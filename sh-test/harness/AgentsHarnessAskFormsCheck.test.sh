#!/usr/bin/env bash
## Behavioural check on the tools that ask -- AskQuestion, ConfirmReadback, EscalateDecision,
## and RequestPermission -- run through --intern-tool, the
## path the myx.distro MCP uses. Covers: each post filled from its tool's own template; the
## answer forms (free text, yes-no, one, many) answered by click and by reply; the answer emoji
## placed under a post and never counted as an answer; a reply that names none of the answers
## coming back as VERDICT: RETURNED with the ways on; the same question asked again, changed
## (revise), in its own thread, inside another thread and in one that numbered questions
## share; a readback closing a question with an answer form; a discarded question's post, and
## the edit of it asked of the send; a permission by click; what became of a refusal said in
## the session's one event-track thread; and the word
## UNCLASSIFIED of a read from before still taken as RETURNED.
## Offline: a Slack-shaped fake curl is first on PATH, and every scenario runs in its own
## workspace under this check's temp tree, in $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessAskFormsCheck.XXXXXX" )" || exit 1
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
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}
rigVerdictLine(){
	LC_ALL=C awk '/^VERDICT: / { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-verdict-line" ; } }' "$rigScenarioDir/out"
}
rigRecordFile(){
	local recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md "$rigScenarioDir/ws/.local/agents/pending/closed"/*.md ; do
		[ -f "$recordFile" ] && { printf '%s' "$recordFile" ; return 0 ; }
	done
	printf '%s' "$rigScenarioDir/no-record"
}
rigRecordCount(){
	local recordCount=0 recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md "$rigScenarioDir/ws/.local/agents/pending/closed"/*.md ; do
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

## The text a post, or an edit of one, carries: the JSON string of its body, as sent.
rigTextOf(){ ## body file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk '{ at = index( $0, "\"text\":\"" ) ; if ( ! at ) { next ; } rest = substr( $0, at + 8 ) ; end = 0 ; marks[1] = "\",\"thread_ts\":" ; marks[2] = "\",\"ts\":" ; marks[3] = "\",\"blocks\":" ; for ( markNo = 1 ; markNo <= 3 ; markNo++ ) { markAt = index( rest, marks[markNo] ) ; if ( markAt > 0 && ( end == 0 || markAt < end ) ) { end = markAt ; } } if ( end > 0 ) { print substr( rest, 1, end - 1 ) ; } exit ; }' "$1"
}
## What an edit must carry: the text the post was sent with, less its How to answer part. Of a
## permission the line that names its refusal stands after that part, and stays.
rigClosedOf(){ ## the body file of the post
	rigTextOf "$1" | LC_ALL=C sed -e 's/\\n\\n\*\*✅ How to answer\*\*.*\(\\n\\n_Refusal:_ .*\)$/\1/' -e 's/\\n\\n\*\*✅ How to answer\*\*.*$//'
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
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/IN" "$rigScenarioDir/ws/OUT"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
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
rigReactions(){ ## users (a JSON list body), reaction names...
	local reactUsers="$1" reactOut="" reactName
	shift
	for reactName in "$@" ; do
		reactOut="$reactOut${reactOut:+,}{\"name\":\"$reactName\",\"count\":2,\"users\":[$reactUsers]}"
	done
	printf ',"reactions":[%s]' "$reactOut"
}
rigMessage(){ ## ts suffix, user, text, optional extra fields
	printf ',{"ts":"1700000001.%s","user":"%s","text":"%s","thread_ts":"1700000001.000101"%s}' "$1" "$2" "$3" "${4:-}"
}

## One served call of a tool. A question nobody answers is re-waited without end by design,
## so the guard is the scenario's: a killed run is reported as such, never as a result. With
## from-read the guard counts from the first thread read this call makes.
rigKilled=""
rigCall(){ ## guard seconds, tool, argument object, optional from-read
	local callPid callLeft callStartLeft=120 callReads
	rigKilled="no"
	callReads="$( rigCalls conversations.replies )"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SPAWN_SESSION_ID="rig-forms-$rigScenarioName" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
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
	ASKP_WANT="$1" ASKP_FORM="$3" LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsToolingTemplateFill.awk" -f "$rigHere/questions/AgentsAskPostFill.awk" "$rigHere/templates/$2" 2>&1
}

rigAsk='"to":"magic-team","address_to":"URIGOWNER"'
rigOptions='"options":"alpha -- the unit checks\nbeta -- the lint\ngamma -- the smoke run"'

echo "-- each tool's post, from its own template --"
rigAssert "a free-text question: no emoji line, plain options, the rest as before" \
	"$( ASKP_F_question='Which way?' ASKP_OPTIONS=$'alpha -- a\n- beta -- b' ASKP_F_context='ctx' rigFill post ask-question.post.format.md text )" \
	$'# ❓ Question\n\nWhich way?\n\n**📋 Options**\n- alpha -- a\n- beta -- b\n\n**⚙ Context**\nctx\n\n**✅ How to answer**\n- reply in this thread'
rigAssert "a readback: the same body as before" \
	"$( ASKP_F_tag=Q2 ASKP_F_question='Right?' ASKP_F_understood=U ASKP_F_source=S ASKP_F_will_do=W rigFill post confirm-readback.post.format.md confirm )" \
	$'# 🔁 Readback Q2\n\nRight?\n\n**📥 What I understood**\nU\n\n**📎 Where it came from**\nS\n\n**▶️ What I will do if confirmed**\nW\n\n**✅ How to answer**\n- click 👍 to confirm or ❌ to stop\n- or reply `yes` (or `ok`, `agreed`, `confirm`), `no`, or `correct:` followed by the correction\n- the word first; a comment after a comma, or on the next lines'
rigAssert "a decision: its options numbered, the recommended line kept" \
	"$( ASKP_F_question='Pick' ASKP_OPTIONS=$'alpha -- a\nbeta -- b (recommended)' rigFill post escalate-decision.post.format.md one )" \
	$'# 🧭 Decision\n\nPick\n\n**📋 Options**\n- 1️⃣ alpha -- a\n- 2️⃣ beta -- b (recommended)\n\n**✅ How to answer**\n- click the number of your choice\n- or reply with its number, or with the first word of the option\n- the word first; a comment after a comma, or on the next lines\n- or reply `ok` (or add 👍) to take the recommended option'
rigAssert "a permission: its first line made from the refused call, the asker's words under the reason, the clicks named first, and last the refusal by its id, each said once" \
	"$( ASKP_F_question='May I?' ASKP_F_refused_tool=Write ASKP_F_refused_target=/x ASKP_F_refused_for=me ASKP_F_refusal_id=refusal-1 ASKP_F_reason=why ASKP_F_task=t rigFill post request-permission.post.format.md grant )" \
	$'# 🔐 Permission\n\nAllow **Write** on `/x` for **me**? An allow grants exactly that, and nothing wider.\n\n**💡 Why this task needs it**\nMay I?\nwhy\n\n**🗂 Task**\nt\n\n**✅ How to answer**\n- click ❌ to deny, 1️⃣ to allow once, or 🔁 to allow for this session\n- or reply `deny`, `allow-once` or `allow-session`\n- the word first; a comment after a comma, or on the next lines\n\n_Refusal:_ `refusal-1`'
rigAssert "yes-no: its two answers" \
	"$( ASKP_F_question='Go?' rigFill post ask-question.post.format.md yes-no | tail -n 4 )" \
	$'**✅ How to answer**\n- click 👍 for yes or ❌ for no\n- or reply `yes` or `no`\n- the word first; a comment after a comma, or on the next lines'
rigAssert "one: its options numbered, how to choose one" \
	"$( ASKP_F_question='Which?' ASKP_OPTIONS=$'a\nb' rigFill post ask-question.post.format.md one | tail -n 7 )" \
	$'- 1️⃣ a\n- 2️⃣ b\n\n**✅ How to answer**\n- click the number of your choice\n- or reply with its number, or with the first word of the option\n- the word first; a comment after a comma, or on the next lines'
rigAssert "many: past the tenth an option has a plain number" \
	"$( ASKP_F_question='Which?' ASKP_OPTIONS=$'a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk' rigFill post ask-question.post.format.md many | LC_ALL=C sed -n '15,20p' )" \
	$'- 🔟 j\n- 11. k\n\n**✅ How to answer**\n- click each number you choose, then 🆗 to send\n- or reply with the numbers or first words, separated by spaces or commas, for example `1 3`'
rigAssert "many: the emoji placed stop at the tenth, then the OK mark that sends" \
	"$( ASKP_OPTIONS=$'a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk' rigFill reactions ask-question.post.format.md many | tr '\n' ' ' )" \
	"one two three four five six seven eight nine keycap_ten ok "
rigAssert "many: its post names no check mark, the mark of an answered question" \
	"$( ASKP_F_question='Which?' ASKP_OPTIONS=$'a\nb' rigFill post ask-question.post.format.md many | LC_ALL=C sed -n '/How to answer/,$p' | LC_ALL=C grep -c -e '✅ to send' -e 'white_check_mark' )" 0
rigAssert "an optional field with no value leaves its heading out" \
	"$( ASKP_F_question='Go?' rigFill post ask-question.post.format.md text | LC_ALL=C grep -c -e 'Options' -e 'Context' )" 0
rigAssert "a required slot with no value refuses the fill" \
	"$( ASKP_F_question='Right?' ASKP_F_understood=U ASKP_F_source=S rigFill post confirm-readback.post.format.md confirm )" \
	"AgentsAskPostFill.awk: the slot {{will-do}} is required and has no value"
rigAssert "a post that takes no answer any more: the same text without How to answer" \
	"$( ASKP_F_question='Which way?' ASKP_OPTIONS=$'alpha -- a\nbeta -- b' ASKP_F_context='ctx' rigFill closed ask-question.post.format.md one )" \
	$'# ❓ Question\n\nWhich way?\n\n**📋 Options**\n- 1️⃣ alpha -- a\n- 2️⃣ beta -- b\n\n**⚙ Context**\nctx'

echo "-- refused before anything is sent --"
rigStart refusals
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"Which check?\",\"select\":\"one\"}"
rigAssert "select one with no options is refused"      "$( rigHolds "$rigScenarioDir/out" 'ERROR: AskQuestion: select one needs options' )" yes
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"Go on?\",\"select\":\"yes-no\",$rigOptions}"
rigAssert "select yes-no with options is refused"      "$( rigHolds "$rigScenarioDir/out" 'ERROR: AskQuestion: select yes-no takes no options' )" yes
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"Go on?\",\"select\":\"poll\"}"
rigAssert "an unknown select is refused"               "$( rigHolds "$rigScenarioDir/out" 'select must be yes-no, one or many' )" yes
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"Go on?\",\"refusal_id\":\"refusal-0\"}"
rigAssert "AskQuestion refuses a permission's own parameter" "$( rigHolds "$rigScenarioDir/out" 'ERROR: AskQuestion: refusal_id is not a parameter of AskQuestion' )" yes
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"Go on?\",\"kind\":\"decision\"}"
rigAssert "AskQuestion takes no kind: its name sets it" "$( rigHolds "$rigScenarioDir/out" 'ERROR: AskQuestion: kind is not a parameter of AskQuestion' )" yes
rigCall 30 ConfirmReadback "{$rigAsk,\"question\":\"Right?\",\"understood\":\"u\",\"source\":\"s\",\"will_do\":\"w\",$rigOptions}"
rigAssert "ConfirmReadback refuses options"            "$( rigHolds "$rigScenarioDir/out" 'ERROR: ConfirmReadback: options is not a parameter of ConfirmReadback' )" yes
rigCall 30 ConfirmReadback "{$rigAsk,\"question\":\"Right?\",\"understood\":\"u\",\"source\":\"s\"}"
rigAssert "ConfirmReadback needs its three fields"     "$( rigHolds "$rigScenarioDir/out" 'ERROR: ConfirmReadback: kind readback needs understood, source and will_do' )" yes
rigCall 30 EscalateDecision "{$rigAsk,\"question\":\"Which?\",$rigOptions,\"select\":\"many\"}"
rigAssert "EscalateDecision refuses select"            "$( rigHolds "$rigScenarioDir/out" 'ERROR: EscalateDecision: select is not a parameter of EscalateDecision' )" yes
rigCall 30 EscalateDecision "{$rigAsk,\"question\":\"Which?\"}"
rigAssert "EscalateDecision needs options"             "$( rigHolds "$rigScenarioDir/out" 'ERROR: EscalateDecision: kind decision needs options' )" yes
rigCall 30 RequestPermission "{$rigAsk,\"question\":\"May I?\",\"refusal_id\":\"refusal-0\",\"reason\":\"r\",\"task_ref\":\"t\",\"understood\":\"u\"}"
rigAssert "RequestPermission refuses a readback's own parameter" "$( rigHolds "$rigScenarioDir/out" 'ERROR: RequestPermission: understood is not a parameter of RequestPermission' )" yes
rigCall 30 RequestPermission "{$rigAsk,\"question\":\"May I?\",\"refusal_id\":\"refusal-0\",\"reason\":\"r\",\"task_ref\":\"t\"}"
rigAssert "RequestPermission needs a recorded refusal" "$( rigHolds "$rigScenarioDir/out" 'ERROR: RequestPermission: no refusal refusal-0 is recorded' )" yes
rigAssert "none of them posted anything"               "$( rigCalls chat.postMessage )" 0
rigAssert "and none left a record"                     "$( rigRecordCount )" 0

echo "-- yes-no: the emoji placed, a click, a reply, and the placed emoji never an answer --"
rigStart yes-no-click
rigThread 000101 "$( rigReactions "$rigBoth" +1 )$( : )" ""
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Should the rig go on?\",\"select\":\"yes-no\"}"
rigAssert "it ran to completion"                       "$rigKilled" no
rigAssert "the result opens with RECEIVED"             "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: RECEIVED"
rigAssert "the click is the verdict"                   "$( rigVerdictLine )" "VERDICT: yes"
rigAssert "the thumbs up and the cross were placed under the question first" "$( rigReacted reactions 000101 | cut -d' ' -f1-2 )" "+1 x"
rigAssert "the post says how to answer yes or no"      "$( rigHolds "$rigScenarioDir/post.1" 'click 👍 for yes or ❌ for no' )" yes
rigAssert "the record keeps the form"                  "$( rigRecordField select )" yes-no
rigAssert "and closes with the verdict"                "$( rigRecordField verdict )" yes
rigStart yes-no-seeded-only
rigThread 000101 "$( rigReactions "$rigSelf" +1 x )" ""
rigCall 6 AskQuestion "{$rigAsk,\"question\":\"Should the rig go on?\",\"select\":\"yes-no\"}" from-read
rigAssert "the placed emoji alone answer nothing: it is still waiting" "$rigKilled" yes
rigAssert "the thread was read, so it was the wait"    "$( [ "$( rigCalls conversations.replies )" -ge 1 ] && printf yes || printf no )" yes
rigAssert "and the record stays open"                  "$( rigRecordField status )" reply-pending
rigStart yes-no-reply
rigThread 000101 "$( rigReactions "$rigSelf" +1 x )" "$( rigMessage 000200 URIGOWNER 'No, not yet.' )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Should the rig go on?\",\"select\":\"yes-no\"}"
rigAssert "a reply of no is the verdict"               "$( rigVerdictLine )" "VERDICT: no"
rigStart reaction-refused
: > "$rigScenarioDir/react-refuse"
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'ok' )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Should the rig go on?\",\"select\":\"yes-no\"}"
rigAssert "a refused reaction never fails the ask"     "$( rigVerdictLine )" "VERDICT: yes"
rigAssert "and it is logged"                           "$( LC_ALL=C grep -c 'could not be added on CRIG00001:1700000001.000101' "$rigScenarioDir/err" )" 2

rigStart yes-no-by-wait
rigThread 000101 "$( rigReactions "$rigBoth" x )" ""
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"Should the rig go on?\",\"select\":\"yes-no\",\"wait\":false}"
rigAssert "posted with no wait, the form is on its record" "$( rigFirstLine "$rigScenarioDir/out" ):$( rigRecordField select )" "ASK-RESULT: POSTED:yes-no"
rigCall 60 Wait "{\"sources\":\"ask:$( rigRecordId )\",\"timeout\":5}"
rigAssert "a Wait on its ask source takes the click as the asking call would" "$( rigVerdictLine ):$( rigRecordField verdict )" "VERDICT: no:no"

echo "-- one: a number click, a number reply, the first word --"
rigStart one-click
rigThread 000101 "$( rigReactions "$rigSelf" one three )$( : )" ""
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"first","reactions":[{"name":"one","count":1,"users":[%s]},{"name":"two","count":2,"users":[%s]},{"name":"three","count":1,"users":[%s]}]}],"has_more":false}\n' "$rigSelf" "$rigBoth" "$rigSelf" > "$rigScenarioDir/replies.json"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",\"select\":\"one\",$rigOptions}"
rigAssert "the number clicked is the option"           "$( rigVerdictLine )" "VERDICT: beta"
rigAssert "the three numbers were placed under it"     "$( rigReacted reactions 000101 | cut -d' ' -f1-3 )" "one two three"
rigAssert "the post numbers its options"               "$( rigHolds "$rigScenarioDir/post.1" '- 2️⃣ beta -- the lint' )" yes
rigStart one-number-reply
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER '3.' )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",\"select\":\"one\",$rigOptions}"
rigAssert "a number replied is the option"             "$( rigVerdictLine )" "VERDICT: gamma"
rigStart one-word-reply
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'Alpha, please' )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",\"select\":\"one\",$rigOptions}"
rigAssert "the first word replied is the option"       "$( rigVerdictLine )" "VERDICT: alpha"

echo "-- many: sent by the OK mark, or by a reply --"
rigStart many-not-sent
rigThread 000101 "$( rigReactions "$rigBoth" one three )" ""
rigCall 6 AskQuestion "{$rigAsk,\"question\":\"Which checks?\",\"select\":\"many\",$rigOptions}" from-read
rigAssert "numbers with no OK mark are not sent: it is still waiting" "$rigKilled" yes
rigAssert "no result line was produced"                "$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT:' )" no
rigAssert "the record stays open"                      "$( rigRecordField status )" reply-pending
rigStart many-check-alone
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"first","reactions":[{"name":"one","count":1,"users":[%s]},{"name":"ok","count":2,"users":[%s]}]}],"has_more":false}\n' "$rigSelf" "$rigBoth" > "$rigScenarioDir/replies.json"
rigCall 6 AskQuestion "{$rigAsk,\"question\":\"Which checks?\",\"select\":\"many\",$rigOptions}" from-read
rigAssert "an OK mark with no number is no answer"     "$rigKilled" yes
rigAssert "the record stays open"                      "$( rigRecordField status )" reply-pending
rigStart many-sent
rigThread 000101 "$( rigReactions "$rigBoth" three one ok )" ""
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which checks?\",\"select\":\"many\",$rigOptions}"
rigAssert "the numbers held with the OK mark, in option order" "$( rigVerdictLine )" "VERDICT: alpha gamma"
rigAssert "the numbers and the OK mark were placed, and no check mark" "$( rigReacted reactions 000101 | cut -d' ' -f1-4 )" "one two three ok"
rigStart many-sent-before
rigThread 000101 "$( rigReactions "$rigBoth" two white_check_mark )" ""
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which checks?\",\"select\":\"many\",$rigOptions}"
rigAssert "a question posted with the check mark as its send is still sent by it" "$( rigVerdictLine )" "VERDICT: beta"
rigStart many-reply
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'gamma, 1' )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which checks?\",\"select\":\"many\",$rigOptions}"
rigAssert "numbers and words replied, in option order" "$( rigVerdictLine )" "VERDICT: alpha gamma"

echo "-- a reply that names none of the answers: RETURNED, the ways on, then explain and answer --"
rigStart returned
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'What does beta cover?' )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",\"select\":\"one\",$rigOptions}"
rigReturnedId="$( rigRecordId )"
rigAssert "it ran to completion"                       "$rigKilled" no
rigAssert "the verdict is RETURNED"                    "$( rigVerdictLine )" "VERDICT: RETURNED"
rigAssert "the record stays open"                      "$( rigRecordField status )" reply-pending
rigAssert "the reply text comes back"                  "$( rigHolds "$rigScenarioDir/out" 'What does beta cover?' )" yes
rigAssert "it says this may be a communication"        "$( rigHolds "$rigScenarioDir/out" 'This may be a communication and not a rejection: a request to explain, a correction, or an instruction.' )" yes
rigAssert "explain, with its call"                     "$( rigHolds "$rigScenarioDir/out" '- explain: SendMessage to=CRIG00001:1700000001.000101 message=<your explanation>, then Wait mode=continue.' )" yes
rigAssert "update, with its call"                      "$( rigHolds "$rigScenarioDir/out" "- update: AskQuestion pending_id=$rigReturnedId revise=true with the fields you change." )" yes
rigAssert "discard, with its call"                     "$( rigHolds "$rigScenarioDir/out" "- discard: AskQuestion pending_id=$rigReturnedId withdraw=<why>." )" yes
rigAssert "take it as the answer, with its call"       "$( rigHolds "$rigScenarioDir/out" "- take it as the answer: AskQuestion pending_id=$rigReturnedId readback=<the answer you take the reply to mean> understood=<why>." )" yes
rigAssert "the last line is the re-wait call"          "$( LC_ALL=C awk 'END { print ; }' "$rigScenarioDir/out" )" "AskQuestion pending_id=$rigReturnedId"
rigAssert "the reply is kept on the record"            "$( rigHolds "$( rigRecordFile )" 'What does beta cover?' )" yes
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'What does beta cover?' )$( rigMessage 000300 URIGSELF1 'beta is the lint.' )$( rigMessage 000400 URIGOWNER 'beta' )"
rigPosts="$( rigCalls chat.postMessage )"
rigCall 60 AskQuestion "{\"pending_id\":\"$rigReturnedId\"}"
rigAssert "after the explanation, the next reply is the answer" "$( rigVerdictLine )" "VERDICT: beta"
rigAssert "the re-wait posts nothing itself: its one post is the confirmation reply of the answer it applied, made once" \
	"$(( $( rigCalls chat.postMessage ) - rigPosts )):$( rigHolds "$rigScenarioDir/post.$( cat "$rigScenarioDir/posts" 2>/dev/null )" '✅ Read: `beta` by' ):$( LC_ALL=C grep -l -F -- '✅ Read: `beta` by' "$rigScenarioDir"/post.[0-9]* 2>/dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" "1:yes:1"
rigAssert "the record closes with it"                  "$( rigRecordField status )" reply-received

rigStart returned-readback
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'the lint one I think' )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",\"select\":\"one\",$rigOptions}"
rigAssert "the verdict is RETURNED"                    "$( rigVerdictLine )" "VERDICT: RETURNED"
rigCall 60 AskQuestion "{\"pending_id\":\"$( rigRecordId )\",\"readback\":\"beta\",\"understood\":\"the lint is beta\"}"
rigAssert "a readback closes a question with an answer form" "$( rigVerdictLine )" "VERDICT: beta"
rigAssert "it is marked as closed by readback"         "$( rigHolds "$rigScenarioDir/out" 'CLOSED-BY: readback' )" yes
rigAssert "the readback is said in the thread"         "$( rigHolds "$rigScenarioDir/post.2" 'I take your reply to mean' )" yes
rigAssert "the record closes with it"                  "$( rigRecordField verdict )" beta

echo "-- the typed kinds return the same way, under their own names --"
rigStart readback-returned
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'hold on, which tag?' )"
rigCall 60 ConfirmReadback "{$rigAsk,\"question\":\"Did I read it right?\",\"understood\":\"tag v1\",\"source\":\"the brief\",\"will_do\":\"tag it\"}"
rigAssert "a readback: RETURNED"                       "$( rigVerdictLine )" "VERDICT: RETURNED"
rigAssert "its ways name ConfirmReadback"              "$( rigHolds "$rigScenarioDir/out" "- update: ConfirmReadback pending_id=$( rigRecordId ) revise=true" )" yes
rigAssert "and offer no readback of a readback"        "$( rigHolds "$rigScenarioDir/out" 'take it as the answer' )" no
rigAssert "the thumbs up and the cross were placed"    "$( rigReacted reactions 000101 )" "+1 x"
rigStart readback-click
rigThread 000101 "$( rigReactions "$rigBoth" +1 )" ""
rigCall 60 ConfirmReadback "{$rigAsk,\"question\":\"Did I read it right?\",\"understood\":\"tag v1\",\"source\":\"the brief\",\"will_do\":\"tag it\"}"
rigAssert "a readback by click"                        "$( rigVerdictLine )" "VERDICT: yes"
rigStart decision-click
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"first","reactions":[{"name":"one","count":1,"users":[%s]},{"name":"two","count":1,"users":[%s]},{"name":"three","count":2,"users":[%s]}]}],"has_more":false}\n' "$rigSelf" "$rigSelf" "$rigBoth" > "$rigScenarioDir/replies.json"
rigCall 60 EscalateDecision "{$rigAsk,\"question\":\"Which check first?\",$rigOptions}"
rigAssert "a decision by number click"                 "$( rigVerdictLine )" "VERDICT: gamma"
rigAssert "its options are numbered in the post"       "$( rigHolds "$rigScenarioDir/post.1" '- 3️⃣ gamma -- the smoke run' )" yes
rigAssert "the record is a decision"                   "$( rigRecordField kind )" decision
rigStart decision-number-reply
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER '2' )"
rigCall 60 EscalateDecision "{$rigAsk,\"question\":\"Which check first?\",$rigOptions}"
rigAssert "a decision by number reply"                 "$( rigVerdictLine )" "VERDICT: beta"
rigStart decision-returned
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'none of these' )"
rigCall 60 EscalateDecision "{$rigAsk,\"question\":\"Which check first?\",$rigOptions}"
rigAssert "a decision: RETURNED"                       "$( rigVerdictLine )" "VERDICT: RETURNED"
rigAssert "its readback way names EscalateDecision"    "$( rigHolds "$rigScenarioDir/out" "- take it as the answer: EscalateDecision pending_id=$( rigRecordId ) readback=" )" yes
rigStart tool-own-fields
rigThread 000101 "" ""
rigCall 30 EscalateDecision "{$rigAsk,\"question\":\"Which check first?\",$rigOptions,\"task_ref\":\"dispatch-rig\"}"
rigAssert "control: the tool of that kind takes its own fields only" "$( rigHolds "$rigScenarioDir/out" 'ERROR: EscalateDecision: task_ref is not a parameter of EscalateDecision' )" yes

echo "-- asked again, changed, in its own thread: the root stays the place to answer --"
rigStart revise-root
rigThread 000101 "" "$( rigMessage 000150 URIGOWNER 'add the docs build please' )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which checks?\",\"select\":\"many\",$rigOptions}"
rigAssert "the first reply returns the question"       "$( rigVerdictLine )" "VERDICT: RETURNED"
rigRootId="$( rigRecordId )"
## The thread as it will read once the update is in it: the update is the second post.
rigThread 000101 "" "$( rigMessage 000150 URIGOWNER 'add the docs build please' )$( rigMessage 000201 URIGSELF1 'the live update' )"
rigCall 8 AskQuestion "{\"pending_id\":\"$rigRootId\",\"revise\":true,\"options\":\"alpha -- the unit checks\\nbeta -- the lint\\ngamma -- the smoke run\\ndelta -- the docs build\"}" from-read
rigAssert "the first update is posted and waits"       "$rigKilled" yes
rigAssert "it is a reply in the thread of the question" "$( LC_ALL=C sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigScenarioDir/post.2" | head -1 )" "1700000001.000101"
rigAssert "its title says it is updated"               "$( rigHolds "$rigScenarioDir/post.2" 'Question ✏️ updated' )" yes
rigAssert "it shows the changed options"               "$( rigHolds "$rigScenarioDir/post.2" '- 4️⃣ delta -- the docs build' )" yes
rigAssert "the same record"                            "$( rigRecordCount ):$( rigRecordId )" "1:$rigRootId"
rigAssert "which knows its live version"               "$( rigRecordField revision-ts )" "1700000001.000201"
rigAssert "and that it is its first revision"          "$( rigRecordField revisions )" 1
rigAssert "the root is marked once, and gains the new number" "$( rigReacted reactions 000101 | cut -d' ' -f5- )" "recycle four"
rigAssert "the live update carries the answer emoji"   "$( rigReacted reactions 000201 )" "one two three four ok"
rigAssert "nothing is deleted yet"                     "$( cat "$rigScenarioDir/deleted" 2>/dev/null | tr '\n' ' ' )" ""
rigAssert "and the root is never edited"               "$( rigCalls chat.update )" 0
## The second update changes the form, and the person then clicks on the root.
rigThread 000101 "$( rigReactions "$rigBoth" +1 )" "$( rigMessage 000150 URIGOWNER 'add the docs build please' )$( rigMessage 000301 URIGSELF1 'the live update' )"
rigCall 60 AskQuestion "{\"pending_id\":\"$rigRootId\",\"revise\":true,\"question\":\"Run every check?\",\"select\":\"yes-no\"}"
rigAssert "the second update ran to its answer"        "$rigKilled" no
rigAssert "the update before it is removed"            "$( cat "$rigScenarioDir/deleted" 2>/dev/null | tr '\n' ' ' )" "1700000001.000201 "
rigAssert "the root is still marked once"              "$( rigReacted reactions 000101 | tr ' ' '\n' | LC_ALL=C grep -c -x recycle )" 1
rigAssert "the emoji that no longer answer leave the root, and those of the live form leave it with the answered mark" "$( rigReacted reactions.removed 000101 )" "one two three four ok +1 x"
rigAssert "and the missing ones are placed on it"      "$( rigReacted reactions 000101 | tr ' ' '\n' | LC_ALL=C grep -c -x -e '+1' -e x )" 2
rigAssert "a click on the root answers the live version" "$( rigVerdictLine )" "VERDICT: yes"
rigAssert "the same record and id throughout"          "$( rigRecordCount ):$( rigRecordId )" "1:$rigRootId"
rigAssert "now at its second revision"                 "$( rigRecordField revisions )" 2
rigAssert "the record keeps both revisions"            "$( LC_ALL=C grep -c '^## Revision ' "$( rigRecordFile )" )" 2

rigStart revise-root-live-click
rigThread 000101 "" "$( rigMessage 000150 URIGOWNER 'which ones are fast?' )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",\"select\":\"one\",$rigOptions}"
rigThread 000101 "$( rigReactions "$rigSelf" one two three )" "$( rigMessage 000150 URIGOWNER 'which ones are fast?' )$( rigMessage 000201 URIGSELF1 'the live update' "$( rigReactions "$rigBoth" two )" )"
rigCall 60 AskQuestion "{\"pending_id\":\"$( rigRecordId )\",\"revise\":true,\"context\":\"alpha and beta take a minute each\"}"
rigAssert "a click on the live update answers too"     "$( rigVerdictLine )" "VERDICT: beta"
rigAssert "the earlier reply is not read again"        "$( rigHolds "$rigScenarioDir/out" 'VERDICT: RETURNED' )" no

echo "-- asked again inside another thread: a new reply each time, the one before marked and closed --"
rigStart revise-threaded
printf '{"ok":true,"messages":[{"ts":"1700000001.000001","user":"URIGOWNER","text":"the thread"},{"ts":"1700000001.000101","user":"URIGSELF1","text":"first","thread_ts":"1700000001.000001"},{"ts":"1700000001.000150","user":"URIGOWNER","text":"which is fastest?","thread_ts":"1700000001.000001"}],"has_more":false}\n' > "$rigScenarioDir/replies.json"
rigCall 60 AskQuestion "{\"to\":\"CRIG00001:1700000001.000001\",\"address_to\":\"URIGOWNER\",\"question\":\"Which check first?\",\"select\":\"one\",$rigOptions}"
rigAssert "the first reply returns the question"       "$( rigVerdictLine )" "VERDICT: RETURNED"
rigThreadId="$( rigRecordId )"
rigThreadTag="$( rigRecordField question-tag )"
rigThreadPosts(){ ## the question's posts in the thread so far, as ts suffixes
	local postsOut="" postsTs
	for postsTs in "$@" ; do
		postsOut="$postsOut,{\"ts\":\"1700000001.$postsTs\",\"user\":\"URIGSELF1\",\"text\":\"a version\",\"thread_ts\":\"1700000001.000001\"}"
	done
	printf '{"ok":true,"messages":[{"ts":"1700000001.000001","user":"URIGOWNER","text":"the thread"}%s],"has_more":false}\n' "$postsOut" > "$rigScenarioDir/replies.json"
}
rigThreadPosts 000101 000201
rigCall 8 AskQuestion "{\"pending_id\":\"$rigThreadId\",\"revise\":true,\"context\":\"alpha takes a minute\"}" from-read
rigAssert "the first update is posted and waits"       "$rigKilled" yes
rigAssert "it is a new reply in the same thread"       "$( LC_ALL=C sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigScenarioDir/post.2" | head -1 )" "1700000001.000001"
rigAssert "the version before it is marked"            "$( rigReacted reactions 000101 | tr ' ' '\n' | LC_ALL=C grep -c -x recycle )" 1
rigAssert "and loses the answer emoji"                 "$( rigReacted reactions.removed 000101 )" "one two three"
rigAssert "and is edited"                              "$( cat "$rigScenarioDir/edited" 2>/dev/null | tr '\n' ' ' )" "1700000001.000101 "
rigAssert "the edit is a whole message, as the send builds one: it names that post, has blocks, no How to answer" \
	"$( rigEditShape "$rigScenarioDir/edit.1700000001.000101" 1700000001.000101 )" "1:1:0"
rigAssert "its text is what the post was sent with, author line and all, less How to answer" \
	"$( rigTextOf "$rigScenarioDir/edit.1700000001.000101" )" "$( rigClosedOf "$rigScenarioDir/post.1" )"
rigAssert "which is the template's own text for a post that takes no answer" \
	"$( rigHolds "$rigScenarioDir/edit.1700000001.000101" "# ❓ Question $rigThreadTag"'\n\nWhich check first?\n\n**📋 Options**\n- 1️⃣ alpha -- the unit checks\n- 2️⃣ beta -- the lint\n- 3️⃣ gamma -- the smoke run"' )" yes
rigAssert "the live version carries the answer emoji"  "$( rigReacted reactions 000201 )" "one two three"
rigThreadPosts 000101 000201 000301
rigCall 8 AskQuestion "{\"pending_id\":\"$rigThreadId\",\"revise\":true,\"context\":\"alpha takes a minute, beta two\"}" from-read
rigAssert "the second update is posted and waits"      "$rigKilled" yes
rigAssert "three posts of the question, and nothing deleted" "$( rigCalls chat.postMessage ):$( rigCalls chat.delete )" "3:0"
rigAssert "the second version is marked too"           "$( rigReacted reactions 000201 | tr ' ' '\n' | LC_ALL=C grep -c -x recycle )" 1
rigAssert "and loses the answer emoji"                 "$( rigReacted reactions.removed 000201 )" "one two three"
rigAssert "and is edited the same way"                 "$( rigEditShape "$rigScenarioDir/edit.1700000001.000201" 1700000001.000201 )" "1:1:0"
rigAssert "to its own text, updated title and context kept, less How to answer" \
	"$( rigTextOf "$rigScenarioDir/edit.1700000001.000201" ):$( rigHolds "$rigScenarioDir/edit.1700000001.000201" '✏️ updated\n\nWhich check first?' )" "$( rigClosedOf "$rigScenarioDir/post.2" ):yes"
rigAssert "the same record, id and number"             "$( rigRecordCount ):$( rigRecordId ):$( rigRecordField question-tag )" "1:$rigThreadId:$rigThreadTag"
rigAssert "which lists the versions it left behind"    "$( rigRecordField superseded )" "1700000001.000101, 1700000001.000201"
## A click on a version left behind is read no more: only the live one counts.
printf '{"ok":true,"messages":[{"ts":"1700000001.000001","user":"URIGOWNER","text":"the thread"},{"ts":"1700000001.000101","user":"URIGSELF1","text":"first","thread_ts":"1700000001.000001","reactions":[{"name":"one","count":1,"users":["URIGOWNER"]}]},{"ts":"1700000001.000301","user":"URIGSELF1","text":"live","thread_ts":"1700000001.000001","reactions":[{"name":"three","count":2,"users":[%s]}]}],"has_more":false}\n' "$rigBoth" > "$rigScenarioDir/replies.json"
rigCall 60 AskQuestion "{\"pending_id\":\"$rigThreadId\"}"
rigAssert "the click on the live version is the answer" "$( rigVerdictLine )" "VERDICT: gamma"

echo "-- asked again in a thread that other numbered questions share: its number still routes its replies --"
rigWaitId(){ ## -> the pending id the last call left to wait on
	LC_ALL=C sed -n 's/^WAIT-ID: ask://p' "$rigScenarioDir/out" | head -1
}
rigFieldOf(){ ## pending id, field
	LC_ALL=C awk -v key="$2" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' \
		"$( [ -f "$rigScenarioDir/ws/.local/agents/pending/$1.md" ] && printf '%s' "$rigScenarioDir/ws/.local/agents/pending/$1.md" || printf '%s' "$rigScenarioDir/ws/.local/agents/pending/closed/$1.md" )" 2>/dev/null || printf 'no-record'
}
## The shared thread as it reads once both questions and the first one's update are in it,
## then the person's replies: each "<ts suffix>|<text>".
rigSharedThread(){
	local sharedOut="" sharedTs sharedReply
	for sharedTs in 000101 000201 000301 ; do
		sharedOut="$sharedOut,{\"ts\":\"1700000001.$sharedTs\",\"user\":\"URIGSELF1\",\"text\":\"a question\",\"thread_ts\":\"1700000001.000001\"}"
	done
	for sharedReply in "$@" ; do
		sharedOut="$sharedOut,{\"ts\":\"1700000001.${sharedReply%%|*}\",\"user\":\"URIGOWNER\",\"text\":\"${sharedReply#*|}\",\"thread_ts\":\"1700000001.000001\"}"
	done
	printf '{"ok":true,"messages":[{"ts":"1700000001.000001","user":"URIGOWNER","text":"the thread"}%s],"has_more":false}\n' "$sharedOut" > "$rigScenarioDir/replies.json"
}
## Two questions asked into one thread, neither waited on: the first is then asked again, changed.
rigSharedFirst="" rigSharedSecond=""
rigSharedStart(){ ## scenario name
	rigStart "$1"
	rigThreadPosts 000101
	rigCall 30 AskQuestion "{\"to\":\"CRIG00001:1700000001.000001\",\"address_to\":\"URIGOWNER\",\"question\":\"Which check first?\",\"select\":\"one\",$rigOptions,\"wait\":false}"
	rigSharedFirst="$( rigWaitId )"
	rigThreadPosts 000101 000201
	rigCall 30 AskQuestion "{\"to\":\"CRIG00001:1700000001.000001\",\"address_to\":\"URIGOWNER\",\"question\":\"Which check last?\",\"select\":\"one\",$rigOptions,\"wait\":false}"
	rigSharedSecond="$( rigWaitId )"
	[ -n "$rigSharedFirst" ] && [ -n "$rigSharedSecond" ] && [ "$rigSharedFirst" != "$rigSharedSecond" ] || rigRefuse "the rig did not leave two questions in one thread"
}
rigSharedStart revise-shared-numbered
rigAssert "two questions in one thread, each under its own number" "$( rigFieldOf "$rigSharedFirst" question-tag ):$( rigFieldOf "$rigSharedSecond" question-tag )" "Q1:Q2"
rigSharedThread '000400|Q2 gamma' '000500|Q1 beta'
rigCall 60 AskQuestion "{\"pending_id\":\"$rigSharedFirst\",\"revise\":true,\"context\":\"alpha takes a minute\"}"
rigAssert "the update ran to its answer"               "$rigKilled" no
rigAssert "the update is posted under the same number" "$( rigHolds "$rigScenarioDir/post.3" '# ❓ Question Q1 ✏️ updated' ):$( rigFieldOf "$rigSharedFirst" revision-ts )" "yes:1700000001.000301"
rigAssert "the reply numbered for it answers its live version, the one numbered for the other does not" "$( rigVerdictLine )" "VERDICT: beta"
## A wait of a session returns on every update of interest to that session: the same wait takes
## the reply numbered for the other question too, said as what else arrived.
rigAssert "its record closes with it" "$( rigFieldOf "$rigSharedFirst" verdict ):$( rigFieldOf "$rigSharedFirst" status )" "beta:reply-received"
rigAssert "the other question takes the reply numbered for it, in the same wait" \
	"$( rigHolds "$rigScenarioDir/out" 'ALSO-ARRIVED: ' ):$( rigHolds "$rigScenarioDir/out" "# --- pending reply $rigSharedSecond, as the asking call would take it ---" ):$( rigFieldOf "$rigSharedSecond" status ):$( rigFieldOf "$rigSharedSecond" verdict )" "yes:yes:reply-received:gamma"
rigSharedStart revise-shared-plain
rigSharedThread '000400|beta'
rigCall 60 AskQuestion "{\"pending_id\":\"$rigSharedFirst\",\"revise\":true,\"context\":\"alpha takes a minute\"}"
rigAssert "a reply with no number answers the question posted last above it: the live version" "$( rigVerdictLine ):$( rigFieldOf "$rigSharedFirst" verdict )" "VERDICT: beta:beta"
rigCall 6 AskQuestion "{\"pending_id\":\"$rigSharedSecond\"}" from-read
rigAssert "the question above the live version does not take that reply: it is still waiting" "$rigKilled:$( rigFieldOf "$rigSharedSecond" status )" "yes:reply-pending"

echo "-- a discarded question: its post marked, without its answer emoji and its How to answer --"
rigStart discard-root
rigThread 000101 "" ""
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"Should the rig go on?\",\"select\":\"yes-no\",\"wait\":false}"
rigAssert "posted, not waited on"                      "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: POSTED"
rigCall 60 AskQuestion "{\"pending_id\":\"$( rigRecordId )\",\"withdraw\":\"the rig went on by itself\"}"
rigAssert "it is withdrawn"                            "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: WITHDRAWN"
rigAssert "the root gets the cancelled mark"           "$( rigReacted reactions 000101 | tr ' ' '\n' | LC_ALL=C grep -c -x no_entry_sign )" 1
rigAssert "and loses the answer emoji"                 "$( rigReacted reactions.removed 000101 )" "+1 x"
rigAssert "and is edited, as a whole message"          "$( rigEditShape "$rigScenarioDir/edit.1700000001.000101" 1700000001.000101 )" "1:1:0"
rigAssert "to the text it was sent with, less How to answer" "$( rigTextOf "$rigScenarioDir/edit.1700000001.000101" )" "$( rigClosedOf "$rigScenarioDir/post.1" )"
rigAssert "which ends with the question itself"        "$( rigTextOf "$rigScenarioDir/edit.1700000001.000101" | LC_ALL=C sed 's/^.*# ❓ Question/# ❓ Question/' )" '# ❓ Question\n\nShould the rig go on?'
## A root that was asked again, changed, and then discarded: the root is edited to its own
## first text, and the update under it no longer invites a click.
rigStart discard-root-updated
rigThread 000101 "" "$( rigMessage 000150 URIGOWNER 'what is alpha?' )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",\"select\":\"one\",$rigOptions}"
rigThread 000101 "" "$( rigMessage 000150 URIGOWNER 'what is alpha?' )$( rigMessage 000201 URIGSELF1 'the live update' )"
rigCall 8 AskQuestion "{\"pending_id\":\"$( rigRecordId )\",\"revise\":true,\"question\":\"Run every check?\",\"select\":\"yes-no\"}" from-read
rigAssert "the update is posted and waits"             "$rigKilled" yes
rigCall 60 AskQuestion "{\"pending_id\":\"$( rigRecordId )\",\"withdraw\":\"no longer needed\"}"
rigAssert "it is withdrawn"                            "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: WITHDRAWN"
rigAssert "the root is edited, and only the root"      "$( cat "$rigScenarioDir/edited" 2>/dev/null | tr '\n' ' ' ):$( rigEditShape "$rigScenarioDir/edit.1700000001.000101" 1700000001.000101 )" "1700000001.000101 :1:1:0"
rigAssert "to its own first text, not the update's"    "$( rigTextOf "$rigScenarioDir/edit.1700000001.000101" ):$( rigHolds "$rigScenarioDir/edit.1700000001.000101" 'Run every check?' )" "$( rigClosedOf "$rigScenarioDir/post.1" ):no"
rigAssert "the root gets the cancelled mark"           "$( rigReacted reactions 000101 | tr ' ' '\n' | LC_ALL=C grep -c -x no_entry_sign )" 1
rigAssert "and the update under it loses its answer emoji" "$( rigReacted reactions.removed 000201 )" "+1 x"
## One floor for the send and the edit, on the asker's own words only. A question over it is
## not posted: it comes back as a correction. A line the tooling adds is nobody's to rewrite:
## a refused call over every limit holds nothing back, and its post is edited when discarded.
rigStart discard-below-floor
rigThread 000101 "" ""
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"Should the rig go on now; or wait for the next run?\",\"select\":\"yes-no\",\"wait\":false}"
rigAssert "a question over the plain-language floor is not posted: it comes back as a correction" \
	"$( rigFirstLine "$rigScenarioDir/out" | cut -c1-12 ):$( rigCalls chat.postMessage ):$( rigRecordCount )" "CORRECTION: :0:0"
rigLongTarget="/dev/null/rig-forms/a path of many words one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty; and a semicolon"
rigCall 60 Write "{\"path\":\"$rigLongTarget\",\"content\":\"x\"}"
rigFloorRefusal="$( LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigScenarioDir/out" | head -1 )"
[ -n "$rigFloorRefusal" ] || rigRefuse "the rig produced no refusal to ask permission for"
rigCall 8 RequestPermission "{$rigAsk,\"question\":\"May the rig write this file?\",\"refusal_id\":\"$rigFloorRefusal\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}" from-read
rigAssert "a line the tooling adds, over every limit, does not hold the question back: it is posted and waits" \
	"$rigKilled:$( rigCalls chat.postMessage ):$( rigHolds "$rigScenarioDir/post.1" 'nineteen twenty; and a semicolon' )" "yes:1:yes"
rigCall 60 RequestPermission "{\"pending_id\":\"$( rigRecordId )\",\"withdraw\":\"the rig went on by itself\"}"
rigAssert "and it is still edited when discarded"      "$( rigEditShape "$rigScenarioDir/edit.1700000001.000101" 1700000001.000101 ):$( rigTextOf "$rigScenarioDir/edit.1700000001.000101" )" "1:1:0:$( rigClosedOf "$rigScenarioDir/post.1" )"
## An edit Slack refuses never fails the discard: it is asked for once, its answer is final,
## and the post keeps its mark with its text as it was.
rigStart discard-edit-refused
: > "$rigScenarioDir/edit-refuse"
rigThread 000101 "" ""
rigCall 30 AskQuestion "{$rigAsk,\"question\":\"Should the rig go on?\",\"select\":\"yes-no\",\"wait\":false}"
rigCall 30 AskQuestion "{\"pending_id\":\"$( rigRecordId )\",\"withdraw\":\"the rig went on by itself\"}"
rigAssert "a refused edit never fails the discard"     "$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigRecordField status )" "no:ASK-RESULT: WITHDRAWN:withdrawn"
rigAssert "the edit is asked for once, never again, and nothing is edited" "$( rigCalls chat.update ):$( cat "$rigScenarioDir/edit-refused" 2>/dev/null | tr '\n' ' ' ):$( [ -e "$rigScenarioDir/edited" ] && printf edited || printf none )" "1:1700000001.000101 :none"
rigAssert "the post still gets the cancelled mark and loses the answer emoji" "$( rigReacted reactions 000101 | tr ' ' '\n' | LC_ALL=C grep -c -x no_entry_sign ):$( rigReacted reactions.removed 000101 )" "1:+1 x"
rigAssert "and it is logged, not dropped"              "$( LC_ALL=C grep -c -F 'the post CRIG00001:1700000001.000101 could not be edited to drop its How to answer part' "$rigScenarioDir/err" )" 1
## The edit itself, asked of the send (--update-ts): what Slack answers to it is final, nothing
## is queued or emailed for it, and its outcome is logged as an edit, never as a post.
rigSendUpdate(){ ## -> the rc of one edit of the question's post, its output kept
	( cd "$rigScenarioDir/ws" && printf 'the changed text' | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SPAWN_SESSION_ID="rig-forms-$rigScenarioName" MDAT_SPAWN_AGENT="$rigMember" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-comms-slack-send-message "$rigMember" CRIG00001 --update-ts 1700000001.000101 --from-stdin \
	) > "$rigScenarioDir/send.out" 2> "$rigScenarioDir/send.err"
	printf '%s' "$?"
}
rigSendLogged(){ ## -> the outcome and reason of the newest line of the send log
	cat "$rigScenarioDir/ws/.local/agents"/comms-slack-send.*.log 2>/dev/null | LC_ALL=C awk -F'\t' '{ last = $6 " " $7 ; } END { print last ; }'
}
rigUpdates="$( rigCalls chat.update )"
rigAssert "the send fails an edit Slack refuses, asking once" "$( rigSendUpdate ):$(( $( rigCalls chat.update ) - rigUpdates ))" "1:1"
rigAssert "it says the message stands as it was, with nothing queued or emailed" \
	"$( LC_ALL=C grep -c -F 'the message CRIG00001:1700000001.000101 was NOT edited -- Slack answered and did not edit it. It stands as it was: an edit is not queued, and no email is sent.' "$rigScenarioDir/send.err" ):$( LC_ALL=C grep -c -e 'notifying by email' -e 'nothing was posted' "$rigScenarioDir/send.err" )" "1:0"
rigAssert "and it is logged as an edit that did not happen" "$( rigSendLogged )" "failed not edited: Slack answered and did not edit it error=cant_update_message"
rm -f "$rigScenarioDir/edit-refuse"
rigAssert "an edit Slack makes is logged as an edit, never as a post" "$( rigSendUpdate ):$( rigSendLogged )" "0:ok edited ts=1700000001.000101"
rigStart discard-threaded
printf '{"ok":true,"messages":[{"ts":"1700000001.000001","user":"URIGOWNER","text":"the thread"},{"ts":"1700000001.000101","user":"URIGSELF1","text":"first","thread_ts":"1700000001.000001"}],"has_more":false}\n' > "$rigScenarioDir/replies.json"
rigCall 30 AskQuestion "{\"to\":\"CRIG00001:1700000001.000001\",\"address_to\":\"URIGOWNER\",\"question\":\"Which check first?\",\"select\":\"one\",$rigOptions,\"wait\":false}"
rigCall 60 AskQuestion "{\"pending_id\":\"$( rigRecordId )\",\"withdraw\":\"no longer needed\"}"
rigAssert "a threaded question: its post gets the cancelled mark" "$( rigReacted reactions 000101 | tr ' ' '\n' | LC_ALL=C grep -c -x no_entry_sign )" 1
rigAssert "and loses the answer emoji"                 "$( rigReacted reactions.removed 000101 )" "one two three"
rigAssert "and is edited, as a whole message"          "$( cat "$rigScenarioDir/edited" 2>/dev/null | tr '\n' ' ' ):$( rigEditShape "$rigScenarioDir/edit.1700000001.000101" 1700000001.000101 )" "1700000001.000101 :1:1:0"
rigAssert "to the text it was sent with, less How to answer" "$( rigTextOf "$rigScenarioDir/edit.1700000001.000101" )" "$( rigClosedOf "$rigScenarioDir/post.1" )"
rigStart answered-unedited
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'yes' )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Should the rig go on?\",\"select\":\"yes-no\"}"
rigAssert "control: an answered question is never edited" "$( rigVerdictLine ):$( rigCalls chat.update )" "VERDICT: yes:0"

echo "-- a permission: by click, and a thumbs up granting nothing --"
rigRefusal(){ ## output file -> the refusal id it printed
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$1" | head -1
}
rigStart permission-click
rigCall 60 Write "{\"path\":\"/dev/null/rig-forms/p\",\"content\":\"x\"}"
rigPermissionRefusal="$( rigRefusal "$rigScenarioDir/out" )"
[ -n "$rigPermissionRefusal" ] || rigRefuse "the rig produced no refusal to ask permission for"
rigAssert "the refusal names the tool to ask with"     "$( rigHolds "$rigScenarioDir/out" "ask for it with RequestPermission refusal_id=$rigPermissionRefusal" )" yes
rigThread 000101 "$( rigReactions "$rigBoth" +1 )" ""
rigCall 8 RequestPermission "{$rigAsk,\"question\":\"May the rig write this file?\",\"refusal_id\":\"$rigPermissionRefusal\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}" from-read
rigAssert "a thumbs up is no answer to a permission"   "$( rigVerdictLine )" "VERDICT: RETURNED"
rigAssert "and grants nothing"                         "$( [ -s "$rigScenarioDir/ws/.local/agents/sessions/rig-forms-permission-click/grants" ] && printf granted || printf none )" none
rigAssert "the cross, the one and the repeat sign were placed, and the folder, which this request offers" "$( rigReacted reactions 000101 )" "x one repeat file_folder"
rigAssert "the post names the clicks"                  "$( rigHolds "$rigScenarioDir/post.1" 'click ❌ to deny, 1️⃣ to allow once, or 🔁 to allow for this session' )" yes
rigThread 000101 "$( rigReactions "$rigBoth" one )" ""
rigCall 60 RequestPermission "{\"pending_id\":\"$( rigRecordId )\"}"
rigAssert "a click on the one allows once"             "$( rigVerdictLine )" "VERDICT: allow-once"
rigAssert "signed by whoever clicked"                  "$( LC_ALL=C sed -n 's/^ANSWERED-BY: //p' "$rigScenarioDir/out" | head -1 )" "URIGOWNER"
rigAssert "and the grant is written as a typed allow-once is" "$( LC_ALL=C grep -c '^GRANT: ' "$rigScenarioDir/out" )" 1
rigStart permission-deny
rigCall 60 Write "{\"path\":\"/dev/null/rig-forms/q\",\"content\":\"x\"}"
rigThread 000101 "$( rigReactions "$rigBoth" one x )" ""
rigCall 60 RequestPermission "{$rigAsk,\"question\":\"May the rig write this file?\",\"refusal_id\":\"$( rigRefusal "$rigScenarioDir/out" )\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}"
rigAssert "a cross beside an allow denies"             "$( rigVerdictLine )" "VERDICT: deny"

echo "-- a permission asked of the human-owner: the team bot posts it, in its own conversation with the owner --"
rigBotToken="rig-bot-token-TEAM"
rigOwnToken="rig-user-token-TESTER"
rigCoordinatorToken="rig-user-token-COORD"
## How many calls of one method went out under one token: the fake curl keeps each call with its token.
rigCallsAs(){ ## method, token, optional rest of the line (a reaction's "<ts> <name>")
	LC_ALL=C awk -v wantCall="$1 $2${3:+ $3}" '$0 == wantCall { hitCount++ ; } END { print hitCount + 0 ; }' "$rigScenarioDir/calls" 2>/dev/null || printf 'no-such-log'
}
## The three answer emoji of a permission on one post, as placed under one token: "<x>:<one>:<repeat>".
rigSeededAs(){ ## token, ts suffix
	printf '%s:%s:%s' "$( rigCallsAs reactions.add "$1" "1700000001.$2 x" )" "$( rigCallsAs reactions.add "$1" "1700000001.$2 one" )" "$( rigCallsAs reactions.add "$1" "1700000001.$2 repeat" )"
}
## A refused write, then its permission asked of whoever the fields name; the thread is scripted by the caller.
rigPermissionAsk(){ ## the path of the refused write, the call's to and its other fields, the task it is for (default dispatch-rig)
	rigCall 60 Write "{\"path\":\"$1\",\"content\":\"x\"}"
	rigCall 60 RequestPermission "{$2,\"question\":\"May the rig write this file?\",\"refusal_id\":\"$( rigRefusal "$rigScenarioDir/out" )\",\"reason\":\"the rig needs it\",\"task_ref\":\"${3:-dispatch-rig}\"}"
}
## How many records of the scenario say one identity asked.
rigRecordsAskedAs(){ ## bot|member
	LC_ALL=C grep -l -x -F "ask-identity: $1" "$rigScenarioDir/ws/.local/agents/pending"/*.md "$rigScenarioDir/ws/.local/agents/pending/closed"/*.md 2>/dev/null | LC_ALL=C awk 'END { print NR + 0 ; }'
}
## The token one post of the scenario went out under: the fake curl keeps it beside the post.
rigPostedAs(){ ## post number
	cat "$rigScenarioDir/posted-as.$1" 2>/dev/null || printf 'no-such-post'
}
## The number the scenario's next post gets from the fake curl, whose ts is then 1700000001.000<n>01.
rigNextPost(){
	printf '%s' "$(( $( cat "$rigScenarioDir/posts" 2>/dev/null || printf 0 ) + 1 ))"
}
rigStart owner-permission
rigThread 000101 "$( rigReactions "$rigBoth" one )" ""
rigPermissionAsk /dev/null/rig-forms/owner-permission '"to":"human-owner","as_bot":false'
rigAssert "asked of the human-owner, whatever as_bot says: its post goes out under the team bot's token, and none under the member's own" \
	"$( rigPostedAs 1 ):$( rigCallsAs chat.postMessage "$rigOwnToken" )" "$rigBotToken:0"
rigAssert "to the human-owner conversation, which under the bot's token is the bot's own with the owner" "$( rigHolds "$rigScenarioDir/post.1" '"channel":"URIGOWNER"' )" yes
rigAssert "its record says the bot asked, and names the human-owner as asked" "$( rigRecordField ask-identity ):$( rigRecordField address-to )" "bot:human-owner"
rigAssert "the cross, the one and the repeat sign are placed under the bot's token, none under the member's own" \
	"$( rigSeededAs "$rigBotToken" 000101 ) $( rigSeededAs "$rigOwnToken" 000101 )" "1:1:1 0:0:0"
rigAssert "the asking call's own wait reads its thread as the bot, and sees the owner's click" \
	"$rigKilled:$( rigVerdictLine ):$( [ "$( rigCallsAs conversations.replies "$rigBotToken" )" -gt 0 ] && printf bot-read || printf no-bot-read ):$( rigCallsAs conversations.replies "$rigOwnToken" )" "no:VERDICT: allow-once:bot-read:0"
rigAssert "and the grant is written"                   "$( LC_ALL=C grep -c '^GRANT: ' "$rigScenarioDir/out" )" 1
## The live fault: a member with no account of its own. Its permission went to the owner under
## the coordinator's account, in the coordinator's conversation, where the bot placed no emoji.
rigStart owner-permission-no-account
rm -f "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
printf 'SLACK_USER_TOKEN=%s\n' "$rigCoordinatorToken" > "$rigScenarioDir/ws/.local/.agents/magic-coordinator.agent.env"
rigThread 000101 "$( rigReactions "$rigBoth" repeat )" ""
rigPermissionAsk /dev/null/rig-forms/owner-permission-no-account '"to":"human-owner"'
rigAssert "a member with no account of its own: its post goes out under the bot's token, and none under the coordinator's" \
	"$( rigPostedAs 1 ):$( rigCallsAs chat.postMessage "$rigCoordinatorToken" )" "$rigBotToken:0"
rigAssert "its record says the bot asked, and its three emoji are placed under the bot's token" "$( rigRecordField ask-identity ) $( rigSeededAs "$rigBotToken" 000101 )" "bot 1:1:1"
rigAssert "and the owner's click is the answer"        "$rigKilled:$( rigVerdictLine )" "no:VERDICT: allow-session"
## The accepted siblings stay as they were: a permission asked of a team member who holds
## the call (the coordinator, by a standing row), one addressed to the owner in another
## conversation, and a plain question to the owner.
rigStart member-permission
printf 'SLACK_USER_TOKEN=%s\n' "$rigCoordinatorToken" > "$rigScenarioDir/ws/.local/.agents/magic-coordinator.agent.env"
printf 'URIGCOORD' > "$rigScenarioDir/account.$rigCoordinatorToken"
printf 'magic-coordinator:ws:workspace:Edit(//dev/null/rig-forms/**)\n' > "$rigScenarioDir/ws/.local/agents/permissions.registry"
rigThread 000101 "$( rigReactions '"URIGSELF1","URIGCOORD"' x )" ""
rigPermissionAsk /dev/null/rig-forms/member-permission '"to":"magic-coordinator"'
rigAssert "asked of a team member who holds the call: its post goes out under the member's own token, to that member, as before" \
	"$( rigPostedAs 1 ):$( rigCallsAs chat.postMessage "$rigBotToken" ):$( rigHolds "$rigScenarioDir/post.1" '"channel":"URIGCOORD"' )" "$rigOwnToken:0:yes"
rigAssert "it is asked of who was named, so the result carries no NOTE line" "$( LC_ALL=C grep -c '^NOTE: addressed to ' "$rigScenarioDir/out" )" 0
rigAssert "its record says the member asked, and its emoji are placed under the member's own token" \
	"$( rigRecordField ask-identity ) $( rigSeededAs "$rigOwnToken" 000101 ) $( rigSeededAs "$rigBotToken" 000101 )" "member 1:1:1 0:0:0"
rigAssert "and that member's click is the answer"      "$rigKilled:$( rigVerdictLine )" "no:VERDICT: deny"
rigStart owner-permission-elsewhere
rigThread 000101 "$( rigReactions "$rigBoth" one )" ""
rigPermissionAsk /dev/null/rig-forms/owner-permission-elsewhere '"to":"magic-team","address_to":"human-owner"'
rigAssert "addressed to the owner in another conversation: the member's own post there, as before" \
	"$( rigPostedAs 1 ):$( rigCallsAs chat.postMessage "$rigBotToken" ):$( rigRecordField ask-identity ):$( rigHolds "$rigScenarioDir/post.1" '"channel":"CRIG00001"' ):$( rigVerdictLine )" "$rigOwnToken:0:member:yes:VERDICT: allow-once"
rigStart owner-question
rigCall 30 AskQuestion '{"to":"human-owner","question":"Should the rig go on?","select":"yes-no","wait":false}'
rigAssert "a plain question to the human-owner is the team bot's too: its post, record and emoji, none under the member's own token" \
	"$( rigPostedAs 1 ):$( rigCallsAs chat.postMessage "$rigOwnToken" ):$( rigRecordField ask-identity ):$( rigCallsAs reactions.add "$rigBotToken" '1700000001.000101 +1' ):$( rigCallsAs reactions.add "$rigOwnToken" '1700000001.000101 +1' )" "$rigBotToken:0:bot:1:0"
## The same permission asked of the owner again: the same refused call, which is what a
## permission is known by, never its words. One the bot asked keeps its own thread. One asked
## before under a member's own account stands where the bot is not: the bot posts it anew.
## Each answer here allows the call once, so the call is made once more, which uses that grant
## up, and is refused again before it is asked again. Each time it is asked for another task
## of the session: a further call asked alone for the same task, once he has answered one, is
## not posted at all (AgentsHarnessPermissionSetAskCheck).
rigAgainFile="/dev/null/rig-forms/owner-permission-again"
rigStart owner-permission-again
rigThread 000101 "$( rigReactions "$rigBoth" one )" ""
rigPermissionAsk "$rigAgainFile" '"to":"human-owner"'
rigAgainPost="$( rigNextPost )"
rigThread 000101 "$( rigReactions "$rigBoth" one )" "$( rigMessage "000${rigAgainPost}01" URIGSELF1 'asked again' "$( rigReactions "$rigBoth" one )" )"
rigCall 60 Write "{\"path\":\"$rigAgainFile\",\"content\":\"x\"}"
rigPermissionAsk "$rigAgainFile" '"to":"human-owner"' 'the second task of the rig'
rigAssert "asked again after the bot asked it: the bot's reply in that question's own thread" \
	"$( rigPostedAs "$rigAgainPost" ):$( rigHolds "$rigScenarioDir/post.$rigAgainPost" '"thread_ts":"1700000001.000101"' ):$( rigSeededAs "$rigBotToken" "000${rigAgainPost}01" ):$( rigRecordsAskedAs bot )" "$rigBotToken:yes:1:1:1:2"
## As records from before read: asked under the member's own account.
for rigAgainRecord in "$rigScenarioDir/ws/.local/agents/pending"/*.md "$rigScenarioDir/ws/.local/agents/pending/closed"/*.md ; do
	LC_ALL=C sed 's/^ask-identity: bot$/ask-identity: member/' "$rigAgainRecord" > "$rigAgainRecord.rig" && mv -f "$rigAgainRecord.rig" "$rigAgainRecord"
done
rigCall 60 Write "{\"path\":\"$rigAgainFile\",\"content\":\"x\"}"
rigAgainPost="$( rigNextPost )"
rigThread "000${rigAgainPost}01" "$( rigReactions "$rigBoth" one )" ""
rigPermissionAsk "$rigAgainFile" '"to":"human-owner"' 'the third task of the rig'
rigAssert "asked again after a member's own post of it: a new message of the bot's, never a reply in that thread" \
	"$( rigPostedAs "$rigAgainPost" ):$( rigCallsAs chat.postMessage "$rigOwnToken" ):$( LC_ALL=C grep -c -F '"thread_ts"' "$rigScenarioDir/post.$rigAgainPost" 2>/dev/null ):$( rigSeededAs "$rigBotToken" "000${rigAgainPost}01" )" "$rigBotToken:0:0:1:1:1"
rigAssert "and its record says the bot asked"          "$( rigRecordsAskedAs bot ):$( rigRecordsAskedAs member )" "1:2"

echo "-- who a permission goes to is settled as it is asked: a member who does not hold the call is not asked --"
## Named in a thread, a member that holds nothing of the refused call, and nobody running in the
## session holds it: the question goes to the human-owner, by the team bot, and the result says so.
rigStart permission-routed
rigThread 000101 "$( rigReactions "$rigBoth" one )" ""
rigPermissionAsk /dev/null/rig-forms/permission-routed '"to":"CRIG00001:1700000001.000001","address_to":"magic-coordinator"'
rigAssert "the result says who it went to instead of the one named, and why, in one NOTE line" \
	"$( LC_ALL=C grep -c -x -F 'NOTE: addressed to human-owner, not magic-coordinator: magic-coordinator does not hold Write /dev/null/rig-forms/permission-routed, and nobody running in this session holds it' "$rigScenarioDir/out" ):$( LC_ALL=C grep -c '^NOTE: addressed to ' "$rigScenarioDir/out" )" "1:1"
rigAssert "it goes to the human-owner as the team bot's post, in the bot's conversation with the owner, not in the thread named" \
	"$( rigPostedAs 1 ):$( rigHolds "$rigScenarioDir/post.1" '"channel":"URIGOWNER"' ):$( LC_ALL=C grep -c -F '"thread_ts"' "$rigScenarioDir/post.1" 2>/dev/null )" "$rigBotToken:yes:0"
rigAssert "its record says the bot asked the human-owner, and its emoji are placed under the bot's token" \
	"$( rigRecordField ask-identity ):$( rigRecordField address-to ) $( rigSeededAs "$rigBotToken" 000101 )" "bot:human-owner 1:1:1"
rigAssert "and the owner's click is the answer"        "$rigKilled:$( rigVerdictLine )" "no:VERDICT: allow-once"

echo "-- a refusal names an ask already open that would allow the call --"
## The line of a refusal that follows its REFUSAL-ID line.
rigAfterRefusalId(){
	LC_ALL=C awk 'seenId { print ; exit ; } /^REFUSAL-ID: / { seenId = 1 ; }' "$rigScenarioDir/out" 2>/dev/null
}
rigStart refusal-open-ask
rigOpenPath="/dev/null/rig-forms/refusal-open-ask"
rigCall 60 Write "{\"path\":\"$rigOpenPath\",\"content\":\"x\"}"
rigOpenRefusal="$( rigRefusal "$rigScenarioDir/out" )"
[ -n "$rigOpenRefusal" ] || rigRefuse "the rig produced no refusal to ask permission for"
rigAssert "with no ask open, a refusal names none: the way to ask follows its id, as before" \
	"$( LC_ALL=C grep -c 'is already open' "$rigScenarioDir/out" ):$( rigAfterRefusalId | cut -c1-33 )" "0:This is a refusal, not a verdict."
rigThread 000101 "" ""
rigCall 8 RequestPermission "{$rigAsk,\"question\":\"May the rig write this file?\",\"refusal_id\":\"$rigOpenRefusal\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}" from-read
rigOpenId="$( rigRecordId )"
rigAssert "control: its permission is asked, and nobody has answered" "$rigKilled:$( rigRecordField status )" "yes:reply-pending"
rigCall 60 Write "{\"path\":\"$rigOpenPath\",\"content\":\"x\"}"
rigAssert "refused again while that ask is open: the refusal names it, right after its id" \
	"$( rigAfterRefusalId )" "An ask that would allow this call is already open: $rigOpenId (a permission, waiting on URIGOWNER). Do not ask again: wait for its answer with Wait sources=ask:$rigOpenId, then retry the call."
rigAssert "once, and the way to ask still follows"     "$( LC_ALL=C grep -c 'is already open' "$rigScenarioDir/out" ):$( rigHolds "$rigScenarioDir/out" 'This is a refusal, not a verdict.' )" "1:yes"
rigCall 60 Write "{\"path\":\"$rigOpenPath-other\",\"content\":\"x\"}"
rigAssert "the refusal of another call names no ask"   "$( LC_ALL=C grep -c 'is already open' "$rigScenarioDir/out" ):$( rigAfterRefusalId | cut -c1-33 )" "0:This is a refusal, not a verdict."

echo "-- returned, then the answer: the next reply or click that names one is the answer --"
## A refused write, then its permission asked of the owner; the thread is scripted by the caller.
rigReturnedAsk(){ ## scenario name
	rigStart "$1"
	rigCall 60 Write "{\"path\":\"/dev/null/rig-forms/$1\",\"content\":\"x\"}"
	rigReturnedRefusal="$( rigRefusal "$rigScenarioDir/out" )"
	[ -n "$rigReturnedRefusal" ] || rigRefuse "the rig produced no refusal to ask permission for"
}
rigReturnedCall(){ ## the first ask
	rigCall 60 RequestPermission "{$rigAsk,\"question\":\"May the rig write this file?\",\"refusal_id\":\"$rigReturnedRefusal\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}"
}
rigReturnedAgain(){ ## the wait on the same question again
	rigCall 60 RequestPermission "{\"pending_id\":\"$( rigRecordId )\"}"
}
rigReturnedGrants(){
	LC_ALL=C awk 'END { print NR + 0 ; }' "$rigScenarioDir/ws/.local/agents/sessions/rig-forms-$rigScenarioName/grants" 2>/dev/null || printf 0
}
rigAskedWhy="$( rigMessage 000200 URIGOWNER 'What is the file for?' )"
rigReturnedAsk returned-then-reply
rigThread 000101 "" "$rigAskedWhy"
rigReturnedCall
rigAssert "a reply that names no answer returns the permission, still open, nothing granted" "$( rigVerdictLine ):$( rigRecordField status ):$( rigReturnedGrants )" "VERDICT: RETURNED:reply-pending:0"
rigThread 000101 "" "$rigAskedWhy$( rigMessage 000300 URIGOWNER 'allow-once' )"
rigReturnedAgain
rigAssert "returned, then an answer by reply: it is the answer, with its grant" "$( rigVerdictLine ):$( rigRecordField status ):$( rigReturnedGrants )" "VERDICT: allow-once:reply-received:1"
rigReturnedAsk returned-then-click
rigThread 000101 "" "$rigAskedWhy"
rigReturnedCall
rigAssert "control: returned first"                    "$( rigVerdictLine )" "VERDICT: RETURNED"
rigThread 000101 "$( rigReactions "$rigBoth" repeat )" "$rigAskedWhy"
rigReturnedAgain
rigAssert "returned, then an answer by click: it is the answer, with its grant" "$( rigVerdictLine ):$( rigRecordField status ):$( rigReturnedGrants )" "VERDICT: allow-session:reply-received:1"
rigReturnedAsk returned-twice
rigThread 000101 "" "$rigAskedWhy"
rigReturnedCall
rigThread 000101 "" "$rigAskedWhy$( rigMessage 000300 URIGOWNER 'And who asked for it?' )"
rigReturnedAgain
rigAssert "a second reply that names no answer returns it again, still open" "$( rigVerdictLine ):$( rigRecordField status )" "VERDICT: RETURNED:reply-pending"
rigThread 000101 "" "$rigAskedWhy$( rigMessage 000300 URIGOWNER 'And who asked for it?' )$( rigMessage 000400 URIGOWNER 'deny' )"
rigReturnedAgain
rigAssert "returned twice, then an answer: it is the answer, and nothing is granted" "$( rigVerdictLine ):$( rigRecordField status ):$( rigReturnedGrants )" "VERDICT: deny:reply-received:0"
## The live fault: an answer a member gave by reply. Every member message starts with the send
## header, and its mark was read as the reply's first word, so the answer named nothing.
rigHeader=':mouse: *_magic-coordinator_* @dispatchr → <@URIGSELF1>.'
rigReturnedAsk returned-then-member
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER "$rigHeader this is not decided yet. Do not wait on it." )"
rigReturnedCall
rigAssert "a member's reply that names no answer returns it" "$( rigVerdictLine )" "VERDICT: RETURNED"
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER "$rigHeader this is not decided yet. Do not wait on it." )$( rigMessage 000300 URIGOWNER "$rigHeader allow-once. The owner decided: yes, for this one write." )"
rigReturnedAgain
rigAssert "then the same member's reply naming an answer after its send header is the answer" "$( rigVerdictLine ):$( rigRecordField status ):$( rigReturnedGrants )" "VERDICT: allow-once:reply-received:1"

## A refused target is shown to a person by its location root, <place>:<relative path>, where
## it lies in a registered place, with no absolute path beside it. The refusal is recorded
## for a path in the scenario's own workspace, registered as the place rig-ws.
rigPlaceRefusal(){ ## file name under the workspace's OUT -> the refusal id recorded for it
	printf '%s\t%s\t%s\t%s\t%s\n' rig-ws workspace read-write "$rigScenarioDir/ws" workspace > "$rigScenarioDir/ws/.local/agents/directories.registry"
	( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT MDAT_SPAWN_SESSION_ID="rig-forms-$rigScenarioName" MDAT_SPAWN_AGENT="$rigMember" \
		RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" \
		--intern-op-permission-refusal-log "$rigMember" --session-id "rig-forms-$rigScenarioName" --tool Write --target "$rigScenarioDir/ws/OUT/$1" --reason rig 2>/dev/null ) \
		| LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' | head -1
}
for rigPlaceTool in RequestPermission ; do
	rigStart "permission-place-$rigPlaceTool"
	rigPlaceId="$( rigPlaceRefusal place.txt )"
	[ -n "$rigPlaceId" ] || rigRefuse "the rig recorded no refusal in its registered place"
	rigThread 000101 "$( rigReactions "$rigBoth" one )" ""
	rigCall 60 "$rigPlaceTool" "{$rigAsk,\"question\":\"May the rig write this file?\",\"refusal_id\":\"$rigPlaceId\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}"
	rigAssert "$rigPlaceTool: the refused target is shown by its place, and no absolute path is in the post" \
		"$( rigHolds "$rigScenarioDir/post.1" ' on `rig-ws:OUT/place.txt` for ' ):$( LC_ALL=C grep -c -F "$rigScenarioDir/ws/OUT" "$rigScenarioDir/post.1" )" "yes:0"
	rigAssert "$rigPlaceTool: the grant is still written for the exact path the record keeps" \
		"$( rigVerdictLine ):$( LC_ALL=C grep -c -F "$rigScenarioDir/ws/OUT/place.txt" "$rigScenarioDir/ws/.local/agents/sessions/rig-forms-permission-place-$rigPlaceTool/$rigPlaceId.md" )" "VERDICT: allow-once:1"
done

echo "-- what became of a refusal is posted to event-track: a grant where it is written, a denial where it is applied --"
## Posts that hold one text, and whether one of them sits in a thread.
rigPostsWith(){ ## fixed text
	local postCount=0 postFile
	for postFile in "$rigScenarioDir"/post.[0-9]* ; do
		[ -f "$postFile" ] || continue
		LC_ALL=C grep -q -F -- "$1" "$postFile" && postCount=$(( postCount + 1 ))
	done
	printf '%s' "$postCount"
}
rigPostWith(){ ## fixed text -> the first post file holding it
	local postFile
	for postFile in "$rigScenarioDir"/post.[0-9]* ; do
		[ -f "$postFile" ] || continue
		LC_ALL=C grep -q -F -- "$1" "$postFile" && { printf '%s' "$postFile" ; return 0 ; }
	done
	printf '%s' "$rigScenarioDir/no-such-post"
}
## A refused write with event-track configured, then the permission asked for by click:
## the refusal is the first post and opens the session's tracking-thread, the question the second.
rigTracked(){ ## scenario name, the emoji the owner clicks, ...
	local trackedName="$1"
	shift
	rigStart "$trackedName"
	printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n' >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	rigCall 60 Write "{\"path\":\"/dev/null/rig-forms/$trackedName\",\"content\":\"x\"}"
	rigThread 000201 "$( rigReactions "$rigBoth" "$@" )" ""
	rigCall 60 RequestPermission "{$rigAsk,\"question\":\"May the rig write this file?\",\"refusal_id\":\"$( rigRefusal "$rigScenarioDir/out" )\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}"
}
rigTracked track-allow-once one
rigAssert "the refusal post names the member whose call it was" "$( rigHolds "$rigScenarioDir/post.1" 'member: magic-tester' )" yes
rigAssert "allow-once by click"                        "$( rigVerdictLine )" "VERDICT: allow-once"
rigAssert "exactly one grant post"                     "$( rigPostsWith '✅ permission granted' )" 1
rigAssert "it sits in the session's tracking-thread, where the refusal is" "$( rigHolds "$( rigPostWith '✅ permission granted' )" '"thread_ts":"1700000001.000101"' )" yes
rigAssert "it names the call"                          "$( rigHolds "$( rigPostWith '✅ permission granted' )" "target: \`/dev/null/rig-forms/track-allow-once\`" )" yes
rigAssert "who granted it, by name, whose call it was, and its scope" "$( rigHolds "$( rigPostWith '✅ permission granted' )" 'granted by: human-owner · member: magic-tester · scope: once' )" yes
rigAssert "nobody is named as asked when the one asked answered" "$( rigHolds "$( rigPostWith '✅ permission granted' )" 'asked:' )" no
rigAssert "and no denial post"                         "$( rigPostsWith '❌ permission denied' )" 0
rigTracked track-allow-session repeat
rigAssert "allow-session by click"                     "$( rigVerdictLine )" "VERDICT: allow-session"
rigAssert "exactly one grant post"                     "$( rigPostsWith '✅ permission granted' )" 1
rigAssert "its scope is this session"                  "$( rigHolds "$( rigPostWith '✅ permission granted' )" 'granted by: human-owner · member: magic-tester · scope: this session' )" yes
rigTracked track-deny x
rigAssert "deny by click"                              "$( rigVerdictLine )" "VERDICT: deny"
rigAssert "exactly one denial post"                    "$( rigPostsWith '❌ permission denied' )" 1
rigAssert "in the session's tracking-thread"           "$( rigHolds "$( rigPostWith '❌ permission denied' )" '"thread_ts":"1700000001.000101"' )" yes
rigAssert "who denied it and whose call it was, with no scope" "$( rigHolds "$( rigPostWith '❌ permission denied' )" 'denied by: human-owner · member: magic-tester' ):$( rigHolds "$( rigPostWith '❌ permission denied' )" 'scope:' )" "yes:no"
rigAssert "and no grant post, and no grant"            "$( rigPostsWith '✅ permission granted' ):$( [ -s "$rigScenarioDir/ws/.local/agents/sessions/rig-forms-track-deny/grants" ] && printf granted || printf none )" "0:none"
rigStart track-post-fails
printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n' >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
printf 'permission granted\n' > "$rigScenarioDir/post-refuse-matching"
rigCall 60 Write "{\"path\":\"/dev/null/rig-forms/track-post-fails\",\"content\":\"x\"}"
rigThread 000201 "$( rigReactions "$rigBoth" one )" ""
rigCall 60 RequestPermission "{$rigAsk,\"question\":\"May the rig write this file?\",\"refusal_id\":\"$( rigRefusal "$rigScenarioDir/out" )\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}"
rigAssert "a grant post that fails leaves the verdict applied" "$( rigVerdictLine )" "VERDICT: allow-once"
rigAssert "and the grant written"                      "$( LC_ALL=C grep -c '^GRANT: once ' "$rigScenarioDir/out" )" 1
rigAssert "with no grant post made"                    "$( rigPostsWith '✅ permission granted' )" 0

echo "-- one event-track thread per session, in one record; its feed switched by its own marker --"
rigSessionDir(){
	printf '%s' "$rigScenarioDir/ws/.local/agents/sessions/rig-forms-$rigScenarioName"
}
rigTrackStart(){ ## scenario name
	rigStart "$1"
	printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n' >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	mkdir -p "$( rigSessionDir )"
}
## A session started under the rule: its start post recorded the thread, and switched its feed on.
rigTrackStart track-after-start
printf 'CRIGTRACK:1700000001.000050\n' > "$( rigSessionDir )/event-track.thread"
: > "$( rigSessionDir )/feed.open"
rigCall 60 Write "{\"path\":\"/dev/null/rig-forms/track-after-start\",\"content\":\"x\"}"
rigAssert "a refusal after a start post is a reply in the start post's thread" "$( rigHolds "$rigScenarioDir/post.1" '"thread_ts":"1700000001.000050"' )" yes
rigThread 000201 "$( rigReactions "$rigBoth" one )" ""
rigCall 60 RequestPermission "{$rigAsk,\"question\":\"May the rig write this file?\",\"refusal_id\":\"$( rigRefusal "$rigScenarioDir/out" )\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}"
rigAssert "the grant lands in that same thread"        "$( rigHolds "$( rigPostWith '✅ permission granted' )" '"thread_ts":"1700000001.000050"' )" yes
rigAssert "the record still names that one thread"     "$( cat "$( rigSessionDir )/event-track.thread" 2>/dev/null )" "CRIGTRACK:1700000001.000050"
rigFeedSwitch(){ ## -> on|off, as every writer of the feed asks
	( . "$rigHere/session/AgentsTools.EventTrackThread.include" ; AgentsToolsEventTrackFeedOn "$( rigSessionDir )" && printf on || printf off )
}
rigAssert "its feed is on by its own marker, and nothing writes the old file" "$( rigFeedSwitch ):$( [ -e "$( rigSessionDir )/event-track" ] && printf old-file || printf none )" "on:none"
## A session running since before the rule: one file was both its thread and its feed switch.
rigTrackStart track-from-before
printf 'CRIGTRACK:1700000001.000060\n' > "$( rigSessionDir )/event-track"
rigCall 60 Write "{\"path\":\"/dev/null/rig-forms/track-from-before\",\"content\":\"x\"}"
rigAssert "a session from before the rule: the refusal is a reply in its start post's thread" "$( rigHolds "$rigScenarioDir/post.1" '"thread_ts":"1700000001.000060"' )" yes
rigAssert "nothing it holds is rewritten: its file stays, and no record is written beside it" "$( cat "$( rigSessionDir )/event-track" 2>/dev/null ):$( [ -e "$( rigSessionDir )/event-track.thread" ] && printf written || printf none )" "CRIGTRACK:1700000001.000060:none"
rigAssert "and its feed is still on, by the file that switched it then" "$( rigFeedSwitch )" on
## The same, where a refusal had already opened a second thread beside it: the start post's wins.
rigTrackStart track-two-before
printf 'CRIGTRACK:1700000001.000060\n' > "$( rigSessionDir )/event-track"
printf 'CRIGTRACK:1700000001.000070\n' > "$( rigSessionDir )/event-track.thread"
rigCall 60 Write "{\"path\":\"/dev/null/rig-forms/track-two-before\",\"content\":\"x\"}"
rigAssert "two threads from before the rule: the start post's is the session's, and neither file is rewritten" "$( rigHolds "$rigScenarioDir/post.1" '"thread_ts":"1700000001.000060"' ):$( cat "$( rigSessionDir )/event-track" 2>/dev/null ):$( cat "$( rigSessionDir )/event-track.thread" 2>/dev/null )" "yes:CRIGTRACK:1700000001.000060:CRIGTRACK:1700000001.000070"
## The first record stands, whoever asks to record a second one: no path opens a second thread.
rigAssert "a thread recorded for a session that has one changes nothing, and the one it has is given back" \
	"$( . "$rigHere/session/AgentsTools.EventTrackThread.include" ; AgentsToolsEventTrackThreadRecord "$( rigSessionDir )" 'CRIGTRACK:1700000001.000999' ):$( cat "$( rigSessionDir )/event-track.thread" 2>/dev/null )" \
	"CRIGTRACK:1700000001.000060:CRIGTRACK:1700000001.000070"
## A session spawned before the rule with no feed has neither file: its start post's thread
## is in its spawn record alone, and its first refusal goes there instead of opening another.
rigTrackStart track-from-spawn-record
mkdir -p "$rigScenarioDir/ws/.local/agents/spawned/rig-box"
printf -- '---\nsession-id: rig-box\nspawn-id: rig-forms-track-from-spawn-record\nowner: %s\nstatus: spawn-started\nagent-log-thread: CRIGTRACK:1700000001.000080\n---\n\n# Spawn session\n' "$rigMember" \
	> "$rigScenarioDir/ws/.local/agents/spawned/rig-box/rig-forms-track-from-spawn-record.spawn.md"
rigCall 60 Write "{\"path\":\"/dev/null/rig-forms/track-from-spawn-record\",\"content\":\"x\"}"
rigAssert "a session with its thread in its spawn record alone: the refusal is a reply in that thread" "$( rigHolds "$rigScenarioDir/post.1" '"thread_ts":"1700000001.000080"' )" yes
rigCall 60 Write "{\"path\":\"/dev/null/rig-forms/track-from-spawn-record-b\",\"content\":\"x\"}"
rigAssert "and so is the next one: nothing is written into its store, and no feed is switched on" \
	"$( rigHolds "$rigScenarioDir/post.2" '"thread_ts":"1700000001.000080"' ):$( [ -e "$( rigSessionDir )/event-track.thread" ] && printf written || printf none ):$( rigFeedSwitch )" "yes:none:off"
rigStart track-no-start
printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n' >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
rigCall 60 Write "{\"path\":\"/dev/null/rig-forms/track-no-start-a\",\"content\":\"x\"}"
rigCall 60 Write "{\"path\":\"/dev/null/rig-forms/track-no-start-b\",\"content\":\"x\"}"
rigAssert "with no start post, the first refusal opens the session's thread" "$( LC_ALL=C grep -c -F '"thread_ts"' "$rigScenarioDir/post.1" )" 0
rigAssert "and the second refusal is a reply in it"    "$( rigHolds "$rigScenarioDir/post.2" '"thread_ts":"1700000001.000101"' )" yes
rigAssert "it is recorded once, as the session's thread" "$( cat "$rigScenarioDir/ws/.local/agents/sessions/rig-forms-track-no-start/event-track.thread" 2>/dev/null )" "CRIGTRACK:1700000001.000101"
rigAssert "and it switches no feed on: nothing is kept for a poster that is not there" \
	"$( rigFeedSwitch ):$( [ -e "$( rigSessionDir )/feed" ] && printf kept || printf none )" "off:none"
rigThread 000301 "$( rigReactions "$rigBoth" one )" ""
rigCall 60 RequestPermission "{$rigAsk,\"question\":\"May the rig write this file?\",\"refusal_id\":\"$( rigRefusal "$rigScenarioDir/out" )\",\"reason\":\"the rig needs it\",\"task_ref\":\"dispatch-rig\"}"
rigAssert "a later grant lands in that same thread"    "$( rigHolds "$( rigPostWith '✅ permission granted' )" '"thread_ts":"1700000001.000101"' )" yes

echo "-- records and lines from before still read --"
rigAssert "a transcript line of the second name renders by its kind" \
	"$( LC_ALL=C awk -f "$rigHere/session/AgentsSessionTranscriptFormat.awk" -f /dev/stdin <<< 'BEGIN { print stlAskTool( "AskUserQuestion", "permission" ) " " stlAskTool( "AskUserQuestion", "" ) " " stlAskTool( "EscalateDecision", "" ) " [" stlAskTool( "Read", "" ) "]" ; }' )" \
	"RequestPermission AskQuestion EscalateDecision []"
rigAssert "the verdict reader says RETURNED where a reply names none of the answers" \
	"$( printf '1700000001.000200 | URIGOWNER | maybe\n' | MDAT_VERDICT_KIND=decision MDAT_VERDICT_OPTIONS=$'alpha\nbeta' MDAT_VERDICT_AUTHORS=URIGOWNER LC_ALL=C awk -f "$rigHere/questions/AgentsEscalationVerdict.awk" | cut -f1 )" "RETURNED"
## A read that still answers with the word before it (UNCLASSIFIED), as a tools copy from
## before the change prints it: the harness takes it as RETURNED. The read is the real one,
## reached through an origin of links whose one own file gives its verdict line the old word.
rigOldOrigin="$rigTmp/origin-old-word"
rigOldPackage="$rigOldOrigin/myx/myx.distro-agents"
mkdir -p "$rigOldPackage/sh-scripts" || rigRefuse "the rig origin could not be made"
rigLinkAll(){ ## from directory, to directory, the one name left out
	local linkEntry
	for linkEntry in "$1"/* ; do
		[ -e "$linkEntry" ] || continue
		[ "${linkEntry##*/}" != "$3" ] || continue
		ln -s "$linkEntry" "$2/${linkEntry##*/}" || rigRefuse "the rig origin could not link ${linkEntry##*/}"
	done
}
rigLinkAll "$MDLT_ORIGIN" "$rigOldOrigin" myx
rigLinkAll "$MDLT_ORIGIN/myx" "$rigOldOrigin/myx" myx.distro-agents
rigLinkAll "$MDLT_ORIGIN/myx/myx.distro-agents" "$rigOldPackage" sh-scripts
rigLinkAll "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts" "$rigOldPackage/sh-scripts" DistroAgentsTools.fn.sh
{
	printf '#!/usr/bin/env bash\n'
	printf 'export MDLT_ORIGIN=%q\n' "$MDLT_ORIGIN"
	printf '%s\n' 'rigReal="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"' \
		'if [ "${1:-}" = "--wait-for-input" ] && [ -f "$RIG_SCENARIO/odd-wait" ] ; then "$rigReal" "$@" | LC_ALL=C sed "1s/.*/WAIT-RESULT: REWOUND/" ; exit 0 ; fi' \
		'[ "${1:-}" = "--intern-op-escalation-read" ] || exec "$rigReal" "$@"' \
		'rigOut="$( "$rigReal" "$@" )"' \
		'rigRc=$?' \
		'case "$rigOut" in *"VERDICT: RETURNED"*) printf "%s\n" "$2" >> "$RIG_SCENARIO/old-word-reads" ;; esac' \
		'printf "%s\n" "$rigOut" | LC_ALL=C sed "s/^VERDICT: RETURNED\$/VERDICT: UNCLASSIFIED/"' \
		'exit "$rigRc"'
} > "$rigOldPackage/sh-scripts/DistroAgentsTools.fn.sh"
chmod +x "$rigOldPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigStart old-word-read
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'none of these' )"
MDLT_ORIGIN="$rigOldOrigin" rigCall 60 EscalateDecision "{$rigAsk,\"question\":\"Which check first?\",$rigOptions}"
rigAssert "the read answered with the word before it"  "$( rigHolds "$rigScenarioDir/old-word-reads" "$rigMember" )" yes
rigAssert "and the harness gives it back as RETURNED, the old word nowhere in its result" "$( rigVerdictLine ):$( rigHolds "$rigScenarioDir/out" UNCLASSIFIED )" "VERDICT: RETURNED:no"
rigAssert "with the ways on, and the record open"      "$( rigHolds "$rigScenarioDir/out" "- update: EscalateDecision pending_id=$( rigRecordId ) revise=true" ):$( rigRecordField status )" "yes:reply-pending"

