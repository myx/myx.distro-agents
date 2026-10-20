#!/usr/bin/env bash
## Behavioural check on F5.7 of the refactorings epic, the document self-check: the rule set `document` of the ONE validator,
## `--intern-doc-validate document <file|--from-stdin>` (sh-lib/team-data/AgentsTools.InternDocValidate.include). It reads one
## document in one pass, needs no store, no model and no decision, and prints one row for each fault,
## `<file>:<line>: report-<rule>: <text>`. Its rules arrive REPORTING: a row is said and nothing is refused (exit 0).
## Held:
##   1. the kind is built in the one validator (the refusal of an unknown kind names `document` beside `routine`), reads a clean
##      document with no row, refuses nothing where it reports, and is read-only
##   2. a citation that resolves to nothing: a file (absolute, or relative from the document's tree, the package or the
##      skillset), a board item, a workspace or a place name. What is no citation is not read: a name in a code fence, a
##      sandbox path, a placeholder, a glob, a bare name
##   3. a cited rule name that does not resolve in the file it names: the NAME is checked, never the line number; `:N` alone
##      keeps the file of the citation before it; a file that is not there is a citation row, not a rule row
##   4. a stated count against the real one: a count that introduces a list against the items of that list; `all N stages`
##      against the stage headings present
##   5. arithmetic that does not close: an equation, and a table with a Total row
##   6. a heading twice with different content, in one place
##   7. items out of their own declared order: a numbered list, and headings that carry an id
##   8. a statement a later statement replaces: the same sentence with other numbers
##   9. the sentence splitter: a sentence ending in a bold run at the end of its line, and a list item, are not joined to the next
##  10. a pure rule set: the same document gives the same rows, --from-stdin gives the same rows, no store is needed
##  11. the controls: the epic with one planted fault of each class gives exactly those rows more than the epic gives;
##      the routine set of the package gives none
## Red before F5.7: the kind `document` is not built (every case fails).
## Offline: rig files only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDocSelfCheckCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigD="$rigTmp/docs"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" "$rigSkills/magic-team" "$rigData/board/running" "$rigD/sub"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## What the citations are checked against: files, a board item, two places.
printf 'real\n' > "$rigD/real.txt" ; printf '# real\n' > "$rigD/real.md"
printf -- '- **The root is posted once** and nothing else.\n- **`AgentsToolsFoo`** is a function.\n' > "$rigD/cited.md"
printf '#!/usr/bin/env bash\nAgentsToolsFoo(){ :; }\n' > "$rigD/cited.sh"
printf -- '---\ntype: task\n---\n# Task: real\n' > "$rigData/board/running/task-20261001T1000Z-real-item.md"
printf 'ws-rig-known\tworkspace\tread-write\t%s\towner\n' "$rigWs" > "$rigWs/.local/agents/directories.registry"

rigDataEnv=( "MDAT_DATA_ROOT=$rigData" )
rigRun(){ ## kind, file|--from-stdin -- rc in rigRc, the rows in $rigTmp/said.out, the other stream in $rigTmp/said.err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" USER=rigacct PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" ${rigDataEnv[@]+"${rigDataEnv[@]}"} bash "$rigTool" --intern-doc-validate "$1" "$2" ) > "$rigTmp/said.out" 2> "$rigTmp/said.err" < "${rigStdin:-/dev/null}" || rigRc=$?
}
rigRowsAt(){ ## rule -- the lines of the rows of that rule in the last run, comma-separated, in the order printed
	LC_ALL=C sed -n -E "s/^.*:([0-9]+): $1: .*\$/\\1/p" "$rigTmp/said.out" | LC_ALL=C tr '\n' ',' | LC_ALL=C sed 's/,$//'
}
rigRowCount(){ LC_ALL=C grep -c -E '^.*:[0-9]+: report-[a-z-]+: ' "$rigTmp/said.out" || : ; }
rigDoc(){ ## name, lines... -- the document $rigD/<name>.md, one argument a line
	local docName="$1" ; shift
	printf '%s\n' "$@" > "$rigD/$docName.md"
}
rigCheck(){ ## name -- one run of the document of that name
	rigRun document "$rigD/$1.md"
}

