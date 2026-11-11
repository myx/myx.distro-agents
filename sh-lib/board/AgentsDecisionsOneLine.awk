#!/usr/bin/env awk

# A Decisions text as one line: the lines of stdin joined by a space, trimmed, and cut at <max> bytes with `...` appended,
# never splitting a UTF-8 character. Loaded after the shared cut:
#   LC_ALL=C awk -v max=<bytes> -f sh-lib/session/AgentsProgressLineSafe.awk -f sh-lib/board/AgentsDecisionsOneLine.awk
# MUST run under LC_ALL=C, as progressLineSafe() does.

{ text = text ( NR > 1 ? " " : "" ) $0 ; }
END {
	sub( /^ +/, "", text ) ;
	sub( / +$/, "", text ) ;
	if ( length( text ) > max ) { text = progressLineSafe( text, max - 3 ) ; }
	print text ;
}
