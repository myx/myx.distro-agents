#!/usr/bin/env bash
## Behavioural check on the `supervised` flag (S13.1 and S13.12 of `20261102-refactorings.epic.md`): a scheduler flag like
## `learning`, so the rig runs the supervisor by itself, and a run it started is told to go only when the flag goes off.
## Held:
##   1. `--current-flags` prints `supervised` after `learning`, `no` until it is set, and the read writes nothing
##   2. `--override-flag supervised` turns it on and keeps `MDAT_SCHEDULE_SUPERVISED` as `on`; it takes no TTL; `--no` clears it
##   3. the console's own view carries it: a flag row after the others, and a cell in the hours to come
##   4. with the flag off, one iteration of the real loop starts no supervision run
##   5. with it on, one iteration starts exactly one, `magic-coordinator.supervision-session.routine.md`, owned by
##      magic-coordinator, on the rig's own preset and never one asked for
##   6. a second iteration, that run still live, starts no second one
##   7. the flag off again, at the run's idle point: the loop tells the run to go once, with DISMISSED in its thread
##   8. the flag off while the run WORKS: the dismissal is not given, and the loop does not say it was
## Red before S13.1: `--current-flags` has no `supervised` line, `--override-flag supervised` is refused as no such flag, and
## the loop starts nothing for it. Red before the told-to-go fix: section 8's first row, which counted the loop saying a run was
## told to go in the very iteration where the dismissal could not land.
## Offline: a rig workspace, its team data and its console are this rig's own tree; every process it starts is ended on the way out.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRoutine="magic-coordinator.supervision-session.routine.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "the tooling is not at the origin: $rigPackage"
[ -f "$rigPackage/skillset/magic-team/magic-coordinator/$rigRoutine" ] || rigRefuse "the supervision routine is not in the package skillset"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's control-thread fixture is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSupervisedFlagCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
rigRemoveTree(){
	local removeLeft=10
	while [ "$removeLeft" -gt 0 ] ; do
		chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp" 2> /dev/null
		[ ! -e "$rigTmp" ] && return 0
		sleep 1 ; removeLeft=$(( removeLeft - 1 ))
	done
	rm -rf -- "$rigTmp"
}
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren TERM $rigStarted ; sleep 1 ; rigProcSignalWithChildren KILL $rigStarted ; rigRemoveTree' EXIT
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
rigScheduleSetup 1
## Monday 2026-10-19 in Etc/GMT-3: 13:00, inside worktime.
rigMon13=1792404000
rigAt "$rigMon13"
cp "$rigPackage/skillset/magic-team/magic-coordinator/$rigRoutine" "$rigSkills/magic-coordinator/$rigRoutine" \
	|| rigRefuse "the supervision routine could not be put in the rig skillset"

