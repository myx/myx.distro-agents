#!/usr/bin/env bash
## Behavioural check that every team skill file is readable through the harness tools
## the myx.distro MCP serves -- Read by path under $HOME/.claude/skills, and Skill by
## name in both forms, `<member>` and `<member>/<file>` -- and that a root set which
## cannot be computed is refused with its reason: by the harness on stdout, the only
## stream an MCP caller sees, and by the console before it starts a harness leg. AgentsHarnessAccessRootsCheck.test.sh asks where the set comes from;
## this asks whether the skills are inside it. It also holds Skill by `skill`, in every
## name form a client passes, rendered with `args` as Claude Code renders a skill.
##
## Why it exists. A member folder under $HOME/.claude/skills is a symlink into the tree
## that owns it, and Read resolves a path before matching it, so the granted skills
## directory never covers a member file: what makes it readable is the member being in
## the workspace's member index (AgentsTools.TeamRegistry.include), whose members/ view
## is MDAT_SKILLSET_ROOT -- every member another workspace publishes included. A member
## linked only in the vendor folder $HOME/.claude/skills is never read from there.
##
## Offline and unmetered: --intern-tool reaches no endpoint and needs no credential.
## HOME and MMDAPP are this rig's own fixtures, so no file of the real machine is read.
##
## Red recipe, run: drop the `$MDAT_SKILLSET_ROOT"/*/` walk from
## AgentsToolsClientAccessRootsMembers, or the `*/*)` split from AgentsHarnessToolSkill,
## or the status capture around AgentsToolsClientAccessRoots in the harness or in
## AgentsConsoleShellScript.template.sh, or pass only name, file, list, offset and limit
## to AgentsHarnessToolSkill from its dispatch arm.
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

## The shape of this machine: members live in their owning trees, are linked into
## $HOME/.claude/skills for the vendor clients, and reach this workspace through its
## member index view, which links them as another workspace publishes them. No
## permissions registry, so no declared grant covers them either.
rigWsSkills="$rigTmp/ws/.local/agents/members"
mkdir -p "$rigTmp/home/.claude/skills" "$rigTmp/ws/source" "$rigWsSkills" \
	"$rigTmp/owners/rig-keeper" "$rigTmp/owners/magic-team" "$rigTmp/owners/rig-vendor-only" "$rigTmp/OUTSIDE"
printf 'rig-keeper-boot\n' > "$rigTmp/owners/rig-keeper/SKILL.md"
printf 'rig-keeper-armed\n' > "$rigTmp/owners/rig-keeper/rig-keeper.armed.md"
printf 'rig-team-armed\n' > "$rigTmp/owners/magic-team/magic-team.armed.md"
printf 'rig-outside\n' > "$rigTmp/OUTSIDE/secret.txt"
ln -s "$rigTmp/owners/rig-keeper" "$rigTmp/home/.claude/skills/rig-keeper"
ln -s "$rigTmp/owners/magic-team" "$rigTmp/home/.claude/skills/magic-team"
ln -s "$rigTmp/owners/rig-keeper" "$rigWsSkills/rig-keeper"
ln -s "$rigTmp/owners/magic-team" "$rigWsSkills/magic-team"
## In the vendor folder only, as a link: ours, generated, never read back.
printf 'rig-vendor-only-boot\n' > "$rigTmp/owners/rig-vendor-only/SKILL.md"
ln -s "$rigTmp/owners/rig-vendor-only" "$rigTmp/home/.claude/skills/rig-vendor-only"
## In the vendor folder as a real folder: a skill the user or a vendor put there.
mkdir -p "$rigTmp/home/.claude/skills/rig-user-own"
printf 'rig-user-own-boot\n' > "$rigTmp/home/.claude/skills/rig-user-own/SKILL.md"

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
	rigOut="$( printf '%s' "$2" | HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigWsSkills" \
		"$rigHarness" --intern-tool "$1" 2>/dev/null )" || :
	[ -n "$rigOut" ] || rigRefuse "no output from $1 $2, so the tool was never exercised"
	case "$rigOut" in
		*'could not be computed'*)                           printf 'refused-with-reason' ;;
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

