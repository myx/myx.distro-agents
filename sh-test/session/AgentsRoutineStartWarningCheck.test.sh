#!/usr/bin/env bash
## Behavioural check on the help verb and the counted start warning of F6.1: a routine that requires a tracking item,
## started inside a session that is already running (a joined start: the spawner has no session to give an item to),
## goes on with a warning, asks the session's coordinator for the item by the existing inquiry path, naming the routine,
## and keeps the warning on the run's record as `start-warning: <requirement> <why>`, where it is counted.
## Held:
##   1. the joined start of a `tracking-item: required` routine with no item: exit 0, the run briefed
##   2. it says the warning on its own output, naming the routine
##   3. an inquiry stands in magic-coordinator's inbox, naming the routine and the requirement
##   4. the run's record carries `start-warning: tracking-item ...`
##   5. controls: the same routine started as a session of its own makes the item (automate) and warns of nothing; a
##      routine that leaves tracking-item: out warns of nothing
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRoutineStartWarningCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigData/board" "$rigData/inboxes/magic-coordinator/incoming"
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
for rigMember in keeper-rig magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigRoutine(){ ## short name, the tracking-item: value or nothing
	{
		printf -- '---\ntype: routine\nexecutors: keeper-rig\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n'
		[ -z "$2" ] || printf 'tracking-item: %s\n' "$2"
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-team/magic-team.$1.routine.md"
}
rigRoutine needsitem required
rigRoutine plain ""

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One start of keeper-rig's routine through the spawn proxy: `joined` (a start inside a running session, said by --start-context) or `new`.
rigSpawn(){ ## routine short name, joined|new
	local spawnSession=( --session-new )
	[ "$2" = new ] || spawnSession=( --session-new --start-context joined )
	rm -f "$rigTmp"/brief.* ; rm -f "$rigData"/inboxes/magic-coordinator/incoming/inquiry-*
	rm -rf "$rigData/board" ; mkdir -p "$rigData/board"
	chmod -R u+w -- "$rigWs/.local/agents" 2> /dev/null ; rm -rf "$rigWs/.local/agents/spawned"
	rigRc=0
	env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-start-warning keeper-rig --routine "$1" "${spawnSession[@]}" --dispatch-doc:none --wait <<< "RIG-TASK-TEXT" > "$rigTmp/spawn.out" 2>&1 || rigRc=$?
	rigInquiries="$( ls "$rigData"/inboxes/magic-coordinator/incoming/inquiry-* 2> /dev/null | LC_ALL=C grep -c . || : )"
	rigWarned="$( LC_ALL=C grep -h -c '^start-warning: tracking-item' "$rigWs"/.local/agents/spawned/*/*.md 2> /dev/null | LC_ALL=C awk '{ n += $1 } END { print n + 0 }' )"
	rigItems="$( find "$rigData/board" -type f -name '*.md' 2> /dev/null | LC_ALL=C grep -c . || : )"
}

echo "-- 1-4. a joined start of a routine that requires an item, with none --"
rigSpawn needsitem joined
rigAssert "the start goes on: exit 0, the run briefed" "$rigRc:$( [ -e "$rigTmp/brief.keeper-rig" ] && echo briefed || echo none )" "0:briefed"
rigAssert "it says the warning, naming the routine" "$( LC_ALL=C grep -c 'WARNING: magic-team.needsitem.routine.md: tracking-item' "$rigTmp/spawn.out" )" "1"
rigAssert "one inquiry in magic-coordinator's inbox, naming the routine and the requirement" "$rigInquiries:$( LC_ALL=C grep -l -F 'magic-team.needsitem.routine.md' "$rigData"/inboxes/magic-coordinator/incoming/inquiry-* 2> /dev/null | LC_ALL=C grep -c . ):$( LC_ALL=C grep -l -F 'tracking-item' "$rigData"/inboxes/magic-coordinator/incoming/inquiry-* 2> /dev/null | LC_ALL=C grep -c . )" "1:1:1"
rigAssert "the run's record carries one start-warning:" "$rigWarned" "1"

echo "-- 5. controls --"
rigSpawn needsitem new
rigAssert "as a session of its own: the item is made (automate), no warning, no inquiry" "$rigRc:$rigItems:$rigWarned:$rigInquiries" "0:1:0:0"
rigSpawn plain joined
rigAssert "a routine that leaves tracking-item: out: no warning, no inquiry" "$rigRc:$rigWarned:$rigInquiries" "0:0:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE START WARNING CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_START_WARNING: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
