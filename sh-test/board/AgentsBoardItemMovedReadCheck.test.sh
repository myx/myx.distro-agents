#!/usr/bin/env bash
## An item the scan cannot read costs that item and nothing else. A handback moves a running item to review, and
## housekeeping does it while a scan walks the states, so a listed item can be gone from its folder by the time it
## is read. The scan names it and returns every other section; under the dispatcher's own set -e, an unguarded read
## ends the whole scan instead.
## Offline: a temp workspace, data root and HOME, three review items, and one of them made unreadable. The control
## run is the same scan with every item readable, so a scan that simply stopped naming items could not pass both.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardItemMovedReadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws" "$rigTmp/home/.claude/skills/magic-coordinator" "$rigTmp/data/inboxes/magic-coordinator" \
	"$rigTmp/data/board/review" "$rigTmp/data/board/running" "$rigTmp/data/board/backlog" "$rigTmp/data/board/blocked"
printf '# magic-coordinator\n' > "$rigTmp/home/.claude/skills/magic-coordinator/SKILL.md"
for rigName in task-rig-kept task-rig-gone task-rig-also ; do
	printf -- '---\ntype: task\nowner: magic-coordinator\ndate: 2026-11-03 10:00 +0000\n---\n\n# %s\n' "$rigName" \
		> "$rigTmp/data/board/review/$rigName.md"
done
printf -- '---\ntype: task\nowner: magic-coordinator\n---\n\n# running rig item\n' > "$rigTmp/data/board/running/task-rig-running.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One scan of the whole active board, in the rig tree, in its own env -i.
rigScan(){ ## output file, rc file
	local scanOut="$1" scanRcFile="$2" scanRc=0
	( cd "$rigTmp/ws" && env -u MDAT_SKILLSET_ROOT HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigTmp/data" bash "$rigTool" --intern-op-session-context-scan magic-coordinator \
		--state review --state running --state backlog --state blocked --all-types \
		--no-slack --no-email --no-trello --no-inbox-inquiry --no-inbox-reflections --no-inbox-notes \
		--no-inbox-other --no-board-related ) > "$scanOut" 2> "$scanOut.err" || scanRc=$?
	printf '%s' "$scanRc" > "$scanRcFile"
}
rigSection(){ ## output file, state, item name
	LC_ALL=C grep -c -x -F -- "## $2/$3.md" "$1" || :
}

echo "-- an item the scan cannot read --"
chmod 000 "$rigTmp/data/board/review/task-rig-gone.md"
rigScan "$rigTmp/moved" "$rigTmp/moved.rc"
chmod 644 "$rigTmp/data/board/review/task-rig-gone.md"
rigAssert "the scan still succeeds"                   "$( cat "$rigTmp/moved.rc" )" 0
rigAssert "the unreadable item is named and skipped"  "$( LC_ALL=C grep -c 'item not read -- review/task-rig-gone.md' "$rigTmp/moved" || : )" 1
rigAssert "its neighbour in the same state is read"   "$( rigSection "$rigTmp/moved" review task-rig-kept )" 1
rigAssert "and so is the other one"                   "$( rigSection "$rigTmp/moved" review task-rig-also )" 1
rigAssert "a running item's section is read too"      "$( rigSection "$rigTmp/moved" running task-rig-running )" 1

echo "-- control: every item readable --"
rigScan "$rigTmp/whole" "$rigTmp/whole.rc"
rigAssert "control: the scan succeeds"                "$( cat "$rigTmp/whole.rc" )" 0
rigAssert "control: all three review items are read"  "$( LC_ALL=C grep -c -x -E '## review/task-rig-(kept|gone|also)[.]md' "$rigTmp/whole" || : )" 3
rigAssert "control: and the running item is read"     "$( rigSection "$rigTmp/whole" running task-rig-running )" 1
rigAssert "control: and nothing is named as skipped"  "$( LC_ALL=C grep -c 'item not read --' "$rigTmp/whole" || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD ITEM MOVED READ CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_ITEM_MOVED_READ: OK (%d assertions, offline)\n' "$rigPassCount"
