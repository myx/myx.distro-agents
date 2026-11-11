#!/usr/bin/env awk
# Prints the stored position from a sweep-state note's own frontmatter.
#
# With no key (`-v key=`), it prints `last_swept_ts:` and behaves exactly as before.
# With a key, it prints `source-<key>-last-swept-ts:` and falls back to
# `last_swept_ts:` when that source has no position of its own.
#
# With `-v mode=list` it prints every stored per-source position instead, one
# `<key><TAB><ts>` a line, and no key is read. A caller that has to hand a floor
# to a scan before that scan has enumerated its sources reads this.
#
# Three outcomes, told apart by exit status:
#   rc 0 -- found; the value is on stdout (in list mode: at least one source).
#   rc 3 -- a frontmatter block carrying no position for this key or fallback
#           (in list mode: no per-source position at all).
#   rc 1 -- no frontmatter block at all.
BEGIN { want = "last_swept_ts:" ; keyed = ( key != "" ) ; listing = ( mode == "list" ) }
NR == 1 && $0 == "---" { inFront = 1 ; sawFront = 1 ; next ; }
inFront && $0 == "---" { inFront = 0 ; next ; }
inFront && listing && match($0, /^source-.*-last-swept-ts:/) {
	mark = substr($0, 1, RLENGTH)
	value = substr($0, RLENGTH + 1)
	gsub(/^[ \t]+|[ \t]+$/, "", value)
	gsub(/^"|"$/, "", value)
	sourceKey = substr(mark, length("source-") + 1, length(mark) - length("source-") - length("-last-swept-ts:"))
	if ( sourceKey != "" && value != "" ) { rows[++n] = sourceKey "\t" value }
	next
}
inFront && !listing && keyed && index($0, "source-" key "-last-swept-ts:") == 1 {
	value = substr($0, length("source-" key "-last-swept-ts:") + 1)
	gsub(/^[ \t]+|[ \t]+$/, "", value)
	gsub(/^"|"$/, "", value)
	if ( value != "" ) { found = value ; haveKey = 1 ; }
}
inFront && !listing && index($0, want) == 1 {
	value = substr($0, length(want) + 1)
	gsub(/^[ \t]+|[ \t]+$/, "", value)
	gsub(/^"|"$/, "", value)
	if ( value != "" ) { fallback = value ; }
}
END {
	if ( ! sawFront ) { exit 1 ; }
	if ( listing ) {
		if ( n == 0 ) { exit 3 ; }
		for ( i = 1 ; i <= n ; i++ ) { print rows[i] ; }
		exit 0
	}
	if ( haveKey ) { print found ; exit 0 ; }
	if ( fallback != "" ) { print fallback ; exit 0 ; }
	exit 3
}
