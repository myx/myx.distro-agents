#!/usr/bin/env bash
## Behavioural check on the line full suites stand in (sh-test/AgentsRunTests.sh), run rather than read, on a fixture
## machine built here: a HOME, whose .agents/magic-team/suite-queue is the machine's one line and whose
## .agents/magic-team/suite-lanes holds its lanes, a workspace, and under
## its .local/temp several copies of a package, each a build session's scratch with the runner under test and one tiny
## test in it. Held: a run of every test waits its turn in arrival order, whichever copy it is started from, and says
## in one line whom it waits behind; a run of named tests stands in the same line; a ticket whose runner no longer exists is taken
## out by whoever waits behind it; and the hand rule's lock ($MMDAPP/.local/temp/suite-run.lock) is kept by both sides:
## a run at its turn holds it, waits while another holds it by hand and never removes that one, starts under one held
## by its own caller only when its own turn has come and is refused before that, and removes one left by a runner that
## is gone. And the one budget of test workers, $HOME/.agents/magic-team/suite-workers, that every runner shares, full
## or named: the tests running at once on the machine never pass it, slots go in the order they were asked for, a slot whose process is gone comes back by itself, a runner says in one
## line that a test of its waits and how many slots are in use, and every test runs at a lowered priority. The hand
## rule the budget replaces ($MMDAPP/.local/temp/one-test-run.lock, an `owner` file naming a scratch folder) is honoured
## while a session still holds it: no test starts beside it, unless it is the run's own caller's. Nothing here is told by how
## long a run takes: a suite that must still be running when another is started runs until the rig lets it end, so the
## order of what happened is the rig's own, on a busy host as on an idle one. What the rig cannot show: nine real
## sessions at once, and a real suite's length.
##
## AND THE LANES: as many runs stand beside each other as the machine's lanes allow, in arrival order, and a test that
## measures its own timing takes every lane. The rig fixes the lane count and its pace floor itself, so nothing here
## waits on how busy this host is (section 9). Red before the lanes landed: three runs of one test each took turns one
## after another, and the second of two that could have stood together waited for the first.
##
## AND THE YIELD: a run gives its lane up between two of its checks to a run behind it, keeps its checks once and in order,
## and is named by a waiter with its checks done of all (section 10); a run of two workers yields once, after its checks in
## flight (10a); one worker yields twice and takes its one lane back each time (10b). A check started by hand judges a run at work by its
## lane, never by its beat, says the same of it, and passes a yielding run by (sections 11 and 12). A run that yielded waits for the
## run it yielded to only until that run holds a lane, so a lane that stands free is taken while that run still works (10f).
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigRunner="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its tests with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsQueueCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignal TERM $rigStarted ; rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home" ; rigWs="$rigTmp/ws"
rigQueue="$rigHome/.agents/magic-team/suite-queue"
rigWorkers="$rigHome/.agents/magic-team/suite-workers"
rigLanes="$rigHome/.agents/magic-team/suite-lanes"
rigLock="$rigWs/.local/temp/suite-run.lock"
rigTestLock="$rigWs/.local/temp/one-test-run.lock"
mkdir -p "$rigHome" "$rigWs/.local/temp"
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
rigRoot(){ ## session -- the source root of that session's copy of the package; `live` is the workspace's own tree, no scratch folder
	if [ "$1" = live ] ; then printf '%s\n' "$rigWs/source" ; else printf '%s\n' "$rigWs/.local/temp/rig-scratch-$1/source" ; fi
}
rigPackage(){ ## session, how many tests (default 1) -- that copy: the runner under test, and its tiny tests, each of which says in the shared log when it begins and ends, what it found the line and the lock holding while it ran, and its priority; held (RIG_HOLD), it ends only once the rig lets it (rigLet). One test is named by its session alone, each of several <session>.<n>
	local packageTests packageIndex ; packageTests="$( rigRoot "$1" )/myx/myx.distro-agents/sh-test"
	mkdir -p "$packageTests"
	cp "$rigRunner" "$packageTests/AgentsRunTests.sh"
	## THE RUNNER IS A ROUTER: its parts travel with it, or the rig copy finds none and runs nothing.
	mkdir -p "$packageTests/runner" && cp "$( dirname "$rigRunner" )"/runner/*.sh "$packageTests/runner"/ || rigRefuse "the runner parts could not be copied into the rig"
	mkdir -p "$packageTests/check-fixtures" && cp "$(dirname "$rigRunner")/check-fixtures"/runner-*.py "$packageTests/check-fixtures"/
	cat > "$packageTests/RigTiny.test.sh" <<'RIGTINY'
#!/usr/bin/env bash
rigTinyId="${0##*/RigTiny}" ; rigTinyId="${rigTinyId%.test.sh}"
RIG_SUITE="$RIG_SUITE${rigTinyId:+.$rigTinyId}"
printf 'BEGIN %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
printf 'NICE %s %s\n' "$RIG_SUITE" "$( ps -o nice= -p $$ 2> /dev/null | LC_ALL=C tr -d ' ' )" >> "$RIG_SHARED/log"
printf 'HELD %s lock=%s line=%s\n' "$RIG_SUITE" \
	"$( LC_ALL=C sed -n 's/^runner-pid: //p' "$MMDAPP/.local/temp/suite-run.lock/holder.txt" 2> /dev/null | LC_ALL=C sed -n 1p )" \
	"$( LC_ALL=C sed -n 's/^session=//p' "$HOME/.agents/magic-team/suite-queue"/*.ticket 2> /dev/null | LC_ALL=C tr '\n' ' ' )" >> "$RIG_SHARED/log"
rigHeldFor=600
while [ -n "${RIG_HOLD:-}" ] && [ ! -e "$RIG_SHARED/let.$RIG_SUITE" ] && [ "$rigHeldFor" -gt 0 ] ; do sleep 0.2 ; rigHeldFor=$(( rigHeldFor - 1 )) ; done
printf 'END %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
echo "RIG_TINY: OK"
RIGTINY
	[ "${2:-1}" = 1 ] && return 0
	for (( packageIndex = 1 ; packageIndex <= $2 ; packageIndex++ )) ; do cp "$packageTests/RigTiny.test.sh" "$packageTests/RigTiny$packageIndex.test.sh" ; done
	rm -f "$packageTests/RigTiny.test.sh"
}
for rigSession in a b c n ; do rigPackage "$rigSession" ; done
rigPackage p 3 ; rigPackage q 3 ; rigPackage live

