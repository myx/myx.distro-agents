#!/usr/bin/env bash
## Behavioural check on the roots `Settings` and `Configuration` of the manager screen (sh-lib/AgentsManagerScreen.py),
## run rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.test.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.test.sh), which notes each start and prints the fixture: rows in the form
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
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.test.py"
rigTools="$rigFixtures/manager-screen.tools.test.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
rigTmp="$( mktemp -d -t AgentsManagerScreenSettingsCheck )" || exit 1
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
rigEnv=/rig/ws_rig/.local/home/rig/MDLT.settings.env
## The choices of the style, as the digest gives them: each style in each of its colours, Magic first.
rigStyles='nu-system=Magic_-_System,nu-blue=Magic_-_Dark/Blue,nu-gray=Magic_-_Light/Gray,tv-system=Turbo_Vision_-_System,tv-blue=Turbo_Vision_-_Dark/Blue,tv-gray=Turbo_Vision_-_Light/Gray,bw-system=Basic_B/W_-_System,bw-dark=Basic_B/W_-_Dark/Blue,bw-light=Basic_B/W_-_Light/Gray'
rigTeamEnv=/rig/ws_rig/.local/.agents/magic-team.agent.env
## A digest of eight subjects, every line of fifteen fields. Of the configuration: workspace, two paths, one of
## them missing, and a place; cli, what the workspace asks for, a leg with a secret that is set, whose row carries
## a value the screen must never show, and one that is missing, and a leg that is not usable; systems, a scope
## that is set, one that is set and lacks two keys, one that misses a key, and a system no scope holds; loop, an
## outcome, a date and a word; scopes, two scopes, one of forty-two keys, so that the subject is longer than the
## pane, the other with a key and a secret that are missing; and one line of console. Of the settings: the style
## of the interface, a choice; of console a choice saved for the user and a line of a kind the screen does not
## know; of control two numbers, each with its range, saved for the workspace.
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow subject workspace 3
	rigConf workspace paths workspace-root set /rig/ws_rig
	rigConf workspace paths session-stores missing /rig/ws_rig/.local/agents/stores
	rigConf workspace places ws-rig set /rig/ws_rig
	rigRow subject cli 7
	rigConf cli workspace SPAWN_CLI_SERVICE set claude
	rigConf cli workspace SPAWN_HARNESS_TIER missing -
	rigConf cli claude present set /rig/harness/claude.sh
	rigConf cli claude ANTHROPIC_API_KEY secret-set sk-must-never-show Anthropic_API_Key 'The_key_the_Claude_CLI_signs_in_with.'
	rigConf cli claude CLAUDE_CODE_OAUTH_TOKEN secret-missing -
	rigConf cli claude usable set yes
	rigConf cli grok usable missing no
	rigRow subject systems 4
	rigConf systems slack magic-team set -
	rigConf systems slack magic-coordinator set SLACK_APP_TOKEN,SLACK_SIGNING_SECRET
	rigConf systems confluence magic-team missing CONFLUENCE_SPACE
	rigConf systems jira - missing -
	rigRow subject loop 3
	rigConf loop main-loop MAIN_LOOP_LAST_OUTCOME set failed
	rigConf loop heartbeat recheck-date set 2026-10-09_04:28_+0000
	rigConf loop heartbeat running set no
	rigRow subject scopes 44
	rigConf scopes magic-coordinator EMAIL_USER set coordinator@rig.example
	rigConf scopes magic-coordinator SLACK_BOT_TOKEN secret-set -
	rigNumber=1 ; while [ "$rigNumber" -le 40 ] ; do rigConf scopes magic-coordinator "$( printf 'KEY_%02d' "$rigNumber" )" set "$( printf 'value_%02d' "$rigNumber" )" ; rigNumber=$(( rigNumber + 1 )) ; done
	rigConf scopes magic-team TRELLO_BOARD missing -
	rigConf scopes magic-team TRELLO_TOKEN secret-missing -
	rigRow subject interface 1 Interface_Settings
	rigRow line interface style MDAT_MANAGER_STYLE set tv-system Interface_Style 'How_the_manager_screen_is_drawn:_its_frames,_its_colours_and_its_keys.' yes choice user default "$rigStyles" "$rigEnv" settings
	rigRow subject console 3 Console_Behaviour
	rigRow line console history MDLT_CONSOLE_HISTORY set workspace-personal Console_History_Type 'Where_a_console_keeps_the_shell_history_of_this_user.' yes choice user user 'workspace-personal=Per_User_In_This_Workspace,bash-default=The_File_Bash_Uses' "$rigEnv" settings
	rigConf console origin MDLT_CONSOLE_ORIGIN set source Console_Tooling_Origin 'Where_the_consoles_of_this_workspace_load_their_tools_from.'
	rigRow line console title RIG_CONSOLE_TITLE set rig_title Console_Title 'What_a_console_shows_as_its_title.' yes text user default - "$rigEnv" settings
	rigRow subject control 2 Session_Control
	rigRow line control request SESSION_CONTROL_REQUEST_SECONDS set 5 Control_Request_Seconds 'How_many_seconds_a_console_waits_for_a_session_to_answer_a_request.' yes number workspace default 1..60 "$rigTeamEnv" settings
	rigRow line control kill SESSION_CONTROL_KILL_SECONDS set 30 Control_Kill_Seconds 'How_many_seconds_the_carrying_out_of_a_kill_may_take.' yes number workspace workspace 5..600 "$rigTeamEnv" settings
} > "$rigF/rows.--manager-config-digest"
rigRow counters 0 0 0 0 0 0.42 > "$rigF/rows"
rigRow saved MDAT_MANAGER_STYLE nu-blue user "$rigEnv" > "$rigF/rows.--manager-config-set"
rigRow saved SESSION_CONTROL_REQUEST_SECONDS 12 workspace "$rigTeamEnv" > "$rigF/rows.--manager-config-set SESSION_CONTROL_REQUEST_SECONDS 12"
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
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize %s\nroot sessions\n' "$rigTools" "${rigSize:-120 40}" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
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
	LC_ALL=C grep -c -v -x -e '--manager-session-list' -e '--manager-dashboard-read' -e '--manager-config-digest --full' -e '--manager-place-list' "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- Configuration lists the subjects of its lines, and one read of the digest fills both roots --"
