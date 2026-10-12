#!/usr/bin/env awk

## AgentsGrantsSessionIndex.awk -- one session's permission index (AgentsTools.Grants.include):
## the member's own rows of the grants index joined with the session's own grants, run with
## AgentsGrantsPattern.awk loaded first. The first file is the grants index; every further
## one is the `grants` file of one session store, read as AgentsToolsPermissionGrantScan
## reads it: a grant of this member's own (its record's owner), signed by someone else.
##   -v member=<name>
##   ENVIRON agentsGrantsSessionHeader: this index's header line
##   ENVIRON agentsGrantsSandboxIn, agentsGrantsSandboxOut: the session's sandbox folders
##   ENVIRON agentsGrantsOrigin: this origin's skillset, resolved
##   ENVIRON agentsGrantsStores: the store dirs the session reads, one per line
##       These five are text: -v decodes a backslash in a value, and takes no newline in every
##       awk. -v header, sandboxIn, sandboxOut, origin and stores=<store dir> are each read
##       where the environment names none: a harness started before they went there holds the
##       caller that passes them so.
##   ENVIRON agentsGrantsEnded: the store dirs whose session has ended, one per line
##   ENVIRON agentsGrantsItemRuns: the stores of the member's other runs on the same board item
##       (AgentsToolsGrantsItemRuns), one `<store dir><TAB><item><TAB><coworking session store,
##       or -><TAB><only, task, or empty>` line each: a session grant there holds while that
##       item is open and that session runs, whatever became of the run it was given to, and a
##       task grant there while the item it names is open. A store marked `only` is read for
##       those two alone; one marked `task` for its task grants alone, the rest having ended.
## Prints, TAB-separated, and nothing at all when the grants index is not one:
##   <header>
##   store   <dir>                                   each store, for the freshness test
##   ceiling <pattern> <read-only|read-write> <place> <path>   deepest first
##   allow   " <tools> " <pattern> <floor|standing>
##   session <tool> <pattern> <ref> <store>
##   runs    <tool> <pattern> <ref> <item> <coworking session store, or ->
##   task    <tool> <pattern> <item>
##   once    <tool> <pattern> <stamp epoch> <ref>
##   end
## A target a refusal names matches exactly; a passed or set one as AgentsToolsPermissionCovers
## reads it. A revoked grant (<store>/revoked/<ref>) is left out, and so is a session grant of a
## store whose session has ended. A once row's expiry, a once row's use, a task's item and a
## session row's end are checked at the call. A runs row is a session grant of one of the
## member's other runs on the same item: its item and that session's end are checked there too.
##
## -v mode=list (--intern-op-permission-list): the member's effective grants instead, one row
## each, TAB-separated: kind, read|write|<tool>, target, place (name:relative, or -), origin,
## expiry -- with -v now=<epoch> -v ttl=<once TTL> and ENVIRON agentsGrantsUsed (used-up once
## markers, <store>/consumed/<ref>, one per line), agentsGrantsBoard and agentsGrantsOpenStates.
## In this mode a session grant of a store agentsGrantsItemRuns names is listed as held while
## that item is open and that session runs: its caller names the store only while that is so,
## or marks it `task`.

BEGIN {
	FS = "\t" ; OFS = "\t" ; ok = 0 ; rowCount = 0
	readTools = " Read Grep Glob " ; writeTools = " Read Edit Write Execute Grep Glob "
	fileTools = writeTools
	n = split( ENVIRON["agentsGrantsEnded"], endedList, "\n" )
	for ( i = 1 ; i <= n ; i++ ) if ( endedList[i] != "" ) endedStore[endedList[i]] = 1
	n = split( ENVIRON["agentsGrantsItemRuns"], runsList, "\n" )
	for ( i = 1 ; i <= n ; i++ ) {
		if ( split( runsList[i], runsPart, "\t" ) < 3 || runsPart[1] == "" || runsPart[2] == "" ) continue
		runsItem[runsPart[1]] = runsPart[2] ; runsSession[runsPart[1]] = runsPart[3]
		runsOnly[runsPart[1]] = ( runsPart[4] != "" ) ; runsEnded[runsPart[1]] = ( runsPart[4] == "task" )
	}
	if ( mode == "list" ) {
		n = split( ENVIRON["agentsGrantsUsed"], usedList, "\n" )
		for ( i = 1 ; i <= n ; i++ ) if ( usedList[i] != "" ) usedOnce[usedList[i]] = 1
		boardRoot = ENVIRON["agentsGrantsBoard"] ; openStates = ENVIRON["agentsGrantsOpenStates"]
	}
	else {
		if ( header == "" ) header = ENVIRON["agentsGrantsSessionHeader"]
		if ( sandboxIn == "" ) sandboxIn = ENVIRON["agentsGrantsSandboxIn"]
		if ( sandboxOut == "" ) sandboxOut = ENVIRON["agentsGrantsSandboxOut"]
		if ( origin == "" ) origin = ENVIRON["agentsGrantsOrigin"]
		if ( stores == "" ) stores = ENVIRON["agentsGrantsStores"]
	}
}

