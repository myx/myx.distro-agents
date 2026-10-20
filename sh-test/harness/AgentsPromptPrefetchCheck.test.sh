#!/usr/bin/env bash
## Behavioural check on the prefetch of what a spawned member is told to read on its way to armed (F10.8 of the refactorings epic),
## run through the real core against a fake `curl` replaying canned streams, which records each request body. A harness member of a
## spawned session reads, before it acts, its own armed file, the sections of the team's armed file that its brief names and, where
## its spawn record asks for the prefix of the routine, the routine's text. Those reads, and no others, are made for it before its
## task, as a block of its own in the first message with a cache marker at its end, so the prefix is cached for the member's runs and
## the model needs no round to fetch it. The skillset stays the one source: the content is the Skill tool's own answers, kept in an
## internal cache that is stamped with every source file and rebuilt on any change. Held:
##   1. the first message of a spawned member on the Anthropic wire is two blocks, the reads with a marker at its end and the task;
##      four markers a request; exactly the armed file where the task names no sections, and the named sections beside it where it
##      does -- never the whole team file, the basic file again, or the tool index; the reads are the ones the Skill tool serves
##   2. the run is armed at its start, so its first acting call is not redirected
##   3. the same read asked later (the armed file whole, the same sections) answers with one line; a changed source, a range, other
##      sections, another file, and the whole bundle of a default Skill load are served as they were
##   4. the cache: served from it while no source changed, rebuilt on any change of any source, a damaged entry rebuilt
##   5. `cache-prefix: routine` of the spawn record adds the routine's mixed text; `armed`, and no record, do not; a later read of that
##      routine (its file, its kind's file, and --get-routine-text run by the member) is answered by the one line while the mixed text
##      is unchanged, and served as it was when a range is asked, when it changed, or when it was not read in
##   5c. the system text of a run that carries a prefetch says what it read on its way to armed is in the first message and that it
##      is armed, in place of asking for the read, and mentions no cache; with no prefetch it is as it was
##   6. no prefetch for a run that is not a spawned session, for a member with no armed file, for a served call, or for a run started
##      with MDAT_HARNESS_PREFETCH=off; nothing of it in the sandbox's input/ or in the spawn record
##   7. the chat-completions wire carries the same text as one string
##   9. the lifetime the cache markers ask for (F10.7): unset and 5m send the bytes they always did, 1h puts its ttl in every marker of the run and changes nothing else,
##      another lifetime is refused before any request, and a served call is not asked
##  10. magic-team.work-duty: its `cache-prefix: routine` is read from the file as the spawn reads it, and a run of it carries the text of its routine mixed with its kind's
##   8. two spawns of one member, in sessions, sandboxes and zones of their own, send requests that are byte for byte the same through the marker
##      that ends the prefetch block, and differ in the task block alone: what is of one run (its sandbox and results roots, the sentence of a
##      spawned session) opens that block, and is in the system text nowhere (F10.7, the input token cache)
## Offline by construction: no socket, no credential.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-reply.include.sh" || rigRefuse "the rig's reply fixture is missing from the package: sh-test/check-fixtures/rig-reply.include.sh"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPromptPrefetchCheck )" || exit 1
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
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	rigIn "$( cat "$1" )" "$2"
}
rigCount(){ ## file, text -- how many times the file holds the text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C grep -o -F -- "$2" "$1" | wc -l | tr -d ' '
}
rigEndsWith(){ ## text, tail -- yes where the text ends with the tail
	case "$1" in
		*"$2") printf 'yes' ;;
		*) printf 'no' ;;
	esac
}
## The first message of a run that carries no prefetch: one string, as it was, and the task its last words (a run with a sandbox, as every scene
## here has, opens it with the text of its own roots: F10.7).
rigStringTask(){ ## messages text -- yes where the first message is one string that ends with the task
	case "$1" in
		'{"role":"user","content":"'*'RIG-TASK-MARKER"}]}') printf 'yes' ;;
		*) printf 'no' ;;
	esac
}
rigMarkers(){ ## file -- how many cache markers the request carries
	LC_ALL=C grep -o '"cache_control":{"type":"ephemeral"}' "$1" | wc -l | tr -d ' '
}

