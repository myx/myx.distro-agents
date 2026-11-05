#!/usr/bin/env bash
## Behavioural check on what a routine stack's move does to the executor (S6.27 stage 3, build order
## step 3): a move's result carries the frame's steps and the step the run starts at, and the
## executor's own CheckList is left exactly as it was.
## Held:
##   1. a push names the routine's steps, in their order
##   2. and names its first step as the step the run starts at
##   3. a rewind starts at that routine's first step, whether or not the list closed it
##   4. a push starts past a step its own list has already closed
##   5. the CheckList is not written by a move: the file is byte for byte what it was
##   6. the list a move reads is the one the CheckList tool writes, wherever the record is filed (D2): a session
##      whose record is filed under its spawn id, and whose list stands in sessions/<session-id>/, is still read
## Red before stage 3: 1 to 4 fail (a move's result names no step); 5 holds from stage 2.
## Red before the list's place was fixed on live: 6 fails (the move reads the record's folder, and names no step).
## Offline: a fake curl answers Slack; every workspace is a folder of the rig's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigSessionFn="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
unset MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SESSION_THREAD MDAT_SPAWN_AGENT MDAT_SPAWN_SANDBOX_ROOT CLAUDE_CODE_SESSION_ID harnessSessionId harnessAgent
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigSessionFn" "$rigFixtures/session-chat.curl.stub.sh" "$rigFixtures/rig-temp.include.sh" "$rigFixtures/rig-exec.py" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineStackMoveStepsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/skills/rig-member" "$rigTmp/data"
printf 'rig member\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

printf -- '---\nexecutors: rig-member\nmaintainers: rig-member\ninvitees: none\nrequires-session-kind: standalone\n---\n# rig standalone kind\n' \
	> "$rigTmp/skills/magic-team/magic-team.standalone.routine.md"
rigRoutine(){ ## file name, the two step names
	local routineName="$1" routineOne="$2" routineTwo="$3"
	{
		printf -- '---\ntype: routine\nexecutors: rig-member\nmaintainers: rig-member\ninvitees: none\nrequires-session-kind: standalone\n---\n'
		printf '# %s\n\n# Steps\n\n' "$routineName"
		printf '1. **%s**: do the first thing.\n2. **%s**: do the second thing.\n' "$routineOne" "$routineTwo"
	} > "$rigTmp/skills/magic-team/$routineName"
}
rigRoutine rig-a.routine.md rig-a-one rig-a-two
rigRoutine rig-b.routine.md rig-b-one rig-b-two
rigRoutine rig-c.routine.md rig-c-one rig-c-two

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigWs="" rigSession="" rigRecord="" rigScn="" rigList=""
## A workspace of the rig's own: a session whose record holds one frame, its thread, and the
## executor's own CheckList beside that record, as the spawner leaves it.
rigScene(){ ## scenario name
	rigScn="$rigTmp/$1"
	rigWs="$rigScn/ws"
	rigSession="rig-sess-$1"
	rm -rf "$rigScn"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/spawned/$rigSession" "$rigWs/.local/agents/sessions/$rigSession" "$rigScn/data"
	rigRecord="$rigWs/.local/agents/spawned/$rigSession/$rigSession.spawn.md"
	rigList="$rigWs/.local/agents/spawned/$rigSession/rig-member.checklist.md"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_WORKSPACE_DOMAIN=rig.slack.com\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/rig-member.agent.env"
	: > "$rigScn/calls"
	printf '%s\n' "CRIG00001:1760000000.000050" > "$rigWs/.local/agents/sessions/$rigSession/session.thread"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: righost\nworkspace: rigws\nowner: rig-member\nstart-context: spawned\nroutine: rig-a.routine.md\nroutine-stack: rig-a.routine.md:current\nstatus: spawn-started\nstarted-at: 2026-11-04 09:00 +0300\n---\n\n# Spawn session: %s\n' \
		"$rigSession" "$rigSession" "$rigSession" > "$rigRecord"
	printf -- '- [ ] rig-a-one\n- [ ] rig-a-two\n' > "$rigList"
}
rigOut="" rigErr="" rigRc=""
## ONE CALL, THEN ITS DRAIN WAITED OUT. The tooling starts the drain of its event-track outbox apart, and
## that drain waits the channel's own window before it posts: a few seconds past the call, after the call's
## own process has gone. So a call is followed by a bounded wait on the outbox itself: a queued record is
## taken once the drain has posted it, and the drain's lock is given back when it ends.
rigCall(){ ## name, then the operation and its arguments
	local callName="$1" callRc=0 callLeft=90
	shift
	rigOut="$rigScn/$callName.out" rigErr="$rigScn/$callName.err"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" "PATH=$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigScn/data" "MDAT_WAIT_REMIND=off" "MDAT_COMMS_READER=off" "MDAT_COLLECT_THREAD=off" "MDAT_TEAM_DATA_COMMIT_THREAD=off" \
		"RIG_SCENARIO=$rigScn" "MDAT_SESSION_ID=$rigSession" "MDAT_SPAWN_SESSION_ID=$rigSession" "MDAT_SPAWN_AGENT=rig-member" \
		python3 -I -B "$rigFixtures/rig-exec.py" --alarm 120 -- bash "$rigSessionFn" "$@" ) > "$rigOut" 2> "$rigErr" < /dev/null || callRc=$?
	rigRc="$callRc"
	while [ "$callLeft" -gt 0 ] ; do
		[ -n "$( ls -d "$rigWs"/.local/agents/event-track-send/*/[0-9]* "$rigWs"/.local/agents/locks/event-track-send-* 2> /dev/null )" ] || return 0
		sleep 1 ; callLeft=$(( callLeft - 1 ))
	done
	return 0
}
## One line of a result, by its own label, as the operation prints it: its value after the label.
rigResult(){ ## label
	LC_ALL=C sed -n "s/^ *$1: //p" "$rigOut" 2> /dev/null | LC_ALL=C sed -n 1p
}
rigFrames(){
	env -i HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_DATA_ROOT="$rigScn/data" \
		bash -c '. "$1" ; AgentsToolsSessionRoutineStackLines "$2"' rig "$rigHere/session/AgentsTools.RoutineStack.include" "$rigSession" 2> /dev/null \
		| LC_ALL=C sed -n 's/^routine-stack: //p' | LC_ALL=C awk 'BEGIN { ORS = "" } { printf "%s%s", ( NR > 1 ? " → " : "" ), $0 }'
}
rigListSum(){ LC_ALL=C cksum < "$rigList" 2> /dev/null ; }
rigOutHolds(){ LC_ALL=C grep -c -F -- "$1" "$rigOut" 2> /dev/null || : ; }

