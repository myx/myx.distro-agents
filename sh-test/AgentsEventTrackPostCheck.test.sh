#!/usr/bin/env bash
## Behavioural check on the tooling's own tracking posts (--intern-op-event-track-post,
## AgentsTools.InternOpEventTrackPost.include): every kind renders from the template
## sh-lib/templates/event-track.post.format.md with the member and the short session id
## in its header; no post carries @here or an addressee line; lines are one code block; a
## long batch is cut into posts of at most MDAT_EVENT_TRACK_CHUNK_BYTES; the op posts through
## the shared Slack call (a rate limit is waited out), threads the later parts of a post under
## the first, replaces a post in place, and logs each post; and the event-track feed picks the
## kind of a batch from its lines.
## Offline: a Slack-shaped fake curl first on PATH answers every call, and every op runs in a
## clean environment whose workspace and data root sit under this rig's own mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/templates/event-track.post.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigTemplate" ] || rigRefuse "the template is not in the package: $rigTemplate"
rigTmp="$( mktemp -d -t AgentsEventTrackPostCheck )" || exit 1
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
rigYes(){ "$@" > /dev/null 2>&1 && printf yes || printf no ; }

## ---------------------------------------------------------------------------
echo "-- every kind renders from the template --"
## ---------------------------------------------------------------------------
set -- --rig-none
MDSC_CMD=rig
. "$rigLib/AgentsTools.InternOpEventTrackPost.include"
rigLines="$rigTmp/lines"
{
	printf '2030-01-01T00:01:00Z TOOL Read path=/x -> ok 3B/1L 2ms\n'
	printf '2030-01-01T00:01:01Z TOOL Edit path=/x -> refused "ERROR: refused by a hook"\n'
	printf '> ERROR: refused by a hook\n'
	printf '2030-01-01T00:01:02Z ROUND n=4 in=1 cache-read=2 cache-write=0 out=3\n'
} > "$rigLines"
rigRender(){ ## kind, out dir, lines file, name=value...
	local renderKind="$1" renderDir="$2" renderFrom="$3"
	shift 3
	rm -rf "$renderDir" ; mkdir -p "$renderDir"
	AgentsEventTrackPostRender "$renderKind" magic-tester abcdef01-2345-4000-8000-000000000001 "$renderDir" "$renderFrom" "$@"
}
for rigKindLabel in 'start|🚀|session start' 'activity|📋|activity' 'state|🔄|state change' 'handback|📦|handback' 'review|🔍|review' \
	'dismissed|🛑|dismissed' 'refusal|🚫|refusal' 'error|⛔|error' 'end|🏁|session end' 'notice|⚠️|notice' ; do
	rigKind="${rigKindLabel%%|*}" ; rigRest="${rigKindLabel#*|}" ; rigEmoji="${rigRest%%|*}" ; rigLabel="${rigRest#*|}"
	rigFrom="$rigLines" ; [ "$rigKind" != start ] || rigFrom=/dev/null
	rigRender "$rigKind" "$rigTmp/k-$rigKind" "$rigFrom" what=rig-what cli=rig-cli outcome=succeeded tokens='in=1 out=2'
	rigPost="$rigTmp/k-$rigKind/000001"
	rigAssert "$rigKind: one post, its header the kind's emoji, the member, the kind and the short session" \
		"$( ls "$rigTmp/k-$rigKind" | LC_ALL=C awk 'END { print NR }' ):$( head -1 "$rigPost" )" "1:$rigEmoji *magic-tester* · $rigLabel · \`abcdef01\`"
	rigAssert "$rigKind: no @here, no addressee arrow, no member-message author line" \
		"$( LC_ALL=C grep -c -e '@here' -e '→' -e '\*_' "$rigPost" )" 0
	if [ "$rigKind" != start ] ; then
		rigAssert "$rigKind: the lines are one code block, fenced, after the fields" \
			"$( LC_ALL=C grep -c '^```$' "$rigPost" ):$( LC_ALL=C awk '/^```$/ { n++ ; next } n == 1 { c++ } END { print c + 0 }' "$rigPost" ):$( tail -1 "$rigPost" )" '2:4:```'
	fi