## The skillset of a scene: the team's files, a kind routine and a routine of this check, a member with all of its files, and a
## member with a basic file alone. The team's armed file has the two sections the brief names and one it does not.
rigSectionA="Nothing stops on its own: log, escalate, resolve"
rigSectionB="Every message is addressed, tagged, and sent on a real channel"
rigRoutineFile(){ ## skillset directory, the opening step's text
	{
		printf -- '---\ntype: routine\nexecutors: rig-a\nmaintainers: magic-coordinator\nrequires-session-kind: coworking\n---\n# magic-team.rigroutine.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **rig-own-open**: %s.\n\n# Steps\n\n1. **rig-own-work**: work.\n\n# Closure steps\n\n1. **rig-own-close**: close.\n\n' "$2"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$1/magic-team/magic-team.rigroutine.routine.md"
}
## The kind routine of the rig: short, with the sections the mix reads, so that a routine's mixed text stays under the size at which the
## reply layer keeps a result in a file (AgentsReplyLongResultCheck) and the member's own call to --get-routine-text answers whole.
rigKindRoutine(){ ## skillset directory
	{
		printf -- '---\ntype: routine\nexecutors: rig-a\nmaintainers: magic-coordinator\nrequires-session-kind: coworking\n---\n# magic-team.coworking.routine — the actual procedure\n\n# Summary\n\nA rig kind routine.\n\n# Opening steps\n\n1. **rig-kind-open**: open.\n\n# Steps\n\n1. **rig-kind-work**: work.\n\n# Closure steps\n\n1. **rig-kind-close**: close.\n\n'
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$1/magic-team/magic-team.coworking.routine.md"
}
rigMakeSkills(){ ## skillset directory
	mkdir -p "$1/magic-team" "$1/rig-a" "$1/rig-c"
	printf 'RIG-TEAM-COMMON-LINE one two\n' > "$1/magic-team/magic-team.basic.md"
	printf '# %s\n\nRIG-TEAM-SECTION-ONE\n\n# %s\n\nRIG-TEAM-SECTION-TWO\n\n# Something else\n\nRIG-TEAM-UNNAMED\n' "$rigSectionA" "$rigSectionB" > "$1/magic-team/magic-team.armed.md"
	printf -- '---\nname: magic-team\n---\nteam skill\n' > "$1/magic-team/SKILL.md"
	rigKindRoutine "$1"
	rigRoutineFile "$1" RIG-ROUTINE-OPENING
	printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$1/rig-a/rig-a.basic.md"
	printf -- '---\nstatus: rig\n---\nRIG-A-ARMED-BODY\n' > "$1/rig-a/rig-a.armed.md"
	printf -- '---\nname: rig-a\n---\nmember skill\n' > "$1/rig-a/SKILL.md"
	printf 'RIG-C-BASIC own words\n' > "$1/rig-c/rig-c.basic.md"
	printf -- '---\nname: rig-c\n---\nmember skill\n' > "$1/rig-c/SKILL.md"
}
## The brief the spawner puts first in a dispatch, as far as it tells the member what to read (spawn-brief.document.format.md).
rigBrief="SPAWN-PREPARE-BRIEF: rig-a
read-and-obey: read rig-a.armed.md and the routine, through the skillset reader, carefully and in full, before acting, and obey them.
Read these two sections of magic-team/magic-team.armed.md, the same way, with section and not the whole file: {name: magic-team, file: magic-team.armed.md, section: $rigSectionA|$rigSectionB}"
rigTask="RIG-TASK-MARKER"

## One scene is one run folder: its sandbox and canned streams. Its workspace and skillset are named by the second word, and are
## shared by the scenes that name the same one, which is how a scene finds the cache an earlier one left, and finds a source as
## an earlier one changed it.
rigSpawn="rig-spawn-one"
rigDir="" rigWs="" rigSandbox="" rigSkills=""
rigScene(){ ## scene name, workspace name
	rigDir="$rigTmp/$1" ; rigWs="$rigTmp/ws-$2" ; rigSandbox="$rigDir/sandbox" ; rigSkills="$rigTmp/skills-$2"
	mkdir -p "$rigDir" "$rigWs/.local/.agents" "$rigSandbox/input" "$rigSandbox/output"
	printf '0' > "$rigDir/round"
	[ -d "$rigSkills" ] || rigMakeSkills "$rigSkills"
}
rigRecord(){ ## cache-prefix, routine -- the spawn record in the root of the sandbox, as the spawner writes it
	{
		printf -- '---\nspawn-id: %s\nparent-spawn-id: none\n' "$rigSpawn"
		[ -z "$1" ] || printf 'cache-prefix: %s\n' "$1"
		[ -z "$2" ] || printf 'routine: %s\n' "$2"
		printf 'status: spawn-started\n---\n\n# Spawn session: %s\n' "$rigSpawn"
	} > "$rigSandbox/$rigSpawn.md"
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
rigToolStream(){ ## canned-stream file, tool name, the call's input as a JSON object
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
rigChatTextStream(){ ## canned-stream file, content
	printf 'data: {"choices":[{"index":0,"delta":{"content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' "$2" > "$1"
}
## The run: a spawned member's harness (the spawn session id and the sandbox set), or a plain run with none.
rigWire="AnthropicMessages"
rigPrefetch="on"
## Where a scene names them, the one access root all of its runs share (else the scene's folder), the zone the clock of the run reads and the
## session the run belongs to; no word of them otherwise, so every scene before them runs as it did.
rigRoot="" rigTz="" rigSession="" rigCacheTime="" rigNoRequest=""
rigRun(){ ## member, spawned (yes|no), further harness arguments -- the scene's streams are in place
	local runMember="$1" runSpawned="$2" runSpawnWord="RIG_NOT_SPAWNED=1" ; shift 2
	[ "$runSpawned" != yes ] || runSpawnWord="MDAT_SPAWN_SESSION_ID=$rigSpawn"
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" "$runSpawnWord" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" MDAT_HARNESS_PREFETCH="$rigPrefetch" RIG_SCENARIO="$rigDir" ${rigTz:+TZ=$rigTz} ${rigSession:+MDAT_SESSION_ID=$rigSession} ${rigCacheTime:+HARNESS_INPUT_CACHE_TIME=$rigCacheTime} \
		HARNESS_PROVIDER_NAME="first-message rig" HARNESS_SELF_NAME="AgentsPromptPrefetchCheck.test.sh" HARNESS_WIRE="$rigWire" HARNESS_CREDENTIAL_NAMES="none" \
		HARNESS_ENDPOINT="https://harness-prompt-prefetch.invalid/v1/messages" HARNESS_HOST="harness-prompt-prefetch.invalid" HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01" \
		HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
		HARNESS_OUTPUT_TOKENS_LIGHT="4101" HARNESS_OUTPUT_TOKENS_MAIN="4202" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
		bash "$rigHarness" ${runMember:+--agent "$runMember"} --access-root "${rigRoot:-$rigDir}" --access-write-root "$rigSkills" "$@" "$rigTask" ) > "$rigDir/out" 2> "$rigDir/err"
	rigRunStatus=$?
	[ "$( cat "$rigDir/round" )" != 0 ] || [ -n "$rigNoRequest" ] || rigRefuse "the harness issued no request at all -- its stderr: $( head -5 "$rigDir/err" )"
}
rigReq(){ ## round -- the messages of that request, as sent
	LC_ALL=C sed 's/.*"messages":\[//' "$rigDir/req.$1"
}
## The text a tool result holds in the request that answers a call, JSON-escaped as it was sent, with the reply layer's date left out.
rigEscapedResult(){ ## request file
	rigReplyBare < "$1" | LC_ALL=C awk '
		{
			head = "\"tool_use_id\":\"toolu_RIG\",\"content\":\"" ;
			at = index( $0, head ) ;
			if ( at == 0 ) { exit ; }
			rest = substr( $0, at + length( head ) ) ;
			out = "" ;
			for ( k = 1 ; k <= length( rest ) ; k++ ) {
				ch = substr( rest, k, 1 ) ;
				if ( ch == "\\" ) { out = out ch substr( rest, k + 1, 1 ) ; k++ ; continue ; }
				if ( ch == "\"" ) { break ; }
				out = out ch ;
			}
			print out ;
		}
	'
}
## The entry the prefetch keeps for a read: the skill, the file and the sections.
rigReadEntry(){ ## name, file, sections
	printf '%s' "$rigWs/.local/agents/prefetch/read.$1.$2.$( printf '%s' "${3:-}" | cksum | cut -d ' ' -f 1 )"
}
rigOneLine="Already in this run's first message, unchanged since then"
rigSecJson="$rigSectionA|$rigSectionB"
rigSkillCall(){ ## name, file, extra members of the call's input (as JSON members, or empty)
	printf '{"name":"%s","file":"%s"%s}' "$1" "$2" "${3:+,$3}"
}

echo "-- 1. a spawned member's first message: its armed file, then the task --"
rigScene served shared ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigServedDir="$rigDir"
rigAssert "the run ends normally"                                                         "$rigRunStatus" 0
rigAssert "the first message is two text blocks, the read with a marker at its end and the task block after it, the task its last words" \
	"$( rigIn "$( rigReq 1 )" '{"role":"user","content":[{"type":"text","text":"' ):$( rigIn "$( rigReq 1 )" '","cache_control":{"type":"ephemeral"}},{"type":"text","text":"' ):$( rigEndsWith "$( rigReq 1 )" 'RIG-TASK-MARKER"}]}]}' )" yes:yes:yes
rigAssert "four markers a request: the moving one, the floor, the common instruction, the read"  "$( rigMarkers "$rigDir/req.1" )" 4
rigAssert "the read is the member's armed file, as the Skill tool serves it, front matter and all"  "$( rigIn "$( rigReq 1 )" 'RIG-A-ARMED-BODY' ):$( rigIn "$( rigReq 1 )" 'status: rig' )" yes:yes
rigAssert "and nothing else: no basic file again, no team file, no tool index"             "$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' ):$( rigCount "$rigDir/req.1" 'RIG-A-BASIC own words' ):$( rigIn "$( rigReq 1 )" 'RIG-TEAM-' ):$( rigIn "$( rigReq 1 )" 'Tool index' )" 1:1:no:no
rigAssert "the team's basic file is in the system text alone, once"                        "$( rigCount "$rigDir/req.1" 'RIG-TEAM-COMMON-LINE' )" 1
rigAssert "the prefetch says on stderr what it did"                                       "$( rigIn "$( cat "$rigDir/err" )" 'prefetched the reads of the rig-a skill into the first message -- ' ):$( rigIn "$( cat "$rigDir/err" )" '0 from the cache, 1 built' )" yes:yes

echo "-- 1b. it is what the Skill read serves --"
rigScene read shared ; rigToolStream "$rigDir/res.1" Skill "$( rigSkillCall rig-a rig-a.armed.md )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a no
rigEscaped="$( rigEscapedResult "$rigDir/req.2" )"
rigAssert "control: a run that is no spawned session reads the armed file itself"           "$( rigIn "$rigEscaped" 'RIG-A-ARMED-BODY' )" yes
rigAssert "and its first message is one string with the task its last words, three markers as before"     "$( rigStringTask "$( rigReq 1 )" ):$( rigMarkers "$rigDir/req.1" )" yes:3
rigFirstBlock="$( LC_ALL=C sed 's/.*"messages":\[{"role":"user","content":\[{"type":"text","text":"//' "$rigServedDir/req.1" | LC_ALL=C sed 's/","cache_control".*//' )"
rigAssert "the first block of the spawned run holds that very text, byte for byte"          "$( [ -n "$rigEscaped" ] && rigIn "$rigFirstBlock" "$rigEscaped" )" yes

echo "-- 1c. the sections the brief names come with it, and only those --"
rigTask="$rigBrief"$'\n'"RIG-TASK-MARKER"
rigScene brief brief ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigBriefDir="$rigDir"
rigAssert "the armed file and both named sections are in the first block"                   "$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' ):$( rigCount "$rigDir/req.1" 'RIG-TEAM-SECTION-ONE' ):$( rigCount "$rigDir/req.1" 'RIG-TEAM-SECTION-TWO' )" 1:1:1
rigAssert "a section the brief does not name is not, nor the team's basic file again"       "$( rigCount "$rigDir/req.1" 'RIG-TEAM-SECTION-ONE' ):$( rigIn "$( rigReq 1 )" 'RIG-TEAM-UNNAMED' ):$( rigCount "$rigDir/req.1" 'RIG-TEAM-COMMON-LINE' )" 1:no:1
rigAssert "still four markers: the reads are one block"                                      "$( rigMarkers "$rigDir/req.1" )" 4
rigAssert "the task block is the brief and the task, after them"                             "$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' ):$( rigIn "$( rigReq 1 )" 'SPAWN-PREPARE-BRIEF: rig-a' ):$( rigIn "$( rigReq 1 )" 'RIG-TASK-MARKER"}]}' )" 1:yes:yes
rigAssert "the prefetch says it carried two reads"                                          "$( rigIn "$( cat "$rigDir/err" )" 'prefetched the reads of the rig-a skill' )" yes
rigScene read-sec brief ; rigToolStream "$rigDir/res.1" Skill "$( rigSkillCall magic-team magic-team.armed.md "\"section\":\"$rigSecJson\"" )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a no
rigEscaped="$( rigEscapedResult "$rigDir/req.2" )"
rigFirstBlock="$( LC_ALL=C sed 's/.*"messages":\[{"role":"user","content":\[{"type":"text","text":"//' "$rigBriefDir/req.1" | LC_ALL=C sed 's/","cache_control".*//' )"
rigAssert "the sections are what the Skill read of those sections serves, byte for byte"    "$( rigIn "$rigEscaped" 'RIG-TEAM-SECTION-ONE' ):$( [ -n "$rigEscaped" ] && rigIn "$rigFirstBlock" "$rigEscaped" )" yes:yes

