#!/usr/bin/env bash
## Behavioural check on what an answer given through the escalation answer operation leaves
## in the question's thread: ONE reply, which says what became of the answer -- what is
## granted, that nothing is, or that the answer is not applied and who the request goes to
## now. The seen fault: an approver who did not hold what it approved got the tooling's reply
## that its answer is not applied, and two seconds later its own `Answered by <member>:
## allow-session`, posted whatever became of the answer, so one thread said both. Covers an
## allow that is applied, a deny, a readback confirmed, an allow that goes up to a holder
## running in the session, and one that goes up to the human-owner. Offline: a Slack-shaped
## fake curl is first on PATH, a ps that lists the rig's own runs only is beside it, and
## everything runs in a workspace under this check's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTools"
for rigNeed in magic-tester magic-developer magic-coordinator ; do
	[ -r "${MDAT_SKILLSET_ROOT:-}/$rigNeed/$rigNeed.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigNeed"
done

rigTmp="$( mktemp -d -t AgentsEscalationOneReplyCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## THE RIG'S OWN PROCESS LIST: a spawn is found running by its spawn id in the host's process
## list, so the ps first on PATH answers the whole-host listing from the rig's own list and
## hands every other call to the real ps (as AgentsPermissionHoldsCheck does).
RIG_PS_REAL="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
RIG_PS_LIST="$rigTmp/ps.list"
export RIG_PS_REAL RIG_PS_LIST
: > "$RIG_PS_LIST"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "$RIG_PS_LIST" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "$RIG_PS_LIST" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "$RIG_PS_REAL" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
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
rigHas(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in *"$2"*) printf yes ;; *) printf no ;; esac
}

## The rig workspace: a coworking session rig-cow with the coordinator, the developer and the
## tester. The developer holds DEV by a standing row and runs now; the coordinator holds nothing.
rigWs="$rigTmp/ws"
rigData="$rigWs/DATA"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig-cow" "$rigWs/.local/agents/sessions/rig-cow" "$rigData/board/running" "$rigWs/DEV" "$rigWs/ELSE"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'magic-developer:ws:workspace:Edit(/%s/DEV/**)\n' "$rigWs" > "$rigWs/.local/agents/permissions.registry"
rigHost="$( hostname -s 2>/dev/null || echo unknown )"
rigSpawnRecord(){ ## spawn id, owner, parent session id
	printf -- '---\nsession-id: rig-cow\nspawn-id: %s\n%shost: %s\nowner: %s\nstatus: spawn-started\n---\n\n# Spawn session\n' \
		"$1" "${3:+parent-session-id: $3$'\n'}" "$rigHost" "$2" > "$rigWs/.local/agents/spawned/rig-cow/$1.md"
}
rigSpawnRecord rig-coord magic-coordinator ""
rigSpawnRecord rig-dev magic-developer rig-coord
rigSpawnRecord rig-tester magic-tester rig-coord
printf '%s rig-run --session-id %s\n' "$(( 900000 + RANDOM ))" rig-dev >> "$RIG_PS_LIST"
## The session's own thread, which is not the thread any question below is asked in.
rigSessionThread="1700000000.000900"
printf 'CRIG00001:%s\n' "$rigSessionThread" > "$rigWs/.local/agents/sessions/rig-cow/session.thread"
RIG_CURL_LOG="$rigTmp/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"

