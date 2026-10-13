#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The one way a check of sh-test signals a process it started and kept for later. Sourced by
## the check, before its rig puts anything of its own on PATH:
##   . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.test.sh"
##
## WHY. A process id is a number the system gives again. On a busy host the numbers come
## round in about a minute (2026-10-13: about 1600 new processes a second while tests ran,
## and the table holds 99998). A check that keeps the pid of a stand-in in a variable or a
## file and signals it minutes later, in a cleanup or in a trap, signals whatever process has
## that number then: a helper of another test run, a member's agent, the owner's own program.
## A plain `kill <pid>` ends that stranger, `pkill -P <pid>` what it started, and
## `kill -- -<pid>` its whole process group.
##
## HOW. A process is noted with when it began, as the tooling itself keeps a process
## (`<pid> <start>`, AgentsToolsRegistryProcessesBegan of sh-lib/AgentsTools.Registries.include:
## that reading and no second one), and is signalled only while its pid is still the process
## that began then. The same pid begun at another time is another process, and one that is
## gone is nothing: neither is signalled. A process is noted right after it is started, by
## the shell that started it (`$!`), or by itself where the tooling under test started it (a
## stand-in console notes itself into a file). A pid that was never noted is never signalled.
##
##   rigProcNote <pid>...                  notes each process, as it is now, in this shell
##   rigProcNoteFile <file> <pid>...       the same note, kept in a file: for a stand-in that notes
##                                         itself, and for a note that must outlast its shell
##   rigProcNoteFrom <file>...             takes the notes of those files for this shell's own
##   rigProcSignal <signal> <pid>...       signals each that is still the process noted
##   rigProcSignalWithChildren <signal> <pid>...
##                                         the same, and with each the processes it has started,
##                                         read at that moment: the process first, so that it does
##                                         not go on once what it waited for is gone
##   rigProcSignalKept <signal> <file>...  signals each process those files note that is still itself
##   rigProcGroupSignal <signal> <group id>...
##                                         signals a process group the check made itself (a job
##                                         started under `set -m`, a stand-in that leads a group)
##                                         only where it shows the group to be its own still: a
##                                         process it noted, the leader or any other, is at that
##                                         moment the same process and a member of that group.
##                                         Every member is then noted, so the next signal to the
##                                         group is shown by any of them that is left. Signal 0
##                                         sends nothing and notes the members. A group none of whose
##                                         members was ever noted, and the group the check itself
##                                         runs in, are never signalled.
## The signal is a name or a number without its dash (TERM, KILL, HUP, INT, 9). Each signalling
## function ends 0 where it signalled something and 1 where it found nothing of its own to signal,
## as `kill` does; none says anything.
##
## The notes are a variable of the shell that took them: a subshell has those of its starter
## and keeps its own to itself. A watchdog (`( sleep 900 ; rigProcSignal TERM $$ ) &`) so has
## the note of the check it guards, taken before it was started, and ends that check and no
## later holder of its number.
##
## What is left unproved, and is not signalled: a group whose noted members are all gone while
## others it started remain; a process that was gone before it could be noted.
## sh-test/AgentsTestSignalsCheck.test.sh is the check of this file, and the guard over every
## signal of sh-test that does not go through it.

rigProcNoted="${rigProcNoted:-}"
## ps and awk of the host as this file was sourced, never a rig's own, which stand first on PATH later
rigProcPath="${rigProcPath:-$PATH}"
rigProcHere="$( cd "$( dirname "${BASH_SOURCE[0]}" )" 2> /dev/null && pwd -P )" || rigProcHere=""

## When each of the processes given began, `<pid> <start>` a line, for those that are processes
## now. The tooling's own reading, in a shell of its own: nothing of the tooling is defined in
## the check, and nothing the check defines stands in for a command of the reading.
rigProcBegan(){ ## pid...
	[ $# -gt 0 ] && [ -n "$rigProcHere" ] || return 0
	(
		set +e +u
		PATH="$rigProcPath" ; export PATH
		[ -n "${MDLT_ORIGIN:-}" ] || { MDLT_ORIGIN="${rigProcHere%/myx/myx.distro-agents/sh-test/check-fixtures}" ; export MDLT_ORIGIN ; }
		unset -f ps awk 2> /dev/null
		. "$rigProcHere/../../sh-lib/AgentsTools.Registries.include" || exit 0
		beganLines="$( printf '%s\n' "$@" | AgentsToolsRegistryProcessesBegan )"
		## one number that is no process id leaves the whole reading empty: then each by itself
		if [ -z "$beganLines" ] && [ $# -gt 1 ] ; then
			for beganPid in "$@" ; do printf '%s\n' "$beganPid" | AgentsToolsRegistryProcessesBegan ; done
		else
			[ -z "$beganLines" ] || printf '%s\n' "$beganLines"
		fi
	) 2> /dev/null
	return 0
}

rigProcNote(){ ## pid...
	local noteLines
	noteLines="$( rigProcBegan "$@" )" || noteLines=""
	[ -z "$noteLines" ] || rigProcNoted="$rigProcNoted${rigProcNoted:+
}$noteLines"
	return 0
}

rigProcNoteFile(){ ## file, pid...
	local fileName="$1" fileLines ; shift
	fileLines="$( rigProcBegan "$@" )" || fileLines=""
	[ -z "$fileLines" ] || printf '%s\n' "$fileLines" >> "$fileName"
	return 0
}

rigProcNoteFrom(){ ## file...
	local fromLines
	fromLines="$( cat "$@" 2> /dev/null | PATH="$rigProcPath" LC_ALL=C awk 'NF == 2 && $1 ~ /^[0-9]+$/' )" || fromLines=""
	[ -z "$fromLines" ] || rigProcNoted="$rigProcNoted${rigProcNoted:+
}$fromLines"
	return 0
}

