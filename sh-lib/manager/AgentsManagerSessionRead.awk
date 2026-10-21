#!/usr/bin/awk -f
##
## AgentsManagerSessionRead.awk -- the rows of --manager-session-read: one coworking session,
## or one run of it, in full. Called by AgentsTools.ManagerSession.include with two inputs, in
## this order: the pending-replies registry file, then the rows the list prints for that one
## session (its `session` row and its `run` rows, TAB between the fields, as
## AgentsManagerSessionRows.awk makes them). In the environment:
##   MDAT_MANAGER_AGENTS  the workspace's agents folder, $MMDAPP/.local/agents
##   MDAT_MANAGER_ROWS    the measured rows of the session, a line each (measuredDated of
##                        AgentsToolsRegistryMeasureRows): where each run's record lies, its threads
##   MDAT_MANAGER_STORES  the spawn ids that have a store folder under sessions/, a line each
##   MDAT_MANAGER_RUN     the one run to show, by its own id; empty for every run of the session
##   MDAT_MANAGER_CONTROL the control thread of the session where it left a pid file or a lock,
##                        `<session-id> <alive|gone> <pid>`, as it was measured for this call
##                        (AgentsToolsManagerSessionControls); empty for a session with none
##
## What a registry holds is taken from the rows given: nothing here measures, and no record is
## read for a column. A run's record is read for its headers, each as it stands, and its store,
## sessions/<spawn id>, for what no registry holds: the model, the tokens, the last milestone,
## the stored wait, the marks, and where its session log and its transcript lie. Only the
## records and the stores of the runs given are opened, never another session's.
##
## Printed, TAB between the fields: the `session` row as given; one `dispatch` row, what the
## session was started for, from its founder's record; one `control` row, the three last
## fields of the `session` row, the state its control thread stored, when, and whether that
## thread lives, and the process it is said of; one `tokens` row, the total of the session;
## then for each run its `run` row as
## given, a `header` row for every header of its record, and one `store` row. A run with no
## spawn id has no record to find by name and no store: its `run` row alone.
## THE `tokens` ROW is the sum over every run of the session, whichever runs are shown, of the
## four figures its `store` row gives, by the same reading (tokensOfRun,
## AgentsManagerSessionTokens.awk, loaded with -f before this file): in, cache read, cache
## write, out; then how many runs are summed, and how many of those run still; then `so-far`,
## or `final` for a session that reads `finished`, every run of it ended and closed; then how
## many runs are left out, their figures not known. With no run summed the four read `-`. A
## spawn id that two records carry is one run.
##

## A free text as one field, exact: its backslash written `\\`, a TAB `\t`, a carriage return
## `\r` and a line break `\n`; `-` for none.
function exactText(textValue,    outText, oneChar) {
	if (textValue == "") return "-" ;
	if (textValue !~ /[\\\t\r\n]/) return textValue ;
	outText = "" ;
	while (match(textValue, /[\\\t\r\n]/)) {
		oneChar = substr(textValue, RSTART, 1) ;
		outText = outText substr(textValue, 1, RSTART - 1) ( oneChar == "\\" ? "\\\\" : ( oneChar == "\t" ? "\\t" : ( oneChar == "\r" ? "\\r" : "\\n" ) ) ) ;
		textValue = substr(textValue, RSTART + 1) ;
	}
	return outText textValue ;
}

## A value as a registry writes one: its whitespace runs `_`, `-` for none.
function columnText(textValue) {
	gsub(/^[ \t\r]+|[ \t\r]+$/, "", textValue) ;
	gsub(/[ \t\r]+/, "_", textValue) ;
	return ( textValue == "" ? "-" : textValue ) ;
}

## A name that is one path component, so nothing here opens a file outside the two stores.
function plainName(nameText) {
	return ( nameText != "" && nameText != "-" && nameText != "." && nameText != ".." && index(nameText, "/") == 0 ) ;
}

