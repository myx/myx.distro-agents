#!/usr/bin/env bash
## Behavioural check on the output floor's reading of a pipe table (S10.24):
## `AgentsOutputStyleCheck.awk` measures the writer's prose and not a table's cells.
## Held:
##   1. a 79-row table, the case the epic names, is clean: no word-cap and no
##      paragraph-gate fault, and the checker passes it;
##   2. the words around a table are still measured, before it and after it, and a
##      sentence over the cap there still holds the send back;
##   3. a semicolon and an over-cap sentence inside cells are cells, not prose;
##   4. the skip is the table's shape alone: the same words carrying no pipe are still
##      measured, a prose line carrying a pipe in a word is measured as before, and a
##      fenced block and a quoted line are skipped as they always were;
##   5. the whole table still reaches one Slack `table` block, built by
##      AgentsSlackBlocksBuild.awk from the same text the checker passed.
## Red recipe: take the pipe-table branch out of scanLine (AgentsOutputStyleCheck.awk),
## and cases 1 and 3 fail, on both fault lines and on the pass.
## Offline: the checker reads stdin and the builder reads stdin. No curl, no network,
## no workspace and no team data.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigChecker="$rigPackage/sh-lib/comms/AgentsOutputStyleCheck.awk"
rigBlocks="$rigPackage/sh-lib/comms/AgentsSlackBlocksBuild.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigChecker" ] || rigRefuse "the checker is not at the origin this workspace resolves: $rigChecker"
[ -f "$rigBlocks" ] || rigRefuse "the block builder is missing from the package: $rigBlocks"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's fixture that makes its folder is missing from the package"
rigTmp="$( rigTempDir AgentsOutputStyleTableCheck )" || rigRefuse "the rig's own folder could not be made"
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The checker's faults for one text: the predicate of each, one a line, space-joined.
rigFaults(){ ## text file
	LC_ALL=C awk -v textGroup=message -f "$rigChecker" < "$1" 2> /dev/null | LC_ALL=C cut -f1 | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
## The checker's exit status for one text.
rigRc(){ ## text file
	LC_ALL=C awk -v textGroup=message -f "$rigChecker" < "$1" > /dev/null 2>&1
	printf '%s' "$?"
}
## A table of <rows> body rows, with a heading row, its delimiter, and a sentence before
## it and after it where those are given.
rigTable(){ ## file, rows, sentence before, sentence after
	local rowNo=0
	{
		[ -z "$3" ] || printf '%s\n\n' "$3"
		printf '| Item | Owner | State |\n|---|---|---|\n'
		while [ "$rowNo" -lt "$2" ] ; do
			rowNo=$(( rowNo + 1 ))
			printf '| Row %s | magic-developer | settled |\n' "$rowNo"
		done
		[ -z "$4" ] || printf '\n%s\n' "$4"
	} > "$1"
}
rigLong='This sentence is deliberately written to run well past the twenty five word cap so that the measurement of the words beside a table can be seen at all.'

echo "-- 1. a 79-row table, the case the epic names --"
rigTable "$rigTmp/t79.md" 79 'The table below is the release checklist for the epic.' 'The table above is the same checklist, and every row of it is settled.'
rigAssert "a 79-row table fires no predicate at all" "$( rigFaults "$rigTmp/t79.md" )" ""
rigAssert "and the checker passes it" "$( rigRc "$rigTmp/t79.md" )" 0

echo "-- 2. the words around a table are still measured --"
rigTable "$rigTmp/before.md" 3 "$rigLong" ''
rigAssert "an over-cap sentence before the table fires word-cap" "$( rigFaults "$rigTmp/before.md" )" "word-cap"
rigAssert "and it still holds the send back" "$( rigRc "$rigTmp/before.md" )" 1
rigTable "$rigTmp/after.md" 3 '' "$rigLong"
rigAssert "an over-cap sentence after the table fires word-cap" "$( rigFaults "$rigTmp/after.md" )" "word-cap"

echo "-- 3. a cell is no prose of the writer's --"
printf '| Kind | Note |\n|---|---|\n| one; two | a cell that runs past the twenty five word cap deliberately so that the measurement of a cell can be seen at all |\n' > "$rigTmp/cells.md"
rigAssert "a semicolon and an over-cap cell fire nothing" "$( rigFaults "$rigTmp/cells.md" )" ""

echo "-- 4. only the table's shape is skipped --"
printf 'one; two | a cell that runs past the twenty five word cap deliberately so that the measurement of a cell can be seen at all\n' > "$rigTmp/nopipe.md"
rigAssert "the same words with no leading pipe are prose, and are measured" "$( rigFaults "$rigTmp/nopipe.md" )" "word-cap semicolon"
printf 'The flag takes one value; the pipe sign is a character in it.\n' > "$rigTmp/pipe.md"
rigAssert "a prose line carrying a pipe in a word is measured as before" "$( rigFaults "$rigTmp/pipe.md" )" "semicolon"
printf '```\n| a | b |\nnot prose; not measured\n```\n' > "$rigTmp/fence.md"
rigAssert "a fenced block is still skipped whole" "$( rigFaults "$rigTmp/fence.md" )" ""
printf '> a quoted line; not the writer of this message\n' > "$rigTmp/quote.md"
rigAssert "a quoted line is still skipped" "$( rigFaults "$rigTmp/quote.md" )" ""

echo "-- 5. the same text still reaches one Slack table block --"
rigBlocksJson="$( LC_ALL=C awk -v mentionMap="" -f "$rigBlocks" < "$rigTmp/t79.md" 2> /dev/null )" || rigBlocksJson=""
rigAssert "the builder makes exactly one table block for the whole table" \
	"$( printf '%s' "$rigBlocksJson" | LC_ALL=C grep -o '"type":"table"' | LC_ALL=C grep -c . )" 1
rigAssert "and the block carries every body row of it, and its heading row" \
	"$( printf '%s' "$rigBlocksJson" | LC_ALL=C grep -o '"text":"settled"' | LC_ALL=C grep -c . ):$( printf '%s' "$rigBlocksJson" | LC_ALL=C grep -o '"text":"State"' | LC_ALL=C grep -c . )" "79:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ OUTPUT STYLE TABLE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'OUTPUT_STYLE_TABLE: OK (%d assertions, offline)\n' "$rigPassCount"
