#!/usr/bin/env bash
## Behavioural check on the age bound of the store's record rows (sh-lib/session/AgentsTools.StartedRecords.include,
## AgentsToolsSpawnedAllRecordsInto): where `MDAT_RECORD_ROWS_MAX_AGE_SECONDS` is set, a record that closed longer ago
## than that is not handed on, while one still `spawn-started` is, whatever its age. This is what keeps the supervisor's
## scan from opening every record ever written (1 204 on this rig, 21.8 s measured). Held:
##   1. THE CONTROL: with no bound, every record is a row.
##   2. THE BOUND: an old closed record is left out, and an old started record is kept.
##   3. The recent record is kept in both.
## RED RECIPE, measured 2026-11-26 00:20 +0200: before the change the variable was not read anywhere, so row 2 saw
## three rows where two are wanted.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
[ -d "$rigPackage" ] || { echo "⛔ ERROR: no $rigPackage" >&2 ; exit 1 ; }
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnedRecordRowsBoundCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigStore="$rigWs/.local/agents/spawned"
mkdir -p "$rigStore" || exit 1
rigRecord(){ ## id, status, mtime stamp
	mkdir -p "$rigStore/$1" || exit 1
	printf -- '---\nspawn-id: %s\nsession-id: %s\nowner: keeper-rig-01\nstatus: %s\nrun-process: -\nparent-session-id: none\nagent-less: no\nroutine: none\n---\n' \
		"$1" "$1" "$2" > "$rigStore/$1/$1.spawn.md" || exit 1
	touch -t "$3" "$rigStore/$1/$1.spawn.md" || exit 1
}
rigRecord rig-old-closed spawn-succeeded 202611240000
rigRecord rig-old-started spawn-started 202611240000
rigRecord rig-recent spawn-succeeded "$( date +%Y%m%d%H%M )"
printf '%s\n' \
	"rig-old-closed rig-old-closed none host keeper-rig-01 spawn-succeeded 0 rig-old-closed - -" \
	"rig-old-started rig-old-started none host keeper-rig-01 spawn-started 0 rig-old-started - -" \
	"rig-recent rig-recent none host keeper-rig-01 spawn-succeeded 0 rig-recent - -" \
	> "$rigWs/.local/agents/spawned-sessions.registry"
rigRows(){ ## bound (may be empty) -- the rows, one a line
	MDLT_ORIGIN="$MDLT_ORIGIN" RIG_WS="$rigWs" MDAT_RECORD_ROWS_MAX_AGE_SECONDS="$1" bash -c '
		. "$1/myx/myx.distro-agents/sh-lib/session/AgentsTools.StartedRecords.include" || exit 9
		AgentsToolsSpawnedRecordRows "$RIG_WS" spawn-id status
	' rig-rows "$MDLT_ORIGIN" 2> /dev/null
}
rigPassCount=0
rigFailCount=0
rigAssert(){
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
echo "-- 1. the control: no bound, every record is a row --"
rigAll="$( rigRows "" )"
rigAssert "three rows without a bound" "$( printf '%s\n' "$rigAll" | LC_ALL=C awk 'NF { n++ } END { print n + 0 }' )" "3"
echo "-- 2. the bound leaves the old closed record out and keeps the old started one --"
rigBounded="$( rigRows 3600 )"
rigAssert "two rows with a one-hour bound" "$( printf '%s\n' "$rigBounded" | LC_ALL=C awk 'NF { n++ } END { print n + 0 }' )" "2"
rigAssert "the old started record is kept" "$( printf '%s\n' "$rigBounded" | LC_ALL=C awk -F'\t' '$1 == "rig-old-started" { n++ } END { print n + 0 }' )" "1"
rigAssert "the old closed record is left out" "$( printf '%s\n' "$rigBounded" | LC_ALL=C awk -F'\t' '$1 == "rig-old-closed" { n++ } END { print n + 0 }' )" "0"
echo "-- 3. the recent record is a row either way --"
rigAssert "the recent record survives the bound" "$( printf '%s\n' "$rigBounded" | LC_ALL=C awk -F'\t' '$1 == "rig-recent" { n++ } END { print n + 0 }' )" "1"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWNED RECORD ROWS BOUND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SPAWNED_RECORD_ROWS_BOUND: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
