#!/usr/bin/env awk

# Reads the session chat file forward from a pointer and prints the blocks that are the floor of one member's run
# (F3.3, AgentsTools.SessionChat.include): each block ahead of a line `# via <source>` that names where it came from,
# the header, the body, and a blank line. Files, in this order: the session's index, the chat file; they are two files
# that differ, and the index is not empty.
#
#   -v after        the pointer: only a block with a number past it is read
#   -v session      the session whose chat file this is, for its own channel kinds: a block recorded on its
#                   printback channel (`printback:<session>`, F2.2) is its own as a block of its thread is
#   -v member       the reading run's member: its own posts are never its floor
#   -v role         executor: every message of the session thread; participant: the ones that tag or mention the member
#   -v thread       <channel>:<thread> of the session's thread, empty for none
#   -v memberId     the member's Slack account, for a mention written as <@id>; empty for none
#   -v covered      spaced <channel>:<thread> a source of the same Wait reads itself: their blocks are read past and not printed
#   -v pendingBefore  the UTC time (as a header keeps it) before which a post that has no ts yet is given up; empty: never given up
#   -v replySource  the name a reply to a post of the member comes by, such as replies:<session>
#   -v side         a file for what the caller stores, one line each: `newest <n>` (the last block read, to be the pointer) and
#                   `delivered <count>`
#   -v filter       spaced words of me, here, any: the session channel's own read (F7.2, --wait-session-channel; AgentsTools.ThisSession.include)
#                   in place of the floor's rule for the messages of the session thread -- me: addressed to the member or mentioning it,
#                   here: addressed to all, any: every message; empty for the floor. A block of the thread the floor owes the member that
#                   the words pass over is HELD: `newest` stops in front of the first one, so the floor still gives it, and a block the
#                   words delivered beyond that point is named on a line `seen <n>`, to be marked delivered to the member, so nothing is
#                   given twice. A reply to a post of the member is never of the thread, and is held when the floor owes it.
#
# A block is delivered when it is not history, not already delivered to the member (the index's last field), not the member's
# own, and: a reply to the member's own post (origin reply:<member>) is the floor of that member alone; a message of the
# session thread is the floor of the executor, and of a participant when it names it (in a session with no thread, a message recorded `local`
# is that, and no `local` message is of a session that has a thread); a message recorded on the session's printback channel
# (`printback:<session>`, F2.2) is the session's own in a session with a thread or without one, the root-native kind having no
# thread to be the session's own by; nothing else is. A message not posted
# (no ts yet) is nobody's, and a post of another member that is not yet is not passed: the blocks behind it wait, and `newest` stays
# the block before it, until it has a ts, or is given up (`refused`, `unknown` in the place of its conversation), or its header
# is older than pendingBefore (F9.3: a post the writer will still deliver reaches every floor once it is delivered). A post of
# the reading member's own stops nothing. A block whose origin is `notice` is never the floor: it is a notice the spawn proxy
# recorded for the session (F3.3, AgentsTools.CommsPrintback.include), and the next foreground call's digest alone surfaces it,
# one line, so the reader passes it and moves on. Every closing brace is preceded by a `;`.

BEGIN {
	delivered = 0 ;
	mentionRe = "(^|[^A-Za-z0-9_-])@" member "([^A-Za-z0-9_-]|$)" ;
	coveredCount = split(covered, coveredWord, " ") ;
	filterCount = split(filter, filterWord, " ") ;
	for ( filterAt = 1 ; filterAt <= filterCount ; filterAt++ ) {
		if ( filterWord[filterAt] == "me" ) { wantMe = 1 ; }
		else if ( filterWord[filterAt] == "here" ) { wantHere = 1 ; }
		else if ( filterWord[filterAt] == "any" ) { wantAny = 1 ; }
	}
	filtered = ( filterCount > 0 ) ;
	holdAt = 0 ;
}

FILENAME == ARGV[1] {
	count++ ;
	split($0, field, "\t") ;
	idxNo[count] = field[1] + 0 ;
	idxWhere[count] = field[3] ;
	idxOrigin[count] = field[4] ;
	idxLine[count] = field[5] + 0 ;
	idxSeen[count] = field[6] ;
	idxTs[count] = field[2] ;
	if ( idxNo[count] == after + 1 ) { firstAt = count ; }
	next ;
}

FILENAME == ARGV[2] {
	if ( firstAt > 0 && FNR >= idxLine[firstAt] ) { text[FNR] = $0 ; last = FNR ; }
	next ;
}

function isCovered(whereValue,   at) {
	for ( at = 1 ; at <= coveredCount ; at++ ) {
		if ( coveredWord[at] == whereValue ) { return 1 ; }
	}
	return 0 ;
}

# Whether a block's conversation is the session's own: its thread, else, for a session that has none, `local` -- what the console left
# for the chat file alone (F11.6): recorded with no ts and nothing posted, and the floor of a session with no thread is that file.
# The session's printback channel is its own in either case: the root-native kind has no thread, and a message on it is the
# session's whatever else the session keeps (F2.2).
function ownThread(whereValue) {
	if ( whereValue == "printback:" session ) { return 1 ; }
	return ( thread != "" ) ? ( whereValue == thread ) : ( whereValue == "local" ) ;
}

