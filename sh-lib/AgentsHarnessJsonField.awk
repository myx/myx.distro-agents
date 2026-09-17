#!/usr/bin/env awk

# Reads one JSON object (stdin) and prints the scalar value at one exact
# dot-separated key path (`-v path=...`). Provider-neutral: the harness core and
# every wire adapter read their responses through it. Same recursive-descent
# engine as AgentsSlackJsonField.awk beside it, with names brought to this
# package's own two-word convention; unlike that reader there is no top-level
# `ok` gate, because these responses carry no such key.
#
# rc 0 found (value on stdout) -- rc 3 parsed, path absent -- rc 1 not a
# parseable JSON object -- rc 2 usage error (no path given).
#
# `-v optional=1` suppresses the rc-3 note. `-v sentinel=1` emits `<value>X` so
# a free-text leaf's own trailing newlines survive `$( ... )`; the caller strips
# the one trailing `X`. An array also emits `<path>.__count`, empty or not.
#
# LC_ALL=C IS REQUIRED -- the walk indexes a byte array from split(s, sc, "").

BEGIN {
	wantPath = path
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

## -1 for anything that is not exactly four hex digits. A non-hex digit scored
## index()-1 == -1 and produced a NEGATIVE code point, which sprintf("%c", ...)
## renders differently on each awk -- one of them a value-truncating NUL.
function hex2dec(hexText,   hexIndex, hexChar, hexVal, hexAcc) {
	if (length(hexText) != 4) return -1
	hexAcc = 0
	for (hexIndex = 1; hexIndex <= length(hexText); hexIndex++) {
		hexChar = tolower(substr(hexText, hexIndex, 1))
		hexVal = index("0123456789abcdef", hexChar) - 1
		if (hexVal < 0) return -1
		hexAcc = hexAcc * 16 + hexVal
	}
	return hexAcc
}

function utf8enc(codePoint,   byteOne, byteTwo, byteThree, byteFour) {
	if (codePoint < 128) {
		return sprintf("%c", codePoint)
	} else if (codePoint < 2048) {
		byteOne = 192 + int(codePoint / 64)
		byteTwo = 128 + (codePoint % 64)
		return sprintf("%c%c", byteOne, byteTwo)
	} else if (codePoint < 65536) {
		byteOne = 224 + int(codePoint / 4096)
		byteTwo = 128 + int(codePoint / 64) % 64
		byteThree = 128 + (codePoint % 64)
		return sprintf("%c%c%c", byteOne, byteTwo, byteThree)
	} else {
		byteOne = 240 + int(codePoint / 262144)
		byteTwo = 128 + int(codePoint / 4096) % 64
		byteThree = 128 + int(codePoint / 64) % 64
		byteFour = 128 + (codePoint % 64)
		return sprintf("%c%c%c%c", byteOne, byteTwo, byteThree, byteFour)
	}
}

function parseString(   curChar, outText, hexText, codeVal, hexTwo, codeTwo, codePoint, isClosed) {
	scanPos++
	outText = ""
	isClosed = 0
	while (scanPos <= scanLen) {
		curChar = scanChars[scanPos]
		if (curChar == "\"") { scanPos++; isClosed = 1; break; }
		if (curChar == "\\") {
			scanPos++
			curChar = scanChars[scanPos]
			if (curChar == "\"") outText = outText "\""
			else if (curChar == "\\") outText = outText "\\"
			else if (curChar == "/") outText = outText "/"
			else if (curChar == "b") outText = outText "\b"
			else if (curChar == "f") outText = outText "\f"
			else if (curChar == "n") outText = outText "\n"
			else if (curChar == "r") outText = outText "\r"
			else if (curChar == "t") outText = outText "\t"
			else if (curChar == "u") {
				hexText = scanChars[scanPos+1] scanChars[scanPos+2] scanChars[scanPos+3] scanChars[scanPos+4]
				codeVal = hex2dec(hexText)
				scanPos += 4
				## Malformed \u: rejected rather than rendered as an awk-dependent byte.
				if (codeVal < 0) { structErr = 1; return outText; }
				if (codeVal >= 55296 && codeVal <= 56319 && (scanChars[scanPos+1] scanChars[scanPos+2]) == "\\u") {
					hexTwo = scanChars[scanPos+3] scanChars[scanPos+4] scanChars[scanPos+5] scanChars[scanPos+6]
					codeTwo = hex2dec(hexTwo)
					if (codeTwo >= 56320 && codeTwo <= 57343) {
						codePoint = 65536 + (codeVal - 55296) * 1024 + (codeTwo - 56320)
						outText = outText utf8enc(codePoint)
						scanPos += 6
					} else {
						outText = outText utf8enc(codeVal)
					}
				} else {
					outText = outText utf8enc(codeVal)
				}
			}
			else outText = outText curChar
			scanPos++
		} else {
			outText = outText curChar
			scanPos++
		}
	}
	if (!isClosed) structErr = 1
	return outText
}

function emitLeaf(leafPath, rawText, leafValue) {
	if (leafPath != wantPath) return
	if (foundCount == 0) foundValue = leafValue
	foundCount++
}

function parseValue(nodePath,   curChar, startPos, leafValue, rawText, rawPos) {
	skipws()
	curChar = scanChars[scanPos]
	if (curChar == "\"") {
		leafValue = parseString()
		emitLeaf(nodePath, "", leafValue)
	} else if (curChar == "{") {
		parseObject(nodePath)
	} else if (curChar == "[") {
		parseArray(nodePath)
	} else if (curChar == "t") {
		scanPos += 4
		emitLeaf(nodePath, "true", "true")
	} else if (curChar == "f") {
		scanPos += 5
		emitLeaf(nodePath, "false", "false")
	} else if (curChar == "n") {
		scanPos += 4
		emitLeaf(nodePath, "null", "")
	} else {
		startPos = scanPos
		while (scanPos <= scanLen) {
			curChar = scanChars[scanPos]
			if (curChar == "-" || curChar == "+" || curChar == "." || curChar == "e" || curChar == "E" || (curChar >= "0" && curChar <= "9")) scanPos++
			else break
		}
		## A zero-length run cannot begin a value, so `{"a":}` is rc 1 not rc 0.
		if (scanPos == startPos) { structErr = 1; return; }
		rawText = ""
		for (rawPos = startPos; rawPos < scanPos; rawPos++) rawText = rawText scanChars[rawPos]
		emitLeaf(nodePath, rawText, rawText)
	}
}

function parseObject(nodePath,   keyName, keyPath, curChar) {
	scanPos++
	skipws()
	if (scanChars[scanPos] == "}") { scanPos++; return; }
	while (1) {
		skipws()
		keyName = parseString()
		skipws()
		## The separator is required: consuming it blindly read `{"a" 1}` as rc 0.
		if (scanChars[scanPos] != ":") { structErr = 1; return; }
		scanPos++
		keyPath = (nodePath == "") ? keyName : nodePath "." keyName
		parseValue(keyPath)
		skipws()
		curChar = scanChars[scanPos]
		if (curChar == ",") { scanPos++; continue; }
		else if (curChar == "}") { scanPos++; break; }
		else { structErr = 1; break; }
	}
}

function parseArray(nodePath,   itemIndex, curChar) {
	scanPos++
	skipws()
	itemIndex = 0
	if (scanChars[scanPos] == "]") { scanPos++; emitLeaf(nodePath ".__count", itemIndex, itemIndex); return; }
	while (1) {
		parseValue(nodePath "." itemIndex)
		itemIndex++
		skipws()
		curChar = scanChars[scanPos]
		if (curChar == ",") { scanPos++; continue; }
		else if (curChar == "]") { scanPos++; break; }
		else { structErr = 1; break; }
	}
	emitLeaf(nodePath ".__count", itemIndex, itemIndex)
}

{
	if (inputSeen) inputText = inputText "\n" $0
	else inputText = $0
	inputSeen = 1
}

END {
	if (wantPath == "") {
		printf("⛔ ERROR: AgentsHarnessJsonField.awk: no key path given -- pass one as `-v path=choices.0.message.content`\n") > "/dev/stderr"
		exit 2
	}

	scanLen = split(inputText, scanChars, "")
	scanPos = 1

	skipws()
	if (scanPos > scanLen || scanChars[scanPos] != "{") {
		printf("⛔ ERROR: AgentsHarnessJsonField.awk: input is not a JSON object -- an empty read, an HTML error page, or a transport diagnostic captured in place of a response body (wanted path `%s`)\n", wantPath) > "/dev/stderr"
		exit 1
	}

	parseValue("")
	skipws()

	if (structErr || scanPos <= scanLen) {
		printf("⛔ ERROR: AgentsHarnessJsonField.awk: input did not parse as one complete JSON object -- truncated body or trailing garbage (wanted path `%s`)\n", wantPath) > "/dev/stderr"
		exit 1
	}

	if (foundCount > 1) {
		printf("# AgentsHarnessJsonField.awk: path `%s` occurred %d times at that exact full path (duplicate key in one object, malformed JSON) -- reporting the first\n", wantPath, foundCount) > "/dev/stderr"
	}

	if (foundCount == 0) {
		if (optional != "1") {
			printf("# AgentsHarnessJsonField.awk: path `%s` is absent from this response (rc 3) -- not an empty value, not present\n", wantPath) > "/dev/stderr"
		}
		exit 3
	}

	if (sentinel == "1") {
		printf("%sX", foundValue)
	} else {
		print foundValue
	}
	exit 0
}