echo "-- every outcome of the wait is reported as itself, and none is named UNCLASSIFIED --"
## A dismissal of the asker, where its answer was waited for: an outcome of its own.
rigStart outcome-dismissed
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER "DISMISSED $rigMember" )"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Should the rig go on?\"}"
rigAssert "a dismissal where the answer was waited for is ASK-RESULT: DISMISSED" "$rigKilled:$( rigFirstLine "$rigScenarioDir/out" )" "no:ASK-RESULT: DISMISSED"
rigAssert "it says no answer was collected, that the question stays open, and how to discard it" \
	"$( rigHolds "$rigScenarioDir/out" "You were dismissed where this answer was waited for, so none was collected here. Pending reply $( rigRecordId ) stays open, and is answered or withdrawn as any other: AskQuestion pending_id=$( rigRecordId ) withdraw=<why> discards it where it is no longer needed." ):$( rigRecordField status )" "yes:reply-pending"
rigAssert "its last line is the dismissal's own next step" "$( LC_ALL=C awk 'END { print ; }' "$rigScenarioDir/out" )" "NEXT: you are dismissed -- give your handback if you have not, then end your run"
rigAssert "and it names who dismissed it, as the wait said" "$( LC_ALL=C grep -c '^WAIT-DISMISSED-BY: 1700000001.000200 | URIGOWNER' "$rigScenarioDir/out" )" 1
## A first line the tool does not know, as a wait of another version might give: an ERROR that
## quotes it, the question left open with the way to wait for it.
rigStart outcome-unknown
: > "$rigScenarioDir/odd-wait"
rigThread 000101 "" "$( rigMessage 000200 URIGOWNER 'yes, go on' )"
MDLT_ORIGIN="$rigOldOrigin" rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Should the rig go on?\"}"
rigAssert "a first line the tool does not know is an ERROR that quotes it" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" )" \
	"no:ERROR: AskQuestion: the wait on pending reply $( rigRecordId ) returned a first line this tool does not know, so NOTHING is known about whether it was answered, and its record is left as it was. That line: \"WAIT-RESULT: REWOUND\""
