#!/usr/bin/env bash
## Behavioural check on the agent reset of the model path (F10.6 of the refactorings epic), run through the real core and the
## Anthropic Messages wire against a fake `curl` replaying canned streams that records each request body, and through the real
## ThisSession operations (--executor-checkpoint-rewind, --idle-wait). The reset is INTERNAL: the run is returned to its armed state
## (F10.5) and nothing a member is told changes, and what it promises is that the member's NEXT run starts armed from the cached entry.
## Held:
##   1. a rewind (the executor's own) returns the run to its armed state
##   2. so does the return of an `--idle-wait` that an arrival ends
##   3. a run with no team session (MDAT_SESSION_ID unset) still returns on a rewind
##   4. a rewind that is refused (no snapshot of the name) returns nothing
##   5. DONE WHEN: the member's next run, a second spawn in the same workspace, starts armed from the cached entry: its armed file is
##      served from the stamped entry the first spawn left (1 from the cache, 0 built) and untouched, it acts in its first round with no
##      read round, and nothing it is told mentions the reset, a cache, or a parked agent
## Offline by construction: no socket, no credential; a call to anything but the model is refused and logged.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTest="$rigPackage/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigSession="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
rigKind="$rigPackage/skillset/magic-team/magic-team/magic-team.standalone.routine.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -f "$rigSession" ] || rigRefuse "ThisSession not found at the origin this workspace resolves: $rigSession"
[ -f "$rigKind" ] || rigRefuse "the standalone routine is not in the package: $rigKind"
[ -f "$rigHere/harness/AgentsHarnessCheckpoint.include" ] || rigRefuse "the checkpoint include is not in the package: $rigHere/harness/AgentsHarnessCheckpoint.include"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessResetCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home"
cp "$rigTest/check-fixtures/harness-idle-wait.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package: sh-test/check-fixtures/harness-idle-wait.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
[ "$( PATH="$rigTmp/bin:/usr/bin:/bin" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCount(){ ## file, text -- how many times the file holds the text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C grep -o -F -- "$2" "$1" | wc -l | tr -d ' '
}
rigCountI(){ ## file, extended pattern -- how many times the file holds it, whatever the case
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C grep -o -i -E -- "$2" "$1" | wc -l | tr -d ' '
}
rigPresent(){ ## file -- there or gone
	[ -e "$1" ] && printf there || printf gone
}
rigMtime(){ ## file -- its modification time in epoch seconds
	stat -f %m "$1" 2> /dev/null || stat -c %Y "$1" 2> /dev/null || printf none
}

