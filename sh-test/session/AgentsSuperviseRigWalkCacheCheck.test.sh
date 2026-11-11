#!/usr/bin/env bash
## Behavioural check on the kept list of a rig's control pid files (`AgentsToolsSuperviseRigPidFiles`, sh-lib/session/AgentsTools.SuperviseScan.include).
## The walk over spawned/ to depth 14 ran minutes under load, twice a supervision tick; it now runs once in MDAT_SUPERVISE_RIG_WALK_SECONDS. Held:
##   1. THE FIRST CALL WALKS and lists a control pid file inside a run's output folder.
##   2. A SECOND CALL WITHIN THE TTL READS THE KEPT LIST: a pid file made in between is not listed yet, and the list file is not rewritten.
##   3. TTL 0 WALKS EVERY CALL: both files listed.
##   4. A PID FILE OUTSIDE AN OUTPUT FOLDER is never listed.
## Offline: a temp agents folder, no workspace read.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/session/AgentsTools.SuperviseScan.include" ] || rigRefuse "the supervise scan include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSuperviseRigWalkCacheCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigAgents="$rigTmp/agents"
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
	MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SUPERVISE_RIG_WALK_SECONDS="$1" RIG_AGENTS="$rigAgents" bash -c '
		set +e +u
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SuperviseScan.include" > /dev/null 2>&1
		AgentsToolsSuperviseRigPidFiles "$RIG_AGENTS"
	' 2> /dev/null | sed "s|^$rigAgents/spawned/||"
}
rigOut="$( rigWalk 900 )"
rigAssert "the first call walks and lists the rig's control pid inside the output folder" "$rigOut" "rig-spawn-one/output/magic-tester/rig/.local/agents/sessions/rig-sess-one/control/pid"
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
printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
