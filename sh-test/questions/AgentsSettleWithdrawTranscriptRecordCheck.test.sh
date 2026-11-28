#!/usr/bin/env bash
## Behavioural check that withdrawing an open ask keeps the record of it: one line in the acting
## run's own session transcript, naming the pending id it withdrew (epic S6.10, statement 2:
## "The logs and the event-track thread keep the record.").
## Run through the real operation, in a rig workspace of its own, over a Slack-shaped fake curl,
## and read back through a separate path: the log file the acting session's own transcript
## pointer names. Covered:
##   1. the positive control: --append-transcript, a writer known to land in that transcript,
##      puts its line there. Without it a pointer that never resolves and a write that never
##      happened read exactly alike.
##   2. the ask is opened by the store's own operation and is still open when it is withdrawn,
##      and the withdraw reports itself as done, so the record asserted below is owed.
##   3. one line appears in the acting run's transcript since, naming that pending id, and only one.
## Red: with the statement unimplemented, row 3 finds no new line at all while the control
## still passes.
## Offline: the fake curl opens no socket, and the rig is a folder of the workspace's scratch.
## Guards: sh-lib/questions/AgentsTools.OpSettlePendingReply.include
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## The control writes team data, which only a team rig keeps (AgentsTools.TeamDataGate.include).
## The runner gives every test that mode, and a run by hand takes the same default.
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"
rigSid="rig-withdraw-record"
rigChannel="CRIG00001"
rigAskTs="1700000100.000100"
rigControlText="RIG-WITHDRAW-CONTROL-LINE"
rigReason="rig no longer needs an answer"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" ] || rigRefuse "the fake curl fixture is missing from the package"

. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSettleWithdrawTranscriptRecordCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap '[ -n "${RIG_KEEP:-}" ] || rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/pending" "$rigTmp/bin" "$rigData" || rigRefuse "could not create the rig"
## The members these calls name, in a skillset root of the rig's own: a call acting as a member
## whose directory is absent is refused (AgentsToolsSlackMemberPresent).
for rigNeed in "$rigMember" magic-coordinator magic-team ; do
	mkdir -p "$rigSkills/$rigNeed" || rigRefuse "could not create the rig's member directory $rigNeed"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigNeed/$rigNeed.basic.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=%s\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' "$rigChannel" > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigWs/.local/.agents/$rigMember.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The fake curl is the package's own: every method logged, every posted body kept, and a thread
## answered from replies.<ts>.json where the scenario has one.
cp "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" ; export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
RIG_CURL_LOG="$rigTmp/curl.log" ; export RIG_CURL_LOG ; : > "$RIG_CURL_LOG"
RIG_SCENARIO="$rigTmp/scenario" ; export RIG_SCENARIO ; mkdir -p "$RIG_SCENARIO"
## The question's own thread, as a read answers it: the asker's post and nothing else, so the
## withdraw has something to see and nobody but the asker took part.
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"RIG-ASK"}]}\n' "$rigAskTs" > "$RIG_SCENARIO/replies.$rigAskTs.json"

## The acting run's own session: its transcript pointer is what the operation must write through,
## and its store is where the withdraw tells the asker (AgentsSessionKnown).
mkdir -p "$rigWs/.local/agents/sessions/$rigSid" || rigRefuse "could not create the rig's session store"

rigEnv(){ ## command... -- the rig's workspace, as the acting member of its own session
	( cd "$rigWs" && env -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD \
		-u CLAUDE_CODE_SESSION_ID -u harnessSessionId -u harnessAgent -u MDAT_TEAM_MEMBER \
		-u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u MDAT_COMMS_READER -u MDAT_COLLECT_THREAD \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="$rigSid" MDAT_WORKSPACE_MODE="$MDAT_WORKSPACE_MODE" \
		MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_SCHEDULE_THREAD=off MDAT_WAIT_REMIND=off \
		RIG_SCENARIO="$RIG_SCENARIO" RIG_CURL_LOG="$RIG_CURL_LOG" "$@" )
}

