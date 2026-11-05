#!/usr/bin/env bash
## Behavioural check on S12.13: the schedule paces its duty starts on tool-call time.
## The rule: a duty start is made only while the median tool call of this rig's runs, over the last 30 minutes, is under the limit
## (MDAT_TOOL_PACE_MS, 7000 by default). Tool-call time gates a start, never load. A work-duty start stays exempt from MDAT_SPAWN_LIMIT.
## Held:
##   1. THE MEASURE reads `dur_ms` out of each run's `context.jsonl`, and takes the median of those calls within the window only.
##   2. NO MEASURE IS A PERMIT, and so is a thin one: with no calls in the window there is nothing to say the machine is slow, and a rig must not
##      stop every duty for want of data. This is the direction that keeps the team working.
##   3. OVER THE LIMIT IS NO START, and exactly the limit holds too: the epic says under 7 s, so the median must be below it.
##   4. THE OPERATION says what it read, in one line, so a person can tell a slow machine from a stopped schedule.
## The real Dispatcher include runs on a rig of its own, with stand-in runs whose `context.jsonl` this check writes. Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/session/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the Dispatcher include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSchedulePaceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" "$rigTmp/store/board" || exit 1
export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/store" MDLT_ORIGIN="$MDLT_ORIGIN"
cd "$rigWs" || exit 1
set -- check
. "$rigPackage/sh-lib/session/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1 || rigRefuse "the Dispatcher include would not load"

## One stand-in run: a live spawn record, and a context.jsonl holding the calls this check decides.
rigRun(){ ## run id, then one `dur_ms` a call
	local runId="$1" runDir rigDur callNo=1
	shift
	runDir="$rigWs/.local/agents/spawned/$runId"
	mkdir -p "$runDir" || return 1
	printf -- '---\nspawn-id: %s\nsession-id: %s\nowner: magic-librarian\nstatus: spawn-started\nroutine: magic-team.work-duty.routine.md\n---\n' "$runId" "$runId" > "$runDir/$runId.spawn.md"
	: > "$runDir/context.jsonl"
	for rigDur in "$@" ; do
		printf '{"type":"tool","tool":"Bash","id":"t%s","dur_ms":%s,"outcome":"ok"}\n' "$callNo" "$rigDur" >> "$runDir/context.jsonl"
		callNo=$(( callNo + 1 ))
	done
	return 0
}

echo "-- 1. the measure, and its window --"
rigRun run-a 1000 1000 1000
rigAssert "the median of one live run's calls is read: 1000 of three calls, under the limit" \
	"$( AgentsToolsSchedulePaceText )" "pace: 1000 of 3 calls in 30 minutes -- under 7000, a duty start is allowed"
## An OLD file is out of the window: its mtime is set two hours back.
rigRun run-old 60000 60000 60000
touch -t "$( date -v-2H '+%Y%m%d%H%M' 2> /dev/null || date -d '2 hours ago' '+%Y%m%d%H%M' )" "$rigWs/.local/agents/spawned/run-old/context.jsonl"
rigAssert "a run whose calls are older than the window is not counted: still 1000 of three" \
	"$( AgentsToolsSchedulePaceText )" "pace: 1000 of 3 calls in 30 minutes -- under 7000, a duty start is allowed"

echo "-- 2. no measure is a permit --"
rm -rf "$rigWs/.local/agents/spawned"
rigAssert "with no calls in the window nothing says the machine is slow, so a start is allowed" \
	"$( AgentsToolsSchedulePaceAllows && printf allowed || printf held )" "allowed"
rigRun run-thin 9000
rigAssert "and one slow call is none of the median's business either: allowed" \
	"$( AgentsToolsSchedulePaceAllows && printf allowed || printf held )" "allowed"

echo "-- 3. over the limit is no start --"
rm -rf "$rigWs/.local/agents/spawned"
rigRun run-slow 8000 9000 9000
rigAssert "a median of 9000, over 7000, holds a start, and the line says so" \
	"$( AgentsToolsSchedulePaceText ):$( AgentsToolsSchedulePaceAllows && printf allowed || printf held )" \
	"pace: 9000 of 3 calls in 30 minutes -- over 7000, a duty start is held:held"
rigRun run-edge 7000 7000
rigAssert "a median of exactly the limit holds it too: the epic says under 7 s" \
	"$( AgentsToolsSchedulePaceAllows && printf allowed || printf held )" "held"
rm -rf "$rigWs/.local/agents/spawned"
rigRun run-fast 100 200
rigAssert "and a median under the limit allows it again" \
	"$( AgentsToolsSchedulePaceAllows && printf allowed || printf held )" "allowed"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE PACE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_PACE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
