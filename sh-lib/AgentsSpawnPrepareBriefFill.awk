#!/usr/bin/env awk
# Fills {{member}}/{{routine}}/{{executors}}/{{invitees}}/{{open-warnings}} slots in a
# brief template's Skeleton block, keeping the [own]/[native] lines of BRIEF_HARNESS only.
## Slots are replaced by position, never gsub, so & and \ in a value pass through literally.
function fill( text, slot, value,    slotPos, done ) {
	done = "" ;
	while ( ( slotPos = index( text, slot ) ) > 0 ) {
		done = done substr( text, 1, slotPos - 1 ) value ;
		text = substr( text, slotPos + length( slot ) ) ;
	}
	return done text ;
}
BEGIN {
	member = ENVIRON["BRIEF_MEMBER"] ;
	warnings = ENVIRON["BRIEF_WARNINGS"] ;
	routine = ENVIRON["BRIEF_ROUTINE"] ;
	executors = ENVIRON["BRIEF_EXECUTORS"] ;
	invitees = ENVIRON["BRIEF_INVITEES"] ;
	harness = ENVIRON["BRIEF_HARNESS"] ;
}
## A line tagged [own] or [native] is kept, untagged, only for that harness kind.
function harnessLine( text,    tag ) {
	if ( match( text, /^\[(own|native)\] / ) == 0 ) { return 1 ; }
	tag = substr( text, 2, RLENGTH - 3 ) ;
	return tag == harness ;
}
/^# Skeleton[ \t]*$/ { inSection = 1 ; next ; }
inSection && /^# / { exit ; }
inSection && /^```/ { if ( inBlock ) { done = 1 ; exit ; } inBlock = 1 ; next ; }
inBlock {
	line = $0 ;
	if ( line == "{{open-warnings}}" ) { print warnings ; next ; }
	if ( ! harnessLine( line ) ) { next ; }
	sub( /^\[(own|native)\] /, "", line ) ;
	line = fill( line, "{{member}}", member ) ;
	line = fill( line, "{{routine}}", routine ) ;
	line = fill( line, "{{executors}}", executors ) ;
	line = fill( line, "{{invitees}}", invitees ) ;
	print line ;
}
END { if ( ! done ) { exit 3 ; } ; }
