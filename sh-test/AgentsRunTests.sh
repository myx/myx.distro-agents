#!/usr/bin/env bash
##
## AgentsRunTests.sh -- runs sh-test/*.test.sh and sh-test/*/*.test.sh in parallel (myx.common lib/parallel) and keeps
## one log and one receipt per test in a run folder, in the folder the run was started from: the
## session's own output folder where a session runs it, the workspace's .local/temp otherwise:
##   <that folder>/mdat-tests/<UTC-stamp>/<test>.log      the test's whole output
##     (<UTC-stamp>-<pid> for a run started in the same second as another)
##   <that folder>/mdat-tests/<UTC-stamp>/<test>.receipt  rc, seconds, last line
##   <that folder>/mdat-tests/<UTC-stamp>/summary.txt     PASS / FAIL per test, totals
## and points <that folder>/mdat-tests/latest at it.
##
## Usage: AgentsRunTests.sh [-w <workers>] [-t <timeout-seconds>] [--stall-margin <seconds>] [<name-substring>...]
##        AgentsRunTests.sh --passed [<name-substring>...]
##   no substrings: every *.test.sh of sh-test and of its subfolders, one level down (a test is
##   known by its name, so no two share one); otherwise the tests whose name contains any of them.
##   --passed runs nothing: for each of those tests it prints one line, `<test> <when>`, the
##   time it passed on the very state it would run on now, or `<test> -` where no such pass
##   is on record (the pass record, below).
##   Workers: one unless -w is given.
##   Each line of the run list is `<test> <timeout-seconds>`; -t sets the timeout written
##   into each line (default 900).
##   Status: 0 every test passed, 1 a test did not or the run was refused, 124 the run stood
##   still and was ended (A RUN THAT STANDS STILL, below).
##
## Each test gets a test-only session identity, so no test can write into a live session store.
## And nothing of the session its runner was started in. A member's session that a spawn started
## holds more than its id and its member: its coworking session and that session's thread, the
## conversations it continues, its sandbox, its launch marker, whether its caller waits. Every
## MDAT_SPAWN_* and MDAT_SESSION_* variable is taken out, and MDAT_CONVERSATION_THREADS: a rig
## that found them was no session of its own. Its spawn joined that session and took its thread,
## its question to a member went there, its harness kept its scratch in that member's sandbox.
## And its waits remind no ask (MDAT_WAIT_REMIND=off, AgentsTools.MemberWait.include): the asks of
## a rig carry the ts its fake Slack gives, years old, so every wait that brings nothing would
## remind them, one more post than a scenario counts. A test of the reminders unsets it.
## And no test starts the communications reader (MDAT_COMMS_READER=off, AgentsTools.SessionComms.include):
## a detached process of the tooling that a rig's spawn would leave running after the rig is gone. The
## check of the reader unsets it, and ends what it starts.
## And none starts the thread that updates the sources a scan reads (MDAT_COLLECT_THREAD=off, AgentsTools.CollectThread.include): the same
## kind of process, left running after its rig is gone. The check of the thread unsets it, and ends what it starts.
## And none starts the thread that commits and pushes the team data (MDAT_TEAM_DATA_COMMIT_THREAD=off, AgentsTools.TeamDataThread.include): with it off
## a writer commits in its own process, as before the thread. The check of the thread unsets it, and ends what it starts.
## And none starts the schedule's service thread (MDAT_SCHEDULE_THREAD=off, AgentsTools.ScheduleThread.include): with it off the main loop runs
## the schedule's steps in its own process, as it always did. The check of the thread unsets it, and ends what it starts.
## And a rig that sets no workspace mode is a team rig (MDAT_WORKSPACE_MODE=team-rig, AgentsTools.TeamDataGate.include): its mode is the
## default the one reader of the mode gives, which a setting of the rig stands ahead of. Unset, a rig is just agents and keeps no team
## data (F13.1). The checks of the gate and of the digest set or unset it themselves.
##
## WAITING IN THE LINE, IN ARRIVAL ORDER, AND MORE THAN ONE LANE. Every run, of every test (no name
## given) or of named tests, waits its turn in arrival order and says in one line that it waits and
## behind whom, across every builder of the machine. The line is one folder on the machine,
## $HOME/.agents/magic-team/suite-queue, never a folder of the package: a runner started from any copy
## of the package (MDLT_ORIGIN) stands in the same line. A ticket is a file named by its arrival time, holding
## the session of its run -- `session=<session-id>` -- and one whose run has ended is taken out by whoever waits
## behind it, so no turn is held by the dead. A ticket that has held the line past MDAT_SUITE_QUEUE_HOLD_SECONDS
## gives it up too, however alive its run looks, and so does one whose waiting holder stopped beating past
## MDAT_SUITE_QUEUE_STALL_SECONDS.
##
## HOW MANY RUNS STAND BESIDE EACH OTHER, AND WHAT DECIDES IT. The line became the team's throttle:
## at 01:20Z on 2026-11-04 five runs queued behind one holder, and a run refused after 900 s having
## started nothing. Load average is not the measure. At load 15 to 39 that night tool calls stayed at a
## median of 1 s and a 90th percentile of 5 s, so the machine had capacity the line did not use. What is
## measured is the pace a tool call finds now: one fixed piece of this shell's own work, no fork, best of
## three, against the fastest pace this machine has shown. That floor is kept in
## $HOME/.agents/magic-team/suite-lanes/pace-floor, a slower measurement never raises it, and it is read
## afresh once it is a day old. Lanes are floor/pace times the machine's own count (suite-lanes/max, 3
## unless it holds a number), at least one: fewer runs stand beside each other as calls slow down, more as
## they speed up. Measured on ws-myx-devops at 04:16Z: 283 ms at rest, 336 ms with eight busy loops
## added, 983 ms with twenty, and 286 ms again two seconds after those ended while load still read 19.8.
##
## A LANE IS WHAT A RUN HOLDS, AND THE QUEUE IS STILL IN ARRIVAL ORDER. A run takes one lane at its turn
## and gives it back when it ends, so two runs stand beside each other exactly as many lanes allow. A
## ticket ahead of this run that holds no lane is the head of the queue and is waited for, so a run that
## arrived first starts first. A run with a test that measures its own timing takes EVERY lane and says
## so: a test declares that with `## lane: alone` in its header, and such a test never runs beside
## another test or another run.
## The hand rule this replaces, `mkdir $MMDAPP/.local/temp/suite-run.lock` around a run,
## is kept, so a session on the hand rule and a queued run never run at once: while another session
## holds that lock every lane is shut and each run waits, naming it. A lock taken by hand is no turn:
## one whose note names the folder this run's source root is in, under $MMDAPP/.local/temp, is the
## caller's own, and the run starts under it only when its own turn in the line has come, leaving it for
## the caller to remove; with any run ahead of it in the line the run is refused, saying so. A lock left
## by a runner that no longer exists is removed; one taken by hand never is.
##
## NOTHING RUNS AROUND THE LINE. A run that cannot be given a lane says so and refuses; a test started by
## a run carries that run's ticket (MDAT_SUITE_QUEUE_TURN) and stands in no line of its own, and a ticket
## that is no file of the line buys no run anything.
##
## ONE BUDGET OF TEST WORKERS FOR THE WHOLE MACHINE, shared by every runner, of a full suite
## or of named tests, from any copy of the package: a test takes a worker slot before it
## starts and gives it back when it ends, so the tests running at once on the machine never
## pass the budget, whatever each runner's own number of workers. The budget is half the
## machine's cores unless $HOME/.agents/magic-team/suite-workers/budget holds a number. Slots
## are asked for in arrival order, across runners, so a run of named tests is not starved by
## a full suite; the runner says in one line when a test of its waits, and how many slots
## are in use. A slot is held by the test's own process: one whose process no longer exists
## is given back by whoever asks next. Tests run at a lowered priority (nice 10, or the
## runner's own where that is lower still), so a person's own work on the machine comes first.
## The hand rule the budget replaces, `mkdir $MMDAPP/.local/temp/one-test-run.lock` with a
## file `owner` naming the session's scratch folder around any test run, is honoured for as
## long as any session still holds it: no test takes a slot while another session holds that
## lock, and the runner says whose it is. A run can tell whose it is only by the folder its
## own source root is in, under $MMDAPP/.local/temp: a lock naming that folder is its
## caller's own, and so is any such lock to a run from a tree that is no scratch folder.
##
## THE DRIVER IS HANDED ITS WORKERS, NEVER THE TESTS. lib/parallel starts a job for each line
## it reads and, once as many run as it has workers, waits to be told that one has ended
## before it reads on. It is told through a helper process of its own, and a driver whose
## helper is gone is never told: it waits for ever with no test running, and no job is left
## to wake it (2026-10-13: 192 named tests, 56 run, then more than an hour of standing
## still; the helper of that run was gone, and nothing of the driver looks after it). So the
## driver reads one line for each worker and no more: it starts them all at once and has
## nothing to wait for but their end. Each worker takes the tests of the run list one after
## another, each time the first that no worker has taken, until none is left. A test is
## taken by whoever makes its log, which is made whole or not at all, so no test is run
## twice and none is left out. What runs at once, and the order in which the tests start
## and ask for their slots, are as they were: as many tests as workers, in the order of the
## list.
##
## A RUN THAT STANDS STILL IS ENDED, AND SAYS SO. Every start and every end of a test is
## written in the run folder, and so are each line a test prints and the note, made again
## each minute, that a test waits for a slot. A watch beside the run looks at the folder.
## Once nothing in it has changed for longer than a test may take (-t) and a margin more
## (--stall-margin, default 120 seconds), no test of the run is running and none waits, so
## the run is ended: the driver is stopped with what is left under it, the summary is written
## with what did end, the tests that never ran and those that started and never ended are
## named, in the output and in <run folder>/stalled.txt, and the status is 124. The watch
## counts the time as it goes and never reads it off the clock, so a machine that slept is
## not taken for a run that stood still. A margin under 61 seconds is for a rig alone: a
## test that waits for a slot is seen to wait once a minute. A run whose tests have no time
## limit (-t 0, or no number) has no watch: there is no time by which a test must have ended.
##
## A PASS IS KEPT BY THE CONTENT IT WAS EARNED ON. After a test passes, the pass goes on
## record under a key made from the content of everything the test can read: every file of
## the copy of the package this runner is in (its tests and their fixtures, sh-lib,
## sh-scripts, the skillset, the docs, project.inf, this runner), every file of the tooling's
## other packages under the same source root (myx.distro-*, myx.common), of myx.common as it
## is installed (MYXROOT), and of the member set the environment hands the tests
## (MDAT_SKILLSET_ROOT, which a test started from a scratch copy still reads from the
## workspace), with the shell and the system the tests run under. Paths below those roots
## and content only, never where a root lies: a copy that is byte for byte another shares
## its passes. The key is made before the test starts and again once it has passed, and the
## pass is kept only where the two agree, so a pass on a tree that moved under the test is
## kept for no state. Only a pass is kept: a failure is no record, whatever made the test
## fail. Not in the key: the workspace's own data and the machine's state, which the rigs of
## the tests stand in for. The record is one folder on the machine,
## $HOME/.agents/magic-team/suite-results, a folder for each test and in it a file named by
## the key; a pass is believed for seven days, and every run removes the ones older than
## that, of every test. A run reads none of it and runs what it is told: `--passed` is the
## one reader, for whoever decides what is left to run, as the retest queue does
## (sh-lib/member/AgentsTools.MemberRetest.include).
##

