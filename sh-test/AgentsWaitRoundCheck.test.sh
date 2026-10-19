#!/usr/bin/env bash
## Behavioural check on how long a wait of a session runs when nothing arrives, and on what it
## then returns. A session whose wait comes back later than the prompt cache of its CLI
## service lives pays for its whole history again, uncached, at every wake; so the round of
## such a wait is a number each CLI service has (AgentsTools.CliService.include), a little
## under its cache's lifetime where that is known and the safe short one where it is not,
## which one setting of the workspace overrides (WAIT_ROUND_SECONDS). Covers: that number a
## service, the safe one, the override, and how a session's service is known; the wait
## operation holding a session's wait to it, and leaving a wait of no session alone; the Wait
## tool's empty round, one line with the call that goes on; a call that asks coming back the
## same way, its ask still open, and going on with that call; and an arrival ending the round
## at once, as before. A dismissal ending a wait is AgentsHarnessDismissedEndCheck's and
## AgentsHarnessAskSessionWaitCheck's.
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists the rig's own runs only
## is beside it, and every scenario runs in its own workspace under this check's temp tree, in
## $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsWaitRoundCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## THE RIG'S OWN PROCESS LIST: the ps first on PATH answers the whole-host listing from the
## rig's own list, and hands every other call to the real ps, so no process of this host is
## taken for a run of the rig's.
RIG_PS_REAL="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
RIG_PS_LIST="$rigTmp/ps.list"
export RIG_PS_REAL RIG_PS_LIST
: > "$RIG_PS_LIST"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "$RIG_PS_LIST" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "$RIG_PS_LIST" 2> /dev/null ;;
		esac
		exit 0
	;;
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
rigFirstLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}
rigLastLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NF { lastLine = $0 ; } END { print lastLine ; }' "$1"
}
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}
## Whether one method went out under one token at all.
rigUsedAs(){ ## method, token
	LC_ALL=C awk -v wantCall="$1 $2" 'index( $0 " ", wantCall " " ) == 1 { hit = 1 ; } END { print ( hit ? "yes" : "no" ) ; }' "$rigScenarioDir/calls" 2>/dev/null || printf 'no-such-log'
}
## The posts of the scenario that went into one thread and hold one text: how many, and under which tokens.
rigPostsIn(){ ## thread ts suffix, text
	local postFile postCount=0 postTokens=""
	for postFile in "$rigScenarioDir"/post.[0-9]* ; do
		[ -f "$postFile" ] || continue
		LC_ALL=C grep -q -F "\"thread_ts\":\"1700000001.$1\"" "$postFile" && LC_ALL=C grep -q -F -- "$2" "$postFile" || continue
		postCount=$(( postCount + 1 ))
		postTokens="$postTokens$( cat "$rigScenarioDir/posted-as.${postFile##*.}" 2>/dev/null ) "
	done
	printf '%s:%s' "$postCount" "${postTokens% }"
}
## The one line of the result that starts with a prefix, or a value saying there is none.
rigLineOf(){ ## prefix
	LC_ALL=C awk -v wantPrefix="$1" 'index( $0, wantPrefix ) == 1 { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-" wantPrefix "line" ; } }' "$rigScenarioDir/out"
}
## The record of the scenario's one ask of a kind, and one field of a record.
rigRecordOf(){ ## kind
	local recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] && LC_ALL=C grep -q -x -F "kind: $1" "$recordFile" || continue
		recordFile="${recordFile##*/}"
		printf '%s' "${recordFile%.md}"
		return 0
	done
	printf 'no-%s-record' "$1"
}
rigField(){ ## pending id, field
	LC_ALL=C awk -v key="$2" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$rigScenarioDir/ws/.local/agents/pending/$1.md" 2>/dev/null || printf 'no-record'
}
rigRefusal(){ ## output file -> the refusal id it printed
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$1" | head -1
}

