#!/usr/bin/env bash
## Behavioural check on the keep-or-stop rule of an idle duty (S18.4): the branch in AgentsToolsScheduleDutyLifetime reads
## the three numbers the spawner wrote on the run's own record, `duty-cache-round`, `duty-cache-life` and
## `duty-cache-turns`. The design's own arithmetic: the armed floor's cache costs 2.0x to write again against 0.1x to read,
## so one rebuild is repaid by 20 reads, and keeping wins while the gap to the next work time is under 20 waits.
## Held at both wait rounds this estate runs, 2700 s for claude-native and deepseek, and the safe 270 s:
##   1. 2700 s: eight hours keeps, 53999 s keeps, 54000 s stops, and the reason names the 20 waits it measured against.
##   2. 270 s: eight hours stops, 5399 s keeps, 5400 s stops.
##   3. A ROUND PAST THE CACHE'S OWN LIFE stops whatever the gap, and the reason names the round and the life.
##   4. A RECORD CARRYING NO NUMBERS leaves the limits that were there before to decide.
##   5. A LAST WAKE THAT READ NOTHING stops, even where the hours alone would keep.
## The CONTROL of every row is its opposite: a rule that never stopped passes 1a, 1b, 2b, 4 and fails 1c, 2a, 2c, 3, 5.
## Offline: the schedule include over a stand-in record and a stand-in clock. No rig folder, no tool call.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the schedule include is not in this tree: sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyKeepOrStopCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/home" "$rigTmp/ws" "$rigTmp/data" "$rigTmp/spawned/rig-run"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
rigRecord(){ ## round, life, turns, the last wake's cache figure (read|nothing) -- the record's path
	local recFile="$rigTmp/spawned/rig-run/rig-run.spawn.md"
	{
		printf -- '---\nsession-id: rig-run\nspawn-id: rig-run\nowner: magic-coordinator\nstatus: spawn-started\nroutine: magic-coordinator.off-duty.routine.md\n'
		printf 'output-file: %s\n' "$rigTmp/spawned/rig-run/rig-output.log"
		[ -z "$1" ] || printf 'duty-cache-round: %s\nduty-cache-life: %s\nduty-cache-turns: %s\n' "$1" "$2" "$3"
		printf -- '---\n\n# Spawn session: rig-run\n'
	} > "$recFile"
	case "$4" in
		read) printf '%s\n' '   shared prefix -- round 1 read 4100 tokens from the cache' > "$rigTmp/spawned/rig-run/rig-output.log" ;;
		nothing) printf '%s\n' '   shared prefix -- round 1 cached nothing: the prefix is under the model minimum' > "$rigTmp/spawned/rig-run/rig-output.log" ;;
	esac
	printf '%s\n' "$recFile"
}
rigLife(){ ## record, idle seconds, seconds to the next work time, cache figure -- `kept`, or `stopped` and its reason
	local lifeSaid=""
	lifeSaid="$( env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" \
		MDLT_ORIGIN="$MDLT_ORIGIN" RIG_RECORD="$1" RIG_IDLE="$2" RIG_GAP="$3" RIG_CACHE="${4:-read}" bash -c '
			set +e
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
			## The pass around the rule: the hours do not allow it, nothing else keeps it, and the clock is the rig own.
			AgentsToolsScheduleDismiss(){ printf "stopped %s\n" "$2" ; }
			AgentsToolsScheduleHasWork(){ return 1 ; }
			AgentsToolsScheduleBoardDemand(){ return 1 ; }
			AgentsToolsScheduleOtherDutyLive(){ return 1 ; }
			AgentsToolsScheduleInSession(){ return 1 ; }
			AgentsToolsScheduleTagNews(){ return 1 ; }
			AgentsToolsScheduleDutyCache(){ printf "%s\n" "$RIG_CACHE" ; }
			## One clock read for the whole pass: two reads a second apart would move the gap this row measures.
			lifeNowRig="$( date +%s )"
			AgentsToolsManagerRunIdleSince(){ printf "%s\n" "$(( lifeNowRig - RIG_IDLE ))" ; }
			AgentsToolsScheduleClock(){ printf "%s 0 1 43200\n" "$lifeNowRig" ; }
			AgentsToolsScheduleNextWorkStart(){ [ -z "$RIG_GAP" ] || printf "%s\n" "$(( lifeNowRig + RIG_GAP ))" ; }
			AgentsToolsScheduleDutyLifetime "$RIG_RECORD" magic-coordinator no no
			printf "kept\n"
		' 2> /dev/null )"
	printf '%s\n' "$lifeSaid" | LC_ALL=C grep -E '^(stopped|kept)' | LC_ALL=C head -1
}
rigVerdict(){ ## what rigLife printed -- keep, or stop
	case "$1" in stopped*) printf 'stop' ;; *) printf 'keep' ;; esac
}

