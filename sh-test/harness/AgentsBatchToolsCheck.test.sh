#!/usr/bin/env bash
## Behavioural check on BatchTools (F7.8 of the refactorings epic): one tool call that calls several tools and returns
## their results in the same order. Arguments: `mode`, one of sequence-stop-on-error, sequence-all-through,
## parallel-concurrent (bounded by `workers`, default 4, as lib/parallel), parallel-all-any-match, parallel-all-through
## (every call at once); `calls`, a list of {"tool":..,"arguments":{..}}; and `format: "json"`. The result is one
## `BATCH-ENTRY: <n> <tool> <ok|error|skipped|cancelled>` line per call, in call order, each followed by that call's
## result, and a last line `BATCH-RESULT: <mode> <ok>/<total>`; with format json, {"mode":..,"entries":[{"tool":..,
## "status":..,"result":..}]}. An entry over 8 KB is an F2.4 file reference. An unknown mode or tool is refused and
## nothing runs. It is listed in the harness's and the MCP server's tools, its description saying it saves rounds.
## Held, served by the harness (--intern-tool) and through the MCP server's tools/call:
##   1. it is listed by both, with a description that says it saves rounds and returns one structured result
##   2. sequence-all-through: every call, in order, an error among them; the summary counts the ok ones
##   3. sequence-stop-on-error: the calls after the error are skipped, and not run
##   4. parallel-all-through: every call at once -- each of five sees all five started
##   5. parallel-concurrent: bounded, by default four at once -- not all five see five started; with workers 5 all do
##   6. parallel-all-any-match: it returns at the first ok, before the slow call ends; the slow call is cancelled
##   7. entries stay in call order though the calls end out of order
##   8. an entry over 8 KB is a file reference
##   9. format json: one JSON object, its entries in call order
##  10. an unknown mode, or an unknown tool among the calls, is refused and nothing runs
##  11. `--mdat-output-format json` on the shell operations that implement harness and MCP tools: the operation of
##      Wait (--wait-for-input) and of the collect that SubagentHandback and ProposeApprove run
##      (--intern-op-pending-reply-collect) print one JSON document; an operation that implements no tool
##      (--agents-config-option) prints exactly as without it
## Red before F7.8: no such tool (every case fails).
## Offline: MMDAPP and HOME are this rig's own; the calls are reads of this rig's files and short shell commands.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] && [ -f "$rigTool" ] || rigRefuse "the harness or the tool is not at the origin this workspace resolves: $MDLT_ORIGIN"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBatchToolsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
## The granted team work directory of the workspace: inside the access roots of the server and of a served call.
rigFix="$rigTmp/.local/temp/team/fix"
mkdir -p "$rigFix/marks" "$rigTmp/.local/.agents" "$rigTmp/home"
printf 'RIG-LINE-A\n' > "$rigFix/a.txt"
printf 'RIG-LINE-B\n' > "$rigFix/b.txt"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/.local/.agents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigServe(){ ## name, arguments JSON -- one served BatchTools call; its reply in <name>.out
	printf '%s' "$2" > "$rigTmp/$1.args"
	( cd "$rigFix" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_DATA_ROOT -u MDAT_SKILLSET_ROOT MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" HOME="$rigTmp/home" \
		MDAT_SPAWN_AGENT=magic-tester MDAT_SPAWN_SESSION_ID=rig-batch-run bash "$rigHarness" --intern-tool BatchTools < "$rigTmp/$1.args" ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err"
}
## One BatchTools call through the MCP server; its decoded text in <name>.out, the seconds it took in rigSeconds.
rigMcp(){ ## name, arguments JSON
	local mcpStart
	mcpStart="$( date +%s )"
	printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"BatchTools","arguments":%s}}\n' "$2" \
		| ( cd "$rigFix" && env -u CLAUDE_CODE_SESSION_ID MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" HOME="$rigTmp/home" \
		CLAUDE_CODE_SESSION_ID=rig-batch-client bash "$rigTool" --intern-mcp-server --run ) 2> "$rigTmp/$1.err" | LC_ALL=C grep '^{"jsonrpc":"2.0","id":2,' > "$rigTmp/$1.wire"
	rigSeconds=$(( $( date +%s ) - mcpStart ))
	"$rigPython" -I -c 'import json,sys
for line in open(sys.argv[1]):
	reply = json.loads(line)
	for part in reply.get("result", {}).get("content", []):
		if part.get("type") == "text": print(part.get("text", ""))
	if "error" in reply: print("RPC-ERROR: " + json.dumps(reply["error"]))' "$rigTmp/$1.wire" > "$rigTmp/$1.out" 2> /dev/null || :
}
rigEntries(){ ## name -- the entry lines, as `<n> <tool> <status>` joined by |
	LC_ALL=C sed -n 's/^BATCH-ENTRY: //p' "$rigTmp/$1.out" | LC_ALL=C tr '\n' '|' | LC_ALL=C sed 's/|$//'
}
rigSummary(){ LC_ALL=C sed -n 's/^BATCH-RESULT: //p' "$rigTmp/$1.out" | LC_ALL=C tail -n 1 ; }
## The line of the reply a text stands on, counted from 1, or 0.
rigLineOf(){ ## name, fixed text
	LC_ALL=C grep -n -F -- "$2" "$rigTmp/$1.out" 2> /dev/null | head -1 | cut -d: -f1 | LC_ALL=C sed 's/^$/0/' | LC_ALL=C grep . || printf 0
}
rigReadCalls="[{\"tool\":\"Read\",\"arguments\":{\"file_path\":\"$rigFix/a.txt\"}},{\"tool\":\"Read\",\"arguments\":{\"file_path\":\"$rigFix/missing.txt\"}},{\"tool\":\"Read\",\"arguments\":{\"file_path\":\"$rigFix/b.txt\"}}]"
## Five shell calls that each mark their start, wait up to four seconds for all five starts, and say how many they saw.
rigFive(){ ## tag
	local fiveNo fiveCalls=""
	for fiveNo in 1 2 3 4 5 ; do
		fiveCalls="$fiveCalls${fiveCalls:+,}{\"tool\":\"execute\",\"arguments\":{\"command\":\"touch $rigFix/marks/$1.start.$fiveNo ; n=0 ; while [ \$( ls $rigFix/marks | grep -c ^$1.start. ) -lt 5 ] && [ \$n -lt 40 ] ; do sleep 0.1 ; n=\$(( n + 1 )) ; done ; echo $1-saw-\$( ls $rigFix/marks | grep -c ^$1.start. )\"}}"
	done
	printf '[%s]' "$fiveCalls"
}

