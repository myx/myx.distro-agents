#!/usr/bin/env bash
## Behavioural check on the stores that hold what a session leaves behind: the live list names threads that are still there, and a dead
## session's folder goes once nothing has written it for the days the runs keep. Held:
##   1. `AgentsToolsSessionLiveIds` prints an id only while its own pid file names a process that is still there, and drops one that is not
##   2. the reader spends one builtin a line: no process is started for a look
##   3. `AgentsToolsSessionStorePrune` removes an old folder whose thread is gone, and keeps one whose thread is live and one too new
##   4. `AgentsToolsSessionLivePrune` removes the line of a dead thread, keeps the line of a live one, and prints the count it removed
## Offline: a temp store of this check alone, removed at its end; no store of this machine is read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigHere/session" ] || rigRefuse "the session includes are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionRetentionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigStore="$rigTmp/ws"
mkdir -p "$rigStore/.local/agents/sessions" || rigRefuse "the probe store could not be made"

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## The session's own start, as the thread writes it: the process's lstart with its blanks as underscores.
rigStartOf(){ ## pid
	LC_ALL=C ps -o lstart= -p "$1" 2> /dev/null | LC_ALL=C awk 'NF { gsub( / /, "_" ) ; print ; exit ; }'
}
## A session folder with a state and a pid file of its own.
rigSession(){ ## id, pid, start
	mkdir -p "$rigStore/.local/agents/sessions/$1/control"
	printf 'state: running\n' > "$rigStore/.local/agents/sessions/$1/control/state"
	printf '%s %s\n' "$2" "$3" > "$rigStore/.local/agents/sessions/$1/control/pid"
}

## THIS SHELL IS THE LIVE THREAD: its pid is the one a live line names.
rigSession live-thread "$$" "$( rigStartOf $$ )"
rigSession dead-thread 999999 "Sat_Jan_01_00:00:00_2022"
rigSession old-dead 999998 "Sat_Jan_01_00:00:00_2022"
## The old folders are old on their own clocks; the third is a dead thread's, but written now.
touch -t 202001010000 "$rigStore/.local/agents/sessions/old-dead" "$rigStore/.local/agents/sessions/live-thread"
printf 'live-thread\ndead-thread\nold-dead\n' > "$rigStore/.local/agents/live-sessions"

echo "-- 1. the live list names threads that are still there --"
rigLive="$( MMDAPP="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" ; AgentsToolsSessionLiveIds' rig "$rigHere/session/AgentsTools.SessionStore.Paths.include" 2> /dev/null )" || rigLive=""
rigAssert "only the id whose pid is this shell comes back" "$( printf '%s\n' "$rigLive" | LC_ALL=C sort | tr '\n' ' ' )" "live-thread "

echo "-- 3. the sessions store: old and gone goes, live and new stay --"
rigGone="$( MMDAPP="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" ; . "$2" ; AgentsToolsSessionStorePrune 14 20' rig "$rigHere/session/AgentsTools.SessionStore.Write.include" "$rigHere/session/AgentsTools.SessionStore.Paths.include" 2> /dev/null )" || rigGone=""
rigAssert "one folder removed, and it says so"  "$rigGone" "1"
rigAssert "the folder of the dead and old thread is gone" "$( [ -e "$rigStore/.local/agents/sessions/old-dead" ] && printf here || printf gone )" "gone"
rigAssert "the live thread's folder stays"         "$( [ -e "$rigStore/.local/agents/sessions/live-thread" ] && printf here || printf gone )" "here"
rigAssert "the dead thread's folder, written now, stays" "$( [ -e "$rigStore/.local/agents/sessions/dead-thread" ] && printf here || printf gone )" "here"

echo "-- 4. the live list is pruned of a line that names no thread --"
rigPruned="$( MMDAPP="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" ; . "$2" ; AgentsToolsSessionLivePrune' rig "$rigHere/session/AgentsTools.SessionStore.Write.include" "$rigHere/session/AgentsTools.SessionStore.Paths.include" 2> /dev/null )" || rigPruned=""
rigAssert "the two dead lines are removed, and it says how many" "$rigPruned" "2"
rigAssert "the list holds the live thread alone"  "$( LC_ALL=C sort "$rigStore/.local/agents/live-sessions" | tr '\n' ' ' )" "live-thread "

echo "-- control: a store with no live list answers nothing --"
: > "$rigStore/.local/agents/live-sessions"
rigAssert "no line, no ids"  "$( MMDAPP="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" ; AgentsToolsSessionLiveIds' rig "$rigHere/session/AgentsTools.SessionStore.Paths.include" 2> /dev/null )" ""

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SESSION RETENTION CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	exit 1
fi
printf 'SESSION_RETENTION: OK (%d assertions, offline)\n' "$rigPass"
exit 0
