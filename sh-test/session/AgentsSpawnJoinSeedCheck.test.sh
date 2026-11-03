#!/usr/bin/env bash
## Behavioural check on the CheckList a joining run is seeded with (S6.13): where a run joins a session,
## its list takes the items its brief states, the items its arguments state, and only the routine's steps
## stated for all participants. The run that opens a session keeps the whole routine's steps. Held against
## the real spawn proxy, with a console stand-in that records the dispatch and runs no model. Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the fixture that ends control threads is missing from the package"
. "$rigTest/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's temp fixture is missing from the package"
rigTmp="$( rigTempDir AgentsSpawnJoinSeedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigTmp/home/.agents/magic-team" "$rigSkills/magic-team" "$rigSkills/keeper-myx" "$rigSkills/magic-coordinator" "$rigData/board/running" "$rigData/inboxes/keeper-myx"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the first context.' \
	'[ -s "$RIG_SCENARIO/brief" ] && { cat > /dev/null ; exit 0 ; }' \
	'rigContext="$( cat )"' \
	'case "$rigContext" in "Your previous run on this task ended without calling SubagentHandback."*) exit 0 ;; esac' \
	'printf "%s\n" "$rigContext" > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/keeper-myx/keeper-myx.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

## A routine of two executor-only steps and two stated for all participants, in the wording the routine
## uses for a step every participant runs.
printf -- '%s\n' \
	'---' 'type: routine' 'executors: keeper-myx' 'maintainers: keeper-myx' 'requires-session-kind: coworking' '---' \
	'# rig seeded routine — the actual procedure' '' \
	'# Steps' '' \
	'1. **rig-lead**: the executor leads the work as a participant.' '' \
	'2. **rig-shared-work**: All participants: each does its own part of the work.' '' \
	'3. **rig-dispatch**: the executor dispatches the pieces.' '' \
	'# Closure steps' '' \
	'1. **rig-close**: post the session substance into the session thread.' '' \
	'2. **rig-shared-close**: All participants: each checks its own part of the session.' \
	> "$rigSkills/magic-team/magic-team.rigseeded.routine.md"

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFail=$(( rigFail + 1 ))
	fi
}
rigSpawn(){ ## member, the brief, then the further arguments of the proxy
	local rigMember="$1" rigBrief="$2" ; shift 2
	: > "$rigTmp/brief"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" RIG_MEMBER="$rigMember" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$RIG_MEMBER" --dispatch-doc:none --wait --context rig-join-seed "$@"
		' rig-spawn "$@" <<< "$rigBrief" 2>&1
}
## One member's list, as written; `no-list` where the seed made none.
rigList(){ ## member
	local rigFile
	rigFile="$( find "$rigWs/.local/agents" -name "$1.checklist.md" 2> /dev/null | head -1 )"
	[ -f "$rigFile" ] && cat "$rigFile" || printf 'no-list'
}
rigNewestId(){ ## a header of the newest spawn record
	local rigRecord
	rigRecord="$( ls -t "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | head -1 )"
	[ -n "$rigRecord" ] || return 0
	LC_ALL=C sed -n "s/^$1: //p" "$rigRecord" | head -1
}

echo "-- the run that opens a session keeps the whole routine --"
rigOpened="$( rigSpawn keeper-myx 'RIG-BRIEF-OPEN' --routine rigseeded --session-new --checklist-item RIG-ARG-ONE )"
grep -q 'RIG-BRIEF-OPEN' "$rigTmp/brief" || rigRefuse "the console never received the opening context: $( printf '%s\n' "$rigOpened" | LC_ALL=C grep -m1 ERROR )"
[ "$( rigNewestId start-context )" = spawned ] || rigRefuse "the opening spawn started no session, so there is nothing to join"
rigSessionId="$( rigNewestId session-id )"
rigAssert "the opening run's list holds every step of its routine, and its argument item" \
	"$( rigList keeper-myx )" '- [ ] rig-lead
- [ ] rig-shared-work
- [ ] rig-dispatch
- [ ] rig-close
- [ ] rig-shared-close
- [ ] RIG-ARG-ONE'

echo "-- the run that joins keeps its own items and only the all-participants steps --"
rigJoined="$( rigSpawn magic-coordinator $'RIG-JOIN-BRIEF\n\n## Formal task\n\n- RIG-JOIN-STEP-ONE\n- RIG-JOIN-STEP-TWO\n' --routine rigseeded --session-id "$rigSessionId" --checklist-item RIG-JOIN-ARG )"
grep -q 'RIG-JOIN-BRIEF' "$rigTmp/brief" || rigRefuse "the console never received the joining context: $( printf '%s\n' "$rigJoined" | LC_ALL=C grep -m1 ERROR )"
rigAssert "the joining run joined that session" "$( rigNewestId start-context ):$( rigNewestId session-id )" "joined:$rigSessionId"
rigAssert "the joining run's list holds the items its brief states, in order" \
	"$( rigList magic-coordinator | LC_ALL=C grep -c -x -e '- \[ \] RIG-JOIN-STEP-ONE' -e '- \[ \] RIG-JOIN-STEP-TWO' )" 2
rigAssert "and the item its argument states" \
	"$( rigList magic-coordinator | LC_ALL=C grep -c -x -F -- '- [ ] RIG-JOIN-ARG' )" 1
rigAssert "and the routine's steps stated for all participants" \
	"$( rigList magic-coordinator | LC_ALL=C grep -c -x -e '- \[ \] rig-shared-work' -e '- \[ \] rig-shared-close' )" 2
rigAssert "and no step the executor alone runs" \
	"$( rigList magic-coordinator | LC_ALL=C grep -c -x -e '- \[ \] rig-lead' -e '- \[ \] rig-dispatch' -e '- \[ \] rig-close' )" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ THIS SPAWN JOIN SEED CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_JOIN_SEED: OK (%d assertions, offline)\n' "$rigPass"
