#!/usr/bin/awk -f
##
## AgentsRegistryHeaderRows.awk -- the rows of the spawned-sessions or the
## pending-replies registry, every record file in ONE pass, instead of a frontmatter
## print and one header awk per column per file. Called by AgentsTools.Registries.include
## with -v registryRows=spawned|pending; stdin is one entry per line, in the order the
## caller's own glob loops found them, so the row order is the shell's:
##   D<tracking-name>  spawned: a sandbox root starts; its name is the tracking name
##   S<record path>    spawned: one record in the current sandbox
##   E                 spawned: the current sandbox held no record
##   A<record path>    pending: one ask record
##   B<board path>     pending: one board item, a row only while it carries blocked-on
## Each text is escaped by the caller, `\` as `\\` and a newline as `\n`, so any name
## fits on one line.
##
## Frontmatter is read as AgentsBoardItemFrontmatterPrint.awk reads it: the lines
## strictly between the first two `---` lines, everything to EOF when there is no
## second one. A header is read as AgentsToolsRegistryHeader reads it: the first line
## whose key before its first `:` is the name exactly and whose trimmed value is not
## empty, the value's own whitespace runs written as `_`; `-` where none. A file that
## cannot be read has no headers, so every column is `-`.
##

function registryDecode(encodedText,    decodedText, charPos, charNow, charNext, textLength) {
	if (index(encodedText, "\\") == 0) return encodedText ;
	decodedText = "" ;
	textLength = length(encodedText) ;
	for (charPos = 1 ; charPos <= textLength ; charPos++) {
		charNow = substr(encodedText, charPos, 1) ;
		if (charNow == "\\" && charPos < textLength) {
			charNext = substr(encodedText, charPos + 1, 1) ;
			if (charNext == "n") { decodedText = decodedText "\n" ; charPos++ ; continue ; }
			if (charNext == "\\") { decodedText = decodedText "\\" ; charPos++ ; continue ; }
		}
		decodedText = decodedText charNow ;
	}
	return decodedText ;
}

## Fills fmLine[1..fmCount] with one file's frontmatter lines.
function registryFrontmatterRead(filePath,    readLine, readRc, fmDepth) {
	fmCount = 0 ;
	fmDepth = 0 ;
	while ((readRc = (getline readLine < filePath)) > 0) {
		if (readLine == "---") {
			fmDepth++ ;
			if (fmDepth >= 2) break ;
			continue ;
		}
		if (fmDepth == 1) fmLine[++fmCount] = readLine ;
	}
	close(filePath) ;
}

function registryHeader(wantKey,    lineIdx, lineText, colonPos, lineKey, lineValue) {
	for (lineIdx = 1 ; lineIdx <= fmCount ; lineIdx++) {
		lineText = fmLine[lineIdx] ;
		colonPos = index(lineText, ":") ;
		if (colonPos < 2) continue ;
		lineKey = substr(lineText, 1, colonPos - 1) ;
		if (lineKey != wantKey) continue ;
		lineValue = substr(lineText, colonPos + 1) ;
		gsub(/^[ \t]+|[ \t]+$/, "", lineValue) ;
		gsub(/[ \t]+/, "_", lineValue) ;
		if (lineValue != "") return lineValue ;
	}
	return "-" ;
}

function registryBaseName(pathText,    baseText) {
	baseText = pathText ;
	sub(/.*\//, "", baseText) ;
	return baseText ;
}

{
	entryKind = substr($0, 1, 1) ;
	entryText = registryDecode(substr($0, 2)) ;
}

registryRows == "spawned" && entryKind == "D" {
	sandboxTracking = entryText ;
	next ;
}

registryRows == "spawned" && entryKind == "E" {
	printf "%s - - - - no-session-record - - - - -\n", sandboxTracking ;
	next ;
}

## The record's own tracking-name wins over the folder name, and carries on to the
## sandbox's later records that name none, as the per-file shell loop always did.
registryRows == "spawned" && entryKind == "S" {
	registryFrontmatterRead(entryText) ;
	recordTracking = registryHeader("tracking-name") ;
	if (recordTracking != "-") sandboxTracking = recordTracking ;
	printf "%s %s %s %s %s %s %s %s %s %s %s\n", sandboxTracking, registryHeader("session-id"), registryHeader("parent-session-id"), registryHeader("host"), registryHeader("owner"), registryHeader("status"), registryHeader("exit-code"), registryHeader("spawn-id"), registryHeader("agent-log-thread"), registryHeader("session-thread"), registryHeader("workspace") ;
	next ;
}

registryRows == "pending" && entryKind == "A" {
	registryFrontmatterRead(entryText) ;
	printf "%s ask %s %s %s %s %s\n", registryBaseName(entryText), registryHeader("session-id"), registryHeader("owner"), registryHeader("status"), registryHeader("blocked-on"), registryHeader("communication-channel-id") ;
	next ;
}

registryRows == "pending" && entryKind == "B" {
	registryFrontmatterRead(entryText) ;
	boardBlocked = registryHeader("blocked-on") ;
	if (boardBlocked == "-") next ;
	printf "%s board-item %s %s %s %s %s\n", registryBaseName(entryText), registryHeader("session-id"), registryHeader("owner"), registryHeader("status"), boardBlocked, registryHeader("communication-channel-id") ;
	next ;
}
