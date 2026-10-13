#!/usr/bin/env bash
## Behavioural check on the kill key of the manager screen (sh-lib/AgentsManagerScreen.py), run rather than read.
## The screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.test.py),
## and where it would call the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.test.sh),
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
## what the operation answered for each run stands at the head of the left pane, ended, killed, not ended, was not
## running, and their count in the bottom line; then the list is read again and shows the session as it is now; a
## kill that fails shows its error line, after the rows it printed; an answer that comes when another item is
## selected stays out of that item's pane; the key works with the focus on the left pane too; and a kill that was
## confirmed runs on to its own end when the screen ends first, while a read that runs then is ended with the screen.
## Offline: no operation of the real tooling is called, no process is signalled, and no session of this machine is read.
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
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:sessions:record none\ntable feed:sessions:record none\ntable view:sessions/*:record none\ntable feed:sessions/*:record none\nwall 2026-10-13 02:30 +0000\nsize 120 40\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
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
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigKills(){ ## how many times the kill operation was started, whatever its arguments
	LC_ALL=C grep -c -- '^--manager-session-kill' "$MANAGER_SCREEN_RIG/calls" || :
}
rigKillWords(){ ## the arguments of every start of the kill operation, each between brackets, a start a line
	LC_ALL=C grep -F -- '[--manager-session-kill]' "$MANAGER_SCREEN_RIG/words" || :
}
rigOthers(){ ## how many starts were neither the list of the sessions nor the kill
	LC_ALL=C grep -c -v -e '^--manager-session-list' -e '^--manager-session-kill' "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- the kill key asks first, and says exactly what will be killed --"
rigCase esc
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
turn
get on
cells onKeys 37 1 83
keys k
get asked
show d
cells askedLine 38 1 83
keys y e
get typing
cells typingLine 38 1 83
keys ESC
turn
get esc
said escLine
cells escKeys 37 1 83
RIGSCRIPT
rigAssert "a running session is selected, and the left pane names the kill key for it" "$( rigVal on.selected ) [$( rigVal onKeys )]" "$rigS1 [keys: k kill  l log]"
rigAssert "k opens the line to type in, and asks for the word"       "[$( rigVal asked.dialog )] [$( rigVal askedLine )] $( rigVal asked.cursor )" "[kill the session, 2 agents? type yes:|] [kill the session, 2 agents? type yes:] 38,39"
rigAssert "above the line stands what will be killed: the session by its name and its id" "[$( rigPane d 32 )][$( rigPane d 33 )]" "[ KILL the session daily of Monday][ session $rigS1]"
rigAssert "each agent that is alive, with its state and its own id"  "[$( rigPane d 34 )][$( rigPane d 35 )][$( rigPane d 36 )]" \
	"[ Its 2 live agents end the hard way: no closure runs, none is asked anything.][   magic-coordinator  running waiting  $rigS1][   magic-tester       running working  $rigR2]"
rigAssert "how many are left as they are, and how to back out"       "[$( rigPane d 37 )][$( rigPane d 38 )]" "[ 2 other agents are not alive on this host: they are left as they are.][ Type yes and Enter to kill. Esc, or anything else, kills nothing.]"
rigAssert "the pane of the session stays above it, and nothing spills" "[$( rigPane d 3 )] $( rigVal asked.spills )" "[ state     running] 0"
rigAssert "what is typed shows in the line"                          "[$( rigVal typing.dialog )] [$( rigVal typingLine )]" "[kill the session, 2 agents? type yes:|ye] [kill the session, 2 agents? type yes: ye]"
rigAssert "Esc closes the line: the bottom line is empty again, and the keys of the item are back" "[$( rigVal esc.dialog )] [$( rigVal esc.notice )] [$( rigVal escLine )] [$( rigVal escKeys )]" "[] [] [] [keys: k kill  l log]"
rigAssert "and no operation was called but the list"                 "$( rigKills ) $( rigOthers ) $( rigVal esc.calls ) [$( rigVal esc.reading )]" "0 0 0 []"

echo "-- the typed word kills the selected session, and the answer is shown --"
rigCase session
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN DOWN
copy $rigTmp/session/after.rows $rigTmp/session/rows
keys k y e s
get typed
keys ENTER
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
cells afterRow 4 85 119
cells afterKeys 37 1 83
RIGSCRIPT
rigAssert "until Enter nothing is called"                            "[$( rigVal typed.dialog )] [$( rigVal typed.reading )]" "[kill the session, 2 agents? type yes:|yes] []"
rigAssert "Enter on the word starts the kill, beside the screen"     "[$( rigVal asked.dialog )] $( rigVal asked.reading ) [$( rigVal askedLine )]" "[] action:kill:$rigS1 [kill asked of the tooling: the session daily of Monday]"
rigAssert "the operation is called once, with the id of that session and nothing more" "$( rigKills ) [$( rigKillWords )]" "1 [[--manager-session-kill][--session-id][$rigS1]]"
rigAssert "nothing goes to its standard input, and nothing else is called" "$( [ -e "$MANAGER_SCREEN_RIG/stdin.--manager-session-kill" ] && printf input || printf none ) $( rigOthers )" "none 0"
rigAssert "the bottom line counts what the operation answered"       "[$( rigVal answeredLine )]" "[kill: 1 ended, 1 killed, 1 was not running, 1 not signalled]"
rigAssert "the left pane shows the answer for each run: ended, killed, was not running" "[$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )][$( rigPane a 6 )]" \
	"[ the kill, answered 02:30:00:][   magic-coordinator  ended][   magic-tester       killed: it took KILL][   keeper-myx         was not running]"
rigAssert "and one that was not signalled, with why"                 "[$( rigPane a 7 )][$( rigPane a 8 )] $( rigVal answered.answer )" "[   magic-developer    not signalled: it has no id of its own][] 5"
rigAssert "then the list is read again"                              "$( rigCalled --manager-session-list )" 2
rigAssert "and shows the session as it is now, still selected, under the answer" "$( rigVal after.selected ) [$( rigVal afterRow )] [$( rigPane z 3 )][$( rigPane z 9 )]" \
	"$rigS1 [>daily of Monday          finished] [ the kill, answered 02:30:00:][ state     finished]"
rigAssert "it has nothing to kill any more: the pane names no kill key" "[$( rigVal afterKeys )]" "[keys: l log]"

echo "-- on an agent the kill takes the agent's own id, with --run --"
rigCase agent
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN ENTER DOWN DOWN
turn
get on
cells onKeys 37 1 83
keys k
get asked
show d
keys y e s ENTER
wait action 30
get answered
show a
said answeredLine
RIGSCRIPT
rigAssert "an agent that joined the session is selected"             "$( rigVal on.path ) $( rigVal on.selected ) [$( rigVal onKeys )]" "sessions/$rigS1 $rigR2 [keys: k kill  l log]"
rigAssert "the line asks for the word, naming the agent"             "[$( rigVal asked.dialog )]" "[kill the agent magic-tester? type yes:|]"
rigAssert "above it: that agent alone, by its own id, and of which session" "[$( rigPane d 34 )][$( rigPane d 35 )][$( rigPane d 36 )]" \
	"[ KILL the agent magic-tester alone][ run $rigR2, running working][ of the session daily of Monday ($rigS1)]"
rigAssert "and that the others run on"                               "[$( rigPane d 37 )][$( rigPane d 38 )]" "[ It ends the hard way: no closure runs, it is asked nothing. The others run on.][ Type yes and Enter to kill. Esc, or anything else, kills nothing.]"
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
keys y e s ENTER
wait action 30
get answered
said answeredLine
RIGSCRIPT
rigAssert "the founder is selected: its id is the id of its session" "$( rigVal on.path ) $( rigVal on.selected )" "sessions/$rigS1 $rigS1"
rigAssert "the line says that it alone is ended, not the session"    "[$( rigVal asked.dialog )] [$( rigPane d 33 )][$( rigPane d 34 )][$( rigPane d 37 )]" \
	"[kill the agent magic-coordinator? type yes:|] [ KILL the agent magic-coordinator alone][ run $rigS1, running waiting][ It is the founder: its id is its session's. It alone is ended, not the session.]"
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
said partLine
keys k Y E S ENTER
get capitals
keys k SPACE y e s ENTER
get spaceBefore
keys k y e s SPACE ENTER
get spaceAfter
keys k y e s s ENTER
get more
keys k n o ENTER
get no
keys k ENTER
get nothing
turn 3
get end
RIGSCRIPT
rigNothing="nothing was killed: the word typed was not yes"
rigAssert "a part of the word kills nothing, and the bottom line says so" "[$( rigVal part.dialog )] [$( rigVal part.notice )] [$( rigVal partLine )]" "[] [$rigNothing] [$rigNothing]"
rigAssert "neither do capitals, a space before it or after it, or a letter more" "[$( rigVal capitals.notice )][$( rigVal spaceBefore.notice )][$( rigVal spaceAfter.notice )][$( rigVal more.notice )]" "[$rigNothing][$rigNothing][$rigNothing][$rigNothing]"
rigAssert "nor another word, nor no word at all"                     "[$( rigVal no.notice )][$( rigVal nothing.notice )]" "[$rigNothing][$rigNothing]"
rigAssert "the operation was never called"                           "$( rigKills ) $( rigOthers ) $( rigVal end.calls ) [$( rigVal end.reading )]" "0 0 0 []"

echo "-- a row that cannot be killed says so, and nothing is asked --"
rigCase cannot
rigScript <<'RIGSCRIPT'
keys k
get section
keys ESC
keys ENTER
wait sessions 30
keys k
get up
keys ESC
keys DOWN k
get launch
keys ESC
keys DOWN DOWN
turn
get lone
cells loneKeys 37 1 83
keys k
get ended
keys ESC
keys UP ENTER DOWN DOWN DOWN
turn
get keeper
cells keeperKeys 37 1 83
keys k
get gone
keys ESC
keys DOWN k
get noId
keys ESC
turn 3
get end
RIGSCRIPT
rigHere="k: nothing to kill here: k kills a session or an agent"
rigAssert "on a section, and on the row that goes up, there is nothing to kill" "[$( rigVal section.dialogHolds )][$( rigVal up.dialogHolds )] [$( rigVal section.dialog )$( rigVal up.dialog )]" "[$rigHere][$rigHere] [message:ok|message:ok|]"
rigAssert "on Launch / Spawn there is nothing to kill, and no word is asked for" "$( rigVal launch.selected ) [$( rigVal launch.dialog )] [$( rigVal launch.dialogHolds )]" "launch [message:ok|] [$rigHere]"
rigAssert "a session that has ended names no kill key"               "$( rigVal lone.selected ) [$( rigVal loneKeys )]" "$rigS2 [keys: l log]"
rigAssert "and k on it says that no agent of it is alive, asking nothing" "[$( rigVal ended.dialog )] [$( rigVal ended.dialogHolds )]" "[message:ok|] [k: nothing to kill: no agent of this session is alive]"
rigAssert "an agent that has ended names no kill key, and k says that it is not alive" "$( rigVal keeper.selected ) [$( rigVal keeperKeys )] [$( rigVal gone.dialog )] [$( rigVal gone.dialogHolds )]" "$rigR3 [keys: l log] [message:ok|] [k: nothing to kill: this agent is not alive]"
rigAssert "neither is a run with no id of its own"                   "$( rigVal noId.selected ) [$( rigVal noId.dialog )] [$( rigVal noId.dialogHolds )]" "-3 [message:ok|] [k: nothing to kill: this agent is not alive]"
rigAssert "the operation was never called"                           "$( rigKills ) $( rigOthers ) $( rigVal end.calls )" "0 0 0"

echo "-- a kill that fails shows its error line --"
rigCase fail
echo fail > "$MANAGER_SCREEN_RIG/mode.--manager-session-kill"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
keys k y e s ENTER
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
echo fail-rows > "$MANAGER_SCREEN_RIG/mode.--manager-session-kill"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
keys k y e s ENTER
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
keys k y e s ENTER
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
keys y e s ENTER
wait action 30
get answered
RIGSCRIPT
rigAssert "with the focus on the left pane, k asks and the word kills" "$( rigVal asked.focus ) [$( rigVal asked.dialog )] $( rigKills ) [$( rigKillWords )]" "view [kill the session, 2 agents? type yes:|] 1 [[--manager-session-kill][--session-id][$rigS1]]"

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
keys k y e s ENTER
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
rigAssert "a read that runs when the screen ends is ended with it"   "$( rigVal asked.reading ) $( rigEnded --manager-session-list 20 )" "list:sessions 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN KILL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_KILL: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
