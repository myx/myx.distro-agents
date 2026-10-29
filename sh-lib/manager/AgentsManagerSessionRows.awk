#!/usr/bin/awk -f
##
## AgentsManagerSessionRows.awk -- the rows of --manager-session-list: the measured rows of
## the spawned-sessions registry grouped into coworking sessions, each session with its
## runs, and one row of counters. Called by AgentsTools.ManagerSession.include with two
## inputs, in this order: the pending-replies registry file, then the measured rows
## (measuredDated of AgentsToolsRegistryMeasureRows: eleven stored columns, live, state,
## started-at, resolved-at, session-comment, session-state, session-state-at). -v activeOnly=1
## keeps the sessions that are not finished and can be acted on from this host, those that
## read running, waiting, unclosed or failed (activeState); -v loadAverage is the figure of the counters row, and
## -v hostName the name of this host, which stands last in that row, `-` where none is given. In
## the environment, MDAT_MANAGER_WAITING is ` <spawn-id> <spawn-id> ... `: the live runs that
## sit inside a Wait; and MDAT_MANAGER_CONTROL is a line `<session-id> <alive|gone> <pid>` for
## each session whose control thread left a pid file or a lock, as it was measured for this
## call (AgentsToolsManagerSessionControls): a session with no line there has none. And
## MDAT_MANAGER_AGENTS is the workspace's agents folder, $MMDAPP/.local/agents, where the
## store of each run lies: its tokens are read there, by the one reading the read of a session
## has too (tokensOfRun, AgentsManagerSessionTokens.awk, loaded with -f before this file). The
## minutes of a date are dateMinutes of AgentsManagerDateMinutes.awk, loaded with -f before this file too.
##
## A session is the rows that carry one session-id; a row with none (an empty sandbox, a
## record with no header) is a session of its own under its tracking name. Nothing here
## measures: live and state are the row's own, as the render derives them, and the state of a
## session is nothing but those states, added up (the END block). A row that is
## not sixteen, eighteen or nineteen words, a sandbox folder named with a space, cannot be
## read and is left out; one of sixteen is a row of a caller that counts no state of a
## session, and reads `-` there; one of nineteen carries the refused count too (sketch 3.6).
## The state its control thread stored for a session stands at the end of its row beside the
## state derived here, each as it is: where the two differ, neither is changed.
## THE TOKENS OF A SESSION are the last field but one of its row, one number: the four figures
## of each of its runs, in, cache read, cache write and out, all added. A run whose figures
## are not known is left out, and the number then ends with `+`: it is not the whole. `-` where
## no run of the session has known figures. One small file of a run's store is read for it,
## where the run has one; a spawn id that two records carry is one run.
## THE USAGE-LIMIT FLAG of a session, the second-last field of its row, is the one wording
## the run's own store keeps when the provider refused it for its API usage limit -- that it
## stopped on the provider usage limit and the date it reopens (usageLimitOfRun, one more
## small file of a run's store), `-` where no run of the session was refused. The last of its
## refused runs wins, since a later refusal is the one that still holds.
## THE REFUSED COUNT of a session, the last field of its row, is every one of its runs' own
## `refused` count added (sketch 3.6): not only the refusal that stopped a run, every one a
## run's harness loop hit. `-` where none of the session's runs ever carried one.
##
## Every line goes out behind five sort keys and a TAB each, for
## `sort -t <TAB> -k1,1nr -k2,2n -k3,3n -k4,4n -k5,5n` and a cut of them: the session's
## start in minutes (-1 with no date, so last), its place in the registry, 0 for the
## session row and 1 for a run, the run's start in minutes, the run's place. The counters
## row carries -2, so it is the last line.
##

