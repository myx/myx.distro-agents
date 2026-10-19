#!/usr/bin/env bash
## Regression check: a pending reply closed with no thread (answered by the team operation)
## must leave the stored Wait set quiet once its one closing line has already been returned.
## AgentsWaitProbeAsk (AgentsTools.MemberWait.include) writes that same line on every poll of
## such a record. Staying quiet after the first RECEIVED depends on the stored per-source
## baseline carrying forward between calls. That carry-forward, for a non-Slack source such as
## ask:, used to require --wait-since-utime to be empty -- so a caller resuming a default-mode
## wait WITH a since_utime (an ordinary, common call shape) got a fresh empty baseline every
## time, and the same closed line kept reading as new.
## Offline: no Slack source is named by either scenario here, so no curl call is expected at
## all; the fixture is present only as a safety net against an unintended one.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "DistroAgentsTools.fn.sh not found at the origin this workspace resolves: $rigTools"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to act under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsWaitAskBaselineCarryCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigFirstLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}

rigScenarioDir="$rigTmp/closed-no-thread"
mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents/pending"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
RIG_CURL_LOG="$rigScenarioDir/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"

## A question closed by the team operation, with no thread at all -- the shape a member with
## no Slack account is answered under, and the shape AgentsWaitProbeAsk's own header comment
## names as reaching its asker from the record alone, never from a thread read.
rigPendingId="rig-closed-001"
cat > "$rigScenarioDir/ws/.local/agents/pending/$rigPendingId.md" <<'RIGRECORD'
status: reply-received
answered-session: rig-other-session
answered-by: rig-other-session
verdict: closed-by-operation
kind: question
# Thread
RIGRECORD

rigSession="rig-wait-baseline"
rigOp(){ ## operation and its arguments
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		MDAT_WAIT_REMIND=off MMDAPP="$rigScenarioDir/ws" bash "$rigTools" "$@" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err"
}

echo "-- a question closed with no thread: the first poll sees it, a later one must not repeat it --"
rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$rigSession" --wait-source "ask:$rigPendingId" --wait-timeout 5 --wait-poll-interval 1
rigAssert "the first wait on a freshly-closed question receives it" "$( rigFirstLine "$rigScenarioDir/out" )" "WAIT-RESULT: RECEIVED"

rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$rigSession" --wait-source "ask:$rigPendingId" --wait-since-utime 1 --wait-timeout 5 --wait-poll-interval 1
rigAssert "a later default wait naming since_utime, nothing new, times out" \
	"$( rigFirstLine "$rigScenarioDir/out" | LC_ALL=C sed 's/ (.*//' )" "WAIT-RESULT: TIMEOUT"

rigOp --member-wait-for-input "$rigMember" --wait-continue --wait-session-id "$rigSession" --wait-timeout 5 --wait-poll-interval 1
rigAssert "control: a plain continue of the same stored wait also times out" \
	"$( rigFirstLine "$rigScenarioDir/out" | LC_ALL=C sed 's/ (.*//' )" "WAIT-RESULT: TIMEOUT"

rigAssert "no request went anywhere but a Slack method" \
	"$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT ASK BASELINE CARRY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_ASK_BASELINE_CARRY: OK (%d assertions, offline)\n' "$rigPassCount"
