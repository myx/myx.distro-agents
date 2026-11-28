#!/usr/bin/env bash
## Behavioural check: a start hold left by a run that died is cleared once it is past its ten minutes, and a fresh hold is kept -- the
## sweep the pass runs so no key stays blocked by a mark nobody reads (the sketch: a hung advance is bounded). Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
sweepInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
[ -f "$sweepInclude" ] || { echo "⛔ ERROR: the schedule include is not at the origin" >&2 ; exit 1 ; }
sweepTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsScheduleStaleHoldsSweepCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$sweepTmp" 2> /dev/null || :' EXIT
mkdir -p "$sweepTmp/.local/agents/schedule/starting"
sweepStore="$sweepTmp/.local/agents/schedule/starting"
: > "$sweepStore/advance.magic-coordinator.hold" ; touch -t 202611240042 "$sweepStore/advance.magic-coordinator.hold"
: > "$sweepStore/fresh.key.hold" ; touch -t "$( date +%Y%m%d%H%M )" "$sweepStore/fresh.key.hold"
sweepOut="$( MMDAPP="$sweepTmp" MDLT_ORIGIN="$MDLT_ORIGIN" agentsSchedulePassNow="$( date +%s )" bash -c '
	. "'"$sweepInclude"'" 2> /dev/null
	AgentsToolsScheduleStaleHoldsSweep
' 2> /dev/null )"
sweepPasses=0 sweepFails=0
sweepAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; sweepPasses=$(( sweepPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; sweepFails=$(( sweepFails + 1 )) ; fi
}
sweepAssert "the two-day-old hold is gone" "$( [ -e "$sweepStore/advance.magic-coordinator.hold" ] && echo present || echo gone )" "gone"
sweepAssert "the fresh hold is kept" "$( [ -e "$sweepStore/fresh.key.hold" ] && echo present || echo gone )" "present"
sweepAssert "the sweep says what it cleared" "$( printf '%s\n' "$sweepOut" | LC_ALL=C grep -c 'cleared a start hold past its ten minutes: advance.magic-coordinator.hold' )" "1"
sweepAssert "the fresh hold is not named in the line" "$( printf '%s\n' "$sweepOut" | LC_ALL=C grep -c 'fresh.key.hold' || true )" "0"
if [ "$sweepFails" -ne 0 ] ; then
	echo "⛔ STALE HOLDS SWEEP CHECK FAILED: $sweepFails of $(( sweepPasses + sweepFails )) assertion(s)" >&2 ; exit 1
fi
echo "SCHEDULE_STALE_HOLDS_SWEEP: OK ($sweepPasses assertions, offline)"
