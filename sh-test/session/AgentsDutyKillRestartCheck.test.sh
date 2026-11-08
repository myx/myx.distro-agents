#!/usr/bin/env bash
## Behavioural check on S23.6, the liveness of a run as a cached reading, and on the kill-and-restart of a duty (S23.7), run with real processes: a stand-in run and
## a stand-in supervising shell, each a `sleep` the check starts and kills (SIGKILL), recorded in a duty record as the launcher records them (`run-process:`,
## `supervisor-process:`). Held:
##   1. A LIVE RUN reads alive, rc 0, and its reading is kept in .local/agents/liveness/<spawn id> as `alive <epoch>`. The duty scan finds it. Nothing closes it.
##   2. THE KILL: the run and its shell are killed; inside the TTL the reading is served as measured (alive); past it the reading is gone, rc 0, and kept as gone.
##      The record still says `spawn-started`, and no view takes that for a live run: the scan no longer finds the duty.
##   3. THE CLOSE: the stale close ends the record, spawn-failed, once and says so; the restart rule then reads an end: held inside its 300 seconds, due after.
##   4. UNKNOWN is never gone: a record that names no process, and one of another host, read unknown, rc 2, are not cached, and are waited for, never closed.
##   5. THE LOOP: its work-duty step closes a duty record whose run and shell are both gone, and says so.
##   5b. THE RESTART is a new run at its armed base (S23.7): its start joins the duty's session and carries no resume, so nothing resumes the dead run's conversation.
##   6. THE BOARD HOLDERS: a holder whose run is gone holds nothing; a holder that cannot be told either way, and one that lives, still hold.
## Offline: the workspace, the board and every record are this rig's own tree; the processes are this check's own and are ended with it.
set -u
## The list of started records is kept for MDAT_STARTED_RECORDS_SECONDS in the product, and this check makes records between its asks, so it reads them fresh.
export MDAT_STARTED_RECORDS_SECONDS=0 MDAT_DUTY_RECORDS_SECONDS=0
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/session/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the loop's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyKillRestartCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigEach in $rigPids ; do kill -9 "$rigEach" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigSp="$rigTmp/ws/.local/agents/spawned/rig-sess"
mkdir -p "$rigWs/.local/agents/schedule" "$rigSp" "$rigTmp/home" "$rigData/board/running" "$rigData/inboxes/magic-coordinator/incoming"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigStartOf(){ ## pid -- when the process began, as the launcher records it
	LC_ALL=C ps -o lstart= -p "$1" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }'
}
rigProcess(){ ## prints the pid of a process of this check's own that runs until killed
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigPids="$rigPids $!"
	printf '%s\n' "$!"
}
rigKill(){ ## pid... -- killed, and waited for until the process is no process of this host
	local killPid killLeft
	for killPid in "$@" ; do
		kill -9 "$killPid" 2> /dev/null
		killLeft=50
		while kill -0 "$killPid" 2> /dev/null && [ "$killLeft" -gt 0 ] ; do sleep 0.1 ; killLeft=$(( killLeft - 1 )) ; done
	done
}
rigRecord(){ ## file, spawn id, owner, status, host, run pid (may be empty), shell pid (may be empty)
	{
		printf -- '---\nspawn-id: %s\nsession-id: rig-sess\nowner: %s\nstatus: %s\nroutine: magic-coordinator.work-duty.routine.md\nhost: %s\n' "$2" "$3" "$4" "$5"
		[ -z "$6" ] || printf 'run-process: %s %s\n' "$6" "$( rigStartOf "$6" )"
		[ -z "$7" ] || printf 'supervisor-process: %s %s\n' "$7" "$( rigStartOf "$7" )"
		printf -- '---\n\n# Spawn session: %s\n' "$2"
	} > "$1"
}
rigFn(){ ## the function and its arguments... -- run in the loop's include: `<rc>:<what it printed>`
	local fnOut fnRc
	fnOut="$( env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_TMP="$rigTmp" AGENTS_LIVENESS_TTL=300 MDAT_STARTED_RECORDS_SECONDS=0 MDAT_DUTY_RECORDS_SECONDS=0 \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			set +e
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardItemHandler.include" > /dev/null 2>&1
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" > /dev/null 2>&1
			"$@"
		' rig "$@" 2> /dev/null )"
	fnRc=$?
	printf '%s:%s' "$fnRc" "$fnOut"
}
rigStatus(){ ## record -- its status header
	LC_ALL=C sed -n 's/^status: //p' "$1" | head -1
}

