#!/usr/bin/env bash
## Behavioural check on the WAIT class -- `--member-wait-for-input` and the `Wait`
## harness tool that drives it. AgentsHarnessSelfCheck.test.awk beside it proves `Wait`
## occupies its four structural sites and nothing whatever about a wait returning:
## a build where TIMEOUT returned 1, or where an unknown source kind timed out
## instead of erroring, leaves that report byte-identical to a clean one. This one
## RUNS the operation and the tool -- early return, the TIMEOUT/ERROR split, an
## unknown kind, a failing source among several, the --wait-since-utime baseline,
## the source listing, the --wait-include-own mismatch refusal, and the own-post
## filter it governs -- and then runs the marker back through the real harness
## to prove it reaches the model as what it was. Offline by construction: a fake
## `curl` is first on PATH and refuses every request that is not one of this
## check's own canned model rounds, every source used is a `file:` source under
## this check's own temp tree, and nothing outlives the EXIT trap.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigInclude="$rigHere/AgentsTools.MemberWait.include"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -f "$rigInclude" ] || rigRefuse "the wait operation is not at the origin this workspace resolves: $rigInclude"
[ -x "$rigTool" ] || rigRefuse "the team tooling is not on the path the Wait tool itself resolves: $rigTool"

rigTmp="$( mktemp -d -t AgentsHarnessWaitCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## Every request any part of this check could issue passes through here, and it
## opens no socket. A model round replays this round's canned stream; anything
## else -- a Slack read above all -- is recorded and refused. The log is what turns
## "offline" from an intention into an assertion: the scenarios below check it is
## empty, and the closing one checks nothing in it ever named Slack.
## The fake binaries this rig puts on PATH are REAL FILES under sh-test/check-fixtures
## and are copied, never carried here in a heredoc: a delimiter lost inside a body
## that is itself shell takes the rest of this check with it, and a check that stops
## checking still prints its PASS lines. A missing fixture refuses instead.
mkdir -p "$rigTmp/bin"
rigFixtures="$rigTest/check-fixtures"
cp "$rigFixtures/harness-wait-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigFixtures/harness-wait-check.curl.test.sh"
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
export HARNESS_SELF_NAME="AgentsHarnessWaitCheck.test.sh"
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
rigAssert "it says the sources were read"               "$( rigHolds "$rigOpOut" 'those sources were read' )" yes
rigAssert "no never-read line when every source was read" "$( rigHolds "$rigOpOut" 'WAIT-NEVER-READ:' )" no
rigAssert "it does not say none could be read"          "$( rigHolds "$rigOpOut" 'None of the sources could be read' )" no
rigAssert "it names no source as never read"            "$( rigHolds "$rigOpOut" 'these sources could not be read at all' )" no
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
rigAssert "alone: it says none could be read"           "$( rigHolds "$rigOpOut" 'None of the sources could be read' )" yes
rigAssert "alone: the never-read line names it"         "$( rigHolds "$rigOpOut" 'WAIT-NEVER-READ: [file:not-an-absolute-path]' )" yes
rigAssert "alone: it claims no read at all"             "$( rigHolds "$rigOpOut" 'were read' )" no
rigAssert "alone: it claims no successful wait"         "$( rigHolds "$rigOpOut" 'COMPLETE, SUCCESSFUL' )" no

## One unreadable source beside one readable source that stays empty: the text
## names which was read and which never was.
rigDropM="$rigTmp/dropM.txt"
: > "$rigDropM"
rigOp failing-source-mixed "$rigMember" --wait-source "file:not-an-absolute-path" --wait-source "file:$rigDropM" --wait-timeout 2 --wait-poll-interval 1
rigAssert "mixed: the wait completes"                   "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: TIMEOUT"
rigAssert "mixed: it returns 0"                         "$rigOpStatus" 0
rigAssert "mixed: the read source is named as read"     "$( rigHolds "$rigOpOut" "on the sources that were read: [file:$rigDropM]" )" yes
rigAssert "mixed: the other is named as never read"     "$( rigHolds "$rigOpOut" 'nothing is known about them either way: [file:not-an-absolute-path]' )" yes
rigAssert "mixed: it does not say none could be read"   "$( rigHolds "$rigOpOut" 'None of the sources could be read' )" no
rigAssert "mixed: no blanket read claim"                "$( rigHolds "$rigOpOut" 'those sources were read' )" no
rigAssert "mixed: the never-read line names only the unread one" "$( LC_ALL=C awk '/^WAIT-NEVER-READ: / { print ; }' "$rigOpOut" )" "WAIT-NEVER-READ: [file:not-an-absolute-path]"
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
## 8. --wait-include-own only changes anything on a :conversation source: refused
##    everywhere else, with its own same-call control proving the flag is what
##    gets refused -- the control succeeds on the identical source with only the
##    flag dropped.
## ---------------------------------------------------------------------------
rigDropH="$rigTmp/dropH.txt"
: > "$rigDropH"
rigOp include-own-mismatch "$rigMember" --wait-source "file:$rigDropH" --wait-timeout 2 --wait-poll-interval 1 --wait-include-own
rigAssert "the marker line opens stdout"                 "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: ERROR"
rigAssert "A REFUSED COMBINATION RETURNS 1"               "$rigOpStatus" 1
rigAssert "it refused at second zero, not at the bound"   "$( rigWithin "$rigOpElapsed" 10 )" "within-10"
rigAssert "the diagnostic names the flag"                 "$( rigHolds "$rigOpErr" '--wait-include-own' )" yes
rigAssert "nothing was reported as waited on"             "$( rigHolds "$rigOpOut" '# waited:' )" no

rigOp include-own-mismatch-control "$rigMember" --wait-source "file:$rigDropH" --wait-timeout 2 --wait-poll-interval 1
rigAssert "control: the same source, flag dropped, completes" "$( rigMarker "$rigOpOut" )" "WAIT-RESULT: TIMEOUT"
rigAssert "control: it returns 0"                         "$rigOpStatus" 0
rigAssert "control: no mismatch diagnostic"               "$( rigHolds "$rigOpErr" 'wait-include-own' )" no
rigVerdict "--wait-include-own on a source where it has no effect -- refused, with a same-source control"

## ---------------------------------------------------------------------------
## 9. AgentsSlackThreadAnswers.awk itself -- the default skips the caller's own
##    post on a :conversation rendering, and -v includeOwn=1 brings it back. The
##    same two-line rendering both times, so the flag is the only variable between
##    the primary and its control -- and the other member's post counts in both,
##    which is what proves this is a filter and not a wipe.
## ---------------------------------------------------------------------------
rigAnswersAwk="$rigHere/AgentsSlackThreadAnswers.awk"
rigRenderFile="$rigTmp/render.conversation.txt"
cat > "$rigRenderFile" <<RIG_RENDER
1700000002.000001 | U100 | [sender: $rigMember] RIG-OWN-POST
1700000003.000001 | U200 | [sender: some-other-member] RIG-OTHER-POST
RIG_RENDER

rigAnswersDefault="$rigTmp/answers.default.out"
LC_ALL=C awk -v rootTs=1700000001.000000 -v fromUsers="" -v tag="" -v threadCount=0 -v others="" -v mode="conversation" -v callerName="$rigMember" -v includeOwn=0 \
	-f "$rigAnswersAwk" < "$rigRenderFile" > "$rigAnswersDefault" 2>/dev/null
rigAssert "default: the caller's own post is excluded"    "$( rigHolds "$rigAnswersDefault" 'RIG-OWN-POST' )" no
rigAssert "default: the other member's post still counts" "$( rigHolds "$rigAnswersDefault" 'RIG-OTHER-POST' )" yes

rigAnswersIncluded="$rigTmp/answers.included.out"
LC_ALL=C awk -v rootTs=1700000001.000000 -v fromUsers="" -v tag="" -v threadCount=0 -v others="" -v mode="conversation" -v callerName="$rigMember" -v includeOwn=1 \
	-f "$rigAnswersAwk" < "$rigRenderFile" > "$rigAnswersIncluded" 2>/dev/null
