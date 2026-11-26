#!/usr/bin/env bash
## Behavioural check on AgentsRoutineRunsAtScan.awk: one pass over a folder of routines answers `<file>\t<runs-at>` exactly as the
## per-file frontmatter read did, so the autorun step stops paying a process a file. Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
runsAwk="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsRoutineRunsAtScan.awk"
runsLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/routine/AgentsTools.RoutineKey.include"
[ -f "$runsAwk" ] || { echo "⛔ ERROR: the awk is not at the origin: $runsAwk" >&2 ; exit 1 ; }
runsTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsRoutineRunsAtScanCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$runsTmp" 2> /dev/null || :' EXIT
mkdir -p "$runsTmp/a"
printf -- '---\nruns-at: daily 09:00\n---\n' > "$runsTmp/a/one.routine.md"
printf -- '---\nruns-at: none\n---\n' > "$runsTmp/a/two.routine.md"
printf -- '---\nexecutors: magic-devops\n---\n' > "$runsTmp/a/three.routine.md"
printf -- '---\nruns-at: workdays 10:00\n---\n' > "$runsTmp/a/four.routine.md"
runsBatch="$( LC_ALL=C awk -f "$runsAwk" "$runsTmp/a"/*.routine.md 2> /dev/null )"
runsPasses=0 runsFails=0
runsAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; runsPasses=$(( runsPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; runsFails=$(( runsFails + 1 )) ; fi
}
runsAssert "two routines carry a schedule, one say none, one has no line" "$( printf '%s\n' "$runsBatch" | LC_ALL=C wc -l | tr -d ' ' )" "2"
runsAssert "the daily routine is found with its time" "$( printf '%s\n' "$runsBatch" | LC_ALL=C awk -F'\t' '$1 ~ /one[.]routine[.]md$/ { print $2 }' )" "daily 09:00"
runsAssert "the workdays routine is found with its time" "$( printf '%s\n' "$runsBatch" | LC_ALL=C awk -F'\t' '$1 ~ /four[.]routine[.]md$/ { print $2 }' )" "workdays 10:00"
runsAssert "the none and the no-line routine are absent" "$( printf '%s\n' "$runsBatch" | LC_ALL=C grep -c -e 'two.routine.md' -e 'three.routine.md' )" "0"
if [ "$runsFails" -ne 0 ] ; then
	echo "⛔ ROUTINE RUNS-AT SCAN CHECK FAILED: $runsFails of $(( runsPasses + runsFails )) assertion(s)" >&2 ; exit 1
fi
echo "ROUTINE_RUNS_AT_SCAN: OK ($runsPasses assertions, offline)"
