#!/usr/bin/env bash
## Behavioural check on the harness dispatcher making every tool call a task underneath (epic S20; sh-lib/harness/AgentsHarnessRun.include,
## sh-lib/session/AgentsTools.ToolTask.include). Every call is a real one through the harness's own served entry point (`--intern-tool <tool>`)
## against this check's own rig workspace. Held:
##   1. a quick tool (Read) returns its own result, and the processes folder keeps nothing of it
##   2. `background: true` returns at once with TASK-ID=process-N and the hint; the task goes on
##   3. TaskOutput reads the task by its handle: running while it runs, finished with its output after
##   4. Wait on `process:<handle>` brings the task's end
##   5. the default time (MDAT_TOOL_TASK_SECONDS) returns a long call early; TaskStop on its handle closes it
##   6. `timeout` with `timeout_action: kill` ends the call at the timeout and returns what it wrote
##   7. Bash's own `timeout` still kills as it did, with no `timeout_action` given
##   8. a tool that blocks by design (Wait) is not wrapped: its result is its own
## The rig is a workspace of its own, under the scratch of this one, with its own MMDAPP and a member the served identity resolves. Every call is bounded
## by its own alarm, and the check needs no endpoint, no credential and no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigHarness="$rigOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh"
rigMember="rig-a" rigSession="rig-task-harness"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
[ -f "$rigOrigin/myx/myx.distro-agents/sh-lib/session/AgentsTools.ToolTask.include" ] || rigRefuse "the tool task include is not in the package"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsToolTaskHarnessCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## Whatever a returned task left running is ended on the way out: every pid its handles name, and its group, and anything started under the rig.
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
printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
printf 'line one\nline two\n' > "$rigTmp/work/note.txt"
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"
rigProc="$rigTmp/ws/.local/agents/sessions/$rigSession/processes"
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
		MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 MDAT_TOOL_TASK_CEILING=60 $rigExtraEnv \
		python3 -I -B "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigHarness" --intern-tool "$1" --access-read-root "$rigTmp" --access-write-root "$rigTmp" ) \
		> "$rigTmp/$rigName.out" 2> "$rigTmp/$rigName.err" || rigStatus=$?
	printf '%s' "$rigStatus" > "$rigTmp/$rigName.rc"
}
rigSaidRe(){ ## regular expression, call name -- how many lines of what that call printed match it
	LC_ALL=C grep -c -E -- "$1" "$rigTmp/$2.out" 2> /dev/null || :
}
rigHead(){ LC_ALL=C head -1 "$rigTmp/$1.out" 2> /dev/null || : ; }
rigLeft(){ ( cd "$rigProc" 2> /dev/null && ls -A 2> /dev/null | LC_ALL=C grep -c . || : ) ; }
rigNote(){ [ -d "$rigProc" ] || mkdir -p "$rigProc" ; }

echo "-- 1. a quick tool --"
rigCall Read "{\"path\":\"$rigTmp/work/note.txt\"}" read1
rigAssert "Read returns the file, as ever" "$( rigSaidRe 'line two' read1 )" "1"
rigAssert "and the session's processes folder keeps nothing of the call" "$( rigLeft )" "0"

echo "-- 2. background --"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"echo started; sleep 4; echo late\",\"background\":true}" bg1
rigAssert "it returns at once with the task id" "$( rigHead bg1 )" "TASK-ID=process-1"
rigAssert "and the hint names the five ways on" "$( rigSaidRe 'Wait sources=process:process-1|TaskOutput handle=process-1|TaskStop handle=process-1|timeout_action=kill|goes on' bg1 )" "5"

echo "-- 3. TaskOutput --"
sleep 1
rigCall TaskOutput '{"handle":"process-1"}' to1
rigAssert "while it runs: RUNNING, with the output so far" "$( rigHead to1 ):$( rigSaidRe 'STILL RUNNING' to1 )" "PROCESS-RESULT: RUNNING:1"
for rigWait in $(seq 1 40) ; do [ -f "$rigProc/process-1.status" ] && break ; sleep 0.25 ; done
rigCall TaskOutput '{"handle":"process-1"}' to2
rigAssert "after it ended: FINISHED, with its whole output" "$( rigHead to2 ):$( rigSaidRe '^>late$' to2 )" "PROCESS-RESULT: FINISHED:1"

echo "-- 4. Wait on the handle --"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"sleep 3; echo end\",\"background\":true}" bg2
rigCall Wait '{"sources":"process:process-2","timeout":20}' wait1
rigAssert "the end of a running task arrives under its source" "$( rigHead bg2 ):$( rigSaidRe 'State: FINISHED' wait1 )" "TASK-ID=process-2:1"

echo "-- 5. the default time, and TaskStop --"
rigExtraEnv="MDAT_TOOL_TASK_SECONDS=1"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"sleep 20\"}" def1
rigExtraEnv=""
rigAssert "a long call returns early at the default, naming it" "$( rigHead def1 ):$( rigSaidRe 'the default of 1s passed' def1 )" "TASK-ID=process-3:1"
rigCall TaskStop '{"handle":"process-3"}' stop1
rigAssert "TaskStop closes it" "$( rigHead stop1 )" "PROCESS-RESULT: CLOSED"

echo "-- 6. timeout_action kill --"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"echo partial; sleep 22\",\"timeout\":1,\"timeout_action\":\"kill\"}" kill1
rigAssert "the call is ended at the timeout, and says so" "$( rigHead kill1 | cut -c1-40 )" "ERROR: Bash was ended at your timeout of"
rigAssert "the sleeping process is gone" "$( ps -ax -o command | LC_ALL=C grep -c '[s]leep 22' || : )" "0"

echo "-- 7. Bash's own timeout --"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"echo hi\",\"timeout\":5}" own1
rigAssert "a Bash with only its own timeout ends in time and returns its output, as before" "$( rigSaidRe 'hi' own1 )" "1"

echo "-- 8. a tool that blocks by design --"
rigExtraEnv="MDAT_TOOL_TASK_SECONDS=1"
rigCall Wait '{"sources":"file:/nonexistent-rig-path","timeout":3}' wait2
rigExtraEnv=""
rigAssert "Wait is not wrapped: it returns its own result, never a task" "$( rigSaidRe '^TASK-ID=' wait2 )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TOOL TASK HARNESS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TOOL_TASK_HARNESS: OK (%d assertions, offline)\n' "$rigPassCount"