## The skillset of the rig: the team's files with the standalone kind routine, a member, and a routine of the member that declares a scan.
rigSkills="$rigTmp/skills"
mkdir -p "$rigSkills/magic-team" "$rigSkills/rig-a"
printf 'RIG-TEAM-COMMON-LINE one two\n' > "$rigSkills/magic-team/magic-team.basic.md"
printf '# Nothing stops on its own\n\nRIG-TEAM-SECTION\n' > "$rigSkills/magic-team/magic-team.armed.md"
printf -- '---\nname: magic-team\n---\nteam skill\n' > "$rigSkills/magic-team/SKILL.md"
cp "$rigKind" "$rigSkills/magic-team/" || rigRefuse "the standalone routine could not be copied into the rig"
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigSkills/rig-a/rig-a.basic.md"
printf -- '---\nstatus: rig\n---\nRIG-A-ARMED-BODY\n' > "$rigSkills/rig-a/rig-a.armed.md"
printf -- '---\nname: rig-a\n---\nmember skill\n' > "$rigSkills/rig-a/SKILL.md"
rigRoutine(){ ## short name, scan line ('' for none declared)
	{
		printf -- '---\ntype: routine\nexecutors: rig-a\nmaintainers: magic-coordinator\ninvitees: none\nrequires-session-kind: standalone\n'
		[ -z "$2" ] || printf 'input-scan-def: %s\n' "$2"
		printf 'access-control: executors:allow-tool:--executor-checkpoint-push,executors:allow-tool:--executor-checkpoint-rewind,executors:allow-tool:--executor-checkpoint-exit\n'
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **rig-open**: open.\n\n# Steps\n\n1. **rig-work**: work.\n\n# Closure steps\n\n1. **rig-close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-team/magic-team.$1.routine.md"
}
rigRoutine rigduty grooming
rigRoutine rigquiet ''

rigSpawn="rig-spawn-reset"
rigDir="" rigWs="" rigSandbox="" rigStore="" rigSessId=""
rigScene(){ ## scene name, routine short name ('' for a spawn with no routine) -- a workspace of its own, unless rigWsShared names one
	rigDir="$rigTmp/$1" ; rigWs="${rigWsShared:-$rigTmp/ws-$1}" ; rigSandbox="$rigDir/sandbox" ; rigStore="$rigWs/.local/agents/sessions/$rigSpawn"
	mkdir -p "$rigDir" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig" "$rigSandbox/input" "$rigSandbox/output"
	printf '0' > "$rigDir/round"
	{
		printf -- '---\nspawn-id: %s\nsession-id: %s\n' "$rigSpawn" "$rigSpawn"
		[ -z "$2" ] || printf 'routine: magic-team.%s.routine.md\n' "$2"
		printf 'status: spawn-started\n---\n\n# Spawn session: %s\n' "$rigSpawn"
	} > "$rigWs/.local/agents/spawned/rig/$rigSpawn.spawn.md"
	cp "$rigWs/.local/agents/spawned/rig/$rigSpawn.spawn.md" "$rigSandbox/$rigSpawn.spawn.md"
}
rigTextStream(){ ## canned-stream file, content
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig2","type":"message","role":"assistant","content":[],"usage":{"input_tokens":60,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"%s"}}\n\n' "$2"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}
rigEsc(){ ## a JSON text as a JSON string's content
	printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}
rigToolStream(){ ## canned-stream file, then name and input JSON for each call of the turn
	local streamFile="$1" streamIndex=0
	shift
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig1","type":"message","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		while [ $# -ge 2 ] ; do
			printf 'event: content_block_start\ndata: {"type":"content_block_start","index":%s,"content_block":{"type":"tool_use","id":"toolu_RIG%s","name":"%s","input":{}}}\n\n' "$streamIndex" "$streamIndex" "$1"
			printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":%s,"delta":{"type":"input_json_delta","partial_json":"%s"}}\n\n' "$streamIndex" "$( rigEsc "$2" )"
			printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":%s}\n\n' "$streamIndex"
			streamIndex=$(( streamIndex + 1 )) ; shift 2
		done
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":40}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$streamFile"
}
rigOp(){ ## operation word and arguments -- the Bash call that makes it, in the scene's folder
	printf '{"cwd":"%s","command":"bash \\"%s\\" %s"}' "$rigDir" "$rigSession" "$*"
}
rigWriteJson(){ ## file name -- the Write call that makes a file of the run's own
	printf '{"file_path":"%s/%s","content":"RIG-ACTED"}' "$rigDir" "$1"
}
rigRun(){ ## further harness arguments -- the run, as the team session rigSessId when that is set
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_SESSION_ID="$rigSpawn" MDAT_SPAWN_AGENT=rig-a MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" ${rigSessId:+MDAT_SESSION_ID="$rigSessId"} RIG_SCENARIO="$rigDir" \
		HARNESS_PROVIDER_NAME="two-spawn rig" HARNESS_SELF_NAME="AgentsHarnessResetCheck.test.sh" HARNESS_WIRE="AnthropicMessages" HARNESS_CREDENTIAL_NAMES="none" \
		HARNESS_ENDPOINT="https://harness-idle-wait.invalid/v1/messages" HARNESS_HOST="harness-idle-wait.invalid" HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01" \
		HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
		HARNESS_OUTPUT_TOKENS_LIGHT="4101" HARNESS_OUTPUT_TOKENS_MAIN="4202" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 240 -- bash "$rigHarness" --agent rig-a --access-root "$rigDir" "$@" RIG-TASK-MARKER ) > "$rigDir/out" 2> "$rigDir/err"
	rigRunStatus=$?
	[ "$( cat "$rigDir/round" )" != 0 ] || rigRefuse "the harness issued no request at all -- its stderr: $( head -5 "$rigDir/err" )"
}
echo "-- 1. the executor's rewind returns the run to its armed state --"
rigSessId="$rigSpawn" rigWsShared=""
rigScene rewind rigquiet
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-rewind armed )"
rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
rigAssert "the run ends normally, in two requests, and returned to armed"                  "$rigRunStatus:$( cat "$rigDir/round" ):$( LC_ALL=C grep -c 'rewound' "$rigDir/err" )" 0:2:1

echo "-- 2. so does the return of an idle-wait that an arrival ends --"
rigScene idle rigduty
rigToolStream "$rigDir/res.1" Bash "$( rigOp --idle-wait )"
rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
rigAssert "the arrival returned the run (the scan's report is in the request after it)"      "$( rigCount "$rigDir/req.2" 'state-and-lock (routine-grooming)' ):$( LC_ALL=C grep -c 'rewound' "$rigDir/err" )" 1:1

echo "-- 3. a run with no team session still returns on a rewind --"
rigSessId=""
rigScene nosession rigquiet
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-rewind armed )"
rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
rigAssert "the rewind is made"                                                              "$( LC_ALL=C grep -c 'rewound' "$rigDir/err" )" 1
rigSessId="$rigSpawn"

