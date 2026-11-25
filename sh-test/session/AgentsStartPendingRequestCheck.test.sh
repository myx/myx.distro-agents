#!/usr/bin/env bash
## Behavioural check on the REQUEST THREAD of `AgentsToolsScheduleStartPending` (AgentsTools.DispatcherSchedule.include), run rather than read: the start of an
## approved item of board-pending passes the thread of the Slack message the item traces to, and says so where it cannot. The spawner, the pace and the items
## tool are stubs, so what is measured is the spawner's own argument list. Every row is an assertion. Held:
##   1. An item whose `communication-channel-id` is `slack:<channel>:<ts>` is started with `--conversation <channel>:<ts>` before its members.
##   2. An item with no header, or an email one, is started with the old arguments, byte for byte, and says nothing.
##   3. A header that names no thread, and an item from a Slack inbox item with no header, are each said once, at the start, and the start goes on with no flag.
##   4. The line is said only where a start is made: an item with no approval, one held by the pace gate, one whose recheck date is not due and one the board
##      refuses to move say nothing, on every pass.
## Offline: nothing is spawned, posted or moved.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/schedule/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's functions are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsStartPendingRequestCheck )" || exit 1
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
mkdir -p "$rigWs/.local"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills" rigOwnerOrigin="$MDLT_ORIGIN"
rigOwnerBoardReady
rigOrigin="$rigTmp/origin"
mkdir -p "$rigOrigin/myx/myx.distro-agents/sh-scripts"
rigCopyTree "$rigRealOrigin/myx/myx.distro-.local" "$rigOrigin/myx/myx.distro-.local" || rigRefuse "the origin's local package is not there"
rigCopyTree "$rigRealOrigin/myx/myx.distro-agents/sh-lib" "$rigOrigin/myx/myx.distro-agents/sh-lib" || rigRefuse "the origin's sh-lib is not there"
cat > "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh" <<'RIGITEMS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${RIG_ITEMS_LOG:?}"
[ -z "${RIG_ITEMS_FAIL:-}" ] || { echo "⛔ ERROR: the move was refused" >&2 ; exit 1 ; }
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

rigMedian=1000 rigDutyMembers="" rigRunMembers="" rigEmergency=no rigWorktime=yes
AgentsToolsScheduleCurrentFlags(){ printf 'worktime: %s\novertime: no\nemergency: %s\n' "$rigWorktime" "$rigEmergency" ; }
AgentsToolsBoardItemHandler(){ printf 'routine\tmagic-team.verify.routine.md\tstub\n' ; }
AgentsToolsScheduleSpawn(){ printf '%s\n' "$*" >> "$rigSpawnLog" ; }
AgentsToolsSchedulePaceText(){
	local paceLimit="${MDAT_TOOL_PACE_MS:-7000}"
	if [ "$rigMedian" -lt "$paceLimit" ] ; then printf 'pace: %s of 300 calls in 30 minutes -- under %s, a duty start is allowed\n' "$rigMedian" "$paceLimit"
	else printf 'pace: %s of 300 calls in 30 minutes -- over %s, a duty start is held\n' "$rigMedian" "$paceLimit" ; fi
}
AgentsToolsScheduleWorkDutyRecord(){ case " $rigDutyMembers " in *" $1 "*) printf 'record\n' ; return 0 ;; esac ; return 1 ; }
AgentsToolsScheduleMemberRuns(){ case " $rigRunMembers " in *" $1 "*) return 0 ;; esac ; return 1 ; }
AgentsToolsScheduleOverrideLeft(){ [ "$1" = MDAT_SCHEDULE_EMERGENCY ] && [ "$rigEmergency" = yes ] && printf 'on\n' ; return 0 ; }

