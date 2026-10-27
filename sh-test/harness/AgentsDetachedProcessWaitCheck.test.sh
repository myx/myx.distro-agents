#!/usr/bin/env bash
## Behavioural check on the detached Bash of the harness and on Wait over the process it leaves running
## (sh-lib/harness/AgentsUniversalHarness.sh, AgentsHarnessToolBash and AgentsHarnessToolWait; the process
## source is AgentsWaitProbeProcess, AgentsTools.MemberWait.include). Every call is a real one through the
## harness's own served entry point -- `--intern-tool Bash`, `--intern-tool Wait` -- against this check's own
## rig workspace, and a real detached process that writes real files, never a stand-in. Held:
##   1. a detached start hands back a handle (`process-<n>`), and the Wait source of that handle resolves:
##      the process's own state and output arrive under it; a handle this session never started is not read
##      at all, and is named as never read rather than as a source that found nothing
##   2. Wait on the process brings its lines as they come: the first wait returns while the process is still
##      running, with the line written so far alone, and the next returns the rest, and the end itself
##   3. stopping the process closes its handle, and the wait that had been watching it says so: its next
##      return is State: CLOSED, never FINISHED, and a wait after it brings nothing more from that source
##   4. stdin: a process started with the caller's stdin reads it, line for line; one started with none reads
##      /dev/null, so `cat` does not block and the command reaches its own end
##   5. the prefixes: a line on stdout is prefixed `>` and one on stderr `!`, each stream in the order it was
##      written, and one mixed rendering tells the two apart -- no line of either stream wears the other's mark
##   6. two detached starts in one session take two handles, and each handle keeps its own command and its own
##      output: the second start does not overwrite the first, and a read of the first still names the first
##   7. a stop stops the process group, not the wrapper shell alone: a command that ignores TERM is killed and
##      writes nothing after the stop, and a closed handle delivers nothing written to it after the close
## The rig is a workspace of its own, under the scratch of this one, with its own MMDAPP and a member the
## served identity resolves; the package under it is the one at the origin, never a copy. Every call is
## bounded by its own alarm, and the check itself needs no endpoint, no credential and no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigMember="rig-a"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDetachedProcessWaitCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/skills/$rigMember" "$rigTmp/home" "$rigTmp/work" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCall(){ ## tool, argument object, session, call name -- what the call printed in <name>.out, its status in <name>.rc
	local rigStatus=0 rigName="$4"
	( cd "$rigTmp/ws" && printf '%s' "$2" | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="$3" \
		MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigHarness" --intern-tool "$1" --access-read-root "$rigTmp" --access-write-root "$rigTmp" ) \
		> "$rigTmp/$rigName.out" 2> "$rigTmp/$rigName.err" || rigStatus=$?
	printf '%s' "$rigStatus" > "$rigTmp/$rigName.rc"
}
rigSaid(){ ## fixed whole line, call name -- how many lines of what that call printed are exactly it
	LC_ALL=C grep -c -x -F -- "$1" "$rigTmp/$2.out" 2> /dev/null || :
}
rigSaidRe(){ ## regular expression, call name -- how many lines of what that call printed match it
	LC_ALL=C grep -c -E -- "$1" "$rigTmp/$2.out" 2> /dev/null || :
}
rigHead(){ ## call name -- the first line of what that call printed
	LC_ALL=C head -1 "$rigTmp/$1.out" 2> /dev/null || :
}
rigHandle(){ ## call name -- the process handle a detached start printed
	LC_ALL=C sed -n 's/^Process handle: //p' "$rigTmp/$1.out" 2> /dev/null | LC_ALL=C head -1
}
rigLineOf(){ ## fixed whole line, call name -- the number of its first line, or 0
	LC_ALL=C grep -n -x -F -- "$1" "$rigTmp/$2.out" 2> /dev/null | LC_ALL=C head -1 | LC_ALL=C cut -d : -f 1
}
rigSection(){ ## process handle, call name -- the lines of what that call printed under the source process:<handle> alone (a session's Wait set keeps the sources of its earlier waits, so one wait can bring several)
	LC_ALL=C awk -v want="# arrived on: process:$1" '$0 == want { inSection = 1 ; next ; } /^# arrived on: / { inSection = 0 ; } /^# --- end ---$/ { inSection = 0 ; } inSection { print ; }' "$rigTmp/$2.out" 2> /dev/null
}
rigEarlier(){ ## fixed text, fixed text, call name -- yes where the first stands above the second
	local rigFirst rigSecond
	rigFirst="$( rigLineOf "$1" "$3" )" ; rigSecond="$( rigLineOf "$2" "$3" )"
	[ -n "$rigFirst" ] && [ -n "$rigSecond" ] && [ "$rigFirst" -lt "$rigSecond" ] && printf 'yes' || printf 'no'
}
rigAwaitEnd(){ ## session, handle, call name -- reads the process by its handle until it has ended
	local rigTry=0
	while [ "$rigTry" -lt 60 ] ; do
		rigTry=$(( rigTry + 1 ))
		rigCall Bash "{\"handle\":\"$2\"}" "$1" "$3"
		LC_ALL=C grep -q -x 'PROCESS-RESULT: FINISHED' "$rigTmp/$3.out" 2> /dev/null && return 0
		sleep 0.25
	done
	return 1
}
rigStart(){ ## session, command, call name -- one detached start of the command, in the rig's work folder
	## The commands this check starts are plain shell words: no quote and no backslash, so they travel as they are.
	rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"$2\",\"detach\":true}" "$1" "$3"
}

