#!/usr/bin/env bash
## Behavioural check on an epic id borne by a numbered list item or by a `### ` heading: AgentDispatcherTools.fn.sh
## --epic-read --feature and --epic-update --set-status, run rather than read, in a rig. The fixture carries the shapes
## the live epic carries: one feature whose open work is a numbered list, and a `### ` heading that bears an id of its own.
## Held:
##   1. CONTROL: a `## ` heading id and a plain list item resolve, so the wider rows below are not passing on nothing.
##   2. --epic-read --feature <id> prints an item and its nested lines alone, and a `### ` heading's own section.
##   3. --epic-update --set-status <id> done closes a list-born item, and a `### `-born one once its items are closed.
##   4. An id borne by both a heading and a list item takes the heading, and stderr names both places.
##   5. REFUSED: an id that stands nowhere, an id that stands twice, a feature that holds an open item.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/AgentDispatcherTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsEpicItemIdCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/temp" "$rigHome" "$rigSkills/magic-coordinator" "$rigWs/todo-sketchpad/backlog"
rigRc=""
rigRun(){ ## result prefix, words... -- rc in rigRc
	local runOut="$1" ; shift
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" MDAT_SPAWN_AGENT=magic-coordinator \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$@"' rig "$rigTool" "$@" ) > "$runOut.out" 2> "$runOut.err" < /dev/null
	rigRc=$?
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" || :
}
rigHasX(){ ## exact line, file -- how many lines of the file equal it
	LC_ALL=C grep -c -x -F -- "$1" "$2" || :
}
## The fixture: S10 holds a plain list, S18 holds a list with a gap in its numbering, and S18.4 is a `### ` heading
## whose own list restarts at 1. S18's item 4 and the heading share one id, as the live epic's do.
rigEpic="$rigWs/todo-sketchpad/backlog/20990101-rig.epic.md"
printf '# Rig epic\n\nSource: none.\nBuilders: keeper-x.\n\n## S10 - Other items\n\nOwner: keeper-x. State: open.\n\n1. First item.\n2. Second item.\n9. Ninth item. Owner: keeper-x.\n\n## S18 - Off-hours\n\nOwner: keeper-x. State: open.\n\nOpen:\n1. The off-duty routine. Owner: keeper-x.\n    - Nested line of item one.\n4. Grow the cached prefix. Owner: keeper-x.\n5. The daily review holds the syntax. Owner: keeper-x.\n\n### S18.4 - The off-hours duty\n\nOwner: keeper-x. State: open.\n\n1. How the off-duty is named. Owner: keeper-x.\n\n## Done\n\n- S1.1: an old close.\n' > "$rigEpic"

echo "-- 1. control: a heading id and a plain list item --"
rigRun "$rigTmp/c1" --epic-read "$rigEpic" --feature S10
rigAssert "a feature heading prints its section, list and all" "$( rigHas 'First item.' "$rigTmp/c1.out" ) $( rigHas 'Ninth item.' "$rigTmp/c1.out" ) $( rigHas 'Off-duty routine' "$rigTmp/c1.out" ) $rigRc" "1 1 0 0"
rigRun "$rigTmp/c2" --epic-read "$rigEpic" --feature S10.9
rigAssert "a plain list item prints alone, with no neighbour" "$( LC_ALL=C tr '\n' '|' < "$rigTmp/c2.out" ) $rigRc" "9. Ninth item. Owner: keeper-x.| 0"

echo "-- 2. --epic-read --feature: the item, and the ### heading --"
rigRun "$rigTmp/r1" --epic-read "$rigEpic" --feature S18.1
rigAssert "a list item prints itself and its nested lines, and no other item" "$( LC_ALL=C tr '\n' '|' < "$rigTmp/r1.out" ) $rigRc" "1. The off-duty routine. Owner: keeper-x.|    - Nested line of item one.| 0"
rigRun "$rigTmp/r2" --epic-read "$rigEpic" --feature S18.5
rigAssert "the last item of the list prints alone" "$( LC_ALL=C tr '\n' '|' < "$rigTmp/r2.out" ) $rigRc" "5. The daily review holds the syntax. Owner: keeper-x.| 0"
rigRun "$rigTmp/r3" --epic-read "$rigEpic" --feature S18.4
rigAssert "an id borne by a ### heading prints that heading's section, not the list item" "$( rigHas 'The off-hours duty' "$rigTmp/r3.out" ) $( rigHas 'How the off-duty is named' "$rigTmp/r3.out" ) $( rigHas 'Grow the cached prefix' "$rigTmp/r3.out" ) $rigRc" "1 1 0 0"
rigAssert "the heading wins, and both places are named on stderr" "$( rigHas 'line 21' "$rigTmp/r3.err" ) $( rigHas 'line 24' "$rigTmp/r3.err" )" "1 1"

