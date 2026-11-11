#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The one way a check of sh-test makes the folder its rig lives in, and its turn in the machine's one line of
## test runs. Sourced by the check:
##   . "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh"
##
## WHY THE FOLDER. No file of this package is ever kept in the system's temp folder (the owner's rule, held for
## every file of the package by AgentsTempNamesCheck): a rig lives in the workspace the check runs in, under
## .local/agents/scratch/sh-test/, beside the harness's own scratch and like it outside every member's floor
## (AgentsTools.Grants.include), so no grant of the workspace reaches a path of a rig. Where there is no
## workspace there is no rig, and no result.
##
## WHY THE TURN. A check started by hand, `bash <check>.test.sh`, used to run beside every other: sessions running
## checks that way at once, around the suite queue, took this machine to load 133 on 2026-11-03. So a check takes
## its turn in the same line a full suite stands in -- $HOME/.agents/magic-team/suite-queue, machine wide, from any
## tree (`AgentsRunTests.sh`, ONE RUN AT A TIME) -- before it makes its folder, and holds it while it runs.
##
##   rigTempDir <name>   waits its turn, then prints the path of a new, empty folder,
##                       $MMDAPP/.local/agents/scratch/sh-test/<name>.XXXXXXXX, made by mktemp -d. With no
##                       MMDAPP, or one that is no folder, it makes nothing, says so on stderr, and returns 1,
##                       for the check to end on before it reports a result. A MMDAPP that is the team-data
##                       store, or inside it, is refused too: a rig's files are no team data, and one placed
##                       there was committed into the shared store by the very step that commits the team data.
##
## HOW THE TURN IS KEPT AND GIVEN BACK. A ticket is a file named by its arrival time, holding the SESSION of the run
## or check that took it -- its own run id, never a process id, since a number is given to another process and a
## ticket naming one reads alive when its owner is long gone -- and the second it joined the line. No trap gives it
## back: whoever waits behind a ticket that has given up its place removes it. A ticket gives up its place when the
## workspace's records say its run has ended (S10.29), when it has held the line longer than
## MDAT_SUITE_QUEUE_HOLD_SECONDS, and when a waiting holder's beat -- written at each pass of its wait -- has stood
## still for longer than MDAT_SUITE_QUEUE_STALL_SECONDS. A ticket of this check's own session is no ticket ahead: a
## check that starts a full suite, and the tests of a suite, run inside that very turn and never wait for themselves.
## A test a run started takes no ticket at all (MDAT_SUITE_QUEUE_TURN, which the runner exports).
##
## THERE IS NO SWITCH TO KEEP A CHECK OUT OF THE LINE, and none should be added. One existed for an evening
## (RIG_NO_QUEUE) and a developer used it to bypass the line for real work, which is how the machine reached load 133.
## The one check that cannot take a turn is the check of the line itself, and it gets out of the way by giving its own
## rig its own HOME: a line under another folder is another line, and the machine's one is left alone.
##
## It also sources rig-copy.include.sh, which holds `rigCopyTree`: the one way a check puts a tree in that folder, as a
## real copy rather than a link into the origin.
##

## One line of turns on the machine, shared by every runner and every check, from any tree.
rigQueueDir="${HOME:-}/.agents/magic-team/suite-queue"

rigQueueAncestors(){ ## -- the pids above this process, self included, on one line
	local ancestorPid="$$" ancestorAround=0
	while [ -n "$ancestorPid" ] && [ "$ancestorAround" -lt 64 ] ; do
		printf '%s ' "$ancestorPid"
		ancestorPid="$( ps -o ppid= -p "$ancestorPid" 2> /dev/null | LC_ALL=C tr -d ' ' )"
		ancestorAround=$(( ancestorAround + 1 ))
	done
}

## The session of this check's own run, as its ticket names it: the run a person or a suite started the check from.
rigQueueSession="${MDAT_SPAWN_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"

