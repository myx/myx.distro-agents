#!/usr/bin/env bash
## Behavioural check on --intern-op-morning-review-input-scan and its cut-off advance: the three
## sections and nothing else, header lines only (never a body), each section's own cap marked
## `capped`, the caller's own cut-off (default, then stored, never another caller's, a future one
## not trusted), and the scan and the cut-off advance retired as --magic-* operations: the scan is run by
## the spawner (F6.4) and the cut-off is the routine's own state, moved with --update-routine-state.
## running-session-ended is held through the awk directly, with a fixed
## ended-session list, since the rig has no spawn sandbox. Offline: a temp data store,
## skillset root and workspace.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigAwk="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsMorningReviewStateShape.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigAwk" ] || rigRefuse "the state-shape awk is missing: $rigAwk"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsMorningReviewInputScanCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigSkills="$rigTmp/home/.claude/skills"
rigData="$rigTmp/data"
mkdir -p "$rigTmp/ws" "$rigSkills/magic-coordinator" "$rigSkills/magic-librarian" \
	"$rigData/inboxes/magic-coordinator/incoming" "$rigData/inboxes/magic-librarian/incoming"
printf '# magic-coordinator\n' > "$rigSkills/magic-coordinator/SKILL.md"
printf '# magic-librarian\n' > "$rigSkills/magic-librarian/SKILL.md"
for rigState in backlog pending running review blocked parked processed archived retained ; do
	mkdir -p "$rigData/board/$rigState"
done
rigItem(){ ## state, name, header lines
	printf -- '---\n%b---\n\nBODY-SENTINEL never in a scan\n' "$3" > "$rigData/board/$1/$2.md"
}
for rigN in 1 2 3 4 5 ; do
	rigItem blocked "task-rig-noblocker-$rigN" "type: task\nstatus: stuck\n"
done
rigItem blocked task-rig-condition "type: task\ncondition: waits on rig\n"
rigItem blocked task-rig-blockedby "type: task\nblocked-by: task-rig-other\n"
printf 'no frontmatter at all\nBODY-SENTINEL\n' > "$rigData/board/blocked/task-rig-nofm.md"
rigItem parked task-rig-norecheck "type: task\n"
rigItem parked task-rig-recheck "type: task\nrecheck-date: 2026-10-10 00:00 +0000\n"
rigItem review dispatch-rig-noreviewby "status: dispatch-succeeded\n"
rigItem review dispatch-rig-reviewby "review-by: magic-coordinator\n"
rigItem processed task-rig-noprocessedat "status: done\n"
rigItem processed task-rig-processedat "processed-at: 2026-10-01 00:00 +0000\n"
rigItem running task-rig-running "session-id: rig-session-ended\n"
rigItem backlog task-rig-backlog "type: task\n"
## Skillset: 24 changed files and the two SKILL.md, plus one old one, which the cut-off excludes.
for rigN in $( seq 1 24 ) ; do printf 'x\n' > "$rigSkills/magic-librarian/rig-changed-$rigN.md" ; done
printf 'x\n' > "$rigSkills/magic-librarian/rig-old.md"
touch -t 202001010000 "$rigSkills/magic-librarian/rig-old.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRun(){ ## op args...
	( cd "$rigTmp/ws" && env HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigData" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err"
}
rigHas(){ ## fixed string
	LC_ALL=C grep -q -F -- "$1" "$rigTmp/out" && printf yes || printf no
}
rigLine(){ ## line prefix
	LC_ALL=C grep -m1 -F -- "$1" "$rigTmp/out"
}

