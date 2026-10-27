#!/usr/bin/env bash
## Behavioural check on the layers of the prefix cache (F10.7 of the refactorings epic), run through the real core on the OpenAI
## chat wire -- the wire DeepSeek speaks -- against a fake `curl` replaying canned streams, which records each request body. The
## provider caches an exact prefix from the first token, so everything before the first differing byte of two requests is read from
## the cache and everything after it is paid for again. The request is laid out most-shared first, each layer labelled:
##   tools      the 95 KB floor, before the messages, identical for every member
##   team       in the system message: the team's basic file, the team's armed file (the armed floor of every session kind) and the
##              harness paragraph -- identical for every member and every session of the team
##   member     in the first user message, after the tools: the member's basic file, the sentence of its armed file and its stable
##              roots, then the prefetch block (the member's armed file, and the task's named reads) -- identical for every session of
##              that member
##   session    the routine where the spawn record declares `cache-prefix: routine`; a work-duty's dispatch (its routine, its member's
##              static guidance and then its own variables) where the routine is `armed`; the task's reads and the run's own notes
## Held:
##   1. every kind's prefix carries team basic + team armed + tools; two sessions of DIFFERENT members share that whole team layer and
##      first differ at the member label
##   2. two sessions of ONE member share tools, team and member, and first differ in the session layer
##   3. two work-duty runs of one member share the prefix, the routine and the member's static guidance before their variables: the
##      dispatch's static head is byte-identical, and the first difference is in its `## This run` variables
##   4. an epic and a plain spawn carry the same team prefix and no + layer; a routine-policy spawn still preloads its routine
##   5. no `team+` or `member+` layer and no `armed-extended` marker is in a request of a session that is no work-duty, or where the skillset holds no
##      extended file; a work-duty's request carries the team's extended file after the team layer and its member's after the member's armed content
##   6. the system message is the team layer and nothing else; no per-run byte (spawn id, sandbox, dispatch, task) is before the
##      session layer; a work-duty's run notes come after its variables
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
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPromptCacheLayersCheck )" || exit 1
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
rigCount(){ ## file, text -- how many times the file holds the text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C grep -o -F -- "$2" "$1" | wc -l | tr -d ' '
}
rigOffset(){ ## file, literal text -- the byte offset of its first occurrence, 0-based; empty where it is absent
	LC_ALL=C grep -b -o -F -- "$2" "$1" 2>/dev/null | head -1 | LC_ALL=C cut -d: -f1
}
rigLastOffset(){ ## file, literal text -- the byte offset of its last occurrence, 0-based; empty where it is absent
	LC_ALL=C grep -b -o -F -- "$2" "$1" 2>/dev/null | tail -1 | LC_ALL=C cut -d: -f1
}

