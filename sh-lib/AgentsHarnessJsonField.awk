#!/usr/bin/env awk

# THE JSON reader of this package: one linear walk behind every mode, every
# dialect and every library entry. No other file here tokenizes JSON for reading.
#
# Field mode (default): the decoded scalar at one exact dot path, `-v path=a.0.b`.
# An array also yields `<path>.__count`, empty or not. rc 0 found (value on stdout)
# -- rc 3 parsed, path absent -- rc 1 not a parseable JSON object -- rc 2 usage.
# `-v optional=1` hushes the rc-3 note. `-v sentinel=1` prints `<value>X` so a free
# text leaf's own trailing newlines survive `$( ... )`; the caller strips the `X`.
# A duplicate path reports its first value, with a note.
#
# `-v mode=raw` prints the value at `path` as its own source bytes (a string keeps
# its quotes and escapes); `-v mode=keys` prints the child key names of the object
# at `path`, undecoded, one per line. Both rc 0/1/3/2 as above, rc 3 silent.
#
# `-v mode=records -v array=<path> -v want=<csv>` prints one TAB-separated row per
# element of that array, fields in `want` order, empty where an element lacks one.
#
# `-v dialect=slack|atlassian` selects the grammar those APIs' readers have always
# parsed with, byte for byte (sh-test/AgentsJsonEngineDiffCheck.test.sh holds each
# to its previous file): a malformed \u decodes rather than fails, the `:` is not
# checked, an empty value is "", a fault does not stop the walk, no `__count`.
#   slack      field: a top-level `ok` leaf is required (rc 1 without one).
#              records: one page per input line (`## ` lines skipped); ok:false
#              is refused; a cell's TAB/CR/LF become spaces.
#   atlassian  `-v raw=1` (field) or `-v raw=<csv of want names>` (records) reads an
#              object/array value as its bracket-balanced source bytes. records:
#              rc 3 when the array is absent; a cell's \ TAB CR LF are escaped.
#
# Library: set `jfLibrary = 1` in a later -f file's BEGIN -- no input is read and
# END does nothing. `jfLax = 1` there selects the lax grammar for jfWalkText.
#   jfParseText(text)       0 parsed, 1 not an object, 2 fault; jfLeaf[path] holds
#                           the first value of every leaf, jfLeafSeen[path] presence.
#   jfSliceText(text, path, mode)   mode raw|keys as above; 0 found (jfSliceValue),
#                           1 not one object, 3 absent. jfLeaf is left untouched.
#   jfWalkText(text)        every node in document order, a container after its
#                           children: jfNodeN, jfNodePath/Type/Value/From/To[i], type
#                           s n t f z (null) or { [ (value: member/item count);
#                           jfNodeRaw(i) its source as the old readers spelled it;
#                           jfRootChar the first non-blank byte. Never stops early.
#
# LINEAR, AND THE WAY IT GETS THERE IS LOAD-BEARING. This awk's substr(), index()
# and length() each cost the length of the WHOLE string they are given, and a
# string grown one byte at a time is copied once per byte. So the input is held
# as a table of chunks of at most jfChunkCap bytes, a string's unescaped runs are
# found with index() inside one chunk and copied whole, and a value is built only
# where its path can still be the one asked for. The walk still runs to the end:
# a fault after the value is still rc 1. Quirks every caller was built on are
# kept: a string's opening byte is skipped unseen, `t`/`f`/`n` skip 4/5/4 bytes.
#
# LC_ALL=C IS REQUIRED -- every offset here is a byte offset.

BEGIN {
	jfWant = path
	jfMode = mode
	jfDialect = dialect
	jfChunkCap = 256
	jfCollectAll = 0
	jfOrdered = 0
	jfLax = (dialect == "slack" || dialect == "atlassian")
	jfCounts = !jfLax
	jfNeedOk = (dialect == "slack" && mode == "")
	jfSliceGrammar = (mode == "raw" || mode == "keys")
	jfSliceRawOn = (mode == "raw")
	jfKeysOn = (mode == "keys")
	jfRecords = (mode == "records")
	jfBalancedOn = (dialect == "atlassian" && ((mode == "" && raw == "1") || (jfRecords && raw != "")))
	jfAllLive = jfRecords
	jfReset()
	if (jfRecords) jfRecordsInit()
}