done
rigAssert "the fields the caller gave fill their slots" "$( LC_ALL=C grep -c -x -F 'what: rig-what' "$rigTmp/k-error/000001" ):$( LC_ALL=C grep -c -x -F 'tokens: in=1 out=2' "$rigTmp/k-end/000001" )" 1:1
rigAssert "a line whose slots are all empty is left out" "$( LC_ALL=C grep -c -e '^detail:' -e '^part:' "$rigTmp/k-error/000001" )" 0
rigAssert "an empty slot on a kept line reads -" "$( LC_ALL=C grep -c -x -F 'outcome: succeeded · exit: - · launched: -' "$rigTmp/k-end/000001" )" 1
rigAssert "the tooling counts the line kinds and their span" "$( LC_ALL=C grep -x 'events: .*' "$rigTmp/k-activity/000001" )" 'events: TOOL 2, ROUND 1 · span: 00:01:00 to 00:01:02'
rigRender nonesuch "$rigTmp/k-none" "$rigLines" ; rigNoneRc=$?
rigAssert "a kind the template has no block for renders nothing" "$rigNoneRc:$( ls "$rigTmp/k-none" | LC_ALL=C awk 'END { print NR }' )" 3:0
rigRender start "$rigTmp/k-nosession" /dev/null
AgentsEventTrackPostRender notice magic-tester "" "$rigTmp/k-nosession" /dev/null what=x
rigAssert "no session reads - in the header" "$( head -1 "$rigTmp/k-nosession/000001" )" '⚠️ *magic-tester* · notice · `-`'

echo "-- nothing in a value or a line mentions anyone or breaks the code --"
printf '2030-01-01T00:02:00Z TOOL SendMessage text=<!here> <@U123> & ```x``` -> ok\n' > "$rigTmp/lines.esc"
rigRender refusal "$rigTmp/k-esc" "$rigTmp/lines.esc" target='/a`b<c>' reason="$( printf 'two\nlines=injected' )"
rigAssert "Slack's control characters in a line are escaped" "$( LC_ALL=C grep -c -F 'text=&lt;!here&gt; &lt;@U123&gt; &amp;' "$rigTmp/k-esc/000001" )" 1
rigAssert "a backtick in a value is %60, its < and > escaped" "$( LC_ALL=C grep -c -F 'target: `/a%60b&lt;c&gt;`' "$rigTmp/k-esc/000001" )" 1
rigAssert "a newline in a value opens no other field" "$( LC_ALL=C grep -c -x -F 'reason: two%0Alines=injected' "$rigTmp/k-esc/000001" )" 1
rigAssert "a code fence inside a line does not end the block" "$( LC_ALL=C grep -c '^```$' "$rigTmp/k-esc/000001" ):$( LC_ALL=C grep -c '```x```' "$rigTmp/k-esc/000001" )" 2:0