## The skillset of the rig: the team's common instruction and armed file, a second team file a task may name a section of, two
## members with their own basic and armed files and references, the work-duty routine with its kind routine, an epic routine and a
## routine that declares the routine prefix. The armed floors are long on purpose: they stand for the ~30 KB a real member carries,
## so a layer is far larger than the model's own preamble.
rigSkills="$rigTmp/skills"
rigSectionA="RIG-TEAM-SECTION-ONE a section a task names"
mkdir -p "$rigSkills/magic-team" "$rigSkills/rig-a" "$rigSkills/rig-b"
printf 'RIG-TEAM-COMMON-LINE one two\n' > "$rigSkills/magic-team/magic-team.basic.md"
{
	printf '# %s\n\n' "$rigSectionA"
	rigLine=0
	while [ "$rigLine" -lt 60 ] ; do
		printf 'RIG-TEAM-ARMED-LINE-%03d the team armed floor every session kind carries\n' "$rigLine"
		rigLine=$(( rigLine + 1 ))
	done
	printf '\n# Something else\n\nRIG-TEAM-UNNAMED\n'
} > "$rigSkills/magic-team/magic-team.armed.md"
printf '# Negotiations\n\n# %s\n\nRIG-TEAM-NEGOTIATIONS-SECTION\n' "$rigSectionA" > "$rigSkills/magic-team/magic-team.negotiations.md"
printf -- '---\nname: magic-team\n---\nteam skill\n' > "$rigSkills/magic-team/SKILL.md"
printf -- '---\nrequires-session-kind: standalone\ncache-prefix: extended\n---\n# magic-team.work-duty.routine — the actual procedure\n\n# Summary\n\nThe rig duty.\n\n# Opening steps\n\n1. **rig-own-open**: RIG-ROUTINE-OPENING.\n\n# Steps\n\n1. **rig-own-work**: work.\n\n# Closure steps\n\n1. **rig-own-close**: close.\n' > "$rigSkills/magic-team/magic-team.work-duty.routine.md"
printf -- '---\nrequires-session-kind: coworking\n---\n# magic-team.standalone.routine — the kind routine\n\n# Opening steps\n\n1. **rig-kind-open**: RIG-KIND-OPENING.\n' > "$rigSkills/magic-team/magic-team.standalone.routine.md"
printf -- '---\nrequires-session-kind: coworking\ncache-prefix: routine\n---\n# magic-team.rigroutine.routine — the actual procedure\n\n# Summary\n\nA rig routine that preloads its own text.\n\n# Opening steps\n\n1. **rig-routine-open**: RIG-ROUTINE-POLICY-OPENING.\n' > "$rigSkills/magic-team/magic-team.rigroutine.routine.md"
printf -- '---\nrequires-session-kind: coworking\n---\n# magic-team.epic.routine — the actual procedure\n\n# Opening steps\n\n1. **RIG-EPIC-OPENING**: the epic procedure, the same file for every epic.\n' > "$rigSkills/magic-team/magic-team.epic.routine.md"
printf -- '---\nrequires-session-kind: coworking\n---\n# magic-team.coworking.routine — the kind routine\n\n# Opening steps\n\n1. **rig-kind-worker-open**: open.\n' > "$rigSkills/magic-team/magic-team.coworking.routine.md"
for rigMember in rig-a rig-b ; do
	rigTag="$( printf '%s' "${rigMember#rig-}" | LC_ALL=C tr 'a-z' 'A-Z' )"
	printf 'RIG-%s-BASIC own words\n' "$rigTag" > "$rigSkills/$rigMember/$rigMember.basic.md"
	{
		printf -- '---\nstatus: rig\n---\n# %s -- armed content\n' "$rigMember"
		rigLine=0
		while [ "$rigLine" -lt 120 ] ; do
			printf 'RIG-%s-ARMED-LINE-%03d the floor of this member, carried by every one of its runs\n' "$rigTag" "$rigLine"
			rigLine=$(( rigLine + 1 ))
		done
	} > "$rigSkills/$rigMember/$rigMember.armed.md"
	printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigSkills/$rigMember/SKILL.md"
	mkdir -p "$rigSkills/$rigMember/reference"
	printf 'RIG-%s-REFERENCE the member static guidance a work-duty carries\n' "$rigTag" > "$rigSkills/$rigMember/reference/static.md"
done

rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/spawned"
rigChatEnd(){ printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-DONE"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' > "$1" ; }
rigChatCall(){ ## stream file, tool name, arguments JSON
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call-1","type":"function","function":{"name":"%s","arguments":"%s"}}]},"finish_reason":null}]}\n' \
		"$2" "$( printf '%s' "$3" | sed 's/\\/\\\\/g; s/"/\\"/g' )" > "$1"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' >> "$1"
	printf 'data: [DONE]\n' >> "$1"
}
## The console's leg branch passes the member's roots and nothing of this run (AgentsConsoleShellScript.template.sh): the harness adds
## the spawn's own sandbox after it has taken the roots the system text names. 1 runs a legacy console, which still passes them, to hold
## the harness's own filter of them.
rigLegacyConsole=0
rigSpawn(){ ## tag, member, policy, routine, dispatch, own routine (the record's `routine:`, as a work-duty's says) -- one spawn; its request body in $rigTmp/spawn.<tag>/req.1
	local tag="$1" member="$2" policy="$3" routine="$4" dispatch="$5" ownRoutine="${6:-}"
	local dir="$rigTmp/spawn.$tag" sandbox="$rigWs/.local/agents/spawned/$tag" sid="$tag"
	local spawnRoots=( --access-read-root "$rigWs" --access-read-root "$rigSkills" --access-write-root "$rigSkills" )
	[ "$rigLegacyConsole" != 1 ] || spawnRoots+=( --access-read-root "$sandbox/input" --access-write-root "$sandbox/output" )
	mkdir -p "$dir" "$sandbox/input" "$sandbox/output"
	printf '0' > "$dir/round"
	{
		printf -- '---\nspawn-id: %s\nparent-spawn-id: none\n' "$sid"
		[ -z "$policy" ] || printf 'cache-prefix: %s\n' "$policy"
		[ -z "$routine" ] || printf 'prefix-routine: %s\n' "$routine"
		[ -z "$ownRoutine" ] || printf 'routine: %s\n' "$ownRoutine"
		printf 'status: spawn-started\n---\n\n# Spawn session: %s\n' "$sid"
	} > "$sandbox/$sid.spawn.md"
	rigChatEnd "$dir/res.1"
	( cd "$rigWs" || exit 1
		env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" \
			MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
			MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_SESSION_ID="$sid" MDAT_SPAWN_SANDBOX_ROOT="$sandbox" \
			MDAT_SPAWN_AGENT="$member" MDAT_SESSION_ID="rig-cowork" \
			MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 MDAT_HARNESS_PREFETCH=on \
			RIG_SCENARIO="$dir" \
			HARNESS_PROVIDER_NAME="spawn layers rig" HARNESS_SELF_NAME="AgentsPromptCacheLayersCheck.test.sh" \
			HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none" \
			HARNESS_ENDPOINT="https://harness-spawn-layers.invalid/v1/chat/completions" HARNESS_HOST="harness-spawn-layers.invalid" \
			HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" \
			HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
			HARNESS_OUTPUT_TOKENS_LIGHT="4101" HARNESS_OUTPUT_TOKENS_MAIN="4202" \
			bash "$rigHarness" --agent "$member" --tier normal --session-id "$sid" \
				"${spawnRoots[@]}" \
				"$dispatch" ) > "$dir/out" 2> "$dir/err"
	rigRunStatus=$?
	[ -f "$dir/req.1" ] || rigRefuse "the $tag spawn issued no request at all -- its stderr: $( head -5 "$dir/err" )"
}
## A work-duty dispatch, as AgentsTools.WorkDutyDispatch.include builds it: the static head (routine + member static guidance) and
## this run's variables. The head is the builder's, byte for byte, so two runs can be compared before their variables.
rigWorkDutyHead(){ ## member
	( export MMDAPP="$rigWs" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN"
		. "$rigHere/session/AgentsTools.WorkDutyDispatch.include"
		AgentsToolsWorkDutyDispatchHead "$rigSkills/magic-team/magic-team.work-duty.routine.md" "$rigSkills" "$1" )
}
rigWorkDutyDispatch(){ ## tag, member
	local rigWdTag="$1" rigWdMember="$2" rigWdHead="" rigWdVars=""
	rigWdHead="$( rigWorkDutyHead "$rigWdMember" )" || rigRefuse "the work-duty dispatch head could not be built for $rigWdMember"
	rigWdVars="$( ( export MMDAPP="$rigWs" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN"
		. "$rigHere/session/AgentsTools.WorkDutyDispatch.include"
		AgentsToolsWorkDutyDispatchVariables "$rigWdTag" "$rigWdTag" "2026-10-26 14:00 UTC" "" ) )" || rigRefuse "the work-duty dispatch variables could not be built"
	printf '%s\n\n%s' "$rigWdHead" "$rigWdVars"
}
rigToolsAt(){ rigOffset "$1" '"tools":[' ; }
rigMessagesAt(){ rigOffset "$1" '"messages":[' ; }
rigSystemEnd(){ rigOffset "$1" '"role":"user"' ; }
rigSystemBytes(){ ## request file -- everything before the first message: model, the tool floor, the system message
	head -c "$( rigSystemEnd "$1" )" "$1"
}
rigDiffAt(){ ## request file, request file -- the 0-based byte of their first difference
	cmp -l "$1" "$2" 2>/dev/null | head -1 | LC_ALL=C awk '{ print $1 - 1 }'
}
rigTeamEnd(){ ## request file -- the first byte of the member label, where the team layer ends
	LC_ALL=C grep -b -o -F -- '## Your role -- the same for every session of ' "$1" 2>/dev/null | head -1 | LC_ALL=C cut -d: -f1
}
rigSessionAt(){ ## request file -- the first byte of the session layer: the work-duty dispatch, the routine, the task's reads, the run notes
	local at
	at="$( rigOffset "$1" '## Work-duty dispatch --' )"
	[ -n "$at" ] || at="$( rigOffset "$1" '## This session -- the routine' )"
	[ -n "$at" ] || at="$( rigOffset "$1" '## This session -- what its task tells you to read' )"
	[ -n "$at" ] || at="$( rigOffset "$1" '## This session -- what is yours for this run alone' )"
	printf '%s' "$at"
}
rigNoTeamPlus(){ ## request file -- 1 where no + layer and no extended marker is anywhere in it
	[ "$( rigCount "$1" '## Team+' ):$( rigCount "$1" '## Member+' ):$( rigCount "$1" 'armed-extended' )" = "0:0:0" ] && printf 1 || printf 0
}

