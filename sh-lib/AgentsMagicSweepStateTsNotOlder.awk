#!/usr/bin/env awk
# True when candidate is not older than floorTs (both Slack ts values).
function secOf(v) {
	sub(/\..*$/, "", v)
	if ( v == "" ) { v = "0" ; }
	return v + 0
}
function fracOf(v,   f) {
	f = v
	if ( f !~ /\./ ) { return "000000" ; }
	sub(/^[^.]*\./, "", f)
	while ( length(f) < 6 ) { f = f "0" ; }
	return substr(f, 1, 6)
}
BEGIN {
	candidateSec = secOf(candidate)
	floorSec = secOf(floorTs)
	if ( candidateSec > floorSec ) { exit 0 ; }
	if ( candidateSec < floorSec ) { exit 1 ; }
	candidateFrac = fracOf(candidate)
	floorFrac = fracOf(floorTs)
	if ( candidateFrac < floorFrac ) { exit 1 ; }
	exit 0
}
