#!/usr/bin/env bash
## Behavioural check on --intern-op-agent-spawn-proxy's --routine/--routine-default
## options: given one, the proxy builds the --intern-op-spawn-prepare-brief block for
## the member it spawns and puts it before the spawn context, followed by one blank
## line, in every source mode (stdin, --from-file, --from-board); given neither,
## behaviour is unchanged; given both, the spawn is refused before anything launches.
## Offline: a fake console records exactly what it receives on stdin, a fake curl
## answers Slack. Modelled on AgentsSpawnSessionThreadCheck.test.sh (fake console/curl
## rig) and AgentsHarnessArmGateCheck.test.sh (env -i isolated scenarios, rig tree only).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRealTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/skillset/magic-team/magic-team/templates/spawn-brief.document.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigRealTemplate" ] || rigRefuse "the brief template is not in the package: $rigRealTemplate"

rigTmp="$( mktemp -d -t "AgentsSpawnProxyRoutineCheck-XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team/templates" "$rigSkills/keeper-myx" "$rigData/board/backlog"

cp "$rigHere/check-fixtures/slack-send-identity-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigHere/check-fixtures/slack-send-identity-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## The console the proxy launches: records exactly what it receives on stdin and
## signals a launch -- the same fixture shape AgentsSpawnSessionThreadCheck.test.sh uses.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'cat > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

## A real brief template, a target member's own duty file, and the default routine --
## enough for --intern-op-spawn-prepare-brief to resolve a real, complete brief block.
cp "$rigRealTemplate" "$rigSkills/magic-team/templates/spawn-brief.document.format.md"
printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator, magic-librarian\ninvitees: magic-team\ndefault-for-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
## A board item for the --from-board source mode.
printf -- '---\ntype: task\n---\n\nRIG-BOARD-MARKER-TEXT\n' > "$rigData/board/backlog/task-rig-routine.md"
## A plain file for the --from-file source mode.
printf 'RIG-FILE-MARKER-TEXT\n' > "$rigTmp/task-file.txt"

rigSpawn(){ ## stdin content, then extra --intern-op-agent-spawn-proxy args...
	local rigStdin="$1" ; shift
	: > "$rigTmp/brief"
	env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:none --wait --context rig-spawn-routine "$@"
		' rig-spawn-wrapper "$@" <<< "$rigStdin" 2>&1
}

## True when the file's own "(none open)" line (the brief block's own last line) is
## followed by exactly one blank line and then real content -- the "block, one blank
## line, then the spawn context" shape S5 asks for, checked the same way regardless of
## what the spawn context itself looks like in a given source mode.
rigBlankGapThenContent(){ ## file
	LC_ALL=C awk '
		$0 == "(none open)" { base = NR ; next ; }
		base && NR == base + 1 { blank = ( $0 == "" ) ; next ; }
		base && NR == base + 2 { print ( blank && $0 != "" ) ? "ok" : "bad" ; exit ; }
	' "$1"
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

## Posting succeeds, so a launch is never also blocked on Slack config.
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

echo "-- --routine-default, stdin source: block, one blank line, then the task text --"
rigOut="$( rigSpawn "RIG-TASK-TEXT" --routine-default )"
grep -q 'RIG-TASK-TEXT' "$rigTmp/brief" || rigRefuse "the fake console never received the context, so nothing below would be measured: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "the launch succeeded"                         "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "the brief block opens the context"            "$( head -1 "$rigTmp/brief" )" "SPAWN-PREPARE-BRIEF: keeper-myx"
rigAssert "the read-and-obey line names the default routine" \
	"$( grep -c -x -F 'read-and-obey: read keeper-myx.armed.md and magic-team.coworking.routine.md, through the skillset reader, carefully and in full, before acting, and obey them.' "$rigTmp/brief" )" 1
rigAssert "one blank line separates the block from the task text" "$( rigBlankGapThenContent "$rigTmp/brief" )" ok
rigAssert "the task text itself follows"                 "$( grep -c -x -F 'RIG-TASK-TEXT' "$rigTmp/brief" )" 1

echo "-- --routine-default, --from-file source: the block still comes first --"
rigOut="$( rigSpawn "RIG-UNUSED-STDIN" --routine-default --from-file "$rigTmp/task-file.txt" )"
grep -q 'RIG-FILE-MARKER-TEXT' "$rigTmp/brief" || rigRefuse "the fake console never received the context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "the brief block still opens the context"      "$( head -1 "$rigTmp/brief" )" "SPAWN-PREPARE-BRIEF: keeper-myx"
rigAssert "one blank line separates it from the file's own content" "$( rigBlankGapThenContent "$rigTmp/brief" )" ok
rigAssert "the file's content follows, marker included"  "$( grep -c -x -F 'RIG-FILE-MARKER-TEXT' "$rigTmp/brief" )" 1

echo "-- --routine-default, --from-board source: the block still comes first --"
rigOut="$( rigSpawn "RIG-UNUSED-STDIN" --routine-default --from-board task-rig-routine.md )"
grep -q 'RIG-BOARD-MARKER-TEXT' "$rigTmp/brief" || rigRefuse "the fake console never received the context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "the brief block still opens the context"      "$( head -1 "$rigTmp/brief" )" "SPAWN-PREPARE-BRIEF: keeper-myx"
rigAssert "one blank line separates it from the board item's own content" "$( rigBlankGapThenContent "$rigTmp/brief" )" ok
rigAssert "the board item's content follows, marker included" "$( grep -c -x -F 'RIG-BOARD-MARKER-TEXT' "$rigTmp/brief" )" 1

echo "-- neither option: the context is the task text alone, unchanged --"
rigOut="$( rigSpawn "RIG-TASK-TEXT" )"
rigAssert "the launch succeeded"                         "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "no brief block is prepended"                  "$( grep -c '^SPAWN-PREPARE-BRIEF:' "$rigTmp/brief" )" 0
rigAssert "the task text itself opens the context, unchanged" "$( head -1 "$rigTmp/brief" )" "RIG-TASK-TEXT"

echo "-- both --routine and --routine-default: refused before anything launches --"
: > "$rigTmp/brief"
rigOut="$( rigSpawn "RIG-TASK-TEXT" --routine-default --routine magic-team.coworking.routine.md )"
rigAssert "is refused"                                   "$( printf '%s\n' "$rigOut" | grep -c 'use only one of --routine' )" 1
rigAssert "and nothing was launched"                     "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=' )" 0
rigAssert "the console never ran"                        "$( [ -s "$rigTmp/brief" ] && echo ran || echo did-not-run )" did-not-run

echo "-- --routine with no value: refused with the one shared wording --"
: > "$rigTmp/brief"
rigOut="$( rigSpawn "RIG-TASK-TEXT" --routine )"
rigAssert "is refused"                                   "$( printf '%s\n' "$rigOut" | grep -c 'routine requires <selector>' )" 1
rigAssert "the console never ran"                        "$( [ -s "$rigTmp/brief" ] && echo ran || echo did-not-run )" did-not-run

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN PROXY ROUTINE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_PROXY_ROUTINE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
