#!/usr/bin/env awk

# The short and the full form of a source the caller added (F3.3, Settled): reads the rendering of a Slack source -- a head line
# `<ts> | <user> |<annotations> <text>` for each message and the lines under it -- on its standard input and prints it in the form the
# source was added in. Lines ahead of the first head pass through as they are.
#
#   -v mode        short or full
#   -v ref         what names the source for the operation that reads a message in full: <ref>:<ts> is `--member-comms-slack-read <member> <ref>:<ts> --thread`, and is what a cut message shows
#   -v member      the member whose wait this is
#   -v cutFlag     short: a file made when a message was cut, for the caller to say how to read it in full, once
#   -v dir         full: the folder a message too long for the return is kept in, one file a message, <dir>/<ts>.md, with the message whole
#   -v longBytes   full: the size over which a message is too long for the return (F2.4's threshold)
#   -v indexFile   the source's index cache file, a line for each message once: `<ts> | <user> | <what was served>` and, for one kept as a file, ` -> <file>`;
#                  empty where the session has no folder to keep it in
#
# SHORT returns the message cut to its first 160 bytes (its lines joined), with its own reference, <ref>:<ts>, behind it -- the message
# whole when it is no longer than that -- and keeps only that short form, in the index. A large message is so never copied anywhere.
# The line that says how to read a message in full stands once in a return, and is the caller's: -v cutFlag names a file made when any
# message was cut.
# FULL returns every message whole, in the return. Only a single message too long for the return, over F2.4's threshold (-v longBytes, 8192),
# is kept as a file of its own and served as a preview with a reference: the whole lines that fit in 2 KB, or the first 20, whichever is
# more, never over 7 KB (the preview of a long result, F2.4), then `[kept: <file>, <bytes> bytes, <lines> lines]`. No file is made for any
# other message.
# Every closing brace is preceded by a `;`.

function whole(from, to,   at, out) {
	out = "" ;
	for ( at = from ; at <= to ; at++ ) { out = out line[at] "\n" ; }
	return out ;
}

# A cut at <limit> bytes that does not leave half of a UTF-8 character behind.
function cutAt(text, limit,   out) {
	if ( length(text) <= limit ) { return text ; }
	out = substr(text, 1, limit) ;
	while ( out ~ /[\200-\277]$/ ) { out = substr(out, 1, length(out) - 1) ; }
	if ( out ~ /[\300-\377]$/ ) { out = substr(out, 1, length(out) - 1) ; }
	return out ;
}

function keep(entry, key) {
	if ( indexFile == "" || ( key in indexed ) ) { return ; }
	indexed[key] = 1 ;
	print entry >> indexFile ;
}

function flush(   headText, annot, textFirst, joined, at, shown, cutText, total, path, previewBytes, fit, cap, pre, headPrefix) {
	if ( ! pending ) { return ; }
	pending = 0 ;
	# the head: <ts> | <user> |<annotations> <first line of the text>
	headText = line[from] ;
	annot = headText ;
	sub(/^[0-9.]+ \| [^|]* \|/, "", annot) ;
	headPrefix = substr(headText, 1, length(headText) - length(annot)) ;
	textFirst = annot ;
	pre = "" ;
	while ( match(textFirst, /^ \[[^]]*\]/) ) { pre = pre substr(textFirst, 1, RLENGTH) ; textFirst = substr(textFirst, RLENGTH + 1) ; }
	sub(/^ /, "", textFirst) ;
	headPrefix = headPrefix pre ;
	total = 0 ;
	for ( at = from ; at <= last ; at++ ) { total += length(line[at]) + 1 ; }
	if ( mode == "short" ) {
		joined = textFirst ;
		for ( at = from + 1 ; at <= last ; at++ ) {
			if ( line[at] !~ /^[ \t\r]*$/ ) { joined = joined " / " line[at] ; }
		}
		cutText = cutAt(joined, 160) ;
		if ( cutText != joined ) {
			print headPrefix " " cutText " ... (" total " bytes; " ref ":" msgTs ")" ;
			if ( cutFlag != "" ) { print "cut" > cutFlag ; close(cutFlag) ; }
		} else {
			print headPrefix " " cutText ;
		}
		keep(msgTs " | " msgUser " | " cutText, msgTs) ;
		return ;
	}
	# full: a message that fits the return comes whole, and nothing is made for it
	if ( total <= longBytes + 0 ) {
		for ( at = from ; at <= last ; at++ ) { print line[at] ; }
		keep(msgTs " | " msgUser " | " cutAt(textFirst, 120), msgTs) ;
		return ;
	}
	# one over the threshold: its own file, a preview and a reference in the return
	path = dir "/" msgTs ".md" ;
	system("mkdir -p '" dir "'") ;
	printf "%s", whole(from, last) > path ;
	close(path) ;
	fit = 0 ; cap = 0 ; previewBytes = 0 ;
	for ( at = from ; at <= last ; at++ ) {
		previewBytes += length(line[at]) + 1 ;
		if ( previewBytes <= 2048 ) { fit = at - from + 1 ; }
		if ( previewBytes <= 7168 ) { cap = at - from + 1 ; }
	}
	shown = ( fit > 20 ) ? fit : 20 ;
	if ( shown > last - from + 1 ) { shown = last - from + 1 ; }
	if ( shown > cap ) { shown = cap ; }
	if ( shown < 1 ) { shown = 1 ; }
	for ( at = from ; at < from + shown ; at++ ) {
		if ( at == from && length(line[at]) > 7168 ) { print substr(line[at], 1, 2048) ; } else { print line[at] ; }
	}
	print "  [kept: " path ", " total " bytes, " ( last - from + 1 ) " lines" ( shown < last - from + 1 || length(line[from]) > 7168 ? "; the rest is in the file" : "" ) "]" ;
	keep(msgTs " | " msgUser " | " cutAt(textFirst, 120) " -> " path, msgTs) ;
}

BEGIN {
	if ( indexFile != "" ) {
		while ( ( getline known < indexFile ) > 0 ) {
			if ( known ~ /^[0-9]+\.[0-9]+ \| / ) { key = known ; sub(/ .*$/, "", key) ; indexed[key] = 1 ; }
		}
		close(indexFile) ;
	}
	count = 0 ;
}

/^[0-9]+\.[0-9]+ \| / {
	flush() ;
	pending = 1 ;
	from = ++count ;
	line[from] = $0 ;
	last = from ;
	msgTs = $1 ;
	msgUser = $0 ;
	sub(/^[0-9.]+ \| /, "", msgUser) ;
	sub(/ \|.*$/, "", msgUser) ;
	next ;
}

pending {
	last = ++count ;
	line[last] = $0 ;
	next ;
}

{
	print ;
}

END {
	flush() ;
}
