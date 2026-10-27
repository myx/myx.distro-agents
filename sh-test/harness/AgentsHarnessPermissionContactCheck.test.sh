#!/usr/bin/env bash
## Behavioural check on the answer of a permission asked for a CONTACT (F7.10 of the refactorings epic), run through --intern-tool, the path the myx.distro MCP
## uses. A call refused for a contact (`contact:<id>`, recorded by DistroAgentsContacts.fn.sh --escalate-contact) is asked of the human-owner with
## RequestPermission on its refusal, the existing escalation path, and is answered and applied by the escalation apply, signed by whoever answered. Held:
##   1. THE POST says exactly what each answer grants, from the refusal: the call and the contact it is refused for; the answers offered are deny, the session
##      and the contact (👤, `allow-contact`), never once and never the folder or the project; the emoji placed are the three of them.
##   2. HIS CLICK ON 👤 is allow-contact: the escalation apply opens a `contact` grant, an `allows:` entry of the contact's record signed by him, which the
##      chain reads for the contact whatever the session; the confirmation in the thread says the grant is the contact's, for good; the member that asked
##      holds nothing by it.
##   3. HIS WORD allow-session is a session grant for the contact in that session only.
##   4. WHERE THE REFUSAL IS NOT A CONTACT'S the answer is not offered: the post has no 👤, and allow-contact typed or clicked is no answer, nothing is granted.
##   5. WHO ANSWERS: an answer from one who does not hold the call goes up the chain, still open, with nothing granted; the human-owner holds everything.
##   6. THE VERDICT READER, asked directly: the click and the word count only where the contact is offered, and two clicks never widen what one gives.
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists nothing of the host is beside it, and every scenario runs in its own workspace under this
## check's temp tree, in $MMDAPP/.local/temp.
set -u
## The runner gives every test a team rig as the default workspace mode (AgentsRunTests.sh); a run by hand takes the same default, so the result is the same either way.
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessPermissionContactCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" "$rigTmp/bin/curl.fixture" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl.fixture"
## THE OWNER ANSWERS LATER. The curl first on PATH is the fixture with one thing ahead of it: a
## scenario can keep the thread the owner has answered in aside (replies.later.json), and name
## a file (replies.later.when, a glob). From the first call made once that file exists, the
## thread served is the later one. So an answer arrives at one known point of a call, never by
## a clock.
RIG_CURL_FIXTURE="$rigTmp/bin/curl.fixture"
export RIG_CURL_FIXTURE
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
if [ -n "${RIG_SCENARIO:-}" ] && [ -f "$RIG_SCENARIO/replies.later.json" ] && [ -f "$RIG_SCENARIO/replies.later.when" ] ; then
	for rigWhen in $( cat "$RIG_SCENARIO/replies.later.when" ) ; do
		[ -e "$rigWhen" ] || continue
		mv -f "$RIG_SCENARIO/replies.later.json" "$RIG_SCENARIO/replies.json"
		break
	done
