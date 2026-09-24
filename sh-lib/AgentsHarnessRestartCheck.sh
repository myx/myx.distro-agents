#!/usr/bin/env bash
## Behavioural check on summarise-and-restart -- the one thing the three coherence
## checks beside it cannot see, because they read the sources and this one runs them.
## A fake `curl` first on PATH records each request body and replays a canned stream
## per round, so the REAL core and the REAL wire drive four scenarios: the threshold
## fires and the leg restarts, the threshold is disabled and every one of those
## assertions answers the other way, the summarise step produces nothing and the run
## fails loud, and the restart bound is spent. Offline by construction -- no socket is
## opened, no credential is read, and nothing outlives the EXIT trap.
set -u
rigHere="$( cd "$( dirname -- "$0" )" && pwd )"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
[ -f "$rigHarness" ] || { echo "⛔ ERROR: harness not found beside this check: $rigHarness" >&2 ; exit 1 ; }

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

rigTmp="$( mktemp -d -t AgentsHarnessRestartCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
## The fake binaries this rig puts on PATH are REAL FILES under sh-lib/check-fixtures
## and are copied, never carried here in a heredoc: a delimiter lost inside a body
## that is itself shell takes the rest of this check with it, and a check that stops
## checking still prints its PASS lines. A missing fixture refuses instead.
rigFixtures="$rigHere/check-fixtures"
cp "$rigFixtures/harness-restart-check.curl.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigFixtures/harness-restart-check.curl.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## A provider stub's job, done here instead: the core refuses to start without these.
## The host is a reserved .invalid name that can never resolve and the token is a
## literal, so nothing in this rig can reach a service or spend a credential.
export HARNESS_PROVIDER_NAME="restart-check rig"
export HARNESS_SELF_NAME="AgentsHarnessRestartCheck.sh"
export HARNESS_ENDPOINT="https://harness-restart-check.invalid/v1/chat/completions"
export HARNESS_HOST="harness-restart-check.invalid"
export HARNESS_WIRE="OpenAiChat"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_LIGHT="rig-not-a-credential"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir"
	printf '0' > "$rigScenarioDir/round"
	printf 'RIG-TOOLRESULT-MARKER\n' > "$rigScenarioDir/read.txt"
}

## A round answering with one Read tool call, then the usage chunk the threshold reads.
rigToolStream(){ ## canned-stream file, this round's total_tokens
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call","type":"function","function":{"name":"Read","arguments":"{\\"path\\":\\"%s\\"}"}}]}}]}\n' "$rigScenarioDir/read.txt" > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":%s}}\n' "$2" >> "$1"
	printf 'data: [DONE]\n' >> "$1"
}

## A round answering with plain text and no tool call.
rigTextStream(){ ## canned-stream file, content, finish_reason, this round's total_tokens
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"%s"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":%s}}\n' "$2" "$3" "$4" > "$1"
	printf 'data: [DONE]\n' >> "$1"
}

