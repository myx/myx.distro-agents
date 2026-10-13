#!/usr/bin/env bash
## Behavioural check on the list of the manager screen and on what a key does (sh-lib/AgentsManagerScreen.py), run
## rather than read, through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.test.py): each
## case feeds keys and reads the screen and the state back as text. Held: the root holds `Sessions / Activity`,
## `Pending Questions`, `Team Members` and `Settings / Configuration` in that order, the first one selected; Enter or
## Right dives into a row, the first row below the root goes up, and so does Left, back onto the row that was dived
## into; inside `Sessions / Activity` the first item is `Launch / Spawn`, a level of its own; Up and Down stop at the
## first and at the last row and never wrap; PageDown and PageUp move the selection by the height of the pane, and
## the rows in view with it; Tab moves the focus, and the same keys then scroll the left pane while the selection of
## the list stays; `a` switches all and active only while the list has the focus; rows that come again in another
## order keep the selection on the same item, and where that item is gone the selection takes the row at its place;
## `q` quits; a line that is typed in takes every key until Enter or Esc, and Esc calls nothing; each key of an
## action goes to the handler of that action, with the row that is selected, or says that it is not built; and the
## left pane names, under the item, the keys that act on the selected row, once their handlers are built, while the
## bottom line keeps the keys of the screen.
## Offline: nothing of the tooling is called.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py"
rigDriver="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/manager-screen.driver.test.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"

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

echo "-- the root --"
rigScript <<'RIGSCRIPT'
size 120 40
turn
get a
border title 1 84 120
cells row1 2 85 119
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
cells row5 6 85 119
RIGSCRIPT
rigAssert "the root holds the four sections in their order"          "[$( rigVal row1 )][$( rigVal row2 )][$( rigVal row3 )][$( rigVal row4 )][$( rigVal row5 )]" "[>Sessions / Activity][ Pending Questions][ Team Members][ Settings / Configuration][]"
rigAssert "the first one is selected, and the list has the focus"    "$( rigVal a.selected ) $( rigVal a.index ) $( rigVal a.focus ) $( rigVal a.rows )" "sessions 0 list 4"

echo "-- Enter and Right dive in, the first row and Left go up --"
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
get in
border inTitle 1 84 120
cells inRow1 2 85 119
cells inRow2 3 85 119
border inLeft 1 0 84
keys ENTER
get out
keys DOWN DOWN RIGHT
get third
keys LEFT
get back
keys LEFT
get root
RIGSCRIPT
rigAssert "Enter shows the level of that section"                    "$( rigVal in.path ) [$( rigVal inTitle )]" "sessions [Sessions / Activity  [all]]"
rigAssert "its first row is the row that goes up, and it is selected" "[$( rigVal inRow1 )] $( rigVal in.selected )" "[>..] .."
rigAssert "inside Sessions / Activity the first item is Launch / Spawn" "[$( rigVal inRow2 )]" "[ Launch / Spawn]"
rigAssert "the left pane names what is selected"                     "[$( rigVal inLeft )]" "[..]"
rigAssert "Enter on the row that goes up shows the root again"       "[$( rigVal out.path )] $( rigVal out.selected )" "[] sessions"
rigAssert "Right dives into the third section"                       "$( rigVal third.path ) $( rigVal third.selected )" "team .."
rigAssert "Left goes up and returns to the row it came from"         "[$( rigVal back.path )] $( rigVal back.selected ) $( rigVal back.index )" "[] team 2"
rigAssert "Left at the root stays at the root"                       "[$( rigVal root.path )] $( rigVal root.selected )" "[] team"

echo "-- Launch / Spawn is a level of its own --"
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER DOWN
get on
border onLeft 1 0 84
keys ENTER
get in
border inTitle 1 84 120
keys LEFT
get back
RIGSCRIPT
rigAssert "it can be selected, and the left pane follows"            "$( rigVal on.selected ) [$( rigVal onLeft )]" "launch [Launch / Spawn]"
rigAssert "Enter dives into it, and it holds the free prompt under the row that goes up" "$( rigVal in.path ) $( rigVal in.rows ) $( rigVal in.selected ) [$( rigVal inTitle )]" "sessions/launch 2 .. [Launch / Spawn]"
rigAssert "Left returns to it"                                       "$( rigVal back.path ) $( rigVal back.selected )" "sessions launch"

