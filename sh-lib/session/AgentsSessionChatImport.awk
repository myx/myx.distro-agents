#!/usr/bin/env awk

# Turns one rendering of a Slack thread or conversation (AgentsSlackMessagesFormat.awk: a head line
# `<ts> | <user> |<annotations> <text>` for each message, and the lines under it) into the blocks the session chat
# file keeps (AgentsTools.SessionChat.include), for the messages it does not hold yet. It writes the blocks to -v chatOut
# and their index lines to -v indexOut, and prints nothing; the caller appends both under the file's lock.
# Files, in this order: the session's index (or an empty file), the table of Slack user ids to names (the
# mention-id cache, `name=id=...`, or an empty file), the rendering.
#
#   -v channel         the conversation the rendering is of (a message is known by <channel>:<ts>, so one held is never held twice)
#   -v where           <channel>:<thread>, the `where` of every block, as the index keeps it
#   -v origin          how these blocks come in: slack, or reply:<member>
#   -v seen            the member whose own Wait delivers these messages itself, `-` for none
#   -v historyBefore   epoch seconds: a message at or before it is history -- there for whoever reads the thread, never new
#                      to a floor -- and 0 for none
#   -v startLine       the line the first new header will be at in the chat file; -v startNo the number of the first new block
#   -v chatOut, -v indexOut
#
# From is the sender the tooling recorded on the message (`[sender: X]`) or else the Slack account, named by the table where
# it is there. To is the people the tooling's own header addressed (`... -> *_name_*.`), `all` where it names none; the
# body is what follows that header, or the whole text of a message with none. Every closing brace is preceded by a `;`.

function secOf(v) {
	sub(/\..*$/, "", v) ;
	if ( v == "" ) { v = "0" ; }
	return v + 0 ;
}

function pad(v, width) {
	v = v "" ;
	while ( length(v) < width ) { v = "0" v ; }
	return v ;
}

# The UTC time of an epoch, as the header of a block keeps it.
function isoOf(epoch,   days, secs, z, era, doe, yoe, y, doy, mp, d, m) {
	days = int(epoch / 86400) ;
	secs = epoch - days * 86400 ;
	z = days + 719468 ;
	era = int(z / 146097) ;
	doe = z - era * 146097 ;
	yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365) ;
	y = yoe + era * 400 ;
	doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100)) ;
	mp = int((5 * doy + 2) / 153) ;
	d = doy - int((153 * mp + 2) / 5) + 1 ;
	m = ( mp < 10 ) ? mp + 3 : mp - 9 ;
	if ( m <= 2 ) { y++ ; }
	return sprintf("%s-%s-%sT%s:%s:%sZ", pad(y, 4), pad(m, 2), pad(d, 2), pad(int(secs / 3600), 2), pad(int((secs % 3600) / 60), 2), pad(secs % 60, 2)) ;
}

# The names a header addresses, comma-joined; `all` for @here or none.
function addresseesOf(headText,   rest, found, name) {
	found = "" ;
	rest = headText ;
	while ( match(rest, /\*_[^*]+_\*/) ) {
		name = substr(rest, RSTART + 2, RLENGTH - 4) ;
		rest = substr(rest, RSTART + RLENGTH) ;
		found = found ( found == "" ? "" : "," ) name ;
	}
	return ( found == "" ) ? "all" : found ;
}

