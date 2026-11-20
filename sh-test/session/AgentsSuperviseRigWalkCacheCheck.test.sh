#!/usr/bin/env bash
## Behavioural check on the kept list of a rig's control pid files (`AgentsSessionRigControlRows`, sh-lib/spawn/AgentsTools.SpawnSandbox.include).
## The walk over spawned/ to depth 14 ran minutes under load, twice a supervision tick; it now runs once in MDAT_SUPERVISE_RIG_WALK_SECONDS. Held:
##   1. THE FIRST CALL ANSWERS FROM NO LIST and starts the walk in the background; the walk keeps a control pid file inside a run's output folder.
##   2. A SECOND CALL WITHIN THE TTL READS THE KEPT LIST: a pid file made in between is not listed yet, and the list file is not rewritten.
##   3. TTL 0 WALKS EVERY CALL: both files listed.
##   4. A PID FILE OUTSIDE AN OUTPUT FOLDER is never listed.
##   5. ONE WALK AT A TIME: a list past its TTL starts no walk while a live walker holds the lock, and a dead walker's lock is taken over.
##   6. A FINISHED SANDBOX IS NOT WALKED AGAIN: only one with a started run, a record written since a TTL before the last walk, a rig on the kept list
##      or no record is walked; a control shows the skipped sandbox's rig is there to be found.
## Offline: a temp agents folder, no workspace read.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/spawn/AgentsTools.SpawnSandbox.include" ] || rigRefuse "the spawn sandbox include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSuperviseRigWalkCacheCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
rigAgents="$rigWs/.local/agents"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
## A rig left inside a run's output folder: spawned/<spawn>/output/<member>/rig/.local/agents/sessions/<session>/control/pid, depth 10.
rigPidFile(){ ## spawn id, session id
	local pidDir="$rigAgents/spawned/$1/output/magic-tester/rig/.local/agents/sessions/$2/control"
	mkdir -p "$pidDir" && printf '%s %s\n' "$$" "rig" > "$pidDir/pid"
}
rigPidFile rig-spawn-one rig-sess-one
## One outside any output folder: spawned/<spawn>/control/pid, the run's own, never a rig's.
mkdir -p "$rigAgents/spawned/rig-spawn-one/control" && printf '%s own\n' "$$" > "$rigAgents/spawned/rig-spawn-one/control/pid"
rigWalk(){ ## ttl
	MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SUPERVISE_RIG_WALK_SECONDS="$1" MMDAPP="$rigWs" bash -c '
		set +e +u
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.SpawnSandbox.include" > /dev/null 2>&1
		AgentsSessionRigControlRows
	' 2> /dev/null | LC_ALL=C awk -F'\t' '{ print $1 "/" $4 ; }'
}
rigOut="$( rigWalk 900 )"
rigAssert "the first call answers from no list, without waiting on the walk" "$rigOut" ""
rigLeft=10 ; while { [ ! -f "$rigAgents/schedule/supervise.rig-pids" ] || [ -d "$rigAgents/schedule/supervise.rig-pids.walk" ] ; } && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigOut="$( rigWalk 900 )"
rigAssert "the background walk kept the rig's control pid inside the output folder" "$rigOut" "rig-spawn-one/output/magic-tester/rig/.local/agents/sessions/rig-sess-one/control/pid"
rigAssert "the walk's result is kept in schedule/supervise.rig-pids" "$( [ -f "$rigAgents/schedule/supervise.rig-pids" ] && echo kept )" "kept"
rigKeptAt="$( stat -f %m "$rigAgents/schedule/supervise.rig-pids" 2> /dev/null || stat -c %Y "$rigAgents/schedule/supervise.rig-pids" )"
rigPidFile rig-spawn-two rig-sess-two
sleep 1
rigOut="$( rigWalk 900 )"
rigAssert "a second call within the TTL reads the kept list: the new rig is not listed yet" "$( printf '%s\n' "$rigOut" | grep -c 'rig-sess' )" "1"
rigAssert "and the kept list was not rewritten" "$( stat -f %m "$rigAgents/schedule/supervise.rig-pids" 2> /dev/null || stat -c %Y "$rigAgents/schedule/supervise.rig-pids" )" "$rigKeptAt"
rigOut="$( rigWalk 0 )"
rigAssert "TTL 0 walks every call: both rigs listed" "$( printf '%s\n' "$rigOut" | grep -c 'rig-sess' )" "2"
rigAssert "the run's own control pid, outside an output folder, is never listed" "$( printf '%s\n' "$rigOut" | grep -c 'rig-spawn-one/control/pid' )" "0"
touch -t 202001010000 "$rigAgents/schedule/supervise.rig-pids"
mkdir -p "$rigAgents/schedule/supervise.rig-pids.walk" && printf '%s\n' "$$" > "$rigAgents/schedule/supervise.rig-pids.walk/pid"
rigWalk 900 > /dev/null ; sleep 2
rigAssert "a list past its TTL starts no walk while a live walker holds the lock" "$( stat -f %Sm -t %Y "$rigAgents/schedule/supervise.rig-pids" 2> /dev/null || date -r "$( stat -c %Y "$rigAgents/schedule/supervise.rig-pids" )" +%Y )" "2020"
( exit 0 ) & rigGone=$! ; wait "$rigGone"
printf '%s\n' "$rigGone" > "$rigAgents/schedule/supervise.rig-pids.walk/pid"
rigWalk 900 > /dev/null
rigLeft=10 ; while [ -d "$rigAgents/schedule/supervise.rig-pids.walk" ] && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "a lock whose walker is gone is taken over: the list is walked again" "$( stat -f %Sm -t %Y "$rigAgents/schedule/supervise.rig-pids" 2> /dev/null || date -r "$( stat -c %Y "$rigAgents/schedule/supervise.rig-pids" )" +%Y )" "$( date +%Y )"
## A FINISHED SANDBOX IS NOT WALKED AGAIN, in a workspace of its own. Its runs' records: a started run, a finished run written long before the last
## walk, a finished one written since, and a finished one the kept list names; a sandbox with no record. Each holds a rig made after the last walk.
rigWs="$rigTmp/ws-ended" ; rigAgents="$rigWs/.local/agents"
rigRecord(){ ## spawn id, status, touch time or empty
	mkdir -p "$rigAgents/spawned/$1" && printf -- '---\nsession-id: %s\nspawn-id: %s\nstatus: %s\n---\n' "$1" "$1" "$2" > "$rigAgents/spawned/$1/$1.spawn.md"
	[ -z "$3" ] || touch -t "$3" "$rigAgents/spawned/$1/$1.spawn.md"
}
rigRecord rig-live spawn-started 202001010000
rigRecord rig-ended-old spawn-succeeded 202001010000
rigRecord rig-ended-listed spawn-succeeded 202001010000
rigPidFile rig-ended-listed rig-sess-listed
rigOut="$( rigWalk 0 )"
rigAssert "control: the walk before reads the finished sandbox that holds a rig" "$( printf '%s\n' "$rigOut" | grep -c 'rig-sess-listed' )" "1"
## The last walk began 1000 s ago: its list is past the TTL, and a record written since a TTL before it counts as written since.
rigPast="$(( $( date +%s ) - 1000 ))"
touch -t "$( date -r "$rigPast" '+%Y%m%d%H%M.%S' 2> /dev/null || date -d "@$rigPast" '+%Y%m%d%H%M.%S' )" "$rigAgents/schedule/supervise.rig-pids"
rigRecord rig-ended-recent spawn-succeeded ""
for rigOne in rig-live rig-ended-old rig-ended-recent rig-norecord ; do rigPidFile "$rigOne" "rig-sess-$rigOne" ; done
rigWalk 900 > /dev/null
rigLeft=10 ; while [ -d "$rigAgents/schedule/supervise.rig-pids.walk" ] && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigOut="$( rigWalk 900 )"
rigAssert "every sandbox that can hold an unseen rig is walked: the started run's, the recent one's, the listed one's, the one with no record" \
	"$( for rigOne in rig-live rig-ended-recent rig-ended-listed rig-norecord ; do printf '%s ' "$( printf '%s\n' "$rigOut" | grep -c "^$rigOne/output/" )" ; done )" "1 1 1 1 "
rigAssert "a sandbox finished long before the last walk, which named nothing in it, is not walked again" "$( printf '%s\n' "$rigOut" | grep -c '^rig-ended-old/' )" "0"
rigOut="$( rigWalk 0 )"
rigAssert "control: TTL 0 walks every sandbox, so the rig in the old one is there to be found" "$( printf '%s\n' "$rigOut" | grep -c '^rig-ended-old/' )" "1"
printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
