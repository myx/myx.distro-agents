#!/usr/bin/env awk
# A routine file's root headings, outside its frontmatter and outside code fences: one row each,
# `<line number><TAB><heading text>`. With SECTION (variable) set to a heading's text, prints instead
# the lines of that section's body, up to the next root heading.
BEGIN { fence = 0 ; inFront = 0 ; inSection = 0 ; }
NR == 1 && $0 == "---" { inFront = 1 ; next ; }
inFront { if ( $0 == "---" ) { inFront = 0 ; } next ; }
$0 ~ /^```/ { fence = ! fence ; if ( inSection ) { print ; } next ; }
! fence && substr( $0, 1, 2 ) == "# " {
	if ( SECTION == "" ) { printf "%d\t%s\n", NR, substr( $0, 3 ) ; }
	else { inSection = ( substr( $0, 3 ) == SECTION ) ; }
	next ;
}
SECTION != "" && inSection { print ; }
