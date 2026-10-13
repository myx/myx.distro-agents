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
## The menus follow the view, the level the list is at: a menu with no command of the view is not in the bar, the commands
## of a view all stand in its menus, and one that does not apply to the row selected is greyed and, tried, says why.
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
	printf 'tools %s\ntable list:pending none\nsize 120 40\nworkspace /somewhere/ws-rig\nclock 12:34:56\nwait sessions 30\ntable list:sessions none\nrowsgen sessions 60\nroot sessions\nkeys ENTER\nturn\n' "$rigTmp/tools"
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
rigAssert "the first line is the menu bar: the system mark, the menus, and at its right end the workspace, the machine and the clock" "$( rigLine a 1 | rigSqueeze )" " ≡ Go Session View Help ws-rig@rig-host 12:34:56 "
rigAssert "each menu has its hot letter in a look of its own"        "$( rigRole r 1 1 36 )" "mmmmhmmmhmmmmmmmmhmmmmmhmmmmmmmmmmmm"
rigAssert "the @ between the workspace and the machine has a look of its own, apart from the two names, also with no colour" "[$( rigVal where )] $( rigRole r 1 95 110 ) $( rigRole k 1 95 110 )" "[ws-rig@rig-host  12:34:56] mmmmmm@mmmmmmmmm RRRRRRHRRRRRRRRR"
rigAssert "each window carries its title in the middle of its top border" "[$( rigVal viewTitle )] [$( rigVal listTitle )]" "[Sessions (Activity) [wrap]] [Sessions (Activity)]"
rigAssert "the active window, the list, has a double frame, and the other a single one" "[$( rigVal corners )]" "[┌─────────────────────────── Sessions (Activity) [wrap] ───────────────────────────┐╔══════ Sessions (Activity) ═══════╗]"
rigAssert "a list longer than its window has a scroll bar for its right border, and the other window its plain border" "[$( rigVal barTop )][$( rigVal barThumb )][$( rigVal barTrack )][$( rigVal barEnd )] [$( rigVal viewSide )] $( rigVal a.rows )" "[▲][■][▒][▼] [│] 62"
rigAssert "the bottom borders of the two windows are plain: the counters and the load are the dashboard's" "[$( rigVal foot )] [$( rigVal load )] $( rigVal a.counters | LC_ALL=C grep -c 'load=0.42' )" "[] [] 1"
rigAssert "the last line names the keys that work now, each key in the look of a hot letter" "[$( rigVal status )] $( rigRole r 40 1 9 )" "[ Enter Open  Left Up  a Active  u Read  m Menu  ^X Exit  Tab Window] mhhhhhmmm"
rigAssert "Tab makes the other window the active one: the frames change places" "$( rigVal t.focus ) [$( rigVal cornersT )]" "view [╔═══════════════════════════ Sessions (Activity) [wrap] ═══════════════════════════╗┌────── Sessions (Activity) ───────┐]"
rigAssert "and the status line names the keys of that window"        "[$( rigVal statusT )]" "[ w Cut  u Read  m Menu  ^X Exit  Tab Window]"
rigAssert "with a row selected it names the keys that act on that row too" "$( rigVal row.selected ) [$( rigVal statusRow )]" "r001 [ Left Up  a Active  u Read  m Menu  ^X Exit  Tab Window]"

