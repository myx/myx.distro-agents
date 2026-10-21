#!/usr/bin/env bash
## Behavioural check on the executor's checkpoint operations of ThisSession (F10.5 of the refactorings epic): `DistroAgentsSession.fn.sh
## --executor-checkpoint-push [<name>]`, `--executor-checkpoint-rewind [<name>]` and `--executor-checkpoint-exit`. Each WRITES A REQUEST
## into the run's store for the harness of the run to read at the end of the round (the harness side is AgentsHarnessCheckpointCheck);
## every refusal that can be known here is made here, in the call's own answer. Held:
##   1. the syntax: a name is bare and at most one; exit takes none; an operation of the family that does not exist is invalid
##   2. locked to the session: from no member's session, and from a call that belongs to no spawned session, refused
##   3. a run of a native client (no marker of the harness in its sandbox) and a session whose routine does not allow the operation to
##      its member (no routine, other member, other operation, routine of another member) get a NOTICE, exit 0, and no request
##   4. allowed by an entry of the routine's own `allows:` for the member, for `executors` or for `participants`: the request is written, in
##      the order of the calls, and the answer says when it is made
##   5. a rewind names a snapshot the run holds (its store's `snapshots`), or none and the newest: else refused, naming what is held
## Offline: every path under one temp tree, no model, no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigSession="${rigHere%/sh-lib}/sh-scripts/DistroAgentsSession.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSession" ] || rigRefuse "ThisSession is not at the origin this workspace resolves: $rigSession"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsExecutorCheckpointOpsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigIn(){ ## text, needle -- yes where the text holds the needle
	case "$1" in
		*"$2"*) printf 'yes' ;;
		*) printf 'no' ;;
	esac
}

rigSkills="$rigTmp/skills" ; rigWs="$rigTmp/ws" ; rigSandbox="$rigTmp/sandbox" ; rigId="rig-cp-1"
rigStore="$rigWs/.local/agents/sessions/$rigId"
mkdir -p "$rigSkills/magic-team" "$rigSkills/rig-a" "$rigSkills/rig-b" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig" "$rigSandbox" "$rigTmp/home"
printf 'rig\n' > "$rigSkills/rig-a/rig-a.basic.md" ; printf 'rig\n' > "$rigSkills/rig-a/rig-a.armed.md"
printf 'rig\n' > "$rigSkills/rig-b/rig-b.basic.md" ; printf 'rig\n' > "$rigSkills/rig-b/rig-b.armed.md"
printf 'rig\n' > "$rigSkills/magic-team/magic-team.basic.md" ; printf 'rig\n' > "$rigSkills/magic-team/magic-team.armed.md"
rigRoutine(){ ## short name, executors, allows
	{
		printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: magic-coordinator\ninvitees: none\nrequires-session-kind: standalone\n' "$2"
		[ -z "$3" ] || printf 'allows: %s\n' "$3"
		printf -- '---\n# magic-team.%s.routine\n' "$1"
	} > "$rigSkills/magic-team/magic-team.$1.routine.md"
}
rigRoutine viaexec rig-a "executors:--executor-checkpoint-push,executors:--executor-checkpoint-rewind,executors:--executor-checkpoint-exit"
rigRoutine viaparts rig-a "participants:--executor-checkpoint-push,participants:--executor-checkpoint-rewind,participants:--executor-checkpoint-exit"
rigRoutine vianame rig-a "rig-a:--executor-checkpoint-push,rig-a:--executor-checkpoint-rewind,rig-a:--executor-checkpoint-exit"
rigRoutine forother rig-a "rig-b:--executor-checkpoint-push,rig-b:--executor-checkpoint-rewind"
rigRoutine pushonly rig-a "executors:--executor-checkpoint-push"
rigRoutine otherexec rig-b "executors:--executor-checkpoint-push,executors:--executor-checkpoint-rewind"
rigRoutine nothing rig-a ""
rigRoutine unrelated rig-a "executors:Read:/some/where,executors:--executor-checkpoint-pushy"

