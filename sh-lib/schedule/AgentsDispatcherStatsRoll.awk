# AgentsDispatcherStatsRoll.awk -- F7.11: the two summaries of the stats store, rolled from its runs rows (AgentsDispatcherStatsRuns.awk's columns), -v want=:
#   routines  one row for each routine, the routine being the entity and its runs attached:
#             routine runs succeeded failed running last-run-at last-run-status last-succeeded-at in cache-read cache-write out members
#             WHEN IT LAST SUCCEEDED is not when it last ran: a routine failing every night still has a recent run. A run succeeded with
#             `spawn-succeeded`, failed with `spawn-failed`, is running with `spawn-started`; any other status counts in runs only.
#   tokens    one row for each day, member, routine, preset and credential: day member routine preset credential runs in cache-read cache-write out
# The order of the rows is the caller's (sort). Times are compared as written, to the minute.

function stamp(text) { return substr( text, 1, 16 ) }
BEGIN { FS = "\t" ; OFS = "\t" }
{
	run = $1 ; member = $3 ; routine = $4 ; status = $5 ; started = $6 ; day = $8 ; preset = $12 ; credential = $13
	tin = $14 + 0 ; tcr = $15 + 0 ; tcw = $16 + 0 ; tout = $17 + 0
	if ( want == "tokens" ) {
		key = day OFS member OFS routine OFS preset OFS credential
		tRuns[key]++ ; tIn[key] += tin ; tCr[key] += tcr ; tCw[key] += tcw ; tOut[key] += tout
		next
	}
	rRuns[routine]++ ; rIn[routine] += tin ; rCr[routine] += tcr ; rCw[routine] += tcw ; rOut[routine] += tout
	if ( status == "spawn-succeeded" ) { rOk[routine]++ } else if ( status == "spawn-failed" ) { rBad[routine]++ } else if ( status == "spawn-started" ) { rRun[routine]++ }
	if ( started != "-" && stamp( started ) >= rLast[routine] ) { rLast[routine] = stamp( started ) ; rLastStatus[routine] = status }
	if ( status == "spawn-succeeded" && started != "-" && stamp( started ) >= rLastOk[routine] ) { rLastOk[routine] = stamp( started ) }
	if ( index( "," rMembers[routine] ",", "," member "," ) == 0 ) { rMembers[routine] = rMembers[routine] ( rMembers[routine] == "" ? "" : "," ) member }
}
END {
	if ( want == "tokens" ) {
		for ( key in tRuns ) { print key, tRuns[key], tIn[key], tCr[key], tCw[key], tOut[key] }
		exit
	}
	for ( routine in rRuns ) {
		print routine, rRuns[routine], rOk[routine] + 0, rBad[routine] + 0, rRun[routine] + 0, ( rLast[routine] == "" ? "-" : rLast[routine] ), ( rLast[routine] == "" ? "-" : rLastStatus[routine] ), ( rLastOk[routine] == "" ? "-" : rLastOk[routine] ), rIn[routine], rCr[routine], rCw[routine], rOut[routine], rMembers[routine]
	}
}
