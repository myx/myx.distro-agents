#!/usr/bin/env bash
## The two re-wait edges AgentsHarnessAskCheck does not cover: a re-wait from a resumed
## session (a new process under the same session id) is accepted while one from another
## session is refused, and the asker's own post naming a verdict is never the answer.
## Offline: the Slack-shaped ask fixture is first on PATH; each scenario has its own
## workspace under this rig's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"
rigTmp="$( mktemp -d -t AgentsHarnessAskRewaitCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, text
	LC_ALL=C grep -q -F -- "$2" "$1" 2>/dev/null && printf yes || printf no
}
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null
}
rigVerdictLine(){
	LC_ALL=C awk '/^VERDICT: / { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-verdict-line" ; } }' "$rigScenarioDir/out"
}
rigRecordStatus(){
	LC_ALL=C awk -F': ' '$1 == "status" { print $2 ; exit ; }' "$rigScenarioDir/ws/.local/agents/pending/$rigRewaitId.md" 2>/dev/null
}

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
## The thread: opener, question, then the scenario's later messages. The fixture's own
## account, URIGSELF1, is the asker's.
rigReplies(){ ## later messages (may be empty)
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"opener"},{"ts":"1700000001.000102","user":"URIGSELF1","text":"question","thread_ts":"1700000001.000101"}%s],"has_more":false}\n' "$1" > "$rigScenarioDir/replies.json"
}
## One tool call under a stated session, in a process of its own, with a guard: an ask
## nobody answers waits by design, so the guard ends it and says so.
rigKilled=""
rigAsk(){ ## session id, guard seconds, argument object, optional tool (default AskUserQuestion)
	local askPid askLeft="$2"
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SPAWN_SESSION_ID="$1" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool "${4:-AskUserQuestion}" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	askPid=$!
	set +m
	while kill -0 "$askPid" 2>/dev/null && [ "$askLeft" -gt 0 ] ; do sleep 1 ; askLeft=$(( askLeft - 1 )) ; done
	if kill -0 "$askPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$askPid" ; sleep 1 ; kill -KILL -- "-$askPid" ; wait "$askPid" ; } 2>/dev/null
	fi
	{ wait "$askPid" ; } 2>/dev/null || :
}
rigQuestion='May the rig write the refused report file?'

echo "-- a resumed session may re-wait; another session may not --"
rigStart resumed
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"let me think","thread_ts":"1700000001.000101"}'
rigAsk rig-session-a 60 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"allow-once -- let it write\\ndeny -- keep it refused\"}"
rigAssert "the first reply is UNCLASSIFIED"            "$( rigVerdictLine )" "VERDICT: UNCLASSIFIED"
rigRewaitId="$( LC_ALL=C sed -n 's/^AskUserQuestion pending_id=//p' "$rigScenarioDir/out" | tail -1 )"
[ -n "$rigRewaitId" ] || rigRefuse "no re-wait line came back, so nothing below would be measured"
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"let me think","thread_ts":"1700000001.000101"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"deny","thread_ts":"1700000001.000101"}'
rigAsk rig-session-b 30 "{\"pending_id\":\"$rigRewaitId\"}"
rigAssert "another session's re-wait is refused"       "$( rigHolds "$rigScenarioDir/out" "ERROR: AskUserQuestion: pending reply $rigRewaitId belongs to session rig-session-a, not this one" )" yes
rigAssert "and the record stays open"                  "$( rigRecordStatus )" reply-pending
rigPostsBefore="$( rigCalls chat.postMessage )"
rigAsk rig-session-a 30 "{\"pending_id\":\"$rigRewaitId\"}"
rigAssert "control: the same session in a new process is accepted" "$( rigVerdictLine )" "VERDICT: deny"
rigAssert "the re-wait posted nothing"                 "$(( $( rigCalls chat.postMessage ) - rigPostsBefore ))" 0
rigAssert "and the record closed as received"          "$( rigRecordStatus )" reply-received