## ---- 1. the handle of a detached start is one the Wait source resolves ----
echo "-- 1. a detached start hands back a handle the Wait source resolves --"
rigSession1="rig-detached-handle"
rigStart "$rigSession1" 'sleep 5; echo RIG-HANDLE-ONE; sleep 6' start1
rigAssert "the start says the process runs, and names its handle" "$( rigSaid 'PROCESS-RESULT: RUNNING' start1 ):$( printf '%s' "$( rigHandle start1 )" | LC_ALL=C grep -c -E '^process-[0-9]+$' )" "1:1"
rigHandle1="$( rigHandle start1 )"
rigCall Wait "{\"sources\":\"process:$rigHandle1\",\"timeout\":40}" "$rigSession1" watch1
rigAssert "the wait resolves that handle: the process's own state and output arrive under it" \
	"$( rigHead watch1 ):$( rigSaid "# arrived on: process:$rigHandle1" watch1 ):$( rigSaid '>RIG-HANDLE-ONE' watch1 ):$( rigSaidRe '^State: RUNNING$' watch1 )" \
	"WAIT-RESULT: RECEIVED:1:1:1"
rigCall Wait '{"sources":"process:process-9","timeout":0}' "$rigSession1" unknown1
rigAssert "control: a handle this session never started is named as never read, not as a source that found nothing" \
	"$( rigSaidRe '^WAIT-RESULT: TIMEOUT' unknown1 ):$( rigSaidRe '^WAIT-NEVER-READ: .*\[process:process-9\]' unknown1 )" "1:1"

## ---- 2. the lines come as they are written, and the end comes too ----
echo "-- 2. Wait brings the lines as they come, and returns when the process ends --"
rigSession2="rig-detached-grow"
rigStart "$rigSession2" 'sleep 6; echo RIG-GROW-ONE; sleep 5; echo RIG-GROW-TWO; echo RIG-GROW-ERR >&2' start2
rigAssert "the second process runs under the handle its own start returned" "$( rigSaid 'PROCESS-RESULT: RUNNING' start2 ):$( printf '%s' "$( rigHandle start2 )" | LC_ALL=C grep -c -E '^process-[0-9]+$' )" "1:1"
rigHandle2="$( rigHandle start2 )"
rigCall Wait "{\"sources\":\"process:$rigHandle2\",\"timeout\":40}" "$rigSession2" watch2a
rigAssert "the first wait returns while the process still runs, with the one line written so far" \
	"$( rigHead watch2a ):$( rigSaid '>RIG-GROW-ONE' watch2a ):$( rigSaidRe '^State: RUNNING$' watch2a ):$( rigSaid '>RIG-GROW-TWO' watch2a )" \
	"WAIT-RESULT: RECEIVED:1:1:0"
