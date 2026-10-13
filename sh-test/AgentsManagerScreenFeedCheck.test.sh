#!/usr/bin/env bash
## Behavioural check on how the log mode of the left window of the manager screen (sh-lib/AgentsManagerScreen.py)
## sets out an entry of the feed, run rather than read. The screen's own code runs through the stand-in terminal of
## the driver (check-fixtures/manager-screen.driver.test.py), and where it would call the dispatcher it calls a
## stand-in script (check-fixtures/manager-screen.tools.test.sh), which prints rows in the forms the operations print.
## Held: an entry is a head line, its time and its member ended by a colon, and its body on the lines after it, set
## in by the width of the time and one blank; the mark of the entry starts the body; every body starts in the same
## column; a long body is broken at words, keeps that indent on every line it goes on, and loses no word; every
## entry has its own head, also where the same member spoke in the same minute; the head is drawn paler than the
## body, and the day line as the body is; the time and the member come from the row, so a text that looks like a
## head stays a body; the indent is the same at another width of the window, where the body takes more lines; the
## log of one agent names its member in the head too; and the raw mode shows the raw lines as they are, none of
## them a head.
## Offline: no operation of the real tooling is called. The time zone is set here, so the times read the same anywhere.
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
rigTmp="$( mktemp -d -t AgentsManagerScreenFeedCheck )" || exit 1
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
## One session that runs, with two agents: its founder, whose id is the session's, and a tester. The feed of the
## session holds a short entry of each, a long one, one whose text looks like a head, and two of the same member
## in the same minute; the feed of the founder alone holds its own entries.
rigS1=11111111-0000-4000-8000-000000000001 ; rigR2=a2a2a2a2-0000-4000-8000-0000000000a2
rigLong='✉️ to *magic-tester*: please run the named tests once more against live and say exactly which ones you ran, by name, and then wait for the next word from me before anything else is started'
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 2 running=2
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting
	rigRow run "$rigS1" "$rigR2" magic-tester spawn-started running running 2026-10-12_17:05_+0000 - rig-host ws-rig working
	rigRow counters 1 0 1 1 0 0.42
} > "$rigF/rows"
{
	rigRow source "$rigS1" magic-coordinator transcript /rig/audit/session-s1.log
	rigRow source "$rigR2" magic-tester transcript /rig/audit/session-r2.log
	rigRow feed 2026-10-13T02:00:05Z "$rigS1" magic-coordinator member magic-coordinator '🧠 round 98 · in 37K · cache 163K · out 56'
	rigRow feed 2026-10-13T02:00:40Z "$rigR2" magic-tester member magic-tester '💻 run the named tests — execute job 7 · 31 s'
	rigRow feed 2026-10-13T02:01:10Z "$rigS1" magic-coordinator member magic-coordinator "$rigLong"
	rigRow feed 2026-10-13T02:01:20Z "$rigS1" magic-coordinator member magic-coordinator '12:34:56 nobody: a text that looks like a head'
	rigRow feed 2026-10-13T02:01:30Z "$rigS1" magic-coordinator member magic-coordinator '⏳ wait going idle'
} > "$rigF/rows.--manager-session-transcript-read --session-id $rigS1"
{
	rigRow source "$rigS1" magic-coordinator transcript /rig/audit/session-s1.log
	rigRow feed 2026-10-13T02:00:05Z "$rigS1" magic-coordinator member magic-coordinator '🧠 round 98 · in 37K · cache 163K · out 56'
} > "$rigF/rows.--manager-session-transcript-read --session-id $rigS1 --run"
{
	rigRow source "$rigS1" magic-coordinator session-log /rig/s1.log ; rigRow source "$rigR2" magic-tester session-log /rig/r2.log
	rigRow log "$rigS1" magic-coordinator 'coordinator log 1' ; rigRow log "$rigS1" magic-coordinator '  -> tool: 02:00:05 magic-coordinator: no head'
	rigRow log "$rigR2" magic-tester 'tester log 1'
} > "$rigF/rows.--manager-session-transcript-read --session-id $rigS1 --log"
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:sessions:record none\ntable view:sessions/*:record none\nwall 2026-10-13 02:30 +0000\nsize %s\nroot sessions\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigLook(){ ## tag, line of the screen counted from 0, from, to -- the letters of the looks of those cells, each letter once
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -n "$(( $2 + 1 ))p" | LC_ALL=C cut -c"$(( $3 + 1 ))-$4" | LC_ALL=C fold -w 1 | LC_ALL=C sort -u | LC_ALL=C tr -d '\n'
}
rigBody(){ ## the tags of the lines of one body, in their order -- its lines joined by a blank, each without its indent
	local bodyText="" bodyTag
	for bodyTag in "$@" ; do bodyText="$bodyText $( rigVal "$bodyTag" | LC_ALL=C sed -e 's/^  *//' )" ; done
	printf '%s' "${bodyText# }"
}

