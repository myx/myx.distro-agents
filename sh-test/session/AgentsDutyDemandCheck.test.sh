#!/usr/bin/env bash
## Behavioural check on what starts the work duty of a member (F7.12; AgentsToolsScheduleDemand and its helpers in AgentsTools.DispatcherLoop.include), by script:
##   1. THE INBOX: an item in a member's incoming/ is work; the standing state-and-lock notes of the routines that lock, which stand in the coordinator's
##      incoming/, are not, so an idle coordinator is not started for them.
##   2. THE BOARD, for the coordinator alone: an item of an active state (pending, running, review, blocked, parked) written since its duty last ended is news;
##      so is an item whose recheck-date fell due since. The end of a duty is the modification time of the duty's lock note; with no note, any such item
##      is news. The spawner's own dispatch-* tracking items are written at every start and end and are no news; an item of backlog or processed is not
##      either. A keeper has no demand of the board.
##   3. THE ROUTINE of a member's duty is its own `<member>.work-duty.routine.md` where its skill folder holds one, else the team's.
## Offline: a data root and a workspace of this rig, the functions run in a clean environment.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/session/AgentsTools.DispatcherLoop.include" ] || rigRefuse "the loop's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyDemandCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data" rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/schedule" "$rigTmp/home" "$rigTmp/skills/keeper-rig"
for rigState in backlog pending running review blocked parked processed ; do mkdir -p "$rigData/board/$rigState" ; done
mkdir -p "$rigData/inboxes/magic-coordinator/incoming" "$rigData/inboxes/magic-coordinator/processed" "$rigData/inboxes/keeper-rig/incoming" "$rigData/inboxes/keeper-rig/processed"
rigNote="$rigData/inboxes/magic-coordinator/incoming/note-20261020T000000Z-work-duty-state-and-lock.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigFn(){ ## the function and its arguments... -- run in the loop's include; prints yes or no for its rc, and what it printed
	local fnOut fnRc
	fnOut="$( env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_TMP="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			set +e
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherLoop.include" > /dev/null 2>&1
			"$@"
		' rig "$@" 2> /dev/null )"
	fnRc=$?
	printf '%s:%s' "$( [ "$fnRc" = 0 ] && printf yes || printf no )" "$fnOut"
}
rigItem(){ ## state, name, extra frontmatter lines, age: old|new
	printf -- '---\ntype: task\nowner: rig\n%s---\n\nrig item\n' "$3" > "$rigData/board/$1/$2.md"
	[ "${4:-new}" != old ] || touch -t 202610010000 "$rigData/board/$1/$2.md"
}
rigDemand(){ rigFn AgentsToolsScheduleDemand "$1" ; }

echo "-- 1. the inbox --"
printf -- '---\ntype: note\nstate: work-duty-finished\n---\n' > "$rigNote"
touch -t 202610010000 "$rigNote"
rigAssert "a standing state-and-lock note in the coordinator's incoming/ is no work" "$( rigDemand magic-coordinator )" "no:"
printf -- '---\ntype: note\nowner: magic-coordinator\n---\n' > "$rigData/inboxes/magic-coordinator/incoming/note-20261020T0900Z-rig-work.md"
rigAssert "an item that is none is" "$( rigDemand magic-coordinator )" "yes:"
rm -f "$rigData/inboxes/magic-coordinator/incoming/note-20261020T0900Z-rig-work.md"
printf -- '---\ntype: note\nowner: keeper-rig\n---\n' > "$rigData/inboxes/keeper-rig/incoming/note-20261020T0900Z-rig-work.md"
rigAssert "a keeper's inbox item is its work" "$( rigDemand keeper-rig )" "yes:"

echo "-- 2. the board, for the coordinator --"
rigItem running task-rig-old '' old
rigAssert "an item older than the end of the last duty is no news" "$( rigDemand magic-coordinator )" "no:"
sleep 1
rigItem running task-rig-new ''
rigAssert "an item of an active state written since is news" "$( rigDemand magic-coordinator )" "yes:"
touch "$rigNote"
rigAssert "...until a duty ends again (its lock note is written)" "$( rigDemand magic-coordinator )" "no:"
sleep 1
rigItem running dispatch-20261020T0900Z-rig ''
rigAssert "a dispatch-* tracking item of the spawner is no news" "$( rigDemand magic-coordinator )" "no:"
rigItem backlog task-rig-backlog ''
rigItem processed task-rig-processed ''
rigAssert "nor is an item of backlog or processed" "$( rigDemand magic-coordinator )" "no:"
rm -f "$rigData/board/running/task-rig-new.md" "$rigData/board/running"/dispatch-*.md "$rigData/board/backlog/task-rig-backlog.md" "$rigData/board/processed/task-rig-processed.md"
rigItem parked task-rig-due $'recheck-date: 2026-10-10 00:00 +0000\n' old
touch -t 202610050000 "$rigNote"
rigAssert "a recheck-date that fell due since the last duty ended is news" "$( rigDemand magic-coordinator )" "yes:"
touch -t 202610150000 "$rigNote"
rigAssert "one that fell due before it is not" "$( rigDemand magic-coordinator )" "no:"
rigItem blocked task-rig-ahead $'recheck-date: 2099-01-01 00:00 +0000\n' old
rigAssert "one that is still ahead is not" "$( rigDemand magic-coordinator )" "no:"
rm -f "$rigNote"
rigAssert "with no lock note, any item of an active state is news" "$( rigDemand magic-coordinator )" "yes:"
rigAssert "a keeper has no demand of the board" "$( rm -f "$rigData/inboxes/keeper-rig/incoming"/* ; rigDemand keeper-rig )" "no:"

echo "-- 3. the routine of a duty --"
printf -- '---\ntype: routine\n---\n' > "$rigTmp/skills/keeper-rig/keeper-rig.work-duty.routine.md"
rigAssert "a member whose skill folder holds its own: that one" "$( rigFn AgentsToolsScheduleDutyRoutine keeper-rig "$rigTmp/skills/keeper-rig" )" "yes:keeper-rig.work-duty.routine.md"
rigAssert "a member whose folder holds none: the team's" "$( rigFn AgentsToolsScheduleDutyRoutine keeper-other "$rigTmp/skills/keeper-other" )" "yes:magic-team.work-duty.routine.md"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DUTY DEMAND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DUTY_DEMAND: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