# Where a block of the session's own came from, as the `# via` line names it: `local` for the console's, `printback` for the
# root-native kind's, `slack:<conversation>:<thread>` for the session thread's.
function sourceOf(whereValue) {
	if ( whereValue == "local" ) { return "local" ; }
	if ( whereValue ~ /^printback:/ ) { return "printback" ; }
	return "slack:" whereValue ;
}

function listHas(listValue, wanted,   items, itemCount, at) {
	itemCount = split(listValue, items, ",") ;
	for ( at = 1 ; at <= itemCount ; at++ ) {
		if ( items[at] == wanted ) { return 1 ; }
	}
	return 0 ;
}

END {
	if ( firstAt == 0 ) { exit ; }
	for ( at = firstAt ; at <= count ; at++ ) {
		head = text[idxLine[at]] ;
		endLine = ( at < count ) ? idxLine[at + 1] - 1 : last ;
		# the header: <iso-time> <from> -> <to>:
		who = head ;
		sub(/^[^ ]* /, "", who) ;
		from = who ;
		sub(/ -> .*$/, "", from) ;
		to = who ;
		sub(/^.* -> /, "", to) ;
		sub(/:$/, "", to) ;
		take = 0 ;
		origin = idxOrigin[at] ;
		if ( origin != "history" && idxWhere[at] == "-" && from != member && ! listHas(idxSeen[at], member) && ( pendingBefore == "" || substr(head, 1, 20) >= pendingBefore ) ) {
			stopAt = at ;
			break ;
		}
		if ( origin == "history" || origin == "notice" || idxWhere[at] == "-" ) {
			take = 0 ;
		} else if ( listHas(idxSeen[at], member) || from == member ) {
			take = 0 ;
		} else if ( origin ~ /^reply:/ ) {
			take = ( origin == "reply:" member ) ;
			source = replySource ;
		} else if ( ownThread(idxWhere[at]) ) {
			source = sourceOf(idxWhere[at]) ;
			if ( role == "executor" ) { take = 1 ; }
			else {
				take = listHas(to, member) ;
				for ( row = idxLine[at] + 1 ; ! take && row <= endLine ; row++ ) {
					if ( text[row] ~ mentionRe ) { take = 1 ; }
					else if ( memberId != "" && index(text[row], "<@" memberId ">") > 0 ) { take = 1 ; }
				}
			}
		}
		newest = idxNo[at] ;
		if ( filtered ) {
			floorOwed = ( take && ! isCovered(idxWhere[at]) ) ;
			sel = 0 ;
			if ( ! ( origin == "history" || idxWhere[at] == "-" || listHas(idxSeen[at], member) || from == member || origin ~ /^reply:/ ) && ownThread(idxWhere[at]) && ! isCovered(idxWhere[at]) ) {
				source = sourceOf(idxWhere[at]) ;
				if ( wantAny ) { sel = 1 ; }
				if ( wantHere && listHas(to, "all") ) { sel = 1 ; }
				if ( wantMe && listHas(to, member) ) { sel = 1 ; }
				for ( row = idxLine[at] + 1 ; wantMe && ! sel && row <= endLine ; row++ ) {
					if ( text[row] ~ mentionRe ) { sel = 1 ; }
					else if ( memberId != "" && index(text[row], "<@" memberId ">") > 0 ) { sel = 1 ; }
				}
			}
			if ( ! sel ) {
				if ( floorOwed && holdAt == 0 ) { holdAt = idxNo[at] ; }
				continue ;
			}
			take = 1 ;
		}
		if ( ! take ) { continue ; }
		if ( isCovered(idxWhere[at]) ) { continue ; }
		stop = endLine ;
		while ( stop > idxLine[at] && text[stop] ~ /^[ \t\r]*$/ ) { stop-- ; }
		if ( source != lastSource ) { print "# via " source ; lastSource = source ; }
		for ( row = idxLine[at] ; row <= stop ; row++ ) { print ( text[row] ~ /^# via / ) ? " " text[row] : text[row] ; }
		print "" ;
		delivered++ ;
		deliveredNo[delivered] = idxNo[at] ;
	}
	if ( side != "" ) {
		pointerTo = ( filtered && holdAt > 0 ) ? holdAt - 1 : idxNo[count] ;
		if ( stopAt > 0 && idxNo[stopAt] - 1 < pointerTo ) { pointerTo = idxNo[stopAt] - 1 ; }
		print "newest " pointerTo > side ;
		print "delivered " delivered > side ;
		for ( deliveredAt = 1 ; filtered && deliveredAt <= delivered ; deliveredAt++ ) {
			if ( deliveredNo[deliveredAt] > pointerTo ) { print "seen " deliveredNo[deliveredAt] > side ; }
		}
	}
}
