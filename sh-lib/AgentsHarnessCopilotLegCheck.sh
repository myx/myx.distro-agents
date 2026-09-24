#!/usr/bin/env bash
## Behavioural check on the COPILOT LEG -- the leaf's own declarations reaching the wire,
## and the core behaving under them. A value a vendor may rename is read from the leaf at
## run time; the endpoint, the host and the credential name are pinned here, a wrong one
## being the defect rather than a rename. Unlike the instruments beside it the leaf
## exports the REAL endpoint, so the fake `curl` first on PATH is the only thing between
## this check and it: it is re-checked before every scenario, refuses to run outside one,
## and COPILOT_GITHUB_TOKEN is forced to a literal so a machine holding a real token
## never has it enter the process. A rig that cannot reach its subject refuses instead.
set -u
rigHere="$( cd "$( dirname -- "$0" )" && pwd )"
rigLeaf="$rigHere/AgentsCopilotHarness.sh"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigLeaf" ] || rigRefuse "the Copilot leaf is not beside this check: $rigLeaf"

rigTmp="$( mktemp -d -t "AgentsHarnessCopilotLegCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
## The fake binaries this rig puts on PATH are REAL FILES under sh-lib/check-fixtures
## and are copied, never carried here in a heredoc: a delimiter lost inside a body
## that is itself shell takes the rest of this check with it, and a check that stops
## checking still prints its PASS lines. A missing fixture refuses instead.
rigFixtures="$rigHere/check-fixtures"
rigInstallFixture(){
	cp "$rigFixtures/$1" "$2" || rigRefuse "a fixture is missing from the package: $rigFixtures/$1"
	chmod +x "$2"
}
rigInstallFixture harness-copilot-leg-check.curl.sh "$rigTmp/bin/curl"

## Denies exactly when the payload carries the rig's argument marker. Silence and exit 0
## is the allow every hook in this estate uses. Shared with AgentsHarnessMcpCheck.sh,
## which asserts the same thing about the same marker -- one fixture, because the two
## bodies were byte-identical copies.
rigInstallFixture pre-tool-use-deny-on-marker.sh "$rigTmp/bin/rigdeny"

PATH="$rigTmp/bin:$PATH"
export PATH
RIG_DECL_DIR="$rigTmp"
export RIG_DECL_DIR

rigOnPath(){
	[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue a real request against the leaf's own live endpoint"
}
rigOnPath

## The leaf reads this name at load into HARNESS_TOKEN_LIGHT and HARNESS_TOKEN_MAIN and
## exports them, so on a machine where the real token is in the environment a rig that
## omitted this would write a live credential into its own request log.
export COPILOT_GITHUB_TOKEN="rig-not-a-credential"

## What the leaf declared, read back from what the fake curl inherited -- never typed in,
## because both model ids are anchored by elimination and the provider name is a label
## this package chooses, so a rename of any of the three must not read as a defect.
## Scope is the whole run, not one scenario: this returns whatever the LAST curl wrote,
## which is why the credential-gate scenario -- where no curl runs at all -- still has a
## value to read. Correct while one leaf drives every scenario, and no longer correct the
## day a second one does.
rigDecl(){ ## declaration name
	[ -s "$rigTmp/decl.$1" ] || rigRefuse "no request in this run recorded the leaf's own $1, so there is nothing to assert against"
	cat "$rigTmp/decl.$1"
}

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigOnPath
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir"
	printf '0' > "$rigScenarioDir/round"
}

## A round answering with plain text and no tool call.
rigTextStream(){ ## canned-stream file, content, this round's total_tokens
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":%s}}\n' "$2" "$3" > "$1"
	printf 'data: [DONE]\n' >> "$1"
}

## A round answering with one Read tool call, then the usage chunk the threshold reads.
rigReadStream(){ ## canned-stream file, path to read, this round's total_tokens
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call","type":"function","function":{"name":"Read","arguments":"{\\"path\\":\\"%s\\"}"}}]}}]}\n' "$2" > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":%s}}\n' "$3" >> "$1"
	printf 'data: [DONE]\n' >> "$1"
}

## A round answering with one Write tool call.
rigWriteStream(){ ## canned-stream file, path to write, content
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call","type":"function","function":{"name":"Write","arguments":"{\\"path\\":\\"%s\\",\\"content\\":\\"%s\\"}"}}]}}]}\n' "$2" "$3" > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' >> "$1"
	printf 'data: [DONE]\n' >> "$1"
}

