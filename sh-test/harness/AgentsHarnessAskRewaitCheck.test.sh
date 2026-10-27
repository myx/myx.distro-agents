#!/usr/bin/env bash
## The two re-wait edges AgentsHarnessAskCheck does not cover: a re-wait from a resumed
## session (a new process under the same session id) is accepted while one from another
## session is refused, and the asker's own post naming a verdict is never the answer.
## Offline: the Slack-shaped ask fixture is first on PATH; each scenario has its own
## workspace under this rig's temp tree.
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
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessAskRewaitCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, text
	LC_ALL=C grep -q -F -- "$2" "$1" 2>/dev/null && printf yes || printf no
}
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null
}
rigVerdictLine(){
	LC_ALL=C awk '/^VERDICT: / { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-verdict-line" ; } }' "$rigScenarioDir/out"
}
rigRecordFile(){ ## pending id -- its record's path, open or retained-closed
	## A closed record is retained, not deleted: it moves into pending/closed/
	## (AgentsTools.InternOpPendingReply.include), so both are tried; where neither exists the
	## open path is returned, so a missing record reads exactly as before.
	local rf
	for rf in "$rigScenarioDir/ws/.local/agents/pending/$1.md" "$rigScenarioDir/ws/.local/agents/pending/closed/$1.md" ; do
		[ -f "$rf" ] && { printf '%s' "$rf" ; return 0 ; }
	done
	printf '%s' "$rigScenarioDir/ws/.local/agents/pending/$1.md"
}
rigRecordId(){ ## -- the id of the scenario's record, open or retained-closed
	## A closed record is retained, not deleted: it moves into pending/closed/
	## (AgentsTools.InternOpPendingReply.include), so both stores are listed, the live one
	## first, and an id read after a close is still found.
	{ ls "$rigScenarioDir/ws/.local/agents/pending" 2>/dev/null ; ls "$rigScenarioDir/ws/.local/agents/pending/closed" 2>/dev/null ; } \
		| LC_ALL=C sed -n 's/\.md$//p' | head -1
}
rigRecordField(){ ## pending id, field
	LC_ALL=C awk -v key="$2" '$0 == "---" { if ( ++fm == 2 ) exit ; next ; } fm == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; exit ; }' "$( rigRecordFile "$1" )" 2>/dev/null
}
rigRecordHolds(){ ## pending id, text
	rigHolds "$( rigRecordFile "$1" )" "$2"
}
rigRecordStatus(){
	LC_ALL=C awk -F': ' '$1 == "status" { print $2 ; exit ; }' "$( rigRecordFile "$rigRewaitId" )" 2>/dev/null
}

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
## The thread: the question, its root, then the scenario's later messages. The fixture's
## own account, URIGSELF1, is the asker's.
rigReplies(){ ## later messages (may be empty)
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"question"}%s],"has_more":false}\n' "$1" > "$rigScenarioDir/replies.json"
}
## One tool call under a stated session, in a process of its own, with a guard: an ask
## nobody answers waits by design, so the guard ends it and says so.
## The tool of the kind a payload names: a typed kind is asked by its own tool, which presets it, so the kind is not passed.
rigKindTool(){ ## argument object
	case "$1" in
		*'"kind":"readback"'*) printf 'ConfirmReadback' ;;
		*'"kind":"decision"'*) printf 'EscalateDecision' ;;
		*'"kind":"permission"'*) printf 'RequestPermission' ;;
		*) printf 'AskQuestion' ;;
	esac
}
rigKindStrip(){ ## argument object -- without its kind
	printf '%s' "$1" | LC_ALL=C sed -e 's/"kind":"[a-z]*",//' -e 's/,"kind":"[a-z]*"//'
}
rigKilled=""
rigAsk(){ ## session id, guard seconds, argument object, optional tool (default AskQuestion)
	local askPid askLeft="$2"
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && rigKindStrip "$3" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SPAWN_SESSION_ID="$1" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool "${4:-$( rigKindTool "$3" )}" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	askPid=$!
	set +m
	while kill -0 "$askPid" 2>/dev/null && [ "$askLeft" -gt 0 ] ; do sleep 1 ; askLeft=$(( askLeft - 1 )) ; done
	if kill -0 "$askPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$askPid" ; sleep 1 ; kill -KILL -- "-$askPid" ; wait "$askPid" ; } 2>/dev/null
	fi
	{ wait "$askPid" ; } 2>/dev/null || :
}
rigQuestion='May the rig write the refused report file?'

