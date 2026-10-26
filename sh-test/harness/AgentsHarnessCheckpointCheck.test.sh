#!/usr/bin/env bash
## Behavioural check on snapshot and rewind of the model path (F10.5 of the refactorings epic), run through the real core and the
## Anthropic Messages wire against a fake `curl` replaying canned streams, which records each request body, and through the real
## ThisSession operations (DistroAgentsSession.fn.sh --executor-checkpoint-push, -rewind and -exit) that the model's own Bash calls make.
## A snapshot is a name for the conversation at a turn boundary; a rewind puts the conversation back to it, so the request that follows
## is BYTE FOR BYTE the one that was sent at that point -- the prefix the input token cache holds. Held:
##   1. push, work, rewind: the request after the rewind is the request after the push, and the file the work wrote is still there
##   2. the tooling's own `armed` snapshot of a prefetched run (F10.8) is the system text and the first message with no task changed: a
##      rewind to it makes the next request the very first one, byte for byte
##   3. a run that was not prefetched is armed by its read, and `armed` is the end of the round of that read
##   4. a snapshot asked for in a round of two calls is made after BOTH have their results, so a rewind never leaves a call without one
##   5. the stack: a rewind to a name drops the snapshots after it (a later rewind to one is refused, in the call's own answer);
##      `exit` drops all; a name held again replaces the older
##   6. a new leg of the kept context is opened by a rewind, and the transcript is told
##   7. where the routine does not allow the operations they take no snapshot, say so and the run goes on
##   8. the include's own refusal of a snapshot in the middle of a round, and of a name that is not bare
## Offline by construction: no socket, no credential.
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
rigTmp="$( rigTempDir AgentsHarnessCheckpointCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home"
cp "$rigTest/check-fixtures/harness-mcp-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
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
rigSame(){ ## two files -- same or differs
	cmp -s "$1" "$2" 2> /dev/null && printf same || printf differs
}
rigCount(){ ## file, text -- how many times the file holds the text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C grep -o -F -- "$2" "$1" | wc -l | tr -d ' '
}

## The skillset of the rig: the team's files with the standalone kind routine, a member, and two routines of one participant -- one that
## allows the three operations, one that allows nothing.
rigSkills="$rigTmp/skills"
mkdir -p "$rigSkills/magic-team" "$rigSkills/rig-a"
printf 'RIG-TEAM-COMMON-LINE one two\n' > "$rigSkills/magic-team/magic-team.basic.md"
printf '# Nothing stops on its own\n\nRIG-TEAM-SECTION\n' > "$rigSkills/magic-team/magic-team.armed.md"
printf -- '---\nname: magic-team\n---\nteam skill\n' > "$rigSkills/magic-team/SKILL.md"
cp "$rigKind" "$rigSkills/magic-team/" || rigRefuse "the standalone routine could not be copied into the rig"
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigSkills/rig-a/rig-a.basic.md"
printf -- '---\nstatus: rig\n---\nRIG-A-ARMED-BODY\n' > "$rigSkills/rig-a/rig-a.armed.md"
printf -- '---\nname: rig-a\n---\nmember skill\n' > "$rigSkills/rig-a/SKILL.md"
rigRoutine(){ ## short name, allows value
	{
		printf -- '---\ntype: routine\nexecutors: rig-a\nmaintainers: magic-coordinator\ninvitees: none\nrequires-session-kind: standalone\n'
		[ -z "$2" ] || printf 'allows: %s\n' "$2"
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **rig-open**: open.\n\n# Steps\n\n1. **rig-work**: work.\n\n# Closure steps\n\n1. **rig-close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-team/magic-team.$1.routine.md"
}
rigRoutine rigsolo 'executors:--executor-checkpoint-push,executors:--executor-checkpoint-rewind,executors:--executor-checkpoint-exit'
rigRoutine rigdeny ''

rigSpawn="rig-spawn-cp"
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
rigWorkJson(){ ## file name -- the Write call that makes a file of the run's own
	printf '{"file_path":"%s/%s","content":"RIG-WORK"}' "$rigDir" "$1"
}
rigPrefetch="on"
rigRun(){ ## further harness arguments
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_SESSION_ID="$rigSpawn" MDAT_SPAWN_AGENT=rig-a MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" MDAT_HARNESS_PREFETCH="$rigPrefetch" RIG_SCENARIO="$rigDir" \
		HARNESS_PROVIDER_NAME="checkpoint rig" HARNESS_SELF_NAME="AgentsHarnessCheckpointCheck.test.sh" HARNESS_WIRE="AnthropicMessages" HARNESS_CREDENTIAL_NAMES="none" \
		HARNESS_ENDPOINT="https://harness-checkpoint.invalid/v1/messages" HARNESS_HOST="harness-checkpoint.invalid" HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01" \
		HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
		HARNESS_OUTPUT_TOKENS_LIGHT="4101" HARNESS_OUTPUT_TOKENS_MAIN="4202" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
		bash "$rigHarness" --agent rig-a --access-root "$rigDir" "$@" RIG-TASK-MARKER ) > "$rigDir/out" 2> "$rigDir/err"
	rigRunStatus=$?
	[ "$( cat "$rigDir/round" )" != 0 ] || rigRefuse "the harness issued no request at all -- its stderr: $( head -5 "$rigDir/err" )"
}
rigHeld(){ ## the names of the snapshots the run's store holds, in order, space-joined
	LC_ALL=C awk -F '\t' 'NF { printf "%s%s", sep, $1 ; sep = " " }' "$rigStore/snapshots" 2> /dev/null
}

