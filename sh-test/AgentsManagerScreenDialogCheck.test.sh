#!/usr/bin/env bash
## Behavioural check on the dialogs of the manager screen (sh-lib/manager/AgentsManagerScreen.py) and on its status line, run
## rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), which opens a dialog of the rig's own with a control of every kind.
## Held: a dialog is drawn from its declaration, framed, with its title, over the windows, and in the Turbo Vision
## style with a shadow; it has the keys, so no key of a window, of a menu or of the screen works while it is open; Tab
## and Shift-Tab move between its controls and its buttons; a field takes what is typed and Backspace; in a field of
## several lines Enter is a new line; Space toggles a box and chooses a radio button; Up and Down pick in a list; Left
## and Right go from button to button; Enter presses the first button, whose handler gets what every control holds;
## what the handler refuses stands in the dialog, which stays open; Esc and Cancel close it and call nothing. The
## message box holds a text whole, broken to the box, and one longer than its room scrolls; a box that comes while
## another is open waits for it. The status line names only the keys that act for what has the keys: those of the
## active window and of the selected row first and those of every window after them, the first to go where the line
## is short; those of a menu while one is open; those of a dialog, by the control the keys are on, while one is open.
## The dialogs are drawn in every style, in Magic with its own marks; each has an empty line under its top, and one
## under its buttons where they cast no shadow; in Magic its lines are in the colour of the ground of its title tab,
## that tab stands at its left, and its shadow at its right starts beside its second line. The keys every
## terminal delivers: a plain key opens the menu bar, reads now, asks for help and takes the next style; Esc and
## then a letter is Alt with that letter, for the menus and for the exit; and the key map is the style's: a bare q
## ends the screen in none. Inside a container, with the selection on the row that goes
## up, the left window shows the container itself and its keys act on it. A toggle of a view, the raw log in place
## of the feed, all or active, is kept for the run of the screen whatever is selected. The help lists the keys
## from the declaration.
## And, with the real screen on a pseudo-terminal in front of a terminal that keeps its cells
## (check-fixtures/manager-screen.vt.stub.py), in every style: while a field of a dialog, of one line or of several, has
## the keys, the cursor shows, where what is typed goes, an emoji typed too, and stays there as the screen draws
## again; while a button has them it shows nowhere; at the end it shows again.
## Offline: nothing but the screen's own code runs, and no operation of the tooling is called.
## Reconciled for F11.0: every dialog has bigger margins inside its frame (two empty lines under its top, one more
## under its buttons, three blank cells at each side), so its box is four cells wider and two lines taller and what it
## holds stands where it stood.
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
rigRun(){ ## the commands of the driver on standard input, after the ones every case starts with: a list of two sessions, entered; what it printed is kept in rigOut
	rigOut="$( { printf 'size 120 40\nrows sessions s1=one s2=two\nrows team m1=member-one\nroot sessions\nkeys ENTER\n' ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigHas(){ ## tag, text -- how many lines of that drawing hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigRole(){ ## tag, line counted from 1, the cells from and to counted from 1 -- the letter of each of those cells in a drawing of looks or of roles
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -n "${2}p" | LC_ALL=C cut -c"$3-$4"
}
rigRepeat(){ ## text, count
	local repeatText="" repeatLeft="$2"
	while [ "$repeatLeft" -gt 0 ] ; do repeatText="$repeatText$1" ; repeatLeft=$(( repeatLeft - 1 )) ; done
	printf '%s' "$repeatText"
}

