#!/usr/bin/env awk
# Prints each pending-reply record matching the owner/open filters, with an optional trailing count.
function resetRecord() {
	dashes = 0 ; first = "" ; haveRecord = 1 ; split("", val) ;
	fileId = FILENAME ; sub(/^.*\//, "", fileId) ; sub(/\.md$/, "", fileId) ;
}
function flush(   keyIdx, keyName) {
	if ( wantOwner != "" && val["owner"] != wantOwner ) { return ; }
	if ( openOnly != "" && val["status"] != "reply-pending" ) { return ; }
	printf "PENDING-REPLY: %s\n", fileId ;
	for ( keyIdx = 1 ; keyIdx <= keyCount ; keyIdx++ ) {
		keyName = keys[keyIdx] ;
		if ( keyName in val ) { printf "%s: %s\n", keyName, val[keyName] ; }
	}
	printf "question: %s\n\n", first ;
	shown++ ;
}
BEGIN { keyCount = split("status owner kind question-tag channel question-ts thread-ts address-to session-id asked-at resolved-at verdict answered-by amended-at amended-by amend-reason amended-from amended-from-answered-by", keys, " ") ; }
FNR == 1 { if ( haveRecord ) { flush() ; } resetRecord() ; }
$0 == "---" { dashes++ ; next ; }
dashes == 1 {
	colon = index($0, ": ") ;
	if ( colon > 1 ) {
		keyName = substr($0, 1, colon - 1) ;
		if ( ! ( keyName in val ) ) { val[keyName] = substr($0, colon + 2) ; }
	}
	next ;
}
dashes >= 2 && first == "" && $0 !~ /^#/ && $0 !~ /^[ \t]*$/ { first = $0 ; }
END {
	if ( haveRecord ) { flush() ; }
	if ( countLine != "" ) { printf "PENDING-REPLIES: %d\n", shown + 0 ; }
}
