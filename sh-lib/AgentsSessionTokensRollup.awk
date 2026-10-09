#!/usr/bin/env awk

# Token totals for board items, computed when shown and never stored: an item's own
# `tokens:` header plus every item under it, by the links that already exist.
#   - an item whose `tracks:` or `follows-up:` names it;
#   - a spawn record (.local/agents/spawned/*/*.md) whose `parent-session-id:` is the
#     item's `spawn-id:` (the children index lists the same records) -- the record's
#     `spawns:` item is under it.
# Each descendant counts once, however many links reach it.
#
# stdin: one file path per line, board items and spawn records alike (told apart by
# a /spawned/ segment). -v want="<item> <item> ..." names the items to total, bare
# names with or without .md. Prints one row per wanted item that has any tokens:
#   <item>\t<in>\t<cache-read>\t<cache-write>\t<out>\t<sub-sessions>
# Run LC_ALL=C.

function rlBare(nameText) {
	sub(/^.*\//, "", nameText)
	sub(/\.md$/, "", nameText)
	return nameText
}

function rlTokensField(headerText, keyName,   fieldText) {
	if (!match(headerText, "(^| )" keyName "=[0-9]+")) return ""
	fieldText = substr(headerText, RSTART, RLENGTH)
	sub(/^ /, "", fieldText)
	sub(/^[^=]*=/, "", fieldText)
	return fieldText
}

function rlReadFile(filePath,   lineText, lineNumber, inFront, keyName, valueText, itemName, isRecord, tokenText, linkCount, linkList, linkIndex) {
	isRecord = (index(filePath, "/spawned/") > 0)
	itemName = rlBare(filePath)
	lineNumber = 0
	inFront = 0
	while ((getline lineText < filePath) > 0) {
		lineNumber++
		if (lineNumber == 1) {
			if (lineText != "---") break
			inFront = 1
			continue
		}
		if (lineText == "---") break
		keyName = lineText
		sub(/:.*$/, "", keyName)
		valueText = lineText
		if (!sub(/^[^:]*:[ \t]*/, "", valueText)) continue
		if (isRecord) {
			if (keyName == "parent-session-id") recordParent = valueText
			else if (keyName == "spawns") recordSpawns = valueText
			continue
		}
		if (keyName == "tokens") tokenText = valueText
		else if (keyName == "spawn-id") itemSpawn[itemName] = valueText
		else if (keyName == "tracks" || keyName == "follows-up") {
			linkCount = split(valueText, linkList, /[ ,]+/)
			for (linkIndex = 1; linkIndex <= linkCount; linkIndex++) {
				if (linkList[linkIndex] == "") continue
				childOf[rlBare(linkList[linkIndex]), itemName] = 1
			}
		}
	}
	close(filePath)
	if (isRecord) {
		if (recordParent != "" && recordParent != "none" && recordSpawns != "") spawnChild[recordParent, rlBare(recordSpawns)] = 1
		recordParent = ""
		recordSpawns = ""
		return
	}
	itemKnown[itemName] = 1
	if (tokenText != "") {
		hasTokens[itemName] = 1
		tokIn[itemName] = rlTokensField(tokenText, "in") + 0
		tokCr[itemName] = rlTokensField(tokenText, "cache-read") + 0
		tokCw[itemName] = rlTokensField(tokenText, "cache-write") + 0
		tokOut[itemName] = rlTokensField(tokenText, "out") + 0
	}
}

function rlVisit(itemName, depthLeft,   pairKey, pairParts, childName) {
	if (itemName in rlSeen) return
	rlSeen[itemName] = 1
	if (itemName in hasTokens) {
		sumIn += tokIn[itemName] ; sumCr += tokCr[itemName] ; sumCw += tokCw[itemName] ; sumOut += tokOut[itemName]
		if (itemName != rlRoot) subCount++
		anyTokens = 1
	}
	if (depthLeft <= 0) return
	for (pairKey in childOf) {
		split(pairKey, pairParts, SUBSEP)
		if (pairParts[1] == itemName) rlVisit(pairParts[2], depthLeft - 1)
	}
	if ((itemName in itemSpawn) && itemSpawn[itemName] != "") {
		for (pairKey in spawnChild) {
			split(pairKey, pairParts, SUBSEP)
			if (pairParts[1] == itemSpawn[itemName]) {
				childName = pairParts[2]
				rlVisit(childName, depthLeft - 1)
			}
		}
	}
}

{ if ($0 != "") rlReadFile($0) }

END {
	wantCount = split(want, wantList, /[ \t\n]+/)
	for (wantIndex = 1; wantIndex <= wantCount; wantIndex++) {
		if (wantList[wantIndex] == "") continue
		rlRoot = rlBare(wantList[wantIndex])
		split("", rlSeen)
		sumIn = sumCr = sumCw = sumOut = 0
		subCount = 0
		anyTokens = 0
		rlVisit(rlRoot, 8)
		if (!anyTokens) continue
		printf "%s\t%d\t%d\t%d\t%d\t%d\n", rlRoot, sumIn, sumCr, sumCw, sumOut, subCount
	}
}
