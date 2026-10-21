#!/usr/bin/env bash
## Behavioural check on the collection operation (F4.2, Settled): `--intern-op-collect-sources` brings the sources a member's input
## scan read directly -- its mailbox and its Trello -- into the member's inbox, through the tooling, which holds the credentials
## hidden, and never changes a source's read state. Held, against a fake imaplib and a fake curl, in a rig tree of this check's own:
##   1. THE TTL TABLE is one: mail 60 s, Trello 120 s beside the 15 s of the tags and the 300 s of a scan, and Wait reads it
##   2. A MAILBOX is collected as inbox notes, one for each unseen message (`note-<date>-email-u<uid>.md`, the channel id the
##      member needs to mark it read afterwards, the block the scan renders in the body), by one IMAP session that opens the
##      mailbox read-only and fetches with BODY.PEEK: no STORE, COPY or EXPUNGE is ever sent
##   3. THE POINTER AND THE TTL: a source inside its TTL is not asked again; a forced pass finds nothing twice; a message that
##      is read elsewhere keeps its note (a person reading the mailbox takes nothing from the member); one the member has
##      processed is not collected again; a pass collects 64 at most
##   4. A FAILURE is said, leaves the source due, and prints no secret
##   5. TRELLO is collected the same way, with reads only
##   6. WHO AND WHAT: a member with nothing configured, a client-* member on our own side, the members a scan reads, a bad call
##   7. WHAT IS STALE is named, for the thread that updates what no scan asked for
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
rigTmp="$( rigTempDir AgentsCollectSourcesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigFix="$rigTmp/fix"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigData/inboxes" "$rigData/board" "$rigTmp/bin" "$rigTmp/py" "$rigFix" \
	"$rigSkills/rig-member" "$rigSkills/rig-plain" "$rigSkills/client-rig"
for rigName in rig-member rig-plain client-rig ; do printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigName/$rigName.basic.md" ; done
## The routine whose scan is the sweep: its executor is the member whose sources the sweep reads.
printf -- '---\ntype: routine\nexecutors: rig-member\ninput-scan-def: sweep\n---\n# rig-member.sweep.routine\n' > "$rigSkills/rig-member/rig-member.sweep.routine.md"
cp "$rigPackage/sh-test/check-fixtures/collect-sources.imaplib.stub.py" "$rigTmp/py/imaplib.py"
cp "$rigPackage/sh-test/check-fixtures/collect-sources.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl"
rigSecret="rig-app-password-SECRET-0001"
rigTrelloKey="rig-trello-key-SECRET-0002" rigTrelloToken="rig-trello-token-SECRET-0003"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'EMAIL_IMAP_HOST=imap.rig.invalid\nEMAIL_USER=rig@rig.invalid\nEMAIL_APP_PASSWORD=%s\nTRELLO_KEY=%s\nTRELLO_TOKEN=%s\n' "$rigSecret" "$rigTrelloKey" "$rigTrelloToken" > "$rigWs/.local/.agents/rig-member.agent.env"
printf 'EMAIL_IMAP_HOST=imap.rig.invalid\nEMAIL_USER=client@rig.invalid\nEMAIL_APP_PASSWORD=%s\n' "$rigSecret" > "$rigWs/.local/.agents/client-rig.agent.env"

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
rigField(){ ## file, field -- the first value of a frontmatter key
	LC_ALL=C awk -v want="$2: " 'NR == 1 { next ; } $0 == "---" { exit ; } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit ; }' "$1" 2> /dev/null
}
rigMailbox(){ ## "<uid> <unseen|seen>"... -- the fake mailbox as it is now
	: > "$rigFix/mailbox"
	local rigRow
	for rigRow in "$@" ; do printf '%s\n' "$rigRow" >> "$rigFix/mailbox" ; done
}
rigRun(){ ## options of the operation -- output in $rigTmp/out and $rigTmp/err, status in rigRc
	rigRc=0
	: > "$rigFix/imap.log" ; : > "$rigFix/curl.log"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" PYTHONPATH="$rigTmp/py" PYTHONDONTWRITEBYTECODE=1 \
		FIX_DIR="$rigFix" RIG_TMP="$rigTmp" MDAT_COLLECT_LOCK_TRIES=1 \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-collect-sources "$@"
		' rig "$@" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	[ "$rigRc" != 99 ] || rigRefuse "the call was not contained in the rig tree"
}
rigIncoming="$rigData/inboxes/rig-member/incoming" rigProcessed="$rigData/inboxes/rig-member/processed"
rigState="$rigWs/.local/agents/collect"
rigKey(){ ## state name (<kind>.<member>), key -- the value of a key of a source's state
	LC_ALL=C awk -v want="$2" '$1 == want { sub( /^[^ ]+ ?/, "" ) ; print ; exit ; }' "$rigState/$1.state" 2> /dev/null
}
rigNames(){ ## folder, glob -- the item names, one a line
	( cd "$1" 2> /dev/null && ls -1 $2 2> /dev/null )
}

