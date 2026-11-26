#!/usr/bin/env bash
## Behavioural check on the schedule's three steps of the main loop (F7.5 of the refactorings epic, second gate; sh-lib/session/
## AgentsTools.DispatcherSchedule.include, taken at each iteration of --intern-main-loop after its configuration check). The real loop (--one) and the
## real spawner run, as in AgentsSessionControlMainLoopCheck; the console, curl, date and every setting are this rig's own. GUARD: every tooling
## call goes through one `env -i` whose child refuses to start unless MMDAPP and MDAT_DATA_ROOT sit under this rig's tree and PATH holds no agent CLI.
## Held:
##   1. AUTORUN. A routine with a runs-at that is due is started through the spawner, once a day, and says so in one line; one that follows a
##      predecessor waits quietly until the predecessor completed that day and is started in the first iteration after; a routine of any member
##      is asked (each identity once). A routine whose executors are any member is not started.
##   2. WORK DUTY BY THE FLAGS. During worktime a member of the roster that has something to work on (an item in its inbox) gets one work-duty
##      session, `magic-team.work-duty.routine`, and not a second while it holds one; a member with nothing gets none; human-owner (an identity
##      record) and an oncall member get none. magic-coordinator also holds duty during emergency and overtime. A member whose flag does not allow is
##      started nothing, whatever it has to work on.
##   3. THE END OF A DUTY. A run of the duty that is out of its flags, with no input and idle for more than an hour, is told to go with DISMISSED in
##      its session thread, at its next idle point (its Wait) and never while it works, once; one that still has input is not (the whole lifetime
##      rule -- the cache, the session, the 20 minutes, the holidays -- is AgentsDutyLifetimeCheck's); a demand that comes later starts nothing
##      until the flag allows again.
##   4. A member that is not eligible costs no Slack read: the team channel is read only for members whose flag allows (the budget itself is AgentsScheduleBudgetCheck's).
##   5. LEARNING. With learning on, a session that ended since the last look gets one inquiry into magic-librarian's inbox, once; with it off, none, and
##      none later; none for a session of the first look (a history is no news), and none for a session whose only member is magic-librarian.
##      A session that finishes by its verdict alone, with no run started or ended, is learned on the next pass; a sync that changes no review
##      item runs no look.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRealTemplate="$rigPackage/sh-lib/templates/spawn-brief.document.format.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "dispatcher not found"
[ -f "$rigRealTemplate" ] || rigRefuse "the brief template is not in the package: $rigRealTemplate"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleLoopCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
## A detached session of the rig may still write into the tree for a moment after it is signalled: the removal is tried again, for ten seconds, before it says what it could not remove.
rigRemoveTree(){
	local removeLeft=10
	while [ "$removeLeft" -gt 0 ] ; do
		chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp" 2> /dev/null
		[ ! -e "$rigTmp" ] && return 0
		sleep 1 ; removeLeft=$(( removeLeft - 1 ))
	done
	rm -rf -- "$rigTmp"
}
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rigRemoveTree' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
. "$rigPackage/sh-test/check-fixtures/rig-schedule-loop.include.sh" || rigRefuse "the schedule rig fixture is missing from the package"
rigScheduleSetup 4
## Monday 2026-10-19 in Etc/GMT-3: 13:00 (worktime), 18:00 (after it).
rigMon13=1792404000 ; rigMon18=1792422000
rigAt "$rigMon13"
rigFinished(){ ## session, member, status
	mkdir -p "$rigSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nstart-context: spawned\nhost: %s\nworkspace: rigws\nowner: %s\nstatus: %s\nstarted-at: 2026-10-19 08:00 +0300\nresolved-at: 2026-10-19 08:30 +0300\n---\n\n# Spawn session: %s\n' "$1" "$1" "$rigHost" "$2" "$3" "$1" > "$rigSp/$1/$1.spawn.md"
}
## Learning is on from the start, and a session has ended before the loop first looks.
printf 'MDAT_SCHEDULE_LEARNING=on\n' >> "$rigWs/.local/.agents/magic-team.agent.env"
rigFinished rig-hist-${rigTag}hist keeper-rig-05 spawn-succeeded

echo "-- 0. the work-duty routine itself --"
rigDutyFile="$rigPackage/skillset/magic-team/magic-team/magic-team.work-duty.routine.md"
rigAssert "it is a standalone routine that declares the work-duty scan, never runs by itself, and ends its steps with --idle-wait" "$( LC_ALL=C grep -c -x -e 'requires-session-kind: standalone' -e 'input-scan-def: work-duty --session-id {{session-id}}' -e 'runs-at: none' "$rigDutyFile" ):$( LC_ALL=C grep -c -F -e '--idle-wait' "$rigDutyFile" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' )" "3:named"
rigDutyRows="$( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigPackage/sh-scripts/DistroAgentsTesting.fn.sh" --skillset-validate-routine "$rigDutyFile" 2>&1 < /dev/null | LC_ALL=C grep -c -E '^[^ ]+:[0-9]+: ' || : )"
rigAssert "and the routine contract is met: the validator has no row for it" "$rigDutyRows" "0"

