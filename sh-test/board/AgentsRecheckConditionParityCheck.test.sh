#!/usr/bin/env bash
## Parity check of the one recheck test (AgentsToolsRecheckConditionUnmet, AgentsTools.RecheckDate.include): one table of `condition:` values, each on
## an approved pending task with a recheck-date not yet due, put through the test itself and through every reader and writer of it. The start pass, the
## supervise scan and the due scan hold the item exactly where the test calls the condition unmet; both writers into board-pending, the board move
## and the item upsert, keep a date the call sets exactly there, and refuse it everywhere else. One verdict a column: `holds` or `free`. The rows are
## old data, put by the fixture's legacy route, since no writer leaves such a date. Offline: a rig data root, nothing spawned, nothing moved out of it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/schedule/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's functions are not at the origin this workspace resolves: $rigHere"
rigFn="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRecheckConditionParityCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigWs="$rigTmp/ws" rigData="$rigTmp/data"
mkdir -p "$rigWs/.local"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills" rigOwnerOrigin="$MDLT_ORIGIN"
rigOwnerBoardReady

## The table, `<want>|<condition>`: `holds` where a date beside the condition holds, `free` where it holds nothing. An empty condition is none at all.
rigTable='free|
free|met: 2026-11-18 07:20 +0200: the answer arrived
free|none: the item waits for nothing
free|Met: the answer arrived
free|NONE.
free|   met: behind leading spaces
free|met
holds|unmet: conflicts with task-rig-running
holds|metrics are read again
holds|nonexistent: a gate
holds|Unblocked at grooming: nothing else gates it'
rigRow=0
while IFS='|' read -r rigWant rigCondition ; do
	rigRow=$(( rigRow + 1 ))
	{ printf '%s\n' '---' 'type: task' 'owner: rig' 'approved-by: human-owner (rig-session, 2026-01-01T00:00:00Z)' 'approved-at: 2026-01-01 00:00 +0000' \
		'handler-routine: magic-team.epic-build.routine.md'
	  [ -z "$rigCondition" ] || printf 'condition: %s\n' "$rigCondition"
	  printf '%s\n' 'recheck-date: 2099-01-01 00:00 +0000' '---' '' '# a parity row' ; } | rigOwnerBoardLegacyPut "$( printf 'task-20260101T00%02dZ-parity.md' "$rigRow" )"
done <<< "$rigTable"

## The readers first, since none of them writes. The start pass's own filter, its routine lookup stubbed to log the item and stop.
rigLog="$rigTmp/start.log"
: > "$rigLog"
env MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDSC_CMD=check RIG_LOG="$rigLog" RIG_HERE="$rigHere" bash -c '
	. "$RIG_HERE/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
	. "$RIG_HERE/board/AgentsTools.BoardItemHandler.include" > /dev/null 2>&1
	type AgentsToolsScheduleStartPending > /dev/null 2>&1 || exit 3
	AgentsToolsScheduleCurrentFlags(){ printf "worktime: yes\novertime: no\nemergency: no\n" ; }
	AgentsToolsSchedulePaceText(){ printf "pace: a duty start is allowed\n" ; }
	AgentsToolsBoardItemHandler(){ printf "%s\n" "${1##*/}" >> "$RIG_LOG" ; return 1 ; }
	AgentsToolsScheduleSpawn(){ return 1 ; }
	AgentsToolsScheduleStartPending > /dev/null 2>&1
' || rigRefuse "the start pass could not be run"
## The supervise scan, its store root and vault answered from the rig.
rigSupervised="$(
	set +u
	. "$rigHere/supervise/AgentsTools.SuperviseBoard.include" || exit 3
	AgentsToolsTeamDataRootOf(){ printf '%s\n' "$rigData" ; }
	AgentsToolsVaultFolderInto(){ printf -v "$1" '%s' "$rigTmp/no-vault" ; }
	AgentsToolsVaultFilesInto(){ eval "$1=()" ; }
	MMDAPP="$rigWs" AgentsToolsSuperviseBoard "$rigWs" 2> /dev/null
)" || rigRefuse "the supervise scan could not be run"
## The due scan, over every row at once.
rigDue="$(
	set +u
	. "$rigHere/board/AgentsTools.BoardStates.include" > /dev/null 2>&1 || exit 3
	MDAT_DATA_ROOT="$rigData" AgentsToolsBoardItemDue "$rigData/board/pending"/task-*-parity.md
	[ $? -ne 2 ] || exit 2
)" || rigRefuse "the due scan could not be run"
## The test itself.
set +u
. "$rigHere/board/AgentsTools.RecheckDate.include"
set -u

rigRow=0
while IFS='|' read -r rigWant rigCondition ; do
	rigRow=$(( rigRow + 1 ))
	rigName="$( printf 'task-20260101T00%02dZ-parity' "$rigRow" )"
	if ! type AgentsToolsRecheckConditionUnmet > /dev/null 2>&1 ; then rigTest=missing
	elif AgentsToolsRecheckConditionUnmet "$rigCondition" ; then rigTest=holds ; else rigTest=free ; fi
	if LC_ALL=C grep -q -x -F -- "$rigName.md" "$rigLog" ; then rigStart=free ; else rigStart=holds ; fi
	if printf '%s\n' "$rigSupervised" | LC_ALL=C grep -q -F -- "pending-skipped ws $rigName recheck=" ; then rigSupervise=holds ; else rigSupervise=free ; fi
	case "$( printf '%s\n' "$rigDue" | LC_ALL=C awk -F "$( printf '\034' )" -v rowName="/$rigName.md" 'substr( $1, length( $1 ) - length( rowName ) + 1 ) == rowName { print $3 ; exit ; }' )" in
		recheck-date-ahead) rigDueWord=holds ;;
		due) rigDueWord=free ;;
		*) rigDueWord=unread ;;
	esac
	## The writer last: a date the call sets is kept (rc 0) where it holds, and refused (rc 1) where it does not.
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash -c 'cd "$MMDAPP" && exec bash "$0" "$@"' "$rigFn" \
		--move-to-pending --team-member magic-coordinator "$rigName.md" --from-state:pending --recheck-in 600 > "$rigTmp/$rigName.write" 2>&1
	case "$?" in 0) rigWrite=holds ;; 1) rigWrite=free ;; *) rigWrite=failed ;; esac
	## The item upsert last, through the fixture's own call of it: the same verdict, rc 0 or rc 1.
	if rigOwnerItemsCall "AgentsToolsItemUpsert \"\$MDAT_SPAWN_AGENT\" --from-board pending '$rigName.md' '--header:upsert:recheck-date:2099-01-02 00:00 +0000' --context rig" "upsert $rigName" 2> /dev/null ; then rigUpsert=holds ; else rigUpsert=free ; fi
	rigAssert "row $rigRow '$rigCondition': test start supervise due move upsert" \
		"$rigTest $rigStart $rigSupervise $rigDueWord $rigWrite $rigUpsert" "$rigWant $rigWant $rigWant $rigWant $rigWant $rigWant"
done <<< "$rigTable"
rigAssert "control: the table carries both verdicts" "$( printf '%s\n' "$rigTable" | LC_ALL=C cut -d '|' -f 1 | LC_ALL=C sort -u | tr '\n' ' ' )" "free holds "

if [ "$rigFails" -ne 0 ] ; then echo "⛔ RECHECK CONDITION PARITY CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "RECHECK_CONDITION_PARITY: OK ($rigPasses assertions, offline)"
