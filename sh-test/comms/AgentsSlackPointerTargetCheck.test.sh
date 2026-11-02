#!/usr/bin/env bash
## Behavioural check on the full pointer as a Slack target (epic S11 item 1; owner 2026-11-01: the communication id of any message is its
## full pointer, `slack:<conversation>:<ts>`). A Wait shows every message by that pointer, so the one resolver every Slack operation
## takes its target through (DistroAgentsToolsResolveTarget) must read it as it stands: a reply typed to the pointer lands in that
## message's thread, in a channel (C...) and in a direct conversation (D...) alike. Held, run and not read:
##   1. A pointer with a ts resolves to the same conversation and thread as the bare `<conversation>:<ts>` form, for a channel and for a DM.
##   2. A pointer to a conversation alone resolves to that conversation at its top, as the bare id does.
##   3. A word in front that is no driver is still refused, rc 3, with the line that says what to pass.
##   4. A pointer whose ts is no ts is refused as the bare form is.
## Offline: the resolver is called itself, in a rig workspace of its own, so no cache or setting of a real workspace is touched.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigPackage/sh-lib/comms/AgentsTools.CommsSlack.include" ] || rigRefuse "the Slack driver is not at the origin this workspace resolves: $rigPackage"

. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackPointerTargetCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
. "$rigPackage/sh-lib/comms/AgentsTools.CommsChannel.include"
## The include ends by dispatching its own arguments, and a source with none reads an unset $1.
set +u ; . "$rigPackage/sh-lib/comms/AgentsTools.CommsSlack.include" ; set -u

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigResolve(){ ## address -- the resolver's lines on one line, then its rc
	local resolveOut="" resolveRc=0
	resolveOut="$( MMDAPP="$rigTmp" DistroAgentsToolsResolveTarget "$1" keeper-myx 2>&1 )" || resolveRc=$?
	printf '%s|rc=%s' "$( printf '%s' "$resolveOut" | tr '\n' ' ' )" "$resolveRc"
}

echo "-- the bare form, the control: the instrument has to see a channel, a thread and a DM --"
rigAssert "a channel and a ts: the channel and the thread" "$( rigResolve C0RIG0001:1700000000.000100 )" "CHANNEL=C0RIG0001 THREAD_TS=1700000000.000100|rc=0"
rigAssert "a DM and a ts: the DM and the thread" "$( rigResolve D0RIG0002:1700000000.000200 )" "CHANNEL=D0RIG0002 THREAD_TS=1700000000.000200|rc=0"

echo "-- 1. a pointer with a ts is the same message --"
rigAssert "slack:<channel>:<ts> is that channel and thread" "$( rigResolve slack:C0RIG0001:1700000000.000100 )" "CHANNEL=C0RIG0001 THREAD_TS=1700000000.000100|rc=0"
rigAssert "slack:<DM>:<ts> is that DM and thread" "$( rigResolve slack:D0RIG0002:1700000000.000200 )" "CHANNEL=D0RIG0002 THREAD_TS=1700000000.000200|rc=0"

echo "-- 2. a pointer to a conversation alone is its top --"
rigAssert "the bare id: the conversation, no thread" "$( rigResolve C0RIG0001 )" "$( rigResolve slack:C0RIG0001 )"

echo "-- 3. a word in front that is no driver is refused --"
rigAssert "rig:<channel>:<ts> names no conversation, rc 3" "$( rigResolve rig:C0RIG0001:1700000000.000100 )" "'rig:C0RIG0001:1700000000.000100' names no conversation: 'rig' is not a Slack id. Pass the id of the conversation and the ts of the message, <channel>:<ts>, with no other word in front of them.|rc=3"

echo "-- 4. a ts that is no ts is refused as the bare form is --"
rigAssert "the bare form names no message, rc 3" "$( rigResolve C0RIG0001:not-a-ts | LC_ALL=C grep -c -E "'not-a-ts' is not a message ts\\..*\\|rc=3$" )" "1"
rigAssert "and so does the pointer" "$( rigResolve slack:C0RIG0001:not-a-ts | LC_ALL=C grep -c -E "'not-a-ts' is not a message ts\\..*\\|rc=3$" )" "1"

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
