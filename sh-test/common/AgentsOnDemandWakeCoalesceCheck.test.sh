#!/usr/bin/env bash
## Behavioural check of the fire-and-forget ask of an on-demand thread (AgentsToolsOnDemandThreadAsk with the bound `-`, and the
## thread's AgentsToolsOnDemandThreadServe): a wake identical to one already waiting is not written again, so a thread slower than
## its writers never fills its fifo and no writer waits on a full one. Held:
##   1. with no thread reading, ten thousand identical asks all return, inside the bound of the check
##   2. control: the one wake left in the fifo is served by a thread started afterwards
##   3. a slow thread given a burst of thirty identical wakes runs its handler a few times, not thirty
##   4. different requests are each served
## Red before the change: every ask writes its line, so a fifo nobody drains fills and the next ask waits on it for good.
## Offline: a rig folder of this check's own; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOnDemandWakeCoalesceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigServer=""
trap '[ -z "$rigServer" ] || kill "$rigServer" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigFolder="$rigTmp/thread"
mkdir -p "$rigFolder" && mkfifo "$rigFolder/request.fifo" || exit 1
## The thread of this rig: each request served is one line of the served file, and the handler takes a second, a slow thread.
rigServe(){ ## idle seconds
	bash -c '
		. "$1/sh-lib/common/AgentsTools.OnDemandThread.include" || exit 1
		rigServed="$3/served"
		rigHandler(){ printf "%s\n" "$*" >> "$rigServed" ; sleep 1 ; }
		AgentsToolsOnDemandThreadServe "$2" "$4" rigHandler - no
	' rig "$rigPkg" "$rigFolder" "$rigTmp" "$1" > /dev/null 2>&1 &
	rigServer="$!"
}
## A server still running past its bound is stopped here, so the check leaves no process behind.
rigStop(){
	[ -n "$rigServer" ] || return 0
	kill -0 "$rigServer" 2> /dev/null && { kill "$rigServer" 2> /dev/null || : ; }
	wait "$rigServer" 2> /dev/null || :
	rigServer=""
}
rigAsks(){ ## count, the request fields...
	local asksCount="$1" ; shift
	bash -c '
		. "$1/sh-lib/common/AgentsTools.OnDemandThread.include" || exit 1
		asksFolder="$2" ; asksCount="$3" ; shift 3
		asksAt=0 ; while [ "$asksAt" -lt "$asksCount" ] ; do AgentsToolsOnDemandThreadAsk "$asksFolder" - "$@" ; asksAt=$(( asksAt + 1 )) ; done
		printf "returned\n"
	' rig "$rigPkg" "$rigFolder" "$asksCount" "$@" 2> /dev/null
}

echo "-- 1. no thread reading: every ask returns --"
## The fifo is held open here, as the writers of a rig hold it, so what is written to it stays until a reader takes it.
exec 6<> "$rigFolder/request.fifo" || exit 1
rigAsks 10000 commit > "$rigTmp/asks.out" &
rigAsker="$!"
rigWaited=0 ; while kill -0 "$rigAsker" 2> /dev/null && [ "$rigWaited" -lt 60 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
if kill -0 "$rigAsker" 2> /dev/null ; then kill "$rigAsker" 2> /dev/null ; wait "$rigAsker" 2> /dev/null ; rigBlocked="blocked after ${rigWaited}s" ; else wait "$rigAsker" 2> /dev/null ; rigBlocked="$( cat "$rigTmp/asks.out" )" ; fi
rigAssert "ten thousand identical asks with no reader all return" "$rigBlocked" returned

echo "-- 2. control: the wake left waiting is served by a thread started afterwards --"
: > "$rigTmp/served"
rigServe 3
sleep 5
rigAssert "the waiting wake was served" "$( [ "$( LC_ALL=C grep -c '^commit$' "$rigTmp/served" )" -ge 1 ] && echo served || echo none )" served
rigStop

echo "-- 3. a slow thread and a burst of identical wakes --"
: > "$rigTmp/served"
rigServe 3
sleep 1
rigAsks 30 commit > /dev/null
rigWaited=0 ; while kill -0 "$rigServer" 2> /dev/null && [ "$rigWaited" -lt 90 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigStop
rigRuns="$( LC_ALL=C grep -c '^commit$' "$rigTmp/served" )"
rigAssert "thirty identical wakes run the handler a few times, not thirty ($rigRuns)" "$( [ "$rigRuns" -ge 1 ] && [ "$rigRuns" -le 3 ] && echo few || echo many )" few

echo "-- 4. different requests are each served --"
: > "$rigTmp/served"
rigServe 3
sleep 1
rigAsks 1 commit > /dev/null ; rigAsks 1 other > /dev/null
rigWaited=0 ; while kill -0 "$rigServer" 2> /dev/null && [ "$rigWaited" -lt 30 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigStop
rigAssert "a different request is served beside the first" "$( LC_ALL=C sort -u "$rigTmp/served" | LC_ALL=C tr '\n' ' ' )" "commit other "

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ ON-DEMAND WAKE COALESCE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'ON_DEMAND_WAKE_COALESCE: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
