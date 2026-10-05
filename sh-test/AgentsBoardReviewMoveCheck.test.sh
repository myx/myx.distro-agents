#!/usr/bin/env bash
## Behavioural check on board-review's own move legs. Entry into review carries no new
## operation: it goes through the existing --intern-op-board-upsert-move-edit move
## primitive, running -> review, with the review-by header set. The spawn proxy's own
## close path into review is covered separately by AgentsSpawnProxyCloseCommitCheck.test.sh
## (not duplicated here). Review is also a valid --from-state on that same primitive, for
## both directions a reviewer's own decision takes: reject (review -> running) and accept,
## via the existing --magic-board-to-processed (review -> processed). No console, no git,
## no Slack: these are plain board-file moves.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
rigTmp="$( mktemp -d -t AgentsBoardReviewMoveCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
mkdir -p "$rigTmp/ws" "$rigData/board/running"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One team op, guarded, against this rig's own temp data root; rc into <result>.rc.
rigOp(){ ## result file, extra DistroAgentsTools.fn.sh arguments...
	local opOut="$1" ; shift
	env -i HOME="$rigTmp" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}
rigLoc(){ ## item filename -- which board/<state>/ actually holds it, or not-found
	local stateDir
	for stateDir in "$rigData"/board/*/ ; do
		[ -f "$stateDir$1" ] && { basename "$stateDir" ; return 0 ; }
	done
	printf 'not-found'
}

echo "-- entry: running -> review, via the move primitive directly, review-by set --"
mkdir -p "$rigData/board/review"
printf -- '---\ntype: task\nowner: rig\n---\n\nrig item\n' > "$rigData/board/running/task-rig-entry.md"
rigOp "$rigTmp/o1" --intern-op-board-upsert-move-edit review task-rig-entry.md --from-state:running \
	--header:upsert:review-by:magic-tester --context rig
rigAssert "the move succeeds"                          "$( cat "$rigTmp/o1.rc" )" 0
rigAssert "the item now sits in board/review"          "$( rigLoc task-rig-entry.md )" review
rigAssert "review-by is set on the moved item"         "$( LC_ALL=C grep -c -x -F 'review-by: magic-tester' "$rigData/board/review/task-rig-entry.md" )" 1
echo "-- the spawn proxy's own close path into review is covered by AgentsSpawnProxyCloseCommitCheck.test.sh, not duplicated here --"

echo "-- reject: review -> running, review as an existing op's --from-state --"
mkdir -p "$rigData/board/review"
printf -- '---\ntype: task\nowner: rig\n---\n\nrig item\n' > "$rigData/board/review/task-rig-reject.md"
printf -- '---\ntype: task\nowner: rig\n---\n\nrig item, reviewer comments appended\n' \
	| rigOp "$rigTmp/o2" --intern-op-board-upsert-move-edit running task-rig-reject.md --from-state:review --upsert-from-stdin --context rig
rigAssert "the move succeeds"                          "$( cat "$rigTmp/o2.rc" )" 0
rigAssert "the item lands back in board/running"       "$( rigLoc task-rig-reject.md )" running

echo "-- accept: review -> processed, via the existing --magic-board-to-processed --"
printf -- '---\ntype: task\nowner: rig\n---\n\nrig item\n' > "$rigData/board/review/task-rig-accept.md"
rigOp "$rigTmp/o3" --magic-board-to-processed magic-tester task-rig-accept.md --from-state:review
rigAssert "the move succeeds"                          "$( cat "$rigTmp/o3.rc" )" 0
rigAssert "the item lands in board/processed"          "$( rigLoc task-rig-accept.md )" processed

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD REVIEW MOVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_REVIEW_MOVE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
