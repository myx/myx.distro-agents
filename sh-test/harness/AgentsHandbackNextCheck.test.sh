#!/usr/bin/env bash
## Behavioural check of the start of the next routine from a handback (S24 item 4). A routine hands over by its own frontmatter key
## `hands-over-to: <routine file>`. Where the run is the executor of the routine its record names, the routine declares a successor, and the
## outcome of its delivered handback carries exactly one `next-routine: <successor> <input>` line, one session of the successor starts, and
## nowhere else. Through the real SubagentHandback tool, a Slack-shaped fake curl that opens no socket, and a program run in place of the spawner
## (MDAT_HANDBACK_NEXT_SPAWNER, AgentsTools.HandbackNext.include) that records its arguments. Held:
##   1. the start: one, as magic-coordinator, the input in its task, `--handed-over-by` naming the run; the handback is posted as before and a line names the new session
##   2. once per successor and input: the same run again, a corrected handback, and a second run on the same input start nothing more
##   3. nothing started and nothing said: no line, a routine that declares no successor, a run that is not the executor
##   4. refused, said in the thread, no marker: two lines, a successor the routine does not declare, a chain that comes back, an input that is missing,
##      relative, with a `..` part, or in no todo-sketchpad backlog and no sandbox of the run
##   5. the input in the sandbox of the run, and in a todo-sketchpad backlog, is allowed
##   6. a refused spawn: said with the manual start, the marker given back, and the same handback sent again starts
##   7. the epic gate: an epic its validator refuses starts no wave, a valid one does
##   8. the same through the MCP server: one start from a SubagentHandback call served
## Red before S24 item 4: no routine follows a handback.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="rig-helper"
rigCurrent="CSESS001:1700000002.000202"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -f "$rigTool" ] || rigRefuse "dispatcher not found at the origin this workspace resolves: $rigTool"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHandbackNextCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/skills/$rigMember"
printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
## The routines of the rig: a predecessor that hands over, its successor, a routine that hands over to none, a pair that hands over to each other, and a
## predecessor of a wave.
rigRoutine(){ ## file name, hands-over-to (empty for none)
	{
		printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: %s\nrequires-session-kind: standalone\n' "$rigMember" "$rigMember"
		[ -z "${2:-}" ] || printf 'hands-over-to: %s\n' "$2"
		printf -- '---\n# %s\n' "$1"
	} > "$rigTmp/skills/$rigMember/$1"
}
rigRoutine rig-pred.routine.md rig-succ.routine.md
rigRoutine rig-succ.routine.md ""
rigRoutine rig-plain.routine.md ""
rigRoutine rig-cyc-a.routine.md rig-cyc-b.routine.md
rigRoutine rig-cyc-b.routine.md rig-cyc-a.routine.md
rigRoutine rig-intake.routine.md magic-team.epic-wave.routine.md
rigRoutine magic-team.epic-wave.routine.md ""
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >> "$RIG_SPAWN_LOG"' '[ "${RIG_SPAWN_FAIL:-}" != yes ] || { echo "ERROR: the rig spawner refuses" ; exit 1 ; }' 'echo "SESSION_ID=rig-next"' > "$rigTmp/bin/spawner.sh"
chmod +x "$rigTmp/bin/spawner.sh"
PATH="$rigTmp/bin:/usr/bin:/bin"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigScenarioDir="" rigSpawnLog="" rigSpawnFail="" rigRun="rig-child-id" rigBacklog="" rigSandbox="" rigValidEpic="" rigGood=""
rigScene(){ ## scenario directory name, the routine the run was started on (empty: none), the owner of the run (default the rig member)
	rigScenarioDir="$rigTmp/$1" ; rigSpawnFail="" ; rigRun="rig-child-id"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents/spawned/child-folder/output" "$rigScenarioDir/data" "$rigScenarioDir/ws/source/myx/todo-sketchpad/rig-pad/backlog"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
	rigSpawnLog="$rigScenarioDir/spawn.log" ; : > "$rigSpawnLog"
	rigBacklog="$rigScenarioDir/ws/source/myx/todo-sketchpad/rig-pad/backlog" ; rigSandbox="$rigScenarioDir/ws/.local/agents/spawned/child-folder"
	printf '# a sketch\n' > "$rigBacklog/20261102-rig.sketch.md" ; rigGood="$rigBacklog/20261102-rig.sketch.md"
	printf '# 20261102 rig: the epic\n\nSource: `rig.sketch.md`.\nBuilders: the rig members.\n\n## Decisions\n\n- One rule holds.\n\n## S1 - First\n\n1. One outcome. Owner: rig-helper.\n\n## Done\n' > "$rigBacklog/20261102-rig.epic.md" ; rigValidEpic="$rigBacklog/20261102-rig.epic.md"
	rigRecord rig-child-id "${2:-}" "${3:-$rigMember}"
}
rigRecord(){ ## spawn id, routine (empty: none), owner
	{
		printf -- '---\nspawn-id: %s\nparent-spawn-id: none\nsession-thread: %s\nowner: %s\n' "$1" "$rigCurrent" "$3"
		[ -z "${2:-}" ] || printf 'routine: %s\n' "$2"
		printf -- '---\n'
	} > "$rigScenarioDir/ws/.local/agents/spawned/child-folder/$1.spawn.md"
}
rigJson(){ ## outcome text -- the call's JSON
	printf '{"to":"session-current","outcome":"%s"}' "$( printf '%s' "$1" | LC_ALL=C awk 'BEGIN { ORS = "" ; } { gsub( /\\/, "\\\\" ) ; gsub( /"/, "\\\"" ) ; print ( NR > 1 ? "\\n" : "" ) $0 ; }' )"
}
rigEnv(){ ## the environment of a run, one word each
	printf '%s\n' RIG_SCENARIO="$rigScenarioDir" RIG_SPAWN_LOG="$rigSpawnLog" RIG_SPAWN_FAIL="$rigSpawnFail" MDAT_HANDBACK_NEXT_SPAWNER="$rigTmp/bin/spawner.sh" \
		MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SESSION_THREAD="$rigCurrent" MDAT_SPAWN_SESSION_ID="$rigRun" \
		MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$rigTmp/skills"
}
rigCall(){ ## the outcome text
	local rigWords=()
	while IFS= read -r rigWord ; do rigWords+=( "$rigWord" ) ; done <<< "$( rigEnv )"
	( cd "$rigScenarioDir/ws" && rigJson "$1" | \
		env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT "${rigWords[@]}" \
		bash "$rigHarness" --intern-tool SubagentHandback > "$rigScenarioDir/tool.out" 2> "$rigScenarioDir/tool.err" )
}
rigPosts(){ ls "$rigScenarioDir"/post.* 2>/dev/null | wc -l | tr -d ' ' ; }
rigPostText(){ ## post number
	[ -f "$rigScenarioDir/post.${1:-1}" ] || return 0
	LC_ALL=C awk -v path=text -v optional=1 -f "$rigHere/harness/AgentsHarnessJsonField.awk" < "$rigScenarioDir/post.${1:-1}" 2>/dev/null
}
rigStarts(){ wc -l < "$rigSpawnLog" | tr -d ' ' ; }
rigMarkers(){ ls "$rigScenarioDir/ws/.local/agents/handback-next/" 2>/dev/null | LC_ALL=C grep -v -c '\.\(out\|rc\)$' || : ; }
## The start is made in the background: its end is a file .rc beside the marker. Waits for as many as asked, at most 30 seconds.
rigWaitStarts(){ ## how many ends
	local rigTry=0
	while [ "$( ls "$rigScenarioDir/ws/.local/agents/handback-next/" 2>/dev/null | LC_ALL=C grep -c '\.rc$' || : )" -lt "$1" ] && [ "$rigTry" -lt 60 ] ; do sleep 0.5 ; rigTry=$(( rigTry + 1 )) ; done
}
rigWaitPosts(){ ## how many posts
	local rigTry=0
	while [ "$( rigPosts )" -lt "$1" ] && [ "$rigTry" -lt 60 ] ; do sleep 0.5 ; rigTry=$(( rigTry + 1 )) ; done
}
rigNone(){ ## what a call that starts nothing and says nothing leaves: starts, markers, posts
	printf '%s:%s:%s' "$( rigStarts )" "$( rigMarkers )" "$( rigPosts )"
}

