#!/usr/bin/awk -f
##
## AgentsDispatcherCompleted.awk -- the questions of TeamDispatcher about the run history (--routine-completed and the autorun's
## --routine-due, DistroAgentsDispatcher.fn.sh): did a run of one routine close `spawn-succeeded` in a stretch of time, or did one
## start in it. Called by AgentsTools.Dispatcher.include with dateMinutes loaded before it (AgentsManagerDateMinutes.awk). The input
## is the spawn records to read, one path a line. In the environment: DISPATCH_ROUTINE, the routine's file name as a record writes it
## (`routine:`); DISPATCH_MODE, `completed` (the default: a run that closed spawn-succeeded, by its resolved-at) or `started` (a
## run of any status, by its started-at); the stretch's start, DISPATCH_SINCE_MINUTES (minutes since 1970, UTC) or else
## DISPATCH_SINCE, `YYYY-MM-DD HH:MM`, with DISPATCH_ZONE, the offset that time is in, `+0300`; and, where there is one, its end,
## DISPATCH_UNTIL_MINUTES, which no run may reach.
##
## It prints the one run whose time is the latest of those that qualify, as a row of the form the list's run rows have (dates as a
## registry keeps them): `run`, the session id, the spawn id, the member, the status, started-at, resolved-at and the routine. It
## ends 1, printing nothing, where none qualifies. For `completed` a run still open, one that failed, one that ended without a
## close, and a record with no date that can be read, are none.
##

## A date as a record writes it, `2026-10-19 09:30 +0300`, as a registry keeps it, `2026-10-19_09:30_+0300`.
function registryDate(dateText) {
	gsub(/ /, "_", dateText) ;
	return dateText ;
}

BEGIN {
	wantRoutine = ENVIRON["DISPATCH_ROUTINE"] ;
	wantMode = ( ENVIRON["DISPATCH_MODE"] == "started" ? "started" : "completed" ) ;
	if (ENVIRON["DISPATCH_SINCE_MINUTES"] != "") sinceMinutes = ENVIRON["DISPATCH_SINCE_MINUTES"] + 0 ;
	else sinceMinutes = dateMinutes( registryDate( ENVIRON["DISPATCH_SINCE"] " " ENVIRON["DISPATCH_ZONE"] ) ) ;
	untilMinutes = ( ENVIRON["DISPATCH_UNTIL_MINUTES"] != "" ? ENVIRON["DISPATCH_UNTIL_MINUTES"] + 0 : -1 ) ;
	bestMinutes = -1 ;
}

NF {
	recordFile = $0 ;
	fenceCount = 0 ;
	recordSession = "" ; recordSpawn = "" ; recordOwner = "" ; recordStatus = "" ; recordStarted = "" ; recordResolved = "" ; recordRoutine = "" ;
	while (( getline recordLine < recordFile ) > 0) {
		if (recordLine == "---") {
			fenceCount++ ;
			if (fenceCount == 2) break ;
			continue ;
		}
		if (fenceCount != 1) continue ;
		colonAt = index( recordLine, ": " ) ;
		if (colonAt == 0) continue ;
		recordKey = substr( recordLine, 1, colonAt - 1 ) ;
		recordValue = substr( recordLine, colonAt + 2 ) ;
		if (recordKey == "session-id") recordSession = recordValue ;
		else if (recordKey == "spawn-id") recordSpawn = recordValue ;
		else if (recordKey == "owner") recordOwner = recordValue ;
		else if (recordKey == "status") recordStatus = recordValue ;
		else if (recordKey == "started-at") recordStarted = recordValue ;
		else if (recordKey == "resolved-at") recordResolved = recordValue ;
		else if (recordKey == "routine") recordRoutine = recordValue ;
	}
	close( recordFile ) ;
	if (recordRoutine != wantRoutine) next ;
	if (wantMode == "completed") {
		if (recordStatus != "spawn-succeeded") next ;
		closedMinutes = dateMinutes( registryDate( recordResolved ) ) ;
	} else {
		closedMinutes = dateMinutes( registryDate( recordStarted ) ) ;
	}
	if (closedMinutes < 0 || closedMinutes < sinceMinutes) next ;
	if (untilMinutes >= 0 && closedMinutes >= untilMinutes) next ;
	if (closedMinutes > bestMinutes) {
		bestMinutes = closedMinutes ;
		bestRow = "run\t" recordSession "\t" recordSpawn "\t" recordOwner "\t" recordStatus "\t" registryDate( recordStarted ) "\t" registryDate( recordResolved ) "\t" recordRoutine ;
	}
}

END {
	if (bestMinutes < 0) exit 1 ;
	print bestRow ;
}
