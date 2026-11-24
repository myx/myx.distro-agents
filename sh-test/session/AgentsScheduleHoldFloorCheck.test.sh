#!/usr/bin/env bash
## Behavioural check on what a hold stops and what it leaves running (epic S22, the hold floor): a hold stops the start of new work and
## never the review of handbacks, the release of finished sessions or the close of a dead run, and the coordinator's duty runs its board
## group under a hold. `AgentsToolsScheduleLoop` and `AgentsToolsScheduleWorkDuty`, in AgentsTools.DispatcherSchedule.include, run
## for three passes over a rig, each row against its control with no hold:
##   1. UNDER A HOLD NO NEW WORK STARTS: no autorun, no pending item, no supervision, no emergency start, no retest drain, and the duty
##      of no member but the coordinator.
##   2. UNDER A HOLD THE REVIEW GOES ON: the coordinator's duty is started while the board has news, and is not while it has none.
##   3. UNDER A HOLD A DEAD DUTY RECORD IS CLOSED, the finished runs are released, and a live duty's lifetime rule runs.
##   4. THE CONTROLS: the same rig with no hold starts the whole roster, runs every step, closes, releases and runs the lifetime.
## The steps below the pass are stand-ins that count their calls, and the spawner is a counter. The board and the inboxes are written by
## their owners. Offline: no session is made and no setting of any workspace is read or written.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the schedule's include is not at $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleHoldFloorCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigMembers="$rigTmp/members" rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local/agents" "$rigHome" || exit 1
: > "$rigTmp/settings"
: > "$rigTmp/calls"
: > "$rigTmp/duty"
for rigOne in keeper-rig-one keeper-rig-two magic-coordinator ; do
	mkdir -p "$rigMembers/$rigOne" || exit 1
	printf 'status: active\n' > "$rigMembers/$rigOne/SKILL.md"
	printf '# armed\n' > "$rigMembers/$rigOne/$rigOne.armed.md"
done
for rigOne in magic-coordinator.off-duty.routine.md magic-coordinator.work-duty.routine.md ; do
	printf -- '---\ntype: routine\n---\n\nrig\n' > "$rigMembers/magic-coordinator/$rigOne" || exit 1
done
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigHome" rigOwnerOrigin="$MDLT_ORIGIN"
rigOwnerBoardReady || exit 1
## Every member has an inbox item, so the inbox is never what decides a start below.
for rigOne in keeper-rig-one keeper-rig-two magic-coordinator ; do
	rigOwnerInboxReady "$rigOne" || exit 1
	printf -- '---\ntype: note\n---\n\nrig work\n' | rigOwnerInboxPut "$rigOne" note-20261106T000000Z-rig.md || exit 1
