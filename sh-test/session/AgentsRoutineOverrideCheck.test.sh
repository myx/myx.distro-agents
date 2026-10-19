#!/usr/bin/env bash
## Behavioural check on overriding a refusal (F6.1 of the refactorings epic): the refusal of one requirement at a start
## is overridden by a PERMISSION, never by a flag the acting member passes to itself. It is the grant of the tool
## `override` for the target `<requirement>:<routine file>`, one requirement at a time, held by the member that makes the
## start; the refusal names that ask; and a start it lets through is kept on the run's record (`override:`) and on the
## dispatch item's `## Decisions`. A grant for another requirement does not override this one.
## Held:
##   1. no grant: a routine with `tracking-item: forbidden`, started with a dispatch item by a member, is refused and
##      nothing is made; the refusal names the ask (tool override, target tracking-item:<routine file>)
##   2. the member holds that grant (a session grant in its own store): the start goes on, says it was overridden, the
##      record carries `override: tracking-item ...`, and the item's Decisions say so
##   3. a grant for start-context, not tracking-item: still refused
##   4. no member makes the start (the console): no override exists to hold, still refused
## Offline: a fake curl first on PATH; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig starts its session's control thread, which outlives this check: the rig ends it.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRoutineOverrideCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigData/board"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
for rigMember in keeper-rig rig-lead magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
{
	printf -- '---\ntype: routine\nexecutors: keeper-rig\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\ntracking-item: forbidden\n---\n'
	printf '# magic-team.rigforbid.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n'
	printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
} > "$rigSkills/magic-team/magic-team.rigforbid.routine.md"
rigStore="$rigWs/.local/agents/sessions/rig-lead-run"
## A session grant of the tool `override`, in the store of the lead's session: kind:tool:target:by:time:ref, the target
## escaped as the grants file writes it.
rigGrant(){ ## the target, as the requirement and routine it covers
	rm -rf "$rigStore" ; mkdir -p "$rigStore"
	printf 'session:override:%s:human-owner:20261019T1500Z:pass-rig1\n' "$1" > "$rigStore/grants"
	printf -- '---\nowner: rig-lead\n---\n\nA rig grant.\n' > "$rigStore/pass-rig1.md"
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
## One start of keeper-rig's routine with a dispatch item, by the member rig-lead in its session (or by no member).
rigSpawn(){ ## lead|console
	local spawnEnv=()
	[ "$1" != lead ] || spawnEnv=( MDAT_SPAWN_AGENT=rig-lead MDAT_SPAWN_SESSION_ID=rig-lead-run )
	rm -f "$rigTmp"/brief.*
	rm -rf "$rigData/board" ; mkdir -p "$rigData/board"
	chmod -R u+w -- "$rigWs/.local/agents/spawned" 2> /dev/null ; rm -rf "$rigWs/.local/agents/spawned"
	rigRc=0
	env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" ${spawnEnv[@]+"${spawnEnv[@]}"} \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-override keeper-rig --routine rigforbid --session-new --dispatch-doc:create --wait <<< "RIG-TASK-TEXT" > "$rigTmp/spawn.out" 2>&1 || rigRc=$?
	rigItem="$( find "$rigData/board" -type f -name 'dispatch-*.md' 2> /dev/null | head -1 )"
}

echo "-- 1. no grant: refused, and the refusal names the ask --"
rm -rf "$rigStore"
rigSpawn lead
rigAssert "refused, nothing made, tool override and target tracking-item:<routine> named" "$( [ "$rigRc" -ne 0 ] && echo refused || echo started ):$( [ -e "$rigTmp/brief.keeper-rig" ] && echo briefed || echo none ):$( [ -z "$rigItem" ] && echo noitem || echo item ):$( LC_ALL=C grep -c -F 'tool override, target tracking-item:magic-team.rigforbid.routine.md' "$rigTmp/spawn.out" )" "refused:none:noitem:1"

echo "-- 2. the member holds the grant: overridden, and kept --"
rigGrant 'tracking-item%3Amagic-team.rigforbid.routine.md'
rigSpawn lead
rigAssert "the start goes on, saying it was overridden by a permission" "$rigRc:$( [ -e "$rigTmp/brief.keeper-rig" ] && echo briefed || echo none ):$( LC_ALL=C grep -c 'overridden by a permission' "$rigTmp/spawn.out" )" "0:briefed:1"
rigAssert "the record names the override" "$( LC_ALL=C grep -h -c '^override: tracking-item magic-team.rigforbid.routine.md' "$rigWs"/.local/agents/spawned/*/*.md 2> /dev/null | LC_ALL=C awk '{ n += $1 } END { print n + 0 }' )" "1"
rigAssert "the item's Decisions say so" "$( [ -n "$rigItem" ] && LC_ALL=C grep -c 'override: tracking-item' "$rigItem" || echo no-item )" "1"

echo "-- 3. a grant for another requirement does not override this one --"
rigGrant 'start-context%3Amagic-team.rigforbid.routine.md'
rigSpawn lead
rigAssert "still refused" "$( [ "$rigRc" -ne 0 ] && echo refused || echo started ):$( [ -e "$rigTmp/brief.keeper-rig" ] && echo briefed || echo none )" "refused:none"

echo "-- 4. no member makes the start: nothing to hold --"
rigGrant 'tracking-item%3Amagic-team.rigforbid.routine.md'
rigSpawn console
rigAssert "refused" "$( [ "$rigRc" -ne 0 ] && echo refused || echo started ):$( [ -e "$rigTmp/brief.keeper-rig" ] && echo briefed || echo none )" "refused:none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE OVERRIDE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_OVERRIDE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
