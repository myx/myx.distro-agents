#!/usr/bin/awk -f
##
## AgentsManagerSessionTokens.awk -- the token figures of one run, for --manager-session-read
## and --manager-session-list: ONE READING for both, so that the total of a session is the sum
## of exactly the figures the read shows for each of its runs. Functions only: loaded with -f
## before the awk that calls it (AgentsManagerSessionRead.awk, AgentsManagerSessionRows.awk).
##
## The figures of a run are its own store's `tokens` fact, `<in> <cache-read> <cache-write> <out>`,
## the running sum the transcript keeps while the run works, which stays there once the run has
## ended (AgentsTools.SessionTranscript.include). No registry holds them. The store's owner hands
## the facts of every run in one walk (AgentsSessionRunFacts), the first input of the awk that
## calls these; no file of a store is opened here.
##

## One row of the store's facts, `<id> TAB <fact> TAB <value>` (AgentsSessionRunFacts), kept in order:
## storeFactCount[id, fact] values, each in storeFactValue[id, fact, n]. The value is the rest of
## the row, TABs and all.
function storeFactTake(rowText,    firstAt, secondAt, factId, factName) {
	firstAt = index(rowText, "\t") ; if (firstAt < 2) return ;
	factId = substr(rowText, 1, firstAt - 1) ;
	rowText = substr(rowText, firstAt + 1) ;
	secondAt = index(rowText, "\t") ; if (secondAt < 2) return ;
	factName = substr(rowText, 1, secondAt - 1) ;
	storeFactValue[factId, factName, ++storeFactCount[factId, factName]] = substr(rowText, secondAt + 1) ;
}

## The first value of one fact of an id, empty where its store keeps none.
function storeFact(factId, factName) {
	return ( ( ( factId, factName ) in storeFactCount ) ? storeFactValue[factId, factName, 1] : "" ) ;
}

## Whether the store of that id keeps that fact at all, an empty file one of them.
function storeFactSeen(factId, factName) {
	return ( ( factId, factName ) in storeFactCount ) ;
}

## The four figures of one run into tokenWords[1..4], each as the `store` row of the read
## prints it: a number, or `-` for one that is no number; all four `-` where the store has
## no such fact, or its line holds fewer than four words. Returns 1 where all four are
## numbers: only such a run is taken into a total, and any other is a run whose figures are
## not known.
function tokensOfRun(spawnId, tokenWords,    tokenText, tokenAt, tokenKnown) {
	tokenText = storeFact(spawnId, "tokens") ;
	if (split(tokenText, tokenWords, " ") < 4) { for (tokenAt = 1 ; tokenAt <= 4 ; tokenAt++) tokenWords[tokenAt] = "-" ; }
	tokenKnown = 1 ;
	for (tokenAt = 1 ; tokenAt <= 4 ; tokenAt++) { if (tokenWords[tokenAt] !~ /^[0-9]+$/) { tokenWords[tokenAt] = "-" ; tokenKnown = 0 ; } }
	return tokenKnown ;
}

## A sum of figures as it is printed: a whole number, however large.
function tokensFigure(sumValue) {
	return sprintf("%.0f", sumValue) ;
}
