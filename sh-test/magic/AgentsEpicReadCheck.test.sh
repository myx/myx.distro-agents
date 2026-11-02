#!/usr/bin/env bash
## Behavioural check on the coordinator's epic read (S23.8): AgentDispatcherTools.fn.sh --epic-read and --epic-list, run rather than read,
## in a rig: epic files in the rig's workspace and the real tooling. Held:
##   1. WHO: magic-coordinator and a call from no member's session read; another member's session is refused and prints nothing.
##   2. --epic-read <file> prints the file whole; with --feature <id> it prints that feature's section alone, down to the next heading.
##   3. --epic-list <folder> prints one line for each *.epic.md file of the folder, `<file> <N> sections`, and says so where there is none.
##   4. REFUSED: a path outside a todo-sketchpad folder, a path with a `..` part, a missing file, a feature that is not there or stands twice,
##      a missing path, an option it does not know. Each is an error, never an empty result.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/AgentDispatcherTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsEpicReadCheck )" || exit 1
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
mkdir -p "$rigWs/.local/temp" "$rigHome" "$rigData/inboxes/magic-coordinator/incoming" "$rigSkills/magic-coordinator" "$rigWs/todo-sketchpad/backlog" "$rigWs/todo-sketchpad/empty"
rigEpic="$rigWs/todo-sketchpad/backlog/20990101-rig.epic.md"
rigAs="" rigRc=""
rigRun(){ ## result prefix, words... -- rc in rigRc
	local runOut="$1" ; shift
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" ${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$@"' rig "$rigTool" "$@" ) > "$runOut.out" 2> "$runOut.err" < /dev/null
	rigRc=$?
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" || :
}
printf '# Rig epic\n\n## S1 - First feature\n\n1. alpha\n2. beta\n\n## S2 - Second feature\n\n1. gamma\n' > "$rigEpic"
printf '# Rig epic two\n\n## S1 - Only\n' > "$rigWs/todo-sketchpad/backlog/20990102-rig.epic.md"
printf 'not an epic\n' > "$rigWs/todo-sketchpad/backlog/notes.md"
printf 'outside\n' > "$rigWs/outside.md"

echo "-- 1. who --"
rigAs=magic-coordinator ; rigRun "$rigTmp/a1" --epic-read "$rigEpic" ; rigRcA1="$rigRc"
rigAs="" ;                rigRun "$rigTmp/a2" --epic-read "$rigEpic" ; rigRcA2="$rigRc"
rigAs=keeper-x ;          rigRun "$rigTmp/a3" --epic-read "$rigEpic" ; rigRcA3="$rigRc"
rigAssert "the coordinator and a call from no member read; another member is refused and gets no text" "$rigRcA1 $rigRcA2 $rigRcA3 $( rigHas 'runs only as magic-coordinator, and this call comes from keeper-x' "$rigTmp/a3.err" ) $( wc -c < "$rigTmp/a3.out" | tr -d ' ' )" "0 0 1 1 0"

echo "-- 2. --epic-read --"
rigAs=magic-coordinator
rigAssert "the whole file is printed as it stands" "$( cmp -s "$rigTmp/a1.out" "$rigEpic" && printf same || printf differs )" same
rigRun "$rigTmp/b1" --epic-read "$rigEpic" --feature S2
rigAssert "a feature prints its own section, down to the next heading, and no other" "$( LC_ALL=C tr '\n' '|' < "$rigTmp/b1.out" ) $rigRc" "## S2 - Second feature||1. gamma| 0"
rigRun "$rigTmp/b2" --epic-read "$rigEpic" --feature S1
rigAssert "the first feature stops before the second" "$( rigHas 'alpha' "$rigTmp/b2.out" ) $( rigHas 'beta' "$rigTmp/b2.out" ) $( rigHas 'gamma' "$rigTmp/b2.out" ) $( rigHas '## S2' "$rigTmp/b2.out" )" "1 1 0 0"

echo "-- 3. --epic-list --"
rigRun "$rigTmp/c1" --epic-list "$rigWs/todo-sketchpad/backlog"
rigAssert "one line for each epic file, with its count of `## ` sections, and not the plain note" "$( LC_ALL=C tr '\n' '|' < "$rigTmp/c1.out" ) $rigRc" "20990101-rig.epic.md 2 sections|20990102-rig.epic.md 1 sections| 0"
rigRun "$rigTmp/c2" --epic-list "$rigWs/todo-sketchpad/empty"
rigAssert "a folder with no epic file says so, and exits 0" "$( LC_ALL=C tr '\n' '|' < "$rigTmp/c2.out" ) $rigRc" "EPIC-LIST: no epic file in $rigWs/todo-sketchpad/empty| 0"

echo "-- 4. refused --"
rigRun "$rigTmp/d1" --epic-read "$rigWs/outside.md" ; rigRcD1="$rigRc"
rigRun "$rigTmp/d2" --epic-read "$rigWs/todo-sketchpad/backlog/../../outside.md" ; rigRcD2="$rigRc"
rigRun "$rigTmp/d3" --epic-read "$rigWs/todo-sketchpad/backlog/no-such.epic.md" ; rigRcD3="$rigRc"
rigRun "$rigTmp/d4" --epic-read "$rigEpic" --feature S9 ; rigRcD4="$rigRc"
printf '# Rig\n\n## S1 - One\n\n## S1 - Again\n' > "$rigWs/todo-sketchpad/backlog/20990103-dup.epic.md"
rigRun "$rigTmp/d5" --epic-read "$rigWs/todo-sketchpad/backlog/20990103-dup.epic.md" --feature S1 ; rigRcD5="$rigRc"
rigRun "$rigTmp/d6" --epic-read ; rigRcD6="$rigRc"
rigRun "$rigTmp/d7" --epic-read "$rigEpic" --bogus ; rigRcD7="$rigRc"
rigRun "$rigTmp/d8" --epic-list "$rigWs" ; rigRcD8="$rigRc"
rigAssert "outside a todo-sketchpad folder: refused" "$rigRcD1 $( rigHas 'is not under a todo-sketchpad folder' "$rigTmp/d1.err" ) $( wc -c < "$rigTmp/d1.out" | tr -d ' ' )" "1 1 0"
rigAssert "a .. part: refused" "$rigRcD2 $( rigHas 'has a .. part' "$rigTmp/d2.err" ) $( wc -c < "$rigTmp/d2.out" | tr -d ' ' )" "1 1 0"
rigAssert "a missing file: refused" "$rigRcD3 $( rigHas 'no such epic file' "$rigTmp/d3.err" )" "1 1"
rigAssert "a feature not there: refused" "$rigRcD4 $( rigHas 'feature S9 must stand exactly once' "$rigTmp/d4.err" ) $( wc -c < "$rigTmp/d4.out" | tr -d ' ' )" "1 1 0"
rigAssert "a feature standing twice: refused" "$rigRcD5 $( rigHas 'feature S1 must stand exactly once' "$rigTmp/d5.err" )" "1 1"
rigAssert "no path: refused with the syntax" "$rigRcD6 $( rigHas 'syntax is <epic-file> [--feature <feature-id>]' "$rigTmp/d6.err" )" "1 1"
rigAssert "an option it does not know: refused" "$rigRcD7 $( rigHas 'invalid option: --bogus' "$rigTmp/d7.err" )" "1 1"
rigAssert "a list of a folder outside a todo-sketchpad folder: refused" "$rigRcD8 $( rigHas 'is not under a todo-sketchpad folder' "$rigTmp/d8.err" )" "1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ EPIC READ CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'EPIC_READ: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
