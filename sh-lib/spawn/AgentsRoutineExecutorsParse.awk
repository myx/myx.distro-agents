#!/usr/bin/env awk
# THE ONE PARSE of a routine's `executors:` value. Read by AgentsTools.RoutineExecutors.include for every
# shell caller, and preloaded by the awk programs that read many routine files in one pass, so one rule
# answers everywhere.
# An entry is a member, then optionally one parenthetical of its own comma-separated parameters. Entries are
# separated by a comma and by nothing else, which is the separator the spawner has always read: `the
# coordinator and friends` is one entry naming no member, exactly as it read before this rule. Within an
# entry, the parenthetical is the override, and the member is the text before it, its edges trimmed. A
# parenthetical is sealed: a comma inside it separates parameters, never entries.

## A word with its edges trimmed.
function trimmedD( text ) {
	gsub( /^[ \t]+|[ \t]+$/, "", text )
	return text
}

## The entries of a value, as `<member>\034<parameters>` from 1, both trimmed. An entry naming nothing is kept
## as an empty row: a comma with nothing between, or a trailing one, is a fault the caller reports, never a
## silent drop. Returns the count.
function routineExecutorsEntries( value, out,   rest, piece, depth, i, n, c, name, params, openAt, count ) {
	count = 0
	rest = value "\n"
	if ( value == "" ) return 0
	while ( rest != "" ) {
		piece = rest
		## The entry ends at the first comma outside a parenthetical.
		depth = 0 ; openAt = 0 ; n = length( piece )
		for ( i = 1 ; i <= n ; i++ ) {
			c = substr( piece, i, 1 )
			if ( c == "(" ) { depth++ ; if ( openAt == 0 ) openAt = i ; continue ; }
			if ( c == ")" ) { if ( depth > 0 ) depth-- ; continue ; }
			if ( c == "," && depth == 0 ) break
		}
		rest = ( i <= n ) ? substr( piece, i + 1 ) : ""
		piece = ( i <= n ) ? substr( piece, 1, i - 1 ) : piece
		name = piece ; params = ""
		openAt = index( piece, "(" )
		if ( openAt > 0 ) {
			name = substr( piece, 1, openAt - 1 )
			params = substr( piece, openAt + 1 )
			sub( /)[ \t]*$/, "", params )
			gsub( /[()]/, "", params )
		}
		count++ ; out[count] = trimmedD( name ) "\034" trimmedD( params )
	}
	return count
}

## The parameters the entry for a member carries, as written, and "" where it carries none: the entry naming
## that member, else a `<type>-*` of its type, else the `magic-team` or `*` that is every member.
function routineExecutorsParams( value, member,   entries, count, entryAt, splitParts, entryName, entryParams, wantType ) {
	count = routineExecutorsEntries( value, entries )
	wantType = ""
	if ( index( member, "-" ) > 0 ) wantType = substr( member, 1, index( member, "-" ) ) "*"
	for ( entryAt = 1 ; entryAt <= count ; entryAt++ ) {
		split( entries[entryAt], splitParts, "\034" )
		entryName = splitParts[1] ; entryParams = splitParts[2]
		if ( entryParams == "" ) continue
		if ( entryName == member ) return entryParams
		if ( wantType != "" && entryName == wantType ) return entryParams
		if ( entryName == "magic-team" || entryName == "*" ) return entryParams
	}
	return ""
}

## The members a value names on one line, space-separated: the form a reader that tests one name takes.
function routineExecutorsMemberList( value,   entries, count, entryAt, splitParts, list ) {
	count = routineExecutorsEntries( value, entries )
	list = ""
	for ( entryAt = 1 ; entryAt <= count ; entryAt++ ) {
		split( entries[entryAt], splitParts, "\034" )
		if ( splitParts[1] == "" ) continue
		list = list ( list == "" ? "" : " " ) splitParts[1]
	}
	return list
}

## The answer for a shell caller: the mode is `mode`, passed with -v, the value EXECUTORS_VALUE and the member
## EXECUTORS_MEMBER. A caller that preloads this file for its functions passes no mode, and nothing is printed.
BEGIN {
	## NO MODE IS A PRELOAD: the caller's own program runs and this file only defines the functions. It used to `exit 0` here, which ended the
	## caller's awk as well - the fast reader of the routines printed no row at all, and every screen that read that list said "none".
	if ( mode == "" ) { }
	else if ( mode == "entries" ) {
		count = routineExecutorsEntries( ENVIRON["EXECUTORS_VALUE"], entries )
		for ( entryAt = 1 ; entryAt <= count ; entryAt++ ) { split( entries[entryAt], splitParts, "\034" ) ; printf "%s\t%s\n", splitParts[1], splitParts[2] ; }
		exit 0
	}
	else if ( mode == "params" ) { print routineExecutorsParams( ENVIRON["EXECUTORS_VALUE"], ENVIRON["EXECUTORS_MEMBER"] ) ; exit 0 ; }
	else { print routineExecutorsMemberList( ENVIRON["EXECUTORS_VALUE"] ) ; exit 0 ; }
}
