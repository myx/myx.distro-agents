#!/usr/bin/env bash
## Behavioural check on `DistroAgentsSession.fn.sh --idle-wait [--wait-timeout <seconds>]` of ThisSession (F10.5 gate B of the refactorings
## epic), and on the new dispatch of `--executor-checkpoint-rewind [<name>] [--from-stdin]`. Like the checkpoint operations, `--idle-wait`
## WRITES A REQUEST into the run's store for the harness of the run to read at the end of the round (the harness side is
## AgentsHarnessIdleWaitCheck): the wait and the return of the conversation are the harness's, because only it holds the conversation.
## What the call knows here it settles here, in its own answer. Held:
##   1. the syntax: one option, `--wait-timeout`, whole seconds; nothing else
##   2. locked to the session: from no member's session, and from a call that belongs to no spawned session, refused
##   3. who has it: only a single-participant session (a routine of kind standalone with one executor and no invitee) and a separate
##      spawn (no routine). A native client's run, and a routine of several participants, get a NOTICE, exit 0, no request, and are told
##      to Wait, so a loop on the call cannot spin
##   4. what it waits on: the floor, and the scans the routine itself declares (`input-scan-def:`), by name, as `scan:` sources; `none`
##      declares none, an option of a scan is not carried, a scan named twice is named once; then the sources it declares with `wait-sources:`,
##      the macro {{team-member}} being the member of the run, a source named twice once
##   5. the answer names the checkpoint the run returns to: `opening` where the run holds it, else `armed`, else none
##   6. the new dispatch of a rewind: `--from-stdin` keeps the text, whole, for the harness to give as the next input; with no text it is refused
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
rigTmp="$( rigTempDir AgentsIdleWaitOpCheck )" || exit 1
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

rigSkills="$rigTmp/skills" ; rigWs="$rigTmp/ws" ; rigSandbox="$rigTmp/sandbox" ; rigId="rig-idle-1"
rigStore="$rigWs/.local/agents/sessions/$rigId"
mkdir -p "$rigSkills/magic-team" "$rigSkills/rig-a" "$rigSkills/rig-b" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig" "$rigSandbox" "$rigTmp/home"
printf 'rig\n' > "$rigSkills/rig-a/rig-a.basic.md" ; printf 'rig\n' > "$rigSkills/rig-a/rig-a.armed.md"
printf 'rig\n' > "$rigSkills/rig-b/rig-b.basic.md" ; printf 'rig\n' > "$rigSkills/rig-b/rig-b.armed.md"
printf 'rig\n' > "$rigSkills/magic-team/magic-team.basic.md" ; printf 'rig\n' > "$rigSkills/magic-team/magic-team.armed.md"
rigRoutine(){ ## short name, kind, executors, invitees, then the lines to add to the frontmatter, one argument each
	local routineName="$1" routineKind="$2" routineExecutors="$3" routineInvitees="$4" routineLine
	shift 4
	{
		printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: magic-coordinator\ninvitees: %s\nrequires-session-kind: %s\n' "$routineExecutors" "$routineInvitees" "$routineKind"
		for routineLine in "$@" ; do printf '%s\n' "$routineLine" ; done
		printf -- '---\n# magic-team.%s.routine\n' "$routineName"
	} > "$rigSkills/magic-team/magic-team.$routineName.routine.md"
}
rigRoutine solonone standalone rig-a none 'input-scan-def: none'
rigRoutine soloquiet standalone rig-a none
rigRoutine solowait standalone rig-a none 'input-scan-def: work-duty' 'wait-sources: inbox:{{team-member}} board:running board:pending' 'wait-sources: board:running'
rigRoutine soloduty standalone rig-a none 'input-scan-def: work-duty'
rigRoutine solomany standalone rig-a none 'input-scan-def: grooming --select-workspace somewhere' 'input-scan-def: work-duty' 'input-scan-def: grooming'
rigRoutine soloplus standalone rig-a none 'input-scan-def: work-duty' 'allows: executors:--executor-checkpoint-push,executors:--executor-checkpoint-rewind'
rigRoutine cowork coworking rig-a rig-b 'input-scan-def: routine-coworking-session'
rigRoutine twoexec standalone 'rig-a, rig-b' none 'input-scan-def: work-duty'
rigRoutine invited standalone rig-a rig-b 'input-scan-def: work-duty'
rigRoutine teamwide standalone magic-team none 'input-scan-def: work-duty'

