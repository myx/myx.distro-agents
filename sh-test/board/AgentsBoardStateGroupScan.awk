## AgentsBoardStateGroupScan.awk -- one row a group of board states named in code outside the states
## include, as `<path>:<line>: <the run>`.
##
## A GROUP is two or more different states of the one list written as one set, in either of two
## forms: a family of `|`-joined alternatives whose every member is a state, and a run of states
## joined by single spaces. The `board:` prefix of a wait source is dropped before the atoms are
## read, so `board:review|board:parked` is the same group as `review|parked`. A `|`-family holding
## one word that is no state is a vocabulary of its own, no row: the harness's run states are one.
## A comment line is skipped, and so is the states include itself (skipPath).
BEGIN {
	scanCount = split( states, scanState, " " )
	for ( scanAt = 1 ; scanAt <= scanCount ; scanAt++ ) { scanIs[scanState[scanAt]] = 1 }
}
{
	if ( FILENAME == skipPath ) next
	scanLine = $0
	scanProbe = scanLine ; sub( /^[ \t]+/, "", scanProbe )
	if ( scanProbe ~ /^#/ ) next
	## The `board:` prefix of a wait source is no part of the state's name.
	for ( scanAt = 1 ; scanAt <= scanCount ; scanAt++ ) { gsub( "board:" scanState[scanAt], scanState[scanAt], scanLine ) }
	## The atoms: each word, and the characters that follow it up to the next word.
	scanLen = length( scanLine ) ; scanAtoms = 0 ; scanWordNow = ""
	for ( scanAt = 1 ; scanAt <= scanLen ; scanAt++ ) {
		scanChar = substr( scanLine, scanAt, 1 )
		if ( scanChar ~ /[A-Za-z0-9_-]/ ) { scanWordNow = scanWordNow scanChar ; continue }
		if ( scanWordNow != "" ) { scanAtoms++ ; scanAtom[scanAtoms] = scanWordNow ; scanJoin[scanAtoms] = scanChar ; scanWordNow = "" }
		else if ( scanAtoms > 0 ) { scanJoin[scanAtoms] = scanJoin[scanAtoms] scanChar }
	}
	if ( scanWordNow != "" ) { scanAtoms++ ; scanAtom[scanAtoms] = scanWordNow ; scanJoin[scanAtoms] = "" }
	scanAt = 1
	while ( scanAt <= scanAtoms ) {
		if ( ! ( scanAtom[scanAt] in scanIs ) ) { scanAt++ ; continue }
		## A `|`-family: every member of it must be a state, else the whole family is foreign.
		if ( scanJoin[scanAt] == "|" ) {
			scanEnd = scanAt ; scanAllStates = 1
			while ( scanEnd < scanAtoms && scanJoin[scanEnd] == "|" ) {
				scanEnd++
				if ( ! ( scanAtom[scanEnd] in scanIs ) ) { scanAllStates = 0 }
			}
			if ( scanAllStates ) {
				scanRun = scanAtom[scanAt]
				for ( scanStep = scanAt + 1 ; scanStep <= scanEnd ; scanStep++ ) { scanRun = scanRun "|" scanAtom[scanStep] }
				delete scanRunSeen ; scanRunSeen[scanAtom[scanAt]] = 1 ; scanDiff = 1
				for ( scanStep = scanAt + 1 ; scanStep <= scanEnd ; scanStep++ ) { if ( ! ( scanAtom[scanStep] in scanRunSeen ) ) { scanRunSeen[scanAtom[scanStep]] = 1 ; scanDiff++ } }
				if ( scanDiff >= 2 ) printf "%s:%d: %s\n", FILENAME, FNR, scanRun
			}
			scanAt = scanEnd + 1
			continue
		}
		## A space-joined run of states, which ends at the first word that is no state.
		scanEnd = scanAt
		while ( scanEnd < scanAtoms && scanJoin[scanEnd] == " " && ( scanAtom[scanEnd + 1] in scanIs ) && scanJoin[scanEnd + 1] != "|" ) { scanEnd++ }
		if ( scanEnd > scanAt ) {
			scanRun = scanAtom[scanAt]
			for ( scanStep = scanAt + 1 ; scanStep <= scanEnd ; scanStep++ ) { scanRun = scanRun " " scanAtom[scanStep] }
			printf "%s:%d: %s\n", FILENAME, FNR, scanRun
		}
		scanAt = scanEnd + 1
	}
}