fi
exec "$RIG_CURL_FIXTURE" "$@"
RIGCURL
chmod +x "$rigTmp/bin/curl"
## THE RIG'S OWN PROCESS LIST: empty. The ps first on PATH answers the whole-host listing with
## nothing, so no process of this host is taken for a run of the rig, and hands every other
## call to the real ps.
RIG_PS_REAL="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
export RIG_PS_REAL
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*) exit 0 ;;
esac
exec "$RIG_PS_REAL" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] || rigRefuse "the rig's own ps is not first on PATH, so this check would read the host's process list"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}
rigFirstLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}
## How many lines of a file are one text exactly.
rigLines(){ ## file, line
	LC_ALL=C awk -v wantLine="$2" '$0 == wantLine { hitCount++ ; } END { print hitCount + 0 ; }' "$1" 2>/dev/null || printf 'no-such-file'
}
## How many lines of a file start with one text.
rigStarts(){ ## file, line start
	LC_ALL=C awk -v wantHead="$2" 'index( $0, wantHead ) == 1 { hitCount++ ; } END { print hitCount + 0 ; }' "$1" 2>/dev/null || printf 'no-such-file'
}
rigVerdictLine(){
	LC_ALL=C awk '/^VERDICT: / { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-verdict-line" ; } }' "$rigScenarioDir/out"
}
rigRefusal(){ ## output file -> the refusal id it printed
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$1" | head -1
}
## The pending-reply records of the scenario, oldest first by the post they stand at.
rigRecordFiles(){
	local recordFile
	for recordFile in "$rigWs/.local/agents/pending"/*.md "$rigWs/.local/agents/pending/closed"/*.md ; do
		[ -f "$recordFile" ] || continue
		printf '%s\t%s\n' "$( LC_ALL=C sed -n 's/^question-ts: //p' "$recordFile" | head -1 )" "$recordFile"
	done | LC_ALL=C sort | cut -f2-
}
rigRecordCount(){
	rigRecordFiles | LC_ALL=C awk 'END { print NR + 0 ; }'
}
rigRecordFile(){ ## which, counting from 1
	rigRecordFiles | LC_ALL=C sed -n "${1:-1}p"
}
rigRecordField(){ ## field, which record (default the first)
	LC_ALL=C awk -v key="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$( rigRecordFile "${2:-1}" )" 2>/dev/null || printf 'no-record'
}
rigRecordId(){ ## which record (default the first)
	local recordId
	recordId="$( rigRecordFile "${1:-1}" )" ; recordId="${recordId##*/}"
	printf '%s' "${recordId%.md}"
}
rigSetFile(){ ## which record (default the first)
	local setFile
	setFile="$( rigRecordFile "${1:-1}" )"
	printf '%s' "${setFile%.md}.set"
}
## The text a post, or an edit of one, carries: the JSON string of its body, as sent.
rigTextOf(){ ## body file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk '{ at = index( $0, "\"text\":\"" ) ; if ( ! at ) { next ; } rest = substr( $0, at + 8 ) ; end = 0 ; marks[1] = "\",\"thread_ts\":" ; marks[2] = "\",\"ts\":" ; marks[3] = "\",\"blocks\":" ; for ( markNo = 1 ; markNo <= 3 ; markNo++ ) { markAt = index( rest, marks[markNo] ) ; if ( markAt > 0 && ( end == 0 || markAt < end ) ) { end = markAt ; } } if ( end > 0 ) { print substr( rest, 1, end - 1 ) ; } exit ; }' "$1"
}
## Whether that text holds one line exactly: the line stands between two line breaks of it.
rigTextLine(){ ## body file, line
	case "\\n$( rigTextOf "$1" )\\n" in
		*"\\n$2\\n"*) printf 'yes' ;;
		*) printf 'no' ;;
	esac
}
## How often that text holds one piece of text.
rigTextCount(){ ## body file, text
	rigTextOf "$1" | LC_ALL=C awk -v want="$2" '{ rest = $0 ; while ( ( at = index( rest, want ) ) > 0 ) { hitCount++ ; rest = substr( rest, at + length( want ) ) ; } } END { print hitCount + 0 ; }'
}

rigBotToken="rig-bot-token-TEAM"
rigOwnToken="rig-user-token-TESTER"
rigScenarioDir=""
rigSession=""
rigWs=""
## Where the refused calls point: under no folder of this machine, so nothing any member holds
## reaches them, and nothing is ever written.
rigOut="/dev/null/rig-contact/out"
rigFar="/dev/null/rig-contact/far"
## And a place nothing is written in.
rigRo="/dev/null/rig-contact/ro"
## The task of the scenarios that have one: an item of the board, named as the tooling names one.
rigItem="dispatch-20261012T1200Z-rig"
rigTaskRef=""
rigReason="the rig reworks its report files"
rigStart(){ ## scenario directory name, optional `task`: the board holds the item of the task
	rigScenarioDir="$rigTmp/$1"
	rigSession="rig-contact-$1"
	rigWs="$rigScenarioDir/ws"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigWs/IN" "$rigScenarioDir/data/board/running"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=%s\n' "$rigBotToken" \
		> "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=%s\n' "$rigOwnToken" > "$rigWs/.local/.agents/$rigMember.agent.env"
	## Places by name: the workspace itself, two folders outside it, and one that is read-only.
	printf '%s\t%s\t%s\t%s\t%s\n' rig-ws workspace read-write "$rigWs" workspace rig-out directory read-write "$rigOut" owner rig-far directory read-write "$rigFar" owner rig-ro directory read-only "$rigRo" owner \
		> "$rigWs/.local/agents/directories.registry"
	rigTaskRef="the report rework"
	if [ "${2:-}" = "task" ] ; then
		printf -- '---\nstatus: dispatch-started\nowner: %s\nsession-id: %s\n---\n\n# Rework the report files\n\n## Brief\n\nThe rig rewrites its report files.\n' "$rigMember" "$rigSession" \
			> "$rigScenarioDir/data/board/running/$rigItem.md"
		rigTaskRef="the report rework, $rigItem"
	fi
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
	rigThreadNow 1 ""
}
## The ts the fake Slack gives the n-th post of a scenario.
rigPostTs(){ ## n
	printf '1700000001.000%s01' "$1"
}
## The thread of one post as conversations.replies returns it, with what the owner has put on
## it: nothing, or his click.
rigThreadJson(){ ## which post, the owner's reaction name or empty
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"first"%s}],"has_more":false}\n' "$( rigPostTs "$1" )" \
		"${2:+,\"reactions\":[{\"name\":\"$2\",\"count\":2,\"users\":[\"URIGSELF1\",\"URIGOWNER\"]}]}"
}
rigThreadNow(){ ## which post, the owner's reaction name or empty
	rm -f "$rigScenarioDir/replies.later.json" "$rigScenarioDir/replies.later.when"
	rigThreadJson "$1" "$2" > "$rigScenarioDir/replies.json"
}
## The owner clicks once a file exists: the thread with his click is kept aside until then.
rigThreadLater(){ ## which post, the owner's reaction name, the file (a glob) his click waits for
	rigThreadJson "$1" "$2" > "$rigScenarioDir/replies.later.json"
	printf '%s\n' "$3" > "$rigScenarioDir/replies.later.when"
}

