#!/usr/bin/env bash
## Behavioural check on several permissions of one session reaching the human-owner as one
## prompt, run through --intern-tool, the path the myx.distro MCP uses. Covers: while a
## permission question of a session to the human-owner is open and unanswered, a further
## refused call of that session makes no new post; it is added to the open one, which becomes
## a Permission set of that session: its post edited in place to the set's own text, every
## call on it by tool and place, its answer emoji changed to the set's, its record and its
## `.set` keeping each call and the refusal it came from; a third call joins the same way;
## one allow-set grants every call listed and nothing else, one deny grants none, and both
## are confirmed once in the thread; the asking call says the call was added; a prompt that
## is answered takes no further call, and neither does one an answer reached while the call
## was being added: the answer is applied to the prompt as it was asked, the post is put
## back, and the new call, one more asked alone for the same task once he has answered, is
## not posted at all: it comes back as a correction; a call the open prompt asks for already is
## not asked again; a call of another session, and one whose target a set would read as a
## pattern, are prompts of their own; and the whole prompt is withdrawn as a set is.
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists nothing of the host is
## beside it, and every scenario runs in its own workspace under this check's temp tree, in
## $MMDAPP/.local/temp.
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
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.test.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.test.sh"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessPermissionJoinCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.test.sh" "$rigTmp/bin/curl.fixture" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl.fixture"
## THE OWNER ANSWERS LATER. The curl first on PATH is the fixture with one thing ahead of it: a
## scenario can keep the thread the owner has answered in aside (replies.later.json), and name
## a file (replies.later.when, a glob). From the first call made once that file exists, the
## thread served is the later one. So an answer arrives at one known point of a call, never by
## a clock: after the call was written to the record, or after the post was edited.
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
rigCallsAs(){ ## method, token, optional rest of the line (a reaction's "<ts> <name>")
	LC_ALL=C awk -v wantCall="$1 $2${3:+ $3}" '$0 == wantCall { hitCount++ ; } END { print hitCount + 0 ; }' "$rigScenarioDir/calls" 2>/dev/null || printf 'no-such-log'
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
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
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

rigBotToken="rig-bot-token-TEAM"
rigOwnToken="rig-user-token-TESTER"
rigScenarioDir=""
rigScenarioName=""
rigSession=""
rigStart(){ ## scenario directory name
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	rigSession="rig-join-$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/IN" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=%s\n' "$rigBotToken" \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=%s\n' "$rigOwnToken" > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
	rigThreadNow ""
}
## The thread of the scenario's first post as conversations.replies returns it, with what the
## owner has put on it: nothing, or his click.
rigThreadJson(){ ## the owner's reaction name, or empty
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"first"%s}],"has_more":false}\n' \
		"${1:+,\"reactions\":[{\"name\":\"$1\",\"count\":2,\"users\":[\"URIGSELF1\",\"URIGOWNER\"]}]}"
}
rigThreadNow(){ ## the owner's reaction name, or empty
	rm -f "$rigScenarioDir/replies.later.json" "$rigScenarioDir/replies.later.when"
	rigThreadJson "$1" > "$rigScenarioDir/replies.json"
}
## The owner clicks once a file exists: the thread with his click is kept aside until then.
rigThreadLater(){ ## the owner's reaction name, the file (a glob) his click waits for
	rigThreadJson "$1" > "$rigScenarioDir/replies.later.json"
	printf '%s\n' "$2" > "$rigScenarioDir/replies.later.when"
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
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD \
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID="$rigSession" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
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
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		TMPDIR="$rigTmp/tmp" MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" bash "$rigTools" "$@" ) > "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err" || rigOpRc=$?
}
## A write the harness refuses: prints its refusal id.
rigRefused(){ ## path
	rigCall 60 Write "{\"path\":\"$1\",\"content\":\"x\"}"
	rigRefusal "$rigScenarioDir/out"
}
## The permission for one refusal asked of the human-owner. With a quiet time it is a call
## nobody answers, ended by the rig once it has done nothing but wait for that long.
rigAsk(){ ## refusal id, the question, optional quiet seconds
	if [ -n "${3:-}" ] ; then
		rigCall "$3" RequestPermission "{\"to\":\"human-owner\",\"question\":\"$2\",\"refusal_id\":\"$1\",\"reason\":\"the rig needs it for $2\",\"task_ref\":\"dispatch-rig\"}" settle
	else
		rigCall 120 RequestPermission "{\"to\":\"human-owner\",\"question\":\"$2\",\"refusal_id\":\"$1\",\"reason\":\"the rig needs it for $2\",\"task_ref\":\"dispatch-rig\"}"
	fi
}
## Whether the session holds a grant for one write: the first word after GRANT:, or none.
rigGranted(){ ## path
	rigOp --intern-op-permission-grant-read "$rigMember" --session-id "$rigSession" --tool Write --target "$1"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigScenarioDir/op.out" | head -1 | LC_ALL=C awk '{ print ; found = 1 ; } END { if ( ! found ) { print "none" ; } }'
}
## The emoji of the tooling's own on the first post: "<placed, in order>|<taken off, in order>".
rigEmoji(){
	printf '%s|%s' "$( LC_ALL=C awk '$1 == "1700000001.000101" { out = out ( out == "" ? "" : " " ) $2 ; } END { print out ; }' "$rigScenarioDir/reactions" 2>/dev/null )" \
		"$( LC_ALL=C awk '$1 == "1700000001.000101" { out = out ( out == "" ? "" : " " ) $2 ; } END { print out ; }' "$rigScenarioDir/reactions.removed" 2>/dev/null )"
}
## The first post, and how often it was edited: its text as it stands is the body of its last edit.
rigPrompt="1700000001.000101"
rigEdits(){
	[ -f "$rigScenarioDir/edited" ] || { printf '0' ; return 0 ; }
	rigLines "$rigScenarioDir/edited" "$rigPrompt"
}
rigOne=/dev/null/rig-join/one
rigTwo=/dev/null/rig-join/two
rigThree=/dev/null/rig-join/three

