##
## AgentsItemRenameSweep.awk -- the reference sweep for
## --intern-op-item-rename (AgentsTools.InternOpItemRename.include).
## Externalized per this package's own externalize-awk/py convention (see
## AgentsBoardItemFrontmatterPrint.awk's own header comment for that name) --
## unconditional, no size-based exception.
##
## Rewrites EVERY occurrence of an item's old name so it reads as the new
## name. Two forms, in this order: the full filename
## (`<stem>.<ext>` -> `<stem>.<ext>`) and then the bare stem. Measured on the
## live tree before this was written: of 115 board reference-field lines, 110
## carried the BARE stem and only 5 carried the full filename -- a
## filename-only rule rewrites 5 and silently leaves 110 pointing at a name
## that no longer exists.
##
## SCOPE IS EVERY OCCURRENCE, INCLUDING PROSE. An earlier draft of this file
## restricted rewriting to pointer fields (supersedes:/references:/blocks:
## and their list items) and left narrative alone, on the reasoning that
## rewriting a status: line describing a past event edits history rather than
## a pointer. That was overruled: a name is a name, and if the file is called
## something else then every mention of it says so. The field whitelist and
## its two modes are gone -- do not reintroduce them as a "safety"
## improvement.
##
## NOTHING HERE REACHES A REGEX ENGINE. The names are literal data and arrive
## via ENVIRON[] rather than -v, because -v performs its own escape
## processing on the value before the program ever sees it -- the defect
## already documented at AgentsTools.InternOpBoardRename.include's own sweep.
## There is no match(), no gsub(), no pattern of any kind: only index(),
## substr() and character walks.
##
## THE BOUNDARY TEST IS THE RUN-TIME COLLISION ASSERTION. A survey found zero
## cases where one item name is a strict prefix of another, but that is a
## fact about today's data, not a property of the design -- and with prose now
## in scope the sweep touches far more text than the survey covered. So every
## candidate match is checked in place: the character before it and the
## character after it must both be outside the name-character set, or the
## occurrence is left alone. A longer name that merely starts with this one
## can therefore never be corrupted, whether or not the survey saw it.
##
## Inputs (all four required):
##   ENVIRON["MDAT_RENAME_OLD"]       old full filename, with extension
##   ENVIRON["MDAT_RENAME_NEW"]       new full filename, with extension
##   ENVIRON["MDAT_RENAME_OLD_STEM"]  old filename minus its final extension
##   ENVIRON["MDAT_RENAME_NEW_STEM"]  new filename minus its final extension
##

function isNameChar(c) {
	## Explicit enumeration, never a bracket range. Measured on this box:
	## under en_US.UTF-8 a [a-z] range MATCHES "A"; under LC_ALL=C it does
	## not. Collation-dependent ranges are not whitelists. '.' is a name
	## character here so that `<stem>.<ext>` is never treated as a stem
	## sitting at a boundary. It blocks only as an extension separator --
	## see replaceWhole()'s own note. This does NOT depend on which pass runs
	## first: a stem followed by `.md` is blocked by the boundary test either
	## way, so the two passes produce identical output in either order.
	return index("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.", c) > 0
}

