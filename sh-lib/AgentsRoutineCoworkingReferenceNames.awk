#!/usr/bin/awk -f
##
## AgentsRoutineCoworkingReferenceNames.awk -- reads an --intern-op-session-context-scan
## document (## <state>/<item> blocks restricted to `blocks:`/`blocked-by:`
## headers) on stdin, and prints one bare item-name per line for
## every value found across both fields, every block -- including
## comma-separated list values (`a, b, c`, the encoding
## AgentsTools.InternOpBoardUpsertMoveEdit.include's own --header:append
## produces) and plain scalar values alike. The leading-`[`/trailing-`]`
## strip below is a no-op on current-format values -- kept only so a
## still-bracketed legacy value parses the same way. Duplicates are expected and
## normal (dedupe with `sort -u`, not this script's job); the caller unions
## this against the originally-given item-name set, normalising a bare name to
## the `<name>.md` form --item compares against, to build
## --routine-coworking-session-input-scan's phase-2 --item list. See
## AgentsTools.RoutineCoworking.include's own header.
##
/^blocks: |^blocked-by: / {
	val = $0 ;
	sub(/^[a-z-]+: /, "", val) ;
	gsub(/^\[/, "", val) ;
	gsub(/\]$/, "", val) ;
	n = split(val, parts, ",") ;
	for (i = 1 ; i <= n ; i++) {
		item = parts[i] ;
		gsub(/^[ \t]+|[ \t]+$/, "", item) ;
		if (item != "") { print item ; }
	}
}
