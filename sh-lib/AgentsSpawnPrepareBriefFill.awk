#!/usr/bin/env awk
# Fills {{member}}/{{routine}}/{{executors}}/{{invitees}}/{{open-warnings}} slots in a
# brief template's Skeleton block, keeping the [own]/[native] lines of BRIEF_HARNESS only.
## The slots are filled by the one shared filler, loaded ahead of this file
## (AgentsToolsToolingTemplateFill, AgentsToolingTemplateFill.awk): by position, never gsub,
## so & and \ in a value pass through literally.
## The value the shared filler asks for (AgentsToolingTemplateFill.awk): a slot of the brief.
## Any other `{{name}}` is no slot of it, and stays as written.
function ttSlot( name ) {
	if ( name == "member" ) { return member ; }
	if ( name == "routine" ) { return routine ; }
	if ( name == "executors" ) { return executors ; }
	if ( name == "invitees" ) { return invitees ; }
	if ( name == "open-warnings" ) { return warnings ; }
	return "{{" name "}}" ;
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
	print ttFillSlots( line, 1 ) ;
}
END { if ( ! done ) { exit 3 ; } ; }
