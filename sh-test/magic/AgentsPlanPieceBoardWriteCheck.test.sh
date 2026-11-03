#!/usr/bin/env bash
## Behavioural check on S24.5 of the refactorings epic: THE PLAN ROUTINE NAMES THE OPERATION AND THE WRITER THAT PUT
## EACH PLAN PIECE ON THE BOARD, and that operation, run for real, does put the piece there.
## Read over the package's own routine and run against a rig's own board store. Held:
##   1. control: the routine's Closure region is read, and its second step is found
##   2. the hand-off step names `--grooming-create-pending`, and the writer `magic-coordinator`
##   3. control: the step before it names neither, so the reading separates the two steps
##   4. `magic-coordinator` runs that very operation, and the piece lands in `board-pending` as a `task-*` item
##   5. read back through a second path: the item carries its owner, `spawned-by` the plan, `approved-by`, `approved-at`
##   6. and its body is the piece's own text
##   7. control: the same operation run as another member is refused and writes nothing
##   8. control that the check can fail: on a copy whose hand-off step names another operation, the same reading
##      names that other operation, so assertion 2 comes out wrong rather than passing on any text at all
## Offline: the rig's own board store under this workspace's scratch; every call one `env -i` whose child refuses
## to run outside it. Never the live team data.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsItems.fn.sh"
rigRoutine="$rigPackage/skillset/magic-team/magic-team/magic-team.plan.routine.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigRoutine" ] || rigRefuse "the plan routine is not at the origin this workspace resolves: $rigRoutine"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPlanPieceBoardWriteCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
## One numbered step of a region, its own numbering removed, up to the next one.
rigStepText(){ ## routine file, region heading, step number
	LC_ALL=C awk -v wantStep="$2" -v region="$1" '
		$0 == region { inRegion = 1 ; next }
		inRegion && /^# / { exit }
		inRegion && /^[0-9]+\. / {
			if ( taking ) { exit }
			stepNumber = $0 ; sub( /\..*/, "", stepNumber )
			if ( stepNumber + 0 == wantStep + 0 ) { taking = 1 ; print }
			next
		}
		taking { print }
	' "$3"
}
## The closure step that hands an approved piece over, and the words it uses for the operation and the writer.
rigHandOffText(){ ## routine file -- the text of the step that carries `--grooming-create-pending`
	local handOffStep
	for handOffStep in 1 2 3 4 ; do
		rigStepText "# Closure steps" "$handOffStep" "$1"
	done | LC_ALL=C sed -n '/--grooming-create-pending/,$p'
}
rigHandOffOp(){ ## routine file -- the write operation its hand-off step names, or none
	rigHandOffText "$1" | LC_ALL=C grep -o -- '--[a-z][a-z-]*create-[a-z-]*' | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' '
}
rigHandOffWriter(){ ## routine file -- the member its hand-off step names as the writer, or none
	rigHandOffText "$1" | LC_ALL=C grep -c -- 'magic-coordinator' || :
}

rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigData" "$rigSkills/magic-coordinator" "$rigSkills/magic-developer"
for rigMember in magic-coordinator magic-developer ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
done
rigRc=0
rigRun(){ ## result prefix, caller, words... -- rc in rigRc
	local runOut="$1" runAs="$2" ; shift 2
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT="$runAs" RIG_TMP="$rigTmp" RIG_TOOL="$rigTool" \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$RIG_TOOL" "$@"' rig "$@" ) > "$runOut.out" 2> "$runOut.err" < /dev/null
	rigRc=$?
}
rigLoc(){ ## bare item filename -- which board/<state>/ holds it, or not-found
	local locDir
	for locDir in "$rigData"/board/*/ ; do
		[ -f "$locDir$1" ] && { basename "$locDir" ; return 0 ; }
	done
	printf 'not-found'
}
rigField(){ ## item filename, header name -- the value of that frontmatter line, or none
	local fieldFile="$rigData/board/$( rigLoc "$1" )/$1"
	LC_ALL=C awk -v want="$2" '$0 == "---" { if ( ++fm == 2 ) exit ; next } fm == 1 && index( $0, want ": " ) == 1 { print substr( $0, length( want ) + 3 ) ; found = 1 ; exit } END { if ( ! found ) print "none" }' "$fieldFile" 2> /dev/null
}
rigBody(){ ## item filename -- the text under its frontmatter
	local bodyFile="$rigData/board/$( rigLoc "$1" )/$1"
	LC_ALL=C awk '$0 == "---" { if ( ++fm == 2 ) taking = 1 ; next } taking && NF { print }' "$bodyFile" 2> /dev/null
}
rigBoardFiles(){ ## -- how many items the store holds at all
	LC_ALL=C find "$rigData/board" -type f 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' '
}

rigPlanItem="plan-20261103T0700Z-plan.md" rigPieceItem="task-20261103T0701Z-piece-a.md"
rigApprover="magic-coordinator (rig-plan-session, 2026-11-03T07:00:00Z)"

echo "-- 1. control: the routine's Closure region is read, and its second step is found --"
rigStepTwo="$( rigStepText "# Closure steps" 2 "$rigRoutine" )"
rigAssert "the Closure region's second step is named" "$( [ -n "$rigStepTwo" ] && printf found || printf none )" found

echo "-- 2. the hand-off step names the operation and the writer --"
rigAssert "the operation it names to put a piece on the board" "$( rigHandOffOp "$rigRoutine" )" "--grooming-create-pending "
rigAssert "the writer it names is magic-coordinator" "$( rigHandOffWriter "$rigRoutine" )" 1
rigAssert "and it says the item is a task in board-pending" "$( rigHandOffText "$rigRoutine" | LC_ALL=C grep -o -e 'task-\*' -e 'board-pending' | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" 'board-pending task-* '

echo "-- 3. control: the step before it names neither, so the reading separates the two --"
rigAssert "the step before names no create operation" "$( rigStepText "# Closure steps" 1 "$rigRoutine" | LC_ALL=C grep -c -- '--[a-z-]*create' || : )" 0
rigAssert "and names no writer" "$( rigStepText "# Closure steps" 1 "$rigRoutine" | LC_ALL=C grep -c -- 'magic-coordinator' || : )" 0

echo "-- 4. the writer runs that very operation, and the piece lands in board-pending --"
## The operation is taken from the routine's own words, never spelled here as well: a routine that renames it is
## driven by the new name, and one that names an operation the tooling does not hold fails here rather than passing.
rigOp="$( rigHandOffOp "$rigRoutine" | LC_ALL=C awk '{ print $1 }' )"
rigRun "$rigTmp/c1" magic-coordinator "$rigOp" "$rigPieceItem" --owner-header-value magic-developer \
	--header:upsert:spawned-by:"${rigPlanItem%.md}" --header:upsert:approved-by:"$rigApprover" \
	--header:upsert:approved-at:"2026-11-03 09:00 +0200" --upsert-body:'Piece A: the check that proves it.'
rigAssert "the named operation ran as the named writer" "$rigRc" 0
rigAssert "the piece is in board-pending" "$( rigLoc "$rigPieceItem" )" pending

echo "-- 5. read back through a second path: its headers --"
rigRun "$rigTmp/c2" magic-coordinator --get-board-item "$rigPieceItem"
rigAssert "the item reads back" "$rigRc" 0
rigAssert "its type word is task" "$( rigField "$rigPieceItem" type )" task
rigAssert "its owner is the piece's owner" "$( rigField "$rigPieceItem" owner )" magic-developer
rigAssert "it names the plan it came from" "$( rigField "$rigPieceItem" spawned-by )" "${rigPlanItem%.md}"
rigAssert "it carries the approval the plan gave it" "$( rigField "$rigPieceItem" approved-by )" "$rigApprover"
rigAssert "and the moment of that approval" "$( rigField "$rigPieceItem" approved-at )" "2026-11-03 09:00 +0200"

echo "-- 6. and its body is the piece's own text --"
rigAssert "the body reads back as written" "$( rigBody "$rigPieceItem" )" "Piece A: the check that proves it."

echo "-- 7. control: the same operation as another member is refused and writes nothing --"
rigFilesBefore="$( rigBoardFiles )"
rigRun "$rigTmp/c3" magic-developer "$rigOp" task-20261103T0702Z-piece-b.md --owner-header-value magic-developer --upsert-body:'Not mine to make.'
rigAssert "a developer's call is refused" "$( [ "$rigRc" != 0 ] && printf refused || printf allowed )" refused
rigAssert "and the store is as it was" "$( rigBoardFiles )" "$rigFilesBefore"
rigAssert "the refusal names the member that owns the write" "$( LC_ALL=C grep -c -e 'magic-coordinator' "$rigTmp/c3.err" || : )" 1

echo "-- 8. control that the check can fail: a hand-off step naming another operation --"
cp -p "$rigRoutine" "$rigTmp/renamed.md" || rigRefuse "the routine could not be copied for its own control"
LC_ALL=C sed 's/--grooming-create-pending/--upsert-vault-item/' "$rigRoutine" > "$rigTmp/renamed.md"
rigAssert "the same reading on the copy names the other operation" "$( rigHandOffOp "$rigTmp/renamed.md" )" ""
rigAssert "so the assertion above comes out dirty on it, not passing on any text" \
	"$( [ "$( rigHandOffOp "$rigTmp/renamed.md" )" = "--grooming-create-pending " ] && printf passed || printf dirty )" dirty

if [ "$rigFails" -ne 0 ] ; then
	printf '⛔ PLAN PIECE BOARD WRITE CHECK FAILED: %s of %s assertion(s)\n' "$rigFails" "$(( rigPasses + rigFails ))" ; exit 1
fi
printf 'PLAN_PIECE_BOARD_WRITE: OK (%s assertions, offline)\n' "$rigPasses"
