#!/usr/bin/env bash
## Behavioural check on the project answer of a single permission, run through --intern-tool,
## the path the myx.distro MCP uses. Covers: a permission asked for one refused file that lies in
## a project of a workspace's source tree -- the nearest folder, at or above the file, that holds
## a project.inf -- offers one more answer beside the folder's, by a click and by a word: the
## tool of the refused call on everything in that project, for the session; the post says
## exactly that on a line of its own, the tool, the project by its place and for how long, and
## its first line still says what the plain allow grants; the answer is a one-entry set grant
## of the session for the member whose call was refused, so a file in another folder of the
## project is not refused afterwards, and neither is the project's own project.inf, while a
## file of another project, or another tool, still is; the confirmation says the tool and the
## project; what is granted is worked out from the refusal record when the answer is applied,
## never from the post; where the project is the very folder of the file only the folder
## answer is offered, since the two would grant the same; it is not offered, and is no answer
## where it is typed or clicked, where no project is found in a source tree or the folder
## answer itself cannot be right; a read in a read-only place is offered; a prompt that
## offered it and takes a further call loses its click with the others; and the verdict
## reader and the filler, each asked directly.
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists nothing of the host is
## beside it, and every scenario runs in its own workspace under this check's temp tree, in
## $MMDAPP/.local/temp. What is written is written in that tree only.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessPermissionProjectCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp" "$rigTmp/home"
## A RIG HOME: the workspaces this machine knows are then the scenario's own two and no other,
## so the floor every member holds, a write of each known workspace's .local/temp, does not
## reach the rig tree, which lies in this workspace's .local/temp, and a write in the rig's
## source tree is refused as one in a real source tree is.
HOME="$rigTmp/home"
export HOME
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
## Where the refused calls point, set by rigStart: the source tree of the scenario's own
## workspace, which holds two projects (a project.inf each), a folder under no project and a
## project that is a read-only place; a folder with a project.inf outside the source tree; and
## the source tree of a second workspace the scenario registers. Nothing the rig's member holds
## reaches a write there.
rigTree=""
rigA=""
rigB=""
rigLoose=""
rigRo=""
rigAside=""
rigWs2=""
## The task of the scenarios that have one: an item of the board, named as the tooling names one.
rigItem="dispatch-20261012T1200Z-rig"
rigTaskRef=""
rigReason="the rig reworks its report files"
rigStart(){ ## scenario directory name, optional `task`: the board holds the item of the task
	rigScenarioDir="$rigTmp/$1"
	rigSession="rig-project-$1"
	rigWs="$rigScenarioDir/ws"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigWs/IN" "$rigScenarioDir/data/board/running"
	rigTree="$rigWs/source"
	rigA="$rigTree/rig/proj-a" ; rigB="$rigTree/rig/proj-b" ; rigLoose="$rigTree/rig/loose" ; rigRo="$rigTree/rig/proj-ro"
	rigAside="$rigWs/aside/proj-x" ; rigWs2="$rigScenarioDir/ws2"
	mkdir -p "$rigA/lib" "$rigA/conf" "$rigA/sub/lib" "$rigB/lib" "$rigLoose/notes" "$rigRo/lib" "$rigAside/lib" "$rigWs2/source/far/proj-c/lib"
	for rigInf in "$rigA" "$rigA/sub" "$rigB" "$rigRo" "$rigAside" "$rigWs2/source/far/proj-c" ; do
		printf 'Name: %s\n' "${rigInf##*/}" > "$rigInf/project.inf"
	done
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=%s\n' "$rigBotToken" \
		> "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=%s\n' "$rigOwnToken" > "$rigWs/.local/.agents/$rigMember.agent.env"
	## Places by name: the workspace itself, a second workspace, and a project that is read-only.
	printf '%s\t%s\t%s\t%s\t%s\n' rig-ws workspace read-write "$rigWs" workspace rig-ws2 workspace read-write "$rigWs2" owner rig-ro directory read-only "$rigRo" owner \
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
## What the project answer of one refusal would grant, as the operation says it:
## "<entry>|<as a post shows it>", or "none".
rigProjectOf(){ ## refusal id
	rigOp --intern-op-permission-folder "$rigMember" --session-id "$rigSession" --refusal-id "$1"
	LC_ALL=C awk '/^PROJECT-ENTRY: / { entry = substr( $0, 16 ) ; } /^PROJECT-SHOWN: / { shown = substr( $0, 16 ) ; } END { if ( entry == "" ) { print "none" ; } else { print entry "|" shown ; } }' "$rigScenarioDir/op.out"
}
## And what the folder answer of it would grant, the entry alone, or "none".
rigFolderOf(){ ## refusal id
	rigOp --intern-op-permission-folder "$rigMember" --session-id "$rigSession" --refusal-id "$1"
	LC_ALL=C awk '/^ENTRY: / { entry = substr( $0, 8 ) ; } END { print ( entry == "" ? "none" : entry ) ; }' "$rigScenarioDir/op.out"
}
## A call the harness refuses: prints its refusal id, or nothing where it was not refused.
rigRefusedCall(){ ## tool, argument object
	rigCall 60 "$1" "$2"
	rigRefusal "$rigScenarioDir/out"
}
## How many posts of the scenario hold one text.
rigPostsWith(){ ## text
	local postFile postCount=0
	for postFile in "$rigScenarioDir"/post.* ; do
		[ -f "$postFile" ] || continue
		case "$( cat "$postFile" )" in
			*"$1"*) postCount=$(( postCount + 1 )) ;;
		esac
	done
	printf '%s' "$postCount"
}
## The answer of a request that is already posted and open: the same call again by its id.
rigRewait(){ ## which record (default the first)
	rigCall 120 RequestPermission "{\"pending_id\":\"$( rigRecordId "${1:-1}" )\"}"
}