## Boundary-checked literal replacement of every whole occurrence of `from`
## with `to`, in `line`. Returns the rewritten line.
function replaceWhole(line, from, to,   out, rest, base, p, absP, fromLen, prevOK, nextOK, after, nextChar) {
	fromLen = length(from)
	if ( fromLen == 0 ) { return line ; }
	out = ""
	rest = line
	base = 0
	while ( ( p = index(rest, from) ) > 0 ) {
		absP = base + p

		prevOK = ( absP == 1 )
		if ( ! prevOK ) { prevOK = ! isNameChar(substr(line, absP - 1, 1)) ; }

		after = substr(rest, p + fromLen)
		nextOK = ( length(after) == 0 )
		if ( ! nextOK ) {
			nextChar = substr(after, 1, 1)
			if ( ! isNameChar(nextChar) ) {
				nextOK = 1
			} else if ( nextChar == "." ) {
				## A '.' blocks only as an EXTENSION SEPARATOR -- another name
				## character must follow it to count as one. A '.' at end of
				## line, or before a space or other punctuation, is sentence
				## punctuation and must not block the rewrite.
				##
				## Treating '.' as a boundary character unconditionally silently
				## skipped every name ending a sentence. Measured against the
				## real corpus: 14 live `<name>.md.` occurrences were being
				## missed -- the sweep reported success, counted the file as
				## touched, and left those mentions pointing at the old name.
				## Prose is explicitly in scope, and `<name>.md.` is one of the
				## commonest shapes prose takes here. That is the exact silent
				## class this boundary assertion exists to prevent, arriving
				## through the assertion itself.
				##
				## KNOWN RESIDUAL, measured and deliberately left: a name
				## followed by TWO OR MORE dots is still skipped. `.` is itself
				## a name character, so in `<name>..` the second dot satisfies
				## "a name character follows" and blocks the rewrite. Measured
				## against the real corpus: 3 occurrences, against 14 for the
				## single-dot case this branch fixes. Ellipsis-after-a-name is
				## the realistic shape.
				##
				## NOT fixed here because the obvious fix -- skip the run of
				## dots, then test the character after it -- carries its own
				## edge that nobody has ruled on: `<name>...text` would then
				## still block, and whether that is right depends on whether
				## the dots are an ellipsis or a path. Narrowed from 14 to 3,
				## NOT eliminated. Do not read this branch as closing the class.
				nextOK = ( length(after) < 2 || ! isNameChar(substr(after, 2, 1)) )
			} else {
				nextOK = 0
			}
		}

		if ( prevOK && nextOK ) {
			out = out substr(rest, 1, p - 1) to
		} else {
			## Not a whole-name match -- part of a longer name. Emit it
			## untouched and step past it. This is the assertion, applied per
			## occurrence at run time rather than assumed from a survey.
			out = out substr(rest, 1, p - 1) substr(rest, p, fromLen)
		}

		base = base + p - 1 + fromLen
		rest = substr(rest, p + fromLen)
	}
	return out rest
}

BEGIN {
	oldFull = ENVIRON["MDAT_RENAME_OLD"]
	newFull = ENVIRON["MDAT_RENAME_NEW"]
	oldStem = ENVIRON["MDAT_RENAME_OLD_STEM"]
	newStem = ENVIRON["MDAT_RENAME_NEW_STEM"]
	## ALL FOUR are validated, not just the full names. The stems are NOT
	## derived here on purpose: deriving them would mean this file deciding
	## where the extension boundary falls, and a caller that forgot to pass
	## them would get a silently different answer instead of an error.
	##
	## Validating only the two full names produced exactly one silent
	## half-sweep already. Two instances measured this file and disagreed about
	## whether the bare-stem pass fired; the difference was entirely the
	## invocation. With the stems unset, replaceWhole()'s own length-0 guard
	## returns the line untouched, so the full-name pass rewrote `<name>.md`,
	## the stem pass did nothing at all, and the script still exited 0 and
	## reported success. Prose cites bare stems -- 110 of 115 measured board
	## reference lines carry the stem and not the filename -- so that failure
	## mode quietly leaves the majority of references stale while looking
	## clean. Loud, always, over half a sweep reported as a whole one.
	if ( length(oldFull) == 0 || length(newFull) == 0 || length(oldStem) == 0 || length(newStem) == 0 ) {
		print "AgentsItemRenameSweep.awk: all four of MDAT_RENAME_OLD, MDAT_RENAME_NEW, MDAT_RENAME_OLD_STEM, MDAT_RENAME_NEW_STEM must be set (stems are never derived here -- see this file's own BEGIN note)" > "/dev/stderr"
		exit 1
	}
}

{
	## Full filename first, then the bare stem -- for readability, NOT for
	## correctness. An earlier version of this comment claimed the order was
	## load-bearing ("after the first pass no `<stem>.<ext>` occurrence
	## survives"); it is not, and the claim was checked rather than assumed.
	## replaceWhole()'s boundary test already blocks a stem followed by an
	## extension separator, so a stem-first run leaves `<stem>.<ext>` untouched
	## and both orders produce identical output.
	##
	## Stated because a false guarantee is worse than none: someone would
	## later either reorder these "safely" on the strength of a dependency the
	## code never had, or preserve the order for a reason that was never true.
	line = replaceWhole($0, oldFull, newFull)
	line = replaceWhole(line, oldStem, newStem)
	print line
}
