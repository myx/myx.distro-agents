#!/usr/bin/env bash
## Behavioural check on the kill key of the manager screen (sh-lib/AgentsManagerScreen.py), run rather than read.
## The screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py),
## and where it would call the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.stub.sh),
## which notes each start, its arguments word for word and what came on its standard input, and prints the fixture
## kept for those very arguments: rows in the forms `--manager-session-list` and `--manager-session-kill` print.
## Held: `k` on a running session opens the line to type in and says above it exactly what will be killed: the
## session by its name and its id, each agent that is alive with its own id, and how many are left as they are;
## Esc calls nothing and leaves the bottom line empty; the typed word `yes` calls `--manager-session-kill
## --session-id <id>` once, with the id of that session; on an agent that joined, with that agent's own id and
## `--run`; on the founder, whose id is its session's, with `--run` too, never the id alone, which would end the
## whole session; any other word, a part of it, capitals, a space around it or nothing at all kills nothing and says
## so; a row that is no session and no agent, a session with no live agent and an agent that is not alive say that
## there is nothing to kill, and nothing is asked; the left pane names `k kill` only where it has something to end;
## while the confirmation is open the plan of the kill is read (`--plan`, which ends nothing) and the dialog then says
## from its rows what is ended, dismissed and closed; a session that is not finished and has no agent alive takes `k`
## too, its dialog titled Close with a Close button, and the kill finishes it: the status line gives the summing row;
## what the operation answered for each run stands at the head of the left pane, ended, killed, not ended, was not
## running, and their count in the bottom line; then the list is read again and shows the session as it is now; a
## kill that fails shows its error line, after the rows it printed; an answer that comes when another item is
## selected stays out of that item's pane; the key works with the focus on the left pane too; and a kill that was
## confirmed runs on to its own end when the screen ends first, while a read that runs then is ended with the screen.
## Offline: no operation of the real tooling is called, no process is signalled, and no session of this machine is read.
## Reconciled for F11.0: the left pane has no `keys:` line any more, so the keys of a row are read from the status
## line (rigKeysNamed); the spacer under `Launch (Start)` moves each session row of the list one line down; every
## dialog has bigger margins inside its frame (two empty lines under its top, one more under its buttons, three blank
## cells at each side), so its box is four cells wider and two lines taller and what it holds stands where it stood.
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
rigTmp="$( mktemp -d -t AgentsManagerScreenKillCheck )" || exit 1
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
## One session that runs, `daily of Monday`, with four runs: its founder, whose id is the session's, which waits; a
## tester that joined and works; a keeper that has ended; and a run with no id of its own. And one lone run that has
## ended. Then the same two sessions as they read once the first was killed. What the kill prints for an id is kept
## under the arguments of that kill.
rigS1=11111111-0000-4000-8000-000000000001 ; rigR2=a2a2a2a2-0000-4000-8000-0000000000a2 ; rigR3=a3a3a3a3-0000-4000-8000-0000000000a3
rigS2=22222222-0000-4000-8000-000000000002
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
rigLone(){
	rigRow session "$rigS2" - finished 2026-10-11_14:28_+0000 2026-10-11_14:51_+0000 1 finished=1
	rigRow run "$rigS2" "$rigS2" magic-devops spawn-succeeded no-process finished 2026-10-11_14:28_+0000 2026-10-11_14:51_+0000 rig-host ws-rig -
}
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 4 running=2,finished=2
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting
	rigRow run "$rigS1" "$rigR2" magic-tester spawn-started running running 2026-10-12_17:05_+0000 - rig-host ws-rig working
	rigRow run "$rigS1" "$rigR3" keeper-myx spawn-succeeded no-process finished 2026-10-12_17:06_+0000 2026-10-12_18:00_+0000 rig-host ws-rig -
	rigRow run "$rigS1" - magic-developer spawn-failed no-spawn-id finished 2026-10-12_17:10_+0000 2026-10-12_17:11_+0000 rig-host ws-rig -
	rigLone
	rigRow counters 1 0 1 1 3 0.42
} > "$rigF/rows"
{
	rigRow session "$rigS1" daily_of_Monday finished 2026-10-12_16:57_+0000 2026-10-13_02:30_+0000 4 finished=4
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-failed no-process finished 2026-10-12_16:57_+0000 2026-10-13_02:30_+0000 rig-host ws-rig -
	rigRow run "$rigS1" "$rigR2" magic-tester spawn-failed no-process finished 2026-10-12_17:05_+0000 2026-10-13_02:30_+0000 rig-host ws-rig -
	rigRow run "$rigS1" "$rigR3" keeper-myx spawn-succeeded no-process finished 2026-10-12_17:06_+0000 2026-10-12_18:00_+0000 rig-host ws-rig -
	rigRow run "$rigS1" - magic-developer spawn-failed no-spawn-id finished 2026-10-12_17:10_+0000 2026-10-12_17:11_+0000 rig-host ws-rig -
	rigLone
	rigRow counters 0 0 0 0 3 0.42
} > "$rigF/after.rows"
rigKillSession="--manager-session-kill --session-id $rigS1"
rigKillFounder="--manager-session-kill --session-id $rigS1 --run"
rigKillTester="--manager-session-kill --session-id $rigR2 --run"
{
	rigRow kill "$rigS1" "$rigS1" magic-coordinator ended spawn-started 4101 dispatch-20261012T165700Z-daily-1
	rigRow kill "$rigS1" "$rigR2" magic-tester killed spawn-started 4102,4103 -
	rigRow kill "$rigS1" "$rigR3" keeper-myx no-process spawn-succeeded - -
	rigRow kill "$rigS1" - magic-developer no-spawn-id spawn-failed - -
} > "$rigF/rows.$rigKillSession"
rigRow kill "$rigS1" "$rigS1" magic-coordinator ended spawn-started 4101 dispatch-20261012T165700Z-daily-1 > "$rigF/rows.$rigKillFounder"
## What each of those kills would do, as `--plan` prints it: the same rows, a run that lives as one that would be
## ended, and for the whole session the row that sums them. The tester asked one question that waits.
rigQ2=0f62d1f4-0000-4000-8000-0000000000f2
{
	rigRow kill "$rigS1" "$rigS1" magic-coordinator would-end spawn-started 4101 dispatch-20261012T165700Z-daily-1
	rigRow kill "$rigS1" "$rigR2" magic-tester would-end spawn-started 4102,4103 -
	rigRow kill "$rigS1" "$rigR3" keeper-myx no-process spawn-succeeded - -
	rigRow kill "$rigS1" - magic-developer no-spawn-id spawn-failed - -
	rigRow finish "$rigS1" 2 0 0 running
} > "$rigF/rows.$rigKillSession --plan"
rigRow kill "$rigS1" "$rigS1" magic-coordinator would-end spawn-started 4101 dispatch-20261012T165700Z-daily-1 > "$rigF/rows.$rigKillFounder --plan"
{
	rigRow kill "$rigS1" "$rigR2" magic-tester would-end spawn-started 4102 -
	rigRow dismiss "$rigS1" "$rigQ2" "$rigR2" would-dismiss
} > "$rigF/rows.$rigKillTester --plan"
rigRow kill "$rigS1" "$rigR2" magic-tester ended spawn-started 4102 - > "$rigF/rows.$rigKillTester"
{
	rigRow kill "$rigS1" "$rigS1" magic-coordinator not-ended spawn-started 4101 dispatch-20261012T165700Z-daily-1
	rigRow kill "$rigS1" "$rigR2" magic-tester ended spawn-started 4102 -
} > "$rigF/stuck.rows"
## A fresh rig for one case: a copy of the fixtures, no call noted yet.
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	: > "$MANAGER_SCREEN_RIG/ended"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size, with the reads of one item taken out of the table; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:sessions:record none\ntable feed:sessions:record none\ntable view:sessions/*:record none\ntable feed:sessions/*:record none\nwall 2026-10-13 02:30 +0000\nsize 120 40\nroot sessions\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigKeysNamed(){ ## cells name -- the row's own keys as the status line names them, in the words the pane's `keys:` line
	## had before F11.0 removed it; `PANE-KEYS-LINE` where the pane still has a line of its own
	local namedSaid namedWords="" namedPair namedKey namedWord
	if rigVal "$1" | LC_ALL=C grep -q '^keys:' ; then printf 'PANE-KEYS-LINE' ; return 0 ; fi
	namedSaid="$( rigVal "${1}Status" ) "
	for namedPair in k:Kill ; do
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
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigKills(){ ## how many times the kill operation was started to kill, whatever its arguments: a plan of it, which ends nothing, is not counted
	LC_ALL=C grep -- '^--manager-session-kill' "$MANAGER_SCREEN_RIG/calls" | LC_ALL=C grep -c -v -- ' --plan$' || :
}
rigKillWords(){ ## the arguments of every start of the kill operation that kills, each between brackets, a start a line
	LC_ALL=C grep -F -- '[--manager-session-kill]' "$MANAGER_SCREEN_RIG/words" | LC_ALL=C grep -v -F -- '[--plan]' || :
}
rigPlans(){ ## how many times the plan of a kill was read
	LC_ALL=C grep -c -- '^--manager-session-kill .* --plan$' "$MANAGER_SCREEN_RIG/calls" || :
}
rigOthers(){ ## how many starts were neither the list of the sessions nor the kill. The list of the locations, which every start of the screen reads, is not counted.
	LC_ALL=C grep -c -v -e '^--manager-session-list' -e '^--manager-session-kill' -e '^--manager-place-list$' "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- the kill key asks first, and says exactly what will be killed --"
rigCase esc
rigBoxHas(){ printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || : ; } ## tag, text -- how many lines of that drawing of a dialog hold the text
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
turn
get on
cells onKeys 37 1 83
cells onKeysStatus 39 0 120
keys k
get asked
show d
box b
cells askedLine 38 1 83
keys y e
get typing
cells typingLine 38 1 83
box t
wait plan 30
get planned
box p
keys ESC
turn
get esc
said escLine
cells escKeys 37 1 83
cells escKeysStatus 39 0 120
RIGSCRIPT
rigAssert "a running session is selected, and the left pane names the kill key for it" "$( rigVal on.selected ) [$( rigKeysNamed onKeys )]" "$rigS1 [keys: k kill]"
rigAssert "k opens the dialog of a kill, the keys on the field for the word" "[$( rigVal asked.dialog )] [$( rigVal asked.dialogTitle )] $( rigBoxHas b '║   Type yes to kill ' ) $( rigBoxHas b ' »Kill« ▅   Cancel  ▅' )" "[kill:word|] [Kill the session] 1 1"
rigAssert "the dialog says what will be killed: the session by its name and its id" "$( rigBoxHas b '║   KILL the session daily of Monday ' ) $( rigBoxHas b "║   session $rigS1 " )" "1 1"
rigAssert "each agent that is alive, with its state and its own id"  "$( rigBoxHas b '║   Its 2 live agents end the hard way: no closure runs, none is asked ' ) $( rigBoxHas b "║     magic-coordinator  running waiting  $rigS1 " ) $( rigBoxHas b "║     magic-tester       running working  $rigR2 " )" "1 1 1"

rigAssert "that what it does besides is being read, and how to back out" "$( rigBoxHas b '║   What it does besides, the questions it dismisses and the records it ' ) $( rigBoxHas b '║   The word yes, typed whole, and Kill or Enter: that kills. Cancel and Esc ' )" "1 1"
rigAssert "the plan of the kill is read while the dialog is open, once, by the id of the session, and what was typed stays" "$( rigPlans ) $( rigCalled "$rigKillSession --plan" ) [$( rigVal planned.dialog )] [$( rigVal planned.dialogTitle )]" "1 1 [kill:word|ye] [Kill the session]"
rigAssert "then the dialog says from its rows what is ended, each with its processes and its own id" "$( rigBoxHas p '║   It ends 2 agents the hard way: no closure runs, none is asked anything. ' ) $( rigBoxHas p "║     magic-coordinator  pid 4101  $rigS1 " ) $( rigBoxHas p "║     magic-tester       pid 4102,4103  $rigR2 " )" "1 1 1"
rigAssert "what is dismissed and closed, here nothing, and the state the session reads" "$( rigBoxHas p '║   No question of it waits: nothing is dismissed. ' ) $( rigBoxHas p '║   No record of it is left open: nothing is closed. ' ) $( rigBoxHas p '║   The session reads running now. ' ) $( rigBoxHas p 'is being read' )" "1 1 1 0"
rigAssert "the pane of the session stays above it, and nothing spills" "[$( rigPane d 4 )] $( rigVal asked.spills )" "[  state    running] 0"
rigAssert "what is typed shows in the field"                       "[$( rigVal typing.dialog )] $( rigBoxHas t '║   ye ' )" "[kill:word|ye] 1"
rigAssert "Esc closes the line: the bottom line is empty again, and the keys of the item are back" "[$( rigVal esc.dialog )] [$( rigVal esc.notice )] [$( rigVal escLine )] [$( rigKeysNamed escKeys )]" "[] [] [] [keys: k kill]"
rigAssert "and no operation was called but the list"                 "$( rigKills ) $( rigOthers ) $( rigVal esc.calls ) [$( rigVal esc.reading )]" "0 0 0 []"

echo "-- the typed word kills the selected session, and the answer is shown --"
rigCase session
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN DOWN
copy $rigTmp/session/after.rows $rigTmp/session/rows
keys k
wait plan 30
keys y e s
get typed
keys ENTER
get pressed
wait plan 30
get asked
said askedLine
wait action 30
get answered
show a
said answeredLine
wait sessions 30
turn
get after
show z
cells afterRow 5 85 119
cells afterKeys 37 1 83
RIGSCRIPT
rigAssert "Enter on the word does nothing at once: the plan is read once more, and the dialog says so" "[$( rigVal pressed.dialog )] [$( rigVal pressed.dialogSays )] $( rigVal pressed.calls )" "[kill:word|yes] [its plan is read once more: it is done if nothing of it has changed] 0"
rigAssert "until Enter nothing is called"                            "[$( rigVal typed.dialog )] [$( rigVal typed.reading )]" "[kill:word|yes] []"
rigAssert "Enter on the word starts the kill, beside the screen"     "[$( rigVal asked.dialog )] $( rigVal asked.reading ) [$( rigVal askedLine )]" "[] action:kill:$rigS1 [kill asked of the tooling: the session daily of Monday]"
rigAssert "the operation is called once, with the id of that session and nothing more" "$( rigKills ) [$( rigKillWords )]" "1 [[--manager-session-kill][--session-id][$rigS1]]"
rigAssert "nothing goes to its standard input, and nothing else is called" "$( [ -e "$MANAGER_SCREEN_RIG/stdin.--manager-session-kill" ] && printf input || printf none ) $( rigOthers )" "none 0"
rigAssert "the bottom line counts what the operation answered"       "[$( rigVal answeredLine )]" "[kill: 1 ended, 1 killed, 1 was not running, 1 not signalled]"
rigAssert "the left pane shows the answer for each run: ended, killed, was not running" "[$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )][$( rigPane a 6 )]" \
	"[ the kill, answered 02:30:00:][   magic-coordinator  ended][   magic-tester       killed: it took KILL][   keeper-myx         was not running]"
rigAssert "and one that was not signalled, with why"                 "[$( rigPane a 7 )][$( rigPane a 8 )] $( rigVal answered.answer )" "[   magic-developer    not signalled: it has no id of its own][] 5"
rigAssert "then the list is read again"                              "$( rigCalled --manager-session-list )" 2
rigAssert "and shows the session as it is now, still selected, under the answer" "$( rigVal after.selected ) [$( rigVal afterRow )] [$( rigPane z 3 )][$( rigPane z 10 )]" \
	"$rigS1 [>daily of Monday        finished ►] [ the kill, answered 02:30:00:][  state    finished]"
rigAssert "it has nothing to kill any more: the pane names no kill key" "[$( rigVal afterKeys )]" "[]"

echo "-- on an agent the kill takes the agent's own id, with --run --"
rigCase agent
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN ENTER DOWN DOWN
turn
get on
cells onKeys 37 1 83
cells onKeysStatus 39 0 120
keys k
get asked
show d
box b
wait plan 30
box p
keys y e s ENTER
wait plan 30
wait action 30
get answered
show a
said answeredLine
RIGSCRIPT
rigAssert "an agent that joined the session is selected"             "$( rigVal on.path ) $( rigVal on.selected ) [$( rigKeysNamed onKeys )]" "sessions/$rigS1 $rigR2 [keys: k kill]"
rigAssert "the dialog asks for the word, naming the agent"          "[$( rigVal asked.dialog )] [$( rigVal asked.dialogTitle )]" "[kill:word|] [Kill the agent magic-tester]"
rigAssert "it says: that agent alone, by its own id, and of which session" "$( rigBoxHas b '║   KILL the agent magic-tester alone ' ) $( rigBoxHas b "║   run $rigR2, running working " ) $( rigBoxHas b "║   of the session daily of Monday ($rigS1) " )" "1 1 1"

rigAssert "and that the others run on"                              "$( rigBoxHas b '║   It ends the hard way: no closure runs, it is asked nothing. The others ' )" "1"
rigAssert "its plan is read with its own id and --run, on opening and once more when it is confirmed, and says which question of its own is dismissed with it" "$( rigCalled "$rigKillTester --plan" ) $( rigBoxHas p '║   It dismisses 1 question of it that waits: ' ) $( rigBoxHas p "║     $rigQ2  asked by magic-tester " )" "2 1 1"
rigAssert "the operation is called once, with the run's own id and --run" "$( rigKills ) [$( rigKillWords )]" "1 [[--manager-session-kill][--session-id][$rigR2][--run]]"
rigAssert "and never with the id of its session"                     "$( LC_ALL=C grep -c -F -- "$rigS1" "$MANAGER_SCREEN_RIG/words" || : )" 0
rigAssert "the answer of that one run is shown"                      "[$( rigVal answeredLine )] [$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )]" "[kill: 1 ended] [ the kill, answered 02:30:00:][   magic-tester       ended][]"

echo "-- on the founder, whose id is its session's, --run is passed too --"
rigCase founder
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN ENTER DOWN
turn
get on
keys k
get asked
show d
box b
wait plan 30
keys y e s ENTER
wait plan 30
wait action 30
get answered
said answeredLine
RIGSCRIPT
rigAssert "the founder is selected: its id is the id of its session" "$( rigVal on.path ) $( rigVal on.selected )" "sessions/$rigS1 $rigS1"
rigAssert "the dialog says that it alone is ended, not the session"  "[$( rigVal asked.dialog )] $( rigBoxHas b '║   KILL the agent magic-coordinator alone ' ) $( rigBoxHas b "║   run $rigS1, running waiting " ) $( rigBoxHas b '║   It is the founder: its id is its session' )" "[kill:word|] 1 1 1"

rigAssert "the operation is called once, with that id and --run"     "$( rigKills ) [$( rigKillWords )]" "1 [[--manager-session-kill][--session-id][$rigS1][--run]]"
rigAssert "never with the id alone, which would end the whole session" "$( rigCalled "$rigKillSession" ) $( rigCalled "$rigKillFounder" )" "0 1"
rigAssert "the founder alone is answered for"                        "[$( rigVal answeredLine )]" "[kill: 1 ended]"

echo "-- a wrong word kills nothing --"
rigCase wrong
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
keys k y e ENTER
get part
keys ESC
keys k Y E S ENTER
get capitals
keys ESC
keys k SPACE y e s ENTER
get spaceBefore
keys ESC
keys k y e s SPACE ENTER
get spaceAfter
keys ESC
keys k y e s s ENTER
get more
keys ESC
keys k n o ENTER
get no
keys ESC
keys k ENTER
get nothing
keys ESC
wait plan 30
turn 3
get end
RIGSCRIPT
rigNothing="nothing is killed: the word typed is not yes"
rigAssert "a part of the word kills nothing: the dialog stays open, and says so" "[$( rigVal part.dialog )] [$( rigVal part.dialogSays )]" "[kill:word|ye] [$rigNothing]"
rigAssert "neither do capitals, a space before it or after it, or a letter more" "[$( rigVal capitals.dialogSays )][$( rigVal spaceBefore.dialogSays )][$( rigVal spaceAfter.dialogSays )][$( rigVal more.dialogSays )]" "[$rigNothing][$rigNothing][$rigNothing][$rigNothing]"
rigAssert "nor another word, nor no word at all"                     "[$( rigVal no.dialogSays )][$( rigVal nothing.dialogSays )]" "[$rigNothing][$rigNothing]"
rigAssert "the operation was never called"                           "$( rigKills ) $( rigOthers ) $( rigVal end.calls ) [$( rigVal end.reading )]" "0 0 0 []"

echo "-- a row that cannot be killed says so, and nothing is asked --"
rigCase cannot
rigScript <<'RIGSCRIPT'
keys k
get section
turn
keys ENTER
wait sessions 30
keys k
get up
turn
keys DOWN k
get launch
turn
keys DOWN DOWN
turn
get lone
cells loneKeys 37 1 83
keys k
get ended
turn
keys UP ENTER DOWN DOWN DOWN
turn
get keeper
cells keeperKeys 37 1 83
keys k
get gone
turn
keys DOWN k
get noId
turn
turn 3
get end
RIGSCRIPT
rigHere="Kill: for a session or an agent, not for what is selected"
rigAssert "on a section k is no key of the view; on the row that goes up the status line says what k is for, and no box opens" "[$( rigVal section.notice )][$( rigVal up.notice )] [$( rigVal section.dialog )$( rigVal up.dialog )]" "[][$rigHere] []"
rigAssert "on Launch (Start) there is nothing to kill, and no word is asked for" "$( rigVal launch.selected ) [$( rigVal launch.dialog )] [$( rigVal launch.notice )]" "launch [] [$rigHere]"
rigAssert "a session that has ended names no kill key"               "$( rigVal lone.selected ) [$( rigVal loneKeys )]" "$rigS2 []"
rigAssert "and k on it says in the status line that it is finished, asking nothing" "[$( rigVal ended.dialog )] [$( rigVal ended.notice )]" "[] [Kill: this session is finished]"
rigAssert "an agent that has ended names no kill key, and k says that it is not alive" "$( rigVal keeper.selected ) [$( rigVal keeperKeys )] [$( rigVal gone.dialog )] [$( rigVal gone.notice )]" "$rigR3 [] [] [Kill: this agent is not alive]"
rigAssert "neither is a run with no id of its own"                   "$( rigVal noId.selected ) [$( rigVal noId.dialog )] [$( rigVal noId.notice )]" "-3 [] [Kill: this agent is not alive]"
rigAssert "the operation was never called"                           "$( rigKills ) $( rigOthers ) $( rigVal end.calls )" "0 0 0"

echo "-- a session that is not finished and has no agent alive: k closes it, and the kill finishes it --"
rigS3=33333333-0000-4000-8000-000000000003 ; rigR5=b5b5b5b5-0000-4000-8000-0000000000b5 ; rigQ1=0f62d1f4-0000-4000-8000-0000000000f1
rigCase waiting
rigStale(){ ## the state of the session -- its rows of the list
	rigRow session "$rigS3" stale_work "$1" 2026-10-01_09:00_+0000 2026-10-01_10:00_+0000 2 finished=2
	rigRow run "$rigS3" "$rigS3" magic-coordinator spawn-succeeded no-process finished 2026-10-01_09:00_+0000 2026-10-01_10:00_+0000 rig-host ws-rig -
	rigRow run "$rigS3" "$rigR5" keeper-myx spawn-succeeded no-process finished 2026-10-01_09:05_+0000 2026-10-01_09:40_+0000 rig-host ws-rig -
	rigRow counters 0 0 0 1 1 0.42
}
rigStale waiting > "$MANAGER_SCREEN_RIG/rows"
rigStale finished > "$MANAGER_SCREEN_RIG/after.rows"
rigStaleKill(){ ## the outcome of the question, of the record, the state the session reads -- the rows of its kill
	rigRow kill "$rigS3" "$rigR5" keeper-myx no-process spawn-succeeded - -
	rigRow kill "$rigS3" "$rigS3" magic-coordinator no-process spawn-succeeded - -
	rigRow dismiss "$rigS3" "$rigQ1" "$rigS3" "$1"
	rigRow close "$rigS3" "$rigR5" keeper-myx "$2" dispatch-rig-stale-1
	rigRow finish "$rigS3" 0 1 1 "$3"
}
rigStaleKill would-dismiss would-close waiting > "$MANAGER_SCREEN_RIG/rows.--manager-session-kill --session-id $rigS3 --plan"
rigStaleKill dismissed closed finished > "$MANAGER_SCREEN_RIG/rows.--manager-session-kill --session-id $rigS3"
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN DOWN
turn
get on
cells onKeys 37 1 83
cells onKeysStatus 39 0 120
keys k
get asked
box b
wait plan 30
get planned
box p
keys y e ENTER
get part
keys s
copy $rigTmp/waiting/after.rows $rigTmp/waiting/rows
keys ENTER
wait plan 30
get sent
said sentLine
wait action 30
get answered
show a
said answeredLine
wait sessions 30
turn
get after
cells afterKeys 37 1 83
RIGSCRIPT
rigAssert "a session that waits with no agent alive is selected, and the left pane names the kill key for it" "$( rigVal on.selected ) [$( rigKeysNamed onKeys )]" "$rigS3 [keys: k kill]"
rigAssert "k asks, and its title, its button and its word say Close: nothing of it lives" "[$( rigVal asked.dialog )] [$( rigVal asked.dialogTitle )] $( rigBoxHas b '║   Type yes to close ' ) $( rigBoxHas b ' »Close« ▅   Cancel  ▅' ) $( rigBoxHas b ' »Kill« ▅' )" "[close:word|] [Close the session] 1 1 0"
rigAssert "it names the session, says that nothing is ended, and that the rest is being read" "$( rigBoxHas b '║   CLOSE the session stale work ' ) $( rigBoxHas b "║   session $rigS3 " ) $( rigBoxHas b '║   No agent of it is alive: nothing is ended. ' ) $( rigBoxHas b '║   What it does besides, the questions it dismisses and the records it ' )" "1 1 1 1"
rigAssert "its plan is read when the dialog opens and once more when it is confirmed, and ends nothing" "$( rigPlans ) $( rigCalled "--manager-session-kill --session-id $rigS3 --plan" ) $( rigVal planned.calls ) [$( rigVal planned.dialog )]" "2 2 0 [close:word|]"
rigAssert "from the rows of the plan: the question that is dismissed, by who asked it" "$( rigBoxHas p '║   No agent of it is alive: nothing is ended. ' ) $( rigBoxHas p '║   It dismisses 1 question of it that waits: ' ) $( rigBoxHas p "║     $rigQ1  asked by magic-coordinator " )" "1 1 1"
rigAssert "the record that is closed, the state it reads now, and how to back out" "$( rigBoxHas p '║   It closes 1 record of it left open: ' ) $( rigBoxHas p '║     keeper-myx         dispatch-rig-stale-1 ' ) $( rigBoxHas p '║   The session reads waiting now. ' ) $( rigBoxHas p '║   The word yes, typed whole, and Close or Enter: that finishes the ' )" "1 1 1 1"
rigAssert "a part of the word closes nothing, and the dialog says so in its own words" "[$( rigVal part.dialog )] [$( rigVal part.dialogSays )]" "[close:word|ye] [nothing is closed: the word typed is not yes]"
rigAssert "the word whole and Enter: the kill of that session is asked, once, by its id alone" "[$( rigVal sent.dialog )] [$( rigVal sentLine )] $( rigKills ) [$( rigKillWords )]" "[] [close asked of the tooling: the session stale work] 1 [[--manager-session-kill][--session-id][$rigS3]]"
rigAssert "the status line gives the row that sums it: ended, dismissed, closed, and the state" "[$( rigVal answeredLine )]" "[kill: 0 ended, 1 dismissed, 1 closed: the session reads finished]"
rigAssert "the left pane sets out each row of the answer"           "[$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )][$( rigPane a 6 )][$( rigPane a 7 )][$( rigPane a 8 )]" \
	"[ the kill, answered 02:30:00:][   keeper-myx         was not running][   magic-coordinator  was not running][   question $rigQ1 of magic-coordinator: dismissed][   record of keeper-myx: closed][   the session reads finished]"
rigAssert "then the list is read again, and the session, finished, takes no kill any more" "$( rigCalled --manager-session-list ) $( rigVal after.selected ) [$( rigVal afterKeys )]" "2 $rigS3 []"

echo "-- the plan is read when the confirmation opens and once more when it is confirmed: one that changed meanwhile is not acted on --"
rigCase changed
{
	rigRow kill "$rigS1" "$rigS1" magic-coordinator would-end spawn-started 4101 dispatch-20261012T165700Z-daily-1
	rigRow kill "$rigS1" "$rigR2" magic-tester no-process spawn-started - -
	rigRow kill "$rigS1" "$rigR3" keeper-myx no-process spawn-succeeded - -
	rigRow kill "$rigS1" - magic-developer no-spawn-id spawn-failed - -
	rigRow dismiss "$rigS1" "$rigQ2" "$rigR2" would-dismiss
	rigRow finish "$rigS1" 1 1 0 running
} > "$MANAGER_SCREEN_RIG/plan2.rows"
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN DOWN
keys k y e s ENTER
get early
wait plan 30
advance 25
turn 3
wait plan 30
box s
copy $rigTmp/changed/plan2.rows $rigTmp/changed/rows.$rigKillSession --plan
keys ENTER
get pressed
keys ENTER
wait plan 30
get changed
box c
keys y e s ENTER
wait plan 30
get again
said againLine
wait action 30
RIGSCRIPT
rigAssert "a press while the plan is still being read does nothing, and the dialog says so" "[$( rigVal early.dialog )] [$( rigVal early.dialogSays )] $( rigVal early.calls )" "[kill:word|yes] [nothing is done yet: its plan is still being read] 0"
rigAssert "the plan stands as it was read when the dialog opened, whatever time passes" "$( rigBoxHas s '║   It ends 2 agents the hard way: no closure runs, none is asked anything. ' ) $( rigBoxHas s '║   No question of it waits: nothing is dismissed. ' )" "1 1"
rigAssert "the press reads it once more, and a second press while that runs reads nothing more" "[$( rigVal pressed.dialog )] [$( rigVal pressed.dialogSays )]" "[kill:word|yes] [its plan is read once more: it is done if nothing of it has changed]"
rigAssert "the plan had changed: nothing is done, the word is taken out, and the dialog says so" "[$( rigVal changed.dialog )] $( rigVal changed.calls ) [$( rigVal changed.reading )] [$( rigVal changed.dialogSays )]" \
	"[kill:word|] 0 [] [nothing was done: its plan changed while this stood open. It stands above as it is now: type the word again]"
rigAssert "and it shows the plan as it is now"                       "$( rigBoxHas c '║   It ends 1 agent the hard way: no closure runs, none is asked anything. ' ) $( rigBoxHas c '║   It dismisses 1 question of it that waits: ' ) $( rigBoxHas c 'It ends 2 agents' )" "1 1 0"
rigAssert "confirmed again, with the plan as it now stands, the kill is asked for" "[$( rigVal again.dialog )] $( rigVal again.reading ) [$( rigVal againLine )]" "[] action:kill:$rigS1 [kill asked of the tooling: the session daily of Monday]"
rigAssert "once, by the id of the session; and the plan was read three times in all: on opening and at each confirmation" "$( rigKills ) [$( rigKillWords )] $( rigPlans )" "1 [[--manager-session-kill][--session-id][$rigS1]] 3"

echo "-- a kill that fails shows its error line --"
rigCase fail
## the kill itself fails, by its own words: its plan is read, since a kill whose plan cannot be read is not asked for
echo fail > "$MANAGER_SCREEN_RIG/mode.$rigKillSession"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
keys k
wait plan 30
keys y e s ENTER
wait plan 30
wait action 30
get failed
show f
keys ENTER
wait sessions 30
turn
get after
RIGSCRIPT
rigAssert "what the operation wrote stands in a box, whole" "[$( rigVal failed.dialogTitle )] [$( rigVal failed.dialogHolds )]" "[The kill failed] [operation: $rigKillSession / rig-tools: a line that is no error / rig-tools: ⛔ ERROR: the rig said fail]"
rigAssert "and in the left pane, which says that the kill failed"    "[$( rigPane f 3 )][$( rigPane f 4 )][$( rigPane f 5 )]" "[ the kill failed, answered 02:30:00:][ rig-tools: ⛔ ERROR: the rig said fail][]"
rigAssert "the list is read again all the same, and the session is as it was" "$( rigCalled --manager-session-list ) $( rigVal after.selected ) [$( rigVal after.failed )]" "2 $rigS1 []"
rigCase stuck
cp "$MANAGER_SCREEN_RIG/stuck.rows" "$MANAGER_SCREEN_RIG/rows.$rigKillSession"
echo fail-rows > "$MANAGER_SCREEN_RIG/mode.$rigKillSession"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
keys k
wait plan 30
keys y e s ENTER
wait plan 30
wait action 30
get stuck
show s
said stuckLine
RIGSCRIPT
rigAssert "a run that could not be ended is shown as not ended, with the other rows the operation printed" "[$( rigPane s 3 )][$( rigPane s 4 )][$( rigPane s 5 )]" \
	"[ the kill failed, answered 02:30:00:][   magic-coordinator  not ended: a process is still there after TERM and KILL][   magic-tester       ended]"
rigAssert "and the error line of the operation after them"           "[$( rigPane s 6 )][$( rigPane s 7 )] [$( rigVal stuck.dialogHolds )]" "[ rig-tools: ⛔ ERROR: the rig said fail, after its rows][] [operation: $rigKillSession / rig-tools: ⛔ ERROR: the rig said fail, after its rows]"

echo "-- an answer that comes when another item is selected stays out of its pane --"
rigCase moved
echo "sleep 1" > "$MANAGER_SCREEN_RIG/mode.--manager-session-kill"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
keys k
wait plan 30
keys y e s ENTER
wait plan 30
keys DOWN
get moved
wait action 30
get answered
show m
said answeredLine
keys UP
turn
get back
show b
RIGSCRIPT
rigAssert "the selection moves on while the kill runs"               "$( rigVal moved.selected ) $( rigVal moved.reading )" "$rigS2 action:kill:$rigS1"
rigAssert "its answer still stands in the bottom line"               "[$( rigVal answeredLine )]" "[kill: 1 ended, 1 killed, 1 was not running, 1 not signalled]"
rigAssert "and not in the pane of the item that is selected now, nor later in the first one's" "$( rigVal answered.answer ) $( rigPaneHolds m 'the kill' ) $( rigVal back.selected ) $( rigPaneHolds b 'the kill' )" "0 0 $rigS1 0"

echo "-- the key works with the focus on the left pane too --"
rigCase focus
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN TAB
keys k
get asked
wait plan 30
keys y e s ENTER
wait plan 30
wait action 30
get answered
RIGSCRIPT
rigAssert "with the focus on the left pane, k asks and the word kills" "$( rigVal asked.focus ) [$( rigVal asked.dialog )] $( rigKills ) [$( rigKillWords )]" "view [kill:word|] 1 [[--manager-session-kill][--session-id][$rigS1]]"

echo "-- a kill that was confirmed is carried out whole, also when the screen ends first --"
rigEnded(){ ## the arguments of a start, tenths of a second to wait at most -- how many starts with exactly those came to their own end by then
	local endedWaited=0
	while [ "$endedWaited" -lt "$2" ] && ! LC_ALL=C grep -q -x -F -- "$1" "$MANAGER_SCREEN_RIG/ended" ; do
		sleep 0.1 ; endedWaited=$(( endedWaited + 1 ))
	done
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/ended" || :
}
rigCase lasting
echo "sleep 2" > "$MANAGER_SCREEN_RIG/mode.--manager-session-kill"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
keys k
wait plan 30
keys y e s ENTER
wait plan 30
get asked
RIGSCRIPT
rigAssert "the screen ends while the kill it started still runs"     "$( rigVal asked.reading ) $( rigEnded "$rigKillSession" 0 )" "action:kill:$rigS1 0"
rigAssert "the kill runs on to its own end"                          "$( rigEnded "$rigKillSession" 100 )" 1
rigCase cut
echo "sleep 1" > "$MANAGER_SCREEN_RIG/mode.--manager-session-list"
rigScript <<'RIGSCRIPT'
keys ENTER
get asked
RIGSCRIPT
rigAssert "a read that runs when the screen ends is ended with it"   "$( rigVal asked.reading | LC_ALL=C tr ',' '\n' | LC_ALL=C grep -x 'list:sessions' ) $( rigEnded --manager-session-list 20 )" "list:sessions 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN KILL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_KILL: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