echo "-- 1. the one TTL table --"
rigTtl="$( bash -c '. "$1/sh-lib/member/AgentsTools.SourceTtl.include" && for s in mail:rig-member trello:rig-member tagged:x scan:work-duty chat:s ; do printf "%s=%s " "${s%%:*}" "$( AgentsToolsSourceTtlOf "$s" )" ; done' rig "$rigPackage" 2> /dev/null )"
rigAssert "mail 60, trello 120, tagged 15, scan 300, any other 0" "$rigTtl" "mail=60 trello=120 tagged=15 scan=300 chat=0 "
rigAssert "Wait's table is that table" "$( LC_ALL=C grep -c -F "scan:*) printf '300" "$rigPackage/sh-lib/member/AgentsTools.MemberWait.include" ):$( LC_ALL=C grep -c -F 'AgentsToolsSourceTtlOf "$1"' "$rigPackage/sh-lib/member/AgentsTools.MemberWait.include" )" "0:1"

echo "-- 2. a mailbox --"
rigMailbox "201 unseen" "202 unseen" "203 seen"
rigRun --member rig-member --kind mail
rigAssert "the call succeeds and says what it collected" "$rigRc:$( rigCount "$rigTmp/out" '^collect: mail:rig-member: 2 new$' )" "0:1"
rigAssert "one note for each unseen message, none for the seen one" "$( rigNames "$rigIncoming" 'note-*-email-u*.md' | tr '\n' ' ' )" "note-20261006T1021Z-email-u201.md note-20261006T1022Z-email-u202.md "
rigItem="$rigIncoming/note-20261006T1021Z-email-u201.md"
rigAssert "the note is the member's own" "$( rigField "$rigItem" type ):$( rigField "$rigItem" owner ):$( rigField "$rigItem" from )" "note:rig-member:rig-member"
rigAssert "it names the message, for marking it read afterwards" "$( rigField "$rigItem" communication-channel-id )" "email:rig@rig.invalid:201"
rigAssert "its body is the block the scan renders" "$( rigCount "$rigItem" '^## email-message 201$' ):$( rigCount "$rigItem" '^subject: collect rig mail 201$' ):$( rigCount "$rigItem" '^status: unseen$' )" "1:1:1"
rigAssert "no body of the mail is stored" "$( rigCount "$rigItem" 'Body of rig mail' )" "0"
rigAssert "the write gate refused nothing and warned of nothing" "$( rigCount "$rigTmp/err" 'contract-|WARNING|nothing was written' )" "0"
rigAssert "one session: one connection, one login" "$( rigCount "$rigFix/imap.log" '^CONNECT ' ):$( rigCount "$rigFix/imap.log" '^LOGIN ' )" "1:1"
rigAssert "the mailbox opened read-only, searched UNSEEN" "$( rigCount "$rigFix/imap.log" '^EXAMINE INBOX$' ):$( rigCount "$rigFix/imap.log" '^UID SEARCH UNSEEN$' ):$( rigCount "$rigFix/imap.log" '^SELECT ' )" "1:1:0"
rigAssert "each message fetched without setting Seen" "$( rigCount "$rigFix/imap.log" '^UID FETCH [0-9]+ \(BODY\.PEEK\[\]\)$' )" "2"
rigAssert "no command that changes a read state was sent" "$( rigCount "$rigFix/imap.log" 'STORE|COPY|EXPUNGE|APPEND' )" "0"
rigAssert "the pointer and the check time are kept, with no secret" "$( rigKey mail.rig-member result ):$( rigKey mail.rig-member last-uid ):$( [ "$( rigKey mail.rig-member checked-at )" -gt 0 ] && echo stamped || echo none )" "ok:202:stamped"
rigAssert "the password is in no output, no state, no item" "$( LC_ALL=C grep -r -l -F "$rigSecret" "$rigTmp/out" "$rigTmp/err" "$rigState" "$rigData" 2> /dev/null | wc -l | tr -d '[:space:]' )" "0"

