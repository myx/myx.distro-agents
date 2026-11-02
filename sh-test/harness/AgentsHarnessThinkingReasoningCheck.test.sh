#!/usr/bin/env bash
## Behavioural check on the reasoning a thinking-mode turn carries back. DeepSeek refused
## a run whose resent history had lost it ("The reasoning_content in the thinking mode
## must be passed back to the API"), so the assistant turn keeps the text the stream gave
## it, and every later request -- the next round's, the kept context's, a restored prefix
## -- reads that same turn. The field is a property of the leg's mode, never of the text
## having arrived: a thinking leg's tool-call turn carries it even when its reasoning was
## empty, and a leg with no thinking carries it nowhere.
##
## Two parts. The builders are called directly, on a fabricated answer, so every direction
## is a value rather than a claim. Then the DeepSeek leaf is run end to end with its fake
## curl first on PATH, and the requests it would have sent are read back. Offline by
## construction: nothing here opens a socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigLeaf="$rigHere/harness/AgentsDeepseekHarness.sh"

## A rig that cannot reach its subject must never reach a PASS line, which reads like a
## result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

for rigFile in "$rigLeaf" "$rigHere/harness/AgentsOpenAiChatWire.sh" "$rigHere/harness/AgentsOpenAiChatStream.awk" \
	"$rigHere/harness/AgentsHarnessContext.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessThinkingReasoningCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
## The fake curl is a real file under sh-test/check-fixtures, copied rather than carried
## here: it records this round's request body and replays the canned stream beside it.
cp "$rigTest/check-fixtures/harness-copilot-leg-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
RIG_DECL_DIR="$rigTmp"
export RIG_DECL_DIR
## The leaf reads this name at load and exports it, so a machine holding the real token
## never has it reach a request this rig records.
export DEEPSEEK_API_KEY="rig-not-a-credential"
## The prompt-cache routing key puts a header on the channel the bearer rides; it is not
## this check's subject, and a session id would take the run down the kept-context path.
unset CLAUDE_CODE_SESSION_ID MDAT_SPAWN_SESSION_ID
export HARNESS_PROMPT_CACHE_KEY=off

rigOnPath(){
	[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue a real request against the leaf's own live endpoint"
}

rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigScenarioPass=$(( rigScenarioPass + 1 ))
	else
		rigScenarioFail=$(( rigScenarioFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

## yes/no rather than a status, with a third value for a file that is not there: a request
## never made is not the same finding as one made without the text.
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}

## The decoded value of one field of a request body, by the package's own reader, so a body
## its reader cannot walk is the corruption this check exists to catch. Four answers, since
## an absent field, an empty one and a corrupt body are three different findings. The
## reader's trailing `X` keeps a value's own newlines through `$( ... )`, so it is stripped.
rigField(){ ## request body, dot path
	local fieldRc=0 fieldValue
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	fieldValue="$( printf '%s\n' "$( cat "$1" )" | LC_ALL=C awk -v path="$2" -v optional=1 -v sentinel=1 -f "$rigHere/harness/AgentsHarnessJsonField.awk" 2>/dev/null )" || fieldRc=$?
	fieldValue="${fieldValue%X}"
	if [ "$fieldRc" != 0 ] ; then
		if [ "$fieldRc" = 3 ] ; then printf 'absent' ; else printf 'corrupt' ; fi
		return 0
	fi
	if [ -n "$fieldValue" ] ; then printf '%s' "$fieldValue" ; else printf 'empty' ; fi
}

rigScenarioDir=""
rigScenarioPass=0
rigScenarioFail=0
rigPassCount=0
rigFailCount=0
rigScenarioCount=0

rigStart(){ ## scenario directory name
	rigOnPath
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir"
	printf '0' > "$rigScenarioDir/round"
	rigScenarioPass=0
	rigScenarioFail=0
}

rigVerdict(){ ## scenario title
	local verdictMark=PASS
	[ "$rigScenarioFail" = 0 ] || verdictMark=FAIL
	printf '  %s  %s -- %d of %d assertions\n' "$verdictMark" "$1" "$rigScenarioPass" "$(( rigScenarioPass + rigScenarioFail ))"
	rigPassCount=$(( rigPassCount + rigScenarioPass ))
	rigFailCount=$(( rigFailCount + rigScenarioFail ))
	rigScenarioCount=$(( rigScenarioCount + 1 ))
}

rigRun(){ ## effort word
	rigRunStatus=0
	RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" HARNESS_EFFORT="$1" \
		"$rigLeaf" --access-read-root "$rigScenarioDir" --access-write-root "$rigScenarioDir" RIG-TASK-MARKER \
		> "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || rigRunStatus=$?
	[ "$( cat "$rigScenarioDir/round" )" != 0 ] || rigRefuse "the harness issued no request at all, so this scenario exercised nothing"
}

## A round's canned stream, one line per SSE event, closed by [DONE]. A reasoning line is
## written only where the caller gives one, which is what tells a thinking leg's empty
## round from a leg that never reasons.
rigStream(){ ## file, reasoning or "", the rest of the round's events
	local rigStreamFile="$1" rigReasoning="$2"
	: > "$rigStreamFile"
	[ -z "$rigReasoning" ] || printf 'data: {"choices":[{"index":0,"delta":{"reasoning":"%s"}}]}\n' "$rigReasoning" >> "$rigStreamFile"
	printf '%s\n' "$3" >> "$rigStreamFile"
	printf 'data: [DONE]\n' >> "$rigStreamFile"
}

rigToolEvent(){ ## call id, path to read
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"%s","type":"function","function":{"name":"Read","arguments":"{\\"path\\":\\"%s\\"}"}}]}}]}\n' "$1" "$2"
}

