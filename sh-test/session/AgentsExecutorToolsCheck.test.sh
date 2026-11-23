#!/usr/bin/env bash
## Behavioural check on the executor's own front, sh-scripts/AgentExecutorTools.fn.sh (sketch section 10.7; the design is
## magic-developer's inbox item inquiry-20261123T0525Z-executor-front-design.md). Held, stage by stage, over a rig workspace:
##   1. THE FOUR MOVES: the front serves --set-session-topic, --set-session-chapter, --get-uninvited-participants and
##      --list-session-runs; each old home keeps an arm that says where the name went and reaches the operation; the four rows
##      stand in the front table and in its stubs; and ThisSession still serves its own three words through the new front.
##   2. --executor-queue: one block per participant, its open and in-progress items and not its closed ones, whether it has a run in
##      the session, and each refusal the design lists.
##   3. --executor-checklist-append: the chair's items land in the participant's list, marked as the chair's, and each refusal the
##      design lists.
##   4. --executor-resume: a stopped session's executor is resumed, appending to its queue resumes it, and each refusal the design lists.
## Offline: a Slack-shaped fake curl is first on PATH, every tree is this rig's own, and no model CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigFront="$rigPackage/sh-scripts/AgentExecutorTools.fn.sh"
rigSessionTool="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
rigDispatcher="$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh"
rigHarness="$rigPackage/sh-lib/harness/AgentsUniversalHarness.sh"
rigTable="$rigPackage/sh-lib/harness/AgentsContext.FrontTable.include"
rigStore="$rigPackage/sh-lib/session/AgentsTools.SessionStore.include"
unset MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SESSION_THREAD MDAT_SPAWN_AGENT MDAT_SPAWN_SANDBOX_ROOT CLAUDE_CODE_SESSION_ID harnessSessionId harnessAgent
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigSessionTool" "$rigDispatcher" "$rigHarness" "$rigTable" "$rigStore" "$rigFixtures/session-chat.curl.stub.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigFixtures/rig-temp.include.sh" || exit 1
. "$rigFixtures/rig-control-threads.include.sh" || exit 1
. "$rigFixtures/rig-owner-writes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsExecutorToolsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills" || exit 1
for rigMember in rig-chair rig-part rig-other ; do
	mkdir -p "$rigTmp/skills/$rigMember" || exit 1
	printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
	printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
