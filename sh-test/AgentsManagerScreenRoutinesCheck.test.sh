#!/usr/bin/env bash
## Behavioural check on `Routines` under `Magic-Team (Agents)` in the manager screen (sh-lib/manager/AgentsManagerScreen.Routines.py), run rather than read (F11.11, stage one). The
## screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in
## script (check-fixtures/manager-screen.tools.stub.sh) that prints the fixture. Held: the root stands in Magic-Team (Agents) with a row for each routine `--manager-routine-list`
## prints, by its name, with its state at the end of the row; the routine selected shows its title and, as facts, its file, owner, executors, kind of session, state in its
## colour, last run, start and why it is not started; the section selected shows all of them as one table (routine, executors, kind, state, last run). It reads the
## listing alone, once, and computes nothing: the state and the last run are the last two fields of each row, and a row without them reads `-`. It stays apart from
## `Launch (Start)`, which lists the same routines for starting one. Offline.
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
rigTmp="$( rigTempDir AgentsManagerScreenRoutinesCheck )" || exit 1
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
## The block of the team data of the dashboard, as the tooling prints it: its mode and whether the folder is there.
rigRow14(){ ## the fields of a routine row, TAB-joined: selector owner start executors session title reason needs state last-run (and, of stage two, auto runs-at runs-after valid would)
	printf 'routine\t%s\t%s\t%s\t%s\t%s\t-\t%s\t%s\t%s\t%s\t%s' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"
	[ $# -lt 15 ] || printf '\t%s\t%s\t%s\t%s\t%s' "${11}" "${12}" "${13}" "${14}" "${15}"
	printf '\n'
}
rigCase(){ ## name -- a fresh rig whose listing holds four routines
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	{
		rigRow14 magic-coordinator.daily.routine.md magic-coordinator startable magic-coordinator - Daily_of_the_team - - succeeded 2026-10-20_09:00 yes daily_09:00 - yes yes
		rigRow14 magic-team.coworking.routine.md magic-team not-startable magic-team coworking Coworking_session "its_executors,_magic-team,_is_any_member" members running 2026-10-20_14:17 no - - yes "no:its_executors,_magic-team,_is_any_member"
		rigRow14 keeper-myx.nightly.routine.md keeper-myx startable keeper-myx - Nightly_gap_check - - failed 2026-10-19_01:00 yes workdays_01:00 keeper-myx.gone.routine.md "no:runs-after:_keeper-myx.gone.routine.md_names_no_routine" "no:today_is_not_one_of_its_days_(workdays)"
		rigRow14 keeper-myx.fresh.routine.md keeper-myx startable keeper-myx - Not_yet_run - - never - no none - yes yes
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
rigCalled(){ ## words -- how many times the stand-in was started with exactly these words
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- the root, its rows and the table --"
rigCase list
rigScript <<'RIGSCRIPT'
turn
at @magic-team
turn
rowids team
at @routines
turn
wait list 10
rowids rows
show r
keys DOWN
wait focus 10
turn
show s
RIGSCRIPT
rigAssert "Magic-Team (Agents) holds Routines, and Routines a row for each routine, by its name as the listing gave it" "$( printf '%s' "$( rigVal team )" | LC_ALL=C grep -c -w routines ) | $( rigVal rows )" "1 | .. magic-coordinator/magic-coordinator.daily.routine.md magic-team/magic-team.coworking.routine.md keeper-myx/keeper-myx.nightly.routine.md keeper-myx/keeper-myx.fresh.routine.md"
rigAssert "the section selected shows all of them as one table: routine, executors, kind of session, state, last run, whether it runs by itself, whether it is valid, whether a start now would be accepted" "$( rigHolds r 'ROUTINE            EXECUTORS        KIND      STATE     LAST RUN         AUTO VALID WOULD START' ) $( rigHolds r 'succeeded 2026-10-20 09:00 yes  yes   yes' ) $( rigHolds r 'magic-team       coworking running   2026-10-20 14:17 no   yes   no' ) $( rigHolds r 'keeper-myx.nightly keeper-myx       -         failed    2026-10-19 01:00 yes  no    no' ) $( rigHolds r 'keeper-myx.fresh   keeper-myx       -         never                      no   yes   yes' )" "1 1 1 1 1"
rigAssert "a routine selected shows its title and its facts, its state and its last run among them, its autorun and its two verdicts" "$( rigHolds s 'Daily of the team' ) $( rigHolds s ' state            succeeded' ) $( rigHolds s ' last run         2026-10-20 09:00' ) $( rigHolds s ' executors        magic-coordinator' ) $( rigHolds s ' runs by itself   yes' ) $( rigHolds s ' runs at          daily 09:00' ) $( rigHolds s ' valid            yes' ) $( rigHolds s ' would start now  yes' )" "1 1 1 1 1 1 1 1"
rigAssert "the listing was read once for it" "$( rigCalled '--manager-routine-list' )" "1"
rigScript <<'RIGSCRIPT'
turn
at @routines
turn
wait list 10
keys DOWN DOWN
wait focus 10
turn
show t
RIGSCRIPT
rigAssert "one that is not started says why, and the kind of its session, and that a start now would not be accepted, for the same reason" "$( rigHolds t 'its executors, magic-team, is any member' ) $( rigHolds t 'coworking: members working together' ) $( rigHolds t ' would start now    no' ) $( rigHolds t ' would not because' ) $( rigHolds t ' runs by itself     no' )" "2 1 1 1 1"
rigScript <<'RIGSCRIPT'
turn
at @routines
turn
wait list 10
keys DOWN DOWN DOWN
wait focus 10
turn
show n
RIGSCRIPT
rigAssert "one that follows a routine that is no routine, and runs on days it is not on: its times, why it is not valid and why a start now would not be accepted" "$( rigHolds n ' runs at            workdays 01:00' ) $( rigHolds n ' runs after         keeper-myx.gone.routine.md' ) $( rigHolds n ' not valid because' ) $( rigHolds n 'runs-after: keeper-myx.gone.routine.md names no routine' ) $( rigHolds n ' would start now    no' ) $( rigHolds n 'today is not one of its days (workdays)' )" "1 1 1 1 1 1"

echo "-- a listing without the two fields: the routine reads -- --"
rigCase old
{ printf 'routine\tx.routine.md\tx\tstartable\tx\t-\t-\tOld_row\t-\t-\n' ; } > "$MANAGER_SCREEN_RIG/rows.--manager-routine-list"
rigScript <<'RIGSCRIPT'
turn
at @routines
turn
wait list 10
show o
RIGSCRIPT
rigAssert "a row of ten fields is still a row: its state and its last run, its autorun and its two verdicts read -" "$( rigHolds o 'x        x          -     -      -' ) $( rigHolds o 'ROUTINE  EXECUTORS' )" "1 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN ROUTINES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "MANAGER_SCREEN_ROUTINES: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"
