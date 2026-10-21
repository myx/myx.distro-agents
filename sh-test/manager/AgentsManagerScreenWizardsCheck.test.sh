#!/usr/bin/env bash
## Behavioural check on the configuration wizards of the manager screen (F11.7 of the refactorings epic), run rather than read. The screen's own code runs
## through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which notes each start and what came on its standard input, and prints the fixture: the rows
## --manager-wizard-read <wizard> and --manager-keys-list print.
## Held (F11.7: "Configurable features have items to show and to configure, as a wizard: one step as a form, or several steps, with proper enums, types, layout and
## flow. The subsystem's console plugin provides the form descriptions for the common popup, form and dialog view. Examples: agents configure cli service. `.local`
## generate server keys. `.local` delete or regenerate server keys, with warnings. `.local` configure git settings. Configuration asks interactively, then performs
## the extra actions needed to apply the state change, possibly with dialogs showing command output"; the coordinator's ruling: "the CLI-service wizard: pick or
## create a preset (cli service, model or macro, effort, its credentials shown as F11.8 defines), and set the team's three tiers to presets with an optional :effort;
## SPAWN_CLI_SERVICE only where no tier is set ... Git settings and the server-key wizards ... each destructive step behind its warning and the typed confirm"):
##   1. the wizards are declared by the features that have them, in a registry of the configuration; `Git Settings` is a folder of the configuration, its three settings its rows
##   2. the CLI service's wizard: `c` on the CLI services (or on a line of them) reads its form once, and opens the steps in order: the preset (one there is, or a new one named),
##      its service, model and effort (no service for a preset that extends one), the credentials of its service in their one form (no step for a service with none), and the
##      tiers (the team's CLI service only where no tier is set); Back goes back, Cancel and Esc leave nothing applied; Finish runs
##      `--manager-wizard-apply cli-service --preset <name>` in the output dialog with the changed answers alone, a line `<key> <TAB> <value>` each, on its standard input
##   2b. F13.4: `s`, Auto-select CLI..., on the item of the CLI services runs `--owner-setup-cli-auto --check` in the output dialog, the one a command of a workspace runs in, and
##      the screen computes nothing of it; where it ended with status 0 the dialog offers `Apply` beside OK, which runs `--owner-setup-cli-auto --apply` in a dialog of its own,
##      and where it ended otherwise OK alone; anywhere else in the configuration it selects nothing
##   3. the git settings' wizard: one step, the name, the email and the key, each as it stands; Finish applies what was changed through `--manager-wizard-apply git-settings`
##   4. the server keys: `n` on a key that is not there asks, with its warning, and runs `--manager-keys-generate <key>`; `R` and `d` on a key that is there ask first
##      for the word typed whole (`regenerate`, `delete`) and run `--manager-keys-regenerate` and `--manager-keys-delete`; a host key of the server takes none
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
rigTmp="$( rigTempDir AgentsManagerScreenWizardsCheck )" || exit 1
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
rigSecret="Hd3mTyRIGSECRET31Vq7zKe"
rigShown="Hd3mT******************"
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow subject cli 1 CLI_Services
	rigRow line cli workspace SPAWN_CLI_SERVICE set claude Spawn_CLI_Service 'The_agent_CLI.' 'no:set_at_deployment:_a_wizard_will_change_it' - - - - - configuration
} > "$rigF/rows.--manager-config-digest --full"
rigCli(){ ## the rows the CLI wizard's read prints, the tiers given as arguments: low normal high
	for rigOne in claude copilot grok gemini scaleway standard-v1 claude-native copilot-native grok-native ; do rigRow option cli-service "$rigOne" "$rigOne" ; done
	for rigOne in low default normal high hard ; do rigRow option effort "$rigOne" "$rigOne" ; done
	rigRow credential claude ANTHROPIC_API_KEY ; rigRow credential claude CLAUDE_CODE_OAUTH_TOKEN ; rigRow credential grok XAI_API_KEY
	rigRow option preset base base ; rigRow option preset ext ext
	rigRow preset base PRESET_CLI_SERVICE set claude
	rigRow preset base PRESET_MODEL_OR_MACRO set normal
	rigRow preset base ANTHROPIC_API_KEY secret-set "$rigShown"
	rigRow preset ext PRESET_EXTEND set base
	rigRow team SPAWN_TIER_LOW "${1:-missing}" "${2:--}"
	rigRow team SPAWN_TIER_NORMAL missing -
	rigRow team SPAWN_TIER_HIGH missing -
}
rigCli > "$rigF/rows.--manager-wizard-read cli-service"
rigCli set base > "$rigTmp/cli-with-tier"
{
	rigRow current user.name Rig_Person
	rigRow current user.email rig@rig.example
	rigRow current ssh-key /rig/home/.ssh/id_ed25519
	rigRow option ssh-key /rig/home/.ssh/id_ed25519 Deploy_Key_To_Add_To_Git
	rigRow option ssh-key /rig/home/.ssh/id_work Work_Key
} > "$rigF/rows.--manager-wizard-read git-settings"
rigFull='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123 mdci@rig-host'
rigKeyRow(){ rigRow key "$1" "$2" "$3" "$4" "$5" "$6" SHORT-never-shown "$7" "$8" "${9:--}" ; }
{
	rigRow group add-to-git 2 Keys_To_Add_To_Git -
	rigRow group trust-on-connect 1 Keys_To_Trust_When_Connecting -
	rigKeyRow deploy Deploy_Key add-to-git 'for_git' ssh-ed25519 SHA256:abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ /rig/home/.ssh/id_ed25519.pub present "${rigFull// /_}"
	rigKeyRow generated Generated_Key add-to-git 'a_key' - - /rig/home/.ssh/id_other.pub absent -
	rigKeyRow host-ed25519 Host_Key_ED25519 trust-on-connect 'a_host_key' ssh-ed25519 SHA256:ZYXWVUTSRQPONMLKJIHGFEDCBAzyxwvutsrqponmlkj /rig/etc/ssh/ssh_host_ed25519_key.pub present "rig-host_ssh-ed25519_AAAAC3NzaC1lZDI1NTE5AAAAIhost"
} > "$rigF/rows.--manager-keys-list"
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
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigApplied(){ ## how many starts of the operations that apply or change
	LC_ALL=C grep -c -E '^--manager-(wizard-apply|keys-(generate|regenerate|delete)) ' "$MANAGER_SCREEN_RIG/calls" || :
}
rigInput(){ ## the standard input the stand-in was given for an operation, its end of lines written `/`
	LC_ALL=C tr '\n\t' '/ ' < "$MANAGER_SCREEN_RIG/stdin.$1" 2> /dev/null || :
}
## the first part of every script: to the CLI services in the configuration, `c`, to the first step
rigToCli='at @configuration clipresets
turn
wait list 30
keys DOWN
turn
'

