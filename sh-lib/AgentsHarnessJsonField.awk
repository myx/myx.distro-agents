#!/usr/bin/env awk

# Reads one JSON object (stdin) and prints the scalar value at one exact
# dot-separated key path (`-v path=...`). Provider-neutral: the harness core and
# every wire adapter read their responses through it. Same recursive-descent
# grammar as AgentsSlackJsonField.awk beside it, with names brought to this
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
# LINEAR, AND THE WAY IT GETS THERE IS LOAD-BEARING. This awk's substr(), index()
# and length() each cost the length of the WHOLE string they are given, and a
# string grown one byte at a time is copied once per byte. So the input is held
# as a table of chunks of at most jfChunkCap bytes, a string's unescaped runs are
# found with index() inside one chunk and copied whole, and a value is built only
# where its path can still be the one asked for -- every other string is checked
# and skipped. The walk still runs to the end of the document: a fault after the
# value is still rc 1, and a duplicate is still reported, exactly as before.
# The grammar is unchanged byte for byte, quirks included (a string's opening
# byte is skipped unseen, `t`/`f`/`n` skip 4/5/4 bytes unread);
# sh-test/AgentsHarnessJsonFieldDiffCheck.test.sh holds it to the previous engine.
#
# `jfLibrary = 1` (set in a later -f file's BEGIN) makes this a library: no input
# is read and END does nothing, and jfParseText(text) fills jfLeaf[path] with the
# first value of every leaf, jfLeafSeen[path] marking presence -- the same answer
# this reader gives for each path, from one walk.
#
# LC_ALL=C IS REQUIRED -- every offset here is a byte offset.

BEGIN {
	jfWant = path
	jfChunkCap = 256
	jfCollectAll = 0
	jfReset()
}

function jfReset() {
	delete jfK
	delete jfCs
	delete jfLeaf
	delete jfLeafSeen
	jfM = 0
	jfTotal = 0
	jfCs[1] = 1
	jfKc = 1
	jfHi = 0
	jfPos = 1
	jfLineSeen = 0
	jfFoundCount = 0
	jfFoundValue = ""
	jfStructErr = 0
}

## Adds text to the end of the chunk table, halving until each chunk fits.
function jfAppend(text, textLen,   halfLen) {
	if (textLen <= 0) return
	if (textLen <= jfChunkCap) {
		jfM++
		jfK[jfM] = text
		jfCs[jfM] = jfTotal + 1
		jfTotal += textLen
		jfCs[jfM + 1] = jfTotal + 1
		return
	}
	halfLen = int(textLen / 2)
	jfAppend(substr(text, 1, halfLen), halfLen)
	jfAppend(substr(text, halfLen + 1), textLen - halfLen)
}

## The walk only moves forward, so the current chunk does too. Its text and
## bounds are held in scalars: an array subscript is a number formatted to a
## string on every access, and this runs once per token.
function jfSeek() {
	if (jfPos < jfHi) return
	while (jfKc <= jfM && jfPos >= jfCs[jfKc + 1]) jfKc++
	jfLoad()
}

function jfLoad() {
	if (jfKc > jfM) {
		jfLo = jfTotal + 1
		jfHi = 1e18
		jfText = ""
	} else {
		jfLo = jfCs[jfKc]
		jfHi = jfCs[jfKc + 1]
		jfText = jfK[jfKc]
	}
}

function jfCur() {
	if (jfPos >= jfHi) jfSeek()
	return substr(jfText, jfPos - jfLo + 1, 1)
}

## One byte at or ahead of the walk, without moving it; "" past the end.
function jfPeek(atPos,   chunkAt) {
	if (atPos < jfHi) return substr(jfText, atPos - jfLo + 1, 1)
	chunkAt = jfKc
	while (chunkAt <= jfM && atPos >= jfCs[chunkAt + 1]) chunkAt++
	if (chunkAt > jfM) return ""
	return substr(jfK[chunkAt], atPos - jfCs[chunkAt] + 1, 1)
}

