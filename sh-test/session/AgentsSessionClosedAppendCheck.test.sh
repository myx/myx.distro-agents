#!/usr/bin/env bash
## AgentsSessionClosedAppendCheck -- the closed index's line as the one close writes it (AgentsToolsSessionClosedAppend,
## sh-lib/session/AgentsTools.SessionStores.include), and the row the screen's page renders from it
## (AgentsToolsManagerSessionClosedRows). The line's columns are: sequence, session id, member, routine, host, end moment,
## end word, start moment, token sum, runs folders.
## Held:
##   1. the line holds ten TAB-separated fields, and no field carries a space
##   2. the member, the routine, the host and the start moment come from the session's own record, never `-`
##   3. the runs field names the folder of the session's run, so the page finds that folder's block
##   4. the line is a row the page renders: its session row and its run row are both shown
##   5. control: a start moment carrying a space makes no row of the line, so the assertion above can fail
## Offline: a rig workspace of this check's own, written through the store's own writers.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionClosedAppendCheck )" || { echo "⛔ the rig folder could not be made" >&2 ; exit 1 ; }
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigWs="$rigTmp/ws"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigStart="2026-11-20 10:00 +0200"
mkdir -p "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions" "$rigWs/.local/temp" "$rigTmp/home" || exit 1

## THE STORE'S OWN FUNCTIONS, in an environment of the rig's own: one shell call, as every writer of the store runs.
rigStoreFns='. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionStore.Write.include" || exit 1
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionStores.include" || exit 1'
rigStoreCall(){ ## the call's words, its own stdin passed on -- the store's own status
	local callRc=0
	( cd "$rigWs" && env -i MDAT_SCHEDULE_THREAD=off MDAT_TEAM_DATA_COMMIT_THREAD=off HOME="$rigTmp/home" \
		PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash -c "$rigStoreFns
$1" rig ) || callRc=$?
	return "$callRc"
}

## THE SESSION AND ITS ONE RUN, written by the store's own record writer: the headers the closed line reads are the record's.
printf -- '---\nsession-id: s-rig\nspawn-id: run-rig\nhost: %s\nworkspace: ws-rig\nowner: rig-member\nroutine: magic-team.coworking.routine.md\nstatus: spawn-started\nstarted-at: %s\n---\n\n# Spawn session: s-rig\n' \
	"$rigHost" "$rigStart" | rigStoreCall 'AgentsSpawnRecordWrite run-rig run-rig' \
	|| { echo "⛔ the rig's record could not be written" >&2 ; exit 1 ; }
MMDAPP="$rigWs"
. "$rigPackage/sh-lib/session/AgentsTools.StartedRecords.include" || exit 1
. "$rigPackage/sh-lib/session/AgentsTools.SessionStores.include" || exit 1
. "$rigPackage/sh-lib/manager/AgentsTools.ManagerSessionRows.include" || exit 1
sleep 1
rigAssert "control: the session's kept list names its own record" \
	"$( AgentsToolsSpawnedSessionRecords s-rig own | LC_ALL=C sed 's#.*/##' )" "run-rig.spawn.md"

echo "-- 1. the closed line: ten fields, none of them carrying a space --"
rigStoreCall 'AgentsToolsSessionClosedAppend s-rig finished 4321' || { echo "⛔ the closed-line writer refused" >&2 ; exit 1 ; }
rigIndex="$rigWs/.local/agents/closed-sessions.index"
rigLine="$( LC_ALL=C tail -1 "$rigIndex" 2> /dev/null )"
rigField(){ ## the field of the line -- its value, empty where the line has no such field
	printf '%s\n' "$rigLine" | LC_ALL=C awk -F'\t' -v want="$1" '{ print ( NF >= want ? $want : "" ) ; }'
}
rigAssert "the closed line holds ten TAB-separated fields" \
	"$( printf '%s\n' "$rigLine" | LC_ALL=C awk -F'\t' '{ print NF ; }' )" "10"
rigAssert "no field of the closed line carries a space" \
	"$( printf '%s\n' "$rigLine" | LC_ALL=C awk -F'\t' '{ for ( at = 1 ; at <= NF ; at++ ) if ( $at ~ / / ) bad++ ; } END { print bad + 0 ; }' )" "0"

echo "-- 2. the four columns the session's own record carries --"
rigAssert "the line names the member its record carries" "$( rigField 3 )" "rig-member"
rigAssert "the line names the routine its record carries" "$( rigField 4 )" "magic-team.coworking.routine.md"
rigAssert "the line names the host its record carries" "$( rigField 5 )" "$rigHost"
rigAssert "the start moment is the record's, in the line's own form: a space written _" "$( rigField 8 )" "2026-11-20_10:00_+0200"

echo "-- 3. and 4. the runs field names the run's folder, and the page renders the line as a row --"
rigAssert "the runs field names the folder of the session's run" "$( rigField 10 )" "run-rig"
rigAssert "the closed window returns the line whole, ten fields of it, with no space in the start moment" \
	"$( AgentsToolsSessionClosedWindow 0 40 | LC_ALL=C awk -F'\t' '{ print NF, ( $8 ~ / / ? "spaced" : "flat" ) ; }' )" "10 flat"
rigPage="$( AgentsToolsManagerSessionClosedRows --manager-session-closed-list 0 2>&1 )"
rigAssert "the page renders the line as a session row of that session" \
	"$( printf '%s\n' "$rigPage" | LC_ALL=C awk -F'\t' '$1 == "session" && $2 == "s-rig" { n++ ; } END { print n + 0 ; }' )" "1"
rigAssert "the page's run row names the run's folder and its member, so the runs field reached that folder's block" \
	"$( printf '%s\n' "$rigPage" | LC_ALL=C awk -F'\t' '$1 == "run" && $3 == "run-rig" { print $2, $3, $4 ; }' | LC_ALL=C sort -u )" \
	"s-rig run-rig rig-member"

echo "-- 5. the control: a start moment carrying a space is no row at all --"
printf '2\ts-gap\trig-member\tmagic-team.coworking.routine.md\t%s\t2026-11-20_11:00_+0200\tfinished\t2026-11-20 10:00 +0200\t-\t-\n' \
	"$rigHost" >> "$rigIndex"
rigControl="$( AgentsToolsManagerSessionClosedRows --manager-session-closed-list 0 2>&1 )"
rigAssert "control: a start moment carrying a space makes no row of its line" \
	"$( printf '%s\n' "$rigControl" | LC_ALL=C awk -F'\t' '$1 == "session" && $2 == "s-gap" { n++ ; } END { print n + 0 ; }' )" "0"
rigAssert "control: the line written without a space is still a row beside it" \
	"$( printf '%s\n' "$rigControl" | LC_ALL=C awk -F'\t' '$1 == "session" && $2 == "s-rig" { n++ ; } END { print n + 0 ; }' )" "1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SESSION CLOSED APPEND CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	exit 1
fi
echo "SESSION CLOSED APPEND: OK ($rigPass assertions, offline)"
