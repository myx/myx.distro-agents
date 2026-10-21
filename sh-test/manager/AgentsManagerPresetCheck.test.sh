#!/usr/bin/env bash
## Behavioural check on the presets and the tiers of the console (F10.1, F10.2, F11.7: "not configurable means not working"), run rather than read, against a rig workspace: --manager-preset-list,
## --manager-preset-new, --manager-preset-tiers, and the variables of a preset and of a tier as --manager-scope-read gives them and --manager-scope-set and --manager-scope-delete change them.
## Held:
##   1. the list: each preset with what it extends, what it comes to with what it inherits (CLI service, model, effort) and by whom it is used
##   2. the variables of a preset by their kinds: the CLI service a choice from the nine, locked where the preset extends, with why; the effort, the lifetime of the input cache choices; the largest context
##      a number in a range; the model and the extra spawn line texts; the credentials of the service; every parameter the file does not hold offered as missing; extend a choice of the other presets
##   3. the tiers of the team and of a member that holds no file of settings: three choices each, from the presets alone and each with an effort; the tiers listed for the team and each member
##   4. the writes: through the setting reader of the dispatcher, so a value that is none of the list is refused and nothing changes; an extending preset takes no CLI service
##   5. a preset made: extending one, or with a CLI service of its own; a name taken, a name with a capital, a parent that is not there and a service that is none are refused and leave no file
##   6. a preset in use is not deleted: not one a preset extends, not one a tier names; one nothing uses is
##   7. END TO END: a tier chosen from the console's operations is the preset a spawn gets: the spawner's own choice (AgentsToolsPresetChosen) answers the member's own tier ahead of the team's, by the
##      tier asked, and what that preset comes to (AgentsToolsPresetEffective) is what it inherits
## Offline; only the rig's own tree is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerPresetCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigAgents="$rigWs/.local/.agents"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
mkdir -p "$rigAgents" "$rigTmp/home" "$rigSkills/keeper-myx" "$rigSkills/magic-coordinator"
printf 'rig\n' > "$rigSkills/keeper-myx/keeper-myx.basic.md" ; printf 'rig\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md" ; printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf 'PRESET_CLI_SERVICE=claude\n' > "$rigAgents/preset-rig-base.agent.env"
printf 'PRESET_EXTEND=rig-base\nPRESET_MODEL_OR_MACRO=low\n' > "$rigAgents/preset-rig-ext.agent.env"
printf 'PRESET_EXTEND=rig-base\nPRESET_MODEL_OR_MACRO=high\nPRESET_EFFORT=high\n' > "$rigAgents/preset-rig-opus.agent.env"
printf 'SPAWN_TIER_LOW=rig-ext\nSPAWN_TIER_NORMAL=rig-ext\nSPAWN_HARNESS_TIER=light\n' > "$rigAgents/magic-team.agent.env"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigRc=0
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err, the value of a write in $rigInput
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "${rigInput:-}" || rigRc=$?
}
rigKeyRow(){ ## key -- the fields of that key's row in the last output after its name: state, kind, takes (cut)
	LC_ALL=C awk -F'\t' -v key="$1" '$1 == "key" && $2 == key { printf "%s|%s|%s", $3, $7, substr( $8, 1, 40 ) }' "$rigTmp/out"
}
rigChosen(){ ## member, the tier asked -- the spawner's own choice of the preset, from the rig workspace
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDSC_CMD=rig \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Preset.include" ; AgentsToolsPresetPayRoot() { printf "%s\n" "$MMDAPP" ; } ; AgentsToolsPresetChosen "$1"' rig "$1" 2> /dev/null )
}
rigEffective(){ ## preset, key
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDSC_CMD=rig \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Preset.include" ; AgentsToolsPresetEffective "$MMDAPP" "$1" "$2"' rig "$1" "$2" 2> /dev/null )
}

echo "-- 1. the list --"
rigRun --manager-preset-list
rigAssert "each preset with what it extends and comes to, and by whom it is used" "$( LC_ALL=C awk -F'\t' '{ printf "%s ext=%s svc=%s model=%s eff=%s used=%s / ", $3, $8, $9, $10, $11, $12 }' "$rigTmp/out" )" \
	"Agents:_preset-rig-base ext=- svc=claude model=- eff=- used=preset-rig-ext_preset-rig-opus / Agents:_preset-rig-ext ext=rig-base svc=claude model=low eff=- used=magic-team / Agents:_preset-rig-opus ext=rig-base svc=claude model=high eff=high used=- / "

