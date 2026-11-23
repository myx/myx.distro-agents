#!/usr/bin/env bash
## Behavioural check on the suite's red list (sh-test/known-failures.txt and the runner that reads it), run rather than read,
## on a fixture machine built here: a HOME of its own, a workspace, and one copy of the package holding the runner under test
## and three tiny tests. Held:
##   1. CONTROL, and the whole point: a failure with no row of its own is printed with no owner and counted UNOWNED, so a
##      runner that names an owner it does not have is caught here.
##   2. A red test with a row carries its owner and its reason, on its FAIL line of the summary and on stderr.
##   3. A green test with a row is printed FIXED and counted FIXED, and never as PASS: a stale row is seen, not hidden.
##   4. The last line counts what the summary holds: OWNED, UNOWNED and FIXED beside the totals.
##   5. A row that is not three filled fields stops the run before any test starts, and names the line.
##   6. Comments, blank lines and a row for a test this run does not hold are no error.
## Red recipe: on the runner before this list, section 2's FAIL line reads `FAIL RigRed rc=1` with no owner= and section 1
## reports it as if it were the owned case, section 3 prints PASS and counts FIXED 0, and section 5 runs the tests anyway.
## Offline: every tree is the rig's own, under the rig's HOME, and every process this check starts is ended by it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigRunner="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its tests with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsKnownFailuresCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home" rigWs="$rigTmp/ws" rigSource="$rigTmp/source"
rigPkg="$rigSource/myx/myx.distro-agents"
mkdir -p "$rigHome" "$rigWs/.local/agents/members" "$rigPkg/sh-test/check-fixtures"
cp "$rigRunner" "$rigPkg/sh-test/AgentsRunTests.sh" || rigRefuse "the runner under test could not be copied into the rig"
## THE RUNNER IS A ROUTER: its parts travel with it, or the rig's copy finds none and runs nothing.
mkdir -p "$rigPkg/sh-test/runner" && cp "$( dirname "$rigRunner" )"/runner/*.sh "$rigPkg/sh-test/runner"/ || rigRefuse "the runner's parts could not be copied into the rig"
cp "$( dirname "$rigRunner" )/check-fixtures"/runner-*.py "$rigPkg/sh-test/check-fixtures/" || rigRefuse "the runner's keepers could not be copied into the rig"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## The three tests: one red, one green, and a row that names a test no run here holds.
printf '#!/usr/bin/env bash\necho "RIG_RED: ran"\nexit 1\n' > "$rigPkg/sh-test/RigRed.test.sh"
printf '#!/usr/bin/env bash\necho "RIG_GREEN: ran"\n' > "$rigPkg/sh-test/RigGreen.test.sh"
rigList="$rigPkg/sh-test/known-failures.txt"
## A list in the shape the file itself carries: what it is, a row a test, comments and blank lines among them.
rigListWrite(){
	cat > "$rigList" <<'RIGLIST'
## the checks that fail today, with the owner of each and the reason it is not fixed
RigRed	magic-tester	the Wait row returns TIMEOUT where the answer came
## a test this run does not hold: no row of the run is owed to it
RigAbsent	keeper-myx	its rig is not on every host

RigGreen	magic-developer	it waited on a lane that was never given back
RIGLIST
}

rigRc="" rigOut="" rigFolder=""
rigRun(){ ## the runner's own options, then the test names -- its output in rigOut, its status in rigRc, its run folder in rigFolder
	rigRc=0
	rigOut="$( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigSource" MYXROOT="${MYXROOT:-}" \
		bash "$rigPkg/sh-test/AgentsRunTests.sh" -w 1 "$@" 2>&1 )" || rigRc=$?
	rigFolder="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^# AgentsRunTests\.sh: .* run folder: //p' | LC_ALL=C sed -n 1p )"
}
rigFailLines(){ ## -- the run's own summary lines that start with FAIL, one a line, before the known-failure lines
	[ -n "$rigFolder" ] || return 0
	LC_ALL=C grep '^FAIL' "$rigFolder/summary.txt" 2> /dev/null || :
}
rigSummary(){ ## test name -- the FAIL line of that test, empty where it has none
	rigFailLines | LC_ALL=C awk -v want="$1" '$2 == want' | LC_ALL=C sed -n 1p
}
rigVerdictOf(){ ## test name -- PASS, FAIL or FIXED, the word its own line of the summary starts with, empty where it has no line
	[ -n "$rigFolder" ] || return 0
	LC_ALL=C awk -v want="$1" '$2 == want { print $1 ; exit ; }' "$rigFolder/summary.txt" 2> /dev/null
}
rigTotals(){ ## -- the last line of the summary, as it is, with the wall clock and what it says nothing of taken off it
	[ -n "$rigFolder" ] || return 0
	LC_ALL=C tail -n 1 "$rigFolder/summary.txt" 2> /dev/null | LC_ALL=C sed 's/  WALL [^ ]*//'
}
rigCounts(){ ## -- the counts of the last line, as `OWNED n UNOWNED n FIXED n`
	[ -n "$rigFolder" ] || return 0
	LC_ALL=C tail -n 1 "$rigFolder/summary.txt" 2> /dev/null | LC_ALL=C sed -n 's/^.*  OWNED /OWNED /p' | LC_ALL=C tr -s ' '
}

