#!/usr/bin/env bash
## Behavioural check on the root `Dashboard (Monitor)` of the manager screen (sh-lib/manager/AgentsManagerScreen.py), run
## rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which notes each start and prints the fixture: rows in the two
## forms `--manager-dashboard-read` prints, `block <block> <label> <figures>` and
## `figure <block> <figure> <label> <value> <unit> <level> <share>`.
## Held: `Dashboard (Monitor)` is the first row of the root list and is the row the screen starts on, so the left
## window shows it at once; its blocks are read by `--manager-dashboard-read` with no argument, while that root is
## selected and while it is opened, on the period, and never while another root is selected; each block is a box
## with its label in its top border and a line a figure, the label at the left and the value at the right; a count,
## a size and a span of time show short, a value of another unit as it is printed; a value stands in the palette
## entry of its level, and in a style with no colours a mark and bold tell the level; a figure that is a share has
## a bar and its hundredths; a value too long for its line stands under its label, whole; a block and a figure the screen
## never heard of are drawn as they come, also with more fields than are known, and a figure of no block is left
## out; the blocks stand side by side as a grid where the window is wide and one under another where it is
## narrow, and nothing is drawn past the window; Enter opens the root: its rows are the blocks, in the order of
## the operation, each with the worst level of its figures at the end of its line, the row that goes up shows the
## whole dashboard and a block's row that block alone; `8` goes there from anywhere; the borders of the two
## windows are plain, with no counters and no load, in every view; an operation that gives no block says so, and
## one that fails says so in a box. Panels have no cut mode: with the lines cut, the dashboard, `..` and a block's
## row in it, and a block's row of `Team Data` are drawn as wrapped, titled [wrap]; `w` is greyed and refused there,
## and Left and Right too; the other views, `Team Data`'s own summary among them, stay cut.
## Offline: no operation of the real tooling is called.
## Reconciled for F11.5: the list of the sessions is Active Sessions of Activity (`at @activity active-sessions`), the view that stays cut is Pending Questions, and Team Data is put at with `at @teamdata`.
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
rigTmp="$( rigTempDir AgentsManagerScreenDashboardCheck )" || exit 1
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
## Three blocks no tooling prints, so nothing here is known to the screen by its name. The first: a count with no
## level, and a figure of each level, a word, a size and a span of time. The second: a share that is well, a share
## whose label leaves its bar no room beside the value, and a figure of a unit and a level nobody declared, with a
## field more than the form has. The third, its own row a field longer too: a value too long for any line. And
## three lines that are no row of the dashboard: a figure of a block that was not printed, a line of another name,
## a block too short.
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow block alpha Alpha_Block 4
	rigRow figure alpha a-plain Plain_Count 1234567 count - -
	rigRow figure alpha a-ok Good_One yes - ok -
	rigRow figure alpha a-warn Warned_Size 129011712 bytes warn -
	rigRow figure alpha a-bad Bad_Age 8863 seconds bad -
	rigRow block beta Beta_Block 3
	rigRow figure beta b-share Share_Used 663234043904 bytes ok 70
	rigRow figure beta b-long A_Figure_With_A_Long_Label 12 count - 33
	rigRow figure beta b-odd Odd_Unit 3.5 furlongs strange - one-field-more
	rigRow figure ghost g-one Of_No_Block 1 count - -
	rigRow other thing of another name
	rigRow block gamma Gamma_Block 1 one-field-more
	rigRow figure gamma c-path Root_Path /rig/some/where/far/away/a/long/path/that/fits/no/small/box/END - - -
	rigRow block short
} > "$rigF/rows.--manager-dashboard-read"
rigRow counters 3 1 2 4 5 0.42 righost > "$rigF/rows"
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
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize %s\nroot dashboard\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigBoth(){ ## tag, text, text -- how many lines of that screen hold both texts
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -F -- "$2" | LC_ALL=C grep -c -F -- "$3" || :
}
rigLookAt(){ ## tag of the screen as text, tag of the same screen as looks, text -- how the cells that text stands in are drawn, on the first line that holds it
	RIG_OUT="$rigOut" "$rigPython" -I -B -c '
import os, sys
show, looks, text = sys.argv[1:4]
out = os.environ["RIG_OUT"].split("\n")
shown = [line[len(show) + 1:] for line in out if line.startswith(show + "|")]
drawn = [line[len(looks) + 1:] for line in out if line.startswith(looks + "|")]
for number, line in enumerate(shown):
    at = line.find(text)
    if at >= 0:
        print(drawn[number][at:at + len(text)])
        break
' "$1" "$2" "$3"
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigArgued(){ ## how many starts of the dashboard's operation carried any argument
	LC_ALL=C grep -- '^--manager-dashboard-read' "$MANAGER_SCREEN_RIG/calls" | LC_ALL=C grep -c -v -x -- '--manager-dashboard-read' || :
}

echo "-- the screen starts on the dashboard: the first row of the root, read at once, drawn as blocks"
rigCase start
rigScript <<'EOF'
workspace /rig/ws-rig
turn
get first
wait list 5
wait sessions 5
show a
roles ar
get a
border title 1 0 84
border leftFoot 38 0 84
border listFoot 38 84 120
EOF
rigAssert "the screen starts on the first row of the root, which is the dashboard" "$( rigVal first.index ) $( rigVal first.selected ) [$( rigVal first.selectedLabel )] [$( rigVal first.path )]" "0 dashboard [Dashboard (Monitor)] []"
rigAssert "its operation is called at once, with no argument, though the root is not opened" "$( rigCalled --manager-dashboard-read ) $( rigArgued )" "1 0"
rigAssert "the left window is titled by it, and nothing failed" "[$( rigVal title )] [$( rigVal a.failed )] [$( rigVal a.dialog )] $( rigVal a.spills )" "[Dashboard (Monitor) [wrap]] [] [] 0"
rigAssert "a block is a box with its label in its top border" "$( rigHolds a '┌─ Alpha Block ─' ) $( rigHolds a '┌─ Beta Block ─' ) $( rigHolds a '┌─ Gamma Block ─' )" "1 1 1"
rigAssert "a figure is a line of its box: its label at the left, its value at the right" "$( rigHolds a '│ Plain Count ' ) $( rigHolds a ' 1.2M │' )" "1 1"
rigAssert "a count, a size and a span of time show short; a word shows as it is" "$( rigBoth a 'Plain Count' ' 1.2M │' ) $( rigBoth a 'Warned Size' ' 123.0M │' ) $( rigBoth a 'Bad Age' ' 2h 27m │' ) $( rigBoth a 'Good One' ' yes │' )" "1 1 1 1"
rigAssert "a value of a unit nobody declared shows as it is printed, and a row with a field more is taken" "$( rigBoth a 'Odd Unit' ' 3.5 │' ) $( rigHolds a 'one-field-more' )" "1 0"
rigAssert "a figure of a block that was not printed, a line of another name and a block too short are left out" "$( rigHolds a 'Of No Block' ) $( rigHolds a 'another name' ) $( rigHolds a 'short' )" "0 0 0"
rigAssert "a share has a bar of ten cells and its hundredths beside its value" "$( rigBoth a 'Share Used' ' 617.7G ■■■■■■■▒▒▒  70% │' )" "1"
rigAssert "where they have no room beside the value, the bar stands under the figure, as wide as the box" "$( rigBoth a 'A Figure With A Long Label' ' 12 │' ) $( rigHolds a '│ ■■■■■■■■■■▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  33% │' )" "1 1"
rigAssert "a value longer than a line stands under its label whole, on as many lines as it takes, and nothing of it is cut" "$( rigHolds a '│ Root Path  ' ) $( rigHolds a '│ /rig/some/where/far/away/a/long/path │' ) $( rigHolds a '│ /that/fits/no/small/box/END  ' ) $( rigHolds a '…' )" "1 1 1 0"
rigAssert "the label of a block stands out, and a value with no level too" "$( rigLookAt a ar 'Alpha Block' ) $( rigLookAt a ar '1.2M' )" "BBBBBBBBBBB BBBB"
rigAssert "a value stands in the palette entry of its level: well, to look at, bad" "$( rigLookAt a ar 'yes' ) $( rigLookAt a ar '123.0M' ) $( rigLookAt a ar '2h 27m' )" "kkk WWWWWW XXXXXX"
rigAssert "the bar of a share is drawn in the level of its figure, and what is left of it of less weight" "$( rigLookAt a ar '■■■■■■■▒▒▒' )" "kkkkkkkDDD"
rigAssert "with colours no mark stands ahead of a value" "$( rigHolds a '! 123.0M' ) $( rigHolds a '+ yes' )" "0 0"
rigAssert "the borders of the two windows are plain: no counters, no load, though the row of counters was read" "[$( rigVal leftFoot )] [$( rigVal listFoot )] $( rigVal a.counters | LC_ALL=C grep -c 'load=0.42' )" "[] [] 1"

echo "-- with no colours a mark and bold tell the level"
rigCase bw
rigScript <<'EOF'
style bw
turn
wait list 5
show b
looks bl
get b
EOF
rigAssert "the mark of its level stands ahead of a value" "$( rigBoth b 'Good One' ' + yes │' ) $( rigBoth b 'Warned Size' ' ! 123.0M │' ) $( rigBoth b 'Bad Age' ' !! 2h 27m │' ) $( rigBoth b 'Plain Count' '  1.2M │' )" "1 1 1 1"
rigAssert "and bold tells it: one to look at is bold, a bad one bold in reverse, one that is well plain" "$( rigLookAt b bl '! 123.0M' ) $( rigLookAt b bl '!! 2h 27m' ) $( rigLookAt b bl '+ yes' ) $( rigVal b.spills )" "BBBBBBBB HHHHHHHHH ..... 0"

echo "-- a grid that fills the window: side by side where it is wide, one under another where it is narrow"
rigCase wide
rigSize="160 40" rigScript <<'EOF'
turn
wait list 5
show w
get w
EOF
rigAssert "in a wide window the three blocks stand side by side" "$( rigBoth w '┌─ Alpha Block ─' '┌─ Beta Block ─' ) $( rigBoth w '┌─ Beta Block ─' '┌─ Gamma Block ─' ) $( rigVal w.spills )" "1 1 0"
rigAssert "and the last box ends where the window ends, less one cell" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^w|' | LC_ALL=C grep -c -F -- '─┐ │║' )" "1"
rigCase narrow
rigSize="80 24" rigScript <<'EOF'
turn
wait list 5
show n
get n
style magic
turn
show c
get c
EOF
rigAssert "in a narrow one they stand one under another, and nothing is drawn past the window" "$( rigBoth n '┌─ Alpha Block ─' '┌─ Beta Block ─' ) $( rigHolds n '┌─ Alpha Block ─' ) $( rigVal n.spills )" "0 1 0"
rigAssert "Magic draws the same blocks, a level in its colours" "$( rigHolds c '┌─ Alpha Block ─' ) $( rigBoth c 'Warned Size' ' 123.0M │' ) $( rigVal c.spills )" "1 1 0"

echo "-- Enter opens it: the blocks are its rows; the row that goes up shows it whole, a block's row that block"
rigCase opened
rigScript <<'EOF'
turn
wait list 5
keys ENTER
turn
get in
show in
border inTitle 1 0 84
keys DOWN
turn
get alpha
show alpha
border alphaTitle 1 0 84
keys DOWN DOWN
turn
show gamma
get gamma
keys BACKSPACE
turn
get out
EOF
rigAssert "Enter opens the root: the row that goes up, then a row a block, in the order of the operation" "$( rigVal in.path ) $( rigVal in.rows ) $( rigVal in.selected ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^in|' | LC_ALL=C sed -n -e 's/^.*║.\(Alpha Block\).*$/\1/p' -e 's/^.*║.\(Beta Block\).*$/\1/p' -e 's/^.*║.\(Gamma Block\).*$/\1/p' | tr '\n' ',' )" "dashboard 4 .. Alpha Block,Beta Block,Gamma Block,"
rigAssert "a block's row ends with the worst level of its figures, where one is worse than well" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^in|' | LC_ALL=C grep -c 'Alpha Block  *bad║' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^in|' | LC_ALL=C grep -c 'Beta Block  *║' )" "1 1"
rigAssert "on the row that goes up the left window shows the dashboard itself, whole" "[$( rigVal inTitle )] $( rigHolds in '┌─ Alpha Block ─' ) $( rigHolds in '┌─ Beta Block ─' )" "[Dashboard (Monitor) [wrap]] 1 1"
rigAssert "on the row of a block it shows that block alone, as wide as the window" "$( rigVal alpha.selected ) [$( rigVal alphaTitle )] $( rigHolds alpha '┌─ Alpha Block ─' ) $( rigHolds alpha '┌─ Beta Block ─' ) $( rigVal alpha.viewLines )" "alpha [Alpha Block [wrap]] 1 0 6"
rigAssert "there a long value has the room to stand beside its label" "$( rigVal gamma.selected ) $( rigBoth gamma '│ Root Path ' ' /rig/some/where/far/away/a/long/path/that/fits/no/small/box/END │' ) $( rigVal gamma.spills )" "gamma 1 0"
rigAssert "Backspace goes back to the root, onto its row" "[$( rigVal out.path )] $( rigVal out.selected )" "[] dashboard"

