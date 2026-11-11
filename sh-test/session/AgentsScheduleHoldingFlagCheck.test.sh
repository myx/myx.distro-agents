#!/usr/bin/env bash
## Behavioural check on the schedule's holding flag (S12.15, board task 20261106T0836Z; `AgentsToolsScheduleOverride`,
## `AgentsToolsScheduleCurrentFlags` and `AgentsToolsScheduleLoop` in AgentsTools.DispatcherSchedule.include). Holding is how a rig
## is stopped in two parts: the flag stops the schedule starting anything, and stopping the running sessions is a separate action.
## Held, run rather than read:
##   1. SETTING holding stores an override with no end, and the override answers `holding: yes`.
##   2. --current-flags lists it, `holding: yes` while it holds and `holding: no` after `--override-flag --no holding`.
##   3. A TTL SETS AN END, and the flags line carries the seconds left.
##   4. WHILE IT HOLDS THE LOOP STARTS NOTHING: no autorun, no duty, no pending board item, no supervision, no emergency start.
##   5. AND IT STILL REPORTS AND LEARNS: what ended is reported and the learning step still runs, and those change no running state.
##   6. CLEARED, THE LOOP STARTS AGAIN, so the flag is a hold and not a one-way switch.
## The settings reader is a stand-in over a key file of the rig's own, so no setting of any workspace is read or written here. Every step
## of the pass is a stand-in that records its own call, so no board item is advanced and no session is made: which routines are due is
## AgentsScheduleLoopCheck's and AgentsAutorunCheck's question. Until 2026-11-09 `AgentsToolsScheduleStartPending` had no stand-in, so
## the pass reached the real `$MDAT_DATA_ROOT/board/pending` and advanced a real item while this check reported itself offline.
## RED RECIPE, measured on a copy under this check's own scratch on 2026-11-06:
##   the holding gate (the `MDAT_SCHEDULE_HOLDING` test that returns before the pass's steps, :1728-1732 at 2026-11-09 02:57) deleted —
##   row 4 fails with all five of its "starts nothing" assertions, and row 5's holding line fails.
##   `holding` removed from the flags list (the `for flagsFlag in` line, :227) — row 2 fails, and only row 2.
## Measured 2026-11-09 on a copy: with `AgentsToolsScheduleStartPending` called above the holding gate instead of below it, the run reads
## OK at 17 of 17 before this check's stand-in and assertion, and 1 of 18 red after it, on the row `no pending board item was started`.
## Offline: the include this check loads, a rig of its own, and no spawner, git or network.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/session/AgentsTools.DispatcherSchedule.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the Dispatcher include is not at $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleHoldingFlagCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" || exit 1
: > "$rigTmp/settings"
: > "$rigTmp/calls"
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
## ONE PRELUDE, AND EVERY CALL IS A SHELL OF ITS OWN OVER IT. The include is sourced first, because it defines these very functions:
## a stand-in placed before it is overwritten by the real one, and the check then measures the real schedule instead of its rig.
cat > "$rigTmp/prelude.sh" <<'PRELUDE'
. "$RIG_INCLUDE" || exit 1
## magic-team --select-default <key> <fallback> | --upsert <key> <value> | --delete <key>
AgentsToolsConfigOption(){
	local optVerb="$2" optKey optValue="" optLine=""
	shift 2
	optKey="${1:-}"
	while IFS= read -r optLine ; do
		case "$optLine" in "$optKey="*) optValue="${optLine#"$optKey="}" ;; esac
	done < "$RIG_SETTINGS"
	case "$optVerb" in
		--select-default)
			[ -n "$optValue" ] || optValue="${2:--}"
			printf '%s\n' "$optValue"
		;;
		--upsert|--set)
			grep -v -e "$optKey=" "$RIG_SETTINGS" > "$RIG_SETTINGS.next" 2> /dev/null || :
			printf '%s=%s\n' "$optKey" "$2" >> "$RIG_SETTINGS.next"
			mv "$RIG_SETTINGS.next" "$RIG_SETTINGS"
		;;
		--delete)
			grep -v -e "$optKey=" "$RIG_SETTINGS" > "$RIG_SETTINGS.next" 2> /dev/null || :
			mv "$RIG_SETTINGS.next" "$RIG_SETTINGS"
		;;
		*) return 1 ;;
	esac
	return 0
}
AgentsToolsScheduleTools(){ return 0 ; }
AgentsToolsScheduleSpawnReport(){ printf 'report\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleLearning(){ printf 'learn\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleAutorun(){ printf 'autorun\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleWorkDuty(){ printf 'duty\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleSupervision(){ printf 'supervision\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleImportantEmergency(){ printf 'emergency\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleStartPending(){ printf 'start-pending\n' >> "$RIG_CALLS" ; }
PRELUDE
## EVERY CALL IS BOUNDED: a step that is not a stand-in would otherwise run the whole schedule in this rig, so the check says a call
## stood still rather than standing still with it. The words land in rigOut, and a call that overran is named as such.
rigRun(){ ## the shell words to run after the prelude
	RIG_SETTINGS="$rigTmp/settings" RIG_CALLS="$rigTmp/calls" RIG_INCLUDE="$rigInclude" MMDAPP="$rigWs" \
		bash -c '. "$1" ; shift ; eval "$*"' rig-run "$rigTmp/prelude.sh" "$@" > "$rigTmp/out" 2>&1 &
	rigRunPid="$!"
	rigProcNote "$rigRunPid"
	rigLeft=30
	while [ "$rigLeft" -gt 0 ] ; do
		kill -0 "$rigRunPid" 2> /dev/null || break
		sleep 1 ; rigLeft=$(( rigLeft - 1 ))
	done
	if kill -0 "$rigRunPid" 2> /dev/null ; then
		rigProcSignal TERM "$rigRunPid" || :
		rigOut="<the call stood still for 30 seconds>"
	else
		wait "$rigRunPid" 2> /dev/null
		rigOut="$( cat "$rigTmp/out" )"
	fi
}
rigLog(){ LC_ALL=C grep -c -x -- "$1" "$rigTmp/calls" 2> /dev/null || : ; }
rigSaid(){ ## text -- whether the last call's output holds it
	case "$rigOut" in *"$1"*) printf 'said' ;; *) printf 'not-said' ;; esac
}

echo "-- 1. setting holding, and what the override answers --"
rigRun 'AgentsToolsScheduleOverride --override-flag holding'
rigAssert "setting holding with no TTL answers holding: yes" "$rigOut" 'holding: yes'
rigAssert "and what it stored is an override with no end" "$( LC_ALL=C grep -c -x -F 'MDAT_SCHEDULE_HOLDING=on' "$rigTmp/settings" || : )" 1

echo "-- 2. --current-flags lists it --"
rigRun 'AgentsToolsScheduleCurrentFlags --current-flags'
rigAssert "the flags line for holding reads yes while it holds" "$( rigSaid 'holding: yes' )" said
rigRun 'AgentsToolsScheduleOverride --override-flag --no holding'
rigAssert "clearing it answers holding: no" "$rigOut" 'holding: no'
rigRun 'AgentsToolsScheduleCurrentFlags --current-flags'
rigAssert "the flags line for holding reads no afterwards" "$( rigSaid 'holding: no' )" said
rigAssert "and no longer reads yes" "$( rigSaid 'holding: yes' )" not-said

echo "-- 3. a TTL sets an end, and the line says how long is left --"
rigRun 'AgentsToolsScheduleOverride --override-flag holding 3600'
rigAssert "holding set for an hour reads yes, with seconds left" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C sed -e 's/ ([0-9][0-9]* seconds left)/ (seconds left)/' )" 'holding: yes (seconds left)'
rigRun 'AgentsToolsScheduleOverride --override-flag --no holding'

