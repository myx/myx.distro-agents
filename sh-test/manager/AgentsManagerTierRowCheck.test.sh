#!/usr/bin/env bash
## Behavioural check on the team's tier row as the console writes it (S23.10): a console edit changes the value a
## spawn really uses. That value is what AgentsToolsPresetChosen answers, the one the spawn proxy exports as
## MDAT_SPAWN_PRESET. A read of the scope file is not that value, so no assertion here is built on one.
## Held, against a rig workspace and a second workspace named to pay for its spawns:
##   A. a workspace that pays for itself: the team's tier written from the console is the preset chosen (control)
##   B. the same, for a member's own tier row (control)
##   C. with a paying workspace named, the chooser answers that workspace's team tier (control)
##   D. with a paying workspace named, a member's own tier written from the console is the preset chosen (control)
##   E. with a paying workspace named, the team's tier written from the console is the preset chosen
##   F. a paying workspace named that this machine does not know: the write and the removal of the team's tier are
##      refused, the refusal names the payer, and neither file changes -- RED on live, where both exits 0 and write here
## Red before S23.10: E failed, the write staying in this workspace while the chooser read the one that pays. A to D held.
## Red on the bad payer: F, both calls, where `AgentsToolsConfigOptionElsewhere` answers nothing for a payer that
## resolves to no workspace and the write falls back to this workspace.
## Offline: only the rig's tree is written, and no credential is printed.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerTierRowCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigPayer="$rigTmp/payer" ; rigSkills="$rigTmp/skills"
rigAgents="$rigWs/.local/.agents" ; rigPayerAgents="$rigPayer/.local/.agents"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
mkdir -p "$rigAgents" "$rigPayerAgents" "$rigTmp/home/.agents/magic-team" "$rigSkills/keeper-rig"
printf '%s\n' "$rigPayer" > "$rigTmp/home/.agents/magic-team/known-workspaces.registry"
printf '# rig armed\n' > "$rigSkills/keeper-rig/keeper-rig.basic.md"
printf '# rig armed\n' > "$rigSkills/keeper-rig/keeper-rig.armed.md"
printf 'PRESET_CLI_SERVICE=claude\nANTHROPIC_API_KEY=rig-tier-row-key-ONE\n' > "$rigAgents/preset-rig-a.agent.env"
printf 'PRESET_EXTEND=rig-a\nPRESET_MODEL_OR_MACRO=high\n' > "$rigAgents/preset-rig-b.agent.env"
printf 'PRESET_CLI_SERVICE=claude\nANTHROPIC_API_KEY=rig-tier-row-key-TWO\n' > "$rigPayerAgents/preset-paid-a.agent.env"
printf 'PRESET_EXTEND=paid-a\nPRESET_MODEL_OR_MACRO=high\n' > "$rigPayerAgents/preset-paid-b.agent.env"
printf 'SPAWN_TIER_NORMAL=rig-a\n' > "$rigAgents/magic-team.agent.env"
printf 'SPAWN_TIER_NORMAL=paid-a\n' > "$rigPayerAgents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRc=0
rigInput=""
rigRun(){ ## the console's arguments -- one call from the rig workspace, its value on the standard input; rc in rigRc
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" \
		MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_WORKSPACE_MODE=team-rig \
		bash "$rigTool" "$@" ) > "$rigTmp/run.out" 2> "$rigTmp/run.err" <<< "$rigInput"
	rigRc=$?
}
rigChosen(){ ## member (may be empty) -- the preset the spawner chooses, as the spawn proxy takes it
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDSC_CMD=rig \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Preset.include" ; AgentsToolsPresetChosen "$1"' rig "$1" 2> /dev/null )
}

echo "-- A. a workspace that pays for itself --"
rigAssert "the team's tier before any write is the preset the chooser answers" "$( rigChosen "" )" rig-a
rigInput="rig-b" ; rigRun --manager-scope-set agents:magic-team SPAWN_TIER_NORMAL
rigAssert "the console saves the team's tier" "$rigRc" 0
rigAssert "the tier the console saved is the preset a spawn of the team is given" "$( rigChosen "" )" rig-b

echo "-- B. a member's own tier row, in a workspace that pays for itself --"
rigInput="rig-b" ; rigRun --manager-scope-set agents:keeper-rig SPAWN_TIER_NORMAL
rigAssert "the member's tier saved from the console is the preset chosen for that member" "$rigRc $( rigChosen keeper-rig )" "0 rig-b"

echo "-- C. a workspace whose spawn settings are another's --"
printf 'SPAWN_SETTINGS_WORKSPACE=payer\n' >> "$rigAgents/magic-team.agent.env"
rigAssert "with the team's tier set here and there, the chooser answers the paying workspace's" "$( rigChosen "" )" paid-a

echo "-- D. a member's own tier row, with a paying workspace named --"
rigInput="rig-a" ; rigRun --manager-scope-set agents:keeper-rig SPAWN_TIER_NORMAL
rigAssert "a member's own tier is the preset chosen for that member, the team's row aside" "$rigRc $( rigChosen keeper-rig )" "0 rig-a"

echo "-- E. the team's tier row, with a paying workspace named --"
rigInput="rig-a" ; rigRun --manager-scope-set agents:magic-team SPAWN_TIER_NORMAL
rigAssert "the console reports the save of the team's tier" "$rigRc" 0
rigAssert "the team's tier the console saved is the preset a spawn of the team is given" "$( rigChosen "" )" rig-a

echo "-- F. a paying workspace this machine does not know --"
printf 'SPAWN_SETTINGS_WORKSPACE=no-such-workspace-x\n' >> "$rigAgents/magic-team.agent.env"
rigFilesBefore="$( cksum < "$rigAgents/magic-team.agent.env" )/$( cksum < "$rigPayerAgents/magic-team.agent.env" )"
rigInput="rig-b" ; rigRun --manager-scope-set agents:magic-team SPAWN_TIER_NORMAL
rigAssert "the write is refused, and the refusal names the paying workspace" "$rigRc $( LC_ALL=C grep -c 'no-such-workspace-x' "$rigTmp/run.err" )" "1 1"
rigAssert "neither workspace's file changes on the refusal" "$( cksum < "$rigAgents/magic-team.agent.env" )/$( cksum < "$rigPayerAgents/magic-team.agent.env" )" "$rigFilesBefore"
rigInput="" ; rigRun --manager-scope-unset agents:magic-team SPAWN_TIER_NORMAL
rigAssert "the removal is refused, and the refusal names the paying workspace" "$rigRc $( LC_ALL=C grep -c 'no-such-workspace-x' "$rigTmp/run.err" )" "1 1"
rigAssert "neither workspace's file changes on the refused removal" "$( cksum < "$rigAgents/magic-team.agent.env" )/$( cksum < "$rigPayerAgents/magic-team.agent.env" )" "$rigFilesBefore"

printf '\nTOTAL: %d passed, %d failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
