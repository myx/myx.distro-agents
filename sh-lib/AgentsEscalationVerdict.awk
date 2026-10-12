#!/usr/bin/env awk

# Reads one rendering of the answers to a typed question -- AgentsSlackThreadAnswers.awk's
# shape: "<ts> | <user> | <text>" per reply, and "reaction on the question: [reactions:
# NAME xN (USERS)]" -- and prints "<verdict>\t<author>\t<ts>", or "RETURNED\t\t".
# <ts> is the reply the verdict was read from, empty for a reaction.
#
# Only a reply's FIRST LINE, or a reaction the kind declares, gives an answer, and the line
# only in one of two shapes -- exactly what the post asks for. ALONE: the line is an
# answering word and nothing else, case, the spaces around it and the marks that close it
# aside ("allow-once", "Deny."), or it is an option's whole line as the post shows it. WITH
# HIS WORDS: the answering word, then a punctuation mark before anything else -- `. , ! ; :`
# or an ellipsis at once, or a dash after it -- then whatever he wrote ("allow-once, but only
# this file", "deny. The path is wrong", "yes: go on", "trash - ok"). Anything else is no
# answer: a word followed by a space and more words with no mark between ("allow-once
# please"), a word that is not at the start ("sure, allow-once", "do not deny"), and a line
# of two answers, where what follows the first names another answer in one of the two shapes
# ("allow-once, allow-session", "yes, no"). No negation parsing is attempted in place of any
# of it: the owner's rule is "complete first line, or separated by punctuation at least".
# Any other reply is RETURNED and goes back to the asker, with its text. The first answer
# that classifies wins. A readback "correct" prints "correct -- <his words on that line>".
# Only the reply's first line is read -- its first line that is no quote of the question, a
# ``` fenced block or a line starting with ">" or "&gt;" being skipped -- and the rest of it
# is a clarification, kept by the caller.
# A MEMBER'S REPLY starts with the send header the team's own send writes ahead of every
# message, `[<mark> ]*_<from>_*[ @<alias>] → <addressees>.`: it is no part of the reply, so the
# first line starts after it (sendHeaderLength). Read as the reply's first word, the
# header's mark made every answer a member gave by reply name none of the answers.
# A PLAIN AFFIRMATION -- ok, okay, yes, agree, agreed, confirm or confirmed as the answering
# word, also after a leading "I", in any case, or a +1, thumbsup, ok_hand or white_check_mark
# reaction on the question -- is yes for a readback, and for a decision the option whose
# line is marked "(recommended)"; with no option marked it answers nothing. Never for a
# permission: that kind takes only its own words.
# The author is the account that wrote the classified answer; for a reaction, the first
# of its users that is one of the accepted authors.
#
# BY NUMBER: the post numbers its options, so an option is also answered by its number as the
# reply's first word, or by a click on its number emoji (one to keycap_ten). A number keeps
# its own rule: it is the first word, a `#` before it and a mark after it aside, whatever
# follows it ("2 please"). An option's own first word wins over a number. An option is named
# by its first word, so that word is its answering word. Two numbers clicked by one account on a one-option form name
# none. A permission is also answered by click: x is deny, one is allow-once, repeat is
# allow-session, deny first and then the narrower grant when several are held. Where the
# request offers the folder of the refused file (MDAT_VERDICT_FOLDER), file_folder is
# allow-folder, wider and so after them, and the word allow-folder is an answer too;
# where it does not, neither the click nor the word answers anything. The same holds for the
# project that file lies in (MDAT_VERDICT_PROJECT): building_construction is allow-project,
# the widest and so the last, and the word allow-project is an answer too. So is a
# permission set: x is deny and unlock is allow-set, deny first; edit only by reply, since it
# carries the change in words.
# A PROPOSAL (ProposeApprove) is answered by the human-owner's own click on its root:
# white_check_mark is approved and x is rejected, rejected first when both are held. The
# reader is given the reactions of the root alone, never those under the proposal reply
# (AgentsSlackThreadAnswersSince.awk). By reply, approved or approve is approved, and rejected
# or reject is rejected, in either shape; his words on that line are carried, as "approved --
# <text>" or "rejected -- <text>". No plain affirmation approves: that kind takes only its own
# words and marks.
# A CHANGE held for approval (AgentsTools.InternOpChange.include) takes approve or reject, the
# human-owner's own: by reply in either shape, in any case, approved and rejected read the
# same, his words on that line carried for a caller that keeps them; or by click, +1 (or
# thumbsup) to approve and x to reject, reject first when both are held. His own
# white_check_mark approves too, as it does on a proposal. No plain affirmation approves.
# A REVIEW takes accept, return or reject: by reply in either shape, in any case, printed with
# his words on that line as "<word> -- <the rest of the line>"; or by click,
# +1 (or thumbsup) for accept, leftwards_arrow_with_hook for return, x for reject. Two of them
# held by one account name none. No plain affirmation in words is taken for one.
# A PLAIN QUESTION takes a verdict only by its answer form (MDAT_VERDICT_SELECT): yes-no reads
# as a readback does, without correct; one reads as a decision does, without the recommended
# option; many is every option named, in option order, space-separated -- by reply when every
# word of its first line is a number or an option's first word, and by click only once the
# account holds ok, the mark that sends, the options being every number it holds then. The
# send mark with no number is no answer. white_check_mark, the send mark before ok, is still
# taken as one, so a question posted with it can be answered as its own text says; it is no
# longer placed or named, being the mark the tooling puts on an answered question.
# A reaction by an asking account never counts (MDAT_VERDICT_ASKING): the tooling places the
# answer emoji under the question as the account that posted it.
# A CLICK IS READ ONLY WHERE THE RENDERING PUTS IT: ahead of the first reply. A line under a
# reply's head is that reply's text whatever it starts with, a line that reads as a reaction
# line too -- a reply's text never stands for a click, of its writer or of anyone it names.
# Such a line used to be taken out of the reply and counted with the clicks; it gave no
# verdict only because the clicks were already judged at the reply's head.
#
# ENVIRON["MDAT_VERDICT_KIND"]    question | readback | decision | permission | permission-set | review
#                                 | proposal | change
# ENVIRON["MDAT_VERDICT_SELECT"]  question only: yes-no | one | many.
# ENVIRON["MDAT_VERDICT_OPTIONS"] decision, one and many: the options, one per line; each
#                                 line's first word is the word that answers it, and the line
#                                 holding "(recommended)" names the recommended option.
# ENVIRON["MDAT_VERDICT_AUTHORS"] the accounts whose answer counts, space-separated.
# ENVIRON["MDAT_VERDICT_ASKING"]  the accounts that asked, space-separated; may be empty.
# ENVIRON["MDAT_VERDICT_WORDS"]   non-empty: the words on the verdict's line are carried too.
# ENVIRON["MDAT_VERDICT_FOLDER"]  permission only, non-empty: the request offers the folder of
#                                 the refused file, so allow-folder is one of its answers.
# ENVIRON["MDAT_VERDICT_PROJECT"] permission only, non-empty: the request offers the project
#                                 the refused file lies in, so allow-project is one of its answers.
#
# THE WORDS WITH A VERDICT. A reply that gives a verdict is not only a verdict: what the person
# wrote after the answering word, on that line, is for the asker to read -- a condition, a
# correction, a hint. Asked for them (MDAT_VERDICT_WORDS), the verdict of every kind is printed
# as "<verdict> -- <words>", the way a correction's, an edit's, a review's and a proposal's
# always are; a selection of several is its whole line and has none. The words never change
# the verdict. A caller that does not ask gets the verdict as before: this reader also runs
# for processes started before the words were carried, which match the verdict whole.

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

