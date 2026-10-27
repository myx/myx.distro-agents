#!/usr/bin/env bash
## Behavioural check on the roots `Settings` and `Configuration` of the manager screen (sh-lib/manager/AgentsManagerScreen.py),
## run rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which notes each start and prints the fixture: rows in the form
## `--manager-config-digest --full` prints, a `subject` row and then its `line` rows of fifteen fields.
## Held: the digest is read only while one of the two roots is shown, by `--manager-config-digest --full`, once
## for both, and again on its period; which root a line stands in is the last field of its row, and a subject
## with lines of both stands in each with its own; a root lists its subjects in the order of the operation, each
## a row that is entered, with how many of its lines are missing at the end of its row; the left pane shows the
## selected subject: what it holds, how many lines and how many missing, then its lines group by group; a plain
## setting shows its value, a path with an underscore as it is written, a date with its spaces; a secret shows
## only as configured or not configured, and nothing of a value its row might carry is ever on the screen; a
## subject longer than the pane scrolls with the focus on the left pane; a subject entered lists its lines by
## their labels alone, and the left window shows the selected one: what it is now first, its description, its
## key, group, state, source and scope, what it takes, where it is saved and whether Enter changes it; Enter on
## a setting opens the dialog of the kind its row names, radio buttons for a choice, a field with its range for
## a number, a field for any other, says whom OK saves it for, and OK calls `--manager-config-set <key> <value>`
## once with the value as it was chosen or typed; a number out of the range of its row is not sent; the style
## of the interface is taken by the screen at once; a save that is refused stands whole in a box; and a line
## whose row says it is not changed takes no Enter: the status line says why in the words of that row.
## Offline: no operation of the real tooling is called, and no setting of this machine is read.
## Reconciled for F11.7: Settings holds `Scope Settings` ahead of its subjects and Configuration `Git Settings` and `Installed Subsystems` ahead of theirs, so each subject is one row further down (two in Configuration); the scopes of the digest are not a subject of either root, so the long subject that scrolls is a subject of its own in the fixture; a credential shows in its one form with `configured` beside it.
## Reconciled for F11.0: a spacer stands between the folders of Configuration and its subjects; the left pane has no
## `keys:` line any more; every dialog has bigger margins inside its frame (two empty lines under its top, one more
## under its buttons, three blank cells at each side), so its box is four cells wider and two lines taller and what it
## holds stands where it stood; LOOKS has one more look, the underlined last line of a row (ROW_LINE).
## Reconciled for F11.5: Settings and Configuration stand at the 6th and 7th number key (Sessions, Team Members and Team Data stand under Magic-Team (Agents)); the digest has the subject of the knowledge store (MDAT_KNOWLEDGE_STORE), whose words stand in the table of Settings.
## Reconciled for F11.0, the table lines: an empty line between two rows of a full table (the rows by line number move), two spaces between the columns, and LOOKS holds the looks of a cell on the ground of a row and on an underlined line besides.
set -u
## The runner gives every test a team rig as the default workspace mode (AgentsRunTests.sh); a run by hand takes the same default, so the result is the same either way.
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
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
rigTmp="$( rigTempDir AgentsManagerScreenSettingsCheck )" || exit 1
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
rigConf(){ ## subject, group, key, state, value, label, description -- a line of the configuration as `--full` prints one: not changed from here, with why
	rigRow line "$1" "$2" "$3" "$4" "$5" "${6:--}" "${7:--}" 'no:set_at_deployment:_a_wizard_will_change_it' - - - - - configuration
}
rigKeyOf(){ ## subject, group, key, state, value, label, scope -- the line of a key an outside system holds in a scope, as `--full` prints one: its value as the scope has it, the scope as its source and its file, not changed from here
	rigRow line "$1" "$2" "$3" "$4" "$5" "$6" 'A_setting_of_this_outside_system.' 'no:set_at_deployment:_a_wizard_will_change_it' - - "$7" - "/rig/ws_rig/.local/.agents/$7.agent.env" configuration
}
rigEnv=/rig/ws_rig/.local/home/rig/MDLT.settings.env
## The choices of the style, as the digest gives them: each style in each of its colours, Magic first.
rigStyles='nu-system=Magic_-_System,nu-blue=Magic_-_Dark/Blue,nu-gray=Magic_-_Light/Gray,tv-system=Turbo_Vision_-_System,tv-blue=Turbo_Vision_-_Dark/Blue,tv-gray=Turbo_Vision_-_Light/Gray,bw-system=Basic_B/W_-_System,bw-dark=Basic_B/W_-_Dark/Blue,bw-light=Basic_B/W_-_Light/Gray'
rigTeamEnv=/rig/ws_rig/.local/.agents/magic-team.agent.env
## A digest of eight subjects, every line of fifteen fields. Of the configuration: workspace, two paths, one of
## them missing, and a place; cli, what the workspace asks for, a leg with a secret that is set, whose row carries
## a value the screen must never show, and one that is missing, and a leg that is not usable; systems, a scope
## that is set, one that is set and lacks two keys, one that misses a key, and a system no scope holds; loop, an
## outcome, a date and a word; longone, two scopes, one of forty-two keys, so that the subject is longer than the
## pane, the other with a key and a secret that are missing; and one line of console. Of the settings: the style
## of the interface, a choice; of console a choice saved for the user and a line of a kind the screen does not
## know; of control two numbers, each with its range, saved for the workspace.
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow subject workspace 3
	rigConf workspace paths workspace-root set /rig/ws_rig
	rigConf workspace paths session-stores missing /rig/ws_rig/.local/agents/stores
	rigConf workspace places ws-rig set /rig/ws_rig
	rigRow subject cli 6
	rigConf cli workspace SPAWN_CLI_SERVICE set claude
	rigConf cli workspace SPAWN_HARNESS_TIER missing -
	rigConf cli claude ANTHROPIC_API_KEY secret-set sk-m************** Anthropic_API_Key 'The_key_the_Claude_CLI_signs_in_with.'
	rigConf cli claude CLAUDE_CODE_OAUTH_TOKEN secret-missing -
	rigConf cli claude usable set yes
	rigConf cli grok usable missing no
	rigRow subject systems 8
	rigConf systems slack magic-team set -
	rigConf systems slack magic-coordinator set SLACK_APP_TOKEN,SLACK_SIGNING_SECRET
	rigConf systems email magic-coordinator set -
	rigKeyOf systems email EMAIL_USER set coordinator@rig.example Email_User magic-coordinator
	rigKeyOf systems email EMAIL_APP_PASSWORD secret-set Ep1kF************ Email_App_Password magic-coordinator
	rigKeyOf systems email EMAIL_IMAP_HOST set imap.rig.example Email_IMAP_Host magic-coordinator
	rigConf systems confluence magic-team missing CONFLUENCE_SPACE
	rigConf systems jira - missing -
	rigRow subject loop 2
	rigConf loop main-loop MAIN_LOOP_LAST_OUTCOME set failed
	rigConf loop main-loop MAIN_LOOP_LAST_ITERATION_UTC set 2026-10-09_04:28_+0000
	rigRow subject longone 44
	rigConf longone magic-coordinator EMAIL_USER set coordinator@rig.example
	rigConf longone magic-coordinator SLACK_BOT_TOKEN secret-set -
	rigNumber=1 ; while [ "$rigNumber" -le 40 ] ; do rigConf longone magic-coordinator "$( printf 'KEY_%02d' "$rigNumber" )" set "$( printf 'value_%02d' "$rigNumber" )" ; rigNumber=$(( rigNumber + 1 )) ; done
	rigConf longone magic-team TRELLO_BOARD missing -
	rigConf longone magic-team TRELLO_TOKEN secret-missing -
	rigRow subject interface 1 Interface_Settings
	rigRow line interface style MDLT_MANAGER_STYLE set tv-system Interface_Style 'How_the_manager_screen_is_drawn:_its_frames,_its_colours_and_its_keys.' yes choice user default "$rigStyles" "$rigEnv" settings
	rigRow subject console 3 Console_Behaviour
	rigRow line console history MDLT_CONSOLE_HISTORY set workspace-personal Console_History_Type 'Where_a_console_keeps_the_shell_history_of_this_user.' yes choice user user 'workspace-personal=Per_User_In_This_Workspace,bash-default=The_File_Bash_Uses' "$rigEnv" settings
	rigConf console origin MDLT_CONSOLE_ORIGIN set source Console_Tooling_Origin 'Where_the_consoles_of_this_workspace_load_their_tools_from.'
	rigRow line console title RIG_CONSOLE_TITLE set rig_title Console_Title 'What_a_console_shows_as_its_title.' yes text user default - "$rigEnv" settings
	rigRow subject control 2 Session_Control
	rigRow line control request SESSION_CONTROL_REQUEST_SECONDS set 5 Control_Request_Seconds 'How_many_seconds_a_console_waits_for_a_session_to_answer_a_request.' yes number workspace default 1..60 "$rigTeamEnv" settings
	rigRow line control kill SESSION_CONTROL_KILL_SECONDS set 30 Control_Kill_Seconds 'How_many_seconds_the_carrying_out_of_a_kill_may_take.' yes number workspace workspace 5..600 "$rigTeamEnv" settings
	rigRow subject knowledge 1 Knowledge_Store
	rigRow line knowledge store MDAT_KNOWLEDGE_STORE set off Knowledge_Store_Switch 'Whether_this_workspace_keeps_a_vector_store_of_what_the_team_knows.' yes choice team default 'off=Off,on=On' "$rigTeamEnv" settings
} > "$rigF/rows.--manager-config-digest"
rigRow counters 0 0 0 0 0 0.42 > "$rigF/rows"
rigRow saved MDLT_MANAGER_STYLE nu-blue user "$rigEnv" > "$rigF/rows.--manager-config-set"
rigRow saved SESSION_CONTROL_REQUEST_SECONDS 12 workspace "$rigTeamEnv" > "$rigF/rows.--manager-config-set SESSION_CONTROL_REQUEST_SECONDS 12"
rigRow saved MDLT_CONSOLE_HISTORY bash-default user "$rigEnv" > "$rigF/rows.--manager-config-set MDLT_CONSOLE_HISTORY bash-default"
## the digest as it reads once the history type is saved as bash-default
LC_ALL=C sed 's/	workspace-personal	Console_History_Type/	bash-default	Console_History_Type/' "$rigF/rows.--manager-config-digest" > "$rigTmp/changed.digest"
## A fresh rig for one case: a copy of the fixtures, no call noted yet.
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize %s\nroot active-sessions\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigPane(){ ## tag, line counted from 1 -- the left pane's part of that line of the screen, without the spaces at its end
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -n "${2}p" | LC_ALL=C sed -e "s/^$1|//" -e 's/^┌\(─\)* \(.*\) \(─\)*┐.*$/ \2/' -e 's/^╔\(═\)* \(.*\) \(═\)*╗.*$/ \2/' -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' -e 's/▲.*$//' -e 's/▼.*$//' -e 's/▒.*$//' -e 's/■.*$//' -e 's/  *$//'
}
rigPaneHolds(){ ## tag, text -- how many lines of the left pane of that screen are exactly the text, the spaces at their ends aside
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C sed -e "s/^$1|//" -e 's/^┌\(─\)* \(.*\) \(─\)*┐.*$/ \2/' -e 's/^╔\(═\)* \(.*\) \(═\)*╗.*$/ \2/' -e 's/^│/ /' -e 's/^║/ /' -e 's/│.*$//' -e 's/║.*$//' -e 's/▲.*$//' -e 's/▼.*$//' -e 's/▒.*$//' -e 's/■.*$//' -e 's/^▐/ /' -e 's/▌.*$//' -e 's/↑.*$//' -e 's/↓.*$//' -e 's/  *$//' | LC_ALL=C grep -c -x -F -- "$2" || :
}
rigScreenHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigBoxHolds(){ ## tag, text -- how many lines of that box hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigOthers(){ ## how many starts were neither the list of the sessions, nor the read of the dashboard the screen starts on, nor the digest asked for whole. The list of the locations, which every start of the screen reads, is not counted.
	LC_ALL=C grep -c -v -x -e '--manager-session-list' -e '--manager-dashboard-read' -e '--manager-dashboard-read machine disk' -e '--manager-config-digest --full' -e '--manager-place-list' "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- Configuration lists the subjects of its lines, and one read of the digest fills both roots --"
rigCase list
rigScript <<'RIGSCRIPT'
root magic-team
turn
wait sessions 30
keys DOWN DOWN DOWN DOWN DOWN DOWN
advance 11
wait sessions 30
wait focus 30
get on
keys ENTER
get asked
wait list 30
turn
get in
show u
border title 1 84 120
cells row1 2 85 119
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
cells row5 6 85 119
cells rowH 7 85 119
cells rowD 8 85 119
cells row6 10 85 119
cells row7 11 85 119
cells row8 12 85 119
cells row9 13 85 119
cells row10 14 85 119
cells row11 15 85 119
keys BACKSPACE
turn 3
get root
show r
keys UP
turn 3
get sroot
show sr
keys ENTER
turn 3
get sin
border stitle 1 84 120
cells srow2 3 85 119
cells srow3 5 85 119
cells srow4 6 85 119
cells srow5 7 85 119
cells srow6 8 85 119
cells srow7 9 85 119
show su
get once
advance 11
wait list 30
get twice
RIGSCRIPT
rigAssert "a root not entered: the digest is read once the selection has rested on its row, and the left window then holds what the root holds" "$( rigVal on.selected ) [$( rigVal on.reading )] $( rigVal on.viewLines )" "configuration [] 33"
rigAssert "entering it afterwards asks for nothing more: the one read of the digest was made for the row" "$( rigVal asked.path ) [$( rigVal asked.reading )]" "configuration []"
rigAssert "its two folders and then its subjects are listed under the row that goes up, the subjects in the order of the operation, each a row that is entered" "[$( rigVal title )] $( rigVal in.rows ) [$( rigVal row1 )][$( rigVal row2 | sed 's/  *$//' )][$( rigVal row3 | sed 's/  *$//' )][$( rigVal row4 | sed 's/  *$//' )][$( rigVal row5 | sed 's/  *$//' )][$( rigVal rowH | sed 's/  *$//' )][$( rigVal rowD | sed 's/  *$//' )][$( rigVal row9 | sed 's/  *$//' )][$( rigVal row10 | sed 's/  *$//' )][$( rigVal row11 | sed 's/  *$//' )]" "[Configuration] 13 [>..][ Config Checker                  ►][ Server Keys                     ►][ CLI Presets and Tiers           ►][ Git Settings                    ►][ Configure Harness               ►][ Installed Subsystems            ►][ loop                            ►][ longone               2 missing ►][ Console Behaviour               ►]"
rigAssert "a subject with missing lines carries their count at the end of its row" "[$( rigVal row6 )][$( rigVal row7 )][$( rigVal row8 )]" \
	"[][ workspace             1 missing ►][ systems               2 missing ►]"
rigAssert "on the row that goes up the left pane is the root's table, nothing above it (the owner: \"no summary on top\")" "[$( rigPane u 3 )] $( rigScreenHolds u '61 lines' )" "[  SUBJECT     LINES MISSING WHAT] 0"
rigAssert "back at the root it says what it held"                   "[$( rigVal root.path )] $( rigVal root.selected ) [$( rigPane r 3 )]" "[] configuration [  SUBJECT     LINES MISSING WHAT]"
rigAssert "Settings, not entered yet, says what it holds from that same read" "$( rigVal sroot.selected ) [$( rigPane sr 3 )]" "settings [  SUBJECT            LINES MISSING WHAT]"
rigAssert "it lists the subjects that have a line of the settings, a subject of both roots in each" "[$( rigVal stitle )] $( rigVal sin.rows ) [$( rigVal srow2 | sed 's/  *$//' )][$( rigVal srow3 | sed 's/  *$//' )][$( rigVal srow4 | sed 's/  *$//' )][$( rigVal srow5 | sed 's/  *$//' )][$( rigVal srow6 | sed 's/  *$//' )][$( rigVal srow7 )]" "[Settings] 6 [ Scope Settings                  ►][ Interface Settings              ►][ Console Behaviour               ►][ Session Control                 ►][ Knowledge Store                 ►][]"
rigAssert "the subject of the knowledge store says in the table of Settings what it holds, as every subject does" "$( rigScreenHolds sr 'Knowledge Store' ) $( rigScreenHolds sr 'the optional vector store of what the team knows' )" "1 1"
rigAssert "and its table stands first, no words of the root above it" "[$( rigPane su 3 )] $( rigScreenHolds su 'What a user sets for himself' )" "[  SUBJECT            LINES MISSING WHAT] 0"
rigAssert "the digest was read once for both roots, whole, and once more when its period had passed" "$( rigCalled '--manager-config-digest --full' ) $( rigCalled --manager-config-digest ) $( rigOthers )" "2 0 0"

echo "-- the left pane shows the selected subject, group by group --"
rigCase subjects
rigScript <<'RIGSCRIPT'
keys 9
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN
turn
get w
show w
cells wKeys 37 1 83
cells wStatus 39 0 120
keys DOWN
turn
show s
keys DOWN
turn
get l
show l
RIGSCRIPT
rigAssert "workspace: its table first, no caption and no words above it" "$( rigVal w.selected ) [$( rigPane w 3 )] $( rigScreenHolds w '3 lines, 1 missing' )" "workspace [  SETTING         VALUE                                       KEY] 0"
rigAssert "its lines as a table: its missing line first, under a heading of its own, with the group it is of, since it is a subject of the configuration; then its paths under a heading of their own, a path with an underscore as it is written" "[$( rigPane w 4 | LC_ALL=C tr -s ' ' )][$( rigPane w 5 | LC_ALL=C tr -s ' ' )][$( rigPane w 6 | LC_ALL=C tr -s ' ' )][$( rigPane w 7 | LC_ALL=C tr -s ' ' )]" \
	"[ missing, first][ session-stores /rig/ws_rig/.local/agents/stores (missing) in paths][ paths][ workspace-root /rig/ws_rig -]"
rigAssert "then its places, under a heading of their own" "[$( rigPane w 8 | LC_ALL=C tr -s ' ' )][$( rigPane w 9 | LC_ALL=C tr -s ' ' )][$( rigPane w 10 )]" "[ places][ ws-rig /rig/ws_rig -][]"
rigAssert "under its lines no sentence says what Enter does: the status line names it; it names no key of its own" "[$( rigPane w 10 )][$( rigPane w 11 )] [$( rigVal wKeys )] [$( rigVal wStatus | sed 's/  *$//' )] $( rigVal w.spills )" "[][] [] [ ENTER Open  BSP Up  a Active  / Filter  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut  t Sort] 0"
rigAssert "systems: a scope that is set, and one that is set and lacks keys (the value column is as wide as the longest value, so the keys it lacks go on in the next rows)" "[$( rigPane s 8 | LC_ALL=C tr -s ' ' )][$( rigPane s 9 | LC_ALL=C tr -s ' ' )][$( rigPane s 11 | LC_ALL=C tr -s ' ' )][$( rigPane s 12 | LC_ALL=C tr -s ' ' )][$( rigPane s 13 | LC_ALL=C tr -s ' ' )]" \
	"[ slack][ magic-team set - -][ magic-coordinator set, lacks - -][ SLACK_APP_TOKEN,][ SLACK_SIGNING_SECRET]"
rigAssert "systems, all values shown (F11.7): under the scope that holds them stand the keys of a system, each with its value beside the assessment of its scope and the scope as its source" "[$( rigPane s 14 | LC_ALL=C tr -s ' ' )][$( rigPane s 15 | LC_ALL=C tr -s ' ' )][$( rigPane s 17 | LC_ALL=C tr -s ' ' )][$( rigPane s 21 | LC_ALL=C tr -s ' ' )]" \
	"[ email][ magic-coordinator set - -][ Email User coordinator@rig.example magic-coordinator EMAIL_USER][ Email IMAP Host imap.rig.example magic-coordinator EMAIL_IMAP_HOST]"
rigAssert "a credential of a system reads as its one form, nothing beside it (F11.7: an outside system says no more of it; a CLI's keeps its assessment); of its value the screen shows what the operation printed and no more" "[$( rigPane s 19 | LC_ALL=C tr -s ' ' )] $( rigScreenHolds s 'Ep1kF' ) $( rigScreenHolds s 'RIGSECRET' ) $( rigScreenHolds s '(configured)' )" \
	"[ Email App Password Ep1kF************ magic-coordinator EMAIL_APP_PASSWORD] 1 0 0"
rigAssert "a scope that misses a key, and a system no scope holds: the first lines, each with its system" "[$( rigPane s 4 | LC_ALL=C tr -s ' ' )][$( rigPane s 5 | LC_ALL=C tr -s ' ' )][$( rigPane s 7 | LC_ALL=C tr -s ' ' )]" "[ missing, first][ magic-team missing: CONFLUENCE_SPACE - in confluence][ no scope missing - in jira]"
rigAssert "loop: no line is missing, and a date reads with its spaces" "$( rigVal l.selected ) [$( rigPane l 5 | LC_ALL=C tr -s ' ' )][$( rigPane l 7 | LC_ALL=C tr -s ' ' )]" \
	"loop [ MAIN_LOOP_LAST_OUTCOME failed][ MAIN_LOOP_LAST_ITERATION_UTC 2026-10-09 04:28 +0000]"

echo "-- a subject longer than the pane scrolls with the focus on the left pane --"
rigCase scroll
rigSize="120 20"
rigScript <<'RIGSCRIPT'
keys 9
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN
turn
get top
show top
keys TAB PGDN
get paged
show paged
keys PGDN PGDN PGDN
get end
show end
RIGSCRIPT
rigSize=""
rigAssert "longone is selected, longer than the pane: from its top as many of its rows as the pane holds, a table, its missing lines first" "$( rigVal top.selected ) $( rigVal top.viewTop ) [$( rigPane top 3 | LC_ALL=C tr -s ' ' )]" "longone 0 [ SETTING VALUE KEY]"
rigAssert "every row of it, the pane scrolling: no line for how many more, no count in its title, how many rows once in the frame" "$( rigScreenHolds top ' more' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^top|' | LC_ALL=C sed -n '2p' | LC_ALL=C grep -c -E 'rows\]' ) $( rigScreenHolds top ' 44 rows ' )" "0 0 1"
rigAssert "the key that is missing stands on its first page, with its scope" "[$( rigPane top 4 | LC_ALL=C tr -s ' ' )][$( rigPane top 5 | LC_ALL=C tr -s ' ' )] $( rigVal end.spills )" "[ missing, first][ TRELLO_BOARD missing in magic-team] 0"

echo "-- a subject is entered: its lines by their labels alone, and the left window shows the one selected --"
rigCase entered
rigScript <<'RIGSCRIPT'
keys 8
wait list 30
keys DOWN DOWN DOWN ENTER
turn
get in
border title 1 84 120
cells row1 2 85 119
cells row2 3 85 119
cells row3 4 85 119
cells row4 5 85 119
show f
keys DOWN
turn
get h
show h
cells hStatus 39 0 120
keys DOWN
turn
show t
keys BACKSPACE
turn
get back
at @configuration cli
turn
wait list 30
turn
# the lines of this subject stand group by group: two headings stand ahead of this line
keys DOWN DOWN DOWN DOWN DOWN
turn
get k
show k
cells kStatus 39 0 120
cells kRow 7 85 119
RIGSCRIPT
rigAssert "Enter on a subject opens it: its lines of this root under the row that goes up, by label, nothing at the end of a row" "$( rigVal in.path ) [$( rigVal title )] $( rigVal in.rows ) [$( rigVal row1 )][$( rigVal row2 | sed 's/  *$//' )][$( rigVal row3 | sed 's/  *$//' )][$( rigVal row4 )]" "settings/console [Console Behaviour] 3 [>..][ Console History Type...][ Console Title...][]"
rigAssert "on the row that goes up the left window shows the subject itself: its table, nothing above it" "[$( rigPane f 2 )][$( rigPane f 3 )]" "[ Console Behaviour [wrap]][  SETTING               VALUE               SOURCE   KEY]"
rigAssert "its VALUE column holds the raw value a setting is saved as, and no description of it" "$( rigScreenHolds f ' workspace-personal ' ) $( rigScreenHolds f 'Per User In This Workspace' ) $( rigScreenHolds f ' rig_title ' )" "1 0 1"
rigAssert "a setting: its label as the title, and as its head its label and what it is now, by the label of the choice and as it is saved" "$( rigVal h.selectedLabel ) [$( rigPane h 2 )][$( rigPane h 3 )][$( rigPane h 4 )]" "Console History Type [ Console History Type [wrap]][ Console History Type = workspace-personal (Per User In This Workspace)][]"
rigAssert "then its description, and under it its key, group, state, source and scope" "[$( rigPane h 5 )][$( rigPane h 6 )][$( rigPane h 7 )][$( rigPane h 8 )][$( rigPane h 9 )][$( rigPane h 10 )][$( rigPane h 11 )]" \
	"[ Where a console keeps the shell history of this user.][][  key       MDLT_CONSOLE_HISTORY][  group     history][  state     set][  source    saved for this user][  scope     this user, in this workspace]"
rigAssert "what it takes, where it is saved, and that it is changed from here, which the status line names and no line of the pane" "[$( rigPane h 12 )][$( rigPane h 13 )][$( rigPane h 14 )][$( rigPane h 15 )] $( rigPaneHolds h ' keys: ENTER change' ) [$( rigVal hStatus | sed 's/  *$//' )]" \
	"[  takes     workspace-personal (Per User In This Workspace), bash-default (The File][            Bash Uses)][  saved in  /rig/ws_rig/.local/home/rig/MDLT.settings.env][  change    yes] 0 [ ENTER Change  BSP Up  a Active  / Filter  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"
rigAssert "a setting of a kind the screen does not know shows as it is, with nothing it takes" "[$( rigPane t 3 )] $( rigPaneHolds t '  source    the default' ) $( rigScreenHolds t ' takes ' ) $( rigPaneHolds t '  change    yes' )" "[ Console Title = rig_title] 1 0 1"
rigAssert "Backspace goes up, onto the subject that was entered"         "$( rigVal back.path ) $( rigVal back.selected )" "settings console"
rigAssert "a secret of the configuration, titled with its group since the subject has several: its one form with its state, its description, and why it is not changed, in the words of its row" "$( rigVal k.path ) [$( rigPane k 2 )][$( rigPane k 3 )][$( rigPane k 5 )] $( rigPaneHolds k '  change  no: set at deployment: a wizard will change it' ) $( rigScreenHolds k 'sk-must' )" "configuration/cli [ claude: Anthropic API Key [wrap]][ Anthropic API Key = sk-m**************][ The key the Claude CLI signs in with.] 1 0"
rigAssert "such a line is a credential, so a row that is entered (F11.8): the left window names no key for it, and the status line names Enter as opening it" "[$( rigVal kRow | sed 's/  *$//' )] $( rigScreenHolds k 'keys:' ) [$( rigVal kStatus | sed 's/  *$//' )]" "[>  Anthropic API Key...] 0 [ ENTER Open  BSP Up  a Active  / Filter  u Read  m Menu  ^X Exit  TAB Window  ? Help  w Cut]"

echo "-- Configuration: Enter on a line changes nothing, and says why --"
rigCase viewing
rigScript <<'RIGSCRIPT'
at @configuration cli
turn
wait list 30
turn
# the first row under the row that goes up is the heading of a group: the line is the one after it
keys DOWN DOWN
turn
keys y e SPACE o ENTER
get typed
keys RIGHT
get dived
keys k
get kill
turn
keys n
get start
turn
keys TAB y ENTER TAB
turn 3
get end
RIGSCRIPT
rigAssert "Enter on a line of the configuration opens nothing: the status line says, in the words of the row, that a wizard will change it" "[$( rigVal typed.dialog )] [$( rigVal typed.notice )] $( rigVal typed.path ) $( rigVal typed.quit )" "[] [Change the setting: set at deployment: a wizard will change it] configuration/cli no"
rigAssert "Right dives nowhere: it pages down, and the status line keeps what it said" "$( rigVal dived.path ) [$( rigVal dived.notice )]" "configuration/cli [Change the setting: set at deployment: a wizard will change it]"
rigAssert "k and n are no keys of this view: nothing opens, and the status line keeps what it said" "[$( rigVal kill.notice )][$( rigVal start.notice )] [$( rigVal start.dialog )]" "[Change the setting: set at deployment: a wizard will change it][Change the setting: set at deployment: a wizard will change it] []"
rigAssert "no operation was called but the reads, and nothing was saved" "$( rigOthers ) $( rigCalled '--manager-config-digest --full' ) $( rigVal end.calls ) [$( rigVal end.dialog )]" "0 1 0 []"

## A small digest whose subjects and lines carry labels, a line with none ending with `-`.
{
	rigRow subject workspace 1 Workspace_Paths
	rigConf workspace paths workspace-root set /rig/ws_rig Workspace_Root
	rigRow subject cli 2 CLI_Services
	rigConf cli workspace SPAWN_HARNESS_TIER missing - Spawn_Harness_Tier
	rigConf cli workspace ODD_KEY set odd -
	rigRow subject interface 1 Interface_Settings
	rigRow line interface style MDLT_MANAGER_STYLE set tv-system Interface_Style 'How_the_manager_screen_is_drawn.' yes choice user default "$rigStyles" "$rigEnv" settings
} > "$rigTmp/labelled.digest"
rigCaseLabelled(){ ## name -- a fresh rig whose digest is the labelled one
	rigCase "$1"
	cp "$rigTmp/labelled.digest" "$MANAGER_SCREEN_RIG/rows.--manager-config-digest"
}

echo "-- the labels of the digest: a subject and a line show by their label, the key is the detail --"
rigCaseLabelled labels
rigScript <<'RIGSCRIPT'
turn
keys 9
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN
turn
get w
at @configuration cli
turn
wait list 30
turn
wait focus 30
turn 2
show c
keys 8
turn
keys DOWN DOWN
turn
get i
show i
RIGSCRIPT
rigAssert "the subjects are listed by their labels"                  "[$( rigVal w.selectedLabel )] [$( rigVal i.selectedLabel )]" "[Workspace Paths] [Interface Settings]"
rigAssert "a line with no label shows by its key there too" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^c|' | LC_ALL=C tr -s ' ' | LC_ALL=C grep -c -F '║ ODD_KEY' )" "1"
rigAssert "the subject of the interface shows its style as it is saved, by its value and not by the label of the choice, where it comes from, and its key" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^i|' | LC_ALL=C tr -s ' ' | LC_ALL=C grep -c -F '│ Interface Style tv-system default MDLT_MANAGER_STYLE' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^i|' | LC_ALL=C grep -F 'Interface Settings ' | LC_ALL=C grep -c -F '►' )" "1 1"

