#!/usr/bin/env bash
## Behavioural check on S4.6, run rather than read: NOTHING CATCHES A CLAUDE-NATIVE WORK-DUTY THAT ENDS ON ITS
## FINAL ANSWER. The harness's own runs catch this live, inside their one model-call loop
## (AgentsUniversalHarness.sh:1878-1897), and idle-wait there. A claude-native run has no such loop here to
## catch it in: the vendor CLI's own process has already ended by the time the spawn proxy is told. The proxy
## must resume the duty instead, in its own kept session (AgentsToolsSpawnProxyWorkDutyContinue), the same
## mechanical shape AgentsToolsSpawnProxyHandbackWarn's own retry already uses.
## Held: a work-duty's own console is called a second time, with MDAT_SPAWN_RESUME=true, after its first call
## gave a handback and exited clean; it is called in the one session the first call ran in; and a round that
## finds the session dismissed stops there, with no third call.
## Offline: the fake curl is the Slack send identity check's; the console is a stand-in that counts its own
## calls and hands back every time.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWorkDutyClaudeNativeContinueCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigSkills/keeper-myx" "$rigSkills/magic-coordinator" "$rigData/board/backlog"

cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## The console the proxy launches: counts its own calls, keeps each call's brief and whether it was a resume,
## hands back and exits clean every time, and marks the session dismissed on the second call -- the loop's
## one way out, so this check runs a bounded number of rounds.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'callN=$(( $( cat "$RIG_SCENARIO/calls" 2>/dev/null || printf 0 ) + 1 ))' \
	'printf "%s" "$callN" > "$RIG_SCENARIO/calls"' \
	'cat > "$RIG_SCENARIO/brief.$callN"' \
	'printf "%s\n" "${MDAT_SPAWN_RESUME:-}" > "$RIG_SCENARIO/resume.$callN"' \
	'printf "%s\n" "$MDAT_SESSION_ID" > "$RIG_SCENARIO/session.$callN"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'if [ "$callN" = "2" ] ; then' \
	'	mkdir -p "$MMDAPP/.local/agents/sessions/$MDAT_SESSION_ID"' \
	'	: > "$MMDAPP/.local/agents/sessions/$MDAT_SESSION_ID/dismissed"' \
	'fi' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf -- '---\nexecutors: keeper-myx\nmaintainers: keeper-myx\nrequires-session-kind: standalone\n---\n# rig work-duty routine fixture\n' \
	> "$rigSkills/keeper-myx/keeper-myx.work-duty.routine.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

echo "-- a work-duty that hands back and ends clean is resumed, not closed --"
env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
	MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TOOL="$rigTool" \
	bash -c 'cd "$MMDAPP" && exec bash "$RIG_TOOL" --spawn-session --routine keeper-myx.work-duty.routine.md keeper-myx' \
	> "$rigTmp/run.out" 2>&1 < /dev/null

rigWaited=0
while [ ! -f "$rigTmp/resume.2" ] && [ "$rigWaited" -lt 60 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done

rigAssert "the console was called at least twice: the plain end did not stop it" "$( [ -f "$rigTmp/resume.2" ] && echo yes || echo no )" "yes"
rigAssert "the second call is a resume" "$( cat "$rigTmp/resume.2" 2>/dev/null )" "true"
rigAssert "the second call ran in the same session as the first" \
	"$( [ -s "$rigTmp/session.1" ] && [ "$( cat "$rigTmp/session.1" 2>/dev/null )" = "$( cat "$rigTmp/session.2" 2>/dev/null )" ] && echo same || echo "differ" )" "same"

## The second call marked the session dismissed: the loop's one way out. Give it a moment, then
## confirm no third call ever came.
sleep 2
rigAssert "a dismissed session is not resumed a third time" "$( [ -f "$rigTmp/resume.3" ] && echo yes || echo no )" "no"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ WORK DUTY CLAUDE-NATIVE CONTINUE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
echo "WORK_DUTY_CLAUDE_NATIVE_CONTINUE: OK ($rigPasses assertions, offline)"
