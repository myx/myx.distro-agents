#!/usr/bin/env bash
## Behavioural check on the list of the manager screen and on what a key does (sh-lib/manager/AgentsManagerScreen.py), run
## rather than read, through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py): each
## case feeds keys and reads the screen and the state back as text. Held: the root holds `Sessions (Activity)`,
## `Pending Questions`, `Team Members`, `Consoles`, `Settings` and `Configuration` in that order, the first one selected; Enter
## dives into a row, the first row below the root goes up, and so does Backspace from any row, back onto the row that was
## dived into; in the list Right pages down as PageDown does, and Left pages up, on the first row climbs a level and at the root does nothing more,
## and neither dives; inside `Sessions (Activity)` the first item is `Launchpad`, a level of its own; Up and Down stop at the
## first and at the last row and never wrap; PageDown and PageUp move the selection by the height of the pane, and
## the rows in view with it; Tab moves the focus, and the same keys then scroll the left pane while the selection of
## the list stays; `a` switches all and active only while the list has the focus; rows that come again in another
## order keep the selection on the same item, and where that item is gone the selection takes the row at its place;
## `q` quits; each key of an
## action goes to the handler of that action, with the row that is selected, or says that it is not built; and the
## status line names the keys that act on the selected row, once their handlers are built, the left pane none of its own.
## Offline: nothing of the tooling is called.
## Reconciled for F11.0: a spacer stands between the groups of the roots, and the left pane has no `keys:` line any more
## (the status line names those keys), so its content takes its last line too.
## Reconciled for F11.10: Workspace (System) stands at the end of the places, so the root holds nine sections and Manuals (Help) is the ninth.
## Reconciled for F11.5: the root holds eight sections, and Magic-Team (Agents) is the one that holds Activity, Pending Questions, Team Members and Team Data; the level a case enters is Magic-Team (Agents), and the first item of Activity is Launchpad.
## Reconciled for the Magic-Team reorder (20261021 sketch): Pending Questions stood first under Magic-Team (Agents), ahead of Activity.
## Reconciled for the removal of Pending Questions from Magic-Team (owner-approved: it is a root alone now): its sections are
## `.. activity launch team teamdata routines`, so Activity stands first and Launchpad after it.
## Reconciled for F11.5, the lists of Activity: the key `a` (all or only the active) is not offered there, as it has nothing to take: not in the status line, and not in the menu View.
## Reconciled for F11.6: the status line of a session names the send-message key too, `M Message`, between `k Kill` and `u Read`.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
rigDriver="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/manager-screen.driver.py"
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
cells row6 7 85 119
cells row7 8 85 119
cells row8 9 85 119
cells row9 10 85 119
cells row10 11 85 119
cells row11 12 85 119
cells row12 13 85 119
cells row13 14 85 119
cells row14 15 85 119
RIGSCRIPT
rigAssert "the root holds the nine sections in their order, the dashboard first, a spacer between its five groups: Dashboard and Pending Questions, Magic-Team, Locations, Consoles and Workspace, Settings and Configuration, Manuals" "[$( rigVal row1 )][$( rigVal row2 )][$( rigVal row3 )][$( rigVal row4 )][$( rigVal row5 )][$( rigVal row6 )][$( rigVal row7 )][$( rigVal row8 )][$( rigVal row9 )][$( rigVal row10 )][$( rigVal row11 )][$( rigVal row12 )][$( rigVal row13 )][$( rigVal row14 )]" "[ Dashboard (Monitor)             ►][ Pending Questions               ►][][ Magic-Team (Agents)             ►][][ Locations (Places)              ►][ Consoles                        ►][ Workspace (System)              ►][ This Machine                    ►][][ Settings                        ►][ Configuration                   ►][][>Manuals (Help)                  ►]"
rigAssert "the screen starts on the last one, Manuals (Help), selected, and the list has the focus" "$( rigVal a.selected ) $( rigVal a.index ) $( rigVal a.focus ) $( rigVal a.rows )" "manuals 9 list 10"

