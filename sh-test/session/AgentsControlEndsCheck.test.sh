#!/usr/bin/env bash
## Behavioural check on S27.7: a session's control process ends when its agent ends, and closes
## the record. Today an `--intern-session-control --run` outlives its agent by a day, so the
## registry and the console keep showing an ended run as started.
## Red before S27.7: a control thread whose session has a run that ended with no record closed
## neither the record nor itself, and kept ticking.
## Offline: the workspace, its board and its spawn records are this rig's own temp tree. No socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsControlEndsCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigOne in $rigPids ; do kill -KILL "$rigOne" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigWs/.local/.agents" "$rigData/board/running" "$rigSpawned/rig-end" "$rigWs/.local/agents/sessions/rig-session/control"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSESSION_CONTROL_TICK_SECONDS=1\nSESSION_CONTROL_CLOSING_SECONDS=2\nNO_PROXY=*\n' > "$rigWs/.local/.agents/magic-team.agent.env"
mkdir -p "$rigTmp/bin" && printf '#!/bin/sh\ncat > /dev/null\nexit 7\n' > "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl"
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

echo "-- 1. a control thread ends once its session's run has ended, and closes the record (S27.7) --"
## The run's record says started, and no process runs as it: the run has ended and nothing closed
## its record. This is exactly what the control thread now has to settle.
printf -- '---\nsession-id: rig-session\nspawn-id: rig-run\nparent-spawn-id: none\ntracking-name: rig-end\nhost: %s\nowner: keeper-myx\nstatus: spawn-started\nstarted-at: 2026-11-01 00:00 +0000\n---\n' \
	"$rigHost" > "$rigSpawned/rig-end/rig-run.spawn.md"
touch -t 202611010000 "$rigSpawned/rig-end/rig-run.spawn.md" "$rigWs/.local/agents/sessions/rig-session" 2> /dev/null || :
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
	MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	bash "$rigFn" --intern-session-control --run --session-id rig-session ) > "$rigTmp/control.out" 2>&1 &
rigControlPid=$!
rigPids="$rigPids $rigControlPid"
disown "$rigControlPid" 2> /dev/null || :
rigWaited=0
while [ "$rigWaited" -lt 90 ] && kill -0 "$rigControlPid" 2> /dev/null ; do
	sleep 1 ; rigWaited=$(( rigWaited + 1 ))
done
rigStatus="$( LC_ALL=C sed -n 's/^status: //p' "$rigSpawned/rig-end/rig-run.spawn.md" 2> /dev/null | head -1 )"
rigAssert "the run's record is closed"                  "$rigStatus" "spawn-ended-without-close"
rigAssert "the control thread ended by itself"          "$( kill -0 "$rigControlPid" 2> /dev/null && printf running || printf ended )" ended

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ CONTROL ENDS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'CONTROL_ENDS: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