set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

testDir="$( cd "$( dirname "$0" )" && pwd )"
runWorkers="" runTimeout=900 runPassed="" runStallMargin=120
while [ $# -gt 0 ] ; do
	case "$1" in
		-w|--workers) runWorkers="$2" ; shift 2 ;;
		-t|--timeout) runTimeout="$2" ; shift 2 ;;
		--stall-margin)
			case "$2" in ''|*[!0123456789]*) echo "⛔ ERROR: AgentsRunTests.sh: --stall-margin takes a number of seconds: $2" >&2 ; exit 1 ;; esac
			runStallMargin="$2" ; shift 2
		;;
		--passed) runPassed=1 ; shift ;;
		--) shift ; break ;;
		-*) echo "⛔ ERROR: AgentsRunTests.sh: unknown option: $1" >&2 ; exit 1 ;;
		*) break ;;
	esac
done

runQueueDir="${HOME:-}/.agents/magic-team/suite-queue"
runHandLock="$MMDAPP/.local/temp/suite-run.lock"
runTicket="" runLockMine=""
runSlotDir="${HOME:-}/.agents/magic-team/suite-workers"
runSlotDefault="$( sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2 )"
case "$runSlotDefault" in ''|*[!0123456789]*) runSlotDefault=2 ;; esac
runSlotDefault=$(( runSlotDefault / 2 ))
[ "$runSlotDefault" -ge 1 ] || runSlotDefault=1
runTestLock="$MMDAPP/.local/temp/one-test-run.lock"
## the folder this run's source root is in, under the workspace's temp: empty for any other tree
runOwnFolder="${MDLT_ORIGIN#"$MMDAPP/.local/temp/"}"
if [ "$runOwnFolder" != "$MDLT_ORIGIN" ] ; then runOwnFolder="${runOwnFolder%%/*}" ; else runOwnFolder="" ; fi
runLaneDir="${HOME:-}/.agents/magic-team/suite-lanes"
runLaneMine="" runLaneAlone="" runLaneCountNow=1

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
## in, myx.common as it is installed, the member set the environment hands the tests, and the
## tooling's other packages under the source root.
runPassRoots=( "package=$( cd "$testDir/.." && pwd -P )" "myxroot=${MYXROOT:-/usr/local/share/myx.common}" )
[ -z "${MDAT_SKILLSET_ROOT:-}" ] || runPassRoots[${#runPassRoots[@]}]="members=$MDAT_SKILLSET_ROOT"
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
		namesName="$( basename "$namesTest" .test.sh )"
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
AgentsRunTicketState(){ ## ticket file, the sessions holding a lane now on one line -- `alive`, `own`, `gone`, `ended`, `held` or `stalled`
	local ticketSession ticketSince ticketStamp ticketClock ticketAge ticketBeat
	local ticketHold=${MDAT_SUITE_QUEUE_HOLD_SECONDS:-21600} ticketStall=${MDAT_SUITE_QUEUE_STALL_SECONDS:-3600}
	case "$ticketHold" in ''|*[!0123456789]*) ticketHold=21600 ;; esac
	case "$ticketStall" in ''|*[!0123456789]*) ticketStall=3600 ;; esac
	ticketSession="$( LC_ALL=C sed -n 's/^session=//p' "$1" 2>/dev/null | LC_ALL=C sed -n 1p )"
	## A ticket with no session line was never written whole, and holds nobody's place.
	[ -n "$ticketSession" ] || { printf 'gone' ; return 0 ; }
	case "$ticketSession" in *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-]*) printf 'gone' ; return 0 ;; esac
	## This run's own ticket is no place ahead of it: its own session is written on it.
	[ "$ticketSession" != "$( AgentsRunOwnSession )" ] || { printf 'own' ; return 0 ; }
	## A ticket that names a run is given up when this workspace's records say that run has ended. One naming `none`, a run
	## the tooling gave no id, has no record to read, and is judged by its own age and beat below.
	if [ "$ticketSession" != none ] ; then
		AgentsRunSessionEnded "$ticketSession" && { printf 'ended' ; return 0 ; }
	fi
	## A run holding one of the machine's lanes is running and not waiting: its lane's own holder record says it is there.
	case " ${2:-} " in *" $ticketSession "*) printf 'alive' ; return 0 ;; esac
	ticketSince="$( LC_ALL=C sed -n 's/^since=//p' "$1" 2> /dev/null | LC_ALL=C sed -n 1p )"
	ticketStamp="$( date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$ticketSince" '+%s' 2> /dev/null || date -u -d "$ticketSince" '+%s' 2> /dev/null )" || ticketStamp=""
	ticketClock="$( date +%s )" || { printf 'alive' ; return 0 ; }
	case "$ticketStamp" in
		''|*[!0123456789]*) ticketStamp="" ;;
		*) ticketAge=$(( ticketClock - ticketStamp )) ; [ "$ticketAge" -le "$ticketHold" ] || { printf 'held' ; return 0 ; } ;;
	esac
	## The beat is the second of the last pass of a holder's wait, so a run that stopped waiting gives up the place a
	## process alone would go on holding. A ticket with no beat at all carries no evidence that its holder stopped, so
	## the hold limit above alone judges it.
	ticketBeat="$( LC_ALL=C tail -1 "$1.beat" 2> /dev/null )"
	case "$ticketBeat" in ''|*[!0123456789]*) printf 'alive' ; return 0 ;; esac
	[ "$(( ticketClock - ticketBeat ))" -le "$ticketStall" ] && printf 'alive' || printf 'stalled'
}

