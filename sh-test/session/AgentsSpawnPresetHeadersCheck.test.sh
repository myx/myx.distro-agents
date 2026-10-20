#!/usr/bin/env bash
## Behavioural check on the two headers a new run record carries for what it cost and on whose key (F11.4 of the refactorings epic, Settled
## 2026-10-20: "Each new run record carries `preset:` and `credential:`: the name of the preset scope that holds the key and the key's
## setting name, never a value"). The preset the spawner chose for the spawn, `<preset>[:<effort>]` (F10.2), is `preset:`; the scope of the
## preset chain that holds the credential of the preset's CLI service, after the extends, with the key's name, is `credential:`, so that
## presets sharing one key group together. A record that has neither says neither.
## Held, against the proxy with a console stand-in:
##   1. a spawn with no preset chosen: neither header
##   2. a preset that holds the key: both, the credential as `preset-<name>/<KEY>`; the value is nowhere but the preset's own file
##   3. an extension that holds none: its own `preset:` (with the effort), the credential of the preset it extends: they group together
##   4. an extension that holds a key of its own: its own scope
##   5. a preset whose chain holds no key: `preset:` alone
##   6. a preset of the workspace that pays: read there
## Offline: a fake console, a fake curl that answers Slack; every run an `env -i` child.
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
rigTmp="$( rigTempDir AgentsSpawnPresetHeadersCheck )" || exit 1
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
## The presets of the rig. rig-key holds the key of the claude service; rig-ext extends it and holds none; rig-own extends it and holds a key of its own;
## rig-bare holds none and extends nothing. The values are secrets of the rig: they must be printed nowhere.
rigSecretKey="rig-secret-KEY-7731"
rigSecretOwn="rig-secret-OWN-5520"
rigSecretPaid="rig-secret-PAID-9148"
rigAgents="$rigWs/.local/.agents"
printf 'PRESET_CLI_SERVICE=claude\nANTHROPIC_API_KEY=%s\n' "$rigSecretKey" > "$rigAgents/preset-rig-key.agent.env"
printf 'PRESET_EXTEND=rig-key\nPRESET_MODEL_OR_MACRO=low\n' > "$rigAgents/preset-rig-ext.agent.env"
printf 'PRESET_EXTEND=rig-key\nANTHROPIC_API_KEY=%s\n' "$rigSecretOwn" > "$rigAgents/preset-rig-own.agent.env"
printf 'PRESET_CLI_SERVICE=claude\n' > "$rigAgents/preset-rig-bare.agent.env"
printf 'PRESET_CLI_SERVICE=claude\nCLAUDE_CODE_OAUTH_TOKEN=%s\n' "$rigSecretPaid" > "$rigPayer/.local/.agents/preset-rig-paid.agent.env"
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
rigSpawn(){ ## content, member, the tier setting of the team (may be empty), the workspace that pays (may be empty)
	: > "$rigTmp/brief"
	rm -rf "$rigWs/.local/agents/spawned"
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
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$1" --dispatch-doc:none --wait --context rig-spawn-headers ${2:+--spawn-settings-workspace "$2"}
		' rig-spawn "$2" "${4:-}" <<< "$1" 2>&1
}
rigRecord(){ ## -- the run record the last spawn made
	ls -t "$rigWs"/.local/agents/spawned/*/*.md 2> /dev/null | head -1
}
rigHeader(){ ## header -- its value in the run record, or `-` where it has none
	local headerFile headerValue
	headerFile="$( rigRecord )"
	[ -n "$headerFile" ] || { printf 'no-record' ; return 0 ; }
	headerValue="$( LC_ALL=C awk -v wantField="$1" 'NR == 1 && $0 != "---" { exit } $0 == "---" { dashes++ ; if (dashes == 2) exit ; next } index($0, wantField ": ") == 1 { print substr($0, length(wantField) + 3) ; exit }' "$headerFile" )"
	printf '%s' "${headerValue:--}"
}
rigSecrets(){ ## -- how many files of the rig, but the preset files themselves, hold a secret value
	LC_ALL=C grep -rl -F -e "$rigSecretKey" -e "$rigSecretOwn" -e "$rigSecretPaid" "$rigTmp" 2> /dev/null | LC_ALL=C grep -v -e '/preset-[a-z-]*\.agent\.env$' -e "^$rigTmp/brief$" | LC_ALL=C grep -c . || :
}

echo "-- 1. no preset chosen: neither header --"
rigOut="$( rigSpawn "RIG-TASK-TEXT" keeper-myx "" )"
grep -q 'RIG-TASK-TEXT' "$rigTmp/brief" || rigRefuse "the fake console never received the context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "the record has no preset: and no credential:" "$( rigHeader preset ) $( rigHeader credential )" "- -"

echo "-- 2. a preset that holds the key --"
rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-key" > /dev/null
rigAssert "the preset, and the scope and the name of the key" "$( rigHeader preset ) $( rigHeader credential )" "rig-key preset-rig-key/ANTHROPIC_API_KEY"
rigAssert "the value of the key is in no file but the preset's own, and in no output" "$( rigSecrets )" "0"

echo "-- 3. an extension that holds none groups with the preset it extends --"
rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-ext:high" > /dev/null
rigAssert "its own name with the effort, the credential of rig-key" "$( rigHeader preset ) $( rigHeader credential )" "rig-ext:high preset-rig-key/ANTHROPIC_API_KEY"

echo "-- 4. an extension with a key of its own --"
rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-own" > /dev/null
rigAssert "its own scope holds the key" "$( rigHeader preset ) $( rigHeader credential )" "rig-own preset-rig-own/ANTHROPIC_API_KEY"
rigAssert "and no value is printed anywhere" "$( rigSecrets )" "0"

echo "-- 5. a chain with no key: the preset alone --"
rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-bare" > /dev/null
rigAssert "the preset, and no credential:" "$( rigHeader preset ) $( rigHeader credential )" "rig-bare -"

echo "-- 6. read in the workspace that pays --"
rigSpawn "RIG-TASK-TEXT" keeper-myx "rig-paid" "payer" > /dev/null
rigAssert "the key of the paying workspace's preset, the second name of the service" "$( rigHeader preset ) $( rigHeader credential )" "rig-paid preset-rig-paid/CLAUDE_CODE_OAUTH_TOKEN"
rigAssert "and its value is printed nowhere" "$( rigSecrets )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN PRESET HEADERS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_PRESET_HEADERS: OK (%d assertions, offline)\n' "$rigPassCount"
