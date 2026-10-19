#!/usr/bin/env awk
# Compares each printed help entry's text against the manual's for the same header lines.
FNR == NR {
	if ( $0 ~ /^## / ) { inOptions = ( $0 ~ /^##  Options:/ ) ; headerTotal = 0 ; next ; }
	if ( ! inOptions ) { next ; }
	if ( $0 ~ /^\t\t--/ ) {
		if ( ! inHeaders ) { headerTotal = 0 ; }
		inHeaders = 1 ;
		if ( !( $0 in manualText ) ) { headerList[++headerTotal] = $0 ; manualText[$0] = "" ; }
		next ;
	}
	inHeaders = 0 ;
	for ( headerIndex = 1 ; headerIndex <= headerTotal ; headerIndex++ ) { manualText[headerList[headerIndex]] = manualText[headerList[headerIndex]] $0 "\n" ; }
	next ;
}
## Trailing blank lines are not compared: the capture above strips them from the last entry.
function flushEntry(    headerIndex, wantText ) {
	sub( /\n+$/, "", shownText ) ;
	for ( headerIndex = 1 ; headerIndex <= shownTotal ; headerIndex++ ) {
		if ( !( shownList[headerIndex] in manualText ) ) { print "FAIL\t" substr( shownList[headerIndex], 3 ) ; continue ; }
		wantText = manualText[shownList[headerIndex]] ;
		sub( /\n+$/, "", wantText ) ;
		print ( wantText == shownText ? "PASS" : "FAIL" ) "\t" substr( shownList[headerIndex], 3 ) ;
	}
	shownTotal = 0 ; shownText = "" ;
}
$0 ~ /^\t\t--/ {
	if ( ! shownHeaders ) { flushEntry() ; }
	shownHeaders = 1 ;
	shownList[++shownTotal] = $0 ;
	next ;
}
shownTotal > 0 { shownHeaders = 0 ; shownText = shownText $0 "\n" ; }
END { flushEntry() ; }
