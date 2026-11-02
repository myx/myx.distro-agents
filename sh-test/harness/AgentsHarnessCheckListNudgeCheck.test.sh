#!/usr/bin/env bash
## Behavioural check on the CheckList nudge (the owner's standing ruling, `20261026-refactorings.epic.md:59`): a run whose own CheckList has not
## changed for 30 minutes, and which made at least 15 tool calls other than Wait since, is given one plain message as its next chat message. At most
## one per 30 minutes, and a list write resets both the count and the clock. Held, against the real harness model loop, a fake curl that replays
## canned rounds and the list a fixture in the rig's spawn folder:
##   1. fifteen calls other than Wait, with a list 31 minutes old: the next request carries the message, and nothing before it does
##   2. fourteen such calls: no message
##   3. a list 29 minutes old: no message
##   4. a list write between them: the count starts again, and nothing is nudged at the fourteenth call
##   5. a nudge given a minute ago is not repeated, and one given 31 minutes ago is given
##   6. a nudge mark that is unreadable still lets the first nudge fire
## Offline: a fake curl replays canned model rounds, the skillset is a fixture, every run an `env -i` child.
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
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsHarnessCheckListNudgeCheck.XXXXXX" )" || exit 1
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
rigScene(){ ## scenario name, list age in seconds (empty: a list written now), the list to keep
	rigDir="$rigTmp/$1"
	rigSpawn="rig-nudge-$$-$1"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/OUT" "$rigDir/sandbox/input" "$rigDir/sandbox/output" "$rigDir/ws/.local/agents/spawned/rig-folder"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-not-a-token\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf -- '---\nspawn-id: %s\nparent-spawn-id: none\nowner: %s\n---\n' "$rigSpawn" "$rigMember" > "$rigDir/ws/.local/agents/spawned/rig-folder/$rigSpawn.spawn.md"
	rigList="$rigDir/ws/.local/agents/spawned/rig-folder/$rigMember.checklist.md"
	printf -- '%s\n' "${3:-}" > "$rigList"
	[ -z "${2:-}" ] || touch -t "$( date -r "$(( $( date +%s ) - $2 ))" '+%Y%m%d%H%M.%S' )" "$rigList"
	## The fake curl counts the rounds itself, from this file, and nothing else writes it.
	printf '0' > "$rigDir/round"
	: > "$rigDir/curl.log"
	rigRounds=0
}
rigRound(){ ## tool name, and the arguments JSON when it takes any -- the next canned round: one tool call
	rigRounds=$(( rigRounds + 1 ))
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call-%s","type":"function","function":{"name":"%s","arguments":"%s"}}]},"finish_reason":null}]}\n' \
		"$rigRounds" "$1" "$( printf '%s' "${2:-{\}}" | sed 's/\\/\\\\/g; s/"/\\"/g' )" > "$rigDir/res.$rigRounds"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' >> "$rigDir/res.$rigRounds"
	printf 'data: [DONE]\n' >> "$rigDir/res.$rigRounds"
}
rigCalls(){ ## how many, and the tool to call -- that many rounds of one named tool
	local rigLeft="$1"
	while [ "$rigLeft" -gt 0 ] ; do rigRound "$2" ; rigLeft=$(( rigLeft - 1 )) ; done
}
rigPlainRounds(){ ## how many -- that many rounds of a plain reply, which is a quit attempt; six end the run
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
		HARNESS_PROVIDER_NAME="checklist nudge rig" HARNESS_SELF_NAME="AgentsHarnessCheckListNudgeCheck.test.sh" \
		HARNESS_ENDPOINT="https://harness-checklist-nudge-check.invalid/v1/chat/completions" HARNESS_HOST="harness-checklist-nudge-check.invalid" \
		HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none" HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" \
		HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: curl is not the rig fake" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_HARNESS" --access-read-root "$MMDAPP" --access-read-root "$MDAT_SKILLSET_ROOT" --access-write-root "$MMDAPP/OUT" --agent "$RIG_MEMBER" RIG-TASK
		' > "$rigDir/out" 2> "$rigDir/err" || rigLoopRc=$?
	[ "$( cat "$rigDir/round" )" != 0 ] || rigRefuse "the harness made no model request: $( tail -3 "$rigDir/err" | LC_ALL=C tr '\n' ' ' )"
}
rigNudgeAt(){ ## the round number of the first request that carries the nudge, empty where none does
	LC_ALL=C grep -l -F "has not changed for 30 minutes" "$rigDir"/req.* 2> /dev/null | LC_ALL=C sed 's|.*/req\.||' | LC_ALL=C sort -n | head -1
}
rigNudgeMost(){ ## the most times one request carries the nudge: 1 where it was added once and kept in the history
	local mostCount=0 reqFile reqCount
	for reqFile in "$rigDir"/req.* ; do
		[ -f "$reqFile" ] || continue
		reqCount="$( LC_ALL=C grep -o -F "has not changed for 30 minutes" "$reqFile" 2> /dev/null | wc -l | tr -d ' ' )"
		[ "$reqCount" -le "$mostCount" ] || mostCount="$reqCount"
	done
	printf '%s' "$mostCount"
}

