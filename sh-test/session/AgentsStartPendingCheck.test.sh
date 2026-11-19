#!/usr/bin/env bash
## Behavioural check on `AgentsToolsScheduleStartPending` (AgentsTools.DispatcherSchedule.include), run rather than read: the schedule thread's start of an
## approved item of board-pending, with no agent, one an pass. The spawner, the pace, the items tool and the lookups of live sessions are stubs, so the check
## decides what the function chooses and nothing is started. Held: a slow machine (the pace gate) starts nothing; an item with no `approved-by` is not started;
## a recheck date that is not due holds an item whose condition stands, and one that is due does not; an item is started with its routine and its members and moved to running first;
## an item whose start is its owner alone, and whose owner holds a live duty, is left for that duty, unless it is urgent or emergency or the emergency flag is
## on; an item with a restart-session group is started whatever the owner's duty; a member that runs a session already gets another only at a median tool call
## of 5 s or less, unless the item is urgent or emergency; one item is started a pass, the oldest by name, and an item the rules leave is no hold on the next.
## Offline: nothing is spawned, posted or moved.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/schedule/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's functions are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsStartPendingCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
## Every store of this rig is written by its owner's own writer, never by hand here: the board through
## rigOwnerBoardPut, the vault through rigOwnerVaultPut, and a board item of odd frontmatter through rigOwnerStoreItem.
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
## A tree of the origin's own: its whole sh-lib and sh-scripts as real copies, so the function loads what it loads,
## and the one items tool stubbed on top.
rigOrigin="$rigTmp/origin"
mkdir -p "$rigOrigin/myx/myx.distro-agents/sh-scripts"
cp -RL "$rigRealOrigin/myx/myx.distro-.local" "$rigOrigin/myx/myx.distro-.local" || rigRefuse "the origin's local package is not there"
cp -RL "$rigRealOrigin/myx/myx.distro-agents/sh-lib" "$rigOrigin/myx/myx.distro-agents/sh-lib" || rigRefuse "the origin's sh-lib is not there"
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
MDLT_ORIGIN="$rigRealOrigin" . "$rigHere/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
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