echo "-- 1. push, work, rewind: the request after the rewind is the request after the push --"
rigScene push-rewind rigsolo
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-push opening )"
rigToolStream "$rigDir/res.2" Write "$( rigWorkJson work.txt )"
rigToolStream "$rigDir/res.3" Bash "$( rigOp --executor-checkpoint-rewind opening )"
rigTextStream "$rigDir/res.4" RIG-DONE ; rigRun
rigAssert "the run ends normally, in four requests"                                      "$rigRunStatus:$( cat "$rigDir/round" )" 0:4
rigAssert "the push is answered at once, to be made at the end of the round"             "$( rigIn "$( cat "$rigDir/req.2" )" 'the snapshot opening is made at the end of this round' )" yes
rigAssert "the snapshots are held in the run's store: the tooling's armed, then opening"  "$( rigHeld )" "armed opening"
rigAssert "the request after the rewind is the request after the push, byte for byte"    "$( rigSame "$rigDir/req.2" "$rigDir/req.4" )" same
rigAssert "the work between is not in the conversation any more"                         "$( rigCount "$rigDir/req.3" 'RIG-WORK' ):$( rigCount "$rigDir/req.4" 'RIG-WORK' )" 1:0
rigAssert "but the file it wrote is still there: only the conversation returns"           "$( cat "$rigDir/work.txt" 2> /dev/null )" RIG-WORK
rigAssert "the run says what it did"                                                     "$( rigIn "$( cat "$rigDir/err" )" 'snapshot opening -- count, 3 message(s)' ):$( rigIn "$( cat "$rigDir/err" )" 'rewound' )" yes:yes
rigAssert "the first request holds the prefetch block, so the armed snapshot is the init kind"  "$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' ):$( LC_ALL=C awk -F '\t' '$1 == "armed" { print $2 ":" $3 }' "$rigStore/snapshots" )" 1:init:0

echo "-- 2. a rewind to armed: the very first request again --"
rigScene to-armed rigsolo
rigToolStream "$rigDir/res.1" Write "$( rigWorkJson one.txt )"
rigToolStream "$rigDir/res.2" Bash "$( rigOp --executor-checkpoint-rewind armed )"
rigTextStream "$rigDir/res.3" RIG-DONE ; rigRun
rigAssert "the request after the rewind to armed is the first request, byte for byte"    "$( rigSame "$rigDir/req.1" "$rigDir/req.3" )" same
rigAssert "so the prefetch block, and the cache marker at its end, are in it as they were"  "$( rigCount "$rigDir/req.3" 'RIG-A-ARMED-BODY' ):$( rigCount "$rigDir/req.3" '"cache_control":{"type":"ephemeral"}' )" 1:3
rigAssert "the work is gone from it"                                                     "$( rigCount "$rigDir/req.3" 'RIG-WORK' ):$( rigCount "$rigDir/req.3" 'toolu_RIG' )" 0:0

