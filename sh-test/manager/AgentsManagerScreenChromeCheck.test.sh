#!/usr/bin/env bash
## Behavioural check on the look of the manager screen (sh-lib/manager/AgentsManagerScreen.py) and on what draws it from its
## declaration, run rather than read. The screen's own code draws through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), which keeps the cells it is given and the look of each, so each case
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
## closes. The styles of STYLES: F9 takes the next one at once; Basic B/W draws what Turbo Vision draws but for the icons
## of Turbo Vision in the frame of the active window; a name that is
## no style is refused, the retired compact one among them, and named in the environment it leaves the default. On a
## real terminal with colours the screen sets colours, on one with none it comes up all the same and sets none, a style
## without colours sets none on a terminal that has them, Magic sets the shades of a terminal of 256 colours, and Alt-X
## ends it with status 0. In Magic, in each of its colours, an empty line stands fixed under the top of each window and
## its content under it, the list's first row beside the ↑ of its scroll bar; Turbo Vision and B/W have none.
## The menus follow the view, the level the list is at: a menu with no command of the view is not in the bar, the commands
## of a view all stand in its menus, and one that does not apply to the row selected is greyed and, tried, says why.
## Offline: the only thing the screen calls here is the stand-in for the dispatcher (check-fixtures/manager-screen.tools.stub.sh).
## Reconciled for F11.5: the list of sixty is Active Sessions of Activity (the `sessions` command of the driver; `..` and the sixty, so 61 rows); its title is the name of the
## list; `Launchpad` and the team are levels of their own, put at with `at`; the key 2 is Pending Questions, 3 Magic-Team (Agents) and 6 Settings; the Go menu holds
## the mounted levels, so the third item down is Activity; the row that goes up is the one that is no session, and its left window is the table of all sixty: a scroll bar, a count of rows in its bottom border, `/ Filter` and `t Sort`.
## Reconciled for F11.0: the spacer under `Launchpad` moves each session row of the list one line down, so the
## click on the first session lands a line lower in Turbo Vision and B/W.
## Reconciled for F11.5, the lists of Activity: the key `a` (all or only the active) is not offered there, as it has nothing to take: not in the status line, and not in the menu View.
## Reconciled for F11.6: the status line of a session names the send-message key too, `M Message`, between `k Kill` and `u Read`.
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
rigTmp="$( rigTempDir AgentsManagerScreenChromeCheck )" || exit 1
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
rigStart(){ ## the commands every case starts with: the row of counters is read, then the list holds sixty sessions that run (Active Sessions of Activity) and is entered
	printf 'tools %s\ntable list:pending none\nsize 120 40\nworkspace /somewhere/ws-rig\nclock 12:34:56\nwait sessions 30\ntable list:magic-team/activity none\nsessions %s\nroot active-sessions\nkeys ENTER\nturn\n' "$rigTmp/tools" "$( awk 'BEGIN { for ( i = 1 ; i <= 60 ; i++ ) printf "r%03d=n%03d ", i, i }' )"
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
rigAssert "each window carries its title in the middle of its top border" "[$( rigVal viewTitle )] [$( rigVal listTitle )]" "[Active Sessions [wrap]] [Active Sessions]"
rigAssert "the active window, the list, has a double frame with the icons of Turbo Vision, the box that closes and the one that zooms, and the other a single one" "[$( rigVal corners )]" "[┌───────────────────────────── Active Sessions [wrap] ─────────────────────────────┐╔═[■]════ Active Sessions ═════[↕]═╗]"
rigAssert "a list longer than its window has a scroll bar for its right border, and so has the other window, whose table of all sixty sessions is longer than it is" "[$( rigVal barTop )][$( rigVal barThumb )][$( rigVal barTrack )][$( rigVal barEnd )] [$( rigVal viewSide )] $( rigVal a.rows )" "[▲][■][▒][▼] [▒] 61"
rigAssert "the bottom borders of the two windows are plain, but for the count of the rows of a table: the counters and the load are the dashboard's" "[$( rigVal foot )] [$( rigVal load )] $( rigVal a.counters | LC_ALL=C grep -c 'load=0.42' )" "[60 rows] [] 1"
rigAssert "the last line names the keys that work now, each key in the look of a hot letter" "[$( rigVal status )] $( rigRole r 40 1 16 )" "[ ENTER Open  BSP Up  / Filter  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut  t Sort] mhhhhhmmmmmmmhhh"
rigAssert "Tab makes the other window the active one: the frames change places" "$( rigVal t.focus ) [$( rigVal cornersT )]" "view [╔═[■]═════════════════════════ Active Sessions [wrap] ═════════════════════════[↕]═╗┌──────── Active Sessions ─────────┐]"
rigAssert "and the status line names the keys of that window"        "[$( rigVal statusT )]" "[ / Filter  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut  t Sort]"
rigAssert "with a row selected it names the keys that act on that row too" "$( rigVal row.selected ) [$( rigVal statusRow )]" "r002 [ ENTER Open  BSP Up  / Filter  k Kill  M Message  J Join  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"

echo "-- Magic's right pane: no > at the left of the selected row, ▶ at its right, and one column of padding --"
rigRun <<'RIGSCRIPT'
keys DOWN
turn
cells tvSel 3 85 119
cells tvEnd 3 117 119
style nu
turn
get nuList
cells nuSel 4 85 119
cells nuEnd 4 117 119
RIGSCRIPT
rigAssert "Turbo Vision keeps its mark at the left and ► at the right edge" "[$( rigVal tvSel )][$( rigVal tvEnd )]" "[>n001                    running ►][ ►]"
rigAssert "Magic draws no mark of the selection at the left, ▶ at the right, and a blank column after it: the row is one cell narrower" "$( rigVal nuList.style ) [$( rigVal nuSel )][$( rigVal nuEnd )]" "nu [ n001                   running ▶][▶]"

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
keys TAB
get keyed
keys ALT-g t
get team
keys F10 RIGHT ENTER
get grey
keys ESC ALT-x
get out
RIGSCRIPT
rigAssert "F10 opens the first menu, its bar on its first item"     "$( rigVal m.menu )" "go:dashboard"
rigAssert "the pull-down is a frame with its items, their keys at the right, and a line between two groups" "$( rigHas m '┌───' ) $( rigHas m '│ Pending Questions        2 │' ) $( rigHas m '│ Exit                    ^X │' ) $( rigHas m '│ Open                 ENTER │' ) $( rigHas m '│ Up one level           BSP │' ) $( rigHas m '├───' ) $( rigHas m '└───' )" "1 1 1 1 1 2 2"
rigAssert "the item the bar is on stands in the look of the bar, another has its hot letter in a look of its own, and the pull-down has a shadow" "$( rigRole mr 3 4 9 ) $( rigRole mr 4 4 9 ) $( rigRole mr 4 34 35 )" "moOooo mmhmmm ww"
rigAssert "the status line names the keys of a menu"                 "$( rigLine m 40 | LC_ALL=C sed -e 's/  *$//' )" " ENTER Choose  ESC Close  ←/→ Menus  UP/DN Items"
rigAssert "Down moves the bar"                                       "$( rigVal m2.menu )" "go:activity"
rigAssert "Right opens the menu beside it"                           "$( rigVal s.menu )" "session:kill"
rigAssert "an item that does not apply to the row selected is greyed" "$( rigRole sr 4 9 14 )" "xxxxxx"
rigAssert "Esc closes the menu"                                      "[$( rigVal closed.menu )]" "[]"
rigAssert "Alt with the hot letter of a menu opens that menu"        "$( rigVal v.menu )" "view:read"
rigAssert "Enter chooses the item the bar is on (Next window): the menu closes, and the command is done" "[$( rigVal chosen.menu )] $( rigVal chosen.focus )" "[] view"
rigAssert "the key of that command does the same: Tab takes the keys back to the list" "$( rigVal keyed.focus )" "list"
rigAssert "the hot letter of an item chooses it"                     "[$( rigVal team.menu )] $( rigVal team.path )" "[] magic-team/team"
rigAssert "an item that does not apply is not chosen: the menu stays, nothing is done, and the status line says why" "$( rigVal grey.menu ) [$( rigVal grey.notice )] [$( rigVal grey.dialog )]" "member:start [Start: for a team member, not for what is selected] []"
rigAssert "Alt-X ends the screen"                                    "$( rigVal out.quit )" "yes"

echo "-- the shadow of a menu stands beside each of its rows, a line between two groups as much as an item --"
for rigStyle in tv magic ; do
	rigRun <<RIGSCRIPT
style $rigStyle
keys F10
show sh
roles shr
RIGSCRIPT
	## Turbo Vision's shadow is two cells wide, Magic's slim one a single cell; the right edge of the pull-down is read off
	## its first item, and the line between two groups is a row of it whose text holds the left junction of the rule, in
	## Magic the blank of its side with the line after it
	rigWide=2 ; [ "$rigStyle" = tv ] || rigWide=1
	rigEdge="$( rigLine shr 3 | LC_ALL=C sed -e 's/^\(...[mhoOx]*\).*/\1/' )" ; rigEdge="${#rigEdge}"
	rigBeside="" ; rigRow=3
	while [ "$( rigRole shr "$rigRow" 4 4 )" = m ] ; do
		case "$( rigLine sh "$rigRow" )" in *├*|*' ───'*) rigBeside="$rigBeside $( rigRole shr "$rigRow" $(( rigEdge + 1 )) $(( rigEdge + rigWide )) )" ;; esac
		rigRow=$(( rigRow + 1 ))
	done
	rigAssert "in the style $rigStyle the cells beside each line between two groups of a menu are its shadow, as beside an item" "$( rigVal style.refused )[$( rigRole shr 3 $(( rigEdge + 1 )) $(( rigEdge + rigWide )) )] [${rigBeside# }]" "$( [ "$rigStyle" = tv ] && echo '[ww] [ww ww]' || echo '[z] [z z]' )"