echo "-- 1. a push names the frame's steps, and the step the run starts at --"
rigScene steps
rigCall s-1 --routine-stack --push rig-b.routine.md --reason "the plan comes next"
rigAssert "the move is made"                              "$rigRc:$( rigOutHolds 'OK: --routine-stack push' )" "0:1"
rigAssert "the routine's steps are named, in their order"  "$( rigResult steps )" "rig-b-one, rig-b-two"
rigAssert "and the first of them is the step the run starts at" "$( rigResult 'start at' )" "rig-b-one"
rigAssert "the frames read as stage 2 writes them"        "$( rigFrames )" "rig-a.routine.md:open → rig-b.routine.md:current"

echo "-- 2. a move to a routine names its first step, and a closed one is behind it --"
printf -- '- [ ] rig-a-one\n- [ ] rig-a-two\n- [x] rig-b-one\n- [ ] rig-b-two\n' > "$rigList"
rigCall s-2 --routine-stack --push rig-c.routine.md --reason "then the report"
rigAssert "the move is made"                              "$rigRc:$( rigOutHolds 'OK: --routine-stack push' )" "0:1"
rigAssert "its steps are named"                            "$( rigResult steps )" "rig-c-one, rig-c-two"
rigAssert "and it starts at its first step, which no list has closed" "$( rigResult 'start at' )" "rig-c-one"

echo "-- 3. a rewind starts at that routine's first step, whether or not the list closed it --"
printf -- '- [ ] rig-a-one\n- [ ] rig-a-two\n- [x] rig-b-one\n- [ ] rig-b-two\n- [x] rig-c-one\n- [~] rig-c-two\n' > "$rigList"
rigCall s-3 --routine-stack --rewind --reason "the second step was wrong"
rigAssert "the move is made"                              "$rigRc:$( rigOutHolds 'OK: --routine-stack rewind' )" "0:1"
rigAssert "the run starts at the first step of the frame, closed in the list or not" "$( rigResult 'start at' )" "rig-c-one"
rigAssert "and the frames do not move"                     "$( rigFrames )" "rig-a.routine.md:open → rig-b.routine.md:open → rig-c.routine.md:current"

