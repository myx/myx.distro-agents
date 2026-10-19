#!/usr/bin/env awk
# The mix-in of a routine's kind routine (F5.6, one level): prints the routine with the kind routine's
# Opening steps, Closure steps, local rules and tooling mixed in. Reads two files, the kind routine
# first, then the routine; ROUTINE_SKIPS (environment) is the routine's `skips-inherited:` value, step
# names separated by commas, left out of what the kind routine contributes.
#   Opening steps: the kind routine's, then the routine's own.
#   Steps: the routine's own, and only its own.
#   Closure steps: the routine's own, then the kind routine's.
#   Routine's local rules: the kind routine's items, then the routine's own.
#   Routine-specific tooling: the kind routine's operations the routine does not list, then the routine's own.
# A step is a list item whose text starts with a bold name, `1. **name**` or `- **name**`, a step of a
# group (a nested item) as well as a root one. A skipped step takes its nested lines with it. The
# steps of a mixed section are numbered again in one run.
function trim( text ) { sub( /^[ \t]+/, "", text ) ; sub( /[ \t]+$/, "", text ) ; return text ; }
function indentOf( line,    rest ) { rest = line ; sub( /^[ ]+/, "", rest ) ; return length( line ) - length( rest ) ; }
function isItem( line ) { return ( line ~ /^[ ]*([0-9]+\.|[-*]) / ) ; }
function stepName( line,    name ) {
	if ( line !~ /^[ ]*([0-9]+\.|[-*]) \*\*[^*]+\*\*/ ) { return "" ; }
	name = line ; sub( /^[ ]*([0-9]+\.|[-*]) \*\*/, "", name ) ; sub( /\*\*.*$/, "", name ) ;
	return name ;
}
function wanted( name ) { return ( name == "Opening steps" || name == "Closure steps" || name == "Routine's local rules" || name == "Routine-specific tooling" || name == "Steps" ) ; }
# A body split at its first list item: the lead-in text, then the item block.
function splitBody( text,    lines, count, at, started ) {
	bodyIntro = "" ; bodyItems = "" ; started = 0 ;
	count = split( text, lines, "\n" ) ;
	if ( count > 0 && lines[count] == "" ) { count-- ; }
	for ( at = 1 ; at <= count ; at++ ) {
		if ( ! started && isItem( lines[at] ) ) { started = 1 ; }
		if ( started ) { bodyItems = bodyItems lines[at] "\n" ; } else { bodyIntro = bodyIntro lines[at] "\n" ; }
	}
}
# An item block without the steps named in the skip list, each with its nested lines.
function withoutSkipped( block,    lines, count, at, name, skipping, skipIndent, out ) {
	count = split( block, lines, "\n" ) ;
	if ( count > 0 && lines[count] == "" ) { count-- ; }
	out = "" ; skipping = 0 ;
	for ( at = 1 ; at <= count ; at++ ) {
		if ( skipping ) {
			if ( lines[at] == "" || indentOf( lines[at] ) > skipIndent ) { continue ; }
			skipping = 0 ;
		}
		name = stepName( lines[at] ) ;
		if ( name != "" && ( name in skipSet ) ) { skipping = 1 ; skipIndent = indentOf( lines[at] ) ; continue ; }
		out = out lines[at] "\n" ;
	}
	return out ;
}
# The root steps of a block numbered again, 1 up.
function renumbered( block,    lines, count, at, number, out ) {
	count = split( block, lines, "\n" ) ;
	if ( count > 0 && lines[count] == "" ) { count-- ; }
	out = "" ; number = 0 ;
	for ( at = 1 ; at <= count ; at++ ) {
		if ( lines[at] ~ /^[0-9]+\. / ) { number++ ; sub( /^[0-9]+\./, number ".", lines[at] ) ; }
		out = out lines[at] "\n" ;
	}
	return out ;
}
function joinBlocks( first, second,    out ) {
	out = first ;
	if ( first != "" && second != "" && first !~ /\n\n$/ ) { out = out "\n" ; }
	return out second ;
}
# The tooling body parsed: its lead-in, the operation lines under `## DistroAgentsTools magic-tooling operations`, and every other subsection.
function toolingParse( text,    lines, count, at, mode ) {
	toolIntro = "" ; toolOps = "" ; toolRest = "" ; mode = "intro" ;
	count = split( text, lines, "\n" ) ;
	if ( count > 0 && lines[count] == "" ) { count-- ; }
	for ( at = 1 ; at <= count ; at++ ) {
		if ( lines[at] ~ /^## / ) { mode = ( lines[at] == "## DistroAgentsTools magic-tooling operations" ) ? "ops" : "rest" ; if ( mode == "ops" ) { continue ; } }
		if ( mode == "intro" ) { toolIntro = toolIntro lines[at] "\n" ; }
		else if ( mode == "ops" ) { if ( lines[at] != "" ) { toolOps = toolOps lines[at] "\n" ; } }
		else { toolRest = toolRest lines[at] "\n" ; }
	}
}
function emitSection( name, body,    kindBody, ownIntro, ownItems, kindItems, opsOwn, restOwn, introOwn, kindOps, kindRest, lines, count, at, extra, ownSet ) {
	kindBody = kindText[name] ;
	if ( name == "Steps" || kindBody == "" ) { printf "%s", body ; return ; }
	if ( name == "Opening steps" || name == "Closure steps" || name == "Routine's local rules" ) {
		splitBody( body ) ; ownIntro = bodyIntro ; ownItems = bodyItems ;
		splitBody( kindBody ) ; kindItems = bodyItems ; if ( ownIntro == "" ) { ownIntro = bodyIntro ; }
		if ( name != "Routine's local rules" ) { kindItems = withoutSkipped( kindItems ) ; }
		if ( name == "Closure steps" ) { ownItems = joinBlocks( ownItems, kindItems ) ; } else { ownItems = joinBlocks( kindItems, ownItems ) ; }
		if ( name != "Routine's local rules" ) { ownItems = renumbered( ownItems ) ; }
		printf "%s", joinBlocks( ownIntro, ownItems ) ;
		return ;
	}
	# Routine-specific tooling
	toolingParse( body ) ; introOwn = toolIntro ; opsOwn = toolOps ; restOwn = toolRest ;
	toolingParse( kindBody ) ; kindOps = toolOps ; kindRest = toolRest ;
	if ( introOwn == "" ) { introOwn = toolIntro ; }
	count = split( opsOwn, lines, "\n" ) ;
	for ( at = 1 ; at <= count ; at++ ) { if ( lines[at] != "" ) { ownSet[lines[at]] = 1 ; } }
	extra = "" ;
	count = split( kindOps, lines, "\n" ) ;
	for ( at = 1 ; at <= count ; at++ ) { if ( lines[at] != "" && ! ( lines[at] in ownSet ) ) { extra = extra lines[at] "\n" ; } }
	printf "%s", introOwn ;
	if ( introOwn != "" && introOwn !~ /\n\n$/ ) { printf "\n" ; }
	printf "## DistroAgentsTools magic-tooling operations\n\n%s%s", extra, opsOwn ;
	if ( restOwn != "" || kindRest != "" ) { printf "\n" ; }
	printf "%s", restOwn ;
	if ( restOwn != "" && kindRest != "" && restOwn !~ /\n\n$/ ) { printf "\n" ; }
	printf "%s", kindRest ;
}
BEGIN {
	skipCount = split( ENVIRON["ROUTINE_SKIPS"], skipList, "," ) ;
	for ( skipAt = 1 ; skipAt <= skipCount ; skipAt++ ) { if ( trim( skipList[skipAt] ) != "" ) { skipSet[trim( skipList[skipAt] )] = 1 ; } }
}
FNR == 1 { fence = 0 ; inFront = 0 ; section = "" ; if ( $0 == "---" ) { inFront = 1 ; if ( FILENAME != ARGV[1] ) { print ; } next ; } }
inFront { if ( $0 == "---" ) { inFront = 0 ; } if ( FILENAME != ARGV[1] ) { print ; } next ; }
{
	isHead = 0 ;
	if ( $0 ~ /^```/ ) { fence = ! fence ; }
	else if ( ! fence && substr( $0, 1, 2 ) == "# " ) { isHead = 1 ; }
}
FILENAME == ARGV[1] {
	if ( isHead ) { section = substr( $0, 3 ) ; next ; }
	if ( wanted( section ) ) { kindText[section] = kindText[section] $0 "\n" ; }
	next ;
}
{
	if ( isHead ) {
		if ( buffering != "" ) { emitSection( buffering, buffer ) ; buffering = "" ; buffer = "" ; }
		section = substr( $0, 3 ) ;
		print ;
		if ( wanted( section ) ) { buffering = section ; buffer = "" ; }
		next ;
	}
	if ( buffering != "" ) { buffer = buffer $0 "\n" ; next ; }
	print ;
}
END { if ( buffering != "" ) { emitSection( buffering, buffer ) ; } }
