#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the spawn store's retention (AgentsSpawnedRetentionPrune, sh-lib/session/AgentsTools.SessionStore.Write.include).
## The rows it reads are the spawned-sessions registry's agents view, one row a spawn: the folder in its first column, the status in its sixth,
## the live word in its twelfth. Held here, on a rig store of its own:
##   1. a folder whose every row is settled and whose last write is past the cut-off goes
##   2. a folder a started row names stays, and so does one where a settled row and a started row both name it
##   3. a folder the registry never names stays
##   4. a folder written inside after its own time was set back stays: the last write is the newest one at or beneath it
##   5. a folder an undo hold protects stays, and one whose run names an open board item stays; the item of a closed one does not save it
##   6. the seven-column sessions view is not the row shape: fed it, the prune deletes nothing
## Offline: a temp store of this check alone, removed at its end; no store of this machine is read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigHere/session" ] || rigRefuse "the session includes are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnedRetentionPruneCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigStore="$rigTmp/ws"
rigBoard="$rigTmp/data"
mkdir -p "$rigStore/.local/agents/spawned" "$rigStore/.local/agents/sessions" "$rigBoard/board/running" "$rigBoard/board/processed" \
	|| rigRefuse "the probe store could not be made"

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## One row of the spawned-sessions agents view: the folder, then the session, the parent, the host, the owner, the status, the exit code,
## the spawn id, the log thread, the session thread, the workspace, the live word and the state -- thirteen words, as the render prints them.
rigRow(){ ## folder, status, live, state
	printf '%s %s none macmyx14 magic-developer %s 0 %s - - ws-rig %s %s\n' "$1" "$1" "$2" "$1" "$3" "$4"
}
## A spawn record of a folder, with its status and its optional `spawns:` link.
rigRecord(){ ## folder, status, item (empty for none)
	mkdir -p "$rigStore/.local/agents/spawned/$1" || rigRefuse "a folder of the probe store could not be made"
	{
		printf -- '---\n'
		printf 'type: spawn\n'
		printf 'status: %s\n' "$2"
		printf 'session-id: %s\n' "$1"
		[ -z "${3:-}" ] || printf 'spawns: %s\n' "$3"
		printf -- '---\n\n# a run of the check\n'
	} > "$rigStore/.local/agents/spawned/$1/$1.spawn.md"
}
## A board item of the given state, resolved or not.
rigItem(){ ## state, name, resolved (yes for a closed one)
	mkdir -p "$rigBoard/board/$1" || rigRefuse "a board state of the probe store could not be made"
	{
		printf -- '---\n'
		printf 'type: task\n'
		printf 'from: magic-coordinator\n'
		printf 'owner: magic-coordinator\n'
		printf 'status: %s\n' "$1"
		[ "${3:-}" = yes ] && printf 'resolved-at: 2026-11-20 10:00 +0200\n'
		printf -- '---\n\n# a task of the check\n'
	} > "$rigBoard/board/$1/$2"
}
## A folder old by its own time and by everything in it, its spawn record included: the last write is the newest one beneath it, so a
## record written now makes any folder fresh. The walk is deepest first, so setting a child does not move its folder's own time after it.
rigAged(){ ## folder, when
	mkdir -p "$rigStore/.local/agents/spawned/$1/output" || rigRefuse "a folder of the probe store could not be made"
	printf 'a deliverable of the run\n' > "$rigStore/.local/agents/spawned/$1/output/report.txt"
	find "$rigStore/.local/agents/spawned/$1" -depth -exec touch -t "$2" {} + || rigRefuse "a folder of the probe store could not be aged"
}
## The prune, over the rows given on stdin, against the rig store and the rig board.
rigPrune(){ ## days, rows
	( cd "$rigTmp" && MMDAPP="$rigStore" MDAT_DATA_ROOT="$rigBoard" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash -c '. "$1" ; . "$2" ; AgentsSpawnedRetentionPrune "$3" 20' rig \
			"$rigHere/session/AgentsTools.SessionStore.Write.include" \
			"$rigHere/session/AgentsTools.SessionStore.Paths.include" "$1" <<< "$2" 2> /dev/null )
}
rigHere2(){ ## folder
	[ -e "$rigStore/.local/agents/spawned/$1" ] && printf here || printf gone
}

