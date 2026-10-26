#!/usr/bin/env bash
## Behavioural check on options given with no answer form. A question with options and no
## select would be posted as a list that looks like answers and takes no click, so the call
## comes back to its caller as a CORRECTION that says to pass select one or many: nothing is
## posted, nothing is recorded. The same under the second name of the tools. A question taken
## back to free text by a revise leaves the options of the form before it, and one that asks
## for free text and options together is the same correction. Control: the same options with
## a select are posted, numbered. Offline: a Slack-shaped fake curl, first on PATH, answers
## every request.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-reply.include.sh" || { echo "⛔ ERROR: the rig's reply fixture is missing from the package: sh-test/check-fixtures/rig-reply.include.sh -- refusing to report a result" >&2 ; exit 1 ; }
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessAskOptionsSelectCheck.XXXXXX" )" || exit 1
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
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}
rigFirstWord(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstWord = $1 ; } END { print ( NR ? firstWord : "empty-output" ) ; }' "$1"
}
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
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
rigRecordId(){
	local recordId
	recordId="$( rigRecordFile )" ; recordId="${recordId##*/}"
	printf '%s' "${recordId%.md}"
}
rigRecordField(){ ## field
	LC_ALL=C awk -v key="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$( rigRecordFile )" 2>/dev/null || printf 'no-record'
}

