#!/usr/bin/env bash
## Behavioural check on the folder `Scope Settings` of the root `Settings` of the manager screen (F11.7 of the refactorings epic), run rather than read.
## The screen's own code runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it
## calls a stand-in script (check-fixtures/manager-screen.tools.stub.sh), which notes each start and what came on its standard input, and prints the
## fixture: the rows --manager-scope-list, --manager-scope-read <id> and --manager-scope-reveal <id> <key> print.
## Held (F11.7: "`Scope Settings` per subsystem, moved here from `Configuration` ... displays all `--config` items of every installed subsystem as sources,
## allows edit and delete, and shows visually which item belongs to which subsystem and group. A subsection is a group of settings and becomes a folder,
## named like `Agents: client-ndm` ... A whole subsection can be cleared, reset or deleted where the subsystem allows it. Entering an exact variable name
## unrolls it. The content pane shows a readable summary, with the variable name and value in a table and the pointless text removed. Enter edits, `d`
## deletes with confirmation"; the coordinator's rulings: the scopes as they exist, the preset-<name> blocks each its own folder of the agents, Clear for any
## scope, Delete where many exist, no Reset with nothing to reset to):
##   1. the folder stands in Settings, ahead of its subjects, and no longer in Configuration; the lines of the digest's scopes stay where `Member Settings` reads them
##   2. entered, it lists the scopes in the order of the operation, each a folder by its label as its subsystem names it
##   3. a scope selected shows its variables as a table of name and value, a credential in its one form, one that holds nothing as `-`; entered, its variables are
##      its rows, and one selected shows its name and its value as that table's one row; the status line names Edit and Delete there, Clear and Delete on a scope
##   4. Enter on a variable edits it: its value is read whole for the field, the OK of the form saves what stands there through `--manager-scope-set <id> <name>` with
##      the value on the standard input and never in the command; a field that holds what the variable held saves nothing; Esc and Cancel save nothing
##   5. a credential's form shows its one form, reads its value whole only on Reveal (Ctrl-R), and saves only a value typed over it
##   6. `d` on a variable asks first, naming the scope and the variable; its OK calls `--manager-scope-unset <id> <name>`; Esc calls nothing
##   7. `c` on a scope that holds a variable and `D` on a scope of many ask first for the word typed whole (`yes`) and call `--manager-scope-clear <id>` and
##      `--manager-scope-delete <id>`; a scope that holds nothing is not cleared, and the workspace's own scope is not deleted: each says why in the status line
## Offline: no operation of the real tooling is called.
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
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenScopesCheck )" || exit 1
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
rigConf(){ ## subject, group, key, state, value -- a line of the configuration as `--full` prints one
	rigRow line "$1" "$2" "$3" "$4" "$5" "${6:--}" "${7:--}" 'no:set_at_deployment:_a_wizard_will_change_it' - - - - - configuration
}
rigSecret="Hd3mTyRIGSECRET31Vq7zKe"
rigShown="Hd3mT******************"
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow scope common:workspace Common:_workspace 2 yes no /rig/ws/.local/MDLT.settings.env
	rigRow scope common:user-rig Common:_user-rig 1 yes no /rig/ws/.local/home/rig/MDLT.settings.env
	rigRow scope remote:mdci01.rig.example Remote:_mdci01.rig.example 2 yes yes /rig/ws/remote/static/mdci01.rig.example.remote.env
	rigRow scope agents:keeper-rig Agents:_keeper-rig 0 no yes /rig/ws/.local/.agents/keeper-rig.agent.env
	rigRow scope agents:magic-team Agents:_magic-team 3 yes yes /rig/ws/.local/.agents/magic-team.agent.env
	rigRow scope agents:preset-rig Agents:_preset-rig 2 yes yes /rig/ws/.local/.agents/preset-rig.agent.env
} > "$rigF/rows.--manager-scope-list"
{
	rigRow scope agents:magic-team Agents:_magic-team 3 yes yes /rig/ws/.local/.agents/magic-team.agent.env
	rigRow key SPAWN_CLI_SERVICE set claude setting the_agent_CLI_this_workspace_starts
	rigRow key SLACK_BOT_TOKEN secret-set "$rigShown" credential the_bot_token_of_Slack
	rigRow key EMPTY_KEY missing - setting -
} > "$rigF/rows.--manager-scope-read agents:magic-team"
printf 'claude\n' > "$rigF/rows.--manager-scope-reveal agents:magic-team SPAWN_CLI_SERVICE"
printf '%s\n' "$rigSecret" > "$rigF/rows.--manager-scope-reveal agents:magic-team SLACK_BOT_TOKEN"
{
	rigRow subject workspace 1
	rigConf workspace paths workspace-root set /rig/ws
	rigRow subject scopes 1
	rigConf scopes magic-team SPAWN_CLI_SERVICE set claude
	rigRow subject interface 1 Interface_Settings
	rigRow line interface style MDAT_MANAGER_STYLE set tv-system Interface_Style 'How_the_manager_screen_is_drawn.' yes choice user default 'nu-system=Magic_-_System,tv-system=Turbo_Vision_-_System' /rig/ws/.local/home/rig/MDLT.settings.env settings
} > "$rigF/rows.--manager-config-digest --full"
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
rigCalls(){ ## how many starts of the operations that write
	LC_ALL=C grep -c -E '^--manager-scope-(set|unset|clear|delete) ' "$MANAGER_SCREEN_RIG/calls" || :
}
rigInput(){ ## the standard input the stand-in was given for an operation, its end of line left out
	LC_ALL=C tr -d '\n' < "$MANAGER_SCREEN_RIG/stdin.$1" 2> /dev/null || :
}

