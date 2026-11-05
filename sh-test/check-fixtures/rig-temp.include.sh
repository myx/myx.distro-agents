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
## HOW THE TURN IS KEPT AND GIVEN BACK. A ticket is a file named by its arrival time, holding the pid of the check
## that took it. No trap gives it back: whoever waits behind a ticket whose process is gone removes it, so a check
## killed outright leaves nothing standing in the line. A ticket held by a process above the waiter is no ticket
## ahead: a check that starts a full suite, and the tests of a suite, run inside that very turn and never wait for
## themselves. A test a run started takes no ticket at all (MDAT_SUITE_QUEUE_TURN, which the runner exports).
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

rigQueueTicketState(){ ## ticket file, ancestors -- `alive`, `own`, `stale` or `gone`
	local ticketPid ticketSince ticketStamp ticketClock ticketCpu ticketWas ticketAge
	ticketPid="$( LC_ALL=C sed -n 's/^pid=//p' "$1" 2> /dev/null | LC_ALL=C sed -n 1p )"
	case "$ticketPid" in ''|*[!0123456789]*) printf 'gone' ; return 0 ;; esac
	case " $2 " in *" $ticketPid "*) printf 'own' ; return 0 ;; esac
	kill -0 "$ticketPid" 2> /dev/null || { printf 'gone' ; return 0 ; }
	## A HOLDER THAT LIVES BUT HAS STOPPED IS NO HOLDER (S12.14). A runner alive with no CPU progress is one that cannot give its turn back: it
	## stood in the machine's line for over an hour on 2026-11-04 while every waiter stood behind it. The age is read from the ticket's own
	## `since:`, so a holder that arrived moments ago is never judged. Only a holder older than the bound is sampled at all, and then its CPU time
	## is read twice, a second apart: a holder that is working moves it.
	ticketSince="$( LC_ALL=C sed -n 's/^since=//p' "$1" 2> /dev/null | LC_ALL=C sed -n 1p )"
	ticketStamp="$( date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$ticketSince" '+%s' 2> /dev/null || date -u -d "$ticketSince" '+%s' 2> /dev/null )" || ticketStamp=""
	case "$ticketStamp" in ''|*[!0123456789]*) printf 'alive' ; return 0 ;; esac
	ticketClock="$( date +%s )" || { printf 'alive' ; return 0 ; }
	ticketAge=$(( ticketClock - ticketStamp ))
	[ "$ticketAge" -gt "${MDAT_SUITE_QUEUE_STALL_SECONDS:-3600}" ] || { printf 'alive' ; return 0 ; }
	ticketCpu="$( ps -o time= -p "$ticketPid" 2> /dev/null | LC_ALL=C tr -d ' ' )"
	case "$ticketCpu" in ''|*[!0123456789:.]*) printf 'alive' ; return 0 ;; esac
	sleep 1
	ticketWas="$( ps -o time= -p "$ticketPid" 2> /dev/null | LC_ALL=C tr -d ' ' )"
	case "$ticketWas" in ''|*[!0123456789:.]*) printf 'alive' ; return 0 ;; esac
	[ "$ticketCpu" = "$ticketWas" ] && printf 'stale' || printf 'alive'
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
	local turnStamp turnTicket turnFile turnAhead turnWhom turnState turnSaid="" turnAncestors
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
	printf 'pid=%s\norigin=%s\nkind=check\nsince=%s\n' "$$" "${MDLT_ORIGIN:-}" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$rigQueueDir/.$turnTicket" 2> /dev/null \
		&& mv -f "$rigQueueDir/.$turnTicket" "$rigQueueDir/$turnTicket" 2> /dev/null || {
		echo "⛔ ERROR: $0: cannot stand in the machine's line of test runs: $rigQueueDir" >&2
		return 1
	}
	while : ; do
		turnAhead=0 ; turnWhom="" ; turnAncestors="$( rigQueueAncestors )"
		for turnFile in "$rigQueueDir"/*.ticket ; do
			[ -f "$turnFile" ] || continue
			[ "${turnFile##*/}" \< "$turnTicket" ] || continue
			turnState="$( rigQueueTicketState "$turnFile" "$turnAncestors" )"
			case "$turnState" in
				gone|stale) rm -f "$turnFile" ; continue ;;
				own) continue ;;
			esac
			turnAhead=$(( turnAhead + 1 ))
			[ -n "$turnWhom" ] || turnWhom="the run of pid $( LC_ALL=C sed -n 's/^pid=//p' "$turnFile" 2> /dev/null | LC_ALL=C sed -n 1p ), in line since $( LC_ALL=C sed -n 's/^since=//p' "$turnFile" 2> /dev/null | LC_ALL=C sed -n 1p )"
		done
		[ "$turnAhead" -gt 0 ] || break
		if [ "$turnSaid" != "$turnWhom" ] ; then
			echo "# $0: one check runs on this machine at a time -- this one waits its turn behind $turnWhom" >&2
			turnSaid="$turnWhom"
		fi
		sleep 2
	done
	return 0
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
