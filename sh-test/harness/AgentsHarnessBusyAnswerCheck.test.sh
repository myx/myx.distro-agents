#!/usr/bin/env bash
## Behavioural check on a provider that is busy or answers empty (S6.18): the run keeps its place and asks again, and a real refusal still ends it.
## Run through the real core and the real OpenAI wire against a fake curl that replays canned answers, so nothing opens a socket.
## Held:
##   1. HTTP 503 more times than HARNESS_STREAM_ATTEMPTS, then an empty stop, then an answer: the run ends 0 with that answer, and says so once in its log and once in its session thread
##   2. an empty stop after a tool round asks the same request again, byte for byte, so the tool call and its result stay paired
##   3. a refusal that carries a status of its own (400, 401, 402) ends the run on its first request, whatever words its body holds
##      and an unlisted 5xx is settled by its status alone, with no reading of its body
##   4. a context-length refusal at HTTP 400 still summarises and carries on
##   5. a tool name the provider broke gets a refusal as its result, whatever the locale, and an unarmed run is still redirected first
##   6. the pause is one budget for the whole run: a round does not hand it back, an empty answer spends the same one, a budget
##      spelled 6h is the default, a status line with no reason phrase still reads as busy, an unlisted status still ends the run,
##      and the post reaches a joined run's thread and says so where it cannot
## A provider that never recovers is bounded by the canned answers: the one after the last is a dropped connection, which ends the run as it always did.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigHarness="$rigOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh"
rigFixtures="$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures"
rigMember="rig-a"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
[ -f "$rigFixtures/harness-busy-check.curl.stub.sh" ] || rigRefuse "the fake curl fixture is missing: $rigFixtures/harness-busy-check.curl.stub.sh"
[ -f "$rigFixtures/session-address-first.curl.stub.sh" ] || rigRefuse "the Slack-shaped fake curl fixture is missing: $rigFixtures/session-address-first.curl.stub.sh"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessBusyAnswerCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/skills/$rigMember" "$rigTmp/home" "$rigTmp/bin" "$rigWs/.local/agents/sessions/rig-busy" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigWs/.local/.agents/$rigMember.agent.env"
printf 'CRIG00001:1760000000.000100\n' > "$rigWs/.local/agents/sessions/rig-busy/session.thread"
cp "$rigFixtures/harness-busy-check.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "cannot place the fake curl"
rigPath="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
[ "$( PATH="$rigPath" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, text -- yes where the file holds the text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}
rigCount(){ ## file, text -- how many lines of the file hold the text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C grep -c -F -- "$2" "$1" || :
}
rigSame(){ ## two files -- same or differs
	cmp -s "$1" "$2" 2> /dev/null && printf same || printf differs
}

rigDir=""
rigStart(){ ## scenario name
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir"
	printf '0' > "$rigDir/round"
	printf 'RIG-TOOLRESULT-MARKER\n' > "$rigDir/read.txt"
}
rigBusy(){ ## request number, status, body words -- the service's own refusal: its status line and a body with no data: frame
	printf 'HTTP/1.1 %s Rig Status\r\n\r\n' "$2" > "$rigDir/hdr.$1"
	printf '{"error":{"message":"%s","type":"service_unavailable_error","param":null,"code":null}}' "$3" > "$rigDir/res.$1"
}
## The same refusal with no reason phrase after the status, which is what a transport writes when the
## provider sends none: the status is still 503, and only the `\r` stands after it.
rigBusyBare(){ ## request number, status, body words
	printf 'HTTP/1.1 %s\r\n\r\n' "$2" > "$rigDir/hdr.$1"
	printf '{"error":{"message":"%s","type":"service_unavailable_error","param":null,"code":null}}' "$3" > "$rigDir/res.$1"
}
rigEmpty(){ ## request number -- an answer that stops with no tool call and no content
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":20,"completion_tokens":0,"total_tokens":20}}\ndata: [DONE]\n' > "$rigDir/res.$1"
}
rigText(){ ## request number, content
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":20,"completion_tokens":2,"total_tokens":22}}\ndata: [DONE]\n' "$2" > "$rigDir/res.$1"
}
rigTool(){ ## request number -- an answer with one Read call
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call","type":"function","function":{"name":"Read","arguments":"{\\"path\\":\\"%s\\"}"}}]}}]}\ndata: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":100,"completion_tokens":5,"total_tokens":105}}\ndata: [DONE]\n' "$rigDir/read.txt" > "$rigDir/res.$1"
}
rigToolBadWrite(){ ## request number -- the same break on a Write name, a tool the unarmed gate redirects
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-badwrite","type":"function","function":{"name":"Write</|DSML| parameter>","arguments":"{}"}}]}}]}\ndata: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":20,"completion_tokens":2,"total_tokens":22}}\ndata: [DONE]\n' > "$rigDir/res.$1"
}
rigToolAccent(){ ## request number -- a name whose only fault is a letter a bracket range folds into `[A-Za-z]`
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-accent","type":"function","function":{"name":"Read\u00e9","arguments":"{}"}}]}}]}\ndata: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":20,"completion_tokens":2,"total_tokens":22}}\ndata: [DONE]\n' > "$rigDir/res.$1"
}
rigToolBad(){ ## request number -- an answer whose one tool call carries a name broken by the provider's own markup
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-bad","type":"function","function":{"name":"Read</|DSML| parameter>\\n<|DSML| parameter name=","arguments":"{}"}}]}}]}\ndata: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":20,"completion_tokens":2,"total_tokens":22}}\ndata: [DONE]\n' > "$rigDir/res.$1"
}
rigRunStatus=0
rigRoundCount=0
rigRun(){ ## context tokens, agent name (empty: a run with no team identity, which posts nowhere), then NAME=value assignments for this run
	rigRunStatus=0
	local rigTokens="$1" rigAgentName="${2:-}"
	shift 2
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_SESSION_ID=rig-busy MDAT_SPAWN_AGENT="$rigMember" RIG_SCENARIO="$rigDir" RIG_SLACK_STUB="$rigFixtures/session-address-first.curl.stub.sh" \
		MDAT_WAIT_REMIND=off MDAT_HARNESS_CONTEXT_TOKENS="$rigTokens" ${@+"$@"} \
		HARNESS_PROVIDER_NAME="busy-answer rig" HARNESS_SELF_NAME="AgentsHarnessBusyAnswerCheck.test.sh" HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none" \
		HARNESS_ENDPOINT="https://harness-busy-check.invalid/v1/chat/completions" HARNESS_HOST="harness-busy-check.invalid" \
		HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
		HARNESS_STREAM_ATTEMPTS=3 HARNESS_RETRY_DELAY=0 \
		python3 -I -B "$rigFixtures/rig-exec.py" --alarm 120 -- bash "$rigHarness" ${rigAgentName:+--agent "$rigAgentName"} --access-root "$rigDir" RIG-TASK-MARKER ) > "$rigDir/out" 2> "$rigDir/err" || rigRunStatus=$?
	rigRoundCount="$( cat "$rigDir/round" )"
	[ "$rigRoundCount" != 0 ] || rigRefuse "the harness issued no request at all, so this scenario exercised nothing -- its stderr: $( head -5 "$rigDir/err" )"
}

