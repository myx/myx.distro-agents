#!/usr/bin/env awk
# Translates \d\s\w (and negations) and POSIX class shorthand inside a pattern to ERE-safe form.
BEGIN {
	patternText = ENVIRON["GREP_PATTERN"] ; outText = "" ; inBracket = 0 ; charPos = 1 ; patternLength = length(patternText) ;
	while ( charPos <= patternLength ) {
		thisChar = substr(patternText, charPos, 1) ; nextChar = substr(patternText, charPos + 1, 1) ;
		if ( !inBracket && thisChar == "[" ) {
			outText = outText thisChar ; charPos++ ; inBracket = 1 ;
			if ( substr(patternText, charPos, 1) == "^" ) { outText = outText "^" ; charPos++ ; }
			if ( substr(patternText, charPos, 1) == "]" ) { outText = outText "]" ; charPos++ ; }
			continue ;
		}
		if ( inBracket && thisChar == "[" && nextChar != "" && index(":=.", nextChar) > 0 && ( closePos = index(substr(patternText, charPos + 2), nextChar "]") ) > 0 ) {
			outText = outText substr(patternText, charPos, closePos + 3) ; charPos = charPos + closePos + 3 ; continue ;
		}
		if ( inBracket && thisChar == "]" ) { outText = outText thisChar ; charPos++ ; inBracket = 0 ; continue ; }
		if ( thisChar == "\\" && nextChar != "" ) {
			classIndex = index("dswDSW", nextChar) ;
			if ( classIndex == 0 ) { outText = outText thisChar nextChar ; charPos = charPos + 2 ; continue ; }
			className = ( classIndex % 3 == 1 ) ? "[:digit:]" : ( ( classIndex % 3 == 2 ) ? "[:space:]" : "[:alnum:]_" ) ;
			if ( inBracket && classIndex > 3 ) { print "ERROR: \\" nextChar " cannot stand inside a [...] bracket expression here, because POSIX has no negated class inside one. Use [^...] instead. Nothing was searched." ; exit 3 ; }
			outText = outText ( inBracket ? className : ( classIndex > 3 ? "[^" className "]" : "[" className "]" ) ) ;
			charPos = charPos + 2 ; continue ;
		}
		outText = outText thisChar ; charPos++ ;
	}
	print outText ;
}
