#!/usr/bin/env bash
## Behavioural check on what every spawn now gets without its caller carrying it: the
## proxy's "## Staying on the task" section (wait with Wait; a spawn its caller does not
## block on never ends on its own and ends only on a Wait DISMISSED, a --wait spawn hands
## back and ends); a Wait result turned DISMISSED only by a DISMISSED addressed to the
## waiting member (AgentsHarnessWaitDismissed.awk); and the harness Agent tool putting the spawn-prepare-brief
## block (tool-routing, read-and-obey) ahead of the prompt -- once, not over a prompt that
## carries its own, and noting it rather than refusing where none can be built. The
## harness system text's own wait rule, and the Agent tool's dismissal note, are checked
## by their words. Offline: a fake console
## records what it receives, a fake curl answers Slack; every run is an `env -i` child
## refusing to run outside this rig's mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigRealTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/skillset/magic-team/magic-team/templates/spawn-brief.document.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigRealTemplate" ] || rigRefuse "the brief template is not in the package: $rigRealTemplate"

rigTmp="$( mktemp -d -t "AgentsSpawnBriefAutoCheck-XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## A filled sandbox input/ loses its write bits by contract.
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team/templates" "$rigSkills/keeper-myx" "$rigSkills/magic-coordinator" "$rigSkills/rig-plain" "$rigData/board/running" "$rigData/inboxes/keeper-myx"

cp "$rigTest/check-fixtures/slack-send-identity-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## The console the proxy launches: records its stdin once (a later handback retry must
## not overwrite the brief under test) and signals a launch.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'[ -s "$RIG_SCENARIO/brief" ] && { cat > /dev/null ; exit 0 ; }' \
	'cat > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

cp "$rigRealTemplate" "$rigSkills/magic-team/templates/spawn-brief.document.format.md"
printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\ndefault-for-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSpawn(){ ## stdin content, member
	: > "$rigTmp/brief"
	env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$1" --dispatch-doc:none --wait --context rig-spawn-auto
		' rig-spawn "$2" <<< "$1" 2>&1
}
## The harness Agent tool, served; it returns at once and the console runs behind it.
rigAgent(){ ## tool argument JSON
	: > "$rigTmp/brief"
	printf '%s' "$1" | env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" HARNESS_PROVIDER_NAME=rig HARNESS_SELF_NAME=rig RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_HARNESS="$rigHarness" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_HARNESS" --intern-tool Agent --access-read-root "$RIG_TMP"
		' 2>&1
	local rigWaited=0
	while [ ! -s "$rigTmp/brief" ] && [ "$rigWaited" -lt 60 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
	sleep 1
}
rigCount(){ ## fixed whole line
	LC_ALL=C grep -c -x -F -- "$1" "$rigTmp/brief"
}

echo "-- the proxy, --wait: staying on the task, the blocked caller is the dismissal --"
rigOut="$( rigSpawn "RIG-TASK-TEXT" keeper-myx )"
grep -q 'RIG-TASK-TEXT' "$rigTmp/brief" || rigRefuse "the fake console never received the context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "the launch succeeded"                          "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "the brief carries the staying section"         "$( rigCount '## Staying on the task' )" 1
rigAssert "which names Wait and its MCP mirror"           "$( LC_ALL=C grep -c -F 'done with the Wait tool (mcp__myx_distro__Wait over MCP)' "$rigTmp/brief" )" 1
rigAssert "and says the blocked caller cannot dismiss"    "$( LC_ALL=C grep -c -F 'Whoever started you is blocked until this run ends, so it cannot dismiss you: when your work is done, hand back with SubagentHandback and end your run.' "$rigTmp/brief" )" 1
rigAssert "not the wait-for-DISMISSED text"               "$( LC_ALL=C grep -c -F 'End your run only when a Wait returns DISMISSED' "$rigTmp/brief" )" 0
rigOut="$( rigSpawn "RIG-TASK-TEXT" rig-meta-caller )"
rigAssert "a caller that is no member gets it too"        "$( rigCount '## Staying on the task' )" 1

echo "-- the harness Agent tool: the brief block is the tooling's --"
rigOut="$( rigAgent '{"agent":"keeper-myx","prompt":"RIG-AGENT-TASK"}' )"
grep -q 'RIG-AGENT-TASK' "$rigTmp/brief" || rigRefuse "the Agent tool's spawn never reached the console: $( printf '%s\n' "$rigOut" | grep -m1 ERROR )"
rigAssert "the block opens the context"                   "$( head -1 "$rigTmp/brief" )" "SPAWN-PREPARE-BRIEF: keeper-myx"
rigAssert "with its tool-routing line"                    "$( LC_ALL=C grep -c '^tool-routing: ' "$rigTmp/brief" )" 1
rigAssert "and its read-and-obey line"                    "$( rigCount 'read-and-obey: read keeper-myx.armed.md and magic-team.coworking.routine.md, through the skillset reader, carefully and in full, before acting, and obey them.' )" 1
rigAssert "the prompt follows"                            "$( rigCount 'RIG-AGENT-TASK' )" 1
rigAssert "a spawn nobody blocks on waits for DISMISSED"  "$( LC_ALL=C grep -c -F 'End your run only when a Wait returns DISMISSED: whoever started you dismisses you by a message addressed to you whose body is DISMISSED.' "$rigTmp/brief" )" 1
rigAssert "after reporting done and waiting"              "$( LC_ALL=C grep -c -F 'report that to whoever started you, with SubagentHandback, saying you are done and waiting for further instructions, then keep waiting.' "$rigTmp/brief" )" 1

rigOut="$( rigAgent '{"agent":"keeper-myx","prompt":"SPAWN-PREPARE-BRIEF: keeper-myx\nRIG-OWN-BLOCK"}' )"
grep -q 'RIG-OWN-BLOCK' "$rigTmp/brief" || rigRefuse "the second Agent spawn never reached the console"
rigAssert "a prompt with its own block is not given another" "$( LC_ALL=C grep -c '^SPAWN-PREPARE-BRIEF: ' "$rigTmp/brief" )" 1

rigOut="$( rigAgent '{"agent":"rig-plain","prompt":"RIG-PLAIN-TASK"}' )"
rigAssert "a member with no .armed.md is still spawned"   "$( LC_ALL=C grep -c -x -F 'RIG-PLAIN-TASK' "$rigTmp/brief" )" 1
rigAssert "and the result says the block is missing"      "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'NOTE: the spawn brief block (tool-routing, read-and-obey) could not be built for rig-plain' )" 1

echo "-- the harness system text --"
rigAssert "says a plain-text reply ends the run, and to Wait instead" \
	"$( LC_ALL=C grep -c -F 'A plain-text reply with no tool call ends your run, so never give one while the work is still open' "$rigHarness" )$( LC_ALL=C grep -c -F 'Wait for it with the Wait tool (mcp__myx_distro__Wait over MCP)' "$rigHarness" )" 11

rigAssert "spawned sessions nobody blocks on are told to wait for DISMISSED" \
	"$( LC_ALL=C grep -c -F '[ -z "${MDAT_SPAWN_SESSION_ID:-}" ] || [ "${MDAT_SPAWN_CALLER_WAITS:-}" = "true" ] || harnessSpawnedWaitNote=" You are a spawned session: you never end on your own' "$rigHarness" )" 1
rigAssert "the Agent tool tells the spawner how to dismiss" \
	"$( LC_ALL=C grep -c -F 'SendMessage to its session thread with address_to set to its member name and the message DISMISSED, which its Wait returns as DISMISSED. TaskStop is the last-resort force stop.' "$rigHere/AgentsOpenAiChatWire.sh" )" 1
rigAssert "the Wait tool declares the DISMISSED outcome" \
	"$( LC_ALL=C grep -c -F 'DISMISSED: a message addressed to you whose body is DISMISSED arrived' "$rigHere/AgentsOpenAiChatWire.sh" )" 1
rigAssert "and the MCP mirror serves it" \
	"$( MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigHere/AgentsHarnessMcpMirror.sh" 2>/dev/null | LC_ALL=C grep -c -F 'DISMISSED: a message addressed to you whose body is DISMISSED arrived' )" 1

