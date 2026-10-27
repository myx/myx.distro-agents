#!/usr/bin/env bash
## Behavioural check on WHICH SCOPE a CLI service's credential is written in and read
## from by the owner setup, run rather than read, against scenario workspaces built
## here -- no file of the real workspace is read or written, and no host is reached.
##
## Held:
##   A. --owner-setup-deepseek --apply writes DEEPSEEK_API_KEY into preset-deepseek,
##      the preset of its CLI service, and the team scope holds no DEEPSEEK_API_KEY
##      afterwards; the preset carries PRESET_CLI_SERVICE=deepseek once, and the spawn
##      path's own reader answers the key from there
##   B. the read side reads the same place: --check says the credential is OK with it
##      in the preset and FAIL with it only in magic-team, its remedy names
##      preset-deepseek, and a fresh --check writes no file at all
##   C. the preset is made once and never overwritten: a second apply with the same
##      value changes no byte of it, a new value replaces the key in place, and the
##      team scope still holds no credential
##   D. an existing preset with a key and other keys of its own is left intact by an
##      apply that changes nothing, and keeps those keys when a value does change
##   E. the preset writer takes the key in the preset of the service it names, takes
##      deepseek as a CLI service beside the other nine, and still refuses a word that
##      is no service
##   F. the same move holds mechanically for grok and copilot, whose credentials are
##      in preset-grok and preset-copilot and in no team scope
##
## RED RECIPE (live, before this change) -- every cause is the same scope defect, seen
## from the write side, the read side and the service list; none is a fault of the rig.
## Keep a pristine copy of the live package as a rig origin and run THIS file, from the
## patched package, against it:
##   mkdir -p <pristine>/myx
##   cp -R <live>/myx.distro-agents <pristine>/myx/myx.distro-agents
##   ln -s <live>/myx.distro-.local <live>/myx.distro-system <pristine>/myx/
##   MMDAPP=<scratch workspace> MDLT_ORIGIN=<pristine> \
##     bash <patched>/myx.distro-agents/sh-test/config/AgentsOwnerSetupCredentialScopeCheck.test.sh
## Expected red, 30 of 52 assertions, in four groups:
##   - A stops at "the deepseek setup applies and ends 0" (got 1, want 0): the deepseek
##     option is in no catalogue row, so the settings step refuses before writing, and
##     every A/C/D assertion that wants the key in preset-deepseek fails with nothing
##     stored at all;
##   - E stops at "deepseek is a CLI service a preset may name" (got 1, want 0):
##     AgentsTools.Preset.include's service list has no deepseek, so a preset cannot
##     name it, and its credential is refused with it;
##   - F's grok apply ends 1 and its key lands in magic-team (preset-grok, wanted, holds
##     none); copilot stores its token there too, and both "not in the team scope"
##     assertions fail -- the write side of the defect;
##   - B fails because the check reads magic-team: with the key in preset-deepseek the
##     check says FAIL, and its remedy names magic-team instead of preset-deepseek.
##
## Offline: a private origin, a scratch workspace and HOME, stub myx.common and
## myx.distro-source of the rig's own, and no network and no credential.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigLocalContext="$rigOrigin/myx/myx.distro-.local/sh-lib/LocalContext.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
[ -f "$rigLocalContext" ] || rigRefuse "myx.distro-.local is not beside the package at the origin: $rigLocalContext"
[ -d "$rigOrigin/myx/myx.distro-system" ] || rigRefuse "myx.distro-system is not beside the package at the origin"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOwnerSetupCredentialScopeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The origin every call in this rig runs from: the package under test by link, the two
## siblings it needs by link, and a minimal myx.distro-source. The source scan is not
## this check's subject, and a sandbox may carry no source package; the stub makes the
## integrations step end 0 with no project instead of depending on the origin's shape.
rigToolOrigin="$rigTmp/origin"
mkdir -p "$rigToolOrigin/myx"
ln -s "$rigPackage" "$rigToolOrigin/myx/myx.distro-agents"
ln -s "$rigOrigin/myx/myx.distro-system" "$rigToolOrigin/myx/myx.distro-system"
ln -s "$rigOrigin/myx/myx.distro-.local" "$rigToolOrigin/myx/myx.distro-.local"
rigSourceStub="$rigToolOrigin/myx/myx.distro-source"
mkdir -p "$rigSourceStub/sh-scripts" "$rigSourceStub/sh-lib/source-prepare"
cat > "$rigSourceStub/sh-scripts/DistroSourceTools.fn.sh" <<'SH'
#!/usr/bin/env bash
ListDistroProjects(){ return 0 ; }
ListDistroDeclares(){ return 0 ; }
ListDistroNamespaces(){ return 0 ; }
DistroSourceTools(){ return 0 ; }
SH
printf '# a rig source scan: no project\nreturn 0\n' > "$rigSourceStub/sh-lib/source-prepare/ScanSourceProjects.include"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## text, needle -- yes where the text holds the needle
	case "$1" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
}
rigCount(){ ## file, fixed line -- how many lines of that file are exactly that line
	[ -f "$1" ] || { printf '0' ; return 0 ; }
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigPrefixCount(){ ## file, prefix -- how many lines of that file start with it
	[ -f "$1" ] || { printf '0' ; return 0 ; }
	LC_ALL=C grep -c -e "^$2" "$1" 2> /dev/null || :
}
rigCksum(){ ## file -- its checksum, or no-file
	[ -f "$1" ] && cksum < "$1" || printf 'no-file\n'
}

## A scenario workspace: its own HOME, the empty source folder the integrations step
## scans, the three packages by link at the private origin, and a myx.common of the
## rig's own carrying only what the integrations step runs -- the MCP server script,
## the home setup and the JSON escaper. Nothing of the machine's own myx.common is read.
rigSerial=0
rigMakeWs(){ ## -- sets rigWs and rigHome
	rigSerial=$(( rigSerial + 1 ))
	rigWs="$rigTmp/ws$rigSerial" ; rigHome="$rigTmp/home$rigSerial"
	mkdir -p "$rigWs/.local/myx" "$rigWs/.local/.agents" "$rigWs/source" "$rigHome"
	local linkName
	for linkName in myx.distro-agents myx.distro-system myx.distro-.local myx.distro-source ; do
		ln -s "$rigToolOrigin/myx/$linkName" "$rigWs/.local/myx/$linkName" || rigRefuse "cannot link $linkName into the rig workspace"
	done
	rigMcpRoot="$rigWs/.local/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
	mkdir -p "$rigMcpRoot/bin/lib" "$rigMcpRoot/bin/setup" "$rigMcpRoot/include/data"
	printf '#!/usr/bin/env bash\nexit 0\n' > "$rigMcpRoot/bin/lib/agentMcpServer.Common"
	printf '#!/usr/bin/env bash\nprintf "{}\\n" > "${HOME:?}/.claude.json"\nexit 0\n' > "$rigMcpRoot/bin/setup/agentMcp.Common"
	chmod +x "$rigMcpRoot/bin/lib/agentMcpServer.Common" "$rigMcpRoot/bin/setup/agentMcp.Common"
	cat > "$rigMcpRoot/include/data/agentMcpJsonEscape.awk" <<'AWK'
BEGIN { ORS = "" }
{
	gsub(/\\/, "\\\\")
	gsub(/"/, "\\\"")
	printf "%s", $0
}
AWK
	rigAgents="$rigWs/.local/.agents"
}

rigRc=0
: > "$rigTmp/all.out"
rigRun(){ ## arguments of the dispatcher -- the scene's workspace, home and PATH alone
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDAT_WORKSPACE_MODE=team-rig \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigToolOrigin" MDLT_OPTION="--run-from-path $rigToolOrigin" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null
	rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" > "$rigTmp/all"
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all.out"
}
## The reader that ANSWERS a credential on purpose (the console asks it for the value), so
## its answer is kept out of the leak log: a whole value there is the read working, not a
## diagnostic echoing a secret. Every other call's output is in that log.
rigRunValue(){
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDAT_WORKSPACE_MODE=team-rig \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigToolOrigin" MDLT_OPTION="--run-from-path $rigToolOrigin" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null
	rigRc=$?
}
rigRunStdin(){ ## value, arguments of the dispatcher -- the value on stdin
	local stdinValue="$1" ; shift
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDAT_WORKSPACE_MODE=team-rig \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigToolOrigin" MDLT_OPTION="--run-from-path $rigToolOrigin" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "$stdinValue"
	rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" > "$rigTmp/all"
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all.out"
}
rigSet(){ ## preset, key, value -- the rc of the write
	rigRun --agents-config-option "preset-$1" --upsert "$2" "$3" ; printf '%s' "$rigRc"
}
rigSetStdin(){ ## preset, key, value -- the rc of the write, the value on stdin
	rigRunStdin "$3" --agents-config-option "preset-$1" --upsert-from-stdin "$2" ; printf '%s' "$rigRc"
}
rigSelect(){ ## scope, key -- what the tooling's reader answers
	rigRunValue --agents-config-option "$1" --select "$2" ; cat "$rigTmp/out"
}
rigHolder(){ ## workspace, preset spec -- what the spawn path records as the credential's holder
	( cd "$1" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$1" MDLT_ORIGIN="$rigToolOrigin" MDSC_CMD=rig-check \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Preset.include" && AgentsToolsPresetCredentialHolder "$MMDAPP" "$1"' rig "$2" ) 2> /dev/null
}

## The rig's own secrets: made here, never read from anywhere, and never printed by
## this check -- the assertions that touch them count lines or compare to `same`.
rigKeyA="sk-RIGantDEEPSEEKscopeQw7ZpL3x"
rigKeyB="sk-RIGantDEEPSEEKscopeRc4Nm8Vb"
rigKeyOld="sk-RIGexistingPresetKept9Hs"
rigXaiKey="xai-RIGgrokScopeTgHn0Lc"
rigCopilotKey="ghp_RIGcopilotScopeQz8wVu3"
rigAnthropicKey="sk-ant-RIGclaudeScopeK2pRf6"
rigOauthKey="oauth-RIGclaudeScopeD1sNv7"

echo "-- A. the setup writes the credential into the service's preset, and the team scope holds none --"
rigMakeWs
rigWsA="$rigWs" ; rigHomeA="$rigHome"
rigRunStdin "DEEPSEEK_API_KEY=$rigKeyA" --owner-setup-deepseek --values-from-stdin --apply
rigAssert "the deepseek setup applies and ends 0"                                  "$rigRc" 0
rigAssert "and says it set DEEPSEEK_API_KEY, with no error"                        "$( rigHolds "$( cat "$rigTmp/all" )" 'DEEPSEEK_API_KEY set in' ):$( rigHolds "$( cat "$rigTmp/all" )" 'ERROR' )" "yes:no"
rigAssert "the preset of the CLI service was made"                                "$( [ -f "$rigAgents/preset-deepseek.agent.env" ] && printf yes || printf no )" yes
rigAssert "it names its CLI service, once"                                        "$( rigCount "$rigAgents/preset-deepseek.agent.env" 'PRESET_CLI_SERVICE=deepseek' )" 1
rigAssert "and holds the credential"                                              "$( rigCount "$rigAgents/preset-deepseek.agent.env" "DEEPSEEK_API_KEY=$rigKeyA" )" 1
rigAssert "the team scope holds no DEEPSEEK_API_KEY"                              "$( rigPrefixCount "$rigAgents/magic-team.agent.env" 'DEEPSEEK_API_KEY=' )" 0
rigAssert "while it keeps the spawn setting that is not a credential"             "$( rigCount "$rigAgents/magic-team.agent.env" 'SPAWN_TIER_NORMAL=deepseek' )" 1
rigAssert "the spawn path, asked of the team scope, answers the key from the preset" "$( [ "$( rigSelect magic-team DEEPSEEK_API_KEY )" = "$rigKeyA" ] && printf same || printf other )" same
rigAssert "the holder the run record reads is preset-deepseek's"                  "$( rigHolder "$rigWsA" deepseek )" "preset-deepseek/DEEPSEEK_API_KEY"

echo "-- B. the check reads the same place, and writes nothing --"
rigRun --owner-setup-deepseek --check
rigAssert "with the key in the preset, --check ends 0"                            "$rigRc" 0
rigAssert "the key is found, and the credential is OK"                            "$( rigHolds "$( cat "$rigTmp/all" )" 'DEEPSEEK_API_KEY: OK' ):$( rigHolds "$( cat "$rigTmp/all" )" 'DEEPSEEK_CREDENTIAL: OK' )" "yes:yes"
rigMakeWs
rigRun --owner-setup-deepseek --check
rigAssert "on a fresh workspace, --check ends non-zero"                           "$( [ "$rigRc" != 0 ] && printf yes || printf no )" yes
rigAssert "and says the credential is not set"                                    "$( rigHolds "$( cat "$rigTmp/all" )" 'DEEPSEEK_CREDENTIAL: FAIL' )" yes
rigAssert "and it made no file at all: a check writes nothing"                    "$( ls "$rigAgents" 2> /dev/null | wc -l | tr -d ' ' )" 0
printf 'SPAWN_TIER_NORMAL=deepseek\nDEEPSEEK_API_KEY=%s\n' "$rigKeyA" > "$rigAgents/magic-team.agent.env"
printf 'PRESET_CLI_SERVICE=deepseek\n' > "$rigAgents/preset-deepseek.agent.env"
rigRun --owner-setup-deepseek --check
rigAssert "a key in magic-team alone is not the credential: --check fails"         "$( [ "$rigRc" != 0 ] && printf yes || printf no )" yes
rigAssert "and its remedy names the preset scope"                                 "$( rigHolds "$( cat "$rigTmp/all" )" 'preset-deepseek --upsert-from-stdin DEEPSEEK_API_KEY' )" yes
printf 'PRESET_CLI_SERVICE=deepseek\nDEEPSEEK_API_KEY=%s\n' "$rigKeyA" > "$rigAgents/preset-deepseek.agent.env"
rigRun --owner-setup-deepseek --check
rigAssert "the same call with it in the preset ends 0"                            "$rigRc" 0
rigAssert "and the spawn path answers nothing for a team-scope-only key"          "$( printf 'PRESET_CLI_SERVICE=deepseek\n' > "$rigAgents/preset-deepseek.agent.env" ; [ -z "$( rigSelect magic-team DEEPSEEK_API_KEY )" ] && printf empty || printf answered )" empty

echo "-- C. made once, and never overwritten --"
rigWs="$rigWsA" ; rigHome="$rigHomeA" ; rigAgents="$rigWsA/.local/.agents"
rigCksumA="$( rigCksum "$rigAgents/preset-deepseek.agent.env" )"
rigRunStdin "DEEPSEEK_API_KEY=$rigKeyA" --owner-setup-deepseek --values-from-stdin --apply
rigAssert "a second apply with the same value ends 0"                             "$rigRc" 0
rigAssert "reports it already set"                                                "$( rigHolds "$( cat "$rigTmp/all" )" 'DEEPSEEK_API_KEY already set' )" yes
rigAssert "and changed no byte of the preset"                                     "$( rigCksum "$rigAgents/preset-deepseek.agent.env" )" "$rigCksumA"
rigAssert "the preset still names its service once"                               "$( rigCount "$rigAgents/preset-deepseek.agent.env" 'PRESET_CLI_SERVICE=deepseek' )" 1
rigRunStdin "DEEPSEEK_API_KEY=$rigKeyB" --owner-setup-deepseek --values-from-stdin --apply
rigAssert "a new value replaces the key, once"                                    "$( rigCount "$rigAgents/preset-deepseek.agent.env" "DEEPSEEK_API_KEY=$rigKeyB" )" 1
rigAssert "the old value is gone"                                                 "$( rigCount "$rigAgents/preset-deepseek.agent.env" "DEEPSEEK_API_KEY=$rigKeyA" )" 0
rigAssert "the preset's service was not made a second time"                       "$( rigCount "$rigAgents/preset-deepseek.agent.env" 'PRESET_CLI_SERVICE=deepseek' )" 1
rigAssert "and the team scope still holds no key"                                 "$( rigPrefixCount "$rigAgents/magic-team.agent.env" 'DEEPSEEK_API_KEY=' )" 0

echo "-- D. an existing preset is left intact --"
rigMakeWs
rigWsD="$rigWs" ; rigHomeD="$rigHome"
printf 'PRESET_CLI_SERVICE=deepseek\nPRESET_MODEL_OR_MACRO=normal\nPRESET_ENDPOINT_URL=https://api.deepseek.com/v1/chat/completions\nDEEPSEEK_API_KEY=%s\n' "$rigKeyOld" > "$rigAgents/preset-deepseek.agent.env"
printf 'SPAWN_HARNESS_TIER=heavy\n' > "$rigAgents/magic-team.agent.env"
rigCksumD="$( rigCksum "$rigAgents/preset-deepseek.agent.env" )"
rigRun --owner-setup-deepseek --apply
rigAssert "an apply that supplies no value ends 0"                                "$rigRc" 0
rigAssert "and leaves the existing preset byte for byte"                          "$( rigCksum "$rigAgents/preset-deepseek.agent.env" )" "$rigCksumD"
rigAssert "the team's other spawn setting is kept"                                "$( rigCount "$rigAgents/magic-team.agent.env" 'SPAWN_HARNESS_TIER=heavy' )" 1
rigAssert "and no credential was written into the team scope"                     "$( rigPrefixCount "$rigAgents/magic-team.agent.env" 'DEEPSEEK_API_KEY=' )" 0
rigRunStdin "DEEPSEEK_API_KEY=$rigKeyOld" --owner-setup-deepseek --values-from-stdin --apply
rigAssert "an apply with the value already stored reports it and changes nothing" "$( rigHolds "$( cat "$rigTmp/all" )" 'DEEPSEEK_API_KEY already set' ):$( rigCksum "$rigAgents/preset-deepseek.agent.env" )" "yes:$rigCksumD"
rigRunStdin "DEEPSEEK_API_KEY=$rigKeyB" --owner-setup-deepseek --values-from-stdin --apply
rigAssert "a changed value is written, and the preset's other keys stand"         "$( rigCount "$rigAgents/preset-deepseek.agent.env" "DEEPSEEK_API_KEY=$rigKeyB" ):$( rigCount "$rigAgents/preset-deepseek.agent.env" 'PRESET_MODEL_OR_MACRO=normal' ):$( rigCount "$rigAgents/preset-deepseek.agent.env" 'PRESET_ENDPOINT_URL=https://api.deepseek.com/v1/chat/completions' )" "1:1:1"
rigAssert "its service is still named once"                                       "$( rigCount "$rigAgents/preset-deepseek.agent.env" 'PRESET_CLI_SERVICE=deepseek' )" 1

echo "-- E. the preset writer takes deepseek, and each service's own credential in its preset --"
rigMakeWs
rigAssert "deepseek is a CLI service a preset may name"                            "$( rigSet svc-deepseek PRESET_CLI_SERVICE deepseek )" 0
rigAssert "the services a preset may name are all taken, deepseek among them"      "$( rigList="" ; for rigService in claude copilot grok gemini scaleway standard-v1 deepseek local claude-native copilot-native grok-native ; do rigList="$rigList$( rigSet "svc-$rigService" PRESET_CLI_SERVICE "$rigService" )" ; done ; printf '%s' "$rigList" )" "00000000000"
rigAssert "a word that is no service is still refused"                            "$( rigSet svc-chatgpt PRESET_CLI_SERVICE chatgpt )" 1
rigAssert "a deepseek credential is taken in the preset that names deepseek"       "$( rigSetStdin svc-deepseek DEEPSEEK_API_KEY "$rigKeyA" )" 0
rigAssert "and is stored whole"                                                   "$( rigCount "$rigAgents/preset-svc-deepseek.agent.env" "DEEPSEEK_API_KEY=$rigKeyA" )" 1
rigAssert "claude: either of its two keys is taken in preset-claude"              "$( [ "$( rigSet svc-claude PRESET_CLI_SERVICE claude )" = 0 ] && [ "$( rigSetStdin svc-claude ANTHROPIC_API_KEY "$rigAnthropicKey" )" = 0 ] && [ "$( rigSetStdin svc-claude CLAUDE_CODE_OAUTH_TOKEN "$rigOauthKey" )" = 0 ] && printf taken || printf refused )" taken
rigAssert "copilot's token is taken in preset-copilot"                            "$( [ "$( rigSet svc-copilot PRESET_CLI_SERVICE copilot )" = 0 ] && [ "$( rigSetStdin svc-copilot COPILOT_GITHUB_TOKEN "$rigCopilotKey" )" = 0 ] && printf taken || printf refused )" taken
rigAssert "grok's key is taken in preset-grok"                                    "$( [ "$( rigSet svc-grok PRESET_CLI_SERVICE grok )" = 0 ] && [ "$( rigSetStdin svc-grok XAI_API_KEY "$rigXaiKey" )" = 0 ] && printf taken || printf refused )" taken

echo "-- F. the same move holds for another service, end to end --"
rigMakeWs
rigRunStdin "XAI_API_KEY=$rigXaiKey" --owner-setup-grok --values-from-stdin --apply
rigAssert "grok applies and ends 0"                                               "$rigRc" 0
rigAssert "its key is in preset-grok"                                             "$( rigCount "$rigAgents/preset-grok.agent.env" "XAI_API_KEY=$rigXaiKey" )" 1
rigAssert "and not in the team scope"                                             "$( rigPrefixCount "$rigAgents/magic-team.agent.env" 'XAI_API_KEY=' )" 0
rigAssert "while the team keeps the spawn setting"                                "$( rigCount "$rigAgents/magic-team.agent.env" 'SPAWN_TIER_NORMAL=grok' )" 1
rigRun --owner-setup-grok --check
rigAssert "grok's own check reads it there and ends 0"                            "$rigRc" 0
rigAssert "and says the credential is OK"                                         "$( rigHolds "$( cat "$rigTmp/all" )" 'GROK_CREDENTIAL: OK' )" yes
rigMakeWs
rigRunStdin "COPILOT_GITHUB_TOKEN=$rigCopilotKey" --owner-setup-copilot --values-from-stdin --apply
rigAssert "copilot applies and ends 0"                                            "$rigRc" 0
rigAssert "its token is in preset-copilot"                                        "$( rigCount "$rigAgents/preset-copilot.agent.env" "COPILOT_GITHUB_TOKEN=$rigCopilotKey" )" 1
rigAssert "and not in the team scope"                                             "$( rigPrefixCount "$rigAgents/magic-team.agent.env" 'COPILOT_GITHUB_TOKEN=' )" 0
rigRun --owner-setup-copilot --check
rigAssert "copilot's own check reads it there and ends 0"                         "$rigRc" 0

echo "-- guard: no whole credential on any stream --"
rigLeak=0
for rigSecret in "$rigKeyA" "$rigKeyB" "$rigKeyOld" "$rigXaiKey" "$rigCopilotKey" "$rigAnthropicKey" "$rigOauthKey" ; do
	rigLeak=$(( rigLeak + $( LC_ALL=C grep -c -F -- "$rigSecret" "$rigTmp/all.out" 2> /dev/null || : ) ))
done
rigAssert "none of the rig's credentials appears whole in what the calls printed" "$rigLeak" 0

if [ "$rigFailCount" -ne 0 ] ; then
	printf '\n⛔ OWNER SETUP CREDENTIAL SCOPE CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf '\nOWNER SETUP CREDENTIAL SCOPE: OK (%s assertions, offline)\n' "$rigPassCount"
exit 0
