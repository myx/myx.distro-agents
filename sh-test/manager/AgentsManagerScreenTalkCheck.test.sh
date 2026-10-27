#!/usr/bin/env bash
## Behavioural check on what the manager screen says to a session (F11.6 of the refactorings epic), run rather than read: a send-message key on a session
## and on a participant (`M`), and magic-coordinator joined into a session that has finished, waits or is stuck (`J`). The screen's own code runs through
## the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which notes each start and what came on its standard input, and prints the fixture.
## Held (F11.6: "In a session, a send-message key sends to the session or to a participant, through the same file and Slack system. For each active session,
## a command posts into its session thread, or into the abstract session communications channel. For a session whose participants have all finished, or that
## is waiting or stuck, a command joins `magic-coordinator` into that session, with a task to assess it, unblock it interactively, and report."):
##   1. `M` on a session of the list opens the dialog of a message, titled by the session, whose list offers the whole session first and then each participant
##      once; Send calls `--manager-session-message --session-id <id>` once, with the message alone on the standard input and no word of it among the arguments
##   2. a participant chosen in the list is the one `--to <member>` names; on the row of a participant the list stands on that participant at first
##   3. an empty message is sent never, and says so; Esc and Cancel send nothing
##   4. what the operation printed is said: left for the writer to send into the thread, or recorded in the chat file of a session that has no thread
##   5. `J` asks first, naming the session and what the join does; its OK calls `--manager-session-join --session-id <id>` once, Cancel and Esc nothing; it is
##      offered for a session that has finished, one that waits and one that is stuck, and on one that runs the status line says why not and nothing is called
##   6. both keys are named by the status line where they act, and stand in the menu of the session
## Offline: no operation of the real tooling is called.
set -u
## The runner gives every test a team rig as the default workspace mode (AgentsRunTests.sh); a run by hand takes the same default, so the result is the same either way.
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
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
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenTalkCheck )" || exit 1
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
rigRow(){ local rowText="$1" ; shift ; while [ $# -gt 0 ] ; do rowText="$rowText"$'\t'"$1" ; shift ; done ; printf '%s\n' "$rowText" ; }
## The sessions: one that runs, one that is stuck (an open record, nothing alive), one that waits, and one that has finished, each with its runs.
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow session s-run run-session running 2026-10-13_10:00_+0000 - 1 running=1 - - none 10
	rigRow run s-run r-run keeper-rig spawn-started running running 2026-10-13_10:00_+0000 - rig ws working
	rigRow session s-stuck stuck-session unclosed 2026-10-13_09:00_+0000 - 2 unclosed=2 - - gone 10
	rigRow run s-stuck r-st1 keeper-rig spawn-started no-process unclosed 2026-10-13_09:00_+0000 - rig ws -
	rigRow run s-stuck r-st2 keeper-two spawn-started no-process unclosed 2026-10-13_09:01_+0000 - rig ws -
	rigRow session s-wait wait-session waiting 2026-10-13_08:00_+0000 - 1 finished=1 - - none 10
	rigRow run s-wait r-wa keeper-rig spawn-succeeded no finished 2026-10-13_08:00_+0000 2026-10-13_08:30_+0000 rig ws -
	rigRow session s-fin fin-session finished 2026-10-12_08:00_+0000 2026-10-12_09:00_+0000 2 finished=2 - - none 10
	rigRow run s-fin r-fi1 keeper-rig spawn-succeeded no finished 2026-10-12_08:00_+0000 2026-10-12_08:30_+0000 rig ws -
	rigRow run s-fin r-fi2 magic-coordinator spawn-succeeded no finished 2026-10-12_08:05_+0000 2026-10-12_09:00_+0000 rig ws -
	rigRow counters 1 0 1 0 0 0.42 rig
} > "$rigF/rows.--manager-session-list"
rigRow counters 0 0 0 0 0 0.42 > "$rigF/rows"
rigRow message s-stuck user-rig all thread m.msg > "$rigF/rows.--manager-session-message --session-id s-stuck"
rigRow message s-stuck user-rig keeper-two thread m.msg > "$rigF/rows.--manager-session-message --session-id s-stuck --to keeper-two"
rigRow message s-stuck user-rig keeper-rig chat-file 3 > "$rigF/rows.--manager-session-message --session-id s-stuck --to keeper-rig"
rigRow join s-stuck magic-coordinator dispatch-rig.md > "$rigF/rows.--manager-session-join --session-id s-stuck"
rigRow join s-fin magic-coordinator dispatch-rig2.md > "$rigF/rows.--manager-session-join --session-id s-fin"
rigRow join s-wait magic-coordinator dispatch-rig3.md > "$rigF/rows.--manager-session-join --session-id s-wait"
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls" ; : > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize %s\nroot active-sessions\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1 ; }
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigCalls(){ ## how many starts of the operations that talk
	LC_ALL=C grep -c -E '^--manager-session-(message|join) ' "$MANAGER_SCREEN_RIG/calls" || :
}
rigInput(){ ## the standard input the stand-in was given for an operation, its end of line left out
	LC_ALL=C tr -d '\n' < "$MANAGER_SCREEN_RIG/stdin.$1" 2> /dev/null || :
}
rigScreenHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}

