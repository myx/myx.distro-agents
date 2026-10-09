#!/usr/bin/env bash
## Behavioural check on the prompt-cache routing key of AgentsOpenAiChatWire.sh, run
## through the real leaves against the shared fake `curl`, which records each round's
## body and its stdin header channel. What it proves: prompt_cache_key is one value for
## every round and every restart of one harness session, another value for another
## session, the same value as the x-grok-conv-id header on the xAI leaf, and absent
## when switched off -- by HARNESS_PROMPT_CACHE_KEY=off, or by the Scaleway and Copilot
## leaves, which default it off. Offline by construction: no socket, no credential.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

for rigLeafName in Grok Scaleway Copilot ; do
	[ -f "$rigHere/Agents${rigLeafName}Harness.sh" ] || rigRefuse "the $rigLeafName leaf is not at the origin this workspace resolves"
done

rigTmp="$( mktemp -d -t "AgentsHarnessPromptCacheKeyCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-copilot-leg-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "a fixture is missing from the package: $rigTest/check-fixtures/harness-copilot-leg-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
RIG_DECL_DIR="$rigTmp"
export RIG_DECL_DIR

rigOnPath(){
	[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue a real request against a live endpoint"
}

## Every credential name a leaf reads, forced to a literal.
export XAI_API_KEY="rig-not-a-credential"
export SCALEWAY_DEEPSEEK="rig-not-a-credential"
export SCALEWAY_GEMMA="rig-not-a-credential"
export COPILOT_GITHUB_TOKEN="rig-not-a-credential"
## The switch under test is set per run, never inherited from this environment.
unset HARNESS_PROMPT_CACHE_KEY

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigOnPath
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir"
	printf '0' > "$rigScenarioDir/round"
}

rigTextStream(){ ## canned-stream file, content
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' "$2" > "$1"
	printf 'data: [DONE]\n' >> "$1"
}

rigReadStream(){ ## canned-stream file, path to read
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call","type":"function","function":{"name":"Read","arguments":"{\\"path\\":\\"%s\\"}"}}]}}]}\n' "$2" > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' >> "$1"
	printf 'data: [DONE]\n' >> "$1"
}

## The session comes from --session-id alone: the session variables of whatever client
## runs this check are removed, so they can neither supply nor change the key.
rigRunStatus=0
rigRun(){ ## leaf name, then the leaf arguments this scenario adds
	local runLeaf="$1"
	shift
	rigRunStatus=0
	RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" \
		env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT \
		"$rigHere/Agents${runLeaf}Harness.sh" --access-write-root "$rigScenarioDir" "$@" RIG-TASK-MARKER \
		> "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || rigRunStatus=$?
	[ "$( cat "$rigScenarioDir/round" )" != 0 ] || rigRefuse "the $runLeaf leaf issued no request at all, so this scenario exercised nothing -- its stderr: $( head -5 "$rigScenarioDir/err" )"
}

## The key a request body carries, or `absent`.
rigBodyKey(){ ## request file
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	LC_ALL=C sed -n 's/.*"prompt_cache_key":"\([^"]*\)".*/\1/p' "$1" | head -1 | grep . || printf 'absent'
}

## The x-grok-conv-id header value a round sent on stdin, or `absent`.
rigHeaderKey(){ ## stdin file
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	LC_ALL=C sed -n 's/^x-grok-conv-id: //p' "$1" | head -1 | grep . || printf 'absent'
}

rigPassCount=0
rigFailCount=0
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

## A case arm inside $( ) is a syntax error under bash 3.2, so the shape tests live here.
rigKeyShape(){ ## key
	case "$1" in
		*rig-session*) printf 'leaks' ;;
		harness-[0-9]*) printf 'opaque' ;;
		*) printf '%s' "$1" ;;
	esac
}

rigDiffers(){ ## a, b
	if [ "$1" != "$2" ] ; then printf 'differs' ; else printf 'same:%s' "$1" ; fi
}

rigVerdict(){ ## scenario title
	local verdictMark=PASS
	[ "$rigScenarioFail" = 0 ] || verdictMark=FAIL
	printf '  %s  %s -- %d of %d assertions\n' "$verdictMark" "$1" "$rigScenarioPass" "$(( rigScenarioPass + rigScenarioFail ))"
	rigPassCount=$(( rigPassCount + rigScenarioPass ))
	rigFailCount=$(( rigFailCount + rigScenarioFail ))
	rigScenarioPass=0
	rigScenarioFail=0
}