echo "-- a dialog is drawn from its declaration, and has the keys --"
rigRun <<'RIGSCRIPT'
rigdialog What the rig asks.
turn
get o
box d
box r roles
cells st1 39 0 120
keys x SPACE y
get typed
keys BACKSPACE BACKSPACE BACKSPACE TAB
turn
cells st2 39 0 120
keys a ENTER b
get area
keys TAB
turn
cells st3 39 0 120
keys SPACE DOWN DOWN SPACE
get who
keys TAB
turn
cells st4 39 0 120
keys UP SPACE
get how
keys TAB
turn
cells st5 39 0 120
keys DOWN DOWN DOWN
get pick
keys TAB
turn
get onOk
box rOk roles
cells st6 39 0 120
keys RIGHT
turn
get onCancel
cells st7 39 0 120
keys RIGHT BACKTAB
get back
keys q k ALT-x F10 F5 a
get held
box d2
keys ENTER
get done
said doneLine
RIGSCRIPT
rigAssert "the dialog opens over the screen, the keys on its first control" "$( rigVal o.dialog ) [$( rigVal o.dialogTitle )] $( rigVal o.dialogBox ) $( rigVal o.spills )" "rig:name|typed [A dialog of the rig] 30,4,60,32 0"
rigAssert "it is framed, with its title in its top border, and holds its text" "$( rigHas d '╔═[■]══════════════ A dialog of the rig ═══════════════════╗' ) $( rigHas d '║   What the rig asks. ' ) $( rigHas d '╚══════════════════════════════════════════════════════════╝' )" "1 1 1"
rigAssert "each control under its label: a field, boxes, radio buttons, a list, and the buttons last" "$( rigHas d '║   Name ' ) $( rigHas d '║   typed ' ) $( rigHas d '║   [ ] alpha ' ) $( rigHas d '║   [X] beta ' ) $( rigHas d '║   ( ) one way ' ) $( rigHas d '║   (•) another ' ) $( rigHas d '║   > first ' ) $( rigHas d ' »OK« ▅   Cancel  ▅' )" "1 1 1 1 1 1 1 1"
rigAssert "in the Turbo Vision style it has a shadow, at its right from its second line and under it" "$( rigRole r 2 59 62 ) $( [ "$( rigRole r 1 61 62 )" = ww ] && echo shadow || echo none ) $( rigRole r 33 3 62 )" "gGww none $( rigRepeat w 60 )"
rigAssert "the field that has the keys stands in a look of its own, another field and a button in theirs" "$( rigRole r 7 1 6 ) $( rigRole r 10 1 6 ) $( rigRole r 29 21 40 ) $( rigVal o.cursor )" "GgggII Ggggii gbbbbbbggbbbbbbbbbbg 10,39"
rigAssert "the status line names the keys of the dialog alone: in a field, Enter, Tab and Esc" "[$( rigVal st1 )]" "[ ENTER OK  TAB Next  ESC Cancel]"
rigAssert "what is typed goes into the field, a space too"            "$( rigVal typed.dialog )" "rig:name|typedx y"
rigAssert "Tab goes to the next control; in a field of several lines Enter is a new line" "[$( rigVal st2 )] $( rigVal area.dialog )" "[ ENTER New line  TAB Next  ESC Cancel] rig:notes|a\\nb"
rigAssert "Space toggles the box the keys are on, and Up and Down move among the boxes" "[$( rigVal st3 )] $( rigVal who.dialog )" "[ Space Toggle  UP/DN Move  ENTER OK  TAB Next  ESC Cancel] rig:who|b,a,c"
rigAssert "Space chooses the radio button the keys are on"            "[$( rigVal st4 )] $( rigVal how.dialog )" "[ Space Choose  UP/DN Move  ENTER OK  TAB Next  ESC Cancel] rig:how|x"
rigAssert "Up and Down pick in a list, and stop at its end"           "[$( rigVal st5 )] $( rigVal pick.dialog )" "[ UP/DN Pick  ENTER OK  TAB Next  ESC Cancel] rig:pick|p3"
rigAssert "after the controls Tab comes to the buttons, and the one with the keys stands out" "$( rigVal onOk.dialog ) $( rigRole rOk 29 21 40 ) [$( rigVal st6 )]" "rig:ok| gnnnnnnggbbbbbbbbbbg [ ←/→ Buttons  ENTER OK  TAB Next  ESC Cancel]"
rigAssert "Right goes to the next button, which Enter would then press" "$( rigVal onCancel.dialog ) [$( rigVal st7 )]" "rig:cancel| [ ←/→ Buttons  ENTER Cancel  TAB Next  ESC Cancel]"
rigAssert "Right goes around to the first button, and Shift-Tab back to the control before it" "$( rigVal back.dialog )" "rig:pick|p3"
rigAssert "no key of a window, of a menu or of the screen works while the dialog is open" "$( rigVal held.dialog ) $( rigVal held.quit ) [$( rigVal held.menu )] $( rigVal held.filter ) $( rigVal held.focus ) [$( rigVal held.notice )]" "rig:pick|p3 no [] all list []"
rigAssert "the dialog shows what was chosen"                         "$( rigHas d2 '║   [X] alpha ' ) $( rigHas d2 '║   (•) one way ' ) $( rigHas d2 '║   > third ' ) $( rigHas d2 '║   b ' )" "1 1 1 1"
rigAssert "Enter presses the first button: the dialog closes, and its handler has what every control holds" "[$( rigVal done.dialog )] [$( rigVal done.notice )]" "[] [pressed ok: name=typed notes=a\\nb who=b,a,c how=x pick=p3]"
rigAssert "and the status line says it, as a short confirmation does" "[$( rigVal doneLine )]" "[pressed ok: name=typed notes=a\\nb who=b,a,c how=x pick=p3]"

