#!/usr/bin/env bash
## Behavioural check on the approval cascade in --intern-op-board-upsert-move-edit: an
## approval-* arriving in board-processed carrying approved-by/approved-at stamps them onto
## each `blocks` item (an item's own values win) and moves a stamped board-blocked item whose
## every blocked-by is processed/archived/retained to board-pending, in the approval move's own commit.
## Approval is iterative: comments, clarifications and rejections with a reason on an open
## approval (same-state edits, moves among non-terminal states) cascade nothing, nor does a
## final denial. Re-running is a no-op; a bad `blocks` target is reported and never fails the
## move. Offline: a temp data root with its own local git repository, no remote.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
rigTmp="$( mktemp -d -t AgentsApprovalCascadeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
mkdir -p "$rigTmp/ws"
for rigState in backlog pending running review blocked parked processed archived retained ; do
	mkdir -p "$rigData/board/$rigState"
done
rigGit(){ env -i HOME="$rigTmp" PATH="/usr/bin:/bin" GIT_CONFIG_NOSYSTEM=1 git -C "$rigData" "$@" ; }
rigGit init -q || rigRefuse "git init failed"
rigGit config user.email rig@example.invalid
rigGit config user.name rig
rigGit config commit.gpgsign false

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigOp(){ ## result file, extra DistroAgentsTools.fn.sh arguments...
	local opOut="$1" ; shift
	env -i HOME="$rigTmp" PATH="/usr/bin:/bin" GIT_CONFIG_NOSYSTEM=1 MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}
