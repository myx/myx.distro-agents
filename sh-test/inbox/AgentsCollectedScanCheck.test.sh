#!/usr/bin/env bash
## Behavioural check on the scan that reads a collected source (F4.2): the session-context scan's email and Trello sections read the
## notes the collection (AgentsTools.Collect.include) brought into the member's inbox, and no longer ask the source themselves.
## Held, against a fake imaplib and a fake curl, in a rig tree of this check's own:
##   1. THE EMAIL SECTION prints the blocks it always printed, from the notes; the collection runs inside the scan when the TTL has
##      passed and not otherwise, so the next scan inside it connects to nothing; the scan holds no password
##   2. THE CUT-OFF narrows the search and what is shown, as before
##   3. A MESSAGE THE SERVER WOULD NOT GIVE is said as not read, never dropped; a failed session is not scanned, never empty
##   4. A MAILBOX PAST A PASS'S REACH says so, and the next scan past the TTL brings the rest
##   5. TRELLO is read from its notes the same way
##   6. THE INBOX SECTIONS: the collected notes are shown once -- in the section of the source the scan reads, in the notes
##      section of a scan that does not read it
##   7. A SOURCE NOT CONFIGURED is said as before
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
rigTmp="$( rigTempDir AgentsCollectedScanCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigFix="$rigTmp/fix"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigData/inboxes" "$rigData/board/running" "$rigTmp/bin" "$rigTmp/py" "$rigFix" \
	"$rigSkills/rig-member" "$rigSkills/rig-plain"
for rigName in rig-member rig-plain ; do printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigName/$rigName.basic.md" ; done
cp "$rigPackage/sh-test/check-fixtures/collect-sources.imaplib.stub.py" "$rigTmp/py/imaplib.py"
cp "$rigPackage/sh-test/check-fixtures/collect-sources.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl"
rigSecret="rig-app-password-SECRET-0001"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'EMAIL_IMAP_HOST=imap.rig.invalid\nEMAIL_USER=rig@rig.invalid\nEMAIL_APP_PASSWORD=%s\nTRELLO_KEY=rig-trello-key\nTRELLO_TOKEN=rig-trello-token\n' "$rigSecret" > "$rigWs/.local/.agents/rig-member.agent.env"

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
rigMailbox(){ ## "<uid> <unseen|seen|ghost>"... -- the fake mailbox as it is now
	: > "$rigFix/mailbox"
	local rigRow
	for rigRow in "$@" ; do printf '%s\n' "$rigRow" >> "$rigFix/mailbox" ; done
}
## One scan of a member. member, then the scan's options. Output in $rigTmp/out and $rigTmp/err, status in rigRc.
rigScan(){
	local scanMember="$1"
	shift
	rigRc=0
	: > "$rigFix/imap.log" ; : > "$rigFix/curl.log"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" PYTHONPATH="$rigTmp/py" PYTHONDONTWRITEBYTECODE=1 \
		FIX_DIR="$rigFix" RIG_TMP="$rigTmp" MDAT_COLLECT_LOCK_TRIES=1 \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-session-context-scan "$@"
		' rig "$scanMember" --all-types --no-slack --no-board-related --no-inbox-inquiry --no-inbox-reflections --no-inbox-other "$@" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	[ "$rigRc" != 99 ] || rigRefuse "the scan was not contained in the rig tree"
}
rigIncoming="$rigData/inboxes/rig-member/incoming"
rigState="$rigWs/.local/agents/collect"
rigAge(){ ## state name, seconds -- the check time of a source moved back
	LC_ALL=C awk -v old="$(( $(date +%s) - $2 ))" '$1 == "checked-at" { print "checked-at " old ; next ; } { print ; }' "$rigState/$1.state" > "$rigState/$1.state.new" && mv "$rigState/$1.state.new" "$rigState/$1.state"
}

