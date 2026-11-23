#!/usr/bin/env bash
## Control check for the parent-item rigs beside it: the instrument those rigs read through can show a mark and can show
## its absence, on the untouched tree, so their red is a missing behaviour and not a probe that never looks.
## Held:
##   1. the seed writes a `parent` mark, and a read of the list shows it as ` [parent]`
##   2. the same read shows the member's own item with no mark at all
##   3. a mark of the member's own that is not `own` is shown too, so a mark of any name survives the read
##   4. control for the control: a list with no marks file reads every item with no suffix
## Passes on the untouched tree, and every assertion here passes before and after the fix.
## Offline: a rig workspace and a skillset of this rig's own; no network is reached.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPkg="${rigHere%/sh-lib}"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigSeed="$rigHere/session/AgentsTools.CheckListSeed.include"
rigTest="$rigPkg/sh-test"
rigMember="rig-control"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigSeed" "$rigTest/check-fixtures/rig-temp.include.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
## A call of this rig starts the workspace's own on-demand threads (the event-id thread of the comms cache), and a
## thread outlives the check that started it, so every one of them is ended before the tree is removed (T1905Z).
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessCheckListParentMarkControl )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigHome="$rigTmp/home"
mkdir -p "$rigSkills/$rigMember" "$rigWs/.local/agents/spawned/rig-control-run" "$rigHome" || exit 1
printf '%s\n' "$rigMember" > "$rigSkills/$rigMember/$rigMember.basic.md"
printf -- '---\nspawn-id: rig-control-run\nsession-id: rig-control-run\nowner: %s\nparent-session-id: none\n---\n' "$rigMember" \
	> "$rigWs/.local/agents/spawned/rig-control-run/rig-control-run.spawn.md"
rigList="$rigWs/.local/agents/spawned/rig-control-run/$rigMember.checklist.md"
rigMarks="${rigList%.checklist.md}.checklist-sources.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigItems(){ LC_ALL=C grep -e '^- \[ \] ' -e '^- \[x\] ' -e '^- \[~\] ' <<< "$1" ; }
rigSeedList(){ ## the item text, its lines on standard input
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID HOME="$rigHome" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash -c '. "$1" || exit 1 ; AgentsToolsCheckListSeed "$2" "$3" ""' rig "$rigSeed" rig-control-run "$rigMember" > /dev/null 2>&1 )
}
rigCall(){ ## the JSON arguments
	( cd "$rigWs" && printf '%s' "$1" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" HOME="$rigHome" \
		MDAT_SPAWN_SESSION_ID=rig-control-run MDAT_SPAWN_AGENT="$rigMember" \
		bash "$rigHarness" --intern-tool CheckList 2> /dev/null )
}

echo "-- 1. the seed's mark is written, and the read shows it --"
printf 'RIG-SEEDED-TASK\n' | rigSeedList
rigAssert "the seed's mark is on the list's marks file"    "$( LC_ALL=C grep -c -x -F -- "parent	RIG-SEEDED-TASK" "$rigMarks" 2>/dev/null )" 1
rigAssert "and the read shows it as the parent's"          "$( rigItems "$( rigCall '{}' )" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-SEEDED-TASK [parent]' )" 1

echo "-- 2. the member's own item reads with no mark at all --"
rigCall '{"todos":[{"content":"RIG-SEEDED-TASK","status":"pending","activeForm":"A"},{"content":"RIG-OWN-ITEM","status":"pending","activeForm":"Doing the own item"}]}' > /dev/null
rigRead="$( rigCall '{}' )"
rigAssert "the own item reads with no suffix"              "$( rigItems "$rigRead" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-OWN-ITEM' )" 1
rigAssert "and its mark is own"                            "$( LC_ALL=C grep -c -x -F -- "own	RIG-OWN-ITEM" "$rigMarks" 2>/dev/null )" 1

echo "-- 3. a mark of any other name is shown too --"
printf -- 'step\tRIG-OWN-ITEM\nparent\tRIG-SEEDED-TASK\n' > "$rigMarks"
rigAssert "a step mark reads as a step mark"               "$( rigItems "$( rigCall '{}' )" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-OWN-ITEM [step]' )" 1

echo "-- 4. control for the control: with no marks file, nothing is shown --"
rm -f "$rigMarks"
rigRead="$( rigCall '{}' )"
rigAssert "no item reads with a suffix"                    "$( rigItems "$rigRead" | LC_ALL=C grep -c -e '\[step\]' -e '\[parent\]' )" 0
rigAssert "and both items are still read"                  "$( rigItems "$rigRead" | LC_ALL=C grep -c -e 'RIG-OWN-ITEM' -e 'RIG-SEEDED-TASK' )" 2

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS CHECKLIST PARENT MARK CONTROL FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_CHECKLIST_PARENT_MARK_CONTROL: OK (%d assertions, offline)\n' "$rigPassCount"
