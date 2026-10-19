#!/usr/bin/env bash
## Behavioural check on the root `Team Data` of the manager screen (sh-lib/manager/AgentsManagerScreen.py) and on its
## `Operations`, its cleanups and its sync, run in the big output dialog, run rather than read. The screen's own code runs through the stand-in
## terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it
## calls a stand-in script (check-fixtures/manager-screen.tools.stub.sh), which notes each start and prints the
## fixture, or becomes a script of the rig that writes on both streams over time and ends as it is told.
## Held: the root stands after Team Members only where the dashboard says that the team data is there, the number
## keys follow the list as it is shown, so where it is not the roots after it keep their numbers, and its item of the
## menu Go says why it does nothing; its summary says where the team data is, the mode of the workspace from
## the digest, the remote and the branch, the board by state, and the main loop where the read gives one, judged
## only on a full team rig; a cleanup that needs a team rig is greyed in another mode, with the mode's label; a
## cleanup is asked first, then runs as a child whose two streams are followed in order while the screen keeps
## turning, its result said in a line of its own, by a status or by a signal, with OK alone after it; Esc while it
## runs asks whether to stop it, and Stop it ends it by SIGTERM; the text follows its end until it is scrolled up.
## The operations are called exactly as the tooling has them. Offline: no operation of the real tooling is called.
## Reconciled for F11.0: `Launch / Spawn` is named `Launch (Start)`, `Consoles (Tools)` `Consoles`.
## Reconciled for F11.0, the table lines: two spaces between the columns of the tables of the dashboard.
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
rigTmp="$( rigTempDir AgentsManagerScreenTeamDataCheck )" || exit 1
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
## The dashboard of a team rig whose team data is there, with its board and its main loop; and the digest of the
## settings in the two forms a mode takes: a full team rig, its team data with a git remote, and a workspace that
## is just agents, with no remote.
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
rigDescribed="A_line_of_the_rig,_as_the_digest_describes_it."
rigDeployed="no:set_at_deployment:_a_wizard_will_change_it"
{
	rigRow block team-data Team_Data 5
	rigRow figure team-data root Team_Data_Root /rig/ws/team-data - - -
	rigRow figure team-data present Team_Data_Present yes - ok -
	rigRow figure team-data size Team_Data_Size 81309696 bytes - -
	rigRow figure team-data board-running Board_Items_Running 43 count - -
	rigRow figure team-data board-review Board_Items_Review 142 count - -
	rigRow block team-data-git Team_Data_Git 8
	rigRow figure team-data-git repository Team_Data_Repository yes - - -
	rigRow figure team-data-git branch Team_Data_Branch main - - -
	rigRow figure team-data-git upstream Team_Data_Upstream origin/main - - -
	rigRow figure team-data-git ahead Commits_Ahead 2 count bad -
	rigRow figure team-data-git behind Commits_Behind 1 count bad -
	rigRow figure team-data-git uncommitted Paths_Not_Committed 3 count warn -
	rigRow figure team-data-git last-commit Last_Commit 7500 seconds - -
	rigRow figure team-data-git last-subject Last_Commit_Subject the_last_change - - -
	rigRow block loop Main_Loop_And_Heartbeat 2
	rigRow figure loop main-loop-outcome Main_Loop_Last_Outcome failed - bad -
	rigRow figure loop main-loop-failures Main_Loop_Consecutive_Failures 1 count warn -
	rigRow block machine The_Machine 1
	rigRow figure machine processors Processors_Online 10 count - -
} > "$rigF/dashboard.rig"
LC_ALL=C grep -v -e $'\tloop\t' -e $'^block\tloop' "$rigF/dashboard.rig" > "$rigF/dashboard.agents"
LC_ALL=C grep -v -e $'team-data' "$rigF/dashboard.agents" > "$rigF/dashboard.none"
rigDigest(){ ## mode, full-team-rig state, full-team-rig value, remote state, remote value
	rigRow subject workspace 2 Workspace_Paths
	rigRow group workspace mode 2 Workspace_Role
	rigRow line workspace mode MDAT_WORKSPACE_MODE set "$1" Workspace_Mode "$rigDescribed" "$rigDeployed" choice workspace workspace just-agents=Just_Agents,rig-client=Remote_Rig_Client,team-rig=Team_Rig /rig/ws/.local/.agents/magic-team.agent.env configuration
	rigRow line workspace mode full-team-rig "$2" "$3" Full_Team_Rig "$rigDescribed" "$rigDeployed" - - - - - configuration
	rigRow subject scopes 1 Scope_Settings
	rigRow group scopes magic-team 1 magic-team
	rigRow line scopes magic-team TEAM_DATA_GIT_REMOTE "$4" "$5" Team_Data_Git_Remote "$rigDescribed" "$rigDeployed" - - - - - configuration
}
rigDigest team-rig set yes set git@rig.invalid:team-data.git > "$rigF/digest.full"
rigDigest team-rig missing no missing - > "$rigF/digest.plain"
rigDigest just-agents missing no missing - > "$rigF/digest.agents"

