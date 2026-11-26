#!/usr/bin/env bash
## Behavioural check on the polling bound of the MCP client's wait for an answer (AgentsHarnessMcpReply, sh-lib/harness/AgentsHarnessMcpClient.sh).
## A server writes its answer to the handshake first, so from the first poll on the output holds whole lines that are none of the awaited
## answer. A poll that parses those same lines again costs a process for the read and one for the parse, a second, in every live call that
## waits on a server. Held:
##   1. eight polls over output that holds no answer to the id awaited parse it once
##   2. the control: the answer appended to that output is returned by the next poll, so 1 is no cache that hides what arrives
##   3. the control: another id awaited over the same output is parsed and answered, so what is kept is per id
## The parse is counted by a stand-in for awk that counts its calls and runs the real one. Offline: no request, no host.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHere/harness/AgentsHarnessMcpClient.sh" "$rigHere/harness/AgentsHarnessMcpConfig.include" "$rigHere/harness/AgentsHarnessArgTable.awk" "$rigHere/harness/AgentsHarnessJsonField.awk" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
## The function from its own `Name(){` line to the first line that is a lone `}`.
rigLift="$( LC_ALL=C awk '
	/^AgentsHarnessMcpReply\(\)\{/ { inFn = 1 ; }
	inFn { print ; }
	inFn && /^\}$/ { inFn = 0 ; seen++ ; }
	END { if ( seen != 1 ) exit 1 ; }
' "$rigHere/harness/AgentsHarnessMcpClient.sh" )" || rigRefuse "AgentsHarnessMcpReply was not found in AgentsHarnessMcpClient.sh"
. "$rigHere/harness/AgentsHarnessMcpConfig.include" || rigRefuse "AgentsHarnessMcpConfig.include does not load"
eval "$rigLift"
harnessHere="$rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
harnessScratch="$( rigTempDir AgentsHarnessMcpReplyPollBoundCheck )" || exit 1
trap 'rm -rf -- "$harnessScratch"' EXIT
rigCount="$harnessScratch/awk.count"
awk(){ printf 'x' >> "$rigCount" ; [ ! -e "$harnessScratch/awk.fail" ] || return 1 ; command awk "$@" ; }

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## How many parses the stand-in has counted.
rigParses(){
	local parsesText=""
	IFS= read -r -d '' parsesText < "$rigCount" 2> /dev/null || :
	printf '%s' "${#parsesText}"
}

printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05"}}' > "$harnessScratch/mcp.out"
: > "$rigCount"

echo "-- 1. eight polls over output with no answer to the id awaited --"
rigPoll=0 rigWins=0
while [ "$rigPoll" -lt 8 ] ; do
	AgentsHarnessMcpReply 3 && rigWins=$(( rigWins + 1 ))
	rigPoll=$(( rigPoll + 1 ))
done
rigAssert "no poll found an answer where there was none" "$rigWins" "0"
rigAssert "and the output was parsed once" "$( rigParses )" "1"

echo "-- 2. the control: the answer arrives --"
printf '%s\n' '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"rig-answer"}]}}' >> "$harnessScratch/mcp.out"
AgentsHarnessMcpReply 3 && rigFound=yes || rigFound=no
rigAssert "the next poll returns it" "$rigFound" "yes"
rigAssert "and it is the answer of the id awaited" "$( printf '%s' "$harnessMcpReply" | LC_ALL=C grep -c 'rig-answer' )" "1"

echo "-- 3. the control: another id over the same output --"
printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05"}}' > "$harnessScratch/mcp.out"
AgentsHarnessMcpReply 3 && rigFound=yes || rigFound=no
rigAssert "an id with no answer in it still has none" "$rigFound" "no"
AgentsHarnessMcpReply 1 && rigFound=yes || rigFound=no
rigAssert "an id the output answers is answered after the one that had none" "$rigFound" "yes"

echo "-- 4. the control: a parse that fails once is not kept as no answer --"
printf '%s\n' '{"jsonrpc":"2.0","id":5,"result":{"content":[{"type":"text","text":"late-answer"}]}}' > "$harnessScratch/mcp.out"
: > "$harnessScratch/awk.fail"
AgentsHarnessMcpReply 5 && rigFound=yes || rigFound=no
rigAssert "a poll whose parse fails finds nothing" "$rigFound" "no"
rm -f "$harnessScratch/awk.fail"
AgentsHarnessMcpReply 5 && rigFound=yes || rigFound=no
rigAssert "the next poll over the same output finds the answer" "$rigFound" "yes"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ MCP REPLY POLL BOUND CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_REPLY_POLL_BOUND: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
