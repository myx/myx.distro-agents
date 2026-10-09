#!/usr/bin/env awk

## AgentsGrantsIndexBuild.awk -- the grants index (AgentsTools.Grants.include), from one tagged
## stream on stdin, TAB-separated, run with AgentsGrantsPattern.awk loaded first:
##   head    <the index header line>
##   real    <literal directory> <the same, resolved>
##   member  <name>                                  every member a `*` row reaches
##   place   <name> <kind> <ceiling> <path>          the merged place list
##   floor   <read|write> <glob>                     every member's floor
##   grant   <member:workspace:kind:grant>           every workspace's permissions registry
## Prints the index, one row per line, TAB-separated:
##   *        ceiling <path>/** <pattern> <read-only|read-write> <place>   deepest first
##   <member> <read|write|tool|unresolved> <glob or tool text> <pattern or -> <floor|standing> <note>
##   end
## Fully unrolled: a `*` row is one row per member. A write row on a read-only place is a
## read row, with one warning; an unresolved row is kept, never matched, with one warning --
## here for another workspace's row (-v self=<this workspace's name>), its own install having
## said it for its own.

BEGIN { FS = "\t" ; OFS = "\t" ; head = "" ; memberCount = 0 ; placeCount = 0 ; floorCount = 0 ; grantCount = 0 ; }

