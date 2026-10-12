## AgentsOutputStyleMarker.awk -- the retired marker of a question, `NEEDS REPLY`, found.
## Reads one text on stdin: a sender's own words. Prints one `- needs-reply-marker: <line>`
## line for each line that carries the marker, the line cut as a floor fault is, and nothing
## for a text that carries none. Always exit 0.
## Only the marker itself is looked for, in capitals, as its rule had it written: no wording
## is read as a question. The fence, code-span and quote exclusions are those of
## AgentsOutputStyleCheck.awk, restated: awk loads no fragment from another program. So a
## message can still name the marker, in code style or in a quoted line.

substr( $0, 1, 3 ) == "```" { inFence = ! inFence ; next ; }
inFence { next ; }
/^[[:space:]]*(>|&gt;)/ { next ; }
{
	lineText = $0 ;
	gsub( /`[^`]*`/, " ", lineText ) ;
	if ( lineText !~ /(^|[^A-Za-z])NEEDS[ \t]+REPLY([^A-Za-z]|$)/ ) { next ; }
	shownText = $0 ;
	gsub( /^[[:space:]]+|[[:space:]]+$/, "", shownText ) ;
	if ( length( shownText ) > 120 ) { shownText = substr( shownText, 1, 117 ) "..." ; }
	printf "- needs-reply-marker: %s\n", shownText ;
}