## Whether --active keeps a session of that state: one that is not finished, and with which
## something can still be done from this host. `running`. `waiting`: no live process and a run
## of it waiting on an answer, which can be answered or dismissed, or every live run of it in a
## Wait, which is what it is doing. `unclosed`, no live process
## and a record still open: the record can be closed, the run started again. `failed`, every run of it
## died on its start: a joined coordinator takes it up. Not `finished`;
## and not `unknown-foreign`, which is another host's: nothing can be done with it from here. `starting`, a run the main
## loop is still starting (its start marker has no result yet), whose process is not seen yet.
function activeState(stateWord) {
	return ( stateWord == "running" || stateWord == "starting" || stateWord == "waiting" || stateWord == "unclosed" || stateWord == "failed" ) ;
}

## The usage-limit flag of one run, from its store: the first line of
## sessions/<spawn id>/usage-limit, the one wording the close keeps there when the provider
## refused the run because its API usage limit was reached -- that it stopped on the
## provider usage limit, and the date the provider said it reopens
## (AgentsTools.UsageLimit.include). One small file a run is opened for it, where the run has
## one; empty where it has none. A run with no bare id opens nothing.
function usageLimitOfRun(agentsDir, spawnId,    limitPath, limitText) {
	limitText = "" ;
	if (spawnId != "" && spawnId != "-" && spawnId != "." && spawnId != ".." && index(spawnId, "/") == 0) {
		limitPath = agentsDir "/sessions/" spawnId "/usage-limit" ;
		if (( getline limitText < limitPath ) < 1) limitText = "" ;
		close(limitPath) ;
	}
	return limitText ;
}

BEGIN {
	OFS = "\t" ;
	waitingSet = ENVIRON["MDAT_MANAGER_WAITING"] ;
	agentsDir = ENVIRON["MDAT_MANAGER_AGENTS"] ;
	stateTotal = split("running starting waiting unclosed unknown-foreign failed finished", stateOrder, " ") ;
	controlTotal = split(ENVIRON["MDAT_MANAGER_CONTROL"], controlLines, "\n") ;
	for (controlAt = 1 ; controlAt <= controlTotal ; controlAt++) {
		if (split(controlLines[controlAt], controlWords, " ") >= 2) controlOf[controlWords[1]] = controlWords[2] ;
	}
}

## The pending-replies registry: key source session-id owner status blocked-on channel. Read
## for the counter of open asks, and for the asking id of each of them: that id is the session
## itself or the run that asked, so an ask still open is a row's own fact wherever the row
## stands, and the state of the session below counts it.
FILENAME == ARGV[1] {
	if ($2 == "ask" && $5 == "reply-pending") { pendingAnswers++ ; openAsker[$3] = 1 ; }
	next ;
}