rigAssert "control: includeOwn=1 brings the own post back" "$( rigHolds "$rigAnswersIncluded" 'RIG-OWN-POST' )" yes
rigAssert "control: the other member's post still counts"  "$( rigHolds "$rigAnswersIncluded" 'RIG-OTHER-POST' )" yes
rigVerdict "AgentsSlackThreadAnswers.awk -- the own-post skip is real, and includeOwn=1 lifts exactly it"

## ---------------------------------------------------------------------------
## 10. The session Wait -- three mutually exclusive modes (--wait-default,
##     --wait-continue, --wait-close), stored state, the seen/note/done/wait id
##     sets reacted before any read, ids and floors, one round returning every
##     source that differs, the own-inbox and board macro-event kinds, and the
##     internal poll. Every call runs in a workspace of its own under this rig's
##     temp tree, so no state lands in the real workspace, and the Slack-shaped
##     fake curl (never the model-round one above) answers on its own log. Each
##     row has a same-scenario control that answers the other way.
## ---------------------------------------------------------------------------
rigSlackBin="$rigTmp/slackbin"
mkdir -p "$rigSlackBin"
cp "$rigFixtures/harness-ask-check.curl.test.sh" "$rigSlackBin/curl" \
	|| rigRefuse "the Slack-shaped fake curl fixture is missing from the package: $rigFixtures/harness-ask-check.curl.test.sh"
chmod +x "$rigSlackBin/curl"
rigSlackPath="$rigSlackBin:$PATH"
[ "$( PATH="$rigSlackPath" command -v curl )" = "$rigSlackBin/curl" ] || rigRefuse "the Slack-shaped fake curl is not first on its PATH, so a new row could issue real requests"

## One table, so the emoji map is one place to change: set, emoji, message ts.
rigReactTable="seen:eyes:1700000001.000200 note:writing_hand:1700000001.000300 done:white_check_mark:1700000001.000400 wait:hourglass_flowing_sand:1700000001.000500"
rigReactChannel="CRIG00001"
rigReactThread="1700000001.000101"

rigNewDir=""
rigNewSession=""
rigNewPoll="1"
rigNewStatus=0
rigNewElapsed=0
rigNewOut=""
rigNewErr=""
rigNewGuard=40
rigNewOrigin=""
rigNewStart(){ ## scenario name
	rigNewDir="$rigTmp/new-$1"
	rigNewSession="rig-sess-$1"
	rigNewPoll="1"
	rigNewOrigin=""
	mkdir -p "$rigNewDir/ws/.local/.agents" "$rigNewDir/ws/.local/temp" "$rigNewDir/data/inboxes/$rigMember" "$rigNewDir/data/board/pending"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigNewDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigNewDir/ws/.local/.agents/$rigMember.agent.env"
	: > "$rigNewDir/curl.log"
}
## The thread: opener, then the scenario's later messages. The fixture's own
## account, URIGSELF1, is this member's; URIGOWNER's posts are the arrivals.
rigNewReplies(){ ## later messages, optional thread ts (default: the shared replies.json)
	local repliesFile="$rigNewDir/replies.json"
	[ -z "${2:-}" ] || repliesFile="$rigNewDir/replies.$2.json"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"opener"}%s],"has_more":false}\n' "${2:-$rigReactThread}" "$1" > "$repliesFile"
}
rigOwnerPost(){ ## ts, text, thread ts
	printf ',{"ts":"%s","user":"URIGOWNER","text":"%s","thread_ts":"%s"}' "$1" "$2" "$3"
}
## The operation under the scenario's own workspace, session store and inbox, with
## the guard rigOp has: a wait that does not return is killed and says so. The poll
## env is set from rigNewPoll, and an empty rigNewPoll leaves it unset.
rigNew(){ ## output basename, then the operation's own arguments
	local opName="$1" opStart opEnd opPid opWatchPid
	shift
	rigNewOut="$rigNewDir/$opName.out"
	rigNewErr="$rigNewDir/$opName.err"
	rigNewStatus=0
	local opTool="$rigTool"
	[ -z "$rigNewOrigin" ] || opTool="$rigNewOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
	opStart="$( date +%s )"
	env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_WAIT_POLL_SECONDS \
		"PATH=$rigSlackPath" "RIG_CURL_LOG=$rigNewDir/curl.log" "RIG_SCENARIO=$rigNewDir" "MMDAPP=$rigNewDir/ws" "MDAT_DATA_ROOT=$rigNewDir/data" \
		${rigNewOrigin:+MDLT_ORIGIN=$rigNewOrigin} \
		${rigNewPoll:+MDAT_WAIT_POLL_SECONDS=$rigNewPoll} \
		"$opTool" --member-wait-for-input "$rigMember" "$@" > "$rigNewOut" 2> "$rigNewErr" &
	opPid=$!
	(
		opLeft="$rigNewGuard"
		while [ "$opLeft" -gt 0 ] ; do
			kill -0 "$opPid" 2>/dev/null || exit 0
			sleep 1
			opLeft=$(( opLeft - 1 ))
		done
		printf 'rig: the wait did not return within %ss, and was killed\n' "$rigNewGuard" >> "$rigNewErr"
		kill -TERM "$opPid" 2>/dev/null
		sleep 2
		kill -KILL "$opPid" 2>/dev/null
	) &
	opWatchPid=$!
	wait "$opPid" || rigNewStatus=$?
	kill -TERM "$opWatchPid" 2>/dev/null
	wait "$opWatchPid" 2>/dev/null || :
	opEnd="$( date +%s )"
	rigNewElapsed=$(( opEnd - opStart ))
}
rigNewIn(){ ## output basename, then arguments -- under the scenario's own session id
	local inName="$1"
	shift
	rigNew "$inName" "$@" --wait-session-id "$rigNewSession"
}
## The Nth line of a file, or a token saying why there is none.
rigNth(){ ## file, line number
	[ -f "$1" ] || { printf 'no-such-output' ; return 0 ; }
	LC_ALL=C awk -v wantLine="$2" 'NR == wantLine { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-such-line" ; } }' "$1"
}
## How many lines OPEN with a text.
rigOpens(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-output' ; return 0 ; }
	LC_ALL=C awk -v wantText="$2" 'index($0, wantText) == 1 { hitCount++ ; } END { print hitCount + 0 ; }' "$1"
}
rigLines(){ ## file -- how many lines it holds, 0 for a file never written
	[ -f "$1" ] || { printf 0 ; return 0 ; }
	LC_ALL=C awk 'END { print NR + 0 ; }' "$1"
}
rigReactCount(){ ## "<ts> <name>" -- how many times the fake Slack was asked for that reaction
	[ -f "$rigNewDir/reactions" ] || { printf 0 ; return 0 ; }
	LC_ALL=C awk -v wantText="$1" '$0 == wantText { hitCount++ ; } END { print hitCount + 0 ; }' "$rigNewDir/reactions"
}
rigNewState(){ ## session id -- the stored wait state directory, present or absent
	[ -d "$rigNewDir/ws/.local/agents/sessions/$1/wait" ] && printf present || printf absent
}
rigNewStateFile(){ ## session id
	[ -f "$rigNewDir/ws/.local/agents/sessions/$1/wait/state" ] && printf present || printf absent
}
## Every reaction before the first read of the thread: validate, react, then wait.
rigReactsFirst(){
	[ -f "$rigNewDir/curl.log" ] || { printf 'no-such-log' ; return 0 ; }
	LC_ALL=C awk '
		$0 == "reactions.add" { lastReact = NR ; }
		$0 == "conversations.replies" && firstRead == 0 { firstRead = NR ; }
		END {
			if ( lastReact == 0 ) { print "no-reactions" ; }
			else if ( firstRead == 0 ) { print "no-read" ; }
			else if ( lastReact < firstRead ) { print "reactions-first" ; }
			else { print "read-first" ; }
		}' "$rigNewDir/curl.log"
}