echo "-- 1. every kind starts with team basic + team armed + tools; two members share it whole --"
rigSpawn a-armed-1 rig-a "" "" 'DISPATCH-A-ONE
RIG-TASK-A1'
rigSpawn b-armed-1 rig-b "" "" 'DISPATCH-B-ONE
RIG-TASK-B1'
rigA1="$rigTmp/spawn.a-armed-1/req.1" ; rigB1="$rigTmp/spawn.b-armed-1/req.1"
rigTeamEndA="$( rigTeamEnd "$rigA1" )"
rigDiffAB="$( rigDiffAt "$rigA1" "$rigB1" )"
rigAssert "both spawns end normally on one request"                              "$rigRunStatus" 0
rigAssert "the team layer opens with its own label"                             "$( rigCount "$rigA1" '## Team-wide -- the same for every member and every session of this team' )" 1
rigAssert "the team layer holds the team's common instruction, the team's armed floor and the harness paragraph every run carries" \
	"$( rigCount "$rigA1" 'RIG-TEAM-COMMON-LINE one two' ):$( rigCount "$rigA1" 'RIG-TEAM-ARMED-LINE-000' ):$( rigCount "$rigA1" 'RIG-TEAM-ARMED-LINE-059' ):$( rigCount "$rigA1" 'Use the given tools to accomplish the request' )" "1:1:1:1"
rigAssert "the armed floor is one copy: the whole team file, not a team+ block"   "$( rigCount "$rigA1" 'RIG-TEAM-ARMED-LINE-000' ):$( rigNoTeamPlus "$rigA1" )" "1:1"
rigAssert "the team layer is the same bytes in both members' sessions"           "$( [ -n "$rigDiffAB" ] && [ -n "$rigTeamEndA" ] && [ "$rigDiffAB" -ge "$rigTeamEndA" ] && printf shared || printf differ )" shared
rigAssert "and it does not hold either member's own words: the member label is the first difference" \
	"$( [ "$rigDiffAB" -ge "$rigTeamEndA" ] && [ "$rigDiffAB" -lt "$( rigOffset "$rigA1" 'RIG-A-BASIC own words' )" ] && printf at-member )" at-member
