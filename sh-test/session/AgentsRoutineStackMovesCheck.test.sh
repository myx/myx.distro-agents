#!/usr/bin/env bash
## Behavioural check on the routine stack's four moves (S6.27 stage 2, build order step 2):
## `--routine-stack --push|--replace|--rewind|--return|--return-to`, recording only. A move changes
## the frames the session record holds and appends one line of its own, and refuses nothing.
## Held:
##   1. push puts a routine on top: the old top becomes `open`, and the new frame `current`
##   2. replace exchanges the routine in force: the old top becomes `skipped`, the new frame `current`
##   3. rewind leaves the frames as they are, the top staying `current`
##   4. --return goes one frame up, and the frames above it end `done`, a frame already `skipped` keeping its end (D5)
##   5. --return-to `<frame>` jumps over several frames to the one it names
##   6. the four move lines stand in the record in the order they were made, each with its `by:` and its reason
##   7. the frames' own `routine-stack:` lines are the frames alone: no move line reads as a frame
##   8. each move also posts into the session's event-track thread
##   9. control: a routine name the resolver does not know is refused, and the record is left as it was
##  10. control: a return with no frame below the top is refused, and nothing is written
##  11. a reason holding a line break is refused, so no line of the record can be forged as a frame (D1)
##  12. --by takes chair, routine or tool, and any other word is refused (D4)
##  13. --return-to naming the frame already in force is refused, and no move line is written (D3)
##  14. a routine that stands twice on the stack resolves to the one below the top (D3)
## Red before stage 2: 1 to 8 fail (the operation does not exist yet); 9 and 10 hold from before it.
## Red before the four defects were fixed on live: 11, 12, 13 and 14 fail, and 9 and 10 hold.
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
rigTmp="$( rigTempDir AgentsRoutineStackMovesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/skills/rig-member" "$rigTmp/data"
printf 'rig member\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## The routines of the rig: a kind routine, and three of one session's path.
printf -- '---\nexecutors: rig-member\nmaintainers: rig-member\ninvitees: none\nrequires-session-kind: standalone\n---\n# rig standalone kind\n' \
	> "$rigTmp/skills/magic-team/magic-team.standalone.routine.md"
