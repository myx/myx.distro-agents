#!/usr/bin/env bash
## Behavioural check, the process walk (epic 20261026 S25.20, for the Auth* and RMM2 test cases of S25.12): ONE board item is carried by the real tools from
## ingest to the epic's `## Done`, in one rig, each step starting from the state the step before left. The document is the only object: its state is the board
## folder it sits in, so every step is read back from that folder, and the duty's own scan is asked what it sees at the states it acts on. Held, run and not read:
##   1. INGEST: the coordinator makes a project item and two child task items in board/backlog, the children spawned-by the project. A caller that is no
##      coordinator is refused and nothing is made (the control).
##   2. EPIC: the coordinator lists the folder's epics and reads the feature the item belongs to; the epic validates clean as kind `epic`.
##   3. PLAN: a child moves backlog to pending with its owner header. A move from a state the item is not in is refused and moves nothing (the control).
##   4. DUTY SEES IT: the scan's board digest shows the child under no state while it is in backlog (the control), and under pending once it is there.
##   5. DISPATCH: the child moves pending to running, carrying its session-id; the digest shows it under running and no longer under pending.
##   6. REVIEW: the child moves running to review with its review-by; the digest shows it under review, and the child never dispatched under none.
##   7. ACCEPT: the coordinator moves it review to processed; it has its processed-at stamp, left review, and a second accept of it is refused.
##   8. EPIC DONE: the epic item closes through `--epic-update --set-status <feature>.<n> done <text>`, lands in `## Done`, and the epic still validates clean.
##   9. WHERE IT STOPS: the other child is untouched in backlog, and the project is still open: the walk moves one item, nothing else.
## What the walk does not run: a builder (a model run) and the served handback that ends it. Those are AgentsMagicSpawnSessionCheck, AgentsReviewFlowCheck
## and AgentsHandbackNextCheck. Here the dispatch and the review move are the board operations those runs end in.
## Offline: the rig's own temp tree, every call through one `env -i` whose child refuses to run outside it. Never the live team data or .local/agents.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigScripts="$rigPackage/sh-scripts"
rigScanRig="$rigPackage/sh-test/check-fixtures/board-round-scan.rig.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigNeed in "$rigScripts/DistroAgentsItems.fn.sh" "$rigScripts/DistroAgentsTools.fn.sh" "$rigScripts/AgentDispatcherTools.fn.sh" "$rigScanRig" ; do
	[ -f "$rigNeed" ] || rigRefuse "not at the origin this workspace resolves: $rigNeed"