FNR == 1 && NR == 1 { if ( index( $0, "myx.distro grants.index " ) != 1 ) exit 1 ; ok = 1 ; next ; }

## The grants index: this member's read and write rows, and the ceiling rows.
NR == FNR {
	if ( $1 == "*" && $2 == "ceiling" ) { ceilingRow[++ceilingCount] = $4 OFS $5 OFS $6 OFS substr( $3, 1, length( $3 ) - 3 ) ; next ; }
	if ( $1 != member ) next
	if ( $2 == "read" ) allowRow[++allowCount] = readTools OFS $4 OFS $5
	else if ( $2 == "write" ) allowRow[++allowCount] = writeTools OFS $4 OFS $5
	if ( mode == "list" ) listStanding()
	next
}

## One session store's grants: kind:tool:target:by:time:ref.
{
	store = FILENAME ; sub( /\/grants$/, "", store )
	n = split( $0, f, ":" )
	if ( n < 6 ) next
	kind = f[1] ; tool = f[2] ; target = f[3] ; by = f[4] ; stamp = f[5] ; ref = f[6]
	for ( i = 7 ; i <= n ; i++ ) ref = ref ":" f[i]
	if ( mode != "list" && index( fileTools, " " tool " " ) == 0 ) next
	if ( by == "" || by == member ) next
	if ( ref == "" || ref == "." || ref == ".." || index( ref, "/" ) ) next
	if ( kind != "session" && kind != "task" && kind != "once" ) next
	if ( recordField( store "/" ref ".md", "owner" ) != member ) next
	if ( fileExists( store "/revoked/" ref ) ) next
	## A store of the member's other runs on the same item, whose session grants hold: listed so in
	## mode list, else a runs row; one the session reads as its own gives its session row below too.
	## Its task grants are read below as any other store's; nothing else of a marked store is.
	if ( store in runsItem ) {
		if ( kind == "session" && !runsEnded[store] ) {
			natural = grantsFieldDecode( target )
			if ( mode == "list" ) { item = runsItem[store] ; at = "" ; listHeld() ; next ; }
			pattern = ( index( ref, "refusal-" ) == 1 ) ? grantsLiteral( natural ) : grantsCoversPattern( natural )
			heldRow[++heldCount] = "runs" OFS tool OFS pattern OFS ref OFS runsItem[store] OFS runsSession[store]
		}
		if ( runsOnly[store] && kind != "task" ) next
	}
	if ( kind == "session" && ( store in endedStore ) ) next
	natural = grantsFieldDecode( target )
	item = ""
	if ( kind == "task" ) {
		item = recordField( store "/" ref ".md", "task" )
		if ( item == "" && ( getline item < ( store "/" ref ".task" ) ) <= 0 ) item = ""
		close( store "/" ref ".task" )
		sub( /^.*\//, "", item ) ; sub( /\.md$/, "", item )
		if ( item == "" ) next
	}
	at = ""
	if ( kind == "once" ) { at = stampEpoch( stamp ) ; if ( at == "" ) next ; }
	if ( mode == "list" ) { listHeld() ; next ; }
	pattern = ( index( ref, "refusal-" ) == 1 ) ? grantsLiteral( natural ) : grantsCoversPattern( natural )
	if ( kind == "session" ) { heldRow[++heldCount] = "session" OFS tool OFS pattern OFS ref OFS store ; next ; }
	if ( kind == "task" ) { heldRow[++heldCount] = "task" OFS tool OFS pattern OFS item ; next ; }
	onceRow[++onceCount] = "once" OFS tool OFS pattern OFS at OFS ref
}

## One front-matter field of a record, or empty -- AgentsToolsPermissionField's reading.
function recordField( file, field,    line, front, value ) {
	front = 0 ; value = ""
	while ( ( getline line < file ) > 0 ) {
		if ( front == 0 && line == "---" ) { front = 1 ; continue ; }
		if ( front == 1 && line == "---" ) break
		if ( front == 1 && index( line, "# " ) == 1 ) break
		if ( front == 1 && index( line, field ": " ) == 1 ) { value = substr( line, length( field ) + 3 ) ; break ; }
		if ( front == 0 ) break
	}
	close( file )
	return value
}

## Whether a regular file can be read: a marker, a record, a board item.
function fileExists( file,    line, got ) {
	got = ( getline line < file )
	close( file )
	return got >= 0
}

## A grants line's UTC stamp, YYYYMMDDTHHMMZ or YYYYMMDDTHHMMSSZ, as epoch seconds, or empty:
## AgentsIsoToEpoch.awk's own arithmetic, so an Allow once lapses here as it does there.
function stampEpoch( s,    y, mo, d, h, mi, sec, era, yoe, doy, doe ) {
	if ( s !~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9]([0-9][0-9])?Z$/ ) return ""
	y = substr( s, 1, 4 ) + 0 ; mo = substr( s, 5, 2 ) + 0 ; d = substr( s, 7, 2 ) + 0
	h = substr( s, 10, 2 ) + 0 ; mi = substr( s, 12, 2 ) + 0 ; sec = ( length( s ) == 16 ) ? substr( s, 14, 2 ) + 0 : 0
	if ( mo <= 2 ) y = y - 1
	era = int( y / 400 ) ; yoe = y - era * 400
	doy = int( ( 153 * ( mo + ( mo > 2 ? -3 : 9 ) ) + 2 ) / 5 ) + d - 1
	doe = yoe * 365 + int( yoe / 4 ) - int( yoe / 100 ) + doy
	return ( era * 146097 + doe - 719468 ) * 86400 + h * 3600 + mi * 60 + sec
}

