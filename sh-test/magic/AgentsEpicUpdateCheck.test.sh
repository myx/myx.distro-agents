#!/usr/bin/env bash
## Behavioural check on the epic file's own edit (W1 of the refactorings epic): AgentDispatcherTools.fn.sh --epic-update --set-status
## and --add-settled, run rather than read, in a rig: an epic file in the rig's workspace and the real tooling. Held:
##   1. WHO: magic-coordinator; another member's session is refused, a write from no member's session is refused, and the epic is untouched.
##   2. --set-status writes the `Status:` line that stands under the `## <feature-id>` heading, prints `EPIC: <file>: <id> status set to <status>`, and touches no other feature.
##   3. --set-status <feature-id> done takes the feature's own lines out and adds one line to `## Done`, its id and what
##      holds now -- the body's last line, the `**Settled ...**` stamp taken off -- and a file with no section gets it.
##   4. --add-settled adds the text as one plain present-tense line under the same heading, after its `Status:` line,
##      prints `EPIC: <file>: <id> settled: <text>`, and takes no date and no owner, wherever the word of either stands.
##   5. --set-status <feature-id>.<n> done <text...> closes one item: it and its nested lines leave, `## Done` gets
##      `- <feature-id>.<n>: <text>`, the caller's text and not the file's last line, and a feature is refused while
##      an item stands.
##   6. REFUSED: a feature that stands more than once, or not at all; a status of more than one word; a bad mode; a missing epic file; no settled text; a date or an owner, wherever it stands; an option it does not know; an item that does not stand, stands twice, names no number, or is closed by a word other than done, with no text.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/AgentDispatcherTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsEpicUpdateCheck )" || exit 1
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
mkdir -p "$rigWs/.local/temp" "$rigHome" "$rigData/inboxes/magic-coordinator/incoming" "$rigSkills/magic-coordinator"
rigEpic="$rigWs/epic-rig.md"
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
rigHasX(){ ## exact line, file -- how many lines of the file equal it
	LC_ALL=C grep -c -x -F -- "$1" "$2" || :
}
rigToday="$( date +%Y-%m-%d )"

echo "-- an epic file, two features, a status line each --"
printf '# Rig epic\n\n## feature-one The first feature\n\nStatus: not started\n\n## feature-two The second feature\n\nStatus: not started\n' > "$rigEpic"

echo "-- 1. who --"
rigAs=keeper-x ; rigRun "$rigTmp/w1" --epic-update "$rigEpic" --set-status feature-one running ; rigRcW1="$rigRc"
rigAs="" ;       rigRun "$rigTmp/w2" --epic-update "$rigEpic" --set-status feature-one running ; rigRcW2="$rigRc"
rigAs=magic-coordinator ; rigRun "$rigTmp/w3" --epic-update "$rigEpic" --set-status feature-one running ; rigRcW3="$rigRc"
rigAssert "another member refused, no member refused for a write, the coordinator writes; the epic untouched before the write" "$( rigHas 'runs only as magic-coordinator, and this call comes from keeper-x' "$rigTmp/w1.err" ) $( rigHas 'comes from no member' "$rigTmp/w2.err" ) $( cat "$rigTmp/w1.out" "$rigTmp/w2.out" | wc -l | tr -d ' ' ) $rigRcW1 $rigRcW2 $rigRcW3 $( rigHasX 'Status: running' "$rigEpic" )" "1 1 0 1 1 0 1"

echo "-- 2. --set-status --"
rigAssert "the write prints the status set line" "$( cat "$rigTmp/w3.out" | LC_ALL=C tr -d '\n' )" "EPIC: epic-rig.md: feature-one status set to running"
rigAssert "the one status line changed, the other feature is untouched" "$( rigHasX 'Status: running' "$rigEpic" ) $( rigHasX 'Status: not started' "$rigEpic" ) $( LC_ALL=C grep -n '^Status:' "$rigEpic" | LC_ALL=C tr '\n' ' ' )" "1 1 5:Status: running 9:Status: not started "

