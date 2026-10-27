#!/usr/bin/env bash
## Behavioural check on a member's own send into the event-track channel (S11.1 remainder, sketch 12.2): it goes
## through the channel's outbox rules (AgentsTools.EventTrackSend.include) without being rewritten as a tracking post.
## Held: what is queued for the channel is posted first, in its order, and the member's message after it; the two
## messages are no closer than the 7 s window; the moment of the member's post is noted, so the next post of the channel
## waits its window from it; a send into any other channel notes nothing. A Slack-shaped fake curl
## stands first on PATH and writes down the second, the API and the text of each call. Against a rig workspace built
## here; nothing of the real workspace is read or written. Offline.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsEventTrackMemberSendCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigLog="$rigTmp/curl.log"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_CHANNEL_MAGIC_TEAM=CRIGTEAM\nSLACK_BOT_TOKEN=rig-bot-token\n' > "$rigWs/.local/.agents/magic-team.agent.env"
: > "$rigLog"
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/bash
url="" body=""
while [ $# -gt 0 ] ; do
	case "$1" in
		https://*) url="$1" ;;
		--data-binary|-d|--data) case "$2" in @*) body="$( cat "${2#@}" 2> /dev/null )" ;; *) body="$2" ;; esac ; shift ;;
	esac
	shift
done
api="${url##*/}"
printf '%s\t%s\t%s\n' "$( date +%s )" "$api" "$( printf '%s' "$body" | LC_ALL=C tr '\n\t' '  ' | LC_ALL=C cut -c1-4000 )" >> "$RIG_CURL_LOG"
case "$api" in
	auth.test) printf '{"ok":true,"user_id":"URIGBOT","user":"rigbot","team_id":"TRIG"}\n' ;;
	*) printf '{"ok":true,"ts":"1700000000.%06d","channel":"CRIGTRACK","message":{"ts":"1700000000.%06d"}}\n' "$RANDOM" "$RANDOM" ;;
esac
RIGCURL
chmod +x "$rigTmp/bin/curl"
export RIG_CURL_LOG="$rigLog"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigSendOp(){ ## text, target -> the member's send, as the member
	( cd "$rigWs" && printf '%s' "$1" | env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT=keeper-myx PATH="$rigTmp/bin:$PATH" MMDAPP="$rigWs" \
		MDLT_ORIGIN="$MDLT_ORIGIN" RIG_CURL_LOG="$rigLog" bash "$rigTool" --intern-op-comms-slack-send-message keeper-myx "$2" --identity-bot --from-stdin ) > "$rigTmp/send.out" 2> "$rigTmp/send.err"
}
rigPosts(){ ## -> the chat.postMessage lines of the log, "<second>\t<text>"
	LC_ALL=C awk -F'\t' '$2 == "chat.postMessage" { print $1 "\t" $3 }' "$rigLog"
}

## ONE TRACKING POST WAITS IN THE CHANNEL'S OUTBOX: queued, not sent, as a post of the tooling waits behind a sender.
rigQueue="$rigWs/.local/agents/event-track-send/CRIGTRACK"
mkdir -p "$rigTmp/src" && : > "$rigTmp/src/lines" && printf 'what=rig-queued-notice\0' > "$rigTmp/src/fields"
MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.EventTrackSend.include"
	queue="$( AgentsToolsEventTrackSendDir CRIGTRACK )" && AgentsToolsEventTrackSendAppend "$queue" keeper-myx notice "" event-track CRIGTRACK "" "$1/fields" "$1/lines"' rig "$rigTmp/src" > /dev/null \
	|| rigRefuse "the rig could not queue a post"
rigAssert "control: one post waits in the outbox, nothing was sent" "$( find "$rigQueue" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*' | LC_ALL=C awk 'END { print NR + 0 }' ):$( rigPosts | LC_ALL=C awk 'END { print NR + 0 }' )" "1:0"

rigSendOp "rig direct message one" event-track
rigAssert "the send ends 0" "$( LC_ALL=C grep -c 'ok\|SENT_MESSAGE' "$rigTmp/send.err" "$rigTmp/send.out" | LC_ALL=C awk -F: '{ n += $2 } END { print ( n > 0 ? "answered" : "silent" ) }' )" "answered"
rigAssert "the queued post went first and the member's message after it: two posts, in that order" \
	"$( rigPosts | LC_ALL=C awk -F'\t' 'NR == 1 && index( $2, "rig-queued-notice" ) { first = "queued" } NR == 2 && index( $2, "rig direct message one" ) { second = "direct" } END { print NR ":" first ":" second }' )" "2:queued:direct"
rigAssert "the two are no closer than the 7 s window" \
	"$( rigPosts | LC_ALL=C awk -F'\t' 'NR == 1 { at = $1 } NR == 2 { print ( $1 - at >= 7 ? "paced" : "too-close:" ( $1 - at ) ) }' )" "paced"
rigAssert "the outbox left empty, the moment of the member's post noted" \
	"$( find "$rigQueue" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*' | LC_ALL=C awk 'END { print NR + 0 }' ):$( [ -s "$rigQueue/last-send" ] && printf noted || printf missing )" "0:noted"
rigLastSeen="$( cat "$rigQueue/last-send" 2> /dev/null )"
rigSecondAt="$( rigPosts | LC_ALL=C awk -F'\t' 'NR == 2 { print $1 }' )"
rigAssert "the noted moment is that of the member's post, within a second" "$( [ -n "$rigLastSeen" ] && [ -n "$rigSecondAt" ] && [ "$(( rigLastSeen - rigSecondAt ))" -le 1 ] && [ "$(( rigLastSeen - rigSecondAt ))" -ge 0 ] && printf same || printf "last=$rigLastSeen second=$rigSecondAt" )" "same"

rigBefore="$( rigPosts | LC_ALL=C awk 'END { print NR + 0 }' )"
rigSendOp "rig direct message two" event-track
rigAssert "the next send waits its window from the member's post: no closer than 7 s" \
	"$( rigPosts | LC_ALL=C awk -F'\t' -v skip="$rigBefore" 'NR == skip { at = $1 } NR == skip + 1 { print ( $1 - at >= 7 ? "paced" : "too-close:" ( $1 - at ) ) }' )" "paced"

echo "-- a send into another channel notes nothing --"
rigTeamBefore="$( cat "$rigQueue/last-send" 2> /dev/null )"
rigSendOp "rig team message" magic-team
rigAssert "magic-team: posted, and the event-track moment unchanged" \
	"$( rigPosts | LC_ALL=C awk -F'\t' 'index( $2, "rig team message" ) { n++ } END { print n + 0 }' ):$( [ "$( cat "$rigQueue/last-send" 2> /dev/null )" = "$rigTeamBefore" ] && printf unchanged || printf changed )" "1:unchanged"

if [ "$rigFails" -gt 0 ] ; then
	echo "⛔ EVENT TRACK MEMBER SEND CHECK FAILED: $rigFails of $(( rigFails + rigPasses )) assertion(s)" >&2
	exit 1
fi
echo "EVENT_TRACK_MEMBER_SEND: OK ($rigPasses assertions, offline)"