echo "-- 1. the email section, from the notes --"
rigMailbox "201 unseen" "202 unseen" "203 seen"
rigScan rig-member --do-email --no-trello --no-inbox-notes
rigAssert "the scan reads its one source" "$rigRc:$( rigCount "$rigTmp/out" '^sources-scanned: 1 of 1$' )" "0:1"
rigAssert "each unseen message is a block of the document, the seen one is none" "$( rigCount "$rigTmp/out" '^## email-message (201|202)$' ):$( rigCount "$rigTmp/out" '^## email-message 203$' )" "2:0"
rigAssert "a block is what the scan always printed" "$( rigCount "$rigTmp/out" '^subject: collect rig mail 201$' ):$( rigCount "$rigTmp/out" '^status: unseen$' ):$( rigCount "$rigTmp/out" '^mailbox: INBOX$' )" "1:2:2"
rigAssert "the instrument line and the identity are the same" "$( rigCount "$rigTmp/out" '^instrument: unread-semantics \(IMAP UID SEARCH UNSEEN\)$' ):$( rigCount "$rigTmp/out" '^identity: email rig@rig.invalid ' )" "1:1"
rigAssert "one session was made, by the collection, read-only" "$( rigCount "$rigFix/imap.log" '^CONNECT ' ):$( rigCount "$rigFix/imap.log" '^EXAMINE INBOX$' ):$( rigCount "$rigFix/imap.log" '^UID FETCH [0-9]+ \(BODY\.PEEK\[\]\)$' ):$( rigCount "$rigFix/imap.log" 'STORE|COPY|EXPUNGE' )" "1:1:2:0"
rigAssert "the document is not the notes' frontmatter: no note is printed as an inbox item" "$( rigCount "$rigTmp/out" '^## inbox/' )" "0"
rigAssert "the password is in no output" "$( LC_ALL=C grep -l -F "$rigSecret" "$rigTmp/out" "$rigTmp/err" 2> /dev/null | wc -l | tr -d '[:space:]' )" "0"
rigScan rig-member --do-email --no-trello --no-inbox-notes
rigAssert "a scan inside the TTL connects to nothing and prints the same" "$( rigCount "$rigFix/imap.log" '^CONNECT ' ):$( rigCount "$rigTmp/out" '^## email-message (201|202)$' )" "0:2"
rigAssert "no mdat-* file is left" "$( ls -1 "$rigWs/.local/temp" | LC_ALL=C grep -c '^mdat-' || : )" "0"

echo "-- 2. the cut-off --"
rigAge mail.rig-member 3600
rigMailbox "201 unseen" "202 unseen" "301 unseen"
rigScan rig-member --do-email --no-trello --no-inbox-notes --comms-since-utime 1791547200
rigAssert "the search is bounded by the day before the cut-off" "$( rigCount "$rigFix/imap.log" '^UID SEARCH UNSEEN SINCE 08-Oct-2026$' ):$( rigCount "$rigTmp/out" '^cut-off-applied: by date -- IMAP SINCE 08-Oct-2026' )" "1:1"
rigAssert "a message dated before it is not shown" "$( rigCount "$rigTmp/out" '^## email-message ' ):$( rigCount "$rigTmp/out" 'NOTE:\*\* no new incoming email updates' )" "0:1"
rigAge mail.rig-member 3600
rigScan rig-member --do-email --no-trello --no-inbox-notes
rigAssert "with no cut-off the same notes are all shown" "$( rigCount "$rigTmp/out" '^## email-message (201|202|301)$' )" "3"

echo "-- 3. a message not given, a session that failed --"
rigMailbox "201 unseen" "202 unseen" "301 unseen" "401 ghost"
rigAge mail.rig-member 3600
rigScan rig-member --do-email --no-trello --no-inbox-notes
rigAssert "a UID with no message is said, not dropped" "$( rigCount "$rigTmp/out" '^## email-message 401$' ):$( rigCount "$rigTmp/out" '^fetch: not read -- the IMAP session returned 4 for this UID' )" "1:1"
: > "$rigFix/login-fails"
rigAge mail.rig-member 3600
rigScan rig-member --do-email --no-trello --no-inbox-notes
rigAssert "a failed session is not scanned, said, never an empty source" "$( rigCount "$rigTmp/out" '^sources-scanned: 0 of 1$' ):$( rigCount "$rigTmp/out" 'NOTE:\*\* no scan was made -- the IMAP session' ):$( rigCount "$rigTmp/out" '^## email-message ' ):$( [ "$rigRc" != 0 ] && echo partial )" "1:1:0:partial"
rigAssert "and says why on its error output, without the password" "$( rigCount "$rigTmp/err" 'collect: mail:rig-member: failed' ):$( LC_ALL=C grep -l -F "$rigSecret" "$rigTmp/err" 2> /dev/null | wc -l | tr -d '[:space:]' )" "1:0"
rm -f "$rigFix/login-fails"
rigScan rig-member --do-email --no-trello --no-inbox-notes
rigAssert "the next scan tries again at once" "$rigRc:$( rigCount "$rigTmp/out" '^sources-scanned: 1 of 1$' )" "0:1"

