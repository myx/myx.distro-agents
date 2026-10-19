#!/usr/bin/env awk

# Searches the tool catalogue on stdin -- one JSON array, declarations in any of
# three envelopes -- and prints the matches as one <functions> block. Query and
# bound arrive as MDAT_TOOLSEARCH_QUERY and MDAT_TOOLSEARCH_MAX. MAGIC.md states the forms.
# rc 0 printed -- rc 1 not one parseable array, or a declaration missing a field.
# LC_ALL=C IS REQUIRED: split(s, sc, "") and substr() must count the same bytes.

BEGIN {
	inputText = ""
	inputSeen = 0
	toolCount = 0
	structErr = 0
}

function skipws(   curChar) {
	while (scanPos <= scanLen) {
		curChar = scanChars[scanPos]
		if (curChar == " " || curChar == "\t" || curChar == "\n" || curChar == "\r") scanPos++
		else break
	}
}

## Advances past one string and returns its source text without the quotes.
function scanString(   startPos, curChar, isClosed) {
	startPos = scanPos
	scanPos++
	isClosed = 0
	while (scanPos <= scanLen) {
		curChar = scanChars[scanPos]
		if (curChar == "\\") { scanPos = scanPos + 2 ; continue ; }
		scanPos++
		if (curChar == "\"") { isClosed = 1 ; break ; }
	}
	if (!isClosed) structErr = 1
	return substr(inputText, startPos + 1, scanPos - startPos - 2)
}

## nodeRole is where this value sits: "top", "tool", "function", or the field it
## is kept as -- "name", "description", "schema" -- else "".
function scanValue(nodeRole,   startPos, curChar) {
	skipws()
	startPos = scanPos
	curChar = scanChars[scanPos]
	if (curChar == "\"") scanString()
	else if (curChar == "{") scanObject(nodeRole)
	else if (curChar == "[") scanArray(nodeRole)
	else {
		while (scanPos <= scanLen) {
			curChar = scanChars[scanPos]
			if (curChar == "," || curChar == "}" || curChar == "]" || curChar == " " || curChar == "\t" || curChar == "\n" || curChar == "\r") break
			scanPos++
		}
		## A zero-length run cannot begin a value, so `{"a":}` is refused.
		if (scanPos == startPos) { structErr = 1 ; return ; }
	}
	if ((nodeRole == "name" || nodeRole == "description" || nodeRole == "schema") && !((toolCount, nodeRole) in toolField)) {
		toolField[toolCount, nodeRole] = substr(inputText, startPos, scanPos - startPos)
	}
}

## The three envelopes differ only in where the fields sit and what the schema
## key is called, so one mapping reads all of them.
function scanObject(nodeRole,   keyName, childRole, curChar) {
	scanPos++
	skipws()
	if (scanChars[scanPos] == "}") { scanPos++ ; return ; }
	while (!structErr) {
		skipws()
		if (scanChars[scanPos] != "\"") { structErr = 1 ; return ; }
		keyName = scanString()
		skipws()
		if (scanChars[scanPos] != ":") { structErr = 1 ; return ; }
		scanPos++
		childRole = ""
		if (nodeRole == "tool" && keyName == "function") childRole = "function"
		else if (nodeRole == "tool" || nodeRole == "function") {
			if (keyName == "name" || keyName == "description") childRole = keyName
			else if (keyName == "parameters" || keyName == "inputSchema" || keyName == "input_schema") childRole = "schema"
		}
		scanValue(childRole)
		skipws()
		curChar = scanChars[scanPos]
		if (curChar == ",") { scanPos++ ; continue ; }
		else if (curChar == "}") { scanPos++ ; break ; }
		else { structErr = 1 ; break ; }
	}
}

function scanArray(nodeRole,   curChar) {
	scanPos++
	skipws()
	if (scanChars[scanPos] == "]") { scanPos++ ; return ; }
	while (!structErr) {
		if (nodeRole == "top") {
			toolCount++
			scanValue("tool")
		}
		else scanValue("")
		skipws()
		curChar = scanChars[scanPos]
		if (curChar == ",") { scanPos++ ; continue ; }
		else if (curChar == "]") { scanPos++ ; break ; }
		else { structErr = 1 ; break ; }
	}
}

{
	if (inputSeen) inputText = inputText "\n" $0
	else inputText = $0
	inputSeen = 1
}