echo "-- 1. the start --"
rigScene start rig-pred.routine.md
rigCall "Filed the sketch. The next step is the successor.
next-routine: rig-succ.routine.md $rigGood"
rigWaitStarts 1 ; rigWaitPosts 2
rigAssert "one start was made" "$( rigStarts )" "1"
rigAssert "of the successor, as the spawner is asked" "$( LC_ALL=C grep -c -e '^--spawn-session --routine rig-succ.routine.md ' "$rigSpawnLog" )" "1"
rigAssert "as magic-coordinator" "$( LC_ALL=C grep -c -e ' magic-coordinator$' "$rigSpawnLog" )" "1"
rigAssert "its task names the input" "$( LC_ALL=C grep -c -F -e "$rigGood" "$rigSpawnLog" )" "1"
rigAssert "its record is to name the handing-back run" "$( LC_ALL=C grep -c -e '--handed-over-by rig-child-id ' "$rigSpawnLog" )" "1"
rigAssert "one marker stands" "$( rigMarkers )" "1"
rigAssert "the handback is posted as before, and a line names the new session" "$( rigPosts )" "2"
rigAssert "that line says which routine started, and the session" "$( rigPostText 2 | LC_ALL=C grep -c 'rig-succ.routine.md as session rig-next' )" "1"