echo "-- a second refused call, while the first permission question is open: no new post, the open one asks for both --"
rigStart joined
rigFirst="$( rigRefused "$rigOne" )"
[ -n "$rigFirst" ] || rigRefuse "the rig produced no refusal to ask permission for"
rigAsk "$rigFirst" "May the rig write the first file?" 8
rigAssert "control: the first call is one permission question, the bot's post to the owner, open, with a permission's emoji, the folder's among them" \
	"$rigKilled:$( rigCalls chat.postMessage ):$( rigCallsAs chat.postMessage "$rigBotToken" ):$( rigRecordCount ):$( rigRecordField kind ):$( rigRecordField status ):$( rigEmoji )" \
	"yes:1:1:1:permission:reply-pending:x one repeat file_folder|"
rigJoinedId="$( rigRecordId )"
rigSecond="$( rigRefused "$rigTwo" )"
rigAsk "$rigSecond" "May the rig write the second file?" 8
rigAssert "no second post is made and no second record opened: still one post, one record, the same one" \
	"$rigKilled:$( rigCalls chat.postMessage ):$( rigRecordCount ):$( rigRecordId )" "yes:1:1:$rigJoinedId"
rigAssert "the open post is edited in place, once, by the bot, to the permission set post" \
	"$( rigEdits ):$( rigCallsAs chat.update "$rigBotToken" ):$( rigCallsAs chat.update "$rigOwnToken" ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" 'Permission set' ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" 'for this session only' )" \
	"1:1:0:yes:yes"
rigAssert "it shows every call asked for, by place and tool, and how one answer covers them" \
	"$( rigHolds "$rigScenarioDir/edit.$rigPrompt" "$rigOne" ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" "$rigTwo" ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" 'Write' ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" 'allow-set' ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" 'allow-once' )" \
	"yes:yes:yes:yes:no"
rigAssert "why each call is needed stands under its place" \
	"$( rigHolds "$rigScenarioDir/edit.$rigPrompt" 'the rig needs it for May the rig write the first file?' ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" 'the rig needs it for May the rig write the second file?' )" "yes:yes"