echo "-- 2. armed at its start: the first acting call is not redirected --"
rigTask="RIG-TASK-MARKER"
rigScene armed shared ; rigRecord "" ""
rigToolStream "$rigDir/res.1" Write "{\"file_path\":\"$rigDir/ws-out.txt\",\"content\":\"RIG-WRITTEN\"}" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "the Write of the first round lands"                                            "$( cat "$rigDir/ws-out.txt" 2> /dev/null )" "RIG-WRITTEN"
rigAssert "and its result is not the redirect to the duty file"                           "$( rigIn "$( rigReq 2 )" 'read your duty file first' )" no
rigAssert "the arming is recorded in the sandbox as a read would record it"              "$( [ -s "$rigSandbox/$rigSpawn.armed" ] && printf yes || printf no )" yes

echo "-- 3. the same read asked later --"
rigScene again shared ; rigRecord "" "" ; rigToolStream "$rigDir/res.1" Skill "$( rigSkillCall rig-a rig-a.armed.md )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "the armed file, read whole, unchanged: one line says it is in the first message"  "$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' ):$( rigCount "$rigDir/req.2" 'RIG-A-ARMED-BODY' )" yes:1:1
rigScene again-range shared ; rigRecord "" "" ; rigToolStream "$rigDir/res.1" Skill "$( rigSkillCall rig-a rig-a.armed.md '"offset":1,"limit":5' )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "a range of it is served as it was"                                             "$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' ):$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.2" 'RIG-A-ARMED-BODY' )" 1:no:2
rigScene again-basic shared ; rigRecord "" "" ; rigToolStream "$rigDir/res.1" Skill "$( rigSkillCall rig-a rig-a.basic.md )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "the basic file, which the run is not told to read and which its system text holds, is served as it was"  "$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' ):$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.2" 'RIG-A-BASIC own words' )" 1:no:2
rigScene again-bundle shared ; rigRecord "" "" ; rigToolStream "$rigDir/res.1" Skill '{"skill":"rig-a"}' ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "a default Skill load is the whole bundle, as it was: the team file whole, the member's files, no one line"  "$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.2" 'RIG-TEAM-UNNAMED' ):$( rigCount "$rigDir/req.2" 'RIG-A-ARMED-BODY' )" no:1:2
rigScene again-team shared ; rigRecord "" "" ; rigToolStream "$rigDir/res.1" Skill "$( rigSkillCall magic-team magic-team.armed.md )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "another file, the team's armed file whole, is served whole"                    "$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' ):$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.2" 'RIG-TEAM-UNNAMED' )" 1:no:1
rigTask="$rigBrief"$'\n'"RIG-TASK-MARKER"
rigScene again-sec brief ; rigRecord "" "" ; rigToolStream "$rigDir/res.1" Skill "$( rigSkillCall magic-team magic-team.armed.md "\"section\":\"$rigSecJson\"" )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "the sections the brief names, asked as it names them: one line, and the text is in the context once"  "$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.1" 'RIG-TEAM-SECTION-ONE' ):$( rigCount "$rigDir/req.2" 'RIG-TEAM-SECTION-ONE' )" yes:1:1
rigScene again-sec1 brief ; rigRecord "" "" ; rigToolStream "$rigDir/res.1" Skill "$( rigSkillCall magic-team magic-team.armed.md "\"section\":\"$rigSectionA\"" )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "one of them alone is another read, and is served as it was"                    "$( rigCount "$rigDir/req.1" 'RIG-TEAM-SECTION-ONE' ):$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.2" 'RIG-TEAM-SECTION-ONE' )" 1:no:2
rigScene again-other brief ; rigRecord "" "" ; rigToolStream "$rigDir/res.1" Skill '{"skill":"rig-c"}' ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "another member's skill is served as it was"                                    "$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' ):$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigIn "$( rigReq 2 )" 'member skill' )" 1:no:yes
rigTask="RIG-TASK-MARKER"
rigScene changed changed ; rigRecord "" ""
rigToolStream "$rigDir/res.1" Edit "{\"file_path\":\"$rigSkills/rig-a/rig-a.armed.md\",\"old_string\":\"RIG-A-ARMED-BODY\",\"new_string\":\"RIG-A-ARMED-CHANGED\"}"
rigToolStream "$rigDir/res.2" Skill "$( rigSkillCall rig-a rig-a.armed.md )" ; rigTextStream "$rigDir/res.3" RIG-DONE ; rigRun rig-a yes
rigAssert "a source changed after the prefetch: the file is served whole, with the change"   "$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' ):$( rigIn "$( rigReq 3 )" "$rigOneLine" ):$( rigCount "$rigDir/req.3" 'RIG-A-ARMED-CHANGED' )" 1:no:2

