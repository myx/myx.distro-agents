#!/usr/bin/env awk
# Parses a Skill file's own frontmatter/body, then substitutes $N/named-arg/${CLAUDE_*} slots in its body.
function replaceEvery(fromText, toText, inText,   foundPos, doneText) {
	doneText = ""
	while ( ( foundPos = index(inText, fromText) ) > 0 ) { doneText = doneText substr(inText, 1, foundPos - 1) toText ; inText = substr(inText, foundPos + length(fromText)) ; }
	return doneText inText
}
NR == 1 && $0 == "---" { inFront = 1 ; next ; }
inFront && $0 == "---" { inFront = 0 ; next ; }
inFront && inNameList && $0 ~ /^[ \t]*-/ { listName = $0 ; sub(/^[ \t]*-[ \t]*/, "", listName) ; gsub(/["\047 \t]/, "", listName) ; nameList[++nameCount] = listName ; next ; }
inFront { inNameList = 0 ; }
inFront && $0 ~ /^disable-model-invocation:[ \t]*true[ \t]*$/ { modelBlocked = 1 ; }
inFront && $0 ~ /^arguments:/ { listText = $0 ; sub(/^arguments:/, "", listText) ; gsub(/\[/, " ", listText) ; gsub(/\]/, " ", listText) ; gsub(/[,"\047]/, " ", listText) ; nameCount = split(listText, nameList, " ") ; inNameList = 1 ; }
inFront { next ; }
{ bodyText = bodyText $0 "\n" ; }
END {
	if ( modelBlocked ) { printf "ERROR: Skill: %s sets disable-model-invocation: true, so only a user can invoke it, never a model\n", ENVIRON["skillLabel"] ; exit ; }
	argText = ENVIRON["skillArgs"] ; tokenCount = 0 ; tokenOpen = 0 ; quoteChar = "" ; tokenText = ""
	for ( charPos = 1 ; charPos <= length(argText) ; charPos++ ) {
		argChar = substr(argText, charPos, 1)
		if ( argChar == "\\" && quoteChar != "\047" && charPos < length(argText) && ( quoteChar == "" || index("\"\\$`", substr(argText, charPos + 1, 1)) > 0 ) ) { charPos++ ; tokenText = tokenText substr(argText, charPos, 1) ; tokenOpen = 1 ; continue ; }
		if ( quoteChar != "" ) { if ( argChar == quoteChar ) { quoteChar = "" ; } else { tokenText = tokenText argChar ; } continue ; }
		if ( argChar == "\"" || argChar == "\047" ) { quoteChar = argChar ; tokenOpen = 1 ; continue ; }
		if ( argChar == " " || argChar == "\t" || argChar == "\n" ) { if ( tokenOpen ) { argTokens[tokenCount++] = tokenText ; tokenText = "" ; tokenOpen = 0 ; } continue ; }
		tokenText = tokenText argChar ; tokenOpen = 1
	}
	if ( tokenOpen ) argTokens[tokenCount++] = tokenText
	outText = "" ; restText = bodyText ; argTaken = 0
	while ( ( dollarPos = index(restText, "$") ) > 0 ) {
		preText = substr(restText, 1, dollarPos - 1) ; restText = substr(restText, dollarPos + 1) ;
		placeLen = 0 ; placeKnown = 0 ; placeValue = ""
		if ( match(restText, /^ARGUMENTS\[[0-9]+\]/) ) {
			placeLen = RLENGTH ; argIndex = substr(restText, 11, RLENGTH - 11) + 0 ;
			if ( argIndex < tokenCount ) { placeKnown = 1 ; placeValue = argTokens[argIndex] ; }
		} else if ( substr(restText, 1, 9) == "ARGUMENTS" ) {
			placeLen = 9 ; placeKnown = 1 ; placeValue = argText
		} else if ( match(restText, /^[0-9]+/) ) {
			placeLen = RLENGTH ; argIndex = substr(restText, 1, RLENGTH) + 0 ;
			if ( argIndex < tokenCount ) { placeKnown = 1 ; placeValue = argTokens[argIndex] ; }
		} else {
			for ( nameIndex = 1 ; nameIndex <= nameCount ; nameIndex++ ) {
				argName = nameList[nameIndex]
				if ( argName != "" && substr(restText, 1, length(argName)) == argName && substr(restText, length(argName) + 1, 1) !~ /[A-Za-z0-9_]/ ) { placeLen = length(argName) ; placeKnown = 1 ; placeValue = ( nameIndex <= tokenCount ) ? argTokens[nameIndex - 1] : "" ; }
			}
		}
		escapeOne = substr(preText, length(preText)) == "\\" && !( length(preText) > 1 && substr(preText, length(preText) - 1, 1) == "\\" )
		if ( placeLen == 0 ) { outText = outText preText "$" ; continue ; }
		if ( escapeOne ) { outText = outText substr(preText, 1, length(preText) - 1) "$" substr(restText, 1, placeLen) ; }
		else if ( placeKnown ) { outText = outText preText placeValue ; argTaken = 1 ; }
		else { outText = outText preText "$" substr(restText, 1, placeLen) ; }
		restText = substr(restText, placeLen + 1)
	}
	outText = outText restText
	if ( argText != "" && !argTaken ) outText = outText "\nARGUMENTS: " argText "\n"
	outText = replaceEvery("${CLAUDE_SKILL_DIR}", ENVIRON["skillBaseDir"], outText)
	if ( ENVIRON["skillPluginRoot"] != "" ) { outText = replaceEvery("${CLAUDE_PLUGIN_ROOT}", ENVIRON["skillPluginRoot"], outText) ; if ( ENVIRON["skillPluginData"] != "" ) outText = replaceEvery("${CLAUDE_PLUGIN_DATA}", ENVIRON["skillPluginData"], outText) ; }
	printf "Base directory for this skill: %s\n%s", ENVIRON["skillBaseDir"], outText
}