RIG_OP_AGENT=""
RIG_OP_SESSION=""
rigOp(){
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID \
		${RIG_OP_SESSION:+MDAT_SPAWN_SESSION_ID="$RIG_OP_SESSION"} ${RIG_OP_AGENT:+MDAT_SPAWN_AGENT="$RIG_OP_AGENT"} \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" bash "$rigTools" "$@" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err"
}
rigRefusal(){ ## member, session, tool, target
	rigOp --intern-op-permission-refusal-log "$1" --session-id "$2" --tool "$3" --target "$4" --reason rig
	LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/op.out" | head -1
}
rigField(){ ## file, field
	LC_ALL=C awk -F': ' -v wantField="$2" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit ; }' "$1" 2>/dev/null
}
## Each question has a thread of its own, named by its number: 1700000000.0001<n>.
rigAskNo=0
rigThread=""
rigAsk(){ ## kind, addressee, refusal id (may be empty) -> rigPend, rigThread
	rigAskNo=$(( rigAskNo + 1 ))
	rigThread="1700000000.0001$( printf '%02d' "$rigAskNo" )"
	rigPend="$( printf '# Ask\n\nMay I?\n' | ( cd "$rigWs" && env -u MDAT_SPAWN_AGENT MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" bash "$rigTools" \
		--intern-op-pending-reply-open magic-tester --to CRIG00001 --session-id rig-tester --kind "$1" --address-to "$2" \
		${3:+--refusal-id "$3"} --channel CRIG00001 --question-ts "$rigThread" --thread-ts "$rigThread" --addressees URIGOWNER --asking-accounts ' URIGSELF1 ' 2>/dev/null ) )"
	[ -n "$rigPend" ] || rigRefuse "no escalation record could be opened"
}
## The posts made since a mark, as their numbers: the fake curl numbers each post it takes.
rigPostMark=0
rigMark(){
	rigPostMark="$( cat "$rigTmp/posts" 2>/dev/null || printf 0 )"
}
## How many of the posts made since the mark hold every text given.
rigNew(){ ## fixed text...
	local newNo newText newAll newCount=0 newLast
	newLast="$( cat "$rigTmp/posts" 2>/dev/null || printf 0 )"
	newNo="$rigPostMark"
	while [ "$newNo" -lt "$newLast" ] ; do
		newNo=$(( newNo + 1 ))
		[ -f "$rigTmp/post.$newNo" ] || continue
		newAll=1
		for newText in "$@" ; do LC_ALL=C grep -q -F -- "$newText" "$rigTmp/post.$newNo" || { newAll="" ; break ; } ; done
		[ -z "$newAll" ] || newCount=$(( newCount + 1 ))
	done
	printf '%s' "$newCount"
}
rigInThread(){ ## thread ts -> the JSON field that puts a post in that thread
	printf '"thread_ts":"%s"' "$1"
}
rigAnswer(){ ## answering member, its session, operation, verdict
	rigMark
	RIG_OP_AGENT="$1" RIG_OP_SESSION="$2" rigOp "$3" "$1" "$rigPend" "$4"
}

echo "-- an allow that is applied: one reply, which says what is granted --"
rigIdA="$( rigRefusal magic-tester rig-tester Write "$rigWs/DEV/a.txt" )"
[ -n "$rigIdA" ] || rigRefuse "no refusal could be recorded"
rigAsk permission magic-developer "$rigIdA"
rigAnswer magic-developer rig-dev --member-escalation-answer allow-session
[ "$( rigHas "$rigTmp/op.out" "ESCALATION: $rigPend answered" )" = yes ] || rigRefuse "the holder's answer was not applied, so no row below would be measured: $( LC_ALL=C grep -m1 ERROR "$rigTmp/op.err" )"
rigAssert "the question's thread gets one reply"          "$( rigNew "$( rigInThread "$rigThread" )" )" 1
rigAssert "it says what was read and what is granted"     "$( rigNew "$( rigInThread "$rigThread" )" 'Read: `allow-session` by magic-developer. Granted: Write on ' ' to magic-tester, for this session.' )" 1
rigAssert "and nothing else was posted for that answer"   "$( rigNew '"channel"' )" 1

echo "-- a deny: one reply, which says nothing is granted --"
rigIdD="$( rigRefusal magic-tester rig-tester Write "$rigWs/DEV/d.txt" )"
rigAsk permission magic-developer "$rigIdD"
rigAnswer magic-developer rig-dev --member-escalation-answer deny
rigAssert "the question's thread gets one reply"          "$( rigNew "$( rigInThread "$rigThread" )" )" 1
rigAssert "it says nothing is granted"                    "$( rigNew "$( rigInThread "$rigThread" )" 'Read: `deny` by magic-developer. Nothing is granted to magic-tester.' )" 1
rigAssert "and nothing else was posted for that answer"   "$( rigNew '"channel"' )" 1

echo "-- a readback confirmed: one reply --"
rigAsk readback magic-developer ""
rigAnswer magic-developer rig-dev --member-escalation-answer yes
rigAssert "the answer is applied"                         "$( rigHas "$rigTmp/op.out" "ESCALATION: $rigPend answered" )" yes
rigAssert "the question's thread gets one reply, which says what was read" "$( rigNew "$( rigInThread "$rigThread" )" ):$( rigNew "$( rigInThread "$rigThread" )" 'Read: `yes` by magic-developer.' )" "1:1"
rigAssert "and nothing else was posted for that answer"   "$( rigNew '"channel"' )" 1