# Writes the pending message, if there is one.
function flush(   bodyLast, at, text, header, arrow, toPart, endPos, to, firstText, hasHeader) {
	if ( ! pending ) { return ; }
	pending = 0 ;
	key = channel ":" msgTs ;
	if ( key in held ) { return ; }
	held[key] = 1 ;
	firstText = msgText[1] ;
	to = "all" ;
	hasHeader = 0 ;
	arrow = index(firstText, " \342\206\222 ") ;
	if ( arrow > 0 ) {
		toPart = substr(firstText, arrow + 5) ;
		endPos = index(toPart, ". ") ;
		if ( endPos == 0 && toPart ~ /\.$/ ) { endPos = length(toPart) ; }
		if ( endPos > 0 ) {
			hasHeader = 1 ;
			to = addresseesOf(substr(toPart, 1, endPos - 1)) ;
			firstText = substr(toPart, endPos + 2) ;
			if ( endPos == length(toPart) ) { firstText = "" ; }
		}
	}
	msgText[1] = firstText ;
	bodyLast = msgLines ;
	while ( bodyLast > 0 && msgText[bodyLast] ~ /^[ \t\r]*$/ ) { bodyLast-- ; }
	from = msgSender ;
	if ( from == "" ) { from = ( msgUser in nameOf ) ? nameOf[msgUser] : msgUser ; }
	if ( from == "" ) { from = "unknown" ; }
	gsub(/ -> /, " - ", from) ;
	gsub(/ -> /, " - ", to) ;
	header = isoOf(secOf(msgTs)) " " from " -> " to ":" ;
	print header >> chatOut ;
	lineCount = 1 ;
	for ( at = 1 ; at <= bodyLast ; at++ ) {
		text = msgText[at] ;
		if ( at == 1 && text == "" && bodyLast >= 2 ) { continue ; }
		if ( text ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ ) { text = " " text ; }
		print text >> chatOut ;
		lineCount++ ;
	}
	print "" >> chatOut ;
	# A tracking post of the tooling (`[tracking: <kind>]`) is held for whoever reads the thread and is never new to a floor, as history is: it tells
	# nobody anything the tooling did not already do. News are `handback`, a run reporting to the run that started it, and what the tooling sent that is
# addressed to someone (`tooling` with a header naming its addressees: DISMISSED among it): that always reaches the one it is for.
	printf "%d\t%s\t%s\t%s\t%d\t%s\n", startNo, msgTs, where, ( secOf(msgTs) <= historyBefore + 0 || ( msgTracking != "" && msgTracking != "handback" && ! ( msgTracking == "tooling" && to != "all" ) ) ) ? "history" : origin, startLine, seen >> indexOut ;
	startNo++ ;
	startLine += lineCount + 1 ;
}

BEGIN {
	historyBefore += 0 ;
}

# 1: the index. A message is known by its conversation and its ts.
FILENAME == ARGV[1] {
	split($0, field, "\t") ;
	conv = field[3] ;
	sub(/:.*$/, "", conv) ;
	held[conv ":" field[2]] = 1 ;
	next ;
}

# 2: the table of Slack accounts and their names.
FILENAME == ARGV[2] {
	split($0, field, "=") ;
	if ( field[1] != "" && field[2] != "" && field[2] != "-" ) { nameOf[field[2]] = field[1] ; }
	next ;
}

# 3: the rendering.
/^[0-9]+\.[0-9]+ \| / {
	flush() ;
	pending = 1 ;
	msgTs = $1 ;
	rest = $0 ;
	sub(/^[0-9.]+ \| /, "", rest) ;
	msgUser = rest ;
	sub(/ \|.*$/, "", msgUser) ;
	sub(/^[^|]*\|/, "", rest) ;
	msgSender = "" ;
	msgTracking = "" ;
	while ( match(rest, /^ \[[^]]*\]/) ) {
		ann = substr(rest, RSTART + 1, RLENGTH - 1) ;
		rest = substr(rest, RSTART + RLENGTH) ;
		if ( ann ~ /^\[tracking: / ) {
			msgTracking = ann ;
			sub(/^\[tracking: /, "", msgTracking) ;
			sub(/\]$/, "", msgTracking) ;
		}
		if ( ann ~ /^\[sender: / ) {
			msgSender = ann ;
			sub(/^\[sender: /, "", msgSender) ;
			sub(/\]$/, "", msgSender) ;
		}
	}
	sub(/^ /, "", rest) ;
	msgLines = 1 ;
	msgText[1] = rest ;
	next ;
}

pending {
	msgLines++ ;
	msgText[msgLines] = $0 ;
}

END {
	flush() ;
}