## WHERE THE RECORD IS READ FROM: the pointer the acting session's own folder holds, then the log
## file that pointer names. Never the operation's own report.
rigPointer="$rigWs/.local/agents/sessions/$rigSid/transcript"
rigLogPath=""
rigRecordResolve(){
	[ -s "$rigPointer" ] || return 1
	IFS= read -r rigLogPath < "$rigPointer" || return 1
	[ -n "$rigLogPath" ] && [ -f "$rigLogPath" ]
}
rigLines(){ ## -- the lines the transcript log holds now
	[ -f "$rigLogPath" ] || { printf '0' ; return 0 ; }
	LC_ALL=C awk 'END { print NR + 0 }' "$rigLogPath"
}
rigHas(){ ## fixed text -- yes or no, over the whole transcript log
	[ -f "$rigLogPath" ] || { printf 'no' ; return 0 ; }
	if LC_ALL=C grep -q -F -- "$1" "$rigLogPath" ; then printf 'yes' ; else printf 'no' ; fi
}
rigNewNaming(){ ## lines-before, fixed text -- how many of the lines added since carry it
	[ -f "$rigLogPath" ] || { printf '0' ; return 0 ; }
	LC_ALL=C awk -v from="$1" -v want="$2" 'NR > from && index( $0, want ) { hits++ } END { print hits + 0 }' "$rigLogPath"
}
rigField(){ ## file, field -- the record's own header value
	LC_ALL=C awk -F': ' -v wantField="$2" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit }' "$1" 2> /dev/null
}

echo "-- the positive control: a known writer's line lands in the acting run's transcript --"
rigEnv bash "$rigTool" --append-transcript --team-member "$rigMember" --message "$rigControlText" --create \
	< /dev/null > "$rigTmp/control.out" 2> "$rigTmp/control.err"
rigAssert "the control wrote, so the session's transcript exists" "$( LC_ALL=C grep -c '^OK: appended to ' "$rigTmp/control.out" )" 1
rigLogPath="" ; rigResolved="no"
rigRecordResolve && rigResolved="yes"
rigAssert "the session's own pointer names a log file" "$rigResolved" yes
rigAssert "and the control's line is in that log, so a line written later would be seen" "$( rigHas "$rigControlText" )" yes

echo "-- the open ask, opened by the store's own operation --"
rigAskId="$( printf '# Ask\n\nMay I?\n' | rigEnv bash "$rigTool" --intern-op-pending-reply-open "$rigMember" --to "$rigChannel" \
	--kind question --channel "$rigChannel" --question-ts "$rigAskTs" --thread-ts "$rigAskTs" \
	--addressees URIGOWNER --asking-accounts ' URIGSELF1 ' 2> "$rigTmp/open.err" )"
rigAskFile="$rigWs/.local/agents/pending/$rigAskId.md"
[ -n "$rigAskId" ] && [ -f "$rigAskFile" ] \
	|| rigRefuse "the ask was not opened, so this check could not test its withdraw: $( head -2 "$rigTmp/open.err" )"
rigAssert "the ask is open, asked by the acting member" "$( rigField "$rigAskFile" status ):$( rigField "$rigAskFile" owner )" "reply-pending:$rigMember"

echo "-- withdrawn: the withdraw reports itself done --"
rigLinesBefore="$( rigLines )"
rigWithdrawRc=0
rigEnv bash "$rigTool" --settle-pending-reply --team-member "$rigMember" "$rigAskId" --reason "$rigReason" --withdraw \
	< /dev/null > "$rigTmp/withdraw.out" 2> "$rigTmp/withdraw.err" || rigWithdrawRc=$?
rigAssert "the withdraw says what it did" "$( LC_ALL=C grep -c -x -F "WITHDRAWN $rigAskId" "$rigTmp/withdraw.out" )" 1
rigAssert "and the call ends 0" "$rigWithdrawRc" 0
## The close moves the record to pending/closed/, so a status in the open folder would be stale.
rigClosedFile="$rigWs/.local/agents/pending/closed/$rigAskId.md"
rigAssert "the ask closed as withdrawn, so the record asserted below is owed" \
	"$( [ -f "$rigClosedFile" ] && rigField "$rigClosedFile" status || printf 'not-closed' )" "withdrawn"

echo "-- the record of that withdraw, in the acting run's own transcript --"
rigAssert "the control's line is still there, so the pointer did not move" "$( rigHas "$rigControlText" )" yes
rigAssert "one line names the pending id it withdrew" "$( rigNewNaming "$rigLinesBefore" "$rigAskId" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ SETTLE WITHDRAW TRANSCRIPT RECORD CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'SETTLE_WITHDRAW_TRANSCRIPT_RECORD: OK (%s assertions, offline, rig tree only)\n' "$rigPassCount"
