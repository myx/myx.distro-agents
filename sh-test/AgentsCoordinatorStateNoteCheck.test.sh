#!/usr/bin/env bash
## Behavioural check on what the tooling does for the coordinator's state note and its neighbours, against temp stores only: the board's active-item
## list (capped, names only) and counts (AgentsToolsBoardActiveItems, AgentsToolsBoardCounts); --intern-op-state-note-upsert stamping
## last-iteration-date/-timestamp (a given value wins) and keeping last-test-email-sent; --magic-test-report-send (refused without a recipient, built
## and stamped once due, NOT_DUE inside the hour) through the real email path in build-only mode with a fake curl first on PATH;
## --magic-daily-lock-acquire's `first-today:` line and the grooming/daily closes' last-close-date stamp. Every call goes through one `env -i` whose
## child refuses to run outside this rig's mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCoordinatorStateNoteCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
rigInbox="$rigData/inboxes/magic-coordinator/incoming"
rigHbNote="$rigInbox/note-20260809T155000Z-heartbeat-state-and-lock.md"
rigGroomNote="$rigInbox/note-20260809T154332Z-grooming-state-and-lock.md"
rigDailyNote="$rigInbox/note-20260811T120000Z-daily-state-and-lock.md"
## audit/ is where the report's --text-group declaration is recorded.
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/home" "$rigTmp/bin" "$rigSkills/magic-coordinator" "$rigInbox" "$rigData/audit"
for rigState in backlog pending running review blocked parked ; do mkdir -p "$rigData/board/$rigState" ; done

## A fake curl whose only job is to prove it was never reached.
printf '#!/bin/sh\nprintf "curl invoked\\n" >> "%s/curl.log"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"

rigToday="$( date +%Y-%m-%d )"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigField(){ ## file, field
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { print substr($0, length(f) + 3) ; exit ; }' "$1"
}
rigLine(){ ## file, line prefix -- the first line starting with it, prefix stripped
	LC_ALL=C awk -v p="$2" 'index($0, p) == 1 { print substr($0, length(p) + 1) ; exit ; }' "$1"
}
rigOp(){ ## result file, op and arguments...
	local opOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" AGENTS_EMAIL_SEND_BUILD_ONLY=true \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/bin/curl" ] || exit 98
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}
rigBoardFn(){ ## function name -- one of the board readers of the state-note include, run in the rig
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		RIG_TMP="$rigTmp" RIG_FN="$1" \
		bash -c '
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			MDSC_CMD=rig ; set -- --rig-none ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicCoordinatorState.include" 2> /dev/null
			"$RIG_FN"
		'
}

echo "-- board counts and active items --"
for rigState in backlog pending running review blocked parked ; do
	printf -- '---\ntype: task\n---\n\nx\n' > "$rigData/board/$rigState/task-rig-$rigState.md"
done
rigAssert "one count line for each state, live"           "$( rigBoardFn AgentsToolsBoardCounts | tr '\n' ' ' )" "backlog: 1 pending: 1 running: 1 review: 1 blocked: 1 parked: 1 processed: 0 archived: 0 retained: 0 "
rigAssert "active and blocked items, by state, nothing else" "$( rigBoardFn AgentsToolsBoardActiveItems | tr '\n' ' ' )" "running/task-rig-running.md review/task-rig-review.md pending/task-rig-pending.md blocked/task-rig-blocked.md "
rigN=1
while [ "$rigN" -le 44 ] ; do printf -- '---\ntype: task\n---\n\nx\n' > "$rigData/board/running/task-rig-cap-$rigN.md" ; rigN=$(( rigN + 1 )) ; done
rigAssert "the list is capped at 40, the rest counted"    "$( rigBoardFn AgentsToolsBoardActiveItems | LC_ALL=C awk 'NF { n++ ; last = $0 ; } END { print n " " last ; }' )" "41 (+8 more)"
rm -f "$rigData/board/running"/task-rig-cap-*.md