echo "-- a resumed session may re-wait; another session may not --"
rigStart resumed
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"let me think","thread_ts":"1700000001.000101"}'
rigAsk rig-session-a 60 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"allow-once -- let it write\\ndeny -- keep it refused\"}"
rigAssert "the first reply is RETURNED"                "$( rigVerdictLine )" "VERDICT: RETURNED"
rigRewaitId="$( LC_ALL=C sed -n 's/^[A-Za-z]* pending_id=//p' "$rigScenarioDir/out" | tail -1 )"
[ -n "$rigRewaitId" ] || rigRefuse "no re-wait line came back, so nothing below would be measured"
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"let me think","thread_ts":"1700000001.000101"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"deny","thread_ts":"1700000001.000101"}'
rigAsk rig-session-b 30 "{\"pending_id\":\"$rigRewaitId\"}"
rigAssert "another session's re-wait is refused"       "$( rigHolds "$rigScenarioDir/out" "ERROR: AskQuestion: pending reply $rigRewaitId belongs to session rig-session-a, not this one" )" yes
rigAssert "and the record stays open"                  "$( rigRecordStatus )" reply-pending
rigPostsBefore="$( rigCalls chat.postMessage )"
rigAsk rig-session-a 30 "{\"pending_id\":\"$rigRewaitId\"}"
rigAssert "control: the same session in a new process is accepted" "$( rigVerdictLine )" "VERDICT: deny"
rigAssert "the re-wait posts nothing itself: its one post is the confirmation reply of the answer it applied" \
	"$(( $( rigCalls chat.postMessage ) - rigPostsBefore )):$( rigHolds "$rigScenarioDir/post.$( cat "$rigScenarioDir/posts" 2>/dev/null )" '✅ Read: `deny` by' )" "1:yes"
rigAssert "and the record closed as received"          "$( rigRecordStatus )" reply-received

echo "-- the asker's own post is never the answer --"
rigStart asker-post
rigReplies ',{"ts":"1700000001.000200","user":"URIGSELF1","text":"allow-once","thread_ts":"1700000001.000101"}'
rigAsk rig-session-c 12 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"allow-once -- let it write\\ndeny -- keep it refused\"}"
rigAssert "a thread holding only the asker's own verdict-shaped post is still waited on" "$rigKilled" yes
rigAssert "no verdict was taken from it"               "$( rigVerdictLine )" "no-verdict-line"
rigRewaitId="$( rigRecordId )"
rigAssert "the record stays open"                      "$( rigRecordStatus )" reply-pending
rigReplies ',{"ts":"1700000001.000200","user":"URIGSELF1","text":"allow-once","thread_ts":"1700000001.000101"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"deny","thread_ts":"1700000001.000101"}'
rigAsk rig-session-c 30 "{\"pending_id\":\"$rigRewaitId\"}"
rigAssert "control: the addressee's later answer is the verdict" "$( rigVerdictLine )" "VERDICT: deny"

## The record with what differs between two runs of the same ask -- its id, its clock and whether a quiet round reminded it -- written out.
rigRecordShape(){ ## scenario directory
	local shapeFile shapeId
	for shapeFile in "$1/ws/.local/agents/pending"/*.md "$1/ws/.local/agents/pending/closed"/*.md ; do
		[ -f "$shapeFile" ] || continue
		shapeId="${shapeFile##*/}" ; shapeId="${shapeId%.md}"
		LC_ALL=C sed -E -e '/^(reminder-30m|reminder-2h|reminders|last-reminder-at): /d' -e "s/$shapeId/<id>/g" -e 's/rig-session-[a-z]/<session>/g' -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9:.]+Z?/<time>/g' -e 's/(^|[^0-9.])[0-9]{10}([^0-9.]|$)/\1<epoch>\2/g' "$shapeFile"
		return 0
	done
	printf 'no-record'
}
rigWaitSet(){ ## scenario directory, session id
	LC_ALL=C sed -n 's/^sources: //p' "$1/ws/.local/agents/sessions/$2/wait/state" 2>/dev/null | head -1
}
rigAnswer=',{"ts":"1700000001.000200","user":"URIGOWNER","text":"RIG-ANSWER-MARKER","thread_ts":"1700000001.000101"}'