echo "-- Up and Down stop at the ends --"
rigScript <<'RIGSCRIPT'
size 120 40
keys UP
get top
keys DOWN DOWN DOWN
get last
keys DOWN DOWN
get still
RIGSCRIPT
rigAssert "Up on the first row stays there"                          "$( rigVal top.index )" 0
rigAssert "Down reaches the last row"                                "$( rigVal last.index ) $( rigVal last.selected )" "3 settings"
rigAssert "Down on the last row stays there, and does not wrap"      "$( rigVal still.index ) $( rigVal still.selected )" "3 settings"

echo "-- PageDown and PageUp, a hundred rows in a pane of twenty lines --"
rigScript <<'RIGSCRIPT'
size 120 23
rowsgen pending 100
keys DOWN ENTER
get a
keys PGDN
get b
cells bRow1 2 85 119
cells bRow20 20 85 119
keys PGDN
get c
keys PGUP
get d
keys PGDN PGDN PGDN PGDN PGDN PGDN PGDN PGDN
get e
cells eRow20 20 85 119
keys PGUP PGUP PGUP PGUP PGUP PGUP PGUP PGUP
get f
RIGSCRIPT
rigAssert "the pane has twenty lines, and the level a hundred rows under the row that goes up" "$( rigVal a.listHeight ) $( rigVal a.rows ) $( rigVal a.index ) $( rigVal a.top )" "19 101 0 0"
rigAssert "PageDown moves the selection by one page"                 "$( rigVal b.index ) $( rigVal b.selected )" "19 r019"
rigAssert "and the rows in view move with it"                        "$( rigVal b.top ) [$( rigVal bRow1 )] [$( rigVal bRow20 )]" "19 [>row 019] [ row 037]"
rigAssert "a second PageDown moves by one more page"                 "$( rigVal c.index ) $( rigVal c.top )" "38 38"
rigAssert "PageUp moves back by one page"                            "$( rigVal d.index ) $( rigVal d.top )" "19 19"
rigAssert "PageDown ends on the last row, with the last page in view" "$( rigVal e.index ) $( rigVal e.top ) [$( rigVal eRow20 )]" "100 82 [>row 100]"
rigAssert "PageUp ends on the first row"                             "$( rigVal f.index ) $( rigVal f.top ) $( rigVal f.spills )" "0 0 0"

echo "-- Tab moves the focus, and the left pane then scrolls --"
rigScript <<'RIGSCRIPT'
size 120 40
view 100
turn
get a
looks la
keys TAB DOWN DOWN DOWN
get b
looks lb
cells bFirst 2 1 83
keys PGDN
get c
keys UP
get d
keys PGDN PGDN PGDN PGDN PGDN
get e
cells eLast 37 1 83
keys PGUP PGUP PGUP PGUP PGUP
get f
keys ENTER RIGHT LEFT
get g
keys TAB DOWN
get h
RIGSCRIPT
rigAssert "the list has the focus first, and its title shows it"     "$( rigVal a.focus ) $( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^la|//p' | LC_ALL=C sed -n '2p' | LC_ALL=C cut -c1,85 )" "list .B"
rigAssert "Tab moves the focus to the left pane, and its title shows it" "$( rigVal b.focus ) $( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^lb|//p' | LC_ALL=C sed -n '2p' | LC_ALL=C cut -c1,85 )" "view B."
rigAssert "Down three times scrolls the left pane by three lines"    "$( rigVal b.viewTop ) [$( rigVal bFirst )]" "3 [line 004]"
rigAssert "and the selection of the list has not moved"              "$( rigVal b.index ) $( rigVal b.selected )" "0 sessions"
rigAssert "PageDown scrolls it by the height of the pane"            "$( rigVal c.viewTop ) $( rigVal c.viewHeight )" "39 36"
rigAssert "Up scrolls it back by one line"                           "$( rigVal d.viewTop )" 38
rigAssert "it stops at its last line"                                "$( rigVal e.viewTop ) [$( rigVal eLast )]" "64 [line 100]"
rigAssert "and at its first"                                         "$( rigVal f.viewTop )" 0
rigAssert "the keys that dive and go up do nothing there"            "[$( rigVal g.path )] $( rigVal g.selected ) $( rigVal g.focus )" "[] sessions view"
rigAssert "Tab gives the focus back to the list, and Down moves its selection again" "$( rigVal h.focus ) $( rigVal h.index ) $( rigVal h.viewTop )" "list 1 0"

