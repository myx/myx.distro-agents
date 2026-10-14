#!/usr/bin/env bash
## Behavioural check on the mouse of the manager screen (sh-lib/AgentsManagerScreen.py), run rather than read. The
## screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.test.py),
## which feeds it an event of the mouse at a cell as one turn. Held: a click inside a window gives it the keys; a
## click on a row of the list selects that row, and a second click on the selected row, or a double click, opens it
## as Enter does; the wheel moves in the window under the pointer; a click on a half of the scroll bar pages. A click
## on a name of the menu bar opens that menu, a click on an item chooses it, and a click outside closes the menu and
## does nothing else. In a dialog a click on a button presses it, on a box toggles it, on a radio button and on a row
## of a list chooses it, on a field gives it the keys, and a click outside the dialog does nothing. A click on a key
## the status line shows does what that key does. What curses reports of the mouse becomes a click, when the first
## button is let go, a double click and the wheel, and nothing else. The real screen comes up and is ended by a click on the menu bar and the hot
## letter of Exit on a terminal that reports the mouse, and comes up all the same on one that reports none.
## Offline: the only thing the real screen calls here is the stand-in for the dispatcher (check-fixtures/manager-screen.tools.test.sh).
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
rigTmp="$( mktemp -d -t AgentsManagerScreenMouseCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/rig" "$rigTmp/ws-rig"
export MANAGER_SCREEN_RIG="$rigTmp/rig"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigFixtures/manager-screen.tools.test.sh" > "$rigTmp/tools"
chmod +x "$rigTmp/tools"
printf 's1\tfirst\ns2\tsecond\n' > "$rigTmp/rig/rows"
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
rigRun(){ ## the commands of the driver on standard input, after the ones every case starts with: a list of sixty sessions, entered; what it printed is kept in rigOut
	rigOut="$( { printf 'size 120 40\nrowsgen sessions 60\nroot sessions\nkeys ENTER\nturn\n' ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigVals(){ ## name -- the values of every `<name>=` line, a space between them
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed -e 's/ $//'
}
rigPty(){ ## columns, lines, the text to wait for, keys, the command... -- what the driver says of the run is kept in rigOut
	local ptyColumns="$1" ptyLines="$2" ptyWait="$3" ptyKeys="$4" ; shift 4
	rigOut="$( "$rigPython" -I -B "$rigDriver" "$rigScreen" pty "$ptyColumns" "$ptyLines" "$ptyWait" "$ptyKeys" 60 -- "$@" 2>&1 )"
}

echo "-- the panes: a click gives the keys, selects a row, opens it; the wheel; the scroll bar --"
rigRun <<'RIGSCRIPT'
mouse click 10 10
get view
mouse click 90 4
get row
mouse click 90 3
get other
mouse click 90 3
get opened
keys BACKSPACE BACKSPACE
get root
cells doubledRow 4 85 119
mouse double 90 4
get doubled
border doubledTitle 1 84 120
keys ALT-2
get before
mouse down 90 10
mouse down 90 10
get wheeled
mouse up 90 10
get back
view 100
mouse down 10 10
get viewDown
mouse up 10 10
get viewUp
mouse click 119 30
get paged
mouse click 119 5
get pagedUp
RIGSCRIPT
rigAssert "a click inside the left window gives it the keys, and selects nothing" "$( rigVal view.focus ) $( rigVal view.selected )" "view .."
rigAssert "a click on a row of the list selects that row, and the list has the keys" "$( rigVal row.focus ) $( rigVal row.selected ) $( rigVal row.path )" "list r001 sessions"
rigAssert "a click on another row selects that one, and opens nothing" "$( rigVal other.selected ) $( rigVal other.path )" "launch sessions"
rigAssert "a second click on the selected row opens it, as Enter does" "$( rigVal opened.path )" "sessions/launch"
rigAssert "a double click on a row of the root selects it and opens it: the list is then in the row that was clicked, whichever root stands on that line" "[$( rigVal root.path )] $( [ -n "$( rigVal doubled.path )" ] && echo opened ) $( rigVal doubledTitle | LC_ALL=C grep -c -F -- "$( rigVal doubledRow | LC_ALL=C sed -e 's/^ //' -e 's/  *►$//' )" )" "[] opened 1"
rigAssert "the wheel moves the selection of the list under the pointer, down and up" "$(( $( rigVal wheeled.index ) - $( rigVal before.index ) )) $(( $( rigVal back.index ) - $( rigVal wheeled.index ) )) $( rigVal back.focus )" "2 -1 list"
rigAssert "over the left window it scrolls that window, and the keys stay where they were" "$( rigVal viewDown.viewTop ) $( rigVal viewUp.viewTop ) $( rigVal viewDown.focus )" "3 0 list"
rigAssert "a click on the lower half of the scroll bar pages down, on the upper half up" "$( [ "$( rigVal paged.index )" -gt 30 ] && echo down ) $( [ "$( rigVal pagedUp.index )" -lt 10 ] && echo up ) $( rigVal paged.spills )" "down up 0"

