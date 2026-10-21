#!/usr/bin/env bash
## Behavioural check on the testbed of the testing system (F7.6 of the refactorings epic): DistroAgentsTesting.fn.sh and the `--tester-*` stubs of
## DistroAgentsTools.fn.sh, over the project metadata of the tests (sh-lib/member/AgentsTools.Testbed.include), kept in .local/agents/testing/tests/.
## Run rather than read, on the machine of check-fixtures/rig-retest-machine.include.sh: a HOME with the one retest queue, a workspace whose tree is a
## copy of the tooling with three tiny tests in place of the package's. Held:
##   1. REGISTER. A test is registered with its project, script, functionality, keywords, rig, documents, resources and the nightly flag, and the file
##      says when; a test registered already, an id that is no id, a script that is not there, a missing project, a bad flag are refused, and leave nothing.
##   2. FROM A FOLDER. --from-folder registers every test of a folder by its file name, leaves one registered already as it is and says so, and takes
##      neither a test id nor a --script.
##   3. UPDATE. Only what is named changes, a list replaced whole, with the date of the update; an unknown test, nothing to change and a script that is
##      not there are refused.
##   4. UNREGISTER. The metadata goes and the test with its script stays; a second time is refused.
##   5. LIST. Rows with the stats of the test runner (passed on the state it would run on now, runs, passes, fails) and the last runs, by project,
##      namespace and keyword; the last row counts them. Nothing registered is no row but the count.
##   6. RUNNING. --run-oldest-untested puts the oldest registered test that has not passed into the one retest queue (no second queue), by the
##      acting member or the console user, with the priority no-wait, and nothing when every test has passed; --test-invalidate drops the pass record
##      so that the test is the oldest untested again; --run-all-nightly-regressions puts every test that is eligible for the nightly and nothing
##      when none is; --wait is the priority of the request, and the call stays until the batch has run it and says how it came out.
##      6b. Both runs are of the tests in a sh-test folder that a testing directive of a project.inf names (F13.5, the reader the grants use): with no directive,
##      one for another folder or one for another host nothing is put in the queue and each says so, and the directive adds the folder; a test registered
##      in a folder no directive names is registered, and says on stderr that it is not eligible for system runs.
##   7. STUBS. --tester-test-* and --tester-run-* of DistroAgentsTools.fn.sh give what the operations of DistroAgentsTesting.fn.sh give.
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
rigTmp="$( rigTempDir AgentsTestbedCheck )" || exit 1
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
rigDir="$rigWs/.local/agents/testing/tests"
rigKey(){ ## test id, key -- that key of a registered test's file
	rigField "$rigDir/$1.md" "$2"
}
rigTestCount(){ ## -- how many tests stand in the testbed
	ls "$rigDir" 2> /dev/null | LC_ALL=C grep -c '\.md$' || :
}
rigTesting(){ ## prefix, words... -- one call of DistroAgentsTesting.fn.sh
	local testingScript="$rigScript" ; rigScript=DistroAgentsTesting
	rigOp "$@"
	rigScript="$testingScript"
}
rigTools(){ ## prefix, words... -- one call of DistroAgentsTools.fn.sh
	local toolsScript="$rigScript" ; rigScript=DistroAgentsTools
	rigOp "$@"
	rigScript="$toolsScript"
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" || :
}
rigRow(){ ## list output, test id, column -- that column of the test's row: 3 project, 4 functionality, 5 keywords, 6 nightly, 7 passed, 8 invalidated-at, 9 runs, 10 passes, 11 fails
	LC_ALL=C awk -F'\t' -v id="$2" -v col="$3" '$1 == "test" && $2 == id { print $col ; exit }' "$1"
}
rigBegin=$( date +%s )

