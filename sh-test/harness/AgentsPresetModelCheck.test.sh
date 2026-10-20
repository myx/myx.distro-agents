#!/usr/bin/env bash
## Behavioural check on how the model name of a preset reaches a harness leg (F10.2 of the refactorings epic): the leg stubs
## take HARNESS_MODEL_LIGHT and HARNESS_MODEL_MAIN from their environment ahead of their own (the default form), and the
## console gives a leg the model its spawn's preset names for its tier, dropping what a parent session left in the environment.
## It is never a new --tier value: the harness gate takes light, normal and heavy as it did. A vendor CLI is passed no model.
## Held:
##   1. each of the four leg stubs: its own models where nothing is exported, an exported one ahead of it, an exported empty
##      one (what a spawn hands on) is none
##   2. the console's DagcHarnessModelExport, run as the console runs it: a parent's exported models are dropped; the model the
##      spawn's preset names for the main tier is exported; a macro names none; with no tier setting none is exported
##   3. the console calls it for a harness leg only, after the credentials; and it passes a vendor CLI no model option
## Red before F10.2: all fail. Offline: the rig workspace alone.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTemplate="$rigPackage/sh-lib/manager/AgentsConsoleShellScript.template.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTemplate" ] || rigRefuse "the console template is not at the origin this workspace resolves: $rigTemplate"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPresetModelCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigAgents="$rigWs/.local/.agents"
mkdir -p "$rigAgents" "$rigTmp/home" "$rigTmp/skills"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

echo "-- 1. the leg stubs: the default form --"
rigModels(){ ## leg, then env assignments -- `<light>|<main>` as the lines of the stub give them
	local legName="$1" ; shift
	env -i PATH="/usr/bin:/bin" "$@" bash -c 'eval "$( LC_ALL=C grep -e "^HARNESS_MODEL_LIGHT=" -e "^HARNESS_MODEL_MAIN=" "$1" )" ; printf "%s|%s" "$HARNESS_MODEL_LIGHT" "$HARNESS_MODEL_MAIN"' rig "$rigPackage/sh-lib/harness/Agents${legName}Harness.sh"
}
rigDefaults="Claude=claude-haiku-4-5|claude-opus-5 Scaleway=gemma-4-26b-a4b-it|deepseek-v4-flash-0731 Grok=grok-4.3|grok-4.7 Copilot=gpt-5.6-sol|claude-fable-5"
for rigPair in $rigDefaults ; do
	rigLeg="${rigPair%%=*}" ; rigWant="${rigPair#*=}"
	rigAssert "$rigLeg: its own models where nothing is exported"            "$( rigModels "$rigLeg" X=1 )" "$rigWant"
	rigAssert "$rigLeg: an exported main model stands ahead of its own"      "$( rigModels "$rigLeg" HARNESS_MODEL_MAIN=rig-model-main )" "${rigWant%%|*}|rig-model-main"
	rigAssert "$rigLeg: an exported light model too"                         "$( rigModels "$rigLeg" HARNESS_MODEL_LIGHT=rig-model-light )" "rig-model-light|${rigWant#*|}"
	rigAssert "$rigLeg: an exported empty one is none, as a spawn hands on"  "$( rigModels "$rigLeg" HARNESS_MODEL_LIGHT= HARNESS_MODEL_MAIN= )" "$rigWant"
done

