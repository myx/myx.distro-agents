#!/usr/bin/env bash
## Behavioural check on the UNIVERSAL leg: the universal harness is the full manual type, listed as
## `universal`, and takes every value from the preset that supplies it. It refuses before any
## request when one of them is missing, and says which. Offline: nothing here reaches a network.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
leg="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh"
[ -f "$leg" ] || { echo "⛔ ERROR: the universal harness is not there: $leg" >&2 ; exit 1 ; }
## The leg's output and its home live under the workspace's own temp folder, never the system's.
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsUniversalLegCheck.XXXXXX" )" || { echo "⛔ ERROR: no scratch folder under the workspace" >&2 ; exit 1 ; }
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/home"
rigOut="$rigTmp/universal.out" rigErr="$rigTmp/universal.err"

pass=0 fail=0
check(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$(( pass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$(( fail + 1 )) ; fi ; }
runLeg(){ ( cd "$( dirname "$leg" )" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" "$@" bash "$leg" "rig prompt" ) > "$rigOut" 2> "$rigErr" ; echo $? ; }

echo "-- the console lists it as a leg --"
check "a provider name is declared for the console to list" "$( LC_ALL=C grep -c '^HARNESS_PROVIDER_NAME=' "$leg" )" 1
check "no endpoint of its own: the preset supplies one" "$( LC_ALL=C grep -c '^HARNESS_ENDPOINT="https' "$leg" )" 0

echo "-- without the preset's values it refuses, and names what is missing --"
check "no values at all: refused" "$( runLeg )" 1
check "the refusal names the endpoint" "$( LC_ALL=C grep -c 'HARNESS_ENDPOINT' "$rigErr" )" 1
check "with an endpoint but no model: refused" "$( runLeg HARNESS_ENDPOINT_URL=https://example.invalid/v1 )" 1
check "the refusal names the light model" "$( LC_ALL=C grep -c 'HARNESS_MODEL_LIGHT' "$rigErr" )" 1

echo "-- with every value given it runs: one request to the preset's endpoint with its model, and the answer comes back --"
## The positive control of the refusals above: a leg that refused everything would pass those. A fake curl first on PATH
## (the fixture the harness checks share) replays one canned stream and keeps the request body; nothing reaches a network.
rigScn="$rigTmp/scn" ; mkdir -p "$rigTmp/bin" "$rigScn" "$rigTmp/work"
cp "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/harness-restart-check.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl"
printf '0' > "$rigScn/round"
printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-UNIVERSAL-ANSWER"},"finish_reason":"stop"}],"usage":{"prompt_tokens":5,"completion_tokens":3,"total_tokens":8}}\ndata: [DONE]\n' > "$rigScn/res.1"
rigRc="$( cd "$rigTmp/work" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" MMDAPP="$MMDAPP" RIG_SCENARIO="$rigScn" \
	HARNESS_PROVIDER_NAME="universal rig" HARNESS_WIRE=OpenAiChat HARNESS_ENDPOINT="https://universal-check.invalid/v1/chat/completions" HARNESS_HOST=universal-check.invalid \
	HARNESS_CREDENTIAL_NAMES="none" HARNESS_MODEL_LIGHT=rig-light-model HARNESS_MODEL_MAIN=rig-main-model HARNESS_TOKEN_LIGHT=rig-not-a-credential HARNESS_TOKEN_MAIN=rig-not-a-credential \
	bash "$leg" --access-root "$rigTmp/work" "rig prompt" > "$rigOut" 2> "$rigErr" ; echo $? )"
check "it ends 0" "$rigRc" 0
check "the model's answer is its output" "$( LC_ALL=C grep -c 'RIG-UNIVERSAL-ANSWER' "$rigOut" )" 1
check "exactly one request went out" "$( cat "$rigScn/round" )" 1
check "and it names a model the preset gave and carries the prompt" "$( LC_ALL=C grep -c -e '"model":"rig-[a-z]*-model"' "$rigScn/req.1" ) $( LC_ALL=C grep -c 'rig prompt' "$rigScn/req.1" )" "1 1"

echo "-- both wires are reachable from the same file --"
check "the Anthropic Messages wire is named" "$( [ "$( LC_ALL=C grep -c 'AnthropicMessages' "$leg" )" -ge 1 ] && echo yes )" yes
check "and the OpenAI chat wire" "$( [ "$( LC_ALL=C grep -c 'OpenAiChat' "$leg" )" -ge 1 ] && echo yes )" yes

rm -f -- "$rigOut" "$rigErr"
if [ "$fail" = 0 ] ; then printf 'UNIVERSAL_LEG: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ UNIVERSAL_LEG CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$(( pass + fail ))" ; exit 1
