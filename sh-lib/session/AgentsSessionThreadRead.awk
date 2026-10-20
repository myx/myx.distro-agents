#!/usr/bin/env awk

# Prints the session thread from the session chat file (F7.2, ThisSession's --get-session-thread; AgentsTools.ThisSession.include):
# the blocks of the file whose conversation:thread is the session's, in the order of the file, each as the file holds it, the header,
# the body, and a blank line. Files, in this order: the session's index, the chat file. The index is not empty. Nothing is changed.
#
#   -v thread    <channel>:<thread> of the session's thread
#   -v own       yes: only the caller's own traffic -- sent by the member, addressed to it (in the to of the header), or mentioning it
#   -v member    the caller's member name
#   -v memberId  the caller's Slack account, for a mention written as <@id>; empty for none
#
# A block that was never posted (no ts yet), a message of another conversation and a reply to a post of the run are not the thread.
# Every closing brace is preceded by a `;`.

BEGIN {
	mentionRe = "(^|[^A-Za-z0-9_-])@" member "([^A-Za-z0-9_-]|$)" ;
}

FILENAME == ARGV[1] {
	count++ ;
	split($0, field, "\t") ;
	idxNo[count] = field[1] + 0 ;
	idxWhere[count] = field[3] ;
	idxOrigin[count] = field[4] ;
	idxLine[count] = field[5] + 0 ;
	next ;
}

FILENAME == ARGV[2] {
	text[FNR] = $0 ;
	last = FNR ;
	next ;
}

function listHas(listValue, wanted,   items, itemCount, at) {
	itemCount = split(listValue, items, ",") ;
	for ( at = 1 ; at <= itemCount ; at++ ) {
		if ( items[at] == wanted ) { return 1 ; }
	}
	return 0 ;
}

END {
	if ( thread == "" ) { exit ; }
	for ( at = 1 ; at <= count ; at++ ) {
		if ( idxWhere[at] != thread || idxOrigin[at] ~ /^reply:/ ) { continue ; }
		endLine = ( at < count ) ? idxLine[at + 1] - 1 : last ;
		# the header: <iso-time> <from> -> <to>:
		who = text[idxLine[at]] ;
		sub(/^[^ ]* /, "", who) ;
		from = who ;
		sub(/ -> .*$/, "", from) ;
		to = who ;
		sub(/^.* -> /, "", to) ;
		sub(/:$/, "", to) ;
		take = 1 ;
		if ( own == "yes" ) {
			take = ( from == member || listHas(to, member) ) ;
			for ( row = idxLine[at] + 1 ; ! take && row <= endLine ; row++ ) {
				if ( text[row] ~ mentionRe ) { take = 1 ; }
				else if ( memberId != "" && index(text[row], "<@" memberId ">") > 0 ) { take = 1 ; }
			}
		}
		if ( ! take ) { continue ; }
		stop = endLine ;
		while ( stop > idxLine[at] && text[stop] ~ /^[ \t\r]*$/ ) { stop-- ; }
		for ( row = idxLine[at] ; row <= stop ; row++ ) { print text[row] ; }
		print "" ;
	}
}