done

echo "-- in Magic a pull-down hangs from the menu bar: no edge row between the bar and its first item; its sides, its bottom and its shadow stand as before --"
rigRun <<'RIGSCRIPT'
style nu
keys F10
show hang
roles hangr
cells hangTop 1 3 31
RIGSCRIPT
rigAssert "Magic menu: no edge row between the bar and the first item, which stands on the line under the bar between its sides, its shadow beside it" "$( rigVal style.refused )[$( rigVal hangTop )] $( rigRole hangr 2 4 6 ) $( rigHas hang '▛' )" "[  Dashboard (Monitor)   1  ▁] moO 0"
rigAssert "and its bottom a thin line, the shadow half a line under it (the lines over and under the windows hold such a line too)" "$( rigHas hang "$( rigRepeat ▁ 27 )" ) $( rigHas hang "$( rigRepeat ▄ 27 )" )" "3 1"
rigAssert "Magic menu: its shadow at its right starts beside its second item; beside its first stays what lies there" "$( [ "$( rigRole hangr 2 31 31 )" = z ] && echo shadow || echo under ) $( rigRole hangr 3 31 31 )" "under z"
rigRun <<'RIGSCRIPT'
keys F10
cells tvTop 1 3 7
RIGSCRIPT
rigAssert "Turbo Vision keeps the top border of its pull-down" "[$( rigVal tvTop )]" "[┌───]"
rigRun <<'RIGSCRIPT'
style nu
turn
roles edr
cells edTop 1 0 120
RIGSCRIPT
rigAssert "Magic windows: each title a tab at the left of the line over it, three cells in" "$( rigVal style.refused )[$( rigVal edTop )]" "[$( rigRepeat ▁ 3 ) Active Sessions [wrap] $( rigRepeat ▁ 56 ) $( rigRepeat ▁ 3 ) Active Sessions $( rigRepeat ▁ 15 )]"
rigAssert "Magic windows: the shadow of the right column starts beside a window's second line; beside its first stays the desktop, as beside its top" "$( rigRole edr 2 84 84 ) $( rigRole edr 3 84 84 ) $( rigRole edr 4 84 84 )" "v v |"