## ---------------------------------------------------------------------------
## 10a. Two or three modes together are ERROR and nothing is done. The control is
##      the same call with one mode.
## ---------------------------------------------------------------------------
rigNewStart modes
rigDropN="$rigNewDir/dropN.txt"
: > "$rigDropN"
rigPairNo=0
for rigPair in "--wait-default --wait-continue" "--wait-default --wait-close" "--wait-continue --wait-close" "--wait-default --wait-continue --wait-close" ; do
	rigPairNo=$(( rigPairNo + 1 ))
	rigNewIn "pair-$rigPairNo" $rigPair --wait-source "file:$rigDropN" --wait-timeout 600
	rigAssert "[$rigPair] the marker line opens stdout"        "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: ERROR"
	rigAssert "[$rigPair] returns 1"                           "$rigNewStatus" 1
	rigAssert "[$rigPair] refused at second zero, not the bound" "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
	rigAssert "[$rigPair] names the rule"                      "$( rigHolds "$rigNewErr" 'modes are mutually exclusive' )" yes
	rigAssert "[$rigPair] nothing was waited on"               "$( rigHolds "$rigNewOut" '# waited:' )" no
	rigAssert "[$rigPair] no state was stored"                 "$( rigNewState "$rigNewSession" )" absent
done
rigNewIn mode-one --wait-default --wait-source "file:$rigDropN" --wait-timeout 2
rigAssert "control: one mode is a wait"                        "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
rigAssert "control: it returns 0"                              "$rigNewStatus" 0
rigAssert "control: it says which mode ran"                    "$( rigNth "$rigNewOut" 2 )" "WAIT-MODE: default"
rigAssert "control: no exclusivity diagnostic"                 "$( rigHolds "$rigNewErr" 'mutually exclusive' )" no
rigAssert "no request left this box"                           "$( rigLines "$rigNewDir/curl.log" )" 0
rigVerdict "the three modes are mutually exclusive -- ERROR at second zero with nothing done, one mode a wait"

## ---------------------------------------------------------------------------
## 10b. A mode flag with no session id is ERROR, for each mode. The control gives
##      the session id.
## ---------------------------------------------------------------------------
rigNewStart nosession
rigDropO="$rigNewDir/dropO.txt"
: > "$rigDropO"
for rigMode in default continue close ; do
	rigNew "nosession-$rigMode" "--wait-$rigMode" --wait-source "file:$rigDropO" --wait-timeout 600
	rigAssert "[$rigMode] the marker line opens stdout"        "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: ERROR"
	rigAssert "[$rigMode] returns 1"                           "$rigNewStatus" 1
	rigAssert "[$rigMode] refused at second zero"              "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
	rigAssert "[$rigMode] the diagnostic names the missing id" "$( rigHolds "$rigNewErr" '--wait-session-id' )" yes
	rigAssert "[$rigMode] nothing was waited on"               "$( rigHolds "$rigNewOut" '# waited:' )" no
done
rigNewIn nosession-control --wait-close
rigAssert "control: close with a session id completes"         "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: CLOSED"
rigAssert "control: it returns 0"                              "$rigNewStatus" 0
rigVerdict "a mode flag with no session id -- ERROR for each mode, and the same flag with one completes"

## ---------------------------------------------------------------------------
## 10c. --close resets and returns at once, and closing with nothing stored is
##      still CLOSED. Its control is --default, which waits the bound out.
## ---------------------------------------------------------------------------
rigNewStart close
rigDropP="$rigNewDir/dropP.txt"
: > "$rigDropP"
rigNewIn close-none --wait-close --wait-source "file:$rigDropP" --wait-timeout 600
rigAssert "close with nothing stored: CLOSED opens stdout"     "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: CLOSED"
rigAssert "it names its mode on the next line"                 "$( rigNth "$rigNewOut" 2 )" "WAIT-MODE: close"
rigAssert "it returns 0"                                       "$rigNewStatus" 0
rigAssert "it returned at once, not at the 600s bound"         "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
rigAssert "it did not wait"                                    "$( rigHolds "$rigNewOut" '# waited:' )" no
rigAssert "it is visible in the log, with member and session"  "$( rigHolds "$rigNewErr" "# --member-wait-for-input: mode=close member=$rigMember session=$rigNewSession" )" yes
rigNewIn close-twice --wait-close
rigAssert "closing twice is CLOSED the second time too"        "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: CLOSED"
rigAssert "and returns 0"                                      "$rigNewStatus" 0
rigNewIn default-stores --wait-default --wait-source "file:$rigDropP" --wait-timeout 2
rigAssert "control: default waited the bound out"              "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
rigAssert "control: it really waited"                          "$( rigAtLeast "$( rigWaited "$rigNewOut" )" 2 )" "at-least-2"
rigAssert "a TIMEOUT stores the session state"                 "$( rigNewStateFile "$rigNewSession" )" present
rigNewIn close-stored --wait-close --wait-timeout 600
rigAssert "close with state stored: CLOSED"                    "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: CLOSED"
rigAssert "close removed the wait directory"                   "$( rigNewState "$rigNewSession" )" absent
rigNewIn continue-after-close --wait-continue --wait-timeout 600
rigAssert "continue after close has nothing stored: ERROR"     "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: ERROR"
rigAssert "it returns 1"                                       "$rigNewStatus" 1
rigAssert "it is not a default wait run instead"               "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
rigAssert "no request left this box"                           "$( rigLines "$rigNewDir/curl.log" )" 0
rigVerdict "--close -- returns at once, CLOSED even with nothing stored, removes the state; --default is its waiting control"

## ---------------------------------------------------------------------------
## 10d. --continue uses the stored sources and filters; --default resets and
##      stores. Over file sources, so no message ids are involved.
## ---------------------------------------------------------------------------
rigNewStart continue
rigDropA2="$rigNewDir/dropA.txt"
rigDropB2="$rigNewDir/dropB.txt"
: > "$rigDropA2"
: > "$rigDropB2"
rigNewIn continue-nostate --wait-continue --wait-timeout 600
rigAssert "continue with no stored state: ERROR"               "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: ERROR"
rigAssert "it returns 1"                                       "$rigNewStatus" 1
rigAssert "it is not a default wait in disguise"               "$( rigHolds "$rigNewOut" '# waited:' )" no
rigAssert "it returned at second zero"                         "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
rigAssert "it stored nothing"                                  "$( rigNewState "$rigNewSession" )" absent

rigNewIn default-first --wait-default --wait-source "file:$rigDropA2" --wait-timeout 2
rigAssert "default: the marker line opens stdout"              "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
rigAssert "default: the mode is the second line"               "$( rigNth "$rigNewOut" 2 )" "WAIT-MODE: default"
rigAssert "default: it returns 0"                              "$rigNewStatus" 0
rigAssert "default: the filters it used are returned"          "$( rigOpens "$rigNewOut" '# filters:' )" 1
rigAssert "default: the reaction counts are returned"          "$( rigHolds "$rigNewOut" '# reactions: seen=0 note=0 done=0 wait=0 failed=' )" yes
rigAssert "default: the stderr trace names mode, member and session" "$( rigHolds "$rigNewErr" "# --member-wait-for-input: mode=default member=$rigMember session=$rigNewSession" )" yes
rigAssert "default: the state is stored"                       "$( rigNewStateFile "$rigNewSession" )" present

rigNewIn continue-control --wait-continue --wait-timeout 2
rigAssert "control: continue with state is a wait"             "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
rigAssert "control: the mode is continue"                      "$( rigNth "$rigNewOut" 2 )" "WAIT-MODE: continue"
rigAssert "control: the stored source is the one waited on"    "$( rigHolds "$rigNewOut" "# sources: file:$rigDropA2" )" yes
rigAssert "control: the trace says continue"                   "$( rigHolds "$rigNewErr" "# --member-wait-for-input: mode=continue member=$rigMember session=$rigNewSession" )" yes

rigDropAfter 1 "$rigDropA2" RIG-CONTINUE-ARRIVAL
rigNewIn continue-arrival --wait-continue --wait-timeout 30
rigDropDone
rigAssert "continue returns on an arrival at the stored source" "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "it names the stored source that fired"              "$( rigHolds "$rigNewOut" "# arrived on: file:$rigDropA2" )" yes
rigAssert "it carries the arrival"                             "$( rigHolds "$rigNewOut" 'RIG-CONTINUE-ARRIVAL' )" yes
rigAssert "it returned on the arrival, not the bound"          "$( rigWithin "$rigNewElapsed" 10 )" "within-10"

