#!/usr/bin/env bash
## Behavioural check on the collect of an answer to a question: a reply that names no answer
## of its ask is never recorded as that ask's answer. An ask that OFFERS options is a
## disambiguation ask, and takes only one of them: the record's `select` field is no witness
## to that, since a revise can leave the options standing with no form beside them.
## Held as eight rows, each through the real operation --intern-op-pending-reply-collect:
##   A. an ask with options and a form, the reply `asdf`: no answer, the record stays open.
##   B. the same ask answered `Switch`, its own first option: answered, with `switch`.
##   C. an ask whose options stand beside it with NO form, the reply `asdf`: no answer.
##   D. the same ask answered `Switch`: answered. The control on C, so the fix cannot pass
##      by refusing every reply to such an ask.
##   E. the same ask, and the `eyes` mark the tooling itself places on a message it has read:
##      no answer.
##   F. a free-text question, no form and no options, the reply `asdf, why not`: answered as
##      typed. The control on what the three rows above must not take away.
##   G. the same ask as C, answered by an option's whole line as the post shows it: answered,
##      with that option's own word.
##   H. the same ask again, answered in words that are no option's line and name none: no
##      answer. The control on G, so a reply is not read as an option it never named.
##
## RED RECIPE, measured on the code before the fix at 2026-11-20 18:57 +0200: C is red,
## answered `asdf`. D is red too, answered `Switch` unlowered: the ask's options were never
## read there, so no option word was ever matched against them. G is red, its whole option
## line kept as the answer instead of the word that line names. H is red the same way, its
## words kept as typed. A, B, E and F pass on the live tree. E's own red comes from the
## collect keeping any reaction line as an answer to a free-text ask, which its recorded
## store shows seven times over.
##
## Offline: a Slack-shaped fake curl is first on PATH, and every record, thread and workspace
## is this check's own under the workspace's temp folder.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to read under"

rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsPendingReplyCollectNonsenseCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:/usr/bin:/bin"
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

## A scenario's own workspace, its two accounts, and the fake curl's log.
rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents/pending" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
## An ask, the options beside it, and its thread's messages. <select> empty writes no `select`
## field at all, which is what a revise back to free text leaves.
rigAsk(){ ## id, tag, select, options
	local askFile="$rigScenarioDir/ws/.local/agents/pending/$1.md" rigOptFile=""
	{
		printf -- '---\nstatus: reply-pending\nowner: %s\nhost: rig\n' "$rigMember"
		printf 'communication-channel-id: slack:human-owner\nblocked-on: reply from human-owner\n'
		printf 'session-id: rig-sess\nkind: question\naddress-to: human-owner\n'
		printf 'channel: CRIG00001\nquestion-ts: 1700000001.000100\nthread-ts: 1700000001.000100\n'
		printf 'addressees: URIGOWNER\nasking-accounts: URIGSELF1\nquestion-tag: %s\n' "$2"
		[ -z "$3" ] || printf 'select: %s\n' "$3"
		printf 'asked-at: 2026-11-20 10:00 +0200\n---\n\n'
		printf '# Question asked\n\n# ❓ Question %s\n\nWhich way should the rig go?\n' "$2"
	} > "$askFile"
	[ -z "$4" ] || printf '%s\n' "$4" > "${askFile%.md}.options"
}
rigReplies(){ ## the thread's messages, as JSON array elements after the question
	printf '{"ok":true,"messages":[{"ts":"1700000001.000100","user":"URIGSELF1","text":"the question"}%s],"has_more":false}\n' "$1" > "$rigScenarioDir/replies.json"
}
rigEnv(){ ## command... -- run in the scenario's workspace, with no model key
	( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY \
		RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_WORKSPACE_MODE=team-rig MDAT_COLLECT_THREAD=off MDAT_COMMS_READER=off MDAT_WAIT_REMIND=off \
		MDAT_DATA_ROOT="$rigScenarioDir/data" "$@" )
}
rigCollect(){ rigEnv bash "$rigTool" --intern-op-pending-reply-collect --session-id rig-sess > "$rigScenarioDir/out" 2> "$rigScenarioDir/out.err" ; }
rigRecordFile(){ ## id
	local rigRec="$rigScenarioDir/ws/.local/agents/pending/$1.md"
	[ -f "$rigRec" ] || rigRec="$rigScenarioDir/ws/.local/agents/pending/closed/$1.md"
	printf '%s' "$rigRec"
}
rigStatus(){ LC_ALL=C awk -F': ' '$1 == "status" { print $2 ; exit ; }' "$( rigRecordFile "$1" )" ; }
rigField(){ LC_ALL=C awk -v key="$2" 'index($0, key ": ") == 1 { print substr($0, length(key) + 3) ; exit ; }' "$( rigRecordFile "$1" )" ; }

