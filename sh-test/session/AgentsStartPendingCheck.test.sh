#!/usr/bin/env bash
## Behavioural check on `AgentsToolsScheduleStartPending` (AgentsTools.DispatcherSchedule.include), run rather than read: the schedule thread's start of an
## approved item of board-pending, with no agent, one an pass. The spawner, the pace, the items tool and the lookups of live sessions are stubs, so the check
## decides what the function chooses and nothing is started. Held: a slow machine (the pace gate) starts nothing; an item with no `approved-by` is not started;
## a recheck date that is not due holds an item, and one that is due does not; an item is started with its routine and its members and moved to running first;
## an item whose start is its owner alone, and whose owner holds a live duty, is left for that duty, unless it is urgent or emergency or the emergency flag is
## on; an item with a restart-session group is started whatever the owner's duty; a member that runs a session already gets another only at a median tool call
## of 5 s or less, unless the item is urgent or emergency; one item is started a pass, the oldest by name, and an item the rules leave is no hold on the next.
## Offline: nothing is spawned, posted or moved.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/session/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's functions are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsStartPendingCheck )" || exit 1
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
rigPending="$rigData/board/pending"
rigSpawnLog="$rigTmp/spawn.log"
rigItemsLog="$rigTmp/items.log"
mkdir -p "$rigPending" "$rigWs/.local"
## A tree of the origin's own, with the one items tool stubbed and the one awk the function reads, as real copies.
rigOrigin="$rigTmp/origin"
mkdir -p "$rigOrigin/myx/myx.distro-agents/sh-scripts" "$rigOrigin/myx/myx.distro-.local/sh-lib/output"
cp "$rigRealOrigin/myx/myx.distro-.local/sh-lib/output/LocalIsoToEpoch.awk" "$rigOrigin/myx/myx.distro-.local/sh-lib/output/LocalIsoToEpoch.awk" || rigRefuse "the date awk is not there"
cat > "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh" <<'RIGITEMS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${RIG_ITEMS_LOG:?}"
[ -z "${RIG_ITEMS_FAIL:-}" ] || { echo "⛔ ERROR: the move was refused" >&2 ; exit 1 ; }
exit 0
RIGITEMS
export RIG_ITEMS_LOG="$rigItemsLog"

export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDSC_CMD=check
## The two includes are sourced as the schedule thread sources them, with no `set -u`: they read variables a caller may not have set.
set +u
MDLT_ORIGIN="$rigRealOrigin" . "$rigHere/session/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
MDLT_ORIGIN="$rigRealOrigin" . "$rigHere/board/AgentsTools.BoardItemHandler.include" > /dev/null 2>&1
set -u
type AgentsToolsScheduleStartPending > /dev/null 2>&1 || rigRefuse "AgentsToolsScheduleStartPending is not defined by sourcing the schedule's functions"
type AgentsToolsBoardItemKey > /dev/null 2>&1 || rigRefuse "the board item key reader is not defined"
export MDLT_ORIGIN="$rigOrigin"

## The stubs: what the function asks of the rest of the tooling.
rigMedian=1000 rigDutyMembers="" rigRunMembers="" rigEmergency=no rigWorktime=yes
AgentsToolsScheduleCurrentFlags(){ printf 'worktime: %s\novertime: no\nemergency: %s\n' "$rigWorktime" "$rigEmergency" ; }
AgentsToolsBoardItemHandler(){ printf 'routine\tmagic-team.verify.routine.md\tstub\n' ; }
AgentsToolsScheduleSpawn(){ printf '%s\n' "$*" >> "$rigSpawnLog" ; }
AgentsToolsSchedulePaceText(){ ## the median the check sets, against the limit the caller sets
	local paceLimit="${MDAT_TOOL_PACE_MS:-7000}"
	if [ "$rigMedian" -lt "$paceLimit" ] ; then printf 'pace: %s of 300 calls in 30 minutes -- under %s, a duty start is allowed\n' "$rigMedian" "$paceLimit"
	else printf 'pace: %s of 300 calls in 30 minutes -- over %s, a duty start is held\n' "$rigMedian" "$paceLimit" ; fi
}
AgentsToolsScheduleWorkDutyRecord(){ case " $rigDutyMembers " in *" $1 "*) printf 'record\n' ; return 0 ;; esac ; return 1 ; }
AgentsToolsScheduleMemberRuns(){ case " $rigRunMembers " in *" $1 "*) return 0 ;; esac ; return 1 ; }
AgentsToolsScheduleOverrideLeft(){ [ "$1" = MDAT_SCHEDULE_EMERGENCY ] && [ "$rigEmergency" = yes ] && printf 'on\n' ; return 0 ; }

