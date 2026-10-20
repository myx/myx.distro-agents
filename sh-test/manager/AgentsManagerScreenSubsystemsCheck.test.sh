#!/usr/bin/env bash
## Behavioural check on the folder `Installed Subsystems` of the root `Configuration` of the manager screen (F11.7 of the refactorings epic), run rather
## than read. The screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call
## the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.stub.sh), which notes each start and prints the fixture: the rows
## `--manager-subsystem-list` prints.
## Held (F11.7: "`Installed Subsystems` displays the subsystem list with installed status, and indented commands to install or uninstall, as `Outside
## Systems` does. It does not allow uninstalling the current subsystem's console, or `.local`. Owned by `.local`"; the coordinator's ruling, "refusing
## .local and the console's own subsystem"):
##   1. the folder stands in `Configuration`, behind `Server Keys`, and is a part of `.local`: the python of it is a part in .local's sh-lib/manager that the
##      screen loads (LOCAL_PARTS), and a screen whose `.local` has no such part has no such folder and fails nowhere
##   2. entered, it lists the subsystems in the order of the operation, each with its state at the end of its row, and under it, set in by two, a row for
##      each command it is offered: Install for one that is missing, Uninstall for one that is installed and is not the console's own; .local, system
##      and the console's own (agents) have none
##   3. a subsystem selected shows what it is and what it is offered; a command selected shows the command line it runs
##   4. Enter on a command asks first, by the command and what it does; Cancel and Esc do nothing; Run runs `--manager-subsystem-run <install|uninstall>
##      <name>` in the big output dialog, with no other word, and the list is read again when it ends; Enter on a subsystem that has no command runs nothing
## Offline: no operation of the real tooling is called.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigTools="$rigFixtures/manager-screen.tools.stub.sh"
rigPart="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/manager/LocalManagerScreen.Subsystems.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenSubsystemsCheck )" || exit 1
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
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow subsystem .local installed base no no
	rigRow subsystem system installed shared no no
	rigRow subsystem deploy installed - no yes
	rigRow subsystem source missing - yes no
	rigRow subsystem remote installed - no yes
	rigRow subsystem agents installed console no no
} > "$rigF/rows.--manager-subsystem-list"
rigRow counters 0 0 0 0 0 0.42 > "$rigF/rows"
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
rigPane(){ ## tag, line counted from 1 -- the left pane's part of that line of the screen
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/^┌\(─\)* \(.*\) \(─\)*┐.*$/ \2/' -e 's/^╔\(═\)* \(.*\) \(═\)*╗.*$/ \2/' -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' -e 's/▲.*$//' -e 's/▼.*$//' -e 's/▒.*$//' -e 's/■.*$//' -e 's/  *$//'
}
rigScreenHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- 1. the folder stands in Configuration, behind Server Keys, a part of .local --"
rigCase folder
rigScript <<'RIGSCRIPT'
at @configuration
rowids ids
RIGSCRIPT
rigAssert "Configuration holds Installed Subsystems among the rows it always holds, behind the checker and the keys" "$( rigVal ids | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -x -e .. -e checker -e keys -e subsystems | LC_ALL=C tr '\n' ' ' )" ".. checker keys subsystems "
rigAssert "the python of the folder is a part of .local, which the screen names among the parts it loads from there" "$( [ -f "$rigPart" ] && echo part ) $( LC_ALL=C grep -c -F 'LocalManagerScreen.Subsystems.py' "$rigScreen" )" "part 1"

rigCase nopart
rigRealScreen="$rigScreen"
mkdir -p "$rigTmp/tree/myx/myx.distro-agents/sh-lib/manager"
cp "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/"*.py "$rigTmp/tree/myx/myx.distro-agents/sh-lib/manager/"
rigScreen="$rigTmp/tree/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
rigScript <<'RIGSCRIPT'
at @configuration
rowids ids
RIGSCRIPT
rigScreen="$rigRealScreen"
rigAssert "a screen whose .local has no such part has no such folder, and fails nowhere" "$( rigVal ids )" ".. checker keys git"