AgentsRunDescribeTicket(){ ## ticket file -- that place named as its own ticket names it: its session, the copy it runs from and how long it has held
	local describeSession describeKind describeOrigin describeSince describeStamp describeClock describeAge describeFrom
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
	printf 'the %s of session %s%s, in the line for %s' \
		"$( [ "$describeKind" = check ] && printf 'check' || printf 'run' )" \
		"${describeSession:-nobody}" "$describeFrom" "$describeAge"
}
AgentsRunQueueLeave(){ ## -- out of the line, and every lane this run took given back
	local leaveLane
	[ -z "$runTicket" ] || rm -f "$runQueueDir/$runTicket" "$runQueueDir/$runTicket.beat"
	for leaveLane in $runLaneMine ; do AgentsRunLaneGive "$leaveLane" ; done
	runTicket="" runLockMine="" runLaneMine=""
}
## THE PACE A TOOL CALL FINDS NOW, and the lanes it buys (WAITING IN THE LINE, above). One fixed piece of this
## shell's own work, no fork, so it measures the machine and not a program's start; the best of three, since the
## slowest sample of a loaded machine says when a call was descheduled and not how fast one would be.
AgentsRunPaceMs(){ ## -- the milliseconds of one fixed piece of shell work, or nothing where it cannot be timed
	local paceTry paceOne paceLow="" paceWhole paceFrac
	for paceTry in 1 2 3 ; do
		## `%3R` is seconds to three decimals, such as `0.283`, so the whole part and the fraction are read apart
		paceOne="$( { TIMEFORMAT='%3R' ; time for (( paceStep = 0 ; paceStep < 90000 ; paceStep++ )) ; do : ; done ; } 2>&1 )"
		case "$paceOne" in ''|*[!0123456789.]*|*.*.*|*.) continue ;; esac
		paceWhole="${paceOne%%.*}" ; paceFrac="${paceOne#*.}"
		case "$paceWhole" in ''|*[!0123456789]*) continue ;; esac
		paceOne=$(( 10#$paceWhole * 1000 + 10#$paceFrac ))
		if [ -z "$paceLow" ] || [ "$paceOne" -lt "$paceLow" ] ; then paceLow="$paceOne" ; fi
	done
	printf '%s' "$paceLow"
}
AgentsRunLaneCount(){ ## -- how many runs may stand beside each other now: the machine's own count, else the pace against the fastest pace it has shown
	local laneMax lanePace laneFloor laneCount laneFixed
	laneMax="$( LC_ALL=C sed -n 1p "$runLaneDir/max" 2>/dev/null )"
	case "$laneMax" in ''|*[!0123456789]*) laneMax="${MDAT_SUITE_LANES:-3}" ;; esac
	case "$laneMax" in ''|*[!0123456789]*) laneMax=3 ;; esac
	[ "$laneMax" -ge 1 ] || laneMax=1
	mkdir -p "$runLaneDir" 2>/dev/null || { printf '1\n' ; return 0 ; }
	## A machine whose lane count is set by hand keeps it, as a machine sets its budget of test workers by hand. That is
	## how a rig of a check fixes the count, so nothing of it waits on how busy the host is.
	laneFixed="$( LC_ALL=C sed -n 1p "$runLaneDir/count" 2>/dev/null )"
	case "$laneFixed" in
		''|*[!0123456789]*) ;;
		*) [ "$laneFixed" -ge 1 ] || laneFixed=1 ; [ "$laneFixed" -le "$laneMax" ] || laneFixed="$laneMax" ; printf '%s\n' "$laneFixed" ; return 0 ;;
	esac
	laneFloor="$( LC_ALL=C sed -n 1p "$runLaneDir/pace-floor" 2>/dev/null )"
	case "$laneFloor" in ''|*[!0123456789]*) laneFloor="" ;; esac
	lanePace="$( AgentsRunPaceMs )"
	## NO PACE, A BUSY MACHINE: a probe that cannot be timed says nothing about the machine, and a signal whose failure mode was
	## "the machine is idle" is fooled by breaking the instrument. One lane is the safe reading, and never the maximum.
	## A pace of zero is no measurement either: it would divide by zero, and written to the floor it would make every later
	## reading look slow enough for one lane for ever.
	case "$lanePace" in ''|*[!0123456789]*|0) printf '1\n' ; return 0 ;; esac
	## The floor is the fastest pace this machine has shown. It is re-read once it is a day old, so a machine that
	## was busy when it was last written is not held to that pace for ever, and a slower pace never raises it.
	if [ -f "$runLaneDir/pace-floor" ] && [ -n "$( find "$runLaneDir/pace-floor" -mtime +0 2>/dev/null )" ] ; then laneFloor="" ; fi
	if [ -z "$laneFloor" ] || [ "$lanePace" -lt "$laneFloor" ] ; then
		printf '%s\n' "$lanePace" > "$runLaneDir/.pace-floor.$$" 2>/dev/null && mv -f "$runLaneDir/.pace-floor.$$" "$runLaneDir/pace-floor" 2>/dev/null || :
		laneFloor="$lanePace"
	fi
	[ "$laneFloor" -gt 0 ] || laneFloor=1
	laneCount=$(( laneMax * laneFloor / lanePace ))
	[ "$laneCount" -ge 1 ] || laneCount=1
	[ "$laneCount" -le "$laneMax" ] || laneCount="$laneMax"
	printf '%s\n' "$laneCount"
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
## A lane whose holder is gone is given back at every read, by whoever asks next, so no lane is held by the dead.
## Lane 1 IS the hand rule's lock, so a lock taken by hand -- one with no runner-pid in it -- is held by a live
## session and is never given back here.
AgentsRunLaneFree(){ ## lane number -- rc 0 while that lane may be taken (its holder has ended)
	local laneHeld
	case "$1" in
		1)
			[ -d "$runHandLock" ] || return 0
			LC_ALL=C grep -q '^runner-pid: ' "$runHandLock"/* 2>/dev/null || return 1
		;;
		*)
			[ -d "$runLaneDir/lane.$1" ] || return 0
		;;
	esac
	laneHeld="$( AgentsRunLaneHolder "$1" )"
	case "$laneHeld" in
		''|*[!0123456789]*) AgentsRunLaneGive "$1" ; return 0 ;;
	esac
	[ "$laneHeld" = "$$" ] && return 1
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
		;;
		*)
			mkdir -p "$runLaneDir" 2>/dev/null || return 1
			mkdir "$runLaneDir/lane.$1" 2>/dev/null || return 1
			printf 'pid=%s\nrunner-pid: %s\nsession=%s\norigin=%s\ntaken: %s\n' "$$" "$$" "$( AgentsRunOwnSession )" "$MDLT_ORIGIN" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$runLaneDir/lane.$1/pid" 2>/dev/null
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
AgentsRunTicketHoldsLane(){ ## session, the sessions holding lanes on one line -- rc 0 where one of the lanes is that session's
	case "$1" in ''|none) return 1 ;; esac
	case " $2 " in *" $1 "*) return 0 ;; esac
	return 1
}
AgentsRunLaneHolders(){ ## lanes to read -- the sessions holding them now, on one line, a dead one given back as it is read, each session once
	local holderLane=1 holderLine="" holderHeld
	while [ "$holderLane" -le "$1" ] ; do
		if ! AgentsRunLaneFree "$holderLane" ; then
			holderHeld="$( AgentsRunLaneSession "$holderLane" )"
			[ -n "$holderHeld" ] || holderHeld="$( AgentsRunLaneHolder "$holderLane" )"
			case " $holderLine " in *" $holderHeld "*) ;; *) holderLine="$holderLine $holderHeld" ;; esac
		fi
		holderLane=$(( holderLane + 1 ))
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
AgentsRunDescribeSession(){ ## session -- that place named as its own ticket names it, where a lane holds it and no ticket names it
	local describeWanted="$1" describeFile
	for describeFile in "$runQueueDir"/*.ticket ; do
		[ -f "$describeFile" ] || continue
		[ "$( LC_ALL=C sed -n 's/^session=//p' "$describeFile" 2>/dev/null | LC_ALL=C sed -n 1p )" != "$describeWanted" ] || { AgentsRunDescribeTicket "$describeFile" ; return 0 ; }
	done
	printf 'the run of session %s, holding one of the machine lanes' "${describeWanted:-nobody}"
}
AgentsRunQueueTurn(){ ## -- stands in the line, takes a lane at this run's turn, and returns; says whom it waits behind, each time that changes
	local turnStamp turnFile turnSession turnState turnWhom="" turnWho="" turnHeldWhom="" turnAhead=0 turnSaid="" turnBegan turnWaited
	local turnHolders turnLane turnRound=0 turnRecount=0
	## A RUN NEVER STANDS IN THE LINE PAST ITS BOUND. A run that has waited MDAT_SUITE_QUEUE_LIMIT seconds -- 900 unless
	## the machine sets it -- says in one line whom it waits behind and refuses: it runs nothing outside its turn, and its
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
	runTicket="$turnStamp.$$.ticket"
	trap AgentsRunQueueLeave EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM HUP
	## whole or not at all: a ticket half written would read as one of no run
	printf 'session=%s\norigin=%s\nkind=run\nsince=%s\n' "$( AgentsRunOwnSession )" "$MDLT_ORIGIN" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$runQueueDir/.$runTicket" \
		&& mv -f "$runQueueDir/.$runTicket" "$runQueueDir/$runTicket" || {
		echo "⛔ ERROR: AgentsRunTests.sh: cannot stand in the machine's line of test runs: $runQueueDir" >&2 ; exit 1
	}
	runLaneAlone=""
	AgentsRunAloneWanted "$@" && runLaneAlone=1
	runLaneCountNow="$( AgentsRunLaneCount )"
	while : ; do
		turnWhom="" ; turnAhead=0
		## the beat of this waiting ticket, so a run that stopped waiting gives up its place while its session lives
		printf '%s\n' "$( date +%s )" >> "$runQueueDir/$runTicket.beat" 2>/dev/null || :
		## The lanes are read at every pass, so a lane whose run died is given back here rather than held for ever.
		turnHolders="$( AgentsRunLaneHolders "$runLaneCountNow" )"
		for turnFile in "$runQueueDir"/*.ticket ; do
			[ -f "$turnFile" ] || continue
			[ "${turnFile##*/}" \< "$runTicket" ] || continue
			turnSession="$( LC_ALL=C sed -n 's/^session=//p' "$turnFile" 2>/dev/null | LC_ALL=C sed -n 1p )"
			## A ticket of this run's own session -- a check running it, or a check of a check -- is the turn this run is
			## inside, and never a place ahead of it (AgentsRunTicketState). A ticket that names no session is nobody's.
			turnState="$( AgentsRunTicketState "$turnFile" "$turnHolders" )"
			case "$turnState" in
				own) continue ;;
				alive) ;;
				*) ## `gone`, `ended`, `held` and `stalled`: a place given up, taken out of the line here and said
					[ "$turnState" = gone ] || echo "# AgentsRunTests.sh: a place given up in the line, so this run stands no longer behind it: $( AgentsRunDescribeTicket "$turnFile" )" >&2
					rm -f "$turnFile" "$turnFile.beat" ; continue
				;;
			esac
			## A ticket ahead that holds no lane is the head of the queue, and this run waits for it, so a run
			## that arrived first starts first. One already holding a lane is running, and this run may take
			## another lane beside it -- and where every lane is taken, the holder is named as well.
			if AgentsRunTicketHoldsLane "$turnSession" "$turnHolders" ; then
				[ -n "$turnHeldWhom" ] || turnHeldWhom="$( AgentsRunDescribeSession "$turnSession" )"
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
		fi
		## said once each time whom it waits behind changes: the age is left out of that comparison, since it moves every pass
		turnWho="${turnWhom%, in the line for *}"
		if [ "$turnWho" != "$turnSaid" ] ; then
			echo "# AgentsRunTests.sh: $runLaneCountNow lane(s) of test runs on this machine, by its pace -- this one waits its turn behind $turnWhom" >&2
			turnSaid="$turnWho"
		fi
		## Its bound passed: what it waits behind, and no run of it. The ticket is given back here, so nothing behind it
		## waits on a run that will never start.
		if [ "$(( $( date +%s ) - turnBegan ))" -ge "$turnWaited" ] ; then
			rm -f "$runQueueDir/$runTicket" 2> /dev/null ; runTicket=""
			echo "⛔ ERROR: AgentsRunTests.sh: not started: its turn in the machine's line had not come within ${turnWaited}s. It waited behind $turnWhom. Nothing was run, and no ticket is left in the line. Run it again, or set MDAT_SUITE_QUEUE_LIMIT higher where a longer wait is wanted." >&2
			exit 1
		fi
		## the lanes are read again now and then, so a machine that came to rest or grew busy widens or narrows them
		turnRecount=$(( turnRecount + 1 ))
		if [ "$turnRecount" -ge 15 ] ; then turnRecount=0 ; runLaneCountNow="$( AgentsRunLaneCount )" ; fi
		sleep 2
	done
}
## Every run waits its turn, a run of named tests as the whole suite does (WAITING IN THE LINE, above).
AgentsRunQueueTurn $( AgentsRunNames "$@" )