rigBotToken="rig-bot-token-TEAM"
rigOwnToken="rig-user-token-TESTER"

## One scenario's workspace. The asking member has an account of its own, as the member of the
## live case had: its asks to the human-owner are the team bot's posts all the same.
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

## One thread of its own as conversations.replies returns it: its first message, the n-th post
## of the scenario (1700000001.000n01), with what the scenario puts on it, then the later messages.
rigThread(){ ## first message ts suffix, its extra fields (may be empty), later messages (may be empty)
	printf '{"ok":true,"messages":[{"ts":"1700000001.%s","user":"URIGSELF1","text":"first"%s}%s],"has_more":false}\n' \
		"$1" "$2" "$3" > "$rigScenarioDir/replies.1700000001.$1.json.next" && mv -f "$rigScenarioDir/replies.1700000001.$1.json.next" "$rigScenarioDir/replies.1700000001.$1.json"
}
rigBoth='"URIGSELF1","URIGOWNER"'
rigReactions(){ ## users (a JSON list body), reaction names...
	local reactUsers="$1" reactOut="" reactName
	shift
	for reactName in "$@" ; do
		reactOut="$reactOut${reactOut:+,}{\"name\":\"$reactName\",\"count\":2,\"users\":[$reactUsers]}"
	done
	printf ',"reactions":[%s]' "$reactOut"
}
rigMessage(){ ## thread ts suffix, ts suffix, user, text
	printf ',{"ts":"1700000001.%s","user":"%s","text":"%s","thread_ts":"1700000001.%s"}' "$2" "$3" "$4" "$1"
}

## One served call of a tool, as the asking member in the scenario's one session. An ask nobody
## answers is re-waited without end by design, so the guard is the scenario's: a killed run is
## reported as such, never as a result. The rig's posts are of 2023, so every reminder of an
## ask would be due at once: the waits here send none, and each post counted is the call's own.
rigKilled=""
rigCall(){ ## guard seconds, tool, argument object
	local callPid callLeft="$1"
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD \
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID="rig-waitround-$rigScenarioName" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 MDAT_WAIT_SETTLE_SECONDS=0 MDAT_WAIT_REMIND=off \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	callPid=$!
	set +m
	while kill -0 "$callPid" 2>/dev/null && [ "$callLeft" -gt 0 ] ; do sleep 1 ; callLeft=$(( callLeft - 1 )) ; done
	if kill -0 "$callPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$callPid" ; sleep 1 ; kill -KILL -- "-$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}
## One team operation in the scenario's workspace, as no session of its own.
rigOp(){ ## operation and its arguments
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" bash "$rigTools" "$@" ) > "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err"
}

rigOptions='"options":"alpha -- the unit checks\nbeta -- the lint\ngamma -- the smoke run"'
rigInclude="$rigHere/harness/AgentsTools.CliService.include"
[ -f "$rigInclude" ] || rigRefuse "the include that holds each CLI service's round is missing from the package: $rigInclude"
## The session of a scenario, and the service its launcher is said to have started it on (none: no launch marker).
rigSessionOf(){ printf 'rig-waitround-%s' "$rigScenarioName" ; }
rigLaunchedOn(){ ## cli service
	mkdir -p "$rigScenarioDir/ws/.local/agents/sessions/$( rigSessionOf )"
	printf '%s\n' "$1" > "$rigScenarioDir/ws/.local/agents/sessions/$( rigSessionOf )/launch"
}
## The workspace's own setting of the round.
rigRoundSet(){ ## value
	printf 'WAIT_ROUND_SECONDS=%s\n' "$1" >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
}
## One function of the include, in the scenario's workspace, with nothing of a native client in its environment.
rigService(){ ## function, its arguments
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT ${RIG_CLAUDE_SESSION:+CLAUDE_CODE_SESSION_ID="$RIG_CLAUDE_SESSION"} MMDAPP="$rigScenarioDir/ws" \
		bash -c '. "$1" ; shift ; "$@"' rig "$rigInclude" "$@" 2> /dev/null )
}
RIG_CLAUDE_SESSION=""
## The bound a wait of the operation ran under, as its own result says it: "<n>s bound", or "no bound".
rigBound(){
	LC_ALL=C sed -n 's/^# waited: [0-9]*s of \(.*bound\), .*$/\1/p' "$rigScenarioDir/op.out" | head -1
}
## A file that holds something already, so a wait from a floor returns on it at once and says its bound.
rigDrop(){
	printf 'RIG-PRESENT\n' > "$rigScenarioDir/drop.txt"
}