done

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
## ONE PRELUDE, AND EVERY CALL IS A SHELL OF ITS OWN OVER IT. The include is sourced first, because it defines these very functions: a stand-in
## placed before it would be overwritten by the real one, and the check would measure the real schedule instead of its rig.
cat > "$rigTmp/prelude.sh" <<'PRELUDE'
MMDAPP="$RIG_WS" ; export MMDAPP
MDAT_DATA_ROOT="$RIG_DATA" ; export MDAT_DATA_ROOT
MDAT_WORKSPACE_MODE=team-rig ; export MDAT_WORKSPACE_MODE
MDAT_SCHEDULE_THREAD=off ; export MDAT_SCHEDULE_THREAD
set +e +u
. "$RIG_INCLUDE" > /dev/null 2>&1 || exit 1
## magic-team --select-default <key> <fallback> | --upsert <key> <value> | --delete <key>, over the rig's own key file.
AgentsToolsConfigOption(){
	local optVerb="$2" optKey optValue="" optLine=""
	[ -n "${RIG_SETTINGS:-}" ] || { echo "⛔ ERROR: rig AgentsToolsConfigOption: RIG_SETTINGS is not set -- nothing was written" >&2 ; return 2 ; }
	shift 2
	optKey="${1:-}"
	while IFS= read -r optLine ; do
		case "$optLine" in "$optKey="*) optValue="${optLine#"$optKey="}" ;; esac
	done < "$RIG_SETTINGS"
	case "$optVerb" in
		--select-default) [ -n "$optValue" ] || optValue="${2:--}" ; printf '%s\n' "$optValue" ;;
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
## The flags: the hours are the rig's, and the holding line is the real flag line over the rig's own settings.
AgentsToolsScheduleCurrentFlags(){
	printf 'worktime: yes\nweekend: no\nholidays: no\n'
	AgentsToolsScheduleFlagLine holding "" "" "$( date +%s )"
	printf 'emergency: no\novertime: no\nlearning: no\nsupervised: no\n'
	return 0
}
## The steps of the pass that start or release, each a counter.
AgentsToolsScheduleSpawnReport(){ printf 'report\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleLearningStep(){ printf 'learn\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleAutorun(){ printf 'autorun\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleStartPending(){ printf 'start-pending\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleIdleRunsEnd(){ printf 'idle-runs\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleRetestDrain(){ printf 'retest\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleSupervision(){ printf 'supervision\n' >> "$RIG_CALLS" ; }
AgentsToolsScheduleImportantEmergency(){ printf 'emergency\n' >> "$RIG_CALLS" ; }
## What the duty step asks of the rest: the pace allows, the roster is the rig's three members, no tag is news, and the spawner counts.
AgentsToolsSchedulePaceText(){ printf 'pace: 1 of 9 calls in 5 minutes -- under 4s, a duty start is allowed\n' ; return 0 ; }
AgentsToolsSchedulePaceAllows(){ return 0 ; }
AgentsToolsScheduleTeamTags(){ return 0 ; }
AgentsToolsScheduleDmTags(){ return 0 ; }
AgentsToolsScheduleTagNews(){ return 1 ; }
AgentsToolsScheduleTagCarry(){ return 0 ; }
AgentsToolsScheduleTagGive(){ return 0 ; }
AgentsToolsScheduleDutyRestartDue(){ return 1 ; }
AgentsToolsScheduleDutyBlockedDetach(){ return 1 ; }
AgentsToolsTeamMemberDirectoryText(){ local rigM ; for rigM in keeper-rig-one keeper-rig-two magic-coordinator ; do printf '%s\t%s/%s\n' "$rigM" "$RIG_MEMBERS" "$rigM" ; done ; }
AgentsToolsScheduleSpawn(){ printf 'start\t%s\n' "$1" >> "$RIG_CALLS" ; return 0 ; }
## A dead duty record and a live duty's lifetime, each a counter. A member holds a live duty where RIG_DUTY names it, or where an earlier pass started it.
AgentsToolsScheduleStartedDutyRecords(){ [ -z "${RIG_STALE:-}" ] || printf '%s\n' "$RIG_STALE" ; }
AgentsToolsScheduleDutyStaleClose(){ printf 'close\t%s\n' "$1" >> "$RIG_CALLS" ; return 0 ; }
AgentsToolsScheduleDutyLifetime(){ printf 'lifetime\t%s\n' "$2" >> "$RIG_CALLS" ; return 0 ; }
AgentsToolsScheduleWorkDutyRecord(){
	LC_ALL=C grep -q -x -F -e "$1" "$RIG_DUTY" 2> /dev/null && { printf '%s/rig.spawn.md\n' "$RIG_WS" ; return 0 ; }
	LC_ALL=C grep -q -x -F -e "start"$'\t'"work-duty.$1" "$RIG_CALLS" 2> /dev/null && { printf '%s/rig.spawn.md\n' "$RIG_WS" ; return 0 ; }
	return 1
}
PRELUDE
## EVERY CALL IS BOUNDED: a step that is not a stand-in would otherwise run the whole schedule in this rig, so the check says a call stood still.
rigRun(){ ## the shell words to run after the prelude
	: > "$rigTmp/calls"
	env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$rigHome" MDLT_ORIGIN="$MDLT_ORIGIN" MDSC_CMD=check \
		RIG_SETTINGS="$rigTmp/settings" RIG_CALLS="$rigTmp/calls" RIG_INCLUDE="$rigInclude" RIG_WS="$rigWs" RIG_DATA="$rigData" \
		RIG_MEMBERS="$rigMembers" RIG_DUTY="$rigTmp/duty" RIG_STALE="${rigStale:-}" \
		bash -c '. "$1" ; shift ; eval "$*"' rig-run "$rigTmp/prelude.sh" "$@" > "$rigTmp/out" 2>&1 &
	rigRunPid="$!"
	rigProcNote "$rigRunPid"
	rigLeft=60
	while [ "$rigLeft" -gt 0 ] ; do
		kill -0 "$rigRunPid" 2> /dev/null || break
		sleep 1 ; rigLeft=$(( rigLeft - 1 ))
	done
	if kill -0 "$rigRunPid" 2> /dev/null ; then
		rigProcSignal TERM "$rigRunPid" || :
		rigOut="<the call stood still for 60 seconds>"
	else
		wait "$rigRunPid" 2> /dev/null
		rigOut="$( cat "$rigTmp/out" )"
	fi
}
## Three passes, each in a subshell of its own, so a pass starts from no state of the one before. The schedule starts one duty a pass.
rigPasses(){ rigRun 'for rigPass in 1 2 3 ; do ( AgentsToolsScheduleLoop ) ; done' ; }
rigHold(){ ## on|off
	if [ "$1" = on ] ; then rigRun 'AgentsToolsScheduleOverride --override-flag holding > /dev/null'
	else rigRun 'AgentsToolsScheduleOverride --override-flag --no holding > /dev/null' ; fi
}
rigStarts(){ ## the members whose duty the passes started, in the order they were started
	LC_ALL=C awk -F '\t' '$1 == "start" { sub( /^work-duty\./, "", $2 ) ; printf "%s ", $2 ; }' "$rigTmp/calls"
}
rigCalls(){ ## a line of the call log, whole -- how many times it stands there
	LC_ALL=C grep -c -x -F -- "$1" "$rigTmp/calls" || :
}
rigReview(){ printf -- '---\ntype: task\nowner: magic-coordinator\n---\n\n# rig\n' | rigOwnerBoardPut review task-20261120T000000Z-rig-review.md || rigRefuse "the review item could not be written" ; }
rigNoReview(){ rm -f "$rigData/board/review"/*.md ; }

echo "-- 1. under a hold no new work starts, and the review goes on --"
rigHold on
rigAssert "the rig is holding: the flags line says so" "$( rigRun 'AgentsToolsScheduleCurrentFlags --current-flags' ; LC_ALL=C grep -c -x 'holding: yes' "$rigTmp/out" || : )" 1
rigReview
rigPasses
rigAssert "the board has a review item: only the coordinator's duty is started" "$( rigStarts )" "magic-coordinator "
rigAssert "no autorun routine is started" "$( rigCalls autorun )" 0
rigAssert "no pending board item is started" "$( rigCalls start-pending )" 0
rigAssert "no supervision is started" "$( rigCalls supervision )" 0
rigAssert "no emergency start is made" "$( rigCalls emergency )" 0
rigAssert "no retest drain is started" "$( rigCalls retest )" 0
rigAssert "the finished runs are released, in each of the three passes" "$( rigCalls idle-runs )" 3
rigAssert "and what ended is reported, and the learning step runs" "$( rigCalls report ):$( rigCalls learn )" "3:3"
rigNoReview
rigPasses
rigAssert "the board has no news: no duty is started, whatever the inboxes hold" "$( rigStarts )" ""

echo "-- 2. under a hold a dead duty record is closed and a live duty's lifetime runs --"
rigStale="$rigTmp/dead.spawn.md"
rigPasses
rigAssert "a dead duty record is closed in each pass" "$( rigCalls "$( printf 'close\t%s' "$rigStale" )" )" 3
rigStale=""
## The coordinator holds a live duty too, so no start in the pass ends the walk before the keeper's duty is reached.
printf 'keeper-rig-one\nmagic-coordinator\n' > "$rigTmp/duty"
rigPasses
rigAssert "the lifetime rule of a member's live duty runs in each pass" "$( rigCalls "$( printf 'lifetime\tkeeper-rig-one' )" )" 3
: > "$rigTmp/duty"

echo "-- 3. the controls: the same rig with no hold --"
rigHold off
rigAssert "the flags line says no hold" "$( rigRun 'AgentsToolsScheduleCurrentFlags --current-flags' ; LC_ALL=C grep -c -x 'holding: no' "$rigTmp/out" || : )" 1
rigReview
rigPasses
rigAssert "with a review item the whole roster is started, the coordinator first" "$( rigStarts )" "magic-coordinator keeper-rig-one keeper-rig-two "
rigAssert "the autorun, the pending start, the supervision, the emergency and the retest steps all run" \
	"$( rigCalls autorun ):$( rigCalls start-pending ):$( rigCalls supervision ):$( rigCalls emergency ):$( rigCalls retest )" "3:3:3:3:3"
rigAssert "the finished runs are released as under the hold" "$( rigCalls idle-runs )" 3
rigNoReview
rigPasses
rigAssert "with no board news the roster is still started, on its inbox work" "$( rigStarts )" "magic-coordinator keeper-rig-one keeper-rig-two "
rigStale="$rigTmp/dead.spawn.md"
rigPasses
rigAssert "a dead duty record is closed in each pass, as under the hold" "$( rigCalls "$( printf 'close\t%s' "$rigStale" )" )" 3
rigStale=""
## The coordinator holds a live duty too, so no start in the pass ends the walk before the keeper's duty is reached.
printf 'keeper-rig-one\nmagic-coordinator\n' > "$rigTmp/duty"
rigPasses
rigAssert "the lifetime rule of a live duty runs in each pass, as under the hold" "$( rigCalls "$( printf 'lifetime\tkeeper-rig-one' )" )" 3
: > "$rigTmp/duty"

echo "-- 4. cleared again, a hold that was set and lifted leaves nothing behind --"
rigHold on
rigHold off
rigReview
rigPasses
rigAssert "after the hold is lifted the roster is started again" "$( rigStarts )" "magic-coordinator keeper-rig-one keeper-rig-two "
rigAssert "and the pass no longer says it is holding" "$( LC_ALL=C grep -c 'holding:' "$rigTmp/out" || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE HOLD FLOOR CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_HOLD_FLOOR: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
