## AgentsSchedulePendingOrder.awk -- the queue order of the pending board items, one row a file: `<tier> TAB <stamp> TAB <path>`, which the caller sorts as C text.
## The tier is 0 for `mark: emergency`, 1 for `mark: urgent` and 2 for any other. The stamp is the UTC stamp in the file name, `<date>T<time>Z` with the time padded to six digits,
## which is the item's age; a name with none takes `~`, after every digit, so a tier's stamped items come first and the rest keep the order of their names. The files are the arguments.
FNR == 1 {
	if ( have ) { printf "%d\t%s\t%s\n", tier, stamp, path ; }
	have = 1 ; path = FILENAME ; name = FILENAME ; sub( /^.*\//, "", name ) ; stamp = "~" ; tier = 2 ; inside = ( $0 == "---" ) ;
	if ( match( name, /[0-9]+T[0-9]+Z/ ) ) {
		split( substr( name, RSTART, RLENGTH - 1 ), part, "T" ) ;
		stamp = part[1] "T" part[2] substr( "000000", length( part[2] ) + 1 ) ;
	}
	if ( ! inside ) { nextfile ; }
	next ;
}
inside && $0 == "---" { nextfile ; }
inside && /^mark:/ { sub( /^mark: */, "" ) ; tier = ( $0 == "emergency" ? 0 : ( $0 == "urgent" ? 1 : 2 ) ) ; }
END {
	if ( have ) { printf "%d\t%s\t%s\n", tier, stamp, path ; }
}
