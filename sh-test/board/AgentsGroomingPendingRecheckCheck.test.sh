#!/usr/bin/env bash
## Behavioural check on grooming's writes into board-pending (`--grooming-to-pending`, `--grooming-create-pending`): a recheck-date re-checks an unmet
## `condition:`. A date the item carries beside a condition that reads `met` or `none`, or beside none, is dropped with a warning. A date the call itself
## sets there (`--recheck-in`, a `recheck-date` header) is refused, rc 1, and nothing is written. An unmet condition, a `metrics …` prefix included,
## keeps the date the call sets, on a move and on a create alike. Offline: plain board-file writes in a temp data root.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsGroomingPendingRecheckCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
mkdir -p "$rigTmp/ws"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigOp(){ ## result file, DistroAgentsTools.fn.sh arguments...
	local opOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}
rigItem(){ ## state, item filename, extra frontmatter lines
	rigOwnerBoardWrite $1 "$2" -- '---\ntype: task\nowner: rig\napproved-by: human-owner\n%s---\n\nrig item\n' "$3"
}
rigHeld(){ ## item filename in pending -- the call's status, then how many recheck-date and condition lines the item carries
	printf '%s:%s:%s' "$( cat "$rigTmp/$1.out.rc" )" \
		"$( LC_ALL=C grep -c '^recheck-date:' "$rigData/board/pending/$1" 2> /dev/null || : )" \
		"$( LC_ALL=C grep -c '^condition:' "$rigData/board/pending/$1" 2> /dev/null || : )"
}
rigSaid(){ ## item filename, text -- how many lines of the call's output carry it
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" || :
}

echo "-- a date the item carries, beside no unmet condition: dropped, with its warning --"
rigItem blocked task-rig-met.md $'condition: met 2026-11-18 07:20 +0200: the answer arrived\nrecheck-date: 2099-01-01 00:00 +0000\n'
rigOp "$rigTmp/task-rig-met.md.out" --grooming-to-pending --team-member magic-coordinator task-rig-met.md --from-state:blocked --owner-header-value rig
rigAssert "unblocked with a met condition: moved, no recheck-date, the condition kept" "$( rigHeld task-rig-met.md )" "0:0:1"
rigAssert "the write says why it kept no recheck-date" "$( rigSaid task-rig-met.md 'recheck-date not kept' )" 1

echo "-- a date the call sets, beside no unmet condition: refused, nothing written --"
rigItem pending task-rig-none.md ''
rigOp "$rigTmp/task-rig-none.md.out" --grooming-to-pending --team-member magic-coordinator task-rig-none.md --from-state:pending --owner-header-value rig --recheck-in 600
rigAssert "no condition and --recheck-in: refused, the item unchanged" "$( rigHeld task-rig-none.md )" "1:0:0"
rigAssert "the refusal says why" "$( rigSaid task-rig-none.md 'a recheck-date on a pending item re-checks an unmet condition' )" 1
rigItem pending task-rig-word.md $'condition: none. Ready to start\n'
rigOp "$rigTmp/task-rig-word.md.out" --grooming-to-pending --team-member magic-coordinator task-rig-word.md --from-state:pending --owner-header-value rig \
	'--header:upsert:recheck-date:2099-01-01 00:00 +0000'
rigAssert "a condition that reads none, and a recheck-date header in the call: refused" "$( rigHeld task-rig-word.md )" "1:0:1"
rigOp "$rigTmp/task-20260101T0007Z-rig-create.md.out" --grooming-create-pending --team-member magic-coordinator task-20260101T0007Z-rig-create.md --owner-header-value rig \
	--upsert-body:"$( printf -- '---\ntype: task\nowner: rig\napproved-by: human-owner (rig-session, 2026-01-01T00:00:00Z)\napproved-at: 2026-01-01 00:00 +0000\n---\n\nrig item\n' )" --recheck-in 600
rigAssert "a create into pending with no condition and --recheck-in: refused, nothing created" \
	"$( cat "$rigTmp/task-20260101T0007Z-rig-create.md.out.rc" ):$( [ -f "$rigData/board/pending/task-20260101T0007Z-rig-create.md" ] && echo present || echo absent )" "1:absent"

echo "-- a date the call sets beside an unmet condition: kept --"
rigItem pending task-rig-unmet.md $'condition: the rig waits for an answer\n'
rigOp "$rigTmp/task-rig-unmet.md.out" --grooming-to-pending --team-member magic-coordinator task-rig-unmet.md --from-state:pending --owner-header-value rig --recheck-in 600
rigAssert "control: a condition that stands keeps the recheck-date the call asked for" "$( rigHeld task-rig-unmet.md )" "0:1:1"
rigItem pending task-rig-form.md $'condition: unmet: the rig waits for an answer\n'
rigOp "$rigTmp/task-rig-form.md.out" --grooming-to-pending --team-member magic-coordinator task-rig-form.md --from-state:pending --owner-header-value rig --recheck-in 600
rigAssert "the unmet: form keeps it" "$( rigHeld task-rig-form.md )" "0:1:1"
rigItem pending task-rig-metrics.md $'condition: metrics are read again\n'
rigOp "$rigTmp/task-rig-metrics.md.out" --grooming-to-pending --team-member magic-coordinator task-rig-metrics.md --from-state:pending --owner-header-value rig --recheck-in 600
rigAssert "a metrics prefix is unmet, and keeps it" "$( rigHeld task-rig-metrics.md )" "0:1:1"
rigOp "$rigTmp/task-20260101T0008Z-rig-create.md.out" --grooming-create-pending --team-member magic-coordinator task-20260101T0008Z-rig-create.md --owner-header-value rig \
	--upsert-body:"$( printf -- '---\ntype: task\nowner: rig\napproved-by: human-owner (rig-session, 2026-01-01T00:00:00Z)\napproved-at: 2026-01-01 00:00 +0000\ncondition: unmet: the rig waits\n---\n\nrig item\n' )" --recheck-in 600
rigAssert "a create into pending with an unmet condition keeps the date it sets" "$( rigHeld task-20260101T0008Z-rig-create.md )" "0:1:1"

if [ "$rigFails" -ne 0 ] ; then echo "⛔ GROOMING PENDING RECHECK CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "GROOMING_PENDING_RECHECK: OK ($rigPasses assertions, offline, rig tree only)"
