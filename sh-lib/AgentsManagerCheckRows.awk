#!/usr/bin/awk -f
##
## AgentsManagerCheckRows.awk -- the result lines of one check of the setup as rows: for
## --manager-check-run (AgentsTools.ManagerCheck.include). On standard input what
## `--owner-setup-<domain> --check` printed, text for a person. NOTHING IS DECIDED HERE: no
## check is made, no state is changed and none is weighed. A line is only put into fields.
##
##   -v domain=<name>     the domain the text is of: the second field of every row.
##   -v capitals=<words>  the words of a key that stand whole in capitals in its label.
##
## What is read of the text:
##   `## <words>`                a heading: the section of the result lines under it;
##   `<KEY>: OK|WARN|FAIL ...`   a result line: one row, with what follows the state as the
##                               first of its reason;
##   `  fix: <command>`          under a result line: its remedy;
##   `  <word>: <text>`          under a result line: more of its reason, in the check's own
##                               words; the word itself is kept but for warn, fail and note;
##   a line set further in       goes on with the line above it.
## Any other line is no result and is left out. Prints one row a result line:
##   `check`, domain, section, key, label, state, reason, remedy
## the label the words of the key, capitalised; the state `ok`, `warn` or `fail`. Every field
## is one field: a run of whitespace in it reads `_`, and an empty one `-`. The remedy, the
## last, is a command to run: its blanks are kept, one where a run of them stood.
##

BEGIN {
	OFS = "\t" ; section = "" ; have = 0
	count = split( capitals, capital, " " )
	for ( at = 1 ; at <= count ; at++ ) inCapitals[capital[at]] = 1
}

function field( text ) {
	gsub( /^[ \t]+|[ \t]+$/, "", text )
	gsub( /[ \t]+/, "_", text )
	return ( text == "" ) ? "-" : text
}

function labelOf( key,    count, word, at, text ) {
	count = split( key, word, /[_-]+/ ) ; text = ""
	for ( at = 1 ; at <= count ; at++ ) {
		if ( word[at] == "" ) continue
		text = text ( text == "" ? "" : " " ) ( ( toupper( word[at] ) in inCapitals ) ? toupper( word[at] ) : toupper( substr( word[at], 1, 1 ) ) tolower( substr( word[at], 2 ) ) )
	}
	return text
}

function flush() {
	if ( !have ) return
	gsub( /^[ \t]+|[ \t]+$/, "", remedy ) ; gsub( /[ \t]+/, " ", remedy )
	print "check", field( domain ), field( section ), field( key ), field( labelOf( key ) ), state, field( reason ), ( remedy == "" ) ? "-" : remedy
	have = 0
}

/^## / { flush() ; section = substr( $0, 4 ) ; next }

/^[A-Z][A-Z0-9_]*: (OK|WARN|FAIL)( |$)/ {
	flush()
	have = 1 ; key = $0 ; sub( /:.*$/, "", key )
	rest = $0 ; sub( /^[A-Z][A-Z0-9_]*: /, "", rest )
	state = ( rest ~ /^OK/ ) ? "ok" : ( rest ~ /^WARN/ ) ? "warn" : "fail"
	sub( /^(OK|WARN|FAIL)[ ]*/, "", rest )
	reason = rest ; remedy = "" ; last = "reason"
	next
}

have && /^[ \t]+[a-z][a-z-]*:( |$)/ {
	text = $0 ; sub( /^[ \t]+/, "", text )
	tag = text ; sub( /:.*$/, "", tag ) ; sub( /^[a-z-]+:[ ]*/, "", text )
	if ( tag == "fix" ) { remedy = remedy ( remedy == "" ? "" : " " ) text ; last = "remedy" }
	else {
		if ( tag != "warn" && tag != "fail" && tag != "note" ) text = tag ": " text
		reason = reason ( reason == "" ? "" : " " ) text ; last = "reason"
	}
	next
}

have && /^[ \t]+[^ \t]/ {
	text = $0 ; sub( /^[ \t]+/, "", text )
	if ( last == "remedy" ) remedy = remedy " " text ; else reason = reason ( reason == "" ? "" : " " ) text
	next
}

/^[^ \t]/ { flush() }

END { flush() }
