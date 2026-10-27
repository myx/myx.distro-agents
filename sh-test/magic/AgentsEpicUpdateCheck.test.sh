#!/usr/bin/env bash
## Behavioural check on the epic file's own edit (W1 of the refactorings epic): AgentDispatcherTools.fn.sh --epic-update --set-status
## and --add-settled, run rather than read, in a rig: an epic file in the rig's workspace and the real tooling. Held:
##   1. WHO: magic-coordinator; another member's session is refused, a write from no member's session is refused, and the epic is untouched.
##   2. --set-status writes the `Status:` line that stands under the `## <feature-id>` heading, prints `EPIC: <file>: <id> status set to <status>`, and touches no other feature.
##   3. --add-settled adds a `**Settled <date> (<owner>).** <text>` line under the same heading, after its `Status:` line, and prints `EPIC: <file>: <id> settled: <text>`;
##      a given --date and --owner win, the defaults are today and `owner`.
##   4. REFUSED: a feature that stands more than once, or not at all; a status of more than one word; a bad mode; a missing epic file; no settled text; an option it does not know.
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

echo "-- 3. --add-settled --"
rigRun "$rigTmp/a1" --epic-update "$rigEpic" --add-settled feature-one --date 2026-10-25 --owner myx The owner picked this.
rigAssert "the write prints the settled line" "$( cat "$rigTmp/a1.out" | LC_ALL=C tr -d '\n' )" "EPIC: epic-rig.md: feature-one settled: The owner picked this."
rigAssert "a given date and owner win, the line stands after the status line" "$( rigHasX '**Settled 2026-10-25 (myx).** The owner picked this.' "$rigEpic" ) $( LC_ALL=C grep -n '^Status: running$' "$rigEpic" | LC_ALL=C cut -d: -f1 ) $( LC_ALL=C grep -n 'Settled 2026-10-25' "$rigEpic" | LC_ALL=C cut -d: -f1 )" "1 5 7"
rigRun "$rigTmp/a2" --epic-update "$rigEpic" --add-settled feature-two Defaults here.
rigAssert "no date and no owner: today and owner" "$( rigHas "**Settled $rigToday (owner).** Defaults here." "$rigEpic" )" "1"

echo "-- 4. what is refused --"
rigRun "$rigTmp/r1" --epic-update "$rigEpic" --set-status feature-missing running
rigRun "$rigTmp/r2" --epic-update "$rigEpic" --set-status feature-one
rigRun "$rigTmp/r3" --epic-update "$rigEpic" --set-status feature-one running extra
rigRun "$rigTmp/r4" --epic-update "$rigEpic" --add-settled feature-one
rigRun "$rigTmp/r5" --epic-update "$rigEpic" --bogus feature-one x
rigRun "$rigTmp/r6" --epic-update "$rigWs/no-such.md" --set-status feature-one running
rigAssert "a feature not there, no status, a status of more than one word, no settled text, a bad mode, a missing file: each refused" "$( rigHas 'feature feature-missing must stand exactly once' "$rigTmp/r1.err" ) $( rigHas 'syntax is <feature-id> <status>' "$rigTmp/r2.err" ) $( rigHas 'the status is one line, passed as one argument' "$rigTmp/r3.err" ) $( rigHas 'the settled text is needed' "$rigTmp/r4.err" ) $( rigHas 'is not --set-status or --add-settled' "$rigTmp/r5.err" ) $( rigHas 'no such epic file' "$rigTmp/r6.err" )" "1 1 1 1 1 1"
printf '# Rig epic\n\n## feature-one First\n\nStatus: x\n\n## feature-one Again\n\nStatus: y\n' > "$rigEpic.dup"
rigRun "$rigTmp/r7" --epic-update "$rigEpic.dup" --set-status feature-one running
rigAssert "a feature standing twice: refused, the file untouched" "$( rigHas 'feature feature-one must stand exactly once' "$rigTmp/r7.err" ) $( rigHasX 'Status: running' "$rigEpic.dup" )" "1 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ EPIC UPDATE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'EPIC_UPDATE: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
