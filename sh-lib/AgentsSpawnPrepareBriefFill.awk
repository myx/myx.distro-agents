#!/usr/bin/env awk
# Fills {{member}}/{{routine}}/{{executors}}/{{invitees}}/{{open-warnings}} slots in a
# brief template's Skeleton block.
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
}
/^# Skeleton[ \t]*$/ { inSection = 1 ; next ; }
inSection && /^# / { exit ; }
inSection && /^```/ { if ( inBlock ) { done = 1 ; exit ; } inBlock = 1 ; next ; }
inBlock {
	line = $0 ;
	if ( line == "{{open-warnings}}" ) { print warnings ; next ; }
	line = fill( line, "{{member}}", member ) ;
	line = fill( line, "{{routine}}", routine ) ;
	line = fill( line, "{{executors}}", executors ) ;
	line = fill( line, "{{invitees}}", invitees ) ;
	print line ;
}
END { if ( ! done ) { exit 3 ; } ; }
