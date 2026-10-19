#!/usr/bin/env bash
## Behavioural check on the frame of the manager screen (sh-lib/manager/AgentsManagerScreen.py), run rather than read. The
## screen's own code draws through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py),
## which keeps the cells it is given, so each case reads the screen back as text; the cases at the end start the real
## screen, on a pseudo-terminal the driver makes. Held: at 120 and at 80 columns the list on the right takes a quarter
## to a third of the width and the left pane the rest, and the last line of the left pane is the line of its bottom border, where nothing is typed; the
## first and the last line are the status lines, each across the whole width, with the panes between them; a terminal
## that is too small gets one line that says so, and the screen goes on until it is resized or quit; a change of size
## draws everything again at the new widths and leaves nothing of the old drawing; a line that holds a character of
## two cells is cut to the width of its pane and never reaches into the other; for a terminal that is not UTF-8 the
## marks are of one byte and what it cannot show becomes `?`; the quit key ends the real screen with
## status 0 and leaves the terminal in the mode it had; a failure inside the real screen gives the terminal back before
## its one error line is written, and the status is not 0; and where Python has no curses module, or there is no
## terminal, the screen says so in one line, starts nothing and ends with a status that is not 0.
## Offline: the only thing the screen calls here is the stand-in for the dispatcher (check-fixtures/manager-screen.tools.stub.sh).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
"$rigPython" -I -c 'import curses' 2> /dev/null || rigRefuse "the python3 on PATH has no curses module, so the real screen cannot be started here: $rigPython"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenFrameCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/rig" "$rigTmp/ws-rig"
export MANAGER_SCREEN_RIG="$rigTmp/rig"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigFixtures/manager-screen.tools.stub.sh" > "$rigTmp/tools"
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

echo "-- at 120 columns by 40 lines --"
rigScript <<'RIGSCRIPT'
size 120 40
root sessions
workspace /somewhere/ws-rig
clock 12:34:56
turn
get a
show a
looks k
cells sepTitle 1 83 84
cells sepBody 20 83 84
cells sepInput 38 83 84
cells sepTop 0 83 84
cells sepBottom 39 83 84
get d
RIGSCRIPT
rigAssert "the screen is drawn"                                      "$( rigVal a.layout ) $( rigLines a )" "ok 40"
rigAssert "the list on the right takes a quarter to a third (30 to 40)" "$( rigBetween "$( rigVal a.listWidth )" 30 40 )" yes
rigAssert "the left pane has the rest, less the one column between"  "$(( $( rigVal a.viewWidth ) + 1 + $( rigVal a.listWidth ) ))" 120
rigAssert "the list stands on the right of that column"              "$( rigVal a.separator ) $( rigVal a.listLeft )" "83 84"
rigAssert "the column parts the panes from the titles down to the bottom border" "$( rigVal sepTitle )$( rigVal sepBody )$( rigVal sepInput )" "┐│┘"
rigAssert "the last line of the left pane is the line of its bottom border, and no cursor stands there: the screen has no line to type in" "$( rigVal a.inputLine ) cursor [$( rigVal d.cursor )]" "38 cursor []"
rigAssert "and the two windows hold as many lines"                           "$( rigVal a.listHeight ) $( rigVal a.viewHeight )" "36 36"
rigAssert "the first line is the menu bar, across the whole width, a hot letter in it apart"  "$( rigLine k 1 | LC_ALL=C tr H R ) $( rigLine k 1 | LC_ALL=C cut -c1-10 )" "$( rigRepeat R 120 ) RRRRHRRRHR"
rigAssert "the last line is the status line, across the whole width, a key in it apart"   "$( rigLine k 40 | LC_ALL=C tr H R ) $( rigLine k 40 | LC_ALL=C cut -c1-10 )" "$( rigRepeat R 120 ) RHHHHHRRRR"
rigAssert "the column between the panes does not cross them"         "[$( rigVal sepTop )][$( rigVal sepBottom )]" "[][]"
rigAssert "the top line shows the workspace and the clock"           "$( rigLine a 1 | LC_ALL=C sed -e 's/  */ /g' )" " ≡ Go View Help ws-rig 12:34:56 "
rigAssert "the bottom line shows the key hints"                      "$( rigLine a 40 | LC_ALL=C sed -e 's/  *$//' )" " ENTER Open  a Active  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut"
rigAssert "nothing was drawn past the end of a line"                 "$( rigVal d.spills )" 0