## The length of the send header a message starts with, its closing `. ` or line end included;
## 0 where it starts with none. The header is exactly what the member send writes ahead of the
## body (AgentsTools.MemberCommsSlack.include; AgentsSessionContextCommsItems.awk reads who it
## names): before the arrow nothing but an optional mark, the sender, and its alias where
## that is not the sender's own name, which the header says once. With no alias beside the
## name the mark is held to what a mark is, a `:shortcode:` or a sign that is no plain letter.
function sendHeaderLength( text,    arrowAt, fromPart, toPart, endAt ) {
	arrowAt = index( text, " → " ) ;
	if ( arrowAt == 0 ) { return 0 ; }
	fromPart = substr( text, 1, arrowAt - 1 ) ;
	if ( fromPart !~ /^([^ ]+ )?\*_[^*]+_\* @[^ ]+$/ && fromPart !~ /^((:[A-Za-z0-9_+-]+:|[^ -~]+) )?\*_[^*]+_\*$/ ) { return 0 ; }
	toPart = substr( text, arrowAt + length( " → " ) ) ;
	endAt = index( toPart, ". " ) ;
	if ( endAt > 0 ) { return arrowAt + length( " → " ) + endAt ; }
	return ( substr( toPart, length( toPart ), 1 ) == "." ) ? length( text ) : 0 ;
}

