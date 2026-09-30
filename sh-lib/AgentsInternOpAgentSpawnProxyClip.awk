#!/usr/bin/env awk
# Renders a spawn-close log's own key lines (session, model, exec, rounds, errors) clipped to 200 bytes each.
function clip( text,    cutAt ) {
	gsub( /[[:cntrl:]]/, " ", text ) ;
	gsub( /`/, "", text ) ;
	if ( length( text ) <= 200 ) { return text ; }
	cutAt = 200 ;
	while ( cutAt > 0 && substr( text, cutAt + 1, 1 ) >= "\200" && substr( text, cutAt + 1, 1 ) < "\300" ) { cutAt-- ; }
	return substr( text, 1, cutAt ) "..." ;
}
BEGIN {
	classTotal = split( "⛔ ERROR:|🚫 refused:|🔁 RETRY:|🙋 WARNING: DistroAgentsConsole:|⚠️  round cap reached|⚠️  context threshold reached|♻️  context threshold reached|⚠️  no token usage", classList, "|" ) ;
}
{ line = $0 ; sub( /^[[:space:]]+/, "", line ) ; }
index( line, "🔗 session " ) == 1 && sessionLine == "" { sessionLine = clip( line ) ; }
index( line, "🤖 " ) == 1 && modelLine == "" { modelLine = clip( line ) ; }
index( line, "DISTRO_CONSOLE_EXEC=" ) == 1 && execLine == "" { execLine = clip( line ) ; }
line == "session started" { startedLine = line ; }
index( line, "── round " ) == 1 { roundLine = clip( line ) ; }
index( line, "<- tool result (error)" ) == 1 { toolErrors++ ; }
{
	for ( classIndex = 1 ; classIndex <= classTotal ; classIndex++ ) {
		## The harness prints errors at column 1 only -- every other error class matches the stripped line instead.
		matchText = ( classIndex == 1 ) ? $0 : line ;
		if ( index( matchText, classList[classIndex] ) == 1 && ++classCount[classIndex] <= 3 ) { kept[++keptTotal] = clip( line ) ; }
	}
}
$0 ~ /^[^[:space:]]+: line [0-9]+: / && ++shellErrorCount <= 3 { kept[++keptTotal] = clip( $0 ) ; }
END {
	if ( sessionLine != "" ) { print sessionLine ; }
	if ( modelLine != "" ) { print modelLine ; }
	if ( execLine != "" ) { print execLine ; }
	if ( startedLine != "" ) { print startedLine ; }
	if ( roundLine != "" ) { print "last " roundLine ; }
	for ( keptIndex = 1 ; keptIndex <= keptTotal ; keptIndex++ ) { print kept[keptIndex] ; }
	for ( classIndex = 1 ; classIndex <= classTotal ; classIndex++ ) {
		if ( classCount[classIndex] > 3 ) { print classList[classIndex] " total " classCount[classIndex] ; }
	}
	if ( startedLine != "" ) { print "tool-result-errors: " ( toolErrors + 0 ) ; }
}
