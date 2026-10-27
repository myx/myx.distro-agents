#!/usr/bin/env bash
## Behavioural check on a work-duty that answers in plain text, run rather than read: A WORK-DUTY IS ONE SESSION, AND ONLY A DISMISSAL ENDS IT.
## A reply with no tool call ends a harness run (AgentsUniversalHarness.sh), and a work-duty's model gives one whenever it thinks it is done.
## Each such end made the schedule start the duty again, as a new session with a new header in the team channel.
## Held: a work-duty's plain-text reply does not end the run: the harness makes the idle-wait itself, rewinds to the checkpoint where one is held,
## and the model is asked again; a dismissal ends it as before (AgentsHarnessIdleWaitCheck holds that). A run that is not a work-duty ends on its plain-text reply, as it always did.
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
rigTmp="$( rigTempDir AgentsHarnessDutyNoQuitCheck )" || exit 1
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
		printf 'access-control: executors:allow-tool:--executor-checkpoint-push,executors:allow-tool:--executor-checkpoint-rewind,executors:allow-tool:--executor-checkpoint-exit\n'
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
		HARNESS_PROVIDER_NAME="idle-wait rig" HARNESS_SELF_NAME="AgentsHarnessDutyNoQuitCheck.test.sh" HARNESS_WIRE="AnthropicMessages" HARNESS_CREDENTIAL_NAMES="none" \
		HARNESS_ENDPOINT="https://harness-idle-wait.invalid/v1/messages" HARNESS_HOST="harness-idle-wait.invalid" HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01" \
		HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
		HARNESS_OUTPUT_TOKENS_LIGHT="4101" HARNESS_OUTPUT_TOKENS_MAIN="4202" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 MDAT_HARNESS_WAIT_TIMEOUT="${rigWaitTimeout:-}" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 240 -- bash "$rigHarness" --agent rig-a --access-root "$rigDir" "$@" RIG-TASK-MARKER ) > "$rigDir/out" 2> "$rigDir/err"
	rigRunStatus=$?
	[ "$( cat "$rigDir/round" )" != 0 ] || rigRefuse "the harness issued no request at all -- its stderr: $( head -5 "$rigDir/err" )"
}
rigRoutine work-duty ''
rigHeld(){ ## the names of the snapshots the run's store holds, in order, space-joined
	ls "$rigStore" 2> /dev/null | tr '\n' ' '
}