echo "-- 1. control: a failure with no row of its own is named as one, and no owner is invented for it --"
rigListWrite
LC_ALL=C grep -v '^RigRed' "$rigList" > "$rigList.nored" && mv "$rigList.nored" "$rigList"
rigRun -t 60 RigRed
rigAssert "the red test fails" "$( rigVerdictOf RigRed )" FAIL
rigAssert "and its line names no owner" "$( rigSummary RigRed | LC_ALL=C grep -c 'owner=' || : )" 0
rigAssert "so the run counts it UNOWNED and nothing as OWNED" "$( rigCounts )" "OWNED 0 UNOWNED 1 FIXED 0"

echo "-- 2. a red test with a row carries its owner and its reason --"
rigListWrite
rigRun -t 60 RigRed RigGreen
rigAssert "the red test fails" "$( rigVerdictOf RigRed )" FAIL
rigAssert "and its FAIL line carries the row's owner and reason" "$( rigSummary RigRed )" \
	"FAIL RigRed rc=1 owner=magic-tester reason=the Wait row returns TIMEOUT where the answer came"
rigAssert "the summary carries that row once, and nowhere twice" \
	"$( LC_ALL=C grep -c 'owner=magic-tester' "$rigFolder/summary.txt" 2> /dev/null || : )" 1
rigAssert "and the same reaches the run's stderr, beside its FAIL line" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'owner=magic-tester' || : )" 1
rigAssert "it counts as OWNED and nothing is UNOWNED" "$( rigCounts )" "OWNED 1 UNOWNED 0 FIXED 1"

echo "-- 3. a green test with a row is FIXED: a stale row is seen, and never hidden as a pass --"
rigAssert "the green test is FIXED, and no PASS line of its own" "$( rigVerdictOf RigGreen )$( rigSummary RigGreen )" FIXED
rigAssert "it is printed FIXED, with the row to take out" \
	"$( LC_ALL=C awk -v want=RigGreen '$2 == want { printf "%s %s", $1, $2 ; }' "$rigFolder/summary.txt" 2> /dev/null )" "FIXED RigGreen"
rigAssert "and it is counted FIXED" "$( rigCounts )" "OWNED 1 UNOWNED 0 FIXED 1"

echo "-- 4. the last line counts the totals as they are --"
rigAssert "the totals line keeps its shape, and then counts what the summary holds" \
	"$( rigTotals | LC_ALL=C tr -s ' ' )" "TOTAL 2 PASS 1 FAIL 1 OWNED 1 UNOWNED 0 FIXED 1"
echo "-- 5. a row that is not three filled fields stops the run, naming its line --"
printf 'RigGreen\tmagic-developer\n' > "$rigList"
rigRun -t 60 RigGreen
rigAssert "the run is refused, and its status is a failure" "$rigRc" 1
rigAssert "the refusal names the list and the line it read" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'not three filled fields.*the line(s): 1' || : )" 1
rigAssert "control: and no test of it started, so no run folder was made" "$rigFolder" ""
printf 'RigGreen\t\tmagic-developer\treason\n' > "$rigList"
rigRun -t 60 RigGreen
rigAssert "a row with an empty owner is refused the same way" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'not three filled fields.*the line(s): 1' || : )" 1

echo "-- 6. comments, blank lines and a row for a test this run does not hold are no error --"
rigListWrite
rigRun -t 60 RigGreen
rigAssert "a run of that one test passes, with the row for the absent test read and left alone" "$rigRc $( rigCounts )" "0 OWNED 0 UNOWNED 0 FIXED 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS KNOWN FAILURES CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_KNOWN_FAILURES: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
