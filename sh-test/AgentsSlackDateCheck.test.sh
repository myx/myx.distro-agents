#!/usr/bin/env bash
## Behavioural check on Slack's date format wherever the tooling itself writes a date or a
## time into text it sends to Slack, and where it reads such text back: the one helper
## (sh-lib/AgentsSlackDate.awk, AgentsToolsSlackDateToken in AgentsTools.SlackDate.include)
## gives `<!date^<epoch>^<token string>|<the same moment as UTC text>>` for every moment form
## this tree carries, in each style, and nothing for what it cannot read; a range is two
## tokens; a renderer that escapes its values sends the helper's own token unescaped and no
## other; no cut falls inside a token; the member send's blocks carry the same moment as a
## date element, and a token in a code span or a code block stays text; a message read back
## (the formatter, the session-context scan, a search, a Wait's answers) shows a token as its
## fallback, and the dismissal, mention and addressing readers still work on such text; a
## tracking post's given date comes out unescaped and outside a code span, and its Wait line
## shows the fallback; a spawn's start and end posts say their times as tokens.
## The pending-reply reminder and the main loop's timeout post are held where their rigs
## are: AgentsPendingReplyRemindCheck and AgentsMainLoopPassBoundCheck.
## Offline: temp files, a Slack-shaped fake curl first on PATH for the one spawn that runs,
## and every op in a clean environment whose workspace and data root sit under this rig's
## own mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigDate="$rigLib/AgentsSlackDate.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigDate" ] || rigRefuse "the helper is not at the origin this workspace resolves: $rigDate"
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
rigTmp="$( mktemp -d -t AgentsSlackDateCheck )" || exit 1
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
rigHolds(){ ## file, fixed string
	LC_ALL=C grep -q -F -- "$2" "$1" 2>/dev/null && printf yes || printf no
}
## The helper as a command: one `<moment><TAB><style>` in, its token out.
rigToken(){ ## moment, style
	printf '%s\t%s\n' "$1" "$2" | LC_ALL=C awk -v sldStandalone=token -f "$rigDate"
}
## The helper's functions, called by name: the library, then this driver.
cat > "$rigTmp/call.awk" <<'RIG_CALL_EOF'
BEGIN {
	callName = ENVIRON["RIG_CALL"] ; argOne = ENVIRON["RIG_A"] ; argTwo = ENVIRON["RIG_B"] ; argThree = ENVIRON["RIG_C"] ;
	if ( callName == "range" ) { print sldToken( argOne, argThree ) "\342\200\223" sldToken( argTwo, argThree ) ; }
	else if ( callName == "as" ) { print sldTokenAs( argOne, argTwo, argThree ) ; }
	else if ( callName == "keep" ) { print sldKeep( argOne ) ; }
	else if ( callName == "fallbacks" ) { print sldFallbacks( argOne ) ; }
	else if ( callName == "cut" ) {
		## Every cap from 1 to the text's length: how many keep more than the cap, or end inside a token.
		badCuts = 0 ;
		for ( capBytes = 1 ; capBytes <= length( argOne ) ; capBytes++ ) {
			keptBytes = sldCutAt( argOne, capBytes ) ;
			headText = substr( argOne, 1, keptBytes ) ;
			if ( keptBytes > capBytes || headText ~ /<!date[^>]*$/ ) { badCuts++ ; }
		}
		print badCuts ":" sldCutAt( argOne, argTwo + 0 ) ;
	}
	exit ;
}
RIG_CALL_EOF
rigCall(){ ## function, arguments...
	RIG_CALL="$1" RIG_A="${2:-}" RIG_B="${3:-}" RIG_C="${4:-}" LC_ALL=C awk -f "$rigDate" -f "$rigTmp/call.awk" < /dev/null
}

