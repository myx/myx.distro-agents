#!/usr/bin/env bash
## Behavioural check on the shared prefix of the input token cache (F10.7 of the refactorings epic), run through the real core
## and the Anthropic Messages wire against a fake `curl` replaying canned streams, which records each request body. The API
## caches tools, then system, then messages, so what the members of a team can share is a `tools` block that is the same for
## all of them and a `system` that opens with the same bytes: the team's common instruction (magic-team.basic.md), MOVED there
## from the default skill bundle. Held:
##   1. the floor's tools are in the order of their names, and a cache marker ends them
##   2. `system` is one string for a team member: the team's identity/basic and the harness paragraph every run carries; the member
##      layer is the first block of the first user message, with a marker of its own
##   3. three markers a request, no more: the moving one at the top, the end of the floor, the end of the member block; none elsewhere
##   4. two members' requests are byte for byte the same through the team layer and the whole tool floor, and differ at the member
##      label in the first user message
##   5. no agent has no team layer: `system` is one string, two markers; magic-team itself carries the team's instruction as its own
##      basic, in a marked team block, and its member block names it
##   6. the default skill bundle of a harness run leaves the team's basic file out (the armed file stays); a served call, a native
##      client's, keeps it
##   7. round 1 says what became of the shared prefix
## Offline by construction: no socket, no credential.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
[ -f "$rigHarness" ] || { echo "⛔ ERROR: harness not found at the origin this workspace resolves: $rigHarness" >&2 ; exit 1 ; }
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPromptCachePrefixCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-mcp-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

export HARNESS_PROVIDER_NAME="prompt-cache-prefix rig"
export HARNESS_SELF_NAME="AgentsPromptCachePrefixCheck.test.sh"
export HARNESS_ENDPOINT="https://harness-prompt-cache-prefix.invalid/v1/messages"
export HARNESS_HOST="harness-prompt-cache-prefix.invalid"
export HARNESS_WIRE="AnthropicMessages"
export HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_LIGHT="rig-not-a-credential"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"
export HARNESS_OUTPUT_TOKENS_LIGHT="4101"
export HARNESS_OUTPUT_TOKENS_MAIN="4202"

## The skillset of the rig: the team's two files, and two members with their own.
rigSkills="$rigTmp/skills"
mkdir -p "$rigSkills/magic-team" "$rigSkills/rig-a" "$rigSkills/rig-b"
printf 'RIG-TEAM-COMMON-LINE one two\n' > "$rigSkills/magic-team/magic-team.basic.md"
printf 'RIG-TEAM-ARMED-BODY\n' > "$rigSkills/magic-team/magic-team.armed.md"
printf -- '---\nname: magic-team\n---\nteam skill\n' > "$rigSkills/magic-team/SKILL.md"
for rigMember in rig-a rig-b ; do
	printf 'RIG-%s-BASIC own words\n' "$( printf '%s' "${rigMember#rig-}" | tr 'a-z' 'A-Z' )" > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf 'RIG-%s-ARMED-BODY\n' "$( printf '%s' "${rigMember#rig-}" | tr 'a-z' 'A-Z' )" > "$rigSkills/$rigMember/$rigMember.armed.md"
	printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigSkills/$rigMember/SKILL.md"
done
printf -- '---\nname: magic-team\n---\nteam skill\n' > "$rigSkills/magic-team/SKILL.md"

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir"
	printf '0' > "$rigScenarioDir/round"
}
rigTextStream(){ ## canned-stream file, content, cache_creation, cache_read
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig2","type":"message","role":"assistant","content":[],"usage":{"input_tokens":60,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":1}}}\n\n' "${3:-0}" "${4:-0}"
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"%s"}}\n\n' "$2"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}
rigSkillStream(){ ## canned-stream file, the skill the model reads
	{
		printf 'event: message_start\ndata: {"type":"message_start","message":{"id":"msg_rig1","type":"message","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n\n'
		printf 'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_RIG","name":"Skill","input":{}}}\n\n'
		printf 'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"skill\\": \\"%s\\"}"}}\n\n' "$2"
		printf 'event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n'
		printf 'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":40}}\n\n'
		printf 'event: message_stop\ndata: {"type":"message_stop"}\n\n'
	} > "$1"
}
rigRun(){ ## harness arguments before the task
	RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir" MDAT_SKILLSET_ROOT="$rigSkills" \
		"$rigHarness" "$@" --access-root "$rigScenarioDir" RIG-TASK-MARKER > "$rigScenarioDir/out" 2> "$rigScenarioDir/err"
	rigRunStatus=$?
	[ "$( cat "$rigScenarioDir/round" )" != 0 ] || rigRefuse "the harness issued no request at all -- its stderr: $( head -5 "$rigScenarioDir/err" )"
}
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-request' ; return 0 ; }
	case "$( cat "$1" )" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
}
rigIn(){ ## text, needle -- yes where the text holds the needle
	case "$1" in
		*"$2"*) printf 'yes' ;;
		*) printf 'no' ;;
	esac
}
rigEndsWith(){ ## text, tail -- yes where the text ends with the tail
	case "$1" in
		*"$2") printf 'yes' ;;
		*) printf 'no' ;;
	esac
}
rigMarkers(){ ## file -- how many cache markers the request carries
	LC_ALL=C grep -o '"cache_control":{"type":"ephemeral"}' "$1" | wc -l | tr -d ' '
}
rigToolNames(){ ## file -- the names of the declared tools in the order of the request
	LC_ALL=C sed -e 's/.*"tools":\[//' -e 's/\],"tool_choice".*//' "$1" | LC_ALL=C grep -o '{"name":"[A-Za-z0-9_]*","description"' | LC_ALL=C sed -e 's/{"name":"//' -e 's/","description"//'
}
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

