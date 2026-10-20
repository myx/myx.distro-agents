#!/usr/bin/env bash
## Behavioural check on the tiers (F10.2 of the refactorings epic): the team defaults and, optionally, each member
## configure three tier presets, SPAWN_TIER_LOW, SPAWN_TIER_NORMAL and SPAWN_TIER_HIGH, each `<preset>[:<effort>]`; the
## minimum to run team members is one default tier in the team defaults. The preset is resolved to a tier BEFORE it
## reaches the harness (the harness gate takes light, normal or heavy and stays as it is): the spawn settings a
## spawn reads from magic-team (the CLI service, the credentials, the harness tier, and the model of the tier) are
## answered from the resolved preset where tier settings are configured, and are read as ever where none is.
## Against a rig workspace built here; every call runs with MMDAPP at the rig, so the settings of the real workspace
## are never read and never written. No secret is printed: a value is compared inside this check, and what the check
## says of it is `same` or `differs`.
## Held:
##   A. the tier settings: accepted in magic-team and in a member's scope, in the form <preset>[:<effort>], else refused
##   B. the catalogue holds the three, in the scope of the team
##   C. the preset to a harness tier (today: light is the light model, normal the main model, heavy the main model with
##      effort high): a macro gives its tier; effort high lifts normal to heavy; a model name or no macro leaves the tier asked
##   D. the preset a spawner chooses: the member's setting of the tier asked, else the team's, else the same of the default tier
##   E. the spawn settings, answered from the preset; as ever where no tier is set; a credential of no use to the preset's
##      CLI service is never answered from the team's; a broken tier setting is said and answers nothing
##   F. the presets and tier settings of the workspace that pays are the ones read
##   G. a CLI service named by the caller is no preset's spawn (MDAT_SPAWN_PRESET=-<service>): its CLI is the one named, and a
##      credential of that service is the first preset block's that has the service of its own and holds the key (the workspace
##      that pays first, then this one), else the scope's, as ever
## Red before F10.2: A, B, C, D, E (but the control) and F fail; G fails before the lookup of a named service. Offline: the rig workspace alone.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTierPresetCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigPayer="$rigTmp/payer"
rigAgents="$rigWs/.local/.agents" ; rigPayerAgents="$rigPayer/.local/.agents"
mkdir -p "$rigAgents" "$rigPayerAgents" "$rigWs/.local/agents" "$rigTmp/home/.agents/magic-team" "$rigTmp/skills" "$rigTmp/bin"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
printf '#!/bin/sh\nexit 7\n' > "$rigTmp/bin/curl" ; chmod +x "$rigTmp/bin/curl"
printf '%s\n' "$rigPayer" > "$rigTmp/home/.agents/magic-team/known-workspaces.registry"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
: > "$rigTmp/all.out"
rigRc=0
rigPreset=""
rigRun(){ ## arguments of the dispatcher -- output in run.out/run.err, rc in rigRc; MDAT_SPAWN_PRESET as rigPreset says
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" ${rigPreset:+MDAT_SPAWN_PRESET="$rigPreset"} bash "$rigTool" "$@" ) > "$rigTmp/run.out" 2> "$rigTmp/run.err" < /dev/null
	rigRc=$?
	[ -n "${rigRead:-}" ] || cat "$rigTmp/run.out" "$rigTmp/run.err" >> "$rigTmp/all.out"
}
rigRunStdin(){ ## value, arguments
	local stdinValue="$1" ; shift
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" bash "$rigTool" "$@" ) > "$rigTmp/run.out" 2> "$rigTmp/run.err" <<< "$stdinValue"
	rigRc=$?
	cat "$rigTmp/run.out" "$rigTmp/run.err" >> "$rigTmp/all.out"
}
rigSelect(){ ## key -- what the team scope's reader gives (the spawn settings come through the preset where tiers are set); never for a credential
	local rigRead=1
	rigRun --agents-config-option magic-team --select "$1" ; cat "$rigTmp/run.out"
}
rigSame(){ ## key, value -- `same` where the reader's answer is that value, `differs` else; the value is never printed
	local rigRead=1
	rigRun --agents-config-option magic-team --select "$1"
	[ "$( cat "$rigTmp/run.out" )" = "$2" ] && printf same || printf differs
}
rigHeld(){ ## key -- `held` where the reader gives a value, `empty` where it gives none; the value is never printed
	local rigRead=1
	rigRun --agents-config-option magic-team --select "$1"
	[ -s "$rigTmp/run.out" ] && printf held || printf empty
}
rigPut(){ ## scope, key, value -- the rc of the write through the tooling
	rigRun --agents-config-option "$1" --upsert "$2" "$3" ; printf '%s' "$rigRc"
}
rigFn(){ ## a function of the include and its arguments -- output and ` rc=<rc>`
	local fnOut fnRc
	fnOut="$( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDSC_CMD=rig-check ${rigPreset:+MDAT_SPAWN_PRESET="$rigPreset"} bash -c '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Preset.include" && "$@"
	' rig "$@" 2>&1 )"
	fnRc=$?
	printf '%s rc=%s' "$fnOut" "$fnRc"
}
rigSecretA="sk-RIGtierCRED-Qw7ZpL3xV9tR2mBk4Hs8NfD1"
rigSecretB="oauth-RIGtierCRED-5yTgHn0LcX6aVu3PqZ8w"
rigSecretC="scwRIGtierCRED-9aB3cD5eF7gH1jKdeepseek"
rigOldKey="sk-RIGOLDteamCRED-1a2b3c4d5e6f7g8h9i0j"
rigOldScw="scwRIGOLDgemmaCRED-0j9i8h7g6f5e4d3c"
rigBlock(){ ## preset, lines... -- writes a preset block directly
	local blockName="$1" ; shift
	printf '%s\n' "$@" > "$rigAgents/preset-$blockName.agent.env"
}
rigBlock rig-claude "PRESET_CLI_SERVICE=claude" "ANTHROPIC_API_KEY=$rigSecretA" "CLAUDE_CODE_OAUTH_TOKEN=$rigSecretB"
rigBlock rig-haiku "PRESET_EXTEND=rig-claude" "PRESET_MODEL_OR_MACRO=low"
rigBlock rig-sonnet "PRESET_EXTEND=rig-claude" "PRESET_MODEL_OR_MACRO=claude-sonnet-5-5"
rigBlock rig-opus "PRESET_EXTEND=rig-claude" "PRESET_MODEL_OR_MACRO=high"
rigBlock rig-scw "PRESET_CLI_SERVICE=scaleway" "SCALEWAY_DEEPSEEK=$rigSecretC" "PRESET_MODEL_OR_MACRO=normal"
rigBlock rig-nocli "PRESET_MODEL_OR_MACRO=low"
## The old way: the team's own spawn settings, which no tier setting yet replaces.
printf 'SPAWN_CLI_SERVICE=claude-native\nANTHROPIC_API_KEY=%s\nSCALEWAY_GEMMA=%s\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_ROUND_SECONDS=120\n' "$rigOldKey" "$rigOldScw" > "$rigAgents/magic-team.agent.env"
printf '# member\n' > "$rigAgents/keeper-rig.agent.env"
chmod 770 "$rigAgents" ; chmod 660 "$rigAgents"/*.agent.env

echo "-- control: with no tier setting the team's own spawn settings are read as ever --"
rigAssert "the CLI service is the team's"                                          "$( rigSelect SPAWN_CLI_SERVICE )" claude-native
rigAssert "the credential is the team's"                                           "$( rigSame ANTHROPIC_API_KEY "$rigOldKey" )" same
rigAssert "the harness tier asked is none"                                         "$( rigSelect SPAWN_HARNESS_TIER )" ""

echo "-- A. the tier settings --"
rigAssert "SPAWN_TIER_NORMAL=<preset> is accepted in the team's scope"            "$( rigPut magic-team SPAWN_TIER_NORMAL rig-sonnet )" 0
rigAssert "and is stored whole"                                                    "$( rigSelect SPAWN_TIER_NORMAL )" rig-sonnet
rigAssert "with an effort, <preset>:<effort>"                                      "$( rigPut magic-team SPAWN_TIER_HIGH rig-opus:high )" 0
rigAssert "the three tier names are SPAWN_TIER_LOW, _NORMAL and _HIGH"            "$( rigPut magic-team SPAWN_TIER_LOW rig-haiku )" 0
rigAssert "a member's scope takes them too"                                        "$( rigPut keeper-rig SPAWN_TIER_NORMAL rig-scw )" 0
rigAssert "a preset that is not there is refused"                                  "$( rigPut magic-team SPAWN_TIER_NORMAL rig-nothing )" 1
rigAssert "an effort that is none of the five is refused"                          "$( rigPut magic-team SPAWN_TIER_NORMAL rig-sonnet:max )" 1
rigAssert "an empty effort, two efforts, and no preset are refused"                "$( rigPut magic-team SPAWN_TIER_NORMAL rig-sonnet: )$( rigPut magic-team SPAWN_TIER_NORMAL rig-sonnet:low:high )$( rigPut magic-team SPAWN_TIER_NORMAL :high )" 111
rigAssert "a fourth tier name is refused"                                          "$( rigPut magic-team SPAWN_TIER_URGENT rig-sonnet )" 1
rigAssert "a tier setting stands in no preset's block"                             "$( rigPut preset-rig-haiku SPAWN_TIER_NORMAL rig-sonnet )" 1
rigAssert "a refusal leaves the stored value: the team's normal tier is still the first"  "$( rigSelect SPAWN_TIER_NORMAL )" rig-sonnet
rigRunStdin "rig-haiku:low" --agents-config-option magic-team --upsert-from-stdin SPAWN_TIER_LOW
rigAssert "a good value from stdin is written"                                     "$rigRc $( rigSelect SPAWN_TIER_LOW )" "0 rig-haiku:low"
rigRunStdin "rig-nothing" --agents-config-option magic-team --upsert-from-stdin SPAWN_TIER_LOW
rigAssert "a bad one is refused and the stored value stands"                       "$rigRc $( rigSelect SPAWN_TIER_LOW )" "1 rig-haiku:low"
rigRun --agents-config-option magic-team --upsert SPAWN_TIER_NORMAL "RIGPASTED-secret-Zq81"
rigAssert "a refusal repeats nothing that was given"                               "$( cat "$rigTmp/run.out" "$rigTmp/run.err" | LC_ALL=C grep -c -F -e 'RIGPASTED-secret-Zq81' )" 0
rigRun --agents-config-option keeper-rig --delete SPAWN_TIER_NORMAL
rigAssert "a tier setting is taken off by a delete"                                "$rigRc $( LC_ALL=C grep -c '^SPAWN_TIER_' "$rigAgents/keeper-rig.agent.env" )" "0 0"
rigPut keeper-rig SPAWN_TIER_NORMAL rig-scw > /dev/null
rigPut magic-team SPAWN_TIER_LOW rig-haiku > /dev/null

echo "-- B. the catalogue --"
rigCatalogue(){ ( . "$rigPackage/sh-lib/config/AgentsTools.OwnerSetupOptionSpec.include" ; AgentsToolsOwnerSetupOptionSpec "$1" ) ; }
rigAssert "the three tier settings are in the catalogue, in the scope of the team, plain" "$( for rigKey in SPAWN_TIER_LOW SPAWN_TIER_NORMAL SPAWN_TIER_HIGH ; do rigCatalogue "$rigKey" | LC_ALL=C cut -d'|' -f1,3 ; done | LC_ALL=C sort | uniq -c | tr -s ' ' )" " 3 magic-team|plain"

echo "-- C. the preset to a harness tier --"
rigTier(){ rigFn AgentsToolsPresetTier "$@" ; }
rigAssert "low and easy are the light tier"                                        "$( rigTier low '' normal )$( rigTier easy '' heavy )" "light rc=0light rc=0"
rigAssert "normal and default are the normal tier"                                 "$( rigTier normal '' light )$( rigTier default '' heavy )" "normal rc=0normal rc=0"
rigAssert "high and hard are the heavy tier"                                       "$( rigTier high '' normal )$( rigTier hard '' light )" "heavy rc=0heavy rc=0"
rigAssert "the effort high or hard lifts a normal macro to heavy, which is the main model with effort high" "$( rigTier normal high normal )$( rigTier default hard normal )" "heavy rc=0heavy rc=0"
rigAssert "the effort low, default or normal changes no tier"                      "$( rigTier normal low normal )$( rigTier normal default normal )$( rigTier low normal normal )" "normal rc=0normal rc=0light rc=0"
rigAssert "effort high leaves a light macro light: the tier light has no effort"    "$( rigTier low high normal )" "light rc=0"
rigAssert "a model name leaves the tier asked, light, normal or heavy"             "$( rigTier claude-sonnet-5-5 '' light )$( rigTier claude-sonnet-5-5 '' normal )$( rigTier claude-sonnet-5-5 '' heavy )" "light rc=0normal rc=0heavy rc=0"
rigAssert "and effort high lifts it from normal to heavy"                          "$( rigTier claude-sonnet-5-5 high normal )" "heavy rc=0"
rigAssert "no macro and no tier asked is the normal tier"                          "$( rigTier '' '' '' )" "normal rc=0"
rigAssert "no macro: the tier asked stands"                                        "$( rigTier '' '' light )$( rigTier '' '' heavy )" "light rc=0heavy rc=0"
rigAssert "the harness gate is not widened: --tier takes light, normal and heavy, and the default is normal" "$( LC_ALL=C grep -c -F -e 'light|normal|heavy) harnessTier="$2" ;;' -e 'harnessTier="normal"' "$rigPackage/sh-lib/harness/AgentsUniversalHarness.sh" )" 2

echo "-- D. the preset a spawner chooses --"
rigChosen(){ rigFn AgentsToolsPresetChosen "$@" ; }
rigAssert "asked none: the team's normal tier"                                     "$( rigChosen '' )" "rig-sonnet rc=0"
printf 'SPAWN_HARNESS_TIER=light\n' >> "$rigAgents/magic-team.agent.env"
rigAssert "asked light: the team's low tier, with its effort where it has one"     "$( rigChosen '' )" "rig-haiku rc=0"
printf 'SPAWN_HARNESS_TIER=heavy\n' >> "$rigAgents/magic-team.agent.env"
rigAssert "asked heavy: the team's high tier, with its effort"                     "$( rigChosen '' )" "rig-opus:high rc=0"
rigAssert "a member with no setting of its own gets the team's"                    "$( rigChosen keeper-other )" "rig-opus:high rc=0"
rigPut keeper-rig SPAWN_TIER_HIGH rig-scw:low > /dev/null
rigAssert "a member's setting of the tier asked stands ahead of the team's"        "$( rigChosen keeper-rig )" "rig-scw:low rc=0"
printf 'SPAWN_HARNESS_TIER=normal\n' >> "$rigAgents/magic-team.agent.env"
rigAssert "asked normal: the member's normal tier, not its high one"               "$( rigChosen keeper-rig )" "rig-scw rc=0"
printf 'SPAWN_HARNESS_TIER=light\n' >> "$rigAgents/magic-team.agent.env"
rigAssert "asked light, where the member sets none: the team's low tier, not the member's normal" "$( rigChosen keeper-rig )" "rig-haiku rc=0"
rigRun --agents-config-option magic-team --delete SPAWN_TIER_LOW
rigAssert "where the team sets none of the tier asked, the default tier of the member" "$( rigChosen keeper-rig )" "rig-scw rc=0"
rigAssert "and of the team for a member with none"                                 "$( rigChosen keeper-other )" "rig-sonnet rc=0"
rigAssert "the minimum is the team's default tier: with only that set, any tier asked gets it" "$( rigRun --agents-config-option magic-team --delete SPAWN_TIER_HIGH ; rigChosen keeper-other )" "rig-sonnet rc=0"
rigPut magic-team SPAWN_TIER_LOW rig-haiku > /dev/null ; rigPut magic-team SPAWN_TIER_HIGH rig-opus:high > /dev/null
rigRun --agents-config-option magic-team --delete SPAWN_HARNESS_TIER
rigAssert "a rig with no tier setting chooses none"                                "$( mv "$rigAgents/magic-team.agent.env" "$rigTmp/team.keep" ; printf 'SPAWN_CLI_SERVICE=claude-native\n' > "$rigAgents/magic-team.agent.env" ; mv "$rigAgents/keeper-rig.agent.env" "$rigTmp/member.keep" ; rigChosen keeper-rig ; mv "$rigTmp/team.keep" "$rigAgents/magic-team.agent.env" ; mv "$rigTmp/member.keep" "$rigAgents/keeper-rig.agent.env" )" " rc=0"

echo "-- E. the spawn settings, answered from the preset --"
rigRun --agents-config-option magic-team --delete SPAWN_HARNESS_TIER
rigAssert "asked none: the CLI service is the preset's, inherited from rig-claude"  "$( rigSelect SPAWN_CLI_SERVICE )" claude
rigAssert "the credentials are the preset's (inherited), not the team's"           "$( rigSame ANTHROPIC_API_KEY "$rigSecretA" )$( rigSame CLAUDE_CODE_OAUTH_TOKEN "$rigSecretB" )" samesame
rigAssert "a credential the preset's CLI service does not read is answered empty, the team's old one not given" "$( rigHeld SCALEWAY_GEMMA )" empty
rigAssert "the harness tier answered is the resolved one: a model name, tier asked none, is normal" "$( rigSelect SPAWN_HARNESS_TIER )" normal
rigAssert "the model of the main tier is the preset's model name, the light one none"  "$( rigSelect HARNESS_MODEL_MAIN )|$( rigSelect HARNESS_MODEL_LIGHT )" "claude-sonnet-5-5|"
printf 'SPAWN_HARNESS_TIER=light\n' >> "$rigAgents/magic-team.agent.env"
rigAssert "asked light: the haiku preset, macro low: tier light, and no model name to pass" "$( rigSelect SPAWN_HARNESS_TIER )|$( rigSelect HARNESS_MODEL_LIGHT )|$( rigSelect HARNESS_MODEL_MAIN )" "light||"
printf 'SPAWN_HARNESS_TIER=heavy\n' >> "$rigAgents/magic-team.agent.env"
rigAssert "asked heavy: the opus preset, macro high: tier heavy"                   "$( rigSelect SPAWN_HARNESS_TIER )" heavy
printf 'SPAWN_HARNESS_TIER=normal\n' >> "$rigAgents/magic-team.agent.env"
rigPut magic-team SPAWN_TIER_NORMAL rig-sonnet:high > /dev/null
rigAssert "the effort after the preset lifts a normal tier to heavy"                "$( rigSelect SPAWN_HARNESS_TIER )|$( rigSelect HARNESS_MODEL_MAIN )" "heavy|claude-sonnet-5-5"
rigPut magic-team SPAWN_TIER_NORMAL rig-sonnet > /dev/null
rigPreset="rig-scw"
rigAssert "a spawn's own preset (MDAT_SPAWN_PRESET) is the one answered: its CLI service" "$( rigSelect SPAWN_CLI_SERVICE )" scaleway
rigAssert "its credential, and none of the team's or of the preset it was not"      "$( rigSame SCALEWAY_DEEPSEEK "$rigSecretC" )|$( rigHeld SCALEWAY_GEMMA )|$( rigHeld ANTHROPIC_API_KEY )" "same|empty|empty"
rigAssert "its macro normal gives the tier normal, and no model name"               "$( rigSelect SPAWN_HARNESS_TIER )|$( rigSelect HARNESS_MODEL_MAIN )" "normal|"
rigRun --agents-config-option magic-team --select-default SPAWN_CLI_SERVICE fallback
rigAssert "--select-default is answered the same way"                              "$( cat "$rigTmp/run.out" )" scaleway
rigPreset=""
rigAssert "a key that is no spawn setting is read as ever"                         "$( rigSame SLACK_BOT_TOKEN rig-bot-token-TEAM )$( rigSelect WAIT_ROUND_SECONDS )" "same120"
rigAssert "the team's own spawn settings are not erased: they stand in their scope, read by the scope's reader"  "$( LC_ALL=C grep -c -e '^SPAWN_CLI_SERVICE=claude-native$' "$rigAgents/magic-team.agent.env" )" 1
printf 'SPAWN_TIER_NORMAL=rig-gone\n' >> "$rigAgents/magic-team.agent.env"
rigRun --agents-config-option magic-team --select SPAWN_CLI_SERVICE
rigAssert "a tier setting that names a preset that is not there is said, and answers nothing" "$rigRc $( LC_ALL=C grep -c -e 'rig-gone' "$rigTmp/run.err" ) $( cat "$rigTmp/run.out" )" "1 1 "
rigPut magic-team SPAWN_TIER_NORMAL rig-sonnet > /dev/null
printf 'SPAWN_TIER_NORMAL=rig-nocli\n' >> "$rigAgents/magic-team.agent.env"
rigRun --agents-config-option magic-team --select SPAWN_CLI_SERVICE
rigAssert "a preset with no CLI service is said, and answers nothing"              "$rigRc $( LC_ALL=C grep -c -e 'rig-nocli' "$rigTmp/run.err" ) $( cat "$rigTmp/run.out" )" "1 1 "
rigPut magic-team SPAWN_TIER_NORMAL rig-sonnet > /dev/null

echo "-- G. a CLI service named by the caller --"
rigSecretF="sk-RIGaaaCRED-7Hn2Vb5Qd9Xw3Lm8Pt1Zc4Rk6Jf0"
rigSecretG="sk-RIGextCRED-3Pq8Wd2Hn6Tb9Vm1Zc5Lk7Jf4Rx0Gs"
rigPreset="-claude"
rigAssert "the CLI service is read from the team's scope, as ever: the named one is the caller's own"  "$( rigSelect SPAWN_CLI_SERVICE )" claude-native
rigAssert "a Claude credential is the first claude block's, the team's old one not given"  "$( rigSame ANTHROPIC_API_KEY "$rigSecretA" )$( rigSame CLAUDE_CODE_OAUTH_TOKEN "$rigSecretB" )" samesame
rigPreset="-claude-native"
rigAssert "a native service has the credentials of its leg"                         "$( rigSame ANTHROPIC_API_KEY "$rigSecretA" )" same
rigPreset="-scaleway"
rigAssert "a Scaleway credential is the scaleway block's"                          "$( rigSame SCALEWAY_DEEPSEEK "$rigSecretC" )" same
rigAssert "one no block holds is the scope's own, as ever"                          "$( rigSame SCALEWAY_GEMMA "$rigOldScw" )" same
rigPreset="-claude"
rigAssert "a credential the named service does not read is the scope's: none here"  "$( rigHeld SCALEWAY_DEEPSEEK )" empty
rigBlock rig-aaa-claude "PRESET_CLI_SERVICE=claude" "ANTHROPIC_API_KEY=$rigSecretF"
rigAssert "the first block by name that holds it is the one"                        "$( rigSame ANTHROPIC_API_KEY "$rigSecretF" )" same
rm -f "$rigAgents/preset-rig-aaa-claude.agent.env"
rigBlock rig-aaa-ext "PRESET_EXTEND=rig-claude" "ANTHROPIC_API_KEY=$rigSecretG"
rigAssert "a block that extends is not one that has the service of its own"          "$( rigSame ANTHROPIC_API_KEY "$rigSecretA" )" same
rm -f "$rigAgents/preset-rig-aaa-ext.agent.env"
rigPreset=""

echo "-- F. the workspace that pays --"
mkdir -p "$rigPayer/.local/.agents"
printf 'PRESET_CLI_SERVICE=grok\nXAI_API_KEY=%s\n' "$rigSecretC" > "$rigPayerAgents/preset-rig-paid.agent.env"
printf 'SPAWN_TIER_NORMAL=rig-paid\nSPAWN_CLI_SERVICE=copilot\n' > "$rigPayerAgents/magic-team.agent.env"
printf 'SPAWN_SETTINGS_WORKSPACE=payer\n' >> "$rigAgents/magic-team.agent.env"
rigAssert "the team's tier setting and the preset are the paying workspace's: its CLI service"  "$( rigSelect SPAWN_CLI_SERVICE )" grok
rigAssert "its credential"                                                         "$( rigSame XAI_API_KEY "$rigSecretC" )" same
rigPreset="rig-paid"
rigAssert "a spawn's preset is read there too"                                     "$( rigSelect SPAWN_CLI_SERVICE )" grok
rigPreset=""
rigPreset="-grok"
rigAssert "a named service finds its credential in the paying workspace's block first"  "$( rigSame XAI_API_KEY "$rigSecretC" )" same
rigPreset="-scaleway"
rigAssert "and, where that has none, in this workspace's own"                       "$( rigSame SCALEWAY_DEEPSEEK "$rigSecretC" )" same
rigPreset=""

echo "-- guard: no whole secret on any stream; the real workspace untouched --"
rigAssert "no whole credential of the rig appears in any output"                   "$( LC_ALL=C grep -c -F -e "$rigSecretA" -e "$rigSecretB" -e "$rigSecretC" -e "$rigOldKey" -e "$rigOldScw" "$rigTmp/all.out" )" 0
rigAssert "the real workspace holds no setting made by this check"                 "$( LC_ALL=C grep -l -e 'rig-sonnet' -e 'rig-haiku' "${MMDAPP%/}/.local/.agents"/*.agent.env 2> /dev/null | wc -l | tr -d ' ' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TIER PRESET CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TIER_PRESET: OK (%d assertions, offline)\n' "$rigPassCount"
