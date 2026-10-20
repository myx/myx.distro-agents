#!/usr/bin/env bash
## Behavioural check on the tokens views of the Dashboard in the manager screen (sh-lib/manager/AgentsManagerScreen.Tokens.py), run rather than read. The screen's own
## code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh) that prints the fixture. Held: under the group `Agents: Tokens` of the Dashboard, and under no other group, stand
## `Tokens By Day`, `Tokens By Preset`, `Tokens By Credential`, `Tokens By Agent` and `Tokens By Routine`, ahead of its panels; each reads the Dispatcher's rows by its key
## (`--manager-stats-tokens --by day|preset|credential|member|routine`), once, and shows a row for each key with its runs; selected, its rows are a table of the keys, their
## runs and their tokens, short for the eye, with the total of them at its foot; `s` turns the sums into the average of a run and back, in the table and in the title,
## and does nothing where no such view is shown. The screen computes nothing else. Offline.
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
rigTmp="$( rigTempDir AgentsManagerScreenTokensCheck )" || exit 1
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
rigRows(){ ## the rows of one view
	case "$1" in
		day) printf 'tokens\t2026-10-18\t4\t1000\t2000000\t300000\t4000\ntokens\t2026-10-19\t6\t3000\t6000000\t900000\t12000\n' ;;
		preset) printf 'tokens\t-\t8\t2000\t4000000\t600000\t8000\ntokens\tfast\t2\t2000\t4000000\t600000\t8000\n' ;;
		credential) printf 'tokens\tkey-a\t10\t4000\t8000000\t1200000\t16000\n' ;;
		member) printf 'tokens\tmagic-coordinator\t6\t3000\t6000000\t900000\t12000\ntokens\tkeeper-myx\t4\t1000\t2000000\t300000\t4000\n' ;;
		routine) printf 'tokens\t-\t10\t4000\t8000000\t1200000\t16000\n' ;;
	esac
}
rigCase(){ ## name -- a fresh rig: the Dashboard with the group of the tokens and another, and the rows of every view
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	{
		rigRow group tokens Agents:_Tokens 1
		rigRow group machine The_Machine 1
		rigRow block sessions Sessions 1
		rigRow figure sessions sessions-running Sessions_Running 2 count - -
	} > "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read"
	: > "$MANAGER_SCREEN_RIG/calls" ; : > "$MANAGER_SCREEN_RIG/words" ; echo rows > "$MANAGER_SCREEN_RIG/mode"
	for rigOne in "day day" "preset preset" "credential credential" "agent member" "routine routine" ; do
		rigRows "${rigOne#* }" | LC_ALL=C sed 's/^/&/' > "$MANAGER_SCREEN_RIG/rows.--manager-stats-tokens --by ${rigOne#* }"
	done
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

echo "-- the views stand in the group of the tokens, and in no other --"
rigCase views
rigScript <<'RIGSCRIPT'
turn
at dashboard tokens
turn
wait list 10
rowids tokens
at dashboard machine
turn
wait list 10
rowids machine
RIGSCRIPT
rigAssert "Agents: Tokens holds the five views ahead of its panels" "$( rigVal tokens )" ".. day preset credential agent routine sessions"
rigAssert "the other group of the Dashboard holds none of them" "$( rigVal machine )" ".. sessions"

echo "-- a view reads the Dispatcher by its key, once, and shows its rows --"
rigScript <<'RIGSCRIPT'
at dashboard tokens day
turn
wait list 10
get d
rowids day
show d
at dashboard tokens preset
turn
wait list 10
rowids preset
at dashboard tokens agent
turn
wait list 10
rowids agent
at dashboard tokens routine
turn
wait list 10
rowids routine
at dashboard tokens credential
turn
wait list 10
rowids credential
RIGSCRIPT
rigAssert "each row is a key of the view, in the order the Dispatcher gave" "$( rigVal day ) | $( rigVal preset ) | $( rigVal agent ) | $( rigVal routine ) | $( rigVal credential )" ".. 2026-10-18 2026-10-19 | .. - fast | .. magic-coordinator keeper-myx | .. - | .. key-a"
rigAssert "the Dispatcher was asked for each by its own key, as the screen is told" "$( rigCalled '--manager-stats-tokens --by day' ) $( rigCalled '--manager-stats-tokens --by preset' ) $( rigCalled '--manager-stats-tokens --by member' ) $( rigCalled '--manager-stats-tokens --by routine' ) $( rigCalled '--manager-stats-tokens --by credential' )" "1 1 1 1 1"
rigAssert "a row shows its runs, and the view as a table: the keys, the runs and the tokens short for the eye, and the total at its foot, summed" \
	"$( rigHolds d '2026-10-19  6     3K  6.0M' ) $( rigHolds d 'summed over its runs' ) $( rigHolds d ' all         10    4K  8.0M' )" "1 1 1"

echo "-- s turns the sums into the average of a run, and back --"
rigScript <<'RIGSCRIPT'
at dashboard tokens day
turn
wait list 10
keys s
turn
show a
get a
keys s
turn
show b
at dashboard tokens
turn
keys s
at dashboard tokens day
turn
show c
RIGSCRIPT
rigAssert "with s the table, its title and the status line show the average of a run: 3000 tokens in 6 runs is 500, 6000000 cache read is 1.0M" "$( rigHolds a 'the average of a run' ) $( rigHolds a '2026-10-19  6     500  1.0M' ) $( rigHolds a '2026-10-18  4     250  500K' )" "2 1 1"
rigAssert "and s again, the sums" "$( rigHolds b 'summed over its runs' ) $( rigHolds b '2026-10-19  6     3K  6.0M' )" "1 1"
rigAssert "s does nothing where no tokens view is shown: the group, then the view, is still summed" "$( rigHolds c 'summed over its runs' )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN TOKENS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "MANAGER_SCREEN_TOKENS: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"
