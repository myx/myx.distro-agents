#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The one way a check of sh-test ends the control threads the tooling started in its rig. Sourced by the
## check, before its rig puts anything of its own on PATH, as the rig's process helper is, through which it
## signals (rig-processes.include.sh, sourced here where the check has not):
##   . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh"
##
## WHY. The control thread of a session is a detached process of the tooling that outlives the call that
## started it (sh-lib/session/AgentsTools.SessionControlStart.include), and the check with it. The advance input scan
## and each iteration of the main loop start the thread of every session of their workspace that is not finished
## and has none alive; the console's --manager-session-control-start starts one by name. In a rig that is any
## session with a run in the rig's process list, or with a record of this host still open. A thread whose rig
## is then removed never ends by itself: at its next tick it makes its folder again, finds no record to watch,
## and stays. So a check that calls one of those operations ends what they started before it removes its tree:
##   trap 'rigControlThreadsEnd "$rigTmp" ; ... ; rm -rf -- "$rigTmp"' EXIT
## sh-test/AgentsSessionControlStartCheck.test.sh holds this file, and is the guard over every check of sh-test
## that names one of those operations.
##
## HOW. A start writes the process it made, with when it began, into the log of the thread, control/log of the
## session's folder, before it returns; a thread that holds a session says the same in its pid file. Both are
## read as notes of the process helper, `<pid> <start>`, so a process is signalled only while its pid is still
## the process that began then: a pid another process has taken since is never signalled.
##
## AND THE COMMUNICATIONS READER (F9.3), the one detached process of the workspace that the spawner starts beside a
## session's control thread (sh-lib/session/AgentsTools.SessionComms.include): its start line is in comms/log of the
## workspace and its lock, comms/lock, names it, both read here the same way.
##
## AND THE THREAD OF THE SOURCES A SCAN READS (F4.2), the same: its start line is in collect/thread.log and its lock, collect/thread.lock,
## names it (sh-lib/comms/AgentsTools.CollectThread.include).
##
##   rigControlThreadNotes <dir>...   the notes found under those rig trees, `<pid> <start>` a line
##   rigControlThreadsEnd <dir>...    ends every such process that is still itself, with what it started (the
##                                    sleep it waits on), the hard way: nothing of it is wanted any more

type rigProcSignalWithChildren > /dev/null 2>&1 || . "$( cd "$( dirname "${BASH_SOURCE[0]}" )" 2> /dev/null && pwd -P )/rig-processes.include.sh"

rigControlThreadNotes(){ ## dir...
	[ $# -gt 0 ] || return 0
	PATH="$rigProcPath" find "$@" -path '*/control/log' -type f -exec cat {} + 2> /dev/null \
		| PATH="$rigProcPath" LC_ALL=C sed -n 's/^.* a start of the control thread of session .* is made: pid \([0-9][0-9]*\), begun \([^ ]*\)$/\1 \2/p'
	PATH="$rigProcPath" find "$@" -path '*/control/pid' -type f -exec cat {} + 2> /dev/null
	PATH="$rigProcPath" find "$@" -path '*/comms/log' -type f -exec cat {} + 2> /dev/null \
		| PATH="$rigProcPath" LC_ALL=C sed -n 's/^.* a start of the communications reader is made: pid \([0-9][0-9]*\), begun \([^ ]*\)$/\1 \2/p'
	PATH="$rigProcPath" find "$@" -path '*/comms/lock' -type l -exec readlink {} \; 2> /dev/null
	PATH="$rigProcPath" find "$@" -path '*/collect/thread.log' -type f -exec cat {} + 2> /dev/null \
		| PATH="$rigProcPath" LC_ALL=C sed -n 's/^.* a start of the source collector is made: pid \([0-9][0-9]*\), begun \([^ ]*\)$/\1 \2/p'
	PATH="$rigProcPath" find "$@" -path '*/collect/thread.lock' -type l -exec readlink {} \; 2> /dev/null
	return 0
}

rigControlThreadsEnd(){ ## dir...
	local endNotes endPids
	[ $# -gt 0 ] || return 0
	endNotes="$( rigControlThreadNotes "$@" | PATH="$rigProcPath" LC_ALL=C awk 'NF == 2 && $1 ~ /^[0-9]+$/ && ! endSaid[$0]++' )" || endNotes=""
	[ -n "$endNotes" ] || return 0
	rigProcNoted="$rigProcNoted${rigProcNoted:+
}$endNotes"
	endPids="$( printf '%s\n' "$endNotes" | PATH="$rigProcPath" LC_ALL=C awk '! endSaid[$1]++ { print $1 }' )" || endPids=""
	rigProcSignalWithChildren KILL $endPids
	return 0
}