echo "-- the menus --"
rigRun <<'RIGSCRIPT'
keys F10
get m
show m
roles mr
keys DOWN DOWN DOWN
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
rigAssert "F10 opens the first menu, its bar on its first item"     "$( rigVal m.menu )" "go:dashboard"
rigAssert "the pull-down is a frame with its items, their keys at the right, and a line between two groups" "$( rigHas m '┌───' ) $( rigHas m '│ Sessions (Activity)      1 │' ) $( rigHas m '│ Exit                    ^X │' ) $( rigHas m '├───' ) $( rigHas m '└───' )" "1 1 1 3 2"
rigAssert "the item the bar is on stands in the look of the bar, another has its hot letter in a look of its own, and the pull-down has a shadow" "$( rigRole mr 3 4 9 ) $( rigRole mr 4 4 9 ) $( rigRole mr 4 34 35 )" "moOooo mmhmmm ww"
rigAssert "the status line names the keys of a menu"                 "$( rigLine m 40 | LC_ALL=C sed -e 's/  *$//' )" " Enter Choose  Esc Close  Left/Right Menus  Up/Down Items"
rigAssert "Down moves the bar"                                       "$( rigVal m2.menu )" "go:team"
rigAssert "Right opens the menu beside it"                           "$( rigVal s.menu )" "session:kill"
rigAssert "an item that does not apply to the row selected is greyed" "$( rigRole sr 4 9 14 )" "xxxxxx"
rigAssert "Esc closes the menu"                                      "[$( rigVal closed.menu )]" "[]"
rigAssert "Alt with the hot letter of a menu opens that menu"        "$( rigVal v.menu )" "view:read"
rigAssert "Enter chooses the item the bar is on: the menu closes, and the command is done" "[$( rigVal chosen.menu )] $( rigVal chosen.filter )" "[] active"
rigAssert "the key of that command does the same"                    "$( rigVal keyed.filter )" "all"
rigAssert "the hot letter of an item chooses it"                     "[$( rigVal team.menu )] $( rigVal team.path )" "[] team"
rigAssert "an item that does not apply is not chosen: the menu stays, nothing is done, and the status line says why" "$( rigVal grey.menu ) [$( rigVal grey.notice )] [$( rigVal grey.dialog )]" "member:start [Start: for a team member, not for what is selected] []"
rigAssert "Alt-X ends the screen"                                    "$( rigVal out.quit )" "yes"

echo "-- the menus follow the view --"
rigRun <<'RIGSCRIPT'
cells barSessions 0 0 40
keys DOWN DOWN
turn
keys ALT-s
show ss
roles ssr
mouse click 10 5
get clicked
keys ESC k
get byKey
keys n
get otherView
keys 5
turn
cells barLaunch 0 0 40
keys ALT-s
show sl
keys ESC 2
turn
cells barPending 0 0 40
keys 3
turn
cells barTeam 0 0 40
keys 4
turn
cells barSettings 0 0 40
keys LEFT
turn
cells barRoot 0 0 40
keys ALT-s
get noMenuS
keys ALT-q
get noMenuQ
RIGSCRIPT
rigAssert "a menu with no command of the view is not in the bar: at the root the system mark, Go, View and Help alone, and each view with its own beside them" "[$( rigVal barRoot | rigSqueeze )] [$( rigVal barSessions | rigSqueeze )] [$( rigVal barLaunch | rigSqueeze )] [$( rigVal barPending | rigSqueeze )] [$( rigVal barTeam | rigSqueeze )] [$( rigVal barSettings | rigSqueeze )]" "[ ≡ Go View Help] [ ≡ Go Session View Help] [ ≡ Go Session View Help] [ ≡ Go View Question Help] [ ≡ Go Member View Help] [ ≡ Go View Help]"
rigAssert "Alt with the letter of a menu that is not in the bar opens nothing" "[$( rigVal noMenuS.menu )] [$( rigVal noMenuQ.menu )]" "[] []"
rigAssert "in a view every command of it stands in its menu, and none of another view: the sessions" "$( rigHas ss '│ Kill ' ) $( rigHas ss '│ Control thread' ) $( rigHas ss '│ Pause' ) $( rigHas ss '│ Restart' ) $( rigHas ss 'Start the routine' ) $( rigHas ss 'Free prompt' )" "1 1 1 1 0 0"
rigAssert "and Launch / Spawn, whose menu of the same name holds its two alone" "$( rigHas sl '│ Start the routine' ) $( rigHas sl '│ Free prompt' ) $( rigHas sl '│ Kill ' ) $( rigHas sl '│ Pause' )" "1 1 0 0"
rigAssert "one that does not apply to the row selected is greyed" "$( rigRole ssr 6 9 14 )" "xxxxxx"
rigAssert "clicked, it is not chosen: the menu stays, and the status line says why" "$( rigVal clicked.menu ) [$( rigVal clicked.notice )] [$( rigVal clicked.dialog )]" "session:pause [Pause is not built yet] []"
rigAssert "tried by its key, it says why in the status line, and no box opens" "[$( rigVal byKey.notice )] [$( rigVal byKey.dialog )]" "[Kill: not for what is selected, as it is now] []"
rigAssert "the key of a command of another view is no key here: nothing opens, and the status line keeps what it said" "[$( rigVal otherView.notice )] [$( rigVal otherView.dialog )]" "[Kill: not for what is selected, as it is now] []"

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
rigAssert "and one at the bottom: the counters, then the keys that act now, the menu key among them" "$( rigLine c 40 | LC_ALL=C sed -e 's/  *$//' )" " running 2  paused 0  working 1  waiting 2  pending 3  Enter Open  Left Up  a Active  u Read  m Menu  q Exit  Tab Window"
rigAssert "it spends nothing on frames: one column parts the two panes, and the list has a line more" "$( rigHas c '║' ) $( rigHas c '┌' ) $( rigHas c '└' ) $( rigHas c '│' ) $( rigVal mc.listHeight ) $( rigVal mc.viewHeight )" "0 0 0 38 37 36"
rigAssert "its @ stands apart too, in a line that is otherwise in one look" "$( rigLine ck 1 | LC_ALL=C tr -d R )" "B"
rigAssert "the menu exists in it: F10 shows the menu bar on the top line and the pull-down under it" "$( rigVal cm.menu ) [$( rigLine cmenu 1 | rigSqueeze | LC_ALL=C cut -c1-41 )] $( rigHas cmenu '│ Sessions (Activity)      1 │' )" "go:dashboard [ ≡ Go Session View Help ws-rig@rig-host] 1"
rigAssert "B/W is the next: it draws what Turbo Vision draws, cell for cell" "$( rigVal bw.style ) $( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^b|//p' | LC_ALL=C sed -n '1,39p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^t|//p' | LC_ALL=C sed -n '1,39p' )" ] && echo same || echo differs )" "bw same"
rigAssert "and after the last style comes the first again"          "$( rigVal back.style )" "tv"
rigAssert "a name that is no style is refused, and the style stays"  "$( rigVal style.refused ) $( rigVal still.style )" "nonsense tv"

