#!/usr/bin/env bash
## Behavioural check on THE ASKING CALL THAT A TAGGED MESSAGE ENDS: a member's ask stands waiting on its
## session's stored wait, and a message tagging that member must end that call within seconds -- not at the
## next slow look of the tags, and not after the call's own long round.
##
## Why it exists. A coordinator work-duty asked the human-owner a question, and it sat inside that call for
## over an hour while member asks and board work queued behind it. The wait it stands on is the session's
## stored wait whole (AgentsHarnessAsk.include, the asking loop), whose floor carries tagged:<member>,
## mentions:<member> and wake:<member> (AgentsTools.MemberWaitSources.include). So a tagged message can end
## the call -- if the tags reach that wait in seconds. This check measures that, and measures nothing else.
##
## What it MEASURES, never assumes:
##   1. control: an asking call with nothing for the member goes on waiting, and its ask stays open;
##   2. a message tagging the member ends the asking call within seconds, and the call says what arrived;
##   3. the wake marker is what makes it seconds: with the marker kept away, the same message reaches the
##      call only at the tags' slow look, so the second assertion is red without the first mechanism.
## Offline by construction: the fake curl is first on PATH, opens no socket, and answers from the scenario
## folder. Every scenario is its own workspace under this check's temp tree, in $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigAsker="magic-coordinator"
rigSender="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigAsker/$rigAsker.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigAsker"

. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessAskTaggedWakeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'for rigHold in "$rigTmp"/*/hold ; do [ ! -f "$rigHold" ] || : > "${rigHold%hold}release" ; done ; sleep 1 ; chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" "$rigTmp/bin/curl.real" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl.real"
## The fake Slack this check needs: the ask's own post, reactions and thread reads come from the package's
## ask fixture; the reads the TAGS are made of -- the team channel's history, the conversation roster, the
## mention search -- are answered here from the scenario folder. Without that second half the tags cannot be
## read at all, and a wait that never read them would look like a wait nothing tagged.
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/usr/bin/env bash
for rigArg in "$@" ; do
	case "$rigArg" in
		*conversations.history*)
			rigCh="${rigArg##*channel=}" ; rigCh="${rigCh%%&*}"
			[ -z "${RIG_SCENARIO:-}" ] || [ ! -f "$RIG_SCENARIO/history.$rigCh.json" ] || { cat "$RIG_SCENARIO/history.$rigCh.json" ; exit 0 ; }
			printf '{"ok":true,"messages":[],"has_more":false}\n' ; exit 0
		;;
		*conversations.list*)
			[ -z "${RIG_SCENARIO:-}" ] || [ ! -f "$RIG_SCENARIO/dms.json" ] || { printf '{"ok":true,"channels":%s,"response_metadata":{"next_cursor":""}}\n' "$( cat "$RIG_SCENARIO/dms.json" )" ; exit 0 ; }
			printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n' ; exit 0
		;;
		*search.messages*)
			printf '{"ok":false,"error":"missing_scope","needed":"search:read"}\n' ; exit 0
		;;
	esac
done
exec "$(dirname "$0")/curl.real" "$@"
RIGCURL
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
rigFirstLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}
rigField(){ ## record file, field
	local fieldFile="$1"
	[ -f "$fieldFile" ] || { printf 'no-record' ; return 0 ; }
	LC_ALL=C awk -v key="$2" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$fieldFile" 2>/dev/null || printf 'no-record'
}

