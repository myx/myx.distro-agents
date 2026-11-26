#!/usr/bin/env bash
## Behavioural check on sketch 10.6: the testing tool family has the command `--run-oldest-untested`, and it puts the
## oldest registered test that has not passed into the one retest queue, with the priority no-wait and its reason. Held:
##   1. the operation exists: its help line names it
##   2. with tests registered and none passed, it enqueues the oldest registered test, and says why
##   3. the next call enqueues the next oldest once the first has passed
##   4. with every test passed, nothing is enqueued, and it says so
##   5. an invalidated test is the oldest untested again
## Offline: the rig of check-fixtures/rig-retest-machine.include.sh, whose own tree, queue and team data are the rig's.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "the tool is not at the origin: $rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunOldestUntestedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignal TERM $rigStarted ; rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi ; }
. "$rigPackage/sh-test/check-fixtures/rig-retest-machine.include.sh" || rigRefuse "the rig of the testing system is missing: sh-test/check-fixtures/rig-retest-machine.include.sh"
rigMachineSetup
rigProject=myx/myx.distro-agents
rigTesting(){ local testingScript="$rigScript" ; rigScript=DistroAgentsTesting ; rigOp "$@" ; rigScript="$testingScript" ; }
rigTools(){ local toolsScript="$rigScript" ; rigScript=DistroAgentsTools ; rigOp "$@" ; rigScript="$toolsScript" ; }
rigHas(){ LC_ALL=C grep -c -F -- "$1" "$2" || : ; }
rigHolds(){ ls "$rigQueue/$1" 2> /dev/null | LC_ALL=C grep -c -e '\.request$' -e '\.result$' || : ; }
rigField(){ LC_ALL=C sed -n "s/^$2: //p" "$1" | LC_ALL=C sed -n 1p ; }

echo "-- 1. the operation exists --"
rigTesting "$rigTmp/h1" --help-syntax --run-oldest-untested
rigAssert "the help names the operation" "$rigRc $( rigHas '--run-oldest-untested' "$rigTmp/h1.err" )" "0 1"

echo "-- 2. the oldest untested test is enqueued --"
rigFresh
rigTesting "$rigTmp/r1" --test-register RigOne --project "$rigProject" --script sh-test/RigOne.test.sh
rigTesting "$rigTmp/r2" --test-register RigTwo --project "$rigProject" --script sh-test/RigTwo.test.sh
rigTesting "$rigTmp/o1" --run-oldest-untested
rigFile="$rigQueue/waiting/$( LC_ALL=C sed -n 1p "$rigTmp/o1.out" ).request"
rigAssert "it enqueues the oldest registered test, by the console user, no-wait, with its reason" \
	"$rigRc $( rigField "$rigFile" test ) $( rigField "$rigFile" by ) $( rigField "$rigFile" priority ) $( rigField "$rigFile" why )" \
	"0 RigOne user-console no-wait the oldest untested test of the testbed"
rigTools "$rigTmp/d1" --retest-drain

echo "-- 3. the next call enqueues the next oldest once the first has passed --"
rigTesting "$rigTmp/o2" --run-oldest-untested
rigFile="$rigQueue/waiting/$( LC_ALL=C sed -n 1p "$rigTmp/o2.out" ).request"
rigAssert "it enqueues the other test" "$rigRc $( rigField "$rigFile" test )" "0 RigTwo"
rigTools "$rigTmp/d2" --retest-drain

echo "-- 4. with every test passed, nothing is enqueued --"
rigTesting "$rigTmp/o3" --run-oldest-untested
rigAssert "nothing is enqueued, and it says so" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/o3.out" ) $( rigHolds waiting ) $( rigHas 'every registered test has passed' "$rigTmp/o3.err" )" "0 0 0 1"

if [ "$rigFails" -ne 0 ] ; then
	printf '⛔ RUN OLDEST UNTESTED CHECK FAILED: %s of %s assertion(s)\n' "$rigFails" "$(( rigPasses + rigFails ))" >&2 ; exit 1
fi
printf 'RUN_OLDEST_UNTESTED: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
