#!/usr/bin/env bash
## AgentsRunPassed.sh -- the --passed operation of the test runner: for each test named, the time it passed on the
## state it would run on now, or `-`. Runs nothing, stands in no line, makes no run folder. Reached only through
## AgentsRunTests.sh, which sets MDAT_SUITE_TESTDIR: a part of that runner, not a program of its own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

testDir="${MDAT_SUITE_TESTDIR:?⛔ ERROR: AgentsRunTests.sh: MDAT_SUITE_TESTDIR is not set -- run this through AgentsRunTests.sh}"
runWorkers="" runTimeout=900 runPassed="" runStallMargin=120 runSweep="" runSweepHours=24 runWait=""
## The arguments as given, for the run that goes on detached (NOBODY SITS ON A WAIT).
runArgs=( "$@" )
while [ $# -gt 0 ] ; do
	case "$1" in
		--sweep-rigs|--sweep-rigs-list)
			runSweep="$1" ; shift
			if [ $# -gt 0 ] ; then
				case "$1" in ''|*[!0123456789]*) echo "⛔ ERROR: AgentsRunTests.sh: $runSweep takes a number of hours: $1" >&2 ; exit 1 ;; esac
				runSweepHours="$1" ; shift
			fi
		;;
		-w|--workers) runWorkers="$2" ; shift 2 ;;
		-t|--timeout) runTimeout="$2" ; shift 2 ;;
		--stall-margin)
			case "$2" in ''|*[!0123456789]*) echo "⛔ ERROR: AgentsRunTests.sh: --stall-margin takes a number of seconds: $2" >&2 ; exit 1 ;; esac
			runStallMargin="$2" ; shift 2
		;;
		--passed) runPassed=1 ; shift ;;
		--wait) runWait=1 ; shift ;;
		--) shift ; break ;;
		-*) echo "⛔ ERROR: AgentsRunTests.sh: unknown option: $1" >&2 ; exit 1 ;;
		*) break ;;
	esac
done

runQueueDir="${HOME:-}/.agents/magic-team/suite-queue"
runHandLock="$MMDAPP/.local/temp/suite-run.lock"
runTicket="" runLockMine="" runDir="" runChecks=""
runSlotDir="${HOME:-}/.agents/magic-team/suite-workers"
runSlotDefault="$( sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2 )"
case "$runSlotDefault" in ''|*[!0123456789]*) runSlotDefault=2 ;; esac
runSlotDefault=$(( runSlotDefault / 2 ))
[ "$runSlotDefault" -ge 1 ] || runSlotDefault=1
runTestLock="$MMDAPP/.local/temp/one-test-run.lock"
## the member folder of the workspace the run is in: what every test is handed, and what the pass key
## covers, so that the member set of the session that started the run reaches neither.
runMembers="${MMDAPP%/}/.local/agents/members"
## the folder this run's source root is in, under the workspace's temp: empty for any other tree
runOwnFolder="${MDLT_ORIGIN#"$MMDAPP/.local/temp/"}"
if [ "$runOwnFolder" != "$MDLT_ORIGIN" ] ; then runOwnFolder="${runOwnFolder%%/*}" ; else runOwnFolder="" ; fi
runLaneDir="${HOME:-}/.agents/magic-team/suite-lanes"
runLaneMine="" runLaneAlone="" runLaneCountNow=1 runLaneWhy=""
## NOBODY SITS ON A WAIT: a run started detached for its caller takes that caller's ticket over first, before any work of its own, so the
## caller hands its place on at once. Its own pid and start go on the ticket, its run folder comes from it, and leaving the line is its own.
if [ -n "${MDAT_SUITE_QUEUE_ADOPT:-}" ] && [ -f "$runQueueDir/$MDAT_SUITE_QUEUE_ADOPT" ] ; then
	{ LC_ALL=C grep -v -E '^(pid|pstart)=' "$runQueueDir/$MDAT_SUITE_QUEUE_ADOPT" ; printf 'pid=%s\npstart=%s\n' "$$" "$( ps -o lstart= -p "$$" 2> /dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ //;s/ $//' )" ; } > "$runQueueDir/.$MDAT_SUITE_QUEUE_ADOPT" \
		&& mv -f "$runQueueDir/.$MDAT_SUITE_QUEUE_ADOPT" "$runQueueDir/$MDAT_SUITE_QUEUE_ADOPT" || {
		echo "⛔ ERROR: AgentsRunTests.sh: cannot take over its caller's ticket in the machine's line of test runs: $runQueueDir/$MDAT_SUITE_QUEUE_ADOPT" >&2 ; exit 1
	}
	runTicket="$MDAT_SUITE_QUEUE_ADOPT"
	trap AgentsRunQueueLeave EXIT
	runDir="$( LC_ALL=C sed -n 's/^rundir=//p' "$runQueueDir/$runTicket" | LC_ALL=C sed -n 1p )"
fi
unset MDAT_SUITE_QUEUE_ADOPT

## The slot keeper, one small program for both ends of a slot: every change to the one state
## file ($runSlotDir/state: `H <pid>` a slot held, `W <pid>` one asked for, in arrival order)
## is made under an exclusive lock on $runSlotDir/lock, which the system gives back by itself
## when its holder dies, and an entry whose process no longer exists is dropped at every read.
##   take <dir> <default budget> <fd to say it on> <said marker> <started file> <hand lock> <own folder> <timeout> <command...>
##     asks for a slot as this very process, waits its place in the line, and while another
##     session holds the hand lock, then lowers its priority, sets the test's own time limit
##     and becomes the command: the slot is held by the test's own pid from before it starts
##     until that process is gone.
##   give <dir> <pid>   gives that process's slot back at once, where the runner saw it end.
## The three keepers are programs beside the tests, in check-fixtures; a runner copied alone (a rig) takes them from the origin's package.
runKeeperDir="$testDir/check-fixtures"
[ -f "$runKeeperDir/runner-slot-keeper.py" ] || runKeeperDir="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
runSlotKeeper="$runKeeperDir/runner-slot-keeper.py"

