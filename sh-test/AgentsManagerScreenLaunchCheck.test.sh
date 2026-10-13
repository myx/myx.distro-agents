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
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:sessions:record none\ntable feed:sessions:record none\nwall 2026-10-13 02:30 +0000\nsize 120 40\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigPane(){ ## tag, line counted from 1 -- the left pane's part of that line of the screen, without the spaces at its end
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/│.*$//' -e 's/  *$//'
}
rigPaneHolds(){ ## tag, text -- how many lines of the left pane of that screen hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -e 's/│.*$//' | LC_ALL=C grep -c -F -- "$2" || :
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
rigOthers(){ ## how many starts were none of the three operations this screen may call here
	LC_ALL=C grep -c -v -e '^--manager-session-list' -e '^--manager-routine-list$' -e '^--magic-spawn-session' "$MANAGER_SCREEN_RIG/calls" || :
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
cells title 1 84 120
cells row1 2 84 120
cells row2 3 84 120
cells row3 4 84 120
cells row4 5 84 120
cells row5 6 84 120
cells row6 7 84 120
cells row7 8 84 120
cells row8 9 84 120
looks k
RIGSCRIPT
rigAssert "until it is entered the routines are not read"            "$( rigVal on.selected ) $( rigCalled --manager-routine-list )" "launch 1"
rigAssert "entering it asks the operation that lists the routines, once" "$( rigVal asked.path ) $( rigVal asked.reading ) $( rigCalled --manager-routine-list ) $( rigOthers )" "sessions/launch list:sessions/launch 1 0"
rigAssert "the first row under the row that goes up is the free prompt" "[$( rigVal title )] [$( rigVal row1 )][$( rigVal row2 )] $( rigVal in.rows )" "[ Launch / Spawn] [>..][ Free prompt] 7"
rigAssert "then every routine, in the order of the operation, by its selector without .routine.md" "[$( rigVal row3 )][$( rigVal row4 )][$( rigVal row5 )]" "[ keeper-myx.spec-conformance][ magic-coordinator.daily][ magic-coordinator.retro]"
rigAssert "one that cannot be started carries what the operation says of it" "[$( rigVal row6 )][$( rigVal row7 )][$( rigVal row8 )]" "[ magic-team.discuss    not-startable][ odd                          broken][]"
rigAssert "and shows plainer than the ones that can"                 "$( rigLooks k 5 86 86 )$( rigLooks k 6 86 86 )$( rigLooks k 7 86 86 )$( rigLooks k 8 86 86 )$( rigLooks k 9 86 86 )" "...DD"
rigAssert "on the row that goes up the left pane says what the level holds" "[$( rigPane u 3 )]" "[ 5 routines: 3 can be started here, 2 cannot.]"

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
cells freeKeys 37 0 83
keys DOWN DOWN
turn
get daily
show d
cells dailyKeys 37 0 83
keys DOWN
turn
show r
keys DOWN
turn
get discuss
show n
cells discussKeys 37 0 83
keys DOWN
turn
get odd
show o
cells oddKeys 37 0 83
RIGSCRIPT
rigAssert "the free prompt says what a line typed there starts"      "$( rigVal free.selected ) [$( rigPane f 3 )][$( rigPane f 4 )][$( rigPane f 5 )]" \
	"free [ A line typed here starts a new coworking session, opened by the coordinator, with][ that line as its brief.][ Enter opens the line to type in. An empty line starts nothing.]"
rigAssert "and the left pane names Enter as its key"                 "[$( rigVal freeKeys )]" "[ keys: Enter start]"
rigAssert "a routine: its file, its owner, its title, its executors" "$( rigVal daily.selected ) [$( rigPane d 3 )][$( rigPane d 4 )][$( rigPane d 5 )][$( rigPane d 6 )]" \
	"magic-coordinator/$rigDaily [ routine   $rigDaily][ owner     magic-coordinator][ title     magic-coordinator.daily.routine — the daily meeting][ executors magic-coordinator]"
rigAssert "the kind of its session, that Enter starts it, and the name its session takes" "[$( rigPane d 7 )][$( rigPane d 8 )][$( rigPane d 9 )][$( rigPane d 10 )] [$( rigVal dailyKeys )]" \
	"[ session   coworking: the spawner adds magic-coordinator to it][ start     Enter starts it, as its executors, whoever is at the console][ name      daily, the name its session takes unless another is typed][] [ keys: Enter start]"
rigAssert "several executors read with their spaces"                 "[$( rigPane r 6 )]" "[ executors magic-coordinator, magic-librarian]"
rigAssert "one that cannot be started says so, and why"              "$( rigVal discuss.selected ) [$( rigPane n 8 )][$( rigPane n 9 )][$( rigPane n 10 )]" \
	"magic-team/magic-team.discuss.routine.md [ start     not-startable: Enter does not start it][ why       its executors, magic-team, is any member: the session spawner starts it][           only with members named]"
rigAssert "and the left pane names no key for it"                    "[$( rigVal discussKeys )]" "[]"
rigAssert "a broken file: what the operation says of it, and no key" "$( rigVal odd.selected ) [$( rigPane o 3 )][$( rigPane o 4 )][$( rigPane o 5 )][$( rigPane o 6 )] [$( rigVal oddKeys )]" \
	"rig-member/odd.routine.md [ routine   odd.routine.md][ owner     rig-member][ start     broken: Enter does not start it][ why       the file does not open with a frontmatter block] []"

echo "-- Enter twice starts a routine under its own name --"
rigCase start
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
copy $rigTmp/start/after.rows $rigTmp/start/rows
keys ENTER
get asked
show d
cells askedLine 38 0 83
turn 3
get waiting
keys ENTER
get started
cells startedLine 38 0 83
wait action 30
get answered
show a
cells answeredLine 38 0 83
wait sessions 30
turn
keys LEFT
get up
cells upRow3 4 84 120
cells upRow4 5 84 120
RIGSCRIPT
rigAssert "Enter on a routine opens the line with the name of its session: the selector without its owner and .routine.md" "[$( rigVal asked.dialog )] [$( rigVal askedLine )] $( rigVal asked.cursor )" "[name:|daily] [ name: daily] 38,12"
rigAssert "above the line stands what will be started, and as whom"   "[$( rigPane d 35 )][$( rigPane d 36 )]" "[ START the routine $rigDaily][ It runs as its executors, whoever is at the console: magic-coordinator]"
rigAssert "and that the name can be typed over, or left"             "[$( rigPane d 37 )][$( rigPane d 38 )]" "[ The line below is the name of its session: type over it, or leave it.][ With no name the session shows by its id. Enter starts it. Esc starts nothing.]"
rigAssert "until Enter is pressed again nothing is started"          "[$( rigVal waiting.dialog )] $( rigVal waiting.calls ) [$( rigVal waiting.reading )]" "[name:|daily] 0 []"
rigAssert "Enter again starts it, beside the screen"                 "[$( rigVal started.dialog )] $( rigVal started.reading ) [$( rigVal startedLine )]" "[] action:launch:$rigDaily [ start asked of the tooling: $rigDaily, named daily]"
rigAssert "the operation is called once, with that routine and the name daily" "$( rigStarts ) [$( rigStartWords 1 )]" "1 [[--magic-spawn-session][--routine][$rigDaily][--session-name-or-comment][daily]]"
rigAssert "nothing goes to its standard input, and nothing else is called" "$( rigInput '' ) $( rigOthers )" "none 0"
rigAssert "the bottom line shows the id of the new session, and of its members what fits" "[$( rigVal answeredLine )] [$( rigVal answered.notice )]" "[ started: session $rigNew, members magic-coordinator,…] [started: session $rigNew, members magic-coordinator, magic-librarian]"
rigAssert "the left pane shows what the operation printed: the session, its name, the routine, the members" "[$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )][$( rigPane a 6 )][$( rigPane a 7 )]" \
	"[ the start, answered 02:30:00:][ session   $rigNew][ name      daily][ routine   $rigDaily][ members   magic-coordinator, magic-librarian]"
rigAssert "and what it noted, then the routine as before"            "[$( rigPane a 8 )][$( rigPane a 9 )][$( rigPane a 10 )]" "[ note      magic-spawn-session: added magic-librarian: the rig says so][][ routine   $rigDaily]"
rigAssert "the list is read again, and the new session is among its rows" "$( rigCalled --manager-session-list ) $( rigVal up.path ) [$( rigVal upRow3 )][$( rigVal upRow4 )]" "2 sessions [ daily                       running][ keeper-myx 11111111         running]"

echo "-- a name typed over the default is the one passed --"
rigCase name
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN DOWN DOWN
keys ENTER$( rigType ' of Monday' )
get typed
keys ENTER
wait action 30
keys ENTER BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE$( rigType 'stand up' ) ENTER
wait action 30
keys ENTER BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE
get emptied
keys ENTER
get none
wait action 30
keys ENTER BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE SPACE SPACE ENTER
wait action 30
RIGSCRIPT
rigAssert "the name is typed on after the default"                   "[$( rigVal typed.dialog )]" "[name:|daily of Monday]"
rigAssert "and passed whole, as one word of the command"             "[$( rigStartWords 1 )]" "[[--magic-spawn-session][--routine][$rigDaily][--session-name-or-comment][daily of Monday]]"
rigAssert "the default deleted and another name typed: that one is passed" "[$( rigStartWords 2 )]" "[[--magic-spawn-session][--routine][$rigDaily][--session-name-or-comment][stand up]]"
rigAssert "the name emptied: the routine is started with no name"    "[$( rigVal emptied.dialog )] [$( rigVal none.notice )] [$( rigStartWords 3 )]" "[name:|] [start asked of the tooling: $rigDaily, with no name] [[--magic-spawn-session][--routine][$rigDaily]]"
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
cells escLine 38 0 83
keys DOWN DOWN ENTER
get discuss
cells discussLine 38 0 83
keys RIGHT
get right
keys DOWN ENTER
get odd
keys UP UP UP TAB ENTER
get left
turn 3
get end
RIGSCRIPT
rigAssert "Esc closes the line: nothing is started, and the bottom line is empty" "[$( rigVal esc.dialog )] [$( rigVal escLine )] $( rigVal esc.selected )" "[] [] magic-coordinator/$rigDaily"
rigAssert "Enter on a routine that cannot be started opens no line, and says why" "$( rigVal discuss.selected ) [$( rigVal discuss.dialog )] [$( rigVal discuss.notice )]" \
	"magic-team/magic-team.discuss.routine.md [] [not started: magic-team.discuss.routine.md is not-startable: its executors, magic-team, is any member: the session spawner starts it only with members named]"
rigAssert "the bottom line shows the start of that, cut to the pane" "[$( rigVal discussLine )]" "[ not started: magic-team.discuss.routine.md is not-startable: its executors, magic…]"
rigAssert "Right on a routine dives nowhere and starts nothing"       "$( rigVal right.path ) [$( rigVal right.dialog )]" "sessions/launch []"
rigAssert "a broken file is not started either"                      "[$( rigVal odd.dialog )] [$( rigVal odd.notice )]" "[] [not started: odd.routine.md is broken: the file does not open with a frontmatter block]"
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
show d
keys ENTER
get empty
cells emptyLine 38 0 83
keys ENTER SPACE SPACE ENTER
get spaces
keys ENTER x ESC
get esc
turn 3
get end
RIGSCRIPT
rigAssert "Enter on the free prompt opens the line for one line of text" "[$( rigVal asked.dialog )] [$( rigPane d 36 )][$( rigPane d 37 )][$( rigPane d 38 )]" \
	"[prompt:|] [ FREE PROMPT: a new coworking session, opened by the coordinator][ The line typed below is its brief, given to the operation on its standard input.][ Enter goes on to the name of the session. Esc starts nothing.]"
rigAssert "Enter with no text starts nothing, and says so"           "[$( rigVal empty.dialog )] [$( rigVal emptyLine )]" "[] [ nothing was started: the line was empty]"
rigAssert "spaces alone are no text, and Esc starts nothing"         "[$( rigVal spaces.dialog )] [$( rigVal spaces.notice )] [$( rigVal esc.dialog )] [$( rigVal esc.notice )]" "[] [nothing was started: the line was empty] [] []"
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
keys ENTER
get name
show n
turn 3
get waiting
keys ENTER
get started
wait action 30
get answered
show a
cells answeredLine 38 0 83
RIGSCRIPT
rigAssert "the line is typed"                                        "[$( rigVal typed.dialog )]" "[prompt:|Magic, start retro please]"
rigAssert "Enter goes on to the name of the session, with the line above it" "[$( rigVal name.dialog )] [$( rigPane n 36 )][$( rigPane n 37 )][$( rigPane n 38 )]" \
	"[name:|] [ FREE PROMPT: Magic, start retro please][ The line below is the name of its session, or none: it then shows by its id.][ Enter starts it. Esc starts nothing.]"
rigAssert "until the name is entered nothing is started"             "[$( rigVal waiting.dialog )] $( rigVal waiting.calls ) [$( rigVal waiting.reading )]" "[name:|] 0 []"
rigAssert "Enter with no name starts it"                             "$( rigVal started.reading ) [$( rigVal started.notice )]" "action:prompt:free [start asked of the tooling: a free prompt, with no name]"
rigAssert "the operation is called once, with --routine-default and no word of the line" "$( rigStarts ) [$( rigStartWords 1 )] $( rigCalled '--magic-spawn-session --routine-default' )" "1 [[--magic-spawn-session][--routine-default]] 1"
rigAssert "the line is on its standard input, whole, with a line end" "$( rigInput 'Magic, start retro please' )" same
rigAssert "what the operation printed is shown"                      "[$( rigVal answeredLine )] [$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )]" \
	"[ started: session $rigNew, members magic-coordinator,…] [ the start, answered 02:30:00:][ session   $rigNew][ name      none: it shows by its id]"

echo "-- the free prompt with a name, with odd characters, and Esc at the name --"
rigCase named
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN ENTER
wait list 30
keys DOWN
keys ENTER$( rigType 'Magic, start retro please' ) ENTER$( rigType 'retro by hand' ) ENTER
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
keys ENTER$( rigType "$rigOdd" ) ENTER ENTER
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
keys ENTER$( rigType 'Magic, start retro please' ) ENTER x ESC
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
cells failedLine 38 0 83
wait sessions 30
turn
keys LEFT
get up
RIGSCRIPT
rigAssert "the error line of the operation stands in the bottom line" "[$( rigVal failedLine )]" "[ --magic-spawn-session: rig-tools: ⛔ ERROR: the rig said fail]"
rigAssert "and in the left pane, which says that the start failed"   "[$( rigPane f 3 )][$( rigPane f 4 )][$( rigPane f 5 )]" "[ the start failed, answered 02:30:00:][ rig-tools: ⛔ ERROR: the rig said fail][]"
rigAssert "the list is read again, and holds no new session"         "$( rigCalled --manager-session-list ) $( rigVal up.path ) $( rigVal up.rows )" "2 sessions 3"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN LAUNCH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_LAUNCH: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
