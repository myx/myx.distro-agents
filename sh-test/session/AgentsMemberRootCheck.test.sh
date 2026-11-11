#!/usr/bin/env bash
## Behavioural check on the team-data root the schedule's service thread resolves for itself before a pass (S12.19, board task
## 20261106T0859Z; sh-lib/session/AgentsTools.InternSchedule.include, --intern-schedule). A service thread started from an invited
## member's session inherits that member's `MDAT_DATA_ROOT`, and that value names another workspace's store. The rule drops it and
## resolves this workspace's own.
## The member-root half of the same rule (MDAT_SKILLSET_ROOT, `:59-64`) is not here: its proof starts a routine, and a start's
## subshell outlives an `--intern-schedule --one` pass and holds the runner's pipe. Filed with magic-coordinator 2026-11-07.
## Held, run rather than read, against a rig of this check's own and one real `--intern-schedule --one` pass:
##   1. AN INHERITED DATA ROOT IS RESOLVED AGAIN. `MDAT_DATA_ROOT` is inherited as a store of another workspace, holding a board of
##      its own. The pass recomputes the dependencies of THIS workspace's board: its report names this board's one edge and never
##      the other store's item. The pass starts nothing, so this row is about the store alone.
## RED RECIPE, measured on a copy under this check's own scratch on 2026-11-06: delete the data-root resolution at `:65-68` and the
## edge line goes from `1` to `0`, because the pass then reads the inherited store, which has no edge.
## Offline: the pass and a console, curl, ps and date of the rig's own. A guard refuses a workspace outside the rig tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "the tooling is not at $rigFn"
[ -f "$rigPackage/sh-lib/session/AgentsTools.InternSchedule.include" ] || rigRefuse "the schedule's include is not in the package under test"
## The stand-ins this check starts are signalled only while they are still the processes it noted.
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's control-thread fixture is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMemberRootCheck )" || exit 1
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
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" 2> /dev/null ; rigProcSignalWithChildren KILL $rigStarted ; [ -n "${RIG_KEEP_TREE:-}" ] || rigRemoveTree' EXIT
trap 'exit 1' INT TERM
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
. "$rigPackage/sh-test/check-fixtures/rig-schedule-loop.include.sh" || rigRefuse "the schedule rig fixture is missing from the package"
rigScheduleSetup 1
## Monday 2026-10-19 in Etc/GMT-3, 13:00: inside worktime, past every runs-at of this rig.
rigAt 1792404000

## THIS WORKSPACE'S BOARD, at the data root the rule resolves to with no TEAM_DATA_DIRECTORY set. Two items with one edge between them,
## so the report names both rather than only counting them. Their owner is no member of the rig's roster, so the pass starts no
## work-duty either: this check measures the store and nothing else.
rigNearData="$rigWs/.local/agents/team-data-root"
mkdir -p "$rigNearData/board/running" "$rigNearData/board/pending" "$rigNearData/inboxes/magic-coordinator/incoming" || exit 1
printf -- '---\ntype: task\nowner: keeper-boardonly\nblocks: task-20261019T0900Z-near-child\n---\n\n# this board'"'"'s own blocker\n' > "$rigNearData/board/running/task-20261019T0900Z-near-parent.md"
printf -- '---\ntype: task\nowner: keeper-boardonly\n---\n\n# this board'"'"'s own waiting item\n' > "$rigNearData/board/pending/task-20261019T0900Z-near-child.md"
## THE OTHER WORKSPACE'S BOARD, inherited as `MDAT_DATA_ROOT`: one item of its own, no edge, which no report about this workspace may name.
rigFarWs="$rigTmp/loop/far-ws"
rigFarData="$rigFarWs/.local/agents/team-data-root"
mkdir -p "$rigFarData/board/running" "$rigFarData/inboxes/magic-coordinator/incoming" || exit 1
printf -- '---\ntype: task\nowner: keeper-far\n---\n\n# the other board'"'"'s own item\n' > "$rigFarData/board/running/task-20261019T0900Z-far-only.md"

## THE PASS STARTS NOTHING. `holding` is set in the rig's own settings, so the loop starts no routine and no duty. That is not
## a convenience: a start's subshell outlives an `--intern-schedule --one` pass and holds the runner's pipe, and this check is
## about the store alone. The pass's own board step, the dependencies, still runs with the flag set.
printf 'MDAT_SCHEDULE_HOLDING=on\n' >> "$rigWs/.local/.agents/magic-team.agent.env"

## One `--intern-schedule --one` pass, in the rig, with the data root inherited from the other workspace. Every call is one `env -i`,
## and the child refuses a workspace outside the rig: a probe once reached a real workspace without such a guard.
rigOne(){ ## name -- the pass, its output kept as $rigDir/<name>.out and .err
	local oneName="$1" onePid
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig MDAT_SCHEDULE_THREAD=off HOME="$rigDir/home" \
		PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigFarData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigScn" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree: $MDAT_DATA_ROOT" >&2 ; exit 99 ;; esac
			! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-schedule --one
		' ) > "$rigDir/$oneName.out" 2> "$rigDir/$oneName.err" < /dev/null &
	onePid="$!"
	rigProcNote "$onePid"
	rigStarted="$rigStarted $onePid"
	wait "$onePid"
	rigOneRc=$?
}
rigDepReport(){ LC_ALL=C sed -n '1,60p' "$rigWs/.local/agents/board-dependencies.last" 2> /dev/null ; }
rigReportHas(){ printf '%s\n' "$( rigDepReport )" | LC_ALL=C grep -c -F -- "$1" || : ; }

echo "-- 1. an inherited data root is resolved again --"
rigOne pass1
## THE PASS RAN, read from its product and not from its status alone. Its contract answers 2 while a flag that keeps duties is on, which
## worktime is at this hour, and 0 otherwise. But 0 is also what a pass that did nothing answers, so the status proves no work on its own:
## the dependencies report is the product that only a pass which reached its board step writes.
rigAssert "the pass ran: its answer is one its contract gives, and its board step wrote the report" \
	"$( { [ "$rigOneRc" = 0 ] || [ "$rigOneRc" = 2 ] ; } && printf ran || printf other ):$( [ -s "$rigWs/.local/agents/board-dependencies.last" ] && printf report || printf none )" "ran:report"
rigAssert "and it reported no error of its own" "$( LC_ALL=C grep -c -E 'ERROR' "$rigDir/pass1.err" || : )" "0"
rigAssert "its report is written in the workspace's own state folder, whatever store was inherited" \
	"$( [ -s "$rigWs/.local/agents/board-dependencies.last" ] && printf report )" "report"
rigAssert "the report names the one edge of this workspace's own board" \
	"$( rigReportHas '- task-20261019T0900Z-near-child <- task-20261019T0900Z-near-parent' )" "1"
rigAssert "and never the inherited store's item, so the inherited store was not read" \
	"$( rigReportHas 'task-20261019T0900Z-far-only' )" "0"
rigAssert "the inherited store is untouched: its own item is still where the other workspace keeps it, with no finding written beside it" \
	"$( [ -f "$rigFarData/board/running/task-20261019T0900Z-far-only.md" ] && printf kept ) $( [ -s "$rigFarWs/.local/agents/board-dependencies.last" ] && printf written || printf none )" \
	"kept none"

echo
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MEMBER ROOT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
echo "MEMBER_ROOT: OK ($rigPassCount assertions, offline, rig tree only)"
