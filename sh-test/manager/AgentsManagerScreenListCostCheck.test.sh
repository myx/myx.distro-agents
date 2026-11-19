#!/usr/bin/env bash
## Behavioural check on what the manager screen asks of the tooling while nobody touches it: no two
## `--manager-session-list` passes may run at once, with one screen open and with two. The screen's
## own code (sh-lib/manager/LocalManagerScreen.py) runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py) and the stand-in for the dispatcher
## (check-fixtures/manager-screen.tools.stub.sh), which records every start in the rig's `calls` file.
## The screen's period re-reads the list it shows every REFRESH_SECONDS, by design, so this check does
## not assert that a quiet screen makes no further pass. It asserts what the item's Check line asks:
## no two passes overlapping at any instant, read from stamps the stand-in writes as each pass begins
## and ends, never from a count.
## The trigger half of the task, one changed session running the list once, needs the change-stamp
## operation, whose name is unruled: it is held until that ruling lands.
## Offline: no operation of the real tooling is called, and no session of this machine is read.
set -u
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
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
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenListCostCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

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

## The stand-in, wrapped so each start and its end are stamped. A pass' span is its START line to
## its END line, both on the one clock, so a question about overlap is answered by those stamps and
## never by a count. The shared stand-in itself is used unchanged.
rigStamp="$rigTmp/stamp-tools.sh"
cat > "$rigStamp" <<STAMP
#!/usr/bin/env bash
printf 'START %s %s\n' "\$( date +%s.%N )" "\$*" >> "\$MANAGER_SCREEN_RIG/stamps"
bash "$rigTools" "\$@"
printf 'END %s %s\n' "\$( date +%s.%N )" "\$*" >> "\$MANAGER_SCREEN_RIG/stamps"
STAMP
chmod +x "$rigStamp"

## One rig for every case: the fixtures, one session that runs with one agent, and nothing read yet.
rigF="$rigTmp/fixtures"
mkdir -p "$rigF"
{
	rigRow session 11111111-0000-4000-8000-000000000001 daily_of_Monday running 2026-10-12_16:57_+0300 - 1 running=1 - - - '' - - - active
	rigRow run 11111111-0000-4000-8000-000000000001 a1a1a1a1-0000-4000-8000-0000000000a1 magic-coordinator spawn-started running waiting 2026-10-12_16:57_+0300 - rig-host ws-rig waiting
	rigRow counters 1 1 1 0 0 0 0.42
} > "$rigF/rows.--manager-session-list"
echo rows > "$rigF/mode"

rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	: > "$MANAGER_SCREEN_RIG/stamps"
}
## The driver's commands on standard input, after the ones that name the stand-in and the time.
rigScript(){ ## the body of the script, on standard input
	{ printf 'tools bash %s\nworkspace %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize 120 40\n' "$rigStamp" "$MMDAPP" ; cat ; } \
		| "$rigPython" -I -B "$rigDriver" "$rigScreen" script > "$MANAGER_SCREEN_RIG/driver.out" 2>&1
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
## Sixty seconds of a screen nobody touches, ten seconds a step, which is the screen's own period.
quietTurns(){
	local step
	for step in 1 2 3 4 5 6 ; do
		printf 'advance 10\nturn\nturn\nturn\n'
	done
}
## The passes that overlapped another, as `START`/`END` stamps, or `none`. A pass opens on its START
## and closes on its END; a START arriving while one is open is two passes at once, whoever started them.
rigOverlaps(){
	LC_ALL=C awk '
		$0 ~ /--manager-session-list$/ {
			if ( $1 == "START" ) { if ( open ) { print "open since " openAt " ; another at " $2 ; bad = 1 } ; open = 1 ; openAt = $2 }
			else if ( $1 == "END" ) { open = 0 }
		}
		END { if ( !bad ) print "none" }
	' "$MANAGER_SCREEN_RIG/stamps" | LC_ALL=C sed -n 1p
}
rigPassSpans(){ ## every pass' span, oldest first, as `<start>..<end>`, for the reader of a failure
	LC_ALL=C awk '
		$0 ~ /--manager-session-list$/ { if ( $1 == "START" ) { start = $2 } else { printf "%s..%s ", start, $2 } }
		END { printf "\n" }
	' "$MANAGER_SCREEN_RIG/stamps"
}

echo "-- 1. the baseline: an opened screen reads the list once --"
rigCase baseline
rigScript <<RIGSCRIPT
at @activity
turn
wait sessions 5
RIGSCRIPT
rigBaseline="$( rigCalled '--manager-session-list' )"
rigAssert "one pass for the first read" "$rigBaseline" "1"

echo "-- 2. one screen left quiet for 60 s: no two of its passes overlap --"
rigCase quiet
rigScript <<RIGSCRIPT
at @activity
turn
wait sessions 5
$( quietTurns )
RIGSCRIPT
rigQuiet="$( rigCalled '--manager-session-list' )"
rigAssert "the quiet screen still reads the list, so this case is not vacuous" "$(( rigQuiet >= rigBaseline ))" "1"
rigAssert "no two list passes overlap, with one screen open" "$( rigOverlaps )" "none"
printf '        passes: %s\n' "$( rigPassSpans )"

echo "-- 3. two screens left quiet for 60 s: no two of their passes overlap --"
rigCase two
for rigWhich in a b ; do
	{ printf 'tools bash %s\nworkspace %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize 120 40\n' "$rigStamp" "$MMDAPP"
	  printf 'at @activity\nturn\nwait sessions 5\n' ; quietTurns ; } > "$rigTmp/script.$rigWhich"
	"$rigPython" -I -B "$rigDriver" "$rigScreen" script < "$rigTmp/script.$rigWhich" > "$MANAGER_SCREEN_RIG/driver.$rigWhich.out" 2>&1 &
done
wait
rigTwo="$( rigCalled '--manager-session-list' )"
rigAssert "both screens read the list, so this case is not vacuous" "$(( rigTwo > rigBaseline ))" "1"
rigAssert "no two list passes overlap, with two screens open" "$( rigOverlaps )" "none"
printf '        passes: %s\n' "$( rigPassSpans )"

echo
if [ "$rigFailCount" -gt 0 ] ; then
	echo "⛔ MANAGER SCREEN LIST COST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)"
	exit 1
fi
echo "✅ MANAGER SCREEN LIST COST CHECK: all $rigPassCount assertions hold"
exit 0
