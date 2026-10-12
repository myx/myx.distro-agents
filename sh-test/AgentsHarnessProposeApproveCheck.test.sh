#!/usr/bin/env bash
## Behavioural check on ProposeApprove, the tool that puts a proposal document to the
## human-owner, run through --intern-tool, the path the myx.distro MCP uses. Covers: its two
## posts filled from its own template, the root that is its question and the proposal reply
## under it with the link to its document; no emoji placed by the tooling; a comment coming
## back as VERDICT: RETURNED with the ways on; a changed proposal (revise) replacing the reply
## and never touching the root; the verdict by the human-owner's own click on the root and by
## a reply's first word; a click under the proposal reply being no verdict; a reply before the
## live proposal reply ignored whole and one after it read whole, each line with the reply it
## belongs to, a reply the thread reader set aside included; a change refused
## with the verdict once one is on the root; the calls that post nothing and come back as a
## CORRECTION (no document, another member than the coordinator, a thread as `to`); a
## discarded proposal; the verdict on the Decisions of its tracking item, with the link; and
## the declaration every wire and the MCP serve.
## Offline: a Slack-shaped fake curl is first on PATH, and every scenario runs in its own
## workspace under this check's temp tree, in $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigMember="magic-coordinator"
rigOther="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigOther/$rigOther.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigOther, the member this check proposes as in vain"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessProposeApproveCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
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
## Whether a result opens with a text: its first line starts with it.
rigOpens(){ ## file, text
	case "$( rigFirstLine "$1" )" in
		"$2"*) printf 'yes' ;;
		*)     printf 'no' ;;
	esac
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
rigRecordCount(){
	local recordCount=0 recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] && recordCount=$(( recordCount + 1 ))
	done
	printf '%s' "$recordCount"
}
rigRecordField(){ ## field
	LC_ALL=C awk -v key="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$( rigRecordFile )" 2>/dev/null || printf 'no-record'
}
rigRecordId(){
	local recordId
	recordId="$( rigRecordFile )" ; recordId="${recordId##*/}"
	printf '%s' "${recordId%.md}"
}
## The emoji placed on, or taken off, one post: its names in the order asked for.
rigReacted(){ ## reactions|reactions.removed, ts suffix
	LC_ALL=C awk -v want="1700000001.$2" '$1 == want { out = out ( out == "" ? "" : " " ) $2 ; } END { print out ; }' "$rigScenarioDir/$1" 2>/dev/null
}
## The thread a post was sent into, empty for a message of its own.
rigThreadOf(){ ## body file
	LC_ALL=C sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$1" 2>/dev/null | head -1
}
## Whether an edit is a whole message as the send builds one: it names the post it edits,
## has blocks, and holds no How to answer anywhere -- "<names it>:<blocks>:<How to answer>".
rigEditShape(){ ## edit body file, ts of the post
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	printf '%s:%s:%s' "$( LC_ALL=C grep -c -F "\"ts\":\"$2\"" "$1" )" "$( LC_ALL=C grep -c -F '"blocks":[' "$1" )" "$( LC_ALL=C grep -c -F 'How to answer' "$1" )"
}