echo "-- 1. register --"
rigFresh
rigTesting "$rigTmp/r1" --test-register RigOne --project "$rigProject" --script sh-test/RigOne.test.sh --functionality queueing --keyword retest --keyword rig --nightly yes
rigAssert "a test is registered: rc 0, and it says so" "$rigRc $( cat "$rigTmp/r1.out" )" "0 registered: RigOne"
rigAssert "its file holds the project, script, functionality, keywords and flag as given" "$( rigKey RigOne project ) $( rigKey RigOne script ) $( rigKey RigOne functionality ) $( rigKey RigOne keywords ) $( rigKey RigOne nightly )" "$rigProject sh-test/RigOne.test.sh queueing retest,rig yes"
rigAssert "what is not given is a dash, and it was never invalidated" "$( rigKey RigOne rig ) $( rigKey RigOne documents ) $( rigKey RigOne resources ) $( rigKey RigOne invalidated-at )" "- - - -"
rigAssert "it says when it was registered, and that is when it was updated" "$( [ -n "$( rigKey RigOne registered-at )" ] && [ "$( rigKey RigOne registered-at )" = "$( rigKey RigOne updated-at )" ] && printf same )" "same"
rigTesting "$rigTmp/r1b" --test-register RigOne --project "$rigProject" --script sh-test/RigOne.test.sh
rigAssert "a test registered already is refused, saying how to change it" "$rigRc $( rigHas 'is registered already -- change it with --test-update' "$rigTmp/r1b.err" )" "1 1"
rigTesting "$rigTmp/r1c" --test-register 'Bad Id' --project "$rigProject" --script sh-test/RigOne.test.sh
rigAssert "an id that is no id is refused" "$rigRc $( rigHas 'not the id of a test' "$rigTmp/r1c.err" )" "1 1"
rigTesting "$rigTmp/r1d" --test-register RigTwo --project "$rigProject" --script sh-test/RigMissing.test.sh
rigAssert "a script that is not there is refused" "$rigRc $( rigHas 'no such script: sh-test/RigMissing.test.sh' "$rigTmp/r1d.err" )" "1 1"
rigTesting "$rigTmp/r1e" --test-register RigTwo --script sh-test/RigTwo.test.sh
rigAssert "a registration without a project is refused" "$rigRc $( rigHas '--project is needed' "$rigTmp/r1e.err" )" "1 1"
rigTesting "$rigTmp/r1f" --test-register RigTwo --project "$rigProject" --script sh-test/RigTwo.test.sh --nightly maybe
rigAssert "a flag that is neither yes nor no is refused" "$rigRc $( rigHas '--nightly is yes or no' "$rigTmp/r1f.err" )" "1 1"
rigTesting "$rigTmp/r1g" --test-register RigTwo --project "$rigProject" --script sh-test/RigTwo.test.sh --bogus x
rigAssert "an option it does not know is refused" "$rigRc $( rigHas 'unknown option: --bogus' "$rigTmp/r1g.err" )" "1 1"
rigAssert "the refused left nothing behind: one test is in the testbed" "$( rigTestCount )" "1"

echo "-- 2. from a folder --"
rigTesting "$rigTmp/f2" --test-register --from-folder source/myx/myx.distro-agents/sh-test --project "$rigProject"
rigAssert "every test of the folder is registered by its file name, the one registered already is left and said" "$rigRc $( rigHas 'skipped: RigOne is registered already' "$rigTmp/f2.out" ) $( rigHas ': 2 test(s) of ' "$rigTmp/f2.out" ) $( rigTestCount )" "0 1 1 3"
rigAssert "a test of the folder has the project, its file as the script (from the workspace) and the defaults" "$( rigKey RigThree project ) $( rigKey RigThree script ) $( rigKey RigThree nightly ) $( rigKey RigThree keywords )" "$rigProject source/myx/myx.distro-agents/sh-test/RigThree.test.sh no -"
rigTesting "$rigTmp/f2b" --test-register RigFour --from-folder source/myx/myx.distro-agents/sh-test --project "$rigProject"
rigAssert "a folder takes no test id" "$rigRc $( rigHas 'takes no test id' "$rigTmp/f2b.err" )" "1 1"
rigTesting "$rigTmp/f2c" --test-register --from-folder source/myx/myx.distro-agents/sh-none --project "$rigProject"
rigAssert "a folder that is not there is refused" "$rigRc $( rigHas 'no such folder' "$rigTmp/f2c.err" )" "1 1"

