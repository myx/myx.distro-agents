#!/usr/bin/env bash
## Behavioural check on the effort changed while a run goes on (F10.7 of the refactorings epic, Constraint 12): a harness run
## reads `sessions/<key>/effort` before every request (the run's own store, else its coworking session's), and the effort of the
## request is that; and, because a change of effort in the middle of a conversation is a known silent invalidator of the input
## token cache, the run SAYS so when it reads a change. --manager-session-effort <session-id> <unset|none|low|normal|high> writes the file.
## Run through the real core and the Anthropic Messages wire against a fake `curl` replaying canned streams; the file is written
## by the fake curl's hook while round 1 is answered, so round 2 is the first to see it. Held:
##   1. the tier's own effort (heavy: high) stands where nothing is asked
##   2. low, high, normal asked between rounds: the next request carries low, high, or medium (normal); unset sends none, and the effort none is a level of its own,
##      and one `input cache` line names the old effort and the new; asking what already stands says nothing
##   3. an effort asked before the first request is the starting one, and says nothing
##   4. a value that is none of the three is ignored; the coworking session's store is read where the run's own has none
##   5. the operation: it writes the file and prints one row; refuses a bad effort, an unknown or ill-formed id, a wrong count of
##      words, and a member's session; and its help is paired
## Offline by construction: no socket, no credential.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTest="$rigPackage/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigHarness" ] || { echo "⛔ ERROR: harness not found at the origin this workspace resolves: $rigHarness" >&2 ; exit 1 ; }
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsEffortWhileRunningCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-mcp-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

export HARNESS_PROVIDER_NAME="effort rig"
export HARNESS_SELF_NAME="AgentsEffortWhileRunningCheck.test.sh"
export HARNESS_ENDPOINT="https://harness-effort.invalid/v1/messages"
export HARNESS_HOST="harness-effort.invalid"
export HARNESS_WIRE="AnthropicMessages"
export HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_LIGHT="rig-not-a-credential"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"
export HARNESS_OUTPUT_TOKENS_LIGHT="4101"
export HARNESS_OUTPUT_TOKENS_MAIN="4202"

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/.local/agents/sessions/rig-run" "$rigScenarioDir/.local/agents/sessions/rig-cowork"
	printf '0' > "$rigScenarioDir/round"
}
rigStreams(){ ## the two rounds: a Glob call, then the answer
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig1","type":"message","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_RIG","name":"Glob","input":{}}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"pattern\\": \\"*\\", \\"path\\": \\"%s\\"}"}}\n\n' "$rigScenarioDir"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":40}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$rigScenarioDir/res.1"
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig2","type":"message","role":"assistant","content":[],"usage":{"input_tokens":60,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"RIG-DONE"}}\n\n'
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$rigScenarioDir/res.2"
}
rigRun(){ ## harness arguments before the task; RIG_AFTER_ROUND_1 as the scenario sets it
	RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" MDAT_SESSION_ID=rig-cowork \
		"$rigHarness" --session-id rig-run --access-root "$rigScenarioDir" "$@" RIG-TASK-MARKER > "$rigScenarioDir/out" 2> "$rigScenarioDir/err"
	rigRunStatus=$?
	[ "$( cat "$rigScenarioDir/round" )" != 0 ] || rigRefuse "the harness issued no request at all -- its stderr: $( head -5 "$rigScenarioDir/err" )"
}
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	case "$( cat "$1" )" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
}
rigEffortOf(){ ## request file -- the effort the request carries, or none
	LC_ALL=C sed -n 's/.*"output_config":{"effort":"\([a-z]*\)"}.*/\1/p' "$1" | grep . || printf 'none'
}
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigAsk(){ ## the value, the store (rig-run or rig-cowork) -- what a console would write, written in place
	printf '%s\n' "$1" > "$rigScenarioDir/.local/agents/sessions/${2:-rig-run}/effort"
}

echo "-- 1. nothing asked: the tier's own effort --"
rigStart heavy-as-is ; rigStreams
rigRun --tier heavy
rigAssert "round 1 carries the heavy tier's effort high"                     "$( rigEffortOf "$rigScenarioDir/req.1" )" high
rigAssert "round 2 the same"                                                 "$( rigEffortOf "$rigScenarioDir/req.2" )" high
rigAssert "nothing is said of the cache"                                     "$( rigHolds "$rigScenarioDir/err" 'input cache --' )" no