echo "-- sections and caps --"
rigRun --intern-op-morning-review-input-scan magic-coordinator ; rigRc=$?
[ "$( rigHas '## state shape' )" = yes ] || rigRefuse "the scan printed no state shape, so nothing below is measured: $( grep -m1 ERROR "$rigTmp/err" )"
rigAssert "exit 0, every source read"                 "$rigRc" 0
rigAssert "exactly three sections"                    "$( LC_ALL=C grep -c '^## ' "$rigTmp/out" )" 3
rigAssert "cutoff section"                            "$( rigHas '## cutoff (morning-review, magic-coordinator)' )" yes
rigAssert "changed-files section"                     "$( rigHas '## skillset files changed since cutoff' )" yes
rigAssert "counts per state"                          "$( rigLine 'counts:' )" "counts: backlog 1, pending 0, running 1, review 2, blocked 8, parked 2, processed 2, archived 0, retained 0"
rigAssert "blocked-no-blocker capped at 3"            "$( rigLine 'blocked-no-blocker:' )" "blocked-no-blocker: 6 (capped, 3 shown)"
rigAssert "three blocked samples shown"               "$( LC_ALL=C grep -c '^  blocked/' "$rigTmp/out" )" 3
rigAssert "a blocked item with condition is not flagged" "$( rigHas 'task-rig-condition' )" no
rigAssert "a blocked item with blocked-by is not flagged" "$( rigHas 'task-rig-blockedby' )" no
rigAssert "parked-no-recheck-date"                    "$( rigLine 'parked-no-recheck-date:' )" "parked-no-recheck-date: 1"
rigAssert "review-no-review-by"                       "$( rigLine 'review-no-review-by:' )" "review-no-review-by: 1"
rigAssert "processed-no-processed-at"                 "$( rigLine 'processed-no-processed-at:' )" "processed-no-processed-at: 1"
rigAssert "running-session-ended without a registry"  "$( rigLine 'running-session-ended:' )" "running-session-ended: 0"
rigAssert "header lines shown"                        "$( rigHas '    status: stuck' )" yes
rigAssert "never a body"                              "$( rigHas 'BODY-SENTINEL' )" no
rigAssert "default cut-off when none is stored"       "$( rigHas 'default, 7 days' )" yes
rigAssert "changed files capped at 20"                "$( rigLine 'changed:' )" "changed: 26 (capped, 20 shown)"
rigAssert "twenty file names shown"                   "$( LC_ALL=C grep -c '^magic-[a-z]*/' "$rigTmp/out" )" 20
rigAssert "a file older than the cut-off is not listed" "$( rigHas 'rig-old.md' )" no
rigAssert "output under 6 KB"                         "$( [ "$( wc -c < "$rigTmp/out" )" -lt 6144 ] && echo yes || echo no )" yes
rigNext="$( LC_ALL=C awk '/^next: / { print $2 ; exit }' "$rigTmp/out" )"

echo "-- an item in review that names no reviewer, whose run has a record here --"
## Its review falls to where that run reports to, so it is no shape fault; one whose spawn-id
## names no record still is. The list of runs the scan builds is a scratch file of the workspace,
## gone once the scan is done.
rigItem review dispatch-rig-runreviewed "spawn-id: rig-run-reviewed\n"
rigItem review dispatch-rig-runmissing "spawn-id: rig-run-missing\n"
mkdir -p "$rigTmp/ws/.local/agents/spawned/rig-run-reviewed"
printf -- '---\nsession-id: rig-run-reviewed\nspawn-id: rig-run-reviewed\nowner: magic-librarian\n---\n' > "$rigTmp/ws/.local/agents/spawned/rig-run-reviewed/rig-run-reviewed.spawn.md"
rigRun --intern-op-morning-review-input-scan magic-coordinator ; rigRc=$?
rigAssert "the item whose run has a record is not flagged, the one whose run has none is, and no scratch file is left" \
	"$rigRc:$( rigLine 'review-no-review-by:' ):$( rigHas 'dispatch-rig-runreviewed' ):$( rigHas 'dispatch-rig-runmissing' ):$( ls "$rigTmp/ws/.local/temp" 2> /dev/null | LC_ALL=C grep -c '^mdat-morning-review-runs' )" \
	"0:review-no-review-by: 2:no:yes:0"
rm -f "$rigData/board/review/dispatch-rig-runreviewed.md" "$rigData/board/review/dispatch-rig-runmissing.md"
rm -rf "$rigTmp/ws/.local/agents/spawned/rig-run-reviewed"

