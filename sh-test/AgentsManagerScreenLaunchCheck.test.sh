#!/usr/bin/env bash
## Behavioural check on `Launch / Spawn` of the manager screen (sh-lib/AgentsManagerScreen.py), run rather than read.
## The screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.test.py),
## and where it would call the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.test.sh),
## which notes each start, its arguments word for word and what came on its standard input, and prints the fixture
## kept for that operation: rows in the form `--manager-routine-list` prints, and the three lines
## `--magic-spawn-session` prints. Held: entering `Launch / Spawn` asks `--manager-routine-list` once; its first row
## under the row that goes up is `Free prompt`, then comes every routine in the order of the operation, each by its
## selector without `.routine.md`; one that is not startable shows plainer, dimmed, with what the operation says of
## it at the end of its row; the left pane shows the selected routine, its owner, its title, its executors, the kind
## of its session and the name its session takes, and for one that is not startable the reason; it names `Enter
## start` on a routine that can be started and on the free prompt, and nothing on one that cannot; Enter on a
## routine opens the line to type in with the session's name, the selector without its owner and without
## `.routine.md`, and Enter again calls `--magic-spawn-session --routine <selector> --session-name-or-comment
## <name>` once; a name typed over the default is the one passed, as one word; an emptied name passes none; Esc
## starts nothing; Enter on a routine that cannot be started calls nothing and says why; Enter on the free prompt
## takes one line, then a name that may be left empty, and calls `--magic-spawn-session --routine-default` once with
## the line on its standard input and no word of it among its arguments, whatever characters it holds; an empty line
## is refused by the screen and starts nothing; Esc at either step starts nothing; what the operation printed, the
## session id and the members, is shown, and the list is read again and holds the new session; and an error of the
## start is shown, with no new session in the list.
## Offline: no operation of the real tooling is called, no CLI is started, and no session of this machine is read.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.test.py"
rigTools="$rigFixtures/manager-screen.tools.test.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.test.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.test.sh"
rigTmp="$( mktemp -d -t AgentsManagerScreenLaunchCheck )" || exit 1
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
	printf '%s\n' "magic-spawn-session: added magic-librarian: the rig says so"
	printf '%s\n' "SESSION_ID=$rigNew" "ROUTINE=$rigDaily" "MEMBERS=magic-coordinator magic-librarian"
} > "$rigF/rows.--magic-spawn-session"
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
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:sessions:record none\ntable feed:sessions:record none\nwall 2026-10-13 02:30 +0000\nsize 120 40\nroot sessions\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
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
	LC_ALL=C grep -c -- '^--magic-spawn-session' "$MANAGER_SCREEN_RIG/calls" || :
}
rigStartWords(){ ## number -- the arguments of that start of the operation that starts a session, each between brackets
	LC_ALL=C grep -F -- '[--magic-spawn-session]' "$MANAGER_SCREEN_RIG/words" | LC_ALL=C sed -n "${1}p"
}
rigOthers(){ ## how many starts were none of the four operations this screen may call here: the list of the team is read while a dialog that offers members is open. The list of the locations, which every start of the screen reads, is not counted.
	LC_ALL=C grep -c -v -e '^--manager-session-list' -e '^--manager-routine-list$' -e '^--magic-spawn-session' -e '^--manager-team-member-list$' -e '^--manager-place-list$' "$MANAGER_SCREEN_RIG/calls" || :
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
	local inputFile="$MANAGER_SCREEN_RIG/stdin.--magic-spawn-session"
	if [ ! -e "$inputFile" ] ; then printf none
	elif printf '%s\n' "$1" | cmp -s - "$inputFile" ; then printf same
	else cat "$inputFile" ; fi
}