echo "-- 3. the pointer, the TTL, the mail read elsewhere --"
rigRun --member rig-member --kind mail
rigAssert "inside its TTL the source is not asked again" "$( rigCount "$rigTmp/out" '^collect: mail:rig-member: fresh \(checked [0-9]+s ago, ttl 60s\)$' ):$( rigCount "$rigFix/imap.log" '^CONNECT ' )" "1:0"
rigRun --member rig-member --kind mail --force
rigAssert "a forced pass finds nothing new, fetches nothing, and writes nothing twice" "$( rigCount "$rigTmp/out" '^collect: mail:rig-member: 0 new$' ):$( rigCount "$rigFix/imap.log" '^UID FETCH ' ):$( rigNames "$rigIncoming" 'note-*-email-u*.md' | wc -l | tr -d '[:space:]' )" "1:0:2"
rigMailbox "201 seen" "202 unseen" "203 seen" "204 unseen"
rigRun --member rig-member --kind mail --force
rigAssert "a new message is collected" "$( rigCount "$rigTmp/out" '^collect: mail:rig-member: 1 new$' )" "1"
rigAssert "the mail read elsewhere keeps its note: nothing a person does to the mailbox takes a mail from the member" "$( rigNames "$rigIncoming" 'note-*-email-u*.md' | tr '\n' ' ' )" "note-20261006T1021Z-email-u201.md note-20261006T1022Z-email-u202.md note-20261006T1024Z-email-u204.md "
rigMailbox "202 unseen" "204 unseen"
## the member processes the note of the mail 202 (what its ordinary tool does: the note leaves incoming/ for processed/)
mkdir -p "$rigProcessed" && mv "$rigIncoming/note-20261006T1022Z-email-u202.md" "$rigProcessed/"
rigRun --member rig-member --kind mail --force
rigAssert "a message the member has processed is not collected again" "$( rigNames "$rigIncoming" 'note-*-email-u202.md' | wc -l | tr -d '[:space:]' ):$( rigCount "$rigFix/imap.log" '^UID FETCH 202 ' )" "0:0"
rigRun --member rig-member --kind mail --force --since 06-Oct-2026
rigAssert "a bounded pass searches since the date" "$( rigCount "$rigFix/imap.log" '^UID SEARCH UNSEEN SINCE 06-Oct-2026$' ):$( rigCount "$rigTmp/out" ' 0 new$' )" "1:1"
rigMailbox ; for rigUid in $(seq 301 370) ; do printf '%s unseen\n' "$rigUid" >> "$rigFix/mailbox" ; done
rigRun --member rig-member --kind mail --force
rigAssert "a pass collects 64 at most" "$( rigCount "$rigTmp/out" '^collect: mail:rig-member: 64 new$' ):$( rigNames "$rigIncoming" 'note-*-email-u3*.md' | wc -l | tr -d '[:space:]' )" "1:64"
rigRun --member rig-member --kind mail --force
rigAssert "the pointer carries the rest to the next pass" "$( rigCount "$rigTmp/out" '^collect: mail:rig-member: 6 new$' ):$( rigNames "$rigIncoming" 'note-*-email-u3*.md' | wc -l | tr -d '[:space:]' )" "1:70"