rigAssert "the record is left open, and the result names the way to wait for the answer" \
	"$( rigRecordField status ):$( LC_ALL=C grep -c -x -F "WAIT-ID: ask:$( rigRecordId )" "$rigScenarioDir/out" ):$( LC_ALL=C grep -c '^NEXT: ' "$rigScenarioDir/out" )" "reply-pending:1:1"
rigAssert "no result of this check names an outcome UNCLASSIFIED" "$( cat "$rigTmp"/*/out 2>/dev/null | LC_ALL=C grep -c 'UNCLASSIFIED' )" 0
rigAssert "and the tool description names every outcome it can give" \
	"$( for rigOutcome in RECEIVED POSTED ALREADY-OPEN DISMISSED TIMEOUT CLOSED CLARIFIED ; do LC_ALL=C grep -q -F "ASK-RESULT: $rigOutcome" "$rigHere/harness/AgentsOpenAiChatWire.sh" || printf 'missing:%s ' "$rigOutcome" ; done ):$( LC_ALL=C grep -c 'UNCLASSIFIED' "$rigHere/harness/AgentsOpenAiChatWire.sh" )" ":0"

echo "-- the plain-language floor: a correction to make, never a refusal or a denial --"
rigLong='one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twentyone twentytwo twentythree twentyfour twentyfive twentysix.'
rigFloorSend(){ ## message, as a JSON string body
	rigCall 30 SendMessage "{\"to\":\"magic-team\",\"message\":\"$1\"}"
}
rigStart floor-send
rigFloorSend "$rigLong And a second fault; here."
rigAssert "a message over a limit is not sent, and the result opens with the word CORRECTION" "$( rigFirstLine "$rigScenarioDir/out" | cut -c1-12 ):$( rigCalls chat.postMessage )" "CORRECTION: :0"
rigAssert "its first line says it was not sent and must be corrected and sent again" "$( rigHolds "$rigScenarioDir/out" 'CORRECTION: the message was NOT sent and must be corrected and sent again.' )" yes
rigAssert "then one line for each fault: the limit, and the sentence it fired on" \
	"$( LC_ALL=C grep -c '^- word-cap: 26 words against a cap of 25: one two three' "$rigScenarioDir/out" ):$( LC_ALL=C grep -c -x -F -- '- semicolon: a semicolon, which this floor does not allow: And a second fault; here' "$rigScenarioDir/out" ):$( LC_ALL=C grep -c '^- ' "$rigScenarioDir/out" )" "1:1:2"