## The store: seven folders, each a record of its own.
rigRecord settled-old spawn-succeeded ; rigAged settled-old 202001010000
rigRecord tooling-closed spawn-ended-without-close ; rigAged tooling-closed 202001010000
rigRecord running-old spawn-started ; rigAged running-old 202001010000
rigRecord mixed-rows spawn-succeeded ; rigAged mixed-rows 202001010000
rigRecord unnamed-old spawn-succeeded ; rigAged unnamed-old 202001010000
rigRecord written-inside spawn-succeeded ; rigAged written-inside 202001010000
rigRecord undo-held spawn-succeeded ; rigAged undo-held 202001010000
rigRecord open-item spawn-succeeded ; rigAged open-item 202001010000
rigRecord closed-item spawn-succeeded ; rigAged closed-item 202001010000
## The last write of one is now, though everything in it says 2020.
printf 'work still being written\n' > "$rigStore/.local/agents/spawned/written-inside/output/late.txt"
## A promise of undo holds one, naming a record whose state is open.
mkdir -p "$rigStore/.local/agents/sessions/undo-session/undo/undo-record"
printf -- '---\nstate: open\n---\n' > "$rigStore/.local/agents/sessions/undo-session/undo/undo-record/record"
printf 'undo-session/undo-record\n' > "$rigStore/.local/agents/spawned/undo-held/undo.hold"
## Two runs name a board item: one that stands open, and one that closed.
rigRecord open-item spawn-succeeded "task-20260101T0000Z-open.md"
rigItem running task-20260101T0000Z-open.md
rigRecord closed-item spawn-succeeded "task-20260101T0000Z-closed.md"
rigItem processed task-20260101T0000Z-closed.md yes
## Written to name their items after they were aged, so they are aged once more.
rigAged open-item 202001010000
rigAged closed-item 202001010000

rigRows="$( printf '%s\n' \
	"$( rigRow settled-old spawn-succeeded gone finished )" \
	"$( rigRow tooling-closed spawn-ended-without-close gone finished )" \
	"$( rigRow running-old spawn-started running busy )" \
	"$( rigRow mixed-rows spawn-succeeded gone finished )" \
	"$( rigRow mixed-rows spawn-started running busy )" \
	"$( rigRow written-inside spawn-succeeded gone finished )" \
	"$( rigRow undo-held spawn-succeeded gone finished )" \
	"$( rigRow open-item spawn-succeeded gone finished )" \
	"$( rigRow closed-item spawn-succeeded gone finished )" )"

echo "-- 1. a settled folder past the cut-off goes --"
rigSaid="$( rigPrune 14 "$rigRows" )" || rigSaid=""
rigAssert "the settled old folder is gone" "$( rigHere2 settled-old )" "gone"
rigAssert "the folder the tooling closed itself is gone" "$( rigHere2 tooling-closed )" "gone"
rigAssert "it printed a count" "$( printf '%s' "$rigSaid" | LC_ALL=C awk '/^[0-9]+$/ { print "yes" ; exit ; }' )" "yes"

echo "-- 2. a row still started keeps its folder --"
rigAssert "a folder a started row names stays" "$( rigHere2 running-old )" "here"
rigAssert "a folder one settled row and one started row name stays" "$( rigHere2 mixed-rows )" "here"

echo "-- 3. a folder the registry never names stays --"
rigAssert "a folder of records with no row stays" "$( rigHere2 unnamed-old )" "here"

echo "-- 4. the last write is the newest one at or beneath the folder --"
rigAssert "a folder written inside, its own time set back, stays" "$( rigHere2 written-inside )" "here"

echo "-- 5. a promise of undo, and an open item the run names, keep the folder --"
rigAssert "the folder an undo hold protects stays" "$( rigHere2 undo-held )" "here"
rigAssert "the folder of a run naming an open board item stays" "$( rigHere2 open-item )" "here"
rigAssert "the folder of a run naming a closed board item goes" "$( rigHere2 closed-item )" "gone"