echo "-- the asker's own post is never the answer --"
rigStart asker-post
rigReplies ',{"ts":"1700000001.000200","user":"URIGSELF1","text":"allow-once","thread_ts":"1700000001.000101"}'
rigAsk rig-session-c 12 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"allow-once -- let it write\\ndeny -- keep it refused\"}"
rigAssert "a thread holding only the asker's own verdict-shaped post is still waited on" "$rigKilled" yes
rigAssert "no verdict was taken from it"               "$( rigVerdictLine )" "no-verdict-line"
rigRewaitId="$( ls "$rigScenarioDir/ws/.local/agents/pending" 2>/dev/null | LC_ALL=C sed -n 's/\.md$//p' | head -1 )"
rigAssert "the record stays open"                      "$( rigRecordStatus )" reply-pending
rigReplies ',{"ts":"1700000001.000200","user":"URIGSELF1","text":"allow-once","thread_ts":"1700000001.000101"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"deny","thread_ts":"1700000001.000101"}'
rigAsk rig-session-c 30 "{\"pending_id\":\"$rigRewaitId\"}"
rigAssert "control: the addressee's later answer is the verdict" "$( rigVerdictLine )" "VERDICT: deny"

## The record with what differs between two runs of the same ask -- its id and its clock -- written out.
rigRecordShape(){ ## scenario directory
	local shapeFile shapeId
	for shapeFile in "$1/ws/.local/agents/pending"/*.md ; do
		[ -f "$shapeFile" ] || continue
		shapeId="${shapeFile##*/}" ; shapeId="${shapeId%.md}"
		LC_ALL=C sed -E -e "s/$shapeId/<id>/g" -e 's/rig-session-[a-z]/<session>/g' -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9:.]+Z?/<time>/g' -e 's/(^|[^0-9.])[0-9]{10}([^0-9.]|$)/\1<epoch>\2/g' "$shapeFile"
		return 0
	done
	printf 'no-record'
}
rigWaitSet(){ ## scenario directory, session id
	LC_ALL=C sed -n 's/^sources: //p' "$1/ws/.local/agents/sessions/$2/wait/state" 2>/dev/null | head -1
}
rigAnswer=',{"ts":"1700000001.000200","user":"URIGOWNER","text":"RIG-ANSWER-MARKER","thread_ts":"1700000001.000101"}'

echo "-- a posted ask joins the session's Wait set, and Wait takes its answer into the record --"
rigStart own-wait
rigReplies "$rigAnswer"
rigAsk rig-session-d 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\"}"
rigAssert "control: the ask's own wait takes the answer" "$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT: RECEIVED' )" yes
rigAssert "control: and leaves nothing in the Wait set" "$( rigWaitSet "$rigScenarioDir" rig-session-d )" ""
rigStart posted-wait
rigReplies ""
rigAsk rig-session-d 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"wait\":false}"
rigRewaitId="$( LC_ALL=C sed -n 's/^WAIT-ID: ask://p' "$rigScenarioDir/out" | tail -1 )"
[ -n "$rigRewaitId" ] || rigRefuse "no WAIT-ID line came back from a posted ask, so nothing below would be measured"
rigAssert "the posted ask is POSTED"                   "$( LC_ALL=C head -1 "$rigScenarioDir/out" )" "ASK-RESULT: POSTED"
rigAssert "its NEXT: names both Waits"                 "$( LC_ALL=C awk 'END { print ; }' "$rigScenarioDir/out" )" "NEXT: added to your Wait set -- call Wait mode=continue, or start a new wait with Wait sources=ask:$rigRewaitId"
rigAssert "its wait item is in the session's Wait set" "$( rigWaitSet "$rigScenarioDir" rig-session-d )" "ask:$rigRewaitId "
rigAsk rig-session-x 30 "{\"sources\":\"ask:$rigRewaitId\"}" Wait
rigAssert "another session's Wait on it is refused"   "$( rigHolds "$rigScenarioDir/out" 'is a question asked by session rig-session-d' )" yes
rigAsk rig-session-d 30 '{"mode":"continue"}' Wait
rigAssert "Wait mode=continue, unanswered, times out" "$( LC_ALL=C head -1 "$rigScenarioDir/out" )" "WAIT-RESULT: TIMEOUT"
rigAssert "and the record stays open"                  "$( rigRecordStatus )" reply-pending
rigReplies "$rigAnswer"
rigAsk rig-session-d 30 '{"mode":"continue"}' Wait
rigAssert "Wait mode=continue returns the answer"      "$( LC_ALL=C head -1 "$rigScenarioDir/out" )" "WAIT-RESULT: RECEIVED"
rigAssert "it carries the answer text"                 "$( rigHolds "$rigScenarioDir/out" 'RIG-ANSWER-MARKER' )" yes
rigAssert "and takes it as the asking call would"      "$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT: RECEIVED' )" yes
rigAssert "the record closed as received"              "$( rigRecordStatus )" reply-received
rigAssert "the record is the one the ask's own wait leaves" "$( rigRecordShape "$rigScenarioDir" )" "$( rigRecordShape "$rigTmp/own-wait" )"
rigAssert "the answered item left the Wait set"        "$( rigWaitSet "$rigScenarioDir" rig-session-d )" ""
rigAsk rig-session-d 30 "{\"pending_id\":\"$rigRewaitId\"}"
rigAssert "control: the pending_id re-wait sees it closed" "$( rigHolds "$rigScenarioDir/out" 'is closed' )" yes