echo "-- 1. busy more times than attempts, then empty, then an answer --"
rigStart busy-then-empty-then-answer
rigReq=1
while [ "$rigReq" -le 8 ] ; do rigBusy "$rigReq" 503 RIG-BUSY-MARKER ; rigReq=$(( rigReq + 1 )) ; done
rigEmpty 9
rigText 10 RIG-FINAL-MARKER
rigRun 0 "$rigMember"
rigAssert "the run ends normally"                                     "$rigRunStatus" 0
rigAssert "ten requests: eight busy, one empty, one answered"         "$rigRoundCount" 10
rigAssert "the answer is the result"                                  "$( cat "$rigDir/out" )" RIG-FINAL-MARKER
rigAssert "the busy answer is said once in the log"                   "$( rigCount "$rigDir/err" 'BUSY:' )" 1
rigAssert "the log names the status it was given"                     "$( rigHolds "$rigDir/err" 'HTTP 503' )" yes
rigAssert "the busy answer is said once in the session thread"        "$( cat "$rigDir/posts" 2> /dev/null || printf 0 )" 1
rigAssert "that post is in the session thread"                        "$( rigHolds "$rigDir/post.1" '"thread_ts":"1760000000.000100"' )" yes
rigAssert "that post names the host"                                  "$( rigHolds "$rigDir/post.1" 'harness-busy-check.invalid' )" yes
rigAssert "the empty answer is asked again with the same request"     "$( rigSame "$rigDir/req.9" "$rigDir/req.10" )" same

