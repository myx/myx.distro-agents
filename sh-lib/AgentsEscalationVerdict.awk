#!/usr/bin/env awk

# Reads one rendering of the answers to a typed question -- AgentsSlackThreadAnswers.awk's
# shape: "<ts> | <user> | <text>" per reply, and "reaction on the question: [reactions:
# NAME xN (USERS)]" -- and prints "<verdict>\t<author>\t<ts>", or "UNCLASSIFIED\t\t".
# <ts> is the reply the verdict was read from, empty for a reaction.
#
# Only a reply's FIRST word, or a reaction the kind declares, gives an answer -- exactly
# what the post asks for ("reply with the first word"). An answer word anywhere else in a
# reply is never taken: "do not deny" would read as deny, and "don't allow-session" as a
# grant, and no negation parsing is attempted in its place. Any other reply is
# UNCLASSIFIED and goes back to the asker. The first answer that classifies wins. A
# readback "correct" prints "correct -- <the rest of the reply>". Only the reply's first
# line is read -- its first line that is no quote of the question, a ``` fenced block or a
# line starting with ">" or "&gt;" being skipped -- and the rest of it is a clarification,
# kept by the caller.
# A PLAIN AFFIRMATION -- a first word ok, okay, yes, agree, agreed, confirm or confirmed,
# also after a leading "I", in any case, or a +1, thumbsup, ok_hand or white_check_mark
# reaction on the question -- is yes for a readback, and for a decision the option whose
# line is marked "(recommended)"; with no option marked it answers nothing. Never for a
# permission: that kind takes only its own words.
# The author is the account that wrote the classified answer; for a reaction, the first
# of its users that is one of the accepted authors.
#
# ENVIRON["MDAT_VERDICT_KIND"]    readback | decision | permission | permission-set
# ENVIRON["MDAT_VERDICT_OPTIONS"] decision only: the options, one per line; each line's
#                                 first word is the word that answers it, and the line
#                                 holding "(recommended)" names the recommended option.
# ENVIRON["MDAT_VERDICT_AUTHORS"] the accounts whose answer counts, space-separated.

function lowered( text,    upperSet, lowerSet, outText, charIndex, oneChar, charAt ) {
	upperSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ;
	lowerSet = "abcdefghijklmnopqrstuvwxyz" ;
	outText = "" ;
	for ( charIndex = 1 ; charIndex <= length( text ) ; charIndex++ ) {
		oneChar = substr( text, charIndex, 1 ) ;
		charAt = index( upperSet, oneChar ) ;
		outText = outText ( charAt > 0 ? substr( lowerSet, charAt, 1 ) : oneChar ) ;
	}
	return outText ;
}

## Whether a reply's first line is a plain affirmation (the words of the header).
function affirmed( text,    words, wordTotal, oneWord ) {
	wordTotal = split( lowered( text ), words, /[ \t]+/ ) ;
	oneWord = words[1] ;
	if ( oneWord == "i" && wordTotal > 1 ) { oneWord = words[2] ; }
	sub( /[.,!;:]+$/, "", oneWord ) ;
	return ( oneWord in affirmSet ) ;
}

BEGIN {
	kind = ENVIRON["MDAT_VERDICT_KIND"] ;
	recommendedWord = "" ;
	optionTotal = split( ENVIRON["MDAT_VERDICT_OPTIONS"], optionLines, "\n" ) ;
	for ( optionIndex = 1 ; optionIndex <= optionTotal ; optionIndex++ ) {
		optionWord = optionLines[optionIndex] ;
		sub( /^- /, "", optionWord ) ;
		sub( /[ \t].*$/, "", optionWord ) ;
		sub( /:$/, "", optionWord ) ;
		optionWord = lowered( optionWord ) ;
		if ( optionWord != "" ) { optionSet[optionWord] = 1 ; }
		if ( optionWord != "" && recommendedWord == "" && index( lowered( optionLines[optionIndex] ), "(recommended)" ) ) { recommendedWord = optionWord ; }
	}
	split( "ok okay yes agree agreed confirm confirmed", affirmWords, " " ) ;
	for ( affirmIndex in affirmWords ) { affirmSet[affirmWords[affirmIndex]] = 1 ; }
	split( "+1 thumbsup ok_hand white_check_mark", affirmReactions, " " ) ;
	for ( affirmIndex in affirmReactions ) { affirmReactionSet[affirmReactions[affirmIndex]] = 1 ; }
	verdictTs = "" ;
	if ( kind == "readback" ) { optionSet["yes"] = 1 ; optionSet["no"] = 1 ; optionSet["correct"] = 1 ; }
	else if ( kind == "permission" ) { optionSet["deny"] = 1 ; optionSet["allow-once"] = 1 ; optionSet["allow-session"] = 1 ; optionSet["allow-task"] = 1 ; }
	else if ( kind == "permission-set" ) { optionSet["deny"] = 1 ; optionSet["allow-set"] = 1 ; optionSet["edit"] = 1 ; }
	authorTotal = split( ENVIRON["MDAT_VERDICT_AUTHORS"], authorList, " " ) ;
	for ( authorIndex = 1 ; authorIndex <= authorTotal ; authorIndex++ ) { authorSet[authorList[authorIndex]] = 1 ; }
	verdict = "" ;
	author = "" ;
}

verdict != "" { next ; }

