#!/usr/bin/awk -f
##
## AgentsRoutineRunsAtScan.awk -- prints `<file>\t<runs-at>` for every routine file given whose frontmatter carries a `runs-at:`
## line, in one pass over all of them. The schedule's autorun step reads every member's routine files each pass; one frontmatter
## read a file was a process per file, and 14 s of an 83 s pass at 2026-11-26.
##
FNR == 1 { inFrontmatter = ( $0 == "---" ) ? 1 : 0 ; runsAt = "" ; next }
$0 == "---" { if ( inFrontmatter == 1 ) { if ( runsAt != "" && runsAt != "none" ) print FILENAME "\t" runsAt ; nextfile } ; next }
inFrontmatter == 1 && /^runs-at: / { runsAt = substr( $0, 10 ) }
