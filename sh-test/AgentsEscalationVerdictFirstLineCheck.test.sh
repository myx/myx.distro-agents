#!/usr/bin/env bash
## Behavioural check: a typed verdict is the reply's first line, in one of two shapes, for every
## kind the verdict reader serves (AgentsEscalationVerdict.awk). The owner's rule: "complete
## first line, or separated by punctuation at least". ALONE: the answering word and nothing
## else, case, spaces and the marks that close it aside, or an option's whole line as the post
## shows it. WITH HIS WORDS: the word, then a punctuation mark before anything else -- at once,
## or a dash after it -- then whatever he wrote, which reaches the asker. Anything else comes
## back as RETURNED with his text: words after the word with no mark between, a word that is
## not at the start, two answers on the line. This narrowed "the first word wins", by which
## `allow-once please` granted and `yes but not now` confirmed.
## A number as the answer and a question that takes several keep their own rules, held here
## as they were. His comments on later lines and in later replies reach the asker as before,
## and a reply he posts right after the read that first sees his verdict reaches the asker too:
## with the verdict, where the read that takes the answer sees it, or by the next Wait -- it
## used to reach the record alone where that read saw it and the wait before it had not.
## Three parts. The reader alone, a row per reply. The tools: an answer with his words, and a
## reply that is none, through a served call. Then a thread that grows between its reads.
## Red recipe: read a verdict by the reply's first word again in judgeMessage, and every row
## under "no verdict: words after" and "two answers" gives the verdict it used to.
## Offline: a Slack-shaped fake curl is first on PATH, model CLIs on PATH only log, and every
## scenario runs in its own workspace under this check's temp tree, in $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/magic-tester/magic-tester.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold magic-tester, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsEscalationVerdictFirstLineCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

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

echo "-- the reader alone, every kind: the first line answers alone or with his words, and nothing else does --"
rigOptions=$'alpha: the first\nbeta (recommended): the second one\ngamma the third'
rigVerdict(){ ## kind, answer form, the reply as it is rendered under its head -> the verdict, with the words on its line
	printf '1700000001.000200 | URIGOWNER | %s\nand a line under it\n' "$3" | MDAT_VERDICT_WORDS=1 MDAT_VERDICT_KIND="$1" MDAT_VERDICT_SELECT="$2" MDAT_VERDICT_OPTIONS="$rigOptions" MDAT_VERDICT_AUTHORS=URIGOWNER MDAT_VERDICT_ASKING=URIGSELF1 \
		LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" 2>&1 | LC_ALL=C cut -f1
}
## kind | answer form | the reply's first line | what it is read as
while IFS='|' read -r rigKind rigForm rigLine rigWant ; do
	case "$rigKind" in ''|'#'*) continue ;; esac
	rigAssert "$rigKind${rigForm:+ ($rigForm)} [$rigLine]" "$( rigVerdict "$rigKind" "$rigForm" "$rigLine" )" "$rigWant"
