# AgentsDispatcherStatsRuns.awk -- F7.11: the runs row of the stats store, derived from the run records. -v list=<file> names the files to read, one path a line,
# so that no argument list limits it: the token files (sessions/<run>/tokens, `<in> <cache-read> <cache-write> <out>`, the running sum the harness keeps) and the
# run records (spawned/<session>/<run>.spawn.md); a token file is told from a record by its name. One TAB-separated row for each record:
#   run session member routine status started-at resolved-at day workspace executing paying preset credential in cache-read cache-write out exit-code
# An empty or absent field is `-`, absent tokens are 0. The day is the date part of started-at as the record writes it. The run is the record's `spawn-id:`
# (its file name without .spawn.md where it has none). Nothing is read from anywhere else.

function base(path,    parts, count) { count = split(path, parts, "/") ; return parts[count] }
function runOfTokens(path,    parts, count) { count = split(path, parts, "/") ; return parts[count - 1] }
function dash(text) { return ( text == "" ) ? "-" : text }
function readTokens(path,    line, parts) {
	if ( ( getline line < path ) > 0 && split( line, parts, " " ) >= 4 ) { tok[runOfTokens( path )] = ( parts[1] + 0 ) "\t" ( parts[2] + 0 ) "\t" ( parts[3] + 0 ) "\t" ( parts[4] + 0 ) }
	close( path )
}
function readRecord(path,    line, front, run, session, member, routine, status, started, resolved, workspace, executing, paying, preset, credential, exitCode, at, key, value, day, tokenText, first) {
	front = 0 ; first = 1
	while ( ( getline line < path ) > 0 ) {
		if ( first ) { first = 0 ; if ( line == "---" ) { front = 1 } ; continue }
		if ( front != 1 ) { break }
		if ( line == "---" ) { break }
		at = index( line, ": " )
		if ( at == 0 ) { continue }
		key = substr( line, 1, at - 1 ) ; value = substr( line, at + 2 )
		if ( key == "spawn-id" ) { run = value }
		else if ( key == "session-id" ) { session = value }
		else if ( key == "owner" ) { member = value }
		else if ( key == "routine" ) { routine = value }
		else if ( key == "status" ) { status = value }
		else if ( key == "started-at" ) { started = value }
		else if ( key == "resolved-at" ) { resolved = value }
		else if ( key == "workspace" ) { workspace = value }
		else if ( key == "executing-workspace" ) { executing = value }
		else if ( key == "paying-workspace" ) { paying = value }
		else if ( key == "preset" ) { preset = value }
		else if ( key == "credential" ) { credential = value }
		else if ( key == "exit-code" ) { exitCode = value }
	}
	close( path )
	if ( run == "" ) { run = base( path ) ; sub( /\.spawn\.md$/, "", run ) }
	day = substr( started, 1, 10 ) ; if ( day !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ ) { day = "-" }
	tokenText = ( run in tok ) ? tok[run] : "0\t0\t0\t0"
	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", run, dash( session ), dash( member ), dash( routine ), dash( status ), dash( started ), dash( resolved ), day, dash( workspace ), dash( executing ), dash( paying ), dash( preset ), dash( credential ), tokenText, dash( exitCode )
}
BEGIN {
	count = 0
	while ( ( getline path < list ) > 0 ) {
		if ( path == "" ) { continue }
		if ( base( path ) == "tokens" ) { readTokens( path ) } else { records[++count] = path }
	}
	close( list )
	for ( at = 1 ; at <= count ; at++ ) { readRecord( records[at] ) }
	exit
}