rigCase list
rigScript <<'RIGSCRIPT'
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
cells row6 7 85 119
cells row7 8 85 119
cells row8 9 85 119
cells row9 10 85 119
cells row10 11 85 119
cells row11 12 85 119
keys LEFT
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
cells srow3 4 85 119
cells srow4 5 85 119
cells srow5 6 85 119
show su
get once
advance 11
wait list 30
get twice
RIGSCRIPT
rigAssert "a root not entered: the digest is read once the selection has rested on its row, and the left window then holds what the root holds" "$( rigVal on.selected ) [$( rigVal on.reading )] $( rigVal on.viewLines )" "configuration [] 12"
rigAssert "entering it afterwards asks for nothing more: the one read of the digest was made for the row" "$( rigVal asked.path ) [$( rigVal asked.reading )]" "configuration []"
rigAssert "its three folders and then its subjects are listed under the row that goes up, the subjects in the order of the operation, each a row that is entered" "[$( rigVal title )] $( rigVal in.rows ) [$( rigVal row1 )][$( rigVal row2 | sed 's/  *$//' )][$( rigVal row3 | sed 's/  *$//' )][$( rigVal row4 | sed 's/  *$//' )][$( rigVal row8 | sed 's/  *$//' )][$( rigVal row10 | sed 's/  *$//' )][$( rigVal row11 )]" "[Configuration] 10 [>..][ Config Checker                  ►][ Server Keys                     ►][ Tooling Commands                ►][ loop                            ►][ Console Behaviour               ►][]"
rigAssert "a subject with missing lines carries their count at the end of its row" "[$( rigVal row5 )][$( rigVal row6 )][$( rigVal row7 )][$( rigVal row9 )]" \
	"[ workspace             1 missing ►][ cli                   3 missing ►][ systems               2 missing ►][ scopes                2 missing ►]"
