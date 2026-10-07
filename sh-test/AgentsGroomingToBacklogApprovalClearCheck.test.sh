#!/usr/bin/env bash
## Behavioural check on --magic-grooming-to-backlog clearing the item's approval by itself:
## an item moved back to backlog arrives without approved-by/approved-at (check-backlog-promote
## re-earns them), an item carrying none moves cleanly, and a caller's own approved-by or
## approved-at header in the call stands untouched. Offline: plain board-file moves in a
## temp data root.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
rigTmp="$( mktemp -d -t AgentsGroomingToBacklogApprovalClearCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
mkdir -p "$rigTmp/ws" "$rigData/board/parked" "$rigData/board/pending"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
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
rigCount(){ ## item filename in backlog, header name -- how many frontmatter lines start with it
	LC_ALL=C grep -c "^$2:" "$rigData/board/backlog/$1" 2>/dev/null || :
}
rigItem(){ ## state, item filename, extra frontmatter lines
	printf -- '---\ntype: task\nowner: rig\n%s---\n\nrig item\n' "$3" > "$rigData/board/$1/$2"
}

echo "-- an approved item returns to backlog: its approval is cleared --"
rigItem pending task-rig-approved.md $'approved-by: human-owner\napproved-at: 2026-09-29 10:00 +0000\n'
rigOp "$rigTmp/o1" --magic-grooming-to-backlog magic-coordinator task-rig-approved.md --from-state:pending --owner-header-value rig
rigAssert "the move succeeds"                   "$( cat "$rigTmp/o1.rc" )" 0
rigAssert "the item sits in board/backlog"      "$( [ -f "$rigData/board/backlog/task-rig-approved.md" ] && echo yes || echo no )" yes
rigAssert "approved-by is gone"                 "$( rigCount task-rig-approved.md approved-by )" 0
rigAssert "approved-at is gone"                 "$( rigCount task-rig-approved.md approved-at )" 0
rigAssert "control: groomed-from is stamped"    "$( rigCount task-rig-approved.md groomed-from )" 1

echo "-- an item with no approval moves cleanly --"
rigItem parked task-rig-plain.md ''
rigOp "$rigTmp/o2" --magic-grooming-to-backlog magic-coordinator task-rig-plain.md --from-state:parked --owner-header-value rig
rigAssert "the move succeeds"                   "$( cat "$rigTmp/o2.rc" )" 0
rigAssert "the item sits in board/backlog"      "$( [ -f "$rigData/board/backlog/task-rig-plain.md" ] && echo yes || echo no )" yes

echo "-- a caller's own approval header stands --"
rigItem parked task-rig-caller.md $'approved-by: human-owner\napproved-at: 2026-09-29 10:00 +0000\n'
rigOp "$rigTmp/o3" --magic-grooming-to-backlog magic-coordinator task-rig-caller.md --from-state:parked --owner-header-value rig \
	'--header:upsert:approved-by:magic-architect (rig-session, 2026-09-29T10:00:00Z)'
rigAssert "the move succeeds"                   "$( cat "$rigTmp/o3.rc" )" 0
rigAssert "the caller's approved-by is kept"    "$( LC_ALL=C grep -c -x -F 'approved-by: magic-architect (rig-session, 2026-09-29T10:00:00Z)' "$rigData/board/backlog/task-rig-caller.md" )" 1
rigAssert "approved-at is untouched"            "$( rigCount task-rig-caller.md approved-at )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ GROOMING TO BACKLOG APPROVAL CLEAR CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'GROOMING_TO_BACKLOG_APPROVAL_CLEAR: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