echo "-- 1. the folder stands in Settings, not in Configuration --"
rigCase roots
rigScript <<'RIGSCRIPT'
at @settings
turn
wait list 30
rowids sids
at @configuration
rowids cids
at @configuration scopes
rowids lids
RIGSCRIPT
rigAssert "Settings holds Scope Settings among the rows it always holds, ahead of its subjects" "$( rigVal sids )" ".. scopes interface"
rigAssert "Configuration holds no folder of the scopes: its rows are its folders and its other subjects" "$( rigVal cids | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x scopes || : ) / $( rigVal cids )" "0 / .. checker keys git subsystems workspace"
rigAssert "the lines of the scopes of the digest are still the level Member Settings reads" "$( rigVal lids )" ".. magic-team SPAWN_CLI_SERVICE"

echo "-- 2, 3. entered, and what the left pane shows --"
rigCase entered
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
turn
rowids ids
show f
keys DOWN DOWN DOWN DOWN DOWN
turn
wait focus 30
turn
show g
keys ENTER
wait list 30
turn
get in
rowids kids
keys DOWN
turn
show h
keys DOWN
turn
show i
keys DOWN
turn
show j
RIGSCRIPT
rigAssert "the scopes in the order of the operation, each a folder by its label: the common ones, the remote profile, the agents' scopes, the preset among them" "$( rigVal ids )" ".. common:workspace common:user-rig remote:mdci01.rig.example agents:keeper-rig agents:magic-team agents:preset-rig"
rigAssert "the folder selected: a table of the scopes, each by its label, its variables and its file" "[$( rigPane f 3 | LC_ALL=C tr -s ' ' )][$( rigPane f 5 | LC_ALL=C tr -s ' ' )] $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^f|' | LC_ALL=C tr -s ' ' | LC_ALL=C grep -c -F -e 'Agents: keeper-rig 0 /rig/ws/.local/.agents/keeper-rig.agent.env' )" "[ SCOPE KEYS FILE][ Common: workspace 2 /rig/ws/.local/MDLT.settings.env] 1"
rigAssert "a scope selected: its variables as a table of name and value, a credential in its one form, one that holds nothing as -" "[$( rigPane g 3 | LC_ALL=C tr -s ' ' )][$( rigPane g 5 | LC_ALL=C tr -s ' ' )][$( rigPane g 7 | LC_ALL=C tr -s ' ' )][$( rigPane g 9 | LC_ALL=C tr -s ' ' )] $( rigScreenHolds g "$rigSecret" )" "[ NAME VALUE][ SPAWN_CLI_SERVICE claude][ SLACK_BOT_TOKEN $rigShown][ EMPTY_KEY -] 0"
rigAssert "entered, its variables are its rows, in the order of the file" "$( rigVal in.path ) / $( rigVal kids )" "settings/scopes/agents:magic-team / .. SPAWN_CLI_SERVICE SLACK_BOT_TOKEN EMPTY_KEY"
rigAssert "a variable selected: its name, its value and its type as the one row of that table, and its description under it" "[$( rigPane h 3 | LC_ALL=C tr -s ' ' )][$( rigPane h 5 | LC_ALL=C tr -s ' ' )] $( rigScreenHolds h 'the agent CLI this workspace starts' )" "[ NAME VALUE TYPE][ SPAWN_CLI_SERVICE claude setting] 1"
rigAssert "a credential selected shows its one form, never whole" "[$( rigPane i 5 | LC_ALL=C tr -s ' ' )] $( rigScreenHolds i "$rigSecret" )" "[ SLACK_BOT_TOKEN $rigShown credential] 0"
rigAssert "the status line names Edit and Delete for a variable (ENTER Open stays for the engine's own row)" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^j|' | LC_ALL=C tail -1 | LC_ALL=C grep -c -F -e 'ENTER Edit' -e 'd Delete' )" "1"
rigAssert "the status line names Clear and Delete on a scope" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^g|' | LC_ALL=C tail -1 | LC_ALL=C grep -c -F -e 'c Clear' -e 'D Delete' )" "1"

