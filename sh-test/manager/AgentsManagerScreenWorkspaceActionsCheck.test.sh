#!/usr/bin/env bash
## Behavioural check on what `Workspace (System)` does besides showing (myx.distro-.local, sh-lib/manager/LocalManagerScreen.Workspace.py), run rather than read. The screen's own code runs through the
## stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script that prints the fixture. Held: the block of the
## commands of the workspace holds an indented row for each, and Enter on one asks first and then runs it by --manager-workspace-command-run, an unattended one in the big output dialog and one that
## needs the terminal given the terminal; an item that leads on (the mode, the sessions, a member) goes there on Enter, onto the level the reader named, from which Back goes up as it does anywhere; an item
## that leads nowhere does nothing. Offline.
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
rigTmp="$( rigTempDir AgentsManagerScreenWorkspaceActionsCheck )" || exit 1
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
rigCase(){ ## name -- a fresh rig whose operation prints the workspace, two commands, the agents block with two items that lead on and a member that does
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	{
		printf 'fact\t-\tname\tws-here\nfact\t-\tpath\t/rig/ws-here\n'
		printf 'block\tcommands\tCommands\t2\n'
		printf 'item\tcommands\t🖥️_Rig_Console\tterminal\tready\tmyx.distro-source\t-\n'
		printf 'item\tcommands\t⬇️_Rig_Pull\toutput\tready\tmyx.distro-source\t-\n'
		printf 'block\tagents\tAgents\t3\nfact\tagents\tmode\tteam-rig\n'
		printf 'item\tagents\tmode\tsetting\tteam-rig\tthe_settings_of_the_team\t@scopes/agents:magic-team\n'
		printf 'item\tagents\tsessions\tsessions\t3_recorded\tActivity\t@activity\n'
		printf 'item\tagents\tnothing\tthing\tok\t-\t-\n'
		printf 'block\tteam\tTeam_Members\t1\n'
		printf 'item\tteam\tkeeper-rig\tkeeper\tsource-symlink\t/rig/members/keeper-rig\t@team/keeper-rig\n'
	} > "$MANAGER_SCREEN_RIG/rows.--manager-workspace-read"
	printf 'ran\nthe rig command\n' > "$MANAGER_SCREEN_RIG/rows.--manager-workspace-command-run ⬇️_Rig_Pull"
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

echo "-- the commands of the workspace --"
rigCase commands
rigScript <<'RIGSCRIPT'
workspace /rig/Workspaces/ws-here
turn
at @workspace
turn
wait list 10
rowids rows
keys DOWN DOWN DOWN
wait focus 10
turn
get first
show a
keys ENTER
turn
get ask
show ask
keys ESC
turn
get cancelled
keys DOWN
turn
keys ENTER
turn
get ask2
keys ENTER
wait follow 5
get ran
RIGSCRIPT
rigAssert "the block of the commands holds an indented row for each command, by its name with its emoji, how it runs at the end" "$( rigVal rows )" ".. workspace commands 🖥️_Rig_Console ⬇️_Rig_Pull agents agents:mode agents:sessions agents:nothing team team:keeper-rig"
rigAssert "a command selected: the left window says which package declares it and how it runs" "$( rigVal first.selectedLabel ) $( rigHolds a ' myx.distro-source' ) $( rigHolds a ' with the whole terminal, as a console' )" "🖥️ Rig Console 1 1"
rigAssert "Enter asks first, naming the workspace by its name and how it will run; Esc runs nothing" "$( rigVal ask.dialog ) [$( rigVal ask.dialogTitle )] $( rigHolds ask 'workspace ws-here' ) [$( rigVal cancelled.dialog )]" "placecommand:run| [Run: 🖥️ Rig Console] 1 []"
rigAssert "one that runs unattended runs in the big output dialog by --manager-workspace-command-run, the command's name as the list gives it, and no location" "$( rigVal ran.dialog | LC_ALL=C sed 's/:.*//' ) $( LC_ALL=C grep -c -F -e '[--manager-workspace-command-run][⬇️_Rig_Pull]' "$MANAGER_SCREEN_RIG/words" || : ) $( LC_ALL=C grep -c -F -e 'place-command-run' "$MANAGER_SCREEN_RIG/words" || : )" "output 1 0"

echo "-- one that needs the terminal is given it --"
rigScript <<'RIGSCRIPT'
workspace /rig/Workspaces/ws-here
turn
at @workspace
turn
wait list 10
keys DOWN DOWN DOWN
wait focus 10
turn
keys ENTER
turn
keys ENTER
turn
turn
get started
RIGSCRIPT
rigAssert "the screen gives the terminal to the command, by the dispatcher and the same operation, from this workspace" "$( rigVal started.children ) $( rigVal started.childWords )" "1 [bash][$rigTools][--manager-workspace-command-run][🖥️_Rig_Console]"

echo "-- an item that leads on goes there --"
rigLead(){ ## name, how many rows down from the workspace row -- the path after Enter, and after Back
	rigScript <<RIGSCRIPT
workspace /rig/Workspaces/ws-here
turn
at @workspace
turn
wait list 10
keys $2
wait focus 10
turn
keys ENTER
turn
wait list 5
get after
keys BACKSPACE
turn
get back
RIGSCRIPT
}
rigLead mode "DOWN DOWN DOWN DOWN DOWN DOWN"
rigAssert "the mode leads to the settings of the team, where it is changed: onto the level, and Back goes up one" "$( rigVal after.path ) | $( rigVal back.path )" "settings/scopes/agents:magic-team | settings/scopes"
rigLead sessions "DOWN DOWN DOWN DOWN DOWN DOWN DOWN"
rigAssert "the sessions lead to Activity" "$( rigVal after.path ) | $( rigVal back.path )" "magic-team/activity | magic-team"
rigLead member "DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN"
rigAssert "a member leads to its folder in Team Members" "$( rigVal after.path ) | $( rigVal back.path )" "magic-team/team/keeper-rig | magic-team/team"
rigLead nothing "DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN"
rigAssert "an item that leads nowhere stays where it is" "$( rigVal after.path ) | $( rigVal back.path )" "workspace | "

if [ -n "${RIG_DUMP:-}" ] ; then printf '%s\n' "$rigOut" | cut -c1-110 | grep -E '^(a|ask)\|' | grep -v -E '│ *│║ *║' ; fi
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN WORKSPACE ACTIONS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "MANAGER_SCREEN_WORKSPACE_ACTIONS: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"