echo "-- 3. --epic-update --set-status: a list-born item, and a ###-born feature --"
rigRun "$rigTmp/u1" --epic-update "$rigEpic" --set-status S18.1 done "The routine is live."
rigAssert "the closed item prints its id and the caller's text" "$( cat "$rigTmp/u1.out" | LC_ALL=C tr -d '\n' )" "EPIC: 20990101-rig.epic.md: S18.1 closed: The routine is live."
rigAssert "the item and its nested line leave, its neighbours stand, and ## Done takes one line" \
	"$( rigHas 'The off-duty routine' "$rigEpic" ) $( rigHas 'Nested line of item one' "$rigEpic" ) $( rigHas 'Grow the cached prefix' "$rigEpic" ) $( rigHasX '- S18.1: The routine is live.' "$rigEpic" )" "0 0 1 1"
rigRun "$rigTmp/u2" --epic-update "$rigEpic" --set-status S18.5 done "The syntax is held."
rigAssert "the last item of a list closes on its own id" "$( rigHas 'The daily review holds the syntax' "$rigEpic" ) $( rigHasX '- S18.5: The syntax is held.' "$rigEpic" )" "0 1"
rigRun "$rigTmp/u3" --epic-update "$rigEpic" --set-status S18.4 done ; rigRcU3="$rigRc"
rigAssert "a ### feature holding an item is refused, and the item count is named" "$rigRcU3 $( rigHas 'holds 1 open item(s)' "$rigTmp/u3.err" ) $( rigHas 'The off-hours duty' "$rigEpic" )" "1 1 1"
rigRun "$rigTmp/u4" --epic-update "$rigEpic" --set-status S18.4.1 done "The naming is settled."
rigAssert "an item of a ### feature closes on its own id" "$( rigHas 'How the off-duty is named' "$rigEpic" ) $( rigHasX '- S18.4.1: The naming is settled.' "$rigEpic" )" "0 1"
rigRun "$rigTmp/u5" --epic-update "$rigEpic" --set-status S18.4 done
rigAssert "the ### feature closes once its items are gone, one ## Done line carrying its id" \
	"$( rigHas 'The off-hours duty' "$rigEpic" ) $( rigHasX '- S18.4: Owner: keeper-x. State: open.' "$rigEpic" ) $( rigHas 'Grow the cached prefix' "$rigEpic" )" "0 1 1"

echo "-- 4. refused --"
rigRun "$rigTmp/f1" --epic-read "$rigEpic" --feature S18.9
rigAssert "an id that stands nowhere is refused, naming the item" "$rigRc $( rigHas 'item S18.9 must stand exactly once' "$rigTmp/f1.err" ) $( wc -c < "$rigTmp/f1.out" | tr -d ' ' )" "1 1 0"
printf '# Rig\n\nSource: none.\nBuilders: keeper-x.\n\n## S20 - One\n\nOwner: keeper-x. State: open.\n\n1. An item. Owner: keeper-x.\n\n## S20 - Again\n\nOwner: keeper-x. State: open.\n\n1. Another. Owner: keeper-x.\n\n## Done\n' > "$rigWs/todo-sketchpad/backlog/20990102-dup.epic.md"
rigRun "$rigTmp/f2" --epic-read "$rigWs/todo-sketchpad/backlog/20990102-dup.epic.md" --feature S20
rigAssert "a heading standing twice is refused" "$rigRc $( rigHas 'feature S20 must stand exactly once' "$rigTmp/f2.err" )" "1 1"
rigRun "$rigTmp/f3" --epic-update "$rigEpic" --set-status S10.2 running ; rigRcF3="$rigRc"
rigAssert "an item id takes only done, never a status" "$rigRcF3 $( rigHas 'only done closes an item' "$rigTmp/f3.err" ) $( rigHasX '2. Second item.' "$rigEpic" )" "1 1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ EPIC ITEM ID CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'EPIC_ITEM_ID: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
