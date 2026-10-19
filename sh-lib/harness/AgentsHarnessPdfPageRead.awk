#!/usr/bin/env awk
# Renders PDF pages (already form-feed-split) with a "--- page N ---" header per page, under a byte cap.
{
	sub(/\n+$/, "")
	pageNo = firstPage + NR - 1
	lineTotal = split("--- page " pageNo " ---\n" $0, pageLines, "\n")
	for ( lineNo = 1 ; lineNo <= lineTotal ; lineNo++ ) {
		textBytes = textBytes + length(pageLines[lineNo]) + 1
		if ( textBytes <= byteCap ) shownText = shownText pageLines[lineNo] "\n"
		else if ( !cutPage ) cutPage = pageNo
	}
}
END {
	if ( pagesAsked == "" && NR > 10 ) { print "ERROR: this PDF has more than 10 pages, so pages is required -- pass a range such as 1-5, at most 20 pages per request" ; exit ; }
	printf "%s", shownText
	if ( cutPage && cutPage == firstPage ) printf "... page %d alone is over the %d-byte cap of this reader, so the rest of it cannot be returned here ...\n", cutPage, byteCap
	else if ( cutPage ) printf "... TRUNCATED at page %d: continue with pages %d-%d ...\n", cutPage, cutPage, firstPage + NR - 1
}