echo "-- Magic's scroll bar: in the cells of the shadow, a line lower than in the other styles, its arrows and thumb ▍ white on the shadow's black, grey and ▎ in another window --"
rigRun <<'RIGSCRIPT'
style nu
turn
roles nbr
cells nbFirst 2 119 120
cells nbUp 3 119 120
cells nbThumb 4 119 120
cells nbTrack 30 119 120
cells nbDown 38 119 120
keys TAB
turn
roles nbo
cells nbOffUp 3 119 120
cells nbOffThumb 4 119 120
keys TAB
turn
mouse click 119 38
get nbPaged
RIGSCRIPT
rigBarColours="$( "$rigPython" -I -B - "$rigScreen" <<'RIGPY' 2>&1
import importlib.util, sys
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
for name in ("nu-system", "nu-blue", "nu-gray"):
    arrows, thumb, track, shadow = (module.STYLE_LOOKS[name][look] for look in (module.SCROLL, module.THUMB, module.TRACK, module.SHADOW))
    shown = " ".join("%s/%s%s" % (look[:2] + ("b" if look[2] else "",) if look[3] is None else look[3:5] + ("b" if look[5] else "",))
                     for look in (arrows, thumb, track))
    print("%s %s %s" % (name, shown, arrows[1] == thumb[1] == track[1] == shadow[1] and arrows[4] == thumb[4] == track[4] == shadow[4]))
