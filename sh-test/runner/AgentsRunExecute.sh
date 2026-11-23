#!/usr/bin/env bash
## AgentsRunExecute.sh -- the run operation of the test runner: the machine's line, the lanes, the worker slots,
## the pass record and the stall watch, and one test after another until the list is done. Reached only through
## AgentsRunTests.sh, which sets MDAT_SUITE_TESTDIR: a part of that runner, not a program of its own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

testDir="${MDAT_SUITE_TESTDIR:?⛔ ERROR: AgentsRunTests.sh: MDAT_SUITE_TESTDIR is not set -- run this through AgentsRunTests.sh}"
runWorkers="" runTimeout=900 runPassed="" runStallMargin=120 runYieldBound=120 runSweep="" runSweepHours=24 runWait=""
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

AgentsRunRunnerAlive(){ ## pid -- rc 0 while a process of that pid is running this runner
	case "$1" in ''|*[!0123456789]*) return 1 ;; esac
	## A run starts its script as `bash <script> <args>`, so the second word of its command line names the script.
	local aliveArgs aliveWord
	aliveArgs="$( ps -p "$1" -ww -o args= 2>/dev/null )"
	aliveArgs="${aliveArgs#"${aliveArgs%%[![:space:]]*}"}"
	aliveWord="${aliveArgs#* }"
	aliveWord="${aliveWord#"${aliveWord%%[![:space:]]*}"}"
	aliveWord="${aliveWord%%[[:space:]]*}"
	case "${aliveWord##*/}" in AgentsRunTests.sh|AgentsRunExecute.sh) return 0 ;; esac
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
AgentsRunOwnSession(){ ## -- the run that stands in the line, as its ticket names it: this run's own id, or `none`
	printf '%s' "${MDAT_SPAWN_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-none}}"
}
## A RUN'S PLACE IS ITS SESSION'S, NOT A PROCESS'S (S10.29). A ticket names the run that took it, `session=<id>`,
## never a process id: a number is given to another process, and a ticket naming one reads alive when its owner has
## long ended. A place gives up when this workspace's records say its run has ended, when the run has held the line
## past MDAT_SUITE_QUEUE_HOLD_SECONDS, and when a waiting run's beat -- written at each pass of its wait -- has stood
## still past MDAT_SUITE_QUEUE_STALL_SECONDS.
AgentsRunSessionEnded(){ ## session -- rc 0 where this workspace's records say that run has ended
	local endSession="$1" endRecord endLine endFront endStatus endSeen="" endStarted=""
	case "$endSession" in ''|none|.|..|*/*) return 1 ;; esac
	for endRecord in "$MMDAPP"/.local/agents/spawned/*/"$endSession.spawn.md" ; do
		[ -f "$endRecord" ] || continue
		endSeen=1 ; endFront="" ; endStatus=""
		while IFS= read -r endLine ; do
			case "$endFront:$endLine" in
				':---') endFront=1 ;;
				'1:---') break ;;
				'1:status: '*) [ -n "$endStatus" ] || endStatus="${endLine#status: }" ;;
			esac
		done < "$endRecord"
		case "$endStatus" in
			spawn-started) endStarted=1 ;;
			spawn-succeeded|spawn-failed|spawn-ended-without-close) return 0 ;;
		esac
	done
	[ -z "$endStarted" ] || return 1
	[ -z "$endSeen" ] || return 1
	[ -e "$MMDAPP/.local/agents/sessions/$endSession/ended" ]
}
AgentsRunTicketState(){ ## ticket file, the lane holders now on one line (AgentsRunLaneHolders) -- `alive`, `own`, `gone`, `ended`, `held` or `stalled`
	local ticketSession="" ticketSince="" ticketStamp ticketClock ticketAge ticketBeat="" ticketPid="" ticketPstart="" ticketKind="" ticketKey ticketValue ticketLine
	local ticketHold=${MDAT_SUITE_QUEUE_HOLD_SECONDS:-21600} ticketStall=${MDAT_SUITE_QUEUE_STALL_SECONDS:-3600}
	case "$ticketHold" in ''|*[!0123456789]*) ticketHold=21600 ;; esac
	case "$ticketStall" in ''|*[!0123456789]*) ticketStall=3600 ;; esac
	## THE LINE'S OWN LOAD: every waiter judges every ticket ahead of it at every pass. Each judgement here is shell reads and
	## at most one process (the ps of a named pid), never a process per field (rigQueueTicketState holds the same rule).
	while IFS='=' read -r ticketKey ticketValue ; do
		case "$ticketKey" in
			session) [ -n "$ticketSession" ] || ticketSession="$ticketValue" ;;
			since) [ -n "$ticketSince" ] || ticketSince="$ticketValue" ;;
			pid) [ -n "$ticketPid" ] || ticketPid="$ticketValue" ;;
			kind) [ -n "$ticketKind" ] || ticketKind="$ticketValue" ;;
			pstart) [ -n "$ticketPstart" ] || ticketPstart="$ticketValue" ;;
		esac
	done 2> /dev/null < "$1"
	## A ticket with no session line was never written whole, and holds nobody's place.
	[ -n "$ticketSession" ] || { printf 'gone' ; return 0 ; }
	case "$ticketSession" in *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-]*) printf 'gone' ; return 0 ;; esac
	## This run's own ticket is no place ahead of it: its own session is written on it.
	[ "$ticketSession" != "$( AgentsRunOwnSession )" ] || { printf 'own' ; return 0 ; }
	## The round's clock, set once per pass by the waiting loop; a reader called alone takes its own.
	ticketClock="${runQueueClock:-}"
	case "$ticketClock" in ''|*[!0123456789]*) ticketClock="$( date +%s )" || { printf 'alive' ; return 0 ; } ;; esac
	## A ticket that names a run is given up when this workspace's records say that run has ended. One naming `none`, a run
	## the tooling gave no id, has no record to read, and is judged by its own age and beat below.
	if [ "$ticketSession" != none ] ; then
		AgentsRunSessionEnded "$ticketSession" && { printf 'ended' ; return 0 ; }
	fi
	## THE HOLD LIMIT FIRST, from the second the ticket joined the line: the first field of its name, `<epoch>.<micro>.<pid>.ticket`,
	## zero-padded and so read in base ten (a leading zero is octal to the shell), with no process; a name that carries no epoch (a
	## ticket made by hand) is dated by its `since`, one date process. A place held past the limit is given up, beating or not.
	ticketStamp="${1##*/}" ; ticketStamp="${ticketStamp#0[abc]-}" ; ticketStamp="${ticketStamp%%.*}"
	case "$ticketStamp" in ''|*[!0123456789]*) ticketStamp="" ;; *) ticketStamp="$(( 10#$ticketStamp ))" ; [ "$ticketStamp" -ge 1000000000 ] || ticketStamp="" ;; esac
	[ -n "$ticketStamp" ] || [ -z "$ticketSince" ] || ticketStamp="$( date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$ticketSince" '+%s' 2> /dev/null || date -u -d "$ticketSince" '+%s' 2> /dev/null )" || ticketStamp=""
	case "$ticketStamp" in
		''|*[!0123456789]*) ticketStamp="" ;;
		*) ticketAge=$(( ticketClock - ticketStamp )) ; [ "$ticketAge" -le "$ticketHold" ] || { printf 'held' ; return 0 ; } ;;
	esac
	## The beat is the second of the last pass of a waiter's loop (its last line, where an older file holds several). A beat
	## within the last two minutes is a waiter alive at its loop: nothing else is read for it, and no process is spent on it.
	[ ! -f "$1.beat" ] || while read -r ticketLine ; do ticketBeat="$ticketLine" ; done 2> /dev/null < "$1.beat"
	case "$ticketBeat" in ''|*[!0123456789]*) ticketBeat="" ;; *) [ "$(( ticketClock - ticketBeat ))" -gt 120 ] || { printf 'alive' ; return 0 ; } ;; esac
	## A ticket that names its process is given up where that process is gone, or where the number now belongs to a process
	## that started at another moment: a run that died at work frees the line at once.
	if [ -n "$ticketPid" ] && [ -n "$ticketPstart" ] ; then
		[ "$( ps -o lstart= -p "$ticketPid" 2> /dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ //;s/ $//' )" = "$ticketPstart" ] || { printf 'gone' ; return 0 ; }
	fi
	## A run holding one of the machine's lanes is running and not waiting: its lane's own holder record says it is there.
	[ "$ticketKind" != check ] || ticketPid=""
	! AgentsRunTicketHoldsLane "$ticketPid" "$ticketSession" "${2:-}" || { printf 'alive' ; return 0 ; }
	## A run that stopped waiting gives up the place a process alone would go on holding. A ticket with no beat at all
	## carries no evidence that its holder stopped, so the hold limit above alone judges it.
	[ -n "$ticketBeat" ] || { printf 'alive' ; return 0 ; }
	[ "$(( ticketClock - ticketBeat ))" -le "$ticketStall" ] && printf 'alive' || printf 'stalled'
}

