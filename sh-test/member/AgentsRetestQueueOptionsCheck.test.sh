#!/usr/bin/env bash
## Behavioural check on the options F7.6 of the refactorings epic gave the retest queue (--retest-queue and --retest-drain,
## sh-lib/member/AgentsTools.MemberRetest.include), which stay the one queue of the machine (no second queue): --project, --wait and --no-wait.
## Run rather than read, on the machine of check-fixtures/rig-retest-machine.include.sh. The older behaviour of the queue is held by
## AgentsRetestQueueCheck. Held:
##   1. PRIORITY. A request is of the priority no-wait unless it is made with --wait, and the request says so; the last of the two flags counts.
##   2. PROJECT. --project queues the tests the testbed has registered for that project, with any test named beside it and each test once; a project
##      nothing is registered for is refused and queues nothing.
##   3. A WAITING CALL. A request made with --wait is the first the next drain takes, and takes alone: what waits without --wait is left for the one
##      after. The call stays until its request is run, then says how it came out and ends with rc 0 for a pass.
##   4. A FAILURE. A call with --wait whose test fails says FAIL and ends with rc 1.
## Offline, rig tree only: nothing here reaches Slack or any endpoint.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigPackage/sh-test/AgentsRunTests.sh" ] || rigRefuse "the test runner is not at the origin this workspace resolves: $rigPackage/sh-test/AgentsRunTests.sh"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRetestQueueOptionsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignal TERM $rigStarted ; rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
. "$rigPackage/sh-test/check-fixtures/rig-retest-machine.include.sh" || rigRefuse "the rig of the testing system is missing from the package: sh-test/check-fixtures/rig-retest-machine.include.sh"
rigMachineSetup
rigProject=myx/myx.distro-agents
rigAsk(){ ## result prefix, arguments of the queue operation... -- one request; its id in rigId, the rc in rigRc
	local askOut="$1" ; shift
	rigScript=DistroAgentsTools
	rigOp "$askOut" --retest-queue "$@"
	rigId="$( LC_ALL=C sed -n 1p "$askOut.out" )"
}
rigRegister(){ ## test... -- those tests registered in the testbed for the project
	local registerTest
	rigScript=DistroAgentsTesting
	for registerTest in "$@" ; do rigOp "$rigTmp/register-$registerTest" --test-register "$registerTest" --project "$rigProject" --script "sh-test/$registerTest.test.sh" ; done
	rigScript=DistroAgentsTools
}
rigWaitingTests(){ ## -- the request files that wait, by their test lines, one request a line
	local testsFile
	for testsFile in "$rigQueue/waiting"/*.request ; do
		[ -f "$testsFile" ] || continue
		LC_ALL=C sed -n 's/^test: //p' "$testsFile" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
		printf '\n'
	done
}
rigBegin=$( date +%s )

echo "-- 1. priority --"
rigFresh
rigAsk "$rigTmp/p1" --by rig-builder --why 'no flag' RigOne
rigAssert "a request without a flag is of the priority no-wait, and says so" "$rigRc $( rigField "$rigQueue/waiting/$rigId.request" priority )" "0 no-wait"
rigAsk "$rigTmp/p1b" --by rig-builder --why 'told so' --no-wait RigOne
rigAssert "--no-wait is the same" "$rigRc $( rigField "$rigQueue/waiting/$rigId.request" priority )" "0 no-wait"
rigAsk "$rigTmp/p1c" --by rig-builder --why 'last counts' --wait --no-wait RigOne
rigAssert "of the two flags the last counts" "$rigRc $( rigField "$rigQueue/waiting/$rigId.request" priority )" "0 no-wait"
rigAsk "$rigTmp/p1d" --by rig-builder --why 'unknown' --soon RigOne
rigAssert "an option it does not know is refused, and the syntax names the flags" "$rigRc $( LC_ALL=C grep -c -F -- '[--wait|--no-wait]' "$rigTmp/p1d.err" ) $( LC_ALL=C grep -c -F -- 'unknown option: --soon' "$rigTmp/p1d.err" )" "1 1 1"

echo "-- 2. project --"
rigFresh
rigAsk "$rigTmp/j2" --by rig-builder --why 'none registered' --project "$rigProject"
rigAssert "a project nothing is registered for is refused, saying where to register, and queues nothing" "$rigRc $( LC_ALL=C grep -c -F -- 'no test is registered for the project' "$rigTmp/j2.err" ) $( rigHolds waiting )" "1 1 0"
rigRegister RigOne RigTwo
rigAsk "$rigTmp/j2b" --by rig-builder --why 'the project' --project "$rigProject"
rigAssert "the tests registered for the project are queued, and only those (RigThree is not registered)" "$rigRc [$( rigWaitingTests )]" "0 [RigOne RigTwo]"
rm -f "$rigQueue"/waiting/*.request
rigAsk "$rigTmp/j2c" --by rig-builder --why 'the project and one beside' --project "$rigProject" RigThree RigOne
rigAssert "a test named beside it is queued too, each test once" "$rigRc [$( rigWaitingTests )]" "0 [RigOne RigThree RigTwo]"
rm -f "$rigQueue"/waiting/*.request
rigAsk "$rigTmp/j2d" --by rig-builder --why 'a project that is not' --project other/project
rigAssert "another project is another set of tests: none registered, refused" "$rigRc $( rigHolds waiting )" "1 0"

echo "-- 3. a waiting call --"
rigFresh
rigRegister RigOne RigTwo
rigAsk "$rigTmp/w3a" --by rig-first --why 'does not wait' RigOne ; rigIdA="$rigId"
rigCall "$rigTmp/w3b" --retest-queue --by rig-second --why 'waits for the batch' --wait RigTwo ; rigWaitPid="$rigLast"
rigUntil "retest-" "$rigTmp/w3b.out" || rigRefuse "the call with --wait did not say its request id"
rigIdB="$( LC_ALL=C sed -n 1p "$rigTmp/w3b.out" )"
rigAssert "the call with --wait has said its id and stays: its request waits with the priority wait" "$( rigField "$rigQueue/waiting/$rigIdB.request" priority ) $( kill -0 "$rigWaitPid" 2> /dev/null && printf staying ) $( rigHolds waiting )" "wait staying 2"
rigOp "$rigTmp/d3" --retest-drain
rigAssert "the first drain takes the request that is waited for, alone, and runs its test" "$rigRc [$( rigBegun )] $( rigHolds waiting ) $( [ -f "$rigQueue/waiting/$rigIdA.request" ] && printf other-waits )" "0 [live:RigTwo] 1 other-waits"
rigEnd "$rigWaitPid"
rigAssert "the call ends once it is run: rc 0, and it says how it came out" "$rigRc $( LC_ALL=C grep -c "^RETEST $rigIdB PASS -- asked by rig-second about live: 1 passed -- waits for the batch\$" "$rigTmp/w3b.out" )" "0 1"
rigOp "$rigTmp/d3b" --retest-drain
rigAssert "the next drain takes the one that did not wait" "$rigRc [$( rigBegun )] $( rigHolds waiting ) $( rigHolds done )" "0 [live:RigOne live:RigTwo] 0 2"

echo "-- 4. a failure --"
rigFresh
rigRegister RigOne
: > "$rigTmp/fail.RigOne"
rigScript=DistroAgentsTools ; rigCall "$rigTmp/w4" --retest-queue --by rig-third --why 'fails' --wait RigOne ; rigWaitPid="$rigLast"
rigUntil "retest-" "$rigTmp/w4.out" || rigRefuse "the call with --wait did not say its request id"
rigOp "$rigTmp/d4" --retest-drain
rigEnd "$rigWaitPid"
rigAssert "a test that fails: the call says FAIL, and ends with rc 1" "$rigRc $( LC_ALL=C grep -c '^RETEST retest-.* FAIL -- asked by rig-third about live: 0 passed, FAILED: RigOne -- fails$' "$rigTmp/w4.out" )" "1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RETEST QUEUE OPTIONS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RETEST_QUEUE_OPTIONS: OK (%d assertions, offline, rig tree only, %d seconds)\n' "$rigPasses" "$(( $( date +%s ) - rigBegin ))"