BEGIN {
	kind = ENVIRON["MDAT_VERDICT_KIND"] ;
	wordsWanted = ( ENVIRON["MDAT_VERDICT_WORDS"] != "" ) ;
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
	folderOffered = ( kind == "permission" && ENVIRON["MDAT_VERDICT_FOLDER"] != "" ) ;
	projectOffered = ( kind == "permission" && ENVIRON["MDAT_VERDICT_PROJECT"] != "" ) ;
	if ( projectOffered ) { optionSet["allow-project"] = 1 ; }
	if ( folderOffered ) { optionSet["allow-folder"] = 1 ; }
	else if ( kind == "permission-set" ) { optionSet["deny"] = 1 ; optionSet["allow-set"] = 1 ; optionSet["edit"] = 1 ; }
	else if ( kind == "proposal" ) { optionSet["approved"] = 1 ; optionSet["rejected"] = 1 ; }
	else if ( kind == "change" ) { optionSet["approve"] = 1 ; optionSet["reject"] = 1 ; }
	authorTotal = split( ENVIRON["MDAT_VERDICT_AUTHORS"], authorList, " " ) ;
	for ( authorIndex = 1 ; authorIndex <= authorTotal ; authorIndex++ ) { authorSet[authorList[authorIndex]] = 1 ; }
	askingTotal = split( ENVIRON["MDAT_VERDICT_ASKING"], askingList, " " ) ;
	for ( askingIndex = 1 ; askingIndex <= askingTotal ; askingIndex++ ) { askingSet[askingList[askingIndex]] = 1 ; }
	## A plain question takes a verdict only by its answer form.
	form = ( kind == "question" ) ? ENVIRON["MDAT_VERDICT_SELECT"] : "" ;
	## The options by number, as the post numbers them: an empty line is none.
	numberTotal = 0 ;
	for ( optionIndex = 1 ; optionIndex <= optionTotal ; optionIndex++ ) {
		if ( optionLines[optionIndex] == "" ) { continue ; }
		optionWord = optionLines[optionIndex] ;
		sub( /^- /, "", optionWord ) ;
		sub( /[ \t].*$/, "", optionWord ) ;
		sub( /:$/, "", optionWord ) ;
		numberWord[++numberTotal] = lowered( optionWord ) ;
		## The option's whole line, as the post shows it: a reply that is that line names it.
		optionWord = lowered( optionLines[optionIndex] ) ;
		sub( /^- /, "", optionWord ) ;
		sub( /^[ \t]+/, "", optionWord ) ;
		sub( /[ \t]+$/, "", optionWord ) ;
		numberLine[numberTotal] = optionWord ;
	}
	split( "one two three four five six seven eight nine keycap_ten", numberNames, " " ) ;
	## The marks of more than one byte that close a word or stand after it: an ellipsis, and
	## the two long dashes.
	longMarks[1] = "…" ; longMarks[2] = "–" ; longMarks[3] = "—" ;
	verdict = "" ;
	author = "" ;
}

## The option a number names, 1 to the last option; 0 for anything else. A number may carry
## a `#` before it and a mark after it.
function numberOf( word ) {
	sub( /^#/, "", word ) ;
	sub( /[.,!;:)]+$/, "", word ) ;
	if ( word !~ /^[0-9]+$/ || length( word ) > 4 ) { return 0 ; }
	return ( word + 0 >= 1 && word + 0 <= numberTotal && numberWord[word + 0] != "" ) ? word + 0 : 0 ;
}

## The first accepted account that holds one reaction on the question, or "".
function holderOf( name,    heldIndex ) {
	for ( heldIndex = 1 ; heldIndex <= heldTotal ; heldIndex++ ) {
		if ( ( heldOrder[heldIndex], name ) in held ) { return heldOrder[heldIndex] ; }
	}
	return "" ;
}