AgentsRunDescribeTicket(){ ## ticket file -- that place named as its own ticket names it: its session, the copy it runs from and how long it has held
	local describeSession describeKind describeOrigin describeSince describeStamp describeClock describeAge describeFrom describeRunDir describeLine describeAll=0 describeDone=0 describeDoing=""
	describeSession="$( LC_ALL=C sed -n 's/^session=//p' "$1" 2>/dev/null | LC_ALL=C sed -n 1p )"
	describeKind="$( LC_ALL=C sed -n 's/^kind=//p' "$1" 2>/dev/null | LC_ALL=C sed -n 1p )"
	describeOrigin="$( LC_ALL=C sed -n 's/^origin=//p' "$1" 2>/dev/null | LC_ALL=C sed -n 1p )"
	describeSince="$( LC_ALL=C sed -n 's/^since=//p' "$1" 2>/dev/null | LC_ALL=C sed -n 1p )"
	describeStamp="$( date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$describeSince" '+%s' 2>/dev/null || date -u -d "$describeSince" '+%s' 2>/dev/null )" || describeStamp=""
	describeClock="$( date +%s )" || describeClock=0
	describeFrom="" ; [ -z "$describeOrigin" ] || describeFrom=" from $describeOrigin"
	## the age is made in a variable: a `case` inside `$( )` ends at its own first `)`, so it cannot be written there
	describeAge="an unreadable while"
	case "$describeStamp" in
		''|*[!0123456789]*) ;;
		*) if [ "$describeClock" -ge "$describeStamp" ] ; then describeAge="$(( describeClock - describeStamp ))s" ; else describeAge="no time yet" ; fi ;;
	esac
	## a run at work says how far it is, after its age, so the waiter's "whom changed" test passes over it as it does over the age
	describeRunDir="$( LC_ALL=C sed -n 's/^rundir=//p' "$1" 2>/dev/null | LC_ALL=C sed -n 1p )"
	if [ -n "$describeRunDir" ] && [ -f "$describeRunDir/tests.list" ] ; then
		while IFS= read -r describeLine ; do describeAll=$(( describeAll + 1 )) ; done < "$describeRunDir/tests.list"
		[ ! -f "$describeRunDir/progress.txt" ] || while IFS= read -r describeLine ; do case "$describeLine" in PASS*|FAIL*) describeDone=$(( describeDone + 1 )) ;; esac ; done < "$describeRunDir/progress.txt"
		describeDoing=", running: $describeDone of $describeAll checks done"
		[ ! -f "$1.yield" ] || describeDoing=", its lanes given up between two checks: $describeDone of $describeAll checks done"
	fi
	printf 'the %s of session %s%s, in the line for %s%s' \
		"$( [ "$describeKind" = check ] && printf 'check' || printf 'run' )" \
		"${describeSession:-nobody}" "$describeFrom" "$describeAge" "$describeDoing"
}
AgentsRunQueueLeave(){ ## -- out of the line, and every lane this run took given back
	local leaveLane
	[ -z "$runTicket" ] || rm -f "$runQueueDir/$runTicket" "$runQueueDir/$runTicket.beat" "$runQueueDir/$runTicket.yield"
	## a lane given up between two checks may be another run's by now: only one this runner still holds goes back
	for leaveLane in 1 "$runLaneDir"/lane.* ; do
		leaveLane="${leaveLane##*/lane.}"
		case "$leaveLane" in ''|*[!0123456789]*) continue ;; esac
		[ "$( AgentsRunLaneHolder "$leaveLane" )" != "$$" ] || AgentsRunLaneGive "$leaveLane"
	done
	runTicket="" runLockMine="" runLaneMine=""
}
## THE PACE A TOOL CALL FINDS NOW, and the lanes it buys (HOW MANY RUNS STAND BESIDE EACH OTHER, above): the schedule's pace line, read from the
## file each rig keeps it in (`<epoch> <window> <median ms> <calls>`) and never taken here, since taking it walks the whole `spawned/` tree.
AgentsRunLaneCount(){ ## -- one line: how many runs may stand beside each other now, then why
	local laneMax laneFixed laneRig laneAt laneHeld laneMedian laneAge laneBestAge="" laneBestRig="" laneBestMedian="" laneBestHeld=""
	local laneTtl="${MDAT_TOOL_PACE_CACHE_SECONDS:-60}" laneLimit="${MDAT_TOOL_PACE_MS:-4000}" laneNow="$( date +%s )"
	laneMax="$( LC_ALL=C sed -n 1p "$runLaneDir/max" 2>/dev/null )"
	case "$laneMax" in ''|*[!0123456789]*) laneMax="${MDAT_SUITE_LANES:-3}" ;; esac
	case "$laneMax" in ''|*[!0123456789]*) laneMax=3 ;; esac
	[ "$laneMax" -ge 1 ] || laneMax=1
	## A machine whose lane count is set by hand keeps it, as a machine sets its budget of test workers by hand. That is
	## how a rig of a check fixes the count, so nothing of it waits on the pace.
	laneFixed="$( LC_ALL=C sed -n 1p "$runLaneDir/count" 2>/dev/null )"
	case "$laneFixed" in
		''|*[!0123456789]*) ;;
		*) [ "$laneFixed" -ge 1 ] || laneFixed=1 ; [ "$laneFixed" -le "$laneMax" ] || laneFixed="$laneMax" ; printf '%s set by hand in %s/count\n' "$laneFixed" "$runLaneDir" ; return 0 ;;
	esac
	case "$laneTtl" in ''|*[!0123456789]*) laneTtl=60 ;; esac
	case "$laneLimit" in ''|*[!0123456789]*|0) laneLimit=4000 ;; esac
	type AgentsToolsSuperviseRigs > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/supervise/AgentsTools.SuperviseRigs.include" || {
		echo "⛔ ERROR: AgentsRunTests.sh: the rigs of the machine cannot be named, AgentsTools.SuperviseRigs.include does not load" >&2 ; printf '1 the rigs cannot be named\n' ; return 0
	}
	## The freshest measure of the rigs --flags names, the one a measure younger than its own TTL: an older one, or none, is too little to judge.
	while IFS=$'\t' read -r laneRig _ ; do
		{ read -r laneAt _ laneMedian laneHeld < "$laneRig/.local/agents/schedule/pace.measure" ; } 2> /dev/null || continue
		case "$laneAt" in ''|*[!0123456789]*) continue ;; esac
		case "$laneHeld" in ''|*[!0123456789]*) continue ;; esac
		case "$laneMedian" in ''|*[!0123456789]*) laneHeld=0 ;; esac
		laneAge=$(( laneNow - laneAt ))
		[ "$laneAge" -ge 0 ] && [ "$laneAge" -lt "$laneTtl" ] || continue
		[ -z "$laneBestAge" ] || [ "$laneAge" -lt "$laneBestAge" ] || continue
		laneBestAge="$laneAge" laneBestRig="$laneRig" laneBestMedian="$laneMedian" laneBestHeld="$laneHeld"
	done <<< "$( AgentsToolsSuperviseRigs "$MMDAPP" 2> /dev/null )"
	if [ -z "$laneBestRig" ] ; then
		printf '%s no pace measure of a rig is under %ss old, too little to judge\n' "$laneMax" "$laneTtl"
	elif [ "$laneBestHeld" -lt 3 ] ; then
		printf '%s pace of %s, %ss old: %s calls in its window, too few to judge\n' "$laneMax" "${laneBestRig##*/}" "$laneBestAge" "$laneBestHeld"
	elif [ "$laneBestMedian" -lt "$laneLimit" ] ; then
		printf '%s pace of %s, %ss old: median %s ms machinery a call over %s calls, under the %s ms gate\n' "$laneMax" "${laneBestRig##*/}" "$laneBestAge" "$laneBestMedian" "$laneBestHeld" "$laneLimit"
	else
		printf '1 pace of %s, %ss old: median %s ms machinery a call over %s calls, at or over the %s ms gate\n' "${laneBestRig##*/}" "$laneBestAge" "$laneBestMedian" "$laneBestHeld" "$laneLimit"
	fi
}
AgentsRunLaneReport(){ ## -- the lane this run holds, of how many stood open when its turn came, and which other runs hold the rest
	local reportEach reportUsed=0
	for reportEach in $runLaneMine ; do reportUsed=$(( reportUsed + 1 )) ; done
	printf 'running in %s lane(s) of the %s open at its turn, holding %s%s\n' \
		"${reportUsed:-0}" "$runLaneCountNow" "${runLaneMine# }" "$( [ -z "$runLaneAlone" ] || printf ', the machine to itself for a test that measures its own timing' )"
}
AgentsRunLaneSession(){ ## lane number -- the session written in that lane, or nothing
	case "$1" in
		1) LC_ALL=C sed -n 's/^session=//p' "$runHandLock/holder.txt" 2>/dev/null | LC_ALL=C sed -n 1p ;;
		*) LC_ALL=C sed -n 's/^session=//p' "$runLaneDir/lane.$1/pid" 2>/dev/null | LC_ALL=C sed -n 1p ;;
	esac
}
AgentsRunLaneHolder(){ ## lane number -- the pid written in that lane, or nothing: what a lane is judged alive by
	case "$1" in
		1) LC_ALL=C sed -n 's/^runner-pid: //p' "$runHandLock/holder.txt" 2>/dev/null | LC_ALL=C sed -n 1p ;;
		*) LC_ALL=C sed -n 's/^pid=//p' "$runLaneDir/lane.$1/pid" 2>/dev/null | LC_ALL=C sed -n 1p ;;
	esac
}
AgentsRunLaneGive(){ ## lane number -- gives one lane back, whatever state its holder left it in
	case "$1" in
		1) rm -f "$runHandLock/holder.txt" ; rmdir "$runHandLock" 2>/dev/null ;;
		*) rm -f "$runLaneDir/lane.$1/pid" ; rmdir "$runLaneDir/lane.$1" 2>/dev/null ;;
	esac
	return 0
}
## A LANE WHOSE HOLDER IS GONE IS GIVEN BACK AT EVERY READ, BY WHOEVER ASKS NEXT, so no lane is held by the dead. So is one
## whose holder lives while its work is done (A LANE IS WHAT A RUN HOLDS, above). Lane 1 IS the hand rule's lock, so a lock
## taken by hand -- one with no runner-pid in it -- is held by a live session and is never given back here.
AgentsRunLaneFree(){ ## lane number -- rc 0 while that lane may be taken (its holder has ended, or its run is past its last check)
	local laneHeld laneDir laneChecks laneKey laneValue laneLine laneSession laneFile laneRecord
	local laneTicketSession laneTicketPid laneCount laneHave laneName laneRest
	case "$1" in
		1) [ -d "$runHandLock" ] || return 0 ; laneRecord="$runHandLock/holder.txt" ;;
		*) [ -d "$runLaneDir/lane.$1" ] || return 0 ; laneRecord="$runLaneDir/lane.$1/pid" ;;
	esac
	## A LANE'S RECORD IS READ BY THE SHELL ALONE: every waiter reads it at every pass, so no field costs a process. Its
	## fields are written in the forms the record carries them: lane 1 with `runner-pid: ` and a numbered lane with `pid=`.
	laneHeld="" laneDir="" laneChecks=0
	while IFS= read -r laneLine ; do
		case "$laneLine" in
			'runner-pid: '*) [ -n "$laneHeld" ] || laneHeld="${laneLine#runner-pid: }" ;;
			'pid='*) [ -n "$laneHeld" ] || laneHeld="${laneLine#pid=}" ;;
			'rundir='*) [ -n "$laneDir" ] || laneDir="${laneLine#rundir=}" ;;
			'checks='*) case "${laneLine#checks=}" in ''|*[!0123456789]*) ;; *) laneChecks="${laneLine#checks=}" ;; esac ;;
		esac
	done 2> /dev/null < "$laneRecord"
	## a lock taken by hand, one with no runner-pid in it, is a live session's and is never given back here
	[ -n "$laneHeld" ] || return 1
	case "$laneHeld" in
		*[!0123456789]*) AgentsRunLaneGive "$1" ; return 0 ;;
	esac
	[ "$laneHeld" != "$$" ] || return 1
	## A RUN WHOSE FOLDER HOLDS A RECEIPT FOR EVERY CHECK IT TOOK THE LANE TO RUN IS PAST ITS LAST CHECK, whatever its
	## process is doing: nothing of it will ever write another receipt. The count is the run's own, on its lane's record as
	## `checks=`; a record naming a folder and no count is judged by the checks its list names. A record naming no folder
	## keeps the lane.
	if [ -n "$laneDir" ] ; then
		if [ "$laneChecks" -le 0 ] && [ -r "$laneDir/tests.list" ] ; then
			while read -r laneName laneRest || [ -n "$laneName" ] ; do
				[ -n "$laneName" ] || continue
				laneChecks=$(( laneChecks + 1 ))
				laneName=""
			done < "$laneDir/tests.list"
		fi
		laneHave=0
		for laneName in "$laneDir"/*.receipt ; do [ ! -e "$laneName" ] || laneHave=$(( laneHave + 1 )) ; done
		if [ "$laneChecks" -gt 0 ] && [ "$laneHave" -ge "$laneChecks" ] ; then
			laneSession="$( AgentsRunLaneSession "$1" )"
			echo "# AgentsRunTests.sh: gave lane $1 back: the run that left the lock, session ${laneSession:-nobody}, is past its last check -- its run folder $laneDir holds a receipt for all $laneChecks of its checks" >&2
			AgentsRunLaneGive "$1"
			## ITS PLACE IN THE LINE GOES WITH ITS LANE: a ticket of that same run is no place ahead of anyone, and a waiter
			## left standing behind it would wait its whole bound for a turn that never comes.
			for laneFile in "$runQueueDir"/*.ticket ; do
				[ -f "$laneFile" ] || continue
				[ "${laneFile##*/}" != "$runTicket" ] || continue
				laneTicketSession="" laneTicketPid=""
				while IFS='=' read -r laneKey laneValue ; do
					case "$laneKey" in
						session) [ -n "$laneTicketSession" ] || laneTicketSession="$laneValue" ;;
						pid) [ -n "$laneTicketPid" ] || laneTicketPid="$laneValue" ;;
					esac
				done 2> /dev/null < "$laneFile"
				case "$laneSession" in
					''|none) case "$laneTicketPid" in "$laneHeld") rm -f "$laneFile" "$laneFile.beat" "$laneFile.yield" ;; esac ;;
					*) [ "$laneTicketSession" != "$laneSession" ] || rm -f "$laneFile" "$laneFile.beat" "$laneFile.yield" ;;
				esac
			done
			return 0
		fi
	fi
	AgentsRunRunnerAlive "$laneHeld" && return 1
	AgentsRunLaneGive "$1"
	return 0
}
AgentsRunLaneTake(){ ## lane number -- takes that lane whole or not at all; rc 1 where another has just taken it
	case "$1" in
		1)
			mkdir "$runHandLock" 2>/dev/null || return 1
			runLockMine=1
			printf 'runner-pid: %s\nsession=%s\nagent: AgentsRunTests.sh, a run from %s\nlanes: yes\ntaken: %s\n' "$$" "$( AgentsRunOwnSession )" "$MDLT_ORIGIN" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$runHandLock/holder.txt" 2>/dev/null
			## THE CHECKS THIS RUN TOOK THE LANE TO RUN, AND THE FOLDER THEY GO IN, GO ON THE LOCK WHEN THEY ARE KNOWN: a
			## run that takes lane 1 back after a yield writes the lock afresh, and a lock without them would never be judged.
			case "${runChecks:-}" in
				''|*[!0123456789]*) ;;
				*) printf 'checks=%s\n' "$runChecks" >> "$runHandLock/holder.txt" 2>/dev/null ;;
			esac
			[ -z "$runDir" ] || printf 'rundir=%s\n' "$runDir" >> "$runHandLock/holder.txt" 2>/dev/null
		;;
		*)
			mkdir -p "$runLaneDir" 2>/dev/null || return 1
			mkdir "$runLaneDir/lane.$1" 2>/dev/null || return 1
			printf 'pid=%s\nrunner-pid: %s\nsession=%s\norigin=%s\ntaken: %s\n' "$$" "$$" "$( AgentsRunOwnSession )" "$MDLT_ORIGIN" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$runLaneDir/lane.$1/pid" 2>/dev/null
			## A NUMBERED LANE NAMES THE FOLDER AND THE COUNT THE SAME WAY LANE 1 DOES, so a lane whose work is done is given
			## back before its holder ends, whichever lane it is. A run that takes one back after a yield writes it afresh.
			case "${runChecks:-}" in
				''|*[!0123456789]*) ;;
				*) printf 'checks=%s\n' "$runChecks" >> "$runLaneDir/lane.$1/pid" 2>/dev/null ;;
			esac
			[ -z "$runDir" ] || printf 'rundir=%s\n' "$runDir" >> "$runLaneDir/lane.$1/pid" 2>/dev/null
		;;
	esac
	runLaneMine="$runLaneMine $1"
	return 0
}
## A test that measures its own timing says `## lane: alone` in its header: it takes every lane, so nothing of any
## other run is busy beside it. Read from the header alone, never from the body.
AgentsRunAloneWanted(){ ## test name... -- rc 0 where one of them asks for the machine to itself
	local aloneTest alonePath
	for aloneTest in "$@" ; do
		alonePath="$( AgentsRunTestPath "$aloneTest" )"
		[ -f "$alonePath" ] || continue
		LC_ALL=C sed -n '1,40s/^## lane: alone[[:space:]]*$/alone/p' "$alonePath" 2>/dev/null | LC_ALL=C grep -q alone && return 0
	done
	return 1
}
## A LANE IS ITS RUN'S OWN: runs of one session are several runs, so a run ticket holds a lane only by its own pid. A check's ticket, whose
## run holds the lane, and a ticket that names no process, as a runner copy from before the lanes writes it, go by their session.
AgentsRunTicketHoldsLane(){ ## the ticket's pid (empty for a check's, or one that names none), its session, the lane holders on one line -- rc 0 where a lane is that run's
	if [ -n "$1" ] ; then
		case " $3 " in *" pid=$1 "*) return 0 ;; esac
		return 1
	fi
	case "$2" in ''|none) return 1 ;; esac
	case " $3 " in *" session=$2 "*) return 0 ;; esac
	return 1
}
## Every lane there is, never only those the count reads now: a run took its lane under the count of its turn, and a lower
## count since must not make it read as a run with no lane, which every waiter behind it would then stand behind.
AgentsRunLaneHolders(){ ## -- the runs holding a lane now, `pid=<pid> session=<session>` a lane, on one line, a dead one given back as it is read
	local holderLane holderLine=""
	for holderLane in 1 "$runLaneDir"/lane.* ; do
		holderLane="${holderLane##*/lane.}"
		case "$holderLane" in ''|*[!0123456789]*) continue ;; esac
		if ! AgentsRunLaneFree "$holderLane" ; then
			holderLine="$holderLine pid=$( AgentsRunLaneHolder "$holderLane" ) session=$( AgentsRunLaneSession "$holderLane" )"
		fi
	done
	printf '%s' "$holderLine"
}
AgentsRunLaneFreeOne(){ ## lanes to try -- the first free lane number, or nothing where every lane is held
	local freeLane=1
	while [ "$freeLane" -le "$1" ] ; do
		AgentsRunLaneFree "$freeLane" && { printf '%s\n' "$freeLane" ; return 0 ; }
		freeLane=$(( freeLane + 1 ))
	done
	return 1
}
## A lock taken by hand -- the hand rule's own shape, a note and no runner-pid -- is a live session's, shuts every
## lane, and is never given back by a runner. So does the lock of a runner from before the lanes: it writes no
## `lanes: yes` line, and a run of this runner may not stand beside it, since that run would not see this one's lanes.
AgentsRunHandLockByHand(){ ## -- rc 0 where the hand lock stands and no run holding it reads the lanes
	[ -d "$runHandLock" ] || return 1
	LC_ALL=C grep -q '^runner-pid: ' "$runHandLock"/* 2>/dev/null || return 0
	LC_ALL=C grep -q '^lanes: yes' "$runHandLock"/* 2>/dev/null && return 1
	return 0
}
## A run a session starts keeps its folder in that session's output folder, beside its own files, and a run
## with no session keeps the workspace's .local/temp. The rule stands here as well as at the tooling's own
## sites because a runner copied alone into a rig cannot reach sh-lib.
AgentsRunFolderMake(){ ## -- makes this run's folder, runDir, points latest at it, and writes it on the ticket
	local folderRoot="$MMDAPP/.local/temp/mdat-tests"
	[ -z "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] || folderRoot="$MDAT_SPAWN_SANDBOX_ROOT/output/mdat-tests"
	runDir="$folderRoot/$( date -u +%Y%m%dT%H%M%SZ )"
	## A folder of its own: a run started in the same second as another takes its pid into the name,
	## since two runs in one folder would each run the other's list and overwrite its logs.
	mkdir -p "$folderRoot" 2>/dev/null
	mkdir "$runDir" 2>/dev/null || { runDir="$runDir-$$" ; mkdir -p "$runDir" ; } || { echo "⛔ ERROR: AgentsRunTests.sh: cannot create $runDir" >&2 ; exit 1 ; }
	ln -sfn "$runDir" "$folderRoot/latest" 2>/dev/null || :
	## the run folder on the ticket, so a waiter says how many of its checks are done
	[ -z "$runTicket" ] || printf 'rundir=%s\n' "$runDir" >> "$runQueueDir/$runTicket" 2>/dev/null || :
}
AgentsRunQueueTurn(){ ## -- stands in the line, takes a lane at this run's turn, and returns; says whom it waits behind, each time that changes
	local turnStamp turnFile turnSession turnState turnWhom="" turnWho="" turnHeldWhom="" turnAhead=0 turnSaid="" turnBegan turnWaited runQueueClock="" turnSleep
	local turnHolders turnLane turnRound=0 turnRecount=0 turnChild turnTries turnAdopted="$runTicket" turnKey turnValue turnPid turnKind
	## A RUN NEVER STANDS IN THE LINE PAST ITS BOUND. A run that has waited MDAT_SUITE_QUEUE_LIMIT seconds -- 900 unless
	## the machine sets it, and 3600 for a run left detached, since nobody waits on it -- says in one line whom it waits behind and refuses: it runs nothing outside its turn, and its
	## ticket goes, so the runs behind it are not held by it. Two runs waited half an hour on 2026-11-03 before a person
	## ended them; a run below a person's patience is worth more than a run that never says anything.
	turnBegan="$( date +%s )"
	turnWaited=0
	case "${MDAT_SUITE_QUEUE_LIMIT:-900}" in ''|*[!0123456789]*) turnWaited=900 ;; *) turnWaited="${MDAT_SUITE_QUEUE_LIMIT:-900}" ;; esac
	mkdir -p "$runQueueDir" 2>/dev/null || {
		echo "⛔ ERROR: AgentsRunTests.sh: cannot create the machine's line of test runs: $runQueueDir -- no run is started outside its turn" >&2 ; exit 1
	}
	mkdir -p "$MMDAPP/.local/temp" 2>/dev/null || {
		echo "⛔ ERROR: AgentsRunTests.sh: cannot create $MMDAPP/.local/temp, the folder of the lock a run takes at its turn" >&2 ; exit 1
	}
	turnStamp="$( python3 -I -B -c 'import time; print("%017.6f" % time.time(), end="")' 2>/dev/null )" || turnStamp=""
	[ -n "$turnStamp" ] || turnStamp="$( date +%s ).000000"
	## A HIGHER TIER IS SERVED FIRST: the task's tier (S16 stage 4, `mark:` of its item: emergency, urgent, important), given as
	## MDAT_SUITE_TIER, names the ticket with a prefix that sorts before every stamp, emergency before urgent before important, so the
	## line's own order by name serves it first, with no read added to a waiter's pass. Runs of one tier keep their arrival order.
	## THE TIER DEFAULTS TO THE CONTEXT TASK'S: the item this run's session works, as its spawn record names it, and that item's
	## `mark:`, read once here through the item reader. A given MDAT_SUITE_TIER wins; a run of no session, or of a task with no mark, is ordinary.
	if [ -z "${MDAT_SUITE_TIER:-}" ] ; then
		runTierSession="$( AgentsRunOwnSession )"
		case "$runTierSession" in
			''|none) ;;
			*)
				runTierItem="$( LC_ALL=C grep -m1 -oE '(task|dispatch)-[0-9]{8}T[0-9]{4}Z-[A-Za-z0-9.-]+\.md' "$MMDAPP/.local/agents/spawned/$runTierSession/$runTierSession.spawn.md" 2> /dev/null )" || runTierItem=""
				if [ -n "$runTierItem" ] && command -v DistroAgentsItems.fn.sh > /dev/null 2>&1 ; then
					MDAT_SUITE_TIER="$( DistroAgentsItems.fn.sh --get-board-item "$runTierItem" 2> /dev/null | LC_ALL=C sed -n 's/^mark: *//p' | LC_ALL=C sed -n 1p )" || MDAT_SUITE_TIER=""
				fi
			;;
		esac
	fi
	case "${MDAT_SUITE_TIER:-}" in emergency) runTierPrefix="0a-" ;; urgent) runTierPrefix="0b-" ;; important) runTierPrefix="0c-" ;; *) runTierPrefix="" ;; esac
	runTicket="${turnAdopted:-$runTierPrefix$turnStamp.$$.ticket}"
	trap AgentsRunQueueLeave EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM HUP
	if [ -n "$turnAdopted" ] ; then
		## A run that took its caller's ticket over (NOBODY SITS ON A WAIT, above) counts its bound from the second that ticket joined the line.
		turnBegan="${runTicket#0[abc]-}" ; turnBegan="$(( 10#${turnBegan%%.*} ))"
	else
		## whole or not at all: a ticket half written would read as one of no run. The pid and its start let a waiter judge a
		## run that died at work gone at once (rigQueueTicketState), where the hold limit alone kept its place for hours.
		printf 'session=%s\norigin=%s\nkind=run\nsince=%s\npid=%s\npstart=%s\n%s' "$( AgentsRunOwnSession )" "$MDLT_ORIGIN" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" "$$" "$( ps -o lstart= -p "$$" 2> /dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ //;s/ $//' )" "${runTierPrefix:+tier=$MDAT_SUITE_TIER
}" > "$runQueueDir/.$runTicket" \
			&& mv -f "$runQueueDir/.$runTicket" "$runQueueDir/$runTicket" || {
			echo "⛔ ERROR: AgentsRunTests.sh: cannot stand in the machine's line of test runs: $runQueueDir" >&2 ; exit 1
		}
	fi
	runLaneAlone=""
	AgentsRunAloneWanted "$@" && runLaneAlone=1
	read -r runLaneCountNow runLaneWhy <<< "$( AgentsRunLaneCount )"
	while : ; do
		turnWhom="" ; turnAhead=0 ; turnHeldWhom=""
		## one clock per pass, read by every judgement of it; the beat of this waiting ticket is that second, written over at every
		## pass, so a run that stopped waiting gives up its place while its session lives, and the beat file stays one line
		runQueueClock="$( date +%s )" || runQueueClock=""
		printf '%s\n' "$runQueueClock" > "$runQueueDir/$runTicket.beat" 2>/dev/null || :
		## A beat whose ticket is gone is a leftover nothing else removes: a waiter pruned while it lived rewrites it once more.
		for turnFile in "$runQueueDir"/*.ticket.beat "$runQueueDir"/*.ticket.yield ; do [ ! -f "$turnFile" ] || [ -f "${turnFile%.*}" ] || rm -f "$turnFile" ; done
		## The lanes are read at every pass, so a lane whose run died is given back here rather than held for ever.
		turnHolders="$( AgentsRunLaneHolders )"
		for turnFile in "$runQueueDir"/*.ticket ; do
			[ -f "$turnFile" ] || continue
			## The line ends at this run's own ticket: nothing behind it changes its turn.
			[ "${turnFile##*/}" != "$runTicket" ] || break
			[ "${turnFile##*/}" \< "$runTicket" ] || continue
			## Read in the shell: every waiter reads every ticket ahead of it at every pass, so a process here is paid waiters times tickets.
			turnSession="" turnPid="" turnKind=""
			while IFS='=' read -r turnKey turnValue ; do
				case "$turnKey" in
					session) [ -n "$turnSession" ] || turnSession="$turnValue" ;;
					pid) [ -n "$turnPid" ] || turnPid="$turnValue" ;;
					kind) [ -n "$turnKind" ] || turnKind="$turnValue" ;;
				esac
			done 2> /dev/null < "$turnFile"
			[ "$turnKind" != check ] || turnPid=""
			## A ticket of this run's own session -- a check running it, or a check of a check -- is the turn this run is
			## inside, and never a place ahead of it (AgentsRunTicketState). A ticket that names no session is nobody's.
			turnState="$( AgentsRunTicketState "$turnFile" "$turnHolders" )"
			case "$turnState" in
				own) continue ;;
				alive) ;;
				*) ## `gone`, `ended`, `held` and `stalled`: a place given up, taken out of the line here and said
					[ "$turnState" = gone ] || echo "# AgentsRunTests.sh: a place given up in the line, so this run stands no longer behind it: $( AgentsRunDescribeTicket "$turnFile" )" >&2
					rm -f "$turnFile" "$turnFile.beat" "$turnFile.yield" ; continue
				;;
			esac
			## A run that gave its lanes up between two checks is passed by until it takes them again.
			[ ! -f "$turnFile.yield" ] || continue
			## A ticket ahead that holds no lane is the head of the queue, and this run waits for it, so a run
			## that arrived first starts first. One already holding a lane is running, and this run may take
			## another lane beside it -- and where every lane is taken, the holder is named as well.
			if AgentsRunTicketHoldsLane "$turnPid" "$turnSession" "$turnHolders" ; then
				[ -n "$turnHeldWhom" ] || turnHeldWhom="$( AgentsRunDescribeTicket "$turnFile" )"
				continue
			fi
			turnAhead=$(( turnAhead + 1 ))
			[ -n "$turnWhom" ] || turnWhom="$( AgentsRunDescribeTicket "$turnFile" )"
		done
		## Taken by hand by this run's own caller: no turn of its own. With nobody ahead the
		## run's turn has come and it starts under that lock; with anyone ahead it is refused,
		## since each of them waits behind that lock and this run would wait behind them.
		if [ -d "$runHandLock" ] && AgentsRunHandLockOwn ; then
			[ "$turnAhead" != 0 ] || {
				## The caller holds the lock itself: the run starts under it and leaves it for the caller, so it takes no lane of its own and gives none back.
				MDAT_SUITE_QUEUE_TURN="$runQueueDir/$runTicket" ; export MDAT_SUITE_QUEUE_TURN
				return 0
			}
			echo "⛔ ERROR: AgentsRunTests.sh: not started: this run's caller holds $runHandLock by hand, and its turn in the machine's line has not come: $turnAhead run(s) stand ahead of it, the first $turnWhom. A lock taken by hand is no turn. Remove it and run again: the run waits its turn by itself, and takes the lock itself when that comes." >&2
			exit 1
		fi
		## The hand lock of any other session, taken by hand, shuts every lane: no run starts beside a session on the hand rule.
		if AgentsRunHandLockByHand ; then
			## A lock taken by hand and a lock of a runner from before the lanes say different things: the first is a
			## session's own rule, the second is a runner this one cannot share lanes with.
			if LC_ALL=C grep -q '^runner-pid: ' "$runHandLock"/* 2>/dev/null ; then
				turnWhom="the lock $runHandLock, held by a runner from before the lanes: $( AgentsRunHandLockNote ) -- it runs alone on the whole machine, and this one waits for it"
			else
				turnWhom="the lock $runHandLock, taken by hand and held by: $( AgentsRunHandLockNote ) -- where that was done for this very run, remove it: the run takes the turn itself"
			fi
		elif [ -z "$turnWhom" ] ; then
			if [ -n "$runLaneAlone" ] ; then
				## A test that measures its own timing takes every lane, so nothing of any other run is busy beside it.
				## Every lane is looked at first and then taken one at a time; a lane another run takes in between gives
				## back what this run had, and it waits as any run does.
				turnLane="" ; turnRound=1
				while [ "$turnRound" -le "$runLaneCountNow" ] ; do
					AgentsRunLaneFree "$turnRound" || { turnLane="" ; break ; }
					turnLane="$turnRound" ; turnRound=$(( turnRound + 1 ))
				done
				if [ -n "$turnLane" ] ; then
					turnRound=1
					while [ "$turnRound" -le "$runLaneCountNow" ] ; do
						AgentsRunLaneTake "$turnRound" || break
						turnRound=$(( turnRound + 1 ))
					done
					if [ "$turnRound" -gt "$runLaneCountNow" ] ; then
						MDAT_SUITE_QUEUE_TURN="$runQueueDir/$runTicket" ; export MDAT_SUITE_QUEUE_TURN
						return 0
					fi
					for turnLane in $runLaneMine ; do AgentsRunLaneGive "$turnLane" ; done
					runLaneMine="" runLockMine=""
					turnWhom="a lane another run took as this one asked for every lane of the machine"
					turnLane=""
				fi
				[ -n "$turnWhom" ] || turnWhom="$turnHeldWhom"
				[ -n "$turnWhom" ] || turnWhom="another run holding one of $runLaneCountNow lane(s) of the machine"
				turnWhom="$turnWhom -- this run holds a test that measures its own timing, and such a test runs alone"
			else
				turnLane="$( AgentsRunLaneFreeOne "$runLaneCountNow" )"
				if [ -n "$turnLane" ] && AgentsRunLaneTake "$turnLane" ; then
					## The tests this run starts are inside its turn: they take no ticket of their own, so the run's own
					## workers still run as many tests at once as it was given (rig-temp.include.sh, rigQueueTurn).
					MDAT_SUITE_QUEUE_TURN="$runQueueDir/$runTicket" ; export MDAT_SUITE_QUEUE_TURN
					return 0
				fi
				## The run this one waits behind is the head of the queue, and where nobody is waiting for a lane, it is
				## the run that holds the lane this one needs.
				[ -n "$turnWhom" ] || turnWhom="${turnHeldWhom:-another run holding one of $runLaneCountNow lane(s) of the machine}"
			fi
		elif [ -n "$turnHeldWhom" ] && [ -z "$( AgentsRunLaneFreeOne "$runLaneCountNow" )" ] ; then
			## A head of the line ahead of it, and every lane held: what it waits for is a lane, so the run holding one is the run named.
			turnWhom="$turnHeldWhom"
		fi
		## said once each time whom it waits behind changes: the age is left out of that comparison, since it moves every pass
		turnWho="${turnWhom%, in the line for *}"
		if [ "$turnWho" != "$turnSaid" ] ; then
			echo "# AgentsRunTests.sh: $runLaneCountNow lane(s) of test runs on this machine ($runLaneWhy) -- this one waits its turn behind $turnWhom" >&2
			turnSaid="$turnWho"
		fi
		## NOBODY SITS ON A WAIT. A run that must wait, and was not given --wait, starts a run of itself detached, in a process group of
		## its own, which takes this very ticket over, so the line keeps its order. This call returns once that run has, and names where the
		## result will be: a tool call that started it is never held for a turn that may be an hour away.
		if [ -z "$runWait" ] ; then
			[ -n "$runDir" ] || AgentsRunFolderMake
			set -m
			MDAT_SUITE_QUEUE_ADOPT="$runTicket" MDAT_SUITE_TIER="${MDAT_SUITE_TIER:-}" MDAT_SUITE_QUEUE_LIMIT="${MDAT_SUITE_QUEUE_LIMIT:-3600}" nohup "$BASH" "$MDAT_SUITE_ENTRY" --wait ${runArgs[@]+"${runArgs[@]}"} > "$runDir/runner.log" 2>&1 < /dev/null &
			turnChild=$!
			set +m
			## Taken over while the run started lives, within a minute; its start-up before that is a bash start and one file write.
			turnTries=300
			while [ "$turnTries" -gt 0 ] && kill -0 "$turnChild" 2> /dev/null && ! LC_ALL=C grep -q -x "pid=$turnChild" "$runQueueDir/$runTicket" 2> /dev/null ; do sleep 0.2 ; turnTries=$(( turnTries - 1 )) ; done
			if LC_ALL=C grep -q -x "pid=$turnChild" "$runQueueDir/$runTicket" 2> /dev/null ; then
				printf '# AgentsRunTests.sh: queued and not waited on: this call returns now, and the run waits its turn detached, as pid %s, on ticket %s\n' "$turnChild" "$runQueueDir/$runTicket"
				printf '# AgentsRunTests.sh: read it later: %s/progress.txt as its checks end, %s/summary.txt once it has ended, %s/runner.log for its own lines\n' "$runDir" "$runDir" "$runDir"
				runTicket=""
				exit 75
			fi
			## Not taken over: the run started is ended, and once it has, this call waits its turn itself where the ticket still names it, so
			## the place is never left to nobody. A ticket that run took and then gave back on its way out is a place lost, and said so.
			kill -TERM -- "-$turnChild" 2> /dev/null || kill -TERM "$turnChild" 2> /dev/null || :
			wait "$turnChild" 2> /dev/null || :
			if ! LC_ALL=C grep -q -x "pid=$$" "$runQueueDir/$runTicket" 2> /dev/null ; then
				runTicket=""
				echo "⛔ ERROR: AgentsRunTests.sh: not started: the run started to wait detached took this run's ticket and ended, so its place in the machine's line is gone and nothing was run. Its own lines are in $runDir/runner.log. Run it again." >&2
				exit 1
			fi
			echo "# AgentsRunTests.sh: the run started to wait detached did not take this run's ticket over, so this call waits its turn itself" >&2
			runWait=1
		fi
		## Its bound passed: what it waits behind, and no run of it. The ticket is given back here, so nothing behind it
		## waits on a run that will never start.
		if [ "$(( $( date +%s ) - turnBegan ))" -ge "$turnWaited" ] ; then
			rm -f "$runQueueDir/$runTicket" "$runQueueDir/$runTicket.beat" 2> /dev/null ; runTicket=""
			echo "⛔ ERROR: AgentsRunTests.sh: not started: its turn in the machine's line had not come within ${turnWaited}s. It waited behind $turnWhom. Nothing was run, and no ticket is left in the line. Run it again, or set MDAT_SUITE_QUEUE_LIMIT higher where a longer wait is wanted." >&2
			exit 1
		fi
		## the lanes are read again now and then, so a machine that came to rest or grew busy widens or narrows them
		turnRecount=$(( turnRecount + 1 ))
		if [ "$turnRecount" -ge 15 ] ; then turnRecount=0 ; read -r runLaneCountNow runLaneWhy <<< "$( AgentsRunLaneCount )" ; fi
		## the pass is slower the longer the line: a run far back has nothing to gain from a quick look, and a long line looked
		## at quickly by every waiter is load on the very machine the line protects
		## A run more than 10 back cannot reach a lane for minutes, so it looks up to 90 s apart. Under 120 s, so its beat still reads fresh
		## to every other waiter, which then spends no `ps` on it (AgentsRunTicketState).
		turnSleep=$(( 5 + turnAhead * 3 ))
		if [ "$turnAhead" -le 10 ] ; then [ "$turnSleep" -le 30 ] || turnSleep=30 ; else [ "$turnSleep" -le 90 ] || turnSleep=90 ; fi
		sleep "$turnSleep"
	done
}
## THE FAILURES HAVE OWNERS. A red test of the suite is what a regression run cannot protect, so each one carries the
## member who owns it and the reason it is red, in a list beside this runner. THE LIST IS READ HERE, BEFORE ANY TEST
## RUNS, so a row that is not exactly three filled fields stops the run rather than letting a failure stand with no
## owner: a summary whose owners cannot be trusted is worth less than no run. A missing list is no error, since a rig
## holding the runner alone has none, and every failure then counts as unowned. Shell builtins alone read it, so a run
## of 843 tests pays no process for it.
runKnownFile="$testDir/known-failures.txt"
runKnownTab=$'\t'
runKnownDetail="" runKnownBad="" runKnownLine=0
if [ -f "$runKnownFile" ] ; then
	while IFS= read -r runKnownText ; do
		runKnownLine=$(( runKnownLine + 1 ))
		case "$runKnownText" in ''|'#'*) continue ;; esac
		case "$runKnownText" in *"$runKnownTab"*) ;; *) runKnownBad="$runKnownBad $runKnownLine" ; continue ;; esac
		runKnownTest="${runKnownText%%"$runKnownTab"*}" runKnownRest="${runKnownText#*"$runKnownTab"}"
		case "$runKnownRest" in *"$runKnownTab"*) ;; *) runKnownBad="$runKnownBad $runKnownLine" ; continue ;; esac
		runKnownOwner="${runKnownRest%%"$runKnownTab"*}" runKnownReason="${runKnownRest#*"$runKnownTab"}"
		case "$runKnownTest" in ''|*' '*) runKnownBad="$runKnownBad $runKnownLine" ; continue ;; esac
		case "$runKnownOwner$runKnownReason" in *"$runKnownTab"*|' ') runKnownBad="$runKnownBad $runKnownLine" ; continue ;; esac
		case "$runKnownOwner" in '') runKnownBad="$runKnownBad $runKnownLine" ; continue ;; esac
		case "$runKnownReason" in '') runKnownBad="$runKnownBad $runKnownLine" ; continue ;; esac
		runKnownDetail="$runKnownDetail$runKnownTest$runKnownTab$runKnownOwner$runKnownTab$runKnownReason"$'\n'
	done < "$runKnownFile"
fi
if [ -n "$runKnownBad" ] ; then
	echo "⛔ ERROR: AgentsRunTests.sh: $runKnownFile holds a row that is not three filled fields -- the test, its owner and the reason it is red, TAB between them; the line(s):$runKnownBad" >&2
	exit 1
fi
AgentsRunKnownOf(){ ## test name -- sets runKnown to ` owner=<owner> reason=<reason>`, or to nothing for a test the list does not hold
	local knownRest="$runKnownDetail" knownLine knownTest knownOwner knownReason
	runKnown=""
	while [ -n "$knownRest" ] ; do
		knownLine="${knownRest%%$'\n'*}"
		if [ "$knownLine" = "$knownRest" ] ; then knownRest="" ; else knownRest="${knownRest#*$'\n'}" ; fi
		knownTest="${knownLine%%"$runKnownTab"*}"
		if [ "$knownTest" = "$1" ] ; then
			knownLine="${knownLine#*"$runKnownTab"}"
			knownOwner="${knownLine%%"$runKnownTab"*}" knownReason="${knownLine#*"$runKnownTab"}"
			runKnown=" owner=$knownOwner reason=$knownReason" ; return 0
		fi
	done
	return 0
}

## Every run waits its turn, a run of named tests as the whole suite does (WAITING IN THE LINE, above).
AgentsRunQueueTurn $( AgentsRunNames "$@" )

## The run's folder, made at its turn, or already made where the run was queued and went on detached (NOBODY SITS ON A WAIT).
[ -n "$runDir" ] || AgentsRunFolderMake
## No test links a rig into source (epic S23.11): each finds a guard `ln` first on its PATH. A runner copied alone into a rig cannot reach sh-lib and runs with none.
if [ -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.SandboxLinks.include" ] ; then
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.SandboxLinks.include" && AgentsToolsLnGuardMake "$runDir/guard-bin" && PATH="$runDir/guard-bin:$PATH"
fi

runList="$runDir/tests.list"
AgentsRunNames "$@" | while IFS= read -r runName ; do
	printf '%s %s\n' "$runName" "$runTimeout"
done > "$runList"
runCount="$( grep -c . "$runList" )"
[ "$runCount" -gt 0 ] || { echo "⛔ ERROR: AgentsRunTests.sh: no test matches" >&2 ; exit 1 ; }
runChecks="$runCount"
## EVERY LANE THIS RUN HOLDS NAMES THE FOLDER AND THE COUNT ON ITS OWN RECORD, so a lane whose holder lives while its work is
## done is given back (AgentsRunLaneFree), by the count it was given rather than a list that may have been cut. Written here,
## where both are settled: a run that took its ticket over finds them already there, and a take after a yield writes them
## afresh itself.
for runLane in $runLaneMine ; do
	runLaneRecord="$runHandLock/holder.txt"
	case "$runLane" in 1) ;; *) runLaneRecord="$runLaneDir/lane.$runLane/pid" ;; esac
	[ -z "$( LC_ALL=C sed -n 's/^rundir=//p' "$runLaneRecord" 2>/dev/null )" ] || continue
	printf 'checks=%s\nrundir=%s\n' "$runCount" "$runDir" >> "$runLaneRecord" 2>/dev/null || :
done

AgentsRunOneTest(){ ## test name, timeout seconds -- one task line of the run list
	local oneName="$1" oneTimeout="${2:-$runTimeout}" oneStart oneEnd oneRc=0 oneLast onePid oneEnded=""
	oneStart="$( date +%s )"
	## The test's own process asks for its worker slot, waits for it, and only then becomes
	## the test (the slot keeper, above); fd 8 is this runner's own output, for the one line
	## it says while a test waits, and the test never sees it.
	(
		## nothing of the session this runner was started in reaches the test (the test-only identity, above).
		## MDAT_TEAM_MEMBER is the one more name AgentsToolsTeamMember falls to, past MDAT_SPAWN_AGENT: a test
		## that needs a member sets its own, as the rigs already do.
		unset ${!MDAT_SPAWN_@} ${!MDAT_SESSION_@} MDAT_CONVERSATION_THREADS harnessSessionId harnessAgent MDAT_TEAM_MEMBER
		export MDAT_SKILLSET_ROOT="$runMembers"
		export CLAUDE_CODE_SESSION_ID="rig-run-$oneName-test-only"
		export MDAT_WAIT_REMIND=off
		export MDAT_COMMS_READER=off
		export MDAT_COLLECT_THREAD=off
		export MDAT_TEAM_DATA_COMMIT_THREAD=off
		export MDAT_SCHEDULE_THREAD=off
		export MDAT_WORKSPACE_MODE=team-rig
		cd "$testDir" || exit 1
		exec python3 -I -B "$runSlotKeeper" take "$runSlotDir" "$runSlotDefault" 8 "$runDir/slot-wait.said" "$runDir/$oneName.started" "$runTestLock" "$runOwnFolder" "$oneTimeout" "$BASH" "$( AgentsRunTestPath "$oneName" )"
	) 8>&2 > "$runDir/$oneName.log" 2>&1 3>&- 4>&- &
	onePid=$!
	## THE CHECK'S OWN TREES ARE MARKED BY ITS START: what it makes after this mark, named after it, is its own to remove.
	: > "$runDir/$oneName.begin" 2> /dev/null || :
	wait "$onePid" || oneRc=$?
	python3 -I -B "$runSlotKeeper" give "$runSlotDir" "$onePid" 2>/dev/null || :
	## its time is counted from when it got its slot, not from when it asked
	[ ! -s "$runDir/$oneName.started" ] || IFS= read -r oneStart < "$runDir/$oneName.started"
	rm -f "$runDir/$oneName.started"
	oneEnd="$( date +%s )"
	oneLast="$( grep . "$runDir/$oneName.log" | tail -n 1 )"
	## A TEST ENDED AT ITS TIME LIMIT SAYS SO, in its receipt, its FAIL line and the summary (S6.47): the exit status
	## 128+ALRM it ends on is a number a reader has to decode, and the last line it printed can be any word at all.
	oneEnded=""
	[ ! -s "$runDir/$oneName.started.limit" ] || oneEnded="$( head -1 "$runDir/$oneName.started.limit" 2> /dev/null )"
	rm -f "$runDir/$oneName.started.limit"
	printf 'rc=%s\nseconds=%s\nlast=%s\n' "$oneRc" "$(( oneEnd - oneStart ))" "$oneLast" > "$runDir/$oneName.receipt"
	[ -z "$oneEnded" ] || printf 'ended-by=time-limit\n' >> "$runDir/$oneName.receipt"
	if [ "$oneRc" = 0 ] ; then
		## A PASSED CHECK LEAVES NO TREE BEHIND: its temp trees, named after it in the two places checks write (.local/temp and
		## .local/agents/scratch/sh-test) and made after its begin mark, are removed, unless a live process still names one, as a second copy
		## of the same check running beside it does. A failed check keeps its trees for reading.
		if [ -f "$runDir/$oneName.begin" ] ; then
			local cleanProcs cleanEntry
			cleanProcs="$( ps -axo command= 2> /dev/null )"
			while IFS= read -r cleanEntry ; do
				[ -n "$cleanEntry" ] || continue
				case "$cleanProcs" in *"${cleanEntry##*/}"*) continue ;; esac
				rm -rf -- "$cleanEntry" 2> /dev/null || :
			done <<< "$( find "${MMDAPP%/}/.local/temp" "${MMDAPP%/}/.local/agents/scratch/sh-test" -mindepth 1 -maxdepth 1 \( -name "$oneName.*" -o -name "$oneName-*" \) -newer "$runDir/$oneName.begin" 2> /dev/null )"
		fi
		printf 'PASS  %-48s %4ss  %s\n' "$oneName" "$(( oneEnd - oneStart ))" "$oneLast"
	else
		printf 'FAIL  %-48s %4ss  rc=%s  %s%s\n' "$oneName" "$(( oneEnd - oneStart ))" "$oneRc" "${oneEnded:+$oneEnded -- }" "$oneLast"
	fi
}

