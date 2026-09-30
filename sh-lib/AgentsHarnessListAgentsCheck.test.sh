#!/usr/bin/env bash
## Behavioural check on the ListAgents tool (3329): it lists from the spawn sandbox
## registry, not the board. An empty sandbox is a row with no session record; a record
## on this host is running while a process carries its session id and no-process after;
## another host's record is other-host; no MMDAPP is a stated ERROR, never an empty list.
## Served through --intern-tool; every run goes through one `env -i` whose child refuses
## to start outside this rig's mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHarness="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found: $rigHarness"
rigTmp="$( mktemp -d -t AgentsHarnessListAgentsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigSleepPid=""
trap '[ -z "$rigSleepPid" ] || kill "$rigSleepPid" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
rigThisHost="$( hostname -s 2>/dev/null || echo unknown )"
rigSession="rig-sess-$$-live"
mkdir -p "$rigSpawned/rig-empty/input" "$rigWs/data/board/running"
rigRecord(){ ## tracking name, session id, host
	mkdir -p "$rigSpawned/$1/input"
	## spawn-id, not just session-id: liveness is matched on spawn-id since the
	## id split, and a lone spawn's own spawn-id equals its session-id, the same
	## shape this fixture already gives session-id. Missing this made every row
	## read no-spawn-id regardless of a real live process.
	printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: %s\nowner: rig-member\nstatus: started\n---\n' "$2" "$2" "$1" "$3" > "$rigSpawned/$1/$2.md"
}
rigRecord rig-local "$rigSession" "$rigThisHost"
rigRecord rig-remote rig-sess-remote rig-elsewhere
## A board item the old lister would have read; the registry lister must not need it.
printf -- '---\nstatus: dispatch-started\n---\n' > "$rigWs/data/board/running/dispatch-rig-board-only.md"

rigList(){ ## result file, then env assignments for this call
	local listOut="$1" ; shift
	printf '{}' | env -i HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigWs/data" \
		HARNESS_PROVIDER_NAME=rig HARNESS_SELF_NAME=rig RIG_TMP="$rigTmp" RIG_HARNESS="$rigHarness" "$@" \
		bash -c '
			[ -z "${MMDAPP:-}" ] || case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$RIG_TMP" && exec bash "$RIG_HARNESS" --intern-tool ListAgents --access-read-root "$RIG_TMP"
		' > "$listOut" 2> "$listOut.err"
}
rigRow(){ ## result file, tracking name -- that row's live column, or none
	## live is second-to-last: state (section 12) was appended after it, so the
	## column this rig actually asserts on moved from the last field to $(NF-1).
	LC_ALL=C awk -v wantName="$2" '$1 == wantName { print $(NF-1) ; found = 1 ; } END { if ( ! found ) print "no-row" ; }' "$1"
}

echo "-- with a live process carrying the session id --"
( exec -a "rig-holder $rigSession" sleep 60 ) &
rigSleepPid=$!
sleep 1
rigList "$rigTmp/l1" MMDAPP="$rigWs"
## Full row, all thirteen fields: the empty-sandbox row's own columns, then
	## live (no-spawn-id, since it carries no spawn-id at all) and state
	## (unclosed: not finished, not running/other-host, no open ask to wait on).
	rigAssert "an empty sandbox is listed with no session record" "$( LC_ALL=C grep -c -x 'rig-empty - - - - no-session-record - - - - - no-spawn-id unclosed' "$rigTmp/l1" || : )" 1
rigAssert "this host's record with its process is running" "$( rigRow "$rigTmp/l1" rig-local )" running
rigAssert "another host's record is other-host"        "$( rigRow "$rigTmp/l1" rig-remote )" other-host
rigAssert "a board item alone is not a listed session" "$( rigRow "$rigTmp/l1" dispatch-rig-board-only.md )" no-row

echo "-- after the process ends --"
kill "$rigSleepPid" 2>/dev/null ; { wait "$rigSleepPid" ; } 2>/dev/null ; rigSleepPid=""
rigList "$rigTmp/l2" MMDAPP="$rigWs"
rigAssert "the same record is no-process"              "$( rigRow "$rigTmp/l2" rig-local )" no-process

echo "-- control: no MMDAPP --"
rigList "$rigTmp/l3"
rigAssert "it is a stated ERROR"                       "$( LC_ALL=C grep -c '^ERROR: MMDAPP is not set in this process' "$rigTmp/l3" || : )" 1
rigAssert "and never an empty list"                    "$( LC_ALL=C grep -c '^## spawned sessions' "$rigTmp/l3" || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ LIST AGENTS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_LIST_AGENTS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