echo "-- 1. the wizards are declared by their features; Git Settings is a folder --"
rigCase folder
rigScript <<'RIGSCRIPT'
at @configuration
turn
wait list 30
rowids ids
root git
turn
wait focus 30
turn
keys ENTER
wait list 30
turn
rowids kids
get in
RIGSCRIPT
rigAssert "the folder stands in the configuration, after CLI Presets and Tiers and ahead of the subsystems; entered, its rows are the three settings" "$( rigVal ids ) / $( rigVal kids )" ".. checker keys clipresets git subsystems diagnostics / .. user.name user.email ssh-key"

echo "-- 2. the CLI service's wizard --"
rigCase cli1
rigScript <<RIGSCRIPT
$rigToCli
get row
keys c
turn
wait plan 30
turn
get s1
RIGSCRIPT
rigAssert "c on the CLI services reads the form of the wizard once, by the operation, and opens its first step: the presets there are and a new one, the first chosen" "$( rigVal row.selected ) / $( rigCalled '--manager-wizard-read cli-service' ) / $( rigVal s1.dialogTitle ) / $( rigVal s1.dialog )" "presets / 1 / Configure CLI Service: the preset / wizard:cli-service:0:preset|base"
rigCase cli2
rigScript <<RIGSCRIPT
$rigToCli
keys c
turn
wait plan 30
turn
keys DOWN DOWN SPACE TAB f r e s h
turn
get named
keys ENTER
turn
get s2
keys DOWN DOWN SPACE TAB TAB DOWN DOWN DOWN DOWN SPACE
turn
get s2set
keys ENTER
turn
get s3
show s3screen
keys $(printf '%s' "$rigSecret" | LC_ALL=C sed 's/./& /g')
turn
keys ENTER
turn 2
get applying
wait follow 30
turn
get ended
RIGSCRIPT
rigAssert "a new preset is named in the first step, and Next opens the second: the service (claude first), the model, the effort, titled by the preset" "$( rigVal named.dialog | LC_ALL=C cut -d'|' -f1 ) / $( rigVal s2.dialogTitle )" "wizard:cli-service:0:name / Configure CLI Service: fresh"
rigAssert "the service and the effort are chosen (grok, high); Next opens the credentials of that service, the key it reads" "$( rigVal s2set.dialog | LC_ALL=C cut -d'|' -f1 ) / $( rigVal s3.dialogTitle ) / $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^s3screen|' | LC_ALL=C grep -c -F XAI_API_KEY )" "wizard:cli-service:1:effort / Configure CLI Service: the credentials of grok / 1"
rigAssert "the last step is the credentials; Finish runs the operation with the preset's name as its words, in the output dialog" "$( rigVal applying.dialogTitle ) / $( rigCalled '--manager-wizard-apply cli-service --preset fresh' )" "Configure CLI Service: fresh / 1"
rigAssert "what is changed is on its standard input, a line a key: the service, the effort, the credential; the tiers are assigned elsewhere" "$( rigInput --manager-wizard-apply )" "PRESET_CLI_SERVICE grok/PRESET_EFFORT high/XAI_API_KEY $rigSecret/"
rigAssert "no value of an answer is a word of any call, and the credential is in the standard input alone" "$( LC_ALL=C grep -c -F -e "$rigSecret" -e 'fresh:high' "$MANAGER_SCREEN_RIG/calls" || : ) $( LC_ALL=C grep -c -F -- "$rigSecret" "$MANAGER_SCREEN_RIG/words" || : )" "0 0"
rigAssert "the wizard ends in the output dialog, which closes on OK; the presets are read again afterwards" "$( [ "$( rigCalled '--manager-preset-list' )" -ge 3 ] && echo again || echo once )" "again"
rigCase cli3
rigScript <<RIGSCRIPT
$rigToCli
keys c
turn
wait plan 30
turn
keys DOWN SPACE
keys ENTER
turn
get ext
keys ENTER
turn
get third
keys ESC
turn
get esc
RIGSCRIPT
rigAssert "a preset that extends another has no service to choose: its step says it extends, and offers the model and the effort alone" "$( rigVal ext.dialogTitle ) / $( rigVal ext.dialogHolds | LC_ALL=C grep -c -F 'extends base' )" "Configure CLI Service: ext / 1"
rigAssert "Esc leaves the wizard: no dialog is left, nothing is applied" "[$( rigVal esc.dialog )] $( rigApplied )" "[] 0"
rigCase cli4
rigScript <<RIGSCRIPT
$rigToCli
keys c
turn
wait plan 30
turn
keys ENTER
turn
get second
keys ENTER
turn
get third
keys ENTER
turn 2
get applying
wait follow 30
turn
RIGSCRIPT
rigAssert "an existing preset left as it is: Next goes through, the credential shown in its one form, and Finish applies nothing but what changed, which is nothing: the standard input is empty" "$( rigVal second.dialogTitle ) / $( rigVal third.dialogTitle ) / $( rigCalled '--manager-wizard-apply cli-service --preset base' ) / [$( rigInput --manager-wizard-apply )]" \
	"Configure CLI Service: base / Configure CLI Service: the credentials of claude / 1 / []"
