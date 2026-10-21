#!/usr/bin/env awk

# Takes the tooling's own posts out of a rendering (AgentsSlackMessagesFormat.awk: a head line `<ts> | <user> |<annotations> <text>` for each
# message, and the lines under it) before anything decides whether the rendering holds input. The tooling marks what it posts itself: every
# tracking post (the session root, the start, end, notice and activity posts of event-track, AgentsTools.InternOpEventTrackPost.include) carries
# `[tracking: <kind>]` and the spawn id of its session as `[session: <id>]`, out of the post's own metadata -- never a match on its words.
#
#   -v member the reading member
#   -v away   the spawn ids of the sessions the reading member launched and that do not report to it, spaced (AgentsToolsTrackingLaunchedAway)
#
# What is dropped, with the lines under it: a tracking post of any kind but `handback` and `tooling`; a post the tooling sent itself (`tooling`, the
# internal sends of the tooling: DISMISSED, notes, alerts, inquiries) that is not ADDRESSED TO the reading member -- one that is, `... → *_member_*.`, is
# for that run and always stays: DISMISSED and whatever is addressed to a run reach its Wait; and a `handback` of a session in -v away -- a run the member
# launched that reports to nobody, or to somebody else, has nothing to hand back to the member. A `handback` of any other session is a run reporting
# to the member, and stays: it is news. A message with no `[tracking:` annotation is a person's or a member's, and stays.
# Every closing brace is preceded by a `;`.

BEGIN {
	awayCount = split(away, awayId, " ") ;
	keep = 1 ;
}

# Whether the text of a head line is addressed to the member: its header's addressee line, `... → *_member_*.`
function addressedTo(text,   arrow, toPart, endPos) {
	gsub(/[\r\n\t]+/, " ", text) ;
	arrow = index(text, " \342\206\222 ") ;
	if ( arrow == 0 ) { return 0 ; }
	toPart = substr(text, arrow + 5) ;
	endPos = index(toPart, ". ") ;
	if ( endPos > 0 ) { toPart = substr(toPart, 1, endPos - 1) ; }
	return ( member != "" && index(toPart, "*_" member "_*") > 0 ) ;
}

function isAway(session,   at) {
	for ( at = 1 ; at <= awayCount ; at++ ) {
		if ( awayId[at] == session ) { return 1 ; }
	}
	return 0 ;
}

/^[0-9]+\.[0-9]+ \| / {
	rest = $0 ;
	sub(/^[^|]*\| [^|]*\|/, "", rest) ;
	kind = "" ; session = "" ;
	while ( match(rest, /^ \[[^]]*\]/) ) {
		ann = substr(rest, RSTART + 1, RLENGTH - 1) ;
		rest = substr(rest, RSTART + RLENGTH) ;
		if ( ann ~ /^\[tracking: / ) { kind = ann ; sub(/^\[tracking: /, "", kind) ; sub(/\]$/, "", kind) ; }
		if ( ann ~ /^\[session: / ) { session = ann ; sub(/^\[session: /, "", session) ; sub(/\]$/, "", session) ; }
	}
	keep = 1 ;
	if ( kind != "" ) {
		if ( kind == "tooling" ) { keep = addressedTo(rest) ; }
		else if ( kind != "handback" ) { keep = 0 ; }
		else if ( session != "" && isAway(session) ) { keep = 0 ; }
	}
}

keep { print ; }
