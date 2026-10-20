#!/usr/bin/env bash
## Behavioural check on the extra spawn line of a preset (F10.1 of the refactorings epic): the one line the human-owner
## wrote in the preset the spawner chose for a spawn, which the spawner puts into the dispatch it crafts, and which no
## member is shown the source of. The preset the spawner chooses is the team's default tier (SPAWN_TIER_NORMAL,
## `<preset>[:<effort>]`, F10.2), which the rig sets in the team's scope; MDAT_SPAWN_PRESET is what the spawner then
## sets for the one spawn.
## Held, against the proxy with a console stand-in that records the dispatch it is started with:
##   1. a spawn with no preset chosen gets no extra line, and the dispatch is the dispatch of every spawn
##   2. a spawn whose preset holds a line gets it, once, as a line of its own, after the standing text
##   3. a preset that extends one with a line inherits it; its own stands ahead of the inherited one
##   4. the effort after the name changes nothing here
##   5. under no heading of its own, and the preset is not named in the dispatch: no member is told where it came from
##   6. it is not in the sandbox's input/ either, which holds the brief as given
##   7. a preset with no line adds nothing; a preset that is not there adds none
##   8. it is read in the workspace that pays for the spawn, where another pays
## Red before F10.1: 2, 3, 4 and 8 fail (1, 5, 6 and 7 hold: they are what must stay).
## (Reconciled in F10.2: the preset is chosen by the team's tier setting, no longer handed in by the environment.)
## Offline: a fake console that records what it receives, a fake curl that answers Slack; every run an `env -i` child.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigTest/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's temp fixture is missing from the package"
rigTmp="$( rigTempDir AgentsPresetSpawnLineCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigPayer="$rigTmp/payer"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
mkdir -p "$rigWs/.local/.agents" "$rigPayer/.local/.agents" "$rigTmp/bin" "$rigTmp/home/.agents/magic-team" "$rigSkills/magic-team" "$rigSkills/keeper-myx" "$rigSkills/magic-coordinator" "$rigData/board/running" "$rigData/inboxes/keeper-myx"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'[ -s "$RIG_SCENARIO/brief" ] && { cat > /dev/null ; exit 0 ; }' \
	'rigContext="$( cat )"' \
	'case "$rigContext" in "Your previous run on this task ended without calling SubagentHandback."*) exit 0 ;; esac' \
	'printf "%s\n" "$rigContext" > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The presets of the rig: a base with a line, an extension that inherits it, one with a line of its own, one with none.
rigAgents="$rigWs/.local/.agents"
printf 'PRESET_CLI_SERVICE=claude\nPRESET_EXTRA_SPAWN_LINE=RIG-BASE-LINE do not paraphrase the tool names.\n' > "$rigAgents/preset-rig-base.agent.env"
printf 'PRESET_EXTEND=rig-base\nPRESET_MODEL_OR_MACRO=low\n' > "$rigAgents/preset-rig-ext.agent.env"
printf 'PRESET_EXTEND=rig-base\nPRESET_EXTRA_SPAWN_LINE=RIG-OWN-LINE keep answers short.\n' > "$rigAgents/preset-rig-own.agent.env"
printf 'PRESET_CLI_SERVICE=grok\n' > "$rigAgents/preset-rig-plain.agent.env"
## The workspace that pays holds a preset the spawning workspace does not.
printf 'PRESET_CLI_SERVICE=claude\nPRESET_EXTRA_SPAWN_LINE=RIG-PAYER-LINE only the payer holds this.\n' > "$rigPayer/.local/.agents/preset-rig-paid.agent.env"
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
rigSpawn(){ ## content, member, the tier setting of the team (may be empty), the workspace that pays (may be empty; the setting is then its team's)
	: > "$rigTmp/brief"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	: > "$rigPayer/.local/.agents/magic-team.agent.env"
	if [ -n "${3:-}" ] ; then
		if [ -n "${4:-}" ] ; then printf 'SPAWN_TIER_NORMAL=%s\n' "$3" > "$rigPayer/.local/.agents/magic-team.agent.env" ; else printf 'SPAWN_TIER_NORMAL=%s\n' "$3" >> "$rigWs/.local/.agents/magic-team.agent.env" ; fi
	fi
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$1" --dispatch-doc:none --wait --context rig-spawn-preset ${2:+--spawn-settings-workspace "$2"}
		' rig-spawn "$2" "${4:-}" <<< "$1" 2>&1
}
rigCount(){ ## fixed text, anywhere in a line of the dispatch
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/brief"
}

