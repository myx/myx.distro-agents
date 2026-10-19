#!/usr/bin/env bash
## Behavioural check on what the wait of a session returns on, run through --intern-tool, the
## path the myx.distro MCP uses. A wait of a session returns on any update that is of interest
## to that session, not only on the one thing the call was started for. Covers: the wait inside
## a call that asks (here RequestPermission) is the session's stored wait whole, so an answer
## standing on another open ask of the session, or arriving there while the call waits, is
## taken -- read with the identity its record names, applied, confirmed once in its own
## thread -- and given to the asker with the call saying which ask it answers, that its own
## ask is still open, and the exact call that goes on waiting for it; that waiting again
## takes the call's own answer; the three shapes of such an answer (one option clicked,
## several with the send mark, a typed reply that names no option and comes back with its
## words); that an answer is taken once, whatever waits or collects after it; that the Wait
## tool returns the same answers for a question posted with wait=false and for an ask of
## another kind whose call was cut short; and that a message in a conversation the session
## already waits on ends an asking call the same way.
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists the rig's own runs only
## is beside it, and every scenario runs in its own workspace under this check's temp tree, in
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessAskSessionWaitCheck.XXXXXX" )" || exit 1
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
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID="rig-anyupdate-$rigScenarioName" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 MDAT_WAIT_SETTLE_SECONDS=0 MDAT_WAIT_REMIND=off \
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
## A question to the human-owner posted with wait=false: the scenario's first post, 000101.
rigAskNoWait(){ ## select (one|many)
	rigCall 30 AskQuestion "{\"to\":\"human-owner\",\"question\":\"Which check first?\",\"select\":\"$1\",$rigOptions,\"wait\":false}"
	rigQuestion="$( rigRecordOf question )"
}
## A write the gate refuses, and the permission asked for it of the human-owner: the scenario's
## second post, 000201, whose thread holds the prompt alone until the scenario has it answered.
rigRefused(){
	rigCall 30 Write "{\"path\":\"/dev/null/rig-anyupdate/x\",\"content\":\"x\"}"
	rigRefusalId="$( rigRefusal "$rigScenarioDir/out" )"
	[ -n "$rigRefusalId" ] || rigRefuse "the rig produced no refusal to ask permission for"
	rigThread 000201 "" ""
}
rigAskPermission(){ ## guard seconds
	rigCall "$1" RequestPermission "{\"to\":\"human-owner\",\"question\":\"May the rig write this file?\",\"refusal_id\":\"$rigRefusalId\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}"
	rigPermission="$( rigRecordOf permission )"
}
## What a call that returned on another ask's answer must say of its own ask: the first line,
## that its own ask is open, and the exact call that goes on waiting for it as its last line.
rigReturnedOnOther(){
	printf '%s:%s:%s:%s' "$rigKilled" "$( rigFirstLine "$rigScenarioDir/out" )" "$( rigField "$rigPermission" status )" "$( [ "$( rigLastLine "$rigScenarioDir/out" )" = "RequestPermission pending_id=$rigPermission" ] && printf 'names-the-call' || rigLastLine "$rigScenarioDir/out" )"
}
## The answer a call gave of the question, and which ask it said it is of: "<names the
## question's record>:<its own first words>:<verdict>:<by>".
rigGaveQuestion(){
	printf '%s:%s:%s:%s' "$( rigHolds "$rigScenarioDir/out" "# --- pending reply $rigQuestion, as the asking call would take it ---" )" \
		"$( LC_ALL=C grep -c '^ASKED: question, .*: Which check first?$' "$rigScenarioDir/out" )" "$( rigLineOf 'VERDICT: ' )" "$( rigLineOf 'ANSWERED-BY: ' )"
}
## The permission's own answer, taken by waiting again on it: "<killed>:<first line>:<verdict>:<grant>".
rigTookPermission(){ ## reaction the owner clicks on the prompt
	rigThread 000201 "$( rigReactions "$rigBoth" "$1" )" ""
	rigCall 45 RequestPermission "{\"pending_id\":\"$rigPermission\"}"
	printf '%s:%s:%s:%s' "$rigKilled" "$( rigFirstLine "$rigScenarioDir/out" )" "$( rigLineOf 'VERDICT: ' )" "$( rigLineOf 'GRANT: ' )"
}