echo "-- 4. a variable edited --"
rigCase edit
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN
turn
wait focus 30
keys ENTER
wait list 30
keys DOWN
turn
keys ENTER
turn
get open
wait plan 30
turn
get loaded
keys BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE c o d e x
turn
get typed
keys ENTER
turn
wait action 30
turn 2
wait list 30
turn
get saved
RIGSCRIPT
rigAssert "Enter opens the form of the variable, titled by it, with the scope named" "$( rigVal open.dialogTitle ) / $( rigVal open.dialogHolds | LC_ALL=C grep -c -F -e 'Agents: magic-team' ) $( rigVal open.dialogHolds | LC_ALL=C grep -c -F -e 'type: setting' -e 'the agent CLI this workspace starts' )" "Edit: SPAWN_CLI_SERVICE / 1 1"
rigAssert "its value is read whole for the field, by the operation that reads one value, and stands in the field" "$( rigVal loaded.dialog ) / $( rigCalled '--manager-scope-reveal agents:magic-team SPAWN_CLI_SERVICE' )" "scope-edit:words|claude / 1"
rigAssert "the OK of the form saves what stands in the field, by the operation, with the scope and the name as its words and the value on the standard input alone" "$( rigVal typed.dialog ) / $( rigCalled '--manager-scope-set agents:magic-team SPAWN_CLI_SERVICE' ) / [$( rigInput --manager-scope-set )] / $( LC_ALL=C grep -c -F -- 'codex' "$MANAGER_SCREEN_RIG/calls" || : )" "scope-edit:words|codex / 1 / [codex] / 0"
rigAssert "the form is closed, and the list is read again after the save" "[$( rigVal saved.dialog )] $( rigCalled '--manager-scope-read agents:magic-team' )" "[] 2"
rigCase editsame
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN
turn
wait focus 30
keys ENTER
wait list 30
keys DOWN
turn
keys ENTER
turn
wait plan 30
turn
keys ENTER
turn 3
get same
RIGSCRIPT
rigAssert "a field that holds what the variable held saves nothing, and the form closes" "[$( rigVal same.dialog )] $( rigCalls )" "[] 0"
rigCase editearly
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN
turn
wait focus 30
keys ENTER
wait list 30
keys DOWN
turn
keys ENTER
keys ENTER
get early
RIGSCRIPT
rigAssert "before its value has been read the form saves nothing and says why, and stays" "$( rigVal early.dialog | LC_ALL=C cut -d'|' -f1 ) / $( rigVal early.dialogSays ) / $( rigCalls )" "scope-edit:words / nothing is saved yet: its value is still being read / 0"
rigCase editesc
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN
turn
wait focus 30
keys ENTER
wait list 30
keys DOWN
turn
keys ENTER
turn
wait plan 30
turn
keys x ESC
turn
get esc
RIGSCRIPT
rigAssert "Esc saves nothing" "[$( rigVal esc.dialog )] $( rigCalls )" "[] 0"

