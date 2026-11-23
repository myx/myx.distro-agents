#!/usr/bin/env bash
## Behavioural check on the spend statement a run writes when a bound stops it, and on the
## default bounds themselves. The restart check's shape: a fake `curl` first on PATH records
## each request body and replays a canned stream per round, so the REAL core drives every
## scenario. Each canned round states its own prompt and completion, so the figure the
## statement carries is a number this check computes rather than one it compares with itself.
## Offline by construction -- no socket, no credential, and nothing outlives the EXIT trap.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"

## Refusing to report is this rig's whole guard: a rig that never reached its subject must
## never reach its PASS lines, which read exactly like a result. What the subject said is
## printed with it, so a rig that could not start differs from a subject that broke.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2
	[ ! -s "$rigScenarioDir/err" ] || { echo "--- what the harness said:" >&2 ; LC_ALL=C tail -6 "$rigScenarioDir/err" >&2 ; }
	exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"

. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessSpendBoundCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
## The restart check's own fake curl, copied rather than written again: it records each round's
## request body and replays `res.<n>`, and names nothing of the restart that made it.
rigFixtures="$rigTest/check-fixtures"
cp "$rigFixtures/harness-restart-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigFixtures/harness-restart-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## A provider stub's job, done here instead: the core refuses to start without these. The host
## is a reserved .invalid name that can never resolve, so nothing in this rig reaches a service.
export HARNESS_PROVIDER_NAME="spend bound rig"
export HARNESS_SELF_NAME="AgentsHarnessSpendBoundCheck.test.sh"
export HARNESS_ENDPOINT="https://harness-spend-bound.invalid/v1/chat/completions"
export HARNESS_HOST="harness-spend-bound.invalid"
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

## A round answering with one Read tool call, carrying its own usage figures.
rigToolStream(){ ## canned-stream file, prompt tokens, completion tokens
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call","type":"function","function":{"name":"Read","arguments":"{\\"path\\":\\"%s\\"}"}}]}}]}\n' "$rigScenarioDir/read.txt" > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":%s,"completion_tokens":%s,"total_tokens":%s}}\n' "$2" "$3" "$(( $2 + $3 ))" >> "$1"
	printf 'data: [DONE]\n' >> "$1"
}

## A round answering with plain text and no tool call, carrying the same usage shape.
rigTextStream(){ ## canned-stream file, content, finish_reason, prompt tokens, completion tokens
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"%s"}],"usage":{"prompt_tokens":%s,"completion_tokens":%s,"total_tokens":%s}}\n' "$2" "$3" "$4" "$5" "$(( $4 + $5 ))" > "$1"
	printf 'data: [DONE]\n' >> "$1"
}