rigScenarioDir=""
rigScenarioName=""
rigStart(){ ## scenario directory name
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/IN" "$rigScenarioDir/ws/OUT" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-COORDINATOR\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigOther.agent.env"
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
rigSelf='"URIGSELF1"'
rigOwner='"URIGOWNER"'
rigStranger='"URIGOTHER"'
rigReactions(){ ## users (a JSON list body), reaction names...
	local reactUsers="$1" reactOut="" reactName
	shift
	for reactName in "$@" ; do
		reactOut="$reactOut${reactOut:+,}{\"name\":\"$reactName\",\"count\":2,\"users\":[$reactUsers]}"
	done
	printf ',"reactions":[%s]' "$reactOut"
}
rigMessage(){ ## thread root ts suffix, ts suffix, user, text, optional extra fields
	printf ',{"ts":"1700000001.%s","user":"%s","text":"%s","thread_ts":"1700000001.%s"%s}' "$2" "$3" "$4" "$1" "${5:-}"
}

## One served call of a tool, as one member. A proposal nobody answers is re-waited without
## end by design, so the guard is the scenario's: a killed run is reported as such, never as
## a result. With from-read the guard counts from the first thread read this call makes.
rigKilled=""
rigAs="$rigMember"
rigCall(){ ## guard seconds, tool, argument object, optional from-read
	local callPid callLeft callStartLeft=120 callReads
	rigKilled="no"
	callReads="$( rigCalls conversations.replies )"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID="rig-propose-$rigScenarioName" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigAs" MDAT_HARNESS_WAIT_TIMEOUT=1 \
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

## One post filled straight from its template, as the tool fills it.
rigFill(){ ## want, template, form -- the slots come from the caller's environment
	ASKP_WANT="$1" ASKP_FORM="$3" LC_ALL=C awk -f "$rigHere/AgentsToolingTemplateFill.awk" -f "$rigHere/AgentsAskPostFill.awk" "$rigHere/templates/$2" 2>&1
}
## The verdict the one reader takes from one rendering of the answers.
rigVerdict(){ ## the answers, as AgentsSlackThreadAnswers.awk prints them
	printf '%s\n' "$1" | MDAT_VERDICT_KIND=proposal MDAT_VERDICT_AUTHORS="URIGOWNER" MDAT_VERDICT_ASKING="URIGSELF1" LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" | LC_ALL=C tr '\t' '|'
}

rigLink='https://example.invalid/wiki/PRO-007'
rigLinkTwo='https://example.invalid/wiki/PRO-007?version=2'
rigQuestion='Do we retire the old sync on Friday?'
rigPropose="\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"proposal\":\"Retire the old sync on Friday. The new sync covers every case it had.\",\"document\":\"$rigLink\""

echo "-- the two posts, from the tool's own template --"
rigAssert "the root is the question alone, under its own title" \
	"$( ASKP_BLOCK=Skeleton/root ASKP_F_question='Which way?' rigFill block propose-approve.post.format.md '' )" \
	$'# 📜 Proposal\n\nWhich way?'
rigAssert "the proposal reply: the proposed form, the link to its document, how to answer" \
	"$( ASKP_F_proposal='This way.' ASKP_F_document="$rigLink" rigFill post propose-approve.post.format.md approve )" \
	$'# 📄 The proposal\n\nThis way.\n\n**🔗 Document**\n'"$rigLink"$'\n\n**✅ How to answer**\n- react on the first message of this thread: ✅ approves the document, ❌ rejects the proposal\n- or reply here `approved` or `rejected`\n- any other reply here is a comment: the proposal is worked out from it, and this message is replaced by the changed one'
rigAssert "the context is shown where one is given" \
	"$( ASKP_F_proposal='This way.' ASKP_F_document="$rigLink" ASKP_F_context='ctx' rigFill post propose-approve.post.format.md approve | LC_ALL=C sed -n '8,9p' )" \
	$'**⚙ Context**\nctx'
rigAssert "a proposal with no document is not filled" \
	"$( ASKP_F_proposal='This way.' ASKP_F_document='' rigFill post propose-approve.post.format.md approve )" \
	"AgentsAskPostFill.awk: the slot {{document}} is required and has no value"
rigAssert "the template places no emoji: the root carries only a person's own" \
	"$( rigFill reactions propose-approve.post.format.md approve | LC_ALL=C grep -c . )" 0
rigAssert "a reply that takes no answer any more: the same text without How to answer" \
	"$( ASKP_F_proposal='This way.' ASKP_F_document="$rigLink" rigFill closed propose-approve.post.format.md approve )" \
	$'# 📄 The proposal\n\nThis way.\n\n**🔗 Document**\n'"$rigLink"
rigAssert "the template has no mark for a root or a replaced reply, and one for a discarded reply" \
	"$( ASKP_BLOCK=Marks/superseded rigFill block propose-approve.post.format.md '' | LC_ALL=C grep -c 'has no block' ):$( ASKP_BLOCK=Marks/revised rigFill block propose-approve.post.format.md '' | LC_ALL=C grep -c 'has no block' ):$( ASKP_BLOCK=Marks/cancelled rigFill block propose-approve.post.format.md '' )" \
	"1:1:no_entry_sign"

echo "-- the verdict reader: his own click on the root, or the first word of a reply --"
rigAssert "the check mark approves"                    "$( rigVerdict 'reaction on the question: [reactions: white_check_mark x1 (URIGOWNER)]' )" "approved|URIGOWNER|"
rigAssert "the cross rejects"                          "$( rigVerdict 'reaction on the question: [reactions: x x1 (URIGOWNER)]' )" "rejected|URIGOWNER|"
rigAssert "both held: rejected first"                  "$( rigVerdict $'reaction on the question: [reactions: white_check_mark x1 (URIGOWNER)]\nreaction on the question: [reactions: x x1 (URIGOWNER)]' )" "rejected|URIGOWNER|"
rigAssert "a thumbs up approves nothing"               "$( rigVerdict 'reaction on the question: [reactions: +1 x1 (URIGOWNER)]' )" "RETURNED||"
rigAssert "a check mark by the asking account is none" "$( rigVerdict 'reaction on the question: [reactions: white_check_mark x1 (URIGSELF1)]' )" "RETURNED||"
rigAssert "a check mark by anyone else is none"        "$( rigVerdict 'reaction on the question: [reactions: white_check_mark x1 (URIGOTHER)]' )" "RETURNED||"
rigAssert "a reply: approved"                          "$( rigVerdict '1700000001.000300 | URIGOWNER | Approved.' )" "approved|URIGOWNER|1700000001.000300"
rigAssert "a reply: rejected, with its text"           "$( rigVerdict '1700000001.000300 | URIGOWNER | rejected: the scope is too wide' )" "rejected -- the scope is too wide|URIGOWNER|1700000001.000300"
rigAssert "a plain ok approves nothing"                "$( rigVerdict '1700000001.000300 | URIGOWNER | ok' )" "RETURNED||"
rigAssert "the word anywhere but first is no verdict"  "$( rigVerdict '1700000001.000300 | URIGOWNER | I have not approved this' )" "RETURNED||"
rigAssert "the other kinds read as before: approved is no readback answer" \
	"$( printf '%s\n' '1700000001.000300 | URIGOWNER | approved' | MDAT_VERDICT_KIND=readback MDAT_VERDICT_AUTHORS="URIGOWNER" LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" | LC_ALL=C tr '\t' '|' )" "RETURNED||"
rigAssert "only the replies after the live proposal reply are read, and every reaction line" \
	"$( printf '%s\n' 'reaction on the question: [reactions: x x1 (URIGOWNER)]' '1700000001.000150 | URIGOWNER | an old comment' 'its second line' '1700000001.000300 | URIGOWNER | a new comment' 'and more' \
		| LC_ALL=C awk -v sinceTs=1700000001.000201 -f "$rigHere/AgentsSlackThreadAnswersSince.awk" | LC_ALL=C tr '\n' '|' )" \
	"reaction on the question: [reactions: x x1 (URIGOWNER)]|1700000001.000300 | URIGOWNER | a new comment|and more|"
## The two readers over one thread rendering, so the marking of a set-aside reply is the one the
## first of them prints: the answers to the question of 1700000001.000101, in a thread it shares
## with a question asked after it and closed since, then what stands after the live proposal
## reply of 1700000002.500000.
rigSinceTag="Q1"
rigSince(){ ## the rendered thread after its first two messages, a line each
	{
		printf '%s\n' '1700000001.000101 | URIGSELF1 | [reactions: x x1 (URIGOWNER)] the question' '1700000001.000120 | URIGSELF1 | another question, asked after it'
		printf '%s\n' "$@"
	} | LC_ALL=C awk -v rootTs=1700000001.000101 -v fromUsers=URIGOWNER -v askingUsers=URIGSELF1 -v tag="$rigSinceTag" -v threadCount=2 -v others='1700000001.000120/1700000001' \
			-f "$rigHere/AgentsDismissalMatch.awk" -f "$rigHere/AgentsSlackThreadAnswers.awk" \
		| LC_ALL=C awk -v sinceTs=1700000002.500000 -f "$rigHere/AgentsSlackThreadAnswersSince.awk" | LC_ALL=C tr '\n' '|'
}
rigOld='1700000002.000100 | URIGOWNER |'
rigLive='1700000002.500000 | URIGSELF1 | the live proposal reply'
rigNew='1700000003.000100 | URIGOWNER |'
rigAssert "the thread reader marks every line of a reply it sets aside" \
	"$( rigSince "$rigNew a new comment" 'its second line' | LC_ALL=C tr '|' '\n' | LC_ALL=C grep -c '^UNMATCHED-REPLY ' )" 2
rigAssert "a set-aside reply of several lines: read whole after the live proposal reply, ignored whole before it" \
	"$( rigSince "$rigOld an old comment" 'its second line' '# its third line' "$rigLive" "$rigNew a new comment" 'its second line' '# its third line' )" \
	"reaction on the question: [reactions: x x1 (URIGOWNER)]|UNMATCHED-REPLY $rigNew a new comment|UNMATCHED-REPLY its second line|UNMATCHED-REPLY # its third line|"
rigAssert "a set-aside reply under a reply that is ignored is still read whole" \
	"$( rigSince "$rigOld Q1 an old numbered comment" 'its second line' "$rigLive" "$rigNew a new comment" 'its second line' )" \
	"reaction on the question: [reactions: x x1 (URIGOWNER)]|UNMATCHED-REPLY $rigNew a new comment|UNMATCHED-REPLY its second line|"
rigAssert "a set-aside reply above a reply that is read is still ignored whole" \
	"$( rigSince "$rigOld an old comment" 'its second line' "$rigLive" "$rigNew Q1 a new numbered comment" 'its second line' )" \
	"reaction on the question: [reactions: x x1 (URIGOWNER)]|$rigNew a new numbered comment|its second line|"
rigAssert "a reply marked on its head line alone, as before, goes the same way with the lines under it" \
	"$( printf '%s\n' "UNMATCHED-REPLY $rigOld an old comment" 'its second line' "UNMATCHED-REPLY $rigNew a new comment" 'its second line' \
		| LC_ALL=C awk -v sinceTs=1700000002.500000 -f "$rigHere/AgentsSlackThreadAnswersSince.awk" | LC_ALL=C tr '\n' '|' )" \
	"UNMATCHED-REPLY $rigNew a new comment|its second line|"
rigSinceTag=""
## A line that reads as one of the thread reader's own marks comes from it one space in (ownLine).
rigAssert "with no reply set aside, as a proposal's own thread reads: a line goes with its reply whatever it starts with" \
	"$( rigSince "$rigOld an old comment" '# its second line' 'reaction on the question: its third line' "$rigLive" "$rigNew a new comment" '# its second line' 'reaction on the question: its third line' )" \
	"reaction on the question: [reactions: x x1 (URIGOWNER)]|$rigNew a new comment|# its second line| reaction on the question: its third line|"

echo "-- posted nothing: a correction for its caller to make --"
rigStart corrections
rigCall 30 ProposeApprove "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"proposal\":\"Retire it.\"}"
rigAssert "no document: a correction, by its first word" "$( rigOpens "$rigScenarioDir/out" "CORRECTION: ProposeApprove: a proposal is put with the link to its document" )" yes
rigAssert "it says how to get a link"                  "$( rigHolds "$rigScenarioDir/out" 'Artifact file=<path> kind=PRO' )" yes
rigCall 30 ProposeApprove "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"proposal\":\"Retire it.\",\"document\":\"PRO-007 in the wiki\"}"
rigAssert "a document that is no link: a correction"   "$( rigOpens "$rigScenarioDir/out" "CORRECTION: ProposeApprove: a proposal is put with the link to its document" )" yes
rigCall 30 ProposeApprove "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"document\":\"$rigLink\"}"
rigAssert "no proposal text: a correction"             "$( rigOpens "$rigScenarioDir/out" "CORRECTION: ProposeApprove: proposal is required and was empty" )" yes
rigCall 30 ProposeApprove "{\"to\":\"CRIG00001:1700000000.000100\",\"address_to\":\"human-owner\",\"question\":\"$rigQuestion\",\"proposal\":\"Retire it.\",\"document\":\"$rigLink\"}"
rigAssert "a thread as to: a correction"               "$( rigOpens "$rigScenarioDir/out" "CORRECTION: ProposeApprove: a proposal opens a thread of its own" )" yes
rigCall 30 ProposeApprove "{$rigPropose,\"address_to\":\"$rigOther\"}"
rigAssert "another addressee than the human-owner: a correction" "$( rigOpens "$rigScenarioDir/out" "CORRECTION: ProposeApprove: a proposal is put to the human-owner" )" yes
rigAs="$rigOther"
rigCall 30 ProposeApprove "{$rigPropose}"
rigAs="$rigMember"
rigAssert "another member than the coordinator: a correction" "$( rigOpens "$rigScenarioDir/out" "CORRECTION: ProposeApprove: only magic-coordinator puts a proposal to the human-owner" )" yes
rigAssert "it names who called, and what to do"        "$( rigHolds "$rigScenarioDir/out" "this call is made as $rigOther. Hand the proposal to magic-coordinator" )" yes
rigCall 30 ProposeApprove "{$rigPropose,\"options\":\"alpha\\nbeta\"}"
rigAssert "ProposeApprove refuses a field of another kind" "$( rigHolds "$rigScenarioDir/out" 'ERROR: ProposeApprove: options is not a parameter of ProposeApprove' )" yes
rigCall 30 AskUserQuestion "{$rigPropose,\"kind\":\"proposal\"}"
rigAssert "the second name puts no proposal"           "$( rigHolds "$rigScenarioDir/out" 'ERROR: AskUserQuestion: a proposal is put with ProposeApprove, its own tool.' )" yes
rigAssert "none of them posted anything"               "$( rigCalls chat.postMessage )" 0
rigAssert "and none left a record"                     "$( rigRecordCount )" 0

echo "-- put: the root, the proposal reply under it, no emoji, and a comment coming back --"
rigStart propose
rigThread 000101 "" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )$( rigMessage 000101 000250 URIGOWNER 'What does it cost us?' )"
rigCall 60 ProposeApprove "{$rigPropose,\"context\":\"The old sync runs nightly.\"}"
rigId="$( rigRecordId )"
rigAssert "it ran to completion"                       "$rigKilled" no
rigAssert "two posts: the root and the proposal"       "$( rigCalls chat.postMessage )" 2
rigAssert "the root is a message of its own"           "$( rigThreadOf "$rigScenarioDir/post.1" )" ""
rigAssert "the root is the question, under its title"  "$( rigHolds "$rigScenarioDir/post.1" "📜 Proposal\\n\\n$rigQuestion" )" yes
rigAssert "the root says nothing of the proposal, its link or how to answer" \
	"$( LC_ALL=C grep -c -e 'example.invalid' -e 'How to answer' -e 'Retire the old sync on Friday\. The new' "$rigScenarioDir/post.1" )" 0
