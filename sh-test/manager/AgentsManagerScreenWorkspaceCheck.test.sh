#!/usr/bin/env bash
## Behavioural check on `Workspace (System)` in the manager screen (myx.distro-.local, sh-lib/manager/LocalManagerScreen.Workspace.py), run rather than read (F11.10). The screen's own code
## runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh) that prints the fixture. Held: the root stands among the locations, and holds a row for the workspace by its name, then a row for each block
## --manager-workspace-read prints, by its label, with the number of its items at the end, and under it an indented row for each item with its state at the end; the section selected
## shows the facts of the workspace and every block under its label, its facts and its items as a table; the row of the workspace shows its facts; a block shows its facts and its items;
## an item shows what it is. It reads the operation once and computes nothing: a block it knows nothing of is drawn as every other, and a path stands as it is. Offline.
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
rigTmp="$( rigTempDir AgentsManagerScreenWorkspaceCheck )" || exit 1
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
rigCase(){ ## name -- a fresh rig whose operation prints the workspace, three subsystems, the agents block and two members
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	{
		printf 'fact\t-\tname\tws-here\nfact\t-\tpath\t/rig/ws-here\nfact\t-\ttooling\tsource\nfact\t-\ttooling-path\t/rig/ws-here/source\nfact\t-\taccount\tkeeper\n'
		printf 'block\tpackages\tInstalled_Subsystems\t3\n'
		printf 'item\tpackages\t.local\tsubsystem\tinstalled\t-\nitem\tpackages\tsystem\tsubsystem\tinstalled\t-\nitem\tpackages\tagents\tsubsystem\tinstalled\t-\n'
		printf 'block\tagents\tAgents\t0\nfact\tagents\tmode\tteam-rig\nfact\tagents\tteam-data\tyes\n'
		printf 'block\tteam\tTeam_Members\t2\n'
		printf 'item\tteam\tkeeper-rig\tkeeper\tsource-symlink\t/rig/ws-here/.local/agents/members/keeper-rig\n'
		printf 'item\tteam\todd-one\todd\tnot-in-registry\t/rig/ws-here/.local/agents/members/odd-one\n'
	} > "$MANAGER_SCREEN_RIG/rows.--manager-workspace-read"
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

echo "-- the root, its rows and the summary --"
rigCase list
rigScript <<'RIGSCRIPT'
turn
at @workspace
turn
wait list 10
rowids rows
show r
RIGSCRIPT
rigAssert "the root holds a row for the workspace, and a row for each block with an indented row for each of its items" "$( rigVal rows )" ".. workspace packages packages:.local packages:system packages:agents agents team team:keeper-rig team:odd-one"
rigAssert "the rows: the workspace by its name; a block by its label, the number of its items at the end; an item indented, its state at the end" "$( rigHolds r '║ ws-here ' ) $( rigHolds r ' Installed Subsystems                  3' ) $( rigHolds r '   .local                      installed' ) $( rigHolds r ' Team Members                          2' ) $( rigHolds r '   odd-one               not-in-registry' )" "1 1 1 1 1"
rigAssert "the section shows the facts of the workspace, then each block under its label: its facts, and its items as a table" "$( rigHolds r ' tooling from  source' ) $( rigHolds r ' runs as       keeper' ) $( rigHolds r '│Installed Subsystems  ' ) $( rigHolds r '  NAME    KIND       STATE      WHERE' ) $( rigHolds r ' mode       team-rig' ) $( rigHolds r ' team data  yes' ) $( rigHolds r '  keeper-rig  keeper  source-symlink   /rig/ws-here/.local/agents/members/keeper-rig' )" "1 1 1 1 1 1 1"
rigAssert "the operation was read once, by its name, whole" "$( rigCalled '--manager-workspace-read' )" "1"

echo "-- the rows selected --"
rigScript <<'RIGSCRIPT'
turn
at @workspace
turn
wait list 10
keys DOWN
wait focus 10
turn
show a
keys DOWN DOWN DOWN DOWN DOWN
wait focus 10
turn
show b
keys DOWN
wait focus 10
turn
show c
keys DOWN
wait focus 10
turn
show d
RIGSCRIPT
rigAssert "the workspace selected shows its facts: name, path, where its tooling comes from, that tooling's path, the account the console runs as" "$( rigHolds a ' name          ws-here' ) $( rigHolds a ' path          /rig/ws-here' ) $( rigHolds a ' tooling from  source' ) $( rigHolds a ' tooling path  /rig/ws-here/source' ) $( rigHolds a ' runs as       keeper' )" "1 1 1 1 1"
rigAssert "the block of the agents shows its facts: the mode and whether the workspace keeps team data" "$( rigHolds b ' mode       team-rig' ) $( rigHolds b ' team data  yes' )" "1 1"
rigAssert "the block of the members shows its items as a table: the member, its kind, how it is set up, and its folder" "$( rigHolds c '  NAME        KIND    STATE            WHERE' ) $( rigHolds c '  odd-one     odd     not-in-registry  /rig/ws-here/.local/agents/members/odd-one' )" "1 1"
rigAssert "an item shows what it is: its block, kind, state in its colour and where" "$( rigHolds d ' block  Team Members' ) $( rigHolds d ' kind   keeper' ) $( rigHolds d ' state  source-symlink' ) $( rigHolds d ' where  /rig/ws-here/.local/agents/members/keeper-rig' )" "1 1 1 1"

echo "-- a block it knows nothing of, and a path that lies in a location --"
rigCase other
{
	printf 'fact\t-\tname\tws-here\nfact\t-\tpath\t/rig/ws-here\n'
	printf 'block\tzed\tZed_Things\t1\nfact\tzed\tsome-fact\tlooks_so\nitem\tzed\tone\tthing\tok\t/rig/ws-here/zed/one\n'
} > "$MANAGER_SCREEN_RIG/rows.--manager-workspace-read"
printf 'place\tws-here\tWs_Here\tworkspace\tread-write\t/rig/ws-here\tpresent\tyes\t0\n' > "$MANAGER_SCREEN_RIG/rows.--manager-place-list"
rigScript <<'RIGSCRIPT'
turn
wait list 10
at @workspace
turn
wait list 10
rowids rows
show o
RIGSCRIPT
rigAssert "a block of a name it was never told is drawn like every other: its label, its fact by its name with the dashes read as blanks and its value as it was written, its item" "$( rigVal rows ) | $( rigHolds o '│Zed Things' ) $( rigHolds o ' some fact  looks_so' ) $( rigHolds o '  one   thing  ok     ' )" ".. workspace zed zed:one | 1 1 1"
rigAssert "a path stands as it is, whole, though it lies in a location the screen knows by a name; the path of the item too" "$( rigHolds o ' path  /rig/ws-here' ) $( rigHolds o '/rig/ws-here/zed/one' ) $( rigHolds o 'ws-here:' )" "1 1 0"

if [ -n "${RIG_DUMP:-}" ] ; then printf '%s\n' "$rigOut" | cut -c1-110 | grep -E '^(c|d|o)\|' | grep -v -E '│ *│║ *║' ; fi
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN WORKSPACE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "MANAGER_SCREEN_WORKSPACE: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"
