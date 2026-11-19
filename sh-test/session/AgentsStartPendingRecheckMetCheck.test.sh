#!/usr/bin/env bash
## Behavioural check on `AgentsToolsScheduleStartPending` (AgentsTools.DispatcherSchedule.include): a recheck-date re-checks an unmet `condition:`, so a date
## not yet due holds an approved pending item only while its condition stands. An item whose condition reads `met` or `none` (any case, past leading
## spaces, the documented `met: …` and `none: …` forms included), or carries none, is started. A date its reader cannot take holds nothing.
## The work-duty's conflict gate holds an item so, by an unmet condition beside its date, and its routine names the call that writes both.
## Offline: the pace, the flags, the routine lookup, the spawn and the items tool are stubs, so nothing is spawned, posted or moved.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/schedule/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's functions are not at the origin this workspace resolves: $rigHere"
rigDuty="${rigHere%/sh-lib}/skillset/magic-team/magic-coordinator/magic-coordinator.work-duty.routine.md"
[ -f "$rigDuty" ] || rigRefuse "the work-duty routine is not at the origin this workspace resolves: $rigDuty"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsStartPendingRecheckMetCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigRealOrigin="$MDLT_ORIGIN"
rigWs="$rigTmp/ws"
rigData="$rigWs/data"
rigSpawnLog="$rigTmp/spawn.log"
rigItemsLog="$rigTmp/items.log"
mkdir -p "$rigWs/.local"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills" rigOwnerOrigin="$MDLT_ORIGIN"
rigOwnerBoardReady
## A tree of the origin's own, as real copies, so the function loads what it loads, and the one items tool stubbed on top.
rigOrigin="$rigTmp/origin"
mkdir -p "$rigOrigin/myx/myx.distro-agents/sh-scripts"
cp -RL "$rigRealOrigin/myx/myx.distro-.local" "$rigOrigin/myx/myx.distro-.local" || rigRefuse "the origin's local package is not there"
cp -RL "$rigRealOrigin/myx/myx.distro-agents/sh-lib" "$rigOrigin/myx/myx.distro-agents/sh-lib" || rigRefuse "the origin's sh-lib is not there"
printf '%s\n' '#!/usr/bin/env bash' 'printf '"'"'%s\n'"'"' "$*" >> "${RIG_ITEMS_LOG:?}"' > "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh"
export RIG_ITEMS_LOG="$rigItemsLog"
export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDSC_CMD=check
## Sourced as the schedule thread sources them, with no `set -u`: they read variables a caller may not have set.
set +u
MDLT_ORIGIN="$rigRealOrigin" . "$rigHere/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
set -u
type AgentsToolsScheduleStartPending > /dev/null 2>&1 || rigRefuse "AgentsToolsScheduleStartPending is not defined by sourcing the schedule's functions"
export MDLT_ORIGIN="$rigOrigin"

## The stubs: a fast machine in worktime, no duty and no run of any member, a routine that is no verify.
AgentsToolsScheduleCurrentFlags(){ printf 'worktime: yes\novertime: no\nemergency: no\n' ; }
AgentsToolsBoardItemHandler(){ printf 'routine\tmagic-team.coworking.routine.md\tstub\n' ; }
AgentsToolsScheduleSpawn(){ printf '%s\n' "$*" >> "$rigSpawnLog" ; }
AgentsToolsSchedulePaceText(){ printf 'pace: 1000 of 300 calls in 30 minutes -- under 7000, a duty start is allowed\n' ; }
AgentsToolsScheduleWorkDutyRecord(){ return 1 ; }
AgentsToolsScheduleMemberRuns(){ return 1 ; }
AgentsToolsScheduleOverrideLeft(){ return 0 ; }

rigPass(){ ## header lines of the one pending item -- what the pass did: started or held
	rm -f "$rigData/board/pending"/*.md "$rigSpawnLog" "$rigItemsLog"
	{ printf '%s\n' '---' 'approved-by: human-owner' 'owner: magic-developer' "$@" ; printf '%s\n' '---' '' '# an item' ; } | rigOwnerBoardLegacyPut task-a.md
	AgentsToolsScheduleStartPending > /dev/null 2>&1
	if [ -s "$rigSpawnLog" ] && [ -s "$rigItemsLog" ] ; then printf 'started' ; else printf 'held' ; fi
}

rigAssert "control: an unmet condition with a recheck-date that is due is started" \
	"$( rigPass 'condition: the rig waits for an answer' 'recheck-date: 2000-01-01 00:00 +0000' )" started
rigAssert "an unmet condition with a recheck-date not yet due is held" \
	"$( rigPass 'condition: the rig waits for an answer' 'recheck-date: 2099-01-01 00:00 +0000' )" held
rigAssert "a met condition with a recheck-date not yet due is started" \
	"$( rigPass 'condition: met 2026-11-18 07:20 +0200: the answer arrived' 'recheck-date: 2099-01-01 00:00 +0000' )" started
rigAssert "a condition that reads none, with a recheck-date not yet due, is started" \
	"$( rigPass 'condition: none. Started by the rig' 'recheck-date: 2099-01-01 00:00 +0000' )" started
rigAssert "no condition, with a recheck-date not yet due, is started" \
	"$( rigPass 'recheck-date: 2099-01-01 00:00 +0000' )" started
rigAssert "a condition whose first word only begins with met is unmet, and held" \
	"$( rigPass 'condition: metrics are read again' 'recheck-date: 2099-01-01 00:00 +0000' )" held
rigAssert "the met: form with a date not yet due is started" \
	"$( rigPass 'condition: met: 2026-11-18 07:20 +0200: the answer arrived' 'recheck-date: 2099-01-01 00:00 +0000' )" started
rigAssert "the none: form with a date not yet due is started" \
	"$( rigPass 'condition: none: the item waits for nothing' 'recheck-date: 2099-01-01 00:00 +0000' )" started
rigAssert "Met: in another case is started" \
	"$( rigPass 'condition: Met: the answer arrived' 'recheck-date: 2099-01-01 00:00 +0000' )" started
rigAssert "NONE. in capitals is started" \
	"$( rigPass 'condition: NONE.' 'recheck-date: 2099-01-01 00:00 +0000' )" started
rigAssert "met behind leading spaces is started" \
	"$( rigPass 'condition:    met: the answer arrived' 'recheck-date: 2099-01-01 00:00 +0000' )" started
rigAssert "the unmet: form with a date not yet due is held" \
	"$( rigPass 'condition: unmet: the rig waits for an answer' 'recheck-date: 2099-01-01 00:00 +0000' )" held
rigAssert "an unreadable recheck-date holds nothing, beside an unmet condition too" \
	"$( rigPass 'condition: unmet: the rig waits for an answer' 'recheck-date: someday soon' )" started
rigAssert "a conflict-gate hold, as the work-duty writes it, is held while the conflict stands" \
	"$( rigPass 'condition: unmet: conflicts with task-rig-running' 'recheck-date: 2099-01-01 00:00 +0000' )" held
rigAssert "the work-duty's conflict gate names the call that writes that condition beside its date" \
	"$( LC_ALL=C grep -c -F -- '`--move-to-pending <item> --from-state:pending --header:upsert:condition:unmet: conflicts with <job> --recheck-in <n>`' "$rigDuty" || : )" 1

if [ "$rigFails" -ne 0 ] ; then echo "⛔ START PENDING RECHECK MET CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "START_PENDING_RECHECK_MET: OK ($rigPasses assertions, offline)"
