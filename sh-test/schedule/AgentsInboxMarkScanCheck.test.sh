#!/usr/bin/env bash
## Behavioural check on AgentsInboxMarkScan.awk: one pass over many inbox files answers `<file>\t<mark>` exactly as one awk a file
## did, so the schedule's important-and-emergency step reads the whole incoming in one process. Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
scanAwk="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/inbox/AgentsInboxMarkScan.awk"
oneAwk="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsBoardItemFrontmatterPrint.awk"
[ -f "$scanAwk" ] && [ -f "$oneAwk" ] || { echo "⛔ ERROR: the awk scripts are not at the origin" >&2 ; exit 1 ; }
scanTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsInboxMarkScanCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$scanTmp"' EXIT
printf -- '---\nmark: important\ntype: note\n---\nbody\n' > "$scanTmp/note-a.md"
printf -- '---\nmark: emergency\n---\n' > "$scanTmp/note-b.md"
printf -- '---\ntype: note\n---\n' > "$scanTmp/note-c.md"
printf -- '---\nmark: urgent\n' > "$scanTmp/note-d-no-close.md"
scanPasses=0 scanFails=0
scanAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; scanPasses=$(( scanPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; scanFails=$(( scanFails + 1 )) ; fi
}
scanBatch="$( LC_ALL=C awk -f "$scanAwk" "$scanTmp"/*.md 2> /dev/null )"
scanOne=""
for f in "$scanTmp"/*.md ; do
	m="$( LC_ALL=C awk -f "$oneAwk" "$f" 2> /dev/null | LC_ALL=C sed -n 's/^mark: //p' | LC_ALL=C tail -n 1 )"
	[ -z "$m" ] || scanOne="$scanOne$f	$m
"
done
scanMismatch=0
for f in "$scanTmp"/*.md ; do
	batchMark="$( printf '%s\n' "$scanBatch" | LC_ALL=C awk -F'\t' -v want="$f" '$1 == want { print $2 }' )"
	oneMark="$( printf '%s' "$scanOne" | LC_ALL=C awk -F'\t' -v want="$f" '$1 == want { print $2 }' )"
	[ "$batchMark" = "$oneMark" ] || scanMismatch=$(( scanMismatch + 1 ))
done
scanAssert "the one pass answers each file exactly as one awk a file answered" "$scanMismatch" "0"
scanAssert "a file with no mark answers nothing" "$( printf '%s\n' "$scanBatch" | LC_ALL=C grep -c 'note-c.md' )" "0"
scanAssert "three marked files are found, a malformed last line included" "$( printf '%s\n' "$scanBatch" | LC_ALL=C grep -c 'mark:' )" "0"
scanAssert "the marked count is three" "$( printf '%s\n' "$scanBatch" | LC_ALL=C grep -c $'\t' )" "3"
if [ "$scanFails" -ne 0 ] ; then
	echo "⛔ INBOX MARK SCAN CHECK FAILED: $scanFails of $(( scanPasses + scanFails )) assertion(s)" >&2 ; exit 1
fi
echo "INBOX_MARK_SCAN: OK ($scanPasses assertions, offline)"