rigCall Wait '{"mode":"continue","timeout":40}' "$rigSession2" watch2b
rigAssert "the next wait returns the rest, and the end itself: the other line, the error line, and the exit status" \
	"$( rigHead watch2b ):$( rigSaid '>RIG-GROW-TWO' watch2b ):$( rigSaid '!RIG-GROW-ERR' watch2b ):$( rigSaid 'State: FINISHED, exit status 0' watch2b )" \
	"WAIT-RESULT: RECEIVED:1:1:1"

## ---- 3. stopping it closes the handle, and the wait that watched says so ----
echo "-- 3. stopping the process closes its handle, and the wait watching it says so --"
rigSession3="rig-detached-stop"
rigStart "$rigSession3" 'sleep 6; echo RIG-STOP-BEFORE; sleep 10; echo RIG-STOP-AFTER' start3
rigHandle3="$( rigHandle start3 )"
rigAssert "the process to stop is the one this start returned" "$( rigSaid 'PROCESS-RESULT: RUNNING' start3 ):$( printf '%s' "$rigHandle3" | LC_ALL=C grep -c -E '^process-[0-9]+$' )" "1:1"
rigCall Wait "{\"sources\":\"process:$rigHandle3\",\"timeout\":40}" "$rigSession3" watch3a
rigAssert "control: before the stop, the wait watching it says it runs" "$( rigHead watch3a ):$( rigSaidRe '^State: RUNNING$' watch3a )" "WAIT-RESULT: RECEIVED:1"
rigCall Bash "{\"handle\":\"$rigHandle3\",\"stop\":true}" "$rigSession3" stop3
rigAssert "the stop closes that handle and says so" "$( rigSaid 'PROCESS-RESULT: CLOSED' stop3 ):$( rigSaidRe '^You stopped it' stop3 ):$( rigSaid "Process handle: $rigHandle3" stop3 )" "1:1:1"
rigCall Wait '{"mode":"continue","timeout":40}' "$rigSession3" watch3b
rigAssert "the wait that had been watching returns, and it says the process was stopped: CLOSED, never FINISHED" \
	"$( rigHead watch3b ):$( rigSaidRe '^State: CLOSED$' watch3b ):$( rigSaidRe '^State: FINISHED' watch3b ):$( rigSaid '>RIG-STOP-AFTER' watch3b )" \
	"WAIT-RESULT: RECEIVED:1:0:0"
rigCall Wait '{"mode":"continue","timeout":3}' "$rigSession3" watch3c
rigAssert "a wait after the stop brings nothing more from that source: the watching has ended" \
	"$( rigSaidRe '^WAIT-RESULT: TIMEOUT' watch3c ):$( rigSaid '>RIG-STOP-BEFORE' watch3c ):$( rigSaid '>RIG-STOP-AFTER' watch3c )" "1:0:0"

## ---- 4. stdin: the caller's is read, and with none the process reads /dev/null ----
echo "-- 4. stdin: the caller's is read; with none the process reads /dev/null and does not block --"
rigSession4="rig-detached-stdin"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"cat\",\"detach\":true,\"stdin\":\"RIG-STDIN-ONE\\nRIG-STDIN-TWO\\n\"}" "$rigSession4" start4
rigHandle4="$( rigHandle start4 )"
rigEndRc=0 ; rigAwaitEnd "$rigSession4" "$rigHandle4" read4 || rigEndRc=$?
rigAssert "a process started with the caller's stdin reads it, line for line, and ends on its own" \
	"$rigEndRc:$( rigSaid '>RIG-STDIN-ONE' read4 ):$( rigSaid '>RIG-STDIN-TWO' read4 ):$( rigSaid 'This process ENDED with exit status 0, so its output is complete.' read4 )" "0:1:1:1"
rigSession5="rig-detached-nostdin"
rigStart "$rigSession5" 'cat; echo RIG-STDIN-END' start5
rigHandle5="$( rigHandle start5 )"
rigEndRc=0 ; rigAwaitEnd "$rigSession5" "$rigHandle5" read5 || rigEndRc=$?
rigAssert "with no stdin the process reads /dev/null: cat does not block, and the command reaches its own end" \
	"$rigEndRc:$( rigSaid '>RIG-STDIN-END' read5 ):$( rigSaid 'This process ENDED with exit status 0, so its output is complete.' read5 ):$( rigSaid 'This process is STILL RUNNING' read5 )" "0:1:1:0"