echo "-- Enter on the style: a dialog of its own, the style and its colours; OK takes both at once and saves them as one value --"
rigCaseLabelled style
rigScript <<'RIGSCRIPT'
turn
keys 8
wait list 30
keys DOWN DOWN ENTER
turn
keys ENTER
get up
keys ENTER DOWN
turn
keys ENTER
turn
get dlg
box sbox
keys UP SPACE
get magic
keys TAB DOWN SPACE
get dark
keys ESC
get esc
keys ENTER UP SPACE TAB DOWN SPACE ENTER
get ok
show after
wait action 30
get done
RIGSCRIPT
rigAssert "Enter on the row that goes up inside a subject goes up, and opens no dialog" "$( rigVal up.path ) [$( rigVal up.dialog )]" "settings []"
rigAssert "on the style it opens the dialog of the style, on the style this screen is drawn in, the keys on the styles" "[$( rigVal dlg.dialog )] [$( rigVal dlg.dialogTitle )]" "[setting-style:style|tv] [Interface Style]"
rigAssert "two groups of radio buttons, the styles Magic first and the colours, each on what this screen is drawn in, with OK and Cancel, and it says whom it is saved for" "$( rigBoxHolds sbox '║   Style ' ) $( rigBoxHolds sbox '║   ( ) Magic ' ) $( rigBoxHolds sbox '║   (•) Turbo Vision ' ) $( rigBoxHolds sbox '║   ( ) Basic B/W ' ) $( rigBoxHolds sbox '║   Colours ' ) $( rigBoxHolds sbox '║   (•) System ' ) $( rigBoxHolds sbox '║   ( ) Dark/Blue ' ) $( rigBoxHolds sbox '║   ( ) Light/Gray ' ) $( rigBoxHolds sbox ' »OK« ▅   Cancel  ▅' ) $( rigBoxHolds sbox 'OK saves it for the user who runs this console, and this screen takes it' ) $( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^sbox|║   ([^)]*) \([A-Za-z/ ]*[A-Za-z]\) .*$/\1/p' | LC_ALL=C tr '\n' ',' )" "1 1 1 1 1 1 1 1 1 1 Magic,Turbo Vision,Basic B/W,System,Dark/Blue,Light/Gray,"
rigAssert "Space chooses the style the bar is on, Tab goes to the colours and Space chooses there; Esc closes, saves nothing and leaves the style" "[$( rigVal magic.dialog )] [$( rigVal dark.dialog )] [$( rigVal esc.dialog )] $( rigVal esc.style )-$( rigVal esc.colours ) $( rigCalled '--manager-config-set MDLT_MANAGER_STYLE nu-blue' )" "[setting-style:style|nu] [setting-style:colours|dark] [] tv-system 1"
rigAssert "OK: this screen takes the style and its colours at once, before the operation has answered" "[$( rigVal ok.dialog )] $( rigVal ok.style )-$( rigVal ok.colours ) [$( rigVal ok.notice )] $( rigScreenHolds after ' This screen is drawn in Magic - Dark/Blue now.' )" "[] nu-blue [save asked of the tooling: Interface Style: Magic - Dark/Blue] 1"
rigAssert "and they are saved by the write operation, once, as one value, by the key of the row" "$( rigCalled '--manager-config-set MDLT_MANAGER_STYLE nu-blue' ) $( LC_ALL=C grep -c -e '--manager-config-set' "$MANAGER_SCREEN_RIG/calls" ) [$( rigVal done.notice )] $( rigVal done.style )-$( rigVal done.colours )" "1 1 [saved: Interface Style: Magic - Dark/Blue] nu-blue"

