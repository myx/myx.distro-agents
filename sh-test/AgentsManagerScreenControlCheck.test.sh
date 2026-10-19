#!/usr/bin/env bash
## Behavioural check on what the manager screen (sh-lib/manager/AgentsManagerScreen.py) shows of the control thread of a
## session, and on its key `c`, run rather than read. The screen's own code runs through the stand-in terminal of
## the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a
## stand-in script (check-fixtures/manager-screen.tools.stub.sh), which notes each start, its arguments word for word
## and what came on its standard input, and prints the fixture kept for those very arguments: rows in the forms
## `--manager-session-list`, `--manager-session-read` and `--manager-session-control-start` print.
## Held: the three fields at the end of a `session` row come with the rows the screen already asks for, and no call
## more is made for them; in the list a session whose control thread reads `gone` carries the mark `x` ahead of its
## state, and one whose thread reads `alive` or `none` carries none; the section says how many carry it; the left
## pane of a session shows one line `control` under its state: whether the thread lives, and the state it stored
## with when that was set, each as it is, also where the stored state and the derived one differ; once the read of
## that one session has come, the pid of a thread that lives, and the stored state as that read has it; with a read
## that prints no `control` row, what the list said; the status line names `c Control` under a session that is not
## finished and whose thread does not live, and under no other, and the left pane has no `keys:` line of its own (F11.0); `c` on a session asks for no confirmation and calls
## `--manager-session-control-start --session-id <id>` once, with the id of that session and nothing on its
## standard input; the bottom line says the outcome in words from the row, started with its pid, alive already,
## not needed and not started each with the reason the row gives, a TAB and a backslash of it read back; the same
## words stand at the head of the left pane; then the list is read again, and the mark goes with the thread that
## lives now; a start that fails after its row keeps the words of that row in the bottom line, with the error line
## of the operation under them in the pane, and the row keeps its mark; one that fails with no row shows its error
## line; a row that is no session, a section, the row that goes up, `Launch (Start)` and an agent of a session,
## says that there is nothing to control, and nothing is called; `c` pressed again before the answer has come asks
## nothing a second time; the key works with the focus on the left pane too; and rows of before, a `session` row of
## eight fields and a read with no `control` row, still draw: no mark, `-` in the line `control`, and no error.
## Reconciled for F11.0: the pane's `keys:` line is gone (its keys are read from the status line, rigKeysNamed), and
## the spacer under `Launch (Start)` moves each session row of the list one line down; `a.rows` is taken to count
## no spacer.
## Offline: no operation of the real tooling is called, no process is started, and no session of this machine is read.
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
## This check names the operation that starts a control thread, and only its stand-in is ever called. It ends the
## control threads of its rig all the same, as every check that names that operation does: the guard of
## AgentsSessionControlStartCheck holds it to that, and none is found here.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the fixture that ends the control threads of a rig is missing: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenControlCheck )" || exit 1
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
## Five sessions, as the list prints them now, the three fields of the control thread at the end of each `session`
## row. `daily of Monday` runs, and its thread is gone. `weekly review` runs, and its thread lives. One lone run
## has ended in order: the state its thread stored is finished, and the thread left nothing. `far work` waits for
## an answer and never had a thread. `broken one` is finished, and its thread died while it ran: the state it
## stored is running still. Then the same five once the thread of the first was started.
rigS1=11111111-0000-4000-8000-000000000001 ; rigR2=a2a2a2a2-0000-4000-8000-0000000000a2 ; rigR3=a3a3a3a3-0000-4000-8000-0000000000a3
rigS2=22222222-0000-4000-8000-000000000002 ; rigS3=33333333-0000-4000-8000-000000000003
rigS4=44444444-0000-4000-8000-000000000004 ; rigS5=55555555-0000-4000-8000-000000000005
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
rigRunsS1(){
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting
	rigRow run "$rigS1" "$rigR2" magic-tester spawn-started running running 2026-10-12_17:05_+0000 - rig-host ws-rig working
	rigRow run "$rigS1" "$rigR3" keeper-myx spawn-succeeded no-process finished 2026-10-12_17:06_+0000 2026-10-12_18:00_+0000 rig-host ws-rig -
}
rigRunS2(){ rigRow run "$rigS2" "$rigS2" magic-architect spawn-started running running 2026-10-12_15:00_+0000 - rig-host ws-rig working ; }
rigOthers(){
	rigRow session "$rigS2" weekly_review running 2026-10-12_15:00_+0000 - 1 running=1 running 2026-10-12_15:01_+0000 alive
	rigRunS2
	rigRow session "$rigS3" - finished 2026-10-11_14:28_+0000 2026-10-11_14:51_+0000 1 finished=1 finished 2026-10-11_14:51_+0000 none
	rigRow run "$rigS3" "$rigS3" magic-devops spawn-succeeded no-process finished 2026-10-11_14:28_+0000 2026-10-11_14:51_+0000 rig-host ws-rig -
	rigRow session "$rigS4" far_work waiting 2026-10-12_12:00_+0000 - 1 finished=1 - - none
	rigRow run "$rigS4" "$rigS4" keeper-mel spawn-succeeded no-process finished 2026-10-12_12:00_+0000 2026-10-12_12:30_+0000 rig-host ws-rig -
	rigRow session "$rigS5" broken_one finished 2026-10-12_09:00_+0000 2026-10-12_09:50_+0000 1 finished=1 running 2026-10-12_09:40_+0000 gone
	rigRow run "$rigS5" "$rigS5" keeper-ae3 spawn-failed no-process finished 2026-10-12_09:00_+0000 2026-10-12_09:50_+0000 rig-host ws-rig -
	rigRow counters 2 0 2 1 3 0.42
}
{ rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 3 running=2,finished=1 running 2026-10-12_16:58_+0000 gone ; rigRunsS1 ; rigOthers ; } > "$rigF/rows"
{ rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 3 running=2,finished=1 running 2026-10-12_16:58_+0000 alive ; rigRunsS1 ; rigOthers ; } > "$rigF/after.rows"
## The rows of before: a `session` row of eight fields.
{ rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 3 running=2,finished=1 ; rigRunsS1 ; rigRow counters 1 0 1 1 3 0.42 ; } > "$rigF/old.rows"
## The read of one session. Of the first it prints no `control` row, as a read of before. Of the second it prints
## one, with the pid of the thread and a stored state that is newer than the one the list had.
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 3 running=2,finished=1
	rigRow dispatch "$rigS1" record magic-coordinator magic-coordinator.daily.routine.md dispatch-20261012T165700Z-daily-1 C0RIG:1791000000.000100 C0TRK:1791000000.000200 'The daily of Monday.'
	rigRunsS1
} > "$rigF/rows.--manager-session-read --session-id $rigS1"
{
	rigRow session "$rigS2" weekly_review running 2026-10-12_15:00_+0000 - 1 running=1 member-dead 2026-10-12_17:30_+0000 alive
	rigRow dispatch "$rigS2" record magic-architect - - - - 'The review of the week.'
	rigRow control "$rigS2" member-dead 2026-10-12_17:30_+0000 alive 4242
	rigRunS2
} > "$rigF/rows.--manager-session-read --session-id $rigS2"
## What the start of a control thread prints, by the session it is asked for: one `control` row.
rigStart="--manager-session-control-start --session-id"
rigRow control "$rigS1" started 4321 - > "$rigF/rows.$rigStart $rigS1"
rigRow control "$rigS2" alive 4242 - > "$rigF/rows.$rigStart $rigS2"
rigRow control "$rigS3" not-needed - 'every run of it has closed its record, and a finished session needs no thread' > "$rigF/rows.$rigStart $rigS3"
rigRow control "$rigS1" not-started - 'its open records are runs of another host (far\\host), which cannot be watched\tfrom here' > "$rigF/not-started.rows"
rigRow control "$rigS1" started 4321 'it had not taken the lock of its session after 10 seconds, and is a process still' > "$rigF/slow.rows"
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
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; the reads of one item are taken out of the table, but for the facts of a session where rigReads says view; what it printed is kept in rigOut
	local scriptView='table view:sessions:record none'
	[ "${rigReads:-}" != view ] || scriptView='# the facts of a session are read'
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\n%s\ntable feed:sessions:record none\ntable view:sessions/*:record none\ntable feed:sessions/*:record none\nwall 2026-10-13 02:30 +0000\nsize 120 40\nroot sessions\n' "$rigTools" "$scriptView" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigKeysNamed(){ ## cells name -- the row's own keys k and c as the status line names them, in the words the pane's
	## `keys:` line had before F11.0 removed it; `PANE-KEYS-LINE` where the pane still has a line of its own
	local namedSaid namedWords=""
	if rigVal "$1" | LC_ALL=C grep -q '^keys:' ; then printf 'PANE-KEYS-LINE' ; return 0 ; fi
	namedSaid="$( rigVal "${1}Status" ) "
	case "$namedSaid" in *' k Kill '*) namedWords="k kill" ;; esac
	case "$namedSaid" in *' c Control '*) namedWords="${namedWords:+$namedWords  }c control" ;; esac
	[ -z "$namedWords" ] || printf 'keys: %s' "$namedWords"
}
rigPane(){ ## tag, line counted from 1 -- the left pane's part of that line of the screen, without the spaces at its end
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/^┌\(─\)* \(.*\) \(─\)*┐.*$/ \2/' -e 's/^╔\(═\)* \(.*\) \(═\)*╗.*$/ \2/' -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' -e 's/  *$//'
}
rigPaneHolds(){ ## tag, text -- how many lines of the left pane of that screen hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' | LC_ALL=C grep -c -F -- "$2" || :
}
rigListRow(){ ## what a row shows as, its tail -- that row of the list, a session that can be opened, as it is drawn in its 34 cells with the mark of a folder at its right edge, not selected
	printf ' %-*s %s ►' "$(( 30 - ${#2} ))" "$1" "$2"
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigStarts(){ ## how many times the start of a control thread was called, whatever its arguments
	LC_ALL=C grep -c -- '^--manager-session-control-start' "$MANAGER_SCREEN_RIG/calls" || :
}
rigStartWords(){ ## the arguments of every such call, each between brackets, a call a line
	LC_ALL=C grep -F -- '[--manager-session-control-start]' "$MANAGER_SCREEN_RIG/words" || :
}
rigElse(){ ## how many starts were neither the list of the sessions, nor the read of one, nor the start of a control thread. The list of the locations, which every start of the screen reads, is not counted.
	LC_ALL=C grep -c -v -e '^--manager-session-list' -e '^--manager-session-read' -e '^--manager-session-control-start' -e '^--manager-place-list$' "$MANAGER_SCREEN_RIG/calls" || :
}
rigStored="stored running, set 2026-10-12 16:58 +0000 (9h ago)"

echo "-- the list marks a session whose control thread is gone --"
rigCase list
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
turn 3
get a
cells row3 5 85 119
cells row4 6 85 119
cells row5 7 85 119
cells row6 8 85 119
cells row7 9 85 119
show u
RIGSCRIPT
rigAssert "the screen asked for the list of the sessions, once, and for nothing more" "$( rigCalled --manager-session-list ) $( rigStarts ) $( rigElse ) $( rigVal a.rows )" "1 0 0 7"
rigAssert "a running session whose thread is gone carries the mark ahead of its state" "[$( rigVal row3 )]" "[$( rigListRow "daily of Monday" "x running" )]"
rigAssert "one whose thread lives carries none"                      "[$( rigVal row4 )]" "[$( rigListRow "weekly review" "running" )]"
rigAssert "nor does one that ended in order, nor one that never had a thread" "[$( rigVal row5 )][$( rigVal row6 )]" "[$( rigListRow "magic-devops 33333333" "finished" )][$( rigListRow "far work" "waiting" )]"
rigAssert "a finished session whose thread died carries the mark too" "[$( rigVal row7 )]" "[$( rigListRow "broken one" "x finished" )]"
rigAssert "on the row that goes up the pane is every session as a table, nothing above it, the state of each whose thread is gone with its mark" "[$( rigPane u 3 )] $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^u|' | LC_ALL=C sed 's/│║.*//' | LC_ALL=C grep -c -E ' x (running|waiting|finished|unclosed) ' )" "[  SESSION               STATE      AGE AGENTS TOKENS MEMBERS] 2"