rigToolClose(){ ## this round's total tokens
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":%s}}\n' "$1"
}

rigTextEvent(){ ## content, this round's total tokens
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":%s}}\n' "$1" "$2"
}

## ---------------------------------------------------------------------------
## A. Both turn builders, called directly. Three directions, because the field is the
##    leg's mode and not the round's text: a thinking leg's turn with text, its tool-call
##    turn with none, and a leg whose thinking is off.
## ---------------------------------------------------------------------------
rigBuilders(){ ## fabricated answer, family thinking form, thinking off or ""
	(
		set -u
		harnessHere="$rigHere" harnessWire=OpenAiChat harnessResponse="$1"
		harnessNoneForm="$2" harnessThinkingOff="$3"
		harnessDim="" harnessTool="" harnessOff="" harnessValue="" harnessWarn="" harnessBad=""
		. "$rigHere/harness/AgentsOpenAiChatWire.sh"
		. "$rigHere/harness/AgentsHarnessContext.include"
		AgentsWireAssistantToolCallsRecord '{"id":"rig-call","type":"function","function":{"name":"Read","arguments":"{}"}}'
		printf '\n--\n'
		AgentsHarnessContextAssistantRecord
	)
}
rigBuilderLine(){ ## builder output, 1 the tool turn | 2 the reply turn
	if [ "$2" = 1 ] ; then
		printf '%s' "${1%%$'\n'--$'\n'*}"
	else
		printf '%s' "${1##*$'\n'--$'\n'}"
	fi
}

rigStart a-builders
rigAnswer='{"choices":[{"index":0,"message":{"role":"assistant","content":"RIG-ANSWER","reasoning_content":"RIG-THOUGHT with \"quotes\" and \\ and a newline\nsecond line"},"finish_reason":"stop"}]}'
rigBare='{"choices":[{"index":0,"message":{"role":"assistant","content":"RIG-ANSWER"},"finish_reason":"stop"}]}'
rigBuilt="$( rigBuilders "$rigAnswer" thinking:disabled "" )"
rigAssert "a thinking turn's tool call carries the reasoning" \
	"$( rigBuilderLine "$rigBuilt" 1 )" \
	'{"role":"assistant","content":null,"tool_calls":[{"id":"rig-call","type":"function","function":{"name":"Read","arguments":"{}"}}],"reasoning_content":"RIG-THOUGHT with \"quotes\" and \\ and a newline\nsecond line"}'