echo "-- a plain-text reply of a work-duty does not end it: the idle-wait is made, and the model is asked again --"
rigScene duty work-duty
printf 'WAIT_ROUND_SECONDS=2\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The dismissal comes once the second idle-wait has begun, so the order is the check's and not the machine's speed.
( rigWaited=0 ; while [ "$( LC_ALL=C grep -c -F 'idle-wait -- waiting on' "$rigDir/err" 2> /dev/null )" -lt 2 ] && [ "$rigWaited" -lt 240 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done ; sleep 1 ; mkdir -p "$rigStore" ; printf 'rig-boss\n' > "$rigStore/dismissed" ) &
rigLater=$!
rigTextStream "$rigDir/res.1" RIG-DUTY-THINKS-IT-IS-DONE
rigTextStream "$rigDir/res.2" RIG-DUTY-STILL-THINKS-IT-IS-DONE
## the third reply comes after the dismissal: it ends the run
rigTextStream "$rigDir/res.3" RIG-DISMISSED-DONE
rigRun
wait "$rigLater" 2> /dev/null
rigAssert "the run did not end on its plain replies: the model was asked a second and a third time, and the dismissal ended it" "$rigRunStatus:$( cat "$rigDir/round" )" "0:3"
rigAssert "the harness made the idle-wait itself, after each of the two replies before the dismissal" "$( rigCount "$rigDir/err" 'idle-wait -- waiting on' )" "2"
rigAssert "and the model is woken with the keepalive text, the conversation returned to its checkpoint" "$( rigIn "$( cat "$rigDir/req.2" )" 'made its keepalive round' ):$( rigIn "$( cat "$rigDir/req.2" )" 'returned to its checkpoint armed' )" "yes:yes"

echo "-- every plain reply of a work-duty lands on the held checkpoint, also when the run bounds its waits --"
## The run names a wait bound, so the wait comes back at it with no arrival and no keepalive: the conversation is returned all the same (sketch 7.3: "we want it rewind after each working loop").
rigScene bound work-duty
rigWaitTimeout=2
( rigWaited=0 ; while [ "$( LC_ALL=C grep -c -F 'idle-wait -- waiting on' "$rigDir/err" 2> /dev/null )" -lt 2 ] && [ "$rigWaited" -lt 240 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done ; sleep 1 ; mkdir -p "$rigStore" ; printf 'rig-boss\n' > "$rigStore/dismissed" ) &
rigLater=$!
rigTextStream "$rigDir/res.1" RIG-BOUND-DONE
rigTextStream "$rigDir/res.2" RIG-BOUND-DONE-AGAIN
rigRun
wait "$rigLater" 2> /dev/null
rigWaitTimeout=""
rigAssert "the wait ended at the run's bound with no arrival, and the conversation went back to its checkpoint all the same" "$( rigIn "$( cat "$rigDir/req.2" )" 'returned to its checkpoint armed' ):$( rigCount "$rigDir/req.2" 'RIG-BOUND-DONE' )" "yes:0"

echo "-- an executor is not dismissed unless it is the last one running (sketch 5.3) --"
## A member spawned into a session with another member's run still going: its plain reply does not end it. When the other run has ended, the next plain reply does.
rigScene exec rigquiet
printf 'WAIT_ROUND_SECONDS=2\n' > "$rigWs/.local/.agents/magic-team.agent.env"
sed -i.bak 's/^status: spawn-started$/status: spawn-started\nstart-context: spawned/' "$rigWs/.local/agents/spawned/rig/$rigSpawn.spawn.md" && rm -f "$rigWs/.local/agents/spawned/rig/$rigSpawn.spawn.md.bak"
printf -- '---\nspawn-id: rig-other\nsession-id: %s\nowner: rig-b\nhost: another-host\nstart-context: joined\nroutine: magic-team.rigquiet.routine.md\nstatus: spawn-started\n---\n\n# Spawn session: rig-other\n' "$rigSpawn" > "$rigWs/.local/agents/spawned/rig/rig-other.spawn.md"
( rigWaited=0 ; while [ "$( LC_ALL=C grep -c -F 'idle-wait -- waiting on' "$rigDir/err" 2> /dev/null )" -lt 1 ] && [ "$rigWaited" -lt 240 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
  sed -i.bak 's/^status: spawn-started$/status: spawn-succeeded/' "$rigWs/.local/agents/spawned/rig/rig-other.spawn.md" ) &
rigLater=$!
rigTextStream "$rigDir/res.1" RIG-EXEC-DONE
rigTextStream "$rigDir/res.2" RIG-EXEC-DONE-AGAIN
rigRun
wait "$rigLater" 2> /dev/null
rigAssert "while the other run was going the executor did not end; once it had ended, the next plain reply did" "$rigRunStatus:$( cat "$rigDir/round" ):$( rigCount "$rigDir/err" 'idle-wait -- waiting on' )" "0:2:1"

echo "-- a run that is not a work-duty ends on its plain-text reply --"
rigScene plain rigquiet
rigTextStream "$rigDir/res.1" RIG-PLAIN-DONE
rigRun
rigAssert "one request, and the run ended" "$rigRunStatus:$( cat "$rigDir/round" ):$( rigCount "$rigDir/err" 'idle-wait -- waiting on' )" "0:1:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS DUTY NO QUIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_DUTY_NO_QUIT: OK (%d assertions, offline)\n' "$rigPassCount"