## The tickets behind this run's own that wait for its lanes, into runYieldWaiters one a line (A RUN GIVES ITS LANES UP, above): a
## check started by hand waits behind every ticket ahead of it, and a run only where no lane is free for it. With no ticket behind
## this run, the common case at a boundary, it is one glob of the line and no process.
AgentsRunYieldWaiters(){
	local yieldFile yieldKey yieldValue yieldSession yieldPid yieldKind yieldWon yieldHolders="" yieldFree=""
	runYieldWaiters=""
	[ -n "$runTicket" ] && [ -n "$runLaneMine" ] || return 0
	for yieldFile in "$runQueueDir"/*.ticket ; do
		[ -f "$yieldFile" ] || continue
		[ "${yieldFile##*/}" \> "$runTicket" ] || continue
		[ ! -f "$yieldFile.yield" ] || continue
		yieldSession="" yieldPid="" yieldKind="" yieldWon=""
		while IFS='=' read -r yieldKey yieldValue ; do
			case "$yieldKey" in
				session) [ -n "$yieldSession" ] || yieldSession="$yieldValue" ;;
				pid) [ -n "$yieldPid" ] || yieldPid="$yieldValue" ;;
				kind) [ -n "$yieldKind" ] || yieldKind="$yieldValue" ;;
				turn-won) [ -n "$yieldWon" ] || yieldWon="$yieldValue" ;;
			esac
		done 2> /dev/null < "$yieldFile"
		## a check that has won its turn is at work, and waits for nothing
		[ -z "$yieldWon" ] || continue
		[ -n "$yieldHolders" ] || yieldHolders="$( AgentsRunLaneHolders ) "
		[ "$( AgentsRunTicketState "$yieldFile" "$yieldHolders" )" = alive ] || continue
		if [ "$yieldKind" != check ] ; then
			! AgentsRunTicketHoldsLane "$yieldPid" "$yieldSession" "$yieldHolders" || continue
			[ -n "$yieldFree" ] || yieldFree="$( AgentsRunLaneFreeOne "$runLaneCountNow" || printf 'none' )"
			[ "$yieldFree" = none ] || continue
		fi
		runYieldWaiters="$runYieldWaiters$yieldFile"$'\n'
	done
	return 0
}
## The yield itself, by the one worker that marked the ticket: the checks in flight end (a check of the run list whose log has no
## receipt yet is one still running; no other file of the run folder is a check), the lanes go back, each ticket it yielded to is
## waited for until it holds a lane, has won its turn or is gone, the mark goes, and free lanes are taken again.
## EVERY WAIT HERE IS BOUNDED, each at runYieldBound: a wait with no bound kept a run alive past its own time limit for 21 h 50 m
## (A RUN THAT STANDS STILL, above). A wait that runs out goes on with the lanes the run has, and the run ends.
AgentsRunYieldGive(){
	local giveName giveRest giveBusy giveLane giveWaiter giveLanes="$runLaneMine" giveWant=0 giveHave=0 giveTry giveUntil giveHolders giveKey giveValue givePid giveSession giveKind giveWon
	giveUntil=$(( SECONDS + runYieldBound ))
	while [ "$SECONDS" -lt "$giveUntil" ] ; do
		giveBusy=""
		while read -r giveName giveRest ; do [ ! -f "$runDir/$giveName.log" ] || [ -f "$runDir/$giveName.receipt" ] || { giveBusy=1 ; break ; } ; done < "$runList"
		[ -n "$giveBusy" ] || break
		touch "$runList" 2> /dev/null || :
		sleep 1
	done
	for giveLane in $runLaneMine ; do [ "$( AgentsRunLaneHolder "$giveLane" )" != "$$" ] || AgentsRunLaneGive "$giveLane" ; done
	echo "# AgentsRunTests.sh: gave its lane(s)$runLaneMine back between two checks: $( printf '%s' "$runYieldWaiters" | LC_ALL=C grep -c . ) ticket(s) behind it wait for them" >&2
	## A waiter that took a lane may yield in its turn: waiting for it to end would hold this run back for the whole chain while a lane stands free.
	giveUntil=$(( SECONDS + runYieldBound ))
	while IFS= read -r giveWaiter ; do
		[ -n "$giveWaiter" ] || continue
		while [ "$SECONDS" -lt "$giveUntil" ] && [ -f "$giveWaiter" ] ; do
			giveHolders="$( AgentsRunLaneHolders ) "
			[ "$( AgentsRunTicketState "$giveWaiter" "$giveHolders" )" = alive ] || break
			givePid="" giveSession="" giveKind="" giveWon=""
			while IFS='=' read -r giveKey giveValue ; do
				case "$giveKey" in
					session) [ -n "$giveSession" ] || giveSession="$giveValue" ;;
					pid) [ -n "$givePid" ] || givePid="$giveValue" ;;
					kind) [ -n "$giveKind" ] || giveKind="$giveValue" ;;
					turn-won) [ -n "$giveWon" ] || giveWon="$giveValue" ;;
				esac
			done 2> /dev/null < "$giveWaiter"
			[ -z "$giveWon" ] || break
			[ "$giveKind" != check ] || givePid=""
			! AgentsRunTicketHoldsLane "$givePid" "$giveSession" "$giveHolders" || break
			date +%s > "$runQueueDir/$runTicket.beat" 2> /dev/null || :
			touch "$runList" 2> /dev/null || :
			sleep 2
		done
	done <<< "$runYieldWaiters"
	## As many lanes as it gave, whichever are free: a head that waits for its old lane while another stands free holds the whole line behind it.
	for giveLane in $giveLanes ; do giveWant=$(( giveWant + 1 )) ; done
	[ "$giveWant" -le "$runLaneCountNow" ] || giveWant="$runLaneCountNow"
	runLaneMine=""
	giveUntil=$(( SECONDS + runYieldBound ))
	while [ "$giveHave" -lt "$giveWant" ] && [ "$SECONDS" -lt "$giveUntil" ] ; do
		giveTry=1
		while [ "$giveTry" -le "$runLaneCountNow" ] && [ "$giveHave" -lt "$giveWant" ] ; do
			case " $runLaneMine " in *" $giveTry "*) ;; *) ! { AgentsRunLaneFree "$giveTry" && AgentsRunLaneTake "$giveTry" ; } || giveHave=$(( giveHave + 1 )) ;; esac
			giveTry=$(( giveTry + 1 ))
		done
		[ "$giveHave" -lt "$giveWant" ] || break
		date +%s > "$runQueueDir/$runTicket.beat" 2> /dev/null || :
		touch "$runList" 2> /dev/null || :
		sleep 2
	done
	## The mark comes off only now, with the lanes taken back: a worker waiting on it goes on with lanes the run holds.
	[ "$giveHave" -ge "$giveWant" ] || echo "# AgentsRunTests.sh: waited ${runYieldBound}s for its lane(s) to come free and goes on with $giveHave of $giveWant" >&2
	rm -f "$runQueueDir/$runTicket.yield"
	echo "# AgentsRunTests.sh: took its lane(s)$runLaneMine again and goes on with its checks" >&2
	return 0
}
## Before a worker is handed its next check (A RUN GIVES ITS LANES UP, above). With a ticket waiting for the run's lanes, no new check is
## handed out: the first worker to mark the ticket yields for the run, once, and every other worker waits until the mark is gone and the
## lanes are the run's again. rc 0 where the worker stopped.
AgentsRunYieldPoint(){
	local pointLane
	AgentsRunYieldWaiters
	[ -n "$runYieldWaiters" ] || [ -f "$runQueueDir/$runTicket.yield" ] || return 1
	if [ -n "$runYieldWaiters" ] && ( set -C ; date +%s > "$runQueueDir/$runTicket.yield" ) 2> /dev/null ; then
		AgentsRunYieldGive
		return 0
	fi
	## The lanes the run holds now, read from the lane files this runner holds: the yield takes back any lanes that stand free, so their
	## numbers may be others than those this worker was forked with.
	while : ; do
		runLaneMine=""
		for pointLane in 1 "$runLaneDir"/lane.* ; do
			pointLane="${pointLane##*/lane.}"
			case "$pointLane" in ''|*[!0123456789]*) continue ;; esac
			[ "$( AgentsRunLaneHolder "$pointLane" )" != "$$" ] || runLaneMine="$runLaneMine $pointLane"
		done
		[ -f "$runQueueDir/$runTicket.yield" ] || [ -z "$runLaneMine" ] || break
		sleep 1
	done
	return 0
}