echo "-- 4. the internal cache, stamped with every source --"
rigTask="$rigBrief"$'\n'"RIG-TASK-MARKER"
rigScene cache1 cache ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "the first spawn builds both reads and keeps them"                              "$( rigIn "$( cat "$rigDir/err" )" '0 from the cache, 2 built' ):$( [ -f "$( rigReadEntry rig-a rig-a.armed.md )" ] && printf kept || printf missing ):$( [ -f "$( rigReadEntry magic-team magic-team.armed.md "$rigSecJson" )" ] && printf kept || printf missing )" yes:kept:kept
rigAssert "an entry holds the text under a stamp of its sources"                          "$( rigHolds "$( rigReadEntry rig-a rig-a.armed.md )" 'RIG-A-ARMED-BODY' ):$( head -1 "$( rigReadEntry rig-a rig-a.armed.md )" | LC_ALL=C cut -c1-6 )" yes:"stamp "
rigTamper(){ ## entry file, from, to -- the words of the entry's text changed, its stamp as it was
	LC_ALL=C sed "s/$2/$3/g" "$1" > "$1.new" && mv -f "$1.new" "$1"
}
rigTamper "$( rigReadEntry rig-a rig-a.armed.md )" RIG-A-ARMED-BODY RIG-A-ARMED-CACHED
rigTamper "$( rigReadEntry magic-team magic-team.armed.md "$rigSecJson" )" RIG-TEAM-SECTION-ONE RIG-TEAM-SECTION-CACHED
rigScene cache2 cache ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "no source changed: the next spawn is served from the entries, not built again"  "$( rigIn "$( rigReq 1 )" 'RIG-A-ARMED-CACHED' ):$( rigIn "$( rigReq 1 )" 'RIG-TEAM-SECTION-CACHED' ):$( rigIn "$( cat "$rigDir/err" )" '2 from the cache, 0 built' )" yes:yes:yes
rigChange(){ ## file, from, to -- one word of a source changed to another of the same length
	LC_ALL=C sed "s/$2/$3/" "$1" > "$1.new" && mv -f "$1.new" "$1"
}
rigScene cache3 cache ; rigRecord "" "" ; rigChange "$rigSkills/rig-a/rig-a.armed.md" ARMED-BODY ARMEX-BODY ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "the armed file changed, at once and by as many bytes as it had: rebuilt, never the entry; the other entry is still good"  "$( rigIn "$( rigReq 1 )" 'RIG-A-ARMEX-BODY' ):$( rigIn "$( rigReq 1 )" 'RIG-A-ARMED-CACHED' ):$( rigIn "$( rigReq 1 )" 'RIG-TEAM-SECTION-CACHED' ):$( rigIn "$( cat "$rigDir/err" )" '1 from the cache, 1 built' )" yes:no:yes:yes
rigAssert "and the entry is written anew"                                                  "$( rigHolds "$( rigReadEntry rig-a rig-a.armed.md )" 'RIG-A-ARMEX-BODY' ):$( rigHolds "$( rigReadEntry rig-a rig-a.armed.md )" 'CACHED' )" yes:no
rigTamper "$( rigReadEntry rig-a rig-a.armed.md )" RIG-A-ARMEX-BODY RIG-A-ARMEX-CACHED
rigScene cache4 cache ; rigRecord "" "" ; rigChange "$rigSkills/magic-team/magic-team.armed.md" SECTION-TWO SECTION-TW0 ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "the team's armed file changed: the sections are read again, the armed file is not"  "$( rigIn "$( rigReq 1 )" 'RIG-TEAM-SECTION-TW0' ):$( rigIn "$( rigReq 1 )" 'RIG-TEAM-SECTION-CACHED' ):$( rigIn "$( rigReq 1 )" 'RIG-A-ARMEX-CACHED' )" yes:no:yes
rigTamper "$( rigReadEntry magic-team magic-team.armed.md "$rigSecJson" )" RIG-TEAM-SECTION-ONE RIG-TEAM-SECTION-CACHED
rigScene cache5 cache ; rigRecord "" "" ; rigChange "$rigSkills/magic-team/magic-team.basic.md" "one two" "one tw0" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "the team's basic file changed: it is the system text of the run, which carries it at once; the reads are good"  "$( rigHolds "$rigDir/req.1" 'RIG-TEAM-COMMON-LINE one tw0' ):$( rigIn "$( cat "$rigDir/err" )" '2 from the cache, 0 built' )" yes:yes
printf 'this is no cache entry\n' > "$( rigReadEntry rig-a rig-a.armed.md )"
rigScene cache6 cache ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "a damaged entry is built over, the run goes on"                                "$( rigIn "$( rigReq 1 )" 'RIG-A-ARMEX-BODY' ):$( rigHolds "$( rigReadEntry rig-a rig-a.armed.md )" 'RIG-A-ARMEX-BODY' ):$rigRunStatus" yes:yes:0