echo "-- state note write: stamps --"
printf -- '---\ntype: note\nstate: heartbeat-running\nrecheck-date: 2001-01-01 00:00 +0000\nsession-id: rig\nlast-test-email-sent: 2001-01-01T00:00:00Z\n---\n\nold\n' > "$rigHbNote"
printf -- '---\ntoday-stage: grooming-dispatched\n---\n\nLast iteration: rig.\n' | rigOp "$rigTmp/u1" --intern-op-state-note-upsert magic-coordinator
rigAssert "the write succeeds"                            "$( cat "$rigTmp/u1.rc" )" 0
rigAssert "last-iteration-date is stamped today"          "$( rigField "$rigHbNote" last-iteration-date )" "$rigToday"
rigAssert "last-iteration-timestamp is stamped"           "$( rigField "$rigHbNote" last-iteration-timestamp | LC_ALL=C grep -c -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' )" 1
rigAssert "last-test-email-sent is kept"                  "$( rigField "$rigHbNote" last-test-email-sent )" "2001-01-01T00:00:00Z"
rigAssert "the caller's own field is written"             "$( rigField "$rigHbNote" today-stage )" grooming-dispatched
printf -- '---\nlast-iteration-date: 2026-01-02\nlast-iteration-timestamp: rig-given\n---\n\nLast iteration: rig.\n' | rigOp "$rigTmp/u2" --intern-op-state-note-upsert magic-coordinator
rigAssert "a given value wins, once"                      "$( rigField "$rigHbNote" last-iteration-date ) $( rigField "$rigHbNote" last-iteration-timestamp ) $( LC_ALL=C grep -c '^last-iteration-date: ' "$rigHbNote" )" "2026-01-02 rig-given 1"

echo "-- test report --"
rigOp "$rigTmp/r1" --magic-test-report-send magic-coordinator
rigAssert "refused with no recipient configured"          "$( cat "$rigTmp/r1.rc" ):$( LC_ALL=C grep -c 'EMAIL_USER is not set' "$rigTmp/r1" )" "1:1"
printf 'EMAIL_USER=owner@example.com\n' > "$rigTmp/ws/.local/.agents/human-owner.agent.env"
printf 'EMAIL_USER=rig@example.com\nEMAIL_APP_PASSWORD=rig-app-password\nEMAIL_SMTP_HOST=smtp.rig.invalid\nEMAIL_SMTP_PORT=587\n' > "$rigTmp/ws/.local/.agents/magic-coordinator.agent.env"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-contacts.include.sh" || exit 1
rigContactSeed "$rigData" magic-coordinator rig-owner - owner@example.com
rigOp "$rigTmp/r2" --magic-test-report-send magic-coordinator
rigAssert "sent once due"                                 "$( cat "$rigTmp/r2.rc" ):$( LC_ALL=C grep -c '^SENT:to=owner@example.com:' "$rigTmp/r2" )" "0:1"
rigAssert "addressed to the configured owner"             "$( LC_ALL=C grep -c -x 'To: owner@example.com' "$rigTmp/r2" )" 1
rigAssert "the body carries the counts and the items"     "$( LC_ALL=C grep -c -x -E -e '- running: 1' -e '- blocked/task-rig-blocked.md' "$rigTmp/r2" | tr -d ' ' )" 2
rigAssert "last-test-email-sent is stamped now"           "$( rigField "$rigHbNote" last-test-email-sent | cut -c1-10 )" "$( date -u +%Y-%m-%d )"
rigOp "$rigTmp/r3" --magic-test-report-send magic-coordinator
rigAssert "inside the hour it is not due, and sends nothing" "$( cat "$rigTmp/r3.rc" ):$( LC_ALL=C grep -c '^NOT_DUE:' "$rigTmp/r3" ):$( LC_ALL=C grep -c '^To: ' "$rigTmp/r3" )" "0:1:0"
rigAssert "curl was never reached"                        "$( [ -f "$rigTmp/curl.log" ] && echo reached || echo never )" never

echo "-- daily: first-today; grooming/daily closes stamp last-close-date --"
rigOp "$rigTmp/d1" --magic-daily-lock-acquire magic-coordinator rig
rigAssert "a first daily is first-today"                  "$( cat "$rigTmp/d1.rc" ):$( rigLine "$rigTmp/d1" 'first-today: ' )" "0:yes"
rigOp "$rigTmp/d2" --magic-daily-close-state-and-unlock magic-coordinator
rigAssert "the daily close stamps today"                  "$( rigField "$rigDailyNote" last-close-date )" "$rigToday"
rigOp "$rigTmp/d3" --magic-daily-lock-acquire magic-coordinator rig
rigAssert "the next daily today is not first-today"       "$( cat "$rigTmp/d3.rc" ):$( rigLine "$rigTmp/d3" 'first-today: ' )" "0:no"
rigOp "$rigTmp/d4" --magic-daily-lock-acquire magic-coordinator rig-other
rigAssert "a held daily lock still refuses, with no first-today line" "$( cat "$rigTmp/d4.rc" ):$( LC_ALL=C grep -c '^first-today: ' "$rigTmp/d4" )" "1:0"
rm -f "$rigGroomNote"
rigOp "$rigTmp/g1" --magic-grooming-lock-acquire magic-coordinator rig
rigOp "$rigTmp/g2" --magic-grooming-close-state-and-unlock magic-coordinator
rigAssert "the grooming close stamps today"               "$( rigField "$rigGroomNote" last-close-date )" "$rigToday"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COORDINATOR STATE NOTE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COORDINATOR_STATE_NOTE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
