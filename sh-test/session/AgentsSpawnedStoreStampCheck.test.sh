#!/usr/bin/env bash
## AgentsSpawnedStoreStampCheck -- the spawned/ store's stamp: spawned/ itself, its own clock moved by AgentsSpawnRecordWrite and
## AgentsSpawnRecordRemove after every record they write or remove (sh-lib/session/AgentsTools.SessionStore.include), and the
## readers that keep a list against it (AgentsSpawnedStoreStampInto, sh-lib/session/AgentsTools.StartedRecords.include).
## 1. Static: every `>`, `>>`, `mv`, `cp` or `rm` onto a run record, and every `rm` of a folder of spawned/, in sh-lib and
##    sh-scripts stands in one of the two store functions. Red: a `> "$record"` in any other function.
## 2. Rig: a session's records listed, then a second record joined into its folder and closed, within the same second where the
##    clock allows: the session's list shows it, and the started list sees it start and close. Red: the two store functions
##    leave the stamp where it was.
## 3. Rig: a registry rebuild whose walk a record joins, and which lands a second later, is not taken for the store as it stands:
##    the registry as it stands lists that record. Red: a registry dated when it landed, and a reader that compares by order.
## 4. Rig: two rebuilds racing, a record joined between them: the slow one lands, then the one started after the join, so the
##    registry ends with the newer rows under the stamp as it stands. Red: rebuilds with no lock, the older rows landing last.
## Offline: a rig workspace of its own; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/AgentsSpawnedStoreStampCheck.XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}