echo "-- 1. M on a session: the dialog, and what Send calls --"
rigCase message
rigScript <<'RIGSCRIPT'
turn
wait list 30
keys ENTER
turn
wait list 30
turn
rowids ids
keys DOWN DOWN
turn
get row
keys M
turn
get open
show open
keys x y z TAB
get typed
keys ENTER
turn
wait action 30
turn 2
get sent
RIGSCRIPT
rigAssert "the list of the sessions that are not finished, in the order of the operation" "$( rigVal ids )" ".. s-run s-stuck s-wait"
rigAssert "the row the key was pressed on is the stuck session" "$( rigVal row.selected )" "s-stuck"
rigAssert "M opens the dialog of a message, titled by the session; its list offers the whole session and each participant once, the whole session chosen" \
	"$( rigVal open.dialogTitle ) / $( rigVal open.dialog )" "Message: stuck-session / talk:words|"
rigAssert "Send calls the operation once with the session alone, and the message is on its standard input and in no word of the call" \
	"$( rigCalled '--manager-session-message --session-id s-stuck' ) / [$( rigInput --manager-session-message )] / $( LC_ALL=C grep -c -F -- 'xyz' "$MANAGER_SCREEN_RIG/calls" || : )" "1 / [xyz] / 0"
rigAssert "the dialog is closed once sent" "[$( rigVal sent.dialog )]" "[]"

echo "-- 2. a participant --"
rigCase toone
rigScript <<'RIGSCRIPT'
turn
wait list 30
keys ENTER
turn
wait list 30
turn
keys DOWN DOWN
turn
keys M
turn
keys BACKTAB DOWN DOWN
get chosen
keys TAB
keys h i
keys TAB
keys ENTER
turn
wait action 30
turn 2
get sent
RIGSCRIPT
rigAssert "a participant chosen in the list is the one --to names, once, after the session; the message alone is the standard input" \
	"$( rigVal chosen.dialog ) / $( rigCalled '--manager-session-message --session-id s-stuck --to keeper-two' ) / [$( rigInput --manager-session-message )] / $( rigCalls )" "talk:who|keeper-two / 1 / [hi] / 1"
rigCase onrun
rigScript <<'RIGSCRIPT'
turn
wait list 30
keys ENTER
turn
wait list 30
turn
keys DOWN DOWN
turn
keys ENTER
wait list 30
turn
rowids kids
keys DOWN DOWN DOWN DOWN DOWN
turn
get row
keys M
turn
get open
RIGSCRIPT
rigAssert "inside the session, on the row of a participant, the dialog is for the session and the list stands on that participant" \
	"$( rigVal kids ) / $( rigVal open.dialogTitle )" ".. r-st1 r-st2 / Message: stuck-session"