echo "-- Enter on a choice: the form offers the same choices and saves the raw value, which the table then shows --"
rigCase choice
rigScript <<RIGSCRIPT
turn
keys 8
wait list 30
keys DOWN DOWN DOWN ENTER
turn
keys DOWN
turn
get row
keys ENTER
turn
get dlg
box cbox
keys DOWN SPACE
get chosen
copy $rigTmp/changed.digest $MANAGER_SCREEN_RIG/rows.--manager-config-digest
keys ENTER
get saved
wait action 30
keys u
wait list 30
turn
get after
show after
keys BACKSPACE
turn
show table
RIGSCRIPT
rigAssert "Enter on the setting opens its form: the dialog of the choices, on the setting, as before" "[$( rigVal dlg.dialog )] [$( rigVal dlg.dialogTitle )]" "[setting:choice|workspace-personal] [Console History Type]"
rigAssert "it offers the same choices, each by its label as before: a radio button for each, the saved one chosen" "$( rigBoxHolds cbox '(•) Per User In This Workspace' ) $( rigBoxHolds cbox '( ) The File Bash Uses' )" "1 1"
rigAssert "Space chooses the second, OK saves it: the write operation is called once, with the key and the raw value, not the label" "[$( rigVal chosen.dialog )] [$( rigVal saved.dialog )] $( rigCalled '--manager-config-set MDLT_CONSOLE_HISTORY bash-default' ) $( LC_ALL=C grep -c -e '--manager-config-set' "$MANAGER_SCREEN_RIG/calls" )" "[setting:choice|bash-default] [] 1 1"
rigAssert "read back: the table of the subject shows the saved raw value, and the setting's detail shows it first, with its description after it" "$( rigScreenHolds table ' bash-default ' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^table|' | LC_ALL=C grep -F 'MDLT_CONSOLE_HISTORY' | LC_ALL=C grep -c -F 'The File Bash Uses' ) $( rigPaneHolds after ' Console History Type = bash-default (The File Bash Uses)' )" "1 0 1"