echo "-- 5. the routine's text, where the spawn record asks for the routine's prefix --"
rigTask="RIG-TASK-MARKER"
rigScene routine1 routine ; rigRecord routine magic-team.rigroutine.routine.md ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "cache-prefix: routine: the first message holds the routine mixed with its kind routine, after the armed file"  "$( rigIn "$( rigReq 1 )" 'RIG-ROUTINE-OPENING' ):$( rigIn "$( rigReq 1 )" 'rig-own-work' ):$( rigIn "$( rigReq 1 )" 'RIG-A-ARMED-BODY' )" yes:yes:yes
rigAssert "in the same block, so four markers still"                                       "$( rigMarkers "$rigDir/req.1" )" 4
rigAssert "the routine text is kept in an entry of its own"                                "$( [ -f "$rigWs/.local/agents/prefetch/routine.magic-team.rigroutine.routine.md" ] && printf kept || printf missing )" kept
## Reproducible, for the cache (Constraint 3): the same routine built again, in another workspace and another session some seconds later, is the same bytes,
## in the entry and in the block of the first message.
rigRoutineBlock(){ ## request file -- the routine's block of the first message as sent: from its marker to the run's own paths, which the notes after it name
	LC_ALL=C sed -e 's/.*"messages":\[//' -e 's/.*read for you before your task://' -e "s#$rigTmp.*##" "$1"
}
rigEntryText(){ ## entry file -- the entry without the stamp lines (a checksum, a size and the path of each input, the one thing that names its workspace)
	LC_ALL=C grep -v -E '^[0-9]+ [0-9]+ ' "$1"
}
rigFirstEntry="$rigWs/.local/agents/prefetch/routine.magic-team.rigroutine.routine.md" ; rigFirstReq="$rigDir/req.1"
sleep 2
rigScene routine1b routineb ; rigRecord routine magic-team.rigroutine.routine.md ; rigSession="rig-session-routine-b" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes ; rigSession=""
rigAssert "built again in another workspace and session, seconds later: the entry is the same bytes"  "$( [ -s "$rigFirstEntry" ] && [ -n "$( rigEntryText "$rigFirstEntry" )" ] && [ "$( rigEntryText "$rigFirstEntry" )" = "$( rigEntryText "$rigWs/.local/agents/prefetch/routine.magic-team.rigroutine.routine.md" )" ] && echo identical )" identical
rigAssert "and so is the block of the first message"                                       "$( [ -n "$( rigRoutineBlock "$rigFirstReq" )" ] && [ "$( rigRoutineBlock "$rigFirstReq" )" = "$( rigRoutineBlock "$rigDir/req.1" )" ] && echo identical )" identical
rigScene routine1 routine
LC_ALL=C sed "s/RIG-ROUTINE-OPENING/RIG-ROUTINE-CACHED/g" "$rigWs/.local/agents/prefetch/routine.magic-team.rigroutine.routine.md" > "$rigTmp/entry.new" && mv -f "$rigTmp/entry.new" "$rigWs/.local/agents/prefetch/routine.magic-team.rigroutine.routine.md"
rigScene routine2 routine ; rigRecord routine magic-team.rigroutine.routine.md ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "unchanged: served from its entry"                                               "$( rigIn "$( rigReq 1 )" 'RIG-ROUTINE-CACHED' )" yes
rigScene routine3 routine ; rigRecord routine magic-team.rigroutine.routine.md ; rigRoutineFile "$rigSkills" RIG-ROUTINE-CHANGED ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "the routine file changed: rebuilt"                                              "$( rigIn "$( rigReq 1 )" 'RIG-ROUTINE-CHANGED' ):$( rigIn "$( rigReq 1 )" 'CACHED' )" yes:no
rigScene routine4 routine ; rigRecord armed magic-team.rigroutine.routine.md ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "cache-prefix: armed: no routine text"                                           "$( rigIn "$( rigReq 1 )" 'RIG-ROUTINE-' ):$( rigIn "$( rigReq 1 )" 'RIG-A-ARMED-BODY' )" no:yes
rigScene routine5 routine ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "a record with no cache-prefix: no routine text"                                 "$( rigIn "$( rigReq 1 )" 'RIG-ROUTINE-' ):$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' )" no:1
rigScene routine6 routine ; rm -f "$rigSandbox/$rigSpawn.md" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "no record at all: the armed file alone"                                         "$( rigIn "$( rigReq 1 )" 'RIG-ROUTINE-' ):$( rigIn "$( rigReq 1 )" 'RIG-A-ARMED-BODY' )" no:yes

echo "-- 5b. a later read of the routine: the same one line, while the mixed text is unchanged --"
rigSession="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsSession.fn.sh"
rigGetText='bash "'"$rigSession"'" --get-routine-text magic-team.rigroutine.routine.md'
rigBashJson(){ ## the Bash call that runs --get-routine-text, in the scene's own folder, which is an access root of the run
	printf '{"cwd":"%s","command":%s}' "$rigDir" "$( printf '%s' "$rigGetText" | LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/^/"/' -e 's/$/"/' )"
}
rigScene rd rd ; rigRecord routine magic-team.rigroutine.routine.md ; rigToolStream "$rigDir/res.1" Skill "$( rigSkillCall magic-team magic-team.rigroutine.routine.md )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "the routine file, read whole: one line, and the routine's text is in the context once"  "$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.2" 'RIG-ROUTINE-OPENING' )" yes:1
rigScene rd-kind rd ; rigRecord routine magic-team.rigroutine.routine.md ; rigToolStream "$rigDir/res.1" Skill "$( rigSkillCall magic-team magic-team.coworking.routine.md )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "so is the routine file of its kind"                                             "$( rigCount "$rigDir/req.1" 'RIG-ROUTINE-OPENING' ):$( rigIn "$( rigReq 2 )" "$rigOneLine" )" 1:yes
rigScene rd-range rd ; rigRecord routine magic-team.rigroutine.routine.md ; rigToolStream "$rigDir/res.1" Skill "$( rigSkillCall magic-team magic-team.rigroutine.routine.md '"offset":1,"limit":40' )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "a range of the routine file is served as it was"                                "$( rigCount "$rigDir/req.1" 'RIG-ROUTINE-OPENING' ):$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.2" 'RIG-ROUTINE-OPENING' )" 1:no:2
rigScene rd-text rd ; rigRecord routine magic-team.rigroutine.routine.md ; rigToolStream "$rigDir/res.1" Bash "$( rigBashJson )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "--get-routine-text of that routine, run by the member: one line, not the text again"  "$( rigCount "$rigDir/req.1" 'RIG-ROUTINE-OPENING' ):$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.2" 'RIG-ROUTINE-OPENING' )" 1:yes:1
rigScene rd-armed rd ; rigRecord armed magic-team.rigroutine.routine.md ; rigToolStream "$rigDir/res.1" Skill "$( rigSkillCall magic-team magic-team.rigroutine.routine.md )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "cache-prefix: armed: the routine was not read in, so its file is served whole"  "$( rigCount "$rigDir/req.1" 'RIG-ROUTINE-OPENING' ):$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.2" 'RIG-ROUTINE-OPENING' )" 0:no:1
rigScene rd-text-armed rd ; rigRecord armed magic-team.rigroutine.routine.md ; rigToolStream "$rigDir/res.1" Bash "$( rigBashJson )" ; rigTextStream "$rigDir/res.2" RIG-DONE ; rigRun rig-a yes
rigAssert "and --get-routine-text prints the text"                                         "$( rigCount "$rigDir/req.1" 'RIG-A-ARMED-BODY' ):$( rigIn "$( rigReq 2 )" "$rigOneLine" ):$( rigCount "$rigDir/req.2" 'RIG-ROUTINE-OPENING' )" 1:no:1
rigScene rd-chg rdchg ; rigRecord routine magic-team.rigroutine.routine.md
rigToolStream "$rigDir/res.1" Edit "{\"file_path\":\"$rigSkills/magic-team/magic-team.rigroutine.routine.md\",\"old_string\":\"RIG-ROUTINE-OPENING\",\"new_string\":\"RIG-ROUTINE-CHANGED\"}"
rigToolStream "$rigDir/res.2" Bash "$( rigBashJson )"
rigToolStream "$rigDir/res.3" Skill "$( rigSkillCall magic-team magic-team.rigroutine.routine.md )" ; rigTextStream "$rigDir/res.4" RIG-DONE ; rigRun rig-a yes
rigAssert "the routine changed after the prefetch: --get-routine-text prints its text, with the change"  "$( rigIn "$( rigReq 3 )" "$rigOneLine" ):$( rigCount "$rigDir/req.3" 'RIG-ROUTINE-CHANGED' )" no:2
rigAssert "and the file read too"                                                          "$( rigIn "$( rigReq 4 )" "$rigOneLine" ):$( rigCount "$rigDir/req.4" 'RIG-ROUTINE-CHANGED' )" no:3