echo "-- the left pane of a session says whether its control thread lives, and the state it stored --"
rigCase pane
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
turn
get s1
show s1
cells keys1 37 1 83
cells keys1Status 39 0 120
keys DOWN
turn
show s2
cells keys2 37 1 83
cells keys2Status 39 0 120
keys DOWN
turn
show s3
cells keys3 37 1 83
cells keys3Status 39 0 120
keys DOWN
turn
show s4
cells keys4 37 1 83
cells keys4Status 39 0 120
keys DOWN
turn
get s5
show s5
cells keys5 37 1 83
cells keys5Status 39 0 120
RIGSCRIPT
rigAssert "a thread that is gone: the line control stands under the state, with the state the thread stored and when" "$( rigVal s1.selected ) [$( rigPane s1 4 )][$( rigPane s1 5 )][$( rigPane s1 6 )]" \
	"$rigS1 [  state    running][  control  gone; $rigStored][  started  2026-10-12 16:57 +0000 (9h ago)]"
rigAssert "and the pane names the key that starts it again"          "[$( rigKeysNamed keys1 )]" "[keys: k kill  c control]"
rigAssert "a thread that lives: the pane says so, and names no such key" "[$( rigPane s2 5 )] [$( rigKeysNamed keys2 )]" "[  control  alive; stored running, set 2026-10-12 15:01 +0000 (11h ago)] [keys: k kill]"
rigAssert "a session that ended in order: no thread, the stored state finished, and no key" "[$( rigPane s3 4 )][$( rigPane s3 5 )] [$( rigKeysNamed keys3 )]" "[  state    finished][  control  none; stored finished, set 2026-10-11 14:51 +0000 (35h ago)] []"
rigAssert "a session that is not finished and never had a thread: nothing stored, and the key is named" "[$( rigPane s4 4 )][$( rigPane s4 5 )] [$( rigKeysNamed keys4 )]" "[  state    waiting][  control  none; stored -] [keys: k kill  c control]"
rigAssert "where the stored state and the derived one differ, each is shown as it is" "$( rigVal s5.selected ) [$( rigPane s5 4 )][$( rigPane s5 5 )]" "$rigS5 [  state    finished][  control  gone; stored running, set 2026-10-12 09:40 +0000 (16h ago)]"
rigAssert "a finished session names no such key, whatever its thread" "[$( rigKeysNamed keys5 )]" "[]"
rigAssert "all of it came with the one list: nothing more was called" "$( rigCalled --manager-session-list ) $( rigStarts ) $( rigElse ) $( rigVal s5.spills )" "1 0 0 0"