echo "-- the raw value, and the place form of a path, in the table and in the detail of a setting --"
## the functions of the screen over a line of the digest that offers a path as its choices, with a location registered for it
cat > "$rigTmp/values.py" <<'RIGPY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
screen = importlib.util.module_from_spec(spec) ; spec.loader.exec_module(screen)
state = screen.ManagerState("")
state.rows["places"] = [{"place": {"path": "/rig/ws-myx-devops", "key": "ws-myx-devops"}}]
state.placed = None
place = lambda text: screen.placedLine(state, text)[0]
choices = [("", "<default> (own .local)"), ("/rig/ws-myx-devops/source", "ws-myx-devops (source)"), ("/rig/elsewhere/source", "elsewhere (source)")]
line = {"subject": "console", "group": "origin", "key": "MDLT_CONSOLE_ORIGIN", "state": "set", "value": "/rig/ws-myx-devops/source", "label": "Console Tooling Origin",
        "description": "", "change": "yes", "kind": "choice", "scope": "workspace", "source": "workspace", "where": "", "choices": choices, "range": None}
unset = dict(line, key="MDLT_CONSOLE_DETAIL", label="Console Verbosity", value="", choices=[("", "<default> (none)"), ("true", "true (track)")])
heads, rows, kinds, looks = screen.digestTable("console", [line, unset], False, place)
print("cells=%s" % "|".join(row[1] for row in rows))
print("title=%s" % screen.settingLines(line, 100, place)[0])
print("titleUnset=%s" % screen.settingLines(unset, 100, place)[0])
takes = [text for text in screen.settingLines(line, 200, place) if "takes" in text]
print("takes=%s" % " ".join(takes[0].split()))
print("formChoices=%s" % ",".join(label for value, label in line["choices"]))
RIGPY
rigValues="$( cd "$rigTmp" && "$rigPython" -I -B "$rigTmp/values.py" "$rigScreen" 2>&1 )"
rigValue(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigValues" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigAssert "a path in the VALUE column is in its place form, and a setting that holds nothing shows nothing there but the dash" "$( rigValue cells )" "ws-myx-devops:source|-"
rigAssert "the detail writes it value first, its description after it in brackets, in its title line" "[$( rigValue title )] [$( rigValue titleUnset )]" "[Console Tooling Origin = ws-myx-devops:source (ws-myx-devops (source))] [Console Verbosity = <default> (none)]"
rigAssert "and in its list of the values it takes, each value first; a choice with no value stands by its description" "$( rigValue takes )" "takes <default> (own .local), ws-myx-devops:source (ws-myx-devops (source)), /rig/elsewhere/source (elsewhere (source))"
rigAssert "the choices the form offers are as they were, by their labels" "$( rigValue formChoices )" "<default> (own .local),ws-myx-devops (source),elsewhere (source)"

echo "-- Enter on a number: its range in the dialog, saved for the workspace; one out of its range is not sent --"
rigCase number
rigScript <<'RIGSCRIPT'
turn
keys 8
wait list 30
keys DOWN DOWN DOWN DOWN ENTER
turn
keys DOWN
turn
show n
keys ENTER
turn
get dlg
box nbox
keys BACKSPACE TAB ENTER
get empty
keys 9 9 ENTER
get high
keys BACKSPACE BACKSPACE 0 7 ENTER
get nought
keys BACKSPACE BACKSPACE 1 2 ENTER
get ok
wait action 30
turn
get done
show d
RIGSCRIPT
rigAssert "a number: what it is now and where from, what it takes, and that a change is for everybody" "$( rigPaneHolds n ' Control Request Seconds = 5' ) $( rigPaneHolds n '  source    the default' ) $( rigPaneHolds n '  scope     everybody who works in this workspace' ) $( rigPaneHolds n '  takes     a whole number from 1 to 60' )" "1 1 1 1"
rigAssert "Enter opens the dialog of a number, on what it is now, with its range over the field" "[$( rigVal dlg.dialog )] [$( rigVal dlg.dialogTitle )] $( rigBoxHolds nbox 'A whole number from 1 to 60' ) $( rigBoxHolds nbox ' »OK« ▅   Cancel  ▅' )" "[setting-number:number|5] [Control Request Seconds] 1 1"
rigAssert "the dialog says that it is saved for the workspace, for everybody" "$( rigBoxHolds nbox 'OK saves it for the WORKSPACE: it changes for everybody who works in it.' ) $( rigBoxHolds nbox 'now       5, the default' )" "1 1"
rigAssert "an empty field presses nothing"                           "[$( rigVal empty.dialog )] [$( rigVal empty.dialogSays )]" "[setting-number:number|] [nothing is saved: no number is typed]"
rigAssert "a number out of its range, and one written with a nought ahead, are not sent: the dialog says what it takes" "[$( rigVal high.dialog )] [$( rigVal high.dialogSays )] [$( rigVal nought.dialog )] [$( rigVal nought.dialogSays )] $( LC_ALL=C grep -c -e '--manager-config-set' "$MANAGER_SCREEN_RIG/calls" )" \
	"[setting-number:number|99] [nothing is saved: it takes a whole number from 1 to 60, written with its digits alone] [setting-number:number|07] [nothing is saved: it takes a whole number from 1 to 60, written with its digits alone] 1"
rigAssert "OK with a number of the range saves it by the write operation, once, the number as it was typed" "[$( rigVal ok.dialog )] [$( rigVal ok.notice )] $( rigCalled '--manager-config-set SESSION_CONTROL_REQUEST_SECONDS 12' ) $( LC_ALL=C grep -c -e '--manager-config-set' "$MANAGER_SCREEN_RIG/calls" )" "[] [save asked of the tooling: Control Request Seconds: 12] 1 1"
rigAssert "what the save printed stands in the left window: the key, the value, whom it is saved for and where" "[$( rigVal done.notice )] $( rigPaneHolds d ' saved     SESSION_CONTROL_REQUEST_SECONDS' ) $( rigPaneHolds d ' scope     workspace' ) $( rigPaneHolds d " in        $rigTeamEnv" )" "[saved: Control Request Seconds: 12] 1 1 1"

echo "-- a setting of a kind the screen does not know is changed as a short text, sent as it was typed --"
rigCase words
rigScript <<'RIGSCRIPT'
turn
keys 8
wait list 30
keys DOWN DOWN DOWN ENTER
turn
keys DOWN DOWN
turn
keys ENTER
turn
get dlg
box tbox
keys SPACE x ENTER
get ok
wait action 30
RIGSCRIPT
rigAssert "Enter opens a field with what it is now"                  "[$( rigVal dlg.dialog )] [$( rigVal dlg.dialogTitle )] $( rigBoxHolds tbox 'OK saves it for the user who runs this console.' )" "[setting-text:words|rig_title] [Console Title] 1"
rigAssert "what was typed is one word of the call, as it stands"     "[$( rigVal ok.dialog )] $( LC_ALL=C grep -c -x -F -- '[--manager-config-set][RIG_CONSOLE_TITLE][rig_title x]' "$MANAGER_SCREEN_RIG/words" )" "[] 1"

echo "-- a save that is refused: what the operation wrote stands in a box --"
rigCaseLabelled refused
printf 'fail\n' > "$MANAGER_SCREEN_RIG/mode.--manager-config-set"
rigScript <<'RIGSCRIPT'
turn
keys 8
wait list 30
keys DOWN DOWN ENTER
turn
keys DOWN
turn
keys ENTER DOWN SPACE ENTER
wait action 30
turn
get failed
RIGSCRIPT
rigAssert "the refusal is shown whole, under its own title"          "[$( rigVal failed.dialogTitle )] [$( rigVal failed.dialogHolds )]" "[The save failed] [operation: --manager-config-set MDLT_MANAGER_STYLE bw-system / rig-tools: a line that is no error / rig-tools: ⛔ ERROR: the rig said fail]"

echo "-- a subject with settings of two scopes that share a label: each stands under the heading of its scope --"
rigCase scoped
{
	rigRow subject style 2 Style_Of_Things
	rigRow line style user RIG_STYLE_USER set tv Interface_Style 'How.' yes choice user user tv=TV,mc=MC "$rigEnv" settings
	rigRow line style workspace RIG_STYLE_WORKSPACE set mc Interface_Style 'How.' yes choice workspace workspace tv=TV,mc=MC "$rigEnv" settings
} > "$MANAGER_SCREEN_RIG/rows.--manager-config-digest"
rigScript <<'RIGSCRIPT'
turn
root settings
keys ENTER
wait list 30
keys DOWN DOWN ENTER
turn
get in
cells g1 3 85 119
cells g2 4 85 119
cells g3 5 85 119
cells g4 6 85 119
keys DOWN DOWN DOWN DOWN
turn
get second
border title 1 0 84
RIGSCRIPT
rigAssert "two settings of one label in two groups: a heading for each, the setting under its own, and its window titled with its group" "$( rigVal in.path ) $( rigVal in.rows ) [$( rigVal g1 | LC_ALL=C sed 's/  *$//' )][$( rigVal g2 | LC_ALL=C sed 's/  *$//' )][$( rigVal g3 | LC_ALL=C sed 's/  *$//' )][$( rigVal g4 | LC_ALL=C sed 's/  *$//' )] [$( rigVal second.selected )] [$( rigVal title )]" "settings/style 5 [ user][   Interface Style...][ workspace][   Interface Style...] [workspace RIG_STYLE_WORKSPACE] [workspace: Interface Style [wrap]]"

echo "-- the styles: Magic, Turbo Vision and Basic B/W, in that order, Turbo Vision the default; the compact one is retired --"
rigCase magic
rigScript <<'RIGSCRIPT'
turn
keys 8
wait list 30
turn
keys I
get s1
keys I
get s2
turn
show m
roles mr
keys F10
turn
show mm
roles mmr
keys ESC
turn
show mafter
fresh mfresh
rigdialog
turn
get mdlg
box mbox
box mboxr roles
keys BACKTAB
turn
box mboxf
box mboxfr roles
keys ESC
turn
show mclosed
fresh mclosedfresh
get mend
tell Refused | the rig refuses it
turn
box abox
box aboxr roles
keys ESC
turn
keys I
get s3
style mc
get retired
style magic
plain
turn
show mp
style bw
turn
show bp
RIGSCRIPT
rigSome(){ ## count -- `some` where it is one or more, else `none`
	if [ "$1" -ge 1 ] 2> /dev/null ; then echo some ; else echo none ; fi
}
rigAssert "I takes the next style: Basic B/W, then Magic, then Turbo Vision again, each in the colours of now, and the status line names each" "$( rigVal s1.style ) [$( rigVal s1.notice )] $( rigVal s2.style ) [$( rigVal s2.notice )] $( rigVal s3.style )" "bw [interface style: Basic B/W - System] nu [interface style: Magic - System] tv"
rigAssert "the compact style is no style any more: its name is refused and the style stays" "$( rigVal style.refused ) $( rigVal retired.style )" "mc tv"
rigCount(){ ## tag letters -- how many cells of the roles of that tag are drawn in those looks
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1|//p" | LC_ALL=C tr -d -c "$2" | LC_ALL=C wc -c | LC_ALL=C tr -d ' '
}
rigAssert "Magic: the windows stand in their own colour, a thin line on the bottom edge of the line above them and of their last line, the change of colour their sides, their shadow whole cells at their right; no line frame, no half block and nothing on the top of a cell" "$( rigScreenHolds m '▔' ) $( rigScreenHolds m '▀' ) $( rigSome "$( rigScreenHolds m '▁▁▁' )" ) $( rigScreenHolds m '▗' ) $( rigScreenHolds m '▐' ) $( rigScreenHolds m '▌' ) $( rigScreenHolds m '▝' ) $( rigScreenHolds m '┌' ) $( rigScreenHolds m '┏' ) $( rigScreenHolds m '┃' ) $( rigScreenHolds m '║' ) $( rigSome "$( rigCount mr V )" ) $( rigSome "$( rigCount mr v )" ) $( rigSome "$( rigCount mr E )" ) $( rigSome "$( rigCount mr a )" )" "0 0 some 0 0 0 0 0 0 0 0 some some some some"
rigAssert "each title stands as a tab on the line over its window, in a look of its own, the active one in its own" "$( rigScreenHolds m '▁ Settings ▁' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^m|' | LC_ALL=C sed -n '2p' | LC_ALL=C grep -o '▟' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^mr|' | LC_ALL=C sed -n '2p' | LC_ALL=C tr -d -c 'T' | LC_ALL=C wc -c | LC_ALL=C tr -d ' ' )" "1 0 10"
rigAssert "a row that is entered has its mark at the right edge of the row, in every subject of the root" "$( rigScreenHolds m '▶  |' ) $( rigScreenHolds m 'Interface Settings...' )" "5 0"
rigAssert "the status line: each key a chip of its own colour, the text as it was" "$( rigSome "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^mr|' | tail -1 | LC_ALL=C tr -d -c 'K' | LC_ALL=C wc -c )" ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^m|' | tail -1 | LC_ALL=C grep -c -F ' ⏎ Open  ' )" "some 1"
rigAssert "a menu: hung from the bar, its own colour up to a thin line at its bottom, no mark at its sides, its shadow at its right and half a line under it, the black of it the ground of its cells" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^mm|' | LC_ALL=C grep -c -F '▀' ) $( rigSome "$( rigScreenHolds mm '▁▁▁' )" ) $( rigScreenHolds mm '▄▄▄' ) $( rigScreenHolds mm '▛' ) $( rigScreenHolds mm '▜' ) $( rigScreenHolds mm '▙' ) $( rigScreenHolds mm '▟' ) $( rigScreenHolds mm '█' ) $( rigSome "$( rigCount mmr z )" )" "0 some 1 0 0 0 0 0 some"
rigAssert "closed, it leaves nothing: what is drawn is what a new terminal shows of the same state" "$( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^mafter|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^mfresh|//p' )" ] && echo same || echo differs ) $( rigScreenHolds mafter '▄▄▄' )" "same 0"
rigAssert "a dialog: its own colour, a thin line on the bottom edge of the line above it, its title a tab on it, and of its last line, no mark at its sides, its shadow at its right and half a line under it" "$( rigBoxHolds mbox '▁ A dialog of the rig ▁' ) $( rigBoxHolds mbox '▁▁▁' ) $( rigBoxHolds mbox '▔' ) $( rigBoxHolds mbox '▀' ) $( rigBoxHolds mbox '▛' ) $( rigBoxHolds mbox '▜' ) $( rigBoxHolds mbox '▐' ) $( rigBoxHolds mbox '▌' ) $( rigBoxHolds mbox '█' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^mbox|' | tail -1 | LC_ALL=C grep -c -F '| ▄▄▄' )" "1 2 0 0 0 0 0 0 0 1"
rigAssert "its boxes and its radio buttons: a tick and a dot where chosen, a faint dot where not" "$( rigBoxHolds mbox '|    · alpha' ) $( rigBoxHolds mbox '|    ✓ beta' ) $( rigBoxHolds mbox '|    · one way' ) $( rigBoxHolds mbox '|    • another' ) $( rigBoxHolds mbox '[X]' ) $( rigBoxHolds mbox '(*)' )" "1 1 1 1 0 0"
rigAssert "a field to type in stands between brackets, its room filled with dots" "$( rigBoxHolds mbox '|    [typed.....' ) $( rigBoxHolds mbox '..]  ' )" "1 1"
rigAssert "its buttons are bars of one width, each with a shadow beside and half a line under it, the black of it the ground of its cells, the default in a look of its own" "$( rigBoxHolds mbox '    OK        Cancel   ' ) $( rigBoxHolds mbox ' ▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄' ) $( rigBoxHolds mbox '[ Cancel ]' ) $( rigBoxHolds mbox '»' ) $( rigCount mboxr N ) $( rigSome "$( rigCount mboxr Z )" )" "1 1 0 0 10 some"
rigAssert "the button with the keys changes its colour and has ► ◄ inside its ends; the default keeps its own look" "$( rigBoxHolds mboxf '► Cancel ◄' ) $( rigBoxHolds mboxf '    OK    ' ) $( rigCount mboxfr n ) $( rigCount mboxfr N )" "1 1 10 10"
rigAssert "closed, the dialog leaves nothing either, and nothing was drawn past a line or the screen" "$( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^mclosed|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^mclosedfresh|//p' )" ] && echo same || echo differs ) $( rigScreenHolds mclosed '█' ) $( rigVal mend.spills )" "same 0 0"
rigAssert "what the screen refuses or what failed stands in the looks of its level: its body, its outline and its title in yellow set into its top line; the rig's dialog, of no level, in none of them" "$( rigBoxHolds abox '▁ Refused ▁' ) $( rigSome "$( rigCount aboxr r )" ) $( rigSome "$( rigCount aboxr q )" ) $( rigCount aboxr Y ) $( rigCount mboxr rqY )" "1 some some 9 0"
rigAssert "on a terminal that is not UTF-8 Magic draws in the marks of one byte, with no mark it cannot show, as Basic B/W draws there" "$( rigScreenHolds mp '#=' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^mp|' | LC_ALL=C sed -n '1,39p' | LC_ALL=C grep -c '[^ -~]' ) $( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^mp|//p' | LC_ALL=C sed -n '1,39p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^bp|//p' | LC_ALL=C sed -n '1,39p' )" ] && echo as-basic-bw || echo differs )" "2 0 as-basic-bw"
rigColours="$( "$rigPython" -I -B - "$rigScreen" <<'RIGPY' 2>&1
import importlib.util, sys
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
class Curses:
    A_NORMAL, A_BOLD, A_REVERSE, A_DIM = 0, 1 << 21, 1 << 18, 1 << 20
    COLOR_BLACK, COLOR_RED, COLOR_GREEN, COLOR_YELLOW, COLOR_BLUE, COLOR_MAGENTA, COLOR_CYAN, COLOR_WHITE = range(8)
    error = Exception
    def __init__(self, colours):
        self.COLORS, self.COLOR_PAIRS, self.pairs, self.changed = colours, 256, {}, 0
    def has_colors(self):
        return self.COLORS > 0
    def use_default_colors(self):
        pass
    def init_pair(self, number, text, ground):
        self.pairs[number] = (text, ground)
    def init_color(self, *words):
        self.changed += 1
    def color_pair(self, number):
        return number << 8