echo "-- Launch / Spawn lists the free prompt, then every routine --"
rigCase list
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN
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
looks k
RIGSCRIPT
rigAssert "until it is entered the routines are not read"            "$( rigVal on.selected ) $( rigCalled --manager-routine-list )" "launch 1"
rigAssert "entering it asks the operation that lists the routines, once" "$( rigVal asked.path ) $( rigVal asked.reading ) $( rigCalled --manager-routine-list ) $( rigOthers )" "sessions/launch list:sessions/launch 1 0"
rigAssert "the first row under the row that goes up is the free prompt" "[$( rigVal title )] [$( rigVal row1 )][$( rigVal row2 )] $( rigVal in.rows )" "[Launch / Spawn] [>..][ Free prompt] 7"
rigAssert "then every routine, in the order of the operation, by its selector without .routine.md" "[$( rigVal row3 )][$( rigVal row4 )][$( rigVal row5 )]" "[ keeper-myx.spec-conformance][ magic-coordinator.daily][ magic-coordinator.retro]"
rigAssert "one that cannot be started carries what the operation says of it" "[$( rigVal row6 )][$( rigVal row7 )][$( rigVal row8 )]" "[ magic-team.discuss  not-startable][ odd                        broken][]"
rigAssert "and shows plainer than the ones that can"                 "$( rigLooks k 5 86 86 )$( rigLooks k 6 86 86 )$( rigLooks k 7 86 86 )$( rigLooks k 8 86 86 )$( rigLooks k 9 86 86 )" "...DD"
rigAssert "on the row that goes up the left pane says what the level holds: how many are started here, how many with members named, how many are not" "[$( rigPane u 3 )]" "[ 5 routines: 3 can be started here, 0 with members named, 2 cannot.]"

echo "-- the left pane shows the selected routine, and the keys that act on it --"
rigCase pane
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN
turn
get free
show f
cells freeKeys 37 1 83
keys DOWN DOWN
turn
get daily
show d
cells dailyKeys 37 1 83
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
rigAssert "the free prompt says what a prompt typed there starts"      "$( rigVal free.selected ) [$( rigPane f 3 )][$( rigPane f 4 )][$( rigPane f 5 )]" \
	"free [ A prompt typed here starts a new coworking session, opened by the coordinator,][ with that prompt as its brief.][ Enter opens its dialog: who runs it, the prompt, the name of the session. An empty]"
rigAssert "and the left pane names Enter as its key"                 "[$( rigVal freeKeys )]" "[keys: ENTER start]"
rigAssert "a routine: its file, its owner, its title, its executors" "$( rigVal daily.selected ) [$( rigPane d 3 )][$( rigPane d 4 )][$( rigPane d 5 )][$( rigPane d 6 )]" \
	"magic-coordinator/$rigDaily [ routine   $rigDaily][ owner     magic-coordinator][ title     magic-coordinator.daily.routine — the daily meeting][ executors magic-coordinator]"
rigAssert "the kind of its session, that Enter starts it, and the name its session takes" "[$( rigPane d 7 )][$( rigPane d 8 )][$( rigPane d 9 )][$( rigPane d 10 )] [$( rigVal dailyKeys )]" \
	"[ session   coworking: the spawner adds magic-coordinator to it][ start     Enter starts it, as its executors, whoever is at the console][ name      daily, the name its session takes unless another is typed][] [keys: ENTER start]"
rigAssert "several executors read with their spaces"                 "[$( rigPane r 6 )]" "[ executors magic-coordinator, magic-librarian]"
rigAssert "one that cannot be started says so, and why"              "$( rigVal discuss.selected ) [$( rigPane n 8 )][$( rigPane n 9 )][$( rigPane n 10 )]" \
	"magic-team/magic-team.discuss.routine.md [ start     not-startable: Enter does not start it][ why       its executors, magic-team, is any member: the session spawner starts it][           only with members named]"
rigAssert "and the left pane names no key for it"                    "[$( rigVal discussKeys )]" "[]"
rigAssert "a broken file: what the operation says of it, and no key" "$( rigVal odd.selected ) [$( rigPane o 3 )][$( rigPane o 4 )][$( rigPane o 5 )][$( rigPane o 6 )] [$( rigVal oddKeys )]" \
	"rig-member/odd.routine.md [ routine   odd.routine.md][ owner     rig-member][ start     broken: Enter does not start it][ why       the file does not open with a frontmatter block] []"

