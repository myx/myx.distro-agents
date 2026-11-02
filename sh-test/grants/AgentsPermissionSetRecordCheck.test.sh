#!/usr/bin/env bash
## Behavioural check on S21.20: a permission-set ask that POSTS always leaves its pending record,
## so an answer has somewhere to arrive. Run through --intern-tool, the path the myx.distro MCP
## uses, against a Slack-shaped fake curl that opens no socket.
##   1. the owner's conversation is known only by its channel id, and his account cannot be named:
##      the post lands and the record is created, asked of human-owner by its member name.
##   2. control: with his account resolvable, the same instrument sees the same record, so the
##      five words "record was created" are not printed by a rig that never writes one.
##   3. control: a rig whose conversation is unknown posts nothing, and says so -- never a record
##      without a post.
## Offline: HOME, the workspace, the board and the skillset are fixtures; a fake curl and a fake
## ps are first on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigHarness="$rigHere/sh-lib/harness/AgentsUniversalHarness.sh"
rigFixture="$rigHere/sh-test/check-fixtures/harness-ask-forms.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing from the package"
[ -r "${MDAT_SKILLSET_ROOT:-}/magic-tester/magic-tester.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold magic-tester, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsPermissionSetRecordCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap '[ "${KEEP:-}" = 1 ] || { chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp" ; }' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigFixture" "$rigTmp/bin/curl" || rigRefuse "the fake curl could not be copied"
chmod +x "$rigTmp/bin/curl"
printf '#!/bin/sh\nexit 0\n' > "$rigTmp/bin/ps"
chmod +x "$rigTmp/bin/ps"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigMember="magic-tester"
rigItem="dispatch-20261102T0700Z-rig-set-record"
rigRefusal="refusal-00000000-0000-4000-8000-000000000105"
rigCase="" rigWs="" rigPost=0 rigRecord=0 rigOut=""

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## One rig of its own: a workspace, a board item, a refusal record, and the team channels as the
## case says. `owner` is what SLACK_CHANNEL_HUMAN_OWNER holds, empty for the third case.
rigStart(){ ## case name, the owner setting
	rigCase="$rigTmp/$1"
	rigWs="$rigCase/ws"
	rigOut="$rigCase/out"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/sessions/rig-set-record" "$rigCase/data/board/running"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=%s\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' "$2" \
		> "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigWs/.local/.agents/$rigMember.agent.env"
	printf '%s\t%s\t%s\t%s\t%s\n' rig-ws workspace read-write "$rigWs" \
		> "$rigWs/.local/agents/directories.registry"
	printf -- '---\nstatus: dispatch-started\nowner: %s\nsession-id: rig-set-record\n---\n\n# The rig needs its report folder\n' "$rigMember" \
		> "$rigCase/data/board/running/$rigItem.md"
	printf -- '---\nstatus: refused\nowner: %s\nsession-id: rig-set-record\ntool: Write\ntarget: /dev/null/rig-set-record/out/one.txt\nrefused-at: 2026-11-02 09:00 +0200\n---\n\n# Refused\n\nERROR: path not in the allowed write-root set: /dev/null/rig-set-record/out/one.txt\n' "$rigMember" \
		> "$rigWs/.local/agents/sessions/rig-set-record/$rigRefusal.md"
	RIG_CURL_LOG="$rigCase/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}

## The ask, through the harness: a set of one entry, for the task. An ask nobody answers waits by
## design, so the call is read by what it left on disk -- its record and its post -- and never by
## its exit. The post and the record are made well before the wait, so the loop waits for the
## record file, then ends the call.
rigAsk(){
	local askPid askLeft=90 settleLeft=10
	(
		cd "$rigWs" && printf '%s' '{"refusal_id":"'"$rigRefusal"'","reason":"the rig writes its report there","task_ref":"the report rework, '"$rigItem"'","entries":["Write,Read:/dev/null/rig-set-record/out/**"]}' \
			| env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD \
				MDAT_DATA_ROOT="$rigCase/data" MDAT_SPAWN_SESSION_ID="rig-set-record" RIG_SCENARIO="$rigCase" MMDAPP="$rigWs" \
				MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$MDAT_SKILLSET_ROOT" MDAT_WORKSPACE_MODE=team-rig \
				MDAT_WAIT_REMIND=off MDAT_HARNESS_WAIT_TIMEOUT=1 MDLT_ORIGIN="${MDLT_ORIGIN:?}" \
				bash "$rigHarness" --intern-tool RequestPermission --access-read-root "$rigWs" --access-write-root "$rigWs"
	) > "$rigOut" 2> "$rigCase/err" &
	askPid=$!
	while [ "$askLeft" -gt 0 ] ; do
		kill -0 "$askPid" 2>/dev/null || break
		[ -z "$( rigRecordFiles )" ] || break
		[ ! -s "$rigOut" ] || break
		sleep 1 ; askLeft=$(( askLeft - 1 ))
	done
	if kill -0 "$askPid" 2>/dev/null ; then
		kill -TERM "$askPid" 2>/dev/null ; sleep 1 ; kill -KILL "$askPid" 2>/dev/null
	fi
	wait "$askPid" 2>/dev/null || :
	## A record written as the call was ended is still this call's: the settle waits for the file.
	while [ "$settleLeft" -gt 0 ] ; do
		[ -z "$( rigRecordFiles )" ] || break
		[ -n "$( LC_ALL=C grep -c . "$rigOut" 2>/dev/null | LC_ALL=C awk '{ print ( $1 > 0 ? "said" : "" ) ; }' )" ] || { sleep 1 ; settleLeft=$(( settleLeft - 1 )) ; continue ; }
		break
	done
	rigPost="$( LC_ALL=C grep -c '^chat.postMessage$' "$RIG_CURL_LOG" 2>/dev/null )"
	rigRecord="$( rigRecordFiles | LC_ALL=C grep -c . )"
}
## The pending records of the case's workspace, one path a line.
rigRecordFiles(){
	find "$rigWs/.local/agents/pending" -maxdepth 1 -name '*.md' 2>/dev/null
}

echo "-- 1. the owner's account cannot be named: the post lands, and the record is asked under his member name --"
rigStart unnameable CRIGDM001
rigAsk
rigAssert "the ask was posted" "$rigPost" "1"
rigAssert "and its pending record was created, as a permission set of the asking member" "$rigRecord:$( LC_ALL=C sed -n 's/^kind: //p' "$rigWs/.local/agents/pending"/*.md 2>/dev/null | head -1 )" "1:permission-set"
rigAssert "its addressees are the party it is for, by its member name, so an answer is recognised" "$( LC_ALL=C sed -n 's/^addressees: //p' "$rigWs/.local/agents/pending"/*.md 2>/dev/null | head -1 )" "human-owner"
rigAssert "and the failure this check was written for is gone" "$( LC_ALL=C grep -c 'could not be named' "$rigOut" 2>/dev/null )" "0"

echo "-- 2. control: his account resolvable, the same instrument sees the same record --"
rigStart resolvable URIGOWNER
rigAsk
rigAssert "a post, and a record, when his account is known too" "$rigPost:$rigRecord" "1:1"

echo "-- 3. control: a conversation nobody named posts nothing, and no record stands alone --"
rigStart unpublished ""
rigAsk
rigAssert "nothing is posted, and nothing is recorded for it" "$rigPost:$rigRecord" "0:0"
rigAssert "and it says so, as an error rather than a result" "$( LC_ALL=C grep -c '^ERROR: ' "$rigOut" 2>/dev/null | LC_ALL=C awk '{ print ( $1 > 0 ? "said" : "silent" ) ; }' )" "said"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION SET RECORD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a permission-set ask that posted left no record where the owner's account could not be named" >&2
	echo "  fix:  sh-lib/grants/AgentsTools.InternOpPermission.include, its set's addressees -- never the assertion" >&2
	exit 1
fi
printf 'PERMISSION_SET_RECORD: OK (%d assertions, served, offline)\n' "$rigPassCount"
