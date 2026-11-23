#!/usr/bin/env bash
## Behavioural check on a run that outlives its own bound (sh-test/AgentsRunTests.sh, A RUN GIVES ITS LANES UP, and the stall
## watch's keeper). The fault, measured 2026-11-20: a runner held every lane on the machine for 21 h 50 m, all its checks
## receipted and none of them running, because the loop that takes its lanes back had no bound and its own touch of
## tests.list kept the stall watch quiet. Run, not read, on a fixture machine of its own with one lane. Held:
##  1. A run whose one lane the run behind it takes, once it has given that lane up, goes on with the lanes it has when its
##     own bound passes, runs its next check, and ends by itself. It says how long it waited and with how many lanes.
##  2. The keeper leaves tests.list and runner.log out of its measure: a touch of either file alone changes nothing the
##     keeper reports.
##  3. The keeper counts the checks of the run folder that have started and have no receipt yet.
##  4. The stall watch's window outwaits a legitimate yield: a run whose timeout plus margin is under the yield's whole
##     budget is not ended as stalled while its retake waits its bound, since no file of its folder changes meanwhile.
## Red before the change: the retake loop waits for ever, so the run never hands out its next check and never ends, a
## touch of tests.list or runner.log alone moves the keeper's line, and a window of the timeout plus the margin covers
## only part of a yield. The run's own bound is 120 s, so the red run of this check waits out that bound; the rig's own
## bound is past it, and the run's time limit is far past both.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigRunner="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
rigKeeper="$( dirname "$rigRunner" )/check-fixtures/runner-stall-keeper.py"
[ -f "$rigKeeper" ] || rigRefuse "the stall watch's keeper is missing from the package: $rigKeeper"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its checks with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsYieldBoundCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## Only what this shell started and knows to be running still is ever signalled, with what is under it, read at that moment.
rigUnder(){ ## pid -- every process under it now, one on a line
	ps -A -o pid= -o ppid= 2> /dev/null | LC_ALL=C awk -v root="$1" '{ ppid[ $1 ] = $2 ; } END { for ( pid in ppid ) { top = pid ; hops = 0 ; while ( ( top in ppid ) && top != root && hops++ < 64 ) top = ppid[ top ] ; if ( top == root && pid != root ) print pid ; } ; }'
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
rigQueue="$rigHome/.agents/magic-team/suite-queue"
mkdir -p "$rigHome/.agents/magic-team/suite-lanes" "$rigHome/.agents/magic-team/suite-workers" "$rigWs/.local/temp"
## This rig's machine: one lane, two worker slots, both set by hand, so nothing of it waits on the pace of a real machine.
printf '1\n' > "$rigHome/.agents/magic-team/suite-lanes/count"
printf '2\n' > "$rigHome/.agents/magic-team/suite-workers/budget"
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
rigPackage(){ ## session, how many checks -- that copy: the runner under test, its keepers, and its tiny checks RigTiny1..n, each of which says in the shared log when it begins and ends, as <session>.<n>; held (RIG_HOLD), it ends only once the rig lets it (rigLet)
	local packageTests packageIndex ; packageTests="$( rigRoot "$1" )/myx/myx.distro-agents/sh-test"
	mkdir -p "$packageTests/check-fixtures" || rigRefuse "the copy could not be made: $1"
	cp "$rigRunner" "$packageTests/AgentsRunTests.sh" && cp "$( dirname "$rigRunner" )/check-fixtures"/runner-*.py "$packageTests/check-fixtures"/ || rigRefuse "the runner's keepers could not be copied: $1"
	mkdir -p "$packageTests/runner" && cp "$( dirname "$rigRunner" )"/runner/*.sh "$packageTests/runner"/ || rigRefuse "the runner's parts could not be copied: $1"
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
rigPackage a 2 ; rigPackage b 1

rigRun(){ ## session, runner args... -- that session's runner, started in the background from its own copy, every check of it held; its output in <session>.out, its status in <session>.rc once it has ended
	rm -f "$rigTmp/$1.rc"
	{
		( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$( rigRoot "$1" )" MYXROOT="${MYXROOT:-}" RIG_SHARED="$rigTmp" RIG_SUITE="$1" RIG_HOLD=1 \
			MDAT_SPAWN_SESSION_ID="rig-session-$1" \
			bash "$( rigRoot "$1" )/myx/myx.distro-agents/sh-test/AgentsRunTests.sh" "${@:2}" ) > "$rigTmp/$1.out" 2>&1
		printf '%s\n' "$?" > "$rigTmp/$1.rc"
	} &
	rigLast=$!
	rigProcNote "$rigLast"
}
rigEnd(){ ## job, session, seconds -- waits for that runner to end by itself, its status in rigRc; one that has not ended by then is ended by the rig, with what is under it, and rigRc says so
	local endLeft=$(( $3 * 5 ))
	while [ ! -s "$rigTmp/$2.rc" ] && [ "$endLeft" -gt 0 ] ; do sleep 0.2 ; endLeft=$(( endLeft - 1 )) ; done
	if [ -s "$rigTmp/$2.rc" ] ; then wait "$1" 2> /dev/null ; rigRc="$( cat "$rigTmp/$2.rc" )" ; return 0 ; fi
	rigStop "$1" ; rigRc="never-ended"
}
rigLet(){ ## <session>.<n> -- lets that held check end
	: > "$rigTmp/let.$1"
}
rigUntilIn(){ ## number, fixed text, file, seconds, session or nothing -- waits until the file holds that many lines with the text; rc 1 when it never does, or when that session's runner has ended without it
	local untilLeft=$(( $4 * 5 ))
	while [ "$( LC_ALL=C grep -c -F -- "$2" "$3" 2> /dev/null || : )" -lt "$1" ] ; do
		[ "$untilLeft" -gt 0 ] || return 1
		[ -z "${5:-}" ] || [ ! -s "$rigTmp/$5.rc" ] || return 1
		sleep 0.2 ; untilLeft=$(( untilLeft - 1 ))
	done
}
rigSaid(){ ## session, fixed text -- how many lines of its output hold the text
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" 2> /dev/null || :
}
rigTickets(){ ## -- how many places stand in this rig's line
	local ticketCount=0 ticketEach
	for ticketEach in "$rigQueue"/*.ticket ; do [ -f "$ticketEach" ] && ticketCount=$(( ticketCount + 1 )) ; done
	printf '%s\n' "$ticketCount"
}

echo "-- 1. a run whose lane the run behind takes goes on at its own bound, and ends --"
rigRun a -w 1 --wait -t 300 RigTiny ; rigJobA=$rigLast
rigUntilIn 1 'BEGIN a.1' "$rigTmp/log" 120 a || rigRefuse "the first check of the run never began, so nothing below would be measured"
## The run behind joins the line while the one ahead holds the only lane of the machine, and holds that lane while its
## own check is held, so nothing gives the lane back to the run ahead.
rigRun b -w 1 --wait -t 900 RigTiny ; rigJobB=$rigLast
rigLineLeft=600
while [ "$( rigTickets )" -lt 2 ] && [ "$rigLineLeft" -gt 0 ] && [ ! -s "$rigTmp/a.rc" ] && [ ! -s "$rigTmp/b.rc" ] ; do sleep 0.2 ; rigLineLeft=$(( rigLineLeft - 1 )) ; done
[ "$( rigTickets )" -ge 2 ] || rigRefuse "the run behind never joined the machine's line, so nothing below would be measured"
## The check ahead ends, so its runner comes to the boundary where it gives its lane up, and the run behind takes it.
rigLet a.1
rigUntilIn 1 'BEGIN b.1' "$rigTmp/log" 120 a || :
rigAssert "the run ahead gave its one lane up, and the run behind took it and began its check" "$( LC_ALL=C grep -c -x 'BEGIN b\.1' "$rigTmp/log" || : )" 1
## Its bound is 120 s, and the lane stays with the run behind for as long as its check is held. A run that goes on at that
## bound hands out its next check; a run that waits for the lane never does.
rigUntilIn 1 'BEGIN a.2' "$rigTmp/log" 200 a || :
rigAssert "the run ahead handed its next check out although the lane never came back, so the retake waited no longer than its bound" "$( LC_ALL=C grep -c -x 'BEGIN a\.2' "$rigTmp/log" || : )" 1
rigAssert "it says how long it waited for its lane, and with how many it went on" "$( rigSaid a 'waited 120s for its lane(s) to come free and goes on with 0 of 1' )" 1
rigLet a.2
rigEnd "$rigJobA" a 60
rigAssert "and it ended by itself: rc 0" "$rigRc" 0
rigAssert "its summary counts both checks, and nothing of it is said to have stood still" "$( LC_ALL=C tail -n 1 "$( LC_ALL=C sed -n 's/^# AgentsRunTests\.sh: .* run folder: //p' "$rigTmp/a.out" | LC_ALL=C sed -n 1p )/summary.txt" 2> /dev/null | LC_ALL=C sed 's/  WALL .*//' ) $( rigSaid a 'stood still' )" "TOTAL 2  PASS 2  FAIL 0 0"
rigLet b.1 ; rigEnd "$rigJobB" b 120
rigAssert "the run behind ran its one check and ended too: rc 0" "$rigRc" 0
rigAssert "nothing of either run is left in the machine's line" "$( rigTickets )" 0

echo "-- 2. the keeper leaves tests.list out of its measure --"
rigKeeperDir="$rigTmp/keeper" ; mkdir -p "$rigKeeperDir"
printf 'rc=0\n' > "$rigKeeperDir/RigTiny1.receipt"
: > "$rigKeeperDir/RigTiny1.log"
: > "$rigKeeperDir/RigTiny1.begin"
: > "$rigKeeperDir/RigTiny2.log"
## A detached run writes its own stderr into the run folder's runner.log, so that file alone moves while nothing of the run does.
: > "$rigKeeperDir/runner.log"
printf 'RigTiny1 5\nRigTiny2 5\n' > "$rigKeeperDir/tests.list"
## Every entry of that folder at one old moment, so a touch of one file alone is the only thing that can move the keeper's line.
find "$rigKeeperDir" -mindepth 1 -maxdepth 1 -exec touch -t 202001010000 {} +
rigKeeperLine="$( python3 -I -B "$rigKeeper" "$rigKeeperDir" 2> /dev/null )"
touch "$rigKeeperDir/tests.list"
rigAssert "a touch of tests.list alone, with nothing else changed, leaves the keeper's line as it was" "$( python3 -I -B "$rigKeeper" "$rigKeeperDir" 2> /dev/null )" "$rigKeeperLine"
rigAssert "the keeper counts the one receipt, the check that started with it, and the check that started and has none" "$( printf '%s\n' "$rigKeeperLine" | LC_ALL=C awk '{ print $3, $4 ; }' )" "1 1"
touch "$rigKeeperDir/runner.log"
rigAssert "a touch of runner.log alone, with nothing else changed, leaves the keeper's line as it was" "$( python3 -I -B "$rigKeeper" "$rigKeeperDir" 2> /dev/null )" "$rigKeeperLine"
rigAssert "the keeper does not count runner.log as a check that started and has no receipt" "$( printf '%s\n' "$rigKeeperLine" | LC_ALL=C awk '{ print $4 ; }' )" 1
printf 'rc=1\n' > "$rigKeeperDir/RigTiny2.receipt"
rigAssert "once that check has a receipt, no check of the folder is counted as started and unfinished" "$( python3 -I -B "$rigKeeper" "$rigKeeperDir" 2> /dev/null | LC_ALL=C awk '{ print $3, $4 ; }' )" "2 0"
rigAssert "a folder that cannot be read is a failure of the keeper, never an empty line" "$( python3 -I -B "$rigKeeper" "$rigTmp/no-such-folder" > /dev/null 2>&1 ; printf '%s' "$?" ) $( python3 -I -B "$rigKeeper" "$rigTmp/no-such-folder" 2> /dev/null | LC_ALL=C grep -c . || : )" "1 0"

echo "-- 3. the stall watch's window outwaits a legitimate yield --"
## c runs with a short timeout and margin, so its watch's window is 70 s while its retake waits its whole 120 s bound. Its run
## folder does not change while the retake waits, since tests.list is out of the keeper's measure: a window that does not outwait
## the yield ends a legitimate yield as a stall, and c never says it waited.
rigPackage c 2 ; rigPackage d 1
rigRun c -w 1 --wait -t 60 --stall-margin 10 RigTiny ; rigJobC=$rigLast
rigUntilIn 1 'BEGIN c.1' "$rigTmp/log" 120 c || rigRefuse "the first check of the short-timeout run never began, so nothing below would be measured"
rigRun d -w 1 --wait -t 900 RigTiny ; rigJobD=$rigLast
rigLineLeft=600
while [ "$( rigTickets )" -lt 2 ] && [ "$rigLineLeft" -gt 0 ] && [ ! -s "$rigTmp/c.rc" ] && [ ! -s "$rigTmp/d.rc" ] ; do sleep 0.2 ; rigLineLeft=$(( rigLineLeft - 1 )) ; done
[ "$( rigTickets )" -ge 2 ] || rigRefuse "the run behind never joined the machine's line, so nothing below would be measured"
rigLet c.1
rigUntilIn 1 'BEGIN d.1' "$rigTmp/log" 120 c || rigRefuse "no yield happened, so nothing below would be measured"
rigLet c.2
rigEnd "$rigJobC" c 300
rigAssert "the short-timeout run was not ended as stalled while its yield waited its bound" "$( rigSaid c 'stood still' )" 0
rigAssert "it waited its lane bound and went on, so the watch outwaited the whole yield" "$( rigSaid c 'waited 120s for its lane(s) to come free' )" 1
rigAssert "and it ended by itself: rc 0" "$rigRc" 0
rigLet d.1 ; rigEnd "$rigJobD" d 120

echo "-- 4. a lane held by a live run is not given back --"
## The runner is split: AgentsRunTests.sh execs the part, so a live run's command line names runner/AgentsRunExecute.sh. A lane read that
## matches only the entry reads that live holder as gone, gives its lane back, and the run behind takes it while the run ahead is at work.
rigPackage e 2 ; rigPackage f 1
rigRun e -w 1 --wait -t 300 RigTiny ; rigJobE=$rigLast
rigUntilIn 1 'BEGIN e.1' "$rigTmp/log" 120 e || rigRefuse "the run holding the only lane never began its first check, so nothing below would be measured"
rigRun f -w 1 --wait -t 900 RigTiny ; rigJobF=$rigLast
rigLineLeft=600
while [ "$( rigTickets )" -lt 2 ] && [ "$rigLineLeft" -gt 0 ] && [ ! -s "$rigTmp/e.rc" ] && [ ! -s "$rigTmp/f.rc" ] ; do sleep 0.2 ; rigLineLeft=$(( rigLineLeft - 1 )) ; done
[ "$( rigTickets )" -ge 2 ] || rigRefuse "the run behind never joined the machine's line, so nothing below would be measured"
rigSettled=0
while [ "$rigSettled" -lt 100 ] && [ ! -s "$rigTmp/f.rc" ] ; do sleep 0.2 ; rigSettled=$(( rigSettled + 1 )) ; done
rigAssert "the lane stayed with the live run ahead, so the run behind began no check of its own" "$( LC_ALL=C grep -c -x 'BEGIN f\.1' "$rigTmp/log" || : )" 0
rigLet e.1
rigUntilIn 1 'BEGIN f.1' "$rigTmp/log" 200 e || :
rigAssert "and once that run gave its lane up, the run behind took it and began its check" "$( LC_ALL=C grep -c -x 'BEGIN f\.1' "$rigTmp/log" || : )" 1
rigLet e.2 ; rigLet f.1
rigEnd "$rigJobE" e 300 ; rigEnd "$rigJobF" f 300

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS YIELD BOUND CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_YIELD_BOUND: OK (%d assertions, offline, rig machine only)\n' "$rigPasses"
