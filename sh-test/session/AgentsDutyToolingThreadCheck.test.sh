#!/usr/bin/env bash
## Behavioural check on S23.4, run rather than read: A WORK-DUTY NAMES BOTH ITS TOOLING THREAD AND ITS SESSION THREAD, and a tag from another run of its member wakes it.
## The schedule starts a duty with `--spawn-session --session-thread:event-track` (AgentsToolsScheduleWork). Held here:
##   1. --spawn-session takes --session-thread:<event-track|magic-team> and refuses any other mode, so the schedule's own start is not turned away;
##   2. a duty told to go with both threads is told in its session thread, and a record with no session thread falls back to its tooling thread (agent-log-thread), addressed to it;
##   3. a record with neither thread is not told to go, and says why.
## What a duty's record holds after a real start, and that no header reaches the team channel, is AgentsWorkDutySingleThreadCheck's.
## Offline: the fake curl is the Slack send identity check's. The tree is this rig's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyToolingThreadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigTmp/bin" "$rigSkills/magic-team" "$rigSkills/keeper-myx" "$rigSkills/magic-coordinator" "$rigData/board/backlog"
cp "$rigPackage/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
printf '#!/usr/bin/env bash\n## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER, records the context, and hands back.\ncat > "$RIG_SCENARIO/brief"\nprintf "📦 SubagentHandback\\n"\nprintf "rig-cli\\n" > "$MDAT_SPAWN_LAUNCH_MARKER"\n' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf -- '---\nexecutors: keeper-myx\nmaintainers: keeper-myx\nrequires-session-kind: standalone\n---\n# rig work-duty routine fixture\n' > "$rigSkills/keeper-myx/keeper-myx.work-duty.routine.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIG00002\nSLACK_CHANNEL_HUMAN_OWNER=CRIG00003\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
: > "$rigTmp/calls" ; : > "$rigTmp/bodies"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigEnv(){ ## the rig's environment, then the command
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" "$@"
}

echo "-- 1. --spawn-session takes the thread mode the schedule passes --"
rigBadOut="$( rigEnv bash -c 'cd "$MMDAPP" && exec bash "$RIG_FN" --spawn-session --session-thread:bogus --routine keeper-myx.work-duty.routine.md keeper-myx' 2>&1 < /dev/null )" ; rigBadRc=$?
rigAssert "a mode that is neither event-track nor magic-team is refused" "$rigBadRc:$( printf '%s' "$rigBadOut" | LC_ALL=C grep -c -F 'the mode is event-track or magic-team' )" "1:1"
rigGoodOut="$( rigEnv bash -c 'cd "$MMDAPP" && exec bash "$RIG_FN" --spawn-session --session-thread:event-track --routine keeper-myx.work-duty.routine.md keeper-myx' 2>&1 < /dev/null )" ; rigGoodRc=$?
rigAssert "event-track is taken: the start is made, and the option is not called invalid" "$rigGoodRc:$( printf '%s' "$rigGoodOut" | LC_ALL=C grep -c -F 'invalid option' )" "0:0"
[ "$rigGoodRc" = 0 ] || printf '%s\n' "$rigGoodOut" | head -5 | cut -c1-300
rigWaited=0
while LC_ALL=C grep -l -x -F 'status: spawn-started' "$rigWs/.local/agents/spawned"/*/*.spawn.md > /dev/null 2>&1 && [ "$rigWaited" -lt 60 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigRecord="$( ls "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | head -1 )"
rigAssert "its record names both its tooling thread and its session thread" "$( LC_ALL=C grep -c '^agent-log-thread: ' "$rigRecord" || : ):$( LC_ALL=C grep -c '^session-thread: ' "$rigRecord" || : )" "1:1"

echo "-- 2. a duty with no session thread is told to go in its tooling thread --"
rigDutyRecord(){ ## spawn id, extra header line -- a duty's record, and the sandbox it sits in
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	printf -- '---\nowner: keeper-myx\nstatus: spawn-started\n%s\n---\n' "$2" > "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
}
rigDismiss(){ ## spawn id -- one call of the dismissal, its run idle (the activity and the hold probes are the rig's)
	rigEnv bash -c '
		cd "$MMDAPP" && . "$RIG_FN" && . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherSchedule.include" || exit 98
		AgentsToolsManagerRunActivity(){ printf waiting ; }
		AgentsToolsSessionDismissHeld(){ return 1 ; }
		AgentsToolsScheduleDismiss "$MMDAPP/.local/agents/spawned/$1/$1.spawn.md" "rig is done"
	' rig-dismiss "$1" 2>&1 < /dev/null
}
: > "$rigTmp/bodies"
rigDutyRecord rig-duty-tooling 'agent-log-thread: CRIG00002:1760000000.000100'
rigToldOut="$( rigDismiss rig-duty-tooling )"
rigAssert "it is told to go" "$( printf '%s' "$rigToldOut" | LC_ALL=C grep -c -F 'rig-duty-tooling of keeper-myx is told to go' )" "1"
rigAssert "the post is DISMISSED, in its tooling thread, addressed to it" "$( LC_ALL=C grep -c -F '"text":"DISMISSED' "$rigTmp/bodies" || : ):$( LC_ALL=C grep -c -F '"channel":"CRIG00002"' "$rigTmp/bodies" || : ):$( LC_ALL=C grep -c -F '"thread_ts":"1760000000.000100"' "$rigTmp/bodies" || : )" "1:1:1"

echo "-- 3. a record with neither thread is not told to go --"
rigDutyRecord rig-duty-none ''
rigBodiesBefore="$( LC_ALL=C grep -c '' "$rigTmp/bodies" || : )"
rigNoneOut="$( rigDismiss rig-duty-none )"
rigAssert "it says it has neither thread, and posts nothing" "$( printf '%s' "$rigNoneOut" | LC_ALL=C grep -c -F 'neither a session thread nor a tooling thread' ):$( LC_ALL=C grep -c '' "$rigTmp/bodies" || : )" "1:$rigBodiesBefore"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ DUTY TOOLING THREAD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
echo "DUTY_TOOLING_THREAD: OK ($rigPasses assertions, offline)"