## The Dispatcher's own operations, in the rig.
rigDispatchFlag(){ ## words...
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigScn" \
		bash "$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh" "$@" ) 2>&1 < /dev/null
}
rigReadSchedule(){ ## -- the console's own read of the schedule, in the rig
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigScn" \
		bash "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" --manager-schedule-read ) 2>&1 < /dev/null
}
rigFlagLine(){ ## flag -- its line of --current-flags
	rigDispatchFlag --current-flags | LC_ALL=C awk -v want="$1" 'index( $0, want ": " ) == 1 { print ; exit }'
}
rigFlagNames(){ rigDispatchFlag --current-flags | LC_ALL=C awk -F': ' '/^(worktime|weekend|holidays|emergency|overtime|learning|supervised): / { printf "%s ", $1 }' ; }
rigSettingOf(){ ## key -- the rig's own stored value, or -
	local settingValue
	settingValue="$( LC_ALL=C sed -n "s/^$1=//p" "$rigWs/.local/.agents/magic-team.agent.env" 2> /dev/null | head -1 )"
	printf '%s\n' "${settingValue:--}"
}
rigSuperRecords(){ LC_ALL=C grep -l -x "routine: $rigRoutine" "$rigSp"/*/*.spawn.md 2> /dev/null | wc -l | tr -d ' ' ; }
rigSuperRecord(){ LC_ALL=C grep -l -x "routine: $rigRoutine" "$rigSp"/*/*.spawn.md 2> /dev/null | head -1 ; }
rigHeader(){ ## record, key -- that field of the record's frontmatter
	LC_ALL=C awk -v want="$2" '$0 == "---" { if ( ++n > 1 ) exit ; next } n == 1 && index( $0, want ": " ) == 1 { print substr( $0, length( want ) + 3 ) ; exit }' "$1" 2> /dev/null
}
## THE RECORD MADE LIVE, as a run that still works: a stand-in process named in the rig's own process list, its store
## saying it sits in its Wait, and a dismissible thread. The record is written whole rather than edited, so the fields a
## dismissal reads are exactly the ones set here.
rigSuperLive(){ ## record
	local liveId liveDir liveMember liveSession
	liveId="${1##*/}" ; liveId="${liveId%.spawn.md}"
	liveMember="$( rigHeader "$1" owner )" ; liveSession="$( rigHeader "$1" session-id )"
	liveDir="$rigStores/$liveId"
	rigLiveDoorOpen || return 1
	rigLiveFifo="$rigLiveDoor" bash -c 'exec 0<"$rigLiveFifo" ; IFS= read -r rigLiveLine ; exit 0' runner 5>&- > /dev/null 2>&1 < /dev/null &
	rigStarted="$rigStarted $!"
	printf '%s claude --verbose --session-id %s --agent %s the brief\n' "$!" "$liveId" "$liveMember" >> "$rigDir/ps.list"
	disown "$!" 2> /dev/null || :
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: %s\nstatus: spawn-started\nstarted-at: 2026-10-19 10:00 +0300\nagent-log-thread: CRIG00001:1760000000.0000\nsession-thread: CRIG00001:1760000000.0000\nroutine: %s\n---\n\n# Spawn session: %s\n' \
		"$liveSession" "$liveId" "$rigHost" "$liveMember" "$rigRoutine" "$liveId" > "$1"
	mkdir -p "$liveDir/wait"
	printf '2026-10-19T10:00:00Z start\n2026-10-19T10:05:00Z wait going idle\n' > "$liveDir/milestones"
	printf 'waiting\n' > "$liveDir/wait/state"
	## The rig's clock is 13:00 that day, so the wait must be dated before the milestone that says it began: a file's
	## real mtime is later than the rig's own instant, and the run would read as working.
	touch -t 202610190959.00 "$liveDir/wait/state" 2> /dev/null || :
}
rigDismissedCount(){ LC_ALL=C grep -l -F DISMISSED "$rigScn"/post.* 2> /dev/null | wc -l | tr -d ' ' ; }

echo "-- 1. the flag is one of the schedule's --"
rigAssert "supervised is a flag of --current-flags, after learning" "$( rigFlagNames )" "worktime weekend holidays emergency overtime learning supervised "
rigAssert "and it reads no until it is set" "$( rigFlagLine supervised )" "supervised: no"
rigBefore="$( cksum < "$rigWs/.local/.agents/magic-team.agent.env" )"
rigDispatchFlag --current-flags > /dev/null
rigAssert "the read writes nothing" "$( cksum < "$rigWs/.local/.agents/magic-team.agent.env" )" "$rigBefore"

echo "-- 2. its override --"
rigDispatchFlag --override-flag supervised > /dev/null
rigAssert "the override turns it on and keeps it as a setting" "$( rigFlagLine supervised ):$( rigSettingOf MDAT_SCHEDULE_SUPERVISED )" "supervised: yes:on"
rigDispatchFlag --override-flag supervised 60 > /dev/null
rigAssert "it takes no TTL, as learning takes none" "$( rigFlagLine supervised )" "supervised: yes"
rigDispatchFlag --override-flag --no supervised > /dev/null
rigAssert "--no clears it, and the setting goes" "$( rigFlagLine supervised ):$( rigSettingOf MDAT_SCHEDULE_SUPERVISED )" "supervised: no:-"

echo "-- 3. the console's own view --"
rigReadOff="$( rigReadSchedule )"
rigDispatchFlag --override-flag supervised > /dev/null
rigReadOn="$( rigReadSchedule )"
rigAssert "a flag row for each flag, supervised the last of the seven" \
	"$( printf '%s\n' "$rigReadOff" | LC_ALL=C awk -F'\t' '$1 == "flag" { printf "%s ", $2 }' )" "worktime weekend holidays emergency overtime learning supervised "