rigAssert "a thinking turn's reply carries the reasoning" \
	"$( rigBuilderLine "$rigBuilt" 2 )" \
	'{"role":"assistant","content":"RIG-ANSWER","reasoning_content":"RIG-THOUGHT with \"quotes\" and \\ and a newline\nsecond line"}'
rigBuilt="$( rigBuilders "$rigBare" thinking:disabled "" )"
rigAssert "A THINKING TOOL TURN WITH NO REASONING CARRIES AN EMPTY FIELD" \
	"$( rigBuilderLine "$rigBuilt" 1 )" \
	'{"role":"assistant","content":null,"tool_calls":[{"id":"rig-call","type":"function","function":{"name":"Read","arguments":"{}"}}],"reasoning_content":""}'
rigAssert "and a thinking reply with none stays bare" \
	"$( rigBuilderLine "$rigBuilt" 2 )" \
	'{"role":"assistant","content":"RIG-ANSWER"}'
rigBuilt="$( rigBuilders "$rigAnswer" thinking:disabled 1 )"
rigAssert "control: thinking switched off adds no tool-turn field" \
	"$( rigBuilderLine "$rigBuilt" 1 )" \
	'{"role":"assistant","content":null,"tool_calls":[{"id":"rig-call","type":"function","function":{"name":"Read","arguments":"{}"}}]}'
rigAssert "control: thinking switched off adds no reply field" \
	"$( rigBuilderLine "$rigBuilt" 2 )" \
	'{"role":"assistant","content":"RIG-ANSWER"}'
rigBuilt="$( rigBuilders "$rigAnswer" effort:low "" )"
rigAssert "control: a family with no thinking mode adds no field" \
	"$( rigBuilderLine "$rigBuilt" 1 )" \
	'{"role":"assistant","content":null,"tool_calls":[{"id":"rig-call","type":"function","function":{"name":"Read","arguments":"{}"}}]}'
rigVerdict "the field follows the leg's mode, and a bare tool turn still gets it"

## ---------------------------------------------------------------------------
## B. Two tool rounds in thinking mode, end to end under the DeepSeek leaf: the known
##    positive. Round 2 is the request that used to answer 400.
## ---------------------------------------------------------------------------
rigStart b-two-tool-rounds
printf 'RIG-TOOLRESULT-MARKER\n' > "$rigScenarioDir/read.txt"
rigStream "$rigScenarioDir/res.1" RIG-THINK-ONE "$( rigToolEvent rig-call-1 "$rigScenarioDir/read.txt" )
$( rigToolClose 20 )"
rigStream "$rigScenarioDir/res.2" RIG-THINK-TWO "$( rigToolEvent rig-call-2 "$rigScenarioDir/read.txt" )
$( rigToolClose 40 )"
rigStream "$rigScenarioDir/res.3" RIG-THINK-THREE "$( rigTextEvent RIG-FINAL-MARKER 60 )"
rigRun normal
rigAssert "the run ends normally"                    "$rigRunStatus" 0
rigAssert "the final answer is the model's"          "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigAssert "three rounds were requested"              "$( cat "$rigScenarioDir/round" )" 3
rigAssert "round 1 carries no reasoning yet"         "$( rigField "$rigScenarioDir/req.1" messages.2.reasoning_content )" absent
rigAssert "ROUND 2 CARRIES ROUND 1'S REASONING"      "$( rigField "$rigScenarioDir/req.2" messages.2.reasoning_content )" RIG-THINK-ONE
rigAssert "round 3 carries the first turn's reasoning" "$( rigField "$rigScenarioDir/req.3" messages.2.reasoning_content )" RIG-THINK-ONE
rigAssert "and the second turn's"                    "$( rigField "$rigScenarioDir/req.3" messages.4.reasoning_content )" RIG-THINK-TWO
rigAssert "the tool result still rides the history"  "$( rigHolds "$rigScenarioDir/req.3" 'RIG-TOOLRESULT-MARKER' )" yes
rigVerdict "two tool rounds in thinking mode resend every turn's reasoning"

