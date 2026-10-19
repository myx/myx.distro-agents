#!/usr/bin/awk -f
##
## AgentsManagerConfigLabels.awk -- gives each row of the settings digest what the one
## declaration says of it, its label and, in full, its description and whether it can be
## changed: for AgentsToolsManagerConfigLabelled (AgentsTools.ManagerConfig.include). On
## standard input, in this order: the rows of the declaration (THE LABELS there, which says
## what a row is), one line that holds the byte \034 alone, and the rows of a subject as the
## digest made them, a TAB between their fields: its `subject` row and its `line` rows. A
## line has six fields, or eleven where it is a changeable setting's: the six, then where its
## value comes from, what it takes, its kind, its scope and the file it is saved in.
##
##   -v capitals=<words>   the words of a key that stand whole in capitals in a label made of
##       the key's own words, parted by blanks (agentsManagerConfigLabelCapitals).
##   -v full=1             each line in full, fifteen fields: its six, its label, then its
##       description, whether it can be changed, its kind, its scope, where its value comes
##       from, what it takes, where it is saved, and which of the two it belongs to,
##       `settings` or `configuration`, as its row of the declaration says. A line that
##       cannot be changed reads `no` where it says so, with the reason after a colon where
##       it belongs to the configuration, and `-` in the five fields after it. And one
##       `group` row ahead of the lines of each group of a subject: the subject, the group
##       as its lines carry it, how many lines it has, and its label, that of the row of
##       the declaration that has that group and no key.
##   -v deployed=<words>   that reason: why no line of the configuration is changed here.
##   -v earlier=<subjects>   the subjects whose changeable lines keep, without full, the form
##       they had first: where the value comes from and what it takes ahead of the label.
##
## Without full a row gets one more field at its end, its label. The label and the
## description are those of the first row of the declaration that fits, their blanks written
## `_` as every field of a row has them, and `-` where no row fits. Nothing else of a row is
## changed: no key, no state, no value.
##

BEGIN {
	FS = "\t" ; OFS = "\t"
	declaring = 1 ; rows = 0
	count = split( capitals, capital, " " )
	for ( at = 1 ; at <= count ; at++ ) inCapitals[capital[at]] = 1
	count = split( earlier, capital, " " )
	for ( at = 1 ; at <= count ; at++ ) earlierForm[capital[at]] = 1
}

declaring {
	if ( $0 == "\034" ) { declaring = 0 ; next }
	count = split( $0, part, "|" )
	if ( count < 4 || part[1] == "" || part[4] == "" ) next
	rows++
	rowSubject[rows] = part[1] ; rowGroup[rows] = part[2] ; rowKey[rows] = part[3] ; rowLabel[rows] = part[4]
	rowBelongs[rows] = ( count >= 5 ) ? part[5] : "" ; rowDescription[rows] = ( count >= 6 ) ? part[6] : ""
	next
}

$1 == "subject" {
	if ( full ) flushGroup()
	at = rowOf( $2, "", "", 1 )
	print $0, ( at ? worded( rowLabel[at], "" ) : "-" )
	next
}

$1 == "line" {
	at = rowOf( $2, $3, $4, 0 )
	label = at ? worded( rowLabel[at], $4 ) : "-"
	base = $1 OFS $2 OFS $3 OFS $4 OFS $5 OFS $6
	if ( !full ) {
		if ( NF >= 11 && ( $2 in earlierForm ) ) print base, $7, $8, label
		else print base, label
		next
	}
	description = at ? worded( rowDescription[at], $4 ) : "-"
	belongs = ( at && rowBelongs[at] != "" ) ? rowBelongs[at] : "-"
	## a line of the configuration that has the fields of a changeable one keeps them, and is not changed here either
	if ( NF >= 11 ) {
		reason = ( belongs == "configuration" ) ? deployed : ""
		gsub( /[ \t]+/, "_", reason )
		held = base OFS label OFS description OFS ( ( belongs == "configuration" ) ? "no:" reason : "yes" ) OFS $9 OFS $10 OFS $7 OFS $8 OFS $11 OFS belongs
	}
	else {
		reason = ( belongs == "configuration" ) ? deployed : ""
		gsub( /[ \t]+/, "_", reason )
		held = base OFS label OFS description OFS ( ( reason == "" ) ? "no" : "no:" reason ) OFS "-" OFS "-" OFS "-" OFS "-" OFS "-" OFS belongs
	}
	## The lines of a group are kept until its last, so that its row can count them.
	if ( groupHas && ( $2 != groupSubject || $3 != groupName ) ) flushGroup()
	if ( !groupHas ) { groupHas = 1 ; groupSubject = $2 ; groupName = $3 ; groupCount = 0 }
	groupRows[++groupCount] = held
	next
}

END { if ( full ) flushGroup() }

## The row of a group and then its lines, as they were kept.
function flushGroup(    at, number ) {
	if ( !groupHas ) return
	at = groupOf( groupSubject, groupName )
	print "group", groupSubject, groupName, groupCount, ( at ? worded( rowLabel[at], groupName ) : "-" )
	for ( number = 1 ; number <= groupCount ; number++ ) print groupRows[number]
	groupHas = 0
}

## The row of the declaration for a group of a subject: the first that has a group that
## fits and no key, 0 where none does.
function groupOf( subject, group,    at ) {
	for ( at = 1 ; at <= rows ; at++ ) if ( rowSubject[at] == subject && rowKey[at] == "" && rowGroup[at] != "" && fits( rowGroup[at], group ) ) return at
	return 0
}

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

## A text of a row of the declaration as a field of a row of the digest: what it says of the
## key put in, its blanks written `_`, and `-` where it is empty.
function worded( text, key ) {
	text = put( put( text, "{words}", wordsOf( key ) ), "{name}", key )
	gsub( /[ \t]+/, "_", text )
	return ( text == "" ) ? "-" : text
}

## The row of the declaration for a subject itself (own is 1) or for one of its lines: the
## first that fits, 0 where none does. A row with no group and no key is the subject's own,
## and no line's.
function rowOf( subject, group, key, own,    at ) {
	for ( at = 1 ; at <= rows ; at++ ) {
		if ( rowSubject[at] != subject ) continue
		if ( rowGroup[at] == "" && rowKey[at] == "" ) { if ( !own ) continue }
		else if ( own || !fits( rowGroup[at], group ) || !fits( rowKey[at], key ) ) continue
		return at
	}
	return 0
}
