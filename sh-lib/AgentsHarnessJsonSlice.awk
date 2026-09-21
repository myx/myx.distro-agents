#!/usr/bin/env awk

# Reads one JSON object (stdin) and prints, for one exact dot-separated key path
# (`-v path=...`), either that value's own RAW SOURCE TEXT (`-v mode=raw`) or the
# immediate child key names of the object sitting there, one per line
# (`-v mode=keys`). AgentsHarnessJsonField.awk beside it returns DECODED SCALARS
# ONLY, so neither a schema subtree nor a key whose name nobody knows in advance
# is reachable through it; this returns bytes and names instead, and that reader
# keeps every scalar and every `__count`.
#
# Nothing here is decoded: a raw value is the bytes the document carried, and a
# key name keeps its own escapes, so a name a caller cannot gate arrives visibly
# ungateable rather than silently rewritten into something that passes.
#
# rc 0 found (value on stdout) -- rc 3 parsed, path absent -- rc 1 not a
# parseable JSON object -- rc 2 usage error.
#
# LC_ALL=C IS REQUIRED -- the walk indexes a byte array from split(s, sc, "").

BEGIN {
	wantPath = path
	sliceMode = mode
	inputText = ""
	inputSeen = 0
	foundCount = 0
	foundValue = ""
	structErr = 0
}

function skipws(   curChar) {
	while (scanPos <= scanLen) {
		curChar = scanChars[scanPos]
		if (curChar == " " || curChar == "\t" || curChar == "\n" || curChar == "\r") scanPos++
		else break
	}
}

function sliceText(fromPos, toPos,   outText, atPos) {
	outText = ""
	for (atPos = fromPos; atPos < toPos; atPos++) outText = outText scanChars[atPos]
	return outText
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
	return sliceText(startPos + 1, scanPos - 1)
}

function scanValue(nodePath,   startPos, curChar) {
	skipws()
	startPos = scanPos
	curChar = scanChars[scanPos]
	if (curChar == "\"") scanString()
	else if (curChar == "{") scanObject(nodePath)
	else if (curChar == "[") scanArray(nodePath)
	else {
		while (scanPos <= scanLen) {
			curChar = scanChars[scanPos]
			if (curChar == "," || curChar == "}" || curChar == "]" || curChar == " " || curChar == "\t" || curChar == "\n" || curChar == "\r") break
			scanPos++
		}
		## A zero-length run cannot begin a value, so `{"a":}` is rc 1 not rc 0.
		if (scanPos == startPos) { structErr = 1 ; return ; }
	}
	if (sliceMode == "raw" && nodePath == wantPath) {
		if (foundCount == 0) foundValue = sliceText(startPos, scanPos)
		foundCount++
	}
}

function scanObject(nodePath,   isWanted, keyName, keyPath, curChar) {
	isWanted = (sliceMode == "keys" && nodePath == wantPath)
	if (isWanted) foundCount++
	scanPos++
	skipws()
	if (scanChars[scanPos] == "}") { scanPos++ ; return ; }
	while (1) {
		skipws()
		## A key is a string and the separator is required: consuming either blindly
		## reads `{"a" 1}` as a well-formed object.
		if (scanChars[scanPos] != "\"") { structErr = 1 ; return ; }
		keyName = scanString()
		if (isWanted && foundCount == 1) foundValue = foundValue keyName "\n"
		skipws()
		if (scanChars[scanPos] != ":") { structErr = 1 ; return ; }
		scanPos++
		keyPath = (nodePath == "") ? keyName : nodePath "." keyName
		scanValue(keyPath)
		skipws()
		curChar = scanChars[scanPos]
		if (curChar == ",") { scanPos++ ; continue ; }
		else if (curChar == "}") { scanPos++ ; break ; }
		else { structErr = 1 ; break ; }
	}
}

function scanArray(nodePath,   itemIndex, curChar) {
	scanPos++
	skipws()
	itemIndex = 0
	if (scanChars[scanPos] == "]") { scanPos++ ; return ; }
	while (1) {
		scanValue(nodePath "." itemIndex)
		itemIndex++
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
	if (wantPath == "" || (sliceMode != "raw" && sliceMode != "keys")) {
		printf("⛔ ERROR: AgentsHarnessJsonSlice.awk: pass both `-v path=...` and one of `-v mode=raw` or `-v mode=keys`\n") > "/dev/stderr"
		exit 2
	}

	scanLen = split(inputText, scanChars, "")
	scanPos = 1

	skipws()
	if (scanPos > scanLen || scanChars[scanPos] != "{") {
		printf("⛔ ERROR: AgentsHarnessJsonSlice.awk: input is not a JSON object -- an empty read, a diagnostic captured in place of a document, or a line that is not one (wanted path `%s`)\n", wantPath) > "/dev/stderr"
		exit 1
	}

	scanValue("")
	skipws()

	if (structErr || scanPos <= scanLen) {
		printf("⛔ ERROR: AgentsHarnessJsonSlice.awk: input did not parse as one complete JSON object -- truncated body or trailing garbage (wanted path `%s`)\n", wantPath) > "/dev/stderr"
		exit 1
	}

	if (foundCount == 0) exit 3

	if (sliceMode == "keys") printf("%s", foundValue)
	else printf("%s\n", foundValue)
	exit 0
}
