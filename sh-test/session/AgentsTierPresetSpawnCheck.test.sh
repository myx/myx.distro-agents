#!/usr/bin/env bash
## Behavioural check on what a spawn does with the tiers (F10.2 of the refactorings epic): the spawn proxy chooses the
## preset of the member it starts from the tier settings, the member's ahead of the team's, and hands it to the console
## it starts as MDAT_SPAWN_PRESET; every read of a spawn setting in that console is then the preset's; the preset's extra
## spawn line is in the dispatch; a CLI service named by the caller is no preset's spawn; what a parent session left in the
## environment (a preset, the models its leg exported) is not handed on; and the brief a spawn is prepared with reads the
## CLI the spawn will run on.
## Held, against the proxy with a console stand-in that records what its environment says and what the tooling answers there:
##   1. no tier setting: no preset is chosen, and the console reads the team's own CLI service
##   2. a team tier setting: the console gets it, and the CLI service it reads is the preset's
##   3. a member's own setting stands ahead of the team's, with its effort
##   4. the tier asked picks the setting of that tier (SPAWN_HARNESS_TIER)
##   5. a caller-named CLI service: the console is told `-<service>`, reads the team's own CLI service and the credential of that service from a preset block, and no extra line is added
##   6. a parent's preset and models are not handed on
##   7. the preset's extra spawn line is in the dispatch, with no MDAT_SPAWN_PRESET in the caller's environment
##   8. the brief of a spawn is made for the CLI of the preset: harness or native
## Red before F10.2: 2 to 8 fail (1 holds). Offline: a fake console, a fake curl; every run an `env -i` child.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigTest/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's temp fixture is missing from the package"
rigTmp="$( rigTempDir AgentsTierPresetSpawnCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data" ; rigAgents="$rigWs/.local/.agents"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
mkdir -p "$rigAgents" "$rigTmp/bin" "$rigTmp/home" "$rigSkills/magic-team" "$rigSkills/keeper-myx" "$rigSkills/rig-member" "$rigSkills/magic-coordinator" "$rigData/board/running" "$rigData/inboxes/keeper-myx"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## The console the proxy launches: records the dispatch, what its environment says, and the CLI service the tooling answers there.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli) arm and --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER, records the dispatch and what its environment says.' \
	'[ -s "$RIG_SCENARIO/brief" ] && { cat > /dev/null ; exit 0 ; }' \
	'rigContext="$( cat )"' \
	'case "$rigContext" in "Your previous run on this task ended without calling SubagentHandback."*) exit 0 ;; esac' \
	'printf "%s\n" "$rigContext" > "$RIG_SCENARIO/brief"' \
	'{ printf "preset=%s\n" "${MDAT_SPAWN_PRESET-unset}" ; printf "light=%s\n" "${HARNESS_MODEL_LIGHT-unset}" ; printf "main=%s\n" "${HARNESS_MODEL_MAIN-unset}" ;' \
	'  printf "cli=%s\n" "$( bash "$RIG_FN" --agents-config-option magic-team --select SPAWN_CLI_SERVICE 2> /dev/null )" ;' \
	'  printf "cachetime=%s\n" "$( bash "$RIG_FN" --agents-config-option magic-team --select HARNESS_INPUT_CACHE_TIME 2> /dev/null )" ;' \
	'  [ -n "$( bash "$RIG_FN" --agents-config-option magic-team --select ANTHROPIC_API_KEY 2> /dev/null )" ] && printf "key=held\n" || printf "key=empty\n" ; } > "$RIG_SCENARIO/seen"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf '# rig armed\n' > "$rigSkills/rig-member/rig-member.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
