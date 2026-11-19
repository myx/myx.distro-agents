#!/usr/bin/env bash
## Behavioural check on S15's first part (epic-blueprint-20261102T0000Z-refactorings, S15 Rules line 6 and Open 3):
## a duty that went into a session and stayed there past its bound detaches, and a new duty starts in the same pass.
## The failing case is the one measured 2026-11-17 09:41 +0200: the member's joined duty holds the work-duty lock, so a
## start is refused, and nothing gives the floor back. Held:
##   1. THE DETACH: a joined duty, its `session-id` other than its `spawn-id`, whose `started-at` is past the bound,
##      gives its lock back and its record carries `duty-detached`.
##   2. THE NEW DUTY: the same pass starts that member's duty, and says why.
##   3. THE BOUND IS REAL: the same joined duty inside the bound detaches nothing and starts nothing. The bound the check
##      runs with is stated here, so the edge is exercised at 20 minutes past and 5 minutes inside it.
##   4. THE SESSION IS KEPT: the detach changes no `session-id` and deletes no record, so the run keeps its session and
##      its work. A detach is never a kill.
##   5. INSIDE A SESSION IS REAL: a duty whose `session-id` is its own (`spawn-id`) is no run inside a session, however
##      old, and it detaches nothing.
## Offline: the store's list providers, the liveness reading, the spawner and the lock's own release are stand-ins; the
## record readers, the detach and the pass's control flow are the code under test. The lock's real release is held by
## AgentsWorkDutyLockCheck.
set -u
: "${MMDAPP:?MMDAPP is not set}"
: "${MDLT_ORIGIN:?MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's include is not at the origin this workspace resolves"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyBlockedDetachCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
## The pass runs with MMDAPP at the rig's own root, and the store under its .local, so the schedule's kept files and the
## store's own makers both see one rig.
rigWs="$rigTmp" rigData="$rigTmp/.local/agents/team-data" rigMembers="$rigTmp/members" rigSpawned="$rigTmp/.local/agents/spawned"
rigMember=magic-coordinator
rigNote="note-20261020T000000Z-work-duty-state-and-lock.md"
rigInbox="$rigData/inboxes/$rigMember/incoming"
mkdir -p "$rigWs/.local/agents/schedule/duty-session" "$rigSpawned" "$rigMembers/$rigMember" "$rigTmp/home" || exit 1
## THE STORE IS THE OWNERS' OWN: the board's folders and the member's inbox are made by their makers, and every item is
## written by the store's upsert, never by this check's redirect.
MMDAPP="$rigWs" ; export MMDAPP
rigBoardStates "$rigData" || rigRefuse "the rig's board folders could not be made"
rigInboxReady "$rigData" "$rigMember" || rigRefuse "the rig's inbox could not be made"
printf 'status: active\n' > "$rigMembers/$rigMember/SKILL.md"
printf '# armed\n' > "$rigMembers/$rigMember/$rigMember.armed.md"
## The work the duty has, so the start is never refused for want of demand.
printf -- '---\ntype: note\nfrom: magic-coordinator\n---\n\nrig work\n' > "$rigTmp/body.work.md"
MMDAPP="$rigWs" ; export MMDAPP
rigStoreItem "$rigWs" "$rigData" "$rigWs" "$rigMember" "inbox $rigMember note-20261106T000000Z-rig-work.md" "$rigTmp/body.work.md" || rigRefuse "the rig's inbox work could not be written"
rigPassCount=0
rigFailCount=0
## The bound the pass runs with, one setting: 900 s, magic-coordinator's ruling of 2026-11-17 11:16 +0200.
rigBound=900
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
## One duty record, as the launcher records it: the joined run's `session-id` is the session it went into, its own
## `spawn-id` another name; the founding run's two are the same. `started-at` is given in minutes before now.
rigRecord(){ ## the spawn id, the session id, its age in minutes, the routine
	mkdir -p "$rigSpawned/$2" || return 1
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nstart-context: %s\n' "$2" "$1" "$([ "$1" = "$2" ] && echo spawned || echo joined)"
		printf 'routine-lock: inbox:%s:%s\ncache-prefix: extended\nreports-to: none\nparent-member: magic-coordinator\n' "$rigMember" "$rigNote"
		printf 'host: %s\nworkspace: %s\nexecuting-workspace: %s\npaying-workspace: %s\nmember-workspace: %s\n' "$( hostname -s )" "${rigWs##*/}" "${rigWs##*/}" "${rigWs##*/}" "${rigWs##*/}"
		printf 'owner: %s\nroutine: %s\nstatus: spawn-started\nstarted-at: %s\nday-first: no\n' "$rigMember" "$4" "$( date -r $(( $( date +%s ) - 60 * $3 )) '+%Y-%m-%d %H:%M %z' )"
		printf 'session-thread: CRIG00001:1700000000.000001\n---\n\n# Spawn session: %s\n' "$2"
	} > "$rigSpawned/$2/$1.spawn.md"
}
## The lock as the spawner takes it: held by the session, its recheck-date ahead, so it is no free lock. Written by the
## store's own upsert, as the spawner writes it; what the spawner's own take costs is AgentsWorkDutyLockCheck's subject.
rigLock(){ ## the holding session id
	{
		printf -- '---\ntype: note\nfrom: %s\nowner: %s\nstate: work-duty-running\n' "$rigMember" "$rigMember"
		printf 'session-id: %s\nrecheck-date: %s\nheld-on: %s %s\nheld-at: %s\n---\n\n' "$1" "$( date -r $(( $( date +%s ) + 7200 )) '+%Y-%m-%d %H:%M %z' )" "$( hostname -s )" "${rigWs##*/}" "$( date '+%Y-%m-%d %H:%M %z' )"
		printf '# the state of the work-duty routine, locked by the spawner while it runs.\n'
	} > "$rigTmp/body.lock.md" || return 1
	MMDAPP="$rigWs" ; export MMDAPP
	rigStoreItem "$rigWs" "$rigData" "$rigWs" "$rigMember" "inbox $rigMember $rigNote" "$rigTmp/body.lock.md"
}
rigField(){ ## file, field
	LC_ALL=C awk -v want="$2: " 'NR == 1 { next ; } $0 == "---" { exit ; } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit ; }' "$1" 2> /dev/null
}
## The stand-ins. Every one is inherited by the include's `type ... || . ` guards, so no real one is sourced over it.
rigRun(){ ## -- the members this pass started, in its order
	: > "$rigTmp/calls"
	env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_DUTY_BLOCKED_SECONDS="$rigBound" \
		RIG_FLAGS="$rigTmp/flags" RIG_CALLS="$rigTmp/calls" RIG_MEMBERS="$rigMembers" \
		RIG_DATA="$rigData" RIG_WS="$rigWs" RIG_SPAWNED="$rigSpawned" RIG_MEMBER="$rigMember" \
		bash -c '
			MMDAPP="$RIG_WS" ; export MMDAPP
			MDAT_DATA_ROOT="$RIG_DATA" ; export MDAT_DATA_ROOT
			AGENTS_LIVENESS_TTL=0 ; export AGENTS_LIVENESS_TTL
			set +e +u
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
			AgentsToolsScheduleCurrentFlags(){ cat "$RIG_FLAGS" ; return 0 ; }
			AgentsToolsSchedulePaceText(){ printf "pace: 1 of 9 calls in 30 minutes -- a duty start is allowed\n" ; return 0 ; }
			AgentsToolsScheduleDutyStaleClose(){ return 0 ; }
			AgentsToolsScheduleTeamTags(){ return 0 ; }
			AgentsToolsScheduleDmTags(){ return 0 ; }
			AgentsToolsScheduleTagNews(){ return 1 ; }
			AgentsToolsScheduleTagCarry(){ return 0 ; }
			AgentsToolsTeamMemberDirectoryText(){ printf "%s\t%s/%s\n" "$RIG_MEMBER" "$RIG_MEMBERS" "$RIG_MEMBER" ; }
			AgentsToolsScheduleDutyRoutine(){ printf "%s.work-duty.routine.md\n" "$RIG_MEMBER" ; }
			AgentsToolsScheduleSpawn(){ printf "%s\n" "$1" >> "$RIG_CALLS" ; return 0 ; }
			AgentsToolsScheduleDutyRestartDue(){ return 1 ; }
			AgentsToolsScheduleDutyLifetime(){ return 0 ; }
			AgentsToolsBoardItemsInto(){ printf -v "$1" "%s" "" ; return 1 ; }
			## The store list and the liveness reading are providers, not the subject: every rig record is a started
			## record of a live run, and the run of a joined record is alive in the session it went into.
			AgentsToolsSpawnedStartedRecords(){ find "$RIG_SPAWNED" -type f -name "*.spawn.md" 2> /dev/null ; }
			AgentsToolsLivenessOf(){ printf "alive\n" ; return 0 ; }
			## The lock release is AgentsWorkDutyLockChecks own subject; here it releases the rig note and records the call.
			AgentsToolsRoutineLockUnlock(){ printf "unlock %s %s\n" "$1" "$2" >> "$RIG_CALLS"
				rigUnlockPath="$RIG_DATA/inboxes/$RIG_MEMBER/incoming/${1##*:}"
				[ -f "$rigUnlockPath" ] || return 1
				printf "%s\n" "$3" > "$RIG_DATA/unlocked"
				printf -- "---\ntype: note\nfrom: %s\nowner: %s\nstate: work-duty-finished\nlast-receipt: %s\n---\n\n# the state of the work-duty routine.\n" "$RIG_MEMBER" "$RIG_MEMBER" "$3" > "$rigUnlockPath"
				return 0 ; }
			AgentsToolsScheduleWorkDuty 2> /dev/null
		' > "$rigTmp/run.out" 2> /dev/null
	printf '%s' "$( LC_ALL=C grep -E '^work-duty\.' "$rigTmp/calls" 2> /dev/null | LC_ALL=C sed 's/^work-duty\.//' | LC_ALL=C tr '\n' ' ' )"
}
rigFlags(){ printf '%s\n' "worktime: yes" "weekend: no" "holidays: no" "emergency: no" "overtime: no" "learning: no" "supervised: no" > "$rigTmp/flags" ; }
rigReset(){
	rm -f "$rigSpawned"/*/*.spawn.md "$rigData/unlocked" "$rigWs/.local/agents/schedule/duty-session/$rigMember" 2> /dev/null
	: > "$rigTmp/calls"
}
rigFlags

echo "-- 1 to 4. a duty inside a session past the bound: it detaches, and a new duty starts --"
rigReset
rigRecord 1dc0fc51-d006-4a98-8111-e0dba5e3e37b b6a14d2b-25d2-4773-9a0f-c0c59c799ed1 20 magic-coordinator.work-duty.routine.md
rigLock b6a14d2b-25d2-4773-9a0f-c0c59c799ed1
printf 'b6a14d2b-25d2-4773-9a0f-c0c59c799ed1\n' > "$rigTmp/kept" ; mkdir -p "$rigWs/.local/agents/schedule/duty-session" ; cp "$rigTmp/kept" "$rigWs/.local/agents/schedule/duty-session/$rigMember"
rigJoinedRecord="$rigSpawned/b6a14d2b-25d2-4773-9a0f-c0c59c799ed1/1dc0fc51-d006-4a98-8111-e0dba5e3e37b.spawn.md"
rigStarted="$( rigRun )"
rigAssert "the pass starts the member whose duty was blocked inside a session past its bound" "$rigStarted" "$rigMember "
rigAssert "the detached record says so, in one field" "$( [ -n "$( rigField "$rigJoinedRecord" duty-detached )" ] && echo marked || echo unmarked )" "marked"
rigAssert "the lock is given back: the note reads finished, with the detach as its receipt" "$( rigField "$rigInbox/$rigNote" state ):$( [ -n "$( rigField "$rigInbox/$rigNote" last-receipt )" ] && echo receipt || echo none )" "work-duty-finished:receipt"
rigAssert "the new duty is a session of its own: the kept session id of the detached run is gone" "$( [ -f "$rigWs/.local/agents/schedule/duty-session/$rigMember" ] && echo kept || echo gone )" "gone"
rigAssert "the detached run keeps its session and its work: its record and its session-id are untouched" "$( [ -f "$rigJoinedRecord" ] && echo there || echo missing ):$( rigField "$rigJoinedRecord" session-id )" "there:b6a14d2b-25d2-4773-9a0f-c0c59c799ed1"
rigAssert "the start says why it is made" "$( LC_ALL=C grep -c -F 'detached' "$rigTmp/run.out" || : )" 1

echo "-- 3. inside the bound: nothing detaches, nothing starts --"
rigReset
rigRecord 1dc0fc51-d006-4a98-8111-e0dba5e3e37b b6a14d2b-25d2-4773-9a0f-c0c59c799ed1 5 magic-coordinator.work-duty.routine.md
rigLock b6a14d2b-25d2-4773-9a0f-c0c59c799ed1
rigYoungRecord="$rigSpawned/b6a14d2b-25d2-4773-9a0f-c0c59c799ed1/1dc0fc51-d006-4a98-8111-e0dba5e3e37b.spawn.md"
rigAssert "a duty inside a session inside its bound starts nothing" "$( rigRun )" ""
rigAssert "and its record is not marked" "$( [ -z "$( rigField "$rigYoungRecord" duty-detached )" ] && echo unmarked || echo marked )" "unmarked"
rigAssert "and its lock still reads running" "$( rigField "$rigInbox/$rigNote" state )" "work-duty-running"

echo "-- 5. a duty whose session is its own, however old: it is no run inside a session --"
rigReset
rigRecord b6a14d2b-25d2-4773-9a0f-c0c59c799ed1 b6a14d2b-25d2-4773-9a0f-c0c59c799ed1 3000 magic-coordinator.work-duty.routine.md
rigLock b6a14d2b-25d2-4773-9a0f-c0c59c799ed1
rigOwnRecord="$rigSpawned/b6a14d2b-25d2-4773-9a0f-c0c59c799ed1/b6a14d2b-25d2-4773-9a0f-c0c59c799ed1.spawn.md"
rigAssert "a duty that founded its own session detaches nothing, however old it is" "$( rigRun )" ""
rigAssert "and its record is not marked" "$( [ -z "$( rigField "$rigOwnRecord" duty-detached )" ] && echo unmarked || echo marked )" "unmarked"

printf 'DUTY_BLOCKED_DETACH: %s (%d passed, %d failed)\n' "$([ "$rigFailCount" = 0 ] && echo OK || echo FAIL)" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ] || exit 1
exit 0