rigAssert "the proposal is a reply under the root"     "$( rigThreadOf "$rigScenarioDir/post.2" )" "1700000001.000101"
rigAssert "it carries the link to its document"        "$( rigHolds "$rigScenarioDir/post.2" "**🔗 Document**\\n$rigLink" )" yes
rigAssert "the proposed form, the context and how to answer" \
	"$( rigHolds "$rigScenarioDir/post.2" 'The new sync covers every case it had.' ):$( rigHolds "$rigScenarioDir/post.2" 'The old sync runs nightly.' ):$( rigHolds "$rigScenarioDir/post.2" '✅ approves the document, ❌ rejects the proposal' )" "yes:yes:yes"
rigAssert "the tooling placed no emoji anywhere"       "$( rigCalls reactions.add )" 0
rigAssert "the comment returns the proposal"           "$( rigVerdictLine )" "VERDICT: RETURNED"
rigAssert "the comment text comes back"                "$( rigHolds "$rigScenarioDir/out" 'What does it cost us?' )" yes
rigAssert "it says this may be a communication"        "$( rigHolds "$rigScenarioDir/out" 'This may be a communication and not a rejection: a request to explain, a correction, or an instruction.' )" yes
rigAssert "explain, with its call"                     "$( rigHolds "$rigScenarioDir/out" '- explain: SendMessage to=CRIG00001:1700000001.000101 message=<your explanation>, then Wait mode=continue.' )" yes
rigAssert "update, with its call"                      "$( rigHolds "$rigScenarioDir/out" "- update: ProposeApprove pending_id=$rigId revise=true with the fields you change. The proposal reply is replaced" )" yes
rigAssert "discard, with its call"                     "$( rigHolds "$rigScenarioDir/out" "- discard: ProposeApprove pending_id=$rigId withdraw=<why>." )" yes
rigAssert "no readback is offered"                     "$( rigHolds "$rigScenarioDir/out" 'take it as the answer' )" no
rigAssert "the last line is the re-wait call"          "$( LC_ALL=C awk 'END { print ; }' "$rigScenarioDir/out" )" "ProposeApprove pending_id=$rigId"
rigAssert "one record, of its own kind, still open"    "$( rigRecordCount ):$( rigRecordField kind ):$( rigRecordField status )" "1:proposal:reply-pending"
rigAssert "the root is where it is answered"           "$( rigRecordField question-ts ):$( rigRecordField thread-ts )" "1700000001.000101:1700000001.000101"
rigAssert "the proposal reply is its live version"     "$( rigRecordField revision-ts )" "1700000001.000201"
rigAssert "it is addressed to the human-owner"         "$( rigRecordField address-to ):$( rigRecordField addressees )" "human-owner:URIGOWNER"
rigAssert "the record keeps the question first, then the proposal" \
	"$( LC_ALL=C awk 'body && NF && $0 !~ /^#/ { print ; exit ; } /^# Question asked$/ { body = 1 ; }' "$( rigRecordFile )" ):$( rigHolds "$( rigRecordFile )" "$rigLink" )" "$rigQuestion:yes"
