#!/usr/bin/env bash
## Behavioural check on `--stop-sessions` (S12.15, board task 20261106T0933Z; the arm in DistroAgentsDispatcher.fn.sh). Stopping a rig is
## two parts, and this is the second: the running sessions are ended, and only once `holding` holds, so the schedule starts nothing again
## behind the stop. Held, run rather than read, with the real dispatcher from the package under test:
##   1. IT REFUSES WITHOUT holding, and says how to set it. No session list is asked for and nothing is ended.
##   2. WITH holding SET IT RUNS, and ends the schedule thread last, through a TERM to the process its lock names.
##   3. THE THREAD IS ENDED ONLY WHILE ITS LOCK NAMES A LIVE PROCESS: a lock naming nobody leaves it alone, so the stop never signals a
##      number that has been given to a stranger.
## The session-end half is one loop over the active list, and its own row is AgentsManagerSessionKillCheck's: this check holds the gate,
## the flag and the thread, which are the arm's own decisions.
## RED RECIPE, measured on a copy under this check's own scratch on 2026-11-06. The copy needs the sibling packages its readers load, so
## it is `<copy>/myx/{myx.distro-agents,myx.distro-system,myx.distro-source,myx.common}` and named with RIG_PACKAGE:
##   the holding gate at :192-195 deleted — row 1 fails on both its assertions, and row 2 on the flag it then never sets.
## Offline: the dispatcher and a rig of its own; the thread is a sleeper of this check, ended through the shared helper.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigFn="$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at $rigFn"
case "$rigPackage" in
	*/myx/myx.distro-agents) rigOrigin="${rigPackage%/myx/myx.distro-agents}" ;;
	*) rigRefuse "the package under test is not at <origin>/myx/myx.distro-agents: $rigPackage" ;;
esac
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsStopSessionsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rigProcSignal TERM "${rigThreadPid:-0}" || : ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
rigThreadDir="$rigWs/.local/agents/schedule-thread"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/schedule/starting" "$rigThreadDir" || exit 1
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nMDAT_WORKSPACE_MODE=team-rig\n' > "$rigWs/.local/.agents/magic-team.agent.env"
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
## EVERY CALL IS THE REAL SCRIPT, in an environment of the rig's own.
rigDispatcher(){ ## the operation and its words
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDSC_CMD=DistroAgentsDispatcher \
		bash "$rigFn" "$@" > "$rigTmp/out" 2>&1
	rigRc=$?
	rigOut="$( cat "$rigTmp/out" )"
}
## THE THREAD THE STOP ENDS: a sleeper of this check's own, noted before it is written to the lock, so only that process is signalled.
rigThreadLockLine(){ ## the pid -- `<pid> <start>` as the tooling's own reader gives it
	printf '%s %s\n' "$1" "$( printf '%s\n' "$1" | MDLT_ORIGIN="$rigOrigin" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" ; AgentsToolsRegistryProcessesBegan' | LC_ALL=C awk '{ print $2 }' )"
}
rigThread(){ ## the lock line to write
	python3 -I -B -c 'import time; time.sleep(180)' > /dev/null 2>&1 &
	rigThreadPid="$!" ; rigProcNote "$rigThreadPid"
	printf '%s\n' "$1" > "$rigThreadDir/thread.lock"
}

echo "-- 1. it refuses without holding --"
rigDispatcher --stop-sessions
rigAssert "the stop answers an error" "$rigRc" 1
rigAssert "and says to set holding first" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'holding is not set' )" 1
rigAssert "no session list was asked for, and nothing was ended" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -e '^session	' -e '^thread	' )" 0

echo "-- 2. with holding set it runs, and ends the schedule thread --"
rigDispatcher --override-flag holding
rigAssert "the real flag is set" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -x 'holding: yes' )" 1
python3 -I -B -c 'import time; time.sleep(180)' > /dev/null 2>&1 &
rigThreadPid="$!" ; rigProcNote "$rigThreadPid"
## The lock line is `<pid> <start>`, exactly as the tooling keeps it: the liveness test compares that start against the one the process
## table gives now, so a line with an invented start reads as another process and is left alone.
printf '%s\n' "$( rigThreadLockLine "$rigThreadPid" )" > "$rigThreadDir/thread.lock"
rigDispatcher --stop-sessions
rigAssert "the stop answers 0" "$rigRc" 0
rigAssert "the thread it ended is the one its lock named" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c "^thread	$rigThreadPid	ended" )" 1
rigAssert "and that process is gone" "$( kill -0 "$rigThreadPid" 2> /dev/null && printf alive || printf ended )" ended

echo "-- 3. a lock naming nobody is left alone --"
rigThread 999999
rigDispatcher --stop-sessions
rigAssert "the stop answers 0 with a stale lock too" "$rigRc" 0
rigAssert "and reports no thread ended, since that number is no live thread" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^thread	' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ STOP SESSIONS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'STOP_SESSIONS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
