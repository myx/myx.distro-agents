#!/usr/bin/awk -f
##
## AgentsManagerDateMinutes.awk -- the minutes of a date as a registry keeps it, for the readers of the runs: ONE
## READING of such a date, so that the order the list gives its sessions by and the question whether a routine
## completed since a time are decided by the same calendar. Functions only: loaded with -f before the awk that calls
## it (AgentsManagerSessionRows.awk, AgentsDispatcherCompleted.awk).
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
