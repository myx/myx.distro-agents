#!/usr/bin/env bash
## Behavioural check on the UNIVERSAL leg: the universal harness is the full manual type, listed as
## `universal`, and takes every value from the preset that supplies it. It refuses before any
## request when one of them is missing, and says which. Offline: nothing here reaches a network.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
leg="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh"
[ -f "$leg" ] || { echo "⛔ ERROR: the universal harness is not there: $leg" >&2 ; exit 1 ; }

pass=0 fail=0
check(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$(( pass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$(( fail + 1 )) ; fi ; }
runLeg(){ ( cd "$( dirname "$leg" )" && env -i HOME="${HOME:-/tmp}" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" "$@" bash "$leg" "rig prompt" ) > /tmp/universal.out 2> /tmp/universal.err ; echo $? ; }

echo "-- the console lists it as a leg --"
check "a provider name is declared for the console to list" "$( LC_ALL=C grep -c '^HARNESS_PROVIDER_NAME=' "$leg" )" 1
check "no endpoint of its own: the preset supplies one" "$( LC_ALL=C grep -c '^HARNESS_ENDPOINT="https' "$leg" )" 0

echo "-- without the preset's values it refuses, and names what is missing --"
check "no values at all: refused" "$( runLeg )" 1
check "the refusal names the endpoint" "$( LC_ALL=C grep -c 'HARNESS_ENDPOINT' /tmp/universal.err )" 1
check "with an endpoint but no model: refused" "$( runLeg HARNESS_ENDPOINT_URL=https://example.invalid/v1 )" 1
check "the refusal names the light model" "$( LC_ALL=C grep -c 'HARNESS_MODEL_LIGHT' /tmp/universal.err )" 1

echo "-- both wires are reachable from the same file --"
check "the Anthropic Messages wire is named" "$( [ "$( LC_ALL=C grep -c 'AnthropicMessages' "$leg" )" -ge 1 ] && echo yes )" yes
check "and the OpenAI chat wire" "$( [ "$( LC_ALL=C grep -c 'OpenAiChat' "$leg" )" -ge 1 ] && echo yes )" yes

rm -f /tmp/universal.out /tmp/universal.err
if [ "$fail" = 0 ] ; then printf 'UNIVERSAL_LEG: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ UNIVERSAL_LEG CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$(( pass + fail ))" ; exit 1