## THE READER: `<file>|<function>|<line>` for each write onto a run record outside the two store functions. A record is a word
## ending in `.spawn.md`, a variable assigned one or a store function's record path, or a parameter its function's comment names
## a spawn, run or parent record or a tracking file. A write is the target of `>` or `>>`, the destination of `mv` or `cp`, or a
## word `rm` takes, where a folder of spawned/ counts too. Quotes and `$( )` left open at the end of a line carry to the next.
rigWriters(){ ## files (relative to the current folder)
	LC_ALL=C awk '
function splitWords( text, wordList,   at, ch, count, word ) {
	count = 0 ; word = ""
	for ( at = 1 ; at <= length( text ) ; at++ ) {
		ch = substr( text, at, 1 )
		if ( inSingle ) { if ( ch == "\x27" ) inSingle = 0 ; continue ; }
		if ( ch == "\\" ) { word = word substr( text, at, 2 ) ; at++ ; continue ; }
		if ( ch == "\"" ) { inDouble = ! inDouble ; word = word ch ; continue ; }
		if ( ch == "\x27" && ! inDouble ) { inSingle = 1 ; continue ; }
		if ( ch == "(" && ( ! inDouble || substr( text, at - 1, 1 ) == "$" ) ) { parenQuote[++depth] = inDouble ; inDouble = 0 ; word = word ch ; continue ; }
		if ( ch == ")" && depth > 0 && ! inDouble ) { inDouble = parenQuote[depth--] ; word = word ch ; continue ; }
		if ( ! inDouble && depth == 0 && ( ch == " " || ch == "\t" || ch == ";" ) ) {
			if ( word != "" ) wordList[++count] = word
			if ( ch == ";" ) wordList[++count] = ";"
			word = "" ; continue
		}
		word = word ch
	}
	if ( word != "" && ! inSingle && ! inDouble && depth == 0 ) wordList[++count] = word
	return count
}
function bareName( word,   name ) {
	name = word ; gsub( /^"|"$/, "", name )
	if ( name !~ /^\$\{?[A-Za-z0-9_]+\}?$/ ) return ""
	gsub( /[${}]/, "", name )
	return name
}
function isRecord( word, kind,   name, plain ) {
	plain = word ; gsub( /^"|"$/, "", plain )
	if ( plain ~ /\.spawn\.md$/ ) return 1
	name = bareName( word )
	if ( name != "" && ( ( scope SUBSEP name ) in recordVar ) ) return 1
	if ( name ~ /^[1-9]$/ && ( name in recordParam ) ) return 1
	if ( kind == "rm" && name != "" && ( ( scope SUBSEP name ) in folderVar ) ) return 1
	if ( kind == "rm" && plain ~ /agents\/spawned/ ) return 1
	return 0
}
function isEnd( word ) { return word ~ /^(;|;;|&&|\|\||\||\}|\)|then|do|done|fi|else)$/ || word ~ /^[0-9]*>/ ; }
function report( ) { if ( fn != "AgentsSpawnRecordWrite" && fn != "AgentsSpawnRecordRemove" ) print FILENAME "|" fn "|" FNR ; }
FNR == 1 { fn = "" ; scope = FILENAME SUBSEP "" ; split( "", recordParam ) ; inSingle = 0 ; inDouble = 0 ; depth = 0 ; }
/^[A-Za-z_][A-Za-z0-9_]*\(\)[ \t]*\{/ {
	fn = $0 ; sub( /\(\).*/, "", fn ) ; scope = FILENAME SUBSEP fn ; split( "", recordParam )
	paramText = $0 ; if ( sub( /^[^#]*##[ \t]*/, "", paramText ) ) { paramCount = split( paramText, paramName, /, */ ) ; for ( at = 1 ; at <= paramCount ; at++ ) if ( paramName[at] ~ /spawn record|run record|parent record|tracking file/ ) recordParam[at] = 1 ; }
	next
}
/^\}/ { fn = "" ; scope = FILENAME SUBSEP "" ; split( "", recordParam ) ; next ; }
/^[ \t]*#/ { next ; }
{
	split( "", words ) ; wordCount = splitWords( $0, words )
	for ( at = 1 ; at <= wordCount ; at++ ) {
		word = words[at]
		if ( word ~ /^(local )?[A-Za-z_][A-Za-z0-9_]*=/ ) {
			name = word ; sub( /=.*/, "", name ) ; value = word ; sub( /^[^=]*=/, "", value )
			from = bareName( value )
			if ( value ~ /\.spawn\.md"?$/ || value ~ /AgentsToolsSessionRoutineStackRecord|AgentsSessionRun(Own)?RecordInto|AgentsSpawnRecordFindInto/ \
				|| ( from ~ /^[1-9]$/ && ( from in recordParam ) ) || ( from != "" && ( ( scope SUBSEP from ) in recordVar ) ) ) recordVar[scope, name] = 1
			if ( value ~ /agents\/spawned"?$|agentsSpawnedStoreLeaf"?$/ || ( from != "" && ( ( scope SUBSEP from ) in folderVar ) ) ) folderVar[scope, name] = 1
		}
		if ( word ~ /^(AgentsSpawnRecordInto|AgentsSpawnRecordFindInto|AgentsSessionRunOwnRecordInto|AgentsSessionRunRecordInto)$/ && at < wordCount ) recordVar[scope, words[at + 1]] = 1
		if ( word == "AgentsSpawnedStoreDirInto" && at < wordCount ) folderVar[scope, words[at + 1]] = 1
		if ( word == "for" && at + 2 <= wordCount && words[at + 2] == "in" && at + 3 <= wordCount ) {
			if ( words[at + 3] ~ /\.spawn\.md"?$/ ) recordVar[scope, words[at + 1]] = 1
			else if ( words[at + 3] ~ /spawned"?\/\*\/"?$|Root"?\/\*\/"?$/ && $0 ~ /spawn/ ) folderVar[scope, words[at + 1]] = 1
		}
		if ( ( word == ">" || word == ">>" ) && at < wordCount && isRecord( words[at + 1], "write" ) ) { report( ) ; break ; }
		if ( word ~ /^>>?"/ && isRecord( substr( word, index( word, "\"" ) ), "write" ) ) { report( ) ; break ; }
		if ( word == "mv" || word == "cp" ) {
			last = "" ; for ( scanAt = at + 1 ; scanAt <= wordCount && ! isEnd( words[scanAt] ) ; scanAt++ ) if ( words[scanAt] !~ /^-/ ) last = words[scanAt]
			if ( last != "" && isRecord( last, "write" ) ) { report( ) ; break ; }
		}
		if ( word == "rm" ) {
			hit = 0 ; for ( scanAt = at + 1 ; scanAt <= wordCount && ! isEnd( words[scanAt] ) ; scanAt++ ) if ( words[scanAt] !~ /^-/ && isRecord( words[scanAt], "rm" ) ) hit = 1
			if ( hit ) { report( ) ; break ; }
		}
	}
}
	' "$@"
}

echo "-- 1. every write onto a run record stands in the two store functions --"
( cd "$rigPackage" && find sh-lib sh-scripts -type f \( -name '*.include' -o -name '*.sh' \) ! -name '*.keep' | LC_ALL=C sort ) > "$rigTmp/files"
rigAssert "control: the tooling's files are read, many of them" "$( [ "$( wc -l < "$rigTmp/files" | LC_ALL=C tr -d ' ' )" -ge 150 ] && echo many )" many
rigFound="$( cd "$rigPackage" && rigWriters $( cat "$rigTmp/files" ) | LC_ALL=C tr '\n' ' ' )"
rigAssert "no write onto a run record, and no removal of a folder of spawned/, past AgentsSpawnRecordWrite and AgentsSpawnRecordRemove" "${rigFound:-none}" none
mkdir -p "$rigTmp/probe"
cat > "$rigTmp/probe/Probe.include" <<'PROBE'
## a comment: printf x > "$record.spawn.md"
ProbeLiteral(){
	printf '%s\n' "$1" > "$MMDAPP/.local/agents/spawned/$1/$1.spawn.md"
}
ProbeVariable(){
	local probeRecord="$MMDAPP/.local/agents/spawned/$1/$1.spawn.md" probeTemp
	probeTemp="$( mktemp "$probeRecord.XXXXXX" )"
	printf '%s\n' "$( awk '
		{ print "it" ; }
	' "$probeRecord" )" > "$probeTemp" && mv -f "$probeTemp" "$probeRecord"
}
ProbeParameter(){ ## spawn record file, value
	{ printf '%s\n' "$2" > "$1.new" && mv -f "$1.new" "$1" ; } 2> /dev/null
}
ProbeFolder(){
	local probeFolder=""
	AgentsSpawnedStoreDirInto probeFolder "$MMDAPP"
	rm -rf -- "$probeFolder"
}
ProbeQuiet(){ ## spawn record file
	printf '%s\n' x > "${1%.spawn.md}.armed"
	printf '%s\n' x > "$MMDAPP/.local/temp/x" 2> /dev/null
	rm -f "$1.new"
}
AgentsSpawnRecordWrite(){
	cat > "$writeTemp" && mv -f "$writeTemp" "$writeDir/$1.spawn.md"
}
PROBE
rigProbe="$( cd "$rigTmp/probe" && rigWriters Probe.include | LC_ALL=C sed 's/|[0-9]*$//' | LC_ALL=C tr '\n' ' ' )"
rigAssert "controls: a literal record, a record variable, a record parameter and a store folder are writes; a side file, a temp, a comment and the store function are none" \
	"$rigProbe" "Probe.include|ProbeLiteral Probe.include|ProbeVariable Probe.include|ProbeParameter Probe.include|ProbeFolder "

echo "-- 2. a record joined into a listed session and closed in the same second is listed, and its close is seen --"
rigWs="$rigTmp/ws" ; rigOrigin="$MDLT_ORIGIN"
mkdir -p "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions" "$rigWs/.local/temp" || exit 1
export MMDAPP="$rigWs"
. "$rigPackage/sh-test/check-fixtures/rig-owner-writes.include.sh" || { echo "⛔ the fixture writer would not load" >&2 ; exit 1 ; }
. "$rigPackage/sh-lib/session/AgentsTools.StartedRecords.include" || exit 1
. "$rigPackage/sh-lib/schedule/AgentsTools.StartedRecords.include" || exit 1
. "$rigPackage/sh-lib/spawn/AgentsTools.SpawnProxyClose.include" || exit 1
rigRecord(){ ## session, run
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: rig-member\nstatus: spawn-started\n---\n\n# rig run %s\n' "$1" "$2" "$2"
}
rigRecord S-rig S-rig | rigOwnerSpawnPut S-rig || { echo "⛔ the session's record could not be written" >&2 ; exit 1 ; }
rigOwnerSessionFolder S-rig > /dev/null 2>&1 || { echo "⛔ the session's folder could not be made" >&2 ; exit 1 ; }
## The session's list is primed in a second after the store last changed, so the list is kept.
sleep 1
rigPrimed="$( AgentsToolsSpawnedSessionRecords S-rig own | LC_ALL=C sed 's#.*/##' | LC_ALL=C tr '\n' ' ' )"
rigAssert "control: the primed list holds the session's own record" "$rigPrimed" "S-rig.spawn.md "
rigAssert "control: the primed list is kept" "$( [ -s "$rigWs/.local/agents/sessions/S-rig/records.kept" ] && echo kept )" kept
rigStarted="$( AgentsToolsSpawnedStartedRecords | LC_ALL=C sed 's#.*/##' | LC_ALL=C tr '\n' ' ' )"
rigAssert "control: the primed started list holds the session's record" "$rigStarted" "S-rig.spawn.md "
## The join, the close and the reads start on a fresh second, so they run within it where the host is not slow.
rigSecond="$( date +%s )"
while [ "$( date +%s )" = "$rigSecond" ] ; do sleep 0.05 ; done
rigSecond="$( date +%s )"
rigRecord S-rig R-rig | rigOwnerStore AgentsSpawnRecordWrite R-rig S-rig || { echo "⛔ the joined record could not be written" >&2 ; exit 1 ; }
rigAssert "the joined record is listed with the session's own" "$( AgentsToolsSpawnedSessionRecords S-rig own | LC_ALL=C sed 's#.*/##' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "R-rig.spawn.md S-rig.spawn.md "
rigAssert "the started list shows the joined record" "$( AgentsToolsSpawnedStartedRecords | LC_ALL=C sed 's#.*/##' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "R-rig.spawn.md S-rig.spawn.md "
AgentsToolsSpawnProxyCloseSandboxOnce "$rigWs/.local/agents/spawned/S-rig/R-rig.spawn.md" succeeded 0 > /dev/null 2>&1 || { echo "⛔ the joined record could not be closed" >&2 ; exit 1 ; }
rigAssert "control: the joined record is closed" "$( LC_ALL=C sed -n 's/^status: //p' "$rigWs/.local/agents/spawned/S-rig/R-rig.spawn.md" )" spawn-succeeded
rigAssert "the started list sees the close" "$( AgentsToolsSpawnedStartedRecords | LC_ALL=C sed 's#.*/##' | LC_ALL=C tr '\n' ' ' )" "S-rig.spawn.md "
rigAssert "the closed record stays listed with its session" "$( AgentsToolsSpawnedSessionRecords S-rig own | LC_ALL=C sed 's#.*/##' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "R-rig.spawn.md S-rig.spawn.md "
[ "$( date +%s )" = "$rigSecond" ] && echo "  note: the join, the close and the reads ran in one second" || echo "  note: the join, the close and the reads crossed a second"
AgentsSpawnRecordRemove R-none > /dev/null 2>&1 ; rigOwnerStore AgentsSpawnRecordRemove S-rig
rigAssert "the store's removal takes the session's folder" "$( [ -e "$rigWs/.local/agents/spawned/S-rig" ] && echo stayed || echo gone )" gone
rigFound="$( AgentsToolsSpawnedSessionRecords S-rig own | LC_ALL=C tr '\n' ' ' )"
rigAssert "the session's list sees the removal" "${rigFound:-none}" none

echo "-- 3. a registry rebuild that a record joins during its walk is rebuilt again by the reader --"
. "$rigPackage/sh-lib/team-data/AgentsTools.Registries.include" || exit 1
. "$rigPackage/sh-lib/session/AgentsTools.RegistrySpawnedSessions.include" || exit 1
rigRecord T-rig T-rig | rigOwnerSpawnPut T-rig || { echo "⛔ the session's record could not be written" >&2 ; exit 1 ; }
rigFound="$( AgentsToolsSpawnedRegistryFile )"
rigAssert "control: the registry as it stands lists the session" "$( LC_ALL=C grep -c -w -F T-rig "$rigFound" 2> /dev/null )" 1
## The slow rebuild: its rows are read, a record joins the session, and the rows land a second later, without the record.
eval "rigRowsReal$( declare -f AgentsToolsRegistrySpawnedSessionsRows | LC_ALL=C sed '1s/^AgentsToolsRegistrySpawnedSessionsRows//' )"
AgentsToolsRegistrySpawnedSessionsRows(){
	rigRowsReal > "$rigTmp/rows"
	rigRecord T-rig U-rig | rigOwnerStore AgentsSpawnRecordWrite U-rig T-rig || return 1
	sleep 1
	cat "$rigTmp/rows"
}
( AGENTS_REGISTRY_HOUSEKEEPING=1 ; export AGENTS_REGISTRY_HOUSEKEEPING ; AgentsToolsRegistrySpawnedSessionsRebuild ) > /dev/null 2>&1
eval "AgentsToolsRegistrySpawnedSessionsRows$( declare -f rigRowsReal | LC_ALL=C sed '1s/^rigRowsReal//' )"
rigAssert "control: the slow rebuild left the joined record out" "$( LC_ALL=C grep -c -w -F U-rig "$rigWs/.local/agents/spawned-sessions.registry" 2> /dev/null )" 0
rigFound="$( AgentsToolsSpawnedRegistryFile )"
rigAssert "the registry as it stands lists the record that joined during the slow rebuild" "$( LC_ALL=C grep -c -w -F U-rig "$rigFound" 2> /dev/null )" 1

echo "-- 4. two rebuilds racing, a record joined between them, end with the newer rows under the current stamp --"
rigRecord V-rig V-rig | rigOwnerSpawnPut V-rig || { echo "⛔ the session's record could not be written" >&2 ; exit 1 ; }
## The older rebuild, in the background: its rows are read, a record joins, it says so, and its rows land two seconds later.
( AgentsToolsRegistrySpawnedSessionsRows(){
	rigRowsReal > "$rigTmp/rows-old"
	rigRecord V-rig W-rig | rigOwnerStore AgentsSpawnRecordWrite W-rig V-rig || return 1
	: > "$rigTmp/joined"
	sleep 2
	cat "$rigTmp/rows-old"
  }
  AGENTS_REGISTRY_HOUSEKEEPING=1 ; export AGENTS_REGISTRY_HOUSEKEEPING ; AgentsToolsRegistrySpawnedSessionsRebuild ) > /dev/null 2>&1 &
rigOlder=$!
rigWaited=0
while [ ! -f "$rigTmp/joined" ] && [ "$rigWaited" -lt 100 ] ; do sleep 0.1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "control: the record joined during the older rebuild" "$( [ -f "$rigTmp/joined" ] && echo joined )" joined
( AGENTS_REGISTRY_HOUSEKEEPING=1 ; export AGENTS_REGISTRY_HOUSEKEEPING ; AgentsToolsRegistrySpawnedSessionsRebuild ) > /dev/null 2>&1
wait "$rigOlder"
rigAssert "the registry holds the record joined between the two rebuilds" "$( LC_ALL=C grep -c -w -F W-rig "$rigWs/.local/agents/spawned-sessions.registry" 2> /dev/null )" 1
rigAssert "the registry is dated with the stamp as it stands" \
	"$( LC_ALL=C stat -f '%m' "$rigWs/.local/agents/spawned-sessions.registry" 2> /dev/null || LC_ALL=C stat -c '%Y' "$rigWs/.local/agents/spawned-sessions.registry" 2> /dev/null )" \
	"$( LC_ALL=C stat -f '%m' "$rigWs/.local/agents/spawned" 2> /dev/null || LC_ALL=C stat -c '%Y' "$rigWs/.local/agents/spawned" 2> /dev/null )"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SPAWNED STORE STAMP CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: a record written past the store's own writer leaves the stamp where it was, and every list kept against it misses that write" >&2
	echo "  fix:  write the record through AgentsSpawnRecordWrite and remove a folder through AgentsSpawnRecordRemove" >&2
	exit 1
fi
echo "SPAWNED_STORE_STAMP: OK ($rigPass assertions, offline)"
