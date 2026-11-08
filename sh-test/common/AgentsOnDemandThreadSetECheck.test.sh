#!/usr/bin/env bash
## Behavioural check on a service thread whose tick or handler leaves `set -e` on (board task 20261106T0900Z, S12.14;
## `AgentsToolsOnDemandThreadServe` in AgentsTools.OnDemandThread.include). The thread runs with `set +e +u` and calls its tick and its
## handler unguarded in the first draft: a handler that ran `set -e` left it on, and the next non-zero status ended the thread with no end
## line, so nothing said it had died. Held, run rather than read:
##   1. A TICK THAT TURNS `set -e` ON AND FAILS LEAVES THE THREAD ALIVE: a later tick still runs.
##   2. AND THE THREAD STILL WRITES ITS END LINE, on TERM, naming the signal.
##   3. A HANDLER THAT TURNS `set -e` ON AND FAILS LEAVES IT ALIVE TOO, and the answer still reaches its caller.
##   4. AND THAT THREAD WRITES ITS END LINE as well.
## The real serve function runs in a process of its own, over a folder of this rig's own; the tick and the handler are the rig's.
## RED RECIPE, measured on a copy under this check's own scratch on 2026-11-06: change the tick call at :278 to `"$serveTick" ; serveRc=$?`
## and the handler calls at :262 and :264 to drop their `||`, and rows 1 to 4 fail: the thread ends at the first failing tick.
## Offline: the include this check loads, a rig of its own, and no spawner, git or network.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/common/AgentsTools.OnDemandThread.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the on-demand thread include is not at $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOnDemandThreadSetECheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
## THE SERVE RUNS IN A PROCESS OF ITS OWN: the folder, the idle bound, and the two functions are the rig's, written to a prelude so the
## failing tick and the failing handler are the code the check reads rather than a string inside a command line.
cat > "$rigTmp/prelude.sh" <<'PRELUDE'
. "$RIG_INCLUDE" || exit 1
rigTick(){
	printf 'tick\n' >> "$RIG_TICKS"
	set -e
	false
}
rigHandler(){
	printf 'handler\n' >> "$RIG_HANDLED"
	set -e
	false
	printf 'answer\n' >&3
}
rigExitHandler(){
	printf 'handler\n' >> "$RIG_HANDLED"
	exit 3
}
PRELUDE
## ONE THREAD, STARTED APART AND WATCHED. Its own start is noted, because it is signalled later and a number is given again.
rigServe(){ ## the folder, the handler name, the tick name
	RIG_INCLUDE="$rigInclude" RIG_TICKS="$rigTmp/ticks" RIG_HANDLED="$rigTmp/handled" \
		bash -c '. "$1" ; shift ; AgentsToolsOnDemandThreadServe "$1" 120 "$2" "$3" no' rig-serve "$rigTmp/prelude.sh" "$@" \
		>> "$rigTmp/thread.log" 2>&1 &
	rigServePid="$!"
	rigProcNote "$rigServePid"
	rigLeft=100
	while [ ! -s "$1/thread.lock" ] && [ "$rigLeft" -gt 0 ] ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
	## The request fifo is made after the lock is taken, so a request written before it stands is a redirection onto nothing.
	rigLeft=100
	while [ ! -p "$1/request.fifo" ] && [ "$rigLeft" -gt 0 ] ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
}
rigAlive(){ kill -0 "$rigServePid" 2> /dev/null && printf alive || printf gone ; }
## A request with no reply field beyond `-`: the thread calls its handler and answers nobody, which is the handler's own question here.
rigRequest(){ ## the folder, then the words of the request
	printf '%s\t-\n' "$2" > "$1/request.fifo" 2> /dev/null || :
}
rigAwait(){ ## the file, then how many lines it must reach
	local awaitLeft=200
	while [ "$( LC_ALL=C grep -c . "$1" 2> /dev/null || : )" -lt "$2" ] && [ "$awaitLeft" -gt 0 ] ; do sleep 0.1 ; awaitLeft=$(( awaitLeft - 1 )) ; done
	LC_ALL=C grep -c . "$1" 2> /dev/null || :
}

echo "-- 1. a tick that turns set -e on and fails leaves the thread alive --"
rigFolder="$rigTmp/thread-a"
: > "$rigTmp/ticks"
rigServe "$rigFolder" - rigTick
rigAssert "the thread ran its failing tick more than once, so it survived the first" "$( rigAwait "$rigTmp/ticks" 2 )" 2
rigAssert "and it is still the process that runs" "$( rigAlive )" alive

echo "-- 2. and it still writes its end line --"
rigProcSignal TERM "$rigServePid" || :
rigLeft=100
while [ "$( rigAlive )" = alive ] && [ "$rigLeft" -gt 0 ] ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "the thread ended on TERM" "$( rigAlive )" gone
rigAssert "and its log carries the end line naming the signal" \
	"$( LC_ALL=C grep -c 'the thread, pid [0-9]*, ends: it was ended by TERM' "$rigTmp/thread.log" || : )" 1

echo "-- 3. a handler that turns set -e on and fails leaves it alive too --"
rigFolder="$rigTmp/thread-b"
: > "$rigTmp/handled"
rigServe "$rigFolder" rigHandler -
rigRequest "$rigFolder" one
rigRequest "$rigFolder" two
rigAssert "the thread served its failing handler twice" "$( rigAwait "$rigTmp/handled" 2 )" 2
rigAssert "and it is still the process that runs" "$( rigAlive )" alive

echo "-- 4. and that thread writes its end line as well --"
rigProcSignal TERM "$rigServePid" || :
rigLeft=100
while [ "$( rigAlive )" = alive ] && [ "$rigLeft" -gt 0 ] ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "the second thread ended on TERM" "$( rigAlive )" gone
rigAssert "and its log carries its end line too" \
	"$( LC_ALL=C grep -c 'the thread, pid [0-9]*, ends: it was ended by TERM' "$rigTmp/thread.log" || : )" 2

echo "-- 5. a handler that calls exit still gives the lock back and writes an end line --"
rigFolder="$rigTmp/thread-c"
: > "$rigTmp/handled"
rigServe "$rigFolder" rigExitHandler -
rigRequest "$rigFolder" one
rigAwait "$rigTmp/handled" 1 > /dev/null
rigLeft=100
while [ "$( rigAlive )" = alive ] && [ "$rigLeft" -gt 0 ] ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "the thread ended with its handler's exit" "$( rigAlive )" gone
rigAssert "its lock is given back, not left naming a dead process" "$( [ -s "$rigFolder/thread.lock" ] && printf left || printf given )" given
rigAssert "and its log carries an end line that says a handler ended it" \
	"$( LC_ALL=C grep -c 'the thread, pid [0-9][0-9]*, ends: a handler or a tick ended the process' "$rigTmp/thread.log" || : )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ON DEMAND THREAD SET -E CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'ON_DEMAND_THREAD_SET_E: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
