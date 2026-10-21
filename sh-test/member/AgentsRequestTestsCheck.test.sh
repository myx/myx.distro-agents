#!/usr/bin/env bash
## Behavioural check on the member's tool for testing needs (F7.6 of the refactorings epic): AgentTestingTools.fn.sh --request-tests, the way any
## member communicates a testing need to the testing system and to magic-tester. Run rather than read, on the machine of
## check-fixtures/rig-retest-machine.include.sh: the one retest queue, a team data root with the inbox of magic-tester, and members of the rig.
## Held:
##   1. WHO. Only a member asks: a call from no member's session is refused, and queues and files nothing.
##   2. THE REQUEST. The tests go into the one retest queue as the request of the calling member, with the reason, and one inquiry into
##      magic-tester's inbox says who asked, what for, why and where the outcome is read; the id is the first line of the answer.
##   3. WHAT IT NAMES. A project, tests and changed files are all in the request and in the inquiry; a refused request (a test the copy does not hold,
##      no reason, --by, an option it does not know) queues nothing and asks nobody.
##   4. WAITING. With --wait the priority of the request is wait, the inquiry is filed before the batch has run (so the tester knows at once), the
##      call stays until the batch has run the request, and then says how it came out and ends with rc 0 for a pass.
##   5. SEVERAL. Two members asking give two requests and two inquiries; nothing goes to any other inbox.
## Offline, rig tree only: nothing here reaches Slack or any endpoint.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-scripts/AgentTestingTools.fn.sh" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigPackage/sh-scripts/AgentTestingTools.fn.sh"
[ -f "$rigPackage/sh-test/AgentsRunTests.sh" ] || rigRefuse "the test runner is not at the origin this workspace resolves: $rigPackage/sh-test/AgentsRunTests.sh"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRequestTestsCheck )" || exit 1
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
rigRequest(){ ## result prefix, arguments of --request-tests... -- one call as the member in rigAs; the id in rigId, the rc in rigRc
	local requestOut="$1" ; shift
	rigScript=AgentTestingTools
	rigOp "$requestOut" --request-tests "$@"
	rigScript=DistroAgentsTools
	rigId="$( LC_ALL=C sed -n 's/^\(retest-[0-9A-Za-z-]*\)$/\1/p' "$requestOut.out" | LC_ALL=C sed -n 1p )"
}
rigInquiry(){ ## -- the one inquiry in magic-tester's inbox (its path), or nothing where there is none or more than one
	local inquiryList ; inquiryList="$( ls "$rigData/inboxes/magic-tester/incoming" 2> /dev/null | LC_ALL=C grep '^inquiry-' )"
	[ "$( printf '%s' "$inquiryList" | LC_ALL=C grep -c . )" = 1 ] || return 0
	printf '%s\n' "$rigData/inboxes/magic-tester/incoming/$inquiryList"
}
rigElsewhere(){ ## -- how many inquiries stand in any other inbox
	ls "$rigData"/inboxes/rig-member/incoming "$rigData"/inboxes/rig-other/incoming 2> /dev/null | LC_ALL=C grep -c '^inquiry-' || :
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" || :
}
rigBegin=$( date +%s )

echo "-- 1. who --"
rigFresh
rigRequest "$rigTmp/h1" --why 'the console asks' RigOne
rigAssert "a call from no member is refused, and nothing is queued or filed" "$rigRc $( rigHas 'is raised by a member' "$rigTmp/h1.err" ) $( rigHolds waiting ) $( rigInbox magic-tester | LC_ALL=C grep -c . )" "1 1 0 0"