echo "-- 5c. the system text says what it read is in the first message and the run is armed, where a prefetch is carried --"
rigSystemOf(){ ## request file -- the system part of the request, the markers left out
	LC_ALL=C sed -e 's/.*"system":\[//' -e 's/\],"tools":.*//' -e 's/"cache_control":{"type":"ephemeral"}//g' "$1"
}
rigScene sys shared ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigSys="$( rigSystemOf "$rigDir/req.1" )"
rigAssert "a prefetch is carried: the system text says what was read is in the first message, ahead of the task, and that the run is armed"  "$( rigIn "$rigSys" 'What you read on your way to armed -- your own rig-a.armed.md -- is already in your first message, ahead of your task, and you are armed' )" yes
rigAssert "it no longer asks for the read, and names no sections where none are carried"  "$( rigIn "$rigSys" 'read your own rig-a.armed.md' ):$( rigIn "$rigSys" 'sections' )" no:no
rigAssert "it names no routine where none is carried, and does not mention a cache or a prefetch"  "$( rigIn "$rigSys" 'your routine' ):$( rigIn "$rigSys" 'cache' ):$( rigIn "$rigSys" 'prefetch' )" no:no:no
rigTask="$rigBrief"$'\n'"RIG-TASK-MARKER"
rigScene sys-brief brief ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "with the sections carried, it says so"                                          "$( rigIn "$( rigSystemOf "$rigDir/req.1" )" 'your own rig-a.armed.md, the sections of the team'"'"'s files that your task tells you to read -- is already in your first message' )" yes
rigTask="RIG-TASK-MARKER"
rigScene sys-routine routine ; rigRecord routine magic-team.rigroutine.routine.md ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "with the routine's text carried, it says so"                                    "$( rigIn "$( rigSystemOf "$rigDir/req.1" )" 'your own rig-a.armed.md, the text of your routine mixed with the routine of its kind -- is already in your first message' )" yes
rigPrefetch="off" ; rigScene sys-off shared ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes ; rigPrefetch="on"
rigAssert "no prefetch: the sentence is as it was, asking for the read"                    "$( rigIn "$( rigSystemOf "$rigDir/req.1" )" 'Before your first acting call, read your own rig-a.armed.md with the Skill tool, name rig-a and file rig-a.armed.md -- it is not included here.' )" yes
rigScene sys-nospawn shared ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a no
rigAssert "a run that is no spawned session: as it was"                                    "$( rigIn "$( rigSystemOf "$rigDir/req.1" )" 'Before your first acting call, read your own rig-a.armed.md' )" yes

echo "-- 6. where there is no prefetch, and where nothing else is touched --"
rigScene nofile shared ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-c yes
rigAssert "a member with no armed file: one string, the task its last words"                "$( rigStringTask "$( rigReq 1 )" )" yes
rigPrefetch="off" ; rigScene off shared ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes ; rigPrefetch="on"
rigAssert "started with MDAT_HARNESS_PREFETCH=off: one string, the task its last words, three markers, and not armed"  "$( rigStringTask "$( rigReq 1 )" ):$( rigMarkers "$rigDir/req.1" ):$( [ -e "$rigSandbox/$rigSpawn.armed" ] && printf armed || printf unarmed )" yes:3:unarmed
rigScene served-call shared ; rigRecord "" ""
rigServedOut="$( printf '%s' '{"skill":"rig-a"}' | ( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_SESSION_ID="$rigSpawn" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" MDAT_SPAWN_AGENT=rig-a bash "$rigHarness" --intern-tool Skill ) 2> /dev/null )"
rigAssert "a served call, a native client's, is the bundle with the team's basic file, as it was"  "$( rigIn "$rigServedOut" 'RIG-A-ARMED-BODY' ):$( rigIn "$rigServedOut" 'RIG-TEAM-COMMON-LINE' ):$( rigIn "$rigServedOut" "$rigOneLine" )" yes:yes:no
rigServedHad="$( rigCount "$rigServedDir/req.1" 'RIG-A-ARMED-BODY' )"
rigAssert "nothing of the prefetch is in the sandbox's input/, where the run did prefetch"  "$rigServedHad:$( LC_ALL=C grep -r -l 'RIG-A-ARMED-BODY' "$rigServedDir/sandbox/input" 2> /dev/null | wc -l | tr -d ' ' )" 1:0
rigAssert "nor in the spawn record, which is as the spawner wrote it"                       "$rigServedHad:$( rigIn "$( cat "$rigServedDir/sandbox/$rigSpawn.md" )" 'RIG-A-' )" 1:no
rigAssert "nor in the output folder"                                                       "$rigServedHad:$( LC_ALL=C grep -r -l 'RIG-A-ARMED-BODY' "$rigServedDir/sandbox/output" 2> /dev/null | wc -l | tr -d ' ' )" 1:0

echo "-- 7. the chat-completions wire: the same text as one string --"
rigWire="OpenAiChat"
rigScene chat shared ; rigRecord "" "" ; rigChatTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "the user message is one string: the read, then the task"                        "$( rigIn "$( cat "$rigDir/req.1" )" 'RIG-A-ARMED-BODY' ):$( rigIn "$( cat "$rigDir/req.1" )" 'RIG-TASK-MARKER"}' ):$( rigCount "$rigDir/req.1" 'cache_control' )" yes:yes:0
rigAssert "in that order"                                                                  "$( LC_ALL=C awk '{ a = index( $0, "RIG-A-ARMED-BODY" ) ; b = index( $0, "RIG-TASK-MARKER" ) ; print ( a > 0 && b > a ) ? "ordered" : "not" ; exit }' "$rigDir/req.1" )" ordered
rigAssert "the run's own roots are in the user message between the read and the task, and the system message names neither the sandbox nor the spawn"  "$( LC_ALL=C awk '{ u = index( $0, "\"role\":\"user\"" ) ; a = index( $0, "RIG-A-ARMED-BODY" ) ; r = index( $0, "sessions/rig-spawn-one/results" ) ; b = index( $0, "RIG-TASK-MARKER" ) ; print ( u > 0 && a > u && r > a && b > r && index( substr( $0, 1, u ), "rig-spawn-one" ) == 0 && index( substr( $0, 1, u ), "/sandbox" ) == 0 ) ? "ordered" : "not" ; exit }' "$rigDir/req.1" )" ordered
rigAssert "the team's basic file is in the system message once"                            "$( rigCount "$rigDir/req.1" 'RIG-TEAM-COMMON-LINE' )" 1
rigWire="AnthropicMessages"

