#!/usr/bin/env bash
## Behavioural check on what an ask says about itself, run through --intern-tool, the path the
## myx.distro MCP uses. Every ask has a cold reader: a person, or a member with none of the
## asking run's context. Covers: the About line every ask post opens with, to the human-owner
## and to a team member alike, filled by the tooling from the asking run's own records -- the
## plain title of the task it works on, and the system it concerns -- and left out whole where
## those records name neither; the plain-words refusal of a question carrying a file path, a
## file name with a line, a code token in backticks, an internal id or a bare uuid, for every
## ask kind and every addressee, with the same detail in the context accepted; and the request
## an authority check posts, which says in words what it allows and about what.
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessAskAboutCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
. "$rigTest/check-fixtures/rig-owner-writes.include.sh" || rigRefuse "the store-write fixture is missing from the package"

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
rigFirstLine(){
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}
## What a post was sent with: its body text, one line per line.
rigPostedLines(){ ## post number
	[ -f "$rigScenarioDir/post.$1" ] || return 0
	LC_ALL=C awk '{
		at = index( $0, "\"text\":\"" ) ; if ( ! at ) { exit } ;
		rest = substr( $0, at + 8 ) ;
		end = 0 ;
		marks[1] = "\",\"thread_ts\":" ; marks[2] = "\",\"ts\":" ; marks[3] = "\",\"blocks\":" ;
		for ( markNo = 1 ; markNo <= 3 ; markNo++ ) { markAt = index( rest, marks[markNo] ) ; if ( markAt > 0 && ( end == 0 || markAt < end ) ) { end = markAt ; } }
		if ( end > 0 ) { rest = substr( rest, 1, end - 1 ) ; }
		gsub( /\\n/, "\n", rest ) ;
		print rest ;
	}' "$rigScenarioDir/post.$1" 2>/dev/null
}
## Where a post first carries a word, counting from 1, or 0 where it carries none.
rigLineOf(){ ## post number, word
	LC_ALL=C awk -v wantWord="$2" 'index( $0, wantWord ) { print NR ; found = 1 ; exit } END { if ( ! found ) { print 0 } }' <<< "$( rigPostedLines "$1" )"
}
## How many lines of a post carry a word.
rigTimes(){ ## post number, word
	LC_ALL=C awk -v wantWord="$2" 'index( $0, wantWord ) { hitCount++ } END { print hitCount + 0 }' <<< "$( rigPostedLines "$1" )"
}
rigPosts(){ ## method
	[ -f "$rigScenarioDir/calls" ] || { printf '0' ; return 0 ; }
	LC_ALL=C awk -v wantMethod="$1" '$1 == wantMethod { hitCount++ } END { print hitCount + 0 }' "$rigScenarioDir/calls" 2>/dev/null || printf 'no-such-log'
}
rigVerdictLine(){
	LC_ALL=C awk '/^VERDICT: / { print ; found = 1 ; exit } END { if ( ! found ) { print "no-verdict-line" } }' "$rigScenarioDir/out"
}
## The shape the refusal names, as the check reads it out of the line: `<a shape>` or `none`.
rigRefusalShape(){ ## the call's output file
	LC_ALL=C awk '
		/^CORRECTION: / {
			said = $0 ;
			sub( /^.* carries /, "", said ) ;
			sub( /, which .*/, "", said ) ;
			sub( / \(.*/, "", said ) ;
			print said ; found = 1 ; exit ;
		}
		END { if ( ! found ) { print "none" } }
	' "$1"
}

rigScenarioDir=""
rigScenarioName=""
rigSession=""
rigKilled=""
rigStart(){ ## scenario directory name, the run id the ask is made as
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	rigSession="$2"
	rigKilled="no"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/IN" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
	rigWs="$rigScenarioDir/ws" ; rigData="$rigScenarioDir/data" ; rigAs="$rigMember"
}
## One thread as conversations.replies returns it: its first message with what the scenario
## puts on it, then the later messages.
rigThread(){ ## first message ts suffix, its extra fields (may be empty), later messages (may be empty)
	printf '{"ok":true,"messages":[{"ts":"1700000001.%s","user":"URIGSELF1","text":"first"%s}%s],"has_more":false}\n' \
		"$1" "$2" "$3" > "$rigScenarioDir/replies.json"
}
rigOwnerClick(){ ## option name the owner clicked
	printf ',"reactions":[{"name":"%s","count":2,"users":["URIGSELF1","URIGOWNER"]}]' "$1"
}

## The run's own records: the task it works on, and the workspace it executes in. Written by
## the stores' own writers, never by hand.
rigAskTask="task-20300101T0000Z-retire-the-old-sync"
rigAskTitle="Task: retire the old sync from the reporting job"
rigAskSystem="ws-rig-farm"
rigAskRunRecords(){
	rigOwnerBoardWrite running "$rigAskTask.md" -- '---\ntype: task\nowner: %s\n---\n\n# %s\n\nThe reporting job stops at the old sync.\n' "$rigMember" "$rigAskTitle" \
		|| rigRefuse "the board item of the run's task could not be written"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: %s\nspawned-by: %s\nexecuting-workspace: %s\nsession-comment: the rig ask\n---\n' \
		"$rigSession" "$rigSession" "$rigMember" "$rigAskTask" "$rigAskSystem" | rigOwnerSpawnPut "$rigSession" \
		|| rigRefuse "the run's own record could not be written"
}

## One served call of a tool. A question nobody answers is re-waited without end by design, so
## the guard is the scenario's: a killed run is reported as such, never as a result.
rigCall(){ ## guard seconds, tool, argument object
	local callPid callLeft
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD \
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID="$rigSession" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" \
		MDAT_HARNESS_WAIT_TIMEOUT=1 MDAT_SLACK_READ_BOUND_SECONDS=60 \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	callPid=$!
	set +m
	callLeft="$1"
	while kill -0 "$callPid" 2>/dev/null && [ "$callLeft" -gt 0 ] ; do
		sleep 1
		callLeft=$(( callLeft - 1 ))
	done
	if kill -0 "$callPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$callPid" ; sleep 1 ; kill -KILL -- "$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}

rigDecisionOptions='"options":"alpha -- the unit checks\nbeta -- the lint"'

## The plain-words renderer of the tree under test, where it has one: on a tree without it the act
## is passed as it stands, which is what the authority scenario's assertions then measure.
. "$rigHere/questions/AgentsTools.AskAbout.include" || true
rigPlainWords(){ ## value
	if type AgentsToolsAskWordsPlain > /dev/null 2>&1 ; then AgentsToolsAskWordsPlain "$1" ; else printf '%s' "$1" ; fi
}

echo "-- a decision to the human-owner from a run working a task: its post says what it is about --"
rigStart decision-about about-run
rigAskRunRecords
rigThread 000101 "$( rigOwnerClick one )" ""
rigCall 180 EscalateDecision "{\"to\":\"human-owner\",\"question\":\"Which check should run first?\",$rigDecisionOptions}"
rigAssert "the post carries the task's title once, above the question" \
	"$( rigTimes 1 "$rigAskTitle" ):$( [ "$( rigLineOf 1 "$rigAskTitle" )" -gt 0 ] && [ "$( rigLineOf 1 "$rigAskTitle" )" -lt "$( rigLineOf 1 'Which check should run first?' )" ] && echo above || echo not-above )" \
	"1:above"
rigAssert "and the system it concerns, on the same line as the title" \
	"$( rigLineOf 1 "$rigAskSystem" ):$( rigLineOf 1 "$rigAskTitle" )" \
	"$( rigLineOf 1 "$rigAskTitle" ):$( rigLineOf 1 "$rigAskTitle" )"
rigAssert "the system is printed once" "$( rigTimes 1 "$rigAskSystem" )" "1"
rigAssert "two posts made -- the question, then its confirmation -- and the owner's click is the answer" \
	"$( rigPosts chat.postMessage ):$rigKilled:$( rigVerdictLine )" "2:no:VERDICT: alpha"

echo "-- a run whose records name no task: the About line is left out whole, and the ask still goes --"
rigStart decision-no-records about-none
rigThread 000101 "$( rigOwnerClick two )" ""
rigCall 180 EscalateDecision "{\"to\":\"human-owner\",\"question\":\"Which check should run first?\",$rigDecisionOptions}"
rigAssert "no About line, and the question goes: two posts, its confirmation after it" \
	"$( rigTimes 1 'About' ):$( rigPosts chat.postMessage )" "0:2"
rigAssert "the answer still reads: the second option" "$rigKilled:$( rigVerdictLine )" "no:VERDICT: beta"

echo "-- the same About line on an ask to a team member, who is a cold reader too --"
rigStart member-about about-member
rigAskRunRecords
rigCall 180 AskQuestion '{"to":"magic-team","address_to":"magic-tester","question":"Which check should run first?","wait":false}'
rigAssert "a question to a member carries the title and the system once each" \
	"$( rigPosts chat.postMessage ):$( rigTimes 1 "$rigAskTitle" ):$( rigTimes 1 "$rigAskSystem" )" "1:1:1"

echo "-- a path is refused for every ask kind and every addressee, and accepted in the context --"
rigStart kind-decision-path about-kind-decision
rigAskRunRecords
rigCall 40 EscalateDecision '{"to":"human-owner","question":"Which of these two should I keep, /Volumes/rig/skin/a or b?","options":"keep -- the first\nother -- the second"}'
rigAssert "a decision to the human-owner: refused, naming the path, and nothing posted" \
	"$( rigRefusalShape "$rigScenarioDir/out" ):$( rigPosts chat.postMessage )" "a file path:0"

rigStart kind-question-path about-kind-question
rigAskRunRecords
rigCall 40 AskQuestion '{"to":"human-owner","question":"Which of the two files under /Volumes/rig/skin/ should go?","select":"yes-no"}'
rigAssert "a question to the human-owner: refused too" "$( rigRefusalShape "$rigScenarioDir/out" )" "a file path"

rigStart kind-readback-path about-kind-readback
rigAskRunRecords
rigCall 40 ConfirmReadback '{"to":"human-owner","question":"Is /Volumes/rig/skin/a the right file?","understood":"The rig keeps it.","source":"The message of today.","will_do":"Keep it."}'
rigAssert "a readback: refused too" "$( rigRefusalShape "$rigScenarioDir/out" )" "a file path"

rigStart kind-permission-path about-kind-permission
rigAskRunRecords
rigCall 40 AskQuestion '{"to":"magic-team","address_to":"magic-tester","question":"May I write /Volumes/rig/skin/a now?","wait":false}'
rigAssert "a question to a member: refused too, since a member is a cold reader" \
	"$( rigRefusalShape "$rigScenarioDir/out" ):$( rigPosts chat.postMessage )" "a file path:0"

rigStart context-path about-context
rigAskRunRecords
rigThread 000101 "$( rigOwnerClick two )" ""
rigCall 180 EscalateDecision '{"to":"human-owner","question":"Which of these two should I keep?","context":"They are the two folders /Volumes/rig/skin/a and /Volumes/rig/skin/b.","options":"keep -- the first\nother -- the second"}'
rigAssert "the same path in the context is accepted: the About line on the post, the path once" \
	"$rigKilled:$( rigPosts chat.postMessage ):$( rigTimes 1 "$rigAskTitle" ):$( rigTimes 1 '/Volumes/rig/skin/a' )" "no:2:1:1"
rigAssert "and the answer reads: the second option" "$( rigVerdictLine )" "VERDICT: other"

echo "-- a file name with a line, a code token, an internal id and a bare uuid are refused by name --"
rigStart shape-line about-line
rigAskRunRecords
rigCall 40 AskQuestion '{"to":"human-owner","question":"Is FORK.md:53 the line that changed?","select":"yes-no"}'
rigAssert "a file name and line" "$( rigRefusalShape "$rigScenarioDir/out" )" "a file name and line"

rigStart shape-backticks about-backticks
rigAskRunRecords
rigCall 40 AskQuestion '{"to":"human-owner","question":"Which of `alpha` and `beta` should I run?","select":"yes-no"}'
rigAssert "a code token between backticks" "$( rigRefusalShape "$rigScenarioDir/out" )" "a code token between backticks"

rigStart shape-id about-id
rigAskRunRecords
rigCall 40 AskQuestion '{"to":"human-owner","question":"Should refusal-f76d9a57 be lifted now?","select":"yes-no"}'
rigAssert "an internal id" "$( rigRefusalShape "$rigScenarioDir/out" )" "an internal id"

rigStart shape-uuid about-uuid
rigAskRunRecords
rigCall 40 AskQuestion '{"to":"human-owner","question":"Is 5f1007f3-4d21-4c0e-9a77-8c1f2b3d4e5f still waiting?","select":"yes-no"}'
rigAssert "a bare uuid" "$( rigRefusalShape "$rigScenarioDir/out" )" "an internal id"

rigStart shape-hex about-hex
rigAskRunRecords
rigCall 40 AskQuestion '{"to":"human-owner","question":"May I answer question 7e6ebbc0 with yes?","select":"yes-no"}'
rigAssert "a bare hex id, as a permission request showed it" "$( rigRefusalShape "$rigScenarioDir/out" )" "an internal id"

echo "-- a plain question still goes, which is the control on the refusal --"
rigStart plain-question about-plain
rigAskRunRecords
rigCall 180 AskQuestion '{"to":"magic-team","address_to":"magic-tester","question":"Should cafe food stay cheap?","wait":false}'
rigAssert "a plain question, with no shape in it, is posted with no correction" \
	"$( rigRefusalShape "$rigScenarioDir/out" ):$( rigPosts chat.postMessage )" "none:1"

echo "-- the request an authority check posts says in words what it allows, and about what --"
rigStart authority-words about-authority
rigAskRunRecords
rigAuthorityPost="$(
	ASKP_F_refused_tool="$( rigPlainWords 'answer question 7e6ebbc0 with yes' )" ASKP_F_refused_for=magic-coordinator \
	ASKP_F_refusal_id=refusal-rig ASKP_F_reason='the manager does not hold that authority' ASKP_F_task='magic-coordinator ran an operation that needs that authority.' \
	ASKP_F_about="$rigAskTitle -- $rigAskSystem" ASKP_F_allowed_words="$( rigPlainWords 'answer question 7e6ebbc0 with yes' )" \
	ASKP_WANT=post ASKP_FORM=grant LC_ALL=C awk -f "$rigHere/comms/AgentsToolingTemplateFill.awk" -f "$rigHere/questions/AgentsAskPostFill.awk" "$rigHere/templates/request-permission.post.format.md"
)"
rigAssert "its first line says the act without the id, and the line under it does too" \
	"$( printf '%s\n' "$rigAuthorityPost" | LC_ALL=C grep -c 'Allow \*\*answer question that one with yes\*\*' ):$( printf '%s\n' "$rigAuthorityPost" | LC_ALL=C grep -c 'This allows: answer question that one with yes.' )" "1:1"
rigAssert "and it carries the About line, so a cold reader knows what it is about" \
	"$( printf '%s\n' "$rigAuthorityPost" | LC_ALL=C grep -c -F "$rigAskTitle" )" "1"

echo
if [ "$rigFailCount" -eq 0 ] ; then
	printf 'HARNESS_ASK_ABOUT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
	exit 0
fi
printf 'HARNESS_ASK_ABOUT: FAIL (%d of %d assertions)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
exit 1