## The first line of a file; fileSeen says whether the file is there, an empty one too.
function firstLine(filePath,    lineText, readRc) {
	lineText = "" ;
	readRc = ( getline lineText < filePath ) ;
	close(filePath) ;
	fileSeen = ( readRc >= 0 ) ;
	return ( readRc > 0 ? lineText : "" ) ;
}

## The last line of a file that is not empty.
function lastLine(filePath,    lineText, lastText) {
	lastText = "" ;
	while (( getline lineText < filePath ) > 0) { if (lineText != "") lastText = lineText ; }
	close(filePath) ;
	return lastText ;
}

## One run's record, its headers in the order they stand: the lines strictly between the
## first two `---` lines, as the registries read them. A header's value is what follows its
## first `:`, trimmed. Kept under the run's place: headerName, headerValue, headerTotal.
function recordRead(runAt, filePath,    lineText, fenceDepth, colonAt, valueText) {
	headerTotal[runAt] = 0 ; fenceDepth = 0 ;
	while (( getline lineText < filePath ) > 0) {
		if (lineText == "---") { if (++fenceDepth >= 2) break ; continue ; }
		if (fenceDepth != 1) continue ;
		colonAt = index(lineText, ":") ;
		if (colonAt < 2) continue ;
		valueText = substr(lineText, colonAt + 1) ;
		gsub(/^[ \t]+|[ \t\r]+$/, "", valueText) ;
		headerTotal[runAt]++ ;
		headerName[runAt, headerTotal[runAt]] = substr(lineText, 1, colonAt - 1) ;
		headerValue[runAt, headerTotal[runAt]] = valueText ;
	}
	close(filePath) ;
}

## A header of a run's record, by its name: the first that has a value, as a registry takes it.
function recordHeader(runAt, wantName,    headerAt) {
	for (headerAt = 1 ; headerAt <= headerTotal[runAt] ; headerAt++) {
		if (headerName[runAt, headerAt] == wantName && headerValue[runAt, headerAt] != "") return headerValue[runAt, headerAt] ;
	}
	return "" ;
}

## The `store` row of one run, from its own store.
function storeRow(spawnId,    storeDir, tokenText, tokenWords, tokenAt, lineText, milestoneText, milestoneAt, waitText, markText, markAt, byText, logPath, transcriptPath) {
	storeDir = agentsDir "/sessions/" spawnId ;
	if (!( spawnId in storeSeen )) {
		return "store" OFS spawnId OFS "no-store" OFS "-" OFS "-" OFS "-" OFS "-" OFS "-" OFS ( spawnId in asksOf ? asksOf[spawnId] : "-" ) OFS "-" OFS "-" OFS "-" OFS "-" OFS "-" OFS "-" OFS "-" ;
	}
	tokensOfRun(agentsDir, spawnId, tokenWords) ;
	## The last milestone, `<ISO UTC> <what>`, as the transcript writes one at each.
	milestoneText = lastLine(storeDir "/milestones") ; milestoneAt = "-" ;
	if (milestoneText ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z /) { milestoneAt = substr(milestoneText, 1, 20) ; milestoneText = substr(milestoneText, 22) ; }
	## What the stored wait of the run waits on.
	waitText = "" ;
	while (( getline lineText < ( storeDir "/wait/state" ) ) > 0) {
		if (index(lineText, "sources:") == 1) { waitText = substr(lineText, 9) ; break ; }
	}
	close(storeDir "/wait/state") ;
	gsub(/^[ \t]+|[ \t\r]+$/, "", waitText) ; gsub(/[ \t]+/, " ", waitText) ;
	## The marks: each a file of that name in the store. The dismissal holds who dismissed.
	markText = "" ; byText = "" ;
	for (markAt = 1 ; markAt <= markTotal ; markAt++) {
		lineText = firstLine(storeDir "/" markNames[markAt]) ;
		if (!fileSeen) continue ;
		markText = markText ( markText == "" ? "" : "," ) markNames[markAt] ;
		if (markNames[markAt] == "dismissed") byText = ( lineText == "" ? "unknown" : lineText ) ;
	}
	firstLine(storeDir "/session.log") ;
	logPath = ( fileSeen ? storeDir "/session.log" : "" ) ;
	## The transcript: the file the store's pointer names, while it is there.
	transcriptPath = firstLine(storeDir "/transcript") ;
	if (transcriptPath != "") { firstLine(transcriptPath) ; if (!fileSeen) transcriptPath = "" ; }
	return "store" OFS spawnId OFS "store" OFS columnText(firstLine(storeDir "/model")) OFS tokenWords[1] OFS tokenWords[2] OFS tokenWords[3] OFS tokenWords[4] \
		OFS ( spawnId in asksOf ? asksOf[spawnId] : "-" ) OFS ( markText == "" ? "-" : markText ) OFS milestoneAt OFS exactText(milestoneText) OFS exactText(waitText) \
		OFS exactText(byText) OFS exactText(logPath) OFS exactText(transcriptPath) ;
}

