#!/usr/bin/env bash
## Behavioural check on S15's detach against a work-duty's own kept session. Every restart of a duty joins the session its member's duty
## founded (AgentsToolsScheduleSpawn, --join-session), so its `session-id` differs from its `spawn-id`, and it is still no run inside a session.
## Held, with records in the store's own layout, the real started list, the real liveness reading and a stand-in run that is a live process:
##   1. A RESTART IN ITS KEPT SESSION, past the bound and alive, whose session was founded by a duty run of the same owner (a failed one), is
##      not detached, keeps the kept session, reads as the member's live duty, and the pass starts no second duty.
##   2. THE CONTROL: the same restart inside a foreign session, founded by another routine, still detaches, and the pass starts a new duty.
##   3. A session founded by a duty run of another owner is foreign too: the restart detaches.
## Offline: the spawner, the pace, the flags, the tags and the member directory are stand-ins; the records, their readers, the liveness
## reading and the detach are the code under test.
set -u
: "${MDLT_ORIGIN:?MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's include is not at the origin this workspace resolves"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyKeptSessionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
sleep 600 > /dev/null 2>&1 < /dev/null &
rigLivePid=$!
trap 'kill -9 "$rigLivePid" 2> /dev/null ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws" rigMembers="$rigTmp/members" rigMember=magic-coordinator
rigSpawned="$rigWs/.local/agents/spawned" rigKept="$rigWs/.local/agents/schedule/duty-session/magic-coordinator"
mkdir -p "${rigKept%/*}" "$rigSpawned" "$rigMembers/$rigMember" "$rigTmp/home" || exit 1
printf 'status: active\n' > "$rigMembers/$rigMember/SKILL.md"
printf '# armed\n' > "$rigMembers/$rigMember/$rigMember.armed.md"
rigHost="$( hostname -s 2> /dev/null )"
[ -n "$rigHost" ] || rigRefuse "the host has no name, so no record could be read as this host's"
rigLiveAt="$( LC_ALL=C ps -o lstart= -p "$rigLivePid" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }' )"
[ -n "$rigLiveAt" ] || rigRefuse "the stand-in run has no start time, so no record of it could be made"
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
## One run record as the launcher writes it: `started-at` given in minutes before now, the live stand-in recorded as run and supervisor.
rigRecord(){ ## spawn id, session id, owner, routine, status, age in minutes, live (yes|no)
	mkdir -p "$rigSpawned/$2" || return 1
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nstart-context: %s\n' "$2" "$1" "$( [ "$1" = "$2" ] && echo spawned || echo joined )"
		printf 'host: %s\nworkspace: ws\nowner: %s\nroutine: %s\nstatus: %s\n' "$rigHost" "$3" "$4" "$5"
		printf 'started-at: %s\n' "$( date -r $(( $( date +%s ) - 60 * $6 )) '+%Y-%m-%d %H:%M %z' )"
		[ "$7" != yes ] || printf 'run-process: %s %s\nsupervisor-process: %s %s\n' "$rigLivePid" "$rigLiveAt" "$rigLivePid" "$rigLiveAt"
		printf -- '---\n\n# Spawn session: %s\n' "$1"
	} > "$rigSpawned/$2/$1.spawn.md"
}
rigField(){ ## file, field
	LC_ALL=C awk -v want="$2: " 'NR == 1 { next ; } $0 == "---" { exit ; } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit ; }' "$1" 2> /dev/null
}
## One schedule pass, then the member's live duty as the lock reads it. Prints the members the pass started, spaced.
rigRun(){
	: > "$rigTmp/calls"
	env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$rigTmp/home" MDLT_ORIGIN="$MDLT_ORIGIN" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" \
		MDAT_DUTY_BLOCKED_SECONDS=900 MDAT_STARTED_RECORDS_SECONDS=0 MDAT_DUTY_RECORDS_SECONDS=0 AGENTS_LIVENESS_TTL=0 \
		RIG_TMP="$rigTmp" RIG_CALLS="$rigTmp/calls" RIG_MEMBERS="$rigMembers" RIG_MEMBER="$rigMember" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			set +e +u
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
			AgentsToolsScheduleCurrentFlags(){ printf "%s\n" "worktime: yes" "weekend: no" "holidays: no" "emergency: no" "overtime: no" "learning: no" "supervised: no" ; return 0 ; }
			AgentsToolsSchedulePaceText(){ printf "pace: 1 of 9 calls in 30 minutes -- a duty start is allowed\n" ; return 0 ; }
			AgentsToolsScheduleTeamTags(){ return 0 ; }
			AgentsToolsScheduleDmTags(){ return 0 ; }
			AgentsToolsScheduleTagNews(){ return 1 ; }
			AgentsToolsScheduleTagCarry(){ return 0 ; }
			AgentsToolsScheduleTagGive(){ return 0 ; }
			AgentsToolsScheduleDemand(){ return 0 ; }
			AgentsToolsTeamMemberDirectoryText(){ printf "%s\t%s/%s\n" "$RIG_MEMBER" "$RIG_MEMBERS" "$RIG_MEMBER" ; }
			AgentsToolsScheduleDutyRoutine(){ printf "%s.work-duty.routine.md\n" "$RIG_MEMBER" ; }
			AgentsToolsScheduleSpawn(){ printf "%s\n" "$1" >> "$RIG_CALLS" ; return 0 ; }
			AgentsToolsScheduleDutyRestartDue(){ return 1 ; }
			AgentsToolsScheduleDutyLifetime(){ return 0 ; }
			AgentsToolsBoardItemsInto(){ printf -v "$1" "%s" "" ; return 1 ; }
			AgentsToolsScheduleWorkDuty
			rigLiveDuty="$( AgentsToolsScheduleWorkDutyRecord "$RIG_MEMBER" )"
			printf "live-duty: %s\n" "${rigLiveDuty##*/}"
		' > "$rigTmp/run.out" 2>&1
	printf '%s' "$( LC_ALL=C sed -n 's/^work-duty\.//p' "$rigTmp/calls" | LC_ALL=C tr '\n' ' ' )"
}
rigLiveDutyRead(){ LC_ALL=C sed -n 's/^live-duty: //p' "$rigTmp/run.out" ; }
rigReset(){
	rm -rf -- "$rigSpawned" "$rigWs/.local/agents/liveness" "$rigKept" 2> /dev/null
	mkdir -p "$rigSpawned" || exit 1
}