index( $0, "reaction on the question: [reactions: " ) == 1 {
	judgeMessage() ;
	if ( verdict != "" ) { next ; }
	reactionName = substr( $0, length( "reaction on the question: [reactions: " ) + 1 ) ;
	sub( / .*$/, "", reactionName ) ;
	reactionUsers = $0 ;
	sub( /^.*\(/, "", reactionUsers ) ;
	sub( /\)\]$/, "", reactionUsers ) ;
	reactionAuthor = "" ;
	reactionTotal = split( reactionUsers, reactionList, "," ) ;
	for ( reactionIndex = 1 ; reactionIndex <= reactionTotal ; reactionIndex++ ) {
		if ( reactionList[reactionIndex] in authorSet ) {
			reactionAuthor = reactionList[reactionIndex] ;
			break ;
		}
	}
	if ( reactionAuthor == "" ) { next ; }
	sub( /::skin-tone-[0-9]+$/, "", reactionName ) ;
	if ( kind == "readback" && ( reactionName in affirmReactionSet ) ) { verdict = "yes" ; }
	else if ( kind == "readback" && reactionName == "x" ) { verdict = "no" ; }
	else if ( kind == "decision" && ( reactionName in affirmReactionSet ) && recommendedWord != "" ) { verdict = recommendedWord ; }
	else if ( ( kind == "permission" || kind == "permission-set" ) && reactionName == "x" ) { verdict = "deny" ; }
	if ( verdict != "" ) { author = reactionAuthor ; }
	next ;
}

## A reply is judged once all of its lines are read: its verdict line is the first one that
## is no quote of the question -- not blank, not in a ``` fenced block, not starting with ">"
## or "&gt;" (firstUnquoted). Only that line gives the answer.
/^[0123456789]+\.[0123456789]+ \| [^|]* \| / {
	judgeMessage() ;
	messageTs = $1 ;
	messageAuthor = $0 ;
	sub( /^[^|]*\| /, "", messageAuthor ) ;
	sub( / \|.*$/, "", messageAuthor ) ;
	messageText = $0 ;
	sub( /^[^|]*\| [^|]*\| /, "", messageText ) ;
	## Leading mentions and annotation blocks are not the answer.
	while ( messageText ~ /^( |<@[^>]*>|\[[^]]*\])/ ) { sub( /^( |<@[^>]*>|\[[^]]*\])/, "", messageText ) ; }
	messageCount = 1 ;
	messageLine[1] = messageText ;
	next ;
}

## Any other line belongs to the reply above it.
messageCount > 0 { messageLine[++messageCount] = $0 ; next ; }

## The first line of line[1..n] that is no quote heading the reply: blank lines, lines
## starting with ">" or "&gt;", and a ``` fenced block are skipped. Returns its index (0
## when every line is a quote) and leaves its text in firstText -- what follows a fence
## closed on the same line, when one is.
function firstUnquoted( line, n,    i, text, inFence, rest, closeAt ) {
	inFence = 0 ; firstText = "" ;
	for ( i = 1 ; i <= n ; i++ ) {
		text = line[i] ;
		if ( inFence ) {
			closeAt = index( text, "```" ) ;
			if ( closeAt == 0 ) { continue ; }
			inFence = 0 ;
			text = substr( text, closeAt + 3 ) ;
		} else {
			sub( /^[ \t]+/, "", text ) ;
			if ( substr( text, 1, 3 ) == "```" ) {
				rest = substr( text, 4 ) ;
				closeAt = index( rest, "```" ) ;
				if ( closeAt == 0 ) { inFence = 1 ; continue ; }
				text = substr( rest, closeAt + 3 ) ;
			}
		}
		sub( /^[ \t]+/, "", text ) ;
		if ( text == "" || text ~ /^(>|&gt;)/ ) { continue ; }
		firstText = text ;
		return i ;
	}
	return 0 ;
}

function judgeMessage(    replyText, replyWord, replyRest ) {
	if ( messageCount == 0 ) { return ; }
	messageCount_ = messageCount ; messageCount = 0 ;
	if ( verdict != "" || firstUnquoted( messageLine, messageCount_ ) == 0 ) { return ; }
	replyText = firstText ;
	replyWord = replyText ;
	sub( /[ \t].*$/, "", replyWord ) ;
	replyRest = substr( replyText, length( replyWord ) + 1 ) ;
	sub( /^[ \t]+/, "", replyRest ) ;
	replyWord = lowered( replyWord ) ;
	sub( /[.,!;]$/, "", replyWord ) ;
	if ( kind == "readback" ) {
		if ( replyWord == "yes" || replyWord == "no" ) { verdict = replyWord ; }
		else if ( replyWord == "correct" || replyWord == "correct:" ) { verdict = "correct" ( replyRest != "" ? " -- " replyRest : "" ) ; }
		else if ( affirmed( replyText ) ) { verdict = "yes" ; }
	} else if ( kind == "permission" ) {
		if ( replyWord == "deny" || replyWord == "allow-once" || replyWord == "allow-session" || replyWord == "allow-task" ) { verdict = replyWord ; }
	} else if ( kind == "permission-set" ) {
		## edit carries the change, as a readback correct does.
		if ( replyWord == "deny" || replyWord == "allow-set" ) { verdict = replyWord ; }
		else if ( replyWord == "edit" || replyWord == "edit:" ) { verdict = "edit" ( replyRest != "" ? " -- " replyRest : "" ) ; }
	} else if ( kind == "decision" ) {
		if ( replyWord in optionSet ) { verdict = replyWord ; }
		else if ( recommendedWord != "" && affirmed( replyText ) ) { verdict = recommendedWord ; }
	}
	if ( verdict != "" ) { author = messageAuthor ; verdictTs = messageTs ; }
}

END {
	judgeMessage() ;
	printf "%s\t%s\t%s\n", ( verdict != "" ? verdict : "UNCLASSIFIED" ), author, verdictTs ;
}