def shades(colours, style, shown=("PLAIN", "REVERSE", "FRAME_ON", "BOX_BUTTON")):
    module.curses = Curses(colours)
    surface = module.CursesSurface.__new__(module.CursesSurface)
    plain, coloured = surface.looksOf()
    module.setStyle(style)
    surface.plain, surface.coloured = plain, coloured
    looks = surface.looks()
    said = []
    for look in [getattr(module, name) for name in shown]:
        pair = module.curses.pairs.get((looks[look] >> 8) & 0xff)
        said.append("%s/%s%s" % (pair[0], pair[1], "b" if looks[look] & Curses.A_BOLD else "") if pair else "none")
    return "%s:%s:%s" % (style, " ".join(said), module.curses.changed)
magic = ("PLAIN", "REVERSE", "FRAME_ON", "BOX_BUTTON", "EDGE_ON", "EDGE_ON_SHADE", "TITLE_ON", "KEY_CHIP", "ALERT_HEAD")
print("256 " + shades(256, "magic", magic))
print("256 " + shades(256, "tv"))
print("8 " + shades(8, "magic", magic))
## a terminal of eight colours may have no more than 64 pairs (TERM=screen): every style keeps its colours there
print("pairs 8 %s" % (len(module.curses.pairs) <= 63))
print("8 " + shades(8, "tv"))
print("0 " + shades(0, "magic", magic))
print("order %s first %s" % (" ".join(name for name, entry in module.STYLES), module.STYLE_FIRST))
for colours in (256, 8):
    for style in ("tv-system", "tv-blue", "tv-gray", "bw-system", "bw-dark", "bw-light"):
        print("%d %s" % (colours, shades(colours, style)))