echo "-- Enter dives in, the first row and Backspace go up --"
rigScript <<'RIGSCRIPT'
size 120 40
root magic-team
keys ENTER
get in
border inTitle 1 84 120
cells inRow1 2 85 119
cells inRow2 3 85 119
cells inRow3 4 85 119
border inLeft 1 0 84
keys ENTER
get out
keys DOWN DOWN ENTER
get third
keys BACKSPACE
get back
keys BACKSPACE
get root
RIGSCRIPT
rigAssert "Enter shows the level of that section"                    "$( rigVal in.path ) [$( rigVal inTitle )]" "magic-team [Magic-Team (Agents)]"
rigAssert "its first row is the row that goes up, and it is selected" "[$( rigVal inRow1 )] $( rigVal in.selected )" "[>..] .."
rigAssert "inside Magic-Team (Agents) the first item is Activity" "[$( rigVal inRow2 )]" "[ Activity                        ►]"
rigAssert "and Launchpad stands after it" "[$( rigVal inRow3 )]" "[ Launchpad                       ►]"
rigAssert "the left pane names what it shows: on the row that goes up, the section itself"                     "[$( rigVal inLeft )]" "[Magic-Team (Agents) [wrap]]"
rigAssert "Enter on the row that goes up shows the root again"       "[$( rigVal out.path )] $( rigVal out.selected )" "[] magic-team"
rigAssert "Enter dives into the third section"                       "$( rigVal third.path ) $( rigVal third.selected )" "consoles .."
rigAssert "Backspace goes up and returns to the row it came from"    "[$( rigVal back.path )] $( rigVal back.selected )" "[] consoles"
rigAssert "Backspace at the root stays at the root, and says why"    "[$( rigVal root.path )] $( rigVal root.selected ) [$( rigVal root.notice )]" "[] consoles [Up one level: this is the top level]"

echo "-- Launchpad is a level of its own --"
rigScript <<'RIGSCRIPT'
size 120 40
## Reconciled for the removal of Pending Questions from Magic-Team: Launch is Magic-Team's second
## section now (`.. activity launch team teamdata routines`), so it is two steps from the row that goes up
at magic-team
keys DOWN DOWN
get on
border onLeft 1 0 84
keys ENTER
get in
border inTitle 1 84 120
keys LEFT
get back
RIGSCRIPT
rigAssert "it can be selected, and the left pane follows"            "$( rigVal on.selected ) [$( rigVal onLeft )]" "launch [Launchpad [wrap]]"
rigAssert "Enter dives into it, and it holds the four starts under the row that goes up" "$( rigVal in.path ) $( rigVal in.rows ) $( rigVal in.selected ) [$( rigVal inTitle )]" "magic-team/launch 5 .. [Launchpad]"
rigAssert "Left stays in the level it is in: it never climbs" "$( rigVal back.path ) $( rigVal back.selected )" "magic-team/launch .."

echo "-- Up and Down stop at the ends --"
rigScript <<'RIGSCRIPT'
size 120 40
root dashboard
keys UP
get top
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN
get last
keys DOWN DOWN
get still
RIGSCRIPT
rigAssert "Up on the first row stays there"                          "$( rigVal top.index )" 0
rigAssert "Down, pressed more times than the root has rows, reaches the last row" "$( [ "$( rigVal last.index )" = "$(( $( rigVal last.rows ) - 1 ))" ] && echo last ) $( rigVal last.selected )" "last manuals"
rigAssert "Down on the last row stays there, and does not wrap"      "$( [ "$( rigVal still.index )" = "$( rigVal last.index )" ] && echo there ) $( rigVal still.selected )" "there manuals"

echo "-- PageDown and PageUp, a hundred rows in a pane of twenty lines --"
rigScript <<'RIGSCRIPT'
size 120 23
root dashboard
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

echo "-- Left and Right in the list: Right pages down, Left pages up, on the first row it goes up a level, on the root's first row nothing more --"
rigScript <<'RIGSCRIPT'
size 120 23
root dashboard
rowsgen pending 100
keys DOWN ENTER
get a
keys RIGHT
get b
keys RIGHT
get c
keys DOWN DOWN LEFT
get d
keys LEFT
get e
keys LEFT
get f
keys LEFT
get g
keys LEFT
get h
keys LEFT
get i
RIGSCRIPT
lrSteps="[$( rigVal b.index ) $( rigVal b.top )][$( rigVal c.index ) $( rigVal c.top )][$( rigVal d.index ) $( rigVal d.top )][$( rigVal e.index ) $( rigVal e.top )][$( rigVal f.index ) $( rigVal f.top )]"
lrPaths="[$( rigVal b.path )][$( rigVal c.path )][$( rigVal d.path )][$( rigVal e.path )][$( rigVal f.path )]"
lrGone="[$( rigVal g.path )] $( rigVal g.selected ) [$( rigVal h.path )] $( rigVal h.selected ) [$( rigVal i.path )] $( rigVal i.selected ) $( rigVal i.focus ) [$( rigVal i.notice )]"
rigScript <<'RIGSCRIPT'
size 120 23
root dashboard
rowsgen pending 100
keys DOWN ENTER
keys PGDN
get b
keys PGDN
get c
keys DOWN DOWN PGUP
get d
keys PGUP
get e
keys PGUP
get f
RIGSCRIPT
rigAssert "Right pages down, Left in the middle pages up, and Left short of the first row ends on it, all in the level" "$lrSteps $lrPaths" "[19 19][38 38][21 19][2 0][0 0] [pending][pending][pending][pending][pending]"
rigAssert "each exactly as PageDown and PageUp do"                   "$lrSteps" "[$( rigVal b.index ) $( rigVal b.top )][$( rigVal c.index ) $( rigVal c.top )][$( rigVal d.index ) $( rigVal d.top )][$( rigVal e.index ) $( rigVal e.top )][$( rigVal f.index ) $( rigVal f.top )]"
rigAssert "Left never climbs: on the first row it stays in the level, the keys stay in the list, and no notice is given" "$lrGone" "[pending] .. [pending] .. [pending] .. list []"

