#!/usr/bin/env bash
## Behavioural check that AgentsSlackBlocksBuild.awk's bare-URL/bare-address
## branch reaches a real send, through --member-comms-slack-send-message's
## default markdown path, with the fake curl fixture capturing the posted
## body. The unit-level proof lives in AgentsSlackBlocksLinkifyCheck.test.sh;
## this rig additionally proves the tooling-built preamble carries no link
## element of its own, only the agent text block does. Offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t "AgentsSlackBareUrlLinkCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin"

cp "$rigHere/check-fixtures/slack-send-identity-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigHere/check-fixtures/slack-send-identity-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## Whether $1 (a captured body) contains the literal substring $2.
rigHas(){
	case "$1" in *"$2"*) printf yes ;; *) printf no ;; esac
}
## How many separate "link" elements the body carries.
rigLinkCount(){
	printf '%s' "$1" | LC_ALL=C grep -o '"type":"link"' | LC_ALL=C grep -c . || :
}

## Sends agent text through the real path and returns the one captured
## chat.postMessage body (trailing argv -- one line, no embedded newline).
rigSend(){ ## text...
	: > "$rigTmp/bodies"
	local sendOut=""
	sendOut="$( cd "$rigWs" && env -u MDAT_DATA_ROOT RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --member-comms-slack-send-message keeper-myx magic-team --identity-bot "$@" 2>&1 )" \
		|| { printf 'send-failed: %s' "$( printf '%s\n' "$sendOut" | grep 'ERROR' | head -1 )" ; return 0 ; }
	cat "$rigTmp/bodies"
}
## Same, but the body arrives on this function's own stdin (for a fence,
## which trailing argv cannot carry -- it joins words with spaces, no
## newlines).
rigSendStdin(){
	: > "$rigTmp/bodies"
	local sendOut=""
	sendOut="$( cd "$rigWs" && env -u MDAT_DATA_ROOT RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --member-comms-slack-send-message keeper-myx magic-team --identity-bot --from-stdin 2>&1 )" \
		|| { printf 'send-failed: %s' "$( printf '%s\n' "$sendOut" | grep 'ERROR' | head -1 )" ; return 0 ; }
	cat "$rigTmp/bodies"
}

## The subject has to be reachable before anything is asserted about it.
rigSend 'Smoke test line.' > /dev/null
grep -q '^chat.postMessage ' "$rigTmp/calls" || rigRefuse "no send reached the fake curl at all, so no case below would be measured"

echo "-- bare URL and bare address become real link elements through the send path --"
rigJson="$( rigSend 'See https://example.com/path for details.' )"
rigAssert "a bare https URL becomes a link element in the posted body" \
	"$( rigHas "$rigJson" '{"type":"link","url":"https://example.com/path","text":"https://example.com/path"}' )" yes
rigAssert "the tooling-built preamble carries no link element of its own" \
	"$( rigLinkCount "$rigJson" )" 1
rigAssert "the plain top-level text field still carries the bare url exactly as typed, not enriched" \
	"$( rigHas "$( printf '%s' "$rigJson" | grep -o '"text":"[^"]*"' | head -1 )" 'See https://example.com/path for details.' )" yes

rigJson="$( rigSend 'See http://example.org/info for details.' )"
rigAssert "a bare http URL becomes a link element in the posted body" \
	"$( rigHas "$rigJson" '{"type":"link","url":"http://example.org/info","text":"http://example.org/info"}' )" yes

rigJson="$( rigSend 'Contact myx@meloscope.com for help.' )"
rigAssert "a bare address becomes bold plain text, not a link" \
	"$( rigHas "$rigJson" '{"type":"text","text":"myx@meloscope.com","style":{"bold":true}}' )" yes
rigAssert "a bare address never becomes a mailto link" \
	"$( rigHas "$rigJson" 'mailto:' )" no

echo "-- skipped by construction: code span, fence, existing link --"
rigJson="$( rigSend 'Use `http://example.com` literally.' )"
rigAssert "a url inside a code span is never linkified" \
	"$( rigHas "$rigJson" '"type":"link"' )" no

rigJson="$( printf '%s\n' '```' 'https://example.com' '```' | rigSendStdin )"
rigAssert "a url inside a fence is never linkified" \
	"$( rigHas "$rigJson" '"type":"link"' )" no
rigAssert "and posts as preformatted text" \
	"$( rigHas "$rigJson" 'rich_text_preformatted' )" yes

rigJson="$( rigSend 'See [Click here](https://example.com/page) now.' )"
rigAssert "an existing [text](url) link keeps its own label" \
	"$( rigHas "$rigJson" '{"type":"link","url":"https://example.com/page","text":"Click here"}' )" yes
rigAssert "and is not also linkified a second time as a bare url" \
	"$( rigLinkCount "$rigJson" )" 1

echo "-- trailing punctuation and a lone bracket are stripped through the send path --"
rigJson="$( rigSend 'Visit https://example.com/path. Thanks.' )"
rigAssert "a trailing full stop is stripped from the posted link" \
	"$( rigHas "$rigJson" '{"type":"link","url":"https://example.com/path","text":"https://example.com/path"}' )" yes
rigAssert "the stripped stop reappears as its own literal text" \
	"$( rigHas "$rigJson" '{"type":"text","text":". Thanks."}' )" yes

rigJson="$( rigSend 'See (https://example.com/path) now.' )"
rigAssert "a lone wrapping bracket is stripped from the posted link" \
	"$( rigHas "$rigJson" '{"type":"link","url":"https://example.com/path","text":"https://example.com/path"}' )" yes

echo "-- the url check wins over the address check, through the send path --"
rigJson="$( rigSend 'Open https://user@host/path now.' )"
rigAssert "https://user@host/path posts as ONE url link" \
	"$( rigHas "$rigJson" '{"type":"link","url":"https://user@host/path","text":"https://user@host/path"}' )" yes
rigAssert "never also a mailto link out of the same span" \
	"$( rigHas "$rigJson" 'mailto:' )" no

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK BARE URL LINK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_BARE_URL_LINK: OK (%d assertions, offline)\n' "$rigPassCount"
