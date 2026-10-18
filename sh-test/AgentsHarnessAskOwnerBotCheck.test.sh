#!/usr/bin/env bash
## Behavioural check on who asks the human-owner, and as whom an answer is read and marked,
## run through --intern-tool, the path the myx.distro MCP uses. Covers: a question, a readback
## and a decision asked of the human-owner are the team bot's posts, in the bot's conversation
## with the owner, their answer emoji placed and their thread read under the bot's token, and
## their answer confirmed there once -- from a member with no Slack account of its own and
## from one with an account alike, whatever as_bot says; a question addressed to the owner in
## another conversation is asked there as before; a proposal stays the coordinator's own two
## posts, with no emoji of the tooling; the collector reads a plain question the bot asked as the bot, and its resolved
## marks go on under the bot's token at the first call; a permission whose addressee does not
## hold the refused call goes to the holder running in the session, and that member's answer
## reaches the asker; what the RequestPermission description says of both; and what the as_bot
## text of the three other tools that ask says of an ask to the human-owner.
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
for rigNeed in magic-tester magic-developer magic-coordinator ; do
	[ -r "${MDAT_SKILLSET_ROOT:-}/$rigNeed/$rigNeed.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigNeed, so the tool would have no identity to send under"
done

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessAskOwnerBotCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## THE RIG'S OWN PROCESS LIST. A spawn is found running by its spawn id in the host's process
## list (AgentsToolsRegistryRunningSpawns). A rig that read the real list would take any process
## of this host whose command line holds one of its ids for a live run of its own. So the ps
## first on PATH answers the whole-host listing from the rig's own list, one
## `<pid> <command line>` line a run, and hands every other call to the real ps.
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
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}
## How many calls of one method went out under one token: the fake curl keeps each call with its token.
rigCallsAs(){ ## method, token, optional rest of the line (a reaction's "<ts> <name>")
	LC_ALL=C awk -v wantCall="$1 $2${3:+ $3}" '$0 == wantCall { hitCount++ ; } END { print hitCount + 0 ; }' "$rigScenarioDir/calls" 2>/dev/null || printf 'no-such-log'
}
## Whether one method went out under one token at all, a reaction's post and name left aside.
rigUsedAs(){ ## method, token
	LC_ALL=C awk -v wantCall="$1 $2" 'index( $0 " ", wantCall " " ) == 1 { hit = 1 ; } END { print ( hit ? "yes" : "no" ) ; }' "$rigScenarioDir/calls" 2>/dev/null || printf 'no-such-log'
}
## The emoji placed on one post under one token: their names in the order asked for.
rigPlacedAs(){ ## token, ts suffix
	LC_ALL=C awk -v wantHead="reactions.add $1 1700000001.$2 " 'index( $0, wantHead ) == 1 { out = out ( out == "" ? "" : " " ) substr( $0, length( wantHead ) + 1 ) ; } END { print out ; }' "$rigScenarioDir/calls" 2>/dev/null
}
## The token one post of the scenario went out under: the fake curl keeps it beside the post.
rigPostedAs(){ ## post number
	cat "$rigScenarioDir/posted-as.$1" 2>/dev/null || printf 'no-such-post'
}
rigVerdictLine(){
	LC_ALL=C awk '/^VERDICT: / { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-verdict-line" ; } }' "$rigScenarioDir/out"
}
rigRecordFile(){
	local recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] && { printf '%s' "$recordFile" ; return 0 ; }
	done
	printf '%s' "$rigScenarioDir/no-record"
}
rigRecordField(){ ## field
	LC_ALL=C awk -v key="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$( rigRecordFile )" 2>/dev/null || printf 'no-record'
}
rigRecordId(){
	local recordId
	recordId="$( rigRecordFile )" ; recordId="${recordId##*/}"
	printf '%s' "${recordId%.md}"
}
rigRefusal(){ ## output file -> the refusal id it printed
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$1" | head -1
}

rigBotToken="rig-bot-token-TEAM"
rigOwnToken="rig-user-token-TESTER"
rigCoordinatorToken="rig-user-token-COORD"
rigDeveloperToken="rig-user-token-DEV"

