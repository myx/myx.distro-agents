#!/usr/bin/awk -f
##
## AgentsManagerPlaceRows.awk -- the `place` rows of the places as the console shows them: for
## AgentsToolsManagerPlaceRows (AgentsTools.ManagerPlace.include). On standard input the merged
## list of the places as their own reader gives it (AgentsToolsPlacesMergedText), each row with
## one more field, the state of its path as the shell measured it: name, kind, ceiling, path,
## declaring root, declared-by, state, a TAB between them.
##
## In the environment:
##   MDAT_MANAGER_PLACE_HERE       the root of the workspace the call runs in.
##   MDAT_MANAGER_PLACE_SESSIONS   the registry `spawned-sessions` of that workspace, as it
##       lies: read here and never rebuilt. Of its columns, blanks between them, the second is
##       taken, the id of a session (the first, its tracking name, where it has none), and the
##       eleventh, the name of the workspace a run names, `-` where it names none. Where the
##       file cannot be read no session is counted at all.
##   -v wanted=<key>   only the place of that key.
##
## Prints one row a place: `place`, its key, label, kind, ceiling, path, state, here, sessions.
##   label     the words of the key, capitalised: what stands between its `-`, `_`, `.`, `+`
##             and `@`, the first letter of each a capital, the rest as it stands.
##   here      `yes` where the path is the root of the workspace the call runs in, else `no`.
##   sessions  for a workspace, how many sessions of the registry have a run that names it,
##             by the last segment of its path; `-` for any other place, and where no
##             registry was read.
## Every field is one field: a run of whitespace in it reads `_`, and an empty one `-`.
##

BEGIN {
	FS = "\t" ; OFS = "\t"
	here = ENVIRON["MDAT_MANAGER_PLACE_HERE"] ; sub( /\/+$/, "", here )
	registry = ENVIRON["MDAT_MANAGER_PLACE_SESSIONS"] ; counted = 0
	if ( registry != "" ) {
		while ( ( got = ( getline line < registry ) ) > 0 ) {
			if ( split( line, column, " " ) < 11 || column[11] == "-" ) continue
			id = ( column[2] == "-" ) ? column[1] : column[2]
			if ( ( column[11] SUBSEP id ) in seen ) continue
			seen[column[11] SUBSEP id] = 1 ; sessions[column[11]]++
		}
		counted = ( got == 0 )
		close( registry )
	}
}

NF >= 7 && ( wanted == "" || $1 == wanted ) {
	base = $4 ; sub( /.*\//, "", base )
	print "place", field( $1 ), field( labelOf( $1 ) ), field( $2 ), field( $3 ), field( $4 ), field( $7 ), ( $4 != "-" && $4 == here ) ? "yes" : "no", ( $2 == "workspace" && counted ) ? sessions[base] + 0 : "-"
}

function field( text ) {
	gsub( /[ \t]+/, "_", text )
	return ( text == "" ) ? "-" : text
}

function labelOf( key,    count, word, at, text ) {
	count = split( key, word, /[-_.+@]+/ ) ; text = ""
	for ( at = 1 ; at <= count ; at++ ) {
		if ( word[at] == "" ) continue
		text = text ( text == "" ? "" : " " ) toupper( substr( word[at], 1, 1 ) ) substr( word[at], 2 )
	}
	return text
}
