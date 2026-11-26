#!/usr/bin/env bash
## AgentsHotPathWalksCheck -- the reads of EVERY run record, of every item of a board state, of every
## session store and of every inbox, in the tooling, each on a list with its reason. A working workspace
## holds thousands of run folders under .local/agents/spawned, as many session stores under sessions/,
## and hundreds of items in a board state, so a `grep`, an `awk`, a `find` or a `for` over
## `spawned/*/*.spawn.md`, `sessions/*/<file>` or `board/<state>/*.md` costs each call that asks it, and a call
## path (a schedule pass, a Wait round, a permission gate, a start) must take a kept list or an index
## instead (epic S10.37). This check reads the code, never the clock: a walk is slow code wherever it
## stands, and the list says why each one is still there.
## Guards: every walk of sh-lib and sh-scripts is on the list, matched by the function it stands in (a
## walk at file level, outside any function, matches by file), as often as the list says; every row's
## reason is a named one; a named reason the tooling uses is one the list defines; the control lines find
## a walk in each store-path shape and no glob that names one file. A store path is recognised however
## it is written: the literal, a place function in a command substitution, a variable set by a place
## function's ...Into form, or a variable assigned from the place function.
## Red: a new `grep ... spawned/*/*.spawn.md` in any function of sh-lib fails the first guard.
## Offline: reads the source tree alone; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/AgentsHotPathWalksCheck.XXXXXXXX" )" || exit 1
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
		'sh-lib/board/AgentsTools.BoardHousekeeping.include|AgentsToolsAdvanceSpawnHousekeeping|2|@housekeeping' \
		'sh-lib/board/AgentsTools.BoardHousekeeping.include|AgentsToolsReviewUnseenEscalate|1|@housekeeping' \
		'sh-lib/board/AgentsTools.BoardRoundScan.include|AgentsToolsBoardRecheckDueSection|1|@call-path' \
		'sh-lib/board/AgentsTools.BoardStates.include|AgentsToolsBoardStateCounts|2|@one-off' \
		'sh-lib/board/AgentsTools.ReviewFlow.include|AgentsReviewItemsForRoutine|1|@call-path' \
		'sh-lib/run/AgentsTools.ManagerSessionKill.include|AgentsToolsManagerSessionKill|1|@one-off' \
		'sh-lib/manager/AgentsTools.ManagerSessionRows.include|AgentsToolsManagerSessionScope|2|@one-off' \
		'sh-lib/manager/AgentsTools.ManagerSessionRows.include|AgentsToolsManagerSessionRows|1|@kept' \
		'sh-lib/session/AgentsTools.SessionStore.include|AgentsSessionRowsInto|1|@rebuild' \
		'sh-lib/manager/AgentsTools.OpManagerSessionControlStart.include||1|@rebuild' \
		'sh-lib/wait/AgentsTools.MemberWaitSources.include||1|@call-path' \
		'sh-lib/inbox/AgentsTools.OpUpsertInboxInquiry.include||1|@call-path' \
		'sh-lib/session/AgentsTools.SessionChat.include|AgentsToolsSessionChatThreadSessions|1|@call-path' \
		'sh-lib/session/AgentsTools.SessionComms.include|AgentsToolsSessionCommsSessions|1|@call-path' \
		'sh-lib/session/AgentsTools.SessionComms.include|AgentsToolsSessionCommsTakeAll|1|@call-path' \
		'sh-lib/session/AgentsTools.SessionComms.include|AgentsToolsSessionCommsWork|1|@call-path' \
		'sh-lib/session/AgentsTools.SessionControlStart.include|AgentsToolsSessionControlCheckWorkspace|1|@rebuild' \
		'sh-lib/session/AgentsTools.ChildrenIndex.include|AgentsToolsChildrenIndexRepair|1|@housekeeping' \
		'sh-lib/spawn/AgentsTools.InternOpAgentSpawnProxy.include||3|@rebuild' \
		'sh-lib/session/AgentsTools.StartedRecords.include|AgentsToolsSpawnedAllRecordsInto|1|@call-path' \
		'sh-lib/session/AgentsTools.StartedRecords.include|AgentsToolsSpawnedChildRecords|1|@fallback' \
		'sh-lib/session/AgentsTools.StartedRecords.include|AgentsToolsSpawnedRegistryFile|1|@kept' \
		'sh-lib/session/AgentsTools.SessionStore.include|AgentsSessionFoldersFind|1|@one-off' \
		'sh-lib/session/AgentsTools.SessionControlStart.include|AgentsSessionControlPidRows|1|@one-off' \
		'sh-lib/session/AgentsTools.SessionControlStart.include|AgentsSessionControlRowsInto|1|@one-off' \
		'sh-lib/session/AgentsTools.SessionTranscript.include|AgentsSessionTokensRowsInto|1|@one-off' \
		'sh-lib/session/AgentsTools.SessionTranscript.include|AgentsSessionTokensRollupRows|1|@kept' \
		'sh-lib/spawn/AgentsTools.CleanupSweep.include|AgentsToolsCleanupSweep|1|@housekeeping' \
		'sh-lib/session/AgentsTools.SessionStore.include|AgentsSpawnedRecords|1|@one-off' \
		'sh-lib/spawn/AgentsTools.SpawnSandbox.include|AgentsSessionRigControlRows|1|@kept' \
		'sh-lib/board/AgentsTools.BoardDependencies.include|AgentsToolsBoardDependencies|1|@housekeeping' \
		'sh-lib/session/AgentsTools.SessionChat.include|AgentsToolsSessionChatMessagesToSince|1|@one-off' \
		'sh-lib/inbox/AgentsTools.InternTeamDataReflectionSweep.include||1|@one-off' \
		'sh-lib/inbox/AgentsTools.InboxPlace.include|AgentsToolsInboxFilesInto|1|@call-path' \
		'sh-lib/session/AgentsTools.RegistrySpawnedSessions.include|AgentsToolsRegistryRenderSpawnedSessions|1|@rebuild' \
		'sh-lib/session/AgentsTools.RegistrySpawnedSessions.include|AgentsToolsRegistryRenderSpawnedSessionsKept|5|@rebuild' \
		'sh-lib/session/AgentsTools.RegistrySpawnedSessions.include|AgentsToolsRegistrySpawnedSessionsRebuild|2|@rebuild' \
		'sh-lib/session/AgentsTools.RegistrySpawnedSessions.include|AgentsToolsRegistrySpawnedSessionsRows|2|@rebuild' \
		'sh-lib/team-data/AgentsTools.StrayStore.include|AgentsToolsStrayStoreList|1|@one-off' \
		'sh-lib/board/AgentsTools.BoardDispatchRuns.include|AgentsToolsBoardDispatchRunsTableInto|1|@one-off' \
		'sh-lib/undo/AgentsTools.UndoRecord.include||1|@one-off'
}