echo "-- a, all or active --"
rigScript <<'RIGSCRIPT'
size 120 40
keys ENTER
get a
keys TAB a
get b
border bTitle 1 84 120
keys TAB a
get c
border cTitle 1 84 120
keys a
get d
RIGSCRIPT
rigAssert "all sessions are shown first"                             "$( rigVal a.filter )" all
rigAssert "a does nothing while the left pane has the focus"         "$( rigVal b.focus ) $( rigVal b.filter ) [$( rigVal bTitle )]" "view all [Sessions / Activity  [all]]"
rigAssert "with the focus on the list it switches to the active ones" "$( rigVal c.focus ) $( rigVal c.filter ) [$( rigVal cTitle )]" "list active [Sessions / Activity  [active]]"
rigAssert "and back to all"                                          "$( rigVal d.filter )" all

echo "-- rows that come again --"
rigScript <<'RIGSCRIPT'
size 120 40
rows pending a=alpha b=beta c=gamma d=delta
keys DOWN ENTER DOWN DOWN DOWN
get a
rows pending d=delta c=gamma b=beta
turn
get b
cells bRow 4 85 119
rows pending d=delta b=beta
turn
get c
rows pending d=delta
turn
get d
RIGSCRIPT
rigAssert "the third item of four is selected"                       "$( rigVal a.selected ) $( rigVal a.index ) $( rigVal a.rows )" "c 3 5"
rigAssert "in another order, with a row above it gone, the selection stays on the same item" "$( rigVal b.selected ) $( rigVal b.index ) [$( rigVal bRow )]" "c 2 [>gamma]"
rigAssert "when that item itself is gone, the selection takes the row at the same place" "$( rigVal c.selected ) $( rigVal c.index )" "b 2"
rigAssert "and the last row where that place is gone too"            "$( rigVal d.selected ) $( rigVal d.index )" "d 1"

echo "-- q, Esc and the line that is typed in --"
rigScript <<'RIGSCRIPT'
size 120 40
keys ESC
get esc
dialog Name:
keys q TAB a DOWN
get typing
cells typingLine 38 1 83
keys ESC
get closed
said closedLine
dialog Name:
keys h i SPACE x BACKSPACE o ENTER
get sent
said sentLine
keys q
get quit
RIGSCRIPT
rigAssert "Esc with nothing open does nothing"                       "$( rigVal esc.quit ) $( rigVal esc.index ) $( rigVal esc.focus )" "no 0 list"
rigAssert "a key typed into the line is text: nothing quits, moves or switches" "$( rigVal typing.dialog ) $( rigVal typing.quit ) $( rigVal typing.focus ) $( rigVal typing.filter ) $( rigVal typing.index )" "Name:|qa no list all 0"
rigAssert "the line shows what is asked and what was typed"          "[$( rigVal typingLine )] $( rigVal typing.cursor )" "[Name: qa] 38,9"
rigAssert "Esc backs out: the line is empty again, and nothing was submitted" "[$( rigVal closed.dialog )] [$( rigVal closed.notice )] [$( rigVal closedLine )]" "[] [] []"
rigAssert "Enter submits what was typed, as it was corrected"        "[$( rigVal sent.dialog )] [$( rigVal sent.notice )] [$( rigVal sentLine )]" "[] [submitted: hi o] [submitted: hi o]"
rigAssert "q quits"                                                  "$( rigVal quit.quit )" yes

