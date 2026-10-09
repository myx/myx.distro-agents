#!/usr/bin/env awk
# Extracts the answer text: the first line of the first matched reply. The rest of that reply,
# and every later one, are clarifications (AgentsPendingReplyClarifications.awk).
/^[0-9]+\.[0-9]+ \| / {
	line = $0 ; sub(/^[^|]*\| [^|]*\|/, "", line) ;
	while ( match(line, /^ \[[^]]*\]/) ) { line = substr(line, RSTART + RLENGTH) ; }
	sub(/^ +/, "", line) ;
	print line ;
	exit ;
}