## Whether the records of this workspace say a run has ended: one of its spawn records settled, or its own session
## store carrying the end marker of a root session. A run with no record at all has not ended, since absence of a
## record is no evidence that it is gone.
rigQueueSessionEnded(){ ## session -- rc 0 when those records say that run has ended
	local endId="$1" endRoot endRecord endLine endFront endStatus endSeen="" endStarted="" endSettled=""
	case "$endId" in ''|.|..|*/*|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-]*) return 1 ;; esac
	endRoot="${MMDAPP:-/nonexistent}/.local/agents/spawned"
	for endRecord in "$endRoot"/*/"$endId.spawn.md" ; do
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
			spawn-succeeded|spawn-failed|spawn-ended-without-close) endSettled=1 ;;
		esac
	done
	[ -n "$endStarted" ] && return 1
	[ -n "$endSettled" ] && return 0
	[ -n "$endSeen" ] && return 1
	[ -e "${MMDAPP:-/nonexistent}/.local/agents/sessions/$endId/ended" ]
}

## Whom a ticket ahead is, and how long it has held the line: the one phrase both waiters say, about the ticket
## rather than about a process, so a number given to another process can never be read as a live holder.
rigQueueTicketWhom(){ ## ticket file -- that phrase
	local whomSession whomOrigin whomKind whomSince whomStamp whomClock whomFrom whomAge
	whomSession="$( LC_ALL=C sed -n 's/^session=//p' "$1" 2> /dev/null | LC_ALL=C sed -n 1p )"
	whomOrigin="$( LC_ALL=C sed -n 's/^origin=//p' "$1" 2> /dev/null | LC_ALL=C sed -n 1p )"
	whomKind="$( LC_ALL=C sed -n 's/^kind=//p' "$1" 2> /dev/null | LC_ALL=C sed -n 1p )"
	whomSince="$( LC_ALL=C sed -n 's/^since=//p' "$1" 2> /dev/null | LC_ALL=C sed -n 1p )"
	whomStamp="$( date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$whomSince" '+%s' 2> /dev/null || date -u -d "$whomSince" '+%s' 2> /dev/null )" || whomStamp=""
	case "$whomStamp" in ''|*[!0123456789]*) whomStamp="" ;; esac
	whomFrom="" ; [ -z "$whomOrigin" ] || whomFrom=" from $whomOrigin"
	whomAge="in the line since its own second could not be read"
	if [ -n "$whomStamp" ] ; then
		whomClock="$( date +%s )" || whomClock=0
		whomAge="in the line for $(( whomClock - whomStamp ))s"
	fi
	printf 'the %s of session %s%s, %s' \
		"$( [ "$whomKind" = check ] && printf 'check' || printf 'run' )" "${whomSession:-nobody}" "$whomFrom" "$whomAge"
}

