#!/usr/bin/awk -f
##
## AgentsManagerSessionTokens.awk -- the token figures of one run, for --manager-session-read
## and --manager-session-list: ONE READING for both, so that the total of a session is the sum
## of exactly the figures the read shows for each of its runs. Functions only: loaded with -f
## before the awk that calls it (AgentsManagerSessionRead.awk, AgentsManagerSessionRows.awk).
##
## The figures of a run are its own store's: the first line of sessions/<spawn id>/tokens,
## `<in> <cache-read> <cache-write> <out>`, the running sum the transcript keeps while the run
## works, which stays there once the run has ended (AgentsTools.SessionTranscript.include). No
## registry holds them. One small file a run is opened for them, where the run has one, and no
## transcript and no record.
##

## The four figures of one run into tokenWords[1..4], each as the `store` row of the read
## prints it: a number, or `-` for one that is no number; all four `-` where the store has
## no such file, or its line holds fewer than four words. Returns 1 where all four are
## numbers: only such a run is taken into a total, and any other is a run whose figures are
## not known. agentsDir is the workspace's agents folder, $MMDAPP/.local/agents.
function tokensOfRun(agentsDir, spawnId, tokenWords,    tokenPath, tokenText, tokenAt, tokenKnown) {
	tokenText = "" ;
	if (spawnId != "" && spawnId != "-" && spawnId != "." && spawnId != ".." && index(spawnId, "/") == 0) {
		tokenPath = agentsDir "/sessions/" spawnId "/tokens" ;
		if (( getline tokenText < tokenPath ) < 1) tokenText = "" ;
		close(tokenPath) ;
	}
	if (split(tokenText, tokenWords, " ") < 4) { for (tokenAt = 1 ; tokenAt <= 4 ; tokenAt++) tokenWords[tokenAt] = "-" ; }
	tokenKnown = 1 ;
	for (tokenAt = 1 ; tokenAt <= 4 ; tokenAt++) { if (tokenWords[tokenAt] !~ /^[0-9]+$/) { tokenWords[tokenAt] = "-" ; tokenKnown = 0 ; } }
	return tokenKnown ;
}

## A sum of figures as it is printed: a whole number, however large.
function tokensFigure(sumValue) {
	return sprintf("%.0f", sumValue) ;
}