## -v mode=bases: only the literal directory each path starts with, once each, for its
## caller to resolve and hand back as `real` lines.
mode == "bases" {
	base = ""
	if ( $1 == "place" && $5 ~ /^\// ) base = $5
	else if ( $1 == "floor" && $3 ~ /^\// ) base = grantsGlobBase( $3 )
	else if ( $1 == "grant" && match( $0, /:(Edit|Read)\(\/.*\)$/ ) ) {
		base = substr( $0, RSTART + 6, RLENGTH - 7 ) ; sub( /^\/\/+/, "/", base ) ; base = grantsGlobBase( base )
	}
	if ( base != "" && base != "/" && !( base in baseSeen ) ) { baseSeen[base] = 1 ; print base ; }
	next
}

$1 == "head" { head = substr( $0, 6 ) ; next ; }
$1 == "real" { real[$2] = $3 ; next ; }
$1 == "member" { if ( $2 != "" && $2 != "*" && !( $2 in isMember ) ) { isMember[$2] = 1 ; memberOrder[++memberCount] = $2 ; } next ; }
$1 == "place" {
	if ( $5 !~ /^\// ) next
	placeCount++ ; placeName[placeCount] = $2 ; placeCeiling[placeCount] = $4 ; placePath[placeCount] = resolvedPath( $5 )
	next
}
$1 == "floor" { if ( $3 ~ /^\// ) { floorCount++ ; floorVerb[floorCount] = $2 ; floorGlob[floorCount] = resolvedGlob( $3 ) ; } next ; }
$1 == "grant" {
	line = substr( $0, 7 )
	n = index( line, ":" ) ; if ( !n ) next
	who = substr( line, 1, n - 1 ) ; line = substr( line, n + 1 )
	n = index( line, ":" ) ; if ( !n ) next
	ws = substr( line, 1, n - 1 ) ; line = substr( line, n + 1 )
	n = index( line, ":" ) ; if ( !n ) next
	kind = substr( line, 1, n - 1 ) ; text = substr( line, n + 1 )
	if ( who == "" || text == "" ) next
	if ( kind == "tool" ) { verb = "tool" ; glob = text ; }
	else if ( kind == "unresolved" ) { verb = "unresolved" ; glob = text ; }
	else if ( text ~ /^Edit\(\/.*\)$/ ) { verb = "write" ; glob = substr( text, 6, length( text ) - 6 ) ; }
	else if ( text ~ /^Read\(\/.*\)$/ ) { verb = "read" ; glob = substr( text, 6, length( text ) - 6 ) ; }
	else next
	if ( verb == "read" || verb == "write" ) { sub( /^\/\/+/, "/", glob ) ; glob = resolvedGlob( glob ) ; }
	note = ws ":" kind
	if ( verb == "write" && ( p = placeOf( grantsGlobBase( glob ) ) ) && placeCeiling[p] == "read-only" ) {
		verb = "read"
		if ( !( ( who SUBSEP glob ) in cappedSaid ) ) {
			cappedSaid[who SUBSEP glob] = 1
			printf( "⚠️ WARNING: grants: the write grant of %s on %s (declared in %s) is capped to read: %s is a read-only place\n", who, glob, ws, placeName[p] ) > "/dev/stderr"
		}
	}
	## Said where it was declared (--make-agents-indices there); here only for another workspace.
	if ( verb == "unresolved" && ws != self && !( ( who SUBSEP glob ) in unresolvedSaid ) ) {
		unresolvedSaid[who SUBSEP glob] = 1
		printf( "⚠️ WARNING: grants: an unresolved grant of %s is kept as a row that admits nothing: %s (declared in %s)\n", who, glob, ws ) > "/dev/stderr"
	}
	grantCount++ ; grantWho[grantCount] = who ; grantVerb[grantCount] = verb ; grantGlob[grantCount] = glob ; grantNote[grantCount] = note
	if ( who != "*" && !( who in isMember ) ) { isMember[who] = 1 ; memberOrder[++memberCount] = who ; }
	next
}

## A path with its longest resolved literal directory put in place of its spelling.
function resolvedPath( p,    q ) {
	if ( p in real ) return real[p]
	q = p
	while ( q != "" && q != "/" ) {
		sub( /\/[^\/]*$/, "", q )
		if ( q in real ) return real[q] substr( p, length( q ) + 1 )
	}
	return p
}
function resolvedGlob( g,    base ) {
	base = grantsGlobBase( g )
	if ( base == "/" ) return g
	return resolvedPath( base ) substr( g, length( base ) + 1 )
}

## The deepest place holding a path, or 0.
function placeOf( path,    i, best, bestLength ) {
	best = 0 ; bestLength = -1
	for ( i = 1 ; i <= placeCount ; i++ ) {
		if ( path != placePath[i] && index( path, placePath[i] "/" ) != 1 && placePath[i] != "/" ) continue
		if ( length( placePath[i] ) > bestLength ) { best = i ; bestLength = length( placePath[i] ) ; }
	}
	return best
}

function emit( who, verb, glob, from, note,    key ) {
	key = who SUBSEP verb SUBSEP glob
	if ( key in emitted ) return
	emitted[key] = 1
	print who, verb, glob, ( verb == "read" || verb == "write" ) ? grantsGlobPattern( glob ) : "-", from, note
}

END {
	if ( mode == "bases" ) exit
	print head
	## Every place, deepest first: the first one holding a path decides its ceiling.
	for ( i = 1 ; i <= placeCount ; i++ ) order[i] = i
	for ( i = 2 ; i <= placeCount ; i++ ) {
		for ( j = i ; j > 1 && length( placePath[order[j]] ) > length( placePath[order[j - 1]] ) ; j-- ) { t = order[j] ; order[j] = order[j - 1] ; order[j - 1] = t ; }
	}
	for ( i = 1 ; i <= placeCount ; i++ ) {
		p = order[i]
		if ( ( placePath[p] ) in ceilingDone ) continue
		ceilingDone[placePath[p]] = 1
		print "*", "ceiling", placePath[p] "/**", grantsGlobPattern( placePath[p] "/**" ), placeCeiling[p], placeName[p]
	}
	for ( m = 1 ; m <= memberCount ; m++ ) {
		who = memberOrder[m]
		for ( g = 1 ; g <= grantCount ; g++ ) {
			if ( grantWho[g] != who && grantWho[g] != "*" ) continue
			emit( who, grantVerb[g], grantGlob[g], "standing", grantNote[g] )
		}
		for ( f = 1 ; f <= floorCount ; f++ ) emit( who, floorVerb[f], floorGlob[f], "floor", "floor" )
	}
	print "end"
}
