#!/usr/bin/env bash
## Behavioural check on the coworking kind's scan (F6.4, with F6.3): `--intern-op-routine-coworking-session-input-scan` is no
## operation an agent calls; the spawner runs it for a routine that declares it, and it reads the tracking documents from the
## session's own dispatch -- the dispatch item the start made and the item it was started from -- which is context, so its
## definition needs no value of its own: `input-scan-def: routine-coworking-session`.
## Held:
##   1. a start with a dispatch item saves a scan to input/input-scan.md that names that dispatch item
##   2. the scan declared no tracking document: the definition names the scan alone
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRoutineCoworkingScanCheck.XXXXXX" )" || exit 1
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
	'## input/ is emptied when the run closes: what the scan left there is read while the run is live.' \
	'cp "$MDAT_SPAWN_SANDBOX_ROOT/input/input-scan.md" "$RIG_SCENARIO/input-scan.seen" 2> /dev/null || :' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
for rigMember in keeper-rig magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigRoutine(){ ## short name, the input-scan-def: line or nothing
	{
		printf -- '---\ntype: routine\nexecutors: keeper-rig\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n'
		[ -z "$2" ] || printf '%s\n' "$2"
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-team/magic-team.$1.routine.md"
}
rigRoutine rigscanned 'input-scan-def: routine-coworking-session'
rigRoutine rigplain ''

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One start of keeper-rig's routine through the spawn proxy, waiting for its run; the sandbox it made in rigSandbox.
rigSpawn(){ ## routine short name
	rm -f "$rigTmp"/brief.* "$rigTmp/input-scan.seen"
	chmod -R u+w -- "$rigWs/.local/agents" 2> /dev/null ; rm -rf "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sandboxes" "$rigData/board" ; mkdir -p "$rigData/board"
	env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-scan-def keeper-rig --routine "$1" --session-new --dispatch-doc:create --wait <<< "RIG-TASK-TEXT" > "$rigTmp/spawn.out" 2>&1
	rigSandbox="$( find "$rigWs/.local/agents/spawned" -type d -name input 2> /dev/null | head -1 )"
	rigSandbox="${rigSandbox%/input}"
}

echo "-- 1. the spawner runs the coworking scan, with no tracking document given --"
rigSpawn rigscanned
rigItemName="$( find "$rigData/board" -type f -name 'dispatch-*.md' 2> /dev/null | head -1 )"
rigItemName="${rigItemName##*/}"
rigAssert "control: the start made its dispatch item" "$( [ -n "$rigItemName" ] && echo item || echo none )" "item"
rigAssert "input/input-scan.md is saved, and names the dispatch item the start made" "$( [ -f "$rigTmp/input-scan.seen" ] && echo saved || echo none ):$( LC_ALL=C grep -c -F -- "${rigItemName:-no-such-item}" "$rigTmp/input-scan.seen" 2> /dev/null | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' )" "saved:named"
echo "-- 2. the definition names the scan only --"
rigAssert "no tracking document in it" "$( LC_ALL=C grep -c '^input-scan-def: routine-coworking-session$' "$rigSkills/magic-team/magic-team.rigscanned.routine.md" )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE COWORKING SCAN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_COWORKING_SCAN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