echo "-- a submenu a subsystem registers: a row of the Dashboard after its blocks, which opens a level of its own"
rigCase submenu
{
	cat "$rigF/rows.--manager-dashboard-read"
	rigRow group tokens Agents:_Tokens 2
	rigRow group nameless
} > "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read"
{
	rigRow block delta Delta_Block 1
	rigRow figure delta d-one Delta_Figure 7 count - -
	rigRow block epsilon Epsilon_Block 1
	rigRow figure epsilon e-one Epsilon_Figure 9 count - -
} > "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read --group tokens"
rigScript <<'EOF'
turn
wait list 5
keys ENTER
turn
get in
show in
keys DOWN DOWN DOWN DOWN
turn
wait focus 5
get sub
show sub
border subTitle 1 0 84
keys ENTER
turn
wait list 5
get dive
show dive
## nine rows down to the block: the seven views of the tokens, then the rows of the submenu
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN
turn
get blk
show blk
border blkTitle 1 0 84
keys BACKSPACE
turn
get out
EOF
rigAssert "the rows of the Dashboard: the row that goes up, the blocks in the order of the operation, then the submenu, whose line says how many panels it holds; the line of a submenu with no panels is none" "$( rigVal in.path ) $( rigVal in.rows ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^in|' | LC_ALL=C sed -n -e 's/^.*║.\(Alpha Block\).*$/\1/p' -e 's/^.*║.\(Beta Block\).*$/\1/p' -e 's/^.*║.\(Gamma Block\).*$/\1/p' -e 's/^.*║.\(Agents: Tokens\)  *\(2 panels\).*$/\1 \2/p' | tr '\n' ',' )" "dashboard 5 Alpha Block,Beta Block,Gamma Block,Agents: Tokens 2 panels,"
rigAssert "selected, the submenu shows its panels in the left window, read for it with its key; the blocks of the Dashboard are not among them" "$( rigVal sub.selected ) [$( rigVal subTitle )] $( rigHolds sub '┌─ Delta Block ─' ) $( rigHolds sub '┌─ Epsilon Block ─' ) $( rigHolds sub '┌─ Alpha Block ─' ) $( rigCalled '--manager-dashboard-read --group tokens' )" "tokens [Agents: Tokens [wrap]] 1 1 0 1"
rigAssert "Enter opens it: the row that goes up, the six views of the tokens that stand in this submenu alone, then a row a block of the submenu" "$( rigVal dive.path ) $( rigVal dive.rows ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^dive|' | LC_ALL=C sed -n -e 's/^.*║.\(Delta Block\).*$/\1/p' -e 's/^.*║.\(Epsilon Block\).*$/\1/p' | tr '\n' ',' )" "dashboard/tokens 12 Delta Block,Epsilon Block,"
rigAssert "on the row of a block of the submenu that block alone is shown, as wide as the window" "$( rigVal blk.selected ) [$( rigVal blkTitle )] $( rigHolds blk '┌─ Delta Block ─' ) $( rigHolds blk '┌─ Epsilon Block ─' )" "delta [Delta Block [wrap]] 1 0"
rigAssert "Backspace goes back to the Dashboard, onto the row of the submenu" "[$( rigVal out.path )] $( rigVal out.selected )" "[dashboard] tokens"
rigAssert "the Dashboard was read with no argument, whatever else was asked" "$( rigCalled --manager-dashboard-read ) $( rigArgued )" "1 1"