done <<'RIG_ROWS'
# a verdict: the answering word and nothing else, case, spaces and the marks that close it aside
permission||allow-once|allow-once
permission||Allow-Once.|allow-once
permission||  deny!  |deny
permission||allow-session…|allow-session
permission-set||allow-set|allow-set
permission-set||edit|edit
proposal||approve.|approved
review||ACCEPT|accept
readback||yes|yes
readback||ok!|yes
readback||I agree|yes
readback||correct|correct
decision||beta|beta
decision||Beta.|beta
decision||ok|beta
decision||beta (recommended): the second one|beta
question|yes-no|no.|no
question|yes-no|agreed|yes
question|one|gamma|gamma
# a verdict with his words: the word, a punctuation mark at once or a dash after it, then anything
permission||allow-once, but only this file|allow-once -- but only this file
permission||deny. The path is wrong|deny -- The path is wrong
permission||deny: the path is wrong|deny -- the path is wrong
permission||allow-session - for this task|allow-session -- for this task
permission||deny — wrong path|deny -- wrong path
permission||deny. allow-once would be too wide|deny -- allow-once would be too wide
permission-set||edit: drop the second entry|edit -- drop the second entry
permission-set||deny, edit it first|deny -- edit it first
proposal||approved - ship it|approved -- ship it
proposal||rejected: too wide|rejected -- too wide
review||return: fix the tests|return -- fix the tests
readback||yes: go on|yes -- go on
readback||I agree, go on|yes -- go on
readback||yes, no problem|yes -- no problem
readback||ok, agreed|yes -- agreed
readback||correct: the path is /b|correct -- the path is /b
decision||beta, because it is cheaper|beta -- because it is cheaper
decision||beta: because it is cheaper|beta -- because it is cheaper
decision||ok, the second|beta -- the second
decision||alpha - ok… primitive but works|alpha -- ok… primitive but works
question|yes-no|yes: go on|yes -- go on
question|yes-no|no, yes was for the other one|no -- yes was for the other one
question|one|gamma, for now|gamma -- for now
# no verdict: words after the word with no punctuation between
permission||allow-once please|RETURNED
permission||allow-once but only this file|RETURNED
permission-set||edit drop the second entry|RETURNED
proposal||approved ship it|RETURNED
review||return fix the tests|RETURNED
readback||yes please|RETURNED
readback||I agree with the first part|RETURNED
readback||correct the path is /b|RETURNED
decision||beta because it is cheaper|RETURNED
decision||ok then|RETURNED
question|yes-no|yes go on|RETURNED
question|one|gamma for now|RETURNED
# no verdict: a word that is not at the start, a question, a plain affirmation where the kind takes none
permission||sure, allow-once|RETURNED
permission||allow-once?|RETURNED
permission||ok|RETURNED
decision||the beta one|RETURNED
question|one|ok|RETURNED
# no verdict: two answers on the line
permission||allow-once allow-session|RETURNED
permission||allow-once, allow-session|RETURNED
permission-set||allow-set, deny|RETURNED
proposal||approved, rejected|RETURNED
review||reject, accept|RETURNED
readback||yes, no|RETURNED
decision||alpha, beta|RETURNED
decision||alpha, 2|RETURNED
# their own rules, as they were: a number, and a question that takes several
decision||2|beta
decision||#2.|beta
decision||2 please|beta -- please
question|one|3 for now|gamma -- for now
question|many|alpha gamma|alpha gamma
question|many|1, 3|alpha gamma
question|many|alpha and gamma|RETURNED
RIG_ROWS
rigHeader=':mouse: *_magic-coordinator_* @dispatchr → <@URIGSELF1>.'
rigAssert "a member's reply: its first line starts after its send header, in either shape, and is none with words and no mark" \
	"$( rigVerdict permission "" "$rigHeader allow-once, only this file" ):$( rigVerdict permission "" "$rigHeader deny" ):$( rigVerdict permission "" "$rigHeader allow-once please" )" \
	"allow-once -- only this file:deny:RETURNED"
rigAssert "a quote of the question ahead of the answer is skipped, and the line after it is read the same way" \
	"$( rigVerdict permission "" $'&gt; may I?\nallow-once, this once' ):$( rigVerdict permission "" $'&gt; may I?\nallow-once this once' )" \
	"allow-once -- this once:RETURNED"
rigAssert "a caller that does not ask for the words gets the verdict alone, a correction with its words as before" \
	"$( printf '1700000001.000200 | URIGOWNER | allow-once, but only this file\n' | MDAT_VERDICT_KIND=permission MDAT_VERDICT_AUTHORS=URIGOWNER LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" | LC_ALL=C cut -f1 ):$( printf '1700000001.000200 | URIGOWNER | correct: the path is /b\n' | MDAT_VERDICT_KIND=readback MDAT_VERDICT_AUTHORS=URIGOWNER LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" | LC_ALL=C cut -f1 )" \
	"allow-once:correct -- the path is /b"
rigAssert "a reply that is none does not end the reading: the next one that answers is the verdict" \
	"$( printf '1700000001.000200 | URIGOWNER | allow-once please\n1700000001.000300 | URIGOWNER | allow-once\n' | MDAT_VERDICT_KIND=permission MDAT_VERDICT_AUTHORS=URIGOWNER LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" | LC_ALL=C tr '\t' '|' )" \
	"allow-once|URIGOWNER|1700000001.000300"

