#!/usr/bin/env bash
## Behavioural check of the cache's ready fifo against its callers' own descriptors (a library function leaves its caller's shell as it
## found it). The comms thread waits between its passes on a pipe of its own on descriptor 9, and calls AgentsToolsCommsCacheSayReady
## after each pull a reader waits on; a reader calls AgentsToolsCommsCacheWaitReady from a shell whose descriptors are its own. In a rig:
##   1. a shell holding its own pipe on 9 still has it after it says ready: a line written there is read back, and a read on it waits
##   2. a shell holding its own pipe on 8 still has it after a ready wait
##   3. control: a reader waiting on a folder is still woken by the word ready, well inside its budget
## Red before the change: the word ready took 9 and closed it, so the thread's wait returned at once and its loop spun; the ready wait
## closed 8.
## Offline: fifos in a rig folder of this check's own; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsReadyKeepsDescriptorsCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigFolder="$rigTmp/cache/slack/C0RIG"
mkdir -p "$rigFolder" || exit 1
rigShell(){ ## script: run with the cache include loaded, in a rig workspace
	env -u MDAT_COMMS_CACHE_WAIT_UNTIL MMDAPP="$rigTmp/ws" rigPkg="$rigPkg" rigTmp="$rigTmp" rigFolder="$rigFolder" bash -c '
		. "$rigPkg/sh-lib/comms/AgentsTools.CommsCache.include" || exit 1
		'"$1" 2> /dev/null
}

echo "-- 1. the word ready leaves the caller's 9 --"
rigOut="$( rigShell 'mkfifo "$rigTmp/own9" && exec 9<> "$rigTmp/own9" || exit 1
	rm -f "$rigFolder/.ready" ; mkfifo "$rigFolder/.ready" ; : > "$rigFolder/.waiting"
	AgentsToolsCommsCacheSayReady "$rigFolder"
	printf "own\n" >&9 ; got="" ; IFS= read -r -t 1 -u 9 got
	from=$SECONDS ; read -r -t 1 -u 9 ; read -r -t 1 -u 9 ; read -r -t 1 -u 9
	printf "%s %s" "${got:-none}" "$(( SECONDS - from ))"' )"
rigAssert "a line written to 9 is read back from it" "${rigOut%% *}" own
rigAssert "three one-second reads on 9 wait two seconds or more" "$( [ "${rigOut##* }" -ge 2 ] 2> /dev/null && echo waits || echo "waited ${rigOut##* }s" )" waits

echo "-- 2. a ready wait leaves the caller's 8 --"
rm -f "$rigFolder/.waiting"
rigOut="$( rigShell 'mkfifo "$rigTmp/own8" && exec 8<> "$rigTmp/own8" || exit 1
	AgentsToolsCommsCacheWaitReady "$rigFolder" 1
	printf "own\n" >&8 ; got="" ; IFS= read -r -t 1 -u 8 got ; printf "%s" "${got:-none}"' )"
rigAssert "a line written to 8 is read back from it" "$rigOut" own

echo "-- 3. control: a waiting reader is woken --"
rm -f "$rigFolder/.waiting"
rigFrom="$SECONDS"
rigShell 'AgentsToolsCommsCacheWaitReady "$rigFolder" 8 ; printf "%s" "$?" > "$rigTmp/reader.rc"' &
rigReader=$!
rigI=0 ; while [ ! -f "$rigFolder/.waiting" ] && [ "$rigI" -lt 50 ] ; do sleep 0.1 ; rigI=$(( rigI + 1 )) ; done
rigShell 'AgentsToolsCommsCacheSayReady "$rigFolder"'
wait "$rigReader"
rigAssert "the reader came back with the data" "$( cat "$rigTmp/reader.rc" 2> /dev/null )" 0
rigAssert "well inside its eight seconds" "$( [ $(( SECONDS - rigFrom )) -lt 6 ] && echo inside || echo "$(( SECONDS - rigFrom ))s" )" inside

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ COMMS READY KEEPS DESCRIPTORS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_READY_KEEPS_DESCRIPTORS: OK (%d assertions, offline, rig fifos only)\n' "$rigPass"
