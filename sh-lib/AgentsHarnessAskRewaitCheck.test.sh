#!/usr/bin/env bash
## The two re-wait edges AgentsHarnessAskCheck does not cover: a re-wait from a resumed
## session (a new process under the same session id) is accepted while one from another
## session is refused, and the asker's own post naming a verdict is never the answer.
## Offline: the Slack-shaped ask fixture is first on PATH; each scenario has its own
## workspace under this rig's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
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
cp "$rigHere/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
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
rigAsk(){ ## session id, guard seconds, argument object
	local askPid askLeft="$2"
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SPAWN_SESSION_ID="$1" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool AskUserQuestion ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
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

rigAssert "no request went anywhere but a Slack method" "$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK REWAIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_REWAIT: OK (%d assertions, offline)\n' "$rigPassCount"