echo "-- 2. asked between the rounds --"
rigStart to-low ; rigStreams
RIG_AFTER_ROUND_1="printf 'low\\n' > '$rigScenarioDir/.local/agents/sessions/rig-run/effort'" rigRun --tier heavy
rigAssert "round 1 carries high"                                             "$( rigEffortOf "$rigScenarioDir/req.1" )" high
rigAssert "round 2 carries low"                                              "$( rigEffortOf "$rigScenarioDir/req.2" )" low
rigAssert "the run says the input cache is discarded, naming both efforts"   "$( rigHolds "$rigScenarioDir/err" 'input cache -- effort changed from high to low: the cached prefix of this session is discarded' )" yes
rigStart to-normal ; rigStreams
RIG_AFTER_ROUND_1="printf 'normal\\n' > '$rigScenarioDir/.local/agents/sessions/rig-run/effort'" rigRun --tier heavy
rigAssert "normal is a level of its own: round 2 sends medium"               "$( rigEffortOf "$rigScenarioDir/req.2" )" medium
rigAssert "and the line says from high to normal"                            "$( rigHolds "$rigScenarioDir/err" 'effort changed from high to normal' )" yes
rigStart to-unset ; rigStreams
RIG_AFTER_ROUND_1="printf 'unset\\n' > '$rigScenarioDir/.local/agents/sessions/rig-run/effort'" rigRun --tier heavy
rigAssert "unset is the model's default: round 2 sends no effort"            "$( rigEffortOf "$rigScenarioDir/req.2" )" none
rigAssert "and the line says from high to unset"                             "$( rigHolds "$rigScenarioDir/err" 'effort changed from high to unset' )" yes
rigStart to-none ; rigStreams
RIG_AFTER_ROUND_1="printf 'none\\n' > '$rigScenarioDir/.local/agents/sessions/rig-run/effort'" rigRun --tier heavy
rigAssert "none is a level of its own: a service with no none gets its lowest"  "$( rigEffortOf "$rigScenarioDir/req.2" )" low
rigAssert "and the line says from high to none"                              "$( rigHolds "$rigScenarioDir/err" 'effort changed from high to none' )" yes
rigStart to-none-thinking ; rigStreams
RIG_AFTER_ROUND_1="printf 'none\\n' > '$rigScenarioDir/.local/agents/sessions/rig-run/effort'" HARNESS_NONE_FORM=thinking:disabled rigRun --tier heavy
rigAssert "none of a family that switches its thinking off: the thinking is off and no effort is sent"  "$( rigHolds "$rigScenarioDir/req.2" '"thinking":{"type":"disabled"}' ) $( rigEffortOf "$rigScenarioDir/req.2" )" "yes none"
rigStart to-high ; rigStreams
RIG_AFTER_ROUND_1="printf 'high\\n' > '$rigScenarioDir/.local/agents/sessions/rig-run/effort'" rigRun
rigAssert "from unset to high: round 1 sends none, round 2 high"             "$( rigEffortOf "$rigScenarioDir/req.1" ) $( rigEffortOf "$rigScenarioDir/req.2" )" "none high"
rigAssert "and the line says from unset to high"                            "$( rigHolds "$rigScenarioDir/err" 'effort changed from unset to high' )" yes
rigStart same-as-it-stands ; rigStreams
RIG_AFTER_ROUND_1="printf 'high\\n' > '$rigScenarioDir/.local/agents/sessions/rig-run/effort'" rigRun --tier heavy
rigAssert "asking what already stands changes nothing"                       "$( rigEffortOf "$rigScenarioDir/req.2" )" high
rigAssert "and says nothing of the cache"                                    "$( rigHolds "$rigScenarioDir/err" 'input cache --' )" no

echo "-- 3. asked before the first request: the starting effort --"
rigStart before-the-start ; rigStreams
rigAsk low rig-run
rigRun --tier heavy
rigAssert "round 1 already carries low"                                      "$( rigEffortOf "$rigScenarioDir/req.1" )" low
rigAssert "and nothing is said of the cache"                                 "$( rigHolds "$rigScenarioDir/err" 'input cache --' )" no