rigAssert "the row reads no with the flag off and yes with it on" \
	"$( printf '%s\n' "$rigReadOff" | LC_ALL=C awk -F'\t' '$1 == "flag" && $2 == "supervised" { printf "%s", $3 }' ):$( printf '%s\n' "$rigReadOn" | LC_ALL=C awk -F'\t' '$1 == "flag" && $2 == "supervised" { printf "%s", $3 }' )" "no:yes"
rigAssert "the grid holds it in the hours to come" \
	"$( printf '%s\n' "$rigReadOn" | LC_ALL=C awk -F'\t' '$1 == "cell" && $4 ~ /supervised/ { n++ } END { print ( n > 100 ? "most-cells" : n + 0 ) }' )" "most-cells"
rigDispatchFlag --override-flag --no supervised > /dev/null

echo "-- 4. flag off: the loop starts no supervisor --"
rigOneRun off1 ; rigWaitStarts
rigAssert "no supervision run is started, and the iteration says nothing of one" \
	"$( rigSuperRecords ):$( rigSaid off1 'supervision:' )" "0:0"

echo "-- 5. flag on: one supervisor, on the rig's own preset --"
rigConsoleBefore="$( LC_ALL=C grep -c 'start [0-9]* magic-coordinator' "$rigDir/console.log" )"
rigDispatchFlag --override-flag supervised > /dev/null
rigOneRun on1 ; rigWaitStarts
rigAssert "one line says a supervisor was started" "$( rigSaid on1 'supervision: started' )" "1"
rigAssert "and exactly one record names the supervision routine" "$( rigSuperRecords )" "1"
rigSuperRec="$( rigSuperRecord )"
rigAssert "it is the coordinator's own run of it" "$( rigHeader "$rigSuperRec" owner )" "magic-coordinator"
rigAssert "it runs on the rig's own preset, which the start never names" "$( rigHeader "$rigSuperRec" preset )" "rig-cli"
rigAssert "the rig's console was started again for the coordinator" \
	"$(( $( LC_ALL=C grep -c 'start [0-9]* magic-coordinator' "$rigDir/console.log" ) - rigConsoleBefore > 0 ? 1 : 0 ))" "1"

echo "-- 6. a second iteration, the run still live, starts no second one --"
rigSuperLive "$rigSuperRec"
rigOneRun on2 ; rigWaitStarts
rigAssert "still one record, and no second start line" \
	"$( rigSuperRecords ):$( rigSaid on2 'supervision: started' )" "1:0"

echo "-- 7. flag off again: it is told to go, once, at its idle point --"
rigDispatchFlag --override-flag --no supervised > /dev/null
rigOneRun off2
rigAssert "the run is told to go, once" "$( rigSaid off2 'supervision: ' ):$( rigDismissedCount )" "1:1"
rigOneRun off3
rigAssert "and it is not told twice" "$( rigDismissedCount )" "1"

echo "-- 8. flag off while the run works: the dismissal does not land, and the loop does not say it did --"
## The dismissal is given at a run's idle point and nowhere else, so the ordinary case is one where nothing was posted. The loop
## used to say it had been, every iteration, and an operator could not tell a landing from silence.
rm -f "$rigWs/.local/agents/schedule/dismissed/"*
rigSupId="${rigSuperRec##*/}" ; rigSupId="${rigSupId%.spawn.md}"
printf '2026-10-19T10:00:00Z start\n2026-10-19T10:05:00Z tool going on\n' > "$rigStores/$rigSupId/milestones"
rigDismissedBefore="$( rigDismissedCount )"
rigDismissMarksBefore=0
[ ! -d "$rigWs/.local/agents/schedule/dismissed" ] || rigDismissMarksBefore="$( LC_ALL=C ls "$rigWs/.local/agents/schedule/dismissed" | LC_ALL=C grep -c . || : )"
rigOneRun off4
rigAssert "the loop says nothing of a dismissal that could not land" "$( rigSaid off4 'supervision: ' )" "0"
rigAssert "and it posts none, so no mark stands either" "$( rigDismissedCount ):$( LC_ALL=C ls "$rigWs/.local/agents/schedule/dismissed" 2> /dev/null | LC_ALL=C grep -c . || : )" "$rigDismissedBefore:$rigDismissMarksBefore"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SUPERVISED FLAG CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SUPERVISED_FLAG: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