echo "-- 4. a failure --"
rigMailbox "401 unseen"
: > "$rigFix/login-fails"
rm -f "$rigState/mail.rig-member.state"
rigRun --member rig-member --kind mail
rigAssert "is said, with the status of a partial run" "$rigRc:$( rigCount "$rigTmp/out" '^collect: mail:rig-member: failed -- ' )" "3:1"
rigAssert "leaves the source due, and the failure kept" "$( rigKey mail.rig-member result ):$( rigKey mail.rig-member checked-at )" "failed:0"
rigAssert "no secret is said" "$( LC_ALL=C grep -r -l -F -e "$rigSecret" "$rigTmp/out" "$rigTmp/err" "$rigState" 2> /dev/null | wc -l | tr -d '[:space:]' )" "0"
rm -f "$rigFix/login-fails"
rigRun --member rig-member --kind mail
rigAssert "the next call tries again at once and collects" "$rigRc:$( rigCount "$rigTmp/out" '^collect: mail:rig-member: 1 new$' )" "0:1"

echo "-- 5. Trello --"
printf '%s' '[{"id":"n2","type":"commentCard","date":"2026-10-06T11:00:00.000Z","unread":true,"memberCreator":{"username":"alice"},"data":{"text":"second","card":{"name":"Card B"},"board":{"name":"Board X"}}},{"id":"n1","type":"addedToCard","date":"2026-10-06T09:05:00.000Z","unread":true,"memberCreator":{"username":"bob"},"data":{"card":{"name":"Card A"},"board":{"name":"Board X"}}}]' > "$rigFix/trello.json"
rigRun --member rig-member --kind trello
rigAssert "each unread notification is a note" "$rigRc:$( rigCount "$rigTmp/out" '^collect: trello:rig-member: 2 new$' ):$( rigNames "$rigIncoming" 'note-*-trello-*.md' | tr '\n' ' ' )" "0:1:note-20261006T0905Z-trello-n1.md note-20261006T1100Z-trello-n2.md "
rigItem="$rigIncoming/note-20261006T1100Z-trello-n2.md"
rigAssert "its body is the block the scan renders" "$( rigCount "$rigItem" '^## trello-notification n2$' ):$( rigCount "$rigItem" '^card: Card B$' )" "1:1"
rigAssert "the write gate refused nothing and warned of nothing" "$( rigCount "$rigTmp/err" 'contract-|WARNING|nothing was written' )" "0"
rigAssert "only the one read was made, a GET" "$( rigCount "$rigFix/curl.log" '^GET https://api.trello.com/1/members/me/notifications\?read_filter=unread$' ):$( LC_ALL=C wc -l < "$rigFix/curl.log" | tr -d '[:space:]' )" "1:1"
rigAssert "the credentials are in no output, no state, no item" "$( LC_ALL=C grep -r -l -F -e "$rigTrelloKey" -e "$rigTrelloToken" "$rigTmp/out" "$rigTmp/err" "$rigState" "$rigData" 2> /dev/null | wc -l | tr -d '[:space:]' )" "0"
printf '%s' '[{"id":"n3","type":"commentCard","date":"2026-10-06T12:00:00.000Z","unread":true,"memberCreator":{"username":"alice"},"data":{"text":"third","card":{"name":"Card C"},"board":{"name":"Board X"}}},{"id":"n2","type":"commentCard","date":"2026-10-06T11:00:00.000Z","unread":true,"memberCreator":{"username":"alice"},"data":{"text":"second","card":{"name":"Card B"},"board":{"name":"Board X"}}}]' > "$rigFix/trello.json"
rigRun --member rig-member --kind trello --force
rigAssert "one new; the one read elsewhere keeps its note" "$( rigCount "$rigTmp/out" '^collect: trello:rig-member: 1 new$' ):$( rigNames "$rigIncoming" 'note-*-trello-*.md' | tr '\n' ' ' )" "1:note-20261006T0905Z-trello-n1.md note-20261006T1100Z-trello-n2.md note-20261006T1200Z-trello-n3.md "
: > "$rigFix/trello-fails"
rigRun --member rig-member --kind trello --force
rigAssert "a refused read is a failure, said without the credentials" "$rigRc:$( rigCount "$rigTmp/out" '^collect: trello:rig-member: failed -- ' ):$( LC_ALL=C grep -l -F -e "$rigTrelloKey" -e "$rigTrelloToken" "$rigTmp/out" "$rigTmp/err" 2> /dev/null | wc -l | tr -d '[:space:]' )" "3:1:0"
rm -f "$rigFix/trello-fails"