echo "-- 1. the kind is built; a clean document has no row; rows refuse nothing; read-only --"
rigRun nosuchkind "$rigD/real.md"
rigAssert "an unknown kind is refused, naming document beside routine" \
	"$rigRc:$( LC_ALL=C grep -c -F 'document' "$rigTmp/said.err" ):$( LC_ALL=C grep -c -F 'routine' "$rigTmp/said.err" )" "1:1:1"
rigDoc clean \
	'# A clean document' '' \
	"The file \`$rigD/real.txt\` is there." '' \
	'Three things:' '' '- a' '- b' '- c' '' \
	'The set is 40 + 7 = 47 files, and the table closes:' '' \
	'| kind | n |' '|---|---|' '| a | 1 |' '| b | 2 |' '| Total | 3 |' '' \
	'1. one' '2. two' '3. three'
rigCheck clean
rigAssert "a clean document: exit 0, no row" "$rigRc:$( rigRowCount )" "0:0"
rigDoc faulty '# Faulty' '' "A gone file: \`$rigD/gone.md\`."
rigCheck faulty
rigAssert "a document with a fault: the row is said, exit 0, the rule name starts report-" \
	"$rigRc:$( rigRowCount ):$( LC_ALL=C grep -c -E '^[^ ]*:3: report-citation: ' "$rigTmp/said.out" )" "0:1:1"
rigAssert "a row names the file as it was given, the line, the rule and the text" \
	"$( LC_ALL=C grep -c -F "$rigD/faulty.md:3: report-citation: " "$rigTmp/said.out" )" "1"
rigSum="$( cksum < "$rigD/faulty.md" )"
rigCheck faulty
rigAssert "read-only: the document is unchanged" "$( cksum < "$rigD/faulty.md" )" "$rigSum"

echo "-- 2. a citation that resolves to nothing --"
rigDoc cites \
	'# Citations' \
	'' \
	"The file \`$rigD/real.txt\` is there, and \`$rigD/gone.md\` is not." \
	'A relative `sh-lib/team-data/AgentsTools.InternDocValidate.include` is in the package; `sh-lib/nowhere/Gone.include` is not.' \
	"A path from the document's own tree, \`docs/real.md\`, resolves; \`docs/gone.md\` does not." \
	'Not citations: `input/input-scan.md`, `.local/agents/x.md`, `docs/<name>.md`, `docs/*.md`, `$MMDAPP/x.md`, `~/x.md`.' \
	'A bare name is not checked: `gone.md`.' \
	'Board: `task-20261001T1000Z-real-item` is on it, `task-20261001T1000Z-no-such-item` is not.' \
	'Places: `ws-rig-known` is registered, `ws-rig-unknown` is not; `--member-directory-path ws-rig-nope` names none.' \
	'The skillset root: `magic-team/magic-team.armed.md` is there, `magic-team/magic-team.gone.md` is not.' \
	'' '```' "\`$rigD/in-a-fence.md\` and \`task-20261001T1000Z-in-fence\` and \`ws-in-fence\`" '```'
rigCheck cites
rigAssert "a file, a relative path, a board item, two places and a skillset path that are not there: one row each, at their line" \
	"$( rigRowsAt report-citation )" "3,4,5,8,9,9,10"
rigAssert "the row names what is not there" \
	"$( LC_ALL=C grep -c -F -e "$rigD/gone.md" -e 'sh-lib/nowhere/Gone.include' -e 'docs/gone.md' -e 'task-20261001T1000Z-no-such-item' -e 'ws-rig-unknown' -e 'ws-rig-nope' -e 'magic-team/magic-team.gone.md' "$rigTmp/said.out" )" "7"