echo "-- Right opens nothing, Backspace goes up from any row, Enter goes down --"
rigScript <<'RIGSCRIPT'
size 120 23
root dashboard
keys RIGHT
get root
rowsgen pending 100
keys UP UP UP UP UP UP UP UP UP DOWN ENTER
get in
keys RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT
get bottom
keys UP BACKSPACE
get up
keys ENTER
get again
RIGSCRIPT
rigAssert "Right on a row that dives pages down and does not dive"   "[$( rigVal root.path )] $( rigVal root.selected )" "[] manuals"
rigAssert "Enter dives"                                               "$( rigVal in.path ) $( rigVal in.selected )" "pending .."
rigAssert "Right on the last page stays on the last row, as PageDown does, and opens nothing" "$( rigVal bottom.path ) $( rigVal bottom.index ) $( rigVal bottom.top )" "pending 100 82"
rigAssert "Backspace on a row in the middle goes up a level, onto the row dived into" "[$( rigVal up.path )] $( rigVal up.selected )" "[] pending"
rigAssert "and Enter dives into it again"                            "$( rigVal again.path )" "pending"

echo "-- Tab moves the focus, and the left pane then scrolls --"
rigScript <<'RIGSCRIPT'
size 120 40
root pending
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
keys ENTER BACKSPACE
get g
keys TAB DOWN
get h
RIGSCRIPT
rigAssert "the list has the focus first, and its title shows it"     "$( rigVal a.focus ) $( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^la|//p' | LC_ALL=C sed -n '2p' | LC_ALL=C cut -c1,85 )" "list .B"
rigAssert "Tab moves the focus to the left pane, and its title shows it" "$( rigVal b.focus ) $( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^lb|//p' | LC_ALL=C sed -n '2p' | LC_ALL=C cut -c1,85 )" "view B."
rigAssert "Down three times scrolls the left pane by three lines"    "$( rigVal b.viewTop ) [$( rigVal bFirst )]" "3 [line 004]"
rigAssert "and the selection of the list has not moved"              "$( rigVal b.selected )" "pending"
rigAssert "PageDown scrolls it by the height of the pane"            "$( rigVal c.viewTop ) $( rigVal c.viewHeight )" "39 36"
rigAssert "Up scrolls it back by one line"                           "$( rigVal d.viewTop )" 38
rigAssert "it stops at its last line"                                "$( rigVal e.viewTop ) [$( rigVal eLast )]" "64 [line 100]"
rigAssert "and at its first"                                         "$( rigVal f.viewTop )" 0
rigAssert "the keys that dive and go up do nothing there"            "[$( rigVal g.path )] $( rigVal g.selected ) $( rigVal g.focus )" "[] pending view"
rigAssert "Tab gives the focus back to the list, and Down moves its selection again" "$( rigVal h.focus ) $( rigVal h.selected ) $( rigVal h.viewTop )" "list magic-team 0"

echo "-- a, all or active --"
rigScript <<'RIGSCRIPT'
size 120 40
table list:magic-team/launch --rig +active --active
root launch
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
rigAssert "all are shown first"                             "$( rigVal a.filter )" all
rigAssert "a is a button, so it works while the left pane has the focus: it switches to the active ones"  "$( rigVal b.focus ) $( rigVal b.filter ) [$( rigVal bTitle )]" "view active [Launchpad  [active]]"
rigAssert "with the focus on the list it switches back to all" "$( rigVal c.focus ) $( rigVal c.filter ) [$( rigVal cTitle )]" "list all [Launchpad  [all]]"
rigAssert "and once more to the active ones"                         "$( rigVal d.filter )" active

