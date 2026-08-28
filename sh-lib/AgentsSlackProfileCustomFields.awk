#!/usr/bin/env awk

# Joins a workspace's custom profile field DEFINITIONS with one account's
# VALUES in them, and prints one tab-separated record per field:
#
#     <id>\t<label>\t<value>\t<alt>
#
# Two files, in this order, both raw Slack response bodies:
#   1. team.profile.get   -- profile.fields is an ARRAY of {id,label,...}
#   2. users.profile.get  -- profile.fields is an OBJECT keyed by that id
#
# WHY A DEDICATED READER. AgentsSlackJsonField.awk answers ONE fully qualified
# path and cannot enumerate keys it was never told the names of. Custom field
# ids are workspace-defined -- the same "Title" label is a different Xf... id in
# each workspace -- so the key set is not knowable in advance and no fixed path
# reaches it. A different question from the one that file answers, not a
# shortcoming of it.
#
# IDS ARE UNIONED, not taken from either side alone. A definition with no value
# is a field this account left empty; a value whose definition is missing is a
# field defined after the definitions were fetched, or one this identity cannot
# see. Both are real states. An emitter iterating only the values would report
# an empty fields object as "no custom fields exist" -- a different and false
# claim.
#
# Order is the definition order the workspace itself returns, with any
# value-only ids appended: stable across runs, so two accounts diff without
# sorting.
#
# EXIT: 0 records printed (possibly zero -- an account may legitimately have
# filled none), 1 a body could not be scanned. Zero records is NOT an error and
# is never reported as one.
#
# Variable names are two-word camelCase throughout, per MAGIC.md: a bare `close`
# as a parameter is an awk parse error, and the diagnostic points at the wrong
# construct entirely.

function skipQuoted(jsonText, scanPos,   curChar) {
	# scanPos points at the opening quote; returns the index just past the close.
	scanPos++
	while (scanPos <= length(jsonText)) {
		curChar = substr(jsonText, scanPos, 1)
		if (curChar == "\\") { scanPos += 2 ; continue }
		if (curChar == "\"") { return scanPos + 1 }
		scanPos++
	}
	return 0
}

function matchBracket(jsonText, scanPos, openChar, closeChar,   nestDepth, curChar, textLen) {
	# scanPos points at the opening bracket; returns the index of its match.
	nestDepth = 0
	textLen = length(jsonText)
	while (scanPos <= textLen) {
		curChar = substr(jsonText, scanPos, 1)
		if (curChar == "\"") { scanPos = skipQuoted(jsonText, scanPos) ; if (scanPos == 0) return 0 ; continue }
		if (curChar == openChar) nestDepth++
		else if (curChar == closeChar) { nestDepth-- ; if (nestDepth == 0) return scanPos }
		scanPos++
	}
	return 0
}

function unescapeJson(rawValue) {
	gsub(/\\"/, "\"", rawValue)
	gsub(/\\\//, "/", rawValue)
	gsub(/\\n/, " ", rawValue)
	gsub(/\\t/, " ", rawValue)
	gsub(/\\\\/, "\\", rawValue)
	return rawValue
}

function scalarNamed(objText, keyName,   foundPos, valuePos, endPos) {
	foundPos = index(objText, "\"" keyName "\":\"")
	if (foundPos == 0) return ""
	valuePos = foundPos + length(keyName) + 3
	endPos = skipQuoted(objText, valuePos)
	if (endPos == 0) return ""
	return unescapeJson(substr(objText, valuePos + 1, endPos - valuePos - 2))
}

{ bodyText[FNR == 1 ? ++bodyCount : bodyCount] = bodyText[bodyCount] $0 }

END {
	if (bodyCount < 2) { print "custom-fields: two response bodies required" > "/dev/stderr" ; exit 1 }

	## Definitions: profile.fields is an array of objects carrying id and label.
	defsText = bodyText[1]
	foundPos = index(defsText, "\"fields\":[")
	fieldCount = 0
	if (foundPos > 0) {
		arrayStart = foundPos + length("\"fields\":")
		arrayStop = matchBracket(defsText, arrayStart, "[", "]")
		if (arrayStop == 0) { print "custom-fields: unterminated definitions array" > "/dev/stderr" ; exit 1 }
		arrayText = substr(defsText, arrayStart + 1, arrayStop - arrayStart - 1)
		scanPos = 1
		while (scanPos <= length(arrayText)) {
			curChar = substr(arrayText, scanPos, 1)
			if (curChar == "{") {
				objEnd = matchBracket(arrayText, scanPos, "{", "}")
				if (objEnd == 0) { print "custom-fields: unterminated definition object" > "/dev/stderr" ; exit 1 }
				objText = substr(arrayText, scanPos, objEnd - scanPos + 1)
				fieldId = scalarNamed(objText, "id")
				if (fieldId != "") {
					fieldCount++
					orderedId[fieldCount] = fieldId
					labelOf[fieldId] = scalarNamed(objText, "label")
					knownId[fieldId] = 1
				}
				scanPos = objEnd + 1
				continue
			}
			if (curChar == "\"") { scanPos = skipQuoted(arrayText, scanPos) ; continue }
			scanPos++
		}
	}

	## Values: profile.fields is an object keyed by the same ids.
	valsText = bodyText[2]
	foundPos = index(valsText, "\"fields\":{")
	if (foundPos > 0) {
		objStart = foundPos + length("\"fields\":")
		objStop = matchBracket(valsText, objStart, "{", "}")
		if (objStop == 0) { print "custom-fields: unterminated values object" > "/dev/stderr" ; exit 1 }
		innerText = substr(valsText, objStart + 1, objStop - objStart - 1)
		scanPos = 1
		while (scanPos <= length(innerText)) {
			curChar = substr(innerText, scanPos, 1)
			if (curChar == "\"") {
				keyEnd = skipQuoted(innerText, scanPos)
				if (keyEnd == 0) break
				fieldId = substr(innerText, scanPos + 1, keyEnd - scanPos - 2)
				while (keyEnd <= length(innerText) && substr(innerText, keyEnd, 1) != "{" && substr(innerText, keyEnd, 1) != ",") keyEnd++
				if (substr(innerText, keyEnd, 1) == "{") {
					objEnd = matchBracket(innerText, keyEnd, "{", "}")
					if (objEnd == 0) break
					objText = substr(innerText, keyEnd, objEnd - keyEnd + 1)
					valueOf[fieldId] = scalarNamed(objText, "value")
					altOf[fieldId] = scalarNamed(objText, "alt")
					if (!(fieldId in knownId)) { knownId[fieldId] = 1 ; fieldCount++ ; orderedId[fieldCount] = fieldId }
					scanPos = objEnd + 1
					continue
				}
				scanPos = keyEnd
				continue
			}
			scanPos++
		}
	}

	for (emitIndex = 1; emitIndex <= fieldCount; emitIndex++) {
		fieldId = orderedId[emitIndex]
		printf "%s\t%s\t%s\t%s\n", fieldId, labelOf[fieldId], valueOf[fieldId], altOf[fieldId]
	}
	exit 0
}
