#!/usr/bin/env bash
## Behavioural check on S27.4 (console side) and S25.14 of the refactorings epic, run rather than read: the console shows the states of
## the runs apart, and a session by its title with the chapter it is in. The screen's own code (sh-lib/manager/LocalManagerScreen.py) runs
## through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py) and the stand-in for the dispatcher
## (check-fixtures/manager-screen.tools.stub.sh), which prints the rows the rig keeps for each operation. The rows are those the real list
## prints for the registry's words (AgentsManagerSessionStatesCheck holds that side).
## Held:
##   1. an agent shows the word of its state alone: thinking, tool, waiting, idling, parked, finished; no second word is added to it
##   2. each of those words has its look: the thinking, tool and idling the look of what is well, waiting and parked the look of what to look at,
##      finished dim
##   3. a session shows its title and, after it, the chapter it is in; one with no chapter shows the title alone
##   4. the left pane of a session names the chapter in a line of its own, and no such line stands where there is none
##   5. a session awaiting review is among the active sessions and reads parked; a finished one is closed
##   6. the agents that wait and those that work stay in their lists, and a parked agent is one of those that are not closed
## Red before S27.4: an agent read `thinking working` and `waiting waiting`, the new words had no look, and a chapter was shown nowhere.
## Offline: no operation of the real tooling is called.
set -u
## The runner gives every test a team rig as the default workspace mode (AgentsRunTests.sh); a run by hand takes the same default, so the result is the same either way.
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigCorePackage="$MDLT_ORIGIN/myx/myx.distro-.local"
rigScreen="$rigCorePackage/sh-lib/manager/LocalManagerScreen.py"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigTools="$rigFixtures/manager-screen.tools.stub.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenStatesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export TZ=UTC

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRow(){ ## the fields of one row, joined by TAB
	local rowText="$1" ; shift
	while [ $# -gt 0 ] ; do rowText="$rowText"$'\t'"$1" ; shift ; done
	printf '%s\n' "$rowText"
}
rigS1=11111111-0000-4000-8000-000000000001 ; rigS2=22222222-0000-4000-8000-000000000002 ; rigS3=33333333-0000-4000-8000-000000000003
rigA1=a1a1a1a1-0000-4000-8000-0000000000a1 ; rigA2=a2a2a2a2-0000-4000-8000-0000000000a2 ; rigA3=a3a3a3a3-0000-4000-8000-0000000000a3
rigA4=a4a4a4a4-0000-4000-8000-0000000000a4
rigB1=b1b1b1b1-0000-4000-8000-0000000000b1 ; rigC1=c1c1c1c1-0000-4000-8000-0000000000c1
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
## Three sessions, the newest first. The first is named, in a chapter, and has six agents, one for each word of a state: it thinks, it is in a
## tool, it waits in a Wait, it has nothing to do, one handed back and left, one has ended. The second has no chapter, and its one agent handed back and left. The
## third has ended.
{
	rigRow session "$rigS1" Rig_work running 2026-10-12_16:57_+0300 - 5 thinking=1,tool=1,waiting=1,idling=1,parked=1,finished=1 - - alive 1500000 - - Writing_the_dispatch
	rigRow run "$rigS1" "$rigA1" magic-coordinator spawn-started running thinking 2026-10-12_16:57_+0300 - rig-host ws-rig working
	rigRow run "$rigS1" "$rigA2" magic-tester spawn-started running tool 2026-10-12_17:05_+0300 - rig-host ws-rig working
	rigRow run "$rigS1" "$rigA3" magic-librarian spawn-started running waiting 2026-10-12_17:06_+0300 - rig-host ws-rig waiting
	rigRow run "$rigS1" "$rigA4" magic-architect spawn-started running idling 2026-10-12_17:07_+0300 - rig-host ws-rig -
	rigRow run "$rigS1" - keeper-myx spawn-succeeded gone parked 2026-10-12_17:07_+0300 2026-10-12_18:00_+0300 rig-host ws-rig -
	rigRow run "$rigS1" - keeper-mel spawn-succeeded gone finished 2026-10-12_17:08_+0300 2026-10-12_18:10_+0300 rig-host ws-rig -
	rigRow session "$rigS2" Handed_back parked 2026-10-12_09:00_+0300 - 1 parked=1 - - none 40000 - - -
	rigRow run "$rigS2" "$rigB1" magic-developer spawn-succeeded gone parked 2026-10-12_09:00_+0300 2026-10-12_09:30_+0300 rig-host ws-rig -
	rigRow session "$rigS3" Ended finished 2026-10-11_14:28_+0300 2026-10-11_14:51_+0300 1 finished=1 - - none 9000000 - - -
	rigRow run "$rigS3" "$rigC1" magic-devops spawn-succeeded gone finished 2026-10-11_14:28_+0300 2026-10-11_14:51_+0300 rig-host ws-rig -
	rigRow counters 1 0 2 1 2 0.42
} > "$rigF/rows.--manager-session-list"
rigRow counters 0 0 0 0 0 0.42 > "$rigF/rows"
## A fresh rig for one case: a copy of the fixtures, no call noted yet.
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize 120 40\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigPaneHolds(){ ## tag, text -- how many lines of the left pane of that screen hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' | LC_ALL=C grep -c -F -- "$2" || :
}
rigLook(){ ## tag, line of the screen counted from 0, from, to -- the letters of the looks of those cells, each letter once
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -n "$(( $2 + 1 ))p" | LC_ALL=C cut -c"$(( $3 + 1 ))-$4" | LC_ALL=C fold -w 1 | LC_ALL=C sort -u | LC_ALL=C tr -d '\n'
}

rigWordLook(){ ## tag, row text, word -- the letters of the role looks under the word, in the first line of the screen shown under that tag that holds the row text (its roles are under <tag>r)
	printf '%s\n' "$rigOut" | "$rigPython" -I -B -c '
import sys
tag, rowText, word = sys.argv[1], sys.argv[2], sys.argv[3]
shown, roles = [], []
for line in sys.stdin.read().split("\n"):
    if line.startswith(tag + "|"):
        shown.append(line[len(tag) + 1:])
    elif line.startswith(tag + "r|"):
        roles.append(line[len(tag) + 2:])
for at, line in enumerate(shown):
    column = line.find(rowText)
    if column >= 0 and at < len(roles):
        column += rowText.find(word)
        print("".join(sorted(set(roles[at][column:column + len(word)]))))
        break
' "$1" "$2" "$3"
}

echo "-- 1. a session shows its title and, after it, the chapter it is in; Activity keeps the sessions that are not closed --"
rigCase list
rigScript <<RIGSCRIPT
at @activity active-sessions
wait sessions 30
rowids active
cells r1 3 85 119
cells r2 4 85 119
at @activity closed-sessions
rowids closed
RIGSCRIPT
rigAssert "the active sessions: the one at work, and the one awaiting review; the finished one is closed" "$( rigVal active ) | $( rigVal closed )" ".. $rigS1 $rigS2 | .. $rigS3"
rigAssert "a session shows its title, the chapter after it, and its state; one with no chapter shows its title alone, and its state parked" "[$( rigVal r1 )][$( rigVal r2 )]" \
	"[ Rig work — Writ… running   1.5M ►][ Handed back       parked    40K ►]"

echo "-- 2. the left pane of a session: the chapter in a line of its own, each agent by the word of its state alone, each word in its look --"
rigCase pane
rigScript <<RIGSCRIPT
at @activity active-sessions
wait sessions 30
keys DOWN
show s1
roles s1r
keys DOWN
show s2
RIGSCRIPT
rigAssert "the chapter has its line, in the pane of the session that has one and in none other" "$( rigPaneHolds s1 'chapter  Writing the dispatch' ) $( rigPaneHolds s2 'chapter' )" "1 0"
rigAssert "the agents read thinking, tool, waiting, idling, parked and finished, and nothing is added to a word" \
	"$( rigPaneHolds s1 'magic-coordinator  thinking ' )$( rigPaneHolds s1 'magic-tester       tool ' )$( rigPaneHolds s1 'magic-librarian    waiting ' )$( rigPaneHolds s1 'magic-architect    idling ' )$( rigPaneHolds s1 'keeper-myx         parked ' )$( rigPaneHolds s1 'keeper-mel         finished ' )" "111111"
rigAssert "thinking, tool and idling have the look of what is well, as running has" "$( rigWordLook s1 'magic-coordinator  thinking' thinking ) $( rigWordLook s1 'magic-tester       tool' tool ) $( rigWordLook s1 'magic-architect    idling' idling ) $( rigWordLook s1 'state    running' running )" "k k k k"
rigAssert "waiting and parked have the look of what to look at" "$( rigWordLook s1 'magic-librarian    waiting' waiting ) $( rigWordLook s1 'keeper-myx         parked' parked )" "W W"
rigAssert "finished is dim" "$( rigWordLook s1 'keeper-mel         finished' finished )" "D"

echo "-- 3. the lists of agents keep those that work, those that wait and those that ended, an agent awaiting review among those that are not closed --"
rigCase agents
rigScript <<RIGSCRIPT
at @activity active-agents
wait sessions 30
rowids active
at @activity waiting-agents
rowids waiting
at @activity closed-agents
rowids closed
RIGSCRIPT
rigAssert "Active Agents: the one that thinks, the one in a tool, the one with nothing to do, and the two that handed back; Waiting Agents: the one in a Wait; Closed Agents: the two that ended" \
	"$( rigVal active ) | $( rigVal waiting ) | $( rigVal closed )" \
	".. $rigA1 $rigA2 $rigA4 -$rigS1.4 $rigB1 | .. $rigA3 | .. -$rigS1.5 $rigC1"

echo "-- the count --"
if [ "$rigFailCount" -eq 0 ] ; then
	printf 'MANAGER SCREEN STATES: OK (%d assertions, offline)\n' "$rigPassCount"
	exit 0
fi
printf '⛔ MANAGER SCREEN STATES CHECK FAILED: %d of %d assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
exit 1
