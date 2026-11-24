#!/usr/bin/env bash
## Behavioural check on the start gate of the schedule's pending autostart (epic S22): the autostart reads the same limit the coordinator's
## dispatches meet, starts no more than it allows and picks by priority and age. `AgentsToolsScheduleStartPending` in
## AgentsTools.DispatcherSchedule.include, with the spawner, the pace, the items tool and the limit as stand-ins. Held, each against its control:
##   1. AT THE LIMIT NOTHING STARTS: an approved item is not moved to running, not spawned and stays in pending, and the line says why.
##      THE CONTROL is the same item under the limit: it is moved and spawned.
##   2. THE LIMIT IS READ ONLY WHEN AN ITEM CAN START: a pass with nothing to start does not ask for it.
##   3. AN EMERGENCY ITEM WAITS FOR THE LIMIT TOO, which the environment enforces.
##   4. THE OLDEST ITEM OF A TIER IS STARTED FIRST, whatever its type word: the stamp in the name is the age, and the type word is not.
##      THE CONTROL is the pair whose type word and stamp order agree. A tier still comes before age.
## Offline: nothing is spawned, posted or moved.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/schedule/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's functions are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsStartPendingLimitCheck )" || exit 1
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
rigLimitLog="$rigTmp/limit.log"
mkdir -p "$rigWs/.local"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills" rigOwnerOrigin="$MDLT_ORIGIN"
rigOwnerBoardReady
## A tree of the origin's own, so the function loads what it loads, and the one items tool stubbed on top.
rigOrigin="$rigTmp/origin"
mkdir -p "$rigOrigin/myx/myx.distro-agents/sh-scripts"
rigCopyTree "$rigRealOrigin/myx/myx.distro-.local" "$rigOrigin/myx/myx.distro-.local" || rigRefuse "the origin's local package is not there"
rigCopyTree "$rigRealOrigin/myx/myx.distro-agents/sh-lib" "$rigOrigin/myx/myx.distro-agents/sh-lib" || rigRefuse "the origin's sh-lib is not there"
cat > "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh" <<'RIGITEMS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${RIG_ITEMS_LOG:?}"
exit 0
RIGITEMS
export RIG_ITEMS_LOG="$rigItemsLog"
export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDSC_CMD=check
set +u
MDLT_ORIGIN="$rigRealOrigin" . "$rigHere/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
MDLT_ORIGIN="$rigRealOrigin" . "$rigHere/board/AgentsTools.BoardItemHandler.include" > /dev/null 2>&1
set -u
type AgentsToolsScheduleStartPending > /dev/null 2>&1 || rigRefuse "AgentsToolsScheduleStartPending is not defined by sourcing the schedule's functions"
export MDLT_ORIGIN="$rigOrigin"

## The stubs: what the function asks of the rest of the tooling. The limit is the one the spawner's own start reads (AgentsToolsSpawnLimitReached):
## the line `<running> <limit>` and rc 0 where it is reached, rc 1 where it is not.
rigLimitLine=""
AgentsToolsScheduleCurrentFlags(){ printf 'worktime: yes\novertime: no\nemergency: no\n' ; }
AgentsToolsBoardItemHandler(){ printf 'routine\tmagic-team.verify.routine.md\tstub\n' ; }
AgentsToolsScheduleSpawn(){ printf '%s\n' "$*" >> "$rigSpawnLog" ; }
AgentsToolsSchedulePaceText(){ printf 'pace: 1000 of 300 calls in 30 minutes -- under 7000, a duty start is allowed\n' ; }
AgentsToolsScheduleWorkDutyRecord(){ return 1 ; }
AgentsToolsScheduleMemberRuns(){ return 1 ; }
AgentsToolsScheduleOverrideLeft(){ return 0 ; }
AgentsToolsSpawnLimitReached(){ printf 'called\n' >> "$rigLimitLog" ; [ -n "$rigLimitLine" ] || return 1 ; printf '%s\n' "$rigLimitLine" ; }