echo "-- the round of each CLI service, the safe one, and the workspace's one override --"
rigStart table
rigAssert "the vendor claude CLI, whose cache is known to live about an hour here: three quarters of an hour" "$( rigService AgentsToolsCliServiceWaitRound claude-native )" 2700
rigAssert "a service whose cache lifetime is not known takes the safe round, under a five-minute cache" \
	"$( rigService AgentsToolsCliServiceWaitRound scaleway ):$( rigService AgentsToolsCliServiceWaitRound grok-native ):$( rigService AgentsToolsCliServiceWaitRound claude ):$( rigService AgentsToolsCliServiceWaitRound copilot )" "270:270:270:270"
rigAssert "and so does a session whose service is not known at all" "$( rigService AgentsToolsCliServiceWaitRound '' )" 270
rigRoundSet 7
rigAssert "the workspace's setting overrides it, whatever the service" \
	"$( rigService AgentsToolsCliServiceWaitRound claude-native ):$( rigService AgentsToolsCliServiceWaitRound scaleway ):$( rigService AgentsToolsCliServiceWaitRound '' )" "7:7:7"
rigStart table-bad
rigRoundSet 0
rigAssert "a setting of zero is no round: each service keeps its own" "$( rigService AgentsToolsCliServiceWaitRound claude-native ):$( rigService AgentsToolsCliServiceWaitRound '' )" "2700:270"
rigStart table-words
rigRoundSet 'an hour'
rigAssert "a setting that is no whole number is no round either" "$( rigService AgentsToolsCliServiceWaitRound claude-native ):$( rigService AgentsToolsCliServiceWaitRound '' )" "2700:270"

echo "-- which service a session runs on --"
rigStart service
rigAssert "a session with no launch marker: not known" "[$( rigService AgentsToolsCliServiceOfSession "$( rigSessionOf )" )]" "[]"
RIG_CLAUDE_SESSION="$( rigSessionOf )"
rigAssert "unless it is the vendor claude CLI's own session, which names itself" "[$( rigService AgentsToolsCliServiceOfSession "$( rigSessionOf )" )]" "[claude-native]"
rigAssert "and only that very session" "[$( rigService AgentsToolsCliServiceOfSession another-session )]" "[]"
RIG_CLAUDE_SESSION=""
rigLaunchedOn scaleway
rigAssert "a session its launcher started: the service the launch marker names" "[$( rigService AgentsToolsCliServiceOfSession "$( rigSessionOf )" )]" "[scaleway]"
rigLaunchedOn 'not a service; rm -rf'
rigAssert "a marker that holds no service name names none" "[$( rigService AgentsToolsCliServiceOfSession "$( rigSessionOf )" )]" "[]"