echo "-- 2. the variables of a preset by their kinds --"
rigRun --manager-scope-read agents:preset-rig-ext
rigAssert "a preset that extends: the CLI service is locked, with why; the parent a choice of the others; the effort, the cache lifetime, the context, the extra line offered as missing" \
	"$( rigKeyRow PRESET_CLI_SERVICE ) $( rigKeyRow PRESET_EXTEND ) $( rigKeyRow PRESET_EFFORT ) $( rigKeyRow PRESET_INPUT_CACHE_TIME ) $( rigKeyRow PRESET_CONTEXT_MAX_SIZE ) $( rigKeyRow PRESET_EXTRA_SPAWN_LINE )" \
	"missing|locked|it_extends_a_preset:_the_CLI_service_is_ set|choice|rig-base=rig-base,rig-opus=rig-opus missing|choice|low=low,default=default,normal=normal,hi missing|choice|5m=5m,1h=1h missing|number|1000..10000000 missing|text|-"
rigRun --manager-scope-read agents:preset-rig-base
rigAssert "a preset that extends none: the CLI service a choice of the nine, no credential locked; the credentials of claude offered; the model a text" "$( rigKeyRow PRESET_CLI_SERVICE | LC_ALL=C cut -c1-60 ) $( rigKeyRow ANTHROPIC_API_KEY ) $( rigKeyRow PRESET_MODEL_OR_MACRO )" \
	"set|choice|claude=claude,copilot=copilot,grok=grok, missing|text|- missing|text|-"
rigAssert "a credential offered is one, by its type" "$( LC_ALL=C awk -F'\t' '$1 == "key" && $2 == "ANTHROPIC_API_KEY" { print $5 }' "$rigTmp/out" )" "credential"

echo "-- 3. the tiers --"
rigRun --manager-scope-read agents:magic-team
rigAssert "the team's three tiers: set or missing, each a choice of the presets, each alone and with every effort" "$( rigKeyRow SPAWN_TIER_LOW ) $( rigKeyRow SPAWN_TIER_HIGH ) $( LC_ALL=C awk -F'\t' '$2 == "SPAWN_TIER_HIGH" { print gsub( /=/, "=", $8 ) }' "$rigTmp/out" )" "set|choice|rig-base=rig-base,rig-base:low=rig-base: missing|choice|rig-base=rig-base,rig-base:low=rig-base: 18"
rigRun --manager-scope-read agents:keeper-myx
rigAssert "a member that holds no file of settings is a scope for its tiers: three missing choices; the id is none of the listed scopes" "$( rigKeyRow SPAWN_TIER_NORMAL ) $( rigRun --manager-scope-list ; LC_ALL=C grep -c 'keeper-myx' "$rigTmp/out" || : )" "missing|choice|rig-base=rig-base,rig-base:low=rig-base: 0"
rigRun --manager-preset-tiers
rigAssert "the tiers listed: the team first with its three, then each member to start" "$( LC_ALL=C awk -F'\t' '{ printf "%s %s %s %s %s / ", $2, $3, $8, $9, $10 }' "$rigTmp/out" )" "agents:magic-team Team rig-ext rig-ext - / agents:keeper-myx keeper-myx - - - / agents:magic-coordinator magic-coordinator - - - / "

echo "-- 4. the writes go through the setting reader --"
rigInput="high" ; rigRun --manager-scope-set agents:preset-rig-base PRESET_EFFORT
rigAssert "a value of the list is saved" "$rigRc $( LC_ALL=C grep -c '^PRESET_EFFORT=high$' "$rigAgents/preset-rig-base.agent.env" )" "0 1"
rigInput="enormous" ; rigRun --manager-scope-set agents:preset-rig-base PRESET_EFFORT
rigAssert "a value that is none of the list is refused and the file is as it was" "$rigRc $( LC_ALL=C grep -c '^PRESET_EFFORT=high$' "$rigAgents/preset-rig-base.agent.env" )" "1 1"
rigInput="grok" ; rigRun --manager-scope-set agents:preset-rig-ext PRESET_CLI_SERVICE
rigAssert "a CLI service in a preset that extends is refused by the reader itself, as the screen locks it" "$rigRc $( LC_ALL=C grep -c '^PRESET_CLI_SERVICE=' "$rigAgents/preset-rig-ext.agent.env" )" "1 0"
rigInput="5000" ; rigRun --manager-scope-set agents:preset-rig-base PRESET_CONTEXT_MAX_SIZE
rigAssert "a context size is saved" "$rigRc $( LC_ALL=C grep -c '^PRESET_CONTEXT_MAX_SIZE=5000$' "$rigAgents/preset-rig-base.agent.env" )" "0 1"