rigAssert "the comment is kept on the record"          "$( rigHolds "$( rigRecordFile )" 'What does it cost us?' )" yes

echo "-- changed: the reply before is removed, the changed one posted, the root never touched --"
## The thread as it reads once the changed proposal is in it: the third post.
rigThread 000101 "" "$( rigMessage 000101 000250 URIGOWNER 'What does it cost us?' )$( rigMessage 000101 000301 URIGSELF1 'the changed proposal' )"
rigCall 8 ProposeApprove "{\"pending_id\":\"$rigId\",\"revise\":true,\"proposal\":\"Retire the old sync on Friday. It costs one hour of work.\"}" from-read
rigAssert "the changed proposal is posted and waits"   "$rigKilled" yes
rigAssert "it is a reply under the same root"          "$( rigThreadOf "$rigScenarioDir/post.3" )" "1700000001.000101"
rigAssert "it carries the changed text and the same link" "$( rigHolds "$rigScenarioDir/post.3" 'It costs one hour of work.' ):$( rigHolds "$rigScenarioDir/post.3" "$rigLink" )" "yes:yes"
rigAssert "its title carries no mark"                  "$( rigHolds "$rigScenarioDir/post.3" 'updated' )" no
rigAssert "the reply before it is removed"             "$( cat "$rigScenarioDir/deleted" 2>/dev/null | tr '\n' ' ' )" "1700000001.000201 "
rigAssert "the comment before it is not given back again" "$( rigHolds "$rigScenarioDir/out" 'VERDICT: RETURNED' )" no
rigAssert "the same record, now at its changed reply"  "$( rigRecordCount ):$( rigRecordId ):$( rigRecordField revision-ts ):$( rigRecordField revisions )" "1:$rigId:1700000001.000301:1"
## The second change gives another document.
rigThread 000101 "" "$( rigMessage 000101 000250 URIGOWNER 'What does it cost us?' )$( rigMessage 000101 000401 URIGSELF1 'the changed proposal' )"
rigCall 8 ProposeApprove "{\"pending_id\":\"$rigId\",\"revise\":true,\"document\":\"$rigLinkTwo\"}" from-read
rigAssert "the second change is posted and waits"      "$rigKilled" yes
rigAssert "it carries the other link, and the text of the first change" "$( rigHolds "$rigScenarioDir/post.4" "$rigLinkTwo" ):$( rigHolds "$rigScenarioDir/post.4" 'It costs one hour of work.' )" "yes:yes"
rigAssert "one proposal reply is live: both before it are removed" "$( cat "$rigScenarioDir/deleted" 2>/dev/null | tr '\n' ' ' )" "1700000001.000201 1700000001.000301 "
rigAssert "the record: its second change"              "$( rigRecordField revision-ts ):$( rigRecordField revisions ):$( LC_ALL=C grep -c '^## Revision ' "$( rigRecordFile )" )" "1700000001.000401:2:2"
rigCall 30 ProposeApprove "{\"pending_id\":\"$rigId\",\"revise\":true,\"question\":\"Another question?\"}"
rigAssert "a change takes no question: a correction"   "$( rigOpens "$rigScenarioDir/out" "CORRECTION: ProposeApprove: the question of a proposal is the root of its thread" )" yes
rigAssert "which posted nothing"                       "$( rigCalls chat.postMessage )" 4