echo "-- two members: the same tools, the same opening of system --"
rigStart member-a ; rigTextStream "$rigScenarioDir/res.1" RIG-DONE ; rigRun --agent rig-a ; rigA="$rigScenarioDir"
rigStart member-b ; rigTextStream "$rigScenarioDir/res.1" RIG-DONE ; rigRun --agent rig-b ; rigB="$rigScenarioDir"
rigAssert "the run ends normally"                                                  "$rigRunStatus" 0
rigTeamOpen='{"type":"text","text":"## Team-wide -- the same for every member and every session of this team\n\nRIG-TEAM-COMMON-LINE one two'
rigAssert "system is one string: the team identity/basic, the team's armed floor and the harness paragraph every run carries"  "$( rigHolds "$rigA/req.1" '"system":"## Team-wide -- the same for every member and every session of this team\n\nRIG-TEAM-COMMON-LINE one two\n\nRIG-TEAM-ARMED-BODY\n\nUse the given tools to accomplish the request' )" yes
rigAssert "the team's armed floor is in the system text, once, and no team+ layer follows the floor"  "$( LC_ALL=C grep -o 'RIG-TEAM-ARMED-BODY' "$rigA/req.1" | wc -l | tr -d ' ' ):$( LC_ALL=C grep -c '## Team+' "$rigA/req.1" )" "1:0"
rigAssert "the member layer is the first block of the first user message, with its own marker"  "$( rigHolds "$rigA/req.1" '"role":"user","content":[{"type":"text","text":"## Your role -- the same for every session of rig-a\n\nRIG-A-BASIC own words' )" yes
rigAssert "the other member's label and own words are the same block, after the same system and tools"  "$( rigHolds "$rigB/req.1" '"role":"user","content":[{"type":"text","text":"## Your role -- the same for every session of rig-b\n\nRIG-B-BASIC own words' )" yes
rigAssert "three markers a request: the moving one, the end of the floor, the end of the member block" "$( rigMarkers "$rigA/req.1" )" 3
rigAssert "the marker of the floor ends its tools (no MCP tool follows here)"      "$( rigHolds "$rigA/req.1" '"cache_control":{"type":"ephemeral"}}],"tool_choice"' )" yes
rigAssert "one marker stands in the messages: the member's own block"               "$( LC_ALL=C sed 's/.*"messages":\[//' "$rigA/req.1" | LC_ALL=C grep -c 'cache_control' )" 1
rigToolNames "$rigA/req.1" > "$rigTmp/names.a" ; rigToolNames "$rigB/req.1" > "$rigTmp/names.b"
rigAssert "the floor's tools are in the order of their names"                       "$( LC_ALL=C sort -c "$rigTmp/names.a" 2>&1 && printf sorted )" sorted
rigAssert "and there are many of them, the same in both requests"                   "$( [ "$( wc -l < "$rigTmp/names.a" | tr -d ' ' )" -gt 20 ] && cmp -s "$rigTmp/names.a" "$rigTmp/names.b" && printf same )" same
rigDiffAt="$( cmp -l "$rigA/req.1" "$rigB/req.1" 2>/dev/null | head -1 | LC_ALL=C awk '{ print $1 }' )"
rigCommonPart="$( head -c "$(( ${rigDiffAt:-1} - 1 ))" "$rigA/req.1" )"
rigThrough="$( rigIn "$rigCommonPart" 'RIG-TEAM-COMMON-LINE one two' )$( rigIn "$rigCommonPart" 'Use the given tools to accomplish the request' )"
rigAssert "two members' requests are the same bytes through the team layer and the whole tool floor" "$rigThrough" yesyes
rigAssert "and differ after it: the first differing byte is the member's name in the role label"  "$( tail -c +"${rigDiffAt:-1}" "$rigA/req.1" | head -c 1 )" "a"
rigAssert "the common part ends at the member label"                                "$( rigEndsWith "$rigCommonPart" '## Your role -- the same for every session of rig-' )" yes
rigAssert "the common instruction is in the system and nowhere else"                "$( LC_ALL=C grep -o 'RIG-TEAM-COMMON-LINE' "$rigA/req.1" | wc -l | tr -d ' ' )" 1

