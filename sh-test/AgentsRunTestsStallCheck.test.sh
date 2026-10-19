#!/usr/bin/env bash
## Behavioural check on a run of the test runner that stands still (sh-test/AgentsRunTests.sh), run rather than read,
## on a fixture machine built here: a HOME, whose .agents/magic-team/suite-workers is the machine's one budget of test
## workers, a workspace, and under its .local/temp several copies of a package, each with the runner under test and
## some tiny tests, which say in a shared log when they begin and end and end only once the rig lets them. Held:
##  1. The driver's helper lost. myx.common lib/parallel is told that a job has ended by a background loop of its own
##     (`while dd bs=256 count=1 <&3 ...`), which one failed read ends for good; a driver without it, once as many jobs
##     run as it has workers, waits for ever. The live fault this pins, 2026-10-13: 192 named tests, 56 run, then more
##     than an hour with no test running and nothing said. Here that read fails from the first, by a dd first on the
##     runner's PATH. The run still runs every test, in the order of its list, never more at once than its workers,
##     and ends by itself: the runner hands the driver its workers and never the tests, so the driver has no job to
##     be told of.
##  2. A run that stands still is ended, and says so: with a worker of it stopped, so that no test of it is running
##     and none will start, it is ended once nothing of it has changed for longer than a test may take and the
##     margin, with status 124, naming the tests that never ran and the one that started and never ended, in its
##     output, its summary and the note in its run folder; and nothing of it is left running. A run that only takes
##     longer than that, one test after another, is not ended, and neither is one whose tests have no time limit.
##  3. A test that waits for a worker slot is not a run that stands still, however long it waits: its runner says
##     once a minute that it waits, and that is seen.
## Nothing here is told by how long a run takes: every wait of the rig is for something the run writes, with a bound
## past which the rig ends the run itself and says it never ended. What the rig cannot show: who ended the helper of
## the live run.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigRunner="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its tests with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
rigRealDd="$( command -v dd )" || rigRefuse "no dd on PATH to hand the other calls to"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsStallCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## Only what this shell started and knows to be running still is ever signalled, with what is under it, read at
## that moment: a pid kept from earlier may be another process's by now.
rigUnder(){ ## pid -- every process under it now, one on a line
	ps -A -o pid= -o ppid= 2> /dev/null | LC_ALL=C awk -v root="$1" '{ ppid[ $1 ] = $2 } END { for ( pid in ppid ) { top = pid ; hops = 0 ; while ( ( top in ppid ) && top != root && hops++ < 64 ) top = ppid[ top ] ; if ( top == root && pid != root ) print pid } }'
}
rigStop(){ ## pid of a background job of this shell that is running -- it and everything under it ended at once, a stopped process too
	kill -KILL "$1" $( rigUnder "$1" ) 2> /dev/null ; wait "$1" 2> /dev/null
}
rigStopAll(){
	local stopJob
	for stopJob in $( jobs -pr ) ; do rigStop "$stopJob" ; done
}
trap 'rigStopAll ; rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home" ; rigWs="$rigTmp/ws"
rigWorkers="$rigHome/.agents/magic-team/suite-workers"
mkdir -p "$rigHome" "$rigWs/.local/temp" "$rigTmp/tmp" "$rigTmp/bin"
: > "$rigTmp/log"

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
rigPackage(){ ## session, how many tests -- that copy: the runner under test, and its tiny tests RigTiny1..n, each of which says in the shared log when it begins and ends, as <session>.<n>; held (RIG_HOLD), it ends only once the rig lets it (rigLet)
	local packageTests packageIndex ; packageTests="$( rigRoot "$1" )/myx/myx.distro-agents/sh-test"
	mkdir -p "$packageTests"
	cp "$rigRunner" "$packageTests/AgentsRunTests.sh"
	cat > "$packageTests/RigTiny.test.sh" <<'RIGTINY'
#!/usr/bin/env bash
rigTinyId="${0##*/RigTiny}" ; rigTinyId="${rigTinyId%.test.sh}"
RIG_SUITE="$RIG_SUITE.$rigTinyId"
printf 'BEGIN %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
rigHeldFor=3000
while [ -n "${RIG_HOLD:-}" ] && [ ! -e "$RIG_SHARED/let.$RIG_SUITE" ] && [ "$rigHeldFor" -gt 0 ] ; do sleep 0.2 ; rigHeldFor=$(( rigHeldFor - 1 )) ; done
printf 'END %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
echo "RIG_TINY: OK"
RIGTINY
	for (( packageIndex = 1 ; packageIndex <= $2 ; packageIndex++ )) ; do cp "$packageTests/RigTiny.test.sh" "$packageTests/RigTiny$packageIndex.test.sh" ; done
	rm -f "$packageTests/RigTiny.test.sh"
}
rigPackage a 5 ; rigPackage b 3 ; rigPackage c 3 ; rigPackage n 1
## The dd that loses the driver its helper: the helper's one read fails, every other call is the real dd's.
ln -s "$rigRealDd" "$rigTmp/bin/dd.real" || rigRefuse "the rig could not keep the real dd"
cat > "$rigTmp/bin/dd" <<'RIGDD'
#!/bin/sh
case " $* " in *" bs=256 "*) exit 1 ;; esac
exec "${0%/*}/dd.real" "$@"
RIGDD
chmod +x "$rigTmp/bin/dd"