## ---------------------------------------------------------------------------
echo "-- the helper: one token per moment, in each style, its fallback the same moment in UTC --"
## ---------------------------------------------------------------------------
## 2026-10-09T06:02:30Z is epoch 1791525750.
rigAssert "time with seconds"       "$( rigToken 1791525750 time-secs )"      '<!date^1791525750^{time_secs}|06:02:30 UTC>'
rigAssert "time without seconds"    "$( rigToken 1791525750 time )"           '<!date^1791525750^{time}|06:02 UTC>'
rigAssert "date and time"           "$( rigToken 1791525750 date-time )"      '<!date^1791525750^{date_num} {time}|2026-10-09 06:02 UTC>'
rigAssert "date and time, seconds"  "$( rigToken 1791525750 date-time-secs )" '<!date^1791525750^{date_num} {time_secs}|2026-10-09 06:02:30 UTC>'
rigAssert "date only"               "$( rigToken 1791525750 date )"           '<!date^1791525750^{date_num}|2026-10-09 UTC>'
rigSame=""
for rigMoment in '1791525750' '1791525750.813549' '2026-10-09T06:02:30Z' '2026-10-09 06:02:30' '2026-10-09 09:02:30 +0300' '2026-10-09T09:02:30+03:00' '2026-10-09 02:32:30 -0330' '20261009T060230Z' ; do
	[ "$( rigToken "$rigMoment" date-time-secs )" = '<!date^1791525750^{date_num} {time_secs}|2026-10-09 06:02:30 UTC>' ] || rigSame="$rigSame [$rigMoment]"
done
rigAssert "every form of one moment this tree carries is the same token: epoch, a Slack ts, ISO, a local time with its offset, the name form" "$rigSame" ""
rigAssert "a stamp to the minute, as the tooling's own records hold it" \
	"$( rigToken '2026-10-09 09:02 +0300' date-time ):$( rigToken '20261009T0602Z' date-time )" \
	'<!date^1791525720^{date_num} {time}|2026-10-09 06:02 UTC>:<!date^1791525720^{date_num} {time}|2026-10-09 06:02 UTC>'
rigAssert "a bare date is its first second in UTC" "$( rigToken '2026-10-09' date )" '<!date^1791504000^{date_num}|2026-10-09 UTC>'
rigAssert "the last second of a leap day"        "$( rigToken '2028-02-29T23:59:59Z' date-time-secs )" '<!date^1835481599^{date_num} {time_secs}|2028-02-29 23:59:59 UTC>'
rigBad=""
for rigMoment in 'yesterday' '' '2026-10-09 0602' '-5' '2026-10-09T06:02:30Zjunk' '06:02:30' ; do
	rigOut="$( rigToken "$rigMoment" date-time )" ; rigRc=$?
	[ -z "$rigOut" ] && [ "$rigRc" = 1 ] || rigBad="$rigBad [$rigMoment: $rigOut rc=$rigRc]"
done
rigOut="$( rigToken 1791525750 weird )" ; rigRc=$?
[ -z "$rigOut" ] && [ "$rigRc" = 1 ] || rigBad="$rigBad [style weird: $rigOut rc=$rigRc]"
rigAssert "a moment or a style it cannot read gives nothing and exit 1, never a wrong date" "$rigBad" ""
rigAssert "a range is two tokens, the site's own separator between them" \
	"$( rigCall range '2030-01-01T00:01:00Z' '2030-01-01T00:01:14Z' time-secs )" \
	'<!date^1893456060^{time_secs}|00:01:00 UTC>–<!date^1893456074^{time_secs}|00:01:14 UTC>'
rigAssert "a token string of the caller's own, with a style's fallback" \
	"$( rigCall as 1791640500 '{date_short_pretty} at {time}' date-time )|$( rigCall as 1791640500 '{ago}' date-time )|$( rigCall as 1791640500 '{time}|x' date-time )" \
	'<!date^1791640500^{date_short_pretty} at {time}|2026-10-10 13:55 UTC>|<!date^1791640500^{ago}|2026-10-10 13:55 UTC>|'

echo "-- the shell wrapper is the same helper --"
set -- --rig-none
. "$rigLib/AgentsTools.SlackDate.include"
rigAssert "AgentsToolsSlackDateToken prints the helper's token" "$( AgentsToolsSlackDateToken '2026-10-09 09:02 +0300' date-time )" "$( rigToken '2026-10-09 09:02 +0300' date-time )"
rigKept="$( AgentsToolsSlackDateToken 'not a moment' date-time )" || rigKept="kept as it was"
rigAssert "it returns 1 and prints nothing for what it cannot read, so a caller keeps its text" "$rigKept" "kept as it was"

