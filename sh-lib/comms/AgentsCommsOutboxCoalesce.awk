#!/usr/bin/awk -f
##
## AgentsCommsOutboxCoalesce.awk -- the records of a comms outbox after the first `sent` of them, with every run of consecutive tracking posts of one member and
## one session joined into ONE message, up to Slack's weight limit. Called by AgentsToolsCommsCachePush (AgentsTools.CommsCache.include) with -v sent=<records
## already posted> over the file the pusher is about to push, under the push lock.
##
## WHY. A tracking post is one line of one run's activity, rendered as one box (a `container` block) and queued as its own record, and Slack takes one message a
## second into a channel: at one box a message, a backlog of thousands never drains, and a post costs the pusher a call for one line. A message holds 50
## blocks, a box's children counted (AgentsEventTrackPostWeight, AgentsEventTrackPostPack), so consecutive boxes are packed into one message, as the older
## collector did before the comms outbox took the posts.
##
## WHAT IT JOINS. Only a record of method chat.postMessage whose payload is a tracking post of kind activity or feed (`"tracking":"activity"` or `"tracking":"feed"`
## in its metadata: the two kinds that carry a run's lines of work) with blocks and a thread, and only ones with the same session, member and kind that follow
## each other once the others are taken out. Every other record -- a message of a member, an ask, a notice, a handback -- is written first, in the order it came,
## and the tracking posts follow it: a person's message and an ask never wait behind a backlog of tracking lines, which a channel takes one message a second.
## The joined record is the first one's, with its text, its metadata and its reason; only the boxes are the run's. The first `sent` records are written as
## they are, so the position the pusher keeps still points at the same record. A line that is not six tab-separated columns is written as it is, first.
##
## One-true-awk 20200816 is this fleet's floor: every line break falls right after a binary operator and right before a real token.
##

BEGIN {
	FS = "\t" ; OFS = "\t" ;
	limit = 50 ;
	boxOpen = "\"blocks\":[" ;
	boxClose = "],\"thread_ts\":" ;
	groupCount = 0 ;
}

## The weight of the boxes of a payload: every block, a box's children counted.
function weightOf(text,    copy) {
	copy = text ;
	return gsub( /\{"type":"(container|section|context|divider|header|actions|image|rich_text)"/, "&", copy ) + 0 ;
}

## The group in hand, put in the tracking queue (written after every other record): alone as it came, or as one joined message.
function flush() {
	if ( groupCount == 0 ) return ;
	if ( groupCount == 1 ) queue[ queued++ ] = groupLine ;
	else queue[ queued++ ] = groupSession OFS groupBlock OFS groupMember OFS groupIdentity OFS groupMethod OFS ( groupWhy != "" ? "why=" groupWhy "\037" : "" ) groupHead groupBoxes groupTail ;
	groupCount = 0 ; groupBoxes = "" ; groupWeight = 0 ;
}

{
	if ( NR <= sent ) { print ; next ; }
	if ( NF != 6 || $5 != "chat.postMessage" ) { print ; next ; }
	payload = $6 ; why = "" ;
	if ( index( payload, "why=" ) == 1 && index( payload, "\037" ) > 0 ) {
		why = substr( payload, 5, index( payload, "\037" ) - 5 ) ;
		payload = substr( payload, index( payload, "\037" ) + 1 ) ;
	}
	boxAt = index( payload, boxOpen ) ;
	closeAt = index( payload, boxClose ) ;
	kind = "" ;
	if ( index( payload, "\"tracking\":\"activity\"" ) > 0 ) kind = "activity" ;
	else if ( index( payload, "\"tracking\":\"feed\"" ) > 0 ) kind = "feed" ;
	if ( kind == "" || boxAt == 0 || closeAt <= boxAt ) { print ; next ; }
	boxes = substr( payload, boxAt + length( boxOpen ), closeAt - boxAt - length( boxOpen ) ) ;
	weight = weightOf( boxes ) ;
	if ( groupCount > 0 && $1 == groupSession && $3 == groupMember && kind == groupKind && groupWeight + weight <= limit ) {
		groupBoxes = groupBoxes "," boxes ;
		groupWeight += weight ;
		groupCount++ ;
		next ;
	}
	flush() ;
	groupKind = kind ;
	groupLine = $0 ; groupSession = $1 ; groupBlock = $2 ; groupMember = $3 ; groupIdentity = $4 ; groupMethod = $5 ; groupWhy = why ;
	groupHead = substr( payload, 1, boxAt + length( boxOpen ) - 1 ) ;
	groupTail = substr( payload, closeAt ) ;
	groupBoxes = boxes ; groupWeight = weight ; groupCount = 1 ;
}

END {
	flush() ;
	for ( queueAt = 0 ; queueAt < queued ; queueAt++ ) print queue[ queueAt ] ;
}
