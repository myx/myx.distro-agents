#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on how an item is written (S26 item 1): the write at
## AgentsTools.InternOpItem.include:539 puts the item beside itself and moves it into place, so a
## reader in the write window sees the old item or the new one, and never an empty or half an item.
## A failed operation leaves the item unchanged.
##   1. THE CONTROL: the upsert succeeds and the item holds the new text.
##   2. THE WRITE IS A RENAME: the item's inode differs across a successful upsert. A truncating
##      write in place keeps the inode, so this is red exactly on the defect and green on a rename.
##   3. NO BESIDE FILE IS LEFT: after the upsert, no `<item>.tmp*` sits beside the item.
## Offline: no network, no git, this check's own data root under the workspace's sh-test scratch.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTools="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTools"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsItemWriteAtomicCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/skills/rig-member" "$rigData/board/backlog"
printf 'rig-member\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigItem="note-20261019T0100Z-rig-atom.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One upsert of the rig's item, its body on stdin: the op's own answer, its status printed last.
## The write is reached through AgentsToolsItemUpsert, the one call site every writer uses: the old
## --intern-op-item-upsert name is retired and refused by name.
rigUpsert(){ ## body text -- the call's output
	local upRc=0
	( cd "$rigWs" && printf '%s\n' "$1" | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin" GIT_CONFIG_NOSYSTEM=1 \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigData" "MDAT_SPAWN_AGENT=rig-member" "MDAT_SESSION_ID=rig-session" \
		bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include" 2> /dev/null
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.InternOpItem.include"
			AgentsToolsItemUpsert rig-member --from-board backlog "'"$rigItem"'" --upsert-from-stdin --context rig
		' ) 2>&1 || upRc=$?
	printf 'UPSERT-EXIT=%s\n' "$upRc"
}
rigInode(){ LC_ALL=C stat -f '%i' "$rigData/board/backlog/$rigItem" 2> /dev/null || LC_ALL=C stat -c '%i' "$rigData/board/backlog/$rigItem" 2> /dev/null ; }
rigItemText(){ cat "$rigData/board/backlog/$rigItem" 2> /dev/null ; }

printf -- '---\ntype: note\nowner: rig-member\n---\n\nRIG-OLD-BODY\n' > "$rigData/board/backlog/$rigItem"

echo "-- 1. the control: the upsert lands --"
rigOut="$( rigUpsert "$( printf -- '---\ntype: note\nowner: rig-member\n---\n\nRIG-NEW-BODY\n' )" )"
rigAssert "the upsert succeeds" "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^UPSERT-EXIT=//p' )" "0"
rigAssert "and the item holds the new text" "$( printf '%s' "$( rigItemText )" | LC_ALL=C grep -c -x -F 'RIG-NEW-BODY' )" "1"

echo "-- 2. the write is a rename, so a reader never sees the item emptied --"
rigBefore="$( rigInode )"
rigOut="$( rigUpsert "$( printf -- '---\ntype: note\nowner: rig-member\n---\n\nRIG-THIRD-BODY\n' )" )"
rigAfter="$( rigInode )"
rigAssert "the upsert succeeds" "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^UPSERT-EXIT=//p' )" "0"
rigAssert "the item's inode differs across the write" "$( [ -n "$rigBefore" ] && [ "$rigBefore" != "$rigAfter" ] && printf renamed || printf same-inode )" "renamed"

echo "-- 3. nothing is left beside the item --"
rigAssert "no beside file is left after the upsert" "$( LC_ALL=C find "$rigData/board/backlog" -maxdepth 1 -name '*.tmp*' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "0"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'ITEM_WRITE_ATOMIC: OK\n'
