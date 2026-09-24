#!/usr/bin/env bash
## Behavioural check on the WAIT class -- `--member-wait-for-input` and the `Wait`
## harness tool that drives it. AgentsHarnessSelfCheck.awk beside it proves `Wait`
## occupies its four structural sites and nothing whatever about a wait returning:
## a build where TIMEOUT returned 1, or where an unknown source kind timed out
## instead of erroring, leaves that report byte-identical to a clean one. This one
## RUNS the operation and the tool -- early return, the TIMEOUT/ERROR split, an
## unknown kind, a failing source among several, the --wait-since-utime baseline,
## and the source listing -- and then runs the marker back through the real harness
## to prove it reaches the model as what it was. Offline by construction: a fake
## `curl` is first on PATH and refuses every request that is not one of this
## check's own canned model rounds, every source used is a `file:` source under
## this check's own temp tree, and nothing outlives the EXIT trap.
set -u
rigHere="$( cd "$( dirname -- "$0" )" && pwd )"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigInclude="$rigHere/AgentsTools.MemberWait.include"
rigTool="${rigHere%/*}/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigHarness" ] || rigRefuse "harness not found beside this check: $rigHarness"
[ -f "$rigInclude" ] || rigRefuse "the wait operation is not beside this check: $rigInclude"
[ -x "$rigTool" ] || rigRefuse "the team tooling is not on the path the Wait tool itself resolves: $rigTool"
[ -n "${MMDAPP:-}" ] || rigRefuse "MMDAPP is not set, so the operation has no workspace to place its own working directory under"

rigTmp="$( mktemp -d -t AgentsHarnessWaitCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## Every request any part of this check could issue passes through here, and it
## opens no socket. A model round replays this round's canned stream; anything
## else -- a Slack read above all -- is recorded and refused. The log is what turns
## "offline" from an intention into an assertion: the scenarios below check it is
## empty, and the closing one checks nothing in it ever named Slack.
## The fake binaries this rig puts on PATH are REAL FILES under sh-lib/check-fixtures
## and are copied, never carried here in a heredoc: a delimiter lost inside a body
## that is itself shell takes the rest of this check with it, and a check that stops
## checking still prints its PASS lines. A missing fixture refuses instead.
mkdir -p "$rigTmp/bin"
rigFixtures="$rigHere/check-fixtures"
cp "$rigFixtures/harness-wait-check.curl.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigFixtures/harness-wait-check.curl.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
RIG_CURL_LOG="$rigTmp/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"

## A provider stub's job, done here instead: the core refuses to start without these.
## The host is a reserved .invalid name that can never resolve and the token is a
## literal, so nothing in this rig can reach a service or spend a credential.
export HARNESS_PROVIDER_NAME="wait-check rig"
export HARNESS_SELF_NAME="AgentsHarnessWaitCheck.sh"
export HARNESS_ENDPOINT="https://harness-wait-check.invalid/v1/chat/completions"
export HARNESS_HOST="harness-wait-check.invalid"
export HARNESS_WIRE="OpenAiChat"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_LIGHT="rig-not-a-credential"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"

