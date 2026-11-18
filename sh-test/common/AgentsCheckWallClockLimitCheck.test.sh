#!/usr/bin/env bash
## Behavioural check on S12.14's second half: every check run has a wall-clock limit, and the machine's line has it too.
## The gap measured on 2026-11-05: a check started by hand, `bash <check>.test.sh`, takes its turn in the machine's line and holds it for as
## long as it likes. The runner's own `-t` covers only the tests a run starts. So a check that stands still holds the line for ever.
## Held:
##   1. A HAND-STARTED CHECK IS BOUNDED: the turn sets a limit for the check it was called by, and that limit is the run's own
##      (MDAT_SUITE_CHECK_LIMIT_SECONDS, default 900) counted from the moment the turn was taken.
##   2. THAT LIMIT IS A REAL NUMBER the check can act on, and it is one the same call can report, so a check that is close to it can say so.
##   3. A RUN'S OWN TURN IS NOT BOUNDED TWICE: a check inside a run takes no ticket of its own, and gets no limit of its own either, because the
##      run's own `-t` and its stall watch already cover it.
##   4. A CHECK THAT OVERRUNS IS ENDED AT ITS LIMIT, with the processes it started, and says so. A check that waited in the line is given its
##      whole limit from the turn it won, never what is left of a limit counted from when it was started, and it leaves no process behind.
## INSIDE A RUN, ROWS 1, 2 AND 4 ARE SKIPPED, and said to be skipped, never passed: they measure a check started by hand, and a run's own `-t`
## bounds this check instead. Row 3 is the row about a run, and it runs there.
## The real rig-temp fixture runs, over a rig of its own with a private HOME, so the machine's line is left alone. Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" ] || rigRefuse "the rig-temp fixture is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing"
mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/agent-check-limit.XXXXXX" )" || exit 1
trap 'rigProcSignalWithChildren TERM $rigStarted 2> /dev/null ; type rigCheckWatchEnd > /dev/null 2>&1 && rigCheckWatchEnd ; rm -rf -- "$rigTmp"' EXIT
rigStarted=""
HOME="$rigTmp/home" ; export HOME
mkdir -p "$HOME" "$rigTmp/ws/.local/agents" || exit 1
MMDAPP="$rigTmp/ws" ; export MMDAPP
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig-temp fixture would not load"
## WHICH ROWS THIS RUN MEASURES. The runner exports its own turn (MDAT_SUITE_QUEUE_TURN) into every test it starts, so its presence is the one
## signal that this is a check inside a run. The hand-started rows measure the opposite case and are skipped there, each said to be skipped.
rigInRun=""
[ -z "${MDAT_SUITE_QUEUE_TURN:-}" ] || rigInRun=1
rigSkipCount=0
rigSkip(){ ## what is skipped, and why -- said, never counted as a pass
	rigSkipCount=$(( rigSkipCount + 1 ))
	printf '  SKIP  %s\n        why:  %s\n' "$1" "$2"
}
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}

if [ -n "$rigInRun" ] ; then
	rigSkip "the hand-started check's limit (rows 1 and 2)" "this check runs inside a run, whose own -t and stall watch bound it"
else
echo "-- 1. a hand-started check is bounded --"
rigDirOut="$( rigTempDir AgentsScheduleWallClockCheck )" || rigRefuse "the rig's folder could not be made"
rigDeadlineWord="none"
case "$( rigCheckSecondsLeft )" in
	''|*[!0123456789]*) ;;
	*) rigDeadlineWord="set" ;;
esac
rigAssert "the check's turn comes with a deadline, set from MDAT_SUITE_CHECK_LIMIT_SECONDS" "$rigDeadlineWord" "set"
rigLeft="$( rigCheckSecondsLeft )"
rigAssert "and that deadline is the limit ahead of the check, within a minute of it" \
	"$(( rigLeft > 840 && rigLeft <= 900 ))" "1"

echo "-- 2. the deadline is the number the check acts on --"
rigSecondsNow="$( rigCheckSecondsLeft )"
rigAssert "a check may read the seconds it has left, and they count down" \
	"$(( rigSecondsNow >= 0 && rigSecondsNow <= rigLeft ))" "1"