echo "-- a posted ask joins the session's Wait set, and Wait takes its answer into the record --"
rigStart own-wait
rigReplies "$rigAnswer"
rigAsk rig-session-d 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\"}"
rigAssert "control: the ask's own wait takes the answer" "$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT: RECEIVED' )" yes
rigAssert "control: and the answered item stays in the Wait set" "$( rigWaitSet "$rigScenarioDir" rig-session-d )" "replies:rig-session-d chat:rig-session-d ask:$( rigRecordId ) "
rigStart posted-wait
rigReplies ""
rigAsk rig-session-d 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"wait\":false}"
rigRewaitId="$( LC_ALL=C sed -n 's/^WAIT-ID: ask://p' "$rigScenarioDir/out" | tail -1 )"
[ -n "$rigRewaitId" ] || rigRefuse "no WAIT-ID line came back from a posted ask, so nothing below would be measured"
rigAssert "the posted ask is POSTED"                   "$( LC_ALL=C head -1 "$rigScenarioDir/out" )" "ASK-RESULT: POSTED"
rigAssert "its NEXT: says only to call Wait"           "$( LC_ALL=C awk 'END { print ; }' "$rigScenarioDir/out" )" "NEXT: call Wait"
rigAssert "its wait item is in the session's Wait set" "$( rigWaitSet "$rigScenarioDir" rig-session-d )" "ask:$rigRewaitId "
rigAsk rig-session-x 30 "{\"sources\":\"ask:$rigRewaitId\"}" Wait
rigAssert "another session's Wait on it is refused"   "$( rigHolds "$rigScenarioDir/out" 'is a question asked by session rig-session-d' )" yes
rigAsk rig-session-d 30 '{"mode":"continue"}' Wait
rigAssert "Wait mode=continue, unanswered, times out" "$( LC_ALL=C head -1 "$rigScenarioDir/out" | LC_ALL=C sed 's/ (.*//' )" "WAIT-RESULT: TIMEOUT"
rigAssert "and the record stays open"                  "$( rigRecordStatus )" reply-pending
rigReplies "$rigAnswer"
rigAsk rig-session-d 30 '{"mode":"continue"}' Wait
rigAssert "Wait mode=continue returns the answer"      "$( LC_ALL=C head -1 "$rigScenarioDir/out" )" "WAIT-RESULT: RECEIVED"
rigAssert "it carries the answer text"                 "$( rigHolds "$rigScenarioDir/out" 'RIG-ANSWER-MARKER' )" yes
rigAssert "and takes it as the asking call would"      "$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT: RECEIVED' )" yes
rigAssert "the record closed as received"              "$( rigRecordStatus )" reply-received
rigAssert "the record is the one the ask's own wait leaves" "$( rigRecordShape "$rigScenarioDir" )" "$( rigRecordShape "$rigTmp/own-wait" )"
rigAssert "the answered item stays in the Wait set"    "$( rigWaitSet "$rigScenarioDir" rig-session-d )" "replies:rig-session-d chat:rig-session-d ask:$rigRewaitId "
rigAssert "its thread watched from the answer"         "$( LC_ALL=C awk -F': ' '$1 == "follow-floor" { print $2 ; exit ; }' "$( rigRecordFile "$rigRewaitId" )" )" "1700000001.000200"
rigAsk rig-session-d 30 "{\"pending_id\":\"$rigRewaitId\"}"
rigAssert "control: the pending_id re-wait sees it closed" "$( rigHolds "$rigScenarioDir/out" 'is closed' )" yes

echo "-- a direct answer: a later message in its thread arrives on Wait and is kept --"
rigReplies "$rigAnswer"',{"ts":"1700000001.000500","user":"URIGOWNER","text":"correction: keep a copy too","thread_ts":"1700000001.000101"}'
rigAsk rig-session-d 30 '{"mode":"continue"}' Wait
rigAssert "the later message arrives"                  "$( LC_ALL=C head -1 "$rigScenarioDir/out" )" "WAIT-RESULT: RECEIVED"
rigAssert "as a clarification on the answer"           "$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT: CLARIFIED' )$( rigHolds "$rigScenarioDir/out" 'correction: keep a copy too' )" yesyes
rigAssert "kept on the record"                         "$( rigHolds "$( rigRecordFile "$rigRewaitId" )" '- 1700000001.000500 URIGOWNER: correction: keep a copy too' )" yes
rigAssert "the answer itself is left as it was"        "$( LC_ALL=C awk -F': ' '$1 == "verdict" { print $2 ; exit ; }' "$( rigRecordFile "$rigRewaitId" )" )" "RIG-ANSWER-MARKER"
rigAssert "the follow floor stays at the answer"       "$( LC_ALL=C awk -F': ' '$1 == "follow-floor" { print $2 ; exit ; }' "$( rigRecordFile "$rigRewaitId" )" )" "1700000001.000200"
rigAsk rig-session-d 30 '{"mode":"continue"}' Wait
rigAssert "nothing new: the next Wait times out"       "$( LC_ALL=C head -1 "$rigScenarioDir/out" | LC_ALL=C sed 's/ (.*//' )" "WAIT-RESULT: TIMEOUT"

