#!/usr/bin/env bash
## Behavioural check on `DistroAgentsSession.fn.sh --idle-wait` as the way ANY participant says it has finished its batch
## (S18 Open item 2, magic-developer). The call writes a request the harness of the run reads at the end of the round, so
## what it decides is settled here and shown in its own answer. Held:
##   1. a participant of a coworking session has it: a request is written, and the answer says what it waits for -- no NOTICE
##      refusing it on the ground that the routine is not a single-participant one
##   2. a native client's run has it too: the answer says a message is what arrives and that Wait is where it waits, and the
##      run's own mark says it is idle, so whoever gives the next task sees it
##   3. a run that may not return to its checkpoint asks for the signal alone: the request carries the word `signal`
##   4. a single-participant run asks for the return, as it did: no `signal`
##   5. the CheckList gate: an open item that is not the wait-for-more one returns at once with the items, writes no request,
##      names the condition and says to retry
##   6. the wait-for-more item passes the gate by its own text, so a duty's recurring item never blocks its own idle wait
##   7. a list of closed items, and a session with no list, both wait as they should
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
rigTmp="$( rigTempDir AgentsIdleWaitParticipantCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0 rigFailCount=0
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

rigSkills="$rigTmp/skills" ; rigWs="$rigTmp/ws" ; rigSandbox="$rigTmp/sandbox" ; rigId="rig-idle-p"
rigStore="$rigWs/.local/agents/sessions/$rigId"
mkdir -p "$rigSkills/magic-team" "$rigSkills/rig-a" "$rigSkills/rig-b" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig" "$rigSandbox" "$rigTmp/home"
printf 'rig\n' > "$rigSkills/rig-a/rig-a.basic.md" ; printf 'rig\n' > "$rigSkills/rig-a/rig-a.armed.md"
printf 'rig\n' > "$rigSkills/rig-b/rig-b.basic.md" ; printf 'rig\n' > "$rigSkills/rig-b/rig-b.armed.md"
printf 'rig\n' > "$rigSkills/magic-team/magic-team.basic.md" ; printf 'rig\n' > "$rigSkills/magic-team/magic-team.armed.md"
rigRoutine(){ ## short name, kind, executors, invitees, then the lines to add to the frontmatter
	local routineName="$1" routineKind="$2" routineExecutors="$3" routineInvitees="$4" routineLine
	shift 4
	{
		printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: magic-coordinator\ninvitees: %s\nrequires-session-kind: %s\n' "$routineExecutors" "$routineInvitees" "$routineKind"
		for routineLine in "$@" ; do printf '%s\n' "$routineLine" ; done
		printf -- '---\n# magic-team.%s.routine\n' "$routineName"
	} > "$rigSkills/magic-team/magic-team.$routineName.routine.md"
}
rigRoutine cowork coworking rig-a rig-b 'input-scan-def: routine-coworking-session'
rigRoutine duty standalone rig-a none 'input-scan-def: work-duty' 'wait-sources: inbox:{{team-member}} board:running'

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
rigList(){ ## the caller's own list, one a line
	mkdir -p "$rigWs/.local/agents/spawned/rig"
	printf '%s\n' "$@" > "$rigWs/.local/agents/spawned/rig/rig-a.checklist.md"
}
rigOp(){ ## the call as a member's shell makes it
	( cd "$rigTmp" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=rig-a MDAT_SPAWN_SESSION_ID="$rigId" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" \
		bash "$rigSession" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null
	rigRc=$?
	rigOut="$( cat "$rigTmp/out" )" ; rigErr="$( cat "$rigTmp/err" )"
}
rigRequests(){ LC_ALL=C awk 'NF { printf "%s%s", sep, $0 ; sep = ";" }' "$rigStore/checkpoint.request" 2> /dev/null ; }
rigMark(){ LC_ALL=C awk '{ print $3 }' "$rigStore/activity" 2> /dev/null ; }

echo "-- 1. a participant of a coworking session has it --"
rigBind cowork ; rigHarnessRun yes ; rigOp --idle-wait
rigAssert "a request is written, naming the session's scan"                            "$rigRc:$( rigRequests )" "0:idle - signal scan:routine-coworking-session wake:rig-a"
rigAssert "no NOTICE refuses it for want of a single-participant routine"              "$( rigIn "$rigOut" 'single-participant' ):$( rigIn "$rigErr" 'single-participant' )" "no:no"
rigAssert "the answer says it waits for any message addressed to the run"               "$( rigIn "$rigOut" 'any message' ):$( rigIn "$rigOut" 'addressed to this run' )" "yes:yes"

echo "-- 2. a native client's run signals, and is told where it waits --"
rigBind cowork ; rigHarnessRun no ; rigOp --idle-wait
rigAssert "no request: there is no harness here to read one"                            "$rigRc:$( rigRequests )" "0:"
rigAssert "its mark says idle, so the next task giver sees it"                          "$( rigMark )" idle
rigAssert "it is told a message arrives, that it is not a task, and that Wait is where it waits" "$( rigIn "$rigOut" 'message' ):$( rigIn "$rigOut" 'not a task' ):$( rigIn "$rigOut" 'Wait' )" "yes:yes:yes"

echo "-- 3. and 4. who may return to its checkpoint --"
rigBind cowork ; rigHarnessRun yes ; rigOp --idle-wait
rigAssert "a coworking participant signals alone: the return there is not decided"      "$( rigRequests ):$( rigIn "$rigOut" 'signal' )" "idle - signal scan:routine-coworking-session wake:rig-a:yes"
rigBind duty ; rigHarnessRun yes ; printf 'armed\tinit\t0\t1\t2\t2026-01-01T00:00:00Z\n' > "$rigStore/snapshots" ; rigOp --idle-wait
rigAssert "a single-participant run asks for the return, as it did: no signal word"      "$( rigRequests ):$( rigIn "$rigOut" 'returns to its checkpoint armed' )" "idle - scan:work-duty inbox:rig-a board:running wake:rig-a:yes"
rm -f "$rigStore/checkpoint.request" "$rigStore/snapshots"

echo "-- 5. the CheckList gate --"
rigBind duty ; rigHarnessRun yes ; rigList '- [ ] Read the input scan' '- [~] Work the round (in progress: working)'
rigOp --idle-wait
rigAssert "open items return at once, and no request is written"                        "$rigRc:$( rigRequests ):$( rigIn "$rigOut" 'Read the input scan' )" "0::yes"
rigAssert "the answer names the condition and says to retry"                            "$( rigIn "$rigOut" 'CHECKLIST' ):$( rigIn "$rigOut" 'again' )" "yes:yes"

echo "-- 6. the wait-for-more item passes the gate by its own text --"
rigBind duty ; rigHarnessRun yes ; rigList '- [x] Work the round' '- [~] Wait for more: run --idle-wait (in progress: waiting)'
rigOp --idle-wait
rigAssert "the recurring item does not block its own idle wait"                         "$rigRc:$( rigRequests )" "0:idle - scan:work-duty inbox:rig-a board:running wake:rig-a"
rm -f "$rigStore/checkpoint.request" ; rigList '- [ ] Wait for more, which is done by running --idle-wait'
rigOp --idle-wait
rigAssert "and it passes whether it is open or in progress, by its text alone"           "$rigRc:$( rigRequests )" "0:idle - scan:work-duty inbox:rig-a board:running wake:rig-a"
rm -f "$rigStore/checkpoint.request" ; rigList '- [ ] wait for more: run --idle-wait'
rigOp --idle-wait
rigAssert "the duty's own list item passes too, as the two duty routines word it"        "$rigRc:$( rigRequests )" "0:idle - scan:work-duty inbox:rig-a board:running wake:rig-a"
rm -f "$rigStore/checkpoint.request" ; rigList '- [ ] Wait for the next arrival, then answer it'
rigOp --idle-wait
rigAssert "so does the wording a live duty wrote on it"                                  "$rigRc:$( rigRequests )" "0:idle - scan:work-duty inbox:rig-a board:running wake:rig-a"

echo "-- 7. a closed list, and no list at all --"
rigBind duty ; rigHarnessRun yes ; rigList '- [x] Work the round'
rigOp --idle-wait
rigAssert "a list of closed items waits as it should"                                   "$rigRc:$( rigRequests )" "0:idle - scan:work-duty inbox:rig-a board:running wake:rig-a"
rm -f "$rigStore/checkpoint.request" "$rigWs/.local/agents/spawned/rig/rig-a.checklist.md"
rigOp --idle-wait
rigAssert "a session with no list waits as it should"                                   "$rigRc:$( rigRequests )" "0:idle - scan:work-duty inbox:rig-a board:running wake:rig-a"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ IDLE WAIT PARTICIPANT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'IDLE_WAIT_PARTICIPANT: OK (%d assertions, offline)\n' "$rigPassCount"
