#!/usr/bin/env bash
## Behavioural check: `--get-my-board-items <member>` lists the member's own active board items, and only those.
##   1. a pending and a running item owned by the member are listed
##   2. an item owned by another member, and a processed item of the member, are not listed
##   3. the output holds no inbox section: it is a board query, not the duty's whole input scan
##   4. control that the check can fail: the member's own inbox item, present in the store, does not appear
## Offline: the rig's own board store under this check's scratch; every call one `env -i` whose child refuses to
## run outside it. Never the live team data.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsItems.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsGetMyBoardItemsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigData/board/pending" "$rigData/board/running" "$rigData/board/processed" \
	"$rigData/inboxes/rig-dev/incoming" "$rigSkills/rig-dev" "$rigSkills/rig-other"
for rigMember in rig-dev rig-other ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
done
rigItem(){ ## state, item name, owner
	printf -- '---\ntype: task\nfrom: rig\ndate: 2026-11-13 09:00 +0200\nowner: %s\ndocument-contract: board-item.task\n---\n\n# %s\n\nbody\n' "$3" "$2" > "$rigData/board/$1/$2.md"
}
rigItem pending task-20261113T0900Z-rig-mine-pending rig-dev
rigItem running task-20261113T0901Z-rig-mine-running rig-dev
rigItem pending task-20261113T0902Z-rig-theirs rig-other
rigItem processed task-20261113T0903Z-rig-mine-done rig-dev
printf -- '---\ntype: inquiry\nfrom: rig-other\ndate: 2026-11-13 09:04 +0200\nowner: rig-dev\ndocument-contract: inbox-item.inquiry\n---\n\nrig-inbox-marker\n' \
	> "$rigData/inboxes/rig-dev/incoming/inquiry-20261113T0904Z-rig-inbox-marker.md"

( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=rig-dev RIG_TMP="$rigTmp" RIG_TOOL="$rigTool" \
	bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$RIG_TOOL" --get-my-board-items rig-dev' rig ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null
rigRc=$?
rigCount(){ LC_ALL=C grep -c -F -- "$1" "$rigTmp/out" || : ; }

echo "-- 1. the member's own active items are listed --"
rigAssert "the call succeeds" "$rigRc" 0
rigAssert "its pending and its running item are listed" "$( rigCount rig-mine-pending ):$( rigCount rig-mine-running )" "1:1"
echo "-- 2. nothing else of the board --"
rigAssert "another member's item and its own processed item are not" "$( rigCount rig-theirs ):$( rigCount rig-mine-done )" "0:0"
echo "-- 3. no inbox section --"
rigAssert "no inbox heading" "$( LC_ALL=C grep -c '^## .*Inbox' "$rigTmp/out" || : )" "0"
echo "-- 4. control: the member's inbox item exists and is not shown --"
rigAssert "the inbox item is in the store, and absent from the output" \
	"$( [ -f "$rigData/inboxes/rig-dev/incoming/inquiry-20261113T0904Z-rig-inbox-marker.md" ] && echo present ):$( rigCount rig-inbox-marker )" "present:0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ GET MY BOARD ITEMS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'GET_MY_BOARD_ITEMS: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
