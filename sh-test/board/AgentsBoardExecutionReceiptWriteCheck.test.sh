#!/usr/bin/env bash
## Behavioural check: the restart receipt writes `execution-receipt: spawn:<session>:<utc>` onto an item in the state it stands in
## (running or review), refuses a missing item without writing, and refuses a missing session. Offline: its own team-data fixture.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rcInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.ReviewFlow.include"
[ -f "$rcInclude" ] || { echo "⛔ ERROR: the review flow include is not at the origin" >&2 ; exit 1 ; }
rcRoot="$( mktemp -d "${TMPDIR:-/tmp}/AgentsBoardExecutionReceiptWriteCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rcRoot" 2> /dev/null || :' EXIT
mkdir -p "$rcRoot/.local/agents/team-data-root/board/running" "$rcRoot/.local/agents/team-data-root/board/review"
rcData="$rcRoot/.local/agents/team-data-root"
printf -- '---\ntype: task\nowner: keeper-myx\ndocument-contract: board-item.task\ndate: 2026-11-27 01:45 +0200\napproved-by: human-owner (cad2c625-5d9b-4771-9d59-453380a4ffe0, 2026-11-26T12:36:32Z)\napproved-at: 2026-11-26 14:36 +0200\n---\n\n# Task: in running\n' > "$rcData/board/running/task-20261126T125830Z-running-fixture.md"
printf -- '---\ntype: task\nowner: keeper-myx\ndocument-contract: board-item.task\ndate: 2026-11-27 01:40 +0200\n---\n\n# Task: in review\n' > "$rcData/board/review/task-20261127T0140Z-review-fixture.md"
rcOut="$( MMDAPP="$rcRoot" MDAT_DATA_ROOT="$rcData" MDAT_WORKSPACE_MODE=team-rig MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
	. "'"$rcInclude"'" 2> /dev/null
	AgentsToolsBoardExecutionReceiptWrite task-20261126T125830Z-running-fixture.md 01234567-89ab-cdef-0123-456789abcdef 2026-11-27T01:40:00Z ; printf "running=%s\n" "$?"
	AgentsToolsBoardExecutionReceiptWrite task-20261127T0140Z-review-fixture.md 01234567-89ab-cdef-0123-456789abcdef 2026-11-27T01:40:00Z ; printf "review=%s\n" "$?"
	AgentsToolsBoardExecutionReceiptWrite task-20261127T0140Z-not-there.md 01234567-89ab-cdef-0123-456789abcdef ; printf "missing=%s\n" "$?"
	AgentsToolsBoardExecutionReceiptWrite task-20261127T0140Z-review-fixture.md "" ; printf "nosession=%s\n" "$?"
' 2> /dev/null )"
rcPasses=0 rcFails=0
rcAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rcPasses=$(( rcPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rcFails=$(( rcFails + 1 )) ; fi
}
rcAssert "the running item takes the receipt" "$( grep -c '^execution-receipt: spawn:01234567-89ab-cdef-0123-456789abcdef:2026-11-27T01:40:00Z$' "$rcData/board/running/task-20261126T125830Z-running-fixture.md" )" "1"
rcAssert "the review item takes the receipt" "$( grep -c '^execution-receipt: spawn:01234567-89ab-cdef-0123-456789abcdef:2026-11-27T01:40:00Z$' "$rcData/board/review/task-20261127T0140Z-review-fixture.md" )" "1"
rcAssert "a missing item is refused" "$( printf '%s\n' "$rcOut" | LC_ALL=C grep -c '^missing=1' )" "1"
rcAssert "a missing session is refused" "$( printf '%s\n' "$rcOut" | LC_ALL=C grep -c '^nosession=2' )" "1"
rcAssert "the running call answered 0" "$( printf '%s\n' "$rcOut" | LC_ALL=C grep -c '^running=0' )" "1"
if [ "$rcFails" -ne 0 ] ; then
	echo "⛔ BOARD EXECUTION RECEIPT WRITE CHECK FAILED: $rcFails of $(( rcPasses + rcFails )) assertion(s)" >&2 ; exit 1
fi
echo "BOARD_EXECUTION_RECEIPT_WRITE: OK ($rcPasses assertions, offline)"