echo "-- Enter twice starts a routine under its own name --"
rigCase start
rigBoxHas(){ printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || : ; } ## tag, text -- how many lines of that drawing of a dialog hold the text
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
copy $rigTmp/start/after.rows $rigTmp/start/rows
keys ENTER
get asked
box d
cells askedLine 38 1 83
turn 3
get waiting
keys ENTER
get started
said startedLine
wait action 30
get answered
show a
said answeredLine
wait sessions 30
turn
keys BACKSPACE
get up
cells upRow3 4 85 119
cells upRow4 5 85 119
RIGSCRIPT
rigAssert "Enter on a routine opens its dialog, the keys on what the session is to work on, and in it the name of its session: the selector without its owner and .routine.md" "[$( rigVal asked.dialog )] [$( rigVal asked.dialogTitle )] $( rigBoxHas d '║ daily ' )" "[routine:task|] [Start the routine] 1"
rigAssert "the dialog says what will be started, and as whom"        "$( rigBoxHas d "║ routine   $rigDaily " ) $( rigBoxHas d '║ executors magic-coordinator: it runs as its executors, whoever is ' )" "1 1"
rigAssert "its fields are what the session is to work on and its name, over Start and Cancel" "$( rigBoxHas d '║ What the session is to work on ' ) $( rigBoxHas d '║ Name of the session, or none ' ) $( rigBoxHas d ' »Start« ▄   Cancel  ▄' ) $( rigBoxHas d 'With no name the session shows by its id.' )" "1 1 1 1"
rigAssert "until Enter is pressed again nothing is started"          "[$( rigVal waiting.dialog )] $( rigVal waiting.calls ) [$( rigVal waiting.reading )]" "[routine:task|] 0 []"
rigAssert "Enter again starts it, beside the screen"                 "[$( rigVal started.dialog )] $( rigVal started.reading ) [$( rigVal startedLine )]" "[] action:launch:$rigDaily [start asked of the tooling: $rigDaily, named daily]"
rigAssert "the operation is called once, with that routine and the name daily" "$( rigStarts ) [$( rigStartWords 1 )]" "1 [[--magic-spawn-session][--routine][$rigDaily][--session-name-or-comment][daily]]"
rigAssert "nothing goes to its standard input, and nothing else is called" "$( rigInput '' ) $( rigOthers )" "none 0"
rigAssert "the bottom line shows the id of the new session, and of its members what fits" "[$( rigVal answeredLine )] [$( rigVal answered.notice )]" "[started: session $rigNew, members magic-coordina…] [started: session $rigNew, members magic-coordinator, magic-librarian]"
rigAssert "the left pane shows what the operation printed: the session, its name, the routine, the members" "[$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )][$( rigPane a 6 )][$( rigPane a 7 )]" \
	"[ the start, answered 02:30:00:][ session   $rigNew][ name      daily][ routine   $rigDaily][ members   magic-coordinator, magic-librarian]"
rigAssert "and what it noted, then the routine as before"            "[$( rigPane a 8 )][$( rigPane a 9 )][$( rigPane a 10 )]" "[ note      magic-spawn-session: added magic-librarian: the rig says so][][ routine   $rigDaily]"
rigAssert "the list is read again, and the new session is among its rows" "$( rigCalled --manager-session-list ) $( rigVal up.path ) [$( rigVal upRow3 )][$( rigVal upRow4 )]" "2 sessions [ daily                   running ►][ keeper-myx 11111111     running ►]"

echo "-- a name typed over the default is the one passed --"
rigCase name
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
keys ENTER TAB$( rigType ' of Monday' )
get typed
keys ENTER
wait action 30
keys ENTER TAB BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE$( rigType 'stand up' ) ENTER
wait action 30
keys ENTER TAB BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE
get emptied
keys ENTER
get none
wait action 30
keys ENTER TAB BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE SPACE SPACE ENTER
wait action 30
RIGSCRIPT
rigAssert "the name is typed on after the default"                   "[$( rigVal typed.dialog )]" "[routine:name|daily of Monday]"
rigAssert "and passed whole, as one word of the command"             "[$( rigStartWords 1 )]" "[[--magic-spawn-session][--routine][$rigDaily][--session-name-or-comment][daily of Monday]]"
rigAssert "the default deleted and another name typed: that one is passed" "[$( rigStartWords 2 )]" "[[--magic-spawn-session][--routine][$rigDaily][--session-name-or-comment][stand up]]"
rigAssert "the name emptied: the routine is started with no name"    "[$( rigVal emptied.dialog )] [$( rigVal none.notice )] [$( rigStartWords 3 )]" "[routine:name|] [start asked of the tooling: $rigDaily, with no name] [[--magic-spawn-session][--routine][$rigDaily]]"
rigAssert "spaces alone are no name"                                 "[$( rigStartWords 4 )] $( rigStarts )" "[[--magic-spawn-session][--routine][$rigDaily]] 4"