echo "-- approved: his own check mark on the root --"
rigThread 000101 "$( rigReactions "$rigOwner" white_check_mark )" "$( rigMessage 000101 000250 URIGOWNER 'What does it cost us?' )$( rigMessage 000101 000401 URIGSELF1 'the changed proposal' )"
rigCall 60 ProposeApprove "{\"pending_id\":\"$rigId\"}"
rigAssert "the wait ran to its answer"                 "$rigKilled" no
rigAssert "the result opens with RECEIVED"             "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: RECEIVED"
rigAssert "the verdict is approved"                    "$( rigVerdictLine )" "VERDICT: approved"
rigAssert "it names who approved"                      "$( rigHolds "$rigScenarioDir/out" 'ANSWERED-BY: URIGOWNER' )" yes
rigAssert "the record closes with it"                  "$( rigRecordField status ):$( rigRecordField verdict ):$( rigRecordField answered-by )" "reply-received:approved:URIGOWNER"
rigAssert "the wait posts nothing itself: its one post is the confirmation reply of the answer it applied" \
	"$( rigCalls chat.postMessage ):$( LC_ALL=C grep -c -F 'Read: `approved` by' "$rigScenarioDir/post.5" 2>/dev/null )" "5:1"
rigAssert "the tooling never reacted, on the root or anywhere" "$( rigCalls reactions.add ):$( rigCalls reactions.remove )" "0:0"
rigAssert "the root was never edited or removed"       "$( rigCalls chat.update ):$( LC_ALL=C grep -c -x '1700000001.000101' "$rigScenarioDir/deleted" )" "0:0"

