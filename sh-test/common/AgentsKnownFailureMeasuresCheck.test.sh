#!/usr/bin/env bash
## Behavioural check on how a run's summary counts a red test (sh-test/AgentsRunTests.sh and the runner it routes to), run
## rather than read, on a fixture machine built here: a HOME of its own, a workspace, and one copy of the package holding
## the runner under test and three tiny tests. A red test is one of three kinds, and only one kind measured an assertion, so
## the summary must count the three apart. Held:
##   1. CONTROL: the three tests all run, and all three end red. Nothing below is measured on a run that did not happen.
##   2. CONTROL: the runner already marks a test that ended at its own wall-clock limit, so the fact is there and only the
##      counting apart is missing.
##   3. A test that failed an assertion is counted as an assertion, and the other two kinds are not.
##   4. A test that refused to report a result is counted apart, and its own row carries `kind=REFUSED`.
##   5. A test that ended at its wall-clock limit is counted apart, and its own row carries `kind=TIMEOUT`.
##   6. CONTROL, the other half of 3 to 5: a run of the assertion test alone counts one assertion, and no row of that run
##      carries a kind, so a summary that counts every red test as a refusal is caught here as surely as one that does not.
##   7. CONTROL: the refusal the rig's test speaks is the refusal the suite's own checks speak, so the rig's input is real.
## Red recipe: on the runner before S6.47's counting, the last line reads
##   `TOTAL 3  PASS 0  FAIL 3  WALL 13s  OWNED 3  UNOWNED 0  FIXED 0`
## and there is no `KINDS` line at all, so section 3 reads an empty assertion count where 1 is wanted, and sections 4 and 5
## read an empty count and no kind, because a test that refused and a test that timed out are both counted as a failure and
## are indistinguishable in every count.
## The words this check reads are settled by the architect's naming read: each stands once below, so a rename costs one line.
## Offline: every tree is the rig's own, under the rig's HOME, and every process this check starts is ended by it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigRunner="$rigOrigin/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
## The three kinds the summary must count apart, and the field a red test's own row carries its kind in.
rigWordAssert='ASSERT'        ## the count of tests that ran an assertion and it failed
rigWordRefused='REFUSED'      ## the count of tests that refused to report a result
rigWordTimedOut='TIMEOUT'     ## the count of tests that ended at their own wall-clock limit
rigKindField='kind='          ## the field of a red test's own row that names which of the three it is
rigSaysRefused='refusing to report a result'
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its tests with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsKnownFailureMeasuresCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home" rigWs="$rigTmp/ws" rigSource="$rigTmp/source"
rigPkg="$rigSource/myx/myx.distro-agents"
mkdir -p "$rigHome" "$rigWs/.local/agents/members" "$rigPkg/sh-test/check-fixtures"
cp "$rigRunner" "$rigPkg/sh-test/AgentsRunTests.sh" || rigRefuse "the runner under test could not be copied into the rig"
## THE RUNNER IS A ROUTER: its parts and its keepers travel with it, or the rig's copy finds none and runs nothing.
mkdir -p "$rigPkg/sh-test/runner" && cp "$( dirname "$rigRunner" )"/runner/*.sh "$rigPkg/sh-test/runner"/ || rigRefuse "the runner's parts could not be copied into the rig"
cp "$( dirname "$rigRunner" )/check-fixtures"/runner-*.py "$rigPkg/sh-test/check-fixtures"/ || rigRefuse "the runner's keepers could not be copied into the rig"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## The three red tests, one of each kind. The refusal speaks the words the suite's own checks speak when they refuse,
## which is the one signal a refusal leaves behind; the stall sleeps past a two second limit and is ended by the runner.
printf '#!/usr/bin/env bash\necho "RIG_ASSERTED: one row read, one wanted"\necho "  FAIL the row reads 0 where 1 is wanted"\nexit 1\n' > "$rigPkg/sh-test/RigAsserted.test.sh"
printf '#!/usr/bin/env bash\necho "⛔ ERROR: the rig holds no model family this leg knows -- %s" >&2\nexit 1\n' "$rigSaysRefused" > "$rigPkg/sh-test/RigRefused.test.sh"
printf '#!/usr/bin/env bash\necho "RIG_TIMEDOUT: begins"\nsleep 30\necho "RIG_TIMEDOUT: never reached"\n' > "$rigPkg/sh-test/RigTimedOut.test.sh"
rigList="$rigPkg/sh-test/known-failures.txt"
## One row each, in the shape the real file carries: a row is what makes a red test OWNED rather than UNOWNED, and the owner
## stands apart from the kind of failure, so this check reads the kind alone.
printf 'RigAsserted\tmagic-tester\tthe row reads 0 where 1 is wanted\nRigRefused\tmagic-tester\tthe rig holds no model family this leg knows\nRigTimedOut\tmagic-tester\tthe check or its rig stands still\n' > "$rigList"

rigRc="" rigOut="" rigFolder=""
rigRun(){ ## the runner's own options, then the test names -- its output in rigOut, its status in rigRc, its run folder in rigFolder
	rigRc=0
	rigOut="$( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigSource" MYXROOT="${MYXROOT:-}" \
		bash "$rigPkg/sh-test/AgentsRunTests.sh" -w 1 "$@" 2>&1 )" || rigRc=$?
	rigFolder="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^# AgentsRunTests\.sh: .* run folder: //p' | LC_ALL=C sed -n 1p )"
}
## The summary's own line is not this check's business: a count is read wherever it stands, so a line of its own and a wider
## totals line both answer. Only a word followed by a number counts, so a FAIL line naming a test is never read as one.
rigCountOf(){ ## a count's word -- the number the summary gives that word, empty where it gives none
	[ -n "$rigFolder" ] || return 0
	LC_ALL=C tr -s ' ' < "$rigFolder/summary.txt" 2> /dev/null | LC_ALL=C awk -v want="$1" '
		{ for (field = 1 ; field < NF ; field++) if ($field == want && $(field + 1) ~ /^[0-9]+$/) { print $(field + 1) ; exit ; } ; }
	'
}
## The kind is a keyed field on the test's own row, never a bare word: twenty reasons in the live red list hold "refuse",
## and a bare match would find one of those and call it a kind.
rigKindOf(){ ## a test name -- the kind its own row carries, empty where it carries none
	[ -n "$rigFolder" ] || return 0
	LC_ALL=C awk -v field="$rigKindField" -v name="$1" '
		$2 == name { for (part = 1 ; part <= NF ; part++) if (index($part, field) == 1) { print substr($part, length(field) + 1) ; exit ; } ; }
	' "$rigFolder/summary.txt" 2> /dev/null
}

echo "-- 1. control: the three tests all run, and all three end red --"
rigRun -t 2 RigAsserted RigRefused RigTimedOut
rigAssert "the three red tests each carry a FAIL line of their own" \
	"$( LC_ALL=C grep -c '^FAIL' "$rigFolder/summary.txt" 2> /dev/null || : )" 3
rigAssert "and the run counts three tests, none of them passed" \
	"$( rigCountOf TOTAL )/$( rigCountOf PASS )" "3/0"

echo "-- 2. control: the runner already marks a test that ended at its wall-clock limit --"
rigAssert "the timed-out test's own FAIL line says it ended at its limit" \
	"$( LC_ALL=C awk '$2 == "RigTimedOut" && /time-limit/ { print "marked" ; exit ; }' "$rigFolder/summary.txt" 2> /dev/null )" marked

echo "-- 3. an assertion failure is counted as one, and the other two kinds are not --"
rigAssert "the assertion count is the one test that ran an assertion" "$( rigCountOf "$rigWordAssert" )" 1
rigAssert "and the assertion test's own row carries no other kind" "$( rigKindOf RigAsserted )" ""

echo "-- 4. a refusal is counted apart, and its own row carries its kind --"
rigAssert "the summary gives a count of its own to a test that refused" "$( rigCountOf "$rigWordRefused" )" 1
rigAssert "and the refused test's own row says which kind it is" "$( rigKindOf RigRefused )" "$rigWordRefused"

echo "-- 5. a timeout is counted apart, and its own row carries its kind --"
rigAssert "the summary gives a count of its own to a test that timed out" "$( rigCountOf "$rigWordTimedOut" )" 1
rigAssert "and the timed-out test's own row says which kind it is" "$( rigKindOf RigTimedOut )" "$rigWordTimedOut"

echo "-- 6. control: one test that failed its assertion is counted as one, and the total says one --"
rigRun -t 2 RigAsserted
rigAssert "the one test ran an assertion and it failed, and the count says one" "$( rigCountOf "$rigWordAssert" )" 1
rigAssert "and no row of that run carries a kind at all" \
	"$( LC_ALL=C awk -v field="$rigKindField" '{ for (part = 1 ; part <= NF ; part++) if (index($part, field) == 1) { print "kinded" ; exit ; } ; }' "$rigFolder/summary.txt" 2> /dev/null )" ""
rigAssert "and the run holds that one test and no other" "$( rigCountOf TOTAL )" 1

echo "-- 7. an unowned red is named, not just counted: the list row is what makes one owned --"
printf 'RigAsserted\tmagic-tester\tthe row reads 0 where 1 is wanted\nRigTimedOut\tmagic-tester\tthe check or its rig stands still\n' > "$rigList"
rigRun -t 2 RigAsserted RigRefused RigTimedOut
rigAssert "the totals line counts the red no row of the list owns" "$( rigCountOf UNOWNED )" 1
rigAssert "and the summary names that test under its own heading" \
	"$( LC_ALL=C awk '$1 == "UNOWNED-TESTS" { want = $2 ; next } want && $1 == "RigRefused" { print "named" ; exit }' "$rigFolder/summary.txt" 2> /dev/null )" named
rigAssert "and names no test the list does own" \
	"$( LC_ALL=C awk '$1 == "UNOWNED-TESTS" { want = $2 ; next } want && ( $1 == "RigAsserted" || $1 == "RigTimedOut" ) { print "listed" ; exit }' "$rigFolder/summary.txt" 2> /dev/null )" ""

echo "-- 8. control: the refusal the rig speaks is the one the suite's own checks speak --"
rigAssert "the suite's own refusal helper says these words" \
	"$( LC_ALL=C grep -c -F "refusing to report a result" "$rigOrigin/myx/myx.distro-agents/sh-test/common/AgentsRunTestsKnownFailuresCheck.test.sh" 2> /dev/null || : )" 1

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ KNOWN FAILURE MEASURES CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'KNOWN_FAILURE_MEASURES: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