echo "-- 4 and 5. while it holds the loop starts nothing, and still reports and learns --"
: > "$rigTmp/calls"
rigRun 'AgentsToolsScheduleOverride --override-flag holding > /dev/null ; AgentsToolsScheduleLoop'
rigAssert "the pass says in one line that it is holding" "$( rigSaid 'holding: the schedule starts nothing while holding is set' )" said
rigAssert "no autorun was started" "$( rigLog autorun )" 0
rigAssert "no duty was started" "$( rigLog duty )" 0
rigAssert "no supervision was started" "$( rigLog supervision )" 0
rigAssert "no emergency start was made" "$( rigLog emergency )" 0
rigAssert "no pending board item was started" "$( rigLog start-pending )" 0
rigAssert "what ended was still reported" "$( rigLog report )" 1
rigAssert "and the learning step still ran" "$( rigLog learn )" 1

echo "-- 6. cleared, the loop starts again --"
: > "$rigTmp/calls"
rigRun 'AgentsToolsScheduleOverride --override-flag --no holding > /dev/null ; AgentsToolsScheduleLoop'
rigAssert "the autorun step runs again" "$( rigLog autorun )" 1
rigAssert "and the duty step runs again" "$( rigLog duty )" 1
rigAssert "and the pass no longer says it is holding" "$( rigSaid 'the schedule starts nothing while holding is set' )" not-said

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE HOLDING FLAG CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_HOLDING_FLAG: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