echo "-- Esc starts nothing; a routine that cannot be started says why --"
rigCase refuse
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
keys ENTER x ESC
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
mouse click 100 7
mouse click 100 7
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
rigAssert "the box sets its facts out, the reason broken to the box with its underscores as spaces, over one button" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^discussBox|' | LC_ALL=C grep -c -F -e '║ routine   magic-team.discuss.routine.md ' -e '║ executors magic-team ' -e '║ why       its executors, magic-team, is any member: the session ' -e '║           starts it only with members named ' -e ' »OK« ▄' )" "5"
rigAssert "the box says it and the status line does not; Enter closes it" "[$( rigVal discuss.notice )] [$( rigVal closed.dialog )] [$( rigVal closed.notice )]" "[] [] []"
rigAssert "Right on it opens no box and dives nowhere: it pages down, as in every list" "$( rigVal right.path ) [$( rigVal right.dialog )] $( [ "$( rigVal right.index )" -gt "$( rigVal closed.index )" ] && echo down )" "sessions/launch [] down"
rigAssert "a click on it while it is selected, the click that opens, too" "$( rigVal click.selected ) [$( rigVal click.dialog )] [$( rigVal click.dialogTitle )]" "magic-team/magic-team.discuss.routine.md [information:ok|] [The routine is not started]"
rigAssert "its greyed menu item is another thing: tried, it opens no box and says one line of the status line" "[$( rigVal item.dialog )] [$( rigVal item.notice )]" \
	"[] [Start the routine: magic-team.discuss is not started from here: its executors, magic-team, is any member: the session spawner starts it only with members named]"
rigAssert "a broken file is not started either"                      "[$( rigVal odd.dialog )] [$( rigVal odd.dialogHolds )]" "[information:ok|] [odd cannot be started from here. / routine: odd.routine.md / owner: rig-member / executors: none are named / start: broken / why: the file does not open with a frontmatter block]"
rigAssert "Right on a routine that can be started pages down, dives nowhere and starts nothing" "$( rigVal can.selected ) $( rigVal can.path ) [$( rigVal can.dialog )]" "rig-member/odd.routine.md sessions/launch []"
rigAssert "with the focus on the left pane Enter starts nothing"     "$( rigVal left.focus ) $( rigVal left.selected ) [$( rigVal left.dialog )]" "view magic-coordinator/$rigDaily []"
rigAssert "the operation that starts a session was never called"     "$( rigStarts ) $( rigOthers ) $( rigVal end.calls )" "0 0 0"

echo "-- the free prompt: an empty line starts nothing --"
rigCase empty
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN
keys ENTER
get asked
box d
keys TAB ENTER
get empty
box e
keys SPACE SPACE TAB ENTER
get spaces
keys ESC ENTER x ESC
get esc
turn 3
get end
RIGSCRIPT
rigAssert "Enter on the free prompt opens its dialog, the keys on the prompt: who runs it, the prompt, the name" "[$( rigVal asked.dialog )] [$( rigVal asked.dialogTitle )] $( rigBoxHas d '║ Who runs it ' ) $( rigBoxHas d '║ > magic-coordinator: a new coworking session, by the default routine ' ) $( rigBoxHas d '║ Prompt ' ) $( rigBoxHas d '║ Name of the session, or none ' ) $( rigBoxHas d ' »Start« ▄   Cancel  ▄' )" "[prompt:prompt|] [Free prompt] 1 1 1 1 1"

rigAssert "Start with no prompt starts nothing: the dialog says so in a line of its own, and the keys are back on the prompt" "[$( rigVal empty.dialog )] [$( rigVal empty.dialogSays )] $( rigBoxHas e '║ nothing is started: the prompt is empty ' )" "[prompt:prompt|] [nothing is started: the prompt is empty] 1"
rigAssert "spaces alone are no prompt, and Esc starts nothing"       "[$( rigVal spaces.dialog )] [$( rigVal spaces.dialogSays )] [$( rigVal esc.dialog )] [$( rigVal esc.notice )]" "[prompt:prompt|  ] [nothing is started: the prompt is empty] [] []"

