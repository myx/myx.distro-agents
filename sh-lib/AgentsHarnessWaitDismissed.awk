#!/usr/bin/awk -f
##
## AgentsHarnessWaitDismissed.awk -- finds a dismissal among the messages a Wait
## returned, for AgentsUniversalHarness.sh's AgentsHarnessToolWait. Input: the wait's
## own stdout. `-v agent=<member>`: the member waiting. Needs AgentsDismissalMatch.awk
## loaded first: `awk -v agent=<member> -f AgentsDismissalMatch.awk -f <this>`.
##
## A message is one `<ts> | <user> |...` line plus the lines under it (a Slack text
## keeps its newlines), up to the next message or a `WAIT-` line. Whether it dismisses
## <agent> is AgentsDismissalMatch.awk's dismissalOf: tagged to <agent> (the send
## header's addressees, or `DISMISSED <agent>` typed), whichever account posted it;
## only one authored by <agent> itself is ignored. A DISMISSED addressed to someone
## else, or to nobody, dismisses no one: a shared session thread holds several members.
##
## Prints the dismissing message's `<ts> | <user>` and exits 0; exits 1 when none.
## Every closing `}` is preceded by a `;` (reference/shell.md's awk axiom).
##
function flush() {
	if (cur != "" && dismissalOf(cur, agent)) { print head ; found = 1 ; exit 0 ; } ;
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