echo "-- at 80 columns by 24 lines --"
rigScript <<'RIGSCRIPT'
size 80 24
root sessions
turn
get a
show a
RIGSCRIPT
rigAssert "the list on the right takes a quarter to a third (20 to 26)" "$( rigBetween "$( rigVal a.listWidth )" 20 26 )" yes
rigAssert "the left pane has the rest"                               "$(( $( rigVal a.viewWidth ) + 1 + $( rigVal a.listWidth ) ))" 80
rigAssert "every line is drawn, at the full width"                   "$( rigLines a ) $( rigVal a.spills )" "24 0"

echo "-- a terminal that is too small --"
rigScript <<'RIGSCRIPT'
size 20 5
root sessions
turn
show a
get a
keys DOWN ENTER
get b
size 80 24
get c
size 20 5
keys ALT-x
get q
RIGSCRIPT
rigAssert "one line says that the terminal is too small"             "[$( rigLine a 1 )]" "[Too small: 20x5 (ne…]"
rigAssert "and the other lines are empty"                            "[$( rigLine a 2 )$( rigLine a 3 )$( rigLine a 4 )$( rigLine a 5 )]" "[$( rigRepeat ' ' 80 )]"
rigAssert "the screen does not fail, and goes on drawing"            "$( rigVal a.layout ) $( rigVal b.frames ) $( rigVal b.quit ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c DRIVER-FAILED )" "none 3 no 0"
rigAssert "a key moves nothing while nothing can be seen"            "$( rigVal b.selected )" sessions
rigAssert "resized, the frame is drawn again"                        "$( rigVal c.layout ) $( rigVal c.listWidth )" "ok 24"
rigAssert "too small again, the quit key still ends it"              "$( rigVal q.layout ) $( rigVal q.quit )" "none yes"

echo "-- a change of size --"
rigScript <<'RIGSCRIPT'
size 120 40
root sessions
workspace /somewhere/ws-rig
clock 12:34:56
view 60
turn
get a
size 90 40
get b
show b
fresh f
cells oldSep 20 83 84
cells newSep 20 62 63
RIGSCRIPT
rigAssert "the change came as a key, and the frame was drawn again"  "$( rigVal a.frames ) $( rigVal b.frames )" "1 2"
rigAssert "the panes are drawn at the new widths, the scroll bar of the left window in the column between them" "$( rigVal b.columns ) $( rigVal b.viewWidth ) $( rigVal b.listWidth ) [$( rigVal newSep )]" "90 62 27 [▒]"
rigAssert "the list still takes a quarter to a third (23 to 30)"     "$( rigBetween "$( rigVal b.listWidth )" 23 30 )" yes
rigAssert "the old column between the panes is gone"                 "[$( rigVal oldSep )]" "[]"
rigAssert "nothing of the old drawing is left: the screen is what a new terminal of that size shows" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^b|//p' | cksum )" "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^f|//p' | cksum )"
rigAssert "and that screen has its 40 lines"                         "$( rigLines b ) $( rigLines f )" "40 40"

echo "-- a line with a character that takes two cells --"
rigScript <<RIGSCRIPT
size 120 40
root sessions
rows pending a=🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀 b=$( rigRepeat y 34 )🚀zz
keys DOWN ENTER DOWN
viewline $( rigRepeat x 80 )🚀 and more text that does not fit the pane
viewline $( rigRepeat x 40 )🚀$( rigRepeat y 100 )
viewline short 🚀 line
turn
show a
get a
cells sep1 2 83 84
cells sep2 3 83 84
cells sep3 4 83 84
RIGSCRIPT
rigAssert "a character of two cells that no longer fits is left out whole, and the line fills the pane" \
	"[$( rigLine a 3 )]" "[│$( rigRepeat x 80 )… │║ ..$( rigRepeat ' ' 31 )║]"
rigAssert "one that fits stays, and the line is cut where the pane ends" \
	"[$( rigLine a 4 )]" "[│$( rigRepeat x 40 )🚀$( rigRepeat y 39 )…│║>$( rigRepeat 🚀 16 )…║]"