echo "-- the keys of the actions --"
rigScript <<'RIGSCRIPT'
size 120 40
keys k
get k
keys ESC
keys p
get p
keys ESC
keys r
get r
keys ESC
keys s
get s
keys ESC
keys R
get R
keys ESC
keys l
get l
keys ESC
keys n
get n
keys ESC
handler kill
keys DOWN k
get handled
keys TAB k
get handledLeft
RIGSCRIPT
rigAssert "each key of an action has its place, and says so in a box until its handler is built; k, l and n, which are, say that a section is nothing to kill, has no log and is no member to start" \
	"[$( rigVal k.dialogHolds )][$( rigVal p.dialogHolds )][$( rigVal r.dialogHolds )][$( rigVal s.dialogHolds )][$( rigVal R.dialogHolds )][$( rigVal l.dialogHolds )][$( rigVal n.dialogHolds )]" \
	"[k: nothing to kill here: k kills a session or an agent][p: pause is not built yet][r: resume is not built yet][s: stop is not built yet][R: restart is not built yet][l: this item has no feed and no log][n: nothing to start here: n starts a team member with a prompt]"
rigAssert "none of them moved or quit anything"                      "$( rigVal l.index ) $( rigVal l.quit ) $( rigVal l.focus )" "0 no list"
rigAssert "with a handler, the key goes to it with the row that is selected" "[$( rigVal handled.notice )]" "[handled kill on pending]"
rigAssert "also while the left pane has the focus"                   "$( rigVal handledLeft.focus ) [$( rigVal handledLeft.notice )]" "view [handled kill on pending]"

echo "-- the keys that act on the selected item stand in the left pane --"
rigScript <<'RIGSCRIPT'
size 120 40
rows sessions s1=one_session
rows team m1=one_member
rows pending a1=one_ask
keys ENTER DOWN DOWN
view 100
turn
get none
cells noneKeys 37 1 83
cells noneBottom 39 0 120
handler kill
handler log
handler start
turn
get built
cells builtKeys 37 1 83
cells builtLast 36 1 83
looks builtLooks
keys TAB PGDN PGDN PGDN
get scrolled
cells scrolledLast 36 1 83
keys TAB UP
view 100
turn
get launch
cells launchKeys 37 1 83
keys LEFT DOWN ENTER DOWN
get ask
cells askKeys 37 1 83
keys LEFT DOWN ENTER DOWN
get member
cells memberKeys 37 1 83
cells memberBottom 39 0 120
RIGSCRIPT
rigAssert "a session is selected: the pane names the one key whose handler is built, l" "$( rigVal none.selected ) [$( rigVal noneKeys )]" "s1 [keys: l log]"
rigAssert "the status line names the keys that act on the session, and after them those of every window"             "[$( rigVal noneBottom )]" "[ Left Up  a All/active  l Log  F5 Read  F10 Menu  Alt-X Exit  Tab Window]"
rigAssert "with handlers built, the keys that act on a session stand under it, and only those" "[$( rigVal builtKeys )] $( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^builtLooks|//p' | LC_ALL=C sed -n '38p' | LC_ALL=C cut -c1-12 )" "[keys: k kill  l log] .BBBBBBBBBBB"
rigAssert "the content of the pane ends one line above them"         "[$( rigVal builtLast )]" "[line 035]"
rigAssert "and scrolls in the lines it has left"                     "$( rigVal scrolled.viewTop ) [$( rigVal scrolledLast )]" "65 [line 100]"
rigAssert "Launch / Spawn has no such key"                           "$( rigVal launch.selected ) [$( rigVal launchKeys )]" "launch [line 036]"
rigAssert "an ask has none: no key answers it"                       "$( rigVal ask.path ) $( rigVal ask.selected ) [$( rigVal askKeys )]" "pending a1 []"
rigAssert "a team member has the key that starts it"                 "$( rigVal member.path ) $( rigVal member.selected ) [$( rigVal memberKeys )]" "team m1 [keys: n start]"
rigAssert "on a team member the status line names the key that starts it"                "[$( rigVal memberBottom )]" "[ Left Up  a All/active  n Start  F5 Read  F10 Menu  Alt-X Exit  Tab Window]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN LIST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_LIST: OK (%d assertions, offline, stand-in terminal)\n' "$rigPassCount"