rigCase(){ ## name, dashboard (rig, agents or none), digest (full, plain or agents)
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	LC_ALL=C grep -v -e 'team-data-git' "$rigF/dashboard.$2" > "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read"
	LC_ALL=C grep -v -e 'machine' "$rigF/dashboard.$2" > "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read team-data team-data-git loop"
	cp "$rigF/digest.$3" "$MANAGER_SCREEN_RIG/rows.--manager-config-digest --full"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\nwall 2026-10-13 02:30 +0000\nsize 120 36\nroot dashboard\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigFolderHolds(){ ## tag, text -- how many lines of that whole screen hold the text and, on the same line, the mark of a folder: a row that is one
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -F -- "$2" | LC_ALL=C grep -c -F '►' || :
}
rigHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigLeft(){ ## tag -- what the left window of that screen holds: its lines that hold something, without the frame, a ` / ` between two
	RIG_OUT="$rigOut" "$rigPython" -I -B -c '
import os, re, sys
held = []
for line in os.environ["RIG_OUT"].split("\n"):
    found = re.match(r"^%s\|[│║](.*?)[│║▒▲▼■]" % re.escape(sys.argv[1]), line)
    if found and found.group(1).strip():
        held.append(found.group(1).rstrip())
print(" / ".join(held))
' "$1"
}
rigWords(){ ## text -- how many starts of the stand-in had exactly these words, each between brackets
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/words" || :
}
## The way to the operations: the root by its number, with the digest read beside its list, then into `Operations`,
## its first row selected.
rigToCleanup='turn
wait list 10
keys 5
wait list 10
wait also 10
keys DOWN ENTER
wait list 10
keys DOWN
turn'

echo "-- 1. the root: there only where the team data is --"
rigCase none none agents
rigScript <<'RIGSCRIPT'
turn
wait list 10
get root
keys 5
get five
keys 9
get nine
keys m
turn
show go
keys m
keys ESC
keys ALT-g m
get chosen
RIGSCRIPT
rigAssert "with no team data the root list holds the nine roots and no Team Data" "$( rigVal root.rows ) $( rigHolds root 'Team Data' )" "9 0"
rigAssert "the numbers follow the list as it is shown: 5 is Locations (Places) and 9 Manuals (Help), as with no such root" "$( rigVal five.path ) $( rigVal nine.path )" "places manuals"
rigAssert "the menu Go names Team Data with no number, after Team Members, and the roots after it with theirs" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^go|' | LC_ALL=C grep -o -e 'Team Members  *4 ' -e 'Team Data  *[0-9]* ' -e 'Locations (Places)  *5 ' -e 'Manuals (Help)  *9 ' | LC_ALL=C sed 's/   */ /g;s/ $//' | LC_ALL=C tr '\n' '|' )" "Team Members 4|Team Data|Locations (Places) 5|Manuals (Help) 9|"
rigAssert "chosen there it does nothing and says why in the status line" "$( rigVal chosen.path ) $( rigVal chosen.notice )" "manuals Team Data: no team data is configured for this workspace"
rigCase full rig full
rigScript <<'RIGSCRIPT'
turn
wait list 10
get root
keys m
turn
show go
keys ESC
keys DOWN DOWN DOWN DOWN
wait focus 10
wait focus 10
get on
show on
keys 5
wait list 10
get in
show in
RIGSCRIPT
rigAssert "where the dashboard says the team data is there, Team Data is the fifth of ten roots, after Team Members" "$( rigVal root.rows ) $( rigVal on.index ) $( rigVal on.selectedLabel )" "10 4 Team Data"
rigAssert "and the numbers follow: 5 is Team Data, the roots after it one more, and Launch (Start) has none past nine" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^go|' | LC_ALL=C grep -o -e 'Team Data  *[0-9]* │' -e 'Locations (Places)  *[0-9]* │' -e 'Configuration  *[0-9]* │' -e 'Launch (Start)  *[0-9]* │' | LC_ALL=C sed 's/ *│$//;s/   */ /g;s/ $//' | LC_ALL=C tr '\n' '|' )" "Team Data 5|Locations (Places) 6|Configuration 9|Launch (Start)|"
rigAssert "selected, its summary says as its caption that the team data is there and its size, then where it is and the mode of the workspace" "$( rigHolds on '│Team data: there, 77.5M.' ) $( rigHolds on '│ root    /rig/ws/team-data' ) $( rigHolds on '│ mode    Team Rig, saved for the workspace; a full team rig' )" "1 1 1"
rigAssert "its git state, nicely, as facts under a heading: where it stands and what it tracks, ahead and behind, what is not committed, each in the look of its level, and its last commit" "$( rigHolds on '│Git ' ) $( rigHolds on '│ branch       main, tracking origin/main' ) $( rigHolds on '│ ahead        2' ) $( rigHolds on '│ behind       1' ) $( rigHolds on '│ uncommitted  3' ) $( rigHolds on '│ last commit  2h 5m ago: the last change' )" "1 1 1 1 1 1"
rigAssert "then the remote and the branch of the team data, its board by state as a table, and the main loop as a table, judged on a full team rig" "$( rigHolds on '│ remote  git@rig.invalid:team-data.git' ) $( rigHolds on "│ branch  not set: the tooling's own" ) $( rigHolds on '│  running  43' ) $( rigHolds on '│Main loop and heartbeat ' ) $( rigHolds on 'Main Loop Last Outcome          failed  (bad)' )" "1 1 1 1 1"
rigAssert "focused, it read its blocks of the dashboard, its git state among them, and the digest of the settings, as they are called" "$( rigWords '[--manager-dashboard-read][team-data][team-data-git][loop]' | LC_ALL=C awk '{ print ( $1 > 0 ) }' ) $( rigWords '[--manager-config-digest][--full]' | LC_ALL=C awk '{ print ( $1 > 0 ) }' )" "1 1"
rigAssert "entered, it holds Operations, its three stores and its blocks: the team data, its git state and the main loop" "$( rigVal in.path ) $( rigVal in.rows ) $( rigFolderHolds in ' Operations ' ) $( rigHolds in ' Team Data Git' ) $( rigHolds in ' Main Loop And Heartbeat' ) $( rigHolds in ' The Machine' )" "teamdata 8 1 1 1 0"

echo "-- 2. the main loop by the mode of the workspace --"
rigCase plain rig plain
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys DOWN DOWN DOWN DOWN
wait focus 10
wait focus 10
show on
RIGSCRIPT
rigAssert "a team rig with no shared persistence shows its main loop plain, and says so" "$( rigHolds on '│ remote  none: no shared persistence is set' ) $( rigHolds on 'Main loop and heartbeat (not judged here: a full team rig alone is)' ) $( rigHolds on 'a full team rig' )" "1 1 1"
rigCase agents agents agents
rigScript <<RIGSCRIPT
turn
wait list 10
keys DOWN DOWN DOWN DOWN
wait focus 10
wait focus 10
show on
$rigToCleanup
get purge
show purge
keys DOWN
turn
show gc
keys ENTER
get gc
cells st 35 0 120
keys DOWN
turn
show sync
RIGSCRIPT
rigAssert "a workspace that is just agents has no main loop, and its summary says so" "$( rigHolds on '│ mode    Just Agents, saved for the workspace' ) $( rigHolds on 'No main loop here: a workspace has one in the mode team-rig alone.' ) $( rigHolds on 'Main Loop' )" "1 1 0"
rigAssert "there Operations shows each operation, what it does, what it runs, and that it is offered" "$( rigVal purge.path ) $( rigVal purge.selectedLabel ) $( rigHolds purge 'Empties the cleanup folder of this workspace' ) $( rigHolds purge 'runs   --owner-cleanup-purge' ) $( rigHolds purge 'here   offered' )" "teamdata/operations Purge The Cleanup Folder 1 1 1"
rigAssert "the sync of the team data is not offered where no git remote of it is set" "$( rigHolds sync 'runs   --magic-team-data-commit-pending magic-coordinator' ) $( rigHolds sync 'here   not offered: no git remote of the team data is set' )" "1 1"
rigAssert "the one that needs a team rig is not offered, with the label of the mode" "$( rigHolds gc 'runs   --intern-team-data-final-gc-deletion magic-coordinator' ) $( rigHolds gc 'here   not offered: for a team rig alone: this workspace is Just' )" "1 1"
rigAssert "Enter on it opens nothing and says why in the status line, and nothing is called" "[$( rigVal gc.dialog )] $( rigVal gc.notice ) / $( rigWords '[--intern-team-data-final-gc-deletion][magic-coordinator]' )" "[] Run the operation: for a team rig alone: this workspace is Just Agents / 0"

echo "-- 3. a cleanup runs in the big output dialog, followed while it writes --"
rigCase run rig agents
printf 'script purge.sh\n' > "$MANAGER_SCREEN_RIG/mode.--owner-cleanup-purge"
cat > "$MANAGER_SCREEN_RIG/purge.sh" <<'RIGCHILD'
echo "purge: the first line, on standard output"
sleep 1.5
echo "purge: the second line, on standard error" >&2
printf 'purge:\ta tab, \033[1ma sequence\033[0m and a mark ⛔\n'
exit 3
RIGCHILD
rigScript <<RIGSCRIPT
$rigToCleanup
keys ENTER
get ask
show ask
keys ENTER
wait follow 0.6
get running
show running
cells st 35 0 120
wait follow 10
get ended
show ended
cells end 35 0 120
keys ENTER
get closed
RIGSCRIPT
rigAssert "Enter asks first: what will run, its operation, and Run or Cancel" "$( rigVal ask.dialog ) [$( rigVal ask.dialogTitle )] $( rigHolds ask 'operation --owner-cleanup-purge' ) $( rigHolds ask ' »Run« ▅   Cancel  ▅' )" "cleanup:run| [Run: Purge The Cleanup Folder] 1 1"
rigAssert "Run opens the big dialog, most of the screen, that runs it: its first line is there while it still runs" "$( rigVal running.dialog ) $( rigVal running.dialogBox ) [$( rigVal running.dialogHolds )] $( rigVal running.reading | LC_ALL=C grep -c -F 'follow:' )" "output:stop| 2,1,116,34 [purge: the first line, on standard output / It runs: Esc or Stop asks whether to stop it.] 1"
rigAssert "the status line names only its keys while it runs: Enter and Esc ask whether to stop it" "$( rigVal st | LC_ALL=C sed 's/  */ /g' )" " ENTER Stop ESC Stop"
rigAssert "at its end it holds both streams in the order they were written, a tab as spaces and no sequence of a terminal" "$( rigVal ended.dialogHolds | LC_ALL=C sed 's/ \/ Ended with.*//' )" "purge: the first line, on standard output / purge: the second line, on standard error / purge:  a tab, a sequence and a mark ⛔"
rigAssert "and its result in a line of its own, the status and how long it ran; OK alone; the status line says it too" "$( rigVal ended.dialogHolds | LC_ALL=C sed -n 's/.* \/ \(Ended with status 3, after [0-9.]*s\.\)$/\1/p' | LC_ALL=C sed 's/[0-9.]*s\.$/Ns./' ) $( rigVal ended.dialog ) $( rigVal ended.notice | LC_ALL=C sed 's/[0-9.]*s\.$/Ns./' )" "Ended with status 3, after Ns. output:ok| Purge The Cleanup Folder: Ended with status 3, after Ns."
rigAssert "OK closes it; the operation was called once, exactly as the tooling has it" "[$( rigVal closed.dialog )] $( rigWords '[--owner-cleanup-purge]' )" "[] 1"

echo "-- 4. an end by a signal, and Esc while it runs --"
rigCase signal rig full
printf 'script killed.sh\n' > "$MANAGER_SCREEN_RIG/mode.--intern-team-data-final-gc-deletion"
printf 'echo "gc: about to be ended"\nkill -KILL $$\n' > "$MANAGER_SCREEN_RIG/killed.sh"
rigScript <<RIGSCRIPT
$rigToCleanup
keys DOWN ENTER ENTER
wait follow 10
get ended
RIGSCRIPT
rigAssert "a team rig offers the cleanup that needs one, and calls it as the tooling has it, with its member" "$( rigWords '[--intern-team-data-final-gc-deletion][magic-coordinator]' )" "1"
rigAssert "one that ends by a signal says the signal by its number and its name" "$( rigVal ended.dialogHolds | LC_ALL=C sed 's/[0-9.]*s\.$/Ns./' )" "gc: about to be ended / Ended by signal 9 (SIGKILL), after Ns."
rigCase sync rig full
printf 'script synced.sh\n' > "$MANAGER_SCREEN_RIG/mode.--magic-team-data-commit-pending"
printf 'echo "TEAM-DATA-NOTHING-PENDING: /rig/ws/team-data"\n' > "$MANAGER_SCREEN_RIG/synced.sh"
rigScript <<RIGSCRIPT
$rigToCleanup
keys DOWN DOWN ENTER ENTER
wait follow 10
get ended
RIGSCRIPT
rigAssert "where a git remote is set the sync is offered, runs the tooling's own commit and push as it is, and ends with status 0" "$( rigWords '[--magic-team-data-commit-pending][magic-coordinator]' ) $( rigVal ended.dialogHolds | LC_ALL=C sed 's/[0-9.]*s\.$/Ns./' )" "1 TEAM-DATA-NOTHING-PENDING: /rig/ws/team-data / Ended with status 0, after Ns."
rigCase stop rig agents
printf 'script slow.sh\n' > "$MANAGER_SCREEN_RIG/mode.--owner-cleanup-purge"
printf 'echo "slow: up"\nsleep 20\necho "slow: never"\n' > "$MANAGER_SCREEN_RIG/slow.sh"
rigScript <<RIGSCRIPT
$rigToCleanup
keys ENTER ENTER
wait follow 0.6
keys ESC
get asked
cells st 35 0 120
keys ESC
get goon
keys ESC
keys ENTER
wait follow 10
get stopped
RIGSCRIPT
rigAssert "Esc while it runs does not close it: it asks whether to stop it, and Stop it and Go on are its buttons" "$( rigVal asked.dialog ) [$( rigVal asked.dialogSays )] [$( rigVal st | LC_ALL=C sed 's/  */ /g' )]" "output:stop| [Stop it? Stop it sends it SIGTERM; Go on and Esc let it run.] [ ←/→ Buttons ENTER Stop it TAB Next ESC Go on]"
rigAssert "Esc again lets it run on" "$( rigVal goon.dialog ) [$( rigVal goon.dialogSays )]" "output:stop| [It runs on.]"
rigAssert "Stop it ends it by SIGTERM: the result says so, and the dialog stays for OK" "$( rigVal stopped.dialogHolds | LC_ALL=C sed 's/[0-9.]*s\.$/Ns./' ) / $( rigVal stopped.dialog )" "slow: up / Ended by signal 15 (SIGTERM), after Ns. / output:ok|"

echo "-- 5. the text follows its end until it is scrolled up --"
rigCase follow rig agents
printf 'script many.sh\n' > "$MANAGER_SCREEN_RIG/mode.--owner-cleanup-purge"
printf 'for n in $( seq 1 60 ) ; do printf "many: line %%03d\\n" "$n" ; done\n' > "$MANAGER_SCREEN_RIG/many.sh"
rigScript <<RIGSCRIPT
$rigToCleanup
keys ENTER ENTER
wait follow 10
show end
keys UP
show up
keys DOWN
show down
RIGSCRIPT
rigAssert "it shows the end of what was written: the last line, not the first" "$( rigHolds end 'many: line 060' ) $( rigHolds end 'many: line 001' )" "1 0"
rigAssert "scrolled up by a line the last one goes, and scrolled down to the end it is there again" "$( rigHolds up 'many: line 060' ) $( rigHolds down 'many: line 060' )" "0 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN TEAM DATA CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_TEAM_DATA: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
