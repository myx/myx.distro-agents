#!/usr/bin/env awk
# True (exit 0) when SEARCH_URL's host passes the SEARCH_ALLOWED/SEARCH_BLOCKED domain lists.
BEGIN {
	urlHost = tolower(ENVIRON["SEARCH_URL"]) ; sub(/^[a-z][a-z0-9+.-]*:\/\//, "", urlHost) ; sub(/[\/?#].*$/, "", urlHost) ; sub(/^.*@/, "", urlHost) ; sub(/:[0-9]*$/, "", urlHost) ; sub(/\.$/, "", urlHost) ;
	allowCount = split(tolower(ENVIRON["SEARCH_ALLOWED"]), allowList, "\n") ; blockCount = split(tolower(ENVIRON["SEARCH_BLOCKED"]), blockList, "\n") ;
	keepIt = 1 ; allowSeen = 0 ; allowHit = 0 ;
	for ( listIndex = 1 ; listIndex <= allowCount ; listIndex++ ) { domainName = allowList[listIndex] ; sub(/^\*?\./, "", domainName) ; sub(/\.$/, "", domainName) ; if ( domainName == "" ) { continue ; } ; allowSeen = 1 ; if ( urlHost == domainName || substr(urlHost, length(urlHost) - length(domainName)) == "." domainName ) { allowHit = 1 ; } ; }
	if ( ENVIRON["SEARCH_ALWAYS"] == "allowed" ) { allowHit = 1 ; }
	if ( allowSeen && !allowHit ) { keepIt = 0 ; }
	for ( listIndex = 1 ; listIndex <= blockCount ; listIndex++ ) { domainName = blockList[listIndex] ; sub(/^\*?\./, "", domainName) ; sub(/\.$/, "", domainName) ; if ( domainName == "" ) { continue ; } ; if ( urlHost == domainName || substr(urlHost, length(urlHost) - length(domainName)) == "." domainName ) { keepIt = 0 ; } ; }
	exit ( keepIt ? 0 : 1 ) ;
}
