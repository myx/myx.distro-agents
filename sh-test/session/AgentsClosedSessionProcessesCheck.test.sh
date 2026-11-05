#!/usr/bin/env bash
## Behavioural check on S5.2: a process left over from a closed or long-idle session is closed by the tooling.
## A session's detached processes are kept in its folder, each with the pid it started and when that pid began
## (`sessions/<session>/processes/process-N.{pid,began,out,err}`). When its session ends, nothing closes them, and a
## command a run left detached goes on writing for as long as it likes. The advance pass closes them.
## Held here, each case its own session folder and its own stand-in:
##   1. a session whose every run is closed, holding one detached process: the pass ends it, and marks it closed.
##   2. a session whose run is alive holds the same: the pass leaves it alone, and its run goes on.
##   3. a session whose folder is gone, a year old by its record: nothing of another tree is touched, and the pass
##      names nothing.
##   4. control: a session whose process names a pid that is no longer the process that began then. The pass ends
##      NOTHING, since a pid that has been given to another process is another process.
## Red before S5.2: case 1's process is still there, and the pass named nothing.
## Offline: every tree is the rig's own, the fake curl opens no socket, and every process this check starts is ended by it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigHouse="$rigPkg/sh-lib/magic/AgentsTools.SpawnHousekeeping.include"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHouse" ] || rigRefuse "the housekeeping include is not at the origin: $rigHouse"
. "$rigPkg/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing"
. "$rigPkg/sh-test/check-fixtures/rig-blocking-stand-in.include.sh" || rigRefuse "the rig's stand-in helper is missing"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsClosedSessionProcessesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
rigStopAll(){ rigBlockingStandInEnd $rigStandPids ; rigProcSignalWithChildren KILL $rigPids ; rm -rf -- "$rigTmp" ; }
trap rigStopAll EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigData/board/running" "$rigData/board/review" "$rigData/board/processed" "$rigTmp/bin" "$rigTmp/home"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
cat > /dev/null
printf '{"ok":true,"ts":"1793659000.000001","channel":"CRIG00001"}'
exit 0
RIGCURL
chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPass=0 ; rigFail=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi ; }

## A record of one run of a session, its status the caller gives.
rigRecord(){ ## session id, spawn id, status, extra header lines
	mkdir -p "$rigWs/.local/agents/spawned/$2"
	{ printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: %s\nstarted-at: 2026-01-01 00:00 +0000\nsession-thread: CRIG00001:1700000000.000001\n' \
		"$1" "$2" "$2" "$rigHost" "$3"
	  [ -z "${4:-}" ] || printf '%s\n' "$4"
	  printf -- '---\n\n# rig spawn: %s\n' "$2"
	} > "$rigWs/.local/agents/spawned/$2/$2.spawn.md"
}
## One detached process of a session, as the Bash tool keeps it: a stand-in whose words carry the pid it was given,
## its out and err, its pid, and when that pid began.
rigDetached(){ ## session id, handle, the pid to keep
	local detDir="$rigWs/.local/agents/sessions/$1/processes"
	mkdir -p "$detDir"
	: > "$detDir/$2.out" ; : > "$detDir/$2.err"
	printf '%s\n' "$3" > "$detDir/$2.pid"
	rigBegan "$3" > "$detDir/$2.began" || :
	printf 'a detached command of the rig\n' > "$detDir/$2.cmd"
}
## The tooling's own reading of when a process began, from the helper, in a shell of its own.
rigBegan(){ ## pid -- "<pid> <when it began>", or nothing
	rigProcBegan "$1"
}
rigStarted(){ ## pid -- the start column a record keeps after the pid
	rigProcBegan "$1" | LC_ALL=C awk '{ print $2 }'
}
## The pass, as the advance lock take runs it: one call, its report on stdout.
rigPass_(){ ## the measured rows it is given
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=magic-coordinator \
		bash -c '. "$1" ; AgentsToolsAdvanceSpawnHousekeeping 24 magic-coordinator no-threads' rig "$rigHouse" 2>&1
}

echo "-- 1. a closed session's detached process is ended by the pass (S5.2) --"
rigRecord rig-closed rig-closed-run spawn-succeeded
rigBlockingStandIn rig-closed-command ; rigLeft="$rigStandPid"
rigDetached rig-closed process-1 "$rigLeft"
rigOut="$( rigPass_ )"
rigAssert "the process is ended"          "$( kill -0 "$rigLeft" 2> /dev/null && printf alive || printf gone )" gone
rigAssert "the pass names it once"        "$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'leftover: rig-closed process-1' )" 1
rigAssert "and it is marked closed"       "$( [ -f "$rigWs/.local/agents/sessions/rig-closed/processes/process-1.closed" ] && printf closed || printf open )" closed

echo "-- 2. control: a live session's detached process is left alone --"
rigBlockingStandIn rig-live-run ; rigLive="$rigStandPid"
rigRecord rig-live rig-live-run spawn-started "run-process: $rigLive $( rigStarted "$rigLive" )"
rigDetached rig-live process-1 "$rigLive"
rigOut2="$( rigPass_ )"
rigAssert "the live process goes on"      "$( kill -0 "$rigLive" 2> /dev/null && printf alive || printf gone )" alive
rigAssert "and is named by nothing"       "$( printf '%s' "$rigOut2" | LC_ALL=C grep -c 'leftover: rig-live' )" 0

echo "-- 3. control: a process whose pid is no longer the one that began then is not signalled --"
rigRecord rig-moved rig-moved-run spawn-succeeded
rigBlockingStandIn rig-moved-stranger ; rigStranger="$rigStandPid"
rigDetached rig-moved process-1 "$rigStranger"
printf '1 Mon_Jan_1_00:00:00_2001\n' > "$rigWs/.local/agents/sessions/rig-moved/processes/process-1.began"
rigOut3="$( rigPass_ )"
rigAssert "the stranger goes on"          "$( kill -0 "$rigStranger" 2> /dev/null && printf alive || printf gone )" alive
rigAssert "and is named by nothing"       "$( printf '%s' "$rigOut3" | LC_ALL=C grep -c 'leftover: rig-moved' )" 0

echo "-- 4. control: a session whose folder is gone is not walked, and nothing is made again --"
rigRecord rig-vanished rig-vanished-run spawn-succeeded
rigDetached rig-vanished process-1 "$rigStranger"
rm -rf -- "$rigWs/.local/agents/sessions/rig-vanished"
rigOut4="$( rigPass_ )"
rigAssert "nothing is named for it"       "$( printf '%s' "$rigOut4" | LC_ALL=C grep -c 'leftover: rig-vanished' )" 0
rigAssert "and its folder is not made again" "$( [ -e "$rigWs/.local/agents/sessions/rig-vanished" ] && printf made || printf none )" none

if [ "$rigFail" -ne 0 ] ; then
	printf '⛔ CLOSED SESSION PROCESSES CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" >&2 ; exit 1
fi
printf 'CLOSED_SESSION_PROCESSES: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
