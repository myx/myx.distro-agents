#!/usr/bin/env bash
## Behavioural check on a routine's `references:` key (epic S6.15): a routine's frontmatter names the references its executor
## needs, one `<member>/<file>` a line, and the spawner prefetches them, so a coding routine's `code-craft.md` and `shell.md`
## arrive with its text and no instruction to read them. Held, through the real harness against a fake `curl` replaying canned
## streams and recording each request body:
##   1. a spawned run of a routine that names a reference carries that file's text in its first message, beside the armed file
##   2. it is kept in an entry of the run's own prefetch cache, and a later read of that very file there answers in one line
##   3. a run of a routine that names none carries no such text: the control, so a pass is the key's work and not the rig's
##   4. the routine validator accepts a reference that is a file there is, and refuses one no run could read, naming the key
## Offline by construction: no socket, no credential.
set -u
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
: "${MMDAPP:?ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test"
rigTesting="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigRefuse(){
	echo "ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -f "$rigTesting" ] || rigRefuse "the testing file is not at the origin this workspace resolves: $rigTesting"
. "$rigTest/check-fixtures/rig-reply.include.sh" || rigRefuse "the rig's reply fixture is missing from the package"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineReferencesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home"
cp "$rigTest/check-fixtures/harness-mcp-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
[ "$( PATH="$rigTmp/bin:/usr/bin:/bin" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigIn(){ ## text, needle
	case "$1" in
		*"$2"*) printf 'yes' ;;
		*) printf 'no' ;;
	esac
}
rigCount(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C grep -o -F -- "$2" "$1" | wc -l | tr -d ' '
}

## A routine file of the rig: its name, and the frontmatter lines after requires-session-kind. A quoted heredoc, so nothing of
## the body is expanded or re-quoted.
rigRoutineFile(){ ## path, the frontmatter lines of the key (may be empty)
	{
		printf -- '---\ntype: routine\nexecutors: rig-a\nmaintainers: human-owner\nrequires-session-kind: coworking\ncache-prefix: routine\n'
		[ -z "$2" ] || printf 'references: %s\n' "$2"
		printf -- '---\n'
		cat <<'BODY'
# magic-team.rigroutine.routine -- the actual procedure

# Summary

A rig routine.

# Opening steps

1. **rig-own-open**: open.

# Steps

1. **rig-own-work**: work.

# Closure steps

1. **rig-own-close**: close.

# Routine's local procedures

None.

# Routine's local rules

None.

# Routine-specific tooling

None.

# Maintainer Notes

None.
BODY
	} > "$1"
}
rigKindRoutine(){ ## path
	{
		printf -- '---\ntype: routine\nexecutors: rig-a\nmaintainers: human-owner\nrequires-session-kind: coworking\n---\n'
		cat <<'BODY'
# magic-team.coworking.routine -- the actual procedure

# Summary

A rig kind routine.

# Opening steps

1. **rig-kind-open**: open.

# Steps

1. **rig-kind-work**: work.

# Closure steps

1. **rig-kind-close**: close.

# Routine's local procedures

None.

# Routine's local rules

None.

# Routine-specific tooling

None.

# Maintainer Notes

None.
BODY
	} > "$1"
}
rigMakeSkills(){ ## skillset directory, the references line (may be empty)
	mkdir -p "$1/magic-team" "$1/rig-a/reference"
	printf 'RIG-TEAM-COMMON-LINE one two\n' > "$1/magic-team/magic-team.basic.md"
	printf -- '---\nmaintainers: rig\n---\nRIG-TEAM-ARMED\n' > "$1/magic-team/magic-team.armed.md"
	printf -- '---\nname: magic-team\n---\nteam skill\n' > "$1/magic-team/SKILL.md"
	rigKindRoutine "$1/magic-team/magic-team.coworking.routine.md"
	rigRoutineFile "$1/magic-team/magic-team.rigroutine.routine.md" "$2"
	printf -- '---\nmaintainers: rig\n---\nRIG-A-ARMED-BODY\n' > "$1/rig-a/rig-a.armed.md"
	printf 'RIG-A-BASIC own words\n' > "$1/rig-a/rig-a.basic.md"
	printf -- '---\nname: rig-a\n---\nmember skill\n' > "$1/rig-a/SKILL.md"
	printf 'RIG-REFERENCE-CRAFT read before any code\n' > "$1/rig-a/reference/rig-ref.md"
}

