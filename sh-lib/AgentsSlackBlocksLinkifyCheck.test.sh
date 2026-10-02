#!/usr/bin/env bash
## Behavioural check on AgentsSlackBlocksBuild.awk's bare-URL and bare-address
## branch in parseInlineStyles() (the "http(s)://..." / "local@domain" ->
## real link element" rule): a thread URL becomes a link, trailing "." and a
## lone wrapping bracket are stripped, a valid address becomes a mailto:
## link with the typed address as its text, the URL check wins over the
## address check on "https://user@host/path", and an invalid-domain address,
## a dotted name, a version number, a file name, an unresolved @mention, an
## existing [text](url) link, a code span, a fence and a header line are all
## left exactly as they were. Pure pipe into the converter -- no curl, no
## network, offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigAwk="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/AgentsSlackBlocksBuild.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigAwk" ] || rigRefuse "the converter is not at the origin this workspace resolves: $rigAwk"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## Runs the converter over one or more input lines, joined with real newlines.
rigConvert(){ ## line [line...]
	printf '%s\n' "$@" | LC_ALL=C awk -v mentionMap="" -f "$rigAwk"
}
## Whether $1 (the converter's JSON output) contains the literal substring $2.
rigHas(){
	case "$1" in *"$2"*) printf yes ;; *) printf no ;; esac
}

## The subject has to be reachable before anything is asserted about it.
rigSmoke="$( rigConvert 'plain line' )"
case "$rigSmoke" in \[*\]) : ;; *) rigRefuse "the converter produced no JSON array at all, so no case below would be measured" ;; esac

echo "-- bare URL recognised, dotted non-URL text left alone --"
rigJson="$( rigConvert 'See https://meloscope.slack.com/archives/C0BJ49W7ZCM/p1790872199715469 for context' )"
rigAssert "the example thread URL becomes a link element, text equal to the url" \
	"$( rigHas "$rigJson" '{"type":"link","url":"https://meloscope.slack.com/archives/C0BJ49W7ZCM/p1790872199715469","text":"https://meloscope.slack.com/archives/C0BJ49W7ZCM/p1790872199715469"}' )" yes
rigJson="$( rigConvert 'Owned by myx.distro-agents team' )"
rigAssert "a dotted project name with no scheme stays literal, not a link" \
	"$( rigHas "$rigJson" '"type":"link"' )" no
rigJson="$( rigConvert 'Running version 3.2.57 now' )"
rigAssert "a bare version number stays literal, not a link" \
	"$( rigHas "$rigJson" '"type":"link"' )" no
rigJson="$( rigConvert 'See report.txt for the log' )"
rigAssert "a plain file name stays literal, not a link" \
	"$( rigHas "$rigJson" '"type":"link"' )" no

echo "-- trailing punctuation trimmed from a bare URL --"
rigJson="$( rigConvert 'Visit https://example.com/path. Thanks' )"
rigAssert "a trailing full stop is stripped from the url" \
	"$( rigHas "$rigJson" '{"type":"link","url":"https://example.com/path","text":"https://example.com/path"}' )" yes
rigAssert "the stripped stop re-appears as its own literal text" \
	"$( rigHas "$rigJson" '{"type":"text","text":". Thanks"}' )" yes
rigJson="$( rigConvert '(https://example.com/path)' )"
rigAssert "a lone wrapping bracket is stripped from the url" \
	"$( rigHas "$rigJson" '{"type":"link","url":"https://example.com/path","text":"https://example.com/path"}' )" yes
rigAssert "both the opening and the stripped closing bracket stay as literal text around the link" \
	"$( rigHas "$rigJson" '{"type":"text","text":"("},{"type":"link","url":"https://example.com/path","text":"https://example.com/path"},{"type":"text","text":")"}' )" yes

echo "-- valid address recognised, invalid-domain address left alone --"
rigJson="$( rigConvert 'Contact myx@meloscope.com for help' )"
rigAssert "a valid address becomes a mailto: link, text equal to the typed address" \
	"$( rigHas "$rigJson" '{"type":"link","url":"mailto:myx@meloscope.com","text":"myx@meloscope.com"}' )" yes
rigJson="$( rigConvert 'Try foo@localhost, nothing else' )"
rigAssert "an address with no dot in its domain stays literal, not a link" \
	"$( rigHas "$rigJson" '"type":"link"' )" no
rigAssert "that literal address still reads whole in the plain text" \
	"$( rigHas "$rigJson" 'foo@localhost' )" yes

echo "-- the url check wins over the address check, @mentions are untouched --"
rigJson="$( rigConvert 'Open https://user@host/path now' )"
rigAssert "https://user@host/path becomes ONE url link, its own @ already claimed" \
	"$( rigHas "$rigJson" '{"type":"link","url":"https://user@host/path","text":"https://user@host/path"}' )" yes
rigAssert "and never a second, mailto: link out of the same span" \
	"$( rigHas "$rigJson" 'mailto:' )" no
rigJson="$( rigConvert 'cc @keeper-myx please' )"
rigAssert "an unresolved @mention is not swept up as a bare address" \
	"$( rigHas "$rigJson" '"type":"link"' )" no
rigAssert "and reads back as the literal @name" \
	"$( rigHas "$rigJson" '@keeper-myx' )" yes

echo "-- untouched by construction: existing links, code, fences, headers --"
rigJson="$( rigConvert '[Click here](https://example.com/page)' )"
rigAssert "an existing [text](url) link keeps its own distinct label" \
	"$( rigHas "$rigJson" '{"type":"link","url":"https://example.com/page","text":"Click here"}' )" yes
rigJson="$( rigConvert 'Use `http://example.com` literally' )"
rigAssert "a url inside a code span stays code, never a link" \
	"$( rigHas "$rigJson" '"type":"link"' )" no
rigAssert "and keeps its code style" \
	"$( rigHas "$rigJson" '{"type":"text","text":"http://example.com","style":{"code":true}}' )" yes
rigJson="$( rigConvert '```' 'https://example.com' '```' )"
rigAssert "a url inside a fence stays verbatim preformatted text, never a link" \
	"$( rigHas "$rigJson" '"type":"link"' )" no
rigAssert "and the fence block itself is the one carrying it" \
	"$( rigHas "$rigJson" 'rich_text_preformatted' )" yes
rigJson="$( rigConvert '# Visit https://example.com now' )"
rigAssert "a header line's own url stays literal, the header block unchanged" \
	"$( rigHas "$rigJson" '{"type":"header","text":{"type":"plain_text","text":"Visit https://example.com now","emoji":true}}' )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK BLOCKS LINKIFY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_BLOCKS_LINKIFY: OK (%d assertions, offline)\n' "$rigPassCount"
