#!/usr/bin/env bash
## Behavioural check on THE WAKE LATENCY of a wait: how long after an arrival does a waiting session wake?
##
## A duty session's routine promises it "wakes within seconds of an item arriving in its inbox", and the owner
## reported two failures of that promise: an idle-wait that "reacts in 5 minutes or so", and a coordinator's
## Slack DM that was not read "in like 20 minutes". The cause was the cadence: one poll interval for every
## source, five seconds growing to five minutes, so a local arrival waited for it. The fix is a one-second tick
## over the kinds read out of files, the growing gap kept for the kinds read over the network, and a wake marker
## the send operation writes (AgentsTools.WakeMarker.include, AgentsTools.MemberWait.include).
##
## So this check MEASURES, and never assumes:
##   - an item dropped in the inbox is woken on in about a second, early in the wait and forty seconds into it;
##   - an item dropped in a watched board state is woken on the same way;
##   - a message our own member sends wakes the wait in about a second, through the real send operation, which
##     writes the recipient's marker, and the message itself -- a new Slack message -- is what the return carries;
##   - the marker is no arrival of its own, and it brings a costly source's next look forward at once;
##   - a scan-only watcher is woken by the marker too, not by the scan's 300 s TTL nor by the end of the
##     session's wait round: the report the scan would carry is returned within seconds of the message;
##   - and the tick is no Slack spin: a quiet wait still reads a Slack thread no more often than the gap it used
##     to poll at (the whole reason that interval existed).
## Offline: a Slack-shaped fake curl is first on PATH and every scenario runs in its own workspace under this
## check's temp tree, in $MMDAPP/.local/temp. The settle of a burst is 0 here, so the number measured is the wake
## and not the settle (a Slack burst in production adds $MDAT_WAIT_SETTLE_SECONDS, three seconds by default).
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"
rigSender="magic-coordinator"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigTool"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigSender/$rigSender.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigSender"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsWaitWakeLatencyCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"

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
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}
rigFirstLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}
rigAtMost(){ ## value, limit
	case "$1" in ''|*[!0-9]*) printf 'not-a-number:%s' "$1" ; return 0 ;; esac
	[ "$1" -le "$2" ] && printf 'at-most-%s' "$2" || printf '%s-over-%s' "$1" "$2"
}
rigAtLeast(){ ## value, limit
	case "$1" in ''|*[!0-9]*) printf 'not-a-number:%s' "$1" ; return 0 ;; esac
	[ "$1" -ge "$2" ] && printf 'at-least-%s' "$2" || printf '%s-under-%s' "$1" "$2"
}
rigNow(){ date +%s ; }
rigFieldN(){ ## the string, the field number, of a measurement line separated by |
	printf '%s' "$1" | LC_ALL=C cut -d'|' -f"$2"
}

## The scenario's thread, its first message, the floor the wait reads from, and the message that lands later.
rigChannel="CRIG00001"
rigThread="1700000001.000101"
rigFloor="1700000001.000200"
rigMessageBefore="1700000001.000101"
rigMessageArrives="1700000001.000301"
rigCurlReads(){ ## the fake Slack's own count of thread reads, or of one method named
	LC_ALL=C awk -v want="${1:-conversations.replies}" '$0 == want { hitCount++ ; } END { print hitCount + 0 ; }' "$rigScenarioDir/curl.log" 2>/dev/null || printf 'no-such-log'
}