AgentsRunWorker(){ ## worker number -- one task line of the driver: the tests of the run list one after another, each the first no worker has taken, until none is left
	local workerName workerTimeout workerRan=""
	while read -r workerName workerTimeout ; do
		[ -n "$workerName" ] || continue
		## before a check is handed out: a worker that has run one since its last stop may give the run's lanes up, and every worker stops while one does
		if [ -n "$workerRan" ] || [ -f "$runQueueDir/$runTicket.yield" ] ; then
			! AgentsRunYieldPoint || workerRan=""
		fi
		## taken by whoever makes its log: made by one worker or not at all, never by two
		( set -C ; printf '' > "$runDir/$workerName.log" ) 2>/dev/null || continue
		AgentsRunOneTest "$workerName" "$workerTimeout" < /dev/null || :
		workerRan=1
	done < "$runList"
	return 0
}

## The stall keeper: what the run folder holds now, on one line: the time of its newest entry,
## how many entries it has, how many of them are receipts, and how many tests started and have
## no receipt yet. The watch compares two of these lines and nothing else. `tests.list` is left
## out of it: the yield touches it, so counting it cannot tell a live wait from a wedge.
runStallKeeper="$runKeeperDir/runner-stall-keeper.py"
AgentsRunStallEnd(){ ## seconds stood still, and finished where every test has its receipt -- the note of it, and the driver ended with what is left under it
	local endSelf endSignal endPid
	## from here the watch is not told to go any more: it ends the run, and then itself
	trap '' TERM
	if [ "${2:-stalled}" = finished ] ; then
		## EVERY TEST HAS ITS RECEIPT: the run is over and only the driver stands, held by a check that left a process behind.
		printf 'driver-ended=%s\ntimeout=%s\nreceipts=%s\nended=%s\n' "$1" "$runTimeout" "$3" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$runDir/driver-ended.txt" || :
	else
		printf 'stood-still=%s\ntimeout=%s\nmargin=%s\nended=%s\n' "$1" "$runTimeout" "$runStallMargin" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$runDir/stalled.txt" || { rm -f "$runDir/stalled.txt" ; return 1 ; }
	fi
	## The driver is the first process of the pipeline, a child of this runner as the watch is,
	## and the tee after it ends by itself once nothing writes to it. The driver is told to end,
	## so it removes what it made; what is under it is ended outright, a stopped process too.
	## The pids are read and signalled in one go: none is kept for later, when its number may
	## be another process's.
	endSelf="$( exec sh -c 'echo "$PPID"' )"
	ps -A -o pid= -o ppid= -o comm= 2>/dev/null | LC_ALL=C awk -v root="$$" -v self="$endSelf" '
		{ ppid[ $1 ] = $2 ; name[ $1 ] = $3 ; }
		END {
			for ( pid in ppid ) {
				if ( pid == self || pid == root ) continue
				top = pid ; hops = 0
				while ( ( top in ppid ) && ppid[ top ] != root && top != self && hops++ < 64 ) top = ppid[ top ]
				if ( ! ( top in ppid ) || ppid[ top ] != root || top == self || name[ top ] ~ /(^|\/)tee$/ ) continue
				if ( top == pid ) first = first "TERM " pid "\n" ; else rest = rest "KILL " pid "\n"
			}
			printf "%s%s", first, rest
		}' | while read -r endSignal endPid ; do kill "-$endSignal" "$endPid" 2>/dev/null ; done
	return 0
}
## THE WINDOW OUTWAITS THE WHOLE YIELD: its three runYieldBound phases leave the run folder unchanged, so the watch cannot tell them from a stall.
AgentsRunStallWatch(){ ## -- beside the run for as long as it lasts: once nothing in the run folder has changed for longer than a test may take and the margin, the run is ended as stalled (A RUN THAT STANDS STILL, above). Its measure is real seconds, so a shortened `sleep` on PATH changes only how often it looks, never what it reads
	local watchLimit=$(( 10#$runTimeout + 10#$runStallMargin + 3 * 10#$runYieldBound )) watchEvery watchSleep="" watchSeen="" watchNow watchStill=0 watchChanged=$SECONDS
	watchEvery=$(( watchLimit / 10 )) ; [ "$watchEvery" -ge 1 ] || watchEvery=1 ; [ "$watchEvery" -le 20 ] || watchEvery=20
	trap '[ -z "$watchSleep" ] || kill "$watchSleep" 2>/dev/null ; exit 0' TERM
	while : ; do
		## its own sleep holds none of the runner's output, and goes with the watch
		sleep "$watchEvery" > /dev/null 2>&1 < /dev/null &
		watchSleep=$! ; wait "$watchSleep" ; watchSleep=""
		## a runner that is gone has nobody to tell
		kill -0 "$$" 2>/dev/null || return 0
		## what it counts is real seconds since the run folder last changed, never the length of its own naps: a nap is
		## however long `sleep` was told to take, and a rig may put its own `sleep` first on PATH (sh-test's clock)
		watchNow="$( python3 -I -B "$runStallKeeper" "$runDir" 2>/dev/null )"
		[ -n "$watchNow" ] || continue
		if [ "$watchNow" != "$watchSeen" ] ; then watchSeen="$watchNow" ; watchChanged=$SECONDS ; continue ; fi
		## EVERY TEST OF THE LIST HAS ITS RECEIPT: the run is finished, and the driver may be held open by a process a check left
		## behind. A count seen on two passes running is no receipt being written at this instant, so the run is ended and its
		## summary written, instead of standing still until the stall bound.
		watchWanted="$( LC_ALL=C grep -c . "$runList" 2> /dev/null || : )"
		watchHave="$( LC_ALL=C ls -1 "$runDir"/*.receipt 2> /dev/null | LC_ALL=C grep -c . || : )"
		if [ "${watchHave:-0}" -ge "${watchWanted:-0}" ] && [ "${watchWanted:-0}" -gt 0 ] ; then
			[ "${watchDoneSeen:-}" != "$watchHave" ] || { AgentsRunStallEnd - finished "$watchHave" || : ; return 0 ; }
			watchDoneSeen="$watchHave"
			continue
		fi
		watchDoneSeen=""
		watchStill=$(( SECONDS - watchChanged ))
		[ "$watchStill" -gt "$watchLimit" ] || continue
		AgentsRunStallEnd "$watchStill" || :
		return 0
	done
}

. "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" || {
	echo "⛔ ERROR: AgentsRunTests.sh: myx.common lib/parallel is not available" >&2 ; exit 1
}
mkdir -p "$runSlotDir" 2>/dev/null && [ -w "$runSlotDir" ] || {
	echo "⛔ ERROR: AgentsRunTests.sh: cannot use the machine's budget of test workers: $runSlotDir -- no test is run outside it" >&2 ; exit 1
}

echo "# AgentsRunTests.sh: $runCount test(s), workers ${runWorkers:-1}, timeout ${runTimeout}s, run folder: $runDir" >&2
echo "# AgentsRunTests.sh: $( AgentsRunLaneReport ) -- lanes of the machine: $runLaneWhy" >&2
runStart="$( date +%s )"
## as many workers as the driver would run at once, and a line of the driver for each, never more lines than tests (THE DRIVER IS HANDED ITS WORKERS, above)
runWorkerCount="${runWorkers:-1}"
runWorkerLines="$runCount"
case "$runWorkerCount" in ''|*[!0123456789]*) ;; *) [ "$runWorkerCount" -ge "$runCount" ] || runWorkerLines="$runWorkerCount" ;; esac
runWorkerList=""
for (( runWorker = 1 ; runWorker <= runWorkerLines ; runWorker++ )) ; do runWorkerList="$runWorkerList${runWorkerList:+$'\n'}$runWorker" ; done
## no time limit for a test, no time to hold a run to; the watch says nothing itself, so it holds none of this runner's output
runStallPid=""
case "$runTimeout" in ''|*[!0123456789]*) ;; *) [ "$(( 10#$runTimeout ))" = 0 ] || { AgentsRunStallWatch > /dev/null 2>&1 & runStallPid=$! ; } ;; esac
## THE STATE THE RUN STARTS ON, walked once for the whole run (the pass record, above). A walk a test would pay the whole
## store on every test, and the suite is 935 tests on one machine.
AgentsRunPassKey $( cut -d' ' -f1 "$runList" ) > "$runDir/pass-keys.start" 2> /dev/null || :
Parallel --workers "$runWorkerCount" AgentsRunWorker <<< "$runWorkerList" | tee "$runDir/progress.txt"
## The run has ended: by itself, and the watch is told to go; or by the watch, which hears nothing while it ends
## the run, and is waited for. It is told only while this shell knows it to be running, never by a pid kept for later.
runStalled="" runNever="" runNeverCount=0 runOpen="" runOpenCount=0
if [ -n "$runStallPid" ] ; then
	case " $( jobs -pr | LC_ALL=C tr '\n' ' ' )" in *" $runStallPid "*) kill "$runStallPid" 2>/dev/null ;; esac
	wait "$runStallPid" 2>/dev/null
