#!/usr/bin/env bash
## Behavioural check: a readback to the human-owner cites his own words. A readback whose source is a post of the asking
## session's own -- its thread's root, or one of its own posts -- carries no word of his: the ruling such a post brings, from
## a coordinator with his authority, is recorded and acted on, never read back to him. Through the real tool
## (AgentsUniversalHarness.sh --intern-tool ConfirmReadback), offline: a curl that fails at once, so nothing leaves the machine.
## Held:
##   1. a readback citing the session thread's root is refused before anything is sent, naming the record route
##   2. so is one citing one of the session's own posts
##   3. control: a readback citing another message is not refused by that rule
##   4. control: the same own source in a readback to a member is not refused by that rule
## Red before the rule: 1 and 2 fail, since the tool only asked that a source be given.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigMember="magic-tester"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to ask as"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessReadbackOwnSourceCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/bin"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_MAGIC_TEAM=CRIG00001\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf '#!/bin/sh\nexit 22\n' > "$rigWs/bin/curl"
chmod +x "$rigWs/bin/curl"
rigSession="rig-readback-own"
mkdir -p "$rigWs/.local/agents/sessions/$rigSession"
printf 'DRIG00001:1700000000.000100\n' > "$rigWs/.local/agents/sessions/$rigSession/session.thread"
printf 'DRIG00001:1700000000.000200 1700000000.000200 - - - 0 - 0\n' > "$rigWs/.local/agents/sessions/$rigSession/last-own-post"

rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One readback, to whom and citing what; the tool's whole output in $rigTmp/out.
rigReadback(){ ## to, source
	( cd "$rigWs" && printf '{"to":"%s","question":"Is this your decision on the rig item?","understood":"The rig parts move to the other board.","source":"%s","will_do":"Record it on the rig item.","wait":false}' "$1" "$2" \
		| env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT MDAT_SPAWN_SESSION_ID="$rigSession" MMDAPP="$rigWs" MDAT_SPAWN_AGENT="$rigMember" PATH="$rigWs/bin:$PATH" \
		bash "$rigHarness" --intern-tool ConfirmReadback ) > "$rigTmp/out" 2> "$rigTmp/err"
}
rigOwnRefused(){ LC_ALL=C grep -c -F 'holds no word of the human-owner' "$rigTmp/out" ; }

echo "-- 1. the session thread's root is no word of his --"
rigReadback human-owner slack:DRIG00001:1700000000.000100
rigAssert "refused, before anything is sent" "$( rigOwnRefused ):$( LC_ALL=C grep -c -F 'Nothing was sent' "$rigTmp/out" )" "1:1"
rigAssert "naming the record route" "$( LC_ALL=C grep -c -F -- '--record-decision' "$rigTmp/out" )" 1

echo "-- 2. nor is one of the session's own posts --"
rigReadback human-owner slack:DRIG00001:1700000000.000200
rigAssert "refused too" "$( rigOwnRefused )" 1

echo "-- 3. control: another message --"
rigReadback human-owner slack:DRIG00001:1700000000.000300
rigAssert "control: not refused by that rule" "$( rigOwnRefused )" 0

echo "-- 4. control: the same own source in a readback to a member --"
rigReadback magic-coordinator slack:DRIG00001:1700000000.000100
rigAssert "control: not refused by that rule" "$( rigOwnRefused )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS READBACK OWN SOURCE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_READBACK_OWN_SOURCE: OK (%d assertions, offline)\n' "$rigPassCount"