rigHold=""
rigQueueLimit=""
rigHoldLimit=""
rigStallLimit=""
rigRun(){ ## session, runner args... -- that session's runner, started in the background from its own copy; its output in <session>.out. With rigHold set, its test ends only at rigLet <session>
	( cd "$rigWs" && exec env -i HOME="${rigHomeFor:-$rigHome}" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$( rigRoot "$1" )" MYXROOT="${MYXROOT:-}" RIG_SHARED="$rigTmp" RIG_SUITE="$1" RIG_HOLD="$rigHold" \
		MDAT_SUITE_QUEUE_LIMIT="${rigQueueLimit:-}" MDAT_SUITE_QUEUE_HOLD_SECONDS="${rigHoldLimit:-}" MDAT_SUITE_QUEUE_STALL_SECONDS="${rigStallLimit:-}" \
		MDAT_SPAWN_SESSION_ID="rig-session-$1" MDAT_SUITE_TIER="${rigTier:-}" \
		bash "$( rigRoot "$1" )/myx/myx.distro-agents/sh-test/AgentsRunTests.sh" --wait "${@:2}" ) > "$rigTmp/$1.out" 2>&1 &
	rigLast=$!
	rigStarted="$rigStarted $rigLast" ; rigProcNote "$rigLast"
}
rigEnd(){ ## pid -- waits for that runner, its rc in rigRc
	rigRc=0 ; wait "$1" 2> /dev/null || rigRc=$?
}
rigLet(){ ## session -- lets that session's held test end
	: > "$rigTmp/let.$1"
}
rigUntil(){ ## fixed text, file -- waits for a line of the file to hold the text, however long a busy host takes, up to four minutes; rc 1 when it never does
	local untilLeft=1200
	while ! LC_ALL=C grep -q -F -- "$1" "$2" 2> /dev/null ; do
		[ "$untilLeft" -gt 0 ] || return 1
		sleep 0.2 ; untilLeft=$(( untilLeft - 1 ))
	done
}
rigWaits(){ ## session -- how many lines of its output say it waits its turn
	LC_ALL=C grep -c -F -- 'waits its turn behind' "$rigTmp/$1.out" 2> /dev/null || :
}
rigTickets(){ ## -- how many tickets stand in the line
	ls "$rigQueue" 2> /dev/null | LC_ALL=C grep -c '\.ticket$' || :
}
rigOrder(){ ## -- the shared log's begins and ends, in the order they were written, on one line
	LC_ALL=C grep -e '^BEGIN ' -e '^END ' "$rigTmp/log" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigHeld(){ ## session -- what its test found while it ran: the lock's runner, then the sessions standing in the line
	LC_ALL=C sed -n "s/^HELD $1 //p" "$rigTmp/log" | LC_ALL=C sed -n 1p
}
rigHeldOwn(){ ## session -- `own` where that run held a lane itself and stood first in the line, else what it found
	local ownHeld ; ownHeld="$( rigHeld "$1" )"
	case "$ownHeld" in
		lock=*[0-9]*" line=rig-session-$1 "*) printf 'own' ; return 0 ;;
		lock=*[0-9]*" line=rig-session-$1\ "*) printf 'own' ; return 0 ;;
	esac
	printf '%s' "$ownHeld"
}
rigDeadPid(){ ## -- the pid of a process that has ended
	( exit 0 ) & local deadPid=$! ; wait "$deadPid" 2> /dev/null ; printf '%s\n' "$deadPid"
}
rigFresh(){ ## -- a clean line at one lane, no lock, no slot taken and no budget set, an empty log, nothing held or let go
	rm -rf "$rigQueue" "$rigLanes" "$rigLock" "$rigTestLock" "$rigWorkers" ; : > "$rigTmp/log" ; rm -f "$rigTmp"/*.out "$rigTmp"/let.* ; rigHold=""
	rigQueueLimit="" ; rigHoldLimit="" ; rigStallLimit=""
	rigLanes 1
}
rigLanes(){ ## number -- how many lane(s) this machine allows: fixed by the rig, so the count is that number on any host
	mkdir -p "$rigLanes" && printf '%s\n' "$1" > "$rigLanes/max" && printf '%s\n' "$1" > "$rigLanes/count"
}
rigLaneHolders(){ ## -- the pids holding a lane of the rig's machine now, sorted, on one line (lane 1 is the hand rule's lock)
	local laneNumber=1 lanePid laneMax
	laneMax="$( LC_ALL=C sed -n 1p "$rigLanes/max" 2>/dev/null )"
	case "$laneMax" in ''|*[!0123456789]*) laneMax=1 ;; esac
	while [ "$laneNumber" -le "$laneMax" ] ; do
		case "$laneNumber" in
			1) lanePid="$( LC_ALL=C sed -n 's/^runner-pid: //p' "$rigLock/holder.txt" 2> /dev/null | LC_ALL=C sed -n 1p )" ;;
			*) lanePid="$( LC_ALL=C sed -n 's/^pid=//p' "$rigLanes/lane.$laneNumber/pid" 2> /dev/null | LC_ALL=C sed -n 1p )" ;;
		esac
		[ -z "$lanePid" ] || printf '%s\n' "$lanePid"
		laneNumber=$(( laneNumber + 1 ))
	done | LC_ALL=C sort | LC_ALL=C tr '\n' ' '
}
rigBudget(){ ## number -- the machine's budget of test workers set to it
	mkdir -p "$rigWorkers" && printf '%s\n' "$1" > "$rigWorkers/budget"
}
rigSlots(){ ## kind (H: held, W: asked for) -- how many the slot state lists
	LC_ALL=C grep -c "^$1 " "$rigWorkers/state" 2> /dev/null || :
}
rigBegun(){ ## -- the tests that have begun and not ended, by the shared log, space separated
	LC_ALL=C awk '$1 == "BEGIN" { on[$2] = 1 ; order[++n] = $2 ; } $1 == "END" { delete on[$2] ; } END { for ( i = 1 ; i <= n ; i++ ) if ( order[i] in on ) printf "%s ", order[i] ; }' "$rigTmp/log"
}
rigMostAtOnce(){ ## -- the most tests that were running at one time, by the shared log
	LC_ALL=C awk '$1 == "BEGIN" { n++ ; if ( n > most ) most = n ; } $1 == "END" { n-- ; } END { print most + 0 ; }' "$rigTmp/log"
}
rigUntilBegun(){ ## how many -- waits until that many tests have begun in all, up to four minutes; rc 1 when they never do
	local begunLeft=1200
	while [ "$( LC_ALL=C grep -c '^BEGIN ' "$rigTmp/log" )" -lt "$1" ] ; do
		[ "$begunLeft" -gt 0 ] || return 1
		sleep 0.2 ; begunLeft=$(( begunLeft - 1 ))
	done
}
rigUntilEnded(){ ## how many -- the same for tests that have ended
	local endedLeft=1200
	while [ "$( LC_ALL=C grep -c '^END ' "$rigTmp/log" )" -lt "$1" ] ; do
		[ "$endedLeft" -gt 0 ] || return 1
		sleep 0.2 ; endedLeft=$(( endedLeft - 1 ))
	done
}
rigSlotWaits(){ ## session -- how many lines of its output say a test of its waits for a worker slot
	LC_ALL=C grep -c -F -- 'a test waits for a worker slot' "$rigTmp/$1.out" 2> /dev/null || :
}

echo "-- 1. a full suite with nobody in the line runs at once, and holds the turn while it runs --"
rigFresh
rigRun a ; rigEnd "$rigLast"
rigAssert "it ran: rc 0, its one test passed, and it said nothing of waiting" "$rigRc $( LC_ALL=C grep -c '^PASS  RigTiny ' "$rigTmp/a.out" || : ) $( rigWaits a )" "0 1 0"
rigRunnerPid="$( rigHeld a | LC_ALL=C sed -n 's/^lock=\([0-9]*\) .*/\1/p' )"
rigAssert "while it ran, the hand rule's lock was held by its own runner, and it alone stood in the line" "$( [ -n "$rigRunnerPid" ] && printf held || printf not-held ) [$( rigHeld a )]" "held [lock=$rigRunnerPid line=rig-session-a ]"
rigAssert "when it ended it left the line and gave the lock back" "$( rigTickets ) $( [ -d "$rigLock" ] && printf held || printf free )" "0 free"
rigAssert "the line is the machine's, in the team's own directory under HOME, and in no copy of the package" "$( [ -d "$rigQueue" ] && printf there || printf missing ) $( find "$rigWs" -name 'suite-queue' 2> /dev/null | LC_ALL=C grep -c . || : )" "there 0"

echo "-- 2. three full suites from three copies: one at a time, in the order they arrived --"
rigFresh ; rigHold=1
rigRun a ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the first suite never began, so nothing below would be measured"
rigRun b ; rigPidB=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/b.out" || rigRefuse "the second suite never said it waits, so the order below would be nobody's"
rigRun c ; rigPidC=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/c.out" || rigRefuse "the third suite never said it waits, so the order below would be nobody's"
rigTicketA="$( ls "$rigQueue" | LC_ALL=C sed -n 1p | LC_ALL=C sed -n 's/^[0-9.]*\.\([0-9]*\)\.ticket$/\1/p' )"
rigAssert "while the first runs, three stand in the line, and neither of the others has begun" "$( rigTickets ) $( rigOrder )" "3 BEGIN a"
rigLet a ; rigEnd "$rigPidA" ; rigRcA=$rigRc
rigUntil 'BEGIN b' "$rigTmp/log" || :
rigUntil 'rig-scratch-b/source, in the line for' "$rigTmp/c.out" || :
rigAssert "the first ended, the second began, and the third still waits, now behind the second" "$( rigOrder ) $( rigTickets )" "BEGIN a END a BEGIN b 2"
rigLet b ; rigEnd "$rigPidB" ; rigRcB=$rigRc
rigLet c ; rigEnd "$rigPidC" ; rigRcC=$rigRc
rigAssert "all three ran" "$rigRcA $rigRcB $rigRcC" "0 0 0"
rigAssert "one at a time and in arrival order: each began only after the one before it had ended" "$( rigOrder )" "BEGIN a END a BEGIN b END b BEGIN c END c"
rigAssert "the second said, in one line, that it waits and behind whom: the first, by its session, the copy it runs from and how long it has held" "$( rigWaits b ) $( LC_ALL=C grep -c -F -- "this one waits its turn behind the run of session rig-session-a from $( rigRoot a ), in the line for " "$rigTmp/b.out" || : )" "1 1"
rigAssert "the third said whom it waited behind, in one line each time that changed, naming a copy ahead of it and never its own" "$( rigWaits c ) $( LC_ALL=C grep -F -- 'waits its turn behind' "$rigTmp/c.out" | LC_ALL=C sed -e 's/.* from //' -e 's/, in the line for .*//' -e "s|$rigWs/.local/temp/||" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" "2 rig-scratch-a/source rig-scratch-b/source "
rigAssert "each held the lock itself while it ran" "$( rigHeldOwn b ) $( rigHeldOwn c )" "own own"
rigAssert "and the line and the lock are free again" "$( rigTickets ) $( [ -d "$rigLock" ] && printf held || printf free )" "0 free"

echo "-- 2a. a run of a higher tier is served before the ordinary runs that arrived before it, and its ticket names the tier --"
rigFresh ; rigHold=1
rigRun a ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the first suite never began, so nothing below would be measured"
rigRun b ; rigPidB=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/b.out" || rigRefuse "the ordinary suite never said it waits, so the order below would be nobody's"
rigTier=urgent ; rigRun c ; rigPidC=$rigLast ; rigTier=""
rigUntil 'waits its turn behind' "$rigTmp/c.out" || rigRefuse "the urgent suite never said it waits, so the order below would be nobody's"
rigAssert "the urgent ticket names its tier, and sorts first" "$( LC_ALL=C grep -h '^tier=' "$rigQueue"/*.ticket 2> /dev/null ) $( ls "$rigQueue" | LC_ALL=C grep '\.ticket$' | LC_ALL=C sed -n '1s/^\(0b-\).*/\1/p' )" "tier=urgent 0b-"
rigLet a ; rigEnd "$rigPidA"
rigUntil 'BEGIN c' "$rigTmp/log" || :
rigLet c ; rigEnd "$rigPidC"
rigUntil 'BEGIN b' "$rigTmp/log" || :
rigLet b ; rigEnd "$rigPidB"
rigAssert "the urgent run began before the ordinary one that arrived before it" "$( rigOrder )" "BEGIN a END a BEGIN c END c BEGIN b END b"

echo "-- 2b. with no tier given, a run takes its context task's tier: the item its session's spawn record names, and its mark --"
rigFresh ; rigHold=1
mkdir -p "$rigTmp/fakebin" "$rigWs/.local/agents/spawned/rig-session-c"
printf '#!/bin/sh\nprintf -- "---\\nmark: urgent\\n---\\n"\n' > "$rigTmp/fakebin/DistroAgentsItems.fn.sh" ; chmod +x "$rigTmp/fakebin/DistroAgentsItems.fn.sh"
printf -- '---\nsession-id: rig-session-c\ndescription: Board item task-20260101T0000Z-rig-urgent.md, approved\n---\n' > "$rigWs/.local/agents/spawned/rig-session-c/rig-session-c.spawn.md"
rigRun a ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the first suite never began, so nothing below would be measured"
rigRun b ; rigPidB=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/b.out" || rigRefuse "the ordinary suite never said it waits, so the order below would be nobody's"
PATH="$rigTmp/fakebin:$PATH" rigRun c ; rigPidC=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/c.out" || rigRefuse "the task's suite never said it waits, so the order below would be nobody's"
rigAssert "the ticket names the tier its task's mark gave" "$( LC_ALL=C grep -h '^tier=' "$rigQueue"/*.ticket 2> /dev/null )" "tier=urgent"
rigLet a ; rigEnd "$rigPidA"
rigUntil 'BEGIN c' "$rigTmp/log" || :
rigLet c ; rigEnd "$rigPidC"
rigUntil 'BEGIN b' "$rigTmp/log" || :
rigLet b ; rigEnd "$rigPidB"
rigAssert "the urgent task's run began before the ordinary one that arrived before it" "$( rigOrder )" "BEGIN a END a BEGIN c END c BEGIN b END b"
rm -rf "$rigTmp/fakebin" "$rigWs/.local/agents/spawned/rig-session-c"

echo "-- 3. a run of named tests stands in the same line --"
rigFresh ; rigHold=1
rigRun a ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the full suite never began, so nothing below would be measured"
rigHold=""
rigRun n RigTiny ; rigPidN=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/n.out" || rigRefuse "the named run never said it waits, so the order below would be nobody's"
rigAssert "while the full suite runs, the named run waits behind it, begins nothing, and both stand in the line" "$( rigOrder ) $( rigTickets ) $( rigWaits n )" "BEGIN a 2 1"
rigLet a ; rigEnd "$rigPidA" ; rigRcA=$rigRc
rigEnd "$rigPidN"
rigAssert "it ran once the full suite had ended, holding the lock itself" "$rigRcA $rigRc $( rigOrder ) $( rigHeldOwn n )" "0 0 BEGIN a END a BEGIN n END n own"
rigAssert "and the line and the lock are free again" "$( rigTickets ) $( [ -d "$rigLock" ] && printf held || printf free )" "0 free"

echo "-- 4. a place whose run is not there is given up by itself --"
rigFresh
mkdir -p "$rigQueue"
## A run is known to have gone by its own records, never by a process: a spawn record settled, or a session store with its
## end marker. A ticket with no session line was never written whole, so it holds nobody's place. A ticket naming `none`
## is judged by its age and beat instead: a run with no id has no record to read, which is no evidence it is gone.
rigRecord(){ ## session, status -- that session's spawn record in the rig's workspace
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nstatus: %s\nhost: %s\n---\n\n# Spawn session: %s\n' "$1" "$1" "$2" "$( hostname -s 2> /dev/null )" "$1" > "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
}
rigDead="$( rigDeadPid )"
rigRecord rig-settled-run spawn-succeeded
rigRecord rig-dropped-run spawn-ended-without-close
mkdir -p "$rigWs/.local/agents/sessions/rig-marked-run" ; printf 'ended-at: 2026-01-01T00:00:00Z\nreason: clear\n' > "$rigWs/.local/agents/sessions/rig-marked-run/ended"
printf 'session=rig-settled-run\norigin=%s\nkind=run\nsince=%s\n' "$( rigRoot b )" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$rigQueue/0000000001.000000.rig-settled-run.ticket"
printf 'session=rig-dropped-run\norigin=%s\nkind=run\nsince=%s\n' "$( rigRoot c )" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$rigQueue/0000000002.000000.rig-dropped-run.ticket"
printf 'session=rig-marked-run\norigin=%s\nkind=check\nsince=%s\n' "$( rigRoot c )" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$rigQueue/0000000003.000000.rig-marked-run.ticket"
: > "$rigQueue/0000000005.000000.7.ticket"
rigRun a ; rigEnd "$rigLast"
rigAssert "places ahead whose run is settled, whose session store says it ended, or that were never written whole: the suite runs at once, saying nothing of waiting" "$rigRc $( rigWaits a ) $( rigOrder )" "0 0 BEGIN a END a"
rigAssert "and they are taken out of the line" "$( rigTickets )" 0
mkdir -p "$rigLock" ; printf 'runner-pid: %s\nagent: AgentsRunTests.sh, a full suite from %s\ntaken: 2026-01-01T00:00:00Z\n' "$rigDead" "$( rigRoot b )" > "$rigLock/holder.txt"
: > "$rigTmp/log"
rigRun a ; rigEnd "$rigLast"
rigAssert "the lock left by a runner that is gone is released too: the suite runs at once, and gives its own lock back" "$rigRc $( rigWaits a ) $( rigOrder ) $( [ -d "$rigLock" ] && printf held || printf free )" "0 0 BEGIN a END a free"
rm -rf "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions"

echo "-- 5. the hand rule's lock is kept by both sides --"
rigFresh
mkdir -p "$rigLock" ; printf 'agent: rig-scratch-other (a session on the hand rule)\ntaken: 2026-01-01T00:00:00Z\n' > "$rigLock/holder.txt"
rigRun a ; rigPidA=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/a.out" || :
sleep 3
rigAssert "a lock another session holds by hand: the suite waits, begins nothing, and says behind whom, the lock by its path and its holder's own note" "$( rigOrder ) $( LC_ALL=C grep -c -F -- "this one waits its turn behind the lock $rigLock, taken by hand and held by: agent: rig-scratch-other (a session on the hand rule) taken: 2026-01-01T00:00:00Z -- where that was done for this very run, remove it: the run takes the turn itself" "$rigTmp/a.out" || : )" " 1"
rigAssert "it never removes a lock taken by hand, however long it waits" "$( [ -d "$rigLock" ] && printf held || printf free ) $( LC_ALL=C grep -c 'rig-scratch-other' "$rigLock/holder.txt" 2> /dev/null || : )" "held 1"
rigTicketA="$( ls "$rigQueue" | LC_ALL=C sed -n 1p )"
rm -rf "$rigLock"
rigEnd "$rigPidA"
rigAssert "accepted sibling: once that session removes its lock, the suite takes its turn, holding the lock itself, and gives it back" "$rigRc $( rigOrder ) $( rigHeldOwn a ) $( [ -d "$rigLock" ] && printf held || printf free )" "0 BEGIN a END a own free"
rigFresh
mkdir -p "$rigLock" ; printf 'agent: rig-scratch-a (this session, on the hand rule)\ntaken: 2026-01-01T00:00:00Z\n' > "$rigLock/holder.txt"
rigRun a ; rigEnd "$rigLast"
rigAssert "a lock its own caller took by hand, its note naming the folder this run's source root is in: that is the turn, so it runs at once" "$rigRc $( rigWaits a ) $( rigOrder )" "0 0 BEGIN a END a"
rigAssert "and that lock is left as it was, for the caller to remove" "$( [ -d "$rigLock" ] && printf held || printf free ) $( LC_ALL=C grep -c 'rig-scratch-a (this session' "$rigLock/holder.txt" 2> /dev/null || : ) $( LC_ALL=C grep -c 'runner-pid' "$rigLock/holder.txt" 2> /dev/null || : )" "held 1 0"
: > "$rigTmp/log"
rigRun b ; rigPidB=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/b.out" || :
sleep 3
rigAssert "control: the same lock is another session's to a run from another copy, which waits behind it" "$( rigOrder ) $( rigWaits b )" " 1"
kill -TERM "$rigPidB" 2> /dev/null ; rigEnd "$rigPidB"
rigAssert "a waiting run that is told to end leaves the line, and leaves the lock that is not its own" "$( rigTickets ) $( [ -d "$rigLock" ] && printf held || printf free ) $( rigOrder )" "0 held "
## A lock taken by hand is no turn. Two runs wait in the line behind a lock a third session holds by hand; that
## session's own run arrives behind them.
rigFresh
mkdir -p "$rigLock" ; printf 'agent: rig-scratch-c (a session that took the lock by hand, ahead of the line)\ntaken: 2026-01-01T00:00:00Z\n' > "$rigLock/holder.txt"
rigRun a ; rigPidA=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/a.out" || rigRefuse "the first waiting run never said it waits, so the line below would be empty"
rigRun b ; rigPidB=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/b.out" || rigRefuse "the second waiting run never said it waits, so the line below would be shorter"
rigTicketA="$( ls "$rigQueue" | LC_ALL=C sed -n 1p )"
rigRun c ; rigEnd "$rigLast"
rigAssert "the run of the caller that holds the lock by hand is refused while others stand ahead of it: rc 1, nothing begun, and its one line says why, how many are ahead, who is first, and what to do" "$rigRc [$( rigOrder )] $( LC_ALL=C grep -c -F -- "⛔ ERROR: AgentsRunTests.sh: not started: this run's caller holds $rigLock by hand, and its turn in the machine's line has not come: 2 run(s) stand ahead of it, the first the run of session rig-session-a from $( rigRoot a ), in the line for " "$rigTmp/c.out" || : ) $( LC_ALL=C grep -c -F -- 'A lock taken by hand is no turn. Remove it and run again: the run waits its turn by itself, and takes the lock itself when that comes.' "$rigTmp/c.out" || : )" "1 [] 1 1"
rigAssert "it left the line, the two ahead of it still stand there, and the lock is left as it was" "$( rigTickets ) $( [ -d "$rigLock" ] && printf held || printf free ) $( LC_ALL=C grep -c 'rig-scratch-c' "$rigLock/holder.txt" 2> /dev/null || : )" "2 held 1"
rm -rf "$rigLock"
rigEnd "$rigPidA" ; rigRcA=$rigRc ; rigEnd "$rigPidB"
rigAssert "accepted sibling: with that lock removed, the two that waited run in the order they arrived" "$rigRcA $rigRc $( rigOrder )" "0 0 BEGIN a END a BEGIN b END b"

echo "-- 5a. a run never waits past its bound: it says whom it waits behind, refuses, and holds nobody --"
## Two runs waited half an hour on 2026-11-03 before a person ended them. A ticket is honoured only while its holder is a
## live run, so the one this section waits behind is a real run, held until the rig lets it go. A run that waits
## MDAT_SUITE_QUEUE_LIMIT seconds refuses, names the run in front of it, and gives its own ticket back, so nothing behind
## it waits on a run that will never start. The control is the same wait with a bound longer than it.
rigFresh ; rigHold=1
rigRun a RigTiny ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the run ahead never began, so the bound below would be measured on nothing"
rigQueueLimit=3
rigRun b RigTiny ; rigEnd "$rigLast"
rigAssert "a run whose turn has not come within its bound is refused, and runs nothing" "$rigRc [$( rigOrder )]" "1 [BEGIN a]"
rigAssert "its one line names the run it waited behind, its copy and when it joined the line, and says nothing was run" \
	"$( LC_ALL=C grep -c -F -- "⛔ ERROR: AgentsRunTests.sh: not started: its turn in the machine's line had not come within 3s. It waited behind the run of session rig-session-a from $( rigRoot a ), in the line for " "$rigTmp/b.out" || : )" 1
rigAssert "and it gave its own ticket back: the run it waited behind is the only one still in the line" "$( rigTickets )" 1
rigQueueLimit=""
rigRun c RigTiny ; rigPidC=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/c.out" || rigRefuse "the third run never said it waits, so the control below would be nobody's"
rigLet a
rigUntil 'BEGIN c' "$rigTmp/log" || rigRefuse "the third run never began once the first let go, so the control below would measure nothing"
rigEnd "$rigPidA"
rigEnd "$rigPidC"
rigAssert "control: the same wait with a bound longer than it lets a run through, so the refusal above is the bound and not the line" \
	"$rigRc $( LC_ALL=C grep -c -x -F 'BEGIN c' "$rigTmp/log" || : )" "0 1"
rigHold="" ; rigQueueLimit=""

echo "-- 5b. a place held past the stated limit is given up, and a waiting run is told who holds it and for how long --"
## S10.29. A full suite left by an ended run held the machine's head for almost 27 hours on 2026-11-05, and every later
## check waited behind it. A ticket whose run's records say it ended gives up its place (section 4). A ticket still held
## past MDAT_SUITE_QUEUE_HOLD_SECONDS gives it up too, however alive its run looks, and the run waiting behind it says who
## holds the line and for how long before it is released. The control is the same place read with a bound longer than its
## age: it is kept then, and the run behind it is refused at its own bound.
rigAwait(){ ## fixed text, file, seconds -- waits for that line of the file, up to that many seconds; rc 1 when it never comes
	local awaitLeft="$3"
	while ! LC_ALL=C grep -q -F -- "$1" "$2" 2> /dev/null ; do
		[ "$awaitLeft" -gt 0 ] || return 1
		sleep 0.2 ; awaitLeft=$(( awaitLeft - 1 ))
	done
}
rigPlace(){ ## -- a place in the line held two hours by a live run, whose own record says it is started
	rigFresh ; rigLanes 1
	rigRecord rig-holder-run spawn-started
	mkdir -p "$rigQueue"
	printf 'session=rig-holder-run\norigin=%s\nkind=run\nsince=%s\n' "$( rigRoot b )" "$( date -u -v-2H '+%Y-%m-%dT%H:%M:%SZ' 2> /dev/null || date -u -d '2 hours ago' '+%Y-%m-%dT%H:%M:%SZ' )" > "$rigQueue/0000000001.000000.rig-holder-run.ticket"
}
rigPlace ; rigHoldLimit=600 ; rigStallLimit=7200 ; rigQueueLimit=30
rigRun n RigTiny ; rigPidN=$rigLast
rigEnd "$rigPidN"
rigAssert "a place held past the stated limit is given up, and the run says who held it, from which copy, and for how long" \
	"$( LC_ALL=C grep -c -E -- "a place given up in the line, so this run stands no longer behind it: the run of session rig-holder-run from $( rigRoot b ), in the line for [0-9]+s$" "$rigTmp/n.out" || : )" "1"
rigAssert "and the run behind it goes on to run its test, with no place left standing" "$rigRc $( rigOrder ) $( rigTickets )" "0 BEGIN n END n 0"
rigPlace ; rigHoldLimit=86400 ; rigStallLimit=7200 ; rigQueueLimit=30
rigRun n RigTiny ; rigPidN=$rigLast
rigAwait 'waits its turn behind' "$rigTmp/n.out" 60 || :
rigAssert "control: with the limit longer than the place is old, the run waits behind it and says so, and that place stands" \
	"$( LC_ALL=C grep -c -E -- "this one waits its turn behind the run of session rig-holder-run from $( rigRoot b ), in the line for [0-9]+s$" "$rigTmp/n.out" || : ) $( rigTickets )" "1 2"
rigEnd "$rigPidN"
rigAssert "and that run was refused at its own bound, having run nothing, so the two bounds are told apart" "$rigRc [$( rigOrder )]" "1 []"
rigHoldLimit="" ; rigStallLimit="" ; rigQueueLimit=""
rm -rf "$rigWs/.local/agents/spawned"

echo "-- 6. no line, no run --"
rigFresh
: > "$rigTmp/not-a-directory"
rigHomeFor="$rigTmp/not-a-directory"
rigRun a ; rigEnd "$rigLast"
rigAssert "where the machine's line cannot be made, a full suite is refused rather than run outside its turn: rc 1, nothing begun, the place named" "$rigRc $( rigOrder ) $( LC_ALL=C grep -c -F -- "⛔ ERROR: AgentsRunTests.sh: cannot create the machine's line of test runs: $rigTmp/not-a-directory/.agents/magic-team/suite-queue" "$rigTmp/a.out" || : )" "1  1"
rigRun n RigTiny ; rigEnd "$rigLast"
rigAssert "nor is a run of named tests run outside its turn, where the line cannot be made: rc 1, nothing begun, the place named" "$rigRc [$( rigOrder )] $( LC_ALL=C grep -c -F -- "⛔ ERROR: AgentsRunTests.sh: cannot create the machine's line of test runs: $rigTmp/not-a-directory/.agents/magic-team/suite-queue" "$rigTmp/n.out" || : )" "1 [] 1"
rigHomeFor=""
rigRun n RigTiny ; rigEnd "$rigLast"
rigAssert "accepted sibling: with the machine's own directory there, the same named run runs at once, and leaves the line empty" "$rigRc $( rigOrder ) $( rigWaits n ) $( rigTickets )" "0 BEGIN n END n 0 0"

echo "-- 7. one budget of test workers for the whole machine, shared by every runner --"
## A run of named tests, three tests on three workers, every test held until the rig lets it end; the budget is 2. A second run, of three more, waits its turn.
rigFresh ; rigBudget 2 ; rigHold=1
rigRun p -w 3 RigTiny ; rigPidP=$rigLast
rigUntilBegun 2 || rigRefuse "two tests never began under a budget of two, so nothing below would be measured"
rigUntil 'a test waits for a worker slot' "$rigTmp/p.out" || rigRefuse "the run never said a test of its waits"
rigAssert "a run on more workers than the budget holds the budget and no more: two tests begun, two slots held, the third asked for and waiting" "$( rigBegun | LC_ALL=C wc -w | LC_ALL=C tr -d ' ' ) $( rigSlots H ) $( rigSlots W )" "2 2 1"
rigAssert "it said so in one line: a test of its waits, and how many slots are in use, of how many" "$( rigSlotWaits p ) $( LC_ALL=C grep -h -F -- 'a test waits for a worker slot' "$rigTmp/p.out" | LC_ALL=C sort -u | LC_ALL=C sed "s|$rigWorkers|<the budget>|" )" "1 # AgentsRunTests.sh: a test waits for a worker slot: 2 of 2 in use on this machine, the one budget every runner shares (<the budget>)"
rigAssert "it stands alone in the line, and holds its lock" "$( rigTickets ) $( [ -d "$rigLock" ] && printf held || printf free )" "1 held"
## each test let go in turn, whichever is running, until all three have ended
rigEndedWant=0
while [ "$rigEndedWant" -lt 3 ] ; do
	for rigRunningTest in $( rigBegun ) ; do rigLet "$rigRunningTest" ; done
	rigEndedWant=$(( rigEndedWant + 1 ))
	rigUntilEnded "$rigEndedWant" || rigRefuse "a held test never ended once let go"
done
rigEnd "$rigPidP" ; rigRcP=$rigRc
rigHold=""
rigRun q -w 3 RigTiny ; rigEnd "$rigLast"
rigAssert "started in the same second or not, each run has a folder of its own for its list and its logs" "$( LC_ALL=C sed -n 's/.*run folder: //p' "$rigTmp/p.out" "$rigTmp/q.out" | LC_ALL=C sort -u | LC_ALL=C grep -c . || : )" 2
rigAssert "all six ran, and at no time were more than the budget running at once" "$rigRcP $rigRc $( LC_ALL=C grep -c '^END ' "$rigTmp/log" ) $( rigMostAtOnce )" "0 0 6 2"
rigAssert "every slot was given back" "$( rigSlots H ) $( rigSlots W )" "0 0"
rigAssert "every test ran at a lowered priority, nice 10 or lower still" "$( LC_ALL=C awk '$1 == "NICE" { n++ ; if ( $3 + 0 < 10 ) bad++ ; } END { printf "%d %d", n, bad ; }' "$rigTmp/log" )" "6 0"
## A slot whose process is gone comes back by itself: a holder that never ran here, then one that was killed with its runner.
rigFresh ; rigBudget 1
rigDead="$( rigDeadPid )"
mkdir -p "$rigWorkers" ; printf 'H %s\n' "$rigDead" > "$rigWorkers/state"
rigRun n RigTiny ; rigEnd "$rigLast"
rigAssert "the one slot listed for a process that no longer exists: a test takes it at once, and nobody is told to wait" "$rigRc $( rigOrder ) $( rigSlotWaits n )" "0 BEGIN n END n 0"
rigFresh ; rigBudget 1 ; rigHold=1 ; rigStallLimit=3
rigRun a RigTiny ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the test that was to be killed never began"
rigSlotPid="$( LC_ALL=C sed -n 's/^H //p' "$rigWorkers/state" | LC_ALL=C sed -n 1p )"
## first whoever would give the slot back, the runner's own process that waits for the test, then the slot's keeper with the test under it, so no held test outlives this section
rigSlotGiver="$( ps -o ppid= -p "$rigSlotPid" 2> /dev/null | LC_ALL=C tr -d ' ' )"
kill -KILL "$rigSlotGiver" "$rigPidA" 2> /dev/null ; rigProcNote "$rigSlotPid" ; rigProcSignalWithChildren KILL "$rigSlotPid" || : ; wait "$rigPidA" 2> /dev/null
rigKilledLeft=50 ; while kill -0 "$rigSlotPid" 2> /dev/null && [ "$rigKilledLeft" -gt 0 ] ; do sleep 0.2 ; rigKilledLeft=$(( rigKilledLeft - 1 )) ; done
rigAssert "control: the killed test's slot is still listed, since nobody was left to give it back" "$( LC_ALL=C grep -c "^H $rigSlotPid\$" "$rigWorkers/state" || : )" 1
rigHold=""
rigRun n RigTiny ; rigEnd "$rigLast"
rigAssert "the next test to ask takes it all the same, and the dead holder is gone from the list" "$rigRc $( rigOrder ) $( LC_ALL=C grep -c "^H $rigSlotPid\$" "$rigWorkers/state" || : )" "0 BEGIN a BEGIN n END n 0"
rigStallLimit=""
## A run of named tests waits for the whole of a full suite, whose slots it never shares. Budget 1; a full suite of three
## tests on two workers has one test running and one waiting when the named run arrives.
rigFresh ; rigBudget 1 ; rigHold=1
rigRun p -w 2 ; rigPidP=$rigLast
rigUntilBegun 1 || rigRefuse "the full suite's first test never began"
rigUntil 'a test waits for a worker slot' "$rigTmp/p.out" || rigRefuse "the full suite's second test never asked for a slot"
rigHold=""
rigRun n RigTiny ; rigPidN=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/n.out" || rigRefuse "the named run never said it waits its turn"
rigAssert "a named run beside a full suite waits in the line and asks for no slot: two tickets, one slot held, one asked for, by the suite" "$( rigTickets ) $( rigSlots H ) $( rigSlots W ) $( rigWaits n )" "2 1 1 1"
## the suite's three tests and the named run's one, each let go once it has begun
rigEndedWant=0
while [ "$rigEndedWant" -lt 4 ] ; do
	rigEndedWant=$(( rigEndedWant + 1 ))
	rigUntilBegun "$rigEndedWant" || rigRefuse "a test never began once the one before it had ended"
	for rigRunningTest in $( rigBegun ) ; do rigLet "$rigRunningTest" ; done
	rigUntilEnded "$rigEndedWant" || rigRefuse "a held test never ended once let go"
done
rigEnd "$rigPidP" ; rigRcP=$rigRc
rigEnd "$rigPidN"
## The suite gives its lane up between two of its checks once the one in flight has ended (section 10), so the named run goes third.
rigAssert "the tests run one at a time, and the named run goes once the suite's check in flight has ended" "$rigRcP $rigRc $( LC_ALL=C sed -n 's/^BEGIN \([a-z]\).*/\1/p' "$rigTmp/log" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' ) $( rigMostAtOnce )" "0 0 p p n p 1"
## The budget where none is set: half the machine's cores. That many slots held by live processes leave none.
rigFresh
rigCores="$( sysctl -n hw.ncpu 2> /dev/null || getconf _NPROCESSORS_ONLN 2> /dev/null || echo 2 )"
rigHalf=$(( rigCores / 2 )) ; [ "$rigHalf" -ge 1 ] || rigHalf=1
mkdir -p "$rigWorkers" ; : > "$rigWorkers/state" ; rigHolders=""
for (( rigHolder = 1 ; rigHolder <= rigHalf ; rigHolder++ )) ; do
	sleep 600 & rigHolders="$rigHolders $!" ; rigStarted="$rigStarted $!" ; printf 'H %s\n' "$!" >> "$rigWorkers/state" ; rigProcNote "$!"
done
rigRun n RigTiny ; rigPidN=$rigLast
rigUntil 'a test waits for a worker slot' "$rigTmp/n.out" || rigRefuse "with every slot of the default budget held, the test never said it waits"
rigAssert "with no budget set it is half the machine's cores: that many held, and a test waits, saying so" "[$( rigOrder )] $( LC_ALL=C grep -c -F -- "a test waits for a worker slot: $rigHalf of $rigHalf in use on this machine" "$rigTmp/n.out" || : )" "[] 1"
rigProcSignal TERM ${rigHolders%% [0-9]*} ; rigProcSignal TERM $rigHolders
rigEnd "$rigPidN"
rigAssert "and it runs once a holder is gone" "$rigRc $( rigOrder )" "0 BEGIN n END n"

echo "-- 8. the hand rule for any test run is honoured for as long as a session still holds its lock --"
rigTestLockHeld(){ ## -- whether the hand lock stands, and what its owner file says
	if [ -d "$rigTestLock" ] ; then printf 'held:%s' "$( LC_ALL=C tr '\n' ' ' < "$rigTestLock/owner" 2> /dev/null | LC_ALL=C sed 's/ $//' )" ; else printf free ; fi
}
rigFresh
mkdir -p "$rigTestLock" ; printf 'rig-scratch-other\n' > "$rigTestLock/owner"
rigRun n RigTiny ; rigPidN=$rigLast
rigUntil 'a test waits: another session holds' "$rigTmp/n.out" || rigRefuse "the run never said it waits behind the hand lock, so nothing below would be measured"
sleep 3
rigAssert "another session holds the lock by hand: a run starts no test beside it, and says in one line whose lock it waits behind" "[$( rigOrder )] $( LC_ALL=C grep -c -F -- "# AgentsRunTests.sh: a test waits: another session holds $rigTestLock by hand (rig-scratch-other), and no test starts beside a run that holds it" "$rigTmp/n.out" || : )" "[] 1"
rigAssert "its test keeps its place in the line for a slot, takes none, and the lock is never removed by the runner" "$( rigSlots H ) $( rigSlots W ) $( rigTestLockHeld )" "0 1 held:rig-scratch-other"
rm -rf "$rigTestLock"
rigEnd "$rigPidN"
rigAssert "accepted sibling: once that session removes its lock, the test runs" "$rigRc $( rigOrder )" "0 BEGIN n END n"
rigFresh
mkdir -p "$rigTestLock" ; printf 'rig-scratch-n\n' > "$rigTestLock/owner"
rigRun n RigTiny ; rigEnd "$rigLast"
rigAssert "a lock whose owner is the folder this run starts from is its own caller's: its tests run under it, nobody is told to wait, and the lock is left for the caller" "$rigRc $( rigOrder ) $( LC_ALL=C grep -c -F -- 'a test waits' "$rigTmp/n.out" || : ) $( rigTestLockHeld )" "0 BEGIN n END n 0 held:rig-scratch-n"
: > "$rigTmp/log"
rigRun live RigTiny ; rigEnd "$rigLast"
rigAssert "a run from a tree that is no scratch folder cannot tell whose the lock is, and takes it as its caller's own: a session on the hand rule runs the live tree's tests under its own lock" "$rigRc $( rigOrder ) $( LC_ALL=C grep -c -F -- 'a test waits' "$rigTmp/live.out" || : ) $( rigTestLockHeld )" "0 BEGIN live END live 0 held:rig-scratch-n"

echo "-- 9. the machine's lanes: as many runs stand beside each other as it has, in arrival order --"
## The line became the throttle: a run of one named test held every other run for as long as it took. A lane is what a
## run holds, the count comes from the machine's pace (fixed here), and a ticket ahead that holds no lane is still the
## head of the queue. The rig's test writes its BEGIN and END to the shared log, so what ran at once is its own order.
rigFresh ; rigLanes 2 ; rigHold=1
rigRun a RigTiny ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the first run never began, so nothing below would be measured"
rigRun b RigTiny ; rigPidB=$rigLast
rigUntil 'BEGIN b' "$rigTmp/log" || rigRefuse "the second run never began beside the first: two lanes were free but the run waited"
rigAssert "with two lanes, the second run begins while the first still runs: two tests at once, and neither said it waits" \
	"$( rigMostAtOnce ) $( rigWaits a )$( rigWaits b )" "2 00"
rigAssert "each holds a lane of its own, so no lane is taken twice" \
	"$( rigLaneHolders | LC_ALL=C awk '{ print NF ; }' )" 2
rigAssert "and the two tests' names are the ones the log holds at once" \
	"$( rigBegun | LC_ALL=C wc -w | LC_ALL=C tr -d ' ' )" 2
rigLet a ; rigLet b ; rigEnd "$rigPidA" ; rigEnd "$rigPidB"
rigAssert "both ran through, rc 0 each" "$rigRc $( LC_ALL=C grep -c '^END ' "$rigTmp/log" )" "0 2"
rigAssert "and both lanes are free again, with the line empty" "$( rigLaneHolders )|$( rigTickets )" "|0"
rigFresh ; rigLanes 2 ; rigHold=1
rigRun a RigTiny ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the run that was to hold a lane never began"
rigRun b RigTiny ; rigPidB=$rigLast
rigUntil 'BEGIN b' "$rigTmp/log" || rigRefuse "the second run never began on the machine's second lane"
rigRun c RigTiny ; rigPidC=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/c.out" || rigRefuse "with both lanes taken, the third run never said it waits, so the limit below would be nobody's"
rigAssert "with both lanes taken, a third run waits and begins nothing, saying whom it waits behind" "$( rigOrder ) $( rigWaits c )" "BEGIN a BEGIN b 1"
rigLet a ; rigEnd "$rigPidA"
rigUntil 'BEGIN c' "$rigTmp/log" || rigRefuse "the third run never took the lane the first gave back, so the lane would be held by the dead"
rigAssert "control: the lane the first run gave back is taken by the third at once, and it runs" "$( LC_ALL=C grep -c -x -F 'BEGIN c' "$rigTmp/log" )" 1
rigLet b ; rigLet c ; rigEnd "$rigPidB" ; rigEnd "$rigPidC"
rigAssert "all three ran, and never more than the machine's two lanes at once" "$( LC_ALL=C grep -c '^END ' "$rigTmp/log" ) $( rigMostAtOnce )" "3 2"
rigFresh ; rigLanes 1 ; rigHold=1
rigRun a RigTiny ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the run on the one-lane machine never began"
rigRun b RigTiny ; rigPidB=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/b.out" || rigRefuse "with one lane the second run never said it waits"
rigAssert "one lane is the machine as it was: the second run waits, and says so in one line" "$( rigOrder ) $( rigWaits b )" "BEGIN a 1"
rigLet a ; rigEnd "$rigPidA" ; rigLet b ; rigEnd "$rigPidB"
rigAssert "and then it runs" "$( LC_ALL=C grep -c '^END ' "$rigTmp/log" )" 2
## A lane whose run is gone is taken by whoever asks next: a lane file left by a dead run, and a lock taken by hand,
## which is lane 1 and is a live session's, so it is never given back.
rigFresh ; rigLanes 2 ; rigDead="$( rigDeadPid )"
mkdir -p "$rigLanes/lane.1" ; printf 'pid=%s\n' "$rigDead" > "$rigLanes/lane.1/pid"
rigRun n RigTiny ; rigEnd "$rigLast"
rigAssert "a lane listed for a process that no longer exists is taken at once, and nobody is told to wait" "$rigRc $( rigOrder ) $( rigWaits n )" "0 BEGIN n END n 0"
rigFresh ; rigLanes 2
mkdir -p "$rigLock" ; printf 'agent: rig-scratch-other (a session on the hand rule)\ntaken: 2026-01-01T00:00:00Z\n' > "$rigLock/holder.txt"
rigRun n RigTiny ; rigPidN=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/n.out" || rigRefuse "a lock taken by hand never made the run wait, so the lane rule below would be nobody's"
rigAssert "a lock taken by hand shuts every lane: the run waits behind it, and the lock is left as it was" "$( rigWaits n ) $( [ -d "$rigLock" ] && printf held || printf free ) $( LC_ALL=C grep -c 'rig-scratch-other' "$rigLock/holder.txt" 2> /dev/null || : )" "1 held 1"
rm -rf "$rigLock" ; rigEnd "$rigPidN"
rigAssert "accepted sibling: once it is removed the run takes a lane and runs" "$rigRc $( rigOrder )" "0 BEGIN n END n"
## A test that measures its own timing takes every lane: declared `## lane: alone` in its header. The lanes it found
## held for it are counted as the machine's own: the hand rule's lock is lane 1, and every `lane.<n>` folder is another.
rigFresh ; rigLanes 3 ; rigHold=1
cat > "$( rigRoot a )/myx/myx.distro-agents/sh-test/RigTinyAlone.test.sh" <<'RIGALONE'
#!/usr/bin/env bash
## lane: alone
RIG_SUITE="$RIG_SUITE.alone"
printf 'BEGIN %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
rigLaneFirst=0
LC_ALL=C grep -q '^runner-pid: ' "$MMDAPP/.local/temp/suite-run.lock/holder.txt" 2> /dev/null && rigLaneFirst=1
rigLaneRest="$( ls "$HOME/.agents/magic-team/suite-lanes" 2> /dev/null | LC_ALL=C grep -c '^lane\.' )"
case "$rigLaneRest" in ''|*[!0123456789]*) rigLaneRest=0 ;; esac
printf 'LANES %s\n' "$(( rigLaneFirst + rigLaneRest ))" >> "$RIG_SHARED/log"
rigHeldFor=600
while [ -n "${RIG_HOLD:-}" ] && [ ! -e "$RIG_SHARED/let.$RIG_SUITE" ] && [ "$rigHeldFor" -gt 0 ] ; do sleep 0.2 ; rigHeldFor=$(( rigHeldFor - 1 )) ; done
printf 'END %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
echo "RIG_ALONE: OK"
RIGALONE
for rigSession in a b c ; do cp "$( rigRoot "$rigSession" )/myx/myx.distro-agents/sh-test/RigTinyAlone.test.sh" "$( rigRoot "$rigSession" )/myx/myx.distro-agents/sh-test/" 2> /dev/null || : ; done
rigRun a RigTinyAlone ; rigPidA=$rigLast
rigUntil 'BEGIN a.alone' "$rigTmp/log" || rigRefuse "the run of the alone test never began, so its lanes below would be nobody's"
rigUntil 'LANES ' "$rigTmp/log" || rigRefuse "the alone test never said how many lanes it found held for it"
rigAssert "a test whose header says it measures its own timing takes every lane of the machine" \
	"$( LC_ALL=C sed -n 's/^LANES //p' "$rigTmp/log" | LC_ALL=C sed -n 1p )" 3
