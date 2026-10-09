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
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRealTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/templates/spawn-brief.document.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigRealTemplate" ] || rigRefuse "the brief template is not in the package: $rigRealTemplate"

rigTmp="$( mktemp -d -t "AgentsSpawnProxyRoutineCheck-XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## A filled sandbox input/ loses its write bits (AgentsToolsSpawnSandboxFillInput's own
## read-only-by-mode contract), reached now that --intern-root-harness spawns for real.
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigSkills/keeper-myx" "$rigSkills/magic-coordinator" "$rigData/board/backlog"

cp "$rigTest/check-fixtures/slack-send-identity-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## The console the proxy launches: records exactly what it receives on stdin and
## signals a launch -- the same fixture shape AgentsSpawnSessionThreadCheck.test.sh uses.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'## It hands back, so the proxy never retries it and overwrites the brief it recorded.' \
	'cat > "$RIG_SCENARIO/brief"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

## The package's real brief template, a target member's own duty file, and the default routine --
## enough for --intern-op-spawn-prepare-brief to resolve a real, complete brief block.
printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
## --intern-root-harness's own caller, hardcoded magic-coordinator, needs its own
## basic.md (the real-member check --address-to's own send validates against) and
## armed.md (required by --intern-op-spawn-prepare-brief itself), same as keeper-myx above.
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
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

## --intern-root-harness never reads external stdin itself -- it pipes its own static
## brief file into the spawn proxy internally -- so this helper gives none, unlike rigSpawn.
rigRootHarness(){ ## extra --intern-root-harness args...
	: > "$rigTmp/brief"
	env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-root-harness "$@"
		' rig-root-harness-wrapper "$@" < /dev/null 2>&1
}

