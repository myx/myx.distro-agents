#!/usr/bin/env awk
# True when candidate is strictly newer than floorTs (both Slack ts values).
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
	if ( fracOf(candidate) > fracOf(floorTs) ) { exit 0 ; }
	exit 1
}