rigAssert "on the row that goes up the left pane says what the root holds, and that a wizard will change it" "[$( rigPane u 3 )][$( rigPane u 5 )][$( rigPane u 6 )]" "[ 6 subjects, 62 lines, 8 missing.][ What was set when the workspace was deployed and configured. For viewing: nothing][ of it is changed from here, a wizard will change it later.]"
rigAssert "back at the root it says what it held"                   "[$( rigVal root.path )] $( rigVal root.selected ) [$( rigPane r 3 )]" "[] configuration [ 6 subjects, 62 lines, 8 missing.]"
rigAssert "Settings, not entered yet, says what it holds from that same read" "$( rigVal sroot.selected ) [$( rigPane sr 3 )]" "settings [ 3 subjects, 5 lines, 0 missing.]"
rigAssert "it lists the subjects that have a line of the settings, a subject of both roots in each" "[$( rigVal stitle )] $( rigVal sin.rows ) [$( rigVal srow2 | sed 's/  *$//' )][$( rigVal srow3 | sed 's/  *$//' )][$( rigVal srow4 | sed 's/  *$//' )][$( rigVal srow5 )]" "[Settings] 4 [ Interface Settings              ►][ Console Behaviour               ►][ Session Control                 ►][]"
rigAssert "and says what the root is for"                           "[$( rigPane su 3 )][$( rigPane su 5 )]" "[ 3 subjects, 5 lines, 0 missing.][ What a user sets for himself, and what is changed while the workspace runs. Enter]"
rigAssert "the digest was read once for both roots, whole, and once more when its period had passed" "$( rigCalled '--manager-config-digest --full' ) $( rigCalled --manager-config-digest ) $( rigOthers )" "2 0 0"

echo "-- the left pane shows the selected subject, group by group --"
rigCase subjects
rigScript <<'RIGSCRIPT'
keys 8
wait list 30
keys DOWN DOWN DOWN DOWN
turn
get w
show w
cells wKeys 37 1 83
cells wStatus 39 0 120
keys DOWN
turn
show c
keys DOWN
turn
show s
keys DOWN
turn
get l
show l
RIGSCRIPT
rigAssert "workspace: what it holds, and how many of its lines are missing" "$( rigVal w.selected ) [$( rigPane w 3 )][$( rigPane w 4 )]" "workspace [ workspace: the paths of this workspace, and the places it knows][ 3 lines, 1 missing, each marked !]"
rigAssert "its missing line first, marked, with the group it is of, since it is a subject of the configuration; then its paths under a line of their own, a path with an underscore as it is written" "[$( rigPane w 6 )][$( rigPane w 7 )][$( rigPane w 9 )][$( rigPane w 10 )]" \
	"[ missing, first][   ! session-stores  /rig/ws_rig/.local/agents/stores (missing)  in paths][ paths][     workspace-root  /rig/ws_rig]"
rigAssert "then its places, under a line of their own"               "[$( rigPane w 11 )][$( rigPane w 12 )][$( rigPane w 13 )][$( rigPane w 14 )]" "[][ places][     ws-rig  /rig/ws_rig][]"
rigAssert "under its lines it says that Enter opens it, the sentence broken at the window, which the status line names; it names no key of its own" "[$( rigPane w 15 )][$( rigPane w 16 )] [$( rigVal wKeys )] [$( rigVal wStatus | sed 's/  *$//' )] $( rigVal w.spills )" "[ Enter opens it: its lines one by one, each with what it is and whether it is][ changed from here.] [] [ ENTER Open  BSP Up  a Active  u Read  m Menu  ^X Exit  TAB Window  ? Help] 0"
rigAssert "cli: a missing key first, marked, with its group; then what the workspace asks for, a key as it is written" "[$( rigPane c 3 )][$( rigPane c 6 )][$( rigPane c 7 )][$( rigPane c 11 )][$( rigPane c 12 )]" \
	"[ cli: the CLI service the workspace asks for, and each CLI the console knows][ missing, first][   ! SPAWN_HARNESS_TIER       missing  in workspace][ workspace][     SPAWN_CLI_SERVICE  claude]"
