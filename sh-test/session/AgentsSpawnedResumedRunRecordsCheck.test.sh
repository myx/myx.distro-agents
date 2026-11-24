#!/usr/bin/env bash
## AgentsSpawnedResumedRunRecordsCheck -- the record list of the spawned/ store names each run's own record, so a run the session
## resumed is read as itself and not as the session's first record (AgentsToolsSpawnedAllRecordsInto and its readers,
## sh-lib/session/AgentsTools.StartedRecords.include). The registry's second column is the session and its eighth the run's spawn id:
## the two differ for every run after the first, and the first record is the one the second column names.
##   1. the list holds the resumed run's own record, and the first record of its session once, not once for each run
##   2. a session with one run lists that run's record once: the control that the reading is still right for the plain case
##   3. the rows read from the list carry the resumed run as `spawn-started`, so no reader of the rows sees a session with no run open
##   4. `start-failing` names a session whose two failed starts are within the hour and no run is open, and names none where a
##      resumed run is open: the first is the control that the kind can fire on this rig
## Red before the fix: the list names the first record once for each run, the resumed run's record is not in it, and
## `start-failing` names the session whose run is alive. Offline: a rig workspace of its own; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
[ -f "$rigPackage/sh-lib/session/AgentsTools.StartedRecords.include" ] || { echo "⛔ ERROR: the record list's include is not at the origin -- refusing to report a result" >&2 ; exit 1 ; }
mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/AgentsSpawnedResumedRunRecordsCheck.XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigStore="$rigWs/.local/agents/spawned"
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigNow="$( date +%s )"

## ONE RECORD: its sandbox, its name, the session it belongs to, its status.
rigRecord(){ ## sandbox, record name, session, status
	mkdir -p "$rigStore/$1" || exit 1
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: magic-coordinator\nstatus: %s\nstarted-at: 2026-11-23 16:56 +0200\n---\n\n# Spawn session: %s\n' "$3" "$2" "$4" "$2" > "$rigStore/$1/$2.spawn.md"
}
## ONE REGISTRY ROW, the store's own form: tracking, session, parent, host, owner, status, exit, the run's spawn id, then the rest.
rigRow(){ ## tracking, session, status, exit, spawn id
	printf '%s %s none righost magic-coordinator %s %s %s C0RIG:1 D0RIG:1 rigws 2026-11-24_00:00\n' "$1" "$2" "$3" "$4" "$5" >> "$rigWs/.local/agents/spawned-sessions.registry"
}
mkdir -p "$rigWs/.local/agents" "$rigWs/.local/agents/sessions" || exit 1
## SESSION S1: a first run that failed and a second run, resumed under the same session, that is open now.
rigRecord rigsess1 rigsess1 rigsess1 spawn-failed
rigRecord rigsess1 rigrun2x rigsess1 spawn-started
rigRow rigsess1 rigsess1 spawn-failed 143 rigsess1
rigRow rigsess1 rigsess1 spawn-started - rigrun2x
## SESSION S2: one run only.
rigRecord rigsess2 rigsess2 rigsess2 spawn-succeeded
rigRow rigsess2 rigsess2 spawn-succeeded 0 rigsess2
## SESSION S3: two failed runs within the hour and none open.
rigRecord rigsess3 rigsess3 rigsess3 spawn-failed
rigRecord rigsess3 rigrun3b rigsess3 spawn-failed
rigRow rigsess3 rigsess3 spawn-failed 143 rigsess3
rigRow rigsess3 rigsess3 spawn-failed 143 rigrun3b

rigList="$( MMDAPP="$rigWs" ; . "$rigPackage/sh-lib/session/AgentsTools.StartedRecords.include" && AgentsToolsSpawnedAllRecordsInto rigPaths "$rigWs" && printf '%s\n' ${rigPaths[@]+"${rigPaths[@]}"} )"
rigRows="$( MMDAPP="$rigWs" ; . "$rigPackage/sh-lib/session/AgentsTools.StartedRecords.include" && AgentsToolsSpawnedRecordRows "$rigWs" spawn-id session-id owner status run-process parent-session-id agent-less )"

echo "-- 1. the resumed run's own record is listed, and the first record once --"
rigAssert "the list holds the resumed run's own record" "$( printf '%s\n' "$rigList" | LC_ALL=C grep -c -F -- '/rigsess1/rigrun2x.spawn.md' )" 1
rigAssert "the session's first record stands in the list once" "$( printf '%s\n' "$rigList" | LC_ALL=C grep -c -F -- '/rigsess1/rigsess1.spawn.md' )" 1
echo "-- 2. a session of one run --"
rigAssert "control: its record stands once" "$( printf '%s\n' "$rigList" | LC_ALL=C grep -c -F -- '/rigsess2/rigsess2.spawn.md' )" 1
echo "-- 3. the rows --"
rigAssert "the rows carry the resumed run as spawn-started" "$( printf '%s\n' "$rigRows" | LC_ALL=C awk -F'\t' '$5 == "rigsess1" && $7 == "spawn-started"' | LC_ALL=C grep -c . )" 1
echo "-- 4. start-failing --"
rigFailing="$( MMDAPP="$rigWs" ; MDLT_ORIGIN="$MDLT_ORIGIN" ; . "$rigPackage/sh-lib/supervise/AgentsTools.SuperviseStartFailing.include" && AgentsToolsSuperviseStartFailing "$rigWs" "$rigNow" "$rigRows" 2> /dev/null )"
rigAssert "control: the kind fires on this rig, for the session with two failed starts and no run open" "$( printf '%s\n' "$rigFailing" | LC_ALL=C grep -c -F -- 'start-failing ws rigsess3 ' )" 1
rigAssert "a session whose resumed run is open is not named" "$( printf '%s\n' "$rigFailing" | LC_ALL=C grep -c -F -- 'start-failing ws rigsess1 ' )" 0

printf 'SPAWNED_RESUMED_RUN_RECORDS: %s (%d assertions, offline, rig tree only)\n' "$( [ "$rigFail" = 0 ] && echo OK || echo FAIL )" "$(( rigPass + rigFail ))"
[ "$rigFail" = 0 ] || exit 1