## One scenario's workspace: the team's env, the member's, the mention cache the send resolves the recipient's
## account from (so no Slack call has to decide who it is), and the data root.
rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" \
		"$rigScenarioDir/data/inboxes/$rigMember/incoming" "$rigScenarioDir/data/board/backlog" "$rigScenarioDir/slack" || exit 1
	printf 'SLACK_CHANNEL_MAGIC_TEAM=%s\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' "$rigChannel" \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	printf '%s=URIGSELF1=test-er=Test Er=test-er=rig.example\n' "$rigMember" > "$rigScenarioDir/ws/.local/.agents/slack-mention-ids.cache"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	RIG_SCENARIO="$rigScenarioDir/slack"
	export RIG_CURL_LOG RIG_SCENARIO
	: > "$RIG_CURL_LOG"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGCOORD1","text":"RIG before the floor","thread_ts":"%s"}],"has_more":false}\n' \
		"$rigMessageBefore" "$rigThread" > "$RIG_SCENARIO/replies.$rigThread.json"
}
## The message that lands while the wait runs: it is a new message in the thread the wait reads, so a wait that
## reads that thread again finds it -- and one that does not, does not.
rigMessageLands(){
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGCOORD1","text":"RIG before the floor","thread_ts":"%s"},{"ts":"%s","user":"URIGCOORD1","text":"RIG landed while the wait was idle","thread_ts":"%s"}],"has_more":false}\n' \
		"$rigMessageBefore" "$rigThread" "$rigMessageArrives" "$rigThread" > "$RIG_SCENARIO/replies.$rigThread.json"
}
## The wake marker of the member, as the send operation leaves it (AgentsTools.WakeMarker.include).
rigMarker(){ printf '%s' "$rigScenarioDir/ws/.local/agents/wake/$rigMember" ; }
rigWakeTest(){ ## who wrote it (the include's own touch, as the send calls it)
	type AgentsToolsWakeTouch > /dev/null 2>&1 || . "$rigHere/comms/AgentsTools.WakeMarker.include" || return 1
	MMDAPP="$rigScenarioDir/ws" AgentsToolsWakeTouch "$rigMember" "${1:-$rigSender}"
}
## Eight touches, a second apart: a touch lands inside every round of a one-second tick, so each one brings the
## costly source's next look forward and the count of those looks says whether the marker did it.
rigTouchMany(){
	local touchTick
	for touchTick in 1 2 3 4 5 6 7 8 ; do
		rigWakeTest
		[ "$touchTick" = "8" ] || sleep 1
	done
}

## One measured wait: <name> <bound seconds> <arrival after seconds> <arrival function or empty> <sources...>.
## It runs in the scenario's own workspace with no session, so no round of a service bounds it and the cadence
## under test is the whole cadence. Prints "<latency>|<rounds>|<slack reads>|<first line>|<marker?>".
rigMeasure(){
	local name="$1" bound="$2" after="$3" arrivalFn="$4" out started arrived ended latency rounds reads marker=""
	shift 4
	out="$rigScenarioDir/$name.out"
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID \
		MMDAPP="$rigScenarioDir/ws" MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_WAIT_SETTLE_SECONDS=0 MDAT_WAIT_REMIND=off MDAT_COMMS_READER=off \
		bash "$rigTool" --wait-for-input "$rigMember" "$@" --wait-timeout "$bound" ) > "$out" 2> "$out.err" &
	local waitPid=$!
	started="$( rigNow )"
	[ "$after" -le 0 ] || sleep "$after"
	arrived="$( rigNow )"
	rigArrivedAt=""
	[ -z "$arrivalFn" ] || "$arrivalFn"
	## An arrival that is itself a call (a send operation) says when it had made it: the moment the message is
	## posted and its marker written, not the moment that call began.
	[ -z "$rigArrivedAt" ] || arrived="$rigArrivedAt"
	while kill -0 "$waitPid" 2>/dev/null ; do
		[ $(( $( rigNow ) - started )) -lt $(( bound + 90 )) ] || { kill -TERM "$waitPid" 2>/dev/null ; break ; }
		sleep 1
	done
	wait "$waitPid" 2>/dev/null || :
	ended="$( rigNow )"
	latency=$(( ended - arrived ))
	[ "$latency" -ge 0 ] || latency=0
	rounds="$( LC_ALL=C sed -n 's/^# waited: [0-9]*s of .*, \([0-9]*\) poll round(s).*/\1/p' "$out" | head -1 )"
	reads="$( rigCurlReads )"
	[ ! -f "$( rigMarker )" ] || marker="marker-written"
	printf '%s|%s|%s|%s|%s\n' "$latency" "${rounds:-no-rounds}" "$reads" "$( rigFirstLine "$out" )" "${marker:-no-marker}"
}

