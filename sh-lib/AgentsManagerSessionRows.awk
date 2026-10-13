#!/usr/bin/awk -f
##
## AgentsManagerSessionRows.awk -- the rows of --manager-session-list: the measured rows of
## the spawned-sessions registry grouped into coworking sessions, each session with its
## runs, and one row of counters. Called by AgentsTools.ManagerSession.include with two
## inputs, in this order: the pending-replies registry file, then the measured rows
## (measuredDated of AgentsToolsRegistryMeasureRows: eleven stored columns, live, state,
## started-at, resolved-at, session-comment, session-state, session-state-at). -v activeOnly=1
## keeps the sessions with a live run; -v loadAverage is the figure of the counters row, and
## -v hostName the name of this host, which stands last in that row, `-` where none is given. In
## the environment, MDAT_MANAGER_WAITING is ` <spawn-id> <spawn-id> ... `: the live runs that
## sit inside a Wait; and MDAT_MANAGER_CONTROL is a line `<session-id> <alive|gone> <pid>` for
## each session whose control thread left a pid file or a lock, as it was measured for this
## call (AgentsToolsManagerSessionControls): a session with no line there has none.
##
## A session is the rows that carry one session-id; a row with none (an empty sandbox, a
## record with no header) is a session of its own under its tracking name. Nothing here
## measures: live and state are the row's own, as the render derives them. A row that is
## not eighteen words, a sandbox folder named with a space, cannot be read and is left out;
## one of sixteen is a row of a caller that counts no state of a session, and reads `-` there.
## The state its control thread stored for a session stands at the end of its row beside the
## state derived here, each as it is: where the two differ, neither is changed.
##
## Every line goes out behind five sort keys and a TAB each, for
## `sort -t <TAB> -k1,1nr -k2,2n -k3,3n -k4,4n -k5,5n` and a cut of them: the session's
## start in minutes (-1 with no date, so last), its place in the registry, 0 for the
## session row and 1 for a run, the run's start in minutes, the run's place. The counters
## row carries -2, so it is the last line.
##

## Minutes since 1970-01-01 UTC of a date as a spawn record writes it and a registry keeps
## it, `2026-10-12_16:57_+0300`; -1 for anything else.
function dateMinutes(dateText,    dateDigits, dateYear, dateMonth, dateDay, dateOffset, dateSign) {
	if (length(dateText) != 22) return -1 ;
	if (substr(dateText, 5, 1) != "-" || substr(dateText, 8, 1) != "-" || substr(dateText, 11, 1) != "_" || substr(dateText, 14, 1) != ":" || substr(dateText, 17, 1) != "_") return -1 ;
	dateSign = substr(dateText, 18, 1) ;
	if (dateSign != "+" && dateSign != "-") return -1 ;
	dateDigits = substr(dateText, 1, 4) substr(dateText, 6, 2) substr(dateText, 9, 2) substr(dateText, 12, 2) substr(dateText, 15, 2) substr(dateText, 19, 4) ;
	if (dateDigits !~ /^[0-9]+$/) return -1 ;
	dateYear = substr(dateText, 1, 4) + 0 ; dateMonth = substr(dateText, 6, 2) + 0 ; dateDay = substr(dateText, 9, 2) + 0 ;
	if (dateMonth <= 2) { dateYear-- ; dateMonth += 12 ; }
	dateOffset = substr(dateText, 19, 2) * 60 + substr(dateText, 21, 2) ;
	if (dateSign == "-") dateOffset = -dateOffset ;
	return ( 365 * dateYear + int(dateYear / 4) - int(dateYear / 100) + int(dateYear / 400) + int((153 * (dateMonth - 3) + 2) / 5) + dateDay - 719469 ) * 1440 + substr(dateText, 12, 2) * 60 + substr(dateText, 15, 2) - dateOffset ;
}

BEGIN {
	OFS = "\t" ;
	waitingSet = ENVIRON["MDAT_MANAGER_WAITING"] ;
	stateTotal = split("running waiting unclosed unknown-foreign finished", stateOrder, " ") ;
	controlTotal = split(ENVIRON["MDAT_MANAGER_CONTROL"], controlLines, "\n") ;
	for (controlAt = 1 ; controlAt <= controlTotal ; controlAt++) {
		if (split(controlLines[controlAt], controlWords, " ") >= 2) controlOf[controlWords[1]] = controlWords[2] ;
	}
}

## The pending-replies registry: key source session-id owner status blocked-on channel. An
## ask is open by its status, a board item by standing here at all, as the render reads them.
FILENAME == ARGV[1] {
	if ($2 == "ask" && $5 == "reply-pending") { openOf[$3] = 1 ; pendingAnswers++ ; }
	else if ($2 == "board-item") { openOf[$3] = 1 ; }
	next ;
}

NF != 16 && NF != 18 { next ; }