## skill as the native tool takes it: the workspace skillset, a synced skill, a synced
## plugin holding skills and a command, and a working directory holding a project skill
## plus a decoy named like the plugin, which the plugin must win over.
rigPlugin="$rigTmp/home/.claude/plugins/synced/rig-bucket/rig-plugin-dir"
mkdir -p "$rigWsSkills/rig-bare" "$rigWsSkills/rig-folder" "$rigWsSkills/rig-manual" "$rigWsSkills/rig-args" \
	"$rigWsSkills/rig-noph" "$rigWsSkills/rig-issue" "$rigTmp/home/.claude/skills/synced/rig-bucket/rig-synced" \
	"$rigPlugin/.claude-plugin" "$rigPlugin/skills/rig-ps" "$rigPlugin/skills/rig-ps-folder" "$rigPlugin/commands" \
	"$rigTmp/cwd/rig-proj/.claude/skills/rig-local" "$rigTmp/cwd/rig-plugin/.claude/skills/rig-ps"
printf '%s\n' rig-bare-one rig-bare-two > "$rigWsSkills/rig-bare/SKILL.md"
printf '%s\n' --- 'name: rig-named' --- rig-folder-body > "$rigWsSkills/rig-folder/SKILL.md"
printf '%s\n' --- 'disable-model-invocation: true' --- rig-manual-body > "$rigWsSkills/rig-manual/SKILL.md"
printf '%s\n' 'all=[$ARGUMENTS] first=[$0] second=[$ARGUMENTS[1]] esc=[\$1] dir=[${CLAUDE_SKILL_DIR}]' > "$rigWsSkills/rig-args/SKILL.md"
printf '%s\n' rig-noph-body > "$rigWsSkills/rig-noph/SKILL.md"
printf '%s\n' --- 'arguments: [issue, branch]' --- 'i=[$issue] b=[$branch] x=[$2] d=[\\$0] cost=$1.00' > "$rigWsSkills/rig-issue/SKILL.md"
printf '%s\n' rig-synced-body > "$rigTmp/home/.claude/skills/synced/rig-bucket/rig-synced/SKILL.md"
printf '%s\n' '{"name":"rig-plugin"}' > "$rigPlugin/.claude-plugin/plugin.json"
printf '%s\n' 'root=[${CLAUDE_PLUGIN_ROOT}] data=[${CLAUDE_PLUGIN_DATA}]' > "$rigPlugin/skills/rig-ps/SKILL.md"
printf '%s\n' --- 'name: rig-ps-named' --- rig-ps-folder-body > "$rigPlugin/skills/rig-ps-folder/SKILL.md"
printf '%s\n' rig-cmd-body > "$rigPlugin/commands/rig-cmd.md"
printf '%s\n' rig-local-body > "$rigTmp/cwd/rig-proj/.claude/skills/rig-local/SKILL.md"
printf '%s\n' rig-decoy-body > "$rigTmp/cwd/rig-plugin/.claude/skills/rig-ps/SKILL.md"

## The whole result, as the server returns it, from the working directory a dir:skill
## name is taken against.
rigSkill(){ ## argument object
	local rigOut
	rigOut="$( cd "$rigTmp/cwd" && printf '%s' "$1" | HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigWsSkills" \
		"$rigHarness" --intern-tool Skill 2>/dev/null )" || :
	[ -n "$rigOut" ] || rigRefuse "no output from Skill $1, so the tool was never exercised"
	printf '%s' "$rigOut"
}

echo "-- Skill by skill, every name form --"
rigAssert "Skill with neither skill nor name is refused" \
	"$( rigSkill '{}' | cut -c1-13 )" "ERROR: Skill:"
rigAssert "Skill name still reads the file raw, frontmatter and all" \
	"$( rigSkill '{"name":"rig-folder"}' )" "---"$'\n'"name: rig-named"$'\n'"---"$'\n'"rig-folder-body"
rigAssert "skill <bare> renders from the workspace skillset" \
	"$( rigSkill '{"skill":"rig-bare"}' )" "Base directory for this skill: $rigWsSkills/rig-bare"$'\n'"rig-bare-one"$'\n'"rig-bare-two"
rigAssert "skill <bare> finds a folder by its frontmatter name" \
	"$( rigSkill '{"skill":"rig-named"}' )" "Base directory for this skill: $rigWsSkills/rig-folder"$'\n'"rig-folder-body"
rigAssert "skill <bare> reads a member another workspace publishes, from the member index" \
	"$( rigSkill '{"skill":"rig-keeper"}' )" "Base directory for this skill: $rigWsSkills/rig-keeper"$'\n'"rig-keeper-boot"