echo "-- the tools: his words come with the verdict, and a reply that is none comes back whole --"
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/fixture-curl" || rigRefuse "the fake curl fixture is missing from the package"
cat > "$rigTmp/bin/curl" <<'RIG_CURL'
#!/usr/bin/env bash
## The package's fake curl, with one thing added: a thread that grows. After the first read of
## a thread that already holds his answer, the scenario's next version of it, where it has
## one (replies.next.json), is what every later read is given. Opens no socket.
rigGrow=""
for rigArg in "$@" ; do
	case "$rigArg" in https://slack.com/api/conversations.replies*) rigGrow="$RIG_SCENARIO/replies.next.json" ;; esac
done
bash "$RIG_FIXTURE_CURL" "$@" ; rigRc=$?
if [ -n "$rigGrow" ] && [ -f "$rigGrow" ] && LC_ALL=C grep -q -F '1700000001.000200' "$RIG_SCENARIO/replies.json" ; then mv -f "$rigGrow" "$RIG_SCENARIO/replies.json" ; fi
exit "$rigRc"
RIG_CURL
for rigModel in claude codex ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigTmp/bin/$rigModel"
done
chmod +x "$rigTmp/bin/"* "$rigTmp/fixture-curl"
RIG_FIXTURE_CURL="$rigTmp/fixture-curl"
PATH="$rigTmp/bin:$PATH"
export PATH RIG_FIXTURE_CURL
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"