## The options one account holds by number click, as their words in option order; sets
## pickedCount. Only the ten numbers that have an emoji.
function pickedBy( who,    numberIndex, picked ) {
	picked = "" ; pickedCount = 0 ;
	for ( numberIndex = 1 ; numberIndex <= numberTotal && numberIndex <= 10 ; numberIndex++ ) {
		if ( ( ( who, numberNames[numberIndex] ) in held ) && numberWord[numberIndex] != "" ) {
			picked = picked ( pickedCount++ ? " " : "" ) numberWord[numberIndex] ;
		}
	}
	return picked ;
}

## The options a reply to a many question names: every word of its line a number or an
## option's first word, separated by spaces or commas. "" when any word is neither.
function manyOf( text,    words, wordTotal, wordIndex, oneWord, numberIndex, taken, picked, pickedAny ) {
	wordTotal = split( lowered( text ), words, /[ \t,]+/ ) ;
	for ( wordIndex = 1 ; wordIndex <= wordTotal ; wordIndex++ ) {
		oneWord = words[wordIndex] ;
		if ( oneWord == "" ) { continue ; }
		sub( /[.!;:]+$/, "", oneWord ) ;
		numberIndex = 0 ;
		if ( oneWord in optionSet ) {
			for ( numberIndex = 1 ; numberIndex <= numberTotal ; numberIndex++ ) { if ( numberWord[numberIndex] == oneWord ) { break ; } }
		}
		if ( numberIndex < 1 || numberIndex > numberTotal ) { numberIndex = numberOf( oneWord ) ; }
		if ( numberIndex == 0 ) { return "" ; }
		taken[numberIndex] = 1 ;
	}
	picked = "" ; pickedAny = 0 ;
	for ( numberIndex = 1 ; numberIndex <= numberTotal ; numberIndex++ ) {
		if ( numberIndex in taken ) { picked = picked ( pickedAny++ ? " " : "" ) numberWord[numberIndex] ; }
	}
	return picked ;
}

