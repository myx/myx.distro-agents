#!/usr/bin/env bash
## Behavioural check on the advance pass as a session of its own (F7.12, the heartbeat retired: it ran advance inline at every iteration and spawned an agent each
## time, whether or not anything waited). The schedule's loop (AgentsToolsScheduleAdvance, sh-lib/session/AgentsTools.DispatcherLoop.include) starts it through the
## spawner when something is new for it, found by script. The real loop (--one), the real spawner and the real advance routine run in the schedule rig of
## AgentsScheduleLoopCheck: its console ends at once, its clock is its own. Held:
##   1. NOTHING NEW: nothing is written since the last pass ended (the modification time of the advance lock note, which the close of a pass writes), and no
##      recheck-date fell due since: no start, no spawn record, no line.
##   2. SOMETHING NEW: an item of the board's active states, or of magic-coordinator's incoming/, written after the last pass ended starts one pass, with one line;
##      a recheck-date between the end of the last pass and now does too; one before it, or ahead, does not.
##   3. NOT FROM THE STANDING NOTES: a write of a state and lock note in incoming/ (the routines' own) starts nothing.
##   4. NOT WHILE ONE RUNS: a note that reads advance-running with its recheck-date ahead starts nothing, newer items or not; one whose recheck-date has passed (a
##      holder that died) does not stop the next pass.
##   5. NOT WHERE THE LOOP IS NOT SET UP: with no advance lock note, none is started.
##   6. BOUNDED: only while the schedule opens the coordinator's duty (worktime, emergency, overtime), and no sooner than MDAT_SCHEDULE_ADVANCE_MINUTES (30 when not
##      set, 0 for no wait) after the last pass ended; what is new waits.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "dispatcher not found"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAdvanceScheduleCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
. "$rigPackage/sh-test/check-fixtures/rig-schedule-loop.include.sh" || rigRefuse "the schedule rig fixture is missing from the package"
rigScheduleSetup 1
## Monday 2026-10-19 in Etc/GMT-3: 13:00 now; the last pass ended at 12:00.
rigNow=1792404000 ; rigEnd=$(( rigNow - 3600 ))
rigAt "$rigNow"
## The real advance routine, but for its scan (a check of the loop does not need it) and its executors' cli: the lock note is the coordinator's standing one.
LC_ALL=C sed -e 's/^input-scan-def: .*$/input-scan-def: none/' "$rigPackage/skillset/magic-team/magic-coordinator/magic-coordinator.advance.routine.md" > "$rigSkills/magic-coordinator/magic-coordinator.advance.routine.md" \
	|| rigRefuse "the advance routine is not in the package skillset"
