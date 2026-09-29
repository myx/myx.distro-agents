#!/usr/bin/env bash
## Behavioural check on the one local lock primitive, sh-lib/AgentsTools.LocalLock.include,
## run rather than read. Holds: a free lock is taken and given back; a live holder's lock
## is not taken; a dead holder's lock is broken; of several callers breaking the same dead
## lock at once exactly one ends up holding it; the old directory form is removed; the
## lock area is local state only. Offline, in this check's own temp workspace.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigInclude="$rigHere/AgentsTools.LocalLock.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the lock primitive is missing: $rigInclude"

rigTmp="$( mktemp -d -t AgentsLocalLockCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws"
rigLocks="$rigTmp/ws/.local/agents/locks"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## One caller in its own process: takes the lock, reports, holds it a moment, gives it back.
rigCaller(){ ## key, tries, hold seconds, report file
	MMDAPP="$rigTmp/ws" bash -c '
		. "$1"
		if AgentsToolsLocalLockTake "$2" "$3" rig 2>/dev/null ; then
			heldPath="$agentsLocalLockPath"
			printf "held %s\n" "$$" >> "$5"
			sleep "$4"
			AgentsToolsLocalLockGive "$heldPath"
		else
			printf "refused %s\n" "$$" >> "$5"
		fi
	' rig "$rigInclude" "$1" "$2" "$3" "$4"
}
rigDeadPid(){
	sleep 0 &
	local deadPid=$!
	wait "$deadPid"
	printf '%s' "$deadPid"
}
rigCount(){ ## report file, word
	LC_ALL=C awk -v wantWord="$2" '$1 == wantWord { hitCount++ ; } END { print hitCount + 0 ; }' "$1" 2>/dev/null
}

echo "-- a free lock is taken, and given back --"
rigCaller free 1 0 "$rigTmp/r.free"
rigAssert "a free lock is taken"                  "$( rigCount "$rigTmp/r.free" held )" 1
rigAssert "and given back afterwards"             "$( [ -e "$rigLocks/free" ] || [ -L "$rigLocks/free" ] && printf held || printf released )" released

echo "-- a live holder's lock is not taken --"
mkdir -p "$rigLocks"
ln -s "$$" "$rigLocks/live"
rigCaller live 2 0 "$rigTmp/r.live"
rigAssert "a live holder's lock is refused"       "$( rigCount "$rigTmp/r.live" refused )" 1
rigAssert "and still names its holder"            "$( readlink "$rigLocks/live" )" "$$"
rm -f "$rigLocks/live"

echo "-- a dead holder's lock is broken --"
ln -s "$( rigDeadPid )" "$rigLocks/dead"
rigCaller dead 2 0 "$rigTmp/r.dead"
rigAssert "a dead holder's lock is taken over"    "$( rigCount "$rigTmp/r.dead" held )" 1
rigAssert "and released afterwards"               "$( [ -e "$rigLocks/dead" ] || [ -L "$rigLocks/dead" ] && printf held || printf released )" released

echo "-- the old directory form is removed --"
mkdir -p "$rigLocks/oldform"
printf '%s\n' "$$" > "$rigLocks/oldform/pid"
rigCaller oldform 2 0 "$rigTmp/r.oldform"
rigAssert "an old directory-form lock is replaced" "$( rigCount "$rigTmp/r.oldform" held )" 1
rigAssert "and nothing of it is left"             "$( [ -e "$rigLocks/oldform" ] || [ -L "$rigLocks/oldform" ] && printf held || printf released )" released

echo "-- several callers breaking one dead lock at once: exactly one holds it --"
rigBadRounds=0
for rigRound in 1 2 3 4 5 6 7 8 ; do
	ln -s "$( rigDeadPid )" "$rigLocks/race"
	: > "$rigTmp/r.race"
	for rigCallerIndex in 1 2 3 4 ; do
		rigCaller race 1 2 "$rigTmp/r.race" &
	done
	wait
	[ "$( rigCount "$rigTmp/r.race" held )" = 1 ] || rigBadRounds=$(( rigBadRounds + 1 ))
	rm -f "$rigLocks/race" "$rigLocks"/race.stale.*
done
rigAssert "every round had exactly one holder"    "$rigBadRounds bad rounds" "0 bad rounds"

echo "-- a lock taken while another is held: both are given back, neither is left --"
MMDAPP="$rigTmp/ws" bash -c '
	. "$1"
	AgentsToolsLocalLockTake outer 1 rig && outerPath="$agentsLocalLockPath"
	AgentsToolsLocalLockTake inner 1 rig && innerPath="$agentsLocalLockPath"
	AgentsToolsLocalLockGive "$innerPath"
	AgentsToolsLocalLockGive "$outerPath"
' rig "$rigInclude"
rigAssert "the outer lock is released"           "$( [ -L "$rigLocks/outer" ] && printf held || printf released )" released
rigAssert "the inner lock is released"           "$( [ -L "$rigLocks/inner" ] && printf held || printf released )" released

echo "-- a bad key is refused, never a path --"
rigCaller "../escape" 1 0 "$rigTmp/r.bad"
rigAssert "a key naming a path is refused"        "$( rigCount "$rigTmp/r.bad" refused )" 1
rigAssert "and nothing was created outside"       "$( [ -e "$rigTmp/ws/.local/agents/escape" ] && printf created || printf absent )" absent

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ LOCAL LOCK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'LOCAL_LOCK: OK (%d assertions, offline)\n' "$rigPassCount"
