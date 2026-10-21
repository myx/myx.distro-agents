#!/usr/bin/env bash
## Behavioural check on `--idle-wait` of the model path (F10.5 gate B of the refactorings epic), run through the real core and the
## Anthropic Messages wire against a fake `curl` replaying canned streams, which records each request body, and through the real
## ThisSession operation (DistroAgentsSession.fn.sh --idle-wait) that the model's own Bash call makes. The call WRITES A REQUEST; the
## harness reads it at the end of the round, when the round is whole, waits there -- in its own process, as the Wait tool waits, so a
## dismissal, the seat and the review limit are the Wait tool's -- and on an arrival puts the conversation back to the run's checkpoint
## (`opening` where the run holds it, else `armed`) with the arrival as the next input. The model spends nothing while it waits, and its
## context does not grow by the rounds of the work it has done. Held:
##   1. an arrival returns the run to `armed`, and the request that follows is the first request through the end of the prefetch block,
##      byte for byte (the input token cache), the task block holding the task and the arrival
##   2. an arrival returns the run to `opening` where it holds it: the request that follows is the request at the checkpoint, byte for
##      byte, then the arrival as a user message; the work between is not in the conversation, the file it wrote is still there
##   3. the task block is the task itself and the one input of this cycle: a second return does not carry the first's (the new dispatch
##      of a rewind, `--executor-checkpoint-rewind --from-stdin`, given twice), for the init kind and for the count kind
##   4. a wait that comes back with no arrival (a TIMEOUT) returns nothing: the model is told so, and its conversation stays
##   5. so does a wait that could not be made, and a wait of a session that is dismissed (the DISMISSED is the model's to read)
##   6. a run with no declared scan waits on the floor alone; a run with a scan waits on the floor and the scan
##   7. a run that holds no snapshot (after `exit`) takes the arrival as a message, and is told nothing was returned
##   8. a quiet round of the session's wait does not wake the model: the harness waits on, and the model is woken once
##   9. the spawner has given the run the report of its declared scan (it keeps the scan's pointer at that report): the first --idle-wait
##      does not wake on it. Without the pointer (1 to 7) the first --idle-wait wakes on the report the scan has
##  10. the prompt-cache line of round 1 (F10.7) is printed for round 1 of each leg -- the run's first, and the first after each rewind or wake --
##      and not for the rounds between, so that the last such line of a run's log is the cache's figure at its last wake: the work-duty's lifetime
##      reads it (a wake that read nothing from the cache ends the duty after 20 idle minutes, AgentsToolsScheduleDutyCache)
## Offline by construction: no socket, no credential; a call to anything but the model is refused and logged.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigSession="${rigHere%/sh-lib}/sh-scripts/DistroAgentsSession.fn.sh"
rigKind="${rigHere%/sh-lib}/skillset/magic-team/magic-team/magic-team.standalone.routine.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -f "$rigSession" ] || rigRefuse "ThisSession not found at the origin this workspace resolves: $rigSession"
[ -f "$rigKind" ] || rigRefuse "the standalone routine is not in the package: $rigKind"
[ -f "$rigHere/harness/AgentsHarnessCheckpoint.include" ] || rigRefuse "the checkpoint include is not in the package: $rigHere/harness/AgentsHarnessCheckpoint.include"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessIdleWaitCheck )" || exit 1
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
rigIn(){ ## text, needle -- yes where the text holds the needle
	case "$1" in
		*"$2"*) printf 'yes' ;;
		*) printf 'no' ;;
	esac
}
rigCount(){ ## file, text -- how many times the file holds the text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C grep -o -F -- "$2" "$1" | wc -l | tr -d ' '
}
rigSame(){ ## two files -- same or differs
	cmp -s "$1" "$2" 2> /dev/null && printf same || printf differs
}
rigUpTo(){ ## file, text -- the checksum of the file's bytes before the first place that holds the text
	local upToAt
	upToAt="$( LC_ALL=C grep -b -o -F -- "$2" "$1" 2> /dev/null | head -1 | cut -d : -f 1 )"
	[ -n "$upToAt" ] || { printf 'no-such-place' ; return 0 ; }
	head -c "$upToAt" "$1" | cksum | cut -d ' ' -f 1
}

