#!/usr/bin/env bash
## Behavioural check on the retired marker of a question, `NEEDS REPLY`. Covers: a member's
## own send whose words carry the marker is not sent, and comes back as a CORRECTION, rc 6,
## in the form the plain-language floor's has, saying to ask the question with a tool that
## asks, alone in its own message; the marker in code style, in a quoted line or in small
## letters is no marker; a send of the tooling's own is not looked at; SendMessage,
## SubagentHandback, ReportFindings and PushNotification return that correction and post
## nothing, while text a handback only carries is not the sender's own; a tool that asks
## takes the marker off the front of its question and never posts it; and one whose words
## still carry it comes back with the marker alone to take out. Only the marker is looked
## for: a message that asks something in plain words, with no marker, is sent.
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists nothing of the host is
## beside it, and every scenario runs in its own workspace under this check's temp tree, in
## $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsNeedsReplyMarkerCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## THE RIG'S OWN PROCESS LIST: empty. The ps first on PATH answers the whole-host listing with
## nothing, so no process of this host is taken for a run of the rig, and hands every other
## call to the real ps.
RIG_PS_REAL="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
export RIG_PS_REAL
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*) exit 0 ;;
esac
exec "$RIG_PS_REAL" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] || rigRefuse "the rig's own ps is not first on PATH, so this check would read the host's process list"

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
rigFirstWord(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstWord = $1 ; } END { if ( NR == 0 ) { firstWord = "empty-output" ; } print firstWord ; }' "$1"
}
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}
rigCount(){ ## file, line start
	LC_ALL=C awk -v wantHead="$2" 'index( $0, wantHead ) == 1 { hitCount++ ; } END { print hitCount + 0 ; }' "$1" 2>/dev/null || printf 'no-such-file'
}
rigRecords(){
	local recordFile recordCount=0
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ ! -f "$recordFile" ] || recordCount=$(( recordCount + 1 ))
	done
	printf '%s' "$recordCount"
}

