#!/usr/bin/awk -f
##
## AgentsReflectionSweep.awk -- the one pass of the reflection sweep (AgentsTools.InternTeamDataReflectionSweep.include). Operands: the
## `reflection-*.md` files of the incoming/ folders that are old by the date in their NAME, or have no date in it, none opened until here.
## For each file it reads the `date:` header once and decides, then writes what it decides in the same pass:
##   - a file whose date (the header's, else the name's) is before the cutoff is SWEPT: written to the processed/ folder beside its incoming/
##     with the three headers a discard carries, appended at the end of its frontmatter in this order, `processed-at`, `disposition:
##     discarded`, `discarded-by`, exactly as the mark op (AgentsTools.InternOpInboxToProcessed.include) appends them, and a file with no
##     frontmatter is given a block and the blank line after it, as the mark op gives it. A swept file with no `date:` header is also given
##     one, the date of its name: the lazy heal of a document without a date;
##   - a file with a `date:` header on or after the cutoff is KEPT;
##   - a file with no `date:` header and no date in its name is HEALED in place: given `date: <stamp>`, the day of this run, and kept. It
##     is written beside itself as `<name>.sweep-heal` and the caller moves it over the original.
## One warning for each file given a date, never again for it: the next run finds the header.
##
## -v cutoff=<YYYYMMDD>   a date before it is old
## -v stamp=<text>        the `processed-at` value, and the `date:` of a healed file: `<YYYY-MM-DD> 00:00 +0000`, THE SAME ALL DAY so that two rigs
##                        sweeping one shared store write the same bytes for the same file
## -v reason=<text>       the `discarded-by` value
##
## Prints, a tab between the fields:  swept <source> <target>  |  healed <source> <temp>  |  kept <source> <date>  |  warn <source> <text>  |
##   count <member> <swept> <kept>. An empty file has no first line, so awk never sees it: it stays in incoming/ and the caller counts it
##   as not seen.
##
## Every closing brace after a statement on its line is preceded by a `;` (magic-developer's reference/shell.md axiom).
##

## YYYYMMDD of a `date:` value in the team form (`2026-10-06 09:30 +0000`) or the name form (`20261006T0930Z`); empty where it is neither.
function normDate( v,    d ) {
	d = substr( v, 1, 10 ) ;
	if ( d ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ ) { return substr( d, 1, 4 ) substr( d, 6, 2 ) substr( d, 9, 2 ) ; }
	d = substr( v, 1, 8 ) ;
	if ( d ~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/ ) { return d ; }
	return "" ;
}

## The `date:` header value a reflection's NAME gives, in the team form; empty where the name has no date.
function nameHeader( name,    d, t ) {
	d = substr( name, 12, 8 ) ;
	if ( d ~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/ && substr( name, 20, 1 ) == "T" ) {
		t = substr( name, 21, 4 ) ;
		if ( t !~ /^[0-9][0-9][0-9][0-9]$/ ) { t = "0000" ; }
		return substr( d, 1, 4 ) "-" substr( d, 5, 2 ) "-" substr( d, 7, 2 ) " " substr( t, 1, 2 ) ":" substr( t, 3, 2 ) " +0000" ;
	}
	d = substr( name, 12, 10 ) ;
	if ( d ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ ) { return d " 00:00 +0000" ; }
	return "" ;
}

function hasKey( key,    i ) {
	for ( i = 2 ; i < fenceClose ; i++ ) { if ( index( L[i], key ":" ) == 1 ) { return 1 ; } ; }
	return 0 ;
}