rigBind(){ ## routine short name, or empty for a spawn record with no routine
	{
		printf -- '---\nspawn-id: %s\nsession-id: %s\n' "$rigId" "$rigId"
		[ -z "$1" ] || printf 'routine: magic-team.%s.routine.md\n' "$1"
		printf 'status: spawn-started\n---\n'
	} > "$rigWs/.local/agents/spawned/rig/$rigId.spawn.md"
	rm -rf "$rigStore" ; mkdir -p "$rigStore"
}
rigHarnessRun(){ ## the marker of a harness run in the sandbox, or none
	if [ "$1" = yes ] ; then : > "$rigSandbox/$rigId.harness" ; else rm -f "$rigSandbox/$rigId.harness" ; fi
}
rigOp(){ ## operation word, then its arguments; env words before `--` (rigEnv) -- the call as a member's shell makes it
	local opWord="$1" ; shift
	( cd "$rigTmp" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT="${rigMember-rig-a}" MDAT_SPAWN_SESSION_ID="${rigSpawnId-$rigId}" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" \
		bash "$rigSession" "$opWord" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err"
	rigRc=$?
	rigOut="$( cat "$rigTmp/out" )" ; rigErr="$( cat "$rigTmp/err" )"
}
rigRequests(){ ## the requests written, space-joined with ; between
	LC_ALL=C awk 'NF { printf "%s%s", sep, $0 ; sep = ";" }' "$rigStore/checkpoint.request" 2> /dev/null
}

echo "-- 1. the syntax --"
rigBind viaexec ; rigHarnessRun yes
rigOp --executor-checkpoint-push one two
rigAssert "push takes at most one name"                                                "$rigRc:$( rigIn "$rigErr" 'syntax is --executor-checkpoint-push [<name>]' ):$( rigRequests )" "1:yes:"
rigOp --executor-checkpoint-exit now
rigAssert "exit takes none"                                                            "$rigRc:$( rigIn "$rigErr" 'syntax is --executor-checkpoint-exit, and takes no argument' ):$( rigRequests )" "1:yes:"
rigOp --executor-checkpoint-push "a b"
rigAssert "a name is bare: no space"                                                   "$rigRc:$( rigIn "$rigErr" 'must be a bare name' )$( rigIn "$rigErr" 'outside the allowed set' ):$( rigRequests )" "1:noyes:"
rigOp --executor-checkpoint-rewind "../x"
rigAssert "and no path"                                                                "$rigRc:$( rigRequests )" "1:"
rigOp --executor-checkpoint-nothing
rigAssert "an operation of the family that does not exist is invalid"                  "$rigRc:$( rigIn "$rigErr" 'invalid option: --executor-checkpoint-nothing' )" "1:yes"

echo "-- 2. locked to the session --"
rigMember="" ; rigOp --executor-checkpoint-push
rigAssert "from no member's session: refused, nothing written"                         "$rigRc:$( rigIn "$rigErr" "a call from no member's session" ):$( rigRequests )" "1:yes:"
rigMember="rig-a" ; rigSpawnId="" ; rigOp --executor-checkpoint-push
rigAssert "from a call that belongs to no spawned session: refused, nothing written"   "$rigRc:$( rigIn "$rigErr" 'belongs to no spawned session' ):$( rigRequests )" "1:yes:"
unset rigMember rigSpawnId

echo "-- 3. a notice, no request --"
rigBind viaexec ; rigHarnessRun no
rigOp --executor-checkpoint-push opening
rigAssert "a native client's run: a NOTICE, exit 0, no request"                       "$rigRc:$( rigIn "$rigOut" 'NOTICE: --executor-checkpoint-push: no checkpoint was made -- this run is a native client' ):$( rigRequests )" "0:yes:"
rigHarnessRun yes
rigBind "" ; rigOp --executor-checkpoint-push opening
rigAssert "a session with no routine"                                                  "$rigRc:$( rigIn "$rigOut" 'does not allow it to its member' ):$( rigRequests )" "0:yes:"
rigBind nothing ; rigOp --executor-checkpoint-push opening
rigAssert "a routine with no allows"                                                   "$rigRc:$( rigIn "$rigOut" 'does not allow it to its member' ):$( rigRequests )" "0:yes:"
rigBind forother ; rigOp --executor-checkpoint-push opening
rigAssert "an allows for another member"                                               "$rigRc:$( rigIn "$rigOut" 'does not allow it to its member' ):$( rigRequests )" "0:yes:"
rigBind otherexec ; rigOp --executor-checkpoint-push opening
rigAssert "an allows for the executors of a routine whose executor is another member"  "$rigRc:$( rigIn "$rigOut" 'does not allow it to its member' ):$( rigRequests )" "0:yes:"
rigBind unrelated ; rigOp --executor-checkpoint-push opening
rigAssert "other entries, and an operation whose name only begins like it"             "$rigRc:$( rigIn "$rigOut" 'does not allow it to its member' ):$( rigRequests )" "0:yes:"
rigBind pushonly ; rigOp --executor-checkpoint-exit
rigAssert "an operation the routine does not name, though it names another"            "$rigRc:$( rigIn "$rigOut" 'does not allow it to its member' ):$( rigRequests )" "0:yes:"

echo "-- 4. allowed: the request is written --"
rigBind viaexec ; rigOp --executor-checkpoint-push opening
rigAssert "executors: the request, and an answer saying when it is made"               "$rigRc:$( rigIn "$rigOut" 'OK: --executor-checkpoint-push: the snapshot opening is made at the end of this round' ):$( rigRequests )" "0:yes:push opening"
rigBind viaparts ; rigOp --executor-checkpoint-push
rigAssert "participants: the request, with the name the harness defaults"             "$rigRc:$( rigIn "$rigOut" 'the snapshot checkpoint is made' ):$( rigRequests )" "0:yes:push"
rigBind vianame ; rigOp --executor-checkpoint-push opening
rigAssert "the member by name"                                                         "$rigRc:$( rigRequests )" "0:push opening"
rigBind viaexec
rigOp --executor-checkpoint-push a ; rigOp --executor-checkpoint-push b ; rigOp --executor-checkpoint-exit
rigAssert "several calls in a round are written in the order they were made"          "$( rigRequests )" "push a;push b;exit"
rigBind pushonly ; rigOp --executor-checkpoint-push opening
rigAssert "an operation the routine names, among others it does not"                   "$rigRc:$( rigRequests )" "0:push opening"

echo "-- 5. a rewind names a snapshot the run holds --"
rigBind viaexec
rigOp --executor-checkpoint-rewind
rigAssert "none held: refused, nothing written"                                        "$rigRc:$( rigIn "$rigErr" 'this run holds no snapshot to return to' ):$( rigRequests )" "1:yes:"
printf 'armed\tinit\t0\t1\t2\t2026-01-01T00:00:00Z\nopening\tcount\t3\t1\t2\t2026-01-01T00:00:01Z\n' > "$rigStore/snapshots"
rigOp --executor-checkpoint-rewind nosuch
rigAssert "a name not held: refused, naming what is"                                   "$rigRc:$( rigIn "$rigErr" "no snapshot named 'nosuch' -- this run holds: armed opening" ):$( rigRequests )" "1:yes:"
rigOp --executor-checkpoint-rewind opening
rigAssert "a name held: the request"                                                   "$rigRc:$( rigRequests ):$( rigIn "$rigOut" 'the conversation returns to opening at the end of this round' )" "0:rewind opening:yes"
rigOp --executor-checkpoint-rewind
rigAssert "no name: the newest, and the answer says so"                                "$rigRc:$( rigRequests ):$( rigIn "$rigOut" 'returns to the newest snapshot' )" "0:rewind opening;rewind:yes"
rigOp --executor-checkpoint-rewind armed
rigAssert "the tooling's own armed can be returned to"                                 "$rigRc:$( rigRequests )" "0:rewind opening;rewind;rewind armed"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ EXECUTOR CHECKPOINT OPS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'EXECUTOR_CHECKPOINT_OPS: OK (%d assertions, offline)\n' "$rigPassCount"