## One scenario's workspace. The coordinator always has an account of its own, the one a
## member's send to the owner is relayed under when that member has none. With no-account the
## asking member has none of its own.
rigScenarioDir=""
rigScenarioName=""
rigStart(){ ## scenario directory name, optional no-account
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/IN" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=%s\n' "$rigBotToken" \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=%s\n' "$rigCoordinatorToken" > "$rigScenarioDir/ws/.local/.agents/magic-coordinator.agent.env"
	[ "${2:-}" = "no-account" ] || printf 'SLACK_USER_TOKEN=%s\n' "$rigOwnToken" > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}

## One thread as conversations.replies returns it: its first message with what the scenario
## puts on it, then the later messages.
rigThread(){ ## first message ts suffix, its extra fields (may be empty), later messages (may be empty)
	printf '{"ok":true,"messages":[{"ts":"1700000001.%s","user":"URIGSELF1","text":"first"%s}%s],"has_more":false}\n' \
		"$1" "$2" "$3" > "$rigScenarioDir/replies.json"
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
rigMessage(){ ## ts suffix, user, text
	printf ',{"ts":"1700000001.%s","user":"%s","text":"%s","thread_ts":"1700000001.000101"}' "$1" "$2" "$3"
}

## One served call of a tool, as the member rigAs in the session rigSession. A question nobody
## answers is re-waited without end by design, so the guard is the scenario's: a killed run is
## reported as such, never as a result. With from-read the guard counts from the first thread
## read this call makes.
rigKilled=""
rigAs="$rigMember"
rigSession=""
rigCall(){ ## guard seconds, tool, argument object, optional from-read
	local callPid callLeft callStartLeft=120 callReads
	rigKilled="no"
	callReads="$( rigCalls conversations.replies )"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD \
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID="${rigSession:-rig-askbot-$rigScenarioName}" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigAs" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	callPid=$!
	set +m
	callLeft="$1"
	while kill -0 "$callPid" 2>/dev/null && [ "$callLeft" -gt 0 ] ; do
		sleep 1
		if [ "${4:-}" = "from-read" ] && [ "$callStartLeft" -gt 0 ] && [ "$( rigCalls conversations.replies )" = "$callReads" ] ; then
			callStartLeft=$(( callStartLeft - 1 ))
			continue
		fi
		callLeft=$(( callLeft - 1 ))
	done
	if kill -0 "$callPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$callPid" ; sleep 1 ; kill -KILL -- "-$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}
## One team operation in the scenario's workspace, as no session of its own unless the caller
## names one in the environment; out and err kept as op.out and op.err.
rigOp(){ ## operation and its arguments
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		${RIG_OP_SESSION:+MDAT_SPAWN_SESSION_ID="$RIG_OP_SESSION"} ${RIG_OP_AGENT:+MDAT_SPAWN_AGENT="$RIG_OP_AGENT"} \
		TMPDIR="$rigTmp/tmp" MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" bash "$rigTools" "$@" ) > "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err"
}
RIG_OP_SESSION=""
RIG_OP_AGENT=""
## The calls made so far are set aside, so what follows is counted on its own.
rigCallsAside(){ ## name of the part set aside
	mv -f "$rigScenarioDir/calls" "$rigScenarioDir/calls.$1" 2>/dev/null || :
}

## What every scenario of a member with no account of its own must show of its question to the
## human-owner: "<post 1 under>:<posts under the coordinator>:<its channel>:<asked as>:<asked of>".
rigOwnerPost(){
	printf '%s:%s:%s:%s:%s' "$( rigPostedAs 1 )" "$( rigCallsAs chat.postMessage "$rigCoordinatorToken" )" \
		"$( rigHolds "$rigScenarioDir/post.1" '"channel":"URIGOWNER"' )" "$( rigRecordField ask-identity )" "$( rigRecordField address-to )"
}
## Whether its thread was read, and by whom: "<under the bot>:<under the coordinator>".
rigOwnerRead(){
	printf '%s:%s' "$( rigUsedAs conversations.replies "$rigBotToken" )" "$( rigUsedAs conversations.replies "$rigCoordinatorToken" )"
}
## The one confirmation of an answer, as the second post of the scenario: "<under>:<in the
## question's thread>:<holds the text given>:<posts in all>".
rigConfirmed(){ ## the text it must hold
	printf '%s:%s:%s:%s' "$( rigPostedAs 2 )" "$( rigHolds "$rigScenarioDir/post.2" '"thread_ts":"1700000001.000101"' )" "$( rigHolds "$rigScenarioDir/post.2" "$1" )" "$( rigCalls chat.postMessage )"
}
rigOptions='"options":"alpha -- the unit checks\nbeta -- the lint\ngamma -- the smoke run"'

echo "-- a question to the human-owner from a member with no account of its own: the team bot posts it --"
## The live fault: such a member's send to the owner is relayed under the coordinator's account,
## into the coordinator's conversation with the owner, where the bot can place no answer emoji.
rigStart question-no-account no-account
rigThread 000101 "$( rigReactions "$rigBoth" +1 )" ""
rigCall 60 AskQuestion '{"to":"human-owner","question":"Should the rig go on?","select":"yes-no"}'
rigAssert "a yes-no question: its post goes out under the team bot's token, none under the coordinator's, to the owner, and its record says the bot asked" \
	"$( rigOwnerPost )" "$rigBotToken:0:yes:bot:human-owner"
rigAssert "the thumbs up and the cross are placed under the bot's token, none under the coordinator's" \
	"$( rigPlacedAs "$rigBotToken" 000101 | cut -d' ' -f1-2 ):$( rigUsedAs reactions.add "$rigCoordinatorToken" )" "+1 x:no"
rigAssert "the asking call's own wait reads its thread as the bot, and the owner's click is the answer" \
	"$rigKilled:$( rigOwnerRead ):$( rigVerdictLine )" "no:yes:no:VERDICT: yes"
rigAssert "the answer is confirmed once in its thread, by the bot" \
	"$( rigConfirmed 'Read: `yes` by human-owner. It is recorded as the answer.' )" "$rigBotToken:yes:yes:2"

rigStart readback-no-account no-account
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'yes' )"
rigCall 60 ConfirmReadback '{"to":"human-owner","question":"Is this right?","understood":"The rig keeps the report.","source":"The message of today.","will_do":"Keep the report."}'
rigAssert "a readback: the same, the bot's post to the owner and the bot on its record" \
	"$( rigOwnerPost )" "$rigBotToken:0:yes:bot:human-owner"
rigAssert "its thumbs up and cross are placed under the bot's token" \
	"$( rigPlacedAs "$rigBotToken" 000101 | cut -d' ' -f1-2 ):$( rigUsedAs reactions.add "$rigCoordinatorToken" )" "+1 x:no"
rigAssert "read as the bot, and the owner's reply is the answer" \
	"$rigKilled:$( rigOwnerRead ):$( rigVerdictLine )" "no:yes:no:VERDICT: yes"
rigAssert "the answer is confirmed once in its thread, by the bot" \
	"$( rigConfirmed 'Read: `yes` by human-owner. It is recorded as the answer to this readback.' )" "$rigBotToken:yes:yes:2"

rigStart decision-no-account no-account
rigThread 000101 "$( rigReactions "$rigBoth" two )" ""
rigCall 60 EscalateDecision "{\"to\":\"human-owner\",\"question\":\"Which check first?\",$rigOptions}"
rigAssert "a decision: the same, the bot's post to the owner and the bot on its record" \
	"$( rigOwnerPost )" "$rigBotToken:0:yes:bot:human-owner"
rigAssert "its three numbers are placed under the bot's token" \
	"$( rigPlacedAs "$rigBotToken" 000101 | cut -d' ' -f1-3 ):$( rigUsedAs reactions.add "$rigCoordinatorToken" )" "one two three:no"
rigAssert "read as the bot, and the number the owner clicked is the option" \
	"$rigKilled:$( rigOwnerRead ):$( rigVerdictLine )" "no:yes:no:VERDICT: beta"
rigAssert "the answer is confirmed once in its thread, by the bot" \
	"$( rigConfirmed 'Read: `beta` by human-owner. It is recorded as the decision.' )" "$rigBotToken:yes:yes:2"

rigStart text-no-account no-account
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'Go on with it.' )"
rigCall 60 AskQuestion '{"to":"human-owner","question":"What should the rig do next?"}'
rigAssert "a free-text question: the bot's post to the owner and the bot on its record" \
	"$( rigOwnerPost )" "$rigBotToken:0:yes:bot:human-owner"