echo "-- Wait: DISMISSED only for a dismissal addressed to the waiting member --"
rigDismissed(){ ## agent -- prints the dismissing head and rc
	local rigHead rigRc=0
	rigHead="$( LC_ALL=C awk -v agent="$1" -f "$rigHere/AgentsHarnessWaitDismissed.awk" "$rigTmp/wait.out" )" || rigRc=$?
	printf '%s rc=%s' "$rigHead" "$rigRc"
}
printf '%s\n' 'WAIT-RESULT: RECEIVED' '1.000001 | U1 | :m: *_magic-coordinator_* @Magic → *_rig-a_* @A; *_rig-c_* @C.' 'DISMISSED' \
	'1.000002 | U2 | [sender: x] DISMISSED keeper-myx' '1.000003 | U3 | *_magic-coordinator_* @Magic → *_rig-b_* @B.' 'Not DISMISSED yet' \
	'1.000004 | U4 | *_magic-coordinator_* @Magic → @here.' 'DISMISSED' 'WAIT-LAST-TS: 1.000004' > "$rigTmp/wait.out"
rigAssert "the header form, addressed to the member"      "$( rigDismissed rig-a )" "1.000001 | U1 rc=0"
rigAssert "one of several addressees"                     "$( rigDismissed rig-c )" "1.000001 | U1 rc=0"
rigAssert "the typed form naming the member"              "$( rigDismissed keeper-myx )" "1.000002 | U2 rc=0"
rigAssert "a body that is not just DISMISSED is not one"  "$( rigDismissed rig-b )" " rc=1"
rigAssert "@here dismisses no one"                        "$( rigDismissed rig-z )" " rc=1"
rigAssert "the harness turns it into the DISMISSED outcome" \
	"$( LC_ALL=C grep -c -F "printf 'WAIT-RESULT: DISMISSED\\nWAIT-DISMISSED-BY: %s\\n'" "$rigHarness" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN BRIEF AUTO CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_BRIEF_AUTO: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
