#!/usr/bin/env bash
## Behavioural check of the asks a member's tagged probe returns from the ask records themselves (AgentsWaitAddressedAsks):
## every open ask of another member that names the member in address-to, asked after the floor, behind a `# in <channel>:<thread
## ts>` line -- an ask posted inside another session's thread, which no history read and no search reaches, is the member's all
## the same. An open ask from before the floor that it was never shown is returned once, and never again. Its own ask, an answered
## ask and an ask of someone else are not. Offline: a temp workspace holding pending records only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberWaitMentions.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigLib" ] || rigRefuse "the probe library is not at the origin: $rigLib"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitAddressedAsksCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
mkdir -p "$rigTmp/ws/.local/agents/pending"
rigAsk(){ ## id, status, owner, address-to, question-ts, question line
	printf -- '---\nstatus: %s\nowner: %s\nkind: question\naddress-to: %s\nchannel: DRIG00001\nquestion-ts: %s\nthread-ts: 1700000001.000100\n---\n\n# Question asked\n\n# ❓ Question\n\n%s\n' \
		"$2" "$3" "$4" "$5" "$6" > "$rigTmp/ws/.local/agents/pending/$1.md"
}
rigAsk ask-open      reply-pending  keeper-rig          magic-coordinator               1700000005.000500 "May the rig go on?"
rigAsk ask-own       reply-pending  magic-coordinator   magic-coordinator               1700000006.000600 "Its own ask"
rigAsk ask-old       reply-pending  keeper-rig          magic-coordinator               1700000001.000150 "Asked before the floor"
rigAsk ask-done      reply-received keeper-rig          magic-coordinator               1700000007.000700 "Answered already"
rigAsk ask-other     reply-pending  keeper-rig          magic-tester                    1700000008.000800 "For someone else"
rigAsk ask-two       reply-pending  keeper-rig          "magic-tester magic-coordinator" 1700000009.000900 "For two members"
rigRun(){ ## member, floor
	( MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" 2> /dev/null ; AgentsWaitAddressedAsks "$2" "$3"' rig "$rigLib" "$1" "$2" )
}
rigOut="$( rigRun magic-coordinator 1700000002 )"

echo "-- an open ask of another member, naming the member, after the floor, is returned --"
rigAssert "the open ask, with its asker and its record"      "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -x '1700000005.000500 | keeper-rig | \[ask: ask-open.md\] May the rig go on?' )" 1
## Three asks of this call stand in the one thread: the open one, the one for two members, and the one from before the floor shown once.
rigAssert "behind the thread it was asked in"                 "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -x '# in DRIG00001:1700000001.000100' )" 3
rigAssert "an ask naming two members reaches each"           "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'ask-two.md' ):$( rigRun magic-tester 1700000002 | LC_ALL=C grep -c 'ask-two.md' )" "1:1"

echo "-- and nothing else is --"
rigAssert "never the member's own ask"                        "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'ask-own.md' )" 0
rigAssert "an open ask from before the floor, never shown: once" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'ask-old.md' )" 1
rigAssert "and never again past the floor"                    "$( rigRun magic-coordinator 1700000002 | LC_ALL=C grep -c 'ask-old.md' )" 0
rigAssert "while a new one past the floor is returned again"  "$( rigRun magic-coordinator 1700000002 | LC_ALL=C grep -c 'ask-open.md' )" 1
rigAssert "never one already answered"                        "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'ask-done.md' )" 0
rigAssert "never one of someone else"                         "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'ask-other.md' )" 0
rigAssert "with no floor, the one before it is returned too"  "$( rigRun magic-coordinator '' | LC_ALL=C grep -c 'ask-old.md' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT ADDRESSED ASKS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_ADDRESSED_ASKS: OK (%d assertions, offline, temp workspace only)\n' "$rigPassCount"