rigAssert "read as the bot, and the owner's reply is received" \
	"$rigKilled:$( rigOwnerRead ):$( rigFirstLine "$rigScenarioDir/out" )" "no:yes:no:ASK-RESULT: RECEIVED"
rigAssert "it has no answer form: no answer emoji is placed, and no confirmation is posted" \
	"$( rigCallsAs reactions.add "$rigBotToken" '1700000001.000101 +1' ):$( rigCallsAs reactions.add "$rigBotToken" '1700000001.000101 x' ):$( rigCalls chat.postMessage )" "0:0:1"

echo "-- the same asks from a member with an account of its own: the team bot posts them too --"
## The live fault: such a member asked the owner under its own account, in its own conversation
## with him, so he was asked in one place or another by who asked.
## Its question as the bot's: "<the no-account form>:<posts under the member's own token>".
rigOwnPost(){
	printf '%s:%s' "$( rigOwnerPost )" "$( rigCallsAs chat.postMessage "$rigOwnToken" )"
}
## Its emoji and its read: "<placed under the bot>:<any placed under its own>:<read under the bot>:<read under its own>".
rigOwnMarks(){ ## how many emoji names to show
	printf '%s:%s:%s:%s' "$( rigPlacedAs "$rigBotToken" 000101 | cut -d' ' -f1-"$1" )" "$( rigUsedAs reactions.add "$rigOwnToken" )" \
		"$( rigUsedAs conversations.replies "$rigBotToken" )" "$( rigUsedAs conversations.replies "$rigOwnToken" )"
}
rigStart question-own-account
rigThread 000101 "$( rigReactions "$rigBoth" +1 )" ""
rigCall 60 AskQuestion '{"to":"human-owner","question":"Should the rig go on?","select":"yes-no"}'
rigAssert "a yes-no question: the bot's post to the owner, none under the member's own token, and the bot on its record" \
	"$( rigOwnPost )" "$rigBotToken:0:yes:bot:human-owner:0"
