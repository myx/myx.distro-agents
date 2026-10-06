#!/usr/bin/awk -f
##
## AgentsInboxProcessedAtList.awk -- lists which inbox items carry the
## tool-stamped `processed-at:` field, for the in-place inbox processed marker
## (contract: MAGIC.md, "Inbox items are marked processed in place"). Read by
## AgentsTools.InternOpInboxToProcessed.include (already-marked check),
## AgentsTools.InternOpSessionContextScan.include (active scopes drop marked
## items) and AgentsTools.InternTeamDataFinalGcDeletion.include (the
## retention clock).
##
## Input: one or more item files as operands. Prints one line per file whose
## frontmatter carries the field: `<path><TAB><value>` (value trimmed, possibly
## empty). Files without it print nothing.
##
## Frontmatter is the block opened by a `---` FIRST line and closed by the next
## `---` line -- the same shape AgentsBoardItemHeaderOpsApply.awk writes, which
## is what stamps the field. A body line reading `processed-at: ...` never
## counts, and neither does a `---` block that does not start the file.
##
## Every closing `}` below is preceded by a `;` (magic-developer's
## reference/shell.md axiom).
##
FNR == 1 { inFm = ($0 == "---") ; done = 0 ; next ; } ;
inFm && $0 == "---" { inFm = 0 ; next ; } ;
inFm && !done && $0 ~ /^processed-at:/ {
	v = substr($0, length("processed-at:") + 1) ;
	sub(/^[ \t]+/, "", v) ; sub(/[ \t\r]+$/, "", v) ;
	print FILENAME "\t" v ;
	done = 1 ;
	next ;
} ;
