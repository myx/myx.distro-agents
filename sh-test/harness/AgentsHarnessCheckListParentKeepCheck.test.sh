#!/usr/bin/env bash
## Behavioural check on a mandatory CheckList item: one a parent gave the run (`parent`, S6.27) is not the run's to
## drop. Through the real CheckList tool (AgentsUniversalHarness.sh --intern-tool CheckList) and a list the seed
## wrote, in a rig workspace. Held:
##   1. the seed marks its item `parent`, and a read of the list shows it as one
##   2. a whole-list write that leaves the parent's item out keeps it, open
##   3. ...and keeps it after a read of its own list, which is what clears what another session added
##   4. the member's own write closes it, where it carries it closed -- that is the one route that closes it
##   5. control: the member's own open item, left out of a write, is dropped, so the keeping is the parent's alone
## Red before the fix: 2 and 3 fail. The write replaces the whole list, and the only protection it has is the
## `<member>.checklist.md.added` file, which the seed never writes (`sh-lib/session/AgentsTools.CheckListSeed.include`,
## the seed writes its marks and no `.added` line), so a seeded or marked item is gone after the write.
## Offline: every tree is this rig's own; no network is reached.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPkg="${rigHere%/sh-lib}"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigSeed="$rigHere/session/AgentsTools.CheckListSeed.include"
rigMember="rig-runner"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigSeed" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
## A call of this rig starts the workspace's own on-demand threads (the event-id thread of the comms cache), and a
## thread outlives the check that started it, so every one of them is ended before the tree is removed (T1905Z).
. "$rigPkg/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessCheckListParentKeepCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSp="$rigWs/.local/agents/spawned"
rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/.agents" "$rigSp/child-folder" "$rigSkills/$rigMember" "$rigTmp/home" "$rigTmp/bin" || exit 1
## A `timeout` of the rig's own: with none on PATH the harness takes its watchdog branch, which leaves a `sleep`
## behind the check. With this one every hook is bounded and the check leaves nothing running.
printf '#!/bin/sh\nshift\nexec "$@"\n' > "$rigTmp/bin/timeout"
chmod +x "$rigTmp/bin/timeout"
PATH="$rigTmp/bin:/usr/bin:/bin"
export PATH
printf 'rig member\n' > "$rigSkills/$rigMember/$rigMember.basic.md"

## The session's own record: its list is kept in the folder that holds it (AgentsHarnessCheckListPlace).
printf -- '---\nspawn-id: rig-child\nsession-id: rig-child\nowner: %s\nparent-session-id: none\n---\n' "$rigMember" \
	> "$rigSp/child-folder/rig-child.spawn.md"
rigList="$rigSp/child-folder/$rigMember.checklist.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The items of a read, as the read shows them, one a line.
rigItems(){ LC_ALL=C grep -e '^- \[ \] ' -e '^- \[x\] ' -e '^- \[~\] ' <<< "$1" ; }
## One CheckList call as the run makes it: the JSON arguments on standard input, the tool's whole answer.
rigCall(){ ## the JSON arguments
	( cd "$rigWs" && printf '%s' "$1" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" HOME="$rigTmp/home" \
		MDAT_SPAWN_SESSION_ID=rig-child MDAT_SPAWN_AGENT="$rigMember" \
		bash "$rigHarness" --intern-tool CheckList 2> /dev/null )
}
## The seed the spawn runs before the run's first turn (AgentsToolsCheckListSeed): the item is the parent's.
rigSeedList(){ ## the item text
	( cd "$rigWs" && printf '%s\n' "$1" | MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" HOME="$rigTmp/home" \
		bash -c '. "$1" || exit 1 ; AgentsToolsCheckListSeed rig-child "$2" ""' rig "$rigSeed" "$rigMember" > /dev/null 2>&1 )
}
rigItem(){ ## a text -- the list's whole lines, joined by ` | `
	[ -f "$rigList" ] || { printf 'no-list' ; return 0 ; }
	LC_ALL=C awk -v want="$1" 'index( $0, want ) { printf "%s%s", ( n++ ? " | " : "" ), $0 ; }' "$rigList"
}

echo "-- 1. the seed marks its item the parent's, and the read shows it so --"
rigSeedList RIG-PARENT-ITEM
rigAssert "the seed put the item on the list"            "$( rigItem RIG-PARENT-ITEM )" "- [ ] RIG-PARENT-ITEM"
rigAssert "the seed marked it the parent's"             "$( LC_ALL=C grep -c -x -F -- "parent	RIG-PARENT-ITEM" "${rigList%.checklist.md}.checklist-sources.md" 2>/dev/null )" 1
rigAssert "and the read shows it as the parent's"       "$( rigItems "$( rigCall '{}' )" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-PARENT-ITEM [parent]' )" 1
rigAssert "the seed wrote nothing to keep for a later write" "$( [ -e "$rigList.added" ] && printf left || printf none )" none

echo "-- 2. a whole-list write that leaves the parent's item out keeps it, open --"
rigCall '{"todos":[{"content":"RIG-OWN-ITEM","status":"pending","activeForm":"Doing the own item"}]}' > /dev/null
rigAssert "the member's own item is written"             "$( rigItem RIG-OWN-ITEM )" "- [ ] RIG-OWN-ITEM"
rigAssert "and the parent's item is still there, open"   "$( rigItem RIG-PARENT-ITEM )" "- [ ] RIG-PARENT-ITEM"
rigAssert "with its source intact"                       "$( rigItems "$( rigCall '{}' )" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-PARENT-ITEM [parent]' )" 1

echo "-- 3. and after a read of its own list, which clears what another session added --"
rigCall '{}' > /dev/null
rigCall '{"todos":[{"content":"RIG-OWN-ITEM","status":"pending","activeForm":"Doing the own item"}]}' > /dev/null
rigAssert "nothing is left to be kept for the next write" "$( [ -e "$rigList.added" ] && printf left || printf none )" none
rigAssert "the parent's item survives that write too"     "$( rigItem RIG-PARENT-ITEM )" "- [ ] RIG-PARENT-ITEM"

echo "-- 4. the member's own write closes it, where it carries it closed --"
rigCall '{"todos":[{"content":"RIG-OWN-ITEM","status":"pending","activeForm":"Doing the own item"},{"content":"RIG-PARENT-ITEM","status":"completed","activeForm":"Finishing the parent item"}]}' > /dev/null
rigAssert "the parent's item is closed by the member's own write" "$( rigItem RIG-PARENT-ITEM )" "- [x] RIG-PARENT-ITEM"

echo "-- 5. control: an own item left out of a write is dropped --"
rigCall '{"todos":[{"content":"RIG-SECOND-ITEM","status":"pending","activeForm":"Doing the second item"}]}' > /dev/null
rigAssert "the own item the write left out is gone"      "$( rigItem RIG-OWN-ITEM )" ""
rigAssert "and the one the write carried is there"        "$( rigItem RIG-SECOND-ITEM )" "- [ ] RIG-SECOND-ITEM"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS CHECKLIST PARENT KEEP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_CHECKLIST_PARENT_KEEP: OK (%d assertions, offline)\n' "$rigPassCount"