## The skillset of the rig: the team's files with the standalone kind routine, a member, and routines of one participant -- one that
## declares a scan, one that declares none; both allow the checkpoint operations. `--idle-wait` needs no allows: of its own.
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
		printf 'allows: executors:--executor-checkpoint-push,executors:--executor-checkpoint-rewind,executors:--executor-checkpoint-exit\n'
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **rig-open**: open.\n\n# Steps\n\n1. **rig-work**: work.\n\n# Closure steps\n\n1. **rig-close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-team/magic-team.$1.routine.md"
}
rigRoutine rigduty grooming
rigRoutine rigquiet ''

rigSpawn="rig-spawn-idle"
rigDir="" rigWs="" rigSandbox="" rigStore=""
rigScene(){ ## scene name, routine short name
	rigDir="$rigTmp/$1" ; rigWs="$rigTmp/ws-$1" ; rigSandbox="$rigDir/sandbox" ; rigStore="$rigWs/.local/agents/sessions/$rigSpawn"
	mkdir -p "$rigDir" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig" "$rigSandbox/input" "$rigSandbox/output"
	printf '0' > "$rigDir/round"
	printf -- '---\nspawn-id: %s\nsession-id: %s\nroutine: magic-team.%s.routine.md\nstatus: spawn-started\n---\n\n# Spawn session: %s\n' "$rigSpawn" "$rigSpawn" "$2" "$rigSpawn" > "$rigWs/.local/agents/spawned/rig/$rigSpawn.spawn.md"
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
rigOpText(){ ## text, operation word and arguments -- the Bash call that makes it with the text on its standard input
	printf '{"cwd":"%s","command":"printf %%s %s | bash \\"%s\\" %s"}' "$rigDir" "$1" "$rigSession" "${*:2}"
}
rigWorkJson(){ ## file name -- the Write call that makes a file of the run's own
	printf '{"file_path":"%s/%s","content":"RIG-WORK"}' "$rigDir" "$1"
}
rigPrefetch="on"
rigRun(){ ## further harness arguments
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_SESSION_ID="$rigSpawn" MDAT_SPAWN_AGENT=rig-a MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" MDAT_HARNESS_PREFETCH="$rigPrefetch" RIG_SCENARIO="$rigDir" \
		HARNESS_PROVIDER_NAME="idle-wait rig" HARNESS_SELF_NAME="AgentsHarnessIdleWaitCheck.test.sh" HARNESS_WIRE="AnthropicMessages" HARNESS_CREDENTIAL_NAMES="none" \
		HARNESS_ENDPOINT="https://harness-idle-wait.invalid/v1/messages" HARNESS_HOST="harness-idle-wait.invalid" HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01" \
		HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
		HARNESS_OUTPUT_TOKENS_LIGHT="4101" HARNESS_OUTPUT_TOKENS_MAIN="4202" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
		perl -e 'alarm 240 ; exec @ARGV' bash "$rigHarness" --agent rig-a --access-root "$rigDir" "$@" RIG-TASK-MARKER ) > "$rigDir/out" 2> "$rigDir/err"
	rigRunStatus=$?
	[ "$( cat "$rigDir/round" )" != 0 ] || rigRefuse "the harness issued no request at all -- its stderr: $( head -5 "$rigDir/err" )"
}
rigHeld(){ ## the names of the snapshots the run's store holds, in order, space-joined
	LC_ALL=C awk -F '\t' 'NF { printf "%s%s", sep, $1 ; sep = " " }' "$rigStore/snapshots" 2> /dev/null
}
rigOther(){ ## how many calls to anything but the model the rig refused
	[ -f "$rigDir/curl.other.log" ] && wc -l < "$rigDir/curl.other.log" | tr -d ' ' || printf 0
}
rigArrival='state-and-lock (routine-grooming)'