rigRun b RigTiny ; rigPidB=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/b.out" || rigRefuse "a plain run never said it waits behind the alone run"
rigAssert "so no other run starts beside it: the plain run waits, and says why" "$( rigOrder ) $( rigWaits b )" "BEGIN a.alone 1"
rigLet a.alone ; rigEnd "$rigPidA"
rigUntil 'BEGIN b' "$rigTmp/log" || rigRefuse "the plain run never began once the alone run had ended"
rigLet b ; rigEnd "$rigPidB"
rigAssert "and once it has ended the plain run takes one lane and runs, so every lane is given back" "$( rigOrder ) $( rigLaneHolders )" "BEGIN a.alone END a.alone BEGIN b END b "
rm -f "$( rigRoot a )/myx/myx.distro-agents/sh-test/RigTinyAlone.test.sh"

echo "-- 10. a run gives its lane up between two checks to a run behind it, and keeps its checks whole --"
rigFresh ; rigHold=1
rigRun p ; rigPidP=$rigLast
rigUntil 'BEGIN p.1' "$rigTmp/log" || rigRefuse "the run of three checks never began, so nothing below would be measured"
rigRun a ; rigPidA=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/a.out" || rigRefuse "the run behind it never said it waits, so its words below would be nobody's"
rigAssert "the waiter names the run ahead as running, with its checks done of all" "$( LC_ALL=C grep -c -F -- 'running: 0 of 3 checks done' "$rigTmp/a.out" || : )" 1
rigLet p.1
rigUntilBegun 2 || rigRefuse "nothing began once the first check had ended"
rigAssert "the run behind it goes before the second check" "$( rigOrder )" "BEGIN p.1 END p.1 BEGIN a"
rigLet a ; rigLet p.2 ; rigLet p.3
rigEnd "$rigPidA" ; rigRcA=$rigRc
rigEnd "$rigPidP"
rigAssert "both runs passed, and the run that yielded said so and took its lane again" "$rigRcA $rigRc $( LC_ALL=C grep -c -F -e 'back between two checks' -e 'took its lane(s)' "$rigTmp/p.out" || : )" "0 0 2"
rigAssert "it ran every check once, in its order" "$( LC_ALL=C sed -E -n 's/^(PASS|FAIL) +(RigTiny[0-9]).*/\1 \2/p' "$rigTmp/p.out" | LC_ALL=C tr '\n' ' ' )" "PASS RigTiny1 PASS RigTiny2 PASS RigTiny3 "
rigAssert "and every lane is given back, with no mark left in the line" "$( rigLaneHolders )$( ls "$rigQueue" 2> /dev/null | LC_ALL=C grep -c '\.yield$' || : )" "0"