echo "-- 8. two spawns of one member: the same bytes through the prefetch marker, apart in the task block alone --"
## What is of one run alone -- its sandbox and results roots, the sentence of a spawned session, the MCP note -- is not in the system text: it is
## the task block's, after the marker, so the system text and the prefetch block are the same for every spawn of a member (the input token cache).
rigPfEnd(){ ## request file -- the byte at which the marker that ends the prefetch block ends
	LC_ALL=C awk 'BEGIN { RS = "\001" ; mark = "\"cache_control\":{\"type\":\"ephemeral\"}}" } { m = index( $0, "\"messages\":[" ) ; k = index( substr( $0, m ), mark ) ; print m + k - 1 + length( mark ) - 1 }' "$1"
}
rigTask="$rigBrief"$'\n'"RIG-TASK-ONE"
rigSpawn="rig-spawn-two" rigSession="rig-session-two" rigTz="Pacific/Kiritimati"
rigScene twin1 twin ; rigRoot="$rigWs" ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes ; rigTwinOne="$rigDir"
rigTask="$rigBrief"$'\n'"RIG-TASK-TWO is another task, and a longer one"
rigSpawn="rig-spawn-three" rigSession="rig-session-three" rigTz="Etc/GMT+12"
rigScene twin2 twin ; rigRoot="$rigWs" ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes ; rigTwoStatus="$rigRunStatus"
rigTwinTwo="$rigDir"
rigSpawn="rig-spawn-one" rigSession="" rigTz="" rigRoot="" ; rigTask="RIG-TASK-MARKER"
rigPfEndOne="$( rigPfEnd "$rigTwinOne/req.1" )" ; rigPfEndTwo="$( rigPfEnd "$rigTwinTwo/req.1" )"
head -c "$rigPfEndOne" "$rigTwinOne/req.1" > "$rigTmp/twin.head.1" ; head -c "$rigPfEndTwo" "$rigTwinTwo/req.1" > "$rigTmp/twin.head.2"
tail -c +"$(( rigPfEndOne + 1 ))" "$rigTwinOne/req.1" > "$rigTmp/twin.task.1" ; tail -c +"$(( rigPfEndTwo + 1 ))" "$rigTwinTwo/req.1" > "$rigTmp/twin.task.2"
rigDiffAt="$( cmp -l "$rigTwinOne/req.1" "$rigTwinTwo/req.1" 2> /dev/null | head -1 | LC_ALL=C awk '{ print $1 }' )"
rigAssert "both runs end normally, and each is a spawned session of its own: not the same session, sandbox or zone"  "$rigRunStatus:$rigTwoStatus:$( [ "$rigTwinOne/sandbox" != "$rigTwinTwo/sandbox" ] && printf apart )" 0:0:apart
rigAssert "the first message is two blocks with four markers, the same in both"                  "$( rigMarkers "$rigTwinOne/req.1" ):$( rigMarkers "$rigTwinTwo/req.1" ):$( [ "$rigPfEndOne" = "$rigPfEndTwo" ] && printf same )" 4:4:same
rigAssert "the two requests are the same bytes through the marker that ends the prefetch block"  "$( cmp -s "$rigTmp/twin.head.1" "$rigTmp/twin.head.2" && printf same || printf differ )" same
rigAssert "what is the same is the tools, the common block, the member's own text and the reads: it holds the armed file, once"  "$( LC_ALL=C grep -o -F 'RIG-TEAM-COMMON-LINE' "$rigTmp/twin.head.1" | wc -l | tr -d ' ' ):$( LC_ALL=C grep -o -F 'RIG-A-BASIC own words' "$rigTmp/twin.head.1" | wc -l | tr -d ' ' ):$( LC_ALL=C grep -o -F 'RIG-A-ARMED-BODY' "$rigTmp/twin.head.1" | wc -l | tr -d ' ' )" 1:1:1
rigAssert "the first byte that differs is in the task block, after the marker"                  "$( [ -n "$rigDiffAt" ] && [ "$rigDiffAt" -gt "$rigPfEndOne" ] && printf after )" after
rigAssert "and the task blocks differ"                                                              "$( cmp -s "$rigTmp/twin.task.1" "$rigTmp/twin.task.2" && printf same || printf differ )" differ
rigAssert "the spawn id, the sandbox and the session are nowhere in what is the same"            "$( LC_ALL=C grep -c -E 'rig-spawn-(two|three)|/sandbox|rig-session' "$rigTmp/twin.head.1" ):$( LC_ALL=C grep -c -E 'rig-spawn-(two|three)|/sandbox|rig-session' "$rigTmp/twin.head.2" )" 0:0
rigAssert "they are in the task block: the sandbox's input/ and output/ and the results folder, each run's own"  "$( LC_ALL=C grep -o -F "/sandbox/input" "$rigTmp/twin.task.1" | wc -l | tr -d ' ' ):$( LC_ALL=C grep -o -F "/sandbox/output" "$rigTmp/twin.task.1" | wc -l | tr -d ' ' ):$( LC_ALL=C grep -o -F 'sessions/rig-spawn-two/results' "$rigTmp/twin.task.1" | wc -l | tr -d ' ' ):$( LC_ALL=C grep -o -F 'sessions/rig-spawn-three/results' "$rigTmp/twin.task.2" | wc -l | tr -d ' ' )" 1:2:1:1
rigAssert "the sentence of a spawned session, that it never ends on its own, is in the task block and not in the system text"  "$( LC_ALL=C grep -c -F 'you never end on your own' "$rigTmp/twin.head.1" ):$( LC_ALL=C grep -o -F 'you never end on your own' "$rigTmp/twin.task.1" | wc -l | tr -d ' ' )" 0:1
rigAssert "the root all the runs of the workspace share stays in the system text: among the access roots, and the write roots"  "$( LC_ALL=C grep -o -F "$rigWs" "$rigTmp/twin.head.1" | wc -l | tr -d ' ' )" 2
rigAssert "the task is the task block's last words, after the run's own roots"                    "$( rigIn "$( cat "$rigTmp/twin.task.1" )" 'RIG-TASK-ONE"}]' ):$( rigIn "$( cat "$rigTmp/twin.task.2" )" 'RIG-TASK-TWO is another task, and a longer one"}]' )" yes:yes