RIGPY
)"
rigAssert "Magic's scroll bar starts a line lower than Turbo Vision's: beside the window's first line the desktop, ↑ beside its second, ↓ on its last line, the thumb ▍ and the track blank" "$( rigVal style.refused )[$( rigVal nbFirst )][$( rigVal nbUp )][$( rigVal nbThumb )][$( rigVal nbTrack )][$( rigVal nbDown )] $( rigRole nbr 3 120 120 )$( rigRole nbr 4 120 120 )$( rigRole nbr 5 120 120 )$( rigRole nbr 31 120 120 )$( rigRole nbr 39 120 120 )" "[][↑][▍][][↓] Vs#|s"
rigAssert "in a window that is not active its arrows and its thumb, ▎, in the track's look" "[$( rigVal nbOffUp )][$( rigVal nbOffThumb )] $( rigRole nbo 4 120 120 )$( rigRole nbo 5 120 120 )" "[↑][▎] ||"
rigAssert "a click on Magic's ↓, on the window's last line, pages down as the lower half of the bar does" "$( [ "$( rigVal nbPaged.index )" -gt 30 ] && echo down || rigVal nbPaged.index ) $( rigVal nbPaged.spills )" "down 0"
rigAssert "in each of Magic's colours, on the black of the shadow: the arrows white and bold, the thumb white, and the track's look, which the arrows and the thumb of another window take, grey" "$( printf '%s\n' "$rigBarColours" | LC_ALL=C tr '\n' ' ' )" "nu-system white/blackb white/blackb white/black True nu-blue 231/16b 231/16 244/16 True nu-gray 231/16b 231/16 244/16 True "

echo "-- Magic keeps an empty line fixed under the top of each window, its content under it; Turbo Vision and B/W do not --"
rigRun <<'RIGSCRIPT'
get t
cells tFirstView 2 1 83
RIGSCRIPT
rigTvFirstView="$( rigVal tFirstView )" ; rigTvHeights="$( rigVal t.viewHeight ) $( rigVal t.listHeight )"
for rigStyle in nu-system nu-blue nu-gray ; do
	rigRun <<RIGSCRIPT