echo "-- it is read on the period only while its root is selected or opened"
rigCase period
rigScript <<'EOF'
turn
wait list 5
advance 11
turn
wait list 5
get again
keys DOWN
turn
advance 11
turn
wait list 5
advance 11
turn
wait list 5
get away
keys 1
turn
wait list 5
get back
advance 11
turn
wait list 5
get inside
EOF
rigReads="$( rigCalled --manager-dashboard-read )"
rigAssert "while its row is selected at the root it is read again when the period has passed" "$( rigVal again.selected ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^DRIVER-FAILED' )" "dashboard 0"
rigAssert "while another root is selected it is not read, however long; 8 goes into it, and it is read again, and on the period while it is open" "$( rigVal away.selected ) [$( rigVal back.path )] [$( rigVal inside.path )] $rigReads $( rigArgued )" "pending [dashboard] [dashboard] 4 0"

echo "-- the borders stay plain in another view"
rigCase borders
rigScript <<'EOF'
turn
wait list 5
wait sessions 5
at @activity active-sessions
turn
turn
wait sessions 5
get s
border leftFoot 38 0 84
border listFoot 38 84 120
style bw
turn
border leftFootBw 38 0 84
border listFootBw 38 84 120
EOF
rigAssert "in the list of the sessions too, with the counters read, in both styles that have frames" "[$( rigVal s.path )] $( rigVal s.counters | LC_ALL=C grep -c 'running=3' ) [$( rigVal leftFoot )] [$( rigVal listFoot )] [$( rigVal leftFootBw )] [$( rigVal listFootBw )]" "[magic-team/activity/active-sessions] 1 [] [] [] []"