echo "-- the real screen, on a terminal with colours and on one with none --"
rigPty 100 30 "Sessions (Activity)" '\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "on a terminal with colours the screen comes up in its colours, and Alt-X ends it with status 0" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.errorAfterLeft )" "yes yes 0 yes none"
MANAGER_SCREEN_PTY_TERM=vt100 rigPty 100 30 "Sessions (Activity)" '\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "on a terminal with no colours it comes up all the same, and sets none" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.rc ) $( rigVal pty.errorAfterLeft )" "yes no 0 none"
rigPty 100 30 "Sessions (Activity)" '\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" --style bw
rigAssert "started in the style B/W it sets no colour on a terminal that has them" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.rc )" "yes no 0"
MDAT_MANAGER_STYLE=mc rigPty 100 30 "a Active  u Read" q "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "the environment names the style of a start: the compact one comes up, and q ends it" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.rc )" "yes no 0"

echo "-- the machine's name stands whole: in a narrow top line the workspace gives way first, then the seconds, then the start of the machine's name --"
mkdir -p "$rigTmp/long" ; : > "$rigTmp/long/calls" ; echo rows > "$rigTmp/long/mode"
printf 'counters\t2\t0\t1\t2\t3\t0.42\tmagic-mac-studio.office.example.net\n' > "$rigTmp/long/rows.--manager-session-list"
for rigStyle in tv mc ; do
	MANAGER_SCREEN_RIG="$rigTmp/long" rigScript <<RIGSCRIPT
style $rigStyle
tools bash $MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/manager-screen.tools.test.sh
workspace /rig/workspace.mdci
clock 12:34:56
size 120 30
wait sessions 30
turn
cells w120 0 46 120
size 69 30
turn
cells w96 0 19 69
size 63 30
turn
cells w90 0 19 63
size 60 30
turn
cells c60 0 0 60
size 40 30
turn
cells w60 0 0 40
roles r60
RIGSCRIPT
	[ "$rigStyle" = tv ] || break
	rigAssert "with room for all of it the workspace, the machine by its full name, and the clock stand whole" "[$( rigVal w120 | LC_ALL=C sed -e 's/^ *//' )]" "[workspace.mdci@magic-mac-studio.office.example.net  12:34:56]"
	rigAssert "the workspace's name is cut first, from its left, with the cut mark" "[$( rigVal w96 | LC_ALL=C sed -e 's/^ *//' )]" "[…i@magic-mac-studio.office.example.net  12:34:56]"
	rigAssert "then the clock loses its seconds, and only then the machine's name its start, never its end" "[$( rigVal w90 | LC_ALL=C sed -e 's/^ *//' )] [$( rigVal w60 )]" "[…@…ic-mac-studio.office.example.net  12:34] [ ≡  Go  View  Help  …@…ample.net  12:34]"
	rigAssert "the @ keeps its own look"                                  "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^r60|//p' | LC_ALL=C sed -n '1p' | LC_ALL=C tr -d -c '@' )" "@"
