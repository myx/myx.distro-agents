#!/usr/bin/env bash
## AgentsHotPathWalksCheck -- the reads of EVERY run record, of every item of a board state, of every
## session store and of every inbox, in the tooling, each on a list with its reason. A working workspace
## holds thousands of run folders under .local/agents/spawned, as many session stores under sessions/,
## and hundreds of items in a board state, so a `grep`, an `awk`, a `find` or a `for` over
## `spawned/*/*.spawn.md`, `sessions/*/<file>` or `board/<state>/*.md` costs each call that asks it, and a call
## path (a schedule pass, a Wait round, a permission gate, a start) must take a kept list or an index
## instead (epic S10.37). This check reads the code, never the clock: a walk is slow code wherever it
## stands, and the list says why each one is still there.
## Guards: every walk of sh-lib and sh-scripts is on the list, under its file and the function it stands
## in, as often as the list says; every row's reason is a named one; a named reason the tooling uses is
## one the list defines; the control lines find a walk in each shape and no glob that names one file.
## Red: a new `grep ... spawned/*/*.spawn.md` in any function of sh-lib fails the first guard.
## Offline: reads the source tree alone; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsHotPathWalksCheck.XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}

## THE REASONS a walk stands, each by its name.
rigReasons(){
	printf '%s\n' \
		'@one-off|an operation a person or a review runs by hand, or a report: once, not on a pass, a round, a gate or a start' \
		'@kept|the refresh of a kept list or measure, bounded by its TTL or its stamp, so the walk runs once per bound and every caller in between reads the list' \
		'@fallback|taken only while the index it stands behind is not marked complete (children/.indexed) or not there: the index answers whenever it stands' \
		'@call-path|NOT FIXED, LEFT: on a pass, a Wait round, a gate, an ask or a start, each call paying the record count; the debt epic S10.37 tracks, to move onto the spawned-sessions registry or the children lists' \
		'@housekeeping|the housekeeping on its own bound (every 5 minutes at most on a render, or once a main-loop iteration): it reads the store whole by design, to close what a dead run left open or to say what fell due' \
		'@rebuild|the spawned-sessions registry rebuilt whole, which is its doctrine (never maintained beside the store): by the writer of the records (the spawn proxy as it makes or closes one, the session control as it starts), by the housekeeping and the collect that follow it on their own bound, or by the render and the operation that ask for one'
}
## THE LIST. One line a function: file under the package|function (empty for top-level code)|how many walks it holds|reason.
rigList(){
	printf '%s\n' \
		'sh-lib/board/AgentsTools.ItemDecisions.include|AgentsToolsItemIsParty|1|@call-path' \
		'sh-lib/board/AgentsTools.ReviewFlow.include|AgentsReviewShutdown|2|@one-off' \
		'sh-lib/member/AgentsTools.Member.include||1|@one-off' \
		'sh-lib/session/AgentsTools.DispatcherSchedule.include|AgentsToolsScheduleVerifyStale|1|@call-path' \
		'sh-lib/comms/AgentsTools.InternOpCommsSlackSend.include|AgentsToolsCommsSlackUnreachableReport|1|@one-off' \
		'sh-lib/monitoring/AgentsTools.Monitoring.include|AgentsToolsMonitoringHealth|1|@one-off' \
		'sh-lib/grants/AgentsTools.Grants.include|AgentsToolsGrantsMemberList|2|@one-off' \
		'sh-lib/manager/AgentsTools.ManagerDashboard.include|AgentsToolsManagerDashboardDeaths|1|@one-off' \
		'sh-lib/member/AgentsTools.MemberWaitSources.include||1|@call-path' \
		'sh-lib/session/AgentsTools.SessionChat.include|AgentsToolsSessionChatThreadSessions|1|@call-path' \
		'sh-lib/session/AgentsTools.SessionComms.include|AgentsToolsSessionCommsTakeAll|1|@call-path' \
		'sh-lib/session/AgentsTools.SpawnSandbox.include|AgentsToolsSpawnProxyRootMarkRetry|1|@housekeeping' \
		'sh-lib/session/AgentsTools.SpawnSandbox.include|AgentsToolsSpawnProxyStaleParkClear|1|@housekeeping' \
		'sh-lib/session/AgentsTools.UndoRecord.include||1|@one-off' \
		'sh-lib/session/AgentsTools.ChildrenIndex.include|AgentsToolsChildrenIndexRepair|1|@housekeeping' \
		'sh-lib/team-data/AgentsTools.InternTeamDataReflectionSweep.include||1|@one-off' \
		'sh-lib/harness/AgentsUniversalHarness.sh||2|@fallback' \
		'sh-lib/manager/AgentsTools.ManagerSession.include||3|@one-off' \
		'sh-lib/member/AgentsTools.InternOpMorningReview.include||1|@one-off' \
		'sh-lib/session/AgentsTools.Dispatcher.include|AgentsToolsDispatcherHistory|1|@one-off' \
		'sh-lib/session/AgentsTools.DispatcherSchedule.include|AgentsToolsSchedulePaceText|1|@kept' \
		'sh-lib/session/AgentsTools.DispatcherStats.include|AgentsToolsStatsRecords|1|@one-off' \
		'sh-lib/session/AgentsTools.DispatcherStats.include|AgentsToolsStatsDerive|4|@one-off' \
		'sh-lib/session/AgentsTools.SessionTranscript.include|AgentsSessionTokensRollupRows|2|@call-path' \
		'sh-lib/team-data/AgentsTools.StrayStore.include|AgentsToolsStrayStoreList|2|@one-off' \
		'sh-lib/team-data/AgentsTools.StrayStore.include|AgentsToolsStrayStoreRunsTable|1|@one-off' \
		'sh-lib/session/AgentsTools.SpawnSandbox.include|AgentsToolsWaitChildThreadSources|1|@fallback' \
		'sh-lib/session/AgentsTools.SpawnSandbox.include|AgentsToolsSpawnSandboxFoldersOfItem|1|@call-path' \
		'sh-lib/session/AgentsTools.StartedRecords.include|AgentsToolsSpawnedDutyRecords|1|@kept' \
		'sh-lib/session/AgentsTools.StartedRecords.include|AgentsToolsSpawnedRecordsOfRoutine|1|@kept' \
		'sh-lib/session/AgentsTools.StartedRecords.include|AgentsToolsSpawnedStartedRecords|1|@kept' \
		'sh-lib/session/AgentsTools.StartedRecords.include|AgentsToolsSpawnedChildRecords|1|@fallback' \
		'sh-lib/session/AgentsTools.SuperviseResume.include|AgentsToolsSuperviseResume|1|@one-off' \
		'sh-lib/session/AgentsTools.SuperviseScan.include|AgentsToolsSuperviseScan|1|@one-off' \
		'sh-lib/team-data/AgentsTools.Registries.include|AgentsToolsRegistryMeasureRows|1|@one-off' \
		'sh-lib/team-data/AgentsTools.Registries.include|AgentsToolsRegistrySpawnedSessionsRows|2|@rebuild' \
		'sh-lib/team-data/AgentsTools.Registries.include|AgentsToolsRegistryRenderSpawnedSessions|1|@rebuild' \
		'sh-lib/team-data/AgentsTools.Registries.include|AgentsToolsRegistryRenderAll|1|@one-off' \
		'sh-lib/team-data/AgentsTools.Registries.include|AgentsToolsRegistryList|1|@one-off' \
		'sh-lib/team-data/AgentsTools.Registries.include|AgentsToolsRegistrySpawnedSessionsRebuild|1|@rebuild' \
		'sh-lib/session/AgentsTools.StartedRecords.include|AgentsToolsSpawnedRegistryFile|1|@kept' \
		'sh-lib/harness/AgentsHarnessMessages.include|AgentsHarnessToolListAgents|1|@call-path' \
		'sh-lib/magic/AgentsTools.SpawnHousekeeping.include|AgentsToolsAdvanceSpawnHousekeeping|4|@housekeeping' \
		'sh-lib/manager/AgentsTools.ManagerSession.include|AgentsToolsManagerSessionKill|1|@one-off' \
		'sh-lib/manager/AgentsTools.ManagerSession.include|AgentsToolsManagerSessionRows|1|@one-off' \
		'sh-lib/manager/AgentsTools.ManagerSession.include|AgentsToolsManagerSessionScope|2|@one-off' \
		'sh-lib/member/AgentsTools.InternOpMorningReview.include||3|@one-off' \
		'sh-lib/board/AgentsTools.BoardRoundScan.include|AgentsToolsBoardRecheckDueSection|1|@call-path' \
		'sh-lib/board/AgentsTools.ReviewFlow.include|AgentsReviewItemsForRoutine|1|@call-path' \
		'sh-lib/grants/AgentsTools.InternOpPermission.include||1|@fallback' \
		'sh-lib/grants/AgentsTools.PermissionHolds.include|AgentsToolsPermissionParticipants|1|@call-path' \
		'sh-lib/harness/AgentsHarnessSpawn.include|AgentsHarnessDispatchItemPath|1|@fallback' \
		'sh-lib/magic/AgentsTools.MagicCoordinatorState.include|AgentsToolsBoardActiveItems|1|@one-off' \
		'sh-lib/magic/AgentsTools.MagicCoordinatorState.include|AgentsToolsBoardCounts|1|@one-off' \
		'sh-lib/magic/AgentsTools.SpawnHousekeeping.include|AgentsToolsReviewUnseenEscalate|1|@housekeeping' \
		'sh-lib/manager/AgentsTools.ManagerDashboard.include|AgentsToolsManagerDashboardTeamData|1|@one-off' \
		'sh-lib/member/AgentsTools.ExternalOwnerItems.include|AgentsToolsExternalOwnerRows|1|@one-off' \
		'sh-lib/session/AgentsTools.CoordinatorSurface.include|AgentsToolsSurfaceStanding|1|@call-path' \
		'sh-lib/session/AgentsTools.DispatcherSchedule.include|AgentsToolsScheduleBoardDemand|1|@call-path' \
		'sh-lib/session/AgentsTools.InternOpSessionContextScan.include||1|@call-path' \
		'sh-lib/session/AgentsTools.InternOpSpawnPrepareBrief.include||1|@call-path' \
		'sh-lib/session/AgentsTools.SpawnSandbox.include|AgentsToolsSpawnSandboxFolderState|1|@housekeeping' \
		'sh-lib/team-data/AgentsTools.Registries.include|AgentsToolsRegistryPendingRepliesRows|1|@rebuild' \
		'sh-lib/questions/AgentsTools.PendingReplyCollect.include|AgentsToolsPendingReplySessionsRunning|1|@rebuild' \
		'sh-lib/session/AgentsTools.InternOpAgentSpawnProxy.include||3|@rebuild' \
		'sh-lib/session/AgentsTools.SessionControlStart.include|AgentsToolsSessionControlCheckWorkspace|1|@rebuild'
}

