#!/usr/bin/env bash
## Behavioural check: a running item whose execution-receipt names a session that has handed back gets `handback-given`; one whose
## session has not, and one with no receipt, are untouched. Informational only: no state move. Offline, its own fixture.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
hsInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.HandbackStamp.include"
[ -f "$hsInclude" ] || { echo "⛔ ERROR: the stamp include is not at the origin" >&2 ; exit 1 ; }
hsRoot="$( mktemp -d "${TMPDIR:-/tmp}/AgentsHandbackStampCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$hsRoot" 2> /dev/null || :' EXIT
hsData="$hsRoot/.local/agents/team-data-root"
mkdir -p "$hsData/board/running" "$hsRoot/.local/agents/spawned/11111111-1111-4111-8111-111111111111" "$hsRoot/.local/agents/spawned/22222222-2222-4222-8222-222222222222"
: > "$hsRoot/.local/agents/spawned/11111111-1111-4111-8111-111111111111/handback.given"
hsItem(){ ## file, session-or-empty
	local hsF="$1" hsS="${2:-}"
	printf -- '---\ntype: task\nowner: keeper-myx\ndocument-contract: board-item.task\ndate: 2026-11-27 02:00 +0200\napproved-by: human-owner (cad2c625-5d9b-4771-9d59-453380a4ffe0, 2026-11-26T12:36:32Z)\napproved-at: 2026-11-26 14:36 +0200\nstatus: dispatch-started\n' > "$hsF"
	[ -z "$hsS" ] || printf 'execution-receipt: spawn:%s:2026-11-26T18:00:00Z\n' "$hsS" >> "$hsF"
	printf -- '---\n\n# Task: fixture\n' >> "$hsF"
}
hsItem "$hsData/board/running/task-20261127T0200Z-handed-back.md" 11111111-1111-4111-8111-111111111111
hsItem "$hsData/board/running/task-20261127T0200Z-still-running.md" 22222222-2222-4222-8222-222222222222
hsItem "$hsData/board/running/task-20261127T0201Z-no-receipt.md"
hsOut="$( MMDAPP="$hsRoot" MDAT_DATA_ROOT="$hsData" MDAT_WORKSPACE_MODE=team-rig MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "'"$hsInclude"'" ; AgentsToolsHandbackStampRun' 2> /dev/null )"
hsPasses=0 hsFails=0
hsAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; hsPasses=$(( hsPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; hsFails=$(( hsFails + 1 )) ; fi
}
hsAssert "the handed-back item is marked" "$( grep -c '^handback-given: ' "$hsData/board/running/task-20261127T0200Z-handed-back.md" )" "1"
hsAssert "the still-running item is not marked" "$( grep -c '^handback-given: ' "$hsData/board/running/task-20261127T0200Z-still-running.md" || true )" "0"
hsAssert "the item with no receipt is not marked" "$( grep -c '^handback-given: ' "$hsData/board/running/task-20261127T0201Z-no-receipt.md" || true )" "0"
hsAssert "one line says one marked" "$( printf '%s\n' "$hsOut" | LC_ALL=C grep -c '1 item(s) marked handed back, 0 refused' )" "1"
hsAssert "the item stays running" "$( [ -f "$hsData/board/running/task-20261127T0200Z-handed-back.md" ] && echo running || echo moved )" "running"
if [ "$hsFails" -ne 0 ] ; then
	echo "⛔ HANDBACK STAMP CHECK FAILED: $hsFails of $(( hsPasses + hsFails )) assertion(s)" >&2 ; exit 1
fi
echo "HANDBACK_STAMP: OK ($hsPasses assertions, offline)"