## How many calls that change something in Slack the scenario has made: a post, an edit, an emoji.
rigWrites(){
	LC_ALL=C awk '$0 == "chat.postMessage" || $0 == "chat.update" || $0 == "reactions.add" || $0 == "reactions.remove" { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null
}
## One served call of a tool, as the rig's member in the session rigSession. A question nobody
## answers is re-waited without end by design, so the guard is the scenario's: a killed run is
## reported as such, never as a result. With settle the guard is a quiet time: it counts from
## the first thread read this call makes, and starts again at every post, edit or emoji, so the
## call is ended only once it does nothing but wait, however long its work took before that.
rigKilled=""
rigCall(){ ## guard seconds, tool, argument object, optional settle
	local callPid callLeft callStartLeft=120 callReads callWrites callNow
	rigKilled="no"
	callReads="$( rigCalls conversations.replies )"
	callWrites="$( rigWrites )"
	set -m
	( cd "$rigWs" && printf '%s' "$3" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD \
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID="$rigSession" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigWs" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigWs" --access-write-root "$rigWs/IN" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	callPid=$!
	set +m
	callLeft="$1"
	while kill -0 "$callPid" 2>/dev/null && [ "$callLeft" -gt 0 ] ; do
		sleep 1
		if [ "${4:-}" = "settle" ] ; then
			if [ "$callStartLeft" -gt 0 ] && [ "$( rigCalls conversations.replies )" = "$callReads" ] ; then
				callStartLeft=$(( callStartLeft - 1 ))
				continue
			fi
			callNow="$( rigWrites )"
			if [ "$callNow" != "$callWrites" ] ; then
				callWrites="$callNow" ; callLeft="$1"
				continue
			fi
		fi
		callLeft=$(( callLeft - 1 ))
	done
	if kill -0 "$callPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$callPid" ; sleep 1 ; kill -KILL -- "-$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}
## One team operation in the scenario's workspace, as no session of its own; out and err kept
## as op.out and op.err, its rc as rigOpRc.
rigOpRc=0
rigOp(){ ## operation and its arguments
	rigOpRc=0
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigWs" bash "$rigTools" "$@" ) > "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err" || rigOpRc=$?
}
## A write the harness refuses: prints its refusal id. What the call printed is kept as refused.out.
rigRefused(){ ## path
	rigCall 60 Write "{\"path\":\"$1\",\"content\":\"x\"}"
	cp "$rigScenarioDir/out" "$rigScenarioDir/refused.out"
	rigRefusal "$rigScenarioDir/out"
}
## What the task needs, asked in one ask: the refusal it starts from and the entries, a JSON
## list. With a quiet time it is a call nobody answers, ended by the rig once it only waits.
rigAskSet(){ ## refusal id, the entries as a JSON value, optional quiet seconds
	if [ -n "${3:-}" ] ; then
		rigCall "$3" RequestPermission "{\"refusal_id\":\"$1\",\"reason\":\"$rigReason\",\"task_ref\":\"$rigTaskRef\",\"entries\":$2}" settle
	else
		rigCall 120 RequestPermission "{\"refusal_id\":\"$1\",\"reason\":\"$rigReason\",\"task_ref\":\"$rigTaskRef\",\"entries\":$2}"
	fi
}
## One refused call asked alone, of the human-owner.
rigAskOne(){ ## refusal id, optional quiet seconds
	if [ -n "${2:-}" ] ; then
		rigCall "$2" RequestPermission "{\"to\":\"human-owner\",\"refusal_id\":\"$1\",\"reason\":\"$rigReason\",\"task_ref\":\"$rigTaskRef\"}" settle
	else
		rigCall 120 RequestPermission "{\"to\":\"human-owner\",\"refusal_id\":\"$1\",\"reason\":\"$rigReason\",\"task_ref\":\"$rigTaskRef\"}"
	fi
}
## Whether the session holds a grant for one call: the first word after GRANT:, or none.
rigGranted(){ ## tool, path
	rigOp --intern-op-permission-grant-read "$rigMember" --session-id "$rigSession" --tool "$1" --target "$2"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigScenarioDir/op.out" | head -1 | LC_ALL=C awk '{ print ; found = 1 ; } END { if ( ! found ) { print "none" ; } }'
}
## The emoji of the tooling's own on one post: "<placed, in order>|<taken off, in order>".
rigEmoji(){ ## which post
	printf '%s|%s' "$( LC_ALL=C awk -v want="$( rigPostTs "$1" )" '$1 == want { out = out ( out == "" ? "" : " " ) $2 ; } END { print out ; }' "$rigScenarioDir/reactions" 2>/dev/null )" \
		"$( LC_ALL=C awk -v want="$( rigPostTs "$1" )" '$1 == want { out = out ( out == "" ? "" : " " ) $2 ; } END { print out ; }' "$rigScenarioDir/reactions.removed" 2>/dev/null )"
}

## The thread of one post with a reply of the owner under it, as conversations.replies returns it.
rigThreadReply(){ ## which post, the owner's words
	rm -f "$rigScenarioDir/replies.later.json" "$rigScenarioDir/replies.later.when"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"first"},{"ts":"1700000001.000%s50","thread_ts":"%s","user":"URIGOWNER","text":"%s"}],"has_more":false}\n' \
		"$( rigPostTs "$1" )" "$1" "$( rigPostTs "$1" )" "$2" > "$rigScenarioDir/replies.json"
}
## A refusal the rig records itself, for a call the harness would not make: prints its id.
rigLogged(){ ## tool, target
	rigOp --intern-op-permission-refusal-log "$rigMember" --session-id "$rigSession" --tool "$1" --target "$2" --reason 'a call the rig made up'
	LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$rigScenarioDir/op.out" | head -1
}
## What the folder answer of one refusal would grant, as the operation says it:
## "<entry>|<as a post shows it>", or "none".
rigFolderOf(){ ## refusal id
	rigOp --intern-op-permission-folder "$rigMember" --session-id "$rigSession" --refusal-id "$1"
	LC_ALL=C awk '/^ENTRY: / { entry = substr( $0, 8 ) ; } /^SHOWN: / { shown = substr( $0, 8 ) ; } END { if ( entry == "" ) { print "none" ; } else { print entry "|" shown ; } }' "$rigScenarioDir/op.out"
}


