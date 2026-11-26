#!/usr/bin/env bash
## Behavioural check on the `flag-end` rows of `--manager-schedule-read`: a timed override prints its own end epoch, measured from the
## clock by the seconds it has left, so the picture can draw to a real end. Its own rig workspace is built here; offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
feTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$feTool" ] || { echo "⛔ ERROR: the tool is not at the origin: $feTool" >&2 ; exit 1 ; }
feTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsScheduleFlagEndRowsCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$feTmp" 2> /dev/null || :' EXIT
mkdir -p "$feTmp/.local/.agents" "$feTmp/.local/agents" "$feTmp/.local/temp"
feNow="$( date +%s )"
{
	printf 'MDAT_SCHEDULE_TIMEZONE=UTC\n'
	printf 'MDAT_SCHEDULE_WORKTIME=09:00 18:00 mon,tue,wed,thu,fri\n'
	printf 'MDAT_SCHEDULE_WEEKEND=sat,sun\n'
	printf 'MDAT_SCHEDULE_EMERGENCY=until %s\n' "$(( feNow + 90 ))"
	printf 'MDAT_SCHEDULE_OVERTIME=until %s\n' "$(( feNow + 3600 ))"
} > "$feTmp/.local/.agents/magic-team.agent.env"
MMDAPP="$feTmp" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$feTool" --manager-schedule-read > "$feTmp/rows" 2> /dev/null || true
fePasses=0 feFails=0
feAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; fePasses=$(( fePasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; feFails=$(( feFails + 1 )) ; fi
}
feEnd(){ ## flag -> its end epoch
	LC_ALL=C awk -F'\t' -v flag="$1" '$1 == "flag-end" && $2 == flag { print $3 ; exit }' "$feTmp/rows"
}
feAssert "the emergency prints its own end, within its 90 seconds" \
	"$( feEnd emergency | LC_ALL=C awk -v n="$feNow" '{ print ( $1 >= n + 80 && $1 <= n + 100 ) ? "in-window" : "out" }' )" "in-window"
feAssert "the overtime prints its own end, within its 3600 seconds" \
	"$( feEnd overtime | LC_ALL=C awk -v n="$feNow" '{ print ( $1 >= n + 3590 && $1 <= n + 3610 ) ? "in-window" : "out" }' )" "in-window"
feAssert "the two ends are 3510 s apart, each flag's own seconds from one clock" \
	"$(( $( feEnd overtime ) - $( feEnd emergency ) ))" "3510"
if [ "$feFails" -ne 0 ] ; then
	echo "⛔ SCHEDULE FLAG-END ROWS CHECK FAILED: $feFails of $(( fePasses + feFails )) assertion(s)" >&2 ; exit 1
fi
echo "SCHEDULE_FLAG_END_ROWS: OK ($fePasses assertions, offline)"
