#!/usr/bin/env bash
## Behavioural check on --member-comms-email-send's new HTML part: a bare
## URL or address in the agent-written body becomes a real <a> link in the
## text/html part, with the same detection rules as
## AgentsSlackBlocksBuild.awk's own bare-URL/bare-address branch (lines
## ~395-440), ported into AgentsEmailHtmlBuild.awk. Drives the real send
## path (through DistroAgentsTools.fn.sh, not the awk file directly) with
## AGENTS_EMAIL_SEND_BUILD_ONLY=true, which prints the finished MIME
## message to stdout instead of ever reaching curl -- same offline shape as
## AgentsSlackBareUrlLinkCheck.test.sh, with a fake curl on PATH besides, as
## a hard backstop in case that gate is ever bypassed.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t "AgentsEmailHtmlPartCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin"

## A fake curl that is never meant to run at all -- unlike the Slack
## fixture's canned-response fake, this one's only job is to prove curl was
## never reached. Any call it logs fails the check outright, below.
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
printf 'curl invoked: %s\n' "$*" >> "$RIG_CURL_LOG"
exit 7
RIGCURL
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

printf 'EMAIL_USER=rig@example.com\nEMAIL_APP_PASSWORD=rig-app-password\nEMAIL_SMTP_HOST=smtp.rig.invalid\nEMAIL_SMTP_PORT=587\n' \
	> "$rigWs/.local/.agents/keeper-myx.agent.env"

## The send's outbound contact gate (AgentsToolsContactAssertKnown) refuses a
## recipient missing from the sender's own contacts note, before the build-only
## exit. The rig's recipient is listed there, in the contacts document format
## (templates/contacts.document.format.md), under the store this rig derives:
## no MDAT_DATA_ROOT is carried, so it is $MMDAPP/.local/agents/team-data-root.
mkdir -p "$rigWs/.local/agents/team-data-root/inboxes/keeper-myx"
printf '%s\n' \
	'| slack-id | contact | handle | email | organisation | permission level |' \
	'| --- | --- | --- | --- | --- | --- |' \
	'| <unresolved> | rig-test | @rig-test | test@example.com | rig | unset |' \
	> "$rigWs/.local/agents/team-data-root/inboxes/keeper-myx/note-rig-contacts.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## Whether $1 (a captured message) contains the literal substring $2.
rigHas(){
	case "$1" in *"$2"*) printf yes ;; *) printf no ;; esac
}
## Whether $2 appears in $1 strictly before $3 (both present, in that order).
rigOrder(){
	case "$1" in *"$2"*"$3"*) printf yes ;; *) printf no ;; esac
}
## How many times the literal substring $2 occurs in $1.
rigCount(){
	printf '%s' "$1" | LC_ALL=C grep -o -- "$2" | LC_ALL=C grep -c . || :
}

## Sends one message through the real path, build-only (never reaches curl):
## recipient, subject, and the body on this function's own stdin -- stdin,
## not trailing argv, so a fence's embedded newlines survive intact, same
## reasoning as AgentsSlackBareUrlLinkCheck.test.sh's rigSendStdin.
## An optional fourth argument sets --format explicitly.
rigSend(){ ## recipient subject [format]
	local recipient="$1" subject="$2" fmt="${3:-}"
	local out=""
	if [ -z "$fmt" ] ; then
		out="$( cd "$rigWs" && env -u MDAT_DATA_ROOT RIG_CURL_LOG="$rigTmp/curl-calls" AGENTS_EMAIL_SEND_BUILD_ONLY=true \
			MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
			bash "$rigTool" --member-comms-email-send keeper-myx "$recipient" -- "$subject" -- --from-stdin 2>"$rigTmp/stderr" )" \
			|| { printf 'send-failed: %s' "$( grep ERROR "$rigTmp/stderr" | head -1 )" ; return 0 ; }
	else
		out="$( cd "$rigWs" && env -u MDAT_DATA_ROOT RIG_CURL_LOG="$rigTmp/curl-calls" AGENTS_EMAIL_SEND_BUILD_ONLY=true \
			MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
			bash "$rigTool" --member-comms-email-send keeper-myx "$recipient" -- "$subject" -- --from-stdin --format "$fmt" 2>"$rigTmp/stderr" )" \
			|| { printf 'send-failed: %s' "$( grep ERROR "$rigTmp/stderr" | head -1 )" ; return 0 ; }
	fi
	printf '%s' "$out"
}

## The subject has to be reachable before anything is asserted about it.
rigMsg="$( printf '%s\n' 'Smoke test line.' | rigSend 'test@example.com' 'Smoke subject' )"
case "$rigMsg" in *'MIME-Version: 1.0'*'multipart/alternative'*) : ;; *) rigRefuse "no built message reached stdout at all, so no case below would be measured" ;; esac

echo "-- multipart structure: plain part first, both parts UTF-8, real boundary close --"
rigAssert "the plain part comes before the html part" \
	"$( rigOrder "$rigMsg" 'Content-Type: text/plain' 'Content-Type: text/html' )" yes
rigAssert "both parts declare UTF-8 charset" "$( rigCount "$rigMsg" 'charset=UTF-8' )" 2
rigBoundary="${rigMsg#*boundary=\"}" ; rigBoundary="${rigBoundary%%\"*}"
rigAssert "a boundary value was actually found" "$( [ -n "$rigBoundary" ] && printf yes || printf no )" yes
rigAssert "the message closes with the final boundary marker" \
	"$( rigHas "$rigMsg" "--${rigBoundary}--" )" yes

