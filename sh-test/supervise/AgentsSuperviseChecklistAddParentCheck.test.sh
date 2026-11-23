#!/usr/bin/env bash
## Behavioural check on the items a supervisor adds to a run's CheckList (`AgentDispatcherTools --supervise-checklist-add`):
## they are items a parent gave the run, so they are marked `parent` (S6.27), and every behaviour that holds for a
## parent's item holds for them. Held:
##   1. the supervisor's add puts its items on the run's list, and each is marked `parent`
##   2. a read of the list shows each of them as the parent's
##   3. a hand back over one of them is refused, and the refusal names it
##   4. an idle wait over one of them is refused, and the refusal names it
##   5. a whole-list rewrite that leaves them out keeps them -- after a read of its own list, which clears what
##      another session added, so what keeps them is their mark and not that file
##   6. control: the run's own item, left out of a write, is dropped, so the keeping is the parent item's alone
## Red before the fix: 1 to 5 fail. The supervisor appends its items and calls no marking function, so they read
## `own` (`sh-lib/supervise/AgentsTools.SuperviseGuide.include`, the add), and every surface above answers them as the
## run's own work: the hand back is sent, and the idle wait goes on to wait.
## Offline: a rig workspace, a fake curl, and a skillset of this rig's own; no network is reached.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPkg="${rigHere%/sh-lib}"
rigFn="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"
rigSessionFn="$rigPkg/sh-scripts/DistroAgentsSession.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigTest="$rigPkg/sh-test"
rigMember="rig-supervised"
rigRun="rig-run-1"
rigThread="CRIGRUN:1793000000.000100"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFn" "$rigSessionFn" "$rigHarness" "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTest/check-fixtures/rig-temp.include.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
## A call of this rig starts the workspace's own on-demand threads (the event-id thread of the comms cache), and a
## thread outlives the check that started it, so every one of them is ended before the tree is removed (T1905Z).
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSuperviseChecklistAddParentCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigSandbox="$rigTmp/sandbox"
rigScen="$rigTmp/scenario"
rigHome="$rigTmp/home"
mkdir -p "$rigSkills/$rigMember" "$rigSkills/magic-coordinator" "$rigSkills/magic-team" "$rigWs/.local/.agents" \
	"$rigWs/.local/agents/spawned/$rigRun" "$rigSandbox" "$rigScen" "$rigTmp/bin" "$rigHome" || exit 1
printf '%s\n' "$rigMember" > "$rigSkills/$rigMember/$rigMember.basic.md"
printf 'magic-coordinator\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigSkills/magic-team/magic-team.basic.md"
## The routine in force names no scan, so an idle wait's answer names the floor alone.
printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: rig\ninvitees: none\nrequires-session-kind: standalone\ninput-scan-def: none\n---\n# rig routine\n' "$rigMember" \
	> "$rigSkills/magic-team/magic-team.rigstandalone.routine.md"
## The run's own record: its list is kept in the folder that holds it (AgentsHarnessCheckListPlace).
printf -- '---\nspawn-id: %s\nsession-id: %s\nroutine: magic-team.rigstandalone.routine.md\nowner: %s\nparent-session-id: none\nsession-thread: %s\nreports-to: none\nstatus: spawn-started\n---\n' \
	"$rigRun" "$rigRun" "$rigMember" "$rigThread" > "$rigWs/.local/agents/spawned/$rigRun/$rigRun.spawn.md"