## Publishes $rigRunStatus and $rigRoundCount for its caller, the way the core's own
## AgentsHarnessPathAllowed publishes $harnessResolvedPath.
rigRunStatus=0
rigRoundCount=0
rigRun(){ ## MDAT_HARNESS_CONTEXT_TOKENS, MDAT_HARNESS_MAX_RESTARTS
	rigRunStatus=0
	## MMDAPP points at the scenario so the core's own PreToolUse hooks read no
	## settings file and every tool call runs, which is what this rig is measuring.
	RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" \
		MDAT_HARNESS_CONTEXT_TOKENS="$1" MDAT_HARNESS_MAX_RESTARTS="$2" \
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

## yes/no rather than a status, so both directions are values a failure can print.
## A request that was never made gets its own third value: it is not the same finding
## as one made without the text, and a bare `no` would read as though it were.
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

rigStart threshold-fires
rigToolStream "$rigScenarioDir/res.1" 5000
rigTextStream "$rigScenarioDir/res.2" RIG-SUMMARY-MARKER stop 20
rigTextStream "$rigScenarioDir/res.3" RIG-FINAL-MARKER stop 20
rigRun 1000 3
rigAssert "the run ends normally"                      "$rigRunStatus" 0
rigAssert "three rounds were requested"                "$rigRoundCount" 3
rigAssert "the threshold announced itself"             "$( rigHolds "$rigScenarioDir/err" 'context threshold reached' )" yes
rigAssert "the restart was announced as 1 of 3"        "$( rigHolds "$rigScenarioDir/err" 'summarising for restart 1 of 3' )" yes
rigAssert "the fresh leg announced itself"             "$( rigHolds "$rigScenarioDir/err" 'original task verbatim plus the summary above' )" yes
rigAssert "the fresh leg's own answer is the result"   "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigAssert "round 1 offered the tools"                  "$( rigHolds "$rigScenarioDir/req.1" '"tool_choice":"auto"' )" yes
rigAssert "the summarise round withdrew the tools"     "$( rigHolds "$rigScenarioDir/req.2" '"tool_choice":"none"' )" yes
rigAssert "the summarise round asked for a handover"   "$( rigHolds "$rigScenarioDir/req.2" 'Write the handover a fresh leg needs' )" yes
rigAssert "the summarise round still held the history" "$( rigHolds "$rigScenarioDir/req.2" 'RIG-TOOLRESULT-MARKER' )" yes
rigAssert "the fresh leg carries the task verbatim"    "$( rigHolds "$rigScenarioDir/req.3" 'RIG-TASK-MARKER' )" yes
rigAssert "the fresh leg carries the summary"          "$( rigHolds "$rigScenarioDir/req.3" 'RIG-SUMMARY-MARKER' )" yes
rigAssert "the fresh leg dropped the old history"      "$( rigHolds "$rigScenarioDir/req.3" 'RIG-TOOLRESULT-MARKER' )" no
rigAssert "the fresh leg has its tools back"           "$( rigHolds "$rigScenarioDir/req.3" '"tool_choice":"auto"' )" yes
rigVerdict "the threshold fires and the leg restarts"

## The negative control, and the reason a green run here cannot be a vacuous one:
## the same probes against the same canned rounds, with the threshold off.
rigStart threshold-disabled
rigToolStream "$rigScenarioDir/res.1" 5000
rigTextStream "$rigScenarioDir/res.2" RIG-SUMMARY-MARKER stop 20
rigRun 0 3
rigAssert "the run ends normally"            "$rigRunStatus" 0
rigAssert "two rounds were requested"        "$rigRoundCount" 2
rigAssert "no threshold was announced"       "$( rigHolds "$rigScenarioDir/err" 'context threshold reached' )" no
rigAssert "no fresh leg was announced"       "$( rigHolds "$rigScenarioDir/err" 'original task verbatim plus the summary above' )" no
rigAssert "round 2 kept its tools"           "$( rigHolds "$rigScenarioDir/req.2" '"tool_choice":"none"' )" no
rigAssert "no third round was requested"     "$( if [ -f "$rigScenarioDir/req.3" ] ; then printf yes ; else printf no ; fi )" no
rigVerdict "the threshold is disabled -- every restart assertion the other way"

rigStart summary-empty
rigToolStream "$rigScenarioDir/res.1" 5000
rigTextStream "$rigScenarioDir/res.2" "" length 20
rigRun 1000 3
rigAssert "the run fails"                              "$rigRunStatus" 1
rigAssert "two rounds were requested"                  "$rigRoundCount" 2
rigAssert "the refusal names the empty summarise step" "$( rigHolds "$rigScenarioDir/err" 'the summarise step produced no text' )" yes
rigAssert "the refusal names the finish reason"        "$( rigHolds "$rigScenarioDir/err" 'finish_reason=length' )" yes
rigAssert "nothing was printed as an answer"           "$( cat "$rigScenarioDir/out" )" ""
rigVerdict "the summarise step produces nothing -- the run fails loud"

rigStart restart-bound
rigToolStream "$rigScenarioDir/res.1" 5000
rigTextStream "$rigScenarioDir/res.2" RIG-SUMMARY-MARKER stop 20
rigToolStream "$rigScenarioDir/res.3" 5000
rigTextStream "$rigScenarioDir/res.4" RIG-FINAL-MARKER stop 20
rigRun 1000 1
rigAssert "the run ends cut-short-but-reported"      "$rigRunStatus" 3
rigAssert "four rounds were requested"               "$rigRoundCount" 4
rigAssert "the one restart was announced as 1 of 1"  "$( rigHolds "$rigScenarioDir/err" 'summarising for restart 1 of 1' )" yes
rigAssert "the fresh leg was announced"              "$( rigHolds "$rigScenarioDir/err" 'original task verbatim plus the summary above' )" yes
rigAssert "the spent budget was announced"           "$( rigHolds "$rigScenarioDir/err" 'with no restart left' )" yes
rigAssert "the closing round withdrew the tools"     "$( rigHolds "$rigScenarioDir/req.4" '"tool_choice":"none"' )" yes
rigAssert "the closing round's answer is the result" "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "the restart bound is spent -- closing round, exit 3"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ RESTART CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_RESTART: OK (%d scenarios, %d assertions, offline)\n' "$rigScenarioCount" "$rigPassCount"
