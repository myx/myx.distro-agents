#!/usr/bin/env bash
## Behavioural check on the form of a credential in the manager screen (sh-lib/manager/AgentsManagerScreen.py, F11.8 of the
## refactorings epic), run rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which notes each start and prints the fixture.
## Held: Enter on a line that is a credential, of a scope or of a CLI, opens its form, in place of saying that a wizard will
## change it: its key, its scope and whether it is changed from here, and its value in the field, in the form of a credential
## the digest gives it, the whole value nowhere on the screen and not read; one button, Reveal, which Ctrl-R presses and the status line names,
## reads the value whole by the setting reader as every program does (`--agents-config-option <scope> --select <key>`, the
## scope of the line, the team's for a CLI), once, and shows it in the field; Esc closes the form and the value whole is on
## the screen no more, nor in a form opened again, which asks for it no more than the first did; a credential that is not
## changed from here has the buttons Close and Reveal and saves nothing; one that is has OK, Reveal and Cancel, saves what was typed as any
## setting is saved, and saves nothing where the field still holds the form shown or the value whole; a line that is no
## credential has neither the button nor its key. Offline: no operation of the real tooling is called.
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
rigTmp="$( rigTempDir AgentsManagerScreenCredentialCheck )" || exit 1
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
rigWhole="rig-the-whole-credential-WHOLEVALUE"
## The digest of a rig whose first subject is the CLI services (F11.7: the scopes are edited in Scope Settings, and these lines are those of a subject of the configuration): a credential that is set, one that is missing, a plain setting, a credential
## that is changed from here (a short text, saved for the workspace) and a plain setting that is changed from here. The digest of
## the other holds a CLI, with the credential of a leg.
{
	rigRow subject cli 5 CLI_Services
	rigConf cli claude SLACK_BOT_TOKEN secret-set 'rig-the-whol***********' Slack_Bot_Token 'The_bot_token.'
	rigConf cli claude TRELLO_TOKEN secret-missing - Trello_Token
	rigConf cli claude SPAWN_CLI_SERVICE set claude Spawn_CLI_Service
	rigRow line cli claude RIG_CREDENTIAL secret-set 'rig-c*****' Rig_Credential 'A_credential_that_is_changed_from_here.' yes text workspace default - /rig/team.env configuration
	rigRow line cli claude RIG_PLAIN set rig_plain Rig_Plain 'A_plain_setting_changed_from_here.' yes text workspace default - /rig/team.env configuration
} > "$rigTmp/scopes.digest"
{
	rigRow subject cli 1 CLI_Services
	rigConf cli claude ANTHROPIC_API_KEY secret-set 'sk-ant-the***********' Anthropic_API_Key 'The_key_the_Claude_CLI_signs_in_with.'
} > "$rigTmp/cli.digest"
rigCase(){ ## name, digest -- a rig of its own, every fixture of this check in it
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cp "$2" "$MANAGER_SCREEN_RIG/rows.--manager-config-digest"
	printf '%s\n' "$rigWhole" > "$MANAGER_SCREEN_RIG/rows.--agents-config-option magic-team --select SLACK_BOT_TOKEN"
	printf '%s\n' "$rigWhole" > "$MANAGER_SCREEN_RIG/rows.--agents-config-option magic-team --select ANTHROPIC_API_KEY"
	printf '%s\n' "$rigWhole" > "$MANAGER_SCREEN_RIG/rows.--agents-config-option magic-team --select RIG_CREDENTIAL"
	rigRow saved RIG_CREDENTIAL typed workspace /rig/team.env > "$MANAGER_SCREEN_RIG/rows.--manager-config-set RIG_CREDENTIAL typed"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
## The commands that take the list into the subject of the CLI services (its level stands, though the Configuration lists CLI Presets and Tiers in its place), and onto its first line
rigIntoSubject=$'at @configuration cli\nturn\nwait list 20\nturn'
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize 120 40\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigCalls(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigSets(){ ## -- how many starts were a save of a setting
	LC_ALL=C grep -c -e '^--manager-config-set' "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- 1. the form of a credential of a scope: its value in the form of a credential, and not read --"
rigCase scope "$rigTmp/scopes.digest"
rigScript <<RIGSCRIPT
$rigIntoSubject
keys DOWN
turn
keys ENTER
turn
get form
show form
RIGSCRIPT
rigAssert "Enter opens its form, titled by the line, and says no wizard will change it" "$( rigVal form.dialogTitle ) [$( rigVal form.notice )]" "Slack Bot Token []"
rigAssert "it holds the key, the scope, that it is not changed from here, and the value in the form of a credential" "$( rigHolds form 'key       SLACK_BOT_TOKEN' ) $( rigHolds form 'scope     magic-team' ) $( rigHolds form 'change    no: set at deployment' ) $( rigHolds form '║   rig-the-whol***********' )" "1 1 1 1"
rigAssert "the value whole is nowhere on the screen, and the setting reader was asked nothing" "$( rigHolds form 'WHOLEVALUE' ) $( rigCalls '--agents-config-option magic-team --select SLACK_BOT_TOKEN' )" "0 0"
rigAssert "the form has the buttons Close and Reveal, no OK, and the status line names the key of Reveal beside those of a form" "$( rigHolds form '»Close«' ) $( rigHolds form 'Reveal' ) $( rigHolds form '»OK«' ) $( rigHolds form '^R Reveal' )" "1 3 0 1"

echo "-- 2. the button Reveal, or its key Ctrl-R, shows the value whole, Esc covers it --"
rigCase reveal "$rigTmp/scopes.digest"
rigScript <<RIGSCRIPT
$rigIntoSubject
keys DOWN
turn
keys ENTER
turn
keys CTRL-r
wait plan 20
turn
get whole
show whole
keys ESC
turn
get closed
show closed
keys ENTER
turn
get again
show again
RIGSCRIPT
rigAssert "it is read by the setting reader, from the scope of the line, once, and stands whole in the field and, wrapped, under the form (F11.7), the form of it gone" "$( rigCalls '--agents-config-option magic-team --select SLACK_BOT_TOKEN' ) $( rigHolds whole "║   $rigWhole" ) $( rigHolds whole '║   rig-the-whol***********' ) $( rigHolds whole 'Its value, whole:' )" "1 2 0 1"
rigAssert "Esc closes the form: the value whole is on the screen no more" "[$( rigVal closed.dialog )] $( rigHolds closed 'WHOLEVALUE' )" "[] 0"
rigAssert "the form opened again shows the form of a credential, and the value whole was not read again" "$( rigHolds again 'WHOLEVALUE' ) $( rigHolds again '║   rig-the-whol***********' ) $( rigCalls '--agents-config-option magic-team --select SLACK_BOT_TOKEN' )" "0 1 1"

echo "-- 3. a credential of a CLI is read from the scope of the team; one that is missing has a form too --"
rigCase cli "$rigTmp/cli.digest"
rigScript <<RIGSCRIPT
$rigIntoSubject
keys DOWN
turn
keys DOWN
turn
keys ENTER
turn
keys CTRL-r
wait plan 20
turn
get cli
show cli
RIGSCRIPT
rigAssert "its form is read as the setting of the team: by its key, from the scope magic-team" "$( rigVal cli.dialogTitle ) $( rigCalls '--agents-config-option magic-team --select ANTHROPIC_API_KEY' ) $( rigHolds cli "║   $rigWhole" )" "Anthropic API Key 1 2"
rigCase missing "$rigTmp/scopes.digest"
rigScript <<RIGSCRIPT
$rigIntoSubject
keys DOWN DOWN
turn
keys ENTER
turn
get missing
show missing
RIGSCRIPT
rigAssert "a credential that is not set has its form too, with the button Close alone" "$( rigVal missing.dialogTitle ) $( rigHolds missing '»Close«' )" "Trello Token 1"

echo "-- 4. a credential that is changed from here: OK saves what was typed, and nothing that was shown --"
rigCase changed "$rigTmp/scopes.digest"
rigScript <<RIGSCRIPT
$rigIntoSubject
keys DOWN DOWN DOWN DOWN
turn
keys ENTER
turn
get open
show open
RIGSCRIPT
rigAssert "its form has OK, Reveal and Cancel, and the status line names the key" "$( rigVal open.dialogTitle ) $( rigHolds open '»OK«' ) $( rigHolds open 'Reveal' ) $( rigHolds open 'Cancel' ) $( rigHolds open '^R Reveal' )" "Rig Credential 1 3 2 1"
rigCase kept "$rigTmp/scopes.digest"
rigScript <<RIGSCRIPT
$rigIntoSubject
keys DOWN DOWN DOWN DOWN
turn
keys ENTER
turn
keys ENTER
turn
get kept
RIGSCRIPT
rigAssert "OK with the field as it was shown saves nothing and closes" "[$( rigVal kept.dialog )] $( rigSets )" "[] 0"
rigCase whole "$rigTmp/scopes.digest"
rigScript <<RIGSCRIPT
$rigIntoSubject
keys DOWN DOWN DOWN DOWN
turn
keys ENTER
turn
keys CTRL-r
wait plan 20
turn
keys ENTER
turn
get whole
RIGSCRIPT
rigAssert "OK with the value whole, as it was read, saves nothing either" "[$( rigVal whole.dialog )] $( rigCalls '--agents-config-option magic-team --select RIG_CREDENTIAL' ) $( rigSets )" "[] 1 0"
rigCase typed "$rigTmp/scopes.digest"
rigScript <<RIGSCRIPT
$rigIntoSubject
keys DOWN DOWN DOWN DOWN
turn
keys ENTER
turn
keys BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE t y p e d
turn
keys ENTER
turn
get typed
RIGSCRIPT
rigAssert "what was typed in its place is saved as any setting is, once, by its key" "$( rigCalls '--manager-config-set RIG_CREDENTIAL typed' ) $( rigSets ) [$( rigVal typed.dialog )]" "1 1 []"

echo "-- 5. the button pressed by Tab and Enter does what its key does --"
rigCase button "$rigTmp/scopes.digest"
rigScript <<RIGSCRIPT
$rigIntoSubject
keys DOWN
turn
keys ENTER
turn
keys TAB TAB ENTER
wait plan 20
turn
get button
show button
RIGSCRIPT
rigAssert "it reads the value, once, shows it whole in the field and wrapped under the form, and the form stays open" "$( rigCalls '--agents-config-option magic-team --select SLACK_BOT_TOKEN' ) $( rigHolds button "║   $rigWhole" ) $( rigVal button.dialogTitle )" "1 2 Slack Bot Token"

echo "-- 6. no other form has the key --"
rigCase plain "$rigTmp/scopes.digest"
rigScript <<RIGSCRIPT
$rigIntoSubject
keys DOWN DOWN DOWN DOWN DOWN
turn
keys ENTER
turn
keys CTRL-r
turn
get plain
show plain
RIGSCRIPT
rigAssert "the form of a plain setting has no such button or key, and the key reads nothing" "$( rigVal plain.dialogTitle ) $( rigHolds plain '^R Reveal' ) $( LC_ALL=C grep -c -e '^--agents-config-option' "$MANAGER_SCREEN_RIG/calls" || : )" "Rig Plain 0 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN CREDENTIAL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_CREDENTIAL: OK (%d assertions, offline)\n' "$rigPassCount"