echo "-- the project answer, by a click: the tool on everything in the project of the refused file, for the session --"
rigStart click
rigFirst="$( rigRefused "$rigA/lib/one.txt" )"
[ -n "$rigFirst" ] || rigRefuse "the rig produced no refusal to ask permission for"
rigThreadNow 1 building_construction
rigAskOne "$rigFirst"
rigAssert "his click on the project is the answer: allow-project, with a set grant of one entry for the member" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigVerdictLine ):$( rigLines "$rigScenarioDir/out" "GRANT: set 1 entries for $rigMember" )" \
	"no:ASK-RESULT: RECEIVED:VERDICT: allow-project:1"
rigAssert "the first line of the post still says what the plain allow grants: that one call, and nothing wider" \
	"$( rigTextLine "$rigScenarioDir/post.1" "Allow **Write** on \`rig-ws:source/rig/proj-a/lib/one.txt\` for **$rigMember**? An allow grants exactly that, and nothing wider." )" "yes"
rigAssert "under how to answer the plain answers and the folder line stand as before, and one line of its own says exactly what the project click grants: the tool, the project by its place, for this session" \
	"$( rigTextLine "$rigScenarioDir/post.1" '- click ❌ to deny, 1️⃣ to allow once, or 🔁 to allow for this session' ):$( rigTextLine "$rigScenarioDir/post.1" '- or click 📁 to allow **Write** on `rig-ws:source/rig/proj-a/lib/**`, for this session' ):$( rigTextLine "$rigScenarioDir/post.1" '- or click 🏗️ to allow **Write** on the project `rig-ws:source/rig/proj-a/**`, for this session' ):$( rigTextLine "$rigScenarioDir/post.1" '- or reply `deny`, `allow-once` or `allow-session`, `allow-folder` for 📁, or `allow-project` for 🏗️' )" \
	"yes:yes:yes:yes"
rigAssert "the project stands on the post once, by its place, and no path of this machine is shown" \
	"$( rigTextCount "$rigScenarioDir/post.1" 'rig-ws:source/rig/proj-a/**' ):$( rigTextCount "$rigScenarioDir/post.1" "$rigTmp" )" "1:0"
rigAssert "the project emoji is placed after the folder one, by the bot; answered, it gets the answered mark, and the bot takes its own answer emoji off it" "$( rigEmoji 1 )" "x one repeat file_folder building_construction white_check_mark|x one repeat file_folder building_construction"
rigAssert "the request is still a single permission, closed with that verdict" "$( rigRecordCount ):$( rigRecordField kind ):$( rigRecordField status ):$( rigRecordField verdict )" "1:permission:reply-received:allow-project"
rigAssert "what was granted is one entry of a set of the session, for the member whose call was refused: the tool for that project" \
	"$( rigLines "$( rigSetFile )" 'scope: session' ):$( rigLines "$( rigSetFile )" "session-id: $rigSession" ):$( rigLines "$( rigSetFile )" "participants: $rigMember" ):$( rigStarts "$( rigSetFile )" 'entry: ' ):$( rigLines "$( rigSetFile )" "entry: Write:$rigA/**" )" \
	"1:1:1:1:1"
rigAssert "the confirmation says what was granted, the tool and the project, in the thread of the post, by the bot" \
	"$( rigCalls chat.postMessage ):$( cat "$rigScenarioDir/posted-as.2" 2>/dev/null ):$( rigHolds "$rigScenarioDir/post.2" "\"thread_ts\":\"$( rigPostTs 1 )\"" ):$( rigHolds "$rigScenarioDir/post.2" "Read: \`allow-project\` by human-owner. Granted: Write on rig-ws:source/rig/proj-a/** to $rigMember, for this session." )" \
	"2:$rigBotToken:yes:yes"
rigAssert "the refused file, a file in another folder of the project, however deep, and one in a project nested in it are granted for the session, and reading follows from the write" \
	"$( rigGranted Write "$rigA/lib/one.txt" ):$( rigGranted Write "$rigA/conf/two.txt" ):$( rigGranted Write "$rigA/conf/deep/er/three.txt" ):$( rigGranted Write "$rigA/sub/lib/four.txt" ):$( rigGranted Read "$rigA/conf/two.txt" )" \
	"session:session:session:session:session"
rigAssert "project.inf included: the project's own project.inf is granted as every file beside it" "$( rigGranted Write "$rigA/project.inf" ):$( rigGranted Read "$rigA/project.inf" )" "session:session"
rigAssert "nothing wider: a file of another project, the folder above the project, and another tool in the project are not granted" \
	"$( rigGranted Write "$rigB/lib/x.txt" ):$( rigGranted Write "$rigB/project.inf" ):$( rigGranted Write "$rigTree/rig/top.txt" ):$( rigGranted Edit "$rigA/lib/one.txt" )" "none:none:none:none"
rigCall 60 Write "{\"path\":\"$rigA/conf/two.txt\",\"content\":\"x\"}"
rigAssert "a file in another folder of the same project is not refused afterwards: it is written" \
	"$rigKilled:$( rigStarts "$rigScenarioDir/out" 'REFUSAL-ID: ' ):$( rigLines "$rigScenarioDir/out" "OK: wrote $rigA/conf/two.txt" ):$( cat "$rigA/conf/two.txt" 2>/dev/null )" "no:0:1:x"
rigCall 60 Write "{\"path\":\"$rigA/project.inf\",\"content\":\"Name: proj-a, as the rig wrote it\"}"
rigAssert "a write to the project's project.inf is not refused: it is written" \
	"$rigKilled:$( rigStarts "$rigScenarioDir/out" 'REFUSAL-ID: ' ):$( rigLines "$rigScenarioDir/out" "OK: wrote $rigA/project.inf" ):$( cat "$rigA/project.inf" 2>/dev/null )" "no:0:1:Name: proj-a, as the rig wrote it"
rigElse="$( rigRefused "$rigB/lib/x.txt" )"
rigAssert "a file of another project is still refused, and nothing is written there" "$( [ -n "$rigElse" ] && printf refused || printf not-refused ):$( [ -e "$rigB/lib/x.txt" ] && printf written || printf not-written )" "refused:not-written"
rigElse="$( rigRefusedCall Edit "{\"path\":\"$rigA/conf/two.txt\",\"old_string\":\"x\",\"new_string\":\"y\"}" )"
rigAssert "another tool is still refused in the project, and the file stays as it was" "$( [ -n "$rigElse" ] && printf refused || printf not-refused ):$( cat "$rigA/conf/two.txt" 2>/dev/null )" "refused:x"

echo "-- the project answer, by a word --"
rigStart word
rigFirst="$( rigRefused "$rigA/lib/one.txt" )"
rigThreadReply 1 'allow-project'
rigAskOne "$rigFirst"
rigAssert "his reply allow-project is the same answer: the project for the session, confirmed with the tool and the project" \
	"$rigKilled:$( rigVerdictLine ):$( rigGranted Write "$rigA/conf/two.txt" ):$( rigGranted Write "$rigA/project.inf" ):$( rigGranted Write "$rigB/lib/x.txt" ):$( rigHolds "$rigScenarioDir/post.2" "Granted: Write on rig-ws:source/rig/proj-a/** to $rigMember, for this session." )" \
	"no:VERDICT: allow-project:session:session:none:yes"

echo "-- the folder answer of the same prompt is what it was: the folder, and not the project --"
rigStart folder
rigFirst="$( rigRefused "$rigA/lib/one.txt" )"
rigThreadNow 1 file_folder
rigAskOne "$rigFirst"
rigAssert "his click on the folder grants the folder of the file, and no other folder of the project" \
	"$rigKilled:$( rigVerdictLine ):$( rigLines "$( rigSetFile )" "entry: Write:$rigA/lib/**" ):$( rigGranted Write "$rigA/lib/two.txt" ):$( rigGranted Write "$rigA/conf/two.txt" ):$( rigGranted Write "$rigA/project.inf" )" \
	"no:VERDICT: allow-folder:1:session:none:none"

echo "-- what is granted is worked out from the refusal record when the answer is applied, never from the post --"
rigStart at-apply
rigFirst="$( rigRefused "$rigA/lib/one.txt" )"
rigAskOne "$rigFirst" 8
rigAssert "control: open, a single permission, with the project click placed" "$rigKilled:$( rigRecordField kind ):$( rigRecordField status ):$( rigEmoji 1 )" "yes:permission:reply-pending:x one repeat file_folder building_construction|"
## What the post was filled with is changed beside the record, as if the post had named more.
rigKept="$( rigRecordFile )" ; rigKept="${rigKept%.md}.fields"
LC_ALL=C awk -F'\t' -v OFS='\t' '$1 == "project" { $2 = "rig-ws:source/**" ; changed = 1 ; } { print ; } END { exit ! changed ; }' "$rigKept" > "$rigKept.rig" && mv -f "$rigKept.rig" "$rigKept" || rm -f "$rigKept.rig"
rigAssert "control: the kept slots of the post now name the whole source tree as its project" "$( LC_ALL=C awk -F'\t' '$1 == "project" { print $2 ; found = 1 ; } END { if ( ! found ) { print "none" ; } }' "$rigKept" 2>/dev/null )" "rig-ws:source/**"
rigThreadNow 1 building_construction
rigRewait
rigAssert "with the kept slots of the post naming the whole source tree, the grant is still the project of the refused file, and nothing beside it" \
	"$rigKilled:$( rigVerdictLine ):$( rigStarts "$( rigSetFile )" 'entry: ' ):$( rigLines "$( rigSetFile )" "entry: Write:$rigA/**" ):$( rigGranted Write "$rigA/conf/two.txt" ):$( rigGranted Write "$rigB/lib/x.txt" )" \
	"no:VERDICT: allow-project:1:1:session:none"
rigStart gone
rigFirst="$( rigRefused "$rigA/lib/one.txt" )"
rigAskOne "$rigFirst" 8
rigAssert "control: open, with the project click placed" "$rigKilled:$( rigRecordField status ):$( rigEmoji 1 )" "yes:reply-pending:x one repeat file_folder building_construction|"
## The project is no project any more when he answers: its project.inf is gone.
rm -f "$rigA/project.inf"
rigThreadNow 1 building_construction
rigRewait
rigAssert "a project that is none any more when he answers is not granted: the request comes back, stays open, and nothing is granted" \
	"$rigKilled:$( rigVerdictLine ):$( rigRecordField status ):$( [ -f "$( rigSetFile )" ] && printf set || printf no-set ):$( rigGranted Write "$rigA/conf/two.txt" )" \
	"no:VERDICT: RETURNED:reply-pending:no-set:none"
rigAssert "and he is told so in the thread, once: read, not applied, and why" \
	"$( rigPostsWith "Read: \`allow-project\` by human-owner, and it could not be applied: nothing is granted, and the question stays open. This request offers no project that can be allowed." )" "1"
rigStart folder-gone
rigFirst="$( rigRefused "$rigA/lib/one.txt" )"
rigAskOne "$rigFirst" 8
## The refusal the request was asked for is gone when he answers: nothing says what its folder is.
rm -f "$rigWs/.local/agents/sessions/$rigSession/$rigFirst.md"
rigThreadNow 1 file_folder
rigRewait
rigAssert "a folder answer that names nothing to grant when it is applied is told in the words it always had" \
	"$rigKilled:$( rigVerdictLine ):$( rigRecordField status ):$( rigPostsWith "Read: \`allow-folder\` by human-owner, and it could not be applied: nothing is granted, and the question stays open. This request offers no folder that can be allowed." )" \
	"no:VERDICT: RETURNED:reply-pending:1"

echo "-- where the project is the very folder of the refused file, only the folder answer is offered: the two would grant the same --"
rigStart same
rigFirst="$( rigRefused "$rigA/top.txt" )"
rigThreadReply 1 'allow-project'
rigAskOne "$rigFirst"
rigAssert "the post offers the folder, which is the project, and names no project answer; the four emoji of a folder prompt are placed" \
	"$( rigTextLine "$rigScenarioDir/post.1" '- or click 📁 to allow **Write** on `rig-ws:source/rig/proj-a/**`, for this session' ):$( rigTextLine "$rigScenarioDir/post.1" '- or reply `deny`, `allow-once` or `allow-session`, or `allow-folder` for 📁' ):$( rigTextCount "$rigScenarioDir/post.1" '🏗️' ):$( rigTextCount "$rigScenarioDir/post.1" 'allow-project' ):$( rigEmoji 1 )" \
	"yes:yes:0:0:x one repeat file_folder|"
rigAssert "typed all the same, allow-project is no answer there: the request comes back, stays open, and nothing is granted" \
	"$rigKilled:$( rigVerdictLine ):$( rigRecordField status ):$( [ -f "$( rigSetFile )" ] && printf set || printf no-set ):$( rigCalls chat.postMessage )" \
	"no:VERDICT: RETURNED:reply-pending:no-set:1"
## The coordinator's answer on behalf, from a session of its own.
( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD MDAT_SPAWN_SESSION_ID=rig-project-coordinator MDAT_SPAWN_AGENT=magic-coordinator \
	MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigWs" bash "$rigTools" --magic-escalation-answer magic-coordinator "$( rigRecordId )" allow-project ) \
	> "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err" ; rigOpRc=$?
rigAssert "given through the team operation it is refused too: no verdict of this request" \
	"$( [ "$rigOpRc" != 0 ] && printf refused || printf taken ):$( rigHolds "$rigScenarioDir/op.err" 'allow-project is not a verdict of this permission' ):$( rigRecordField status )" "refused:yes:reply-pending"
rigStart same-folder
rigFirst="$( rigRefused "$rigA/top.txt" )"
rigThreadNow 1 file_folder
rigAskOne "$rigFirst"
rigAssert "the folder answer there grants the whole project, its project.inf included, and no other project" \
	"$rigKilled:$( rigVerdictLine ):$( rigLines "$( rigSetFile )" "entry: Write:$rigA/**" ):$( rigGranted Write "$rigA/conf/two.txt" ):$( rigGranted Write "$rigA/project.inf" ):$( rigGranted Write "$rigB/lib/x.txt" )" \
	"no:VERDICT: allow-folder:1:session:session:none"

echo "-- where no project is found, or the folder answer cannot be right, the project is not offered --"
rigStart limits
rigAssert "what the project answer would grant, as the operation says it: a file in a folder of a project, its tool for the project, beside the folder" \
	"$( rigProjectOf "$( rigLogged Edit "$rigA/lib/one.txt" )" ):$( rigFolderOf "$( rigLogged Edit "$rigA/lib/one.txt" )" )" "Edit:$rigA/**|rig-ws:source/rig/proj-a/**:Edit:$rigA/lib/**"
rigAssert "the nearest project at or above the file: one nested in another is the project of its own files, and its own folder is offered as the folder alone" \
	"$( rigProjectOf "$( rigLogged Read "$rigA/sub/lib/a.txt" )" ):$( rigProjectOf "$( rigLogged Read "$rigA/sub/a.txt" )" ):$( rigFolderOf "$( rigLogged Read "$rigA/sub/a.txt" )" )" \
	"Read:$rigA/sub/**|rig-ws:source/rig/proj-a/sub/**:none:Read:$rigA/sub/**"
rigAssert "a target that is a folder: the project above it; the project folder itself is offered as the folder alone" \
	"$( rigProjectOf "$( rigLogged Glob "$rigA/lib" )" ):$( rigProjectOf "$( rigLogged Glob "$rigA" )" ):$( rigFolderOf "$( rigLogged Glob "$rigA" )" )" \
	"Glob:$rigA/**|rig-ws:source/rig/proj-a/**:none:Glob:$rigA/**"
rigAssert "a file under no project of the source tree: none, and its folder is still offered" \
	"$( rigProjectOf "$( rigLogged Read "$rigLoose/notes/a.txt" )" ):$( rigFolderOf "$( rigLogged Read "$rigLoose/notes/a.txt" )" ):$( rigProjectOf "$( rigLogged Read "$rigTree/rig/top.txt" )" )" \
	"none:Read:$rigLoose/notes/**:none"
printf 'Name: the whole tree\n' > "$rigTree/project.inf"
rigAssert "never the whole source tree: a project.inf in the root of the tree makes no project of it" \
	"$( rigProjectOf "$( rigLogged Read "$rigLoose/notes/a.txt" )" ):$( rigProjectOf "$( rigLogged Read "$rigTree/rig/top.txt" )" )" "none:none"
rm -f "$rigTree/project.inf"
rigAssert "a folder that holds a project.inf outside the source tree of a workspace is no project: none, and its folder is still offered" \
	"$( rigProjectOf "$( rigLogged Read "$rigAside/lib/a.txt" )" ):$( rigFolderOf "$( rigLogged Read "$rigAside/lib/a.txt" )" )" "none:Read:$rigAside/lib/**"
rigAssert "a project of another workspace this machine knows is offered as one of this workspace is" \
	"$( rigProjectOf "$( rigLogged Read "$rigWs2/source/far/proj-c/lib/a.txt" )" )" "Read:$rigWs2/source/far/proj-c/**|rig-ws2:source/far/proj-c/**"
rigAssert "a tool whose target is no path, a path with a .. segment, a target that is a pattern: none" \
	"$( rigProjectOf "$( rigLogged WebFetch 'https://rig.example/docs/a' )" ):$( rigProjectOf "$( rigLogged Bash "ls -la $rigA/lib" )" ):$( rigProjectOf "$( rigLogged Read "$rigA/lib/../../proj-b/lib/x.txt" )" ):$( rigProjectOf "$( rigLogged Read "$rigA/lib/**" )" )" \
	"none:none:none:none"
rigAssert "a write in a read-only place: none, of the project and of the folder; a read there is offered, since reading is what such a place is for" \
	"$( rigProjectOf "$( rigLogged Write "$rigRo/lib/a.txt" )" ):$( rigFolderOf "$( rigLogged Write "$rigRo/lib/a.txt" )" ):$( rigProjectOf "$( rigLogged Read "$rigRo/lib/a.txt" )" )" "none:none:Read:$rigRo/**|rig-ro:**"

echo "-- a prompt that offered the project and takes a further call is a set: the project click goes with the others --"
rigStart joined
rigFirst="$( rigRefused "$rigA/lib/one.txt" )"
rigAskOne "$rigFirst" 8
rigAssert "control: open, a single permission, with the folder and the project click placed" "$rigKilled:$( rigRecordField kind ):$( rigEmoji 1 )" "yes:permission:x one repeat file_folder building_construction|"
rigSecond="$( rigRefused "$rigB/lib/two.txt" )"
rigAskOne "$rigSecond" 8
rigAssert "joined by a second call it is a permission set: its post names no project answer, and the project click is taken off with the folder, the one and the repeat sign" \
	"$( rigRecordCount ):$( rigRecordField kind ):$( rigHolds "$rigScenarioDir/edit.$( rigPostTs 1 )" 'Permission set' ):$( rigHolds "$rigScenarioDir/edit.$( rigPostTs 1 )" '🏗️' ):$( rigEmoji 1 )" \
	"1:permission-set:yes:no:x one repeat file_folder building_construction unlock|one repeat file_folder building_construction"

echo "-- the verdict reader, asked directly: the project click and word count only where the project is offered --"
rigRead(){ ## folder offered (1 or empty), project offered (1 or empty), the rendered answers, one a line
	printf '%s\n' "$3" | MDAT_VERDICT_KIND=permission MDAT_VERDICT_FOLDER="$1" MDAT_VERDICT_PROJECT="$2" MDAT_VERDICT_AUTHORS=URIGOWNER MDAT_VERDICT_ASKING=URIGSELF1 \
		LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" | LC_ALL=C tr '\t' '|' | LC_ALL=C cut -d'|' -f1-2
}
rigClick(){ ## reaction names of the owner...
	local clickName clickOut=""
	for clickName in "$@" ; do clickOut="$clickOut${clickOut:+$'\n'}reaction on the question: [reactions: $clickName x1 (URIGOWNER)]" ; done
	printf '%s' "$clickOut"
}
rigAssert "offered: the project click is allow-project, and so is the word, first on its line" \
	"$( rigRead 1 1 "$( rigClick building_construction )" ):$( rigRead 1 1 '1700000001.000200 | URIGOWNER | allow-project' ):$( rigRead 1 1 '1700000001.000200 | URIGOWNER | Allow-Project, the whole project is fine' )" \
	"allow-project|URIGOWNER:allow-project|URIGOWNER:allow-project|URIGOWNER"
rigAssert "two clicks never widen what one gives: the cross, the one, the repeat sign and the folder each win over the project" \
	"$( rigRead 1 1 "$( rigClick building_construction x )" ):$( rigRead 1 1 "$( rigClick building_construction one )" ):$( rigRead 1 1 "$( rigClick building_construction repeat )" ):$( rigRead 1 1 "$( rigClick building_construction file_folder )" )" \
	"deny|URIGOWNER:allow-once|URIGOWNER:allow-session|URIGOWNER:allow-folder|URIGOWNER"
rigAssert "not offered, with the folder offered: neither the click nor the word is an answer, and the folder answers as before" \
	"$( rigRead 1 '' "$( rigClick building_construction )" ):$( rigRead 1 '' '1700000001.000200 | URIGOWNER | allow-project' ):$( rigRead 1 '' "$( rigClick file_folder )" ):$( rigRead 1 '' '1700000001.000200 | URIGOWNER | allow-folder' )" \
	"RETURNED|:RETURNED|:allow-folder|URIGOWNER:allow-folder|URIGOWNER"
rigAssert "the project click the tooling placed itself is never an answer" \
	"$( printf 'reaction on the question: [reactions: building_construction x1 (URIGSELF1)]\n' | MDAT_VERDICT_KIND=permission MDAT_VERDICT_FOLDER=1 MDAT_VERDICT_PROJECT=1 MDAT_VERDICT_AUTHORS='URIGOWNER URIGSELF1' MDAT_VERDICT_ASKING=URIGSELF1 LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" | LC_ALL=C tr '\t' '|' | LC_ALL=C cut -d'|' -f1-2 )" "RETURNED|"
rigAssert "a permission set takes neither: its own answers only" \
	"$( printf '%s\n' "$( rigClick building_construction )" | MDAT_VERDICT_KIND=permission-set MDAT_VERDICT_PROJECT=1 MDAT_VERDICT_AUTHORS=URIGOWNER MDAT_VERDICT_ASKING=URIGSELF1 LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" | LC_ALL=C tr '\t' '|' | LC_ALL=C cut -d'|' -f1-2 ):$( printf '1700000001.000200 | URIGOWNER | allow-project\n' | MDAT_VERDICT_KIND=permission-set MDAT_VERDICT_PROJECT=1 MDAT_VERDICT_AUTHORS=URIGOWNER MDAT_VERDICT_ASKING=URIGSELF1 LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" | LC_ALL=C tr '\t' '|' | LC_ALL=C cut -d'|' -f1-2 )" \
	"RETURNED|:RETURNED|"

echo "-- the filler, asked directly: the answers and the emoji of a post follow what it was filled with --"
rigFill(){ ## want, template, form -- the slots come from the caller's environment
	ASKP_WANT="$1" ASKP_FORM="$3" LC_ALL=C awk -f "$rigHere/AgentsToolingTemplateFill.awk" -f "$rigHere/AgentsAskPostFill.awk" "$rigHere/templates/$2" 2>&1
}
rigAssert "with a folder and a project the permission post places five emoji, the project last; with the folder alone four; with none, the three as before" \
	"$( ASKP_F_folder='rig-ws:a/b/**' ASKP_F_project='rig-ws:a/**' rigFill reactions request-permission.post.format.md grant | LC_ALL=C tr '\n' ' ' ):$( ASKP_F_folder='rig-ws:a/b/**' rigFill reactions request-permission.post.format.md grant | LC_ALL=C tr '\n' ' ' ):$( rigFill reactions request-permission.post.format.md grant | LC_ALL=C tr '\n' ' ' )" \
	"x one repeat file_folder building_construction :x one repeat file_folder :x one repeat "
rigAssert "a block of a form that names two fields is taken only where both have a value: a project with no folder is not offered" \
	"$( ASKP_F_project='rig-ws:a/**' rigFill reactions request-permission.post.format.md grant | LC_ALL=C tr '\n' ' ' )" "x one repeat "
rigSlots(){ ## want, the folder, the project -- a permission post of the template, filled
	ASKP_F_question='May I?' ASKP_F_refused_tool=Write ASKP_F_refused_target=/x/a/b ASKP_F_refused_for=me ASKP_F_refusal_id=refusal-1 ASKP_F_reason=why ASKP_F_task=t ASKP_F_folder="$2" ASKP_F_project="$3" \
		rigFill "$1" request-permission.post.format.md grant
}
rigAssert "the answers of a post with both name each on a line of its own, and the reply line names both words; with the folder alone its lines are as they were" \
	"$( rigSlots post '/x/a/**' '/x/**' | LC_ALL=C grep -c -x -F -- '- or click 📁 to allow **Write** on `/x/a/**`, for this session' ):$( rigSlots post '/x/a/**' '/x/**' | LC_ALL=C grep -c -x -F -- '- or click 🏗️ to allow **Write** on the project `/x/**`, for this session' ):$( rigSlots post '/x/a/**' '/x/**' | LC_ALL=C grep -c -x -F -- '- or reply `deny`, `allow-once` or `allow-session`, `allow-folder` for 📁, or `allow-project` for 🏗️' ):$( rigSlots post '/x/a/**' '' | LC_ALL=C grep -c -x -F -- '- or reply `deny`, `allow-once` or `allow-session`, or `allow-folder` for 📁' ):$( rigSlots post '/x/a/**' '' | LC_ALL=C grep -c -F -- '🏗️' )" \
	"1:1:1:1:0"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION PROJECT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_PERMISSION_PROJECT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
