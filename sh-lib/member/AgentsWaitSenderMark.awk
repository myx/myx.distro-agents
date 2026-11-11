#!/usr/bin/env awk

# Every message a Wait shows from a person outside the team carries who the person is, `[sender: <what the contact store says>]`, on the
# message's own head line, right after the two fields every reader already parses (<ts> | <user> |). The store's answer is made by the tooling,
# once for each account, so a run never starts from a bare Slack id and never has to remember to look: a sender with no record reads
# `no record: do not address by name, escalate`, which is the whole instruction for that sender.
#
# -v map=<file>    rows `<slack id><TAB><label>` for the accounts the store knows
# -v owner=<id>    the human-owner's account, which is never marked
#
# Read on stdin, printed on stdout, every line kept in its place. A team post (its text names a member as `*_member_*`) and the owner's own
# messages are printed as they stand. A head whose author is no Slack account id is printed as it stands: a sender is never invented.

BEGIN {
	while ( ( getline row < map ) > 0 ) {
		at = index(row, "\t") ;
		if (at > 1) { known[substr(row, 1, at - 1)] = substr(row, at + 1) ; }
	}
	close(map) ;
}

{
	if ( $0 ~ /^[0-9]+\.[0-9]+ \| U[A-Z0-9]+ \|/ && match($0, /^[0-9]+\.[0-9]+ \| [^|]* \|/) ) {
		headEnd = RLENGTH ;
		head = substr($0, 1, headEnd) ;
		id = head ;
		sub(/^[0-9]+\.[0-9]+ \| /, "", id) ;
		sub(/ \|$/, "", id) ;
		## A team post names its member in the header, as `*_member_*` now and as `member @handle` in the older form: either is no outsider.
		if ( id != owner && $0 !~ /\*_[a-z0-9-]+_\*/ && $0 !~ /(magic|keeper|partner|client)-[a-z0-9-]+\*?_?\*? @[a-z0-9]+/ ) {
			label = ( id in known ) ? known[id] : "no record: do not address by name, escalate" ;
			print head " [sender: " label "]" substr($0, headEnd + 1) ;
			next ;
		}
	}
	print ;
}