rigPassCount=0
rigFailCount=0
rigScenarioCount=0
rigScenarioPass=0
rigScenarioFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigScenarioPass=$(( rigScenarioPass + 1 ))
	else
		rigScenarioFail=$(( rigScenarioFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

rigVerdict(){ ## scenario title
	local verdictMark=PASS
	[ "$rigScenarioFail" = 0 ] || verdictMark=FAIL
	printf '  %s  %s -- %d of %d assertions\n' "$verdictMark" "$1" "$rigScenarioPass" "$(( rigScenarioPass + rigScenarioFail ))"
	rigPassCount=$(( rigPassCount + rigScenarioPass ))
	rigFailCount=$(( rigFailCount + rigScenarioFail ))
	rigScenarioCount=$(( rigScenarioCount + 1 ))
	rigScenarioPass=0
	rigScenarioFail=0
}

## yes/no rather than a status, so both directions are values a failure can print.
## A file that was never written gets its own third value: it is not the same
## finding as one written without the text, and a bare `no` would read as one.
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-output' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}

## The FIRST line, not a substring anywhere: the contract is that stdout OPENS with
## the marker, and a marker buried under a line of bootstrap noise is a different
## build from a conforming one while every substring probe reads them alike.
rigMarker(){ ## stdout file
	[ -f "$1" ] || { printf 'no-such-output' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}

## ... and exactly one of them. Two markers on one stdout is a caller reading the
## first and acting on the second.
rigMarkerLines(){ ## stdout file
	LC_ALL=C awk '/^WAIT-RESULT: / { markerCount++ ; } END { print markerCount + 0 ; }' "$1" 2>/dev/null || printf 'no-such-output'
}

## The seconds the operation itself reports it spent, off its own `# waited:` line.
rigWaited(){ ## stdout file
	LC_ALL=C awk '/^# waited: / { waitedLine = $0 ; sub(/^# waited: /, "", waitedLine) ; sub(/s of .*/, "", waitedLine) ; } END { if ( waitedLine == "" ) { waitedLine = "no-waited-line" ; } print waitedLine ; }' "$1" 2>/dev/null || printf 'no-such-output'
}

## A bound reported as a token rather than a bare number, so a failure prints what
## it actually measured instead of `1` against `1`.
rigWithin(){ ## value, ceiling
	case "$1" in
		''|*[!0-9]*) printf 'not-a-number-%s' "$1" ; return 0 ;;
	esac
	[ "$1" -le "$2" ] || { printf 'over-%s-by-%s' "$2" "$(( $1 - $2 ))" ; return 0 ; }
	printf 'within-%s' "$2"
}
rigAtLeast(){ ## value, floor
	case "$1" in
		''|*[!0-9]*) printf 'not-a-number-%s' "$1" ; return 0 ;;
	esac
	[ "$1" -ge "$2" ] || { printf 'under-%s' "$2" ; return 0 ; }
	printf 'at-least-%s' "$2"
}

## The text the MODEL was shown as this call's result, pulled out of the request
## body on its own. Asserting against the whole body would be vacuous: the body
## also carries the Wait tool's own description, which states every phrase a result
## can carry -- TIMEOUT, COMPLETE SUCCESSFUL wait, the wait could not be performed --
## so a probe over the body reports them present whatever the tool returned.
rigToolResult(){ ## request-body file, destination file
	[ -f "$1" ] || { printf 'no-such-request\n' > "$2" ; return 0 ; }
	## The body is not one line -- the system prompt reaches it carrying its own
	## newlines -- so this walks the whole file and keeps the FIRST tool result,
	## rather than answering once per line.
	LC_ALL=C awk '
		foundResult == 0 {
			roleAt = index($0, "\"role\":\"tool\"") ;
			if ( roleAt > 0 ) {
				bodyText = substr($0, roleAt) ;
				contentAt = index(bodyText, "\"content\":\"") ;
				if ( contentAt > 0 ) {
					bodyText = substr(bodyText, contentAt + 11) ;
					endAt = index(bodyText, "\"}") ;
					if ( endAt > 0 ) { bodyText = substr(bodyText, 1, endAt - 1) ; }
					resultText = bodyText ;
					foundResult = 1 ;
				}
			}
		}
		END { if ( foundResult == 0 ) { resultText = "no-tool-result-in-this-request" ; } print resultText ; }
	' "$1" > "$2"
}

## The result's OPENING, not a substring of it: the contract is that the marker is
## the first thing read, and the tool is what has to preserve that across its own
## boundary.
rigPrefix(){ ## file, prefix
	[ -f "$1" ] || { printf 'no-such-output' ; return 0 ; }
	case "$( cat "$1" )" in
		"$2"*) printf 'yes' ;;
		*)     printf 'no' ;;
	esac
}