rigWire="AnthropicMessages"
rigSpawn="rig-spawn-one"
rigDir="" rigWs="" rigSandbox="" rigSkills=""
rigScene(){ ## scene name, references line, 1 to make the skillset or 0 to reuse the one before
	rigDir="$rigTmp/$1" ; rigWs="$rigTmp/ws" ; rigSandbox="$rigDir/sandbox" ; rigSkills="$rigTmp/skills"
	mkdir -p "$rigDir" "$rigWs/.local/.agents" "$rigSandbox/input" "$rigSandbox/output"
	printf '0' > "$rigDir/round"
	[ "$3" = 0 ] || rigMakeSkills "$rigSkills" "$2"
}
rigRecord(){ ## routine file name
	{
		printf -- '---\nspawn-id: %s\nparent-spawn-id: none\ncache-prefix: routine\nroutine: %s\nstatus: spawn-started\n---\n\n# Spawn session: %s\n' "$rigSpawn" "$1" "$rigSpawn"
	} > "$rigSandbox/$rigSpawn.spawn.md"
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
rigToolStream(){ ## canned-stream file, tool name, the call input as a JSON object
	local streamInput
	streamInput="$( printf '%s' "$3" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' )"
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig1","type":"message","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_RIG","name":"%s","input":{}}}\n\n' "$2"
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"%s"}}\n\n' "$streamInput"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":40}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}
rigTask="RIG-TASK-MARKER"
rigRun(){
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_SESSION_ID="$rigSpawn" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" MDAT_HARNESS_PREFETCH=on RIG_SCENARIO="$rigDir" \
		HARNESS_PROVIDER_NAME="first-message rig" HARNESS_SELF_NAME="AgentsRoutineReferencesCheck.test.sh" HARNESS_WIRE="$rigWire" HARNESS_CREDENTIAL_NAMES="none" \
		HARNESS_ENDPOINT="https://harness-routine-references.invalid/v1/messages" HARNESS_HOST="harness-routine-references.invalid" HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01" \
		HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
		HARNESS_OUTPUT_TOKENS_LIGHT="4101" HARNESS_OUTPUT_TOKENS_MAIN="4202" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
		bash "$rigHarness" --agent rig-a --access-root "$rigTmp" --access-write-root "$rigTmp" "$rigTask" ) > "$rigDir/out" 2> "$rigDir/err"
	rigRunStatus=$?
	[ "$( cat "$rigDir/round" )" != 0 ] || rigRefuse "the harness issued no request at all -- its stderr: $( head -5 "$rigDir/err" )"
}
rigReq(){ ## round
	LC_ALL=C sed 's/.*"messages":\[//' "$rigDir/req.$1"
}
rigOneLine="Already in this run's first message, unchanged since then"
rigRefEntry(){ ## the cache entry of the reference read
	printf '%s' "$rigWs/.local/agents/prefetch/read.rig-a.reference%rig-ref.md.$( printf '%s' "" | cksum | cut -d ' ' -f 1 )"
}
rigRefLine="rig-a/reference/rig-ref.md"

echo "-- 1. a routine that names a reference: its executor is handed the file --"
rigScene named "$rigRefLine" 1
rigRecord magic-team.rigroutine.routine.md ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun
rigAssert "the run ends normally" "$rigRunStatus" 0
rigAssert "the reference text is in the first message" "$( rigIn "$( rigReq 1 )" 'RIG-REFERENCE-CRAFT' )" yes
rigAssert "beside the armed file, which comes first" \
	"$( rigIn "$( rigReq 1 )" 'RIG-A-ARMED-BODY' ):$( LC_ALL=C awk 'BEGIN { RS = "\001" } { a = index( $0, "RIG-A-ARMED-BODY" ) ; b = index( $0, "RIG-REFERENCE-CRAFT" ) ; print ( a > 0 && b > a ) ? "after" : "not" }' "$rigDir/req.1" )" "yes:after"
rigAssert "it is read as a file inside the rig-a skill folder" "$( rigIn "$( rigReq 1 )" 'rig-ref.md' )" yes

echo "-- 2. it is kept, and a later read of that very file is answered in one line --"
rigAssert "the prefetch kept an entry for it" "$( [ -f "$( rigRefEntry )" ] && printf kept || printf missing )" kept
rigAssert "the entry holds the text, under a stamp of its sources" "$( rigIn "$( cat "$( rigRefEntry )" 2>/dev/null )" 'RIG-REFERENCE-CRAFT' ):$( head -1 "$( rigRefEntry )" 2>/dev/null | LC_ALL=C cut -c1-6 )" "yes:stamp "
rigScene named-again "$rigRefLine" 0
rigRecord magic-team.rigroutine.routine.md
rigToolStream "$rigDir/res.1" Skill '{"name":"rig-a","file":"reference/rig-ref.md"}' ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun
rigAssert "a read of it asks once and is answered in one line, and the text stays in the context once" \
	"$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.2" 'RIG-REFERENCE-CRAFT' )" "yes:1"

echo "-- 3. the control: a routine that names none --"
rigScene unnamed '' 1
rigRecord magic-team.rigroutine.routine.md ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun
rigAssert "no reference text, and the armed file still there" \
	"$( rigIn "$( rigReq 1 )" 'RIG-REFERENCE-CRAFT' ):$( rigIn "$( rigReq 1 )" 'RIG-A-ARMED-BODY' )" "no:yes"

echo "-- 4. the routine validator: a reference is accepted where it is a file there is, and refused where it is not --"
rigValidate(){ ## name, references line (may be empty)
	rigRc=0
	rigRoutineFile "$rigSkills/magic-team/magic-team.$1.routine.md" "$2"
	( cd "$rigWs" && env -i HOME="$rigTmp/home" USER=rigacct PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTesting" --skillset-validate-routine "$rigSkills/magic-team/magic-team.$1.routine.md" ) > "$rigTmp/said" 2>&1 < /dev/null || rigRc=$?
}
rigSaid(){ LC_ALL=C grep -c -F -- "$1" "$rigTmp/said" || : ; }
rigValidate refok "$rigRefLine"
rigAssert "a reference that is a file there is: accepted" "$rigRc" 0
rigValidate refslash 'rig-a'
rigAssert "a line that names no file: refused, naming the key" "$( [ "$rigRc" -ne 0 ] && printf refused || printf passed ):$( rigSaid 'references:' )" "refused:1"
rigValidate refmissing 'rig-a/reference/no-such-file.md'
rigAssert "a file that is not there: refused, naming the key" "$( [ "$rigRc" -ne 0 ] && printf refused || printf passed ):$( rigSaid 'references:' )" "refused:1"

if [ "$rigFail" -ne 0 ] ; then
	echo "ROUTINE REFERENCES CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_REFERENCES: OK (%d assertions, offline)\n' "$rigPass"