## True when the file's own "When done, hand back; then Wait until dismissed." line (the brief block's own last line) is
## followed by exactly one blank line and then real content -- the "block, one blank
## line, then the spawn context" shape S5 asks for, checked the same way regardless of
## what the spawn context itself looks like in a given source mode.
rigBlankGapThenContent(){ ## file
	LC_ALL=C awk '
		$0 == "When done, hand back; then Wait until dismissed." { base = NR ; next ; }
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

## Posting succeeds, so a launch is never also blocked on Slack config. Both channels:
## --intern-root-harness picks magic-team when interactive, event-track when not.
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

echo "-- --routine-default, stdin source: block, one blank line, then the task text --"
rigOut="$( rigSpawn "RIG-TASK-TEXT" --routine-default )"
grep -q 'RIG-TASK-TEXT' "$rigTmp/brief" || rigRefuse "the fake console never received the context, so nothing below would be measured: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "the launch succeeded"                         "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "the brief block opens the context"            "$( head -1 "$rigTmp/brief" )" "SPAWN-PREPARE-BRIEF: keeper-myx"
rigAssert "the read-and-obey line names the default routine" \
	"$( grep -c -x -F 'read-and-obey: read keeper-myx.armed.md and magic-team.coworking.routine.md, through the skillset reader, carefully and in full, before acting, and obey them.' "$rigTmp/brief" )" 1
rigAssert "names the shared.md sections" \
	"$( grep -c -x -F 'Read these two sections of magic-team/magic-team.shared.md, the same way, with section and not the whole file: {name: magic-team, file: magic-team.shared.md, section: Nothing stops on its own: log, escalate, resolve|Every message is addressed, tagged, and sent on a real channel}' "$rigTmp/brief" )" 1
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

echo "-- --intern-root-harness: routine given, interactive by default --"
rigOut="$( rigRootHarness --routine coworking --wait )"
grep -q 'INTERACTION-MODE:' "$rigTmp/brief" || rigRefuse "the fake console never received the brief: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "the launch succeeded"                         "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "the routine brief block opens the context"    "$( head -1 "$rigTmp/brief" )" "SPAWN-PREPARE-BRIEF: magic-coordinator"
rigAssert "the read-and-obey line names the given routine" \
	"$( grep -c -x -F 'read-and-obey: read magic-coordinator.armed.md and magic-team.coworking.routine.md, through the skillset reader, carefully and in full, before acting, and obey them.' "$rigTmp/brief" )" 1
rigAssert "names the shared.md sections" \
	"$( grep -c -x -F 'Read these two sections of magic-team/magic-team.shared.md, the same way, with section and not the whole file: {name: magic-team, file: magic-team.shared.md, section: Nothing stops on its own: log, escalate, resolve|Every message is addressed, tagged, and sent on a real channel}' "$rigTmp/brief" )" 1
rigAssert "interactive by default"                        "$( grep -c -x -F 'INTERACTION-MODE: interactive -- keep looping, with a dedicated Slack thread for interaction.' "$rigTmp/brief" )" 1

## The payload routine goes into the packet by its resolved filename, worded as Step 16 of the heartbeat routine words it.
## The line's name and its tail are awaiting the owner's approval, so each is spelled here and nowhere else in these rows.
rigRoutineLabel="ROUTINE:"
rigRoutineTail="-- the dispatch's --routine parameter: run it as this pass's payload."
rigHeartbeatFile="magic-coordinator.heartbeat.routine.md"
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\n---\n# rig heartbeat routine fixture\n' > "$rigSkills/magic-coordinator/$rigHeartbeatFile"
rigLineNo(){ ## file, fixed text at the start of a line -- the number of the first such line, or none
	LC_ALL=C awk -v want="$2" 'index($0, want) == 1 { print NR ; found = 1 ; exit } END { if ( ! found ) print "none" }' "$1"
}

echo "-- --intern-root-harness through the real proxy: the packet names the payload routine, as the main loop calls it --"
rigOut="$( rigRootHarness --routine heartbeat --non-interactive --wait )"
grep -q 'INTERACTION-MODE:' "$rigTmp/brief" || rigRefuse "the fake console never received the brief: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "the launch succeeded"                          "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "the packet has exactly one routine line, naming the resolved file" "$( LC_ALL=C grep -c -x -F "$rigRoutineLabel $rigHeartbeatFile $rigRoutineTail" "$rigTmp/brief" )" 1
rigModeNo="$( rigLineNo "$rigTmp/brief" 'INTERACTION-MODE: non-interactive' )"
rigRoutineNo="$( rigLineNo "$rigTmp/brief" "$rigRoutineLabel " )"
rigBriefNo="$( rigLineNo "$rigTmp/brief" 'SPAWN-REQUEST' )"
rigAssert "the routine line comes right under the mode line"       "$( [ "$rigModeNo" != none ] && [ "$rigRoutineNo" = "$(( rigModeNo + 1 ))" ] && echo adjacent || echo "mode=$rigModeNo routine=$rigRoutineNo" )" adjacent
rigAssert "and the brief follows it: SPAWN-REQUEST after both"     "$( [ "$rigBriefNo" != none ] && [ "$rigBriefNo" -gt "$rigRoutineNo" ] && echo after || echo "brief=$rigBriefNo" )" after
rigAssert "the routine's own brief block still opens the packet"  "$( head -1 "$rigTmp/brief" )" "SPAWN-PREPARE-BRIEF: magic-coordinator"
rigAssert "the main loop calls it with exactly these arguments"   "$( LC_ALL=C grep -c -F 'DistroAgentsTools --intern-root-harness --routine heartbeat --non-interactive --wait' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternMainLoop.include" )" 1