## ---------------------------------------------------------------------------
echo "-- escaping: the helper's own token goes unescaped, and nothing else does --"
## ---------------------------------------------------------------------------
rigOwn='<!date^1791525750^{date_num} {time}|2026-10-09 06:02 UTC>'
rigEsc(){ printf '%s' "$1" | LC_ALL=C sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' ; }
rigAssert "an escaped value's own token is the control sequence again, the rest stays escaped" \
	"$( rigCall keep "$( rigEsc "at $rigOwn by <!here> & <@U1>" )" )" "at $rigOwn by &lt;!here&gt; &amp; &lt;@U1&gt;"
rigAssert "two of them, a range, both" "$( rigCall keep "$( rigEsc "$rigOwn–$rigOwn" )" )" "$rigOwn–$rigOwn"
rigForeign=""
for rigText in '<!date^1791525750^{date_num} {time}^https://example.invalid/x|2026-10-09 06:02 UTC>' '<!date^1791525750^{date_long}|2026-10-09 06:02 UTC>' \
	'<!date^1791525750^{date_num} {time}|click here>' '<!date^abc^{time}|06:02 UTC>' '<!subteam^S1|06:02 UTC>' ; do
	[ "$( rigCall keep "$( rigEsc "$rigText" )" )" = "$( rigEsc "$rigText" )" ] || rigForeign="$rigForeign [$rigText]"
done
rigAssert "a token with a link, another token string, another fallback, or no token at all stays escaped" "$rigForeign" ""

## ---------------------------------------------------------------------------
echo "-- splitting: no cut falls inside a token --"
## ---------------------------------------------------------------------------
rigCutText="started: $rigOwn and ended: $rigOwn."
rigAssert "at every length a text can be cut to, the token goes whole or not at all" \
	"$( rigCall cut "$rigCutText" 20 )" "0:9"
rigAssert "a cut past a token keeps it, a cut before one is where it was asked" \
	"$( rigCall cut "$rigCutText" $(( 9 + ${#rigOwn} )) | LC_ALL=C cut -d: -f2 ):$( rigCall cut "$rigCutText" 5 | LC_ALL=C cut -d: -f2 )" "$(( 9 + ${#rigOwn} )):5"

## ---------------------------------------------------------------------------
echo "-- the member send's blocks: the same moment as a date element --"
## ---------------------------------------------------------------------------
rigBlocks(){ printf '%s\n' "$@" | LC_ALL=C awk -f "$rigLib/AgentsSlackBlocksBuild.awk" ; }
rigBlocks "asked $rigOwn, reminder 1" > "$rigTmp/blocks.one"
rigAssert "a token in a paragraph is a date element between its text" \
	"$( cat "$rigTmp/blocks.one" )" \
	'[{"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"asked "},{"type":"date","timestamp":1791525750,"format":"{date_num} {time}","fallback":"2026-10-09 06:02 UTC"},{"type":"text","text":", reminder 1"}]}]}]'
rigBlocks "- from <!date^1893456060^{time_secs}|00:01:00 UTC>–<!date^1893456074^{time_secs}|00:01:14 UTC>" > "$rigTmp/blocks.range"
rigAssert "a range in a list item is two date elements" \
	"$( LC_ALL=C grep -o '"type":"date"' "$rigTmp/blocks.range" | LC_ALL=C awk 'END { print NR }' ):$( rigHolds "$rigTmp/blocks.range" '{"type":"date","timestamp":1893456074,"format":"{time_secs}","fallback":"00:01:14 UTC"}' )" 2:yes
{ printf '%s\n' "in code \`$rigOwn\` it stays" '```' "$rigOwn" '```' ; } | LC_ALL=C awk -f "$rigLib/AgentsSlackBlocksBuild.awk" > "$rigTmp/blocks.code"
## Each wanted element in a variable first: bash 3.2 brace-expands a double-quoted `{a,b}` written inside "$( )".
rigCodeSpan='{"type":"text","text":"'"$rigOwn"'","style":{"code":true}}'
rigCodeBlock='{"type":"rich_text_preformatted","elements":[{"type":"text","text":"'"$rigOwn"'"}]}'
rigAssert "in a code span and in a code block it stays text: no date element" \
	"$( LC_ALL=C grep -c -F '"type":"date"' "$rigTmp/blocks.code" ):$( rigHolds "$rigTmp/blocks.code" "$rigCodeSpan" ):$( rigHolds "$rigTmp/blocks.code" "$rigCodeBlock" )" 0:yes:yes
rigBlocks 'a <!date^x^{time}|no> b <!here>' > "$rigTmp/blocks.not"
rigAssert "a text that only starts like a token stays text" "$( LC_ALL=C grep -c -F '"type":"date"' "$rigTmp/blocks.not" ):$( rigHolds "$rigTmp/blocks.not" 'a <!date^x^{time}|no> b <!here>' )" 0:yes
if command -v python3 > /dev/null 2>&1 ; then
	rigAssert "the blocks pass the send's own validator, and their text version says the fallback" \
		"$( python3 "$rigLib/AgentsBlockKitValidate.py" < "$rigTmp/blocks.one" ; printf 'rc=%s' "$?" ):$( python3 "$rigLib/AgentsSlackBlocksTextVersion.py" < "$rigTmp/blocks.one" )" \
		"rc=0:asked 2026-10-09 06:02 UTC, reminder 1"
fi

## ---------------------------------------------------------------------------
echo "-- reading back: a token shows as its fallback, and the readers still work --"
## ---------------------------------------------------------------------------
rigAssert "the helper's own rule: each token its fallback, a link in it too, the rest untouched" \
	"$( rigCall fallbacks "a $rigOwn–$rigOwn b <!date^5^{date}^https://example.invalid/x|five> <!here> <@U1> <!date^x^y|z>" )" \
	'a 2026-10-09 06:02 UTC–2026-10-09 06:02 UTC b five <!here> <@U1> <!date^x^y|z>'
rigAssert "as a command" "$( printf '%s\n' "x $rigOwn y" | LC_ALL=C awk -v sldStandalone=fallback -f "$rigDate" )" 'x 2026-10-09 06:02 UTC y'
## A thread as Slack returns it: the tooling's own reminder (a token in it, sent by the team's
## send, so it carries the send header), an answer naming a time, a dismissal, a plain mention.
cat > "$rigTmp/thread.json" <<RIG_THREAD_EOF
{"ok":true,"messages":[{"ts":"1791525800.000100","user":"U0BOT","text":":wrench: *_magic-coordinator_* @magic → *_magic-tester_* <@U0TESTER>.\n⏰ Still waiting for your answer (asked $rigOwn, reminder 1):","metadata":{"event_payload":{"sender":"magic-coordinator"}}},{"ts":"1791525810.000100","user":"U0OWNER","text":"yes, since $rigOwn | fine"},{"ts":"1791525820.000100","user":"U0BOT","text":"*_magic-coordinator_* @magic → *_magic-tester_* <@U0TESTER>. DISMISSED","metadata":{"event_payload":{"sender":"magic-coordinator"}}},{"ts":"1791525830.000100","user":"U0OWNER","text":"<@U0TESTER> see <!date^1791525750^{time}|06:02 UTC>"}]}
RIG_THREAD_EOF
LC_ALL=C awk -f "$rigLib/AgentsSlackMessagesFormat.awk" < "$rigTmp/thread.json" > "$rigTmp/thread.fmt" 2> "$rigTmp/thread.err" ; rigRc=$?
rigAssert "the formatter: four messages, no raw control string, each token its fallback" \
	"$rigRc:$( LC_ALL=C grep -c '^[0-9]*\.[0-9]* | ' "$rigTmp/thread.fmt" ):$( LC_ALL=C grep -c -F '!date^' "$rigTmp/thread.fmt" ):$( LC_ALL=C grep -c -F '2026-10-09 06:02 UTC' "$rigTmp/thread.fmt" )" 0:4:0:2
rigAssert "the reminder reads as it was written, the time in UTC" \
	"$( rigHolds "$rigTmp/thread.fmt" '⏰ Still waiting for your answer (asked 2026-10-09 06:02 UTC, reminder 1):' )" yes
rigAssert "a Wait's answers: the reply after the tooling's own post, its time as the fallback" \
	"$( LC_ALL=C awk -v rootTs=1791525800.000100 -v fromUsers=U0OWNER -f "$rigLib/AgentsDismissalMatch.awk" -f "$rigLib/AgentsSlackThreadAnswers.awk" < "$rigTmp/thread.fmt" | LC_ALL=C tr '\n' '#' )" \
	'1791525810.000100 | U0OWNER | yes, since 2026-10-09 06:02 UTC | fine#1791525830.000100 | U0OWNER | <@U0TESTER> see 06:02 UTC#'
rigDismissedBy="$( LC_ALL=C awk -v agent=magic-tester -f "$rigLib/AgentsDismissalMatch.awk" -f "$rigLib/AgentsHarnessWaitDismissed.awk" "$rigTmp/thread.fmt" )" ; rigRc=$?
rigAssert "the dismissal reader finds the DISMISSED among messages that carry tokens" "$rigDismissedBy:rc=$rigRc" '1791525820.000100 | U0BOT:rc=0'
rigDismissedBy="$( LC_ALL=C grep -v -F 'DISMISSED' "$rigTmp/thread.fmt" | LC_ALL=C awk -v agent=magic-tester -f "$rigLib/AgentsDismissalMatch.awk" -f "$rigLib/AgentsHarnessWaitDismissed.awk" )" ; rigRc=$?
rigAssert "and none where there is none: a reminder with a token dismisses no one" "$rigDismissedBy:rc=$rigRc" ':rc=1'
COMMS_USER_HANDLES=$'U0TESTER\ttester' LC_ALL=C awk -v kind=slack -v source=rig -v channel=CRIG -f "$rigLib/AgentsSessionContextCommsItems.awk" < "$rigTmp/thread.json" > "$rigTmp/thread.items" 2>> "$rigTmp/thread.err" ; rigRc=$?
rigAssert "the session-context scan: no raw control string, the text with its fallback" \
	"$rigRc:$( LC_ALL=C grep -c -F '!date^' "$rigTmp/thread.items" ):$( LC_ALL=C grep -c -x -F 'text: yes, since 2026-10-09 06:02 UTC | fine' "$rigTmp/thread.items" )" 0:0:1
rigAssert "it still reads who a message with a token is from and for: the send header, and a mention" \
	"$( LC_ALL=C awk '/^## slack-message CRIG:1791525800/ { on = 1 } on && /^(author|addressees): / { printf "%s|", $0 } on && /^$/ { exit }' "$rigTmp/thread.items" ):$( LC_ALL=C awk '/^## slack-message CRIG:1791525830/ { on = 1 } on && /^addressees: / { print ; exit }' "$rigTmp/thread.items" )" \
	'author: magic-coordinator|addressees: magic-tester|:addressees: U0TESTER (tester)'
printf '%s\n' "{\"ok\":true,\"messages\":{\"total\":1,\"paging\":{\"count\":20,\"total\":1,\"page\":1,\"pages\":1},\"matches\":[{\"ts\":\"1791525810.000100\",\"user\":\"U0OWNER\",\"text\":\"yes, since $rigOwn\",\"permalink\":\"https://rig.slack.com/archives/CRIG/p1791525810000100\"}]}}" > "$rigTmp/search.json"
rigAssert "a search's lines: the fallback" \
	"$( LC_ALL=C awk -v cutoff=5 -f "$rigLib/AgentsSlackSearchMatches.awk" < "$rigTmp/search.json" )" '1791525810.000100 | U0OWNER | yes, since 2026-10-09 06:02 UTC'
## The three readers carry the rule as a copy, each running with no other file loaded: on one
## text, each must say what the helper says.
rigReaderText="mixed $rigOwn–$rigOwn and <!date^5^{date}^https://example.invalid/x|five> and <!date^x^y|z> end"
rigWant="$( rigCall fallbacks "$rigReaderText" )"
printf '{"ok":true,"messages":[{"ts":"1.000001","user":"U1","text":"%s"}]}\n' "$rigReaderText" > "$rigTmp/one.json"
printf '{"ok":true,"messages":{"total":1,"paging":{"count":20,"total":1,"page":1,"pages":1},"matches":[{"ts":"9.000001","user":"U1","text":"%s","permalink":"https://rig.slack.com/archives/C1/p9000001"}]}}\n' "$rigReaderText" > "$rigTmp/one.search.json"
rigAssert "the readers' copies say what the helper says: the formatter, the session-context scan, the search" \
	"$( LC_ALL=C awk -f "$rigLib/AgentsSlackMessagesFormat.awk" < "$rigTmp/one.json" )|$( LC_ALL=C awk -v kind=slack -v source=rig -v channel=C1 -f "$rigLib/AgentsSessionContextCommsItems.awk" < "$rigTmp/one.json" | LC_ALL=C grep '^text: ' )|$( LC_ALL=C awk -v cutoff=5 -f "$rigLib/AgentsSlackSearchMatches.awk" < "$rigTmp/one.search.json" )" \
	"1.000001 | U1 | $rigWant|text: $rigWant|9.000001 | U1 | $rigWant"

## ---------------------------------------------------------------------------
echo "-- a tracking post: a given date is a token, unescaped and outside a code span --"
## ---------------------------------------------------------------------------
mkdir -p "$rigTmp/skills/magic-tester"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/skills/magic-tester/magic-tester.basic.md"
MDSC_CMD=rig
unset MDAT_SKILLSET_ROOT
. "$rigLib/AgentsTools.InternOpEventTrackPost.include"
rigRenderWs="$rigTmp/render-ws"
mkdir -p "$rigRenderWs/.local/.agents"
rigRender(){ ## kind, out dir, lines file, name=value...
	local renderKind="$1" renderDir="$2" renderFrom="$3"
	shift 3
	rm -rf "$renderDir" ; mkdir -p "$renderDir"
	MMDAPP="$rigRenderWs" AgentsEventTrackPostRender "$renderKind" magic-tester abcdef01-2345-4000-8000-000000000001 "$renderDir" "$renderFrom" "$@"
}
## Every `<!date` a post holds, and how many of them are whole tokens of the helper's shape.
rigTokens(){ ## files...
	cat "$@" | LC_ALL=C awk '{ rest = $0 ; while ( ( at = index( rest, "<!date" ) ) > 0 ) { opened++ ; rest = substr( rest, at ) ; if ( match( rest, /^<!date\^[0-9]+\^[^|<>^]+\|[0-9: -]+ UTC>/ ) ) { whole++ ; } rest = substr( rest, 7 ) ; } } END { print opened + 0 ":" whole + 0 }'
}
rigStarted="$( rigToken '2030-01-01 00:00 +0000' date-time )"
rigRender start "$rigTmp/k-start" /dev/null cli=rig-cli host=rig-host workspace=rig-ws started-at="$rigStarted" what='<!here> & co'
rigAssert "the start time a caller gives as a token is in the post as that token" \
	"$( cat "$rigTmp/k-start"/* | LC_ALL=C grep -c -F 'started: <!date^1893456000^{date_num} {time}|2030-01-01 00:00 UTC>' )" 1
rigAssert "unescaped, outside a code span, no UTC label after it, and the other values still escaped" \
	"$( cat "$rigTmp/k-start"/* | LC_ALL=C grep -c -e '&lt;!date' -e '`<!date' -e 'UTC> UTC' ):$( cat "$rigTmp/k-start"/* | LC_ALL=C grep -c -F '&lt;!here&gt; &amp; co' )" 0:1
rigRender end "$rigTmp/k-end" /dev/null outcome=succeeded armed="yes, at $( rigToken '2026-09-29 10:00 +0300' date-time )" ended-at="$rigStarted"
rigAssert "the end post's own two: when it armed, and when it ended" \
	"$( cat "$rigTmp/k-end"/* | LC_ALL=C grep -c -F 'armed: yes, at <!date^1790665200^{date_num} {time}|2026-09-29 07:00 UTC>' ):$( cat "$rigTmp/k-end"/* | LC_ALL=C grep -c -F 'ended: <!date^1893456000^{date_num} {time}|2030-01-01 00:00 UTC>' ):$( rigTokens "$rigTmp/k-end"/* )" 1:1:2:2
rigRender error "$rigTmp/k-foreign" /dev/null what=x detail='<!date^1893456000^{date_num} {time}^https://example.invalid/x|2030-01-01 00:00 UTC> <!date^1893456000^{date_long}|2030-01-01 00:00 UTC>'
rigAssert "a value's token with a link, or with another token string, is escaped as any value is" "$( rigTokens "$rigTmp/k-foreign"/* ):$( cat "$rigTmp/k-foreign"/* | LC_ALL=C grep -c -F '&lt;!date^1893456000^{date_long}|2030-01-01 00:00 UTC&gt;' )" 0:0:1
## A line too long for one post is cut: the token at its end goes whole or not at all.
rigLongHost="$( LC_ALL=C awk 'BEGIN { for ( n = 1 ; n <= 3770 ; n++ ) printf "h" }' )"
rigRender error "$rigTmp/k-cut" /dev/null what=x host="$rigLongHost" at="$rigStarted"
rigCutTokens="$( rigTokens "$rigTmp/k-cut"/* )"
rigAssert "a line cut by length never ends inside a token" "$( [ "${rigCutTokens%%:*}" = "${rigCutTokens##*:}" ] && printf whole || printf "cut $rigCutTokens" )" whole
rigRender error "$rigTmp/k-fit" /dev/null what=x host=rig-host at="$rigStarted"
rigAssert "control: the same line, short, keeps its token" "$( rigTokens "$rigTmp/k-fit"/* )" 1:1
## Many lines, many posts: every token in every part is whole.
LC_ALL=C awk 'BEGIN { for ( n = 1 ; n <= 400 ; n++ ) { printf "2030-01-01T00:%02d:%02dZ TOOL Read path=/a/long/enough/path/file-number-%03d.md -> ok 10B/1L 1ms\n", int( n / 60 ), n % 60, n ; if ( n % 7 == 0 ) printf "2030-01-01T00:%02d:%02dZ VERDICT item=rig-item-%03d by=magic-tester text=\"accepted\"\n", int( n / 60 ), n % 60, n } }' > "$rigTmp/lines.long"
rigRender feed "$rigTmp/k-long" "$rigTmp/lines.long"
rigLongTokens="$( rigTokens "$rigTmp/k-long"/* )"
rigAssert "a post cut into parts: several parts, tokens in them, and every one whole" \
	"$( [ "$( ls "$rigTmp/k-long" | LC_ALL=C awk 'END { print NR }' )" -gt 2 ] && printf several || printf few ):$( [ "${rigLongTokens%%:*}" -gt 0 ] && [ "${rigLongTokens%%:*}" = "${rigLongTokens##*:}" ] && printf whole || printf "cut $rigLongTokens" )" several:whole
## What a Wait received, read back from Slack, with a token in it: the line says the fallback.
printf '%s\n' '2030-01-01T00:09:08Z TOOL Wait sources=slack:C1:1.2 -> ok 1298B/18L 1m05s' '2030-01-01T00:09:08Z WAIT-RESULT' '> WAIT-RESULT: RECEIVED' \
	"> 1791464999.000100 | U0RIGUSER | since $rigOwn ok" > "$rigTmp/lines.wait"
rigRender feed "$rigTmp/k-wait" "$rigTmp/lines.wait"
rigAssert "a Wait's line shows a received token as its fallback, never the control string" \
	"$( cat "$rigTmp/k-wait"/* | LC_ALL=C grep -c -F '"since 2026-10-09 06:02 UTC ok"' ):$( cat "$rigTmp/k-wait"/* | LC_ALL=C grep -c -e 'date^1791525750' )" 1:0

## ---------------------------------------------------------------------------
echo "-- a spawn's start and end posts say their times as tokens, offline --"
## ---------------------------------------------------------------------------
mkdir -p "$rigTmp/bin" "$rigTmp/ws/.local/.agents" "$rigTmp/data" "$rigTmp/home" "$rigTmp/scenario"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-not-a-token\nSPAWN_CLI_SERVICE=rig-cli\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
## A Slack-shaped curl: logs each method, keeps each posted body, answers by method. Opens no socket.
cat > "$rigTmp/bin/curl" <<'RIGEOF'
#!/usr/bin/env bash
set -u
cat > /dev/null
rigMethod="no-method" rigBody="" rigHeaders="" rigPrev=""
for rigArg in "$@" ; do
	case "$rigPrev" in -D) rigHeaders="$rigArg" ;; esac
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
		http://*|https://*) rigMethod="url:$rigArg" ;;
		@-) ;;
		@*) rigBody="${rigArg#@}" ;;
	esac
	rigPrev="$rigArg"