rigAssert "the member label names the member and follows the team layer"         "$( rigCount "$rigA1" '## Your role -- the same for every session of rig-a' ):$( rigCount "$rigB1" '## Your role -- the same for every session of rig-b' )" "1:1"
rigAssert "the request puts the tool floor before the messages, so the floor is inside the shared prefix" \
	"$( [ -n "$( rigToolsAt "$rigA1" )" ] && [ -n "$( rigMessagesAt "$rigA1" )" ] && [ "$( rigToolsAt "$rigA1" )" -lt "$( rigMessagesAt "$rigA1" )" ] && printf before )" before
rigToolsA="$( LC_ALL=C sed -e 's/.*"tools":\[//' -e 's/\],"messages":.*//' "$rigA1" )"
rigToolsB="$( LC_ALL=C sed -e 's/.*"tools":\[//' -e 's/\],"messages":.*//' "$rigB1" )"
rigAssert "the tool floor is the same bytes for two different members"            "$( [ -n "$rigToolsA" ] && [ "$rigToolsA" = "$rigToolsB" ] && printf same || printf differ )" same
rigAssert "the first difference of two members is after the tool floor and at the member label" \
	"$( [ "$rigDiffAB" -ge "$( rigTeamEnd "$rigA1" )" ] && [ "$rigDiffAB" -ge "$( rigMessagesAt "$rigA1" )" ] && printf after-floor )" after-floor

echo "-- 1b. a task's reads do not reach the system text: two sessions of one member differ only in the session layer --"
rigSpawn a-armed-sec rig-a "" "" "DISPATCH-A-SEC
RIG-TASK-A-SEC {name: magic-team, file: magic-team.negotiations.md, section: $rigSectionA}"
rigAsec="$rigTmp/spawn.a-armed-sec/req.1"
rigSystemA1="$( rigSystemBytes "$rigA1" )" ; rigSystemAsec="$( rigSystemBytes "$rigAsec" )"
rigAssert "a task that names a section leaves the system text (model, floor, system message) byte for byte the same" \
	"$( [ -n "$rigSystemA1" ] && [ "$rigSystemA1" = "$rigSystemAsec" ] && printf same || printf differ )" same
rigAssert "and the two sessions first differ in the session layer, where the section read belongs" \
	"$( [ "$( rigDiffAt "$rigA1" "$rigAsec" )" -ge "$( rigSessionAt "$rigAsec" )" ] && printf session || printf earlier )" session
rigAssert "the section read is labelled as this session's, after the member layer" \
	"$( [ "$( rigLastOffset "$rigAsec" 'RIG-TEAM-SECTION-ONE' )" -gt "$( rigOffset "$rigAsec" 'RIG-A-ARMED-LINE-119' )" ] && [ "$( rigLastOffset "$rigAsec" 'RIG-TEAM-SECTION-ONE' )" -gt "$( rigOffset "$rigAsec" '## This session -- what its task tells you to read' )" ] && printf in-session )" in-session
rigPrefixAsec="$( head -c "$( rigSessionAt "$rigAsec" )" "$rigAsec" )"
rigAssert "no byte of the run (its spawn id, sandbox, session, dispatch) is before the session layer" \
	"$( printf '%s' "$rigPrefixAsec" | LC_ALL=C grep -c -E 'spawn\.a-armed-sec|a-armed-sec|/spawned/|RIG-TASK-A-SEC|DISPATCH-A-SEC' )" 0

echo "-- 2. member layer: two sessions of one member share team and member --"
rigSpawn a-armed-2 rig-a "" "" 'DISPATCH-A-TWO
RIG-TASK-A2'
rigA2="$rigTmp/spawn.a-armed-2/req.1"
rigDiffA12="$( rigDiffAt "$rigA1" "$rigA2" )"
rigSessionA1="$( rigSessionAt "$rigA1" )"
rigAssert "the member layer opens with its own label and the member's own words"  "$( rigCount "$rigA1" "## Your role's armed content -- the same for every session of rig-a" ):$( rigCount "$rigA1" 'RIG-A-BASIC own words' )" "1:1"
rigAssert "the armed floor is in the member layer whole, once"  "$( [ "$( rigCount "$rigA1" 'RIG-A-ARMED-LINE-000' )" = 1 ] && [ "$( rigCount "$rigA1" 'RIG-A-ARMED-LINE-119' )" = 1 ] && printf yes )" yes
rigAssert "two sessions of one member are the same bytes through the member layer"  "$( [ -n "$rigDiffA12" ] && [ -n "$rigSessionA1" ] && [ "$rigDiffA12" -ge "$rigSessionA1" ] && printf shared || printf differ )" shared
rigAssert "and the member layer holds the member's armed floor before the task block" \
	"$( [ "$( rigOffset "$rigA1" 'RIG-A-ARMED-LINE-000' )" -lt "$rigSessionA1" ] && printf before )" before

