#!/usr/bin/awk -f
##
## AgentsManagerSessionScope.awk -- whether a session registry still holds its store as the
## store is now, and, of the spawned-sessions one, the rows of the session an id names: for
## AgentsToolsManagerSessionScope (AgentsTools.ManagerSession.include). Called with two inputs,
## in this order: the registry file, then, on standard input, the store as the shell lists it
## now, a path a line. Loaded after AgentsRegistryHeaderRows.awk, for its reading of a header
## (registryFrontmatterRead, registryHeader): no second reader of a record is written here.
##
## NO TIME IS COMPARED. A record added to a sandbox folder moves the time of that folder alone,
## which no registry row names; the shell's newer-than test counts whole seconds, so a change
## made in the second a registry was built reads no newer than it; and a registry carries the
## moment its rebuild ended, not the moment it read each folder. Names and counts are compared.
##
##   -v scopeMode=runs   the spawned-sessions registry, and the listing of <store>/*/ and
##       <store>/*/*.md: every sandbox folder, then every record file in one. In the
##       environment MDAT_MANAGER_STORE is `<store>/` and MDAT_MANAGER_ID the id asked for;
##       -v ownOnly=1 takes the id as a run's own alone. Prints `fresh` where the registry
##       has every folder the store has and no other, each with as many record rows as the
##       folder has record files, and every row of sixteen columns; `stale` otherwise. Then,
##       where a row carries the id: the run chosen (`-` for every run of the session), the
##       session, and the rows of that session as they stand in the file.
##   -v scopeMode=asks   the pending-replies registry, and the listing of <store>/*.md, the
##       ask records. MDAT_MANAGER_STORE is `<store>/`, MDAT_MANAGER_IDS ` <id> <id> ... `:
##       the session and the own id of each of its runs, one of which an ask of the session
##       carries. Prints `fresh` where the registry has an `ask` row for every ask file, by
##       its name, and no other, and each ask of those ids says in its record, now, the status
##       its row says; `stale` otherwise. The row of a board item is not looked at: it is no
##       file of this store.
##
## A name the registry cannot hold as one word, or a pattern that matched an entry the
## registry does not count, reads `stale` at every call: it costs a rebuild, never a row.
##

BEGIN {
	storeDir = ENVIRON["MDAT_MANAGER_STORE"] ;
	storeAt = length(storeDir) ;
	wantId = ENVIRON["MDAT_MANAGER_ID"] "" ;
	wantIds = ENVIRON["MDAT_MANAGER_IDS"] ;
}

scopeMode == "runs" && FILENAME == ARGV[1] {
	if (NF < 11) next ;
	rowText[++rowTotal] = $0 ;
	rowKey[rowTotal] = ( $2 == "-" ? $1 : $2 ) "" ;
	if (NF < 16) rowsOld = 1 ;
	heldFolder[$1] = 1 ;
	## The row of an empty sandbox is a folder with no record.
	if (!( $6 == "no-session-record" && $2 == "-" && $8 == "-" )) heldRecords[$1]++ ;
	if (!ownOnly && rowKey[rowTotal] == wantId) asSession = 1 ;
	if ($8 != "-" && ( $8 "" ) == wantId && runKey == "") runKey = rowKey[rowTotal] ;
	next ;
}

scopeMode == "runs" {
	if (substr($0, 1, storeAt) != storeDir) next ;
	nowPath = substr($0, storeAt + 1) ;
	slashAt = index(nowPath, "/") ;
	if (slashAt < 2) next ;
	nowName = substr(nowPath, 1, slashAt - 1) ;
	## A pattern that matched nothing stands as it was written: no folder, or no record in any.
	if (nowName == "*") next ;
	if (slashAt == length(nowPath)) nowFolder[nowName] = 1 ;
	else nowRecords[nowName]++ ;
	next ;
}

scopeMode == "asks" && FILENAME == ARGV[1] {
	if ($2 != "ask") next ;
	heldAsk[$1] = 1 ;
	if ($3 != "-" && index(wantIds, " " $3 " ") > 0) { askTotal++ ; askName[askTotal] = $1 ; askStatus[askTotal] = $5 ; }
	next ;
}

scopeMode == "asks" {
	if (substr($0, 1, storeAt) != storeDir) next ;
	nowName = substr($0, storeAt + 1) ;
	if (nowName == "" || nowName == "*.md") next ;
	nowAsk[nowName] = 1 ;
	next ;
}

END {
	if (scopeMode == "runs") {
		scopeStale = rowsOld ;
		for (nowName in nowFolder) { if (!( nowName in heldFolder ) || nowRecords[nowName] + 0 != heldRecords[nowName] + 0) scopeStale = 1 ; }
		for (nowName in heldFolder) { if (!( nowName in nowFolder )) scopeStale = 1 ; }
		print ( scopeStale ? "stale" : "fresh" ) ;
		if (asSession) { pickKey = wantId ; pickRun = "-" ; }
		else if (runKey != "") { pickKey = runKey ; pickRun = wantId ; }
		else exit 0 ;
		print pickRun ; print pickKey ;
		for (rowAt = 1 ; rowAt <= rowTotal ; rowAt++) { if (rowKey[rowAt] == pickKey) print rowText[rowAt] ; }
		exit 0 ;
	}
	if (scopeMode == "asks") {
		scopeStale = 0 ;
		for (nowName in nowAsk) { if (!( nowName in heldAsk )) scopeStale = 1 ; }
		for (nowName in heldAsk) { if (!( nowName in nowAsk )) scopeStale = 1 ; }
		## What each ask of the session says now, read as the registry reads a header.
		for (askAt = 1 ; askAt <= askTotal && !scopeStale ; askAt++) {
			registryFrontmatterRead(storeDir askName[askAt]) ;
			if (registryHeader("status") != askStatus[askAt]) scopeStale = 1 ;
		}
		print ( scopeStale ? "stale" : "fresh" ) ;
	}
}