echo "-- 10a. a run of two workers yields once, not once per worker, and only once its checks in flight have ended --"
rigFresh ; rigHold=1 ; rigBudget 4
rigRun q -w 2 ; rigPidQ=$rigLast
rigUntilBegun 2 || rigRefuse "the two workers never began their first checks, so nothing below would be measured"
rigRun a ; rigPidA=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/a.out" || rigRefuse "the run behind it never said it waits"
rigLet q.1
rigUntilEnded 1 || rigRefuse "the first check never ended"
## the second check is still in flight: the run marks its ticket, hands out no new check, and holds its lane until that check ends
rigLeft=1200
while [ "$rigLeft" -gt 0 ] && [ "$( ls "$rigQueue" 2> /dev/null | LC_ALL=C grep -c '\.yield$' || : )" = 0 ] && [ "$( LC_ALL=C grep -c '^BEGIN ' "$rigTmp/log" || : )" -lt 3 ] ; do sleep 0.2 ; rigLeft=$(( rigLeft - 1 )) ; done
## the two first checks start together, in either order, so their begins are left out of the order compared
rigAssert "with a check in flight the run marks its ticket, hands out no new check, and holds its lane" \
	"$( ls "$rigQueue" 2> /dev/null | LC_ALL=C grep -c '\.yield$' || : ) $( LC_ALL=C grep -c '^BEGIN ' "$rigTmp/log" || : ) $( rigOrder | LC_ALL=C sed 's/BEGIN q\.[12] //g' ) [$( rigLaneHolders )]" "1 2 END q.1 [$rigPidQ ]"
