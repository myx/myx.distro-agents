#!/usr/bin/env bash
## Behavioural check on the line full suites stand in (sh-test/AgentsRunTests.sh), run rather than read, on a fixture
## machine built here: a HOME, whose .agents/magic-team/suite-queue is the machine's one line, a workspace, and under
## its .local/temp several copies of a package, each a build session's scratch with the runner under test and one tiny
## test in it. Held: a run of every test waits its turn in arrival order, whichever copy it is started from, and says
## in one line whom it waits behind; a run of named tests is not queued; a ticket whose runner no longer exists is taken
## out by whoever waits behind it; and the hand rule's lock ($MMDAPP/.local/temp/suite-run.lock) is kept by both sides:
## a run at its turn holds it, waits while another holds it by hand and never removes that one, starts under one held
## by its own caller only when its own turn has come and is refused before that, and removes one left by a runner that
## is gone. And the one budget of test workers, $HOME/.agents/magic-team/suite-workers, that every runner shares, full
## or named: the tests running at once on the machine never pass it, slots go in the order they were asked for so a
## named run is not starved by a full suite, a slot whose process is gone comes back by itself, a runner says in one
## line that a test of its waits and how many slots are in use, and every test runs at a lowered priority. The hand
## rule the budget replaces ($MMDAPP/.local/temp/one-test-run.lock, an `owner` file naming a scratch folder) is honoured
## while a session still holds it: no test starts beside it, unless it is the run's own caller's. Nothing here is told by how
## long a run takes: a suite that must still be running when another is started runs until the rig lets it end, so the
## order of what happened is the rig's own, on a busy host as on an idle one. What the rig cannot show: nine real
## sessions at once, and a real suite's length.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigRunner="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its tests with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
rigTmp="$( mktemp -d -t AgentsRunTestsQueueCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'for rigLeft in $rigStarted ; do kill "$rigLeft" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home" ; rigWs="$rigTmp/ws"
rigQueue="$rigHome/.agents/magic-team/suite-queue"
rigWorkers="$rigHome/.agents/magic-team/suite-workers"
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
	cat > "$packageTests/RigTiny.test.sh" <<'RIGTINY'