echo "-- 3. a run that was not prefetched is armed by its read --"
rigPrefetch="off" ; rigScene read-armed rigsolo
rigToolStream "$rigDir/res.1" Skill '{"name":"rig-a","file":"rig-a.armed.md"}'
rigToolStream "$rigDir/res.2" Write "$( rigWorkJson two.txt )"
rigToolStream "$rigDir/res.3" Bash "$( rigOp --executor-checkpoint-rewind armed )"
rigTextStream "$rigDir/res.4" RIG-DONE ; rigRun ; rigPrefetch="on"
rigAssert "armed is the end of the round of the read: count kind, three messages"         "$( LC_ALL=C awk -F '\t' '$1 == "armed" { print $2 ":" $3 }' "$rigStore/snapshots" )" count:3
rigAssert "the request after the rewind is the request after the read, byte for byte"    "$( rigSame "$rigDir/req.2" "$rigDir/req.4" )" same

echo "-- 4. a snapshot asked in a round of two calls is made after both have their results --"
rigScene two-calls rigsolo
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-push both )" Write "$( rigWorkJson both.txt )"
rigToolStream "$rigDir/res.2" Write "$( rigWorkJson later.txt )"
rigToolStream "$rigDir/res.3" Bash "$( rigOp --executor-checkpoint-rewind both )"
rigTextStream "$rigDir/res.4" RIG-DONE ; rigRun
rigAssert "the snapshot holds the first message, the turn and both results: four messages"  "$( LC_ALL=C awk -F '\t' '$1 == "both" { print $3 }' "$rigStore/snapshots" )" 4
rigAssert "the request after the push holds both results"                                "$( rigCount "$rigDir/req.2" '"type":"tool_result"' )" 2
rigAssert "and the request after the rewind is that request, byte for byte"              "$( rigSame "$rigDir/req.2" "$rigDir/req.4" )" same

echo "-- 5. the stack --"
rigScene stack rigsolo
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-push a )"
rigToolStream "$rigDir/res.2" Bash "$( rigOp --executor-checkpoint-push b )"
rigToolStream "$rigDir/res.3" Bash "$( rigOp --executor-checkpoint-rewind a )"
rigToolStream "$rigDir/res.4" Bash "$( rigOp --executor-checkpoint-rewind b )"
rigTextStream "$rigDir/res.5" RIG-DONE ; rigRun
rigAssert "a rewind to a drops b: the run holds armed and a"                              "$( rigHeld )" "armed a"
rigAssert "a rewind to b is then refused in the call's own answer, naming what is held"   "$( rigIn "$( cat "$rigDir/req.5" )" "no snapshot named 'b' -- this run holds: armed a" )" yes
rigScene replace rigsolo
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-push a )"
rigToolStream "$rigDir/res.2" Bash "$( rigOp --executor-checkpoint-push b )"
rigToolStream "$rigDir/res.3" Bash "$( rigOp --executor-checkpoint-push a )"
rigTextStream "$rigDir/res.4" RIG-DONE ; rigRun
rigAssert "a name held again replaces the older one, and goes to the top"                "$( rigHeld ):$( LC_ALL=C awk -F '\t' '$1 == "a" { print $3 }' "$rigStore/snapshots" )" "armed b a:7"
rigScene exit rigsolo
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-push a )"
rigToolStream "$rigDir/res.2" Bash "$( rigOp --executor-checkpoint-exit )"
rigToolStream "$rigDir/res.3" Bash "$( rigOp --executor-checkpoint-rewind a )"
rigTextStream "$rigDir/res.4" RIG-DONE ; rigRun
rigAssert "exit drops all of them, the tooling's armed too"                              "$( rigHeld ):$( [ -s "$rigStore/snapshots" ] && printf held || printf empty )" ":empty"
rigAssert "and a rewind after it is refused: the run holds none"                         "$( rigIn "$( cat "$rigDir/req.4" )" 'this run holds no snapshot to return to' )" yes