## The reactions on the question, judged once they are all read. Only an accepted account
## that is no asking account counts, so an emoji the tooling placed is never an answer.
function judgeReactions(    lineIndex, name, who, heldIndex, picked ) {
	if ( reactionsJudged ) { return ; }
	reactionsJudged = 1 ;
	if ( verdict != "" || reactionTotal == 0 ) { return ; }
	if ( kind == "permission" ) {
		## Deny first, then the narrower grant: two clicks never widen what one gives.
		if ( ( who = holderOf( "x" ) ) != "" ) { verdict = "deny" ; }
		else if ( ( who = holderOf( "one" ) ) != "" ) { verdict = "allow-once" ; }
		else if ( ( who = holderOf( "repeat" ) ) != "" ) { verdict = "allow-session" ; }
		else if ( folderOffered && ( who = holderOf( "file_folder" ) ) != "" ) { verdict = "allow-folder" ; }
		else if ( projectOffered && ( who = holderOf( "building_construction" ) ) != "" ) { verdict = "allow-project" ; }
		if ( verdict != "" ) { author = who ; }
		return ;
	}
	if ( kind == "permission-set" ) {
		## Deny first: two clicks never give what one of them withholds.
		if ( ( who = holderOf( "x" ) ) != "" ) { verdict = "deny" ; author = who ; }
		else if ( ( who = holderOf( "unlock" ) ) != "" ) { verdict = "allow-set" ; author = who ; }
		return ;
	}
	if ( kind == "proposal" ) {
		## Rejected first: two clicks never approve what one of them rejects.
		if ( ( who = holderOf( "x" ) ) != "" ) { verdict = "rejected" ; author = who ; }
		else if ( ( who = holderOf( "white_check_mark" ) ) != "" ) { verdict = "approved" ; author = who ; }
		return ;
	}
	if ( kind == "change" ) {
		## Reject first: two clicks never approve what one of them rejects.
		if ( ( who = holderOf( "x" ) ) != "" ) { verdict = "reject" ; author = who ; }
		else if ( ( who = holderOf( "+1" ) ) != "" || ( who = holderOf( "thumbsup" ) ) != "" || ( who = holderOf( "white_check_mark" ) ) != "" ) { verdict = "approve" ; author = who ; }
		return ;
	}
	if ( kind == "review" ) {
		## One verdict is the answer. Two held by one account name none.
		for ( heldIndex = 1 ; heldIndex <= heldTotal ; heldIndex++ ) {
			who = heldOrder[heldIndex] ; picked = "" ; pickedCount = 0 ;
			if ( ( ( who, "+1" ) in held ) || ( ( who, "thumbsup" ) in held ) ) { picked = "accept" ; pickedCount++ ; }
			if ( ( who, "leftwards_arrow_with_hook" ) in held ) { picked = "return" ; pickedCount++ ; }
			if ( ( who, "x" ) in held ) { picked = "reject" ; pickedCount++ ; }
			if ( pickedCount == 1 ) { verdict = picked ; author = who ; return ; }
		}
		return ;
	}
	if ( form == "many" ) {
		## Sent only by its send mark, and only with a number held beside it.
		for ( heldIndex = 1 ; heldIndex <= heldTotal ; heldIndex++ ) {
			who = heldOrder[heldIndex] ;
			if ( ! ( ( who, "ok" ) in held ) && ! ( ( who, "white_check_mark" ) in held ) ) { continue ; }
			picked = pickedBy( who ) ;
			if ( pickedCount > 0 ) { verdict = picked ; author = who ; return ; }
		}
		return ;
	}
	if ( kind == "decision" || form == "one" ) {
		## One number is the choice. Two held by one account name none.
		for ( heldIndex = 1 ; heldIndex <= heldTotal ; heldIndex++ ) {
			who = heldOrder[heldIndex] ;
			picked = pickedBy( who ) ;
			if ( pickedCount == 1 ) { verdict = picked ; author = who ; return ; }
		}
	}
	for ( lineIndex = 1 ; lineIndex <= reactionTotal ; lineIndex++ ) {
		name = reactionNames[lineIndex] ;
		if ( ( kind == "readback" || form == "yes-no" ) && ( name in affirmReactionSet ) ) { verdict = "yes" ; }
		else if ( ( kind == "readback" || form == "yes-no" ) && name == "x" ) { verdict = "no" ; }
		else if ( kind == "decision" && ( name in affirmReactionSet ) && recommendedWord != "" ) { verdict = recommendedWord ; }
		if ( verdict != "" ) { author = reactionFirst[lineIndex] ; return ; }
	}
}

verdict != "" { next ; }

! replySeen && index( $0, "reaction on the question: [reactions: " ) == 1 {
	reactionName = substr( $0, length( "reaction on the question: [reactions: " ) + 1 ) ;
	sub( / .*$/, "", reactionName ) ;
	reactionUsers = $0 ;
	sub( /^.*\(/, "", reactionUsers ) ;
	sub( /\)\]$/, "", reactionUsers ) ;
	reactionAuthor = "" ;
	sub( /::skin-tone-[0-9]+$/, "", reactionName ) ;
	reactionUserTotal = split( reactionUsers, reactionList, "," ) ;
	for ( reactionIndex = 1 ; reactionIndex <= reactionUserTotal ; reactionIndex++ ) {
		reactionUser = reactionList[reactionIndex] ;
		if ( ! ( reactionUser in authorSet ) || ( reactionUser in askingSet ) ) { continue ; }
		if ( reactionAuthor == "" ) { reactionAuthor = reactionUser ; }
		held[reactionUser, reactionName] = 1 ;
		if ( ! ( reactionUser in heldSeen ) ) { heldSeen[reactionUser] = 1 ; heldOrder[++heldTotal] = reactionUser ; }
	}
	if ( reactionAuthor == "" ) { next ; }
	## Kept until every reaction is read: several of them may be one answer.
	reactionNames[++reactionTotal] = reactionName ;
	reactionFirst[reactionTotal] = reactionAuthor ;
	next ;
}

