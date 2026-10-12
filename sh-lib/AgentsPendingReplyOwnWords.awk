#!/usr/bin/env awk
# Reads one rendering of the answers to a question -- AgentsSlackThreadAnswers.awk's shape:
# "<ts> | <user> | <text>" heads, each followed by the rest of that message's lines -- and
# prints it with the send header taken off every reply that starts with one, so what is left
# of a reply is its writer's own words. Every other line is printed as it is.
# A MEMBER'S REPLY starts with the send header the team's own send writes ahead of every
# message, `[<mark> ]*_<from>_*[ @<alias>] → <addressees>.`: it is no part of what the reply
# says. This runs ahead of the two readers that keep what a reply says and read it by its
# first line -- AgentsPendingReplyAnswerText.awk, the recorded answer, and
# AgentsPendingReplyClarifications.awk, what is kept with it. With the header left on, one
# filling the head line was recorded as the answer and the answer under it as a
# clarification, and one on the answer's own line was recorded with the answer.
# The rendering itself keeps the header -- a Wait shows by it who wrote to whom, and a
# dismissal is read from it -- so it is taken off here, on the way to those readers only.
# Needs AgentsDismissalMatch.awk loaded first, for memberSendHeaderLength, the one header
# rule: `awk -f AgentsDismissalMatch.awk -f <this>`.

/^[0-9]+\.[0-9]+ \| / {
	headText = $0 ; sub( /^[^|]*\| [^|]*\|/, "", headText ) ;
	while ( match( headText, /^ \[[^]]*\]/ ) ) { headText = substr( headText, RSTART + RLENGTH ) ; }
	sub( /^ +/, "", headText ) ;
	headerLength = memberSendHeaderLength( headText ) ;
	if ( headerLength > 0 ) { print substr( $0, 1, length( $0 ) - length( headText ) ) substr( headText, headerLength + 1 ) ; next ; }
}
{ print ; }
