#!/usr/bin/env bash
## Behavioural check on the board rename (--intern-op-board-rename) against the write gate of the board (F5.3,
## AgentsToolsDocValidateGate): what the rename writes itself -- the renamed item's `supersedes` and the husk it leaves at
## board/processed/ -- is held to the contract of the item's type, as every write of the board is, so a writer of the tooling
## must produce what the gate lets through. Held, run and not read:
##   1. THE RENAMED ITEM carries `supersedes: <old name>` as a bare item name (no .md, no note beside it), and nothing is refused.
##   2. THE HUSK is an item of the old name's own type (task-, approval-, proposal-), `superseded-by:` the new name, bare, stamped
##      processed-at: written, in board/processed/, and nothing is refused.
##   3. --do-not-track leaves no husk, and the rename of the item still goes through.
## Offline: a rig workspace of this check's own under .local/agents/scratch/sh-test; no Slack, no network.
set -u
## The runner gives every test a team rig as the default workspace mode (AgentsRunTests.sh); a run by hand takes the same default, so the result is the same either way.
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardRenameGateCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigData="$rigTmp/data" rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/skills/rig-member" "$rigData/board/backlog" "$rigData/board/processed" "$rigData/board/review"
printf 'rig\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"
rigItem(){ ## state, name, type word -- an item of that type, as the contract's skeleton has it
	printf -- '---\ndocument-contract: board-item.%s\ntype: %s\nfrom: rig-member\nowner: rig-member\ndate: 2026-10-20 04:00 +0300\n---\n\n# %s: the thing\n\nbody of it\n' "$3" "$3" "$3" > "$rigData/board/$1/$2"
}
rigRename(){ ## old, new, options...
	local renameOld="$1" renameNew="$2"
	shift 2
	( cd "$rigWs" && env -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 90 -- bash "$rigTool" --intern-op-board-rename "$renameOld" "$renameNew" "$@" ) > "$rigTmp/rename.out" 2> "$rigTmp/rename.err"
	rigRc=$?
}
rigKey(){ ## file, key -- the first value of a frontmatter key
	LC_ALL=C awk -v want="$2" 'NR == 1 && $0 == "---" { on = 1 ; next ; } on && $0 == "---" { exit ; } on && index($0, want ": ") == 1 { print substr($0, length(want) + 3) ; exit ; }' "$1" 2> /dev/null
}
rigRefusals(){ ## how many refusals the gate said: its closing line of a write it did not make, and a line naming a fault
	LC_ALL=C grep -c -e "nothing was written" -e "contract-" "$rigTmp/rename.err" 2> /dev/null || :
}

echo "-- 1 and 2. the item and its husk, for three types --"
for rigType in task approval proposal ; do
	rigOld="$rigType-20261020T0100Z-rig-old.md" rigNew="$rigType-20261020T0100Z-rig-new.md"
	rigItem backlog "$rigOld" "$rigType"
	rigRename "$rigOld" "$rigNew"
	rigAssert "$rigType: the rename ends well, and the gate refused nothing"      "$rigRc:$( rigRefusals )" "0:0"
	rigAssert "$rigType: the renamed item supersedes the old name, bare"           "$( rigKey "$rigData/board/backlog/$rigNew" supersedes )" "${rigOld%.md}"
	rigAssert "$rigType: the husk stands at board/processed under the old name"     "$( [ -f "$rigData/board/processed/$rigOld" ] && printf yes || printf no )" yes
	rigAssert "$rigType: it is an item of the old name's type"                      "$( rigKey "$rigData/board/processed/$rigOld" type )" "$rigType"
	rigAssert "$rigType: it names what replaced it, bare, and is stamped processed" "$( rigKey "$rigData/board/processed/$rigOld" superseded-by ):$( [ -n "$( rigKey "$rigData/board/processed/$rigOld" processed-at )" ] && printf stamped )" "${rigNew%.md}:stamped"
done

echo "-- 3. --do-not-track --"
rigItem backlog task-20261020T0110Z-rig-quiet.md task
rigRename task-20261020T0110Z-rig-quiet.md task-20261020T0110Z-rig-quieter.md --do-not-track
rigAssert "no husk, the rename goes through, nothing refused" "$rigRc:$( [ -f "$rigData/board/processed/task-20261020T0110Z-rig-quiet.md" ] && printf husk || printf none ):$( [ -f "$rigData/board/backlog/task-20261020T0110Z-rig-quieter.md" ] && printf renamed ):$( rigRefusals )" "0:none:renamed:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD RENAME GATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_RENAME_GATE: OK (%d assertions, offline)\n' "$rigPassCount"