## A contact of the scenario, recorded by the tool that keeps them; the call it is refused for, recorded as the contacts tool records it.
rigContactTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsContacts.fn.sh"
rigContact(){ ## id
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_THREAD MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigWs" \
		bash "$rigContactTool" --collect-contact --id "$1" --name "Alice Two" --email alice@rig.example --reached-by "$rigMember" ) > "$rigScenarioDir/contact.out" 2> "$rigScenarioDir/contact.err"
}
rigRefusedFor(){ ## contact id, tool, target -- the refusal id
	rigOp --intern-op-permission-refusal-log "contact:$1" --session-id "$rigSession" --tool "$2" --target "$3" --reason 'what the contact asked'
	LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$rigScenarioDir/op.out" | head -1
}
rigAllows(){ ## contact id -- the allows: of its record
	LC_ALL=C sed -n 's/^allows: //p' "$rigScenarioDir/data/contacts/persons/$1.md" | LC_ALL=C sed -E 's/[0-9]{8}T[0-9]{6}Z/<time>/g'
}
## What the chain says of a contact for one call in one session: the first words after GRANT:, or none.
rigContactGranted(){ ## contact id, session, tool, target
	rigOp --intern-op-permission-grant-read "contact:$1" --session-id "$2" --tool "$3" --target "$4"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigScenarioDir/op.out" | head -1 | LC_ALL=C awk '{ print ; found = 1 ; } END { if ( ! found ) { print "none" ; } }'
}