echo "-- what a dialog refuses stays in it; Esc, Cancel and Space on a button --"
rigRun <<'RIGSCRIPT'
rigdialog What the rig asks.
keys BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE n o ENTER
turn
get refused
box d
box r roles
keys ESC
get esc
rigdialog What the rig asks.
keys BACKTAB
get last
keys SPACE
get cancelled
rigdialog What the rig asks.
keys TAB TAB TAB TAB TAB SPACE
get spaced
RIGSCRIPT
rigAssert "what the handler refuses stands in the dialog, which stays open" "$( rigVal refused.dialog ) [$( rigVal refused.dialogSays )] $( rigHas d '║   the rig refuses the name no ' ) [$( rigVal refused.notice )]" "rig:name|no [the rig refuses the name no] 1 []"
rigAssert "in a look of its own, above the buttons"                  "$( rigRole r 29 1 8 ) $( rigHas d ' »OK« ▅   Cancel  ▅' ) $( rigVal refused.dialogBox )" "Gggg!!!! 1 30,3,60,33"
rigAssert "Esc closes the dialog and calls nothing"                  "[$( rigVal esc.dialog )] [$( rigVal esc.notice )]" "[] []"
rigAssert "Shift-Tab from the first control goes around to the last button, and Space presses it: Cancel calls nothing" "$( rigVal last.dialog ) [$( rigVal cancelled.dialog )] [$( rigVal cancelled.notice )]" "rig:cancel| [] []"
rigAssert "Space on OK presses it"                                   "[$( rigVal spaced.dialog )] [$( rigVal spaced.notice )]" "[] [pressed ok: name=typed notes= who=b how=y pick=p1]"

echo "-- the message box: a text whole, scrolled where it is long; a second box waits --"
rigRun <<'RIGSCRIPT'
size 60 12
tell The start failed | line 01 / line 02 / line 03 / line 04 / line 05 / line 06 / line 07 / line 08 / line 09 / line 10
turn
get m
box b1
cells st1 11 0 60
cells mFirst 2 11 49
keys DOWN
turn
box b2
keys PGDN PGDN PGDN
turn
box b3
keys q TAB
get still
tell Second | a text that is broken to the box it stands in, between its words, as many lines as it takes to hold all of it
get queued
keys ENTER
turn
get second
box b4
cells st4 11 0 60
keys ESC
get none
RIGSCRIPT
rigAssert "the message box has its title, one button, and as many lines of its text as the terminal leaves it" "$( rigVal m.dialog ) [$( rigVal m.dialogTitle )] $( rigVal m.dialogBox ) $( rigHas b1 ' The start failed ' ) $( rigHas b1 ' »OK« ▅' ) $( rigHas b1 'line 01' ) $( rigHas b1 'line 06' ) $( rigHas b1 'line 07' )" "message:ok| [The start failed] 10,1,40,10 1 1 1 1 0"
rigAssert "on a terminal too short for all of it the empty lines under its top and under its buttons give way first, then those between its parts, before its text loses a line" "[$( rigVal mFirst )]" "[   line 01]"
rigAssert "a mark says that it goes on below, and the status line names what scrolls it" "$( rigHas b1 '▼' ) $( rigHas b1 '▲' ) [$( rigVal st1 )]" "1 0 [ ENTER OK  UP/DN Scroll  ESC Close]"
rigAssert "Down scrolls it by a line"                                "$( rigHas b2 'line 01' ) $( rigHas b2 'line 07' ) $( rigHas b2 '▲' ) $( rigHas b2 '▼' )" "0 1 1 1"
rigAssert "PgDn by a page, and it stops at its end"                  "$( rigHas b3 'line 04' ) $( rigHas b3 'line 05' ) $( rigHas b3 'line 10' ) $( rigHas b3 '▼' )" "0 1 1 0"
rigAssert "the box has the keys: q does not end the screen"          "$( rigVal still.dialog ) $( rigVal still.quit )" "message:ok| no"
rigAssert "a box that comes while one is open waits for it"          "[$( rigVal queued.dialogTitle )] $( rigVal queued.waiting )" "[The start failed] 1"
rigAssert "and opens when that one is closed, its text broken between words" "[$( rigVal second.dialogTitle )] $( rigVal second.waiting ) $( rigHas b4 '║   a text that is broken to the box it stands in, ' ) $( rigHas b4 '║   hold all of it ' ) [$( rigVal st4 )]" "[Second] 0 1 1 [ ENTER OK  ESC Close]"
rigAssert "Esc closes it, and the keys go back to the windows"       "[$( rigVal none.dialog )] $( rigVal none.waiting )" "[] 0"