rigAssert "its thumbs up and cross are placed and its thread is read under the bot's token, never under the member's own, and the owner's click is the answer" \
	"$( rigOwnMarks 2 ):$rigKilled:$( rigVerdictLine )" "+1 x:no:yes:no:no:VERDICT: yes"
rigAssert "the answer is confirmed once in its thread, by the bot" \
	"$( rigConfirmed 'Read: `yes` by human-owner. It is recorded as the answer.' )" "$rigBotToken:yes:yes:2"
rigStart readback-own-account
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'yes' )"
rigCall 60 ConfirmReadback '{"to":"human-owner","question":"Is this right?","understood":"The rig keeps the report.","source":"The message of today.","will_do":"Keep the report."}'
rigAssert "a readback: the same, and the owner's reply is the answer" \
	"$( rigOwnPost ):$( rigOwnMarks 2 ):$rigKilled:$( rigVerdictLine )" "$rigBotToken:0:yes:bot:human-owner:0:+1 x:no:yes:no:no:VERDICT: yes"
rigAssert "confirmed once in its thread, by the bot" \
	"$( rigConfirmed 'Read: `yes` by human-owner. It is recorded as the answer to this readback.' )" "$rigBotToken:yes:yes:2"
rigStart decision-own-account
rigThread 000101 "$( rigReactions "$rigBoth" two )" ""
rigCall 60 EscalateDecision "{\"to\":\"human-owner\",\"question\":\"Which check first?\",$rigOptions}"
rigAssert "a decision: the same, and the number the owner clicked is the option" \
	"$( rigOwnPost ):$( rigOwnMarks 3 ):$rigKilled:$( rigVerdictLine )" "$rigBotToken:0:yes:bot:human-owner:0:one two three:no:yes:no:no:VERDICT: beta"
rigAssert "confirmed once in its thread, by the bot" \
	"$( rigConfirmed 'Read: `beta` by human-owner. It is recorded as the decision.' )" "$rigBotToken:yes:yes:2"