echo "-- a question posted with wait=false and answered, then a permission asked in the same session --"
## The live case: two questions of a session stood answered in the bot's conversation with the
## owner while that session sat in one permission call after another, each waiting on its own
## ask alone. Nothing read them, and nothing confirmed them.
rigStart standing-one
rigAskNoWait one
rigAssert "control: the question is posted with no wait, and its ask is open" "$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigField "$rigQuestion" status )" "no:ASK-RESULT: POSTED:reply-pending"
rigThread 000101 "$( rigReactions "$rigBoth" two )" ""
rigRefused
rigAskPermission 45
rigAssert "the permission call returns on the question's answer, its own ask open, and its last line the call that goes on waiting for it" \
	"$( rigReturnedOnOther )" "no:ASK-RESULT: ARRIVED-OTHER:reply-pending:names-the-call"
rigAssert "it gives that answer and says which ask it answers" "$( rigGaveQuestion )" "yes:1:VERDICT: beta:ANSWERED-BY: URIGOWNER"
rigAssert "the answer is applied, and confirmed once in the question's own thread by the bot" \
	"$( rigField "$rigQuestion" status ):$( rigField "$rigQuestion" verdict ):$( rigPostsIn 000101 'Read: `beta` by human-owner. It is recorded as the answer.' )" "reply-received:beta:1:$rigBotToken"
rigAssert "both threads are read with the identity the records name, the bot's, never the member's own" \
	"$( rigUsedAs conversations.replies "$rigBotToken" ):$( rigUsedAs conversations.replies "$rigOwnToken" )" "yes:no"
rigAssert "waiting again takes the permission's own answer" "$( rigTookPermission one )" "no:ASK-RESULT: RECEIVED:VERDICT: allow-once:GRANT: once $rigRefusalId"
rigAssert "and the question's answer is neither given nor confirmed a second time" \
	"$( rigHolds "$rigScenarioDir/out" "pending reply $rigQuestion," ):$( rigPostsIn 000101 'Read: ' )" "no:1:$rigBotToken"
rigCall 30 Wait '{"mode":"continue","timeout":3}'
rigOp --intern-op-pending-reply-collect --session-id "rig-anyupdate-$rigScenarioName"
rigAssert "taken once: a Wait and a collect after it bring nothing, and post nothing" \
	"$( rigFirstLine "$rigScenarioDir/out" | cut -c1-20 ):$( rigLastLine "$rigScenarioDir/op.out" ):$( rigCalls chat.postMessage )" "WAIT-RESULT: TIMEOUT:COLLECT: answered=0 unmatched=0 open=0 unreadable=0:4"

echo "-- the same with the answer arriving while the permission call waits --"
rigStart arriving-one
rigAskNoWait one
rigRefused
## The owner's click is put on the question only once the permission is asked and its call has waited a while.
( while [ "$( rigRecordOf permission )" = "no-permission-record" ] ; do sleep 1 ; done
	sleep 4
	rigThread 000101 "$( rigReactions "$rigBoth" three )" ""
	: > "$rigScenarioDir/clicked-while-waiting" ) &
rigWriter=$!
rigAskPermission 60
wait "$rigWriter" 2>/dev/null || :
rigAssert "control: the click came after the permission was asked, while its call waited" "$( [ -f "$rigScenarioDir/clicked-while-waiting" ] && printf yes || printf no )" yes
rigAssert "the waiting call returns on it, its own ask open, with the call that goes on waiting" \
	"$( rigReturnedOnOther )" "no:ASK-RESULT: ARRIVED-OTHER:reply-pending:names-the-call"
rigAssert "it gives that answer, says which ask it answers, and the answer is confirmed once in the question's thread" \
	"$( rigGaveQuestion ):$( rigPostsIn 000101 'Read: `gamma` by human-owner. It is recorded as the answer.' )" "yes:1:VERDICT: gamma:ANSWERED-BY: URIGOWNER:1:$rigBotToken"
rigAssert "waiting again takes the permission's own answer" "$( rigTookPermission repeat )" "no:ASK-RESULT: RECEIVED:VERDICT: allow-session:GRANT: session $rigRefusalId"