NF != 16 && NF != 18 && NF != 19 { next ; }

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
	if (( NF == 18 || NF == 19 ) && $17 != "-") { sessionStored[sessionKey] = $17 ; sessionStoredAt[sessionKey] = $18 ; }
	## A row with no session id is a session under its tracking name, which is no id of a
	## session: no control thread is its own.
	if ($2 != "-") sessionById[sessionKey] = 1 ;
	runTotal++ ;
	runSession[runTotal] = sessionKey ;
	runStart[runTotal] = $14 ; runEnd[runTotal] = $15 ;
	runActivity[runTotal] = "-" ;
	if ($12 == "running") {
		sessionLive[sessionKey] = 1 ;
		sessionLiveCount[sessionKey]++ ;
		if (index(waitingSet, " " $8 " ") > 0) { runActivity[runTotal] = "waiting" ; agentsWaiting++ ; sessionLiveWaiting[sessionKey]++ ; }
		else { runActivity[runTotal] = "working" ; agentsWorking++ ; }
	}
	## A RUN THAT DIED ON ITS START READS `failed` (sketch 3.6), whatever the registry derives of it: its status says so.
	runStateWord = ( $6 == "spawn-failed" ? "failed" : $13 ) ;
	if (runStateWord == "failed") sessionFailed[sessionKey] = 1 ;
	## A settled death and a clean advance-pass close share one status word (spawn-ended-without-close):
	## $13 already tells them apart (S21.4), so this reads the derived word, never the raw status again.
	else if (runStateWord == "finished") sessionEnded[sessionKey] = 1 ;
	if (runStateWord == "unknown-foreign") sessionForeign[sessionKey] = 1 ;
	if (runStateWord == "unclosed" || runStateWord == "waiting") sessionOpen[sessionKey] = 1 ;
	if (runStateWord == "starting") sessionStarting[sessionKey] = 1 ;
	## AN ASK STILL WAITING IS THE SESSION'S OWN, whether its run still stands or not: it is counted by
	## the asking id its row carries, the session's own id or the id of one of its runs.
	if (($2 != "-" && ($2 in openAsker)) || ($8 != "-" && ($8 in openAsker))) sessionAsked[sessionKey] = 1 ;
	sessionRuns[sessionKey]++ ;
	## The tokens of the run, added to those of its session; a run with no known figures is counted apart.
	if (agentsDir != "" && !( ( sessionKey, $8 ) in tokenTaken )) {
		if ($8 != "-") tokenTaken[sessionKey, $8] = 1 ;
		if (tokensOfRun(agentsDir, $8, tokenWords)) { sessionTokens[sessionKey] += tokenWords[1] + tokenWords[2] + tokenWords[3] + tokenWords[4] ; sessionTokenRuns[sessionKey]++ ; }
		else sessionTokenUnknown[sessionKey]++ ;
	}
	## A run stopped on the provider's usage limit flags its session, with the date it reopens:
	## the last of its runs that says so wins, since a later refusal is the one that still holds.
	if (agentsDir != "" && !( ( sessionKey, $8 ) in limitTaken )) {
		if ($8 != "-") limitTaken[sessionKey, $8] = 1 ;
		limitText = usageLimitOfRun(agentsDir, $8) ;
		if (limitText != "" && ( !( sessionKey in sessionUsageLimit ) || limitText > sessionUsageLimit[sessionKey] )) sessionUsageLimit[sessionKey] = limitText ;
	}
	## EVERY REFUSAL IS FLAGGED, NOT ONLY THE USAGE LIMIT (sketch 3.6): the session's own total,
	## the refused count of every one of its runs added, field nineteen where the row carries
	## it, `-` where none of its runs ever were. A run with no bare id, or none refused, adds nothing.
	if (NF == 19 && $19 != "-" && $19 ~ /^[0-9]+$/) sessionRefused[sessionKey] += $19 ;
	sessionStates[sessionKey, runStateWord]++ ;
	if (sessionName[sessionKey] == "-") sessionName[sessionKey] = $16 ;
	runMinutes[runTotal] = dateMinutes(runStart[runTotal]) ;
	if (runMinutes[runTotal] >= 0 && (sessionStart[sessionKey] < 0 || runMinutes[runTotal] < sessionStart[sessionKey])) {
		sessionStart[sessionKey] = runMinutes[runTotal] ; sessionStartText[sessionKey] = runStart[runTotal] ;
	}
	endMinutes = dateMinutes(runEnd[runTotal]) ;
	if (endMinutes > sessionEnd[sessionKey]) { sessionEnd[sessionKey] = endMinutes ; sessionEndText[sessionKey] = runEnd[runTotal] ; }
	runRow[runTotal] = $8 OFS $5 OFS $6 OFS $12 OFS runStateWord OFS runStart[runTotal] OFS runEnd[runTotal] OFS $4 OFS $11 ;
}

