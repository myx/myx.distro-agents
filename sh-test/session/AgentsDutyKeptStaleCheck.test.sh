#!/usr/bin/env bash
## Behavioural check on a kept duty session ending with its day (AgentsToolsDutyKeptStale, sh-lib/session/AgentsTools.StartedRecords.include),
## and its two readers: the schedule's start point (AgentsToolsScheduleSpawn) and the spawn proxy. Held:
##   1. a kept session founded on an earlier day is stale; one founded today is not; one with no founding record is not judged stale
##   2. the date is the session's own started-at, never the kept file's time: a kept file rewritten today still names yesterday's session
##   3. both readers drop a stale kept id before the start (their own lines name the rule)
## Red recipe: make AgentsToolsDutyKeptStale read the kept file's time instead, and row 2 fails.
## Offline: a rig workspace under this check's temp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyKeptStaleCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/schedule/duty-session"
rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigFound(){ ## session id, started-at
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: keeper-rig\nstatus: spawn-ended-without-close\nstarted-at: %s\n---\n' "$1" "$1" "$2" > "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
}
rigStale(){ ## session id -> stale|today
	MMDAPP="$rigWs" bash -c '. "$1" ; AgentsToolsDutyKeptStale "$2" && echo stale || echo today' rig "$rigPkg/sh-lib/session/AgentsTools.StartedRecords.include" "$1"
}
rigYesterday="$( date -v-1d '+%Y-%m-%d' 2> /dev/null || date -d yesterday '+%Y-%m-%d' )"
rigToday="$( date '+%Y-%m-%d' )"
[ -n "$rigYesterday" ] || rigRefuse "the date of yesterday could not be read"

echo "-- 1. founded yesterday, today, or with no record --"
rigFound rig-old "$rigYesterday 09:02 +0200"
rigFound rig-new "$rigToday 08:30 +0200"
rigAssert "a session founded yesterday is stale"        "$( rigStale rig-old )" "stale"
rigAssert "a session founded today is not"              "$( rigStale rig-new )" "today"
rigAssert "a session with no founding record is not judged stale" "$( rigStale rig-none )" "today"

echo "-- 2. the session's own date, never the kept file's time --"
printf 'rig-old\n' > "$rigWs/.local/agents/schedule/duty-session/keeper-rig"
touch "$rigWs/.local/agents/schedule/duty-session/keeper-rig"
rigAssert "a kept file rewritten today still names yesterday's session" "$( rigStale "$( head -1 "$rigWs/.local/agents/schedule/duty-session/keeper-rig" )" )" "stale"

echo "-- 3. both readers drop a stale kept id --"
rigAssert "the schedule's start point asks the rule" "$( LC_ALL=C grep -c 'AgentsToolsDutyKeptStale "$spawnDutySession"' "$rigPkg/sh-lib/session/AgentsTools.DispatcherSchedule.include" )" "1"
rigAssert "the spawn proxy asks the rule"            "$( LC_ALL=C grep -c 'AgentsToolsDutyKeptStale "$dutyKeptId"' "$rigPkg/sh-lib/session/AgentsTools.InternOpAgentSpawnProxy.include" )" "1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ DUTY KEPT STALE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'DUTY_KEPT_STALE: OK (%d assertions, offline)\n' "$rigPass"