echo "-- a duty session wakes on an item arriving in its inbox --"
rigStart inbox
rigDropEarly(){ printf -- '---\ntype: inquiry\nfrom: %s\n---\n\nRIG-INBOX-EARLY\n' "$rigSender" > "$rigScenarioDir/data/inboxes/$rigMember/incoming/inquiry-rig-early.md" ; }
rigDropLate(){ printf -- '---\ntype: inquiry\nfrom: %s\n---\n\nRIG-INBOX-LATE\n' "$rigSender" > "$rigScenarioDir/data/inboxes/$rigMember/incoming/inquiry-rig-late.md" ; }
rigEarly="$( rigMeasure inbox-early 30 8 rigDropEarly --wait-source "inbox:$rigMember" )"
printf '  measured: an inbox item dropped 8s into the wait, woken on in %ss (%s poll rounds)\n' "$( rigFieldN "$rigEarly" 1 )" "$( rigFieldN "$rigEarly" 2 )"
rigAssert "an inbox item dropped 8s in is woken on within 2s"    "$( rigAtMost "$( rigFieldN "$rigEarly" 1 )" 2 )" "at-most-2"
rigAssert "and the call it wakes on is the arrival"              "$( rigFieldN "$rigEarly" 4 )" "WAIT-RESULT: RECEIVED"
rigAssert "the waited line names the tick that woke it"          "$( rigHolds "$rigScenarioDir/inbox-early.out" 'poll round(s) at 1s tick for local sources' )" "yes"
rigLate="$( rigMeasure inbox-late 60 40 rigDropLate --wait-source "inbox:$rigMember" )"
printf '  measured: an inbox item dropped 40s into the wait, woken on in %ss (%s poll rounds)\n' "$( rigFieldN "$rigLate" 1 )" "$( rigFieldN "$rigLate" 2 )"
rigAssert "an inbox item dropped 40s in is woken on within 2s"   "$( rigAtMost "$( rigFieldN "$rigLate" 1 )" 2 )" "at-most-2"
rigAssert "and a tick per second of waiting, not one poll per minute" "$( rigAtLeast "$( rigFieldN "$rigLate" 2 )" 35 )" "at-least-35"

echo "-- and on an item arriving in a board state it watches --"
rigStart board
rigBoardDrops(){ printf 'RIG-BOARD-ARRIVAL\n' > "$rigScenarioDir/data/board/backlog/task-rig-arrival.md" ; }
rigBoard="$( rigMeasure board-late 30 8 rigBoardDrops --wait-source "board:backlog" )"
printf '  measured: a board item dropped 8s into the wait, woken on in %ss\n' "$( rigFieldN "$rigBoard" 1 )"
rigAssert "a board item dropped 8s in is woken on within 2s"     "$( rigAtMost "$( rigFieldN "$rigBoard" 1 )" 2 )" "at-most-2"
rigAssert "and the call it wakes on is the arrival"              "$( rigFieldN "$rigBoard" 4 )" "WAIT-RESULT: RECEIVED"

echo "-- a message a member sends wakes the wait on the send, not on a Slack poll --"
rigStart send
## The arrival is the send itself: the coordinator's own operation posts the message (the fake Slack keeps it) and
## writes the recipient's marker, which is the only thing that can wake the wait before its next look at the
## thread. The message is then in the thread the wait reads, so the return carries it.
rigSendArrives(){
	## The message is on Slack before the member's own send writes the marker -- that order is the whole point:
	## the marker says "something for you is there", so what it announces must already be there.
	rigMessageLands
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID \
		MMDAPP="$rigScenarioDir/ws" MDAT_DATA_ROOT="$rigScenarioDir/data" \
		bash "$rigTool" --slack-send-message "$rigSender" "$rigMember" "RIG sent while the wait was idle" ) \
		> "$rigScenarioDir/send.out" 2> "$rigScenarioDir/send.err"
	rigArrivedAt="$( rigNow )"
}
rigSend="$( rigMeasure send-arrival 60 20 rigSendArrives \
	--wait-source "slack:$rigChannel:$rigThread:conversation" --wait-source "wake:$rigMember" --wait-since-utime "$rigFloor" )"
