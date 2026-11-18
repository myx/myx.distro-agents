#!/usr/bin/env awk
# The first line of each named key in a file's first frontmatter block, one value a line in the order the keys
# are named, an empty line for a key the block does not carry. `-v keys=` takes the keys, space separated.
# The one reader of a frontmatter header value: AgentsSessionRunHeadersInto (session/AgentsTools.SessionStore.include)
# and AgentsToolsBoardItemHeadersInto (board/AgentsTools.ItemDecisions.include) both run this file, and neither
# carries a program of its own. Run it under LC_ALL=C, as they do.
BEGIN { n = split( keys, k, " " ) ; }
$0 == "---" { if ( ++fence > 1 ) exit ; next ; }
fence == 1 { for ( i = 1 ; i <= n ; i++ ) if ( !( i in v ) && index( $0, k[i] ": " ) == 1 ) v[i] = substr( $0, length( k[i] ) + 3 ) ; }
END { for ( i = 1 ; i <= n ; i++ ) print v[i] ; }