echo "-- 1. an arrival returns the run to armed --"
rigScene to-armed rigduty
rigToolStream "$rigDir/res.1" Bash "$( rigOp --idle-wait )"
rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
rigAssert "the run ends normally, in two requests"                                       "$rigRunStatus:$( cat "$rigDir/round" )" 0:2
rigAssert "the arrival is the scan's report, and it is in the request after the return"   "$( rigCount "$rigDir/req.1" "$rigArrival" ):$( rigCount "$rigDir/req.2" "$rigArrival" )" 0:1
rigAssert "the request after the return is the first request, through the prefetch block, and has the arrival" "$( rigUpTo "$rigDir/req.1" RIG-TASK-MARKER ):$( rigUpTo "$rigDir/req.2" RIG-TASK-MARKER ):$( rigCount "$rigDir/req.2" "$rigArrival" )" "$( rigUpTo "$rigDir/req.1" RIG-TASK-MARKER ):$( rigUpTo "$rigDir/req.1" RIG-TASK-MARKER ):1"
rigAssert "the prefetch block, and the cache marker at its end, are in it as they were"    "$( rigCount "$rigDir/req.2" 'RIG-A-ARMED-BODY' ):$( rigCount "$rigDir/req.2" '"cache_control":{"type":"ephemeral"}' ):$( rigCount "$rigDir/req.2" 'toolu_RIG' )" 1:4:0
rigAssert "the task is in it once, and nothing of the call that waited"                    "$( rigCount "$rigDir/req.2" RIG-TASK-MARKER ):$( rigCount "$rigDir/req.2" 'toolu_RIG' ):$( rigCount "$rigDir/req.2" 'OK: --idle-wait' )" 1:0:0
rigAssert "it says where the run is, and that the files are as the work left them"         "$( rigIn "$( cat "$rigDir/req.2" )" 'returned to its checkpoint armed' ):$( rigIn "$( cat "$rigDir/req.2" )" 'files' )" yes:yes
rigAssert "the Wait tool's own next step is not carried: it is not a Wait that goes on"     "$( rigCount "$rigDir/req.2" 'if this is not what you are waiting for' ):$( rigCount "$rigDir/req.2" 'WAIT-RESULT: RECEIVED' )" 0:1
rigAssert "the snapshots the run holds are as they were: armed, after the return"          "$( rigHeld ):$( rigCount "$rigDir/req.2" "$rigArrival" )" armed:1
rigAssert "the run says it waited and returned"                                           "$( rigIn "$( cat "$rigDir/err" )" 'idle-wait' ):$( rigIn "$( cat "$rigDir/err" )" 'rewound' )" yes:yes
rigAssert "a new leg of the kept context is opened"                                       "$( LC_ALL=C grep '"type":"context"' "$rigSandbox/context.jsonl" 2> /dev/null | LC_ALL=C grep -c '"leg":2,' )" 1
rigAssert "nothing but the model was called"                                              "$( rigOther )" 0
rigAssert "the cache line of round 1 is printed at the first request and again at the first request after the wake (10)" "$( rigCount "$rigDir/err" 'shared prefix -- round 1 ' )" 2

echo "-- 2. an arrival returns the run to opening, where it holds it --"
rigScene to-opening rigduty
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-push opening )"
rigToolStream "$rigDir/res.2" Write "$( rigWorkJson work.txt )"
rigToolStream "$rigDir/res.3" Bash "$( rigOp --idle-wait )"
rigTextStream "$rigDir/res.4" RIG-DONE ; rigRun
rigAssert "four requests"                                                                 "$rigRunStatus:$( cat "$rigDir/round" )" 0:4
rigAssert "the snapshots, after the return: armed, opening (the stack is kept up to it)"   "$( rigHeld ):$( rigCount "$rigDir/req.4" "$rigArrival" )" "armed opening:1"
rigAssert "the work between is not in the conversation any more"                          "$( rigCount "$rigDir/req.3" 'RIG-WORK' ):$( rigCount "$rigDir/req.4" 'RIG-WORK' )" 1:0
rigAssert "but the file it wrote is still there: only the conversation returns"           "$( cat "$rigDir/work.txt" 2> /dev/null ):$( rigCount "$rigDir/req.4" "$rigArrival" )" RIG-WORK:1
rigAssert "the request after the return holds the checkpoint's whole conversation, then the arrival" "$( head -c "$(( $( wc -c < "$rigDir/req.2" ) - 8 ))" "$rigDir/req.2" | cksum | cut -d ' ' -f 1 ):$( rigCount "$rigDir/req.4" "$rigArrival" )" "$( head -c "$(( $( wc -c < "$rigDir/req.2" ) - 8 ))" "$rigDir/req.4" | cksum | cut -d ' ' -f 1 ):1"
rigAssert "the arrival says where the run is"                                             "$( rigIn "$( cat "$rigDir/req.4" )" 'returned to its checkpoint opening' )" yes