## One scenario: its own workspace, its own fake Slack folder, its own session. The asker's session runs a
## work-duty routine, because the tags are in the floor of a duty's wait -- and that is the run this check is
## about.
rigScenarioDir=""
rigScenarioName=""
rigSession=""
rigStart(){ ## scenario name
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	rigSession="rig-tag-$1"
	mkdir -p "$rigScenarioDir/bin" "$rigScenarioDir/slack" "$rigScenarioDir/data" \
		"$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents/spawned/rig" || exit 1
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-ASKER\n' > "$rigScenarioDir/ws/.local/.agents/$rigAsker.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-SENDER\n' > "$rigScenarioDir/ws/.local/.agents/$rigSender.agent.env"
	printf '%s=URIGASK1=rig-coord=rig coord=rig=rig.example\n%s=URIGSEND1=rig-tester=rig tester=rig=rig.example\n' \
		"$rigAsker" "$rigSender" > "$rigScenarioDir/ws/.local/.agents/slack-mention-ids.cache"
	## THE RUN'S OWN RECORD, at the path the wait's floor reads it by: spawned/<session>/<session>.spawn.md.
	## Its routine line is what puts the tags in a duty's floor (AgentsTools.MemberWaitSources.include:226).
	mkdir -p "$rigScenarioDir/ws/.local/agents/spawned/$rigSession"
	printf -- '---\nspawn-id: %s\nsession-id: %s\nstatus: spawn-started\nroutine: magic-coordinator.work-duty.routine.md\n---\n' \
		"$rigSession" "$rigSession" > "$rigScenarioDir/ws/.local/agents/spawned/$rigSession/$rigSession.spawn.md"
	: > "$rigScenarioDir/slack/history.CRIG00001.json"
	: > "$rigScenarioDir/slack/api.log"
	: > "$rigScenarioDir/curl.log"
	printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigScenarioDir/slack/replies.1700000001.000101.json"
	## The ask's own thread, quiet: the fake Slack answers every other thread from replies.json, and a missing
	## one there reads as a thread that could not be read at all -- a different failure from a quiet thread.
	printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigScenarioDir/slack/replies.json"
	printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n' > "$rigScenarioDir/slack/dms.json"
}
## The module the SEND operation calls to write the recipient's marker: the include's own touch, called here
## as the send calls it. That is the mechanism this check holds, and `AgentsWaitWakeLatencyCheck` holds it
## the same way.
rigMarkerTouch(){ ## [origin]
	[ "${1:-marker}" = "no-marker" ] && return 0
	( cd "$rigScenarioDir/ws" && MMDAPP="$rigScenarioDir/ws" bash -c '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.WakeMarker.include"
		AgentsToolsWakeTouch "$1" "$2"' rig-touch "$rigAsker" "$rigSender" ) || return 1
}
rigMarkerPath(){ printf '%s/.local/agents/wake/%s' "$rigScenarioDir/ws" "$rigAsker" ; }
## The tagged message, in the conversation the tags are read from: the team channel, as the fake Slack's
## history returns it.
rigTagLands(){ ## the text
	printf '{"ok":true,"messages":[{"ts":"%s.000200","user":"URIGSEND1","text":"%s","type":"message"}],"has_more":false}\n' \
		"$( date +%s )" "$1" > "$rigScenarioDir/slack/history.CRIG00001.json"
}
## The asking call, as the asker's own run makes it. Bounded by its own guard, killed as a process group, and
## reported as killed rather than as a result -- an ask nobody answers is re-waited without end by design.
rigKilled=""
rigAsk(){ ## guard seconds, arrival delay, arrival text, marker state
	local askPid askLeft="$1" askDelay="$2" askText="$3" askMarker="${4:-marker}" askStarted
	rigKilled="no"
	askStarted="$( date +%s )"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "{\"to\":\"human-owner\",\"question\":\"Rig: which check first?\",\"select\":\"one\",\"options\":\"alpha -- one\\nbeta -- two\"}" | \
		env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD -u MDAT_SESSION_ID \
		MMDAPP="$rigScenarioDir/ws" MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir/slack" \
		MDAT_SESSION_ID="$rigSession" MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_SPAWN_AGENT="$rigAsker" \
		MDAT_SKILLSET_ROOT="${MDAT_SKILLSET_ROOT:-}" MDAT_HARNESS_WAIT_TIMEOUT=30 MDAT_SLACK_THREAD_CACHE_SECONDS=0 \
		MDAT_WAIT_SETTLE_SECONDS=0 MDAT_WAIT_REMIND=off RIG_CURL_LOG="$rigScenarioDir/curl.log" \
		bash "$rigHarness" --intern-tool AskQuestion ) > "$rigScenarioDir/ask.out" 2> "$rigScenarioDir/ask.err" &
	askPid=$!
	set +m
	## The arrival, once the call is waiting: the message lands, then the marker is written, in that order --
	## the marker says "something for you is there", so what it announces must already be there.
	if [ "$askDelay" -ge 0 ] ; then
		sleep "$askDelay"
		[ -z "$askText" ] || { rigTagLands "$askText" ; rigArrivedAt="$( date +%s )" ; rigMarkerTouch "$askMarker" ; }
	else
		rigArrivedAt=""
	fi
	while kill -0 "$askPid" 2>/dev/null && [ $(( $( date +%s ) - askStarted )) -lt "$askLeft" ] ; do sleep 1 ; done
	if kill -0 "$askPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$askPid" ; sleep 1 ; kill -KILL -- "-$askPid" ; wait "$askPid" ; } 2>/dev/null
	fi
	wait "$askPid" 2>/dev/null || :
	rigLatency=""
	[ -z "${rigArrivedAt:-}" ] || rigLatency=$(( $( date +%s ) - rigArrivedAt ))
}
rigAskRecord(){ ## the asker's open question record, if any
	local recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] || continue
		printf '%s' "$recordFile" ; return 0
	done
	printf '%s/.local/agents/pending/no-record.md' "$rigScenarioDir/ws"
}