for name in ("tv-blue", "tv-gray", "bw-dark", "bw-light"):
    fine = [entry for entry in module.STYLE_LOOKS[name].values()]
    print("exact %s %d of %d %s" % (name, len(module.STYLE_LOOKS[name]), len(module.LOOKS), all(
        text in names and ground in names and 16 <= fineText <= 255 and 16 <= fineGround <= 255
        for names in [("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white")]
        for text, ground, bright, fineText, fineGround, bold in fine)))
names = ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white")
for sets in ("nu-blue", "nu-gray"):
    fine = [entry for entry in module.STYLE_LOOKS[sets].values()]
    print("declared %s %d of %d %s" % (sets, len(module.STYLE_LOOKS[sets]), len(module.LOOKS), all(
        text in names and ground in names and 16 <= fineText <= 255 and 16 <= fineGround <= 255
        for text, ground, bright, fineText, fineGround, bold in fine)))
## the own colours of the terminal: the eight of the light set, and no shade of the palette
print("declared nu-system %d of %d %s" % (len(module.STYLE_LOOKS["nu-system"]), len(module.LOOKS), all(
    own[:3] == module.STYLE_LOOKS["nu-blue"][look][:3] and own[3:] == (None, None, False)
    for look, own in module.STYLE_LOOKS["nu-system"].items())))