## A ticket ahead is given up rather than waited for in four cases: it names no session, the records say its session
## has ended (S10.29), its waiting holder stopped beating past MDAT_SUITE_QUEUE_STALL_SECONDS, or it has held the line past
## MDAT_SUITE_QUEUE_HOLD_SECONDS (S10.29). A ticket that holds a lane is running and not waiting, so neither bound
## judges it; the lane's own holder record does.
## THIS READER IS NOT THE ONLY JUDGE OF A TICKET. `rigQueueTurn`'s loop deletes every ticket whose state is not `own` or
## `alive`, so a rule added here answers one of those two and never a word of its own: a sixth state word is a rule that
## loop makes invisible.
rigQueueTicketState(){ ## ticket file -- `alive`, `own`, `gone`, `ended`, `stalled` or `held`
	local ticketSession="" ticketSince="" ticketStamp ticketClock ticketAge ticketBeat="" ticketPid="" ticketPstart="" ticketWon="" ticketKey ticketValue ticketLine
	local ticketHold=${MDAT_SUITE_QUEUE_HOLD_SECONDS:-21600} ticketStall=${MDAT_SUITE_QUEUE_STALL_SECONDS:-3600}
	case "$ticketHold" in ''|*[!0123456789]*) ticketHold=21600 ;; esac
	case "$ticketStall" in ''|*[!0123456789]*) ticketStall=3600 ;; esac
	## THE LINE'S OWN LOAD: every waiter judges every ticket ahead of it at every pass. Each judgement here is shell reads and
	## at most one process (the ps of a named pid), never a process per field: with a long line and many waiters the sed, date
	## and tail per field were hundreds of processes a second on the machine (S12).
	while IFS='=' read -r ticketKey ticketValue ; do
		case "$ticketKey" in
			session) [ -n "$ticketSession" ] || ticketSession="$ticketValue" ;;
			since) [ -n "$ticketSince" ] || ticketSince="$ticketValue" ;;
			pid) [ -n "$ticketPid" ] || ticketPid="$ticketValue" ;;
			pstart) [ -n "$ticketPstart" ] || ticketPstart="$ticketValue" ;;
			turn-won) [ -n "$ticketWon" ] || ticketWon="$ticketValue" ;;
		esac
	done 2> /dev/null < "$1"
	## A ticket with no session line was never written whole, and holds nobody's place.
	[ -n "$ticketSession" ] || { printf 'gone' ; return 0 ; }
	case "$ticketSession" in *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-]*) printf 'gone' ; return 0 ;; esac
	if [ -n "$rigQueueSession" ] && [ "$ticketSession" = "$rigQueueSession" ] ; then printf 'own' ; return 0 ; fi
	## The round's clock, set once per pass by the waiter; a reader called alone takes its own.
	ticketClock="${rigQueueClock:-}"
	case "$ticketClock" in ''|*[!0123456789]*) ticketClock="$( date +%s )" || { printf 'alive' ; return 0 ; } ;; esac
	## A ticket that names a run is given up when this workspace's records say that run has ended (a glob over the records, no
	## process). One naming `none` is judged by its own age and beat: no record of a run with no id is no evidence that the place is unheld.
	if [ "$ticketSession" != none ] ; then
		rigQueueSessionEnded "$ticketSession" && { printf 'ended' ; return 0 ; }
	fi
	## THE HOLD LIMIT FIRST, from the second the ticket joined the line: the first field of its name, `<epoch>.<micro>.<pid>.ticket`,
	## zero-padded and so read in base ten (a leading zero is octal to the shell), with no process; a name that carries no epoch (a
	## ticket made by hand) is dated by its `since`, one date process. A place held past the limit is given up, beating or not.
	ticketStamp="${1##*/}" ; ticketStamp="${ticketStamp%%.*}"
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
	## A ticket that names its process is given up where that process is gone, or where the number now belongs to a process that started at another
	## moment. A ticket of a run, which names none, is judged as before.
	if [ -n "$ticketPid" ] && [ -n "$ticketPstart" ] ; then
		[ "$( ps -o lstart= -p "$ticketPid" 2> /dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ //;s/ $//' )" = "$ticketPstart" ] || { printf 'gone' ; return 0 ; }
	fi
	## A holder that has won its turn writes `turn-won=<epoch>` and is at work, not waiting: it writes no beat any more, so a stale beat is no evidence that it
	## stopped. Only the hold limit, counted from the turn it won, ends its place.
	case "$ticketWon" in
		''|*[!0123456789]*) ;;
		*) [ "$(( ticketClock - ticketWon ))" -le "$ticketHold" ] && printf 'alive' || printf 'held' ; return 0 ;;
	esac
	## A run that stopped waiting gives up the place a process alone would go on holding. A ticket with no beat at all
	## carries no evidence that its holder stopped, so the hold limit above alone judges it.
	[ -n "$ticketBeat" ] || { printf 'alive' ; return 0 ; }
	[ "$(( ticketClock - ticketBeat ))" -le "$ticketStall" ] && printf 'alive' || printf 'stalled'
}

rigQueueInsideRun(){ ## -- rc 0 when this check runs inside a run of the tests, whose turn it is already in
	local ancestorPid="$$" ancestorAround=0
	while [ -n "$ancestorPid" ] && [ "$ancestorAround" -lt 64 ] ; do
		case "$( ps -p "$ancestorPid" -ww -o args= 2>/dev/null )" in
			*AgentsRunTests.sh*) return 0 ;;
		esac
		ancestorPid="$( ps -o ppid= -p "$ancestorPid" 2> /dev/null | LC_ALL=C tr -d ' ' )"
		ancestorAround=$(( ancestorAround + 1 ))
	done
	return 1
}