rigQ1=33333333-0000-0000-0000-000000000001
rigOptions='Switch: turn the rig left
Finish: run it to its end
Other-session-owns: hand it to another session'

echo "-- A. an ask with options and a form, answered by a word no option names --"
rigStart wordNamingNoOption
rigAsk "$rigQ1" Q1 one "$rigOptions"
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"asdf","thread_ts":"1700000001.000100"}'
rigCollect
rigAssert "the record stays open"                        "$( rigStatus "$rigQ1" )" reply-pending
rigAssert "and no nonsense is recorded as its answer"     "$( rigField "$rigQ1" verdict )" ""

echo "-- B. the same ask answered by its own first option --"
rigStart wordNamingItsOption
rigAsk "$rigQ1" Q1 one "$rigOptions"
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Switch","thread_ts":"1700000001.000100"}'
rigCollect
rigAssert "the record is answered"                        "$( rigStatus "$rigQ1" )" reply-received
rigAssert "with the option it names"                      "$( rigField "$rigQ1" verdict )" switch

echo "-- C. an ask whose options stand beside it with no answer form --"
rigStart optionsWithoutForm
rigAsk "$rigQ1" Q1 "" "$rigOptions"
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"asdf","thread_ts":"1700000001.000100"}'
rigCollect
rigAssert "a word naming none of its options is no answer" "$( rigField "$rigQ1" verdict )" ""
rigAssert "so the record stays open"                       "$( rigStatus "$rigQ1" )" reply-pending

echo "-- D. the same ask answered by its own first option: the control on C --"
rigStart optionsWithoutFormItsOption
rigAsk "$rigQ1" Q1 "" "$rigOptions"
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Switch","thread_ts":"1700000001.000100"}'
rigCollect
rigAssert "its option still answers"                      "$( rigField "$rigQ1" verdict )" switch
rigAssert "and the record closes"                         "$( rigStatus "$rigQ1" )" reply-received

echo '-- E. a free-text ask, and the eyes-mark the tooling places on what it has read --'
rigStart reactionOnFreeTextAsk
rigAsk "$rigQ1" Q1 "" ""
printf '{"ok":true,"messages":[{"ts":"1700000001.000100","user":"URIGSELF1","text":"the question","reactions":[{"name":"eyes","count":1,"users":["URIGOWNER"]}]}],"has_more":false}\n' > "$rigScenarioDir/replies.json"
rigCollect
rigAssert "a seen mark is no answer to a free-text ask"    "$( rigField "$rigQ1" verdict )" ""
rigAssert "and the record stays open"                      "$( rigStatus "$rigQ1" )" reply-pending

echo "-- F. a free-text question, answered in words: the control --"
rigStart freeTextWords
rigAsk "$rigQ1" Q1 "" ""
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"asdf, why not","thread_ts":"1700000001.000100"}'
rigCollect
rigAssert "a free-text ask takes the reply as typed"       "$( rigField "$rigQ1" verdict )" "asdf, why not"
rigAssert "and closes as received"                         "$( rigStatus "$rigQ1" )" reply-received

echo "-- G. the same ask answered by an option's whole line, as the post shows it --"
rigStart optionsWithoutFormItsWholeLine
rigAsk "$rigQ1" Q1 "" "$rigOptions"
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Switch: turn the rig left","thread_ts":"1700000001.000100"}'
rigCollect
rigAssert "its option's line answers with that option's word" "$( rigField "$rigQ1" verdict )" switch
rigAssert "and the record closes"                         "$( rigStatus "$rigQ1" )" reply-received

echo "-- H. the same ask answered in words naming no option: the control on G --"
rigStart optionsWithoutFormOtherWords
rigAsk "$rigQ1" Q1 "" "$rigOptions"
rigReplies ',{"ts":"1700000001.000200","user":"URIGOWNER","text":"Turn the rig right","thread_ts":"1700000001.000100"}'
rigCollect
rigAssert "words naming no option are no answer"             "$( rigField "$rigQ1" verdict )" ""
rigAssert "and the record stays open"                       "$( rigStatus "$rigQ1" )" reply-pending

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PENDING REPLY COLLECT NONSENSE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PENDING_REPLY_COLLECT_NONSENSE: OK (%d assertions, offline, no model)\n' "$rigPassCount"
