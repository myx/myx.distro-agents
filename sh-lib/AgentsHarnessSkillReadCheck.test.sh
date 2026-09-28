#!/usr/bin/env bash
## Behavioural check that every team skill file is readable through the harness tools
## the myx.distro MCP serves -- Read by path under $HOME/.claude/skills, and Skill by
## name in both forms, `<member>` and `<member>/<file>` -- and that a root set which
## cannot be computed is refused with its reason: by the harness on stdout, the only
## stream an MCP caller sees, and by the console before it starts a harness leg. AgentsHarnessAccessRootsCheck.test.sh asks where the set comes from;
## this asks whether the skills are inside it.
##
## Why it exists. A member folder under $HOME/.claude/skills is a symlink into the tree
## that owns it, and Read resolves a path before matching it, so the granted skills
## directory never covered a member file: whether one read at all depended on the
## process having resolved a skillset root that happened to hold that member.
##
## Offline and unmetered: --intern-tool reaches no endpoint and needs no credential.
## HOME and MMDAPP are this rig's own fixtures, so no file of the real machine is read.
##
## Red recipe, run: drop the `$HOME/.claude/skills"/*/` walk from
## AgentsToolsClientAccessRootsMembers, or the `*/*)` split from AgentsHarnessToolSkill,
## or the status capture around AgentsToolsClientAccessRoots in the harness or in
## AgentsConsoleShellScript.template.sh.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

export MDLT_ORIGIN="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigHarness="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"

rigTmp="$( mktemp -d -t AgentsHarnessSkillReadCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The shape of this machine: members live in their owning trees and are linked into
## $HOME/.claude/skills, while this workspace resolved its own skillset, which holds
## none of them. No permissions registry, so no declared grant covers them either.
mkdir -p "$rigTmp/home/.claude/skills" "$rigTmp/ws/source" "$rigTmp/ws/.claude/skills" \
	"$rigTmp/owners/rig-keeper" "$rigTmp/owners/magic-team" "$rigTmp/OUTSIDE"
printf 'rig-keeper-boot\n' > "$rigTmp/owners/rig-keeper/SKILL.md"
printf 'rig-keeper-armed\n' > "$rigTmp/owners/rig-keeper/rig-keeper.armed.md"
printf 'rig-team-armed\n' > "$rigTmp/owners/magic-team/magic-team.armed.md"
printf 'rig-outside\n' > "$rigTmp/OUTSIDE/secret.txt"
ln -s "$rigTmp/owners/rig-keeper" "$rigTmp/home/.claude/skills/rig-keeper"
ln -s "$rigTmp/owners/magic-team" "$rigTmp/home/.claude/skills/magic-team"

export HARNESS_PROVIDER_NAME="skill-read check rig"
export HARNESS_SELF_NAME="AgentsHarnessSkillReadCheck.test.sh"
export HARNESS_ENDPOINT="https://harness-skill-read-check.invalid/v1/chat/completions"
export HARNESS_HOST="harness-skill-read-check.invalid"
export HARNESS_WIRE="OpenAiChat"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"

## One tool call through the real core, as the MCP server makes it: no root flag, so
## the set comes from the package's own mechanism. stdout only, which is what the
## server returns. A refused call exits non-zero by design, so only silence is a fault.
rigCall(){ ## tool, argument object
	local rigOut
	rigOut="$( printf '%s' "$2" | HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigTmp/ws/.claude/skills" \
		"$rigHarness" --intern-tool "$1" 2>/dev/null )" || :
	[ -n "$rigOut" ] || rigRefuse "no output from $1 $2, so the tool was never exercised"
	case "$rigOut" in
		*'could not be computed'*CLIENT_ACCESS_ROOTS_EXTRA*) printf 'refused-with-reason' ;;
		*'not in the allowed access-root set'*)              printf 'refused-not-granted' ;;
		*rig-keeper-armed*)                                  printf 'read-armed' ;;
		*rig-keeper-boot*)                                   printf 'read-boot' ;;
		*rig-team-armed*)                                    printf 'read-team' ;;
		*rig-outside*)                                       printf 'read-outside' ;;
		*)                                                   printf 'other' ;;
	esac
}

rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFails=$(( rigFails + 1 ))
	fi
}

echo "-- Read by path under \$HOME/.claude/skills, no root flag --"
rigAssert "a member typed file is readable" \
	"$( rigCall Read "{\"path\":\"$rigTmp/home/.claude/skills/rig-keeper/rig-keeper.armed.md\"}" )" "read-armed"
rigAssert "a magic-team shared file is readable" \
	"$( rigCall Read "{\"path\":\"$rigTmp/home/.claude/skills/magic-team/magic-team.armed.md\"}" )" "read-team"
## The control that can return zero: a core that admits everything passes both above.
rigAssert "a path outside every root is still refused" \
	"$( rigCall Read "{\"path\":\"$rigTmp/OUTSIDE/secret.txt\"}" )" "refused-not-granted"

echo "-- Skill by name, both forms --"
rigAssert "Skill <member> reads its SKILL.md" \
	"$( rigCall Skill '{"name":"rig-keeper"}' )" "read-boot"
rigAssert "Skill <member>/<file> reads that file" \
	"$( rigCall Skill '{"name":"magic-team/magic-team.armed.md"}' )" "read-team"
rigAssert "Skill <member>/<file> steps out of no folder" \
	"$( rigCall Skill '{"name":"rig-keeper/../../OUTSIDE/secret.txt"}' )" "other"

## The console computes the same set for a harness leg before it starts one. Its own
## origin is this rig's, named in the fixture workspace's settings. No HARNESS_* and no
## provider credential reach it, so a spawn that got past the roots stops at the
## credential gate and never reaches a host; the roots line it prints first is the verdict.
rigConsole(){
	local rigOut
	rigOut="$(
		unset HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST HARNESS_WIRE \
			HARNESS_CREDENTIAL_NAMES HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_MAIN \
			SCALEWAY_DEEPSEEK SCALEWAY_GEMMA
		HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigTmp/ws/.claude/skills" \
			bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsConsoleShellScript.template.sh" \
			--cli scaleway --non-interactive RIG-PROMPT 2>&1 < /dev/null
	)" || :
	[ -n "$rigOut" ] || rigRefuse "no output from the console, so its root resolution was never exercised"
	case "$rigOut" in
		*'could not be computed'*CLIENT_ACCESS_ROOTS_EXTRA*) printf 'refused-with-reason' ;;
		*'# console: scaleway access roots:'*)               printf 'roots-resolved' ;;
		*)                                                   printf 'other' ;;
	esac
}

echo "-- the console resolves the same set for a harness leg --"
## The control that can return zero for the refusal asserted below.
mkdir -p "$rigTmp/ws/.local"
printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigTmp/ws/.local/MDLT.settings.env"
rigAssert "the console resolves the set when it can be computed" "$( rigConsole )" "roots-resolved"

echo "-- a set that cannot be computed is refused, with its reason --"
## The config store is present and the name that reads it fails: the producer refuses.
mkdir -p "$rigTmp/ws/.local/.agents"
printf 'CLIENT_ACCESS_ROOTS_EXTRA=/rig\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
DistroAgentsTools(){ return 7 ; }
export -f DistroAgentsTools
rigAssert "Read names why the set is missing, on stdout" \
	"$( rigCall Read "{\"path\":\"$rigTmp/home/.claude/skills/rig-keeper/rig-keeper.armed.md\"}" )" "refused-with-reason"
rigAssert "the console refuses the spawn and names why" "$( rigConsole )" "refused-with-reason"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SKILL READ CHECK FAILED: $rigFails assertion(s)" >&2
	echo "  warn: a team skill file is not readable through the MCP-served tools, or an" >&2
	echo "        access-root set that could not be computed was used silently" >&2
	echo "  fix:  repair sh-lib/AgentsTools.ClientAccessRoots.include or the Read/Skill" >&2
	echo "        tools in sh-lib/AgentsUniversalHarness.sh, or the root capture in" >&2
	echo "        sh-lib/AgentsConsoleShellScript.template.sh -- never the assertion" >&2
	exit 1
fi
echo "HARNESS_SKILL_READ: OK (skills by path and by name, outside refused, failure named by harness and console, offline)"