echo "-- 1. it is listed, and says what it saves --"
rigAssert "the harness's tools list names BatchTools"         "$( LC_ALL=C grep -c -F '"name":"BatchTools"' "$rigHere/harness/AgentsOpenAiChatWire.sh" )" 1
printf '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' | ( cd "$rigFix" && env -u CLAUDE_CODE_SESSION_ID MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" HOME="$rigTmp/home" bash "$rigTool" --intern-mcp-server --run ) > "$rigTmp/list.wire" 2> /dev/null
rigAssert "the MCP server's tools list names BatchTools"      "$( LC_ALL=C grep -c -F '"name":"BatchTools"' "$rigTmp/list.wire" )" 1
rigAssert "its description says it saves rounds and returns one structured result" \
	"$( "$rigPython" -I -c 'import json,sys
for line in open(sys.argv[1]):
	try: tools = json.loads(line).get("result", {}).get("tools", [])
	except ValueError: continue
	for tool in tools:
		if tool.get("name") == "BatchTools":
			text = tool.get("description", "").lower()
			print("rounds" if "round" in text and "struct" in text else "silent")' "$rigTmp/list.wire" 2> /dev/null | head -1 )" rounds

echo "-- 2. sequence-all-through: every call, in order --"
rigServe s1 "{\"mode\":\"sequence-all-through\",\"calls\":$rigReadCalls}"
rigAssert "three entries, in call order, the missing file an error" "$( rigEntries s1 )" "1 Read ok|2 Read error|3 Read ok"
rigAssert "each result after its own entry"                   "$( [ "$( rigLineOf s1 RIG-LINE-A )" -gt "$( rigLineOf s1 'BATCH-ENTRY: 1 ' )" ] && [ "$( rigLineOf s1 RIG-LINE-A )" -lt "$( rigLineOf s1 'BATCH-ENTRY: 2 ' )" ] && [ "$( rigLineOf s1 RIG-LINE-B )" -gt "$( rigLineOf s1 'BATCH-ENTRY: 3 ' )" ] && printf nested || printf not-nested )" nested
rigAssert "the summary counts the ok ones"                    "$( rigSummary s1 )" "sequence-all-through 2/3"

echo "-- 3. sequence-stop-on-error: the calls after the error are skipped --"
rigServe s2 "{\"mode\":\"sequence-stop-on-error\",\"calls\":$rigReadCalls}"
rigAssert "the third is skipped"                              "$( rigEntries s2 )" "1 Read ok|2 Read error|3 Read skipped"
rigAssert "and not run: its line is nowhere"                  "$( LC_ALL=C grep -c -F RIG-LINE-B "$rigTmp/s2.out" || : )" 0

echo "-- 4. parallel-all-through: every call at once --"
rigMcp p1 "{\"mode\":\"parallel-all-through\",\"calls\":$( rigFive all )}"
rigAssert "each of five saw all five started"                 "$( LC_ALL=C grep -c -x 'all-saw-5' "$rigTmp/p1.out" || : )" 5

echo "-- 5. parallel-concurrent: four at once by default; workers 5 lets all five run --"
rigMcp p2 "{\"mode\":\"parallel-concurrent\",\"calls\":$( rigFive four )}"
rigAssert "control: five entries"                             "$( LC_ALL=C grep -c '^BATCH-ENTRY: ' "$rigTmp/p2.out" || : )" 5
rigAssert "all five ran, and not all five saw five started"   "$( [ "$( LC_ALL=C grep -c -E '^four-saw-[0-9]+$' "$rigTmp/p2.out" || : )" -eq 5 ] && [ "$( LC_ALL=C grep -c -x 'four-saw-5' "$rigTmp/p2.out" || : )" -lt 5 ] && printf bounded || printf not-bounded )" bounded
rigMcp p3 "{\"mode\":\"parallel-concurrent\",\"workers\":5,\"calls\":$( rigFive five )}"
rigAssert "with workers 5, all five saw five started"         "$( LC_ALL=C grep -c -x 'five-saw-5' "$rigTmp/p3.out" || : )" 5

echo "-- 6. parallel-all-any-match: it returns at the first ok; the slow call is cancelled --"
rigMcp p4 "{\"mode\":\"parallel-all-any-match\",\"calls\":[{\"tool\":\"execute\",\"arguments\":{\"command\":\"exit 3\"}},{\"tool\":\"execute\",\"arguments\":{\"command\":\"sleep 1 ; echo rig-found\"}},{\"tool\":\"execute\",\"arguments\":{\"command\":\"sleep 8 ; touch $rigFix/marks/slow.end ; echo rig-slow\"}}]}"
rigAssert "the entries: the error, the first ok, the slow one cancelled" "$( rigEntries p4 )" "1 execute error|2 execute ok|3 execute cancelled"
rigAssert "it returned with the found one, before the slow call would have ended" "$( [ "$rigSeconds" -lt 7 ] && LC_ALL=C grep -q -x rig-found "$rigTmp/p4.out" && printf early || printf "after ${rigSeconds}s or not found" )" early
sleep 8
rigAssert "and the slow call never ended its work"            "$( [ -e "$rigFix/marks/slow.end" ] && printf ended || printf cancelled )" cancelled

echo "-- 7. entries stay in call order though the calls end out of order --"
rigMcp p5 "{\"mode\":\"parallel-all-through\",\"calls\":[{\"tool\":\"execute\",\"arguments\":{\"command\":\"sleep 2 ; echo rig-first-call\"}},{\"tool\":\"execute\",\"arguments\":{\"command\":\"echo rig-second-call\"}}]}"
rigAssert "the first call's entry and result come first"      "$( [ "$( rigLineOf p5 rig-first-call )" -gt 0 ] && [ "$( rigLineOf p5 rig-first-call )" -lt "$( rigLineOf p5 rig-second-call )" ] && printf in-order || printf out-of-order )" in-order

echo "-- 8. an entry over 8 KB is a file reference --"
rigMcp p6 "{\"mode\":\"sequence-all-through\",\"calls\":[{\"tool\":\"execute\",\"arguments\":{\"command\":\"awk 'BEGIN { for ( n = 1 ; n <= 400 ; n++ ) printf \\\"rig batch line %04d, padded to a length of fifty\\\\n\\\", n }'\"}}]}"
rigAssert "the entry holds none of its lines past a preview"  "$( LC_ALL=C grep -c -F 'rig batch line 0399' "$rigTmp/p6.out" || : )" 0
rigAssert "and names a file holding them"                     "$( for rigPath in $( LC_ALL=C grep -o -E '/[^ "]+' "$rigTmp/p6.out" ) ; do [ -f "$rigPath" ] && LC_ALL=C grep -q -F 'rig batch line 0399' "$rigPath" && { printf named ; break ; } ; done )" named