function member( path,    m ) {
	m = path ;
	sub( /\/incoming\/[^\/]*$/, "", m ) ;
	sub( /^.*\//, "", m ) ;
	return m ;
}

## The file as it is, with the lines in add[1..addCount] appended at the end of its frontmatter, as the mark op does.
function emitFile( target,    i ) {
	if ( fenceClose > 0 ) {
		for ( i = 1 ; i < fenceClose ; i++ ) { print L[i] > target ; }
		for ( i = 1 ; i <= addCount ; i++ ) { print add[i] > target ; }
		for ( i = fenceClose ; i <= n ; i++ ) { print L[i] > target ; }
	} else {
		print "---" > target ;
		for ( i = 1 ; i <= addCount ; i++ ) { print add[i] > target ; }
		print "---" > target ;
		print "" > target ;
		for ( i = 1 ; i <= n ; i++ ) { print L[i] > target ; }
	}
	close( target ) ;
}

function finish(    i, v, hdr, hdrKey, name, target, who, nh, nd, old, giveDate ) {
	if ( cur == "" ) { return ; }
	who = member( cur ) ;
	if ( ! ( who in seenMember ) ) { seenMember[who] = 1 ; order[++orderCount] = who ; }
	fenceClose = 0 ;
	if ( L[1] == "---" ) {
		for ( i = 2 ; i <= n ; i++ ) { if ( L[i] == "---" ) { fenceClose = i ; break ; } ; }
	}
	hdr = "" ; hdrKey = 0 ;
	for ( i = 2 ; i < fenceClose ; i++ ) {
		if ( index( L[i], "date:" ) == 1 ) {
			hdrKey = 1 ;
			v = substr( L[i], 6 ) ;
			sub( /^[ \t]+/, "", v ) ;
			hdr = normDate( v ) ;
			break ;
		}
	}
	name = cur ;
	sub( /^.*\//, "", name ) ;
	nh = nameHeader( name ) ;
	nd = normDate( nh ) ;
	giveDate = "" ;
	if ( hdr != "" ) {
		old = ( hdr < cutoff ) ;
	} else if ( nd != "" ) {
		old = ( nd < cutoff ) ;
		if ( hdrKey ) {
			print "warn\t" cur "\ta date: header it cannot read; the date of its name is used" ;
		} else if ( old ) {
			giveDate = nh ;
			print "warn\t" cur "\tno date: header; written from the date of its name: " nh ;
		}
	} else {
		old = 0 ;
		if ( hdrKey ) {
			print "warn\t" cur "\ta date: header it cannot read and no date in its name; kept" ;
		} else {
			giveDate = stamp ;
			print "warn\t" cur "\tno date: header and no date in its name; written as the day of this sweep: " stamp ;
		}
	}
	if ( ! old ) {
		keptCount[who]++ ;
		if ( giveDate != "" ) {
			addCount = 0 ;
			add[++addCount] = "date: " giveDate ;
			emitFile( cur ".sweep-heal" ) ;
			print "healed\t" cur "\t" cur ".sweep-heal" ;
		}
		print "kept\t" cur "\t" ( hdr != "" ? hdr : ( nd != "" ? nd : substr( stamp, 1, 10 ) ) ) ;
		return ;
	}
	target = cur ;
	sub( /\/incoming\/[^\/]*$/, "/processed/" name, target ) ;
	addCount = 0 ;
	if ( ! hasKey( "processed-at" ) ) { add[++addCount] = "processed-at: " stamp ; }
	if ( ! hasKey( "disposition" ) ) { add[++addCount] = "disposition: discarded" ; }
	if ( ! hasKey( "discarded-by" ) ) { add[++addCount] = "discarded-by: " reason ; }
	if ( giveDate != "" ) { add[++addCount] = "date: " giveDate ; }
	emitFile( target ) ;
	sweptCount[who]++ ;
	print "swept\t" cur "\t" target ;
}

FNR == 1 {
	finish() ;
	cur = FILENAME ;
	n = 0 ;
}

{
	L[++n] = $0 ;
}

END {
	finish() ;
	for ( i = 1 ; i <= orderCount ; i++ ) { print "count\t" order[i] "\t" ( sweptCount[order[i]] + 0 ) "\t" ( keptCount[order[i]] + 0 ) ; }
}