echo "-- 6. the kept context and the transcript --"
rigScene leg rigsolo
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-push opening )"
rigToolStream "$rigDir/res.2" Bash "$( rigOp --executor-checkpoint-rewind opening )"
rigTextStream "$rigDir/res.3" RIG-DONE ; rigRun
rigAssert "the rewind opens a second leg of the kept context, as a restart does"         "$( LC_ALL=C grep -c '"type":"context"' "$rigSandbox/context.jsonl" 2> /dev/null ):$( LC_ALL=C grep '"type":"context"' "$rigSandbox/context.jsonl" 2> /dev/null | LC_ALL=C grep -c '"leg":2,' )" "1:1"

echo "-- 7. where the routine does not allow them --"
rigScene denied rigdeny
rigToolStream "$rigDir/res.1" Bash "$( rigOp --executor-checkpoint-push opening )"
rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
rigAssert "no snapshot, a NOTICE in the answer, the run goes on"                         "$( rigHeld ):$( rigIn "$( cat "$rigDir/req.2" )" 'NOTICE: --executor-checkpoint-push: no checkpoint was made' ):$rigRunStatus" "armed:yes:0"

echo "-- 8. the include alone: a boundary, and a bare name --"
rigUnit(){ ## messages as arguments (records), then the call to make -- the include with the harness's own words stubbed
	env -i PATH="/usr/bin:/bin" bash -c '
		harnessWarn="" harnessOff="" harnessDim="" harnessSelfName=unit harnessMcpToolsJson="" harnessSystemText="s"
		AgentsHarnessBareName(){ case "$1" in ""|*[!A-Za-z0-9._-]*) return 1 ;; esac ; return 0 ; }
		AgentsHarnessContextBegin(){ :; } ; AgentsTranscriptHarnessRewind(){ :; } ; AgentsWireUserRecord(){ printf "{\"role\":\"user\",\"content\":\"%s\"}" "$1" ; } ; AgentsWireInitMessages(){ harnessMessages=( "{\"role\":\"user\",\"content\":\"init\"}" ) ; }
		. "$1" ; shift
		harnessCheckpointDir="$1" ; shift
		eval "$1"' unit "$rigHere/harness/AgentsHarnessCheckpoint.include" "$rigTmp/unit-store" "$1" 2> /dev/null
}
mkdir -p "$rigTmp/unit-store"
rigAssert "an assistant record that still waits for its results is no boundary"        "$( rigUnit 'harnessMessages=( "{\"role\":\"user\",\"content\":\"t\"}" "{\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"id\":\"x\"}]}" ) ; AgentsHarnessCheckpointBoundary && printf yes || printf no' )" no
rigAssert "the results answering them make one"                                        "$( rigUnit 'harnessMessages=( "{\"role\":\"user\",\"content\":\"t\"}" "{\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"id\":\"x\"}]}" "{\"role\":\"user\",\"content\":[{\"type\":\"tool_result\"}]}" ) ; AgentsHarnessCheckpointBoundary && printf yes || printf no' )" yes
rigAssert "the chat wire says it in tool_calls, and the same holds"                    "$( rigUnit 'harnessMessages=( "{\"role\":\"user\",\"content\":\"t\"}" "{\"role\":\"assistant\",\"content\":null,\"tool_calls\":[{\"id\":\"x\"}]}" ) ; AgentsHarnessCheckpointBoundary && printf yes || printf no' )" no
rigAssert "a snapshot in the middle of a round is not taken"                            "$( rigUnit 'harnessMessages=( "{\"role\":\"user\",\"content\":\"t\"}" "{\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"id\":\"x\"}]}" ) ; AgentsHarnessSnapshotTake mid count && printf taken || printf refused' )" refused
rigAssert "a name that is not bare is not taken"                                        "$( rigUnit 'harnessMessages=( "{\"role\":\"user\",\"content\":\"t\"}" ) ; AgentsHarnessSnapshotTake "a b" count && printf taken || printf refused' )" refused
rigAssert "a snapshot at a boundary is, and is held"                                    "$( rigUnit 'harnessMessages=( "{\"role\":\"user\",\"content\":\"t\"}" ) ; AgentsHarnessSnapshotTake ok count && printf taken || printf refused' ):$( cut -f 1,2,3 "$rigTmp/unit-store/snapshots" | tr '\t' ' ' )" "taken:ok count 1"
rigAssert "a rewind to a name nobody holds does nothing"                                "$( rigUnit 'harnessMessages=( "{\"role\":\"user\",\"content\":\"t\"}" "{\"role\":\"user\",\"content\":\"u\"}" ) ; AgentsHarnessRewindTo nosuch "" && printf done || printf refused ; printf " %s" "${#harnessMessages[@]}"' )" "refused 2"
rigAssert "a rewind to a count snapshot cuts the array and adds the input given"        "$( rigUnit 'harnessMessages=( "{\"role\":\"user\",\"content\":\"t\"}" ) ; AgentsHarnessSnapshotTake k count ; harnessMessages+=( "{\"role\":\"assistant\",\"content\":\"x\"}" "{\"role\":\"user\",\"content\":\"y\"}" ) ; AgentsHarnessRewindTo k "NEW" && printf "%s|%s" "${#harnessMessages[@]}" "${harnessMessages[1]}"' )" '2|{"role":"user","content":"NEW"}'

