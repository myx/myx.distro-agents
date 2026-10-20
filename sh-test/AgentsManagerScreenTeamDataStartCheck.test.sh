#!/usr/bin/env bash
## Behavioural check on when the root `Team Data` of the manager screen (sh-lib/manager/AgentsManagerScreen.py) stands in the list, run rather than
## read. The screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), started where the real
## screen starts (Manuals, never the Dashboard), and where it would call the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.stub.sh).
## Held: the root stands there at the start, with no visit to the Dashboard, where the workspace is a team rig whose team data is there, as the block of
## the team data of `--manager-dashboard-read` says (its `mode` figure, the gate's one reader, and its `present` figure, the context's root); it does
## not stand where the workspace is just agents (its mode, though the folder of the team data is there), nor where it is a team rig and the team data
## is not. It is decided again whenever anything may have changed it: at a refresh (u), and when a command ends, as a wizard or an edit of the settings
## does, so a workspace set to a team rig shows it with no restart, and one cleared hides it. Offline: no operation of the real tooling is called.
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
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenTeamDataStartCheck )" || exit 1
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
## The block of the team data of the dashboard, as the tooling prints it: its mode and whether the folder is there.
rigDashboard(){ ## mode, present (yes or no) -- the rows of `--manager-dashboard-read team-data`, and of the whole dashboard
	rigRow block team-data Team_Data 3
	rigRow figure team-data root Team_Data_Root /rig/ws/team-data - - -
	rigRow figure team-data mode Workspace_Mode "$1" - - -
	rigRow figure team-data present Team_Data_Present "$2" - "$( [ "$2" = yes ] && echo ok || echo bad )" -
	rigRow block machine The_Machine 1
	rigRow figure machine processors Processors_Online 10 count - -
}
rigCase(){ ## name, mode, present -- a fresh rig whose tooling says that
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	rigDashboard "$2" "$3" > "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read"
	: > "$MANAGER_SCREEN_RIG/calls" ; : > "$MANAGER_SCREEN_RIG/words" ; echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size: no root is named, the screen starts where it does
	rigOut="$( { printf 'tools bash %s\nwall 2026-10-13 02:30 +0000\nsize 120 36\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigReads(){ ## -- how many times the block of the team data was read, as the stand-in noted it in its file `here`
	LC_ALL=C grep -c -x -F -- '--manager-dashboard-read team-data' "$MANAGER_SCREEN_RIG/here" || :
}

echo "-- 1. at the start, with no visit to the Dashboard --"
rigCase rig team-rig yes
rigScript <<'RIGSCRIPT'
turn
get start
wait here 10
at @magic-team
turn
rowids rig
RIGSCRIPT
rigAssert "a team rig whose team data is there: the screen starts at Manuals, and Team Data stands in Magic-Team (Agents)" "$( rigVal start.selected ) $( rigVal rig )" "manuals .. activity pending team teamdata"
rigAssert "it was read at the start, by the block of the team data alone" "$( rigReads )" "1"
rigCase agents just-agents yes
rigScript <<'RIGSCRIPT'
wait here 10
at @magic-team
turn
rowids agents
RIGSCRIPT
rigAssert "a workspace that is just agents does not show it, though the folder of the team data is there" "$( rigVal agents )" ".. activity pending team"
rigCase nodata team-rig no
rigScript <<'RIGSCRIPT'
wait here 10
at @magic-team
turn
rowids nodata
RIGSCRIPT
rigAssert "a team rig whose team data is not there does not show it" "$( rigVal nodata )" ".. activity pending team"

echo "-- 2. decided again: a refresh, and the end of a command --"
rigDashboard just-agents yes > "$rigTmp/dash.agents"
rigDashboard team-rig yes > "$rigTmp/dash.rig"
rigDashboard team-rig no > "$rigTmp/dash.gone"
rigCase set just-agents yes
rigScript <<RIGSCRIPT
wait here 10
at @magic-team
turn
rowids before
copy $rigTmp/dash.rig $MANAGER_SCREEN_RIG/rows.--manager-dashboard-read
keys u
wait here 10
rowids after
copy $rigTmp/dash.agents $MANAGER_SCREEN_RIG/rows.--manager-dashboard-read
keys u
wait here 10
rowids cleared
RIGSCRIPT
rigAssert "a workspace set to a team rig after the screen started shows Team Data at the refresh, with no restart, and cleared of it hides it at the next" "$( rigVal before ) / $( rigVal after ) / $( rigVal cleared )" ".. activity pending team / .. activity pending team teamdata / .. activity pending team"
## the end of a command: the one that Team Data runs writes what a wizard writes, the settings, here the answer of the tooling
rigCase run team-rig yes
printf 'script purge.sh\n' > "$MANAGER_SCREEN_RIG/mode.--owner-cleanup-purge"
printf 'echo "purge: done"\ncp "%s" "%s"\n' "$rigTmp/dash.agents" "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read" > "$MANAGER_SCREEN_RIG/purge.sh"
rigScript <<RIGSCRIPT
wait here 10
turn
wait list 10
at @teamdata
turn
wait list 10
wait also 10
keys DOWN ENTER
wait list 10
keys DOWN
turn
get inside
keys ENTER ENTER
wait follow 10
get ended
keys ENTER
wait here 10
turn
at @magic-team
turn
rowids end
RIGSCRIPT
rigAssert "it runs a command of Team Data, which sets the workspace to just agents as it ends: the dialog is OK alone, and when it is closed the root is gone" "$( rigVal inside.path ) $( rigVal ended.dialog ) / $( rigVal end )" "magic-team/teamdata/operations output:ok| / .. activity pending team"
rigAssert "the end of the command asked for the block again, once more than the start and no refresh did" "$( rigReads )" "2"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN TEAM DATA START CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "MANAGER_SCREEN_TEAM_DATA_START: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"