echo "-- 2. the request --"
rigFresh
rigAs=rig-member
rigRequest "$rigTmp/q2" --why 'changed the wait tool' RigOne
rigFile="$rigQueue/waiting/$rigId.request"
rigAssert "a member asks: rc 0, the id is the first line of the answer, and the request waits in the one queue of the machine" "$rigRc $( LC_ALL=C sed -n 1p "$rigTmp/q2.out" | LC_ALL=C grep -c -E '^retest-[0-9]{8}T[0-9]{6}Z-[0-9a-f-]+$' ) $( rigHolds waiting )" "0 1 1"
rigAssert "the request is the member's: who asks, why, the test, the priority no-wait" "$( rigField "$rigFile" by ) $( rigField "$rigFile" why ) $( rigField "$rigFile" test ) $( rigField "$rigFile" priority )" "rig-member changed the wait tool RigOne no-wait"
rigInquiryFile="$( rigInquiry )"
rigAssert "one inquiry stands in magic-tester's inbox, and in no other" "$( [ -n "$rigInquiryFile" ] && printf one ) $( rigElsewhere )" "one 0"
rigAssert "it is from the member to magic-tester, as the template says" "$( rigHas 'type: inquiry' "$rigInquiryFile" ) $( rigHas 'from: rig-member' "$rigInquiryFile" ) $( rigHas 'owner: magic-tester' "$rigInquiryFile" )" "1 1 1"
rigAssert "it names the request, the test, the priority and the reason, and where the outcome is read" "$( rigHas "request $rigId" "$rigInquiryFile" ) $( rigHas 'RigOne' "$rigInquiryFile" ) $( rigHas 'priority `no-wait`' "$rigInquiryFile" ) $( rigHas 'Why: changed the wait tool' "$rigInquiryFile" ) $( rigHas "--retest-result $rigId" "$rigInquiryFile" )" "1 1 1 1 1"
rigAssert "the name of the inquiry carries the stamp and the request" "$( ls "$rigData/inboxes/magic-tester/incoming" | LC_ALL=C grep -c -E "^inquiry-[0-9]{8}T[0-9]{4}Z-tests-wanted-${rigId##*-}\.md\$" )" "1"
rigScript=DistroAgentsTools
rigOp "$rigTmp/d2" --retest-drain
rigAssert "the batch runs the test it asked for" "$rigRc [$( rigBegun )]" "0 [live:RigOne]"

echo "-- 3. what it names --"
rigFresh
rigAs=rig-member
rigScript=DistroAgentsTesting ; rigOp "$rigTmp/g3" --test-register RigTwo --project "$rigProject" --script sh-test/RigTwo.test.sh ; rigScript=DistroAgentsTools
rigRequest "$rigTmp/n3" --why 'a project, a test and a file' --project "$rigProject" --file myx/myx.distro-agents/sh-lib/member/AgentsTools.Member.include RigOne
rigFile="$rigQueue/waiting/$rigId.request"
rigInquiryFile="$( rigInquiry )"
rigAssert "the project's tests and the test named are in the request, with the changed file" "$rigRc $( LC_ALL=C sed -n 's/^test: //p' "$rigFile" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )$( rigField "$rigFile" file )" "0 RigOne RigTwo sh-lib/member/AgentsTools.Member.include"
rigAssert "the inquiry names the project, the test and the changed file" "$( rigHas "the tests registered for the project $rigProject" "$rigInquiryFile" ) $( rigHas 'RigOne' "$rigInquiryFile" ) $( rigHas 'the changed files myx/myx.distro-agents/sh-lib/member/AgentsTools.Member.include' "$rigInquiryFile" )" "1 1 1"
rigFresh
rigAs=rig-member
rigRequest "$rigTmp/n3b" --why 'a test that is not there' RigNone
rigAssert "a test the copy does not hold is refused by the queue, and nobody is asked" "$rigRc $( rigHolds waiting ) $( rigInbox magic-tester | LC_ALL=C grep -c . )" "1 0 0"
rigRequest "$rigTmp/n3c" RigOne
rigAssert "a request without a reason is refused, and nobody is asked" "$rigRc $( rigHas 'syntax is --why <text>' "$rigTmp/n3c.err" ) $( rigHolds waiting ) $( rigInbox magic-tester | LC_ALL=C grep -c . )" "1 1 0 0"
rigRequest "$rigTmp/n3d" --why 'names someone else' --by rig-other RigOne
rigAssert "--by is refused: the request is the calling member's" "$rigRc $( rigHas '--by is not given' "$rigTmp/n3d.err" ) $( rigHolds waiting ) $( rigInbox magic-tester | LC_ALL=C grep -c . )" "1 1 0 0"
rigRequest "$rigTmp/n3e" --why 'unknown' --soon RigOne
rigAssert "an option it does not know is refused, and nobody is asked" "$rigRc $( rigHas 'unknown option: --soon' "$rigTmp/n3e.err" ) $( rigHolds waiting ) $( rigInbox magic-tester | LC_ALL=C grep -c . )" "1 1 0 0"
rigRequest "$rigTmp/n3f" --why
rigAssert "an option without its value is refused" "$rigRc $( rigHas '--why takes a value' "$rigTmp/n3f.err" )" "1 1"
rigScript=AgentTestingTools ; rigOp "$rigTmp/n3g" --request-nothing ; rigScript=DistroAgentsTools
rigAssert "an operation it does not have is an invalid option" "$rigRc $( rigHas 'invalid option: --request-nothing' "$rigTmp/n3g.err" )" "1 1"

echo "-- 4. waiting --"
rigFresh
rigAs=rig-member
rigScript=AgentTestingTools ; rigCall "$rigTmp/w4" --request-tests --why 'before handoff' --wait RigOne ; rigWaitPid="$rigLast" ; rigScript=DistroAgentsTools
rigUntil "retest-" "$rigTmp/w4.out" || rigRefuse "the call with --wait did not say its request id"
rigId="$( LC_ALL=C sed -n 1p "$rigTmp/w4.out" )"
rigWaited=0
while [ -z "$( rigInquiry )" ] && [ "$rigWaited" -lt 300 ] ; do sleep 0.2 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "with --wait the request has the priority wait, the call stays, and the inquiry is filed before the batch has run" "$( rigField "$rigQueue/waiting/$rigId.request" priority ) $( kill -0 "$rigWaitPid" 2> /dev/null && printf staying ) $( [ -n "$( rigInquiry )" ] && printf filed ) $( rigHolds done )" "wait staying filed 0"
rigAssert "the inquiry says the priority wait" "$( rigHas 'priority `wait`' "$( rigInquiry )" )" "1"
rigOp "$rigTmp/d4" --retest-drain
rigEnd "$rigWaitPid"
rigAssert "once the batch has run it the call ends, rc 0, and says how it came out" "$rigRc $( LC_ALL=C grep -c "^RETEST $rigId PASS -- asked by rig-member about live: 1 passed -- before handoff\$" "$rigTmp/w4.out" )" "0 1"

echo "-- 5. several --"
rigFresh
rigAs=rig-member
rigRequest "$rigTmp/s5a" --why 'one member' RigOne ; rigIdA="$rigId"
rigAs=rig-other
rigRequest "$rigTmp/s5b" --why 'the other member' RigTwo ; rigIdB="$rigId"
rigAssert "two members give two requests, each its own, and two inquiries in magic-tester's inbox, each from its member" "$( rigHolds waiting ) $( rigField "$rigQueue/waiting/$rigIdA.request" by ) $( rigField "$rigQueue/waiting/$rigIdB.request" by ) $( rigInbox magic-tester | LC_ALL=C grep -c . ) $( LC_ALL=C grep -l 'from: rig-member' "$rigData"/inboxes/magic-tester/incoming/inquiry-* | LC_ALL=C grep -c . ) $( LC_ALL=C grep -l 'from: rig-other' "$rigData"/inboxes/magic-tester/incoming/inquiry-* | LC_ALL=C grep -c . ) $( rigElsewhere )" "2 rig-member rig-other 2 1 1 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ REQUEST TESTS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'REQUEST_TESTS: OK (%d assertions, offline, rig tree only, %d seconds)\n' "$rigPasses" "$(( $( date +%s ) - rigBegin ))"