echo "-- the status line names only the keys that act for what has the keys --"
rigRun <<'RIGSCRIPT'
handler kill
handler control
handler log
handler start
keys DOWN
turn
get launch
cells onLaunch 39 0 120
keys DOWN
turn
get session
cells onSession 39 0 120
keys TAB
turn
get left
cells onLeft 39 0 120
keys F10
turn
cells onMenu 39 0 120
keys ESC TAB
size 40 20
turn
cells narrow 19 0 40
size 120 40
keys ALT-4 DOWN
turn
get member
cells onMember 39 0 120
keys k
get wrongKey
RIGSCRIPT
rigAssert "the list active on Launch (Start): what the list takes there, then the keys of every window" "$( rigVal launch.selected ) [$( rigVal onLaunch )]" "launch [ ENTER Open  BSP Up  a Active  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"
rigAssert "on a session: the keys that act on a session, and no Enter, which opens nothing there" "$( rigVal session.selected ) [$( rigVal onSession )]" "s1 [ BSP Up  a Active  k Kill  c Control  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"
rigAssert "the left window active: the list's own keys are gone, those that act on the selected session stay" "$( rigVal left.focus ) [$( rigVal onLeft )]" "view [ a Active  k Kill  c Control  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"
rigAssert "a menu open: the keys of the menu alone"                  "[$( rigVal onMenu )]" "[ ENTER Choose  ESC Close  ←/→ Menus  UP/DN Items]"
rigAssert "a line too short for all: the keys of every window are the first left out" "[$( rigVal narrow )]" "[ BSP Up  a Active  k Kill  c Control]"
rigAssert "on a member: the key that starts one, and none of a session's" "$( rigVal member.path ) $( rigVal member.selected ) [$( rigVal onMember )]" "team m1 [ BSP Up  a Active  n Start  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"

echo "-- the keys every terminal delivers: a plain key, or Esc and then a letter; no function key and no Alt --"
rigRun <<'RIGSCRIPT'
keys m
get byM
keys ESC
get closed
keys ESC
turn
cells afterEsc 39 0 120
keys s
get byEscS
keys ESC x
get afterMenuEsc
keys ESC
advance 2
keys x
get late
keys q
get bareQ
keys u
get read
keys ?
get help
keys ESC
keys m RIGHT RIGHT
turn
show v
keys ESC I
get styled
keys q
get bwQ
RIGSCRIPT
rigAssert "m opens the menu bar, and Esc closes it at once"          "$( rigVal byM.menu ) [$( rigVal closed.menu )]" "go:dashboard []"
rigAssert "after Esc, with nothing to close, the status line names the letters that then act" "[$( rigVal afterEsc )]" "[ g Go  s Session  v View  h Help  x Exit  1 Dashboard (Monitor)  2 Sessions (Activity)  3 Pending Questions]"
rigAssert "Esc and then the hot letter of a menu opens that menu, as Alt with that letter does" "$( rigVal byEscS.menu )" "session:kill"
rigAssert "the Esc that closed a menu is no Alt for the key after it, and neither is one whose key comes too late" "[$( rigVal afterMenuEsc.menu )] $( rigVal afterMenuEsc.quit ) $( rigVal late.quit )" "[] no no"
rigAssert "a bare q does nothing in the Turbo Vision key map"        "$( rigVal bareQ.quit )" "no"
rigAssert "the help names the keys as the style does" "$( rigVal help.dialogHolds | LC_ALL=C grep -c -F 'TAB, F6: Next window' ) $( rigVal help.dialogHolds | LC_ALL=C grep -c -F 'BSP: Up one level' ) $( rigVal help.dialogHolds | LC_ALL=C grep -c -F 'UP and DN move by a line' ) $( rigVal help.dialogHolds | LC_ALL=C grep -c -F 'ESC and then its letter' )" "1 1 1 1"
rigAssert "u reads now, and ? opens the help: the keys from the declaration, those that act now first" "$( rigVal read.forced ) [$( rigVal help.dialogTitle )] $( rigVal help.dialogHolds | LC_ALL=C grep -c -F 'The keys that act now, on what is selected in the active window: / u, F5: Read now / m, F10: Menu / ^X, Alt-X: Exit' )" "list:sessions [Keys] 1"
rigAssert "then the other keys, one whose action is not built saying so, and the menus by their letters" "$( rigVal help.dialogHolds | LC_ALL=C grep -c -F 'p: Pause (not built)' ) $( rigVal help.dialogHolds | LC_ALL=C grep -c -F '/ g: Go / s: Session / m: Member / c: Console / v: View / q: Question / h: Help /' )" "1 1"
rigAssert "the menus name the keys that need no function key"        "$( rigHas v '│ Read now                        u │' ) $( rigHas v '│ Interface style: the next       I │' ) $( rigHas v '│ Interface colours: the next     i │' ) $( rigHas v '│ Next window                   TAB │' ) $( rigHas v 'F5' ) $( rigHas v 'F9' )" "1 1 1 1 0 0"
rigAssert "I takes the next style, Basic B/W, and a bare q ends nothing there either" "$( rigVal styled.style ) $( rigVal bwQ.quit )" "bw no"

