#!/usr/bin/env bash
## Behavioural check on S12.14's second half: every check run has a wall-clock limit, and the machine's line has it too.
## The gap measured on 2026-11-05: a check started by hand, `bash <check>.test.sh`, takes its turn in the machine's line and holds it for as
## long as it likes. The runner's own `-t` covers only the tests a run starts. So a check that stands still holds the line for ever.
## Held:
##   1. A HAND-STARTED CHECK IS BOUNDED: rigTempDir exports a deadline for the check it was called by, and that deadline is the run's own limit
##      (MDAT_SUITE_CHECK_LIMIT_SECONDS, default 900) from the moment the turn was taken.
##   2. THE DEADLINE IS A REAL NUMBER the check can act on, and it is one the same call can report, so a check that is close to it can say so.
##   3. A RUN'S OWN TURN IS NOT BOUNDED TWICE: a check inside a run takes no ticket of its own, and gets no deadline of its own either, because the
##      run's own `-t` and its stall watch already cover it.
## The real rig-temp fixture runs, over a rig of its own with a private HOME, so the machine's line is left alone. Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" ] || rigRefuse "the rig-temp fixture is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing"
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/agent-check-limit.XXXXXX" )" || exit 1
trap 'rigProcSignalWithChildren TERM $rigStarted 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigStarted=""
HOME="$rigTmp/home" ; export HOME
mkdir -p "$HOME" "$rigTmp/ws/.local/agents" || exit 1
MMDAPP="$rigTmp/ws" ; export MMDAPP
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig-temp fixture would not load"
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

echo "-- 1. a hand-started check is bounded --"
rigDirOut="$( rigTempDir AgentsScheduleWallClockCheck )" || rigRefuse "the rig's folder could not be made"
rigDeadlineWord="none"
case "${rigCheckDeadline:-}" in
	''|*[!0123456789]*) ;;
	*) rigDeadlineWord="set" ;;
esac
rigAssert "the check's turn comes with a deadline, set from MDAT_SUITE_CHECK_LIMIT_SECONDS" "$rigDeadlineWord" "set"
case "$rigDeadlineWord" in
	set) rigLeft=$(( rigCheckDeadline - $( date +%s ) )) ;;
	*) rigLeft=0 ;;
esac
rigAssert "and that deadline is the limit ahead of the check, within a minute of it" \
	"$(( rigLeft > 840 && rigLeft <= 900 ))" "1"

echo "-- 2. the deadline is the number the check acts on --"
rigSecondsNow="$( rigCheckSecondsLeft )"
rigAssert "a check may read the seconds it has left, and they count down" \
	"$(( rigSecondsNow >= 0 && rigSecondsNow <= rigLeft ))" "1"
## An expired deadline reads as none left, never as a negative that a check would take for plenty. The deadline is the fixture's own variable,
## so a check that sets it to the past is the only way to make one expire without waiting fifteen minutes.
rigCheckDeadline=$(( $( date +%s ) - 5 ))
rigAssert "a deadline that has passed reads as no seconds left" "$( rigCheckSecondsLeft )" "0"

echo "-- 3. a run's own turn is not bounded twice --"
### A check inside a run carries the run's ticket, and the run's own -t and stall watch cover it: no deadline of its own is set.
(
	MDAT_SUITE_QUEUE_TURN=rig-turn
	export MDAT_SUITE_QUEUE_TURN
	rigCheckDeadline=""
	rigTempDir AgentsScheduleWallClockCheck > /dev/null || :
	printf '%s\n' "${rigCheckDeadline:-none}"
) > "$rigTmp/in-run.out" 2> /dev/null
rigAssert "a check inside a run takes no deadline of its own: the run's own limit covers it" "$( cat "$rigTmp/in-run.out" )" "none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SUITE CHECK LIMIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SUITE_CHECK_LIMIT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
