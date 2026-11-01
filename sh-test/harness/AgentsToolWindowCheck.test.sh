#!/usr/bin/env bash
## Behavioural check on the window a long tool call returns within (epic S22.7; sh-lib/harness/AgentsHarnessToolWindow.include,
## sh-lib/session/AgentsTools.ToolTask.include, sh-lib/harness/AgentsHarnessRun.include). Every call is a real one through the
## harness's own served entry point (`--intern-tool <tool>`) against this check's own rig workspace. Held:
##   1. the table: one number a tool, between 10 and 300 seconds, and no tool that blocks by design carries one
##   2. a call that runs long returns a handle at its own window, naming it
##   3. `sync` overrides the window: the call runs to its own end and returns its own result
##   4. `async` overrides the window: the handle comes back at once, with no wait
## The rig is a workspace of its own, under the scratch of this one, with its own MMDAPP and a member the served identity resolves.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigHarness="$rigOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh"
rigWindow="$rigOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessToolWindow.include"
rigMember="rig-a" rigSession="rig-tool-window"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
## A table that is not there answers every tool with the 300 second floor, which is the defect this check exists for: it is
## refused here rather than reported as a window nobody wrote.
[ -f "$rigWindow" ] || rigRefuse "the tool window table is not in the package: $rigWindow"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsToolWindowCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigReap(){
	local reapFile reapPid
	for reapFile in "$rigTmp/ws/.local/agents/sessions/$rigSession/processes"/*.pid ; do
		[ -f "$reapFile" ] || continue
		reapPid="$( head -1 "$reapFile" )"
		[ -z "$reapPid" ] || kill -TERM -- "-$reapPid" 2> /dev/null || kill -TERM "$reapPid" 2> /dev/null || :
	done
	pkill -TERM -f "$rigTmp" 2> /dev/null || :
	sleep 0.3
}
trap 'rigReap ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/skills/$rigMember" "$rigTmp/home" "$rigTmp/work" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf 'line one\nline two\n' > "$rigTmp/work/note.txt"
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"
rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigExtraEnv=""
rigCall(){ ## tool, argument object, call name -- what the call printed in <name>.out, its status in <name>.rc
	local rigStatus=0 rigName="$3"
	( cd "$rigTmp/ws" && printf '%s' "$2" | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="$rigSession" \
		MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 MDAT_TOOL_TASK_CEILING=90 $rigExtraEnv \
		python3 -I -B "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 150 -- bash "$rigHarness" --intern-tool "$1" --access-read-root "$rigTmp" --access-write-root "$rigTmp" ) \
		> "$rigTmp/$rigName.out" 2> "$rigTmp/$rigName.err" || rigStatus=$?
	printf '%s' "$rigStatus" > "$rigTmp/$rigName.rc"
}
rigSaidRe(){ ## regular expression, call name -- how many lines of what that call printed match it
	LC_ALL=C grep -c -E -- "$1" "$rigTmp/$2.out" 2> /dev/null || :
}
rigHead(){ LC_ALL=C head -1 "$rigTmp/$1.out" 2> /dev/null || : ; }

echo "-- 1. the table --"
. "$rigWindow"
rigAssert "a tool in the table answers its own number" "$( AgentsHarnessToolWindowSeconds Read )" "30"
rigAssert "a name the table does not hold answers nothing" "[$( AgentsHarnessToolWindowSeconds rigNoSuchTool )]" "[]"
rigAssert "every row sits inside the window the owner set, 10 to 300 seconds" "$( printf '%s\n' "$agentsHarnessToolWindow" | LC_ALL=C awk -F'\t' 'NF { if ( $2 < 10 || $2 > 300 || $2 !~ /^[0-9]+$/ ) { bad++ ; } } END { print bad + 0 ; }' )" "0"
rigAssert "and no tool that blocks by design on its own bound carries one" "$( for rigSkip in Wait AskQuestion ConfirmReadback EscalateDecision RequestPermission ProposeApprove ThisSession TaskOutput TaskStop SubagentHandback BatchTools ; do printf '%s\n' "[$( AgentsHarnessToolWindowSeconds "$rigSkip" )]" ; done | LC_ALL=C grep -c '^\[\]$' )" "11"

echo "-- 2. a call that runs long, at its own window --"
rigCall Read "{\"file_path\":\"$rigTmp/work/note.txt\"}" read1
rigAssert "control: a Read that ends in time returns its own text, no task" "$( rigSaidRe 'line two' read1 ):$( rigSaidRe '^TASK-ID=' read1 )" "1:0"
rigExtraEnv="MDAT_TOOL_TASK_CEILING=200"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"sleep 130\"}" slow1
rigExtraEnv=""
rigAssert "the long call comes back with a handle" "$( rigSaidRe '^TASK-ID=process-[0-9]+$' slow1 )" "1"
rigAssert "and names Bash's own window of 120 seconds, not the 300 second floor" "$( rigSaidRe 'the window of 120s passed' slow1 )" "1"
rigCall TaskStop '{"handle":"process-1"}' stop1
rigAssert "TaskStop closes it" "$( rigHead stop1 )" "PROCESS-RESULT: CLOSED"

echo "-- 3. sync overrides the window --"
rigExtraEnv="MDAT_TOOL_TASK_SECONDS=1"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"sleep 3; echo done\",\"sync\":true}" sync2
rigExtraEnv=""
rigAssert "a sync call that outlives the window still returns its own output" "$( rigSaidRe '^done$' sync2 ):$( rigSaidRe '^TASK-ID=' sync2 )" "1:0"

echo "-- 4. async overrides the window --"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"sleep 300\",\"async\":true}" async1
rigAssert "an async call returns a handle at once, without waiting out its 120 second window" "$( rigSaidRe '^TASK-ID=process-[0-9]+$' async1 ):$( rigSaidRe 'you asked for background or async' async1 )" "1:1"
rigCall TaskStop '{"handle":"process-1"}' stop2
rigAssert "TaskStop closes the async one too" "$( rigHead stop2 )" "PROCESS-RESULT: CLOSED"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TOOL WINDOW CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TOOL_WINDOW: OK (%d assertions, offline)\n' "$rigPassCount"