echo "-- the read of one session adds the pid of a thread that lives --"
rigCase read
rigReads=view
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
wait view 30
turn
show s1
keys DOWN
wait view 30
turn
get s2
show s2
RIGSCRIPT
rigReads=""
rigAssert "a read that prints no control row leaves what the list said" "$( rigCalled "--manager-session-read --session-id $rigS1" ) [$( rigPane s1 5 )] $( rigPaneHolds s1 'The daily of Monday.' )" "1 [  control  gone; $rigStored] 1"
rigAssert "a read with its control row: the pid of the thread, and the stored state as that read has it" "$( rigVal s2.selected ) $( rigCalled "--manager-session-read --session-id $rigS2" ) [$( rigPane s2 4 )][$( rigPane s2 5 )]" \
	"$rigS2 1 [  state    running][  control  alive, pid 4242; stored member-dead, set 2026-10-12 17:30 +0000 (9h ago)]"

echo "-- c starts the control thread of the selected session, and asks nothing first --"
rigCase start
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN DOWN
copy $rigTmp/start/after.rows $rigTmp/start/rows
keys c
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
cells afterKeysStatus 39 0 120
RIGSCRIPT
rigAssert "c opens no line to type in: the start is asked of the tooling at once" "[$( rigVal asked.dialog )] $( rigVal asked.reading ) [$( rigVal askedLine )]" "[] action:control:$rigS1 [control thread asked of the tooling: the session daily of Monday]"
rigAssert "the operation is called once, with the id of that session and nothing more" "$( rigStarts ) [$( rigStartWords )]" "1 [[--manager-session-control-start][--session-id][$rigS1]]"
rigAssert "nothing goes to its standard input, and nothing else is called" "$( [ -e "$MANAGER_SCREEN_RIG/stdin.--manager-session-control-start" ] && printf input || printf none ) $( rigElse )" "none 0"
rigAssert "the bottom line says the outcome in words: started, with the pid" "[$( rigVal answeredLine )]" "[control: started, pid 4321]"
rigAssert "the same stands at the head of the left pane"             "[$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )] $( rigVal answered.answer )" "[ the control start, answered 02:30:00:][   started, pid 4321][] 2"
rigAssert "then the list is read again"                              "$( rigCalled --manager-session-list )" 2
rigAssert "and shows the session as it is now, still selected: the mark is gone, and the thread lives" "$( rigVal after.selected ) [$( rigVal afterRow )] [$( rigPane z 7 )][$( rigPane z 8 )]" \
	"$rigS1 [>$( rigListRow "daily of Monday" "running" | LC_ALL=C cut -c2- )] [  state    running][  control  alive; $rigStored]"