rigRunStatus=0
rigRoundCount=0
rigSpawnId=""
rigRun(){ ## any number of environment assignments, each its own word
	rigRunStatus=0
	rigEnv=( RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" )
	[ -z "$rigSpawnId" ] || rigEnv+=( MDAT_SPAWN_SANDBOX_ROOT="$rigScenarioDir" MDAT_SPAWN_SESSION_ID="$rigSpawnId" )
	## The leg's own model family table and its names are the caller's, not this rig's: a leg
	## that inherited one refuses a rig model by name, so they are dropped for the child.
	env -u HARNESS_MODEL_TABLE -u HARNESS_MODEL_FROM_LIGHT -u HARNESS_MODEL_FROM_MAIN "${rigEnv[@]}" $@ \
		"$rigHarness" --access-root "$rigScenarioDir" RIG-TASK-MARKER \
		> "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || rigRunStatus=$?
	rigRoundCount="$( cat "$rigScenarioDir/round" )"
	## A scenario that reached no request exercised nothing, and its red would read as the
	## subject's. Refusing here keeps that apart from a real finding.
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
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}

## The statement's own line, so what is asserted is the sentence the run printed rather than a
## figure read out of whatever else it said beside it.
rigSpendLine(){ ## stderr file
	LC_ALL=C sed -n 's/^.*SPEND:[^A-Za-z0-9]*\(rounds .*\)$/\1/p' "$1" 2> /dev/null | head -1
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

## THE ROUND CEILING. Two rounds of 1000 prompt and 9 completion tokens, then the closing round
## the cap asks for. The statement is written at the start of that closing round, so it carries
## the two rounds already spent: 2000 in, 18 out, 2018 total.
rigStart default-round-ceiling
rigToolStream "$rigScenarioDir/res.1" 1000 9
rigToolStream "$rigScenarioDir/res.2" 1000 9
rigTextStream "$rigScenarioDir/res.3" RIG-FINAL-MARKER stop 1000 9
rigRun "MDAT_HARNESS_MAX_ROUNDS=2"
rigAssert "the run ends cut off but reported" "$rigRunStatus" 3
rigAssert "the cap closed it at the third round" "$rigRoundCount" 3
rigAssert "the cap announced itself" "$( rigHolds "$rigScenarioDir/err" 'round cap reached' )" yes
rigAssert "the statement names the spend" "$( rigSpendLine "$rigScenarioDir/err" )" \
	"rounds 3 in 2000 cache-read 0 cache-write 0 out 18 total 2018 stopped-by rounds at 2"
rigAssert "the closing round withdrew the tools" "$( rigHolds "$rigScenarioDir/req.3" '"tool_choice":"none"' )" yes
rigAssert "the closing round's answer is the result" "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "a round ceiling stops the run and states its spend"

## THE OTHER DIRECTION, on the same canned shape: a cap the run never reaches prints no statement.
## Without this pair a statement printed on every run would pass the scenario above.
rigStart under-the-cap
rigToolStream "$rigScenarioDir/res.1" 1000 9
rigToolStream "$rigScenarioDir/res.2" 1000 9
rigTextStream "$rigScenarioDir/res.3" RIG-FINAL-MARKER stop 1000 9
rigRun "MDAT_HARNESS_MAX_ROUNDS=50"
rigAssert "the run ends normally" "$rigRunStatus" 0
rigAssert "three rounds were requested" "$rigRoundCount" 3
rigAssert "no statement was printed" "$( rigSpendLine "$rigScenarioDir/err" )" ""
rigAssert "the last answer is the result" "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "a run under its ceiling states no spend"

## THE RESTART CEILING. One round over a threshold of 1000 asks for a summary, the fresh leg
## spends one round, and the ceiling of one restart turns the next threshold into the closing
## round: 1009 plus 21 plus 1009 is 2039 at the moment the statement is written.
rigStart restart-ceiling
rigToolStream "$rigScenarioDir/res.1" 1000 9
rigTextStream "$rigScenarioDir/res.2" RIG-SUMMARY-MARKER stop 20 1
rigToolStream "$rigScenarioDir/res.3" 1000 9
rigTextStream "$rigScenarioDir/res.4" RIG-FINAL-MARKER stop 1000 9
rigRun "MDAT_HARNESS_CONTEXT_TOKENS=1000" "MDAT_HARNESS_MAX_RESTARTS=1"
rigAssert "the run ends cut off but reported" "$rigRunStatus" 3
rigAssert "one restart was made" "$( rigHolds "$rigScenarioDir/err" 'summarising for restart 1 of 1' )" yes
rigAssert "the spent restart budget announced itself" "$( rigHolds "$rigScenarioDir/err" 'with no restart left' )" yes
rigAssert "the statement names the spend and the bound" "$( rigSpendLine "$rigScenarioDir/err" )" \
	"rounds 4 in 2020 cache-read 0 cache-write 0 out 19 total 2039 stopped-by restarts at 1"
rigVerdict "a restart ceiling stops the run and states its spend"

## THE MARKER the closer reads into the run record, the convention the `.restarts` and
## `.refused` files already use.
rigStart spend-kept
rigSpawnId="rig-spend-run"
rigToolStream "$rigScenarioDir/res.1" 1000 9
rigToolStream "$rigScenarioDir/res.2" 1000 9
rigTextStream "$rigScenarioDir/res.3" RIG-FINAL-MARKER stop 1000 9
rigRun "MDAT_HARNESS_MAX_ROUNDS=2"
rigSpawnId=""
rigAssert "the line was kept beside the run record" \
	"rounds 3 in 2000 cache-read 0 cache-write 0 out 18 total 2018 stopped-by rounds at 2" \
	"$( head -1 "$rigScenarioDir/rig-spend-run.spend" 2> /dev/null )"
rigVerdict "the spend is kept beside the run record"

## THE DEFAULT ITSELF: a run that sets neither knob is stopped at 2000 rounds and 12 restarts,
## and says so on its start line, so a default nobody chose is stated rather than assumed.
rigStart default-bound-present
rigTextStream "$rigScenarioDir/res.1" RIG-FINAL-MARKER stop 20 1
rigRun ""
rigAssert "the run ends normally" "$rigRunStatus" 0
rigAssert "the start line names the default ceilings" "$( rigHolds "$rigScenarioDir/err" 'stops at 2000 rounds, 12 restarts' )" yes
rigAssert "no cap was reached on a one-round run" "$( rigHolds "$rigScenarioDir/err" 'round cap reached' )" no
rigVerdict "a run with neither knob set states the defaults it runs under"

## THE DEFAULT ITSELF, the other direction: the same start line says none where none is set.
rigStart no-bound-said
rigTextStream "$rigScenarioDir/res.1" RIG-FINAL-MARKER stop 20 1
rigRun "MDAT_HARNESS_MAX_ROUNDS=0" "MDAT_HARNESS_MAX_RESTARTS=0"
rigAssert "the run ends normally" "$rigRunStatus" 0
rigAssert "the start line names no ceiling" "$( rigHolds "$rigScenarioDir/err" 'stops at no rounds, no restarts' )" yes
rigVerdict "a run that sets 0 runs under no ceiling"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPEND BOUND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
printf 'HARNESS_SPEND_BOUND: OK (%d scenarios, %d assertions, offline)\n' "$rigScenarioCount" "$rigPassCount"
