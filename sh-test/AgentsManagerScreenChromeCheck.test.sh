#!/usr/bin/env bash
## Behavioural check on the look of the manager screen (sh-lib/AgentsManagerScreen.py) and on what draws it from its
## declaration, run rather than read. The screen's own code draws through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.test.py), which keeps the cells it is given and the look of each, so each case
## reads the screen back; the cases at the end start the real screen on a pseudo-terminal the driver makes. Held, in the
## Turbo Vision style, which a screen starts in: the first line is the menu bar, the system mark and the menus of MENUS,
## each with its hot letter in a look of its own, and at its right end the workspace, an `@` in a look of its own, the
## machine the row of counters names, and the clock; the windows of WINDOWS stand in frames, the active one in a double
## frame and the other in a single one, the title of each in the middle of its top border; a list longer than its
## window has a scroll bar for its right border; the counters stand in the bottom border of the left window and the
## load in that of the list; the last line names the keys that work now, each key in the look of a hot letter, and
## changes with the window that is active and with the row that is selected. F10 opens the first menu and Alt with its
## hot letter any menu: a pull-down in a frame with its items, their hot letters, their keys at the right, a line
## between two groups, its shadow, and an item that does not apply greyed; the arrows move, Enter and the hot letter of
## an item choose it, which does what the key of that command does, an item that does not apply is not chosen, and Esc
## closes. The styles of STYLES: F9 takes the next one at once; the compact one draws the two panes between two status
## lines with no frame at all, and its menu all the same; B/W draws what Turbo Vision draws; a name that is no style
## is refused. On a real terminal with colours the screen sets colours, on one with none it comes up all the same and
## sets none, a style without colours sets none on a terminal that has them, and Alt-X ends it with status 0.
## Offline: the only thing the screen calls here is the stand-in for the dispatcher (check-fixtures/manager-screen.tools.test.sh).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.test.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
"$rigPython" -I -c 'import curses' 2> /dev/null || rigRefuse "the python3 on PATH has no curses module, so the real screen cannot be started here: $rigPython"
rigTmp="$( mktemp -d -t AgentsManagerScreenChromeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/rig" "$rigTmp/ws-rig"
export MANAGER_SCREEN_RIG="$rigTmp/rig"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigFixtures/manager-screen.tools.test.sh" > "$rigTmp/tools"
chmod +x "$rigTmp/tools"
printf 's1\tfirst\ns2\tsecond\n' > "$rigTmp/rig/rows"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigScript(){ ## the commands of the driver on standard input; what it printed is kept in rigOut
	rigOut="$( "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigLine(){ ## tag, line counted from 1 -- that line of the screen, as drawn
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/|$//'
}
rigLines(){ ## tag -- how many lines that screen has
	printf '%s\n' "$rigOut" | LC_ALL=C grep -c "^$1|" || :
}
rigBetween(){ ## number, low, high
	if [ "$1" -ge "$2" ] 2> /dev/null && [ "$1" -le "$3" ] ; then printf yes ; else printf 'no (%s)' "$1" ; fi
}
rigRepeat(){ ## text, count
	local repeatText="" repeatLeft="$2"
	while [ "$repeatLeft" -gt 0 ] ; do repeatText="$repeatText$1" ; repeatLeft=$(( repeatLeft - 1 )) ; done
	printf '%s' "$repeatText"
}
rigPty(){ ## columns, lines, the text to wait for, keys, the command... -- what the driver says of the run is kept in rigOut
	local ptyColumns="$1" ptyLines="$2" ptyWait="$3" ptyKeys="$4" ; shift 4
	rigOut="$( "$rigPython" -I -B "$rigDriver" "$rigScreen" pty "$ptyColumns" "$ptyLines" "$ptyWait" "$ptyKeys" 60 -- "$@" 2>&1 )"
}

printf 'counters\t2\t0\t1\t2\t3\t0.42\trig-host\n' > "$rigTmp/rig/rows.--manager-session-list"
rigRole(){ ## tag, line counted from 1, the cells from and to counted from 1 -- the letter of each of those cells in a drawing of looks or of roles
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -n "${2}p" | LC_ALL=C cut -c"$3-$4"
}
rigHas(){ ## tag, text -- how many lines of that screen hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigSqueeze(){ ## a line with every run of spaces as one
	LC_ALL=C sed -e 's/  */ /g'
}
rigStart(){ ## the commands every case starts with: the row of counters is read, then the list holds sixty rows and is entered
	printf 'tools %s\ntable list:pending none\nsize 120 40\nworkspace /somewhere/ws-rig\nclock 12:34:56\nwait sessions 30\ntable list:sessions none\nrowsgen sessions 60\nkeys ENTER\nturn\n' "$rigTmp/tools"
}
rigRun(){ ## the commands of the driver on standard input, after the ones every case starts with; what it printed is kept in rigOut
	rigOut="$( { rigStart ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}

echo "-- the menu bar, the windows in their frames, the status line --"
rigRun <<'RIGSCRIPT'
get a
show a
roles r
looks k
cells where 0 94 120
border viewTitle 1 0 84
border listTitle 1 84 120
cells corners 1 0 120
cells barTop 2 119 120
cells barThumb 3 119 120
cells barTrack 20 119 120
cells barEnd 37 119 120
cells viewSide 20 83 84
border foot 38 0 84
border load 38 84 120
cells status 39 0 120
keys TAB
get t
cells cornersT 1 0 120
cells statusT 39 0 120
keys TAB DOWN DOWN
turn
get row
cells statusRow 39 0 120
RIGSCRIPT
rigAssert "the screen starts in the Turbo Vision style, and nothing is drawn past a line" "$( rigVal a.style ) $( rigVal a.layout ) $( rigLines a ) $( rigVal a.spills )" "tv ok 40 0"
rigAssert "the first line is the menu bar: the system mark, the menus, and at its right end the workspace, the machine and the clock" "$( rigLine a 1 | rigSqueeze )" " ≡ Go Session Member View Help ws-rig@rig-host 12:34:56 "
rigAssert "each menu has its hot letter in a look of its own"        "$( rigRole r 1 1 36 )" "mmmmhmmmhmmmmmmmmhmmmmmmmhmmmmmhmmmm"
rigAssert "the @ between the workspace and the machine has a look of its own, apart from the two names, also with no colour" "[$( rigVal where )] $( rigRole r 1 95 110 ) $( rigRole k 1 95 110 )" "[ws-rig@rig-host  12:34:56] mmmmmm@mmmmmmmmm RRRRRRHRRRRRRRRR"
rigAssert "each window carries its title in the middle of its top border" "[$( rigVal viewTitle )] [$( rigVal listTitle )]" "[..] [Sessions / Activity]"
rigAssert "the active window, the list, has a double frame, and the other a single one" "[$( rigVal corners )]" "[┌─────────────────────────────────────── .. ───────────────────────────────────────┐╔══════ Sessions / Activity ═══════╗]"
rigAssert "a list longer than its window has a scroll bar for its right border, and the other window its plain border" "[$( rigVal barTop )][$( rigVal barThumb )][$( rigVal barTrack )][$( rigVal barEnd )] [$( rigVal viewSide )] $( rigVal a.rows )" "[▲][■][▒][▼] [│] 62"
rigAssert "the counters stand in the bottom border of the left window, and the load in that of the list" "[$( rigVal foot )] [$( rigVal load )]" "[running 2  paused 0  working 1  waiting 2  pending 3] [load 0.42]"
rigAssert "the last line names the keys that work now, each key in the look of a hot letter" "[$( rigVal status )] $( rigRole r 40 1 9 )" "[ Enter Open  Left Up  a All/active  F5 Read  F10 Menu  Alt-X Exit  Tab Window] mhhhhhmmm"
rigAssert "Tab makes the other window the active one: the frames change places" "$( rigVal t.focus ) [$( rigVal cornersT )]" "view [╔═══════════════════════════════════════ .. ═══════════════════════════════════════╗┌────── Sessions / Activity ───────┐]"
rigAssert "and the status line names the keys of that window"        "[$( rigVal statusT )]" "[ F5 Read  F10 Menu  Alt-X Exit  Tab Window]"
rigAssert "with a row selected it names the keys that act on that row too" "$( rigVal row.selected ) [$( rigVal statusRow )]" "r001 [ Left Up  a All/active  l Log  F5 Read  F10 Menu  Alt-X Exit  Tab Window]"

echo "-- the menus --"
rigRun <<'RIGSCRIPT'
keys F10
get m
show m
roles mr
keys DOWN DOWN
get m2
keys RIGHT
get s
roles sr
keys ESC
get closed
keys ALT-v
get v
keys DOWN ENTER
get chosen
keys a
get keyed
keys ALT-g t
get team
keys F10 RIGHT ENTER
get grey
keys ESC ALT-x
get out
RIGSCRIPT
rigAssert "F10 opens the first menu, its bar on its first item"     "$( rigVal m.menu )" "go:sessions"
rigAssert "the pull-down is a frame with its items, their keys at the right, and a line between two groups" "$( rigHas m '┌───' ) $( rigHas m '│ Sessions / Activity       Alt-1 │' ) $( rigHas m '│ Exit                      Alt-X │' ) $( rigHas m '├───' ) $( rigHas m '└───' )" "1 1 1 3 1"
rigAssert "the item the bar is on stands in the look of the bar, another has its hot letter in a look of its own, and the pull-down has a shadow" "$( rigRole mr 3 4 9 ) $( rigRole mr 4 4 9 ) $( rigRole mr 4 39 40 )" "moOooo mmhmmm ww"
rigAssert "the status line names the keys of a menu"                 "$( rigLine m 40 | LC_ALL=C sed -e 's/  *$//' )" " Enter Choose  Esc Close  Left/Right Menus  Up/Down Items"
rigAssert "Down moves the bar"                                       "$( rigVal m2.menu )" "go:team"
rigAssert "Right opens the menu beside it"                           "$( rigVal s.menu )" "session:kill"
rigAssert "an item that does not apply to the row selected is greyed" "$( rigRole sr 4 9 14 )" "xxxxxx"
rigAssert "Esc closes the menu"                                      "[$( rigVal closed.menu )]" "[]"
rigAssert "Alt with the hot letter of a menu opens that menu"        "$( rigVal v.menu )" "view:read"
rigAssert "Enter chooses the item the bar is on: the menu closes, and the command is done" "[$( rigVal chosen.menu )] $( rigVal chosen.filter )" "[] active"
rigAssert "the key of that command does the same"                    "$( rigVal keyed.filter )" "all"
rigAssert "the hot letter of an item chooses it"                     "[$( rigVal team.menu )] $( rigVal team.path )" "[] team"
rigAssert "an item that does not apply is not chosen: the menu stays, and nothing is done" "$( rigVal grey.menu ) [$( rigVal grey.notice )] [$( rigVal grey.dialog )]" "session:kill [] []"
rigAssert "Alt-X ends the screen"                                    "$( rigVal out.quit )" "yes"

echo "-- the styles --"
rigRun <<'RIGSCRIPT'
get tv
show t
keys F9
get mc
show c
looks ck
keys F10
get cm
show cmenu
keys ESC F9
get bw
show b
keys F9
get back
style nonsense
get still
RIGSCRIPT
rigAssert "F9 takes the next style at once, and the status line says which" "$( rigVal tv.style ) $( rigVal mc.style ) [$( rigVal mc.notice )]" "tv mc [interface style: MC (Compact)]"
rigAssert "the compact style has a status line on top: the workspace, the machine, the load and the clock" "$( rigLine c 1 | rigSqueeze )" " ws-rig@rig-host load 0.42 12:34:56 "
rigAssert "and one at the bottom: the counters, then the keys that act now, the menu key among them" "$( rigLine c 40 | LC_ALL=C sed -e 's/  *$//' )" " running 2  paused 0  working 1  waiting 2  pending 3  Enter Open  Left Up  a All/active  F5 Read  F10 Menu  Alt-X Exit"
rigAssert "it spends nothing on frames: one column parts the two panes, and the list has a line more" "$( rigHas c '║' ) $( rigHas c '┌' ) $( rigHas c '└' ) $( rigHas c '│' ) $( rigVal mc.listHeight ) $( rigVal mc.viewHeight )" "0 0 0 38 37 36"
rigAssert "its @ stands apart too, in a line that is otherwise in one look" "$( rigLine ck 1 | LC_ALL=C tr -d R )" "B"
rigAssert "the menu exists in it: F10 shows the menu bar on the top line and the pull-down under it" "$( rigVal cm.menu ) [$( rigLine cmenu 1 | rigSqueeze | LC_ALL=C cut -c1-32 )] $( rigHas cmenu '│ Sessions / Activity       Alt-1 │' )" "go:sessions [ ≡ Go Session Member View Help] 1"
rigAssert "B/W is the next: it draws what Turbo Vision draws, cell for cell" "$( rigVal bw.style ) $( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^b|//p' | LC_ALL=C sed -n '1,39p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^t|//p' | LC_ALL=C sed -n '1,39p' )" ] && echo same || echo differs )" "bw same"
rigAssert "and after the last style comes the first again"          "$( rigVal back.style )" "tv"
rigAssert "a name that is no style is refused, and the style stays"  "$( rigVal style.refused ) $( rigVal still.style )" "nonsense tv"

echo "-- the real screen, on a terminal with colours and on one with none --"
rigPty 100 30 "Sessions / Activity" '\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "on a terminal with colours the screen comes up in its colours, and Alt-X ends it with status 0" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.errorAfterLeft )" "yes yes 0 yes none"
MANAGER_SCREEN_PTY_TERM=vt100 rigPty 100 30 "Sessions / Activity" '\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "on a terminal with no colours it comes up all the same, and sets none" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.rc ) $( rigVal pty.errorAfterLeft )" "yes no 0 none"
rigPty 100 30 "Sessions / Activity" '\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" --style bw
rigAssert "started in the style B/W it sets no colour on a terminal that has them" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.rc )" "yes no 0"
MDAT_MANAGER_STYLE=mc rigPty 100 30 "a All/active  F5 Read" q "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "the environment names the style of a start: the compact one comes up, and q ends it" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.rc )" "yes no 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN CHROME CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_CHROME: OK (%d assertions, offline, stand-in terminal and one pseudo-terminal)\n' "$rigPassCount"
