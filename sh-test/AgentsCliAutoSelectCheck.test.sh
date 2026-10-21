#!/usr/bin/env bash
## Behavioural check on the selection of the vendor CLI that works (F13.4 of the refactorings epic), run rather than read, against a scenario
## workspace built here and stand-ins for the two vendor binaries first on PATH -- no real claude or copilot runs, no file of the real workspace
## is read or written. Held:
##   1. `--owner-setup-cli-auto` (bare and --check, read-only) asks claude-native and copilot-native of the CLIs themselves, in that order, and names the first
##      that works: claude-native where `claude` is in PATH and says somebody is signed in, copilot-native where `copilot` is in PATH and `--version` ends well
##   2. a CLI that does not work says why: not in PATH, nobody signed in, no answer, a --version that fails; one that works says so; both are always reported
##   3. neither works: the check says so and ends with a non-zero status, --apply changes nothing and ends non-zero, with the reason on standard error
##   4. --apply carries out the setup of the pick as `--owner-setup-<cli> --set-as-default --apply` -- SPAWN_CLI_SERVICE is stored by the one mechanism that stores it,
##      over a selection already made -- and a check writes nothing
##   5. nothing else is taken: another sub-operation, or a second argument, is refused
##   6. the detection is not in the spawn path: a spawn resolves SPAWN_CLI_SERVICE and scans no PATH (AgentsReviewCliResolved), and nothing of a spawn calls the check
##   7. the domain has its manual, --help-setup-cli-auto
## Offline: no host, no network, no credential.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCliAutoSelectCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigSerial=0

