#!/usr/bin/env bash
## Behavioural check that --slack-delete-message keeps the record of an ordinary message it does
## delete: one line in the acting run's own session transcript, naming the conversation and the
## message (epic S6.10, statement 2: "The logs and the event-track thread keep the record.").
## Run through the real operation, in a rig workspace of its own, over a Slack-shaped fake curl,
## and read back through a separate path: the log file the acting session's own transcript
## pointer names. Covered:
##   1. the positive control: --append-transcript, a writer known to land in that transcript,
##      puts its line there. Without it a pointer that never resolves and a write that never
##      happened read exactly alike.
##   2. an ordinary message the operation does delete reads DELETE_STATE=deleted and asks
##      chat.delete once, so the deletion the record is owed for really happened.
##   3. one line appears in the acting run's transcript since, naming the conversation and the
##      ts of the deleted message, and only one.
## Red: with the statement unimplemented, row 3 finds no new line at all while the control
## still passes.
## Offline: the fake curl opens no socket, and the rig is a folder of the workspace's scratch.
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
rigSid="rig-delete-record"
rigChannel="CRIG00001"
rigOrdinaryTs="1700000300.000300"
rigControlText="RIG-DELETE-CONTROL-LINE"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" ] || rigRefuse "the fake curl fixture is missing from the package"

. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackDeleteTranscriptRecordCheck )" || exit 1
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
## The ordinary message's thread carries no reply, so the operation's own thread read answers and
## the guard against deleting an answered message does not fire.
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"RIG-ORDINARY"}]}\n' "$rigOrdinaryTs" > "$RIG_SCENARIO/replies.$rigOrdinaryTs.json"

## The acting run's own session: its transcript pointer is what the operation must write through.
## The prefix `rig-` keeps the session id a bare name, and the store under .local/agents/sessions
## makes the session one the tooling knows (AgentsSessionKnown).
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
rigNewNamingBoth(){ ## lines-before, fixed text, fixed text -- how many lines added since carry both
	[ -f "$rigLogPath" ] || { printf '0' ; return 0 ; }
	LC_ALL=C awk -v from="$1" -v one="$2" -v two="$3" 'NR > from && index( $0, one ) && index( $0, two ) { hits++ } END { print hits + 0 }' "$rigLogPath"
}
rigCalls(){ ## method -- how many times the fake curl was asked for it
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ } END { print hitCount + 0 }' "$RIG_CURL_LOG"
}

echo "-- the positive control: a known writer's line lands in the acting run's transcript --"
rigEnv bash "$rigTool" --append-transcript --team-member "$rigMember" --message "$rigControlText" --create \
	< /dev/null > "$rigTmp/control.out" 2> "$rigTmp/control.err"
rigAssert "the control wrote, so the session's transcript exists" "$( LC_ALL=C grep -c '^OK: appended to ' "$rigTmp/control.out" )" 1
rigLogPath="" ; rigResolved="no"
rigRecordResolve && rigResolved="yes"
rigAssert "the session's own pointer names a log file" "$rigResolved" yes
rigAssert "and the control's line is in that log, so a line written later would be seen" "$( rigHas "$rigControlText" )" yes

echo "-- an ordinary message, deleted: the deletion happens --"
rigLinesBefore="$( rigLines )"
: > "$RIG_CURL_LOG"
rigDeleteRc=0
rigEnv bash "$rigTool" --slack-delete-message --team-member "$rigMember" "$rigChannel:$rigOrdinaryTs" \
	< /dev/null > "$rigTmp/delete.out" 2> "$rigTmp/delete.err" || rigDeleteRc=$?
rigDeleteState="$( LC_ALL=C sed -n 's/^DELETE_STATE=//p' "$rigTmp/delete.out" )"
rigAssert "deleted, so the record asserted below is owed" "$rigDeleteState" "deleted"
rigAssert "chat.delete was asked once for it" "$( rigCalls chat.delete )" 1
rigAssert "and the call ends 0" "$rigDeleteRc" 0

echo "-- the record of that deletion, in the acting run's own transcript --"
rigAssert "the control's line is still there, so the pointer did not move" "$( rigHas "$rigControlText" )" yes
rigAssert "one line names the ts of the deleted message" "$( rigNewNaming "$rigLinesBefore" "$rigOrdinaryTs" )" 1
rigAssert "and that one line also names the conversation it was deleted from" \
	"$( rigNewNamingBoth "$rigLinesBefore" "$rigOrdinaryTs" "$rigChannel" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ SLACK DELETE TRANSCRIPT RECORD CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'SLACK_DELETE_TRANSCRIPT_RECORD: OK (%s assertions, offline, rig tree only)\n' "$rigPassCount"