## ---- mode list -------------------------------------------------------------------------

## The deepest registered place holding a path, as name:relative, or -: the ceiling rows,
## deepest first, are every place.
function placeHint( t,    i, part, p ) {
	if ( substr( t, 1, 1 ) != "/" ) return "-"
	for ( i = 1 ; i <= ceilingCount ; i++ ) {
		split( ceilingRow[i], part, "\t" )
		p = part[4]
		if ( t == p ) return part[3] ":."
		if ( p == "/" ) return part[3] ":" substr( t, 2 )
		if ( index( t, p "/" ) == 1 ) return part[3] ":" substr( t, length( p ) + 2 )
	}
	return "-"
}

## The place a grant was recorded with (<store>/<ref>.places: natural target, TAB, name:relative).
function recordedHint( file, natural,    line, tab, found ) {
	found = ""
	while ( ( getline line < file ) > 0 ) {
		tab = index( line, "\t" )
		if ( tab && substr( line, 1, tab - 1 ) == natural ) { found = substr( line, tab + 1 ) ; break ; }
	}
	close( file )
	return found
}

## Whether a board item is in an open state.
function itemOpen( name,    states, count, i ) {
	if ( boardRoot == "" ) return 0
	count = split( openStates, states, " " )
	for ( i = 1 ; i <= count ; i++ ) if ( states[i] != "" && fileExists( boardRoot "/" states[i] "/" name ".md" ) ) return 1
	return 0
}

## A floor, standing read or write, or standing tool row of the grants index.
function listStanding(    what, glob, colon ) {
	if ( $2 == "read" || $2 == "write" ) { listRow[++listCount] = $5 OFS $2 OFS $3 OFS placeHint( $3 ) OFS ( $5 == "floor" ? "floor" : $6 ) OFS "none" ; return ; }
	if ( $2 != "tool" ) return
	what = $3 ; glob = "*" ; colon = index( what, ":" )
	if ( colon ) { glob = substr( what, colon + 1 ) ; what = substr( what, 1, colon - 1 ) ; }
	listRow[++listCount] = $5 OFS what OFS glob OFS "-" OFS $6 OFS "none"
}

## A live session, task or once grant, in record form, with where it came from and when it ends.
function listHeld(    shown, hint, ends, storeId ) {
	shown = target ; gsub( /%3A/, ":", shown ) ; gsub( /%2C/, ",", shown )
	hint = recordedHint( store "/" ref ".places", natural )
	if ( hint == "" ) hint = placeHint( natural )
	storeId = store ; sub( /^.*\//, "", storeId )
	if ( kind == "session" && ( store in runsItem ) ) {
		ends = "while item " item " is open"
		if ( runsSession[store] != "-" ) { storeId = runsSession[store] ; sub( /^.*\//, "", storeId ) ; ends = ends " and session " storeId " runs" ; }
	}
	else if ( kind == "session" ) ends = "until session " storeId " ends"
	else if ( kind == "task" ) { if ( !itemOpen( item ) ) return ; ends = "while item " item " is open" ; }
	else {
		if ( ( store "/consumed/" ref ) in usedOnce ) return
		if ( now - at > ttl ) return
		ends = "lapses in " ( ttl - ( now - at ) ) "s unless used"
	}
	heldList[++heldListCount] = kind OFS tool OFS shown OFS hint OFS ref " by " by OFS ends
}

END {
	if ( !ok ) exit 1
	if ( mode == "list" ) {
		for ( i = 1 ; i <= listCount ; i++ ) print listRow[i]
		for ( i = 1 ; i <= heldListCount ; i++ ) print heldList[i]
		exit
	}
	print header
	n = split( stores, storeList, "\n" )
	for ( i = 1 ; i <= n ; i++ ) if ( storeList[i] != "" ) print "store", storeList[i]
	for ( i = 1 ; i <= ceilingCount ; i++ ) print "ceiling", ceilingRow[i]
	for ( i = 1 ; i <= allowCount ; i++ ) print "allow", allowRow[i]
	if ( sandboxIn != "" ) print "allow", readTools, grantsGlobPattern( sandboxIn "/**" ), "floor"
	if ( sandboxOut != "" ) print "allow", writeTools, grantsGlobPattern( sandboxOut "/**" ), "floor"
	if ( origin != "" ) print "allow", readTools, grantsGlobPattern( origin "/**" ), "floor"
	for ( i = 1 ; i <= heldCount ; i++ ) print heldRow[i]
	for ( i = 1 ; i <= onceCount ; i++ ) print onceRow[i]
	print "end"
}