print("256 system " + shades(256, "nu-system", magic))
## the desktop and a window apart in each of Magic's colours, on a terminal of 256 colours: the ground of the desktop,
## and of the line over a window's top, which stands on it, is none of the grounds of a window; then that of a shadow;
## and the menu bar, its hot letters, its `@` and what does not apply apart from the title tab of the active window
for name in ("nu-system", "nu-blue", "nu-gray"):
    grounds = lambda shown: " ".join(said.split("/")[1].rstrip("b") for said in shades(256, name, shown).split(":")[1].split())
    desktop, window = grounds(("DESKTOP", "EDGE_ON_SHADE", "EDGE_SHADE")), grounds(("PLAIN", "EDGE_ON", "EDGE"))
    print("apart %s %s / %s / %s %s" % (name, desktop, window, grounds(("SHADOW",)), not set(desktop.split()) & set(window.split())))
    bar = shades(256, name, ("BAR", "BAR_HOT", "BAR_AT", "BAR_OFF", "TITLE_ON")).split(":")[1].split()
    print("bar %s %s %s" % (name, " ".join(bar), bar[-1].split("/")[1].rstrip("b") not in [said.split("/")[1].rstrip("b") for said in bar[:-1]]))
RIGPY
)"
rigAssert "Magic on a terminal of 256 colours, in its grey colours unless told another: its own shades of the palette, white on deep blue windows, a white bar with blue text for the selection, a white line on the deep blue of the active window and on the dark grey desktop over it, the title strip white, red chips, a yellow title for what failed; the palette itself is never changed" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^256 magic://p' )" "231/19 19/231b 231/19b 16/250 231/19 231/238 19/231b 231/124b 226/124b:0"
rigAssert "Turbo Vision keeps its eight colours there, its buttons a green bar" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^256 tv://p' )" "7/4 0/6 7/4b 0/2:0"
rigAssert "Magic on a terminal of eight colours: the basic colours of the same plan" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^8 magic://p' ) $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^8 tv://p' ) $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^pairs 8 //p' )" "7/4b 4/7 7/4b 0/7 7/4 7/0 4/7 7/1b 3/1b:0 7/4 0/6 7/4b 0/2:0 True"
rigAssert "with no colours no pair is made, and every look of LOOKS has its colours in Magic, each of the eight and of the palette" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^0 magic://p' ) $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^declared //p' | LC_ALL=C tr '\n' ' ' )" "none none none none none none none none none:0 nu-blue 141 of 141 True nu-gray 141 of 141 True nu-system 141 of 141 True "
rigAssert "Magic in the terminal's own colours (nu-system) takes its own choice of the eight named ones, on a terminal of 256 colours too" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^256 system nu-system://p' )" "7/4 0/6 7/4b 0/7 7/4 7/0 4/7 0/3 3/1b:0"
rigAssert "the desktop and a window apart in each of Magic's colours: the desktop, and the line over a window's top that stands on it, dark grey in nu-blue and nu-gray and black in nu-system, never the ground of a window; a shadow black, on that grey in nu-blue and nu-gray" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^apart //p' | LC_ALL=C tr '\n' ' ' )" "nu-system 0 0 0 / 4 4 4 / 0 True nu-blue 238 238 238 / 63 63 63 / 16 True nu-gray 238 238 238 / 19 19 19 / 16 True "
rigAssert "the menu bar and the title tab of the active window under it apart in each of Magic's colours: the bar light grey in nu-blue as in nu-gray, cyan in nu-system, its hot letters red, the tab white" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^bar //p' | LC_ALL=C tr '\n' ' ' )" "nu-system 0/6 1/6 4/6 0/6b 4/7 True nu-blue 16/252 124/252b 21/252 245/252 18/231b True nu-gray 16/252 124/252b 19/252 245/252 19/231b True "
rigAssert "Magic is the first of the styles wherever they are offered, and Turbo Vision stays the one the screen starts in" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^order //p' )" "nu tv bw first tv-system"

echo "-- the colours of a style: its value is <style>-<colours>; a style alone is the value it was before; each scheme draws and leaves nothing --"
rigNames="$( "$rigPython" -I -B - "$rigScreen" <<'RIGPY' 2>&1
import importlib.util, sys
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print("first %s %s" % (module.STYLE_FIRST, module.STYLE["value"]))
print("styles %s" % ",".join("%s=%s" % (name, style["label"]) for name, style in module.STYLES))
print("colours %s" % ",".join("%s=%s" % pair for pair in module.COLOURS))
taken = []
for name in ("tv-system", "tv-blue", "tv-gray", "tv-dark", "tv-light", "bw-system", "bw-dark", "bw-light", "bw-blue",
             "nu-system", "nu-blue", "nu-gray", "nu-dark", "nu-light", "tv", "bw", "magic", "nu", "magic-light", "magic-dark",
             "magic-system", "mc", "zz", "tv-", "tv-green", "-dark", "tv-dark-x", "TV-blue", ""):
    module.setStyle("tv-gray")
    taken.append(module.STYLE["value"] if module.setStyle(name) else "refused:" + module.STYLE["value"])