## ---- 5. > for stdout and ! for stderr, each in the order it was written ----
echo "-- 5. a line on stdout is prefixed > and one on stderr !, told apart in one mixed rendering --"
rigSession6="rig-detached-prefix"
rigStart "$rigSession6" 'echo RIG-OUT-ONE; echo RIG-ERR-ONE >&2; echo RIG-OUT-TWO; echo RIG-ERR-TWO >&2' start6
rigHandle6="$( rigHandle start6 )"
rigAwaitEnd "$rigSession6" "$rigHandle6" read6
rigAssert "each line of the process carries its own stream's mark, and no line is left bare" \
	"$( rigSaid '>RIG-OUT-ONE' read6 ):$( rigSaid '>RIG-OUT-TWO' read6 ):$( rigSaid '!RIG-ERR-ONE' read6 ):$( rigSaid '!RIG-ERR-TWO' read6 ):$( rigSaidRe '^RIG-' read6 )" "1:1:1:1:0"
rigAssert "the marks are told apart in one mixed rendering: neither stream wears the other's" \
	"$( rigSaid '!RIG-OUT-ONE' read6 ):$( rigSaid '>RIG-ERR-ONE' read6 ):$( rigSaidRe '^[>!]RIG-' read6 )" "0:0:4"
rigAssert "each stream keeps the order it was written in, and both are in that one rendering" \
	"$( rigEarlier '>RIG-OUT-ONE' '>RIG-OUT-TWO' read6 ):$( rigEarlier '!RIG-ERR-ONE' '!RIG-ERR-TWO' read6 ):$( rigSaidRe '^[>!]RIG-' read6 )" "yes:yes:4"

## ---- 6. two detached starts in one session keep distinct handles, each with its own output ----
echo "-- 6. two detached processes in one session take two handles, and each keeps its own output --"
rigSession7="rig-detached-two"
rigStart "$rigSession7" 'sleep 5; echo RIG-FIRST-OWN; sleep 40' start7a
rigStart "$rigSession7" 'sleep 9; echo RIG-SECOND-OWN; sleep 3' start7b
rigHandle7a="$( rigHandle start7a )"
rigHandle7b="$( rigHandle start7b )"
rigDistinct7="no"
if [ -n "$rigHandle7a" ] && [ -n "$rigHandle7b" ] && [ "$rigHandle7a" != "$rigHandle7b" ] ; then rigDistinct7="yes" ; fi
rigAssert "the second start takes a handle of its own: the two processes are named apart" \
	"$( printf '%s' "$rigHandle7a" | LC_ALL=C grep -c -E '^process-[0-9]+$' ):$( printf '%s' "$rigHandle7b" | LC_ALL=C grep -c -E '^process-[0-9]+$' ):$rigDistinct7" "1:1:yes"
rigCall Wait "{\"sources\":\"process:$rigHandle7a\",\"timeout\":40}" "$rigSession7" watch7a
rigAssert "the wait on the first handle resolves the first process, and brings its output alone" \
	"$( rigHead watch7a ):$( rigSaid "# arrived on: process:$rigHandle7a" watch7a ):$( rigSaid '>RIG-FIRST-OWN' watch7a ):$( rigSaid '>RIG-SECOND-OWN' watch7a )" \
	"WAIT-RESULT: RECEIVED:1:1:0"
rigCall Wait "{\"sources\":\"process:$rigHandle7b\",\"timeout\":40}" "$rigSession7" watch7b
rigAssert "the wait on the second handle resolves the second process, and brings its output alone" \
	"$( rigHead watch7b ):$( rigSaid "# arrived on: process:$rigHandle7b" watch7b ):$( rigSection "$rigHandle7b" watch7b | LC_ALL=C grep -c -x '>RIG-SECOND-OWN' ):$( rigSection "$rigHandle7b" watch7b | LC_ALL=C grep -c -x '>RIG-FIRST-OWN' )" \
	"WAIT-RESULT: RECEIVED:1:1:0"