echo "-- a typed ask left RETURNED: a new Wait on its WAIT-ID takes the verdict --"
rigStart typed-wait
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"let me think","thread_ts":"1700000001.000101"}'
rigAsk rig-session-e 60 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"allow-once -- let it write\\ndeny -- keep it refused\"}"
rigAssert "the first reply is RETURNED"                "$( rigVerdictLine )" "VERDICT: RETURNED"
rigRewaitId="$( LC_ALL=C sed -n 's/^WAIT-ID: ask://p' "$rigScenarioDir/out" | tail -1 )"
rigAssert "it names its wait item"                     "$( [ -n "$rigRewaitId" ] && printf yes || printf no )" yes
rigAssert "the compatible re-wait line is still last"  "$( LC_ALL=C awk 'END { print ; }' "$rigScenarioDir/out" )" "EscalateDecision pending_id=$rigRewaitId"
rigAssert "the item stays in the Wait set"             "$( rigWaitSet "$rigScenarioDir" rig-session-e )" "replies:rig-session-e chat:rig-session-e ask:$rigRewaitId "
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"let me think","thread_ts":"1700000001.000101"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"deny","thread_ts":"1700000001.000101"}'
rigPostsBefore="$( rigCalls chat.postMessage )"
rigAsk rig-session-e 30 "{\"sources\":\"ask:$rigRewaitId\"}" Wait
rigAssert "a new Wait on the WAIT-ID returns the answer" "$( LC_ALL=C head -1 "$rigScenarioDir/out" )" "WAIT-RESULT: RECEIVED"
rigAssert "with the verdict the re-wait would take"    "$( rigVerdictLine )" "VERDICT: deny"
rigAssert "the Wait posts nothing itself: its one post is the confirmation reply of the answer it applied" \
	"$(( $( rigCalls chat.postMessage ) - rigPostsBefore )):$( rigHolds "$rigScenarioDir/post.$( cat "$rigScenarioDir/posts" 2>/dev/null )" '✅ Read: `deny` by' )" "1:yes"
rigAssert "the record closed as received"              "$( rigRecordStatus )" reply-received
rigAssert "and carries the verdict"                    "$( LC_ALL=C awk -F': ' '$1 == "verdict" { print $2 ; exit ; }' "$( rigRecordFile "$rigRewaitId" )" )" deny
rigAssert "the record is the one the pending_id re-wait leaves" "$( rigRecordShape "$rigScenarioDir" )" "$( rigRecordShape "$rigTmp/resumed" )"


echo "-- a plain question: the first line is the answer, the rest and later replies are kept --"
rigStart plain-multiline
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"yes, keep it\nbut rename it first","thread_ts":"1700000001.000101"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"to report-final","thread_ts":"1700000001.000101"}'
rigAsk rig-session-k 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\"}"
rigRewaitId="$( rigRecordId )"
rigAssert "it is answered"                            "$( LC_ALL=C head -1 "$rigScenarioDir/out" )" "ASK-RESULT: RECEIVED"
rigAssert "with the first line as the answer"         "$( rigRecordField "$rigRewaitId" verdict )" "yes, keep it"
rigAssert "the rest of the reply is kept"             "$( rigRecordHolds "$rigRewaitId" '- 1700000001.000200 URIGOWNER: but rename it first' )" yes
rigAssert "and so is the later reply"                 "$( rigRecordHolds "$rigRewaitId" '- 1700000001.000300 URIGOWNER: to report-final' )" yes

