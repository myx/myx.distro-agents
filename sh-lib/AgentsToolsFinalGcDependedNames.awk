#!/usr/bin/env awk
# Prints each blocked-by/spawned-by dependency basename named in a board item's own frontmatter.
FNR == 1 { fmDepth = 0 ; }
$0 == "---" { fmDepth++ ; next ; }
fmDepth != 1 { next ; }
/^blocked-by: |^spawned-by: / {
	value = $0 ;
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
}
