#!/usr/bin/env awk
# Filters a piped file list to those whose path (relative to GLOB_ROOT) matches the GLOB_PATTERN glob.
BEGIN {
	globRoot = ENVIRON["GLOB_ROOT"] ; globText = ENVIRON["GLOB_PATTERN"] ; globRegex = "^" ; braceDepth = 0 ;
	for ( charPos = 1 ; charPos <= length(globText) ; charPos++ ) {
		globChar = substr(globText, charPos, 1)
		if ( substr(globText, charPos, 3) == "**/" ) { globRegex = globRegex "(.*/)?" ; charPos = charPos + 2 ; }
		else if ( substr(globText, charPos) == "**" ) { globRegex = globRegex ".*" ; charPos = charPos + 1 ; }
		else if ( globChar == "*" ) globRegex = globRegex "[^/]*"
		else if ( globChar == "?" ) globRegex = globRegex "[^/]"
		else if ( globChar == "{" && index(substr(globText, charPos), "}") > 0 ) { globRegex = globRegex "(()" ; braceDepth = braceDepth + 1 ; }
		else if ( globChar == "," && braceDepth > 0 ) globRegex = globRegex "|()"
		else if ( globChar == "}" && braceDepth > 0 ) { globRegex = globRegex ")" ; braceDepth = braceDepth - 1 ; }
		else if ( globChar == "[" && ( classLength = index(substr(globText, charPos + 2), "]") ) > 0 ) { classText = substr(globText, charPos + 1, classLength) ; if ( substr(classText, 1, 1) == "!" ) classText = "^" substr(classText, 2) ; globRegex = globRegex "[" classText "]" ; charPos = charPos + classLength + 1 ; }
		else if ( index("\\.+()|^$[]{}", globChar) > 0 ) globRegex = globRegex "\\" globChar
		else globRegex = globRegex globChar
	}
	globRegex = globRegex "$"
}
{
	relPath = ( index($0, globRoot) == 1 ) ? substr($0, length(globRoot) + 1) : $0
	sub(/^\/+/, "", relPath)
	if ( relPath != "" && relPath ~ globRegex ) print ;
}
