#!/usr/bin/env bash
## Behavioural check: the form of a search's lines, as --member-comms-slack-search-messages
## prints them. One line per match, "<ts> | <user> | <text>"; a reply inside a thread carries
## the reader's own mark AHEAD of its text, "<ts> | <user> | [thread-reply of <parent-ts>] <text>",
## as AgentsSlackMessagesFormat.awk prints its own annotations. The mark used to stand after
## the text, where the text itself ends: a message outside any thread whose text ended with
## those words read as a reply inside the thread they named, and a pasted search line does
## that honestly. Now the mark's place holds the reader's word only: text that itself starts
## with such a mark is printed one space in.
## Two parts. The reader alone (AgentsSlackSearchMatches.awk): each line by its exact form,
## and by how that form reads -- a reply of which thread, or outside any. Then the operation
## itself over a fake curl: the member is given the reader's lines as they are, and the
## count of thread replies is the real ones'.
## Red recipe: print the mark after the text again in AgentsSlackSearchMatches.awk, and a
## real reply reads as a message outside any thread, alike with the one that only ends with
## the words; take the one space out, and text starting with a mark reads as a reply.
## Offline: a Slack-shaped fake curl is first on PATH, and the operation runs in a workspace
## under this check's temp tree, in $MMDAPP/.local/temp. Never the live team data.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigReader="$rigHere/comms/AgentsSlackSearchMatches.awk"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigReader" ] || rigRefuse "the reader is not at the origin this workspace resolves: $rigReader"
[ -x "$rigTools" ] || rigRefuse "dispatcher not found at the origin this workspace resolves: $rigTools"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the operation would have no member to search as"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsSlackSearchFormCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

## One page as search.messages gives it. A match has no thread_ts of its own: its parent is
## named only in its permalink, and a thread's parent names itself there. Slack lists the
## newest first, so each match goes ahead of the ones before it.
rigParent="1700000100.000100"
rigOther="1700000999.000100"
rigMark="[thread-reply of $rigParent]"
rigMatches=""
rigMatch(){ ## ts, user, text as a JSON string body, parent ts (none: outside any thread)
	rigMatches="$( printf '{"ts":"%s","user":"%s","text":"%s","permalink":"https://rig.slack.com/archives/CRIG00001/p%s%s%s"}' \
		"$1" "$2" "$3" "${1%.*}" "${1#*.}" "${4:+?thread_ts=$4&cid=CRIG00001}" )${rigMatches:+,$rigMatches}"
}
rigMatch 1700000100.000100 URIGOWNER 'the parent of a thread' "$rigParent"
rigMatch 1700000200.000100 URIGOWNER 'see this' "$rigParent"
rigMatch 1700000300.000100 URIGOTHER "see this $rigMark"
rigMatch 1700000400.000100 URIGOTHER "$rigMark typed at the start"
rigMatch 1700000500.000100 URIGOTHER "\n$rigMark typed on a second line"
rigMatch 1700000600.000100 URIGOTHER "<!date^1700000000^{date}|$rigMark> out of a date"
rigMatch 1700000700.000100 URIGOWNER "[thread-reply of $rigOther] naming another thread" "$rigParent"
rigMatch 1700000800.000100 URIGOWNER '' "$rigParent"
rigMatch 1700000900.000100 URIGOTHER 'plain, outside any thread'
printf '{"ok":true,"messages":{"total":9,"paging":{"count":100,"total":9,"page":1,"pages":1},"matches":[%s]}}\n' "$rigMatches" > "$rigTmp/search.json"

echo "-- the reader alone: a reply's mark ahead of its text, and text never in the mark's place --"
LC_ALL=C awk -v cutoff=1700000000 -f "$rigReader" < "$rigTmp/search.json" > "$rigTmp/lines" 2> "$rigTmp/lines.err" ; rigRc=$?
rigLine(){ ## ts -> that match's line
	LC_ALL=C awk -v wantTs="$1" 'index( $0, wantTs " | " ) == 1 { print ; }' "$rigTmp/lines"
}
## How a line reads by the form: a mark right after the second bar names the thread the
## message is a reply in, and anything else there is the message's own text.
rigReadsAs(){ ## ts -> `reply of <parent-ts>`, or `outside any thread`
	rigLine "$1" | LC_ALL=C awk '{
		rest = $0 ;
		sub( /^[^ ]+ \| [^ ]+ \|/, "", rest ) ;
		if ( match( rest, /^ \[thread-reply of [0-9]+\.[0-9]+\]/ ) ) {
			print "reply of " substr( rest, 19, RLENGTH - 19 ) ;
		} else {
			print "outside any thread" ;
		} ;
	}'
}
## A line without its own ts and user: what is left to tell two messages' places apart.
rigPlace(){ ## ts
	rigLine "$1" | LC_ALL=C sed 's/^[^ ]* | [^ ]* |//'
}
rigAssert "the page is read: one line per match, oldest first, nothing said aside" \
	"$rigRc:$( LC_ALL=C awk '{ printf "%s ", substr( $1, 8, 3 ) ; }' "$rigTmp/lines" ):$( LC_ALL=C wc -c < "$rigTmp/lines.err" | LC_ALL=C tr -d ' ' )" \
	"0:100 200 300 400 500 600 700 800 900 :0"