echo "-- no agent, and magic-team itself: no common block --"
rigStart no-agent ; rigTextStream "$rigScenarioDir/res.1" RIG-DONE ; rigRun
rigAssert "a run with no agent has one string for system"                            "$( rigHolds "$rigScenarioDir/req.1" '"system":"' )" yes
rigAssert "and two markers: the moving one and the end of the floor"                "$( rigMarkers "$rigScenarioDir/req.1" )" 2
rigStart team-itself ; rigTextStream "$rigScenarioDir/res.1" RIG-DONE ; rigRun --agent magic-team
rigAssert "magic-team itself carries the team's instruction as its own basic, in the team system string"  "$( rigHolds "$rigScenarioDir/req.1" '"system":"## Team-wide -- the same for every member and every session of this team\n\nRIG-TEAM-COMMON-LINE one two' )" yes
rigAssert "and the team's armed floor as well: every member run, magic-team included"  "$( LC_ALL=C grep -o 'RIG-TEAM-ARMED-BODY' "$rigScenarioDir/req.1" | wc -l | tr -d ' ' )" 1
rigAssert "and its member block names magic-team, with no second copy of the team file"  "$( rigHolds "$rigScenarioDir/req.1" '"role":"user","content":[{"type":"text","text":"## Your role -- the same for every session of magic-team' ):$( LC_ALL=C grep -o 'RIG-TEAM-COMMON-LINE' "$rigScenarioDir/req.1" | wc -l | tr -d ' ' )" yes:1
rigAssert "three markers: the moving one, the end of the floor, the end of the member block"  "$( rigMarkers "$rigScenarioDir/req.1" )" 3

echo "-- the default skill bundle --"
rigStart bundle ; rigSkillStream "$rigScenarioDir/res.1" rig-a ; rigTextStream "$rigScenarioDir/res.2" RIG-DONE ; rigRun --agent rig-a
rigBundle="$( LC_ALL=C sed 's/.*"messages":\[//' "$rigScenarioDir/req.2" )"
rigAssert "the bundle of a harness run holds the member's basic and armed files"    "$( rigIn "$rigBundle" RIG-A-BASIC )$( rigIn "$rigBundle" RIG-A-ARMED-BODY )" yesyes
rigAssert "and the team's armed file"                                                "$( rigIn "$rigBundle" RIG-TEAM-ARMED-BODY )" yes
rigAssert "but not the team's basic file, which the system text carries"             "$( rigIn "$rigBundle" RIG-TEAM-COMMON-LINE )" no
rigServed="$( printf '%s' '{"skill":"rig-a"}' | MMDAPP="$rigScenarioDir" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=rig-a "$rigHarness" --intern-tool Skill 2> /dev/null )"
rigAssert "a served call, a native client's, keeps the team's basic file in its bundle"  "$( rigIn "$rigServed" RIG-TEAM-COMMON-LINE )$( rigIn "$rigServed" RIG-TEAM-ARMED-BODY )" yesyes

echo "-- round 1 says what became of the shared prefix --"
rigStart wrote ; rigTextStream "$rigScenarioDir/res.1" RIG-DONE 5000 0 ; rigRun --agent rig-a
rigAssert "written: it says so"                                                      "$( rigHolds "$rigScenarioDir/err" 'shared prefix -- round 1 wrote 5000 tokens to the cache' )" yes
rigStart read ; rigTextStream "$rigScenarioDir/res.1" RIG-DONE 0 4900 ; rigRun --agent rig-a
rigAssert "read: it says so"                                                         "$( rigHolds "$rigScenarioDir/err" 'shared prefix -- round 1 read 4900 tokens from the cache' )" yes
rigStart neither ; rigTextStream "$rigScenarioDir/res.1" RIG-DONE 0 0 ; rigRun --agent rig-a
rigAssert "neither: it says the prefix cached nothing and why"                       "$( rigHolds "$rigScenarioDir/err" 'shared prefix -- round 1 cached nothing' )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PROMPT CACHE PREFIX CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PROMPT_CACHE_PREFIX: OK (%d assertions, offline)\n' "$rigPassCount"
