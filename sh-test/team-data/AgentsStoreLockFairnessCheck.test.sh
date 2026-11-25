#!/usr/bin/env bash
## Behavioural check: the store lock is fair to a waiter (AgentsToolsTeamDataStoreLockTake in AgentsTools.TeamDataStoreLock.include).
## A writer that polls once a second was starved for 30 s by a process that took the lock again at once (the commit thread's cycle).
## Held:
##   1. A FREE LOCK WITH NO WAITER is taken, and its time is the base the other rows are read against.
##   2. A LIVE WAITER HOLDS A FRESH TAKER BACK for its turn: a take that finds a live marker takes at least 800 ms longer than the base.
##   3. A STALE MARKER, its process gone, is removed and holds nobody back: the take is 800 ms or more faster than the held take.
##   4. A WAITER LEAVES A MARKER WHILE IT WAITS and none once it has the lock.
## Red before the fix: row 2 reads no hold-back and row 4 finds no marker, since nothing is written or read.
## Offline: a folder with a .git directory stands for the store. No git is run.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/team-data/AgentsTools.TeamDataStoreLock.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the store lock include is not at $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsStoreLockFairnessCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigPid in $rigPids ; do kill "$rigPid" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
	return 0
}

rigRoot="$rigTmp/store"
rigDir="$rigRoot/.git/team-data-commit"
mkdir -p "$rigDir" || exit 1
export MDAT_DATA_ROOT="$rigRoot"

## One take in a shell of its own, so its pid is its own. Prints the milliseconds it took and its exit status.
rigTake(){ ## tries
	local rigFrom rigRc
	rigFrom="$( python3 -c 'import time;print(int(time.time()*1000))' )"
	bash -c '. "$1" ; AgentsToolsTeamDataStoreLockTake "$2" rig && AgentsToolsTeamDataStoreLockGive' rig "$rigInclude" "$1" > /dev/null 2>&1
	rigRc=$?
	printf '%s %s' "$(( $( python3 -c 'import time;print(int(time.time()*1000))' ) - rigFrom ))" "$rigRc"
}

echo "-- 1. a free lock and no waiter: taken, and its time is the base --"
rigGot="$( rigTake 3 )"
rigBase="${rigGot%% *}"
rigAssert "the take holds the lock" "${rigGot##* }" "0"

echo "-- 2. a live waiter holds a fresh taker back --"
sleep 30 &
rigWaiter=$!
rigPids="$rigPids $rigWaiter"
: > "$rigDir/store.want.$rigWaiter"
rigGot="$( rigTake 3 )"
rigHeld="${rigGot%% *}"
rigAssert "the take takes 800 ms or more longer than the base, then takes" "$( [ "$(( rigHeld - rigBase ))" -ge 800 ] && echo held ):${rigGot##* }" "held:0"
kill "$rigWaiter" 2> /dev/null
rm -f "$rigDir/store.want.$rigWaiter"

echo "-- 3. a stale marker holds nobody back and is removed --"
sleep 0 &
rigDead=$!
wait "$rigDead" 2> /dev/null
: > "$rigDir/store.want.$rigDead"
rigGot="$( rigTake 3 )"
rigAssert "the take is 800 ms or more faster than the held take, and the marker is gone" "$( [ "$(( rigHeld - ${rigGot%% *} ))" -ge 800 ] && echo quick ):$( [ -e "$rigDir/store.want.$rigDead" ] && echo left || echo gone )" "quick:gone"

echo "-- 4. a waiter leaves a marker while it waits and none after --"
sleep 30 &
rigHolder=$!
rigPids="$rigPids $rigHolder"
printf '%s' "$rigHolder" > "$rigDir/store.lock"
bash -c '. "$1" ; AgentsToolsTeamDataStoreLockTake 20 rig && AgentsToolsTeamDataStoreLockGive' rig "$rigInclude" > /dev/null 2>&1 &
rigBlocked=$!
rigPids="$rigPids $rigBlocked"
sleep 2
rigAssert "one marker stands while the lock is held" "$( ls "$rigDir" | grep -c '^store\.want\.' )" "1"
kill "$rigHolder" 2> /dev/null
wait "$rigBlocked" 2> /dev/null
rigAssert "the waiter took the lock and its marker is gone" "$( ls "$rigDir" | grep -c '^store\.want\.' )" "0"

printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