echo "-- 3. work-duty: the routine and the member static guidance are the dispatch's head, the variables its tail --"
rigWorkDutyDispatch a-wd-1 rig-a > "$rigTmp/wd-dispatch.1"
rigWorkDutyDispatch a-wd-2 rig-a > "$rigTmp/wd-dispatch.2"
rigWorkDutyDispatch b-wd-1 rig-b > "$rigTmp/wd-dispatch.b"
rigSpawn a-wd-1 rig-a extended "" "$( cat "$rigTmp/wd-dispatch.1" )"
rigSpawn a-wd-2 rig-a extended "" "$( cat "$rigTmp/wd-dispatch.2" )"
rigSpawn b-wd-1 rig-b extended "" "$( cat "$rigTmp/wd-dispatch.b" )"
rigWd1="$rigTmp/spawn.a-wd-1/req.1" ; rigWd2="$rigTmp/spawn.a-wd-2/req.1" ; rigWdBs="$rigTmp/spawn.b-wd-1/req.1"
rigWorkDutyHead a > "$rigTmp/wd-head.a1"
rigWorkDutyHead a > "$rigTmp/wd-head.a2"
rigSessionWd="$( rigSessionAt "$rigWd1" )"
rigWdVars="$( rigOffset "$rigWd1" '## This run -- its own variables' )"
rigAssert "the dispatch's static head is byte-identical across two work-duty runs of one member" \
	"$( cmp -s "$rigTmp/wd-head.a1" "$rigTmp/wd-head.a2" && printf same || printf differ )" same
rigAssert "the dispatch carries the routine alone, and the member's reference is one copy, in the Member+ layer before the session layer (cache-prefix: extended)" \
	"$( rigCount "$rigWd1" 'RIG-ROUTINE-OPENING' ):$( rigCount "$rigWd1" 'RIG-A-REFERENCE' ):$( [ "$( rigOffset "$rigWd1" 'RIG-A-REFERENCE' )" -lt "$rigSessionWd" ] && printf before )" "1:1:before"
rigAssert "the routine is the dispatch's, not a prefetched block: the harness adds no routine for cache-prefix: extended" \
	"$( rigCount "$rigWd1" '## This session -- the routine' ):$( rigCount "$rigWd1" '## The routine -- carried here' )" "0:1"
rigAssert "the member's reference is before the variables, and the variables are last" \
	"$( [ -n "$rigWdVars" ] && [ "$( rigOffset "$rigWd1" 'RIG-A-REFERENCE' )" -lt "$rigWdVars" ] && [ "$( rigOffset "$rigWd1" 'RIG-ROUTINE-OPENING' )" -lt "$rigWdVars" ] && printf ordered )" ordered
rigAssert "two work-duty runs share the whole prefix, the routine and the guidance before their variables" \
	"$( { [ -n "$( rigDiffAt "$rigWd1" "$rigWd2" )" ] && [ "$( rigDiffAt "$rigWd1" "$rigWd2" )" -ge "$rigWdVars" ] ; } && printf shared || printf differ )" shared
rigAssert "a work-duty's request carries team basic, team armed and the tools like every other kind" \
	"$( rigCount "$rigWd1" 'RIG-TEAM-COMMON-LINE one two' ):$( rigCount "$rigWd1" 'RIG-TEAM-ARMED-LINE-000' ):$( [ -n "$( rigToolsAt "$rigWd1" )" ] && printf tools )" "1:1:tools"
rigAssert "a work-duty's run notes come after its variables, so no per-run root splits the static bytes" \
	"$( [ "$( rigOffset "$rigWd1" '## This session -- what is yours for this run alone' )" -gt "$rigWdVars" ] && printf after )" after
rigAssert "two work-duty sessions of different members share the whole team layer and differ at the member label" \
	"$( { [ -n "$( rigDiffAt "$rigWd1" "$rigWdBs" )" ] && [ "$( rigDiffAt "$rigWd1" "$rigWdBs" )" -ge "$( rigTeamEnd "$rigWd1" )" ] ; } && printf team-plus || printf more )" team-plus
rigAssert "a work-duty and a plain spawn of one member differ at the Member+ layer, after the team layer and the member's armed content" \
	"$( [ "$( rigDiffAt "$rigA1" "$rigWd1" )" -ge "$( rigOffset "$rigWd1" '## Member+ -- ' )" ] && printf member-plus || printf earlier )" member-plus
rigAssert "a work-duty of cache-prefix: extended carries the Member+ layer once and no Team+ layer (it has no content), and no armed-extended marker" \
	"$( rigCount "$rigWd1" '## Member+ -- ' ):$( rigCount "$rigWd1" '## Team+' ):$( rigCount "$rigWd1" 'armed-extended' )" "1:0:0"

