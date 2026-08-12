#!/usr/bin/awk -f
##
## AgentsMagicSweepSlackThreadNames.awk -- reads an --intern-op-session-context-scan
## document (## <state>/<item> blocks, blank-line-separated, each carrying at
## least a `communication-channel-id:` line -- the caller must have requested
## that header) on stdin, and prints one bare item-filename per line for every
## block whose value identifies a live, reply-pending Slack thread. Backs
## --magic-sweep-input-scan's own phase-1 (discover survivors) / phase-2
## (--item-restricted final display) two-call pattern -- see
## AgentsTools.MagicSweep.include's own header.
##
## The value is `<service>:<rest>`; only `slack:` and `email:` services exist.
## A Slack value is either `slack:<channel>` (channel only, nothing to reply
## into yet) or `slack:<channel>:<ts>` (channel plus the thread's own ts). Only
## the three-field form survives: a bare `slack:<channel>` carries no thread to
## re-read, and a non-slack service is not a Slack thread at all. Surrounding
## double quotes are tolerated -- these values are hand-written and
## inconsistently quoted in the real tree.
##
function reset() { curName = "" ; hasThread = 0 ; }
function flush() {
	if (curName != "" && hasThread) { print curName ; }
}
BEGIN { reset() ; }
/^## / {
	flush() ;
	reset() ;
	curName = $0 ;
	sub(/^## [^\/]*\//, "", curName) ;
	next ;
}
/^communication-channel-id: / {
	val = $0 ; sub(/^communication-channel-id: /, "", val) ; gsub(/^[ \t]+|[ \t]+$/, "", val) ; gsub(/^"|"$/, "", val) ;
	## split() is used rather than a regex so "three colon-separated fields"
	## is stated once, literally, and reads the same way as the board-thread
	## extractor in AgentsTools.InternOpSessionContextScan.include.
	nFields = split(val, fields, ":") ;
	if (nFields == 3 && fields[1] == "slack" && fields[2] != "" && fields[3] != "") { hasThread = 1 ; }
	next ;
}
END { flush() ; }