rigRunStatus=0
rigRoundCount=0
rigRun(){ ## the leaf arguments this scenario adds
	rigRunStatus=0
	## MMDAPP points at the scenario, so the core's own PreToolUse hooks read this
	## scenario's own settings file and no file of the real workspace. Nothing sets an
	## MDAT_HARNESS_* value: what the core defaults to under this leaf is the subject.
	RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" \
		"$rigLeaf" "$@" RIG-TASK-MARKER \
		> "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || rigRunStatus=$?
	rigRoundCount="$( cat "$rigScenarioDir/round" )"
	## A real curl having run instead of the fake leaves this counter at 0.
	[ "$rigRoundCount" != 0 ] || rigRefuse "the harness issued no request at all, so this scenario exercised nothing"
}

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

## yes/no rather than a status, so both directions are values a failure can print.
## A request that was never made gets its own third value: it is not the same finding
## as one made without the text, and a bare `no` would read as though it were.
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}

## Asserted against the filesystem, never against the message: a harness that printed a
## refusal and wrote anyway satisfies every probe that only reads the refusal.
rigExists(){ ## path
	if [ -e "$1" ] ; then printf 'yes' ; else printf 'no' ; fi
}

## Whole lines, so a second header riding the same stdin channel is visible as a count.
rigLineCount(){ ## file
	LC_ALL=C awk 'END { print NR + 0 ; }' "$1" 2>/dev/null || printf 'no-such-file'
}

rigAtLeast(){ ## value, floor
	case "$1" in
		''|*[!0-9]*) printf 'not-a-number-%s' "$1" ; return 0 ;;
	esac
	[ "$1" -ge "$2" ] || { printf 'under-%s' "$2" ; return 0 ; }
	printf 'at-least-%s' "$2"
}

## Every destination any request in this whole run went to, distinct, one per line.
rigDestinations(){
	LC_ALL=C awk '
		index($0, "https://") == 1 || index($0, "http://") == 1 { seenUrl[$0] = 1 ; }
		END { for ( oneUrl in seenUrl ) print oneUrl ; }
	' "$rigTmp"/*/argv.* 2>/dev/null
}

rigRequestCount(){
	set -- "$rigTmp"/*/argv.*
	printf '%s' "$#"
}

## The token guard checked rather than asserted: if a real credential ever leaked into a
## request, this is what catches it.
rigForeignBearers(){
	local sweepFile sweepBad=0
	for sweepFile in "$rigTmp"/*/stdin.* ; do
		[ ! -f "$sweepFile" ] || [ "$( cat "$sweepFile" )" = "Authorization: Bearer rig-not-a-credential" ] || sweepBad=$(( sweepBad + 1 ))
	done
	printf '%s' "$sweepBad"
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

## ---------------------------------------------------------------------------
## A. The leaf's own declarations reach the wire, and its credential gate is live.
## ---------------------------------------------------------------------------
rigStart a-declarations
rigTextStream "$rigScenarioDir/res.1" RIG-FINAL-MARKER 20
rigRun --access-write-root "$rigScenarioDir"
rigAssert "the leg completed"                          "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigAssert "the run ends normally"                      "$rigRunStatus" 0
rigAssert "exactly one round was requested"            "$rigRoundCount" 1
## Pinned, not read: an endpoint is not a thing a vendor renames under you, and a
## mistyped one is itself the defect -- AgentsAnthropicStub.sh's own GAP-1 names exactly
## that as the reason a whole leg 404s. The provider name below stays read, being a label
## this package chose and may reword without anything breaking.
rigAssert "the request went to the pinned endpoint"    "$( rigHolds "$rigScenarioDir/argv.1" 'https://api.githubcopilot.com/chat/completions' )" yes
rigAssert "the diagnostics name the leaf's provider"   "$( rigHolds "$rigScenarioDir/err" "$( rigDecl provider )" )" yes
rigAssert "THE MODEL IS TOLD THE LEAF'S PROVIDER"      "$( rigHolds "$rigScenarioDir/req.1" "bespoke $( rigDecl provider ) harness" )" yes
rigAssert "the normal tier carries the main model"     "$( rigHolds "$rigScenarioDir/req.1" "\"model\":\"$( rigDecl modelMain )\"" )" yes
rigAssert "the bearer is on stdin, and is all of it"   "$( cat "$rigScenarioDir/stdin.1" )" "Authorization: Bearer rig-not-a-credential"
rigAssert "stdin carries one header and no extra"      "$( rigLineCount "$rigScenarioDir/stdin.1" )" 1
rigAssert "the bearer is nowhere in argv"              "$( rigHolds "$rigScenarioDir/argv.1" 'rig-not-a-credential' )" no
## A standing guard, not a result: the text it looks for is printed only on a path that
## needs an exchange declared, and nothing in this package declares one -- declaring one
## makes the core refuse at startup on the missing adapter. It has no polarity until a
## leaf does declare one, and then it becomes a result. Said here so it is not read as
## one meanwhile.
rigAssert "GUARD, no exchange declared: none ran"      "$( rigHolds "$rigScenarioDir/err" 'bearer exchanged via' )" no