style $rigStyle
turn
get m
cells mGapView 2 1 83
cells mGapList 2 85 119
cells mFirstView 3 1 83
cells mFirstRow 3 85 119
cells mUp 3 119 120
roles mr
mouse click 100 4
get mClick
keys PGDN
turn
get mDown
cells mGapDown 2 1 119
RIGSCRIPT
	rigAssert "in $rigStyle the line under each window's top is empty, also scrolled down; the pane's first line and the list's first row, in the bar's look, beside the ↑, stand under it" \
		"$( rigVal style.refused )[$( rigVal mGapView | LC_ALL=C tr -d ' ' )][$( rigVal mGapList | LC_ALL=C tr -d ' ' )][$( rigVal mGapDown | LC_ALL=C tr -d ' ' )] $( [ "$( rigVal mFirstView )" = "$rigTvFirstView" ] && echo same || echo moved ) $( rigVal mFirstRow | LC_ALL=C grep -c -F '..' ) $( rigRole mr 4 87 90 ) [$( rigVal mUp )] $( [ "$( rigVal mDown.top )" -gt 0 ] && echo scrolled )" \
		"[][][] same 1 RRRR [↑] scrolled"
	rigAssert "in $rigStyle each window holds a line less than in Turbo Vision, and a click lands on the row drawn there" "$( rigVal m.viewHeight ) $( rigVal m.listHeight ) $( rigVal mClick.index )" "$(( ${rigTvHeights% *} - 1 )) $(( ${rigTvHeights#* } - 1 )) 1"
done
for rigStyle in tv bw ; do
	rigRun <<RIGSCRIPT
style $rigStyle
turn
get c
cells cFirstRow 2 85 119
mouse click 100 5
get cClick
RIGSCRIPT
	rigAssert "in $rigStyle the first row stands right under the top, as before" "$( rigVal cFirstRow | LC_ALL=C grep -c -F '..' ) $( rigVal c.viewHeight ) $( rigVal c.listHeight ) $( rigVal cClick.index )" "1 $rigTvHeights 3"
done

echo "-- the menus follow the view --"
rigRun <<'RIGSCRIPT'
cells barSessions 0 0 40
keys ALT-s
show ss
roles ssr
mouse click 10 5
get clicked
keys ESC k
get byKey
keys n
get otherView
at @magic-team launch
turn
cells barLaunch 0 0 40
keys ALT-s
show sl
keys ESC 2
turn
cells barPending 0 0 40
at @team
turn
turn
cells barTeam 0 0 40
keys 6
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
rigAssert "and Launchpad, whose menu of the same name holds its two alone: the routine and the starts" "$( rigHas sl '│ Start the routine' ) $( rigHas sl '│ Start a session' ) $( rigHas sl '│ Kill ' ) $( rigHas sl '│ Pause' )" "1 1 0 0"
rigAssert "one that does not apply to the row selected is greyed" "$( rigRole ssr 6 9 14 )" "xxxxxx"
rigAssert "clicked, it is not chosen: the menu stays, and the status line says why" "$( rigVal clicked.menu ) [$( rigVal clicked.notice )] [$( rigVal clicked.dialog )]" "session:pause [Pause is not built yet] []"
rigAssert "tried by its key, it says why in the status line, and no box opens" "[$( rigVal byKey.notice )] [$( rigVal byKey.dialog )]" "[Kill: for a session or an agent, not for what is selected] []"
rigAssert "the key of a command of another view is no key here: nothing opens, and the status line keeps what it said" "[$( rigVal otherView.notice )] [$( rigVal otherView.dialog )]" "[Kill: for a session or an agent, not for what is selected] []"