rigAssert "the credential of the preset stands in its field in its one form, the value whole being nowhere" "$( LC_ALL=C grep -c -F -- "$rigSecret" "$MANAGER_SCREEN_RIG/calls" || : )" "0"
rigCase back
rigScript <<RIGSCRIPT
$rigToCli
keys c
turn
wait plan 30
turn
keys ENTER
turn
keys TAB TAB TAB TAB
keys ENTER
turn
get back
RIGSCRIPT
rigAssert "Back returns to the step before" "$( rigVal back.dialogTitle )" "Configure CLI Service: the preset"

echo "-- 2b. Auto-select CLI... (F13.4): the owner's check in the output dialog, and the apply offered from it --"
rigCase auto1
printf 'SPAWN_CLI_AUTO: OK\n  pick: claude-native, the first that works\n' > "$MANAGER_SCREEN_RIG/rows.--owner-setup-cli-auto --check"
printf 'RIG-AUTO-APPLIED\n' > "$MANAGER_SCREEN_RIG/rows.--owner-setup-cli-auto --apply"
rigScript <<RIGSCRIPT
$rigToCli
get row
keys s
turn
get running
wait follow 30
turn
get ended
keys TAB
get second
keys ENTER
turn 2
get applying
wait follow 30
turn
get applied
RIGSCRIPT
rigAssert "s on the CLI services runs the owner's check, and only that, in the output dialog, titled by the command, the way a command of a workspace is run" "$( rigVal row.selected ) / $( rigCalled '--owner-setup-cli-auto --check' ) / $( rigVal running.dialogTitle ) / $( rigCalled '--owner-setup-cli-auto --apply' )" "presets / 1 / Auto-select CLI / 1"
rigAssert "what the check wrote is in the dialog as it wrote it, and the result line is its status" "$( rigVal ended.dialogHolds | LC_ALL=C grep -c -F -e 'SPAWN_CLI_AUTO: OK' -e 'pick: claude-native' -e 'Ended with status 0' )" "1"
rigAssert "it ended with status 0, so the dialog offers the apply beside OK, OK first" "$( rigVal ended.dialog ) / $( rigVal second.dialog )" "output:ok| / output:then|"
rigAssert "the apply is run by the operation and no word of the screen's own, in a dialog titled by it; the apply is not run before it is chosen" "$( rigVal applying.dialogTitle ) / $( rigCalled '--owner-setup-cli-auto --apply' ) / $( rigVal applied.dialogHolds | LC_ALL=C grep -c -F -e 'RIG-AUTO-APPLIED' -e 'Ended with status 0' )" "Auto-select CLI: apply / 1 / 1"
rigCase auto2
printf 'SPAWN_CLI_AUTO: FAIL\n' > "$MANAGER_SCREEN_RIG/rows.--owner-setup-cli-auto --check"
printf 'fail' > "$MANAGER_SCREEN_RIG/mode.--owner-setup-cli-auto --check"
rigScript <<RIGSCRIPT
$rigToCli
keys s
turn
wait follow 30
turn
get ended
keys TAB
get second
keys ENTER
turn 2
get closed
RIGSCRIPT
rigAssert "a check that ends with another status offers nothing: OK alone, and the apply is never run" "$( rigVal ended.dialog ) / $( rigVal second.dialog ) / $( rigVal closed.dialogTitle ) / $( rigCalled '--owner-setup-cli-auto --apply' )" "output:ok| / output:ok| /  / 0"
rigCase auto3
rigScript <<RIGSCRIPT
$rigToCli
keys ENTER
turn
wait list 30
turn
keys DOWN
turn
get line
keys s
turn
get lineopen
RIGSCRIPT
rigAssert "s on a line inside the CLI services is the line's own: nothing is run, and no dialog opens; the item of the CLI services is where it is offered" "$( rigVal line.path ) / $( rigCalled '--owner-setup-cli-auto --check' ) / $( rigVal lineopen.dialogTitle )" "configuration/clipresets/presets / 0 / "
rigCase auto4
rigScript <<'RIGSCRIPT'
at @configuration
turn
wait list 30
keys DOWN DOWN DOWN DOWN
turn
get onGit
keys s
turn
get nope
RIGSCRIPT
rigAssert "s anywhere else in the configuration (on the Git Settings) selects nothing: no check is run, no dialog is opened" "$( rigVal onGit.selected ) / $( rigCalled '--owner-setup-cli-auto --check' ) / $( rigVal nope.dialogTitle )" "git / 0 / "