echo "-- 3. the task block is the task and the one input of this cycle --"
rigScene dispatch-init rigduty
rigToolStream "$rigDir/res.1" Bash "$( rigOpText 'DISPATCH-O$(printf N)E' --executor-checkpoint-rewind armed --from-stdin )"
rigToolStream "$rigDir/res.2" Bash "$( rigOpText 'DISPATCH-TW$(printf O)' --executor-checkpoint-rewind armed --from-stdin )"
rigTextStream "$rigDir/res.3" RIG-DONE ; rigRun
rigAssert "the first dispatch is in the second request, with the task"                    "$( rigCount "$rigDir/req.2" DISPATCH-ONE ):$( rigCount "$rigDir/req.2" RIG-TASK-MARKER )" 1:1
rigAssert "the second return carries the second dispatch and not the first"               "$( rigCount "$rigDir/req.3" DISPATCH-TWO ):$( rigCount "$rigDir/req.3" DISPATCH-ONE ):$( rigCount "$rigDir/req.3" RIG-TASK-MARKER )" 1:0:1
rigAssert "both are the first request through the prefetch block"                         "$( rigUpTo "$rigDir/req.2" RIG-TASK-MARKER ):$( rigUpTo "$rigDir/req.3" RIG-TASK-MARKER ):$( rigCount "$rigDir/req.3" DISPATCH-TWO )" "$( rigUpTo "$rigDir/req.1" RIG-TASK-MARKER ):$( rigUpTo "$rigDir/req.1" RIG-TASK-MARKER ):1"
rigScene dispatch-count rigduty
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-push opening )"
rigToolStream "$rigDir/res.2" Bash "$( rigOpText 'DISPATCH-O$(printf N)E' --executor-checkpoint-rewind opening --from-stdin )"
rigToolStream "$rigDir/res.3" Bash "$( rigOpText 'DISPATCH-TW$(printf O)' --executor-checkpoint-rewind opening --from-stdin )"
rigTextStream "$rigDir/res.4" RIG-DONE ; rigRun
rigAssert "the count kind: the dispatch is a message after the checkpoint, the second not carrying the first" "$( rigCount "$rigDir/req.3" DISPATCH-ONE ):$( rigCount "$rigDir/req.4" DISPATCH-TWO ):$( rigCount "$rigDir/req.4" DISPATCH-ONE )" 1:1:0
rigAssert "and the checkpoint's own conversation stays whole under it, and the file is spent" "$( head -c "$(( $( wc -c < "$rigDir/req.2" ) - 8 ))" "$rigDir/req.2" | cksum | cut -d ' ' -f 1 ):$( rigCount "$rigDir/req.4" DISPATCH-TWO ):$( [ -e "$rigStore/checkpoint.dispatch" ] && printf kept || printf spent )" "$( head -c "$(( $( wc -c < "$rigDir/req.2" ) - 8 ))" "$rigDir/req.4" | cksum | cut -d ' ' -f 1 ):1:spent"

