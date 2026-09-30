#!/usr/bin/env awk
# Extracts the answer text out of the first matched reply block, folding continuation lines in.
/^[0-9]+\.[0-9]+ \| / {
	if ( taken ) { exit ; }
	taken = 1 ;
	line = $0 ; sub(/^[^|]*\| [^|]*\|/, "", line) ;
	while ( match(line, /^ \[[^]]*\]/) ) { line = substr(line, RSTART + RLENGTH) ; }
	sub(/^ +/, "", line) ;
	text = line ;
	next ;
}
taken && $0 !~ /^UNMATCHED-REPLY / { text = ( text == "" ? $0 : text " " $0 ) ; }
END { print text ; }
