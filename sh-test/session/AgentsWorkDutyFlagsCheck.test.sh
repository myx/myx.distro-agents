#!/usr/bin/env bash
## Behavioural check on `AgentsToolsScheduleWorkDuty` (AgentsTools.DispatcherSchedule.include), run rather than read: who the schedule starts a work-duty for, by the
## flags. The roster, the flags, the pace, the demand, the mention news, the spawner and the dismissal are stubs, so the check decides what the loop chooses and
## nothing is started. Held: in worktime a magic or keeper member with something to work on is started, and a partner, a warden and a client never; out of
## worktime, with no flag, nobody; under team overtime the magic members are started and the keepers are not; a member's own overtime starts that member alone; a
## member on vacation is started by nothing, a mention included, while a member next to it is; a member's live duty on vacation is left to its own lifetime, with the
## flags saying it is not allowed; a slow machine starts nothing and says so; a live duty of a partner, a warden or a client is told to go, and a magic or keeper
## member's is not; under the emergency flag a member is started for its own urgent pending task and no other. Offline.
set -u
## The list of started records is kept for MDAT_STARTED_RECORDS_SECONDS in the product, and this check makes records between its asks, so it reads them fresh.
export MDAT_STARTED_RECORDS_SECONDS=0 MDAT_DUTY_RECORDS_SECONDS=0
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/session/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's functions are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWorkDutyFlagsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigReal="$MMDAPP"
rigWs="$rigTmp/ws"
rigData="$rigWs/data"
mkdir -p "$rigWs/.local/agents/spawned" "$rigData/board/pending" "$rigWs/.local/agents/schedule"
export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDSC_CMD=check
set +u
. "$rigHere/session/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
set -u
type AgentsToolsScheduleWorkDuty > /dev/null 2>&1 || rigRefuse "the schedule's functions are not defined by sourcing them"

## What the loop asks of the rest of the tooling, and what this check says.
rigFlags="" rigMemberFlags="" rigLive="" rigDemand="" rigTagNews="" rigSlow="" rigRestart=""
rigSpawnLog="$rigTmp/spawn.log" rigDismissLog="$rigTmp/dismiss.log" rigLifeLog="$rigTmp/life.log"
rigRoster="magic-coordinator	/r/c
magic-developer	/r/d
magic-tester	/r/t
keeper-myx	/r/k
keeper-ae3	/r/a
partner-ndm-ndxs	/r/p
warden-x	/r/w
client-ndm	/r/n
magic-team	/r/m
human-owner	/r/h"
AgentsToolsTeamMemberDirectoryText(){ printf '%s\n' "$rigRoster" ; }
AgentsToolsTeamMemberReferenceOnly(){ return 1 ; }
AgentsToolsScheduleCurrentFlags(){ printf '%s\n' "$rigFlags" ; }
AgentsToolsSchedulePaceText(){ if [ -n "$rigSlow" ] ; then printf 'pace: 9000 of 300 calls in 30 minutes -- over 7000, a duty start is held\n' ; else printf 'pace: 1000 of 300 calls in 30 minutes -- under 7000, a duty start is allowed\n' ; fi ; }
AgentsToolsSchedulePaceAllows(){ [ -z "$rigSlow" ] ; }
AgentsToolsScheduleDutyStaleClose(){ return 0 ; }
AgentsToolsScheduleMemberFlag(){ case " $rigMemberFlags " in *" $1:$2 "*) printf 'on\n' ;; esac ; return 0 ; }
AgentsToolsScheduleWorkDutyRecord(){ case " $rigLive " in *" $1 "*) printf '/rec/%s.spawn.md\n' "$1" ; return 0 ;; esac ; return 1 ; }
AgentsToolsScheduleDutyLifetime(){ printf '%s allowed=%s\n' "$2" "$3" >> "$rigLifeLog" ; }
AgentsToolsScheduleDutyRestartDue(){ case " $rigRestart " in *" $1 "*) return 0 ;; esac ; return 1 ; }
AgentsToolsScheduleDemand(){ case " $rigDemand " in *" $1 "*) return 0 ;; esac ; return 1 ; }
AgentsToolsScheduleTagNews(){ case " $rigTagNews " in *" $1 "*) return 0 ;; esac ; return 1 ; }
AgentsToolsScheduleTeamTags(){ return 0 ; }
AgentsToolsScheduleDmTags(){ return 0 ; }
AgentsToolsScheduleTagCarry(){ return 0 ; }
AgentsToolsScheduleTagGive(){ return 0 ; }
AgentsToolsScheduleDutyRoutine(){ printf 'magic-team.work-duty.routine.md\n' ; }
AgentsToolsInboxDir(){ printf '%s\n' "$rigTmp/inbox-$1" ; }
AgentsToolsScheduleSpawn(){ printf '%s\n' "${2:-$1}" >> "$rigSpawnLog" ; case "$1" in work-duty.*) printf '%s\n' "${1#work-duty.}" >> "$rigSpawnLog.members" ;; esac ; return 0 ; }
AgentsToolsScheduleDismiss(){ printf '%s\n' "$1" >> "$rigDismissLog" ; }
AgentsToolsSpawnSandboxRecordHeader(){ LC_ALL=C awk -F': ' -v key="$2" '$0 == "---" && NR > 1 { exit } $1 == key { print $2 ; exit }' "$1" ; }