rigCall Bash "{\"handle\":\"$rigHandle7a\"}" "$rigSession7" read7a
rigAssert "a read of the first handle still names the first command and its output: the second start overwrote nothing" \
	"$( rigSaid 'Command: sleep 5; echo RIG-FIRST-OWN; sleep 40' read7a ):$( rigSaid '>RIG-FIRST-OWN' read7a ):$( rigSaid '>RIG-SECOND-OWN' read7a )" "1:1:0"
rigCall Bash "{\"handle\":\"$rigHandle7a\",\"stop\":true}" "$rigSession7" stop7a
rigCall Bash "{\"handle\":\"$rigHandle7b\",\"stop\":true}" "$rigSession7" stop7b
rigAssert "each stop closes the handle it names, and only that one" \
	"$( rigSaid "Process handle: $rigHandle7a" stop7a ):$( rigSaid "Process handle: $rigHandle7b" stop7b ):$( rigSaid 'PROCESS-RESULT: CLOSED' stop7a ):$( rigSaid 'PROCESS-RESULT: CLOSED' stop7b )" "1:1:1:1"

## ---- 7. a stop stops the process itself, and a closed handle delivers nothing written after it ----
echo "-- 7. a stop ends the command itself, and a closed handle delivers nothing written after the close --"
rigSession8="rig-detached-after-close"
rigProcessDir8="$rigTmp/ws/.local/agents/sessions/$rigSession8/processes"
## It ignores TERM on purpose, and starts a child of its own that ignores it too: a stop that signals
## the wrapper alone leaves both running, and the command then writes a line afterwards -- to its own
## `.out` even where nothing reads the handle any more. The child records its own pid, so the check
## can ask the process table whether the stop reached it.
rigStart "$rigSession8" "trap '' TERM HUP INT; sleep 30 & echo \$! > RIG-CHILD-PID; sleep 4; echo RIG-CLOSE-BEFORE; sleep 5; echo RIG-AFTER-CLOSE" start8
rigHandle8="$( rigHandle start8 )"
rigCall Wait "{\"sources\":\"process:$rigHandle8\",\"timeout\":40}" "$rigSession8" watch8a
rigAssert "control: the process runs and has written its line before the stop" \
	"$( rigHead watch8a ):$( rigSaid '>RIG-CLOSE-BEFORE' watch8a ):$( rigSaidRe '^State: RUNNING$' watch8a )" "WAIT-RESULT: RECEIVED:1:1"
rigChild8=""
read -r rigChild8 < "$rigTmp/work/RIG-CHILD-PID" 2> /dev/null || rigChild8=""
rigCall Bash "{\"handle\":\"$rigHandle8\",\"stop\":true}" "$rigSession8" stop8
rigAlive8="gone"
sleep 1
[ -z "$rigChild8" ] || ! kill -0 "$rigChild8" 2> /dev/null || rigAlive8="still running"
rigAssert "the stop ends the command's own children with it, not the wrapper shell alone: the child that ignored TERM is gone" \
	"$( rigSaid 'PROCESS-RESULT: CLOSED' stop8 ):$( printf '%s' "$rigChild8" | LC_ALL=C grep -c -E '^[0-9]+$' ):$rigAlive8" "1:1:gone"
rigCall Wait '{"mode":"continue","timeout":40}' "$rigSession8" watch8b
rigAssert "the wait that watched it returns the CLOSED state, and delivers no line written after the stop" \
	"$( rigHead watch8b ):$( rigSaidRe '^State: CLOSED$' watch8b ):$( rigSaid '>RIG-AFTER-CLOSE' watch8b )" "WAIT-RESULT: RECEIVED:1:0"
## A straggler writes straight into the closed handle's own file, as a child that outlived the stop
## would: the handle was closed at a byte count, so neither reader may deliver a byte past it.
printf 'RIG-STRAggler-AFTER-CLOSE\n' >> "$rigProcessDir8/$rigHandle8.out"
rigCall Bash "{\"handle\":\"$rigHandle8\"}" "$rigSession8" read8
rigAssert "a read of the closed handle stops at the close: the straggler is not delivered, what stood before it is" \
	"$( rigHead read8 ):$( rigSaid '>RIG-CLOSE-BEFORE' read8 ):$( rigSaid '>RIG-STRAggler-AFTER-CLOSE' read8 )" "PROCESS-RESULT: CLOSED:1:0"