rigStart a-light-tier
rigTextStream "$rigScenarioDir/res.1" RIG-FINAL-MARKER 20
rigRun --tier light --access-write-root "$rigScenarioDir"
rigAssert "the light tier carries the light model"     "$( rigHolds "$rigScenarioDir/req.1" "\"model\":\"$( rigDecl modelLight )\"" )" yes
rigAssert "and the main model is nowhere in it"        "$( rigHolds "$rigScenarioDir/req.1" "$( rigDecl modelMain )" )" no

## The credential gate, with A's first run as its positive control: the same leaf with
## the name set reached the wire, and with it unset nothing is sent at all. The name is
## pinned on both sides -- unset here, exported above -- which is what ties what the leaf
## READS to what it DECLARES: a refusal naming a variable that setting would not help is
## a transcription defect, not a rename.
rigStart a-credential-gate
rigGateStatus=0
RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" \
	env -u COPILOT_GITHUB_TOKEN "$rigLeaf" --access-write-root "$rigScenarioDir" RIG-TASK-MARKER \
	> "$rigScenarioDir/out" 2> "$rigScenarioDir/err" || rigGateStatus=$?
rigAssert "no credential refuses the run"              "$rigGateStatus" 1
rigAssert "and nothing was sent at all"                "$( cat "$rigScenarioDir/round" )" 0
rigAssert "the refusal names the pinned credential"    "$( rigHolds "$rigScenarioDir/err" 'COPILOT_GITHUB_TOKEN' )" yes
rigVerdict "the leaf's own declarations reach the wire, and its credential gate is live"

## ---------------------------------------------------------------------------
## B. A tool dispatched, and round 2 carrying its result back under the same leaf.
## ---------------------------------------------------------------------------
rigStart b-tool-round
printf 'RIG-TOOLRESULT-MARKER\n' > "$rigScenarioDir/read.txt"
rigReadStream "$rigScenarioDir/res.1" "$rigScenarioDir/read.txt" 20
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
rigRun --access-write-root "$rigScenarioDir"
rigAssert "two rounds were requested"                  "$rigRoundCount" 2
rigAssert "the announce arm named the file it read"    "$( rigHolds "$rigScenarioDir/err" 'b-tool-round/read.txt' )" yes
rigAssert "round 2 carries the tool result"            "$( rigHolds "$rigScenarioDir/req.2" 'RIG-TOOLRESULT-MARKER' )" yes
rigAssert "round 2 still carries the leaf's model"     "$( rigHolds "$rigScenarioDir/req.2" "\"model\":\"$( rigDecl modelMain )\"" )" yes
## Against the literal, never against stdin.1: compared to each other, a bearer that
## vanished from both rounds reads as a bearer that stayed the same.
rigAssert "round 2 carries the same single bearer"     "$( cat "$rigScenarioDir/stdin.2" )" "Authorization: Bearer rig-not-a-credential"
rigAssert "the dispatch arm did not fall through"      "$( rigHolds "$rigScenarioDir/req.2" 'unknown tool' )" no
rigVerdict "a tool dispatched, and its result carried back under the leaf's own model"