echo "-- 1. the autorun --"
rigOneRun first ; rigWaitStarts
rigAssert "a routine due at 09:00 daily, asked at 13:00 Monday, is started through the spawner: one line says so" "$( rigSaid first 'autorun: started keeper-rig-01.auto.routine.md' )" "1"
rigAssert "...and a spawn record of that routine stands, owned by its executor" "$( rigRecordsOf keeper-rig-01.auto.routine.md ):$( LC_ALL=C grep -l -x 'owner: keeper-rig-01' $( LC_ALL=C grep -l -x 'routine: keeper-rig-01.auto.routine.md' "$rigSp"/*/*.spawn.md ) | wc -l | tr -d ' ' )" "1:1"
rigAssert "its successor, which follows it, waits quietly: not started, and no line of it" "$( rigRecordsOf keeper-rig-01.chain.routine.md ):$( rigSaid first 'keeper-rig-01.chain' )" "0:0"
rigAssert "a routine whose executors are any member is not started, and not complained of" "$( rigRecordsOf keeper-rig-02.anyone.routine.md ):$( rigSaid first 'keeper-rig-02.anyone' )" "0:0"
rigAssert "the configuration check of the loop ran before the schedule's lines" "$( [ "$( LC_ALL=C grep -n -F 'configuration check passed' "$rigDir/first.err" | head -1 | cut -d: -f1 )" -lt "$( LC_ALL=C grep -n -F 'autorun: started' "$rigDir/first.err" | head -1 | cut -d: -f1 )" ] && printf before )" "before"
## The predecessor completed: the record the spawner made is closed as a well-ended run, today.
for rigRecord in $( LC_ALL=C grep -l -x 'routine: keeper-rig-01.auto.routine.md' "$rigSp"/*/*.spawn.md ) ; do
	LC_ALL=C sed -i.bak -e 's/^status: .*/status: spawn-succeeded/' -e '/^resolved-at: /d' "$rigRecord" && rm -f "$rigRecord.bak"
	LC_ALL=C awk '{ print ; } /^started-at: / { sub( /^started-at: /, "" ) ; print "resolved-at: " $0 ; }' "$rigRecord" > "$rigRecord.next" && mv -f "$rigRecord.next" "$rigRecord"
done
rigAt $(( rigMon13 + 60 ))
rigOneRun second ; rigWaitStarts
rigAssert "the next iteration starts the successor, now that its predecessor completed today" "$( rigSaid second 'autorun: started keeper-rig-01.chain.routine.md' ):$( rigRecordsOf keeper-rig-01.chain.routine.md )" "1:1"
rigAssert "and starts the first one no more: it ran today" "$( rigRecordsOf keeper-rig-01.auto.routine.md ):$( rigSaid second 'autorun: started keeper-rig-01.auto.routine.md' )" "1:0"

echo "-- 2. work duty by the flags --"
rigAt $(( rigMon13 + 120 ))
rigItem keeper-rig-02 ; rigItem keeper-rig-03
## The schedule starts one duty a pass (the human-owner's rule), so the two duties are started by two passes, a second apart on the rig's clock.
rigOneRun duty1 ; rigWaitStarts
rigAt $(( rigMon13 + 121 ))
rigOneRun duty1b ; rigWaitStarts
rigAssert "worktime, and an item in the inbox: the duty of keeper-rig-02 and of keeper-rig-03 is started, one a pass" "$(( $( rigSaid duty1 'work-duty: started the duty of keeper-rig-02' ) + $( rigSaid duty1b 'work-duty: started the duty of keeper-rig-02' ) )):$(( $( rigSaid duty1 'work-duty: started the duty of keeper-rig-03' ) + $( rigSaid duty1b 'work-duty: started the duty of keeper-rig-03' ) ))" "1:1"
rigAssert "each is a session of the work-duty routine owned by that member: one each, and none for a member with nothing to work on" "$( rigDutyCount keeper-rig-02 ):$( rigDutyCount keeper-rig-03 ):$( rigDutyCount keeper-rig-04 )" "1:1:0"
rigItem oncall-rig ; rigItem human-owner
rigAssert "an oncall member and human-owner get none, whatever is in their inbox: no line of them" "$( rigDutyCount oncall-rig ):$( rigDutyCount human-owner ):$( rigSaid duty1 'oncall-rig' ):$( rigSaid duty1 'human-owner' )" "0:0:0:0"
## THIS HALF HOLDS SECTIONS 0 TO 2: the work-duty routine, the autorun and the flag-driven duty start. The end of a duty, learning and the
## failing configuration check moved to AgentsScheduleLoopEndCheck, which carries the same head and the same fixture. The one check ran 24 schedule
## passes and ended at the runner's own 900-second limit (905 s, measured 2026-11-25), so no one ever read its verdict.
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE LOOP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_LOOP_START: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