echo "-- 3. update --"
rigWas="$( rigKey RigTwo registered-at )"
rigTesting "$rigTmp/u3" --test-update RigTwo --keyword a --keyword b --nightly yes
rigAssert "only what is named changes: keywords and flag, and it says so" "$rigRc $( cat "$rigTmp/u3.out" ) $( rigKey RigTwo keywords ) $( rigKey RigTwo nightly ) $( rigKey RigTwo project ) $( rigKey RigTwo functionality )" "0 updated: RigTwo a,b yes $rigProject -"
rigAssert "the date of registration stays" "$( rigKey RigTwo registered-at )" "$rigWas"
rigTesting "$rigTmp/u3b" --test-update RigTwo --keyword c
rigAssert "a list given again is replaced whole, and the flag stays" "$rigRc $( rigKey RigTwo keywords ) $( rigKey RigTwo nightly )" "0 c yes"
rigTesting "$rigTmp/u3c" --test-update RigNone --nightly no
rigAssert "a test that is not registered is refused" "$rigRc $( rigHas 'RigNone is not registered' "$rigTmp/u3c.err" )" "1 1"
rigTesting "$rigTmp/u3d" --test-update RigTwo
rigAssert "nothing to change is refused" "$rigRc $( rigHas 'nothing to change is given' "$rigTmp/u3d.err" )" "1 1"
rigTesting "$rigTmp/u3e" --test-update RigTwo --script sh-test/RigMissing.test.sh
rigAssert "a script that is not there is refused, and the test is as it was" "$rigRc $( rigHas 'no such script' "$rigTmp/u3e.err" ) $( rigKey RigTwo script )" "1 1 source/myx/myx.distro-agents/sh-test/RigTwo.test.sh"

echo "-- 4. unregister --"
rigTesting "$rigTmp/n4" --test-unregister RigThree
rigAssert "the metadata goes, and the test and its script stay" "$rigRc $( cat "$rigTmp/n4.out" ) $( [ -f "$rigDir/RigThree.md" ] && printf metadata || printf gone ) $( [ -f "$rigLive/myx/myx.distro-agents/sh-test/RigThree.test.sh" ] && printf script-stays )" "0 unregistered: RigThree gone script-stays"
rigTesting "$rigTmp/n4b" --test-unregister RigThree
rigAssert "a second time is refused" "$rigRc $( rigHas 'RigThree is not registered' "$rigTmp/n4b.err" )" "1 1"

echo "-- 5. list --"
rigTesting "$rigTmp/l5" --test-list
rigAssert "the registered tests, none passed, no run yet, and the count" "$rigRc [$( LC_ALL=C tr '\t' '|' < "$rigTmp/l5.out" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )]" "0 [test|RigOne|$rigProject|queueing|retest,rig|yes|-|-|0|0|0 test|RigTwo|$rigProject|-|c|yes|-|-|0|0|0 tests|2|0|2]"
rigTesting "$rigTmp/l5b" --test-list --project "$rigProject"
rigAssert "by project: both" "$( LC_ALL=C grep -c '^test	' "$rigTmp/l5b.out" )" "2"
rigTesting "$rigTmp/l5c" --test-list --project other/project
rigAssert "by a project nothing is registered for: no test, and the count" "$( LC_ALL=C grep -c '^test	' "$rigTmp/l5c.out" ) $( LC_ALL=C tail -n 1 "$rigTmp/l5c.out" | LC_ALL=C tr '\t' '|' )" "0 tests|0|0|0"
rigTesting "$rigTmp/l5d" --test-list --namespace myx
rigTesting "$rigTmp/l5e" --test-list --namespace other
rigAssert "by namespace, the first word of the project" "$( LC_ALL=C grep -c '^test	' "$rigTmp/l5d.out" ) $( LC_ALL=C grep -c '^test	' "$rigTmp/l5e.out" )" "2 0"
rigTesting "$rigTmp/l5f" --test-list --keyword retest
rigAssert "by keyword, the one that has it" "$( LC_ALL=C sed -n 's/^test	\([^	]*\)	.*/\1/p' "$rigTmp/l5f.out" | LC_ALL=C tr '\n' ' ' )" "RigOne "
rigTesting "$rigTmp/l5g" --test-list --bogus x
rigAssert "an option it does not know is refused" "$rigRc" "1"