rigAssert "its record is a permission set now, still open, with no refusal of its own and no slots of a single question" \
	"$( rigRecordField kind ):$( rigRecordField status ):$( rigRecordField refusal-id ):$( [ -f "$( rigRecordFile )" ] && [ ! -f "$( rigSetFile | LC_ALL=C sed 's/\.set$/.fields/' )" ] && printf gone || printf kept )" \
	"permission-set:reply-pending:none:gone"
rigAssert "its set is for this session and this member alone, and holds each call exactly, with the refusal it came from" \
	"$( rigLines "$( rigSetFile )" 'scope: session' ):$( rigLines "$( rigSetFile )" "session-id: $rigSession" ):$( rigLines "$( rigSetFile )" "participants: $rigMember" ):$( rigStarts "$( rigSetFile )" 'entry: ' ):$( rigLines "$( rigSetFile )" "entry: Write:$rigOne" ):$( rigLines "$( rigSetFile )" "entry: Write:$rigTwo" ):$( rigLines "$( rigSetFile )" "refusal: $rigFirst	Write:$rigOne" ):$( rigLines "$( rigSetFile )" "refusal: $rigSecond	Write:$rigTwo" )" \
	"1:1:1:2:1:1:1:1"
rigAssert "the answer emoji follow it: the one, the repeat sign and the folder are taken off, the lock is placed, the cross stays" \
	"$( rigEmoji )" "x one repeat file_folder unlock|one repeat file_folder"
rigAssert "nothing is granted while he has not answered" "$( rigGranted "$rigOne" ):$( rigGranted "$rigTwo" )" "none:none"

echo "-- a third call joins the same prompt, and one allow-set grants every call listed, and nothing else --"
rigThird="$( rigRefused "$rigThree" )"
rigThreadLater unlock "$rigScenarioDir/ws/.local/agents/pending/*.set.three"
## His click waits until the third call is written to the record: the mark below is made by the rig once the set holds three entries.
( while [ "$( rigStarts "$( rigSetFile )" 'entry: ' )" != "3" ] ; do sleep 0.2 ; done ; : > "$( rigSetFile ).three" ) &
rigWatch=$!
rigProcNote "$rigWatch"
rigAsk "$rigThird" "May the rig write the third file?"
rigProcSignal TERM "$rigWatch" ; wait "$rigWatch" 2>/dev/null
rigAssert "the third call comes back answered: allow-set, with the set's grant" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigVerdictLine ):$( rigLines "$rigScenarioDir/out" "GRANT: set 3 entries for $rigMember" )" \
	"no:ASK-RESULT: RECEIVED:VERDICT: allow-set:1"
rigAssert "and says it was added to the open prompt, which asks for three calls, and what one answer does" \
	"$( rigLines "$rigScenarioDir/out" "NOTE: no new prompt was posted. This call is added to the open permission prompt of this session to the human-owner, pending reply $rigJoinedId, which now asks for 3 calls in one post. One answer covers them all: allow-set grants every call of it for this session, deny grants none." )" 1
rigAssert "still one prompt and one record, edited once more, with the third call on it" \
	"$( rigRecordCount ):$( rigEdits ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" "$rigThree" ):$( rigStarts "$( rigSetFile )" 'entry: ' )" "1:2:yes:3"
rigAssert "the answer is confirmed once, in the prompt's thread, by the bot: the one other post" \
	"$( rigCalls chat.postMessage ):$( cat "$rigScenarioDir/posted-as.2" 2>/dev/null ):$( rigHolds "$rigScenarioDir/post.2" '"thread_ts":"1700000001.000101"' ):$( rigHolds "$rigScenarioDir/post.2" 'Read: `allow-set` by human-owner. Granted: 3 permission(s) to magic-tester, for this session only.' )" \
	"2:$rigBotToken:yes:yes"
rigAssert "its record is closed with that verdict" "$( rigRecordField status ):$( rigRecordField verdict )" "reply-received:allow-set"
rigAssert "every call listed is granted for the session, and a call that was never on the post is not" \
	"$( rigGranted "$rigOne" ):$( rigGranted "$rigTwo" ):$( rigGranted "$rigThree" ):$( rigGranted /dev/null/rig-join/four )" "session:session:session:none"

