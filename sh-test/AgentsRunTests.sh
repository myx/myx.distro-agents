#!/usr/bin/env bash
##
## AgentsRunTests.sh -- runs sh-test/*.test.sh in parallel (myx.common lib/parallel) and keeps
## one log and one receipt per test in a run folder:
##   $MMDAPP/.local/temp/mdat-tests/<UTC-stamp>/<test>.log      the test's whole output
##   $MMDAPP/.local/temp/mdat-tests/<UTC-stamp>/<test>.receipt  rc, seconds, last line
##   $MMDAPP/.local/temp/mdat-tests/<UTC-stamp>/summary.txt     PASS / FAIL per test, totals
## and points $MMDAPP/.local/temp/mdat-tests/latest at it.
##
## Usage: AgentsRunTests.sh [-w <workers>] [-t <timeout-seconds>] [<name-substring>...]
##   no substrings: every *.test.sh; otherwise the tests whose name contains any of them.
##   Workers: lib/parallel's own default (ENV_PARALLEL_WORKER_COUNT, else 4) unless -w is given.
##   Each task line of the run list is `<test> <timeout-seconds>`; -t sets the timeout written
##   into each line (default 900).
##
## Each test gets a test-only session identity, so no test can write into a live session store.
##

set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

testDir="$( cd "$( dirname "$0" )" && pwd )"
runWorkers="" runTimeout=900
while [ $# -gt 0 ] ; do
	case "$1" in
		-w|--workers) runWorkers="$2" ; shift 2 ;;
		-t|--timeout) runTimeout="$2" ; shift 2 ;;
		--) shift ; break ;;
		-*) echo "⛔ ERROR: AgentsRunTests.sh: unknown option: $1" >&2 ; exit 1 ;;
		*) break ;;
	esac
done

runRoot="$MMDAPP/.local/temp/mdat-tests"
runDir="$runRoot/$( date -u +%Y%m%dT%H%M%SZ )"
mkdir -p "$runDir" || { echo "⛔ ERROR: AgentsRunTests.sh: cannot create $runDir" >&2 ; exit 1 ; }
ln -sfn "$runDir" "$runRoot/latest" 2>/dev/null || :

runList="$runDir/tests.list"
: > "$runList"
for runTest in "$testDir"/*.test.sh ; do
	runName="$( basename "$runTest" .test.sh )"
	if [ $# -gt 0 ] ; then
		runPick=""
		for runWant in "$@" ; do
			case "$runName" in *"$runWant"*) runPick=1 ;; esac
		done
		[ -n "$runPick" ] || continue
	fi
	printf '%s %s\n' "$runName" "$runTimeout" >> "$runList"
done
runCount="$( grep -c . "$runList" )"
[ "$runCount" -gt 0 ] || { echo "⛔ ERROR: AgentsRunTests.sh: no test matches" >&2 ; exit 1 ; }

AgentsRunOneTest(){ ## test name, timeout seconds -- one task line of the run list
	local oneName="$1" oneTimeout="${2:-$runTimeout}" oneStart oneEnd oneRc=0 oneLast
	oneStart="$( date +%s )"
	(
		unset MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT harnessSessionId harnessAgent
		export CLAUDE_CODE_SESSION_ID="rig-run-$oneName-test-only"
		cd "$testDir" || exit 1
		exec perl -e 'alarm shift; exec @ARGV' "$oneTimeout" bash "$testDir/$oneName.test.sh"
	) > "$runDir/$oneName.log" 2>&1 || oneRc=$?
	oneEnd="$( date +%s )"
	oneLast="$( grep . "$runDir/$oneName.log" | tail -n 1 )"
	printf 'rc=%s\nseconds=%s\nlast=%s\n' "$oneRc" "$(( oneEnd - oneStart ))" "$oneLast" > "$runDir/$oneName.receipt"
	if [ "$oneRc" = 0 ] ; then
		printf 'PASS  %-48s %4ss  %s\n' "$oneName" "$(( oneEnd - oneStart ))" "$oneLast"
	else
		printf 'FAIL  %-48s %4ss  rc=%s  %s\n' "$oneName" "$(( oneEnd - oneStart ))" "$oneRc" "$oneLast"
	fi
}

. "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" || {
	echo "⛔ ERROR: AgentsRunTests.sh: myx.common lib/parallel is not available" >&2 ; exit 1
}

echo "# AgentsRunTests.sh: $runCount test(s), workers ${runWorkers:-lib/parallel default}, timeout ${runTimeout}s, run folder: $runDir" >&2
runStart="$( date +%s )"
Parallel ${runWorkers:+--workers "$runWorkers"} AgentsRunOneTest < "$runList" | tee "$runDir/progress.txt"

{
	for runName in $( cut -d' ' -f1 "$runList" ) ; do
		runRc="$( sed -n 's/^rc=//p' "$runDir/$runName.receipt" 2>/dev/null )"
		if [ "${runRc:-x}" = 0 ] ; then echo "PASS $runName" ; else echo "FAIL $runName rc=${runRc:-none}" ; fi
	done | sort -k1,1 -k2,2
	runPass="$( grep -l '^rc=0$' "$runDir"/*.receipt 2>/dev/null | wc -l | tr -d ' ' )"
	echo "TOTAL $runCount  PASS $runPass  FAIL $(( runCount - runPass ))  WALL $(( $( date +%s ) - runStart ))s"
} > "$runDir/summary.txt"

echo "---" >&2
grep '^FAIL' "$runDir/summary.txt" || :
tail -n 1 "$runDir/summary.txt"
grep -q '^FAIL' "$runDir/summary.txt" && exit 1
exit 0