## A reply is judged once all of its lines are read: its verdict line is the first one that
## is no quote of the question -- not blank, not in a ``` fenced block, not starting with ">"
## or "&gt;" (firstUnquoted). Only that line gives the answer.
/^[0123456789]+\.[0123456789]+ \| [^|]* \| / {
	judgeReactions() ;
	judgeMessage() ;
	replySeen = 1 ;
	messageTs = $1 ;
	messageAuthor = $0 ;
	sub( /^[^|]*\| /, "", messageAuthor ) ;
	sub( / \|.*$/, "", messageAuthor ) ;
	messageText = $0 ;
	sub( /^[^|]*\| [^|]*\| /, "", messageText ) ;
	## Leading mentions and annotation blocks are not the answer.
	while ( messageText ~ /^( |<@[^>]*>|\[[^]]*\])/ ) { sub( /^( |<@[^>]*>|\[[^]]*\])/, "", messageText ) ; }
	## Nor is a member's send header: where it is the whole line, the reply starts on the next.
	messageText = substr( messageText, sendHeaderLength( messageText ) + 1 ) ;
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

## The length of the mark a word ends with -- one of `. , ! ; :`, an ellipsis or a long
## dash -- or 0.
function closingMark( word,    markIndex, markLength ) {
	if ( word ~ /[.,!;:]$/ ) { return 1 ; }
	for ( markIndex = 1 ; markIndex <= 3 ; markIndex++ ) {
		markLength = length( longMarks[markIndex] ) ;
		if ( length( word ) >= markLength && substr( word, length( word ) - markLength + 1 ) == longMarks[markIndex] ) { return markLength ; }
	}
	return 0 ;
}

## The length of the dash a line's rest starts with, a word of its own -- `-`, `--` or a long
## dash -- or 0.
function dashAhead( rest ) {
	sub( /[ \t].*$/, "", rest ) ;
	return ( rest ~ /^-+$/ || rest == longMarks[2] || rest == longMarks[3] ) ? length( rest ) : 0 ;
}

## THE SHAPE OF AN ANSWERING LINE, by its first word: "alone" -- the word and nothing else,
## the marks that close it aside; "marked" -- the word, then a mark before anything else,
## at once or as a dash after it, then his words; "" -- the word, a space and more words with
## no mark between, which is no answer. Leaves the word in shapeWord, lowered and its marks
## off, and the words after the mark in shapeRest.
function lineShape( text,    word, rest, markLength, marked ) {
	sub( /^[ \t]+/, "", text ) ;
	sub( /[ \t]+$/, "", text ) ;
	word = text ;
	sub( /[ \t].*$/, "", word ) ;
	rest = substr( text, length( word ) + 1 ) ;
	sub( /^[ \t]+/, "", rest ) ;
	marked = 0 ;
	while ( ( markLength = closingMark( word ) ) > 0 ) { word = substr( word, 1, length( word ) - markLength ) ; marked = 1 ; }
	shapeWord = lowered( word ) ;
	shapeRest = rest ;
	if ( ! marked && rest != "" ) {
		markLength = dashAhead( rest ) ;
		if ( markLength == 0 ) { return "" ; }
		shapeRest = substr( rest, markLength + 1 ) ;
		sub( /^[ \t]+/, "", shapeRest ) ;
	}
	return ( shapeRest == "" ) ? "alone" : "marked" ;
}

## What one word answers for the kind asked, or "": the kind's own words and an option's
## first word, and -- taken with plain set -- a plain affirmation where the kind has one.
function answerOf( word, plain ) {
	if ( kind == "readback" || form == "yes-no" ) {
		if ( word == "yes" || word == "no" || ( word == "correct" && kind == "readback" ) ) { return word ; }
		return ( plain && ( word in affirmSet ) ) ? "yes" : "" ;
	}
	if ( kind == "permission" ) { return ( word == "deny" || word == "allow-once" || word == "allow-session" || word == "allow-task" || ( word == "allow-folder" && folderOffered ) || ( word == "allow-project" && projectOffered ) ) ? word : "" ; }
	if ( kind == "permission-set" ) { return ( word == "deny" || word == "allow-set" || word == "edit" ) ? word : "" ; }
	if ( kind == "proposal" ) { return ( word == "approved" || word == "approve" ) ? "approved" : ( ( word == "rejected" || word == "reject" ) ? "rejected" : "" ) ; }
	if ( kind == "change" ) { return ( word == "approve" || word == "approved" ) ? "approve" : ( ( word == "reject" || word == "rejected" ) ? "reject" : "" ) ; }
	if ( kind == "review" ) { return ( word == "accept" || word == "return" || word == "reject" ) ? word : "" ; }
	if ( kind == "decision" || form == "one" ) {
		if ( word in optionSet ) { return word ; }
		return ( plain && kind == "decision" && recommendedWord != "" && ( word in affirmSet ) ) ? recommendedWord : "" ;
	}
	return "" ;
}