echo "-- running-session-ended, through the awk --"
printf 'rig-session-ended\n' > "$rigTmp/ended"
rigAssert "a running item whose session ended is flagged" \
	"$( mrShapeEndedFile="$rigTmp/ended" LC_ALL=C awk -v cap=3 -f "$rigAwk" "$rigData/board/running/task-rig-running.md" | LC_ALL=C grep '^running-session-ended:' )" "running-session-ended: 1"
printf 'rig-session-other\n' > "$rigTmp/ended"
rigAssert "a running item whose session is not ended is not" \
	"$( mrShapeEndedFile="$rigTmp/ended" LC_ALL=C awk -v cap=3 -f "$rigAwk" "$rigData/board/running/task-rig-running.md" | LC_ALL=C grep '^running-session-ended:' )" "running-session-ended: 0"

echo "-- the cut-off is the routine's own state --"
## The scan names the update that moves it: ThisSession's --update-routine-state (the librarian's update through it is held by
## AgentsRoutineStateUpsertCheck), and no --magic-* advance is left.
rigAssert "the scan's next: line names the state update" "$( rigRun --intern-op-morning-review-input-scan magic-coordinator ; LC_ALL=C grep -c -E -- '^next: [0-9]+ -- at close: --update-routine-state --header:upsert:last_reviewed_ts:[0-9]+$' "$rigTmp/out" )" 1
rigRecord="$rigData/inboxes/magic-coordinator/incoming/note-20261008T000000Z-morning-review-state.md"
printf -- '---\ntype: note\nfrom: magic-coordinator\nowner: magic-coordinator\nlast_reviewed_ts: %s\n---\n\nrig\n' "$rigNext" > "$rigRecord"
rigRun --intern-op-morning-review-input-scan magic-coordinator
rigAssert "the next scan reads the stored cut-off"    "$( LC_ALL=C awk '/^since: / { print $2, $NF ; exit }' "$rigTmp/out" )" "$rigNext stored"
rigAssert "nothing changed since then"                "$( rigLine 'changed:' )" "changed: 0"
rigRun --intern-op-morning-review-input-scan magic-librarian
rigAssert "another caller keeps its own cut-off"      "$( rigHas 'default, 7 days' )" yes
printf -- '---\ntype: note\nlast_reviewed_ts: %s\n---\n\nrig\n' "$(( $( date +%s ) + 86400 ))" > "$rigRecord"
rigRun --intern-op-morning-review-input-scan magic-coordinator ; rigRc=$?
rigAssert "a cut-off in the future is no cut-off: said, not trusted" "$rigRc:$( rigHas 'cannot be read, so the changed files are not listed' ):$( rigLine 'since:' )" "2:yes:since: unknown"
rm -f "$rigRecord"

echo "-- callers --"
rigRun --intern-op-morning-review-input-scan magic-devops ; rigRc=$?
rigAssert "a non-executor is refused"                 "$rigRc" 1
rigRun --intern-op-morning-review-input-scan magic-coordinator task-rig-backlog.md ; rigRc=$?
rigAssert "an item name is not a parameter"           "$rigRc" 1

echo "-- the retired --magic-* operations --"
## F6.4: the scan has no --magic-* stub, and the cut-off moves through the routine's state, so neither name is an operation.
rigRun --magic-morning-review-input-scan magic-coordinator ; rigRc=$?
rigAssert "the scan stub is gone"                     "$rigRc:$( LC_ALL=C grep -c -F 'invalid option: --magic-morning-review-input-scan' "$rigTmp/err" )" "1:1"
rigRun --magic-morning-review-state-advance magic-coordinator "$rigNext" ; rigRc=$?
rigAssert "the advance is gone"                       "$rigRc:$( LC_ALL=C grep -c -F 'invalid option: --magic-morning-review-state-advance' "$rigTmp/err" )" "1:1"

echo "-- $rigPassCount passed, $rigFailCount failed --"
[ "$rigFailCount" -eq 0 ]
