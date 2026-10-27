#!/usr/bin/env bash
## Behavioural check that NOTHING STARTS THE ADVANCE ROUTINE BY ITSELF (F7.12, MAGIC.md "Each iteration"): the heartbeat is retired and the advance rules
## stand in the coordinator's work duty, which includes them; `magic-coordinator.advance.routine` has `runs-at: none` and a console starts it by hand. The check
## was once the check of an advance pass the loop started whenever something was new; it now holds that the loop starts none in any of those situations, so
## a loop that starts the pass again fails it. The real loop (--one), the real spawner and the real advance routine run in the schedule rig of
## AgentsScheduleLoopCheck: its console ends at once, its clock is its own. Held, each as the pass count and the line count of one iteration, both 0:
##   1. nothing new; 2. something new (a board item of an active state, an item in magic-coordinator's incoming/, a recheck-date between the end of the last
##   pass and now); 3. the standing notes and the spawner's own tracking items; 4. a pass that runs, and a holder that died; 5. no lock note; 6. inside and
##   outside the duty hours, and with the wait after the last pass at 5, 20 and 0 minutes. A control: the routine says `runs-at: none`.
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
rigAssert "an item of a board state written after the last pass ended: still no pass, no line" "$( rigRun n2 )" "0:0"
rm -f "$rigData/board/pending/task-20261019T0103Z-rig-new.md"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" "$rigEnd"
printf -- '---\ntype: note\nfrom: keeper-rig-01\nowner: magic-coordinator\n---\n\nrig\n' > "$rigInbox/note-20261019T0200Z-rig-for-coordinator.md" ; rigTouch $(( rigEnd + 60 )) "$rigInbox/note-20261019T0200Z-rig-for-coordinator.md"
rigAssert "an item written into magic-coordinator's incoming/ after it: still no pass, nothing starts the advance routine by itself" "$( rigRun n3 )" "0:0"
rm -f "$rigInbox/note-20261019T0200Z-rig-for-coordinator.md"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" "$rigEnd"
rigBoardItem backlog task-20261019T0104Z-rig-due.md $(( rigEnd - 600 )) "2026-10-19 12:30 +0300"
rigAssert "a recheck-date between the end of the last pass and now: still no pass, nothing starts the advance routine by itself" "$( rigRun n4 )" "0:0"
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
rigAssert "a holder that died (recheck-date passed): still no pass" "$( rigRun n7 )" "0:0"

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
rigAssert "with the setting at 5 minutes: still no pass, nothing starts the advance routine by itself" "$( rigRun n12 )" "0:0"
printf 'MDAT_SCHEDULE_ADVANCE_MINUTES=20\n' >> "$rigSettings"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" $(( rigNow - 600 ))
rigAssert "with it at 20 minutes: none" "$( rigRun n13 )" "0:0"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" $(( rigNow - 1500 ))
rigAssert "...and still none once 25 minutes have gone" "$( rigRun n14 )" "0:0"
printf 'MDAT_SCHEDULE_ADVANCE_MINUTES=0\n' >> "$rigSettings"
rigNoteSet advance-finished "2026-10-19 14:00 +0300" $(( rigNow - 150 ))
rigAssert "at 0, no wait: still no pass" "$( rigRun n15 )" "0:0"

echo "-- 7. control: the same loop does start a routine that has a time --"
rigRun n16 > /dev/null
rigAssert "the autorun routine of the rig is started by the same iteration" "$( rigRecordsOf keeper-rig-01.auto.routine.md )" "1"
rigAssert "the advance routine says runs-at: none" "$( LC_ALL=C grep -c -x 'runs-at: none' "$rigPackage/skillset/magic-team/magic-coordinator/magic-coordinator.advance.routine.md" 2> /dev/null || :)" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ADVANCE SCHEDULE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ADVANCE_SCHEDULE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