echo "-- the wait operation holds a session's wait to the round of its service --"
rigStart op-claude
rigLaunchedOn claude-native
rigDrop
rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$( rigSessionOf )" --wait-source "file:$rigScenarioDir/drop.txt" --wait-since-utime 1 --wait-timeout 14400
rigAssert "a session on the vendor claude CLI, asked to wait four hours: its bound is that service's round" "$( rigFirstLine "$rigScenarioDir/op.out" ):$( rigBound )" "WAIT-RESULT: RECEIVED:2700s bound"
rigStart op-unknown
rigDrop
rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$( rigSessionOf )" --wait-source "file:$rigScenarioDir/drop.txt" --wait-since-utime 1 --wait-timeout 14400
rigAssert "a session whose service is not known: the safe round" "$( rigFirstLine "$rigScenarioDir/op.out" ):$( rigBound )" "WAIT-RESULT: RECEIVED:270s bound"
rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$( rigSessionOf )" --wait-source "file:$rigScenarioDir/drop.txt" --wait-since-utime 1
rigAssert "with no bound named, the round is its bound" "$( rigBound )" "270s bound"
rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$( rigSessionOf )" --wait-source "file:$rigScenarioDir/drop.txt" --wait-since-utime 1 --wait-timeout 30
rigAssert "a shorter bound the call names stays" "$( rigBound )" "30s bound"
rigOp --member-wait-for-input "$rigMember" --wait-source "file:$rigScenarioDir/drop.txt" --wait-since-utime 1 --wait-timeout 14400
rigAssert "control: a wait of no session keeps the bound it was given" "$( rigBound )" "14400s bound"
rigOp --member-wait-for-input "$rigMember" --wait-source "file:$rigScenarioDir/drop.txt" --wait-since-utime 1
rigAssert "control: and none where it names none" "$( rigBound )" "no bound"
rigStart op-round
rigRoundSet 2
: > "$rigScenarioDir/quiet.txt"
## Under a guard of its own: a wait that did not come back would hold this check for the four hours it names.
( rigOp --member-wait-for-input "$rigMember" --wait-default --wait-session-id "$( rigSessionOf )" --wait-source "file:$rigScenarioDir/quiet.txt" --wait-timeout 14400 --wait-poll-interval 1 ) &
rigOpPid=$!
rigOpLeft=45
while kill -0 "$rigOpPid" 2>/dev/null && [ "$rigOpLeft" -gt 0 ] ; do sleep 1 ; rigOpLeft=$(( rigOpLeft - 1 )) ; done
if kill -0 "$rigOpPid" 2>/dev/null ; then
	pkill -TERM -P "$rigOpPid" 2>/dev/null ; kill -TERM "$rigOpPid" 2>/dev/null
	"$RIG_PS_REAL" -A -o pid=,command= | LC_ALL=C awk -v want="file:$rigScenarioDir/quiet.txt" 'index( $0, want ) { print $1 }' | while read -r rigOpLeft ; do kill -TERM "$rigOpLeft" 2>/dev/null ; done
	printf 'rig: the wait did not come back within 45s, and was stopped\n' > "$rigScenarioDir/op.out"
fi
wait "$rigOpPid" 2>/dev/null || :
rigAssert "with nothing arriving it comes back when the round is over, as a wait that found nothing" \
	"$( rigFirstLine "$rigScenarioDir/op.out" ):$( rigBound )" "WAIT-RESULT: TIMEOUT:2s bound"

echo "-- the Wait tool: an empty round is one line, with the call that goes on --"
rigStart tool-wait
rigRoundSet 2
: > "$rigScenarioDir/quiet.txt"
rigCall 45 Wait "{\"sources\":\"file:$rigScenarioDir/quiet.txt\",\"timeout\":14400}"
rigAssert "one line and no more: nothing arrived, and Wait mode=continue goes on" \
	"$rigKilled:$( LC_ALL=C awk 'END { print NR ; }' "$rigScenarioDir/out" ):$( LC_ALL=C sed -n 's/^WAIT-RESULT: TIMEOUT ([0-9][0-9]*s) NEXT: Wait mode=continue$/the-line/p' "$rigScenarioDir/out" )" "no:1:the-line"
rigCall 45 Wait '{"mode":"continue"}'
rigAssert "and going on is the same one line again" \
	"$rigKilled:$( LC_ALL=C awk 'END { print NR ; }' "$rigScenarioDir/out" ):$( LC_ALL=C sed -n 's/^WAIT-RESULT: TIMEOUT ([0-9][0-9]*s) NEXT: Wait mode=continue$/the-line/p' "$rigScenarioDir/out" )" "no:1:the-line"