## ---------------------------------------------------------------------------
## C. A thinking round that answers with a tool call and no reasoning text at all. The
##    turn still has to carry the field, empty: DeepSeek rejects a tool-calling assistant
##    message that omits it.
## ---------------------------------------------------------------------------
rigStart c-empty-reasoning
printf 'RIG-TOOLRESULT-MARKER\n' > "$rigScenarioDir/read.txt"
rigStream "$rigScenarioDir/res.1" "" "$( rigToolEvent rig-call "$rigScenarioDir/read.txt" )
$( rigToolClose 20 )"
rigStream "$rigScenarioDir/res.2" "" "$( rigTextEvent RIG-FINAL-MARKER 40 )"
rigRun normal
rigAssert "the run ends normally"                    "$rigRunStatus" 0
rigAssert "two rounds were requested"                "$( cat "$rigScenarioDir/round" )" 2
rigAssert "A BARE TOOL TURN STILL CARRIES THE FIELD, EMPTY" "$( rigField "$rigScenarioDir/req.2" messages.2.reasoning_content )" empty
rigAssert "the tool result still rides the history"  "$( rigHolds "$rigScenarioDir/req.2" 'RIG-TOOLRESULT-MARKER' )" yes
rigVerdict "a thinking round with no reasoning text still carries the field"

## ---------------------------------------------------------------------------
## D. Control: the same shape with the leg's thinking switched off. No turn gains the
##    field, which is what the non-thinking mode sends today.
## ---------------------------------------------------------------------------
rigStart d-thinking-off
printf 'RIG-TOOLRESULT-MARKER\n' > "$rigScenarioDir/read.txt"
rigStream "$rigScenarioDir/res.1" "" "$( rigToolEvent rig-call "$rigScenarioDir/read.txt" )
$( rigToolClose 20 )"
rigStream "$rigScenarioDir/res.2" "" "$( rigTextEvent RIG-FINAL-MARKER 40 )"
rigRun none
rigAssert "control: the run ends normally"           "$rigRunStatus" 0
rigAssert "control: two rounds were requested"       "$( cat "$rigScenarioDir/round" )" 2
rigAssert "control: NO FIELD IS INVENTED"            "$( rigHolds "$rigScenarioDir/req.2" 'reasoning_content' )" no
rigAssert "control: the tool result still rides it"  "$( rigHolds "$rigScenarioDir/req.2" 'RIG-TOOLRESULT-MARKER' )" yes
rigVerdict "a leg with no thinking gains no such field"

## ---------------------------------------------------------------------------
## E. The text is escaped, not pasted: quotes, a backslash, a newline and a non-ASCII
##    character arrive as the model gave them, and the body still parses.
## ---------------------------------------------------------------------------
rigStart e-escaped-text
printf 'RIG-TOOLRESULT-MARKER\n' > "$rigScenarioDir/read.txt"
rigStream "$rigScenarioDir/res.1" 'RIG-ESCAPE said \"quoted\" and a backslash \\ and \u00e9\nsecond line' "$( rigToolEvent rig-call "$rigScenarioDir/read.txt" )
$( rigToolClose 20 )"
rigStream "$rigScenarioDir/res.2" "" "$( rigTextEvent RIG-FINAL-MARKER 40 )"
rigRun normal
rigAssert "the run ends normally"                    "$rigRunStatus" 0
rigAssert "THE BODY STILL PARSES"                    "$( rigHolds "$rigScenarioDir/req.2" '"role":"system"' )" yes
rigAssert "the reasoning arrives as the model gave it" \
	"$( rigField "$rigScenarioDir/req.2" messages.2.reasoning_content )" \
	'RIG-ESCAPE said "quoted" and a backslash \ and é
second line'
rigVerdict "quotes, backslashes, newlines and non-ASCII survive the resend"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ THINKING REASONING CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_THINKING_REASONING: OK (%d scenarios, %d assertions, offline)\n' "$rigScenarioCount" "$rigPassCount"