rigLet q.2
rigUntilBegun 3 || rigRefuse "nothing began once the checks in flight had ended"
rigAssert "once they have ended the run behind it goes before the third check" "$( rigOrder | LC_ALL=C sed 's/BEGIN q\.[12] //g' )" "END q.1 END q.2 BEGIN a"
rigLet a ; rigLet q.3
rigEnd "$rigPidA" ; rigRcA=$rigRc
rigEnd "$rigPidQ"
rigAssert "both runs passed, and the run of two workers yielded once" "$rigRcA $rigRc $( LC_ALL=C grep -c -F -- 'back between two checks' "$rigTmp/q.out" || : ) $( LC_ALL=C grep -c -F -- 'took its lane(s)' "$rigTmp/q.out" || : )" "0 0 1 1"
rigAssert "it ran every check once" "$( LC_ALL=C sed -E -n 's/^(PASS|FAIL) +(RigTiny[0-9]).*/\1 \2/p' "$rigTmp/q.out" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "PASS RigTiny1 PASS RigTiny2 PASS RigTiny3 "

echo "-- 10b. one worker yields twice, to two runs that arrive one after the other, and takes its one lane back each time --"
rigFresh ; rigHold=1
rigRun p ; rigPidP=$rigLast
rigUntil 'BEGIN p.1' "$rigTmp/log" || rigRefuse "the run of three checks never began, so nothing below would be measured"
rigRun a ; rigPidA=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/a.out" || rigRefuse "the first run behind it never said it waits"
rigLet p.1
rigUntilBegun 2 || rigRefuse "the first run behind it never began"
rigLet a ; rigEnd "$rigPidA" ; rigRcA=$rigRc
rigUntilBegun 3 || rigRefuse "the second check never began once the first yield was over"
rigRun b ; rigPidB=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/b.out" || rigRefuse "the second run behind it never said it waits"
rigLet p.2
rigUntilBegun 4 || rigRefuse "the second run behind it never began"
rigLet b ; rigEnd "$rigPidB" ; rigRcB=$rigRc
## a run that cannot take its lane back hangs here: the wait is bounded, and a run that hangs is ended so nothing is left
if rigUntilBegun 5 ; then rigLet p.3 ; else rigProcSignal TERM "$rigPidP" || : ; fi
rigEnd "$rigPidP"
rigAssert "after its second yield it took its lane back and ran its third check" "$( rigOrder )" "BEGIN p.1 END p.1 BEGIN a END a BEGIN p.2 END p.2 BEGIN b END b BEGIN p.3 END p.3"
rigAssert "all three runs passed, and each yield took back the one lane it gave" "$rigRcA $rigRcB $rigRc $( LC_ALL=C grep -c -F -- 'took its lane(s) 1 again' "$rigTmp/p.out" || : )" "0 0 0 2"