echo "-- a permission asked for a contact, answered by a click on 👤: the contact itself is granted --"
rigStart click
rigContact alice-two
rigFirst="$( rigRefusedFor alice-two dispatch job-30 )"
[ -n "$rigFirst" ] || rigRefuse "the rig recorded no refusal for the contact"
rigThreadNow 1 bust_in_silhouette
rigAskOne "$rigFirst"
rigAssert "his click on 👤 is the answer: allow-contact" "$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigVerdictLine )" "no:ASK-RESULT: RECEIVED:VERDICT: allow-contact"
rigAssert "the first line of the post says the call and the contact it is refused for, and what an allow grants: that and nothing wider" \
	"$( rigTextLine "$rigScenarioDir/post.1" 'Allow **dispatch** on `job-30` for **contact:alice-two**? An allow grants exactly that, and nothing wider.' )" "yes"
rigAssert "under how to answer: deny, the session and the contact; not once, not a folder, not a project" \
	"$( rigTextLine "$rigScenarioDir/post.1" '- click ❌ to deny, or 🔁 to allow for this session' ):$( rigTextLine "$rigScenarioDir/post.1" '- or click 👤 to allow **dispatch** to the contact `alice-two`, for good, whatever the session' ):$( rigTextLine "$rigScenarioDir/post.1" '- or reply `deny` or `allow-session`, or `allow-contact` for 👤' ):$( rigTextCount "$rigScenarioDir/post.1" 'allow-once' ):$( rigTextCount "$rigScenarioDir/post.1" '📁' )" \
	"yes:yes:yes:0:0"
rigAssert "the emoji placed are the cross, the repeat sign and 👤; answered, it gets the answered mark and the bot takes its own answer emoji off" "$( rigEmoji 1 )" "x repeat bust_in_silhouette white_check_mark|x repeat bust_in_silhouette"
rigAssert "the request is a single permission, closed with that verdict" "$( rigRecordCount ):$( rigRecordField kind ):$( rigRecordField status ):$( rigRecordField verdict )" "1:permission:reply-received:allow-contact"
rigAssert "the grant is an entry of the allows: of the contact's record, signed by the account that answered, and one dated line of its log says it, by his name" \
	"$( rigAllows alice-two ):$( LC_ALL=C grep -c -E -- '-- human-owner -- allowed: dispatch job-30 \(standing\)$' "$rigScenarioDir/data/contacts/persons/alice-two.md" )" "contact:dispatch:job-30:URIGOWNER:<time>:1"
rigAssert "the confirmation in the thread says the grant is the contact's, for good: to the contact, not to the member that asked" \
	"$( rigCalls chat.postMessage ):$( cat "$rigScenarioDir/posted-as.2" 2>/dev/null ):$( rigHolds "$rigScenarioDir/post.2" "\"thread_ts\":\"$( rigPostTs 1 )\"" ):$( rigHolds "$rigScenarioDir/post.2" 'Read: `allow-contact` by human-owner. Granted: dispatch on job-30 to contact:alice-two, for the contact, whatever the session.' )" \
	"2:$rigBotToken:yes:yes"
rigAssert "the chain reads it for the contact in any session, and for no other call or contact; the member that asked holds nothing by it" \
	"$( rigContactGranted alice-two some-other-session dispatch job-30 ):$( rigContactGranted alice-two some-other-session dispatch job-31 ):$( rigContactGranted alice-two some-other-session other-tool job-30 ):$( rigGranted dispatch job-30 )" "contact:none:none:none"

echo "-- answered by a word: allow-session is a session grant for the contact --"
rigStart word
rigContact alice-two
rigFirst="$( rigRefusedFor alice-two dispatch job-30 )"
rigThreadReply 1 'allow-session'
rigAskOne "$rigFirst"
rigAssert "his reply allow-session: the verdict, a session grant in this session's grants for the contact, the record's allows: untouched" \
	"$rigKilled:$( rigVerdictLine ):$( rigContactGranted alice-two "$rigSession" dispatch job-30 ):$( rigContactGranted alice-two some-other-session dispatch job-30 ):$( rigGranted dispatch job-30 ):$( rigAllows alice-two )" \
	"no:VERDICT: allow-session:session:none:none:"
rigAssert "the confirmation says it is for this session, to the contact" "$( rigHolds "$rigScenarioDir/post.2" 'Granted: dispatch on job-30 to contact:alice-two, for this session.' )" "yes"