echo "-- 3. --add-settled: the rule plain, with no date and no owner --"
rigRun "$rigTmp/a1" --epic-update "$rigEpic" --add-settled feature-one The owner picked this.
rigAssert "the write prints the settled line" "$( cat "$rigTmp/a1.out" | LC_ALL=C tr -d '\n' )" "EPIC: epic-rig.md: feature-one settled: The owner picked this."
rigAssert "the rule stands plain, no date and no owner on it, after the status line" "$( rigHasX 'The owner picked this.' "$rigEpic" ) $( LC_ALL=C grep -n '^Status: running$' "$rigEpic" | LC_ALL=C cut -d: -f1 ) $( LC_ALL=C grep -n -x 'The owner picked this.' "$rigEpic" | LC_ALL=C cut -d: -f1 ) $( rigHas 'Settled' "$rigEpic" )" "1 5 7 0"
rigRun "$rigTmp/a2" --epic-update "$rigEpic" --add-settled feature-two Defaults here.
rigAssert "a second feature takes its own plain rule" "$( rigHasX 'Defaults here.' "$rigEpic" )" "1"

echo "-- 4. --set-status done: the item leaves its place, one line of ## Done --"
rigRun "$rigTmp/d1" --epic-update "$rigEpic" --set-status feature-one done
rigAssert "the write prints what the closed item holds now" "$( cat "$rigTmp/d1.out" | LC_ALL=C tr -d '\n' )" "EPIC: epic-rig.md: feature-one closed: The owner picked this."
rigAssert "its own lines are gone, the other feature stands, and one ## Done line carries its id" \
	"$( rigHas 'feature-one' "$rigEpic" ) $( rigHasX '- feature-one: The owner picked this.' "$rigEpic" ) $( rigHas 'feature-two' "$rigEpic" ) $( rigHasX '## Done' "$rigEpic" )" "1 1 1 1"
printf '# Rig epic\n\n## feature-one First\n\nStatus: x\n\n## Done\n\n- something already\n' > "$rigEpic.done"
rigRun "$rigTmp/d2" --epic-update "$rigEpic.done" --set-status feature-one done
rigAssert "a file that has the section gets the line under it, appended last" \
	"$( rigHasX '- feature-one: First' "$rigEpic.done" ) $( cat "$rigEpic.done" | LC_ALL=C tr '\n' '|' )" "1 # Rig epic||## Done||- something already|- feature-one: First|"

echo "-- 5. what is refused --"
rigRun "$rigTmp/r1" --epic-update "$rigEpic" --set-status feature-missing running
rigRun "$rigTmp/r2" --epic-update "$rigEpic" --set-status feature-one
rigRun "$rigTmp/r3" --epic-update "$rigEpic" --set-status feature-one running extra
rigRun "$rigTmp/r4" --epic-update "$rigEpic" --add-settled feature-one
rigRun "$rigTmp/r4b" --epic-update "$rigEpic" --add-settled feature-one --date 2026-10-25 x
rigRun "$rigTmp/r4c" --epic-update "$rigEpic" --add-settled feature-one --owner myx x
rigRun "$rigTmp/r4d" --epic-update "$rigEpic" --add-settled feature-one The rule holds. --date 2026-10-25
rigRun "$rigTmp/r4e" --epic-update "$rigEpic" --add-settled feature-one The rule holds. --owner myx
rigRun "$rigTmp/r5" --epic-update "$rigEpic" --bogus feature-one x
rigRun "$rigTmp/r6" --epic-update "$rigWs/no-such.md" --set-status feature-one running
rigAssert "a feature not there, no status, a status of more than one word, no settled text, a date, an owner, a bad mode, a missing file: each refused" "$( rigHas 'feature feature-missing must stand exactly once' "$rigTmp/r1.err" ) $( rigHas 'syntax is <feature-id> <status>' "$rigTmp/r2.err" ) $( rigHas 'the status is one line, passed as one argument' "$rigTmp/r3.err" ) $( rigHas 'the settled text is needed' "$rigTmp/r4.err" ) $( rigHas 'is gone -- the rule is written plain' "$rigTmp/r4b.err" ) $( rigHas 'is gone -- the rule is written plain' "$rigTmp/r4c.err" ) $( rigHas 'is not --set-status or --add-settled' "$rigTmp/r5.err" ) $( rigHas 'no such epic file' "$rigTmp/r6.err" )" "1 1 1 1 1 1 1 1"
rigAssert "a date or an owner standing after the settled text is refused, and nothing lands" "$( rigHas 'is gone -- the rule is written plain' "$rigTmp/r4d.err" ) $( rigHas 'is gone -- the rule is written plain' "$rigTmp/r4e.err" ) $( rigHas 'The rule holds.' "$rigEpic" )" "1 1 0"
printf '# Rig epic\n\n## feature-one First\n\nStatus: x\n\n## feature-one Again\n\nStatus: y\n' > "$rigEpic.dup"
rigRun "$rigTmp/r7" --epic-update "$rigEpic.dup" --set-status feature-one done
rigAssert "a feature standing twice: refused, the file untouched" "$( rigHas 'feature feature-one must stand exactly once' "$rigTmp/r7.err" ) $( rigHasX '- feature-one' "$rigEpic.dup" )" "1 0"

