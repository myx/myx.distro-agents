#!/usr/bin/env awk
# Rewrites a sweep-state note's frontmatter, every other line kept verbatim.
#
# With no key (`-v key=`), it sets `last_swept_ts: -v ts=` and drops every
# per-source position, which is the behaviour before this change.
# With a key, it sets `source-<key>-last-swept-ts: -v ts=`, keeps every other
# source's position, and keeps `last_swept_ts:` as it stands. The caller decides
# the fallback, because only it knows the oldest position this pass reached.
# A field it sets is inserted before the frontmatter's closing line when absent.
# Exit 1 when the input has no frontmatter, or has one left unclosed.
BEGIN { want = "last_swept_ts:" ; field = ( key == "" ? want : "source-" key "-last-swept-ts:" ) }
NR == 1 && $0 == "---" { inFront = 1 ; sawFront = 1 ; print ; next ; }
inFront && $0 == "---" {
	if ( ! written ) { print field " " ts ; written = 1 ; }
	inFront = 0 ; print ; next ;
}
inFront && key == "" && $0 ~ /^source-[^ \t:]*-last-swept-ts:/ { next ; }
inFront && index($0, field) == 1 {
	if ( ! written ) { print field " " ts ; written = 1 ; }
	next
}
{ print }
END {
	if ( ! sawFront || inFront ) { exit 1 ; }
}