runPassDir="${HOME:-}/.agents/magic-team/suite-results"
runPassAge=$(( 7 * 86400 ))
## What a pass is keyed by, each `<name>=<folder>`: the copy of the package this runner is
## in, myx.common as it is installed, the member folder of the workspace the run is in, and the
## tooling's other packages under the source root.
## The parts of the runner are read by every test it starts, so a change to one moves the state a pass was earned on.
runPassRoots=( "package=$( cd "$testDir/.." && pwd -P )" "myxroot=${MYXROOT:-/usr/local/share/myx.common}" "members=$runMembers" "runner=${MDAT_SUITE_PARTS:-$testDir/runner}" )
for runPassRoot in "$MDLT_ORIGIN"/myx/myx.distro-* "$MDLT_ORIGIN"/myx/myx.common ; do
	[ -d "$runPassRoot" ] || continue
	[ "$( cd "$runPassRoot" 2>/dev/null && pwd -P )" != "${runPassRoots[0]#package=}" ] || continue
	runPassRoots[${#runPassRoots[@]}]="tooling/${runPassRoot##*/}=$runPassRoot"
done
runPassWith="bash $BASH_VERSION, $( uname -srm 2>/dev/null )"

## The pass keeper, the one maker of a key and the one reader of the record.
##   key <dir> <age seconds> <what the tests run under> <name>=<folder>... -- <test>...
##     prints for each test `<test> <key> <when>`: the key of the state it would run on now,
##     and the time of the pass on record under it, where one younger than the age is; `-`
##     for a key that cannot be made (a file that cannot be read, or one gone mid-read: no
##     key, so no pass is kept or found), and for no pass. A root is every file below it,
##     links followed and .git left out, by its path below the root, whether it may be run,
##     and its content.
##   prune <dir> <age seconds>   removes every record older than the age, of every test.
runPassKeeper="$runKeeperDir/runner-pass-keeper.py"
AgentsRunPassKey(){ ## test name... -- for each, on a line: the test, the key of the state it would run on now, when it passed on that state
	python3 -I -B "$runPassKeeper" key "$runPassDir" "$runPassAge" "$runPassWith" "${runPassRoots[@]}" -- "$@" 2>/dev/null
}
AgentsRunPassKeep(){ ## test name, key, seconds -- that pass on record, whole or not at all
	mkdir -p "$runPassDir/$1" 2>/dev/null || return 1
	printf 'passed=%s\nseconds=%s\norigin=%s\n' "$( date -u +%Y-%m-%dT%H:%M:%SZ )" "$3" "$MDLT_ORIGIN" > "$runPassDir/$1/.$2.$$" 2>/dev/null \
		&& mv -f "$runPassDir/$1/.$2.$$" "$runPassDir/$1/$2" 2>/dev/null || { rm -f "$runPassDir/$1/.$2.$$" 2>/dev/null ; return 1 ; }
}
AgentsRunNames(){ ## name-substring... -- the tests of this copy, one on a line: every *.test.sh of sh-test and of its subfolders, or those whose name contains any of the substrings
	local namesTest namesName namesWant namesPick
	for namesTest in "$testDir"/*.test.sh "$testDir"/*/*.test.sh ; do
		[ -f "$namesTest" ] || continue
		namesName="${namesTest##*/}" ; namesName="${namesName%.test.sh}"
		if [ $# -gt 0 ] ; then
			namesPick=""
			for namesWant in "$@" ; do
				case "$namesName" in *"$namesWant"*) namesPick=1 ;; esac
			done
			[ -n "$namesPick" ] || continue
		fi
		printf '%s\n' "$namesName"
	done
}
## The file of a test, by its name: in sh-test itself, else in the subfolder that holds it, one level down.
AgentsRunTestPath(){ ## test name
	local pathTest
	for pathTest in "$testDir/$1.test.sh" "$testDir"/*/"$1.test.sh" ; do
		[ -f "$pathTest" ] && { printf '%s\n' "$pathTest" ; return 0 ; }
	done
	printf '%s\n' "$testDir/$1.test.sh"
}
## Asked what has passed, it runs nothing, stands in no line and makes no run folder.
if [ -n "$runPassed" ] ; then
	runPassedNames=()
	while IFS= read -r runName ; do
		[ -z "$runName" ] || runPassedNames[${#runPassedNames[@]}]="$runName"
	done <<< "$( AgentsRunNames "$@" )"
	[ ${#runPassedNames[@]} -gt 0 ] || { echo "⛔ ERROR: AgentsRunTests.sh: no test matches" >&2 ; exit 1 ; }
	runPassedLines="$( AgentsRunPassKey "${runPassedNames[@]}" )"
	## no keeper, no key: nothing is known to have passed
	[ -n "$runPassedLines" ] || runPassedLines="$( printf '%s - -\n' "${runPassedNames[@]}" )"
	printf '%s\n' "$runPassedLines" | LC_ALL=C cut -d' ' -f1,3
	exit 0
fi
