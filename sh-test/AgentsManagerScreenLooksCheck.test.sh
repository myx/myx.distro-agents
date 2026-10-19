#!/usr/bin/env bash
## Behavioural check on the small looks of the manager screen (sh-lib/AgentsManagerScreen.py), run rather than read. The
## screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and
## where it would call the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.stub.sh), which
## prints rows in the forms the operations print, at once, after a wait, or fails, as the case says.
## Held: a window that waits for its first rows says `Populating <its name>...` in a pale look, the list under its
## fixed rows and the left window on its first line, and no more once the rows have come; a list that was read and
## holds nothing, and one whose read failed, do not say it; the log of an item says it under its head until its
## lines have come; a screen with no reader waits for nothing. The frame of the window without the keys is drawn in
## a paler palette entry than the one with them, and behind a dialog both are, the double line staying where it
## was. A session whose list row ends with the total of its tokens shows it short in a narrow column after its
## state, the figures one under another, where a row has 34 cells, and not in a narrower list; a row without that
## field has no column. (The cut rule of the top line is held by AgentsManagerScreenChromeCheck.)
## Offline: no operation of the real tooling is called. The time zone is set here, so the times read the same anywhere.
## Reconciled for F11.0: `Launch / Spawn` is named `Launch (Start)`, `Consoles (Tools)` `Consoles`; the spacer under
## `Launch (Start)` moves each session row of the list one line down.
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
rigTmp="$( mktemp -d -t AgentsManagerScreenLooksCheck )" || exit 1
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
## Three sessions whose rows end with the total of their tokens, a number, a number with runs left out, and none;
## and one whose row is the short one, with no such field.
rigS1=11111111-0000-4000-8000-000000000001 ; rigS2=22222222-0000-4000-8000-000000000002 ; rigS3=33333333-0000-4000-8000-000000000003 ; rigS4=44444444-0000-4000-8000-000000000004
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 1 running=1 - - - 57147723
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting
	rigRow session "$rigS2" the_retro finished 2026-10-11_14:28_+0000 2026-10-11_14:51_+0000 1 finished=1 - - - 523000+
	rigRow session "$rigS3" grooming finished 2026-10-10_14:28_+0000 2026-10-10_14:51_+0000 1 finished=1 - - - -
	rigRow session "$rigS4" an_old_one finished 2026-10-09_14:28_+0000 2026-10-09_14:51_+0000 1 finished=1
	rigRow counters 1 0 0 1 0 0.42
} > "$rigF/rows"
{ rigRow source "$rigS1" magic-coordinator transcript /rig/audit/session-s1.log ; rigRow feed 2026-10-13T02:00:05Z "$rigS1" magic-coordinator member magic-coordinator '⏳ wait going idle' ; } > "$rigF/rows.--manager-session-transcript-read"
rigCase(){ ## name, what the stand-in does at every start, [the first word of an operation, what it does for that one]
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	printf '%s\n' "$2" > "$MANAGER_SCREEN_RIG/mode"
	[ $# -lt 4 ] || printf '%s\n' "$4" > "$MANAGER_SCREEN_RIG/mode.$3"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable list:dashboard none\ntable list:places none\ntable view:sessions:record none\nworkspace /somewhere/ws-rig\nwall 2026-10-13 02:30 +0000\nsize %s\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigBare(){ ## the commands of the driver on standard input, with no dispatcher
	rigOut="$( { printf 'workspace /somewhere/ws-rig\nwall 2026-10-13 02:30 +0000\nsize %s\n' "${rigSize:-100 30}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigHolds(){ ## tag, text -- how many lines of that drawn screen hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigLook(){ ## tag, line of the screen counted from 0, from, to -- the letters of the looks of those cells, each letter once
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C sed -n "$(( $2 + 1 ))p" | LC_ALL=C cut -c"$(( $3 + 1 ))-$4" | LC_ALL=C fold -w 1 | LC_ALL=C sort -u | LC_ALL=C tr -d '\n'
}

echo "-- a window that waits for its first rows says so, in a pale look --"
rigCase waits rows --manager-session-list 'sleep 1'
rigScript <<'RIGSCRIPT'
turn
keys 2
turn
get w
cells wView 2 1 83
cells wList1 2 85 119
cells wList2 3 85 119
cells wList3 4 85 119
roles wr
wait sessions 30
get r
show rs
cells rList3 5 85 119
RIGSCRIPT
rigAssert "the sessions are being read, and none has come yet"       "$( rigVal w.path ) $( rigVal w.reading ) $( rigVal w.rows )" "sessions list:sessions 2"
rigAssert "the list says what it waits for, under its fixed rows"     "[$( rigVal wList1 )][$( rigVal wList2 )][$( rigVal wList3 )]" "[>..][ Launch (Start)                  ►][ Populating Sessions (Activity)...]"
rigAssert "and the left window, which shows the folder itself, on its first line" "[$( rigVal wView )]" "[Populating Sessions (Activity)...]"
rigAssert "both in the pale look"                                    "[$( rigLook wr 2 1 83 )][$( rigLook wr 4 85 119 )]" "[D][D]"
rigAssert "once the rows have come neither says it"                  "$( rigVal r.rows ) $( rigHolds rs 'Populating' ) [$( rigVal rList3 | LC_ALL=C cut -c1-16 )]" "6 0 [ daily of Monday]"

echo "-- read and empty, and a failed read, keep their own words --"
rigCase empty rows
: > "$MANAGER_SCREEN_RIG/rows"
rigScript <<'RIGSCRIPT'
keys 2
wait sessions 30
get e
show es
RIGSCRIPT
rigAssert "a list that was read and holds nothing does not say it waits" "$( rigVal e.rows ) [$( rigVal e.failed )] $( rigHolds es 'Populating' )" "2 [] 0"
rigCase failed fail
rigScript <<'RIGSCRIPT'
keys 2
wait sessions 30
keys ESC
turn
get f
show fs
RIGSCRIPT
rigAssert "nor does one whose read failed"                           "[$( rigVal f.failed )] $( rigHolds fs 'Populating' )" "[list:sessions] 0"

echo "-- the log of an item waits for its lines under its head; a screen with no reader waits for nothing --"
rigCase log rows --manager-session-transcript-read 'sleep 1'
rigScript <<'RIGSCRIPT'
keys 2
wait sessions 30
keys DOWN DOWN l
advance 1
turn 2
get l
cells lHead 2 1 83
cells lWaits 3 1 83
roles lr
wait feed 30
cells lLine 3 1 83
show ls
RIGSCRIPT
rigAssert "its lines are being read"                                 "$( rigVal l.selected ) $( rigVal l.viewMode ) $( rigVal l.reading ) $( rigVal l.viewLines )" "$rigS1 log feed:sessions|record:$rigS1 0"
rigAssert "under the head line the window says what it waits for, pale" "[$( rigVal lHead )][$( rigVal lWaits )][$( rigLook lr 3 1 83 )]" "[lines     the feed, not read yet][Populating daily of Monday...][D]"
rigAssert "and no more once they have come"                          "[$( rigVal lLine )] $( rigHolds ls 'Populating' )" "[2026-10-13] 0"
rigBare <<'RIGSCRIPT'
rows sessions a=alpha
keys 2 DOWN DOWN
turn
get b
show bs
RIGSCRIPT
rigAssert "with no reader nothing is waited for"                     "$( rigVal b.selected ) $( rigVal b.viewLines ) $( rigHolds bs 'Populating' )" "a 0 0"

echo "-- the frame of a window without the keys is paler, and behind a dialog both are --"
rigBare <<'RIGSCRIPT'
turn
roles a
cells aView 1 0 1
cells aList 1 70 71
keys TAB
roles t
tell A box | its text
turn
roles d
cells dView 1 0 1
cells dList 1 70 71
RIGSCRIPT
rigColours="$( "$rigPython" -I -B -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
on, off = module.LOOKS[module.FRAME_ON], module.LOOKS[module.FRAME]
print("%s %s %s / %s %s %s / mono [%s] [%s]" % (on[2], on[3], on[4], off[2], off[3], off[4], on[1], off[1]))' "$rigScreen" 2>&1 )"
rigAssert "the two frames are two palette entries: bright white for the window with the keys, a paler colour for the other, bold and plain with no colours" "$rigColours" "white blue True / cyan blue False / mono [B] []"
rigAssert "the list has the keys: its frame is the active one's, the left window's the other's" "[$( rigLook a 1 70 71 )][$( rigLook a 1 0 1 )] [$( rigVal aView )$( rigVal aList )]" "[F][f] [┌╔]"
rigAssert "Tab: they change places"                                  "[$( rigLook t 1 70 71 )][$( rigLook t 1 0 1 )]" "[f][F]"
rigAssert "behind a dialog both frames are the paler one, and the double line stays where it was" "[$( rigLook d 1 70 71 )][$( rigLook d 1 0 1 )] [$( rigVal dView )$( rigVal dList )]" "[f][f] [╔┌]"

echo "-- the total of the tokens of a session in a narrow column of the list --"
rigCase tokens rows
rigScript <<'RIGSCRIPT'
keys 2
wait sessions 30
get k
cells k1 5 85 119
cells k2 6 85 119
cells k3 7 85 119
cells k4 8 85 119
size 100 40
turn
get n
cells n1 5 71 99
RIGSCRIPT
rigAssert "at 120 columns a row of the list has 34 cells"             "$( rigVal k.listWidth ) $( rigVal k.rows ) $( rigVal k.spills )" "36 6 0"
rigAssert "a session shows the total of its tokens, short, after its state" "[$( rigVal k1 )]" "[ daily of Monday  running  57.1M ►]"
rigAssert "one with runs left out keeps its mark, one with no figure shows that, the figures one under another" "[$( rigVal k2 )][$( rigVal k3 )]" "[ the retro       finished  523K+ ►][ grooming        finished      - ►]"
rigAssert "a row without that field has no column"                   "[$( rigVal k4 )]" "[ an old one             finished ►]"
rigAssert "a narrower list shows none"                               "$( rigVal n.listWidth ) [$( rigVal n1 )] $( rigVal n.spills )" "30 [ daily of Monday   running ►] 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN LOOKS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_LOOKS: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