echo "-- 9. format json: one object, its entries in call order --"
rigServe j1 "{\"mode\":\"sequence-all-through\",\"format\":\"json\",\"calls\":$rigReadCalls}"
rigAssert "the reply is one JSON object with the mode and its three entries, in order" \
	"$( "$rigPython" -I -c 'import json,sys
reply = json.load(open(sys.argv[1]))
print(reply["mode"] + " " + "|".join(entry["tool"] + ":" + entry["status"] for entry in reply["entries"]) + " " + ("A" if "RIG-LINE-A" in reply["entries"][0]["result"] else "-"))' "$rigTmp/j1.out" 2> /dev/null )" "sequence-all-through Read:ok|Read:error|Read:ok A"

echo "-- 10. an unknown mode, or an unknown tool among the calls, is refused and nothing runs --"
rigMcp r1 "{\"mode\":\"sequence-sometimes\",\"calls\":[{\"tool\":\"execute\",\"arguments\":{\"command\":\"touch $rigFix/marks/refused.mode\"}}]}"
rigAssert "an unknown mode: refused, naming it, and the call did not run" "$( LC_ALL=C grep -c -F 'sequence-sometimes' "$rigTmp/r1.out" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "named" : "unnamed" }' ):$( [ -e "$rigFix/marks/refused.mode" ] && printf ran || printf not-run )" "named:not-run"
rigMcp r2 "{\"mode\":\"sequence-all-through\",\"calls\":[{\"tool\":\"execute\",\"arguments\":{\"command\":\"touch $rigFix/marks/refused.tool\"}},{\"tool\":\"NoSuchRigTool\",\"arguments\":{}}]}"
rigAssert "an unknown tool: refused, naming it, and no call ran" "$( LC_ALL=C grep -c -F 'NoSuchRigTool' "$rigTmp/r2.out" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "named" : "unnamed" }' ):$( [ -e "$rigFix/marks/refused.tool" ] && printf ran || printf not-run )" "named:not-run"