echo "-- a long batch is cut into posts of at most the chunk size --"
rigLong="$rigTmp/lines.long"
LC_ALL=C awk 'BEGIN { for ( n = 1 ; n <= 120 ; n++ ) printf "2030-01-01T00:03:%02dZ TOOL Read path=/a/long/enough/path/number/%03d -> ok 10B/1L 1ms\n", n % 60, n ; for ( n = 1 ; n <= 4000 ; n++ ) printf "0" ; printf "\n" }' > "$rigLong"
rigChunkCheck(){ ## cap -- PASS lines for the posts in $rigTmp/k-long
	local checkDir="$rigTmp/k-long" checkPost checkOver=0 checkFence=0 checkHeader=0 checkPart=0 checkTotal checkNo=0
	checkTotal="$( ls "$checkDir" | LC_ALL=C awk 'END { print NR }' )"
	for checkPost in "$checkDir"/* ; do
		checkNo=$(( checkNo + 1 ))
		[ "$( LC_ALL=C wc -c < "$checkPost" | tr -d ' ' )" -le "$1" ] || checkOver=$(( checkOver + 1 ))
		[ "$( LC_ALL=C grep -c '^```$' "$checkPost" )" = 2 ] && [ "$( tail -1 "$checkPost" )" = '```' ] || checkFence=$(( checkFence + 1 ))
		[ "$( head -1 "$checkPost" )" = '📋 *magic-tester* · activity · `abcdef01`' ] || checkHeader=$(( checkHeader + 1 ))
		LC_ALL=C grep -q -x -F "part: $checkNo of $checkTotal" "$checkPost" || checkPart=$(( checkPart + 1 ))
	done
	rigAssert "cap $1: several posts" "$( [ "$checkTotal" -gt 1 ] && printf yes || printf no )" yes
	rigAssert "cap $1: none over the cap, each one fenced block, each with the header and its part" "$checkOver:$checkFence:$checkHeader:$checkPart" 0:0:0:0
	rigAssert "cap $1: the lines, joined again, are the batch, in order, once" \
		"$( for checkPost in "$checkDir"/* ; do LC_ALL=C awk '/^```$/ { n++ ; next } n == 1' "$checkPost" ; done | LC_ALL=C tr -d '\n' | LC_ALL=C sed 's/-&gt;/->/g' | cksum )" \
		"$( LC_ALL=C tr -d '\n' < "$rigLong" | cksum )"
}
rigRender activity "$rigTmp/k-long" "$rigLong"
rigChunkCheck 3000
MDAT_EVENT_TRACK_CHUNK_BYTES=300 rigRender activity "$rigTmp/k-long" "$rigLong"
rigChunkCheck 300

echo "-- the feed picks a batch's kind by its most important line --"
. "$rigLib/AgentsTools.EventTrackFeed.include"
rigFeedKind(){ AgentsEventTrackFeedKind "$( printf '2030-01-01T00:00:00Z %s\n' "$@" )" ; }
rigAssert "ordinary lines are activity" "$( rigFeedKind 'TOOL Read -> ok' 'ROUND n=1' )" activity
rigAssert "a model or restart line is a state change" "$( rigFeedKind 'TOOL Read -> ok' 'RESTART n=1' )" state
rigAssert "a review or verdict line is review" "$( rigFeedKind 'MODEL model=m' 'VERDICT item=x' )" review
rigAssert "a dismissal or ending is dismissed" "$( rigFeedKind 'VERDICT item=x' 'ENDING item=x' )" dismissed
rigAssert "a handback is handback" "$( rigFeedKind 'ENDING item=x' 'HANDBACK to=x' )" handback
rigAssert "a refused call is refusal" "$( rigFeedKind 'HANDBACK to=x' 'TOOL Edit -> refused "x"' )" refusal
rigAssert "an error wins over everything" "$( rigFeedKind 'TOOL Edit -> refused "x"' 'TOOL Read -> error "x"' 'HANDBACK to=x' )" error

## ---------------------------------------------------------------------------
echo "-- the op posts through the shared Slack call, offline --"
## ---------------------------------------------------------------------------
mkdir -p "$rigTmp/bin" "$rigTmp/ws/.local/.agents" "$rigTmp/data" "$rigTmp/skills/magic-tester" "$rigTmp/home" "$rigTmp/scenario"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/skills/magic-tester/magic-tester.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-not-a-token\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
## A Slack-shaped curl: logs each method, keeps each body, answers by method; a scenario file
## makes the first call rate-limited (status and Retry-After where -D names a file) or refused.
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
if [ -f "$RIG_SCENARIO/ratelimit-once" ] ; then
	rm -f "$RIG_SCENARIO/ratelimit-once"
	[ -z "$rigHeaders" ] || printf 'HTTP/2 429\r\nretry-after: 1\r\n\r\n' > "$rigHeaders"
	printf '{"ok":false,"error":"ratelimited"}\n'
	exit 0
fi
[ -z "$rigHeaders" ] || printf 'HTTP/2 200\r\n\r\n' > "$rigHeaders"
case "$rigMethod" in
	chat.postMessage|chat.update)
		if [ -f "$RIG_SCENARIO/refuse" ] ; then printf '{"ok":false,"error":"channel_not_found"}\n' ; exit 0 ; fi
		rigN=$(( $( cat "$RIG_SCENARIO/posts" 2>/dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigN" > "$RIG_SCENARIO/posts"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/post.$rigN"
		printf '{"ok":true,"channel":"CRIGTRACK","ts":"1700000001.00010%s","message":{"ts":"1700000001.00010%s"}}\n' "$rigN" "$rigN"
	;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
RIGEOF
chmod +x "$rigTmp/bin/curl"
rigOp(){ ## stdin file, op arguments... -- stdout to op.out, stderr to op.err, rc to rigOpRc
	local opIn="$1" ; shift
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" TMPDIR="$rigTmp" \
		MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_SESSION_ID=rig-sender-session RIG_SCENARIO="$rigTmp/scenario" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		${RIG_CHUNK:+MDAT_EVENT_TRACK_CHUNK_BYTES="$RIG_CHUNK"} \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: curl is not the rig fake" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" < "$opIn" > "$rigTmp/op.out" 2> "$rigTmp/op.err"
	rigOpRc=$?
}
rigReset(){ rm -f "$rigTmp/scenario"/* ; }
rigCalls(){ LC_ALL=C grep -c -x -F "$1" "$rigTmp/scenario/calls" 2>/dev/null || : ; }
rigLog(){ cat "$rigTmp/ws/.local/agents"/comms-slack-send.*.log 2>/dev/null ; }

rigReset
rigOp "$rigLines" --intern-op-event-track-post magic-tester event-track --kind activity --session-id abcdef01-2345 --from-stdin
rigAssert "a post succeeds"                              "$rigOpRc" 0
rigAssert "one chat.postMessage, and no addressee lookup" "$( rigCalls chat.postMessage ):$( rigCalls conversations.info ):$( rigCalls auth.test )" 1:0:0
rigBody="$rigTmp/scenario/post.1"
rigAssert "to the event-track channel, top level"        "$( rigYes env LC_ALL=C grep -q -F '"channel":"CRIGTRACK","text":"' "$rigBody" ):$( rigYes env LC_ALL=C grep -q -F 'thread_ts' "$rigBody" )" yes:no
rigAssert "its text opens with the rendered header"      "$( rigYes env LC_ALL=C grep -q -F '"text":"📋 *magic-tester* · activity · `abcdef01`\nevents: TOOL 2, ROUND 1' "$rigBody" )" yes
rigAssert "its lines are one fenced block"               "$( rigYes env LC_ALL=C grep -q -F '\n```\n2030-01-01T00:01:00Z TOOL Read path=/x -&gt; ok 3B/1L 2ms\n' "$rigBody" )" yes
rigAssert "no @here and no addressee arrow"              "$( LC_ALL=C grep -c -e '@here' -e '→' "$rigBody" )" 0
rigAssert "the sender is named in its metadata, with the kind" "$( rigYes env LC_ALL=C grep -q -F '"metadata":{"event_type":"magic_sender","event_payload":{"sender":"magic-tester","tracking":"activity"}}' "$rigBody" )" yes
rigAssert "the post is reported as the member send reports one" "$( LC_ALL=C grep -c -e '^SENT_MESSAGE_CHANNEL=CRIGTRACK$' -e '^SENT_MESSAGE_TS=1700000001.000101$' "$rigTmp/op.err" )" 2
rigAssert "one ok line in the monthly send log, as the bot" "$( rigLog | LC_ALL=C awk -F'\t' '$2 == "magic-tester" && $3 == "event-track" && $4 == "CRIGTRACK" && $5 == "bot" && $6 == "ok" && $8 == "rig-sender-session" { n++ } END { print n + 0 }' )" 1

echo "-- a long post to a conversation threads its later parts under the first --"
rigReset
RIG_CHUNK=300 rigOp "$rigLong" --intern-op-event-track-post magic-tester event-track --kind activity --session-id abcdef01-2345 --from-stdin
rigPosts="$( cat "$rigTmp/scenario/posts" 2>/dev/null || echo 0 )"
rigAssert "several posts"                                "$rigOpRc:$( [ "$rigPosts" -gt 2 ] && printf yes || printf no )" 0:yes
rigAssert "the first opens the thread, every later one is in it" \
	"$( rigYes env LC_ALL=C grep -q -F 'thread_ts' "$rigTmp/scenario/post.1" ):$( LC_ALL=C grep -l -F '"thread_ts":"1700000001.000101"' "$rigTmp/scenario"/post.[0-9]* | LC_ALL=C awk 'END { print NR }' )" "no:$(( rigPosts - 1 ))"

echo "-- into a thread, and in place --"
rigReset
rigOp /dev/null --intern-op-event-track-post magic-tester CRIGTRACK:1699999999.000001 --kind end --session-id abcdef01-2345 --field outcome=succeeded
rigAssert "a post into a thread names it"                "$rigOpRc:$( rigYes env LC_ALL=C grep -q -F '"thread_ts":"1699999999.000001"' "$rigTmp/scenario/post.1" )" 0:yes
rigReset
rigOp /dev/null --intern-op-event-track-post magic-tester CRIGTRACK:1699999999.000001 --kind start --session-id abcdef01-2345 --field cli=configured --field cli=rig-cli --update
rigAssert "an update replaces that post, the later field winning" \
	"$rigOpRc:$( rigCalls chat.update ):$( rigYes env LC_ALL=C grep -q -F '"channel":"CRIGTRACK","ts":"1699999999.000001","text":"🚀 *magic-tester* · session start · `abcdef01`\ncli: rig-cli · ' "$rigTmp/scenario/post.1" )" 0:1:yes

echo "-- a rate limit is waited out by the shared call --"
rigReset
: > "$rigTmp/scenario/ratelimit-once"
rigOp "$rigLines" --intern-op-event-track-post magic-tester event-track --kind activity --from-stdin
rigAssert "two calls, one post"                          "$rigOpRc:$( rigCalls chat.postMessage ):$( cat "$rigTmp/scenario/posts" )" 0:2:1
rigAssert "the wait was said"                            "$( LC_ALL=C grep -c 'waiting 1s as Retry-After asks' "$rigTmp/op.err" )" 1

echo "-- a refused post fails, said and logged --"
rigReset
: > "$rigTmp/scenario/refuse"
rigLogBefore="$( rigLog | LC_ALL=C awk 'END { print NR }' )"
rigOp "$rigLines" --intern-op-event-track-post magic-tester event-track --kind activity --from-stdin
rigAssert "the op fails with one ERROR line"             "$rigOpRc:$( LC_ALL=C grep -c '^⛔ ERROR: .*--intern-op-event-track-post: the activity post, part 1 of 1, was not posted' "$rigTmp/op.err" )" 1:1
rigAssert "and logs it failed"                           "$( rigLog | LC_ALL=C awk -F'\t' -v from="$rigLogBefore" 'NR > from && $6 == "failed" { n++ } END { print n + 0 }' )" 1

echo "-- no request left for a real host --"
rigAssert "every call was a Slack method the fake answered" "$( cat "$rigTmp/scenario/calls" 2>/dev/null | LC_ALL=C grep -c -e '^url:' -e '^no-method$' || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ EVENT TRACK POST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'EVENT_TRACK_POST: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