## ---------------------------------------------------------------------------
## C. Containment, both polarities, and the write checked off the filesystem.
## ---------------------------------------------------------------------------
rigStart c-containment
mkdir -p "$rigScenarioDir/readable" "$rigScenarioDir/writable" "$rigScenarioDir/outside"
printf 'RIG-READABLE-MARKER\n' > "$rigScenarioDir/readable/in-read-root.txt"
printf 'RIG-SECRET-MARKER\n' > "$rigScenarioDir/outside/secret.txt"
rigReadStream "$rigScenarioDir/res.1" "$rigScenarioDir/outside/secret.txt" 20
rigReadStream "$rigScenarioDir/res.2" "$rigScenarioDir/readable/in-read-root.txt" 20
rigWriteStream "$rigScenarioDir/res.3" "$rigScenarioDir/readable/planted.txt" RIG-WRITTEN-MARKER
rigWriteStream "$rigScenarioDir/res.4" "$rigScenarioDir/writable/planted.txt" RIG-WRITTEN-MARKER
rigTextStream "$rigScenarioDir/res.5" RIG-FINAL-MARKER 20
rigRun --access-read-root "$rigScenarioDir/readable" --access-write-root "$rigScenarioDir/writable"
rigAssert "the out-of-root read is refused"            "$( rigHolds "$rigScenarioDir/req.2" 'ERROR: path not in the allowed access-root set' )" yes
rigAssert "AND THE REFUSAL RETURNED NO BYTES"          "$( rigHolds "$rigScenarioDir/req.2" 'RIG-SECRET-MARKER' )" no
rigAssert "the in-root read is allowed"                "$( rigHolds "$rigScenarioDir/req.3" 'RIG-READABLE-MARKER' )" yes
rigAssert "a write into the READ root is refused"      "$( rigHolds "$rigScenarioDir/req.4" 'ERROR: path not in the allowed write-root set' )" yes
rigAssert "AND NOTHING LANDED ON THE FILESYSTEM"       "$( rigExists "$rigScenarioDir/readable/planted.txt" )" no
rigAssert "the in-write-root write is allowed"         "$( rigHolds "$rigScenarioDir/req.5" 'OK: wrote' )" yes
rigAssert "and it really landed on the filesystem"     "$( rigExists "$rigScenarioDir/writable/planted.txt" )" yes
rigAssert "with the content the model asked for"       "$( cat "$rigScenarioDir/writable/planted.txt" 2>/dev/null )" RIG-WRITTEN-MARKER
rigAssert "the model was told the split exists"        "$( rigHolds "$rigScenarioDir/req.1" 'Writing is narrower than reading.' )" yes
rigVerdict "containment in both polarities, with the write checked off the filesystem"

## ---------------------------------------------------------------------------
## D. What a complete non-streaming error body costs, and what the refusal says. NOT the
##    classifier: with no exchange declared the core breaks out at :2014 before reaching
##    the auth-class arm at :2019, so nothing here classifies anything and a body with
##    nothing auth-like in it gives the identical result. The exchange path is not
##    exercised either -- this leaf declares none, no adapter exists, and a green run
##    must never read as evidence that path works.
## ---------------------------------------------------------------------------
rigStart d-error-body
## The flat shape this package's error READER parses. OpenAI's own nested shape reads to
## that reader as a success document, which loses the refusal diagnostic below -- see
## MAGIC.md. The raw-text arm at :2019 is unaffected, so the loss is the diagnostic.
printf '%s\n' '{"status":429,"error":"quota_exceeded","message":"Your plan has expired."}' > "$rigScenarioDir/res.1"
rigRun --access-write-root "$rigScenarioDir"
rigAssert "exactly one request was made"               "$rigRoundCount" 1
rigAssert "the run fails"                              "$rigRunStatus" 1
rigAssert "the refusal names the pinned host"          "$( rigHolds "$rigScenarioDir/err" 'api.githubcopilot.com refused the request' )" yes
rigAssert "and the code the endpoint returned"         "$( rigHolds "$rigScenarioDir/err" 'quota_exceeded' )" yes
## The same standing guard as in scenario A, on the retry side of the same absent path.
rigAssert "GUARD, no exchange declared: no re-exchange" "$( rigHolds "$rigScenarioDir/err" 're-exchanging' )" no
rigVerdict "a complete error body costs one request, and the refusal names the host and the code"

## ---------------------------------------------------------------------------
## E. A PreToolUse hook refusal reaching the model, and the same rounds without it.
## ---------------------------------------------------------------------------
rigStart e-hook-denies
mkdir -p "$rigScenarioDir/.claude"
printf '{"hooks":{"PreToolUse":[{"matcher":"*","hooks":[{"type":"command","command":"%s/bin/rigdeny"}]}]}}\n' "$rigTmp" > "$rigScenarioDir/.claude/settings.json"
rigWriteStream "$rigScenarioDir/res.1" "$rigScenarioDir/RIG-ARG-MARKER.txt" RIG-WRITTEN-MARKER
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
rigRun --access-write-root "$rigScenarioDir"
rigAssert "the hooks were loaded"                      "$( rigHolds "$rigScenarioDir/err" 'PreToolUse hooks from' )" yes
rigAssert "the hook's own reason is the result"        "$( rigHolds "$rigScenarioDir/req.2" 'RIG-HOOK-DENIED' )" yes
rigAssert "it is stated as a hook refusal"             "$( rigHolds "$rigScenarioDir/req.2" 'blocked by a PreToolUse hook' )" yes
rigAssert "AND THE TOOL NEVER RAN"                     "$( rigExists "$rigScenarioDir/RIG-ARG-MARKER.txt" )" no
rigAssert "the round carried on to an answer"          "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigAssert "the run ends normally"                      "$rigRunStatus" 0

