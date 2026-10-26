#!/usr/bin/env awk
# Where the event-track feed's posts end (AgentsTools.EventTrackFeed.include). stdin: the
# lines of the open post, then the new ones, in the order they happened. ETF_ALL=1 ends the
# open post too. Prints each post to send, in order, as a mark line `\001POST` and its lines,
# then `\001OPEN` and the lines the open post keeps. Run with LC_ALL=C.
#
# Fixed here, never configured:
# - A unit is one line with its `> ` body lines. A TOOL line and the message events of the
#   same call next to it (MSG-OUT, HANDBACK, WAIT-RESULT, DISMISSED, ASK, ANSWER, SPAWN) are
#   one unit, so one call is never cut between two posts.
# - NO kind of line ends a post: errors, refusals and session events included. Every unit
#   joins the open post, whoever it regards and whatever it says: the post's blocks say that.
#   Only the run's own window ends it -- 7 seconds after the open post's first line, fixed in
#   code in AgentsEventTrackFeedRun -- or ETF_ALL=1, the post the run makes as it ends.

BEGIN {
	postAll = ( ENVIRON["ETF_ALL"] == "1" ) ;
	companionTool["MSG-OUT"] = "SendMessage" ;
	companionTool["HANDBACK"] = "SubagentHandback" ;
	companionTool["WAIT-RESULT"] = "Wait" ;
	companionTool["DISMISSED"] = "Wait" ;
	companionTool["ASK"] = "AskQuestion" ;
	companionTool["ANSWER"] = "AskQuestion" ;
	companionTool["SPAWN"] = "Agent" ;
	unitCount = 0 ;
}

## The tool a name means, without an MCP server prefix. The tools that ask, and their second
## name AskUserQuestion, are one tool to a unit, so an ASK or an ANSWER joins the call of any.
function baseTool( toolName,    restName, cutAt ) {
	if ( substr( toolName, 1, 5 ) == "mcp__" ) {
		restName = substr( toolName, 6 ) ;
		cutAt = index( restName, "__" ) ;
		if ( cutAt > 0 ) { toolName = substr( restName, cutAt + 2 ) ; }
	}
	if ( toolName == "AskUserQuestion" || toolName == "ConfirmReadback" || toolName == "EscalateDecision" || toolName == "RequestPermission" || toolName == "ProposeApprove" ) { return "AskQuestion" ; }
	return toolName ;
}

{
	if ( substr( $0, 1, 1 ) == ">" && unitCount > 0 ) { unitText[unitCount] = unitText[unitCount] "\n" $0 ; next ; }
	if ( $0 == "" ) { next ; }
	word = "" ; tool = "" ; toText = "" ;
	if ( $0 ~ /^[0123456789][0123456789][0123456789][0123456789]-[0123456789][0123456789]-[0123456789][0123456789]T[0123456789][0123456789]:[0123456789][0123456789]:[0123456789][0123456789]Z [ABCDEFGHIJKLMNOPQRSTUVWXYZ]/ ) {
		split( $0, words, " " ) ;
		word = words[2] ;
		if ( word == "TOOL" ) { tool = baseTool( words[3] ) ; }
		else if ( word in companionTool ) { tool = ( word == "MSG-OUT" && match( $0, / tool=[A-Za-z]+/ ) ) ? substr( $0, RSTART + 6, RLENGTH - 6 ) : companionTool[word] ; }
		if ( match( $0, / to=[^ ]+/ ) ) { toText = substr( $0, RSTART + 4, RLENGTH - 4 ) ; }
	}
	## A line of the same call as the unit before it joins it: its tool, a kind it lacks, the same to.
	if ( tool != "" && unitCount > 0 && unitTool[unitCount] == tool && ! ( ( unitCount, word ) in unitHas ) && ( toText == "" || unitTo[unitCount] == "" || toText == unitTo[unitCount] ) ) {
		unitText[unitCount] = unitText[unitCount] "\n" $0 ;
	} else {
		unitCount++ ;
		unitText[unitCount] = $0 ;
		unitTool[unitCount] = tool ;
		unitTo[unitCount] = "" ;
		unitNow[unitCount] = 0 ;
	}
	if ( word != "" ) { unitHas[unitCount, word] = 1 ; }
	if ( toText != "" ) { unitTo[unitCount] = toText ; }
}

END {
	postText = "" ;
	for ( unitNo = 1 ; unitNo <= unitCount ; unitNo++ ) {
		postText = postText ( postText == "" ? "" : "\n" ) unitText[unitNo] ;
	}
	## ETF_ALL=1: the run is ending, so what is open goes now, and the OPEN mark after it
	## leaves the caller holding nothing. Otherwise the one OPEN mark and the lines after it
	## ARE the open post, and nothing follows them.
	if ( postAll ) {
		if ( postText != "" ) { printf "\001POST\n%s\n", postText ; }
		printf "\001OPEN\n" ;
	} else {
		printf "\001OPEN\n" ;
		if ( postText != "" ) { print postText ; }
	}
}
