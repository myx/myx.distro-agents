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
		weekday) printf 'tokens\tMon\t3\t900\t1800000\t270000\t3600\ntokens\tTue\t4\t1200\t2400000\t360000\t4800\ntokens\tWed\t0\t0\t0\t0\t0\ntokens\tThu\t1\t300\t600000\t90000\t1200\ntokens\tFri\t2\t600\t1200000\t180000\t2400\ntokens\tSat\t0\t0\t0\t0\t0\ntokens\tSun\t0\t0\t0\t0\t0\n' ;;
		hour) printf 'tokens\t00\t1\t100\t0\t0\t0\ntokens\t01\t1\t200\t0\t0\t0\ntokens\t02\t1\t300\t0\t0\t0\ntokens\t03\t1\t400\t0\t0\t0\ntokens\t04\t1\t500\t0\t0\t0\ntokens\t05\t1\t600\t0\t0\t0\ntokens\t06\t1\t700\t0\t0\t0\ntokens\t07\t1\t800\t0\t0\t0\ntokens\t08\t1\t900\t0\t0\t0\ntokens\t09\t1\t1000\t0\t0\t0\ntokens\t10\t1\t1100\t0\t0\t0\ntokens\t11\t1\t1200\t0\t0\t0\ntokens\t12\t1\t1300\t0\t0\t0\ntokens\t13\t1\t1400\t0\t0\t0\ntokens\t14\t1\t1500\t0\t0\t0\ntokens\t15\t1\t1600\t0\t0\t0\ntokens\t16\t1\t1700\t0\t0\t0\ntokens\t17\t1\t1800\t0\t0\t0\ntokens\t18\t1\t1900\t0\t0\t0\ntokens\t19\t1\t2000\t0\t0\t0\ntokens\t20\t1\t2100\t0\t0\t0\ntokens\t21\t1\t2200\t0\t0\t0\ntokens\t22\t1\t2300\t0\t0\t0\ntokens\t23\t1\t2400\t0\t0\t0\n' ;;
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
	for rigOne in "day day" "preset preset" "credential credential" "agent member" "routine routine" "weekday weekday" "hour hour" ; do
		rigRows "${rigOne#* }" | LC_ALL=C sed 's/^/&/' > "$MANAGER_SCREEN_RIG/rows.--manager-stats-tokens --by ${rigOne#* }"
		## what the tooling prints with --share: the same rows with the share and the peak share after them (the stand-in gives 0 0 but for the day), and with --average the averages
		rigRows "${rigOne#* }" | LC_ALL=C awk -F'\t' -v OFS='\t' '{ print $0, 0, 0 }' > "$MANAGER_SCREEN_RIG/rows.--manager-stats-tokens --by ${rigOne#* } --share"
		rigRows "${rigOne#* }" | LC_ALL=C awk -F'\t' -v OFS='\t' '{ r = $3 + 0 ; print $1, $2, $3, ( r ? int($4 / r) : 0 ), ( r ? int($5 / r) : 0 ), ( r ? int($6 / r) : 0 ), ( r ? int($7 / r) : 0 ), 0, 0 }' > "$MANAGER_SCREEN_RIG/rows.--manager-stats-tokens --by ${rigOne#* } --share --average"
	done
	## the day, with the shares of the `in` tokens the tooling would print: 1000 and 3000 of 4000 (25 and 75), of the largest (33 and 100); the averages, which the stand-in picks apart from what a division would give (777 and 333, not 500 and 250)
	printf 'tokens\t2026-10-18\t4\t1000\t2000000\t300000\t4000\t25\t33\ntokens\t2026-10-19\t6\t3000\t6000000\t900000\t12000\t75\t100\n' > "$MANAGER_SCREEN_RIG/rows.--manager-stats-tokens --by day --share"
	printf 'tokens\t2026-10-18\t4\t333\t500000\t75000\t1000\t33\t50\ntokens\t2026-10-19\t6\t777\t1000000\t150000\t2000\t67\t100\n' > "$MANAGER_SCREEN_RIG/rows.--manager-stats-tokens --by day --share --average"
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
wait view 10
rowids tokens
at dashboard machine
turn
wait list 10
wait view 10
rowids machine
RIGSCRIPT
rigAssert "Agents: Tokens holds its two panels first, then the seven views" "$( rigVal tokens )" ".. distribution trendview day preset credential weekday hour agent routine sessions"
rigAssert "the other group of the Dashboard holds none of them" "$( rigVal machine )" ".. sessions"

echo "-- a view reads the Dispatcher by its key, once, and shows its rows --"
rigScript <<'RIGSCRIPT'
at dashboard tokens day
turn
wait list 10
wait view 10
get ch
show ch
keys v
get st
show st
keys v
turn
get d
rowids day
show d
at dashboard tokens preset
turn
wait list 10
wait view 10
rowids preset
at dashboard tokens agent
turn
wait list 10
wait view 10
rowids agent
at dashboard tokens routine
turn
wait list 10
wait view 10
rowids routine
at dashboard tokens credential
turn
wait list 10
wait view 10
rowids credential
RIGSCRIPT
rigAssert "each row is a key of the view, in the order the Dispatcher gave" "$( rigVal day ) | $( rigVal preset ) | $( rigVal agent ) | $( rigVal routine ) | $( rigVal credential )" ".. 2026-10-18 2026-10-19 | .. - fast | .. magic-coordinator keeper-myx | .. - | .. key-a"
rigAssert "the Dispatcher was asked for each by its own key with --share, and the day rows once, plain, for the trend of the other views" "$( rigCalled '--manager-stats-tokens --by day --share' ) $( rigCalled '--manager-stats-tokens --by day' ) $( rigCalled '--manager-stats-tokens --by preset --share' ) $( rigCalled '--manager-stats-tokens --by member --share' ) $( rigCalled '--manager-stats-tokens --by routine --share' ) $( rigCalled '--manager-stats-tokens --by credential --share' )" "1 1 1 1 1 1"
rigAssert "the view OPENS on the chart of what it groups: the DISTRIBUTION alone, and no table under it" \
	"$( rigHolds ch 'Distribution of the tokens (in)' ):$( rigHolds ch 'Trend of the tokens (in)' ):$( [ "$( rigHolds ch '█' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds ch '▒' )" -eq 0 ] && printf 1 || printf 0 )" "1:0:1:1"
