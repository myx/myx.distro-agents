#!/usr/bin/awk -f
##
## AgentMagicSweepSlackThreadNames.awk -- reads an --intern-op-board-scan
## document (## <state>/<item> blocks, blank-line-separated, each carrying at
## least `source-slack-channel:`/`source-slack-ts:` lines -- the caller must
## have requested both headers. Legacy underscore aliases are accepted too.
## have requested both headers) on stdin, and prints one bare item-filename
## per line for every block where BOTH values are non-empty. Backs
## --magic-sweep-input-scan's own phase-1 (discover survivors) / phase-2
## (--item-restricted final display) two-call pattern -- see
## AgentsTools.MagicSweep.include's own header.
##
function reset() { curName = "" ; hasChannel = 0 ; hasTs = 0 ; }
function flush() {
	if (curName != "" && hasChannel && hasTs) { print curName ; }
}
BEGIN { reset() ; }
/^## / {
	flush() ;
	reset() ;
	curName = $0 ;
	sub(/^## [^\/]*\//, "", curName) ;
	next ;
}
/^source-slack-channel: |^source_slack_channel: / {
	val = $0 ; sub(/^source-slack-channel: /, "", val) ; sub(/^source_slack_channel: /, "", val) ; gsub(/^[ \t]+|[ \t]+$/, "", val) ;
	if (val != "") { hasChannel = 1 ; }
	next ;
}
/^source-slack-ts: |^source_slack_ts: / {
	val = $0 ; sub(/^source-slack-ts: /, "", val) ; sub(/^source_slack_ts: /, "", val) ; gsub(/^[ \t]+|[ \t]+$/, "", val) ;
	if (val != "") { hasTs = 1 ; }
	next ;
}
END { flush() ; }