echo "-- --intern-root-harness against a stub proxy: the exact packet and the exact proxy arguments --"
rigStubRoot="$rigTmp/stub-skills" ; rigStubTwo="$rigTmp/stub-skills-two"
mkdir -p "$rigStubRoot/magic-coordinator" "$rigStubRoot/magic-team" "$rigStubTwo/magic-coordinator" "$rigStubTwo/magic-team"
printf -- '---\nexecutors: x\nmaintainers: x\n---\n' | tee "$rigStubRoot/magic-coordinator/$rigHeartbeatFile" "$rigStubRoot/magic-coordinator/magic-coordinator.grooming.routine.md" "$rigStubTwo/magic-coordinator/$rigHeartbeatFile" "$rigStubTwo/magic-team/magic-team.heartbeat-extra.routine.md" > /dev/null
rigBriefFile="$MDLT_ORIGIN/myx/myx.distro-agents/skillset/magic-team/magic-team/dispatches/root-harness-session-start.prompt-packet.verbatim.md"
rigStubRun(){ ## skill root, arguments...
	local stubRoot="$1" ; shift
	rm -f "$rigTmp/stub.args" "$rigTmp/stub.stdin"
	env -i HOME="$rigTmp" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$stubRoot" RIG_ARGS="$rigTmp/stub.args" RIG_STDIN="$rigTmp/stub.stdin" \
		bash -c '
			DistroAgentsTools(){ printf "%s\n" "$*" > "$RIG_ARGS" ; cat > "$RIG_STDIN" ; }
			rigInclude(){ local MDSC_CMD=DistroAgentsTools ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternRootHarness.include" ; }
			rigInclude "$@"
		' rig "$@" > "$rigTmp/stub.out" 2>&1 < /dev/null
	rigStubRc=$?
}
rigExpect(){ ## mode line, routine line or empty -- the packet the stub must have received, written to $rigTmp/stub.expect
	{ printf '%s\n' "$1" ; [ -z "$2" ] || printf '%s\n' "$2" ; printf '\n' ; cat "$rigBriefFile" ; } > "$rigTmp/stub.expect"
}
rigModeNon="INTERACTION-MODE: non-interactive -- run one loop, then exit."
rigModeInt="INTERACTION-MODE: interactive -- keep looping, with a dedicated Slack thread for interaction."
rigRoutineLine="$rigRoutineLabel $rigHeartbeatFile $rigRoutineTail"

rigStubRun "$rigStubRoot" --intern-root-harness --routine heartbeat --non-interactive --wait
rigExpect "$rigModeNon" "$rigRoutineLine"
rigAssert "non-interactive with a routine: the include returns 0"  "$rigStubRc" 0
rigAssert "the packet is exactly mode line, routine line, one blank line, the unchanged brief" "$( cmp -s "$rigTmp/stub.stdin" "$rigTmp/stub.expect" && echo identical || echo different )" identical
rigAssert "the proxy gets the raw selector, --session-thread and --wait, in that order" "$( cat "$rigTmp/stub.args" )" "--magic-heartbeat-spawn-proxy magic-coordinator --session-thread:event-track --routine heartbeat --wait"
rigAssert "the brief's own sections are all in the packet"       "$( for rigSec in SPAWN-REQUEST GOAL CONTEXT WAIT ; do LC_ALL=C grep -c -e "^$rigSec" -e "^## $rigSec" -e "^# $rigSec" "$rigTmp/stub.stdin" | LC_ALL=C awk '{ printf "%s ", ( $1 > 0 ? "yes" : "no" ) }' ; done )" "yes yes yes yes "
rigStubRun "$rigStubRoot" --intern-root-harness --routine heartbeat
rigExpect "$rigModeInt" "$rigRoutineLine"
rigAssert "interactive with a routine: the packet carries the routine line too" "$( cmp -s "$rigTmp/stub.stdin" "$rigTmp/stub.expect" && echo identical || echo different )" identical
rigAssert "and the proxy is told the magic-team thread, without --wait"       "$( cat "$rigTmp/stub.args" )" "--magic-heartbeat-spawn-proxy magic-coordinator --session-thread:magic-team --routine heartbeat"
rigStubRun "$rigStubRoot" --intern-root-harness --wait
rigExpect "$rigModeInt" ""
rigAssert "interactive without a routine: no routine line, the packet is mode line, blank line, brief" "$( cmp -s "$rigTmp/stub.stdin" "$rigTmp/stub.expect" && echo identical || echo different ) $( LC_ALL=C grep -c "^$rigRoutineLabel" "$rigTmp/stub.stdin" || : )" "identical 0"
rigAssert "and no --routine reaches the proxy"                   "$( cat "$rigTmp/stub.args" )" "--magic-heartbeat-spawn-proxy magic-coordinator --session-thread:magic-team --wait"
rigStubRun "$rigStubRoot" --intern-root-harness --non-interactive --wait
rigAssert "non-interactive without a routine is refused, rc 1"     "$rigStubRc" 1
rigAssert "with its own message"                                  "$( LC_ALL=C grep -c -x -F '⛔ ERROR: --non-interactive requires --routine <selector>' <( LC_ALL=C sed 's/^DistroAgentsTools --intern-root-harness: //' "$rigTmp/stub.out" ) || : )" 1
rigAssert "and the proxy was never called: no arguments, no packet" "$( [ -e "$rigTmp/stub.args" ] || [ -e "$rigTmp/stub.stdin" ] && echo called || echo never-called )" never-called
rigStubRun "$rigStubRoot" --intern-root-harness --routine no-such-routine --non-interactive --wait
rigAssert "a selector that matches nothing is refused, rc 1, with the resolver's own line" "$rigStubRc $( LC_ALL=C grep -c -F -e '⛔ ERROR: --routine no-such-routine: matches no routine file' "$rigTmp/stub.out" || : )" "1 1"
rigAssert "and nothing was piped to the proxy"                  "$( [ -e "$rigTmp/stub.args" ] || [ -e "$rigTmp/stub.stdin" ] && echo called || echo never-called )" never-called
rigStubRun "$rigStubTwo" --intern-root-harness --routine heartbeat --non-interactive --wait
rigAssert "control: a decoy matching the same selector is refused, rc 1" "$rigStubRc $( LC_ALL=C grep -c -F -e '⛔ ERROR: --routine heartbeat: matches more than one routine file' "$rigTmp/stub.out" || : )" "1 1"
rigAssert "and both candidates are named"                       "$( LC_ALL=C grep -c -e "^  $rigHeartbeatFile\$" -e '^  magic-team.heartbeat-extra.routine.md$' "$rigTmp/stub.out" || : )" 2
rigAssert "and nothing was piped to the proxy"                  "$( [ -e "$rigTmp/stub.args" ] || [ -e "$rigTmp/stub.stdin" ] && echo called || echo never-called )" never-called
rigStubRun "$rigStubRoot" --intern-root-harness --routine heartbeat --non-interactive --wait
{ printf '%s\n' "$rigModeNon" "$rigRoutineLabel heartbeat -- the dispatch's --routine parameter: run it as this pass's payload." ; printf '\n' ; cat "$rigBriefFile" ; } > "$rigTmp/stub.oldshape"
rigAssert "control: the earlier packet form, a raw selector and a flag name, is not the packet the exact row accepts" "$( cmp -s "$rigTmp/stub.stdin" "$rigTmp/stub.oldshape" && echo identical || echo different )" different

echo "-- --intern-root-harness: no routine and no --non-interactive, through the real proxy --"
rigOut="$( rigRootHarness --wait )"
grep -q 'INTERACTION-MODE:' "$rigTmp/brief" || rigRefuse "the fake console never received the brief: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "the launch succeeded"                          "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "the packet has no routine line"                "$( LC_ALL=C grep -c "^$rigRoutineLabel" "$rigTmp/brief" )" 0
rigAssert "and no routine brief block opens it, the mode line does" "$( head -1 "$rigTmp/brief" )" "$rigModeInt"

echo "-- --intern-root-harness: the fail-first, a copy of the include without the routine line --"
rigOld="$rigTmp/oldorigin"
mkdir -p "$rigOld/myx"
for rigEntry in "$MDLT_ORIGIN"/* ; do [ "${rigEntry##*/}" = myx ] || ln -s "$rigEntry" "$rigOld/${rigEntry##*/}" ; done
for rigEntry in "$MDLT_ORIGIN"/myx/* ; do [ "${rigEntry##*/}" = myx.distro-agents ] || ln -s "$rigEntry" "$rigOld/myx/${rigEntry##*/}" ; done
mkdir "$rigOld/myx/myx.distro-agents"
( cd "$MDLT_ORIGIN/myx/myx.distro-agents" && tar cf - --exclude=.git . ) | ( cd "$rigOld/myx/myx.distro-agents" && tar xf - )
rigOldInc="$rigOld/myx/myx.distro-agents/sh-lib/AgentsTools.InternRootHarness.include"
LC_ALL=C grep -v -F "$rigRoutineLabel \${rootHarnessRoutineFile##*/}" "$rigOldInc" > "$rigOldInc.new" && mv "$rigOldInc.new" "$rigOldInc"
rigAssert "control: the copy really lacks the edit"       "$( LC_ALL=C grep -c -F "$rigRoutineLabel \${rootHarnessRoutineFile##*/}" "$rigOldInc" || : )" 0
rigRealOrigin="$MDLT_ORIGIN"
MDLT_ORIGIN="$rigOld"
rigStubRun "$rigStubRoot" --intern-root-harness --routine heartbeat --non-interactive --wait
MDLT_ORIGIN="$rigRealOrigin"
rigAssert "the old code's packet has no routine line, so the exact row above can fail" "$( LC_ALL=C grep -c "^$rigRoutineLabel" "$rigTmp/stub.stdin" || : )" 0
rigAssert "and it differs from the expected packet"       "$( rigExpect "$rigModeNon" "$rigRoutineLine" ; cmp -s "$rigTmp/stub.stdin" "$rigTmp/stub.expect" && echo identical || echo different )" different

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN PROXY ROUTINE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_PROXY_ROUTINE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
