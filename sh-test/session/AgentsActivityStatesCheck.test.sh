#!/usr/bin/env bash
## Behavioural check on S27.4: the registry and `ListAgents` show the states apart — thinking, in a
## tool, waiting, awaiting review, ended. A record whose process is gone is closed.
## Red before S27.4: a live run read `running` whatever it was doing, because no file said a tool
## call from thinking.
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
rigRun(){ ## folder, spawn id, status, activity word or empty
	mkdir -p "$rigSpawned/$1" "$rigWs/.local/agents/sessions/$2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: %s\n---\n' \
		"$2" "$2" "$1" "$rigHost" "$3" > "$rigSpawned/$1/$2.spawn.md"
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

echo "-- 1. a live run reads the word its own mark carries (S27.4) --"
rigRun rig-think rig-think-$$ spawn-started thinking ; rigAlive rig-think-$$
rigRun rig-tool rig-tool-$$ spawn-started "tool Read" ; rigAlive rig-tool-$$
rigRun rig-wait rig-wait-$$ spawn-started "tool Wait" ; rigAlive rig-wait-$$
rigRun rig-park rig-park-$$ spawn-succeeded ""
: > "$rigWs/.local/agents/sessions/rig-park-$$/parked"
rigRun rig-done rig-done-$$ spawn-succeeded "tool Read"
sleep 2
rigOut="$( rigView )"
rigAssert "a run thinking reads thinking"                "$( rigStateOf "$rigOut" "rig-think-$$" )" "thinking"
rigAssert "a run inside a tool reads in-tool"            "$( rigStateOf "$rigOut" "rig-tool-$$" )" "in-tool"
rigAssert "a run inside Wait reads waiting"              "$( rigStateOf "$rigOut" "rig-wait-$$" )" "waiting"
rigAssert "a parked run reads awaiting-review"           "$( rigStateOf "$rigOut" "rig-park-$$" )" "awaiting-review"
rigAssert "an ended run reads finished, its word ignored" "$( rigStateOf "$rigOut" "rig-done-$$" )" "finished"

echo "-- 2. a word left by a dead process is never the answer (the silent-stale case) --"
rigRun rig-stale rig-stale-$$ spawn-started "tool Read"
rigAssert "no process, no tool: the record is not in-tool" "$( rigStateOf "$( rigView )" "rig-stale-$$" )" "unclosed"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ ACTIVITY STATES CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'ACTIVITY_STATES: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