echo "-- 3b. the + layers: a work-duty carries the team's extended file and its member's reference files after the team and member layers; no other session does --"
## The extended files are optional skillset files: magic-team/magic-team.armed-extended.md after the team layer, <member>/<member>.armed-extended.md after the
## member's armed content. Written here, after the sections above, so none of them sees one.
printf 'RIG-TEAM-PLUS-LINE the team static knowledge only a work-duty preloads\n' > "$rigSkills/magic-team/magic-team.armed-extended.md"
rigWdRoutine=magic-team.work-duty.routine.md
rigSpawn a-plain-plus rig-a "" "" 'DISPATCH-A-PLAIN-PLUS
RIG-TASK-APP'
rigSpawn a-wdplus-1 rig-a extended "" "$( rigWorkDutyDispatch a-wdplus-1 rig-a )" "$rigWdRoutine"
rigSpawn a-wdplus-2 rig-a extended "" "$( rigWorkDutyDispatch a-wdplus-2 rig-a )" "$rigWdRoutine"
rigSpawn b-wdplus-1 rig-b extended "" "$( rigWorkDutyDispatch b-wdplus-1 rig-b )" "$rigWdRoutine"
rigPlain="$rigTmp/spawn.a-plain-plus/req.1" ; rigWp1="$rigTmp/spawn.a-wdplus-1/req.1" ; rigWp2="$rigTmp/spawn.a-wdplus-2/req.1" ; rigWpB="$rigTmp/spawn.b-wdplus-1/req.1"
rigAssert "a plain spawn carries neither the team's extended file nor the member's reference, though both stand in the skillset" "$( rigCount "$rigPlain" 'RIG-TEAM-PLUS-LINE' ):$( rigCount "$rigPlain" 'RIG-A-REFERENCE' ):$( rigCount "$rigPlain" '## Team+' ):$( rigCount "$rigPlain" '## Member+' )" "0:0:0:0"
rigAssert "a work-duty carries the team's extended file once, under its own label, and its member's once" \
	"$( rigCount "$rigWp1" '## Team+ -- ' ):$( rigCount "$rigWp1" 'RIG-TEAM-PLUS-LINE' ):$( rigCount "$rigWp1" '## Member+ -- ' ):$( rigCount "$rigWp1" 'RIG-A-REFERENCE' )" "1:1:1:1"
rigAssert "the order is team, team+, member, member armed content, member+, then the session layer" \
	"$( [ "$( rigOffset "$rigWp1" 'RIG-TEAM-ARMED-LINE-059' )" -lt "$( rigOffset "$rigWp1" 'RIG-TEAM-PLUS-LINE' )" ] && [ "$( rigOffset "$rigWp1" 'RIG-TEAM-PLUS-LINE' )" -lt "$( rigOffset "$rigWp1" '## Your role -- the same for every session of rig-a' )" ] && [ "$( rigOffset "$rigWp1" 'RIG-A-BASIC own words' )" -lt "$( rigOffset "$rigWp1" 'RIG-A-ARMED-LINE-119' )" ] && [ "$( rigOffset "$rigWp1" 'RIG-A-ARMED-LINE-119' )" -lt "$( rigOffset "$rigWp1" 'RIG-A-REFERENCE' )" ] && [ "$( rigOffset "$rigWp1" 'RIG-A-REFERENCE' )" -lt "$( rigSessionAt "$rigWp1" )" ] && printf ordered )" ordered
rigAssert "the system message is the team layer still: neither + layer is in it, and it is byte for byte a plain spawn's" \
	"$( rigCount "$rigWp1" '## Team+ -- ' ) $( [ "$( rigSystemBytes "$rigWp1" )" = "$( rigSystemBytes "$rigPlain" )" ] && printf same || printf differ )" "1 same"
rigAssert "two work-duty runs of one member share the + layers whole and first differ in the session layer" \
	"$( [ "$( rigDiffAt "$rigWp1" "$rigWp2" )" -ge "$( rigSessionAt "$rigWp1" )" ] && [ "$( rigDiffAt "$rigWp1" "$rigWp2" )" -gt "$( rigOffset "$rigWp1" 'RIG-A-REFERENCE' )" ] && printf shared || printf earlier )" shared
rigAssert "two work-duty runs of different members share the team layer and the team+ layer, and first differ at the member label" \
	"$( [ "$( rigDiffAt "$rigWp1" "$rigWpB" )" -ge "$( rigTeamEnd "$rigWp1" )" ] && [ "$( rigDiffAt "$rigWp1" "$rigWpB" )" -gt "$( rigOffset "$rigWp1" 'RIG-TEAM-PLUS-LINE' )" ] && printf at-member || printf earlier )" at-member
rigAssert "another member has the team+ layer and its own Member+ layer: its reference, not the first member's" "$( rigCount "$rigWpB" 'RIG-TEAM-PLUS-LINE' ):$( rigCount "$rigWpB" '## Member+ -- ' ):$( rigCount "$rigWpB" 'RIG-B-REFERENCE' ):$( rigCount "$rigWpB" 'RIG-A-REFERENCE' )" "1:1:1:0"

echo "-- 4. epic and routine: the same team prefix; only the routine policy preloads a routine --"
rigSpawn a-epic-1 rig-a "" magic-team.epic.routine.md 'DISPATCH-EPIC-ONE
RIG-TASK-E1'
rigSpawn a-routine-1 rig-a routine magic-team.rigroutine.routine.md 'DISPATCH-R-ONE
RIG-TASK-R1'
rigEpic1="$rigTmp/spawn.a-epic-1/req.1" ; rigRoutine1="$rigTmp/spawn.a-routine-1/req.1"
rigAssert "an epic carries the same team basic, team armed and tools as a plain spawn" \
	"$( rigCount "$rigEpic1" 'RIG-TEAM-COMMON-LINE one two' ):$( rigCount "$rigEpic1" 'RIG-TEAM-ARMED-LINE-000' ):$( [ -n "$( rigToolsAt "$rigEpic1" )" ] && printf tools )" "1:1:tools"