echo "-- where the refusal is not a contact's, the contact answer is not offered --"
rigStart member
rigMemberRef="$( rigLogged dispatch job-30 )"
rigThreadReply 1 'allow-contact'
rigAskOne "$rigMemberRef"
rigAssert "the post of a member's refusal has no 👤 and names no allow-contact; the three plain emoji are placed" \
	"$( rigTextCount "$rigScenarioDir/post.1" '- or click 👤 to allow' ):$( rigTextCount "$rigScenarioDir/post.1" 'allow-contact' ):$( rigEmoji 1 )" "0:0:x one repeat|"
rigAssert "typed all the same, it is no answer: the request comes back, stays open, and nothing is granted" \
	"$rigKilled:$( rigVerdictLine ):$( rigRecordField status ):$( rigGranted dispatch job-30 )" "no:VERDICT: RETURNED:reply-pending:none"

echo "-- who answers --"
rigStart holder
rigContact alice-two
rigFirst="$( rigRefusedFor alice-two dispatch job-30 )"
rigAskOne "$rigFirst" 8
( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD MDAT_SPAWN_SESSION_ID=rig-contact-coordinator MDAT_SPAWN_AGENT=magic-coordinator \
	MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigWs" bash "$rigTools" --answer-escalation magic-coordinator "$( rigRecordId )" allow-contact ) \
	> "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err" ; rigOpRc=$?
rigAssert "magic-coordinator answers allow-contact for a call it does not hold: not applied, the request stays open, nothing is granted" \
	"$( rigRecordField status ):$( rigAllows alice-two ):$( rigContactGranted alice-two some-other-session dispatch job-30 )" "reply-pending::none"

echo "-- the verdict reader, asked directly: the click and the word count only where the contact is offered --"
rigReadContact(){ ## offered (1 or empty), the rendered answers, one a line
	printf '%s\n' "$2" | MDAT_VERDICT_KIND=permission MDAT_VERDICT_CONTACT="$1" MDAT_VERDICT_AUTHORS=URIGOWNER MDAT_VERDICT_ASKING=URIGSELF1 \
		LC_ALL=C awk -f "$rigHere/questions/AgentsEscalationVerdict.awk" | LC_ALL=C tr '\t' '|' | LC_ALL=C cut -d'|' -f1-2
}
rigClickContact(){ ## reaction names of the owner...
	local clickName clickOut=""
	for clickName in "$@" ; do clickOut="$clickOut${clickOut:+$'\n'}reaction on the question: [reactions: $clickName x1 (URIGOWNER)]" ; done
	printf '%s' "$clickOut"
}
rigAssert "offered: the 👤 click is allow-contact, and so is the word, first on its line" \
	"$( rigReadContact 1 "$( rigClickContact bust_in_silhouette )" ):$( rigReadContact 1 '1700000001.000200 | URIGOWNER | allow-contact' ):$( rigReadContact 1 '1700000001.000200 | URIGOWNER | Allow-Contact, for good' )" \
	"allow-contact|URIGOWNER:allow-contact|URIGOWNER:allow-contact|URIGOWNER"
rigAssert "two clicks never widen what one gives: the cross and the repeat sign each win over 👤" \
	"$( rigReadContact 1 "$( rigClickContact bust_in_silhouette x )" ):$( rigReadContact 1 "$( rigClickContact bust_in_silhouette repeat )" )" "deny|URIGOWNER:allow-session|URIGOWNER"
rigAssert "not offered: neither the click nor the word is an answer" \
	"$( rigReadContact '' "$( rigClickContact bust_in_silhouette )" ):$( rigReadContact '' '1700000001.000200 | URIGOWNER | allow-contact' )" "RETURNED|:RETURNED|"
rigFill(){ ## want, template, form -- the slots come from the caller's environment
	ASKP_WANT="$1" ASKP_FORM="$3" LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsToolingTemplateFill.awk" -f "$rigHere/questions/AgentsAskPostFill.awk" "$rigHere/templates/$2" 2>&1
}
rigAssert "the filler: with a contact the permission post places 👤 beside the cross and the repeat sign, and with none the three as before" \
	"$( ASKP_F_contact=alice-two rigFill reactions request-permission.post.format.md grant | LC_ALL=C tr '\n' ' ' ):$( rigFill reactions request-permission.post.format.md grant | LC_ALL=C tr '\n' ' ' )" "x repeat bust_in_silhouette :x one repeat "

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION CONTACT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_PERMISSION_CONTACT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
