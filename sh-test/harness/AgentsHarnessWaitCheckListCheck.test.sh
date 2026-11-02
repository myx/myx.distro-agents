#!/usr/bin/env bash
## Behavioural check on what a Wait says about the caller's own CheckList (owner 2026-10-31: an idle Wait returns the unclosed items
## instead of waiting, so a member finishes or closes them before it waits for DISMISSED, and every other Wait carries the count
## alone). Through the real Wait tool (AgentsUniversalHarness.sh --intern-tool Wait) and its own stateful call, offline: a plain
## file: source where a source is named, and a curl that fails at once, so no request leaves the machine. Held:
##   1. a TIMEOUT of a Wait that named a source carries the count, and never the items
##   2. so does a wait that delivers an arrival
##   3. a list with every item closed says so, and a session with no list says to write one
##   4. an idle Wait -- no source named, and a handback given -- returns at once with the open items
##   5. and it does so again on the very next call, unchanged list and all (S22 item 6: the list is the queue)
##   6. mode continue is waiting on purpose, so it makes the ordinary wait and carries the count alone
##   7. an idle Wait with nothing open waits as it always did
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessWaitCheckListCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/bin"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## A curl that fails at once: the sources a call names are files, and the default ones are read into WAIT-NEVER-READ without a request.
printf '#!/bin/sh\nexit 22\n' > "$rigWs/bin/curl"
chmod +x "$rigWs/bin/curl"

rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigSession="rig-wait-checklist"
rigFolder="$rigWs/.local/agents/sessions/$rigSession"
rigList="$rigFolder/$rigMember.checklist.md"
rigFile="$rigWs/quiet.txt"
: > "$rigFile"

rigCall(){ ## json argument object, the wait's own bound in seconds
	local rigBound="${2:-2}"
	( cd "$rigWs" && printf '%s' "$1" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT MDAT_SPAWN_SESSION_ID="$rigSession" MMDAPP="$rigWs" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT="$rigBound" PATH="$rigWs/bin:$PATH" \
		bash "$rigHarness" --intern-tool Wait ) > "$rigWs/out" 2> "$rigWs/err"
}
rigHead(){ LC_ALL=C head -1 "$rigWs/out" | LC_ALL=C sed 's/ (.*//' ; }
rigLines(){ LC_ALL=C grep -c -e "$1" "$rigWs/out" ; }

echo "-- 1. a Wait that named a source, come back quiet --"
mkdir -p "$rigFolder"
printf -- '- [x] Read the plan\n- [ ] Fix the index (in progress: Fixing the index)\n- [ ] Run the suite\n' > "$rigList"
rigCall "{\"sources\":\"file:$rigFile\",\"timeout\":2}"
rigAssert "the call is a TIMEOUT" "$( rigHead )" "WAIT-RESULT: TIMEOUT"
rigAssert "the count is carried, and only the count" "$( rigLines '^CHECKLIST: 1 pending, 1 in progress$' )" "1"
rigAssert "no item is carried" "$( rigLines '^- \[ \] ' )" "0"

echo "-- 2. a wait that delivers an arrival --"
: > "$rigFile"
( sleep 1 ; printf 'arrived\n' > "$rigFile" ) &
rigCall "{\"sources\":\"file:$rigFile\",\"timeout\":8}" 8
rigAssert "the arrival is delivered" "$( LC_ALL=C head -1 "$rigWs/out" )" "WAIT-RESULT: RECEIVED"
rigAssert "the arrival carries the count too" "$( rigLines '^CHECKLIST: 1 pending, 1 in progress$' )" "1"
rigAssert "and still no item" "$( rigLines '^- \[ \] ' )" "0"

echo "-- 3. every item closed, and no list at all --"
printf -- '- [x] Read the plan\n- [x] Fix the index\n- [x] Run the suite\n' > "$rigList"
rigCall "{\"mode\":\"continue\"}"
rigAssert "a closed list says how many" "$( rigLines '^CHECKLIST: all 3 closed$' )" "1"
rm -f "$rigList"
rigCall "{\"mode\":\"continue\"}"
rigAssert "a session with no list is told to write one" "$( rigLines '^CHECKLIST: none on record, so write one with CheckList$' )" "1"

echo "-- 4. an idle Wait returns the open items at once --"
printf -- '- [x] Read the plan\n- [ ] Fix the index (in progress: Fixing the index)\n- [ ] Run the suite\n' > "$rigList"
date +%s > "$rigFolder/handback.given"
rigCall '{"timeout":2}'
rigAssert "it returns the items, not a wait" "$( LC_ALL=C head -1 "$rigWs/out" )" "CHECKLIST: 1 pending, 1 in progress. Finish or close them before you wait for DISMISSED."
rigAssert "the pending item is carried" "$( rigLines '^- \[ \] ' )" "1"
rigAssert "the in-progress item is never carried as a line" "$( rigLines '^- \[~\] ' )" "0"
rigAssert "nothing was waited on" "$( rigLines '^WAIT-RESULT' )" "0"

echo "-- 5. the same call again, with the list unchanged, returns them again --"
rigCall '{"timeout":2}'
rigAssert "the list is the queue, so it returns again, not a wait" "$( LC_ALL=C head -1 "$rigWs/out" )" "CHECKLIST: 1 pending, 1 in progress. Finish or close them before you wait for DISMISSED."
rigAssert "the pending item is carried again" "$( rigLines '^- \[ \] ' )" "1"
rigAssert "and still no wait" "$( rigLines '^WAIT-RESULT' )" "0"

echo "-- 6. mode continue is waiting on purpose, and checks nothing --"
rigCall '{"mode":"continue","timeout":2}'
rigAssert "it makes the ordinary wait" "$( rigHead )" "WAIT-RESULT: TIMEOUT"
rigAssert "and carries the count alone" "$( rigLines '^CHECKLIST: 1 pending, 1 in progress$' )" "1"

echo "-- 7. an idle Wait with nothing open waits --"
printf -- '- [x] Read the plan\n- [x] Fix the index\n- [x] Run the suite\n' > "$rigList"
rigCall '{"timeout":2}'
rigAssert "nothing open, so it waits" "$( rigHead )" "WAIT-RESULT: TIMEOUT"
rigAssert "and says the list is closed" "$( rigLines '^CHECKLIST: all 3 closed$' )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS WAIT CHECKLIST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_WAIT_CHECKLIST: OK (%d assertions, offline)\n' "$rigPassCount"
