#!/usr/bin/env bash
## Behavioural check on S6.47: an interrupted task states it clearly. A task, a search or a check ended by a time
## limit, a kill or a lost process says so in its result, with what it covered, and its output never reads like a
## complete empty answer (20261102-refactorings.epic.md, item 47). Run rather than read, each case through the real
## entry point of its own surface. Held:
##   1. a tool task ended at the tool ceiling carries the ceiling's own words on its handle, so a reader of the handle
##      learns a limit ended it and what that limit was
##   2. the Bash read of a handle whose status is a signal death says it was ended by a signal and that its output may
##      be incomplete, and never that its output is complete; a clean end still reads as it always did
##   3. the Wait probe of the same handle says it too, on its own `End:` line, and its `State: FINISHED` line is the
##      one it always printed
##   4. a Wait whose sources could not be probed returns its quiet TIMEOUT one-liner AND the line naming the sources
##      whose reads failed, so a wait that read nothing never reads like a wait that read everything and found it quiet
##   5. a check ended at its time limit has that said in its receipt, its FAIL line and the summary, and never only as
##      an exit status 142 a reader has to decode
##   6. a Knowledge source file that cannot be read is named, and a query that answered nothing says how many sources
##      went unread instead of reading as a complete empty answer
##   7. the reason a run ended at the tooling's own spawn bound is one written function, so the record and the notice
##      cannot disagree about it
## Red before S6.47: the ceiling file is linked nowhere (1), a 137 status reads as a complete output (2, 3), the
## one-line TIMEOUT drops the probe-failure line (4), the receipt carries a bare rc=142 (5), an unreadable source is
## silent (6), and the bound is passed to a notice only, never to the record (7).
## Offline: every case is a rig under this check's own temp tree; no endpoint, credential or network is touched.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigHarness="$rigPackage/sh-lib/harness/AgentsUniversalHarness.sh"
rigToolTask="$rigPackage/sh-lib/session/AgentsTools.ToolTask.include"
rigWaitLocal="$rigPackage/sh-lib/member/AgentsTools.MemberWaitLocal.include"
rigRunner="$rigPackage/sh-test/AgentsRunTests.sh"
rigKnowledge="$rigPackage/sh-scripts/DistroAgentsKnowledge.fn.sh"
rigSpawn="$rigPackage/sh-lib/session/AgentsTools.InternOpAgentSpawnProxy.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigToolTask" "$rigWaitLocal" "$rigRunner" "$rigKnowledge" "$rigSpawn" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
[ -x "$rigKnowledge" ] || rigRefuse "the knowledge tool is not executable: $rigKnowledge"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its tests with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInterruptedStatesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"
mkdir -p "$rigTmp/home" "$rigTmp/ws/.local/agents" "$rigTmp/skills/rig-a" "$rigTmp/data" "$rigTmp/work" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/rig-a/rig-a.basic.md"
printf -- '---\nname: rig-a\n---\nmember skill\n' > "$rigTmp/skills/rig-a/SKILL.md"