rigList="$rigWs/.local/agents/spawned/$rigRun/$rigMember.checklist.md"
rigMarks="$rigWs/.local/agents/spawned/$rigRun/$rigMember.checklist-sources.md"
: > "$rigSandbox/$rigRun.harness"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"
## The names registry a send reads, and the two members it names: a hand back that is not refused is posted.
printf '%s\n' 'magic-coordinator 🐭 Magic Vane dispatchr' "$rigMember 🔬 Vera Sharpe bugsniff" > "$rigWs/.local/agents/team-members-names.registry"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## A `timeout` of the rig's own: with none on PATH the harness takes its watchdog branch, which leaves a `sleep`
## behind the check. With this one every hook is bounded and the check leaves nothing running.
printf '#!/bin/sh\nshift\nexec "$@"\n' > "$rigTmp/bin/timeout"
chmod +x "$rigTmp/bin/timeout"
RIG_CURL_LOG="$rigScen/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"
PATH="$rigTmp/bin:/usr/bin:/bin"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## THE MARKER IS NOT THIS CHECK'S TO CHOOSE: any wording that says the item is the parent's is taken.
rigSaysParent(){ LC_ALL=C grep -c -i -E -e 'parent|mandatory|not yours to close' "$1" 2>/dev/null ; }
## One supervisor operation, as magic-coordinator runs it in this rig's workspace.
rigSupervise(){ ## its arguments
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" \
		MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_COMMS_READER=off MDAT_COLLECT_THREAD=off \
		SLACK_BOT_TOKEN=rig-bot-token-TEAM MDAT_SPAWN_AGENT=magic-coordinator \
		bash "$rigFn" "$@" 2>&1 )
}
## One CheckList call as the run makes it.
rigCheck(){ ## the JSON arguments
	( cd "$rigWs" && printf '%s' "$1" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" HOME="$rigHome" \
		MDAT_SPAWN_SESSION_ID="$rigRun" MDAT_SPAWN_AGENT="$rigMember" \
		bash "$rigHarness" --intern-tool CheckList 2> /dev/null )
}
## One hand back as the run makes it: the extra JSON fields, each leading with its own comma.
rigHandback(){ ## the extra JSON fields
	: > "$rigScen/posts" 2>/dev/null || :
	rm -f "$rigScen"/post.* 2>/dev/null || :
	( cd "$rigWs" && printf '{"outcome":"the work is done"%s}' "${1:-}" | \
		env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		RIG_SCENARIO="$rigScen" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SESSION_THREAD="$rigThread" \
		MDAT_SPAWN_SESSION_ID="$rigRun" MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$rigSkills" HOME="$rigHome" \
		bash "$rigHarness" --intern-tool SubagentHandback > "$rigScen/tool.out" 2> /dev/null )
}
rigRefusals(){ LC_ALL=C grep -c '^REFUSED: ' "$rigScen/tool.out" 2>/dev/null ; }
rigRefusal(){ LC_ALL=C sed -n '/^REFUSED: /,$p' "$rigScen/tool.out" 2>/dev/null ; }
rigPosts(){ LC_ALL=C ls "$rigScen"/post.* 2>/dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ; }
## One idle wait as the run makes it: its answer and the requests its store keeps.
rigIdle(){ ## any arguments of the operation
	rm -f "$rigWs/.local/agents/sessions/$rigRun/checkpoint.request" 2>/dev/null || :
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT="$rigMember" \
		MDAT_SPAWN_SESSION_ID="$rigRun" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" \
		bash "$rigSessionFn" --idle-wait "$@" ) > "$rigTmp/out" 2> /dev/null
}
rigItem(){ ## a text -- the list's line for it, or nothing
	[ -f "$rigList" ] || { printf 'no-list' ; return 0 ; }
	LC_ALL=C awk -v want="$1" 'index( $0, want ) { print ; exit ; }' "$rigList"
}

echo "-- 1 and 2. the supervisor's items are the parent's, and the read shows them so --"
rigOut="$( rigSupervise --supervise-checklist-add "$rigRun" --item "RIG-SUPERVISOR-TASK" --item "RIG-REPORT-TASK" )"
rigAssert "the add reaches the run's list"                 "$( rigItem RIG-SUPERVISOR-TASK )" "- [ ] RIG-SUPERVISOR-TASK"
rigAssert "each item it added is marked parent"            "$( LC_ALL=C grep -c -x -F -- "parent	RIG-SUPERVISOR-TASK" "$rigMarks" 2>/dev/null ):$( LC_ALL=C grep -c -x -F -- "parent	RIG-REPORT-TASK" "$rigMarks" 2>/dev/null )" "1:1"
rigAssert "and the read shows each of them as the parent's" "$( rigCheck '{}' | LC_ALL=C grep -c -e '^- \[ \] RIG-SUPERVISOR-TASK \[parent\]$' -e '^- \[ \] RIG-REPORT-TASK \[parent\]$' )" 2

echo "-- 3. a hand back over one of them is refused, and the refusal names it --"
rigHandback ',"checklist_pending_count":2'
rigAssert "the call is refused"                            "$( rigRefusals )" "1"
rigAssert "the refusal names the item"                     "$( rigRefusal | LC_ALL=C grep -c -F -- 'RIG-SUPERVISOR-TASK' )" "1"
rigAssert "and says it is the parent's, not the run's own" "$( rigRefusal | LC_ALL=C grep -c -i -E -e 'parent|mandatory|not yours to close' )" "1"
rigAssert "and nothing was posted"                         "$( rigPosts )" "0"

echo "-- 4. an idle wait over one of them is refused, and the refusal names it --"
rigIdle
rigAssert "the refusal names the item"                     "$( LC_ALL=C grep -c -F -- 'RIG-SUPERVISOR-TASK' "$rigTmp/out" )" "1"
rigAssert "and says it is the parent's, not the run's own" "$( rigSaysParent "$rigTmp/out" )" "1"
rigAssert "and it waits on nothing"                        "$( [ -s "$rigWs/.local/agents/sessions/$rigRun/checkpoint.request" ] && printf waited || printf none )" "none"

echo "-- 5. a whole-list rewrite keeps them, after a read of its own list --"
rigCheck '{}' > /dev/null
rigCheck '{"todos":[{"content":"RIG-OWN-ITEM","status":"pending","activeForm":"Doing the own item"}]}' > /dev/null
rigAssert "nothing is left to be kept for a later write"   "$( [ -e "$rigList.added" ] && printf left || printf none )" none
rigAssert "the supervisor's first item survives the write" "$( rigItem RIG-SUPERVISOR-TASK )" "- [ ] RIG-SUPERVISOR-TASK"
rigAssert "and so does the second"                         "$( rigItem RIG-REPORT-TASK )" "- [ ] RIG-REPORT-TASK"
rigAssert "and each is still shown as the parent's"        "$( rigCheck '{}' | LC_ALL=C grep -c -e '^- \[ \] RIG-SUPERVISOR-TASK \[parent\]$' -e '^- \[ \] RIG-REPORT-TASK \[parent\]$' )" 2

echo "-- 6. control: the run's own item, left out of a write, is dropped --"
rigCheck '{"todos":[{"content":"RIG-SECOND-ITEM","status":"pending","activeForm":"Doing the second item"}]}' > /dev/null
rigAssert "the own item the write left out is gone"        "$( rigItem RIG-OWN-ITEM )" ""
rigAssert "and the one the write carried is there"         "$( rigItem RIG-SECOND-ITEM )" "- [ ] RIG-SECOND-ITEM"


if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SUPERVISE CHECKLIST ADD PARENT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SUPERVISE_CHECKLIST_ADD_PARENT: OK (%d assertions, offline)\n' "$rigPassCount"