fi
if [ -f "$runDir/stalled.txt" ] ; then
	runStalled="$( sed -n 's/^stood-still=//p' "$runDir/stalled.txt" | sed -n 1p )" ; runStalled="${runStalled:-?}"
	for runName in $( cut -d' ' -f1 "$runList" ) ; do
		[ ! -f "$runDir/$runName.receipt" ] || continue
		if [ -f "$runDir/$runName.log" ] ; then runOpen="$runOpen $runName" ; runOpenCount=$(( runOpenCount + 1 ))
		else runNever="$runNever $runName" ; runNeverCount=$(( runNeverCount + 1 )) ; fi
	done
	printf 'never-ran=%s\nnever-ended=%s\n' "${runNever# }" "${runOpen# }" >> "$runDir/stalled.txt"
fi

## THE STATE THE RUN ENDED ON, and the pass each test earned: a pass is kept only where the two reads agree, so a pass on a
## tree that moved while the run ran is kept for no state. Both walks are the run's, never a test's.
AgentsRunPassKey $( cut -d' ' -f1 "$runList" ) > "$runDir/pass-keys.end" 2> /dev/null || :
exec 8< "$runDir/pass-keys.start" 9< "$runDir/pass-keys.end"
while read -r passName passTimeout ; do
	[ -n "$passName" ] || continue
	runKeyStart="" runKeyEnd="" runKeyStartName="" runKeyEndName=""
	IFS=' ' read -r runKeyStartName runKeyStart runKeyStartWhen <&8 || :
	IFS=' ' read -r runKeyEndName runKeyEnd runKeyEndWhen <&9 || :
	[ "$( sed -n 's/^rc=//p' "$runDir/$passName.receipt" 2> /dev/null | sed -n 1p )" = 0 ] || continue
	[ "$runKeyStartName" = "$passName" ] && [ "$runKeyEndName" = "$passName" ] || {
		printf 'not-kept=no key could be made for the state it ran on\n' >> "$runDir/$passName.receipt"
		continue
	}
	case "$runKeyStart:$runKeyEnd" in
		:*|-:*|*:|*:-) printf 'not-kept=no key could be made for the state it ran on\n' >> "$runDir/$passName.receipt" ;;
		"$runKeyEnd:$runKeyEnd")
			if AgentsRunPassKeep "$passName" "$runKeyStart" "$( sed -n 's/^seconds=//p' "$runDir/$passName.receipt" 2> /dev/null | sed -n 1p )" ; then
				printf 'kept=%s\n' "$runKeyStart" >> "$runDir/$passName.receipt"
			else
				printf 'not-kept=the record could not be written in %s\n' "$runPassDir" >> "$runDir/$passName.receipt"
			fi
		;;
		*) printf 'not-kept=the state it ran on changed while it ran: from %s to %s\n' "$runKeyStart" "$runKeyEnd" >> "$runDir/$passName.receipt" ;;
	esac