rigBotToken="rig-bot-token-TEAM"
rigOwnToken="rig-user-token-TESTER"
rigScenarioDir=""
rigScenarioName=""
rigStart(){ ## scenario directory name
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/IN" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=%s\n' "$rigBotToken" \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=%s\n' "$rigOwnToken" > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
## One served call of a tool, as the rig's member. A question nobody answers is re-waited
## without end by design, so the guard is the scenario's: a killed run is reported as such.
rigKilled=""
rigCall(){ ## guard seconds, tool, argument object
	local callPid callLeft
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD \
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID="rig-marker-$rigScenarioName" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	callPid=$!
	set +m
	callLeft="$1"
	while kill -0 "$callPid" 2>/dev/null && [ "$callLeft" -gt 0 ] ; do
		sleep 1
		callLeft=$(( callLeft - 1 ))
	done
	if kill -0 "$callPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$callPid" ; sleep 1 ; kill -KILL -- "-$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}
## One team operation in the scenario's workspace, as the rig's member in a session of its
## own; the text on stdin, out and err kept as op.out and op.err, its rc as rigOpRc.
rigOpRc=0
rigOp(){ ## text, operation and its arguments
	local opText="$1"
	shift
	rigOpRc=0
	( cd "$rigScenarioDir/ws" && printf '%s' "$opText" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD \
		MDAT_SPAWN_SESSION_ID="rig-marker-$rigScenarioName" MDAT_SPAWN_AGENT="$rigMember" \
		MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" bash "$rigTools" "$@" ) > "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err" || rigOpRc=$?
}
## What a held-back send of the operation must show: "<rc>:<posts>:<first word on stderr>:<marker lines>:<NEXT lines>".
rigOpHeld(){
	printf '%s:%s:%s:%s:%s' "$rigOpRc" "$( rigCalls chat.postMessage )" "$( LC_ALL=C grep -m1 -o '^CORRECTION:' "$rigScenarioDir/op.err" || printf none )" \
		"$( rigCount "$rigScenarioDir/op.err" '- needs-reply-marker: ' )" "$( rigCount "$rigScenarioDir/op.err" 'NEXT: ' )"
}
## What a held-back call of a posting tool must show: "<first word>:<posts>:<marker lines>:<names the tools that ask>".
rigToolHeld(){
	printf '%s:%s:%s:%s' "$( rigFirstWord "$rigScenarioDir/out" )" "$( rigCalls chat.postMessage )" "$( rigCount "$rigScenarioDir/out" '- needs-reply-marker: ' )" \
		"$( rigHolds "$rigScenarioDir/out" 'NEXT: ask the question with AskQuestion, ConfirmReadback, EscalateDecision or RequestPermission, alone in its own message, and send this message again without the marker and without the question' )"
}
rigMarked='The rig finished its run. Every check passed.

NEEDS REPLY: should the rig go on with the next band?'

echo "-- the member send: a message that carries the marker is not sent, and comes back as a correction --"
rigStart op-marked
rigOp "$rigMarked" --member-comms-slack-send-message "$rigMember" magic-team --from-stdin
rigAssert "rc 6, nothing posted, and on stderr one CORRECTION line, one line for the line that carries the marker, one NEXT line" \
	"$( rigOpHeld )" "6:0:CORRECTION::1:1"
rigAssert "the correction says the marker is retired and how a question is asked, and names the line" \
	"$( rigHolds "$rigScenarioDir/op.err" 'It carries the marker NEEDS REPLY, which is retired: a question to a person is asked with a tool that asks, alone in its own message' ):$( rigHolds "$rigScenarioDir/op.err" '- needs-reply-marker: NEEDS REPLY: should the rig go on with the next band?' ):$( rigHolds "$rigScenarioDir/op.err" 'NEXT: ask the question with a tool that asks, alone in its own message, and send this message again without the marker and without the question' )" \
	"yes:yes:yes"
rigAssert "it is worded as a correction, never as a refusal or a denial, and the send itself reports no error" \
	"$( rigHolds "$rigScenarioDir/op.err" 'This is a correction for the sender to make, never a refusal or a denial' ):$( rigCount "$rigScenarioDir/op.err" '⛔ ERROR: DistroAgentsTools' )" "yes:0"
rigStart op-marked-again
rigOp "$rigMarked" --member-comms-slack-send-message "$rigMember" magic-team --from-stdin
rigOp "$rigMarked" --member-comms-slack-send-message "$rigMember" magic-team --from-stdin
rigAssert "a second attempt with the same text is held back the same way: there is no way through on a later one" "$( rigOpHeld )" "6:0:CORRECTION::1:1"
rigStart op-clean
rigOp 'The rig finished its run. Every check passed.' --member-comms-slack-send-message "$rigMember" magic-team --from-stdin
rigAssert "accepted sibling: the report without the marker and the question is sent" "$rigOpRc:$( rigCalls chat.postMessage )" "0:1"
rigStart op-plain-question
rigOp 'The rig finished its run. Should it go on with the next band?' --member-comms-slack-send-message "$rigMember" magic-team --from-stdin
rigAssert "only the marker is looked for: a message that asks in plain words, with no marker, is sent" "$rigOpRc:$( rigCalls chat.postMessage )" "0:1"
rigStart op-code-span
rigOp 'The rule that asked for `NEEDS REPLY:` is retired.' --member-comms-slack-send-message "$rigMember" magic-team --from-stdin
rigAssert "the marker in code style is no marker: a message can still name it" "$rigOpRc:$( rigCalls chat.postMessage )" "0:1"
rigStart op-quoted
rigOp 'He wrote this.

> NEEDS REPLY: should the rig go on?' --member-comms-slack-send-message "$rigMember" magic-team --from-stdin
rigAssert "nor is the marker in a quoted line, which the sender did not write" "$rigOpRc:$( rigCalls chat.postMessage )" "0:1"
rigStart op-small-letters
rigOp 'This thread needs reply from nobody.' --member-comms-slack-send-message "$rigMember" magic-team --from-stdin
rigAssert "nor the same words in small letters" "$rigOpRc:$( rigCalls chat.postMessage )" "0:1"
rigStart op-tooling
rigOp "$rigMarked" --intern-op-comms-slack-send-message "$rigMember" magic-team --from-stdin
rigAssert "accepted sibling: a send of the tooling's own is not looked at" "$rigOpRc:$( rigCalls chat.postMessage )" "0:1"

echo "-- the posting tools: each returns the correction and posts nothing --"
rigStart tool-send
rigCall 60 SendMessage '{"to":"magic-team","message":"The rig finished its run.\n\nNEEDS REPLY: should the rig go on with the next band?"}'
rigAssert "SendMessage: CORRECTION, nothing posted, the line named, and the tools that ask named" "$rigKilled:$( rigToolHeld )" "no:CORRECTION::0:1:yes"
rigAssert "it says the marker is retired, as a correction for the sender to make" \
	"$( rigHolds "$rigScenarioDir/out" 'CORRECTION: the message was NOT sent and must be corrected and sent again. It carries the marker NEEDS REPLY, which is retired' ):$( rigHolds "$rigScenarioDir/out" 'never a refusal or a denial' ):$( rigHolds "$rigScenarioDir/out" 'plain-language limits' )" "yes:yes:no"
rigStart tool-send-clean
rigCall 60 SendMessage '{"to":"magic-team","message":"The rig finished its run."}'
rigAssert "accepted sibling: SendMessage without the marker is sent" "$rigKilled:$( rigFirstWord "$rigScenarioDir/out" ):$( rigCalls chat.postMessage )" "no:Sent:1"
rigStart tool-handback
rigCall 60 SubagentHandback '{"to":"magic-team","outcome":"The rig finished its run. NEEDS REPLY: should it go on?"}'
rigAssert "SubagentHandback, the marker in its outcome: the same" "$rigKilled:$( rigToolHeld )" "no:CORRECTION::0:1:yes"
rigStart tool-handback-carried
rigCall 60 SubagentHandback '{"to":"magic-team","task":"Retire the rule. NEEDS REPLY: is gone.","outcome":"The rule is retired."}'
rigAssert "accepted sibling: the task a handback carries is not its sender's own words, so it is sent" \
	"$rigKilled:$( rigFirstWord "$rigScenarioDir/out" ):$( rigCalls chat.postMessage )" "no:Sent:1"
rigStart tool-findings
rigCall 60 ReportFindings '{"to":"magic-team","subject":"The rig","findings":"Every check passed.\nNEEDS REPLY: should it go on?"}'
rigAssert "ReportFindings, the marker in its findings: the same" "$rigKilled:$( rigToolHeld )" "no:CORRECTION::0:1:yes"
rigStart tool-notification
rigCall 60 PushNotification '{"to":"magic-team","severity":"info","headline":"The rig finished","action_required":"NEEDS REPLY: should it go on?"}'
rigAssert "PushNotification, the marker in what it asks for: the same" "$rigKilled:$( rigToolHeld )" "no:CORRECTION::0:1:yes"

echo "-- a tool that asks never posts the marker --"
rigStart ask-leading
rigCall 30 AskQuestion '{"to":"magic-team","address_to":"human-owner","question":"NEEDS REPLY: should the rig go on?","wait":false}'
rigAssert "the marker in front of the question is taken off: the question is posted without it, and recorded" \
	"$rigKilled:$( rigFirstWord "$rigScenarioDir/out" ):$( rigCalls chat.postMessage ):$( rigHolds "$rigScenarioDir/post.1" 'should the rig go on?' ):$( rigHolds "$rigScenarioDir/post.1" 'NEEDS REPLY' ):$( rigRecords )" \
	"no:ASK-RESULT::1:yes:no:1"
rigAssert "nor does its record keep the marker" "$( rigHolds "$( ls "$rigScenarioDir/ws/.local/agents/pending"/*.md 2>/dev/null | head -1 )" 'NEEDS REPLY' )" "no"
rigStart ask-leading-dash
rigCall 30 AskQuestion '{"to":"magic-team","address_to":"human-owner","question":"NEEDS REPLY - should the rig go on?","wait":false}'
rigAssert "the same with a dash after it" \
	"$rigKilled:$( rigCalls chat.postMessage ):$( rigHolds "$rigScenarioDir/post.1" 'should the rig go on?' ):$( rigHolds "$rigScenarioDir/post.1" 'NEEDS REPLY' )" "no:1:yes:no"
rigStart ask-inside
rigCall 30 AskQuestion '{"to":"magic-team","address_to":"human-owner","question":"The rig finished its run. NEEDS REPLY: should it go on?","wait":false}'
rigAssert "the marker inside its words: nothing is posted or recorded, and the correction says to take the marker out and ask again" \
	"$rigKilled:$( rigFirstWord "$rigScenarioDir/out" ):$( rigCalls chat.postMessage ):$( rigRecords ):$( rigCount "$rigScenarioDir/out" '- needs-reply-marker: ' ):$( rigHolds "$rigScenarioDir/out" 'NEXT: take the marker out and ask again: a question asked with this tool already waits for its answer' ):$( rigHolds "$rigScenarioDir/out" 'send this message again' )" \
	"no:CORRECTION::0:0:1:yes:no"
rigStart ask-clean
rigCall 30 AskQuestion '{"to":"magic-team","address_to":"human-owner","question":"Should the rig go on?","wait":false}'
rigAssert "accepted sibling: a question with no marker is posted as before" \
	"$rigKilled:$( rigFirstWord "$rigScenarioDir/out" ):$( rigCalls chat.postMessage ):$( rigRecords )" "no:ASK-RESULT::1:1"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ NEEDS REPLY MARKER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'NEEDS_REPLY_MARKER: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
