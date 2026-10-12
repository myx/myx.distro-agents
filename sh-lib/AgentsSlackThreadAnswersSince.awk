#!/usr/bin/env awk

# Reads the answers AgentsSlackThreadAnswers.awk printed for one question and keeps the
# reaction lines and only the replies written after -v sinceTs=<ts>: a reply whose head
# "<ts> | <user> | <text>" is at or before that ts is dropped whole, and a later one is kept
# whole.
#
# EVERY LINE IS JUDGED BY THE REPLY IT BELONGS TO, never by what the line itself starts with.
# A reply is its head and every line under it up to the next head. A reply that reader set
# aside has `UNMATCHED-REPLY ` ahead of its head and of each line under it, and its head is
# still its head: its own ts says whether it is kept, and its lines go with it, marked as they
# came. Read by the reply above them, a set-aside reply after the live proposal reply was lost
# under one that is dropped, and one before it came back under one that is kept. A line under
# a head goes with that reply whatever it starts with, `# ` and `reaction on the question: `
# too: a person writes such lines. Only the lines ahead of the first reply are the question's
# own, its reactions, and are kept as they are.
#
# WHY: a proposal (ProposeApprove) is answered on its root alone. Its root is read as the
# question, so the clicks counted are those under the root and never those under the proposal
# reply, which the human-owner may react on without giving a verdict. The replies that count
# are the ones after the live proposal reply: what he wrote before it was already given back
# to the asker, and the proposal was changed from it.
#
# ts comparison is seconds as a number and microseconds as a fixed-width string, never a
# float: the rule of AgentsSlackThreadAnswers.awk, for the same reason.

function secOf( v ) { sub( /\..*$/, "", v ) ; return ( v == "" ? 0 : v + 0 ) ; }
function fracOf( v ) { if ( v !~ /\./ ) { return "000000" ; } sub( /^[^.]*\./, "", v ) ; return substr( v "000000", 1, 6 ) ; }
function newerThan( a, b ) {
	if ( secOf( a ) != secOf( b ) ) { return secOf( a ) > secOf( b ) ; }
	return fracOf( a ) > fracOf( b ) ;
}

BEGIN { keep = 1 ; }

## A head, set aside or not, says by its own ts whether its reply is kept.
{
	headLine = $0 ;
	sub( /^UNMATCHED-REPLY /, "", headLine ) ;
	if ( headLine ~ /^[0-9]+\.[0-9]+ \| / ) {
		sub( / .*$/, "", headLine ) ;
		keep = ( sinceTs == "" || newerThan( headLine, sinceTs ) ) ;
	}
}
keep { print ; }
