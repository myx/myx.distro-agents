#!/usr/bin/env bash
## Behavioural check on sketch 10.6: the testing tool family has the command `--run-all-nightly-regressions`, and it puts
## every registered test eligible for the nightly (nightly: yes) into the one retest queue, with the priority no-wait and
## its reason. Held:
##   1. the operation exists: its help line names it
##   2. with tests registered and flagged nightly, it enqueues exactly the eligible ones, and says why
##   3. a test whose nightly flag is no is not in them
##   4. with none eligible, nothing is enqueued, and it says so
## Offline: the rig of check-fixtures/rig-retest-machine.include.sh, whose own tree, queue and team data are the rig's.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "the tool is not at the origin: $rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunNightlyRegressionsCheck )" || exit 1
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
rigTesting "$rigTmp/h1" --help-syntax --run-all-nightly-regressions
rigAssert "the help names the operation" "$rigRc $( rigHas '--run-all-nightly-regressions' "$rigTmp/h1.err" )" "0 1"

echo "-- 2. the nightly regressions are every eligible test --"
rigFresh
rigAs=magic-tester
rigTesting "$rigTmp/r1" --test-register RigOne --project "$rigProject" --script sh-test/RigOne.test.sh --nightly yes
rigTesting "$rigTmp/r2" --test-register RigTwo --project "$rigProject" --script sh-test/RigTwo.test.sh --nightly yes
rigTesting "$rigTmp/a1" --run-all-nightly-regressions
rigFile="$rigQueue/waiting/$( LC_ALL=C sed -n 1p "$rigTmp/a1.out" ).request"
rigAssert "it enqueues exactly the eligible tests, by the acting member, with the reason" \
	"$rigRc $( LC_ALL=C sed -n 's/^test: //p' "$rigFile" | LC_ALL=C tr '\n' ' ' )$( rigField "$rigFile" by ) $( rigField "$rigFile" why )" \
	"0 RigOne RigTwo magic-tester the nightly regressions of the testbed"
rigAs=""

echo "-- 3. a test whose flag is no is not in them --"
rigTools "$rigTmp/d1" --retest-drain
rigTesting "$rigTmp/u1" --test-update RigTwo --nightly no
rigTesting "$rigTmp/a2" --run-all-nightly-regressions
rigFile="$rigQueue/waiting/$( LC_ALL=C sed -n 1p "$rigTmp/a2.out" ).request"
rigAssert "only the flagged test is enqueued" "$rigRc $( LC_ALL=C sed -n 's/^test: //p' "$rigFile" | LC_ALL=C tr '\n' ' ' )" "0 RigOne "

echo "-- 4. with none eligible, nothing is enqueued --"
rigTools "$rigTmp/d2" --retest-drain
rigTesting "$rigTmp/u2" --test-update RigOne --nightly no
rigTesting "$rigTmp/a3" --run-all-nightly-regressions
rigAssert "nothing is enqueued, and it says so" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/a3.out" ) $( rigHolds waiting ) $( rigHas 'no registered test is eligible for the nightly' "$rigTmp/a3.err" )" "0 0 0 1"

if [ "$rigFails" -ne 0 ] ; then
	printf '⛔ RUN NIGHTLY REGRESSIONS CHECK FAILED: %s of %s assertion(s)\n' "$rigFails" "$(( rigPasses + rigFails ))" >&2 ; exit 1
fi
printf 'RUN_NIGHTLY_REGRESSIONS: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