echo "-- once he has answered, the answered prompt takes no call, and a further call asked alone for the same task is not posted --"
rigFourth="$( rigRefused /dev/null/rig-join/four )"
rigAsk "$rigFourth" "May the rig write the fourth file?" 8
rigAssert "the answered prompt is not edited again and takes no call; the new call comes back as a correction, with no post and no record" \
	"$rigKilled:$( rigEdits ):$( rigCalls chat.postMessage ):$( rigRecordCount ):$( rigStarts "$rigScenarioDir/out" 'CORRECTION: RequestPermission: nothing was posted.' ):$( rigStarts "$( rigSetFile )" 'entry: ' )" \
	"no:2:2:1:1:3"

echo "-- a prompt that already holds his answer takes no further call: the answer is for what it showed --"
rigStart answered-before
rigFirst="$( rigRefused "$rigOne" )"
rigAsk "$rigFirst" "May the rig write the first file?" 8
rigSecond="$( rigRefused "$rigTwo" )"
rigThreadNow one
rigAsk "$rigSecond" "May the rig write the second file?" 8
rigAssert "his allow-once is applied to the one call the prompt showed, and the prompt stays a single permission, never edited" \
	"$( rigRecordField kind ):$( rigRecordField status ):$( rigRecordField verdict ):$( rigEdits ):$( [ -f "$( rigSetFile )" ] && printf set || printf no-set )" \
	"permission:reply-received:allow-once:0:no-set"
rigAssert "the second call is not added to it, and is not posted either: he has answered a call asked alone for this task, so it comes back as a correction" \
	"$rigKilled:$( rigRecordCount ):$( rigCalls chat.postMessage ):$( rigStarts "$rigScenarioDir/out" 'CORRECTION: RequestPermission: nothing was posted.' )" \
	"no:1:2:1"
rigAssert "only the first call is granted, once" "$( rigGranted "$rigOne" ):$( rigGranted "$rigTwo" )" "once:none"

echo "-- an answer that reaches the prompt while a call is being added is never widened --"
rigStart answered-meanwhile
rigFirst="$( rigRefused "$rigOne" )"
rigAsk "$rigFirst" "May the rig write the first file?" 8
rigSecond="$( rigRefused "$rigTwo" )"
## His click lands once the post was edited: after the first read of the thread, before the second.
rigThreadLater one "$rigScenarioDir/edited"
rigAsk "$rigSecond" "May the rig write the second file?" 8
rigAssert "the post was edited to show both calls, and then put back as it was asked: its last edit is the single permission again" \
	"$( rigEdits ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" 'Permission set' ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" "$rigTwo" ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" "$rigOne" ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" 'allow-once' )" \
	"2:no:no:yes:yes"
rigAssert "the call was never written to its record: still a single permission, with no set; the lock was never placed, and the one mark after its emoji is that it is answered" \
	"$( rigRecordField kind ):$( rigRecordField refusal-id ):$( [ -f "$( rigSetFile )" ] && printf set || printf no-set ):$( rigEmoji )" \
	"permission:$rigFirst:no-set:x one repeat file_folder white_check_mark|"
rigAssert "his allow-once is applied to the prompt as it was asked: the first call alone, once" \
	"$( rigRecordField status ):$( rigRecordField verdict ):$( rigGranted "$rigOne" ):$( rigGranted "$rigTwo" )" "reply-received:allow-once:once:none"
rigAssert "and the second call is not posted: it comes back as a correction" \
	"$rigKilled:$( rigRecordCount ):$( rigStarts "$rigScenarioDir/out" 'CORRECTION: RequestPermission: nothing was posted.' )" "no:1:1"