{
	sessionKey = ( $2 == "-" ? $1 : $2 ) ;
	if (!(sessionKey in sessionPlace)) {
		sessionPlace[sessionKey] = ++sessionTotal ;
		sessionOf[sessionTotal] = sessionKey ;
		sessionName[sessionKey] = "-" ; sessionStart[sessionKey] = -1 ; sessionEnd[sessionKey] = -1 ;
		sessionStored[sessionKey] = "-" ; sessionStoredAt[sessionKey] = "-" ;
	}
	## The stored state of the session: every row of it carries the same two, and where a
	## row was read from its record after the others, the later one is the newer.
	if (NF == 18 && $17 != "-") { sessionStored[sessionKey] = $17 ; sessionStoredAt[sessionKey] = $18 ; }
	## A row with no session id is a session under its tracking name, which is no id of a
	## session: no control thread is its own.
	if ($2 != "-") sessionById[sessionKey] = 1 ;
	runTotal++ ;
	runSession[runTotal] = sessionKey ;
	runStart[runTotal] = $14 ; runEnd[runTotal] = $15 ;
	runActivity[runTotal] = "-" ;
	if ($12 == "running") {
		sessionLive[sessionKey] = 1 ;
		if (index(waitingSet, " " $8 " ") > 0) { runActivity[runTotal] = "waiting" ; agentsWaiting++ ; }
		else { runActivity[runTotal] = "working" ; agentsWorking++ ; }
	}
	## An ask of the session: one that names the session, or the run that asked it by its own id.
	if ((sessionKey in openOf) || ($8 != "-" && ($8 in openOf)) || $13 == "waiting") sessionAsks[sessionKey] = 1 ;
	if ($13 == "unknown-foreign") sessionForeign[sessionKey] = 1 ;
	if ($13 == "unclosed" || $13 == "waiting") sessionOpen[sessionKey] = 1 ;
	sessionRuns[sessionKey]++ ;
	sessionStates[sessionKey, $13]++ ;
	if (sessionName[sessionKey] == "-") sessionName[sessionKey] = $16 ;
	runMinutes[runTotal] = dateMinutes(runStart[runTotal]) ;
	if (runMinutes[runTotal] >= 0 && (sessionStart[sessionKey] < 0 || runMinutes[runTotal] < sessionStart[sessionKey])) {
		sessionStart[sessionKey] = runMinutes[runTotal] ; sessionStartText[sessionKey] = runStart[runTotal] ;
	}
	endMinutes = dateMinutes(runEnd[runTotal]) ;
	if (endMinutes > sessionEnd[sessionKey]) { sessionEnd[sessionKey] = endMinutes ; sessionEndText[sessionKey] = runEnd[runTotal] ; }
	runRow[runTotal] = $8 OFS $5 OFS $6 OFS $12 OFS $13 OFS runStart[runTotal] OFS runEnd[runTotal] OFS $4 OFS $11 ;
}

END {
	for (sessionAt = 1 ; sessionAt <= sessionTotal ; sessionAt++) {
		sessionKey = sessionOf[sessionAt] ;
		if (sessionKey in sessionLive) sessionState[sessionKey] = "running" ;
		else if (sessionKey in sessionAsks) sessionState[sessionKey] = "waiting" ;
		else if (sessionKey in sessionForeign) sessionState[sessionKey] = "unknown-foreign" ;
		else if (sessionKey in sessionOpen) sessionState[sessionKey] = "unclosed" ;
		else sessionState[sessionKey] = "finished" ;
		if (sessionState[sessionKey] == "running") sessionsRunning++ ;
		if (activeOnly && sessionState[sessionKey] != "running") continue ;
		stateTally = "" ;
		for (stateAt = 1 ; stateAt <= stateTotal ; stateAt++) {
			if ((sessionKey, stateOrder[stateAt]) in sessionStates) stateTally = stateTally ( stateTally == "" ? "" : "," ) stateOrder[stateAt] "=" sessionStates[sessionKey, stateOrder[stateAt]] ;
		}
		## The date of a state is on record for a finished session alone: when its last run closed.
		## Then, at the end of the row, what its control thread stored and whether that thread lives.
		print sessionStart[sessionKey], sessionAt, 0, 0, 0, "session", sessionKey, sessionName[sessionKey], sessionState[sessionKey], ( sessionStart[sessionKey] < 0 ? "-" : sessionStartText[sessionKey] ), ( sessionState[sessionKey] == "finished" && sessionEnd[sessionKey] >= 0 ? sessionEndText[sessionKey] : "-" ), sessionRuns[sessionKey], stateTally, sessionStored[sessionKey], sessionStoredAt[sessionKey], ( ( sessionKey in sessionById ) && ( sessionKey in controlOf ) ? controlOf[sessionKey] : "none" ) ;
	}
	for (runAt = 1 ; runAt <= runTotal ; runAt++) {
		sessionKey = runSession[runAt] ;
		if (activeOnly && sessionState[sessionKey] != "running") continue ;
		## A run with no date stands after the dated ones of its session.
		print sessionStart[sessionKey], sessionPlace[sessionKey], 1, ( runMinutes[runAt] < 0 ? 99999999999 : runMinutes[runAt] ), runAt, "run", sessionKey, runRow[runAt], runActivity[runAt] ;
	}
	## Paused comes with the step of pause and resume: its place is kept, and reads 0 until then.
	print -2, 0, 0, 0, 0, "counters", sessionsRunning + 0, 0, agentsWorking + 0, agentsWaiting + 0, pendingAnswers + 0, ( loadAverage == "" ? "-" : loadAverage ), ( hostName == "" ? "-" : hostName ) ;
}
