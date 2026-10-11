#!/usr/bin/env awk
# What a board item says its task is, in words, for a post a person reads: its title, and a
# longer text of a few sentences. One reader for every post that says what a session or a
# request is about (AgentsTools.TaskText.include): the event-track start post and the
# permission set post. Loaded after the transcript formatter, for its redaction:
#   LC_ALL=C awk -f AgentsSessionTranscriptFormat.awk -f AgentsTaskText.awk <item file>
# Environment: TASKTEXT_WANT, what is printed, one line or nothing --
#   title   the item's title: its first `# ` heading, without the mark;
#   text    its first paragraph: the first lines after the title that are no heading, up to an
#           empty line or a heading;
#   brief   the first paragraph of a dispatch's own brief, under `## Brief`, after the block the
#           tooling writes ahead of the spawner's words (sh-lib/templates/spawn-brief.document.format.md:
#           from `SPAWN-PREPARE-BRIEF:` to `When done, hand back; then Wait until dismissed.`);
#   header  one field of its frontmatter, named by TASKTEXT_FIELD;
#   line    TASKTEXT_VALUE itself, no item read: a description or a comment somebody gave;
#   kept    TASKTEXT_VALUE as a record keeps it: one line, redacted, at most 480 bytes.
# Every value is one line, redacted as the transcript redacts (stlRedact). A title, a header and
# a line are cut as a message is: at 120 bytes, at a character boundary, with an ellipsis. A
# text or a brief is cut at a sentence end: at most 4 sentences and at most 480 bytes, both
# fixed here; a first sentence longer than that is cut at 480 bytes with an ellipsis.

## One line: control characters and runs of spaces as one space, none at either end.
function oneLine( text ) {
	gsub( /[\001-\037\177]+/, " ", text ) ;
	gsub( /  +/, " ", text ) ;
	sub( /^ /, "", text ) ;
	sub( / $/, "", text ) ;
	return text ;
}

## A text cut to capBytes at a character boundary, with an ellipsis.
function cutBytesAt( text, capBytes ) {
	if ( length( text ) <= capBytes ) { return text ; }
	text = substr( text, 1, capBytes ) ;
	sub( /[\300-\377][\200-\277]*$/, "", text ) ;
	sub( / +$/, "", text ) ;
	return text "\342\200\246" ;
}

## A value somebody gave, as a post shows it.
function shownLine( text ) {
	return cutBytesAt( stlRedact( oneLine( text ) ), lineBytes ) ;
}

## The first sentences of a text: whole ones, while they fit both limits.
function sentences( text,    out, count, rest, piece ) {
	out = "" ; count = 0 ; rest = text ;
	while ( rest != "" && count < maxSentences ) {
		if ( match( rest, /[.!?]( |$)/ ) ) {
			piece = substr( rest, 1, RSTART ) ;
			rest = substr( rest, RSTART + RLENGTH ) ;
		}
		else { piece = rest ; rest = "" ; }
		if ( length( out ) + length( piece ) + ( out == "" ? 0 : 1 ) > maxBytes ) { break ; }
		out = out ( out == "" ? "" : " " ) piece ;
		count++ ;
	}
	if ( out == "" ) { out = cutBytesAt( text, maxBytes ) ; }
	return out ;
}

BEGIN {
	want = ENVIRON["TASKTEXT_WANT"] ;
	wantField = ENVIRON["TASKTEXT_FIELD"] ;
	## Fixed, never configured: the limits the templates' contracts state.
	maxSentences = 4 ; maxBytes = 480 ; lineBytes = 120 ;
	paragraph = "" ; found = "" ;
	if ( want == "line" || want == "kept" ) {
		found = ( want == "line" ) ? shownLine( ENVIRON["TASKTEXT_VALUE"] ) : cutBytesAt( stlRedact( oneLine( ENVIRON["TASKTEXT_VALUE"] ) ), maxBytes ) ;
		if ( found != "" ) { print found ; }
		givenDone = 1 ;
		exit 0 ;
	}
}

## The frontmatter: between the first line and the next `---`.
NR == 1 && $0 == "---" { inHead = 1 ; next ; }
inHead && $0 == "---" { inHead = 0 ; next ; }
inHead {
	if ( want == "header" && found == "" && wantField != "" && index( $0, wantField ": " ) == 1 ) { found = substr( $0, length( wantField ) + 3 ) ; }
	next ;
}

want == "header" { exit 0 ; }

want == "title" {
	if ( $0 ~ /^# / ) { found = substr( $0, 3 ) ; exit 0 ; }
	next ;
}

want == "text" {
	if ( ! titled ) { if ( $0 ~ /^# / ) { titled = 1 ; } next ; }
	if ( $0 ~ /^#/ || $0 ~ /^[ \t]*$/ ) { if ( paragraph != "" ) { exit 0 ; } next ; }
	paragraph = paragraph ( paragraph == "" ? "" : " " ) $0 ;
	next ;
}

want == "brief" {
	if ( ! inBrief ) { if ( $0 == "## Brief" ) { inBrief = 1 ; } next ; }
	if ( index( $0, "SPAWN-PREPARE-BRIEF: " ) == 1 ) { inBlock = 1 ; next ; }
	if ( inBlock ) { if ( $0 == "When done, hand back; then Wait until dismissed." ) { inBlock = 0 ; } next ; }
	if ( $0 ~ /^#/ || $0 ~ /^[ \t]*$/ ) { if ( paragraph != "" ) { exit 0 ; } next ; }
	paragraph = paragraph ( paragraph == "" ? "" : " " ) $0 ;
	next ;
}

END {
	if ( givenDone ) { exit 0 ; }
	if ( want == "text" || want == "brief" ) {
		paragraph = stlRedact( oneLine( paragraph ) ) ;
		if ( paragraph != "" ) { print sentences( paragraph ) ; }
		exit 0 ;
	}
	found = shownLine( found ) ;
	if ( found != "" ) { print found ; }
}
