#!/usr/bin/env bash
## Behavioural check on S27.2's record half, as magic-architect's round-2 review required it: a
## parked run's record reads `awaiting-review` in the view, never started or running, and the park
## mark is the one home of that fact.
## Red before this half landed: the proxy wrote no such word, the render derive had no branch, so a
## parked record rendered `unclosed`, and nothing read the mark at all.
## Offline: the workspace, its board and its spawn records are this rig's own temp tree. No socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPkg/sh-lib/team-data/AgentsTools.Registries.include" ] || rigRefuse "the registries include is not at the origin"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsParkRecordCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigWs/.local/.agents" "$rigData/board/running" "$rigSpawned/rig-parked" "$rigSpawned/rig-done" "$rigWs/.local/agents/sessions/rig-parked-$$" "$rigWs/.local/agents/sessions/rig-done-$$"
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
rigRecord(){ ## folder, spawn id, status, session id (default: the spawn id)
	local recSession="${4:-$2}"
	mkdir -p "$rigSpawned/$1" "$rigWs/.local/agents/sessions/$2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: %s\n---\n' \
		"$recSession" "$2" "$1" "$rigHost" "$3" > "$rigSpawned/$1/$2.spawn.md"
}
rigView(){ ## the registry's agent view, and its session view
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT=magic-coordinator \
		bash -c '. "$1" ; AgentsToolsRegistryRenderSpawnedSessions "$2"' rig "$rigPkg/sh-lib/team-data/AgentsTools.Registries.include" "$1" 2>&1
}
rigStateOf(){ ## view output, spawn id -- the state column of that row
	printf '%s\n' "$1" | LC_ALL=C awk -v want="$2" '$8 == want { print $13 }' | head -1
}

echo "-- 1. a parked run's record reads awaiting-review in the view (S27.2) --"
rigRecord rig-parked rig-parked-$$ spawn-succeeded
: > "$rigWs/.local/agents/sessions/rig-parked-$$/parked"
rigRecord rig-done rig-done-$$ spawn-succeeded
rigOut="$( rigView agents )"
rigAssert "the parked row reads awaiting-review"          "$( rigStateOf "$rigOut" "rig-parked-$$" )" "awaiting-review"
rigAssert "the settled row still reads finished"          "$( rigStateOf "$rigOut" "rig-done-$$" )" "finished"
rigAssert "the session view reads it too"                 "$( rigView sessions | LC_ALL=C awk 'index( $0, "awaiting-review" ) { found++ } END { print found + 0 }' )" 1

echo "-- 2. a control: the mark taken away leaves it finished again --"
rm -f "$rigWs/.local/agents/sessions/rig-parked-$$/parked"
rigAssert "with no mark the row reads finished"           "$( rigStateOf "$( rigView agents )" "rig-parked-$$" )" "finished"

## THE MARK GOES WHEN THE RECORD CLOSES (S27.2): a settled record must never read awaiting-review.
echo "-- 4. a close through the proxy takes the mark away --"
mkdir -p "$rigSpawned/rig-closing-$$"
printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-started\n---\n' \
	"rig-closing-$$" "rig-closing-$$" "rig-closing-$$" "$rigHost" > "$rigSpawned/rig-closing-$$/rig-closing-$$.spawn.md"
mkdir -p "$rigWs/.local/agents/sessions/rig-closing-$$"
: > "$rigWs/.local/agents/sessions/rig-closing-$$/parked"
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
	MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SPAWN_AGENT=magic-coordinator \
	bash -c '. "$1" ; AgentsToolsSpawnProxyCloseSandbox "$2" succeeded 0 "the rig closed it"' rig "$rigPkg/sh-lib/session/AgentsTools.SpawnSandbox.include" \
	"$rigSpawned/rig-closing-$$/rig-closing-$$.spawn.md" ) > /dev/null 2>&1
rigAssert "the record is closed"                          "$( LC_ALL=C sed -n 's/^status: //p' "$rigSpawned/rig-closing-$$/rig-closing-$$.spawn.md" | head -1 )" "spawn-succeeded"
rigAssert "and its mark is gone"                          "$( [ -f "$rigWs/.local/agents/sessions/rig-closing-$$/parked" ] && printf present || printf gone )" "gone"
rigAssert "so the row reads finished, not awaiting-review" "$( rigStateOf "$( rigView agents )" "rig-closing-$$" )" "finished"

echo "-- 3. a record whose two ids differ, its mark under the id the harness holds (S27.2) --"
rigRecord rig-split rig-split-$$ spawn-succeeded rig-sess-split-$$
: > "$rigWs/.local/agents/sessions/rig-split-$$/parked"
rigAssert "the parked row reads awaiting-review though its two ids differ" "$( rigStateOf "$( rigView agents )" "rig-split-$$" )" "awaiting-review"

## A MARK LEFT BY A RUN THAT STARTED AGAIN IS NOT A PARKED RUN (S27.2): the liveness check comes
## first, so a live run reads what it is doing and never awaiting-review. Read from the derive
## itself, which is where the order lives.
echo "-- 5. a live run carrying a stale mark reads what it is doing, not awaiting-review --"
mkdir -p "$rigSpawned/rig-lively-$$" "$rigWs/.local/agents/sessions/rig-lively-$$"
: > "$rigWs/.local/agents/sessions/rig-lively-$$/parked"
printf '1 %s thinking\n' "$( date +%s )" > "$rigWs/.local/agents/sessions/rig-lively-$$/activity"
rigAssert "a live run with a stale mark reads thinking"  "$( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash -c '. "$1" ; AgentsToolsRegistryDeriveState spawn-succeeded running rig-lively-$$ rig-lively-$$' rig "$rigPkg/sh-lib/team-data/AgentsTools.Registries.include" 2>&1 )" "thinking"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ PARK RECORD CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'PARK_RECORD: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