echo "-- a change once a verdict is on the root: nothing posted, the verdict given back --"
rigCall 30 ProposeApprove "{\"pending_id\":\"$rigId\",\"revise\":true,\"proposal\":\"Retire it a week later.\"}"
rigAssert "a correction, by its first word"            "$( rigOpens "$rigScenarioDir/out" "CORRECTION: ProposeApprove: the root of this proposal already carries its verdict" )" yes
rigAssert "with the verdict"                           "$( rigVerdictLine ):$( rigHolds "$rigScenarioDir/out" 'ANSWERED-BY: URIGOWNER' )" "VERDICT: approved:yes"
rigAssert "nothing was posted, and nothing removed"    "$( rigCalls chat.postMessage ):$( LC_ALL=C grep -c . "$rigScenarioDir/deleted" )" "5:2"
rigStart verdict-first
rigThread 000101 "" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 8 ProposeApprove "{$rigPropose}" from-read
rigAssert "put, and nobody answers yet"                "$rigKilled:$( rigRecordField status )" "yes:reply-pending"
rigId="$( rigRecordId )"
## He approves while nobody waits, and the change comes after it.
rigThread 000101 "$( rigReactions "$rigOwner" white_check_mark )" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 30 ProposeApprove "{\"pending_id\":\"$rigId\",\"revise\":true,\"proposal\":\"Retire it a week later.\"}"
rigAssert "the root is read before a change is posted" "$( rigOpens "$rigScenarioDir/out" "CORRECTION: ProposeApprove: the root of this proposal already carries its verdict" )" yes
rigAssert "the verdict found there is given back"      "$( rigVerdictLine )" "VERDICT: approved"
rigAssert "and is the verdict of the record"           "$( rigRecordField status ):$( rigRecordField verdict )" "reply-received:approved"
rigAssert "the change was not posted, the reply not removed: the one post is the confirmation of the verdict read" \
	"$( rigCalls chat.postMessage ):$( rigCalls chat.delete ):$( LC_ALL=C grep -c -F 'Read: `approved` by' "$rigScenarioDir/post.3" 2>/dev/null )" "3:0:1"

echo "-- rejected: the cross on the root, or the word in a reply --"
rigStart reject-click
rigThread 000101 "$( rigReactions "$rigOwner" x )" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 60 ProposeApprove "{$rigPropose}"
rigAssert "the cross on the root rejects"              "$rigKilled:$( rigVerdictLine )" "no:VERDICT: rejected"
rigAssert "the record closes with it"                  "$( rigRecordField status ):$( rigRecordField verdict )" "reply-received:rejected"
rigAssert "no emoji was placed"                        "$( rigCalls reactions.add )" 0
rigStart reject-reply
rigThread 000101 "" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )$( rigMessage 000101 000250 URIGOWNER 'rejected: the new sync is not proven yet' )"
rigCall 60 ProposeApprove "{$rigPropose}"
rigAssert "the word in a reply rejects"                "$rigKilled:$( rigVerdictLine )" "no:VERDICT: rejected"
rigAssert "the rest of its line is the verdict text"   "$( rigHolds "$rigScenarioDir/out" 'VERDICT-TEXT: the new sync is not proven yet' )" yes
rigAssert "no mark is put on the root at the close"    "$( rigReacted reactions 000101 )" ""
rigStart approve-reply
rigThread 000101 "" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )$( rigMessage 000101 000250 URIGOWNER 'Approved.' )"
rigCall 60 ProposeApprove "{$rigPropose}"
rigAssert "the word in a reply approves"               "$rigKilled:$( rigVerdictLine )" "no:VERDICT: approved"