echo "-- 4. a push starts past a step the list already closed --"
printf -- '- [ ] rig-a-one\n- [ ] rig-a-two\n- [x] rig-b-one\n- [ ] rig-b-two\n- [x] rig-c-one\n- [ ] rig-c-two\n' > "$rigList"
rigCall s-4 --routine-stack --push rig-b.routine.md --reason "back to the plan"
rigAssert "the move is made"                              "$rigRc:$( rigOutHolds 'OK: --routine-stack push' )" "0:1"
rigAssert "and it starts at the frame's first step the list has not closed" "$( rigResult 'start at' )" "rig-b-two"

echo "-- 5. a move does not write the executor's CheckList --"
rigSumBefore="$( rigListSum )"
rigCall s-5 --routine-stack --rewind --reason "run these steps again"
rigAssert "the second rewind is made too"                  "$rigRc:$( rigOutHolds 'OK: --routine-stack rewind' )" "0:1"
rigAssert "the list is byte for byte what it was"           "$( rigListSum )" "$rigSumBefore"
rigAssert "and it still holds the items the spawner seeded" "$( LC_ALL=C grep -c -x -F -e '- [ ] rig-a-two' "$rigList" )" 1

echo "-- 6. the list a move reads is the one the CheckList tool writes, wherever the record is filed --"
rigScene apart
## THE SHAPE ON LIVE: the record is filed under the spawn id, and its session id is another name, so the CheckList
## tool's place is sessions/<session-id>/ and never the record's own folder (147 of 437 records on live). A run that
## joined a session reads the steps stated for all participants, so this scene's routine states them so.
rigApart="apart-session"
mkdir -p "$rigWs/.local/agents/sessions/$rigApart"
printf -- '---\ntype: routine\nexecutors: rig-member\nmaintainers: rig-member\ninvitees: none\nrequires-session-kind: standalone\n---\n# rig-a.routine.md\n\n# Steps\n\n1. **rig-a-one**: All participants do the first thing.\n2. **rig-a-two**: All participants do the second thing.\n' \
	> "$rigTmp/skills/magic-team/rig-a.routine.md"
printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: righost\nworkspace: rigws\nowner: rig-member\nstart-context: spawned\nroutine: rig-a.routine.md\nroutine-stack: rig-a.routine.md:current\nstatus: spawn-started\n---\n' \
	"$rigApart" "$rigSession" > "$rigRecord"
printf -- '- [x] rig-a-one\n- [ ] rig-a-two\n' > "$rigWs/.local/agents/sessions/$rigApart/rig-member.checklist.md"
rigSession="$rigApart"
rigCall x-1 --routine-stack --push rig-a.routine.md --reason "the same routine again, from where the list stands"
rigAssert "the move is made"                              "$rigRc:$( rigOutHolds 'OK: --routine-stack push' )" "0:1"
rigAssert "and it starts past the step the member's own list has closed" "$( rigResult 'start at' )" "rig-a-two"


## thread, and that post is queued and drained by a process started apart, at most one message every seven
## seconds: it outlives the call by a few seconds. A runner that watches for left processes cannot tell that
## from a leak, so the check waits them out, bounded, and asserts that it did.
rigSettle(){ ## -- rc 0 once no process of this rig is left, rc 1 at the bound
	local settleLeft=90
	while [ "$settleLeft" -gt 0 ] ; do
		[ "$( ps -A -ww -o args= 2>/dev/null | LC_ALL=C awk -v rig="$rigTmp" 'index( $0, rig ) && !/awk/ { n++ } END { print n + 0 }' )" != "0" ] || return 0
		sleep 1 ; settleLeft=$(( settleLeft - 1 ))
	done
	return 1
}
if rigSettle ; then rigSettled="clean" ; else rigSettled="left-running" ; fi
rigAssert "no process of this check is left running when it ends" "$rigSettled" clean

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE STACK MOVE STEPS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	printf 'ROUTINE_STACK_MOVE_STEPS: FAILED (%d compared, %d assertion(s))\n' "$(( rigPassCount + rigFailCount ))" "$rigFailCount"
	exit 1
fi
printf 'ROUTINE_STACK_MOVE_STEPS: OK (%d assertions, offline)\n' "$rigPassCount"
