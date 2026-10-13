#!/usr/bin/env bash
## End-to-end check that unwait, the Wait tool's own new parameter, actually reaches
## --member-wait-for-input's --unwait through the real harness entry point
## (AgentsHarnessToolWait, AgentsUniversalHarness.sh --intern-tool Wait) -- not just the
## low-level op AgentsWaitUnwaitExpireCheck.test.sh already covers. Offline: the only
## source ever named is a plain file:, so no curl call is expected at all.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessToolUnwaitCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigSession="rig-tool-unwait"
rigFile="$rigWs/quiet.txt"
: > "$rigFile"

rigCall(){ ## json argument object
	( cd "$rigWs" && printf '%s' "$1" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT MDAT_SPAWN_SESSION_ID="$rigSession" MMDAPP="$rigWs" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=5 \
		bash "$rigHarness" --intern-tool Wait ) > "$rigWs/out" 2> "$rigWs/err"
}

echo "-- a bare default wait first establishes the stored source --"
rigCall "{\"sources\":\"file:$rigFile\",\"timeout\":2}"
rigAssert "the first wait times out" "$( LC_ALL=C head -1 "$rigWs/out" | LC_ALL=C sed 's/ (.*//' )" "WAIT-RESULT: TIMEOUT"

echo "-- unwait, through the real Wait tool, drops it --"
rigCall "{\"unwait\":\"file:$rigFile\"}"
rigAssert "the tool call itself reports DROPPED" "$( LC_ALL=C head -1 "$rigWs/out" )" "WAIT-RESULT: DROPPED"

echo "-- a later continue finds nothing stored to continue --"
rigCall '{"mode":"continue"}'
rigAssert "continue now finds no stored wait at all" "$( LC_ALL=C grep -c 'found no stored wait' "$rigWs/out" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS TOOL UNWAIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_TOOL_UNWAIT: OK (%d assertions, offline)\n' "$rigPassCount"