echo "-- 6. --set-status <feature-id>.<n> done: one item leaves, the caller's text to ## Done --"
rigItems="$rigWs/items-rig.md"
printf '# Rig epic\n\n## S24 - Flow\n\nStatus: open\n\n19. First open one. Owner: magic-developer.\n   - Tooling. Owner: magic-developer.\n     - a deep line\n\n20. Second open one. Owner: magic-developer.\n\n## Done\n\n- S1.1: an old close.\n' > "$rigItems"
rigRun "$rigTmp/i1" --epic-update "$rigItems" --set-status S24.19 done "The tooling half is built."
rigAssert "the write prints the closed item id and the caller's text" "$( cat "$rigTmp/i1.out" | LC_ALL=C tr -d '\n' )" "EPIC: items-rig.md: S24.19 closed: The tooling half is built."
rigAssert "the item and its nested lines are gone, its neighbour stands, and ## Done holds the caller's text -- not the file's last line" \
	"$( cat "$rigItems" | LC_ALL=C tr '\n' '|' )" "# Rig epic||## S24 - Flow||Status: open||20. Second open one. Owner: magic-developer.||## Done||- S1.1: an old close.|- S24.19: The tooling half is built.|"
rigRun "$rigTmp/i2" --epic-update "$rigItems" --set-status S24.20 done "The second one holds now."
rigAssert "a second item closes on its own id" "$( rigHasX '- S24.20: The second one holds now.' "$rigItems" ) $( rigHas 'Second open one' "$rigItems" )" "1 0"
rigRun "$rigTmp/i3" --epic-update "$rigItems" --set-status S24 done ; rigRcI3="$rigRc"
rigAssert "a feature closes once its items are closed, its heading leaves, and one ## Done line carries its id" "$rigRcI3 $( rigHasX '- S24: Flow' "$rigItems" ) $( rigHas 'S24 - Flow' "$rigItems" )" "0 1 0"
rigItems2="$rigWs/items2-rig.md"
printf '# Rig epic\n\n## S24 - Flow\n\n19. One open item. Owner: magic-developer.\n\n## S30 - Nothing left\n\nMoved to other.epic.md, section S4.\n\n## Done\n' > "$rigItems2"
rigRun "$rigTmp/i4" --epic-update "$rigItems2" --set-status S24 done
rigRun "$rigTmp/i5" --epic-update "$rigItems2" --set-status S30 done
rigAssert "a feature holding an item is refused by :149, and one holding none closes" "$( rigHas 'feature S24 holds 1 open item(s)' "$rigTmp/i4.err" ) $( rigHasX '## S24 - Flow' "$rigItems2" ) $( rigHasX '- S30: Moved to other.epic.md, section S4.' "$rigItems2" ) $( rigHasX '## S30 - Nothing left' "$rigItems2" )" "1 1 1 0"
rigRun "$rigTmp/i6" --epic-update "$rigItems2" --set-status S24.9 done "x"
rigRun "$rigTmp/i7" --epic-update "$rigItems2" --set-status S24.19 running
rigRun "$rigTmp/i8" --epic-update "$rigItems2" --set-status S24.19 done
rigRun "$rigTmp/i9" --epic-update "$rigItems2" --set-status S24.x done "x"
rigAssert "an item that does not stand, a word other than done, no text, an id with no number: each refused, the file untouched" "$( rigHas 'item S24.9 must stand exactly once' "$rigTmp/i6.err" ) $( rigHas 'only done closes an item' "$rigTmp/i7.err" ) $( rigHas "the closed item's text is needed" "$rigTmp/i8.err" ) $( rigHas 'S24.x is no item id' "$rigTmp/i9.err" ) $( rigHasX '19. One open item. Owner: magic-developer.' "$rigItems2" )" "1 1 1 1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ EPIC UPDATE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'EPIC_UPDATE: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
