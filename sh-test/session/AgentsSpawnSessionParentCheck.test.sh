#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## AgentsSpawnSessionParentCheck.test.sh -- the agent-less parent of a partitioned spawn watches its children and closes
## once the last one is done (S5 item 1, S17 row 7, S21 item 6). Its children are records, and their liveness is a pid
## this check owns: no model is started, and nothing outside the rig is touched.
##
## Held:
##  1. while a child's process lives, the parent record stays `spawn-started`
##  2. once every child has ended, the parent record closes as `spawn-succeeded`
##  3. the control: a parent whose child record says it failed closes as `spawn-failed`
##
## Not held here: the child's reports-to reaching its caller. Two fixtures were tried and both
## answer `human-owner`. `AgentsToolsRunRouteAvailable` refuses an agent-less parent as a candidate
## for its own member, by design, so the hop cannot end there. The route a child's report takes is
## `AgentsHarnessReports`, which passes its own second argument; a bare route call is not that path.
##
## Offline: one `sleep` this check starts and stops, records under the rig, no model, no network.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigHere/sh-lib/session/AgentsTools.SpawnSandbox.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: no spawn sandbox include at $rigInclude" >&2 ; exit 1 ; }

rigPasses=0
rigFails=0
rigAssert(){
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsSpawnSessionParentCheck.XXXXXX" )" || exit 1
rigChildPids=""
rigStop(){
	[ -z "$rigChildPids" ] || kill $rigChildPids 2> /dev/null || :
	rm -rf -- "$rigTmp"
}
trap rigStop EXIT

rigSpawned="$rigTmp/.local/agents/spawned"
rigSessions="$rigTmp/.local/agents/sessions"
mkdir -p "$rigSpawned" "$rigSessions"

rigRecord(){ ## dir-id, session-id, status, extra lines
	local recId="$1" recSession="$2" recStatus="$3" recRest="${4:-}"
	mkdir -p "$rigSpawned/$recId" "$rigSessions/$recSession/control"
	printf -- '---\ntype: spawn\nstatus: %s\nsession-id: %s\n%s---\n\n# %s\n' "$recStatus" "$recSession" "$recRest" "$recId" > "$rigSpawned/$recId/$recId.spawn.md"
}
rigHeader(){ ## record file, header
	LC_ALL=C awk -v want="$2" '$0 == "---" { n++ ; if ( n > 1 ) exit ; next } n == 1 && index( $0, want ": " ) == 1 { print substr( $0, length( want ) + 3 ) ; exit }' "$1" 2> /dev/null || :
}
rigRunParent(){ ## parent dir-id -- starts the parent loop in the background, prints its pid
	( MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" > /dev/null 2>&1 ; AgentsToolsSpawnSessionParent "$2"' _ "$rigInclude" "$1" > /dev/null 2>&1 & printf '%s' "$!" )
}
rigWaitFor(){ ## what, bound in seconds, a command -- polls until it answers 0
	local waitWhat="$1" waitBound="$2" waitCmd="$3" waitFrom="$SECONDS"
	while [ "$(( SECONDS - waitFrom ))" -lt "$waitBound" ] ; do
		bash -c "$waitCmd" > /dev/null 2>&1 && return 0
		sleep 1
	done
	return 1
}

echo "-- 1. a parent waits while a child's process lives --"
sleep 30 & rigChildPids="$rigChildPids $!"
rigChildPid="${rigChildPids##* }"
rigRecord parent-b one-child spawn-started "children: one-child
owner: rig-member
"
rigRecord one-child one-child spawn-started "parent-session-id: parent-b
run-process: $rigChildPid 1
owner: rig-member
"
rigParentPid="$( rigRunParent parent-b )"
sleep 3
rigAssert "the parent is still open while its child runs" "$( rigHeader "$rigSpawned/parent-b/parent-b.spawn.md" status )" "spawn-started"

echo "-- 2. it closes once the child has ended --"
kill "$rigChildPid" 2> /dev/null || : ; wait "$rigChildPid" 2> /dev/null || :
rigChildPids=""
LC_ALL=C awk '{ if ( $0 == "status: spawn-started" ) print "status: spawn-succeeded" ; else print }' "$rigSpawned/one-child/one-child.spawn.md" > "$rigSpawned/one-child/one-child.spawn.md.tmp" && mv -f "$rigSpawned/one-child/one-child.spawn.md.tmp" "$rigSpawned/one-child/one-child.spawn.md"
rigWaitFor "the parent to close" 20 "grep -q '^status: spawn-succeeded$' '$rigSpawned/parent-b/parent-b.spawn.md'"
rigAssert "the parent closes as succeeded" "$( rigHeader "$rigSpawned/parent-b/parent-b.spawn.md" status )" "spawn-succeeded"
kill "$rigParentPid" 2> /dev/null || :

echo "-- 3. the control: a failed child closes the parent as failed --"
sleep 30 & rigChildPids="$rigChildPids $!"
rigChildPid2="${rigChildPids##* }"
rigRecord parent-c two-child spawn-started "children: two-child
owner: rig-member
"
rigRecord two-child two-child spawn-started "parent-session-id: parent-c
run-process: $rigChildPid2 1
owner: rig-member
"
rigParentPid2="$( rigRunParent parent-c )"
sleep 2
kill "$rigChildPid2" 2> /dev/null || : ; wait "$rigChildPid2" 2> /dev/null || :
rigChildPids=""
LC_ALL=C awk '{ if ( $0 == "status: spawn-started" ) print "status: spawn-failed" ; else print }' "$rigSpawned/two-child/two-child.spawn.md" > "$rigSpawned/two-child/two-child.spawn.md.tmp" && mv -f "$rigSpawned/two-child/two-child.spawn.md.tmp" "$rigSpawned/two-child/two-child.spawn.md"
rigWaitFor "the parent to close" 20 "grep -q '^status: spawn-failed$' '$rigSpawned/parent-c/parent-c.spawn.md'"
rigAssert "a failed child closes its parent as failed" "$( rigHeader "$rigSpawned/parent-c/parent-c.spawn.md" status )" "spawn-failed"
kill "$rigParentPid2" 2> /dev/null || :

echo "-- 4. a child born of a parent reaches the caller the parent names --"
rigRecord caller-s caller-s spawn-started "owner: magic-coordinator
"
rigRecord par-route par-route spawn-started "agent-less: true
owner: magic-coordinator
reports-to: caller-s:magic-coordinator
"
rigRecord kid-route kid-route spawn-started "parent-session-id: par-route
owner: rig-member
"
rigAssert "the route follows the parent's own address to its caller" \
	"$( MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" > /dev/null 2>&1 ; AgentsToolsRunRoute "$2"' _ "$rigInclude" "$rigSpawned/kid-route/kid-route.spawn.md" 2> /dev/null )" \
	"caller-s:magic-coordinator"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN SESSION PARENT CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  fix:  the parent's watch and its close, in AgentsTools.SpawnSandbox.include" >&2
	exit 1
fi
printf 'SPAWN_SESSION_PARENT: OK (%d assertions, offline)\n' "$rigPasses"