END {
	for (sessionAt = 1 ; sessionAt <= sessionTotal ; sessionAt++) {
		sessionKey = sessionOf[sessionAt] ;
		## THE STATE OF THE SESSION IS THE STATE OF ITS AGENTS AND OF ITS QUESTIONS: live runs make it running, or
		## waiting where every one of them sits in a Wait; with none live, waiting where a run of it waits on an
		## answer, then an open record of another host's, else one still open, else every run of it failed on its
		## start, else finished. ALL AGENTS FINISHED MAKE THE SESSION FINISHED, NEVER WAITING (sketch 5.4): a question
		## still open does not hold a session whose runs have all ended -- it is counted in the counters row.
		if (sessionKey in sessionLive) {
			sessionState[sessionKey] = ( sessionLiveWaiting[sessionKey] == sessionLiveCount[sessionKey] ) ? "waiting" : "running" ;
		}
		else if (sessionKey in sessionStarting) sessionState[sessionKey] = "starting" ;
		else if ((sessionKey, "waiting") in sessionStates) sessionState[sessionKey] = "waiting" ;
		else if (sessionKey in sessionForeign) sessionState[sessionKey] = "unknown-foreign" ;
		else if (sessionKey in sessionOpen) sessionState[sessionKey] = "unclosed" ;
		else if ((sessionKey in sessionFailed) && !( sessionKey in sessionEnded )) sessionState[sessionKey] = "failed" ;
		else sessionState[sessionKey] = "finished" ;
		if (sessionState[sessionKey] == "running") sessionsRunning++ ;
		if (activeOnly && !activeState(sessionState[sessionKey])) continue ;
		if (learnOnly && sessionState[sessionKey] != "finished") continue ;
		stateTally = "" ;
		for (stateAt = 1 ; stateAt <= stateTotal ; stateAt++) {
			if ((sessionKey, stateOrder[stateAt]) in sessionStates) stateTally = stateTally ( stateTally == "" ? "" : "," ) stateOrder[stateAt] "=" sessionStates[sessionKey, stateOrder[stateAt]] ;
		}
		## The date of a state is on record for a session that ended alone: when its last run closed.
		## Then, at the end of the row, what its control thread stored and whether that thread lives;
		## its tokens; and, last, the usage-limit flag of its runs, `-` where none was refused.
		print sessionStart[sessionKey], sessionAt, 0, 0, 0, "session", sessionKey, sessionName[sessionKey], sessionState[sessionKey], ( sessionStart[sessionKey] < 0 ? "-" : sessionStartText[sessionKey] ), ( ( sessionState[sessionKey] == "finished" || sessionState[sessionKey] == "failed" ) && sessionEnd[sessionKey] >= 0 ? sessionEndText[sessionKey] : "-" ), sessionRuns[sessionKey], stateTally, sessionStored[sessionKey], sessionStoredAt[sessionKey], ( ( sessionKey in sessionById ) && ( sessionKey in controlOf ) ? controlOf[sessionKey] : "none" ), \
			( ( sessionKey in sessionTokenRuns ) ? tokensFigure(sessionTokens[sessionKey]) ( ( sessionKey in sessionTokenUnknown ) ? "+" : "" ) : "-" ), \
			( ( sessionKey in sessionUsageLimit ) ? sessionUsageLimit[sessionKey] : "-" ), \
			( ( sessionKey in sessionRefused ) && sessionRefused[sessionKey] > 0 ? sessionRefused[sessionKey] : "-" ) ;
	}
	for (runAt = 1 ; runAt <= runTotal ; runAt++) {
		sessionKey = runSession[runAt] ;
		if (activeOnly && !activeState(sessionState[sessionKey])) continue ;
		if (learnOnly && sessionState[sessionKey] != "finished") continue ;
		## A run with no date stands after the dated ones of its session.
		print sessionStart[sessionKey], sessionPlace[sessionKey], 1, ( runMinutes[runAt] < 0 ? 99999999999 : runMinutes[runAt] ), runAt, "run", sessionKey, runRow[runAt], runActivity[runAt] ;
	}
	## Paused comes with the step of pause and resume: its place is kept, and reads 0 until then.
	print -2, 0, 0, 0, 0, "counters", sessionsRunning + 0, 0, agentsWorking + 0, agentsWaiting + 0, pendingAnswers + 0, ( loadAverage == "" ? "-" : loadAverage ), ( hostName == "" ? "-" : hostName ) ;
}
