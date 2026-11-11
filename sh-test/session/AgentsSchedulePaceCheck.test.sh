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

## The measure as it stands: the median MACHINERY time (mach_ms) of the calls of LIVE runs within the window (MDAT_TOOL_PACE_WINDOW_SECONDS,
## 300) by each record's own clock ("ms"), Wait records left out, pace.mcp lines added, against MDAT_TOOL_PACE_MS (4000); the line reads
## "pace: N.Ns machinery a call, N calls in 5 minutes -- under 4s, a duty start is allowed". The cache is off here, so every row reads afresh.
export MDAT_TOOL_PACE_CACHE_SECONDS=0
rigNowMs="$(( $( date +%s ) * 1000 ))"
## One stand-in run: a spawn record (live unless told otherwise), and a context.jsonl holding the calls this check decides.
rigRun(){ ## run id, status (started|done), tool, clock offset in seconds (0 = now, 7200 = two hours back), then one mach_ms a call
	local runId="$1" runStatus="$2" runTool="$3" runBack="$4" runDir rigMach callNo=1
	shift 4
	runDir="$rigWs/.local/agents/spawned/$runId"
	mkdir -p "$runDir" || return 1
	printf -- '---\nspawn-id: %s\nsession-id: %s\nowner: magic-librarian\nstatus: spawn-%s\nroutine: magic-team.work-duty.routine.md\n---\n' "$runId" "$runId" "$runStatus" > "$runDir/$runId.spawn.md"
	: > "$runDir/context.jsonl"
	for rigMach in "$@" ; do
		printf '{"type":"message","kind":"tool","tool":"%s","id":"t%s","ms":%s,"dur_ms":%s,"mach_ms":%s,"outcome":"ok"}\n' "$runTool" "$callNo" "$(( rigNowMs - runBack * 1000 ))" "$(( rigMach * 10 ))" "$rigMach" >> "$runDir/context.jsonl"
		callNo=$(( callNo + 1 ))
	done
	return 0
}
rigPace(){ AgentsToolsSchedulePaceText ; }
rigGate(){ AgentsToolsSchedulePaceAllows && printf allowed || printf held ; }

echo "-- 1. the measure, and its window --"
rigRun run-a started Bash 0 1000 1000 1000
rigAssert "the median machinery time of one live run's calls is read: 1.0 s of three calls, under 4 s" \
	"$( rigPace )" "pace: 1.0s machinery a call, 3 calls in 5 minutes -- under 4s, a duty start is allowed"
rigRun run-old started Bash 7200 60000 60000 60000
rigAssert "calls older than the window by their own clock are not counted: still 1.0 s of three" \
	"$( rigPace )" "pace: 1.0s machinery a call, 3 calls in 5 minutes -- under 4s, a duty start is allowed"
rigRun run-done done Bash 0 60000 60000 60000
rigAssert "a run that is not live is not counted either: still 1.0 s of three" \
	"$( rigPace )" "pace: 1.0s machinery a call, 3 calls in 5 minutes -- under 4s, a duty start is allowed"
rigRun run-wait started Wait 0 900000 900000 900000
rigAssert "a Wait waits by design, so its records are left out: still 1.0 s of three" \
	"$( rigPace )" "pace: 1.0s machinery a call, 3 calls in 5 minutes -- under 4s, a duty start is allowed"
rigAssert "machinery time is read, not the call's own run: dur_ms is ten times mach_ms here and the line says 1.0 s" \
	"$( LC_ALL=C grep -c '"dur_ms":10000' "$rigWs/.local/agents/spawned/run-a/context.jsonl" ):$( rigPace | LC_ALL=C grep -c '^pace: 1.0s' )" "3:1"
mkdir -p "$rigWs/.local/agents/schedule"
printf '%s 1000 Edit\n%s 1000 Read\n%s 900000 Wait\n' "$( date +%s )" "$( date +%s )" "$( date +%s )" > "$rigWs/.local/agents/schedule/pace.mcp"
rigAssert "the served calls of pace.mcp count too, its Wait lines left out: 1.0 s of five" \
	"$( rigPace )" "pace: 1.0s machinery a call, 5 calls in 5 minutes -- under 4s, a duty start is allowed"
rm -f "$rigWs/.local/agents/schedule/pace.mcp"

echo "-- 2. no measure is a permit --"
rm -rf "$rigWs/.local/agents/spawned"
rigAssert "with no live run calling in the window the line says so, and a start is allowed" \
	"$( rigPace ):$( rigGate )" "pace: no live run made a call in 5 minutes -- a duty start is allowed, one a pass:allowed"
rigRun run-thin started Bash 0 9000
rigAssert "one slow call is too few to judge: allowed, and the line says so" \
	"$( rigPace ):$( rigGate )" "pace: 9.0s machinery a call, 1 calls in 5 minutes -- too few to judge, a duty start is allowed:allowed"

echo "-- 3. over the limit is no start --"
rm -rf "$rigWs/.local/agents/spawned"
rigRun run-slow started Bash 0 8000 9000 9000
rigAssert "a median of 9.0 s, over 4 s, holds a start, and the line says so" \
	"$( rigPace ):$( rigGate )" "pace: 9.0s machinery a call, 3 calls in 5 minutes -- over 4s, a duty start is held:held"
rm -rf "$rigWs/.local/agents/spawned"
rigRun run-edge started Bash 0 4000 4000 4000
rigAssert "a median of exactly the limit holds it too: under 4 s is the permit" \
	"$( rigGate )" "held"
rm -rf "$rigWs/.local/agents/spawned"
rigRun run-fast started Bash 0 100 200 300
rigAssert "and a median under the limit allows it again" \
	"$( rigGate )" "allowed"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE PACE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_PACE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