echo "-- inside a container, on the row that goes up, the left window shows the container, and its keys act on it --"
rigRun <<'RIGSCRIPT'
rows sessions +s1=one s2=two
rows sessions/s1 a1=agent-one
handler kill
handler log
keys DOWN DOWN
turn
border outside 1 0 84
keys ENTER
turn
get in
border inside 1 0 84
cells st 39 0 120
keys k
get onUp
keys DOWN
turn
border child 1 0 84
keys k
get onChild
keys ALT-2 PGUP DOWN ENTER
turn
get launch
border launchTitle 1 0 84
keys ALT-4
turn
border teamTitle 1 0 84
keys ALT-3
turn
border pendingTitle 1 0 84
keys ALT-7
turn
border settingsTitle 1 0 84
RIGSCRIPT
rigAssert "a session opened, the selection on the row that goes up: the left window still shows that session" "[$( rigVal outside )] [$( rigVal inside )] $( rigVal in.path ) $( rigVal in.selected )" "[one [wrap]] [one [wrap]] sessions/s1 .."
rigAssert "the keys that act on the session stand in the status line there, and act on it" "[$( rigVal st )] [$( rigVal onUp.notice )]" "[ ENTER Open  BSP Up  a Active  k Kill  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut] [handled kill on s1]"
rigAssert "moving to a child shows the child, and the keys act on the child" "[$( rigVal child )] [$( rigVal onChild.notice )]" "[agent-one [wrap]] [handled kill on a1]"
rigAssert "Launch (Start) and the roots, entered with the selection on the row that goes up, show themselves" "$( rigVal launch.path ) [$( rigVal launchTitle )] [$( rigVal teamTitle )] [$( rigVal pendingTitle )] [$( rigVal settingsTitle )]" "sessions/launch [Launch (Start) [wrap]] [Team Members [wrap]] [Pending Questions [wrap]] [Settings [wrap]]"

