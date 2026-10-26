#!/usr/bin/env bash
## Behavioural check on the communication-channel-id abstraction (epic T7): the driver registry
## (slack, email, telegram, printback) in preference order, the Slack driver's name-to-setting map, the
## channel-id split, and the declared-channel ordering -- the "several plugged at once, their
## order the preference" seam. The ordering is checked over rows fed to the pure core
## (AgentsToolsCommsChannelOrderDeclares), so no distro index and no network are needed.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/comms/AgentsTools.CommsChannel.include" ] || rigRefuse "the channel abstraction is not at the origin this workspace resolves"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

. "$rigHere/comms/AgentsTools.CommsChannel.include"

echo "-- the drivers, in preference order --"
rigAssert "slack, email, telegram and printback are the drivers" "$( AgentsToolsCommsChannelServices | tr '\n' ' ' )" "slack email telegram printback "
rigAssert "slack is a known service" "$( AgentsToolsCommsChannelServiceKnown slack && printf yes || printf no )" yes
rigAssert "telegram is a known service" "$( AgentsToolsCommsChannelServiceKnown telegram && printf yes || printf no )" yes
rigAssert "printback is a known service" "$( AgentsToolsCommsChannelServiceKnown printback && printf yes || printf no )" yes
rigAssert "whatsapp is no driver" "$( AgentsToolsCommsChannelServiceKnown whatsapp && printf yes || printf no )" no
rigAssert "slack is the first preference" "$( AgentsToolsCommsChannelServiceRank slack )" 1
rigAssert "email is the second preference" "$( AgentsToolsCommsChannelServiceRank email )" 2
rigAssert "telegram is the third preference" "$( AgentsToolsCommsChannelServiceRank telegram )" 3
rigAssert "printback is the fourth preference" "$( AgentsToolsCommsChannelServiceRank printback )" 4
rigAssert "a word that is no service has no rank" "$( AgentsToolsCommsChannelServiceRank sms )" ""

echo "-- the Slack driver's name-to-setting map --"
rigAssert "magic-team maps to its setting" "$( AgentsToolsCommsChannelSlackKey magic-team )" SLACK_CHANNEL_MAGIC_TEAM
rigAssert "human-owner maps to its setting" "$( AgentsToolsCommsChannelSlackKey human-owner )" SLACK_CHANNEL_HUMAN_OWNER
rigAssert "event-track maps to its setting" "$( AgentsToolsCommsChannelSlackKey event-track )" SLACK_CHANNEL_EVENT_TRACK
rigAssert "event-alert maps to its setting" "$( AgentsToolsCommsChannelSlackKey event-alert )" SLACK_CHANNEL_EVENT_ALERT
rigAssert "a name that is no alias has no key" "$( AgentsToolsCommsChannelSlackKey other-name )" ""

echo "-- a channel id splits into service and address --"
rigAssert "slack with a ts" "$( AgentsToolsCommsChannelParse 'slack:C123:1700000000.000100' | tr '\n' '|' )" "SERVICE=slack|ADDRESS=C123|THREAD_TS=1700000000.000100|"
rigAssert "slack without a ts" "$( AgentsToolsCommsChannelParse 'slack:C123' | tr '\n' '|' )" "SERVICE=slack|ADDRESS=C123|"
rigAssert "an email address" "$( AgentsToolsCommsChannelParse 'email:rig@rig.invalid' | tr '\n' '|' )" "SERVICE=email|ADDRESS=rig@rig.invalid|"
rigAssert "a telegram chat id" "$( AgentsToolsCommsChannelParse 'telegram:123456789' | tr '\n' '|' )" "SERVICE=telegram|ADDRESS=123456789|"
rigAssert "a printback session, the root-native kind" "$( AgentsToolsCommsChannelParse 'printback:rig-session' | tr '\n' '|' )" "SERVICE=printback|ADDRESS=rig-session|"
rigAssert "a client marker is read as an address, no ts" "$( AgentsToolsCommsChannelParse 'slack:client:UNDMPERSON' | tr '\n' '|' )" "SERVICE=slack|ADDRESS=client:UNDMPERSON|"
rigAssert "no service is refused" "$( AgentsToolsCommsChannelParse 'chat:C123' | tr '\n' '|' )" ""
rigAssert "no address is refused" "$( AgentsToolsCommsChannelParse 'slack:' | tr '\n' '|' )" ""

echo "-- declared channels resolve in the driver preference order --"
rigAssert "a name declared on telegram, email and slack resolves slack first" "$( printf '%s\t%s\t%s\n%s\t%s\t%s\n%s\t%s\t%s\n' \
	'orders' telegram '111' \
	'orders' email 'orders@rig.invalid' \
	'orders' slack 'CORDERS01' \
	| AgentsToolsCommsChannelOrderDeclares orders | tr '\n' '|' )" "slack:CORDERS01|email:orders@rig.invalid|telegram:111|"
rigAssert "a name declared on one channel only resolves to just that one" "$( printf '%s\t%s\t%s\n' 'solo' telegram '999' | AgentsToolsCommsChannelOrderDeclares solo | tr '\n' '|' )" "telegram:999|"
rigAssert "a name with no declared channel resolves to nothing" "$( printf '%s\t%s\t%s\n' 'orders' slack 'CORDERS01' | AgentsToolsCommsChannelOrderDeclares nobody | tr '\n' '|' )" ""
rigAssert "rows for other names do not leak in" "$( printf '%s\t%s\t%s\n%s\t%s\t%s\n' 'a' slack 'CA' 'b' email 'b@rig.invalid' | AgentsToolsCommsChannelOrderDeclares b | tr '\n' '|' )" "email:b@rig.invalid|"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COMMS CHANNEL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_CHANNEL: OK (%d assertions, offline, no model)\n' "$rigPassCount"