echo "-- several options: the numbers clicked are an answer only with the send mark --"
rigStart standing-many
rigAskNoWait many
rigThread 000101 "$( rigReactions "$rigBoth" one three )" ""
rigRefused
rigAskPermission 8
rigAssert "control: numbers with no send mark are no answer yet, so the permission call goes on waiting and nothing is taken" \
	"$rigKilled:$( rigField "$rigQuestion" status ):$( rigPostsIn 000101 'Read: ' )" "yes:reply-pending:0:"
rigThread 000101 "$( rigReactions "$rigBoth" one three ok )" ""
rigCall 45 RequestPermission "{\"pending_id\":\"$rigPermission\"}"
rigAssert "with the send mark the waiting call returns on them" "$( rigReturnedOnOther )" "no:ASK-RESULT: ARRIVED-OTHER:reply-pending:names-the-call"
rigAssert "it gives every option chosen, and they are confirmed once in the question's thread" \
	"$( rigGaveQuestion ):$( rigField "$rigQuestion" verdict ):$( rigPostsIn 000101 'Read: `alpha gamma` by human-owner. It is recorded as the answer.' )" "yes:1:VERDICT: alpha gamma:ANSWERED-BY: URIGOWNER:alpha gamma:1:$rigBotToken"
rigAssert "waiting again takes the permission's own answer" "$( rigTookPermission one )" "no:ASK-RESULT: RECEIVED:VERDICT: allow-once:GRANT: once $rigRefusalId"

echo "-- a typed reply that names no option comes back to the asker, with its words --"
rigStart standing-typed
rigAskNoWait one
rigThread 000101 "" "$( rigMessage 000101 000150 URIGOWNER 'It is likely some fixes applied' )"
rigRefused
rigAskPermission 45
rigAssert "the permission call returns on it, its own ask open, with the call that goes on waiting" \
	"$( rigReturnedOnOther )" "no:ASK-RESULT: ARRIVED-OTHER:reply-pending:names-the-call"
rigAssert "it comes back as returned, said of the question, with what the owner wrote" \
	"$( rigGaveQuestion ):$( rigHolds "$rigScenarioDir/out" '1700000001.000150 | URIGOWNER | It is likely some fixes applied' )" "yes:1:VERDICT: RETURNED:no-ANSWERED-BY: line:yes"
rigAssert "the question stays open, and nothing is posted for it" "$( rigField "$rigQuestion" status ):$( rigCalls chat.postMessage )" "reply-pending:2"
rigCall 8 RequestPermission "{\"pending_id\":\"$rigPermission\"}"
rigAssert "the same reply is not returned a second time: waiting again goes on waiting for the permission" "$rigKilled:$( rigField "$rigPermission" status )" "yes:reply-pending"
rigAssert "and then takes the permission's own answer" "$( rigTookPermission one )" "no:ASK-RESULT: RECEIVED:VERDICT: allow-once:GRANT: once $rigRefusalId"

echo "-- the Wait tool returns the same answers --"
rigStart wait-question
rigAskNoWait one
rigThread 000101 "$( rigReactions "$rigBoth" two )" ""
rigCall 45 Wait '{"mode":"continue","timeout":10}'
rigAssert "an answer standing on a question posted with wait=false: the Wait returns it, says which ask it answers, and it is confirmed once" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigGaveQuestion ):$( rigPostsIn 000101 'Read: `beta` by human-owner. It is recorded as the answer.' )" \
	"no:WAIT-RESULT: RECEIVED:yes:1:VERDICT: beta:ANSWERED-BY: URIGOWNER:1:$rigBotToken"
rigStart wait-decision
rigThread 000101 "" ""
rigCall 6 EscalateDecision "{\"to\":\"human-owner\",\"question\":\"Which check first?\",$rigOptions}"
rigDecision="$( rigRecordOf decision )"
rigAssert "control: a decision nobody answered, its call cut short, stays open" "$rigKilled:$( rigField "$rigDecision" status )" "yes:reply-pending"
rigThread 000101 "$( rigReactions "$rigBoth" two )" ""
rigCall 45 Wait '{"mode":"continue","timeout":10}'
rigAssert "an answer standing on an ask of another kind whose call was cut short: the Wait returns it, applied and confirmed once" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigLineOf 'VERDICT: ' ):$( rigField "$rigDecision" status ):$( rigPostsIn 000101 'Read: `beta` by human-owner. It is recorded as the decision.' )" \
	"no:WAIT-RESULT: RECEIVED:VERDICT: beta:reply-received:1:$rigBotToken"