echo "-- a required input: while the prompt is empty nothing presses Start, by no way, and nothing is to be undone --"
rigCase required
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN
keys ENTER
wait list 30
keys TAB
turn
box off roles
cells offStatus 39 0 120
keys BACKTAB
keys ENTER h i
get typed
keys BACKSPACE BACKSPACE BACKSPACE
keys TAB TAB SPACE
get bySpace
keys TAB TAB ENTER
get byEnter
mouse click 52 27
get byClick
keys BACKTAB DOWN TAB TAB ENTER
get member
keys SPACE ENTER SPACE
keys TAB TAB ENTER
get blank
keys x TAB
turn
box on roles
cells onStatus 39 0 120
keys ESC
turn 3
get end
RIGSCRIPT
rigAssert "while the prompt is empty the button that starts is greyed, and Enter in a field of one line names no button to press" "$( rigBoxHas off 'gxxxxxxxxxZgbbbbbbbbbbZ' ) [$( rigVal offStatus )]" "1 [ TAB Next  ESC Cancel]"
rigAssert "Enter in the empty prompt is a new line, never the button: what is typed after it is in the prompt, the dialog is open, nothing was called" "[$( rigVal typed.dialog )] [$( rigVal typed.dialogSays )] $( rigVal typed.calls )" "[prompt:prompt|\\nhi] [] 0"
rigAssert "Tab to the button and Space presses nothing: one line in the dialog says that the prompt is empty, and the keys are back in the prompt" "[$( rigVal bySpace.dialog )] [$( rigVal bySpace.dialogSays )] $( rigVal bySpace.calls )" "[prompt:prompt|] [nothing is started: the prompt is empty] 0"
rigAssert "neither does Enter on the button, nor a click on it" "[$( rigVal byEnter.dialog )] $( rigVal byEnter.calls ) [$( rigVal byClick.dialog )] [$( rigVal byClick.dialogSays )] $( rigVal byClick.calls )" "[prompt:prompt|] 0 [prompt:prompt|] [nothing is started: the prompt is empty] 0"
rigAssert "nor with a member picked in the list, nor with blanks and a new line alone in the prompt, which stay as they were typed" "[$( rigVal member.dialog )] $( rigVal member.calls ) [$( rigVal blank.dialog )] $( rigVal blank.calls )" "[prompt:prompt|] 0 [prompt:prompt| \\n ] 0"
rigAssert "with a prompt typed the button is drawn as a button again, and Enter names it" "$( rigBoxHas on 'gbbbbbbbbbZgbbbbbbbbbbZ' ) [$( rigVal onStatus )]" "1 [ ENTER Start  TAB Next  ESC Cancel]"
rigAssert "nothing was started at any time: no operation that starts was called" "[$( rigVal end.dialog )] $( rigVal end.calls ) $( rigStarts ) $( LC_ALL=C grep -c -- '^--manager-spawn-member' "$MANAGER_SCREEN_RIG/calls" || : )" "[] 0 0 0"
rigAssert "the operation that starts a session was never called"     "$( rigStarts ) $( rigOthers ) $( rigVal end.calls )" "0 0 0"

echo "-- the free prompt starts a coworking session with the line as its brief --"
rigCase prompt
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN
keys ENTER$( rigType 'Magic, start retro please' )
get typed
keys TAB
get name
box n
turn 3
wait list 30
get waiting
keys ENTER
get started
wait action 30
get answered
show a
said answeredLine
RIGSCRIPT
rigAssert "the line is typed"                                        "[$( rigVal typed.dialog )]" "[prompt:prompt|Magic, start retro please]"
rigAssert "Tab goes on to the name of the session, the prompt standing above it" "[$( rigVal name.dialog )] $( rigBoxHas n '║ Magic, start retro please ' )" "[prompt:name|] 1"

rigAssert "until the name is entered nothing is started"             "[$( rigVal waiting.dialog )] $( rigVal waiting.calls ) [$( rigVal waiting.reading )]" "[prompt:name|] 0 []"
rigAssert "Enter with no name starts it"                             "$( rigVal started.reading ) [$( rigVal started.notice )]" "action:prompt:free [start asked of the tooling: a free prompt, with no name]"
rigAssert "the operation is called once, with --routine-default and no word of the line" "$( rigStarts ) [$( rigStartWords 1 )] $( rigCalled '--magic-spawn-session --routine-default' )" "1 [[--magic-spawn-session][--routine-default]] 1"
rigAssert "the line is on its standard input, whole, with a line end" "$( rigInput 'Magic, start retro please' )" same
rigAssert "what the operation printed is shown"                      "[$( rigVal answeredLine )] [$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )]" \
	"[started: session $rigNew, members magic-coordina…] [ the start, answered 02:30:00:][ session   $rigNew][ name      none: it shows by its id]"

