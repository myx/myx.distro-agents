#!/usr/bin/env bash
## Behavioural check on the optional features in the manager screen (LocalManagerScreen.Features.py of `.local`), run rather than read. The screen's own code runs through the
## stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.stub.sh)
## that notes each start and prints the fixture: the rows `--manager-feature-list` and `--manager-feature-part` print.
## Held:
##   1. `Optional Features` stands in `Installed Subsystems`, and entered lists each feature with its parts, their state and size, and under each the commands the tooling gave it (Install, Update,
##      Uninstall), in the order of the operation: the screen keeps no table of the parts of a feature
##   2. Enter on a command asks the plan first (`--manager-feature-part <action> <feature> <part>`, no `--yes`), shows it in the dialog, and runs nothing until Run is pressed; Cancel runs nothing;
##      Run runs the same operation with `--yes` and no other word; a plan the operation says is blocked is shown as blocked and Run does nothing
##   3. `Local AI` stands in `This Machine`, lists the parts of the local AI with their size and state, and under an installed part what it is used for: a prompt and a `local` preset for a chat model, a voice
##      test for a speech part; the prompt goes on the standard input of `--manager-feature-ask <model>`, the voice test is `--manager-feature-stt-test [<file>]`, the preset is `--manager-feature-preset <model> [--name <preset>]`
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
rigTmp="$( rigTempDir AgentsManagerScreenFeaturesCheck )" || exit 1
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
rigAi=setup.feature-local-ai
rigLance=setup.feature-lancedb
rigCmd="DistroAgentsTools.fn.sh --manager-feature-part"
rigF="$rigTmp/fixture" ; mkdir -p "$rigF"
{
	rigRow feature "$rigLance" - not-installed - - - "$rigCmd install $rigLance lancedb" - - platform=macOS_arm64
	rigRow feature "$rigAi" - installed 2687365743 2790000000 yes - - - host.os=Darwin
	rigRow part "$rigAi" stt-whisper-small-q5_1 installed 190085487 190085487 yes - "$rigCmd update $rigAi stt-whisper-small-q5_1" "$rigCmd uninstall $rigAi stt-whisper-small-q5_1" part=stt
	rigRow part "$rigAi" qwen3-4b-q4_k_m installed 2497280256 2913493632 yes - "$rigCmd update $rigAi qwen3-4b-q4_k_m" "$rigCmd uninstall $rigAi qwen3-4b-q4_k_m" part=chat
	rigRow part "$rigAi" qwen3-8b-q4_k_m not-installed 0 5865747402 no "$rigCmd install $rigAi qwen3-8b-q4_k_m" - - part=chat
} > "$rigF/rows.--manager-feature-list"
{
	rigRow plan install "$rigAi" qwen3-8b-q4_k_m 5027783488 - 234767114240 5865747402 17179869184 no -
	rigRow need package_llama.cpp
	rigRow need model_qwen3-8b-q4_k_m_5027783488
} > "$rigF/rows.--manager-feature-part install $rigAi qwen3-8b-q4_k_m"
rigRow plan install "$rigLance" lancedb - - 1000 - 17179869184 yes "less_than_1_GB_free" > "$rigF/rows.--manager-feature-part install $rigLance lancedb"
## the agreed set: the plan for the host's profile, a plan that is blocked (the operation prints its rows, one error line and ends 1), and the work with --yes
{
	rigRow set shared-cpu 3 profile
	rigRow model "$rigAi" stt-whisper-large-v3-turbo-q5_0 stt not-installed 574041195 yes
	rigRow model "$rigAi" qwen3.5-4b-q8_0 chat not-installed 4482403488 yes
	rigRow model "$rigLance" lancedb embedding not-installed - yes
	rigRow total 5056444683 166094671872 no
} > "$rigF/rows.--manager-feature-models"
{
	rigRow set gpu 3 profile
	rigRow model "$rigAi" qwen3.8-27b-q8_0 chat not-installed 29100000000 yes
	rigRow total 29100000000 1000 yes
} > "$rigF/rows.--manager-feature-models --profile gpu"
echo fail-rows > "$rigF/mode.--manager-feature-models --profile gpu"
{
	rigRow result "$rigAi" qwen3.5-4b-q8_0 installed
	rigRow end 1 0 2
} > "$rigF/rows.--manager-feature-models --yes"
printf '%s\n' "Hello from the model" > "$rigF/rows.--manager-feature-ask qwen3-4b-q4_k_m"
printf '%s\n' "hello world" > "$rigF/rows.--manager-feature-stt-test"
rigRow created agents:preset-local qwen3-4b-q4_k_m > "$rigF/rows.--manager-feature-preset qwen3-4b-q4_k_m"
rigRow created agents:preset-mine qwen3-4b-q4_k_m > "$rigF/rows.--manager-feature-preset qwen3-4b-q4_k_m --name mine"
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
rigHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigBoxHas(){ ## tag, text -- how many lines of that drawing of a dialog hold the text
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigCalled(){ ## the arguments of a start -- how many times the stand-in was started with exactly those
	LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || :
}
rigType(){ ## text -- the keys that type it, one a character
	local typeText="$1" typeKeys="" typeChar
	while [ -n "$typeText" ] ; do
		typeChar="${typeText%"${typeText#?}"}" ; typeText="${typeText#?}"
		[ "$typeChar" != " " ] || typeChar=SPACE
		typeKeys="$typeKeys $typeChar"
	done
	printf '%s' "$typeKeys"
}

echo "-- 1. Optional Features stands in Installed Subsystems, and lists the features, their parts and their commands --"
rigCase list
rigScript <<'RIGSCRIPT'
at @subsystems
turn
rowids folder
at @subsystems features
turn
wait list 30
turn
get in
rowids ids
show s
RIGSCRIPT
rigAssert "Installed Subsystems holds the row of Optional Features" "$( rigVal folder | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x features )" "1"
rigAssert "the list is asked once of the operation of the features, and of nothing else of theirs" "$( rigCalled --manager-feature-list ) $( LC_ALL=C grep -c -F -e 'feature-part' -e 'feature-ask' "$MANAGER_SCREEN_RIG/calls" || : )" "1 0"
rigAssert "each feature, its parts and the commands the tooling gave: in the order of the operation" "$( rigVal ids )" ".. $rigLance $rigLance:install $rigAi $rigAi/stt-whisper-small-q5_1 $rigAi/stt-whisper-small-q5_1:update $rigAi/stt-whisper-small-q5_1:uninstall $rigAi/qwen3-4b-q4_k_m $rigAi/qwen3-4b-q4_k_m:update $rigAi/qwen3-4b-q4_k_m:uninstall $rigAi/qwen3-8b-q4_k_m $rigAi/qwen3-8b-q4_k_m:install"
rigAssert "the folder as a table: the state, the size on disk and the memory of the parts, as the operation gave them" "$( rigHolds s 'qwen3-4b-q4_k_m         installed      2.3G    2.7G    yes' ) $( rigHolds s 'setup.feature-lancedb   not installed  -       -       -' ) $( rigHolds s 'qwen3-8b-q4_k_m         not installed  0B      5.5G    no' )" "1 1 1"

echo "-- 2. a command asks the plan first, and runs nothing until Run --"
rigCase plan
rigScript <<'RIGSCRIPT'
at @subsystems features
turn
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN
turn
get on
keys ENTER
wait plan 30
turn
get asked
box d
keys ESC
turn
get esc
RIGSCRIPT
rigAssert "the selection is on the Install of the model that is not installed" "$( rigVal on.selected )" "$rigAi/qwen3-8b-q4_k_m:install"
rigAssert "Enter reads the plan of the operation, without --yes, and shows it: what is fetched, the space, the memory, the needs" "$( rigCalled "--manager-feature-part install $rigAi qwen3-8b-q4_k_m" ) $( rigVal asked.dialogTitle ) $( rigHolds d 'download' ) $( rigHolds d 'package llama.cpp' )" "1 Install qwen3-8b-q4_k_m 1 1"
rigAssert "Esc closes it and nothing was run: the operation was never called with --yes" "[$( rigVal esc.dialog )] $( LC_ALL=C grep -c -F -e '--yes' "$MANAGER_SCREEN_RIG/calls" || : )" "[] 0"
rigCase run
rigScript <<'RIGSCRIPT'
at @subsystems features
turn
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN
turn
keys ENTER
wait plan 30
turn
keys ENTER
turn 2
get ran
wait follow 30
turn
RIGSCRIPT
rigAssert "Run runs the same operation with --yes and no other word, in the output dialog titled by the command" "$( rigVal ran.dialogTitle ) $( rigCalled "--manager-feature-part install $rigAi qwen3-8b-q4_k_m --yes" )" "Install qwen3-8b-q4_k_m 1"
rigCase blocked
rigScript <<'RIGSCRIPT'
at @subsystems features
turn
wait list 30
keys DOWN DOWN
turn
get on
keys ENTER
wait plan 30
turn
keys ENTER
turn
get pressed
box b
RIGSCRIPT
rigAssert "the Install of LanceDB has a plan the operation says is blocked: it says so and Run does nothing" "$( rigVal on.selected ) $( rigHolds b 'less than 1 GB free' ) [$( rigVal pressed.dialogSays )] $( LC_ALL=C grep -c -F -e '--yes' "$MANAGER_SCREEN_RIG/calls" || : )" "$rigLance:install 2 [the plan is blocked: less than 1 GB free] 0"

echo "-- 3. Local AI in This Machine: the parts, and their uses --"
rigCase ai
rigScript <<'RIGSCRIPT'
at @machine
turn
rowids folder
at @machine local-ai
turn
wait list 30
turn
get in
rowids ids
RIGSCRIPT
rigAssert "This Machine holds the row of Local AI" "$( rigVal folder | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x local-ai )" "1"
rigAssert "the parts of the local AI alone, each with its commands, and under an installed part its uses" "$( rigVal ids )" ".. $rigAi $rigAi/stt-whisper-small-q5_1 $rigAi/stt-whisper-small-q5_1:update $rigAi/stt-whisper-small-q5_1:uninstall $rigAi/stt-whisper-small-q5_1:voice $rigAi/qwen3-4b-q4_k_m $rigAi/qwen3-4b-q4_k_m:update $rigAi/qwen3-4b-q4_k_m:uninstall $rigAi/qwen3-4b-q4_k_m:ask $rigAi/qwen3-4b-q4_k_m:preset $rigAi/qwen3-8b-q4_k_m $rigAi/qwen3-8b-q4_k_m:install"
rigCase ask
rigScript <<RIGSCRIPT
at @machine local-ai
turn
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN
turn
get on
keys ENTER$( rigType 'say hello' ) TAB ENTER
get asked
wait action 30
turn
get answered
show answered
RIGSCRIPT
rigAssert "Enter on Ask opens its form, and Ask calls the operation of that model, once; the prompt is on its standard input and is no word of it" "$( rigVal on.selected ) [$( LC_ALL=C grep -F -- '[--manager-feature-ask]' "$MANAGER_SCREEN_RIG/words" )] $( printf '%s\n' 'say hello' | cmp -s - "$MANAGER_SCREEN_RIG/stdin.--manager-feature-ask" && echo same )" "$rigAi/qwen3-4b-q4_k_m:ask [[--manager-feature-ask][qwen3-4b-q4_k_m]] same"
rigAssert "what the model answered is shown" "$( rigHolds answered 'Hello from the model' )" "1"
rigCase preset
rigScript <<RIGSCRIPT
at @machine local-ai
turn
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN
turn
get on
keys ENTER
get opened
keys ENTER
wait action 30
turn
get made
show made
RIGSCRIPT
rigAssert "Make a local preset: the operation is called with the model alone, and the row it printed is shown" "$( rigVal on.selected ) [$( LC_ALL=C grep -F -- '[--manager-feature-preset]' "$MANAGER_SCREEN_RIG/words" )] $( rigHolds made 'agents:preset-local' )" "$rigAi/qwen3-4b-q4_k_m:preset [[--manager-feature-preset][qwen3-4b-q4_k_m]] 1"
rigCase presetNamed
rigScript <<RIGSCRIPT
at @machine local-ai
turn
wait list 30
keys DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN
turn
keys ENTER$( rigType 'mine' ) ENTER
wait action 30
RIGSCRIPT
rigAssert "a name typed goes as --name" "[$( LC_ALL=C grep -F -- '[--manager-feature-preset]' "$MANAGER_SCREEN_RIG/words" )]" "[[--manager-feature-preset][qwen3-4b-q4_k_m][--name][mine]]"
echo "-- a new preset of the local service has its own form: its model is chosen from the installed chat models (sketch 13.4) --"
rigCase localform
rigScript <<'RIGSCRIPT'
at @clipresets presets
turn
wait list 10
keys n
turn
get forms
box fm
keys DOWN DOWN DOWN SPACE ENTER
wait plan 30
turn
get lf
box lf
keys DOWN ENTER
wait action 30
turn
get made
RIGSCRIPT
rigAssert "the forms to choose from name the local one" "$( rigBoxHas fm 'a local preset' )" "1"
rigAssert "the local form lists the chat models that are installed, and no model that is not, no speech model, and no other service" "[$( rigVal lf.dialog )] $( rigBoxHas lf 'qwen3-4b-q4_k_m' ) $( rigBoxHas lf 'qwen3-8b-q4_k_m' ) $( rigBoxHas lf 'stt-whisper' ) $( rigBoxHas lf 'choose one' )" "[preset-local:model|] 1 0 0 1"
rigAssert "with the model chosen, Make asks the operation of the local preset with that model alone, and the form is closed" "[$( rigVal made.dialog )] [$( LC_ALL=C grep -F -- '[--manager-feature-preset]' "$MANAGER_SCREEN_RIG/words" )]" "[] [[--manager-feature-preset][qwen3-4b-q4_k_m]]"

rigCase voice
rigScript <<'RIGSCRIPT'
at @machine local-ai
turn
wait list 30
keys DOWN DOWN DOWN DOWN DOWN
turn
get on
keys ENTER
get opened
keys ENTER
wait action 30
turn
get heard
show heard
RIGSCRIPT
rigAssert "Voice test with no file: the operation is called with no word after it, and the text it gave is shown" "$( rigVal on.selected ) [$( LC_ALL=C grep -F -- '[--manager-feature-stt-test]' "$MANAGER_SCREEN_RIG/words" )] $( rigHolds heard 'hello world' )" "$rigAi/stt-whisper-small-q5_1:voice [[--manager-feature-stt-test]] 1"

echo "-- the agreed set: the plan first, the run only when it is shown, fits and is confirmed --"
rigCase set
rigScript <<'RIGSCRIPT'
at @subsystems features
turn
wait list 30
keys i
wait plan 30
turn
get opened
box p
keys ESC
turn
get esc
RIGSCRIPT
rigAssert "i asks the operation for the plan of the host's profile, without --yes, and shows each part with its state and size, the total against the free space" "$( rigCalled '--manager-feature-models' ) $( rigVal opened.dialogTitle ) $( rigBoxHas p 'qwen3.5-4b-q8_0, not installed, 4.2G (default)' ) $( rigBoxHas p 'to fetch' ) $( rigBoxHas p 'blocked' )" "1 Install the agreed set 1 1 1"
rigAssert "Esc closes it and nothing was installed" "[$( rigVal esc.dialog )] $( LC_ALL=C grep -c -F -e '--yes' "$MANAGER_SCREEN_RIG/calls" || : )" "[] 0"
rigCase setrun
rigScript <<'RIGSCRIPT'
at @subsystems features
turn
wait list 30
keys i
wait plan 30
turn
keys ENTER
turn 2
get ran
wait follow 30
turn
get ended
box e
RIGSCRIPT
rigAssert "Install runs the same operation with --yes, once, in the output dialog, which shows the rows the operation printed" "$( rigCalled '--manager-feature-models --yes' ) $( rigVal ran.dialogTitle ) $( rigBoxHas e 'result' ) $( rigBoxHas e 'end' )" "1 Install the agreed set 1 1"
rigCase setblocked
rigScript <<'RIGSCRIPT'
at @subsystems features
turn
wait list 30
keys i
wait plan 30
turn
keys DOWN DOWN DOWN SPACE TAB TAB TAB ENTER
wait plan 30
turn
get shown
box b
keys BACKTAB ENTER
turn
get pressed
RIGSCRIPT
rigAssert "another profile asks for its own plan; one that does not fit is shown as blocked" "$( rigCalled '--manager-feature-models --profile gpu' ) $( rigBoxHas b 'blocked' ) $( rigBoxHas b 'it does not fit' )" "1 1 1"
rigAssert "Install on a blocked plan does nothing: the dialog says so and the operation is never called with --yes" "[$( rigVal pressed.dialogSays )] $( LC_ALL=C grep -c -F -e '--yes' "$MANAGER_SCREEN_RIG/calls" || : )" "[the plan is blocked: nothing can be installed] 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN FEATURES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "MANAGER_SCREEN_FEATURES: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"