echo "-- 1. the 2700 s round --"
rigRec="$( rigRecord 2700 3600 20 read )"
rigAssert "2700 s, eight hours (28800 s) to worktime: keep"                 "$( rigVerdict "$( rigLife "$rigRec" 600 28800 read )" )" "keep"
rigAssert "2700 s, 53999 s to worktime, one second under 20 waits: keep"   "$( rigVerdict "$( rigLife "$rigRec" 600 53999 read )" )" "keep"
rigAssert "2700 s, 54000 s, the 20 waits: stop"                            "$( rigVerdict "$( rigLife "$rigRec" 600 54000 read )" )" "stop"
rigAssert "and the reason names the 20 wakes it measured against"          "$( rigLife "$rigRec" 600 54000 read | LC_ALL=C grep -c -F 'wakes of 2700s that repay a rebuild' )" "1"

echo "-- 2. the safe 270 s round --"
rigRec="$( rigRecord 270 3600 20 read )"
rigAssert "270 s, eight hours: stop, keeping would lose after 1.5 hours"   "$( rigVerdict "$( rigLife "$rigRec" 600 28800 read )" )" "stop"
rigAssert "270 s, 5399 s to worktime: keep"                               "$( rigVerdict "$( rigLife "$rigRec" 600 5399 read )" )" "keep"
rigAssert "270 s, 5400 s, the 20 waits: stop"                             "$( rigVerdict "$( rigLife "$rigRec" 600 5400 read )" )" "stop"

echo "-- 3. a round past the cache's own life --"
rigRec="$( rigRecord 3601 3600 20 read )"
rigAssert "a 3601 s round, an hour to worktime: stop, every wake would miss" "$( rigVerdict "$( rigLife "$rigRec" 600 3600 read )" )" "stop"
rigAssert "and the reason names the round and the life it passes"           "$( rigLife "$rigRec" 600 3600 read | LC_ALL=C grep -c -F 'reaches past the 3600s its cache lives' )" "1"

echo "-- 4. a record carrying no numbers: the earlier limits decide --"
rigRec="$( rigRecord "" "" "" read )"
rigAssert "no cache numbers, ten minutes idle, an hour to worktime: no stop from this rule" "$( rigVerdict "$( rigLife "$rigRec" 600 3600 read )" )" "keep"
rigAssert "and the hour idle it did limit still ends it"                   "$( rigVerdict "$( rigLife "$rigRec" 3700 3600 read )" )" "stop"

echo "-- 5. a last wake that read nothing --"
rigRec="$( rigRecord 2700 3600 20 nothing )"
rigAssert "2700 s, eight hours, a last wake that read nothing: stop"       "$( rigVerdict "$( rigLife "$rigRec" 600 28800 nothing )" )" "stop"
rigAssert "and the reason says no keeping is shown cheaper"                "$( rigLife "$rigRec" 600 28800 nothing | LC_ALL=C grep -c -F 'no keeping is shown cheaper' )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DUTY KEEP OR STOP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
printf 'DUTY_KEEP_OR_STOP: OK (%d assertions, offline)\n' "$rigPassCount"