rigStart text-own-account
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'Go on with it.' )"
rigCall 60 AskQuestion '{"to":"human-owner","question":"What should the rig do next?"}'
rigAssert "a free-text question: the bot's post, read as the bot, and the owner's reply is received" \
	"$( rigOwnPost ):$( rigUsedAs conversations.replies "$rigBotToken" ):$( rigUsedAs conversations.replies "$rigOwnToken" ):$rigKilled:$( rigFirstLine "$rigScenarioDir/out" )" \
	"$rigBotToken:0:yes:bot:human-owner:0:yes:no:no:ASK-RESULT: RECEIVED"
rigStart question-own-account-as-bot
rigThread 000101 "$( rigReactions "$rigBoth" x )" ""
rigCall 60 AskQuestion '{"to":"human-owner","as_bot":true,"question":"Should the rig go on?","select":"yes-no"}'
rigAssert "with as_bot true it is the bot's, as before: post, record, emoji and read" \
	"$( rigOwnPost ):$( rigOwnMarks 2 ):$( rigVerdictLine )" "$rigBotToken:0:yes:bot:human-owner:0:+1 x:no:yes:no:VERDICT: no"
rigStart question-own-account-not-as-bot
rigThread 000101 "$( rigReactions "$rigBoth" +1 )" ""
rigCall 60 AskQuestion '{"to":"human-owner","as_bot":false,"question":"Should the rig go on?","select":"yes-no"}'
rigAssert "and with as_bot false it is the bot's too: whatever as_bot says" \
	"$( rigOwnPost ):$( rigOwnMarks 2 ):$( rigVerdictLine )" "$rigBotToken:0:yes:bot:human-owner:0:+1 x:no:yes:no:VERDICT: yes"

echo "-- the accepted siblings ask as before --"
rigStart question-no-account-elsewhere no-account
rigThread 000101 "$( rigReactions "$rigBoth" +1 )" ""
rigCall 60 AskQuestion '{"to":"magic-team","address_to":"human-owner","question":"Should the rig go on?","select":"yes-no"}'
rigAssert "addressed to the owner in another conversation, by a member with no account: asked there as before, and its record says the member asked" \
	"$( rigHolds "$rigScenarioDir/post.1" '"channel":"CRIG00001"' ):$( rigRecordField ask-identity ):$( rigRecordField address-to ):$( rigVerdictLine )" "yes:member:human-owner:VERDICT: yes"
rigStart question-own-account-elsewhere
rigThread 000101 "$( rigReactions "$rigBoth" +1 )" ""
rigCall 60 AskQuestion '{"to":"magic-team","address_to":"human-owner","question":"Should the rig go on?","select":"yes-no"}'
rigAssert "and by a member with an account of its own: its own post there, its own emoji and read, none of them the bot's" \
	"$( rigPostedAs 1 ):$( rigHolds "$rigScenarioDir/post.1" '"channel":"CRIG00001"' ):$( rigCallsAs chat.postMessage "$rigBotToken" ):$( rigRecordField ask-identity ):$( rigPlacedAs "$rigOwnToken" 000101 | cut -d' ' -f1-2 ):$( rigUsedAs reactions.add "$rigBotToken" ):$( rigUsedAs conversations.replies "$rigBotToken" ):$( rigVerdictLine )" \
	"$rigOwnToken:yes:0:member:+1 x:no:no:VERDICT: yes"

echo "-- a proposal stays the coordinator's own: two posts under its account, and no emoji of the tooling --"
rigStart proposal
rigAs="magic-coordinator"
rigThread 000101 "$( rigReactions '"URIGOWNER"' white_check_mark )" ""
rigCall 60 ProposeApprove '{"question":"Do we retire the old sync on Friday?","proposal":"Retire the old sync on Friday. The new sync covers every case it had.","document":"https://example.invalid/wiki/PRO-007"}'
rigAs="$rigMember"
rigAssert "its root and its proposal reply go out under the coordinator's own token, to the owner, and its record says the member asked" \
	"$( rigPostedAs 1 ):$( rigPostedAs 2 ):$( rigCallsAs chat.postMessage "$rigBotToken" ):$( rigHolds "$rigScenarioDir/post.1" '"channel":"URIGOWNER"' ):$( rigRecordField ask-identity ):$( rigRecordField kind )" \
	"$rigCoordinatorToken:$rigCoordinatorToken:0:yes:member:proposal"
