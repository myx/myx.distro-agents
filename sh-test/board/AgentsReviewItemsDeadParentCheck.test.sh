#!/usr/bin/env bash
## Behavioural check on which review items the advance round is given: the section
## `## review items addressed to advance.routine` of the coordinator's board scan
## (AgentsToolsBoardRoundSections, sh-lib/board/AgentsTools.BoardRoundScan.include), printed by
## AgentsReviewItemsForRoutine advance (sh-lib/board/AgentsTools.ReviewFlow.include). The duty's own
## step 3 says which review items are its work, and each of those must reach it:
##   - an item whose reviewer is magic-coordinator;
##   - an item with no `review-by:` whose parent run is gone -- nobody else will ever settle it;
##   - an item a routine reviews, by its own name.
## An item whose parent run is alive keeps its review with that parent, and an item of the
## human-owner is his: neither is the duty's, and neither is listed. Held here, on a rig store of
## five review items and two parent records, with the scan's own caller as the instrument:
##   1. THE INSTRUMENT. The section is reached at all and lists nothing but its own items: the
##      known positive is the routine's item, which every tree lists, so a missing dead-parent item
##      is a reading and not a section that was never printed.
##   2. THE DEAD PARENT IS LISTED. Its record is open, of this host, and names a run process that is
##      that process no more, so no live run answers for it.
##   3. THE LIVE PARENT IS NOT. Its record names a process of this check's own still running as that
##      session, recorded as its run, so its parent is alive and keeps the review.
##   4. THE COORDINATOR'S ITEM IS, and the human-owner's is not.
##   5. THE ROUTINE'S ITEM IS, exactly as before: its own review-by, its own line.
## Fault 2 of session 4fbfce66 (epic S24.7), whose rule is magic-coordinator.work-duty.routine step 3.
## Offline: the board, the sandbox records and the process list are this rig's own; the live parent
## is a stand-in of this check alone, ended at its end, and no socket is opened.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
rigRig="$rigPkg/sh-test/check-fixtures/board-round-scan.rig.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigFn"
[ -f "$rigRig" ] || rigRefuse "the board round scan rig is missing from the package: $rigRig"
[ -f "$rigPkg/sh-lib/board/AgentsTools.BoardRoundScan.include" ] || rigRefuse "the board round scan include is missing from the package"
[ -f "$rigPkg/sh-lib/board/AgentsTools.ReviewFlow.include" ] || rigRefuse "the review flow include is missing from the package"
command -v ps > /dev/null || rigRefuse "ps is not on PATH"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReviewItemsDeadParentCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigParentEnd ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigHome="$rigTmp/home" rigSkills="$rigTmp/skills"
rigSpawned="$rigWs/.local/agents/spawned"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigSpawned" "$rigData/board/review" "$rigData/board/running" \
	"$rigData/inboxes/magic-coordinator/incoming" "$rigHome" "$rigSkills/magic-coordinator" || rigRefuse "could not create the rig"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nNO_PROXY=*\nWAIT_COLLECT_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## A live parent run of this check's own: a process running as that session id, recorded as the run its
## record names. Ended at the end of the check through the rig's process helper, and only while it is
## still the process this check started.
rigParentPid="" rigParentChild=""
rigParentStart(){ ## session id the stand-in runs as
	bash -c 'sleep 240 ; :' rig-live-parent --session-id "$1" > /dev/null 2>&1 < /dev/null &
	rigParentPid=$!
	rigProcNote "$rigParentPid"
	disown "$rigParentPid" 2> /dev/null || :
	rigParentChild="$( PATH="$rigProcPath" ps -o lstart= -p "$rigParentPid" 2> /dev/null | PATH="$rigProcPath" LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit }' )"
	[ -n "$rigParentChild" ] || rigRefuse "the live parent stand-in did not start, so nothing below would be measured"
}
rigParentEnd(){ rigProcSignalWithChildren TERM $rigParentPid > /dev/null 2>&1 || : ; }
## A parent's spawn record: open, of this host, and naming the run process it was launched as.
rigParentRecord(){ ## folder name, run-process line
	mkdir -p "$rigSpawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: magic-coordinator\nstatus: spawn-started\nrun-process: %s\n---\n\n# rig parent %s\n' \
		"$1" "$1" "$1" "$rigHost" "$2" "$1" > "$rigSpawned/$1/$1.spawn.md"
}
## A review item: its name, the spawn whose parent decides the case, and its own header lines. The item names
## its run, and that run's own record names the parent it reports to and the member that made the call there,
## which is how the caller reads a parent: by the route, not by the item.
rigReview(){ ## item stem, its own run's spawn id, extra header lines
	mkdir -p "$rigSpawned/$2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nhost: %s\nowner: keeper-rig\nstatus: spawn-started\nreports-to: %s\nparent-member: magic-coordinator\n---\n\n# rig child run\n' \
		"$2" "$2" "$rigHost" "${4:-}" > "$rigSpawned/$2/$2.spawn.md"
	printf -- '---\ntype: dispatch\nowner: keeper-rig\nstatus: dispatch-started\nspawn-id: %s\n%s---\n\n# rig review item\n' \
		"$2" "${3:-}" > "$rigData/board/review/$1.md"
}
rigParentStart rig-parent-live
rigParentRecord rig-parent-live "$rigParentPid $rigParentChild"
rigParentRecord rig-parent-dead "999999 Mon_Jan__1_00:00:00_2001"
## The five items of the duty's rule.
rigReview task-rig-dead-parent   rig-child-dead     "" "rig-parent-dead"
rigReview task-rig-live-parent   rig-child-live     "" "rig-parent-live"
rigReview task-rig-coordinator   rig-child-coord    "review-by: magic-coordinator
" "rig-parent-live"
rigReview task-rig-human         rig-child-human    "review-by: human-owner
" "rig-parent-live"
rigReview task-rig-routine       rig-child-routine  "review-by: magic-coordinator.advance.routine
" "rig-parent-live"
## A control that the section is no catch-all: an item outside review is not its business.
mkdir -p "$rigData/board/running"
printf -- '---\ntype: dispatch\nowner: keeper-rig\nstatus: dispatch-started\n---\n\n# rig running item\n' > "$rigData/board/running/task-rig-running.md"

