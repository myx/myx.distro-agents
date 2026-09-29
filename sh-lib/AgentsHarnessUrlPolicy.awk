#!/usr/bin/env awk

function urlParts(urlText, partsOut,   restText, hostText, cutPos) {
	restText = urlText
	partsOut["scheme"] = ""
	if ( match(restText, /^[A-Za-z][A-Za-z0-9+.-]*:\/\//) ) {
		partsOut["scheme"] = tolower(substr(restText, 1, RLENGTH - 3))
		restText = substr(restText, RLENGTH + 1)
	}
	cutPos = match(restText, /[\/?#]/)
	if ( cutPos > 0 ) {
		hostText = substr(restText, 1, cutPos - 1)
		restText = substr(restText, cutPos)
	} else {
		hostText = restText
		restText = ""
	}
	sub(/^.*@/, "", hostText)
	sub(/:[0-9]*$/, "", hostText)
	sub(/\.$/, "", hostText)
	partsOut["host"] = tolower(hostText)
	if ( substr(restText, 1, 1) != "/" ) {
		restText = "/" restText
	}
	partsOut["path"] = restText
}

function prefixHit(listText,   listCount, listItems, listIndex, entryParts) {
	listCount = split(listText, listItems)
	for ( listIndex = 1 ; listIndex <= listCount ; listIndex++ ) {
		urlParts(listItems[listIndex], entryParts)
		if ( entryParts["host"] == "" ) { continue ; }
		if ( entryParts["scheme"] != "" && entryParts["scheme"] != urlScheme ) { continue ; }
		if ( urlHost != entryParts["host"] && substr(urlHost, length(urlHost) - length(entryParts["host"])) != "." entryParts["host"] ) { continue ; }
		if ( index(urlPath, entryParts["path"]) != 1 ) { continue ; }
		return 1
	}
	return 0
}

BEGIN {
	urlParts(ENVIRON["WEB_URL"], urlInfo)
	urlScheme = urlInfo["scheme"]
	urlHost = urlInfo["host"]
	urlPath = urlInfo["path"]
	if ( urlHost == "" ) { print "unlisted" ; }
	else if ( prefixHit(ENVIRON["WEB_DENY"]) ) { print "denied" ; }
	else if ( prefixHit(ENVIRON["WEB_ALLOW"]) ) { print "allowed" ; }
	else { print "unlisted" ; }
}