rigScenarioDir=""
rigScenarioName=""
rigStart(){ ## scenario directory name
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/IN"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
## One served call of a tool, which must end on its own: only the last revise waits for an
## answer, which nobody gives, so it is stopped once its post is up. The rig's posts are of
## 2023, so every reminder of an ask would be due at once: MDAT_WAIT_REMIND=off sends none,
## and each post counted is the call's own.
rigKilled=""
rigCall(){ ## guard seconds, tool, argument object
	local callPid callLeft="$1"
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SPAWN_SESSION_ID="rig-options-$rigScenarioName" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 MDAT_WAIT_REMIND=off \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	callPid=$!
	set +m
	while kill -0 "$callPid" 2>/dev/null && [ "$callLeft" -gt 0 ] ; do
		sleep 1 ; callLeft=$(( callLeft - 1 ))
	done
	if kill -0 "$callPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$callPid" ; sleep 1 ; kill -KILL -- "-$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}

rigAsk='"to":"magic-team","address_to":"URIGOWNER"'
rigOptions='"options":"alpha -- the unit checks\nbeta -- the lint\ngamma -- the smoke run"'
rigCorrection='CORRECTION: AskQuestion: options are given with no select, so the post would list answers nobody can click. Pass select one to take one of them, or select many to take any number of them. Nothing was sent.'

echo "-- options with no select: a correction, and nothing posted --"
rigStart no-select
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",$rigOptions}"
rigAssert "it ended on its own"                          "$rigKilled" no
rigAssert "the result is the correction, whole, as its one line" "$( rigReplyBare < "$rigScenarioDir/out" )" "$rigCorrection"
rigAssert "its first word is CORRECTION, as the other corrections of the ask tools" "$( rigFirstWord "$rigScenarioDir/out" )" "CORRECTION:"
rigAssert "nothing was posted"                           "$( rigCalls chat.postMessage )" 0
rigAssert "no emoji was placed"                          "$( rigCalls reactions.add )" 0
rigAssert "and no record was left"                       "$( rigRecordCount )" 0
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",$rigOptions,\"wait\":false}"
rigAssert "the same with no wait asked for"              "$( rigFirstWord "$rigScenarioDir/out" ):$( rigCalls chat.postMessage ):$( rigRecordCount )" "CORRECTION::0:0"
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",$rigOptions,\"select\":\"text\"}"
rigAssert "select text is free text too: the same correction" "$( rigFirstWord "$rigScenarioDir/out" ):$( rigCalls chat.postMessage ):$( rigRecordCount )" "CORRECTION::0:0"
rigCall 60 AskUserQuestion "{$rigAsk,\"question\":\"Which check first?\",$rigOptions}"
rigAssert "under the second name of the tools: the same correction, naming the tool as called" \
	"$( rigHolds "$rigScenarioDir/out" 'CORRECTION: AskUserQuestion: options are given with no select' ):$( rigCalls chat.postMessage ):$( rigRecordCount )" "yes:0:0"

echo "-- control: the same options with a select are posted, numbered --"
rigStart with-select
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",$rigOptions,\"select\":\"one\",\"wait\":false}"
rigAssert "select one: posted"                           "$( rigFirstWord "$rigScenarioDir/out" ) $( sed -n '1s/^ASK-RESULT: //p' "$rigScenarioDir/out" ):$( rigCalls chat.postMessage )" "ASK-RESULT: POSTED:1"
rigAssert "its options are numbered, so each takes a click" "$( rigHolds "$rigScenarioDir/post.1" '- 2️⃣ beta -- the lint' )" yes
rigAssert "and their emoji are placed under it"          "$( LC_ALL=C awk '{ printf "%s ", $2 ; }' "$rigScenarioDir/reactions" 2>/dev/null )" "one two three "
rigStart with-many
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which checks?\",$rigOptions,\"select\":\"many\",\"wait\":false}"
rigAssert "select many: posted, with the mark that sends" "$( sed -n '1s/^ASK-RESULT: //p' "$rigScenarioDir/out" ):$( LC_ALL=C awk '{ printf "%s ", $2 ; }' "$rigScenarioDir/reactions" 2>/dev/null )" "POSTED:one two three ok "
rigStart no-options
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"What should the rig check first?\",\"wait\":false}"
rigAssert "control: a free-text question with no options is posted as before" "$( sed -n '1s/^ASK-RESULT: //p' "$rigScenarioDir/out" ):$( rigCalls chat.postMessage ):$( rigHolds "$rigScenarioDir/post.1" 'reply in this thread' )" "POSTED:1:yes"

echo "-- a question taken back to free text leaves its options --"
rigStart back-to-text
rigCall 60 AskQuestion "{$rigAsk,\"question\":\"Which check first?\",$rigOptions,\"select\":\"one\",\"wait\":false}"
rigId="$( rigRecordId )"
[ -f "$( rigRecordFile )" ] || rigRefuse "the question that is to be asked again was never recorded: $( head -1 "$rigScenarioDir/out" )"
rigAssert "control: its record keeps the form and the options" "$( rigRecordField select ):$( [ -s "${rigScenarioDir}/ws/.local/agents/pending/$rigId.options" ] && printf options || printf none )" "one:options"
rigCall 60 AskQuestion "{\"pending_id\":\"$rigId\",\"revise\":true,\"select\":\"text\",$rigOptions}"
rigAssert "asked again as free text with options: the correction, and the question stands as it was" \
	"$( rigFirstWord "$rigScenarioDir/out" ):$( rigCalls chat.postMessage ):$( rigRecordField select )" "CORRECTION::1:one"
## Asked again, it waits for its answer, which nobody gives here: stopped once its post is up.
rigCall 30 AskQuestion "{\"pending_id\":\"$rigId\",\"revise\":true,\"select\":\"text\"}"
rigAssert "asked again as free text: posted, with no list of options in it" \
	"$( rigCalls chat.postMessage ):$( rigHolds "$rigScenarioDir/post.2" 'Options' ):$( rigHolds "$rigScenarioDir/post.2" 'reply in this thread' )" "2:no:yes"
rigAssert "and its record keeps no form and no options"  "$( rigRecordField select ):$( [ -e "${rigScenarioDir}/ws/.local/agents/pending/$rigId.options" ] && printf options || printf none )" "none:none"

rigAssert "no request left this box"                    "$( cat "$rigTmp"/*/curl.log | LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK OPTIONS SELECT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: options with no answer form are posted as a list nobody can click, or the correction is not the one line an asker can act on" >&2
	echo "  fix:  repair AgentsHarnessAskCheck in AgentsUniversalHarness.sh -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_ASK_OPTIONS_SELECT: OK (%d assertions, offline)\n' "$rigPassCount"