rigAssert "a secret shows only as configured or not configured: the one that is not among the missing lines, the one that is in its group"      "[$( rigPane c 8 )][$( rigPane c 14 )][$( rigPane c 15 )][$( rigPane c 16 )][$( rigPane c 17 )]" \
	"[   ! CLAUDE_CODE_OAUTH_TOKEN  not configured  in claude][ claude][     present            /rig/harness/claude.sh][     Anthropic API Key  configured  (ANTHROPIC_API_KEY)][     usable             yes]"
rigAssert "nothing of the value of a secret is on the screen, though its row carried one" "$( rigScreenHolds c 'sk-must' ) $( rigScreenHolds c 'never-show' ) $( LC_ALL=C grep -c -F 'sk-must-never-show' "$MANAGER_SCREEN_RIG/rows.--manager-config-digest" )" "0 0 1"
rigAssert "a CLI that is not usable is marked, among the missing lines, with its name"                       "[$( rigPane c 9 )]" "[   ! usable                   no  in grok]"
rigAssert "systems: a scope that is set, and one that is set and lacks keys" "[$( rigPane s 4 )][$( rigPane s 10 )][$( rigPane s 11 )][$( rigPane s 12 )]" \
	"[ 4 lines, 2 missing, each marked !][ slack][     magic-team         set][     magic-coordinator  set, lacks SLACK_APP_TOKEN, SLACK_SIGNING_SECRET]"
rigAssert "a scope that misses a key, and a system no scope holds: the first lines, each with its system"   "[$( rigPane s 6 )][$( rigPane s 7 )][$( rigPane s 8 )]" "[ missing, first][   ! magic-team  missing: CONFLUENCE_SPACE  in confluence][   ! no scope    missing  in jira]"
rigAssert "loop: no line is missing, and a date reads with its spaces" "$( rigVal l.selected ) [$( rigPane l 4 )][$( rigPane l 6 )][$( rigPane l 7 )][$( rigPane l 9 )][$( rigPane l 10 )][$( rigPane l 11 )]" \
	"loop [ 3 lines][ main-loop][     MAIN_LOOP_LAST_OUTCOME  failed][ heartbeat][     recheck-date  2026-10-09 04:28 +0000][     running       no]"

echo "-- a subject longer than the pane scrolls with the focus on the left pane --"
rigCase scroll
rigSize="120 20"
rigScript <<'RIGSCRIPT'
keys 8
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN
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
rigAssert "scopes is selected, longer than the pane, shown from its top, its missing lines first" "$( rigVal top.selected ) $( rigVal top.viewLines ) $( rigVal top.viewTop ) [$( rigPane top 3 )][$( rigPane top 6 )]" "scopes 53 0 [ scopes: each scope that holds a key, with its keys][ missing, first]"
rigAssert "with the focus on the left pane, PageDown shows its next page" "$( rigVal paged.focus ) $( rigVal paged.viewTop ) [$( rigPane paged 3 )]" "view 16 [     KEY_07           value_07]"
rigAssert "and reaches its last lines; the key and the secret that are missing stand marked on its first page, each with its scope" "$( rigPaneHolds top '   ! TRELLO_BOARD  missing  in magic-team' ) $( rigPaneHolds top '   ! TRELLO_TOKEN  not configured  in magic-team' ) $( rigPaneHolds end ' changed from here.' ) $( rigVal end.spills )" "1 1 1 0"

