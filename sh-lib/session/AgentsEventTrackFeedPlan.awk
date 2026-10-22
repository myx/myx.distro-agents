#!/usr/bin/env awk
# Where the event-track feed's posts end (AgentsTools.EventTrackFeed.include). stdin: the
# lines of the open post, then the new ones, in the order they happened. ETF_ALL=1 ends the
# open post. Prints the post to send, as a mark line `\001POST` and its lines, then
# `\001OPEN` and the lines the open post keeps. Run with LC_ALL=C.
#
# Fixed here, never configured:
# - No line ends a post, an error, a refusal or a session event included: the open post goes
#   at its window's end (7 s, the poster's) or at the size limit (the post op's cut), so a
#   channel is not asked for a post at every error. With ETF_ALL=1 the open post is sent.
# - A unit is one line with its `> ` body lines. A TOOL line and the message events of the
#   same call next to it (MSG-OUT, HANDBACK, WAIT-RESULT, DISMISSED, ASK, ANSWER, SPAWN) are
#   one unit, so one call is never cut between two posts.
# - Every unit joins the open post, whoever it regards: the post's blocks say that.

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
	}
	if ( word != "" ) { unitHas[unitCount, word] = 1 ; }
	if ( toText != "" ) { unitTo[unitCount] = toText ; }
}

END {
	postText = "" ;
	for ( unitNo = 1 ; unitNo <= unitCount ; unitNo++ ) {
		postText = postText ( postText == "" ? "" : "\n" ) unitText[unitNo] ;
	}
	if ( postAll && postText != "" ) {
		printf "\001POST\n%s\n", postText ;
		postText = "" ;
	}
	printf "\001OPEN\n" ;
	if ( postText != "" ) { print postText ; }
}