echo "-- 2. an empty answer after a tool round asks the same request again --"
rigStart empty-after-tool
rigTool 1
rigEmpty 2
rigEmpty 3
rigText 4 RIG-FINAL-MARKER
rigRun 0 ""
rigAssert "the run ends normally"                                     "$rigRunStatus" 0
rigAssert "four requests"                                             "$rigRoundCount" 4
rigAssert "the answer is the result"                                  "$( cat "$rigDir/out" )" RIG-FINAL-MARKER
rigAssert "the request that was answered empty held the tool result"  "$( rigHolds "$rigDir/req.2" 'RIG-TOOLRESULT-MARKER' )" yes
rigAssert "its first retry is that request"                           "$( rigSame "$rigDir/req.2" "$rigDir/req.3" )" same
rigAssert "its second retry is that request"                          "$( rigSame "$rigDir/req.2" "$rigDir/req.4" )" same
rigAssert "the call is held once in what was sent"                    "$( LC_ALL=C grep -o -F '"tool_call_id"' "$rigDir/req.4" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 1

echo "-- 3. a refusal with a status of its own ends the run --"
for rigStatus in 400 401 402 ; do
	rigStart "refused-$rigStatus"
	rigBusy 1 "$rigStatus" "RIG-REFUSAL-$rigStatus-MARKER service unavailable"
	rigText 2 RIG-SHOULD-NEVER-BE-ASKED
	rigRun 0 "$rigMember"
	rigAssert "HTTP $rigStatus ends the run"                             "$rigRunStatus" 1
	rigAssert "HTTP $rigStatus is asked once"                            "$rigRoundCount" 1
	rigAssert "HTTP $rigStatus is named as a refusal"                    "$( rigHolds "$rigDir/err" "RIG-REFUSAL-$rigStatus-MARKER" )" yes
	rigAssert "HTTP $rigStatus is not called busy"                       "$( rigHolds "$rigDir/err" 'BUSY:' )" no
	rigAssert "HTTP $rigStatus posts nothing to the thread"              "$( cat "$rigDir/posts" 2> /dev/null || printf 0 )" 0
done

echo "-- 5. a tool name the provider broke gets a result, and the run goes on (S6.16) --"
rigStart broken-tool-name
rigToolBad 1
rigText 2 RIG-FINAL-MARKER
rigRun 0 ""
rigAssert "the run ends normally"                                     "$rigRunStatus" 0
rigAssert "two requests"                                              "$rigRoundCount" 2
rigAssert "the second request answers the broken call"                "$( rigHolds "$rigDir/req.2" '"tool_call_id":"rig-bad"' )" yes
rigAssert "the second request carries no broken name"                 "$( rigHolds "$rigDir/req.2" 'DSML' )" no
rigAssert "no awk fault on the name"                                  "$( rigHolds "$rigDir/err" 'newline in string' )" no

## The name test is the same answer whatever the machine's collation. A locale that folds
## `é` into the range keeps the letter, so the name reads clean and the call is run.
rigRunEnv=()
rigStart broken-tool-name-utf8
rigToolAccent 1
rigText 2 RIG-FINAL-MARKER
rigRun 0 "" LC_ALL=en_US.UTF-8
rigAssert "a name whose only fault is a letter the range folds in gets the refusal" "$( rigHolds "$rigDir/req.2" 'came back with a broken name from the provider' )" yes
rigAssert "and the replayed call carries the name cut back to Read"      "$( rigHolds "$rigDir/req.2" '{"id":"rig-accent","type":"function","function":{"name":"Read",' )" yes
rigAssert "the run goes on to its answer"                            "$( cat "$rigDir/out" )" RIG-FINAL-MARKER