done
rigAssert "the compact style cuts in the same order: the workspace first, the machine's name whole beside the load and the clock" "[$( rigVal c60 )]" "[ …i@magic-mac-studio.office.example.net load 0.42  12:34:56]"

echo "-- the exit: Esc and then x as a terminal sends it and as a hand types it, Ctrl-X, and what Option types on a Mac --"
rigPty 100 30 "Sessions (Activity)" '\e\px' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "Esc, and x a moment after it, typed by hand, ends the real screen in Turbo Vision" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.errorAfterLeft )" "yes 0 yes none"
rigPty 100 30 "Sessions (Activity)" '\e\px' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" --style bw
rigAssert "and in B/W"                                                "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left )" "yes 0 yes"
rigPty 100 30 "Sessions (Activity)" '\x18' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "Ctrl-X ends the real screen: the key every terminal delivers" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.errorAfterLeft )" "yes 0 yes none"
rigPty 100 30 "Sessions (Activity)" 'm\p\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "with a menu open, Esc with x at once ends the real screen too, as the menu declares" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left )" "yes 0 yes"
rigOut="$( "$rigPython" -I -B "$rigDriver" "$rigScreen" pty 100 30 "Sessions (Activity)" '?\p\ex' 3 -- "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" 2>&1 )"
rigAssert "with a dialog open it ends nothing: no key of the screen works in a dialog, and the screen runs on" "$( rigVal pty.frame ) $( rigVal pty.rc )" "yes timeout"
rigScript <<'RIGSCRIPT'
size 120 40
turn
cells tvStatus 39 0 120
keys m
turn
show tvMenu
keys ESC
keys CTRL-x
get tvOut
RIGSCRIPT
rigAssert "the status line of Turbo Vision names Ctrl-X as the exit, and so does the item of its menu" "$( rigVal tvStatus | LC_ALL=C grep -c -F '^X Exit' ) $( rigVal tvStatus | LC_ALL=C grep -c -F 'Alt-' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F '│ Exit                    ^X │' )" "1 0 1"
rigAssert "Ctrl-X ends the screen in Turbo Vision"                    "$( rigVal tvOut.quit )" "yes"
for rigStyle in bw mc ; do
	rigScript <<RIGSCRIPT
style $rigStyle
size 120 40
turn
cells status 39 0 120
keys CTRL-x
get out
RIGSCRIPT
	rigAssert "Ctrl-X ends the screen in the style $rigStyle"            "$( rigVal out.quit )" "yes"
done
rigAssert "the compact style names q, as before"                      "$( rigVal status | LC_ALL=C grep -c -F 'q Exit' )" "1"
rigScript <<'RIGSCRIPT'
size 120 40
turn
keys ©
get g
keys ESC 1 ß
get s
keys ESC 3 µ
get m
keys ESC √
get v
keys ESC ˙
get h
keys ESC ™
get two
keys ≈
get x
RIGSCRIPT
rigAssert "what Option types on a Mac opens the menu of that letter, where the view has that menu: g, s among the sessions, m in the team, v, h" "$( rigVal g.menu ) $( rigVal s.menu ) $( rigVal m.menu ) $( rigVal v.menu ) $( rigVal h.menu )" "go:dashboard session:kill member:start view:read help:help"
rigAssert "Option with a digit goes to that section, and Option with x ends the screen" "$( rigVal two.path ) $( rigVal x.quit )" "pending yes"
rigScript <<'RIGSCRIPT'
size 120 40
turn
rigdialog
keys ≈ ©
get typed
keys ALT-x
get alt
keys ESC x
get apart
keys m ESC x
get menuApart
keys m ≈
get menuOut
RIGSCRIPT
rigAssert "in a field of a dialog what Option types is text, and ends nothing" "[$( rigVal typed.dialog )] $( rigVal typed.quit )" "[rig:name|typed≈©] no"
rigAssert "Alt-X does nothing in a dialog; Esc closes it, and the x after it is a plain x" "[$( rigVal alt.dialog )] $( rigVal alt.quit ) [$( rigVal apart.dialog )] $( rigVal apart.quit )" "[rig:name|typed≈©] no [] no"
rigAssert "Esc closes a menu, and the x after it is a plain x; with the menu open Option-x ends the screen" "[$( rigVal menuApart.menu )] $( rigVal menuApart.quit ) $( rigVal menuOut.quit )" "[] no yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN CHROME CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_CHROME: OK (%d assertions, offline, stand-in terminal and one pseudo-terminal)\n' "$rigPassCount"
