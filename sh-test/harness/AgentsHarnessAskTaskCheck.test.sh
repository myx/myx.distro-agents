#!/usr/bin/env bash
## Behavioural check on an ask tool running as a task like any other (epic S10.30; sh-lib/harness/AgentsHarnessRun.include,
## sh-lib/harness/AgentsHarnessTaskArgsFill.awk, sh-lib/questions/AgentsTools.AskPost.include). Every call is a real one through the
## harness's own served entry point (`--intern-tool <tool>`) against this check's own rig workspace, with a fake curl first on PATH.
## Held:
##   1. each of the five tools that ask takes `background` as a parameter, and none refuses it as an unknown one
##   2. the argument filler gives each of the five a `background`, and gives none to the six the dispatcher does not wrap
##   3. an ask with `background: true` returns at once with TASK-ID=process-N, so the run is not held for its whole wait
##   4. an ask's `timeout` stays its own seconds per waiting round: the early return names the window, never that timeout
##   5. `Wait` is not wrapped: at a window of 1 s it returns its own result, never a task
## Left undone, and said in the gate: a `timeout_action` on an ask, and the count of posts the task made. Its arm reads the same form
## Bash's does, and that form did not fire for a Bash control in this rig. The post count goes through the comms outbox on this path, so
## the rig's fake curl sees none of it -- the class the epic already names as S10.41.
## The rig is a workspace of its own, under the scratch of this one, with its own MMDAPP and a member the served identity resolves.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigHarness="$rigOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh"
rigFillAwk="$rigOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessTaskArgsFill.awk"
rigWire="$rigOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsOpenAiChatWire.sh"
rigMember="magic-tester" rigSession="rig-ask-task"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
[ -f "$rigFillAwk" ] || rigRefuse "the task argument filler is not in the package: $rigFillAwk"
[ -f "$rigWire" ] || rigRefuse "the chat wire is not in the package: $rigWire"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so a posted question would have no identity to post under"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessAskTaskCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigReap(){
	local reapFile reapPid
	for reapFile in "$rigTmp/ws/.local/agents/sessions/$rigSession/processes"/*.pid ; do
		[ -f "$reapFile" ] || continue
		reapPid="$( head -1 "$reapFile" )"
		[ -z "$reapPid" ] || kill -TERM -- "-$reapPid" 2> /dev/null || kill -TERM "$reapPid" 2> /dev/null || :
	done
	pkill -TERM -f "$rigTmp" 2> /dev/null || :
	sleep 0.3
}
trap 'rigReap ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/agents/pending" "$rigTmp/home" "$rigTmp/work" "$rigTmp/bin" || exit 1
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token\n' \
	> "$rigTmp/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token\n' > "$rigTmp/ws/.local/.agents/$rigMember.agent.env"
## A fake curl that opens no socket, and answers a post after two seconds: a one-second window then falls during the post, which is
## what tells a call returned as a task from one that waited in place.
cp "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/harness-ask-task.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl" || exit 1
rigPath="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
rigProc="$rigTmp/ws/.local/agents/sessions/$rigSession/processes"
rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigExtraEnv=""
rigCall(){ ## tool, argument object, call name -- what the call printed in <name>.out
	local rigStatus=0
	( cd "$rigTmp/ws" && printf '%s' "$2" | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="${MDAT_SKILLSET_ROOT:-}" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="$rigSession" \
		MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 MDAT_TOOL_TASK_CEILING=60 $rigExtraEnv \
		python3 -I -B "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigHarness" --intern-tool "$1" --access-read-root "$rigTmp" --access-write-root "$rigTmp" ) \
		> "$rigTmp/$3.out" 2> "$rigTmp/$3.err" || rigStatus=$?
	printf '%s' "$rigStatus" > "$rigTmp/$3.rc"
}
rigSaidRe(){ LC_ALL=C grep -c -E -- "$1" "$rigTmp/$2.out" 2> /dev/null || : ; }
rigHead(){ LC_ALL=C head -1 "$rigTmp/$1.out" 2> /dev/null || : ; }
## Each call asks its own question, so no call is answered ALREADY-OPEN by the one before it.
rigAsk(){ ## question
	printf '"to":"magic-team","address_to":"URIGOWNER","question":"%s"' "$1"
}

echo "-- 1. each ask tool takes background --"
rigAt=0
for rigAskTool in AskQuestion ConfirmReadback EscalateDecision RequestPermission ProposeApprove ; do
	rigAt=$(( rigAt + 1 ))
	rigCall "$rigAskTool" "{$( rigAsk "Which check runs first, parameter $rigAt?" ),\"background\":true,\"wait\":false}" "param-$rigAskTool"
	rigAssert "$rigAskTool no longer refuses background as an unknown parameter" "$( rigSaidRe 'background is not a parameter' "param-$rigAskTool" )" "0"
done

echo "-- 2. the argument filler --"
rigFilled="$( ( . "$rigWire" ; printf '%s\n' "$harnessToolsJson" ) | LC_ALL=C awk -f "$rigFillAwk" )"
rigBackgroundOf(){ ## tool name -- yes, no, or no-such-tool
	printf '%s\n' "$rigFilled" | LC_ALL=C awk -v want="\"name\":\"$1\"" '
		index( $0, want ) > 0 { found = 1 ; print ( index( $0, "\"background\":" ) ? "yes" : "no" ) ; exit ; }
		END { if ( ! found ) { print "no-such-tool" ; } ; }'
}
for rigAskTool in AskQuestion ConfirmReadback EscalateDecision RequestPermission ProposeApprove ; do
	rigAssert "the schema of $rigAskTool carries background" "$( rigBackgroundOf "$rigAskTool" )" "yes"
done
for rigSkipTool in Wait ThisSession TaskOutput TaskStop SubagentHandback BatchTools ; do
	rigAssert "the schema of $rigSkipTool carries none, because the dispatcher does not wrap it" "$( rigBackgroundOf "$rigSkipTool" )" "no"
done

echo "-- 3. an ask returns at once as a task --"
rigCall AskQuestion "{$( rigAsk 'Which check runs first, background?' ),\"background\":true}" bg1
rigHandle="$( rigHead bg1 | sed -n 's/^TASK-ID=//p' )"
rigAssert "the ask comes back at once with its task id" "$( rigHead bg1 | cut -c1-8 )" "TASK-ID="
rigAssert "and the hint names the three ways on" "$( rigSaidRe 'TaskOutput handle=|TaskStop handle=|Wait sources=process:' bg1 )" "3"
rigAssert "the task is published as a process of this session" "$( [ -n "$rigHandle" ] && [ -f "$rigProc/$rigHandle.pid" ] && printf 'published' || printf 'missing' )" "published"
for rigWait in $(seq 1 60) ; do [ -f "$rigProc/$rigHandle.status" ] && break ; sleep 0.25 ; done
rigCall TaskOutput "{\"handle\":\"$rigHandle\"}" to2
rigAssert "TaskOutput reads the ask's own result once it ended" "$( rigHead to2 )" "PROCESS-RESULT: FINISHED"

echo "-- 4. an ask's timeout never becomes the task's bound --"
rigCall AskQuestion "{$( rigAsk 'Which check runs first, round?' ),\"wait\":false,\"timeout\":1}" round1
rigAssert "a call giving a 1 s round is not returned as a task at it" "$( rigSaidRe '^TASK-ID=' round1 )" "0"
rigAssert "and it is not ended at it either" "$( rigSaidRe 'was ended at your timeout' round1 )" "0"

echo "-- 5. Wait stays unwrapped --"
rigExtraEnv="MDAT_TOOL_TASK_SECONDS=1"
rigCall Wait '{"sources":"file:/nonexistent-rig-path","timeout":3}' wait1
rigExtraEnv=""
rigAssert "Wait is not wrapped: it returns its own result, never a task" "$( rigSaidRe '^TASK-ID=' wait1 )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK TASK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ASK_TASK: OK (%d assertions, offline)\n' "$rigPassCount"