## The broken-name branch is behind neither hook layer: an unarmed run is redirected
## as any other call of that tool is, and the redirect is what its result holds.
rigStart broken-name-unarmed
rigToolBadWrite 1
rigText 2 RIG-FINAL-MARKER
rigRun 0 "$rigMember"
rigAssert "an unarmed run's broken Write call is redirected to its duty file" "$( rigHolds "$rigDir/req.2" 'read your duty file first' )" yes

echo "-- 4. a context-length refusal at HTTP 400 still summarises --"
rigStart context-refusal
mkdir -p "$rigDir/sandbox"
printf 'HTTP/1.1 400 Bad Request\r\n\r\n' > "$rigDir/hdr.1"
printf '%s' '{"error":{"message":"This model maximum context length is 1048576 tokens. Please reduce the length of the messages or completion.","type":"invalid_request_error","param":null,"code":"context_length_exceeded"}}' > "$rigDir/res.1"
rigText 2 RIG-SUMMARY-MARKER
rigText 3 RIG-FINAL-MARKER
rigRun 1000000 "" MDAT_SPAWN_SANDBOX_ROOT="$rigDir/sandbox"
rigAssert "the run does not end on the refusal"                       "$rigRunStatus" 0
rigAssert "three requests"                                            "$rigRoundCount" 3
rigAssert "the summarise request asked for the handover"              "$( rigHolds "$rigDir/req.2" 'Write the handover a fresh leg needs' )" yes
rigAssert "the fresh leg carries the summary"                         "$( rigHolds "$rigDir/req.3" 'RIG-SUMMARY-MARKER' )" yes
rigAssert "the fresh leg's answer is the result"                      "$( cat "$rigDir/out" )" RIG-FINAL-MARKER
## THE RUN DID NOT END REFUSED, SO NO MARKER SAYS IT DID (S6.26): the closer reads `.refused` as the reason the run
## ended, so a run that went on must leave none behind.
rigAssert "the run left no refusal marker behind it"                  "$( [ -f "$rigDir/sandbox/rig-busy.refused" ] && printf present || printf gone )" "gone"
rigAssert "and the count of the refusals is kept"                     "$( [ -s "$rigDir/sandbox/rig-busy.refused-log" ] && printf counted || printf lost )" "counted"

echo "-- 6. the pause is one budget for the run (S6.18) --"
## A round is a turn of the loop, and the pause belongs to the run: a busy answer in a second
## round finds the budget the first one spent, and the pause is said once for the whole run.
rigStart budget-across-rounds
rigBusy 1 503 RIG-BUSY-MARKER
rigTool 2
rigBusy 3 503 RIG-BUSY-MARKER
rigText 4 RIG-FINAL-MARKER
rigRun 0 "" HARNESS_BUSY_BUDGET=1
rigAssert "the pause is said once for the whole run, not once a round" "$( rigCount "$rigDir/err" 'BUSY:' )" 1
rigAssert "every request is still made, the second busy one on the ordinary retry bound" "$rigRoundCount" 4
rigAssert "and the run still ends on its answer"                       "$rigRunStatus" 0

## The empty answer spends the same budget: a run whose busy half spent it does not start a second.
rigStart budget-spent-by-busy
rigBusy 1 503 RIG-BUSY-MARKER
rigEmpty 2
rigText 3 RIG-FINAL-MARKER
rigRun 0 "" HARNESS_BUSY_BUDGET=1
rigAssert "the empty answer after a spent budget ends the run"        "$rigRunStatus" 1
rigAssert "it is asked once, with no second wait"                     "$rigRoundCount" 2

