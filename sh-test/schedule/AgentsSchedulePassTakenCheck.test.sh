#!/usr/bin/env bash
## Behavioural check on the taken-pass rule (AgentsToolsSchedulePassTakenSkips): when a pass already started a duty, a routine item
## waits for the next pass, while an approved urgent or emergency one still starts -- the queue outranks the routine restart.
## Offline: it sources the schedule include and calls the one function.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
takenInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
[ -f "$takenInclude" ] || { echo "⛔ ERROR: the schedule include is not at the origin: $takenInclude" >&2 ; exit 1 ; }
. "$takenInclude" || exit 1
takenPasses=0 takenFails=0
takenAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; takenPasses=$(( takenPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; takenFails=$(( takenFails + 1 )) ; fi
}
takenVerdict(){ ## mark, taken -> skip|take
	AgentsToolsSchedulePassTakenSkips "$1" "$2" && printf 'skip\n' || printf 'take\n'
}
takenAssert "an empty pass starts an ordinary item" "$( takenVerdict normal "" )" "take"
takenAssert "a taken pass skips an ordinary item" "$( takenVerdict normal work-duty.magic-devops )" "skip"
takenAssert "a taken pass still starts an urgent item" "$( takenVerdict urgent work-duty.magic-devops )" "take"
takenAssert "a taken pass still starts an emergency item" "$( takenVerdict emergency work-duty.magic-devops )" "take"
if [ "$takenFails" -ne 0 ] ; then
	echo "⛔ SCHEDULE PASS TAKEN CHECK FAILED: $takenFails of $(( takenPasses + takenFails )) assertion(s)" >&2 ; exit 1
fi
echo "SCHEDULE_PASS_TAKEN: OK ($takenPasses assertions, offline)"
