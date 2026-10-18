#!/usr/bin/awk -f
##
## AgentsRegistryHeaderRows.awk -- the rows of the spawned-sessions or the
## pending-replies registry, every record file in ONE pass, instead of a frontmatter
## print and one header awk per column per file. Called by AgentsTools.Registries.include
## with -v registryRows=spawned|pending. With -v registryColumns=14 a spawned row carries,
## after its eleven columns, the three appended to them: started-at, resolved-at and
## session-comment; with -v registryColumns=16 the two appended after those as well,
## session-state and session-state-at, the state of the row's session (the T entries).
## A caller that names no count gets the eleven, and one that names fourteen gets fourteen,
## so one that loaded its reader before a column existed still counts its rows. stdin is one
## entry per line, in the order the caller's own glob loops found them, so the row order is
## the shell's:
##   D<tracking-name>  spawned: a sandbox root starts; its name is the tracking name
##   S<record path>    spawned: one record in the current sandbox
##   T<state path>     spawned: the state file of one session, before every D and S
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

## The state of one session, as its control thread keeps it in the session's own folder
## (AgentsTools.InternSessionControl.include): the file <sessions>/<session id>/control/state.
## The caller names each one it found there as a file, so nothing but a file is opened
## here: this awk ends on a folder it was given to read. The session is the folder the
## file's `control` stands in. Its `state` line is the word and its `state-at` line the
## date, each read as a header is read, so the date's spaces are written `_`. The word is
## taken as the file holds it, whatever state it names, while it is written as a state
## word is: lower-case letters, digits and `-`. Anything else is no state. A row of sixteen
## columns carries the two of its session, and `-` in both where there is none: a session
## with no such file, a file that cannot be read or names no state, a row with no session id.
registryRows == "spawned" && entryKind == "T" {
	stateSession = entryText ;
	if (sub(/\/control\/state$/, "", stateSession) != 1) next ;
	stateSession = registryBaseName(stateSession) ;
	fmCount = 0 ;
	while ((getline stateLine < entryText) > 0) fmLine[++fmCount] = stateLine ;
	close(entryText) ;
	stateWord = registryHeader("state") ;
	if (stateWord ~ /^[a-z][a-z0-9-]*$/) { stateWordOf[stateSession] = stateWord ; stateDateOf[stateSession] = registryHeader("state-at") ; }
	next ;
}

registryRows == "spawned" && entryKind == "D" {
	sandboxTracking = entryText ;
	next ;
}

registryRows == "spawned" && entryKind == "E" {
	printf "%s - - - - no-session-record - - - - -%s%s\n", sandboxTracking, ( registryColumns >= 14 ? " - - -" : "" ), ( registryColumns >= 16 ? " - -" : "" ) ;
	next ;
}

## The record's own tracking-name wins over the folder name, and carries on to the
## sandbox's later records that name none, as the per-file shell loop always did.
registryRows == "spawned" && entryKind == "S" {
	registryFrontmatterRead(entryText) ;
	recordTracking = registryHeader("tracking-name") ;
	if (recordTracking != "-") sandboxTracking = recordTracking ;
	printf "%s %s %s %s %s %s %s %s %s %s %s", sandboxTracking, registryHeader("session-id"), registryHeader("parent-spawn-id"), registryHeader("host"), registryHeader("owner"), registryHeader("status"), registryHeader("exit-code"), registryHeader("spawn-id"), registryHeader("agent-log-thread"), registryHeader("session-thread"), registryHeader("workspace") ;
	if ( registryColumns >= 14 ) printf " %s %s %s", registryHeader("started-at"), registryHeader("resolved-at"), registryHeader("session-comment") ;
	if ( registryColumns >= 16 ) {
		recordSession = registryHeader("session-id") ;
		if ( recordSession != "-" && ( recordSession in stateWordOf ) ) printf " %s %s", stateWordOf[recordSession], stateDateOf[recordSession] ;
		else printf " - -" ;
	}
	printf "\n" ;
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