echo "-- 1. fifteen calls other than Wait, on a list 31 minutes old: the next request carries the message --"
rigScene old-list-and-enough-calls 1860 '- [ ] Fix the index'
rigCalls 15 Bash
rigPlainRounds 6
rigLoop
rigAssert "the message is added once, not once a round"            "$( rigNudgeMost )" "1"
rigAssert "and the sixteenth request is the first to carry it"     "$( rigNudgeAt )" "16"
rigAssert "it names the line it wants"                             "$( LC_ALL=C grep -c -F 'Say in one plain line where the work stands' "$rigDir/req.16" 2> /dev/null )" "1"

echo "-- 2. fourteen such calls: no message --"
rigScene old-list-few-calls 1860 '- [ ] Fix the index'
rigCalls 14 Bash
rigPlainRounds 6
rigLoop
rigAssert "no message is given"                                    "$( rigNudgeAt )" ""

echo "-- 3. a list 29 minutes old: no message --"
rigScene young-list 1740 '- [ ] Fix the index'
rigCalls 15 Bash
rigPlainRounds 6
rigLoop
rigAssert "no message is given"                                    "$( rigNudgeAt )" ""

echo "-- 4. a list write resets the count --"
rigScene list-write-resets 1860 '- [ ] Fix the index'
rigCalls 10 Bash
rigRound CheckList '{"todos":[{"content":"Fix the index","status":"in_progress","activeForm":"Fixing the index"}]}'
rigCalls 14 Bash
rigPlainRounds 6
rigLoop
rigAssert "no message is given while the count is under fifteen after the write"  "$( rigNudgeAt )" ""

echo "-- 5. a nudge given a minute ago is not repeated, and one given 31 minutes ago is given --"
rigScene twice 1860 '- [ ] Fix the index'
printf '%s\n' "$(( $( date +%s ) - 60 ))" > "$rigDir/ws/.local/agents/spawned/rig-folder/checklist.nudge"
rigCalls 15 Bash
rigPlainRounds 6
rigLoop
rigAssert "the recent nudge holds the message back"                "$( rigNudgeAt )" ""
rm -f "$rigDir"/req.* "$rigDir"/res.*
printf '%s\n' "$(( $( date +%s ) - 1860 ))" > "$rigDir/ws/.local/agents/spawned/rig-folder/checklist.nudge"
touch -t "$( date -r "$(( $( date +%s ) - 1860 ))" '+%Y%m%d%H%M.%S' )" "$rigList"
printf '0' > "$rigDir/round"
rigRounds=0
rigCalls 15 Bash
rigPlainRounds 6
rigLoop
rigAssert "a nudge 31 minutes old is given again"                  "$( rigNudgeAt )" "16"

echo "-- 6. a nudge mark that is unreadable still lets the first nudge fire --"
rigScene no-mark 1860 '- [ ] Fix the index'
printf 'not-a-number\n' > "$rigDir/ws/.local/agents/spawned/rig-folder/checklist.nudge"
rigCalls 15 Bash
rigPlainRounds 6
rigLoop
rigAssert "the first nudge fires"                                  "$( rigNudgeAt )" "16"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CHECKLIST NUDGE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a run that stops moving its list is never nudged, or is nudged twice inside the half hour" >&2
	echo "  fix:  repair the harness -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_CHECKLIST_NUDGE: OK (%d assertions, offline)\n' "$rigPassCount"
