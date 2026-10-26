#!/usr/bin/env bash
## Behavioural check on the harness's own settings, as the Harness Configuration forms read and
## apply them: --manager-harness-read and --manager-harness-apply, offline, against a rig workspace.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigWs="$( rigTempDir AgentsManagerHarnessCheck )" || exit 1
trap 'rm -rf -- "$rigWs"' EXIT
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigWs/bin"
printf '#!/bin/sh\nexit 7\n' > "$rigWs/bin/curl" ; chmod +x "$rigWs/bin/curl"

pass=0 fail=0
check(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$(( pass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$(( fail + 1 )) ; fi ; }
run(){ ( cd "$rigWs" && env -i HOME="$rigWs" PATH="$rigWs/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
	MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ) 2> /dev/null ; }
scope="$rigWs/.local/.agents/magic-team.agent.env"

echo "-- the read gives every setting, unset ones empty --"
check "three rows, each key and its value" "$( run --manager-harness-read | LC_ALL=C cut -f1 | tr '\n' ' ' )" "HARNESS_STREAM_ATTEMPTS HARNESS_RETRY_DELAY HARNESS_PARALLEL_TOOL_CALLS "
check "a scope that holds none reads them all empty" "$( run --manager-harness-read | LC_ALL=C cut -f2 | tr -d '\n' )" ""

echo "-- an apply sets the values it was given --"
check "two settings, as one decision" "$( printf 'HARNESS_STREAM_ATTEMPTS\t5\nHARNESS_PARALLEL_TOOL_CALLS\ton\n' | run --manager-harness-apply | tr '\n' ' ' )" "set	HARNESS_STREAM_ATTEMPTS set	HARNESS_PARALLEL_TOOL_CALLS "
check "and they are what the scope now holds" "$( LC_ALL=C grep -c -e '^HARNESS_STREAM_ATTEMPTS=5$' -e '^HARNESS_PARALLEL_TOOL_CALLS=on$' "$scope" )" 2
check "the read shows them" "$( run --manager-harness-read | tr '\n' ' ' )" "HARNESS_STREAM_ATTEMPTS	5 HARNESS_RETRY_DELAY	 HARNESS_PARALLEL_TOOL_CALLS	on "

echo "-- one line refused, nothing written --"
printf 'HARNESS_STREAM_ATTEMPTS\t4\nHARNESS_RETRY_DELAY\t40\n' > "$rigWs/bad"
check "an out-of-range delay refuses the whole apply" "$( run --manager-harness-apply < "$rigWs/bad" > /dev/null 2>&1 ; echo $? )" 1
check "and the valid line of it was not written either" "$( LC_ALL=C grep -c '^HARNESS_STREAM_ATTEMPTS=5$' "$scope" )" 1
check "a word where a number goes is refused" "$( printf 'HARNESS_STREAM_ATTEMPTS\tmany\n' | run --manager-harness-apply > /dev/null 2>&1 ; echo $? )" 1
check "a choice that is neither word is refused" "$( printf 'HARNESS_PARALLEL_TOOL_CALLS\tmaybe\n' | run --manager-harness-apply > /dev/null 2>&1 ; echo $? )" 1
check "a key that is no harness setting is refused" "$( printf 'HARNESS_SOMETHING\t1\n' | run --manager-harness-apply > /dev/null 2>&1 ; echo $? )" 1

echo "-- an empty value takes the setting out, and a value already held is left alone --"
printf 'HARNESS_RETRY_DELAY\t0\n' | run --manager-harness-apply > /dev/null
check "the retry delay removed" "$( printf 'HARNESS_RETRY_DELAY\t\n' | run --manager-harness-apply )" "removed	HARNESS_RETRY_DELAY"
check "and it is gone from the scope" "$( LC_ALL=C grep -c '^HARNESS_RETRY_DELAY=' "$scope" )" 0
check "a value already held is unchanged" "$( printf 'HARNESS_STREAM_ATTEMPTS\t5\n' | run --manager-harness-apply )" "unchanged	HARNESS_STREAM_ATTEMPTS"

if [ "$fail" = 0 ] ; then printf 'MANAGER_HARNESS: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ MANAGER_HARNESS CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$(( pass + fail ))" ; exit 1