## Which of the pids given are still the processes noted, a pid a line.
rigProcStill(){ ## pid...
	local stillNow
	[ $# -gt 0 ] && [ -n "$rigProcNoted" ] || return 0
	stillNow="$( rigProcBegan "$@" )" || stillNow=""
	[ -n "$stillNow" ] || return 0
	{ printf '%s\n' "$rigProcNoted" ; printf '=\n%s\n' "$stillNow" ; } \
		| PATH="$rigProcPath" LC_ALL=C awk '$0 == "=" { stillRead = 1 ; next ; } ! stillRead { stillNoted[$0] = 1 ; next ; } ( $0 in stillNoted ) && ! stillSaid[$1]++ { print $1 ; }'
	return 0
}

rigProcSignal(){ ## signal, pid...
	local signalName="${1:-}" signalPids
	[ $# -gt 1 ] || return 1
	shift
	signalPids="$( rigProcStill "$@" )" || signalPids=""
	[ -n "$signalPids" ] || return 1
	builtin kill "-$signalName" $signalPids 2> /dev/null
	return 0
}

rigProcSignalWithChildren(){ ## signal, pid...
	local withName="${1:-}" withPids withKids
	[ $# -gt 1 ] || return 1
	shift
	withPids="$( rigProcStill "$@" )" || withPids=""
	[ -n "$withPids" ] || return 1
	## read while the processes are still themselves: what stands under them now is theirs
	withKids="$( PATH="$rigProcPath" ps -A -o pid=,ppid= 2> /dev/null | PATH="$rigProcPath" LC_ALL=C awk -v withParents=" $( printf '%s ' $withPids )" 'index( withParents, " " $2 " " ) { print $1 ; }' )" || withKids=""
	builtin kill "-$withName" $withPids $withKids 2> /dev/null
	return 0
}

rigProcSignalKept(){ ## signal, file...
	local keptName="${1:-}" keptPids
	[ $# -gt 1 ] || return 1
	shift
	rigProcNoteFrom "$@"
	keptPids="$( cat "$@" 2> /dev/null | PATH="$rigProcPath" LC_ALL=C awk 'NF == 2 && $1 ~ /^[0-9]+$/ { print $1 ; }' )" || keptPids=""
	[ -n "$keptPids" ] || return 1
	rigProcSignal "$keptName" $keptPids
}

rigProcGroupSignal(){ ## signal, group id...
	local groupName="${1:-}" groupId groupMembers groupBegan groupOwn groupSent=1
	[ $# -gt 1 ] || return 1
	shift
	for groupId in "$@" ; do
		case "$groupId" in ''|*[!0123456789]*|0|1) continue ;; esac
		[ -n "$rigProcNoted" ] || continue
		groupMembers="$( PATH="$rigProcPath" ps -A -o pid=,pgid= 2> /dev/null | PATH="$rigProcPath" LC_ALL=C awk -v wantGroup="$groupId" '$2 == wantGroup { print $1 ; }' )" || groupMembers=""
		[ -n "$groupMembers" ] || continue
		## never the group this check itself runs in, whatever was noted
		case " $( printf '%s ' $groupMembers )" in *" $$ "*) continue ;; esac
		groupBegan="$( rigProcBegan $groupMembers )" || groupBegan=""
		[ -n "$groupBegan" ] || continue
		## its own still: one of its members is a process this check noted, the same now as then
		groupOwn="$( { printf '%s\n' "$rigProcNoted" ; printf '=\n%s\n' "$groupBegan" ; } \
			| PATH="$rigProcPath" LC_ALL=C awk '$0 == "=" { groupRead = 1 ; next ; } ! groupRead { groupNoted[$0] = 1 ; next ; } ( $0 in groupNoted ) { print "own" ; exit ; }' )" || groupOwn=""
		[ "$groupOwn" = "own" ] || continue
		rigProcNoted="$rigProcNoted
$groupBegan"
		builtin kill "-$groupName" -- "-$groupId" 2> /dev/null && groupSent=0
	done
	return "$groupSent"
}