echo "-- 2. the console's model export, as the console runs it --"
rigFunction="$( LC_ALL=C awk '/^DagcHarnessModelExport\(\)\{/ { on = 1 } on { print } on && /^}/ { exit }' "$rigTemplate" )"
rigAssert "the console defines it"                                          "$( printf '%s' "$rigFunction" | LC_ALL=C grep -c -e '^DagcHarnessModelExport(){' )" 1
rigExport(){ ## env assignments for the call -- `light=<value|unset> main=<value|unset>` after the function ran
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigTmp/skills" "$@" \
		bash -c "$rigFunction"'
			DagcHarnessModelExport
			printf "light=%s main=%s" "${HARNESS_MODEL_LIGHT-unset}" "${HARNESS_MODEL_MAIN-unset}"
		' 2> /dev/null )
}
printf 'SPAWN_CLI_SERVICE=claude-native\n' > "$rigAgents/magic-team.agent.env"
printf 'PRESET_CLI_SERVICE=claude\nPRESET_MODEL_OR_MACRO=claude-sonnet-5-5\n' > "$rigAgents/preset-rig-sonnet.agent.env"
printf 'PRESET_CLI_SERVICE=claude\nPRESET_MODEL_OR_MACRO=low\n' > "$rigAgents/preset-rig-haiku.agent.env"
chmod 770 "$rigAgents" ; chmod 660 "$rigAgents"/*.agent.env
rigAssert "no tier setting: none is exported, and a parent's are dropped"    "$( rigExport HARNESS_MODEL_LIGHT=leak-light HARNESS_MODEL_MAIN=leak-main )" "light=unset main=unset"
printf 'SPAWN_TIER_NORMAL=rig-sonnet\n' >> "$rigAgents/magic-team.agent.env"
rigAssert "a preset that names a model: the main tier's is exported, the light one is none" "$( rigExport HARNESS_MODEL_LIGHT=leak-light HARNESS_MODEL_MAIN=leak-main )" "light=unset main=claude-sonnet-5-5"
rigAssert "the spawn's own preset (MDAT_SPAWN_PRESET) is the one: a macro names no model"  "$( rigExport MDAT_SPAWN_PRESET=rig-haiku HARNESS_MODEL_MAIN=leak-main )" "light=unset main=unset"
rigAssert "a spawn of a caller-named service is no preset's: the team's scope is read as ever" "$( rigExport MDAT_SPAWN_PRESET=-claude HARNESS_MODEL_MAIN=leak-main )" "light=unset main=unset"
printf 'SPAWN_HARNESS_TIER=light\n' >> "$rigAgents/magic-team.agent.env"
printf 'SPAWN_TIER_LOW=rig-sonnet\n' >> "$rigAgents/magic-team.agent.env"
rigAssert "the light tier's model is the light model's name"                  "$( rigExport )" "light=claude-sonnet-5-5 main=unset"

echo "-- 3. where the console calls it --"
rigAssert "the call is for a harness leg, in the console, once"               "$( LC_ALL=C awk '/^if DagcCliIsLeg "\$DAGC_CLI" ; then$/ { gate = NR } /^\tDagcHarnessModelExport$/ { if ( gate == NR - 1 ) found ++ ; else stray ++ } END { print found + 0, stray + 0 }' "$rigTemplate" )" "1 0"
rigAssert "after the credentials are exported"                                "$( LC_ALL=C awk '/^for DAGC_CREDENTIAL_NAME in \$DAGC_CLI_CREDENTIALS ; do$/ { credentials = NR } /^\tDagcHarnessModelExport$/ { call = NR } END { print ( credentials > 0 && call > credentials ) ? "after" : "not after" }' "$rigTemplate" )" after
rigAssert "a vendor CLI is passed no model option"                            "$( LC_ALL=C grep -c -e '--model' "$rigTemplate" )" 0
rigAssert "the harness gate takes light, normal, heavy as it did"             "$( LC_ALL=C grep -c -F -e 'light|normal|heavy) harnessTier="$2" ;;' "$rigPackage/sh-lib/harness/AgentsUniversalHarness.sh" )" 1

echo "-- 4. the console's export of the lifetime the preset asks of the input cache (F10.7) --"
rigFunction="$( LC_ALL=C awk '/^DagcHarnessCacheTimeExport\(\)\{/ { on = 1 } on { print } on && /^}/ { exit }' "$rigTemplate" )"
rigAssert "the console defines it"                                          "$( printf '%s' "$rigFunction" | LC_ALL=C grep -c -e '^DagcHarnessCacheTimeExport(){' )" 1
rigTimeExport(){ ## env assignments for the call -- `time=<value|unset>` after the function ran
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigTmp/skills" "$@" \
		bash -c "$rigFunction"'
			DagcHarnessCacheTimeExport
			printf "time=%s" "${HARNESS_INPUT_CACHE_TIME-unset}"
		' 2> /dev/null )
}
printf 'SPAWN_CLI_SERVICE=claude-native\n' > "$rigAgents/magic-team.agent.env"
printf 'PRESET_CLI_SERVICE=claude\nPRESET_INPUT_CACHE_TIME=1h\n' > "$rigAgents/preset-rig-hour.agent.env"
printf 'PRESET_EXTEND=rig-hour\n' > "$rigAgents/preset-rig-hour-ext.agent.env"
printf 'PRESET_CLI_SERVICE=claude\nPRESET_INPUT_CACHE_TIME=5m\n' > "$rigAgents/preset-rig-five.agent.env"
chmod 770 "$rigAgents" ; chmod 660 "$rigAgents"/*.agent.env
rigAssert "no tier setting: none is exported, and a parent's is dropped"      "$( rigTimeExport HARNESS_INPUT_CACHE_TIME=1h )" "time=unset"
rigAssert "the spawn's own preset asks the hour: 1h is exported"              "$( rigTimeExport MDAT_SPAWN_PRESET=rig-hour )" "time=1h"
rigAssert "one that extends it asks it too"                                   "$( rigTimeExport MDAT_SPAWN_PRESET=rig-hour-ext )" "time=1h"
rigAssert "one that asks 5m exports it as it is set (the leg's wire says nothing for it)" "$( rigTimeExport MDAT_SPAWN_PRESET=rig-five )" "time=5m"
rigAssert "a preset that asks nothing: none, a parent's dropped"               "$( rigTimeExport MDAT_SPAWN_PRESET=rig-haiku HARNESS_INPUT_CACHE_TIME=1h )" "time=unset"
rigAssert "a caller-named service is no preset's: none"                        "$( rigTimeExport MDAT_SPAWN_PRESET=-claude HARNESS_INPUT_CACHE_TIME=1h )" "time=unset"
printf 'SPAWN_TIER_NORMAL=rig-hour\n' >> "$rigAgents/magic-team.agent.env"
rigAssert "the team's tier setting is the preset where the spawn names none"   "$( rigTimeExport )" "time=1h"
rigAssert "the call is for a harness leg, in the console, once, beside the models" "$( LC_ALL=C awk '/^if DagcCliIsLeg "\$DAGC_CLI" ; then$/ { gate = NR } /^\tDagcHarnessCacheTimeExport$/ { if ( gate > 0 && gate == NR - 2 ) found ++ ; else stray ++ } END { print found + 0 " " stray + 0 }' "$rigTemplate" )" "1 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PRESET MODEL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PRESET_MODEL: OK (%d assertions, offline)\n' "$rigPassCount"
