#!/usr/bin/env bash
## Behavioural check on an idle wait over a mandatory CheckList item: one a parent gave the run (`parent`, S6.27) is
## not the run's to drop, so `--idle-wait` is refused and its refusal names that item. Through the real
## DistroAgentsSession.fn.sh, a spawn record and the list the CheckList tool keeps. Held:
##   1. the seed marks its item `parent`, and the item is open
##   2. an idle wait over that item is refused: it writes no request and waits on nothing
##   3. the refusal names the item, as the item and as the parent's
##   4. the refusal is not the answer an open item of the member's own gets: the two answers differ
##   5. control: with no open item, the idle wait goes on to wait, and its request is written
## Red before the fix: 3 and 4 fail. The one reader both the idle wait and the wait use,
## `AgentsSessionChecklistOpenInto` (`sh-lib/session/AgentsTools.CheckListSeed.include`), reads the list's lines and
## never its marks, so a `parent` item and the member's own are one class and answer alike.
## Offline: every path under one rig tree, no model, no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPkg="${rigHere%/sh-lib}"
rigSession="$rigPkg/sh-scripts/DistroAgentsSession.fn.sh"
rigSeed="$rigHere/session/AgentsTools.CheckListSeed.include"
rigMember="rig-idler"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigSession" "$rigSeed" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
## A call of this rig may start the workspace's own on-demand threads, and a thread outlives the check that started
## it, so every one of them is ended before the tree is removed (T1905Z).
. "$rigPkg/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsIdleWaitParentItemCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigSandbox="$rigTmp/sandbox"
rigId="rig-idle-parent"
rigStore="$rigWs/.local/agents/sessions/$rigId"
mkdir -p "$rigSkills/$rigMember" "$rigSkills/magic-team" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig" "$rigSandbox" "$rigTmp/home" || exit 1
printf '%s\n' "$rigMember" > "$rigSkills/$rigMember/$rigMember.basic.md"
printf 'rig\n' > "$rigSkills/magic-team/magic-team.basic.md"
## The routine in force names no scan, so the answer's sources are the floor alone and no other line is read.
printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: rig\ninvitees: none\nrequires-session-kind: standalone\ninput-scan-def: none\n---\n# rig routine\n' "$rigMember" \
	> "$rigSkills/magic-team/magic-team.rigstandalone.routine.md"
printf -- '---\nspawn-id: %s\nsession-id: %s\nowner: %s\nroutine: magic-team.rigstandalone.routine.md\nstatus: spawn-started\n---\n' \
	"$rigId" "$rigId" "$rigMember" > "$rigWs/.local/agents/spawned/rig/$rigId.spawn.md"
## A harness run of this session: without the marker the call answers a native client and waits on nothing.
: > "$rigSandbox/$rigId.harness"
rigList="$rigWs/.local/agents/spawned/rig/$rigMember.checklist.md"
rigMarks="$rigWs/.local/agents/spawned/rig/$rigMember.checklist-sources.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The seed the spawn runs before the run's first turn, so the marks on this list are the tooling's own.
rigSeedList(){ ## the item texts, one a line on standard input
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash -c '. "$1" || exit 1 ; AgentsToolsCheckListSeed "$2" "$3" ""' rig "$rigSeed" "$rigId" "$rigMember" > /dev/null 2>&1 )
}
## One idle wait as the run makes it: its answer, its own status, and the requests the run's store keeps.
rigIdle(){ ## any arguments of the operation
	rm -f "$rigStore/checkpoint.request" 2>/dev/null || :
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT="$rigMember" \
		MDAT_SPAWN_SESSION_ID="$rigId" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" \
		bash "$rigSession" --idle-wait "$@" ) > "$rigTmp/out" 2> "$rigTmp/err"
	rigRc=$?
	rigOut="$( cat "$rigTmp/out" )" ; rigErr="$( cat "$rigTmp/err" )"
}
rigRequest(){ LC_ALL=C awk 'NF { printf "%s%s", ( n++ ? ";" : "" ), $0 ; }' "$rigStore/checkpoint.request" 2>/dev/null ; }
rigItem(){ ## a text -- the list's line for it, or nothing
	[ -f "$rigList" ] || { printf 'no-list' ; return 0 ; }
	LC_ALL=C awk -v want="$1" 'index( $0, want ) { print ; exit ; }' "$rigList"
}

echo "-- 1. the seeded item is the parent's, and it is open --"
printf 'RIG-SEEDED-TASK\n' | rigSeedList
rigAssert "the seeded item is on the list, open"          "$( rigItem RIG-SEEDED-TASK )" "- [ ] RIG-SEEDED-TASK"
rigAssert "the seed marked it the parent's"               "$( LC_ALL=C grep -c -x -F -- "parent	RIG-SEEDED-TASK" "$rigMarks" 2>/dev/null )" 1

echo "-- 2. the idle wait is refused: it writes no request, and waits on nothing --"
rigIdle
rigAssert "the call exits 0, as a refusal of this kind does" "$rigRc" 0
rigAssert "and it wrote no request, so it waits on nothing" "$( rigRequest )" ""
rigAssert "and it did not go on to an ordinary wait"        "$( LC_ALL=C grep -c -e 'WAIT-RESULT' -e 'returns to its checkpoint' "$rigTmp/out" )" 0

echo "-- 3 and 4. the refusal names the item, and separates it from the member's own --"
## THE MARKER IS NOT THIS CHECK'S TO CHOOSE. The refusal has to say that this item is the parent's, and the wording
## the fix picks is the architect's. So any of the words such a refusal carries is taken, and the rig asks only that
## a parent item's answer carries one of them and an own item's answer carries none.
rigMarks2='parent|mandatory|not yours to close'
rigSaysParent(){ LC_ALL=C grep -c -i -E -e "$rigMarks2" "$1" 2>/dev/null ; }
rigAssert "the refusal names the item it refuses over"    "$( LC_ALL=C grep -c -F -- 'RIG-SEEDED-TASK' "$rigTmp/out" )" 1
rigAssert "and says the item is the parent's, and so is not the run's to close" "$( rigSaysParent "$rigTmp/out" )" 1
## THE CONTROL FOR THAT CLAIM: an open item of the member's own is answered with no such word, so the word is the
## parent item's and not one every answer carries. It is still held back, the list being the queue.
printf -- '- [ ] RIG-OWN-ITEM\n' > "$rigList"
: > "$rigMarks"
rigIdle
rigAssert "an open item of the member's own is answered with no such word" "$( rigSaysParent "$rigTmp/out" )" 0
rigAssert "and it is still held back, the list being the queue"  "$( rigRequest )" ""

echo "-- 5. control: with no open item the idle wait goes on to wait --"
printf -- '- [x] RIG-OWN-ITEM\n' > "$rigList"
: > "$rigMarks"
rigIdle
rigAssert "the call writes its request, so it waits"       "$( LC_ALL=C grep -c -F -- 'idle' "$rigStore/checkpoint.request" 2>/dev/null )" 1
rigAssert "and its answer names what it waits on"          "$( LC_ALL=C grep -c -e 'the harness waits on the floor' -e 'waits for any message addressed to it' "$rigTmp/out" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ IDLE WAIT PARENT ITEM CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'IDLE_WAIT_PARENT_ITEM: OK (%d assertions, offline)\n' "$rigPassCount"
