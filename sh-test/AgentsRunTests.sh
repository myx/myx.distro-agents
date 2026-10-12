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
## ONE FULL SUITE AT A TIME, MACHINE-WIDE. A run of every test (no name given) waits its turn,
## in arrival order, and says in one line that it waits and behind whom; a run of named tests
## is never queued. The line is one folder on the machine, $HOME/.agents/magic-team/suite-queue,
## never a folder of the package: a runner started from any copy of the package (MDLT_ORIGIN)
## stands in the same line. A ticket is a file named by its arrival time, holding the pid of
## its runner; one whose runner no longer exists is taken out by whoever waits behind it, so
## no turn is held by the dead.
## The hand rule this replaces, `mkdir $MMDAPP/.local/temp/suite-run.lock` around a full suite,
## is kept by both sides, so a session on the hand rule and a queued run never run at once: a
## run at its turn takes that lock itself and gives it back when it ends, and waits while
## another holds it. A lock taken by hand whose note names the folder this run's source root
## is in, under $MMDAPP/.local/temp, is the caller's own, taken for this very run: it is the
## turn, and is left for the caller to remove. A lock left by a runner that no longer exists
## is removed; one taken by hand never is.
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

runQueueDir="${HOME:-}/.agents/magic-team/suite-queue"
runHandLock="$MMDAPP/.local/temp/suite-run.lock"
runTicket="" runLockMine=""

AgentsRunRunnerAlive(){ ## pid -- rc 0 while a process of that pid is running this runner
	case "$1" in ''|*[!0123456789]*) return 1 ;; esac
	case "$( ps -p "$1" -ww -o args= 2>/dev/null )" in *AgentsRunTests.sh*) return 0 ;; esac
	return 1
}
AgentsRunHandLockNote(){ ## -- what the hand lock's holder wrote in it, on one line
	local noteText
	noteText="$( cat "$runHandLock"/* 2>/dev/null | LC_ALL=C tr '\n' ' ' | LC_ALL=C cut -c1-240 )"
	noteText="${noteText% }"
	printf '%s' "${noteText:-(no note in it)}"
}
AgentsRunHandLockOwn(){ ## -- rc 0 when the lock was taken by hand by this run's own caller, for this run
	local ownFolder="${MDLT_ORIGIN#"$MMDAPP/.local/temp/"}"
	[ "$ownFolder" != "$MDLT_ORIGIN" ] || return 1
	ownFolder="${ownFolder%%/*}"
	[ -n "$ownFolder" ] || return 1
	! LC_ALL=C grep -q '^runner-pid: ' "$runHandLock"/* 2>/dev/null || return 1
	case " $( cat "$runHandLock"/* 2>/dev/null | LC_ALL=C tr -c 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-' ' ' ) " in
		*" $ownFolder "*) return 0 ;;
	esac
	return 1
}
AgentsRunQueueLeave(){ ## -- out of the line, and the lock given back where this run took it
	[ -z "$runTicket" ] || rm -f "$runQueueDir/$runTicket"
	[ -z "$runLockMine" ] || { rm -f "$runHandLock/holder.txt" ; rmdir "$runHandLock" 2>/dev/null ; }
	runTicket="" ; runLockMine=""
}
AgentsRunQueueTurn(){ ## -- stands in the line and returns at this run's turn; says whom it waits behind, each time that changes
	local turnStamp turnFile turnPid turnWhom turnSaid=""
	mkdir -p "$runQueueDir" 2>/dev/null || {
		echo "⛔ ERROR: AgentsRunTests.sh: cannot create the machine's line for full suites: $runQueueDir -- a full suite is not run outside its turn; name the tests to run some without one" >&2 ; exit 1
	}
	turnStamp="$( perl -MTime::HiRes=time -e 'printf "%017.6f", time' 2>/dev/null )" || turnStamp=""
	[ -n "$turnStamp" ] || turnStamp="$( date +%s ).000000"
	runTicket="$turnStamp.$$.ticket"
	trap AgentsRunQueueLeave EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM HUP
	## whole or not at all: a ticket half written would read as one of no runner
	printf 'pid=%s\norigin=%s\nsince=%s\n' "$$" "$MDLT_ORIGIN" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$runQueueDir/.$runTicket" \
		&& mv -f "$runQueueDir/.$runTicket" "$runQueueDir/$runTicket" || {
		echo "⛔ ERROR: AgentsRunTests.sh: cannot stand in the machine's line for full suites: $runQueueDir" >&2 ; exit 1
	}
	while : ; do
		## taken by hand by this run's own caller: that is the turn
		if [ -d "$runHandLock" ] && AgentsRunHandLockOwn ; then
			return 0
		fi
		turnWhom=""
		for turnFile in "$runQueueDir"/*.ticket ; do
			[ -f "$turnFile" ] || continue
			[ "${turnFile##*/}" \< "$runTicket" ] || continue
			turnPid="$( LC_ALL=C sed -n 's/^pid=//p' "$turnFile" 2>/dev/null | LC_ALL=C sed -n 1p )"
			if ! AgentsRunRunnerAlive "$turnPid" ; then
				rm -f "$turnFile" ; continue
			fi
			[ -n "$turnWhom" ] || turnWhom="the run of pid $turnPid from $( LC_ALL=C sed -n 's/^origin=//p' "$turnFile" 2>/dev/null | LC_ALL=C sed -n 1p ), in line since $( LC_ALL=C sed -n 's/^since=//p' "$turnFile" 2>/dev/null | LC_ALL=C sed -n 1p )"
		done
		if [ -z "$turnWhom" ] ; then
			if mkdir "$runHandLock" 2>/dev/null ; then
				runLockMine=1
				printf 'runner-pid: %s\nagent: AgentsRunTests.sh, a full suite from %s\ntaken: %s\n' "$$" "$MDLT_ORIGIN" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$runHandLock/holder.txt"
				return 0
			fi
			turnPid="$( LC_ALL=C sed -n 's/^runner-pid: //p' "$runHandLock/holder.txt" 2>/dev/null | LC_ALL=C sed -n 1p )"
			if [ -n "$turnPid" ] && ! AgentsRunRunnerAlive "$turnPid" ; then
				rm -f "$runHandLock/holder.txt" ; rmdir "$runHandLock" 2>/dev/null
				continue
			fi
			turnWhom="the lock $runHandLock, taken by hand and held by: $( AgentsRunHandLockNote ) -- where that was done for this very run, remove it: the run takes the turn itself"
		fi
		if [ "$turnWhom" != "$turnSaid" ] ; then
			echo "# AgentsRunTests.sh: one full suite runs on this machine at a time -- this one waits its turn behind $turnWhom" >&2
			turnSaid="$turnWhom"
		fi
		sleep 2
	done
}
## No name given is the whole suite, and that waits its turn.
[ $# -gt 0 ] || AgentsRunQueueTurn

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