## Continue takes its sources and filters from the store: naming them is ERROR.
## Each refusal is checked against the stored state, so the argument is what is
## refused, and the continue after them is the control that the state survived.
for rigRefused in "--wait-source file:$rigDropB2" "--wait-since-utime 1700000000" "--wait-addressee URIGOWNER" "--wait-include-own" ; do
	rigNewIn continue-refused --wait-continue $rigRefused --wait-timeout 600
	rigAssert "[continue $rigRefused] the marker line opens stdout" "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: ERROR"
	rigAssert "[continue $rigRefused] returns 1"               "$rigNewStatus" 1
	rigAssert "[continue $rigRefused] refused at second zero"  "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
	rigAssert "[continue $rigRefused] nothing was waited on"   "$( rigHolds "$rigNewOut" '# waited:' )" no
done
rigNewIn continue-after-refusals --wait-continue --wait-timeout 2
rigAssert "control: the state survived the refusals"           "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
rigAssert "control: still the stored source"                   "$( rigHolds "$rigNewOut" "# sources: file:$rigDropA2" )" yes

## Default resets: the second default's source replaces the first's.
rigNewIn default-second --wait-default --wait-source "file:$rigDropB2" --wait-timeout 2
rigAssert "default again: waited on the new source"            "$( rigHolds "$rigNewOut" "# sources: file:$rigDropB2" )" yes
rigNewIn continue-after-reset --wait-continue --wait-timeout 2
rigAssert "continue after a reset uses the new source"         "$( rigHolds "$rigNewOut" "# sources: file:$rigDropB2" )" yes
rigAssert "and nothing of the old one"                         "$( rigHolds "$rigNewOut" "file:$rigDropA2" )" no
## State belongs to its session: another session's continue finds nothing.
rigNew continue-other-session --wait-continue --wait-session-id "rig-sess-other" --wait-timeout 600
rigAssert "another session has no state: ERROR"                "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: ERROR"
rigAssert "it returns 1"                                       "$rigNewStatus" 1
## State is written on RECEIVED or TIMEOUT only: an ERROR run stores nothing.
rigNew default-error --wait-default --wait-session-id "rig-sess-erroring" --wait-source "pigeon:roost" --wait-timeout 600
rigAssert "an erroring default is ERROR"                       "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: ERROR"
rigAssert "it stored nothing"                                  "$( rigNewState rig-sess-erroring )" absent
rigAssert "no request left this box"                           "$( rigLines "$rigNewDir/curl.log" )" 0
rigVerdict "--continue repeats the stored wait, refuses what the store already holds, and --default resets it"

## ---------------------------------------------------------------------------
## 10e. Macro-events on a non-Slack kind: a file added to the own inbox, or the
##      board, between two calls is returned at once by --continue. The control is
##      the same two calls with nothing added, which times out.
## ---------------------------------------------------------------------------
rigNewStart inbox
rigNewSession="rig-sess-inbox-control"
rigNewIn inbox-control-default --wait-default --wait-source "inbox:$rigMember" --wait-timeout 2
rigAssert "control: an empty own inbox is a TIMEOUT"           "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
rigNewIn inbox-control-continue --wait-continue --wait-timeout 2
rigAssert "control: nothing added between the calls: TIMEOUT"  "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
rigAssert "control: it really waited"                          "$( rigAtLeast "$( rigWaited "$rigNewOut" )" 2 )" "at-least-2"
rigNewSession="rig-sess-inbox"
rigNewIn inbox-default --wait-default --wait-source "inbox:$rigMember" --wait-timeout 2
rigAssert "the first call times out"                           "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
printf 'RIG-INBOX-NOTE\n' > "$rigNewDir/data/inboxes/$rigMember/note-rig-arrival.md"
rigNewIn inbox-continue --wait-continue --wait-timeout 30
rigAssert "a file added between two calls: RECEIVED"           "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "it returned at once, not at the bound"              "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
rigAssert "it names the inbox source"                          "$( rigHolds "$rigNewOut" "# arrived on: inbox:$rigMember" )" yes
rigAssert "it lists the new item"                              "$( rigHolds "$rigNewOut" 'note-rig-arrival.md' )" yes
rigNewIn inbox-other --wait-default --wait-source "inbox:magic-team" --wait-timeout 600
rigAssert "another member's inbox is refused"                  "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: ERROR"
rigAssert "it returns 1"                                       "$rigNewStatus" 1
rigAssert "it refused at second zero"                          "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
rigNewSession="rig-sess-board"
rigNewIn board-default --wait-default --wait-source "board:pending" --wait-timeout 2
rigAssert "an unchanged board state is a TIMEOUT"              "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
printf 'RIG-BOARD-ITEM\n' > "$rigNewDir/data/board/pending/task-rig-arrival.md"
rigNewIn board-continue --wait-continue --wait-timeout 30
rigAssert "an item added to the board state: RECEIVED"         "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "it returned at once"                                "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
rigAssert "it names the board source"                          "$( rigHolds "$rigNewOut" '# arrived on: board:pending' )" yes
rigAssert "it lists the new item"                              "$( rigHolds "$rigNewOut" 'task-rig-arrival.md' )" yes
rigAssert "no request left this box"                           "$( rigLines "$rigNewDir/curl.log" )" 0
rigVerdict "own-inbox and board macro-events are returned by --continue between calls, and a quiet pair times out"

## ---------------------------------------------------------------------------
## 10f. The internal poll: 19 seconds by default, MDAT_WAIT_POLL_SECONDS in tests,
##      --wait-poll-interval over both -- and the caller's timeout never lengthened.
## ---------------------------------------------------------------------------
rigNewStart poll
rigDropQ="$rigNewDir/dropQ.txt"
: > "$rigDropQ"
rigNewPoll=""
rigNewIn poll-default --wait-default --wait-source "file:$rigDropQ" --wait-timeout 2
rigAssert "without the env the poll is 19s"                    "$( rigHolds "$rigNewOut" 'poll round(s) at 19s' )" yes
rigAssert "the caller's bound still ends it, not the 19s"      "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
rigAssert "it is a TIMEOUT"                                    "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
rigNewPoll="1"
rigNewIn poll-env --wait-default --wait-source "file:$rigDropQ" --wait-timeout 2
rigAssert "control: with the env the poll is 1s"               "$( rigHolds "$rigNewOut" 'poll round(s) at 1s' )" yes
rigAssert "control: not 19s"                                   "$( rigHolds "$rigNewOut" 'at 19s' )" no
rigNewIn poll-flag --wait-default --wait-source "file:$rigDropQ" --wait-timeout 2 --wait-poll-interval 3
rigAssert "--wait-poll-interval wins over the env"             "$( rigHolds "$rigNewOut" 'poll round(s) at 3s' )" yes
rigDropAfter 1 "$rigDropQ" RIG-POLL-ARRIVAL
rigNewIn poll-arrival --wait-default --wait-source "file:$rigDropQ" --wait-timeout 30
rigDropDone
rigAssert "with the env an arrival is noticed at the next 1s poll" "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "it returned inside 10s of a 30s bound"              "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
rigVerdict "the poll defaults to 19s, MDAT_WAIT_POLL_SECONDS sets it for tests, --wait-poll-interval wins, the bound is never exceeded"

## ---------------------------------------------------------------------------
## 10g. The existing call shape, with no mode and no session id: unchanged -- a
##      wait, no state stored. The 125 assertions above are the full control.
## ---------------------------------------------------------------------------
rigNewStart stateless
rigDropR="$rigNewDir/dropR.txt"
: > "$rigDropR"
rigNew stateless --wait-source "file:$rigDropR" --wait-timeout 2 --wait-poll-interval 1
rigAssert "no mode: still a wait that times out"               "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
rigAssert "no mode: returns 0"                                 "$rigNewStatus" 0
rigAssert "no mode: no state directory was made"               "$( [ -d "$rigNewDir/ws/.local/agents/sessions" ] && printf present || printf absent )" absent
rigVerdict "a call with no mode and no session id is the stateless wait it always was"

