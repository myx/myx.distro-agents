#!/usr/bin/env bash
## Behavioural check on the FULL SERVICE LEG, standard-v1: it declares no endpoint, no model
## and no credential of its own, and refuses before any request when the preset did not give
## them. Offline: nothing here reaches a network, and no leg runs past its own refusals.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
leg="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsStandardV1Harness.sh"
[ -f "$leg" ] || { echo "⛔ ERROR: the full service leg is not there: $leg" >&2 ; exit 1 ; }
## The leg's output and its home live under the workspace's own temp folder, never the system's.
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsStandardV1LegCheck.XXXXXX" )" || { echo "⛔ ERROR: no scratch folder under the workspace" >&2 ; exit 1 ; }
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/home"
rigOut="$rigTmp/standard-v1.out" rigErr="$rigTmp/standard-v1.err"

pass=0 fail=0
check(){ ## name, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$(( pass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$(( fail + 1 )) ; fi
}
runLeg(){ ## environment pairs, then the prompt
	( cd "$( dirname "$leg" )" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" "$@" bash "$leg" "rig prompt" ) > "$rigOut" 2> "$rigErr"
	echo $?
}

echo "-- the leg declares the service and nothing else --"
check "the console can list it: a provider name is declared" \
	"$( LC_ALL=C grep -c '^HARNESS_PROVIDER_NAME=' "$leg" )" 1
check "no endpoint of its own is assigned: no literal URL" \
	"$( LC_ALL=C grep -c '^HARNESS_ENDPOINT="https' "$leg" )" 0
## A server this leg cannot know, so the defaults are stated and a preset may override them
## with PRESET_CONTEXT_MAX_SIZE; the core reads the pair as its restart threshold.
check "it states a family table rather than falling to the core's 400000" \
	"$( LC_ALL=C grep -c '^HARNESS_MODEL_TABLE=".*AgentsHarnessOpenModelTable' "$leg" )" 1
check "and the table is exported to the core, with the origin of each model" \
	"$( LC_ALL=C grep -c '^export HARNESS_MODEL_TABLE HARNESS_MODEL_FROM_LIGHT HARNESS_MODEL_FROM_MAIN$' "$leg" )" 1

echo "-- without the preset's values it refuses, and names what is missing --"
check "no endpoint: refused" \
	"$( runLeg )" 1
check "no endpoint: the refusal names PRESET_ENDPOINT_URL" \
	"$( LC_ALL=C grep -c 'PRESET_ENDPOINT_URL' "$rigErr" )" 1

## A macro names no model, so the leg resolves it: low to the smaller qwen3 chat model, normal and high to the larger.
## Stated statically, as reaching them needs a live request.
check "no model named: the macros resolve to the agreed Qwen3.5 4B and 9B, by their served ids" \
	"$( LC_ALL=C grep -c -e '^HARNESS_MODEL_LIGHT="${HARNESS_MODEL_LIGHT:-qwen3.5-4b-q8_0}"' -e '^HARNESS_MODEL_MAIN="${HARNESS_MODEL_MAIN:-qwen3.5-9b-q8_0}"' "$leg" )" 2

check "no credential: refused" \
	"$( runLeg HARNESS_ENDPOINT_URL=https://example.invalid/v1 HARNESS_MODEL_LIGHT=rig-light HARNESS_MODEL_MAIN=rig-main )" 1
check "no credential: the refusal names both keys it takes" \
	"$( LC_ALL=C grep -c -e 'ANTHROPIC_API_KEY' -e 'OPENAI_API_KEY' "$rigErr" )" 1

echo "-- with every value given it runs: the request carries the preset's model on the wire its endpoint's path picks --"
## The positive control of the refusals above, and the run of the wire choice the greps below only read: a fake curl first
## on PATH (the fixture the harness checks share) keeps the request body and replays one canned OpenAI-chat stream.
rigScn="$rigTmp/scn" ; mkdir -p "$rigTmp/bin" "$rigScn" "$rigTmp/work"
cp "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/harness-restart-check.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl"
runWire(){ ## endpoint path -- the leg's rc, with the canned stream replayed and the request body kept in $rigScn/req.1
	rm -f -- "$rigScn"/req.* "$rigScn"/stdin.* ; printf '0' > "$rigScn/round"
	printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-STANDARD-ANSWER"},"finish_reason":"stop"}],"usage":{"prompt_tokens":5,"completion_tokens":3,"total_tokens":8}}\ndata: [DONE]\n' > "$rigScn/res.1"
	( cd "$rigTmp/work" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" MMDAPP="$MMDAPP" RIG_SCENARIO="$rigScn" \
		HARNESS_ENDPOINT_URL="https://standard-check.invalid/$1" HARNESS_MODEL_LIGHT=qwen3-4b HARNESS_MODEL_MAIN=qwen3-8b OPENAI_API_KEY=rig-not-a-credential \
		bash "$leg" --access-root "$rigTmp/work" "rig prompt" ) > "$rigOut" 2> "$rigErr"
	echo $?
}
check "an OpenAI-style base: the run ends 0" "$( runWire v1 )" 0
check "its answer is the output, after exactly one request" "$( LC_ALL=C grep -c 'RIG-STANDARD-ANSWER' "$rigOut" ) $( cat "$rigScn/round" )" "1 1"
check "the request names the model the preset gave, on the chat wire (stream_options)" "$( LC_ALL=C grep -c '^{"model":"qwen3-8b"' "$rigScn/req.1" ) $( LC_ALL=C grep -c -F '"stream_options"' "$rigScn/req.1" )" "1 1"
runWire anthropic > /dev/null
check "an /anthropic base: the request is the Messages wire's (a top-level system, cache_control, no stream_options)" \
	"$( LC_ALL=C grep -c -F '"system":"' "$rigScn/req.1" ) $( LC_ALL=C grep -c -F '"cache_control"' "$rigScn/req.1" ) $( LC_ALL=C grep -c -F '"stream_options"' "$rigScn/req.1" )" "1 1 0"
runUnknownModel(){ ## the note on a model of no known family, then the requests made
	rm -f -- "$rigScn"/req.* ; printf '0' > "$rigScn/round"
	( cd "$rigTmp/work" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" MMDAPP="$MMDAPP" RIG_SCENARIO="$rigScn" \
		HARNESS_ENDPOINT_URL="https://standard-check.invalid/v1" HARNESS_MODEL_LIGHT=rig-light HARNESS_MODEL_MAIN=rig-main OPENAI_API_KEY=rig-not-a-credential \
		bash "$leg" --access-root "$rigTmp/work" "rig prompt" ) > "$rigOut" 2> "$rigErr"
	printf '%s %s' "$( LC_ALL=C grep -c 'rig-main.*is of no family' "$rigErr" )" "$( cat "$rigScn/round" )"
}
runBlocked(){ ## the finish reason the provider ends an empty answer with -- the leg's rc; the reason it keeps beside the record is read from $rigScn/sb
	rm -f -- "$rigScn"/req.* "$rigScn"/stdin.* ; rm -rf -- "$rigScn/sb" ; mkdir -p "$rigScn/sb" ; printf '0' > "$rigScn/round"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"%s"}],"usage":{"prompt_tokens":5,"completion_tokens":0,"total_tokens":5}}\ndata: [DONE]\n' "$1" > "$rigScn/res.1"
	( cd "$rigTmp/work" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" MMDAPP="$MMDAPP" RIG_SCENARIO="$rigScn" \
		MDAT_SPAWN_SANDBOX_ROOT="$rigScn/sb" MDAT_SPAWN_SESSION_ID=blocked1 \
		HARNESS_ENDPOINT_URL="https://standard-check.invalid/v1" HARNESS_MODEL_LIGHT=qwen3-4b HARNESS_MODEL_MAIN=qwen3-8b OPENAI_API_KEY=rig-not-a-credential \
		bash "$leg" --access-root "$rigTmp/work" "rig prompt" ) > "$rigOut" 2> "$rigErr"
	echo $?
}
## sketch 3.6: a provider block that ends the run is kept beside the record with its reason, as a refusal is, so the flag and the alert show it
check "an answer the provider ended empty on a content filter: the run ends 1" "$( runBlocked content_filter )" 1
check "and the reason it kept names the provider's finish reason" "$( head -1 "$rigScn/sb/blocked1.refused" 2> /dev/null | LC_ALL=C grep -c 'content_filter' )" 1

check "a model of no known family gets the default limits and one note naming it, and the request is made (sketch 13.1: the default is reasonable)" "$( runUnknownModel )" "1 1"
echo "-- the wire follows the endpoint's own path --"
## Stated statically: reaching either branch needs a live request, which this check never makes.
check "the leg names the Anthropic Messages wire for a /anthropic base" \
	"$( LC_ALL=C grep -c 'AnthropicMessages' "$leg" )" 1
check "and the OpenAI chat wire for every other base" \
	"$( LC_ALL=C grep -c 'OpenAiChat' "$leg" )" 1
## THE LEG IS STARTED AS A PROGRAM, SO THE BIT IS PART OF ITS CONTRACT: a leg that lost +x fails a
## spawn with "Permission denied" and nothing else says why -- a rig lost it exactly that way.
check "the leg is executable, because it is run as a program and not read" \
	"$( [ -x "$leg" ] && printf yes || printf no )" yes

rm -f -- "$rigOut" "$rigErr"
if [ "$fail" = 0 ] ; then printf 'STANDARD_V1_LEG: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ STANDARD_V1_LEG CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$(( pass + fail ))" ; exit 1