rigAssert "the second view is that one chart STACKED by token kind: its columns are made of more than one glyph" \
	"$( rigHolds st 'Distribution of the tokens (in)' ):$( rigHolds st 'Trend of the tokens (in)' ):$( [ "$( rigHolds st '█' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds st '▒' )" -gt 0 ] && printf 1 || printf 0 )" "1:0:1:1"
rigAssert "the stacked chart has a short legend below it, one line saying which glyph is which kind of token, and the plain chart has none" "$( rigHolds st '█ in  ▓ cache read  ▒ cache write  ░ out' ) $( rigHolds ch '█ in  ▓ cache read' )" "1 0"
rigAssert "a row shows its runs, and the view as a table: the keys, the runs and the tokens short for the eye, summed, and no total of its own (the screen sums nothing)" \
	"$( rigHolds d '2026-10-19  6     3K  6.0M' ) $( rigHolds d 'summed over its runs' ) $( rigHolds d ' all ' )" "1 1 0"

echo "-- s turns the sums into the average of a run, and back --"
rigScript <<'RIGSCRIPT'
at dashboard tokens day
turn
wait list 10
wait view 10
keys v
keys v
turn
keys s
turn
wait list 10
turn
show a
get a
keys s
turn
wait list 10
turn
show b
at dashboard tokens
turn
keys s
at dashboard tokens day
turn
show c
RIGSCRIPT
rigAssert "with s the table, its title shows the average of a run: the tooling's average is 777 where 3000 over 6 runs would be 500: the screen shows the tooling's, it divides nothing" "$( rigHolds a 'the average of a run' ) $( rigHolds a '2026-10-19  6     777  1.0M' ) $( rigHolds a '2026-10-18  4     333  500K' )" "1 1 1"
rigAssert "and s again, the sums" "$( rigHolds b 'summed over its runs' ) $( rigHolds b '2026-10-19  6     3K  6.0M' )" "1 1"
rigAssert "s asked the Dispatcher for the averages (--average) and the screen divided nothing: the average rows came from the stand-in's fixture" "$( rigCalled '--manager-stats-tokens --by day --share --average' )" "1"
rigAssert "s does nothing where no tokens view is shown: the group, then the view, is still summed" "$( rigHolds c 'summed over its runs' )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN TOKENS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "MANAGER_SCREEN_TOKENS: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"

echo "-- the two panels are views of their own: each shows its panel alone --"
rigScript <<'RIGSCRIPT'
at dashboard tokens distribution
turn
wait list 10
wait view 10
get dv
show dv
at dashboard tokens trendview
turn
wait list 10
wait view 10
get tv
show tv
RIGSCRIPT
rigAssert "Distribution shows the distribution panel alone, Trend the trend panel alone" \
	"$( [ "$( rigHolds dv 'Distribution of the tokens (in)' )" -gt 0 ] && printf 1 || printf 0 ):$( rigHolds dv 'Trend of the tokens (in)' ):$( [ "$( rigHolds tv 'Trend of the tokens (in)' )" -gt 0 ] && printf 1 || printf 0 ):$( rigHolds tv 'Distribution of the tokens (in)' )" "1:0:1:0"

echo "-- the two time views draw their own bins --"
rigScript <<'RIGSCRIPT'
turn
at dashboard tokens weekday
turn
wait list 10
wait view 10
turn
get daz
show daz
RIGSCRIPT
rigAssert "the weekday view holds seven bins, the empty ones among them" "$( rigVal daz.rows ) $( [ "$( rigHolds daz 'Mon' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds daz 'Sun' )" -gt 0 ] && printf 1 || printf 0 )" "8 1:1"
rigScript <<'RIGSCRIPT'
turn
at dashboard tokens hour
turn
wait list 10
wait view 10
turn
get hoz
show hoz
RIGSCRIPT
rigAssert "the hour view holds twenty-four bins, 00 to 23" "$( rigVal hoz.rows ) $( [ "$( rigHolds hoz '00' )" -gt 0 ] && printf 1 || printf 0 ):$( [ "$( rigHolds hoz '23' )" -gt 0 ] && printf 1 || printf 0 )" "25 1:1"

echo "-- a chart taller than its pane scrolls under the keys --"
rigScript <<'RIGSCRIPT'
size 120 18
turn
at dashboard tokens hour
turn
wait list 10
wait view 10
turn
get tall
keys TAB w
turn
keys RIGHT RIGHT RIGHT
turn
get downed
RIGSCRIPT
rigAssert "the hour chart is wider than the pane, so it PANS: viewLeft is not 0 after RIGHT" "$( rigVal tall.viewWidth | LC_ALL=C awk '$1 > 0 { print 1 }' ):$( rigVal downed.viewLeft | LC_ALL=C awk '{ print ( $1 > 0 ) }' )" "1:1"