echo "-- the mode of the left window and a toggle of a view are kept for the run: the raw log, all or active --"
rigRun <<'RIGSCRIPT'
rows sessions +s1=one s2=two
rows sessions/s1 a1=agent-one
table feed:sessions:record --rig-feed
table feed:sessions/*:record --rig-feed
keys DOWN DOWN g
turn
get on
border onTitle 1 0 84
cells onStatus 39 0 120
keys DOWN
turn
get moved
border movedTitle 1 0 84
keys UP ENTER
get inside
keys DOWN
get child
keys LEFT TAB TAB m ESC
get back
keys a
keys ALT-3 ALT-4 ALT-7 ALT-2
advance 11
turn
get roots
keys l
turn
get off
cells offStatus 39 0 120
RIGSCRIPT
rigAssert "g takes the raw log: the title of the left window says so, and the status line names the keys of the two other modes with what each will show" "$( rigVal on.rawLog ) $( rigVal on.viewMode ) [$( rigVal onTitle )] [$( rigVal onStatus )]" "yes raw [one [raw] [wrap]] [ ENTER Open  BSP Up  a Active  b Summary  l Log  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"
rigAssert "moving to another session keeps it: that one shows its raw log too" "$( rigVal moved.rawLog ) [$( rigVal movedTitle )]" "yes [two [raw] [wrap]]"
rigAssert "so do opening a session, moving to an agent, leaving, changing window, a menu" "$( rigVal inside.rawLog ) $( rigVal inside.path ) $( rigVal child.rawLog ) $( rigVal child.selected ) $( rigVal back.rawLog )" "yes sessions/s1 yes a1 yes"
rigAssert "all or active is kept through the four roots and a tick, and the raw log with it" "$( rigVal roots.filter ) $( rigVal roots.path ) $( rigVal roots.rawLog )" "active sessions yes"
rigAssert "l takes the log, the feed alone, and the status line names what each key will show now: the two other modes, and all, since only the active are shown" "$( rigVal off.rawLog ) $( rigVal off.viewMode ) [$( rigVal offStatus )]" "no log [ ENTER Open  BSP Up  a All  b Summary  g Raw log  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"

echo "-- every style draws the dialogs, Magic in its own marks --"
rigRun <<'RIGSCRIPT'
handler kill
keys DOWN DOWN
style bw
rigdialog What the rig asks.
turn
box bw roles
box bwk looks
keys ESC
style magic
rigdialog What the rig asks.
turn
get mg
show md
box mgd
box mgr roles
RIGSCRIPT
rigAssert "B/W: the same dialog, with no shadow, in reverse with the control that has the keys in bold" "$( rigRole bw 2 59 62 | LC_ALL=C tr -d w | LC_ALL=C cut -c1-2 ) $( rigRole bw 31 3 62 | LC_ALL=C tr -d w | LC_ALL=C wc -c | LC_ALL=C tr -d ' ' ) $( rigRole bwk 7 1 6 ) $( rigRole bwk 10 1 6 )" "gG 61 HRRRBB HRRR.."
rigAssert "Magic: the same dialog in its own colour, a thin line on the bottom edge of the line over it, its title a tab on it, and of its last line, nothing on the top of a cell, its shadow, its buttons bars, one line more for their shadow" "$( rigHas mgd '▁▁' ) $( rigHas mgd '▁ A dialog of the rig ▁' ) $( rigHas mgd '▔' ) $( rigHas mgd '▀' ) $( rigHas mgd '    OK        Cancel   ' ) $( rigVal mg.dialogBox )" "2 1 0 0 1 30,4,60,32"
rigAssert "its status line names the keys of the dialog, in its own names"  "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^md|//p' | LC_ALL=C sed -n '40p' | LC_ALL=C sed -e 's/|$//' -e 's/  *$//' )" " ⏎ OK  ⇥ Next  ⎋ Cancel"

echo "-- Turbo Vision: the shadow of a raised button is the ground of its cells --"
rigRun <<'RIGSCRIPT'
style tv-system
rigdialog What the rig asks.
turn
box ts
box tsr roles
keys ESC
style tv-blue
rigdialog What the rig asks.
turn
box tb
box tbr roles
keys ESC
style tv-gray
rigdialog What the rig asks.
turn
box tg
box tgr roles
RIGSCRIPT
rigGround(){ ## style, letter -- the look of that letter in that style as <text>/<ground> of the eight and, where they have their own shades, of the palette; then the ground of the dialog's text the same way
	"$rigPython" -I -B - "$rigScreen" "$1" "$2" <<'RIGPY' 2>&1
import importlib.util, sys
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.setStyle(sys.argv[2])
own = module.STYLE_LOOKS.get(module.STYLE.get("looks"), {})
def colours(look):
    entry = own.get(look)
    return (module.LOOKS[look][2], module.LOOKS[look][3], None, None) if entry is None else (entry[0], entry[1], entry[3], entry[4])
text, ground, fineText, fineGround = colours([number for number, look in enumerate(module.LOOKS) if look[0] == sys.argv[3]][0])
said = "%s/%s" % (text, ground) + ("" if fineText is None else " %d/%d" % (fineText, fineGround))
text, ground, fineText, fineGround = colours(module.BOX)
print(said + " dialog " + ground + ("" if fineGround is None else " %d" % fineGround))
RIGPY
}
rigAssert "beside the face ▅ in the black of the shadow on the dialog, and under it, from one cell after its left, ▅ in the colour of the dialog on the black of the shadow: blocks on the cell's bottom edge, no half block, so the two meet into one shadow; in each of its colours" "$( for rigOne in s:tv-system b:tv-blue g:tv-gray ; do rigTag="t${rigOne%%:*}" ; printf '[%s %s %s %s %s %s %s]' "$( rigHas "$rigTag" ' »OK« ▅   Cancel  ▅' )" "$( rigHas "$rigTag" ' ▅▅▅▅▅▅  ▅▅▅▅▅▅▅▅▅▅' )" "$( rigHas "$rigTag" '▄' )" "$( rigHas "$rigTag" '▀' )" "$( rigRole "${rigTag}r" 30 22 40 )" "$( rigGround "${rigOne#*:}" "$( rigRole "${rigTag}r" 29 28 28 )" )" "$( rigGround "${rigOne#*:}" "$( rigRole "${rigTag}r" 30 23 23 )" )" ; done )" "[1 1 0 0 gZZZZZZggZZZZZZZZZZ black/white dialog white white/black dialog white][1 1 0 0 gZZZZZZggZZZZZZZZZZ black/white 16/248 dialog white 248 white/black 248/16 dialog white 248][1 1 0 0 gZZZZZZggZZZZZZZZZZ black/white 16/248 dialog white 248 white/black 248/16 dialog white 248]"

echo "-- a dialog's chrome: an empty line on its top in every style; in Magic its lines in the colour of its title tab, its title at the left, its shadow from its second line --"
rigRun <<'RIGSCRIPT'
style tv-system
rigdialog What the rig asks.
turn
get tv
cells tvUnder 6 33 87
cells tvText 7 33 87
keys ESC
style bw-system
rigdialog What the rig asks.
turn
get bw
cells bwUnder 6 33 87
cells bwText 7 33 87
cells bwButtons 32 33 87
cells bwFoot 33 33 87
keys ESC
style nu-blue
rigdialog What the rig asks.
turn
get nb
cells nbUnder 6 33 87
cells nbText 7 33 87
cells nbTop 4 30 90
box nbr roles
keys ESC
style nu-gray
rigdialog What the rig asks.
turn
box ngr roles
keys ESC
style nu-system
rigdialog What the rig asks.
turn
box nsr roles
keys ESC
size 120 24
style nu-blue
rigdialog What the rig asks.
turn
box nbd
box nbs roles
keys ESC
size 60 12
tell A title far longer than the box that holds it can show | line 01 / line 02 / line 03 / line 04 / line 05 / line 06 / line 07 / line 08 / line 09 / line 10
turn
get long
cells longTop 1 2 58
RIGSCRIPT
rigLineOnTab(){ ## style, letter of a line, letter of a title tab -- "same" where the text of the line is the ground of the tab, on a terminal of eight colours and on one of 256, else the colours of both
	"$rigPython" -I -B - "$rigScreen" "$1" "$2" "$3" <<'RIGPY' 2>&1
import importlib.util, sys
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.setStyle(sys.argv[2])
own = module.STYLE_LOOKS.get(module.STYLE.get("looks"), {})
def colours(letter):
    look = [number for number, entry in enumerate(module.LOOKS) if entry[0] == letter][0]
    entry = own.get(look)
    return (module.LOOKS[look][2], module.LOOKS[look][3], None, None) if entry is None else (entry[0], entry[1], entry[3], entry[4])
line, tab = colours(sys.argv[3]), colours(sys.argv[4])
print("same" if line[0] == tab[1] and line[2] == tab[3] else "%s/%s %s/%s on %s/%s %s/%s" % (line + tab))
RIGPY
}
rigDown="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^nbd|//p' | LC_ALL=C grep -n '↓' | head -1 | LC_ALL=C cut -d: -f1 )"
rigAssert "every style: under the top of a dialog its empty lines, as under its buttons, its text on the line after them (F11.0: two lines under its top, one more under its buttons)" "$( for rigOne in tv bw nb ; do printf '[%s %s %s]' "$( rigVal "$rigOne.dialogBox" )" "$( rigVal "${rigOne}Under" )" "$( rigVal "${rigOne}Text" )" ; done )" "[30,4,60,32   What the rig asks.][30,4,60,32   What the rig asks.][30,4,60,32   What the rig asks.]"
rigAssert "Basic B/W, whose buttons cast no shadow: an empty line under its buttons too" "[$( rigVal bwButtons | LC_ALL=C sed -e 's/^ *//' )] [$( rigVal bwFoot )]" "[[»OK«]  [ Cancel ]] []"
rigAssert "Magic: the line over a dialog and the line at its foot in the colour of the ground of its title tab, in each of its colours; the marks of a scroll in the look they had" "$( for rigOne in nb:nu-blue ng:nu-gray ns:nu-system ; do rigTag="${rigOne%%:*}r" ; printf '[%s %s]' "$( rigLineOnTab "${rigOne#*:}" "$( rigRole "$rigTag" 1 2 2 )" T )" "$( rigLineOnTab "${rigOne#*:}" "$( rigRole "$rigTag" 32 2 2 )" T )" ; done ) $( rigRole nbs "${rigDown:-1}" 59 59 ) $( rigGround nu-blue G )" "[same same][same same][same same] G black/cyan 16/87 dialog cyan 87"
rigAssert "Magic: the title tab of a dialog at its left, three cells in; a long one cut to leave three cells of the line at its right" "[$( rigVal nbTop )] [$( rigVal longTop )]" "[$( rigRepeat ▁ 3 ) A dialog of the rig $( rigRepeat ▁ 36 )] [$( rigRepeat ▁ 3 ) A title far longer than the box that holds it c… $( rigRepeat ▁ 3 )]"
rigAssert "Magic: the shadow at the right of a dialog starts beside its second line; beside its first stays what lies there" "$( [ "$( rigRole nbr 2 61 61 )" = z ] && echo shadow || echo under ) $( rigRole nbr 3 61 61 )" "under z"