END {
	scanLen = split(inputText, scanChars, "")
	scanPos = 1

	skipws()
	if (scanPos > scanLen || scanChars[scanPos] != "[") {
		printf("⛔ ERROR: AgentsHarnessToolSearch.awk: input is not a JSON array -- an empty read, or a catalogue that no longer opens with [\n") > "/dev/stderr"
		exit 1
	}

	scanValue("top")
	skipws()

	if (structErr || scanPos <= scanLen) {
		printf("⛔ ERROR: AgentsHarnessToolSearch.awk: the tool catalogue is NOT VALID JSON -- the parser refused it at byte %d, in or right after declaration %d\n", scanPos, toolCount - 1) > "/dev/stderr"
		exit 1
	}

	for (toolIndex = 1; toolIndex <= toolCount; toolIndex++) {
		if (!((toolIndex, "name") in toolField) || !((toolIndex, "description") in toolField) || !((toolIndex, "schema") in toolField)) {
			printf("⛔ ERROR: AgentsHarnessToolSearch.awk: declaration %d lacks its name, description or schema, so it cannot be returned whole\n", toolIndex - 1) > "/dev/stderr"
			exit 1
		}
		bareName[toolIndex] = substr(toolField[toolIndex, "name"], 2, length(toolField[toolIndex, "name"]) - 2)
		lowerName[toolIndex] = tolower(bareName[toolIndex])
		lowerDesc[toolIndex] = tolower(toolField[toolIndex, "description"])
	}

	queryText = ENVIRON["MDAT_TOOLSEARCH_QUERY"]
	maxResults = ENVIRON["MDAT_TOOLSEARCH_MAX"] + 0
	sub(/^[ \t]+/, "", queryText)
	sub(/[ \t]+$/, "", queryText)

	hitCount = 0
	if (substr(queryText, 1, 7) == "select:") {
		wantCount = split(substr(queryText, 8), wantNames, ",")
		for (wantIndex = 1; wantIndex <= wantCount; wantIndex++) {
			wantName = wantNames[wantIndex]
			sub(/^[ \t]+/, "", wantName)
			sub(/[ \t]+$/, "", wantName)
			if (wantName == "" || (wantName in wantSeen)) continue
			wantSeen[wantName] = 1
			for (toolIndex = 1; toolIndex <= toolCount; toolIndex++) {
				if (bareName[toolIndex] == wantName) { hitTools[++hitCount] = toolIndex ; break ; }
			}
		}
		showCount = hitCount
	}
	else {
		requireWord = ""
		termText = queryText
		if (substr(queryText, 1, 1) == "+") {
			termText = substr(queryText, 2)
			requireWord = termText
			sub(/[ \t].*$/, "", requireWord)
			sub(/^[^ \t]*/, "", termText)
			requireWord = tolower(requireWord)
			if (requireWord == "") {
				printf("ERROR: ToolSearch: +word needs a word straight after the +, and none was given. Nothing was searched.\n")
				exit 0
			}
		}
		termCount = split(tolower(termText), termWords, " ")
		for (toolIndex = 1; toolIndex <= toolCount; toolIndex++) {
			if (requireWord != "" && !index(lowerName[toolIndex], requireWord)) continue
			toolScore = 0
			for (termIndex = 1; termIndex <= termCount; termIndex++) {
				if (index(lowerName[toolIndex], termWords[termIndex])) toolScore += 2
				if (index(lowerDesc[toolIndex], termWords[termIndex])) toolScore += 1
			}
			if (requireWord == "" && toolScore == 0) continue
			## Insertion that keeps catalogue order among equal scores.
			hitPos = ++hitCount
			while (hitPos > 1 && hitScore[hitPos - 1] < toolScore) {
				hitTools[hitPos] = hitTools[hitPos - 1]
				hitScore[hitPos] = hitScore[hitPos - 1]
				hitPos--
			}
			hitTools[hitPos] = toolIndex
			hitScore[hitPos] = toolScore
		}
		showCount = (hitCount < maxResults) ? hitCount : maxResults
	}

	if (hitCount == 0) {
		printf("No tool matched that query, among the %d tool(s) this run offers.\n", toolCount)
		exit 0
	}

	searchOut = "<functions>\n"
	for (hitIndex = 1; hitIndex <= showCount; hitIndex++) {
		toolIndex = hitTools[hitIndex]
		searchOut = searchOut "<function>{\"description\":" toolField[toolIndex, "description"] ",\"name\":" toolField[toolIndex, "name"] ",\"parameters\":" toolField[toolIndex, "schema"] "}</function>\n"
	}
	printf("%s</functions>\n", searchOut)
	exit 0
}