## What is left of the current chunk from the walk on. Call jfSeek() first.
function jfRest(   restOff) {
	restOff = jfPos - jfLo + 1
	return (restOff == 1) ? jfText : substr(jfText, restOff)
}

## A value is assembled in parts of about 1 KiB, joined pairwise at the end, so
## neither many short runs nor one long one copy the value over and over.
function jfBufReset() {
	jfBufAcc = ""
	jfBufN = 0
}

function jfBufAdd(text) {
	jfBufAcc = jfBufAcc text
	if (length(jfBufAcc) > 1024) {
		jfBufN++
		jfBufPart[jfBufN] = jfBufAcc
		jfBufAcc = ""
	}
}

function jfBufJoin(   joinAt, joinCount) {
	if (jfBufN == 0) return jfBufAcc
	jfBufN++
	jfBufPart[jfBufN] = jfBufAcc
	joinCount = jfBufN
	while (joinCount > 1) {
		for (joinAt = 1; 2 * joinAt <= joinCount; joinAt++) jfBufPart[joinAt] = jfBufPart[2 * joinAt - 1] jfBufPart[2 * joinAt]
		if (joinCount % 2) jfBufPart[joinAt] = jfBufPart[joinCount]
		joinCount = int((joinCount + 1) / 2)
	}
	jfBufN = 0
	jfBufAcc = ""
	return jfBufPart[1]
}

function jfSkipWs(   restText, curChar) {
	## Most calls land on a non-blank byte, and answering those needs no copy.
	curChar = jfCur()
	if (curChar != " " && curChar != "\t" && curChar != "\n" && curChar != "\r") return
	while (1) {
		jfSeek()
		if (jfKc > jfM) return
		restText = jfRest()
		if (!match(restText, /^[ \t\n\r]+/)) return
		jfPos += RLENGTH
		if (RLENGTH < length(restText)) return
	}
}