## THE WALL-CLOCK LIMIT OF A CHECK (S12.14). A check started by hand takes its turn in the machine's line and holds it for as long as it likes,
## and the runner's own `-t` covers only the tests a run starts. So the turn sets a deadline for the check it was called by, and a check that
## stands still is ended by its own work rather than found by a person hours later. MDAT_SUITE_CHECK_LIMIT_SECONDS (900) is the limit.
## A check inside a run takes no deadline of its own: the run's `-t` and its stall watch already cover it.
## The deadline is set when this fixture is sourced, which is the first line of a check: a value made inside rigTempDir could not reach the
## check, since that call is a command substitution.
rigCheckDeadline=""
[ -n "${MDAT_SUITE_QUEUE_TURN:-}" ] || rigCheckDeadline=$(( $( date +%s ) + ${MDAT_SUITE_CHECK_LIMIT_SECONDS:-900} ))
rigCheckSecondsLeft(){ ## -- the seconds this check has left before its deadline, or 0 where none is set or it has passed
	local leftSeconds
	case "${rigCheckDeadline:-}" in
		''|*[!0123456789]*) printf '0\n' ; return 0 ;;
	esac
	leftSeconds=$(( rigCheckDeadline - $( date +%s ) ))
	[ "$leftSeconds" -ge 0 ] || leftSeconds=0
	printf '%s\n' "$leftSeconds"
}

rigQueueTurn(){ ## -- waits its turn in the machine's line; says once in one line whom it waits behind
	local turnStamp turnTicket turnFile turnAhead turnWhom turnState turnSaid="" turnSleep rigQueueClock=""
	## A test the runner started is inside the run's own turn (AgentsRunTests.sh exports MDAT_SUITE_QUEUE_TURN), and so is
	## a check a test starts: taking a ticket there would wait behind a run that is itself waiting for this test, which is
	## a deadlock of the whole line. The run's turn already covers everything under it.
	[ -z "${MDAT_SUITE_QUEUE_TURN:-}" ] || return 0
	rigQueueInsideRun && return 0
	mkdir -p "$rigQueueDir" 2> /dev/null || {
		echo "⛔ ERROR: $0: cannot create the machine's line of test runs: $rigQueueDir -- no check is started outside its turn" >&2
		return 1
	}
	turnStamp="$( python3 -I -B -c 'import time; print("%017.6f" % time.time(), end="")' 2> /dev/null )" || turnStamp=""
	[ -n "$turnStamp" ] || turnStamp="$( date +%s ).000000"
	turnTicket="$turnStamp.$$.ticket"
	## The ticket names the check's process by its pid and its start, so a ticket whose check was killed or stopped is given up at once, and a pid
	## handed to another process later is never read as the holder (rigQueueTicketState).
	printf 'session=%s\norigin=%s\nkind=check\nsince=%s\npid=%s\npstart=%s\n' "${rigQueueSession:-none}" "${MDLT_ORIGIN:-}" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" "$$" "$( ps -o lstart= -p "$$" 2> /dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ //;s/ $//' )" > "$rigQueueDir/.$turnTicket" 2> /dev/null \
		&& mv -f "$rigQueueDir/.$turnTicket" "$rigQueueDir/$turnTicket" 2> /dev/null || {
		echo "⛔ ERROR: $0: cannot stand in the machine's line of test runs: $rigQueueDir" >&2
		return 1
	}
	while : ; do
		turnAhead=0 ; turnWhom=""
		## one clock per pass, read by every judgement of it; the beat of a waiting ticket is that second, written over at every pass,
		## so a holder that stops beating gives up its place while its run lives, and the beat file stays one line
		rigQueueClock="$( date +%s )" || rigQueueClock=""
		printf '%s\n' "$rigQueueClock" > "$rigQueueDir/$turnTicket.beat" 2> /dev/null || :
		for turnFile in "$rigQueueDir"/*.ticket ; do
			[ -f "$turnFile" ] || continue
			[ "${turnFile##*/}" \< "$turnTicket" ] || continue
			turnState="$( rigQueueTicketState "$turnFile" )"
			case "$turnState" in
				own) continue ;;
				alive) ;;
				*) ## `gone`, `ended`, `held` and `stalled`: a place given up, taken back here, and said of the ones a reader must know
					[ "$turnState" = gone ] || echo "# $0: a place given up in the line, so this one stands no longer behind it: $( rigQueueTicketWhom "$turnFile" )" >&2
					rm -f "$turnFile" "$turnFile.beat" ; continue
				;;
			esac
			turnAhead=$(( turnAhead + 1 ))
			[ -n "$turnWhom" ] || turnWhom="$( rigQueueTicketWhom "$turnFile" )"
		done
		## the turn won: the holder is at work and beats no more, so its beat file goes; the ticket stays until a later waiter judges it gone
		[ "$turnAhead" -gt 0 ] || { printf 'turn-won=%s\n' "${rigQueueClock:-$( date +%s )}" >> "$rigQueueDir/$turnTicket" 2> /dev/null || : ; rm -f "$rigQueueDir/$turnTicket.beat" 2> /dev/null ; break ; }
		## said once each time whom it waits behind changes: the age is left out of that comparison, since it moves every pass
		if [ "${turnWhom%, in the line for *}" != "$turnSaid" ] ; then
			echo "# $0: one check runs on this machine at a time -- this one waits its turn behind $turnWhom" >&2
			turnSaid="${turnWhom%, in the line for *}"
		fi
		## the pass is slower the longer the line: a waiter far back has nothing to gain from a quick look, and a long line
		## looked at quickly by every waiter is load on the very machine the line protects
		turnSleep=$(( 5 + turnAhead * 3 )) ; [ "$turnSleep" -le 30 ] || turnSleep=30
		sleep "$turnSleep"
	done
	return 0
}