echo "-- 3. the git settings' wizard --"
rigCase git
rigScript <<'RIGSCRIPT'
root git
turn
wait focus 30
turn
keys c
turn
wait plan 30
turn
get s1
keys BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE
turn
get cleared
keys TAB
keys BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE
keys b a c k @ r i g . e x a m p l e
turn
keys ENTER
turn 2
wait follow 30
turn
RIGSCRIPT
rigAssert "c on the folder reads the form and opens its one step, titled by the wizard, the name in its field as it stands" "$( [ "$( rigCalled '--manager-wizard-read git-settings' )" -ge 1 ] && echo read ) / $( rigVal s1.dialogTitle ) / $( rigVal s1.dialog )" "read / Configure Git Settings / wizard:git-settings:0:name|Rig Person"
rigAssert "Finish applies what was changed alone: the email, on the standard input; the name, which was emptied to be retyped, is not sent" "$( rigCalled '--manager-wizard-apply git-settings' ) / [$( rigInput --manager-wizard-apply )]" "1 / [user.email back@rig.example/]"
rigCase gitnone
rigScript <<'RIGSCRIPT'
root git
turn
wait focus 30
turn
keys c
turn
wait plan 30
turn
keys ENTER
turn 2
wait follow 30
turn
RIGSCRIPT
rigAssert "a form left as it is applies nothing: the operation is called with an empty standard input" "$( rigCalled '--manager-wizard-apply git-settings' ) / [$( rigInput --manager-wizard-apply )]" "1 / []"

