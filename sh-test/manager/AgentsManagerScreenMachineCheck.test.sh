#!/usr/bin/env bash
## Behavioural check on `This Machine` in the manager screen (myx.distro-.local, sh-lib/manager/LocalManagerScreen.Machine.py), run rather than read. The screen's own code runs through the stand-in
## terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script that prints the fixture. Held: the root stands among the locations
## after `Workspace (System)`; it reads the two panels of the Dashboard that are about the machine, The Machine and Disk Space, by their names and by the one operation that prints the Dashboard
## (--manager-dashboard-read), once for its level; each panel is a row; the section shows both as the Dashboard draws panels, and a panel selected shows that one alone. It computes nothing. Offline.
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
[ -f "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/manager/LocalManagerScreen.Workspace.py" ] || rigRefuse "the part of .local is not at the origin"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenMachineCheck )" || exit 1
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
rigCase(){ ## name -- a fresh rig whose operation prints the two panels
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	{
		printf 'block\tmachine\tThe_Machine\t2\n'
		printf 'figure\tmachine\tload-1\tLoad_One_Minute\t6.17\t-\tok\t61\n'
		printf 'figure\tmachine\tprocessors\tProcessors_Online\t10\tcount\t-\t-\n'
		printf 'block\tdisk\tDisk_Space\t1\n'
		printf 'figure\tdisk\tworkspace-used\tWorkspace_Volume_Used\t672126955520\tbytes\tok\t71\n'
	} > "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read machine disk"
	: > "$MANAGER_SCREEN_RIG/calls" ; : > "$MANAGER_SCREEN_RIG/words" ; echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){
	rigOut="$( { printf 'tools bash %s\nwall 2026-10-13 02:30 +0000\nsize 140 40\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigCalled(){ ## words -- how many times the stand-in was started with exactly these words
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- the root and its panels --"
rigCase list
rigScript <<'RIGSCRIPT'
turn
at @machine
turn
wait list 10
rowids rows
show r
keys DOWN DOWN DOWN
wait focus 10
turn
get second
show s
RIGSCRIPT
rigAssert "the root holds the folder of the Local AI, then a row for each panel, The Machine then Disk Space" "$( rigVal rows )" ".. local-ai machine disk"
rigAssert "the section shows both panels, each by its label with its figures" "$( rigHolds r 'The Machine' ) $( rigHolds r 'Disk Space' ) $( rigHolds r 'Load One Minute' ) $( rigHolds r 'Processors Online' ) $( rigHolds r 'Workspace Volume Used' )" "2 2 1 1 1"
rigAssert "a panel selected shows that panel alone" "$( rigVal second.selectedLabel ) $( rigHolds s 'Workspace Volume Used' ) $( rigHolds s 'Load One Minute' )" "Disk Space 1 0"
rigAssert "the two panels were read by the one operation of the Dashboard, by their names, once" "$( rigCalled '--manager-dashboard-read machine disk' )" "1"

echo "-- the root stands after Workspace (System), among the locations --"
rigScript <<'RIGSCRIPT'
turn
root machine
turn
keys UP
turn
get before
root machine
turn
keys DOWN
turn
get after
RIGSCRIPT
rigAssert "the root before it is Workspace (System); the one after it is not a place of the screen's own (Settings)" "$( rigVal before.selectedLabel ) | $( rigVal after.selectedLabel )" "Workspace (System) | Settings"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN MACHINE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "MANAGER_SCREEN_MACHINE: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"