rigHold="" rigPath="$PATH"
rigRun(){ ## session, runner args... -- that session's runner, started in the background from its own copy; its output in <session>.out, and its status in <session>.rc once it has ended. With rigHold set, a test of it ends only at rigLet <session>.<n>
	rm -f "$rigTmp/$1.rc"
	{
		( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$( rigRoot "$1" )" MYXROOT="${MYXROOT:-}" RIG_SHARED="$rigTmp" RIG_SUITE="$1" RIG_HOLD="$rigHold" \
			bash "$( rigRoot "$1" )/myx/myx.distro-agents/sh-test/AgentsRunTests.sh" "${@:2}" ) > "$rigTmp/$1.out" 2>&1
		printf '%s\n' "$?" > "$rigTmp/$1.rc"
	} &
	rigLast=$!
}
rigEnd(){ ## job, session, seconds -- waits for that runner to end by itself, its status in rigRc; one that has not ended by then is ended by the rig, with what is under it, and rigRc says so
	local endLeft=$(( $3 * 5 ))
	while [ ! -s "$rigTmp/$2.rc" ] && [ "$endLeft" -gt 0 ] ; do sleep 0.2 ; endLeft=$(( endLeft - 1 )) ; done
	if [ -s "$rigTmp/$2.rc" ] ; then wait "$1" 2> /dev/null ; rigRc="$( cat "$rigTmp/$2.rc" )" ; return 0 ; fi
	rigStop "$1" ; rigRc="never-ended"
}
rigLet(){ ## <session>.<n> -- lets that held test end
	: > "$rigTmp/let.$1"
}
rigUntil(){ ## fixed text, file, seconds, session or nothing -- waits for a line of the file to hold the text; rc 1 when it never does, or when that session's runner has ended without it
	local untilLeft=$(( $3 * 5 ))
	while ! LC_ALL=C grep -q -F -- "$1" "$2" 2> /dev/null ; do
		[ "$untilLeft" -gt 0 ] || return 1
		[ -z "${4:-}" ] || [ ! -s "$rigTmp/$4.rc" ] || return 1
		sleep 0.2 ; untilLeft=$(( untilLeft - 1 ))
	done
}
rigCount(){ ## BEGIN or END -- how many tests the shared log says have
	LC_ALL=C grep -c "^$1 " "$rigTmp/log" || :
}
rigUntilCount(){ ## BEGIN or END, how many, seconds -- waits until that many tests have, in all; rc 1 when they never do
	local countLeft=$(( $3 * 5 ))
	while [ "$( rigCount "$1" )" -lt "$2" ] ; do
		[ "$countLeft" -gt 0 ] || return 1
		sleep 0.2 ; countLeft=$(( countLeft - 1 ))
	done
}
rigBegun(){ ## -- the tests that have begun and not ended, by the shared log, in the order they began, space separated
	LC_ALL=C awk '$1 == "BEGIN" { on[$2] = 1 ; order[++n] = $2 } $1 == "END" { delete on[$2] } END { for ( i = 1 ; i <= n ; i++ ) if ( order[i] in on ) printf "%s ", order[i] }' "$rigTmp/log"
}
rigMostAtOnce(){ ## -- the most tests that were running at one time, by the shared log
	LC_ALL=C awk '$1 == "BEGIN" { n++ ; if ( n > most ) most = n } $1 == "END" { n-- } END { print most + 0 }' "$rigTmp/log"
}
rigBegins(){ ## from, to -- the tests of those places in the order they began, on one line; sorted where told, for tests that begin at once
	LC_ALL=C sed -n 's/^BEGIN //p' "$rigTmp/log" | LC_ALL=C sed -n "$1,$2p" | { if [ "${3:-}" = sorted ] ; then LC_ALL=C sort ; else cat ; fi ; } | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigFolder(){ ## session -- the run folder its runner said
	LC_ALL=C sed -n 's/^# AgentsRunTests\.sh: .* run folder: //p' "$rigTmp/$1.out" | LC_ALL=C sed -n 1p
}
rigSaid(){ ## session, fixed text -- how many lines of its output hold the text
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" 2> /dev/null || :
}
rigFresh(){ ## -- no slot taken and no budget set, an empty log, nothing held or let go, the real dd
	rm -rf "$rigWorkers" ; : > "$rigTmp/log" ; rm -f "$rigTmp"/*.out "$rigTmp"/*.rc "$rigTmp"/let.* ; rigHold="" ; rigPath="$PATH"
}

echo "-- 1. the driver's helper lost: the run still runs every test, and ends by itself --"
rigFresh ; rigHold=1 ; rigPath="$rigTmp/bin:$PATH"
rigRun a -w 2 RigTiny ; rigJobA=$rigLast
rigUntilCount BEGIN 2 120 || rigRefuse "two tests never began on two workers, so nothing below would be measured"
sleep 2
rigAssert "two workers, five tests, all held: two have begun, the first two of the list, and no third beside them" "$( rigCount BEGIN ) [$( rigBegins 1 2 sorted )]" "2 [a.1 a.2]"
## each test let go in turn, the one that began first, and the next one waited for
rigEnded=0
while [ "$rigEnded" -lt 5 ] ; do
	rigNext="$( rigBegun )" ; rigNext="${rigNext%% *}"
	[ -n "$rigNext" ] || break
	rigLet "$rigNext" ; rigEnded=$(( rigEnded + 1 ))
	rigUntilCount END "$rigEnded" 60 || break
	[ "$rigEnded" -gt 3 ] || rigUntilCount BEGIN $(( rigEnded + 2 )) 30 || break
done
rigEnd "$rigJobA" a 60
rigAssert "every test of the run ran, and the run ended by itself: rc 0, five begun, five ended, five passed" "$rigRc $( rigCount BEGIN ) $( rigCount END ) $( LC_ALL=C grep -c '^PASS  RigTiny' "$rigTmp/a.out" || : )" "0 5 5 5"
rigAssert "the tests after the first two began in the order of the list, each as a worker came free" "$( rigBegins 3 5 )" "a.3 a.4 a.5"
rigAssert "and at no time were more running than the run has workers" "$( rigMostAtOnce )" 2
rigAssert "its summary counts them all, and nothing is said of standing still" "$( LC_ALL=C tail -n 1 "$( rigFolder a )/summary.txt" 2> /dev/null | LC_ALL=C sed 's/  WALL .*//' ) $( rigSaid a 'stood still' ) $( [ -e "$( rigFolder a )/stalled.txt" ] && printf note || printf no-note )" "TOTAL 5  PASS 5  FAIL 0 0 no-note"

echo "-- 2. a run that stands still is ended, and says so --"
## One worker, three tests. The worker is stopped while its first test runs, then that test is let go: it ends, the
## worker never sees it, and nothing of the run can go on.
rigFresh ; rigHold=1
rigRun b -w 1 -t 12 --stall-margin 2 RigTiny ; rigJobB=$rigLast
rigUntil 'BEGIN b.1' "$rigTmp/log" 120 b || rigRefuse "the first test never began, so there is no run to stop"
rigTestPid="$( LC_ALL=C sed -n 's/^H //p' "$rigWorkers/state" 2> /dev/null | LC_ALL=C sed -n 1p )"
rigWorkerPid="$( ps -o ppid= -p "${rigTestPid:-0}" 2> /dev/null | LC_ALL=C tr -d ' ' )"
[ -n "$rigWorkerPid" ] || rigRefuse "the rig did not find the runner's own process that waits for the running test, so it can stop nothing"
rigWorkerStart="$( ps -o lstart= -p "$rigWorkerPid" 2> /dev/null )"
kill -STOP "$rigWorkerPid" 2> /dev/null || rigRefuse "the rig could not stop the worker"
rigLet b.1
rigUntil 'END b.1' "$rigTmp/log" 30 || :
rigEnd "$rigJobB" b 120
rigFolderB="$( rigFolder b )"
rigAssert "the run is ended as stalled: status 124" "$rigRc" 124
rigAssert "it says so in one line, with how long a test may take and the margin it was given" "$( rigSaid b '⛔ ERROR: AgentsRunTests.sh: this run stood still and was ended as stalled: nothing of it started, ended or wrote a line for ' ) $( rigSaid b 's, longer than a test may take (12s) and 2s more, so no test of it was running and none waited for a worker slot.' )" "1 1"
rigAssert "the line names the tests that never ran, and the one that started and never ended" "$( rigSaid b ' Never ran, 2 of 3 test(s): RigTiny2 RigTiny3. Started and never ended, 1: RigTiny1. What did end is in ' )" 1
rigAssert "the summary holds the same: no result for any of the three, and the count of each kind" "$( LC_ALL=C grep -c '^FAIL RigTiny[123] rc=none$' "$rigFolderB/summary.txt" 2> /dev/null || : ) $( LC_ALL=C grep -c -x 'STALLED  never ran 2  never ended 1' "$rigFolderB/summary.txt" 2> /dev/null || : ) $( LC_ALL=C tail -n 1 "$rigFolderB/summary.txt" 2> /dev/null | LC_ALL=C sed 's/  WALL .*//' )" "3 1 TOTAL 3  PASS 0  FAIL 3"
rigAssert "the note in the run folder names them too" "$( LC_ALL=C grep -e '^never-ran=' -e '^never-ended=' "$rigFolderB/stalled.txt" 2> /dev/null | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "never-ran=RigTiny2 RigTiny3 never-ended=RigTiny1"
rigAssert "it stood for longer than a test may take and the margin, and was not ended before" "$( LC_ALL=C awk -F= '$1 == "stood-still" { print ( $2 > 14 ) ? "longer" : "sooner: " $2 }' "$rigFolderB/stalled.txt" 2> /dev/null )" "longer"
rigAssert "nothing of the run is left: the worker that was stopped is gone" "$( [ -n "$rigWorkerStart" ] && [ "$( ps -o lstart= -p "$rigWorkerPid" 2> /dev/null )" = "$rigWorkerStart" ] && printf there || printf gone )" "gone"
## A run that only takes long: three tests one after another, each held five seconds, longer in all than a test may
## take and the margin, and at no time that long with nothing changing.
rigFresh ; rigHold=1
rigRun c -w 1 -t 12 --stall-margin 2 RigTiny ; rigJobC=$rigLast
for rigIndex in 1 2 3 ; do
	rigUntil "BEGIN c.$rigIndex" "$rigTmp/log" 60 || break
	sleep 5 ; rigLet "c.$rigIndex"
done
rigEnd "$rigJobC" c 60
rigAssert "a run that takes longer in all than a test may take and the margin, one test after another, is not ended: rc 0, three passed, nothing said of standing still, no note" "$rigRc $( LC_ALL=C grep -c '^PASS  RigTiny' "$rigTmp/c.out" || : ) $( rigSaid c 'stood still' ) $( [ -e "$( rigFolder c )/stalled.txt" ] && printf note || printf no-note )" "0 3 0 no-note"
## Tests with no time limit: there is no time by which one must have ended, so no margin makes its run stand still.
rigFresh ; rigHold=1
rigRun n -t 0 --stall-margin 1 RigTiny ; rigJobN=$rigLast
rigUntil 'BEGIN n.1' "$rigTmp/log" 60 n || :
sleep 6 ; rigLet n.1
rigEnd "$rigJobN" n 60
rigAssert "a run whose tests have no time limit is not ended, whatever the margin: rc 0, its test passed after six seconds with nothing changing, nothing said of standing still" "$rigRc $( LC_ALL=C grep -c '^PASS  RigTiny1 ' "$rigTmp/n.out" || : ) $( rigSaid n 'stood still' )" "0 1 0"

echo "-- 3. a test that waits for a worker slot is not a run that stands still --"
## A budget of one, its slot held by a process of the rig. The run's one test may take 3 seconds, the margin is 62:
## for 80 seconds nothing of the run starts or ends, and its runner says a second time, after a minute, that it waits.
rigFresh
mkdir -p "$rigWorkers" && printf '1\n' > "$rigWorkers/budget"
sleep 600 & rigHolder=$! ; rigProcNote "$rigHolder"
printf 'H %s\n' "$rigHolder" > "$rigWorkers/state"
rigRun n -t 3 --stall-margin 62 RigTiny ; rigJobN=$rigLast
rigUntil 'a test waits for a worker slot' "$rigTmp/n.out" 120 n || rigRefuse "with the one slot held, the test never said it waits"
sleep 80
rigAssert "after 80 seconds of waiting, longer than a test may take and the margin, the run still waits: nothing begun, not ended, and it has said twice that it waits" "[$( rigCount BEGIN )] $( [ -e "$rigTmp/n.rc" ] && printf ended || printf waiting ) $( rigSaid n 'a test waits for a worker slot' )" "[0] waiting 2"
rigProcSignal TERM "$rigHolder" ; wait "$rigHolder" 2> /dev/null
rigEnd "$rigJobN" n 120
rigAssert "and it runs once the slot is free: rc 0, its test passed, nothing said of standing still" "$rigRc $( LC_ALL=C grep -c '^PASS  RigTiny1 ' "$rigTmp/n.out" || : ) $( rigSaid n 'stood still' )" "0 1 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS STALL CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_STALL: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
