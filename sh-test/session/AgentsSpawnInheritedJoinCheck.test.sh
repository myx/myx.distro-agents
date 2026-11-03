#!/usr/bin/env bash
## Behavioural check on a run that INHERITS its session (S21.20 chapter and S6.13 seed): a spawn that
## names no --session-id but whose caller hands it a session joins that session, and the same two effects
## hold as for a named join. The chapter is written from the joining member and its description. The list
## takes its brief's items, its argument items, and only the routine's steps stated for all participants.
## Held against the real spawn proxy with a console stand-in that records the dispatch. Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the fixture that ends control threads is missing from the package"
. "$rigTest/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's temp fixture is missing from the package"
rigTmp="$( rigTempDir AgentsSpawnInheritedJoinCheck )" || exit 1
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
for rigMember in keeper-myx magic-coordinator ; do
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
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
rigSpawn(){ ## member, the brief, the caller's session words (NAME=value, space separated), then the proxy's arguments
	local rigMember="$1" rigBrief="$2" rigInherit="$3" ; shift 3
	: > "$rigTmp/brief"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" RIG_MEMBER="$rigMember" RIG_INHERIT="$rigInherit" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			for rigWord in $RIG_INHERIT ; do export "${rigWord?}" ; done
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$RIG_MEMBER" --dispatch-doc:none --wait --context rig-inherited-join "$@"
		' rig-spawn "$@" <<< "$rigBrief" 2>&1
}
rigList(){ ## member -- its list, as written; `no-list` where the seed made none
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
rigChapter(){ ## session id
	[ -f "$rigWs/.local/agents/sessions/$1/chapter" ] || return 0
	cat "$rigWs/.local/agents/sessions/$1/chapter"
}

echo "-- a session opened by a run of its own --"
rigOpened="$( rigSpawn keeper-myx 'RIG-BRIEF-OPEN' '' --routine rigseeded --session-new --checklist-item RIG-ARG-ONE )"
grep -q 'RIG-BRIEF-OPEN' "$rigTmp/brief" || rigRefuse "the console never received the opening context: $( printf '%s\n' "$rigOpened" | LC_ALL=C grep -m1 ERROR )"
[ "$( rigNewestId start-context )" = spawned ] || rigRefuse "the opening spawn started no session, so there is nothing to inherit"
rigSessionId="$( rigNewestId session-id )"

echo "-- a run that inherits that session, with no --session-id said --"
rigJoined="$( rigSpawn magic-coordinator $'RIG-INHERIT-BRIEF\n\n## Formal task\n\n- RIG-INHERIT-STEP\n' "MDAT_SESSION_ID=$rigSessionId MDAT_SPAWN_SESSION_ID=rig-run-inherited" --routine rigseeded --checklist-item RIG-INHERIT-ARG --description 'the inherited stage' )"
grep -q 'RIG-INHERIT-BRIEF' "$rigTmp/brief" || rigRefuse "the console never received the inheriting context: $( printf '%s\n' "$rigJoined" | LC_ALL=C grep -m1 ERROR )"
rigAssert "it joins the session it inherited, and its own run id is not that session's" \
	"$( rigNewestId start-context ):$( rigNewestId session-id ):$( [ "$( rigNewestId spawn-id )" = "$rigSessionId" ] && printf same || printf own )" "joined:$rigSessionId:own"
rigAssert "the chapter is written from the joining member and its description" \
	"$( rigChapter "$rigSessionId" )" "magic-coordinator: the inherited stage"
rigAssert "its list holds the item its brief states" \
	"$( rigList magic-coordinator | LC_ALL=C grep -c -x -F -- '- [ ] RIG-INHERIT-STEP' )" 1
rigAssert "and the item its argument states" \
	"$( rigList magic-coordinator | LC_ALL=C grep -c -x -F -- '- [ ] RIG-INHERIT-ARG' )" 1
rigAssert "and the routine's steps stated for all participants" \
	"$( rigList magic-coordinator | LC_ALL=C grep -c -x -e '- \[ \] rig-shared-work' -e '- \[ \] rig-shared-close' )" 2
rigAssert "and no step the executor alone runs" \
	"$( rigList magic-coordinator | LC_ALL=C grep -c -x -e '- \[ \] rig-lead' -e '- \[ \] rig-dispatch' -e '- \[ \] rig-close' )" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ THIS SPAWN INHERITED JOIN CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_INHERITED_JOIN: OK (%d assertions, offline)\n' "$rigPass"