rigAssert "and no team+ or member+ layer: epic is cache-prefix: armed, its routine is read by the run" \
	"$( rigNoTeamPlus "$rigEpic1" ):$( rigCount "$rigEpic1" 'RIG-EPIC-OPENING' )" "1:0"
rigAssert "a routine-policy spawn preloads the routine into the member block, as before" \
	"$( rigCount "$rigRoutine1" '## This session -- the routine' ):$( rigCount "$rigRoutine1" 'RIG-ROUTINE-POLICY-OPENING' )" "1:1"
rigAssert "and still carries no + layer" "$( rigNoTeamPlus "$rigRoutine1" )" 1
rigAssert "an epic's and a routine's team layer is the same bytes as a plain spawn's" \
	"$( [ "$( rigDiffAt "$rigA1" "$rigEpic1" )" -ge "$( rigSessionAt "$rigEpic1" )" ] && [ "$( rigDiffAt "$rigA1" "$rigRoutine1" )" -ge "$( rigSessionAt "$rigRoutine1" )" ] && printf same || printf differ )" same

echo "-- 5. the system message is the team layer; the member layer names the member and its stable roots, never the run --"
rigSystemA1="$rigTmp/system.a1" ; rigSystemBytes "$rigA1" > "$rigSystemA1"
rigSystemB1="$rigTmp/system.b1" ; rigSystemBytes "$rigB1" > "$rigSystemB1"
rigAssert "the system message names neither the spawn id, nor a sandbox path, nor the dispatch" \
	"$( rigCount "$rigSystemA1" 'a-armed-1' ):$( rigCount "$rigSystemA1" '/spawned/' ):$( rigCount "$rigSystemA1" 'DISPATCH-' ):$( rigCount "$rigSystemB1" '/spawned/' )" "0:0:0:0"
rigAssert "the system message carries no member root, and no per-run root" \
	"$( [ "$( rigCount "$rigSystemA1" "$rigWs" )" = 0 ] && [ "$( rigCount "$rigSystemA1" "$rigSkills" )" = 0 ] && [ "$( rigCount "$rigSystemA1" "$rigWs/.local/agents/spawned" )" = 0 ] && printf yes )" yes
rigAssert "the system message carries the team's armed floor, which is no member's own words" \
	"$( rigCount "$rigSystemA1" 'RIG-TEAM-ARMED-LINE-000' ):$( rigCount "$rigSystemA1" 'RIG-A-ARMED-LINE-000' )" "1:0"
rigAssert "the member layer in the first user message carries the member's stable roots" \
	"$( [ "$( rigCount "$rigA1" "$rigWs" )" -ge 1 ] && [ "$( rigCount "$rigA1" "$rigSkills" )" -ge 1 ] && printf yes )" yes
rigAssert "the run's own sandbox input/ and output/ are still named in the session layer, so nothing was taken from the model" \
	"$( [ "$( rigOffset "$rigA1" '## This session -- what is yours for this run alone' )" -lt "$( rigOffset "$rigA1" "$rigWs/.local/agents/spawned/a-armed-1/input" )" ] && [ "$( rigOffset "$rigA1" '## This session -- what is yours for this run alone' )" -lt "$( rigOffset "$rigA1" "$rigWs/.local/agents/spawned/a-armed-1/output" )" ] && printf yes )" yes

echo "-- 6. a legacy console that still passes the sandbox roots on the flags leaks nothing --"
rigLegacyConsole=1
rigSpawn a-legacy-1 rig-a "" "" 'DISPATCH-A-LEGACY
RIG-TASK-A-L1'
rigLegacyConsole=0
rigLegacy="$rigTmp/spawn.a-legacy-1/req.1"
rigLegacySystem="$rigTmp/system.legacy" ; rigSystemBytes "$rigLegacy" > "$rigLegacySystem"
rigAssert "the harness filters the run's own sandbox roots out of the system text"  "$( rigCount "$rigLegacySystem" "$rigWs/.local/agents/spawned/a-legacy-1" )" 0
rigAssert "and the two consoles' requests are the same bytes through the session layer"  "$( [ "$( rigDiffAt "$rigA1" "$rigLegacy" )" -ge "$( rigSessionAt "$rigLegacy" )" ] && printf shared || printf earlier )" shared
rigAssert "the legacy run's own sandbox is still named, in its session layer"        "$( [ "$( rigOffset "$rigLegacy" "$rigWs/.local/agents/spawned/a-legacy-1/input" )" -ge "$( rigSessionAt "$rigLegacy" )" ] && printf named )" named