## A run a session starts keeps its folder in that session's output folder, beside its own files, and a run
## with no session keeps the workspace's .local/temp. The rule stands here as well as at the tooling's own
## sites because a runner copied alone into a rig cannot reach sh-lib.
runRoot="$MMDAPP/.local/temp/mdat-tests"
[ -z "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] || runRoot="$MDAT_SPAWN_SANDBOX_ROOT/output/mdat-tests"
runDir="$runRoot/$( date -u +%Y%m%dT%H%M%SZ )"
## A folder of its own: a run started in the same second as another takes its pid into the name,
## since two runs in one folder would each run the other's list and overwrite its logs.
mkdir -p "$runRoot" 2>/dev/null
mkdir "$runDir" 2>/dev/null || { runDir="$runDir-$$" ; mkdir -p "$runDir" ; } || { echo "⛔ ERROR: AgentsRunTests.sh: cannot create $runDir" >&2 ; exit 1 ; }
ln -sfn "$runDir" "$runRoot/latest" 2>/dev/null || :
## No test links a rig into source (epic S23.11): each finds a guard `ln` first on its PATH. A runner copied alone into a rig cannot reach sh-lib and runs with none.
if [ -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SandboxLinks.include" ] ; then
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SandboxLinks.include" && AgentsToolsLnGuardMake "$runDir/guard-bin" && PATH="$runDir/guard-bin:$PATH"
fi

runList="$runDir/tests.list"
AgentsRunNames "$@" | while IFS= read -r runName ; do
	printf '%s %s\n' "$runName" "$runTimeout"
done > "$runList"
runCount="$( grep -c . "$runList" )"
[ "$runCount" -gt 0 ] || { echo "⛔ ERROR: AgentsRunTests.sh: no test matches" >&2 ; exit 1 ; }

AgentsRunOneTest(){ ## test name, timeout seconds -- one task line of the run list
	local oneName="$1" oneTimeout="${2:-$runTimeout}" oneStart oneEnd oneRc=0 oneLast onePid oneKey oneAfter oneKept="" oneEnded=""
	## the state this test starts on, for the pass it may earn (the pass record, above)
	oneKey="$( AgentsRunPassKey "$oneName" | LC_ALL=C cut -d' ' -f2 )"
	oneStart="$( date +%s )"
	## The test's own process asks for its worker slot, waits for it, and only then becomes
	## the test (the slot keeper, above); fd 8 is this runner's own output, for the one line
	## it says while a test waits, and the test never sees it.
	(
		## nothing of the session this runner was started in reaches the test (the test-only identity, above).
		## MDAT_TEAM_MEMBER is the one more name AgentsToolsTeamMember falls to, past MDAT_SPAWN_AGENT: a test
		## that needs a member sets its own, as the rigs already do.
		unset ${!MDAT_SPAWN_@} ${!MDAT_SESSION_@} MDAT_CONVERSATION_THREADS harnessSessionId harnessAgent MDAT_TEAM_MEMBER
		export CLAUDE_CODE_SESSION_ID="rig-run-$oneName-test-only"
		export MDAT_WAIT_REMIND=off
		export MDAT_COMMS_READER=off
		export MDAT_COLLECT_THREAD=off
		export MDAT_TEAM_DATA_COMMIT_THREAD=off
		export MDAT_SCHEDULE_THREAD=off
		export MDAT_WORKSPACE_MODE=team-rig
		cd "$testDir" || exit 1
		exec python3 -I -B "$runSlotKeeper" take "$runSlotDir" "$runSlotDefault" 8 "$runDir/slot-wait.said" "$runDir/$oneName.started" "$runTestLock" "$runOwnFolder" "$oneTimeout" "$BASH" "$( AgentsRunTestPath "$oneName" )"
	) 8>&2 > "$runDir/$oneName.log" 2>&1 &
	onePid=$!
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
	## kept only where the state is, now that the test has passed, the one it started on; the receipt says which it was
	if [ "$oneRc" = 0 ] ; then
		oneAfter="$( AgentsRunPassKey "$oneName" | LC_ALL=C cut -d' ' -f2 )"
		case "$oneKey:$oneAfter" in
			:*|-:*|*:|*:-) oneKept="not-kept=no key could be made for the state it ran on" ;;
			"$oneAfter:$oneAfter")
				if AgentsRunPassKeep "$oneName" "$oneKey" "$(( oneEnd - oneStart ))" ; then oneKept="kept=$oneKey" ; else oneKept="not-kept=the record could not be written in $runPassDir" ; fi
			;;
			*) oneKept="not-kept=the state it ran on changed while it ran: from $oneKey to $oneAfter" ;;
		esac
	fi
	printf 'rc=%s\nseconds=%s\nlast=%s\n' "$oneRc" "$(( oneEnd - oneStart ))" "$oneLast" > "$runDir/$oneName.receipt"
	[ -z "$oneEnded" ] || printf 'ended-by=time-limit\n' >> "$runDir/$oneName.receipt"
	[ -z "$oneKept" ] || printf '%s\n' "$oneKept" >> "$runDir/$oneName.receipt"
	if [ "$oneRc" = 0 ] ; then
		printf 'PASS  %-48s %4ss  %s\n' "$oneName" "$(( oneEnd - oneStart ))" "$oneLast"
	else
		printf 'FAIL  %-48s %4ss  rc=%s  %s%s\n' "$oneName" "$(( oneEnd - oneStart ))" "$oneRc" "${oneEnded:+$oneEnded -- }" "$oneLast"
	fi
}

