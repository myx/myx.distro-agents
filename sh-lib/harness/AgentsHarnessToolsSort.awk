# AgentsHarnessToolsSort.awk -- the tool declarations of the floor in the order of their names (F10.7): the one order every
# member's request opens its `tools` with, so that block is byte for byte the same in all of them and a marker can stand at its
# end. Reads the array on stdin and writes it again, each declaration as it was, only in another order.
#   -v shape=array  the Messages wire's array: one line `[{"name":"A",...},{"name":"B",...}]`, split where one declaration ends
#                   and the next begins, `},{"name":"` (a quote inside a string is escaped, so those bytes stand nowhere else)
#   -v shape=lines  the chat wire's array: a line `[`, one declaration a line, each but the last ending with a comma, a line `]`
# Names compare byte by byte (run it under LC_ALL=C). A declaration that has no name where one is expected is kept where it is,
# in front: nothing is dropped, and the output has as many declarations as the input.
BEGIN { n = 0 ; }
shape == "lines" {
	if ( $0 == "[" || $0 == "]" ) { next ; }
	line = $0 ; sub( /,$/, "", line ) ;
	rec[ ++n ] = line ; next ;
}
shape == "array" { whole = whole $0 ; }
END {
	if ( shape == "array" ) {
		text = whole ;
		sub( /^\[/, "", text ) ; sub( /\]$/, "", text ) ;
		delim = "},{\"name\":\"" ;
		while ( ( p = index( text, delim ) ) > 0 ) {
			rec[ ++n ] = substr( text, 1, p ) ;
			text = "{\"name\":\"" substr( text, p + length( delim ) ) ;
		}
		rec[ ++n ] = text ;
	}
	for ( i = 1 ; i <= n ; i ++ ) {
		key[ i ] = "" ;
		if ( match( rec[ i ], /"name":"[^"]*"/ ) ) { key[ i ] = substr( rec[ i ], RSTART + 8, RLENGTH - 9 ) ; }
	}
	# insertion sort, stable: equal names keep their order
	for ( i = 2 ; i <= n ; i ++ ) {
		r = rec[ i ] ; k = key[ i ] ; j = i - 1 ;
		while ( j >= 1 && key[ j ] > k ) { rec[ j + 1 ] = rec[ j ] ; key[ j + 1 ] = key[ j ] ; j -- ; }
		rec[ j + 1 ] = r ; key[ j + 1 ] = k ;
	}
	if ( shape == "array" ) {
		printf "[" ;
		for ( i = 1 ; i <= n ; i ++ ) { printf "%s%s", ( i > 1 ? "," : "" ), rec[ i ] ; }
		printf "]\n" ;
	} else {
		print "[" ;
		for ( i = 1 ; i <= n ; i ++ ) { print rec[ i ] ( i < n ? "," : "" ) ; }
		print "]" ;
	}
}