rigReset(){ rm -f "$rigSpawnLog" "$rigSpawnLog.members" "$rigDismissLog" "$rigLifeLog" "$rigData"/board/pending/*.md "$rigWs/.local/agents/spawned"/*/*.spawn.md 2>/dev/null ; rigFlags="" rigMemberFlags="" rigLive="" rigDemand="" rigTagNews="" rigSlow="" rigRestart="" ; }
rigStarted(){ [ -f "$rigSpawnLog.members" ] && LC_ALL=C sort "$rigSpawnLog.members" | tr '\n' ' ' | sed 's/ $//' ; printf '' ; }
rigRunLoop(){ rigOut="$( AgentsToolsScheduleWorkDuty 2>&1 )" ; }
rigRecord(){ ## member, status -- a spawn record of a work-duty run
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	printf '%s\n' '---' "spawn-id: $1-run" "status: $2" "owner: $1" 'routine: magic-team.work-duty.routine.md' '---' > "$rigWs/.local/agents/spawned/$1/$1-run.spawn.md"
}
rigWork="worktime: yes
weekend: no
holidays: no
emergency: no
overtime: no"

rigReset
rigFlags="$rigWork" rigDemand="magic-developer keeper-myx magic-coordinator partner-ndm-ndxs client-ndm warden-x"
rigRunLoop
rigAssert "worktime: the magic and keeper members with work are started; a partner, a warden and a client never" "$( rigStarted )" "keeper-myx magic-coordinator magic-developer"

rigReset
rigFlags="worktime: no
overtime: no
emergency: no" rigDemand="magic-developer keeper-myx magic-coordinator"
rigRunLoop
rigAssert "out of worktime with no flag: nobody is started, with work or not" "$( rigStarted )" ""

rigReset
rigFlags="worktime: no
overtime: yes (3600 seconds left)
emergency: no" rigDemand="magic-developer magic-tester keeper-myx keeper-ae3 magic-coordinator partner-ndm-ndxs"
rigRunLoop
rigAssert "team overtime: the magic members with work are started, and the keepers and partners are not" "$( rigStarted )" "magic-coordinator magic-developer magic-tester"

rigReset
rigFlags="worktime: no
overtime: no
emergency: no" rigDemand="keeper-myx magic-developer" rigMemberFlags="overtime:keeper-myx"
rigRunLoop
rigAssert "a member's own overtime starts that member out of hours, and no other" "$( rigStarted )" "keeper-myx"

rigReset
rigFlags="$rigWork" rigDemand="magic-developer magic-tester" rigTagNews="magic-developer" rigMemberFlags="vacation:magic-developer"
rigRunLoop
rigAssert "a member on vacation is not started in worktime, a mention of it included, and the member next to it is" "$( rigStarted )" "magic-tester"

rigReset
rigFlags="worktime: no
overtime: no
emergency: no" rigTagNews="keeper-myx magic-developer" rigMemberFlags="vacation:magic-developer"
rigRunLoop
rigAssert "out of hours a mention starts a member, and not one on vacation" "$( rigStarted )" "keeper-myx"

rigReset
rigFlags="$rigWork" rigLive="magic-developer" rigMemberFlags="vacation:magic-developer"
rigRunLoop
rigAssert "a live duty of a member on vacation is left to its own lifetime, with the flags saying it is not allowed, and no second is started" "$( rigStarted ):$( grep -c '^magic-developer allowed=no$' "$rigLifeLog" )" ":1"

rigReset
rigFlags="$rigWork" rigLive="magic-tester"
rigRunLoop
rigAssert "a live duty of a member within its flags is left to its lifetime, allowed" "$( grep -c '^magic-tester allowed=yes$' "$rigLifeLog" ):$( rigStarted )" "1:"

rigReset
rigFlags="$rigWork" rigDemand="magic-developer" rigSlow=yes
rigRunLoop
rigAssert "a slow machine starts nothing, and the pass says its pace" "$( rigStarted ):$( printf '%s\n' "$rigOut" | grep -c 'a duty start is held' )" ":1"

rigReset
rigFlags="worktime: no
overtime: no
emergency: yes (3000 seconds left)" rigDemand="magic-coordinator"
printf '%s\n' '---' 'owner: keeper-myx' 'mark: urgent' '---' > "$rigData/board/pending/task-a.md"
printf '%s\n' '---' 'owner: keeper-ae3' 'mark: normal' '---' > "$rigData/board/pending/task-b.md"
rigRunLoop
rigAssert "emergency out of hours: a member is started for its own urgent pending task, the coordinator by the flag, and no member with only an ordinary task" "$( rigStarted )" "keeper-myx magic-coordinator"

rigReset
rigFlags="$rigWork"
rigRecord partner-ndm-ndxs spawn-started
rigRecord magic-developer spawn-started
rigRecord client-ndm spawn-ended
rigRunLoop
rigAssert "a live duty of a partner is told to go at its idle point, and one of a magic member is not; one that has ended is no live duty" "$( [ -f "$rigDismissLog" ] && sed 's#.*/##' "$rigDismissLog" | tr '\n' ' ' | sed 's/ $//' )" "partner-ndm-ndxs-run.spawn.md"

if [ "$rigFails" -ne 0 ] ; then export MMDAPP="$rigReal" ; echo "⛔ WORK DUTY FLAGS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
export MMDAPP="$rigReal"
echo "WORK_DUTY_FLAGS: OK ($rigPasses assertions, offline)"
