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
## S6.40: THE RUN A MESSAGE NAMES DECIDES WHO IT REACHES. Where a message carries `[addressee-run: <id>]` and the
## caller gives its own run id (the third argument), any other run is passed over: the match is never by member name
## alone once both runs are known. That is what keeps one run's DISMISSED from ending an unrelated run of the same
## member in another session.
##
## S27.8: THE TWO RUNS, NOT THE TWO MEMBERS, DECIDE THE AUTHOR'S OWN CASE. A run cannot dismiss
## itself, which is the rule above kept exactly. One run of a member CAN dismiss another run of
## that same member, and that is what `[author-run: <id>]` and `[addressee-run: <id>]` say where
## they are present. With neither, only a different member is a dismissal, as it always was.
##
## Every closing `}` is preceded by a `;` (reference/shell.md's awk axiom).
##
function dismissalOf(msg, member, ownRun,   rest, ann, sender, arrow, fromPart, author, toPart, endPos, body, authorRun, addresseeRun) {
	gsub(/[\r\n\t]+/, " ", msg) ;
	rest = msg ;
	sub(/^[0-9]+\.[0-9]+ \| [^|]* \|/, "", rest) ;
	sender = "" ;
	authorRun = "" ; addresseeRun = "" ;
	while (match(rest, /^ \[[^]]*\]/)) {
		ann = substr(rest, RSTART + 1, RLENGTH - 1) ;
		rest = substr(rest, RSTART + RLENGTH) ;
		if (ann ~ /^\[sender: /) { sender = ann ; sub(/^\[sender: /, "", sender) ; sub(/\]$/, "", sender) ; } ;
		if (ann ~ /^\[author-run: /) { authorRun = ann ; sub(/^\[author-run: /, "", authorRun) ; sub(/\]$/, "", authorRun) ; } ;
		if (ann ~ /^\[addressee-run: /) { addresseeRun = ann ; sub(/^\[addressee-run: /, "", addresseeRun) ; sub(/\]$/, "", addresseeRun) ; } ;
	} ;
	sub(/^[ ]+/, "", rest) ;
	sub(/[ ]+$/, "", rest) ;
	## S6.40: A MESSAGE NAMING ANOTHER RUN IS NOT OURS (S6.40). Where the message carries the run it was for, and the
	## waiter knows its own run, only that run is addressed: a DISMISSED for one run of a member never ends another of
	## that member's, and never one in another session. A message that carries no run is read as it always was.
	if (ownRun != "" && addresseeRun != "" && addresseeRun != ownRun) { return 0 ; } ;
	if (rest ~ ("^DISMISSED " member "[.!]?$")) { return (sender != member) ; } ;
	arrow = index(rest, " → ") ;
	if (arrow == 0) { return 0 ; } ;
	fromPart = substr(rest, 1, arrow - 1) ;
	author = "" ;
	if (match(fromPart, /\*_[^*]+_\*/) && !(RSTART > 1 && substr(fromPart, 1, RSTART - 1) ~ /[^ ]+ [^ ]/)) { author = substr(fromPart, RSTART + 2, RLENGTH - 4) ; } ;
	if (author == member && ! (authorRun != "" && addresseeRun != "" && authorRun != addresseeRun)) { return 0 ; } ;
	if (author == "" && sender == member) { return 0 ; } ;
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
	## The author line may end in the origin routine of the sending run, ` (work-duty)`, after the alias or after a bare name (AgentsTools.InternOpCommsSlackSend.include).
	if (fromPart !~ /^([^ ]+ )?\*_[^*]+_\* @[^ ]+( \([^)]*\))?$/ && fromPart !~ /^((:[A-Za-z0-9_+-]+:|[^ -~]+) )?\*_[^*]+_\*( \([^)]*\))?$/) { return 0 ; } ;
	toPart = substr(text, arrowAt + length(" → ")) ;
	endAt = index(toPart, ". ") ;
	if (endAt > 0) { return arrowAt + length(" → ") + endAt ; } ;
	return (substr(toPart, length(toPart), 1) == ".") ? length(text) : 0 ;
} ;