rigAssert "then a NEXT line, the last"                 "$( LC_ALL=C awk 'END { print ; }' "$rigScenarioDir/out" )" "NEXT: rewrite these and send again"
rigAssert "it is worded as no refusal, no denial and no error" "$( LC_ALL=C grep -c -i -e '^ERROR' -e 'refused' -e 'denied' "$rigScenarioDir/out" )" 0
rigFloorThird="" ; rigFloorTenth=""
for rigAttempt in 2 3 4 5 6 7 8 9 10 ; do
	rigFloorSend "$rigLong And a second fault; here."
	[ "$rigAttempt" != 3 ] || rigFloorThird="$( cat "$rigScenarioDir/out" )"
	[ "$rigAttempt" != 10 ] || rigFloorTenth="$( cat "$rigScenarioDir/out" )"
done
rigAssert "the same message comes back the same on the third and the tenth attempt, and is never sent" \
	"$( printf '%s' "$rigFloorThird" | cut -c1-12 | head -1 ):$( [ "$rigFloorThird" = "$rigFloorTenth" ] && printf same || printf differs ):$( printf '%s\n' "$rigFloorTenth" | LC_ALL=C grep -c '^- ' ):$( rigCalls chat.postMessage )" "CORRECTION: :same:2:0"
rigFloorSend "One short sentence. And a second one, with no fault here."
rigAssert "corrected, the message is sent"             "$( rigHolds "$rigScenarioDir/out" 'SENT_MESSAGE_TS=' ):$( rigCalls chat.postMessage )" "yes:1"
rigStart floor-own-words
rigFloorSend "The owner said this.\\n> $rigLong And; more.\\n\\n\`\`\`\\n$rigLong ; x\\n\`\`\`\\n- /a/path;with/a/semicolon\\n\\nA short end."
rigAssert "a quoted line, a code block and a bare path over the limits do not hold a message back" "$( rigHolds "$rigScenarioDir/out" 'SENT_MESSAGE_TS=' ):$( rigCalls chat.postMessage )" "yes:1"
rigFloorSend "The owner said this.\\n> a quote\\n\\n$rigLong"
rigAssert "the sender's own sentence beside a quote is still measured" "$( rigFirstLine "$rigScenarioDir/out" | cut -c1-12 ):$( LC_ALL=C grep -c '^- ' "$rigScenarioDir/out" ):$( rigCalls chat.postMessage )" "CORRECTION: :1:1"
rigAssert "the descriptions of the sending tools say correction, and none says a message is refused" \
	"$( LC_ALL=C grep -c -F 'starts with CORRECTION' "$rigHere/harness/AgentsOpenAiChatWire.sh" ):$( LC_ALL=C grep -c -F 'The send is refused' "$rigHere/harness/AgentsOpenAiChatWire.sh" ):$( LC_ALL=C grep -c -F 'a refusal or failure returns ERROR' "$rigHere/harness/AgentsOpenAiChatWire.sh" )" "2:0:0"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK FORMS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_FORMS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