rigItem(){ ## file name, then header lines -- one board item, written by the board's own writer
	local itemName="$1"
	shift
	{ printf '%s\n' '---' ; printf '%s\n' "$@" ; printf '%s\n' '---' '' '# an item' ; } | rigOwnerBoardPut pending "$itemName"
}
rigReset(){ rm -f "$rigPending"/*.md "$rigSpawnLog" "$rigItemsLog" ; rigMedian=1000 rigDutyMembers="" rigRunMembers="" rigEmergency=no rigWorktime=yes ; unset RIG_ITEMS_FAIL ; }
rigRunPass(){ rigOut="$( AgentsToolsScheduleStartPending 2>&1 )" ; }
rigSpawnLine(){ [ -f "$rigSpawnLog" ] && head -1 "$rigSpawnLog" || printf 'none' ; }
rigSaid(){ ## text -- how many lines of the pass held it
	printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F -- "$1" || :
}
rigOldLine="pending.task-a --routine magic-team.verify.routine.md --description Board item task-a.md, approved, started from board-pending by the schedule: run its next iteration by magic-team.verify.routine.md. The item is in board-running, its start recorded by the schedule. magic-developer"

echo "-- 1. a header with a thread is passed --"
rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'communication-channel-id: slack:CRIGREQ01:1700000000.000500'
rigRunPass
rigAssert "the start carries --conversation and the thread, just before its member" "$( rigSpawnLine | LC_ALL=C awk '{ print $(NF-2), $(NF-1), $NF ; }' )" "--conversation CRIGREQ01:1700000000.000500 magic-developer"
rigAssert "and a header that names a thread says nothing" "$( rigSaid 'request thread' )" "0"

echo "-- 2. no header, or an email one: the old arguments, byte for byte --"
rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigRunPass
rigAssert "an item with no header is started as it always was" "$( rigSpawnLine )" "$rigOldLine"
rigAssert "and says nothing about a request" "$( rigSaid 'request thread' )" "0"
rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'communication-channel-id: email:rig@example.invalid'
rigRunPass
rigAssert "an email header is started as it always was" "$( rigSpawnLine ):$( rigSaid 'request thread' )" "$rigOldLine:0"

echo "-- 3. what cannot be passed is said once, at the start --"
rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'communication-channel-id: slack:CRIGREQ01'
rigRunPass
rigAssert "a header with no thread starts the item with no flag" "$( rigSpawnLine )" "$rigOldLine"
rigAssert "and says which item, in one line" "$( rigSaid 'start-pending: task-a.md names the Slack place CRIGREQ01, which is no <channel>:<thread ts>' )" "1"
rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'references: note-20261124T0900Z-slack-1700000000.000900'
rigRunPass
rigAssert "an item from a Slack inbox item with no header starts with no flag" "$( rigSpawnLine )" "$rigOldLine"
rigAssert "and says it carries no communication-channel-id, in one line" "$( rigSaid 'start-pending: task-a.md traces to a Slack inbox item and carries no communication-channel-id' )" "1"

echo "-- 4. the line is said only where a start is made --"
rigReset
rigItem task-a.md 'owner: magic-developer' 'communication-channel-id: slack:CRIGREQ01'
rigRunPass ; rigRunPass
rigAssert "an item with no approval starts nothing and says nothing, on any pass" "$( rigSpawnLine ):$( rigSaid 'request thread' )" "none:0"
rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'communication-channel-id: slack:CRIGREQ01'
rigMedian=9000 ; rigRunPass ; rigRunPass
rigAssert "an item held by the pace gate says nothing, on any pass" "$( rigSpawnLine ):$( rigSaid 'which is no <channel>:<thread ts>' )" "none:0"
rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'condition: the rig waits for an answer' 'recheck-date: 2099-01-01 00:00 +0000' 'communication-channel-id: slack:CRIGREQ01'
rigRunPass ; rigRunPass
rigAssert "an item whose recheck date is not due says nothing, on any pass" "$( rigSpawnLine ):$( rigSaid 'which is no <channel>:<thread ts>' )" "none:0"
rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'communication-channel-id: slack:CRIGREQ01'
RIG_ITEMS_FAIL=1 ; export RIG_ITEMS_FAIL ; rigRunPass
rigAssert "an item the board refuses to move says nothing about its request" "$( rigSpawnLine ):$( rigSaid 'which is no <channel>:<thread ts>' )" "none:0"
unset RIG_ITEMS_FAIL
rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'communication-channel-id: slack:CRIGREQ01'
rigRunPass
rigAssert "CONTROL: the same item, approved and free to move, says it once at its start" "$( rigSaid 'which is no <channel>:<thread ts>' )" "1"

if [ "$rigFails" -ne 0 ] ; then echo "⛔ START PENDING REQUEST CHECK FAILED: $rigFails of $(( rigPasses + rigFails ))" >&2 ; exit 1 ; fi
echo "START_PENDING_REQUEST: OK ($rigPasses assertions, offline)"
