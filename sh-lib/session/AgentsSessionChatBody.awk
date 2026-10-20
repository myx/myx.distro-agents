#!/usr/bin/env awk

# Prints the body of one message as the session chat file keeps it (AgentsTools.SessionChat.include): the lines as
# they were, the blank lines at the end left off, and a line that reads as the header of a message kept one space in,
# so the headers of the file stay the only lines that begin a block. Reads the body on its standard input.
#
# The header is `<iso-time> <from> -> <to>:` with the time as 2026-10-19T10:00:00Z. Every closing brace is preceded
# by a `;` (reference/shell.md's awk axiom).

{
	line[NR] = $0 ;
	last = NR ;
}

END {
	while ( last > 0 && line[last] ~ /^[ \t\r]*$/ ) { last-- ; }
	for ( at = 1 ; at <= last ; at++ ) {
		text = line[at] ;
		if ( text ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ ) { text = " " text ; }
		print text ;
	}
}