rigAssert "the owner's own check mark on the root is the verdict, and the tooling placed no emoji anywhere, under any token" \
	"$rigKilled:$( rigVerdictLine ):$( rigCalls reactions.add )" "no:VERDICT: approved:0"

echo "-- a plain question the bot asked: the collector reads it as the bot, and marks it as the bot at the first call --"
rigCollectMarks(){ ## token -> "<eyes on the reply>:<check mark on the question>" as placed under it
	printf '%s:%s' "$( rigCallsAs reactions.add "$1" '1700000001.000200 eyes' )" "$( rigCallsAs reactions.add "$1" '1700000001.000101 white_check_mark' )"
}
rigStart collect-bot-asked
rigCall 30 AskQuestion '{"to":"human-owner","as_bot":true,"question":"What should the rig do next?","wait":false}'
rigAssert "control: asked by the bot for a member with an account of its own, and left open" \
	"$( rigFirstLine "$rigScenarioDir/out" ):$( rigPostedAs 1 ):$( rigRecordField ask-identity ):$( rigRecordField status )" "ASK-RESULT: POSTED:$rigBotToken:bot:reply-pending"
rigCallsAside ask
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'Go on with it.' )"
rigOp --intern-op-pending-reply-collect --id "$( rigRecordId )" --context rig
rigAssert "the collector reads its thread under the bot's token, never under the member's own, and takes the answer" \
	"$( rigUsedAs conversations.replies "$rigBotToken" ):$( rigUsedAs conversations.replies "$rigOwnToken" ):$( LC_ALL=C grep -c "^ANSWERED $( rigRecordId ) " "$rigScenarioDir/op.out" ):$( rigRecordField status )" "yes:no:1:reply-received"
rigAssert "its resolved marks go on under the bot's token, and no call for them is made under the member's own" \
	"$( rigCollectMarks "$rigBotToken" ) $( rigUsedAs reactions.add "$rigOwnToken" )" "1:1 no"
rigStart collect-member-asked
rigCall 30 AskQuestion '{"to":"magic-team","address_to":"human-owner","question":"What should the rig do next?","wait":false}'
rigCallsAside ask
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'Go on with it.' )"
rigOp --intern-op-pending-reply-collect --id "$( rigRecordId )" --context rig
rigAssert "accepted sibling: one the member asked is read and marked under the member's own token, as before" \
	"$( rigRecordField ask-identity ):$( rigUsedAs conversations.replies "$rigOwnToken" ):$( rigUsedAs conversations.replies "$rigBotToken" ):$( rigCollectMarks "$rigOwnToken" ) $( rigUsedAs reactions.add "$rigBotToken" )" "member:yes:no:1:1 no"