echo "-- a decision with a recommended option: a plain ok picks it, and the rest is kept --"
rigStart recommended
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Ok, go\nbecause it ships today","thread_ts":"1700000001.000101"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"and tell ops first","thread_ts":"1700000001.000101"}'
rigAsk rig-session-f 60 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"allow-once -- let it write (recommended)\\ndeny -- keep it refused\"}"
rigRewaitId="$( rigRecordId )"
rigAssert "the post says ok takes the recommended one" "$( rigHolds "$rigScenarioDir/post.1" 'to take the recommended option' )" yes
rigAssert "a plain ok is the recommended option"      "$( rigVerdictLine )" "VERDICT: allow-once"
rigAssert "the record closed with it"                 "$( rigRecordStatus )/$( rigRecordField "$rigRewaitId" verdict )" "reply-received/allow-once"
rigAssert "the rest of the reply is a clarification"  "$( rigRecordHolds "$rigRewaitId" '- 1700000001.000200 URIGOWNER: because it ships today' )" yes
rigAssert "and so is the later reply"                 "$( rigRecordHolds "$rigRewaitId" '- 1700000001.000300 URIGOWNER: and tell ops first' )" yes
rigStart recommended-twice
rigReplies ""
rigAsk rig-session-f 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"allow-once -- let it write (recommended)\\ndeny -- keep it refused (Recommended)\"}"
rigAssert "two recommended options are refused"       "$( rigHolds "$rigScenarioDir/out" 'at most one option marked (recommended)' )" yes
rigAssert "and nothing is posted"                     "$( rigCalls chat.postMessage )" 0

echo "-- the asker reads an unclear reply back as one option, and a later objection arrives on Wait --"
rigStart readback
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"hmm, the first one I guess","thread_ts":"1700000001.000101"}'
rigAsk rig-session-g 60 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"allow-once -- let it write\\ndeny -- keep it refused\"}"
rigAssert "the unclear reply is RETURNED"             "$( rigVerdictLine )" "VERDICT: RETURNED"
rigAssert "the result offers the readback"            "$( rigHolds "$rigScenarioDir/out" 'readback=<the answer you take the reply to mean> understood=<why>. The person may still object there.' )" yes
rigRewaitId="$( LC_ALL=C sed -n 's/^WAIT-ID: ask://p' "$rigScenarioDir/out" | tail -1 )"
[ -n "$rigRewaitId" ] || rigRefuse "no WAIT-ID line came back, so the readback below would not be measured"
rigAsk rig-session-g 30 "{\"pending_id\":\"$rigRewaitId\",\"readback\":\"maybe\"}"
rigAssert "a readback naming no option is refused"    "$( rigHolds "$rigScenarioDir/out" 'is not an option of' )" yes
rigAssert "and the record stays open"                 "$( rigRecordStatus )" reply-pending
rigAsk rig-session-g 30 "{\"pending_id\":\"$rigRewaitId\",\"readback\":\"allow-once\",\"understood\":\"the first one is allow-once\"}"
rigAssert "the readback closes it"                    "$( LC_ALL=C head -1 "$rigScenarioDir/out" )" "ASK-RESULT: RECEIVED"
rigAssert "with that option"                          "$( rigVerdictLine )" "VERDICT: allow-once"
rigAssert "marked as closed by readback"              "$( rigHolds "$rigScenarioDir/out" 'CLOSED-BY: readback' )" yes
rigAssert "on the record too"                         "$( rigRecordStatus )/$( rigRecordField "$rigRewaitId" closed-by )/$( rigRecordField "$rigRewaitId" answered-by )" "reply-received/readback/magic-tester (readback)"
rigAssert "the readback is posted in the thread"      "$( rigHolds "$rigScenarioDir/post.2" '"thread_ts":"1700000001.000101"' )$( rigHolds "$rigScenarioDir/post.2" 'Readback by magic-tester' )" yesyes
rigAssert "its ts is the follow floor"                "$( rigRecordField "$rigRewaitId" follow-floor )" "1700000001.000102"
rigAssert "the reply read back is kept"               "$( rigRecordHolds "$rigRewaitId" '- 1700000001.000200 URIGOWNER: hmm, the first one I guess' )" yes
rigAssert "the item stays in the Wait set"            "$( rigWaitSet "$rigScenarioDir" rig-session-g )" "replies:rig-session-g chat:rig-session-g ask:$rigRewaitId "
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"hmm, the first one I guess","thread_ts":"1700000001.000101"},{"ts":"1700000001.000102","user":"URIGSELF1","text":"readback","thread_ts":"1700000001.000101"},{"ts":"1700000001.000400","user":"URIGOWNER","text":"no, I meant deny","thread_ts":"1700000001.000101"}'
rigAsk rig-session-g 30 "{\"sources\":\"ask:$rigRewaitId\"}" Wait
rigAssert "the objection arrives on Wait"             "$( LC_ALL=C head -1 "$rigScenarioDir/out" )" "WAIT-RESULT: RECEIVED"
rigAssert "as a clarification on the closed decision" "$( rigHolds "$rigScenarioDir/out" 'ASK-RESULT: CLARIFIED' )$( rigHolds "$rigScenarioDir/out" 'no, I meant deny' )" yesyes
rigAssert "kept on the record"                        "$( rigRecordHolds "$rigRewaitId" '- 1700000001.000400 URIGOWNER: no, I meant deny' )" yes
rigAssert "the verdict itself is left as it was"      "$( rigRecordField "$rigRewaitId" verdict )" allow-once
rigStart readback-early
rigReplies ""
rigAsk rig-session-h 8 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"allow-once -- let it write\\ndeny -- keep it refused\"}"
rigRewaitId="$( rigRecordId )"
rigAsk rig-session-h 30 "{\"pending_id\":\"$rigRewaitId\",\"readback\":\"deny\"}"
rigAssert "no readback before any reply"              "$( rigHolds "$rigScenarioDir/out" 'nobody has replied' )" yes
rigAssert "and the record stays open"                 "$( rigRecordStatus )" reply-pending

