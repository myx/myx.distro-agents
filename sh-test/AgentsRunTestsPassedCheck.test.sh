#!/usr/bin/env bash
## Behavioural check on the passes the test runner keeps by content (sh-test/AgentsRunTests.sh), run rather than read,
## on a fixture machine built here: a HOME, whose .agents/magic-team/suite-results is the machine's one record, a
## workspace, and several copies of a small package, each with the runner under test, two tiny tests, a fixture, a
## library file, and beside it a package of the tooling and one that is none of the tooling's; myx.common is a copy
## made here, so that nothing done to the machine's own while this check runs moves the state under it. Held: a test
## that passes goes on record under the content it passed on, and `--passed` says so, running nothing; a run reads none
## of it and runs what it is told; a change to a library file, to the test, to a fixture, to the runner, to another
## package of the tooling, to myx.common, to the member set the environment hands the tests, and to whether a file may
## be run, each leaves the test with no pass on the new state, while the same content with a newer date keeps it and
## the earlier content brings the earlier pass back; a failure is never kept; the same content in another folder shares
## the pass; a pass on a tree that moved while the test ran is kept for no state, and the receipt says so; a pass older
## than seven days is no pass, and every run removes those; and where the record cannot be written tests run as ever.
## Nothing here is told by how long a run takes: a test that must still be running when the tree is changed runs until
## the rig lets it end.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigRunner="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its tests with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsPassedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignal TERM $rigStarted ; rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home" ; rigWs="$rigTmp/ws" ; rigMembers="$rigTmp/members" ; rigCommon="$rigTmp/myx.common"
rigRecord="$rigHome/.agents/magic-team/suite-results"
mkdir -p "$rigHome" "$rigWs/.local/temp" "$rigMembers/rig-member" "$rigCommon"
tar -C "${MYXROOT:-/usr/local/share/myx.common}" --exclude .git -chf - . 2> /dev/null | tar -C "$rigCommon" -xf - 2> /dev/null
[ -f "$rigCommon/bin/lib/parallel.Common" ] || rigRefuse "myx.common could not be copied into the rig"
printf 'rig member\n' > "$rigMembers/rig-member/rig-member.basic.md"
: > "$rigTmp/log"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## ---- the fixture ----
rigRoot(){ ## session -- the source root of that session's copy; `live` is the workspace's own tree, no scratch folder
	if [ "$1" = live ] ; then printf '%s\n' "$rigWs/source" ; else printf '%s\n' "$rigWs/.local/temp/rig-scratch-$1/source" ; fi
}
rigPkg(){ ## session -- that copy of the package
	printf '%s\n' "$( rigRoot "$1" )/myx/myx.distro-agents"
}
rigPackage(){ ## session -- that copy: the runner under test, two tiny tests, a fixture, a library file and project.inf, beside it a package of the tooling and one that is none of its. A tiny test says in the shared log when it begins and ends; it ends only once the rig lets it where the rig holds it (hold.<test>), and fails where the rig says so (fail.<test>)
	local packageDir packageTest ; packageDir="$( rigPkg "$1" )"
	mkdir -p "$packageDir/sh-test/check-fixtures" "$packageDir/sh-lib" "$( rigRoot "$1" )/myx/myx.distro-system/sh-lib" "$( rigRoot "$1" )/myx/rig-other"
	cp "$rigRunner" "$packageDir/sh-test/AgentsRunTests.sh"
	mkdir -p "$packageDir/sh-test/check-fixtures" && cp "$(dirname "$rigRunner")/check-fixtures"/runner-*.py "$packageDir/sh-test/check-fixtures"/
	for packageTest in RigOne RigTwo ; do
		cat > "$packageDir/sh-test/$packageTest.test.sh" <<'RIGTINY'
#!/usr/bin/env bash
rigTinyName="${0##*/}" ; rigTinyName="${rigTinyName%.test.sh}"
printf 'BEGIN %s %s\n' "$RIG_SUITE" "$rigTinyName" >> "$RIG_SHARED/log"
rigHeldFor=600
while [ -e "$RIG_SHARED/hold.$rigTinyName" ] && [ ! -e "$RIG_SHARED/let.$rigTinyName" ] && [ "$rigHeldFor" -gt 0 ] ; do sleep 0.2 ; rigHeldFor=$(( rigHeldFor - 1 )) ; done
printf 'END %s %s\n' "$RIG_SUITE" "$rigTinyName" >> "$RIG_SHARED/log"
[ ! -e "$RIG_SHARED/fail.$rigTinyName" ] || { echo "RIG_TINY: FAILED" ; exit 1 ; }
echo "RIG_TINY: OK"
RIGTINY
	done
	printf 'a fixture\n' > "$packageDir/sh-test/check-fixtures/rig.txt"
	printf '## a library file\n' > "$packageDir/sh-lib/RigLib.include"
	printf 'Name: rig\n' > "$packageDir/project.inf"
	printf '## a file of another package of the tooling\n' > "$( rigRoot "$1" )/myx/myx.distro-system/sh-lib/RigSystem.include"
	printf 'a file of a package that is none of the tooling\n' > "$( rigRoot "$1" )/myx/rig-other/note.txt"
}
for rigSession in a b c live ; do rigPackage "$rigSession" ; done
printf '## one more line in this copy alone\n' >> "$( rigPkg c )/sh-lib/RigLib.include"

