#!/usr/bin/env bash
## Behavioural check: a Wait still on an ask whose record was closed writes no `.direct` cache into the live store.
## Closing an ask moves its record and every sidecar to pending/closed/. AgentsWaitAskDirectRead caches whether the
## ask's conversation is a direct message in `<record>.direct`, beside the record. With the record gone from the live
## store it returns at once and writes nothing there, so no orphan cache is left behind.
## Offline: the workspace is this rig's own temp tree. No socket: both cases return before any Slack read.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPkg/sh-lib/wait/AgentsTools.MemberWaitAsk.include" ] || rigRefuse "the Wait ask include is not at the origin"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitAskDirectClosedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigPending="$rigWs/.local/agents/pending"
mkdir -p "$rigPending/closed" "$rigWs/.local/.agents"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigDirect(){ ## record file, channel -- the call's exit code
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash -c '. "$1" ; AgentsWaitAskDirectRead keeper-x "$2" "$3" 1700000000.000100 U0RIG U0BOT bot "$4" 1700000000.000100' rig \
		"$rigPkg/sh-lib/wait/AgentsTools.MemberWaitAsk.include" "$1" "$2" "$rigTmp/render" > /dev/null 2>&1
	echo "$?"
}

echo "-- a closed ask leaves no cache in the live store --"
rigClosed="$rigPending/rig-closed-1.md"
printf '%s\n' "---" "status: answered" "---" > "$rigPending/closed/rig-closed-1.md"
rigAssert "a record moved to closed/: the call returns 1" "$( rigDirect "$rigClosed" D0RIG00001 )" "1"
rigAssert "a record moved to closed/: no .direct beside where it was" "$( [ -e "$rigPending/rig-closed-1.direct" ] && echo present || echo absent )" "absent"
echo "-- a conversation that is not direct is never cached --"
printf '%s\n' "---" "status: reply-pending" "---" > "$rigPending/rig-live-1.md"
rigAssert "a channel conversation: the call returns 1" "$( rigDirect "$rigPending/rig-live-1.md" C0RIG00001 )" "1"
rigAssert "a channel conversation: no .direct" "$( [ -e "$rigPending/rig-live-1.direct" ] && echo present || echo absent )" "absent"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ WAIT ASK DIRECT CLOSED CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_ASK_DIRECT_CLOSED: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