## An expired limit reads as none left, never as a negative that a check would take for plenty. The turn's instant is what the fixture
## records on the check's own ticket, so a ticket planted with a turn long past is the way to make one expire without waiting fifteen
## minutes; the check's own ticket goes first, since its turn is already won and nothing stands behind it here.
rm -f "$rigQueueDir"/*".$$.ticket"
printf 'session=none\nkind=check\nsince=%s\nturn-won=%s\n' "$( date -u +%Y-%m-%dT%H:%M:%SZ )" "$(( $( date +%s ) - 905 ))" > "$rigQueueDir/00000000000.000000.$$.ticket"
rigAssert "a limit that has passed reads as no seconds left" "$( rigCheckSecondsLeft )" "0"
rm -f "$rigQueueDir"/*".$$.ticket"
fi

echo "-- 3. a run's own turn is not bounded twice --"
### A check inside a run carries the run's ticket, and the run's own -t and stall watch cover it: no deadline of its own is set, and no
### watch is started.
(
	MDAT_SUITE_QUEUE_TURN="${MDAT_SUITE_QUEUE_TURN:-rig-turn}"
	export MDAT_SUITE_QUEUE_TURN
	rigTempDir AgentsScheduleWallClockCheck > /dev/null || :
	printf '%s\n' "limit=$( rigCheckSecondsLeft ) watch=$( jobs -pr | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
) > "$rigTmp/in-run.out" 2> /dev/null
rigAssert "a check inside a run takes no deadline and no watch of its own: the run's own limit covers it" "$( cat "$rigTmp/in-run.out" )" "limit=0 watch=0"

if [ -n "$rigInRun" ] ; then
	rigSkip "the overrun ending and the waited turn (row 4)" "this check runs inside a run, whose own -t and stall watch bound it"
else
echo "-- 4. a check that overruns is ended at its limit, with what it started --"
## A stand-in check in a line of its own: its own HOME, its own workspace, a limit of three seconds, and work that would take eight.
cat > "$rigTmp/Overrun.test.sh" <<'RIGOVERRUN'
#!/usr/bin/env bash
set -u
: "${MDLT_ORIGIN:?}" "${MMDAPP:?}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir RigOverrun )" || exit 1
sleep 8 &
printf 'OVERRUN-CHILD %s\n' "$!"
wait
printf 'OVERRUN-REACHED-END\n'
RIGOVERRUN
mkdir -p "$rigTmp/overrun-home" "$rigTmp/overrun-ws/.local/agents/scratch/sh-test"
rigOverrunStart="$( date +%s )"
{ HOME="$rigTmp/overrun-home" MMDAPP="$rigTmp/overrun-ws" MDAT_SUITE_CHECK_LIMIT_SECONDS=3 \
	bash "$rigTmp/Overrun.test.sh" > "$rigTmp/overrun.out" 2>&1 ; } 2> /dev/null
rigOverrunSeconds=$(( $( date +%s ) - rigOverrunStart ))
rigOverrunChild="$( sed -n 's/^OVERRUN-CHILD //p' "$rigTmp/overrun.out" )"
sleep 1
rigAssert "a check that overruns its limit is ended at it, and not at the end of its work" \
	"$( LC_ALL=C grep -c 'OVERRUN-REACHED-END' "$rigTmp/overrun.out" || : )" "0"
rigAssert "and the overrun is its result, said where its reader finds it" \
	"$( LC_ALL=C grep -c 'overran its wall-clock limit of 3s' "$rigTmp/overrun.out" || : )" 1
rigAssert "and what it started is ended with it" \
	"$( [ -n "$rigOverrunChild" ] && kill -0 "$rigOverrunChild" 2> /dev/null && echo alive || echo gone )" "gone"
## The limit counts from the turn: a check that waited in the line is given its whole limit, never what is left of one counted from its start.
cat > "$rigTmp/Holder.test.sh" <<'RIGHOLDER'
#!/usr/bin/env bash
set -u
: "${MDLT_ORIGIN:?}" "${MMDAPP:?}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir RigHolder )" || exit 1
sleep 6
RIGHOLDER
cat > "$rigTmp/Waiter.test.sh" <<'RIGWAITER'
#!/usr/bin/env bash
set -u
: "${MDLT_ORIGIN:?}" "${MMDAPP:?}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir RigWaiter )" || exit 1
printf 'WAITER-SECONDS-LEFT %s\n' "$( rigCheckSecondsLeft )"
RIGWAITER
mkdir -p "$rigTmp/line-home" "$rigTmp/line-ws/.local/agents/scratch/sh-test"
HOME="$rigTmp/line-home" MMDAPP="$rigTmp/line-ws" MDAT_SUITE_CHECK_LIMIT_SECONDS=10 MDAT_SPAWN_SESSION_ID=rig-holder-session \
	bash "$rigTmp/Holder.test.sh" > "$rigTmp/holder.out" 2>&1 &
rigStarted="$!"
sleep 1
HOME="$rigTmp/line-home" MMDAPP="$rigTmp/line-ws" MDAT_SUITE_CHECK_LIMIT_SECONDS=10 MDAT_SPAWN_SESSION_ID=rig-waiter-session \
	bash "$rigTmp/Waiter.test.sh" > "$rigTmp/waiter.out" 2>&1
wait "$rigStarted" || :
rigStarted=""
rigAssert "a check that waited in the line is given its whole limit once its turn comes" \
	"$(( $( LC_ALL=C sed -n 's/^WAITER-SECONDS-LEFT //p' "$rigTmp/waiter.out" ) > 6 && $( LC_ALL=C sed -n 's/^WAITER-SECONDS-LEFT //p' "$rigTmp/waiter.out" ) <= 10 ))" "1"
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SUITE CHECK LIMIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SUITE_CHECK_LIMIT: OK (%d assertions, %d skipped, offline, rig tree only)\n' "$rigPassCount" "$rigSkipCount"
