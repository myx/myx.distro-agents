#!/usr/bin/awk -f
##
## AgentsManagerConfigLabels.awk -- gives each row of the settings digest its label, as its last
## field: for AgentsToolsManagerConfigLabelled (AgentsTools.ManagerConfig.include). On standard
## input, in this order: the rows of the one declaration of the labels (THE LABELS there, which
## says what a row is), one line that holds the byte \034 alone, and the rows of a subject as
## the digest made them, its `subject` row and its `line` rows, a TAB between their fields.
##
##   -v capitals=<words>   the words of a key that stand whole in capitals in a label made of
##       the key's own words, parted by blanks (agentsManagerConfigLabelCapitals).
##
## Prints each row with one more field at its end: the label of the first row of the
## declaration that fits it, its blanks written `_` as every field of a row has them, and `-`
## where no row fits. Nothing else of a row is changed: no key, no state, no value.
##

BEGIN {
	FS = "\t" ; OFS = "\t"
	declaring = 1 ; rows = 0
	count = split( capitals, capital, " " )
	for ( at = 1 ; at <= count ; at++ ) inCapitals[capital[at]] = 1
}

declaring {
	if ( $0 == "\034" ) { declaring = 0 ; next }
	if ( split( $0, part, "|" ) < 4 || part[1] == "" || part[4] == "" ) next
	rows++
	rowSubject[rows] = part[1] ; rowGroup[rows] = part[2] ; rowKey[rows] = part[3] ; rowLabel[rows] = part[4]
	next
}

$1 == "subject" { print $0, labelOf( $2, "", "", 1 ) ; next }
$1 == "line" { print $0, labelOf( $2, $3, $4, 0 ) ; next }
{ print }

## Whether a word of a row of the declaration fits a word of a line: `*` fits any, a word
## that ends with `*` every word that begins so, any other word itself alone.
function fits( pattern, text ) {
	if ( pattern == "*" ) return 1
	if ( substr( pattern, length( pattern ) ) == "*" ) return ( index( text, substr( pattern, 1, length( pattern ) - 1 ) ) == 1 )
	return ( pattern == text )
}

## The words of a key, capitalised, a blank between them: what stands between its `_` and
## `-`, the first letter of each a capital and the rest small, a word of the capitals whole
## in capitals. A key of one word gets `Setting` after it: no label is one word.
function wordsOf( key,    count, word, at, text, made ) {
	count = split( key, word, /[_-]+/ ) ; text = "" ; made = 0
	for ( at = 1 ; at <= count ; at++ ) {
		if ( word[at] == "" ) continue
		made++
		text = text ( text == "" ? "" : " " ) ( ( toupper( word[at] ) in inCapitals ) ? toupper( word[at] ) : toupper( substr( word[at], 1, 1 ) ) tolower( substr( word[at], 2 ) ) )
	}
	return ( made == 1 ) ? text " Setting" : text
}

## A text with the first of a mark in it replaced, whatever the replacement holds.
function put( text, mark, with,    at ) {
	at = index( text, mark )
	return ( at == 0 ) ? text : substr( text, 1, at - 1 ) with substr( text, at + length( mark ) )
}

## The label of a subject itself (own is 1) or of one of its lines: that of the first row
## that fits. A row with no group and no key is the subject's own, and no line's.
function labelOf( subject, group, key, own,    at, label ) {
	for ( at = 1 ; at <= rows ; at++ ) {
		if ( rowSubject[at] != subject ) continue
		if ( rowGroup[at] == "" && rowKey[at] == "" ) { if ( !own ) continue }
		else if ( own || !fits( rowGroup[at], group ) || !fits( rowKey[at], key ) ) continue
		label = put( put( rowLabel[at], "{words}", wordsOf( key ) ), "{name}", key )
		gsub( /[ \t]+/, "_", label )
		return ( label == "" ) ? "-" : label
	}
	return "-"
}