echo "-- 2. once per successor and input --"
rigCall "Filed the sketch again, corrected.
next-routine: rig-succ.routine.md $rigGood"
rigAssert "the same run again starts nothing more" "$( rigStarts )" "1"
rigRecord rig-child-id2 rig-pred.routine.md "$rigMember"
rigRun="rig-child-id2"
rigCall "A second run, the same input.
next-routine: rig-succ.routine.md $rigGood"
rigAssert "a second run on the same input starts nothing more" "$( rigStarts )" "1"
rigRun="rig-child-id"

echo "-- 3. nothing started, nothing said --"
rigScene noline rig-pred.routine.md
rigCall "Filed as a task. Nothing is handed over."
rigAssert "an outcome with no next-routine line: no start, no marker, the handback alone" "$( rigNone )" "0:0:1"
rigScene nokey rig-plain.routine.md
rigCall "Done.
next-routine: rig-succ.routine.md $rigGood"
rigAssert "a routine that declares no successor starts nothing" "$( rigNone )" "0:0:1"
rigScene worker rig-pred.routine.md rig-other
rigCall "Done.
next-routine: rig-succ.routine.md $rigGood"
rigAssert "a run that is not the executor starts nothing" "$( rigNone )" "0:0:1"
rigScene noroutine ""
rigCall "Done.
next-routine: rig-succ.routine.md $rigGood"
rigAssert "a record that names no routine starts nothing" "$( rigNone )" "0:0:1"

echo "-- 4. refused, and said --"
rigScene twolines rig-pred.routine.md
rigCall "Done.
next-routine: rig-succ.routine.md $rigGood
next-routine: rig-succ.routine.md $rigGood"
rigAssert "two lines start nothing, leave no marker, and are said" "$( rigNone )" "0:0:2"
rigScene wrong rig-pred.routine.md
rigCall "Done.
next-routine: rig-plain.routine.md $rigGood"
rigAssert "a successor the routine does not declare starts nothing, and is said" "$( rigNone )" "0:0:2"
rigAssert "the post names the manual start" "$( rigPostText 2 | LC_ALL=C grep -c -e 'Start it by hand' )" "1"
rigScene cycle rig-cyc-a.routine.md
rigCall "Done.
next-routine: rig-cyc-b.routine.md $rigGood"
rigAssert "a chain that comes back starts nothing, and is said" "$( rigNone )" "0:0:2"
rigScene missing rig-pred.routine.md
rigCall "Done.
next-routine: rig-succ.routine.md $rigBacklog/not-there.md"
rigAssert "an input that is not there starts nothing, and is said" "$( rigNone )" "0:0:2"
rigScene relative rig-pred.routine.md
rigCall "Done.
next-routine: rig-succ.routine.md 20261102-rig.sketch.md"
rigAssert "an input that is not an absolute path starts nothing, and is said" "$( rigNone )" "0:0:2"
rigScene dotdot rig-pred.routine.md
rigCall "Done.
next-routine: rig-succ.routine.md $rigBacklog/../backlog/20261102-rig.sketch.md"
rigAssert "an input with a .. part starts nothing, and is said" "$( rigNone )" "0:0:2"
rigScene elsewhere rig-pred.routine.md
printf '# elsewhere\n' > "$rigTmp/elsewhere.md"
rigCall "Done.
next-routine: rig-succ.routine.md $rigTmp/elsewhere.md"
rigAssert "an input in no backlog and no sandbox of the run starts nothing, and is said" "$( rigNone )" "0:0:2"

echo "-- 5. the places an input may be in --"
rigScene sandbox rig-pred.routine.md
printf '# a plan\n' > "$rigSandbox/output/plan.md"
rigCall "Done.
next-routine: rig-succ.routine.md $rigSandbox/output/plan.md"
rigWaitStarts 1
rigAssert "an input in the sandbox of the run starts" "$( rigStarts )" "1"

