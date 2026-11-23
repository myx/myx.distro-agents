#!/usr/bin/env awk
# Prints each blocked-by/spawned-by dependency basename named in a board item's own frontmatter.
# stdin: one board item path a line, never as operands: a board holds more names than one command line takes.
{
	itemPath = $0 ; fmDepth = 0 ;
	while ((getline itemLine < itemPath) > 0) {
		if (itemLine == "---") { fmDepth++ ; if (fmDepth >= 2) { break ; } ; continue ; } ;
		if (fmDepth != 1) { continue ; } ;
		if (itemLine !~ /^blocked-by: |^spawned-by: /) { continue ; } ;
		value = itemLine ;
		sub(/^blocked-by: |^spawned-by: /, "", value) ;
		sub(/^\[/, "", value) ;
		sub(/\]$/, "", value) ;
		count = split(value, parts, ",") ;
		for (i = 1 ; i <= count ; i++) {
			name = parts[i] ;
			gsub(/^[ \t]+|[ \t]+$/, "", name) ;
			if (name == "") { continue ; }
			if (name !~ /\.md$/) { name = name ".md" ; }
			print name ;
		}
	} ;
	close(itemPath) ;
}