rigAssert "nothing else is a fault: no other rule fires on this document" "$( rigRowCount )" "7"
rigDoc citesAnc '# Ancestor' '' 'A tree path: `docs/sub/other.md`.'
printf '# other\n' > "$rigD/sub/other.md"
rigCheck citesAnc
rigAssert "a path that resolves from an ancestor of the document's folder is there" "$( rigRowCount )" "0"

echo "-- 3. a cited rule name that does not resolve in the file it names --"
rigDoc rules \
	'# Rule names' \
	'' \
	"**The root is posted once** (\`$rigD/cited.md:122\`) is there, whatever the line." \
	"**A rule that is gone** (\`$rigD/cited.md:5\`) is not." \
	"**The root is posted once** (\`$rigD/cited.md:9999\`) moved, and the name is what is checked." \
	"**The root is posted once** (\`$rigD/cited.md:1\`) and **Absent second rule** (\`:2\`) are in one file." \
	"**\`AgentsToolsFoo\`** (\`$rigD/cited.sh:2\`) names a function." \
	'**Some rule** (`NoSuchRuleFile.md:3`) names a file nowhere.' \
	"| **The root is posted once** (\`$rigD/cited.md:3\`) | a table cell |" \
	"| **Gone in a table** (\`$rigD/cited.md:3\`) | a table cell |"
rigCheck rules
rigAssert "a name that is absent, an absent name after a bare :N, an absent name in a table cell: a rule row each" \
	"$( rigRowsAt report-rule-name )" "4,6,10"
rigAssert "the row names the rule and the file" \
	"$( LC_ALL=C grep -c -F -e 'A rule that is gone' -e 'Absent second rule' -e 'Gone in a table' "$rigTmp/said.out" ):$( LC_ALL=C grep -c -F "$rigD/cited.md" "$rigTmp/said.out" )" "3:3"
rigAssert "a rule cited from a file that is not there is a citation row, and not a rule row" \
	"$( rigRowsAt report-citation )" "8"

echo "-- 4. a stated count against the real one --"
rigDoc counts \
	'# S1 — one' \
	'' \
	'Three things:' \
	'' \
	'- a' '- b' '- c' \
	'' \
	'**Four checks run in order:**' \
	'' \
	'1. one' '2. two' '3. three' \
	'' \
	'Two of these are noted:' \
	'- x' '- y' '- z' \
	'' \
	'The two files to read:' \
	'' \
	'- f1' '- f2' '- f3' \
	'' \
	'# S2 — two' \
	'' \
	'It builds all three stages.' \
	'It builds all two stages.' \
	'' \
	'Three rows are kept:' \
	'' \
	'| k | v |' '|---|---|' '| a | x |' '| b | y |'
rigCheck counts
rigAssert "a count that introduces a list, and all N stages, against what is present: a row at each, not at the controls" \
	"$( rigRowsAt report-count )" "9,20,28,31"
rigAssert "the row says the stated count and the real one" \
	"$( LC_ALL=C grep -c -E 'states four.* 3 |states two.* 3 |states three stages.* 2|states three .*2 ' "$rigTmp/said.out" )" "4"
rigAssert "no other rule fires on this document" "$( rigRowCount )" "4"

echo "-- 5. arithmetic that does not close --"
rigDoc sums \
	'# Sums' \
	'' \
	'The set is 40 + 7 = 47 files.' \
	'The other set is 40 + 7 = 48 files.' \
	'Also 47 = 40 + 7 is the same, and 48 = 40 + 7 is not.' \
	'' \
	'| kind | n | m |' '|---|---|---|' '| a | 1 | 5 |' '| b | 2 | 6 |' '| **Total** | 3 | 12 |' \
	'' \
	'| kind | n | note |' '|---|---|---|' '| a | 1 | x |' '| Total | 1 | y |'
rigCheck sums
rigAssert "an equation that does not close, a second one on a line, a Total row that does not add: a row each" \
	"$( rigRowsAt report-arithmetic )" "4,5,11"