rigAssert "the pane names the key no more"                           "[$( rigKeysNamed afterKeys )]" "[keys: k kill]"

echo "-- the other outcomes, each in words from its row --"
rigCase outcomes
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN DOWN
keys c
wait action 30
get alive
show al
wait sessions 30
keys DOWN
keys c
wait action 30
get needless
show nn
wait sessions 30
turn
get end
RIGSCRIPT
rigAssert "a thread that lives already: the operation is asked all the same, and says so with its pid" "$( rigCalled "$rigStart $rigS2" ) [$( rigVal alive.notice )] [$( rigPane al 3 )][$( rigPane al 4 )]" \
	"1 [control: alive already, pid 4242] [ the control start, answered 02:30:00:][   alive already, pid 4242]"
rigAssert "a session that needs none: not needed, with the reason the row gives" "$( rigCalled "$rigStart $rigS3" ) [$( rigVal needless.notice )]" \
	"1 [control: not needed: every run of it has closed its record, and a finished session needs no thread]"
rigAssert "the reason is broken to the pane, and nothing of it is lost" "[$( rigPane nn 3 )] $( rigPaneHolds nn '   not needed: every run of it has closed its record, and a finished session' ) $( rigPaneHolds nn 'no thread' )" "[ the control start, answered 02:30:00:] 1 1"
rigAssert "each was called once, no line was opened, and each answer was followed by a read of the list" "$( rigStarts ) [$( rigVal end.dialog )] $( rigCalled --manager-session-list ) $( rigElse )" "2 [] 3 0"
rigCase slow
cp "$MANAGER_SCREEN_RIG/slow.rows" "$MANAGER_SCREEN_RIG/rows.$rigStart $rigS1"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
keys c
wait action 30
get slow
RIGSCRIPT
rigAssert "a start with words of its own: they follow the pid"       "[$( rigVal slow.notice )]" "[control: started, pid 4321: it had not taken the lock of its session after 10 seconds, and is a process still]"

