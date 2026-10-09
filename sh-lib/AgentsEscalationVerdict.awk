#!/usr/bin/env awk

# Reads one rendering of the answers to a typed question -- AgentsSlackThreadAnswers.awk's
# shape: "<ts> | <user> | <text>" per reply, and "reaction on the question: [reactions:
# NAME xN (USERS)]" -- and prints "<verdict>\t<author>", or "UNCLASSIFIED\t".
#
# Only a reply's FIRST word, or a reaction the kind declares, gives an answer -- exactly
# what the post asks for ("reply with the first word"). An answer word anywhere else in a
# reply is never taken: "do not deny" would read as deny, and "don't allow-session" as a
# grant, and no negation parsing is attempted in its place. Any other reply is
# UNCLASSIFIED and goes back to the asker. The first answer that classifies wins. A
# readback "correct" prints "correct -- <the rest of the reply>".
# The author is the account that wrote the classified answer; for a reaction, the first
# of its users that is one of the accepted authors.
#
# ENVIRON["MDAT_VERDICT_KIND"]    readback | decision | permission | permission-set
# ENVIRON["MDAT_VERDICT_OPTIONS"] decision only: the options, one per line; each line's
#                                 first word is the word that answers it.
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

BEGIN {
	kind = ENVIRON["MDAT_VERDICT_KIND"] ;
	optionTotal = split( ENVIRON["MDAT_VERDICT_OPTIONS"], optionLines, "\n" ) ;
	for ( optionIndex = 1 ; optionIndex <= optionTotal ; optionIndex++ ) {
		optionWord = optionLines[optionIndex] ;
		sub( /^- /, "", optionWord ) ;
		sub( /[ \t].*$/, "", optionWord ) ;
		sub( /:$/, "", optionWord ) ;
		optionWord = lowered( optionWord ) ;
		if ( optionWord != "" ) { optionSet[optionWord] = 1 ; }
	}
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
	if ( kind == "readback" && reactionName == "white_check_mark" ) { verdict = "yes" ; }
	else if ( kind == "readback" && reactionName == "x" ) { verdict = "no" ; }
	else if ( ( kind == "permission" || kind == "permission-set" ) && reactionName == "x" ) { verdict = "deny" ; }
	if ( verdict != "" ) { author = reactionAuthor ; }
	next ;
}

/^[0123456789]+\.[0123456789]+ \| [^|]* \| / {
	replyAuthor = $0 ;
	sub( /^[^|]*\| /, "", replyAuthor ) ;
	sub( / \|.*$/, "", replyAuthor ) ;
	replyText = $0 ;
	sub( /^[^|]*\| [^|]*\| /, "", replyText ) ;
	## Leading mentions and annotation blocks are not the answer.
	while ( replyText ~ /^( |<@[^>]*>|\[[^]]*\])/ ) { sub( /^( |<@[^>]*>|\[[^]]*\])/, "", replyText ) ; }
	replyWord = replyText ;
	sub( /[ \t].*$/, "", replyWord ) ;
	replyRest = substr( replyText, length( replyWord ) + 1 ) ;
	sub( /^[ \t]+/, "", replyRest ) ;
	replyWord = lowered( replyWord ) ;
	sub( /[.,!;]$/, "", replyWord ) ;
	if ( kind == "readback" ) {
		if ( replyWord == "yes" || replyWord == "no" ) { verdict = replyWord ; }
		else if ( replyWord == "correct" || replyWord == "correct:" ) { verdict = "correct" ( replyRest != "" ? " -- " replyRest : "" ) ; }
	} else if ( kind == "permission" ) {
		if ( replyWord == "deny" || replyWord == "allow-once" || replyWord == "allow-session" || replyWord == "allow-task" ) { verdict = replyWord ; }
	} else if ( kind == "permission-set" ) {
		## edit carries the change, as a readback correct does.
		if ( replyWord == "deny" || replyWord == "allow-set" ) { verdict = replyWord ; }
		else if ( replyWord == "edit" || replyWord == "edit:" ) { verdict = "edit" ( replyRest != "" ? " -- " replyRest : "" ) ; }
	} else if ( kind == "decision" ) {
		if ( replyWord in optionSet ) { verdict = replyWord ; }
	}
	if ( verdict != "" ) { author = replyAuthor ; }
	next ;
}

END {
	printf "%s\t%s\n", ( verdict != "" ? verdict : "UNCLASSIFIED" ), author ;
}
