#!/usr/bin/env bash
## Behavioural check on the context-limit repair: a provider's context-length refusal is a
## summarise trigger, never an end. Run through the real core and the real OpenAI wire
## against a fake `curl` that replays canned bodies, so nothing opens a socket and nothing
## reads a credential. Every scenario here is expected to FAIL before the repair and pass
## after it: that red is what makes the green a result.
set -u
: "${MMDAPP:?MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
[ -f "$rigHarness" ] || { echo "⛔ ERROR: harness not found at the origin this workspace resolves: $rigHarness" >&2 ; exit 1 ; }

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessRefusalCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
rigFixtures="$rigTest/check-fixtures"
cp "$rigFixtures/harness-restart-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigFixtures/harness-restart-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## A harness process carries its own leaf's HARNESS_* names in the environment, and this
## rig runs inside one. They are dropped first, so every scenario is judged by this rig's
## own numbers and never by the caller's model table or limits.
unset HARNESS_MODEL_TABLE HARNESS_CONTEXT_TOKENS_LIGHT HARNESS_CONTEXT_TOKENS_MAIN \
	HARNESS_OUTPUT_TOKENS_LIGHT HARNESS_OUTPUT_TOKENS_MAIN

export HARNESS_PROVIDER_NAME="refusal-check rig"
export HARNESS_SELF_NAME="AgentsHarnessRefusalCheck.test.sh"
export HARNESS_ENDPOINT="https://harness-refusal-check.invalid/v1/chat/completions"
export HARNESS_HOST="harness-refusal-check.invalid"
export HARNESS_WIRE="OpenAiChat"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_LIGHT="rig-not-a-credential"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"
export HARNESS_STREAM_ATTEMPTS=1 HARNESS_RETRY_DELAY=0

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir"
	printf '0' > "$rigScenarioDir/round"
	printf 'RIG-TOOLRESULT-MARKER\n' > "$rigScenarioDir/read.txt"
}

## A round answering with one Read tool call, and the usage the trigger reads.
rigToolStream(){ ## canned-stream file, this round's prompt tokens, this round's completion tokens
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call","type":"function","function":{"name":"Read","arguments":"{\\"path\\":\\"%s\\"}"}}]}}]}\n' "$rigScenarioDir/read.txt" > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":%s,"completion_tokens":%s,"total_tokens":%s}}\n' "$2" "$3" "$(( $2 + $3 ))" >> "$1"
	printf 'data: [DONE]\n' >> "$1"
}

## A round answering with plain text and no tool call.
rigTextStream(){ ## canned-stream file, content
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":20,"completion_tokens":2,"total_tokens":22}}\n' "$2" > "$1"
	printf 'data: [DONE]\n' >> "$1"
}

## The service's own refusal body, as DeepSeek sent it for run 3c14b457: no data: frame,
## no [DONE], the numbers stated in the message.
rigRefusalBody(){ ## canned-stream file
	printf '%s' '{"error":{"message":"This model'"'"'s maximum context length is 1048576 tokens. However, you requested 1049121 tokens (665121 in the messages, 384000 in the completion). Please reduce the length of the messages or completion.","type":"invalid_request_error","param":null,"code":"context_length_exceeded"}}' > "$1"
}

rigRunStatus=0
rigRoundCount=0
rigRun(){ ## MDAT_HARNESS_CONTEXT_TOKENS
	rigRunStatus=0
	env RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" \
		MDAT_HARNESS_CONTEXT_TOKENS="$1" \
		"$rigHarness" --access-root "$rigScenarioDir" RIG-TASK-MARKER \
		> "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || rigRunStatus=$?
	rigRoundCount="$( cat "$rigScenarioDir/round" )"
	[ "$rigRoundCount" != 0 ] || rigRefuse "the harness issued no request at all, so this scenario exercised nothing"
}

