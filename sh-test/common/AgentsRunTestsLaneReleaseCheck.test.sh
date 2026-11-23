#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
## Behavioural check on a lane whose holder is alive while its work is finished (sh-test/AgentsRunTests.sh, A LANE IS
## WHAT A RUN HOLDS). Run, not read, on a fixture machine built here: a HOME holding the machine's one line of runs
## (.agents/magic-team/suite-queue) and its lanes (.agents/magic-team/suite-lanes), a workspace, and under its
## .local/temp one copy of the package, holding the runner under test, its keepers and one tiny check. Held:
##  1. Lane 1, the hand rule's lock ($MMDAPP/.local/temp/suite-run.lock), whose holder process is alive and whose run
##     folder holds as many receipts as its tests.list has lines, is given back: the run behind it takes lane 1, runs its
##     own check, and names the holder it freed in one line.
##  2. Control, the other direction: the same lock one receipt short is kept. The run behind waits, is refused at its own
##     bound, never runs its check, and lane 1 still names its holder.
##  3. Control: a lock whose holder process is gone is given back, as it is today, whatever its run folder holds.
##  4. The same two directions on numbered lanes: lane 2, whose live holder's work is finished, is given back and taken,
##     while lane 3, whose live holder is one receipt short, keeps its lane, and lane 1 stays the unfinished holder's.
## THE FIXTURE'S HOLDER. A lane is judged alive by its holder's process, as AgentsRunRunnerAlive reads it: a process whose
## command line names AgentsRunTests.sh. A holder here is a bash process running a file of that name which sleeps, which is
## the shape the live fault had: an idle runner, its only check long ended, still holding the lane. A dead holder is a pid
## whose process has ended.
## THE HOLDER RECORD. Each lane's record is the shape the runner writes: `pid=`, `runner-pid:`, `session=` and `origin=`
## for a numbered lane, `runner-pid:`, `session=`, `lanes: yes` and `taken:` for lane 1, and beside them the `rundir=` line
## this change adds, naming the run folder the holder is working in. A run folder here holds a `tests.list` of two checks
## and either two receipts, its work finished, or one, its work unfinished.
## HOW "NAMES THE HOLDER IT FREED" IS READ. A lane's holder is named by its session in this runner -- a lane's record
## carries `session=`, AgentsRunLaneSession reads it, and a waiter names a holder as `pid=<pid> session=<session>` -- and a
## record's pid names it too. So the naming is one line of the run's output, other than a line that says it waits its turn
## or that it was not started, that holds the freed holder's session or pid, and exactly one such line: a run that names
## the holder twice does not say it in one line. Those two kinds of line are left out because both name the run ahead of
## this one, which on a tree before the change is the holder that never gave its lane back.
## RED ON THE TREE BEFORE THE CHANGE, measured: a lane whose holder is alive is never given back, whatever its run folder
## holds, so 1 never takes lane 1 and 4 never takes lane 2, neither names a freed holder, and both are refused at their own
## bound. The kept locks of 2 and 4 are the controls that a live holder is read alive at all: were one read dead, that
## section would run its check instead.
## Nothing here is told by how long a run takes: each run behind is given a bound of its own, and a run never given its lane
## ends at that bound rather than at any clock of this check's.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigRunner="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its checks with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsLaneReleaseCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigHolders=""
rigCleanUp(){ ## -- the stand-in holders ended, waited for so the shell reports none of them, and the rig gone
	local cleanPid
	rigProcSignalWithChildren TERM $rigHolders 2> /dev/null
	for cleanPid in $rigHolders ; do wait "$cleanPid" 2> /dev/null ; done
	rm -rf -- "$rigTmp"
}
trap rigCleanUp EXIT
rigHome="$rigTmp/home" ; rigWs="$rigTmp/ws"
rigQueue="$rigHome/.agents/magic-team/suite-queue"
rigLanes="$rigHome/.agents/magic-team/suite-lanes"
rigWorkers="$rigHome/.agents/magic-team/suite-workers"
rigLock="$rigWs/.local/temp/suite-run.lock"
mkdir -p "$rigHome" "$rigWs/.local/temp" "$rigWs/.local/agents/members"
: > "$rigTmp/log"
## The bound of the run behind a lock, in seconds: a run never given its lane ends here, on a red tree as on a green one.
## It is reached at the second pass of the runner's wait, so each such case costs that wait's own first sleep.
rigBound=1

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## ---- the fixture ----
rigRoot(){ ## session -- the source root of that session's copy of the package
	printf '%s\n' "$rigWs/.local/temp/rig-scratch-$1/source"
}
rigPackage(){ ## session -- that copy: the runner under test, its keepers, and one tiny check. The check says in the
## shared log when it begins and ends, and what lane 1, lane 2 and lane 3 held at the moment it ran
	local packageTests ; packageTests="$( rigRoot "$1" )/myx/myx.distro-agents/sh-test"
	mkdir -p "$packageTests/check-fixtures" || rigRefuse "the copy could not be made: $1"
	cp "$rigRunner" "$packageTests/AgentsRunTests.sh" && cp "$( dirname "$rigRunner" )/check-fixtures"/runner-*.py "$packageTests/check-fixtures"/ || rigRefuse "the runner could not be copied: $1"
	## THE RUNNER IS A ROUTER: its parts travel with it, or the rig copy finds none and runs nothing.
	mkdir -p "$packageTests/runner" && cp "$( dirname "$rigRunner" )"/runner/*.sh "$packageTests/runner"/ || rigRefuse "the runner parts could not be copied into the rig"
	cat > "$packageTests/RigTiny.test.sh" <<'RIGTINY'
#!/usr/bin/env bash
printf 'BEGIN %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
printf 'LANE %s lock-pid=%s lock-session=%s lane2-pid=%s lane2-session=%s lane3-pid=%s lane3-session=%s\n' "$RIG_SUITE" \
	"$( LC_ALL=C sed -n 's/^runner-pid: //p' "$MMDAPP/.local/temp/suite-run.lock/holder.txt" 2> /dev/null | LC_ALL=C sed -n 1p )" \
	"$( LC_ALL=C sed -n 's/^session=//p' "$MMDAPP/.local/temp/suite-run.lock/holder.txt" 2> /dev/null | LC_ALL=C sed -n 1p )" \
	"$( LC_ALL=C sed -n 's/^pid=//p' "$HOME/.agents/magic-team/suite-lanes/lane.2/pid" 2> /dev/null | LC_ALL=C sed -n 1p )" \
	"$( LC_ALL=C sed -n 's/^session=//p' "$HOME/.agents/magic-team/suite-lanes/lane.2/pid" 2> /dev/null | LC_ALL=C sed -n 1p )" \
	"$( LC_ALL=C sed -n 's/^pid=//p' "$HOME/.agents/magic-team/suite-lanes/lane.3/pid" 2> /dev/null | LC_ALL=C sed -n 1p )" \
	"$( LC_ALL=C sed -n 's/^session=//p' "$HOME/.agents/magic-team/suite-lanes/lane.3/pid" 2> /dev/null | LC_ALL=C sed -n 1p )" >> "$RIG_SHARED/log"
printf 'END %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
echo "RIG_TINY: OK"
RIGTINY
}
rigPackage a

rigRun(){ ## session, runner args... -- that session's runner, started in the background from its own copy with --wait, so
## a run never given its lane is refused at its own bound; its output in <session>.out
	( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$( rigRoot "$1" )" \
		MYXROOT="${MYXROOT:-/usr/local/share/myx.common}" RIG_SHARED="$rigTmp" RIG_SUITE="$1" \
		MDAT_SPAWN_SESSION_ID="rig-session-$1" MDAT_SUITE_QUEUE_LIMIT="$rigBound" \
		bash "$( rigRoot "$1" )/myx/myx.distro-agents/sh-test/AgentsRunTests.sh" "${@:2}" ) > "$rigTmp/$1.out" 2>&1 &
	rigLast=$!
	rigProcNote "$rigLast"
}
rigEnd(){ ## job -- waits for that runner to end, its status in rigRc
	rigRc=0 ; wait "$1" 2> /dev/null || rigRc=$?
}
rigFresh(){ ## lanes -- a clean machine of this rig at that many lanes: no line, no lock, no lane, no slot state, no log
	rm -rf "$rigQueue" "$rigLanes" "$rigLock" "$rigWorkers" ; : > "$rigTmp/log" ; rm -f "$rigTmp/a.out"
	rigLanes "$1"
	mkdir -p "$rigWorkers" && printf '2\n' > "$rigWorkers/budget"
}
rigLanes(){ ## number -- how many lane(s) this rig's machine allows, set by hand so nothing of it waits on the pace of a real machine
	mkdir -p "$rigLanes" && printf '%s\n' "$1" > "$rigLanes/max" && printf '%s\n' "$1" > "$rigLanes/count"
}
rigRunFolder(){ ## folder, list lines, receipts -- a run folder of that shape: what a holder's work leaves behind
	local folderPath="$1" folderAll="$2" folderHave="$3" folderIndex=1
	mkdir -p "$folderPath" || rigRefuse "a run folder could not be made: $folderPath"
	: > "$folderPath/tests.list"
	while [ "$folderIndex" -le "$folderAll" ] ; do printf 'RigTiny%s 60\n' "$folderIndex" >> "$folderPath/tests.list" ; folderIndex=$(( folderIndex + 1 )) ; done
	folderIndex=1
	while [ "$folderIndex" -le "$folderHave" ] ; do
		printf 'rc=0\nseconds=1\nlast=RIG_TINY: OK\n' > "$folderPath/RigTiny$folderIndex.receipt"
		folderIndex=$(( folderIndex + 1 ))
	done
}
rigHolderPid=""
rigLiveHolder(){ ## -- sets rigHolderPid to a runner that is alive and idle: a bash process running a file named
## AgentsRunTests.sh that sleeps, as a lane's holder is judged alive by. Its streams are none of this shell's, so a waiting
## caller is never held open by it
	local holderDir ; holderDir="$( mktemp -d "$rigTmp/holder.XXXXXXXX" )" || rigRefuse "a stand-in holder could not be made"
	printf '#!/usr/bin/env bash\nsleep 600\n' > "$holderDir/AgentsRunTests.sh" || rigRefuse "a stand-in holder could not be written"
	bash "$holderDir/AgentsRunTests.sh" > /dev/null 2>&1 < /dev/null &
	rigHolderPid=$!
	rigHolders="$rigHolders $rigHolderPid"
	rigProcNote "$rigHolderPid"
}
rigDeadPid(){ ## -- the pid of a process that has ended
	( exit 0 ) & local deadPid=$! ; wait "$deadPid" 2> /dev/null ; printf '%s\n' "$deadPid"
}
rigHandLock(){ ## runner pid, session, run folder (or nothing) -- lane 1's holder record, as the runner writes it
	mkdir -p "$rigLock" || rigRefuse "the hand rule's lock could not be made: $rigLock"
	{
		printf 'runner-pid: %s\n' "$1"
		printf 'session=%s\n' "$2"
		[ -z "${3:-}" ] || printf 'rundir=%s\n' "$3"
		printf 'agent: AgentsRunTests.sh, a run from %s\n' "$( rigRoot a )"
		printf 'lanes: yes\n'
		printf 'taken: %s\n' "$( date -u +%Y-%m-%dT%H:%M:%SZ )"
	} > "$rigLock/holder.txt"
}
rigLaneRecord(){ ## lane number, runner pid, session, run folder (or nothing) -- that numbered lane's holder record, as the runner writes it
	mkdir -p "$rigLanes/lane.$1" || rigRefuse "numbered lane $1 could not be made under $rigLanes"
	{
		printf 'pid=%s\n' "$2"
		printf 'runner-pid: %s\n' "$2"
		printf 'session=%s\n' "$3"
		[ -z "${4:-}" ] || printf 'rundir=%s\n' "$4"
		printf 'origin=%s\n' "$( rigRoot a )"
		printf 'taken: %s\n' "$( date -u +%Y-%m-%dT%H:%M:%SZ )"
	} > "$rigLanes/lane.$1/pid"
}
rigSaid(){ ## session, fixed text -- how many lines of its output hold the text
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" 2> /dev/null || :
}
rigFreed(){ ## holder session, holder pid -- how many lines of the run's output name that holder, a line that says the run
## waits its turn or that it was not started left out: the naming of a holder the run freed is a line of its own
	LC_ALL=C grep -F -e "$1" -e "$2" "$rigTmp/a.out" 2> /dev/null \
		| LC_ALL=C grep -v -F -e 'waits its turn behind' -e 'not started:' | LC_ALL=C grep -c . || :
}
rigFound(){ ## session -- what its check wrote of the lanes and the lock at the moment it ran
	LC_ALL=C sed -n "s/^LANE $1 //p" "$rigTmp/log" | LC_ALL=C sed -n 1p
}
rigField(){ ## word prefix, that line -- the value of the space separated word that starts with the prefix
	printf '%s\n' "$2" | LC_ALL=C tr ' ' '\n' | LC_ALL=C sed -n "s/^$1//p" | LC_ALL=C sed -n 1p
}
rigPassesOf(){ ## session -- how many checks of its run passed, by its own output
	LC_ALL=C grep -c '^PASS  RigTiny' "$rigTmp/$1.out" 2> /dev/null || :
}
rigBegins(){ ## -- how many of its checks have begun in all, by the shared log
	LC_ALL=C grep -c -x 'BEGIN a' "$rigTmp/log" 2> /dev/null || :
}
rigEnds(){ ## -- how many of its checks have ended in all, by the shared log
	LC_ALL=C grep -c -x 'END a' "$rigTmp/log" 2> /dev/null || :
}
rigLockHolder(){ ## -- the runner pid lane 1's record names now, or nothing
	LC_ALL=C sed -n 's/^runner-pid: //p' "$rigLock/holder.txt" 2> /dev/null | LC_ALL=C sed -n 1p
}
rigLockSession(){ ## -- the session lane 1's record names now, or nothing
	LC_ALL=C sed -n 's/^session=//p' "$rigLock/holder.txt" 2> /dev/null | LC_ALL=C sed -n 1p
}
rigLaneField(){ ## lane number, word prefix -- that numbered lane's record's value for the prefix, or nothing
	LC_ALL=C sed -n "s/^$2//p" "$rigLanes/lane.$1/pid" 2> /dev/null | LC_ALL=C sed -n 1p
}
rigFolderShape(){ ## folder -- how many lines its tests.list has, then how many receipts it holds
	printf '%s %s\n' "$( LC_ALL=C grep -c . "$1/tests.list" 2> /dev/null || : )" "$( ls "$1" 2> /dev/null | LC_ALL=C grep -c '\.receipt$' || : )"
}

echo "-- 1. lane 1, its holder alive and its work finished: the lane comes back, and the holder is named --"
rigFresh 1
rigRunFolder "$rigTmp/run-1" 2 2
rigAssert "the fixture stands: the run folder given to the lock has as many receipts as its list has lines" "$( rigFolderShape "$rigTmp/run-1" )" "2 2"
rigLiveHolder ; rigHolderFinished="$rigHolderPid"
rigHandLock "$rigHolderFinished" rig-finished-1 "$rigTmp/run-1"
rigRun a --wait -w 1 -t 60 RigTiny ; rigEnd "$rigLast"
rigAssert "the run behind took lane 1 and ran its one check: rc 0, its check passed and ended once" "$rigRc $( rigPassesOf a ) $( rigEnds )" "0 1 1"
rigFoundOne="$( rigFound a )"
rigAssert "while its check ran, lane 1 was the run's own: another runner than the finished holder, and its own session" "$( [ -n "$( rigField 'lock-pid=' "$rigFoundOne" )" ] && [ "$( rigField 'lock-pid=' "$rigFoundOne" )" != "$rigHolderFinished" ] && printf another-runner || printf the-finished-holder ) $( rigField 'lock-session=' "$rigFoundOne" )" "another-runner rig-session-a"
rigAssert "it names the holder it freed, in one line" "$( rigFreed rig-finished-1 "$rigHolderFinished" )" 1

echo "-- 2. control: the same lock one receipt short is kept, and the run behind is refused at its own bound --"
rigFresh 1
rigRunFolder "$rigTmp/run-2" 2 1
rigLiveHolder ; rigHolderShort="$rigHolderPid"
rigHandLock "$rigHolderShort" rig-unfinished-2 "$rigTmp/run-2"
rigRun a --wait -w 1 -t 60 RigTiny ; rigEnd "$rigLast"
rigAssert "the run behind was refused at its own bound: rc 1, and one line says its turn had not come" "$rigRc $( rigSaid a 'not started: its turn in the machine' ) $( rigSaid a "had not come within ${rigBound}s" )" "1 1 1"
rigAssert "its check never began" "$( rigBegins ) $( rigPassesOf a )" "0 0"
rigAssert "and lane 1 still names its holder: the lane was not given back" "$( rigLockHolder )" "$rigHolderShort"

echo "-- 3. control: a lock whose holder process is gone is given back, as it is today --"
rigFresh 1
rigRunFolder "$rigTmp/run-3" 2 0
rigHandLock "$( rigDeadPid )" rig-dead-3 "$rigTmp/run-3"
rigRun a --wait -w 1 -t 60 RigTiny ; rigEnd "$rigLast"
rigAssert "the lane came back to the run behind: rc 0, and its check passed and ended once" "$rigRc $( rigPassesOf a ) $( rigEnds )" "0 1 1"

echo "-- 4. a numbered lane whose live holder's work is finished is given back, and one receipt short is kept --"
rigFresh 3
rigRunFolder "$rigTmp/run-4" 2 2
rigRunFolder "$rigTmp/run-4b" 2 1
rigLiveHolder ; rigHolderLane1="$rigHolderPid"
rigLiveHolder ; rigHolderLane2="$rigHolderPid"
rigLiveHolder ; rigHolderLane3="$rigHolderPid"
rigHandLock "$rigHolderLane1" rig-unfinished-1 "$rigTmp/run-4b"
rigLaneRecord 2 "$rigHolderLane2" rig-finished-2 "$rigTmp/run-4"
rigLaneRecord 3 "$rigHolderLane3" rig-unfinished-3 "$rigTmp/run-4b"
rigRun a --wait -w 1 -t 60 RigTiny ; rigEnd "$rigLast"
rigAssert "the run behind took lane 2 and ran its one check: rc 0, its check passed and ended once" "$rigRc $( rigPassesOf a ) $( rigEnds )" "0 1 1"
rigFoundFour="$( rigFound a )"
rigAssert "while its check ran, lane 2 was the run's own: another runner than the finished holder, and its own session" "$( [ -n "$( rigField 'lane2-pid=' "$rigFoundFour" )" ] && [ "$( rigField 'lane2-pid=' "$rigFoundFour" )" != "$rigHolderLane2" ] && printf another-runner || printf the-finished-holder ) $( rigField 'lane2-session=' "$rigFoundFour" )" "another-runner rig-session-a"
rigAssert "lane 3's holder, one receipt short, kept its lane" "$( rigLaneField 3 'session=' ) $( rigLaneField 3 'pid=' )" "rig-unfinished-3 $rigHolderLane3"
rigAssert "and lane 1's, also one short, kept its own" "$( rigLockSession ) $( rigLockHolder )" "rig-unfinished-1 $rigHolderLane1"
rigAssert "it names the holder it freed, in one line" "$( rigFreed rig-finished-2 "$rigHolderLane2" )" 1

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS LANE RELEASE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_LANE_RELEASE: OK (%d assertions, offline, rig machine only)\n' "$rigPasses"
