#!/usr/bin/env bash
## Behavioural check on the email driver (epic T7): its address resolver over the channel-id split
## and the declared-channel ordering, and its send over the mail ops. Offline, no model -- the
## declared-name path runs over the pure ordering core, and the mail send is stubbed at
## DistroAgentsTools so the delegation is observed without reaching the dispatcher or the network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/comms/AgentsTools.CommsEmail.include" ] || rigRefuse "the email driver is not at the origin this workspace resolves"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The abstraction first, then its declared-name resolver is overridden to the rows the pure
## ordering core orders, so no distro index and no network are needed. The driver sources the
## abstraction itself, so it is loaded once here and the driver's own guard is then a no-op.
. "$rigHere/comms/AgentsTools.CommsChannel.include"

rigDeclaredRows='orders	slack	CORDERS01
orders	email	orders@rig.invalid
orders	telegram	111
solo	telegram	999'
AgentsToolsCommsChannelResolveDeclared(){
	printf '%s\n' "$rigDeclaredRows" | AgentsToolsCommsChannelOrderDeclares "$1"
}

## The mail send is the observation point: what the driver hands the mail ops, args and stdin.
rigMailArgs=""
rigMailStdin=""
DistroAgentsTools(){ rigMailArgs="$*" ; rigMailStdin="$( cat )" ; return 0 ; }

. "$rigHere/comms/AgentsTools.CommsEmail.include"

echo "-- an email channel resolves to its bare address --"
rigAssert "an email id" "$( AgentsToolsCommsEmailResolveAddress 'email:rig@rig.invalid' )" "rig@rig.invalid"
rigAssert "an email id whose address holds a colon" "$( AgentsToolsCommsEmailResolveAddress 'email:rig+tag@rig.invalid' )" "rig+tag@rig.invalid"
rigAssert "a bare address is its own coordinate" "$( AgentsToolsCommsEmailResolveAddress 'owner@rig.invalid' )" "owner@rig.invalid"
rigAssert "a name resolves to its declared email coordinate" "$( AgentsToolsCommsEmailResolveAddress orders )" "orders@rig.invalid"
rigAssert "a slack id names no email address" "$( AgentsToolsCommsEmailResolveAddress 'slack:CORDERS01' ; echo rc=$? )" "rc=1"
rigAssert "a telegram id names no email address" "$( AgentsToolsCommsEmailResolveAddress 'telegram:111' ; echo rc=$? )" "rc=1"
rigAssert "an empty email id names no email address" "$( AgentsToolsCommsEmailResolveAddress 'email:' ; echo rc=$? )" "rc=1"
rigAssert "a name with no declared email coordinate names none" "$( AgentsToolsCommsEmailResolveAddress solo ; echo rc=$? )" "rc=1"

echo "-- the send goes through the mail ops --"
rigMailArgs="" rigMailStdin=""
## A herestring, not a pipe: the function must run in the current shell so the stubbed
## DistroAgentsTools writes the captured args and stdin back where the assertions read them.
AgentsToolsCommsEmailSend magic-coordinator orders "the subject" <<< 'hello over email'
rigAssert "the send names the mail op, the member and the resolved address" "$rigMailArgs" "--intern-op-comms-email-send magic-coordinator orders@rig.invalid -- the subject -- --from-stdin"
rigAssert "the body rides through stdin" "$rigMailStdin" "hello over email"
rigAssert "an id that names no address refuses before the mail op" "$( AgentsToolsCommsEmailSend magic-coordinator 'slack:CORDERS01' s <<< 'x' ; echo rc=$? )" "rc=1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COMMS EMAIL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_EMAIL: OK (%d assertions, offline, no model)\n' "$rigPassCount"