rigPassCount=0
rigFailCount=0
rigScenarioCount=0
rigScenarioPass=0
rigScenarioFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigScenarioPass=$(( rigScenarioPass + 1 ))
	else
		rigScenarioFail=$(( rigScenarioFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}

rigVerdict(){ ## scenario title
	local verdictMark=PASS
	[ "$rigScenarioFail" = 0 ] || verdictMark=FAIL
	printf '  %s  %s -- %d of %d assertions\n' "$verdictMark" "$1" "$rigScenarioPass" "$(( rigScenarioPass + rigScenarioFail ))"
	rigPassCount=$(( rigPassCount + rigScenarioPass ))
	rigFailCount=$(( rigFailCount + rigScenarioFail ))
	rigScenarioCount=$(( rigScenarioCount + 1 ))
	rigScenarioPass=0
	rigScenarioFail=0
}

## 1. The known positive the brief asks for: the service refuses the round for its length,
## and the run must summarise and carry on instead of dying at the boundary.
rigStart refusal-summarises
rigRefusalBody "$rigScenarioDir/res.1"
rigTextStream "$rigScenarioDir/res.2" RIG-SUMMARY-MARKER
rigTextStream "$rigScenarioDir/res.3" RIG-FINAL-MARKER
rigRun 1000000
rigAssert "the run does not end on the refusal"            "$rigRunStatus" 0
rigAssert "three rounds were requested"                    "$rigRoundCount" 3
rigAssert "the refusal was named as a summarise trigger"   "$( rigHolds "$rigScenarioDir/err" 'refused for its context length' )" yes
rigAssert "the summarise round withdrew the tools"         "$( rigHolds "$rigScenarioDir/req.2" '"tool_choice":"none"' )" yes
rigAssert "the summarise round asked for a handover"       "$( rigHolds "$rigScenarioDir/req.2" 'Write the handover a fresh leg needs' )" yes
rigAssert "the summarise round carried its own allowance"  "$( rigHolds "$rigScenarioDir/req.2" '"max_tokens":8192' )" yes
rigAssert "the fresh leg carries the task verbatim"        "$( rigHolds "$rigScenarioDir/req.3" 'RIG-TASK-MARKER' )" yes
rigAssert "the fresh leg carries the summary"              "$( rigHolds "$rigScenarioDir/req.3" 'RIG-SUMMARY-MARKER' )" yes
rigAssert "the fresh leg's answer is the result"           "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigAssert "the restart was announced"                      "$( rigHolds "$rigScenarioDir/err" 'original task verbatim plus the summary above' )" yes
rigVerdict "a context-length refusal is a summarise trigger, and the run carries on"

## 2. A summarise round the service refuses as well cannot repair anything: the run ends
## with a reason, once, rather than looping on a request that can never be admitted.
rigStart refusal-twice-ends
rigRefusalBody "$rigScenarioDir/res.1"
rigRefusalBody "$rigScenarioDir/res.2"
rigRun 1000000
rigAssert "the run ends"                                   "$rigRunStatus" 1
rigAssert "two rounds were requested, never more"           "$rigRoundCount" 2
rigAssert "the second refusal is named as unrepairable"     "$( rigHolds "$rigScenarioDir/err" 'the summarise round was refused too' )" yes
rigAssert "nothing was printed as an answer"               "$( cat "$rigScenarioDir/out" )" ""
rigVerdict "a summarise round refused in turn ends the run once, with its reason"

## 3. The trigger reads the prompt and the round's own growth, so the round that would
## have been refused one step later restarts here instead. These are run 3c14b457's own
## numbers: prompt 663112, completion 405, threshold 664576.
rigStart prompt-growth-triggers
rigToolStream "$rigScenarioDir/res.1" 663112 405
rigTextStream "$rigScenarioDir/res.2" RIG-SUMMARY-MARKER
rigTextStream "$rigScenarioDir/res.3" RIG-FINAL-MARKER
rigRun 664576
rigAssert "the run ends normally"                          "$rigRunStatus" 0
rigAssert "three rounds were requested"                    "$rigRoundCount" 3
rigAssert "the trigger announced itself"                   "$( rigHolds "$rigScenarioDir/err" 'context threshold reached' )" yes
rigAssert "it named the prompt and the growth"              "$( rigHolds "$rigScenarioDir/err" 'prompt 663112' )" yes
rigAssert "the fresh leg's answer is the result"           "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "a round one step below the ceiling still restarts, on the prompt and its growth"

## 4. The negative control for 3: the same round with the threshold well above it must
## not restart, so the assertions above are not satisfied by a build that always fires.
rigStart prompt-growth-quiet
rigToolStream "$rigScenarioDir/res.1" 663112 405
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun 700000
rigAssert "the run ends normally"                          "$rigRunStatus" 0
rigAssert "two rounds were requested"                      "$rigRoundCount" 2
rigAssert "no threshold was announced"                     "$( rigHolds "$rigScenarioDir/err" 'context threshold reached' )" no
rigAssert "the answer is that round's own text"            "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "a round under the threshold does not restart -- the trigger is graduated"

## 5. A reply reserve that is a quarter of the window or more leaves the trigger no room,
## and the start says so in one line rather than leaving it to be discovered at the limit.
rigStart reserve-is-a-policy-number
rigTextStream "$rigScenarioDir/res.1" RIG-FINAL-MARKER
rigRunStatus=0
env RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" \
	HARNESS_CONTEXT_TOKENS_MAIN=1048576 HARNESS_OUTPUT_TOKENS_MAIN=384000 \
	MDAT_HARNESS_CONTEXT_TOKENS="" \
	"$rigHarness" --access-root "$rigScenarioDir" RIG-TASK-MARKER \
	> "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || rigRunStatus=$?
rigRoundCount="$( cat "$rigScenarioDir/round" )"
[ "$rigRoundCount" != 0 ] || rigRefuse "the reserve scenario issued no request at all"
rigAssert "the run ends normally"                          "$rigRunStatus" 0
rigAssert "the oversized reserve is warned of at start"     "$( rigHolds "$rigScenarioDir/err" 'reply reserve 384000 is a quarter of the window' )" yes
rigAssert "with both numbers named"                         "$( rigHolds "$rigScenarioDir/err" '384000 against 1048576' )" yes
rigVerdict "a reserve at a quarter of the window is a fault, said at start"

## 6. Another provider may refuse the same condition in words no list holds. A request
## refused at three quarters of the window is a context refusal whatever it says.
rigStart refusal-other-wording
rigToolStream "$rigScenarioDir/res.1" 800000 10
printf '%s' '{"error":{"message":"RIG-ODD-REFUSAL-MARKER","type":"invalid_request_error","param":null,"code":"bad_request"}}' > "$rigScenarioDir/res.2"
rigTextStream "$rigScenarioDir/res.3" RIG-SUMMARY-MARKER
rigTextStream "$rigScenarioDir/res.4" RIG-FINAL-MARKER
rigRunStatus=0
env RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" \
	HARNESS_CONTEXT_TOKENS_MAIN=1048576 HARNESS_OUTPUT_TOKENS_MAIN=32768 \
	MDAT_HARNESS_CONTEXT_TOKENS=1000000 \
	"$rigHarness" --access-root "$rigScenarioDir" RIG-TASK-MARKER \
	> "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || rigRunStatus=$?
rigRoundCount="$( cat "$rigScenarioDir/round" )"
rigAssert "the run does not end on the odd-worded refusal"   "$rigRunStatus" 0
rigAssert "four rounds were requested"                      "$rigRoundCount" 4
rigAssert "the size decided it, not the words"               "$( rigHolds "$rigScenarioDir/err" 'refused for its context length' )" yes
rigAssert "the summarise round withdrew the tools"           "$( rigHolds "$rigScenarioDir/req.3" '"tool_choice":"none"' )" yes
rigAssert "the fresh leg's answer is the result"             "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "a refusal at three quarters of the window summarises, whatever its wording"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REFUSAL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_REFUSAL: OK (%d scenarios, %d assertions, offline)\n' "$rigScenarioCount" "$rigPassCount"
