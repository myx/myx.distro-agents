#!/usr/bin/env bash
## Behavioural check on S27.0: the registry's state per run is re-checked when its TTL expires, on
## demand and by the rig's background thread, and an ended run's record is closed by that check
## (S23 item 6: no view ever shows running for a process that is gone).
## Red before S27.0: a read of the registry leaves a record saying `spawn-started` while its
## process is gone, for as long as the record's own files are recent.
## Offline: the workspace, its board and its spawn records are this rig's own temp tree; no socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigHouse="$rigPkg/sh-lib/magic/AgentsTools.SpawnHousekeeping.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHouse" ] || rigRefuse "the spawn housekeeping include is not at the origin: $rigHouse"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRegistryTtlCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigWs/.local/.agents" "$rigData/board/running" "$rigSpawned/rig-gone" "$rigSpawned/rig-live" "$rigWs/.local/agents/sessions/rig-gone" "$rigWs/.local/agents/sessions/rig-live"
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
rigRecord(){ ## folder, spawn id, started-at -- tracking-name is the folder, which is how a row finds its record
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-started\nstarted-at: %s\n---\n' \
		"$2" "$2" "$1" "$rigHost" "$3" > "$rigSpawned/$1/$2.spawn.md"
}
rigStatus(){ LC_ALL=C sed -n 's/^status: //p' "$1" 2> /dev/null | head -1 ; }
rigRead(){ ## the demand read: the registry rendered, which is where the TTL check begins
	## The check is started detached, so this call holds its own shell open while it runs: a shell
	## that exits takes the check with it before it has read a record.
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT=magic-coordinator \
		bash -c '. "$1" ; . "$2" ; AgentsToolsRegistryRenderSpawnedSessions agents ; sleep 20' rig "$rigPkg/sh-lib/team-data/AgentsTools.Registries.include" "$rigHouse" 2>&1
}

echo "-- 1. a read past the TTL closes the record of a run whose process is gone (S27.0) --"
## A record well past the stale window, whose process does not run: it is what the TTL check is for.
rigRecord rig-gone rig-gone-$$ "2026-11-01 00:00 +0000"
for rigOld in "$rigSpawned/rig-gone"/*.spawn.md "$rigSpawned/rig-gone" "$rigWs/.local/agents/sessions/rig-gone" ; do
	touch -t 202611010000 "$rigOld" 2> /dev/null || :
done
: > "$rigSpawned/rig-gone/rig-gone-$$.output" 2> /dev/null || :
touch -t 202611010000 "$rigSpawned/rig-gone/rig-gone-$$.output" 2> /dev/null || :
rigRead > /dev/null
rigWaited=0
while [ "$( rigStatus "$rigSpawned/rig-gone/rig-gone-$$.spawn.md" )" = "spawn-started" ] && [ "$rigWaited" -lt 30 ] ; do
	sleep 1 ; rigWaited=$(( rigWaited + 1 ))
done
rigAssert "the ended run's record is closed by the check"  "$( rigStatus "$rigSpawned/rig-gone/rig-gone-$$.spawn.md" )" "spawn-ended-without-close"

echo "-- 2. a control: a run whose process is alive keeps its record open --"
python3 -I -B -c 'import time; time.sleep(120)' -- --session-id "rig-live-$$" > /dev/null 2>&1 &
rigLivePid=$!
rigRecord rig-live "rig-live-$$" "2026-11-01 00:00 +0000"
for rigOld in "$rigSpawned/rig-live" "$rigWs/.local/agents/sessions/rig-live" ; do
	touch -t 202611010000 "$rigOld" 2> /dev/null || :
done
touch -t 202611010000 "$rigSpawned/rig-live/rig-live-$$.spawn.md" 2> /dev/null || :
rigRead > /dev/null
sleep 3
rigAssert "the live run's record still says started"       "$( rigStatus "$rigSpawned/rig-live/rig-live-$$.spawn.md" )" "spawn-started"
kill -KILL "$rigLivePid" 2> /dev/null || :

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ REGISTRY TTL CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'REGISTRY_TTL: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
