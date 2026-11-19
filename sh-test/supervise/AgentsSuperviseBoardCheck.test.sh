#!/usr/bin/env bash
## Behavioural check of AgentsToolsSuperviseBoard (sh-lib/supervise/AgentsTools.SuperviseBoard.include): on a rig workspace of its own,
## each kind is printed where its case holds and left out where it does not. `epic`: a still epic is marked, a moving one is not.
## `pending-skipped`: a recheck-date not due beside an unmet condition, and a verify on a task never run; a task with a build routine, one a run
## names, a due date, and a recheck-date not due beside a condition that reads met or none (any case, past leading spaces), or beside
## none, are not; a `metrics` prefix is unmet, and named. `recheck-unreadable`: a recheck-date its reader cannot take.
## `accepted-unlanded`: an accepted dispatch whose run left a stage, and not one whose item records its landing. `leftover`: a record
## still started two days on, and not one started now. Offline: no tool is called, nothing outside the rig is read or written.
## The board and the vault are injected: their owners' walkers (AgentsToolsBoardItemsInto, AgentsToolsBoardStateFoldersInto,
## AgentsToolsVaultFolderInto) and the store root are stubbed onto plain fixture folders, so the check writes no store the
## code reads. The run records are the session store's own, read through its own row reader.
set -u
rigHere="$( cd "$( dirname "$0" )/../.." && pwd )"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsSuperviseBoardCheck.XXXXXX" )" || exit 1
trap 'rm -rf "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then rigPass=$(( rigPass + 1 )) ; printf '  PASS  %s\n' "$1"
	else rigFail=$(( rigFail + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fi
}
rigWs="$rigTmp/ws" ; rigSpawned="$rigWs/.local/agents/spawned" ; rigItems="$rigTmp/items" ; rigEpics="$rigTmp/epics"
mkdir -p "$rigItems/pending" "$rigItems/running" "$rigItems/processed" "$rigEpics" "$rigSpawned"
rigItem(){ ## state, name, header lines...
	local itemState="$1" itemName="$2" ; shift 2
	{ printf -- '---\n' ; printf '%s\n' "$@" ; printf -- '---\n\n# %s\n' "$itemName" ; } > "$rigItems/$itemState/$itemName.md"
}
rigRecord(){ ## sandbox id, status, started-at, description
	mkdir -p "$rigSpawned/$1"
	printf -- '---\nspawn-id: %s\nsession-id: %s\nstatus: %s\nowner: magic-developer\nstarted-at: %s\ndescription: %s\n---\n' "$1" "$1" "$2" "$3" "$4" > "$rigSpawned/$1/$1.spawn.md"
}
## Epics: one still (edited three hours ago, nothing names it), one moving (an item naming it changed now).
printf '# still\n' > "$rigEpics/epic-blueprint-20260101T0000Z-still.md"
printf '# moving\n' > "$rigEpics/epic-blueprint-20260101T0000Z-moving.md"
touch -t "$( date -v-3H +%Y%m%d%H%M 2> /dev/null || date -d '-3 hours' +%Y%m%d%H%M )" "$rigEpics/epic-blueprint-20260101T0000Z-still.md" "$rigEpics/epic-blueprint-20260101T0000Z-moving.md"
rigItem running task-20260101T0001Z-on-moving 'type: task' 'epic: epic-blueprint-20260101T0000Z-moving'
## Running: one a live run names, one no run names.
rigItem running task-20260101T0010Z-live-run 'type: task'
rigRecord ffffffff-0000-0000-0000-000000000010 spawn-started "$( date '+%Y-%m-%d %H:%M' ) +0200" 'Board item task-20260101T0010Z-live-run.md, approved'
## Running, worked through a dispatch: a running dispatch `tracks:` the task, and the run its name ends in lives; its control, whose run has ended.
rigItem running task-20260101T0014Z-tracked 'type: task'
rigItem running dispatch-20260101T0014Z-spawn-proxy-1-14141414 'type: dispatch' 'status: dispatch-started' 'tracks: task-20260101T0014Z-tracked'
rigRecord 14141414-0000-0000-0000-000000000014 spawn-started "$( date '+%Y-%m-%d %H:%M' ) +0200" 'a dispatched build'
rigItem running task-20260101T0015Z-tracked-ended 'type: task'
## Running, worked by its owner's live duty run; its control, whose owner holds no live duty.
rigItem running task-20260101T0016Z-duty-owned 'type: task' 'owner: magic-tester'
mkdir -p "$rigSpawned/16161616-0000-0000-0000-000000000016"
printf -- '---\nspawn-id: %s\nsession-id: %s\nstatus: spawn-started\nowner: magic-tester\nstarted-at: %s\ndescription: duty\nroutine: magic-tester.work-duty.routine.md\n---\n' 16161616-0000-0000-0000-000000000016 16161616-0000-0000-0000-000000000016 "$( date '+%Y-%m-%d %H:%M' ) +0200" > "$rigSpawned/16161616-0000-0000-0000-000000000016/16161616-0000-0000-0000-000000000016.spawn.md"
rigItem running task-20260101T0017Z-duty-other 'type: task' 'owner: magic-architect'
rigItem running dispatch-20260101T0015Z-spawn-proxy-1-15151515 'type: dispatch' 'status: dispatch-started' 'tracks: task-20260101T0015Z-tracked-ended'
rigRecord 15151515-0000-0000-0000-000000000015 spawn-succeeded "$( date '+%Y-%m-%d %H:%M' ) +0200" 'a dispatched build'
## Pending: a recheck not due, a never-run verify, one with a build routine, one a run names.
rigItem pending task-20260101T0002Z-recheck 'type: task' 'approved-by: human-owner (x, 2026-01-01T00:00:00Z)' 'condition: unmet: the rig waits' 'recheck-date: 2099-01-01 08:00 +0000' 'handler-routine: magic-team.epic-build.routine.md'
rigItem pending task-20260101T0011Z-met 'type: task' 'approved-by: human-owner (x, 2026-01-01T00:00:00Z)' 'condition: met: 2026-01-01 00:00 +0000: the rig answered' 'recheck-date: 2099-01-01 08:00 +0000' 'handler-routine: magic-team.epic-build.routine.md'
rigItem pending task-20260101T0012Z-none 'type: task' 'approved-by: human-owner (x, 2026-01-01T00:00:00Z)' 'condition: none: the rig waits for nothing' 'recheck-date: 2099-01-01 08:00 +0000' 'handler-routine: magic-team.epic-build.routine.md'
rigItem pending task-20260101T0013Z-bare 'type: task' 'approved-by: human-owner (x, 2026-01-01T00:00:00Z)' 'recheck-date: 2099-01-01 08:00 +0000' 'handler-routine: magic-team.epic-build.routine.md'
rigItem pending task-20260101T0014Z-due 'type: task' 'approved-by: human-owner (x, 2026-01-01T00:00:00Z)' 'condition: unmet: the rig waits' 'recheck-date: 2000-01-01 08:00 +0000' 'handler-routine: magic-team.epic-build.routine.md'
rigItem pending task-20260101T0015Z-case 'type: task' 'approved-by: human-owner (x, 2026-01-01T00:00:00Z)' 'condition: Met: the rig answered' 'recheck-date: 2099-01-01 08:00 +0000' 'handler-routine: magic-team.epic-build.routine.md'
rigItem pending task-20260101T0016Z-spaces 'type: task' 'approved-by: human-owner (x, 2026-01-01T00:00:00Z)' 'condition:    none: the rig waits for nothing' 'recheck-date: 2099-01-01 08:00 +0000' 'handler-routine: magic-team.epic-build.routine.md'
rigItem pending task-20260101T0017Z-metrics 'type: task' 'approved-by: human-owner (x, 2026-01-01T00:00:00Z)' 'condition: metrics are read again' 'recheck-date: 2099-01-01 08:00 +0000' 'handler-routine: magic-team.epic-build.routine.md'
rigItem pending task-20260101T0018Z-unreadable 'type: task' 'approved-by: human-owner (x, 2026-01-01T00:00:00Z)' 'condition: unmet: the rig waits' 'recheck-date: someday soon' 'handler-routine: magic-team.epic-build.routine.md'
rigItem pending task-20260101T0003Z-never-run 'type: task' 'approved-by: human-owner (x, 2026-01-01T00:00:00Z)'
rigItem pending task-20260101T0004Z-built 'type: task' 'approved-by: human-owner (x, 2026-01-01T00:00:00Z)' 'handler-routine: magic-team.epic-build.routine.md'
rigItem pending task-20260101T0005Z-ran 'type: task' 'approved-by: human-owner (x, 2026-01-01T00:00:00Z)'
rigRecord aaaaaaaa-0000-0000-0000-000000000005 spawn-succeeded "$( date '+%Y-%m-%d %H:%M' ) +0200" 'Board item task-20260101T0005Z-ran.md, approved'
## Dispatches, named for today: one accepted with a stage and no landing, one accepted with its landing recorded. And one named for
## a day long past, its file just written as a store sync leaves it: its own day is not today, so it is not named.
rigDispNow="$( date -u +%Y%m%dT%H%MZ )"
rigItem processed "dispatch-${rigDispNow}-spawn-proxy-1-bbbbbbbb" 'type: dispatch' 'verdict: accepted'
rigRecord bbbbbbbb-0000-0000-0000-000000000006 spawn-succeeded "$( date '+%Y-%m-%d %H:%M' ) +0200" 'a build'
mkdir -p "$rigSpawned/bbbbbbbb-0000-0000-0000-000000000006/output/magic-developer/stage"
rigItem processed "dispatch-${rigDispNow}-spawn-proxy-1-cccccccc" 'type: dispatch' 'verdict: accepted'
printf -- '- 2026-01-01T00:00Z magic-coordinator resolved: Landed by the root.\n' >> "$rigItems/processed/dispatch-${rigDispNow}-spawn-proxy-1-cccccccc.md"
rigRecord cccccccc-0000-0000-0000-000000000007 spawn-succeeded "$( date '+%Y-%m-%d %H:%M' ) +0200" 'a build'
mkdir -p "$rigSpawned/cccccccc-0000-0000-0000-000000000007/output/magic-developer/stage"
rigItem processed dispatch-20260101T0008Z-spawn-proxy-1-f8f8f8f8 'type: dispatch' 'verdict: accepted'
rigRecord f8f8f8f8-0000-0000-0000-000000000018 spawn-succeeded "$( date '+%Y-%m-%d %H:%M' ) +0200" 'an old build'
mkdir -p "$rigSpawned/f8f8f8f8-0000-0000-0000-000000000018/output/magic-developer/stage"
## Records: one still started two days on, one started now.
rigRecord dddddddd-0000-0000-0000-000000000008 spawn-started "$( date -v-2d '+%Y-%m-%d %H:%M' 2> /dev/null || date -d '-2 days' '+%Y-%m-%d %H:%M' ) +0200" 'old duty'
rigRecord eeeeeeee-0000-0000-0000-000000000009 spawn-started "$( date '+%Y-%m-%d %H:%M' ) +0200" 'new run'

. "$rigHere/sh-lib/supervise/AgentsTools.SuperviseBoard.include"
. "$rigHere/sh-lib/vault/AgentsTools.VaultPlace.include"
## The injected owners: the store root and the two walkers answer from the fixture folders.
AgentsToolsTeamDataRootOf(){ printf '%s\n' "$rigTmp" ; }
AgentsToolsVaultFolderInto(){ printf -v "$1" '%s' "$rigEpics" ; }
AgentsToolsBoardItemsInto(){ ## array variable, name prefix, state...
	local itemsVar="$1" itemsPrefix="${2:-}" itemsState itemsOne ; shift 2
	eval "$itemsVar=()" ; [ $# -gt 0 ] || set -- pending running processed
	for itemsState in "$@" ; do for itemsOne in "$rigItems/$itemsState/$itemsPrefix"*.md ; do [ -f "$itemsOne" ] && eval "$itemsVar+=( \"\$itemsOne\" )" ; done ; done
	return 0
}
AgentsToolsBoardStateFoldersInto(){ ## array variable, state...
	local foldersVar="$1" foldersState ; shift
	eval "$foldersVar=()" ; for foldersState in "$@" ; do eval "$foldersVar+=( \"\$rigItems/\$foldersState\" )" ; done
	return 0
}
rigOut="$( MMDAPP="$rigWs" AgentsToolsSuperviseBoard "$rigWs" 2> /dev/null )"
rigHas(){ printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F -- "$1" ; }
echo "-- epic --"
rigAssert "a still epic is marked still" "$( rigHas 'epic ws 20260101T0000Z-still edited=' ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep 'still edited=' | LC_ALL=C grep -c ' still$' )" "1:1"
rigAssert "a moving epic is not" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '20260101T0000Z-moving' | LC_ALL=C grep -c ' still$' )" "0"
echo "-- pending-skipped --"
rigAssert "a recheck-date not due beside an unmet condition is named" "$( rigHas 'pending-skipped ws task-20260101T0002Z-recheck recheck=2099-01-01_08:00_+0000' )" "1"
rigAssert "one beside a met condition is not: the start pass starts it" "$( rigHas 'task-20260101T0011Z-met' )" "0"
rigAssert "one beside a condition that reads none is not" "$( rigHas 'task-20260101T0012Z-none' )" "0"
rigAssert "one beside no condition is not" "$( rigHas 'task-20260101T0013Z-bare' )" "0"
rigAssert "a due date beside an unmet condition is not" "$( rigHas 'task-20260101T0014Z-due' )" "0"
rigAssert "Met: in another case is not" "$( rigHas 'task-20260101T0015Z-case' )" "0"
rigAssert "none behind leading spaces is not" "$( rigHas 'task-20260101T0016Z-spaces' )" "0"
rigAssert "a metrics prefix is unmet, and named" "$( rigHas 'pending-skipped ws task-20260101T0017Z-metrics recheck=2099-01-01_08:00_+0000' )" "1"
rigAssert "an unreadable recheck-date is reported as one" "$( rigHas 'recheck-unreadable ws task-20260101T0018Z-unreadable someday_soon' )" "1"
rigAssert "and it is not named as skipped: it holds nothing" "$( rigHas 'pending-skipped ws task-20260101T0018Z-unreadable' )" "0"
rigAssert "a verify on a task never run is named" "$( rigHas 'pending-skipped ws task-20260101T0003Z-never-run verify-before-build' )" "1"
rigAssert "a task with a build routine is not" "$( rigHas 'task-20260101T0004Z-built' )" "0"
rigAssert "a task a run names is not" "$( rigHas 'task-20260101T0005Z-ran' )" "0"
echo "-- accepted-unlanded --"
rigAssert "an accepted dispatch with a stage and no landing is named" "$( rigHas "accepted-unlanded ws dispatch-${rigDispNow}-spawn-proxy-1-bbbbbbbb" )" "1"
rigAssert "one named for a day long past, its file freshly written, is not" "$( rigHas 'f8f8f8f8' )" "0"
rigAssert "one whose landing is recorded is not" "$( rigHas 'cccccccc' )" "0"
echo "-- running-idle --"
rigAssert "a running task no live run names is named" "$( rigHas 'running-idle ws task-20260101T0001Z-on-moving' )" "1"
rigAssert "one a live run names is not" "$( rigHas 'running-idle ws task-20260101T0010Z-live-run' )" "0"
rigAssert "one a running dispatch tracks, its run live, is not" "$( rigHas 'running-idle ws task-20260101T0014Z-tracked' )" "0"
rigAssert "control: one a running dispatch tracks, its run ended, is named" "$( rigHas 'running-idle ws task-20260101T0015Z-tracked-ended' )" "1"
rigAssert "one whose owner holds a live duty run is not" "$( rigHas 'running-idle ws task-20260101T0016Z-duty-owned' )" "0"
rigAssert "control: one whose owner holds no live duty is named" "$( rigHas 'running-idle ws task-20260101T0017Z-duty-other' )" "1"
echo "-- leftover --"
rigAssert "a record still started two days on is named" "$( rigHas 'leftover ws dddddddd-0000-0000-0000-000000000008 magic-developer' )" "1"
rigAssert "one started now is not" "$( rigHas 'eeeeeeee' )" "0"
echo
[ "$rigFail" -eq 0 ] || { echo "⛔ SUPERVISE BOARD CHECK FAILED: $rigFail of $(( rigPass + rigFail ))" >&2 ; exit 1 ; }
echo "SUPERVISE_BOARD: OK ($rigPass assertions, offline, rig tree only)"