echo "-- 6. the pass feeds the prune the registry rows, not a filtered view --"
rigCaller="$( for rigFile in "$rigPackage"/sh-lib/*/AgentsTools.BoardHousekeeping.include ; do [ -f "$rigFile" ] || continue ; printf '%s\n' "$rigFile" ; done )"
rigAssert "the housekeeping include is found, and one of it" "$( printf '%s\n' "$rigCaller" | LC_ALL=C grep -c . )" "1"
rigFed="$( LC_ALL=C awk '/AgentsToolsRegistryRenderSpawnedSessionsKept agents/ { sub( /^[ \t]*/, "" ) ; print ; exit ; }' ${rigCaller:+"$rigCaller"} 2> /dev/null )"
rigAssert "its render call names the live view in the fifth argument, leaving the state filter empty" "$rigFed" 'measureText="$( AgentsToolsRegistryRenderSpawnedSessionsKept agents "" "" "" live )"'
rigAssert "the prune is fed that measured text, and its class's days from the one resolver" "$( LC_ALL=C grep -c 'AgentsSpawnedRetentionPrune "$( AgentsToolsStoreRetentionDays run )" 20' ${rigCaller:+"$rigCaller"} 2> /dev/null )" "1"

echo "-- 7. the schedule declares a daily caller, and it invokes both prunes --"
rigSchedule="$rigPackage/sh-lib/schedule/AgentsTools.ScheduleThread.include"
rigAssert "the schedule thread's pass is found" "$( [ -f "$rigSchedule" ] && printf found )" "found"
rigAssert "the pass calls the daily caller" "$( LC_ALL=C grep -c '^[[:space:]]*AgentsToolsSpawnedRetentionRunDetached$' "$rigSchedule" 2> /dev/null )" "1"
rigCallerBody="$( LC_ALL=C awk '/^AgentsToolsSpawnedRetentionRun\(\)[[:space:]]*\{/ { inside = 1 } inside { print } inside && /^\}/ { exit }' "$rigPackage/sh-lib/session/AgentsTools.SessionStore.Write.include" 2> /dev/null )"
rigAssert "the caller runs the session folders' prune" "$( printf '%s\n' "$rigCallerBody" | LC_ALL=C grep -c 'AgentsToolsSessionStorePrune' )" "1"
rigAssert "the caller runs the spawn folders' prune, over the registry rows" "$( printf '%s\n' "$rigCallerBody" | LC_ALL=C grep -c 'AgentsSpawnedRetentionPrune' )" "1"
rigAssert "the caller reads the unfiltered agents view" "$( printf '%s\n' "$rigCallerBody" | LC_ALL=C grep -c 'AgentsToolsRegistryRenderSpawnedSessionsKept agents "" "" "" live' )" "1"
## The cut-off is resolved in one place, and the caller keeps none of its own.
rigAssert "the caller reads no retention setting of its own" "$( printf '%s\n' "$rigCallerBody" | LC_ALL=C grep -cE 'MDAT_CLEANUP_[A-Z_]*DAYS' )" "0"
rigAssert "the caller asks the one resolver for each class's days" "$( printf '%s\n' "$rigCallerBody" | LC_ALL=C grep -c 'AgentsToolsStoreRetentionDays' )" "2"

echo "-- 8. the seven-column sessions view is not the row shape --"
rigRecord sessions-view spawn-succeeded ; rigAged sessions-view 202001010000
rigSeven="$( printf '%s %s %s %s %s %s %s\n' sessions-view ws-rig macmyx14 magic-developer 1 - finished=1 )"
rigSaid="$( rigPrune 14 "$rigSeven" )" || rigSaid=""
rigAssert "fed seven-column rows, it deletes nothing and says nothing" "$rigSaid:$( rigHere2 sessions-view )" ":here"

echo "-- control: the same rows with no settled folder leave a clean store alone --"
rigSaid="$( rigPrune 14 "$( rigRow running-old spawn-started running busy )" )" || rigSaid=""
rigAssert "a store of one running folder is untouched, and nothing is printed" "$rigSaid:$( rigHere2 running-old )" ":here"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SPAWNED RETENTION PRUNE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	exit 1
fi
printf 'SPAWNED_RETENTION_PRUNE: OK (%d assertions, offline)\n' "$rigPass"
exit 0