rigAssert "a real reply: its mark stands ahead of its text" \
	"$( rigLine 1700000200.000100 )" "1700000200.000100 | URIGOWNER | $rigMark see this"
rigAssert "and it reads as a reply in that thread" \
	"$( rigReadsAs 1700000200.000100 )" "reply of $rigParent"
rigAssert "a message outside any thread whose text ends with those words: the text as it is" \
	"$( rigLine 1700000300.000100 )" "1700000300.000100 | URIGOTHER | see this $rigMark"
rigAssert "and it reads as outside any thread" \
	"$( rigReadsAs 1700000300.000100 )" "outside any thread"
rigAssert "the two do not read alike: the same words by a reply and by text ending with its mark" \
	"$( [ "$( rigPlace 1700000200.000100 )" = "$( rigPlace 1700000300.000100 )" ] && printf alike || printf apart )" apart
rigAssert "text that itself starts with a mark is printed one space in" \
	"$( rigLine 1700000400.000100 ):$( rigReadsAs 1700000400.000100 )" "1700000400.000100 | URIGOTHER |  $rigMark typed at the start:outside any thread"
rigAssert "a mark at the start of a later line of the text, flattened, is no nearer" \
	"$( rigLine 1700000500.000100 ):$( rigReadsAs 1700000500.000100 )" "1700000500.000100 | URIGOTHER |  $rigMark typed on a second line:outside any thread"
rigAssert "a mark out of a date's fallback text is no mark either" \
	"$( rigLine 1700000600.000100 ):$( rigReadsAs 1700000600.000100 )" "1700000600.000100 | URIGOTHER |  $rigMark out of a date:outside any thread"
rigAssert "a real reply whose text names another thread is a reply in its own" \
	"$( rigLine 1700000700.000100 ):$( rigReadsAs 1700000700.000100 )" "1700000700.000100 | URIGOWNER | $rigMark  [thread-reply of $rigOther] naming another thread:reply of $rigParent"
rigAssert "a reply with no text is its mark alone" \
	"$( rigLine 1700000800.000100 ):$( rigReadsAs 1700000800.000100 )" "1700000800.000100 | URIGOWNER | $rigMark :reply of $rigParent"
rigAssert "control: a thread's parent is no reply, and a plain message is printed as it was" \
	"$( rigLine 1700000100.000100 ):$( rigReadsAs 1700000100.000100 ):$( rigLine 1700000900.000100 )" \
	"1700000100.000100 | URIGOWNER | the parent of a thread:outside any thread:1700000900.000100 | URIGOTHER | plain, outside any thread"
rigAssert "the page's own count of thread replies is the real ones'" \
	"$( LC_ALL=C awk -v cutoff=1700000000 -v mode=meta -f "$rigReader" < "$rigTmp/search.json" | LC_ALL=C awk -F= '$1 == "PAGE_IN_RANGE_COUNT" || $1 == "PAGE_THREAD_REPLIES" { printf "%s:", $2 ; }' )" "9:3:"

echo "-- the operation: the member is given the reader's lines as they are --"
mkdir -p "$rigTmp/bin" "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/agents" "$rigTmp/data"
cat > "$rigTmp/bin/curl" <<'RIG_CURL'
#!/usr/bin/env bash
## Slack-shaped fake curl: logs each method and answers a search from the rig's own page. Opens no socket.
cat > /dev/null
rigMethod="no-method"
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
		http://*|https://*) rigMethod="url:$rigArg" ;;
	esac
done
printf '%s\n' "$rigMethod" >> "$RIG_CURL_LOG"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
	search.messages) cat "$RIG_SEARCH_PAGE" ;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
RIG_CURL
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigTmp/ws/.local/.agents/$rigMember.agent.env"
RIG_CURL_LOG="$rigTmp/curl.log"
RIG_SEARCH_PAGE="$rigTmp/search.json"
export RIG_CURL_LOG RIG_SEARCH_PAGE
: > "$RIG_CURL_LOG"
( cd "$rigTmp/ws" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID \
	MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" bash "$rigTools" --member-comms-slack-search-messages "$rigMember" CRIG00001 --comms-since-utime 1700000000 ) \
	> "$rigTmp/op.out" 2> "$rigTmp/op.err" < /dev/null ; rigRc=$?
rigAssert "the search is done and complete, in the conversation asked for" \
	"$rigRc:$( LC_ALL=C sed -n '1s/ query=.*//p' "$rigTmp/op.out" )" "0:## target=CRIG00001 channel=CRIG00001"
rigAssert "its lines are the reader's own, each as the reader printed it" \
	"$( LC_ALL=C grep -v '^## ' "$rigTmp/op.out" )" "$( cat "$rigTmp/lines" )"
rigAssert "and its own count of thread replies is the real ones'" \
	"$( LC_ALL=C sed -n 's/^## matches=\([0-9]*\) thread-replies=\([0-9]*\) .*/\1:\2/p' "$rigTmp/op.out" )" "9:3"
rigAssert "the search was asked of the fake, once" "$( LC_ALL=C grep -c -x 'search.messages' "$RIG_CURL_LOG" )" 1
rigAssert "no request went anywhere but a Slack method" \
	"$( LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK SEARCH FORM CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_SEARCH_FORM: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