echo "-- a subject is entered: its lines by their labels alone, and the left window shows the one selected --"
rigCase entered
rigScript <<'RIGSCRIPT'
keys 7
wait list 30
keys DOWN DOWN ENTER
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
keys 8
turn
keys DOWN DOWN DOWN DOWN DOWN ENTER
turn
# the lines of this subject stand group by group: two headings stand ahead of this line
keys DOWN DOWN DOWN DOWN DOWN DOWN
turn
get k
show k
cells kStatus 39 0 120
cells kRow 8 85 119
RIGSCRIPT
rigAssert "Enter on a subject opens it: its lines of this root under the row that goes up, by label, nothing at the end of a row" "$( rigVal in.path ) [$( rigVal title )] $( rigVal in.rows ) [$( rigVal row1 )][$( rigVal row2 | sed 's/  *$//' )][$( rigVal row3 | sed 's/  *$//' )][$( rigVal row4 )]" "settings/console [Console Behaviour] 3 [>..][ Console History Type...][ Console Title...][]"
rigAssert "on the row that goes up the left window shows the subject itself" "[$( rigPane f 2 )][$( rigPane f 3 )][$( rigPane f 4 )]" "[ Console Behaviour [wrap]][ Console Behaviour: how the consoles of this workspace behave][ subject console, 2 lines]"
rigAssert "a setting: its label as the title, what it is now first, by the label of the choice and as it is saved" "$( rigVal h.selectedLabel ) [$( rigPane h 2 )][$( rigPane h 3 )][$( rigPane h 4 )]" "Console History Type [ Console History Type [wrap]][ value     Per User In This Workspace (workspace-personal)][]"
rigAssert "then its description, and under it its key, group, state, source and scope" "[$( rigPane h 5 )][$( rigPane h 6 )][$( rigPane h 7 )][$( rigPane h 8 )][$( rigPane h 9 )][$( rigPane h 10 )][$( rigPane h 11 )]" \
	"[ Where a console keeps the shell history of this user.][][ key       MDLT_CONSOLE_HISTORY][ group     history][ state     set][ source    saved for this user][ scope     this user, in this workspace]"
rigAssert "what it takes, where it is saved, and that Enter changes it, which the status line names" "[$( rigPane h 12 )][$( rigPane h 13 )][$( rigPane h 14 )] $( rigPaneHolds h ' keys: ENTER change' ) [$( rigVal hStatus | sed 's/  *$//' )]" \
	"[ takes     Per User In This Workspace, The File Bash Uses][ saved in  /rig/ws_rig/.local/home/rig/MDLT.settings.env][ change    Enter changes it] 1 [ ENTER Change  BSP Up  a Active  u Read  m Menu  ^X Exit  TAB Window  ? Help]"
rigAssert "a setting of a kind the screen does not know shows as it is, with nothing it takes" "[$( rigPane t 3 )] $( rigPaneHolds t ' source    the default' ) $( rigScreenHolds t ' takes ' ) $( rigPaneHolds t ' change    Enter changes it' )" "[ value     rig_title] 1 0 1"
rigAssert "Backspace goes up, onto the subject that was entered"         "$( rigVal back.path ) $( rigVal back.selected )" "settings console"
rigAssert "a secret of the configuration, titled with its group since the subject has several: only its state, its description, and why it is not changed, in the words of its row" "$( rigVal k.path ) [$( rigPane k 2 )][$( rigPane k 3 )][$( rigPane k 5 )] $( rigPaneHolds k ' change    no: set at deployment: a wizard will change it' ) $( rigScreenHolds k 'sk-must' )" "configuration/cli [ claude: Anthropic API Key [wrap]][ value     configured][ The key the Claude CLI signs in with.] 1 0"
rigAssert "such a line is no row that is entered, the left window names no key for it, and the status line no change" "[$( rigVal kRow | sed 's/  *$//' )] $( rigScreenHolds k 'keys:' ) [$( rigVal kStatus | sed 's/  *$//' )]" "[>  Anthropic API Key] 0 [ BSP Up  a Active  u Read  m Menu  ^X Exit  TAB Window  ? Help]"

