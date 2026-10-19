#!/usr/bin/env awk
# Prints the stored last_swept_ts from a sweep-state note's own frontmatter.
BEGIN { want = "last_swept_ts:" ; }
NR == 1 && $0 == "---" { inFront = 1 ; sawFront = 1 ; next ; }
inFront && $0 == "---" { inFront = 0 ; next ; }
inFront && index($0, want) == 1 {
	value = substr($0, length(want) + 1)
	gsub(/^[ \t]+|[ \t]+$/, "", value)
	gsub(/^"|"$/, "", value)
	if ( value != "" ) { found = value ; }
}
END {
	if ( ! sawFront ) { exit 1 ; }
	if ( found == "" ) { exit 3 ; }
	print found
}