AgentsRunWorker(){ ## worker number -- one task line of the driver: the tests of the run list one after another, each the first no worker has taken, until none is left
	local workerName workerTimeout
	while read -r workerName workerTimeout ; do
		[ -n "$workerName" ] || continue
		## taken by whoever makes its log: made by one worker or not at all, never by two
		( set -C ; printf '' > "$runDir/$workerName.log" ) 2>/dev/null || continue
		AgentsRunOneTest "$workerName" "$workerTimeout" < /dev/null || :
	done < "$runList"
	return 0
}

## The stall keeper: what the run folder holds now, on one line: the time of its newest entry,
## how many entries it has, and how many of them are receipts. The watch compares two of these
## lines and nothing else.
runStallKeeper="$runKeeperDir/runner-stall-keeper.py"
AgentsRunStallEnd(){ ## seconds the run has stood still -- the note of it, for the summary, and the driver ended with what is left under it
	local endSelf endSignal endPid
	## from here the watch is not told to go any more: it ends the run, and then itself
	trap '' TERM
	printf 'stood-still=%s\ntimeout=%s\nmargin=%s\nended=%s\n' "$1" "$runTimeout" "$runStallMargin" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$runDir/stalled.txt" || { rm -f "$runDir/stalled.txt" ; return 1 ; }
	## The driver is the first process of the pipeline, a child of this runner as the watch is,
	## and the tee after it ends by itself once nothing writes to it. The driver is told to end,
	## so it removes what it made; what is under it is ended outright, a stopped process too.
	## The pids are read and signalled in one go: none is kept for later, when its number may
	## be another process's.
	endSelf="$( exec sh -c 'echo "$PPID"' )"
	ps -A -o pid= -o ppid= -o comm= 2>/dev/null | LC_ALL=C awk -v root="$$" -v self="$endSelf" '
		{ ppid[ $1 ] = $2 ; name[ $1 ] = $3 }
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
AgentsRunStallWatch(){ ## -- beside the run for as long as it lasts: once nothing in the run folder has changed for longer than a test may take and the margin, the run is ended as stalled (A RUN THAT STANDS STILL, above)
	local watchLimit=$(( 10#$runTimeout + 10#$runStallMargin )) watchEvery watchSleep="" watchSeen="" watchNow watchStill=0
	watchEvery=$(( watchLimit / 10 )) ; [ "$watchEvery" -ge 1 ] || watchEvery=1 ; [ "$watchEvery" -le 20 ] || watchEvery=20
	trap '[ -z "$watchSleep" ] || kill "$watchSleep" 2>/dev/null ; exit 0' TERM
	while : ; do
		## its own sleep holds none of the runner's output, and goes with the watch
		sleep "$watchEvery" > /dev/null 2>&1 < /dev/null &
		watchSleep=$! ; wait "$watchSleep" ; watchSleep=""
		## a runner that is gone has nobody to tell
		kill -0 "$$" 2>/dev/null || return 0
		watchNow="$( python3 -I -B "$runStallKeeper" "$runDir" 2>/dev/null )"
		[ -n "$watchNow" ] || continue
		if [ "$watchNow" != "$watchSeen" ] ; then watchSeen="$watchNow" ; watchStill=0 ; continue ; fi
		watchStill=$(( watchStill + watchEvery ))
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
echo "# AgentsRunTests.sh: $( AgentsRunLaneReport ) -- the machine's lanes are read against its own pace ($runLaneDir)" >&2
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

{
	for runName in $( cut -d' ' -f1 "$runList" ) ; do
		runRc="$( sed -n 's/^rc=//p' "$runDir/$runName.receipt" 2>/dev/null )"
		runEnded="$( sed -n 's/^ended-by=//p' "$runDir/$runName.receipt" 2>/dev/null | LC_ALL=C sed -n 1p )"
		if [ "${runRc:-x}" = 0 ] ; then echo "PASS $runName" ; else echo "FAIL $runName rc=${runRc:-none}${runEnded:+ $runEnded}" ; fi
	done | sort -k1,1 -k2,2
	runPass="$( grep -l '^rc=0$' "$runDir"/*.receipt 2>/dev/null | wc -l | tr -d ' ' )"
	[ -z "$runStalled" ] || echo "STALLED  never ran $runNeverCount  never ended $runOpenCount"
	echo "TOTAL $runCount  PASS $runPass  FAIL $(( runCount - runPass ))  WALL $(( $( date +%s ) - runStart ))s"
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