echo "-- the free prompt with a name, with odd characters, and Esc at the name --"
rigCase named
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN
keys ENTER$( rigType 'Magic, start retro please' ) TAB$( rigType 'retro by hand' ) ENTER
wait action 30
RIGSCRIPT
rigAssert "a name given after the line is passed, as one word, and the line stays on standard input" "[$( rigStartWords 1 )] $( rigInput 'Magic, start retro please' )" "[[--magic-spawn-session][--routine-default][--session-name-or-comment][retro by hand]] same"
rigOdd='-n "it'"'"'s" 50% a\b $(id) ; rm -rf x `y` --routine z'
rigCase odd
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN
keys ENTER$( rigType "$rigOdd" ) TAB ENTER
wait action 30
RIGSCRIPT
rigAssert "a line with quotes, a percent sign, a backslash, a dollar and a first word that starts with a dash arrives unchanged" "$( rigInput "$rigOdd" )" same
rigAssert "and none of it is a word of the command"                  "$( rigStarts ) [$( rigStartWords 1 )]" "1 [[--magic-spawn-session][--routine-default]]"
rigCase back
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN
keys ENTER$( rigType 'Magic, start retro please' ) TAB x ESC
turn 3
get esc
RIGSCRIPT
rigAssert "Esc at the name starts nothing"                           "[$( rigVal esc.dialog )] [$( rigVal esc.notice )] $( rigStarts ) $( rigVal esc.calls )" "[] [] 0 0"