## A process this check starts and signals later is noted with when it began, and is signalled only while its pid is
## still that process. Whatever a case left running is ended on the way out, and the rig goes with it.
rigUnder(){ ## pid -- every process under it now, one on a line
	ps -A -o pid= -o ppid= 2> /dev/null | LC_ALL=C awk -v root="$1" '{ ppid[ $1 ] = $2 } END { for ( pid in ppid ) { top = pid ; hops = 0 ; while ( ( top in ppid ) && top != root && hops++ < 64 ) top = ppid[ top ] ; if ( top == root && pid != root ) print pid } }'
}
rigStop(){ ## pid of a background job of this shell that is running
	kill -KILL "$1" $( rigUnder "$1" ) 2> /dev/null ; wait "$1" 2> /dev/null
}
rigCleanup(){
	local rigJob
	for rigJob in $( jobs -pr ) ; do rigStop "$rigJob" ; done
	for rigPidFile in "$rigTmp/ws/.local/agents/sessions"/*/processes/*.pid ; do
		[ -f "$rigPidFile" ] || continue
		rigStopPid="$( head -1 "$rigPidFile" 2> /dev/null )"
		[ -z "$rigStopPid" ] || kill -TERM -- "-$rigStopPid" 2> /dev/null || :
	done
	chmod -R u+rwX "$rigTmp" 2> /dev/null || :
	rm -rf -- "$rigTmp"
}
trap rigCleanup EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHas(){ ## file, fixed string -- yes or no
	LC_ALL=C grep -q -F -- "$2" "$1" 2> /dev/null && printf yes || printf no
}

echo "-- 1. a tool task ended at the ceiling carries the ceiling's words on its handle --"
## One call of AgentsToolsTaskCall in a clean shell, as AgentsToolTaskCheck drives it: the result is
## `detached|rc|handle` on the first line and the text after it.
rigTaskSession="rig-interrupt-task"
rigTaskProc="$rigTmp/ws/.local/agents/sessions/$rigTaskSession/processes"
rigTaskOut="$( env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
	MDAT_SPAWN_SESSION_ID="$rigTaskSession" MDAT_TOOL_TASK_CEILING=3 \
	bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ToolTask.include" ; rigBody(){ eval "$1" ; } ; AgentsToolsTaskCall "rig ceiling" true "" "" rigBody "sleep 300" ; printf "%s|%s|%s\n%s\n" "$agentsTaskDetached" "$agentsTaskRc" "$agentsTaskHandle" "$agentsTaskOut"' 2> "$rigTmp/task.err" )"
rigTaskHandle="$( printf '%s\n' "$rigTaskOut" | LC_ALL=C sed -n 's/^yes|0|\(process-[0-9]*\)$/\1/p' | head -1 )"
[ -n "$rigTaskHandle" ] || rigRefuse "the ceiling case started no task: $( printf '%s' "$rigTaskOut" | head -1 )"
for rigTry in $(seq 1 80) ; do [ ! -f "$rigTaskProc/$rigTaskHandle.status" ] || break ; sleep 0.25 ; done
rigAssert "the task was ended, and records the kill's status"  "$( cat "$rigTaskProc/$rigTaskHandle.status" 2> /dev/null )" "137"
rigAssert "its handle carries the ceiling's own words"        "$( cat "$rigTaskProc/$rigTaskHandle.ceiling" 2> /dev/null )" "ended at the ceiling of 3 seconds"

echo "-- 2. the Bash read of a handle ended by a signal --"
rigReadSession="rig-interrupt-read"
rigReadProc="$rigTmp/ws/.local/agents/sessions/$rigReadSession/processes"
mkdir -p "$rigReadProc"
printf '137\n' > "$rigReadProc/process-9.status"
printf 'RIG-SO-FAR\n' > "$rigReadProc/process-9.out"
: > "$rigReadProc/process-9.err"
printf 'ended at the ceiling of 3 seconds\n' > "$rigReadProc/process-9.ceiling"
printf 'sleep 300\n' > "$rigReadProc/process-9.cmd"
printf '991199\n' > "$rigReadProc/process-9.pid"
rigCall(){ ## tool, argument object, session, call name
	local rigStatus=0
	( cd "$rigTmp/ws" && printf '%s' "$2" | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=rig-a MDAT_SPAWN_SESSION_ID="$3" MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 \
		bash "$rigHarness" --intern-tool "$1" --access-read-root "$rigTmp" --access-write-root "$rigTmp" ) \
		> "$rigTmp/$4.out" 2> "$rigTmp/$4.err" || rigStatus=$?
	printf '%s' "$rigStatus" > "$rigTmp/$4.rc"
}
rigCall Bash "{\"handle\":\"process-9\"}" "$rigReadSession" read-sig
rigAssert "the read says a signal ended it"                       "$( rigHas "$rigTmp/read-sig.out" "ENDED BY A SIGNAL (exit status 137)" )" yes
rigAssert "and names the limit that ended it"                     "$( rigHas "$rigTmp/read-sig.out" "ended at the ceiling of 3 seconds" )" yes
rigAssert "and never calls that output complete"                  "$( rigHas "$rigTmp/read-sig.out" "so its output is complete" )" no
rigAssert "it still returns the output written before the end"     "$( rigHas "$rigTmp/read-sig.out" ">RIG-SO-FAR" )" yes
echo "-- 2b. control: the clean end reads exactly as it always did --"
mkdir -p "$rigTmp/ws/.local/agents/sessions/rig-interrupt-clean/processes"
rigCleanProc="$rigTmp/ws/.local/agents/sessions/rig-interrupt-clean/processes"
printf '0\n' > "$rigCleanProc/process-1.status"
printf 'RIG-ALL-DONE\n' > "$rigCleanProc/process-1.out"
: > "$rigCleanProc/process-1.err"
printf 'echo done\n' > "$rigCleanProc/process-1.cmd"
rigCall Bash "{\"handle\":\"process-1\"}" "rig-interrupt-clean" read-clean
rigAssert "control: the complete end keeps its own sentence"      "$( rigHas "$rigTmp/read-clean.out" "This process ENDED with exit status 0, so its output is complete." )" yes
rigAssert "control: and is not called a signal end"              "$( rigHas "$rigTmp/read-clean.out" "ENDED BY A SIGNAL" )" no

echo "-- 3. the Wait probe of the same handle --"
rigProbeOut="$rigTmp/probe.out"
( cd "$rigTmp/ws" && env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SPAWN_SESSION_ID="$rigReadSession" \
	bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberWaitLocal.include" ; waitSessionId="$MDAT_SPAWN_SESSION_ID" ; AgentsWaitProbeProcess rig-a process-9 "" "$1" ; printf "%s" "$?"' rig "$rigProbeOut" ) > "$rigTmp/probe.rc" 2> "$rigTmp/probe.err"
rigAssert "the probe read the handle"                            "$( cat "$rigTmp/probe.rc" )" "0"
rigAssert "its state line is the one it always printed"          "$( LC_ALL=C sed -n 's/^\(State: FINISHED, exit status 137\)$/\1/p' "$rigProbeOut" | head -1 )" "State: FINISHED, exit status 137"
rigAssert "it says on its own line that a signal ended it"       "$( LC_ALL=C grep -c -x 'End: ENDED BY A SIGNAL (exit status 137), so its output stops where that signal caught it and may be incomplete.' "$rigProbeOut" )" "1"
rigAssert "and names the limit the handle carries, on a line of its own" "$( LC_ALL=C grep -c -x 'End: ended at the ceiling of 3 seconds.' "$rigProbeOut" )" "1"
rigAssert "and never calls that output complete"                 "$( rigHas "$rigProbeOut" "so its output is complete" )" no

echo "-- 4. a Wait that could read none of its sources --"
printf 'rig\n' > "$rigTmp/unreadable-source"
chmod 000 "$rigTmp/unreadable-source"
cat "$rigTmp/unreadable-source" > /dev/null 2>&1 && rigRefuse "a mode-000 file is readable here (running as root?), so no source can be made to fail its probe"
printf 'rig\n' > "$rigTmp/readable-source"
## The bound is long enough for at least one round to reach the file: at two seconds the round can be spent on the
ejob default sources and the file is then never-read, which is a different fact from a probe that ran and failed.
rigCall Wait "{\"sources\":\"file:$rigTmp/unreadable-source\",\"timeout\":6}" "rig-interrupt-wait" wait-failed
rigAssert "the quiet result is still its own one line"           "$( LC_ALL=C sed -n '1s/^WAIT-RESULT: TIMEOUT ([0-9][0-9]*s) NEXT: .*$/the-line/p' "$rigTmp/wait-failed.out" )" "the-line"
rigAssert "and the sources whose reads failed are named"         "$( rigHas "$rigTmp/wait-failed.out" "probes that could not run this wait" )" yes
rigAssert "and the failed source is named in that line"          "$( rigHas "$rigTmp/wait-failed.out" "[file:$rigTmp/unreadable-source]" )" yes
echo "-- 4b. control: a wait that read its source and found it quiet --"
rigCall Wait "{\"sources\":\"file:$rigTmp/readable-source\",\"timeout\":6}" "rig-interrupt-wait-ok" wait-quiet
rigAssert "control: a quiet wait reports its TIMEOUT on one line"   "$( LC_ALL=C grep -c '^WAIT-RESULT: TIMEOUT (' "$rigTmp/wait-quiet.out" )" "1"
rigAssert "control: it reports no failed probe"                  "$( rigHas "$rigTmp/wait-quiet.out" "probes that could not run this wait" )" no

echo "-- 5. a check ended at its time limit --"
rigRunHome="$rigTmp/runhome" rigRunWs="$rigTmp/runws" rigRunRoot="$rigTmp/runws/.local/temp/rig-scratch-run/source"
mkdir -p "$rigRunHome" "$rigRunWs/.local/temp" "$rigRunRoot/myx/myx.distro-agents/sh-test/check-fixtures" || exit 1
cp "$rigRunner" "$rigRunRoot/myx/myx.distro-agents/sh-test/AgentsRunTests.sh" || exit 1
cp "$( dirname "$rigRunner" )"/check-fixtures/runner-*.py "$rigRunRoot/myx/myx.distro-agents/sh-test/check-fixtures/" || exit 1
cat > "$rigRunRoot/myx/myx.distro-agents/sh-test/RigHang.test.sh" <<'RIGHANG'
#!/usr/bin/env bash
echo "RIG-HANG-STARTED"
sleep 300
RIGHANG
chmod +x "$rigRunRoot/myx/myx.distro-agents/sh-test/RigHang.test.sh"
rigRunRc=0
( cd "$rigRunRoot/myx/myx.distro-agents/sh-test" && env -i HOME="$rigRunHome" PATH="$rigPath" MMDAPP="$rigRunWs" MDLT_ORIGIN="$rigRunRoot" MYXROOT="${MYXROOT:-/usr/local/share/myx.common}" \
	bash "$rigRunRoot/myx/myx.distro-agents/sh-test/AgentsRunTests.sh" -t 2 --stall-margin 1 ) > "$rigTmp/run.out" 2> "$rigTmp/run.err" || rigRunRc=$?
rigRunDir="$( cat "$rigRunWs/.local/temp/mdat-tests/latest/progress.txt" 2> /dev/null > /dev/null ; readlink "$rigRunWs/.local/temp/mdat-tests/latest" 2> /dev/null )"
rigRunDir="${rigRunDir:-$( ls -d "$rigRunWs/.local/temp/mdat-tests"/*/ 2> /dev/null | LC_ALL=C sort | tail -1 )}"
rigRunDir="${rigRunDir%/}"
[ -n "$rigRunDir" ] && [ -d "$rigRunDir" ] || rigRefuse "the run left no run folder under $rigRunWs/.local/temp/mdat-tests"
rigAssert "the test's receipt says a limit ended it"             "$( LC_ALL=C sed -n 's/^ended-by=//p' "$rigRunDir/RigHang.receipt" 2> /dev/null | head -1 )" "time-limit"
rigAssert "the test's own log carries the limit's words"          "$( rigHas "$rigRunDir/RigHang.log" "ended at its time limit of 2 seconds" )" yes
rigAssert "the FAIL line of the run names the limit"              "$( rigHas "$rigTmp/run.out" "RigHang" )$( rigHas "$rigTmp/run.out" "time-limit" )" "yesyes"
rigAssert "the summary names it too"                             "$( rigHas "$rigRunDir/summary.txt" "FAIL RigHang rc=142 time-limit" )" yes
rigAssert "control: the run itself says nothing of standing still" "$( rigHas "$rigTmp/run.err" "stood still and was ended as stalled" )" no