## ---------------------------------------------------------------------------
## 10h. The id sets: seen, note, done and wait are reacted on their messages
##      BEFORE any read, through one emoji table; ids and floors; a refused
##      reaction is listed and never stops the wait; validation reacts to nothing.
## ---------------------------------------------------------------------------
rigNewStart react
rigReactSource="slack:$rigReactChannel:$rigReactThread:conversation"
rigReactPosts="$( rigOwnerPost 1700000001.000200 msg-200 "$rigReactThread" )$( rigOwnerPost 1700000001.000300 msg-300 "$rigReactThread" )$( rigOwnerPost 1700000001.000400 msg-400 "$rigReactThread" )$( rigOwnerPost 1700000001.000500 msg-500 "$rigReactThread" )"
rigNewReplies "$rigReactPosts"
rigReactArgs=()
for rigReactEntry in $rigReactTable ; do
	rigReactSet="${rigReactEntry%%:*}"
	rigReactRest="${rigReactEntry#*:}"
	rigReactTs="${rigReactRest#*:}"
	rigReactArgs=( "${rigReactArgs[@]+"${rigReactArgs[@]}"}" "--wait-react-$rigReactSet" "$rigReactChannel:$rigReactTs" )
done
rigNewIn react-all --wait-default --wait-source "$rigReactSource" --wait-since-utime 1700000001.000300 --wait-timeout 30 "${rigReactArgs[@]}"
rigAssert "the marker line opens stdout"                       "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "it returns 0"                                       "$rigNewStatus" 0
rigAssert "the mode line follows"                              "$( rigNth "$rigNewOut" 2 )" "WAIT-MODE: default"
rigAssert "the counts say one of each"                         "$( rigHolds "$rigNewOut" '# reactions: seen=1 note=1 done=1 wait=1 failed=' )" yes
for rigReactEntry in $rigReactTable ; do
	rigReactSet="${rigReactEntry%%:*}"
	rigReactRest="${rigReactEntry#*:}"
	rigReactEmoji="${rigReactRest%%:*}"
	rigReactTs="${rigReactRest#*:}"
	rigAssert "$rigReactSet is reacted as :$rigReactEmoji: on $rigReactTs" "$( rigReactCount "$rigReactTs $rigReactEmoji" )" 1
done
rigAssert "nothing else was reacted"                           "$( rigLines "$rigNewDir/reactions" )" 4
rigAssert "every reaction came before the first read"          "$( rigReactsFirst )" reactions-first
## New messages are strictly newer than the floor, so the floor's own message is not one.
rigAssert "the message at the floor is not returned"           "$( rigHolds "$rigNewOut" 'msg-300' )" no
rigAssert "an older message is not returned"                   "$( rigHolds "$rigNewOut" 'msg-200' )" no
rigAssert "a newer message is returned"                        "$( rigHolds "$rigNewOut" 'msg-400' )" yes
rigAssert "the newest message is returned"                     "$( rigHolds "$rigNewOut" 'msg-500' )" yes
rigAssert "the newest ts is named for the next floor"          "$( rigHolds "$rigNewOut" 'WAIT-LAST-TS: 1700000001.000500' )" yes
rigAssert "the filters line carries the floor"                 "$( rigHolds "$rigNewOut" '1700000001.000300' )" yes
## Control: the same thread from an earlier floor returns the messages the later one dropped.
rigNewIn react-early --wait-default --wait-source "$rigReactSource" --wait-since-utime 1700000001.000101 --wait-timeout 30
rigAssert "control: an earlier floor returns the older ones"   "$( rigHolds "$rigNewOut" 'msg-200' )" yes
rigAssert "control: and the one at the later floor"            "$( rigHolds "$rigNewOut" 'msg-300' )" yes
rigAssert "control: with no id sets no reaction was asked for" "$( rigLines "$rigNewDir/reactions" )" 4
rigAssert "control: and the counts say zero"                   "$( rigHolds "$rigNewOut" '# reactions: seen=0 note=0 done=0 wait=0 failed=' )" yes

## A refused reaction is listed and the wait carries on.
: > "$rigNewDir/react-refuse"
rigNewIn react-refused --wait-default --wait-source "$rigReactSource" --wait-since-utime 1700000001.000101 --wait-timeout 30 --wait-react-seen "$rigReactChannel:1700000001.000200"
rm -f "$rigNewDir/react-refuse"
rigAssert "a refused reaction does not stop the wait"          "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "it returns 0"                                       "$rigNewStatus" 0
rigAssert "the failed id is listed"                            "$( rigHolds "$rigNewOut" "failed=$rigReactChannel:1700000001.000200" )" yes
rigAssert "the new messages still came back"                   "$( rigHolds "$rigNewOut" 'msg-500' )" yes

## Validation comes first: one bad id reacts to nothing, not even the good ones.
rigReactsBefore="$( rigLines "$rigNewDir/reactions" )"
rigBadNo=0
for rigBadId in "$rigReactChannel:1700000001.000300;touch-x" "$rigReactChannel:1700000001.000300\$(id)" "$rigReactChannel:1700000001.000300\`id\`" ; do
	rigBadNo=$(( rigBadNo + 1 ))
	rigNewIn "react-bad-$rigBadNo" --wait-default --wait-source "$rigReactSource" --wait-since-utime 1700000001.000101 --wait-timeout 600 --wait-react-seen "$rigReactChannel:1700000001.000200" --wait-react-note "$rigBadId"
	rigAssert "[bad id $rigBadNo] ERROR opens stdout"          "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: ERROR"
	rigAssert "[bad id $rigBadNo] returns 1"                   "$rigNewStatus" 1
	rigAssert "[bad id $rigBadNo] refused at second zero"      "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
	rigAssert "[bad id $rigBadNo] nothing was waited on"       "$( rigHolds "$rigNewOut" '# waited:' )" no
	rigAssert "[bad id $rigBadNo] not even the good id was reacted" "$( rigLines "$rigNewDir/reactions" )" "$rigReactsBefore"
done
rigNewIn react-good-control --wait-default --wait-source "$rigReactSource" --wait-since-utime 1700000001.000101 --wait-timeout 30 --wait-react-seen "$rigReactChannel:1700000001.000200" --wait-react-note "$rigReactChannel:1700000001.000300"
rigAssert "control: the same call with clean ids runs"         "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "control: and reacts"                                "$( rigLines "$rigNewDir/reactions" )" "$(( rigReactsBefore + 2 ))"

## A bare ts is accepted on exactly one Slack source -- and refused otherwise.
rigBareBefore="$( rigLines "$rigNewDir/reactions" )"
rigNewIn react-bare-one --wait-default --wait-source "$rigReactSource" --wait-since-utime 1700000001.000101 --wait-timeout 30 --wait-react-done 1700000001.000400
rigAssert "a bare ts on one Slack source runs"                 "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "and reacts on that source's conversation"           "$( rigLines "$rigNewDir/reactions" )" "$(( rigBareBefore + 1 ))"
rigNewIn react-bare-none --wait-default --wait-source "file:$rigDropR" --wait-timeout 600 --wait-react-done 1700000001.000400
rigAssert "a bare ts with no Slack source is ERROR"            "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: ERROR"
rigAssert "it returns 1"                                       "$rigNewStatus" 1
rigAssert "it reacted to nothing"                              "$( rigLines "$rigNewDir/reactions" )" "$(( rigBareBefore + 1 ))"

## Close and continue take id sets too, and close reacts before it removes state.
## The stored floor is the newest ts the last call returned (000500), so continue has
## nothing to return until a newer post exists; the post is added first.
rigNewReplies "$rigReactPosts$( rigOwnerPost 1700000001.000600 msg-600 "$rigReactThread" )"
rigNewIn react-continue --wait-continue --wait-timeout 30 --wait-react-wait "$rigReactChannel:1700000001.000500"
rigAssert "continue allows id sets"                            "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "and reacted"                                        "$( rigHolds "$rigNewOut" '# reactions: seen=0 note=0 done=0 wait=1 failed=' )" yes
rigAssert "it returns what is newer than the stored floor"     "$( rigHolds "$rigNewOut" 'msg-600' )" yes
rigAssert "and not what the last call already returned"        "$( rigHolds "$rigNewOut" 'msg-500' )" no
rigNewIn react-continue-quiet --wait-continue --wait-timeout 2
rigAssert "control: with nothing newer than the new floor, TIMEOUT" "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
rigCloseBefore="$( rigLines "$rigNewDir/reactions" )"
rigNewIn react-close --wait-close --wait-react-done "$rigReactChannel:1700000001.000400"
rigAssert "close with an id set: CLOSED"                       "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: CLOSED"
rigAssert "it reacted first"                                   "$( rigLines "$rigNewDir/reactions" )" "$(( rigCloseBefore + 1 ))"
rigAssert "then removed the state"                             "$( rigNewState "$rigNewSession" )" absent
rigVerdict "seen, note, done and wait are reacted before any read through one emoji table; ids are strictly after the floor; a refused reaction never stops the wait; a bad id reacts to nothing"

