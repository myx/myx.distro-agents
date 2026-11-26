#!/usr/bin/env bash
## Behavioural check on the pace verdict (AgentsToolsSchedulePaceVerdict): a machine whose runs make few calls a minute is a slow
## machine, not contention, so the rate decides before the timing; above that rate the machinery time decides.
## Offline: it sources the schedule include and calls the one function, no schedule pass and no tooling operation.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
scheduleInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
[ -f "$scheduleInclude" ] || { echo "⛔ ERROR: the schedule include is not at the origin: $scheduleInclude" >&2 ; exit 1 ; }
. "$scheduleInclude" || exit 1
pacePasses=0 paceFails=0
paceAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pacePasses=$(( pacePasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; paceFails=$(( paceFails + 1 )) ; fi
}
paceAssert "169 calls in 300 s is 33 a minute: a slow machine, so a light load and the start is allowed" \
	"$( AgentsToolsSchedulePaceVerdict 5000 169 300 4000 )" "light"
paceAssert "under the call rate, 2.0 s a call is under the limit" \
	"$( AgentsToolsSchedulePaceVerdict 2000 600 300 4000 )" "under"
paceAssert "at a busy rate, 5.0 s a call is over the limit" \
	"$( AgentsToolsSchedulePaceVerdict 5000 600 300 4000 )" "over"
paceAssert "the owner's own threshold moves the verdict, not a constant in the code" \
	"$( MDAT_TOOL_PACE_RATE_PER_MINUTE=10 AgentsToolsSchedulePaceVerdict 5000 169 300 4000 )" "over"
if [ "$paceFails" -ne 0 ] ; then
	echo "⛔ SCHEDULE PACE VERDICT CHECK FAILED: $paceFails of $(( pacePasses + paceFails )) assertion(s)" >&2 ; exit 1
fi
echo "SCHEDULE_PACE_VERDICT: OK ($pacePasses assertions, offline, one function)"
