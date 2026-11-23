#!/usr/bin/env bash
## Behavioural check on what a read of a CheckList shows: each item's source, so a mandatory item reads as one
## (S6.27). Through the real CheckList tool and the supervisor's own add, over one list. Held:
##   1. a step of the routine in force reads ` [step]`
##   2. an item the seed gave the run reads ` [parent]`
##   3. an item a supervisor added reads ` [parent]` too: it is a parent's item, whoever the parent is
##   4. the run's own item reads with no source at all, and every other item keeps the one it had
##   5. control: the read changes nothing, and a second read says the same
## Red before the fix: 3 fails. The supervisor's add appends its item and calls no marking function
## (`sh-lib/supervise/AgentsTools.SuperviseGuide.include`, the add), so no mark names the item and the read shows it
## as the run's own -- a mandatory item reading as one the run may close at will.
## Offline: a rig workspace and a skillset of this rig's own; no network is reached.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPkg="${rigHere%/sh-lib}"
rigFn="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigSeed="$rigHere/session/AgentsTools.CheckListSeed.include"
rigTest="$rigPkg/sh-test"
rigMember="rig-reader"
rigRun="rig-read-run"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFn" "$rigHarness" "$rigSeed" "$rigTest/check-fixtures/rig-temp.include.sh" "$rigTest/check-fixtures/rig-control-threads.include.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessCheckListSourceReadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigHome="$rigTmp/home"
mkdir -p "$rigSkills/$rigMember" "$rigSkills/magic-coordinator" "$rigSkills/magic-team" "$rigWs/.local/.agents" \
	"$rigWs/.local/agents/spawned/$rigRun" "$rigHome" || exit 1
printf '%s\n' "$rigMember" > "$rigSkills/$rigMember/$rigMember.basic.md"
printf 'magic-coordinator\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigSkills/magic-team/magic-team.basic.md"
## A routine of two steps, so a step item has a name the seed knows.
printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: rig\ninvitees: none\nrequires-session-kind: standalone\n---\n# rig routine\n\n# Steps\n\n1. **rig-step-one**: do the first thing.\n2. **rig-step-two**: do the second thing.\n' "$rigMember" \
	> "$rigSkills/magic-team/magic-team.rigtwosteps.routine.md"
printf -- '---\nspawn-id: %s\nsession-id: %s\nroutine: magic-team.rigtwosteps.routine.md\nowner: %s\nparent-session-id: none\nreports-to: none\nstatus: spawn-started\n---\n' \
	"$rigRun" "$rigRun" "$rigMember" > "$rigWs/.local/agents/spawned/$rigRun/$rigRun.spawn.md"
rigList="$rigWs/.local/agents/spawned/$rigRun/$rigMember.checklist.md"

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
## The seed the spawn runs before the run's first turn, its items on standard input and the routine's steps named:
## this item is the parent's, the routine's two steps are the step's (AgentsToolsCheckListSeed).
rigSeedList(){ ## the item text
	( cd "$rigWs" && printf '%s\n' "rig-step-one" "rig-step-two" "$1" | \
		env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID HOME="$rigHome" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash -c '. "$1" || exit 1 ; AgentsToolsCheckListSeed "$2" "$3" "$4"' rig "$rigSeed" "$rigRun" "$rigMember" \
		"$( printf 'rig-step-one\nrig-step-two' )" > /dev/null 2>&1 )
}
## One supervisor operation, as magic-coordinator runs it in this rig's workspace.
rigSupervise(){ ## its arguments
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" \
		MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_COMMS_READER=off MDAT_COLLECT_THREAD=off \
		MDAT_SPAWN_AGENT=magic-coordinator \
		bash "$rigFn" "$@" 2>&1 )
}
## One CheckList call as the run makes it: the JSON arguments on standard input, the tool's whole answer.
rigCall(){ ## the JSON arguments
	( cd "$rigWs" && printf '%s' "$1" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" HOME="$rigHome" \
		MDAT_SPAWN_SESSION_ID="$rigRun" MDAT_SPAWN_AGENT="$rigMember" \
		bash "$rigHarness" --intern-tool CheckList 2> /dev/null )
}
rigTodo(){ ## content -- one todo item object, as the tool takes it
	printf '{"content":"%s","status":"pending","activeForm":"Doing %s"}' "$1" "$1"
}

echo "-- 1 and 2. the read shows a step as the step's and the seed's item as the parent's --"
rigSeedList RIG-SEEDED-TASK
rigRead="$( rigCall '{}' )"
rigAssert "a step of the routine reads as the step's"      "$( rigItems "$rigRead" | LC_ALL=C grep -c -x -F -- '- [ ] rig-step-one [step]' )" 1
rigAssert "the other step too"                             "$( rigItems "$rigRead" | LC_ALL=C grep -c -x -F -- '- [ ] rig-step-two [step]' )" 1
rigAssert "the seed's item reads as the parent's"          "$( rigItems "$rigRead" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-SEEDED-TASK [parent]' )" 1

echo "-- 3. an item a supervisor added reads as the parent's too --"
rigOut="$( rigSupervise --supervise-checklist-add "$rigRun" --item "RIG-SUPERVISOR-TASK" )"
rigRead="$( rigCall '{}' )"
rigAssert "the add reached the list"                       "$( LC_ALL=C grep -c -x -F -- '- [ ] RIG-SUPERVISOR-TASK' "$rigList" )" 1
rigAssert "and the read shows it as the parent's"          "$( rigItems "$rigRead" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-SUPERVISOR-TASK [parent]' )" 1

echo "-- 4. the run's own item reads with no source, and every other item keeps its own --"
## The whole list is written with the run's own item added, every other item carried as it reads, so this write is not
## the subject of any assertion here: only what a read then shows is.
rigCall "{\"todos\":[$( rigTodo rig-step-one ),$( rigTodo rig-step-two ),$( rigTodo RIG-SEEDED-TASK ),$( rigTodo RIG-SUPERVISOR-TASK ),$( rigTodo RIG-OWN-ITEM )]}" > /dev/null
rigRead="$( rigCall '{}' )"
rigAssert "the run's own item reads with no source"        "$( rigItems "$rigRead" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-OWN-ITEM' )" 1
rigAssert "the routine's two steps read as the step's"     "$( rigItems "$rigRead" | LC_ALL=C grep -c -e '- \[ \] rig-step-one \[step\]$' -e '- \[ \] rig-step-two \[step\]$' )" 2
rigAssert "and both parent items read as the parent's"     "$( rigItems "$rigRead" | LC_ALL=C grep -c -e '- \[ \] RIG-SEEDED-TASK \[parent\]$' -e '- \[ \] RIG-SUPERVISOR-TASK \[parent\]$' )" 2

echo "-- 5. control: the read changes nothing, and a second read says the same --"
rigBefore="$( cat "$rigList" )"
rigFirst="$( rigCall '{}' )"
rigSecond="$( rigCall '{}' )"
rigAssert "the first read and the second say the same"     "$( [ "$rigFirst" = "$rigSecond" ] && printf same || printf differs )" same
rigAssert "and neither changed a line of the list"         "$( [ "$rigBefore" = "$( cat "$rigList" )" ] && printf same || printf differs )" same

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS CHECKLIST SOURCE READ CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_CHECKLIST_SOURCE_READ: OK (%d assertions, offline)\n' "$rigPassCount"