rigItem(){ ## state, bare name, type, extra frontmatter lines -- written and committed
	printf -- '---\ntype: %s\nowner: rig\n%s---\n\nrig item\n' "$3" "$4" > "$rigData/board/$1/$2.md"
	rigGit add -- "board/$1/$2.md" && rigGit commit -q -m "rig: $2" -- "board/$1/$2.md"
}
rigLoc(){ ## bare name -- which board/<state>/ holds it, or not-found
	local stateDir
	for stateDir in "$rigData"/board/*/ ; do
		[ -f "$stateDir$1.md" ] && { basename "$stateDir" ; return 0 ; }
	done
	printf 'not-found'
}
rigHas(){ ## bare name, exact frontmatter line -- 1 when the item carries it
	LC_ALL=C grep -c -x -F "$2" "$rigData/board/$( rigLoc "$1" )/$1.md" 2>/dev/null || :
}
rigCount(){ ## bare name, field -- how many lines start with it
	LC_ALL=C grep -c "^$2:" "$rigData/board/$( rigLoc "$1" )/$1.md" 2>/dev/null || :
}
rigCascadeLines(){ LC_ALL=C grep -c 'approval cascade:' "$1" || : ; }
rigApproved=$'approved-by: human-owner (rig-session, 2026-10-07T10:00:00Z)\napproved-at: 2026-10-07 10:00 +0000\n'
rigBy='approved-by: human-owner (rig-session, 2026-10-07T10:00:00Z)'
rigAt='approved-at: 2026-10-07 10:00 +0000'

echo "-- final approve: the approval moves to processed and cascades, in one commit --"
rigItem blocked task-rig-a task $'blocked-by: approval-rig-a\n'
rigItem backlog task-rig-b task ''
rigItem running approval-rig-a approval "${rigApproved}blocks: task-rig-a, task-rig-b"$'\n'
rigOp "$rigTmp/o1" --magic-board-to-processed magic-coordinator approval-rig-a.md --from-state:running
rigAssert "the move succeeds"                              "$( cat "$rigTmp/o1.rc" )" 0
rigAssert "the approval sits in board/processed"           "$( rigLoc approval-rig-a )" processed
rigAssert "the gated item moved to board/pending"          "$( rigLoc task-rig-a )" pending
rigAssert "the gated item carries approved-by"             "$( rigHas task-rig-a "$rigBy" )" 1
rigAssert "the gated item carries approved-at"             "$( rigHas task-rig-a "$rigAt" )" 1
rigAssert "a non-blocked blocks item is stamped"           "$( rigHas task-rig-b "$rigBy" )" 1
rigAssert "a non-blocked blocks item stays where it was"   "$( rigLoc task-rig-b )" backlog
rigAssert "each cascaded step is printed"                  "$( rigCascadeLines "$rigTmp/o1" )" 3
rigAssert "one commit holds the approval and the cascade"  "$( rigGit show --no-renames --name-only --format= HEAD | LC_ALL=C sort | tr '\n' ' ' )" \
	"board/backlog/task-rig-b.md board/blocked/task-rig-a.md board/pending/task-rig-a.md board/processed/approval-rig-a.md board/running/approval-rig-a.md "
rigAssert "the work tree is clean after the commit"        "$( rigGit status --porcelain | wc -l | tr -d ' ' )" 0

echo "-- rerun: the approval arriving in processed again changes nothing --"
rigSumBefore="$( cat "$rigData/board/pending/task-rig-a.md" "$rigData/board/backlog/task-rig-b.md" | cksum )"
rigGit mv board/processed/approval-rig-a.md board/running/approval-rig-a.md && rigGit commit -q -m "rig: back to running"
rigOp "$rigTmp/o2" --intern-op-board-upsert-move-edit processed approval-rig-a.md --from-state:running --context rig
rigAssert "the move succeeds"                              "$( cat "$rigTmp/o2.rc" )" 0
rigAssert "no cascade step is printed"                     "$( rigCascadeLines "$rigTmp/o2" )" 0
rigAssert "the cascaded items are unchanged"               "$( cat "$rigData/board/pending/task-rig-a.md" "$rigData/board/backlog/task-rig-b.md" | cksum )" "$rigSumBefore"

echo "-- iterative approval: comments, clarifications, a rejection with a reason cascade nothing --"
rigItem blocked task-rig-c task $'blocked-by: approval-rig-c\n'
rigItem running approval-rig-c approval $'blocks: task-rig-c\n'
rigOp "$rigTmp/o3a" --intern-op-board-upsert-move-edit running approval-rig-c.md --from-state:running \
	'--header:append:comments:human-owner asks for the cost estimate' --context rig
printf -- '---\ntype: approval\nowner: rig\nblocks: task-rig-c\n%s---\n\nrejected with a reason: rescope first\n' "$rigApproved" \
	| rigOp "$rigTmp/o3b" --intern-op-board-upsert-move-edit running approval-rig-c.md --from-state:running --upsert-from-stdin --context rig
rigOp "$rigTmp/o3c" --intern-op-board-upsert-move-edit review approval-rig-c.md --from-state:running --context rig
rigOp "$rigTmp/o3d" --intern-op-board-upsert-move-edit running approval-rig-c.md --from-state:review --context rig
rigAssert "the comment edit succeeds"                      "$( cat "$rigTmp/o3a.rc" )" 0
rigAssert "the rejection-with-reason edit succeeds"        "$( cat "$rigTmp/o3b.rc" )" 0
rigAssert "the non-terminal moves succeed"                 "$( cat "$rigTmp/o3c.rc" ):$( cat "$rigTmp/o3d.rc" )" 0:0
rigAssert "no cascade step is printed"                     "$( cat "$rigTmp"/o3? | LC_ALL=C grep -c 'approval cascade:' || : )" 0
rigAssert "the gated item stays blocked"                   "$( rigLoc task-rig-c )" blocked
rigAssert "the gated item is not stamped"                  "$( rigCount task-rig-c approved-by )" 0

echo "-- a same-state edit of an already-processed approval cascades nothing --"
rigItem blocked task-rig-p task $'blocked-by: approval-rig-p\n'
rigItem processed approval-rig-p approval "${rigApproved}blocks: task-rig-p"$'\n'
rigOp "$rigTmp/o4" --intern-op-board-upsert-move-edit processed approval-rig-p.md --from-state:processed \
	'--header:append:comments:a late clarification' --context rig
rigAssert "the edit succeeds"                              "$( cat "$rigTmp/o4.rc" )" 0
rigAssert "the gated item stays blocked"                   "$( rigLoc task-rig-p )" blocked
rigAssert "the gated item is not stamped"                  "$( rigCount task-rig-p approved-by )" 0

echo "-- final denial: processed without approved-by/approved-at cascades nothing --"
rigItem blocked task-rig-d task $'blocked-by: approval-rig-d\n'
rigItem running approval-rig-d approval $'blocks: task-rig-d\ndecision: denied\n'
rigOp "$rigTmp/o5" --magic-board-to-processed magic-coordinator approval-rig-d.md --from-state:running
rigAssert "the move succeeds"                              "$( cat "$rigTmp/o5.rc" )" 0
rigAssert "the approval sits in board/processed"           "$( rigLoc approval-rig-d )" processed
rigAssert "no cascade step is printed"                     "$( rigCascadeLines "$rigTmp/o5" )" 0
rigAssert "the gated item stays blocked"                   "$( rigLoc task-rig-d )" blocked
rigAssert "the gated item is not stamped"                  "$( rigCount task-rig-d approved-by )" 0

echo "-- partial blocked-by: stamped, but stays blocked --"
rigItem running task-rig-other task ''
rigItem blocked task-rig-e task $'blocked-by: approval-rig-e, task-rig-other\n'
rigItem running approval-rig-e approval "${rigApproved}blocks: task-rig-e"$'\n'
rigOp "$rigTmp/o6" --magic-board-to-processed magic-coordinator approval-rig-e.md --from-state:running
rigAssert "the move succeeds"                              "$( cat "$rigTmp/o6.rc" )" 0
rigAssert "the gated item stays blocked"                   "$( rigLoc task-rig-e )" blocked
rigAssert "the gated item is stamped"                      "$( rigHas task-rig-e "$rigBy" )" 1
rigAssert "the open blocker is reported"                   "$( LC_ALL=C grep -c 'stays blocked, blocked-by task-rig-other (running)' "$rigTmp/o6" || : )" 1

echo "-- an item's own approval values win --"
rigItem blocked task-rig-f task $'blocked-by: approval-rig-f\napproved-by: magic-architect (other-session, 2026-10-01T09:00:00Z)\n'
rigItem running approval-rig-f approval "${rigApproved}blocks: task-rig-f"$'\n'
rigOp "$rigTmp/o7" --magic-board-to-processed magic-coordinator approval-rig-f.md --from-state:running
rigAssert "the move succeeds"                              "$( cat "$rigTmp/o7.rc" )" 0
rigAssert "the existing approved-by is kept"               "$( rigHas task-rig-f 'approved-by: magic-architect (other-session, 2026-10-01T09:00:00Z)' )" 1
rigAssert "only one approved-by"                           "$( rigCount task-rig-f approved-by )" 1
rigAssert "the missing approved-at is filled"              "$( rigHas task-rig-f "$rigAt" )" 1
rigAssert "the gated item moved to board/pending"          "$( rigLoc task-rig-f )" pending

echo "-- malformed, missing, frontmatter-less blocks targets: reported, the move stands --"
rigItem blocked task-rig-g task $'blocked-by: approval-rig-g\n'
printf 'no frontmatter here\n' > "$rigData/board/backlog/task-rig-nofm.md"
rigItem running approval-rig-g approval "${rigApproved}blocks: bad/name, task-rig-missing, task-rig-nofm, task-rig-g.md, task-rig-g"$'\n'
rigOp "$rigTmp/o8" --magic-board-to-processed magic-coordinator approval-rig-g.md --from-state:running
rigAssert "the move succeeds"                              "$( cat "$rigTmp/o8.rc" )" 0
rigAssert "the approval sits in board/processed"           "$( rigLoc approval-rig-g )" processed
rigAssert "the malformed entries are reported"             "$( LC_ALL=C grep -c 'blocks entry malformed' "$rigTmp/o8" || : )" 2
rigAssert "the missing target is reported"                 "$( LC_ALL=C grep -c 'task-rig-missing not found' "$rigTmp/o8" || : )" 1
rigAssert "the frontmatter-less target is reported"        "$( LC_ALL=C grep -c 'task-rig-nofm.md has no frontmatter' "$rigTmp/o8" || : )" 1
rigAssert "the frontmatter-less target is untouched"       "$( cat "$rigData/board/backlog/task-rig-nofm.md" )" 'no frontmatter here'
rigAssert "the well-formed target still cascades"          "$( rigLoc task-rig-g )" pending

echo "-- a retained blocker counts as resolved, like processed/archived --"
rigItem retained task-rig-ret task ''
rigItem blocked task-rig-h task $'blocked-by: approval-rig-h, task-rig-ret\n'
rigItem running approval-rig-h approval "${rigApproved}blocks: task-rig-h"$'\n'
rigOp "$rigTmp/o9" --magic-board-to-processed magic-coordinator approval-rig-h.md --from-state:running
rigAssert "the move succeeds"                              "$( cat "$rigTmp/o9.rc" )" 0
rigAssert "the gated item moved to board/pending"          "$( rigLoc task-rig-h )" pending

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ APPROVAL CASCADE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'APPROVAL_CASCADE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