rigInbox="$rigData/inboxes/magic-coordinator/incoming"
rigAdvanceNote="$rigInbox/note-20260809T154715Z-advance-state-and-lock.md"
rigTouch(){ ## epoch, files... -- the modification time of files, as the rig's clock has it
	local touchEpoch="$1" ; shift
	python3 -I -B -c 'import os, sys; e = int(sys.argv[1]); [os.utime(p, (e, e)) for p in sys.argv[2:]]' "$touchEpoch" "$@"
}
rigNoteSet(){ ## state, recheck-date, mtime epoch
	printf -- '---\ntype: note\nfrom: magic-coordinator\nowner: magic-coordinator\nstate: %s\nsession-id: rig-last\nrecheck-date: %s\n---\n\nThe state of the advance routine.\n' "$1" "$2" > "$rigAdvanceNote"
	rigTouch "$3" "$rigAdvanceNote"
}
rigBoardItem(){ ## state, name, mtime epoch, recheck-date (may be empty)
	mkdir -p "$rigData/board/$1"
	printf -- '---\ntype: task\nowner: keeper-rig-01\n%s---\n\n# rig\n' "${4:+recheck-date: $4$'\n'}" > "$rigData/board/$1/$2"
	rigTouch "$3" "$rigData/board/$1/$2"
}
rigRun(){ ## name -- one iteration of the loop; how many advance passes it started
	rm -rf "$rigSp"/* 2> /dev/null
	rigOneRun "$1" ; rigWaitStarts
	printf '%s:%s' "$( rigRecordsOf magic-coordinator.advance.routine.md )" "$( rigSaid "$1" 'advance: started a pass' )"
}
## Whatever the autorun and the work duty do in the iteration is theirs: the console log is not asked.

echo "-- 1. nothing new --"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" "$rigEnd"
rigBoardItem backlog task-20261019T0100Z-rig-old.md $(( rigEnd - 600 ))
rigBoardItem blocked task-20261019T0101Z-rig-recheck-before.md $(( rigEnd - 600 )) "2026-10-19 11:30 +0300"
rigBoardItem parked task-20261019T0102Z-rig-recheck-ahead.md $(( rigEnd - 600 )) "2026-10-19 13:30 +0300"
rigTouch $(( rigEnd - 600 )) "$rigInbox"/*.md
rigTouch "$rigEnd" "$rigAdvanceNote"
rigAssert "items older than the last pass, and rechecks before it or ahead: no pass, no line" "$( rigRun n1 )" "0:0"

echo "-- 2. something new --"
rigBoardItem pending task-20261019T0103Z-rig-new.md $(( rigEnd + 60 ))
rigAssert "an item of a board state written after the last pass ended: one pass, one line" "$( rigRun n2 )" "1:1"
rm -f "$rigData/board/pending/task-20261019T0103Z-rig-new.md"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" "$rigEnd"
printf -- '---\ntype: note\nfrom: keeper-rig-01\nowner: magic-coordinator\n---\n\nrig\n' > "$rigInbox/note-20261019T0200Z-rig-for-coordinator.md" ; rigTouch $(( rigEnd + 60 )) "$rigInbox/note-20261019T0200Z-rig-for-coordinator.md"
rigAssert "an item written into magic-coordinator's incoming/ after it: a pass" "$( rigRun n3 )" "1:1"
rm -f "$rigInbox/note-20261019T0200Z-rig-for-coordinator.md"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" "$rigEnd"
rigBoardItem backlog task-20261019T0104Z-rig-due.md $(( rigEnd - 600 )) "2026-10-19 12:30 +0300"
rigAssert "a recheck-date between the end of the last pass and now: a pass" "$( rigRun n4 )" "1:1"
rm -f "$rigData/board/backlog/task-20261019T0104Z-rig-due.md"

echo "-- 3. not from the standing notes --"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" "$rigEnd"
printf -- '---\ntype: note\nfrom: magic-coordinator\nowner: magic-coordinator\nstate: grooming-finished\n---\n\nrig\n' > "$rigInbox/note-20260809T154332Z-grooming-state-and-lock.md"
rigTouch $(( rigEnd + 60 )) "$rigInbox/note-20260809T154332Z-grooming-state-and-lock.md"
rigTouch "$rigEnd" "$rigAdvanceNote"
rigAssert "the routines' own state and lock notes written after the pass: no pass" "$( rigRun n5 )" "0:0"

rigNoteSet advance-finished "2026-10-19 14:00 +0300" "$rigEnd"
rigBoardItem running dispatch-20261019T1230Z-spawn-proxy-1-abcd1234.md $(( rigEnd + 60 ))
rigBoardItem review dispatch-20261019T1231Z-spawn-proxy-2-abcd1235.md $(( rigEnd + 60 ))
rigAssert "the spawner's own tracking items (dispatch-*) written after the pass: no pass" "$( rigRun n5b )" "0:0"
rm -f "$rigData/board/running"/dispatch-*.md "$rigData/board/review"/dispatch-*.md

echo "-- 4. not while one runs --"
rigBoardItem pending task-20261019T0105Z-rig-new2.md $(( rigEnd + 60 ))
rigNoteSet advance-running "2026-10-19 14:00 +0300" "$rigEnd"
rigAssert "a pass that runs (recheck-date ahead): none, newer items or not" "$( rigRun n6 )" "0:0"
rigNoteSet advance-running "2026-10-19 11:00 +0300" "$rigEnd"
rigAssert "a holder that died (recheck-date passed): the next pass is started" "$( rigRun n7 )" "1:1"

echo "-- 5. no lock note --"
rm -f "$rigAdvanceNote"
rigAssert "a workspace without the advance lock note starts none" "$( rigRun n8 )" "0:0"

echo "-- 6. bounded: the duty hours, and the wait after the last pass --"
rigSettings="$rigWs/.local/.agents/magic-team.agent.env"
rigBoardItem pending task-20261019T0106Z-rig-busy.md $(( rigNow - 120 ))
rigNoteSet advance-finished "2026-10-19 14:00 +0300" "$rigEnd"
rigAt 1792422000
rigAssert "something new, the last pass an hour ago, but outside the duty hours (Monday 18:00): none" "$( rigRun n9 )" "0:0"
rigAt 1792836000
rigNoteSet advance-finished "2026-10-19 14:00 +0300" $(( 1792836000 - 3600 ))
rigBoardItem pending task-20261019T0107Z-rig-busy2.md 1792835400
rigAssert "...nor on a Saturday" "$( rigRun n10 )" "0:0"
rm -f "$rigData/board/pending/task-20261019T0107Z-rig-busy2.md"
rigAt "$rigNow"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" $(( rigNow - 600 ))
rigAssert "the last pass ended 10 minutes ago, the wait 30 by default: none, though something is new" "$( rigRun n11 )" "0:0"
printf 'MDAT_SCHEDULE_ADVANCE_MINUTES=5\n' >> "$rigSettings"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" $(( rigNow - 600 ))
rigAssert "with the setting at 5 minutes: a pass" "$( rigRun n12 )" "1:1"
printf 'MDAT_SCHEDULE_ADVANCE_MINUTES=20\n' >> "$rigSettings"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" $(( rigNow - 600 ))
rigAssert "with it at 20 minutes: none" "$( rigRun n13 )" "0:0"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" $(( rigNow - 1500 ))
rigAssert "...and a pass once 25 minutes have gone" "$( rigRun n14 )" "1:1"
printf 'MDAT_SCHEDULE_ADVANCE_MINUTES=0\n' >> "$rigSettings"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" $(( rigNow - 150 ))
rigAssert "at 0, no wait: a pass at once" "$( rigRun n15 )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ADVANCE SCHEDULE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ADVANCE_SCHEDULE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
