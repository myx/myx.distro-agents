#!/usr/bin/env awk

# Every message a Wait shows carries the address a reply to it belongs at, `[reply-to: <conversation>:<ts>]`, on the message's own
# head line, right after the two fields every reader already parses (<ts> | <user> |). ONE mechanism for every source kind: the
# conversation is read from the rendering where the rendering names it (`# in <conversation>` of a person's direct conversations,
# `# replies to your post <conversation>:<ts>`, `# via <source>` of the session thread), and from the source itself otherwise
# (-v conv=). The address is the message's own ts, except for a source that IS one thread: there every message answers in that
# thread, so the thread's ts (-v thread=) is the address for all of them.
#
# Why it exists: a message shown without an address is answered at the top of the conversation, not in the thread it belongs to,
# and the person it was for never sees it where he was reading. The rendering carries a `thread_ts` for a reply but the conversation
# of the read, never the two together, so the address is decided here, once, by the one reader that knows both.
#
# Read on stdin, printed on stdout, every line kept in its place. A head whose conversation is unknown is printed as it stands:
# an address is never invented.

function address(ts,   target) {
	target = (thread != "") ? thread : ts ;
	if (conv == "") { return "" ; }
	return " [reply-to: " conv ":" target "]" ;
}

# A source named as a target, `<channel>:<ts>`, with the `:conversation` form and a `client:` marker taken off first.
function fromTarget(target,   rest, at) {
	rest = target ;
	if (index(rest, kind ":") == 1) { rest = substr(rest, length(kind) + 2) ; }
	sub(/:conversation$/, "", rest) ;
	if (rest ~ /^client:/) { rest = substr(rest, 8) ; }
	at = 0 ;
	for (i = length(rest) ; i >= 1 ; i--) { if (substr(rest, i, 1) == ":") { at = i ; break ; } }
	if (at == 0) { conv = "" ; thread = "" ; return ; }
	conv = substr(rest, 1, at - 1) ;
	thread = (kind == "slack") ? substr(rest, at + 1) : "" ;
}

BEGIN {
	if (source != "") { fromTarget(source) ; }
	while ( ( getline line ) > 0 ) {
		if (line ~ /^# in /) { conv = substr(line, 6) ; thread = "" ; print line ; continue ; }
		if (line ~ /^# replies to your post /) {
			rest = substr(line, 24) ;
			at = 0 ;
			for (i = length(rest) ; i >= 1 ; i--) { if (substr(rest, i, 1) == ":") { at = i ; break ; } }
			conv = (at > 0) ? substr(rest, 1, at - 1) : "" ;
			thread = (at > 0) ? substr(rest, at + 1) : "" ;
			print line ;
			continue ;
		}
		if (line ~ /^# via /) { fromTarget(substr(line, 7)) ; print line ; continue ; }
		if (line ~ /^[0-9]+\.[0-9]+ \| / && match(line, /^[0-9]+\.[0-9]+ \| [^|]* \|/)) {
			ts = line ;
			sub(/ .*$/, "", ts) ;
			headEnd = RLENGTH ;
			## A reply that names its thread answers in it: the rendering's own `[thread-reply of <ts>]` says so.
			threadOf = "" ;
			if (match(line, /\[thread-reply of [0-9]+\.[0-9]+\]/)) { threadOf = substr(line, RSTART + 17, RLENGTH - 18) ; }
			savedThread = thread ;
			if (threadOf != "") { thread = threadOf ; }
			mark = address(ts) ;
			thread = savedThread ;
			if (mark != "") { print substr(line, 1, headEnd) mark substr(line, headEnd + 1) ; continue ; }
		}
		print line ;
	}
}