rigItem(){ ## file name, then header lines -- one board item, written by the board's own writer
	local itemName="$1"
	shift
	{ printf '%s\n' '---' ; printf '%s\n' "$@" ; printf '%s\n' '---' '' '# an item' ; } | rigOwnerBoardPut pending "$itemName"
}
rigReset(){ rm -f "$rigPending"/*.md "$rigSpawnLog" "$rigItemsLog" "$rigLimitLog" ; rigLimitLine="" ; }
rigSpawned(){ [ -f "$rigSpawnLog" ] && wc -l < "$rigSpawnLog" | tr -d ' ' || printf '0' ; }
rigLimitReads(){ [ -f "$rigLimitLog" ] && wc -l < "$rigLimitLog" | tr -d ' ' || printf '0' ; }
rigFirst(){ [ -f "$rigSpawnLog" ] && LC_ALL=C awk 'NR == 1 { print $1 ; }' "$rigSpawnLog" || printf 'none' ; }
rigRunPass(){ rigOut="$( AgentsToolsScheduleStartPending 2>&1 )" ; }

echo "-- 1. at the limit nothing starts --"
rigReset
rigItem task-20261101T0000Z-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigLimitLine="3 3" ; rigRunPass
rigAssert "at the limit the approved item is not spawned and not moved to running" \
	"$( rigSpawned ):$( [ -f "$rigItemsLog" ] && echo moved || echo untouched )" "0:untouched"
rigAssert "and the line names the limit and what runs" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F 'start-pending: held by the spawn limit, 3 runs of 3 allowed, nothing started' )" 1
rigReset
rigItem task-20261101T0000Z-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigRunPass
rigAssert "CONTROL: under the limit the same item is spawned and moved to running first" \
	"$( rigSpawned ):$( LC_ALL=C awk 'NR == 1 { print $1 ; }' "$rigItemsLog" )" "1:--advance-to-running"

echo "-- 2. the limit is read only when an item can start --"
rigReset
rigRunPass
rigAssert "a pass with nothing pending does not ask for the limit" "$( rigLimitReads )" 0
rigItem task-20261101T0000Z-a.md 'owner: magic-developer'
rigRunPass
rigAssert "a pass whose only item has no go does not ask for it" "$( rigLimitReads )" 0
rigItem task-20261101T0000Z-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigRunPass
rigAssert "CONTROL: a pass with an item that can start asks for it once" "$( rigLimitReads )" 1

echo "-- 3. an emergency item waits for the limit too --"
rigReset
rigItem task-20261101T0000Z-a.md 'approved-by: human-owner' 'owner: magic-developer' 'mark: emergency'
rigLimitLine="3 3" ; rigRunPass
rigAssert "at the limit an emergency item is not spawned either" "$( rigSpawned )" 0

echo "-- 4. the oldest item of a tier first, whatever its type word --"
rigReset
rigItem inquiry-20261105T0000Z-newer.md 'approved-by: human-owner' 'owner: magic-tester'
rigItem task-20261101T0000Z-older.md 'approved-by: human-owner' 'owner: magic-developer'
rigRunPass
rigAssert "the older task is started before the newer inquiry that sorts first by name" "$( rigFirst )" "pending.task-20261101T0000Z-older"
rigReset
rigItem inquiry-20261101T0000Z-older.md 'approved-by: human-owner' 'owner: magic-tester'
rigItem task-20261105T0000Z-newer.md 'approved-by: human-owner' 'owner: magic-developer'
rigRunPass
rigAssert "CONTROL: the older inquiry, which sorts first by name too, is started first" "$( rigFirst )" "pending.inquiry-20261101T0000Z-older"
rigReset
rigItem inquiry-20261105T0000Z-newer.md 'approved-by: human-owner' 'owner: magic-tester' 'mark: urgent'
rigItem task-20261101T0000Z-older.md 'approved-by: human-owner' 'owner: magic-developer' 'mark: urgent'
rigRunPass
rigAssert "within the urgent tier the older item is started first as well" "$( rigFirst )" "pending.task-20261101T0000Z-older"
rigReset
rigItem task-20261101T0000Z-older.md 'approved-by: human-owner' 'owner: magic-developer'
rigItem task-20261105T0000Z-urgent.md 'approved-by: human-owner' 'owner: magic-tester' 'mark: urgent'
rigRunPass
rigAssert "a tier comes before age: the newer urgent item is started before the older unmarked one" "$( rigFirst )" "pending.task-20261105T0000Z-urgent"
rigReset
rigItem task-20261101T0000Z-urgent.md 'approved-by: human-owner' 'owner: magic-developer' 'mark: urgent'
rigItem task-20261105T0000Z-emergency.md 'approved-by: human-owner' 'owner: magic-tester' 'mark: emergency'
rigRunPass
rigAssert "and an emergency item before an older urgent one" "$( rigFirst )" "pending.task-20261105T0000Z-emergency"

if [ "$rigFails" -ne 0 ] ; then echo "⛔ START PENDING LIMIT CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "START_PENDING_LIMIT: OK ($rigPasses assertions, offline)"