printf 'PRESET_CLI_SERVICE=claude\nANTHROPIC_API_KEY=RIGKEY-in-the-base-preset\nPRESET_EXTRA_SPAWN_LINE=RIG-BASE-LINE keep the tool names as they are.\n' > "$rigAgents/preset-rig-base.agent.env"
printf 'PRESET_EXTEND=rig-base\nPRESET_MODEL_OR_MACRO=low\n' > "$rigAgents/preset-rig-ext.agent.env"
printf 'PRESET_CLI_SERVICE=grok\nPRESET_EXTRA_SPAWN_LINE=RIG-GROK-LINE answer in short sentences.\n' > "$rigAgents/preset-rig-grok.agent.env"
printf 'PRESET_CLI_SERVICE=claude-native\n' > "$rigAgents/preset-rig-native.agent.env"
rigTeamBase='SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSPAWN_CLI_SERVICE=rig-old-cli\n'

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigTeam(){ ## the team's scope: its base, then the lines given
	printf "$rigTeamBase" > "$rigAgents/magic-team.agent.env"
	[ $# -eq 0 ] || printf '%s\n' "$@" >> "$rigAgents/magic-team.agent.env"
}
rigMember(){ ## the scope of keeper-myx: the lines given
	: > "$rigAgents/keeper-myx.agent.env"
	[ $# -eq 0 ] || printf '%s\n' "$@" >> "$rigAgents/keeper-myx.agent.env"
}
rigSpawn(){ ## member, then --spawn-cli-service <name> where the caller names one; the caller's environment as rigOuter says
	: > "$rigTmp/brief" ; rm -f "$rigTmp/seen"
	local spawnMember="$1" ; shift
	env -i HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" ${rigOuter:-X=1} \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			member="$1" ; shift
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$member" --dispatch-doc:none --wait --context rig-spawn-tier "$@"
		' rig-spawn "$spawnMember" "$@" <<< "RIG-TASK-TEXT" 2>&1
}
rigSeen(){ ## key -- a line of what the console recorded; a variable that was not there reads as an empty one
	LC_ALL=C sed -n "s/^$1=//p" "$rigTmp/seen" 2> /dev/null | head -1 | LC_ALL=C sed 's/^unset$//'
}
rigOuter=""

echo "-- 1. no tier setting --"
rigTeam ; rigMember
rigOut="$( rigSpawn keeper-myx )"
grep -q 'RIG-TASK-TEXT' "$rigTmp/brief" || rigRefuse "the fake console never received the context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "no preset is chosen: the console's is empty"                      "$( rigSeen preset )" ""
rigAssert "and it reads the team's own CLI service, and holds no Claude credential"  "$( rigSeen cli ) $( rigSeen key )" "rig-old-cli empty"

echo "-- 2. a team tier setting --"
rigTeam "SPAWN_TIER_NORMAL=rig-ext"
rigSpawn keeper-myx > /dev/null
rigAssert "the console gets the team's preset"                               "$( rigSeen preset )" rig-ext
rigAssert "and the CLI service it reads is the preset's, inherited, with its credential"  "$( rigSeen cli ) $( rigSeen key )" "claude held"
rigAssert "the models a leg exports are not handed on"                       "$( rigSeen light )|$( rigSeen main )" "|"

echo "-- 3. a member's setting stands ahead of the team's, with its effort --"
rigMember "SPAWN_TIER_NORMAL=rig-grok:high"
rigSpawn keeper-myx > /dev/null
rigAssert "the console gets the member's preset, with the effort"            "$( rigSeen preset )" rig-grok:high
rigAssert "and reads its CLI service"                                        "$( rigSeen cli )" grok
rigSpawn rig-member > /dev/null
rigAssert "another member gets the team's"                                   "$( rigSeen preset )" rig-ext

echo "-- 4. the tier asked picks the setting of that tier --"
rigMember
rigTeam "SPAWN_TIER_NORMAL=rig-ext" "SPAWN_TIER_HIGH=rig-grok" "SPAWN_HARNESS_TIER=heavy"
rigSpawn keeper-myx > /dev/null
rigAssert "asked heavy: the team's high tier"                                "$( rigSeen preset )" rig-grok

echo "-- 5. a CLI service named by the caller is no preset's spawn --"
rigTeam "SPAWN_TIER_NORMAL=rig-ext"
rigSpawn keeper-myx --spawn-cli-service claude > /dev/null
rigAssert "the console is told the service named, as no preset's"             "$( rigSeen preset )" "-claude"
rigAssert "it reads the team's own CLI service"                              "$( rigSeen cli )" rig-old-cli
rigAssert "and the credential of the service named, from the first block that has it" "$( rigSeen key )" held

echo "-- 6. a parent's preset and models are not handed on --"
rigTeam
rigOuter="MDAT_SPAWN_PRESET=rig-grok HARNESS_MODEL_MAIN=leak-main HARNESS_MODEL_LIGHT=leak-light"
rigSpawn keeper-myx > /dev/null
rigAssert "the parent's preset is gone"                                      "$( rigSeen preset )" ""
rigAssert "so are its models, as empty values the leg stubs read as none"    "$( rigSeen light )|$( rigSeen main )" "|"
rigAssert "and the console reads the team's own CLI service"                 "$( rigSeen cli )" rig-old-cli
rigTeam "SPAWN_TIER_NORMAL=rig-ext"
rigSpawn keeper-myx > /dev/null
rigAssert "with a tier setting the parent's preset is replaced by the member's own choice"  "$( rigSeen preset )" rig-ext
rigOuter=""

echo "-- 7. the extra spawn line, from the tiers --"
rigTeam "SPAWN_TIER_NORMAL=rig-ext"
rigSpawn keeper-myx > /dev/null
rigAssert "the inherited line is in the dispatch, once, with no MDAT_SPAWN_PRESET in the caller's environment" "$( LC_ALL=C grep -c -x -F -- 'RIG-BASE-LINE keep the tool names as they are.' "$rigTmp/brief" )" 1
rigMember "SPAWN_TIER_NORMAL=rig-grok"
rigSpawn keeper-myx > /dev/null
rigAssert "the member's preset gives its own line, and not the team's"        "$( LC_ALL=C grep -c -x -F -- 'RIG-GROK-LINE answer in short sentences.' "$rigTmp/brief" )$( LC_ALL=C grep -c -F -- 'RIG-BASE-LINE' "$rigTmp/brief" )" 10
rigMember
rigSpawn keeper-myx --spawn-cli-service claude > /dev/null
rigAssert "a caller-named service adds no line"                              "$( LC_ALL=C grep -c -F -- 'RIG-' "$rigTmp/brief" )" 1

echo "-- 8. the brief is made for the CLI of the preset --"
rigBrief(){ ## member -- the brief the op prints, in brief.out
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_FN="$rigTool" ${rigOuter:-X=1} bash -c 'cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-spawn-prepare-brief "$1" --routine-default' rig-brief "$1" > "$rigTmp/brief.out" 2> "$rigTmp/brief.err"
}
rigTeam "SPAWN_CLI_SERVICE=claude-native"
rigBrief rig-member
rigAssert "control: with no tier setting the team's native service gives the native brief (a tools line)"  "$( LC_ALL=C grep -c '^tools: ' "$rigTmp/brief.out" )" 1
rigTeam "SPAWN_CLI_SERVICE=claude-native" "SPAWN_TIER_NORMAL=rig-ext"
rigBrief rig-member
rigAssert "with the team's tier a harness preset (claude) gives the harness brief, whatever the old setting says" "$( LC_ALL=C grep -c '^tools: ' "$rigTmp/brief.out" )" 0
rigTeam "SPAWN_CLI_SERVICE=claude" "SPAWN_TIER_NORMAL=rig-native"
rigBrief rig-member
rigAssert "a native preset gives the native brief"                           "$( LC_ALL=C grep -c '^tools: ' "$rigTmp/brief.out" )" 1
rigTeam "SPAWN_CLI_SERVICE=claude" "SPAWN_TIER_NORMAL=rig-ext"
rigMember
printf 'SPAWN_TIER_NORMAL=rig-native\n' > "$rigAgents/rig-member.agent.env"
rigBrief rig-member
rigAssert "the member's own setting is the one the brief follows"           "$( LC_ALL=C grep -c '^tools: ' "$rigTmp/brief.out" )" 1
rigBrief keeper-myx
rigAssert "and the team's for another member"                                "$( LC_ALL=C grep -c '^tools: ' "$rigTmp/brief.out" )" 0

echo "-- 9. the lifetime the preset asks of the input cache (F10.7) --"
printf 'PRESET_EXTEND=rig-hour\n' > "$rigAgents/preset-rig-hour-ext.agent.env"
printf 'PRESET_CLI_SERVICE=claude\nPRESET_INPUT_CACHE_TIME=1h\n' > "$rigAgents/preset-rig-hour.agent.env"
printf 'PRESET_CLI_SERVICE=claude\nPRESET_INPUT_CACHE_TIME=2h\n' > "$rigAgents/preset-rig-bad.agent.env"
printf 'PRESET_EXTEND=rig-bad\n' > "$rigAgents/preset-rig-bad-ext.agent.env"
rigMember
rigTeam "SPAWN_TIER_NORMAL=rig-hour"
rigSpawn keeper-myx > /dev/null
rigAssert "a preset that asks the hour: the console reads 1h as the lifetime of the run"  "$( rigSeen cachetime )" 1h
rigTeam "SPAWN_TIER_NORMAL=rig-hour-ext"
rigSpawn keeper-myx > /dev/null
rigAssert "one that extends it has it too"                                   "$( rigSeen cachetime )" 1h
rigTeam "SPAWN_TIER_NORMAL=rig-ext"
rigSpawn keeper-myx > /dev/null
rigAssert "a preset that asks nothing: the console reads none, the provider's own"  "$( rigSeen cachetime )" ""
rigTeam
rigSpawn keeper-myx > /dev/null
rigAssert "and with no tier setting at all"                                  "$( rigSeen cachetime )" ""
rigTeam "SPAWN_TIER_NORMAL=rig-bad"
rigOut="$( rigSpawn keeper-myx ; printf 'rc=%s' "$?" )"
rigAssert "a preset that holds another lifetime (written by hand, past the write check) refuses the spawn: nothing reaches the console, and the reason names the preset and the key"  "$( [ -s "$rigTmp/brief" ] && echo started || echo refused ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'preset rig-bad asks the input cache for a lifetime that is none of 5m, 1h' )" refused:1
rigAssert "and prints no value of it"                                        "$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F -- '2h' )" 0
rigTeam "SPAWN_TIER_NORMAL=rig-bad-ext"
rigSpawn keeper-myx > /dev/null
rigAssert "so does a preset that extends it: the value it inherits is checked"  "$( [ -s "$rigTmp/brief" ] && echo started || echo refused )" refused
rigTeam "SPAWN_TIER_NORMAL=rig-hour"
rigSpawn keeper-myx --spawn-cli-service claude > /dev/null
rigAssert "a caller-named CLI service is no preset's spawn, and asks nothing"  "$( rigSeen cachetime )" ""

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TIER PRESET SPAWN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TIER_PRESET_SPAWN: OK (%d assertions, offline)\n' "$rigPassCount"