## ---------------------------------------------------------------------------
## 10i. One round returns EVERY source that differs, one block each, and one
##      WAIT-LAST-TS per hit source. Two :conversation sources hit together; the
##      control is one source, which prints as it always did.
## ---------------------------------------------------------------------------
rigNewStart multi
rigThreadA="1700000001.000101"
rigThreadB="1700000002.000101"
rigNewReplies "$( rigOwnerPost 1700000001.000300 msg-a "$rigThreadA" )" "$rigThreadA"
rigNewReplies "$( rigOwnerPost 1700000002.000200 msg-b "$rigThreadB" )" "$rigThreadB"
rigNewIn multi-two --wait-default --wait-source "slack:$rigReactChannel:$rigThreadA:conversation" --wait-source "slack:$rigReactChannel:$rigThreadB:conversation" --wait-since-utime 1700000001.000050 --wait-timeout 30
rigAssert "two hits: RECEIVED"                                 "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "two hits: returns 0"                                "$rigNewStatus" 0
rigAssert "two hits: one arrived-on block each"                "$( rigOpens "$rigNewOut" '# arrived on: ' )" 2
rigAssert "two hits: the first source is named"                "$( rigHolds "$rigNewOut" "# arrived on: slack:$rigReactChannel:$rigThreadA:conversation" )" yes
rigAssert "two hits: the second source is named"               "$( rigHolds "$rigNewOut" "# arrived on: slack:$rigReactChannel:$rigThreadB:conversation" )" yes
rigAssert "two hits: both messages are carried"                "$( rigHolds "$rigNewOut" 'msg-a' )$( rigHolds "$rigNewOut" 'msg-b' )" yesyes
rigAssert "two hits: one WAIT-LAST-TS per hit source"          "$( rigOpens "$rigNewOut" 'WAIT-LAST-TS: ' )" 2
rigAssert "two hits: the first names its source and ts"        "$( rigHolds "$rigNewOut" "WAIT-LAST-TS: slack:$rigReactChannel:$rigThreadA:conversation 1700000001.000300" )" yes
rigAssert "two hits: the second names its source and ts"       "$( rigHolds "$rigNewOut" "WAIT-LAST-TS: slack:$rigReactChannel:$rigThreadB:conversation 1700000002.000200" )" yes
rigNewIn multi-one --wait-default --wait-source "slack:$rigReactChannel:$rigThreadA:conversation" --wait-since-utime 1700000001.000050 --wait-timeout 30
rigAssert "control: one hit is one block"                      "$( rigOpens "$rigNewOut" '# arrived on: ' )" 1
rigAssert "control: one hit prints WAIT-LAST-TS as it always did" "$( rigOpens "$rigNewOut" 'WAIT-LAST-TS: 1700000001.000300' )" 1
rigVerdict "one round returns every source that differs, one block and one WAIT-LAST-TS each -- one hit prints as before"

## ---------------------------------------------------------------------------
## 10k. Many threads in one wait: two plain threads sharing the one --wait-since-utime
##      and --wait-addressee, and a plain thread beside a :conversation source. The
##      thread floor S is our own post in thread A (its parent) and a reply of ours in
##      thread B, so each rendering carries the message the floor names. Controls: a
##      thread with only a non-addressee post is not a hit, a quiet thread is not
##      named, and the two refusals that must stay (a lone :conversation with an
##      addressee, a plain thread with none).
## ---------------------------------------------------------------------------
rigNewStart threads
rigThreadFloor="1700000001.000101"
rigThreadPlainA="1700000001.000101"
rigThreadPlainB="1700000000.000050"
rigThreadConv="1700000003.000101"
rigThreadBody(){ ## the thread's first message, then the later messages
	printf '{"ok":true,"messages":[%s%s],"has_more":false}\n' "$1" "$2"
}
rigThreadPost(){ ## ts, user, text, thread ts -- with a leading comma
	printf ',{"ts":"%s","user":"%s","text":"%s","thread_ts":"%s"}' "$1" "$2" "$3" "$4"
}
rigThreadAFile="$rigNewDir/replies.$rigThreadPlainA.json"
rigThreadBFile="$rigNewDir/replies.$rigThreadPlainB.json"
rigThreadCFile="$rigNewDir/replies.$rigThreadConv.json"
rigThreadOpen(){ ## ts, user, text
	printf '{"ts":"%s","user":"%s","text":"%s"}' "$1" "$2" "$3"
}
rigThreadBody "$( rigThreadOpen "$rigThreadPlainA" URIGSELF1 opener-a )" "$( rigThreadPost 1700000001.000300 URIGOWNER answer-a "$rigThreadPlainA" )" > "$rigThreadAFile"
rigThreadBody "$( rigThreadOpen "$rigThreadPlainB" URIGOWNER opener-b )" "$( rigThreadPost "$rigThreadFloor" URIGSELF1 ours-b "$rigThreadPlainB" )$( rigThreadPost 1700000001.000400 URIGOWNER answer-b "$rigThreadPlainB" )" > "$rigThreadBFile"
rigThreadBody "$( rigThreadOpen "$rigThreadConv" URIGSELF1 opener-c )" "$( rigThreadPost 1700000003.000200 URIGOWNER post-c "$rigThreadConv" )" > "$rigThreadCFile"
rigPlainA="slack:$rigReactChannel:$rigThreadPlainA"
rigPlainB="slack:$rigReactChannel:$rigThreadPlainB"
rigConvC="slack:$rigReactChannel:$rigThreadConv:conversation"

rigNewIn threads-two-plain --wait-default --wait-source "$rigPlainA" --wait-source "$rigPlainB" --wait-since-utime "$rigThreadFloor" --wait-addressee URIGOWNER --wait-timeout 30
rigAssert "two plain threads: RECEIVED"                        "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "two plain threads: returns 0"                       "$rigNewStatus" 0
rigAssert "two plain threads: not refused as a second thread"  "$( rigHolds "$rigNewErr" 'ONLY source' )" no
rigAssert "two plain threads: one arrived-on block each"       "$( rigOpens "$rigNewOut" '# arrived on: ' )" 2
rigAssert "two plain threads: thread A is named"               "$( rigHolds "$rigNewOut" "# arrived on: $rigPlainA" )" yes
rigAssert "two plain threads: thread B is named"               "$( rigHolds "$rigNewOut" "# arrived on: $rigPlainB" )" yes
rigAssert "two plain threads: both answers are carried"        "$( rigHolds "$rigNewOut" 'answer-a' )$( rigHolds "$rigNewOut" 'answer-b' )" yesyes
rigAssert "two plain threads: our own post is not carried"     "$( rigHolds "$rigNewOut" 'ours-b' )" no
rigAssert "two plain threads: one WAIT-LAST-TS per thread"     "$( rigOpens "$rigNewOut" 'WAIT-LAST-TS: ' )" 2
rigAssert "two plain threads: the addressee is counted"        "$( rigHolds "$rigNewOut" '# answers counted only from: URIGOWNER' )" yes

## Control: thread B holding only a non-addressee post is not a hit, and is not named.
rigThreadBody "$( rigThreadOpen "$rigThreadPlainB" URIGOWNER opener-b )" "$( rigThreadPost "$rigThreadFloor" URIGSELF1 ours-b "$rigThreadPlainB" )$( rigThreadPost 1700000001.000400 URIGSTRANGER chatter-b "$rigThreadPlainB" )" > "$rigThreadBFile"
rigNewIn threads-two-plain-b-quiet --wait-default --wait-source "$rigPlainA" --wait-source "$rigPlainB" --wait-since-utime "$rigThreadFloor" --wait-addressee URIGOWNER --wait-timeout 30
rigAssert "control: thread A alone arrives"                    "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "control: one block only"                            "$( rigOpens "$rigNewOut" '# arrived on: ' )" 1
rigAssert "control: thread A is the one named"                 "$( rigHolds "$rigNewOut" "# arrived on: $rigPlainA" )" yes
rigAssert "control: thread B is not named as arrived"          "$( rigHolds "$rigNewOut" "# arrived on: $rigPlainB" )" no
rigAssert "control: the non-addressee post is not carried"     "$( rigHolds "$rigNewOut" 'chatter-b' )" no