echo "-- 9. the input of a return, the wait, and the names held (F10.5 gate B), the include alone --"
rigInitSeen(){ ## the calls to make, after a task of T held and an init snapshot of the armed state -- the task block each init render was given, | for a newline
	rigUnit 'harnessPrompt=T ; harnessCheckpointTask=T ; harnessMessages=( "{\"role\":\"user\",\"content\":\"init\"}" ) ; AgentsWireInitMessages(){ printf "%s\n" "$harnessPrompt" | tr "\n" "|" >> "'"$rigTmp"'/init-seen" ; printf ";" >> "'"$rigTmp"'/init-seen" ; harnessMessages=( "x" ) ; } ; AgentsHarnessSnapshotTake armed init ; '"$1"
	cat "$rigTmp/init-seen"; rm -f "$rigTmp/init-seen"
}
rigAssert "a return to the init kind with an input: the task block is the task, a blank line, the input"  "$( rigInitSeen 'AgentsHarnessRewindTo armed ONE' )" 'T||ONE|;'
rigAssert "a second return carries its own input, and not the first's"                                   "$( rigInitSeen 'AgentsHarnessRewindTo armed ONE ; AgentsHarnessRewindTo armed TWO' )" 'T||ONE|;T||TWO|;'
rigAssert "a return with no input restores the task as it was started"                                   "$( rigInitSeen 'AgentsHarnessRewindTo armed ONE ; AgentsHarnessRewindTo armed ""' )" 'T||ONE|;T|;'
rigCode='harnessMessages=( "{\"role\":\"user\",\"content\":\"t\"}" ) ; AgentsHarnessSnapshotTake opening count ; AgentsHarnessSnapshotHeld opening && printf Y || printf n ; AgentsHarnessSnapshotHeld open && printf Y || printf n ; AgentsHarnessSnapshotHeld opening2 && printf Y || printf n ; AgentsHarnessSnapshotHeld armed && printf Y || printf n'
rigAssert "a name is held when the stack has it, and a name that only begins like it is not"             "$( rigUnit "$rigCode" )" 'Ynnn'
rigRound(){ ## the requests, one a line (\n escapes), then the calls -- Round over a store with a request file, the wait stubbed to log what it was asked
	rm -rf "$rigTmp/round-store" ; mkdir -p "$rigTmp/round-store" ; printf "$1" > "$rigTmp/round-store/checkpoint.request"
	shift
	[ -z "${rigDispatch:-}" ] || printf '%s\n' "$rigDispatch" > "$rigTmp/round-store/checkpoint.dispatch"
	rigUnit 'harnessMessages=( "{\"role\":\"user\",\"content\":\"t\"}" ) ; harnessCheckpointDir="'"$rigTmp"'/round-store" ; AgentsHarnessIdleWait(){ printf "idle[%s] " "$*" >> "'"$rigTmp"'/round-log" ; } ; '"$1"
	cat "$rigTmp/round-log" 2> /dev/null ; rm -f "$rigTmp/round-log"
}
rigAssert "an idle request is handed to the wait with its timeout and sources, as words"                 "$( rigRound 'idle 30 scan:a scan:b\n' 'AgentsHarnessCheckpointRound' )" 'idle[30 scan:a scan:b] '
rigAssert "with no timeout the word is -, and a request after an idle one is dropped"                    "$( rigRound 'idle -\npush later\n' 'AgentsHarnessCheckpointRound ; AgentsHarnessSnapshotHeld later && printf "held " || printf "dropped "' )" 'dropped idle[-] '
rigAssert "a request before it is made first"                                                           "$( rigRound 'push first\nidle -\n' 'AgentsHarnessCheckpointRound ; AgentsHarnessSnapshotHeld first && printf "held " || printf "dropped "' )" 'held idle[-] '
rigAssert "the request file is spent by the round"                                                      "$( rigRound 'idle -\n' 'AgentsHarnessCheckpointRound ; ls "'"$rigTmp"'/round-store" | tr "\n" " "' )" 'idle[-] '
rigDispatch="DISPATCH-TEXT"
rigAssert "a rewind takes the dispatch the executor gave, whole, and spends the file"                   "$( rigRound 'push k\nrewind k\n' 'AgentsHarnessCheckpointRound ; printf "%s|" "${harnessMessages[1]}" ; [ -e "'"$rigTmp"'/round-store/checkpoint.dispatch" ] && printf kept || printf spent' )" '{"role":"user","content":"DISPATCH-TEXT"}|spent'
unset rigDispatch
rigIdle(){ ## what the Wait says (a line each, | between), then the calls to make -- the idle wait over stubs: the Wait logs the sources and bound it was asked, the reply layer marks what passes it
	rigUnit 'harnessMessages=( "{\"role\":\"user\",\"content\":\"t\"}" ) ; harnessPrompt=T ; harnessCheckpointTask=T
		AgentsHarnessToolWait(){ printf "ask[%s;%s;%s] " "$1" "$2" "$7" >> "'"$rigTmp"'/idle-log" ; printf "%s\n" "'"$1"'" | tr "|" "\n" ; }
		AgentsHarnessReply(){ harnessReply="REPLY<$1:$( printf "%s" "$2" | tr "\n" "|" )>" ; }
		AgentsHarnessSessionKey(){ printf k ; }
		AgentsWireInitMessages(){ harnessMessages=( "{\"role\":\"user\",\"content\":\"init:$( printf "%s" "$harnessPrompt" | tr "\n" "|" )\"}" ) ; }
		'"$2"'
		printf "%s" "${harnessMessages[$(( ${#harnessMessages[@]} - 1 ))]}" | tr "\n" "|"'
	cat "$rigTmp/idle-log" 2> /dev/null ; rm -f "$rigTmp/idle-log"
}
rigGot='WAIT-RESULT: RECEIVED|# arrived on: scan:a|a report|NEXT: call Wait mode=continue'
rigAssert "an arrival with a checkpoint held: the run returns to it with the arrival, through the reply layer, the Wait's own next step left out"  "$( rigIdle "$rigGot" 'AgentsHarnessSnapshotTake opening count ; harnessMessages+=( "x" "y" ) ; AgentsHarnessIdleWait - scan:a' )" '{"role":"user","content":"Your --idle-wait returned: something arrived while this run was idle. The conversation is returned to its checkpoint opening, so none of the work after it is in front of you; the files, and everything outside the conversation, are as that work left them. What arrived:||REPLY<Wait:WAIT-RESULT: RECEIVED|# arrived on: scan:a|a report>"}ask[scan:a;;default] '
rigGotMid='WAIT-RESULT: RECEIVED|a line|NEXT: inside the report|more report|NEXT: call Wait mode=continue'
rigAssert "only the Wait's own last line is left off: a line of the report that begins alike stays"                                           "$( rigIdle "$rigGotMid" 'AgentsHarnessIdleWait - scan:a' | LC_ALL=C sed 's/.*What arrived:/What arrived:/' )" 'What arrived:||REPLY<Wait:WAIT-RESULT: RECEIVED|a line|NEXT: inside the report|more report>"}ask[scan:a;;default] '
rigAssert "opening is the checkpoint where the run holds both; the work after it is dropped"                                                    "$( rigIdle "$rigGot" 'AgentsHarnessSnapshotTake armed count ; AgentsHarnessSnapshotTake opening count ; harnessMessages+=( "x" ) ; AgentsHarnessSnapshotTake later count ; harnessMessages+=( "y" ) ; AgentsHarnessIdleWait - scan:a ; printf "%s:" "${#harnessMessages[@]}"' )" '2:{"role":"user","content":"Your --idle-wait returned: something arrived while this run was idle. The conversation is returned to its checkpoint opening, so none of the work after it is in front of you; the files, and everything outside the conversation, are as that work left them. What arrived:||REPLY<Wait:WAIT-RESULT: RECEIVED|# arrived on: scan:a|a report>"}ask[scan:a;;default] '
rigAssert "only armed, of the init kind: the task block is the task, a blank line and the arrival"                                              "$( rigIn "$( rigIdle "$rigGot" 'AgentsHarnessSnapshotTake armed init ; harnessMessages+=( "x" ) ; AgentsHarnessIdleWait 30 scan:a' )" '{"role":"user","content":"init:T||Your --idle-wait returned: something arrived' )" yes
rigAssert "the bound is the Wait's, - being none; the sources named are asked as they are"                                                    "$( rigIdle "$rigGot" 'AgentsHarnessSnapshotTake armed init ; AgentsHarnessIdleWait 30 scan:a scan:b' | LC_ALL=C sed 's/.*}ask/ask/' )" 'ask[scan:a scan:b;30;default] '
rigAssert "no scan: the floor is named, as the one source (not the defaults of a bare Wait)"                                                  "$( rigIdle "$rigGot" 'AgentsHarnessSnapshotTake armed init ; AgentsHarnessIdleWait -' | LC_ALL=C sed 's/.*}ask/ask/' )" 'ask[chat:k;;default] '
rigAssert "an arrival with no snapshot held: a message, and the conversation stays"                                                           "$( rigIdle "$rigGot" 'harnessMessages+=( "x" ) ; AgentsHarnessIdleWait - scan:a ; printf "%s:" "${#harnessMessages[@]}"' )" '3:{"role":"user","content":"Something arrived while this run was idle, and no snapshot is held, so your conversation was not returned. What arrived:||REPLY<Wait:WAIT-RESULT: RECEIVED|# arrived on: scan:a|a report>"}ask[scan:a;;default] '
rigAssert "a TIMEOUT returns nothing: the model is told, and how to wait on"                                                                   "$( rigIdle 'WAIT-RESULT: TIMEOUT (5s) NEXT: Wait mode=continue' 'AgentsHarnessSnapshotTake armed init ; AgentsHarnessIdleWait 5 scan:a ; printf "%s:" "${#harnessMessages[@]}"' | LC_ALL=C sed 's/ask\[.*//' )" '2:{"role":"user","content":"Your --idle-wait ended with no arrival, and your conversation was not returned. Call --idle-wait again to keep waiting.||WAIT-RESULT: TIMEOUT (5s)"}'
rigAssert "a dismissal returns nothing, and is given as it came"                                                                              "$( rigIdle 'WAIT-RESULT: DISMISSED|WAIT-DISMISSED-BY: boss|NEXT: you are dismissed' 'AgentsHarnessSnapshotTake armed init ; AgentsHarnessIdleWait - ; printf "%s:" "${#harnessMessages[@]}"' | LC_ALL=C sed 's/ask\[.*//' )" '2:{"role":"user","content":"Your --idle-wait ended on a dismissal, and your conversation was not returned.||WAIT-RESULT: DISMISSED|WAIT-DISMISSED-BY: boss|NEXT: you are dismissed"}'
rigAssert "a wait that could not be made returns nothing, and says what it said"                                                              "$( rigIdle 'WAIT-RESULT: ERROR|no such source' 'AgentsHarnessSnapshotTake armed init ; AgentsHarnessIdleWait - ; printf "%s:" "${#harnessMessages[@]}"' | LC_ALL=C sed 's/ask\[.*//' )" '2:{"role":"user","content":"Your --idle-wait could not be made, and your conversation was not returned. What the wait said:||WAIT-RESULT: ERROR|no such source"}'
rigIdleSeq(){ ## the Wait's first answer, its second (| between the lines), the calls to make -- as rigIdle, the Wait answering a first call, then every next
	rm -f "$rigTmp/idle-count"
	rigUnit 'harnessMessages=( "{\"role\":\"user\",\"content\":\"t\"}" ) ; harnessPrompt=T ; harnessCheckpointTask=T ; sleep(){ :; }
		AgentsHarnessToolWait(){ local n=$( cat "'"$rigTmp"'/idle-count" 2> /dev/null || printf 0 ) ; n=$(( n + 1 )) ; printf "%s" "$n" > "'"$rigTmp"'/idle-count" ; printf "ask[%s;%s;%s] " "$1" "$2" "$7" >> "'"$rigTmp"'/idle-log" ; if [ "$n" = 1 ] ; then printf "%s\n" "'"$1"'" | tr "|" "\n" ; else printf "%s\n" "'"$2"'" | tr "|" "\n" ; fi ; }
		AgentsHarnessReply(){ harnessReply="REPLY<$1:$( printf "%s" "$2" | tr "\n" "|" )>" ; }
		AgentsHarnessSessionKey(){ printf k ; }
		AgentsWireInitMessages(){ harnessMessages=( "{\"role\":\"user\",\"content\":\"init:$( printf "%s" "$harnessPrompt" | tr "\n" "|" )\"}" ) ; }
		'"$3"'
		printf "%s:%s" "${#harnessMessages[@]}" "$( printf "%s" "${harnessMessages[$(( ${#harnessMessages[@]} - 1 ))]}" | tr "\n" "|" | cut -c1-60 )"'
	cat "$rigTmp/idle-log" 2> /dev/null ; rm -f "$rigTmp/idle-log" "$rigTmp/idle-count"
}
rigQuiet='WAIT-RESULT: TIMEOUT (270s) NEXT: Wait mode=continue'
rigAssert "a quiet round with no bound named wakes the model with a keepalive, returned to the armed checkpoint"  "$( rigIdleSeq "$rigQuiet" "$rigGot" 'AgentsHarnessSnapshotTake armed init ; AgentsHarnessIdleWait - scan:a' | cut -c1-140 )" '1:{"role":"user","content":"init:T||Your --idle-wait made its ask[scan:a;;default] '
rigAssert "a bound named by the call is the call's: a quiet round ends it, and the model is told"                          "$( rigIdleSeq "$rigQuiet" "$rigGot" 'AgentsHarnessSnapshotTake armed init ; AgentsHarnessIdleWait 5 scan:a' | cut -c1-120 )" '2:{"role":"user","content":"Your --idle-wait ended with no arrask[scan:a;5;default] '
rigAssert "so is a quiet round that holds a source never read, whose silence means nothing"                              "$( rigIdleSeq "$rigQuiet|WAIT-NEVER-READ: [slack:x]" "$rigGot" 'AgentsHarnessSnapshotTake armed init ; AgentsHarnessIdleWait - scan:a' | cut -c1-120 )" '2:{"role":"user","content":"Your --idle-wait ended with no arrask[scan:a;;default] '
rigAssert "and a bound set for the run (MDAT_HARNESS_WAIT_TIMEOUT) ends it too"                                           "$( rigIdleSeq "$rigQuiet" "$rigGot" 'harnessWaitTimeout=60 ; AgentsHarnessSnapshotTake armed init ; AgentsHarnessIdleWait - scan:a' | cut -c1-120 )" '2:{"role":"user","content":"Your --idle-wait ended with no arrask[scan:a;;default] '
rigAssert "a dismissal after a keepalive round is the model's to read, and the conversation is not returned"  "$( rigIdleSeq 'WAIT-RESULT: DISMISSED|NEXT: end' "$rigGot" 'AgentsHarnessSnapshotTake armed init ; AgentsHarnessIdleWait - scan:a' | cut -c1-120 )" '2:{"role":"user","content":"Your --idle-wait ended on a dismisask[scan:a;;default] '

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS CHECKPOINT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_CHECKPOINT: OK (%d assertions, offline)\n' "$rigPassCount"
