#!/usr/bin/env bash
## Behavioural check on the one-at-a-time gate of the routine-lock acquire (S12.13, board task 20261106T0824Z;
## `AgentsToolsRoutineLockAcquire` in AgentsTools.RoutineLock.include). Its git steps share the one team-data checkout, so two
## acquires in one workspace must not run together. The fault it guards: a start that takes the lock while another start is
## inside the same steps, and a gate folder left behind by a start that failed, which then holds every later start out.
## Held, run rather than read:
##   1. TWO ACQUIRES AT ONCE RUN ONE AFTER THE OTHER, never overlapped, and each one's own order is kept.
##   2. A SUCCESSFUL ACQUIRE LEAVES NO GATE BEHIND.
##   3. A FAILED ACQUIRE LEAVES NO GATE BEHIND either, so the next start is not held out by it.
##   4. THE GATE OF A DEAD START IS TAKEN OVER: one older than ten minutes is cleared, and the acquire goes through.
## The inner acquire is a stand-in that records when it began and ended: this is the gate's own question, and AgentsRoutineLockCheck,
## AgentsRoutinePerMemberLockCheck and AgentsRoutineLockOwnOpsCheck hold what the inner step does with a document.
## RED RECIPE, measured on a copy under this check's own scratch on 2026-11-06, one mutation per guarded line of
## `AgentsToolsRoutineLockAcquire`:
##   the whole `until mkdir` gate loop at :323-327 deleted — the acquires overlap, and row 1 fails.
##   `rmdir "$acqGate"` at :337 deleted — the gate is never given back, and every row after row 1 fails.
##   the ten-minute takeover line at :324 deleted — row 4 fails alone.
## Every acquire here is bounded, so the second mutation reports red rather than standing still.
## Offline: the include this check loads, and a rig of its own; no spawner, git or network is reached.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/magic/AgentsTools.RoutineLock.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the routine-lock include is not at $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineLockAcquireGateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
rigGate="$rigWs/.local/agents/locks/routine-lock-acquire"
mkdir -p "$rigWs/.local/agents" "$rigTmp/log" || exit 1
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
## THE ACQUIRE RUNS IN A SHELL OF ITS OWN. The inner step is the stand-in: it appends `begin <name>` and `end <name>` to its own log,
## and answers what the scenario file says, so this check reads the overlap off the log rather than off a clock.
rigAcquire(){ ## the tag this call is logged under, the status the inner step answers, the seconds it holds
	local acqTag="$1" acqStatus="$2" acqHold="$3"
	MMDAPP="$rigWs" bash -c '
		rigTag="$1" ; rigStatus="$2" ; rigHold="$3" ; rigLog="$4"
		. "$5"
		AgentsToolsRoutineLockAcquireOne(){
			printf "begin %s\n" "$rigTag" >> "$rigLog"
			sleep "$rigHold"
			printf "end %s %s\n" "$rigTag" "$rigStatus" >> "$rigLog"
			agentsRoutineLockTakenOne="no"
			return "$rigStatus"
		}
		AgentsToolsRoutineLockAcquire "inbox:rig-keeper:note-20261020T000000Z-rig-state-and-lock.md" "rig-session-$rigTag" rig-routine
	' rig-acquire "$acqTag" "$acqStatus" "$acqHold" "$rigTmp/log/calls" "$rigInclude"
}
## How many acquires stood inside the gate at once, as the log records it: a begin opens one, an end closes one.
rigPeakInside(){
	LC_ALL=C awk '
		$1 == "begin" { inside++ ; if ( inside > peak ) { peak = inside } ; next }
		$1 == "end" { inside-- ; next }
		END { print peak + 0 }
	' "$rigTmp/log/calls" 2> /dev/null
}
## A gate that is never given back makes a later acquire wait its own 600 seconds, so every acquire here is bounded: the check says
## the acquire stood still, instead of standing still with it.
rigWaitEach(){ ## the seconds allowed, then the pids
	local waitLeft="$1" waitPid waitOne
	shift
	while [ "$waitLeft" -gt 0 ] ; do
		waitOne="no"
		for waitPid in "$@" ; do ! kill -0 "$waitPid" 2> /dev/null || waitOne="yes" ; done
		[ "$waitOne" = "no" ] && return 0
		sleep 1 ; waitLeft=$(( waitLeft - 1 ))
	done
	for waitPid in "$@" ; do rigProcSignal TERM "$waitPid" || : ; done
	return 1
}
## Every acquire this check makes goes through here: it is started apart, given its own note, and watched for the bounded time. Its
## answer lands in rigAcqResult, never in a command substitution, because a background child holding that pipe would block it.
rigRunAcquire(){ ## the tag, the status the inner step answers, the seconds it holds
	rigAcquire "$@" > /dev/null 2>&1 & rigAcqPid="$!" ; rigProcNote "$rigAcqPid"
	if rigWaitEach 30 "$rigAcqPid" ; then rigAcqResult="ended" ; else rigAcqResult="still-running" ; fi
}

echo "-- 1. two acquires at once run one after the other --"
: > "$rigTmp/log/calls"
rigAcquire first 0 1 & rigFirstPid="$!" ; rigProcNote "$rigFirstPid"
rigAcquire second 0 1 & rigSecondPid="$!" ; rigProcNote "$rigSecondPid"
if rigWaitEach 30 "$rigFirstPid" "$rigSecondPid" ; then rigBothEnded="ended" ; else rigBothEnded="still-running" ; fi
rigAssert "both acquires ended rather than one standing still behind the gate" "$rigBothEnded" ended
rigAssert "the two acquires never stood inside the gate together" "$( rigPeakInside )" 1
rigAssert "both acquires ran, one after the other" "$( LC_ALL=C grep -c '^begin ' "$rigTmp/log/calls" || : )" 2

echo "-- 2. a successful acquire leaves no gate behind --"
rigAssert "the gate folder is gone after acquires that returned" "$( [ -e "$rigGate" ] && printf left || printf absent )" absent

echo "-- 3. a failed acquire leaves no gate behind --"
: > "$rigTmp/log/calls"
rigRunAcquire third 1 0
rigAssert "an acquire whose inner step failed ends" "$rigAcqResult" ended
rigAssert "the gate folder is gone after an acquire that failed" "$( [ -e "$rigGate" ] && printf left || printf absent )" absent
: > "$rigTmp/log/calls"
rigRunAcquire fourth 0 0
rigAssert "and the next acquire ends, rather than waiting on it" "$rigAcqResult" ended
rigAssert "the acquire that followed it really ran" "$( LC_ALL=C grep -c '^begin fourth' "$rigTmp/log/calls" || : )" 1

echo "-- 4. the gate of a dead start is taken over --"
mkdir -p "$rigGate" || exit 1
touch -t "$( date -v-15M '+%Y%m%d%H%M' 2> /dev/null || date -d '15 minutes ago' '+%Y%m%d%H%M' )" "$rigGate" || exit 1
: > "$rigTmp/log/calls"
rigRunAcquire fifth 0 0
rigAssert "an acquire behind a gate older than ten minutes ends rather than waiting it out" "$rigAcqResult" ended
rigAssert "the acquire through a dead start's gate really ran" "$( LC_ALL=C grep -c '^begin fifth' "$rigTmp/log/calls" || : )" 1
rigAssert "and that gate is gone too" "$( [ -e "$rigGate" ] && printf left || printf absent )" absent

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE LOCK ACQUIRE GATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'ROUTINE_LOCK_ACQUIRE_GATE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