echo "-- 6. a Knowledge source that cannot be read --"
mkdir -p "$rigTmp/data/board/backlog" || exit 1
printf -- '---\ntype: task\nowner: rig-a\n---\n\n# Rig read\n\nThe RIGKNOWNWORD stands here.\n' > "$rigTmp/data/board/backlog/task-20261019T0100Z-rig-read.md"
printf -- '---\ntype: task\nowner: rig-a\n---\n\n# Rig lost\n\nThe RIGLOSTWORD stands here.\n' > "$rigTmp/data/board/backlog/task-20261019T0101Z-rig-lost.md"
chmod 000 "$rigTmp/data/board/backlog/task-20261019T0101Z-rig-lost.md"
rigQuery(){ ## name, words...
	local rigQueryName="$1" rigQueryRc=0
	shift
	( cd "$rigTmp/ws" && env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=rig-a MDAT_SPAWN_SESSION_ID=rig-knowledge-run \
		bash "$rigKnowledge" "$@" ) > "$rigTmp/$rigQueryName.out" 2> "$rigTmp/$rigQueryName.err" < /dev/null || rigQueryRc=$?
	printf '%s' "$rigQueryRc" > "$rigTmp/$rigQueryName.rc"
}
rigQuery lost --add-board-items --query-keyword RIGLOSTWORD
rigAssert "a source that cannot be read is named"                 "$( rigHas "$rigTmp/lost.err" "task-20261019T0101Z-rig-lost.md" )" yes
rigAssert "and the count of unread sources is said"                "$( rigHas "$rigTmp/lost.err" "could not be read" )" yes
rigAssert "and the empty answer is not called a complete one"       "$( rigHas "$rigTmp/lost.err" "NOT a complete empty answer" )" yes
rigAssert "and it is not reported as a success"                    "$( cat "$rigTmp/lost.rc" )" "1"
echo "-- 6b. control: a query whose sources were all read --"
## The unreadable one is made readable again, so the control's own question is a store that read whole.
chmod 644 "$rigTmp/data/board/backlog/task-20261019T0101Z-rig-lost.md"
rigQuery known --add-board-items --query-keyword RIGKNOWNWORD
rigAssert "control: the section that answers is still found"       "$( rigHas "$rigTmp/known.out" "Rig read" )" yes
rigAssert "control: it returns 0 and names no unread source"       "$( cat "$rigTmp/known.rc" ):$( rigHas "$rigTmp/known.err" "could not be read" )" "0:no"