function jfReset() {
	delete jfK
	delete jfCs
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
	jfOkSeen = 0
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

## Parts joined pairwise, so neither many short pieces nor one long one copy the
## result over and over.
function jfJoin(joinPart, joinCount,   joinAt) {
	if (joinCount == 0) return ""
	while (joinCount > 1) {
		for (joinAt = 1; 2 * joinAt <= joinCount; joinAt++) joinPart[joinAt] = joinPart[2 * joinAt - 1] joinPart[2 * joinAt]
		if (joinCount % 2) joinPart[joinAt] = joinPart[joinCount]
		joinCount = int((joinCount + 1) / 2)
	}
	return joinPart[1]
}

## A value is assembled in parts of about 1 KiB.
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

function jfBufJoin() {
	if (jfBufN == 0) return jfBufAcc
	jfBufN++
	jfBufPart[jfBufN] = jfBufAcc
	jfBufAcc = jfJoin(jfBufPart, jfBufN)
	jfBufN = 0
	return jfBufAcc
}

## The source bytes [fromPos, toPos) -- clamped to the input, as substr() was.
function jfSlice(fromPos, toPos,   chunkAt, lowAt, highAt, cutFrom, cutTo, sliceN) {
	if (toPos > jfTotal + 1) toPos = jfTotal + 1
	if (fromPos < 1) fromPos = 1
	if (fromPos >= toPos) return ""
	lowAt = 1
	highAt = jfM
	while (lowAt < highAt) {
		chunkAt = int((lowAt + highAt + 1) / 2)
		if (jfCs[chunkAt] <= fromPos) lowAt = chunkAt
		else highAt = chunkAt - 1
	}
	sliceN = 0
	for (chunkAt = lowAt; chunkAt <= jfM && jfCs[chunkAt] < toPos; chunkAt++) {
		cutFrom = (fromPos > jfCs[chunkAt]) ? fromPos : jfCs[chunkAt]
		cutTo = (toPos < jfCs[chunkAt + 1]) ? toPos : jfCs[chunkAt + 1]
		jfSlicePart[++sliceN] = substr(jfK[chunkAt], cutFrom - jfCs[chunkAt] + 1, cutTo - cutFrom)
	}
	return jfJoin(jfSlicePart, sliceN)
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

## Strict: -1 for anything that is not exactly four hex digits (a negative code
## point renders differently on each awk). Lax: every digit counts, a non-hex one
## as -1, exactly as the lax readers always decoded it.
function jfHex2Dec(hexText,   hexIndex, hexVal, hexAcc) {
	if (length(hexText) != 4 && !jfLax) return -1
	hexAcc = 0
	for (hexIndex = 1; hexIndex <= length(hexText); hexIndex++) {
		hexVal = index("0123456789abcdef", tolower(substr(hexText, hexIndex, 1))) - 1
		if (hexVal < 0 && !jfLax) return -1
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

## Advances past one string -- its first byte skipped unseen -- leaving its text
## in jfStr when isBuilt (what was read so far, if it never closed). Decoded, or
## in the slice grammar its source bytes, escapes and all, with nothing checked.
function jfParseString(isBuilt,   restText, quoteAt, slashAt, escAt, escChar, hexText, codeVal, hexTwo, codeTwo) {
	jfPos++
	jfStr = ""
	if (isBuilt) jfBufReset()
	while (1) {
		jfSeek()
		if (jfKc > jfM) {
			if (isBuilt) jfStr = jfBufJoin()
			jfStructErr = 1
			return
		}
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
		if (jfSliceGrammar) {
			if (isBuilt) jfBufAdd("\\" escChar)
		} else if (escChar == "u") {
			hexText = jfPeek(escAt + 2) jfPeek(escAt + 3) jfPeek(escAt + 4) jfPeek(escAt + 5)
			codeVal = jfHex2Dec(hexText)
			## Malformed \u: rejected rather than rendered as an awk-dependent byte.
			if (codeVal < 0 && !jfLax) { jfStructErr = 1 ; return ; }
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

## One leaf, to whichever consumer this run has.
function jfEmit(leafPath, leafValue, leafType, fromPos) {
	if (jfSliceGrammar) return
	if (jfOrdered) { jfNodeAdd(leafPath, leafType, leafValue, fromPos) ; return ; }
	if (jfRecords) { jfRecordLeaf(leafPath, leafValue) ; return ; }
	if (jfCollectAll) {
		if (!(leafPath in jfLeafSeen)) {
			jfLeafSeen[leafPath] = 1
			jfLeaf[leafPath] = leafValue
		}
		return
	}
	if (jfNeedOk && leafPath == "ok") jfOkSeen = 1
	if (leafPath != jfWant) return
	if (jfFoundCount == 0) jfFoundValue = leafValue
	jfFoundCount++
}

function jfNodeAdd(nodePath, nodeType, nodeValue, fromPos) {
	jfNodeN++
	jfNodePath[jfNodeN] = nodePath
	jfNodeType[jfNodeN] = nodeType
	jfNodeValue[jfNodeN] = nodeValue
	jfNodeFrom[jfNodeN] = fromPos
	jfNodeTo[jfNodeN] = jfPos
}

function jfContainerDone(nodePath, nodeType, itemCount, fromPos) {
	if (jfOrdered) jfNodeAdd(nodePath, nodeType, itemCount, fromPos)
	else if (nodeType == "[" && jfCounts) jfEmit(nodePath ".__count", itemCount, "n", fromPos)
}

## Whether anything at or under childPath can still be the path asked for. Only an
## empty path has descendants that do not start with its own text plus a dot.
function jfLive(childPath) {
	return jfAllLive || childPath == "" || childPath == jfWant || index(jfWant, childPath ".") == 1 || (jfNeedOk && childPath == "ok")
}

## Atlassian raw capture: past one bracket-balanced {...} or [...], strings
## skipped whole so a bracket inside one never counts.
function jfSkipBalanced(   nestDepth, restText, curChar) {
	nestDepth = 0
	while (1) {
		jfSeek()
		if (jfKc > jfM) break
		restText = jfRest()
		if (!match(restText, /[][{}"]/)) { jfPos += length(restText) ; continue ; }
		jfPos += RSTART - 1
		curChar = substr(restText, RSTART, 1)
		if (curChar == "\"") { jfParseString(0) ; continue ; }
		jfPos++
		if (curChar == "{" || curChar == "[") nestDepth++
		else if (--nestDepth <= 0) return
	}
	jfStructErr = 1
}

function jfIsBalanced(nodePath) {
	if (jfRecords) return jfRecFieldAt(nodePath) in jfRecRawAt
	return nodePath == jfWant
}

function jfParseValue(nodePath, isLive,   curChar, startPos, restText, runText) {
	jfSkipWs()
	startPos = jfPos
	curChar = jfCur()
	if (jfRecords && curChar == "[" && nodePath == jfRecArray) jfArraySeen = 1
	if (jfBalancedOn && isLive && (curChar == "{" || curChar == "[") && jfIsBalanced(nodePath)) {
		jfSkipBalanced()
		jfEmit(nodePath, jfSlice(startPos, jfPos), "r", startPos)
		return
	}
	if (curChar == "\"") {
		jfParseString(isLive && !jfSliceGrammar && (jfAllLive || nodePath == jfWant))
		if (jfStructErr && !jfLax) return
		if (isLive) jfEmit(nodePath, jfStr, "s", startPos)
	} else if (curChar == "{") {
		jfParseObject(nodePath, isLive)
		if (jfStructErr && !jfLax) return
	} else if (curChar == "[") {
		jfParseArray(nodePath, isLive)
		if (jfStructErr && !jfLax) return
	} else if (jfSliceGrammar) {
		## Anything up to a delimiter is one value here, as the slice reader took it.
		while (1) {
			jfSeek()
			if (jfKc > jfM) break
			restText = jfRest()
			if (!match(restText, /^[^],} \t\n\r]+/)) break
			jfPos += RLENGTH
			if (RLENGTH < length(restText)) break
		}
		if (jfPos == startPos) { jfStructErr = 1 ; return ; }
	} else if (curChar == "t") {
		jfPos += 4
		if (isLive) jfEmit(nodePath, "true", "t", startPos)
	} else if (curChar == "f") {
		jfPos += 5
		if (isLive) jfEmit(nodePath, "false", "f", startPos)
	} else if (curChar == "n") {
		jfPos += 4
		if (isLive) jfEmit(nodePath, "", "z", startPos)
	} else {
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
		if (jfPos == startPos && !jfLax) { jfStructErr = 1 ; return ; }
		runText = jfBufJoin()
		if (isLive) jfEmit(nodePath, runText, "n", startPos)
	}
	if (jfSliceRawOn && isLive && nodePath == jfWant) {
		if (jfFoundCount == 0) jfFoundValue = jfSlice(startPos, jfPos)
		jfFoundCount++
	}
}

function jfParseObject(nodePath, isLive,   keyPath, curChar, startPos, isKeys, memberCount) {
	startPos = jfPos
	isKeys = (jfKeysOn && isLive && nodePath == jfWant)
	if (isKeys) jfFoundCount++
	memberCount = 0
	jfPos++
	jfSkipWs()
	if (jfCur() == "}") {
		jfPos++
		if (isLive) jfContainerDone(nodePath, "{", 0, startPos)
		return
	}
	while (1) {
		jfSkipWs()
		## The slice grammar wants a key to BE a string; the others skip its first byte.
		if (jfSliceGrammar && jfCur() != "\"") { jfStructErr = 1 ; return ; }
		jfParseString(isLive)
		if (jfStructErr && !jfLax) return
		if (isKeys && jfFoundCount == 1) jfFoundValue = jfFoundValue jfStr "\n"
		jfSkipWs()
		## The separator is required: consuming it blindly read `{"a" 1}` as rc 0.
		if (jfCur() != ":" && !jfLax) { jfStructErr = 1 ; return ; }
		jfPos++
		if (isLive) {
			keyPath = (nodePath == "") ? jfStr : nodePath "." jfStr
			jfParseValue(keyPath, jfLive(keyPath))
		} else {
			jfParseValue("", 0)
		}
		memberCount++
		if (jfStructErr && !jfLax) return
		jfSkipWs()
		curChar = jfCur()
		if (curChar == ",") { jfPos++ ; continue ; }
		if (curChar == "}") { jfPos++ ; break ; }
		jfStructErr = 1
		if (!jfLax) return
		break
	}
	if (isLive) jfContainerDone(nodePath, "{", memberCount, startPos)
}

function jfParseArray(nodePath, isLive,   itemIndex, itemPath, curChar, startPos) {
	startPos = jfPos
	jfPos++
	jfSkipWs()
	itemIndex = 0
	if (jfCur() == "]") {
		jfPos++
		if (isLive) jfContainerDone(nodePath, "[", 0, startPos)
		return
	}
	while (1) {
		if (isLive) {
			itemPath = nodePath "." itemIndex
			jfParseValue(itemPath, jfLive(itemPath))
		} else {
			jfParseValue("", 0)
		}
		if (jfStructErr && !jfLax) return
		itemIndex++
		jfSkipWs()
		curChar = jfCur()
		if (curChar == ",") { jfPos++ ; continue ; }
		if (curChar == "]") { jfPos++ ; break ; }
		jfStructErr = 1
		if (!jfLax) return
		break
	}
	if (isLive) jfContainerDone(nodePath, "[", itemIndex, startPos)
}

function jfStart() {
	jfPos = 1
	jfKc = 1
	jfLoad()
	jfSkipWs()
	jfRootChar = jfCur()
}

## 0 parsed, 1 not a JSON object at all, 2 a fault inside or after it.
function jfParseDocument() {
	jfStart()
	if (jfPos > jfTotal || jfRootChar != "{") return 1
	jfParseValue("", 1)
	if (jfStructErr) return 2
	jfSkipWs()
	if (jfPos <= jfTotal) return 2
	return 0
}

## Library entry: every leaf of one document into jfLeaf / jfLeafSeen.
function jfParseText(text) {
	jfReset()
	delete jfLeaf
	delete jfLeafSeen
	jfCollectAll = 1
	jfAllLive = 1
	jfOrdered = 0
	jfRecords = 0
	jfNeedOk = 0
	jfBalancedOn = 0
	jfSliceGrammar = 0
	jfAppend(text, length(text))
	return jfParseDocument()
}

## Library entry: mode raw|keys on one document. jfLeaf is not touched.
function jfSliceText(text, slicePath, sliceMode,   sliceRc, savedLax) {
	savedLax = jfLax
	jfReset()
	jfWant = slicePath
	jfLax = 0
	jfCollectAll = 0
	jfAllLive = 0
	jfOrdered = 0
	jfRecords = 0
	jfNeedOk = 0
	jfBalancedOn = 0
	jfSliceGrammar = 1
	jfSliceRawOn = (sliceMode == "raw")
	jfKeysOn = (sliceMode == "keys")
	jfAppend(text, length(text))
	sliceRc = jfParseDocument()
	jfSliceGrammar = 0
	jfSliceRawOn = 0
	jfKeysOn = 0
	jfLax = savedLax
	if (sliceRc != 0) return 1
	if (jfFoundCount == 0) return 3
	jfSliceValue = jfFoundValue
	return 0
}

## Library entry: every node, in order, whatever the document holds after it.
## 0 one clean value with nothing after it, 2 otherwise.
function jfWalkText(text) {
	jfReset()
	jfNodeN = 0
	jfCollectAll = 0
	jfAllLive = 1
	jfOrdered = 1
	jfRecords = 0
	jfNeedOk = 0
	jfBalancedOn = 0
	jfSliceGrammar = 0
	jfAppend(text, length(text))
	jfStart()
	jfParseValue("", 1)
	if (jfStructErr) return 2
	jfSkipWs()
	return (jfPos <= jfTotal) ? 2 : 0
}

## A node's source as the per-file readers spelled it: a string with its quotes,
## a literal by its name whatever followed its first byte.
function jfNodeRaw(nodeAt,   nodeType) {
	nodeType = jfNodeType[nodeAt]
	if (nodeType == "t") return "true"
	if (nodeType == "f") return "false"
	if (nodeType == "z") return "null"
	if (nodeType == "n") return jfNodeValue[nodeAt]
	return jfSlice(jfNodeFrom[nodeAt], jfNodeTo[nodeAt])
}

## ---- records ------------------------------------------------------------------
function jfRecordsInit(   csvAt, csvCount, csvName) {
	jfRecArray = array
	if (array == "" || want == "") {
		printf("⛔ ERROR: AgentsHarnessJsonField.awk: -v array=<name> and -v want=<csv> are both required\n") > "/dev/stderr"
		jfUsageBad = 1
		exit 2
	}
	jfRecWantCount = split(want, csvName, ",")
	for (csvAt = 1; csvAt <= jfRecWantCount; csvAt++) jfRecWantAt[csvName[csvAt]] = csvAt
	if (jfDialect == "atlassian" && raw != "") {
		csvCount = split(raw, csvName, ",")
		for (csvAt = 1; csvAt <= csvCount; csvAt++) jfRecRawAt[csvName[csvAt]] = 1
	}
	jfRecPrefix = array "."
	jfRecPrefixLen = length(jfRecPrefix)
	jfRecMax = -1
	jfRecBase = 0
	jfApiOk = "true"
	jfApiOkSeen = 0
	jfApiError = ""
	jfRootSeen = 0
	jfArraySeen = 0
}

## The field name a path resolves to under the wanted array, or "" if this path is
## not a direct element of it (wrong prefix, or not `array.<idx>.*`).
function jfRecFieldAt(leafPath,   restText, itemIdx) {
	if (index(leafPath, jfRecPrefix) != 1) return ""
	restText = substr(leafPath, jfRecPrefixLen + 1)
	itemIdx = restText
	sub(/\..*/, "", itemIdx)
	if (itemIdx !~ /^[0-9]+$/) return ""
	if (index(restText, itemIdx ".") != 1) return ""
	return substr(restText, length(itemIdx) + 2)
}

## Last value wins per cell. The index stays a STRING in the atlassian dialect, as
## it always was -- so its row loop compares as strings (rows past index 89 of a
## longer array are not printed); slack pages are offset numerically.
function jfRecordLeaf(leafPath, leafValue,   restText, itemIdx, fieldName) {
	if (jfDialect == "slack") {
		if (leafPath == "ok") { jfApiOk = leafValue ; jfApiOkSeen = 1 ; return ; }
		if (leafPath == "error") { jfApiError = leafValue ; return ; }
	}
	if (index(leafPath, jfRecPrefix) != 1) return
	restText = substr(leafPath, jfRecPrefixLen + 1)
	itemIdx = restText
	sub(/\..*/, "", itemIdx)
	if (itemIdx !~ /^[0-9]+$/) return
	if (index(restText, itemIdx ".") != 1) return
	fieldName = substr(restText, length(itemIdx) + 2)
	if (!(fieldName in jfRecWantAt)) return
	if (jfDialect == "slack") {
		itemIdx = jfRecBase + itemIdx
		gsub(/[\n\r\t]/, " ", leafValue)
	} else {
		gsub(/\\/, "\\\\", leafValue)
		gsub(/\t/, "\\t", leafValue)
		gsub(/\r/, "\\r", leafValue)
		gsub(/\n/, "\\n", leafValue)
	}
	if (itemIdx > jfRecMax) jfRecMax = itemIdx
	jfRecSeen[itemIdx] = 1
	jfRecCell[itemIdx SUBSEP jfRecWantAt[fieldName]] = leafValue
}

function jfRecordsPrint(   rowAt, colAt, rowText) {
	for (rowAt = 0; rowAt <= jfRecMax; rowAt++) {
		if (!(rowAt in jfRecSeen)) continue
		rowText = ""
		for (colAt = 1; colAt <= jfRecWantCount; colAt++) {
			rowText = rowText (colAt == 1 ? "" : "\t") ((rowAt SUBSEP colAt) in jfRecCell ? jfRecCell[rowAt SUBSEP colAt] : "")
		}
		printf("%s\n", rowText)
	}
}

## Slack pages arrive one per line, each walked on its own.
!jfLibrary && jfRecords && jfDialect == "slack" {
	if (/^## /) next
	jfRecBase = jfRecMax + 1
	jfReset()
	jfAppend($0, length($0))
	jfStart()
	if (jfRootChar == "{" || jfRootChar == "[") jfRootSeen = 1
	jfParseValue("", 1)
	next
}

!jfLibrary {
	if (jfLineSeen) jfAppend("\n" $0, length($0) + 1)
	else jfAppend($0, length($0))
	jfLineSeen = 1
}

END {
	if (!jfLibrary) {
		if (jfRecords) {
			if (jfUsageBad) exit 2
			if (jfDialect == "slack") {
				if (!jfRootSeen) {
					printf("⛔ ERROR: AgentsHarnessJsonField.awk: the %s response was not JSON -- treat as NOT ENUMERATED, never as empty\n", jfRecArray) > "/dev/stderr"
					exit 1
				}
				if (jfApiOkSeen && jfApiOk == "false") {
					printf("⛔ ERROR: AgentsHarnessJsonField.awk: Slack API call failed: ok:false%s -- treat as NOT ENUMERATED, never as empty\n", (jfApiError != "" ? " error=" jfApiError : "")) > "/dev/stderr"
					exit 1
				}
				jfRecordsPrint()
				exit 0
			}
			jfDocRc = jfParseDocument()
			if (jfDocRc == 1) {
				printf("⛔ ERROR: AgentsHarnessJsonField.awk: input is not a JSON object -- an empty read, an HTML error page, or a transport diagnostic captured in place of a response body (wanted array `%s`)\n", jfRecArray) > "/dev/stderr"
				exit 1
			}
			if (jfDocRc == 2) {
				printf("⛔ ERROR: AgentsHarnessJsonField.awk: input did not parse as one complete JSON object -- truncated body or trailing garbage (wanted array `%s`)\n", jfRecArray) > "/dev/stderr"
				exit 1
			}
			if (!jfArraySeen) {
				printf("⛔ ERROR: AgentsHarnessJsonField.awk: no `%s` array in this response -- the result set is UNKNOWN, not empty. A real, empty `[]` sets this flag; only a missing or wrongly-typed field does not\n", jfRecArray) > "/dev/stderr"
				exit 3
			}
			jfRecordsPrint()
			exit 0
		}

		if (jfSliceGrammar || jfMode != "") {
			if (jfWant == "" || !jfSliceGrammar) {
				printf("⛔ ERROR: AgentsHarnessJsonField.awk: pass both `-v path=...` and one of `-v mode=raw` or `-v mode=keys`\n") > "/dev/stderr"
				exit 2
			}
			jfDocRc = jfParseDocument()
			if (jfDocRc == 1) {
				printf("⛔ ERROR: AgentsHarnessJsonField.awk: input is not a JSON object -- an empty read, a diagnostic captured in place of a document, or a line that is not one (wanted path `%s`)\n", jfWant) > "/dev/stderr"
				exit 1
			}
			if (jfDocRc == 2) {
				printf("⛔ ERROR: AgentsHarnessJsonField.awk: input did not parse as one complete JSON object -- truncated body or trailing garbage (wanted path `%s`)\n", jfWant) > "/dev/stderr"
				exit 1
			}
			if (jfFoundCount == 0) exit 3
			if (jfKeysOn) printf("%s", jfFoundValue)
			else printf("%s\n", jfFoundValue)
			exit 0
		}

		if (jfWant == "") {
			printf("⛔ ERROR: AgentsHarnessJsonField.awk: no key path given -- pass one as `-v path=%s`\n", (jfDialect == "slack") ? "channel.id" : (jfDialect == "atlassian") ? "isLast" : "choices.0.message.content") > "/dev/stderr"
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

		## Every Slack Web API response carries a top-level `ok`: without it this is
		## some other JSON, and its missing field is not an answer.
		if (jfNeedOk && !jfOkSeen) {
			printf("⛔ ERROR: AgentsHarnessJsonField.awk: parsed JSON carries no top-level `ok` key -- not a Slack API response (wanted path `%s`)\n", jfWant) > "/dev/stderr"
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