echo "-- 6. a spawn the spawner refuses --"
rigScene refused rig-pred.routine.md
rigSpawnFail=yes
rigCall "Done.
next-routine: rig-succ.routine.md $rigGood"
rigWaitStarts 1 ; rigWaitPosts 2
rigAssert "the spawner was asked once" "$( rigStarts )" "1"
rigAssert "the marker is given back" "$( rigMarkers )" "0"
rigAssert "the failure is said with the manual start" "$( rigPostText 2 | LC_ALL=C grep -c -e 'Start it by hand' )" "1"
rigSpawnFail=""
rm -f "$rigScenarioDir/ws/.local/agents/handback-next/"*.rc
rigCall "Done, sent again.
next-routine: rig-succ.routine.md $rigGood"
rigWaitStarts 1
rigAssert "the same handback sent again starts" "$( rigStarts )" "2"
rigAssert "and keeps its marker" "$( rigMarkers )" "1"

echo "-- 7. the epic gate --"
rigScene gate rig-intake.routine.md
printf '# 20261102 rig: no Done\n\nSource: `x`.\nBuilders: y.\n\n## Decisions\n\n- A rule.\n' > "$rigBacklog/20261102-rig-bad.epic.md"
rigCall "Done.
next-routine: magic-team.epic-wave.routine.md $rigBacklog/20261102-rig-bad.epic.md"
rigAssert "an epic its validator refuses starts no wave, and is said" "$( rigNone )" "0:0:2"
rigAssert "the post carries the validator's row" "$( rigPostText 2 | LC_ALL=C grep -c -e 'epic-done' )" "1"
rigCall "Done.
next-routine: magic-team.epic-wave.routine.md $rigValidEpic"
rigWaitStarts 1
rigAssert "a valid epic starts the wave" "$( LC_ALL=C grep -c -e '^--spawn-session --routine magic-team.epic-wave.routine.md ' "$rigSpawnLog" )" "1"

echo "-- 8. through the MCP server --"
rigScene mcp rig-pred.routine.md
rigWords=()
while IFS= read -r rigWord ; do rigWords+=( "$rigWord" ) ; done <<< "$( rigEnv )"
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"SubagentHandback","arguments":%s}}\n' "$( rigJson "Done through the server.
next-routine: rig-succ.routine.md $rigGood" )"
} | ( cd "$rigScenarioDir/ws" && env -u MDAT_MCP_SERVED_MARKER -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT HOME="$rigTmp" "${rigWords[@]}" \
	bash "$rigTool" --intern-mcp-server --run > "$rigScenarioDir/mcp.wire" 2> "$rigScenarioDir/mcp.err" ) || :
rigWaitStarts 1
rigAssert "the server answered the handback call" "$( LC_ALL=C grep -c '"id":2,' "$rigScenarioDir/mcp.wire" )" "1"
rigAssert "one start was made from the served call" "$( rigStarts )" "1"

echo "-- 9. the routine validator reads the key --"
rigScene validate ""
rigRoutine rig-two.routine.md "rig-succ.routine.md, rig-plain.routine.md"
rigRoutine rig-none.routine.md rig-not-there.routine.md
rigHandsRows(){ ## routine file name -- how many rows of the rule hands-over-to the routine validator gives it
	local rigWords=()
	while IFS= read -r rigWord ; do rigWords+=( "$rigWord" ) ; done <<< "$( rigEnv )"
	( cd "$rigScenarioDir/ws" && env HOME="$rigTmp" "${rigWords[@]}" bash "$rigTool" --intern-doc-validate routine "$rigTmp/skills/$rigMember/$1" 2> /dev/null | LC_ALL=C grep -c ': hands-over-to: ' || : )
}
rigAssert "a declared successor that is a routine gives no row" "$( rigHandsRows rig-pred.routine.md )" "0"
rigAssert "a routine that declares none gives no row" "$( rigHandsRows rig-plain.routine.md )" "0"
rigAssert "two names give a row" "$( rigHandsRows rig-two.routine.md )" "1"
rigAssert "a name that is no routine gives a row" "$( rigHandsRows rig-none.routine.md )" "1"
rigAssert "a chain that comes back gives a row" "$( rigHandsRows rig-cyc-a.routine.md )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HANDBACK NEXT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HANDBACK_NEXT: OK (%d assertions, offline)\n' "$rigPassCount"
