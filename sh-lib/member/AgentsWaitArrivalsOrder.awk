#!/usr/bin/env awk

# Prints what the sources of a Wait brought, after the floor (F3.3): the messages of all of them together in one group, sorted
# by time, each naming the source it came from, and consecutive messages of one source under one `# arrived on: <source>` line, so
# the readers of those blocks (AgentsHarnessWaitAskResolve and the rest) read them as they always did. Read with -v manifest=<file>:
# a line `<position><TAB><source><TAB><rendering file>` for each source that arrived, in the order the wait asked them.
#
# A Slack source's rendering is split at its message heads (`<ts> | <user> |...`) and its messages take their places by ts. Any other
# source -- an ask, a file, an inbox or a board listing, a scan, the tags -- is one block, whole, never cut or merged with a neighbour:
# it takes the place of its newest message where its rendering has one, and goes after the dated ones in the order asked where it
# has none. A line of a rendering that reads as a mark of this wait's own is printed one space in. Every closing brace is preceded
# by a `;`.

function keyOf(ts,   sec, frac) {
	sec = ts ;
	sub(/\..*$/, "", sec) ;
	frac = ts ;
	if ( frac !~ /\./ ) { frac = "000000" ; } else { sub(/^[^.]*\./, "", frac) ; }
	while ( length(frac) < 6 ) { frac = frac "0" ; }
	frac = substr(frac, 1, 6) ;
	while ( length(sec) < 12 ) { sec = "0" sec ; }
	return sec "." frac ;
}

function addUnit(source, key, whole, lineFrom, lineTo, contentName,   at) {
	units++ ;
	uSource[units] = source ;
	uKey[units] = key ;
	uWhole[units] = whole ;
	uFrom[units] = lineFrom ;
	uTo[units] = lineTo ;
	uName[units] = contentName ;
}

function neutral(line) {
	return ( line ~ /^(WAIT-|# --- |# arrived on: )/ ) ? " " line : line ;
}

BEGIN {
	units = 0 ;
	late = "999999999999.999999" ;
	while ( ( getline manifestLine < manifest ) > 0 ) {
		split(manifestLine, part, "\t") ;
		source = part[2] ;
		name = part[3] ;
		count = 0 ;
		while ( ( getline text < name ) > 0 ) { count++ ; body[name, count] = text ; }
		close(name) ;
		lines[name] = count ;
		newest = "" ;
		for ( row = 1 ; row <= count ; row++ ) {
			if ( body[name, row] ~ /^[0-9]+\.[0-9]+ \| / ) {
				head = body[name, row] ;
				sub(/ .*$/, "", head) ;
				if ( newest == "" || keyOf(head) > newest ) { newest = keyOf(head) ; }
			}
		}
		if ( source ~ /^slack:/ && newest != "" ) {
			from = 0 ;
			for ( row = 1 ; row <= count + 1 ; row++ ) {
				isHead = ( row <= count && body[name, row] ~ /^[0-9]+\.[0-9]+ \| / ) ;
				if ( isHead || row == count + 1 ) {
					if ( from > 0 ) { addUnit(source, headKey, 0, from, row - 1, name) ; }
					if ( isHead ) {
						head = body[name, row] ;
						sub(/ .*$/, "", head) ;
						headKey = keyOf(head) ;
						from = row ;
					}
				}
			}
			# lines ahead of the first head, if there are any, stand as a block of their own, first
			firstHead = 0 ;
			for ( row = 1 ; row <= count && firstHead == 0 ; row++ ) {
				if ( body[name, row] ~ /^[0-9]+\.[0-9]+ \| / ) { firstHead = row ; }
			}
			if ( firstHead > 1 ) { addUnit(source, "000000000000.000000", 1, 1, firstHead - 1, name) ; }
		} else {
			addUnit(source, ( newest == "" ) ? late : newest, 1, 1, count, name) ;
		}
	}
	# a stable insertion sort by key
	for ( i = 2 ; i <= units ; i++ ) {
		k = uKey[i] ; s = uSource[i] ; w = uWhole[i] ; f = uFrom[i] ; t = uTo[i] ; n = uName[i] ;
		j = i - 1 ;
		while ( j >= 1 && uKey[j] > k ) {
			uKey[j + 1] = uKey[j] ; uSource[j + 1] = uSource[j] ; uWhole[j + 1] = uWhole[j] ; uFrom[j + 1] = uFrom[j] ; uTo[j + 1] = uTo[j] ; uName[j + 1] = uName[j] ;
			j-- ;
		}
		uKey[j + 1] = k ; uSource[j + 1] = s ; uWhole[j + 1] = w ; uFrom[j + 1] = f ; uTo[j + 1] = t ; uName[j + 1] = n ;
	}
	open = 0 ;
	current = "" ;
	for ( i = 1 ; i <= units ; i++ ) {
		if ( uWhole[i] || uSource[i] != current || ! open ) {
			if ( open ) { print "# --- end ---" ; }
			print "# arrived on: " uSource[i] ;
			print "# --- what that source holds now follows ---" ;
			open = 1 ;
			current = ( uWhole[i] ) ? "" : uSource[i] ;
		}
		for ( row = uFrom[i] ; row <= uTo[i] ; row++ ) { print neutral(body[uName[i], row]) ; }
	}
	if ( open ) { print "# --- end ---" ; }
	exit ;
}
