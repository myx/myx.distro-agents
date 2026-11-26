## AgentsApplyReportCheck.awk -- a report that says a file was applied names that file as <place>:<path> and its
## read-back. Reads text on stdin. Silent and exit 0 when every such line carries both; one fault line per
## violation and exit 1 otherwise. Two fault kinds: applied-without-place-path, applied-without-read-back.
## A line claiming no apply, and a line naming no file, are not measured: ordinary status talk is left alone.
## The words are matched whatever their case, because a report opens a sentence with them.

BEGIN {
	applyWords = "applied|landed|put in place|fixed|wrote back|written back|written to|wrote to"
	readWords = "cmp|cksum|sha1|sha2|sha256|sha512|md5|hash|read back|read-back|reads back|readback"
	bad = 0
}

{
	lowerLine = tolower( $0 )
	if ( lowerLine !~ applyWords ) next
	if ( $0 !~ /[A-Za-z0-9_.-]+\.[A-Za-z]/ && $0 !~ /:[0-9]+/ ) next
	if ( $0 !~ /(^|[ \t(\[`'"<>])[A-Za-z0-9][A-Za-z0-9._-]*:[^ \t\/:][^ \t:]*\// ) { printf "applied-without-place-path: %s\n", $0 ; bad = 1 ; }
	if ( lowerLine !~ readWords ) { printf "applied-without-read-back: %s\n", $0 ; bad = 1 ; }
}

END { exit ( bad ? 1 : 0 ) ; }