done
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH" ; export PATH

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigScn="" rigWs="" rigSession="" rigOut="" rigErr="" rigRc=0 rigCallNo=0
## A workspace of the rig's own: a session folder made by the session store's own writer, a team env, and the session's thread.
rigScene(){ ## scenario name
	rigScn="$rigTmp/$1"
	rigWs="$rigScn/ws"
	rigSession="rig-sess-$1"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigScn/data" || exit 1
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/rig-chair.agent.env"
	rigWs="$rigWs" rigData="$rigScn/data" rigSkills="$rigTmp/skills" rigOrigin="$rigOrigin" rigAs=rig-chair \
		rigOwnerSessionThreadSet "$rigSession" 'CRIG00001:1760000000.000050' || exit 1
}
## One spawn record of this session, through the session store's own writer: run id, owner, status, the extra header lines.
rigRecord(){ ## run id, owner, status, the extra header lines
	{
		printf '%s\n' '---' "session-id: $rigSession" "spawn-id: $1" "owner: $2" "status: ${3:-spawn-started}"
		[ -z "${4:-}" ] || printf '%s\n' "$4"
		printf '%s\n' '---' ''
	} | rigWs="$rigWs" rigData="$rigScn/data" rigSkills="$rigTmp/skills" rigOrigin="$rigOrigin" rigAs=rig-chair rigOwnerSpawnPut "$1" || exit 1
	[ -f "$rigWs/.local/agents/spawned/$1/$1.spawn.md" ] || [ -n "$( find "$rigWs/.local/agents/spawned" -name "$1.spawn.md" 2> /dev/null )" ] || rigRefuse "the session store wrote no record for $1"
}
## A member's queue, written through the CheckList tool itself: three items, pending, under way and done.
rigQueue(){ ## member
	local queueRc=0
	( cd "$rigWs" && printf '%s' '{"todos":[{"content":"chair reads the queue","status":"pending","activeForm":"reading the queue"},{"content":"an item under way","status":"in_progress","activeForm":"working the item"},{"content":"an item already done","status":"completed","activeForm":"done"}]}' | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigScn/data" MDAT_SPAWN_AGENT="$1" MDAT_SESSION_ID="$rigSession" \
		MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_WAIT_REMIND=off RIG_SCENARIO="$rigScn" \
		python3 -I -B "$rigFixtures/rig-exec.py" --alarm 60 -- bash "$rigHarness" --intern-tool CheckList ) > /dev/null 2>&1 || queueRc=$?
	[ "$queueRc" = 0 ] || rigRefuse "the queue of $1 could not be written by the CheckList tool"
	[ -s "$( rigQueueFile "$1" )" ] || rigRefuse "the CheckList tool wrote no queue for $1"
}
## One call of a tool file, made as the member and session named: stdout in rigOut, stderr in rigErr, the status in rigRc.
rigCall(){ ## script, member, session, then the arguments
	local callScript="$1" callAs="$2" callSession="$3" ; shift 3
	local callRc=0
	rigCallNo=$(( rigCallNo + 1 ))
	rigOut="$rigTmp/call-$rigCallNo.out" rigErr="$rigTmp/call-$rigCallNo.err"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigScn/data" MDAT_SPAWN_AGENT="$callAs" MDAT_SESSION_ID="$callSession" \
		MDAT_SPAWN_SESSION_ID="$callSession" MDAT_WAIT_REMIND=off RIG_SCENARIO="$rigScn" \
		python3 -I -B "$rigFixtures/rig-exec.py" --alarm 60 -- bash "$callScript" "$@" ) > "$rigOut" 2> "$rigErr" < /dev/null || callRc=$?
	rigRc="$callRc"
}
## One call of the harness tool ThisSession, its argument object on standard input, as the run of the session named.
rigThisSession(){ ## member, session, the argument object
	local callRc=0
	rigCallNo=$(( rigCallNo + 1 ))
	rigOut="$rigTmp/this-session-$rigCallNo.out" rigErr="$rigTmp/this-session-$rigCallNo.err"
	( cd "$rigWs" && printf '%s' "$3" | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigScn/data" MDAT_SPAWN_AGENT="$1" MDAT_SESSION_ID="$2" \
		MDAT_SPAWN_SESSION_ID="$2" MDAT_WAIT_REMIND=off RIG_SCENARIO="$rigScn" \
		python3 -I -B "$rigFixtures/rig-exec.py" --alarm 120 -- bash "$rigHarness" --intern-tool ThisSession ) > "$rigOut" 2> "$rigErr" < /dev/null || callRc=$?
	rigRc="$callRc"
}
rigSaid(){ ## fixed text -- how many lines of stdout and stderr together hold it
	LC_ALL=C grep -c -F -- "$1" "$rigOut" "$rigErr" 2> /dev/null | LC_ALL=C awk -F: '{ n += $NF ; } END { print n + 0 ; }'
}
rigQueueFile(){ ## member -- the file the CheckList tool keeps that member's list in
	local queueOut=""
	MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" . "$rigPackage/sh-lib/session/AgentsTools.CheckListSeed.include"
	MMDAPP="$rigWs" AgentsSessionChecklistFileInto queueOut "$rigSession" "$1" || return 1
	printf '%s' "$queueOut"
}

echo "-- 1. the four moves: the front serves them, and each old home says where its name went --"
rigScene moves
rigRecord "$rigSession" rig-chair spawn-started "participants: rig-chair rig-part rig-other
start-context: spawned"
rigRecord run-part rig-part spawn-started ''
rigAssert "the front is there" "$( [ -f "$rigFront" ] && printf yes || printf no )" yes
if [ -f "$rigFront" ] ; then
	rigCall "$rigFront" rig-chair "$rigSession" --get-uninvited-participants
	rigAssert "the front's --get-uninvited-participants answers, and is no invalid option" \
		"$rigRc:$( rigSaid 'invalid option' ):$( LC_ALL=C grep -c -x -F 'rig-other' "$rigOut" )" "0:0:1"
	rigCall "$rigFront" rig-chair "$rigSession" --set-session-topic 'rig topic'
	rigAssert "the front's --set-session-topic sets the session's title" \
		"$rigRc:$( LC_ALL=C grep -c -x -F 'session-comment: rig topic' "$rigWs/.local/agents/spawned/$rigSession/$rigSession.spawn.md" )" "0:1"
	rigCall "$rigFront" rig-chair "$rigSession" --set-session-chapter 'rig chapter'
	rigAssert "the front's --set-session-chapter keeps the chapter" \
		"$rigRc:$( LC_ALL=C grep -c -x -F 'rig chapter' "$rigWs/.local/agents/sessions/$rigSession/chapter" 2> /dev/null || : )" "0:1"
	rigCall "$rigFront" rig-chair "$rigSession" --list-session-runs
	rigAssert "the front's --list-session-runs lists the session, and is no invalid option" \
		"$rigRc:$( rigSaid 'invalid option' ):$( LC_ALL=C awk -F'\t' -v want="$rigSession" '$1 == "session" && $2 == want { n++ ; } END { print n + 0 ; }' "$rigOut" )" "0:0:1"
	rigCall "$rigFront" rig-chair "$rigSession" --rig-no-such-operation
	rigAssert "control: a name the front has not is its invalid option" \
		"$( rigSaid 'AgentExecutorTools: ⛔ ERROR: invalid option: --rig-no-such-operation' )" 1
fi
rigCall "$rigSessionTool" rig-chair "$rigSession" --get-uninvited-participants
rigAssert "the old home of --get-uninvited-participants says where it went, and still answers" \
	"$rigRc:$( rigSaid 'DistroAgentsSession: --get-uninvited-participants moved to AgentExecutorTools.fn.sh --get-uninvited-participants' ):$( LC_ALL=C grep -c -x -F 'rig-other' "$rigOut" )" "0:1:1"
rigCall "$rigSessionTool" rig-chair "$rigSession" --set-session-topic 'rig topic two'
rigAssert "the old home of --set-session-topic says where it went" \
	"$( rigSaid 'DistroAgentsSession: --set-session-topic moved to AgentExecutorTools.fn.sh --set-session-topic' )" 1
rigCall "$rigSessionTool" rig-chair "$rigSession" --set-session-chapter 'rig chapter two'
rigAssert "the old home of --set-session-chapter says where it went" \
	"$( rigSaid 'DistroAgentsSession: --set-session-chapter moved to AgentExecutorTools.fn.sh --set-session-chapter' )" 1
rigCall "$rigDispatcher" rig-chair "$rigSession" --list-session-runs
rigAssert "the old home of --list-session-runs says where it went" \
	"$( rigSaid 'DistroAgentsDispatcher: --list-session-runs moved to AgentExecutorTools.fn.sh --list-session-runs' )" 1
rigRows="$( . "$rigTable" && printf '%s\n' "$agentsFrontTable" )" || rigRows=""
rigAssert "the table gives each of the four moved names to the new front, its audience member" \
	"$( printf '%s\n' "$rigRows" | LC_ALL=C awk -F'\t' '$1 == "AgentExecutorTools" && $3 == "member" && ($2 == "--set-session-topic" || $2 == "--set-session-chapter" || $2 == "--get-uninvited-participants" || $2 == "--list-session-runs") { n++ ; } END { print n + 0 ; }' )" 4
rigStubs="$( . "$rigTable" && printf '%s\n' "$agentsFrontStubs" )" || rigStubs=""
rigAssert "and each old home keeps its stub row" \
	"$( printf '%s\n' "$rigStubs" | LC_ALL=C awk -F'\t' '$3 == "AgentExecutorTools" { print $1 ":" $2 ; }' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" \
	"DistroAgentsDispatcher:--list-session-runs DistroAgentsSession:--get-uninvited-participants DistroAgentsSession:--set-session-chapter DistroAgentsSession:--set-session-topic "
## ThisSession keeps serving the words it served: each reaches its operation, and each is owned by the new front.
for rigWord in get-uninvited-participants set-session-topic set-session-chapter ; do
	rigThisSession rig-chair "$rigSession" "{\"operation\":\"$rigWord\",\"message\":\"rig words\"}"
	rigAssert "ThisSession still serves $rigWord, from the new front" \
		"$( rigSaid 'unknown operation' ):$( rigSaid 'invalid option' ):$( printf '%s\n' "$rigRows" | LC_ALL=C awk -F'\t' -v want="--$rigWord" '$2 == want { print $1 ; }' )" \
		"0:0:AgentExecutorTools"
done

echo "-- 2. --executor-queue: the chair's read of its session's queue --"
rigScene queue
rigRecord "$rigSession" rig-chair spawn-started "participants: rig-chair rig-part
start-context: spawned"
rigRecord run-part rig-part spawn-started ''
rigQueue rig-part
rigCall "$rigFront" rig-chair "$rigSession" --executor-queue
rigAssert "the queue is read, and is no invalid option" "$rigRc:$( rigSaid 'invalid option' )" "0:0"
rigAssert "a block per participant, each with its run's state" \
	"$( LC_ALL=C grep -c -E '^(member rig-chair: has a run in the session|member rig-part: has a run in the session)$' "$rigOut" )" 2
rigAssert "the open item and the item under way are shown, the done one is not" \
	"$( LC_ALL=C grep -c -F -e '- [ ] chair reads the queue' -e '- [~] an item under way' "$rigOut" ):$( rigSaid '- [x] an item already done' )" "2:0"
rigCall "$rigFront" rig-chair "$rigSession" --executor-queue --member rig-part
rigAssert "one participant's block alone: --member names it, and nothing of the chair's" \
	"$( LC_ALL=C grep -c -E '^member rig-part: ' "$rigOut" ):$( rigSaid 'member rig-chair' )" "1:0"
rigCall "$rigFront" rig-chair "$rigSession" --executor-queue --member rig-other
rigAssert "a member neither executor nor participant is refused, and nothing is read" \
	"$( rigSaid 'neither the executor nor a participant' )" 1
rigCall "$rigFront" rig-chair "$rigSession" --executor-queue --session-id rig-no-such-session
rigAssert "a session this workspace does not hold is refused, and no queue printed" \
	"$( [ "$rigRc" != 0 ] && printf refused || printf read ):$( LC_ALL=C grep -c -F 'queue rig-' "$rigOut" )" "refused:0"
rigCall "$rigFront" rig-chair rig-no-such-session --executor-queue
rigAssert "the same, where the session unknown is the call's own" \
	"$rigRc:$( rigSaid 'is unknown in this workspace' )" "1:1"
rigCall "$rigFront" rig-part "$rigSession" --executor-queue
rigAssert "a caller that is not the session's executor is refused" \
	"$( rigSaid 'is not the executor of session' )" 1
rigCall "$rigFront" '' "$rigSession" --executor-queue
rigAssert "a call from no member's seat is refused" "$( rigSaid 'a call from no member' )" 1

echo "-- 3. --executor-checklist-append: the chair puts work into a participant's queue --"
rigScene append
rigRecord "$rigSession" rig-chair spawn-started "participants: rig-chair rig-part
start-context: spawned"
rigRecord run-part rig-part spawn-started ''
rigQueue rig-part
rigCall "$rigFront" rig-chair "$rigSession" --executor-checklist-append --member rig-part --item 'the chair asks: check the build' --item 'the chair asks: report the count'
rigAssert "two items are added, and the call says so" "$rigRc:$( rigSaid '2 item(s) added, as pending' )" "0:1"
rigAssert "both land at the end of the participant's queue, its own three items kept, and nothing in the chair's own queue" \
	"$( LC_ALL=C awk '/^- \[ \] the chair asks/ { n++ ; } END { print n + 0 ; }' "$( rigQueueFile rig-part )" ):$( LC_ALL=C awk 'END { print NR + 0 ; }' "$( rigQueueFile rig-chair )" 2> /dev/null || printf 0 )" "2:0"
rigAssert "each of the chair's two items is marked as the chair's own, not the member's" \
	"$( LC_ALL=C awk -F'\t' '$1 == "parent" && ($2 == "the chair asks: check the build" || $2 == "the chair asks: report the count") { n++ ; } END { print n + 0 ; }' "$( rigQueueFile rig-part | LC_ALL=C sed 's/\.checklist\.md$/.checklist-sources.md/' )" )" 2
rigCall "$rigFront" rig-chair "$rigSession" --executor-checklist-append --member rig-other --item 'not for you'
rigAssert "a member neither executor nor participant is refused, and nothing is written" \
	"$( rigSaid 'neither the executor nor a participant' )" 1
rigCall "$rigFront" rig-chair "$rigSession" --executor-checklist-append
rigAssert "no --item at all is refused" "$( rigSaid 'give at least one --item' )" 1
rigCall "$rigFront" rig-chair "$rigSession" --executor-checklist-append --item ''
rigAssert "an empty item is refused" "$( rigSaid 'takes the text of an item' )" 1
rigCall "$rigFront" rig-chair "$rigSession" --executor-checklist-append --item 'x (due: not-a-date)'
rigAssert "a (due: ...) mark nothing can read is refused, and the list keeps its items" \
	"$( rigSaid 'due must be a date-time this tooling can read' ):$( LC_ALL=C grep -c -F 'x (due: not-a-date)' "$( rigQueueFile rig-part )" )" "1:0"
rigCall "$rigFront" rig-chair rig-no-such-session --executor-checklist-append --item 'nowhere'
rigAssert "a session this workspace does not hold is refused" "$( rigSaid 'is unknown in this workspace' )" 1
rigCall "$rigFront" rig-part "$rigSession" --executor-checklist-append --item 'not yours to add'
rigAssert "a caller that is not the session's executor is refused" "$( rigSaid 'is not the executor of session' )" 1
rigCall "$rigFront" '' "$rigSession" --executor-checklist-append --item 'no seat'
rigAssert "a call from no member's seat is refused" "$( rigSaid 'a call from no member' )" 1
mkdir -p "$( rigQueueFile rig-part ).lock"
rigCall "$rigFront" rig-chair "$rigSession" --executor-checklist-append --member rig-part --item 'while the list is held'
rmdir "$( rigQueueFile rig-part ).lock" 2> /dev/null || :
rigAssert "a list whose lock is held is refused, and nothing is written" \
	"$( rigSaid 'lock was not taken in five seconds' ):$( LC_ALL=C grep -c -F 'while the list is held' "$( rigQueueFile rig-part )" )" "1:0"

echo "-- 4. --executor-resume: adding to a stopped session's queue resumes its executor --"
rigScene resume
rigRecord "$rigSession" rig-chair spawn-succeeded "participants: rig-chair rig-part
start-context: spawned"
rigAssert "the executor's run has ended, so nothing of it runs" \
	"$( MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" bash -c '. "$0/sh-lib/session/AgentsTools.SessionSeats.include" ; AgentsToolsSessionMemberPresent "$1" rig-chair && printf present || printf absent' "$rigPackage" "$rigSession" 2> /dev/null )" absent
rigCall "$rigFront" rig-chair "$rigSession" --executor-checklist-append --member rig-chair --item 'work for a stopped session'
rigAssert "the item lands, and the append resumes the executor it found stopped" \
	"$rigRc:$( rigSaid '1 item(s) added, as pending' ):$( rigSaid 'OK: --executor-resume' )" "0:1:1"
rigAssert "the session's control thread was started" \
	"$( LC_ALL=C grep -c -F "a start of the control thread of session $rigSession is made" "$rigWs/.local/agents/sessions/$rigSession/control/log" 2> /dev/null || : )" 1
rigAssert "and the control thread answered for itself" \
	"$( LC_ALL=C grep -c -E '^(OK: --executor-resume: session '"$rigSession"': (started|alive|started [0-9]+))' "$rigOut" )" 1
sleep 300 &
rigLivePid=$!
rigRecord run-chair-live rig-chair spawn-started ''
rigCall "$rigFront" rig-chair "$rigSession" --executor-resume
kill "$rigLivePid" 2> /dev/null || :
wait "$rigLivePid" 2> /dev/null || :
rigAssert "a live executor run is no candidate for resuming" \
	"$( rigSaid 'is live, so nothing needs resuming' )" 1
rigScene dismissed
rigRecord "$rigSession" rig-chair spawn-succeeded "participants: rig-chair
start-context: spawned"
: > "$rigWs/.local/agents/sessions/$rigSession/dismissed"
rigCall "$rigFront" rig-chair "$rigSession" --executor-resume
rigAssert "a session carrying the owner's dismissal mark is refused, and nothing is started" \
	"$( rigSaid 'dismissal mark' ):$( rigSaid 'a start of the control thread' )" "1:0"
rigCall0(){ ## member, the session the call is its own: the same call from no session named, with that session as its own
	local callRc=0
	rigCallNo=$(( rigCallNo + 1 ))
	rigOut="$rigTmp/call-$rigCallNo.out" rigErr="$rigTmp/call-$rigCallNo.err"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigScn/data" MDAT_SPAWN_AGENT="$1" MDAT_SESSION_ID="$2" MDAT_WAIT_REMIND=off RIG_SCENARIO="$rigScn" \
		python3 -I -B "$rigFixtures/rig-exec.py" --alarm 60 -- bash "$rigFront" --executor-resume ) > "$rigOut" 2> "$rigErr" < /dev/null || callRc=$?
	rigRc="$callRc"
}
rigCall0 rig-chair rig-no-such-session
rigAssert "a session this workspace does not hold has no place for a control thread, and is refused" \
	"$rigRc:$( rigSaid 'is unknown in this workspace' )" "1:1"
rigCall "$rigFront" rig-part "$rigSession" --executor-resume
rigAssert "a caller that is not the session's executor is refused" "$( rigSaid 'is not the executor of session' )" 1
rigCall "$rigFront" '' "$rigSession" --executor-resume
rigAssert "a call from no member's seat is refused" "$( rigSaid 'a call from no member' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ EXECUTOR TOOLS CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'EXECUTOR_TOOLS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
exit 0
