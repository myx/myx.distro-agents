#!/usr/bin/env bash
## Behavioural check on `Launchpad` of the manager screen (sh-lib/manager/AgentsManagerScreen.py), run rather than read.
## The screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py),
## and where it would call the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.stub.sh),
## which notes each start, its arguments word for word and what came on its standard input, and prints the fixture
## kept for that operation: rows in the form `--manager-routine-list` prints, and the three lines
## `--spawn-session` prints. Held: entering `Launchpad` asks `--manager-routine-list --facts-only` once; its first row
## under the row that goes up is `Free prompt`, then comes every routine in the order of the operation, each by its
## selector without `.routine.md`; one that is not startable shows plainer, dimmed, with what the operation says of
## it at the end of its row; the left pane shows the selected routine, its owner, its title, its executors, the kind
## of its session and the name its session takes, and for one that is not startable the reason; it names `Enter
## start` on a routine that can be started and on the free prompt, and nothing on one that cannot; Enter on a
## routine opens the line to type in with the session's name, the selector without its owner and without
## `.routine.md`, and Enter again calls `--spawn-session --routine <selector> --session-name-or-comment
## <name>` once; a name typed over the default is the one passed, as one word; an emptied name passes none; Esc
## starts nothing; Enter on a routine that cannot be started calls nothing and says why; Enter on the free prompt
## takes one line, then a name that may be left empty, and calls `--spawn-session --routine-default` once with
## the line on its standard input and no word of it among its arguments, whatever characters it holds; an empty line
## is refused by the screen and starts nothing; Esc at either step starts nothing; what the operation printed, the
## session id and the members, is shown, and the list is read again and holds the new session; and an error of the
## start is shown, with no new session in the list.
## Offline: no operation of the real tooling is called, no CLI is started, and no session of this machine is read.
## Reconciled for F11.0: `Launch / Spawn` is named `Launchpad`, `Consoles (Tools)` `Consoles`; the spacer under
## `Launchpad` moves each session row of the list one line down, and the spacer under `Free prompt` each routine;
## the left pane has no `keys:` line any more, so the keys of a row are read from the status line (rigKeysNamed);
## every dialog has bigger margins inside its frame (two empty lines under its top, one more under its buttons, three
## blank cells at each side), so its box is four cells wider and two lines taller and what it holds stands where it
## stood.
## Reconciled for F11.5: `Launchpad` is a section of Magic-Team of its own, after Activity (`at magic-team`, two
## steps down into it, with no pending question in the rig), and the new session is among the rows of Active Sessions,
## the third and fourth lines of the list.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
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
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenLaunchCheck )" || exit 1
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
## Five routines, by owner and then by selector: three that can be started, one of them with two executors; one
## whose executors are any member; and a file that fails the routine contract, in a folder whose name its own does
## not begin with. One session runs. Then the list of the sessions as it reads once a start has made a new one.
rigDaily=magic-coordinator.daily.routine.md
rigS1=11111111-0000-4000-8000-000000000001 ; rigNew=99999999-0000-4000-8000-000000000009
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
rigWhy='its_executors,_magic-team,_is_any_member:_the_session_spawner_starts_it_only_with_members_named'
{
	rigRow routine keeper-myx.spec-conformance.routine.md keeper-myx startable keeper-myx - - keeper-myx.spec-conformance.routine_—_the_check -
	rigRow routine "$rigDaily" magic-coordinator startable magic-coordinator coworking - magic-coordinator.daily.routine_—_the_daily_meeting -
	rigRow routine magic-coordinator.retro.routine.md magic-coordinator startable magic-coordinator,_magic-librarian coworking - The_retro -
	rigRow routine magic-team.discuss.routine.md magic-team not-startable magic-team coworking - magic-team.discuss.routine_—_a_discussion "$rigWhy"
	rigRow routine odd.routine.md rig-member broken - - - - the_file_does_not_open_with_a_frontmatter_block
} > "$rigF/rows.--manager-routine-list"
rigOld(){
	rigRow session "$rigS1" - running 2026-10-12_16:57_+0000 - 1 running=1
	rigRow run "$rigS1" "$rigS1" keeper-myx spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig working
}
{ rigOld ; rigRow counters 1 0 1 0 3 0.42 ; } > "$rigF/rows"
{
	rigRow session "$rigNew" daily running 2026-10-13_02:30_+0000 - 2 running=2
	rigRow run "$rigNew" "$rigNew" magic-coordinator spawn-started running running 2026-10-13_02:30_+0000 - rig-host ws-rig working
	rigRow run "$rigNew" 98989898-0000-4000-8000-000000000098 magic-librarian spawn-started running running 2026-10-13_02:30_+0000 - rig-host ws-rig working
	rigOld
	rigRow counters 2 0 3 0 3 0.42
} > "$rigF/after.rows"
{
	printf '%s\n' "spawn-session: added magic-librarian: the rig says so"
	printf '%s\n' "SESSION_ID=$rigNew" "ROUTINE=$rigDaily" "MEMBERS=magic-coordinator magic-librarian"
} > "$rigF/rows.--spawn-session"
## A fresh rig for one case: a copy of the fixtures, no call noted yet.
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size, with the reads of one session taken out of the table; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:magic-team/activity/active-sessions:record none\nwall 2026-10-13 02:30 +0000\nsize 120 40\nat magic-team\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigKeysNamed(){ ## cells name -- the row's own keys as the status line names them, in the words the pane's `keys:` line
	## had before F11.0 removed it; `PANE-KEYS-LINE` where the pane still has a line of its own
	local namedSaid namedWords="" namedPair namedKey namedWord
	if rigVal "$1" | LC_ALL=C grep -q '^keys:' ; then printf 'PANE-KEYS-LINE' ; return 0 ; fi
	namedSaid="$( rigVal "${1}Status" ) "
	for namedPair in ENTER:Start ; do
		namedKey="${namedPair%%:*}" ; namedWord="${namedPair#*:}"
		case "$namedSaid" in *" $namedKey $namedWord "*) namedWords="${namedWords:+$namedWords  }$namedKey $( printf '%s' "$namedWord" | LC_ALL=C tr 'A-Z' 'a-z' )" ;; esac
	done
	[ -z "$namedWords" ] || printf 'keys: %s' "$namedWords"
}
rigPane(){ ## tag, line counted from 1 -- the left pane's part of that line of the screen, without the spaces at its end
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/^┌\(─\)* \(.*\) \(─\)*┐.*$/ \2/' -e 's/^╔\(═\)* \(.*\) \(═\)*╗.*$/ \2/' -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' -e 's/  *$//'
}
rigPaneHolds(){ ## tag, text -- how many lines of the left pane of that screen hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' | LC_ALL=C grep -c -F -- "$2" || :
}
rigLooks(){ ## tag, line counted from 1, the cells from and to counted from 1 -- how those cells are drawn
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -n "${2}p" | LC_ALL=C cut -c"$3-$4"
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigStarts(){ ## how many times the operation that starts a session was started, whatever its arguments
	LC_ALL=C grep -c -- '^--spawn-session' "$MANAGER_SCREEN_RIG/calls" || :
}
rigStartWords(){ ## number -- the arguments of that start of the operation that starts a session, each between brackets
	LC_ALL=C grep -F -- '[--spawn-session]' "$MANAGER_SCREEN_RIG/words" | LC_ALL=C sed -n "${1}p"
}
rigOthers(){ ## how many starts were none of the five operations this screen may call here (the slots of a routine are asked before its form): the list of the team is read while a dialog that offers members is open. The list of the locations, which every start of the screen reads, is not counted.
	LC_ALL=C grep -c -v -e '^--manager-session-list' -e '^--manager-routine-list --facts-only$' -e '^--spawn-session' -e '^--manager-routine-slots ' -e '^--manager-team-member-list$' -e '^--manager-place-list$' "$MANAGER_SCREEN_RIG/calls" || :
}
rigType(){ ## text -- the keys that type it, one a character
	local typeText="$1" typeKeys="" typeChar
	while [ -n "$typeText" ] ; do
		typeChar="${typeText%"${typeText#?}"}" ; typeText="${typeText#?}"
		[ "$typeChar" != " " ] || typeChar=SPACE
		typeKeys="$typeKeys $typeChar"
	done
	printf '%s' "$typeKeys"
}
rigInput(){ ## what the operation that starts a session got on its standard input, in all its starts: `none` where nothing came, `same` where it is exactly the text and a line end, else what came
	local inputFile="$MANAGER_SCREEN_RIG/stdin.--spawn-session"
	if [ ! -e "$inputFile" ] ; then printf none
	elif printf '%s\n' "$1" | cmp -s - "$inputFile" ; then printf same
	else cat "$inputFile" ; fi
}

echo "-- Launchpad lists the free prompt, then every routine --"
rigCase list
rigScript <<'RIGSCRIPT'
## Launchpad is a section of Magic-Team of its own, after Activity: with no pending
## question the rig's rows are `..`, Activity, then Launch -- two steps down
turn
keys DOWN DOWN
turn
get on
keys ENTER
get asked
wait list 30
turn
get in
show u
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
looks k
RIGSCRIPT
rigAssert "until it is entered the routines are not read"            "$( rigVal on.selected ) $( rigCalled '--manager-routine-list --facts-only' )" "launch 1"
rigAssert "entering it asks the fast listing of the routines, once" "$( rigVal asked.path ) $( rigVal asked.reading ) $( rigCalled '--manager-routine-list --facts-only' ) $( rigOthers )" "magic-team/launch list:magic-team/launch 1 0"
rigAssert "the rows under the row that goes up are the five starts of the Launchpad, one for each kind, in the order of the sketch (routine before free prompt)" "[$( rigVal title )] [$( rigVal row1 )][$( rigVal row2 )][$( rigVal row3 )][$( rigVal row4 )][$( rigVal row5 )][$( rigVal row6 )] $( rigVal in.rows )" "[Launchpad] [>..][ Start Coworking Session...][ Start Standalone Session...][ Start Work-Duty Session...][ Start Routine Session...][ Free Prompt...] 11"
rigAssert "then every routine, in the order of the operation, by its selector without .routine.md" "[$( rigVal row8 )][$( rigVal row9 )][$( rigVal row10 )]" "[ keeper-myx.spec-conformance][ magic-coordinator.daily][ magic-coordinator.retro]"
rigAssert "one that cannot be started carries what the operation says of it" "[$( rigVal row11 )][$( rigVal row12 )][$( rigVal row13 )]" "[ magic-team.discuss  not-startable][ odd                        broken][]"
rigAssert "and shows plainer than the ones that can"                 "$( rigLooks k 10 86 86 )$( rigLooks k 11 86 86 )$( rigLooks k 12 86 86 )$( rigLooks k 13 86 86 )$( rigLooks k 14 86 86 )" "...DD"
rigAssert "on the row that goes up the left pane is the level's table, nothing above it" "[$( rigPane u 3 )]" "[  ROUTINE          START         OWNER             TITLE                  SESSION]"

echo "-- the left pane shows the selected routine, and the keys that act on it --"
rigCase pane
rigScript <<'RIGSCRIPT'
## R3: the list is opened at Magic-Team and stepped into Launch; inside it the rows are
## `..`, the free prompt, then every routine -- so one step from the top reaches the free
## prompt and one more reaches the first routine
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN
turn
get free
show f
cells freeKeys 37 1 83
cells freeKeysStatus 39 0 120
## the rows are the operation's order: from the free prompt one step reaches
## spec-conformance, and one more the daily meeting
keys DOWN
turn
keys DOWN
turn
get daily
show d
cells dailyKeys 37 1 83
cells dailyKeysStatus 39 0 120
keys DOWN
turn
show r
keys DOWN
turn
get discuss
show n
cells discussKeys 37 1 83
keys DOWN
turn
get odd
show o
cells oddKeys 37 1 83
RIGSCRIPT
rigAssert "the free prompt says what a prompt to a member starts"      "$( rigVal free.selected ) [$( rigPane f 3 )][$( rigPane f 4 )][$( rigPane f 5 )]" \
	"free [ A prompt to one member, with no routine: only the floor of the member loads, no][ instruction of a session kind.][ Enter opens its dialog: who runs it, the prompt, the name of the session.]"
rigAssert "and the left pane names Enter as its key"                 "[$( rigKeysNamed freeKeys )]" "[keys: ENTER start]"
rigAssert "a routine: its title as its head, then its file, its owner, its executors" "$( rigVal daily.selected ) [$( rigPane d 3 )][$( rigPane d 4 )][$( rigPane d 5 )][$( rigPane d 6 )]" \
	"magic-coordinator/$rigDaily [ magic-coordinator.daily.routine — the daily meeting][  routine    $rigDaily][  owner      magic-coordinator][  executors  magic-coordinator]"
rigAssert "the kind of its session, that it starts here, and the name its session takes" "[$( rigPane d 7 )][$( rigPane d 8 )][$( rigPane d 9 )][$( rigPane d 10 )] [$( rigKeysNamed dailyKeys )]" \
	"[  session    coworking: members working together in one session][  start      startable][  name       daily, unless another is typed][] [keys: ENTER start]"
rigAssert "several executors read with their spaces" "[$( rigPane r 6 )]" "[  executors  magic-coordinator, magic-librarian]"
rigAssert "one that cannot be started says so, and why" "$( rigVal discuss.selected ) [$( rigPane n 8 )][$( rigPane n 9 )][$( rigPane n 10 )]" \
	"magic-team/magic-team.discuss.routine.md [  start      not-startable][  why        its executors, magic-team, is any member: the session spawner starts][             it only with members named]"
rigAssert "and the left pane names no key for it"                    "[$( rigVal discussKeys )]" "[]"
rigAssert "a broken file: what the operation says of it, and no key" "$( rigVal odd.selected ) [$( rigPane o 3 )][$( rigPane o 4 )][$( rigPane o 5 )][$( rigPane o 6 )] [$( rigVal oddKeys )]" \
	"rig-member/odd.routine.md [  routine  odd.routine.md][  owner    rig-member][  start    broken][  why      the file does not open with a frontmatter block] []"

echo "-- Enter twice starts a routine under its own name --"
rigCase start
rigBoxHas(){ printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || : ; } ## tag, text -- how many lines of that drawing of a dialog hold the text
rigScript <<RIGSCRIPT
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN
copy $rigTmp/start/after.rows $rigTmp/start/rows
keys ENTER
wait plan 30
turn
get asked
box d
cells askedLine 38 1 83
turn 3
get waiting
keys ENTER
get started
said startedLine
wait action 30
cells answeredRow 39 0 120
get answered
show a
said answeredLine
wait sessions 30
turn
at @activity active-sessions
turn
get up
cells upRow3 3 85 119
cells upRow4 4 85 119
RIGSCRIPT
rigAssert "Enter on a routine opens its dialog, the keys on what the session is to work on, and in it the name of its session: the selector without its owner and .routine.md" "[$( rigVal asked.dialog )] [$( rigVal asked.dialogTitle )] $( rigBoxHas d '║   daily ' )" "[routine:task|] [Start the routine] 1"
rigAssert "the dialog says what will be started, and as whom"        "$( rigBoxHas d "║   routine   $rigDaily " ) $( rigBoxHas d '║   executors magic-coordinator: it runs as its executors, whoever is ' )" "1 1"
rigAssert "its fields are what the session is to work on and its name, over Start and Cancel" "$( rigBoxHas d '║   Comments/Scope ' ) $( rigBoxHas d '║   Name of the session, or none ' ) $( rigBoxHas d ' »Start« ▅   Cancel  ▅' ) $( rigBoxHas d 'With no name the session shows by its id.' )" "1 1 1 1"
rigAssert "until Enter is pressed again nothing is started"          "[$( rigVal waiting.dialog )] $( rigVal waiting.calls ) [$( rigVal waiting.reading )]" "[routine:task|] 0 []"
## The bottom line is the COMMAND LINE: the keys that act now take it, and what the screen last
## said stands at its right, cut to what is left -- so the notice is checked by its beginning.
rigAssert "Enter again starts it, beside the screen"                 "[$( rigVal started.dialog )] $( rigVal started.reading ) $( [ "$( printf '%s' "$( rigVal started.notice )" | LC_ALL=C grep -c 'start asked of the tool' )" -gt 0 ] && printf 1 || printf 0 )" "[] action:launch:$rigDaily 1"
rigAssert "the operation is called once, with that routine and the name daily" "$( rigStarts ) [$( rigStartWords 1 )]" "1 [[--spawn-session][--routine][$rigDaily][--session-name-or-comment][daily]]"
rigAssert "nothing goes to its standard input, and nothing else is called" "$( rigInput '' ) $( rigOthers )" "none 0"
rigAssert "the bottom line is the command line: it carries actions, never the message first, and and no message of the last operation" \
	"$( [ -n "$( rigVal answeredRow )" ] && printf 1 || printf 0 ):$( [ "$( printf '%s' "$( rigVal answeredRow )" | LC_ALL=C grep -c 'started: session' )" -eq 0 ] && printf 1 || printf 0 )" "1:1"
rigAssert "the left pane shows what the operation printed: the session, its name, the routine, the members" "[$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )][$( rigPane a 6 )][$( rigPane a 7 )]" \
	"[ the start, answered 02:30:00:][ session   $rigNew][ name      daily][ routine   $rigDaily][ members   magic-coordinator, magic-librarian]"
rigAssert "and what it noted, then the routine as before" "[$( rigPane a 8 )][$( rigPane a 9 )][$( rigPane a 10 )]" "[ note      spawn-session: added magic-librarian: the rig says so][][ magic-coordinator.daily.routine — the daily meeting]"
rigAssert "the list is read again, and the new session is among its rows" "$( rigCalled --manager-session-list ) $( rigVal up.path ) [$( rigVal upRow3 )][$( rigVal upRow4 )]" "2 magic-team/activity/active-sessions [ daily                   running ►][ keeper-myx 11111111     running ►]"

echo "-- a name typed over the default is the one passed --"
rigCase name
rigScript <<RIGSCRIPT
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN
keys ENTER
wait plan 30
turn
keys TAB$( rigType ' of Monday' )
get typed
keys ENTER
wait action 30
keys ENTER
wait plan 30
turn
keys TAB BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE$( rigType 'stand up' ) ENTER
wait action 30
keys ENTER
wait plan 30
turn
keys TAB BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE
get emptied
keys ENTER
get none
wait action 30
keys ENTER
wait plan 30
turn
keys TAB BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE SPACE SPACE ENTER
wait action 30
RIGSCRIPT
rigAssert "the name is typed on after the default"                   "[$( rigVal typed.dialog )]" "[routine:name|daily of Monday]"
rigAssert "and passed whole, as one word of the command"             "[$( rigStartWords 1 )]" "[[--spawn-session][--routine][$rigDaily][--session-name-or-comment][daily of Monday]]"
rigAssert "the default deleted and another name typed: that one is passed" "[$( rigStartWords 2 )]" "[[--spawn-session][--routine][$rigDaily][--session-name-or-comment][stand up]]"
rigAssert "the name emptied: the routine is started with no name"    "[$( rigVal emptied.dialog )] [$( rigVal none.notice )] [$( rigStartWords 3 )]" "[routine:name|] [start asked of the tooling: $rigDaily, with no name] [[--spawn-session][--routine][$rigDaily]]"
rigAssert "spaces alone are no name"                                 "[$( rigStartWords 4 )] $( rigStarts )" "[[--spawn-session][--routine][$rigDaily]] 4"

echo "-- Esc starts nothing; a routine that cannot be started says why --"
rigCase refuse
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN
keys ENTER
wait plan 30
turn
keys x ESC
turn
get esc
said escLine
keys DOWN DOWN ENTER
get discuss
box discussBox
keys ENTER
get closed
keys RIGHT
get right
keys ESC
mouse click 100 12
mouse click 100 12
get click
keys ESC
keys ALT-s ENTER
get item
keys ESC
keys DOWN ENTER
get odd
keys ESC
keys UP UP UP RIGHT
get can
keys UP UP UP TAB ENTER
get left
turn 3
get end
RIGSCRIPT
rigAssert "Esc closes the line: nothing is started, and the bottom line is empty" "[$( rigVal esc.dialog )] [$( rigVal escLine )] $( rigVal esc.selected )" "[] [] magic-coordinator/$rigDaily"
rigAssert "Enter on a routine that cannot be started opens the information box: the routine, who executes it, and why" "$( rigVal discuss.selected ) [$( rigVal discuss.dialog )] [$( rigVal discuss.dialogTitle )] [$( rigVal discuss.dialogHolds )]" \
	"magic-team/magic-team.discuss.routine.md [information:ok|] [The routine is not started] [magic-team.discuss cannot be started from here. / routine: magic-team.discuss.routine.md / owner: magic-team / executors: magic-team / start: not-startable / why: its executors, magic-team, is any member: the session spawner starts it only with members named]"
rigAssert "the box sets its facts out, the reason broken to the box with its underscores as spaces, over one button" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^discussBox|' | LC_ALL=C grep -c -F -e '║   routine   magic-team.discuss.routine.md ' -e '║   executors magic-team ' -e '║   why       its executors, magic-team, is any member: the session ' -e '║             starts it only with members named ' -e ' »OK« ▅' )" "5"
rigAssert "the box says it and the status line does not; Enter closes it" "[$( rigVal discuss.notice )] [$( rigVal closed.dialog )] [$( rigVal closed.notice )]" "[] [] []"
rigAssert "Right on it opens no box and dives nowhere: it pages down, as in every list" "$( rigVal right.path ) [$( rigVal right.dialog )] $( [ "$( rigVal right.index )" -gt "$( rigVal closed.index )" ] && echo down )" "magic-team/launch [] down"
rigAssert "a click on it while it is selected, the click that opens, too" "$( rigVal click.selected ) [$( rigVal click.dialog )] [$( rigVal click.dialogTitle )]" "magic-team/magic-team.discuss.routine.md [information:ok|] [The routine is not started]"
rigAssert "its greyed menu item is another thing: tried, it opens no box and says one line of the status line" "[$( rigVal item.dialog )] [$( rigVal item.notice )]" \
	"[] [Start the routine: magic-team.discuss is not started from here: its executors, magic-team, is any member: the session spawner starts it only with members named]"
rigAssert "a broken file is not started either"                      "[$( rigVal odd.dialog )] [$( rigVal odd.dialogHolds )]" "[information:ok|] [odd cannot be started from here. / routine: odd.routine.md / owner: rig-member / executors: none are named / start: broken / why: the file does not open with a frontmatter block]"
rigAssert "Right on a routine that can be started pages down, dives nowhere and starts nothing" "$( rigVal can.selected ) $( rigVal can.path ) [$( rigVal can.dialog )]" "rig-member/odd.routine.md magic-team/launch []"
rigAssert "with the focus on the left pane Enter starts nothing"     "$( rigVal left.focus ) $( rigVal left.selected ) [$( rigVal left.dialog )]" "view magic-coordinator/$rigDaily []"
rigAssert "the operation that starts a session was never called"     "$( rigStarts ) $( rigOthers ) $( rigVal end.calls )" "0 0 0"

echo "-- an error of the start is shown --"
rigCase fail
echo fail > "$MANAGER_SCREEN_RIG/mode.--spawn-session"
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN
keys ENTER
wait plan 30
turn
keys ENTER
wait action 30
get failed
show f
keys ENTER
wait sessions 30
turn
at @activity active-sessions
turn
get up
RIGSCRIPT
rigAssert "what the operation wrote stands in a box, whole" "[$( rigVal failed.dialogTitle )] [$( rigVal failed.dialogHolds )]" "[The start failed] [operation: --spawn-session --routine $rigDaily --session-name-or-comment daily / rig-tools: a line that is no error / rig-tools: ⛔ ERROR: the rig said fail]"
rigAssert "and in the left pane, which says that the start failed"   "[$( rigPane f 3 )][$( rigPane f 4 )][$( rigPane f 5 )]" "[ the start failed, answered 02:30:00:][ rig-tools: ⛔ ERROR: the rig said fail][]"
rigAssert "the list is read again, and holds no new session"         "$( rigCalled --manager-session-list ) $( rigVal up.path ) $( rigVal up.rows )" "2 magic-team/activity/active-sessions 2"

echo "-- a routine that any member executes: its members are chosen in a dialog, and ONE session is started with them --"
rigMembersCase(){ ## name -- a fresh rig in which the list says of the discussion that it needs members, and the team has three members that can be started, one that is never started and one whose workspace is not here
	rigCase "$1"
	{
		LC_ALL=C grep -v 'magic-team.discuss' "$rigF/rows.--manager-routine-list"
		rigRow routine magic-team.discuss.routine.md magic-team not-startable magic-team coworking - magic-team.discuss.routine_—_a_discussion "$rigWhy" members
	} > "$MANAGER_SCREEN_RIG/rows.--manager-routine-list"
	{
		rigRow member human-owner :myx: - - - human ws-rig here reference-only no-process 👤
		rigRow member magic-coordinator 🐭 Magic Vane dispatchr magic ws-rig here active no-process 🤖
		rigRow member keeper-myx 📐 Sage Bourne cronjob keeper ws-rig here active running 🔏
		rigRow member keeper-gone - - - - - - not-present - no-process
		rigRow member magic-tester 🧪 Tess Quill prober magic ws-rig here active no-process 🤖
	} > "$MANAGER_SCREEN_RIG/rows.--manager-team-member-list"
}
rigDiscuss=magic-team.discuss.routine.md
rigMembersCase members
rigScript <<RIGSCRIPT
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN
turn
get on
show o
cells onRow 13 85 119
cells onKeys 37 1 83
cells onKeysStatus 39 0 120
cells onStatus 39 0 120
keys ENTER
wait plan 30
turn
get opened
wait list 30
turn
get filled
box m
cells mStatus 39 0 120
keys TAB TAB ENTER
get none
keys SPACE DOWN DOWN SPACE TAB$( rigType 'the plan for Monday' )
get typed
keys ENTER
get started
wait action 30
get answered
RIGSCRIPT
rigAssert "a routine that is started only with members named says so at the end of its row" "$( rigVal on.selected ) [$( rigVal onRow )]" "magic-team/$rigDiscuss [>magic-team.discuss        members]"
rigAssert "the left pane says that its members are asked for, and it and the status line name the key" "$( rigPaneHolds o '  start      members: its members are asked for' ) [$( rigKeysNamed onKeys )] [$( rigVal onStatus )]" "1 [keys: ENTER start] [ ENTER Start  BSP Up  a Active  / Filter  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"
rigAssert "Enter opens the dialog of its members, and starts nothing" "$( rigVal opened.dialog ) [$( rigVal opened.dialogTitle )] $( rigVal opened.calls )" "members:members| [Start the routine with members] 0"
rigAssert "the members are read by the operation that lists the team, once" "$( rigCalled --manager-team-member-list )" "1"
rigAssert "the dialog names the routine, and has a box for each member that can be started from here, and for no other" "$( rigBoxHas m '║   routine   magic-team.discuss.routine.md ' ) $( rigBoxHas m '║   [ ] magic-coordinator ' ) $( rigBoxHas m '║   [ ] keeper-myx ' ) $( rigBoxHas m '║   [ ] magic-tester ' ) $( rigBoxHas m 'human-owner' ) $( rigBoxHas m 'keeper-gone' )" "1 1 1 1 0 0"
rigAssert "under them the field for what the session is to work on, and OK and Cancel" "$( rigBoxHas m '║   Comments/Scope ' ) $( rigBoxHas m ' OK  ▅  »Cancel« ▅' ) [$( rigVal mStatus )]" "1 1 [ Space Toggle  UP/DN Move  ENTER Cancel  TAB Next  ESC Cancel]"
rigAssert "OK with no member checked is refused inside the dialog, and starts nothing" "$( rigVal none.dialog ) [$( rigVal none.dialogSays )] $( rigVal none.calls )" "members:members| [no member is checked: check one at least, with Space] 0"
rigAssert "Space checks a member, and Tab goes on to the field"      "$( rigVal typed.dialog )" "members:task|the plan for Monday"
rigAssert "OK starts it: the dialog closes, and the status line says with whom" "[$( rigVal started.dialog )] [$( rigVal started.notice )]" "[] [start asked of the tooling: $rigDiscuss, with magic-coordinator, magic-tester]"
rigAssert "ONE session is started, with all the members checked as the words after the routine" "$( rigStarts ) [$( rigStartWords 1 )]" "1 [[--spawn-session][--routine][$rigDiscuss][magic-coordinator][magic-tester]]"
rigAssert "what the session is to work on goes on the standard input of the operation, and is no word of it" "$( rigInput 'the plan for Monday' )" "same"
rigAssert "what the operation printed is shown, as of every start"   "[$( rigVal answered.notice )]" "[started: session $rigNew, members magic-coordinator, magic-librarian]"
rigMembersCase membersEsc
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN ENTER
wait plan 30
wait list 30
keys SPACE ESC
get esc
turn 3
get quiet
keys ENTER
wait plan 30
turn
get again
keys DOWN SPACE ENTER
wait action 30
get one
RIGSCRIPT
rigAssert "Esc closes the dialog and starts nothing, whatever was checked" "[$( rigVal esc.dialog )] $( rigVal quiet.calls ) $( rigVal again.dialog )" "[] 0 members:members|"
rigAssert "one member checked and nothing typed: that member alone, and nothing on the standard input" "$( rigStarts ) [$( rigStartWords 1 )] $( rigInput '' )" "1 [[--spawn-session][--routine][$rigDiscuss][keeper-myx]] none"

echo "-- each start of the Launchpad opens its own form --"
rigMembersCase pads
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN ENTER
wait list 30
get cow
box c
keys ESC
keys DOWN ENTER
get sta
box s
keys ESC
keys DOWN ENTER
get duty
box d
keys ESC
keys DOWN ENTER
get rou
box r
keys DOWN
get roulist
keys ESC
keys DOWN ENTER
get free
box f
keys ESC
turn 3
get end
RIGSCRIPT
rigAssert "Start Coworking Session: members to check, the goal, the name; the keys are on the goal" "[$( rigVal cow.dialog )] [$( rigVal cow.dialogTitle )] $( rigBoxHas c '║   [ ] magic-coordinator ' ) $( rigBoxHas c '║   Session Goal ' ) $( rigBoxHas c '║   Name of the session, or none ' )" "[pad-coworking:goal|] [Start Coworking Session] 1 1 1"
rigAssert "Start Standalone Session: one member in a list, the goal, the name" "[$( rigVal sta.dialog )] [$( rigVal sta.dialogTitle )] $( rigBoxHas s '║   Member ' ) $( rigBoxHas s '║   Session Goal ' )" "[pad-standalone:goal|] [Start Standalone Session] 1 1"
rigAssert "Start Work-Duty Session: one member, comments or scope that may stay empty" "[$( rigVal duty.dialog )] [$( rigVal duty.dialogTitle )] $( rigBoxHas d '║   Comments/Scope ' )" "[pad-work-duty:goal|] [Start Work-Duty Session] 1"
rigAssert "Start Routine Session: the routines to choose from, one chosen, and Next in place of Start" "[$( rigVal rou.dialog )] [$( rigVal rou.dialogTitle )] $( rigBoxHas r '║   Routine ' ) $( rigBoxHas r 'choose one' ) $( rigBoxHas r 'magic-coordinator.daily' ) $( rigBoxHas r 'Next' ) $( rigBoxHas r 'Prompt' )" "[pad-routine:routine|] [Start Routine Session] 1 1 1 1 0"
rigAssert "Free Prompt: one member for now, the prompt, the name" "[$( rigVal free.dialog )] [$( rigVal free.dialogTitle )] $( rigBoxHas f '║   Prompt ' ) $( rigBoxHas f '║   Member ' )" "[pad-free:prompt|] [Free Prompt] 1 1"
rigAssert "opening a form starts nothing" "$( rigStarts ) $( LC_ALL=C grep -c -- '^--manager-spawn-member' "$MANAGER_SCREEN_RIG/calls" || : )" "0 0"

echo "-- a coworking start: the first member is asked for, the others after --also, the goal after --goal --"
rigMembersCase padCow
rigScript <<RIGSCRIPT
keys DOWN DOWN ENTER
wait list 30
keys DOWN ENTER
wait list 30
keys BACKTAB SPACE DOWN DOWN SPACE TAB$( rigType 'the plan for Monday' ) TAB$( rigType 'monday' )
get typed
keys ENTER
get started
wait action 30
RIGSCRIPT
rigAssert "the dialog holds the goal and the name" "[$( rigVal typed.dialog )]" "[pad-coworking:name|monday]"
rigAssert "the operation is called once: the first member checked, the kind, the others after --also, the goal, the name" "$( LC_ALL=C grep -c -F -- '[--manager-spawn-member]' "$MANAGER_SCREEN_RIG/words" || : ) [$( LC_ALL=C grep -F -- '[--manager-spawn-member]' "$MANAGER_SCREEN_RIG/words" )]" "1 [[--manager-spawn-member][magic-coordinator][--session-name-or-comment][monday][--kind][coworking][--also][magic-tester][--goal][the plan for Monday]]"
rigAssert "the start is asked beside the screen, and the status line says so" "[$( rigVal started.dialog )] $( [ "$( printf '%s' "$( rigVal started.notice )" | LC_ALL=C grep -c 'start asked of the tool' )" -gt 0 ] && printf 1 || printf 0 )" "[] 1"

echo "-- a coworking start with no member checked, and no goal, starts nothing --"
rigMembersCase padCowNone
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN ENTER
wait list 30
keys TAB TAB SPACE
get none
box n
RIGSCRIPT
rigAssert "the form refuses inside itself, in one line, and nothing is called" "[$( rigVal none.dialog )] [$( rigVal none.dialogSays )] $( LC_ALL=C grep -c -- '^--manager-spawn-member' "$MANAGER_SCREEN_RIG/calls" || : )" "[pad-coworking:members|] [no member is checked: check one at least, with Space] 0"

echo "-- a routine session: the routine is chosen on the first page, the routine's own start is the next --"
rigMembersCase padRoutine
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN ENTER
wait list 30
keys TAB SPACE
turn
get none
keys DOWN DOWN DOWN DOWN ENTER
turn 3
get next
box nx
RIGSCRIPT
rigAssert "Next with no routine chosen is refused inside the form, and the form stays" "[$( rigVal none.dialog )] [$( rigVal none.dialogSays )]" "[pad-routine:routine|] [nothing is started: no routine is chosen]"
rigAssert "with a routine chosen the routine's own start follows the form (it asks the tooling for the slots), and nothing is started yet" "[$( rigVal next.dialog )] [$( rigVal next.dialogTitle )] $( rigStarts ) $( LC_ALL=C grep -c -- '^--manager-spawn-member' "$MANAGER_SCREEN_RIG/calls" || : )" "[routine-slots-wait:cancel|] [Start the routine] 0 0"

echo "-- standalone, work-duty and free: one member, the kind, the goal or the prompt --"
rigPadWords(){ ## the arguments of the call of the operation that starts a member, each between brackets
	LC_ALL=C grep -F -- '[--manager-spawn-member]' "$MANAGER_SCREEN_RIG/words" | LC_ALL=C sed -n "1p"
}
rigPadStart(){ ## case, steps down to the row of the kind, what is typed (none: nothing) -- one start of that kind in a fresh rig
	rigMembersCase "$1"
	rigScript <<RIGSCRIPT
keys DOWN DOWN ENTER
wait list 30
keys $2 ENTER
wait list 30
keys$( [ "$3" = none ] || rigType "$3" ) TAB ENTER
wait action 30
RIGSCRIPT
}
rigPadStart padStandalone "DOWN DOWN" 'tidy the index'
rigAssert "standalone: the first member of the list, --kind standalone, the goal as --goal" "[$( rigPadWords )]" "[[--manager-spawn-member][magic-coordinator][--kind][standalone][--goal][tidy the index]]"
rigPadStart padDutyEmpty "DOWN DOWN DOWN" none
rigAssert "work-duty with nothing typed: no --goal at all" "[$( rigPadWords )]" "[[--manager-spawn-member][magic-coordinator][--kind][work-duty]]"
rigPadStart padDuty "DOWN DOWN DOWN" 'review the week'
rigAssert "work-duty with comments: they go as --goal" "[$( rigPadWords )]" "[[--manager-spawn-member][magic-coordinator][--kind][work-duty][--goal][review the week]]"
rigPadStart padFree "DOWN DOWN DOWN DOWN DOWN" 'look at the index'
rigAssert "free: --kind free and no --goal; the prompt goes on the standard input, whole" "[$( rigPadWords )] $( printf '%s\n' 'look at the index' | cmp -s - "$MANAGER_SCREEN_RIG/stdin.--manager-spawn-member" && echo same )" "[[--manager-spawn-member][magic-coordinator][--kind][free]] same"

echo "-- a second work-duty of a member: the tooling refuses it, and the screen shows the refusal and starts nothing else --"
## one duty session a member is the tooling's rule (--manager-spawn-member checks the member's duty record); the form draws the refusal and does not decide it
rigMembersCase padDutyRuns
echo fail > "$MANAGER_SCREEN_RIG/mode.--manager-spawn-member"
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN ENTER
wait list 30
keys TAB ENTER
wait action 30
get failed
show f
RIGSCRIPT
rigAssert "the refusal of the operation stands in a box, whole, with the operation that was asked" "[$( rigVal failed.dialogTitle )] $( rigBoxHas f 'rig said fail' ) $( rigBoxHas f 'work-duty' )" "[The start failed] 2 1"
rigAssert "the operation was asked once, and nothing was joined or started instead" "$( LC_ALL=C grep -c -- '^--manager-spawn-member' "$MANAGER_SCREEN_RIG/calls" || : ) $( rigStarts ) $( LC_ALL=C grep -c -- 'join-session' "$MANAGER_SCREEN_RIG/calls" || : )" "1 0 0"

echo "-- a free prompt with no prompt starts nothing --"
rigMembersCase padFreeEmpty
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN ENTER
wait list 30
keys TAB TAB SPACE
get empty
RIGSCRIPT
rigAssert "the form refuses inside itself and nothing is called" "[$( rigVal empty.dialog )] [$( rigVal empty.dialogSays )] $( LC_ALL=C grep -c -- '^--manager-spawn-member' "$MANAGER_SCREEN_RIG/calls" || : )" "[pad-free:prompt|] [nothing is started: the prompt is empty] 0"

echo "-- a routine whose executors ask which member: a required select for each, none chosen for the user, even with one candidate --"
rigSlotsCase(){ ## name -- a fresh rig whose list holds one routine that asks `keeper-?` and `partner-?`, and the slots the tooling gives for it
	rigCase "$1"
	rigRow routine magic-team.gap.routine.md magic-team not-startable "keeper-?,_partner-?" coworking - magic-team.gap.routine_—_a_gap "its_executors_asks_which_members" members > "$MANAGER_SCREEN_RIG/rows.--manager-routine-list"
	{
		rigRow slot executors "keeper-?" choose keeper-a keeper-b
		rigRow slot executors "partner-?" choose partner-c
		rigRow slot participants "magic-*" all magic-x magic-y
		rigRow slot participants "magic-?" choose magic-x magic-y
	} > "$MANAGER_SCREEN_RIG/rows.--manager-routine-slots magic-team.gap.routine.md"
}
rigSlotsCase slots
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN
turn
keys ENTER
wait plan 30
turn
get form
box f
keys TAB TAB TAB TAB TAB SPACE
turn
get none
keys UP UP UP UP DOWN TAB TAB TAB TAB TAB SPACE
turn
get one
RIGSCRIPT
rigAssert "Enter reads the slots of the routine from the tooling, once, before any form opens" "$( rigCalled '--manager-routine-slots magic-team.gap.routine.md' )" "1"
rigAssert "the form has a select for each entry that asks which member, and the read-only members of an entry that takes all" "[$( rigVal form.dialog )] $( rigBoxHas f 'keeper-?: choose one' ) $( rigBoxHas f 'partner-?: choose one' ) $( rigBoxHas f 'magic-x, magic-y' ) $( rigBoxHas f 'choose one' )" "[routine-slots:choose0|] 1 1 1 6"
rigAssert "a participants entry that asks which member is a required select too, the other participants stay read-only, and nothing says it is left to the session" "$( rigBoxHas f 'participants magic-?: choose one' ) $( rigBoxHas f 'chosen in the session' ) $( rigBoxHas f 'participants magic-* (all)' )" "1 0 1"
rigAssert "page two of a routine session has the Comments/Scope box (sketch 14.5), and no prompt" "$( rigBoxHas f '║   Comments/Scope ' ) $( rigBoxHas f 'What the session is to work on' )" "1 0"
rigAssert "Start with nothing chosen starts nothing: the form says which entry asks, and the operation is not called" "[$( rigVal none.dialogSays )] $( rigStarts )" "[nothing is started: executors keeper-? asks which member, and none is chosen] 0"
rigAssert "one chosen is not enough: the entry that has a single candidate is chosen too" "[$( rigVal one.dialogSays )] $( rigStarts )" "[nothing is started: executors partner-? asks which member, and none is chosen] 0"
rigSlotsCase slotsrun
rigScript <<RIGSCRIPT
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN
turn
keys ENTER
wait plan 30
turn
keys DOWN TAB DOWN TAB DOWN TAB$( rigType 'the gap' ) TAB TAB ENTER
wait action 30
turn
get started
RIGSCRIPT
rigAssert "with a member chosen in each select Start calls the operation once: the routine, its name, then the members chosen in the order of the selects" "$( rigStarts ) [$( rigStartWords 1 )]" "1 [[--spawn-session][--routine][magic-team.gap.routine.md][--session-name-or-comment][gap][--participants][magic-*,magic-x][keeper-a][partner-c]]"
rigAssert "and what was typed goes on its standard input" "$( rigInput 'the gap' )" "same"
rigSlotsCase slotspart
rigScript <<'RIGSCRIPT'
keys DOWN DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN
turn
keys ENTER
wait plan 30
turn
keys DOWN TAB DOWN TAB TAB TAB TAB SPACE
turn
get part
RIGSCRIPT
rigAssert "executors chosen and the participants select left alone: Start is refused, naming it, and the operation is not called" "[$( rigVal part.dialogSays )] $( rigStarts )" "[nothing is started: participants magic-? asks which member, and none is chosen] 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN LAUNCH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_LAUNCH: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
