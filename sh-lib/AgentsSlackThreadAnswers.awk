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
# dropped -- only those an addressee made, the same rule a reply is held to. Its
# thread annotation is not kept: a reply is already printed here as its own line,
# and reply_count would report that same one arrival a second time.
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
#
# A THREAD SEVERAL QUESTIONS SHARE (-v tag=Q<n> -v threadCount=<questions it has held>
# -v others="<ts>/<state> ..." from AgentsToolsAskThreadOthers): once it has held more
# than one, a reply starting with this question's number answers it, and the number is
# dropped from what is printed so the reply reads as it would alone; a reply starting
# with another question's number is not printed. A reply with no number answers the
# latest question posted above it: printed when that is this one, not printed when it is
# another still open, and printed marked `UNMATCHED-REPLY ` when that other one was closed
# before the reply came, so its reader returns it unclassified rather than any asker
# taking it. A reaction answers the message it is on, as ever. In a thread that has held
# one question, or with no tag given, nothing here changes. Held, not open: a late reply
# numbered for an answered question never answers the one still open.

BEGIN {
	badUsage = 0
	rootSeen = 0
	inRoot = 0
	inOlder = 0
	## Refused before a single line is read, and END is told, because a filter that
	## printed nothing here would read exactly like a thread nobody has answered in.
	tagNum = tag
	sub(/^[Qq]/, "", tagNum)
	shared = ( tag != "" && threadCount + 0 > 1 )
	## conversation mode: any new post counts, so the addressee check below is
	## skipped -- everyone posts through one shared Slack account today.
	conversationMode = ( mode == "conversation" )
	otherCount = 0
	otherWords = split(others, otherWord, " ")
	for ( otherIdx = 1 ; otherIdx <= otherWords ; otherIdx++ ) {
		if ( index(otherWord[otherIdx], "/") == 0 ) { continue ; }
		otherCount++
		otherTs[otherCount] = substr(otherWord[otherIdx], 1, index(otherWord[otherIdx], "/") - 1)
		otherState[otherCount] = substr(otherWord[otherIdx], index(otherWord[otherIdx], "/") + 1)
	}
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

## The formatter's own `[sender: X]` annotation for one rendered line, or "" where
## the message carries none -- absence is never read as a match, only an actual
## name is. Conversation mode uses this to skip the caller's own post by identity
## rather than by timestamp, since the caller's own next post is still newer than
## its own floor.
function lineSender(line,   rest, ann, val) {
	rest = line
	sub(/^[^|]*\| [^|]*\|/, "", rest)
	while ( match(rest, /^ \[[^]]*\]/) ) {
		ann = substr(rest, RSTART + 1, RLENGTH - 1)
		rest = substr(rest, RSTART + RLENGTH)
		if ( ann ~ /^\[sender: / ) {
			val = ann
			sub(/^\[sender: /, "", val)
			sub(/\]$/, "", val)
			return val
		}
	}
	return ""
}

## A reaction answers only when one of its users is an addressee, the same rule a reply
## is held to. The users are the formatter's "(U1,U2)" tail of the annotation.
function reactedByAddressee(ann,   userList, userCount, userIdx, reactUser) {
	userList = ann
	sub(/^.*\(/, "", userList)
	sub(/\)\]$/, "", userList)
	userCount = split(userList, reactUser, ",")
	for ( userIdx = 1 ; userIdx <= userCount ; userIdx++ ) {
		if ( reactUser[userIdx] != "" && index( " " fromUsers " ", " " reactUser[userIdx] " " ) ) { return 1 ; }
	}
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
			if ( ann ~ /^\[reactions: / && reactedByAddressee(ann) ) { print "reaction on the question: " ann ; }
		}
		next
	}
	inRoot = 0
	if ( ! newerThan(msgTs, rootTs) ) { inOlder = 1 ; next ; }
	if ( ! conversationMode && ! index( " " fromUsers " ", " " $3 " " ) ) { inOlder = 1 ; next ; }
	if ( conversationMode && callerName != "" && lineSender($0) == callerName ) { inOlder = 1 ; next ; }
	inOlder = 0
	if ( shared ) {
		replyText = $0
		sub(/^[^|]*\| [^|]*\|/, "", replyText)
		while ( match(replyText, /^ \[[^]]*\]/) ) { replyText = substr(replyText, RSTART + RLENGTH) ; }
		sub(/^ +/, "", replyText)
		if ( match(replyText, /^[Qq][0-9]+/) ) {
			if ( substr(replyText, 2, RLENGTH - 1) + 0 != tagNum + 0 ) { inOlder = 1 ; next ; }
			replyHead = substr($0, 1, length($0) - length(replyText))
			replyText = substr(replyText, RLENGTH + 1)
			sub(/^[ \t]*[:.,)-]?[ \t]*/, "", replyText)
			print replyHead replyText
			next
		}
		## No number: it answers the latest question posted above it, while that one is open.
		latestTs = rootTs
		latestState = "this"
		for ( otherIdx = 1 ; otherIdx <= otherCount ; otherIdx++ ) {
			if ( newerThan(msgTs, otherTs[otherIdx]) && newerThan(otherTs[otherIdx], latestTs) ) {
				latestTs = otherTs[otherIdx]
				latestState = otherState[otherIdx]
			}
		}
		if ( latestState == "this" ) { print ; next ; }
		if ( latestState ~ /^[0-9]+$/ && secOf(msgTs) > latestState + 0 ) {
			print "UNMATCHED-REPLY " $0
			next
		}
		inOlder = 1
		next
	}
	print
	next
}

{ if ( ! inRoot && ! inOlder ) print ; }

END {
	if ( badUsage ) { exit 2 ; }
	## Conversation mode's own floor is often "now", picked with no post of ours to
	## name -- never a message this thread is required to carry. The read itself
	## already succeeded by the time this runs, which is all rootSeen ever stood in
	## for outside the question-and-answer case.
	if ( rootSeen || conversationMode ) { exit 0 ; }
	print "AgentsSlackThreadAnswers.awk: this thread rendering carries no message with ts=" rootTs " -- so it is not known to be that message thread, and whether anybody answered it is unknown. Refusing to print an empty answer set, which would read as an answer that has not arrived." > "/dev/stderr"
	exit 1
}
