#!/usr/bin/env bash
## Behavioural check on the wizard of a CLI preset (`e` and Enter on a preset of the manager screen, sh-lib/manager/AgentsManagerScreen.py),
## run rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which notes each start, its arguments word for word and what came on its
## standard input, and prints the fixture kept for those very arguments: rows in the forms `--manager-preset-list`,
## `--manager-preset-tiers` and `--manager-wizard-read cli-service` print.
## Held, the round trip of an edit: `e` on a preset opens the wizard of its own kind on that preset, its name prefilled and
## its CLI service not asked again; a value the tooling's choices do not name -- an effort written before the list was
## narrowed, `default`, which the apply still takes -- stands in a choice of its own, as it is set, and a form that did
## not hold it would fall to "not set" and take the setting out; going Back to a step and on again keeps what was answered
## there, so the Finish of that round applies the edit and not nothing; the apply is called once, `--preset <its own name>`,
## with a line `<key> <TAB> <value>` on its standard input for what changed alone, and a value left alone is never sent; the
## list is read again after it; and opened again, the form shows the preset as the tooling now holds it, the new model and
## the effort as it still is. Offline: no operation of the real tooling is called and no setting of this machine is read.
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
rigTmp="$( rigTempDir AgentsManagerScreenWizardCheck )" || exit 1
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
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
## The preset `rig`, as the two reads give it: its row of the list (a scope's six fields, then what it extends, its service,
## its model, its effort and by whom it is used), and what the wizard reads of it. Its effort is `default`, a word written
## before the list of the efforts was narrowed, which the tooling still takes and the choices of the form do not name.
rigPresetRow(){ ## model -- the row of the list, as it stands after an edit
	rigRow preset 'agents:preset-rig' 'Agents:_preset-rig' 4 yes yes '/rig/ws_rig/.local/.agents/preset-rig.agent.env' - claude-native "$1" default 'preset-rig'
}
rigPresetRow old-model > "$rigF/rows.--manager-preset-list"
## What the form of the wizard cannot know: the choices of a service, of an effort and of a cache lifetime, the credentials
## each service reads, and what the preset and the team hold now.
rigWizardRead(){ ## model -- the rows of `--manager-wizard-read cli-service`
	rigRow option cli-service claude-native claude-native
	rigRow option cli-service grok-native grok-native
	rigRow option effort unset unset
	rigRow option effort low low
	rigRow option effort normal normal
	rigRow option effort high high
	rigRow option cache 5m 5m
	rigRow option cache 1h 1h
	rigRow credential claude-native ANTHROPIC_API_KEY
	rigRow option preset rig rig
	rigRow preset rig PRESET_CLI_SERVICE set claude-native
	rigRow preset rig PRESET_MODEL_OR_MACRO set "$1"
	rigRow preset rig PRESET_EFFORT set default
	rigRow team SPAWN_TIER_NORMAL set rig
}
rigWizardRead old-model > "$rigF/rows.--manager-wizard-read cli-service"
## The same two reads once the tooling holds the edit: the model new-model, the effort still default.
rigPresetRow new-model > "$rigTmp/preset-after.rows"
rigWizardRead new-model > "$rigTmp/wizard-after.rows"
rigRow counters 0 0 0 0 1 0.42 > "$rigF/rows.--manager-preset-tiers"
export MANAGER_SCREEN_RIG="$rigTmp/edit"
mkdir -p "$MANAGER_SCREEN_RIG"
cp "$rigF"/* "$MANAGER_SCREEN_RIG/"
: > "$MANAGER_SCREEN_RIG/calls"
: > "$MANAGER_SCREEN_RIG/words"
echo rows > "$MANAGER_SCREEN_RIG/mode"
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize 120 40\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigApplied(){ ## how many lines of the standard input of the apply hold that text
	LC_ALL=C grep -c -F -- "$1" "$MANAGER_SCREEN_RIG/stdin.--manager-wizard-apply" 2> /dev/null || :
}
rigInput(){ ## the standard input of the apply, a line each, its tabs and its ends marked as the tool of this check marks them
	LC_ALL=C sed -n l "$MANAGER_SCREEN_RIG/stdin.--manager-wizard-apply" 2> /dev/null || :
}
rigOthers(){ ## how many starts were neither a read of the folder, the list of the locations or of the sessions, the count of the asks, nor the form of the wizard and its apply
	LC_ALL=C grep -c -v -e '^--manager-preset-list' -e '^--manager-preset-tiers' -e '^--manager-wizard-read cli-service' -e '^--manager-wizard-apply ' -e '^--manager-place-list' -e '^--manager-session-list' -e '^--read-pending-reply ' "$MANAGER_SCREEN_RIG/calls" || :
}

echo "-- e on a preset opens its wizard on that preset: the name prefilled, its service not asked, its own values in the form --"
rigScript <<RIGSCRIPT
at @clipresets presets
turn
wait list 30
turn
keys DOWN
turn
get p
keys e
turn
wait plan 30
turn
get s0
keys TAB TAB
turn
get m0
keys BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE BACKSPACE
keys n e w - m o d e l
turn
get typed
keys TAB
turn
get e0
keys ENTER
turn
get s1
keys TAB TAB
turn
get onback
keys ENTER
turn
keys TAB TAB
turn
get s0b
keys ENTER
turn
get s1b
keys ENTER
turn
wait follow 30
turn 3
get done
copy $rigTmp/preset-after.rows $MANAGER_SCREEN_RIG/rows.--manager-preset-list
copy $rigTmp/wizard-after.rows $MANAGER_SCREEN_RIG/rows.--manager-wizard-read cli-service
keys ENTER
turn
get reread
keys e
turn
wait plan 30
turn
get s0c
keys TAB TAB
turn
get m1
keys TAB
turn
get e1
RIGSCRIPT
rigAssert "the preset of the list is selected"                       "$( rigVal p.selected ) [$( rigVal p.selectedLabel )]" "agents:preset-rig [rig]"
rigAssert "e opens the form of the preset, its own name in the name field, and says which service it has, which an edit does not change" \
	"[$( rigVal s0.dialog )] [$( rigVal s0.dialogTitle )] $( printf '%s\n' "$( rigVal s0.dialogHolds )" | LC_ALL=C grep -c -F -- 'Its CLI service is claude-native' )" \
	"[wizard:cli-service:0:name|rig] [Configure CLI Service: rig] 1"
rigAssert "the form stands on its model as the tooling holds it"       "[$( rigVal m0.dialog )]" "[wizard:cli-service:0:model|old-model]"
rigAssert "the model is typed in its field"                          "[$( rigVal typed.dialog )]" "[wizard:cli-service:0:model|new-model]"
rigAssert "and its effort stands as it is set, though the choices of the tooling do not name that word" "[$( rigVal e0.dialog )]" "[wizard:cli-service:0:effort|default]"
rigAssert "Next opens the credentials of the service, and Back is a button of its own" "[$( rigVal s1.dialog )] [$( rigVal onback.dialog )]" "[wizard:cli-service:1:ANTHROPIC_API_KEY|] [wizard:cli-service:1:back|]"
rigAssert "Back opens the first step again, on what was answered there and not on what the tooling still holds" \
	"[$( rigVal s0b.dialog )] [$( rigVal s1b.dialog )] [$( rigVal done.dialog )]" "[wizard:cli-service:0:model|new-model] [wizard:cli-service:1:ANTHROPIC_API_KEY|] [output:ok|]"
rigAssert "Finish applies it once, by the preset's own name"          "$( rigCalled '--manager-wizard-apply cli-service --preset rig' ) $( LC_ALL=C grep -c -e '--manager-wizard-apply' "$MANAGER_SCREEN_RIG/calls" )" "1 1"
rigOneLine="$( printf 'PRESET_MODEL_OR_MACRO\tnew-model' | LC_ALL=C sed -n l )"
rigAssert "the standard input of the apply is the one line of the value that changed" "[$( rigInput )]" "[$rigOneLine]"
rigAssert "the effort the person left alone is not sent, which would take it out of the preset" "$( rigApplied PRESET_EFFORT ) $( rigInput | LC_ALL=C grep -c -F -e 'PRESET_MODEL_OR_MACRO' )" "0 1"
rigAssert "nothing but the reads of the folder and the apply itself was called" "$( rigOthers )" "0"

echo "-- opened again, the form shows the preset as the tooling now holds it --"
rigAssert "the list was read again after the apply"                   "$( rigCalled --manager-preset-list )" "2"
rigAssert "the preset is still the one selected, and its form opens on it again" "$( rigVal reread.selected ) [$( rigVal s0c.dialog )]" "agents:preset-rig [wizard:cli-service:0:name|rig]"
rigAssert "it shows the model as it now is"                           "[$( rigVal m1.dialog )]" "[wizard:cli-service:0:model|new-model]"
rigAssert "and its effort, as it still is and as it was never changed" "[$( rigVal e1.dialog )]" "[wizard:cli-service:0:effort|default]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN WIZARD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_WIZARD: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