printf '  measured: a message sent 20s into the wait, woken on in %ss (%s rounds, %s Slack reads)\n' \
	"$( rigFieldN "$rigSend" 1 )" "$( rigFieldN "$rigSend" 2 )" "$( rigFieldN "$rigSend" 3 )"
rigAssert "the send operation posted the message"                "$( rigHolds "$rigScenarioDir/send.err" 'SENT_MESSAGE_TS=' )" "yes"
rigAssert "the send wrote the recipient's wake marker"           "$( rigFieldN "$rigSend" 5 )" "marker-written"
rigAssert "the marker woke the wait within 2s, not at a Slack poll" "$( rigAtMost "$( rigFieldN "$rigSend" 1 )" 2 )" "at-most-2"
rigAssert "and the return carries the message that landed"       "$( rigHolds "$rigScenarioDir/send-arrival.out" 'RIG landed while the wait was idle' )" "yes"

echo "-- the marker is a wake-up and never an arrival of its own --"
rigStart marker-only
rigTouchOnce(){ rigWakeTest ; }
rigOnly="$( rigMeasure marker-alone 6 2 rigTouchOnce --wait-source "wake:$rigMember" )"
rigAssert "a marker alone is no arrival: the wait times out"     "$( rigFieldN "$rigOnly" 4 )" "WAIT-RESULT: TIMEOUT"
rigAssert "and what it returns holds nothing of the marker"      "$( rigHolds "$rigScenarioDir/marker-alone.out" 'URIGCOORD1' )" "no"
rigAssert "the marker was written all the same"                  "$( rigFieldN "$rigOnly" 5 )" "marker-written"

echo "-- the tick is no Slack spin, and the marker brings a costly look forward --"
rigStart costly
rigCostlySources=( --wait-source "slack:$rigChannel:$rigThread:conversation" --wait-source "wake:$rigMember" --wait-since-utime "$rigFloor" )
rigQuiet="$( rigMeasure costly-quiet 12 0 "" "${rigCostlySources[@]}" )"
: > "$RIG_CURL_LOG"
rigTouched="$( rigMeasure costly-touched 12 2 rigTouchMany "${rigCostlySources[@]}" )"
printf '  measured: 12 quiet seconds = %s poll rounds, %s Slack reads; the same with 8 marker touches = %s rounds, %s reads\n' \
	"$( rigFieldN "$rigQuiet" 2 )" "$( rigFieldN "$rigQuiet" 3 )" "$( rigFieldN "$rigTouched" 2 )" "$( rigFieldN "$rigTouched" 3 )"
rigAssert "a quiet 12s wait reads Slack no more often than the old gap" "$( rigAtMost "$( rigFieldN "$rigQuiet" 3 )" 4 )" "at-most-4"
rigAssert "and it ticks many times more often than it reads Slack" "$( rigAtLeast "$( rigFieldN "$rigQuiet" 2 )" 8 )" "at-least-8"
rigAssert "eight marker touches bring the costly look forward, ahead of the gap" \
	"$( rigAtLeast "$( rigFieldN "$rigTouched" 3 )" $(( $( rigFieldN "$rigQuiet" 3 ) + 4 )) )" "at-least-$(( $( rigFieldN "$rigQuiet" 3 ) + 4 ))"
rigAssert "and no more than once each: the marker is no permission to spin" \
	"$( rigAtMost "$( rigFieldN "$rigTouched" 3 )" $(( $( rigFieldN "$rigQuiet" 3 ) + 8 )) )" "at-most-$(( $( rigFieldN "$rigQuiet" 3 ) + 8 ))"

