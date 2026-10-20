#!/usr/bin/env bash
## Behavioural check on the schedule's three steps of the main loop (F7.5 of the refactorings epic, second gate; sh-lib/session/
## AgentsTools.DispatcherLoop.include, taken at each iteration of --intern-main-loop before the heartbeat pass). The real loop (--one) and the
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
##   3. THE END OF A DUTY. When the flag stops allowing, a run of the duty is told to go with DISMISSED in its session thread, at its next idle point
##      (its Wait) and never while it works, once; a demand that comes later starts nothing until the flag allows again.
##   4. A member that is not eligible costs no Slack read: the team channel is read only for members whose flag allows (the budget itself is AgentsScheduleBudgetCheck's).
##   5. LEARNING. With learning on, a session that ended since the last look gets one inquiry into magic-librarian's inbox, once; with it off, none, and
##      none later; none for a session of the first look (a history is no news), and none for a session whose only member is magic-librarian.
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
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
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
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nstart-context: spawned\nhost: %s\nworkspace: rigws\nowner: %s\nstatus: %s\nstarted-at: 2026-10-19 08:00 +0300\nresolved-at: 2026-10-19 08:30 +0300\n---\n\n# Spawn session: %s\n' "$1" "$1" "$rigHost" "$2" "$3" "$1" > "$rigSp/$1/$1.md"
}
## Learning is on from the start, and a session has ended before the loop first looks.
printf 'MDAT_SCHEDULE_LEARNING=on\n' >> "$rigWs/.local/.agents/magic-team.agent.env"
rigFinished rig-hist-$rigTag keeper-rig-05 spawn-succeeded

echo "-- 0. the work-duty routine itself --"
rigDutyFile="$rigPackage/skillset/magic-team/magic-team/magic-team.work-duty.routine.md"
rigAssert "it is a standalone routine that declares the work-duty scan, never runs by itself, and ends its steps with --idle-wait" "$( LC_ALL=C grep -c -x -e 'requires-session-kind: standalone' -e 'input-scan-def: work-duty --session-id {{session-id}}' -e 'runs-at: none' "$rigDutyFile" ):$( LC_ALL=C grep -c -F -e '--idle-wait' "$rigDutyFile" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' )" "3:named"
rigDutyRows="$( cd "$rigWs" && env -i HOME="$rigDir/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigPackage/sh-scripts/DistroAgentsTesting.fn.sh" --skillset-validate-routine "$rigDutyFile" 2>&1 < /dev/null | LC_ALL=C grep -c -E '^[^ ]+:[0-9]+: ' || : )"
rigAssert "and the routine contract is met: the validator has no row for it" "$rigDutyRows" "0"

