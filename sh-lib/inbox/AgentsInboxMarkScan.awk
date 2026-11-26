#!/usr/bin/awk -f
##
## AgentsInboxMarkScan.awk -- prints `<file>\t<mark>` for every inbox item among the files given, whose frontmatter carries a
## `mark: ` line, in one pass over all of them. The schedule's important-and-emergency step reads the coordinator's whole incoming
## each pass; one awk a file was a process per item, 1,331 of them at 2026-11-26, and 72 s of a 231 s pass.
##
FNR == 1 { inFrontmatter = ( $0 == "---" ) ? 1 : 0 ; next }
$0 == "---" { if ( inFrontmatter == 1 ) { inFrontmatter = 2 ; nextfile } ; next }
inFrontmatter == 1 && /^mark: / { print FILENAME "\t" substr( $0, 7 ) }