rigAssert "the list cuts its own line the same way"                  "[$( rigLine a 5 )]" "[│short 🚀 line$( rigRepeat ' ' 69 )│║ $( rigRepeat y 32 )…║]"
rigAssert "the column between the panes stands where it stood"       "$( rigVal sep1 )$( rigVal sep2 )$( rigVal sep3 )" "│││"
rigAssert "nothing was drawn past the end of a line or into the other pane" "$( rigVal a.spills )" 0

echo "-- a terminal that is not UTF-8 --"
rigScript <<'RIGSCRIPT'
size 60 12
root sessions
plain
turn
cells sep 3 39 40
cells cut 2 41 59
plaintext given a🚀b│c…
get a
RIGSCRIPT
rigAssert "the column between the panes and the cut mark, which stands ahead of the mark of a folder, are drawn in one byte each: on the first row of the root, the dashboard" "[$( rigVal sep )] [$( rigVal cut )] $( rigVal a.spills )" "[|] [ Dashboard (Mon+ >] 0"
rigAssert "what such a terminal cannot show is given as ?, cell for cell" "[$( rigVal given )]" "[a??b?c?]"

## The real screen comes up on the first row of its root, the dashboard: its name in the title of the left window is what is waited for.
echo "-- the real screen on a pseudo-terminal: the quit key --"
rigPty 80 24 "Dashboard (Monitor)" '\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "the screen came up"                                       "$( rigVal pty.frame ) $( rigVal pty.entered ) $( rigVal pty.modeTaken )" "yes yes yes"
rigAssert "the quit key ends it with status 0"                       "$( rigVal pty.rc )" 0
rigAssert "the terminal is left as it was"                           "$( rigVal pty.left ) $( rigVal pty.modeBack )" "yes yes"
rigAssert "and nothing was written as an error"                      "$( rigVal pty.errorAfterLeft )" none

echo "-- the real screen on a pseudo-terminal: a failure inside it --"
rigPty 80 24 "Dashboard (Monitor)" '\r' "$rigPython" -I -B "$rigDriver" "$rigScreen" child-raise --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "the screen came up, and then failed on its data"          "$( rigVal pty.frame ) $( rigVal pty.error | LC_ALL=C grep -c 'the stand-in for the data of the screen fails' )" "yes 1"
rigAssert "its status is not 0"                                      "$( rigVal pty.rc )" 1
rigAssert "the terminal was given back before the error was written" "$( rigVal pty.left ) $( rigVal pty.errorAfterLeft ) $( rigVal pty.modeBack )" "yes yes yes"
rigAssert "the error is one line of the screen's own"                "$( rigVal pty.error | LC_ALL=C grep -c '^⛔ ERROR: AgentsManagerScreen: the screen failed, and the terminal was given back first: RuntimeError: ' )" 1

echo "-- Python without the curses module --"
rigCallsBefore="$( LC_ALL=C grep -c '' "$rigTmp/rig/calls" )"
RIG_REAL_PYTHON3="$rigPython" bash "$rigFixtures/manager-screen.python3.stub.sh" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" < /dev/null > "$rigTmp/nocurses.out" 2> "$rigTmp/nocurses.err"
rigAssert "the status is not 0"                                      "$?" 1
rigAssert "it says so in one line, and nothing else"                 "$( LC_ALL=C grep -c '' "$rigTmp/nocurses.err" ) $( LC_ALL=C grep -c 'needs the curses module of Python' "$rigTmp/nocurses.err" ) $( LC_ALL=C grep -c '' "$rigTmp/nocurses.out" )" "1 1 0"
echo "-- sibling: the same call with the module there, and no terminal --"
"$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" < /dev/null > "$rigTmp/notty.out" 2> "$rigTmp/notty.err"
rigAssert "the status is not 0"                                      "$?" 1
rigAssert "it says in one line that it needs a terminal"             "$( LC_ALL=C grep -c '' "$rigTmp/notty.err" ) $( LC_ALL=C grep -c 'needs a terminal' "$rigTmp/notty.err" ) $( LC_ALL=C grep -c '' "$rigTmp/notty.out" )" "1 1 0"
rigAssert "and no operation was called for either"                   "$( LC_ALL=C grep -c '' "$rigTmp/rig/calls" )" "$rigCallsBefore"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN FRAME CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_FRAME: OK (%d assertions, offline, stand-in terminal and one pseudo-terminal)\n' "$rigPassCount"