echo "-- 2. entered: the subsystems, each with its state, and its commands under it --"
rigCase entered
rigScript <<'RIGSCRIPT'
root subsystems
turn
keys ENTER
wait list 30
turn
get in
rowids ids
cells r2 3 85 119
cells r4 5 85 119
cells r5 6 85 119
cells r6 7 85 119
cells r7 8 85 119
cells r10 11 85 119
RIGSCRIPT
rigAssert "the operation was asked for the list, once, and nothing else of the operations of this folder" "$( rigCalled --manager-subsystem-list ) $( LC_ALL=C grep -c -F -e 'subsystem-run' "$MANAGER_SCREEN_RIG/calls" || : )" "1 0"
rigAssert "in the order of the operation, a command under each subsystem that is offered one, none under .local, system and agents" "$( rigVal ids )" ".. .local system deploy deploy:uninstall source source:install remote remote:uninstall agents"
rigAssert "each subsystem shows its state at the end of its row" "[$( rigVal r2 | sed 's/  */ /g' )][$( rigVal r4 | sed 's/  */ /g' )][$( rigVal r6 | sed 's/  */ /g' )][$( rigVal r10 | sed 's/  */ /g' )]" "[ .local installed][ deploy installed][ source missing][ agents installed]"
rigAssert "a command stands set in by two under its subsystem" "[$( rigVal r5 | sed 's/ *$//' )][$( rigVal r7 | sed 's/ *$//' )]" "[   Uninstall...][   Install...]"

echo "-- 3. the left pane --"
rigCase pane
rigScript <<'RIGSCRIPT'
root subsystems
turn
wait focus 30
turn
show f
keys ENTER
wait list 30
turn
keys DOWN DOWN DOWN
turn
show s
keys DOWN
turn
show c
RIGSCRIPT
rigAssert "the folder selected, before it is entered: the table of the subsystems under its head, and for each the command it is offered or why it has none" "[$( rigPane f 3 | LC_ALL=C tr -s ' ' )][$( rigPane f 5 | LC_ALL=C tr -s ' ' )][$( rigPane f 11 | LC_ALL=C tr -s ' ' )][$( rigPane f 13 | LC_ALL=C tr -s ' ' )][$( rigPane f 15 | LC_ALL=C tr -s ' ' )]" \
	"[ SUBSYSTEM STATE WHAT COMMAND][ .local installed local tool management: it the base that installs the][ deploy installed deploy-side operations uninstall][ source missing source sync, prepare and ingest install][ remote installed remote operations uninstall]"
rigAssert "a subsystem selected: what it is, its state, what it is offered" "$( rigScreenHolds s 'deploy-side operations' ) $( rigScreenHolds s 'uninstall' )" "1 1"
rigAssert "a command selected: the command line it runs" "$( rigScreenHolds c 'DistroLocalTools.fn.sh --uninstall-distro-deploy' )" "1"

echo "-- 4. Enter on a command asks first; Cancel and Esc do nothing; Run runs it in the output dialog --"
rigCase ask
rigScript <<'RIGSCRIPT'
root subsystems
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN DOWN
turn
get on
keys ENTER
turn
get asked
keys ESC
turn
get esc
keys ENTER
turn
keys TAB ENTER
turn
get cancelled
RIGSCRIPT
rigAssert "the selection is on the command of deploy" "$( rigVal on.selected )" "deploy:uninstall"
rigAssert "Enter asks first: a dialog titled by the command, which holds what it runs and by which operation" "$( rigVal asked.dialogTitle ) / $( rigVal asked.dialogHolds | LC_ALL=C grep -c -F -e 'uninstall deploy' )" "Uninstall deploy / 1"
rigAssert "Esc closes it, and Cancel does: no dialog is left, and nothing was run in all" "[$( rigVal esc.dialog )][$( rigVal cancelled.dialog )] $( LC_ALL=C grep -c -F -e 'subsystem-run' "$MANAGER_SCREEN_RIG/calls" || : )" "[][] 0"
rigCase run
rigScript <<'RIGSCRIPT'
root subsystems
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN DOWN
turn
keys ENTER
turn
keys ENTER
turn 2
get ran
wait follow 30
turn
get ended
RIGSCRIPT
rigAssert "Run runs the operation with exactly those words, in the output dialog titled by the command" "$( rigVal ran.dialogTitle ) $( rigCalled '--manager-subsystem-run uninstall deploy' )" "Uninstall deploy 1"
rigAssert "the list is read again when it ends" "$( rigCalled --manager-subsystem-list )" "2"

echo "-- 5. a subsystem with no command runs nothing --"
rigCase none
rigScript <<'RIGSCRIPT'
root subsystems
turn
keys ENTER
wait list 30
keys DOWN
turn
keys ENTER
turn
get on
RIGSCRIPT
rigAssert "Enter on .local, which has no command, opens no dialog and runs nothing" "[$( rigVal on.dialog )] $( rigVal on.selected ) $( LC_ALL=C grep -c -F -e 'subsystem-run' "$MANAGER_SCREEN_RIG/calls" || : )" "[] .local 0"

printf '\nTOTAL: %d passed, %d failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
