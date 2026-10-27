#!/usr/bin/env bash
## Behavioural check on `--manager-schedule-read` (S13.9), the console's Schedule view, run rather than read, against a rig
## workspace built here: its own magic-team settings and nothing of the real workspace. Held: the rows it prints -- `now`, the six
## `flag` rows in the order of --current-flags, one `switch` row naming the nearest change, and 168 `cell` rows, a weekday and an
## hour each; a cell holds `worktime` for the planned hours of a work day, `weekend` for a weekend day, and an override only
## in the hours that have not passed; a holiday takes worktime out of the days to come; the nearest change is an override's end
## when that is nearer than worktime's boundary; unset settings read as their defaults, said so; an argument is refused; a
## member's session is refused; and nothing is written. Offline.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScheduleReadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigNew(){ ## name, settings text -> a workspace of that name whose magic-team scope holds the text
	mkdir -p "$rigTmp/$1/.local/.agents"
	printf '%s' "$2" > "$rigTmp/$1/.local/.agents/magic-team.agent.env"
}
rigRead(){ ## name, optional arguments -> the output in $rigTmp/<name>.out, the status in rigRc
	rigRc=0
	( cd "$rigTmp/$1" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID MMDAPP="$rigTmp/$1" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigTool" --manager-schedule-read "${@:2}" ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" || rigRc=$?
}
rigCell(){ ## name, weekday, hour -> the flags of that cell
	LC_ALL=C awk -F'\t' -v day="$2" -v hour="$3" '$1 == "cell" && $2 == day && $3 == hour { print $4 }' "$rigTmp/$1.out"
}
rigRow(){ ## name, row name, second field -> that row's line
	LC_ALL=C awk -F'\t' -v row="$2" -v key="${3:-}" '$1 == row && ( key == "" || $2 == key ) { print ; exit }' "$rigTmp/$1.out"
}

rigNow="$( date +%s )"
rigNew set "MDAT_SCHEDULE_TIMEZONE=UTC
MDAT_SCHEDULE_WORKTIME=09:00 18:00 mon,tue,wed,thu,fri
MDAT_SCHEDULE_WEEKEND=sat,sun
MDAT_SCHEDULE_EMERGENCY=until $(( rigNow + 90 ))
"
rigBefore="$( find "$rigTmp/set" -type f | LC_ALL=C sort | xargs cksum )"
rigRead set
rigAssert "it ends 0, and its stdout is rows only" "$rigRc:$( LC_ALL=C grep -c -v -E '^(now|flag|switch|cell)	' "$rigTmp/set.out" )" "0:0"
rigAssert "the rows are now, six flags, one switch and 168 cells, in that order of kinds" \
	"$( LC_ALL=C awk -F'\t' '{ if ( $1 != last ) { kinds = kinds ( kinds == "" ? "" : " " ) $1 ; last = $1 } count[$1]++ } END { print kinds ":" count["now"] ":" count["flag"] ":" count["switch"] ":" count["cell"] }' "$rigTmp/set.out" )" \
	"now flag switch cell:1:6:1:168"
rigAssert "the flags are worktime, weekend, holidays, emergency, overtime, learning" "$( LC_ALL=C awk -F'\t' '$1 == "flag" { printf "%s ", $2 }' "$rigTmp/set.out" )" "worktime weekend holidays emergency overtime learning "
rigAssert "now names the zone the settings give" "$( rigRow set now | LC_ALL=C cut -f5 )" "UTC"
rigAssert "an override with a TTL reads yes with its seconds left" \
	"$( rigRow set flag emergency | LC_ALL=C cut -f3 ):$( rigRow set flag emergency | LC_ALL=C cut -f4 | LC_ALL=C grep -c 'seconds left' )" "yes:1"
rigAssert "the nearest change is the end of the emergency, within its 90 seconds" \
	"$( rigRow set switch | LC_ALL=C awk -F'\t' '{ if ( $3 == "emergency-ends" && $2 >= 1 && $2 <= 90 ) print "emergency-ends"; else print $0 }' )" "emergency-ends"
rigAssert "a work day: nothing before 09, worktime from 09 to 17, nothing from 18" "$( rigCell set mon 08 ):$( rigCell set mon 09 ):$( rigCell set mon 17 ):$( rigCell set mon 18 )" "-:worktime:worktime:-"
rigAssert "a weekend day holds weekend in every hour" "$( rigCell set sat 00 ):$( rigCell set sun 23 )" "weekend:weekend"
rigNew ot "MDAT_SCHEDULE_TIMEZONE=UTC
MDAT_SCHEDULE_OVERTIME=on
"
rigRead ot
rigAssert "an override with no end reads yes, and is in the hours to come, the end of the week too" \
	"$( rigRow ot flag overtime | LC_ALL=C cut -f3 ):$( LC_ALL=C awk -F'\t' '$1 == "cell" && $4 ~ /overtime/ { count++ } END { print ( count > 140 ? "most-cells" : count ) }' "$rigTmp/ot.out" )" "yes:most-cells"
rigAssert "nothing was written to the workspace" "$( find "$rigTmp/set" -type f | LC_ALL=C sort | xargs cksum )" "$rigBefore"

rigNew day "MDAT_SCHEDULE_TIMEZONE=UTC
MDAT_SCHEDULE_HOLIDAYS=on
"
rigRead day
rigToday="$( LC_ALL=C awk -F'\t' '$1 == "now" { print $3 }' "$rigTmp/day.out" )"
rigOther=""
for rigName in mon tue wed thu fri ; do [ "$rigName" = "$rigToday" ] || { rigOther="$rigName" ; break ; } done
rigAssert "a holiday: worktime reads no (holiday), and the work days to come hold no worktime" \
	"$( rigRow day flag worktime | LC_ALL=C cut -f3,4 | LC_ALL=C tr '\t' ' ' ):$( rigCell day "$rigOther" 10 )" "no (holiday) (default):holidays"

rigNew bare ""
rigRead bare
rigAssert "unset settings read as their defaults, and the flags say so" \
	"$( rigRow bare flag worktime | LC_ALL=C cut -f4 ):$( rigRow bare flag weekend | LC_ALL=C cut -f4 ):$( rigCell bare mon 09 ):$( rigCell bare sat 09 )" "(default):(default):worktime:weekend"

rigRead bare extra-word
rigAssert "an argument is refused, rc 1, with the error on stderr and nothing on stdout" \
	"$rigRc:$( LC_ALL=C wc -c < "$rigTmp/bare.out" | LC_ALL=C tr -d ' ' ):$( LC_ALL=C grep -c 'takes no argument' "$rigTmp/bare.err" )" "1:0:1"
rigRc=0
( cd "$rigTmp/bare" && env -u CLAUDE_CODE_SESSION_ID MDAT_SPAWN_SESSION_ID=rig-session MDAT_SPAWN_AGENT=keeper-myx MMDAPP="$rigTmp/bare" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigTool" --manager-schedule-read ) > "$rigTmp/member.out" 2> "$rigTmp/member.err" || rigRc=$?
rigAssert "a call from inside a member's session is refused like the rest of the family, nothing printed" "$( [ "$rigRc" != 0 ] && printf refused || printf allowed ):$( LC_ALL=C wc -c < "$rigTmp/member.out" | LC_ALL=C tr -d ' ' )" "refused:0"

if [ "$rigFails" -gt 0 ] ; then
	echo "⛔ MANAGER SCHEDULE READ CHECK FAILED: $rigFails of $(( rigFails + rigPasses )) assertion(s)" >&2
	exit 1
fi
echo "MANAGER_SCHEDULE_READ: OK ($rigPasses assertions, offline)"