printf 'RIG-ARRIVAL\n' > "$rigScenarioDir/quiet.txt"
rigCall 45 Wait '{"mode":"continue"}'
rigAssert "an arrival is returned as before, whatever the round" "$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigHolds "$rigScenarioDir/out" 'RIG-ARRIVAL' )" "no:WAIT-RESULT: RECEIVED:yes"

echo "-- a call that asks: with nothing arrived it comes back the same way, its ask open --"
rigStart ask-round
rigRoundSet 3
rigThread 000101 "" ""
rigCall 45 EscalateDecision "{\"to\":\"human-owner\",\"question\":\"Which check first?\",$rigOptions}"
rigDecision="$( rigRecordOf decision )"
rigAssert "one line and no more: nothing arrived, and the call that goes on waiting for this answer" \
	"$rigKilled:$( LC_ALL=C awk 'END { print NR ; }' "$rigScenarioDir/out" ):$( LC_ALL=C sed -n "s/^ASK-RESULT: TIMEOUT ([0-9][0-9]*s) NEXT: EscalateDecision pending_id=$rigDecision\$/the-line/p" "$rigScenarioDir/out" )" "no:1:the-line"
rigAssert "the ask stays open, and in the session's Wait set" \
	"$( rigField "$rigDecision" status ):$( LC_ALL=C grep -c -F "ask:$rigDecision " "$rigScenarioDir/ws/.local/agents/sessions/$( rigSessionOf )/wait/state" 2>/dev/null )" "reply-pending:1"
rigCall 45 EscalateDecision "{\"pending_id\":\"$rigDecision\"}"
rigAssert "going on with that call, still nothing: the same one line" \
	"$rigKilled:$( LC_ALL=C awk 'END { print NR ; }' "$rigScenarioDir/out" ):$( LC_ALL=C sed -n "s/^ASK-RESULT: TIMEOUT ([0-9][0-9]*s) NEXT: EscalateDecision pending_id=$rigDecision\$/the-line/p" "$rigScenarioDir/out" )" "no:1:the-line"
rigThread 000101 "$( rigReactions "$rigBoth" two )" ""
rigCall 45 EscalateDecision "{\"pending_id\":\"$rigDecision\"}"
rigAssert "and with the answer there, that call takes it" "$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigLineOf 'VERDICT: ' ):$( rigField "$rigDecision" status )" "no:ASK-RESULT: RECEIVED:VERDICT: beta:reply-received"

echo "-- an arrival ends the round at once --"
rigStart ask-arrival
rigRoundSet 600
rigThread 000101 "" ""
( while [ "$( rigRecordOf decision )" = "no-decision-record" ] ; do sleep 1 ; done
	sleep 4
	rigThread 000101 "$( rigReactions "$rigBoth" three )" ""
	: > "$rigScenarioDir/clicked-while-waiting" ) &
rigWriter=$!
rigArrivalStart="$( date +%s )"
rigCall 90 EscalateDecision "{\"to\":\"human-owner\",\"question\":\"Which check first?\",$rigOptions}"
wait "$rigWriter" 2>/dev/null || :
rigAssert "an answer that comes while the call waits ends it then, long before a round of ten minutes is over" \
	"$rigKilled:$( [ -f "$rigScenarioDir/clicked-while-waiting" ] && printf yes || printf no ):$( rigFirstLine "$rigScenarioDir/out" ):$( rigLineOf 'VERDICT: ' ):$( [ $(( $( date +%s ) - rigArrivalStart )) -lt 90 ] && printf 'in-time' || printf 'late' )" \
	"no:yes:ASK-RESULT: RECEIVED:VERDICT: gamma:in-time"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT ROUND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_ROUND: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
