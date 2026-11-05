#!/usr/bin/env bash
## Behavioural check on the board tree a sweep scans being NAMED, and being the tree its
## rounds write (S16 stage 1, item 3). The scan is run in THE SWEEP'S OWN SHAPE -- the call
## `AgentsToolsBoardRoundSections` makes (AgentsTools.BoardRoundScan.include), which engages
## no comms or inbox section and declines the board section itself. A heading that a section's
## metadata is gated behind therefore has no heading at all, and this check is the one that
## says so: the item blocks print there whatever the guard, so the scope line must print too.
##   1. THE SWEEP'S SCAN EMITS THE SECTION: a `## Board Items` heading, and the item blocks.
##   2. THE SCOPE LINE PRINTS WITH IT, before the first item block, and names the rig's tree.
##   3. THE WRITE NAMES THE SAME TREE, whatever verb it logs under: --log-verb:updated
##      included, which every review round's own write passes.
##   4. CONTROL -- the scan did reach this rig's board, and the move did move the item: an
##      empty board and a refused move would satisfy 1 to 3 by naming nothing real.
## Offline: a temp workspace, a data root and a HOME of this check's own, no git.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardTreeNamedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigHome="$rigTmp/home"
mkdir -p "$rigWs" "$rigData/board/running" "$rigData/board/review" "$rigHome/skills/magic-coordinator"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigHome/skills/magic-coordinator/magic-coordinator.basic.md"
rigItem="task-20261104T0101Z-rig-tree.md"
printf -- '---\ntype: task\nowner: magic-coordinator\n---\n\nrig item\n' > "$rigData/board/running/$rigItem"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One op against this rig's own store: output and status captured, and the run refused
## outright if the store it would touch is not under the rig.
rigOp(){ ## result file, operation and its arguments...
	local opOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigHome/skills" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}
## The tree a scan's board section names in its `scope:` line, and nothing else. The tree is
## the line's tail, so a path holding a space needs no quoting.
rigScanTree(){ ## scan output file
	LC_ALL=C awk '/^scope: board\// && /, tree: / { sub( /^.*, tree: /, "" ) ; print ; exit }' "$1" 2> /dev/null
}
## The line number of the first item block of a scan's output, or 0 for none.
rigFirstItemLine(){ ## scan output file, state
	LC_ALL=C awk -v want="## $2/" 'index( $0, want ) == 1 { print NR ; exit } END { if ( NR == 0 ) print 0 }' "$1" 2> /dev/null
}
## The tree a board move's success line names, whatever verb it logs under. The move logs
## `wrote` by default and whatever `--log-verb:<verb>` names, so the verb is not matched.
rigWriteTree(){ ## move output file
	LC_ALL=C awk '/^# .*board-upsert-move-edit: [a-z]+ / && /, tree: / { sub( /^.*, tree: /, "" ) ; print ; exit }' "$1" 2> /dev/null
}

echo "-- 1 and 4. the sweep's own scan shape names the board section --"
rigOp "$rigTmp/scan" --intern-op-session-context-scan magic-coordinator \
	--state pending --state running --state review --state blocked --state parked \
	--all-types --no-inbox-inquiry --no-inbox-reflections --no-inbox-notes --no-slack --no-email --no-trello \
	--no-inbox-other --no-board-related --context rig-sweep
rigAssert "the sweep's scan ran" "$( cat "$rigTmp/scan.rc" )" 0
rigAssert "control: it listed this rig's running item" \
	"$( LC_ALL=C grep -c -x -F "## running/$rigItem" "$rigTmp/scan" )" 1
rigAssert "the sweep's scan emits the section heading" \
	"$( LC_ALL=C grep -c -x -F '## Board Items' "$rigTmp/scan" )" 1

echo "-- 2. the scope line prints with the items, before the first of them --"
rigAssert "the scope line names the tree the scan read" "$( rigScanTree "$rigTmp/scan" )" "$rigData/board"
rigAssert "and it stands before the first item block" \
	"$( LC_ALL=C awk '/^scope: board\// && /, tree: / { scopeAt = NR } index( $0, "## running/" ) == 1 && !itemAt { itemAt = NR } END { print ( scopeAt && itemAt && scopeAt < itemAt ) ? "before" : "not-before" }' "$rigTmp/scan" )" before

echo "-- 3 and 4. the write names the tree, under a verb other than wrote --"
rigOp "$rigTmp/move" --intern-op-board-upsert-move-edit review "$rigItem" --from-state:running \
	--acting-member:magic-coordinator --log-verb:updated --context rig-sweep
rigAssert "control: the move ran and the item is now in review" \
	"$( [ "$( cat "$rigTmp/move.rc" )" = 0 ] && [ -f "$rigData/board/review/$rigItem" ] && printf moved || printf not-moved )" "moved"
rigAssert "the write's own line names the tree it wrote, under --log-verb:updated" \
	"$( rigWriteTree "$rigTmp/move" )" "$rigData/board"

echo "-- the two names are the same tree --"
rigAssert "the tree scanned is the tree written" \
	"$( rigScanTree "$rigTmp/scan" ):$( rigWriteTree "$rigTmp/move" )" "$rigData/board:$rigData/board"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'BOARD_TREE_NAMED: OK\n'
