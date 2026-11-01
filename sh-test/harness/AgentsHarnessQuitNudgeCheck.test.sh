#!/usr/bin/env bash
## Behavioural check on what a plain reply does while the caller's CheckList still holds pending items (S22 item 5): the run does not end
## there. The harness appends one instruction as the next message and goes on, and a counter beside the list bounds one set to five attempts.
## Offline: a fake curl replays canned model rounds, the skillset is a fixture, and the list is the one the CheckList tool keeps. Held:
##   1. a pending item and a plain reply: the run goes on, and the instruction names the count and 1 of 5
##   2. the same set gets five instructions, and the sixth plain reply ends the run
##   3. a list with only an item in progress ends the run on the first plain reply
##   4. no list at all ends the run, as today
##   5. a changed set resets the counter, and the first instruction after it says 1 of 5
##   6. an item in progress never raises the count
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigMember="rig-helper"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsHarnessQuitNudgeCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/loop" "$rigTmp/home" "$rigTmp/skills/$rigMember"
printf -- '---\nmaintainers: rig\n---\n%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
cp "$rigTest/check-fixtures/harness-arm-gate.curl.stub.sh" "$rigTmp/loop/curl" || rigRefuse "the fake curl fixture of the model loop is missing from the package"
chmod +x "$rigTmp/loop/curl"
rigPathBase="/usr/bin:/bin"
[ "$( PATH="$rigTmp/loop:$rigPathBase" command -v curl )" = "$rigTmp/loop/curl" ] || rigRefuse "the fake curl is not first on the rig's PATH"

rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigDir="" rigSpawn="" rigList="" rigRounds=0
rigScene(){ ## scenario name, the list to keep (empty: none)
	rigDir="$rigTmp/$1"
	rigSpawn="rig-quit-$$-$1"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/OUT" "$rigDir/sandbox/input" "$rigDir/sandbox/output" "$rigDir/ws/.local/agents/spawned/rig-folder"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-not-a-token\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf -- '---\nspawn-id: %s\nparent-spawn-id: none\nowner: %s\n---\n' "$rigSpawn" "$rigMember" > "$rigDir/ws/.local/agents/spawned/rig-folder/$rigSpawn.spawn.md"
	rigList="$rigDir/ws/.local/agents/spawned/rig-folder/$rigMember.checklist.md"
	[ -z "${2:-}" ] || printf -- '%s\n' "$2" > "$rigList"
	printf '0' > "$rigDir/round"
	: > "$rigDir/curl.log"
	rigRounds=0
}
rigRound(){ ## tool name, arguments JSON -- the next canned round: one tool call
	rigRounds=$(( rigRounds + 1 ))
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call-%s","type":"function","function":{"name":"%s","arguments":"%s"}}]},"finish_reason":null}]}\n' \
		"$rigRounds" "$1" "$( printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g' )" > "$rigDir/res.$rigRounds"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' >> "$rigDir/res.$rigRounds"
	printf 'data: [DONE]\n' >> "$rigDir/res.$rigRounds"
}
rigPlainRounds(){ ## how many -- that many rounds of plain text, which is a quit attempt
	local plainLeft="$1"
	while [ "$plainLeft" -gt 0 ] ; do
		rigRounds=$(( rigRounds + 1 ))
		printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-DONE"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' > "$rigDir/res.$rigRounds"
		plainLeft=$(( plainLeft - 1 ))
	done
}
rigLoopRc=0
rigLoop(){ ## -- the model loop of the spawned session, guarded
	rigLoopRc=0
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/loop:$rigPathBase" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_SESSION_ID="$rigSpawn" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SANDBOX_ROOT="$rigDir/sandbox" \
		RIG_SCENARIO="$rigDir" RIG_CURL_LOG="$rigDir/curl.log" RIG_TMP="$rigTmp" RIG_HARNESS="$rigHarness" RIG_MEMBER="$rigMember" \
		HARNESS_PROVIDER_NAME="quit nudge rig" HARNESS_SELF_NAME="AgentsHarnessQuitNudgeCheck.test.sh" \
		HARNESS_ENDPOINT="https://harness-quit-nudge-check.invalid/v1/chat/completions" HARNESS_HOST="harness-quit-nudge-check.invalid" \
		HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none" HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" \
		HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: curl is not the rig fake" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_HARNESS" --access-read-root "$MMDAPP" --access-read-root "$MDAT_SKILLSET_ROOT" --access-write-root "$MMDAPP/OUT" --agent "$RIG_MEMBER" RIG-TASK
		' > "$rigDir/out" 2> "$rigDir/err" || rigLoopRc=$?
	[ "$( cat "$rigDir/round" )" != 0 ] || rigRefuse "the harness made no model request: $( tail -3 "$rigDir/err" | LC_ALL=C tr '\n' ' ' )"
}
rigRequests(){ ## the canned requests this run made, by round number, in order
	LC_ALL=C ls "$rigDir"/req.* 2> /dev/null | LC_ALL=C sort -t. -k2 -n
}
rigInstructions(){ ## how many requests carry the quit instruction
	LC_ALL=C grep -l -F "This session's CheckList still holds" "$rigDir"/req.* 2> /dev/null | wc -l | tr -d ' '
}
rigAttempts(){ ## the attempt numbers of the instruction, in round order, one a line
	local reqFile
	for reqFile in $( rigRequests ) ; do
		LC_ALL=C grep -o -E 'This is attempt [0-9]+ of 5 on this same list' "$reqFile" 2> /dev/null | LC_ALL=C sed -E 's/This is attempt ([0-9]+) .*/\1/' | LC_ALL=C tail -1 || :
	done
}
rigSaid(){ ## file, fixed text -- how many of its lines hold it, 0 where there is no such file
	local saidCount
	saidCount="$( LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null )" || :
	printf '%s' "${saidCount:-0}"
}

echo "-- 1. a pending item and a plain reply: the run goes on, and the instruction names the count --"
rigScene one-pending '- [ ] Fix the index'
rigPlainRounds 6
rigLoop
rigAssert "the run went on past the plain reply"                "$( cat "$rigDir/round" )" "6"
rigAssert "the instruction is given"                            "$( rigInstructions )" "5"
rigAssert "it names the pending count, not the round"           "$( rigSaid "$rigDir/req.2" 'holds 1 pending item(s)' )" "1"
rigAssert "it names the handback's own argument"                 "$( rigSaid "$rigDir/req.2" 'hand back with checklist_pending_count=1 listing them as unfinished' )" "1"

echo "-- 2. the same set gets five instructions, and the sixth plain reply ends the run --"
rigAssert "the attempt numbers count one to five"              "$( rigAttempts | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "1 2 3 4 5"
rigAssert "and the run ended cleanly on the sixth"              "$rigLoopRc:$( LC_ALL=C grep -c . "$rigDir/out" )" "0:6"

echo "-- 3. a list with only an item in progress ends the run on the first plain reply --"
rigScene in-progress-only '- [~] Run the suite'
rigPlainRounds 1
rigLoop
rigAssert "the run ended at once"                               "$rigLoopRc:$( cat "$rigDir/round" )" "0:1"
rigAssert "and no instruction was given"                        "$( rigInstructions )" "0"

echo "-- 4. no list at all ends the run, as today --"
rigScene no-list ''
rigPlainRounds 1
rigLoop
rigAssert "the run ended at once"                               "$rigLoopRc:$( cat "$rigDir/round" )" "0:1"
rigAssert "and no instruction was given"                        "$( rigInstructions )" "0"

echo "-- 5. a changed set resets the counter, and its first instruction says 1 of 5 --"
rigScene changed-set '- [ ] Fix the index'
rigPlainRounds 1
rigRound CheckList '{"todos":[{"content":"Fix the index","status":"pending","activeForm":"Fixing the index"},{"content":"Run the suite","status":"pending","activeForm":"Running the suite"}]}'
rigPlainRounds 6
rigLoop
rigAssert "the first instruction named the first set"           "$( rigSaid "$rigDir/req.2" 'holds 1 pending item(s)' )" "1"
rigAssert "and the first after the change names the second"     "$( rigSaid "$rigDir/req.4" 'holds 2 pending item(s)' )" "1"
rigAssert "with its attempt counted from one again"             "$( rigSaid "$rigDir/req.4" 'This is attempt 1 of 5 on this same list' )" "1"
rigAssert "and the run ended cleanly"                           "$rigLoopRc" "0"

echo "-- 6. an item in progress never raises the count --"
rigScene mixed '- [ ] Fix the index
- [~] Run the suite'
rigPlainRounds 6
rigLoop
rigAssert "the count is the pending items alone"                "$( rigSaid "$rigDir/req.2" 'holds 1 pending item(s)' )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ QUIT NUDGE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a plain reply quits the run while the list still holds pending items, or the counter" >&2
	echo "        never bounds it, or it bounds the wrong set" >&2
	echo "  fix:  repair the harness -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_QUIT_NUDGE: OK (%d assertions, offline)\n' "$rigPassCount"