echo "-- 6. who and what --"
rigMailbox "501 unseen"
rigRun --member rig-plain
rigAssert "a member with nothing configured: said, nothing read" "$rigRc:$( rigCount "$rigTmp/out" '^collect: mail:rig-plain: not configured$' ):$( rigCount "$rigTmp/out" '^collect: trello:rig-plain: not configured$' ):$( rigCount "$rigFix/imap.log" '^CONNECT ' )" "0:1:1:0"
rigRun --member client-rig --kind mail
rigAssert "a client-* member on our own side is skipped, its mailbox is the other organisation's" "$rigRc:$( rigCount "$rigTmp/out" '^collect: mail:client-rig: skipped -- ' ):$( rigCount "$rigFix/imap.log" '^CONNECT ' )" "0:1:0"
rigRun --all --force
rigAssert "all: the members a scan reads are collected -- the sweep's executor, and a client-* member on the client side -- and no other" "$rigRc:$( rigCount "$rigTmp/out" '^collect: mail:rig-member: ' ):$( rigCount "$rigTmp/out" '^collect: trello:rig-member: ' ):$( rigCount "$rigTmp/out" '^collect: mail:client-rig: ' ):$( rigCount "$rigTmp/out" '^collect: (mail|trello):rig-plain: ' ):$( rigCount "$rigTmp/out" '^collect: trello:client-rig: ' )" "0:1:1:1:0:0"
rigRun
rigAssert "no member and no --all is a syntax error" "$rigRc:$( rigCount "$rigTmp/err" 'syntax is' )" "1:1"
rigRun --member rig-member --kind nothing
rigAssert "an unknown kind is refused" "$rigRc:$( rigCount "$rigTmp/err" 'kind' )" "1:1"
rigRun --member no-such-member
rigAssert "an unknown member is refused" "$rigRc:$( rigCount "$rigTmp/err" 'no such member' )" "1:1"
mkdir -p "$rigWs/.local/agents/locks"
## held by this check's own shell, a holder that is alive
ln -s "$$" "$rigWs/.local/agents/locks/collect.mail.rig-member"
rigRun --member rig-member --kind mail --force
rigAssert "a source another collection holds is busy, not read twice" "$rigRc:$( rigCount "$rigTmp/out" '^collect: mail:rig-member: busy -- ' ):$( rigCount "$rigFix/imap.log" '^CONNECT ' )" "0:1:0"
rm -f "$rigWs/.local/agents/locks/collect.mail.rig-member"