echo "-- Configuration: Enter on a line changes nothing, and says why --"
rigCase viewing
rigScript <<'RIGSCRIPT'
keys 8
wait list 30
keys DOWN DOWN DOWN DOWN DOWN ENTER
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
	rigRow line interface style MDAT_MANAGER_STYLE set tv-system Interface_Style 'How_the_manager_screen_is_drawn.' yes choice user default "$rigStyles" "$rigEnv" settings
} > "$rigTmp/labelled.digest"
rigCaseLabelled(){ ## name -- a fresh rig whose digest is the labelled one
	rigCase "$1"
	cp "$rigTmp/labelled.digest" "$MANAGER_SCREEN_RIG/rows.--manager-config-digest"
}

echo "-- the labels of the digest: a subject and a line show by their label, the key is the detail --"
rigCaseLabelled labels
rigScript <<'RIGSCRIPT'
turn
keys 8
wait list 30
keys DOWN DOWN DOWN DOWN
turn
get w
keys DOWN
turn
get c
show c
keys 7
turn
keys DOWN
turn
get i
show i
RIGSCRIPT
rigAssert "the subjects are listed by their labels"                  "[$( rigVal w.selectedLabel )] [$( rigVal c.selectedLabel )] [$( rigVal i.selectedLabel )]" "[Workspace Paths] [CLI Services] [Interface Settings]"
rigAssert "the left window is titled by the label, and names the subject as the operation takes it beside its count" "[$( rigPane c 2 )] $( rigPaneHolds c ' subject cli, 2 lines, 1 missing, each marked !' )" "[ CLI Services [wrap]] 1"
rigAssert "a line shows by its label, with its key as the detail after it" "$( rigPaneHolds c '   ! Spawn Harness Tier  missing  (SPAWN_HARNESS_TIER)  in workspace' )" "1"
rigAssert "a line with no label shows by its key"                     "$( rigPaneHolds c '     ODD_KEY  odd' )" "1"
rigAssert "the subject of the interface shows its style as it is, by the label of the choice, and where it comes from" "$( rigPaneHolds i '     Interface Style  Turbo Vision - System, the default  (MDAT_MANAGER_STYLE)' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^i|' | LC_ALL=C grep -F 'Interface Settings ' | LC_ALL=C grep -c -F '►' )" "1 1"

echo "-- Enter on the style: a dialog of its own, the style and its colours; OK takes both at once and saves them as one value --"
rigCaseLabelled style
rigScript <<'RIGSCRIPT'
turn
keys 7
wait list 30
keys DOWN ENTER
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
rigAssert "two groups of radio buttons, the styles Magic first and the colours, each on what this screen is drawn in, with OK and Cancel, and it says whom it is saved for" "$( rigBoxHolds sbox '║ Style ' ) $( rigBoxHolds sbox '║ ( ) Magic ' ) $( rigBoxHolds sbox '║ (•) Turbo Vision ' ) $( rigBoxHolds sbox '║ ( ) Basic B/W ' ) $( rigBoxHolds sbox '║ Colours ' ) $( rigBoxHolds sbox '║ (•) System ' ) $( rigBoxHolds sbox '║ ( ) Dark/Blue ' ) $( rigBoxHolds sbox '║ ( ) Light/Gray ' ) $( rigBoxHolds sbox ' »OK« ▅   Cancel  ▅' ) $( rigBoxHolds sbox 'OK saves it for the user who runs this console, and this screen takes it' ) $( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^sbox|║ ([^)]*) \([A-Za-z/ ]*[A-Za-z]\) .*$/\1/p' | LC_ALL=C tr '\n' ',' )" "1 1 1 1 1 1 1 1 1 1 Magic,Turbo Vision,Basic B/W,System,Dark/Blue,Light/Gray,"
rigAssert "Space chooses the style the bar is on, Tab goes to the colours and Space chooses there; Esc closes, saves nothing and leaves the style" "[$( rigVal magic.dialog )] [$( rigVal dark.dialog )] [$( rigVal esc.dialog )] $( rigVal esc.style )-$( rigVal esc.colours ) $( rigCalled '--manager-config-set MDAT_MANAGER_STYLE nu-blue' )" "[setting-style:style|nu] [setting-style:colours|dark] [] tv-system 1"
rigAssert "OK: this screen takes the style and its colours at once, before the operation has answered" "[$( rigVal ok.dialog )] $( rigVal ok.style )-$( rigVal ok.colours ) [$( rigVal ok.notice )] $( rigScreenHolds after ' This screen is drawn in Magic - Dark/Blue now.' )" "[] nu-blue [save asked of the tooling: Interface Style: Magic - Dark/Blue] 1"
rigAssert "and they are saved by the write operation, once, as one value, by the key of the row" "$( rigCalled '--manager-config-set MDAT_MANAGER_STYLE nu-blue' ) $( LC_ALL=C grep -c -e '--manager-config-set' "$MANAGER_SCREEN_RIG/calls" ) [$( rigVal done.notice )] $( rigVal done.style )-$( rigVal done.colours )" "1 1 [saved: Interface Style: Magic - Dark/Blue] nu-blue"