echo "-- the styles --"
rigRun <<'RIGSCRIPT'
get tv
show t
keys F9
get bw
show b
keys F9
get magic
keys F9
get back
style nonsense
get still
style mc
get retired
RIGSCRIPT
rigAssert "F9 takes the next style at once, and the status line says which" "$( rigVal tv.style ) $( rigVal bw.style ) [$( rigVal bw.notice )] $( rigVal magic.style ) [$( rigVal magic.notice )]" "tv bw [interface style: Basic B/W - System] nu [interface style: Magic - System]"
rigAssert "Basic B/W is the next: it draws what Turbo Vision draws, cell for cell, but for the icons of Turbo Vision in the frame of the active window" "$( rigVal bw.style ) $( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^b|//p' | LC_ALL=C sed -n '1,39p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^t|//p' | LC_ALL=C sed -n '1,39p' | LC_ALL=C sed -e 's/═\[■\]═/═════/' -e 's/═\[↕\]═/═════/' )" ] && echo same || echo differs ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^t|' | LC_ALL=C grep -c -F -e '═[■]═' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^t|' | LC_ALL=C grep -c -F -e '═[↕]═' )" "bw same 1 1"
rigAssert "and after the last style comes the first again"          "$( rigVal back.style )" "tv"
rigAssert "a name that is no style is refused, and the style stays"  "$( rigVal style.refused ) $( rigVal still.style )" "nonsense tv"
rigAssert "the compact style is retired: its name is no style any more" "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^style.refused=//p' | LC_ALL=C tr '\n' ' ' )$( rigVal retired.style )" "nonsense mc tv"

echo "-- the real screen, on a terminal with colours and on one with none --"
rigPty 100 30 "Magic-Team (Agents)" '\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "on a terminal with colours the screen comes up in its colours, and Alt-X ends it with status 0" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.errorAfterLeft )" "yes yes 0 yes none"
MANAGER_SCREEN_PTY_TERM=vt100 rigPty 100 30 "Magic-Team (Agents)" '\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "on a terminal with no colours it comes up all the same, and sets none" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.rc ) $( rigVal pty.errorAfterLeft )" "yes no 0 none"
rigPty 100 30 "Magic-Team (Agents)" '\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" --style bw
rigAssert "started in the style Basic B/W it sets no colour on a terminal that has them" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.rc )" "yes no 0"
MDLT_MANAGER_STYLE=mc rigPty 100 30 "Magic-Team (Agents)" '\x18' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "the environment names the retired compact style: the default comes up instead, in its colours, and Ctrl-X ends it" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.shades ) $( rigVal pty.rc )" "yes yes no 0"
MANAGER_SCREEN_PTY_TERM=xterm-256color rigPty 100 30 "Magic-Team (Agents)" '\x18' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" --style magic
rigAssert "started in Magic on a terminal of 256 colours it sets the shades of that palette, and Ctrl-X ends it" "$( rigVal pty.frame ) $( rigVal pty.shades ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.errorAfterLeft )" "yes yes 0 yes none"
rigPty 100 30 "Magic-Team (Agents)" '\x18' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" --style magic
rigAssert "and on a terminal of eight colours in the eight" "$( rigVal pty.frame ) $( rigVal pty.colours ) $( rigVal pty.shades ) $( rigVal pty.rc )" "yes yes no 0"

echo "-- the machine's name stands whole: in a narrow top line the workspace gives way first, then the seconds, then the start of the machine's name --"
mkdir -p "$rigTmp/long" ; : > "$rigTmp/long/calls" ; echo rows > "$rigTmp/long/mode"
printf 'counters\t2\t0\t1\t2\t3\t0.42\tmagic-mac-studio.office.example.net\n' > "$rigTmp/long/rows.--manager-session-list"
for rigStyle in tv ; do
	MANAGER_SCREEN_RIG="$rigTmp/long" rigScript <<RIGSCRIPT
style $rigStyle
tools bash $MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/manager-screen.tools.stub.sh
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