echo "-- 10c. a run gives its lane up only to a ticket behind it with no free lane; a yielded run whose old lane another holds takes the lane that stands free --"
rigTicketOf(){ ## pid, session -- a ticket in the line for that live process, behind every ticket before it
	local ofFile="$rigQueue/$( date +%s ).000000.$1.ticket"
	printf 'session=%s\norigin=%s\nkind=run\nsince=%s\npid=%s\npstart=%s\nrundir=%s\n' "$2" "$( rigRoot a )" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" "$1" \
		"$( ps -o lstart= -p "$1" 2> /dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ //;s/ $//' )" "$rigTmp" > "$ofFile"
	date +%s > "$ofFile.beat"
}
## control: lane 2 stands free for the ticket behind, which takes it itself, so the run gives nothing up and begins its next check
rigFresh ; rigLanes 2 ; rigHold=1
rigRun p ; rigPidP=$rigLast
rigUntil 'BEGIN p.1' "$rigTmp/log" || rigRefuse "the run of three checks never began, so nothing below would be measured"
sleep 300 & rigPidWait=$! ; rigProcNote "$rigPidWait"
rigTicketOf "$rigPidWait" rig-session-waiter
rigLet p.1
rigUntilBegun 2 ; rigBegan=$?
rigAssert "control: a lane free for the ticket behind it, the run gives no lane up and begins its next check" "$rigBegan $( LC_ALL=C grep -c -F -- 'gave its lane(s)' "$rigTmp/p.out" || : )" "0 0"
rigLet p.2 ; rigLet p.3 ; rigEnd "$rigPidP"
rigProcSignal TERM "$rigPidWait" || :
## every lane held, lane 2 by a run of its own whose test is held: the ticket behind has no free lane, and the run gives its lane up to it
rigFresh ; rigLanes 2 ; rigHold=1
rigRun p ; rigPidP=$rigLast
rigUntil 'BEGIN p.1' "$rigTmp/log" || rigRefuse "the run of three checks never began, so nothing below would be measured"
rigRun b ; rigPidB=$rigLast
rigUntil 'BEGIN b' "$rigTmp/log" || rigRefuse "the run that holds lane 2 never began, so nothing below would be measured"
sleep 300 & rigPidWait=$! ; rigProcNote "$rigPidWait"
rigTicketOf "$rigPidWait" rig-session-waiter
rigLet p.1
rigUntil 'gave its lane(s)' "$rigTmp/p.out" || rigRefuse "the run never yielded to the ticket behind it"
## lane 1 goes to another live run with a ticket of its own, before the yielded run may take a lane back; lane 2 is let go by its
## run, and then the ticket it waited for ends
## its stand-in names the runner on its command line, which is what the lane reader takes a live run by (AgentsRunRunnerAlive)
bash -c 'sleep 300 ; :' rig-stand-in-AgentsRunTests.sh & rigPidOne=$! ; rigProcNote "$rigPidOne"
rigTicketOf "$rigPidOne" rig-session-one
mkdir "$rigLock" && printf 'runner-pid: %s\nsession=rig-session-one\n' "$rigPidOne" > "$rigLock/holder.txt"
rigLet b ; rigEnd "$rigPidB"
## the ticket it waited for ends as a run that ends does: its process goes, and it leaves the line
rigProcSignal TERM "$rigPidWait" || : ; rm -f "$rigQueue"/*.000000."$rigPidWait".ticket "$rigQueue"/*.000000."$rigPidWait".ticket.beat
rigAwait 'took its lane(s)' "$rigTmp/p.out" 150 ; rigTook=$?
rigAssert "its old lane held, it takes the free lane 2 within 30s" "$rigTook $( LC_ALL=C grep -c -F -- 'took its lane(s) 2 again' "$rigTmp/p.out" || : )" "0 1"
rigProcSignalWithChildren TERM "$rigPidOne" || : ; rm -rf "$rigLock"
rigLet p.2 ; rigUntilBegun 3 && rigLet p.3
rigEnd "$rigPidP"
rigAssert "and its run ended whole" "$rigRc" 0

echo "-- 10d. a run holding a lane above the count read now is a run at work, and the run behind it takes the free lane --"
rigFresh ; rigLanes 2 ; rigHold=1
rigRun a ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the first run never began, so nothing below would be measured"
rigRun b ; rigPidB=$rigLast
rigUntil 'BEGIN b' "$rigTmp/log" || rigRefuse "the second run never took lane 2 beside the first"
rigLet a ; rigEnd "$rigPidA"
## the machine's count falls to one while the second run still holds lane 2
printf '1\n' > "$rigLanes/count"
rigRun c ; rigPidC=$rigLast
rigAwait 'BEGIN c' "$rigTmp/log" 150 ; rigBegan=$?
rigAssert "lane 2 held above a count of 1, the run behind it takes the free lane 1 within 30s" "$rigBegan $( rigWaits c )" "0 0"
rigLet b ; rigLet c ; rigEnd "$rigPidB" ; rigEnd "$rigPidC"
rigAssert "and that run ended whole" "$rigRc" 0

echo "-- 10e. a run of two workers whose yield takes back another lane than it gave goes on with both workers, and ends --"
## p takes lane 1 and runs two checks at once; b holds lane 2; a ticket behind has no free lane, so p gives lane 1 up. Then lane 1 goes to a
## stand-in and b lets lane 2 go, so p takes lane 2 back: the worker that did not yield must go on with the lane the run holds now.
rigFresh ; rigLanes 2 ; rigHold=1
rigRun p -w 2 ; rigPidP=$rigLast
rigUntil 'BEGIN p.2' "$rigTmp/log" || rigRefuse "the run of two workers never began its two checks, so nothing below would be measured"
rigRun b ; rigPidB=$rigLast
rigUntil 'BEGIN b' "$rigTmp/log" || rigRefuse "the run that holds lane 2 never began, so nothing below would be measured"
sleep 300 & rigPidWait=$! ; rigProcNote "$rigPidWait"
rigTicketOf "$rigPidWait" rig-session-waiter
rigLet p.1 ; rigLet p.2
rigUntil 'gave its lane(s)' "$rigTmp/p.out" || rigRefuse "the run never yielded to the ticket behind it"
bash -c 'sleep 300 ; :' rig-stand-in-AgentsRunTests.sh & rigPidOne=$! ; rigProcNote "$rigPidOne"
rigTicketOf "$rigPidOne" rig-session-one
mkdir "$rigLock" && printf 'runner-pid: %s\nsession=rig-session-one\n' "$rigPidOne" > "$rigLock/holder.txt"
rigLet b ; rigEnd "$rigPidB"
rigProcSignal TERM "$rigPidWait" || : ; rm -f "$rigQueue"/*.000000."$rigPidWait".ticket "$rigQueue"/*.000000."$rigPidWait".ticket.beat
rigAwait 'took its lane(s) 2 again' "$rigTmp/p.out" 150 ; rigTook=$?
rigAwait 'BEGIN p.3' "$rigTmp/log" 150 || : ; rigLet p.3
## the run ends once its last check has: a worker still waiting for lane 1, which it no longer holds, would hold it open for ever
rigLeft=150 ; while [ "$rigLeft" -gt 0 ] && [ -n "$( rigProcStill "$rigPidP" )" ] ; do sleep 0.2 ; rigLeft=$(( rigLeft - 1 )) ; done
rigEnded="$( [ -z "$( rigProcStill "$rigPidP" )" ] && printf ended || printf hangs )"
rigAssert "it took lane 2 back, ran its third check, and ended within 30s of it" "$rigTook $( LC_ALL=C grep -c '^END p.3$' "$rigTmp/log" || : ) $rigEnded" "0 1 ended"
[ "$rigEnded" = ended ] || { rigProcSignalWithChildren TERM "$rigPidP" || : ; }
rigEnd "$rigPidP"
rigAssert "and it left no lane of its own behind" "$( ls "$rigLanes" 2> /dev/null | LC_ALL=C grep -c '^lane\.' || : )" "0"
rigProcSignalWithChildren TERM "$rigPidOne" || : ; rm -rf "$rigLock"

echo "-- 10f. a run that yielded waits for the run it yielded to only until that run holds a lane, then takes a lane that stands free --"
## p holds lane 1 and b lane 2; q, of three checks, arrives with no lane free, and p gives lane 1 up to it after its first check. q takes
## lane 1 and its first check is held. Then b lets lane 2 go: a run that waited for q to end would leave lane 2 free for as long as q works.
rigFresh ; rigLanes 2 ; rigHold=1
rigRun p ; rigPidP=$rigLast
rigUntil 'BEGIN p.1' "$rigTmp/log" || rigRefuse "the run of three checks never began, so nothing below would be measured"
rigRun b ; rigPidB=$rigLast
rigUntil 'BEGIN b' "$rigTmp/log" || rigRefuse "the run that holds lane 2 never began, so nothing below would be measured"
rigRun q ; rigPidQ=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/q.out" || rigRefuse "the run behind both lanes never said it waits, so the yield below would be nobody's"
rigLet p.1
rigUntil 'BEGIN q.1' "$rigTmp/log" || rigRefuse "the run p yielded to never began, so nothing below would be measured"
rigLet b ; rigEnd "$rigPidB"
rigAwait 'BEGIN p.2' "$rigTmp/log" 150 ; rigBegan=$?
rigAssert "with q at work on lane 1 and lane 2 free, p takes lane 2 within 30s and begins its second check while q's first is still held" "$rigBegan $( rigBegun )" "0 q.1 p.2 "
rigLet q.1 ; rigLet q.2 ; rigLet q.3 ; rigLet p.2 ; rigLet p.3
rigEnd "$rigPidQ" ; rigRcQ=$rigRc
rigEnd "$rigPidP"
rigAssert "and both runs ended whole" "$rigRcQ $rigRc" "0 0"

echo "-- 11. a check started by hand judges a run at work by its lane, and says how far it is --"
rigFresh
rigTempInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh"
rigWorkTicket="$rigQueue/$( date +%s ).000000.$$.ticket"
mkdir -p "$rigQueue" "$rigTmp/run-dir"
printf 'RigTiny1 900\nRigTiny2 900\nRigTiny3 900\n' > "$rigTmp/run-dir/tests.list"
printf 'PASS  RigTiny1  1s  RIG_TINY: OK\n' > "$rigTmp/run-dir/progress.txt"
printf 'session=rig-session-z\norigin=%s\nkind=run\nsince=%s\npid=%s\npstart=%s\nrundir=%s\n' "$( rigRoot a )" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" "$$" \
	"$( ps -o lstart= -p "$$" 2> /dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ //;s/ $//' )" "$rigTmp/run-dir" > "$rigWorkTicket"
printf '%s\n' "$(( $( date +%s ) - 7200 ))" > "$rigWorkTicket.beat"
rigState(){ ## -- what a check started by hand makes of that ticket, its stall limit a minute
	env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SPAWN_SESSION_ID=rig-session-check MDAT_SUITE_QUEUE_STALL_SECONDS=60 \
		bash -c '. "$1" > /dev/null 2>&1 ; rigQueueTicketState "$2"' _ "$rigTempInclude" "$rigWorkTicket"
}
rigAssert "control: its beat two hours old and no lane, it is judged stalled" "$( rigState )" stalled
mkdir -p "$rigLanes/lane.2" && printf 'pid=%s\nsession=rig-session-z\n' "$$" > "$rigLanes/lane.2/pid"
rigAssert "holding a lane, the same ticket is a run at work" "$( rigState )" alive
rigAssert "and the check names it with its checks done of all" \
	"$( env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" > /dev/null 2>&1 ; rigQueueTicketWhom "$2"' _ "$rigTempInclude" "$rigWorkTicket" | LC_ALL=C grep -c -F -- ', running: 1 of 3 checks done' || : )" 1

echo "-- 12. a check started by hand passes by a run that gave its lane up --"
rm -rf "$rigLanes/lane.2"
date +%s > "$rigWorkTicket.beat"
## the check stands apart from this run, so it takes a turn of its own: inside a run it would take none. It notes itself, and the
## watch its turn starts, so the section ends both below.
( env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SPAWN_SESSION_ID=rig-session-check MDAT_SUITE_CHECK_LIMIT_SECONDS=60 \
	bash -c '. "$1" > /dev/null 2>&1 ; . "$3" || exit 1 ; rigProcNoteFile "$2.procs" $$ ; rigQueueTurn 2> "$2.err" && { rigProcNoteFile "$2.procs" "$rigCheckWatchPid" ; echo WON > "$2" ; }' \
	_ "$rigTempInclude" "$rigTmp/won" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" > /dev/null 2>&1 < /dev/null & )
rigUntil 'waits its turn behind' "$rigTmp/won.err" || rigRefuse "the check never said it waits behind the run"
rigAssert "control: behind a run with no mark, the check waits" "$( [ -f "$rigTmp/won" ] && printf won || printf waits )" waits
date +%s > "$rigWorkTicket.yield"
rigUntil 'WON' "$rigTmp/won" || :
rigAssert "with the mark, it passes the run by and takes its turn" "$( [ -f "$rigTmp/won" ] && printf won || printf waits )" won
## what the section started ends here, whether the check still waits or its watch still sleeps
rigProcNoteFrom "$rigTmp/won.procs"
rigWonPids="$( LC_ALL=C awk 'NF == 2 { print $1 ; }' "$rigTmp/won.procs" 2> /dev/null )" || rigWonPids=""
[ -z "$rigWonPids" ] || rigProcSignalWithChildren KILL $rigWonPids || :
rigLeft=50
while [ "$rigLeft" -gt 0 ] && [ -n "$rigWonPids" ] && [ -n "$( rigProcStill $rigWonPids )" ] ; do sleep 0.2 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "and nothing it started is left running" "$( [ -n "$rigWonPids" ] && printf noted || printf not-noted ) $( [ -n "$rigWonPids" ] && rigProcStill $rigWonPids | LC_ALL=C grep -c . || : )" "noted 0"
rm -f "$rigWorkTicket" "$rigWorkTicket.beat" "$rigWorkTicket.yield"

echo "-- 14. a waiter far back costs the line little: no process per ticket ahead in a pass, and a longer pause past 10 ahead --"
## One lane, held; twenty live tickets ahead of the waiter b. The waiter runs with a sed and a sleep of the rig's first on its PATH: each
## logs itself, and the sleep lasts one second whatever it was asked, so two passes come quickly. One pass is what stands between two pauses.
rigFresh ; rigLanes 1 ; rigHold=1
rigRun a ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the run holding the one lane never began, so nothing below would be measured"
rigAhead=""
for rigOne in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 ; do
	sleep 300 & rigAheadPid=$! ; rigProcNote "$rigAheadPid" ; rigAhead="$rigAhead $rigAheadPid"
	rigTicketOf "$rigAheadPid" "rig-session-ahead-$rigOne"
done
mkdir -p "$rigTmp/shim"
printf '#!/bin/sh\nprintf "SED\\n" >> "%s/shim.log"\nexec /usr/bin/sed "$@"\n' "$rigTmp" > "$rigTmp/shim/sed"
printf '#!/bin/sh\nprintf "SLEEP %%s\\n" "$*" >> "%s/shim.log"\nexec /bin/sleep 1\n' "$rigTmp" > "$rigTmp/shim/sleep"
chmod +x "$rigTmp/shim/sed" "$rigTmp/shim/sleep" ; : > "$rigTmp/shim.log"
PATH="$rigTmp/shim:$PATH" rigRun b ; rigPidB=$rigLast
rigLeft=600 ; while [ "$rigLeft" -gt 0 ] && [ "$( LC_ALL=C grep -c -E '^SLEEP ([5-9]|[1-9][0-9]+)$' "$rigTmp/shim.log" )" -lt 3 ] ; do sleep 0.2 ; rigLeft=$(( rigLeft - 1 )) ; done
## the seds of the second pass: between the first and the second pause of the line's own length
rigPassSeds="$( LC_ALL=C awk '/^SLEEP ([5-9]|[1-9][0-9]+)$/ { pauses++ ; next ; } pauses == 1 && $0 == "SED" { n++ ; } END { print n + 0 ; }' "$rigTmp/shim.log" )"
rigPause="$( LC_ALL=C sed -n 's/^SLEEP \([5-9]\)$/\1/p;s/^SLEEP \([1-9][0-9]*\)$/\1/p' "$rigTmp/shim.log" | LC_ALL=C sed -n 1p )"
## the pass's own reads (the lanes, the first ticket named) take a few; a sed pair for each of the twenty tickets would take 40 more
rigAssert "one pass twenty tickets back starts no sed for each ticket ahead: fewer than 40 in all" "$( [ "$rigPassSeds" -lt 40 ] && printf fewer || printf "$rigPassSeds" )" fewer
rigAssert "and it pauses longer than the 30 s a run near the front pauses: 5 s and 3 s a ticket ahead, up to 90 s" "$rigPause" 65
rigProcSignal TERM "$rigPidB" || : ; rigEnd "$rigPidB"
rigLet a ; rigEnd "$rigPidA"
rigProcSignal TERM $rigAhead || : ; rm -f "$rigQueue"/*.ticket "$rigQueue"/*.ticket.beat

echo "-- 13. a lane is its run's own: another ticket of the holder's session is neither named for it nor kept alive by it --"
## One lane, held by a run of session a. Ahead of the waiter b stand two other tickets of session a, as runs of one session are several runs:
## one that gave its lanes up (a mark beside it), from another copy, and one whose beat stopped two hours ago.
rigFresh ; rigLanes 1 ; rigHold=1 ; rigStallLimit=60
rigRun a ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the run holding the one lane never began, so nothing below would be measured"
sleep 300 & rigPidSib=$! ; rigProcNote "$rigPidSib"
rigSibling="$rigQueue/$(( $( date +%s ) - 600 )).000000.$rigPidSib.ticket"
printf 'session=rig-session-a\norigin=%s\nkind=run\nsince=%s\npid=%s\npstart=%s\n' "$( rigRoot c )" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" "$rigPidSib" \
	"$( ps -o lstart= -p "$rigPidSib" 2> /dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ //;s/ $//' )" > "$rigSibling"
date +%s > "$rigSibling.beat" ; date +%s > "$rigSibling.yield"
sleep 300 & rigPidStale=$! ; rigProcNote "$rigPidStale"
rigStale="$rigQueue/$(( $( date +%s ) - 500 )).000000.$rigPidStale.ticket"
printf 'session=rig-session-a\norigin=%s\nkind=run\nsince=%s\npid=%s\npstart=%s\n' "$( rigRoot n )" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" "$rigPidStale" \
	"$( ps -o lstart= -p "$rigPidStale" 2> /dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ //;s/ $//' )" > "$rigStale"
printf '%s\n' "$(( $( date +%s ) - 7200 ))" > "$rigStale.beat"
rigRun b ; rigPidB=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/b.out" || rigRefuse "the run behind the one lane never said it waits"
rigAwait 'a place given up in the line' "$rigTmp/b.out" 100 || :
rigAssert "the waiter names the run that holds the lane, never another ticket of its session" \
	"$( LC_ALL=C grep 'waits its turn behind' "$rigTmp/b.out" | LC_ALL=C grep -c -F "from $( rigRoot a )," || : ):$( LC_ALL=C grep -c -F "from $( rigRoot c )," "$rigTmp/b.out" || : )" "1:0"
rigAssert "a ticket of the holder's session whose own beat stopped is a place given up, and leaves the line" \
	"$( [ -f "$rigStale" ] && printf kept || printf gone ):$( LC_ALL=C grep -c -F 'a place given up in the line' "$rigTmp/b.out" || : )" "gone:1"
rigLet a ; rigEnd "$rigPidA"
rigUntil 'BEGIN b' "$rigTmp/log" || :
rigLet b ; rigEnd "$rigPidB"
rigAssert "control: the waiter then takes the lane and runs" "$rigRc $( LC_ALL=C grep -c '^END b$' "$rigTmp/log" || : )" "0 1"
rigProcSignal TERM "$rigPidSib" "$rigPidStale" || : ; rm -f "$rigSibling" "$rigSibling.beat" "$rigSibling.yield" "$rigStale" "$rigStale.beat"

echo "-- 15. a ticket past its hold gives the line up, and a lock a finished run left gives lane 1 back --"
## TASK 2026-11-20 17:55Z. Two places stood held by nothing: a head ticket whose run passed its own hold and never took
## a turn, and lane 1, left as a lock by a runner whose run folder held a receipt for every check of its list.
## Each has its control: the same ticket inside its own hold, the same lock whose folder still owes a check, and a lock
## whose holder names no run folder at all. Every control is waited behind, so a line that gave every place up would
## fail here as loudly as one that gave none.
rigStandIn(){ ## -- a process that reads as a live runner, its command line naming the runner; its pid in rigStandInPid
	## one process and no child: the shell execs into the sleep itself, so ending the pid leaves nothing behind
	bash -c 'exec -a rig-stand-in-AgentsRunTests.sh sleep 300' > /dev/null 2>&1 < /dev/null &
	rigStandInPid=$!
	rigStarted="$rigStarted $rigStandInPid"
	rigProcNote "$rigStandInPid"
}
rigOldTicket(){ ## session, seconds ago -- a ticket in the line for that session, naming the live stand-in, joined that long ago
	local oldSince oldFile
	mkdir -p "$rigQueue" || return 1
	oldSince="$( date -u -v-"$2"S '+%Y-%m-%dT%H:%M:%SZ' 2> /dev/null || date -u -r "$(( $( date +%s ) - $2 ))" '+%Y-%m-%dT%H:%M:%SZ' )"
	oldFile="$rigQueue/$( printf '%017d' "$(( $( date +%s ) - $2 ))" ).000000.$rigStandInPid.ticket"
	printf 'session=%s\norigin=%s\nkind=run\nsince=%s\npid=%s\npstart=%s\n' "$1" "$( rigRoot b )" "$oldSince" "$rigStandInPid" \
		"$( ps -o lstart= -p "$rigStandInPid" 2> /dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ //;s/ $//' )" > "$oldFile"
	printf '%s\n' "$( date +%s )" > "$oldFile.beat"
}
rigLockLeft(){ ## receipts, rundir-or-empty, checks-or-empty -- a clean line, a run folder of three checks holding that many receipts, and a lock in the shape a runner writes, held by a live process
	rigFresh ; rigLanes 1 ; rigHoldLimit=86400 ; rigStallLimit=7200 ; rigQueueLimit=8
	mkdir -p "$rigQueue" || return 1
	rigLeftDir="$rigTmp/left-run"
	rm -rf -- "$rigLeftDir"
	mkdir -p "$rigLeftDir"
	printf 'RigTiny1 900\nRigTiny2 900\nRigTiny3 900\n' > "$rigLeftDir/tests.list"
	rigOne=0
	while [ "$rigOne" -lt 3 ] ; do
		rigOne=$(( rigOne + 1 ))
		[ "$1" -lt "$rigOne" ] || printf 'rc=0\nseconds=1\nlast=RIG_TINY: OK\n' > "$rigLeftDir/RigTiny$rigOne.receipt"
	done
	rigStandIn
	mkdir -p "$rigLock"
	printf 'runner-pid: %s\nsession=rig-finished-run\nagent: AgentsRunTests.sh, a run from %s\nlanes: yes\ntaken: %s\n' \
		"$rigStandInPid" "$( rigRoot a )" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$rigLock/holder.txt"
	[ -z "${3:-}" ] || printf 'checks=%s\n' "$3" >> "$rigLock/holder.txt"
	[ -z "${2:-}" ] || printf 'rundir=%s\n' "$2" >> "$rigLock/holder.txt"
}

## 15a. A TICKET PAST ITS HOLD IS GIVEN UP however alive its process is, and the run behind it goes on.
rigFresh ; rigLanes 1 ; rigHoldLimit=600 ; rigStallLimit=7200
rigStandIn ; rigOldTicket rig-session-old 7200
rigRun a RigTiny ; rigEnd "$rigLast"
rigAssert "a ticket 7,200s old, its process alive, past a hold of 600s: the run behind it goes on, says the place was given up, and leaves the line empty" \
	"$rigRc $( LC_ALL=C grep -c -F -- 'a place given up in the line' "$rigTmp/a.out" || : ) $( rigTickets ) $( rigOrder )" "0 1 0 BEGIN a END a"
rigFresh ; rigLanes 1 ; rigHoldLimit=86400 ; rigStallLimit=7200 ; rigQueueLimit=8
rigStandIn ; rigOldTicket rig-session-old 7200
rigRun a RigTiny ; rigEnd "$rigLast"
rigAssert "control: with the hold longer than that ticket is old, the run waits behind it, says so, and is refused at its own bound having run nothing" \
	"$rigRc [$( rigOrder )] $( rigWaits a )" "1 [] 1"

## 15b. A LOCK A FINISHED RUN LEFT GIVES LANE 1 BACK, and a lock names the run folder it is judged by.
rigFresh ; rigLanes 1 ; rigHold=1
rigRun a RigTiny ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the run that takes lane 1 never began, so the lock it writes below would be nobody's"
rigLockDir="$( LC_ALL=C sed -n 's/^rundir=//p' "$rigLock/holder.txt" 2> /dev/null | LC_ALL=C sed -n 1p )"
rigAssert "a run holding lane 1 writes its run folder on the lock, so a lock it leaves behind is judged by its own checks" \
	"$( [ -n "$rigLockDir" ] && [ -f "$rigLockDir/tests.list" ] && printf named || printf absent )" named
rigLet a ; rigEnd "$rigPidA" ; rigHold=""
rigLockLeft 3 "$rigTmp/left-run" 3
rigRun a RigTiny ; rigEnd "$rigLast"
rigAssert "a lock whose own record names 3 checks, its folder holding a receipt for all 3: the run behind it goes on without a word of waiting" \
	"$rigRc $( rigWaits a ) $( rigOrder )" "0 0 BEGIN a END a"
rigAssert "and the line says it gave lane 1 back, naming the session that left the lock and the folder with its checks" \
	"$( LC_ALL=C grep -c -F -- "gave lane 1 back: the run that left the lock, session rig-finished-run, is past its last check -- its run folder $rigTmp/left-run holds a receipt for all 3 of its checks" "$rigTmp/a.out" || : )" 1
rigAssert "and the lock is gone, so lane 1 stands open again" "$( [ -d "$rigLock" ] && printf held || printf free )" free
rigLockLeft 3 "$rigTmp/left-run"
rigRun a RigTiny ; rigEnd "$rigLast"
rigAssert "the same folder judged by its list where the record names no count: the run behind it goes on too" \
	"$rigRc $( rigWaits a ) $( rigOrder )" "0 0 BEGIN a END a"
rigLockLeft 2 "$rigTmp/left-run" 3
rigRun a RigTiny ; rigEnd "$rigLast"
rigAssert "control: a record naming 3 checks whose folder owes one of them holds the lane, and the run behind it waits and is refused at its own bound" \
	"$rigRc [$( rigOrder )] $( rigWaits a ) $( [ -d "$rigLock" ] && printf held || printf free ) $( LC_ALL=C grep -c -F -- 'gave lane 1 back' "$rigTmp/a.out" || : )" "1 [] 1 held 0"
rigLockLeft 3 "" 3
rigRun a RigTiny ; rigEnd "$rigLast"
rigAssert "control: a lock whose holder names no run folder keeps the lane, since nothing states its run has finished" \
	"$rigRc [$( rigOrder )] $( rigWaits a ) $( [ -d "$rigLock" ] && printf held || printf free )" "1 [] 1 held"

## 15c. THE FIRST CASE ON TWO LANES: a finished run's lock freed while its own ticket still stands at the head. A waiter that
## took the free lane must not also wait behind the ticket of the run whose lane it just took.
rigLockLeft 3 "$rigTmp/left-run" 3
rigLanes 2
## the ticket names the very process the lock names, as a run's lock and its ticket do
rigLeftLocked="$( LC_ALL=C sed -n 's/^runner-pid: //p' "$rigLock/holder.txt" 2>/dev/null | LC_ALL=C sed -n 1p )"
printf 'session=rig-finished-run\norigin=%s\nkind=run\nsince=%s\npid=%s\npstart=%s\nrundir=%s\n' \
	"$( rigRoot a )" "$( date -u -v-50M '+%Y-%m-%dT%H:%M:%SZ' )" "$rigLeftLocked" \
	"$( ps -o lstart= -p "$rigLeftLocked" 2> /dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ //;s/ $//' )" "$rigTmp/left-run" \
	> "$rigQueue/$( printf '%017d' "$(( $( date +%s ) - 3000 ))" ).000000.$rigLeftLocked.ticket"
date +%s > "$rigQueue/$( printf '%017d' "$(( $( date +%s ) - 3000 ))" ).000000.$rigLeftLocked.ticket.beat"
rigRun a RigTiny ; rigEnd "$rigLast"
rigAssert "a finished run's lock freed while its own ticket stands at the head, with a lane free: it says it gave the lane back, the waiter takes that lane and runs, and it does not wait behind the ticket" \
	"$rigRc $( LC_ALL=C grep -c -F -- 'gave lane 1 back' "$rigTmp/a.out" || : ) $( rigWaits a ) $( rigOrder )" "0 1 0 BEGIN a END a"
rigAssert "and that run's ticket goes with its lane, so nothing behind it waits for a turn that never comes" \
	"$( ls "$rigQueue" 2> /dev/null | LC_ALL=C grep -F "$rigLeftLocked" | LC_ALL=C grep -c '\.ticket$' || : )" 0
rigHoldLimit="" ; rigStallLimit="" ; rigQueueLimit=""

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS QUEUE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_QUEUE: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