echo "-- one deny covers every call --"
rigStart denied
rigFirst="$( rigRefused "$rigOne" )"
rigAsk "$rigFirst" "May the rig write the first file?" 8
rigSecond="$( rigRefused "$rigTwo" )"
rigThreadLater x "$rigScenarioDir/ws/.local/agents/pending/*.set"
rigAsk "$rigSecond" "May the rig write the second file?"
rigAssert "the cross on the joined prompt is a deny for both calls: nothing is granted, and it is confirmed once in the thread" \
	"$rigKilled:$( rigVerdictLine ):$( rigRecordCount ):$( rigRecordField kind ):$( rigRecordField verdict ):$( rigGranted "$rigOne" ):$( rigGranted "$rigTwo" ):$( rigCalls chat.postMessage ):$( rigHolds "$rigScenarioDir/post.2" 'Read: `deny` by human-owner. Nothing is granted to magic-tester.' )" \
	"no:VERDICT: deny:1:permission-set:deny:none:none:2:yes"

echo "-- a call the open prompt asks for already is not asked again --"
rigStart same-call
rigFirst="$( rigRefused "$rigOne" )"
rigAsk "$rigFirst" "May the rig write the first file?" 8
rigCall 60 RequestPermission "{\"to\":\"human-owner\",\"question\":\"The rig still needs the first file. May it write it?\",\"refusal_id\":\"$rigFirst\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}"
rigAssert "asked again in other words: already open, nothing posted, nothing edited, the prompt still a single permission" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigCalls chat.postMessage ):$( rigEdits ):$( rigRecordCount ):$( rigRecordField kind )" \
	"no:ASK-RESULT: ALREADY-OPEN:1:0:1:permission"

echo "-- the accepted siblings are prompts of their own --"
rigStart other-session
rigFirst="$( rigRefused "$rigOne" )"
rigAsk "$rigFirst" "May the rig write the first file?" 8
rigSession="rig-join-other-session-second"
rigSecond="$( rigRefused "$rigTwo" )"
rigAsk "$rigSecond" "May the rig write the second file?" 8
rigAssert "a refused call of another session is not added to this session's prompt: its own post and record, and no edit" \
	"$( rigCalls chat.postMessage ):$( rigRecordCount ):$( rigRecordField kind ):$( rigRecordField kind 2 ):$( rigRecordField session-id 2 ):$( rigEdits )" \
	"2:2:permission:permission:rig-join-other-session-second:0"
rigStart pattern-target
rigFirst="$( rigRefused "$rigOne" )"
rigAsk "$rigFirst" "May the rig write the first file?" 8
rigOp --intern-op-permission-refusal-log "$rigMember" --session-id "$rigSession" --tool Read --target '/dev/null/rig-join/**' --reason 'a read the rig made up'
rigSecond="$( LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$rigScenarioDir/op.out" | head -1 )"
rigAsk "$rigSecond" "May the rig read everything there?" 8
rigAssert "a call whose target a set would read as a pattern is never added: a set grants by pattern, and this call was one target" \
	"$( rigCalls chat.postMessage ):$( rigRecordCount ):$( rigRecordField kind ):$( rigRecordField kind 2 ):$( rigEdits )" "2:2:permission:permission:0"

echo "-- the whole prompt is withdrawn as a set is --"
rigStart withdrawn
rigFirst="$( rigRefused "$rigOne" )"
rigAsk "$rigFirst" "May the rig write the first file?" 8
rigSecond="$( rigRefused "$rigTwo" )"
rigAsk "$rigSecond" "May the rig write the second file?" 8
rigCall 60 RequestPermission "{\"pending_id\":\"$( rigRecordId )\",\"withdraw\":\"the rig no longer needs either file\"}"
rigAssert "withdrawn by its asker: closed with no verdict, and nothing granted" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigRecordField status ):$( rigRecordField verdict ):$( rigGranted "$rigOne" ):$( rigGranted "$rigTwo" )" \
	"no:ASK-RESULT: WITHDRAWN:withdrawn:none:none:none"
rigAssert "its post is edited to the same set with no way to answer left, and both calls still on it" \
	"$( rigHolds "$rigScenarioDir/edit.$rigPrompt" 'Permission set' ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" "$rigOne" ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" "$rigTwo" ):$( rigHolds "$rigScenarioDir/edit.$rigPrompt" 'allow-set' )" \
	"yes:yes:yes:no"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION JOIN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_PERMISSION_JOIN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