echo "-- only his own click on the root is a verdict --"
rigStart click-under-reply
rigThread 000101 "" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' "$( rigReactions "$rigOwner" white_check_mark )" )"
rigCall 6 ProposeApprove "{$rigPropose}" from-read
rigAssert "a check mark under the proposal reply is no verdict" "$rigKilled:$( rigRecordField status )" "yes:reply-pending"
rigAssert "and nothing came back as an answer"         "$( rigHolds "$rigScenarioDir/out" 'VERDICT:' )" no
rigStart click-by-others
rigThread 000101 "$( rigReactions "$rigSelf" white_check_mark )$( : )" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 6 ProposeApprove "{$rigPropose}" from-read
rigAssert "a check mark by the asking account is no verdict" "$rigKilled:$( rigRecordField status )" "yes:reply-pending"
rigThread 000101 "$( rigReactions "$rigStranger" white_check_mark )" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 6 ProposeApprove "{\"pending_id\":\"$( rigRecordId )\"}" from-read
rigAssert "a check mark by anyone else is no verdict"  "$rigKilled:$( rigRecordField status )" "yes:reply-pending"
rigStart thumbs-up
rigThread 000101 "$( rigReactions "$rigOwner" +1 )" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 60 ProposeApprove "{$rigPropose}"
rigAssert "his thumbs up approves nothing: it comes back" "$rigKilled:$( rigVerdictLine ):$( rigRecordField status )" "no:VERDICT: RETURNED:reply-pending"

echo "-- a comment of several lines: read whole after the live proposal reply, ignored whole before it --"
rigStart comment-lines
rigComment='What does it cost us?\n# In hours\nand who pays'
rigThread 000101 "" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )$( rigMessage 000101 000250 URIGOWNER "$rigComment" )"
rigCall 60 ProposeApprove "{$rigPropose}"
rigAssert "it comes back as one returned comment"      "$rigKilled:$( rigVerdictLine )" "no:VERDICT: RETURNED"
rigAssert "whole: its every line, one that starts with a heading mark too" \
	"$( rigHolds "$rigScenarioDir/out" $'URIGOWNER | What does it cost us?\n# In hours\nand who pays' )" yes
rigId="$( rigRecordId )"
## The proposal is changed from it, so the comment now stands before the live proposal reply.
rigThread 000101 "" "$( rigMessage 000101 000250 URIGOWNER "$rigComment" )$( rigMessage 000101 000301 URIGSELF1 'the changed proposal' )"
rigCall 8 ProposeApprove "{\"pending_id\":\"$rigId\",\"revise\":true,\"proposal\":\"Retire the old sync on Friday. It costs one hour of work.\"}" from-read
rigAssert "before the changed proposal it is ignored whole: no line of it arrives, and the wait goes on" \
	"$rigKilled:$( rigHolds "$rigScenarioDir/out" 'In hours' ):$( rigHolds "$rigScenarioDir/out" 'who pays' ):$( rigHolds "$rigScenarioDir/out" 'VERDICT' ):$( rigRecordField status )" "yes:no:no:no:reply-pending"

echo "-- to the human-owner by default, and never answered by an earlier verdict --"
rigStart default-to
rigThread 000101 "$( rigReactions "$rigOwner" white_check_mark )" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 60 ProposeApprove "{\"question\":\"$rigQuestion\",\"proposal\":\"Retire it.\",\"document\":\"$rigLink\"}"
rigAssert "with no to it is put to the human-owner"    "$rigKilled:$( rigVerdictLine ):$( rigRecordField communication-channel-id ):$( rigRecordField address-to )" "no:VERDICT: approved:slack:human-owner:human-owner"
## The same question again, for another document: the earlier approval is not its answer.
## The third post is the confirmation reply of the first approval, so the new root is the fourth.
rigThread 000401 "" "$( rigMessage 000401 000501 URIGSELF1 'the proposal' )"
rigCall 8 ProposeApprove "{\"question\":\"$rigQuestion\",\"proposal\":\"Retire it.\",\"document\":\"$rigLinkTwo\"}" from-read
rigAssert "the same question for another document is put anew" "$rigKilled:$( rigCalls chat.postMessage ):$( rigRecordCount )" "yes:5:2"
rigAssert "in a thread of its own"                     "$( rigThreadOf "$rigScenarioDir/post.4" ):$( rigThreadOf "$rigScenarioDir/post.5" )" ":1700000001.000401"
rigAssert "no earlier verdict is given for it"         "$( rigHolds "$rigScenarioDir/out" 'NOT ASKED AGAIN' )" no

