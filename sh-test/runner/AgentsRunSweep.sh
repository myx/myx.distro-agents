#!/usr/bin/env bash
## AgentsRunSweep.sh -- the --sweep-rigs and --sweep-rigs-list operations of the test runner: lists the rigs a
## sweep would remove, or removes them, and runs no test. Reached only through AgentsRunTests.sh, which sets
## MDAT_SUITE_TESTDIR: a part of that runner, not a program of its own.
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
## Asked to sweep the rigs, it runs no test and stands in no line. A rig is swept when it is older than the hours, no
## process names its path (one ps for the whole sweep) and no link in it reaches a source tree (the no-symlinks rule: a
## delete never runs over one; the scan is AgentsToolsSandboxLinkScan, the one the sandbox-link check holds). The list
## form removes nothing. The removing form clears the immutable flags and read-only modes a check may have set, then
## removes the rig, and says so a rig a line.
if [ -n "$runSweep" ] ; then
	runSweepRoot="$MMDAPP/.local/agents/scratch/sh-test"
	[ -d "$runSweepRoot" ] || { echo "sweep: no rig folder at $runSweepRoot" ; exit 0 ; }
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.SandboxLinks.include" || exit 1
	runSweepRoots="$( AgentsToolsSourceRoots )"
	runSweepLive="$( ps -A -ww -o args= 2> /dev/null | LC_ALL=C grep -F -- "$runSweepRoot/" || : )"
	runSweepYoung=0 runSweepHeld=0 runSweepDone=0 runSweepFailed=0
	for runSweepRig in "$runSweepRoot"/* ; do
		[ -d "$runSweepRig" ] || { [ ! -e "$runSweepRig" ] || echo "sweep: kept, no rig folder: ${runSweepRig##*/}" ; continue ; }
		[ -n "$( find "$runSweepRig" -maxdepth 0 -mmin "+$(( runSweepHours * 60 ))" 2> /dev/null )" ] || { runSweepYoung=$(( runSweepYoung + 1 )) ; continue ; }
		case "$runSweepLive" in *"$runSweepRig"*) echo "sweep: kept, a process names it: ${runSweepRig##*/}" ; runSweepHeld=$(( runSweepHeld + 1 )) ; continue ;; esac
		if ! AgentsToolsSandboxLinkScan "$runSweepRoots" "$runSweepRig" > /dev/null 2>&1 ; then
			echo "sweep: kept, a link in it reaches a source tree: ${runSweepRig##*/}" ; runSweepHeld=$(( runSweepHeld + 1 )) ; continue
		fi
		if [ "$runSweep" = "--sweep-rigs-list" ] ; then
			echo "sweep: would remove ${runSweepRig##*/}" ; runSweepDone=$(( runSweepDone + 1 )) ; continue
		fi
		chflags -R nouchg,noschg "$runSweepRig" 2> /dev/null || :
		chmod -R u+rwX "$runSweepRig" 2> /dev/null || :
		if rm -rf -- "$runSweepRig" 2> /dev/null && [ ! -e "$runSweepRig" ] ; then
			echo "sweep: removed ${runSweepRig##*/}" ; runSweepDone=$(( runSweepDone + 1 ))
		else
			echo "sweep: could not remove ${runSweepRig##*/}" ; runSweepFailed=$(( runSweepFailed + 1 ))
		fi
	done
	if [ "$runSweep" = "--sweep-rigs-list" ] ; then
		printf 'sweep: %s rig(s) would be removed, %s kept (a process or a link), %s younger than %s hour(s)\n' "$runSweepDone" "$runSweepHeld" "$runSweepYoung" "$runSweepHours"
	else
		printf 'sweep: %s rig(s) removed, %s could not be, %s kept (a process or a link), %s younger than %s hour(s)\n' "$runSweepDone" "$runSweepFailed" "$runSweepHeld" "$runSweepYoung" "$runSweepHours"
	fi
	[ "$runSweepFailed" = 0 ] || exit 1
	exit 0
fi