rigBind(){ ## routine short name, or empty for a spawn record with no routine
	{
		printf -- '---\nspawn-id: %s\nsession-id: %s\n' "$rigId" "$rigId"
		[ -z "$1" ] || printf 'routine: magic-team.%s.routine.md\n' "$1"
		printf 'status: spawn-started\n---\n'
	} > "$rigWs/.local/agents/spawned/rig/$rigId.md"
	rm -rf "$rigStore" ; mkdir -p "$rigStore"
}
rigHarnessRun(){ ## the marker of a harness run in the sandbox, or none
	if [ "$1" = yes ] ; then : > "$rigSandbox/$rigId.harness" ; else rm -f "$rigSandbox/$rigId.harness" ; fi
}
rigOp(){ ## operation word, then its arguments -- the call as a member's shell makes it (standard input: rigStdin, else none)
	local opWord="$1" ; shift
	( cd "$rigTmp" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT="${rigMember-rig-a}" MDAT_SPAWN_SESSION_ID="${rigSpawnId-$rigId}" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" \
		bash "$rigSession" "$opWord" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < "${rigStdin:-/dev/null}"
	rigRc=$?
	rigOut="$( cat "$rigTmp/out" )" ; rigErr="$( cat "$rigTmp/err" )"
}
rigRequests(){ ## the requests written, joined with ; between
	LC_ALL=C awk 'NF { printf "%s%s", sep, $0 ; sep = ";" }' "$rigStore/checkpoint.request" 2> /dev/null
}

echo "-- 1. the syntax --"
rigBind soloduty ; rigHarnessRun yes
rigOp --idle-wait now
rigAssert "an argument it does not know: refused, nothing written"                      "$rigRc:$( rigIn "$rigErr" 'invalid option: now' ):$( rigIn "$rigErr" 'syntax is --idle-wait [--wait-timeout <seconds>]' ):$( rigRequests )" "1:yes:yes:"
rigOp --idle-wait --wait-timeout
rigAssert "a timeout with no value"                                                     "$rigRc:$( rigIn "$rigErr" '--wait-timeout takes whole seconds' ):$( rigRequests )" "1:yes:"
rigOp --idle-wait --wait-timeout soon
rigAssert "a timeout that is no number"                                                 "$rigRc:$( rigIn "$rigErr" '--wait-timeout takes whole seconds' ):$( rigRequests )" "1:yes:"
rigOp --idle-wait --wait-timeout 1.5
rigAssert "or no whole number"                                                          "$rigRc:$( rigRequests )" "1:"

echo "-- 2. locked to the session --"
rigMember="" ; rigOp --idle-wait
rigAssert "from no member's session: refused, nothing written"                          "$rigRc:$( rigIn "$rigErr" "a call from no member's session" ):$( rigRequests )" "1:yes:"
rigMember="rig-a" ; rigSpawnId="" ; rigOp --idle-wait
rigAssert "from a call that belongs to no spawned session: refused, nothing written"    "$rigRc:$( rigIn "$rigErr" 'belongs to no spawned session' ):$( rigRequests )" "1:yes:"
unset rigMember rigSpawnId

echo "-- 3. who has it --"
rigBind soloduty ; rigHarnessRun no
rigOp --idle-wait
rigAssert "a native client's run: a NOTICE, exit 0, no request, told to Wait"           "$rigRc:$( rigIn "$rigOut" 'NOTICE: --idle-wait: nothing was waited on' ):$( rigIn "$rigOut" "native client's" ):$( rigIn "$rigOut" 'Wait' ):$( rigRequests )" "0:yes:yes:yes:"
rigHarnessRun yes
rigBind cowork ; rigOp --idle-wait
rigAssert "a coworking routine: a NOTICE, no request"                                   "$rigRc:$( rigIn "$rigOut" 'NOTICE: --idle-wait: nothing was waited on' ):$( rigIn "$rigOut" 'single-participant' ):$( rigRequests )" "0:yes:yes:"
rigBind twoexec ; rigOp --idle-wait
rigAssert "a standalone routine of two executors"                                       "$rigRc:$( rigIn "$rigOut" 'single-participant' ):$( rigRequests )" "0:yes:"
rigBind invited ; rigOp --idle-wait
rigAssert "a standalone routine with an invitee"                                        "$rigRc:$( rigIn "$rigOut" 'single-participant' ):$( rigRequests )" "0:yes:"
rigBind teamwide ; rigOp --idle-wait
rigAssert "a routine whose executors are the whole team"                                "$rigRc:$( rigIn "$rigOut" 'single-participant' ):$( rigRequests )" "0:yes:"
rigBind "" ; rigOp --idle-wait
rigAssert "a separate spawn, with no routine, has it"                                   "$rigRc:$( rigRequests )" "0:idle -"
rigBind soloquiet ; rigOp --idle-wait
rigAssert "a single-participant routine has it"                                         "$rigRc:$( rigRequests )" "0:idle -"

echo "-- 4. what it waits on --"
rigBind solonone ; rigOp --idle-wait
rigAssert "input-scan-def: none declares no scan: the floor alone"                      "$rigRc:$( rigRequests ):$( rigIn "$rigOut" 'waits on the floor' ):$( rigIn "$rigOut" 'scan:' )" "0:idle -:yes:no"
rigBind soloduty ; rigOp --idle-wait
rigAssert "a declared scan is a source, by name"                                        "$rigRc:$( rigRequests ):$( rigIn "$rigOut" 'the floor and scan:work-duty' )" "0:idle - scan:work-duty:yes"
rigBind solomany ; rigOp --idle-wait
rigAssert "several: in order, an option of a scan not carried, a scan once"             "$( rigRequests )" "idle - scan:grooming scan:work-duty"
rigBind soloduty ; rigOp --idle-wait --wait-timeout 30
rigAssert "a timeout is carried, and the answer says what a quiet wait does"            "$( rigRequests ):$( rigIn "$rigOut" '30 seconds' )" "idle 30 scan:work-duty:yes"
rigBind soloduty ; rigOp --idle-wait --wait-timeout 0
rigAssert "a timeout of 0 is one: read once and return"                                 "$rigRc:$( rigRequests )" "0:idle 0 scan:work-duty"
rigBind solowait ; rigOp --idle-wait
rigAssert "the sources a routine declares are added after its scans: its own inbox by the macro, the board states, none twice" "$( rigRequests ):$( rigIn "$rigOut" 'inbox:rig-a, board:running, board:pending' )" "idle - scan:work-duty inbox:rig-a board:running board:pending:yes"
rigBind soloplus ; rigOp --executor-checkpoint-push a ; rigOp --idle-wait
rigAssert "in the order of the calls of the round, after the snapshot asked before it"  "$( rigRequests )" "push a;idle - scan:work-duty"
rigBind soloduty ; rigOp --executor-checkpoint-push a ; rigOp --idle-wait
rigAssert "it needs no allows: of its own: the wait is asked where the snapshot was a notice" "$( rigRequests )" "idle - scan:work-duty"

echo "-- 5. the answer names the checkpoint the run returns to --"
rigBind soloduty ; rigOp --idle-wait
rigAssert "none held: it says the arrival comes as a message and nothing is returned"   "$( rigIn "$rigOut" 'no snapshot is held' ):$( rigIn "$rigOut" 'not returned' )" "yes:yes"
printf 'armed\tinit\t0\t1\t2\t2026-01-01T00:00:00Z\n' > "$rigStore/snapshots" ; rigOp --idle-wait
rigAssert "armed held: the run returns to armed"                                        "$( rigIn "$rigOut" 'returns to its checkpoint armed' )" yes
printf 'armed\tinit\t0\t1\t2\t2026-01-01T00:00:00Z\nopening\tcount\t3\t1\t2\t2026-01-01T00:00:01Z\nlater\tcount\t5\t1\t2\t2026-01-01T00:00:02Z\n' > "$rigStore/snapshots" ; rigOp --idle-wait
rigAssert "opening held: the run returns to opening, not to the newest"                 "$( rigIn "$rigOut" 'returns to its checkpoint opening' ):$( rigIn "$rigOut" 'later' )" "yes:no"

echo "-- 6. the new dispatch of a rewind --"
rigBind soloplus
printf 'armed\tinit\t0\t1\t2\t2026-01-01T00:00:00Z\nopening\tcount\t3\t1\t2\t2026-01-01T00:00:01Z\n' > "$rigStore/snapshots"
printf 'first line\nsecond line\n\nfourth after a blank\n' > "$rigTmp/dispatch.in" ; rigStdin="$rigTmp/dispatch.in"
rigOp --executor-checkpoint-rewind opening --from-stdin
rigAssert "the text is kept whole, beside the request"                                  "$rigRc:$( rigRequests ):$( cat "$rigStore/checkpoint.dispatch" 2> /dev/null | LC_ALL=C tr '\n' '|' )" "0:rewind opening:first line|second line||fourth after a blank|"
rigAssert "and the answer says the text is the next input"                              "$( rigIn "$rigOut" 'with the text given as the next input' )" yes
rm -f "$rigStore/checkpoint.dispatch" "$rigStore/checkpoint.request"
rigOp --executor-checkpoint-rewind --from-stdin
rigAssert "no name: the newest, with the text"                                          "$rigRc:$( rigRequests ):$( [ -s "$rigStore/checkpoint.dispatch" ] && printf kept || printf none )" "0:rewind:kept"
rm -f "$rigStore/checkpoint.dispatch" "$rigStore/checkpoint.request"
rigOp --executor-checkpoint-rewind --from-stdin opening
rigAssert "in either order"                                                             "$rigRc:$( rigRequests ):$( [ -s "$rigStore/checkpoint.dispatch" ] && printf kept || printf none )" "0:rewind opening:kept"
rm -f "$rigStore/checkpoint.dispatch" "$rigStore/checkpoint.request"
rigOp --executor-checkpoint-rewind opening
rigAssert "without --from-stdin there is no dispatch: the return alone, as before"      "$rigRc:$( rigRequests ):$( [ -e "$rigStore/checkpoint.dispatch" ] && printf kept || printf none )" "0:rewind opening:none"
rm -f "$rigStore/checkpoint.request"
rigStdin="/dev/null" ; rigOp --executor-checkpoint-rewind opening --from-stdin
rigAssert "--from-stdin with no text is refused, nothing written"                       "$rigRc:$( rigIn "$rigErr" 'no text on standard input' ):$( rigRequests ):$( [ -e "$rigStore/checkpoint.dispatch" ] && printf kept || printf none )" "1:yes::none"
rigStdin="$rigTmp/dispatch.in" ; rigOp --executor-checkpoint-rewind one two --from-stdin
rigAssert "more than one name is still the syntax error, naming the new form"           "$rigRc:$( rigIn "$rigErr" 'syntax is --executor-checkpoint-rewind [<name>] [--from-stdin]' ):$( rigRequests )" "1:yes:"
rigOp --executor-checkpoint-push opening --from-stdin
rigAssert "a push takes no dispatch: --from-stdin is not a name of one"                 "$rigRc:$( rigRequests )" "1:"
rigStdin="$rigTmp/dispatch.in" ; rigHarnessRun no ; rigOp --executor-checkpoint-rewind opening --from-stdin
rigAssert "a native client's run keeps no dispatch: the notice, as for the rest"        "$rigRc:$( rigIn "$rigOut" 'NOTICE' ):$( [ -e "$rigStore/checkpoint.dispatch" ] && printf kept || printf none )" "0:yes:none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ IDLE WAIT OP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'IDLE_WAIT_OP: OK (%d assertions, offline)\n' "$rigPassCount"
