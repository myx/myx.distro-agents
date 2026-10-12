#!/usr/bin/env awk

## AgentsGrantsItemRuns.awk -- the runs of one member on one board item, read off the spawn
## records (.local/agents/spawned/*/<spawn id>.md), for AgentsTools.Grants.include: a session
## grant given to a member's run holds for its other runs on the same item in the same coworking
## session, the runs a review return or a resume starts again under a new id.
## A run's item is the first one its record names: its `spawns:` dispatch item, else its
## `spawned-by:` item. A run that names none works no item, and nothing of it is shared.
##   ENVIRON agentsGrantsItemRunsMember   the member whose runs are read: a record of another
##                                        owner is no run of it
##   ENVIRON agentsGrantsItemRunsOwn      a spawn id. With it, what that one run shares, and
##                                        nothing at all when it has no record, is another
##                                        member's, or works no item:
##                                          item <TAB> <item>
##                                          session <TAB> <coworking session id, or ->
##                                          store <TAB> <spawn id>   each other run of the member
##                                                                   on that item in that session
##                                        Without it, every run of the member that works an item:
##                                          run <TAB> <spawn id> <TAB> <item> <TAB> <coworking session id, or ->
## The coworking session reads `-` where one of these very runs started it (its id is that run's
## spawn id): that record closing is the run's end, never the session's, which the next run of
## the same work joins again. Such a session lasts while the item is open.

BEGIN {
	member = ENVIRON["agentsGrantsItemRunsMember"] ; own = ENVIRON["agentsGrantsItemRunsOwn"] ; runCount = 0 ;
}

FNR == 1 {
	front = ( $0 == "---" ) ? 1 : 2 ;
	runId = FILENAME ; sub( /^.*\//, "", runId ) ; sub( /\.md$/, "", runId ) ;
	recOwner = "" ; recSession = "" ; recSpawns = "" ; recBy = "" ;
	next ;
}
front != 1 { next ; }
$0 == "---" { front = 2 ; runKeep() ; next ; }
index( $0, "owner: " ) == 1 { recOwner = substr( $0, 8 ) ; next ; }
index( $0, "session-id: " ) == 1 { recSession = substr( $0, 13 ) ; next ; }
index( $0, "spawns: " ) == 1 { recSpawns = firstName( substr( $0, 9 ) ) ; next ; }
index( $0, "spawned-by: " ) == 1 { recBy = firstName( substr( $0, 13 ) ) ; next ; }

## A name that is one path segment and holds no TAB.
function bareName( nameText ) {
	return nameText != "" && nameText != "." && nameText != ".." && index( nameText, "/" ) == 0 && index( nameText, "\t" ) == 0 ;
}

## The first item a link field names, without its `.md`, or empty.
function firstName( linkText ) {
	sub( /[ ,].*$/, "", linkText ) ; sub( /\.md$/, "", linkText ) ;
	return bareName( linkText ) ? linkText : "" ;
}

## One record read to the end of its front matter: kept when it is a run of the member on an item.
function runKeep(    runItemName ) {
	runItemName = ( recSpawns != "" ) ? recSpawns : recBy ;
	if ( recOwner != member || runItemName == "" || !bareName( runId ) || !bareName( recSession ) ) { return ; }
	if ( !( runId in runItem ) ) { runList[++runCount] = runId ; }
	runItem[runId] = runItemName ; runSession[runId] = recSession ;
}

## The coworking session whose end ends what a run shares, or - where one of these runs started it.
function sessionOf( runName,    startedBy ) {
	startedBy = runSession[runName] ;
	return ( ( startedBy in runItem ) && runItem[startedBy] == runItem[runName] ) ? "-" : startedBy ;
}

END {
	if ( own == "" ) {
		for ( runIndex = 1 ; runIndex <= runCount ; runIndex++ ) {
			print "run\t" runList[runIndex] "\t" runItem[runList[runIndex]] "\t" sessionOf( runList[runIndex] ) ;
		}
		exit ;
	}
	if ( !( own in runItem ) ) { exit ; }
	print "item\t" runItem[own] ;
	print "session\t" sessionOf( own ) ;
	for ( runIndex = 1 ; runIndex <= runCount ; runIndex++ ) {
		runName = runList[runIndex] ;
		if ( runName != own && runItem[runName] == runItem[own] && runSession[runName] == runSession[own] ) { print "store\t" runName ; }
	}
}
