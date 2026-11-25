#!/usr/bin/env bash
## Behavioural check on the pane of an item looked at a SECOND time (sh-lib/manager/AgentsManagerScreen.Pane.py, followSelection, and
## AgentsManagerScreen.Reads.py, startDueReads). The screen's own code runs through the stand-in terminal of the driver.
## Held: a pane made new for an item the screen has already shown holds all of the item's facts, as the first look did, and not the
## row's own few. A pane made new holds nothing of its item, so each read it stands on is due again: its answer, already given and
## still fresh, is taken into the pane, and the read is not asked of the tooling a second time.
##   1. THE FIRST LOOK: the founder's model, tokens and its agents' table are in the pane (the control of this check).
##   2. THE SECOND LOOK, after the selection went to another row and came back: the pane shows the same lines.
##   3. NO SECOND ASK: the tooling was asked for the founder's facts once.
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/manager/LocalManagerScreen.py"
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
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenSecondViewCheck )" || exit 1
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
## The total of the tokens of the first session, as its read gives it: the four figures summed over the three runs
## that have a store, two of which run, what was eaten so far, and one run left out, the one with no id of its own.
rigTokensS1(){ rigRow tokens "$rigS1" 1718 56165137 853380 127488 3 2 so-far 1 ; }
## The state of a live run is the word the registry derives from its activity (S27.4): `waiting` for the founder in its Wait, `tool` for the tester in a tool call.
rigRunS1(){ rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running waiting 2026-10-12_16:57_+0000 - rig-host ws-rig waiting ; }
rigRunR2(){ rigRow run "$rigS1" "$rigR2" magic-tester spawn-started running tool 2026-10-12_17:05_+0000 - rig-host ws-rig working ; }
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
{ rigSessionS1 ; rigDispatchS1 ; rigTokensS1 ; rigRunS1 ; rigStoreS1 ; rigRunR2 ; rigStoreR2 ; rigRunR3 ; rigStoreR3 ; rigRunR4 ; } > "$rigF/rows.--manager-session-read --session-id $rigS1"
{ rigSessionS1 ; rigDispatchS1 ; rigRunS1 ; rigStoreS1 ; } > "$rigF/rows.--manager-session-read --session-id $rigS1 --run"
{ rigSessionS1 ; rigDispatchS1 ; rigRunR2 ; rigStoreR2 ; } > "$rigF/rows.--manager-session-read --session-id $rigR2 --run"
{ rigSessionS1 ; rigDispatchS1 ; rigRunR3 ; rigStoreR3 ; } > "$rigF/rows.--manager-session-read --session-id $rigR3 --run"
{
	rigRow session "$rigS2" - finished 2026-10-11_14:28_+0000 2026-10-11_14:51_+0000 1 finished=1
	rigRow dispatch "$rigS2" no-record - - - - - -
	rigRow tokens "$rigS2" 90 0 0 10 1 0 final 0
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
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize %s\nroot active-sessions\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
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
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/^┌\(─\)* \(.*\) \(─\)*┐.*$/ \2/' -e 's/^╔\(═\)* \(.*\) \(═\)*╗.*$/ \2/' -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' -e 's/▲.*$//' -e 's/▼.*$//' -e 's/▒.*$//' -e 's/■.*$//' -e 's/  *$//'
}
rigPaneHolds(){ ## tag, text -- how many lines of the left pane of that screen hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' -e 's/▲.*$//' -e 's/▼.*$//' -e 's/▒.*$//' -e 's/■.*$//' | LC_ALL=C grep -c -F -- "$2" || :
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigCalls(){ ## how many times the stand-in was started. The list of the locations, which every start of the screen reads, is not counted.
	LC_ALL=C grep -c -v -x -e '--manager-place-list' "$MANAGER_SCREEN_RIG/calls" || :
}


echo "-- an item looked at a second time shows all it showed the first time --"
rigCase second
rigScript <<RIGSCRIPT
at @activity active-sessions $rigS1
turn 1
wait sessions 30
keys DOWN
wait view 30
get f
show f
keys DOWN
wait view 30
get a
keys UP
turn
wait view 30
get g
show g
RIGSCRIPT
rigAssert "the first look holds the founder's model, tokens and last milestone" "[$( rigPane f 9 )][$( rigPane f 10 )][$( rigPane f 11 )]" "[  model      claude-opus-5, cli claude][  tokens     in 1K, cache read 4.2M, cache write 310K, out 52K][  last       wait going idle, 20m ago]"
rigAssert "the selection was on the founder again, and on the tester between" "$( rigVal f.selected ) $( rigVal a.selected ) $( rigVal g.selected )" "$rigS1 $rigR2 $rigS1"
rigAssert "the second look holds the same lines" "[$( rigPane g 9 )][$( rigPane g 10 )][$( rigPane g 11 )]" "[  model      claude-opus-5, cli claude][  tokens     in 1K, cache read 4.2M, cache write 310K, out 52K][  last       wait going idle, 20m ago]"
rigAssert "the founder's facts were asked of the tooling once" "$( rigCalled "--manager-session-read --session-id $rigS1 --run" )" "1"
printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
