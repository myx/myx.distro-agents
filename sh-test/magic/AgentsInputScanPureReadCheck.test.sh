#!/usr/bin/env bash
## Behavioural check on the scans as pure reads (F3.1 of the refactorings epic): the acting parts of a scan are
## lifted out of it -- closing dead spawns, moving a dispatch item from running to review, rewriting the review-by of
## an item whose reviewer session has ended, starting control threads, the heartbeat lock's recheck date. They run
## in the bundled routine they belong to, right after that routine takes its lock, by the tooling itself, and their
## output goes to the tooling log (the daemon line, file descriptor 4), never into the agent's input.
## Held, against a rig board and workspace with a dead spawn, its running dispatch item, a review item whose reviewer
## session has ended, and a live session with no control thread:
##   1. --magic-advance-input-scan acts on none of them: the dead spawn's record, the item's state, the review-by, the
##      sessions' control folders are as they were; nothing is posted and no housekeeping line is printed
##   2. it still reports them: the running item as a running/ row, the review item as a review/ row
##   3. --magic-advance-lock-acquire, the advance routine taking its lock, does the housekeeping: the dead spawn is
##      closed, its item moves to review, the review-by becomes magic-coordinator, the control thread is started
##   4. its housekeeping lines go to the tooling log, and none to its standard output
##   5. --magic-heartbeat-input-scan leaves its lock note as it was, the recheck-date among it
## Red before F3.1: the advance scan does the housekeeping itself, and its lock does none (1, 2 and 3 fail).
## Offline: a ps first on PATH lists the rig's own runs only; a Slack-shaped fake curl logs any post; every tree is
## this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A scan starts the control thread of a session of its rig that is not finished: what was started is ended before the tree is removed.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mktemp -d -t AgentsInputScanPureReadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
printf '#!/bin/sh\ncase " $* " in\n\t*" -A "*)\n\t\tcase "$*" in\n\t\t\t*pid=*) cat "${0%%/*}/../ps.list" 2> /dev/null ;;\n\t\t\t*) sed '"'"'s/^[^ ]* //'"'"' "${0%%/*}/../ps.list" 2> /dev/null ;;\n\t\tesac\n\t\texit 0\n\t;;\nesac\nexec "${0%%/*}/ps.real" "$@"\n' > "$rigTmp/bin/ps"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] || rigRefuse "the rig's own ps is not first on PATH, so this check would read the host's process list"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## ---------------------------------------------------------------- the rig
rigHost="$( hostname -s 2>/dev/null || echo unknown )"
rigW="$rigTmp/ws" rigD="$rigTmp/data" rigH="$rigTmp/home"
mkdir -p "$rigW/.local/.agents" "$rigW/.local/agents/spawned" "$rigW/.local/agents/members/magic-coordinator" "$rigD/inboxes/magic-coordinator" "$rigH" "$rigD/board/running" "$rigD/board/review" "$rigD/board/processed"
printf '# magic-coordinator\n' > "$rigW/.local/agents/members/magic-coordinator/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIG00002\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigW/.local/.agents/magic-team.agent.env"
rigStamp(){ ## hours ago -- a touch -t stamp, BSD or GNU date
	local stampEpoch=$(( $( date +%s ) - $1 * 3600 ))
	date -r "$stampEpoch" +%Y%m%d%H%M 2> /dev/null || date -d "@$stampEpoch" +%Y%m%d%H%M
}
rigSandbox(){ ## session id, status, extra header lines -- a sandbox with its session record, on this host
	mkdir -p "$rigW/.local/agents/spawned/$1/input" "$rigW/.local/agents/spawned/$1/output"
	printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: %s\nowner: rig-member\nstatus: %s\nspawns: dispatch-%s\n%s---\n' "$1" "$1" "$1" "$rigHost" "$2" "$1" "${3:-}" > "$rigW/.local/agents/spawned/$1/$1.md"
}
rigItem(){ ## board state, item filename, type, status, review-by or none, session and spawn id or none
	local itemReview="" itemSession=""
	[ "$5" = none ] || itemReview="review-by: $5"$'\n'
	[ "$6" = none ] || itemSession="session-id: $6"$'\n'"spawn-id: $6"$'\n'
	printf -- '---\ntype: %s\nowner: rig-member\nstatus: %s\n%s%s---\n\nrig item\n' "$3" "$4" "$itemReview" "$itemSession" > "$rigD/board/$1/$2"
}
## A dead spawn and its running item; a review item whose reviewer session has ended; a live session with no thread.
rigSandbox rig-ldead spawn-started ; rigItem running dispatch-rig-ldead.md dispatch dispatch-started none rig-ldead
find "$rigW/.local/agents/spawned/rig-ldead" -exec touch -t "$( rigStamp 48 )" {} +
rigSandbox rig-ended spawn-succeeded "exit-code: 0
armed: yes
"
rigItem review task-rig-rv-ended.md task dispatch-succeeded rig-ended none
rigSandbox rig-live spawn-started
printf '900001 rig-run --session-id rig-live\n' > "$rigTmp/ps.list"

