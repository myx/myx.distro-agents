#!/usr/bin/env bash
## Behavioural check on the release step of a session's control thread: it reads the record of the
## run it is about to end through the store, never through a path it builds from the tracking name
## and the run id. A record's file is named by the session that founded it, or by its own run, and
## the two differ, so a built path misses the record in silence: no release mark is written, and the
## run is never ended. Held, each its own session in this rig's workspace:
##   1. A RECORD NAMED BY ITS SESSION: the row's run has its record at the file the session names,
##      and the item it serves is processed, so the release mark is written. Red before the fix.
##   2. CONTROL, THE SAME SHAPE WITH AN ITEM THAT IS STILL OPEN: no mark, so a mark means the record
##      was reached and its item was settled, never that a tick simply ran.
##   3. THE BUILT PATH HOLDS ANOTHER RUN'S RECORD: a file stands at the built path and belongs to a
##      second run whose item is open. The row's own record is read, so the mark is written and it
##      names the row's run alone. Red before the fix.
##   4. CONTROL, A ROW WITH NO RECORD ANYWHERE: nothing is written, and the tick ends rc 0.
## Offline: the rig's workspace, board and spawn store are this rig's own temp tree. No socket. The
## closing time is held a million seconds past the read, so no arm signals any run.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigNeeded in "$rigPkg/sh-lib/session/AgentsTools.SessionControlRelease.include" "$rigPkg/sh-test/check-fixtures/rig-owner-writes.include.sh" \
	"$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" ; do
	[ -f "$rigNeeded" ] || rigRefuse "a file this check measures is not at the origin: $rigNeeded"
done
. "$rigPkg/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsControlReleaseRecordCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws"
rigHome="$rigTmp/home"
rigData="$rigTmp/data"
rigStores="$rigWs/.local/agents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigStores" "$rigHome" "$rigData/audit" \
	|| rigRefuse "the rig could not be made: $rigTmp"
rigBoardStates "$rigData" processed running || rigRefuse "the rig's board could not be made"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
printf 'SESSION_CONTROL_TICK_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
## One record, by the store's own writer: its folder, the name its file carries, the session that
## founded it, the run it records, and the item it serves.
rigRecord(){ ## folder, file stem, session, run, item
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: magic-developer\nstatus: spawn-started\nspawns: %s\nstarted-at: 2026-11-26 09:00 +0300\n---\n\n# Spawn session: %s\n' \
		"$3" "$4" "$rigHost" "$5" "$3" | rigOwnerStore AgentsSpawnRecordWrite "$2" "$1" \
		|| rigRefuse "the record of $4 could not be written"
}
## One board item, by the item writer every board write goes through.
rigItem(){ ## state, item, run it names
	printf -- '---\ntype: dispatch\nowner: magic-developer\nstatus: dispatch-%s\nspawn-id: %s\nsession-id: release-run\n---\n\n# Dispatch\n\n## Handback\n\n- owed\n' \
		"$1" "$3" | rigStoreItem "$rigData" board "$1" "$2" \
		|| rigRefuse "the board item $2 could not be written"
}
## One pass of the release step, exactly as a control thread makes it: the session's own control
## folder, its row, and the closing time held far off so nothing is signalled by any arm.
rigRelease(){ ## session, row
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" "MDLT_OPTION=--run-from-path $MDLT_ORIGIN" \
		bash -c '. "$1" ; . "$2" ; controlSession="$3" ; controlDir="$4" ; controlClosing=1000000 ; controlRows="$5" ; AgentsToolsSessionControlRelease' \
			rig "$rigPkg/sh-lib/session/AgentsTools.SessionControlRelease.include" \
			"$rigPkg/sh-lib/board/AgentsTools.BoardStates.include" "$1" "$rigStores/$1/control" "$2" ) 2>&1
}
## The release marks one session's control folder holds, one a line; `-` where it holds none.
rigMarks(){ ## session
	local marks
	marks="$( ls "$rigStores/$1/control" 2> /dev/null | LC_ALL=C grep '^release\.' | LC_ALL=C tr '\n' ' ' )" || :
	printf '%s' "${marks:-none}"
}
rigControl(){ ## session
	mkdir -p "$rigStores/$1/control" || rigRefuse "the control folder of $1 could not be made"
}
## The row a control thread reads, in its own fifteen words: tracking name, session, parent, host,
## owner, status, exit, run, agent log, thread, workspace, live, state, rest. The live word is the
## twelfth, where the measure re-emits it.
rigRow(){ ## tracking, session, run
	printf '%s %s - %s magic-developer spawn-started - %s - - %s running - -\n' "$1" "$2" "$rigHost" "$3" "$rigWs"
}

echo "-- 1. a record named by its session is reached, and its settled item releases the run --"
rigControl sess-one
rigRecord sess-one sess-one sess-one run-one dispatch-run-one.md
rigItem processed dispatch-run-one.md run-one
rigRelease sess-one "$( rigRow sess-one sess-one run-one )" > /dev/null
rigAssert "the release step marks the run whose record the session names" "$( rigMarks sess-one )" "release.run-one "

echo "-- 2. control: the same record shape, the item still open --"
rigControl sess-two
rigRecord sess-two sess-two sess-two run-two dispatch-run-two.md
rigItem running dispatch-run-two.md run-two
rigRelease sess-two "$( rigRow sess-two sess-two run-two )" > /dev/null
rigAssert "no mark is written while the item is open" "$( rigMarks sess-two )" "none"

echo "-- 3. the built path holds another run's record, and the row's own record is the one read --"
rigControl sess-four
rigRecord sess-four sess-four sess-four run-three dispatch-run-three.md
rigRecord sess-four run-three sess-four run-other dispatch-run-other.md
rigItem processed dispatch-run-three.md run-three
rigItem running dispatch-run-other.md run-other
rigRelease sess-four "$( rigRow sess-four sess-four run-three )" > /dev/null
rigAssert "the row's own record is read, so its run is marked" "$( rigMarks sess-four )" "release.run-three "

echo "-- 4. control: a row with no record anywhere writes nothing, and the tick ends clean --"
rigControl sess-five
rigFive="$( rigRelease sess-five "$( rigRow sess-five sess-five run-absent )" )" ; rigFiveRc=$?
rigAssert "no mark for a row with no record" "$( rigMarks sess-five )" "none"
rigAssert "and the tick ends rc 0" "$rigFiveRc" "0"
rigAssert "with no error line on its output" "$( printf '%s\n' "$rigFive" | LC_ALL=C grep -c 'ERROR' || : )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONTROL RELEASE RECORD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONTROL_RELEASE_RECORD: OK (%d assertions, offline)\n' "$rigPasses"
