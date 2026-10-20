#!/usr/bin/awk -f
##
## AgentsHarnessWaitDismissed.awk -- finds a dismissal among the messages a Wait
## returned, for AgentsUniversalHarness.sh's AgentsHarnessToolWait. Input: the wait's
## own stdout. `dismissalMember=<member>` in the environment: the member waiting, a name,
## so through ENVIRON and never -v. Needs AgentsDismissalMatch.awk loaded first:
## `dismissalMember=<member> awk -f AgentsDismissalMatch.awk -f <this>`.
##
## A message is one `<ts> | <user> |...` line plus the lines under it (a Slack text
## keeps its newlines), up to the next message, a `WAIT-` line, or one of the lines the wait
## itself puts around what arrived (`# --- what that source holds now follows ---`,
## `# --- end ---`), which are never part of a message. Whether it dismisses
## <agent> is AgentsDismissalMatch.awk's dismissalOf: tagged to <agent> (the send
## header's addressees, or `DISMISSED <agent>` typed), whichever account posted it;
## only one authored by <agent> itself is ignored. A DISMISSED addressed to someone
## else, or to nobody, dismisses no one: a shared session thread holds several members.
##
## A message of the session chat file (F3.3, F9.2) comes in its own form: the header `<iso-time> <from> -> <to>:` and its body, as the
## `chat:` source of a Wait returns it. It dismisses <agent> by the same rule: the header addresses <agent> and the body is exactly
## DISMISSED (a trailing `.` or `!` allowed), or the body is `DISMISSED <agent>`; one from <agent> itself dismisses no one. A chat block
## ends where the next header, a `WAIT-` line or one of the wait's own lines (above) begins.
##
## Prints the dismissing message's `<ts> | <user>` (`<iso-time> | <from>` for a chat block) and exits 0; exits 1 when none.
## Every closing `}` is preceded by a `;` (reference/shell.md's awk axiom).
##
BEGIN { agent = ENVIRON["dismissalMember"] ; } ;
function flush(   chatFrom, chatTo, chatText) {
	if (cur != "" && dismissalOf(cur, agent)) { print head ; found = 1 ; exit 0 ; } ;
	cur = "" ;
	if (chatHead != "") {
		chatFrom = chatHead ;
		sub(/^[^ ]* /, "", chatFrom) ;
		chatTo = chatFrom ;
		sub(/ -> .*$/, "", chatFrom) ;
		sub(/^.* -> /, "", chatTo) ;
		sub(/:$/, "", chatTo) ;
		chatText = chatBody ;
		gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", chatText) ;
		if (chatFrom != agent && ((chatText ~ /^DISMISSED[.!]?$/ && (("," chatTo ",") ~ ("," agent ","))) || chatText ~ ("^DISMISSED " agent "[.!]?$"))) {
			head = chatHead ;
			sub(/ .*$/, "", head) ;
			print head " | " chatFrom ;
			found = 1 ;
			exit 0 ;
		} ;
	} ;
	chatHead = "" ;
	chatBody = "" ;
} ;
/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ {
	flush() ;
	chatHead = $0 ;
	next ;
} ;
/^[0-9]+\.[0-9]+ \| / {
	flush() ;
	cur = $0 ;
	head = $0 ;
	if (match(head, /^[0-9]+\.[0-9]+ \| [^|]* \|/)) { head = substr(head, 1, RLENGTH - 2) ; } ;
	next ;
} ;
/^WAIT-/ { flush() ; next ; } ;
$0 == "# --- what that source holds now follows ---" || $0 == "# --- end ---" { flush() ; next ; } ;
cur != "" { cur = cur "\n" $0 ; next ; } ;
chatHead != "" { chatBody = chatBody "\n" $0 ; } ;
END {
	if (!found) { flush() ; } ;
	if (!found) { exit 1 ; } ;
} ;