rigAssert "no other rule fires on this document" "$( rigRowCount )" "3"

echo "-- 6. a heading twice with different content --"
rigDoc heads \
	'# Doc' \
	'## Alpha' \
	'text one' \
	'## Beta' \
	'## Alpha' \
	'text two' \
	'## Gamma' \
	'### Notes' \
	'x' \
	'## Delta' \
	'### Notes' \
	'y' \
	'## Same' \
	'same body' \
	'## Same' \
	'same body'
rigCheck heads
rigAssert "the same heading in one place with other content: a row at the second; the same text under another parent and the same content twice: none" \
	"$( rigRowsAt report-heading )" "5"
rigAssert "the row names the first" "$( LC_ALL=C grep -c -E ':5: report-heading: .*line 2' "$rigTmp/said.out" )" "1"

echo "-- 7. items out of their own declared order --"
rigDoc order \
	'# Doc' \
	'' \
	'1. one' '2. two' '4. four' '3. three' '5. five' \
	'' \
	'Then a paragraph ends the list.' \
	'' \
	'1. restarts' '2. fine' '   1. nested restarts' '   2. nested fine' '3. outer continues' \
	'' \
	'# S2 — two' \
	'# S1 — one' \
	'## F2.2 — b' \
	'## F2.1 — a' \
	'## F2.3 — c' \
	'# S3 — three'
rigCheck order
rigAssert "an item numbered below the one before it, and ids that descend, in one place: a row at each" \
	"$( rigRowsAt report-order )" "6,18,20"
rigAssert "no other rule fires on this document" "$( rigRowCount )" "3"

echo "-- 8. a statement a later statement replaces --"
rigDoc replaced \
	'# Replaced' \
	'' \
	'The routine set holds 47 files and is read once.' \
	'Something else is said here.' \
	'The routine set holds 49 files and is read once.' \
	'The set holds 47 files and is read once.' \
	'A sentence with no number repeats itself.' \
	'A sentence with no number repeats itself.'
rigCheck replaced
rigAssert "the same sentence with another number later: a row at the earlier one; another sentence, and a sentence repeated whole: none" \
	"$( rigRowsAt report-replaced )" "3"
rigAssert "the row names the later line" "$( LC_ALL=C grep -c -E ':3: report-replaced: .*line 5' "$rigTmp/said.out" )" "1"

echo "-- 9. the splitter: the end of a bold run, and the end of a line --"
rigDoc split \
	'# Splitter' \
	'' \
	'The routine set holds **47 files**' \
	'Another sentence follows here.' \
	'' \
	'The routine set holds **49 files**' \
	'A different sentence follows here.' \
	'' \
	'- The kept set holds 47 items and ends with no stop' \
	'- The kept set holds 49 items and ends with no stop'
rigCheck split
rigAssert "a sentence ending in a bold run at the end of its line is not joined to the next, and a list item with no stop ends at its line" \
	"$( rigRowsAt report-replaced )" "3,9"
rigDoc splitMid \
	'# Splitter' \
	'' \
	'**The count of the kept set is 3 here** The routine set holds 47 files. **The count of the kept set is 4 here** The routine set keeps 49 files.'
rigCheck splitMid
rigAssert "a bold run that is a sentence of its own ends it, with no full stop: the sentences after it are read apart" \
	"$( rigRowsAt report-replaced )" "3"

