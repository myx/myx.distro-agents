#!/usr/bin/env bash
## Behavioural check on a tool call that never blocks beyond the caller's control (epic S20, sh-lib/session/AgentsTools.ToolTask.include).
## Every call runs as a task underneath. Held:
##   1. a call that ends in time returns its own stdout and exit code, replays its stderr, and leaves nothing in the session's processes folder
##   2. `background` returns at once with TASK-ID=process-N and the hint; the task goes on, writes through the handle's files, and records its status
##   3. the default time (MDAT_TOOL_TASK_SECONDS) returns the task early, naming the default
##   4. the caller's own timeout returns it early (the default action), naming the timeout
##   5. timeout_action kill ends the task at the timeout and returns what it wrote, the process gone
##   6. a message addressed to the member in the session chat returns it early, and the message is still there afterwards (nothing consumed)
##   7. a returned task is ended after the ceiling (MDAT_TOOL_TASK_CEILING)
##   8. a call from inside a task, or from no session, runs plain
## Offline: a rig workspace and a rig session, every call through `env -i`.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/session/AgentsTools.ToolTask.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the tool task include is not in the package: $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsToolTaskCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" rigSession="rig-task-session" rigProc="$rigTmp/ws/.local/agents/sessions/rig-task-session/processes"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home"
## Whatever a returned task left running is ended on the way out: every pid its handles name, and its group.
rigReap(){
	local reapFile reapPid
	for reapFile in "$rigProc"/*.pid ; do
		[ -f "$reapFile" ] || continue
		reapPid="$( head -1 "$reapFile" )"
		[ -z "$reapPid" ] || kill -TERM -- "-$reapPid" 2> /dev/null || kill -TERM "$reapPid" 2> /dev/null || :
	done
	sleep 0.3
}
trap 'rigReap ; rm -rf -- "$rigTmp"' EXIT
rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One call of AgentsToolsTaskCall in a clean shell: the result, as `detached|rc|handle` then the text, and the stderr on a file.
rigCall(){ ## env words (NAME=value)..., then label, background, timeout, action, body (a shell command line the task runs)
	local rigEnvWords=() rigWord
	while [ $# -gt 5 ] ; do rigEnvWords+=( "$1" ) ; shift ; done
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_TOOL_TASK_CEILING=60 "${rigEnvWords[@]+"${rigEnvWords[@]}"}" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ToolTask.include" ; rigBody(){ eval "$1" ; } ; AgentsToolsTaskCall "$1" "$2" "$3" "$4" rigBody "$5" ; printf "%s|%s|%s\n%s\n" "$agentsTaskDetached" "$agentsTaskRc" "$agentsTaskHandle" "$agentsTaskOut"' rig "$@" 2> "$rigTmp/err"
}
rigHead(){ printf '%s\n' "$1" | sed -n 1p ; }
rigText(){ printf '%s\n' "$1" | sed '1d' ; }
rigLeft(){ ( cd "$rigProc" 2> /dev/null && ls -A 2> /dev/null | LC_ALL=C grep -c . || : ) ; }

echo "-- 1. a call that ends in time --"
rigOut="$( rigCall "rig fast" "" "" "" 'echo hello; echo noise >&2; exit 3' )"
rigAssert "stdout and exit code come back, the call is not detached" "$( rigHead "$rigOut" ):$( rigText "$rigOut" )" "no|3|:hello"
rigAssert "its stderr is replayed" "$( cat "$rigTmp/err" )" "noise"
rigAssert "nothing is left in the processes folder" "$( rigLeft )" "0"

echo "-- 2. background --"
rigOut="$( rigCall "rig slow" true "" "" 'echo first; sleep 3; echo second' )"
rigAssert "it returns at once, detached, with a handle" "$( rigHead "$rigOut" )" "yes|0|process-1"
rigAssert "the text names the id and the five ways on" "$( rigText "$rigOut" | LC_ALL=C grep -c -e '^TASK-ID=process-1$' -e 'Wait sources=process:process-1' -e 'TaskOutput handle=process-1' -e 'TaskStop handle=process-1' -e 'timeout_action=kill' )" "5"
rigAssert "the handle's files exist: out, err, cmd, pid, began" "$( for rigSuffix in out err cmd pid began ; do [ -e "$rigProc/process-1.$rigSuffix" ] && printf y || printf n ; done )" "yyyyy"
rigPid="$( head -1 "$rigProc/process-1.pid" )"
rigAssert "the task is running and has no status yet" "$( kill -0 "$rigPid" 2> /dev/null && printf running ):$( [ -f "$rigProc/process-1.status" ] && printf status )" "running:"
for rigWait in $(seq 1 60) ; do [ -f "$rigProc/process-1.status" ] && break ; sleep 0.25 ; done
rigAssert "it goes on, ends, and records its status and output through the handle" "$( cat "$rigProc/process-1.status" 2> /dev/null ):$( tr '\n' ' ' < "$rigProc/process-1.out" )" "0:first second "

echo "-- 3. the default time --"
rigOut="$( rigCall MDAT_TOOL_TASK_SECONDS=1 "rig slow" "" "" "" 'sleep 20' )"
rigAssert "the default returns it early, and says so" "$( rigHead "$rigOut" ):$( rigText "$rigOut" | LC_ALL=C grep -c 'the default of 1s passed' )" "yes|0|process-2:1"

echo "-- 4. the caller's timeout --"
rigOut="$( rigCall "rig slow" "" 1 return 'sleep 20' )"
rigAssert "its timeout returns it early, and says so" "$( rigHead "$rigOut" ):$( rigText "$rigOut" | LC_ALL=C grep -c 'your timeout of 1s passed' )" "yes|0|process-3:1"
rigOut="$( rigCall "rig slow" "" 1 "" 'sleep 20' )"
rigAssert "with no action given it returns, never kills" "$( rigHead "$rigOut" )" "yes|0|process-4"

echo "-- 5. timeout_action kill --"
rigOut="$( rigCall "rig slow" "" 1 kill 'echo partial; sleep 21' )"
rigAssert "it ends the task at the timeout and returns what it wrote" "$( rigHead "$rigOut" ):$( rigText "$rigOut" | LC_ALL=C grep -c -e 'was ended at your timeout of 1s' -e '^partial$' )" "no|124|:2"
rigAssert "the sleeping process is gone" "$( ps -ax -o command | LC_ALL=C grep -c '[s]leep 21' || : )" "0"
rigAssert "and no handle was made for it" "$( [ -e "$rigProc/process-5.out" ] && printf made || printf none )" "none"

echo "-- 6. a message addressed to the member --"
rigChat="$rigWs/.local/agents/sessions/$rigSession"
mkdir -p "$rigWs/.local/temp"
printf 'CRIGSES01:1000.000001\n' > "$rigChat/session.thread"
rigChatRun(){ ## code -- in a clean shell with the chat include
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SESSION_ID="$rigSession" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include" ; '"$1"
}
rigChatRun "AgentsToolsSessionChatReaderInit $rigSession keeper-rig" > /dev/null 2>&1
( sleep 2 ; rigChatRun "printf '%s\n' 'hello @keeper-rig' | AgentsToolsSessionChatAppend $rigSession magic-coordinator keeper-rig 1001.000002 CRIGSES01:1000.000001 slack" > /dev/null 2>&1 ) &
rigOut="$( rigCall MDAT_TOOL_TASK_POLL=1 harnessAgent=keeper-rig "rig slow" "" "" "" 'sleep 22' )"
wait
rigAssert "the message returns the call early, and the text says why" "$( rigHead "$rigOut" | cut -d'|' -f1 ):$( rigText "$rigOut" | LC_ALL=C grep -c 'a message for you arrived in the session chat' )" "yes:1"
rigAssert "the message was not consumed: the member's floor still holds it" "$( rigChatRun "AgentsToolsSessionChatFloor $rigSession keeper-rig | grep -c 'hello @keeper-rig'" 2> /dev/null )" "1"
rigOut="$( rigCall harnessAgent=keeper-rig "rig quiet" "" "" "" 'echo done' )"
rigAssert "a call that ends in time is not held back by a message waiting" "$( rigHead "$rigOut" ):$( rigText "$rigOut" )" "no|0|:done"

echo "-- 7. the ceiling --"
rigOut="$( rigCall MDAT_TOOL_TASK_CEILING=2 "rig slow" true "" "" 'sleep 25' )"
rigHandle="$( rigHead "$rigOut" | cut -d'|' -f3 )"
rigPid="$( head -1 "$rigProc/$rigHandle.pid" )"
for rigWait in $(seq 1 40) ; do [ -f "$rigProc/$rigHandle.status" ] && break ; sleep 0.25 ; done
rigAssert "a returned task is ended at the ceiling and records 137" "$( cat "$rigProc/$rigHandle.status" 2> /dev/null ):$( kill -0 "$rigPid" 2> /dev/null && printf alive || printf gone )" "137:gone"

echo "-- 8. plain runs --"
rigOut="$( rigCall MDAT_TOOL_TASK_INNER=1 "rig inner" true "" "" 'echo plain' )"
rigAssert "inside a task the function runs as a capture" "$( rigHead "$rigOut" ):$( rigText "$rigOut" )" "no|0|:plain"
rigOut="$( env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ToolTask.include" ; rigBody(){ echo plain; } ; AgentsToolsTaskCall x true "" "" rigBody ; printf "%s|%s\n" "$agentsTaskDetached" "$agentsTaskOut"' )"
rigAssert "with no session the function runs as a capture" "$rigOut" "no|plain"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TOOL TASK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TOOL_TASK: OK (%d assertions, offline)\n' "$rigPassCount"
