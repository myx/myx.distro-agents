#!/usr/bin/env bash
## Behavioural check: overtime may be set while worktime is on (the owner's ruling). A rig workspace of its own is built here, the
## override is set, and the flags are read back: worktime yes and overtime yes. Offline: nothing of the real workspace is read.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsDispatcher.fn.sh"
[ -f "$rigTool" ] || { echo "⛔ ERROR: the dispatcher is not at the origin: $rigTool" >&2 ; exit 1 ; }
otTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsScheduleOvertimeDuringWorktimeCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$otTmp" 2> /dev/null || :' EXIT
mkdir -p "$otTmp/.local/.agents" "$otTmp/.local/agents" "$otTmp/.local/temp"
{
	printf 'MDAT_SCHEDULE_TIMEZONE=UTC\n'
	printf 'MDAT_SCHEDULE_WORKTIME=00:00 23:59 daily\n'
	printf 'MDAT_SCHEDULE_WEEKEND=none\n'
} > "$otTmp/.local/.agents/magic-team.agent.env"
otPasses=0 otFails=0
otAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; otPasses=$(( otPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; otFails=$(( otFails + 1 )) ; fi
}
otRc=0
MMDAPP="$otTmp" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigTool" --override-flag overtime 120 > "$otTmp/override.out" 2>&1 || otRc=$?
otAssert "the flag is taken while worktime is on" "$otRc" "0"
otAssert "and it says so rather than refusing on the clock" \
	"$( LC_ALL=C grep -c -F 'overtime is for outside worktime' "$otTmp/override.out" )" "0"
otAssert "the flags read back as worktime yes and overtime yes" \
	"$( MMDAPP="$otTmp" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigTool" --current-flags 2>/dev/null | LC_ALL=C awk -F': ' '$1 == "worktime" || $1 == "overtime" { print $1 "=" $2 }' | LC_ALL=C cut -d' ' -f1 | LC_ALL=C tr '\n' ' ' )" "worktime=yes overtime=yes "
if [ "$otFails" -ne 0 ] ; then
	echo "⛔ SCHEDULE OVERTIME DURING WORKTIME CHECK FAILED: $otFails of $(( otPasses + otFails )) assertion(s)" >&2 ; exit 1
fi
echo "SCHEDULE_OVERTIME_DURING_WORKTIME: OK ($otPasses assertions, offline)"