echo "-- 10. a pure rule set --"
rigCheck rules
cp "$rigTmp/said.out" "$rigTmp/first.out"
rigCheck rules
rigAssert "the same document gives the same rows" "$( cmp -s "$rigTmp/said.out" "$rigTmp/first.out" && echo same || echo differ )" "same"
rigStdin="$rigD/rules.md" rigRun document --from-stdin
LC_ALL=C sed 's#^[^ ]*:\([0-9]*\): #\1: #' "$rigTmp/said.out" > "$rigTmp/stdin.rows"
LC_ALL=C sed 's#^[^ ]*:\([0-9]*\): #\1: #' "$rigTmp/first.out" > "$rigTmp/file.rows"
rigAssert "--from-stdin gives the same rows for the same text, shown as <stdin>" "$( cmp -s "$rigTmp/stdin.rows" "$rigTmp/file.rows" && echo same || echo differ ):$( LC_ALL=C grep -c '^<stdin>:' "$rigTmp/said.out" )" "same:4"
rigDataEnv=()
rigCheck cites
rigAssert "with no store at all, the board names are not read, and nothing else is lost" "$( rigRowsAt report-citation )" "3,4,5,9,9,10"
rigDataEnv=( "MDAT_DATA_ROOT=$rigData" )

echo "-- 11. the controls --"
rigEpic="${MMDAPP:?⛔ ERROR: MMDAPP is not set}/source/myx/todo-sketchpad/magic-team-scratchpad/backlog/20261016-refactorings.epic.md"
if [ -f "$rigEpic" ] ; then
	cp "$rigEpic" "$rigD/epic.md"
	rigCheck epic
	rigEpicRc="$rigRc" rigEpicRows="$( rigRowCount )" ; cp "$rigTmp/said.out" "$rigTmp/epic.before"
	printf '%s\n' \
		'' '# Planted faults' '' \
		"A gone file: \`$rigD/planted-gone.md\`." '' \
		"**A planted rule that is gone** (\`$rigD/cited.md:5\`) is not there." '' \
		'Seven planted things:' '' '- a' '- b' '' \
		'A planted sum is 1 + 1 = 3 files.' '' \
		'## Planted heading' 'one' '## Planted heading' 'two' '' \
		'1. a' '2. b' '1. c' '' \
		'The planted set holds 11 files and is read once.' 'The planted set holds 12 files and is read once.' >> "$rigD/epic.md"
	rigCheck epic
	LC_ALL=C sed 's#^[^ ]*:[0-9]*: ##' "$rigTmp/epic.before" | LC_ALL=C sort > "$rigTmp/epic.before.rows"
	LC_ALL=C sed 's#^[^ ]*:[0-9]*: ##' "$rigTmp/said.out" | LC_ALL=C sort > "$rigTmp/epic.after.rows"
	rigAssert "the epic read as it stands: exit 0, every row well formed (the figure is the epic's own: $rigEpicRows)" \
		"$rigEpicRc:$( LC_ALL=C grep -c -v -E '^.*:[0-9]+: report-[a-z-]+: .' "$rigTmp/epic.before" || : )" "0:0"
	rigAssert "the epic with one planted fault of each class: exactly those rows more, one of each class" \
		"$( LC_ALL=C comm -13 "$rigTmp/epic.before.rows" "$rigTmp/epic.after.rows" | LC_ALL=C sed 's#^\(report-[a-z-]*\):.*#\1#' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" \
		"report-arithmetic report-citation report-count report-heading report-order report-replaced report-rule-name "
else
	printf '  SKIP  the epic is not in this workspace: %s\n' "$rigEpic"
fi
rigRoutines=0 rigRoutineRows=0
while IFS= read -r rigRoutine ; do
	rigRoutines=$(( rigRoutines + 1 ))
	rigRun document "$rigRoutine"
	rigRoutineRows=$(( rigRoutineRows + $( rigRowCount ) ))
	[ "$( rigRowCount )" = 0 ] || LC_ALL=C head -3 "$rigTmp/said.out"
done <<< "$( LC_ALL=C find "$rigPackage/skillset" -name '*.routine.md' -type f | LC_ALL=C sort )"
rigAssert "the routine set of the package ($rigRoutines routine documents): no row" "$rigRoutineRows" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DOC SELF-CHECK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DOC_SELF_CHECK: OK (%d assertions, offline)\n' "$rigPassCount"
