#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the comms source ingest as one operation, `--intern-comms-ingest --run <member> <channel id>` (S1.12 stage
## 1, standing ruling 14: the ingest is reachable as one operation a thread runs, and nothing else reads a source). The pass
## itself is AgentsCommsIngestCheck's subject; this check holds the operation that wraps it. Held:
##   0. the control: the sibling `--intern-comms-event-id` arm answers, so the tool's own dispatch is reached
##   1. a call with no `--run` answers this operation's own syntax, and writes nothing
##   2. a pass writes the events its read holds and moves the pointer to the last id it wrote
##   3. the ids come from the event-id thread, which ran for the pass
##   4. a channel naming no valid id is refused, and neither the store nor the pointer moves
##   5. a member name that is no bare path segment is refused, and nothing is written
##   6. a second pass over a store nothing changed writes not one line
## Offline: a Slack-shaped fake curl first on PATH, which counts every call it answers.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## A RIG INHERITS ITS RUNNER'S SESSION, and this check must read none of it.
for rigDrop in ${!MDAT_SPAWN_@} MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_CONVERSATION_THREADS MDAT_WAIT_REMIND harnessSessionId harnessAgent CLAUDE_CODE_SESSION_ID ; do
	unset "$rigDrop" 2> /dev/null || :
done
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTools="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTools" ] || { echo "⛔ ERROR: the tool is not at the origin this workspace resolves: $rigTools" >&2 ; exit 1 ; }
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
## And the event-id thread this check starts, by its lock, ended before the rig goes.
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsIngestOpCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## THE RIG ENDS WHAT IT STARTED: the event-id thread the pass starts is a process of its own, noted as it begins and signalled the one
## safe way sh-test signals a process it did not start.
rigThreadPids(){
	LC_ALL=C awk '/the thread runs as pid/ { for (i = 1 ; i < NF ; i++) if ($i == "pid") { print $(i + 1) } }' \
		"$rigWs/.local/cache/comms/.event-id/thread.log" 2> /dev/null | LC_ALL=C tr -d ':,' | LC_ALL=C awk '/^[0-9]+$/'
}
rigEndThreads(){
	local rigWaited=0 rigAlive=1 rigPid
	while [ "$rigWaited" -lt 25 ] ; do
		rigAlive=0
		for rigPid in $( rigThreadPids ) ; do
			LC_ALL=C ps -o pid= -p "$rigPid" 2> /dev/null | LC_ALL=C grep -q . && rigAlive=1
		done
		[ "$rigAlive" = 1 ] || break
		sleep 1 ; rigWaited=$(( rigWaited + 1 ))
	done
	[ "$rigAlive" = 1 ] || return 0
	rigProcNote $( rigThreadPids )
	rigProcSignalWithChildren KILL $( rigThreadPids )
}
trap 'rigEndThreads ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScn="$rigTmp/scn"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigScn" "$rigTmp/skills/keeper-rig"
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"

## A Slack-shaped fake curl of this check's own: one message, and its one thread reply, whatever the pass.
cat > "$rigTmp/bin/curl" <<'FAKE'
#!/usr/bin/env bash
rigMethod=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
done
printf '%s\n' "$rigMethod" >> "$RIG_SCN/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1","bot_id":"BRIGBOT1"}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n' ;;
	conversations.history)
		printf '{"ok":true,"messages":[{"ts":"1793600000.000001","user":"URIGOTHER","text":"RIG-FIRST","reply_count":1,"latest_reply":"1793600000.000002","reply_users":["URIGOTHER"]}],"has_more":false,"response_metadata":{"next_cursor":""}}\n'
	;;
	conversations.replies) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	conversations.list) printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n' ;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
FAKE
chmod +x "$rigTmp/bin/curl"

## THE SUBJECT HAS TO BE THERE. A check whose include is absent would report rows about nothing: an unknown operation, a store that
## was never written and a refused call all look alike from here.
rigInclude="$rigOrigin/myx/myx.distro-agents/sh-lib/comms/AgentsTools.InternCommsIngest.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the operation is not at the origin this workspace resolves: $rigInclude" >&2 ; exit 1 ; }

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
## The source's cache folder: `slack-<channel id>` in the service's folder, the account naming no part of a channel id that is no DM.
rigCacheDir="$rigWs/.local/cache/comms/slack/slack-CRIG00001"

