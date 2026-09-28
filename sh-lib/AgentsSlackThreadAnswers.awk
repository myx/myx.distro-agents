#!/usr/bin/env awk

# Reads one AgentsSlackMessagesFormat.awk rendering of ONE thread and prints only
# what ANSWERS the message named by -v rootTs=<ts>. That message itself is dropped,
# and so is anything older than it -- an answer to a question is always after the
# question.
#
# WHY THIS EXISTS, and why the wait it feeds cannot be correct without it: a wait
# compares a rendering against a baseline, and the question-and-answer caller starts
# from an EMPTY baseline so that an answer arriving while the send is still in flight
# counts as an arrival rather than as scenery. A rendering that carries the question
# itself is never empty, so that wait came back RECEIVED on its own question, on its
# first poll, in zero seconds, every time -- measured. Rendering the ANSWERS ONLY
# makes an empty baseline mean what it says, nobody has answered yet, with no
# baseline race traded against it.
#
# A REACTION ON THE QUESTION IS AN ANSWER, and often the fastest one, so the
# reaction annotations the formatter puts on that message are kept while its text is
# dropped. Its thread annotation is not kept: a reply is already printed here as its
# own line, and reply_count would report that same one arrival a second time.
#
# THE ROOTED MESSAGE MUST BE PRESENT IN THE INPUT. Absent, this exits 1 rather than
# printing nothing, because nothing printed reads as "nobody has answered yet" --
# which is exactly the claim that cannot be made from a rendering not known to be
# that message thread at all.
#
# ts comparison is seconds as a number and microseconds as a fixed-width string,
# never a float: at a magnitude near 1.8e9 a double cannot separate two ts a
# microsecond apart. Same rule and same reason as AgentsToolsSlackTsNewerThan in
# sh-lib/AgentsTools.CommsSlack.include.

BEGIN {
	badUsage = 0
	rootSeen = 0
	inRoot = 0
	inOlder = 0
	## Refused before a single line is read, and END is told, because a filter that
	## printed nothing here would read exactly like a thread nobody has answered in.
	if ( rootTs == "" ) {
		print "AgentsSlackThreadAnswers.awk: -v rootTs=<ts> is required -- with no message named there is nothing to measure an answer against" > "/dev/stderr"
		badUsage = 1
		exit 2
	}
}

function secOf(v) {
	sub(/\..*$/, "", v)
	if ( v == "" ) { v = "0" ; }
	return v + 0
}

function fracOf(v,   f) {
	f = v
	if ( f !~ /\./ ) { return "000000" ; }
	sub(/^[^.]*\./, "", f)
	while ( length(f) < 6 ) { f = f "0" ; }
	return substr(f, 1, 6)
}

function newerThan(candidate, floorTs) {
	if ( secOf(candidate) > secOf(floorTs) ) { return 1 ; }
	if ( secOf(candidate) < secOf(floorTs) ) { return 0 ; }
	if ( fracOf(candidate) > fracOf(floorTs) ) { return 1 ; }
	return 0
}

## A message HEAD line, in the shape the formatter prints: "<ts> | <user> |<annotations> <text>".
## Message text can carry embedded newlines, so a line that is not a head belongs to the
## message above it -- which is why what to drop is tracked as a state and not decided
## line by line.
/^[0-9]+\.[0-9]+ \| / {
	msgTs = $1
	if ( msgTs == rootTs ) {
		rootSeen = 1
		inRoot = 1
		inOlder = 0
		rest = $0
		sub(/^[^|]*\| [^|]*\|/, "", rest)
		while ( match(rest, /^ \[[^]]*\]/) ) {
			ann = substr(rest, RSTART + 1, RLENGTH - 1)
			rest = substr(rest, RSTART + RLENGTH)
			if ( ann ~ /^\[reactions: / ) { print "reaction on the question: " ann ; }
		}
		next
	}
	inRoot = 0
	if ( ! newerThan(msgTs, rootTs) ) { inOlder = 1 ; next ; }
	if ( ! match( " " fromUsers " ", " " $3 " " ) ) { inOlder = 1 ; next ; }
	inOlder = 0
	print
	next
}

{ if ( ! inRoot && ! inOlder ) print ; }

END {
	if ( badUsage ) { exit 2 ; }
	if ( rootSeen ) { exit 0 ; }
	print "AgentsSlackThreadAnswers.awk: this thread rendering carries no message with ts=" rootTs " -- so it is not known to be that message thread, and whether anybody answered it is unknown. Refusing to print an empty answer set, which would read as an answer that has not arrived." > "/dev/stderr"
	exit 1
}
