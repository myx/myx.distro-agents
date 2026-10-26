#!/usr/bin/env bash
## Behavioural check on the per-member incoming sync (T2 of the refactorings epic): `--intern-op-member-incoming-sync` refills a
## member's own incoming at once -- its mailbox, its Trello notifications, its tags and mentions, its DMs and its session chat --
## whatever their TTLs, one line a source, against a fake imaplib and a fake curl in a rig tree of this check's own. Held:
##   1. THE TTL TABLE holds the cache TTLs T2 names: the session chat short (chat 15), the mail five minutes (mail 300), the tags and
##      mentions at the live Wait floor (tagged 15) with the schedule's one minute elsewhere, Trello 120, a scan 300
##   2. A SYNC collects the mailbox and the Trello of the member into its inbox, force, in one call, and says one line a source:
##      the tags force-read through the schedule's reader (one line, none in the rig), the DMs force-read through the schedule's
##      reader of the member's direct conversations (one line, none: the member holds no Slack token), and the session chat said as
##      no session (one line, none: the sync runs in no session)
##   3. A second sync, with nothing new, says 0 new for each and writes nothing twice
##   4. WHO: a sync with no member is a syntax error; one naming no member is refused
## Offline: every tree is this rig's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFixture in collect-sources.imaplib.stub.py collect-sources.curl.stub.sh rig-temp.include.sh ; do
	[ -f "$rigPackage/sh-test/check-fixtures/$rigFixture" ] || rigRefuse "the fixture $rigFixture is missing from the package"
done
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsIncomingSyncCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigFix="$rigTmp/fix"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigData/inboxes" "$rigData/board" "$rigTmp/bin" "$rigTmp/py" "$rigFix" \
	"$rigSkills/rig-member"
for rigName in rig-member ; do printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigName/$rigName.basic.md" ; done
cp "$rigPackage/sh-test/check-fixtures/collect-sources.imaplib.stub.py" "$rigTmp/py/imaplib.py"
cp "$rigPackage/sh-test/check-fixtures/collect-sources.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl"
rigSecret="rig-app-password-SECRET-0001"
rigTrelloKey="rig-trello-key-SECRET-0002" rigTrelloToken="rig-trello-token-SECRET-0003"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'EMAIL_IMAP_HOST=imap.rig.invalid\nEMAIL_USER=rig@rig.invalid\nEMAIL_APP_PASSWORD=%s\nTRELLO_KEY=%s\nTRELLO_TOKEN=%s\n' "$rigSecret" "$rigTrelloKey" "$rigTrelloToken" > "$rigWs/.local/.agents/rig-member.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCount(){ ## file, extended regex
	LC_ALL=C grep -c -E -- "$2" "$1" 2> /dev/null || :
}
rigMailbox(){ ## "<uid> <unseen|seen>"... -- the fake mailbox as it is now
	: > "$rigFix/mailbox"
	local rigRow
	for rigRow in "$@" ; do printf '%s\n' "$rigRow" >> "$rigFix/mailbox" ; done
}
rigRun(){ ## the member, or none for a bad call
	rigRc=0
	: > "$rigFix/imap.log" ; : > "$rigFix/curl.log"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" PYTHONPATH="$rigTmp/py" PYTHONDONTWRITEBYTECODE=1 \
		FIX_DIR="$rigFix" RIG_TMP="$rigTmp" MDAT_COLLECT_LOCK_TRIES=1 \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-member-incoming-sync "$@"
		' rig "$@" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	[ "$rigRc" != 99 ] || rigRefuse "the call was not contained in the rig tree"
}
rigIncoming="$rigData/inboxes/rig-member/incoming"

echo "-- 1. the one TTL table --"
rigTtl="$( bash -c '. "$1/sh-lib/member/AgentsTools.SourceTtl.include" && for s in chat:s mail:rig-member trello:rig-member tagged:x scan:work-duty ; do printf "%s=%s " "${s%%:*}" "$( AgentsToolsSourceTtlOf "$s" )" ; done' rig "$rigPackage" 2> /dev/null )"
rigAssert "chat 15, mail 300, trello 120, tagged 15, scan 300" "$rigTtl" "chat=15 mail=300 trello=120 tagged=15 scan=300 "

echo "-- 2. a sync refills the member's incoming at once --"
rigMailbox "201 unseen" "202 unseen"
printf '%s' '[{"id":"n1","type":"commentCard","date":"2026-10-06T09:05:00.000Z","unread":true,"memberCreator":{"username":"bob"},"data":{"card":{"name":"Card A"},"board":{"name":"Board X"}}}]' > "$rigFix/trello.json"
rigRun rig-member
rigAssert "the sync succeeds and says one line a source, mail and Trello" "$rigRc:$( rigCount "$rigTmp/out" '^collect: mail:rig-member: 2 new$' ):$( rigCount "$rigTmp/out" '^collect: trello:rig-member: 1 new$' )" "0:1:1"
rigAssert "the tags and mentions are force-read too, one line, none in the rig" "$( rigCount "$rigTmp/out" '^collect: tagged:rig-member: 0 new$' )" "1"
rigAssert "the DMs are force-read too, one line, none -- the member holds no Slack token" "$( rigCount "$rigTmp/out" '^collect: dm:rig-member: 0 new$' )" "1"
rigAssert "the session chat is said too, one line, no session in the rig" "$( rigCount "$rigTmp/out" '^collect: chat:rig-member: no session ' )" "1"
rigAssert "the mailbox notes are in the member's incoming" "$( ( cd "$rigIncoming" 2> /dev/null && ls -1 note-*-email-u*.md 2> /dev/null | tr '\n' ' ' ) )" "note-20261006T1021Z-email-u201.md note-20261006T1022Z-email-u202.md "
rigAssert "the Trello note is in the member's incoming" "$( ( cd "$rigIncoming" 2> /dev/null && ls -1 note-*-trello-*.md 2> /dev/null | tr '\n' ' ' ) )" "note-20261006T0905Z-trello-n1.md "
rigAssert "the password is in no output" "$( LC_ALL=C grep -r -l -F "$rigSecret" "$rigTmp/out" "$rigTmp/err" 2> /dev/null | wc -l | tr -d '[:space:]' )" "0"

echo "-- 3. a second sync finds nothing new and writes nothing twice --"
rigRun rig-member
rigAssert "force finds nothing new for either source" "$rigRc:$( rigCount "$rigTmp/out" '^collect: mail:rig-member: 0 new$' ):$( rigCount "$rigTmp/out" '^collect: trello:rig-member: 0 new$' )" "0:1:1"
rigAssert "the second sync force-reads the tags, none new" "$( rigCount "$rigTmp/out" '^collect: tagged:rig-member: 0 new$' )" "1"
rigAssert "the second sync force-reads the DMs, none new" "$( rigCount "$rigTmp/out" '^collect: dm:rig-member: 0 new$' )" "1"
rigAssert "the second sync says the chat has no session again" "$( rigCount "$rigTmp/out" '^collect: chat:rig-member: no session ' )" "1"
rigAssert "no note is written twice" "$( ( cd "$rigIncoming" 2> /dev/null && ls -1 note-*.md 2> /dev/null | wc -l | tr -d '[:space:]' ) )" "3"

echo "-- 4. who --"
rigRun
rigAssert "no member is a syntax error" "$rigRc:$( rigCount "$rigTmp/err" 'syntax is' )" "1:1"
rigRun no-such-member
rigAssert "an unknown member is refused" "$rigRc:$( rigCount "$rigTmp/err" 'no such member' )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INCOMING SYNC CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INCOMING_SYNC: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
