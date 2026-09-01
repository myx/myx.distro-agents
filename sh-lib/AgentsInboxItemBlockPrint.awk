#!/usr/bin/awk -f
##
## AgentsInboxItemBlockPrint.awk -- prints the COMPLETE `## inbox/<filename>`
## block for every file named on its command line: the heading, the item's
## `key: value` frontmatter verbatim, the framing keys, the body byte-identical
## to storage up to the per-item byte cap, and the single blank line that closes
## each block. One invocation renders a whole section.
##
## ONE PROCESS PER SECTION, NOT TWO PER ITEM. This is on the hot path -- every
## session, every member, four sections -- so the whole section is rendered by
## a single awk over all its files. No per-file subprocess, no counting pass
## followed by a reading pass: each file is read exactly once, and everything
## the framing declares is computed from that one read.
##
## RS IS SET TO \004 SO EACH FILE ARRIVES AS ONE RECORD. That is what makes the
## single read possible, and it is also the only way to see whether the stored
## file ends in a newline: awk's normal line splitting discards exactly that
## fact, and asking the shell for it (`tail -c 1`) would be a subprocess per
## item, which is what this script exists to avoid. \004 (EOT) is a control
## character that does not occur in these documents; a file containing one
## would split into two records and mis-frame, and nothing quieter than that
## can be arranged without giving up the single read.
##
## WHY A DECLARED LINE COUNT AND NO DELIMITER. The document's block grammar is
## `^## ` anchored, and a raw body may legally contain a line starting `## ` --
## so the heading rule alone cannot survive real bodies. No fence or sentinel
## fixes it either: every candidate delimiter is a string some body may legally
## contain, and picking a rarer one only moves the collision further away.
## A count cannot be imitated, because nothing in the body is matched against
## at all. It keeps the format line-oriented, so awk and grep still work over
## the document; it keeps the body byte-exact; and it is self-checking -- after
## N body lines a reader must find `## ` or EOF, and if it does not, the
## document is corrupt and the reader can say so instead of mis-parsing.
##
## Emitted shape:
##   ## inbox/<filename>
##   <frontmatter key: value lines, verbatim>
##   body-truncated: <T> bytes stored, capped at <cap> -- <N> of <M> lines emitted
##   body-final-newline: absent
##   body-lines: <N>
##   <exactly N lines, byte-identical to storage>
##   <one blank line>
##
## `body-lines:` is ALWAYS the last key before the body -- that is where a
## reader stops treating lines as headers -- so both optional keys sit BEFORE
## it. `body-truncated:` is the per-item companion mark the byte cap requires:
## a mid-frame cut with no mark breaks the count contract outright, because a
## reader consuming N lines walks into the next block. It states the stored
## size so a member knows to go read the whole item.
##
## THE CAP CUTS WHOLE LINES ONLY. The maximal run of leading body lines whose
## cumulative bytes fit the cap is emitted; a line is never cut in half,
## because half a line is not byte-identical to anything and would still count
## as a line. A single first line larger than the cap therefore emits zero body
## lines, and the mark says so rather than the block quietly holding nothing.
##
## Frontmatter delimiting matches AgentsBoardItemFrontmatterPrint.awk, the
## sibling this script extends, so the two never disagree about where an item's
## frontmatter ends: both fences present -> frontmatter strictly between them,
## body everything after the closing fence; opening fence only (malformed) ->
## everything after it is frontmatter and the body is empty; no fence at all ->
## no frontmatter and the WHOLE file is body. The sibling prints nothing for a
## fence-less file, which here would silently drop the item's entire content --
## the one outcome this document exists to prevent.
##
## Variables: -v bodyByteCap=<n> (default 8192). LC_ALL=C is required by the
## caller so `length()` counts bytes rather than characters.
##
BEGIN {
	RS = "\004" ;
	if ( bodyByteCap == "" ) { bodyByteCap = 8192 ; }
	bodyByteCap = bodyByteCap + 0 ;
	## Index of the next ARGV operand this script still owes a block for. The
	## boundary rule below and END between them walk it to ARGC, so every
	## operand gets exactly one block whether or not it produced a record.
	argi = 1 ;
}

