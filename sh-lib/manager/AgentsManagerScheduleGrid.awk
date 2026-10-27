# AgentsManagerScheduleGrid.awk -- the week grid of --manager-schedule-read: one row for each weekday and hour,
# `cell<TAB><weekday><TAB><hour 00-23><TAB><flags, comma-separated, or ->`. Reads nothing from a file; every value
# comes in through ENVIRON, never -v (MAGIC.md): SCH_WORKTIME (`<start> <until> <days>`), SCH_WEEKEND (a days list),
# SCH_EPOCH (now), SCH_OFFSET (the zone's offset in seconds), SCH_TODAY (0-6, sunday first), and the overrides as the
# settings hold them -- SCH_HOLIDAYS, SCH_EMERGENCY, SCH_OVERTIME, SCH_LEARNING: `on`, `until <epoch>`, or empty.
# A cell holds `worktime` where the hour overlaps the planned worktime of that weekday (and no holiday holds in it),
# `weekend` where the weekday is a weekend day, and an override's name where that override holds at some time of the
# hour that has not passed yet.

function timeSeconds( text ) {
	if ( text !~ /^([01][0-9]|2[0-3]):[0-5][0-9]$/ ) return -1
	return substr( text, 1, 2 ) * 3600 + substr( text, 4, 2 ) * 60
}

function dayIn( days, name,    parts, count, at, inWeekend ) {
	if ( days == "daily" ) return 1
	if ( days == "workdays" || days == "weekend" ) {
		inWeekend = ( "," weekendDays "," ) ~ ( "," name "," )
		return days == "weekend" ? inWeekend : ! inWeekend
	}
	return ( "," days "," ) ~ ( "," name "," )
}

# Whether an override holds at some time in [from, to): `on` always, `until E` while E is later than from.
function holds( setting, from, to,    until ) {
	if ( setting == "on" ) return 1
	if ( setting ~ /^until [0-9]+$/ ) { until = substr( setting, 7 ) + 0 ; return until > from }
	return 0
}

BEGIN {
	split( "sun mon tue wed thu fri sat", names, " " )
	split( "mon tue wed thu fri sat sun", order, " " )
	split( ENVIRON["SCH_WORKTIME"], work, " " )
	workStart = timeSeconds( work[1] ) ; workUntil = timeSeconds( work[2] ) ; workDays = work[3]
	weekendDays = ENVIRON["SCH_WEEKEND"]
	epoch = ENVIRON["SCH_EPOCH"] + 0 ; offset = ENVIRON["SCH_OFFSET"] + 0 ; today = ENVIRON["SCH_TODAY"] + 0
	todayStart = int( ( epoch + offset ) / 86400 ) * 86400 - offset
	for ( at = 1 ; at <= 7 ; at++ ) {
		name = order[at]
		for ( number = 0 ; number < 7 ; number++ ) if ( names[number + 1] == name ) break
		dayStart = todayStart + ( ( number - today + 7 ) % 7 ) * 86400
		for ( hour = 0 ; hour < 24 ; hour++ ) {
			from = dayStart + hour * 3600 ; to = from + 3600
			flags = ""
			held = ( to > epoch ) ? 1 : 0
			if ( held && holds( ENVIRON["SCH_HOLIDAYS"], from, to ) ) flags = flags ",holidays"
			if ( workStart >= 0 && workUntil >= 0 && dayIn( workDays, name ) && workStart < ( hour + 1 ) * 3600 && workUntil > hour * 3600 && flags !~ /holidays/ ) flags = flags ",worktime"
			if ( ( "," weekendDays "," ) ~ ( "," name "," ) ) flags = flags ",weekend"
			if ( held && holds( ENVIRON["SCH_EMERGENCY"], from, to ) ) flags = flags ",emergency"
			if ( held && holds( ENVIRON["SCH_OVERTIME"], from, to ) ) flags = flags ",overtime"
			if ( held && ENVIRON["SCH_LEARNING"] == "on" ) flags = flags ",learning"
			printf "cell\t%s\t%02d\t%s\n", name, hour, ( flags == "" ? "-" : substr( flags, 2 ) )
		}
	}
}