## A. Two rounds of one session on the xAI leaf: one key, in the body and the header.
rigStart a-one-session-two-rounds
printf 'RIG-TOOLRESULT-MARKER\n' > "$rigScenarioDir/read.txt"
rigReadStream "$rigScenarioDir/res.1" "$rigScenarioDir/read.txt"
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun Grok --session-id rig-session-one
rigKeyA1="$( rigBodyKey "$rigScenarioDir/req.1" )"
rigKeyA2="$( rigBodyKey "$rigScenarioDir/req.2" )"
rigAssert "the run ends normally"                         "$rigRunStatus" 0
rigAssert "two rounds were requested"                     "$( cat "$rigScenarioDir/round" )" 2
rigAssert "round 1 carries an opaque key"                         "$( rigKeyShape "$rigKeyA1" )" opaque
rigAssert "round 2 carries the identical key"             "$rigKeyA2" "$rigKeyA1"
rigAssert "x-grok-conv-id is the same value, round 1"     "$( rigHeaderKey "$rigScenarioDir/stdin.1" )" "$rigKeyA1"
rigAssert "x-grok-conv-id is the same value, round 2"     "$( rigHeaderKey "$rigScenarioDir/stdin.2" )" "$rigKeyA1"
rigAssert "the key sits after stream_options"             "$( LC_ALL=C grep -c '"stream_options":{"include_usage":true},"prompt_cache_key":"' "$rigScenarioDir/req.1" )" 1
rigVerdict "one session, two rounds -- one key, in the body and the xAI header"

## B. A restart of the same session is a new process with the same key.
rigStart b-same-session-restart
rigTextStream "$rigScenarioDir/res.1" RIG-FINAL-MARKER
rigRun Grok --session-id rig-session-one
rigAssert "a restart of the session keeps its key"        "$( rigBodyKey "$rigScenarioDir/req.1" )" "$rigKeyA1"
rigVerdict "the same session in a new process -- the same key"

## C. Another session gets another key.
rigStart c-other-session
rigTextStream "$rigScenarioDir/res.1" RIG-FINAL-MARKER
rigRun Grok --session-id rig-session-two
rigKeyC="$( rigBodyKey "$rigScenarioDir/req.1" )"
rigAssert "another session carries an opaque key"                 "$( rigKeyShape "$rigKeyC" )" opaque
rigAssert "and it differs from the first session"         "$( rigDiffers "$rigKeyC" "$rigKeyA1" )" differs
rigVerdict "another session -- another key"

## D. Switched off: neither the field nor the header.
rigStart d-switched-off
rigTextStream "$rigScenarioDir/res.1" RIG-FINAL-MARKER
HARNESS_PROMPT_CACHE_KEY=off rigRun Grok --session-id rig-session-one
rigAssert "no prompt_cache_key when off"                  "$( rigBodyKey "$rigScenarioDir/req.1" )" absent
rigAssert "no x-grok-conv-id when off"                    "$( rigHeaderKey "$rigScenarioDir/stdin.1" )" absent
rigAssert "stdin carries the bearer alone"                "$( cat "$rigScenarioDir/stdin.1" )" "Authorization: Bearer rig-not-a-credential"
rigVerdict "HARNESS_PROMPT_CACHE_KEY=off -- no field, no header"

## E. No session at all: nothing stable to key on, so nothing is sent.
rigStart e-no-session
rigTextStream "$rigScenarioDir/res.1" RIG-FINAL-MARKER
rigRun Grok
rigAssert "no session, no prompt_cache_key"               "$( rigBodyKey "$rigScenarioDir/req.1" )" absent
rigAssert "no session, no x-grok-conv-id"                 "$( rigHeaderKey "$rigScenarioDir/stdin.1" )" absent
rigVerdict "no session -- no key"

## F. The leaves that default it off, and the switch turning it back on.
for rigLeafName in Scaleway Copilot ; do
	rigStart "f-$rigLeafName-default"
	rigTextStream "$rigScenarioDir/res.1" RIG-FINAL-MARKER
	rigRun "$rigLeafName" --session-id rig-session-one
	rigAssert "$rigLeafName: no prompt_cache_key by default"   "$( rigBodyKey "$rigScenarioDir/req.1" )" absent
	rigAssert "$rigLeafName: no x-grok-conv-id, not xAI"       "$( rigHeaderKey "$rigScenarioDir/stdin.1" )" absent
	rigStart "f-$rigLeafName-on"
	rigTextStream "$rigScenarioDir/res.1" RIG-FINAL-MARKER
	HARNESS_PROMPT_CACHE_KEY=on rigRun "$rigLeafName" --session-id rig-session-one
	rigAssert "$rigLeafName: =on sends the session key"        "$( rigBodyKey "$rigScenarioDir/req.1" )" "$rigKeyA1"
	rigAssert "$rigLeafName: =on still sends no xAI header"    "$( rigHeaderKey "$rigScenarioDir/stdin.1" )" absent
	rigVerdict "$rigLeafName defaults it off, and =on turns it on"
done

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PROMPT CACHE KEY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "✅ PROMPT CACHE KEY CHECK PASSED: $rigPassCount assertion(s)"