echo "-- 6. running --"
rigTesting "$rigTmp/o6" --run-oldest-untested
rigIdA="$( LC_ALL=C sed -n 1p "$rigTmp/o6.out" )"
rigFile="$rigQueue/waiting/$rigIdA.request"
rigAssert "the oldest untested test is put in the one retest queue of the machine: rc 0, one line, its id" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/o6.out" ) $( printf '%s' "$rigIdA" | LC_ALL=C grep -c -E '^retest-[0-9]{8}T[0-9]{6}Z-[0-9a-f-]+$' ) $( rigHolds waiting )" "0 1 1 1"
rigAssert "it is RigOne, registered first, asked by the console user, with the priority no-wait, and says why" "$( rigField "$rigFile" test ) $( rigField "$rigFile" by ) $( rigField "$rigFile" priority ) $( rigField "$rigFile" why )" "RigOne user-console no-wait the oldest untested test of the testbed"
rigTools "$rigTmp/d6" --retest-drain
rigAssert "the batch runs it, once" "$rigRc [$( rigBegun )]" "0 [live:RigOne]"
rigTesting "$rigTmp/l6" --test-list
rigAssert "the list now says RigOne passed on this state (a date, not a dash), one run, one pass, no fail, and shows the run; the other has not" "$( [ "$( rigRow "$rigTmp/l6.out" RigOne 7 )" != - ] && printf passed ) $( rigRow "$rigTmp/l6.out" RigOne 9 ) $( rigRow "$rigTmp/l6.out" RigOne 10 ) $( rigRow "$rigTmp/l6.out" RigOne 11 ) $( LC_ALL=C awk -F'\t' '$1 == "run" && $2 == "RigOne" && $4 == "PASS" { n++ } END { print n + 0 }' "$rigTmp/l6.out" ) $( rigRow "$rigTmp/l6.out" RigTwo 7 ) $( LC_ALL=C tail -n 1 "$rigTmp/l6.out" | LC_ALL=C tr '\t' '|' )" "passed 1 1 0 1 - tests|2|1|1"
rigTesting "$rigTmp/o6b" --run-oldest-untested
rigIdB="$( LC_ALL=C sed -n 1p "$rigTmp/o6b.out" )"
rigAssert "the next oldest untested is the other: RigOne has passed" "$rigRc $( rigField "$rigQueue/waiting/$rigIdB.request" test )" "0 RigTwo"
rigTools "$rigTmp/d6b" --retest-drain
rigTesting "$rigTmp/o6c" --run-oldest-untested
rigAssert "with every test passed, nothing is put in the queue, and it says so" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/o6c.out" ) $( rigHolds waiting ) $( rigHas 'every registered test has passed' "$rigTmp/o6c.err" )" "0 0 0 1"
rigTesting "$rigTmp/v6" --test-invalidate RigOne
rigTesting "$rigTmp/l6b" --test-list
rigAssert "an invalidation drops the pass record: RigOne is not passed any more and says when it was invalidated, RigTwo is still passed" "$rigRc $( cat "$rigTmp/v6.out" ) $( rigRow "$rigTmp/l6b.out" RigOne 7 ) $( [ "$( rigRow "$rigTmp/l6b.out" RigOne 8 )" != - ] && printf dated ) $( LC_ALL=C tail -n 1 "$rigTmp/l6b.out" | LC_ALL=C tr '\t' '|' )" "0 invalidated: RigOne - dated tests|2|1|1"
rigTesting "$rigTmp/o6d" --run-oldest-untested
rigIdC="$( LC_ALL=C sed -n 1p "$rigTmp/o6d.out" )"
rigAssert "so the invalidated test is the oldest untested again" "$( rigField "$rigQueue/waiting/$rigIdC.request" test )" "RigOne"
rigTools "$rigTmp/d6c" --retest-drain
rigTesting "$rigTmp/v6b" --test-invalidate RigNone
rigAssert "a test that is not registered cannot be invalidated" "$rigRc $( rigHas 'RigNone is not registered' "$rigTmp/v6b.err" )" "1 1"
rigAs=magic-tester
rigTesting "$rigTmp/a6" --run-all-nightly-regressions
rigIdD="$( LC_ALL=C sed -n 1p "$rigTmp/a6.out" )"
rigFile="$rigQueue/waiting/$rigIdD.request"
rigAssert "the nightly regressions are every test that is eligible: both, asked by the acting member, with the reason" "$rigRc $( LC_ALL=C sed -n 's/^test: //p' "$rigFile" | LC_ALL=C tr '\n' ' ' )$( rigField "$rigFile" by ) $( rigField "$rigFile" why )" "0 RigOne RigTwo magic-tester the nightly regressions of the testbed"
rigAs=""
rigTools "$rigTmp/d6d" --retest-drain
rigTesting "$rigTmp/u6" --test-update RigTwo --nightly no
rigTesting "$rigTmp/a6b" --run-all-nightly-regressions
rigIdE="$( LC_ALL=C sed -n 1p "$rigTmp/a6b.out" )"
rigAssert "a test whose flag is no is not in them" "$( LC_ALL=C sed -n 's/^test: //p' "$rigQueue/waiting/$rigIdE.request" | LC_ALL=C tr '\n' ' ' )" "RigOne "
rigTools "$rigTmp/d6e" --retest-drain
rigTesting "$rigTmp/u6b" --test-update RigOne --nightly no
rigTesting "$rigTmp/a6c" --run-all-nightly-regressions
rigAssert "with none eligible, nothing is put in the queue, and it says so" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/a6c.out" ) $( rigHolds waiting ) $( rigHas 'no registered test is eligible for the nightly' "$rigTmp/a6c.err" )" "0 0 0 1"
rigTesting "$rigTmp/u6c" --test-update RigOne --nightly yes
rigTesting "$rigTmp/v6c" --test-invalidate RigOne
rigScript=DistroAgentsTesting ; rigCall "$rigTmp/w6" --run-all-nightly-regressions --wait ; rigWaitPid="$rigLast" ; rigScript=DistroAgentsTools
rigUntil "retest-" "$rigTmp/w6.out" || rigRefuse "the call with --wait did not say its request id"
rigWaitFile="$( rigWaitingFile )"
rigAssert "with --wait the priority of the request is wait, and the call has not ended" "$( rigField "$rigWaitFile" priority ) $( kill -0 "$rigWaitPid" 2> /dev/null && printf staying )" "wait staying"
rigTools "$rigTmp/d6f" --retest-drain
rigEnd "$rigWaitPid"
rigAssert "once the batch has run the test the call ends, rc 0, and says how it came out" "$rigRc $( rigHas 'RETEST retest-' "$rigTmp/w6.out" ) $( rigHas ' PASS -- asked by user-console about live: 1 passed' "$rigTmp/w6.out" )" "0 1 1"

