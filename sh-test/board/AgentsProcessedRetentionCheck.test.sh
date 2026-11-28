#!/usr/bin/env bash
## Behavioural check: a processed item is deleted only when it is past the retention days AND no live item, incoming item or vault item
## names it -- the sketch's "move, then delete the unreferenced". A referenced item of any age is kept. Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
prInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.ProcessedRetention.include"
[ -f "$prInclude" ] || { echo "⛔ ERROR: the retention include is not at the origin" >&2 ; exit 1 ; }
prRoot="$( mktemp -d "${TMPDIR:-/tmp}/AgentsProcessedRetentionCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$prRoot" 2> /dev/null || :' EXIT
mkdir -p "$prRoot/board/processed" "$prRoot/board/pending" "$prRoot/board/running" "$prRoot/board/review" "$prRoot/board/blocked" "$prRoot/board/parked" "$prRoot/inboxes/magic-tester/incoming" "$prRoot/inboxes/magic-tester/processed" "$prRoot/vault"
printf -- '---\ntype: task\n---\n\nreferences task-20261101T0000Z-referenced-old.md\n' > "$prRoot/board/pending/live-item.md"
printf -- '---\ntype: task\n---\n' > "$prRoot/board/processed/task-20261101T0000Z-referenced-old.md"
printf -- '---\ntype: task\n---\n' > "$prRoot/board/processed/task-20261101T0000Z-unreferenced-old.md"
printf -- '---\ntype: task\n---\n' > "$prRoot/board/processed/task-20261125T0000Z-unreferenced-new.md"
printf -- '---\ntype: note\n---\n' > "$prRoot/inboxes/magic-tester/processed/note-20261101T0000Z-unreferenced-old.md"
touch -t 202610010000 "$prRoot/board/processed/task-20261101T0000Z-referenced-old.md" "$prRoot/board/processed/task-20261101T0000Z-unreferenced-old.md" "$prRoot/inboxes/magic-tester/processed/note-20261101T0000Z-unreferenced-old.md"
touch -t 202611250000 "$prRoot/board/processed/task-20261125T0000Z-unreferenced-new.md"
prOut="$( MDAT_DATA_ROOT="$prRoot" MDAT_PROCESSED_RETENTION_DAYS=30 MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "'"$prInclude"'" ; AgentsToolsProcessedRetentionRun' 2> /dev/null )"
prPasses=0 prFails=0
prAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; prPasses=$(( prPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; prFails=$(( prFails + 1 )) ; fi
}
prAssert "the old unreferenced board item is deleted" "$( [ -e "$prRoot/board/processed/task-20261101T0000Z-unreferenced-old.md" ] && echo kept || echo deleted )" "deleted"
prAssert "the old unreferenced inbox item is deleted" "$( [ -e "$prRoot/inboxes/magic-tester/processed/note-20261101T0000Z-unreferenced-old.md" ] && echo kept || echo deleted )" "deleted"
prAssert "the referenced old item is kept" "$( [ -e "$prRoot/board/processed/task-20261101T0000Z-referenced-old.md" ] && echo kept || echo deleted )" "kept"
prAssert "the new unreferenced item is kept" "$( [ -e "$prRoot/board/processed/task-20261125T0000Z-unreferenced-new.md" ] && echo kept || echo deleted )" "kept"
prAssert "one line says what it removed" "$( printf '%s\n' "$prOut" | LC_ALL=C grep -c 'removed 2 unreferenced item' )" "1"
if [ "$prFails" -ne 0 ] ; then
	echo "⛔ PROCESSED RETENTION CHECK FAILED: $prFails of $(( prPasses + prFails )) assertion(s)" >&2 ; exit 1
fi
echo "PROCESSED_RETENTION: OK ($prPasses assertions, offline)"
