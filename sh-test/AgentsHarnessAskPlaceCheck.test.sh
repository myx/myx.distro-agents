#!/usr/bin/env bash
## Behavioural check on WHERE a question is posted, run through --intern-tool, the path the
## myx.distro MCP uses. Covers: a team member's name is an addressee, never a place -- a
## question, and a decision, asked of a member by its name is a reply in the asking session's
## own thread, addressed to that member, whether or not that member has a Slack account, and
## its answer is read there; with no session thread it goes to that member's own conversation
## as before; the human-owner is asked in the owner's own conversation as before. And a
## question asked again after its asker withdrew it is a new message of its own, never a reply
## under the cancelled one, while one asked again after it was answered still goes into its
## own thread.
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessAskPlaceCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
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

rigBotToken="rig-bot-token-TEAM"
rigOwnToken="rig-user-token-TESTER"
rigCoordinatorToken="rig-user-token-COORD"

## One scenario's workspace. The coordinator always has an account of its own, and so has the
## asking member, unless the scenario is started with no-account. The developer has none.
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
## The thread of the coworking session the asking member works in, <channel>:<ts>, or none.
rigSessionThread=""
rigCall(){ ## guard seconds, tool, argument object, optional from-read
	local callPid callLeft callStartLeft=120 callReads
	rigKilled="no"
	callReads="$( rigCalls conversations.replies )"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD \
		${rigSessionThread:+MDAT_SESSION_THREAD="$rigSessionThread"} MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID="${rigSession:-rig-askplace-$rigScenarioName}" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigAs" MDAT_HARNESS_WAIT_TIMEOUT=1 \
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

rigOptions='"options":"alpha -- the unit checks\nbeta -- the lint\ngamma -- the smoke run"'
rigThreadOfSession="CRIG00001:1700000000.000001"
## Where one post of the scenario went: "<its conversation>:<the thread it is a reply in, or top>".
rigPostedTo(){ ## post number
	[ -f "$rigScenarioDir/post.$1" ] || { printf 'no-such-post' ; return 0 ; }
	printf '%s:%s' "$( LC_ALL=C sed -n 's/^{"channel":"\([^"]*\)".*/\1/p' "$rigScenarioDir/post.$1" | head -1 )" \
		"$( LC_ALL=C sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigScenarioDir/post.$1" | head -1 | LC_ALL=C grep . || printf top )"
}
## The coordinator has an account of its own in every scenario: URIGCOORD.
rigMemberStart(){ ## scenario directory name, optional no-account
	rigStart "$@"
	printf 'URIGCOORD' > "$rigScenarioDir/account.$rigCoordinatorToken"
}

echo "-- a team member asked by its name: a reply in the session's own thread, addressed to that member --"
## The live fault: the name was taken as that member's own conversation, a place nobody else
## of the session can read, and only a member with an account has one.
rigMemberStart member-in-thread
rigSessionThread="$rigThreadOfSession"
rigCall 60 AskQuestion '{"to":"magic-coordinator","question":"Which sample goes first?","wait":false}'
rigAssert "a question to a member with an account: posted, as a reply in the session thread, never in that member's own conversation" \
	"$( rigFirstLine "$rigScenarioDir/out" ):$( rigPostedTo 1 ):$( rigCalls chat.postMessage )" "ASK-RESULT: POSTED:CRIG00001:1700000000.000001:1"
rigAssert "it is addressed to that member, by its account, and its record says who was asked and where" \
	"$( rigHolds "$rigScenarioDir/post.1" '<@URIGCOORD>' ):$( rigRecordField address-to ):$( rigRecordField addressees ):$( rigRecordField thread-ts ):$( rigRecordField communication-channel-id )" \
	"yes:magic-coordinator:URIGCOORD:1700000000.000001:slack:$rigThreadOfSession"
rigAssert "asked into a thread it carries its number for that member" "$( rigRecordField question-tag )" "Q1"

rigMemberStart member-no-account-in-thread
rigCall 60 AskQuestion '{"to":"magic-developer","question":"Which sample goes first?","wait":false}'
rigAssert "a question to a member with no account: posted the same way, where before nothing could be sent to it" \
	"$( rigFirstLine "$rigScenarioDir/out" ):$( rigPostedTo 1 ):$( LC_ALL=C grep -c 'has no Slack DM channel' "$rigScenarioDir/out" )" "ASK-RESULT: POSTED:CRIG00001:1700000000.000001:0"
rigAssert "it is addressed to that member by its name, and its record says who was asked" \
	"$( rigHolds "$rigScenarioDir/post.1" '→ 🤖 *_magic-developer_*.' ):$( rigRecordField address-to )" "yes:magic-developer"

rigMemberStart decision-in-thread
rigThread 000101 "$( rigReactions '"URIGSELF1","URIGCOORD"' two )" ""
rigCall 60 EscalateDecision "{\"to\":\"magic-coordinator\",\"question\":\"Which check first?\",$rigOptions}"
rigAssert "a decision asked of a member by its name: a reply in the session thread too, and that member's click there is the answer" \
	"$rigKilled:$( rigPostedTo 1 ):$( rigVerdictLine ):$( rigRecordField address-to )" "no:CRIG00001:1700000000.000001:VERDICT: beta:magic-coordinator"

rigMemberStart address-apart
rigCall 60 AskQuestion '{"to":"magic-coordinator","address_to":"magic-developer","question":"Which sample goes first?","wait":false}'
rigAssert "a member named as the place and another as the addressee: the session thread is the place, and the addressee is who was asked" \
	"$( rigPostedTo 1 ):$( rigRecordField address-to )" "CRIG00001:1700000000.000001:magic-developer"

echo "-- the accepted siblings are asked where they were --"
rigMemberStart owner-in-thread
rigCall 60 AskQuestion '{"to":"human-owner","question":"Which sample goes first?","wait":false}'
rigAssert "the human-owner, asked from a session that has a thread: in the owner's own conversation, a message of its own" \
	"$( rigFirstLine "$rigScenarioDir/out" ):$( rigPostedTo 1 ):$( rigRecordField address-to )" "ASK-RESULT: POSTED:URIGOWNER:top:human-owner"
rigMemberStart thread-named
rigCall 60 AskQuestion '{"to":"CRIG00001:1700000000.000777","address_to":"magic-coordinator","question":"Which sample goes first?","wait":false}'
rigAssert "a thread named as the place stays the place" "$( rigPostedTo 1 ):$( rigRecordField address-to )" "CRIG00001:1700000000.000777:magic-coordinator"
rigSessionThread=""
rigMemberStart member-no-thread
rigCall 60 AskQuestion '{"to":"magic-coordinator","question":"Which sample goes first?","wait":false}'
rigAssert "a session with no thread of its own: that member's own conversation, as before" \
	"$( rigFirstLine "$rigScenarioDir/out" ):$( rigPostedTo 1 ):$( rigRecordField address-to )" "ASK-RESULT: POSTED:URIGCOORD:top:magic-coordinator"

echo "-- a question asked again after its asker withdrew it: a new message of its own --"
## The live fault: it was posted as a reply under the withdrawn one, whose post carries the
## cancelled mark.
rigStart reask-after-withdraw
rigCall 60 AskQuestion '{"to":"human-owner","question":"What should the rig do next?","wait":false}'
rigAssert "control: asked first as a message of its own, and left open" \
	"$( rigFirstLine "$rigScenarioDir/out" ):$( rigPostedTo 1 ):$( rigRecordField status )" "ASK-RESULT: POSTED:URIGOWNER:top:reply-pending"
rigWithdrawnId="$( rigRecordId )"
rigCall 60 AskQuestion "{\"pending_id\":\"$rigWithdrawnId\",\"withdraw\":\"the rig asked it the wrong way\"}"
rigAssert "control: withdrawn" "$( rigFirstLine "$rigScenarioDir/out" ):$( rigRecordField status )" "ASK-RESULT: WITHDRAWN:withdrawn"
rigPostsBefore="$( cat "$rigScenarioDir/posts" 2>/dev/null || printf 0 )"
rigCall 60 AskQuestion '{"to":"human-owner","question":"What should the rig do next?","wait":false}'
rigAssert "asked again: posted, as a new message of its own in the owner's conversation, never under the withdrawn one" \
	"$( rigFirstLine "$rigScenarioDir/out" ):$( rigPostedTo "$(( rigPostsBefore + 1 ))" ):$( cat "$rigScenarioDir/posts" 2>/dev/null )" "ASK-RESULT: POSTED:URIGOWNER:top:$(( rigPostsBefore + 1 ))"
rigAssert "and it is a record of its own, open, beside the withdrawn one" \
	"$( LC_ALL=C grep -l -x 'status: reply-pending' "$rigScenarioDir/ws/.local/agents/pending"/*.md 2>/dev/null | LC_ALL=C grep -c . ):$( LC_ALL=C grep -l -x 'status: withdrawn' "$rigScenarioDir/ws/.local/agents/pending"/*.md 2>/dev/null | LC_ALL=C grep -c . )" "1:1"

rigStart reask-after-answer
rigSession="rig-askplace-first"
rigCall 60 AskQuestion '{"to":"human-owner","question":"What should the rig do next?","wait":false}'
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'Go on with it.' )"
rigOp --intern-op-pending-reply-collect --id "$( rigRecordId )" --context rig
rigAssert "control: the first one was answered and is closed" "$( rigRecordField status )" "reply-received"
rigPostsBefore="$( cat "$rigScenarioDir/posts" 2>/dev/null || printf 0 )"
## From another session: the session that asked it holds its answer, and asks nothing again.
rigSession="rig-askplace-second"
rigCall 60 AskQuestion '{"to":"human-owner","question":"What should the rig do next?","wait":false}'
rigSession=""
## The fake Slack names every conversation it answers for CRIG00001, so that is the thread's.
rigAssert "accepted sibling: asked again after it was answered, it still goes into its own thread" \
	"$( rigPostedTo "$(( rigPostsBefore + 1 ))" )" "CRIG00001:1700000001.000101"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK PLACE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_PLACE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