rigCall Bash "{\"handle\":\"$rigHandle8\",\"stop\":true}" "$rigSession8" stop8again
rigCall Bash "{\"handle\":\"$rigHandle8\"}" "$rigSession8" read8b
rigAssert "a second stop leaves the close where the first one took it: the straggler stays undelivered" \
	"$( rigHead read8b ):$( rigSaid '>RIG-CLOSE-BEFORE' read8b ):$( rigSaid '>RIG-STRAggler-AFTER-CLOSE' read8b )" "PROCESS-RESULT: CLOSED:1:0"
rigCall Wait '{"mode":"continue","timeout":3}' "$rigSession8" watch8c
rigAssert "nor does a wait on it: the closed source returns nothing more, on the straggler or on the later line" \
	"$( rigSaidRe '^WAIT-RESULT: TIMEOUT' watch8c ):$( rigSaid '>RIG-STRAggler-AFTER-CLOSE' watch8c ):$( rigSaid '>RIG-AFTER-CLOSE' watch8c )" "1:0:0"
rigAssert "the command itself wrote nothing after the stop, even to its own file: nothing was left running to write it" \
	"$( LC_ALL=C grep -c -F -- 'RIG-AFTER-CLOSE' "$rigProcessDir8/$rigHandle8.out" 2> /dev/null || : )" "0"

## ---- 8. a stop signals the pid only while it is still the process that began under the handle ----
echo "-- 8. a pid that is no longer the process of its handle is not signalled --"
rigSession9="rig-detached-pid-kept"
rigProcessDir9="$rigTmp/ws/.local/agents/sessions/$rigSession9/processes"
rigStart "$rigSession9" 'sleep 45' start9
rigHandle9="$( rigHandle start9 )"
rigWrapper9="$( cat "$rigProcessDir9/$rigHandle9.pid" 2> /dev/null )"
rigAssert "control: the start kept when the process began, beside its pid" "$( LC_ALL=C grep -c -E "^$rigWrapper9 " "$rigProcessDir9/$rigHandle9.began" 2> /dev/null || : )" "1"
## The record of the start is made to name another start, as when the number has been given to a process of another since: the stop must not signal it.
cp "$rigProcessDir9/$rigHandle9.began" "$rigTmp/began.9"
printf '%s Mon_Jan__1_00:00:00_2001\n' "$rigWrapper9" > "$rigProcessDir9/$rigHandle9.began"
rigCall Bash "{\"handle\":\"$rigHandle9\",\"stop\":true}" "$rigSession9" stop9
rigAssert "the stop closes the handle, says nothing was signalled, and the process it names is still running" \
	"$( rigSaid 'PROCESS-RESULT: CLOSED' stop9 ):$( rigSaidRe '^Nothing was signalled' stop9 ):$( kill -0 "$rigWrapper9" 2> /dev/null && printf running || printf gone )" "1:1:running"
## Put right, a second handle on a fresh process is stopped as ever.
rigStart "$rigSession9" 'sleep 45' start9b
rigHandle9b="$( rigHandle start9b )"
rigWrapper9b="$( cat "$rigProcessDir9/$rigHandle9b.pid" 2> /dev/null )"
rigCall Bash "{\"handle\":\"$rigHandle9b\",\"stop\":true}" "$rigSession9" stop9b
sleep 1
rigAssert "a pid that is still the process of its handle is signalled: the stop ends it, and says nothing of not signalling" \
	"$( kill -0 "$rigWrapper9b" 2> /dev/null && printf running || printf gone ):$( rigSaidRe '^Nothing was signalled' stop9b )" "gone:0"
## The first process is ended through its handle, with the start put back, so none is left behind.
cp "$rigTmp/began.9" "$rigProcessDir9/$rigHandle9.began"
rm -f "$rigProcessDir9/$rigHandle9.closed"
rigCall Bash "{\"handle\":\"$rigHandle9\",\"stop\":true}" "$rigSession9" stop9c
sleep 1
rigAssert "put back, the same stop ends it" "$( kill -0 "$rigWrapper9" 2> /dev/null && printf running || printf gone )" "gone"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DETACHED PROCESS WAIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DETACHED_PROCESS_WAIT: OK (%d assertions, offline)\n' "$rigPassCount"
