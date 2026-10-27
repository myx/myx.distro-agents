#!/usr/bin/env bash
## Behavioural check on the glance list of the manager screen (sh-lib/manager/AgentsManagerScreen.Glance.py), run rather than read (F11.12). The list of the
## right window already draws each row as its identity, its state at its end and, where it carries one, its number in a narrow column; the glance adds what it
## still needed: a `/` filter that narrows the rows already read, and a key that opens the full table of the level. Held: `/` opens a line on the last line of
## the list window, what is typed narrows the listed rows by what the glance shows of them (identity, state, number), Enter keeps the filter, Esc clears it, and
## the key `e` shows the level's full table (its summary) in the left window in place of the selected row's own view. Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigTools="$rigFixtures/manager-screen.tools.stub.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenGlanceCheck )" || exit 1
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
rigRow14(){ ## the fields of a routine row, TAB-joined: selector owner start executors session title reason needs state last-run
	printf 'routine\t%s\t%s\t%s\t%s\t%s\t-\t%s\t%s\t%s\t%s\t%s' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"
	printf '\n'
}
rigCase(){ ## name -- a fresh rig whose listing holds four routines
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	{
		rigRow14 magic-coordinator.daily.routine.md magic-coordinator startable magic-coordinator - Daily_of_the_team - - succeeded 2026-10-20_09:00
		rigRow14 magic-team.coworking.routine.md magic-team not-startable magic-team coworking Coworking_session "its_executors,_magic-team,_is_any_member" members running 2026-10-20_14:17
		rigRow14 keeper-myx.nightly.routine.md keeper-myx startable keeper-myx - Nightly_gap_check - - failed 2026-10-19_01:00
		rigRow14 keeper-myx.fresh.routine.md keeper-myx startable keeper-myx - Not_yet_run - - never -
	} > "$MANAGER_SCREEN_RIG/rows.--manager-routine-list"
	: > "$MANAGER_SCREEN_RIG/calls" ; : > "$MANAGER_SCREEN_RIG/words" ; echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){
	rigOut="$( { printf 'tools bash %s\nwall 2026-10-13 02:30 +0000\nsize 140 40\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}

echo "-- the / filter narrows the rows, and the key opens the full table --"
rigCase list
rigScript <<'RIGSCRIPT'
turn
at @routines
turn
wait list 10
rowids all
keys / m a g i c
turn
rowids narrow
show f
keys ENTER
turn
keys e
turn
show t
RIGSCRIPT
rigAssert "the list holds a row for each routine, by its name" "$( rigVal all )" ".. magic-coordinator/magic-coordinator.daily.routine.md magic-team/magic-team.coworking.routine.md keeper-myx/keeper-myx.nightly.routine.md keeper-myx/keeper-myx.fresh.routine.md"
rigAssert "typing /magic narrows the rows to the two whose identity holds it" "$( rigVal narrow )" ".. magic-coordinator/magic-coordinator.daily.routine.md magic-team/magic-team.coworking.routine.md"
rigAssert "the line of the filter stands on the last line of the list window, with what was typed" "$( rigHolds f '/magic' )" "1"
rigAssert "Enter keeps the filter, and the key e shows the full table of the level in the left window: its header" "$( rigHolds t 'EXECUTORS' )" "1"

rigScript <<'RIGSCRIPT'
turn
at @routines
turn
wait list 10
keys / k e e p
turn
rowids keep
keys ESC
turn
rowids cleared
RIGSCRIPT
rigAssert "what is typed narrows by the identity too: keeper leaves the two keeper-myx routines" "$( rigVal keep )" ".. keeper-myx/keeper-myx.nightly.routine.md keeper-myx/keeper-myx.fresh.routine.md"
rigAssert "Esc clears the filter, and every row is back" "$( rigVal cleared )" ".. magic-coordinator/magic-coordinator.daily.routine.md magic-team/magic-team.coworking.routine.md keeper-myx/keeper-myx.nightly.routine.md keeper-myx/keeper-myx.fresh.routine.md"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN GLANCE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "MANAGER_SCREEN_GLANCE: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"