rigRun(){ ## result file, DistroAgentsTools.fn.sh arguments... -- one op, fd 4 the tooling log of this rig: out, err, rc
	local runOut="$1" ; shift
	( cd "$rigW" && env -u MDAT_SKILLSET_ROOT HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigD" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" "$@" ) > "$runOut" 2> "$runOut.err" 4>> "$rigTmp/tooling.log"
	printf '%s' "$?" > "$runOut.rc"
}
rigSum(){ ## file -- its checksum, or gone
	[ -f "$1" ] && cksum < "$1" || printf gone
}
rigLoc(){ ## item filename -- which board/<state>/ holds it
	local locDir
	for locDir in "$rigD"/board/*/ ; do
		[ -f "$locDir$1" ] && { basename "$locDir" ; return 0 ; }
	done
	printf 'not-found'
}
rigHeader(){ ## file, header
	LC_ALL=C sed -n "s/^$2: //p" "$1" 2> /dev/null | head -1
}
rigControl(){ ## session id -- whether its control folder holds anything: started, or none
	[ -n "$( ls -A "$rigW/.local/agents/sessions/$1/control" 2> /dev/null )" ] && printf started || printf none
}
rigPosts(){ LC_ALL=C grep -c '^chat.postMessage ' "$rigTmp/calls" 2> /dev/null || : ; }
: > "$rigTmp/calls" ; : > "$rigTmp/bodies" ; : > "$rigTmp/tooling.log"

rigDeadBefore="$( rigSum "$rigW/.local/agents/spawned/rig-ldead/rig-ldead.md" )"
rigRun "$rigTmp/scan" --magic-advance-input-scan magic-coordinator
[ "$( cat "$rigTmp/scan.rc" )" = 0 ] || rigRefuse "the advance scan failed in the rig: $( tail -2 "$rigTmp/scan.err" | LC_ALL=C tr '\n' ' ' )"

echo "-- 1. the advance scan acts on nothing --"
rigAssert "the dead spawn's record is as it was"              "$( rigSum "$rigW/.local/agents/spawned/rig-ldead/rig-ldead.md" )" "$rigDeadBefore"
rigAssert "its item is still in running"                      "$( rigLoc dispatch-rig-ldead.md )" running
rigAssert "the ended reviewer's item keeps its review-by"     "$( rigHeader "$rigD/board/review/task-rig-rv-ended.md" review-by )" rig-ended
rigAssert "no control thread was started"                     "$( rigControl rig-live )" none
rigAssert "nothing was posted, and no housekeeping line printed or logged" "$( rigPosts ):$( cat "$rigTmp/scan" "$rigTmp/scan.err" "$rigTmp/tooling.log" | LC_ALL=C grep -c '^housekeeping: ' || : )" "0:0"

echo "-- 2. it still reports what it reads --"
rigAssert "the running item is a running/ row"                "$( LC_ALL=C grep -c -x -F '## running/dispatch-rig-ldead.md' "$rigTmp/scan" )" 1
rigAssert "the review item is a review/ row"                  "$( LC_ALL=C grep -c -x -F '## review/task-rig-rv-ended.md' "$rigTmp/scan" )" 1

echo "-- 3. the advance routine's lock does the housekeeping --"
## Fresh cases, made after the scan, so whatever the scan did to the first ones does not stand in for the lock.
rigSandbox rig-ldead2 spawn-started ; rigItem running dispatch-rig-ldead2.md dispatch dispatch-started none rig-ldead2
find "$rigW/.local/agents/spawned/rig-ldead2" -exec touch -t "$( rigStamp 48 )" {} +
rigItem review task-rig-rv-ended2.md task dispatch-succeeded rig-ended none
rigSandbox rig-live2 spawn-started
printf '900002 rig-run --session-id rig-live2\n' >> "$rigTmp/ps.list"
: > "$rigTmp/tooling.log"
rigRun "$rigTmp/lock" --magic-advance-lock-acquire magic-coordinator rig-advance-pass
rigAssert "the lock is taken"                                 "$( cat "$rigTmp/lock.rc" )" 0
rigAssert "the dead spawn's record is closed"                 "$( [ "$( rigHeader "$rigW/.local/agents/spawned/rig-ldead2/rig-ldead2.md" status )" = spawn-started ] && printf open || printf closed )" closed
rigAssert "its item moved to review"                          "$( rigLoc dispatch-rig-ldead2.md )" review
rigAssert "the review-by of the ended reviewer's item is magic-coordinator" "$( rigHeader "$rigD/board/review/task-rig-rv-ended2.md" review-by )" magic-coordinator
rigAssert "the live session's control thread is started"     "$( rigControl rig-live2 )" started

echo "-- 4. its housekeeping goes to the tooling log, none to its output --"
rigAssert "housekeeping lines in the tooling log"            "$( LC_ALL=C grep -c '^housekeeping: ' "$rigTmp/tooling.log" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "logged" : "none" }' )" logged
rigAssert "and none on the lock's standard output"           "$( LC_ALL=C grep -c 'housekeeping' "$rigTmp/lock" || : )" 0

echo "-- 5. the heartbeat scan leaves its lock note as it was --"
mkdir -p "$rigD/inboxes/magic-coordinator"
printf -- '---\ntype: note\nfrom: magic-coordinator\ndate: 2026-10-18\nowner: routine-heartbeat\nstate: heartbeat-running\nrecheck-date: 2026-10-18T10:00:00Z\nsession-id: rig-heartbeat\n---\n\n## state-and-lock (routine-heartbeat)\n' \
	> "$rigD/inboxes/magic-coordinator/note-20260809T155000Z-heartbeat-state-and-lock.md"
rigNoteBefore="$( rigSum "$rigD/inboxes/magic-coordinator/note-20260809T155000Z-heartbeat-state-and-lock.md" )"
rigRun "$rigTmp/hb" --magic-heartbeat-input-scan magic-coordinator
rigAssert "the lock note, its recheck-date among it, is byte for byte as it was" "$( rigSum "$rigD/inboxes/magic-coordinator/note-20260809T155000Z-heartbeat-state-and-lock.md" )" "$rigNoteBefore"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INPUT SCAN PURE READ CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INPUT_SCAN_PURE_READ: OK (%d assertions, offline)\n' "$rigPassCount"