rigRun="$( rigProcess )" rigShell="$( rigProcess )"
rigDuty="$rigSp/rigduty01.spawn.md"
rigRecord "$rigDuty" rigduty01 magic-coordinator spawn-started "$rigHost" "$rigRun" "$rigShell"
[ -n "$( rigStartOf "$rigRun" )" ] || rigRefuse "the stand-in run has no start time, so no record of it could be made"

echo "-- 1. a live run --"
rigAssert "a live run reads alive, rc 0" "$( rigFn AgentsToolsLivenessOf rigduty01 "$rigDuty" )" "0:alive"
rigAssert "its reading is kept as alive and an epoch" "$( LC_ALL=C awk '{ print $1 ( $2 ~ /^[0-9]+$/ ? " epoch" : " none" ) }' "$rigWs/.local/agents/liveness/rigduty01" 2> /dev/null )" "alive epoch"
rigAssert "the duty scan finds the record" "$( rigFn AgentsToolsScheduleWorkDutyRecord magic-coordinator | LC_ALL=C sed 's|^0:.*/||' )" "rigduty01.spawn.md"
rigAssert "the stale close says nothing and leaves it open" "$( rigFn AgentsToolsScheduleDutyStaleClose "$rigDuty" ):$( rigStatus "$rigDuty" )" "0::spawn-started"

echo "-- 2. the kill --"
rigKill "$rigRun" "$rigShell"
rigAssert "inside the TTL the reading is served as measured" "$( rigFn AgentsToolsLivenessOf rigduty01 "$rigDuty" )" "0:alive"
## The TTL passes: the reading's epoch is set back ten minutes, so nothing here waits on a clock.
LC_ALL=C awk -v then="$(( $( date +%s ) - 600 ))" '{ print $1, then }' "$rigWs/.local/agents/liveness/rigduty01" > "$rigWs/.local/agents/liveness/rigduty01.next" && mv -f "$rigWs/.local/agents/liveness/rigduty01.next" "$rigWs/.local/agents/liveness/rigduty01"
rigAssert "past the TTL it is gone, rc 0" "$( rigFn AgentsToolsLivenessOf rigduty01 "$rigDuty" )" "0:gone"
rigAssert "and kept as gone" "$( LC_ALL=C awk '{ print $1 }' "$rigWs/.local/agents/liveness/rigduty01" )" "gone"
rigAssert "the record still says spawn-started" "$( rigStatus "$rigDuty" )" "spawn-started"
rigAssert "yet the duty scan finds no live duty" "$( rigFn AgentsToolsScheduleWorkDutyRecord magic-coordinator | LC_ALL=C sed 's|^\([0-9]*\):.*|\1|' )" "1"

echo "-- 3. the close and the restart --"
rigAssert "the stale close ends the record, and says so" "$( rigFn AgentsToolsScheduleDutyStaleClose "$rigDuty" | LC_ALL=C grep -c 'closing it spawn-failed' ):$( rigStatus "$rigDuty" )" "1:spawn-failed"
rigAssert "a second look says nothing, the record being closed" "$( rigFn AgentsToolsScheduleDutyStaleClose "$rigDuty" )" "0:"
rigAssert "a duty that ended a moment ago is held inside its 300 seconds" "$( rigFn AgentsToolsScheduleDutyRestartDue magic-coordinator | LC_ALL=C sed 's|^\([0-9]*\):.*|\1|' )" "1"
rigWhen="$( date -v-10M '+%Y%m%d%H%M' 2> /dev/null )" || rigWhen="$( date -d '-10 minutes' '+%Y%m%d%H%M' )"
touch -t "$rigWhen" "$rigDuty"
rigAssert "after them it is due, and names the ended record" "$( rigFn AgentsToolsScheduleDutyRestartDue magic-coordinator | LC_ALL=C sed 's|^\([0-9]*\):.*/|\1:|' )" "0:rigduty01.spawn.md"

