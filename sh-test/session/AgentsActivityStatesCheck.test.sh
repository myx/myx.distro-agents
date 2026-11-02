#!/usr/bin/env bash
## Behavioural check on S27.4: the registry and `ListAgents` show one word each, in two columns.
## The process column reads running, gone, remote or unknown. The state column reads thinking, tool, waiting,
## idling, parked, finished, failed or unclosed. A record whose process is gone is closed.
## Red before: a live run read `running` whatever it was doing, then `in-tool`, `awaiting-review` and `unknown-foreign`.
## Offline: the workspace, its board and its spawn records are this rig's own temp tree. No socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPkg/sh-lib/team-data/AgentsTools.Registries.include" ] || rigRefuse "the registries include is not at the origin"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsActivityStatesCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigOne in $rigPids ; do kill -KILL "$rigOne" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigWs/.local/.agents" "$rigData/board/running" "$rigSpawned" "$rigWs/.local/agents/sessions"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigRun(){ ## folder, spawn id, status, activity word or empty, host (this one where not given)
	mkdir -p "$rigSpawned/$1" "$rigWs/.local/agents/sessions/$2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: %s\n---\n' \
		"$2" "$2" "$1" "${5:-$rigHost}" "$3" > "$rigSpawned/$1/$2.spawn.md"
	[ -z "${4:-}" ] || printf '1 %s %s\n' "$( date +%s )" "$4" > "$rigWs/.local/agents/sessions/$2/activity"
}
rigAlive(){ ## spawn id -- a process carrying the id, so the row reads running
	python3 -I -B -c 'import time; time.sleep(180)' -- --session-id "$1" > /dev/null 2>&1 &
	rigPids="$rigPids $!" ; disown "$!" 2> /dev/null || :
}
rigView(){ ## the registry's agent view
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT=magic-coordinator \
		bash -c '. "$1" ; AgentsToolsRegistryRenderSpawnedSessions agents' rig "$rigPkg/sh-lib/team-data/AgentsTools.Registries.include" 2>&1
}
rigStateOf(){ ## view output, spawn id
	printf '%s\n' "$1" | LC_ALL=C awk -v want="$2" '$8 == want { print $13 }' | head -1
}
rigLiveOf(){ ## view output, spawn id -- the process column
	printf '%s\n' "$1" | LC_ALL=C awk -v want="$2" '$8 == want { print $12 }' | head -1
}

echo "-- 1. a live run reads the word its own mark carries (S27.4) --"
rigRun rig-think rig-think-$$ spawn-started thinking ; rigAlive rig-think-$$
rigRun rig-tool rig-tool-$$ spawn-started "tool Read" ; rigAlive rig-tool-$$
rigRun rig-wait rig-wait-$$ spawn-started "tool Wait" ; rigAlive rig-wait-$$
rigRun rig-idle rig-idle-$$ spawn-started "idle" ; rigAlive rig-idle-$$
rigRun rig-ask rig-ask-$$ spawn-started "tool AskQuestion" ; rigAlive rig-ask-$$
rigRun rig-park rig-park-$$ spawn-succeeded ""
: > "$rigWs/.local/agents/sessions/rig-park-$$/parked"
rigRun rig-done rig-done-$$ spawn-succeeded "tool Read"
sleep 2
rigOut="$( rigView )"
rigAssert "a run thinking reads thinking"                "$( rigStateOf "$rigOut" "rig-think-$$" )" "thinking"
rigAssert "a run inside a tool reads tool"              "$( rigStateOf "$rigOut" "rig-tool-$$" )" "tool"
rigAssert "a run inside Wait on a named source reads waiting" "$( rigStateOf "$rigOut" "rig-wait-$$" )" "waiting"
rigAssert "a run inside an ask reads waiting"           "$( rigStateOf "$rigOut" "rig-ask-$$" )" "waiting"
rigAssert "a run in a wait on its floor alone reads idling" "$( rigStateOf "$rigOut" "rig-idle-$$" )" "idling"
rigAssert "a parked run reads parked"                   "$( rigStateOf "$rigOut" "rig-park-$$" )" "parked"
rigAssert "an ended run reads finished, its word ignored" "$( rigStateOf "$rigOut" "rig-done-$$" )" "finished"
rigAssert "the process column of the five live runs reads running" "$( for rigId in think tool wait idle ask ; do rigLiveOf "$rigOut" "rig-$rigId-$$" ; done | LC_ALL=C sort -u | tr '\n' ' ' )" "running "
rigAssert "the process column of a parked and of an ended run reads gone" "$( rigLiveOf "$rigOut" "rig-park-$$" ) $( rigLiveOf "$rigOut" "rig-done-$$" )" "gone gone"

echo "-- 2. a word left by a dead process is never the answer (the silent-stale case) --"
rigRun rig-stale rig-stale-$$ spawn-started "tool Read"
rigStaleOut="$( rigView )"
rigAssert "no process, no tool: the record reads unclosed, not tool" "$( rigStateOf "$rigStaleOut" "rig-stale-$$" )" "unclosed"
rigAssert "and its process reads gone" "$( rigLiveOf "$rigStaleOut" "rig-stale-$$" )" "gone"

echo "-- 3. a run of another host, and a run that names no host, are told apart in the process column --"
rigRun rig-remote rig-remote-$$ spawn-started "" rig-other-host
rigRun rig-nohost rig-nohost-$$ spawn-started "" -
rigRun rig-remote-done rig-remote-done-$$ spawn-succeeded "" rig-other-host
rigOtherOut="$( rigView )"
rigAssert "a run of another host reads remote" "$( rigLiveOf "$rigOtherOut" "rig-remote-$$" )" "remote"
rigAssert "its open record reads unclosed: unknown-foreign is no state" "$( rigStateOf "$rigOtherOut" "rig-remote-$$" )" "unclosed"
rigAssert "a run that names no host reads unknown" "$( rigLiveOf "$rigOtherOut" "rig-nohost-$$" )" "unknown"
rigAssert "its open record reads unclosed too" "$( rigStateOf "$rigOtherOut" "rig-nohost-$$" )" "unclosed"
rigAssert "a closed run of another host keeps what its record says" "$( rigStateOf "$rigOtherOut" "rig-remote-done-$$" )" "finished"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ ACTIVITY STATES CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'ACTIVITY_STATES: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