echo "-- 4. a refused rewind returns nothing --"
rigScene refused rigquiet
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-rewind nosuch )"
rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
rigAssert "no snapshot of that name: refused in the call's answer, no return"              "$( LC_ALL=C grep -c 'rewound' "$rigDir/err" )" 0

echo "-- 5. done when: the member's next run starts armed from the cached entry --"
rigWsShared="$rigTmp/ws-shared" ; rigSessId=""
rigSpawn="rig-spawn-first"
rigScene first ""
rigToolStream "$rigDir/res.1" Write "$( rigWriteJson one.txt )"
rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
rigFirstDir="$rigDir" rigEntry="$( ls "$rigWsShared"/.local/agents/prefetch/read.rig-a.rig-a.armed.md.* 2> /dev/null | head -1 )"
rigFirstTime="$( rigMtime "$rigEntry" )"
rigAssert "control: the first spawn built the entry, from nothing, and acted in its first round"  "$( LC_ALL=C grep -c '0 from the cache, 1 built' "$rigDir/err" ):$( cat "$rigDir/one.txt" 2> /dev/null ):$( cat "$rigDir/round" )" 1:RIG-ACTED:2
sleep 2
rigSpawn="rig-spawn-second"
rigScene second ""
rigToolStream "$rigDir/res.1" Write "$( rigWriteJson two.txt )"
rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
rigAssert "the second spawn is served its armed file from the entry the first left: 1 from the cache, 0 built"  "$( LC_ALL=C grep -c '1 from the cache, 0 built' "$rigDir/err" )" 1
rigAssert "and the entry is untouched by it: not rewritten"                                  "$( rigMtime "$rigEntry" ):$( [ -n "$rigEntry" ] && printf entry || printf none )" "$rigFirstTime:entry"
rigAssert "it is armed at the start: it acts in its first round with no read round (two requests, no Skill call)"  "$( cat "$rigDir/round" ):$( cat "$rigDir/two.txt" 2> /dev/null ):$( rigCount "$rigDir/req.2" '"name":"Skill","input"' ):$( rigCount "$rigDir/req.2" '"name":"Write","input"' )" 2:RIG-ACTED:0:1
rigAssert "its first message already holds the armed file, once, and says it is read for it"  "$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' ):$( rigCount "$rigDir/req.1" 'read for you before your task' )" 1:1
rigAssert "nothing it is told mentions a reset, a parked or warm agent, a cache of its own start, or a snapshot"  "$( rigCountI "$rigDir/req.1" 'agent reset|reset the agent|reset to (its )?(armed|initial)|parked agent|warm agent|freshly loaded|snapshot|rewound' )" 0
rigAssert "nor does any instruction of the skillset"                                         "$( LC_ALL=C grep -r -l -i -E 'agent reset|reset the agent|parked agent|warm agent|freshly loaded' "$rigPackage/skillset" 2> /dev/null | wc -l | tr -d ' ' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS RESET CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_RESET: OK (%d assertions, offline)\n' "$rigPassCount"