done
printf '%s\n' "$rigMethod" >> "$RIG_SCENARIO/calls"
[ -z "$rigHeaders" ] || printf 'HTTP/2 200\r\n\r\n' > "$rigHeaders"
case "$rigMethod" in
	chat.postMessage)
		rigN=$(( $( cat "$RIG_SCENARIO/posts" 2>/dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigN" > "$RIG_SCENARIO/posts"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/post.$rigN"
		printf '{"ok":true,"channel":"CRIGTRACK","ts":"1700000001.%06d","message":{"ts":"1700000001.%06d"}}\n' "$(( 100 + rigN ))" "$(( 100 + rigN ))"
	;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
RIGEOF
chmod +x "$rigTmp/bin/curl"
## The console the proxy starts: the strings its vintage guard looks for, then a launch, and
## the armed mark a harness session leaves beside its record, as the harness writes it.
printf '%s\n' '#!/usr/bin/env bash' \
	'## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) stand-in: launches rig-cli.' \
	'cat > /dev/null' \
	'printf "%s\n" rig-cli > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'[ -z "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] || printf "%s\n" "2026-09-29 10:00 +0300" > "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.armed"' \
	'printf "📦 SubagentHandback\n"' > "$rigTmp/ws/DistroAgentsConsole.sh"
chmod +x "$rigTmp/ws/DistroAgentsConsole.sh"
printf 'RIG-SPAWN-BRIEF\n' > "$rigTmp/spawn.brief"
rigBefore="$( date +%s )"
env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" TMPDIR="$rigTmp" \
	MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigTmp/scenario" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
	bash -c '
		case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
		case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
		case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: curl is not the rig fake" >&2 ; exit 99 ;; esac
		cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy magic-tester --dispatch-doc:none --wait --session-thread:event-track --context rig-slack-date
	' < "$rigTmp/spawn.brief" > "$rigTmp/op.out" 2> "$rigTmp/op.err"
rigOpRc=$?
rigAfter="$( date +%s )"
rigAssert "the spawn ran and launched" "$rigOpRc:$( LC_ALL=C grep -c '^LAUNCHED=true$' "$rigTmp/op.out" )" 0:1
rigStartPost="$( LC_ALL=C grep -l -F '🚀 session start' "$rigTmp/scenario"/post.[0-9]* 2>/dev/null | head -1 )"
rigEndPost="$( LC_ALL=C grep -l -F '🏁 session end' "$rigTmp/scenario"/post.[0-9]* 2>/dev/null | head -1 )"
## One labelled token of a post: `<label><token>`, its epoch within this run, its fallback the helper's.
rigSiteToken(){ ## post file, label
	LC_ALL=C grep -o -E "$2<!date\\^[0-9]+\\^\\{date_num\\} \\{time\\}\\|[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} UTC>" "${1:-/dev/null}" 2>/dev/null | head -1 | LC_ALL=C sed "s/^$2//"
}
rigSiteCheck(){ ## token -- now when its epoch is within this run and its fallback is that moment, else what is off
	local siteEpoch
	siteEpoch="$( printf '%s' "$1" | LC_ALL=C sed -n 's/^<!date^\([0-9]*\)^.*$/\1/p' )"
	[ -n "$siteEpoch" ] || { printf 'no token' ; return 0 ; }
	[ "$siteEpoch" -ge "$rigBefore" ] && [ "$siteEpoch" -le "$rigAfter" ] || { printf 'epoch %s outside %s..%s' "$siteEpoch" "$rigBefore" "$rigAfter" ; return 0 ; }
	[ "$1" = "$( rigToken "$siteEpoch" date-time )" ] || { printf 'fallback is not the epoch: %s' "$1" ; return 0 ; }
	printf 'now'
}
rigAssert "the start post: started is a token, its epoch this run's, its fallback that moment in UTC" "$( rigSiteCheck "$( rigSiteToken "$rigStartPost" 'started: ' )" )" now
rigAssert "the end post: ended is a token, its epoch this run's, its fallback that moment in UTC"     "$( rigSiteCheck "$( rigSiteToken "$rigEndPost" 'ended: ' )" )" now
rigAssert "the end post: when it armed, from the mark's own local stamp" \
	"$( rigHolds "${rigEndPost:-/dev/null}" 'armed: yes, at <!date^1790665200^{date_num} {time}|2026-09-29 07:00 UTC>' )" yes
rigAssert "no post holds an escaped token, one in a code span, a UTC label after one, or the old local stamp" \
	"$( cat "$rigTmp/scenario"/post.[0-9]* 2>/dev/null | LC_ALL=C grep -c -E -e '&lt;!date' -e '`<!date' -e 'UTC> UTC' -e '2026-09-29 10:00 [+]0300' -e '(started|ended): [0-9]{4}-' )" 0
rigAssert "every call was a Slack method the fake answered" "$( cat "$rigTmp/scenario/calls" 2>/dev/null | LC_ALL=C grep -c -e '^url:' -e '^no-method$' || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK DATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_DATE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