echo "-- a permission whose addressee does not hold the call goes to the holder running in the session --"
rigHost="$( hostname -s 2>/dev/null || echo unknown )"
rigCow="rig-askbot-cow"
rigAskerSpawn="rig-askbot-asker"
rigHolderSpawn="rig-askbot-holder"
rigRoutedPath="/dev/null/rig-askbot/routed"
rigSpawnRecord(){ ## spawn id, owner
	mkdir -p "$rigScenarioDir/ws/.local/agents/spawned/$rigCow"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nowner: %s\nstatus: spawn-started\n---\n\n# Spawn session\n' \
		"$rigCow" "$1" "$rigHost" "$2" > "$rigScenarioDir/ws/.local/agents/spawned/$rigCow/$1.md"
}
## A live run of one spawn: a line of the rig's own process list that carries its spawn id.
rigLive(){ ## spawn id
	printf '%s rig-run --session-id %s\n' "$(( 900000 + RANDOM ))" "$1" >> "$RIG_PS_LIST"
}
rigDead(){ ## spawn id
	LC_ALL=C awk -v gone="$1" '$NF != gone' "$RIG_PS_LIST" > "$RIG_PS_LIST.next" && mv -f "$RIG_PS_LIST.next" "$RIG_PS_LIST"
}
## The asker and a developer take part in one coworking session. The developer holds the
## refused call by a standing row and has an account of its own; the coordinator holds nothing.
rigRoutedStart(){ ## scenario directory name
	rigStart "$1"
	printf 'SLACK_USER_TOKEN=%s\n' "$rigDeveloperToken" > "$rigScenarioDir/ws/.local/.agents/magic-developer.agent.env"
	printf 'URIGDEVEL' > "$rigScenarioDir/account.$rigDeveloperToken"
	printf 'magic-developer:ws:workspace:Edit(//dev/null/rig-askbot/**)\n' > "$rigScenarioDir/ws/.local/agents/permissions.registry"
	rigSpawnRecord "$rigAskerSpawn" "$rigMember"
	rigSpawnRecord "$rigHolderSpawn" magic-developer
	rigSession="$rigAskerSpawn"
	rigCall 60 Write "{\"path\":\"$rigRoutedPath\",\"content\":\"x\"}"
	rigRoutedRefusal="$( rigRefusal "$rigScenarioDir/out" )"
	[ -n "$rigRoutedRefusal" ] || rigRefuse "the rig produced no refusal to ask permission for"
}
rigRoutedAsk(){
	rigCall 60 RequestPermission "{\"to\":\"magic-coordinator\",\"question\":\"May the rig write this file?\",\"refusal_id\":\"$rigRoutedRefusal\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}"
}
rigRoutedStart permission-routed-member
rigLive "$rigHolderSpawn"
## The routed member asks back before it answers, so the asking call returns with the question open.
rigThread 000101 "" "$( rigMessage 000200 URIGDEVEL 'What is it for?' )"
rigRoutedAsk
rigAssert "the result says who it went to instead of the one named, and why, in one NOTE line" \
	"$( LC_ALL=C grep -c -x -F "NOTE: addressed to magic-developer, not magic-coordinator: magic-coordinator does not hold Write $rigRoutedPath, and magic-developer holds it and runs in this session" "$rigScenarioDir/out" ):$( LC_ALL=C grep -c '^NOTE: addressed to ' "$rigScenarioDir/out" )" "1:1"
rigAssert "it is the asking member's own post, to that member and never to the one named or the owner, and its record names that member as asked" \
	"$( rigPostedAs 1 ):$( rigHolds "$rigScenarioDir/post.1" '"channel":"URIGDEVEL"' ):$( rigCallsAs chat.postMessage "$rigBotToken" ):$( rigRecordField ask-identity ):$( rigRecordField address-to ):$( rigRecordField addressees )" \
	"$rigOwnToken:yes:0:member:magic-developer:URIGDEVEL"
rigAssert "its answer emoji are placed under the asking member's own token" "$( rigPlacedAs "$rigOwnToken" 000101 | cut -d' ' -f1-3 )" "x one repeat"
rigAssert "a reply of that member that names no answer comes back, and the request stays open" \
	"$rigKilled:$( rigVerdictLine ):$( rigRecordField status )" "no:VERDICT: RETURNED:reply-pending"
rigRoutedId="$( rigRecordId )"
RIG_OP_AGENT=magic-developer RIG_OP_SESSION="$rigHolderSpawn" rigOp --member-escalation-answer magic-developer "$rigRoutedId" allow-session
rigAssert "that member answers it as itself, and the grant is written" \
	"$( LC_ALL=C grep -c -x -F "ESCALATION: $rigRoutedId answered" "$rigScenarioDir/op.out" ):$( LC_ALL=C grep -c '^GRANT: session ' "$rigScenarioDir/op.out" ):$( rigRecordField status ):$( rigRecordField answered-by )" "1:1:reply-received:magic-developer"
rigCall 60 Wait "{\"sources\":\"ask:$rigRoutedId\",\"timeout\":5}"
rigAssert "and the asker's Wait on its ask takes that answer, with its grant" \
	"$rigKilled:$( rigVerdictLine ):$( LC_ALL=C sed -n 's/^ANSWERED-BY: //p' "$rigScenarioDir/out" | head -1 ):$( LC_ALL=C grep -c '^GRANT: session ' "$rigScenarioDir/out" )" "no:VERDICT: allow-session:magic-developer:1"
