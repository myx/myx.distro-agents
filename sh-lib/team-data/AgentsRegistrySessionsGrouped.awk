#!/usr/bin/env awk
# Groups AgentsToolsRegistryRenderSpawnedSessions rows by session-id. -v filterState=<state|empty>.
$1 == "" { next ; }
{
	sid = $2 ; ws = $11 ; host = $4 ; owner = $5 ; thread = $10 ; state = $13
	if ( !(sid in seen) ) { order[++orderTotal] = sid ; seen[sid] = 1 ; }
	count[sid]++
	if ( workspace[sid] == "" ) { workspace[sid] = ws ; }
	else if ( workspace[sid] != ws ) { workspace[sid] = "mixed" ; }
	if ( hostOf[sid] == "" ) { hostOf[sid] = host ; }
	else if ( hostOf[sid] != host ) { hostOf[sid] = "mixed" ; }
	if ( thread != "-" && threadOf[sid] == "" ) { threadOf[sid] = thread ; }
	if ( index( "," ownerSeen[sid] "," , "," owner "," ) == 0 ) {
		ownerSeen[sid] = ( ownerSeen[sid] == "" ) ? owner : ownerSeen[sid] "," owner
	}
	key = sid SUBSEP state
	stateCount[key]++
	if ( !(state in stateSeen) ) { stateOrder[++stateTotal] = state ; stateSeen[state] = 1 ; }
}
END {
	if ( orderTotal == 0 ) { print "**NOTE:** no spawned sessions -- the sandbox root exists and holds none" ; exit ; }
	printedTotal = 0
	for ( i = 1 ; i <= orderTotal ; i++ ) {
		sid = order[i]
		# running also keeps sessions with a waiting row -- a waiting agent is still in flight.
		if ( filterState == "running" ) {
			if ( !( (sid SUBSEP "running") in stateCount ) && !( (sid SUBSEP "waiting") in stateCount ) ) { continue ; }
		} else if ( filterState != "" && !( (sid SUBSEP filterState) in stateCount ) ) { continue ; }
		printedTotal++
		tally = ""
		for ( j = 1 ; j <= stateTotal ; j++ ) {
			st = stateOrder[j]
			key = sid SUBSEP st
			if ( key in stateCount ) {
				tally = ( tally == "" ) ? st "=" stateCount[key] : tally "," st "=" stateCount[key]
			}
		}
		threadVal = ( threadOf[sid] == "" ) ? "-" : threadOf[sid]
		printf "%s %s %s %s %s %s %s\n", sid, workspace[sid], hostOf[sid], ownerSeen[sid], count[sid], threadVal, tally
	}
	if ( printedTotal == 0 ) { print "**NOTE:** no sessions match this view's own state filter -- other spawned sessions exist, filtered out here" ; }
}