echo "-- 7. the run's own sandbox is still a root of the gate: a Read inside input/ lands, a Write inside output/ lands --"
rigReadSandbox="$rigWs/.local/agents/spawned/gate" ; mkdir -p "$rigReadSandbox/input" "$rigReadSandbox/output"
printf 'RIG-SANDBOX-SECRET\n' > "$rigReadSandbox/input/secret.txt"
rigGateDir="$rigTmp/spawn.gate" ; mkdir -p "$rigGateDir" ; printf '0' > "$rigGateDir/round"
{
	printf -- '---\nspawn-id: gate\nparent-spawn-id: none\nstatus: spawn-started\n---\n\n# Spawn session: gate\n'
} > "$rigReadSandbox/gate.spawn.md"
rigChatCall "$rigGateDir/res.1" Read "{\"file_path\":\"$rigReadSandbox/input/secret.txt\"}"
rigChatCall "$rigGateDir/res.2" Write "{\"file_path\":\"$rigReadSandbox/output/written.txt\",\"content\":\"RIG-WRITTEN\"}"
rigChatEnd "$rigGateDir/res.3"
( cd "$rigWs" || exit 1
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_SESSION_ID=gate MDAT_SPAWN_SANDBOX_ROOT="$rigReadSandbox" \
		MDAT_SPAWN_AGENT=rig-a MDAT_SESSION_ID="rig-cowork" \
		MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 MDAT_HARNESS_PREFETCH=on \
		RIG_SCENARIO="$rigGateDir" \
		HARNESS_PROVIDER_NAME="spawn layers rig" HARNESS_SELF_NAME="AgentsPromptCacheLayersCheck.test.sh" \
		HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none" \
		HARNESS_ENDPOINT="https://harness-spawn-layers.invalid/v1/chat/completions" HARNESS_HOST="harness-spawn-layers.invalid" \
		HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" \
		HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
		HARNESS_OUTPUT_TOKENS_LIGHT="4101" HARNESS_OUTPUT_TOKENS_MAIN="4202" \
		bash "$rigHarness" --agent rig-a --tier normal --session-id gate \
			--access-read-root "$rigWs" --access-read-root "$rigSkills" --access-write-root "$rigSkills" \
			'DISPATCH-GATE
RIG-READ-TASK' ) > "$rigGateDir/out" 2> "$rigGateDir/err"
rigGateStatus=$?
rigAssert "the Read of a file under the spawn's own sandbox is served, not refused"  "$( rigIn "$( cat "$rigGateDir/req.2" )" 'RIG-SANDBOX-SECRET' ):$( rigIn "$( cat "$rigGateDir/err" )" 'not granted' )" "yes:no"
rigAssert "the Write under the spawn's own output/ lands"                            "$( cat "$rigReadSandbox/output/written.txt" 2>/dev/null )" "RIG-WRITTEN"
rigAssert "the gate run still ends normally"                                         "$rigGateStatus" 0

echo "-- 8. the console's leg branch: it hands the harness no per-run root --"
rigConsoleTemplate="$rigHere/manager/AgentsConsoleShellScript.template.sh"
rigLegStart="$( LC_ALL=C grep -n -F 'if [ -n "$DAGC_ACCESS_WRITE_FLAG" ] ; then' "$rigConsoleTemplate" 2>/dev/null | head -1 | LC_ALL=C cut -d: -f1 )"
rigLegEnd="$( LC_ALL=C grep -n -F 'elif [ -n "$DAGC_ACCESS_FLAG" ] ; then' "$rigConsoleTemplate" 2>/dev/null | head -1 | LC_ALL=C cut -d: -f1 )"
rigLegBranch="$( [ -n "$rigLegStart" ] && [ -n "$rigLegEnd" ] && [ "$rigLegEnd" -gt "$rigLegStart" ] && sed -n "${rigLegStart},$(( rigLegEnd - 1 ))p" "$rigConsoleTemplate" )"
rigAssert "the leg branch of the console names no sandbox path on the access flags"  "$( printf '%s' "$rigLegBranch" | LC_ALL=C grep -c 'MDAT_SPAWN_SANDBOX_ROOT' )" 0
rigAssert "the console still names it for a non-leg client CLI, which has no harness of ours"  "$( LC_ALL=C grep -c 'DagcAccessAppend .*MDAT_SPAWN_SANDBOX_ROOT/' "$rigConsoleTemplate" )" 2

echo "-- the Team+ and Member+ layers are real: the harness says so, and reads the files where the skillset keeps them (sketch 8) --"
## The comment at the layers said there is no + layer, against the code beside it. The files are the librarian's: they are optional, and a skillset without them has no such layer.
rigAssert "the harness does not say there is no + layer" "$( LC_ALL=C grep -c -F 'There is no + layer' "$rigHere/harness/AgentsUniversalHarness.sh" || : )" 0
rigAssert "the Team+ file is read beside magic-team.armed.md, where the skillset keeps the team's files" "$( LC_ALL=C grep -c -F '/magic-team/magic-team.armed-extended.md' "$rigHere/harness/AgentsUniversalHarness.sh" ):$( [ -f "${rigHere%/sh-lib}/skillset/magic-team/magic-team/magic-team.armed.md" ] && echo beside )" "2:beside"
rigAssert "the Member+ layer is built from the member's reference files and reads no armed-extended file" "$( LC_ALL=C grep -c -F 'armed-extended' "$rigHere/harness/AgentsHarnessSkills.include" || : ):$( LC_ALL=C grep -c -F 'AgentsHarnessMemberPlusText' "$rigHere/harness/AgentsHarnessSkills.include" )" "0:2"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PROMPT CACHE LAYERS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PROMPT_CACHE_LAYERS: OK (%d assertions, offline)\n' "$rigPassCount"
