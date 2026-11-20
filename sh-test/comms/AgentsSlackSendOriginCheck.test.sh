#!/usr/bin/env bash
## Behavioural check on the origin a post carries outside its own session thread (epic S6 item 20: "every post
## outside the poster's own session thread carries its origin routine and its real sender member"), run rather
## than read. The origin is the routine of the run that sends, short and in parentheses after its alias:
## `@dispatchr (root-harness)`. It is read from the run's own record in its sandbox, else from the routine file
## the root harness's mint kept in the session's own folder. A send from no run reads `console`.
## Offline: a Slack-shaped fake curl first on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigTest="$rigPackage/sh-test"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsSlackSendOriginCheck-XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigScenario="$rigTmp/scenario" ; rigSandbox="$rigTmp/sandbox"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents/members/magic-coordinator" \
	"$rigHome/.agents/magic-team" "$rigScenario" "$rigSandbox"
cp "$rigTest/check-fixtures/member-workspace-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/member-workspace-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
printf '%s\n' 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001' 'SLACK_BOT_TOKEN=rig-bot-token-TEAM' > "$rigWs/.local/.agents/magic-team.agent.env"
printf '%s\n' 'magic-coordinator 🐭 Magic Vane dispatchr' > "$rigWs/.local/agents/team-members-names.registry"
printf '%s\t%s\n' magic-coordinator "$rigWs/.local/agents/members/magic-coordinator" > "$rigHome/.agents/magic-team/members.registry"
rigSession="rig-sess-origin-0001"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigReset(){ ## -- a known state: no session spawned, none recorded, an empty sandbox
	rm -rf "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions" "$rigSandbox"
	mkdir -p "$rigSandbox"
}
rigSend(){ ## environment words of the run... -- the author line of one send, `-` where nothing was posted
	: > "$rigScenario/bodies"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigScenario" "$@" \
		bash "$rigTool" --slack-send-message --team-member magic-coordinator magic-team --told RIG-BODY ) \
		> "$rigTmp/out" 2> "$rigTmp/err" < /dev/null
	local bodyLine
	bodyLine="$( LC_ALL=C sed -n '1s/^{"channel":"[^"]*","text":"//; 1s/","blocks":.*//; 1p' "$rigScenario/bodies" )"
	[ -n "$bodyLine" ] || { printf '%s\n' "-" ; return 0 ; }
	printf '%s\n' "${bodyLine%%\\n*}"
}

echo "-- control: a spawned run's own sandbox record names its routine --"
rigReset
printf '%s\n' '---' "session-id: $rigSession" 'owner: magic-coordinator' 'routine: magic-team.coworking.routine.md' '---' > "$rigSandbox/$rigSession.spawn.md"
rigAssert "a spawned run's own record is read, and its routine stands in the author line" \
	"$( rigSend MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" MDAT_SPAWN_AGENT=magic-coordinator )" \
	'🐭 *_magic-coordinator_* @dispatchr (coworking) → this conversation.'

echo "-- a routine switched inside the run: the label is the frame in force, never the one the start recorded --"
rigReset
printf '%s\n' '---' "session-id: $rigSession" 'owner: magic-coordinator' \
	'routine: magic-coordinator.off-duty.routine.md' \
	'routine-stack: magic-coordinator.off-duty.routine.md:open' \
	'routine-stack: magic-coordinator.work-duty.routine.md:current' \
	'---' > "$rigSandbox/$rigSession.spawn.md"
rigAssert "the frame in force labels the post, not the routine line the start wrote" \
	"$( rigSend MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" MDAT_SPAWN_AGENT=magic-coordinator )" \
	'🐭 *_magic-coordinator_* @dispatchr (work-duty) → this conversation.'

echo "-- the stack is read where the record carries no routine line at all --"
rigReset
printf '%s\n' '---' "session-id: $rigSession" 'owner: magic-coordinator' \
	'routine-stack: magic-coordinator.supervision-session.routine.md:current' \
	'---' > "$rigSandbox/$rigSession.spawn.md"
rigAssert "a stack with no routine line still labels the post" \
	"$( rigSend MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" MDAT_SPAWN_AGENT=magic-coordinator )" \
	'🐭 *_magic-coordinator_* @dispatchr (supervision-session) → this conversation.'

echo "-- an adopted root-harness session: its record is in the store, and its routine is the one its mint kept --"
rigReset
mkdir -p "$rigWs/.local/agents/spawned/$rigSession" "$rigWs/.local/agents/sessions/$rigSession"
printf '%s\n' '---' "session-id: $rigSession" 'start-context: root-harness' 'owner: magic-coordinator' 'status: spawn-started' '---' > "$rigWs/.local/agents/spawned/$rigSession/$rigSession.spawn.md"
printf '%s\n' 'magic-coordinator.root-harness.routine.md' > "$rigWs/.local/agents/sessions/$rigSession/root-session.routine"
rigAssert "the root harness names its own routine as the origin" \
	"$( rigSend MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SPAWN_AGENT=magic-coordinator )" \
	'🐭 *_magic-coordinator_* @dispatchr (root-harness) → this conversation.'

echo "-- a send from no run: the console --"
rigReset
rigAssert "a send from no run reads console" \
	"$( rigSend MDAT_SPAWN_AGENT=magic-coordinator )" \
	'🐭 *_magic-coordinator_* @dispatchr (console) → this conversation.'

echo "-- nothing names the run's routine: no origin is invented --"
rigReset
mkdir -p "$rigWs/.local/agents/sessions/$rigSession"
rigAssert "neither record nor routine file: no origin, and the line still posts" \
	"$( rigSend MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SPAWN_AGENT=magic-coordinator )" \
	'🐭 *_magic-coordinator_* @dispatchr → this conversation.'

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