## -1 for anything that is not exactly four hex digits. A non-hex digit scored
## index()-1 == -1 and produced a NEGATIVE code point, which sprintf("%c", ...)
## renders differently on each awk -- one of them a value-truncating NUL.
function jfHex2Dec(hexText,   hexIndex, hexChar, hexVal, hexAcc) {
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

function jfUtf8Enc(codePoint,   byteOne, byteTwo, byteThree, byteFour) {
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

## Advances past one string -- its first byte skipped unseen, as it always was --
## leaving the decoded text in jfStr when isBuilt, and "" otherwise. Every escape
## is still checked either way: a malformed \u is rc 1 whether or not it is wanted.
function jfParseString(isBuilt,   restText, quoteAt, slashAt, escAt, escChar, hexText, codeVal, hexTwo, codeTwo) {
	jfPos++
	jfStr = ""
	if (isBuilt) jfBufReset()
	while (1) {
		jfSeek()
		if (jfKc > jfM) { jfStructErr = 1 ; return ; }
		restText = jfRest()
		quoteAt = index(restText, "\"")
		slashAt = index(restText, "\\")
		if (quoteAt == 0 && slashAt == 0) {
			if (isBuilt) jfBufAdd(restText)
			jfPos += length(restText)
			continue
		}
		if (slashAt == 0 || (quoteAt > 0 && quoteAt < slashAt)) {
			if (isBuilt) {
				if (quoteAt > 1) jfBufAdd(substr(restText, 1, quoteAt - 1))
				jfStr = jfBufJoin()
			}
			jfPos += quoteAt
			return
		}
		if (isBuilt && slashAt > 1) jfBufAdd(substr(restText, 1, slashAt - 1))
		escAt = jfPos + slashAt - 1
		escChar = jfPeek(escAt + 1)
		jfPos = escAt + 2
		if (escChar == "u") {
			hexText = jfPeek(escAt + 2) jfPeek(escAt + 3) jfPeek(escAt + 4) jfPeek(escAt + 5)
			codeVal = jfHex2Dec(hexText)
			## Malformed \u: rejected rather than rendered as an awk-dependent byte.
			if (codeVal < 0) { jfStructErr = 1 ; return ; }
			jfPos = escAt + 6
			if (codeVal >= 55296 && codeVal <= 56319 && (jfPeek(escAt + 6) jfPeek(escAt + 7)) == "\\u") {
				hexTwo = jfPeek(escAt + 8) jfPeek(escAt + 9) jfPeek(escAt + 10) jfPeek(escAt + 11)
				codeTwo = jfHex2Dec(hexTwo)
				if (codeTwo >= 56320 && codeTwo <= 57343) {
					if (isBuilt) jfBufAdd(jfUtf8Enc(65536 + (codeVal - 55296) * 1024 + (codeTwo - 56320)))
					jfPos = escAt + 12
				} else if (isBuilt) {
					jfBufAdd(jfUtf8Enc(codeVal))
				}
			} else if (isBuilt) {
				jfBufAdd(jfUtf8Enc(codeVal))
			}
		} else if (isBuilt) {
			if (escChar == "b") jfBufAdd("\b")
			else if (escChar == "f") jfBufAdd("\f")
			else if (escChar == "n") jfBufAdd("\n")
			else if (escChar == "r") jfBufAdd("\r")
			else if (escChar == "t") jfBufAdd("\t")
			else jfBufAdd(escChar)
		}
	}
}

function jfEmit(leafPath, leafValue) {
	if (jfCollectAll) {
		if (!(leafPath in jfLeafSeen)) {
			jfLeafSeen[leafPath] = 1
			jfLeaf[leafPath] = leafValue
		}
		return
	}
	if (leafPath != jfWant) return
	if (jfFoundCount == 0) jfFoundValue = leafValue
	jfFoundCount++
}

## Whether anything at or under childPath can still be the path asked for. Only an
## empty path has descendants that do not start with its own text plus a dot.
function jfLive(childPath) {
	return jfCollectAll || childPath == "" || childPath == jfWant || index(jfWant, childPath ".") == 1
}

function jfParseValue(nodePath, isLive,   curChar, startPos, rawText, restText) {
	jfSkipWs()
	curChar = jfCur()
	if (curChar == "\"") {
		jfParseString(isLive && (jfCollectAll || nodePath == jfWant))
		if (jfStructErr) return
		if (isLive) jfEmit(nodePath, jfStr)
	} else if (curChar == "{") {
		jfParseObject(nodePath, isLive)
	} else if (curChar == "[") {
		jfParseArray(nodePath, isLive)
	} else if (curChar == "t") {
		jfPos += 4
		if (isLive) jfEmit(nodePath, "true")
	} else if (curChar == "f") {
		jfPos += 5
		if (isLive) jfEmit(nodePath, "false")
	} else if (curChar == "n") {
		jfPos += 4
		if (isLive) jfEmit(nodePath, "")
	} else {
		startPos = jfPos
		jfBufReset()
		while (1) {
			jfSeek()
			if (jfKc > jfM) break
			restText = jfRest()
			if (!match(restText, /^[-+.eE0-9]+/)) break
			if (isLive) jfBufAdd(substr(restText, 1, RLENGTH))
			jfPos += RLENGTH
			if (RLENGTH < length(restText)) break
		}
		## A zero-length run cannot begin a value, so `{"a":}` is rc 1 not rc 0.
		if (jfPos == startPos) { jfStructErr = 1 ; return ; }
		rawText = jfBufJoin()
		if (isLive) jfEmit(nodePath, rawText)
	}
}

function jfParseObject(nodePath, isLive,   keyPath, curChar) {
	jfPos++
	jfSkipWs()
	if (jfCur() == "}") { jfPos++ ; return ; }
	while (1) {
		jfSkipWs()
		jfParseString(isLive)
		if (jfStructErr) return
		jfSkipWs()
		## The separator is required: consuming it blindly read `{"a" 1}` as rc 0.
		if (jfCur() != ":") { jfStructErr = 1 ; return ; }
		jfPos++
		if (isLive) {
			keyPath = (nodePath == "") ? jfStr : nodePath "." jfStr
			jfParseValue(keyPath, jfLive(keyPath))
		} else {
			jfParseValue("", 0)
		}
		if (jfStructErr) return
		jfSkipWs()
		curChar = jfCur()
		if (curChar == ",") { jfPos++ ; continue ; }
		else if (curChar == "}") { jfPos++ ; break ; }
		else { jfStructErr = 1 ; return ; }
	}
}

function jfParseArray(nodePath, isLive,   itemIndex, itemPath, curChar) {
	jfPos++
	jfSkipWs()
	itemIndex = 0
	if (jfCur() == "]") {
		jfPos++
		if (isLive) jfEmit(nodePath ".__count", itemIndex)
		return
	}
	while (1) {
		if (isLive) {
			itemPath = nodePath "." itemIndex
			jfParseValue(itemPath, jfLive(itemPath))
		} else {
			jfParseValue("", 0)
		}
		if (jfStructErr) return
		itemIndex++
		jfSkipWs()
		curChar = jfCur()
		if (curChar == ",") { jfPos++ ; continue ; }
		else if (curChar == "]") { jfPos++ ; break ; }
		else { jfStructErr = 1 ; return ; }
	}
	if (isLive) jfEmit(nodePath ".__count", itemIndex)
}

## 0 parsed, 1 not a JSON object at all, 2 a fault inside or after it.
function jfParseDocument() {
	jfPos = 1
	jfKc = 1
	jfLoad()
	jfSkipWs()
	if (jfPos > jfTotal || jfCur() != "{") return 1
	jfParseValue("", 1)
	if (jfStructErr) return 2
	jfSkipWs()
	if (jfPos <= jfTotal) return 2
	return 0
}

## Library entry: every leaf of one document into jfLeaf / jfLeafSeen.
function jfParseText(text) {
	jfReset()
	jfCollectAll = 1
	jfAppend(text, length(text))
	return jfParseDocument()
}

!jfLibrary {
	if (jfLineSeen) jfAppend("\n" $0, length($0) + 1)
	else jfAppend($0, length($0))
	jfLineSeen = 1
}

END {
	if (!jfLibrary) {
		if (jfWant == "") {
			printf("⛔ ERROR: AgentsHarnessJsonField.awk: no key path given -- pass one as `-v path=choices.0.message.content`\n") > "/dev/stderr"
			exit 2
		}

		jfDocRc = jfParseDocument()

		if (jfDocRc == 1) {
			printf("⛔ ERROR: AgentsHarnessJsonField.awk: input is not a JSON object -- an empty read, an HTML error page, or a transport diagnostic captured in place of a response body (wanted path `%s`)\n", jfWant) > "/dev/stderr"
			exit 1
		}

		if (jfDocRc == 2) {
			printf("⛔ ERROR: AgentsHarnessJsonField.awk: input did not parse as one complete JSON object -- truncated body or trailing garbage (wanted path `%s`)\n", jfWant) > "/dev/stderr"
			exit 1
		}

		if (jfFoundCount > 1) {
			printf("# AgentsHarnessJsonField.awk: path `%s` occurred %d times at that exact full path (duplicate key in one object, malformed JSON) -- reporting the first\n", jfWant, jfFoundCount) > "/dev/stderr"
		}

		if (jfFoundCount == 0) {
			if (optional != "1") {
				printf("# AgentsHarnessJsonField.awk: path `%s` is absent from this response (rc 3) -- not an empty value, not present\n", jfWant) > "/dev/stderr"
			}
			exit 3
		}

		if (sentinel == "1") {
			printf("%sX", jfFoundValue)
		} else {
			print jfFoundValue
		}
		exit 0
	}
}