## The budget is seconds, as the variable says: a value spelled in hours is the default,
## never a number bash's arithmetic refuses to read. Asked of the empty half too, which
## reads the same budget: there the raw string reached bash's `[` and ended the retry.
rigStart budget-in-hours
rigBusy 1 503 RIG-BUSY-MARKER
rigText 2 RIG-FINAL-MARKER
rigRun 0 "" HARNESS_BUSY_BUDGET=6h
rigAssert "a budget spelled 6h neither faults nor ends the run"       "$rigRunStatus" 0
rigAssert "the run asks again and takes the answer"                    "$rigRoundCount" 2
rigAssert "and no integer expression fault is printed"               "$( rigHolds "$rigDir/err" 'integer expression expected' )" no
rigAssert "the log says the budget it used, in seconds"               "$( rigHolds "$rigDir/err" 'up to 21600s' )" yes

rigStart empty-with-budget-in-hours
rigEmpty 1
rigEmpty 2
rigText 3 RIG-FINAL-MARKER
rigRun 0 "" HARNESS_BUSY_BUDGET=6h
rigAssert "the empty half reads the same 6h as the default, so the run waits" "$rigRunStatus:$( cat "$rigDir/out" )" "0:RIG-FINAL-MARKER"
rigAssert "it asks again twice and then is answered"                   "$rigRoundCount" 3
rigAssert "and the empty half prints no integer expression fault"     "$( rigHolds "$rigDir/err" 'integer expression expected' )" no

## A status line with no reason phrase: the status is the number after the protocol and
## nothing else, so a trailing CR never makes 503 read as a refusal that is not one.
rigStart status-with-no-reason-phrase
rigBusyBare 1 503 RIG-BUSY-MARKER
rigText 2 RIG-FINAL-MARKER
rigRun 0 "$rigMember"
rigAssert "a bare 503 line is still read as busy"                      "$rigRoundCount" 2
rigAssert "the run waits and then takes the answer"                   "$( cat "$rigDir/out" )" RIG-FINAL-MARKER
rigAssert "the log names the status without the CR"                   "$( rigHolds "$rigDir/err" 'HTTP 503)' )" yes

## The pause is said in the run's own session thread, which is the thread of the session it
## joined -- not the one under its own spawn id, which a joining run never has.
rigStart joined-run-thread
mkdir -p "$rigWs/.local/agents/sessions/rig-shared" || exit 1
printf 'CRIG00001:1760000000.000200\n' > "$rigWs/.local/agents/sessions/rig-shared/session.thread"
rigBusy 1 503 RIG-BUSY-MARKER
rigText 2 RIG-FINAL-MARKER
rigRun 0 "$rigMember" MDAT_SESSION_THREAD=CRIG00001:1760000000.000200
rigAssert "a run that joined a session posts the pause into that session's thread" "$( rigHolds "$rigDir/post.1" '"thread_ts":"1760000000.000200"' )" yes

## A post that will not go is said, not swallowed: the pause still holds, and the reader is told
## the thread never heard of it.
rigStart joined-run-post-fails
printf 'channel_not_found\n' > "$rigDir/post-errors"
rigBusy 1 503 RIG-BUSY-MARKER
rigText 2 RIG-FINAL-MARKER
rigRun 0 "$rigMember" MDAT_SESSION_THREAD=CRIG00001:1760000000.000200
rigAssert "a pause the thread never heard of says so"                  "$( rigHolds "$rigDir/err" 'the pause could not be posted to CRIG00001:1760000000.000200' )" yes
rigAssert "and the run still waits and takes its answer"               "$( cat "$rigDir/out" )" RIG-FINAL-MARKER

## A status the list does not name settles the refusal on its own: no word in its body makes it
## temporary, so the run ends rather than waiting on a condition nobody called temporary. This row is
## a control, green on both sides: it holds the other side of the rule that a status settles the refusal.
rigStart unlisted-status
rigBusy 1 501 RIG-UNLISTED-MARKER
rigText 2 RIG-SHOULD-NEVER-BE-ASKED
rigRun 0 "$rigMember"
rigAssert "HTTP 501, unlisted, ends the run"                          "$rigRunStatus" 1
rigAssert "and is asked once"                                          "$rigRoundCount" 1
rigAssert "and is not called busy"                                     "$( rigHolds "$rigDir/err" 'BUSY:' )" no

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BUSY ANSWER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_BUSY_ANSWER: OK (%d assertions, offline, a fake curl)\n' "$rigPassCount"
