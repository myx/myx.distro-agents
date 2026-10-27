#!/usr/bin/env bash
## Behavioural check on a work-duty that starts again, run rather than read: A WORK-DUTY IS ONE SESSION WITH ONE THREAD.
## The schedule starts a member's duty (AgentsToolsScheduleSpawn, key `work-duty.<member>`) whenever the member has none running: on
## demand, on a tag, and to keep its cache warm. Each of those starts was a session of its own, and each session opened its own
## header in the team channel (":thread: Session Work duty · <member>") -- a new one every few minutes.
## Held: two starts of one member's duty make ONE root post in the team channel; the second start joins the session the first made
## (the same session id on both spawn records, the first start's id kept in schedule/duty-session/<member>); the thread of the
## session is the same on both; the member is not announced as brought in again; and a duty of another member is its own session.
## Offline: the fake curl is the Slack send identity check's; the console is a stand-in that hands back. The tree is this rig's own.
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

## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWorkDutySingleThreadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## A filled sandbox input/ loses its write bits (AgentsToolsSpawnSandboxFillInput's own
## read-only-by-mode contract), reached now that --intern-root-harness spawns for real.
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigSkills/keeper-myx" "$rigSkills/magic-coordinator" "$rigData/board/backlog"

cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh"
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
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator, magic-librarian\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
## A board item for the --from-board source mode.
printf -- '---\ntype: task\n---\n\nRIG-BOARD-MARKER-TEXT\n' > "$rigData/board/backlog/task-rig-routine.md"
## A plain file for the --from-file source mode.
printf 'RIG-FILE-MARKER-TEXT\n' > "$rigTmp/task-file.txt"


rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## The team channel the session roots go to, and the duty routines of two members.
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
mkdir -p "$rigSkills/keeper-rig2"
printf '# rig armed\n' > "$rigSkills/keeper-rig2/keeper-rig2.armed.md"
for rigMember in keeper-myx keeper-rig2 ; do
	printf -- '---\nexecutors: %s\nmaintainers: %s\nrequires-session-kind: standalone\n---\n# rig work-duty routine fixture\n' "$rigMember" "$rigMember" > "$rigSkills/$rigMember/$rigMember.work-duty.routine.md"
done
: > "$rigTmp/calls" ; : > "$rigTmp/bodies"

## One start of a member's duty the way the schedule makes it, and the wait for its result file.
rigDuty(){ ## member
	rm -f "$rigWs/.local/agents/schedule/starting/work-duty.$1.rc"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && . "$RIG_FN" && . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherLoop.include" \
				&& AgentsToolsScheduleSpawn "work-duty.$1" --routine "$1.work-duty.routine.md" "$1"
		' rig-duty-wrapper "$1" > "$rigTmp/duty.$1.out" 2>&1 < /dev/null
	local waited=0
	while [ ! -f "$rigWs/.local/agents/schedule/starting/work-duty.$1.rc" ] && [ "$waited" -lt 120 ] ; do sleep 1 ; waited=$(( waited + 1 )) ; done
	## The run closes its record after the start came back: wait for that, so the tree is quiet when the next start looks at it.
	waited=0
	while LC_ALL=C grep -l -x -F 'status: spawn-started' "$rigWs/.local/agents/spawned"/*/*.spawn.md > /dev/null 2>&1 && [ "$waited" -lt 60 ] ; do sleep 1 ; waited=$(( waited + 1 )) ; done
	cat "$rigWs/.local/agents/schedule/starting/work-duty.$1.rc" 2> /dev/null || echo norc
}
rigRoots(){ LC_ALL=C grep -c -F '"tracking":"session-root"' "$rigTmp/bodies" || : ; }
rigSessions(){ ## member -- the session ids of its spawn records, oldest first, one a line
	local sessionsFile
	for sessionsFile in $( ls -tr "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null ) ; do
		[ "$( LC_ALL=C sed -n 's/^owner: //p' "$sessionsFile" | head -1 )" = "$1" ] || continue
		LC_ALL=C sed -n 's/^session-id: //p' "$sessionsFile" | head -1
	done
}

echo "-- two starts of one member's duty are one session with one thread --"
rigRc1="$( rigDuty keeper-myx )"
rigAssert "the first start ended well" "$rigRc1" "0"
rigAssert "it opened one header in the team channel" "$( rigRoots )" "1"
rigRc2="$( rigDuty keeper-myx )"
rigAssert "the second start ended well" "$rigRc2" "0"
rigAssert "it opened no second header: the team channel has one" "$( rigRoots )" "1"
rigFirst="$( rigSessions keeper-myx | sed -n 1p )"
rigSecond="$( rigSessions keeper-myx | sed -n 2p )"
rigAssert "both starts are in one session" "$( [ -n "$rigFirst" ] && [ "$rigFirst" = "$rigSecond" ] && echo same || echo "differ:$rigFirst:$rigSecond" )" "same"
rigAssert "the session is kept for the next start" "$( cat "$rigWs/.local/agents/schedule/duty-session/keeper-myx" 2> /dev/null )" "$rigFirst"
rigAssert "the member is not announced as brought in the second time: no reply says it joined" "$( LC_ALL=C grep -c -F ' joined: ' "$rigTmp/bodies" || : )" "0"
echo "-- the duty of another member is its own session --"
rigDuty keeper-rig2 > /dev/null
rigAssert "a second header, for the other member" "$( rigRoots )" "2"
rigAssert "in a session of its own" "$( [ "$( rigSessions keeper-rig2 | sed -n 1p )" != "$rigFirst" ] && echo own || echo shared )" "own"

echo "-- two starts of one member's duty at the same moment make one session --"
## A third member, so the roots and sessions counted here are this section's alone. Two starts, the schedule's and a console's, are made together.
mkdir -p "$rigSkills/keeper-rig3"
printf '# rig armed\n' > "$rigSkills/keeper-rig3/keeper-rig3.armed.md"
printf -- '---\nexecutors: keeper-rig3\nmaintainers: keeper-rig3\nrequires-session-kind: standalone\n---\n# rig work-duty routine fixture\n' > "$rigSkills/keeper-rig3/keeper-rig3.work-duty.routine.md"
rigRootsBefore="$( rigRoots )"
rigStartOnce(){ ## out file
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c 'cd "$MMDAPP" && exec bash "$RIG_FN" --spawn-session --routine keeper-rig3.work-duty.routine.md keeper-rig3' > "$1" 2>&1 < /dev/null
}
rigStartOnce "$rigTmp/race.1" &
rigRacePid1=$!
rigStartOnce "$rigTmp/race.2" &
rigRacePid2=$!
wait "$rigRacePid1" "$rigRacePid2" 2> /dev/null
rigWaited=0
while LC_ALL=C grep -l -x -F 'status: spawn-started' "$rigWs/.local/agents/spawned"/*/*.spawn.md > /dev/null 2>&1 && [ "$rigWaited" -lt 60 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "the member has duty records in one session only, however the two starts fell" "$( rigSessions keeper-rig3 | LC_ALL=C sort -u | wc -l | tr -d ' ' )" "1"
rigAssert "one header in the team channel for the two starts" "$(( $( rigRoots ) - rigRootsBefore ))" "1"
rigAssert "the kept session is that session" "$( cat "$rigWs/.local/agents/schedule/duty-session/keeper-rig3" 2> /dev/null )" "$( rigSessions keeper-rig3 | sed -n 1p )"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ WORK DUTY SINGLE THREAD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
echo "WORK_DUTY_SINGLE_THREAD: OK ($rigPasses assertions, offline)"
