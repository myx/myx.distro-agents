#!/usr/bin/env bash
## Behavioural check on the leftover-process ender (sh-lib/harness/AgentsHarnessToolsBash.include, AgentsHarnessProcessLeftoversEnd):
## a leftover record whose process is gone is marked closed, so the pass that ends leftovers reads it once and never again. Held, run
## rather than read:
##   1. A DEAD PID'S RECORD IS MARKED CLOSED, with its out and err sizes.
##   2. A SECOND LOOK DOES NOTHING: the file is not rewritten and no line is printed.
##   3. THE CONTROL: a record without its begun stamp is left alone, so the marking is about a gone process only.
## The suite's own leftover store was 2,308 records re-read at every schedule pass (76 s of it) before this mark.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/harness/AgentsHarnessToolsBash.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: no $rigInclude" >&2 ; exit 1 ; }
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessProcessLeftoverMarkCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigDir="$rigWs/.local/agents/sessions/rig-session/processes"
mkdir -p "$rigDir" || exit 1
mkdir -p "$rigWs/.local/agents/sessions/rig-session" || exit 1
printf 'out\n' > "$rigDir/left-dead.out" || exit 1
printf 'err\n' > "$rigDir/left-dead.err" || exit 1
sleep 0.1 & rigDeadPid=$!
wait "$rigDeadPid" 2> /dev/null || :
printf '%s\n' "$rigDeadPid" > "$rigDir/left-dead.pid" || exit 1
printf '1\n' > "$rigDir/left-dead.began" || exit 1
printf '7\n' > "$rigDir/left-nostamp.pid" || exit 1
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
rigEndLeftovers(){ ## -- one call of the ender against the rig
	MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
		. "$1" || exit 1
		AgentsHarnessProcessLeftoversEnd rig-session
	' rig-leftovers "$rigInclude" 2> /dev/null
}
echo "-- 1. a dead pid's record is marked closed --"
rigAssert "the ender answers no line for a process that is gone" "$( rigEndLeftovers | wc -l | tr -d ' ' )" "0"
rigAssert "and the record carries its closed mark" "$( [ -f "$rigDir/left-dead.closed" ] && printf closed || printf open )" "closed"
rigAssert "the mark carries the sizes the record already had" "$( LC_ALL=C tr '\n' ' ' < "$rigDir/left-dead.closed" 2> /dev/null )" "out 4 err 4 "

echo "-- 2. a second look does nothing --"
rigMarkAt="$( LC_ALL=C stat -f '%m' "$rigDir/left-dead.closed" 2> /dev/null || LC_ALL=C stat -c '%Y' "$rigDir/left-dead.closed" 2> /dev/null )"
sleep 1
rigAssert "the second look answers no line either" "$( rigEndLeftovers | wc -l | tr -d ' ' )" "0"
rigAssert "and does not rewrite the mark" "$( LC_ALL=C stat -f '%m' "$rigDir/left-dead.closed" 2> /dev/null || LC_ALL=C stat -c '%Y' "$rigDir/left-dead.closed" 2> /dev/null )" "$rigMarkAt"

echo "-- 3. the control: no begun stamp, no mark --"
rigEndLeftovers > /dev/null
rigAssert "a record without its begun stamp is left alone" "$( [ -f "$rigDir/left-nostamp.closed" ] && printf closed || printf open )" "open"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS PROCESS LEFTOVER MARK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'HARNESS_PROCESS_LEFTOVER_MARK: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
