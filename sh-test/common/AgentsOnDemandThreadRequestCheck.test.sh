#!/usr/bin/env bash
## Behavioural check on S12.11 ruling 1: ONE shared ask path, `AgentsToolsOnDemandThreadRequest`, which asks the
## thread, starts one where none answers, and asks once more -- with the restart in that one place and in no
## caller's own loop.
##   1. a caller whose thread is not there yet is answered by ONE call, and its answer is the thread's own words
##   1b. the control, both directions: a path with no folder is rc 1, and a field holding a tab is refused, so a
##       green here is a reading and not an instrument that answers 0 to everything
##   2. against a living thread it asks, and starts no second one
##   3. a thread killed between two calls is started again by the next call, and answered
##   4. the comms ingest's own id batch goes through that one path, keeping no retry loop and no reply fifo
## Red before: the shared path is no function at all, so a caller has no one place to ask.
## Offline: every thread, fifo and workspace is under this rig's own temp folder, and the thread the rig starts is
## the event-id thread on a workspace of the rig's own, so nothing of the real cache is reached.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigInc="$rigPkg/sh-lib/common/AgentsTools.OnDemandThread.include"
rigComms="$rigPkg/sh-lib/comms/AgentsTools.CommsIngest.include"
[ -f "$rigInc" ] || { echo "⛔ ERROR: no thread include at $rigInc" >&2 ; exit 1 ; }
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOnDemandThreadRequestCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigThreadPids=""
rigThreadsStop(){ [ -z "$rigThreadPids" ] || rigProcSignal TERM $rigThreadPids ; rigThreadPids="" ; return 0 ; }
trap 'rigThreadsStop ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0 ; rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## THE FOLDER IS THE THREAD'S OWN, and the thread answers where its operation serves: the event-id thread serves the
## folder its own function names, so a rig asks that one. A folder the caller invents is a folder nothing serves.
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents"
export MMDAPP="$rigWs"
rigDir="$( . "$rigComms" ; AgentsCommsEventIdDir )" || { echo "⛔ ERROR: the event-id folder could not be read" >&2 ; exit 1 ; }
mkdir -p "$rigDir"

## The shared path as a caller reaches it, in its own subshell so its descriptors never leak here.
rigRequest(){ ## folder, bound, operation... --, fields...
	( . "$rigInc" || exit 1 ; AgentsToolsOnDemandThreadRequest "$@" ) > "$rigTmp/out.txt" 2> "$rigTmp/err.txt"
	printf '%s' "$?"
}
rigOut(){ cat "$rigTmp/out.txt" 2> /dev/null ; }
rigLocks(){ ## folder -- how many lock files stand there
	LC_ALL=C find "$1" -maxdepth 1 -name 'thread.lock' 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' '
}
## An id as the event-id thread mints one: the date and the time, `Z`, `-`, six decimal places and three hex of the
## origin. A shape, never a figure: the thread's own clock gives the date and the time.
rigIsId(){
	case "${1:-}" in
		[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]Z-[0-9][0-9][0-9][0-9][0-9][0-9][0-9A-F][0-9A-F][0-9A-F]) printf yes ;;
		*) printf no ;;
	esac
}

echo "-- 1. a caller whose thread is not there yet is answered by one call --"
rigAssert "1. the shared path answers, rc 0, starting the thread itself" \
	"$( rigRequest "$rigDir" 25 --intern-comms-event-id --run -- 1 )" 0
rigAssert "1. and its answer is the thread's own words" "$( rigIsId "$( rigOut )" )" yes
rigAssert "1. and the thread it started is the one there" "$( rigLocks "$rigDir" )" 1

echo "-- 1b. the control, both directions: this instrument can read rc 1 --"
rigAssert "1b. a path with no folder is rc 1" "$( rigRequest "" 25 --intern-comms-event-id --run -- 1 )" 1
rigAssert "1b. a field holding a tab is refused, rc 1" "$( rigRequest "$rigDir" 25 --intern-comms-event-id --run -- "$( printf 'a\tb' )" )" 1
rigAssert "1b. and the refusal is the thread's own, named" \
	"$( LC_ALL=C grep -c 'tab or a newline' "$rigTmp/err.txt" || : )" 1

echo "-- 2. against a living thread it asks, and starts no second one --"
rigBefore="$( cat "$rigDir/thread.lock" 2> /dev/null )"
rigAssert "2. a living thread answers the shared path" "$( rigRequest "$rigDir" 25 --intern-comms-event-id --run -- 1 )" 0
rigAssert "2. and its answer is the thread's own words" "$( rigIsId "$( rigOut )" )" yes
rigAssert "2. and the same thread is still the one there" "$( cat "$rigDir/thread.lock" 2> /dev/null )" "$rigBefore"
rigAssert "2. and no second thread was started" "$( rigLocks "$rigDir" )" 1

echo "-- 3. a thread killed between two calls is started again and answered --"
rigPid3="$( LC_ALL=C cut -d' ' -f1 "$rigDir/thread.lock" 2> /dev/null )"
[ -z "$rigPid3" ] || { rigProcNoteFrom "$rigDir/thread.lock" ; rigProcSignal TERM "$rigPid3" ; }
rigWaited=0
while [ "$rigWaited" -lt 15 ] && [ -f "$rigDir/thread.lock" ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "3. the thread is gone before the next call" "$( rigLocks "$rigDir" )" 0
rigAssert "3. and the next call is answered" "$( rigRequest "$rigDir" 25 --intern-comms-event-id --run -- 1 )" 0
rigAssert "3. by a thread that is there again" "$( rigLocks "$rigDir" )" 1
rigAssert "3. and its answer is the thread's own words" "$( rigIsId "$( rigOut )" )" yes
rigThreadsStop

echo "-- 4. the comms ingest goes through that one path, and its local loop is gone --"
rigAssert "4. its id batch calls the shared path once" \
	"$( LC_ALL=C grep -c -F 'AgentsToolsOnDemandThreadRequest "$nextDir"' "$rigComms" 2> /dev/null || : )" 1
rigAssert "4. and it keeps no retry loop of its own" \
	"$( LC_ALL=C grep -c -F 'nextAsks' "$rigComms" 2> /dev/null || : )" 0
rigAssert "4. and no reply fifo of its own" \
	"$( LC_ALL=C grep -c -F 'nextReply' "$rigComms" 2> /dev/null || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ ON_DEMAND_THREAD_REQUEST CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'ON_DEMAND_THREAD_REQUEST: OK (%d assertions, offline, rig threads only)\n' "$rigPassCount"
