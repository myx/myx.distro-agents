#!/usr/bin/env bash
## Behavioural check on `Manuals (Help)` in the console app (F11.9 of the refactorings epic): it is the default root
## selection; it holds `User Manuals` (the README.md files of the build sequence), `Tooling Commands` (the existing
## feature of `Configuration`, moved here) and `Maintainer Manuals` (the MAGIC.md files). Run rather than read: the
## screen's own code through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py) and the
## stand-in dispatcher (check-fixtures/manager-screen.tools.stub.sh).
## Held:
##   1. at start, with no root asked for, the selection is on Manuals (Help)
##   2. inside it, its rows are User Manuals, Tooling Commands and Maintainer Manuals, in that order
##   3. Tooling Commands there is the existing feature: resting on it reads --manager-command-list
##   4. Configuration holds Tooling Commands no more
## Red before F11.9: the start selects another root, Manuals holds none of the three, and Configuration still holds
## Tooling Commands.
## Not tested, for want of a name: the operation that lists the README and MAGIC files of the build sequence, so the
## build order, the `a` key's alphabetical order and the project names are not asserted.
## Offline: no operation of the real tooling is called.
## Reconciled for F11.5: the list of the sessions is Active Sessions of Activity (`root active-sessions`), and Configuration is the seventh root, key 7.
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
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsManagerScreenManualsFoldersCheck.XXXXXX" )" || exit 1
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
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
printf 'subject\tworkspace\t1\tWorkspace_Paths\nline\tworkspace\tpaths\tworkspace-root\tset\t/rig/ws_rig\tWorkspace_Root\t-\tno:set_at_deployment\t-\t-\t-\t-\t-\tconfiguration\n' > "$rigF/rows.--manager-config-digest"
printf '%s\t%s\n' DistroAgentsTools.fn.sh /rig/Workspaces/ws-one/source/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh > "$rigF/rows.--manager-command-list"
rigCase(){ ## name -- a fresh rig: a copy of the fixtures, no call noted yet
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls" ; : > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigRun(){ ## the preamble, then the commands on standard input; what the driver printed is kept in rigOut
	rigOut="$( { printf '%s' "$1" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigPre="$( printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize 120 40\n' "$rigTools" )"$'\n'
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigCellsCmds(){ ## -- the cells of the right pane, lines 3 to 14
	local cellsLine
	for cellsLine in 3 4 5 6 7 8 9 10 11 12 13 14 ; do printf 'cells r%s %s 85 119\n' "$cellsLine" "$cellsLine" ; done
}
rigRows(){ ## -- the rows read by rigCellsCmds, each between brackets, blank lines (spacers) left out
	local rowsLine rowsText rowsList=""
	for rowsLine in 3 4 5 6 7 8 9 10 11 12 13 14 ; do
		rowsText="$( rigVal "r$rowsLine" | LC_ALL=C sed -e 's/^ *//' -e 's/ *[►~].*$//' -e 's/  *$//' )"
		[ -z "$rowsText" ] || rowsList="$rowsList[$rowsText]"
	done
	printf '%s' "$rowsList"
}

echo "-- 1. the default root selection --"
rigCase start
rigRun "$rigPre" <<'RIGSCRIPT'
turn
turn
get start
RIGSCRIPT
rigAssert "with no root asked for, the selection is on Manuals (Help)" "$( rigVal start.selectedLabel )" "Manuals (Help)"

echo "-- 2. its three rows, in order --"
rigCase inside
rigRun "$rigPre"$'root manuals\n' < <( printf 'turn\nkeys ENTER\nwait list 30\nturn\nget in\n' ; rigCellsCmds )
rigInside="$( rigRows )"
rigAssert "User Manuals, Tooling Commands, Maintainer Manuals lead its rows" "$( printf '%s' "$rigInside" | LC_ALL=C cut -c1-60 )" "[User Manuals][Tooling Commands][Maintainer Manuals]"

echo "-- 3. Tooling Commands there reads the command list --"
rigCase commands
rigRun "$rigPre"$'root manuals\n' <<'RIGSCRIPT'
turn
keys ENTER
wait list 30
keys DOWN DOWN
wait focus 30
wait view 30
turn
get on
RIGSCRIPT
rigAssert "resting on it: it is Tooling Commands, and --manager-command-list was read" "$( rigVal on.selectedLabel ) $( LC_ALL=C grep -c -x -e '--manager-command-list' "$MANAGER_SCREEN_RIG/calls" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/read/' )" "Tooling Commands read"

echo "-- 4. Configuration holds Tooling Commands no more --"
rigCase configuration
rigRun "$rigPre"$'root active-sessions\n' < <( printf 'turn\nkeys 7\nwait list 30\nturn\n' ; rigCellsCmds )
rigConfiguration="$( rigRows )"
rigAssert "Configuration's rows are read, and Tooling Commands is none of them" "$( [ -n "$rigConfiguration" ] && echo read || echo none ) $( printf '%s' "$rigConfiguration" | LC_ALL=C grep -q -F '[Tooling Commands]' && echo held || echo gone )" "read gone"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN MANUALS FOLDERS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_MANUALS_FOLDERS: OK (%d assertions, offline, stand-in terminal)\n' "$rigPassCount"