## The option whose whole line a reply's first line is -- the option taken over as the post
## shows it, one closing mark aside -- or 0.
function optionLineOf( text,    numberIndex ) {
	text = lowered( text ) ;
	sub( /^[ \t]+/, "", text ) ;
	sub( /[ \t]+$/, "", text ) ;
	for ( numberIndex = 1 ; numberIndex <= numberTotal ; numberIndex++ ) {
		if ( numberLine[numberIndex] == "" ) { continue ; }
		if ( text == numberLine[numberIndex] ) { return numberIndex ; }
		if ( length( text ) == length( numberLine[numberIndex] ) + 1 && index( text, numberLine[numberIndex] ) == 1 && text ~ /[.,!;:]$/ ) { return numberIndex ; }
	}
	return 0 ;
}

function judgeMessage(    replyText, replyWord, replyRest, shape, answer, other, words ) {
	if ( messageCount == 0 ) { return ; }
	messageCount_ = messageCount ; messageCount = 0 ;
	if ( verdict != "" || firstUnquoted( messageLine, messageCount_ ) == 0 ) { return ; }
	replyText = firstText ;
	if ( form == "many" ) {
		## A selection of several keeps its own rule: its whole line is the answer.
		verdict = manyOf( replyText ) ;
	} else {
		shape = lineShape( replyText ) ;
		if ( shapeWord == "i" && shape == "" ) {
			## "I agree": a plain affirmation after a leading "I" is read as it is alone.
			shape = lineShape( shapeRest ) ;
			if ( ! ( shapeWord in affirmSet ) ) { shape = "" ; shapeWord = "" ; }
		}
		answer = ( shape != "" ) ? answerOf( shapeWord, 1 ) : "" ;
		words = shapeRest ;
		if ( answer != "" && words != "" ) {
			## Two answers on one line are none: what follows the first names another, by a
			## word of the kind or by a number, in one of the two shapes.
			shape = lineShape( words ) ;
			other = ( shape != "" ) ? answerOf( shapeWord, 0 ) : "" ;
			if ( other == "" && shape != "" && ( kind == "decision" || form == "one" ) && numberOf( shapeWord ) > 0 ) { other = numberWord[numberOf( shapeWord )] ; }
			if ( other != "" && other != answer ) { answer = "" ; }
		}
		if ( answer != "" ) {
			## His words on the verdict's line: always with a correction, an edit, a proposal's
			## and a review's verdict, and with any other for a caller that keeps them.
			gsub( /\t/, " ", words ) ;
			if ( ! wordsWanted && ! ( ( kind == "readback" && answer == "correct" ) || ( kind == "permission-set" && answer == "edit" ) || kind == "proposal" || kind == "review" ) ) { words = "" ; }
			verdict = answer ( words != "" ? " -- " words : "" ) ;
		} else if ( kind == "decision" || form == "one" ) {
			replyWord = replyText ;
			sub( /[ \t].*$/, "", replyWord ) ;
			replyRest = substr( replyText, length( replyWord ) + 1 ) ;
			replyWord = lowered( replyWord ) ;
			if ( optionLineOf( replyText ) > 0 ) { verdict = numberWord[optionLineOf( replyText )] ; }
			else if ( ! ( answerOf( replyWord, 1 ) != "" ) && numberOf( replyWord ) > 0 ) {
				## A number keeps its own rule: the first word, whatever follows it.
				verdict = numberWord[numberOf( replyWord )] ;
				sub( /^[ \t]+/, "", replyRest ) ;
				sub( /^[-:,.;!]+[ \t]*/, "", replyRest ) ;
				gsub( /\t/, " ", replyRest ) ;
				if ( wordsWanted && replyRest != "" ) { verdict = verdict " -- " replyRest ; }
			}
		}
	}
	if ( verdict != "" ) { author = messageAuthor ; verdictTs = messageTs ; }
}

END {
	judgeReactions() ;
	judgeMessage() ;
	printf "%s\t%s\t%s\n", ( verdict != "" ? verdict : "RETURNED" ), author, verdictTs ;
}