echo "-- the menus: a name opens, an item chooses, a click outside closes --"
rigRun <<'RIGSCRIPT'
mouse click 17 0
get menu
mouse click 19 3
get chosen
mouse click 8 0
get session
mouse click 100 30
get outside
mouse click 4 0
get go
mouse click 4 0
get same
mouse click 4 0
mouse click 17 0
get member
RIGSCRIPT
rigAssert "a click on a name in the menu bar opens that menu"        "$( rigVal menu.menu )" "view:read"
rigAssert "a click on an item chooses it: the menu closes, and the command is done" "[$( rigVal chosen.menu )] $( rigVal chosen.filter )" "[] active"
rigAssert "a click outside an open menu closes it, and does nothing else" "$( rigVal session.menu ) [$( rigVal outside.menu )] $( rigVal outside.selected ) $( rigVal outside.focus )" "session:kill [] .. list"
rigAssert "a click on the name of the open menu closes it, and on another name opens that one" "$( rigVal go.menu ) [$( rigVal same.menu )] $( rigVal member.menu )" "go:dashboard [] view:read"

echo "-- a dialog: buttons, boxes, radio buttons, a list, a field; and nothing outside it --"
rigRun <<'RIGSCRIPT'
rigdialog What the rig asks.
turn
mouse click 40 18
get who
mouse click 40 23
get how
mouse click 40 29
get pick
mouse click 40 9
get name
mouse click 5 5
mouse click 100 3
mouse click 25 0
get outside
mouse click 60 31
get cancel
rigdialog What the rig asks.
turn
mouse click 40 19
mouse click 52 31
get ok
rigdialog What the rig asks.
turn
get before
mouse click 35 5
get closed
RIGSCRIPT
rigAssert "a click on a box toggles it, and the keys are on the boxes" "$( rigVal who.dialog )" "rig:who|b,a"
rigAssert "a click on a radio button chooses it, and on a row of a list picks it" "$( rigVal how.dialog ) $( rigVal pick.dialog )" "rig:how|x rig:pick|p3"
rigAssert "a click on a field gives it the keys"                      "$( rigVal name.dialog )" "rig:name|typed"
rigAssert "a click outside the dialog does nothing: no window, no row, no menu" "$( rigVal outside.dialog ) $( rigVal outside.focus ) $( rigVal outside.selected ) [$( rigVal outside.menu )]" "rig:name|typed list .. []"
rigAssert "a click on Cancel closes the dialog and calls nothing"     "[$( rigVal cancel.dialog )] [$( rigVal cancel.notice )]" "[] []"
rigAssert "a click on OK presses it: its handler has what was clicked" "[$( rigVal ok.dialog )] [$( rigVal ok.notice )]" "[] [pressed ok: name=typed notes= who= how=y pick=p1]"
rigAssert "in Turbo Vision a click on the box that closes it, at the left of its top border, does what Esc does" "$( rigVal before.dialogBox ) [$( rigVal closed.dialog )] $( [ "$( rigVal before.notice )" = "$( rigVal closed.notice )" ] && echo nothing-more-said || echo said )" "32,5,56,29 [] nothing-more-said"

echo "-- the status line: a click on a key does what the key does --"
rigRun <<'RIGSCRIPT'
mouse click 90 4
turn
cells st 39 0 120
mouse click 12 39
get filtered
mouse click 29 39
get menu
turn
cells stMenu 39 0 120
mouse click 16 39
get closed
mouse click 3 39
get up
rigdialog What the rig asks.
turn
cells stDialog 39 0 120
mouse click 24 39
get cancelled
RIGSCRIPT
rigAssert "the status line as it is clicked on"                      "[$( rigVal st )]" "[ BSP Up  a Active  u Read  m Menu  ^X Exit  TAB Window  ? Help]"
rigAssert "a click on a key of a command does that command"          "$( rigVal filtered.filter ) $( rigVal menu.menu )" "active go:dashboard"
rigAssert "with a menu open a click on Esc closes it"                "[$( rigVal stMenu )] [$( rigVal closed.menu )]" "[ ENTER Choose  ESC Close  ←/→ Menus  UP/DN Items] []"
rigAssert "a click on Backspace goes up one level"                        "[$( rigVal up.path )]" "[]"
rigAssert "with a dialog open a click on Esc cancels it"             "[$( rigVal stDialog )] [$( rigVal cancelled.dialog )]" "[ ENTER OK  TAB Next  ESC Cancel] []"

echo "-- what curses reports of the mouse --"
rigOut="$( printf '%s\n' 'mousekey 5 7 BUTTON1_RELEASED' 'mousekey 5 7 BUTTON1_CLICKED' 'mousekey 5 7 BUTTON1_DOUBLE_CLICKED' 'mousekey 5 7 BUTTON4_PRESSED' 'mousekey 5 7 BUTTON5_PRESSED' 'mousekey 5 7 BUTTON1_PRESSED' 'mousekey 5 7 BUTTON3_PRESSED' | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
rigAssert "the first button let go, and its click, are a click, a double click is one, the wheel is up and down, a press alone is a press, which is nothing but on the border between the windows, and another button is nothing" "$( rigVals mousekey )" "MOUSE:click:5:7 MOUSE:click:5:7 MOUSE:double:5:7 MOUSE:up:5:7 MOUSE:down:5:7 MOUSE:press:5:7 "

echo "-- the real screen, on a terminal that reports the mouse and on one that reports none --"
rigPty 100 30 "Sessions (Activity)" '\e[M %!\e[M#%!x' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "a click on Go in the menu bar, as an xterm reports it, opens that menu, and the hot letter of Exit ends the screen with status 0" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.errorAfterLeft )" "yes 0 yes none"
MANAGER_SCREEN_PTY_TERM=vt100 rigPty 100 30 "Sessions (Activity)" '\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "on a terminal that reports no mouse the screen comes up all the same, and Esc and then x ends it" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.errorAfterLeft )" "yes 0 none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN MOUSE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_MOUSE: OK (%d assertions, offline, stand-in terminal and two pseudo-terminals)\n' "$rigPassCount"
