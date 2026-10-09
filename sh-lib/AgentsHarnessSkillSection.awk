#!/usr/bin/env awk
# Prints only the named sections of a Markdown file: each from its heading down to the next
# heading of the same or a higher level. ENVIRON["skillSections"] holds the heading texts,
# separated by |, matched exactly once surrounding blanks are trimmed. Sections print in the
# order asked, a blank line between them. Lines inside ``` or ~~~ fences are never headings.
# One unknown section prints ERROR, naming every heading the file has, and nothing else.
function trimText( t ) { sub( /^[ \t]+/, "", t ) ; sub( /[ \t]+$/, "", t ) ; return t ; }
BEGIN {
	wantCount = split( ENVIRON["skillSections"], wantRaw, "|" )
	wantTotal = 0
	for ( i = 1 ; i <= wantCount ; i++ ) {
		w = trimText( wantRaw[i] )
		if ( w == "" || ( w in wantIndex ) ) continue
		wantTotal++ ; wantText[wantTotal] = w ; wantIndex[w] = wantTotal
	}
	inFence = 0 ; headCount = 0 ; current = 0
}
{
	line = $0
	if ( line ~ /^[ ]{0,3}(```|~~~)/ ) inFence = !inFence
	if ( !inFence && line ~ /^#{1,6}[ \t]/ ) {
		level = match( line, /^#+/ ) ? RLENGTH : 0
		text = substr( line, level + 1 ) ; sub( /[ \t]+#+[ \t]*$/, "", text ) ; text = trimText( text )
		headCount++ ; headLine[headCount] = line
		if ( current && level <= currentLevel ) current = 0
		if ( !current && ( text in wantIndex ) && !( text in found ) ) {
			current = wantIndex[text] ; currentLevel = level ; found[text] = 1
		}
	}
	if ( current ) body[current] = body[current] line "\n"
}
END {
	missing = ""
	for ( i = 1 ; i <= wantTotal ; i++ ) if ( !( wantText[i] in found ) ) missing = missing ( missing == "" ? "" : " | " ) wantText[i]
	if ( wantTotal == 0 ) missing = "<none named>"
	if ( missing != "" ) {
		printf "ERROR: Skill: no such section: %s -- the headings in this file are:\n", missing
		for ( i = 1 ; i <= headCount ; i++ ) print headLine[i]
		exit 0
	}
	for ( i = 1 ; i <= wantTotal ; i++ ) {
		if ( i > 1 ) printf "\n"
		printf "%s", body[i]
	}
}