rigCurlCalls(){
	LC_ALL=C awk 'END { print NR + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}
rigCurlNamed(){ ## substring
	LC_ALL=C awk -v wantText="$1" 'index($0, wantText) > 0 { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}

## The operation, on the very path the Wait tool resolves, with its output in files
## rather than a capture: the operation drives reads that fork, and a capture
## returns on pipe EOF rather than on the process that holds it.
rigOpStatus=0
rigOpElapsed=0
rigOpOut=""
rigOpErr=""
## The longest any one call here may take. The scenario proving an unknown kind
## refuses at second zero has to name a bound long enough that returning at it
## would be unmistakable, and a build that stopped refusing would then sit on that
## bound: an instrument for "does a wait ever return" cannot be one that hangs when
## it does not. The operation is backgrounded directly so $! is the real killable
## pid, and the wait is on the process rather than on a pipe.
rigOpGuard=45
rigOp(){ ## output basename, then the operation's own arguments
	local opName="$1" opStart opEnd opPid opWatchPid
	shift
	rigOpOut="$rigTmp/$opName.out"
	rigOpErr="$rigTmp/$opName.err"
	rigOpStatus=0
	opStart="$( date +%s )"
	"$rigTool" --member-wait-for-input "$@" > "$rigOpOut" 2> "$rigOpErr" &
	opPid=$!
	(
		opLeft="$rigOpGuard"
		while [ "$opLeft" -gt 0 ] ; do
			kill -0 "$opPid" 2>/dev/null || exit 0
			sleep 1
			opLeft=$(( opLeft - 1 ))
		done
		printf 'rig: the wait did not return within %ss, and was killed\n' "$rigOpGuard" >> "$rigTmp/$opName.err"
		kill -TERM "$opPid" 2>/dev/null
		sleep 2
		kill -KILL "$opPid" 2>/dev/null
		## The operation names its own working directory after its own pid, so a
		## killed run's leftovers are removable by name rather than by pattern.
		rm -rf -- "$MMDAPP/.local/temp/mdat-member-wait.$rigMember.$opPid"
	) &
	opWatchPid=$!
	wait "$opPid" || rigOpStatus=$?
	kill -TERM "$opWatchPid" 2>/dev/null
	wait "$opWatchPid" 2>/dev/null || :
	opEnd="$( date +%s )"
	rigOpElapsed=$(( opEnd - opStart ))
}

## An arrival, mid-wait. Backgrounded directly so $! is the real killable pid and
## the scenario can wait on the process rather than on a pipe.
rigWriterPid=""
rigDropAfter(){ ## seconds, file, text
	( sleep "$1" ; printf '%s\n' "$3" >> "$2" ) &
	rigWriterPid=$!
}
rigDropDone(){
	[ -z "$rigWriterPid" ] || wait "$rigWriterPid"
	rigWriterPid=""
}

## ---------------------------------------------------------------------------
## 1. An arrival mid-wait returns on the arrival, not on the bound.
## ---------------------------------------------------------------------------
rigDropA="$rigTmp/dropA.txt"
: > "$rigDropA"
rigDropAfter 1 "$rigDropA" RIG-ARRIVAL-MARKER
rigOp early-return "$rigMember" --wait-source "file:$rigDropA" --wait-timeout 30 --wait-poll-interval 1
rigDropDone
rigAssert "the marker line opens stdout"              "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: RECEIVED"
rigAssert "exactly one marker line"                   "$( rigMarkerLines "$rigOpOut" )" 1
rigAssert "an arrival is a successful wait"           "$rigOpStatus" 0
rigAssert "it returned on the arrival, not the bound" "$( rigWithin "$rigOpElapsed" 10 )" "within-10"
rigAssert "the operation reports the same"            "$( rigWithin "$( rigWaited "$rigOpOut" )" 10 )" "within-10"
rigAssert "it names the source that fired"            "$( rigHolds "$rigOpOut" "# arrived on: file:$rigDropA" )" yes
rigAssert "it carries what that source now holds"     "$( rigHolds "$rigOpOut" 'RIG-ARRIVAL-MARKER' )" yes
## The probe-failure line is absent HERE, which is what makes its presence in
## scenario 4 a finding rather than boilerplate every wait prints.
rigAssert "no probe was reported as unable to run"    "$( rigHolds "$rigOpOut" 'probes that could not run' )" no
rigAssert "no request left this box"                  "$( rigCurlCalls )" 0
rigVerdict "an arrival mid-wait returns promptly, naming the source and its content"

## ---------------------------------------------------------------------------
## 2. TIMEOUT is rc 0, and is not ERROR. The single assertion this whole check
##    exists for: inverted, an agent loses the choice between waiting again and
##    escalating. Scenario 1 is its control on the marker, scenario 3 on the rc.
## ---------------------------------------------------------------------------
rigDropB="$rigTmp/dropB.txt"
: > "$rigDropB"
rigOp timeout "$rigMember" --wait-source "file:$rigDropB" --wait-timeout 2 --wait-poll-interval 1
rigAssert "the marker line opens stdout"                "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: TIMEOUT"
rigAssert "exactly one marker line"                     "$( rigMarkerLines "$rigOpOut" )" 1
rigAssert "A COMPLETE WAIT RETURNS 0"                   "$rigOpStatus" 0
rigAssert "it is not dressed as an error"               "$( rigHolds "$rigOpOut" 'WAIT-RESULT: ERROR' )" no
rigAssert "stderr carries no diagnostic either"         "$( rigHolds "$rigOpErr" '⛔ ERROR' )" no
rigAssert "it says in words that this is not a fault"   "$( rigHolds "$rigOpOut" 'COMPLETE, SUCCESSFUL wait' )" yes
rigAssert "it really waited the bound out"              "$( rigAtLeast "$( rigWaited "$rigOpOut" )" 2 )" "at-least-2"
rigAssert "no request left this box"                    "$( rigCurlCalls )" 0
rigVerdict "the bound expires with nothing new -- TIMEOUT, rc 0, and never an error"

## ---------------------------------------------------------------------------
## 3. An unknown source kind errors at second zero, naming the kinds that exist.
##    Its control shares the same 600-second bound and answers the other way on
##    the marker, on the rc and on the diagnostic -- which is the only control
##    that could: one returning at the bound would take ten minutes to run.
## ---------------------------------------------------------------------------
rigOp unknown-kind "$rigMember" --wait-source "pigeon:roost" --wait-timeout 600 --wait-poll-interval 1
rigAssert "the marker line opens stdout"                "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: ERROR"
rigAssert "exactly one marker line"                     "$( rigMarkerLines "$rigOpOut" )" 1
rigAssert "A WAIT THAT COULD NOT RUN RETURNS 1"         "$rigOpStatus" 1
rigAssert "it refused at second zero, not at the bound" "$( rigWithin "$rigOpElapsed" 10 )" "within-10"
rigAssert "the diagnostic names the kind it was given"  "$( rigHolds "$rigOpErr" "kind 'pigeon'" )" yes
rigAssert "it names the kinds this build carries"       "$( rigHolds "$rigOpErr" 'Kinds this build carries: slack file' )" yes
rigAssert "it says this is not a wait that found nothing" "$( rigHolds "$rigOpErr" 'NOT a wait that found nothing' )" yes
rigAssert "nothing was reported as waited on"           "$( rigHolds "$rigOpOut" '# waited:' )" no
rigAssert "no request left this box"                    "$( rigCurlCalls )" 0

rigDropC="$rigTmp/dropC.txt"
printf 'RIG-ALREADY-THERE\n' > "$rigDropC"
rigOp known-kind-control "$rigMember" --wait-source "file:$rigDropC" --wait-since-utime 1 --wait-timeout 600 --wait-poll-interval 1
rigAssert "control: a known kind on the same bound"     "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: RECEIVED"
rigAssert "control: it returns 0"                       "$rigOpStatus" 0
rigAssert "control: also at second zero"                "$( rigWithin "$rigOpElapsed" 10 )" "within-10"
rigAssert "control: no kinds-this-build diagnostic"     "$( rigHolds "$rigOpErr" 'Kinds this build carries' )" no
rigVerdict "an unknown source kind -- ERROR at second zero, rc 1, naming the kinds that exist"

## ---------------------------------------------------------------------------
## 4. One source that cannot be read does not silence the wait over the others.
##    A relative path is the unreadable one: the file adapter rejects it outright,
##    so the failure is the adapter's own and needs no unreachable host to stage.
## ---------------------------------------------------------------------------
rigDropD="$rigTmp/dropD.txt"
: > "$rigDropD"
rigDropAfter 1 "$rigDropD" RIG-THROUGH-MARKER
rigOp failing-source "$rigMember" --wait-source "file:not-an-absolute-path" --wait-source "file:$rigDropD" --wait-timeout 30 --wait-poll-interval 1
rigDropDone
rigAssert "the wait still returned on the good source"  "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: RECEIVED"
rigAssert "it returns 0"                                "$rigOpStatus" 0
rigAssert "the unreadable source is named"              "$( rigHolds "$rigOpOut" '[file:not-an-absolute-path]' )" yes
rigAssert "the good source is the one that fired"       "$( rigHolds "$rigOpOut" "# arrived on: file:$rigDropD" )" yes
rigAssert "its content came through"                    "$( rigHolds "$rigOpOut" 'RIG-THROUGH-MARKER' )" yes
rigAssert "it returned on the arrival, not the bound"   "$( rigWithin "$rigOpElapsed" 10 )" "within-10"

## The same unreadable source ALONE: a wait that can read nothing still completes,
## still returns 0, and still says that silence is not quiet.
rigOp failing-source-alone "$rigMember" --wait-source "file:not-an-absolute-path" --wait-timeout 2 --wait-poll-interval 1
rigAssert "alone: the wait completes"                   "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: TIMEOUT"
rigAssert "alone: it returns 0"                         "$rigOpStatus" 0
rigAssert "alone: the unreadable source is named"       "$( rigHolds "$rigOpOut" '[file:not-an-absolute-path]' )" yes
rigAssert "alone: its silence is not read as quiet"     "$( rigHolds "$rigOpOut" 'Do not read their silence as quiet' )" yes
rigAssert "no request left this box"                    "$( rigCurlCalls )" 0
rigVerdict "a source that cannot be read is named while the wait carries on over the rest"

## ---------------------------------------------------------------------------
## 5. The --wait-since-utime baseline switch. Three legs over ONE file holding ONE
##    unchanging content: the flag is the only difference between the first two,
##    so each is the other's control, and the third shows what the omitted form
##    does count.
## ---------------------------------------------------------------------------
rigDropE="$rigTmp/dropE.txt"
printf 'RIG-PRESENT-MARKER\n' > "$rigDropE"
rigOp since-named "$rigMember" --wait-source "file:$rigDropE" --wait-since-utime 1 --wait-timeout 30 --wait-poll-interval 1
rigAssert "named: content already there returns at once" "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: RECEIVED"
rigAssert "named: it returns 0"                          "$rigOpStatus" 0
rigAssert "named: the baseline is the empty one"         "$( rigHolds "$rigOpOut" 'baseline: empty' )" yes
rigAssert "named: it did not wait"                       "$( rigWithin "$rigOpElapsed" 10 )" "within-10"
rigAssert "named: it carries the content that was there" "$( rigHolds "$rigOpOut" 'RIG-PRESENT-MARKER' )" yes

rigOp since-omitted "$rigMember" --wait-source "file:$rigDropE" --wait-timeout 2 --wait-poll-interval 1
rigAssert "omitted: the same content counts as nothing"  "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: TIMEOUT"
rigAssert "omitted: it returns 0"                        "$rigOpStatus" 0
rigAssert "omitted: the baseline is the first probe"     "$( rigHolds "$rigOpOut" 'baseline: first-probe' )" yes
rigAssert "omitted: it waited the bound out"             "$( rigAtLeast "$( rigWaited "$rigOpOut" )" 2 )" "at-least-2"

rigDropAfter 1 "$rigDropE" RIG-LATER-MARKER
rigOp since-omitted-then-changed "$rigMember" --wait-source "file:$rigDropE" --wait-timeout 30 --wait-poll-interval 1
rigDropDone
rigAssert "omitted: a LATER change does count"           "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: RECEIVED"
rigAssert "omitted: it returns 0"                        "$rigOpStatus" 0
rigAssert "omitted: still the first-probe baseline"      "$( rigHolds "$rigOpOut" 'baseline: first-probe' )" yes
rigAssert "omitted: the later line is what arrived"      "$( rigHolds "$rigOpOut" 'RIG-LATER-MARKER' )" yes
rigAssert "no request left this box"                     "$( rigCurlCalls )" 0
rigVerdict "the --wait-since-utime baseline -- named returns what is there, omitted waits for a change"

## ---------------------------------------------------------------------------
## 6. The listing reports what this build actually carries. Counted against the
##    adapter functions DEFINED IN THE SOURCE rather than against the list the
##    operation prints from: a check reading the same variable the subject prints
##    would confirm consistency and never correctness.
## ---------------------------------------------------------------------------
rigOp list-sources "$rigMember" --wait-list-sources
rigProbesDefined="$( LC_ALL=C awk '/^AgentsWaitProbe[A-Z][A-Za-z]*\(\)\{/ && $0 !~ /^AgentsWaitProbeFunctionName/ { definedCount++ ; } END { print definedCount + 0 ; }' "$rigInclude" )"
rigProbesListed="$( LC_ALL=C awk -F'\t' 'NF == 2 { listedCount++ ; } END { print listedCount + 0 ; }' "$rigOpOut" )"
rigAssert "the marker line opens stdout"                "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: RECEIVED"
rigAssert "it returns 0"                                "$rigOpStatus" 0
rigAssert "it waited on nothing"                        "$( rigHolds "$rigOpOut" '# waited:' )" no
rigAssert "one listed kind per adapter in the source"   "$rigProbesListed" "$rigProbesDefined"
rigAssert "at least one adapter is defined at all"      "$( rigAtLeast "$rigProbesDefined" 1 )" "at-least-1"
rigProbeNames=""
while IFS= read -r rigProbeLine ; do
	rigProbeNames="$rigProbeNames${rigProbeLine%%(*} "
done < <( LC_ALL=C awk '/^AgentsWaitProbe[A-Z][A-Za-z]*\(\)\{/ && $0 !~ /^AgentsWaitProbeFunctionName/ { print $0 ; }' "$rigInclude" )
for rigProbeName in $rigProbeNames ; do
	rigAssert "the source defines $rigProbeName and the listing offers it" "$( rigHolds "$rigOpOut" "$rigProbeName" )" yes
done
rigAssert "the file adapter is offered by name"         "$( rigHolds "$rigOpOut" 'file' )" yes
## The negative control: a kind no adapter defines is absent from the listing, so
## the assertions above are matching what is there rather than matching anything.
rigAssert "a kind nothing defines is not offered"       "$( rigHolds "$rigOpOut" 'pigeon' )" no
rigAssert "nor is its function name"                    "$( rigHolds "$rigOpOut" 'AgentsWaitProbePigeon' )" no
rigAssert "no request left this box"                    "$( rigCurlCalls )" 0
rigVerdict "--wait-list-sources reports exactly the adapters this build defines"

## ---------------------------------------------------------------------------
## 7. The `Wait` harness tool, through the REAL harness and the REAL wire: the
##    four sites the self-check reads are exercised instead -- the declaration on
##    the wire, the announce arm, the dispatch arm, and the operation's own answer
##    coming back as the tool result. What matters here is that the TIMEOUT/ERROR
##    split survives the tool boundary: a harness that flattened the two would
##    leave every assertion above green and still cost the agent the choice.
## ---------------------------------------------------------------------------
rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/.local/temp"
	printf '0' > "$rigScenarioDir/round"
}

## A round answering with one Wait tool call, then the usage chunk the core reads.
rigWaitStream(){ ## canned-stream file, sources value, timeout value
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-wait-call","type":"function","function":{"name":"Wait","arguments":"{\\"sources\\":\\"%s\\",\\"timeout\\":\\"%s\\",\\"poll_interval\\":\\"1\\"}"}}]}}]}\n' "$2" "$3" > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' >> "$1"
	printf 'data: [DONE]\n' >> "$1"
}

## A round answering with plain text and no tool call.
rigTextStream(){ ## canned-stream file, content
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' "$2" > "$1"
	printf 'data: [DONE]\n' >> "$1"
}

rigRunStatus=0
rigRoundCount=0
rigRun(){ ## the harness arguments this scenario adds
	rigRunStatus=0
	## MMDAPP points at the scenario, so the core's own PreToolUse hooks read no
	## settings file of the real workspace and the operation's own working
	## directory is this scenario's too.
	RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" \
		MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
		"$rigHarness" --access-root "$rigScenarioDir" "$@" RIG-TASK-MARKER \
		> "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || rigRunStatus=$?
	rigRoundCount="$( cat "$rigScenarioDir/round" )"
	[ "$rigRoundCount" != 0 ] || rigRefuse "the harness issued no request at all, so this scenario exercised nothing"
}

rigStart tool-timeout
rigDropF="$rigScenarioDir/dropF.txt"
: > "$rigDropF"
rigWaitStream "$rigScenarioDir/res.1" "file:$rigDropF" 2
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun --agent "$rigMember"
rigToolResult "$rigScenarioDir/req.2" "$rigScenarioDir/result"
rigAssert "the run ends normally"                        "$rigRunStatus" 0
rigAssert "two rounds were requested"                    "$rigRoundCount" 2
rigAssert "the declaration reached the wire"             "$( rigHolds "$rigScenarioDir/req.1" '"name":"Wait"' )" yes
rigAssert "the announce arm stated this call"            "$( rigHolds "$rigScenarioDir/err" '{"sources":"file:' )" yes
rigAssert "the dispatch arm did not fall through"        "$( rigHolds "$rigScenarioDir/req.2" 'unknown tool' )" no
rigAssert "a tool result was returned at all"            "$( rigHolds "$rigScenarioDir/result" 'no-tool-result-in-this-request' )" no
rigAssert "THE MODEL IS SHOWN TIMEOUT, AS ITS OPENING"   "$( rigPrefix "$rigScenarioDir/result" 'WAIT-RESULT: TIMEOUT' )" yes
rigAssert "it is not dressed as a failed wait"           "$( rigHolds "$rigScenarioDir/result" 'the wait could not be performed' )" no
rigAssert "the model is told it is not a fault"          "$( rigHolds "$rigScenarioDir/result" 'COMPLETE, SUCCESSFUL wait' )" yes
rigAssert "the source it waited on is named to the model" "$( rigHolds "$rigScenarioDir/result" "file:$rigDropF" )" yes
rigAssert "the round carried on to an answer"            "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "the Wait tool -- declaration, announce, dispatch, and a TIMEOUT reaching the model as TIMEOUT"

## The other half of the split, over the same tool and the same two rounds: the
## kind is the only thing that changed, and every probe answers the other way.
rigStart tool-error
rigWaitStream "$rigScenarioDir/res.1" "pigeon:roost" 2
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun --agent "$rigMember"
rigToolResult "$rigScenarioDir/req.2" "$rigScenarioDir/result"
rigAssert "the run ends normally"                        "$rigRunStatus" 0
rigAssert "two rounds were requested"                    "$rigRoundCount" 2
rigAssert "the announce arm stated this call"            "$( rigHolds "$rigScenarioDir/err" '{"sources":"pigeon:roost"' )" yes
rigAssert "a tool result was returned at all"            "$( rigHolds "$rigScenarioDir/result" 'no-tool-result-in-this-request' )" no
rigAssert "THE MODEL IS SHOWN A FAILED WAIT, AS ITS OPENING" "$( rigPrefix "$rigScenarioDir/result" 'ERROR: the wait could not be performed' )" yes
rigAssert "it is not dressed as a wait that found nothing" "$( rigHolds "$rigScenarioDir/result" 'WAIT-RESULT' )" no
rigAssert "the model is told nothing is known"           "$( rigHolds "$rigScenarioDir/result" 'NOTHING is known about those sources' )" yes
rigAssert "the operation's own reason reaches it"        "$( rigHolds "$rigScenarioDir/result" "kind 'pigeon'" )" yes
rigAssert "and the kinds that do exist"                  "$( rigHolds "$rigScenarioDir/result" 'Kinds this build carries: slack file' )" yes
rigAssert "the round carried on to an answer"            "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "the Wait tool -- an unwaitable source reaching the model as a failed wait, not as silence"

## No team identity: the tool refuses before the operation is reached at all, so a
## wait is never performed under a guessed name.
rigStart tool-no-agent
rigDropG="$rigScenarioDir/dropG.txt"
: > "$rigDropG"
rigWaitStream "$rigScenarioDir/res.1" "file:$rigDropG" 2
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun
rigToolResult "$rigScenarioDir/req.2" "$rigScenarioDir/result"
rigAssert "the run ends normally"                        "$rigRunStatus" 0
rigAssert "two rounds were requested"                    "$rigRoundCount" 2
rigAssert "a tool result was returned at all"            "$( rigHolds "$rigScenarioDir/result" 'no-tool-result-in-this-request' )" no
rigAssert "the refusal names the missing identity"       "$( rigPrefix "$rigScenarioDir/result" 'ERROR: this harness was started without --agent' )" yes
rigAssert "it states that nothing was waited on"         "$( rigHolds "$rigScenarioDir/result" 'Nothing was waited on' )" yes
rigAssert "no wait was performed at all"                 "$( rigHolds "$rigScenarioDir/result" 'WAIT-RESULT' )" no
rigAssert "the round carried on to an answer"            "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "the Wait tool with no --agent -- refused before any wait, and never under a guessed name"

## ---------------------------------------------------------------------------
## The offline claim, asserted rather than stated. Every request any part of this
## check made is in the log, and the only requests there may be are this check's
## own canned model rounds against a .invalid host.
## ---------------------------------------------------------------------------
rigAssert "nothing ever reached slack.com"               "$( rigCurlNamed 'slack.com' )" 0
rigAssert "nor any slack host at all"                    "$( rigCurlNamed 'slack' )" 0
rigAssert "every request was this check's own model round" "$( rigCurlNamed 'harness-wait-check.invalid' )" "$( rigCurlCalls )"
rigAssert "and there were some, so the log is live"      "$( rigAtLeast "$( rigCurlCalls )" 6 )" "at-least-6"
rigVerdict "offline -- every request this check could make is logged, and none of them left this box"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_WAIT: OK (%d scenarios, %d assertions, offline)\n' "$rigScenarioCount" "$rigPassCount"