echo "-- panels have no cut mode: with the lines cut elsewhere, a view of panels is drawn as wrapped, and w is refused there"
rigScreenOf(){ ## tag -- that whole screen as text
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p"
}
rigCase panels
rigSize="176 49" rigScript <<'EOF'
style tv-blue
turn
wait list 5
show pw
keys DOWN TAB w TAB UP
wait list 5
turn
get pc
show pc
keys ENTER
wait list 5
keys DOWN
turn
get pa
show pa
keys DOWN DOWN
turn
show pg
keys UP UP UP
turn
get pu
show pu
keys BACKSPACE TAB
turn
cells pvStatus 48 0 176
keys RIGHT RIGHT
turn
get pr
keys ALT-v
turn
show pm
roles pmr
keys ESC w
turn
get pw2
keys TAB DOWN
turn
show ps
keys TAB
turn
cells psStatus 48 0 176
keys ALT-v
turn
show sm
roles smr
EOF
rigAssert "cut set on another view, the dashboard is drawn exactly as wrapped, titled so, and the setting stays cut" "$( [ "$( rigScreenOf pw )" = "$( rigScreenOf pc )" ] && echo same || echo differs ) $( rigHolds pc 'Dashboard (Monitor) [wrap]' ) $( rigHolds pc '…' ) $( rigVal pc.wrap ) $( rigVal pc.spills )" "same 1 0 no 0"
rigAssert "there w is not named in the status line, and does nothing but say why" "$( rigVal pvStatus | LC_ALL=C grep -c ' w ' ) $( rigVal pw2.wrap ) [$( rigVal pw2.notice )]" "0 no [Wrap or cut long lines: not for what is selected]"
rigAssert "Left and Right are refused as where lines are wrapped" "$( rigVal pr.viewLeft ) [$( rigVal pr.notice )]" "0 [Scroll: the lines are wrapped, none is cut]"
rigAssert "in View, w is greyed there, and not on another view" "$( rigLookAt pm pmr 'Wra' ) $( rigLookAt sm smr 'Wra' | LC_ALL=C grep -c x )" "xxx 0"
rigAssert "a block's row: the block as wide as the window, its value at its right, nothing cut, titled [wrap]" "$( rigVal pa.selected ) $( rigHolds pa 'Alpha Block [wrap]' ) $( rigHolds pa '─┐ │║' ) $( rigBoth pa 'Plain Count' ' 1.2M │ │║' ) $( rigHolds pa '…' )" "alpha 1 1 1 0"
rigAssert "a long value has the room to stand beside its label there" "$( rigBoth pg '│ Root Path ' '/box/END │ │║' )" "1"
rigAssert "the row that goes up shows the dashboard whole, as wrapped" "$( rigVal pu.selected ) $( rigHolds pu 'Dashboard (Monitor) [wrap]' ) $( rigBoth pu '┌─ Alpha Block ─' '┌─ Beta Block ─' ) $( rigHolds pu '…' )" ".. 1 1 0"
rigAssert "another view stays cut, and offers w" "$( rigHolds ps 'Pending Questions [cut]' ) $( rigVal psStatus | LC_ALL=C grep -c 'w Wrap' )" "1 1"
rigCase teamdataPanels
{
	rigRow block team-data Store_Of_Data 2
	rigRow figure team-data present Data_Present yes - ok -
	rigRow figure team-data root Data_Root /rig/data - - -
} > "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read"
cp "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read" "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read team-data team-data-git loop"
rigSize="176 49" rigScript <<'EOF'
style tv-blue
turn
wait list 5
keys DOWN TAB w TAB
at @teamdata
turn
wait list 5
turn
get td
show td
keys DOWN DOWN DOWN DOWN DOWN
turn
get tb
show tb
EOF
rigAssert "Team Data's own summary stays cut; its block's row is drawn as wrapped, as wide as the window" "$( rigVal td.path ) $( rigHolds td 'Team Data [cut]' ) $( rigVal tb.selected ) $( rigHolds tb 'Store Of Data [wrap]' ) $( rigHolds tb '─┐ │║' ) $( rigBoth tb 'Data Present' ' yes │ │║' ) $( rigHolds tb '…' )" "magic-team/teamdata 1 team-data 1 1 1 0"

echo "-- an operation that gives no block, and one that fails"
rigCase none
: > "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read"
rigScript <<'EOF'
turn
wait list 5
show e
get e
EOF
rigAssert "no block: the left window says so" "$( rigHolds e 'Nothing to show here: the operation gave no block.' ) [$( rigVal e.dialog )]" "1 []"
rigCase failing
echo fail > "$MANAGER_SCREEN_RIG/mode.--manager-dashboard-read"
rigScript <<'EOF'
turn
wait list 5
get f
EOF
rigAssert "a read that fails says so in a box, whole" "[$( rigVal f.dialogTitle )] [$( rigVal f.failed )] $( rigVal f.dialogHolds | LC_ALL=C grep -c -F -- 'operation: --manager-dashboard-read' )" "[A read failed] [list:dashboard] 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN DASHBOARD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_DASHBOARD: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