echo "-- 11. --mdat-output-format json on the operations behind the tools --"
mkdir -p "$rigTmp/skills/magic-tester" "$rigTmp/data/inboxes/magic-tester" "$rigTmp/.local/agents/pending"
printf 'rig\n' > "$rigTmp/skills/magic-tester/magic-tester.basic.md"
printf 'rig\n' > "$rigTmp/skills/magic-tester/magic-tester.armed.md"
rigShell(){ ## result name, arguments... -- one shell operation of the tooling, in the rig's workspace
	local shellName="$1" ; shift
	( cd "$rigTmp" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT HOME="$rigTmp/home" MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_WAIT_REMIND=off bash "$rigTool" "$@" ) > "$rigTmp/$shellName.out" 2> "$rigTmp/$shellName.err" < /dev/null
}
rigIsJson(){ ## result name -- json where its whole output is one JSON document
	"$rigPython" -I -c 'import json,sys ; json.load(open(sys.argv[1])) ; print("json")' "$rigTmp/$1.out" 2> /dev/null || printf not-json
}
rigShell o1 --mdat-output-format json --wait-for-input magic-tester --wait-source inbox:magic-tester --wait-session-id rig-batch-json --wait-timeout 1 --wait-poll-interval 1
rigAssert "the operation behind Wait prints one JSON document" "$( rigIsJson o1 )" json
rigShell o2 --mdat-output-format json --intern-op-pending-reply-collect --ended --context rig-batch-json
rigAssert "the collect behind SubagentHandback and ProposeApprove prints one JSON document" "$( rigIsJson o2 )" json
rigShell o3 --agents-config-option magic-team --select-default RIG_UNSET_SETTING rig-default-value
rigShell o4 --mdat-output-format json --agents-config-option magic-team --select-default RIG_UNSET_SETTING rig-default-value
rigAssert "control: the plain config read prints its default" "$( LC_ALL=C grep -c -x -F 'rig-default-value' "$rigTmp/o3.out" )" 1
rigAssert "an operation that implements no tool prints exactly as without it" "$( cmp -s "$rigTmp/o3.out" "$rigTmp/o4.out" && printf same || printf different )" same
## The list beside the option is the operations the harness runs through the dispatcher, but its settings read, and
## the one behind execute: each word the harness's own functions run is on it, and nothing else is.
rigHarnessOps="$( LC_ALL=C awk '
	/^AgentsHarness[A-Za-z]*\(\) *\{/ { inside = 1 ; next }
	/^}/ { inside = 0 ; next }
	inside && /DistroAgentsTools(\.fn\.sh"?)? +--/ {
		line = $0
		while ( match( line, /DistroAgentsTools(\.fn\.sh"?)? +--[a-z][a-z0-9-]+/ ) ) {
			word = substr( line, RSTART, RLENGTH ) ; sub( /.* /, "", word ) ; print word
			line = substr( line, RSTART + RLENGTH )
		}
	}' "$rigHarness" | LC_ALL=C grep -v -x -e '--agents-config-option' ; printf '%s\n' --intern-mcp-execute )"
## The operations of the tool files carry the wrapper in their own door (their list is in the table of the tool files); the dispatcher's own, in its list.
rigListedOps="$( { LC_ALL=C sed -n '/^agentsToolOperations="/,/"$/p' "$rigTool" ; LC_ALL=C sed -n '/^agentsFrontJsonOps="/,/"$/p' "$rigHere/harness/AgentsContext.FrontTable.include" ; } | LC_ALL=C tr -s ' \t"' '\n' | LC_ALL=C grep -E '^--[a-z]' )"
rigAssert "the list beside the option is exactly the operations behind the tools" \
	"$( printf '%s\n' "$rigHarnessOps" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" "$( printf '%s\n' "$rigListedOps" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BATCH TOOLS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BATCH_TOOLS: OK (%d assertions, offline)\n' "$rigPassCount"
