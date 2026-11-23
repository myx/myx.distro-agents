#!/usr/bin/awk -f
##
## AgentsInboxProcessedAtList.awk -- lists which inbox items carry the
## tool-stamped `processed-at:` field, for the inbox processed marker
## (contract: MAGIC.md, "Inbox items live in incoming/ and processed/"). Read by
## AgentsTools.InternOpInboxToProcessed.include (already-marked check),
## AgentsTools.InternOpSessionContextScan.include (active scopes drop marked
## items) and AgentsTools.InternTeamDataFinalGcDeletion.include (the
## retention clock).
##
## Input: on stdin, one item file path a line, never as operands: a folder holds
## more names than one command line takes. Prints one line per file whose
## frontmatter carries the field: `<path><TAB><value>` (value trimmed, possibly
## empty). Files without it, and paths that do not open, print nothing.
##
## Frontmatter is the block opened by a `---` FIRST line and closed by the next
## `---` line -- the same shape AgentsBoardItemHeaderOpsApply.awk writes, which
## is what stamps the field. A body line reading `processed-at: ...` never
## counts, and neither does a `---` block that does not start the file.
##
## Every closing `}` below is preceded by a `;` (magic-developer's
## reference/shell.md axiom).
##
{
	itemPath = $0 ; itemLineNo = 0 ;
	while ((getline itemLine < itemPath) > 0) {
		itemLineNo++ ;
		if (itemLineNo == 1) { if (itemLine != "---") { break ; } ; continue ; } ;
		if (itemLine == "---") { break ; } ;
		if (itemLine ~ /^processed-at:/) {
			stampValue = substr(itemLine, length("processed-at:") + 1) ;
			sub(/^[ \t]+/, "", stampValue) ; sub(/[ \t\r]+$/, "", stampValue) ;
			print itemPath "\t" stampValue ;
			break ;
		} ;
	} ;
	close(itemPath) ;
} ;
