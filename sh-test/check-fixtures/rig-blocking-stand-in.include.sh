#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The one way a check of sh-test keeps a stand-in run alive for as long as it needs it, and no longer.
## Sourced by the check before its rig puts anything of its own on PATH:
##   . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-blocking-stand-in.include.sh"
##
## WHY. A stand-in that spins (`while : ; do sleep 1 ; done`) burns a process and a wake-up a second for as long
## as it lives, and it lives past its check whenever the check does not end it: a kill, a timeout, a trap that
## never runs. That is the high-load practice the owner ruled out, and it came back: 32 such spinners were found
## on 2026-11-03, some 18 hours old, forked by four checks of this suite.
##
## HOW. Every stand-in blocks on a READ OF A PIPE and never polls. The check holds the writing end of that pipe
## on a file descriptor of its own; the stand-in reads. The kernel closes that descriptor when the check's process
## ends, however it ends -- a pass, a fail, a kill, a timeout -- and the read then returns end-of-file and the
## stand-in exits by itself. No trap is relied on, so nothing of the rig can outlive it.
##
##   rigBlockingStandInOpen          makes the pipe folder, under the rig's own tree
##   rigBlockingStandIn <spawn id>   starts one stand-in run; sets rigStandPid, and appends it to rigStandPids
##   rigBlockingStandInEnd <pid>...  ends those that are still the processes noted, through the process helper
##
## A stand-in's pid is kept in the shell that started it, never in a subshell: `rigStandPid="$( rigBlockingStandIn x )"`
## starts it in a subshell, which loses the note of its pid, and the stand-in is then nobody's to end.
## The command line carries `--session-id <spawn id>`, the one rule by which the tooling reads a run.
##
## The door is fd 7 of the check, taken once and closed for every stand-in at its start, so a stand-in holds no writing
## end and sees the end of file. One door serves every stand-in the check starts: a second pipe on the same descriptor
## would close the first, and end every stand-in behind it.
## Not a poll: a loop round a sleep is refused here by AgentsRunTestsLeakCheck.
##

rigStandDir="${rigStandDir:-}" rigStandPids="${rigStandPids:-}" rigStandPid=""
## One door for the whole check: every stand-in reads the same pipe, so a check may hold twenty of them and the door is
## opened once. A second pipe on the same file descriptor would close the first, and every stand-in behind it would end
## at once -- which is how a rig loses the process it meant to keep.
rigStandDoor=""

rigBlockingStandInOpen(){
	[ -n "$rigStandDoor" ] && return 0
	rigStandDir="${rigStandDir:-$rigTmp/stand-ins}"
	mkdir -p "$rigStandDir" || return 1
	rigStandDoor="$rigStandDir/door.$$.fifo"
	rm -f "$rigStandDoor" ; mkfifo "$rigStandDoor" 2> /dev/null || { rigStandDoor="" ; return 1 ; }
	## Held for reading and writing by this shell, so the open is no wait at all, and a stand-in that fails to start
	## never leaves the check blocked on a pipe nobody reads.
	exec 7<> "$rigStandDoor" || { rigStandDoor="" ; return 1 ; }
	return 0
}

rigBlockingStandIn(){ ## spawn id -- starts it, blocking on the door; sets rigStandPid
	local standId="$1"
	rigBlockingStandInOpen || return 1
	rigStandFifo="$rigStandDoor" "${rigStandBash:-bash}" -c 'exec 0<"$rigStandFifo" || exit 3 ; IFS= read -r rigStandLine ; exit 0' runner --session-id "$standId" 7>&- > /dev/null 2>&1 &
	rigStandPid=$!
	rigStandPids="$rigStandPids $rigStandPid"
	type rigProcNote > /dev/null 2>&1 && rigProcNote "$rigStandPid"
	return 0
}

rigBlockingStandInEnd(){ ## pid...
	type rigProcSignalWithChildren > /dev/null 2>&1 || return 0
	[ $# -gt 0 ] || return 0
	rigProcSignalWithChildren KILL "$@"
}

## The pipe says nothing: it is a door, and the end of the check opens it.