BEGIN {
	OFS = "\t" ;
	agentsDir = ENVIRON["MDAT_MANAGER_AGENTS"] ;
	onlyRun = ENVIRON["MDAT_MANAGER_RUN"] ;
	markTotal = split("dismissed dismissed.handback ended review-expired", markNames, " ") ;
	## The measured rows: the sandbox a run's record lies in, column 1, and the threads, columns
	## 9 and 10, the founder's own first.
	rowTotal = split(ENVIRON["MDAT_MANAGER_ROWS"], rowLines, "\n") ;
	for (rowAt = 1 ; rowAt <= rowTotal ; rowAt++) {
		rowWidth = split(rowLines[rowAt], rowWords, " ") ;
		if (rowWidth != 16 && rowWidth != 18) continue ;
		if (rowWords[8] != "-" && !( rowWords[8] in trackingOf )) trackingOf[rowWords[8]] = rowWords[1] ;
		if (rowWords[8] != "-" && rowWords[8] == rowWords[2]) { if (rowWords[9] != "-") trackingThread = rowWords[9] ; if (rowWords[10] != "-") sessionThread = rowWords[10] ; }
		if (anyTracking == "" && rowWords[9] != "-") anyTracking = rowWords[9] ;
		if (anySession == "" && rowWords[10] != "-") anySession = rowWords[10] ;
	}
	if (trackingThread == "") trackingThread = anyTracking ;
	if (sessionThread == "") sessionThread = anySession ;
	storeTotal = split(ENVIRON["MDAT_MANAGER_STORES"], storeIds, "\n") ;
	for (storeAt = 1 ; storeAt <= storeTotal ; storeAt++) { if (storeIds[storeAt] != "") storeSeen[storeIds[storeAt]] = 1 ; }
	controlTotal = split(ENVIRON["MDAT_MANAGER_CONTROL"], controlLines, "\n") ;
	for (controlAt = 1 ; controlAt <= controlTotal ; controlAt++) {
		if (split(controlLines[controlAt], controlWords, " ") >= 3) controlPid[controlWords[1]] = controlWords[3] ;
	}
}

## The pending-replies registry: key source session-id owner status blocked-on channel. An
## ask carries the id of the run that asked it; its own id is its key without the `.md`.
FILENAME == ARGV[1] {
	if ($2 == "ask" && $5 == "reply-pending") {
		askId = $1 ; sub(/\.md$/, "", askId) ;
		asksOf[$3] = ( ( $3 in asksOf ) ? asksOf[$3] "," : "" ) askId ;
	}
	next ;
}

{
	split($0, listedWords, "\t") ;
	if (listedWords[1] == "session") {
		sessionRow = $0 ; sessionId = listedWords[2] ; sessionState = listedWords[4] ;
		sessionStored = ( listedWords[9] == "" ? "-" : listedWords[9] ) ; sessionStoredAt = ( listedWords[10] == "" ? "-" : listedWords[10] ) ; sessionControl = ( listedWords[11] == "" ? "none" : listedWords[11] ) ;
		next ;
	}
	if (listedWords[1] != "run") next ;
	runTotal++ ;
	runRow[runTotal] = $0 ; runSpawn[runTotal] = listedWords[3] ; runMember[runTotal] = listedWords[4] ; runLive[runTotal] = listedWords[6] ;
}