echo "-- 4. a value that is none of the three; the coworking session's store --"
rigStart nonsense ; rigStreams
RIG_AFTER_ROUND_1="printf 'maximum\\n' > '$rigScenarioDir/.local/agents/sessions/rig-run/effort'" rigRun --tier heavy
rigAssert "a value that is none of the three is ignored"                     "$( rigEffortOf "$rigScenarioDir/req.2" )" high
rigStart cowork-store ; rigStreams
RIG_AFTER_ROUND_1="printf 'low\\n' > '$rigScenarioDir/.local/agents/sessions/rig-cowork/effort'" rigRun --tier heavy
rigAssert "the coworking session's store is read where the run's own has none"  "$( rigEffortOf "$rigScenarioDir/req.2" )" low
rigStart own-ahead ; rigStreams
RIG_AFTER_ROUND_1="printf 'low\\n' > '$rigScenarioDir/.local/agents/sessions/rig-cowork/effort' ; printf 'normal\\n' > '$rigScenarioDir/.local/agents/sessions/rig-run/effort'" rigRun --tier heavy
rigAssert "and the run's own store is ahead of it"                           "$( rigEffortOf "$rigScenarioDir/req.2" )" medium

echo "-- 5. --manager-session-effort --"
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/sessions/rig-session-1" "$rigTmp/home" "$rigTmp/skills"
rigOp(){ ## arguments -- rc and the two streams in op.out, op.err
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" ${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} bash "$rigTool" --manager-session-effort "$@" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err" < /dev/null
	rigRc=$?
}
rigAs=""
rigOp rig-session-1 low
rigAssert "it saves low and prints one row: the id, the effort, the file"    "$rigRc $( LC_ALL=C awk -F'\t' '{ print $1, $2, $3 ; }' "$rigTmp/op.out" ) $( LC_ALL=C awk -F'\t' '{ n = split( $4, p, "/" ) ; print p[ n - 1 ] "/" p[ n ] ; }' "$rigTmp/op.out" )" "0 effort rig-session-1 low rig-session-1/effort"
rigAssert "the file holds that one line"                                      "$( cat "$rigWs/.local/agents/sessions/rig-session-1/effort" )" low
rigOp rig-session-1 high
rigAssert "a second write replaces it"                                       "$rigRc $( cat "$rigWs/.local/agents/sessions/rig-session-1/effort" )" "0 high"
rigOp rig-session-1 none
rigAssert "none is a level of its own and is saved like the others"             "$rigRc $( cat "$rigWs/.local/agents/sessions/rig-session-1/effort" )" "0 none"
rigOp rig-session-1 unset
rigAssert "unset is saved like the others"                                    "$rigRc $( cat "$rigWs/.local/agents/sessions/rig-session-1/effort" )" "0 unset"
rigOp rig-session-1 normal
rigAssert "normal is saved like the others"                                   "$rigRc $( cat "$rigWs/.local/agents/sessions/rig-session-1/effort" )" "0 normal"
rigOp rig-session-1 high
rigAssert "no temp file is left in the store"                                "$( ls -A "$rigWs/.local/agents/sessions/rig-session-1" | tr '\n' ' ' )" "effort "
rigOp rig-session-1 maximum
rigAssert "an effort that is none of the five is refused, and the file stands"  "$rigRc $( cat "$rigWs/.local/agents/sessions/rig-session-1/effort" )" "1 high"
rigOp rig-session-9 low
rigAssert "an id that names no store is refused"                             "$rigRc $( [ -e "$rigWs/.local/agents/sessions/rig-session-9" ] && printf made || printf none )" "1 none"
rigOp '../escape' low
rigAssert "an id that is no bare name is refused, and nothing is written outside"  "$rigRc $( [ -e "$rigWs/.local/agents/escape" ] && printf made || printf none )" "1 none"
rigOp rig-session-1
rigAssert "a wrong count of words is refused"                                "$rigRc" 1
rigAs=keeper-rig
rigOp rig-session-1 low
rigAssert "a member's session is refused, as the console's other operations refuse it"  "$rigRc $( cat "$rigWs/.local/agents/sessions/rig-session-1/effort" )" "1 high"
rigAs=""
rigAssert "the help carries it, and says the per-message trial is not built"  "$( LC_ALL=C grep -c -e '--manager-session-effort <session-id> <unset|none|low|normal|high>' -e 'needs a measured trial against the real API' "$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md" )" 3
rigAssert "and so does the syntax list of the help"                           "$( LC_ALL=C grep -c -e '--manager-session-effort <session-id> <unset|none|low|normal|high>' "$rigPackage/sh-lib/help/Help.DistroAgentsTools.include" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ EFFORT WHILE RUNNING CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'EFFORT_WHILE_RUNNING: OK (%d assertions, offline)\n' "$rigPassCount"