echo "-- 4. a wait with no arrival returns nothing --"
rigScene quiet rigduty
rigToolStream "$rigDir/res.1" Bash "$( rigOp --idle-wait )"
rigToolStream "$rigDir/res.2" Bash "$( rigOp --idle-wait --wait-timeout 1 )"
rigTextStream "$rigDir/res.3" RIG-DONE ; rigRun
rigAssert "three requests, the second wait ended quiet"                                   "$rigRunStatus:$( cat "$rigDir/round" )" 0:3
rigAssert "the conversation stays: the call and its answer are in the request"            "$( rigCount "$rigDir/req.3" 'toolu_RIG0' ):$( rigCount "$rigDir/req.3" 'OK: --idle-wait' )" "2:1"
rigAssert "the model is told the wait ended with nothing and that nothing was returned"   "$( rigIn "$( cat "$rigDir/req.3" )" 'WAIT-RESULT: TIMEOUT' ):$( rigIn "$( cat "$rigDir/req.3" )" 'not returned' )" yes:yes
rigAssert "and how to go on waiting"                                                      "$( rigIn "$( cat "$rigDir/req.3" )" 'Call --idle-wait again' )" yes
rigAssert "a quiet wait is no wake: the line is printed at the first request and after the first wait's arrival, not after the quiet one (10)" "$( rigCount "$rigDir/err" 'shared prefix -- round 1 ' )" 2

echo "-- 5. what it waits on --"
rigScene floor rigquiet
rigToolStream "$rigDir/res.1" Bash "$( rigOp --idle-wait --wait-timeout 1 )"
rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
rigAssert "a run with no declared scan waits on the floor alone, and says so"              "$( rigIn "$( cat "$rigDir/err" )" 'idle-wait -- waiting on the floor' ):$( rigIn "$( cat "$rigDir/err" )" 'scan:' )" yes:no
rigAssert "it ended with no arrival, and the conversation was not returned"               "$( rigCount "$rigDir/req.2" 'toolu_RIG0' ):$( rigIn "$( cat "$rigDir/req.2" )" 'not returned' )" 2:yes
rigAssert "it reads the floor alone: no team channel is read for it, and none is reported unread to the model" "$( rigCount "$rigDir/req.2" 'WAIT-NEVER-READ' ):$( rigCount "$rigDir/err" 'slack-read' ):$( rigCount "$rigDir/req.2" 'WAIT-RESULT: TIMEOUT' )" "$( rigCount "$rigDir/req.1" 'WAIT-NEVER-READ' ):0:$(( $( rigCount "$rigDir/req.1" 'WAIT-RESULT: TIMEOUT' ) + 1 ))"
rigAssert "the run with a scan says the floor and the scan"                               "$( rigIn "$( cat "$rigTmp/to-armed/err" )" 'waiting on the floor and scan:grooming' )" yes

echo "-- 6. a wait that could not be made, and a session that is dismissed --"
rigScene dismissed rigduty
mkdir -p "$rigStore" ; printf 'rig-boss\n' > "$rigStore/dismissed"
rigToolStream "$rigDir/res.1" Bash "$( rigOp --idle-wait )"
rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
rigAssert "a dismissal is not an arrival: the conversation stays and the model reads it"   "$( rigCount "$rigDir/req.2" 'toolu_RIG0' ):$( rigIn "$( cat "$rigDir/req.2" )" 'WAIT-RESULT: DISMISSED' ):$( rigIn "$( cat "$rigDir/req.2" )" 'you are dismissed' )" 2:yes:yes
rigAssert "and the arrival of the scan is not shown with it"                              "$( rigCount "$rigDir/req.2" 'WAIT-RESULT: DISMISSED' ):$( rigCount "$rigDir/req.2" "$rigArrival" )" 1:0

echo "-- 7. a run that holds no snapshot --"
rigScene nosnap rigduty
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-exit )"
rigToolStream "$rigDir/res.2" Bash "$( rigOp --idle-wait --wait-timeout 5 )"
rigTextStream "$rigDir/res.3" RIG-DONE ; rigRun
rigAssert "the arrival comes as a message; the conversation holds the calls before it"    "$( rigCount "$rigDir/req.3" "$rigArrival" ):$( rigCount "$rigDir/req.3" '"type":"tool_result"' )" 1:2
rigAssert "and the model is told no snapshot is held and nothing was returned"            "$( rigIn "$( cat "$rigDir/req.3" )" 'no snapshot is held' ):$( rigIn "$( cat "$rigDir/req.3" )" 'not returned' )" yes:yes
rigAssert "an arrival with no conversation returned is a wake too: the cache line of round 1 is printed again after it (10)" "$( rigCount "$rigDir/err" 'shared prefix -- round 1 ' )" 2