echo "-- a start that could not be made says why, and the row keeps its mark --"
rigCase refused
cp "$MANAGER_SCREEN_RIG/not-started.rows" "$MANAGER_SCREEN_RIG/rows.$rigStart $rigS1"
echo fail-rows > "$MANAGER_SCREEN_RIG/mode.--manager-session-control-start"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
keys c
wait action 30
get refused
show f
keys ENTER
wait sessions 30
turn
get after
cells afterRow 5 85 119
cells afterKeys 37 1 83
cells afterKeysStatus 39 0 120
RIGSCRIPT
rigAssert "not started, with the reason of the row first in the box, its backslash and its TAB read back" "[$( rigVal refused.dialogTitle )] [$( rigVal refused.dialogHolds )]" "[The control start failed] [control: not started: its open records are runs of another host (far\\host), which cannot be watched from here / operation: --manager-session-control-start --session-id $rigS1 / rig-tools: ⛔ ERROR: the rig said fail, after its rows]"
rigAssert "the pane says that the start failed, then the row, then the error line of the operation" "[$( rigPane f 3 )] $( rigPaneHolds f '   not started: its open records are runs of another host (far\host), which' ) [$( rigPane f 6 )][$( rigPane f 7 )]" \
	"[ the control start failed, answered 02:30:00:] 1 [ rig-tools: ⛔ ERROR: the rig said fail, after its rows][]"
rigAssert "the list is read again all the same: the row keeps its mark, and the pane its key" "$( rigCalled --manager-session-list ) $( rigVal after.selected ) [$( rigVal afterRow )] [$( rigKeysNamed afterKeys )]" \
	"2 $rigS1 [>$( rigListRow "daily of Monday" "x running" | LC_ALL=C cut -c2- )] [keys: k kill  c control]"
rigCase fail
echo fail > "$MANAGER_SCREEN_RIG/mode.--manager-session-control-start"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
keys c
wait action 30
get failed
show f
keys ENTER
wait sessions 30
turn
get after
cells afterRow 5 85 119
RIGSCRIPT
rigAssert "a start that ends with status 1 and one error line, and no row: what it wrote stands in a box, whole" "[$( rigVal failed.dialogTitle )] [$( rigVal failed.dialogHolds )]" "[The control start failed] [operation: --manager-session-control-start --session-id $rigS1 / rig-tools: a line that is no error / rig-tools: ⛔ ERROR: the rig said fail]"
rigAssert "and in the left pane, which says that the start failed"   "[$( rigPane f 3 )][$( rigPane f 4 )][$( rigPane f 5 )]" "[ the control start failed, answered 02:30:00:][ rig-tools: ⛔ ERROR: the rig said fail][]"
rigAssert "the row keeps its mark"                                   "$( rigCalled --manager-session-list ) [$( rigVal afterRow )] [$( rigVal after.failed )]" "2 [>$( rigListRow "daily of Monday" "x running" | LC_ALL=C cut -c2- )] []"