print("taken %s" % " ".join(taken))
RIGPY
)"
rigAssert "the styles in their order, Magic first, and the colours each is drawn in" "$( printf '%s\n' "$rigNames" | LC_ALL=C sed -n 's/^styles //p' ) $( printf '%s\n' "$rigNames" | LC_ALL=C sed -n 's/^colours //p' )" "nu=Magic,tv=Turbo Vision,bw=Basic B/W system=System,dark=Dark/Blue,light=Light/Gray"
rigAssert "the screen starts in Turbo Vision in the terminal's own colours, as it did" "$( printf '%s\n' "$rigNames" | LC_ALL=C sed -n 's/^first //p' )" "tv-system tv-system"
rigAssert "a style with its colours is taken by its own names of them, dark for blue and light for gray where it has those; a style alone, as one was saved before, in the colours it was drawn in then, Magic also by its name of then; anything else is refused and leaves the style" "$( printf '%s\n' "$rigNames" | LC_ALL=C sed -n 's/^taken //p' )" "tv-system tv-blue tv-gray tv-blue tv-gray bw-system bw-dark bw-light refused:tv-gray nu-system nu-blue nu-gray nu-blue nu-gray tv-system bw-system nu-gray nu-gray nu-gray nu-blue nu-system refused:tv-gray refused:tv-gray refused:tv-gray refused:tv-gray refused:tv-gray refused:tv-gray refused:tv-gray refused:tv-gray"
rigAssert "Turbo Vision blue, as its editor: yellow on blue, a white frame, a cyan bar, green buttons; on eight colours the same plan" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^256 tv-blue://p' ) $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^8 tv-blue://p' )" "227/19 16/37 231/19 16/34:0 3/4b 0/6 7/4b 0/2:0"
rigAssert "Turbo Vision gray, as its demo: black on grey, a white frame, a cyan bar, green buttons; on eight colours the same plan" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^256 tv-gray://p' ) $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^8 tv-gray://p' )" "16/248 16/37 231/248 16/34:0 0/7 0/6 7/7b 0/2:0"
rigAssert "Turbo Vision in the system's colours: the terminal's own eight on any terminal" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^256 tv-system://p' ) $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^8 tv-system://p' )" "7/4 0/6 7/4b 0/2:0 7/4 0/6 7/4b 0/2:0"
rigAssert "Basic B/W: in the system's colours none, dark white on black, light black on white, in greys and on eight colours" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^256 bw-system://p' ) | $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^256 bw-dark://p' ) $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^8 bw-dark://p' ) | $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^256 bw-light://p' ) $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^8 bw-light://p' )" "none none none none:0 | 252/16 16/252 231/16b 16/252:0 7/0 0/7 7/0b 0/7:0 | 16/231 231/16 16/231b 231/16:0 0/7 7/0b 0/7b 7/0b:0"
rigAssert "each scheme of exact shades has its colours, of the eight and of the palette, for every look Turbo Vision and Basic B/W draw, and Basic B/W for every look" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^exact \([a-z-]*\) /\1:/p' | LC_ALL=C tr '\n' ' ' )" "tv-blue:102 of 141 True tv-gray:102 of 141 True bw-dark:141 of 141 True bw-light:141 of 141 True "
rigKept(){ ## tag of the screen before, tag of it with the dialog, tag of the roles of that, the box of the dialog -- the cells its shadow falls on: how many keep what stood there before, of how many, whether any of them holds a character, and whether each is in the look of a shadow
	printf '%s\n' "$rigOut" | "$rigPython" -I -B -c '
import sys
before, during, roles, box = sys.argv[1:5]
left, top, width, height = (int(word) for word in box.split(","))
held = {}
for line in sys.stdin.read().splitlines():
    tag, bar, rest = line.partition("|")
    if bar:
        held.setdefault(tag, []).append(rest[:-1])
cells = [(line, column) for line in range(top + 1, top + height) for column in (left + width, left + width + 1)]
cells += [(top + height, column) for column in range(left + 2, left + width + 2)]
kept = [held[during][line][column] for line, column in cells if held[during][line][column] == held[before][line][column]]
print("kept %d of %d %s %s" % (len(kept), len(cells), "drawn" if "".join(kept).strip() else "blank",
                               "shadow" if all(held[roles][line][column] == "w" for line, column in cells) else "not-shadow"))
' "$1" "$2" "$3" "$4"
}
rigCase schemes
rigScript <<'RIGSCRIPT'
turn
keys 8
wait list 30
turn
style tv-blue
keys I
get c1
keys I
get c2
keys I
get c3
style tv-system
keys i
get k1
keys i
get k2
keys i
get k3
style bw-system
keys i
get k4
keys I
get k5
keys F9
get k6
style tv-system
turn
show wts
rigdialog
turn
get dts
show dts
roles dtsr
keys ESC
turn
style tv-blue
turn
show wtd
rigdialog
turn
get dtd
show dtd
roles dtdr
keys ESC
turn
style tv-gray
turn
show wtl
rigdialog
turn
get dtl
show dtl
roles dtlr
keys ESC
turn
style bw-system
turn
show wbs
rigdialog
turn
show dbs
keys ESC
turn
style bw-dark
turn
show wbd
rigdialog
turn
show dbd
keys ESC
turn
style bw-light
turn
show wbl
rigdialog
turn
show dbl
keys ESC
turn
RIGSCRIPT
rigAssert "I takes the next style in the colours of now: Basic B/W, Magic, Turbo Vision, each dark" "$( rigVal c1.style )-$( rigVal c1.colours ) [$( rigVal c1.notice )] $( rigVal c2.style )-$( rigVal c2.colours ) $( rigVal c3.style )-$( rigVal c3.colours )" "bw-dark [interface style: Basic B/W - Dark/Blue] nu-blue tv-blue"
rigAssert "i takes the next colours in the style of now: System, Dark/Blue, Light/Gray, System again, each by the style's own name; F9 takes the next style as I does" "$( rigVal k1.style )-$( rigVal k1.colours ) [$( rigVal k1.notice )] $( rigVal k2.style )-$( rigVal k2.colours ) $( rigVal k3.style )-$( rigVal k3.colours ) $( rigVal k4.style )-$( rigVal k4.colours ) $( rigVal k5.style )-$( rigVal k5.colours ) $( rigVal k6.style )-$( rigVal k6.colours )" "tv-blue [interface style: Turbo Vision - Dark/Blue] tv-gray tv-system bw-dark nu-blue tv-blue"
rigAssert "Turbo Vision draws the same characters in each of its colours, with or without a dialog" "$( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^wts|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^wtd|//p' )" ] && [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^wts|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^wtl|//p' )" ] && echo same || echo differs ) $( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^dts|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^dtd|//p' )" ] && [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^dts|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^dtl|//p' )" ] && echo same || echo differs )" "same same"
rigAssert "Basic B/W draws the same characters in each of its colours too" "$( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^wbs|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^wbd|//p' )" ] && [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^wbs|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^wbl|//p' )" ] && echo same || echo differs ) $( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^dbs|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^dbd|//p' )" ] && [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^dbs|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^dbl|//p' )" ] && echo same || echo differs )" "same same"
rigAssert "Turbo Vision: the active window has the box that closes at the left of its top border and the one that zooms at its right; the other window has neither" "$( rigScreenHolds wts '╔═[■]═' ) $( rigScreenHolds wts '═[↕]═╗' ) $( rigScreenHolds wts '┌─[■]' ) $( rigScreenHolds wts '[↕]─┐' )" "1 1 0 0"
rigAssert "Turbo Vision: a dialog has the box that closes at the left of its top border, its buttons are bars with a shadow of ▅ beside and under, the black of the shadow over the dialog and under it the other way round, its radio buttons have a dot" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^dts|' | LC_ALL=C grep -o -F '╔═[■]═' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ) $( rigScreenHolds dts ' »OK« ▅   Cancel  ▅' ) $( rigScreenHolds dts ' ▅▅▅▅▅▅  ▅▅▅▅▅▅▅▅▅▅' ) $( rigScreenHolds dts '[ Cancel ]' ) $( rigScreenHolds dts '(•) another' ) $( rigScreenHolds dts '(*)' )" "1 1 1 0 1 0"
rigAssert "Turbo Vision: the shadow of a dialog keeps what lies under it, two cells at its right and a line under it, drawn again in the look of a shadow, in each of its colours" "$( for rigOne in ts td tl ; do rigKept "w$rigOne" "d$rigOne" "d${rigOne}r" "$( rigVal "d$rigOne.dialogBox" )" | LC_ALL=C awk '{ printf "[%s %s]", ( $2 == $4 && $4 > 0 ? "all" : $2 "/" $4 ), $5 " " $6 }' ; done )" "[all drawn shadow][all drawn shadow][all drawn shadow]"
rigAssert "Basic B/W keeps its frames, its buttons between brackets and its radio buttons, and no icon" "$( rigScreenHolds dbs '[»OK«]  [ Cancel ]' ) $( rigScreenHolds dbs '(*) another' ) $( rigScreenHolds wbs '[■]' ) $( rigScreenHolds dbs '[■]' )" "1 1 0 0"
rigLeaves(){ ## style -- one scheme drawn with a menu and with a dialog, each closed again: whether what is drawn then is what a new terminal shows of the same state, each time, and how many texts were put past a line or the screen
	rigCase "leaves-$1"
	rigScript <<RIGSCRIPT
turn
keys 8
wait list 30
turn
style $1
turn
keys F10
turn
keys ESC
turn
show m
fresh mfresh
rigdialog
turn
keys ESC
turn
show d
fresh dfresh
get end
RIGSCRIPT
	printf '%s:%s,%s,%s' "$1" "$( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^m|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^mfresh|//p' )" ] && echo same || echo differs )" "$( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^d|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^dfresh|//p' )" ] && echo same || echo differs )" "$( rigVal end.spills )"
}
rigLeft=""
for rigOne in nu-system nu-blue nu-gray tv-system tv-blue tv-gray bw-system bw-dark bw-light ; do
	rigLeft="$rigLeft $( rigLeaves "$rigOne" )"
done
rigAssert "each style in each of its colours: a menu and a dialog closed leave nothing, and nothing is drawn past a line or the screen" "$rigLeft" " nu-system:same,same,0 nu-blue:same,same,0 nu-gray:same,same,0 tv-system:same,same,0 tv-blue:same,same,0 tv-gray:same,same,0 bw-system:same,same,0 bw-dark:same,same,0 bw-light:same,same,0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN SETTINGS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_SETTINGS: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
