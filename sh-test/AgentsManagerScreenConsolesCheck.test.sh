#!/usr/bin/env bash
## Behavioural check on the root `Consoles` of the manager screen (sh-lib/AgentsManagerScreen.py), run rather
## than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which notes each start and prints the fixture: rows in the form
## `--manager-console-list` prints, `console <key> <group> <label> <terminal> <directory> <word>...`.
## Held: the root list holds `Consoles` as a folder, ahead of the settings, and `6` and the `Go` menu go
## there; its list is read only while it is shown, by `--manager-console-list` with no argument; its rows stand in
## the order of the operation, each by its label with its group at the end of its line, and a line that is no row
## of a console is left out; the left window shows what the folder holds, group by group, and of the selected row
## its label, key, group, folder, its command as it will be run, word by word, and whether it needs a terminal; the
## menu `Console` is in the bar in that view alone, and the status line names Enter as Start; Enter gives the
## terminal to a child that is started from the words of the row exactly as they were printed, a word with a blank
## one word, `_` and `-` as they are, in the folder of the row, with no shell; the status line then says how the
## child ended, by its status or by the signal that ended it, and the list is read again; a command that cannot be
## started says why in a box, whole; the size the terminal has when the child has ended is the size the screen is
## drawn in; the three styles draw it.
## And on a pseudo-terminal, with the real screen and a stand-in console: before the child starts the screen has
## left its own mode, the mouse no longer reported and the other screen of the terminal left, and the child has the
## terminal in the shell's mode; while it runs the screen writes nothing; after a normal end, after an end by a
## signal, and after the terminal was resized meanwhile, the screen is back, drawn whole in the size the terminal
## has then, the mouse reported again, the status line saying how the child ended; and at its own end the terminal
## is given back as it was.
## Offline: no operation of the real tooling is called, and no console of this machine is started.
## Reconciled for F11.0: the left pane has no `keys:` line of its own any more; the status line names Enter as Start.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py"
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
rigTmp="$( mktemp -d -t AgentsManagerScreenConsolesCheck )" || exit 1
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
## Four consoles in three groups, as the operation orders them, in a workspace whose path holds a blank. The shell:
## a word of its command holds blanks, another an underscore. A console of the agents. Two of the distro, the
## second one that needs no terminal and whose words are `-` and `_`, which are exact there. And two lines that are
## no row of a console: one of another name, one too short to hold a command.
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow console bash shell Bash_Shell terminal "/rig/ws rig" /usr/bin/env "MMDAPP=/rig/ws rig" "REASON=the shell of the workspace, by its own name." /rig/sh_x --rcfile "/rig/ws rig/rc_file" -i
	rigRow console claude-native agents Claude_Native_Console terminal "/rig/ws rig" "/rig/ws rig/DistroAgentsConsole.sh" --cli claude-native
	rigRow console source distro Source_Console terminal "/rig/ws rig" "/rig/ws rig/DistroSourceConsole.sh"
	rigRow console plain distro Plain_Tool - "/rig/ws rig" /rig/tool_x - _
	rigRow other thing of another name
	rigRow console short distro Too_Short terminal "/rig/ws rig"
} > "$rigF/rows.--manager-console-list"
rigRow counters 0 0 0 0 0 0.42 > "$rigF/rows"
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
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize %s\nroot sessions\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigPane(){ ## tag, line counted from 1 -- the left pane's part of that line of the screen, without the spaces at its end
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/^┌\(─\)* \(.*\) \(─\)*┐.*$/ \2/' -e 's/^╔\(═\)* \(.*\) \(═\)*╗.*$/ \2/' -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' -e 's/  *$//'
}
rigScreenHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigOthers(){ ## how many starts were neither the list of the sessions nor the list of the consoles with no argument. The list of the locations, which every start of the screen reads, is not counted.
	LC_ALL=C grep -c -v -x -e '--manager-session-list' -e '--manager-console-list' -e '--manager-place-list' "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- Consoles is a root, a folder, and lists what the operation gives --"
rigCase list
rigScript <<'RIGSCRIPT'
turn
wait sessions 30
show rootShown
root consoles
turn 3
advance 11
wait sessions 30
wait focus 30
get on
roles o
keys ENTER
wait list 30
turn
get in
border title 1 84 120
cells bar 0 0 40
cells row1 2 85 119
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
cells row5 6 85 119
cells row6 7 85 119
show u
cells upStatus 39 0 120
keys LEFT
turn
get root
keys 6
turn
get six
keys m
turn
show g
RIGSCRIPT
rigRootLine(){ ## text -- the number of the line of the screen, as first shown, that holds the text
	printf '%s\n' "$rigOut" | LC_ALL=C grep '^rootShown|' | LC_ALL=C grep -n -F -- "$1" | head -1 | LC_ALL=C cut -d: -f1
}
rigAssert "the root list holds it after the team members and ahead of the settings, as a folder, whatever other roots stand between" "$( [ "$( rigRootLine ' Team Members  ' )" -lt "$( rigRootLine ' Consoles  ' )" ] && [ "$( rigRootLine ' Consoles  ' )" -lt "$( rigRootLine ' Settings  ' )" ] && echo in-that-order ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^rootShown|' | LC_ALL=C grep -F ' Consoles  ' | LC_ALL=C grep -c -F '►' )" "in-that-order 1"
rigAssert "not entered: its list is read once the selection has rested on its row, and the left window then holds what the folder holds" "$( rigVal on.selected ) [$( rigVal on.reading )] $( rigVal on.viewLines )" "consoles [] 8"
rigAssert "Enter enters it, and its list is read by the operation with no argument" "$( rigVal in.path ) $( rigCalled --manager-console-list ) $( rigOthers )" "consoles 1 0"
rigAssert "its window is titled by its name, without the dots"       "[$( rigVal title )]" "[Consoles]"
rigAssert "the rows stand in the order of the operation, each by its label with its group at the end" "[$( rigVal row1 )][$( rigVal row2 )][$( rigVal row3 )][$( rigVal row4 )][$( rigVal row5 )]" \
	"[>..][ Bash Shell                  shell][ Claude Native Console      agents][ Source Console             distro][ Plain Tool                 distro]"
rigAssert "a line that is no row of a console, and one too short to hold a command, is left out" "$( rigVal in.rows ) [$( rigVal row6 )]" "5 []"
rigAssert "on the row that goes up the left window shows the folder itself: every one as a table, nothing above it, and no sentence of what Enter does" "[$( rigPane u 2 )][$( rigPane u 3 | LC_ALL=C sed 's/  */ /g' )]" \
	"[ Consoles [wrap]][ CONSOLE GROUP COMMAND]"
rigAssert "the menu Console is in the bar in this view"              "[$( rigVal bar )] [$( rigVal upStatus )]" "[ ≡  Go  Console  View  Help] [ ENTER Open  BSP Up  a Active  u Read  m Menu  ^X Exit  TAB Window  ? Help]"
rigAssert "Left goes back to the root, onto its row, and 6 goes there from anywhere" "[$( rigVal root.path )] $( rigVal root.selected ) [$( rigVal six.path )]" "[] consoles [consoles]"
rigAssert "the Go menu holds it with its key"                        "$( rigScreenHolds g '│ Consoles                 6 │' )" 1

echo "-- the left window shows the selected console --"
rigCase shown
rigScript <<'RIGSCRIPT'
turn
keys 6
wait list 30
keys DOWN
turn
show c
border cTitle 1 0 84
cells cKeys 37 1 83
cells cStatus 39 0 120
get c
keys m RIGHT
turn
show m
keys ESC DOWN DOWN DOWN
turn
show p
RIGSCRIPT
rigAssert "its title is its label, and under it its label as its head, its key and its group" "[$( rigVal cTitle )][$( rigPane c 3 )][$( rigPane c 4 )][$( rigPane c 5 )]" "[Bash Shell [wrap]][ Bash Shell][  key        bash][  group      shell]"
rigAssert "the folder it is started in, as it is written"            "[$( rigPane c 6 )]" "[  directory  /rig/ws rig]"
rigAssert "its command as it will be run, word by word: a word with a blank stands between quotes" "[$( rigPane c 7 )][$( rigPane c 8 )][$( rigPane c 9 )]" \
	"[  command    /usr/bin/env 'MMDAPP=/rig/ws rig' 'REASON=the shell of the workspace,][             by its own name.' /rig/sh_x --rcfile '/rig/ws rig/rc_file' -i][  terminal   yes, on its input and its output]"
rigAssert "no sentence of what Enter does: its key stands in the status line, and the pane has no keys line of its own" "[$( rigPane c 10 )][$( rigPane c 11 )] [$( rigVal cKeys )] [$( rigVal cStatus )]" \
	"[][] [] [ ENTER Start  BSP Up  a Active  u Read  m Menu  ^X Exit  TAB Window  ? Help]"
rigAssert "nothing was read for it but the list, and nothing spills" "$( rigCalled --manager-console-list ) $( rigOthers ) $( rigVal c.spills )" "1 0 0"
rigAssert "the menu Console holds the start, with its key"           "$( rigScreenHolds m '│ Start  ENTER │' )" 1
rigAssert "one that needs no terminal says so, and its words stand as they are" "[$( rigPane p 7 )][$( rigPane p 8 )]" "[  command    /rig/tool_x - _][  terminal   no]"

echo "-- Enter gives the terminal to a child, started from the words of the row as they are --"
rigCase enter
rigScript <<'RIGSCRIPT'
turn
keys 6
wait list 30
keys DOWN
turn
get before
child 3
keys ENTER
get a
said aLine
wait list 30
turn
get after
RIGSCRIPT
rigAssert "until Enter no child is started"                          "$( rigVal before.children )" 0
rigAssert "Enter starts one child, from the words as they were printed: a word with a blank is one word" "$( rigVal a.children ) $( rigVal a.childWords )" \
	"1 [/usr/bin/env][MMDAPP=/rig/ws rig][REASON=the shell of the workspace, by its own name.][/rig/sh_x][--rcfile][/rig/ws rig/rc_file][-i]"
rigAssert "in the folder of the row, as it was printed"              "[$( rigVal a.childDirectory )]" "[/rig/ws rig]"
rigAssert "the status line says how it ended, by its status"         "[$( rigVal aLine )] [$( rigVal a.dialog )]" "[Bash Shell: ended with status 3] []"
rigAssert "the selection stays, and the list is read again"          "$( rigVal after.selected ) $( rigCalled --manager-console-list ) $( rigOthers )" "bash 2 0"
rigCase ends
rigScript <<'RIGSCRIPT'
turn
keys 6
wait list 30
keys DOWN DOWN DOWN DOWN
child 0
keys ENTER
get plain
said plainLine
keys UP UP
child -15
keys ENTER
get b
said bLine
RIGSCRIPT
rigAssert "words that are - and _ are given as they are"             "$( rigVal plain.childWords ) [$( rigVal plainLine )]" "[/rig/tool_x][-][_] [Plain Tool: ended with status 0]"
rigAssert "a child that a signal ended: the status line says which, and the screen lives on" "$( rigVal b.children ) [$( rigVal bLine )] $( rigVal b.quit )" "2 [Claude Native Console: ended by signal 15 (SIGTERM)] no"

echo "-- a command that cannot be started says why in a box; the size the terminal has afterwards is taken --"
rigCase fails
rigScript <<'RIGSCRIPT'
turn
keys 6
wait list 30
keys DOWN DOWN
child missing
keys ENTER
get m
box x
keys ENTER
get closed
child 0 90 24
keys ENTER
get sized
show s
said sLine
keys TAB ENTER
get tab
RIGSCRIPT
rigAssert "a box says it whole: what, where, the command, and why"   "[$( rigVal m.dialogTitle )] [$( rigVal m.dialogHolds )]" \
	"[It did not start] [console: Claude Native Console / directory: /rig/ws rig / command: '/rig/ws rig/DistroAgentsConsole.sh' --cli claude-native / [Errno 2] No such file or directory: '/rig/ws rig/DistroAgentsConsole.sh']"
rigAssert "and the status line says nothing of an end"               "[$( rigVal m.notice )] [$( rigVal closed.dialog )]" "[] []"
rigAssert "the terminal was resized while the child ran: the screen is drawn in the size it has now" "$( rigVal sized.columns )x$( rigVal sized.lines ) $( rigVal sized.layout ) $( rigVal sized.spills ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^s|' ) [$( rigVal sLine )]" \
	"90x24 ok 0 24 [Claude Native Console: ended with status 0]"
rigAssert "with the keys on the left window Enter starts nothing"    "$( rigVal sized.children ) $( rigVal tab.children ) $( rigVal tab.focus )" "2 2 view"

echo "-- the three styles draw it --"
for rigStyle in tv bw magic ; do
	rigCase "style-$rigStyle"
	rigScript <<RIGSCRIPT
style $rigStyle
turn
keys 6
wait list 30
keys DOWN
turn
show c
child 5
keys ENTER
get a
RIGSCRIPT
	rigAssert "$rigStyle: the list, the left window, and Enter starts the child" "$( rigScreenHolds c ' Claude Native Console ' ) $( rigScreenHolds c 'directory  /rig/ws rig' ) $( rigVal a.children ) [$( rigVal a.notice )] $( rigVal a.spills )" \
		"1 1 1 [Bash Shell: ended with status 5] 0"
done

echo "-- on a pseudo-terminal: the real screen gives the terminal to a stand-in console and takes it back --"
## The stand-in console. It notes what it was started with and what it found, says that it is up, and ends as its
## first word says: `exit`, after a line was typed to it, with status 7; `signal`, by a signal it raises on itself;
## `resize`, after a line was typed to it, with status 0, noting the size the terminal has then.
cat > "$rigTmp/standin.py" <<'RIGSTANDIN'
import os, signal, sys, termios
how, facts = sys.argv[1], sys.argv[2]
mode = termios.tcgetattr(0)[3]
with open(facts, "w") as out:
    out.write("argv=%s\n" % "".join("[%s]" % word for word in sys.argv[3:]))
    out.write("cwd=%s\n" % os.getcwd())
    out.write("tty=%s\n" % ("yes" if os.isatty(0) and os.isatty(1) else "no"))
    out.write("cooked=%s\n" % ("yes" if mode & termios.ICANON and mode & termios.ECHO else "no"))
    out.write("size=%dx%d\n" % tuple(os.get_terminal_size(1)))
sys.stdout.write("STANDIN-UP\n")
sys.stdout.flush()
if how == "signal":
    sys.stdout.write("STANDIN-END\n")
    sys.stdout.flush()
    signal.raise_signal(signal.SIGTERM)
sys.stdin.readline()
with open(facts, "a") as out:
    out.write("sizeAtEnd=%dx%d\n" % tuple(os.get_terminal_size(1)))
sys.stdout.write("STANDIN-END\n")
sys.stdout.flush()
sys.exit(7 if how == "exit" else 0)
RIGSTANDIN
mkdir -p "$rigTmp/ws rig"
printf '#!/usr/bin/env bash\nexec bash %q "$@"\n' "$rigTools" > "$rigTmp/tools" ; chmod +x "$rigTmp/tools"
rigPtyCase(){ ## name, how the stand-in ends
	rigCase "$1"
	rigRow console standin alpha_bravo_charlie_delta_echo_foxtrot_golf_hotel_india_juliet_kilo_lima_mike_november_oscar_papa_quebec_romeo Rig_Standin terminal "$rigTmp/ws rig" "$rigPython" -I -B "$rigTmp/standin.py" "$2" "$MANAGER_SCREEN_RIG/facts" "a word" _ - > "$MANAGER_SCREEN_RIG/rows.--manager-console-list"
}
rigPty(){ ## the keys -- what the driver says of the run is kept in rigOut
	rigOut="$( MANAGER_SCREEN_PTY_TRACE="$rigTrace" "$rigPython" -I -B "$rigDriver" "$rigScreen" pty 100 30 "Consoles" "$1" 60 -- "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws rig" --tools "$rigTmp/tools" 2>&1 )"
}
rigFact(){ ## name -- what the stand-in console noted under it
	LC_ALL=C sed -n "s/^$1=//p" "$MANAGER_SCREEN_RIG/facts" 2> /dev/null | head -1
}
## What the trace says of a run, by where the stand-in said it was up and that it ends: how the mouse and the other
## screen of the terminal stood when it came up; how many times the screen wrote either while it ran; what came
## after its end, the other screen entered, the mouse reported, what the status line says, the left window as a
## terminal of 100 columns breaks it and as one of 70 does; and how the two stood at the very end.
rigTraced(){
	rigVal pty.trace | LC_ALL=C awk '{
		for ( at = 1 ; at <= NF ; at++ ) {
			if ( $at == "up" ) { phase = 1 ; before = mouse "/" other ; continue ; }
			if ( $at == "end" ) { phase = 2 ; continue ; }
			if ( $at == "on" || $at == "off" ) { mouse = $at ; if ( phase == 1 ) { during++ ; } if ( phase == 2 && $at == "on" ) { afterOn = 1 ; } }
			if ( $at == "in" || $at == "out" ) { other = $at ; if ( phase == 1 ) { during++ ; } if ( phase == 2 && $at == "in" ) { afterIn = 1 ; } }
			if ( phase == 2 && afterIn && ( $at == "said" || $at == "wide" || $at == "narrow" ) ) { after = after " " $at ; }
		}
		print "up at " before ", " during + 0 " while it ran, then" ( afterIn ? " in" : "" ) ( afterOn ? " on" : "" ) after ", at the end " mouse "/" other ;
	}'
}
rigTrace='on=1000h|off=1000l|in=\e[?1049h|out=\e[?1049l|up=STANDIN-UP|end=STANDIN-END|said=ended with status 7|wide=echo foxtrot golf|narrow=hotel india juliet'
rigPtyCase pty-exit exit
rigPty '6\p\aStandin\a\eOB\p\r\p\aSTANDIN-UP\ago\r\p\aended with status 7\a\x18'
rigAssert "a normal end: the screen came up, ended by its own key with status 0, and gave the terminal back as it was" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.modeBack ) $( rigVal pty.errorAfterLeft )" "yes 0 yes yes none"
rigAssert "the child was started from its words as they are, in its folder, with no shell" "$( rigFact argv ) [$( rigFact cwd )]" "[a word][_][-] [$rigTmp/ws rig]"
rigAssert "it had the terminal, in the shell's mode, in its size"    "$( rigFact tty ) $( rigFact cooked ) $( rigFact size )" "yes yes 100x30"
rigAssert "the screen had left its mode before the child came up, wrote nothing while it ran, and was drawn whole after it with its status" "$( rigTraced )" "up at off/out, 0 while it ran, then in on wide said, at the end off/out"
rigAssert "and the list was read again after it"                     "$( [ "$( rigCalled --manager-console-list )" -ge 2 ] && echo yes || echo "no ($( rigCalled --manager-console-list ))" )" "yes"
rigTrace='on=1000h|off=1000l|in=\e[?1049h|out=\e[?1049l|up=STANDIN-UP|end=STANDIN-END|said=ended by signal 15'
rigPtyCase pty-signal signal
rigPty '6\p\aStandin\a\eOB\p\r\p\aended by signal 15\a\x18'
rigAssert "an end by a signal: the screen does not end with its child, and gives the terminal back at its own end" "$( rigVal pty.frame ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.modeBack ) $( rigVal pty.errorAfterLeft )" "yes 0 yes yes none"
rigAssert "it is back after the child, and says which signal ended it" "$( rigTraced )" "up at off/out, 0 while it ran, then in on said, at the end off/out"
rigTrace='on=1000h|off=1000l|in=\e[?1049h|out=\e[?1049l|up=STANDIN-UP|end=STANDIN-END|said=ended with status 0|wide=echo foxtrot golf|narrow=hotel india juliet'
rigPtyCase pty-resize resize
rigPty '6\p\aStandin\a\eOB\p\r\p\aSTANDIN-UP\a\z70x24\pgo\r\p\aended with status 0\a\x18'
rigAssert "a terminal resized while the child ran: the child saw both sizes, and the screen ended as ever" "$( rigFact size ) $( rigFact sizeAtEnd ) $( rigVal pty.rc ) $( rigVal pty.left ) $( rigVal pty.modeBack )" "100x30 70x24 0 yes yes"
rigAssert "the screen is back in the size the terminal has now: its left window breaks as 70 columns break it" "$( rigTraced )" "up at off/out, 0 while it ran, then in on narrow said, at the end off/out"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN CONSOLES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_CONSOLES: OK (%d assertions, offline, stand-in terminal, stand-in dispatcher and a stand-in console on a pseudo-terminal)\n' "$rigPassCount"
