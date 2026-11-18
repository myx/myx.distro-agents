#!/usr/bin/env bash
## Behavioural check on an approved epic's go reaching every child the grooming reads (task-20261117T1347Z): a
## board-pending item that carries `epic:` and no go of its own is never recalled to board-backlog while its
## blueprint carries the go, and one whose blueprint carries none is recalled as before. Held, run and not read:
##   1. THE READER: AgentsToolsBoardItemEpicGo prints its blueprint's `approved-by`, prints nothing where that
##      carries none, and refuses where the item names no epic or a blueprint the vault does not hold.
##   2. THE REFUSAL, at the one point both callers reach: --grooming-to-backlog and --move-to-backlog both refuse
##      the recall, the message naming the epic, and the item stands in board-pending, unmoved.
##   3. THE CONTROLS: a blueprint with no go, an item with its own go, and an item naming no epic all recall. A
##      check that could not reach board-backlog at all would report the refusal falsely, so these three run.
## Offline: plain board and vault files in a temp data root, the real tooling.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsEpicGoRecallCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
mkdir -p "$rigTmp/ws"

rigPassCount=0
rigFailCount=0
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigTmp/ws" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills"
rigOwnerBoardReady
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigOp(){ ## result file, extra DistroAgentsTools.fn.sh arguments... (stdin passes through)
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
	printf -- '---\ntype: task\nowner: rig\n%s---\n\nrig item\n' "$3" | rigOwnerBoardPut "$1" "$2"
}
rigEpic(){ ## blueprint filename, then one frontmatter line per argument
	printf -- '---\ndocument-contract: vault-item.epic-blueprint\ntype: epic-blueprint\nfrom: magic-coordinator\ndate: 2026-11-02 00:00 +0200\n%s---\n# 20261102 rig: the epic\n\nSource: `rig.sketch.md`. The rig sprint.\n\nBuilders: magic-developer.\n\n## Decisions\n\n- One rule holds.\n\n---\n\n## S1 - The rig feature\n\nOwner: magic-developer. State: open.\n\n1. One outcome a check can pass. Owner: magic-developer.\n\n## Done\n\n' "$( [ $# -lt 2 ] || printf '%s\n' "${@:2}" )" | rigOwnerVaultPut "$1"
}
rigWhere(){ ## state, item filename -- "there" or "gone"
	[ -f "$rigData/board/$1/$2" ] && echo there || echo gone
}
rigSaid(){ ## result file, fixed text -- how many lines hold it
	LC_ALL=C grep -c -F -- "$2" "$1" || :
}
rigEpicGo(){ ## item filename -- the reader's own answer, or rc=N
	env -i MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c \
		'. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardItemHandler.include" && AgentsToolsBoardItemEpicGo "$1" || echo "rc=$?"' \
		rig "$rigData/board/pending/$1"
}

rigEpicName='epic-blueprint-20261102T0000Z-rig-go.md'
rigEpicNameBare='epic-blueprint-20261102T0000Z-rig-bare.md'
rigEpic "$rigEpicName" 'approved-by: human-owner (rig-session, 2026-11-02T09:00:00Z)' 'approved-at: 2026-11-02 11:00 +0200'
rigEpic "$rigEpicNameBare"

echo "-- 1. the reader: the go live from the blueprint, and nothing where it carries none --"
rigItem pending task-rig-child.md "epic: ${rigEpicName%.md}"$'\n'
rigAssert "a child of an epic with a go: the blueprint's approved-by" "$( rigEpicGo task-rig-child.md )" "human-owner (rig-session, 2026-11-02T09:00:00Z)"
rigItem pending task-rig-child-bare.md "epic: ${rigEpicNameBare%.md}"$'\n'
rigAssert "a child of an epic with no go: nothing printed, and rc 0" "$( rigEpicGo task-rig-child-bare.md )" ""
rigItem pending task-rig-no-epic.md ''
rigAssert "an item naming no epic is refused" "$( rigEpicGo task-rig-no-epic.md )" "rc=1"
rigItem pending task-rig-lost-epic.md 'epic: epic-blueprint-20260101T0000Z-not-in-the-vault'$'\n'
rigAssert "an item naming a blueprint the vault does not hold is refused" "$( rigEpicGo task-rig-lost-epic.md )" "rc=1"
rigAssert "the go is never copied onto the child" "$( LC_ALL=C grep -c -x 'approved-by: .*' "$rigData/board/pending/task-rig-child.md" || : )" 0

echo "-- 2. the refusal: both callers reach the one point, and the item stands unmoved --"
rigOp "$rigTmp/g1" --grooming-to-backlog --team-member magic-coordinator task-rig-child.md --from-state:pending --owner-header-value rig
rigAssert "--grooming-to-backlog is refused" "$( cat "$rigTmp/g1.rc" ):$( rigWhere pending task-rig-child.md ):$( rigWhere backlog task-rig-child.md )" "1:there:gone"
rigAssert "the refusal names the epic and the way out" "$( rigSaid "$rigTmp/g1" "names the epic ${rigEpicName%.md}, which carries a go" ):$( rigSaid "$rigTmp/g1" 'Withdraw the go at the epic to recall it' )" "1:1"
rigOp "$rigTmp/m1" --move-to-backlog --team-member magic-coordinator task-rig-child.md --from-state:pending
rigAssert "--move-to-backlog is refused at the same point" "$( cat "$rigTmp/m1.rc" ):$( rigWhere pending task-rig-child.md )" "1:there"

echo "-- 3. the controls: a recall that must still land --"
rigOp "$rigTmp/c1" --grooming-to-backlog --team-member magic-coordinator task-rig-child-bare.md --from-state:pending --owner-header-value rig
rigAssert "a blueprint with no go: the recall lands in board-backlog" "$( cat "$rigTmp/c1.rc" ):$( rigWhere backlog task-rig-child-bare.md )" "0:there"
rigItem pending task-rig-ready.md $'approved-by: human-owner (rig-session, 2026-11-02T09:00:00Z)\napproved-at: 2026-11-02 11:00 +0200\n'
rigOp "$rigTmp/c2" --grooming-to-backlog --team-member magic-coordinator task-rig-ready.md --from-state:pending --owner-header-value rig
rigAssert "an item with its own go: the recall lands" "$( cat "$rigTmp/c2.rc" ):$( rigWhere backlog task-rig-ready.md )" "0:there"
rigOp "$rigTmp/c3" --grooming-to-backlog --team-member magic-coordinator task-rig-no-epic.md --from-state:pending --owner-header-value rig
rigAssert "an item naming no epic: the recall lands" "$( cat "$rigTmp/c3.rc" ):$( rigWhere backlog task-rig-no-epic.md )" "0:there"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ EPIC GO RECALL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'EPIC_GO_RECALL: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