## The scan itself, through its own caller, in the tooling's shell.
rigScan(){
	(
		cd "$rigWs" || exit 1
		env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH=/usr/bin:/bin:/usr/sbin:/sbin MMDAPP="$rigWs" \
			MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_DATA_ROOT="$rigData" \
			MDAT_SKILLSET_ROOT="$rigSkills" MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 MDAT_TEAM_DATA_COMMIT_THREAD=off \
			bash "$rigRig" "$rigFn" magic-coordinator
	) > "$rigTmp/scan.out" 2> "$rigTmp/scan.err"
}
## The section under test, its heading and its own lines only.
rigSection(){
	LC_ALL=C awk '/^## review items addressed to advance.routine$/ { on = 1 ; next } /^## / { on = 0 } on && NF' "$rigTmp/scan.out"
}
rigLists(){ ## item stem -- listed|absent
	rigSection | LC_ALL=C grep -q -F -- "$1" && printf listed || printf absent
}
rigLine(){ ## item stem -- its whole listed line, or nothing
	rigSection | LC_ALL=C awk -v want="$1" 'index( $0, want ) > 0 { print ; exit }'
}
## Whether a line lists that item with exactly that reason. The item's name is the discriminator; the `.md`
## the caller prints after it is the caller's own formatting and is read either way.
rigLineIs(){ ## item stem, the reason in brackets -- yes|no
	rigLine "$1" | LC_ALL=C grep -q -E -x -- "- $1(\.md)? \[$( printf '%s' "$2" | LC_ALL=C sed 's/[][\.*^$/]/\\&/g' )\]" && printf yes || printf no
}

rigScan
rigAssert "the scan printed the review section at all"                       "$( LC_ALL=C grep -c -x -F '## review items addressed to advance.routine' "$rigTmp/scan.out" )" 1
rigAssert "the instrument's known positive, the routine's item, is listed"    "$( rigLists task-rig-routine )" listed
rigAssert "and an item outside review is not this section's business"         "$( rigLists task-rig-running )" absent

rigAssert "an item whose parent run is gone is listed, with its own reason"  "$( rigLineIs task-rig-dead-parent 'no review-by, parent gone' )" yes
rigAssert "an item whose parent run is alive keeps its review with that parent"    "$( rigLists task-rig-live-parent )" absent
rigAssert "an item whose reviewer is magic-coordinator is listed"                  "$( rigLists task-rig-coordinator )" listed
rigAssert "an item of the human-owner is not listed"                               "$( rigLists task-rig-human )" absent
rigAssert "the routine's item keeps its own review-by, on its own line"            "$( rigLineIs task-rig-routine 'review-by: magic-coordinator.advance.routine' )" yes
rigAssert "the coordinator's item keeps its own review-by too"                     "$( rigLineIs task-rig-coordinator 'review-by: magic-coordinator' )" yes
rigAssert "and the section lists three items: the dead parent's, the coordinator's, the routine's" "$( rigSection | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 3
rigAssert "the two it must not list are the live parent's and the human-owner's"   "$( rigSection | LC_ALL=C grep -c -e task-rig-live-parent -e task-rig-human )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REVIEW ITEMS DEAD PARENT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REVIEW_ITEMS_DEAD_PARENT: OK (%d assertions, offline)\n' "$rigPassCount"