echo "-- discarded: the proposal reply marked and closed, the root left as it is --"
rigStart discard
rigThread 000101 "" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 8 ProposeApprove "{$rigPropose}" from-read
rigId="$( rigRecordId )"
rigCall 60 ProposeApprove "{\"pending_id\":\"$rigId\",\"withdraw\":\"superseded by a wider proposal\"}"
rigAssert "it is withdrawn"                            "$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigRecordField status )" "no:ASK-RESULT: WITHDRAWN:withdrawn"
rigAssert "the note is said in its thread"             "$( rigThreadOf "$rigScenarioDir/post.3" ):$( rigHolds "$rigScenarioDir/post.3" 'superseded by a wider proposal' )" "1700000001.000101:yes"
rigAssert "the proposal reply gets the cancelled mark" "$( rigReacted reactions 000201 )" "no_entry_sign"
rigAssert "and is edited to its text without How to answer" "$( rigEditShape "$rigScenarioDir/edit.1700000001.000201" 1700000001.000201 ):$( rigHolds "$rigScenarioDir/edit.1700000001.000201" "$rigLink" )" "1:1:0:yes"
rigAssert "the root is not marked, edited or removed"  "$( rigReacted reactions 000101 ):$( ls "$rigScenarioDir" | LC_ALL=C grep -c -x 'edit.1700000001.000101' ):$( rigCalls chat.delete )" ":0:0"

echo "-- the verdict on the tracking item, with the link to the document --"
rigStart decisions
rigItem="proposal-20300101T0000Z-retire-old-sync"
mkdir -p "$rigScenarioDir/data/board/running"
printf -- '---\ntype: proposal\nowner: %s\n---\n\n# Retire the old sync\n' "$rigMember" > "$rigScenarioDir/data/board/running/$rigItem.md"
rigThread 000101 "$( rigReactions "$rigOwner" white_check_mark )" "$( rigMessage 000101 000201 URIGSELF1 'the proposal' )"
rigCall 60 ProposeApprove "{$rigPropose,\"task_ref\":\"$rigItem\"}"
rigAssert "approved, and the record names its item"    "$rigKilled:$( rigVerdictLine ):$( rigRecordField item )" "no:VERDICT: approved:$rigItem"
rigAssert "the item's Decisions keep the verdict with the link, and who gave it" \
	"$( LC_ALL=C grep '^- ' "$rigScenarioDir/data/board/running/$rigItem.md" | LC_ALL=C sed 's/^- [^ ]* //' )" "URIGOWNER verdict: $rigQuestion -> approved (document: $rigLink) ($( rigRecordId ))"
rigAssert "the tracking item is not shown in the post: the document is what is approved" "$( LC_ALL=C grep -c -F "$rigItem" "$rigScenarioDir/post.1" "$rigScenarioDir/post.2" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/[^ ]*://g' )" "0 0 "

echo "-- declared and served as the other tools that ask --"
rigWire="$rigHere/AgentsOpenAiChatWire.sh"
rigDeclared="$( LC_ALL=C grep -F '{"type":"function","function":{"name":"ProposeApprove",' "$rigWire" )"
rigAssert "the wire declares it once"                  "$( printf '%s\n' "$rigDeclared" | LC_ALL=C grep -c . )" 1
for rigField in to question proposal document task_ref context address_to as_bot pending_id revise withdraw description ; do
	rigAssert "its declaration carries '$rigField'"       "$( printf '%s' "$rigDeclared" | LC_ALL=C grep -c -F "\"$rigField\":{\"type\":" )" 1
done
rigAssert "and no field of another kind"               "$( printf '%s' "$rigDeclared" | LC_ALL=C grep -c -e '"kind":{' -e '"options":{' -e '"select":{' -e '"readback":{' -e '"refusal_id":{' )" 0
rigAssert "the tools JSON holds no apostrophe"         "$( LC_ALL=C awk -v q="'" 'index( $0, "harnessToolsJson=" q ) == 1 { on = 1 ; next ; } on && $0 == "]" q { exit ; } on && index( $0, q ) { hits++ ; } END { print hits + 0 ; }' "$rigWire" )" 0
rigAssert "the served list is rendered from it"        "$( bash "$rigHere/AgentsHarnessMcpMirror.sh" 2>/dev/null | LC_ALL=C grep -c -F '{"name":"ProposeApprove","description":"Put one proposal to the human-owner' )" 1
rigAssert "declared, announced, dispatched and defined: the four sites agree" \
	"$( LC_ALL=C awk -f "$rigTest/AgentsHarnessSelfCheck.test.awk" "$rigWire" "$rigHarness" > /dev/null 2>&1 ; printf '%s' "$?" )" 0
. "$rigHere/AgentsTools.AskPost.include"
rigAssert "the table names it, with its kind, template and own parameters" \
	"$( AgentsToolsAskToolRow mcp__myx_distro__ProposeApprove && printf '%s|%s|%s|%s|%s' "$agentsAskRowName" "$agentsAskRowKind" "$agentsAskRowTemplate" "$agentsAskRowForm" "$agentsAskRowArgs" )" \
	"ProposeApprove|proposal|propose-approve.post.format.md|approve|question proposal document task_ref"
rigAssert "it is a tool of the team floor"             "$( LC_ALL=C grep -c -E '^agentsPermissionFloorTools=".* ProposeApprove .*"$' "$rigHere/AgentsTools.PermissionHolds.include" )" 1

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PROPOSE APPROVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_PROPOSE_APPROVE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
