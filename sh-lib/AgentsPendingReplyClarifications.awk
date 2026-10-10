#!/usr/bin/env awk
# Reads one rendering of the answers to a question -- AgentsSlackThreadAnswers.awk's shape:
# "<ts> | <user> | <text>" heads, each followed by the rest of that message's lines -- and
# prints the CLARIFICATIONS on its answer, one line per message, as "<ts>\t<user>\t<text>":
# the rest of the message the answer was taken from (-v answerTs=<its ts>), after its answer
# line -- its first line that is no quote of the question (firstUnquoted, the rule
# AgentsEscalationVerdict.awk reads the verdict by) -- then every later message whole. A
# message's lines are folded with " / ". Messages at or before answerTs, reaction lines, "# "
# lines and replies marked UNMATCHED-REPLY are not printed. With the answer a reaction, pass
# the question's own ts: every reply is then a clarification.

function secOf( v ) { sub( /\..*$/, "", v ) ; return ( v == "" ? 0 : v + 0 ) ; }
function fracOf( v ) { if ( v !~ /\./ ) { return "000000" ; } sub( /^[^.]*\./, "", v ) ; return substr( v "000000", 1, 6 ) ; }
function newerThan( a, b ) {
	if ( secOf( a ) != secOf( b ) ) { return secOf( a ) > secOf( b ) ; }
	return fracOf( a ) > fracOf( b ) ;
}

## The first line of line[1..n] that is no quote heading the reply: blank lines, lines
## starting with ">" or "&gt;", and a ``` fenced block are skipped. Returns its index, 0 when
## every line is a quote. The same rule as AgentsEscalationVerdict.awk.
function firstUnquoted( line, n,    i, text, inFence, rest, closeAt ) {
	inFence = 0 ;
	for ( i = 1 ; i <= n ; i++ ) {
		text = line[i] ;
		if ( inFence ) {
			closeAt = index( text, "```" ) ;
			if ( closeAt == 0 ) { continue ; }
			inFence = 0 ;
			text = substr( text, closeAt + 3 ) ;
		} else {
			sub( /^[ \t]+/, "", text ) ;
			if ( substr( text, 1, 3 ) == "```" ) {
				rest = substr( text, 4 ) ;
				closeAt = index( rest, "```" ) ;
				if ( closeAt == 0 ) { inFence = 1 ; continue ; }
				text = substr( rest, closeAt + 3 ) ;
			}
		}
		sub( /^[ \t]+/, "", text ) ;
		if ( text == "" || text ~ /^(>|&gt;)/ ) { continue ; }
		return i ;
	}
	return 0 ;
}

function flush(    from, i, text ) {
	if ( curTs != "" ) {
		from = 1 ;
		if ( curIsAnswer ) { from = firstUnquoted( curLine, curCount ) + 1 ; if ( from == 1 ) { from = curCount + 1 ; } }
		text = "" ;
		for ( i = from ; i <= curCount ; i++ ) {
			if ( curLine[i] ~ /^[ \t]*$/ ) { continue ; }
			text = ( text == "" ? curLine[i] : text " / " curLine[i] ) ;
		}
		if ( text != "" ) { printf "%s\t%s\t%s\n", curTs, curUser, text ; }
	}
	curTs = "" ; curUser = "" ; curCount = 0 ; curIsAnswer = 0 ; inMessage = 0 ;
}

/^[0-9]+\.[0-9]+ \| / {
	flush() ;
	headUser = $0 ; sub( /^[^|]*\| /, "", headUser ) ; sub( / \|.*$/, "", headUser ) ;
	headText = $0 ; sub( /^[^|]*\| [^|]*\|/, "", headText ) ;
	while ( match( headText, /^ \[[^]]*\]/ ) ) { headText = substr( headText, RSTART + RLENGTH ) ; }
	sub( /^ +/, "", headText ) ;
	if ( $1 == answerTs || answerTs == "" || newerThan( $1, answerTs ) ) {
		curTs = $1 ; curUser = headUser ; curIsAnswer = ( $1 == answerTs ) ; inMessage = 1 ;
		curCount = 1 ; curLine[1] = headText ;
	}
	next ;
}
/^(reaction on the question: |UNMATCHED-REPLY |# )/ { flush() ; next ; }
inMessage { curLine[++curCount] = $0 ; }
END { flush() ; }