echo "-- an allow that is NOT applied, going up to a holder in the session: one reply there, which says so --"
rigIdR="$( rigRefusal magic-tester rig-tester Write "$rigWs/DEV/r.txt" )"
rigAsk permission magic-coordinator "$rigIdR"
rigAnswer magic-coordinator rig-coord --magic-escalation-answer allow-session
[ "$( rigHas "$rigTmp/op.out" "ESCALATION: $rigPend rerouted" )" = yes ] || rigRefuse "the coordinator's allow did not go up the chain, so no row below would be measured: $( LC_ALL=C grep -m1 ERROR "$rigTmp/op.err" )"
rigAssert "the question's thread gets one reply"          "$( rigNew "$( rigInThread "$rigThread" )" )" 1
rigAssert "it says the answer is not applied, why, and who the question goes to now" \
	"$( rigNew "$( rigInThread "$rigThread" )" 'Read: `allow-session` by magic-coordinator, and it is not applied: magic-coordinator does not hold Write on ' 'Nothing is granted yet. The question now goes to magic-developer, and stays open.' )" 1
rigAssert "no post says that answer as given, or as granted" "$( rigNew 'Answered by' ):$( rigNew 'Granted' )" "0:0"
rigAssert "the one it goes to is told in the session's own thread, once" "$( rigNew "$( rigInThread "$rigSessionThread" )" ):$( rigNew "$( rigInThread "$rigSessionThread" )" 'is now yours to answer, magic-developer.' )" "1:1"
rigAssert "and those two are all that was posted"         "$( rigNew '"channel"' )" 2
rigAssert "the record is open, and nothing is granted"    "$( rigField "$rigWs/.local/agents/pending/$rigPend.md" status ):$( LC_ALL=C grep -c -F -- "$rigIdR" "$rigWs/.local/agents/sessions/rig-tester/grants" 2>/dev/null )" "reply-pending:0"
## The same answer given again says nothing a second time in the question's thread.
rigAnswer magic-coordinator rig-coord --magic-escalation-answer allow-session
rigAssert "given again, the same answer gets no second reply in the question's thread" "$( rigNew "$( rigInThread "$rigThread" )" ):$( rigNew 'Answered by' )" "0:0"

echo "-- an allow that is NOT applied, going up to the human-owner: one reply there, which says so --"
rigIdE="$( rigRefusal magic-tester rig-tester Write "$rigWs/ELSE/e.txt" )"
rigAsk permission magic-coordinator "$rigIdE"
rigAnswer magic-coordinator rig-coord --magic-escalation-answer allow-once
[ "$( rigHas "$rigTmp/op.out" "ESCALATION: $rigPend rerouted" )" = yes ] || rigRefuse "the coordinator's allow did not go up the chain, so no row below would be measured: $( LC_ALL=C grep -m1 ERROR "$rigTmp/op.err" )"
rigAssert "the question's thread gets one reply"          "$( rigNew "$( rigInThread "$rigThread" )" )" 1
rigAssert "it says the answer is not applied, and that the question goes to the human-owner" \
	"$( rigNew "$( rigInThread "$rigThread" )" 'Read: `allow-once` by magic-coordinator, and it is not applied: ' 'The question now goes to human-owner, and stays open.' )" 1
rigAssert "no post says that answer as given, or as granted" "$( rigNew 'Answered by' ):$( rigNew 'Granted' )" "0:0"
rigAssert "the request itself is posted to the human-owner, a message of its own" "$( rigNew 'Forwarded by magic-coordinator.' ):$( rigNew 'Forwarded by magic-coordinator.' '"thread_ts"' )" "1:0"
rigAssert "and those two are all that was posted"         "$( rigNew '"channel"' )" 2

rigMark ; rigPostMark=0
rigAssert "in the whole run no post says Answered by"     "$( rigNew 'Answered by' )" 0
rigAssert "no request left this box"                      "$( LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ESCALATION ONE REPLY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: one answer gets more than one reply in its question's thread, or a reply that says it as given whatever became of it" >&2
	echo "  fix:  repair --member-escalation-answer and AgentsToolsEscalationConfirm in sh-lib/AgentsTools.MemberEscalation.include -- never the assertion" >&2
	exit 1
fi
printf 'ESCALATION_ONE_REPLY: OK (%d assertions, offline)\n' "$rigPassCount"
