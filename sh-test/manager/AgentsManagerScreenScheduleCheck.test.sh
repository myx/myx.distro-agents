#!/usr/bin/env bash
## Behavioural check on `Schedule` of Magic-Team (Agents) in the manager screen (sh-lib/manager/AgentsManagerScreen.Schedule.py), run rather than read. The screen's own code runs through the stand-in
## terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.stub.sh) that prints the
## fixture: the rows `--manager-schedule-read` and `--manager-routine-list --facts-only` print.
## Held (sketch 14.5, Schedule): the section stands in Magic-Team after Routines; it lists the flags of the schedule now, one row each, with the answer and what it is from at the end; its pane shows
## the flags now, how long to the next switch and what changes, the week as a grid (a line for each day, a glyph for each hour by its flag, the cell of now reversed), and the table of the routines
## that start by themselves, from the rows of Routines. The screen derives none of it: the operation's rows are what is drawn.
## Offline: no operation of the real tooling is called.
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
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenScheduleCheck )" || exit 1
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
rigRow(){ local rowText="$1" ; shift ; while [ $# -gt 0 ] ; do rowText="$rowText"$'\t'"$1" ; shift ; done ; printf '%s\n' "$rowText" ; }
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
## the week the operation would print: worktime on weekdays from 09 to 17, the weekend on Saturday and Sunday; it is Tuesday 03:02 and worktime starts in 21438 seconds
{
	rigRow now 1793062935 tue 03:02 host
	rigRow flag worktime no "(default)" ; rigRow flag weekend no "(default)" ; rigRow flag holidays no - ; rigRow flag emergency yes "(3600 seconds left)" ; rigRow flag overtime no - ; rigRow flag learning no -
	rigRow switch 21438 worktime-starts
	for rigDay in mon tue wed thu fri sat sun ; do
		for rigHour in 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 ; do
			case "$rigDay" in
				sat|sun) rigCell=weekend ;;
				*) if [ "$rigHour" -ge 9 ] && [ "$rigHour" -le 17 ] ; then rigCell=worktime ; else rigCell=- ; fi ;;
			esac
			## one hour of Tuesday holds two flags: the emergency and the worktime
			[ "$rigDay$rigHour" != tue12 ] || rigCell="worktime,emergency"
			rigRow cell "$rigDay" "$rigHour" "$rigCell"
		done
	done
} > "$rigF/rows.--manager-schedule-read"
{
	## four that start by themselves and one that does not: A at 10:00, B at 09:00, C right after A, D at 09:30 after B, and E never
	rigAuto(){ ## name, auto, runs-at, runs-after
		printf 'routine\t%s.routine.md\towner\tstartable\towner\t-\t-\tTitle\t-\t-\tsucceeded\t2026-10-20_09:00\t%s\t%s\t%s\t-\t-\n' "$1" "$2" "$3" "$4"
	}
	rigAuto owner.alpha yes daily_10:00 -
	rigAuto owner.bravo yes daily_09:00 -
	rigAuto owner.charlie yes - owner.alpha.routine.md
	rigAuto owner.delta yes workdays_09:30 owner.bravo.routine.md
	rigAuto owner.echo no none -
} > "$rigF/rows.--manager-routine-list --facts-only"
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls" ; : > "$MANAGER_SCREEN_RIG/words" ; echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize %s\nroot active-sessions\n' "$rigTools" "${rigSize:-120 50}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1 ; }
rigHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigCalled(){ LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || : ; }

echo "-- Schedule stands in Magic-Team after Routines, and lists the flags --"
rigCase list
rigScript <<'RIGSCRIPT'
at @magic-team
turn
rowids team
at @schedule
turn
wait list 30
turn
rowids ids
show s
roles r
RIGSCRIPT
rigAssert "Magic-Team holds Schedule after Routines" "$( rigVal team | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -x -e routines -e schedule | LC_ALL=C tr '\n' ' ' )" "routines schedule "
rigAssert "a row for each flag, in the order of the operation" "$( rigVal ids )" ".. worktime weekend holidays emergency overtime learning"
rigAssert "the schedule and the autorun are read once each, and nothing else is asked" "$( rigCalled '--manager-schedule-read' ) $( rigCalled '--manager-routine-list --facts-only' )" "1 1"
rigAssert "the flags now: each with its answer and what it is from, an override with its time left" "$( rigHolds s 'worktime' ) $( rigHolds s 'yes (3600 seconds left)' ) $( rigHolds s 'no (default)' | LC_ALL=C awk '{ print ( $1 > 0 ) }' )" "3 1 1"
rigAssert "how long to the next switch and what changes: the seconds as they were given, in words" "$( rigHolds s 'next switch' ) $( rigHolds s 'worktime starts in 5h 57m' )" "1 1"
rigAssert "the week: several columns an hour, the hours across the top of each block of hours the pane's width allows" "$( rigHolds s '00    01    02' ) $( rigHolds s '12    13    14' )" "1 1"
rigAssert "each cell has the mark of its flag and its glyph: worktime W, the weekend E, a line a day in each block" "$( rigHolds s 'sat  E░░░░ E░░░░ E░░░░' ) $( rigHolds s 'mon  W████ W████ W████' ) $( rigHolds s 'mon  ····· ····· ·····' )" "2 1 1"
rigAssert "an hour that holds several flags is drawn by the strongest of them" "$( rigHolds s 'tue  !!!!! W████ W████' )" "1"
## the table of the routines that start by themselves is in the order they start, a routine that runs after another right under it
rigOrder="$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^s|' | LC_ALL=C grep -o -e 'owner\.[a-z]*  *\(daily\|workdays\|after\)[^│]*' | LC_ALL=C awk '{ print $1 }' | LC_ALL=C tr '\n' ' ' )"
rigAssert "the autorun table: by the time they start, a routine that runs after another right after its predecessor, and the one that never starts by itself not in it" "$rigOrder" "owner.bravo owner.delta owner.alpha owner.charlie "
echo "-- a narrower pane gives the cells fewer columns: they follow the width --"
rigCase narrow
rigSize="80 90"
rigScript <<'RIGSCRIPT'
at @schedule
turn
wait list 30
turn
show s
RIGSCRIPT
rigAssert "twelve hours to a line, each cell four columns where the pane was wide enough for six" "$( rigHolds s '00  01  02  03' ) $( rigHolds s '12  13  14  15' ) $( rigHolds s 'sat  E░░ E░░ E░░ E░░' ) $( rigHolds s 'sat  E░░░░ E░░░░' )" "1 1 2 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN SCHEDULE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "MANAGER_SCREEN_SCHEDULE: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"
