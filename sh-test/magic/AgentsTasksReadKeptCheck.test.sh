#!/usr/bin/env bash
## Behavioural check on the board status read (sh-lib/magic/AgentsTools.CoordinatorSurface.include, AgentsToolsSurfaceTasks):
## the counts and the active items are rendered once and kept the pace window, five minutes, because the token roll-up inside them
## walks every board item and every run record: a walk is 7 s here and a duty's round is longer than a half minute. Held, run rather
## than read:
##   1. A FIRST READ RENDERS, and answers the board's counts and its active items.
##   2. A SECOND READ INSIDE THE WINDOW SERVES THE KEPT COPY: the readers are not called again.
##   3. THE CONTROL: MDAT_TASKS_REBUILD=1 asks the readers again, so the kept copy is a cache and not a one-time answer.
##   4. A COPY A MINUTE OLD IS SERVED: the window's lower side, which a half-minute window rebuilt.
##   5. A COPY OLDER THAN THE WINDOW IS REBUILT: the window's upper side, so the copy expires and is never a one-time answer.
## The readers are stand-ins of the rig, so nothing of a board is read and no store is written.
## RED RECIPE, measured 2026-11-25 16:5x +0200 against the pre-change surface: row 2 fails with 2 calls where 1 is wanted, and
## row 3's count follows it. The machine's one check lane was held by another session's batch, so the red was taken on a copy
## of this check with its rig-temp fixture's line wait removed; the assertions themselves are unchanged.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/magic/AgentsTools.CoordinatorSurface.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the surface include is not at $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTasksReadKeptCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" || exit 1
: > "$rigTmp/calls"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
cat > "$rigTmp/prelude.sh" <<'PRELUDE'
. "$RIG_INCLUDE" || exit 1
AgentsToolsBoardCounts(){ printf 'count\n' >> "$RIG_CALLS" ; printf 'running: 1\n' ; }
AgentsToolsBoardActiveItems(){ printf 'active\n' >> "$RIG_CALLS" ; printf 'running/rig-item.md\n' ; }
PRELUDE
rigTasks(){ ## the environment word for the rebuild, empty for none
	RIG_CALLS="$rigTmp/calls" RIG_INCLUDE="$rigInclude" MMDAPP="$rigWs" MDAT_TASKS_REBUILD="$1" \
		bash -c '. "$1" ; AgentsToolsSurfaceTasks --tasks' rig-tasks "$rigTmp/prelude.sh" > "$rigTmp/tasks.out" 2>&1
}
rigLog(){ LC_ALL=C grep -c -- "$1" "$rigTmp/calls" 2> /dev/null || : ; }

echo "-- 1. a first read renders --"
: > "$rigTmp/calls"
rigTasks ""
rigAssert "the board counts are answered" "$( LC_ALL=C grep -c '^running: 1$' "$rigTmp/tasks.out" 2> /dev/null || : )" 1
rigAssert "and the active items are answered" "$( LC_ALL=C grep -c '^running/rig-item.md$' "$rigTmp/tasks.out" 2> /dev/null || : )" 1
rigAssert "the counters were read once" "$( rigLog '^count$' )" 1

echo "-- 2. a second read inside the window serves the kept copy --"
rigTasks ""
rigAssert "the counts were not read again" "$( rigLog '^count$' )" 1
rigAssert "and the kept copy answers the same board" "$( LC_ALL=C grep -c '^running: 1$' "$rigTmp/tasks.out" 2> /dev/null || : )" 1

echo "-- 3. the control: a forced rebuild asks again --"
rigTasks 1
rigAssert "the counts are read again on a forced rebuild" "$( rigLog '^count$' )" 2

echo "-- 4. a copy a minute old is served --"
touch -t "$( LC_ALL=C date -r "$(( $( date +%s ) - 60 ))" +%Y%m%d%H%M.%S )" "$rigWs/.local/agents/tasks.ready"
rigTasks ""
rigAssert "the counts were not read again inside the window" "$( rigLog '^count$' )" 2

echo "-- 5. a copy older than the window is rebuilt --"
touch -t "$( LC_ALL=C date -r "$(( $( date +%s ) - 400 ))" +%Y%m%d%H%M.%S )" "$rigWs/.local/agents/tasks.ready"
rigTasks ""
rigAssert "the counts are read again past the window" "$( rigLog '^count$' )" 3

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TASKS READ KEPT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'TASKS_READ_KEPT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