echo "-- rows that come again --"
rigScript <<'RIGSCRIPT'
size 120 40
root dashboard
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

echo "-- q and Esc --"
rigScript <<'RIGSCRIPT'
size 120 40
root dashboard
keys ESC
get esc
advance 2
keys q
get bare
keys ESC x
get quit
RIGSCRIPT
rigAssert "Esc with nothing open does nothing"                       "$( rigVal esc.quit ) $( rigVal esc.selected ) $( rigVal esc.focus )" "no dashboard list"
rigAssert "a bare q does nothing in the Turbo Vision key map; Esc and then x ends the screen, as Alt-X does" "$( rigVal bare.quit ) $( rigVal quit.quit )" "no yes"

echo "-- the keys of the actions --"
rigScript <<'RIGSCRIPT'
size 120 40
root dashboard
sessions s1=one_session!
keys k
get k
at @activity closed-sessions
turn
keys DOWN
keys p
get p
turn
keys r
get r
turn
keys s
get s
turn
keys R
get R
keys k
get kIn
keys l
get l
keys n
get n
turn
handler kill
keys k
get handled
keys TAB k
get handledLeft
RIGSCRIPT
rigAssert "each key of an action is a key in its view alone, and at the root none is; in its view it says in the status line why it does nothing: that it is not built, until its handler is; k, which is, that this row is nothing it acts on; l, the key of a mode of the Transcript, and n, the key of another view, say nothing: the status line keeps what it said" \
	"[$( rigVal k.notice )] [$( rigVal p.notice )][$( rigVal r.notice )][$( rigVal s.notice )][$( rigVal R.notice )][$( rigVal kIn.notice )][$( rigVal l.notice )][$( rigVal n.notice )] [$( rigVal n.dialog )]" \
	"[] [Pause is not built yet][Resume is not built yet][Stop is not built yet][Restart is not built yet][Kill: this session is finished][Kill: this session is finished][Kill: this session is finished] []"
rigAssert "none of them moved or quit anything"                      "$( rigVal l.selected ) $( rigVal l.quit ) $( rigVal l.focus )" "s1 no list"
rigAssert "with a handler, the key goes to it with the row that is selected" "[$( rigVal handled.notice )]" "[handled kill on s1]"
rigAssert "also while the left pane has the focus"                   "$( rigVal handledLeft.focus ) [$( rigVal handledLeft.notice )]" "view [handled kill on s1]"

echo "-- the keys that act on the selected item stand in the status line, and in no line of the left pane --"
rigScript <<'RIGSCRIPT'
size 120 40
root dashboard
sessions s1=one_session
rows magic-team/team m1=one_member
rows pending a1=one_ask
at @activity active-sessions
turn
keys DOWN
turn
get none
cells noneKeys 37 1 83
cells noneBottom 39 0 120
handler kill
handler start
turn
get built
cells builtKeys 37 1 83
cells builtLast 36 1 83
cells builtBottom 39 0 120
root launch
turn
get launch
cells launchKeys 37 1 83
root pending
keys ENTER DOWN
get ask
cells askKeys 37 1 83
at @team
turn
keys DOWN
get member
cells memberKeys 37 1 83
cells memberBottom 39 0 120
RIGSCRIPT
rigAssert "a session is selected: with no handler of an action built the pane names no key, and its last line is its content's" "$( rigVal none.selected ) [$( rigVal noneKeys )]" "s1 []"
rigAssert "the status line names the keys that act on the session, and after them those of every window"             "[$( rigVal noneBottom )]" "[ ENTER Open  BSP Up  / Filter  k Kill  M Message  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"
rigAssert "with handlers built, the pane still names no key: its last line is its content's, and the status line names the key that acts on a session" "[$( rigVal builtKeys )] $( rigVal builtBottom | LC_ALL=C grep -c -F ' k Kill ' )" "[] 1"
rigAssert "Launchpad has no such key"                           "$( rigVal launch.selected ) [$( rigVal launchKeys )]" "launch []"
rigAssert "an ask has none: no key answers it"                       "$( rigVal ask.path ) $( rigVal ask.selected ) [$( rigVal askKeys )]" "pending a1 []"
rigAssert "a team member: no line of the pane names the key that starts it" "$( rigVal member.path ) $( rigVal member.selected ) [$( rigVal memberKeys )]" "magic-team/team m1 []"
rigAssert "on a team member the status line names the key that starts it"                "[$( rigVal memberBottom )]" "[ ENTER Start  BSP Up  a Active  / Filter  n Start  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN LIST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_LIST: OK (%d assertions, offline, stand-in terminal)\n' "$rigPassCount"
