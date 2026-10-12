#!/usr/bin/env bash
## Behavioural check on the line full suites stand in (sh-test/AgentsRunTests.sh), run rather than read, on a fixture
## machine built here: a HOME, whose .agents/magic-team/suite-queue is the machine's one line, a workspace, and under
## its .local/temp several copies of a package, each a build session's scratch with the runner under test and one tiny
## test in it. Held: a run of every test waits its turn in arrival order, whichever copy it is started from, and says
## in one line whom it waits behind; a run of named tests is not queued; a ticket whose runner no longer exists is taken
## out by whoever waits behind it; and the hand rule's lock ($MMDAPP/.local/temp/suite-run.lock) is kept by both sides:
## a run at its turn holds it, waits while another holds it by hand and never removes that one, takes one held by its
## own caller as its turn and leaves it, and removes one left by a runner that is gone. Nothing here is told by how
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
rigLock="$rigWs/.local/temp/suite-run.lock"
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
rigRoot(){ ## session -- the source root of that session's copy of the package
	printf '%s\n' "$rigWs/.local/temp/rig-scratch-$1/source"
}
rigPackage(){ ## session -- that copy: the runner under test, and one tiny test, which says in the shared log when it begins and ends, and what it found the line and the lock holding while it ran; held (RIG_HOLD), it ends only once the rig lets it (rigLet)
	local packageTests ; packageTests="$( rigRoot "$1" )/myx/myx.distro-agents/sh-test"
	mkdir -p "$packageTests"
	cp "$rigRunner" "$packageTests/AgentsRunTests.sh"
	cat > "$packageTests/RigTiny.test.sh" <<'RIGTINY'
#!/usr/bin/env bash
printf 'BEGIN %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
printf 'HELD %s lock=%s line=%s\n' "$RIG_SUITE" \
	"$( LC_ALL=C sed -n 's/^runner-pid: //p' "$MMDAPP/.local/temp/suite-run.lock/holder.txt" 2> /dev/null | LC_ALL=C sed -n 1p )" \
	"$( ls "$HOME/.agents/magic-team/suite-queue" 2> /dev/null | LC_ALL=C sed -n 's/^[0-9.]*\.\([0-9]*\)\.ticket$/\1/p' | LC_ALL=C tr '\n' ' ' )" >> "$RIG_SHARED/log"
rigHeldFor=600
while [ -n "${RIG_HOLD:-}" ] && [ ! -e "$RIG_SHARED/let.$RIG_SUITE" ] && [ "$rigHeldFor" -gt 0 ] ; do sleep 0.2 ; rigHeldFor=$(( rigHeldFor - 1 )) ; done
printf 'END %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
echo "RIG_TINY: OK"
RIGTINY
}
for rigSession in a b c n ; do rigPackage "$rigSession" ; done

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
rigFresh(){ ## -- a clean line, no lock, an empty log, nothing held or let go
	rm -rf "$rigQueue" "$rigLock" ; : > "$rigTmp/log" ; rm -f "$rigTmp"/*.out "$rigTmp"/let.* ; rigHold=""
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

echo "-- 6. no line, no full suite --"
rigFresh
: > "$rigTmp/not-a-directory"
rigHomeFor="$rigTmp/not-a-directory"
rigRun a ; rigEnd "$rigLast"
rigAssert "where the machine's line cannot be made, a full suite is refused rather than run outside its turn: rc 1, nothing begun, the place named" "$rigRc $( rigOrder ) $( LC_ALL=C grep -c -F -- "⛔ ERROR: AgentsRunTests.sh: cannot create the machine's line for full suites: $rigTmp/not-a-directory/.agents/magic-team/suite-queue" "$rigTmp/a.out" || : )" "1  1"
rigRun n RigTiny ; rigEnd "$rigLast"
rigAssert "accepted sibling: a run of named tests needs no line, and runs" "$rigRc $( rigOrder )" "0 BEGIN n END n"
rigHomeFor=""

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS QUEUE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_QUEUE: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