#!/usr/bin/env bash
rigTinyId="${0##*/RigTiny}" ; rigTinyId="${rigTinyId%.test.sh}"
RIG_SUITE="$RIG_SUITE${rigTinyId:+.$rigTinyId}"
printf 'BEGIN %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
printf 'NICE %s %s\n' "$RIG_SUITE" "$( ps -o nice= -p $$ 2> /dev/null | LC_ALL=C tr -d ' ' )" >> "$RIG_SHARED/log"
printf 'HELD %s lock=%s line=%s\n' "$RIG_SUITE" \
	"$( LC_ALL=C sed -n 's/^runner-pid: //p' "$MMDAPP/.local/temp/suite-run.lock/holder.txt" 2> /dev/null | LC_ALL=C sed -n 1p )" \
	"$( ls "$HOME/.agents/magic-team/suite-queue" 2> /dev/null | LC_ALL=C sed -n 's/^[0-9.]*\.\([0-9]*\)\.ticket$/\1/p' | LC_ALL=C tr '\n' ' ' )" >> "$RIG_SHARED/log"
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
rigRun(){ ## session, runner args... -- that session's runner, started in the background from its own copy; its output in <session>.out. With rigHold set, its test ends only at rigLet <session>
	( cd "$rigWs" && exec env -i HOME="${rigHomeFor:-$rigHome}" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$( rigRoot "$1" )" MYXROOT="${MYXROOT:-}" RIG_SHARED="$rigTmp" RIG_SUITE="$1" RIG_HOLD="$rigHold" \
		bash "$( rigRoot "$1" )/myx/myx.distro-agents/sh-test/AgentsRunTests.sh" "${@:2}" ) > "$rigTmp/$1.out" 2>&1 &
	rigLast=$!
	rigStarted="$rigStarted $rigLast"
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
rigHeld(){ ## session -- what its test found while it ran: the lock's runner, then the pids standing in the line
	LC_ALL=C sed -n "s/^HELD $1 //p" "$rigTmp/log" | LC_ALL=C sed -n 1p
}
rigDeadPid(){ ## -- the pid of a process that has ended
	( exit 0 ) & local deadPid=$! ; wait "$deadPid" 2> /dev/null ; printf '%s\n' "$deadPid"
}
rigFresh(){ ## -- a clean line, no lock, no slot taken and no budget set, an empty log, nothing held or let go
	rm -rf "$rigQueue" "$rigLock" "$rigTestLock" "$rigWorkers" ; : > "$rigTmp/log" ; rm -f "$rigTmp"/*.out "$rigTmp"/let.* ; rigHold=""
}
rigBudget(){ ## number -- the machine's budget of test workers set to it
	mkdir -p "$rigWorkers" && printf '%s\n' "$1" > "$rigWorkers/budget"
}
rigSlots(){ ## kind (H: held, W: asked for) -- how many the slot state lists
	LC_ALL=C grep -c "^$1 " "$rigWorkers/state" 2> /dev/null || :
}
rigBegun(){ ## -- the tests that have begun and not ended, by the shared log, space separated
	LC_ALL=C awk '$1 == "BEGIN" { on[$2] = 1 ; order[++n] = $2 } $1 == "END" { delete on[$2] } END { for ( i = 1 ; i <= n ; i++ ) if ( order[i] in on ) printf "%s ", order[i] }' "$rigTmp/log"
}
rigMostAtOnce(){ ## -- the most tests that were running at one time, by the shared log
	LC_ALL=C awk '$1 == "BEGIN" { n++ ; if ( n > most ) most = n } $1 == "END" { n-- } END { print most + 0 }' "$rigTmp/log"
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
rigAssert "while it ran, the hand rule's lock was held by its own runner, and it alone stood in the line" "$( [ -n "$rigRunnerPid" ] && printf held || printf not-held ) [$( rigHeld a )]" "held [lock=$rigRunnerPid line=$rigRunnerPid ]"
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
rigUntil 'rig-scratch-b/source, in line since' "$rigTmp/c.out" || :
rigAssert "the first ended, the second began, and the third still waits, now behind the second" "$( rigOrder ) $( rigTickets )" "BEGIN a END a BEGIN b 2"
rigLet b ; rigEnd "$rigPidB" ; rigRcB=$rigRc
rigLet c ; rigEnd "$rigPidC" ; rigRcC=$rigRc
rigAssert "all three ran" "$rigRcA $rigRcB $rigRcC" "0 0 0"
rigAssert "one at a time and in arrival order: each began only after the one before it had ended" "$( rigOrder )" "BEGIN a END a BEGIN b END b BEGIN c END c"
rigAssert "the second said, in one line, that it waits and behind whom: the first, by its pid, the copy it runs from and since when" "$( rigWaits b ) $( LC_ALL=C grep -c -F -- "# AgentsRunTests.sh: one full suite runs on this machine at a time -- this one waits its turn behind the run of pid $rigTicketA from $( rigRoot a ), in line since " "$rigTmp/b.out" || : )" "1 1"
rigAssert "the third said it once for each it waited behind in turn: the first, then the second" "$( rigWaits c ) $( LC_ALL=C grep -F -- 'waits its turn behind' "$rigTmp/c.out" | LC_ALL=C sed -e 's/.* from //' -e 's/, in line since.*//' -e "s|$rigWs/.local/temp/||" | LC_ALL=C tr '\n' ' ' )" "2 rig-scratch-a/source rig-scratch-b/source "
rigAssert "each held the lock itself while it ran" "$( rigHeld b | LC_ALL=C sed -n 's/^lock=\([0-9]*\) line=\1 .*/own/p' ) $( rigHeld c | LC_ALL=C sed -n 's/^lock=\([0-9]*\) line=\1 $/own/p' )" "own own"
rigAssert "and the line and the lock are free again" "$( rigTickets ) $( [ -d "$rigLock" ] && printf held || printf free )" "0 free"

echo "-- 3. a run of named tests is not queued --"
rigFresh ; rigHold=1
rigRun a ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the full suite never began, so nothing below would be measured"
rigHold=""
rigRun n RigTiny ; rigEnd "$rigLast"
rigAssert "it ran while the full suite was still running: begun and ended inside it" "$rigRc $( rigOrder )" "0 BEGIN a BEGIN n END n"
rigAssert "it said nothing of waiting, stood in no line, and the lock stayed the full suite's" "$( rigWaits n ) $( rigHeld n | LC_ALL=C sed -n 's/^lock=\([0-9]*\) line=\1 $/the-full-suite-alone/p' )" "0 the-full-suite-alone"
rigLet a ; rigEnd "$rigPidA"
rigAssert "and the full suite ended as it would have" "$rigRc $( rigTickets ) $( [ -d "$rigLock" ] && printf held || printf free )" "0 0 free"

echo "-- 4. a turn held by a process that no longer exists is released by itself --"
rigFresh
mkdir -p "$rigQueue"
rigDead="$( rigDeadPid )"
sleep 60 & rigOther=$! ; rigStarted="$rigStarted $rigOther"
printf 'pid=%s\norigin=%s\nsince=2026-01-01T00:00:00Z\n' "$rigDead" "$( rigRoot b )" > "$rigQueue/0000000001.000000.$rigDead.ticket"
printf 'pid=%s\norigin=%s\nsince=2026-01-01T00:00:01Z\n' "$rigOther" "$( rigRoot c )" > "$rigQueue/0000000002.000000.$rigOther.ticket"
: > "$rigQueue/0000000003.000000.7.ticket"
rigRun a ; rigEnd "$rigLast"
rigAssert "tickets ahead whose runner is gone, is a process that is no runner, or was never written whole: the suite runs at once, saying nothing of waiting" "$rigRc $( rigWaits a ) $( rigOrder )" "0 0 BEGIN a END a"
rigAssert "and they are taken out of the line" "$( rigTickets )" 0
kill "$rigOther" 2> /dev/null ; wait "$rigOther" 2> /dev/null
mkdir -p "$rigLock" ; printf 'runner-pid: %s\nagent: AgentsRunTests.sh, a full suite from %s\ntaken: 2026-01-01T00:00:00Z\n' "$rigDead" "$( rigRoot b )" > "$rigLock/holder.txt"
: > "$rigTmp/log"
rigRun a ; rigEnd "$rigLast"
rigAssert "the lock left by a runner that is gone is released too: the suite runs at once, and gives its own lock back" "$rigRc $( rigWaits a ) $( rigOrder ) $( [ -d "$rigLock" ] && printf held || printf free )" "0 0 BEGIN a END a free"

echo "-- 5. the hand rule's lock is kept by both sides --"
rigFresh
mkdir -p "$rigLock" ; printf 'agent: rig-scratch-other (a session on the hand rule)\ntaken: 2026-01-01T00:00:00Z\n' > "$rigLock/holder.txt"
rigRun a ; rigPidA=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/a.out" || :
sleep 3
rigAssert "a lock another session holds by hand: the suite waits, begins nothing, and says behind whom, the lock by its path and its holder's own note" "$( rigOrder ) $( LC_ALL=C grep -c -F -- "this one waits its turn behind the lock $rigLock, taken by hand and held by: agent: rig-scratch-other (a session on the hand rule) taken: 2026-01-01T00:00:00Z -- where that was done for this very run, remove it: the run takes the turn itself" "$rigTmp/a.out" || : )" " 1"
rigAssert "it never removes a lock taken by hand, however long it waits" "$( [ -d "$rigLock" ] && printf held || printf free ) $( LC_ALL=C grep -c 'rig-scratch-other' "$rigLock/holder.txt" 2> /dev/null || : )" "held 1"
rigTicketA="$( ls "$rigQueue" | LC_ALL=C sed -n 's/^[0-9.]*\.\([0-9]*\)\.ticket$/\1/p' | LC_ALL=C sed -n 1p )"
rm -rf "$rigLock"
rigEnd "$rigPidA"
rigAssert "accepted sibling: once that session removes its lock, the suite takes its turn, holding the lock itself, and gives it back" "$rigRc $( rigOrder ) [$( rigHeld a )] $( [ -d "$rigLock" ] && printf held || printf free )" "0 BEGIN a END a [lock=$rigTicketA line=$rigTicketA ] free"
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
rigTicketB="$( ls "$rigQueue" | LC_ALL=C sed -n 's/^[0-9.]*\.\([0-9]*\)\.ticket$/\1/p' | LC_ALL=C sed -n 1p )"
kill -TERM "$rigTicketB" 2> /dev/null ; rigEnd "$rigPidB"
rigAssert "a waiting run that is told to end leaves the line, and leaves the lock that is not its own" "$( rigTickets ) $( [ -d "$rigLock" ] && printf held || printf free ) $( rigOrder )" "0 held "
## A lock taken by hand is no turn. Two runs wait in the line behind a lock a third session holds by hand; that
## session's own run arrives behind them.
rigFresh
mkdir -p "$rigLock" ; printf 'agent: rig-scratch-c (a session that took the lock by hand, ahead of the line)\ntaken: 2026-01-01T00:00:00Z\n' > "$rigLock/holder.txt"
rigRun a ; rigPidA=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/a.out" || rigRefuse "the first waiting run never said it waits, so the line below would be empty"
rigRun b ; rigPidB=$rigLast
rigUntil 'waits its turn behind' "$rigTmp/b.out" || rigRefuse "the second waiting run never said it waits, so the line below would be shorter"
rigTicketA="$( ls "$rigQueue" | LC_ALL=C sed -n 1p | LC_ALL=C sed -n 's/^[0-9.]*\.\([0-9]*\)\.ticket$/\1/p' )"
rigRun c ; rigEnd "$rigLast"
rigAssert "the run of the caller that holds the lock by hand is refused while others stand ahead of it: rc 1, nothing begun, and its one line says why, how many are ahead, who is first, and what to do" "$rigRc [$( rigOrder )] $( LC_ALL=C grep -c -F -- "⛔ ERROR: AgentsRunTests.sh: not started: this run's caller holds $rigLock by hand, and its turn in the machine's line has not come: 2 full suite(s) stand ahead of it, the first the run of pid $rigTicketA from $( rigRoot a ), in line since " "$rigTmp/c.out" || : ) $( LC_ALL=C grep -c -F -- 'A lock taken by hand is no turn. Remove it and run again: the run waits its turn by itself, and takes the lock itself when that comes.' "$rigTmp/c.out" || : )" "1 [] 1 1"
rigAssert "it left the line, the two ahead of it still stand there, and the lock is left as it was" "$( rigTickets ) $( [ -d "$rigLock" ] && printf held || printf free ) $( LC_ALL=C grep -c 'rig-scratch-c' "$rigLock/holder.txt" 2> /dev/null || : )" "2 held 1"
rm -rf "$rigLock"
rigEnd "$rigPidA" ; rigRcA=$rigRc ; rigEnd "$rigPidB"
rigAssert "accepted sibling: with that lock removed, the two that waited run in the order they arrived" "$rigRcA $rigRc $( rigOrder )" "0 0 BEGIN a END a BEGIN b END b"

echo "-- 6. no line, no full suite --"
rigFresh
: > "$rigTmp/not-a-directory"
rigHomeFor="$rigTmp/not-a-directory"
rigRun a ; rigEnd "$rigLast"
rigAssert "where the machine's line cannot be made, a full suite is refused rather than run outside its turn: rc 1, nothing begun, the place named" "$rigRc $( rigOrder ) $( LC_ALL=C grep -c -F -- "⛔ ERROR: AgentsRunTests.sh: cannot create the machine's line for full suites: $rigTmp/not-a-directory/.agents/magic-team/suite-queue" "$rigTmp/a.out" || : )" "1  1"
rigRun n RigTiny ; rigEnd "$rigLast"
rigAssert "nor is a run of named tests run outside the machine's budget of test workers, where that cannot be reached: rc 1, nothing begun, the place named" "$rigRc [$( rigOrder )] $( LC_ALL=C grep -c -F -- "⛔ ERROR: AgentsRunTests.sh: cannot use the machine's budget of test workers: $rigTmp/not-a-directory/.agents/magic-team/suite-workers -- no test is run outside it" "$rigTmp/n.out" || : )" "1 [] 1"
rigHomeFor=""
rigRun n RigTiny ; rigEnd "$rigLast"
rigAssert "accepted sibling: with the machine's own directory there, the same named run runs at once, in no line" "$rigRc $( rigOrder ) $( rigWaits n ) $( rigTickets )" "0 BEGIN n END n 0 0"

echo "-- 7. one budget of test workers for the whole machine, shared by every runner --"
## Two runs of named tests, three tests each, from two copies, every test held until the rig lets it end; the budget is 2.
rigFresh ; rigBudget 2 ; rigHold=1
rigRun p RigTiny ; rigPidP=$rigLast
rigRun q RigTiny ; rigPidQ=$rigLast
rigUntilBegun 2 || rigRefuse "two tests never began under a budget of two, so nothing below would be measured"
rigUntil 'a test waits for a worker slot' "$rigTmp/p.out" || rigRefuse "the first run never said a test of its waits"
rigUntil 'a test waits for a worker slot' "$rigTmp/q.out" || rigRefuse "the second run never said a test of its waits"
rigAssert "two runners together hold the budget and no more: two tests begun, two slots held, the other four asked for and waiting" "$( rigBegun | LC_ALL=C wc -w | LC_ALL=C tr -d ' ' ) $( rigSlots H ) $( rigSlots W )" "2 2 4"
rigAssert "each runner said so in one line: a test of its waits, and how many slots are in use, of how many" "$( rigSlotWaits p ) $( rigSlotWaits q ) $( LC_ALL=C grep -h -F -- 'a test waits for a worker slot' "$rigTmp/p.out" "$rigTmp/q.out" | LC_ALL=C sort -u | LC_ALL=C sed "s|$rigWorkers|<the budget>|" )" "1 1 # AgentsRunTests.sh: a test waits for a worker slot: 2 of 2 in use on this machine, the one budget every runner shares (<the budget>)"
rigAssert "neither is a full suite, so neither stands in the line for those, and nobody holds its lock" "$( rigTickets ) $( [ -d "$rigLock" ] && printf held || printf free )" "0 free"
rigAssert "started in the same second or not, each run has a folder of its own for its list and its logs" "$( LC_ALL=C sed -n 's/.*run folder: //p' "$rigTmp/p.out" "$rigTmp/q.out" | LC_ALL=C sort -u | LC_ALL=C grep -c . || : )" 2
## each test let go in turn, whichever is running, until all six have ended
rigEndedWant=0
while [ "$rigEndedWant" -lt 6 ] ; do
	for rigRunningTest in $( rigBegun ) ; do rigLet "$rigRunningTest" ; done
	rigEndedWant=$(( rigEndedWant + 1 ))
	rigUntilEnded "$rigEndedWant" || rigRefuse "a held test never ended once let go"
done
rigEnd "$rigPidP" ; rigRcP=$rigRc ; rigEnd "$rigPidQ"
rigAssert "all six ran, and at no time were more than the budget running at once" "$rigRcP $rigRc $( LC_ALL=C grep -c '^END ' "$rigTmp/log" ) $( rigMostAtOnce )" "0 0 6 2"
rigAssert "every slot was given back" "$( rigSlots H ) $( rigSlots W )" "0 0"
rigAssert "every test ran at a lowered priority, nice 10 or lower still" "$( LC_ALL=C awk '$1 == "NICE" { n++ ; if ( $3 + 0 < 10 ) bad++ } END { printf "%d %d", n, bad }' "$rigTmp/log" )" "6 0"
## A slot whose process is gone comes back by itself: a holder that never ran here, then one that was killed with its runner.
rigFresh ; rigBudget 1
rigDead="$( rigDeadPid )"
mkdir -p "$rigWorkers" ; printf 'H %s\n' "$rigDead" > "$rigWorkers/state"
rigRun n RigTiny ; rigEnd "$rigLast"
rigAssert "the one slot listed for a process that no longer exists: a test takes it at once, and nobody is told to wait" "$rigRc $( rigOrder ) $( rigSlotWaits n )" "0 BEGIN n END n 0"
rigFresh ; rigBudget 1 ; rigHold=1
rigRun a RigTiny ; rigPidA=$rigLast
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the test that was to be killed never began"
rigSlotPid="$( LC_ALL=C sed -n 's/^H //p' "$rigWorkers/state" | LC_ALL=C sed -n 1p )"
## first whoever would give the slot back, the runner's own process that waits for the test, then the test itself
rigSlotGiver="$( ps -o ppid= -p "$rigSlotPid" 2> /dev/null | LC_ALL=C tr -d ' ' )"
kill -KILL "$rigSlotGiver" "$rigPidA" 2> /dev/null ; kill -KILL "$rigSlotPid" 2> /dev/null ; wait "$rigPidA" 2> /dev/null
rigKilledLeft=50 ; while kill -0 "$rigSlotPid" 2> /dev/null && [ "$rigKilledLeft" -gt 0 ] ; do sleep 0.2 ; rigKilledLeft=$(( rigKilledLeft - 1 )) ; done
rigAssert "control: the killed test's slot is still listed, since nobody was left to give it back" "$( LC_ALL=C grep -c "^H $rigSlotPid\$" "$rigWorkers/state" || : )" 1
rigHold=""
rigRun n RigTiny ; rigEnd "$rigLast"
rigAssert "the next test to ask takes it all the same, and the dead holder is gone from the list" "$rigRc $( rigOrder ) $( LC_ALL=C grep -c "^H $rigSlotPid\$" "$rigWorkers/state" || : )" "0 BEGIN a BEGIN n END n 0"
## A run of named tests is not starved by a full suite: slots go in the order they were asked for. Budget 1; a full
## suite of three tests on two workers has one test running and one waiting when the named run's test asks.
rigFresh ; rigBudget 1 ; rigHold=1
rigRun p -w 2 ; rigPidP=$rigLast
rigUntilBegun 1 || rigRefuse "the full suite's first test never began"
rigUntil 'a test waits for a worker slot' "$rigTmp/p.out" || rigRefuse "the full suite's second test never asked for a slot"
rigHold=""
rigRun n RigTiny ; rigPidN=$rigLast
rigUntil 'a test waits for a worker slot' "$rigTmp/n.out" || rigRefuse "the named run's test never asked for a slot"
rigAssert "a named run starts at once beside a full suite, in no line, and its test waits for a slot as any test does: one held, two asked for" "$( rigTickets ) $( rigSlots H ) $( rigSlots W ) $( rigWaits n )" "1 1 2 0"
for rigRunningTest in $( rigBegun ) ; do rigLet "$rigRunningTest" ; done
rigUntilBegun 2 || rigRefuse "the full suite's waiting test never began"
for rigRunningTest in $( rigBegun ) ; do rigLet "$rigRunningTest" ; done
rigEnd "$rigPidN" ; rigRcN=$rigRc
rigUntilBegun 4 || rigRefuse "the full suite's last test never began"
for rigRunningTest in $( rigBegun ) ; do rigLet "$rigRunningTest" ; done
rigEnd "$rigPidP"
rigAssert "the slot goes to the suite's test that asked first, then to the named run's, and only then to the suite's next: the named run is not left behind every test of the suite" "$rigRcN $rigRc $( LC_ALL=C sed -n 's/^BEGIN \([a-z]\).*/\1/p' "$rigTmp/log" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' ) $( rigMostAtOnce )" "0 0 p p n p 1"
## The budget where none is set: half the machine's cores. That many slots held by live processes leave none.
rigFresh
rigCores="$( sysctl -n hw.ncpu 2> /dev/null || getconf _NPROCESSORS_ONLN 2> /dev/null || echo 2 )"
rigHalf=$(( rigCores / 2 )) ; [ "$rigHalf" -ge 1 ] || rigHalf=1
mkdir -p "$rigWorkers" ; : > "$rigWorkers/state" ; rigHolders=""
for (( rigHolder = 1 ; rigHolder <= rigHalf ; rigHolder++ )) ; do
	sleep 600 & rigHolders="$rigHolders $!" ; rigStarted="$rigStarted $!" ; printf 'H %s\n' "$!" >> "$rigWorkers/state"
done
rigRun n RigTiny ; rigPidN=$rigLast
rigUntil 'a test waits for a worker slot' "$rigTmp/n.out" || rigRefuse "with every slot of the default budget held, the test never said it waits"
rigAssert "with no budget set it is half the machine's cores: that many held, and a test waits, saying so" "[$( rigOrder )] $( LC_ALL=C grep -c -F -- "a test waits for a worker slot: $rigHalf of $rigHalf in use on this machine" "$rigTmp/n.out" || : )" "[] 1"
kill ${rigHolders%% [0-9]*} 2> /dev/null ; kill $rigHolders 2> /dev/null
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

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS QUEUE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_QUEUE: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
