#!/usr/bin/awk -f
##
## AgentsBoardItemFrontmatterFieldProbe.awk -- reports whether one named field
## is present in a body's own frontmatter, for the move-stamp defaults in
## AgentsTools.InternOpBoardUpsertMoveEdit.include and
## AgentsTools.InternOpInboxToProcessed.include (contract: MAGIC.md).
##
## Body on stdin, `-v fieldName=<name>`. Prints exactly one of:
##   HAS         -- frontmatter present, and it carries `<fieldName>: `
##   FRONTMATTER -- frontmatter present, field absent (stampable)
##   NONE        -- no complete `---` block, so there is nowhere to stamp
## Bounded to the block between the first two `---` lines, never a
## `/^field: /`-anywhere match: a body line reading `<fieldName>: ...` must not
## be mistaken for the header, the same bound AgentsToolsFinalGcReadItemHeaders
## applies when it reads these fields back.
##
## Every closing `}` below is preceded by a `;` (magic-developer's
## reference/shell.md axiom).
##
$0 == "---" {
	fmDepth++ ;
	if (fmDepth >= 2) { closedFm = 1 ; exit ; } ;
	next ;
} ;
fmDepth == 1 && $0 ~ "^" fieldName ": " { foundField = 1 ; } ;
END {
	if (foundField) { print "HAS" ; }
	else if (closedFm) { print "FRONTMATTER" ; }
	else { print "NONE" ; } ;
} ;