echo "-- 1. no preset chosen: the dispatch of every spawn --"
rigOut="$( rigSpawn "RIG-TASK-TEXT" keeper-myx "" )"
grep -q 'RIG-TASK-TEXT' "$rigTmp/brief" || rigRefuse "the fake console never received the context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "the launch succeeded"                                  "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "no extra line is in it"                                "$( rigCount 'RIG-' | tr -d ' ' )" 1
rigPlainHeadings="$( LC_ALL=C grep -c '^## ' "$rigTmp/brief" )"
rigPlainLines="$( wc -l < "$rigTmp/brief" | tr -d ' ' )"

echo "-- 2. a preset with a line: once, as a line of its own, after the standing text --"
rigOut="$( rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-base" )"
rigAssert "the launch succeeded"                                  "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "the line is in the dispatch, as a whole line, once"    "$( LC_ALL=C grep -c -x -F -- 'RIG-BASE-LINE do not paraphrase the tool names.' "$rigTmp/brief" )" 1
rigAssert "after the standing text of the spawn"                  "$( LC_ALL=C awk '/^## Staying on the task/ { stay = NR } /^RIG-BASE-LINE/ { line = NR } END { print ( stay > 0 && line > stay ) ? "after" : "not after" }' "$rigTmp/brief" )" after

echo "-- 3. an extension inherits it; its own stands ahead --"
rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-ext" > /dev/null
rigAssert "the extension that holds none gets the parent's, once"  "$( LC_ALL=C grep -c -x -F -- 'RIG-BASE-LINE do not paraphrase the tool names.' "$rigTmp/brief" )" 1
rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-own" > /dev/null
rigAssert "the extension that holds its own gets its own"          "$( LC_ALL=C grep -c -x -F -- 'RIG-OWN-LINE keep answers short.' "$rigTmp/brief" )" 1
rigAssert "and not the parent's as well"                           "$( rigCount 'RIG-BASE-LINE' )" 0

echo "-- 4. the effort after the name changes nothing --"
rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-base:high" > /dev/null
rigAssert "the line is there, once"                                "$( LC_ALL=C grep -c -x -F -- 'RIG-BASE-LINE do not paraphrase the tool names.' "$rigTmp/brief" )" 1

echo "-- 5. under no heading of its own; no member is told where it came from --"
rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-own" > /dev/null
rigAssert "no heading was added"                                   "$( LC_ALL=C grep -c '^## ' "$rigTmp/brief" )" "$rigPlainHeadings"
rigAssert "the dispatch is the plain one and the line: two lines more (a blank, the line)" "$(( $( wc -l < "$rigTmp/brief" | tr -d ' ' ) - rigPlainLines ))" 2
rigAssert "the preset is named nowhere in it"                      "$( LC_ALL=C grep -c -e 'rig-own' -e 'rig-base' -e 'preset' "$rigTmp/brief" )" 0

echo "-- 6. not in the sandbox's input/ --"
rigAssert "no file but the recorded dispatch and the preset blocks holds the line"  "$( LC_ALL=C grep -rl -F -e 'RIG-OWN-LINE' "$rigTmp" 2> /dev/null | LC_ALL=C grep -v -e "^$rigAgents/" -e "^$rigTmp/brief$" | tr '\n' ' ' )" ""

echo "-- 7. a preset with no line adds nothing; one that is not there adds none --"
rigOut="$( rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-plain" )"
rigAssert "a preset with no line: the dispatch is the plain one" "$( wc -l < "$rigTmp/brief" | tr -d ' ' )" "$rigPlainLines"
rigOut="$( rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-nothing" )"
rigAssert "a preset that is not there adds no line: the dispatch is the plain one"  "$( wc -l < "$rigTmp/brief" | tr -d ' ' )" "$rigPlainLines"

echo "-- 8. read in the workspace that pays --"
rigOut="$( rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-paid" "payer" )"
rigAssert "the launch succeeded"                                  "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "the preset of the paying workspace gives its line"      "$( LC_ALL=C grep -c -x -F -- 'RIG-PAYER-LINE only the payer holds this.' "$rigTmp/brief" )" 1
rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-paid" > /dev/null
rigAssert "and the spawning workspace, where it pays itself, has no such preset" "$( rigCount 'RIG-PAYER-LINE' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PRESET SPAWN LINE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PRESET_SPAWN_LINE: OK (%d assertions, offline)\n' "$rigPassCount"