echo "-- 4. unknown is never gone --"
rigRecord "$rigSp/rigduty02.spawn.md" rigduty02 magic-coordinator spawn-started "$rigHost" "" ""
rigOther="$( rigProcess )"
rigRecord "$rigSp/rigduty03.spawn.md" rigduty03 magic-coordinator spawn-started "another-host-of-the-rig" "$rigOther" ""
rigKill "$rigOther"
rigAssert "a record that names no process reads unknown, rc 2" "$( rigFn AgentsToolsLivenessOf rigduty02 "$rigSp/rigduty02.spawn.md" )" "2:unknown"
rigAssert "a record of another host reads unknown, rc 2" "$( rigFn AgentsToolsLivenessOf rigduty03 "$rigSp/rigduty03.spawn.md" )" "2:unknown"
rigAssert "neither is kept" "$( ls "$rigWs/.local/agents/liveness" | LC_ALL=C grep -c -e rigduty02 -e rigduty03 || : )" "0"
rigAssert "the stale close waits for the one and closes neither" "$( rigFn AgentsToolsScheduleDutyStaleClose "$rigSp/rigduty02.spawn.md" | LC_ALL=C grep -c 'waited for, never closed' ):$( rigStatus "$rigSp/rigduty02.spawn.md" ):$( rigFn AgentsToolsScheduleDutyStaleClose "$rigSp/rigduty03.spawn.md" | LC_ALL=C grep -c 'waited for, never closed' ):$( rigStatus "$rigSp/rigduty03.spawn.md" )" "1:spawn-started:1:spawn-started"

echo "-- 5. the loop's work-duty step --"
rigRun4="$( rigProcess )" rigShell4="$( rigProcess )"
rigRecord "$rigSp/rigduty04.spawn.md" rigduty04 magic-coordinator spawn-started "$rigHost" "$rigRun4" "$rigShell4"
rigKill "$rigRun4" "$rigShell4"
rigAssert "the step closes a duty record whose run and shell are gone, and says so" "$( rigFn AgentsToolsScheduleWorkDuty | LC_ALL=C grep -c 'rigduty04 is open with no process and no supervisor' ):$( rigStatus "$rigSp/rigduty04.spawn.md" )" "1:spawn-failed"

echo "-- 5b. the restart is a new run at its armed base: it joins the session and resumes nothing --"
mkdir -p "$rigWs/.local/agents/schedule/duty-session" && printf 'rig-sess\n' > "$rigWs/.local/agents/schedule/duty-session/magic-coordinator"
rigRestart(){ ## -- the start the schedule makes of a duty, its tooling call recorded by a stand-in
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_TMP="$rigTmp" MDAT_SPAWN_RESUME="" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			set +e
			DistroAgentsTools(){ printf "%s|resume-env=%s\n" "$*" "${MDAT_SPAWN_RESUME:-unset}" > "$RIG_TMP/spawn.args" ; return 0 ; }
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
			AgentsToolsScheduleSpawn work-duty.magic-coordinator --session-thread:event-track --routine magic-coordinator.work-duty.routine.md magic-coordinator
		' > /dev/null 2>&1
	local restartLeft=50
	while [ ! -s "$rigTmp/spawn.args" ] && [ "$restartLeft" -gt 0 ] ; do sleep 0.1 ; restartLeft=$(( restartLeft - 1 )) ; done
}
rigRestart
rigAssert "the restart's call joins the duty's session, names its routine and member, and carries no resume" "$( LC_ALL=C grep -c -F -e '--spawn-session --join-session rig-sess --session-thread:event-track --routine magic-coordinator.work-duty.routine.md magic-coordinator|resume-env=unset' "$rigTmp/spawn.args" ):$( LC_ALL=C grep -c -e '--resume' "$rigTmp/spawn.args" || : )" "1:0"

echo "-- 6. the board holders --"
rm -f "$rigSp"/rigduty0[123].spawn.md
rigLiveRun="$( rigProcess )" rigDeadRun="$( rigProcess )"
rigRecord "$rigSp/holdalive.spawn.md" holdalive rig-alive spawn-started "$rigHost" "$rigLiveRun" ""
rigRecord "$rigSp/holdgone.spawn.md" holdgone rig-gone spawn-started "$rigHost" "$rigDeadRun" ""
rigRecord "$rigSp/holdnone.spawn.md" holdnone rig-unknown spawn-started "$rigHost" "" ""
rigKill "$rigDeadRun"
printf -- '---\ntype: task\nowner: rig-gone\nparticipants: rig-unknown, rig-alive\n---\n\n# rig item\n' > "$rigData/board/running/task-rig-held.md"
rigAssert "a holder whose run is gone holds nothing; one that cannot be told, and one that lives, hold" "$( rigFn AgentsToolsBoardItemHolders "$rigData/board/running/task-rig-held.md" | LC_ALL=C tr '\t\n' ' -' | LC_ALL=C sed 's/^0://' )" "rig-alive holdalive rig-sess-rig-unknown holdnone rig-sess"
rigKill "$rigLiveRun"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DUTY KILL RESTART CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DUTY_KILL_RESTART: OK (%d assertions, real processes, rig tree only)\n' "$rigPassCount"