rigAssert "the client-* member's mail is in its own inbox, collected as the client's" "$( rigNames "$rigData/inboxes/client-rig/incoming" 'note-*-email-u*.md' | wc -l | tr -d '[:space:]' ):$( rigField "$( ls "$rigData"/inboxes/client-rig/incoming/note-*-email-u*.md | head -1 )" owner )" "1:client-rig"
rigRun --all --force
rigRun --report-stale
rigAssert "a source just checked is not stale" "$rigRc:$( rigCount "$rigTmp/out" '^stale: ' )" "0:0"
rigNow="$( date +%s )"
LC_ALL=C awk -v old="$(( rigNow - 2000 ))" '$1 == "checked-at" { print "checked-at " old ; next } { print }' "$rigState/mail.rig-member.state" > "$rigState/mail.rig-member.state.new" && mv "$rigState/mail.rig-member.state.new" "$rigState/mail.rig-member.state"
rigRun --report-stale
rigAssert "one checked twenty TTLs ago is" "$rigRc:$( rigCount "$rigTmp/out" '^stale: mail:rig-member \(' ):$( rigCount "$rigTmp/out" '^stale: trello:rig-member' ):$( rigCount "$rigFix/imap.log" '^CONNECT ' )" "0:1:0:0"
rm -f "$rigState/trello.rig-member.state"
rigRun --report-stale
rigAssert "one never checked is, and nothing is read to say so" "$( rigCount "$rigTmp/out" '^stale: trello:rig-member \(' ):$( rigCount "$rigFix/curl.log" '^GET ' )" "1:0"

echo "-- 8. a pass is one commit --"
git init -q "$rigData" && git -C "$rigData" config user.name rig && git -C "$rigData" config user.email rig@rig.invalid
git -C "$rigData" add -A > /dev/null 2>&1 ; git -C "$rigData" commit -q -m base --allow-empty > /dev/null 2>&1
rigCommits(){ ## -- how many commits the store holds
	git -C "$rigData" rev-list --count HEAD 2> /dev/null
}
rigMailbox "701 unseen" "702 unseen" "703 unseen"
rigBefore="$( rigCommits )"
rigRun --member rig-member --kind mail --force
rigAssert "a pass of three mails is one commit, holding the three notes, and nothing is left uncommitted" "$rigRc:$(( $( rigCommits ) - rigBefore )):$( git -C "$rigData" show --name-only --format= HEAD | LC_ALL=C grep -c -- '-email-u70[123]\.md' ):$( git -C "$rigData" status --porcelain | LC_ALL=C grep -c . || : )" "0:1:3:0"
rigAssert "which says what it is" "$( git -C "$rigData" log -1 --format=%s | LC_ALL=C grep -c -E '^\* source collection of rig-member: 3 new note\(s\)$' )" "1"
printf '%s' '[{"id":"n9","type":"commentCard","date":"2026-10-06T12:30:00.000Z","unread":true,"memberCreator":{"username":"alice"},"data":{"text":"ninth","card":{"name":"Card Z"},"board":{"name":"Board X"}}}]' > "$rigFix/trello.json"
rigMailbox "704 unseen" "705 unseen"
rigBefore="$( rigCommits )"
rigRun --member rig-member --force
rigAssert "the mail and the Trello of one member in one call are one commit" "$rigRc:$(( $( rigCommits ) - rigBefore )):$( git -C "$rigData" show --name-only --format= HEAD | LC_ALL=C grep -c -E -- '-(email-u70[45]|trello-n9)\.md' )" "0:1:3"
rigMailbox "706 unseen" "707 unseen"
rigBefore="$( rigCommits )"
rigRun --all --force
rigAssert "all the members of a pass are one commit too" "$rigRc:$(( $( rigCommits ) - rigBefore ))" "0:1"
rigRun --member rig-member --kind mail --force
rigAssert "a pass that wrote nothing makes no commit" "$rigRc:$(( $( rigCommits ) - rigBefore - 1 ))" "0:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COLLECT SOURCES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COLLECT_SOURCES: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
