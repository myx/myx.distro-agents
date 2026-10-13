#!/usr/bin/env bash
## Behavioural check on the left pane of a session and of an agent in the manager screen
## (sh-lib/AgentsManagerScreen.py), run rather than read. The screen's own code runs through the stand-in terminal of
## the driver (check-fixtures/manager-screen.driver.test.py), and where it would call the dispatcher it calls a
## stand-in script (check-fixtures/manager-screen.tools.test.sh), which notes each start and prints the fixture kept
## for those very arguments: rows in the forms `--manager-session-list`, `--manager-session-read` and
## `--manager-session-transcript-read` print. The time and the time zone are the case's own.
## Held: a selected session is read by its id, its facts and its lines each as a call of its own, and only while
## it is selected; the head of the pane, which does not scroll, shows its state, its dispatch (what it was started
## for, by whom, the routine and the item), its threads, and one line for each participant with its state; under
## it stands the feed of all its members, the newest at the bottom and in view, each line with its time, its
## member and its text with its emoji, a long one broken under itself, the session log of a run with no transcript
## under a line that names that run, and the last head line says where the lines come from; a selected agent is
## read with --run, the founder too, whose id is its session's: its status, what it waits on, its open asks, its
## model and token counts, its last milestone and its marks, then its own lines only; a run with no transcript
## shows its session log and says so; a run with no id of its own is read by nothing; moving the selection replaces
## the pane, and an answer that comes for an item that is no longer selected is dropped; new lines come into view
## at the end; a pane that was scrolled up stays on the line it showed, and follows again once it is scrolled to
## its end; `l` switches the pane to the raw log of the agent, or of every run of a session, and back, and another
## item shows its feed again; the left pane names the keys of the selected item; a small pane keeps its head
## to half of itself; and the reads of one item start only once the selection has rested on it for a third of a
## second: a selection that runs over a row starts none for it, and the screen waits for its next key no longer
## than that rest still lasts; and an item that is selected again, before the period of its last read has passed,
## is read again and shows its lines.
## And the rows of the control thread change nothing else the pane shows: a `session` row with three more fields at
## its end -- the state the control thread of a session stored, its date, whether that thread lives -- and a
## `control` row after the `dispatch` row of a read. Without them the line `control` of a session says `-`, with
## them what they tell; every other line of the pane of a session and of an agent is drawn cell for cell as before.
## Offline: no operation of the real tooling is called, and no session of this machine is read.
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
rigTmp="$( mktemp -d -t AgentsManagerScreenPaneCheck )" || exit 1
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
## One session that runs, `daily of Monday`, with four runs: its founder, whose id is the session's, which waits;
## a tester that works; a keeper that has ended, was dismissed and has no transcript; and a run with no id of its
## own. And one lone run. What each read prints of them is kept under the arguments of that read.
rigS1=11111111-0000-4000-8000-000000000001 ; rigR2=a2a2a2a2-0000-4000-8000-0000000000a2 ; rigR3=a3a3a3a3-0000-4000-8000-0000000000a3
rigS2=22222222-0000-4000-8000-000000000002
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
rigSessionS1(){ rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 4 running=2,finished=2 ; }
rigDispatchS1(){ rigRow dispatch "$rigS1" record magic-coordinator magic-coordinator.daily.routine.md dispatch-20261012T165700Z-daily-1 C0RIG:1791000000.000100 C0TRK:1791000000.000200 'The daily of Monday:\nwhat moved, what is stuck.' ; }
rigRunS1(){ rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting ; }
rigRunR2(){ rigRow run "$rigS1" "$rigR2" magic-tester spawn-started running running 2026-10-12_17:05_+0000 - rig-host ws-rig working ; }
rigRunR3(){ rigRow run "$rigS1" "$rigR3" keeper-myx spawn-succeeded no-process finished 2026-10-12_17:06_+0000 2026-10-12_18:00_+0000 rig-host ws-rig - ; }
rigRunR4(){ rigRow run "$rigS1" - magic-developer spawn-failed no-spawn-id finished 2026-10-12_17:10_+0000 2026-10-12_17:11_+0000 rig-host ws-rig - ; }
rigStoreS1(){ rigRow header "$rigS1" cli claude ; rigRow store "$rigS1" store claude-opus-5 1200 4200000 310000 52000 q1,q2 - 2026-10-13T02:10:00Z 'wait going idle' 'slack:C0RIG:1791000000.000100:conversation' - "/rig/sessions/$rigS1/session.log" /rig/audit/session-s1.log ; }
rigStoreR2(){ rigRow header "$rigR2" cli claude ; rigRow store "$rigR2" store claude-sonnet-5 414 42780073 307896 0 - - 2026-10-13T02:29:00Z 'tool call' - - "/rig/sessions/$rigR2/session.log" /rig/audit/session-r2.log ; }
rigStoreR3(){ rigRow header "$rigR3" cli copilot ; rigRow store "$rigR3" store gpt-rig 104 9185064 235484 75488 - dismissed,ended 2026-10-12T18:00:00Z end - magic-coordinator "/rig/sessions/$rigR3/session.log" - ; }
rigFeedR2(){ ## count -- that many lines of the tester, a second apart
	local feedNumber=1
	while [ "$feedNumber" -le "$1" ] ; do
		rigRow feed "$( printf '2026-10-13T02:00:%02dZ' "$feedNumber" )" "$rigR2" magic-tester member magic-tester "$( printf '💻 step %02d of the tester — execute job %d · 1 s' "$feedNumber" "$feedNumber" )"
		feedNumber=$(( feedNumber + 1 ))
	done
}
rigLogR3(){ rigRow log "$rigR3" keeper-myx 'starting keeper-myx' ; rigRow log "$rigR3" keeper-myx '  -> tool: read the index — Read' ; rigRow log "$rigR3" keeper-myx '  answering: done.' ; }
{
	rigSessionS1 ; rigRunS1 ; rigRunR2 ; rigRunR3 ; rigRunR4
	rigRow session "$rigS2" - finished 2026-10-11_14:28_+0000 2026-10-11_14:51_+0000 1 finished=1
	rigRow run "$rigS2" "$rigS2" magic-devops spawn-succeeded no-process finished 2026-10-11_14:28_+0000 2026-10-11_14:51_+0000 rig-host ws-rig -
	rigRow counters 1 0 1 1 3 0.42
} > "$rigF/rows"
{ rigSessionS1 ; rigDispatchS1 ; rigRunS1 ; rigStoreS1 ; rigRunR2 ; rigStoreR2 ; rigRunR3 ; rigStoreR3 ; rigRunR4 ; } > "$rigF/rows.--manager-session-read --session-id $rigS1"
{ rigSessionS1 ; rigDispatchS1 ; rigRunS1 ; rigStoreS1 ; } > "$rigF/rows.--manager-session-read --session-id $rigS1 --run"
{ rigSessionS1 ; rigDispatchS1 ; rigRunR2 ; rigStoreR2 ; } > "$rigF/rows.--manager-session-read --session-id $rigR2 --run"
{ rigSessionS1 ; rigDispatchS1 ; rigRunR3 ; rigStoreR3 ; } > "$rigF/rows.--manager-session-read --session-id $rigR3 --run"
{
	rigRow session "$rigS2" - finished 2026-10-11_14:28_+0000 2026-10-11_14:51_+0000 1 finished=1
	rigRow dispatch "$rigS2" no-record - - - - - -
	rigRow run "$rigS2" "$rigS2" magic-devops spawn-succeeded no-process finished 2026-10-11_14:28_+0000 2026-10-11_14:51_+0000 rig-host ws-rig -
} > "$rigF/rows.--manager-session-read --session-id $rigS2"
{
	rigRow source "$rigS1" magic-coordinator transcript /rig/audit/session-s1.log
	rigRow source "$rigR2" magic-tester transcript /rig/audit/session-r2.log
	rigRow source "$rigR3" keeper-myx session-log "/rig/sessions/$rigR3/session.log"
	rigLogR3
	rigRow feed 2026-10-12T16:57:10Z "$rigS1" magic-coordinator member magic-coordinator '🚀 start · claude-opus-5'
	rigRow feed 2026-10-12T17:05:30Z "$rigR2" magic-tester member magic-tester '🧠 round 1 · in 2 · cache 334K · out 0'
	rigRow feed 2026-10-13T02:00:05Z "$rigS1" magic-coordinator member magic-coordinator '✉️ to *magic-tester*: please run the named tests once more against live and say exactly which ones you ran, by name'
	rigRow feed 2026-10-13T02:00:40Z "$rigR2" magic-tester member magic-tester '💻 run the named tests — execute job 7 · 31 s'
	rigRow feed 2026-10-13T02:10:00Z "$rigS1" magic-coordinator member magic-coordinator '⏳ wait going idle'
} > "$rigF/rows.--manager-session-transcript-read --session-id $rigS1"
{ rigRow source "$rigS1" magic-coordinator transcript /rig/audit/session-s1.log ; rigRow feed 2026-10-13T02:10:00Z "$rigS1" magic-coordinator member magic-coordinator '⏳ wait going idle' ; } > "$rigF/rows.--manager-session-transcript-read --session-id $rigS1 --run"
{ rigRow source "$rigR2" magic-tester transcript /rig/audit/session-r2.log ; rigFeedR2 40 ; } > "$rigF/rows.--manager-session-transcript-read --session-id $rigR2 --run"
{ rigRow source "$rigR2" magic-tester transcript /rig/audit/session-r2.log ; rigFeedR2 42 ; } > "$rigF/more.rows"
{
	rigRow source "$rigR2" magic-tester session-log "/rig/sessions/$rigR2/session.log"
	rigNumber=1 ; while [ "$rigNumber" -le 30 ] ; do rigRow log "$rigR2" magic-tester "$( printf '  -> tool: log line %02d' "$rigNumber" )" ; rigNumber=$(( rigNumber + 1 )) ; done
} > "$rigF/rows.--manager-session-transcript-read --session-id $rigR2 --run --log"
{ rigRow source "$rigR3" keeper-myx session-log "/rig/sessions/$rigR3/session.log" ; rigLogR3 ; } > "$rigF/rows.--manager-session-transcript-read --session-id $rigR3 --run"
{
	rigRow source "$rigS1" magic-coordinator session-log /rig/s1.log ; rigRow source "$rigR2" magic-tester session-log /rig/r2.log ; rigRow source "$rigR3" keeper-myx none -
	rigRow log "$rigS1" magic-coordinator 'coordinator log 1' ; rigRow log "$rigS1" magic-coordinator 'coordinator log 2' ; rigRow log "$rigR2" magic-tester 'tester log 1'
} > "$rigF/rows.--manager-session-transcript-read --session-id $rigS1 --log"
{ rigRow source "$rigS2" magic-devops none - ; } > "$rigF/rows.--manager-session-transcript-read --session-id $rigS2"
## A fresh rig for one case: a copy of the fixtures, no call noted yet.
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize %s\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
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
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigCalls(){ ## how many times the stand-in was started
	LC_ALL=C grep -c '' "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- a session selected: its status, its dispatch, its participants, then the feed of its members --"
rigCase session
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
get before
keys DOWN DOWN
advance 1
turn
get asked
wait view 30
wait feed 30
get s
show s
RIGSCRIPT
rigAssert "nothing of one session is read until one is selected"     "[$( rigVal before.reading )]" "[]"
rigAssert "selecting it reads its facts and its lines, each as a call of its own" "$( rigVal asked.reading )" "feed:sessions|record:$rigS1,view:sessions|record:$rigS1"
rigAssert "by its id, once each"                                     "$( rigCalled "--manager-session-read --session-id $rigS1" ) $( rigCalled "--manager-session-transcript-read --session-id $rigS1" ) $( rigCalls )" "1 1 3"
rigAssert "the head shows its state, the line of its control thread, of which these rows say nothing, and when it started" "[$( rigPane s 3 )][$( rigPane s 4 )][$( rigPane s 5 )][$( rigPane s 6 )]" "[ state     running][ control   -][ started   2026-10-12 16:57 +0000 (9h ago)][ agents    4: 2 running, 2 finished]"
rigAssert "its dispatch: what it was started for, by whom, the routine and the item" "[$( rigPane s 7 )][$( rigPane s 8 )][$( rigPane s 9 )]" \
	"[ for       The daily of Monday: what moved, what is stuck.][ founded   by magic-coordinator, routine magic-coordinator.daily.routine.md, item][           dispatch-20261012T165700Z-daily-1]"
rigAssert "its id and its two threads"                               "[$( rigPane s 10 )][$( rigPane s 11 )]" "[ session   $rigS1][ threads   session C0RIG:1791000000.000100, tracking C0TRK:1791000000.000200]"
rigAssert "one line for each participant, with its state"            "[$( rigPane s 13 )][$( rigPane s 14 )][$( rigPane s 15 )][$( rigPane s 16 )]" \
	"[ magic-coordinator  running waiting  since 2026-10-12 16:57 +0000][ magic-tester       running working  since 2026-10-12 17:05 +0000][ keeper-myx         finished         until 2026-10-12 18:00 +0000][ magic-developer    finished         until 2026-10-12 17:11 +0000]"
rigAssert "the last head line says where the lines come from, and which run has no transcript" "[$( rigPane s 17 )][$( rigPane s 18 )]" \
	"[ lines     the feed of 3 runs: 2 from a transcript, 1 from a session log, having no][           transcript (keeper-myx)]"
rigAssert "the session log of the run with no transcript stands under a line that names it" "[$( rigPane s 19 )][$( rigPane s 20 )][$( rigPane s 21 )][$( rigPane s 22 )]" \
	"[ keeper-myx a3a3a3a3, its session log:][ starting keeper-myx][   -> tool: read the index — Read][   answering: done.]"
rigAssert "then the feed of all its members by their times, each line with its member and its emoji" "[$( rigPane s 23 )][$( rigPane s 24 )][$( rigPane s 25 )][$( rigPane s 26 )]" \
	"[ 2026-10-12][ 16:57:10 magic-coordinator 🚀 start · claude-opus-5][ 17:05:30 magic-tester      🧠 round 1 · in 2 · cache 334K · out 0][ 2026-10-13]"
rigAssert "a long line is broken under itself"                       "[$( rigPane s 27 )][$( rigPane s 28 )][$( rigPane s 29 )]" \
	"[ 02:00:05 magic-coordinator ✉️ to *magic-tester*: please run the named tests once][                            more against live and say exactly which ones you ran,][                            by name]"
rigAssert "the newest line is the last"                              "[$( rigPane s 30 )][$( rigPane s 31 )][$( rigPane s 32 )] $( rigVal s.follow ) $( rigVal s.spills )" \
	"[ 02:00:40 magic-tester      💻 run the named tests — execute job 7 · 31 s][ 02:10:00 magic-coordinator ⏳ wait going idle][] yes 0"

echo "-- an agent selected: its status, what it waits on, its model and tokens, then its own lines only --"
rigCase agent
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN ENTER DOWN
wait view 30
wait feed 30
get f
show f
keys DOWN
wait view 30
wait feed 30
get a
show a
RIGSCRIPT
rigAssert "the founder's own run is read with --run, since its id is its session's" "$( rigVal f.selected ) $( rigCalled "--manager-session-read --session-id $rigS1 --run" ) $( rigCalled "--manager-session-transcript-read --session-id $rigS1 --run" )" "$rigS1 1 1"
rigAssert "the founder: what it waits on, and its open asks"         "[$( rigPane f 7 )][$( rigPane f 8 )]" "[ waits on  slack:C0RIG:1791000000.000100:conversation][ asks      2 open: q1, q2]"
rigAssert "its model, its token counts and its last milestone"       "[$( rigPane f 9 )][$( rigPane f 10 )][$( rigPane f 11 )]" "[ model     claude-opus-5, cli claude][ tokens    in 1K, cache read 4.2M, cache write 310K, out 52K][ last      wait going idle, 20m ago]"
rigAssert "the tester is read by its own id, with --run"             "$( rigVal a.selected ) $( rigCalled "--manager-session-read --session-id $rigR2 --run" ) $( rigCalled "--manager-session-transcript-read --session-id $rigR2 --run" )" "$rigR2 1 1"
rigAssert "its status"                                               "[$( rigPane a 3 )][$( rigPane a 4 )][$( rigPane a 5 )][$( rigPane a 6 )]" "[ state     running working][ status    spawn-started][ process   running][ started   2026-10-12 17:05 +0000 (9h ago)]"
rigAssert "its model and token counts, shortened for the eye"        "[$( rigPane a 7 )][$( rigPane a 8 )][$( rigPane a 9 )]" "[ model     claude-sonnet-5, cli claude][ tokens    in 414, cache read 42.8M, cache write 308K, out 0][ last      tool call, 1m ago]"
rigAssert "where its lines come from"                                "[$( rigPane a 14 )]" "[ lines     the feed, from its transcript]"
rigAssert "its own lines only, with no member before them, the newest in view at the end" "[$( rigPane a 15 )][$( rigPane a 37 )] $( rigVal a.viewLines ) $( rigVal a.viewTop ) $( rigVal a.follow )" \
	"[ 02:00:18 💻 step 18 of the tester — execute job 18 · 1 s][ 02:00:40 💻 step 40 of the tester — execute job 40 · 1 s] 41 18 yes"
rigAssert "no line of another member of the session"                 "$( rigPaneHolds a 'magic-coordinator' ) $( rigPaneHolds a 'wait going idle' )" "0 0"

echo "-- moving the selection replaces the pane; a run with no transcript; a run with no id --"
rigCase move
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN ENTER DOWN DOWN
wait view 30
wait feed 30
keys DOWN
get asked
show early
wait view 30
wait feed 30
get k
show k
keys DOWN
turn 3
get d
show d
RIGSCRIPT
rigAssert "the selection moves on: at once nothing of the item before is left" "$( rigVal asked.selected ) $( rigVal asked.viewLines ) $( rigPaneHolds early 'step' ) $( rigPaneHolds early 'claude-sonnet-5' )" "$rigR3 0 0 0"
rigAssert "the next agent is shown: its marks, and who dismissed it" "[$( rigPane k 2 )][$( rigPane k 7 )][$( rigPane k 8 )][$( rigPane k 11 )]" "[ keeper-myx][ ended     2026-10-12 18:00 +0000 (8h ago)][ model     gpt-rig, cli copilot][ marks     dismissed, ended (dismissed by magic-coordinator)]"
rigAssert "it has no transcript: its session log is shown, and the pane says so" "[$( rigPane k 16 )][$( rigPane k 17 )][$( rigPane k 18 )][$( rigPane k 19 )]" \
	"[ lines     its session log: this run has no transcript][ starting keeper-myx][   -> tool: read the index — Read][   answering: done.]"
rigAssert "a run with no id of its own is read by nothing"           "$( rigVal d.selected ) [$( rigVal d.reading )] $( LC_ALL=C grep -c -- '--session-id -' "$MANAGER_SCREEN_RIG/calls" || : )" "-3 [] 0"
rigAssert "it shows what the list holds of it, and no line about lines" "[$( rigPane d 3 )][$( rigPane d 4 )][$( rigPane d 5 )] $( rigPaneHolds d 'lines  ' )" "[ state     finished][ status    spawn-failed][ process   no-spawn-id] 0"

echo "-- a late answer for another item is dropped --"
rigCase late
echo "sleep 2" > "$MANAGER_SCREEN_RIG/mode.--manager-session-transcript-read"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN ENTER
wait feed 30
keys DOWN DOWN
advance 1
turn
get slow
keys DOWN
get moved
wait feed 30
get k
show k
RIGSCRIPT
rigAssert "the read of the tester's lines is slow, and the selection moves on before it ends" "$( rigVal slow.selected ) $( rigVal moved.selected ) $( rigVal moved.reading | LC_ALL=C tr ',' '\n' | LC_ALL=C grep -c "^feed:" )" "$rigR2 $rigR3 1"
rigAssert "when the answers have come, the pane shows the item that is selected now" "[$( rigPane k 2 )] $( rigPaneHolds k 'step' ) $( rigPaneHolds k 'starting keeper-myx' )" "[ keeper-myx] 0 1"

echo "-- new lines come into view at the end; a pane that was scrolled up stays where it is --"
rigCase follow
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN DOWN ENTER DOWN DOWN
wait view 30
wait feed 30
get a
copy $rigTmp/follow/more.rows $rigTmp/follow/rows.--manager-session-transcript-read --session-id $rigR2 --run
advance 11
wait feed 30
get b
show b
keys TAB UP UP UP
get up
show up
RIGSCRIPT
rigAssert "the pane shows the end of the feed"                       "$( rigVal a.viewLines ) $( rigVal a.viewTop ) $( rigVal a.follow )" "41 18 yes"
rigAssert "the next read brings two more lines, and they are in view at the end" "$( rigVal b.viewLines ) $( rigVal b.viewTop ) [$( rigPane b 36 )][$( rigPane b 37 )]" \
	"43 20 [ 02:00:41 💻 step 41 of the tester — execute job 41 · 1 s][ 02:00:42 💻 step 42 of the tester — execute job 42 · 1 s]"
rigAssert "with the focus on the pane, Up three times scrolls it up, and it follows no more" "$( rigVal up.focus ) $( rigVal up.viewTop ) $( rigVal up.follow ) [$( rigPane up 15 )]" "view 17 no [ 02:00:17 💻 step 17 of the tester — execute job 17 · 1 s]"
rigCase stay
rigScript <<RIGSCRIPT
keys ENTER
wait sessions 30
keys DOWN DOWN ENTER DOWN DOWN
wait view 30
wait feed 30
keys TAB UP UP UP
get up
copy $rigTmp/stay/more.rows $rigTmp/stay/rows.--manager-session-transcript-read --session-id $rigR2 --run
advance 11
wait feed 30
get b
show b
keys PGDN
get end
show end
RIGSCRIPT
rigAssert "the pane was scrolled up by three lines"                  "$( rigVal up.viewTop ) $( rigVal up.follow )" "15 no"
rigAssert "the next read brings two more lines: the lines in view do not move" "$( rigVal b.viewLines ) $( rigVal b.viewTop ) $( rigVal b.follow ) [$( rigPane b 15 )][$( rigPane b 37 )]" \
	"43 15 no [ 02:00:15 💻 step 15 of the tester — execute job 15 · 1 s][ 02:00:37 💻 step 37 of the tester — execute job 37 · 1 s]"
rigAssert "scrolled to its end it follows the newest line again"     "$( rigVal end.viewTop ) $( rigVal end.follow ) [$( rigPane end 37 )]" "20 yes [ 02:00:42 💻 step 42 of the tester — execute job 42 · 1 s]"

echo "-- l switches the left pane to the raw log and back --"
rigCase log
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN ENTER DOWN DOWN
wait view 30
wait feed 30
keys l
get pressed
show pressed
wait feed 30
get raw
show raw
keys l
wait feed 30
get back
show back
keys l
wait feed 30
keys UP
get other
wait feed 30
keys LEFT
wait view 30
wait feed 30
keys l
wait feed 30
get s
show s
RIGSCRIPT
rigAssert "l on an agent takes the feed away at once, and asks for the raw log of that run, each time it is pressed for it" "$( rigVal pressed.rawLog ) $( rigVal pressed.viewLines ) $( rigPaneHolds pressed 'step' ) $( rigVal pressed.reading | LC_ALL=C tr ',' '\n' | LC_ALL=C grep -c '^feed:' ) $( rigCalled "--manager-session-transcript-read --session-id $rigR2 --run --log" )" "yes 0 0 1 2"
rigAssert "the pane shows the end of the raw log, and says what it shows" "$( rigVal raw.viewLines ) $( rigVal raw.follow ) [$( rigPane raw 14 )][$( rigPane raw 37 )]" "30 yes [ lines     the raw log, its session log][   -> tool: log line 30]"
rigAssert "l again shows the feed"                                   "$( rigVal back.rawLog ) [$( rigPane back 14 )][$( rigPane back 37 )]" "no [ lines     the feed, from its transcript][ 02:00:40 💻 step 40 of the tester — execute job 40 · 1 s]"
rigAssert "the raw log is asked for of the selected item: another item shows its feed" "$( rigVal other.selected ) $( rigVal other.rawLog )" "$rigS1 no"
rigAssert "l on a session shows the logs of its runs, each under a line that names its run" "$( rigVal s.selected ) $( rigCalled "--manager-session-transcript-read --session-id $rigS1 --log" ) [$( rigPane s 18 )][$( rigPane s 19 )][$( rigPane s 20 )][$( rigPane s 21 )][$( rigPane s 22 )]" \
	"$rigS1 1 [ magic-coordinator 11111111, its session log:][ coordinator log 1][ coordinator log 2][ magic-tester a2a2a2a2, its session log:][ tester log 1]"
rigAssert "and says which run has none"                              "[$( rigPane s 17 )][$( rigPane s 23 )]" "[ lines     the raw logs of 3 runs: 1 with no session log (keeper-myx)][]"

echo "-- the left pane names the keys of the selected item --"
rigCase keys
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
wait feed 30
get session
cells sessionKeys 37 0 83
handler kill
turn
cells builtKeys 37 0 83
keys UP
turn
get launch
cells launchKeys 37 0 83
keys DOWN DOWN
wait view 30
wait feed 30
get lone
show lone
RIGSCRIPT
rigAssert "a running session is selected: the pane names the keys that act on it, kill and log" "$( rigVal session.selected ) [$( rigVal sessionKeys )]" "$rigS1 [ keys: k kill  l log]"
rigAssert "and the same with another handler in the place of the kill" "[$( rigVal builtKeys )]" "[ keys: k kill  l log]"
rigAssert "Launch / Spawn has neither"                               "$( rigVal launch.selected ) [$( rigVal launchKeys )]" "launch []"
rigAssert "a session a client founded says that its founder left no record, and that it has no lines" "$( rigVal lone.selected ) $( rigPaneHolds lone 'founded   by a client, whose founder left no record' ) $( rigPaneHolds lone 'lines     the feed of 1 run: 1 with neither (magic-devops)' )" "$rigS2 1 1"

echo "-- a small pane keeps its head to half of itself --"
rigCase small
rigSize="120 16"
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
wait view 30
wait feed 30
get s
show s
RIGSCRIPT
rigSize=""
rigAssert "the pane has twelve lines, and its head takes no more than half and the line about the lines" "$( rigVal s.viewHeight ) $( rigVal s.viewHead )" "12 7"
rigAssert "what matters stays: the state, the line of its control thread, what it was started for" "[$( rigPane s 3 )][$( rigPane s 4 )][$( rigPane s 7 )]" "[ state     running][ control   -][ for       The daily of Monday: what moved, what is stuck.]"
rigAssert "and the newest line of the feed is in view under it"      "[$( rigPane s 13 )] $( rigVal s.follow ) $( rigVal s.spills )" "[ 02:10:00 magic-coordinator ⏳ wait going idle] yes 0"

echo "-- the reads of one item wait until the selection has rested on it --"
rigCase rest
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
get up
keys DOWN DOWN
get moved
advance 0.2
turn
get early
keys DOWN
advance 0.2
turn
get passed
advance 0.2
turn
get rested
wait view 30
wait feed 30
RIGSCRIPT
rigAssert "a row with nothing to read of it needs no rest"           "$( rigVal up.selected ) $( rigVal up.restLeft ) $( rigVal up.keyWait )" ".. 0.00 0.200"
rigAssert "the selection comes onto a session: nothing of it is read yet, a third of a second is left" "$( rigVal moved.selected ) [$( rigVal moved.reading )] $( rigVal moved.restLeft )" "$rigS1 [] 0.33"
rigAssert "after a fifth of a second still nothing, and the screen waits for a key no longer than the rest lasts" "[$( rigVal early.reading )] $( rigVal early.restLeft ) $( rigVal early.keyWait )" "[] 0.13 0.138"
rigAssert "the selection moves on before the rest is over: the next item rests from then" "$( rigVal passed.selected ) [$( rigVal passed.reading )] $( rigVal passed.restLeft )" "$rigS2 [] 0.13"
rigAssert "once it has rested, its facts and its lines are read"     "$( rigVal rested.reading ) $( rigVal rested.restLeft ) $( rigVal rested.keyWait )" "feed:sessions|record:$rigS2,view:sessions|record:$rigS2 0.00 0.200"
rigAssert "the session the selection ran over was never read"        "$( rigCalled "--manager-session-read --session-id $rigS1" ) $( rigCalled "--manager-session-transcript-read --session-id $rigS1" ) $( rigCalled "--manager-session-read --session-id $rigS2" )" "0 0 1"
rigCase fro
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN DOWN UP DOWN UP DOWN UP
advance 0.3
turn
get back
advance 0.1
turn
get again
wait view 30
wait feed 30
RIGSCRIPT
rigAssert "a selection that goes to and fro between two sessions starts nothing while it moves" "$( rigVal back.selected ) [$( rigVal back.reading )] $( rigVal back.restLeft )" "$rigS1 [] 0.03"
rigAssert "where it comes to rest, that item is read"                "$( rigVal again.reading )" "feed:sessions|record:$rigS1,view:sessions|record:$rigS1"
rigAssert "that one alone, once, for all those keys"                 "$( rigCalled "--manager-session-read --session-id $rigS1" ) $( rigCalled "--manager-session-transcript-read --session-id $rigS1" ) $( rigCalled "--manager-session-read --session-id $rigS2" ) $( rigCalled "--manager-session-transcript-read --session-id $rigS2" ) $( rigCalls )" "1 1 0 0 3"

echo "-- an item selected again is read again, whenever it was last read --"
rigCase again
rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
wait view 30
wait feed 30
get first
keys DOWN
wait view 30
wait feed 30
get away
keys UP
get back
wait view 30
wait feed 30
get read
show r
advance 5
turn 3
wait feed 30
get later
RIGSCRIPT
rigAssert "a session is selected and read, then another"             "$( rigVal first.selected ) $( rigVal first.viewLines ) $( rigVal away.selected )" "$rigS1 13 $rigS2"
rigAssert "the first is selected again, within the period of its read: its pane is new and empty" "$( rigVal back.selected ) $( rigVal back.viewLines )" "$rigS1 0"
rigAssert "it is read again at once, and shows its lines"            "$( rigVal read.viewLines ) $( rigPaneHolds r 'wait going idle' ) $( rigPaneHolds r 'for       The daily of Monday' )" "13 1 1"
rigAssert "each of its two reads was made twice, and no more while it stays selected inside the period" "$( rigCalled "--manager-session-read --session-id $rigS1" ) $( rigCalled "--manager-session-transcript-read --session-id $rigS1" ) [$( rigVal later.reading )]" "2 2 []"

echo "-- a wider session row and a control row change nothing else the pane shows --"
## What the operations print now: each `session` row with three more fields after its eight, and in a read one
## `control` row after the `dispatch` row. Every other row of the fixtures is as it was.
rigWiden(){ ## -- the fixtures of the case in place: the list and each read of a session
	local widenFile
	for widenFile in "$MANAGER_SCREEN_RIG/rows" "$MANAGER_SCREEN_RIG"/rows.--manager-session-read* ; do
		[ -f "$widenFile" ] || continue
		LC_ALL=C awk -F'\t' '
			$1 == "session" { stored = ( $4 == "running" ? "running\t2026-10-12_16:58_+0000\talive" : "finished\t2026-10-11_14:51_+0000\tnone" ) ; print $0 "\t" stored ; sessionId = $2 ; next }
			{ print }
			$1 == "dispatch" { print "control\t" sessionId "\t" stored "\t" ( stored ~ /alive$/ ? "4242" : "-" ) }
		' "$widenFile" > "$widenFile.wide" && mv -f "$widenFile.wide" "$widenFile"
	done
}
rigWideDrawn(){ ## the case, "wide" for the wider rows -- what the screen draws of a session selected, then of an agent of it, then of a session with no record of its founder
	rigCase "$1"
	[ "${2:-}" != "wide" ] || rigWiden
	rigScript <<'RIGSCRIPT'
keys ENTER
wait sessions 30
keys DOWN DOWN
advance 1
turn
wait view 30
wait feed 30
get s
show s
keys ENTER
keys DOWN DOWN
advance 1
turn
wait view 30
wait feed 30
get r
show r
keys LEFT DOWN
advance 1
turn
wait view 30
wait feed 30
get n
show n
RIGSCRIPT
	printf '%s\n' "$rigOut"
}
rigDrawnEight="$( rigWideDrawn eight )"
rigDrawnEleven="$( rigWideDrawn eleven wide )"
rigAssert "control: the fixtures of the second case hold the wider session rows and a control row in each read of a session, and the first holds none" \
	"$( cat "$rigTmp/eleven/rows" "$rigTmp/eleven"/rows.--manager-session-read* | LC_ALL=C awk -F'\t' '$1 == "session" { rows++ ; if ( NF == 11 ) wide++ } $1 == "control" && NF == 6 { control++ } END { print rows + 0 ":" wide + 0 ":" control + 0 }' ) $( cat "$rigTmp/eight/rows" "$rigTmp/eight"/rows.--manager-session-read* | LC_ALL=C awk -F'\t' '$1 == "session" && NF != 8 { wide++ } $1 == "control" { control++ } END { print wide + 0 ":" control + 0 }' )" "7:7:5 0:0"
rigAssert "control: the screen was driven through a session, an agent of it and a second session, read each, and drew each pane" "$( printf '%s\n' "$rigDrawnEight" | LC_ALL=C grep -c -e '^s|' -e '^r|' -e '^n|' | LC_ALL=C awk '{ print ( $1 >= 120 ) ? "drawn" : "not drawn: " $1 }' ) $( printf '%s\n' "$rigDrawnEight" | LC_ALL=C grep -c -F -- 'for       The daily of Monday' | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "read" : "not read" }' ) $( printf '%s\n' "$rigDrawnEight" | LC_ALL=C grep -c 'DRIVER-FAILED' )" "drawn read 0"
rigDrawnBut(){ ## a drawing -- its lines but for the line control of the pane of a session, and but for how many times the screen was drawn, which is as many as the turns it waited for a call, by the clock of the host
	printf '%s\n' "$1" | LC_ALL=C grep -v -e '^[sn]| control   ' -e '^[srn]\.frames='
}
rigAssert "without them the line control of a session says - of what no row tells, and an agent has no such line" "$( printf '%s\n' "$rigDrawnEight" | LC_ALL=C grep -c -e '^s| control   -  ' ) $( printf '%s\n' "$rigDrawnEight" | LC_ALL=C grep -c -e '^n| control   -  ' ) $( printf '%s\n' "$rigDrawnEight" "$rigDrawnEleven" | LC_ALL=C grep -c -e '^r| control ' )" "1 1 0"
rigAssert "with them it says what the read of the session gave: a thread that lives with its pid, one that ended in order, and the state each stored" "$( printf '%s\n' "$rigDrawnEleven" | LC_ALL=C grep -c -F -e 's| control   alive, pid 4242; stored running, set 2026-10-12 16:58 +0000 (9h ago)  ' ) $( printf '%s\n' "$rigDrawnEleven" | LC_ALL=C grep -c -F -e 'n| control   none; stored finished, set 2026-10-11 14:51 +0000 (35h ago)  ' )" "1 1"
rigAssert "nothing else changes: but for that one line of the pane of a session, the screen asks the same reads and draws and reports cell for cell what it did without them" "$( [ "$( rigDrawnBut "$rigDrawnEleven" )" = "$( rigDrawnBut "$rigDrawnEight" )" ] && echo same || { echo differs ; diff <( rigDrawnBut "$rigDrawnEight" ) <( rigDrawnBut "$rigDrawnEleven" ) | head -6 ; } ) $( cmp -s "$rigTmp/eight/calls" "$rigTmp/eleven/calls" && echo same-calls ) $( LC_ALL=C grep -c -e '--manager-session-read' "$rigTmp/eleven/calls" | LC_ALL=C awk '{ print ( $1 >= 3 ) ? "reads" : "no reads: " $1 }' )" "same same-calls reads"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN PANE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_PANE: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