done
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsProcessFlowWalkCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
		[ -z "${RIG_DEBUG:-}" ] || { head -3 "$rigLastOut.err" 2> /dev/null | cut -c1-300 | sed 's/^/        err:  /' ; }
	fi
}
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigEpics="$rigWs/todo-sketchpad/walk-scratchpad/backlog"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigData/board" "$rigEpics" "$rigSkills/magic-coordinator" "$rigSkills/magic-tester" "$rigSkills/magic-developer"
for rigMember in magic-coordinator magic-tester magic-developer ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
done
rigRc=0 rigLastOut=""
rigRun(){ ## result prefix, caller, tool script name, words... -- rc in rigRc; stdin is the caller's
	local runOut="$1" runAs="$2" runTool="$3" ; shift 3
	rigLastOut="$runOut"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_TOOL="$rigScripts/$runTool.fn.sh" ${runAs:+MDAT_SPAWN_AGENT="$runAs"} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$RIG_TOOL" "$@"' rig "$@" ) > "$runOut.out" 2> "$runOut.err"
	rigRc=$?
}
rigScan(){ ## result file -- the board sections of the work-duty's scan, as the coordinator, in the rig
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=magic-coordinator RIG_TMP="$rigTmp" \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$@"' rig "$rigScanRig" "$rigScripts/DistroAgentsTools.fn.sh" magic-coordinator ) > "$1" 2> "$1.err" < /dev/null
}
rigLoc(){ ## bare item filename -- which board/<state>/ holds it, or not-found
	local locDir
	for locDir in "$rigData"/board/*/ ; do
		[ -f "$locDir$1" ] && { basename "$locDir" ; return 0 ; }
	done
	printf 'not-found'
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" 2> /dev/null || :
}
rigSeen(){ ## scan file, item filename -- the state folder the scan's board digest shows the item under, or none
	LC_ALL=C awk -v want="$2" '/^## [a-z]+\// { name = substr( $0, 4 ) ; split( name, part, "/" ) ; if ( part[2] == want ) { print part[1] ; found = 1 ; exit } } END { if ( ! found ) print "none" }' "$1" 2> /dev/null
}
rigField(){ ## item filename, header name -- the value of that frontmatter line, or none
	local fieldFile="$rigData/board/$( rigLoc "$1" )/$1"
	LC_ALL=C awk -v want="$2" '$0 == "---" { if ( ++fm == 2 ) exit ; next } fm == 1 && index( $0, want ": " ) == 1 { print substr( $0, length( want ) + 3 ) ; found = 1 ; exit } END { if ( ! found ) print "none" }' "$fieldFile" 2> /dev/null
}

rigProject="project-20261102T2300Z-walk.md" rigChildA="task-20261102T2301Z-walk-a.md" rigChildB="task-20261102T2302Z-walk-b.md"

echo "-- 1. ingest: a project and two children in the backlog; a caller that is no coordinator is refused --"
rigRun "$rigTmp/i0" magic-developer DistroAgentsItems --grooming-create-backlog --team-member magic-developer "$rigProject" --owner-header-value magic-developer --upsert-body:'The walk.'
rigAssert "a developer's create is refused, rc non-zero, and nothing is made" "$( [ "$rigRc" != 0 ] && printf refused || printf allowed ):$( rigLoc "$rigProject" )" "refused:not-found"
rigRun "$rigTmp/i1" magic-coordinator DistroAgentsItems --grooming-create-backlog --team-member magic-coordinator "$rigProject" --owner-header-value magic-coordinator --upsert-body:'The walk: one item from ingest to review.'
rigAssert "the project is made in the backlog" "$rigRc:$( rigLoc "$rigProject" )" "0:backlog"
rigRun "$rigTmp/i2" magic-coordinator DistroAgentsItems --grooming-create-backlog --team-member magic-coordinator "$rigChildA" --owner-header-value magic-developer --header:upsert:spawned-by:"${rigProject%.md}" --upsert-body:'Child A.'
rigRun "$rigTmp/i3" magic-coordinator DistroAgentsItems --grooming-create-backlog --team-member magic-coordinator "$rigChildB" --owner-header-value magic-developer --header:upsert:spawned-by:"${rigProject%.md}" --upsert-body:'Child B.'
rigAssert "both children are in the backlog" "$( rigLoc "$rigChildA" ) $( rigLoc "$rigChildB" )" "backlog backlog"
rigAssert "each child names its project" "$( rigField "$rigChildA" spawned-by ) $( rigField "$rigChildB" spawned-by )" "${rigProject%.md} ${rigProject%.md}"

echo "-- 2. the epic: listed, read by feature, valid --"
printf '# 20261102 walk: the epic\n\nSource: `walk.sketch.md`. Each item names its sketch section.\n\nBuilders: our team members.\n\n## Decisions\n\n- Walk rule.\n\n## S1 - The walk\n\n1. The walked item. Owner: magic-developer.\n2. The other item. Owner: magic-developer.\n\n## Done\n\n- S0.1: an old close.\n' > "$rigEpics/20261102-walk.epic.md"
rigRun "$rigTmp/e1" magic-coordinator AgentDispatcherTools --epic-list --team-member magic-coordinator "$rigEpics"
rigAssert "the epic folder lists the epic" "$rigRc:$( rigHas '20261102-walk.epic.md' "$rigTmp/e1.out" )" "0:1"
rigRun "$rigTmp/e2" magic-coordinator AgentDispatcherTools --epic-read --team-member magic-coordinator "$rigEpics/20261102-walk.epic.md" --feature S1
rigAssert "the feature reads, with the walked item" "$rigRc:$( rigHas 'The walked item' "$rigTmp/e2.out" )" "0:1"
rigRun "$rigTmp/e3" magic-coordinator DistroAgentsTools --intern-doc-validate epic "$rigEpics/20261102-walk.epic.md"
rigAssert "the epic validates clean as kind epic" "$rigRc:$( wc -c < "$rigTmp/e3.out" | tr -d ' ' )" "0:0"

echo "-- 3. plan: backlog to pending --"
rigScan "$rigTmp/s0"
rigRun "$rigTmp/p0" magic-coordinator DistroAgentsItems --grooming-to-pending --team-member magic-coordinator "$rigChildA" --from-state:review --owner-header-value magic-coordinator
rigAssert "a move from a state the item is not in is refused and moves nothing" "$( [ "$rigRc" != 0 ] && printf refused || printf allowed ):$( rigLoc "$rigChildA" )" "refused:backlog"
rigRun "$rigTmp/p1" magic-coordinator DistroAgentsItems --grooming-to-pending --team-member magic-coordinator "$rigChildA" --from-state:backlog --owner-header-value magic-developer
rigAssert "child A is in pending and left the backlog" "$rigRc:$( rigLoc "$rigChildA" )" "0:pending"
rigScan "$rigTmp/s1"

echo "-- 4. the duty sees it: no state before the move (the control), pending after --"
rigAssert "the scan ran and printed its board digest" "$( [ "$( rigHas '## board digest' "$rigTmp/s1" )" = 1 ] && printf yes || printf no )" yes
rigAssert "control: child A in the backlog is shown under no state" "$( rigSeen "$rigTmp/s0" "$rigChildA" )" none
rigAssert "child A is shown under pending" "$( rigSeen "$rigTmp/s1" "$rigChildA" )" pending
rigAssert "child B, still in the backlog, is shown under none" "$( rigSeen "$rigTmp/s1" "$rigChildB" )" none

echo "-- 5. dispatch: pending to running --"
rigRun "$rigTmp/d1" magic-coordinator DistroAgentsTools --intern-op-board-upsert-move-edit running "$rigChildA" --from-state:pending --header:upsert:session-id:rig-session-walk --context rig
rigAssert "child A is running and carries its session-id" "$rigRc:$( rigLoc "$rigChildA" ):$( rigField "$rigChildA" session-id )" "0:running:rig-session-walk"
rigScan "$rigTmp/s2"
rigAssert "the digest shows child A under running, not pending" "$( rigSeen "$rigTmp/s2" "$rigChildA" )" running

echo "-- 6. review: running to review --"
rigRun "$rigTmp/r1" magic-coordinator DistroAgentsTools --intern-op-board-upsert-move-edit review "$rigChildA" --from-state:running --header:upsert:review-by:magic-coordinator --context rig
rigAssert "child A is in review with its review-by" "$rigRc:$( rigLoc "$rigChildA" ):$( rigField "$rigChildA" review-by )" "0:review:magic-coordinator"
rigScan "$rigTmp/s3"
rigAssert "the digest shows child A under review" "$( rigSeen "$rigTmp/s3" "$rigChildA" )" review
rigAssert "child B, never dispatched, is shown under none" "$( rigSeen "$rigTmp/s3" "$rigChildB" )" none

echo "-- 7. accept: review to processed, once --"
rigRun "$rigTmp/a1" magic-coordinator DistroAgentsItems --move-to-processed --team-member magic-coordinator "$rigChildA" --from-state:review
rigAssert "child A is processed" "$rigRc:$( rigLoc "$rigChildA" )" "0:processed"
rigAssert "it has its processed-at stamp" "$( [ "$( rigField "$rigChildA" processed-at )" != none ] && printf yes || printf no )" yes
rigRun "$rigTmp/a2" magic-coordinator DistroAgentsItems --move-to-processed --team-member magic-coordinator "$rigChildA" --from-state:review
rigAssert "a second accept is refused and the item stays processed" "$( [ "$rigRc" != 0 ] && printf refused || printf allowed ):$( rigLoc "$rigChildA" )" "refused:processed"

echo "-- 8. the epic item closes into ## Done --"
rigRun "$rigTmp/c1" magic-coordinator AgentDispatcherTools --epic-update --team-member magic-coordinator "$rigEpics/20261102-walk.epic.md" --set-status S1.1 done "The walked item holds: ingest, plan, dispatch, review and accept ran."
rigAssert "the update ran" "$rigRc" 0
rigAssert "the item left the feature and ## Done holds the caller's line" "$( rigHas 'The walked item. Owner' "$rigEpics/20261102-walk.epic.md" ) $( rigHas '- S1.1: The walked item holds: ingest, plan, dispatch, review and accept ran.' "$rigEpics/20261102-walk.epic.md" )" "0 1"
rigRun "$rigTmp/c2" magic-coordinator DistroAgentsTools --intern-doc-validate epic "$rigEpics/20261102-walk.epic.md"
rigAssert "the epic still validates clean" "$rigRc:$( wc -c < "$rigTmp/c2.out" | tr -d ' ' )" "0:0"

echo "-- 9. where it stops --"
rigAssert "child B is untouched in the backlog" "$( rigLoc "$rigChildB" )" backlog
rigAssert "the project is still in the backlog" "$( rigLoc "$rigProject" )" backlog

if [ "$rigFails" -gt 0 ] ; then
	echo "⛔ PROCESS FLOW WALK CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	exit 1
fi
printf 'PROCESS_FLOW_WALK: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