echo "-- on a real terminal, in every style: the cursor shows where what is typed goes while a field has the keys, and nowhere while a button has them --"
"$rigPython" -I -c 'import curses' 2> /dev/null || rigRefuse "the python3 on PATH has no curses module, so the real screen cannot be started here: $rigPython"
rigVt="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/manager-screen.vt.stub.py"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/manager-screen.tools.stub.sh"
[ -f "$rigVt" ] || rigRefuse "the terminal of the screen tests is missing: $rigVt"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenDialogCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/rig" "$rigTmp/ws-rig"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigTools" > "$rigTmp/tools"
chmod +x "$rigTmp/tools"
## every dialog the screen declares is open at its start, each after the one before it closes: Esc up to the Free prompt,
## whose prompt, of several lines, has the keys first; Tab to its name, of one line; Tab to OK; Shift-Tab back to the name
rigPrompt="$( "$rigPython" -I -B - "$rigScreen" <<'RIGPY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
screen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(screen)
print(list(screen.DIALOGS).index("prompt"))
RIGPY
)"
rigSteps="await Dialog message
cursor message"
for rigOne in $( seq 1 "$rigPrompt" ) ; do rigSteps="$rigSteps
keys \\e" ; done
rigSteps="$rigSteps
await Dialog prompt
keys ab
cursor area
keys \\t
keys cd😀
cursor input
keys \\t
cursor button
keys \\e[Z
idle 2.5
cursor again
signal SIGTERM
end end
cursor gone"
rigCursor(){ ## tag -- whether the cursor shows, the field it stands in, what stands before it there, the button that has the keys
	printf '%s %s %s %s' "$( rigVal "$1.shown" )" "$( rigVal "$1.field" )" "$( rigVal "$1.before" | LC_ALL=C sed -e 's/^\[//' )" "$( rigVal "$1.focus" )"
}
for rigOne in nu-blue tv-system bw-system ; do
	printf '%s\n' "$rigSteps" > "$rigTmp/steps"
	rigOut="$( env MANAGER_SCREEN_RIG="$rigTmp/rig" MANAGER_SCREEN_VT_DIALOGS=all MDAT_MANAGER_STYLE="$rigOne" "$rigPython" -I -B "$rigVt" "$rigScreen" run 120 40 "$rigTmp/dump.json" -- \
		"$rigPython" -I -B "$rigVt" "$rigScreen" inner "$rigTmp/dump.json" -- --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" < "$rigTmp/steps" 2>&1 )"
	rigAssert "$rigOne: no cursor on the message box's button; in the Free prompt's prompt, of several lines, it shows after what was typed" \
		"$( rigVal await.Dialog_prompt ) [$( rigCursor message )] [$( rigCursor area )]" "yes [no none  0] [yes 2 ab None]"
	rigAssert "$rigOne: Tab to its name, of one line: the cursor there, after an emoji typed too, as the emoji is written apart" "[$( rigCursor input )]" "[yes 3 cd😀 None]"
	rigAssert "$rigOne: Tab to OK: no cursor; Shift-Tab back to the name: there again, and it stays there as the screen draws again" \
		"[$( rigCursor button )] [$( rigCursor again )] $( rigVal idle.frames | LC_ALL=C sed -e 's/^[1-9][0-9]*$/drawn/' )" "[no none  0] [yes 3 cd😀 None] drawn"
	rigAssert "$rigOne: at the end, by a signal, the cursor shows again" "$( rigVal end.rc ) $( rigVal gone.shown )" "143 yes"
	rm -f "$rigTmp/dump.json"
done

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN DIALOG CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_DIALOG: OK (%d assertions, offline, stand-in terminal and a pseudo-terminal in each style)\n' "$rigPassCount"