rigStart wait-text
rigCall 30 AskQuestion '{"to":"human-owner","question":"What should the rig do next?","wait":false}'
rigQuestion="$( rigRecordOf question )"
rigThread 000101 "" "$( rigMessage 000101 000150 URIGOWNER 'Go on with it.' )"
rigCall 45 Wait '{"mode":"continue","timeout":10}'
rigAssert "a free-text answer standing on a question with no options: the Wait returns it and the question is closed" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigHolds "$rigScenarioDir/out" 'Go on with it.' ):$( rigField "$rigQuestion" status )" "no:WAIT-RESULT: RECEIVED:yes:reply-received"
rigCall 30 Wait '{"mode":"continue","timeout":3}'
rigAssert "taken once: the next Wait does not return that answer again" "$( rigFirstLine "$rigScenarioDir/out" | cut -c1-20 ):$( rigHolds "$rigScenarioDir/out" 'Go on with it.' )" "WAIT-RESULT: TIMEOUT:no"

echo "-- a message in a conversation the session already waits on ends an asking call too --"
rigStart session-thread
rigSessionThread="CRIG00001:1700000000.000001"
## The conversation as conversations.replies returns it: its first message, then the later ones.
rigConversation(){ ## later messages (may be empty)
	printf '{"ok":true,"messages":[{"ts":"1700000000.000001","user":"URIGLEAD1","text":"the session thread"}%s],"has_more":false}\n' "$1" \
		> "$rigScenarioDir/replies.1700000000.000001.json.next" && mv -f "$rigScenarioDir/replies.1700000000.000001.json.next" "$rigScenarioDir/replies.1700000000.000001.json"
}
rigConversation ""
rigCall 30 Wait "{\"sources\":\"slack:$rigSessionThread:conversation\",\"since_utime\":\"1700000000.000001\",\"timeout\":2}"
rigAssert "control: the session waits on that conversation, and it is quiet" "$( rigFirstLine "$rigScenarioDir/out" | cut -c1-20 )" "WAIT-RESULT: TIMEOUT"
rigThread 000101 "" ""
( while [ "$( rigRecordOf decision )" = "no-decision-record" ] ; do sleep 1 ; done
	sleep 4
	rigConversation ',{"ts":"1700000000.000200","user":"URIGLEAD1","text":"RIG-NEXT-JOB for the tester","thread_ts":"1700000000.000001"}'
	: > "$rigScenarioDir/posted-while-waiting" ) &
rigWriter=$!
rigCall 60 EscalateDecision "{\"to\":\"human-owner\",\"question\":\"Which check first?\",$rigOptions}"
wait "$rigWriter" 2>/dev/null || :
rigDecision="$( rigRecordOf decision )"
rigAssert "control: the message came after the decision was asked, while its call waited" "$( [ -f "$rigScenarioDir/posted-while-waiting" ] && printf yes || printf no )" yes
rigAssert "the waiting call returns on it, naming the conversation it arrived in, with what was written" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigHolds "$rigScenarioDir/out" "# arrived on: slack:$rigSessionThread:conversation" ):$( rigHolds "$rigScenarioDir/out" 'RIG-NEXT-JOB for the tester' )" \
	"no:ASK-RESULT: ARRIVED-OTHER:yes:yes"
rigAssert "the decision stays open, and the last line is the call that goes on waiting for it" \
	"$( rigField "$rigDecision" status ):$( rigLastLine "$rigScenarioDir/out" )" "reply-pending:EscalateDecision pending_id=$rigDecision"
rigConversation ',{"ts":"1700000000.000200","user":"URIGLEAD1","text":"RIG-NEXT-JOB for the tester","thread_ts":"1700000000.000001"},{"ts":"1700000000.000300","user":"URIGBOT01","text":"*_magic-coordinator_* @magic-coordinator → *_magic-tester_* @magic-tester.\nDISMISSED","thread_ts":"1700000000.000001","metadata":{"event_type":"magic_sender","event_payload":{"sender":"magic-coordinator"}}}'
rigCall 45 EscalateDecision "{\"pending_id\":\"$rigDecision\"}"
rigAssert "a dismissal there ends the call that waits again as a dismissal, the decision still open" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigField "$rigDecision" status )" "no:ASK-RESULT: DISMISSED:reply-pending"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK SESSION WAIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_SESSION_WAIT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