## ONE CALL OF THE OPERATION, through the tool as a member's shell makes it: the rig's own workspace, the rig's own fake Slack, and
## the copy under test as the origin. The call runs in a subshell of this shell, so nothing of it outlives the rig.
rigIngest(){ ## the words after the tool -- its rc, its output in the rig's files
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigScn/data" "RIG_SCN=$rigScn" "MDAT_SPAWN_AGENT=keeper-rig" "MDAT_COMMS_EVENT_ID_IDLE_SECONDS=3" \
		bash "$rigTools" "$@" ) > "$rigScn/call.out" 2> "$rigScn/call.err"
}
rigEvents(){ LC_ALL=C cat "$rigCacheDir"/[0-9][0-9][0-9][0-9][0-9][0-9]/events.txt 2> /dev/null ; }
rigEventCount(){ rigEvents | LC_ALL=C awk 'NF' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ; }
rigPointer(){ LC_ALL=C cat "$rigCacheDir/.ingest.txt" 2> /dev/null ; }
rigLastId(){ rigEvents | LC_ALL=C cut -f1 | LC_ALL=C sort | LC_ALL=C tail -1 ; }

echo "-- 0. the control: the tool reaches its own arms, so a refusal below is the operation's own --"
rigIngest --intern-comms-event-id --run
rigAssert "the sibling arm answers, so the tool's dispatch works" "$?" 0
rigAssert "and its thread wrote its own log" "$( [ -s "$rigWs/.local/cache/comms/.event-id/thread.log" ] && printf written || printf none )" written

echo "-- 1. a call with no --run answers this operation's own syntax, and writes nothing --"
rigIngest --intern-comms-ingest
rigAssert "it is refused" "$?" 1
rigAssert "by this operation's own syntax, not as an unknown one" "$( rigIn "$( cat "$rigScn/call.err" )" '--intern-comms-ingest --run <member> <channel id>' ):$( rigIn "$( cat "$rigScn/call.err" )" 'invalid option' )" "yes:no"
rigAssert "and no store was made" "$( [ -e "$rigWs/.local/cache/comms/slack" ] && printf made || printf none )" none

echo "-- 2. a pass writes the events its read holds, and moves the pointer --"
rigIngest --intern-comms-ingest --run keeper-rig CRIG00001
rigAssert "the pass ran" "$?" 0
rigAssert "it wrote its message" "$( rigEvents | LC_ALL=C awk -F'\t' '$2 == "msg" { n++ } END { print n + 0 }' )" 1
rigAssert "the pointer names the file's last id" "$( rigPointer )" "$( rigLastId )"
rigAssert "and the pointer is the EventIdentifier form" "$( rigPointer | LC_ALL=C awk '$0 ~ /^[0-9]{8}T[0-9]{9}Z-[0-9]{6}[0-9A-F]{3}$/ { n++ } END { print n + 0 }' )" 1

echo "-- 3. the ids come from the event-id thread, which ran for the pass --"
rigThreadStarts(){ LC_ALL=C grep -c -F -e "the thread runs as pid" "$rigWs/.local/cache/comms/.event-id/thread.log" 2> /dev/null | LC_ALL=C tr -d ' ' ; }
rigAssert "the rig's id thread started, the control's or the pass's own" "$( [ "$( rigThreadStarts )" -ge 1 ] && printf yes || printf no )" yes
rigAssert "and reports no error of its own" "$( LC_ALL=C grep -c -F -e "command not found" -e "⛔ ERROR" "$rigWs/.local/cache/comms/.event-id/thread.log" 2> /dev/null | LC_ALL=C tr -d ' ' )" 0

echo "-- 4. a channel naming no valid id is refused, and nothing moves --"
rigCountBefore="$( rigEventCount )"
rigPointerBefore="$( rigPointer )"
rigIngest --intern-comms-ingest --run keeper-rig '@team/*/sessions/*'
rigAssert "it is refused" "$?" 1
rigAssert "naming the channel it was given" "$( rigIn "$( cat "$rigScn/call.err" )" 'the ingest takes one channel id' )" yes
rigAssert "the store holds what it held" "$( rigEventCount )" "$rigCountBefore"
rigAssert "and the pointer did not move" "$( rigPointer )" "$rigPointerBefore"

echo "-- 5. a member name that is no bare path segment is refused, and nothing is written --"
rigIngest --intern-comms-ingest --run ../magic-team CRIG00001
rigAssert "it is refused" "$?" 1
rigAssert "naming the member it was given" "$( rigIn "$( cat "$rigScn/call.err" )" 'the ingest takes one member name' )" yes
rigAssert "the store holds what it held" "$( rigEventCount )" "$rigCountBefore"

echo "-- 6. the control: a quiet pass over a store nothing changed writes not one line --"
rigIngest --intern-comms-ingest --run keeper-rig CRIG00001
rigAssert "the quiet pass ran" "$?" 0
rigAssert "and the store gained nothing" "$( rigEventCount )" "$rigCountBefore"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'COMMS_INGEST_OP: OK\n'