echo "-- 3b. Enter on an item that takes no Enter of its own runs its main action (owner, 2026-10-20): on a setting of the Git Settings it is c Configure --"
rigCase gitenter
rigScript <<'RIGSCRIPT'
at @configuration git
wait list 30
turn
keys DOWN
turn
get row
keys ENTER
turn
wait plan 30
turn
get entered
RIGSCRIPT
rigAssert "Enter on a setting of the Git Settings opens the wizard, as c does: titled by it, on its one step" "$( rigVal row.path ) / $( rigVal entered.dialogTitle ) / $( rigVal entered.dialog | LC_ALL=C cut -d: -f1-2 )" "configuration/git / Configure Git Settings / wizard:git-settings"

echo "-- 4. the server keys --"
rigCase keygen
rigScript <<'RIGSCRIPT'
root keys
turn
keys ENTER
wait list 30
turn
rowids ids
keys DOWN DOWN DOWN
turn
get on
keys n
turn
get gen
keys ENTER
turn 2
wait follow 30
turn
RIGSCRIPT
rigAssert "n on a key that is not there asks first, with its warning, and no word to type; Generate runs the generation of that key alone" "$( rigVal gen.dialogTitle ) / $( rigVal gen.dialog | LC_ALL=C cut -d'|' -f1 ) / $( rigCalled '--manager-keys-generate generated' ) $( rigApplied )" "Generate: Generated Key / wizard:server-key-generate:0:finish / 1 1"
rigCase keyreplace
rigScript <<'RIGSCRIPT'
root keys
turn
keys ENTER
wait list 30
turn
keys DOWN DOWN
turn
get on
keys R
turn
get asked
keys TAB ENTER
turn
get refused
keys r e g e n e r a t e ENTER
turn 2
wait follow 30
turn
RIGSCRIPT
rigAssert "R on a key that is there asks first, with its warning, for the word typed whole" "$( rigVal on.selected ) / $( rigVal asked.dialogTitle ) / $( rigVal asked.dialogHolds | LC_ALL=C grep -c -F 'WARNING' )" "deploy / Regenerate: Deploy Key / 1"
rigAssert "without the word nothing is run and the dialog says so; with it the operation is called for that key alone" "$( rigVal refused.dialogSays ) / $( rigCalled '--manager-keys-regenerate deploy' ) $( rigApplied )" "nothing is done: the word typed is not regenerate / 1 1"
rigCase keydelete
rigScript <<'RIGSCRIPT'
root keys
turn
keys ENTER
wait list 30
turn
keys DOWN DOWN
turn
keys d
turn
get asked
keys d e l e t e ENTER
turn 2
wait follow 30
turn
RIGSCRIPT
rigAssert "d asks for the word delete, and then removes that key alone" "$( rigVal asked.dialogTitle ) / $( rigCalled '--manager-keys-delete deploy' ) $( rigApplied )" "Delete: Deploy Key / 1 1"
rigCase keyhost
rigScript <<'RIGSCRIPT'
root keys
turn
keys ENTER
wait list 30
turn
keys DOWN DOWN DOWN DOWN DOWN
turn
get on
keys n
turn
get g
keys R
turn
get r
keys d
turn
get d
RIGSCRIPT
rigAssert "a host key of the server takes none of them: nothing opens, nothing runs" "$( rigVal on.selected ) / [$( rigVal g.dialog )][$( rigVal r.dialog )][$( rigVal d.dialog )] $( rigApplied )" "host-ed25519 / [][][] 0"
rigAssert "and the status line says it is the system's" "$( rigVal d.notice | LC_ALL=C grep -c -F "the system's" )" "1"

printf '\nTOTAL: %d passed, %d failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