echo "-- 9. the lifetime the cache markers ask for (F10.7) --"
rigTask="RIG-TASK-MARKER"
rigSpawn="rig-spawn-ttl"
rigTtl(){ ## scene name, the lifetime asked (empty: none) -- the request of a spawned run, its root the workspace's
	rigCacheTime="$2" ; rigScene "$1" ttl ; rigRoot="$rigWs" ; rigRecord "" "" ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
	rigCacheTime=""
}
rigTtl ttl-none "" ; rigTtlNone="$rigDir"
rigTtl ttl-five 5m ; rigTtlFive="$rigDir"
rigTtl ttl-hour 1h ; rigTtlHour="$rigDir"
rigPlain='"cache_control":{"type":"ephemeral"}'
rigHourly='"cache_control":{"type":"ephemeral","ttl":"1h"}'
rigAssert "unset: four markers, each the plain one, and no ttl anywhere in the request"  "$( rigCount "$rigTtlNone/req.1" "$rigPlain" ):$( rigCount "$rigTtlNone/req.1" '"ttl"' )" 4:0
rigAssert "5m is the provider's own and says nothing: the request is the unset one's through the prefetch marker, byte for byte"  "$( head -c "$( rigPfEnd "$rigTtlNone/req.1" )" "$rigTtlNone/req.1" | cksum ):$( head -c "$( rigPfEnd "$rigTtlFive/req.1" )" "$rigTtlFive/req.1" | cksum )" "$( head -c "$( rigPfEnd "$rigTtlNone/req.1" )" "$rigTtlNone/req.1" | cksum ):$( head -c "$( rigPfEnd "$rigTtlNone/req.1" )" "$rigTtlNone/req.1" | cksum )"
rigAssert "and has no ttl either"                                                         "$( rigCount "$rigTtlFive/req.1" '"ttl"' ):$( rigCount "$rigTtlFive/req.1" "$rigPlain" )" 0:4
rigAssert "1h: all four markers of the run carry the ttl -- the moving one, the end of the floor, the end of the common block, the end of the prefetch -- and none is plain"  "$( rigCount "$rigTtlHour/req.1" "$rigHourly" ):$( rigCount "$rigTtlHour/req.1" "$rigPlain" ):$( rigCount "$rigTtlHour/req.1" '"cache_control":{' )" 4:0:4
rigAssert "the end of the floor's tools is one of them"                                   "$( rigHolds "$rigTtlHour/req.1" "$rigHourly"'}],"tool_choice"' )" yes
rigAssert "nothing else of the request changes: without the ttl it is the unset request through the prefetch marker"  "$( LC_ALL=C sed 's/,"ttl":"1h"//g' "$rigTtlHour/req.1" | head -c "$( rigPfEnd "$rigTtlNone/req.1" )" | cksum )" "$( head -c "$( rigPfEnd "$rigTtlNone/req.1" )" "$rigTtlNone/req.1" | cksum )"
rigNoRequest="yes" ; rigTtl ttl-bad 2h ; rigNoRequest=""
rigAssert "another lifetime is refused before any request: the harness ends non-zero, sends none, and says what it takes"  "$( [ "$rigRunStatus" != 0 ] && printf refused ):$( cat "$rigTmp/ttl-bad/round" ):$( rigIn "$( cat "$rigTmp/ttl-bad/err" )" 'HARNESS_INPUT_CACHE_TIME is none of 5m, 1h' )" refused:0:yes
rigAssert "and prints no value of it"                                                     "$( LC_ALL=C grep -c -F -e '2h' "$rigTmp/ttl-bad/err" )" 0
rigScene ttl-served ttl ; rigRecord "" ""
rigServedOut="$( printf '%s' '{"skill":"rig-a"}' | ( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_SESSION_ID="$rigSpawn" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" MDAT_SPAWN_AGENT=rig-a HARNESS_INPUT_CACHE_TIME=2h bash "$rigHarness" --intern-tool Skill ) 2> /dev/null )"
rigAssert "a served call, a native client's, makes no request and is not asked: it answers whatever the variable holds"  "$( rigIn "$rigServedOut" 'RIG-A-ARMED-BODY' )" yes
rigWire="OpenAiChat"
rigCacheTime="1h" ; rigScene ttl-chat ttl ; rigRoot="$rigWs" ; rigRecord "" "" ; rigChatTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes ; rigCacheTime=""
rigAssert "the chat-completions wire has no markers to say it in: the same request"       "$( rigCount "$rigDir/req.1" 'cache_control' ):$( rigCount "$rigDir/req.1" '"ttl"' )" 0:0
rigWire="AnthropicMessages"
rigSpawn="rig-spawn-one"

echo "-- 10. magic-team.work-duty: its runs cache the text of the routine --"
rigWorkDuty="$MDLT_ORIGIN/myx/myx.distro-agents/skillset/magic-team/magic-team"
rigAssert "the routine says cache-prefix: routine, read as the spawn reads it (AgentsToolsRoutineKey)"  "$( . "$rigHere/session/AgentsTools.RoutineRequirements.include" ; AgentsToolsRoutineKey "$rigWorkDuty/magic-team.work-duty.routine.md" cache-prefix )" routine
rigAssert "and the validator takes the file"                                              "$( MDLT_ORIGIN="$MDLT_ORIGIN" bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-doc-validate routine "$rigWorkDuty/magic-team.work-duty.routine.md" > /dev/null 2>&1 ; printf 'rc=%s' "$?" )" rc=0
rigWdPolicy="$( . "$rigHere/session/AgentsTools.RoutineRequirements.include" ; AgentsToolsRoutineKey "$rigWorkDuty/magic-team.work-duty.routine.md" cache-prefix )"
rigScene wd wd ; rigRecord "$rigWdPolicy" magic-team.work-duty.routine.md
cp "$rigWorkDuty/magic-team.work-duty.routine.md" "$rigWorkDuty/magic-team.standalone.routine.md" "$rigSkills/magic-team/"
rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "a run of it carries the routine's text in its first message, once, after the armed file: its own steps, and the opening steps of the kind it requires, mixed"  "$( rigCount "$rigDir/req.1" '**work-the-input**' ):$( rigCount "$rigDir/req.1" '### session-start' ):$( rigIn "$( rigReq 1 )" 'RIG-A-ARMED-BODY' )" 1:1:yes
rigAssert "in the block of the prefetch, behind its marker, the task after it"            "$( rigMarkers "$rigDir/req.1" ):$( rigHolds "$rigDir/req.1" 'read for you before your task:' )" 4:yes
rigScene wd-none wd ; rigRecord "" magic-team.work-duty.routine.md ; rigTextStream "$rigDir/res.1" RIG-DONE ; rigRun rig-a yes
rigAssert "control: a record without the policy carries none of it, the armed file alone"  "$( rigCount "$rigDir/req.1" '**work-the-input**' ):$( rigIn "$( rigReq 1 )" 'RIG-A-ARMED-BODY' )" 0:yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PROMPT PREFETCH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PROMPT_PREFETCH: OK (%d assertions, offline)\n' "$rigPassCount"
