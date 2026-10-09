#!/usr/bin/env awk
# Reads one rendering of the answers to a question -- AgentsSlackThreadAnswers.awk's shape:
# "<ts> | <user> | <text>" heads, each followed by the rest of that message's lines -- and
# prints the CLARIFICATIONS on its answer, one line per message, as "<ts>\t<user>\t<text>":
# the rest of the message the answer was taken from (-v answerTs=<its ts>; its first line
# is the answer itself), then every later message whole. A message's lines are folded with
# " / ". Messages at or before answerTs, reaction lines, "# " lines and replies marked
# UNMATCHED-REPLY are not printed. With the answer a reaction, pass the question's own ts:
# every reply is then a clarification.

function secOf( v ) { sub( /\..*$/, "", v ) ; return ( v == "" ? 0 : v + 0 ) ; }
function fracOf( v ) { if ( v !~ /\./ ) { return "000000" ; } sub( /^[^.]*\./, "", v ) ; return substr( v "000000", 1, 6 ) ; }
function newerThan( a, b ) {
	if ( secOf( a ) != secOf( b ) ) { return secOf( a ) > secOf( b ) ; }
	return fracOf( a ) > fracOf( b ) ;
}
function flush() {
	if ( curTs != "" && curText != "" ) { printf "%s\t%s\t%s\n", curTs, curUser, curText ; }
	curTs = "" ; curUser = "" ; curText = "" ; inMessage = 0 ;
}

/^[0-9]+\.[0-9]+ \| / {
	flush() ;
	headUser = $0 ; sub( /^[^|]*\| /, "", headUser ) ; sub( / \|.*$/, "", headUser ) ;
	headText = $0 ; sub( /^[^|]*\| [^|]*\|/, "", headText ) ;
	while ( match( headText, /^ \[[^]]*\]/ ) ) { headText = substr( headText, RSTART + RLENGTH ) ; }
	sub( /^ +/, "", headText ) ;
	if ( $1 == answerTs ) {
		curTs = $1 ; curUser = headUser ; inMessage = 1 ;
	} else if ( answerTs == "" || newerThan( $1, answerTs ) ) {
		curTs = $1 ; curUser = headUser ; curText = headText ; inMessage = 1 ;
	}
	next ;
}
/^(reaction on the question: |UNMATCHED-REPLY |# )/ { flush() ; next ; }
inMessage && $0 !~ /^[ \t]*$/ { curText = ( curText == "" ? $0 : curText " / " $0 ) ; }
END { flush() ; }
