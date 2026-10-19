#!/usr/bin/env awk

# Reads ONE rendering (AgentsSlackMessagesFormat.awk) of the thread, or of the conversation, of one post
# the run made, and prints what the floor of a plain Wait returns of it (AgentsWaitProbeReplies,
# sh-lib/member/AgentsTools.MemberWait.include). Load AgentsDismissalMatch.awk with a first -f.
#
#   -v mode=thread     every message after -v floorTs, whoever wrote it, never the run's own: a reply is
#                      expected in the thread of a post, and any message there answers it. With -v deliver=0
#                      nothing is printed: another source of the same Wait returns the thread.
#   -v mode=channel    the messages after -v floorTs of the people the post addressed (-v addressees, spaced:
#                      an account, or a member's name, told by the sender the tooling recorded on the
#                      message) and the ones that mention the run (-v callerName). Every message after the
#                      floor counts as a sibling of the post, the run's own included, and none past
#                      -v siblingsMax is read: -v siblings is the count so far. Once it has reached the
#                      maximum the siblings are no longer watched (-v mentionsOnly=1): the read goes on from the
#                      floor, and only a message that mentions the run is printed, and nothing is counted.
#   -v postTs          the post itself. It is never printed, but its line gives the reactions it has.
#   -v floorTs         only a message newer than this is new.
#   -v side            a file for what the caller stores, one line each: `newest <ts>` (the newest message
#                      read after the floor, `-` for none), `siblings <count>`, and `reactions <annotations>`
#                      (those of the post, `-` for none).
#
# A message is its head line, `<ts> | <user> |<annotations> <text>`, and the lines under it. The run's own
# message is held whole and printed only where it dismisses the run (dismissalOf, as the other readers of
# a thread do). A line under a message that reads as a mark of this reader's own is printed one space in.
#
# ts comparison is seconds as a number and microseconds as a fixed-width string, never a float, as in
# AgentsSlackThreadAnswers.awk. Every closing brace is preceded by a `;` (reference/shell.md's awk axiom).

BEGIN {
	addressCount = split(addressees, addressWord, " ")
	newest = ""
	count = siblings + 0
	maxCount = siblingsMax + 0
	emit = 0
	heldOwn = ""
	reactions = ""
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

function newerThan(candidate, floorValue) {
	if ( secOf(candidate) > secOf(floorValue) ) { return 1 ; }
	if ( secOf(candidate) < secOf(floorValue) ) { return 0 ; }
	if ( fracOf(candidate) > fracOf(floorValue) ) { return 1 ; }
	return 0
}

## The `[sender: X]` annotation of a head line, or "" where it carries none.
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

## Whether the head line is a message of one the post addressed: by the account in its user column, or by the
## member the tooling recorded as its sender.
function fromAddressee(line,   user, who, idx) {
	user = line
	sub(/^[^|]*\| /, "", user)
	sub(/ \|.*$/, "", user)
	who = lineSender(line)
	for ( idx = 1 ; idx <= addressCount ; idx++ ) {
		if ( addressWord[idx] == "-" ) { continue ; }
		if ( addressWord[idx] == user || ( who != "" && addressWord[idx] == who ) ) { return 1 ; }
	}
	return 0
}

## Whether the head line mentions the run: its member tagged in the send header's addressees, as
## `*_<member>_*` after the arrow, or written `@<member>` in the text.
function mentionsRun(line,   rest, arrow, toPart, endPos) {
	if ( callerName == "" ) { return 0 ; }
	rest = line
	gsub(/[\r\n\t]+/, " ", rest)
	sub(/^[0-9]+\.[0-9]+ \| [^|]* \|/, "", rest)
	while ( match(rest, /^ \[[^]]*\]/) ) { rest = substr(rest, RSTART + RLENGTH) ; }
	sub(/^ +/, "", rest)
	arrow = index(rest, " → ")
	if ( arrow > 0 ) {
		toPart = substr(rest, arrow + length(" → "))
		endPos = index(toPart, ". ")
		if ( endPos > 0 ) { toPart = substr(toPart, 1, endPos - 1) ; }
		if ( index(toPart, "*_" callerName "_*") > 0 ) { return 1 ; }
	}
	return ( rest ~ ( "(^|[^A-Za-z0-9_-])@" callerName "([^A-Za-z0-9_-]|$)" ) )
}

## The reactions of a head line, each `[reactions: <name> x<count> (<users>)]`, spaced.
function reactionsOf(line,   rest, ann, found) {
	rest = line
	sub(/^[^|]*\| [^|]*\|/, "", rest)
	found = ""
	while ( match(rest, /^ \[[^]]*\]/) ) {
		ann = substr(rest, RSTART + 1, RLENGTH - 1)
		rest = substr(rest, RSTART + RLENGTH)
		if ( ann ~ /^\[reactions: / ) { found = found ( found == "" ? "" : " " ) ann ; }
	}
	return found
}

function releaseHeldOwn() {
	if ( heldOwn != "" && dismissalOf(heldOwn, callerName) ) { print heldOwn ; }
	heldOwn = ""
}

/^[0-9]+\.[0-9]+ \| / {
	releaseHeldOwn()
	emit = 0
	msgTs = $1
	if ( msgTs == postTs ) {
		reactions = reactionsOf($0)
		next
	}
	if ( ! newerThan(msgTs, floorTs) ) { next ; }
	if ( mode == "channel" && ! mentionsOnly ) {
		if ( count >= maxCount ) { next ; }
		count++
	}
	if ( newest == "" || newerThan(msgTs, newest) ) { newest = msgTs ; }
	if ( callerName != "" && lineSender($0) == callerName ) {
		heldOwn = $0
		next
	}
	if ( mode == "channel" && ! ( ( ! mentionsOnly && fromAddressee($0) ) || mentionsRun($0) ) ) { next ; }
	if ( mode != "channel" && ! deliver ) { next ; }
	emit = 1
	print
	next
}

{
	if ( heldOwn != "" ) { heldOwn = heldOwn "\n" $0 ; next ; }
	if ( emit ) { print ( $0 ~ /^(# replies to |reactions on your post )/ ? " " $0 : $0 ) ; }
}

END {
	releaseHeldOwn()
	if ( side != "" ) {
		print "newest " ( newest == "" ? "-" : newest ) > side
		print "siblings " count > side
		print "reactions " ( reactions == "" ? "-" : reactions ) > side
	}
}