echo "-- a typed ask left UNCLASSIFIED: a new Wait on its WAIT-ID takes the verdict --"
rigStart typed-wait
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"let me think","thread_ts":"1700000001.000101"}'
rigAsk rig-session-e 60 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"allow-once -- let it write\\ndeny -- keep it refused\"}"
rigAssert "the first reply is UNCLASSIFIED"            "$( rigVerdictLine )" "VERDICT: UNCLASSIFIED"
rigRewaitId="$( LC_ALL=C sed -n 's/^WAIT-ID: ask://p' "$rigScenarioDir/out" | tail -1 )"
rigAssert "it names its wait item"                     "$( [ -n "$rigRewaitId" ] && printf yes || printf no )" yes
rigAssert "the compatible re-wait line is still last"  "$( LC_ALL=C awk 'END { print ; }' "$rigScenarioDir/out" )" "AskUserQuestion pending_id=$rigRewaitId"
rigAssert "the item stays in the Wait set"             "$( rigWaitSet "$rigScenarioDir" rig-session-e )" "ask:$rigRewaitId "
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"let me think","thread_ts":"1700000001.000101"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"deny","thread_ts":"1700000001.000101"}'
rigPostsBefore="$( rigCalls chat.postMessage )"
rigAsk rig-session-e 30 "{\"sources\":\"ask:$rigRewaitId\"}" Wait
rigAssert "a new Wait on the WAIT-ID returns the answer" "$( LC_ALL=C head -1 "$rigScenarioDir/out" )" "WAIT-RESULT: RECEIVED"
rigAssert "with the verdict the re-wait would take"    "$( rigVerdictLine )" "VERDICT: deny"
rigAssert "the Wait posted nothing"                    "$(( $( rigCalls chat.postMessage ) - rigPostsBefore ))" 0
rigAssert "the record closed as received"              "$( rigRecordStatus )" reply-received
rigAssert "and carries the verdict"                    "$( LC_ALL=C awk -F': ' '$1 == "verdict" { print $2 ; exit ; }' "$rigScenarioDir/ws/.local/agents/pending/$rigRewaitId.md" )" deny
rigAssert "the record is the one the pending_id re-wait leaves" "$( rigRecordShape "$rigScenarioDir" )" "$( rigRecordShape "$rigTmp/resumed" )"

rigAssert "no request went anywhere but a Slack method" "$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK REWAIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_REWAIT: OK (%d assertions, offline)\n' "$rigPassCount"