## The negative control, and the reason a green run above cannot be a vacuous one: the
## same canned rounds with no settings file, where every probe answers the other way.
rigStart e-hook-absent
rigWriteStream "$rigScenarioDir/res.1" "$rigScenarioDir/RIG-ARG-MARKER.txt" RIG-WRITTEN-MARKER
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
rigRun --access-write-root "$rigScenarioDir"
rigAssert "control: no hooks were loaded"              "$( rigHolds "$rigScenarioDir/err" 'PreToolUse hooks from' )" no
rigAssert "control: no hook reason came back"          "$( rigHolds "$rigScenarioDir/req.2" 'RIG-HOOK-DENIED' )" no
rigAssert "control: nothing was stated as blocked"     "$( rigHolds "$rigScenarioDir/req.2" 'blocked by a PreToolUse hook' )" no
rigAssert "control: the tool ran and the file exists"  "$( rigExists "$rigScenarioDir/RIG-ARG-MARKER.txt" )" yes
rigVerdict "a PreToolUse hook denies a write -- and without it that same write lands"

## ---------------------------------------------------------------------------
## F. The absent context budget. This leaf sets no context-token value of its own, so
##    the core's own floor is what governs -- two legs either side of it. It says
##    nothing about whether that floor SUITS these models, which stays open.
## ---------------------------------------------------------------------------
rigStart f-under-floor
printf 'RIG-TOOLRESULT-MARKER\n' > "$rigScenarioDir/read.txt"
rigReadStream "$rigScenarioDir/res.1" "$rigScenarioDir/read.txt" 399999
rigTextStream "$rigScenarioDir/res.2" RIG-FINAL-MARKER 20
rigRun --access-write-root "$rigScenarioDir"
rigAssert "a round just under it does not trip"        "$( rigHolds "$rigScenarioDir/err" 'context threshold reached' )" no
rigAssert "so the leg ran straight to its answer"      "$rigRoundCount" 2

rigStart f-at-floor
printf 'RIG-TOOLRESULT-MARKER\n' > "$rigScenarioDir/read.txt"
rigReadStream "$rigScenarioDir/res.1" "$rigScenarioDir/read.txt" 400000
rigTextStream "$rigScenarioDir/res.2" RIG-SUMMARY-MARKER 20
rigTextStream "$rigScenarioDir/res.3" RIG-FINAL-MARKER 20
rigRun --access-write-root "$rigScenarioDir"
rigAssert "a round at it trips the threshold"          "$( rigHolds "$rigScenarioDir/err" 'context threshold reached' )" yes
rigAssert "and the leg restarted onto its summary"     "$( rigHolds "$rigScenarioDir/err" 'original task verbatim plus the summary above' )" yes
rigAssert "three rounds were requested"                "$rigRoundCount" 3
rigAssert "the fresh leg's own answer is the result"   "$( cat "$rigScenarioDir/out" )" RIG-FINAL-MARKER
rigVerdict "the core's own context floor governs a leaf that declares none"

## ---------------------------------------------------------------------------
## G. The offline claim, asserted rather than stated, and last so the whole run is in
##    the log. This is the assertion every scenario above rests on: an instrument that
##    quietly reached the live endpoint would still print its PASS lines.
## ---------------------------------------------------------------------------
rigAssert "every request went to ONE destination"      "$( rigDestinations | LC_ALL=C awk 'END { print NR + 0 ; }' )" 1
rigAssert "and that one is the pinned endpoint"        "$( rigDestinations )" 'https://api.githubcopilot.com/chat/completions'
rigAssert "the log is live rather than empty"          "$( rigAtLeast "$( rigRequestCount )" 19 )" at-least-19
rigAssert "NO REQUEST EVER CARRIED ANOTHER BEARER"     "$( rigForeignBearers )" 0
rigAssert "the fake curl is still first on PATH"       "$( command -v curl )" "$rigTmp/bin/curl"
rigVerdict "offline -- $( rigRequestCount ) requests recorded, every one to the pinned endpoint"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COPILOT LEG CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_COPILOT_LEG: OK (%d scenarios, %d assertions, offline)\n' "$rigScenarioCount" "$rigPassCount"