END {
	if (sessionRow == "") exit 0 ;
	founderAt = 0 ;
	for (runAt = 1 ; runAt <= runTotal ; runAt++) {
		headerTotal[runAt] = 0 ;
		if (!plainName(runSpawn[runAt])) continue ;
		if (runSpawn[runAt] == sessionId && founderAt == 0) founderAt = runAt ;
		## Only the founder's record is read for a run that is not shown.
		if (onlyRun != "" && runSpawn[runAt] != onlyRun && runAt != founderAt) continue ;
		if (plainName(trackingOf[runSpawn[runAt]])) recordRead(runAt, agentsDir "/spawned/" trackingOf[runSpawn[runAt]] "/" runSpawn[runAt] ".spawn.md") ;
	}
	print sessionRow ;
	## What the session was started for: its founder's routine, dispatch item and description.
	## A session a client founded has no record of its founder, and says so.
	if (founderAt > 0) print "dispatch", sessionId, "record", runMember[founderAt], columnText(recordHeader(founderAt, "routine")), columnText(recordHeader(founderAt, "spawns")), ( sessionThread == "" ? "-" : sessionThread ), ( trackingThread == "" ? "-" : trackingThread ), exactText(recordHeader(founderAt, "description")) ;
	else print "dispatch", sessionId, "no-record", "-", "-", "-", ( sessionThread == "" ? "-" : sessionThread ), ( trackingThread == "" ? "-" : trackingThread ), "-" ;
	## The control thread of the session: what the `session` row says of it, and its process.
	print "control", sessionId, sessionStored, sessionStoredAt, sessionControl, ( sessionControl != "none" && ( sessionId in controlPid ) ? controlPid[sessionId] : "-" ) ;
	## The tokens of the session: every run of it, shown or not, each by the figures of its own store.
	tokenRuns = 0 ; tokenRunning = 0 ; tokenUnknown = 0 ;
	for (tokenAt = 1 ; tokenAt <= 4 ; tokenAt++) tokenSum[tokenAt] = 0 ;
	for (runAt = 1 ; runAt <= runTotal ; runAt++) {
		if (runSpawn[runAt] != "-" && ( runSpawn[runAt] in tokenTaken )) continue ;
		tokenTaken[runSpawn[runAt]] = 1 ;
		if (!tokensOfRun(agentsDir, runSpawn[runAt], tokenWords)) { tokenUnknown++ ; continue ; }
		tokenRuns++ ;
		if (runLive[runAt] == "running") tokenRunning++ ;
		for (tokenAt = 1 ; tokenAt <= 4 ; tokenAt++) tokenSum[tokenAt] += tokenWords[tokenAt] ;
	}
	for (tokenAt = 1 ; tokenAt <= 4 ; tokenAt++) tokenSaid[tokenAt] = ( tokenRuns > 0 ? tokensFigure(tokenSum[tokenAt]) : "-" ) ;
	print "tokens", sessionId, tokenSaid[1], tokenSaid[2], tokenSaid[3], tokenSaid[4], tokenRuns, tokenRunning, ( sessionState == "finished" ? "final" : "so-far" ), tokenUnknown ;
	for (runAt = 1 ; runAt <= runTotal ; runAt++) {
		if (onlyRun != "" && runSpawn[runAt] != onlyRun) continue ;
		print runRow[runAt] ;
		if (!plainName(runSpawn[runAt])) continue ;
		for (headerAt = 1 ; headerAt <= headerTotal[runAt] ; headerAt++) print "header", runSpawn[runAt], columnText(headerName[runAt, headerAt]), exactText(headerValue[runAt, headerAt]) ;
		print storeRow(runSpawn[runAt]) ;
	}
}
