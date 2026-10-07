#!/usr/bin/awk -f
##
## AgentsDismissalMatch.awk -- function library, no rules of its own: load it with a
## second `-f` before the program that calls it. Shared by AgentsHarnessWaitDismissed.awk
## (the Wait DISMISSED outcome) and AgentsSlackThreadAnswers.awk (which must not drop a
## dismissal as the waiting member's own post), so both read one rule.
##
## dismissalOf(msg, member) -- 1 when the rendered message <msg> (its `<ts> | <user> |`
## head line plus the lines under it) dismisses <member>, else 0. A dismissal is
## recognised by its TAG, never by the Slack account that posted it: several members
## post under one team bot, so the account, and the `[sender: X]` it carries, cannot
## tell a spawner from its child. The body is exactly DISMISSED (a trailing `.` or `!`
## allowed) in either form:
##   - the team's own send header addressing <member>:
##     `[<mark> ]*_<from>_* @<alias> → ...*_<member>_*... .` then DISMISSED
##     (what SendMessage with address_to <member> and message DISMISSED writes);
##     its author is AgentsSessionContextCommsItems.awk's readHeader author: the
##     first `*_<name>_*` before the arrow, with nothing but a mark before it;
##   - no header, the text `DISMISSED <member>` (a person typing it in the thread).
## Only a dismissal authored by <member> itself is ignored: the header naming <member>
## as author, or, with no header author, a `[sender: <member>]`. A DISMISSED addressed
## to someone else, or to @here, dismisses no one.
##
## Every closing `}` is preceded by a `;` (reference/shell.md's awk axiom).
##
function dismissalOf(msg, member,   rest, ann, sender, arrow, fromPart, author, toPart, endPos, body) {
	gsub(/[\r\n\t]+/, " ", msg) ;
	rest = msg ;
	sub(/^[0-9]+\.[0-9]+ \| [^|]* \|/, "", rest) ;
	sender = "" ;
	while (match(rest, /^ \[[^]]*\]/)) {
		ann = substr(rest, RSTART + 1, RLENGTH - 1) ;
		rest = substr(rest, RSTART + RLENGTH) ;
		if (ann ~ /^\[sender: /) { sender = ann ; sub(/^\[sender: /, "", sender) ; sub(/\]$/, "", sender) ; } ;
	} ;
	sub(/^[ ]+/, "", rest) ;
	sub(/[ ]+$/, "", rest) ;
	if (rest ~ ("^DISMISSED " member "[.!]?$")) { return (sender != member) ; } ;
	arrow = index(rest, " → ") ;
	if (arrow == 0) { return 0 ; } ;
	fromPart = substr(rest, 1, arrow - 1) ;
	author = "" ;
	if (match(fromPart, /\*_[^*]+_\*/) && !(RSTART > 1 && substr(fromPart, 1, RSTART - 1) ~ /[^ ]+ [^ ]/)) { author = substr(fromPart, RSTART + 2, RLENGTH - 4) ; } ;
	if (author == member || (author == "" && sender == member)) { return 0 ; } ;
	toPart = substr(rest, arrow + length(" → ")) ;
	endPos = index(toPart, ". ") ;
	if (endPos == 0) { return 0 ; } ;
	body = substr(toPart, endPos + 2) ;
	toPart = substr(toPart, 1, endPos - 1) ;
	sub(/^[ ]+/, "", body) ;
	if (index(toPart, "*_" member "_*") == 0) { return 0 ; } ;
	return (body ~ /^DISMISSED[.!]?$/) ;
} ;