## THE READER: the lines of a file that read every run record -- a `*/*.spawn.md` glob under spawned/,
## a find over spawned/, a walk of its folders (`spawned/*/ ; do`), or a call that rebuilds the
## spawned-sessions registry (AgentsToolsRegistrySpawnedSessionsRebuild, and the render, which
## rebuilds first) -- each under the function it stands in. A comment line and a `type ... ||` load
## guard are none. A glob that names one file (`spawned/*/<id>.spawn.md`) is none: it costs no process.
rigWalks(){ ## file (relative to the package)
	LC_ALL=C awk -v file="$1" '
		/^[A-Za-z_][A-Za-z0-9_]*\(\)[ \t]*\{/ { fn = $0 ; sub( /\(\).*/, "", fn ) ; next }
		/^\}/ { fn = "" ; next }
		/^[ \t]*(#|type )/ { next }
		/spawned"?\/\*\/\*\.spawn\.md|spawned"?\/\*\/"?\*\.spawn|[Ss]pawned"\*\/\*\.spawn\.md|find "?\$[{A-Za-z_}:-]*\/?\.local\/agents\/spawned|find "\$[A-Za-z]+Agents"\/spawned/ { print file "|" fn ; next }
		/spawned"?\/\*\/"? *(;|do)/ { print file "|" fn ; next }
		/board"?\/(\*|[a-z-]+|"?\$[a-zA-Z{}:-]+"?)\/[a-z.-]*\*[a-z.-]*\.md|board"?\/\*\/"?\*[" ;]|find "?\$\{?MDAT_DATA_ROOT[^ ]*board/ { print file "|" fn ; next }
		## A glob of every session store (`sessions/*/<file each session has>`) or of every inbox is a walk; one that names
		## one file by a variable after the star (`sessions/*/"$ref.md"`) costs no process, and a `case` pattern reads nothing.
		/agents\/sessions"?\/\*\/[^ ]*\)/ { next }
		/sessions"?\/\*\/[a-z.]*\/?"?\$/ { next }
		/agents\/sessions"?\/\*\/|inboxes"?\/\*\/|find "?\$\{?MMDAPP[^ ]*\/(sessions|inboxes)|find "?\$\{?MDAT_DATA_ROOT[^ ]*inboxes/ { print file "|" fn ; next }
		/AgentsToolsRegistrySpawnedSessionsRebuild|AgentsToolsRegistrySpawnedSessionsRows([^A-Za-z]|$)|AgentsToolsRegistryRenderSpawnedSessions([^A-Za-z]|$)/ { print file "|" fn }
	' "$rigPackage/$1"
}

echo "-- 1. every walk of the tooling is on the list, as often as it says, with a named reason --"
rigList > "$rigTmp/list"
rigReasons > "$rigTmp/reasons"
( cd "$rigPackage" && find sh-lib sh-scripts -type f \( -name '*.include' -o -name '*.sh' -o -name '*.fn.sh' -o -name '*.awk' \) ! -name '*.keep' | LC_ALL=C sort ) > "$rigTmp/files"
rigAssert "control: the tooling's files are read, many of them" "$( [ "$( wc -l < "$rigTmp/files" | LC_ALL=C tr -d ' ' )" -ge 150 ] && echo many )" many
: > "$rigTmp/walks"
while IFS= read -r rigFile ; do
	rigWalks "$rigFile" >> "$rigTmp/walks"
done < "$rigTmp/files"
rigGuard="$( LC_ALL=C awk -F'|' '
	FILENAME == ARGV[1] { if ( $0 == "" ) next ; want[$1 "|" $2] = $3 + 0 ; reason[$1 "|" $2] = $4 ; next }
	{ got[$0]++ }
	END {
		for ( key in got ) { if ( ! ( key in want ) ) print "NOT ON THE LIST: " key " (" got[key] " walk(s))" }
		for ( key in want ) { if ( ( key in got ? got[key] : 0 ) != want[key] ) print "LIST: " key " holds " ( key in got ? got[key] : 0 ) " walk(s), the list says " want[key] }
	}
' "$rigTmp/list" "$rigTmp/walks" | LC_ALL=C sort )"
rigAssert "every read of every run record is on the list, and every row stands in the code as often as it says" "${rigGuard:-none}" none
rigAssert "every row's reason is a named one" "$( LC_ALL=C awk -F'|' 'FNR == NR { named[$1] = 1 ; next } { if ( ! ( $4 in named ) ) bad++ } END { print bad + 0 }' "$rigTmp/reasons" "$rigTmp/list" )" 0
rigAssert "every named reason is used by a row" "$( LC_ALL=C awk -F'|' 'FNR == NR { used[$4] = 1 ; next } { if ( ! ( $1 in used ) ) bad++ } END { print bad + 0 }' "$rigTmp/list" "$rigTmp/reasons" )" 0
printf 'the debt: %s walk(s) on a call path, %s kept, %s behind an index, %s registry rebuilds, %s housekeeping, %s one-off\n' \
	"$( LC_ALL=C awk -F'|' '$4 == "@call-path" { n += $3 } END { print n + 0 }' "$rigTmp/list" )" \
	"$( LC_ALL=C awk -F'|' '$4 == "@kept" { n += $3 } END { print n + 0 }' "$rigTmp/list" )" \
	"$( LC_ALL=C awk -F'|' '$4 == "@fallback" { n += $3 } END { print n + 0 }' "$rigTmp/list" )" \
	"$( LC_ALL=C awk -F'|' '$4 == "@rebuild" { n += $3 } END { print n + 0 }' "$rigTmp/list" )" \
	"$( LC_ALL=C awk -F'|' '$4 == "@housekeeping" { n += $3 } END { print n + 0 }' "$rigTmp/list" )" \
	"$( LC_ALL=C awk -F'|' '$4 == "@one-off" { n += $3 } END { print n + 0 }' "$rigTmp/list" )"

echo "-- 2. control lines: the reader finds a walk in each shape and no glob that names one file --"
mkdir -p "$rigTmp/probe/sh-lib"
cat > "$rigTmp/probe/sh-lib/Probe.include" <<'PROBE'
## a comment: grep -l x "$MMDAPP/.local/agents/spawned"/*/*.spawn.md
ProbeOne(){
	list="$( LC_ALL=C grep -l -x -F "session-id: $1" "$MMDAPP"/.local/agents/spawned/*/*.spawn.md 2> /dev/null )"
	for one in "$MMDAPP/.local/agents/spawned"/*/"$1.spawn.md" ; do : ; done
}
ProbeTwo(){
	find "$MMDAPP/.local/agents/spawned" -mindepth 2 -maxdepth 2 -name '*.spawn.md'
	for rec in "${MMDAPP:-/nonexistent}"/.local/agents/spawned/*/*.spawn.md ; do : ; done
}
for top in "$MMDAPP/.local/agents/spawned"/*/*.spawn.md ; do : ; done
PROBE
rigProbe="$( rigPackage="$rigTmp/probe" rigWalks sh-lib/Probe.include | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )"
rigAssert "two functions and the top level, one walk in the first, two in the second, none for the comment or the one-file glob" "$rigProbe" "sh-lib/Probe.include| sh-lib/Probe.include|ProbeOne sh-lib/Probe.include|ProbeTwo sh-lib/Probe.include|ProbeTwo "

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ HOT PATH WALKS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: a read of every run record stands in the tooling with no row saying why: a call path pays the record count each call" >&2
	echo "  fix:  take a kept list or an index (AgentsTools.StartedRecords.include, the spawned-sessions registry, the children lists), or add the row with its reason" >&2
	exit 1
fi
echo "HOT_PATH_WALKS: OK ($rigPass assertions, offline)"