echo "-- 1. control: an asking call with nothing for the member goes on waiting --"
rigStart quiet
rigAsk 25 -1 "" marker
rigAssert "control: the call is still waiting when its guard ends, and nothing was returned" "$rigKilled:$( rigFirstLine "$rigScenarioDir/ask.out" )" "yes:empty-output"
rigAssert "control: its ask is open, so the same call has something to be ended on" "$( rigField "$( rigAskRecord )" status )" "reply-pending"

echo "-- 2. a message tagging the member ends the asking call within seconds --"
rigStart tagged
rigAsk 70 8 "RIG-TAGGED-WAKE <@URIGASK1> take this" marker
printf '  measured: the tag landed 8s into the call, which ended %ss later\n' "${rigLatency:-unmeasured}"
rigAssert "control: the message was posted after the call had begun waiting" "$( [ -n "${rigLatency:-}" ] && printf yes || printf no )" "yes"
rigAssert "the marker the send operation writes is there" "$( [ -f "$( rigMarkerPath )" ] && printf written || printf absent )" "written"
rigAssert "the tag ends the asking call within 10s of arriving" "$( [ -n "${rigLatency:-}" ] && [ "$rigLatency" -le 10 ] && printf "within-10s" || printf "slow:${rigLatency:-unmeasured}" )" "within-10s"
rigAssert "and the call returns on the arrival, its own ask still open" "$( rigFirstLine "$rigScenarioDir/ask.out" )" "ASK-RESULT: ARRIVED-OTHER"
rigAssert "saying what arrived, and the words of the message" "$( rigHolds "$rigScenarioDir/ask.out" 'RIG-TAGGED-WAKE' )" "yes"
rigAssert "the ask the call stands for is left open for its own answer" "$( rigField "$( rigAskRecord )" status )" "reply-pending"

echo "-- 3. the marker is what makes it seconds: without it the same message waits for the tags' slow look --"
rigStart nomarker
rigAsk 30 8 "RIG-TAGGED-SLOW <@URIGASK1> take this" no-marker
rigAssert "control: with the marker kept away, the message landed all the same" "$( rigHolds "$rigScenarioDir/slack/history.CRIG00001.json" 'RIG-TAGGED-SLOW' )" "yes"
rigAssert "control: and no marker was written" "$( [ -f "$( rigMarkerPath )" ] && printf written || printf absent )" "absent"
printf '  measured: without the marker the call ended %ss after the message landed\n' "${rigLatency:-unmeasured}"
rigAssert "the same message is not woken on within 2s without the marker, so assertion 2 is no free pass" \
	"$( [ -n "${rigLatency:-}" ] && [ "$rigLatency" -gt 2 ] && printf 'not-woken-quickly' || printf 'woken:%s' "${rigLatency:-unmeasured}" )" "not-woken-quickly"

echo
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK TAGGED WAKE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_TAGGED_WAKE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