rigRun(){ ## session, runner args... -- that session's runner, started in the background from its own copy; its output in <session>.out
	( cd "$rigWs" && exec env -i HOME="${rigHomeFor:-$rigHome}" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$( rigRoot "$1" )" MYXROOT="$rigCommon" MDAT_SKILLSET_ROOT="$rigMembers" RIG_SHARED="$rigTmp" RIG_SUITE="$1" \
		bash "$( rigPkg "$1" )/sh-test/AgentsRunTests.sh" "${@:2}" ) > "$rigTmp/$1.out" 2>&1 &
	rigLast=$!
	rigStarted="$rigStarted $rigLast" ; rigProcNote "$rigLast"
}
rigEnd(){ ## pid -- waits for that runner, its rc in rigRc
	rigRc=0 ; wait "$1" 2> /dev/null || rigRc=$?
}
rigDo(){ ## session, runner args... -- that runner from start to end, its rc in rigRc
	rigRun "$@" ; rigEnd "$rigLast"
}
rigUntil(){ ## fixed text, file -- waits for a line of the file to hold the text, however long a busy host takes, up to four minutes; rc 1 when it never does
	local untilLeft=1200
	while ! LC_ALL=C grep -q -F -- "$1" "$2" 2> /dev/null ; do
		[ "$untilLeft" -gt 0 ] || return 1
		sleep 0.2 ; untilLeft=$(( untilLeft - 1 ))
	done
}
rigBegins(){ ## test, session (default: any) -- how many times that test has really begun, by the shared log
	LC_ALL=C grep -c -E "^BEGIN ${2:-[a-z]+} $1\$" "$rigTmp/log" || :
}
rigPassed(){ ## session, test -- what the runner's --passed says of that test: `passed`, or `-`
	rigDo "$1" --passed "$2"
	LC_ALL=C sed -n -e "s/^$2 -\$/-/p" -e "s/^$2 [0-9][0-9TZ:-]*\$/passed/p" "$rigTmp/$1.out" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigRecords(){ ## test (default: every test) -- how many passes the record holds
	find "$rigRecord${1:+/$1}" -type f 2> /dev/null | LC_ALL=C grep -c . || :
}
rigFresh(){ ## -- an empty record and an empty log, nothing held, nothing failing
	rm -rf "$rigRecord" ; : > "$rigTmp/log" ; rm -f "$rigTmp"/*.out "$rigTmp"/hold.* "$rigTmp"/let.* "$rigTmp"/fail.*
}
rigAgain(){ ## what was changed -- after a change to copy a: RigOne has no pass on the new state, passes when it is run, and has one then
	local againBefore againBegins ; againBefore="$( rigPassed a RigOne )" ; againBegins="$( rigBegins RigOne )"
	rigDo a RigOne
	rigAssert "$1: the test has no pass on the new state, is run, and has one then" "$againBefore $rigRc $(( $( rigBegins RigOne ) - againBegins )) $( rigPassed a RigOne )" "- 0 1 passed"
}

echo "-- 1. a test that passes goes on record under the content it passed on --"
rigFresh
rigDo a --passed
rigAssert "with nothing on record, --passed names every test of the copy and no pass, and runs nothing" "$rigRc [$( LC_ALL=C tr '\n' ' ' < "$rigTmp/a.out" | LC_ALL=C sed 's/ $//' )] $( LC_ALL=C grep -c . "$rigTmp/log" || : )" "0 [RigOne - RigTwo -] 0"
rigAssert "asked what has passed, it stands in no line, takes no slot, makes no run folder and writes no record" "$( ls "$rigHome/.agents/magic-team" 2> /dev/null | LC_ALL=C grep -c . || : ) $( [ -e "$rigWs/.local/temp/mdat-tests" ] && printf folder || printf none ) $( [ -e "$rigWs/.local/temp/suite-run.lock" ] && printf lock || printf none )" "0 none none"
rigDo a RigOne
rigAssert "the test is run and passes, as ever" "$rigRc $( LC_ALL=C grep -c '^PASS  RigOne ' "$rigTmp/a.out" || : ) $( rigBegins RigOne )" "0 1 1"
rigAssert "its pass is on record, and the test that was not run has none" "$( rigPassed a RigOne ) $( rigPassed a RigTwo ) $( rigRecords RigOne ) $( rigRecords )" "passed - 1 1"
rigDo a --passed RigOne
rigAssert "--passed says when: the time the record holds" "$( LC_ALL=C sed -n 's/^RigOne //p' "$rigTmp/a.out" )" "$( LC_ALL=C sed -n 's/^passed=//p' "$rigRecord/RigOne"/* 2> /dev/null )"
rigAssert "the record is the machine's, in the team's own directory under HOME, and in no copy of the package" "$( [ -d "$rigRecord/RigOne" ] && printf there || printf missing ) $( find "$rigWs" -name 'suite-results' 2> /dev/null | LC_ALL=C grep -c . || : )" "there 0"
rigAssert "the receipt of the run names the key the pass was kept under" "$( LC_ALL=C sed -n 's/^kept=//p' "$rigWs/.local/temp/mdat-tests/latest/RigOne.receipt" 2> /dev/null )" "$( ls "$rigRecord/RigOne" 2> /dev/null )"
rigDo a RigOne
rigAssert "a run reads none of it: told to run a test that has passed on this very state, it runs it" "$rigRc $( LC_ALL=C grep -c '^PASS  RigOne ' "$rigTmp/a.out" || : ) $( rigBegins RigOne )" "0 1 2"

echo "-- 2. a change to anything the test can read leaves it with no pass on the new state --"
printf '## changed\n' >> "$( rigPkg a )/sh-lib/RigLib.include" ; rigAgain "a library file"
printf '## changed\n' >> "$( rigPkg a )/sh-test/RigOne.test.sh" ; rigAgain "the test itself"
printf 'changed\n' >> "$( rigPkg a )/sh-test/check-fixtures/rig.txt" ; rigAgain "a fixture"
printf '## rig: a changed runner\n' >> "$( rigPkg a )/sh-test/AgentsRunTests.sh" ; rigAgain "the runner"
printf '## changed\n' >> "$( rigRoot a )/myx/myx.distro-system/sh-lib/RigSystem.include" ; rigAgain "a file of another package of the tooling"
printf 'changed\n' > "$rigCommon/help/rig-note.md" ; rigAgain "a file of myx.common as it is installed"
printf 'changed\n' >> "$rigMembers/rig-member/rig-member.basic.md" ; rigAgain "a file of the member set the environment hands the tests"
printf 'Name: rig\n' > "$( rigPkg a )/sh-lib/RigNew.include" ; rigAgain "a file added to the package"
chmod +x "$( rigPkg a )/sh-lib/RigNew.include" ; rigAgain "a file that may now be run"
rigKept="$( rigRecords RigOne )"
touch "$( rigPkg a )/sh-lib/RigLib.include" "$( rigPkg a )/sh-test/RigOne.test.sh"
rigAssert "control: the same content with a newer date is the same state, and the pass stands" "$( rigPassed a RigOne )" "passed"
printf 'changed\n' >> "$( rigRoot a )/myx/rig-other/note.txt" ; printf 'new\n' > "$rigWs/.local/temp/rig-note.txt"
rigAssert "control: a package that is none of the tooling, and the workspace's own files, are no part of the state" "$( rigPassed a RigOne )" "passed"
rm -f "$( rigPkg a )/sh-lib/RigNew.include"
rigAssert "the earlier content brings the earlier pass back: taking the added file away is the state before it, with nothing run" "$( rigPassed a RigOne ) $( rigRecords RigOne )" "passed $rigKept"

echo "-- 3. a failure is never kept --"
rigFresh
: > "$rigTmp/fail.RigOne"
rigDo a RigOne
rigAssert "a test that fails is no pass: rc 1, nothing on record" "$rigRc $( LC_ALL=C grep -c '^FAIL  RigOne ' "$rigTmp/a.out" || : ) $( rigRecords ) $( rigPassed a RigOne )" "1 1 0 -"
rigDo a RigOne RigTwo
rigAssert "run with one that passes, the one that passes is kept and the failing one is not" "$rigRc $( rigPassed a RigOne ) $( rigPassed a RigTwo )" "1 - passed"
rm -f "$rigTmp/fail.RigOne"
rigDo a RigOne
rigAssert "accepted sibling: the same test on the same state, once it passes, is kept" "$rigRc $( rigPassed a RigOne )" "0 passed"

echo "-- 4. the same content in another folder shares the pass --"
rigFresh
for rigSession in a b live ; do rm -rf "$( rigRoot "$rigSession" )" ; rigPackage "$rigSession" ; done
rigDo a RigOne
rigAssert "a pass earned in one scratch copy is a pass in a copy that is byte for byte the same, which never ran it" "$rigRc $( rigPassed b RigOne ) $( rigBegins RigOne b )" "0 passed 0"
rigAssert "and in the workspace's own tree, where that is the same content" "$( rigPassed live RigOne ) $( rigBegins RigOne live )" "passed 0"
rigAssert "control: a copy that differs in one line of a library file has no pass" "$( rigPassed c RigOne )" "-"

echo "-- 5. a pass on a tree that moved while the test ran is kept for no state --"
rigFresh
: > "$rigTmp/hold.RigOne"
rigRun a RigOne ; rigPidA=$rigLast
rigUntil 'BEGIN a RigOne' "$rigTmp/log" || rigRefuse "the held test never began, so nothing below would be measured"
cp "$( rigPkg a )/sh-lib/RigLib.include" "$rigTmp/RigLib.before"
printf '## changed while the test ran\n' >> "$( rigPkg a )/sh-lib/RigLib.include"
: > "$rigTmp/let.RigOne" ; rigEnd "$rigPidA"
rigAssert "the test passes, and no pass is kept: neither for the state it ended on" "$rigRc $( LC_ALL=C grep -c '^PASS  RigOne ' "$rigTmp/a.out" || : ) $( rigRecords ) $( rigPassed a RigOne )" "0 1 0 -"
rigAssert "and the receipt of the run says why" "$( LC_ALL=C grep -c '^not-kept=the state it ran on changed while it ran: from [0-9a-f]* to [0-9a-f]*$' "$rigWs/.local/temp/mdat-tests/latest/RigOne.receipt" 2> /dev/null )" "1"
cp "$rigTmp/RigLib.before" "$( rigPkg a )/sh-lib/RigLib.include"
rigAssert "nor for the state it started on" "$( rigPassed a RigOne )" "-"
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*
rigDo a RigOne
rigAssert "accepted sibling: run again on a tree that stays as it is, it is kept" "$rigRc $( rigPassed a RigOne )" "0 passed"

echo "-- 6. a pass is believed for seven days, and every run removes the older ones --"
rigFresh
rigDo a RigOne
rigOld="$( ls "$rigRecord/RigOne" | LC_ALL=C sed -n 1p )"
mkdir -p "$rigRecord/RigGone" ; printf 'passed=2026-01-01T00:00:00Z\n' > "$rigRecord/RigGone/old" ; printf 'passed=2026-01-01T00:00:00Z\n' > "$rigRecord/RigGone/young"
python3 -I -B -c 'import os, sys, time; then = time.time() - 8 * 86400; [os.utime(p, (then, then)) for p in sys.argv[1:]]' "$rigRecord/RigOne/$rigOld" "$rigRecord/RigGone/old" || rigRefuse "the records could not be aged"
rigAssert "a pass recorded eight days ago is no pass" "$( rigPassed a RigOne )" "-"
rigDo a RigTwo
rigAssert "the next run of anything removes every record older than seven days, of every test, and keeps the younger" "$rigRc $( [ -e "$rigRecord/RigOne/$rigOld" ] && printf kept || printf gone ) $( [ -e "$rigRecord/RigGone/old" ] && printf kept || printf gone ) $( [ -e "$rigRecord/RigGone/young" ] && printf kept || printf gone ) $( rigPassed a RigTwo )" "0 gone gone kept passed"

echo "-- 7. where the record cannot be written, tests run as ever --"
rigFresh
mkdir -p "$rigHome/.agents/magic-team" ; : > "$rigRecord"
rigDo a RigOne
rigAssert "a file where the record should be: the test is run and passes, and nothing is kept" "$rigRc $( LC_ALL=C grep -c '^PASS  RigOne ' "$rigTmp/a.out" || : ) $( rigPassed a RigOne )" "0 1 -"
rm -f "$rigRecord"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS PASSED CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_PASSED: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