## One scenario: its own workspace, its own home, and the two stand-ins first on PATH, nothing of the machine's own claude or copilot behind them.
##   claude   in (signed in), out (nobody signed in), silent (answers nothing), absent (no binary)
##   copilot  ok (--version ends well), bad (--version fails), absent (no binary)
rigScene(){ ## claude mode, copilot mode -- sets rigWs, rigHome and rigBin
	rigSerial=$(( rigSerial + 1 ))
	rigWs="$rigTmp/ws$rigSerial" ; rigHome="$rigTmp/home$rigSerial" ; rigBin="$rigTmp/bin$rigSerial"
	mkdir -p "$rigWs/.local/.agents" "$rigHome" "$rigBin"
	## claude's own state file, which the setup of claude-native records the workspace's trust in and will not make
	printf '{}\n' > "$rigHome/.claude.json"
	case "$1" in
		in)     printf '#!/bin/sh\ncase "$*" in "auth status --json") printf "{\\n  \\"loggedIn\\": true\\n}\\n" ;; esac\nexit 0\n' > "$rigBin/claude" ;;
		out)    printf '#!/bin/sh\ncase "$*" in "auth status --json") printf "{\\n  \\"loggedIn\\": false\\n}\\n" ;; esac\nexit 0\n' > "$rigBin/claude" ;;
		silent) printf '#!/bin/sh\nexit 0\n' > "$rigBin/claude" ;;
	esac
	[ -f "$rigBin/claude" ] && chmod +x "$rigBin/claude"
	case "$2" in
		ok)  printf '#!/bin/sh\necho "rig copilot 1"\nexit 0\n' > "$rigBin/copilot" ;;
		bad) printf '#!/bin/sh\nexit 3\n' > "$rigBin/copilot" ;;
	esac
	[ -f "$rigBin/copilot" ] && chmod +x "$rigBin/copilot"
}
rigRun(){ ## arguments of the tool -- its output, then `rc=<status>`; the scene's workspace, home and PATH alone
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SKILLSET_ROOT HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" "$@" 2>&1 | grep -v -e '^SystemContext' -e '^AgentsContext' -e ': Working in:' ; printf 'rc=%s\n' "${PIPESTATUS[0]}" )
}
rigStored(){ ## the preset SPAWN_TIER_NORMAL of the scene's workspace names, or nothing
	LC_ALL=C sed -n 's/^SPAWN_TIER_NORMAL=//p' "$rigWs"/.local/.agents/*.env 2> /dev/null | head -1
}

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

echo "-- 1. the first of claude-native and copilot-native that works is the pick --"
rigScene in ok ; rigOut="$( rigRun --owner-setup-cli-auto --check )"
rigAssert "both work: claude-native is the pick, the check ends well"       "$( rigHolds "$rigOut" 'SPAWN_CLI_AUTO: OK' ):$( rigHolds "$rigOut" 'pick: claude-native,' ):$( rigHolds "$rigOut" 'rc=0' )" yes:yes:yes
rigAssert "and each is reported, with what was found"                       "$( rigHolds "$rigOut" 'CLAUDE_NATIVE_WORKS: OK' ):$( rigHolds "$rigOut" 'claude is installed and signed in' ):$( rigHolds "$rigOut" 'COPILOT_NATIVE_WORKS: OK' ):$( rigHolds "$rigOut" 'copilot is installed and answers --version' )" yes:yes:yes:yes
rigAssert "it says what the spawns start now, and the command that applies the pick"  "$( rigHolds "$rigOut" 'now:  the spawns start nothing' ):$( rigHolds "$rigOut" '--owner-setup-cli-auto --apply' )" yes:yes
rigAssert "a bare call is the same diagnosis"                               "$( rigRun --owner-setup-cli-auto | LC_ALL=C grep -c -e 'SPAWN_CLI_AUTO: OK' -e 'pick: claude-native,' )" 2
rigAssert "a check stores nothing"                                           "$( rigStored ):$( ls "$rigWs/.local/.agents" | wc -l | tr -d ' ' )" ":0"
rigScene out ok ; rigOut="$( rigRun --owner-setup-cli-auto --check )"
rigAssert "claude installed and nobody signed in: copilot-native is the pick, and claude-native says why not"  "$( rigHolds "$rigOut" 'CLAUDE_NATIVE_WORKS: FAIL' ):$( rigHolds "$rigOut" 'claude is installed and nobody is signed in' ):$( rigHolds "$rigOut" 'pick: copilot-native,' ):$( rigHolds "$rigOut" 'rc=0' )" yes:yes:yes:yes
rigScene silent ok ; rigOut="$( rigRun --owner-setup-cli-auto --check )"
rigAssert "claude that says nothing of a sign-in does not work: copilot-native is the pick"  "$( rigHolds "$rigOut" 'claude did not say whether anybody is signed in' ):$( rigHolds "$rigOut" 'pick: copilot-native,' )" yes:yes
rigScene absent ok ; rigOut="$( rigRun --owner-setup-cli-auto --check )"
rigAssert "no claude in PATH: copilot-native is the pick, and the reason is the binary"  "$( rigHolds "$rigOut" 'the claude binary is not in PATH' ):$( rigHolds "$rigOut" 'pick: copilot-native,' )" yes:yes
rigScene in absent ; rigOut="$( rigRun --owner-setup-cli-auto --check )"
rigAssert "claude signed in, no copilot: claude-native is the pick, and copilot-native is reported without a binary"  "$( rigHolds "$rigOut" 'pick: claude-native,' ):$( rigHolds "$rigOut" 'COPILOT_NATIVE_WORKS: FAIL' ):$( rigHolds "$rigOut" 'the copilot binary is not in PATH' )" yes:yes:yes

echo "-- 2. neither works --"
rigScene out bad ; rigOut="$( rigRun --owner-setup-cli-auto --check )"
rigAssert "nobody signed in and a copilot whose --version fails: the check says none is selected, and ends non-zero"  "$( rigHolds "$rigOut" 'SPAWN_CLI_AUTO: FAIL' ):$( rigHolds "$rigOut" 'copilot --version did not end well' ):$( rigHolds "$rigOut" 'neither claude-native nor copilot-native works' ):$( rigHolds "$rigOut" 'rc=1' )" yes:yes:yes:yes
rigScene absent absent ; rigOut="$( rigRun --owner-setup-cli-auto --check )"
rigAssert "neither binary in PATH: the same"                                 "$( rigHolds "$rigOut" 'SPAWN_CLI_AUTO: FAIL' ):$( rigHolds "$rigOut" 'rc=1' )" yes:yes
rigOut="$( rigRun --owner-setup-cli-auto --apply )"
rigAssert "--apply then changes nothing, says why on standard error and ends non-zero"  "$( rigHolds "$rigOut" 'neither claude-native nor copilot-native is installed and works' ):$( rigHolds "$rigOut" 'rc=1' ):$( rigStored ):$( ls "$rigWs/.local/.agents" | wc -l | tr -d ' ' )" yes:yes::0

echo "-- 3. --apply is the setup of the pick, over a selection already made --"
rigScene in ok
printf 'SPAWN_TIER_NORMAL=scaleway\n' > "$rigWs/.local/.agents/magic-team.agent.env" ; printf 'PRESET_CLI_SERVICE=scaleway\n' > "$rigWs/.local/.agents/preset-scaleway.agent.env"
rigOut="$( rigRun --owner-setup-cli-auto --check )"
rigAssert "the check names the selection it would replace"                  "$( rigHolds "$rigOut" 'now:  the spawns start scaleway' )" yes
rigOut="$( rigRun --owner-setup-cli-auto --apply )"
rigAssert "claude-native works: its own setup is carried out, with --set-as-default, and says it was"  "$( rigHolds "$rigOut" 'carrying out --owner-setup-claude-native --set-as-default --apply' ):$( rigHolds "$rigOut" 'the spawns start scaleway now' )" yes:yes
rigAssert "SPAWN_TIER_NORMAL is claude-native in the scene's workspace, the scaleway selection repointed"  "$( rigStored )" claude-native
rigAssert "the preset named as the CLI is made, with the CLI as its service, and the scaleway preset stands"  "$( LC_ALL=C grep -c '^PRESET_CLI_SERVICE=claude-native$' "$rigWs/.local/.agents/preset-claude-native.agent.env" ) $( LC_ALL=C grep -c '^PRESET_CLI_SERVICE=scaleway$' "$rigWs/.local/.agents/preset-scaleway.agent.env" )" "1 1"
rigAssert "and nothing is written under the old name"                       "$( LC_ALL=C grep -c '^SPAWN_CLI_SERVICE=' "$rigWs/.local/.agents/magic-team.agent.env" )" 0
rigScene absent ok
rigOut="$( rigRun --owner-setup-cli-auto --apply )"
rigAssert "only copilot works: the setup of copilot-native is carried out, and it is stored"  "$( rigHolds "$rigOut" 'carrying out --owner-setup-copilot-native --set-as-default --apply' ):$( rigStored )" yes:copilot-native

echo "-- 3b. a tier preset of the team is replaced, the preset itself is not touched --"
rigScene in ok
printf 'SPAWN_TIER_NORMAL=default\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'PRESET_CLI_SERVICE=grok\nXAI_API_KEY=xai-rigkey\n' > "$rigWs/.local/.agents/preset-default.agent.env"
rigOut="$( rigRun --owner-setup-cli-auto --check )"
rigAssert "the check shows what a spawn resolves"                           "$( rigHolds "$rigOut" 'now:  the spawns start grok' )" yes
rigOut="$( rigRun --owner-setup-cli-auto --apply )"
rigAssert "--apply points the tier at the pick: what a spawn resolves is the pick, and the preset it left is untouched"  "$( rigStored ):$( rigHolds "$rigOut" 'still resolves' ):$( LC_ALL=C grep -c '^PRESET_CLI_SERVICE=grok$' "$rigWs/.local/.agents/preset-default.agent.env" )" "claude-native:no:1"
rigScene in ok
printf 'SPAWN_TIER_NORMAL=scaleway\n' > "$rigWs/.local/.agents/magic-team.agent.env" ; printf 'PRESET_CLI_SERVICE=scaleway\n' > "$rigWs/.local/.agents/preset-scaleway.agent.env"
rigOut="$( rigRun --owner-setup-cli-auto --apply )"
rigAssert "and --apply says nothing of a preset standing ahead: what it stored is what a spawn resolves"  "$( rigHolds "$rigOut" 'still resolves' ):$( rigStored )" no:claude-native

echo "-- 4. nothing else is taken --"
rigScene in ok
rigAssert "another sub-operation is refused, and nothing is stored"        "$( rigRun --owner-setup-cli-auto --print-apply-command | LC_ALL=C grep -c 'takes --check or --apply' ):$( rigStored )" 1:
rigAssert "so is a second argument"                                         "$( rigRun --owner-setup-cli-auto --check --apply | LC_ALL=C grep -c 'takes one sub-operation' )" 1

echo "-- 5. the detection is not in the spawn path --"
rigAssert "the CLI a spawn resolves, and the spawn proxy, do not call the check or name the domain"  "$( LC_ALL=C grep -c -e 'AgentsToolsCliServiceWorks' -e 'cli-auto' -e 'agentsCliServiceAutoOrder' "$rigPackage/sh-lib/board/AgentsTools.ReviewFlow.include" "$rigPackage/sh-lib/session/AgentsTools.InternOpAgentSpawnProxy.include" | LC_ALL=C awk -F: '{ n += $NF } END { print n + 0 }' )" 0
rigAssert "the one place that asks is the setup's: the check is called from the owner include alone"  "$( LC_ALL=C grep -l 'AgentsToolsCliServiceWorks' -r "$rigPackage/sh-lib" "$rigPackage/sh-scripts" | LC_ALL=C sed "s|^$rigPackage/||" | LC_ALL=C sort | tr '\n' ' ' )" "sh-lib/config/AgentsTools.Owner.include sh-lib/harness/AgentsTools.CliService.include "

echo "-- 6. the manual --"
rigOut="$( rigRun --help-setup-cli-auto )"
rigAssert "--help-setup-cli-auto prints the manual of the domain"           "$( rigHolds "$rigOut" '--owner-setup-cli-auto [--check|--apply]' ):$( rigHolds "$rigOut" 'copilot --version' ):$( rigHolds "$rigOut" 'rc=0' )" yes:yes:yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CLI AUTO SELECT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CLI_AUTO_SELECT: OK (%d assertions, offline)\n' "$rigPassCount"