echo "-- 1. a restart in its own kept duty session, past the bound and alive: no detach, no second duty --"
rigReset
rigRecord 5e55f0a1-0000-4000-8000-000000000001 5e55f0a1-0000-4000-8000-000000000001 "$rigMember" magic-coordinator.work-duty.routine.md spawn-failed 40 no
rigRecord 7e57a0b2-0000-4000-8000-000000000002 5e55f0a1-0000-4000-8000-000000000001 "$rigMember" magic-coordinator.work-duty.routine.md spawn-started 20 yes
printf '5e55f0a1-0000-4000-8000-000000000001\n' > "$rigKept"
rigRestart="$rigSpawned/5e55f0a1-0000-4000-8000-000000000001/7e57a0b2-0000-4000-8000-000000000002.spawn.md"
rigAssert "the pass starts no second duty for the member" "$( rigRun )" ""
rigAssert "the restart reads as the member's live duty" "$( rigLiveDutyRead )" "7e57a0b2-0000-4000-8000-000000000002.spawn.md"
rigAssert "the restart is not marked detached" "$( [ -z "$( rigField "$rigRestart" duty-detached )" ] && echo unmarked || echo marked )" "unmarked"
rigAssert "the kept duty session stays" "$( cat "$rigKept" 2> /dev/null )" "5e55f0a1-0000-4000-8000-000000000001"

echo "-- 2. the control: the same restart inside a foreign session detaches, and a new duty starts --"
rigReset
rigRecord 0f0e1a2b-0000-4000-8000-000000000003 0f0e1a2b-0000-4000-8000-000000000003 "$rigMember" magic-team.coworking.routine.md spawn-started 40 no
rigRecord 7e57a0b2-0000-4000-8000-000000000002 0f0e1a2b-0000-4000-8000-000000000003 "$rigMember" magic-coordinator.work-duty.routine.md spawn-started 20 yes
printf '0f0e1a2b-0000-4000-8000-000000000003\n' > "$rigKept"
rigForeign="$rigSpawned/0f0e1a2b-0000-4000-8000-000000000003/7e57a0b2-0000-4000-8000-000000000002.spawn.md"
rigAssert "the pass starts the member's duty" "$( rigRun )" "$rigMember "
rigAssert "the restart inside a foreign session is marked detached" "$( [ -n "$( rigField "$rigForeign" duty-detached )" ] && echo marked || echo unmarked )" "marked"
rigAssert "and it is no live duty of the member" "$( rigLiveDutyRead )" ""

echo "-- 3. a session founded by another owner's duty is foreign: the restart detaches --"
rigReset
rigRecord 0ddba11a-0000-4000-8000-000000000004 0ddba11a-0000-4000-8000-000000000004 magic-tester magic-tester.work-duty.routine.md spawn-started 40 no
rigRecord 7e57a0b2-0000-4000-8000-000000000002 0ddba11a-0000-4000-8000-000000000004 "$rigMember" magic-coordinator.work-duty.routine.md spawn-started 20 yes
rigOther="$rigSpawned/0ddba11a-0000-4000-8000-000000000004/7e57a0b2-0000-4000-8000-000000000002.spawn.md"
rigAssert "the pass starts the member's duty" "$( rigRun )" "$rigMember "
rigAssert "the restart is marked detached" "$( [ -n "$( rigField "$rigOther" duty-detached )" ] && echo marked || echo unmarked )" "marked"

printf 'DUTY_KEPT_SESSION: %s (%d passed, %d failed)\n' "$( [ "$rigFailCount" = 0 ] && echo OK || echo FAIL )" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ] || exit 1
exit 0