echo "-- 5. a preset made --"
rigInput="" ; rigRun --manager-preset-new rig-made --extend rig-base
rigAssert "extending one: made, with that as its first variable" "$rigRc $( LC_ALL=C cat "$rigTmp/out" ) $( LC_ALL=C grep -c '^PRESET_EXTEND=rig-base$' "$rigAgents/preset-rig-made.agent.env" )" "0 created	agents:preset-rig-made 1"
rigRun --manager-preset-new rig-own --cli-service grok
rigAssert "with a CLI service of its own: made" "$rigRc $( LC_ALL=C grep -c '^PRESET_CLI_SERVICE=grok$' "$rigAgents/preset-rig-own.agent.env" )" "0 1"
rigBad=""
for rigOne in "rig-made --extend rig-base" "Rig-Capital --cli-service claude" "rig-orphan --extend rig-nowhere" "rig-bogus --cli-service nonsense" "rig-short --extend" ; do
	# shellcheck disable=SC2086
	rigRun --manager-preset-new $rigOne ; [ "$rigRc" = 1 ] && [ ! -s "$rigTmp/out" ] || rigBad="$rigBad [$rigOne]"
done
rigAssert "a name taken, a capital, a parent that is not there, a service that is none and a wrong count are refused, print nothing and leave no file" "${rigBad:- all refused} $( ls "$rigAgents" | LC_ALL=C grep -c -e 'orphan' -e 'bogus' -e 'Capital' -e 'short' )" " all refused 0"

echo "-- 6. a preset in use is not deleted --"
rigRun --manager-scope-delete agents:preset-rig-base
rigAssert "one a preset extends: refused, naming who" "$rigRc $( LC_ALL=C grep -c 'in use by preset-rig-ext' "$rigTmp/err" ) $( [ -f "$rigAgents/preset-rig-base.agent.env" ] && echo kept )" "1 1 kept"
rigRun --manager-scope-delete agents:preset-rig-ext
rigAssert "one a tier of the team names: refused, naming the team" "$rigRc $( LC_ALL=C grep -c 'in use by magic-team' "$rigTmp/err" ) $( [ -f "$rigAgents/preset-rig-ext.agent.env" ] && echo kept )" "1 1 kept"
rigRun --manager-scope-delete agents:preset-rig-own
rigAssert "one nothing uses: deleted" "$rigRc $( [ -f "$rigAgents/preset-rig-own.agent.env" ] && echo kept || echo gone )" "0 gone"

echo "-- 7. end to end: the tier chosen is the preset a spawn gets --"
rigInput="rig-opus:high" ; rigRun --manager-scope-set agents:magic-team SPAWN_TIER_HIGH
rigAssert "a tier of the team chosen from the presets is saved" "$rigRc $( LC_ALL=C grep -c '^SPAWN_TIER_HIGH=rig-opus:high$' "$rigAgents/magic-team.agent.env" )" "0 1"
rigInput="rig-made" ; rigRun --manager-scope-set agents:keeper-myx SPAWN_TIER_LOW
rigAssert "a tier of a member that had no file makes its file" "$rigRc $( LC_ALL=C grep -c '^SPAWN_TIER_LOW=rig-made$' "$rigAgents/keeper-myx.agent.env" )" "0 1"
rigAssert "the spawner asked for the light tier (the team's SPAWN_HARNESS_TIER): the member's own low tier stands ahead of the team's" "$( rigChosen keeper-myx )" "rig-made"
rigAssert "a member with no tier of its own gets the team's, for the same tier" "$( rigChosen magic-coordinator )" "rig-ext"
printf 'SPAWN_TIER_LOW=rig-ext\nSPAWN_TIER_NORMAL=rig-ext\nSPAWN_TIER_HIGH=rig-opus:high\nSPAWN_HARNESS_TIER=heavy\n' > "$rigAgents/magic-team.agent.env"
rigAssert "asked for the heavy tier: the team's high tier, with its effort, for a member that has none of its own" "$( rigChosen magic-coordinator )" "rig-opus:high"
rigAssert "what the preset chosen comes to is what it inherits: its CLI service from its parent, its own model and effort" "$( rigEffective rig-opus PRESET_CLI_SERVICE ) $( rigEffective rig-opus PRESET_MODEL_OR_MACRO ) $( rigEffective rig-opus PRESET_EFFORT )" "claude high high"

printf '\nTOTAL: %d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