## THE READER: a store walk however its path is written, each under the function it stands in.
## A comment line and a `type ... ||` load guard are none. A glob that names one file, and a `case`
## pattern that reads nothing, are none: they cost no process.
rigWalks(){ ## file (relative to the package)
	LC_ALL=C awk -v file="$1" '
## The walk reader: one walk of a store however its path is written. Each store reference is
## A walk is matched by function; a top-level walk keeps an empty function.
/^[A-Za-z_][A-Za-z0-9_]*\(\)[ \t]*\{/ { fn = $0 ; sub( /\(\).*/, "", fn ) ; next ; }
/^\}/ { fn = "" ; next ; }
/^[ \t]*(#|type )/ { next ; }

{

	n = $0

	## spawned store walks.
	if ( n ~ /spawned"?\/\*\/\*\.spawn\.md|spawned"?\/\*\/"?\*\.spawn|[Ss]pawned"\*\/\*\.spawn\.md|find "?\$[{A-Za-z_}:-]*\/?\.local\/agents\/spawned|find "\$[A-Za-z]+Agents"\/spawned/ ) { print file "|" fn ; next ; }
	if ( n ~ /spawned"?\/\*\/"? *(;|do)/ ) { print file "|" fn ; next ; }
	## A stat, ls or test that takes a glob over every folder of a store: one syscall per folder, on each call.
	if ( n ~ /(^|[^A-Za-z0-9_.-])(stat|ls|test|\[)[ \t][^|;]*(spawned|agents\/sessions|inboxes|board)"?\/\*\/"?([ )\x27]|$)/ ) { print file "|" fn ; next ; }
	## A helper whose whole job is such a walk is a walk at each of its callers, where the cost lands.
	if ( n ~ /AgentsSpawnedStoreNewestInto([^A-Za-z]|$)/ ) { print file "|" fn ; next ; }
	## board store walks.
	if ( n ~ /board"?\/(\*|[a-z-]+|"?\$[a-zA-Z{}:-]+"?)\/[a-z.-]*\*[a-z.-]*\.md|board"?\/\*\/"?\*[" ;]|find "?\$\{?MDAT_DATA_ROOT[^ ]*board/ ) { print file "|" fn ; next ; }
	## session-store and inbox walks; a case pattern or a one-file glob is none.
	if ( n ~ /agents\/sessions"?\/\*\/[^ ]*\)/ ) { next ; }
	if ( n ~ /sessions"?\/\*\/[a-z.]*\/?"?\$/ ) { next ; }
	if ( n ~ /inboxes"?\/\*\/[^ ]*\)|inboxes"?\/[A-Za-z0-9_.-]+(\/[A-Za-z0-9_.-]+)?"?\/\*[^ ]*\)/ ) { next ; }
	if ( n ~ /agents\/sessions"?\/\*\/|inboxes"?\/\*\/|inboxes"?\/[A-Za-z0-9_.-]+(\/[A-Za-z0-9_.-]+)?"?\/\*|find "?\$\{?MMDAPP[^ ]*\/(sessions|inboxes)|find "?\$\{?MDAT_DATA_ROOT[^ ]*inboxes/ ) { print file "|" fn ; next ; }
	## registry rebuilds over the spawned store, read whole by design.
	if ( n ~ /AgentsToolsRegistrySpawnedSessionsRebuild|AgentsToolsRegistrySpawnedSessionsRows([^A-Za-z]|$)|AgentsToolsRegistryRenderSpawnedSessions([^A-Za-z]|$)/ ) { print file "|" fn ; }
}
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
	FILENAME == ARGV[1] { if ( $0 == "" ) next ; want[$1 "|" $2] = $3 + 0 ; reason[$1 "|" $2] = $4 ; next ; }
	{ got[$0]++ ; }
	END {
		for ( key in got ) { if ( ! ( key in want ) ) print "NOT ON THE LIST: " key " (" got[key] " walk(s))" ; }
		for ( key in want ) { if ( ( key in got ? got[key] : 0 ) != want[key] ) print "LIST: " key " holds " ( key in got ? got[key] : 0 ) " walk(s), the list says " want[key] ; }
	}
' "$rigTmp/list" "$rigTmp/walks" | LC_ALL=C sort )"
rigAssert "every read of every run record is on the list, and every row stands in the code as often as it says" "${rigGuard:-none}" none
rigAssert "every row's reason is a named one" "$( LC_ALL=C awk -F'|' 'FNR == NR { named[$1] = 1 ; next ; } { if ( ! ( $4 in named ) ) bad++ ; } END { print bad + 0 ; }' "$rigTmp/reasons" "$rigTmp/list" )" 0
rigAssert "every named reason is used by a row" "$( LC_ALL=C awk -F'|' 'FNR == NR { used[$4] = 1 ; next ; } { if ( ! ( $1 in used ) ) bad++ ; } END { print bad + 0 ; }' "$rigTmp/list" "$rigTmp/reasons" )" 0
printf 'the debt: %s walk(s) on a call path, %s kept, %s behind an index, %s registry rebuilds, %s housekeeping, %s one-off\n' \
	"$( LC_ALL=C awk -F'|' '$4 == "@call-path" { n += $3 ; } END { print n + 0 ; }' "$rigTmp/list" )" \
	"$( LC_ALL=C awk -F'|' '$4 == "@kept" { n += $3 ; } END { print n + 0 ; }' "$rigTmp/list" )" \
	"$( LC_ALL=C awk -F'|' '$4 == "@fallback" { n += $3 ; } END { print n + 0 ; }' "$rigTmp/list" )" \
	"$( LC_ALL=C awk -F'|' '$4 == "@rebuild" { n += $3 ; } END { print n + 0 ; }' "$rigTmp/list" )" \
	"$( LC_ALL=C awk -F'|' '$4 == "@housekeeping" { n += $3 ; } END { print n + 0 ; }' "$rigTmp/list" )" \
	"$( LC_ALL=C awk -F'|' '$4 == "@one-off" { n += $3 ; } END { print n + 0 ; }' "$rigTmp/list" )"

echo "-- 2. control lines: the reader finds a walk in each store-path shape and no one-file glob or case pattern --"
mkdir -p "$rigTmp/probe/sh-lib"
cat > "$rigTmp/probe/sh-lib/Probe.include" <<'PROBE'
## a comment: grep -l x "$MMDAPP/.local/agents/spawned"/*/*.spawn.md
type AgentsToolsX > /dev/null 2>&1 || . "x"
ProbeSpawnedLiteral(){
	list="$( LC_ALL=C grep -l -x -F "session-id: $1" "$MMDAPP"/.local/agents/spawned/*/*.spawn.md 2> /dev/null )"
	for one in "$MMDAPP/.local/agents/spawned"/*/"$1.spawn.md" ; do : ; done
}
ProbeSpawnedCommandSub(){
	grep -l -x -F "session-id: $1" "$MMDAPP/.local/agents/spawned"/*/*.spawn.md 2> /dev/null
}
ProbeSpawnedInto(){
	for rec in "$MMDAPP/.local/agents/spawned"/*/*.spawn.md ; do : ; done
}
ProbeBoardInto(){
	for f in "$MDAT_DATA_ROOT/board"/review/*.md ; do : ; done
}
ProbeInboxCommandSub(){
	for f in "$MDAT_DATA_ROOT/inboxes/magic-coordinator/incoming"/*.md ; do : ; done
}
ProbeInboxCase(){
	case "$x" in inboxes/*/*) return 0 ;; esac
}
for top in "$MMDAPP/.local/agents/spawned"/*/*.spawn.md ; do : ; done
PROBE
rigProbe="$( rigPackage="$rigTmp/probe" rigWalks sh-lib/Probe.include | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )"
rigAssert "every store-path shape and the top level, none for the comment, the one-file glob or the inbox case" "$rigProbe" "sh-lib/Probe.include| sh-lib/Probe.include|ProbeBoardInto sh-lib/Probe.include|ProbeInboxCommandSub sh-lib/Probe.include|ProbeSpawnedCommandSub sh-lib/Probe.include|ProbeSpawnedInto sh-lib/Probe.include|ProbeSpawnedLiteral "
cat > "$rigTmp/probe/sh-lib/ProbeSkip.include" <<'PROBE'
ProbeSkip(){
	for one in "$x"/sessions/*/"$ref.md" ; do : ; done
	case "$y" in sessions/*/*) return 0 ;; esac
}
ProbeHit(){
	find "$MMDAPP/.local/agents/sessions" -maxdepth 2 -type d -name wait -mtime +7
}
ProbeStat(){
	stamp="$( LC_ALL=C stat -f '%m' "$MMDAPP/.local/agents/spawned" "$MMDAPP/.local/agents/spawned"/*/ 2> /dev/null )"
}
ProbeLs(){
	ls -d "$MDAT_DATA_ROOT/inboxes"/*/ > /dev/null
}
ProbeTest(){
	[ -d "$MMDAPP/.local/agents/sessions"/*/ ] || :
}
ProbeOneStat(){
	stamp="$( LC_ALL=C stat -f '%m' "$MMDAPP/.local/agents/spawned" "$MMDAPP/.local/agents/spawned/$1"/ 2> /dev/null )"
}
ProbeHelperCall(){
	AgentsSpawnedStoreNewestInto stamp "$MMDAPP"
}
PROBE
rigProbe="$( rigPackage="$rigTmp/probe" rigWalks sh-lib/ProbeSkip.include | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )"
rigAssert "a one-file sessions glob, a sessions case and a stat of one named folder read nothing; a find over the sessions store, a stat, ls or test over every folder of a store, and a call of the walking stamp are walks" "$rigProbe" "sh-lib/ProbeSkip.include|ProbeHelperCall sh-lib/ProbeSkip.include|ProbeHit sh-lib/ProbeSkip.include|ProbeLs sh-lib/ProbeSkip.include|ProbeStat sh-lib/ProbeSkip.include|ProbeTest "

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ HOT PATH WALKS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: a read of every run record stands in the tooling with no row saying why: a call path pays the record count each call" >&2
	echo "  fix:  take a kept list or an index (AgentsTools.StartedRecords.include, the spawned-sessions registry, the children lists), or add the row with its reason" >&2
	exit 1
fi
echo "HOT_PATH_WALKS: OK ($rigPass assertions, offline)"