echo "-- 8. a quiet round does not wake the model --"
rigScene loop rigquiet
printf 'WAIT_ROUND_SECONDS=2\n' > "$rigWs/.local/.agents/magic-team.agent.env"
( sleep 9 ; mkdir -p "$rigStore" ; printf 'rig-boss\n' > "$rigStore/dismissed" ) &
rigLater=$!
rigToolStream "$rigDir/res.1" Bash "$( rigOp --idle-wait )"
rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
wait "$rigLater" 2> /dev/null
rigAssert "the wait comes back quiet every round of the service (2s here), the harness waits on, and the model is woken once"    "$rigRunStatus:$( cat "$rigDir/round" ):$( [ "$( rigCount "$rigDir/err" 'nothing yet, still waiting' )" -ge 1 ] && printf waited || printf 'not-waited' )" 0:2:waited
rigAssert "the quiet rounds are not in the conversation; the dismissal that ended the wait is"                                   "$(( $( rigCount "$rigDir/req.2" 'WAIT-RESULT: TIMEOUT' ) - $( rigCount "$rigDir/req.1" 'WAIT-RESULT: TIMEOUT' ) )):$( rigCount "$rigDir/req.2" 'WAIT-RESULT: DISMISSED' ):$( rigCount "$rigDir/req.2" 'toolu_RIG0' )" 0:1:2

echo "-- 9. the first idle-wait does not wake on the report the spawner already gave --"
rigScene seeded rigduty
## The spawner's own run of the scan (AgentsToolsInputScanDefRun), for this member and this session, as it makes it at a start, acting as
## the member (a scan's text can depend on who runs it: grooming's roster section is the coordinator's). A scan's first run in a
## workspace stores what it keeps: the rig runs it once to settle that, and the run the run is given is the second, so the world between
## the spawner's run and the wait is the one that is quiet.
cat > "$rigTmp/spawner-run.sh" << 'RIG_SPAWNER_RUN'
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.InputScanDef.include"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include"
DistroAgentsTools(){ bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ; }
AgentsToolsInputScanDefRun "grooming" rig-a "$RIG_SESSION" "$RIG_SESSION" "$RIG_OUT"
RIG_SPAWNER_RUN
for rigPass in settle given ; do
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=rig-a RIG_SESSION="$rigSpawn" RIG_OUT="$rigDir/input-scan.md" bash "$rigTmp/spawner-run.sh" ) > "$rigDir/spawner.out" 2> "$rigDir/spawner.err"
done
rigAssert "control: the spawner gave the run the scan's report, and kept its pointer"          "$( LC_ALL=C grep -c -F "$rigArrival" "$rigDir/input-scan.md" ):$( LC_ALL=C grep -c '^scan:grooming:rig-a' "$rigWs/.local/agents/sessions/$rigSpawn/session.chat.pointers" 2> /dev/null )" 1:1
rigToolStream "$rigDir/res.1" Bash "$( rigOp --idle-wait --wait-timeout 3 )"
rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
rigAssert "the first idle-wait finds nothing new: it ends quiet, and the model is told so"     "$rigRunStatus:$( cat "$rigDir/round" ):$( rigIn "$( cat "$rigDir/req.2" )" 'ended with no arrival' )" 0:2:yes
rigAssert "the report already given did not wake it: no arrival, nothing returned"             "$( rigCount "$rigDir/req.2" "$rigArrival" ):$( rigCount "$rigDir/req.2" 'toolu_RIG0' ):$( rigCount "$rigDir/req.2" 'OK: --idle-wait' )" 0:2:1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS IDLE WAIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_IDLE_WAIT: OK (%d assertions, offline)\n' "$rigPassCount"
