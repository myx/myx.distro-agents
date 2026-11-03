#!/usr/bin/env bash
## Behavioural check on Wait's one-off form (S22 item 8, `20261026-refactorings.epic.md:144`: "Wait has a one-off form: one
## named source, read once, ideally with timeout 0. It leaves the registered sources untouched."). Through the real Wait tool
## (AgentsUniversalHarness.sh --intern-tool Wait) and its own stateful call, offline: a plain file: source, and a curl that fails
## at once, so no request leaves the machine. Held:
##   1. one named source is read once and what is there is returned
##   2. the read is one round: the bound it names is not spent, so a source with nothing there returns at once
##   3. the registered sources are untouched: the stored wait is the same file, byte for byte, before and after
##   4. the form needs exactly one source: none named, and two named, are each refused and read nothing
##   5. the source it read never joined the stored wait, so a continued wait is not watching it
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessWaitOneOffCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/bin"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
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
rigSession="rig-wait-oneoff"
rigFolder="$rigWs/.local/agents/sessions/$rigSession"
rigState="$rigFolder/wait/state"
rigFile="$rigWs/one.txt"
rigOther="$rigWs/other.txt"
printf 'on hand\n' > "$rigFile"
printf 'also on hand\n' > "$rigOther"
mkdir -p "$rigFolder"

rigCall(){ ## json argument object
	( cd "$rigWs" && printf '%s' "$1" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT MDAT_SPAWN_SESSION_ID="$rigSession" MMDAPP="$rigWs" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=2 PATH="$rigWs/bin:$PATH" \
		bash "$rigHarness" --intern-tool Wait ) > "$rigWs/out" 2> "$rigWs/err"
}
rigHead(){ LC_ALL=C head -1 "$rigWs/out" | LC_ALL=C sed 's/ (.*//' ; }
rigLines(){ LC_ALL=C grep -c -e "$1" "$rigWs/out" ; }
## The two fields the one-off's own line carries: the polls it made, and the bound it named. The seconds it took are a
## clock, and a read that spans a second boundary on a loaded host reports them as spent; they say nothing about rounds.
rigOneRound(){ LC_ALL=C sed -n 's/^# waited: [0-9]*s of \([^,]*\), \([0-9]*\) poll round(s) .*/\2 polls, \1/p' "$rigWs/out" ; }

## A stored wait to leave alone: one plain Wait over one file writes it.
rigCall "{\"sources\":\"file:$rigFile\",\"timeout\":1}"
rigAssert "a plain Wait stores a wait to leave alone" "$( [ -f "$rigState" ] && printf yes || printf no )" "yes"
rigBefore="$( LC_ALL=C cksum < "$rigState" )"

echo "-- 1. one named source, read once, and what is there comes back --"
rigCall "{\"mode\":\"once\",\"sources\":\"file:$rigFile\",\"since_utime\":\"0\",\"timeout\":8}"
rigAssert "the source is read and returned" "$( rigHead )" "WAIT-RESULT: RECEIVED"
rigAssert "what it holds is carried" "$( rigLines 'on hand' )" "1"
rigAssert "the read is one round: its own line says so, one poll and no bound spent" "$( rigOneRound )" "1 polls, 0s bound"

echo "-- 2. the registered sources are untouched --"
rigAssert "the stored wait is the same file, byte for byte" "$( LC_ALL=C cksum < "$rigState" )" "$rigBefore"

echo "-- 3. one round only: a source with nothing there returns at once --"
: > "$rigWs/empty.txt"
rigCall "{\"mode\":\"once\",\"sources\":\"file:$rigWs/empty.txt\",\"since_utime\":\"0\",\"timeout\":8}"
rigAssert "the read comes back with nothing" "$( rigHead )" "WAIT-RESULT: TIMEOUT"
rigAssert "and it is one round, so the bound it named was never spent" "$( rigOneRound )" "1 polls, 0s bound"

echo "-- 4. exactly one source, and no less --"
rigCall '{"mode":"once","timeout":2}'
rigAssert "none named is refused" "$( LC_ALL=C head -1 "$rigWs/out" | cut -c1-5 )" "ERROR"
rigAssert "and nothing is waited on" "$( rigLines '^WAIT-RESULT' )" "0"
rigCall "{\"mode\":\"once\",\"sources\":\"file:$rigFile file:$rigOther\",\"timeout\":2}"
rigAssert "two named are refused" "$( LC_ALL=C head -1 "$rigWs/out" | cut -c1-5 )" "ERROR"
rigAssert "and nothing is waited on there either" "$( rigLines '^WAIT-RESULT' )" "0"

echo "-- 5. the source it read never joined the stored wait --"
rigAssert "the stored wait still holds what it held" "$( LC_ALL=C cksum < "$rigState" )" "$rigBefore"
rigCall '{"mode":"continue","timeout":1}'
rigAssert "a continued wait does not report the one-off's source" "$( rigLines 'arrived on: file:' )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS WAIT ONE-OFF CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_WAIT_ONEOFF: OK (%d assertions, offline)\n' "$rigPassCount"