echo "-- 3. nothing is sent that is empty, or after Esc --"
rigCase empty
rigScript <<'RIGSCRIPT'
turn
wait list 30
keys ENTER
turn
wait list 30
turn
keys DOWN DOWN
turn
keys M
turn
keys TAB ENTER
turn
get empty
keys ESC
turn
get closed
RIGSCRIPT
rigAssert "an empty message presses nothing: no call, and the dialog stays and says the message is empty" "$( rigVal empty.dialog | LC_ALL=C cut -d'|' -f1 ) / $( rigVal empty.dialogSays ) / $( rigCalls )" "talk:words / nothing is sent: the message is empty / 0"
rigAssert "Esc closes it and sends nothing" "[$( rigVal closed.dialog )] $( rigCalls )" "[] 0"

echo "-- 4. what the operation answered --"
rigCase answered
rigScript <<'RIGSCRIPT'
turn
wait list 30
keys ENTER
turn
wait list 30
turn
keys DOWN DOWN
turn
keys M
turn
keys x TAB ENTER
turn
wait action 30
turn 2
get said
RIGSCRIPT
rigAssert "a message left for the writer is said as that, in the status line, with the sender and the session" "$( rigVal said.notice )" "message left for stuck-session: the writer sends it into the thread as user-rig"

echo "-- 5. J --"
rigCase join
rigScript <<'RIGSCRIPT'
turn
wait list 30
keys ENTER
turn
wait list 30
turn
keys DOWN DOWN
turn
keys J
turn
get open
keys ENTER
turn
wait action 30
turn 2
get done
RIGSCRIPT
rigAssert "J on a stuck session asks first, naming it; OK calls the operation once, and the box is closed" \
	"$( rigVal open.dialogTitle ) / $( rigCalled '--manager-session-join --session-id s-stuck' ) / [$( rigVal done.dialog )]" "Join: stuck-session / 1 / []"
rigCase joincancel
rigScript <<'RIGSCRIPT'
turn
wait list 30
keys ENTER
turn
wait list 30
turn
keys DOWN DOWN
turn
keys J
turn
keys ESC
turn
get esc
RIGSCRIPT
rigAssert "Esc calls nothing" "[$( rigVal esc.dialog )] $( rigCalls )" "[] 0"
rigCase joinwait
rigScript <<'RIGSCRIPT'
turn
wait list 30
keys ENTER
turn
wait list 30
turn
keys DOWN DOWN DOWN
turn
keys J
turn
keys ENTER
turn
wait action 30
turn 2
get done
RIGSCRIPT
rigAssert "and on a session that waits" "$( rigCalled '--manager-session-join --session-id s-wait' )" "1"
rigCase joinrun
rigScript <<'RIGSCRIPT'
turn
wait list 30
keys ENTER
turn
wait list 30
turn
keys DOWN
turn
keys J
turn
get run
RIGSCRIPT
rigAssert "on a session that runs the key asks first too (sketch 5.4: any session): its box opens, and nothing is called until OK" "[$( rigVal run.dialog )] [$( rigVal run.notice )] $( rigCalls )" "[join:ok|] [] 0"
rigCase joinfin
rigScript <<'RIGSCRIPT'
root closed-sessions
turn
wait list 30
keys ENTER
turn
wait list 30
turn
keys DOWN
turn
keys J
turn
keys ENTER
turn
wait action 30
turn 2
get done
RIGSCRIPT
rigAssert "and on a session that has finished, from the list of the closed ones" "$( rigCalled '--manager-session-join --session-id s-fin' )" "1"

echo "-- 6. the status line and the menu --"
rigCase named
rigScript <<'RIGSCRIPT'
turn
wait list 30
keys ENTER
turn
wait list 30
turn
keys DOWN DOWN
turn
get a
show a
keys m RIGHT
turn
show b
RIGSCRIPT
rigAssert "the status line names the keys where they act" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^a|' | LC_ALL=C tail -1 | LC_ALL=C grep -c -F -e 'M Message' -e 'J Join' )" "1"
rigAssert "and the menu of the session offers both" "$( rigScreenHolds b 'Message' ) $( rigScreenHolds b 'Join the coordinator' )" "1 1"

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ MANAGER SCREEN TALK CHECK FAILED: %d of %d assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_TALK: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
