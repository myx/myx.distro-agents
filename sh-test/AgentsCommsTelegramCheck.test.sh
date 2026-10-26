#!/usr/bin/env bash
## Behavioural check on the Telegram driver (epic T7): the bot-token resolver's environment-before-
## scope fallback (the Slack driver's shape), the bare chat-id gate, the address resolver over the
## channel-id split and the declared-channel ordering, and the send over the Telegram Bot API.
## Offline, no model -- the declared-name path runs over the pure ordering core, and curl is stubbed
## so the send is observed without reaching the network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/comms/AgentsTools.CommsTelegram.include" ] || rigRefuse "the telegram driver is not at the origin this workspace resolves"

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
. "$rigHere/comms/AgentsTools.CommsSide.include"

rigDeclaredRows='orders	slack	CORDERS01
orders	email	orders@rig.invalid
orders	telegram	111'
AgentsToolsCommsChannelResolveDeclared(){
	printf '%s\n' "$rigDeclaredRows" | AgentsToolsCommsChannelOrderDeclares "$1"
}

## The scope read is stubbed to one value the test sets, so the token resolver's fallback chain is
## observable without a config store.
rigScopeToken=""
DistroAgentsTools(){
	case "$*" in
		*"--select TELEGRAM_BOT_TOKEN") [ -n "$rigScopeToken" ] && printf '%s\n' "$rigScopeToken" || return 1 ;;
		*) echo "unexpected DistroAgentsTools call: $*" >&2 ; return 1 ;;
	esac
}

. "$rigHere/comms/AgentsTools.CommsTelegram.include"

echo "-- the bot token resolves environment-before-scope, like Slack's --"
TELEGRAM_BOT_TOKEN="env-bot-token-ENV"
rigAssert "the environment's token is used, before any scope" "$( AgentsToolsResolveTelegramBotToken magic-coordinator )" "environment-bot-token env-bot-token-ENV"
unset TELEGRAM_BOT_TOKEN
rigScopeToken="member-token"
rigAssert "with no environment the member scope is used" "$( AgentsToolsResolveTelegramBotToken magic-coordinator )" "member-bot-token member-token"
rigScopeToken="shared-token"
rigAssert "magic-team's own scope is the shared scope" "$( AgentsToolsResolveTelegramBotToken magic-team )" "shared-bot-token shared-token"
rigScopeToken=""
rigAssert "with no token anywhere the resolver refuses" "$( AgentsToolsResolveTelegramBotToken magic-team 2>/dev/null ; echo rc=$? )" "rc=1"

echo "-- the bare chat-id gate --"
rigAssert "a bare chat id" "$( AgentsToolsCommsTelegramBareChatId 123 && echo yes || echo no )" yes
rigAssert "a signed group chat id" "$( AgentsToolsCommsTelegramBareChatId -1001234567890 && echo yes || echo no )" yes
rigAssert "a minus not at the head is no chat id" "$( AgentsToolsCommsTelegramBareChatId 1-2 && echo yes || echo no )" no
rigAssert "a word of letters is no chat id" "$( AgentsToolsCommsTelegramBareChatId orders && echo yes || echo no )" no
rigAssert "a lone minus is no chat id" "$( AgentsToolsCommsTelegramBareChatId - && echo yes || echo no )" no

echo "-- a telegram channel resolves to its bare chat id --"
rigAssert "a telegram id" "$( AgentsToolsCommsTelegramResolveAddress 'telegram:123456789' )" "123456789"
rigAssert "a signed telegram id" "$( AgentsToolsCommsTelegramResolveAddress 'telegram:-1001234567890' )" "-1001234567890"
rigAssert "a bare chat id is its own coordinate" "$( AgentsToolsCommsTelegramResolveAddress '123456789' )" "123456789"
rigAssert "a name resolves to its declared telegram coordinate" "$( AgentsToolsCommsTelegramResolveAddress orders )" "111"
rigAssert "an email id names no telegram chat id" "$( AgentsToolsCommsTelegramResolveAddress 'email:rig@rig.invalid' ; echo rc=$? )" "rc=1"
rigAssert "a slack id names no telegram chat id" "$( AgentsToolsCommsTelegramResolveAddress 'slack:CORDERS01' ; echo rc=$? )" "rc=1"

echo "-- the send posts to the Telegram Bot API --"
## curl runs inside the send's command substitution, a subshell, so its captured args and stdin
## are written to files the assertions read back in the current shell. Under the workspace temp,
## never the system's.
mkdir -p "$MMDAPP/.local/temp"
rigCurlFile="$( mktemp "$MMDAPP/.local/temp/mdat-telegram-curl.XXXXXX" )" || rigRefuse "mktemp failed"
rigStdinFile="$( mktemp "$MMDAPP/.local/temp/mdat-telegram-stdin.XXXXXX" )" || rigRefuse "mktemp failed"
rigCurlBody='{"ok":true,"result":{"message_id":7}}'
curl(){
	printf '%s\n' "$*" > "$rigCurlFile"
	cat > "$rigStdinFile"
	printf '%s\n' "$rigCurlBody"
	return 0
}
TELEGRAM_BOT_TOKEN="tg-token-123"
AgentsToolsCommsTelegramSend magic-coordinator 'telegram:123456789' <<< 'hello over telegram' >/dev/null 2>&1
rigAssert "the send targets sendMessage with the resolved chat id and the token in the URL" \
	"$( grep -c 'api.telegram.org/bottg-token-123/sendMessage' "$rigCurlFile" )" "1"
rigAssert "the chat id rides as a form field" "$( grep -c 'chat_id=123456789' "$rigCurlFile" )" "1"
rigAssert "the text rides as a urlencoded stdin field, never argv" "$( grep -c 'text@-' "$rigCurlFile" )" "1"
rigAssert "the body is what stdin carried" "$( cat "$rigStdinFile" )" "hello over telegram"

rigCurlBody='{"ok":false,"description":"chat not found"}'
rigAssert "an ok:false response is a refused send" "$( AgentsToolsCommsTelegramSend magic-coordinator 'telegram:1' <<< 'x' 2>/dev/null ; echo rc=$? )" "rc=1"
unset TELEGRAM_BOT_TOKEN
rigAssert "no token refuses before the network" "$( AgentsToolsCommsTelegramSend magic-coordinator 'telegram:1' <<< 'x' 2>/dev/null ; echo rc=$? )" "rc=1"

rm -f "$rigCurlFile" "$rigStdinFile"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COMMS TELEGRAM CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_TELEGRAM: OK (%d assertions, offline, no model)\n' "$rigPassCount"