echo "-- Enter on a number: its range in the dialog, saved for the workspace; one out of its range is not sent --"
rigCase number
rigScript <<'RIGSCRIPT'
turn
keys 7
wait list 30
keys DOWN DOWN DOWN ENTER
turn
keys DOWN
turn
show n
keys ENTER
turn
get dlg
box nbox
keys BACKSPACE ENTER
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
rigAssert "a number: what it is now and where from, what it takes, and that a change is for everybody" "$( rigPaneHolds n ' value     5' ) $( rigPaneHolds n ' source    the default' ) $( rigPaneHolds n ' scope     everybody who works in this workspace' ) $( rigPaneHolds n ' takes     a whole number from 1 to 60' )" "1 1 1 1"
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
keys 7
wait list 30
keys DOWN DOWN ENTER
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
keys 7
wait list 30
keys DOWN ENTER
turn
keys DOWN
turn
keys ENTER DOWN SPACE ENTER
wait action 30
turn
get failed
RIGSCRIPT
rigAssert "the refusal is shown whole, under its own title"          "[$( rigVal failed.dialogTitle )] [$( rigVal failed.dialogHolds )]" "[The save failed] [operation: --manager-config-set MDAT_MANAGER_STYLE bw-system / rig-tools: a line that is no error / rig-tools: ⛔ ERROR: the rig said fail]"

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
keys DOWN ENTER
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
keys 7
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
rigAssert "a row that is entered has its mark at the right edge of the row, in every subject of the root" "$( rigScreenHolds m '► |' ) $( rigScreenHolds m 'Interface Settings...' )" "3 0"
rigAssert "the status line: each key a chip of its own colour, the text as it was" "$( rigSome "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^mr|' | tail -1 | LC_ALL=C tr -d -c 'K' | LC_ALL=C wc -c )" ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^m|' | tail -1 | LC_ALL=C grep -c -F ' ⏎ Open  ' )" "some 1"
rigAssert "a menu: hung from the bar, its own colour up to a thin line at its bottom, no mark at its sides, its shadow at its right and half a line under it, the black of it the ground of its cells" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^mm|' | LC_ALL=C grep -c -F '▀' ) $( rigSome "$( rigScreenHolds mm '▁▁▁' )" ) $( rigScreenHolds mm '▄▄▄' ) $( rigScreenHolds mm '▛' ) $( rigScreenHolds mm '▜' ) $( rigScreenHolds mm '▙' ) $( rigScreenHolds mm '▟' ) $( rigScreenHolds mm '█' ) $( rigSome "$( rigCount mmr z )" )" "0 some 1 0 0 0 0 0 some"
rigAssert "closed, it leaves nothing: what is drawn is what a new terminal shows of the same state" "$( [ "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^mafter|//p' )" = "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^mfresh|//p' )" ] && echo same || echo differs ) $( rigScreenHolds mafter '▄▄▄' )" "same 0"
rigAssert "a dialog: its own colour, a thin line on the bottom edge of the line above it, its title a tab on it, and of its last line, no mark at its sides, its shadow at its right and half a line under it" "$( rigBoxHolds mbox '▁ A dialog of the rig ▁' ) $( rigBoxHolds mbox '▁▁▁' ) $( rigBoxHolds mbox '▔' ) $( rigBoxHolds mbox '▀' ) $( rigBoxHolds mbox '▛' ) $( rigBoxHolds mbox '▜' ) $( rigBoxHolds mbox '▐' ) $( rigBoxHolds mbox '▌' ) $( rigBoxHolds mbox '█' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^mbox|' | tail -1 | LC_ALL=C grep -c -F '| ▄▄▄' )" "1 2 0 0 0 0 0 0 0 1"
rigAssert "its boxes and its radio buttons: a tick and a dot where chosen, a faint dot where not" "$( rigBoxHolds mbox '|  · alpha' ) $( rigBoxHolds mbox '|  ✓ beta' ) $( rigBoxHolds mbox '|  · one way' ) $( rigBoxHolds mbox '|  • another' ) $( rigBoxHolds mbox '[X]' ) $( rigBoxHolds mbox '(*)' )" "1 1 1 1 0 0"
rigAssert "a field to type in stands between brackets, its room filled with dots" "$( rigBoxHolds mbox '|  [typed.....' ) $( rigBoxHolds mbox '..]  ' )" "1 1"
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
RIGPY
)"
rigAssert "Magic on a terminal of 256 colours, in its grey colours unless told another: its own shades of the palette, white on deep blue windows, a white bar with blue text for the selection, a white line on the deep blue of the active window and on the dark grey desktop over it, the title strip white, red chips, a yellow title for what failed; the palette itself is never changed" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^256 magic://p' )" "231/19 19/231b 231/19b 16/250 231/19 231/238 19/231b 231/124b 226/124b:0"
rigAssert "Turbo Vision keeps its eight colours there, its buttons a green bar" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^256 tv://p' )" "7/4 0/6 7/4b 0/2:0"
rigAssert "Magic on a terminal of eight colours: the basic colours of the same plan" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^8 magic://p' ) $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^8 tv://p' ) $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^pairs 8 //p' )" "7/4b 4/7 7/4b 0/7 7/4 7/0 4/7 7/1b 3/1b:0 7/4 0/6 7/4b 0/2:0 True"
rigAssert "with no colours no pair is made, and every look of LOOKS has its colours in Magic, each of the eight and of the palette" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^0 magic://p' ) $( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^declared //p' | LC_ALL=C tr '\n' ' ' )" "none none none none none none none none none:0 nu-blue 42 of 42 True nu-gray 42 of 42 True nu-system 42 of 42 True "
rigAssert "Magic in the terminal's own colours (nu-system) takes its own choice of the eight named ones, on a terminal of 256 colours too" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^256 system nu-system://p' )" "7/4 0/6 7/4b 0/7 7/4 7/4 4/7 0/3 3/1b:0"
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
rigAssert "each scheme of exact shades has its colours, of the eight and of the palette, for every look Turbo Vision and Basic B/W draw, and Basic B/W for every look" "$( printf '%s\n' "$rigColours" | LC_ALL=C sed -n 's/^exact \([a-z-]*\) /\1:/p' | LC_ALL=C tr '\n' ' ' )" "tv-blue:30 of 42 True tv-gray:30 of 42 True bw-dark:42 of 42 True bw-light:42 of 42 True "
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
keys 7
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
keys 7
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