echo "-- an error of the start is shown --"
rigCase fail
echo fail > "$MANAGER_SCREEN_RIG/mode.--magic-spawn-session"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
keys ENTER ENTER
wait action 30
get failed
show f
keys ENTER
wait sessions 30
turn
keys BACKSPACE
get up
RIGSCRIPT
rigAssert "what the operation wrote stands in a box, whole" "[$( rigVal failed.dialogTitle )] [$( rigVal failed.dialogHolds )]" "[The start failed] [operation: --magic-spawn-session --routine $rigDaily --session-name-or-comment daily / rig-tools: a line that is no error / rig-tools: ⛔ ERROR: the rig said fail]"
rigAssert "and in the left pane, which says that the start failed"   "[$( rigPane f 3 )][$( rigPane f 4 )][$( rigPane f 5 )]" "[ the start failed, answered 02:30:00:][ rig-tools: ⛔ ERROR: the rig said fail][]"
rigAssert "the list is read again, and holds no new session"         "$( rigCalled --manager-session-list ) $( rigVal up.path ) $( rigVal up.rows )" "2 sessions 3"

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
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN
turn
get on
show o
cells onRow 8 85 119
cells onKeys 37 1 83
cells onStatus 39 0 120
keys ENTER
get opened
wait list 30
turn
get filled
box m
cells mStatus 39 0 120
keys ENTER
get none
keys SPACE DOWN DOWN SPACE TAB$( rigType 'the plan for Monday' )
get typed
keys ENTER
get started
wait action 30
get answered
RIGSCRIPT
rigAssert "a routine that is started only with members named says so at the end of its row" "$( rigVal on.selected ) [$( rigVal onRow )]" "magic-team/$rigDiscuss [>magic-team.discuss        members]"
rigAssert "the left pane says that Enter asks for its members, and it and the status line name the key" "$( rigPaneHolds o ' start     Enter asks for the members to start it with, in one session' ) [$( rigVal onKeys )] [$( rigVal onStatus )]" "1 [keys: ENTER start] [ ENTER Start  BSP Up  a Active  u Read  m Menu  ^X Exit  TAB Window  ? Help]"
rigAssert "Enter opens the dialog of its members, and starts nothing" "$( rigVal opened.dialog ) [$( rigVal opened.dialogTitle )] $( rigVal opened.calls )" "members:members| [Start the routine with members] 0"
rigAssert "the members are read by the operation that lists the team, once" "$( rigCalled --manager-team-member-list )" "1"
rigAssert "the dialog names the routine, and has a box for each member that can be started from here, and for no other" "$( rigBoxHas m '║ routine   magic-team.discuss.routine.md ' ) $( rigBoxHas m '║ [ ] magic-coordinator ' ) $( rigBoxHas m '║ [ ] keeper-myx ' ) $( rigBoxHas m '║ [ ] magic-tester ' ) $( rigBoxHas m 'human-owner' ) $( rigBoxHas m 'keeper-gone' )" "1 1 1 1 0 0"
rigAssert "under them the field for what the session is to work on, and OK and Cancel" "$( rigBoxHas m '║ What the session is to work on ' ) $( rigBoxHas m ' »OK« ▄   Cancel  ▄' ) [$( rigVal mStatus )]" "1 1 [ Space Toggle  UP/DN Move  TAB Next  ESC Cancel]"
rigAssert "OK with no member checked is refused inside the dialog, and starts nothing" "$( rigVal none.dialog ) [$( rigVal none.dialogSays )] $( rigVal none.calls )" "members:members| [no member is checked: check one at least, with Space] 0"
rigAssert "Space checks a member, and Tab goes on to the field"      "$( rigVal typed.dialog )" "members:task|the plan for Monday"
rigAssert "OK starts it: the dialog closes, and the status line says with whom" "[$( rigVal started.dialog )] [$( rigVal started.notice )]" "[] [start asked of the tooling: $rigDiscuss, with magic-coordinator, magic-tester]"
rigAssert "ONE session is started, with all the members checked as the words after the routine" "$( rigStarts ) [$( rigStartWords 1 )]" "1 [[--magic-spawn-session][--routine][$rigDiscuss][magic-coordinator][magic-tester]]"
rigAssert "what the session is to work on goes on the standard input of the operation, and is no word of it" "$( rigInput 'the plan for Monday' )" "same"
rigAssert "what the operation printed is shown, as of every start"   "[$( rigVal answered.notice )]" "[started: session $rigNew, members magic-coordinator, magic-librarian]"
rigMembersCase membersEsc
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN ENTER
wait list 30
keys SPACE ESC
get esc
turn 3
get quiet
keys ENTER
get again
keys DOWN SPACE ENTER
wait action 30
get one
RIGSCRIPT
rigAssert "Esc closes the dialog and starts nothing, whatever was checked" "[$( rigVal esc.dialog )] $( rigVal quiet.calls ) $( rigVal again.dialog )" "[] 0 members:members|"
rigAssert "one member checked and nothing typed: that member alone, and nothing on the standard input" "$( rigStarts ) [$( rigStartWords 1 )] $( rigInput '' )" "1 [[--magic-spawn-session][--routine][$rigDiscuss][keeper-myx]] none"

echo "-- the free prompt run by a member picked from its list --"
rigMembersCase promptWho
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN
keys ENTER
wait list 30
turn
box w
keys BACKTAB DOWN DOWN
get who
keys TAB$( rigType 'look at the index' ) TAB$( rigType 'index' ) ENTER
get started
wait action 30
RIGSCRIPT
rigAssert "the list of who runs a free prompt: the default first, then each member that can be started from here" "$( rigBoxHas w '║ > magic-coordinator: a new coworking session, by the default routine ' ) $( rigBoxHas w '║   magic-coordinator ' ) $( rigBoxHas w '║   keeper-myx ' ) $( rigBoxHas w '║   magic-tester ' ) $( rigBoxHas w 'human-owner' )" "1 1 1 1 0"
rigAssert "a member picked there is started alone with the prompt, by the operation that starts a member, and no session is spawned by the default routine" "$( rigVal who.dialog ) [$( rigVal started.notice )] [$( LC_ALL=C grep -F -- '[--manager-spawn-member]' "$MANAGER_SCREEN_RIG/words" )] $( rigStarts )" "prompt:who|keeper-myx [start asked of the tooling: the member keeper-myx, named index] [[--manager-spawn-member][keeper-myx][--session-name-or-comment][index]] 0"
rigAssert "with the prompt on its standard input"                    "$( printf '%s\n' 'look at the index' | cmp -s - "$MANAGER_SCREEN_RIG/stdin.--manager-spawn-member" && echo same )" "same"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN LAUNCH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_LAUNCH: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