echo "-- 6b. eligible folders: the testing directive of the package's project.inf --"
rigDirective off
rigTesting "$rigTmp/e1" --run-all-nightly-regressions
rigTesting "$rigTmp/e1b" --run-oldest-untested
rigAssert "with no directive naming a folder no test is eligible: neither run puts anything in the queue, and each says so" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/e1.out" ) $( LC_ALL=C grep -c . "$rigTmp/e1b.out" ) $( rigHolds waiting ) $( rigHas 'no registered test is in a sh-test folder that a testing directive names' "$rigTmp/e1.err" ) $( rigHas 'no registered test is in a sh-test folder that a testing directive names' "$rigTmp/e1b.err" )" "0 0 0 0 1 1"
rigTesting "$rigTmp/e1c" --test-register RigNine --project "$rigProject" --script sh-test/RigThree.test.sh
rigAssert "a test whose folder no directive names is registered all the same, and it says it is not eligible for system runs" "$rigRc $( cat "$rigTmp/e1c.out" ) $( rigHas 'registered; not eligible for system runs: no testing directive names source/myx/myx.distro-agents/sh-test' "$rigTmp/e1c.err" ) $( [ -f "$rigDir/RigNine.md" ] && printf stands )" "0 registered: RigNine 1 stands"
rigTesting "$rigTmp/e1d" --test-unregister RigNine
rigDirective sh-other
rigTesting "$rigTmp/e2" --run-all-nightly-regressions
rigAssert "a directive that names another folder gives the tests of this one nothing" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/e2.out" ) $( rigHolds waiting )" "0 0 0"
rigDirective sh-test rig-no-such-host
rigTesting "$rigTmp/e3" --run-all-nightly-regressions
rigAssert "a directive for another host gives nothing" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/e3.out" ) $( rigHolds waiting )" "0 0 0"
rigDirective sh-test
rigTesting "$rigTmp/e4" --run-all-nightly-regressions
rigIdF="$( LC_ALL=C sed -n 1p "$rigTmp/e4.out" )"
rigAssert "the directive adds the folder: the nightly is the test flagged yes that stands in it" "$rigRc $( LC_ALL=C sed -n 's/^test: //p' "$rigQueue/waiting/$rigIdF.request" | LC_ALL=C tr '\n' ' ' )" "0 RigOne "
rigTools "$rigTmp/d6g" --retest-drain
rigTesting "$rigTmp/v6d" --test-invalidate RigTwo
rigTesting "$rigTmp/e5" --run-oldest-untested
rigIdG="$( LC_ALL=C sed -n 1p "$rigTmp/e5.out" )"
rigAssert "and the oldest untested is again one of it: RigTwo" "$rigRc $( rigField "$rigQueue/waiting/$rigIdG.request" test )" "0 RigTwo"
rigTools "$rigTmp/d6h" --retest-drain
rigAssert "one reader of the verb: only the grants' include cuts magic-team:testing out of the declares, and the testbed calls it" "$( LC_ALL=C grep -rl -F "filter-and-cut 'magic-team:testing'" "$rigPackage/sh-lib" | LC_ALL=C sed 's#.*/##' | LC_ALL=C tr '\n' ' ' )$( LC_ALL=C grep -c 'AgentsToolsTestingFolders' "$rigPackage/sh-lib/member/AgentsTools.Testbed.include" | LC_ALL=C awk '$1 > 0 { print "called" }' )" "AgentsTools.Grants.include called"