echo "-- a scan-only watcher is woken on the message, not on the scan's 300 s TTL --"
## The duty's own wait: the scan the routine declares, and the marker --idle-wait adds, called again and again as
## the harness calls it. The first call hands over the report and stores its baseline; the message lands 8s into the
## second call, and what is measured is the time that call takes to return it. Before the scan was woken by the
## marker the report could only be re-read at the scan's TTL of the table (300s) or at the next call's first round,
## so this wait ended TIMEOUT and the message was returned five minutes later, on the call after it.
rigStart scanwake
printf 'WAIT_COLLECT_SECONDS=1\n' >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
rigScanSession="rig-scan-wake"
mkdir -p "$rigScenarioDir/ws/.local/agents/spawned/rig"
printf -- '---\nspawn-id: %s\nsession-id: %s\nstatus: spawn-started\n---\n' "$rigScanSession" "$rigScanSession" \
	> "$rigScenarioDir/ws/.local/agents/spawned/rig/$rigScanSession.spawn.md"
rigScanWait(){ ## output name -- one call of the duty's wait, bounded by the session's own round
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MMDAPP="$rigScenarioDir/ws" MDAT_DATA_ROOT="$rigScenarioDir/data" \
		MDAT_SESSION_ID="$rigScanSession" MDAT_SPAWN_SESSION_ID="$rigScanSession" MDAT_SPAWN_AGENT="$rigMember" \
		MDAT_WAIT_SETTLE_SECONDS=0 MDAT_WAIT_REMIND=off MDAT_COMMS_READER=off \
		bash "$rigTool" --wait-for-input "$rigMember" --wait-default --wait-session-id "$rigScanSession" \
			--wait-source scan:work-duty --wait-source "wake:$rigMember" ) > "$rigScenarioDir/$1.out" 2> "$rigScenarioDir/$1.err"
}
## The arrival: the inbox item the work-duty report carries, and the marker the send operation writes.
rigScanDrop(){ printf -- '---\ntype: inquiry\nfrom: %s\n---\n\nRIG-SCAN-ARRIVAL\n' "$rigSender" \
	> "$rigScenarioDir/data/inboxes/$rigMember/incoming/inquiry-rig-scan.md" ; }
rigScanWait scan-first
rigScanWait scan-measured &
rigScanPid=$!
sleep 8
rigScanArrived="$( rigNow )"
rigScanDrop
rigWakeTest
while kill -0 "$rigScanPid" 2>/dev/null ; do
	[ $(( $( rigNow ) - rigScanArrived )) -lt 300 ] || { kill -TERM "$rigScanPid" 2>/dev/null ; break ; }
	sleep 1
done
wait "$rigScanPid" 2>/dev/null || :
rigScanLatency=$(( $( rigNow ) - rigScanArrived ))
printf '  measured: a message sent 8s into a scan-only wait, woken on in %ss\n' "$rigScanLatency"
rigAssert "the first call reads the scan"                        "$( rigFirstLine "$rigScenarioDir/scan-first.out" )" "WAIT-RESULT: RECEIVED"
rigAssert "a message wakes a scan-only watcher within 10s, not at the scan's 300s TTL" "$( rigAtMost "$rigScanLatency" 10 )" "at-most-10"
rigAssert "and the report it wakes on carries the item"          "$( rigHolds "$rigScenarioDir/scan-measured.out" 'RIG-SCAN-ARRIVAL' )" "yes"

echo
if [ "$rigFailCount" = "0" ] ; then
	printf 'OK: %s assertion(s); wake latency measured: inbox at 8s %ss, inbox at 40s %ss, board %ss, send %ss, scan %ss\n' \
		"$rigPassCount" "$( rigFieldN "$rigEarly" 1 )" "$( rigFieldN "$rigLate" 1 )" "$( rigFieldN "$rigBoard" 1 )" "$( rigFieldN "$rigSend" 1 )" "$rigScanLatency"
	exit 0
fi
printf '⛔ WAIT WAKE LATENCY CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
exit 1