echo "-- 5. a credential edited --"
rigCase cred
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN
turn
wait focus 30
keys ENTER
wait list 30
keys DOWN DOWN
turn
keys ENTER
turn 2
get open
RIGSCRIPT
rigAssert "Enter opens the form of a credential: its one form in the field, its value not read" "$( rigVal open.dialogTitle ) / $( rigVal open.dialog ) / $( rigCalled "--manager-scope-reveal agents:magic-team SLACK_BOT_TOKEN" )" "Edit: SLACK_BOT_TOKEN / scope-credential:words|$rigShown / 0"
rigCase credreveal
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN
turn
wait focus 30
keys ENTER
wait list 30
keys DOWN DOWN
turn
keys ENTER
turn
keys CTRL-r
turn
wait plan 30
turn
get revealed
keys ENTER
turn 3
get unchanged
RIGSCRIPT
rigAssert "Reveal reads it whole, for as long as the form is open" "$( rigVal revealed.dialog ) / $( rigCalled "--manager-scope-reveal agents:magic-team SLACK_BOT_TOKEN" )" "scope-credential:words|$rigSecret / 1"
rigAssert "the OK of a form that holds the value it showed saves nothing, and the value whole is on the screen of no other view" "[$( rigVal unchanged.dialog )] $( rigCalls )" "[] 0"
rigCase credtyped
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN
turn
wait focus 30
keys ENTER
wait list 30
keys DOWN DOWN
turn
keys ENTER
turn
keys BACKSPACE x y
keys ENTER
turn 3
get typed
RIGSCRIPT
rigAssert "a value typed over the form of a credential is saved through the operation, on its standard input" "$( rigCalled '--manager-scope-set agents:magic-team SLACK_BOT_TOKEN' ) / [$( rigInput --manager-scope-set )]" "1 / [${rigShown%?}xy]"
rigAssert "the credential whole was never asked for by a form that did not reveal" "$( rigCalled "--manager-scope-reveal agents:magic-team SLACK_BOT_TOKEN" ) $( LC_ALL=C grep -c -F -- "$rigSecret" "$MANAGER_SCREEN_RIG/calls" || : )" "0 0"

echo "-- 6. a variable taken out --"
rigCase unset
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN
turn
wait focus 30
keys ENTER
wait list 30
keys DOWN
turn
keys d
turn
get asked
keys ESC
turn
get esc
keys d
turn
keys ENTER
turn 3
get done
RIGSCRIPT
rigAssert "d asks first, naming the scope and the variable" "$( rigVal asked.dialogTitle ) / $( rigVal asked.dialogHolds | LC_ALL=C grep -c -F -e 'Agents: magic-team' ) / $( rigVal asked.dialogHolds | LC_ALL=C grep -c -F -e 'SPAWN_CLI_SERVICE' )" "Delete: SPAWN_CLI_SERVICE / 1 / 1"
rigAssert "Esc calls nothing; the OK of the next call it with the scope and the name as its words, and no value" "[$( rigVal esc.dialog )] $( rigCalled '--manager-scope-unset agents:magic-team SPAWN_CLI_SERVICE' ) $( rigCalls )" "[] 1 1"

echo "-- 7. a scope cleared, a scope deleted --"
rigCase clear
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN
turn
keys c
turn
get asked
keys ENTER
turn
get refused
RIGSCRIPT
rigAssert "c on a scope that holds variables asks first for the word typed whole, naming the scope" "$( rigVal asked.dialogTitle ) / $( rigVal asked.dialogHolds | LC_ALL=C grep -c -F -e 'Agents: preset-rig' )" "Clear: Agents: preset-rig / 1"
rigAssert "without the word nothing is called and the dialog says so" "$( rigVal refused.dialogSays ) / $( rigCalls )" "nothing is cleared: the word typed is not yes / 0"
rigCase clearyes
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN
turn
keys c
turn
keys y e s ENTER
turn 3
get done
RIGSCRIPT
rigAssert "with it, the operation is called with the scope as its only word" "[$( rigVal done.dialog )] $( rigCalled '--manager-scope-clear agents:preset-rig' ) $( rigCalls )" "[] 1 1"
rigCase delete
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
keys DOWN DOWN DOWN
turn
keys D
turn
keys y e s ENTER
turn 3
get done
RIGSCRIPT
rigAssert "D on a scope of many, the remote profile, asks for the word and then calls the delete with the scope as its only word" "$( rigCalled '--manager-scope-delete remote:mdci01.rig.example' ) $( rigCalls )" "1 1"
rigCase refuse
rigScript <<'RIGSCRIPT'
root scopes
turn
keys ENTER
wait list 30
keys DOWN
turn
keys D
turn
get common
keys DOWN DOWN DOWN
turn
keys c
turn
get empty
RIGSCRIPT
rigAssert "the workspace's own scope is not deleted: D opens nothing, and the status line says it is cleared, never deleted" "[$( rigVal common.dialog )] $( rigVal common.notice | LC_ALL=C grep -c -F -e 'cleared, never deleted' )" "[] 1"
rigAssert "a scope that holds nothing is not cleared: c opens nothing, and the status line says there is no variable to take out" "[$( rigVal empty.dialog )] $( rigVal empty.notice | LC_ALL=C grep -c -F -e 'no variable to take out' ) $( rigCalls )" "[] 1 0"

printf '\nTOTAL: %d passed, %d failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