##
## A ZERO-BYTE ITEM PRODUCES NO RECORD, SO THE MAIN RULE NEVER FIRES FOR IT.
## Left unhandled the operand vanishes from the document while the calling
## section's own scanned/matched counts still include it -- the document
## asserts the item matched and then does not show it, and the counts agree
## with themselves, so it is the one shape a reader cannot detect. The
## per-item invocation this file replaced ran an END per file and could not
## lose one; collapsing to a single invocation for speed is what introduced
## it. A truncated or interrupted inbox write produces exactly a zero-byte
## `.md`, so this is a real state, not a synthetic one.
##
## THE STUB IS NOT A NORMAL BLOCK WITH `body-lines: 0`. That form is
## indistinguishable from an item that legitimately has frontmatter and no
## body, which would trade a silent omission for a silent misreport. It
## carries its own key naming the file as empty, and still ends on
## `body-lines:` so the framing contract holds for a reader that knows only
## that key.
##
function emitEmptyOperandStub( path,    stubName ) {
	stubName = path ;
	sub( /^.*\//, "", stubName ) ;
	printf "## inbox/%s\n", stubName ;
	printf "body-empty-file: 0 bytes stored -- the item file is empty, nothing to read\n" ;
	print "body-lines: 0" ;
	print "" ;
}

## Emitted IN ORDER, in the operand's own position, never appended at the end:
## at every file boundary, flush every operand still owed a block that comes
## before the file now starting. FNR == 1 is the boundary -- with RS = "\004"
## a normal file is one record, and a file that somehow held a \004 continues
## at FNR > 1 without consuming a second operand.
FNR == 1 {
	while ( argi < ARGC && ARGV[argi] != FILENAME ) {
		if ( ARGV[argi] != "" ) { emitEmptyOperandStub( ARGV[argi] ) ; }
		argi++ ;
	}
	if ( argi < ARGC ) { argi++ ; }
}

{
	name = FILENAME ;
	sub( /^.*\//, "", name ) ;
	printf "## inbox/%s\n", name ;

	content = $0 ;
	contentLen = length( content ) ;
	finalNewline = ( contentLen > 0 && substr( content, contentLen, 1 ) == "\n" ) ;

	if ( contentLen == 0 ) {
		total = 0 ;
	} else {
		total = split( content, L, "\n" ) ;
		## A trailing newline produces one empty trailing element that is not
		## a line of the file.
		if ( finalNewline ) { total-- ; }
	}

	fenceOpen = 0 ; fenceClose = 0 ;
	for ( i = 1 ; i <= total ; i++ ) {
		if ( L[i] == "---" ) {
			if ( fenceOpen == 0 ) { fenceOpen = i ; }
			else { fenceClose = i ; break ; }
		}
	}

	if ( fenceOpen > 0 && fenceClose > 0 ) {
		fmFrom = fenceOpen + 1 ; fmTo = fenceClose - 1 ;
		bodyFrom = fenceClose + 1 ; bodyTo = total ;
	} else if ( fenceOpen > 0 ) {
		fmFrom = fenceOpen + 1 ; fmTo = total ;
		bodyFrom = 1 ; bodyTo = 0 ;
	} else {
		fmFrom = 1 ; fmTo = 0 ;
		bodyFrom = 1 ; bodyTo = total ;
	}

	for ( i = fmFrom ; i <= fmTo ; i++ ) { print L[i] ; }

	bodyCount = bodyTo - bodyFrom + 1 ;
	if ( bodyCount < 0 ) { bodyCount = 0 ; }

	## One pass over the body: total size and the capped prefix length are
	## found together, never by measuring first and re-walking after.
	bodyBytes = 0 ; emitBytes = 0 ; emitCount = 0 ; capping = 1 ;
	for ( i = bodyFrom ; i <= bodyTo ; i++ ) {
		lineBytes = length( L[i] ) + 1 ;
		bodyBytes += lineBytes ;
		if ( capping ) {
			if ( emitBytes + lineBytes <= bodyByteCap ) {
				emitBytes += lineBytes ;
				emitCount++ ;
			} else {
				capping = 0 ;
			}
		}
	}

	if ( emitCount < bodyCount ) {
		printf "body-truncated: %d bytes stored, capped at %d -- %d of %d lines emitted\n", \
			bodyBytes, bodyByteCap, emitCount, bodyCount ;
	}
	## Only meaningful when a body is actually emitted whole -- a body that was
	## cut does not reach its own last byte, so whether storage ended in a
	## newline says nothing about what this block contains.
	if ( ! finalNewline && bodyCount > 0 && emitCount == bodyCount ) {
		print "body-final-newline: absent" ;
	}
	print "body-lines: " emitCount ;

	for ( i = bodyFrom ; i < bodyFrom + emitCount ; i++ ) { print L[i] ; }

	print "" ;
}

## The boundary rule can only flush operands that come BEFORE a file which
## actually produced a record, so a trailing empty operand -- or a run of
## them, or an all-empty operand list, where no boundary ever fires -- is
## flushed here. Same order, same stub, same position: still the operand's
## own place, because nothing follows it.
END {
	while ( argi < ARGC ) {
		if ( ARGV[argi] != "" ) { emitEmptyOperandStub( ARGV[argi] ) ; }
		argi++ ;
	}
}
