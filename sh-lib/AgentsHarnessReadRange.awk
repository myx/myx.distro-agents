#!/usr/bin/env awk
# Prints lines fromLine..fromLine+lineLimit under a byte cap, with a truncation/EOF footer.
NR >= fromLine && ( lineLimit == 0 || NR < fromLine + lineLimit ) {
	shownLine = ( numberLines == "" ) ? $0 : sprintf("%6d\t%s", NR, $0)
	rangeBytes = rangeBytes + length(shownLine) + 1
	if ( rangeBytes <= byteCap ) { print shownLine ; shownCount = shownCount + 1 ; shownBytes = rangeBytes ; }
}
END {
	if ( rangeBytes > byteCap && shownCount == 0 ) printf "... line %d alone is over the %d-byte cap of this reader, so it cannot be returned here ...\n", fromLine, byteCap
	else if ( rangeBytes > byteCap && restHint != "" ) printf "... TRUNCATED: showed %d of %d bytes; %s ...\n", shownBytes, rangeBytes, restHint
	else if ( rangeBytes > byteCap ) printf "... TRUNCATED: showed %d of %d bytes in the requested range; continue with offset %d ...\n", shownBytes, rangeBytes, fromLine + shownCount
	else if ( numberLines != "" && lineLimit > 0 && NR >= fromLine + lineLimit ) printf "... TRUNCATED: showed %d of %d lines; continue with offset %d ...\n", shownCount, NR - fromLine + 1, fromLine + shownCount
	printf "... read %d line(s) from line %d; the file has %d lines ...\n", shownCount, fromLine, NR
}