echo "-- nothing registered --"
rigFresh
rigTesting "$rigTmp/z1" --run-oldest-untested
rigTesting "$rigTmp/z2" --run-all-nightly-regressions
rigTesting "$rigTmp/z3" --test-list
rigAssert "with nothing registered neither run is possible, and the list is only its count" "$rigRc $( rigHas 'no test is registered in the testbed' "$rigTmp/z1.err" ) $( rigHas 'no test is registered in the testbed' "$rigTmp/z2.err" ) $( LC_ALL=C tr '\t' '|' < "$rigTmp/z3.out" )" "0 1 1 tests|0|0|0"

echo "-- 7. the stubs --"
rigFresh
rigTools "$rigTmp/s1" --tester-test-register RigOne --project "$rigProject" --script sh-test/RigOne.test.sh --keyword stub
rigAssert "--tester-test-register registers as --test-register does" "$rigRc $( cat "$rigTmp/s1.out" ) $( rigKey RigOne keywords )" "0 registered: RigOne stub"
rigTools "$rigTmp/s2" --tester-test-update RigOne --nightly yes
rigTools "$rigTmp/s3" --tester-test-list
rigTesting "$rigTmp/s3b" --test-list
rigAssert "--tester-test-update changes it, and --tester-test-list lists what --test-list lists" "$rigRc $( rigKey RigOne nightly ) $( cmp -s "$rigTmp/s3.out" "$rigTmp/s3b.out" && printf same )" "0 yes same"
rigTools "$rigTmp/s4" --tester-run-oldest-untested
rigAssert "--tester-run-oldest-untested puts the test in the queue" "$rigRc $( rigField "$rigQueue/waiting/$( LC_ALL=C sed -n 1p "$rigTmp/s4.out" ).request" test )" "0 RigOne"
rigTools "$rigTmp/s5" --tester-run-all-nightly-regressions
rigAssert "--tester-run-all-nightly-regressions puts the eligible tests in it" "$rigRc $( rigHolds waiting )" "0 2"
rigTools "$rigTmp/s6" --tester-test-invalidate RigOne
rigTools "$rigTmp/s7" --tester-test-unregister RigOne
rigAssert "--tester-test-invalidate and --tester-test-unregister do as theirs" "$rigRc $( cat "$rigTmp/s6.out" ) $( cat "$rigTmp/s7.out" ) $( rigTestCount )" "0 invalidated: RigOne unregistered: RigOne 0"
rigTools "$rigTmp/s8" --tester-test-bogus
rigAssert "a --tester- word of an operation that does not exist is refused as an invalid option" "$rigRc $( rigHas 'invalid option' "$rigTmp/s8.err" )" "1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ TESTBED CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'TESTBED: OK (%d assertions, offline, rig tree only, %d seconds)\n' "$rigPasses" "$(( $( date +%s ) - rigBegin ))"