echo "-- the asker withdraws its own question: no verdict, a note in its thread --"
rigStart withdraw
rigReplies ""
rigAsk rig-session-i 30 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"wait\":false}"
rigRewaitId="$( LC_ALL=C sed -n 's/^WAIT-ID: ask://p' "$rigScenarioDir/out" | tail -1 )"
rigAsk rig-session-i 30 "{\"pending_id\":\"$rigRewaitId\",\"withdraw\":\"the task was cancelled\"}"
rigAssert "it is withdrawn"                           "$( LC_ALL=C head -1 "$rigScenarioDir/out" )" "ASK-RESULT: WITHDRAWN"
rigAssert "closed as withdrawn, with the reason"      "$( rigRecordStatus )/$( rigRecordField "$rigRewaitId" withdraw-reason )/$( rigRecordField "$rigRewaitId" withdrawn-by )" "withdrawn/the task was cancelled/magic-tester"
rigAssert "and no verdict"                            "$( rigRecordField "$rigRewaitId" verdict )" ""
rigAssert "a note in its own thread"                  "$( rigHolds "$rigScenarioDir/post.2" '"thread_ts":"1700000001.000101"' )$( rigHolds "$rigScenarioDir/post.2" 'no longer needs an answer' )" yesyes
rigAssert "it left the Wait set"                      "$( rigWaitSet "$rigScenarioDir" rig-session-i )" ""
rigAsk rig-session-i 30 "{\"pending_id\":\"$rigRewaitId\"}"
## The record this scenario withdraws is retired into pending/closed/, and the re-wait's
## retained-closed branch (AgentsUniversalHarness, retention T9) names the status as
## `is closed (<status>)` -- the live-store branch's `is closed (status <status>)` is reached
## only where the first read saw it open, so the word it carries is `withdrawn`.
rigAssert "a re-wait finds it closed"                 "$( rigHolds "$rigScenarioDir/out" 'is closed (withdrawn)' )" yes
rigStart withdraw-decision
rigReplies ""
rigAsk rig-session-j 8 "{\"to\":\"magic-team\",\"question\":\"$rigQuestion\",\"address_to\":\"URIGOWNER\",\"kind\":\"decision\",\"options\":\"allow-once -- let it write\\ndeny -- keep it refused\"}"
rigRewaitId="$( rigRecordId )"
rigAsk rig-session-j 30 "{\"pending_id\":\"$rigRewaitId\",\"withdraw\":\"asked the wrong person\"}"
rigAssert "an open decision is withdrawn too"         "$( LC_ALL=C head -1 "$rigScenarioDir/out" )/$( rigRecordStatus )" "ASK-RESULT: WITHDRAWN/withdrawn"

rigAssert "no request went anywhere but a Slack method" "$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK REWAIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ASK_REWAIT: OK (%d assertions, offline)\n' "$rigPassCount"