rigItem(){ ## file name, then header lines -- one board item, written by the board's own writer
	local itemName="$1"
	shift
	{ printf '%s\n' '---' ; printf '%s\n' "$@" ; printf '%s\n' '---' '' '# an item' ; } | rigOwnerBoardPut pending "$itemName"
}
rigReset(){ rm -f "$rigPending"/*.md "$rigData/vault"/*.md "$rigSpawnLog" "$rigItemsLog" ; rigMedian=1000 rigDutyMembers="" rigRunMembers="" rigEmergency=no rigWorktime=yes ; unset RIG_ITEMS_FAIL ; }
rigSpawned(){ [ -f "$rigSpawnLog" ] && wc -l < "$rigSpawnLog" | tr -d ' ' || printf '0' ; }
rigRunPass(){ rigOut="$( AgentsToolsScheduleStartPending 2>&1 )" ; }

rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigMedian=9000 ; rigRunPass
rigAssert "a slow machine (median 9 s) starts nothing, and says the pace gate held it" "$( rigSpawned ):$( printf '%s\n' "$rigOut" | grep -c 'held by the pace gate' )" "0:1"

rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer'
rigItem task-b.md 'approved-by: human-owner' 'owner: magic-tester' 'mark: urgent'
rigMedian=9000 ; rigRunPass
rigAssert "on a slow machine an urgent item starts whatever the pace, and the one with no mark waits" "$( rigSpawned ):$( awk '{ print $NF }' "$rigSpawnLog" )" "1:magic-tester"

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

## THE GO OF THE EPIC: a child carries `epic:` alone, and the go is read live from that blueprint.
rigEpic(){ ## blueprint file name, then its frontmatter lines -- one epic blueprint in the rig's vault
	local epicName="$1"
	shift
	{ printf '%s\n' '---' 'document-contract: vault-item.epic-blueprint' 'type: epic-blueprint' 'from: magic-coordinator' 'date: 2026-11-02 00:00 +0200' ; printf '%s\n' "$@" ; printf '%s\n' '---' '' '# an epic' ; } | rigOwnerVaultPut "$epicName"
}
rigReset
rigEpic epic-blueprint-20261102T0000Z-rig.md 'approved-by: human-owner (rig-session, 2026-11-02T09:00:00Z)' 'approved-at: 2026-11-02 11:00 +0200'
rigItem task-a.md 'epic: epic-blueprint-20261102T0000Z-rig' 'owner: magic-developer'
rigRunPass
rigAssert "an item whose epic carries a go is started, and moved to running first" "$( rigSpawned ):$( awk '{ print $NF }' "$rigSpawnLog" ):$( [ -f "$rigItemsLog" ] && LC_ALL=C awk 'NR == 1 { print $1, $2, $3 }' "$rigItemsLog" || echo untouched )" "1:magic-developer:--advance-to-running --team-member magic-coordinator"
rigReset
rigEpic epic-blueprint-20261102T0000Z-rig.md ''
rigItem task-a.md 'epic: epic-blueprint-20261102T0000Z-rig' 'owner: magic-developer'
rigRunPass
rigAssert "the same item, a blueprint with no go: not started, not moved" "$( rigSpawned ):$( [ -f "$rigItemsLog" ] && echo moved || echo untouched )" "0:untouched"

rigReset
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'condition: the rig waits for an answer' 'recheck-date: 2099-01-01 00:00 +0000'
rigRunPass
rigAssert "a recheck date that is not due holds an item whose condition stands" "$( rigSpawned )" "0"
rigItem task-a.md 'approved-by: human-owner' 'owner: magic-developer' 'condition: the rig waits for an answer' 'recheck-date: 2000-01-01 00:00 +0000'
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

## A VERIFY ONLY AFTER NEW WORK, ITS VERDICT KEPT UNTIL THE ITEM CHANGES: read off the records once, then off the kept verdict while the item is unchanged.
rigReset
rigItem task-v.md 'approved-by: human-owner' 'owner: magic-developer'
printf -- '---\nspawn-id: rig-verify-1\nstatus: spawn-succeeded\nstarted-at: 2026-11-01 10:00 +0000\nroutine: magic-team.verify.routine.md\ndescription: Board item task-v.md, approved\n---\n\n# rig\n' | rigOwnerSpawnPut rig-verify-1 || rigRefuse "the record of the verify run could not be written"
rigRunPass
rigAssert "an item whose newest run was a verify is not started, and its verdict is kept" \
	"$( rigSpawned ):$( printf '%s\n' "$rigOut" | grep -c 'a verify waits for new work' ):$( cat "$rigWs/.local/agents/schedule/verify-stale/task-v.md" 2> /dev/null )" "0:1:stale"
rm -rf "$rigWs/.local/agents/spawned/rig-verify-1"
rigRunPass
rigAssert "the item unchanged, the next pass takes the kept verdict and reads no record: not started, though that record is gone" \
	"$( rigSpawned ):$( printf '%s\n' "$rigOut" | grep -c 'a verify waits for new work' )" "0:1"
sleep 1 ; rigItem task-v.md 'approved-by: human-owner' 'owner: magic-developer'
rigRunPass
rigAssert "the item written since, the verdict is read again: no verify on record now, so it is started" "$( rigSpawned )" "1"
## A KEPT VERDICT GOES WITH ITS ITEM: three verify items, each with its verdict kept, then none of them pending any more.
rigReset
for rigVerify in task-v1 task-v2 task-v3 ; do
	rigItem "$rigVerify.md" 'approved-by: human-owner' 'owner: magic-developer'
	printf -- '---\nspawn-id: rig-%s\nstatus: spawn-succeeded\nstarted-at: 2026-11-01 10:00 +0000\nroutine: magic-team.verify.routine.md\ndescription: Board item %s.md, approved\n---\n\n# rig\n' "$rigVerify" "$rigVerify" \
		| rigOwnerSpawnPut "rig-$rigVerify" || rigRefuse "the record of a verify run could not be written"
done
rigRunPass
rigAssert "three verify items processed: three verdicts kept" "$( ls "$rigWs/.local/agents/schedule/verify-stale" 2> /dev/null | LC_ALL=C grep -c -x 'task-v[123].md' )" "3"
rigReset
rigRunPass
rigAssert "none of them pending any more, moved on or gone: no kept file is left" "$( ls "$rigWs/.local/agents/schedule/verify-stale" 2> /dev/null | LC_ALL=C grep -c 'task-v' )" "0"

if [ "$rigFails" -ne 0 ] ; then echo "⛔ START PENDING CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "START_PENDING: OK ($rigPasses assertions, offline)"
