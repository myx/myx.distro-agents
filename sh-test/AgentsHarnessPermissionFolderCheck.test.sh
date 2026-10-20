#!/usr/bin/env bash
## Behavioural check on the folder answer of a single permission, run through --intern-tool,
## the path the myx.distro MCP uses. Covers: a permission asked for one refused file offers one
## more answer, by a click and by a word: the tool of the refused call on everything in the
## folder of that file, for the session; the post says exactly that, the tool, the folder by
## its place and for how long, beside its plain answers, and its first line still says what
## the plain allow grants; the answer is a one-entry set grant of the session for the member
## whose call was refused, so the next file in that folder is not asked, reading follows from
## a write as it always does, and a file in another folder, or another tool, is still asked;
## the confirmation says the tool and the folder; it is not offered, and is no answer where
## it is typed or clicked, where it cannot be right: a tool that has no place, a path with a
## `..` segment, a write in a read-only place, a folder that is a whole workspace; a read in
## a read-only place is offered; a prompt that offered it and takes a further call loses its
## click with the others; and the verdict reader and the filler, each asked directly.
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists nothing of the host is
## beside it, and every scenario runs in its own workspace under this check's temp tree, in
## $MMDAPP/.local/temp.
set -u
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessPermissionFolderCheck.XXXXXX" )" || exit 1
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
	for recordFile in "$rigWs/.local/agents/pending"/*.md ; do
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
rigOut="/dev/null/rig-folder/out"
rigFar="/dev/null/rig-folder/far"
## And a place nothing is written in.
rigRo="/dev/null/rig-folder/ro"
## The task of the scenarios that have one: an item of the board, named as the tooling names one.
rigItem="dispatch-20261012T1200Z-rig"
rigTaskRef=""
rigReason="the rig reworks its report files"
rigStart(){ ## scenario directory name, optional `task`: the board holds the item of the task
	rigScenarioDir="$rigTmp/$1"
	rigSession="rig-folder-$1"
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

echo "-- the folder answer, by a click: the tool on everything in the folder of the refused file, for the session --"
rigStart click
rigFirst="$( rigRefused "$rigOut/reports/one.txt" )"
[ -n "$rigFirst" ] || rigRefuse "the rig produced no refusal to ask permission for"
rigThreadNow 1 file_folder
rigAskOne "$rigFirst"
rigAssert "his click on the folder is the answer: allow-folder, with a set grant of one entry for the member" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigVerdictLine ):$( rigLines "$rigScenarioDir/out" "GRANT: set 1 entries for $rigMember" )" \
	"no:ASK-RESULT: RECEIVED:VERDICT: allow-folder:1"
rigAssert "the first line of the post still says what the plain allow grants: that one call, and nothing wider" \
	"$( rigTextLine "$rigScenarioDir/post.1" "Allow **Write** on \`rig-out:reports/one.txt\` for **$rigMember**? An allow grants exactly that, and nothing wider." )" "yes"
rigAssert "under how to answer the plain answers stand as before, and one line says exactly what the folder click grants: the tool, the folder by its place, for this session" \
	"$( rigTextLine "$rigScenarioDir/post.1" '- click ❌ to deny, 1️⃣ to allow once, or 🔁 to allow for this session' ):$( rigTextLine "$rigScenarioDir/post.1" '- or click 📁 to allow **Write** on `rig-out:reports/**`, for this session' ):$( rigTextLine "$rigScenarioDir/post.1" '- or reply `deny`, `allow-once` or `allow-session`, or `allow-folder` for 📁' )" \
	"yes:yes:yes"
rigAssert "the folder stands on the post once, by its place, and no path of this machine is shown" \
	"$( rigTextCount "$rigScenarioDir/post.1" 'rig-out:reports/**' ):$( rigTextCount "$rigScenarioDir/post.1" '/dev/null' )" "1:0"
rigAssert "the folder emoji is placed with the three plain ones, by the bot; answered, it gets the answered mark, and the bot takes its own answer emoji off it" "$( rigEmoji 1 )" "x one repeat file_folder white_check_mark|x one repeat file_folder"
rigAssert "the request is still a single permission, closed with that verdict" "$( rigRecordCount ):$( rigRecordField kind ):$( rigRecordField status ):$( rigRecordField verdict )" "1:permission:reply-received:allow-folder"
rigAssert "what was granted is one entry of a set of the session, for the member whose call was refused: the tool for that folder" \
	"$( rigLines "$( rigSetFile )" 'scope: session' ):$( rigLines "$( rigSetFile )" "session-id: $rigSession" ):$( rigLines "$( rigSetFile )" "participants: $rigMember" ):$( rigStarts "$( rigSetFile )" 'entry: ' ):$( rigLines "$( rigSetFile )" "entry: Write:$rigOut/reports/**" )" \
	"1:1:1:1:1"
rigAssert "the confirmation says what was granted, the tool and the folder, in the thread of the post, by the bot" \
	"$( rigCalls chat.postMessage ):$( cat "$rigScenarioDir/posted-as.2" 2>/dev/null ):$( rigHolds "$rigScenarioDir/post.2" "\"thread_ts\":\"$( rigPostTs 1 )\"" ):$( rigHolds "$rigScenarioDir/post.2" "Read: \`allow-folder\` by human-owner. Granted: Write on rig-out:reports/** to $rigMember, for this session." )" \
	"2:$rigBotToken:yes:yes"
rigAssert "the refused file and every other file of that folder are granted for the session, and reading them follows from the write" \
	"$( rigGranted Write "$rigOut/reports/one.txt" ):$( rigGranted Write "$rigOut/reports/two.txt" ):$( rigGranted Read "$rigOut/reports/two.txt" ):$( rigGranted Grep "$rigOut/reports/deep/three.txt" )" \
	"session:session:session:session"
rigAssert "nothing wider: a file in another folder, the folder above, and another tool in that folder are not granted" \
	"$( rigGranted Write "$rigOut/other/x.txt" ):$( rigGranted Write "$rigOut/top.txt" ):$( rigGranted Edit "$rigOut/reports/two.txt" )" "none:none:none"
rigCall 60 Write "{\"path\":\"$rigOut/reports/two.txt\",\"content\":\"x\"}"
rigAssert "the next file in the folder is not asked: the call is refused no more" "$rigKilled:$( rigStarts "$rigScenarioDir/out" 'REFUSAL-ID: ' )" "no:0"
rigElse="$( rigRefused "$rigOut/other/x.txt" )"
rigAssert "a file in another folder is still refused, and so still asked" "$( [ -n "$rigElse" ] && printf refused || printf not-refused )" "refused"

echo "-- the folder answer, by a word --"
rigStart word
rigFirst="$( rigRefused "$rigOut/reports/one.txt" )"
rigThreadReply 1 'allow-folder'
rigAskOne "$rigFirst"
rigAssert "his reply allow-folder is the same answer: the folder for the session, confirmed with the tool and the folder" \
	"$rigKilled:$( rigVerdictLine ):$( rigGranted Write "$rigOut/reports/two.txt" ):$( rigGranted Write "$rigOut/other/x.txt" ):$( rigHolds "$rigScenarioDir/post.2" "Granted: Write on rig-out:reports/** to $rigMember, for this session." )" \
	"no:VERDICT: allow-folder:session:none:yes"

echo "-- where the folder cannot be right it is not offered, and is no answer where it is typed --"
rigStart no-place
rigFetch="$( rigLogged WebFetch 'https://rig.example/docs/a' )"
[ -n "$rigFetch" ] || rigRefuse "the rig recorded no refusal for a tool that has no place"
rigThreadReply 1 'allow-folder'
rigAskOne "$rigFetch"
rigAssert "a tool that has no place: the post names no folder and no folder click, and only the three plain emoji are placed" \
	"$( rigTextCount "$rigScenarioDir/post.1" '📁' ):$( rigTextCount "$rigScenarioDir/post.1" 'allow-folder' ):$( rigTextLine "$rigScenarioDir/post.1" '- or reply `deny`, `allow-once` or `allow-session`' ):$( rigEmoji 1 )" \
	"0:0:yes:x one repeat|"
rigAssert "typed all the same, it is no answer: the request comes back, stays open, and nothing is granted" \
	"$rigKilled:$( rigVerdictLine ):$( rigRecordField status ):$( [ -f "$( rigSetFile )" ] && printf set || printf no-set ):$( rigCalls chat.postMessage )" \
	"no:VERDICT: RETURNED:reply-pending:no-set:1"
## The coordinator's answer on behalf, from a session of its own.
( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD MDAT_SPAWN_SESSION_ID=rig-folder-coordinator MDAT_SPAWN_AGENT=magic-coordinator \
	MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigWs" bash "$rigTools" --magic-escalation-answer magic-coordinator "$( rigRecordId )" allow-folder ) \
	> "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err" ; rigOpRc=$?
rigAssert "given through the team operation it is refused too: no verdict of this request" \
	"$( [ "$rigOpRc" != 0 ] && printf refused || printf taken ):$( rigHolds "$rigScenarioDir/op.err" 'allow-folder is not a verdict of this permission' ):$( rigRecordField status )" "refused:yes:reply-pending"
rigAssert "what the folder answer would grant, as the operation says it: a file in a folder, its tool for that folder" \
	"$( rigFolderOf "$( rigLogged Edit "$rigOut/reports/one.txt" )" )" "Edit:$rigOut/reports/**|rig-out:reports/**"
rigAssert "a tool whose target is no path, a path with a .. segment, a target that is a pattern: none" \
	"$( rigFolderOf "$rigFetch" ):$( rigFolderOf "$( rigLogged Bash 'ls -la /dev/null/rig-folder/out' )" ):$( rigFolderOf "$( rigLogged Read "$rigOut/reports/../../far/x.txt" )" ):$( rigFolderOf "$( rigLogged Read "$rigOut/reports/**" )" )" \
	"none:none:none:none"
rigAssert "a write in a read-only place: none; a read there is offered, since reading is what such a place is for" \
	"$( rigFolderOf "$( rigLogged Write "$rigRo/notes/a.txt" )" ):$( rigFolderOf "$( rigLogged Read "$rigRo/notes/a.txt" )" )" "none:Read:$rigRo/notes/**|rig-ro:notes/**"
rigAssert "never a whole workspace: a file that lies in the root of one has no folder to offer; one a folder down has" \
	"$( rigFolderOf "$( rigLogged Read "$rigWs/top.txt" )" ):$( rigFolderOf "$( rigLogged Read "$rigWs/docs/top.txt" )" )" "none:Read:$rigWs/docs/**|rig-ws:docs/**"

echo "-- a prompt that offered the folder and takes a further call is a set: the folder click goes with the plain ones --"
rigStart joined
rigFirst="$( rigRefused "$rigOut/reports/one.txt" )"
rigAskOne "$rigFirst" 8
rigAssert "control: open, a single permission, with the folder click placed" "$rigKilled:$( rigRecordField kind ):$( rigEmoji 1 )" "yes:permission:x one repeat file_folder|"
rigSecond="$( rigRefused "$rigFar/docs/two.txt" )"
rigAskOne "$rigSecond" 8
rigAssert "joined by a second call it is a permission set: its post names no folder answer, and the folder click is taken off with the one and the repeat sign" \
	"$( rigRecordCount ):$( rigRecordField kind ):$( rigHolds "$rigScenarioDir/edit.$( rigPostTs 1 )" 'Permission set' ):$( rigHolds "$rigScenarioDir/edit.$( rigPostTs 1 )" '📁' ):$( rigEmoji 1 )" \
	"1:permission-set:yes:no:x one repeat file_folder unlock|one repeat file_folder"

echo "-- the verdict reader, asked directly: the folder click and word count only where the folder is offered --"
rigRead(){ ## offered (1 or empty), the rendered answers, one a line
	printf '%s\n' "$2" | MDAT_VERDICT_KIND=permission MDAT_VERDICT_FOLDER="$1" MDAT_VERDICT_AUTHORS=URIGOWNER MDAT_VERDICT_ASKING=URIGSELF1 \
		LC_ALL=C awk -f "$rigHere/questions/AgentsEscalationVerdict.awk" | LC_ALL=C tr '\t' '|' | LC_ALL=C cut -d'|' -f1-2
}
rigClick(){ ## reaction names of the owner...
	local clickName clickOut=""
	for clickName in "$@" ; do clickOut="$clickOut${clickOut:+$'\n'}reaction on the question: [reactions: $clickName x1 (URIGOWNER)]" ; done
	printf '%s' "$clickOut"
}
rigAssert "offered: the folder click is allow-folder, and so is the word, first on its line" \
	"$( rigRead 1 "$( rigClick file_folder )" ):$( rigRead 1 '1700000001.000200 | URIGOWNER | allow-folder' ):$( rigRead 1 '1700000001.000200 | URIGOWNER | Allow-Folder, the whole folder is fine' )" \
	"allow-folder|URIGOWNER:allow-folder|URIGOWNER:allow-folder|URIGOWNER"
rigAssert "two clicks never widen what one gives: the cross, the one and the repeat sign each win over the folder" \
	"$( rigRead 1 "$( rigClick file_folder x )" ):$( rigRead 1 "$( rigClick file_folder one )" ):$( rigRead 1 "$( rigClick file_folder repeat )" )" \
	"deny|URIGOWNER:allow-once|URIGOWNER:allow-session|URIGOWNER"
rigAssert "not offered: neither the click nor the word is an answer" \
	"$( rigRead '' "$( rigClick file_folder )" ):$( rigRead '' '1700000001.000200 | URIGOWNER | allow-folder' )" "RETURNED|:RETURNED|"
rigAssert "the folder click the tooling placed itself is never an answer" \
	"$( printf 'reaction on the question: [reactions: file_folder x1 (URIGSELF1)]\n' | MDAT_VERDICT_KIND=permission MDAT_VERDICT_FOLDER=1 MDAT_VERDICT_AUTHORS='URIGOWNER URIGSELF1' MDAT_VERDICT_ASKING=URIGSELF1 LC_ALL=C awk -f "$rigHere/questions/AgentsEscalationVerdict.awk" | LC_ALL=C tr '\t' '|' | LC_ALL=C cut -d'|' -f1-2 )" "RETURNED|"

echo "-- the filler, asked directly: the answers and the emoji of a post follow what it was filled with --"
rigFill(){ ## want, template, form -- the slots come from the caller's environment
	ASKP_WANT="$1" ASKP_FORM="$3" LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsToolingTemplateFill.awk" -f "$rigHere/questions/AgentsAskPostFill.awk" "$rigHere/templates/$2" 2>&1
}
rigAssert "with a folder the permission post places four emoji, the folder last; with none, the three as before" \
	"$( ASKP_F_folder='rig-out:reports/**' rigFill reactions request-permission.post.format.md grant | LC_ALL=C tr '\n' ' ' ):$( rigFill reactions request-permission.post.format.md grant | LC_ALL=C tr '\n' ' ' )" \
	"x one repeat file_folder :x one repeat "
rigAssert "a block of a form for one more field is taken only where that field has a value" \
	"$( ASKP_F_question='May I?' ASKP_F_refused_tool=Write ASKP_F_refused_target=/x/a ASKP_F_refused_for=me ASKP_F_refusal_id=refusal-1 ASKP_F_reason=why ASKP_F_task=t ASKP_F_folder='/x/**' rigFill post request-permission.post.format.md grant | LC_ALL=C grep -c -F -- '- or click 📁 to allow **Write** on `/x/**`, for this session' ):$( ASKP_F_question='May I?' ASKP_F_refused_tool=Write ASKP_F_refused_target=/x/a ASKP_F_refused_for=me ASKP_F_refusal_id=refusal-1 ASKP_F_reason=why ASKP_F_task=t rigFill post request-permission.post.format.md grant | LC_ALL=C grep -c -F -- '📁' )" \
	"1:0"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION FOLDER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_PERMISSION_FOLDER: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
