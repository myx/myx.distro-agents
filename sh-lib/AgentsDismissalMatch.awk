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
##     `[<mark> ]*_<from>_*[ @<alias>] → ...*_<member>_*... .` then DISMISSED
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
##
## memberSendHeaderLength(text) -- the length of the send header <text> starts with, its
## closing `. ` or line end included; 0 where it starts with none. The header is exactly
## what the member send writes ahead of the body (AgentsTools.MemberCommsSlack.include):
## before the arrow nothing but an optional mark, the sender, and its alias where that is
## not the sender's own name, which the header says once. With no alias beside the name the
## mark is held to what a mark is, a `:shortcode:` or a sign that is no plain letter, so a
## line of somebody's own words is never taken for a header. Here for
## AgentsSlackThreadAnswers.awk, which reads a question's number as the first word after
## that header: every caller of that reader loads this file ahead of it, a Wait started
## before this function was written included. AgentsEscalationVerdict.awk's
## sendHeaderLength is the same rule, kept there because that reader is run with no
## library loaded.
##
function memberSendHeaderLength(text,   arrowAt, fromPart, toPart, endAt) {
	arrowAt = index(text, " → ") ;
	if (arrowAt == 0) { return 0 ; } ;
	fromPart = substr(text, 1, arrowAt - 1) ;
	if (fromPart !~ /^([^ ]+ )?\*_[^*]+_\* @[^ ]+$/ && fromPart !~ /^((:[A-Za-z0-9_+-]+:|[^ -~]+) )?\*_[^*]+_\*$/) { return 0 ; } ;
	toPart = substr(text, arrowAt + length(" → ")) ;
	endAt = index(toPart, ". ") ;
	if (endAt > 0) { return arrowAt + length(" → ") + endAt ; } ;
	return (substr(toPart, length(toPart), 1) == ".") ? length(text) : 0 ;
} ;