## Each scenario in a workspace of its own, a served tool call at a time (AgentsUniversalHarness.sh --intern-tool).
rigToolDir="" ; rigToolWs="" ; rigToolName=""
rigToolStart(){ ## scenario name
	rigToolName="$1" ; rigToolDir="$rigTmp/tool-$1" ; rigToolWs="$rigToolDir/ws"
	mkdir -p "$rigToolWs/.local/.agents" "$rigToolWs/.local/agents" "$rigToolWs/IN" "$rigToolDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigToolWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigToolWs/.local/.agents/magic-tester.agent.env"
	RIG_CURL_LOG="$rigToolDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
	rigToolThread ""
}
rigToolThread(){ ## later messages (may be empty), the file (the thread as it is now, when none is named)
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"the question"}%s],"has_more":false}\n' "$1" > "$rigToolDir/${2:-replies.json}"
}
rigToolMsg(){ ## ts suffix, text
	printf ',{"ts":"1700000001.%s","user":"URIGOWNER","text":"%s","thread_ts":"1700000001.000101"}' "$1" "$2"
}
rigToolKilled=""
rigToolCall(){ ## guard seconds, tool, argument object
	local callPid callLeft="$1"
	rigToolKilled="no"
	set -m
	( cd "$rigToolWs" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SPAWN_SESSION_ID="rig-line-$rigToolName" RIG_SCENARIO="$rigToolDir" MMDAPP="$rigToolWs" MDAT_SPAWN_AGENT=magic-tester MDAT_HARNESS_WAIT_TIMEOUT=1 MDAT_WAIT_SETTLE_SECONDS=1 \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigToolWs" --access-write-root "$rigToolWs/IN" ) > "$rigToolDir/out" 2> "$rigToolDir/err" &
	callPid=$!
	set +m
	while kill -0 "$callPid" 2>/dev/null && [ "$callLeft" -gt 0 ] ; do sleep 1 ; callLeft=$(( callLeft - 1 )) ; done
	if kill -0 "$callPid" 2>/dev/null ; then
		rigToolKilled="yes"
		{ kill -TERM -- "-$callPid" ; sleep 1 ; kill -KILL -- "-$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}
rigToolField(){ ## field of the scenario's one record
	local recordFile
	for recordFile in "$rigToolWs/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] || continue
		LC_ALL=C awk -v key="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$recordFile"
		return 0
	done
	printf 'no-record'
}
rigToolSaid(){ ## what the member is given: its verdict line, the words line, and how many of the named lines are in it
	local saidWant saidCount=0
	printf '%s|%s' "$( LC_ALL=C grep -m1 '^VERDICT: ' "$rigToolDir/out" || printf none )" "$( LC_ALL=C grep -m1 '^VERDICT-TEXT: ' "$rigToolDir/out" || printf none )"
	for saidWant in "$@" ; do
		LC_ALL=C grep -q -F -- "$saidWant" "$rigToolDir/out" && saidCount=$(( saidCount + 1 ))
	done
	printf '|%s' "$saidCount"
}
rigAsk='"to":"magic-team","address_to":"URIGOWNER"'
rigAskOptions='"options":"alpha -- the unit checks\nbeta -- the lint"'

rigToolStart words
rigToolThread "$( rigToolMsg 000200 'beta, but run alpha right after\nand tell me when done' )$( rigToolMsg 000300 'one more thing' )"
rigToolCall 60 EscalateDecision "{$rigAsk,\"question\":\"Which check first?\",$rigAskOptions}"
rigAssert "a decision answered with his words: the verdict, his words on its line, the line under it and his later reply, each once; and the record" \
	"$rigToolKilled:$( rigToolSaid 'and tell me when done' 'one more thing' ):$( LC_ALL=C grep -c -F 'one more thing' "$rigToolDir/out" ):$( rigToolField status ):$( rigToolField verdict )" \
	"no:VERDICT: beta|VERDICT-TEXT: but run alpha right after|2:1:reply-received:beta"
rigToolStart none
rigToolThread "$( rigToolMsg 000200 'beta but run alpha right after' )"
rigToolCall 60 EscalateDecision "{$rigAsk,\"question\":\"Which check first?\",$rigAskOptions}"
rigAssert "the same words with no mark between: no verdict, his whole text comes back, and the question stays open" \
	"$rigToolKilled:$( rigToolSaid 'beta but run alpha right after' ):$( rigToolField status ):$( rigToolField verdict )" \
	"no:VERDICT: RETURNED|none|1:reply-pending:none"
rigToolStart readback
rigToolThread "$( rigToolMsg 000200 'yes please' )"
rigToolCall 60 ConfirmReadback "{$rigAsk,\"question\":\"Did I read it right?\",\"understood\":\"tag v1\",\"source\":\"the brief\",\"will_do\":\"tag it\"}"
rigAssert "a readback answered yes with a word after it and no mark: no confirmation is taken" \
	"$rigToolKilled:$( rigToolSaid 'yes please' ):$( rigToolField status )" "no:VERDICT: RETURNED|none|1:reply-pending"

echo "-- a thread that grows: a reply posted right after his verdict was first read reaches the asker, never the record alone --"
rigToolStart grows
rigToolThread "$( rigToolMsg 000200 'beta.' )"
rigToolThread "$( rigToolMsg 000200 'beta.' )$( rigToolMsg 000300 'and one more thing' )" replies.next.json
rigToolCall 60 EscalateDecision "{$rigAsk,\"question\":\"Which check first?\",$rigAskOptions}"
rigGrowsFirst="$rigToolKilled:$( rigToolSaid ):$( LC_ALL=C grep -c -F 'and one more thing' "$rigToolDir/out" )"
rigToolCall 60 Wait '{"mode":"continue"}'
rigGrowsReached="$(( ${rigGrowsFirst##*:} + $( LC_ALL=C grep -c -F 'and one more thing' "$rigToolDir/out" ) ))"
rigAssert "the verdict is given, and his next reply with it or by the next Wait, once" \
	"${rigGrowsFirst%:*}:$rigToolKilled:$rigGrowsReached:$( [ -f "$rigToolDir/replies.next.json" ] && printf unread || printf read )" \
	"no:VERDICT: beta|none|0:no:1:read"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0
rigAssert "and no model was called"                    "$( [ -e "$rigTmp/model-calls" ] && printf called || printf none )" none

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ VERDICT FIRST LINE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'VERDICT_FIRST_LINE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