## A RIG'S COMMS SERVICE THREAD (the owner's design: a Wait reads the cache the service threads fill, and never a service itself). A
## check whose Wait reads a fake Slack starts the rig's thread first, with the rig's own environment given as NAME=value words (its PATH
## with the fake curl, MMDAPP, MDAT_DATA_ROOT, MDAT_SKILLSET_ROOT), so the thread pulls through that Slack and the Wait's probes are served
## within their bound. The thread is noted with when it began (rig-processes.include.sh) and ended by rigCommsThreadEnd, from the trap.
rigCommsThreadPids=""
rigCommsThreadStart(){ ## env words, NAME=value, the rig's own
	local threadLog threadPid
	type rigProcNote > /dev/null 2>&1 || . "$( dirname "${BASH_SOURCE[0]}" )/rig-processes.include.sh" 2> /dev/null || :
	threadLog="${rigTmp:-${TMPDIR:-/tmp}}/rig-comms-thread.log"
	env -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS -u CLAUDE_CODE_SESSION_ID "$@" \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-session-comms --run >> "$threadLog" 2>&1 < /dev/null &
	threadPid=$!
	rigCommsThreadPids="$rigCommsThreadPids $threadPid"
	! type rigProcNote > /dev/null 2>&1 || rigProcNote "$threadPid"
	## The thread is up once it holds its lock and has written its first pass: waited for, up to eight seconds, so a want that follows
	## wakes a thread that is there and is not a second start racing it for the lock.
	local threadMmdapp="" threadWord threadLeft=40
	for threadWord in "$@" ; do case "$threadWord" in MMDAPP=*) threadMmdapp="${threadWord#MMDAPP=}" ;; esac ; done
	while [ "$threadLeft" -gt 0 ] ; do
		[ -n "$threadMmdapp" ] && [ -e "$threadMmdapp/.local/agents/comms/lock" ] && LC_ALL=C grep -q 'runs as pid' "$threadMmdapp/.local/agents/comms/log" 2> /dev/null && break
		sleep 0.2 ; threadLeft=$(( threadLeft - 1 ))
	done
	sleep 1
}
rigCommsThreadEnd(){
	local threadPid
	for threadPid in $rigCommsThreadPids ; do
		if type rigProcSignal > /dev/null 2>&1 ; then rigProcSignal TERM "$threadPid" ; else kill -TERM "$threadPid" 2> /dev/null ; fi
	done
	rigCommsThreadPids=""
}

rigTempDir(){
	if [ -z "${MMDAPP:-}" ] || [ ! -d "$MMDAPP" ] ; then
		echo "⛔ ERROR: MMDAPP names no workspace, so this rig has no place to live -- the system temp folder is never used; refusing to report a result" >&2
		return 1
	fi
	if [ -n "${MDAT_DATA_ROOT:-}" ] ; then
		case "$( cd "$MMDAPP" && pwd -P )/" in
			"$( cd "$MDAT_DATA_ROOT" 2> /dev/null && pwd -P )/"*)
				echo "⛔ ERROR: MMDAPP is the team-data store, or inside it, so a rig placed there would be committed into the shared store; refusing to report a result" >&2
				return 1
			;;
		esac
	fi
	rigQueueTurn || return 1
	mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || return 1
	mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/$1.XXXXXXXX"
}

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-copy.include.sh" || return 1