echo "-- bare URL and bare address become real <a> links in the html part --"
rigMsg="$( printf '%s\n' 'See https://example.com/path for details.' | rigSend 'test@example.com' 'URL case' )"
rigAssert "a bare https URL becomes a link in the html part" \
	"$( rigHas "$rigMsg" '<a href="https://example.com/path">https://example.com/path</a>' )" yes
rigAssert "the plain part still carries the same text literally, unconverted" \
	"$( rigHas "$rigMsg" 'See https://example.com/path for details.' )" yes

rigMsg="$( printf '%s\n' 'Contact myx@meloscope.com for help.' | rigSend 'test@example.com' 'Address case' )"
rigAssert "a bare address becomes bold blue text, not a link" \
	"$( rigHas "$rigMsg" '<b style="color:#0000EE">myx@meloscope.com</b>' )" yes
rigAssert "a bare address never becomes a mailto link" \
	"$( rigHas "$rigMsg" 'mailto:' )" no

echo "-- trailing punctuation stripped, url wins over address --"
rigMsg="$( printf '%s\n' 'Visit https://example.com/path. Thanks.' | rigSend 'test@example.com' 'Punctuation case' )"
rigAssert "a trailing full stop is stripped from the linked url" \
	"$( rigHas "$rigMsg" '<a href="https://example.com/path">https://example.com/path</a>. Thanks.' )" yes

rigMsg="$( printf '%s\n' 'Open https://user@host/path now.' | rigSend 'test@example.com' 'Precedence case' )"
rigAssert "https://user@host/path becomes ONE url link" \
	"$( rigHas "$rigMsg" '<a href="https://user@host/path">https://user@host/path</a>' )" yes
rigAssert "never also a mailto link out of the same span" \
	"$( rigHas "$rigMsg" 'mailto:' )" no
rigAssert "exactly one link in the html part" "$( rigCount "$rigMsg" '<a href=' )" 1

echo "-- code span, fence and an existing markdown link stay out of the linkifier --"
rigMsg="$( printf '%s\n' 'Use `http://example.com` literally.' | rigSend 'test@example.com' 'Code span case' )"
rigAssert "a url inside a code span is never linkified" \
	"$( rigHas "$rigMsg" '<a href=' )" no
rigAssert "and keeps its code styling" \
	"$( rigHas "$rigMsg" '<code>http://example.com</code>' )" yes

rigMsg="$( printf '%s\n' '```' 'https://example.com' '```' | rigSend 'test@example.com' 'Fence case' )"
rigAssert "a url inside a fence is never linkified" \
	"$( rigHas "$rigMsg" '<a href=' )" no
rigAssert "and posts as a preformatted block" \
	"$( rigHas "$rigMsg" '<pre>https://example.com</pre>' )" yes

rigMsg="$( printf '%s\n' 'See [Click here](https://example.com/page) now.' | rigSend 'test@example.com' 'Existing link case' )"
rigAssert "an existing [text](url) link keeps its own label" \
	"$( rigHas "$rigMsg" '<a href="https://example.com/page">Click here</a>' )" yes
rigAssert "and is not also linkified a second time as a bare url" \
	"$( rigCount "$rigMsg" '<a href=' )" 1

echo "-- HTML escaping, in the html part only --"
rigMsg="$( printf '%s\n' 'Use & and <tag> here.' | rigSend 'test@example.com' 'Escaping case' )"
rigAssert "ampersand and angle brackets are escaped in the html part" \
	"$( rigHas "$rigMsg" 'Use &amp; and &lt;tag&gt; here.' )" yes
rigAssert "the plain part keeps the same text literal, unescaped" \
	"$( rigHas "$rigMsg" 'Use & and <tag> here.' )" yes

echo "-- a tooling-built part (the Subject header) is untouched by the converter --"
rigMsg="$( printf '%s\n' 'Body text.' | rigSend 'test@example.com' 'A & B update' )"
rigAssert "the Subject header stays literal, never HTML-escaped" \
	"$( rigHas "$rigMsg" $'Subject: A & B update\n' )" yes

echo "-- Markdown is the default input, with no --format given --"
rigMsg="$( printf '%s\n' 'A **bold** word and `a code span`.' | rigSend 'test@example.com' 'Default format case' )"
rigAssert "bold markdown renders without passing --format at all" \
	"$( rigHas "$rigMsg" '<strong>bold</strong>' )" yes
rigAssert "a code span renders too, same default" \
	"$( rigHas "$rigMsg" '<code>a code span</code>' )" yes

echo "-- format=text has no markdown constructs, escaping and linkifying only --"
rigMsg="$( printf '%s\n' 'A `code` span and myx@meloscope.com here.' | rigSend 'test@example.com' 'Text format case' 'text' )"
rigAssert "format=text never opens a code span" \
	"$( rigHas "$rigMsg" '<code>' )" no
rigAssert "format=text still bolds a bare address" \
	"$( rigHas "$rigMsg" '<b style="color:#0000EE">myx@meloscope.com</b>' )" yes
rigAssert "format=text never makes the address a mailto link" \
	"$( rigHas "$rigMsg" 'mailto:' )" no

if [ -s "$rigTmp/curl-calls" ] ; then
	rigRefuse "curl was invoked during an offline check: $( cat "$rigTmp/curl-calls" )"
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ EMAIL HTML PART CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'EMAIL_HTML_PART: OK (%d assertions, offline, curl never reached)\n' "$rigPassCount"