rigAssert "skill <bare> never reads a link in \$HOME/.claude/skills" \
	"$( rigSkill '{"skill":"rig-vendor-only"}' | cut -c1-29 )" "ERROR: Skill: no such skill: "
rigAssert "Skill name never reads a link in \$HOME/.claude/skills" \
	"$( rigSkill '{"name":"rig-vendor-only"}' | cut -c1-36 )" "ERROR: Skill: no such skill folder: "
rigAssert "skill <bare> still reads a real folder a user put in \$HOME/.claude/skills" \
	"$( rigSkill '{"skill":"rig-user-own"}' )" "Base directory for this skill: $rigTmp/home/.claude/skills/rig-user-own"$'\n'"rig-user-own-boot"
rigAssert "skill anthropic-skills:<S> reads a synced skill" \
	"$( rigSkill '{"skill":"anthropic-skills:rig-synced"}' )" "Base directory for this skill: $rigTmp/home/.claude/skills/synced/rig-bucket/rig-synced"$'\n'"rig-synced-body"
rigAssert "skill <plugin>:<S> finds a plugin by its plugin.json name, a skill by its frontmatter name" \
	"$( rigSkill '{"skill":"rig-plugin:rig-ps-named"}' )" "Base directory for this skill: $rigPlugin/skills/rig-ps-folder"$'\n'"rig-ps-folder-body"
rigAssert "skill <plugin>:<S> reads a plugin command" \
	"$( rigSkill '{"skill":"rig-plugin:rig-cmd"}' )" "Base directory for this skill: $rigPlugin/commands"$'\n'"rig-cmd-body"
rigAssert "skill <dir>:<S> reads <dir>/.claude/skills under the working directory" \
	"$( rigSkill '{"skill":"rig-proj:rig-local"}' )" "Base directory for this skill: $rigTmp/cwd/rig-proj/.claude/skills/rig-local"$'\n'"rig-local-body"
rigAssert "skill :<S> is refused" \
	"$( rigSkill '{"skill":":rig-bare"}' )" "ERROR: Skill: skill has an empty prefix before the colon: :rig-bare"

echo "-- Skill by skill, not found in each form --"
rigAssert "skill <bare> not found" \
	"$( rigSkill '{"skill":"rig-nosuch"}' | sed 's/ -- looked for .*//' )" "ERROR: Skill: no such skill: rig-nosuch"
rigAssert "skill anthropic-skills:<S> not found" \
	"$( rigSkill '{"skill":"anthropic-skills:rig-nosuch"}' | sed 's/ -- looked for .*//' )" "ERROR: Skill: no such skill: anthropic-skills:rig-nosuch"
rigAssert "skill <plugin>:<S> not found" \
	"$( rigSkill '{"skill":"rig-plugin:rig-nosuch"}' | sed 's/ -- looked for .*//' )" "ERROR: Skill: no such skill: rig-plugin:rig-nosuch"
rigAssert "skill <dir>:<S> not found" \
	"$( rigSkill '{"skill":"rig-proj:rig-nosuch"}' | sed 's/ -- looked for .*//' )" "ERROR: Skill: no such skill: rig-proj:rig-nosuch"

echo "-- Skill by skill, disable-model-invocation --"
rigAssert "Skill name reads the file that sets it" \
	"$( rigSkill '{"name":"rig-manual"}' )" "---"$'\n'"disable-model-invocation: true"$'\n'"---"$'\n'"rig-manual-body"
rigAssert "skill refuses a skill that sets it" \
	"$( rigSkill '{"skill":"rig-manual"}' | cut -d, -f1 )" "ERROR: Skill: rig-manual sets disable-model-invocation: true"

echo "-- Skill by skill, args --"
rigAssert "args fill full, indexed and shorthand places, an escaped one stays, the skill dir expands" \
	"$( rigSkill '{"skill":"rig-args","args":"x y"}' )" "Base directory for this skill: $rigWsSkills/rig-args"$'\n'"all=[x y] first=[x] second=[y] esc=[\$1] dir=[$rigWsSkills/rig-args]"
rigAssert "args split on an unescaped space only" \
	"$( rigSkill '{"skill":"rig-args","args":"a\\ b c"}' )" "Base directory for this skill: $rigWsSkills/rig-args"$'\n'"all=[a\\ b c] first=[a b] second=[c] esc=[\$1] dir=[$rigWsSkills/rig-args]"
