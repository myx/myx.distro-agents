#!/usr/bin/env bash
## Behavioural check on the spinner of the manager screen (sh-lib/manager/LocalManagerScreen.py), run rather than read. The screen's own
## code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py).
## Held: while the screen waits on the tooling the spinner turns on its own. A turn of the idle screen writes the cell the spinner
## stands in, and no other, so the frame is never drawn whole for it. It writes a frame only when the frame has changed, and
## it writes none when nothing is waited on.
##   1. THE FRAME CHANGES, ONE CELL: the screen before and after the spinner's turn differs in that one cell.
##   2. NO WRITE FOR THE SAME FRAME: a second turn within the same frame writes nothing.
##   3. THE NEXT FRAME WRITES AGAIN, and nothing was drawn whole: no repaint, and one put for each turn.
##   4. NOTHING WAITED ON, NOTHING WRITTEN: with no read out the spinner's turn writes nothing.
## Red before the fix: the screen has no turn of its own for the spinner, so the driver's `spin` command finds none.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/manager/LocalManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
"$rigPython" -I -c 'import curses' 2> /dev/null || rigRefuse "the python3 on PATH has no curses module, so the real screen cannot be started here: $rigPython"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigScript(){ ## the commands of the driver on standard input; what it printed is kept in rigOut
	rigOut="$( "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigScreenText(){ ## tag -- the screen of that tag, without the tag
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p"
}

## The wait is on from the first turn, and the small spinner of the title stands once it has lasted 0.4 s. The frames follow the wall clock
## eight times a second: 1000.00 is the first frame, 1000.63 the second, 1000.76 the third.
rigScript <<'SCRIPT'
size 100 30
epoch 1000.00
reading view=probe
view 3
turn
epoch 1000.50
turn
show before
get beforeget
epoch 1000.63
spin
show after
get afterget
spin
epoch 1000.76
spin
get thirdget
reading
epoch 1000.88
spin
SCRIPT
rigAssert "the driver ran to its end" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'DRIVER-FAILED\|Traceback\|AttributeError' )" "0"
rigSpins="$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^spin=' | LC_ALL=C tr '\n' ' ' )"
rigAssert "the next frame writes, the same frame writes nothing, the next frame writes again, and a wait that ended writes nothing" "$rigSpins" "spin=yes spin=no spin=yes spin=no "
rigBefore="$( rigScreenText before )"
rigAfter="$( rigScreenText after )"
rigAssert "the screen differs in one cell after the spinner's turn" "$( cmp -l <( printf '%s\n' "$rigBefore" ) <( printf '%s\n' "$rigAfter" ) 2> /dev/null | wc -l | tr -d ' ' )" "1"
rigPutsBefore="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^beforeget\.puts=//p' | head -1 )"
rigPutsAfter="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^afterget\.puts=//p' | head -1 )"
rigAssert "one put for the turn of the spinner, and no frame drawn whole" "$(( rigPutsAfter - rigPutsBefore )) $( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^afterget\.repaints=//p' | head -1 ):$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^beforeget\.repaints=//p' | head -1 )" "1 0:0"

printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