rigItem(){ ## file name, then header lines -- one board item
	local itemName="$1"
	shift
	{ printf '%s\n' '---' ; printf '%s\n' "$@" ; printf '%s\n' '---' '' '# an item' ; } > "$rigPending/$itemName"
}
rigReset(){ rm -f "$rigPending"/*.md "$rigSpawnLog" "$rigItemsLog" ; rigMedian=1000 rigDutyMembers="" rigRunMembers="" rigEmergency=no rigWorktime=yes ; unset RIG_ITEMS_FAIL ; }
rigSpawned(){ [ -f "$rigSpawnLog" ] && wc -l < "$rigSpawnLog" | tr -d ' ' || printf '0' ; }
rigRunPass(){ rigOut="$( AgentsToolsScheduleStartPending 2>&1 )" ; }

rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigMedian=9000 ; rigRunPass
rigAssert "a slow machine (median 9 s) starts nothing, and says the pace gate held it" "$( rigSpawned ):$( printf '%s\n' "$rigOut" | grep -c 'held by the pace gate' )" "0:1"

rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigRunPass
rigAssert "a fast machine starts an approved item, once, with its routine and its member" "$( rigSpawned ):$( awk '{ print $1, $2, $3, $4 }' "$rigSpawnLog" )" "1:pending.task-a --routine magic-team.verify.routine.md --description"
rigAssert "the spawn names the member as its last word" "$( awk '{ print $NF }' "$rigSpawnLog" )" "magic-developer"
rigAssert "the item was moved to running first (the first call), by the items tool, from pending" "$( head -1 "$rigItemsLog" | cut -c1-100 )" "--advance-to-running --team-member magic-coordinator task-a.md --from-state:pending"

rigReset
rigItem task-a.md 'owner: magic-developer'
rigRunPass
rigAssert "an item with no approved-by is not started" "$( rigSpawned ):$( [ -f "$rigItemsLog" ] && echo moved || echo untouched )" "0:untouched"

rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'recheck-date: 2099-01-01 00:00 +0000'
rigRunPass
rigAssert "a recheck date that is not due holds the item" "$( rigSpawned )" "0"
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'recheck-date: 2000-01-01 00:00 +0000'
rigRunPass
rigAssert "a recheck date that is due does not" "$( rigSpawned )" "1"

rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer'
RIG_ITEMS_FAIL=1 ; export RIG_ITEMS_FAIL ; rigRunPass
rigAssert "an item the board refuses to move is not started, and the refusal is said" "$( rigSpawned ):$( printf '%s\n' "$rigOut" | grep -c 'not moved to running, nothing started' )" "0:1"
unset RIG_ITEMS_FAIL

rigReset
rigDutyMembers="magic-developer"
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigRunPass
rigAssert "BATCHING: an item whose owner holds a live duty is left for that duty, not started, not moved" "$( rigSpawned ):$( [ -f "$rigItemsLog" ] && echo moved || echo untouched )" "0:untouched"
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'mark: urgent'
rigRunPass
rigAssert "an urgent item is started whatever the owner's duty" "$( rigSpawned )" "1"
rigReset
rigDutyMembers="magic-developer" rigEmergency=yes
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigRunPass
rigAssert "with the emergency flag on, an item is started whatever the owner's duty" "$( rigSpawned )" "1"
rigReset
rigDutyMembers="magic-developer"
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-coordinator' 'restart-session: magic-developer, magic-tester'
rigRunPass
rigAssert "an item with a restart-session group is started, since its group does not own it: both members, as two words" "$( rigSpawned ):$( awk '{ print $(NF-1) " " $NF }' "$rigSpawnLog" )" "1:magic-developer magic-tester"
rigReset
rigDutyMembers="magic-developer"
rigItem task-a.md 'approved-by: human-owner' 'owner: keeper-myx'
rigRunPass
rigAssert "an item whose owner holds no duty is started: the duty of another member is no hold" "$( rigSpawned )" "1"

rigReset
rigRunMembers="magic-tester"
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-tester'
rigMedian=6000 ; rigRunPass
rigAssert "THROTTLE: a member that runs a session, at a median of 6 s (under the 7 s gate), is given no second one" "$( rigSpawned )" "0"
rigMedian=4000 ; rigRunPass
rigAssert "at 4 s it is" "$( rigSpawned )" "1"
rigReset
rigRunMembers="magic-tester"
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-tester' 'mark: urgent'
rigMedian=6000 ; rigRunPass
rigAssert "an urgent item is given its session at 6 s all the same" "$( rigSpawned )" "1"
rigReset
rigRunMembers="magic-tester"
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-tester'
rigMedian=6000 rigEmergency=yes ; rigRunPass
rigAssert "with the emergency flag on, the throttle gives way" "$( rigSpawned )" "1"
rigReset
rigRunMembers="magic-tester"
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigMedian=6000 ; rigRunPass
rigAssert "a member with no session of its own is started at 6 s: the throttle is for a second session of a member" "$( rigSpawned )" "1"

rigReset
rigRunMembers="magic-tester"
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-tester'
rigItem task-b.md 'approved-by: human-owner' 'owner: magic-developer'
rigMedian=6000 ; rigRunPass
rigAssert "an item the rules leave is no hold on the next: the first is left at 6 s, the second is started" "$( rigSpawned ):$( awk '{ print $NF }' "$rigSpawnLog" )" "1:magic-developer"
rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigItem task-b.md 'approved-by: human-owner' 'owner: magic-tester'
rigRunPass
rigAssert "one item is started a pass, the oldest by name" "$( rigSpawned ):$( awk '{ print $NF }' "$rigSpawnLog" )" "1:magic-developer"

## OUT OF WORKTIME ONLY THE COORDINATOR RUNS: with worktime, overtime and emergency off, only an urgent or emergency item is started.
rigReset
rigWorktime=no
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigRunPass
rigAssert "worktime off: an approved item with no mark starts nothing, and is not moved" "$( rigSpawned ):$( [ -f "$rigItemsLog" ] && echo moved || echo untouched )" "0:untouched"
rigReset
rigWorktime=no
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'mark: urgent'
rigRunPass
rigAssert "worktime off: an urgent item is still started" "$( rigSpawned )" "1"
rigReset
rigWorktime=no
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'mark: important'
rigItem task-b.md 'approved-by: human-owner' 'owner: magic-tester' 'mark: emergency'
rigRunPass
rigAssert "worktime off: an important item waits, the emergency one after it is started" "$( rigSpawned ):$( awk '{ print $NF }' "$rigSpawnLog" )" "1:magic-tester"

if [ "$rigFails" -ne 0 ] ; then echo "⛔ START PENDING CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "START_PENDING: OK ($rigPasses assertions, offline)"
