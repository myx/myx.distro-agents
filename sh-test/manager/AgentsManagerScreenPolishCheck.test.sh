#!/usr/bin/env bash
## Behavioural check on the small console polish of F11.0 (the refactorings epic), the parts whose effect is named:
## `Launch / Spawn` is renamed `Launch (Start)`, `Consoles (Tools)` is renamed `Consoles`, the obsolete pane line
## `keys: k kill  c control` is gone (the status line already shows those keys), and a big window showing command
## output has bigger margins: at least one more line top and bottom and two more characters each side than before.
## Run rather than read: the screen's own code (sh-lib/AgentsManagerScreen.py) draws through the stand-in terminal of
## the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls the stand-in
## script (check-fixtures/manager-screen.tools.stub.sh), which prints the case's fixture.
## Held:
##   1. the root list and the Go menu name `Launch (Start)` and `Consoles`, and neither old name
##   2. the pane of a session whose control thread is gone has no `keys:` line, and the status line still names k and c
##   5. spacers between groups of the root list: a spacer is one blank line between two root rows, and the cursor and
##      the number keys skip it (which groups get one is not settled, and is not asserted): at least one stands there;
##      every step of the cursor down the roots selects a row, never a spacer; the number keys select the same roots
##      as before
##   7. the raw log, `g`: the run's session-*.log, whose writer's lines carry their ISO time, shows the time of each
##      line (no line of a session log but a body line lacks it today, so the case is that g shows them)
##   5b. a spacer stands in any folder between its commands (FIXED_ROWS) and its children, as in Sessions after Launch;
##      MDLT_CONSOLE_SPACERS=disable, the console user's setting of .local, turns every spacer off
##   6. summary mode (`b`) of the left window: a run in Wait shows `<what> for <duration>` on its `waits on` line, in
##      the screen's duration form (its wait taken from when its last milestone, the Wait, was reached)
##   4. the table colour rule, in every style and each of its colour schemes: the other rows of a table differ
##      from a row only in their background, never in their text (its colour, its brightness, its look with no
##      colours); a scheme that gives no alternate background changes nothing of the row
##   3. the box of a failed operation's output: at least two blank lines inside its frame above the text and one
##      below its buttons, and at least three blank columns each side of the text -- one line and two characters more
##      than the box before (one above, none below, one at the left)
## NOTE for the builder: AgentsManagerScreenControlCheck, AgentsManagerScreenChromeCheck and
## AgentsManagerScreenConsolesCheck assert the old names and the old keys line, and are reconciled in the same feature.
## Red before F11.0: the old names, the keys line and the old margins (every case but the status line fails).
## Offline: the only thing the screen calls here is the stand-in for the dispatcher.
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
## This check names the operation that starts a control thread, and only its stand-in is ever called: it ends the
## control threads of its rig all the same, as every check that names that operation does.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the fixture that ends the control threads of a rig is missing: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenPolishCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
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
## One session that runs, its control thread gone, and the start of that thread failing with a line of output.
rigS1=11111111-0000-4000-8000-000000000001
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 1 running=1 running 2026-10-12_16:58_+0000 gone
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting
	rigRow counters 1 0 1 0 1 0.42
} > "$rigF/rows"
rigRow control "$rigS1" not-started - 'its open records are runs of another host, which cannot be watched from here' > "$rigF/rows.--manager-session-control-start --session-id $rigS1"
rigCase(){ ## name -- a fresh rig: a copy of the fixtures, no call noted yet
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls" ; : > "$MANAGER_SCREEN_RIG/words" ; : > "$MANAGER_SCREEN_RIG/ended"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:sessions:record none\ntable feed:sessions:record none\ntable view:sessions/*:record none\ntable feed:sessions/*:record none\nwall 2026-10-13 02:30 +0000\nsize 120 40\nroot sessions\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigScreenHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}

echo "-- 1. the new names, and neither old one --"
rigCase names
rigScript <<'RIGSCRIPT'
turn
wait sessions 30
show rootShown
keys m
turn
show menu
keys ESC
keys ENTER
wait sessions 30
turn
show sessionsShown
RIGSCRIPT
[ "$( rigScreenHolds rootShown 'Team Members' )" -ge 1 ] 2> /dev/null || rigRefuse "the root list was never drawn, so nothing below would be measured: $( printf '%s\n' "$rigOut" | LC_ALL=C grep -m2 -e DRIVER-FAILED -e Traceback -e Error )"
rigAssert "the sessions level names Launch (Start), and not Launch / Spawn" "$( rigScreenHolds sessionsShown 'Launch (Start)' | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "named" : "unnamed" }' ):$( rigScreenHolds sessionsShown 'Launch / Spawn' )" "named:0"
rigAssert "the root list names Consoles, and not Consoles (Tools)" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^rootShown|' | LC_ALL=C grep -c -E ' Consoles  ' ):$( rigScreenHolds rootShown 'Consoles (Tools)' )" "1:0"
rigAssert "the menu names neither old name"                   "$( rigScreenHolds menu 'Launch / Spawn' ):$( rigScreenHolds menu 'Consoles (Tools)' )" "0:0"

echo "-- 2. the pane of a session has no keys line; the status line names the keys --"
rigCase keys
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
turn
get s1
cells keys1 37 1 83
cells status 39 0 120
RIGSCRIPT
rigAssert "control: the session is selected"                 "$( rigVal s1.selected )" "$rigS1"
rigAssert "the pane's line under its facts is no keys: line" "[$( rigVal keys1 | LC_ALL=C sed -n 's/^\(keys:\).*/\1/p' )]" "[]"
rigAssert "control: the status line names k and c"           "$( rigVal status | LC_ALL=C grep -c -E ' k [A-Z][a-z]+ .* c [A-Z][a-z]+' )" 1

echo "-- 3. the box of a failed operation's output: one line and two characters more margin --"
rigCase margins
echo fail > "$MANAGER_SCREEN_RIG/mode.--manager-session-control-start"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
keys c
wait action 30
get failed
box fbox
RIGSCRIPT
[ -n "$( rigVal failed.dialogTitle )" ] || rigRefuse "the failed start opened no box, so no margin would be measured: $( printf '%s\n' "$rigOut" | LC_ALL=C grep -m2 -e DRIVER-FAILED -e Traceback )"
## The margins inside the box, its frame of ╔═╗ ║ ╚═╝ read by characters, not bytes:
## `<blank lines above the text> <blank lines below the buttons> <least blank columns left> <least blank columns right>`.
rigMargins(){
	printf '%s\n' "$rigOut" | LC_ALL=C grep '^fbox|' | "$rigPython" -I -c 'import sys
rows = [ line.rstrip("\n")[ len("fbox|") : ] for line in sys.stdin.buffer.read().decode("utf-8").splitlines() ]
inside = []
for row in rows[ 1 : ] :
	if row.startswith("╚") : break
	left = row.find("║") ; right = row.find("║", left + 1)
	inside.append( row[ left + 1 : right ] )
filled = [ i for i, row in enumerate(inside) if row.strip(" ") ]
text = [ inside[ i ] for i in filled if "▅" not in inside[ i ] and "»" not in inside[ i ] ]
print( "%d %d %d %d" % ( filled[0], len(inside) - 1 - filled[-1], min( len(r) - len(r.lstrip(" ")) for r in text ), min( len(r) - len(r.rstrip(" ")) for r in text ) ) )'
}
rigMarginsGot="$( rigMargins 2> /dev/null )"
## The box before F11.0, measured 2026-10-18: one blank line above the text, none below its buttons, one blank column
## at its left. One line and two columns more than that each.
rigAssert "at least two blank lines above the text, and one below the buttons" "$( printf '%s' "$rigMarginsGot" | LC_ALL=C awk '{ print ( $1 >= 2 && $2 >= 1 ) ? "roomy" : "tight " $1 " " $2 }' )" roomy
rigAssert "at least three blank columns at each side of the text" "$( printf '%s' "$rigMarginsGot" | LC_ALL=C awk '{ print ( $3 >= 3 && $4 >= 3 ) ? "roomy" : "tight " $3 " " $4 }' )" roomy

echo "-- 5. spacers between groups of the root list --"
rigCase spacers
rigScript <<'RIGSCRIPT'
turn
wait sessions 30
show rootList
get r0
keys DOWN
get r1
keys DOWN
get r2
keys DOWN
get r3
keys DOWN
get r4
keys DOWN
get r5
keys DOWN
get r6
keys DOWN
get r7
keys DOWN
get r8
keys DOWN
get r9
keys DOWN
get r10
keys DOWN
get r11
keys DOWN
get r12
keys 3
get n3
keys 6
get n6
keys 2
wait sessions 30
turn
get n2
show sessionsShown
RIGSCRIPT
## The rows of a list as drawn, in its window's columns, as one word each, `-` for a blank one between two filled ones:
## the first words of each filled row, joined by |.
rigListRows(){ ## tag
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | "$rigPython" -I -c 'import sys
tag = sys.argv[1]
rows = [ line.rstrip("\n")[ len(tag) + 1 : ].rstrip("|") for line in sys.stdin.buffer.read().decode("utf-8").splitlines() ]
part = [ row[ 85 : 119 ].strip(" │║►>") for row in rows[ 2 : -2 ] ]
filled = [ i for i, text in enumerate(part) if text ]
words = []
for i in range( filled[0], filled[-1] + 1 ) if filled else [] :
	words.append( " ".join( part[ i ].split()[ : 2 ] ) if part[ i ] else "-" )
print( "|".join( words ) )' "$1" 2> /dev/null
}
rigRootRows="$( rigListRows rootList )"
rigSpaceAfter(){ ## row start, row start -- `spaced` where a spacer stands between the two rows, else what stands there
	printf '%s\n' "$rigRootRows" | "$rigPython" -I -c 'import sys
rows = sys.stdin.read().strip().split("|")
above = [ i for i, row in enumerate(rows) if row.startswith(sys.argv[1]) ]
below = [ i for i, row in enumerate(rows) if row.startswith(sys.argv[2]) ]
if not above or not below : print("no-such-rows")
else : print("spaced" if below[0] == above[0] + 2 and rows[ above[0] + 1 ] == "-" else "|".join( rows[ above[0] : below[0] + 1 ] ))' "$1" "$2"
}
## No team data is configured in this rig, so Team Data is not shown: the first spacer goes after Team Members.
rigAssert "control: Team Data is not shown, no team data being configured" "$( printf '%s\n' "$rigRootRows" | LC_ALL=C tr '|' '\n' | LC_ALL=C grep -c '^Team Data' )" 0
rigAssert "a spacer between Team Members and Locations"        "$( rigSpaceAfter 'Team Members' 'Locations' )" spaced
rigAssert "a spacer between Consoles and Settings"             "$( rigSpaceAfter 'Consoles' 'Settings' )" spaced
rigAssert "a spacer between Configuration and Manuals"         "$( rigSpaceAfter 'Configuration' 'Manuals' )" spaced
rigAssert "and no other spacer at the root"                    "$( printf '%s\n' "$rigRootRows" | LC_ALL=C tr '|' '\n' | LC_ALL=C grep -c -x -- '-' )" 3
## In any folder a spacer stands between its commands (FIXED_ROWS) and its children: in Sessions, after Launch.
rigAssert "in Sessions, a spacer between Launch and the sessions" "$( rigListRows sessionsShown | "$rigPython" -I -c 'import sys
rows = sys.stdin.read().strip().split("|")
at = [ i for i, row in enumerate(rows) if row.startswith("Launch") ]
print("spaced" if at and len(rows) > at[0] + 2 and rows[ at[0] + 1 ] == "-" and rows[ at[0] + 2 ] != "-" else "|".join(rows))' )" spaced
rigAssert "and no other spacer there"                          "$( rigListRows sessionsShown | LC_ALL=C tr '|' '\n' | LC_ALL=C grep -c -x -- '-' )" 1
rigAssert "every step of the cursor selects a row, never a spacer" "$( for rigStep in 0 1 2 3 4 5 6 7 8 9 10 11 12 ; do [ -n "$( rigVal "r$rigStep.selected" )" ] || printf 'empty-at-%s ' "$rigStep" ; done )" ""
rigAssert "the number keys go to the same roots as before: 3 Pending Questions, 6 Consoles" "$( rigVal n3.path ) $( rigVal n6.path )" "pending consoles"
## MDLT_CONSOLE_SPACERS, the console user's own setting of .local beside MDLT_CONSOLE_HISTORY: `disable` turns every
## spacer off. Given here as the environment of the screen's start, as a console user's settings reach it.
rigCase nospacers
rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:sessions:record none\ntable feed:sessions:record none\ntable view:sessions/*:record none\ntable feed:sessions/*:record none\nwall 2026-10-13 02:30 +0000\nsize 120 40\nroot sessions\n' "$rigTools" ; printf 'turn\nwait sessions 30\nshow rootList\nkeys 2\nwait sessions 30\nturn\nshow sessionsShown\n' ; } | MDLT_CONSOLE_SPACERS=disable "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
rigAssert "with MDLT_CONSOLE_SPACERS=disable, no spacer at the root nor in Sessions" "$( rigListRows rootList | LC_ALL=C tr '|' '\n' | LC_ALL=C grep -c -x -- '-' ):$( rigListRows sessionsShown | LC_ALL=C tr '|' '\n' | LC_ALL=C grep -c -x -- '-' )" "0:0"
rigAssert "control: the root list is drawn all the same"      "$( rigListRows rootList | LC_ALL=C tr '|' '\n' | LC_ALL=C grep -c '^Settings' )" 1

echo "-- 6. summary mode: a run in Wait shows what it waits on, and for how long --"
rigCase summary
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 1 running=1 running 2026-10-12_16:58_+0000 alive
	rigRow dispatch "$rigS1" record magic-coordinator magic-coordinator.daily.routine.md dispatch-20261012T165700Z-daily-1 C0RIG:1791000000.000100 C0TRK:1791000000.000200 'The daily of Monday.'
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting
	rigRow store "$rigS1" store rig-model 1 0 0 1 - - 2026-10-13T02:18:00Z Wait ask:Q12 - - -
} > "$MANAGER_SCREEN_RIG/rows.--manager-session-read --session-id $rigS1"
cp "$MANAGER_SCREEN_RIG/rows.--manager-session-read --session-id $rigS1" "$MANAGER_SCREEN_RIG/rows.--manager-session-read --session-id $rigS1 --run"
rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable feed:sessions:record none\ntable feed:sessions/*:record none\nwall 2026-10-13 02:30 +0000\nsize 120 40\nroot sessions\n' "$rigTools" ; printf 'keys ENTER\nwait sessions 30\nkeys DOWN DOWN\nkeys ENTER\nwait list 30\nkeys DOWN\nwait view 30\nturn\nget sumview\nshow sum\n' ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
rigWaitsLine="$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^sum|' | LC_ALL=C grep -F 'waits on' | head -1 | LC_ALL=C sed -e 's/^sum|//' -e 's/  */ /g' )"
rigAssert "control: the left window is in summary mode, b"   "$( rigVal sumview.viewMode )" summary
rigAssert "control: its waits on line says what it waits on"  "$( printf '%s' "$rigWaitsLine" | LC_ALL=C grep -c -F 'waits on ask:Q12' )" 1
rigAssert "and for how long"                                   "$( printf '%s' "$rigWaitsLine" | LC_ALL=C grep -c -F 'waits on ask:Q12 for 12m' )" 1

echo "-- 7. the raw log, g, shows the time of each of its lines --"
rigCase rawlog
cp "$rigTmp/summary/rows.--manager-session-read --session-id $rigS1"* "$MANAGER_SCREEN_RIG/" 2> /dev/null
## The run's session log, as the transcript read gives it: a line of the writer, its body, and another line.
{
	rigRow source "$rigS1" magic-coordinator log /rig/audit/2026-10/session-20261012T165700Z-magic-coordinator-11111111.log
	rigRow log "$rigS1" magic-coordinator '2026-10-12T17:05:00Z TOOL Wait mode=continue -> ok'
	rigRow log "$rigS1" magic-coordinator '> WAIT-RESULT: TIMEOUT'
	rigRow log "$rigS1" magic-coordinator '2026-10-12T17:09:30Z TOOL SendMessage to=session-current -> ok'
} > "$MANAGER_SCREEN_RIG/rows.--manager-session-transcript-read --session-id $rigS1 --run --log"
rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize 120 40\nroot sessions\n' "$rigTools" ; printf 'keys ENTER\nwait sessions 30\nkeys DOWN DOWN\nkeys ENTER\nwait list 30\nkeys DOWN\nwait view 30\nkeys g\nwait feed 30\nturn\nget raw\nshow rawShown\n' ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
rigRawLine(){ ## fixed text -- the line of the raw log as g shows it that holds the text, its blanks squeezed
	printf '%s\n' "$rigOut" | LC_ALL=C grep '^rawShown|' | LC_ALL=C grep -F -- "$1" | head -1 | LC_ALL=C sed -e 's/^rawShown|//' -e 's/  */ /g'
}
rigAssert "control: g shows the raw log, its lines there"     "$( rigVal raw.rawLog ):$( [ -n "$( rigRawLine 'TOOL Wait' )" ] && [ -n "$( rigRawLine 'TOOL SendMessage' )" ] && printf shown || printf missing )" "yes:shown"
rigAssert "g shows the time of each line, by the line"       "$( rigRawLine 'TOOL Wait' | LC_ALL=C grep -c '17:05:00' ):$( rigRawLine 'TOOL SendMessage' | LC_ALL=C grep -c '17:09:30' )" "1:1"

echo "-- 4. the table colour rule: alternate rows differ only in their background --"
## Read from the screen's declaration of its looks, by the screen module itself, in each style and scheme it offers:
## a row of a table (ROW) against every other row (ROW_ALT), as the screen resolves the two in that scheme.
rigRowRule="$( "$rigPython" -I -B -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
screen = importlib.util.module_from_spec(spec) ; spec.loader.exec_module(screen)
broken = []
for style, entry in screen.STYLES:
	for scheme, changes in entry["schemes"]:
		screen.setStyle("%s-%s" % (style, scheme))
		looks = screen.STYLE_LOOKS.get(screen.STYLE.get("looks", ""), {})
		def seen(number):
			base = screen.LOOKS[number]
			own = looks.get(number)
			colours = tuple(own) if own else tuple(base[2:5])
			return base[1], colours
		rowMono, rowColours = seen(screen.ROW)
		altMono, altColours = seen(screen.ROW_ALT)
		text = lambda colours: tuple(colours[i] for i in (0, 2, 3, 5) if i < len(colours))
		if rowMono != altMono or text(rowColours) != text(altColours):
			broken.append("%s-%s" % (style, scheme))
print(" ".join(broken))' "$rigScreen" 2>&1 )"
rigAssert "no style and scheme gives the other rows another text than a row" "[$rigRowRule]" "[]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN POLISH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_POLISH: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