rigDead "$rigHolderSpawn"
## Accepted sibling: the same ask with that holder's run ended goes to the human-owner, by the bot.
rigRoutedStart permission-routed-owner
rigThread 000101 "$( rigReactions "$rigBoth" one )" ""
rigRoutedAsk
rigAssert "accepted sibling: with no live run of the holder it goes to the human-owner, as the team bot's post, and the result says so" \
	"$( LC_ALL=C grep -c -x -F "NOTE: addressed to human-owner, not magic-coordinator: magic-coordinator does not hold Write $rigRoutedPath, and nobody running in this session holds it" "$rigScenarioDir/out" ):$( rigPostedAs 1 ):$( rigHolds "$rigScenarioDir/post.1" '"channel":"URIGOWNER"' ):$( rigRecordField ask-identity ):$( rigRecordField address-to ):$( rigVerdictLine )" \
	"1:$rigBotToken:yes:bot:human-owner:VERDICT: allow-once"
rigSession=""

echo "-- what the RequestPermission description says of both --"
rigWireLine="$( LC_ALL=C grep -F '{"type":"function","function":{"name":"RequestPermission",' "$rigHere/AgentsOpenAiChatWire.sh" )"
rigWireSays(){ ## text -> yes when the description holds it
	case "$rigWireLine" in *"$1"*) printf yes ;; *) printf no ;; esac
}
rigAssert "it says a request to the human-owner is posted by the team bot, whatever as_bot says" \
	"$( rigWireSays 'A request to the human-owner is posted by the team bot, in the conversation of the bot with the owner, whatever as_bot says.' )" yes
rigAssert "it says the request may be addressed to another than the one named, and that a NOTE: line says who and why" \
	"$( rigWireSays 'the request is addressed to a holder running in this session, else to the human-owner' ):$( rigWireSays 'A NOTE: line of the result then says who it was addressed to, and why.' )" "yes:yes"
rigAssert "one declaration, on one line, and no apostrophe in it: the tools JSON stands inside single quotes" \
	"$( printf '%s\n' "$rigWireLine" | LC_ALL=C grep -c . ):$( printf '%s\n' "$rigWireLine" | LC_ALL=C grep -c "'" )" "1:0"
## The as_bot text of the three other tools that ask says the rule: the bot, whatever as_bot says.
rigWireOf(){ ## tool name -> its one declaration line
	LC_ALL=C grep -F "{\"type\":\"function\",\"function\":{\"name\":\"$1\"," "$rigHere/AgentsOpenAiChatWire.sh"
}
rigWireAsBot=""
for rigWireTool in AskQuestion:question ConfirmReadback:readback EscalateDecision:decision ; do
	case "$( rigWireOf "${rigWireTool%%:*}" )" in
		*"\"as_bot\":{\"type\":\"boolean\",\"description\":\"Optional. true posts as the team bot instead of your member identity. Default false. A ${rigWireTool##*:} to the human-owner is posted by the team bot whatever this says, in the conversation of the bot with the owner.\"}"*) rigWireAsBot="$rigWireAsBot${rigWireTool%%:*}=yes " ;;
		*) rigWireAsBot="$rigWireAsBot${rigWireTool%%:*}=no " ;;
	esac
done
rigAssert "the as_bot text of AskQuestion, ConfirmReadback and EscalateDecision says the bot asks the human-owner whatever as_bot says, each for its own kind" \
	"$rigWireAsBot" "AskQuestion=yes ConfirmReadback=yes EscalateDecision=yes "
rigAssert "each of the three is one declaration on one line, with no apostrophe in it" \
	"$( { rigWireOf AskQuestion ; rigWireOf ConfirmReadback ; rigWireOf EscalateDecision ; } | LC_ALL=C grep -c . ):$( { rigWireOf AskQuestion ; rigWireOf ConfirmReadback ; rigWireOf EscalateDecision ; } | LC_ALL=C grep -c "'" )" "3:0"
rigAssert "the served list is still rendered from it" \
	"$( bash "$rigHere/AgentsHarnessMcpMirror.sh" 2>/dev/null | LC_ALL=C grep -c -F '{"name":"RequestPermission","description":"Ask for the access a task needs, starting from a call that was refused' )" 1

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK OWNER BOT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_OWNER_BOT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
