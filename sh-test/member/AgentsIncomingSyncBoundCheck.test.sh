#!/usr/bin/env bash
## Behavioural check on S5.5: a start's read of the member's incoming is bounded, so a slow mail server cannot hold
## a spawn. The bound is `SPAWN_INCOMING_SYNC_SECONDS` (20 by default, 0 for none), and the read is the member's own
## inbox sync. Held here, with the sync replaced by this rig's own stand-in so nothing reaches a network:
##   1. a read slower than the bound is left running, and the call returns at the bound, saying so.
##   2. control: a read inside the bound returns at once with the read's own result.
##   3. a bound of 0 waits the read out, however long it takes.
## Red before S5.5: the call returned only when the read did, so case 1 waited the whole 8 seconds.
## Offline: every tree is the rig's own, and the stand-in reads no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigIncoming="$rigPkg/sh-lib/member/AgentsTools.Incoming.include"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigIncoming" ] || rigRefuse "the incoming include is not at the origin: $rigIncoming"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsIncomingSyncBoundCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigOne in $rigPids ; do kill -TERM "$rigOne" 2> /dev/null || : ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/home" "$rigTmp/bin"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSPAWN_INCOMING_SYNC_SECONDS=%s\n' "${rigBound:-2}" > "$rigWs/.local/.agents/magic-team.agent.env"

rigPass=0 ; rigFail=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi ; }

## The call, with the sync it runs replaced by a stand-in that sleeps as long as this rig says. Its output goes to a
## file and never through a pipe: a read left running holds a pipe's write end open, so a capture would wait for it.
rigRun(){ ## bound, the stand-in's seconds -- sets rigElapsed and rigOut
	local runBound="$1" runSleeps="$2" runStart runEnd
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSPAWN_INCOMING_SYNC_SECONDS=%s\n' "$runBound" > "$rigWs/.local/.agents/magic-team.agent.env"
	runStart="$( date +%s )"
	env -i MMDAPP="$rigWs" HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SLEEPS="$runSleeps" \
		bash -c '. "$1" ; AgentsToolsIncomingSync(){ sleep "$RIG_SLEEPS" ; printf "collect: mail:rig-member: 1 new\n" ; } ; AgentsToolsIncomingSyncBounded rig-member start' rig "$rigIncoming" > "$rigTmp/out.txt" 2>&1 || :
	runEnd="$( date +%s )"
	rigElapsed=$(( runEnd - runStart ))
	rigOut="$( cat "$rigTmp/out.txt" )"
}

echo "-- 1. a read slower than the bound is left, and the call returns at the bound (S5.5) --"
rigRun 2 8
## One assertion for both halves: a call that returned at the bound only because it read nothing is no pass.
rigAssert "it returns at the bound, and says the read was left" "$( [ "$rigElapsed" -le 5 ] && printf bound || printf waited ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'collect: bound: rig-member' )" "bound:1"

echo "-- 2. control: a read inside the bound returns at once, with its own line --"
rigRun 30 1
rigAssert "it returns inside the bound"                    "$( [ "$rigElapsed" -le 5 ] && printf quick || printf waited )" quick
rigAssert "and the read's own line is there"               "$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'collect: mail:rig-member: 1 new' )" 1

echo "-- 3. control: a bound of 0 waits the read out --"
rigRun 0 3
rigAssert "it waits for the read"                          "$( [ "$rigElapsed" -ge 3 ] && printf waited || printf early )" waited
rigAssert "and no bound is said"                           "$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'collect: bound:' )" 0

if [ "$rigFail" -ne 0 ] ; then
	printf '⛔ INCOMING SYNC BOUND CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" >&2 ; exit 1
fi
printf 'INCOMING_SYNC_BOUND: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
