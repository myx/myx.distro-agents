#!/usr/bin/awk -f
##
## AgentsHarnessWaitDismissed.awk -- finds a dismissal among the messages a Wait
## returned, for AgentsUniversalHarness.sh's AgentsHarnessToolWait. Input: the wait's
## own stdout. `-v agent=<member>`: the member waiting.
##
## A message is one `<ts> | <user> |...` line plus the lines under it (a Slack text
## keeps its newlines), up to the next message or a `WAIT-` line. It dismisses <agent>
## when its body is exactly DISMISSED (a trailing `.` or `!` allowed) in either form:
##   - the team's own send header addressing <agent>:
##     `[<mark> ]*_<from>_* @<alias> → ...*_<agent>_*... .` then DISMISSED
##     (what SendMessage with address_to <agent> and message DISMISSED writes);
##   - no header, the text `DISMISSED <agent>` (a person typing it in the thread).
## A DISMISSED addressed to someone else, or to nobody, dismisses no one: a shared
## session thread holds several members.
##
## Prints the dismissing message's `<ts> | <user>` and exits 0; exits 1 when none.
## Every closing `}` is preceded by a `;` (reference/shell.md's awk axiom).
##
function dismisses(msg,   arrow, toPart, endPos, body) {
	gsub(/[\r\n\t]+/, " ", msg) ;
	sub(/^[0-9]+\.[0-9]+ \| [^|]* \|( \[[^]]*\])* ?/, "", msg) ;
	sub(/[ ]+$/, "", msg) ;
	if (msg ~ ("^DISMISSED " agent "[.!]?$")) { return 1 ; } ;
	arrow = index(msg, " → ") ;
	if (arrow == 0) { return 0 ; } ;
	toPart = substr(msg, arrow + length(" → ")) ;
	endPos = index(toPart, ". ") ;
	if (endPos == 0) { return 0 ; } ;
	body = substr(toPart, endPos + 2) ;
	toPart = substr(toPart, 1, endPos - 1) ;
	sub(/^[ ]+/, "", body) ;
	if (index(toPart, "*_" agent "_*") == 0) { return 0 ; } ;
	return (body ~ /^DISMISSED[.!]?$/) ;
} ;
function flush() {
	if (cur != "" && dismisses(cur)) { print head ; found = 1 ; exit 0 ; } ;
	cur = "" ;
} ;
/^[0-9]+\.[0-9]+ \| / {
	flush() ;
	cur = $0 ;
	head = $0 ;
	if (match(head, /^[0-9]+\.[0-9]+ \| [^|]* \|/)) { head = substr(head, 1, RLENGTH - 2) ; } ;
	next ;
} ;
/^WAIT-/ { flush() ; next ; } ;
cur != "" { cur = cur "\n" $0 ; } ;
END {
	if (!found) { flush() ; } ;
	if (!found) { exit 1 ; } ;
} ;