echo "-- 4. a mailbox past a pass's reach --"
rigMailbox ; for rigUid in $(seq 501 570) ; do printf '%s unseen\n' "$rigUid" >> "$rigFix/mailbox" ; done
rigAge mail.rig-member 3600
rigScan rig-member --do-email --no-trello --no-inbox-notes
rigAssert "says what is past it" "$( rigCount "$rigTmp/out" '^\*\*NOTE:\*\* truncated -- [0-9]+ items found, capped at [0-9]+$' )" "1"
rigAge mail.rig-member 3600
rigScan rig-member --do-email --no-trello --no-inbox-notes
rigAssert "the next scan past the TTL brings the rest, and nothing is cut" "$( rigCount "$rigTmp/out" '^\*\*NOTE:\*\* truncated' ):$( rigCount "$rigTmp/out" '^## email-message 5[0-9][0-9]$' )" "0:70"

echo "-- 5. Trello --"
printf '%s' '[{"id":"n2","type":"commentCard","date":"2026-10-06T11:00:00.000Z","unread":true,"memberCreator":{"username":"alice"},"data":{"text":"second","card":{"name":"Card B"},"board":{"name":"Board X"}}},{"id":"n1","type":"addedToCard","date":"2026-10-06T09:05:00.000Z","unread":true,"memberCreator":{"username":"bob"},"data":{"card":{"name":"Card A"},"board":{"name":"Board X"}}}]' > "$rigFix/trello.json"
rigScan rig-member --do-trello --no-email --no-inbox-notes
rigAssert "the section is read from the notes, oldest first" "$rigRc:$( rigCount "$rigTmp/out" '^sources-scanned: 1 of 1$' ):$( LC_ALL=C grep -E '^## trello-notification ' "$rigTmp/out" | tr '\n' ' ' )" "0:1:## trello-notification n1 ## trello-notification n2 "
rigAssert "the identity line is the member's" "$( rigCount "$rigTmp/out" '^identity: trello @rigtrello / rigtrelloid ' )" "1"
rigAssert "one read of the unread notifications was made, a GET" "$( rigCount "$rigFix/curl.log" '^GET https://api.trello.com/1/members/me/notifications\?read_filter=unread$' )" "1"
rigScan rig-member --do-trello --no-email --no-inbox-notes
rigAssert "a scan inside the TTL asks for no notifications" "$( rigCount "$rigFix/curl.log" 'read_filter=unread' ):$( rigCount "$rigTmp/out" '^## trello-notification ' )" "0:2"

echo "-- 6. the inbox sections show a collected note once --"
rigScan rig-member --do-email --do-trello --do-inbox-notes
rigAssert "a scan that reads the sources shows no note of them as an inbox item" "$( rigCount "$rigTmp/out" '^## inbox/note-.*-(email-u|trello-)' )" "0"
rigScan rig-member --no-email --no-trello --do-inbox-notes
rigAssert "a scan that does not read them lists them as the inbox items they are, up to the cap of the section" "$( rigCount "$rigTmp/out" '^## inbox/note-.*-(email-u|trello-)' ):$( rigCount "$rigTmp/out" '^\*\*NOTE:\*\* truncated -- [0-9]+ items found, capped at 64' )" "64:1"

echo "-- 7. a source not configured --"
rigScan rig-plain --do-email --do-trello --no-inbox-notes
rigAssert "is said as before, and asks for nothing" "$( rigCount "$rigTmp/out" 'EMAIL_IMAP_HOST/EMAIL_USER/EMAIL_APP_PASSWORD are not all set' ):$( rigCount "$rigTmp/out" 'TRELLO_KEY/TRELLO_TOKEN are not both set' ):$( rigCount "$rigFix/imap.log" '^CONNECT ' ):$( rigCount "$rigFix/curl.log" 'notifications' )" "1:1:0:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COLLECTED SCAN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COLLECTED_SCAN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
