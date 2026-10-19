#!/usr/bin/env awk
# Rewrites a sweep-state note with its frontmatter last_swept_ts set to -v ts=,
# every other line kept verbatim. Inserts the field before the frontmatter's
# closing line when it is absent. Exit 1 when the input has no frontmatter.
# Frontmatter `source-<key>-last-swept-ts:` entries are dropped: no scan reads a
# per-source position, so a stored one only claims a floor nothing honours.
BEGIN { want = "last_swept_ts:" ; }
NR == 1 && $0 == "---" { inFront = 1 ; sawFront = 1 ; print ; next ; }
inFront && $0 ~ /^source-[^ \t:]*-last-swept-ts:/ { next ; }
inFront && $0 == "---" {
	if ( ! written ) { print want " " ts ; written = 1 ; }
	inFront = 0 ; print ; next ;
}
inFront && index($0, want) == 1 {
	if ( ! written ) { print want " " ts ; written = 1 ; }
	next
}
{ print }
END {
	if ( ! sawFront || inFront ) { exit 1 ; }
}
