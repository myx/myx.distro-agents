#!/usr/bin/env bash
## Behavioural check on `Routines` under `Magic-Team (Agents)` in the manager screen (sh-lib/manager/AgentsManagerScreen.Routines.py), run rather than read (F11.11, stage one). The
## screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in
## script (check-fixtures/manager-screen.tools.stub.sh) that prints the fixture. Held: the root stands in Magic-Team (Agents) with a row for each routine `--manager-routine-list`
## prints, by its name, with its state at the end of the row; the routine selected shows its title and, as facts, its file, owner, executors, kind of session, state in its
## colour, last run, start and why it is not started; the section selected shows all of them as one table (routine, executors, kind, state, last run). It reads the
## listing alone, once, and computes nothing: a row is the seventeen fields `--manager-routine-list` prints, its state and its last run at the eleventh and the twelfth,
## and a row too short to carry them reads `-`. It stays apart from
## `Launchpad`, which lists the same routines for starting one. Offline.
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
## One row of the listing as the operation prints it: its seventeen fields, in the places
## `--manager-routine-list` gives them -- its state at the eleventh, its last run at the twelfth.
rigRoutineRow(){ ## the fields of a routine row, TAB-joined, as `--manager-routine-list` prints them: selector owner start executors session arguments title reason needs state last-run auto runs-at runs-after valid would
	printf 'routine\t%s\t%s\t%s\t%s\t%s\t-\t%s\t%s\t%s\t%s\t%s' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"
	[ $# -lt 15 ] || printf '\t%s\t%s\t%s\t%s\t%s' "${11}" "${12}" "${13}" "${14}" "${15}"
	printf '\n'
}
rigCase(){ ## name -- a fresh rig whose listing holds four routines
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	{
		rigRoutineRow magic-coordinator.daily.routine.md magic-coordinator startable magic-coordinator - Daily_of_the_team - - succeeded 2026-10-20_09:00 yes daily_09:00 - yes yes
		rigRoutineRow magic-team.coworking.routine.md magic-team not-startable magic-team coworking Coworking_session "its_executors,_magic-team,_is_any_member" members running 2026-10-20_14:17 no - - yes "no:its_executors,_magic-team,_is_any_member"
		rigRoutineRow keeper-myx.nightly.routine.md keeper-myx startable keeper-myx - Nightly_gap_check - - failed 2026-10-19_01:00 yes workdays_01:00 keeper-myx.gone.routine.md "no:runs-after:_keeper-myx.gone.routine.md_names_no_routine" "no:today_is_not_one_of_its_days_(workdays)"
		rigRoutineRow keeper-myx.fresh.routine.md keeper-myx startable keeper-myx - Not_yet_run - - never - no none - yes yes
	} > "$MANAGER_SCREEN_RIG/rows.--manager-routine-list"
	## the frontmatter of the daily routine, as `--manager-routine-frontmatter` prints it: a value is kept as printed (an underscore in it is no space)
	## the routine's own text, with the verdicts after the marker, as `--manager-routine-text <selector> --with-verdict` prints it
	printf '%s\n' '# Daily meeting' '' 'The team meets and a **bold** step comes first.' '' '- first item' '- second item' '' '# --- verdicts of the routine ---' 'valid	yes' > "$MANAGER_SCREEN_RIG/rows.--manager-routine-text magic-coordinator.daily.routine.md --with-verdict"
	mkdir -p "$MANAGER_SCREEN_RIG/rows.--manager-routine-frontmatter magic-coordinator"
	printf 'fm\ttype\troutine\nfm\truns-at\tworkdays 10:00\nfm\tinput-scan-def\twork_duty_def\n' > "$MANAGER_SCREEN_RIG/rows.--manager-routine-frontmatter magic-coordinator/magic-coordinator.daily.routine.md"
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
	advance 2
wait focus 10
	wait acts 10
wait fact 10
wait view 10
turn
show s
keys ENTER
wait plan 30
turn
get started
RIGSCRIPT
rigAssert "Magic-Team (Agents) holds Routines, and Routines a row for each routine, by its name as the listing gave it" "$( printf '%s' "$( rigVal team )" | LC_ALL=C grep -c -w routines ) | $( rigVal rows )" "1 | .. magic-coordinator/magic-coordinator.daily.routine.md magic-team/magic-team.coworking.routine.md keeper-myx/keeper-myx.nightly.routine.md keeper-myx/keeper-myx.fresh.routine.md"
## The table's own words, as the owner's sketch gives them: routine, executors, kind, state, last run
## and autorun, and no WOULD START column and no valid one. The column widths are the renderer's
## business, so nothing here pins padding -- only what the table SAYS.
rigAssert "the section selected shows all of them as one table: routine, executors, kind of session, state, last run, whether it runs by itself, and NO valid or startable column: the sketch removes the one and the list reads the frontmatter for the other" \
	"$( rigHolds r 'ROUTINE' ):$( rigHolds r 'EXECUTORS' ):$( rigHolds r 'KIND' ):$( rigHolds r 'STATE' ):$( rigHolds r 'LAST RUN' ):$( rigHolds r 'AUTO' ):$( rigHolds r 'VALID' ):$( rigHolds r 'STARTABLE' )" "1:1:1:1:1:1:0:0"
rigAssert "every routine of the listing is a row of that table, and its STARTABLE answer is a word of the row" \
	"$( [ "$( rigHolds r 'magic-coordinator.daily' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds r 'magic-team.coworking' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds r 'keeper-myx.nightly' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds r 'keeper-myx.fresh' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds r 'yes' )" -gt 0 ] && printf 1 || printf 0 )" "1:1:1:1:1"
rigAssert "a routine selected shows its title and its facts, its state and its last run among them, its autorun and its STARTABLE verdict" \
	"$( [ "$( rigHolds s 'Daily of the team' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds s 'state' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds s '2026-10-20 09:00' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds s 'magic-coordinator' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds s 'succeeded' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds s 'startable' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds s 'valid' )" -gt 0 ] && printf 1 || printf 0 )" "1:1:1:1:1:1:1"
rigAssert "the routine itself is shown rendered under its facts and its frontmatter: its heading, the Markdown of its text without its marks, and not the verdicts the read carries" "$( rigHolds s 'The routine' ) $( rigHolds s 'Daily meeting' ) $( rigHolds s 'bold' ) $( rigHolds s '**' ) $( rigHolds s 'verdicts of the routine' )" "1 1 1 0 0"
rigAssert "Enter starts the routine, as s does: the slots of the routine are asked first, then its launch form opens" "$( rigCalled '--manager-routine-slots magic-coordinator.daily.routine.md' ) [$( rigVal started.dialog )]" "1 [routine:task|]"
rigAssert "the frontmatter of the routine selected is read through the tooling, once, and shown as facts under its own heading: the screen parses no text of the file; a value stays as printed" \
	"$( rigCalled '--manager-routine-frontmatter magic-coordinator/magic-coordinator.daily.routine.md' ):$( rigHolds s 'frontmatter' | LC_ALL=C awk '{ print ( $1 > 0 ) }' ):$( rigHolds s 'runs-at' ):$( rigHolds s 'workdays 10:00' ):$( rigHolds s 'work_duty_def' )" "1:1:1:1:1"
rigAssert "the listing was read once for it, the frontmatter's own facts" "$( rigCalled '--manager-routine-list --facts-only' )" "1"
## R15: the summary of the routine selected states its verdicts, read for it alone.
rigAssert "the selected routine's summary states its verdicts" "$( rigHolds s 'startable' | LC_ALL=C awk '{ print ( $1 > 0 ) }' ):$( rigHolds s 'valid' | LC_ALL=C awk '{ print ( $1 > 0 ) }' )" "1:1"
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
rigAssert "one that is not started says why, and the kind of its session" \
	"$( [ "$( rigHolds t 'its executors, magic-team, is any member' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds t 'coworking: members working together' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds t 'runs by itself' )" -gt 0 ] && printf 1 || printf 0 )" "1:1:1"
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
rigAssert "one that follows a routine that is no routine, and runs on days it is not on: its times, why it is not valid and its STARTABLE answer" \
	"$( [ "$( rigHolds n 'workdays 01:00' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds n 'keeper-myx.gone.routine.md' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds n 'not valid because' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds n 'names no routine' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds n 'startable' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds n 'today is not one of its days' )" -gt 0 ] && printf 1 || printf 0 )" "1:1:1:1:1:1"

echo "-- a listing without the two fields: the routine reads -- --"
rigCase old
{ printf 'routine\tx.routine.md\tx\twould start now\tx\t-\t-\tOld_row\t-\t-\n' ; } > "$MANAGER_SCREEN_RIG/rows.--manager-routine-list"
rigScript <<'RIGSCRIPT'
turn
at @routines
turn
wait list 10
show o
RIGSCRIPT
rigAssert "a row of ten fields is still a row: its state and its last run, its autorun and its verdict read -" "$( rigHolds o 'x        x          -     -      -' ) $( rigHolds o 'ROUTINE  EXECUTORS' )" "1 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN ROUTINES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "MANAGER_SCREEN_ROUTINES: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"