## A plain thread (with its addressee) beside a :conversation thread.
rigNewIn threads-mixed --wait-default --wait-source "$rigPlainA" --wait-source "$rigConvC" --wait-since-utime "$rigThreadFloor" --wait-addressee URIGOWNER --wait-timeout 30
rigAssert "plain beside conversation: RECEIVED"                "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "plain beside conversation: returns 0"               "$rigNewStatus" 0
rigAssert "plain beside conversation: the addressee is allowed" "$( rigHolds "$rigNewErr" 'takes no --wait-addressee' )" no
rigAssert "plain beside conversation: one block each"          "$( rigOpens "$rigNewOut" '# arrived on: ' )" 2
rigAssert "plain beside conversation: the plain thread is named" "$( rigHolds "$rigNewOut" "# arrived on: $rigPlainA" )" yes
rigAssert "plain beside conversation: the conversation is named" "$( rigHolds "$rigNewOut" "# arrived on: $rigConvC" )" yes
rigAssert "plain beside conversation: both posts are carried"  "$( rigHolds "$rigNewOut" 'answer-a' )$( rigHolds "$rigNewOut" 'post-c' )" yesyes

## The refusals that stay: a lone :conversation with an addressee, and a plain thread without one.
rigNewIn threads-conv-addressee --wait-default --wait-source "$rigConvC" --wait-since-utime "$rigThreadFloor" --wait-addressee URIGOWNER --wait-timeout 600
rigAssert "control: a lone :conversation with an addressee is still ERROR" "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: ERROR"
rigAssert "control: it says why"                               "$( rigHolds "$rigNewErr" 'takes no --wait-addressee' )" yes
rigAssert "control: refused at second zero"                    "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
rigNewIn threads-plain-no-addressee --wait-default --wait-source "$rigPlainA" --wait-source "$rigConvC" --wait-since-utime "$rigThreadFloor" --wait-timeout 600
rigAssert "control: a plain thread with no addressee is still ERROR" "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: ERROR"
rigAssert "control: it asks for the addressee"                 "$( rigHolds "$rigNewErr" '--wait-addressee' )" yes
rigAssert "control: refused at second zero"                    "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
rigVerdict "many threads in one wait -- two plain threads, a plain thread beside a :conversation, and the refusals that stay"

## ---------------------------------------------------------------------------
## 10l. Iteration dividers: $agentsWaitKindEvery makes a kind probed on round 1 and then
##      on every Nth round. The variable is a plain assignment in the include, so these
##      rows run the real operation from a scratch origin whose one include differs
##      by that line, and count the probes on the fake Slack's log against the rounds the
##      operation itself reports. The control is "slack:1", which probes every round.
## ---------------------------------------------------------------------------
rigMakeOrigin(){ ## directory, kind-every value
	local originDir="$1" originEvery="$2" originEntry originName originInclude="myx/myx.distro-agents/sh-lib/AgentsTools.MemberWait.include"
	grep -q '^agentsWaitKindEvery="' "$MDLT_ORIGIN/$originInclude" || rigRefuse "the include no longer assigns agentsWaitKindEvery on a line of its own, so the divider rows would test nothing"
	mkdir -p "$originDir/myx/myx.distro-agents/sh-lib"
	for originEntry in "$MDLT_ORIGIN"/* ; do
		originName="${originEntry##*/}"
		[ "$originName" = "myx" ] || ln -s "$originEntry" "$originDir/$originName"
	done
	for originEntry in "$MDLT_ORIGIN/myx"/* ; do
		originName="${originEntry##*/}"
		[ "$originName" = "myx.distro-agents" ] || ln -s "$originEntry" "$originDir/myx/$originName"
	done
	for originEntry in "$MDLT_ORIGIN/myx/myx.distro-agents"/* ; do
		originName="${originEntry##*/}"
		[ "$originName" = "sh-lib" ] || ln -s "$originEntry" "$originDir/myx/myx.distro-agents/$originName"
	done
	for originEntry in "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"/* ; do
		originName="${originEntry##*/}"
		[ "$originName" = "AgentsTools.MemberWait.include" ] || ln -s "$originEntry" "$originDir/myx/myx.distro-agents/sh-lib/$originName"
	done
	LC_ALL=C sed "s/^agentsWaitKindEvery=\".*\"/agentsWaitKindEvery=\"$originEvery\"/" "$MDLT_ORIGIN/$originInclude" > "$originDir/$originInclude"
	[ "$( rigHolds "$originDir/$originInclude" "agentsWaitKindEvery=\"$originEvery\"" )" = yes ] || rigRefuse "the scratch include does not carry the divider $originEvery, so the divider rows would test nothing"
}
rigRoundsOf(){ ## stdout file -- the poll rounds the operation reports
	LC_ALL=C awk '/^# waited: / { roundText = $0 ; sub(/.*bound, /, "", roundText) ; sub(/ poll round.*/, "", roundText) ; } END { if ( roundText == "" ) { roundText = "no-rounds-line" ; } print roundText ; }' "$1" 2>/dev/null || printf 'no-such-output'
}
rigSlackReads(){ ## the fake Slack's own count of thread reads in this scenario
	LC_ALL=C awk '$0 == "conversations.replies" { hitCount++ ; } END { print hitCount + 0 ; }' "$rigNewDir/curl.log" 2>/dev/null || printf 'no-such-log'
}
rigNewStart divider
rigDivThread="slack:$rigReactChannel:$rigReactThread:conversation"
rigNewReplies ""
rigMakeOrigin "$rigNewDir/origin-slack3" "slack:3 file:1 inbox:1 board:1"
rigNewOrigin="$rigNewDir/origin-slack3"
: > "$rigNewDir/curl.log"
rigNewIn divider-three --wait-default --wait-source "$rigDivThread" --wait-since-utime "$rigReactThread" --wait-timeout 7 --wait-poll-interval 1
rigDivRounds="$( rigRoundsOf "$rigNewOut" )"
rigDivReads="$( rigSlackReads )"
rigAssert "every 3rd: a quiet thread is a TIMEOUT"             "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
rigAssert "every 3rd: enough rounds ran for a divider to show" "$( rigAtLeast "$rigDivRounds" 5 )" "at-least-5"
rigAssert "every 3rd: reads are round 1 and every 3rd round after" "$rigDivReads" "$(( ( rigDivRounds - 1 ) / 3 + 1 ))"
rigAssert "every 3rd: fewer reads than rounds"                 "$( rigWithin "$rigDivReads" "$(( rigDivRounds - 1 ))" )" "within-$(( rigDivRounds - 1 ))"
rigNewOrigin=""
: > "$rigNewDir/curl.log"
rigNewIn divider-one --wait-default --wait-source "$rigDivThread" --wait-since-utime "$rigReactThread" --wait-timeout 7 --wait-poll-interval 1
rigDivRounds="$( rigRoundsOf "$rigNewOut" )"
rigAssert "control, every 1: a quiet thread is a TIMEOUT"      "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: TIMEOUT"
rigAssert "control, every 1: the thread is read on every round" "$( rigSlackReads )" "$rigDivRounds"
rigAssert "control, every 1: enough rounds ran"                "$( rigAtLeast "$rigDivRounds" 5 )" "at-least-5"

