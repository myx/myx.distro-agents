#!/usr/bin/env bash
## Covers the two Wait-design asks added alongside the baseline-carry fix
## (AgentsWaitAskBaselineCarryCheck.test.sh): an explicit --unwait, and an answered ask:
## source that drops itself from a default wait once quiet for five minutes past its own
## last update.
## --unwait <source> is a named shorthand for --wait-drop --wait-source <source>: it reuses
## the existing drop-mode machinery, so this covers the flag's own parsing and the "dropping
## is not blocking" property -- the same source still works again once asked for explicitly.
## The five-minute expiry reads a closed record's own follow-floor directly (the same pointer
## a clarification already shifts) as its last-update time; it only ever withholds an ask:
## source a default call would otherwise reach for on its own, never one named explicitly in
## the same call, and it is shown on WAIT-DROPPED-EXPIRED, not applied silently.
## Offline: the only non-ask: source named anywhere here is a plain file:, so no curl call is
## expected at all; the fixture is present only as a safety net against an unintended one.
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsWaitUnwaitExpireCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
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
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}
rigSourcesLine(){ ## file
	LC_ALL=C sed -n 's/^# sources: //p' "$1" | head -1
}

rigScenarioDir="$rigTmp/scenario"
mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents/pending"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
RIG_CURL_LOG="$rigScenarioDir/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"

rigOp(){ ## operation and its arguments
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		MDAT_WAIT_REMIND=off TMPDIR="$rigTmp" MMDAPP="$rigScenarioDir/ws" bash "$rigTools" "$@" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err"
}
## A question closed by the team operation, with no thread: the same minimal shape
## AgentsWaitAskBaselineCarryCheck.test.sh uses, here with a follow-floor set directly, which
## is all the new expiry check reads -- it never depends on AgentsWaitProbeAsk's own thread-
## reading, so no thread fixture is needed to exercise it.
rigRecord(){ ## pending id, follow-floor value
	cat > "$rigScenarioDir/ws/.local/agents/pending/$1.md" <<RIGRECORD
status: reply-received
answered-session: rig-other-session
answered-by: rig-other-session
verdict: closed-by-operation
follow-floor: $2
kind: question
# Thread
RIGRECORD
}

echo "-- --unwait drops a held source by name, and does not block naming it again --"
rigSession1="rig-wait-unwait"
rigRecord rig-unwait-001 1700000000.000000
rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$rigSession1" --wait-source "ask:rig-unwait-001" --wait-timeout 5 --wait-poll-interval 1
rigAssert "the first wait on it receives" "$( rigFirstLine "$rigScenarioDir/out" )" "WAIT-RESULT: RECEIVED"
rigAssert "it is in the stored wait" "$( rigHolds "$rigScenarioDir/ws/.local/agents/sessions/$rigSession1/wait/state" "ask:rig-unwait-001" )" "yes"
rigOp --member-wait-for-input "$rigMember" --unwait "ask:rig-unwait-001" --wait-session-id "$rigSession1"
rigAssert "--unwait reports DROPPED" "$( rigFirstLine "$rigScenarioDir/out" )" "WAIT-RESULT: DROPPED"
rigAssert "it leaves the stored sources line" "$( rigSourcesLine "$rigScenarioDir/out" )" ""
rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$rigSession1" --wait-source "ask:rig-unwait-001" --wait-timeout 5 --wait-poll-interval 1
rigAssert "naming it again explicitly still works: dropping is not blocking" "$( rigFirstLine "$rigScenarioDir/out" )" "WAIT-RESULT: RECEIVED"

echo "-- an answered question quiet for five minutes past its own update expires out on its own --"
rigSession2="rig-wait-expire"
rigRecord rig-expired-001 1600000000.000000
: > "$rigScenarioDir/ws/quiet.txt"
rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$rigSession2" --wait-source "ask:rig-expired-001" --wait-source "file:$rigScenarioDir/ws/quiet.txt" --wait-timeout 5 --wait-poll-interval 1
rigAssert "the first wait on it receives" "$( rigFirstLine "$rigScenarioDir/out" )" "WAIT-RESULT: RECEIVED"
rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$rigSession2" --wait-source "file:$rigScenarioDir/ws/quiet.txt" --wait-timeout 3 --wait-poll-interval 1
rigAssert "a later default wait, naming it from carry-forward alone, times out" \
	"$( rigFirstLine "$rigScenarioDir/out" | LC_ALL=C sed 's/ (.*//' )" "WAIT-RESULT: TIMEOUT"
rigAssert "the expiry is said, not silent" "$( rigHolds "$rigScenarioDir/out" "WAIT-DROPPED-EXPIRED: ask:rig-expired-001" )" "yes"
rigAssert "it left the stored sources" "$( rigSourcesLine "$rigScenarioDir/out" )" "file:$rigScenarioDir/ws/quiet.txt"
rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$rigSession2" --wait-source "ask:rig-expired-001" --wait-timeout 5 --wait-poll-interval 1
rigAssert "naming the expired source again explicitly still works" "$( rigFirstLine "$rigScenarioDir/out" )" "WAIT-RESULT: RECEIVED"

rigAssert "no request went anywhere but a Slack method" \
	"$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT UNWAIT EXPIRE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_UNWAIT_EXPIRE: OK (%d assertions, offline)\n' "$rigPassCount"
