#!/usr/bin/env awk
# Extracts the answer text: the first line of the first matched reply that is no quote of the
# question -- a ``` fenced block and lines starting with ">" or "&gt;" are skipped, the rule
# AgentsEscalationVerdict.awk reads a verdict by. The rest of that reply, and every later one,
# are clarifications (AgentsPendingReplyClarifications.awk). A reply that is all quote gives
# its first line.
# The reply is its head and every line under it up to the next reply's head, whatever a line
# starts with (`# `, `reaction on the question: `): the rule that reader keeps the rest of it
# by, so the two never differ on which line is the answer. A reply set aside
# (`UNMATCHED-REPLY ` ahead of its head and of each line under it) is no matched reply: ahead
# of the first one it is passed over, and after it its head ends that reply.

function firstUnquoted( line, n,    i, text, inFence, rest, closeAt ) {
	inFence = 0 ; firstText = "" ;
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
		firstText = text ;
		return i ;
	}
	return 0 ;
}

function answer() {
	if ( firstUnquoted( line, count ) == 0 ) { firstText = line[1] ; }
	print firstText ;
	done = 1 ;
}

/^[0-9]+\.[0-9]+ \| / {
	if ( count > 0 ) { answer() ; exit ; }
	text = $0 ; sub(/^[^|]*\| [^|]*\|/, "", text) ;
	while ( match(text, /^ \[[^]]*\]/) ) { text = substr(text, RSTART + RLENGTH) ; }
	sub(/^ +/, "", text) ;
	count = 1 ; line[1] = text ;
	next ;
}
count > 0 && /^UNMATCHED-REPLY [0-9]+\.[0-9]+ \| / { answer() ; exit ; }
count > 0 { line[++count] = $0 ; }
END { if ( count > 0 && ! done ) { answer() ; } }
