## AgentsOutputStyleCheck.awk -- the team's plain-language output floor, measured.
## Reads one document on stdin. Silent and exit 0 when clean; one fault line per
## violation and exit 1 otherwise; exit 2 when textGroup names no group.
## textGroup: message (the default, and the strictest), report, brief, relay, help.
## The fence, code-span and quote exclusions restate AgentsSlackBlocksBuild.awk's
## own rule: awk loads no fragment from another program, and that file is not
## edited for this. `textGroup=help` prints what this does and does not measure.

## A fragment under three words is not a point, so it never feeds the element
## caps. It is still measured against the word cap, which it can never exceed.
function flushElement( elementText, isListed,    sentenceList, sentenceTotal, sentenceIndex, oneSentence, wordList, wordCount, shownText, elementWords, elementSentences, restText, markText, closerRun, spanText ) {
	## Scanned, not split: the same closing mark ends a sentence in one place and not in another.
	sentenceTotal = 0 ;
	spanText = "" ;
	restText = elementText ;
	while ( match( restText, /[.!?]+[")*]*([[:space:]]+|$)/ ) ) {
		markText = substr( restText, RSTART, RLENGTH ) ;
		spanText = spanText substr( restText, 1, RSTART - 1 ) ;
		restText = substr( restText, RSTART + RLENGTH ) ;
		closerRun = markText ;
		sub( /^[.!?]+/, "", closerRun ) ;
		sub( /[[:space:]]+$/, "", closerRun ) ;
		## A bold run closes whatever it wraps, so it is read off before the rest is judged.
		sub( /[*][*]+$/, "", closerRun ) ;
		## A quote ends a sentence unless those dots are an ellipsis. A parenthesis needs the span to have opened it.
		if ( closerRun == "" || ( closerRun == "\"" && markText !~ /[.][.]/ ) || ( closerRun == ")" && spanText ~ /^[[:space:]]*["*_]*[(]/ ) ) {
			sentenceList[++sentenceTotal] = spanText ;
			spanText = "" ;
		} else {
			spanText = spanText markText ;
		}
	}
	spanText = spanText restText ;
	if ( spanText != "" ) { sentenceList[++sentenceTotal] = spanText ; }
	elementWords = 0 ;
	elementSentences = 0 ;
	for ( sentenceIndex = 1 ; sentenceIndex <= sentenceTotal ; sentenceIndex++ ) {
		oneSentence = sentenceList[sentenceIndex] ;
		gsub( /^[[:space:]]+|[[:space:]]+$/, "", oneSentence ) ;
		if ( oneSentence == "" ) { continue ; }
		wordCount = split( oneSentence, wordList, /[[:space:]]+/ ) ;
		shownText = ( length( oneSentence ) > 120 ) ? substr( oneSentence, 1, 117 ) "..." : oneSentence ;
		if ( wordCount > wordCap ) {
			printf "word-cap\t%d words against a cap of %d: %s\n", wordCount, wordCap, shownText ;
			faultTotal++ ;
		}
		if ( oneSentence ~ /;/ ) {
			printf "semicolon\ta semicolon, which this floor does not allow: %s\n", shownText ;
			faultTotal++ ;
		}
		elementWords += wordCount ;
		if ( wordCount >= 3 ) { elementSentences++ ; }
	}
	if ( ! elementCaps || isListed ) { return ; }
	shownText = ( length( elementText ) > 120 ) ? substr( elementText, 1, 117 ) "..." : elementText ;
	gsub( /^[[:space:]]+/, "", shownText ) ;
	## Per paragraph, which is the unit the standard names. A chat message is one
	## paragraph, so the message case is unchanged, and a document of many sound
	## paragraphs no longer counts as one oversized one.
	if ( elementSentences > sentenceGate ) {
		printf "sentence-cap\t%d sentences in one paragraph, against a cap of %d: %s\n", elementSentences, sentenceGate, shownText ;
		faultTotal++ ;
	}
	## The backstop for the three-word floor above. A fragment under three words
	## adds its words here and nothing to the sentence count, so a long paragraph
	## of short fragments passes every other predicate. Measured: 80 two-word
	## fragments, 160 words, and this is the only thing that fires.
	if ( elementWords > paragraphGate ) {
		printf "paragraph-gate\t%d words in one paragraph with no list, against a gate of %d: %s\n", elementWords, paragraphGate, shownText ;
		faultTotal++ ;
	}
}

## One line of the document, after any frontmatter has been settled. Called from
## the main rule, and again from END for lines held back by a frontmatter block
## that turned out never to close.
function scanLine( rawLine,    lineText ) {
	## A three-backtick line toggles the fence, and everything inside it is code.
	if ( substr( rawLine, 1, 3 ) == "```" ) { inFence = ! inFence ; return ; }
	if ( inFence ) { return ; }
	## A quoted span carries text the writer did not write, so its length is the
	## source's fact rather than the writer's choice.
	if ( rawLine ~ /^[[:space:]]*>/ ) { return ; }
	lineText = rawLine ;
	gsub( /`[^`]*`/, " ", lineText ) ;
	if ( lineText ~ /^[[:space:]]*$/ ) {
		flushElement( paraText, 0 ) ;
		paraText = "" ;
		return ;
	}
	if ( lineText ~ /^[[:space:]]*([-*]|[0-9]+[.)])[[:space:]]/ ) {
		flushElement( paraText, 0 ) ;
		paraText = "" ;
		flushElement( lineText, 1 ) ;
		return ;
	}
	paraText = paraText " " lineText ;
}

BEGIN {
	if ( textGroup == "" ) { textGroup = "message" ; }
	## One cap, because no mechanical test tells an instructing sentence from a
	## describing one. 25 is the cap that cannot fire on a correct sentence.
	wordCap = 25 ;
	sentenceGate = 6 ;
	## Derived, never chosen: the sentence gate times the word cap.
	paragraphGate = sentenceGate * wordCap ;
	elementCaps = 1 ;
	measureText = 1 ;
	if ( textGroup == "report" || textGroup == "brief" ) {
		elementCaps = 0 ;
	} else if ( textGroup == "relay" ) {
		measureText = 0 ;
	} else if ( textGroup == "help" ) {
		measureText = 0 ;
		printf "AgentsOutputStyleCheck -- the team's plain-language output floor.\n" ;
		printf "\n" ;
		printf "Usage: LC_ALL=C awk -v textGroup=<group> -f AgentsOutputStyleCheck.awk\n" ;
		printf "Groups: message (default, strictest), report, brief, relay, help.\n" ;
		printf "Exit: 0 clean, 1 faults found, 2 no such group.\n" ;
		printf "\n" ;
		printf "MEASURED, every group but relay:\n" ;
		printf "  a sentence over %d words\n", wordCap ;
		printf "  a semicolon\n" ;
		printf "MEASURED, message group only:\n" ;
		printf "  more than %d sentences in ONE PARAGRAPH, outside a list\n", sentenceGate ;
		printf "  a paragraph over %d words carrying no list. A sentence under\n", paragraphGate ;
		printf "    three words does not count toward the sentence gate, so this\n" ;
		printf "    is what catches a long paragraph of short fragments.\n" ;
		printf "NOT MEASURED, and these stay with the writer and magic-librarian:\n" ;
		printf "  the 20-word cap on an instructing sentence -- no mechanical test\n" ;
		printf "    tells an instructing sentence from a describing one\n" ;
		printf "  the noun-cluster limit -- it fires on correct text without a\n" ;
		printf "    part-of-speech tagger, and a code identifier is a noun cluster\n" ;
		printf "  the distinct-points conversion test -- a count throws away the\n" ;
		printf "    word 'distinct', and no shell recovers it\n" ;
		printf "NOT PROSE, and skipped: a leading frontmatter block that actually\n" ;
		printf "  closes, a fenced code block, an inline code span, a quoted line.\n" ;
		printf "KNOWN AND NOT FIXED -- sentence-cap cannot tell a prose paragraph\n" ;
		printf "  from a block written one fact per line. Consecutive non-blank\n" ;
		printf "  lines are joined into one paragraph, so a compact status post\n" ;
		printf "  counts as a paragraph of that many sentences. Measured on one\n" ;
		printf "  81-word text in three formattings: consecutive lines fired at 7,\n" ;
		printf "  the same words with blank lines between them fired nothing, and\n" ;
		printf "  the same words as '- ' bullets fired nothing. Only the line\n" ;
		printf "  formatting changed. This is why sentence-cap refuses nowhere and\n" ;
		printf "  reports everywhere. Fixing it is a predicate redesign.\n" ;
		printf "KNOWN AND NOT FIXED -- a long sentence quoted from somewhere else is\n" ;
		printf "  measured as the writer's own unless it is marked as a quote. The\n" ;
		printf "  carried-text exclusion reads the markup, so an unmarked quotation\n" ;
		printf "  of an over-long sentence is refused where word-cap gates. Mark it\n" ;
		printf "  as a quote and it is skipped.\n" ;
		printf "KNOWN AND NOT FIXED -- a refused send cannot be told from a send\n" ;
		printf "  that did nothing. The gate refuses on word-cap with no warning\n" ;
		printf "  and no name for the sentence it refused. A caller not reading\n" ;
		printf "  the exit path closely takes a refusal for a delivery. Fixing it\n" ;
		printf "  is a change in the gate, not in this program.\n" ;
		printf "KNOWN AND NOT FIXED -- a parenthetical that is a whole sentence is\n" ;
		printf "  not a boundary when it opens a '- ' or '* ' list item. After a\n" ;
		printf "  '1.' marker it is, but only because that marker's own full stop\n" ;
		printf "  restarts the span. No canon line is over cap through this.\n" ;
		printf "KNOWN AND NOT FIXED -- a quotation inside a sentence is taken as a\n" ;
		printf "  boundary unless it carries an ellipsis, so a mid-sentence quote\n" ;
		printf "  ending in '.' or '?' splits the sentence. Five canon sites, one\n" ;
		printf "  row. A capital-follows rule was measured and refuted.\n" ;
		printf "ACCEPTANCE CASES for sentence boundaries live with magic-tester, so\n" ;
		printf "  a change to this splitting starts from that table, not a guess.\n" ;
		printf "NOT REACHED AT ALL, because this runs on a write and nothing else:\n" ;
		printf "  a frontmatter field value written through a patch, and skillset\n" ;
		printf "  text written with Edit or Write. The floor binds them; this does\n" ;
		printf "  not measure them.\n" ;
		exit 0 ;
	} else if ( textGroup != "message" ) {
		printf "AgentsOutputStyleCheck: no such text group: %s -- pass message, report, brief, relay or help\n", textGroup > "/dev/stderr" ;
		measureText = 0 ;
		groupFault = 1 ;
		exit 2 ;
	}
}

measureText == 0 { next ; }

## A leading --- opens frontmatter ONLY if a closing --- actually arrives. The
## lines are held rather than dropped, because an opening --- with no closer is
## a horizontal rule and the document below it is prose. Dropping them outright
## let three characters at the top of a message skip every predicate in silence.
NR == 1 && $0 == "---" { inFrontmatter = 1 ; heldLines[++heldCount] = $0 ; next ; }
inFrontmatter && $0 == "---" { inFrontmatter = 0 ; heldCount = 0 ; next ; }
inFrontmatter { heldLines[++heldCount] = $0 ; next ; }

{ scanLine( $0 ) ; }

END {
	if ( groupFault ) { exit 2 ; }
	if ( measureText == 0 ) { exit 0 ; }
	## The frontmatter never closed, so none of it was frontmatter.
	if ( inFrontmatter ) {
		for ( heldIndex = 1 ; heldIndex <= heldCount ; heldIndex++ ) { scanLine( heldLines[heldIndex] ) ; }
	}
	flushElement( paraText, 0 ) ;
	if ( faultTotal == 0 ) { exit 0 ; }
	printf "AgentsOutputStyleCheck: run this with textGroup=help for what it does and does not measure.\n" > "/dev/stderr" ;
	exit 1 ;
}