## A divider is per kind: a file source still notices its arrival on the next round while the
## Slack thread beside it is left alone until its own turn.
rigMakeOrigin "$rigNewDir/origin-slack5" "slack:5 file:1 inbox:1 board:1"
rigNewOrigin="$rigNewDir/origin-slack5"
rigDropDv="$rigNewDir/dropDv.txt"
: > "$rigDropDv"
: > "$rigNewDir/curl.log"
rigDropAfter 1 "$rigDropDv" RIG-DIVIDER-ARRIVAL
rigNewIn divider-mixed --wait-default --wait-source "$rigDivThread" --wait-source "file:$rigDropDv" --wait-since-utime "$rigReactThread" --wait-timeout 30 --wait-poll-interval 1
rigDropDone
rigAssert "mixed, slack every 5th: the file arrival is returned"  "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "mixed: it names the file source"                    "$( rigHolds "$rigNewOut" "# arrived on: file:$rigDropDv" )" yes
rigAssert "mixed: it returned within a few polls"              "$( rigWithin "$rigNewElapsed" 10 )" "within-10"
rigAssert "mixed: more than one round ran"                     "$( rigAtLeast "$( rigRoundsOf "$rigNewOut" )" 2 )" "at-least-2"
rigAssert "mixed: the thread was read once, on round 1 only"   "$( rigSlackReads )" 1
rigNewOrigin=""
rigDropDw="$rigNewDir/dropDw.txt"
: > "$rigDropDw"
: > "$rigNewDir/curl.log"
rigDropAfter 1 "$rigDropDw" RIG-DIVIDER-ARRIVAL
rigNewIn divider-mixed-control --wait-default --wait-source "$rigDivThread" --wait-source "file:$rigDropDw" --wait-since-utime "$rigReactThread" --wait-timeout 30 --wait-poll-interval 1
rigDropDone
rigAssert "control, every 1: the file arrival is returned"     "$( rigNth "$rigNewOut" 1 )" "WAIT-RESULT: RECEIVED"
rigAssert "control, every 1: the thread is read on every round it ran" "$( rigSlackReads )" "$( rigRoundsOf "$rigNewOut" )"
rigAssert "control, every 1: more than one round ran"          "$( rigAtLeast "$( rigRoundsOf "$rigNewOut" )" 2 )" "at-least-2"
rigVerdict "iteration dividers -- a kind with N is read on round 1 and every Nth round, per kind, and N of 1 reads every round"

## ---------------------------------------------------------------------------
## 10j. The Wait tool through the real harness: the declaration carries the mode and
##      the four id sets and no longer a poll interval; an omitted mode is default;
##      mode close is CLOSED; and the state lands in the session store.
## ---------------------------------------------------------------------------
rigWaitModeStream(){ ## canned-stream file, sources value, timeout value, mode value
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-wait-call","type":"function","function":{"name":"Wait","arguments":"{\\"sources\\":\\"%s\\",\\"timeout\\":\\"%s\\",\\"mode\\":\\"%s\\"}"}}]}}]}\n' "$2" "$3" "$4" > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' >> "$1"
	printf 'data: [DONE]\n' >> "$1"
}
rigStart tool-mode-default
rigDropT="$rigScenarioDir/dropT.txt"
: > "$rigDropT"
rigWaitModeStream "$rigScenarioDir/res.1" "file:$rigDropT" 2 default
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun --agent "$rigMember"
rigToolResult "$rigScenarioDir/req.2" "$rigScenarioDir/result"
rigAssert "the run ends normally"                              "$rigRunStatus" 0
rigAssert "two rounds were requested"                          "$rigRoundCount" 2
## Only the Wait declaration is searched: AskUserQuestion declares a `wait` of its
## own, so a probe over the whole body would hold for that one whatever Wait declared.
LC_ALL=C awk 'BEGIN { RS = "\001" ; }
	{
		declText = $0
		declAt = index(declText, "\"name\":\"Wait\"")
		if ( declAt == 0 ) { print "no-wait-declaration" ; exit ; }
		declText = substr(declText, declAt)
		nextAt = index(substr(declText, 20), "{\"type\":\"function\"")
		if ( nextAt > 0 ) { declText = substr(declText, 1, nextAt + 18) ; }
		print declText
	}' "$rigScenarioDir/req.1" > "$rigScenarioDir/wait-declaration"
rigAssert "the Wait declaration was found in the request"      "$( rigHolds "$rigScenarioDir/wait-declaration" 'no-wait-declaration' )" no
rigAssert "the declaration carries mode"                       "$( rigHolds "$rigScenarioDir/wait-declaration" '"mode":{' )" yes
rigAssert "the declaration carries seen"                       "$( rigHolds "$rigScenarioDir/wait-declaration" '"seen":{' )" yes
rigAssert "the declaration carries note"                       "$( rigHolds "$rigScenarioDir/wait-declaration" '"note":{' )" yes
rigAssert "the declaration carries done"                       "$( rigHolds "$rigScenarioDir/wait-declaration" '"done":{' )" yes
rigAssert "the declaration carries wait"                       "$( rigHolds "$rigScenarioDir/wait-declaration" '"wait":{' )" yes
rigAssert "poll_interval left the declaration"                 "$( rigHolds "$rigScenarioDir/wait-declaration" 'poll_interval' )" no
rigAssert "control: the declaration slice is the Wait one"     "$( rigHolds "$rigScenarioDir/wait-declaration" '"since_utime":{' )" yes
rigAssert "control: and stops before the next tool"            "$( rigHolds "$rigScenarioDir/wait-declaration" '"name":"AskUserQuestion"' )" no
rigAssert "the model is shown TIMEOUT as its opening"          "$( rigPrefix "$rigScenarioDir/result" 'WAIT-RESULT: TIMEOUT' )" yes
rigAssert "it is shown the mode that ran"                      "$( rigHolds "$rigScenarioDir/result" 'WAIT-MODE: default' )" yes
rigAssert "the session state landed in the session store"      "$( ls "$rigScenarioDir"/.local/agents/sessions/*/wait/state 2>/dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" 1
rigAssert "the round carried on to an answer"                  "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "the Wait tool declares mode and the id sets, and an explicit default stores its state"

rigStart tool-mode-omitted
rigDropU="$rigScenarioDir/dropU.txt"
: > "$rigDropU"
rigWaitStream "$rigScenarioDir/res.1" "file:$rigDropU" 2
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun --agent "$rigMember"
rigToolResult "$rigScenarioDir/req.2" "$rigScenarioDir/result"
rigAssert "an omitted mode is a wait that times out"           "$( rigPrefix "$rigScenarioDir/result" 'WAIT-RESULT: TIMEOUT' )" yes
rigAssert "an omitted mode is the default mode"                "$( rigHolds "$rigScenarioDir/result" 'WAIT-MODE: default' )" yes
rigAssert "and stored its state"                               "$( ls "$rigScenarioDir"/.local/agents/sessions/*/wait/state 2>/dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" 1
rigVerdict "the Wait tool with no mode -- the existing call shape -- is the default mode"

rigStart tool-mode-close
rigDropV="$rigScenarioDir/dropV.txt"
: > "$rigDropV"
## 20s, not a long bound: a build that ignored the mode would wait it out, and the
## `# waited:` assertion below is what tells that from a CLOSED.
rigWaitModeStream "$rigScenarioDir/res.1" "file:$rigDropV" 20 close
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER
rigRun --agent "$rigMember"
rigToolResult "$rigScenarioDir/req.2" "$rigScenarioDir/result"
rigAssert "mode close through the tool: CLOSED opens the result" "$( rigPrefix "$rigScenarioDir/result" 'WAIT-RESULT: CLOSED' )" yes
rigAssert "it is not a wait that ran the 600s bound"           "$( rigHolds "$rigScenarioDir/result" '# waited:' )" no
rigAssert "no state is left in the session store"              "$( ls "$rigScenarioDir"/.local/agents/sessions/*/wait/state 2>/dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" 0
rigVerdict "the Wait tool with mode close returns CLOSED at once and leaves no state"

## ---------------------------------------------------------------------------
## The new rows made no request but Slack-shaped ones, on logs of their own.
## ---------------------------------------------------------------------------
rigSlackLogs="$( cat "$rigTmp"/new-*/curl.log 2>/dev/null )"
rigAssert "no new row issued a request that was not a Slack method" "$( printf '%s\n' "$rigSlackLogs" | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )" 0
rigAssert "and the new rows did issue some, so the logs are live" "$( printf '%s\n' "$rigSlackLogs" | LC_ALL=C awk 'NF { n++ ; } END { print ( n >= 6 ) ? "live" : "silent" ; }' )" live
rigVerdict "the session Wait rows stayed offline -- every request is on a log, and each was a Slack-shaped one"

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