echo "-- the log of a session: every entry a head line and its body under it --"
rigCase session
rigScript <<'RIGSCRIPT'
keys 2
wait sessions 30
keys DOWN DOWN l
wait feed 30
get s
cells title 1 0 84
cells l3 3 1 83
cells l4 4 1 83
cells l5 5 1 83
cells l6 6 1 83
cells l7 7 1 83
cells l8 8 1 83
cells l9 9 1 83
cells l10 10 1 83
cells l11 11 1 83
cells l12 12 1 83
cells l13 13 1 83
cells l14 14 1 83
cells l15 15 1 83
cells l16 16 1 83
cells l17 17 1 83
roles r
RIGSCRIPT
rigAssert "the session is selected, and its log is shown"            "$( rigVal s.selected ) $( rigVal s.viewMode ) $( rigVal s.viewLines ) $( rigVal s.spills )" "$rigS1 log 13 0"
rigAssert "the day line stays as it was"                             "[$( rigVal l3 )]" "[2026-10-13]"
rigAssert "a short entry: its head, the time and the member ended by a colon" "[$( rigVal l4 )]" "[02:00:05 magic-coordinator:]"
rigAssert "and its body on the next line, set in by the width of the time and one blank, its mark first" "[$( rigVal l5 )]" "[         🧠 round 98 · in 37K · cache 163K · out 56]"
rigAssert "two members in turn: the member in the head keeps the entries apart" "[$( rigVal l6 )][$( rigVal l7 )][$( rigVal l8 )]" "[02:00:40 magic-tester:][         💻 run the named tests — execute job 7 · 31 s][02:01:10 magic-coordinator:]"
rigAssert "a long body is broken at words into lines that all start in that column" "$( for rigTag in l9 l10 l11 ; do rigVal "$rigTag" | LC_ALL=C sed -e 's/^\( *\).*$/\1/' | LC_ALL=C tr ' ' '_' ; done | LC_ALL=C tr '\n' ' ' )" "_________ _________ _________ "
rigAssert "and no word of it is lost"                                "[$( rigBody l9 l10 l11 )]" "[$rigLong]"
rigAssert "a text that looks like a head is a body: the head comes from the row" "[$( rigVal l12 )][$( rigVal l13 )]" "[02:01:20 magic-coordinator:][         12:34:56 nobody: a text that looks like a head]"
rigAssert "the same member in the same minute has a head of its own again" "[$( rigVal l14 )][$( rigVal l15 )][$( rigVal l16 )]" "[02:01:30 magic-coordinator:][         ⏳ wait going idle][]"
rigAssert "a head is drawn paler than a body, and the day line as a body is" "[$( rigLook r 3 1 83 )][$( rigLook r 4 1 83 )][$( rigLook r 5 1 83 )][$( rigLook r 12 1 83 )][$( rigLook r 13 1 83 )]" "[.][D][.][D][.]"

echo "-- the indent is the same at another width of the window --"
rigCase narrow
rigSize="80 24" rigScript <<'RIGSCRIPT'
keys 2
wait sessions 30
keys DOWN DOWN l
wait feed 30
keys TAB PGUP PGUP PGUP
get n
cells n3 3 1 55
cells n4 4 1 55
cells n5 5 1 55
cells n8 8 1 55
cells n9 9 1 55
cells n10 10 1 55
cells n11 11 1 55
cells n12 12 1 55
cells n13 13 1 55
cells n14 14 1 55
RIGSCRIPT
rigAssert "at 80 columns the window is 54 cells wide inside its frame" "$( rigVal n.viewWidth ) $( rigVal n.viewTop ) $( rigVal n.spills )" "55 0 0"
rigAssert "the head and the body of a short entry stand as they did" "[$( rigVal n3 )][$( rigVal n4 )][$( rigVal n5 )]" "[2026-10-13][02:00:05 magic-coordinator:][         🧠 round 98 · in 37K · cache 163K · out 56]"
rigAssert "the long body takes more lines there, every one set in the same" "[$( rigVal n8 )] $( for rigTag in n9 n10 n11 n12 n13 ; do rigVal "$rigTag" | LC_ALL=C sed -e 's/^\( *\).*$/\1/' | LC_ALL=C tr ' ' '_' ; done | LC_ALL=C tr '\n' ' ' )[$( rigVal n14 )]" "[02:01:10 magic-coordinator:] _________ _________ _________ _________ _________ [02:01:20 magic-coordinator:]"
rigAssert "and holds every word"                                     "[$( rigBody n9 n10 n11 n12 n13 )]" "[$rigLong]"

echo "-- the log of one agent names its member in the head too --"
rigCase agent
rigScript <<'RIGSCRIPT'
keys 2
wait sessions 30
keys DOWN DOWN l ENTER DOWN
wait feed 30
get a
cells a4 4 1 83
cells a5 5 1 83
RIGSCRIPT
rigAssert "the agent is selected, in the mode that was chosen"       "$( rigVal a.path ) $( rigVal a.selected ) $( rigVal a.viewMode )" "sessions/$rigS1 $rigS1 log"
rigAssert "its entry is a head with its member and a body"           "[$( rigVal a4 )][$( rigVal a5 )]" "[02:00:05 magic-coordinator:][         🧠 round 98 · in 37K · cache 163K · out 56]"

echo "-- the raw mode shows the raw lines as they are --"
rigCase raw
rigScript <<'RIGSCRIPT'
keys 2
wait sessions 30
keys DOWN DOWN g
wait feed 30
get w
cells w3 3 1 83
cells w4 4 1 83
cells w5 5 1 83
cells w6 6 1 83
cells w7 7 1 83
cells w8 8 1 83
roles q
RIGSCRIPT
rigAssert "the raw lines of each run stand under the line that names it, as before" "$( rigVal w.viewMode ) [$( rigVal w3 )][$( rigVal w4 )][$( rigVal w5 )][$( rigVal w6 )][$( rigVal w7 )][$( rigVal w8 )]" \
	"raw [magic-coordinator 11111111, its session log:][coordinator log 1][  -> tool: 02:00:05 magic-coordinator: no head][magic-tester a2a2a2a2, its session log:][tester log 1][]"
rigAssert "none of them is drawn as a head"                          "[$( rigLook q 3 1 83 )][$( rigLook q 4 1 83 )][$( rigLook q 5 1 83 )]" "[.][.][.]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN FEED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_FEED: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