done < "$runList"
exec 8<&- 9<&-

{
	runPass=0 runNoteBlock="" runOwned=0 runUnowned=0 runFixed=0
	runAssert=0 runRefused=0 runTimedOut=0
	runRows=""
	for runName in $( cut -d' ' -f1 "$runList" ) ; do
		runRc="$( sed -n 's/^rc=//p' "$runDir/$runName.receipt" 2>/dev/null )"
		runEnded="$( sed -n 's/^ended-by=//p' "$runDir/$runName.receipt" 2>/dev/null | LC_ALL=C sed -n 1p )"
		runKnown="" ; AgentsRunKnownOf "$runName"
		if [ "${runRc:-x}" = 0 ] ; then
			runPass=$(( runPass + 1 ))
			if [ -n "$runKnown" ] ; then
				runFixed=$(( runFixed + 1 ))
				runNoteBlock="$runNoteBlock""FIXED $runName -- it was listed as failing and it passed: take its row out of $runKnownFile"$'\n'
			else
				runRows="$runRows""PASS $runName"$'\n'
			fi
		else
			if [ -n "$runKnown" ] ; then runOwned=$(( runOwned + 1 )) ; else runUnowned=$(( runUnowned + 1 )) ; fi
			## THREE FINDINGS, NEVER ONE: a check ended at its time limit by the stall keeper's own note, a check that
			## refused ended a line on the refusal wording every check of the suite writes, and the rest failed an assertion.
			runKind=""
			if [ -n "$runEnded" ] ; then
				runTimedOut=$(( runTimedOut + 1 ))
				runKind=" kind=TIMEOUT"
			else
				runRefusedLine="$( LC_ALL=C grep -F 'refusing to report a result' "$runDir/$runName.log" 2>/dev/null | LC_ALL=C sed -n 1p )"
				if [ -n "$runRefusedLine" ] ; then
					runRefused=$(( runRefused + 1 ))
					runKind=" kind=REFUSED"
				else
					runAssert=$(( runAssert + 1 ))
				fi
			fi
			runRows="$runRows""FAIL $runName rc=${runRc:-none}${runEnded:+ $runEnded}$runKind$runKnown"$'\n'
		fi
	done
	printf '%s' "$runRows" | sort -k1,1 -k2,2
	printf '%s' "$runNoteBlock"
	[ -z "$runStalled" ] || echo "STALLED  never ran $runNeverCount  never ended $runOpenCount"
	## THE THREE KINDS COUNTED APART, on a line of their own: the totals line below keeps its shape, which three checks
	## read as their instrument, and FAIL keeps its meaning as every check that did not pass, so TOTAL = PASS + FAIL.
	echo "KINDS  ASSERT $runAssert  REFUSED $runRefused  TIMEOUT $runTimedOut"
	echo "TOTAL $runCount  PASS $runPass  FAIL $(( runCount - runPass ))  WALL $(( $( date +%s ) - runStart ))s  OWNED $runOwned  UNOWNED $runUnowned  FIXED $runFixed"
} > "$runDir/summary.txt"
python3 -I -B "$runPassKeeper" prune "$runPassDir" "$runPassAge" 2>/dev/null || :

echo "---" >&2
grep '^FAIL' "$runDir/summary.txt" || :
tail -n 1 "$runDir/summary.txt"
if [ -n "$runStalled" ] ; then
	echo "⛔ ERROR: AgentsRunTests.sh: this run stood still and was ended as stalled: nothing of it started, ended or wrote a line for ${runStalled}s, longer than a test may take (${runTimeout}s) and ${runStallMargin}s more, so no test of it was running and none waited for a worker slot. Never ran, $runNeverCount of $runCount test(s):${runNever:- none}. Started and never ended, $runOpenCount:${runOpen:- none}. What did end is in $runDir/summary.txt, and the note of this in $runDir/stalled.txt" >&2
	exit 124
fi
grep -q '^FAIL' "$runDir/summary.txt" && exit 1
exit 0
