#!/usr/bin/env bash
## Behavioural check on propose-approve reactions (F9.4 of the refactorings epic): ProposeApprove gains the reaction
## integration RequestPermission has, copied from it: the template names under `# Reactions` the emoji the tooling
## places, they are placed under the root by the identity that posted, a reaction by that identity is never an
## answer, and a discarded proposal has the tooling's own answer emoji taken off. It replaces the `# Contract` rule
## "The root is posted once" (sh-lib/templates/propose-approve.post.format.md:122); AgentsHarnessProposeApproveCheck
## asserts the old rule ("no emoji placed") and is brought in line in the same feature.
## Run through --intern-tool, the path the myx.distro MCP uses.
## Held:
##   1. the template's `# Reactions` block for `approve` names the two the verdict reader takes for a proposal, `x`
##      first and then white_check_mark, the order RequestPermission and Permission set place theirs in (open-names 58)
##   2. put: those two are placed on the root, and on no other post
##   3. read: the tooling's own two on the root, by the posting identity, are no verdict, and the call waits on
##   4. read: with the human-owner's own check mark beside them, the verdict is approved, not rejected
##   5. discarded: the tooling takes its own two off the root
## Red before F9.4: the template places no emoji (1, 2 and 5 fail; 3 and 4 hold today, by the reader, and must stay).
## Offline: a Slack-shaped fake curl is first on PATH, and every scenario runs in its own workspace under this
## check's temp tree, in $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigMember="magic-coordinator"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsProposeApproveReactionsCheck.XXXXXX" )" || exit 1
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
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}
rigVerdictLine(){
	LC_ALL=C awk '/^VERDICT: / { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-verdict-line" ; } }' "$rigScenarioDir/out"
}
rigRecordId(){
	local recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] && { recordFile="${recordFile##*/}" ; printf '%s' "${recordFile%.md}" ; return 0 ; }
	done
	printf 'no-record'
}
## The emoji placed on, or taken off, one post: its names sorted, joined by spaces.
rigReactedSet(){ ## reactions|reactions.removed, ts suffix
	LC_ALL=C awk -v want="1700000001.$2" '$1 == want { print $2 ; }' "$rigScenarioDir/$1" 2>/dev/null | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed -e 's/ $//'
}
## The posts other than the root that the tooling put an emoji on.
rigReactedElsewhere(){
	LC_ALL=C awk '$1 != "1700000001.000101" { print $1 ; }' "$rigScenarioDir/reactions" 2>/dev/null | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed -e 's/ $//'
}
rigScenarioDir=""
rigScenarioName=""
rigStart(){ ## scenario directory name
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/IN" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-COORDINATOR\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
rigThread(){ ## first message ts suffix, its extra fields (may be empty), later messages (may be empty)
	printf '{"ok":true,"messages":[{"ts":"1700000001.%s","user":"URIGSELF1","text":"first"%s}%s],"has_more":false}\n' "$1" "$2" "$3" > "$rigScenarioDir/replies.json"
}
rigMessage(){ ## thread root ts suffix, ts suffix, user, text
	printf ',{"ts":"1700000001.%s","user":"%s","text":"%s","thread_ts":"1700000001.%s"}' "$2" "$3" "$4" "$1"
}
## The tooling's own two on the root, by the posting identity, and what else stands with them.
rigOwnPlaced='{"name":"white_check_mark","count":1,"users":["URIGSELF1"]},{"name":"x","count":1,"users":["URIGSELF1"]}'
rigOwnAndOwner='{"name":"white_check_mark","count":2,"users":["URIGSELF1","URIGOWNER"]},{"name":"x","count":1,"users":["URIGSELF1"]}'
rigKilled=""
rigCall(){ ## guard seconds, tool, argument object, optional from-read
	local callPid callLeft callStartLeft=120 callReads
	rigKilled="no"
	callReads="$( rigCalls conversations.replies )"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID="rig-react-$rigScenarioName" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	callPid=$!
	set +m
	rigProcNote "$callPid"
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
		{ rigProcGroupSignal TERM "$callPid" ; sleep 1 ; rigProcGroupSignal KILL "$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}
rigLink='https://example.invalid/wiki/PRO-007'
rigPropose="\"to\":\"magic-team\",\"question\":\"Do we retire the old sync on Friday?\",\"proposal\":\"Retire the old sync on Friday.\",\"document\":\"$rigLink\""

echo "-- 1. the template names the emoji it places --"
rigAssert "x, then white_check_mark, under # Reactions, for approve" \
	"$( ASKP_WANT=reactions ASKP_FORM=approve LC_ALL=C awk -f "$rigHere/comms/AgentsToolingTemplateFill.awk" -f "$rigHere/questions/AgentsAskPostFill.awk" "$rigHere/templates/propose-approve.post.format.md" 2>&1 | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed -e 's/ $//' )" "x white_check_mark"

echo "-- 2. put: the two placed on the root alone --"
rigStart put
rigThread 000101 "" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 8 ProposeApprove "{$rigPropose}" from-read
rigAssert "two posts, the root and the proposal, and the call waits" "$( rigCalls chat.postMessage ):$rigKilled" "2:yes"
rigAssert "the root carries the two"                             "$( rigReactedSet reactions 000101 )" "white_check_mark x"
rigAssert "no other post carries an emoji of the tooling"        "[$( rigReactedElsewhere )]" "[]"
rigPutId="$( rigRecordId )"

echo "-- 3. the tooling's own two are no verdict --"
rigThread 000101 ",\"reactions\":[$rigOwnPlaced]" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 6 ProposeApprove "{\"pending_id\":\"$rigPutId\"}" from-read
rigAssert "the call waits on, and nothing came back as a verdict" "$rigKilled:$( rigVerdictLine )" "yes:no-verdict-line"

echo "-- 4. his own check mark beside them approves --"
rigThread 000101 ",\"reactions\":[$rigOwnAndOwner]" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 60 ProposeApprove "{\"pending_id\":\"$rigPutId\"}"
rigAssert "the verdict is approved, not the tooling's own x"     "$rigKilled:$( rigVerdictLine )" "no:VERDICT: approved"

echo "-- 5. discarded: the tooling's own two taken off the root --"
rigStart discard
rigThread 000101 "" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 8 ProposeApprove "{$rigPropose}" from-read
rigThread 000101 ",\"reactions\":[$rigOwnPlaced]" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 60 ProposeApprove "{\"pending_id\":\"$( rigRecordId )\",\"withdraw\":\"superseded by a wider proposal\"}"
rigAssert "it is withdrawn, and the two are taken off the root"  "$( LC_ALL=C awk 'NR == 1' "$rigScenarioDir/out" ):$( rigReactedSet reactions.removed 000101 )" "ASK-RESULT: WITHDRAWN:white_check_mark x"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method"          "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PROPOSE APPROVE REACTIONS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PROPOSE_APPROVE_REACTIONS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
