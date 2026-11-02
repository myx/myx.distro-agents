#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the batch outcome's two fields having ONE writer (S26 item 4):
## `--advance-batch-outcome` records `outcome` and `execution-receipt` on a running board
## item, and a second write of a DIFFERENT value is refused rather than overwriting what
## the first round decided. (AgentsTools.MagicAdvance.include, --advance-batch-outcome)
##   1. THE FIRST WRITE lands both fields, and the op exits 0.
##   2. A SECOND write of a different outcome is refused: non-zero, and the item still
##      carries the first outcome and the first receipt.
##   3. A SECOND write of the SAME values is no conflict: exit 0, and the fields still say it.
## Offline: a rig data root of this check's own, and no git.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAdvanceOutcomeOneWriterCheck )" || exit 1
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
## One batch outcome, against this rig's own data root: the op's output to <result>, its status to <result>.rc.
## The op is magic-coordinator's only, so the rig's call acts as that member.
rigOutcome(){ ## result file, item filename, outcome, receipt
	local opOut="$1"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin" GIT_CONFIG_NOSYSTEM=1 MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID=rig-session RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --advance-batch-outcome magic-coordinator --items:"$1"
		' rig "$2:$3:$4" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}
rigField(){ ## item filename, field
	LC_ALL=C awk -v want="$2" 'index($0, want ": ") == 1 { print substr($0, length(want) + 3) ; exit }' "$rigData/board/running/$1"
}

printf -- '---\ntype: task\nowner: teammate\nstatus: running\n---\n\nrig item\n' > "$rigData/board/running/task-rig-outcome.md"

echo "-- 1. the first write --"
rigOutcome "$rigTmp/o1" task-rig-outcome.md nudged "round one - 2 items"
rigAssert "the batch outcome succeeds" "$( cat "$rigTmp/o1.rc" )" 0
rigAssert "the item carries the outcome" "$( rigField task-rig-outcome.md outcome )" "nudged"
rigAssert "the item carries the receipt" "$( rigField task-rig-outcome.md execution-receipt )" "round one - 2 items"

echo "-- 2. a second write of a different value is refused --"
rigOutcome "$rigTmp/o2" task-rig-outcome.md respawned "round two - 1 item"
rigAssert "the second write is refused" "$( [ "$( cat "$rigTmp/o2.rc" )" != 0 ] && printf refused || printf allowed )" "refused"
rigAssert "and it says so" "$( [ "$( LC_ALL=C grep -c -e 'ERROR' -e 'refus' "$rigTmp/o2" )" -ge 1 ] && printf said || printf silent )" "said"
rigAssert "the outcome still says what the first write decided" "$( rigField task-rig-outcome.md outcome )" "nudged"
rigAssert "and so does the receipt" "$( rigField task-rig-outcome.md execution-receipt )" "round one - 2 items"

echo "-- 3. a second write of the same values is no conflict --"
rigOutcome "$rigTmp/o3" task-rig-outcome.md nudged "round one - 2 items"
rigAssert "the same values are accepted" "$( cat "$rigTmp/o3.rc" )" 0
rigAssert "and the fields still say it" "$( rigField task-rig-outcome.md outcome ):$( rigField task-rig-outcome.md execution-receipt )" "nudged:round one - 2 items"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'ADVANCE_OUTCOME_ONE_WRITER: OK\n'