echo "-- the exit: Esc and then x as a terminal sends it and as a hand types it, Ctrl-X, and what Option types on a Mac --"
rigPty 100 30 "Magic-Team (Agents)" '\e\px' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "Esc, and x a moment after it, typed by hand, ends the real screen in Turbo Vision" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.errorAfterLeft )" "yes 0 yes none"
rigPty 100 30 "Magic-Team (Agents)" '\e\px' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" --style bw
rigAssert "and in Basic B/W"                                          "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left )" "yes 0 yes"
rigPty 100 30 "Magic-Team (Agents)" '\x18' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "Ctrl-X ends the real screen: the key every terminal delivers" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.errorAfterLeft )" "yes 0 yes none"
rigPty 100 30 "Magic-Team (Agents)" 'm\p\ex' "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools"
rigAssert "with a menu open, Esc with x at once ends the real screen too, as the menu declares" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left )" "yes 0 yes"
rigOut="$( "$rigPython" -I -B "$rigDriver" "$rigScreen" pty 100 30 "Magic-Team (Agents)" '?\p\ex' 3 -- "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" 2>&1 )"
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
for rigStyle in bw magic ; do
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
rigScript <<'RIGSCRIPT'
size 120 40
turn
keys ©
get g
keys ESC
at @activity active-sessions
turn
keys ß
get s
keys ESC
at @team
turn
keys µ
get m
keys ESC √
get v
keys ESC ˙
get h
keys ESC £
get two
keys ≈
get x
RIGSCRIPT
rigAssert "what Option types on a Mac opens the menu of that letter, where the view has that menu: g, s among the sessions, m in the team, v, h" "$( rigVal g.menu ) $( rigVal s.menu ) $( rigVal m.menu ) $( rigVal v.menu ) $( rigVal h.menu )" "go:dashboard session:kill member:start view:read help:help"
rigAssert "Option with a digit goes to that section, and Option with x ends the screen" "$( rigVal two.path ) $( rigVal x.quit )" "magic-team yes"
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

echo "-- the names of the keys: each style its own set, each name one cell, and a click on a name finds its key --"
rigNames="$( "$rigPython" -I -B - "$rigScreen" 2>&1 <<'RIGPY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("screen", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
keys = ("ENTER", "TAB", "ESC", "LEFT", "RIGHT", "UP", "DOWN", "BACKSPACE", "PGUP", "PGDN")
for style in ("tv", "bw", "symbols"):
    if style == "symbols":
        m.STYLE["names"] = "symbols"
    else:
        m.setStyle(style)
    names = [m.keyShown(key) for key in keys]
    print(style, " ".join(names), "|", " ".join(str(m.textWidth(name)) for name in names), "|",
          all(m.keyOfShown(m.keyShown(key)) == key for key in keys), m.keysShown("LEFT/RIGHT"), m.keysShown("UP/DOWN"))
RIGPY
)"
rigAssert "Turbo Vision: capitals, and the arrows of the IBM PC set for Left and Right; a click on each finds its key" "$( printf '%s\n' "$rigNames" | LC_ALL=C grep '^tv ' )" "tv ENTER TAB ESC ← → UP DN BSP PgUp PgDn | 5 3 3 1 1 2 2 3 4 4 | True ←/→ UP/DN"
rigAssert "B/W: the same" "$( printf '%s\n' "$rigNames" | LC_ALL=C grep '^bw ' )" "bw ENTER TAB ESC ← → UP DN BSP PgUp PgDn | 5 3 3 1 1 2 2 3 4 4 | True ←/→ UP/DN"
rigAssert "the set of symbols: one cell each, and no emoji" "$( printf '%s\n' "$rigNames" | LC_ALL=C grep '^symbols ' )" "symbols ⏎ ⇥ ⎋ ← → ↑ ↓ ⌫ PgUp PgDn | 1 1 1 1 1 1 1 1 4 4 | True ←/→ ↑/↓"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN CHROME CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_CHROME: OK (%d assertions, offline, stand-in terminal and one pseudo-terminal)\n' "$rigPassCount"
