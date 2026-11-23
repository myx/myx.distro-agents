#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## AgentsBoardStatusKeyMigration.sh -- the one-shot removal of the `status` key from the board
## items that carry it (S16 stage 2 item 6). Run once, by its own approval, naming the board it
## is given and the state folders it walks.
##
## A dry read is the default and prints what would change. `--apply` writes; each item is
## rewritten to `<item>.tmp.$$` and renamed onto `<item>`, so a half-written item is never
## read as one. The key is the frontmatter line `status: ` and nothing else: a `status: ` line
## inside an item's body is a different thing and is left alone.
##
## Usage: AgentsBoardStatusKeyMigration.sh <board root> [--apply]
##   Prints `read <n>`, `carrying <n>`, `removed <n>`, `left <n>`, one a line. `left` is the
##   count read back after the write, through a second read of the same files.
set -u
rigBoard="${1:-}"
rigApply=""
case "${2:-}" in --apply) rigApply=yes ;; esac
[ -n "$rigBoard" ] || { echo "⛔ ERROR: AgentsBoardStatusKeyMigration.sh: syntax is <board root> [--apply]" >&2 ; exit 1 ; }
[ -d "$rigBoard" ] || { echo "⛔ ERROR: AgentsBoardStatusKeyMigration.sh: no board at $rigBoard" >&2 ; exit 1 ; }

## One item's frontmatter `status: ` line count, and whether it has one at all.
rigHasKey(){ ## item file
	LC_ALL=C awk 'NR == 1 && $0 != "---" { exit ; } NR > 1 && $0 == "---" { exit ; } index($0, "status: ") == 1 { found = 1 ; } END { exit found ? 0 : 1 ; }' "$1"
}
## The item without its frontmatter `status: ` line, on stdout.
rigWithoutKey(){ ## item file
	LC_ALL=C awk '
		NR == 1 && $0 != "---" { body = 1 ; }
		NR > 1 && $0 == "---" { body = 1 ; }
		!body && index($0, "status: ") == 1 { next ; }
		{ print ; }
	' "$1"
}

rigRead=0 rigCarrying=0 rigRemoved=0 rigLeft=0
for rigState in "$rigBoard"/*/ ; do
	[ -d "$rigState" ] || continue
	for rigItem in "$rigState"*.md ; do
		[ -f "$rigItem" ] || continue
		rigRead=$(( rigRead + 1 ))
		rigHasKey "$rigItem" || continue
		rigCarrying=$(( rigCarrying + 1 ))
		[ -n "$rigApply" ] || continue
		rigTmpItem="$( mktemp "$rigItem.tmp.XXXXXX" )" || { echo "⛔ ERROR: could not make a temp file beside $rigItem" >&2 ; exit 1 ; }
		rigWithoutKey "$rigItem" > "$rigTmpItem" || { rm -f "$rigTmpItem" ; echo "⛔ ERROR: could not write $rigTmpItem" >&2 ; exit 1 ; }
		mv -f "$rigTmpItem" "$rigItem" || { rm -f "$rigTmpItem" ; echo "⛔ ERROR: could not rename onto $rigItem" >&2 ; exit 1 ; }
		rigRemoved=$(( rigRemoved + 1 ))
	done
done
## Read back through a fresh walk of the same files, never the count the write kept.
if [ -n "$rigApply" ] ; then
	for rigState in "$rigBoard"/*/ ; do
		[ -d "$rigState" ] || continue
		for rigItem in "$rigState"*.md ; do
			[ -f "$rigItem" ] || continue
			rigHasKey "$rigItem" && rigLeft=$(( rigLeft + 1 ))
		done
	done
fi
printf 'read %d\ncarrying %d\nremoved %d\nleft %d\n' "$rigRead" "$rigCarrying" "$rigRemoved" "$rigLeft"