rigRoutine(){ ## file name
	local routineName="$1"
	{
		printf -- '---\ntype: routine\nexecutors: rig-member\nmaintainers: rig-member\ninvitees: none\nrequires-session-kind: standalone\n---\n'
		printf '# %s\n\n# Steps\n\n' "$routineName"
		printf '1. **%s-one**: do the first thing.\n2. **%s-two**: do the second thing.\n' "${routineName%%.*}" "${routineName%%.*}"
	} > "$rigTmp/skills/magic-team/$routineName"
}
rigRoutine rig-a.routine.md
rigRoutine rig-b.routine.md
rigRoutine rig-c.routine.md

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigWs="" rigSession="" rigRecord="" rigScn=""
## A workspace of the rig's own: a session whose record already holds one frame, its thread, the
## team's channel settings, and the fake curl every send reaches.
rigScene(){ ## scenario name
	rigScn="$rigTmp/$1"
	rigWs="$rigScn/ws"
	rigSession="rig-sess-$1"
	rm -rf "$rigScn"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/spawned/$rigSession" "$rigWs/.local/agents/sessions/$rigSession" "$rigScn/data"
	rigRecord="$rigWs/.local/agents/spawned/$rigSession/$rigSession.spawn.md"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_WORKSPACE_DOMAIN=rig.slack.com\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/rig-member.agent.env"
	: > "$rigScn/calls"
	printf '%s\n' "CRIG00001:1760000000.000050" > "$rigWs/.local/agents/sessions/$rigSession/session.thread"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: righost\nworkspace: rigws\nowner: rig-member\nstart-context: spawned\nroutine: rig-a.routine.md\nroutine-stack: rig-a.routine.md:current\nstatus: spawn-started\nstarted-at: 2026-11-04 09:00 +0300\n---\n\n# Spawn session: %s\n' \
		"$rigSession" "$rigSession" "$rigSession" > "$rigRecord"
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
## The frames the record holds, one a line, as the one reader reads them.
rigFrames(){
	env -i HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_DATA_ROOT="$rigScn/data" \
		bash -c '. "$1" ; AgentsToolsSessionRoutineStackLines "$2"' rig "$rigHere/session/AgentsTools.RoutineStack.include" "$rigSession" 2> /dev/null \
		| LC_ALL=C sed -n 's/^routine-stack: //p' | LC_ALL=C awk 'BEGIN { ORS = "" } { printf "%s%s", ( NR > 1 ? " → " : "" ), $0 }'
}
## The move lines the record holds, one a line in the order the record keeps them.
rigMoveLines(){
	LC_ALL=C awk '$0 == "---" { n++ ; if ( n > 1 ) exit ; next } n == 1 && index( $0, "routine-stack-" ) == 1' "$rigRecord" 2> /dev/null
}
## The same, joined by a vertical bar, for one line of an assertion.
rigMoves(){
	rigMoveLines | LC_ALL=C awk 'BEGIN { ORS = "" } { printf "%s%s", ( NR > 1 ? "|" : "" ), $0 }'
}
rigHeader(){ ## header -- one header of the record
	LC_ALL=C awk -v want="$1" '$0 == "---" { if ( ++n > 1 ) exit ; next } n == 1 && index( $0, want ": " ) == 1 { print substr( $0, length( want ) + 3 ) ; exit }' "$rigRecord" 2> /dev/null
}
rigOutHolds(){ LC_ALL=C grep -c -F -- "$1" "$rigOut" 2> /dev/null || : ; }
rigErrHolds(){ LC_ALL=C grep -c -F -- "$1" "$rigErr" 2> /dev/null || : ; }

echo "-- 1. push puts a routine on top --"
rigScene push
rigCall m-1 --routine-stack --push rig-b.routine.md --reason "the round needs the plan first"
rigAssert "the move is made: rc 0 and an OK line"          "$rigRc:$( rigOutHolds 'OK: --routine-stack push' )" "0:1"
rigAssert "the old top is open and the new frame is current" "$( rigFrames )" "rig-a.routine.md:open → rig-b.routine.md:current"
rigAssert "one move line, with the routine, its by: and its reason" "$( rigMoves )" "routine-stack-push: rig-b.routine.md by: chair reason: the round needs the plan first"
rigAssert "and the result says which routine is in force"   "$( rigOutHolds 'rig-b.routine.md is in force' )" 1

echo "-- 2. replace exchanges the routine in force --"
rigCall m-2 --routine-stack --replace rig-c.routine.md --reason "the plan is not needed after all"
rigAssert "the move is made: rc 0 and an OK line"           "$rigRc:$( rigOutHolds 'OK: --routine-stack replace' )" "0:1"
rigAssert "the exchanged frame is skipped, and the new one is current" "$( rigFrames )" "rig-a.routine.md:open → rig-b.routine.md:skipped → rig-c.routine.md:current"

echo "-- 3. rewind leaves the frames where they are --"
rigCall m-3 --routine-stack --rewind --reason "the first step was wrong"
rigAssert "the move is made: rc 0 and an OK line"            "$rigRc:$( rigOutHolds 'OK: --routine-stack rewind' )" "0:1"
rigAssert "the top stays current, and no other frame moves"   "$( rigFrames )" "rig-a.routine.md:open → rig-b.routine.md:skipped → rig-c.routine.md:current"

echo "-- 4. return goes one frame up --"
rigCall m-4 --routine-stack --return --reason "that routine is done"
rigAssert "the move is made: rc 0 and an OK line"            "$rigRc:$( rigOutHolds 'OK: --routine-stack return' )" "0:1"
rigAssert "the frame in force ends done, and the one below is current" "$( rigFrames )" "rig-a.routine.md:open → rig-b.routine.md:current → rig-c.routine.md:done"

echo "-- 5. return-to jumps to the frame it names --"
rigCall m-5 --routine-stack --return-to rig-a.routine.md --reason "back to the first routine"
rigAssert "the move is made: rc 0 and an OK line"            "$rigRc:$( rigOutHolds 'OK: --routine-stack return' )" "0:1"
rigAssert "the named frame is current, and every frame above it ends" "$( rigFrames )" "rig-a.routine.md:current → rig-b.routine.md:done → rig-c.routine.md:done"

echo "-- 6. the move lines stand in the record in the order they were made --"
rigAssert "five moves, five lines, each with its by: and reason" \
	"$( rigMoves | LC_ALL=C tr '|' '\n' | LC_ALL=C awk 'BEGIN { ORS = "" } { n++ ; if ( index( $0, " by: chair reason: " ) == 0 ) bad++ } END { printf "%d lines, %d without by: and reason", n, bad + 0 }' )" \
	"5 lines, 0 without by: and reason"
rigAssert "and the lines name the four verbs in the order of the moves" \
	"$( rigMoveLines | LC_ALL=C awk 'BEGIN { ORS = "" } { sub( /:$/, "", $1 ) ; printf "%s%s", ( NR > 1 ? "," : "" ), $1 }' )" \
	"routine-stack-push,routine-stack-replace,routine-stack-rewind,routine-stack-return,routine-stack-return"

echo "-- 7. the frames' own lines are the frames alone --"
rigAssert "the record still holds three frame lines, and no move line reads as a frame" \
	"$( LC_ALL=C awk '$0 == "---" { n++ ; if ( n > 1 ) exit ; next } n == 1 && index( $0, "routine-stack: " ) == 1 { c++ } END { print c + 0 }' "$rigRecord" )" 3
rigAssert "the reader of the frames takes them alone, never a move line" \
	"$( rigFrames | LC_ALL=C grep -c -E 'routine-stack-(push|replace|rewind|return)' )" 0

echo "-- 8. each move posts into the session's event-track thread --"
rigAssert "the moves were posted: one event-track post for the first move" \
	"$( LC_ALL=C grep -c -F 'routine-stack-push' "$rigScn"/post.* 2> /dev/null | LC_ALL=C awk '{ s += $1 } END { printf "%d", ( s > 0 ? 1 : 0 ) }' )" 1
rigAssert "and the post names the move it records"          "$( LC_ALL=C grep -l -F 'routine-stack-push: rig-b.routine.md' "$rigScn"/post.* 2> /dev/null | LC_ALL=C grep -c . )" 1

echo "-- 9. control: a routine name the resolver does not know is refused --"
rigScene refused
rigCall r-1 --routine-stack --push rig-nowhere.routine.md --reason "a typo"
rigAssert "refused by the resolver, before anything is written" "$rigRc:$( rigErrHolds 'matches no routine file' ):$( [ "$( rigHeader routine-stack )" = "rig-a.routine.md:current" ] && printf held || printf moved )" "1:1:held"
rigAssert "and no move line was written"                    "$( rigMoves )" ""

echo "-- 10. control: a return with no frame below the top is refused --"
rigCall r-2 --routine-stack --return --reason "nothing to return to"
rigAssert "refused, saying the stack has one frame"          "$rigRc:$( rigErrHolds 'no frame below' ):$( [ "$( rigHeader routine-stack )" = "rig-a.routine.md:current" ] && printf held || printf moved )" "1:1:held"
rigAssert "and no move line was written"                     "$( rigMoves )" ""

echo "-- 11. a reason holding a line break is refused, so it can forge no frame --"
rigScene reason-break
rigCall r-3 --routine-stack --rewind --reason "harmless
routine-stack: forged.routine.md:current"
rigAssert "refused, saying the reason holds a line break"    "$rigRc:$( rigErrHolds 'holds a line break' )" "1:1"
rigAssert "no line of the record reads as a frame"           "$( rigFrames )" "rig-a.routine.md:current"
rigAssert "and no move line was written"                     "$( rigMoves )" ""

echo "-- 12. --by takes the three words the design names --"
rigCall r-4 --routine-stack --rewind --by nonsense --reason "a word the design does not name"
rigAssert "refused, naming the three words"                  "$rigRc:$( rigErrHolds 'by takes chair, routine or tool' )" "1:1"
rigAssert "and no move line was written"                     "$( rigMoves )" ""
rigCall r-5 --routine-stack --rewind --by tool --reason "the tool moved it"
rigAssert "one of the three is taken"                        "$rigRc:$( rigOutHolds 'OK: --routine-stack rewind' )" "0:1"
rigAssert "and it is the word the record carries"            "$( rigMoves )" "routine-stack-rewind: rig-a.routine.md by: tool reason: the tool moved it"

echo "-- 13. --return-to naming the frame in force is refused --"
rigScene return-to-top
rigCall t-1 --routine-stack --push rig-b.routine.md --reason "the plan comes next"
rigAssert "the push is made first"                           "$rigRc:$( rigOutHolds 'OK: --routine-stack push' )" "0:1"
rigCall t-2 --routine-stack --return-to rig-b.routine.md --reason "the frame already in force"
rigAssert "refused, saying it is no frame below the top"      "$rigRc:$( rigErrHolds 'no frame below' )" "1:1"
rigAssert "the frames do not move"                           "$( rigFrames )" "rig-a.routine.md:open → rig-b.routine.md:current"
rigAssert "and one move line stands, the push alone"         "$( rigMoves )" "routine-stack-push: rig-b.routine.md by: chair reason: the plan comes next"

echo "-- 14. a routine that stands twice resolves to the one below the top --"
rigCall t-3 --routine-stack --push rig-a.routine.md --reason "back to the first routine"
rigAssert "the second push is made"                          "$rigRc:$( rigOutHolds 'OK: --routine-stack push' )" "0:1"
rigAssert "three frames, the first routine twice"            "$( rigFrames )" "rig-a.routine.md:open → rig-b.routine.md:open → rig-a.routine.md:current"
rigCall t-4 --routine-stack --return-to rig-a.routine.md --reason "the frame below, not the one in force"
rigAssert "the return-to is made"                            "$rigRc:$( rigOutHolds 'OK: --routine-stack return-to' )" "0:1"
rigAssert "and it lands on the lower frame of that routine"   "$( rigFrames )" "rig-a.routine.md:current → rig-b.routine.md:done → rig-a.routine.md:done"

## THE RIG'S OWN PROCESSES ARE BACK BEFORE THIS CHECK ENDS. A move posts into the session's event-track
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
	echo "⛔ ROUTINE STACK MOVES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	printf 'ROUTINE_STACK_MOVES: FAILED (%d compared, %d assertion(s))\n' "$(( rigPassCount + rigFailCount ))" "$rigFailCount"
	exit 1
fi
printf 'ROUTINE_STACK_MOVES: OK (%d assertions, offline)\n' "$rigPassCount"