rigAssert "args fill named places, and a place past them stays" \
	"$( rigSkill '{"skill":"rig-issue","args":"42"}' )" "Base directory for this skill: $rigWsSkills/rig-issue"$'\n''i=[42] b=[] x=[$2] d=[\\42] cost=$1.00'
rigAssert "a skill with no place gets no ARGUMENTS line without args" \
	"$( rigSkill '{"skill":"rig-noph"}' )" "Base directory for this skill: $rigWsSkills/rig-noph"$'\n'"rig-noph-body"
rigAssert "a skill with no place gets args appended" \
	"$( rigSkill '{"skill":"rig-noph","args":"x y"}' )" "Base directory for this skill: $rigWsSkills/rig-noph"$'\n'"rig-noph-body"$'\n'$'\n'"ARGUMENTS: x y"

echo "-- Skill by skill, plugin variables --"
rigAssert "a plugin skill wins over a same-named directory, expands its root, and its data stays literal with no marketplace" \
	"$( rigSkill '{"skill":"rig-plugin:rig-ps"}' )" "Base directory for this skill: $rigPlugin/skills/rig-ps"$'\n'"root=[$rigPlugin] data=[\${CLAUDE_PLUGIN_DATA}]"
printf '%s\n' '{"marketplace_name":"rig-market"}' > "$rigTmp/home/.claude/plugins/synced/rig-bucket/rig-plugin-dir.meta.json"
rigAssert "a plugin skill expands its data once the marketplace is known" \
	"$( rigSkill '{"skill":"rig-plugin:rig-ps"}' )" "Base directory for this skill: $rigPlugin/skills/rig-ps"$'\n'"root=[$rigPlugin] data=[$rigTmp/home/.claude/plugins/data/rig-plugin-rig-market]"

echo "-- Skill by skill, paging --"
rigAssert "offset and limit page the rendered skill" \
	"$( rigSkill '{"skill":"rig-bare","offset":2,"limit":1}' )" "rig-bare-one"$'\n'"... read 1 line(s) from line 2; the file has 3 lines ..."

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
		HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigWsSkills" \
			bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsConsoleShellScript.template.sh" \
			--cli scaleway --non-interactive RIG-PROMPT 2>&1 < /dev/null
	)" || :
	[ -n "$rigOut" ] || rigRefuse "no output from the console, so its root resolution was never exercised"
	case "$rigOut" in
		*'could not be computed'*)                           printf 'refused-with-reason' ;;
		*'# console: scaleway access roots:'*)               printf 'roots-resolved' ;;
		*)                                                   printf 'other' ;;
	esac
}

echo "-- the console resolves the same set for a harness leg --"
## The control that can return zero for the refusal asserted below.
mkdir -p "$rigTmp/ws/.local"
printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigTmp/ws/.local/MDLT.settings.env"
rigAssert "the console resolves the set when it can be computed" "$( rigConsole )" "roots-resolved"

echo "-- the retired CLIENT_ACCESS_ROOTS_EXTRA is read by nothing --"
## A config store still holding it, and a tooling name that fails: the set is computed
## all the same, since nothing reads the setting any more.
mkdir -p "$rigTmp/ws/.local/.agents"
printf 'CLIENT_ACCESS_ROOTS_EXTRA=/rig\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
DistroAgentsTools(){ return 7 ; }
export -f DistroAgentsTools
rigAssert "Read is served, the stored value never read" \
	"$( rigCall Read "{\"path\":\"$rigTmp/home/.claude/skills/rig-keeper/rig-keeper.armed.md\"}" )" "read-armed"
rigAssert "the console resolves the set all the same" "$( rigConsole )" "roots-resolved"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SKILL READ CHECK FAILED: $rigFails assertion(s)" >&2
	echo "  warn: a team skill file is not readable through the MCP-served tools, or an" >&2
	echo "        access-root set that could not be computed was used silently, or a skill" >&2
	echo "        is not loaded by skill and args as the native Skill tool loads it" >&2
	echo "  fix:  repair sh-lib/AgentsTools.ClientAccessRoots.include or the Read/Skill" >&2
	echo "        tools in sh-lib/AgentsUniversalHarness.sh, or the root capture in" >&2
	echo "        sh-lib/AgentsConsoleShellScript.template.sh -- never the assertion" >&2
	exit 1
fi
echo "HARNESS_SKILL_READ: OK (skills by path, by name and by skill with args in every name form, outside refused, failure named by harness and console, offline)"