echo "-- 1. the autorun --"
rigOneRun first ; rigWaitStarts
rigAssert "a routine due at 09:00 daily, asked at 13:00 Monday, is started through the spawner: one line says so" "$( rigSaid first 'autorun: started keeper-rig-01.auto.routine.md' )" "1"
rigAssert "...and a spawn record of that routine stands, owned by its executor" "$( rigRecordsOf keeper-rig-01.auto.routine.md ):$( LC_ALL=C grep -l -x 'owner: keeper-rig-01' $( LC_ALL=C grep -l -x 'routine: keeper-rig-01.auto.routine.md' "$rigSp"/*/*.md ) | wc -l | tr -d ' ' )" "1:1"
rigAssert "its successor, which follows it, waits quietly: not started, and no line of it" "$( rigRecordsOf keeper-rig-01.chain.routine.md ):$( rigSaid first 'keeper-rig-01.chain' )" "0:0"
rigAssert "a routine whose executors are any member is not started, and not complained of" "$( rigRecordsOf keeper-rig-02.anyone.routine.md ):$( rigSaid first 'keeper-rig-02.anyone' )" "0:0"
rigAssert "the pass of the loop ran after the schedule's lines" "$( [ "$( LC_ALL=C grep -n -F 'autorun: started' "$rigDir/first.err" | head -1 | cut -d: -f1 )" -lt "$( LC_ALL=C grep -n -F 'heartbeat iteration starting' "$rigDir/first.err" | head -1 | cut -d: -f1 )" ] && printf before )" "before"
## The predecessor completed: the record the spawner made is closed as a well-ended run, today.
for rigRecord in $( LC_ALL=C grep -l -x 'routine: keeper-rig-01.auto.routine.md' "$rigSp"/*/*.md ) ; do
	LC_ALL=C sed -i.bak -e 's/^status: .*/status: spawn-succeeded/' -e '/^resolved-at: /d' "$rigRecord" && rm -f "$rigRecord.bak"
	LC_ALL=C awk '{ print } /^started-at: / { sub( /^started-at: /, "" ) ; print "resolved-at: " $0 }' "$rigRecord" > "$rigRecord.next" && mv -f "$rigRecord.next" "$rigRecord"
done
rigAt $(( rigMon13 + 60 ))
rigOneRun second ; rigWaitStarts
rigAssert "the next iteration starts the successor, now that its predecessor completed today" "$( rigSaid second 'autorun: started keeper-rig-01.chain.routine.md' ):$( rigRecordsOf keeper-rig-01.chain.routine.md )" "1:1"
rigAssert "and starts the first one no more: it ran today" "$( rigRecordsOf keeper-rig-01.auto.routine.md ):$( rigSaid second 'autorun: started keeper-rig-01.auto.routine.md' )" "1:0"

echo "-- 2. work duty by the flags --"
rigAt $(( rigMon13 + 120 ))
rigItem keeper-rig-02 ; rigItem keeper-rig-03
rigOneRun duty1 ; rigWaitStarts
rigAssert "worktime, and an item in the inbox: the duty of keeper-rig-02 and of keeper-rig-03 is started" "$( rigSaid duty1 'work-duty: started the duty of keeper-rig-02' ):$( rigSaid duty1 'work-duty: started the duty of keeper-rig-03' )" "1:1"
rigAssert "each is a session of the work-duty routine owned by that member: one each, and none for a member with nothing to work on" "$( rigDutyCount keeper-rig-02 ):$( rigDutyCount keeper-rig-03 ):$( rigDutyCount keeper-rig-04 )" "1:1:0"
rigItem oncall-rig ; rigItem human-owner
rigAssert "an oncall member and human-owner get none, whatever is in their inbox: no line of them" "$( rigDutyCount oncall-rig ):$( rigDutyCount human-owner ):$( rigSaid duty1 'oncall-rig' ):$( rigSaid duty1 'human-owner' )" "0:0:0:0"
echo "-- 3. the end of a duty --"
## The duty of keeper-rig-02 as a live run in a Wait, and that of keeper-rig-03 as one at work.
rigLiveSpawn=""
rigLive(){ ## member, idle|working -- the run of that member's duty in the rig: a stand-in process, a record, a thread and a store; its spawn id in rigLiveSpawn
	local liveRecord liveSpawn
	liveRecord="$( LC_ALL=C grep -l -x "owner: $1" $( LC_ALL=C grep -l -x 'routine: magic-team.work-duty.routine.md' "$rigSp"/*/*.md ) | head -1 )"
	liveSpawn="${liveRecord##*/}" ; liveSpawn="${liveSpawn%.md}"
	LC_ALL=C sed -i.bak -e 's/^status: .*/status: spawn-started/' -e '/^resolved-at: /d' "$liveRecord" && rm -f "$liveRecord.bak"
	if ! LC_ALL=C grep -q '^session-thread: ' "$liveRecord" ; then
		LC_ALL=C awk '{ print } /^status: / { print "session-thread: CRIG00001:1760000000.0000" NR }' "$liveRecord" > "$liveRecord.next" && mv -f "$liveRecord.next" "$liveRecord"
	fi
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigProcNote "$!" ; rigStarted="$rigStarted $!"
	printf '%s claude --verbose --session-id %s --agent %s the brief\n' "$!" "$liveSpawn" "$1" >> "$rigDir/ps.list"
	disown "$!" 2> /dev/null || :
	mkdir -p "$rigStores/$liveSpawn"
	if [ "$2" = idle ] ; then printf '2026-10-19T10:00:00Z start\n2026-10-19T10:05:00Z wait going idle\n' > "$rigStores/$liveSpawn/milestones"
	else printf '2026-10-19T10:00:00Z start\n2026-10-19T10:05:00Z message out\n' > "$rigStores/$liveSpawn/milestones" ; fi
	rigLiveSpawn="$liveSpawn"
}
rigLive keeper-rig-02 idle ; rigSpawn02="$rigLiveSpawn" ; rigLive keeper-rig-03 working ; rigSpawn03="$rigLiveSpawn"
rigAt "$rigMon18"
rigOneRun end1
rigAssert "worktime is over: the run in its Wait is told to go, once, with DISMISSED in its session thread" "$( rigSaid end1 "work-duty: $rigSpawn02 of keeper-rig-02 is told to go" ):$( LC_ALL=C grep -l -F DISMISSED "$rigScn"/post.* 2> /dev/null | wc -l | tr -d ' ' )" "1:1"
rigAssert "the run at work is told nothing: never mid-work" "$( rigSaid end1 "work-duty: $rigSpawn03 of" )" "0"
rigOneRun end2
rigAssert "the run already told is not told twice" "$( LC_ALL=C grep -l -F DISMISSED "$rigScn"/post.* 2> /dev/null | wc -l | tr -d ' ' )" "1"
printf '2026-10-19T10:05:00Z wait going idle\n' >> "$rigStores/$rigSpawn03/milestones"
rigOneRun end3
rigAssert "at its next idle point the other is told: DISMISSED reaches it" "$( rigSaid end3 "work-duty: $rigSpawn03 of keeper-rig-03 is told to go" ):$( LC_ALL=C grep -l -F DISMISSED "$rigScn"/post.* 2> /dev/null | wc -l | tr -d ' ' )" "1:2"
rigItem keeper-rig-04
rigTagsBefore="$( cksum < "$rigWs/.local/agents/schedule/team-channel" )"
rigOneRun end4
rigAssert "the demand of a member outside its flag starts nothing: the duty of keeper-rig-04 is not started" "$( rigStartsOf keeper-rig-04 ):$( rigSaid end4 'the duty of keeper-rig-04' )" "0:0"
rigAssert "...and costs no read of the team channel: no member is eligible, so its record is as it was" "$( cksum < "$rigWs/.local/agents/schedule/team-channel" )" "$rigTagsBefore"
rigItem magic-coordinator
rigOneRun end5
rigAssert "magic-coordinator is not on duty after worktime without emergency or overtime" "$( rigSaid end5 'the duty of magic-coordinator' )" "0"
rigDispatch --override-flag overtime
rigOneRun end6 ; rigWaitStarts
rigAssert "with overtime it is: its duty is started" "$( rigSaid end6 'work-duty: started the duty of magic-coordinator' )" "1"
rigAt $(( rigMon13 + 86400 ))
rigOneRun back1 ; rigWaitStarts
rigAssert "worktime again: the demand of keeper-rig-04 is answered" "$( rigSaid back1 'work-duty: started the duty of keeper-rig-04' )" "1"

echo "-- 5. learning --"
rigInquiries(){ ## session id -- the inquiries of the librarian's inbox that are about that session
	LC_ALL=C ls "$rigData/inboxes/magic-librarian/incoming" 2> /dev/null | LC_ALL=C grep -c -F -- "-learning-$1.md" || :
}
rigAssert "learning was on at the first look, and the session that had ended before it is history: marked, no inquiry (the sessions the loop started itself ended since, and have theirs)" "$( rigInquiries rig-hist-$rigTag ):$( [ -e "$rigWs/.local/agents/schedule/learned/rig-hist-$rigTag" ] && printf marked )" "0:marked"
rigFinished rig-new-$rigTag keeper-rig-06 spawn-succeeded
rigFinished rig-lib-$rigTag magic-librarian spawn-succeeded
rigOneRun learnA
rigAssert "a session that ended since, learning on: one inquiry into magic-librarian's inbox, and a line says so" "$( rigInquiries rig-new-$rigTag ):$( rigSaid learnA "learning: session rig-new-$rigTag ended: one inquiry to magic-librarian" )" "1:1"
rigAssert "the inquiry names the session and holds the words of the template" "$( LC_ALL=C grep -l -F "rig-new-$rigTag" "$rigData"/inboxes/magic-librarian/incoming/inquiry-*-learning-rig-new-* | wc -l | tr -d ' ' ):$( LC_ALL=C grep -q 'retro' "$rigData"/inboxes/magic-librarian/incoming/inquiry-*-learning-rig-new-* && printf words )" "1:words"
rigAssert "a session whose only member is magic-librarian gets none" "$( rigInquiries rig-lib-$rigTag )" "0"
rigDispatch --override-flag --no learning
rigFinished rig-off-$rigTag keeper-rig-07 spawn-succeeded
rigOneRun learnB
rigAssert "the next iteration sends no second one for the first, and none for a session that ended with learning off" "$( rigInquiries rig-new-$rigTag ):$( rigInquiries rig-off-$rigTag )" "1:0"
rigDispatch --override-flag learning
rigOneRun learnC
rigAssert "...and none later, when learning is on again" "$( rigInquiries rig-new-$rigTag ):$( rigInquiries rig-off-$rigTag )" "1:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE LOOP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_LOOP: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