echo "-- a row that is no session says so, and nothing is called --"
rigCase cannot
rigScript <<'RIGSCRIPT'
keys c
get section
turn
keys ENTER
wait sessions 30
keys c
get up
turn
keys DOWN c
get launch
turn
keys DOWN ENTER DOWN
turn
get agent
cells agentKeys 37 1 83
cells agentKeysStatus 39 0 120
keys c
get onAgent
turn
turn 3
get end
RIGSCRIPT
rigHere="Control thread: for a session, not for what is selected"
rigAssert "on a section c is no key of the view; on the row that goes up the status line says what c is for, and no box opens" "[$( rigVal section.notice )][$( rigVal up.notice )] [$( rigVal section.dialog )$( rigVal up.dialog )]" "[][$rigHere] []"
rigAssert "on Launch (Start) there is nothing to control"            "$( rigVal launch.selected ) [$( rigVal launch.notice )]" "launch [$rigHere]"
rigAssert "an agent of a session names no such key, and c on it says the same: the thread is its session's" "$( rigVal agent.path ) $( rigVal agent.selected ) [$( rigKeysNamed agentKeys )] [$( rigVal onAgent.notice )]" "sessions/$rigS1 $rigS1 [keys: k kill] [$rigHere]"
rigAssert "the operation was never called"                           "$( rigStarts ) $( rigElse ) $( rigVal end.calls ) [$( rigVal end.reading )]" "0 0 0 []"

echo "-- c pressed again before the answer has come asks nothing a second time --"
rigCase twice
echo "sleep 1" > "$MANAGER_SCREEN_RIG/mode.--manager-session-control-start"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
keys c c
get twice
keys ESC
wait action 30
get once
keys c
wait action 30
get again
RIGSCRIPT
rigAssert "the second c says that the start is asked for already"   "[$( rigVal twice.dialogHolds )] $( rigVal twice.reading )" "[c: the control thread of this session is asked for already, and its answer has not come] action:control:$rigS1"
rigAssert "one call was made, and its answer is shown"               "[$( rigVal once.notice )]" "[control: started, pid 4321]"
rigAssert "once the answer has come, c asks again"                   "$( rigStarts ) [$( rigVal again.notice )]" "2 [control: started, pid 4321]"

echo "-- the key works with the focus on the left pane too --"
rigCase focus
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN TAB
keys c
get asked
wait action 30
get answered
RIGSCRIPT
rigAssert "with the focus on the left pane, c asks and the answer comes" "$( rigVal asked.focus ) $( rigVal asked.reading ) $( rigStarts ) [$( rigVal answered.notice )]" "view action:control:$rigS1 1 [control: started, pid 4321]"

echo "-- rows of before still draw --"
rigCase old
cp "$MANAGER_SCREEN_RIG/old.rows" "$MANAGER_SCREEN_RIG/rows"
rigReads=view
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
get a
cells row3 5 85 119
show u
keys DOWN DOWN
turn
show early
wait view 30
turn
get s
show s
cells sKeys 37 1 83
cells sKeysStatus 39 0 120
keys c
wait action 30
get asked
RIGSCRIPT
rigReads=""
rigAssert "a session row of eight fields draws as it did: no mark, and the section says nothing of a thread" "$( rigVal a.rows ) [$( rigVal row3 )] $( rigPaneHolds u 'control thread' )" "3 [$( rigListRow "daily of Monday" "running" )] 0"
rigAssert "the line control says - of what the row does not tell, before the read of the session and after it, which prints no control row" "[$( rigPane early 4 )][$( rigPane early 5 )] [$( rigPane s 4 )][$( rigPane s 5 )] $( rigPaneHolds s 'The daily of Monday.' )" \
	"[  state    running][  control  -] [  state    running][  control  -] 1"
rigAssert "the pane names no key for what it cannot tell, and nothing failed" "[$( rigKeysNamed sKeys )] [$( rigVal s.failed )] $( rigVal s.spills ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -e 'DRIVER-FAILED' -e 'Traceback' )" "[keys: k kill] [] 0 0"
rigAssert "c still asks the operation, whose answer it is"           "$( rigStarts ) [$( rigVal asked.notice )]" "1 [control: started, pid 4321]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN CONTROL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_CONTROL: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