echo "-- 7. the reason a run ended at the spawn bound --"
rigLift(){ ## file, function name -- the function whole, from its opening line to its closing brace
	LC_ALL=C awk -v wantName="$2" '
		index( $0, wantName "(){" ) == 1 { inFn = 1 ; }
		inFn { print ; }
		inFn && /^\}$/ { inFn = 0 ; seen++ ; }
		END { if ( seen != 1 ) exit 1 ; }
	' "$1"
}
rigBoundFn="$( rigLift "$rigSpawn" AgentsToolsSpawnProxyBoundReason )" || rigBoundFn=""
if [ -z "$rigBoundFn" ] ; then
	rigAssert "the bound's reason is one written function"        "absent from the spawn proxy" "present"
else
	rigBoundText="$( bash -c "$rigBoundFn ; AgentsToolsSpawnProxyBoundReason 1 7" 2> /dev/null )"
	rigBoundNone="$( bash -c "$rigBoundFn ; AgentsToolsSpawnProxyBoundReason 0 ''" 2> /dev/null )"
	rigAssert "a run the bound ended says so, and names the bound"  "$rigBoundText" "ended at the spawn bound of 7 seconds (SPAWN_WAIT_TIMEOUT_SECONDS)"
	rigAssert "a run the bound did not end says nothing of it"      "$rigBoundNone" ""
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INTERRUPTED STATES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INTERRUPTED_STATES: OK (%d assertions, offline)\n' "$rigPassCount"
