#!/usr/bin/env awk
# Filters a piped file list to those whose path (relative to GLOB_ROOT) matches the GLOB_PATTERN glob.
function globRegex(globText,   regexText, charPos, globChar, braceDepth, classLength, classText) {
	regexText = "^" ; braceDepth = 0 ;
	for ( charPos = 1 ; charPos <= length(globText) ; charPos++ ) {
		globChar = substr(globText, charPos, 1)
		if ( substr(globText, charPos, 3) == "**/" ) { regexText = regexText "(.*/)?" ; charPos = charPos + 2 ; }
		else if ( substr(globText, charPos) == "**" ) { regexText = regexText ".*" ; charPos = charPos + 1 ; }
		else if ( globChar == "*" ) regexText = regexText "[^/]*"
		else if ( globChar == "?" ) regexText = regexText "[^/]"
		else if ( globChar == "{" && index(substr(globText, charPos), "}") > 0 ) { regexText = regexText "(()" ; braceDepth = braceDepth + 1 ; }
		else if ( globChar == "," && braceDepth > 0 ) regexText = regexText "|()"
		else if ( globChar == "}" && braceDepth > 0 ) { regexText = regexText ")" ; braceDepth = braceDepth - 1 ; }
		else if ( globChar == "[" && ( classLength = index(substr(globText, charPos + 2), "]") ) > 0 ) { classText = substr(globText, charPos + 1, classLength) ; if ( substr(classText, 1, 1) == "!" ) classText = "^" substr(classText, 2) ; regexText = regexText "[" classText "]" ; charPos = charPos + classLength + 1 ; }
		else if ( index("\\.+()|^$[]{}", globChar) > 0 ) regexText = regexText "\\" globChar
		else regexText = regexText globChar
	}
	return regexText "$"
}
BEGIN { globRoot = ENVIRON["GLOB_ROOT"] ; globMatch = globRegex(ENVIRON["GLOB_PATTERN"]) ; }
{
	relPath = ( index($0, globRoot) == 1 ) ? substr($0, length(globRoot) + 1) : $0
	sub(/^\/+/, "", relPath)
	if ( relPath == "" ) { relPath = $0 ; sub(/^.*\//, "", relPath) ; }
	if ( relPath ~ globMatch ) { print ; }
}
