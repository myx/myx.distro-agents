#!/usr/bin/awk -f
##
## AgentsMergeMdFiles.awk -- the markdown nesting engine behind --intern-merge-md-files
## (AgentsTools.InternMergeMdFiles.include, contract: MAGIC.md). Every file comes in by a mixin,
## which names the section it becomes; this awk reads the mixins itself, each file once, in one
## process, and prints the merged document on stdout.
##
## Input: `-v specFile=<path>`, one line a record, TAB-separated, in order:
##   `mixin <file> <section name>`, then any `include <glob>` / `exclude <glob>` of that mixin;
##   `-v prefix=<N>` the level of a mixin's section (1: `#`), `-v limit=<N>` how many levels of
##   the result are kept from there, `-v doIndex=1` for a Contents section first.
##
## THE DEPTHS. A file's own heading levels are never kept blindly: each heading's depth is its
## place among the headings open above it, so a level the file skips closes up, and a file that
## starts at `###` starts one level under its mixin. A heading of depth d is written at level
## prefix + d. A `#` line inside a code fence (``` or ~~~) is no heading. A file's leading front
## matter, a first line `---` down to the next, is left out.
##
## THE LIMIT. The deepest level written is prefix + limit - 1. A section deeper than that is
## replaced, with everything under it, by one line naming its heading and its file.
##
## THE FILTERS of a mixin, matched against a heading's caption at any depth, a glob (`*`, `?`,
## `[...]`) matching the whole caption: an excluded section is left out with everything under
## it. Where a mixin names any include, only the included sections are written, each with
## everything under it, and the headings above an included one, without their own text; the
## text ahead of the file's first heading is then left out too.
##
## Every closing `}` below is preceded by a `;` (magic-developer's reference/shell.md axiom).
##

function repeatText(text, count,    result) {
	result = "" ;
	while (count-- > 0) { result = result text ; } ;
	return result ;
} ;

## A glob as an anchored regular expression: `*` any run, `?` one character, `[...]` a class,
## every other character as itself.
function globRegex(glob,    out, at, ch, classEnd) {
	out = "^" ;
	for (at = 1 ; at <= length(glob) ; at++) {
		ch = substr(glob, at, 1) ;
		if (ch == "*") { out = out ".*" ; }
		else if (ch == "?") { out = out "." ; }
		else if (ch == "[") {
			classEnd = index(substr(glob, at + 1), "]") ;
			if (classEnd > 0) { out = out "[" substr(glob, at + 1, classEnd - 1) "]" ; at += classEnd ; }
			else { out = out "\\[" ; } ;
		}
		else if (index("\\^$.|+(){}", ch) > 0) { out = out "\\" ch ; }
		else { out = out ch ; } ;
	} ;
	return out "$" ;
} ;

function matchesAny(caption, kind, mixin,    k) {
	for (k = 1 ; k <= filterCount[mixin, kind] ; k++) {
		if (caption ~ filterRegex[mixin, kind, k]) { return 1 ; } ;
	} ;
	return 0 ;
} ;

function emit(line) { outCount++ ; outLines[outCount] = line ; } ;

## A heading as written: its level, its caption, and its entry of the index.
function emitHeading(level, caption) {
	emit(repeatText("#", level) " " caption) ;
	indexCount++ ; indexDepth[indexCount] = level - prefix ; indexCaption[indexCount] = caption ;
} ;

BEGIN {
	if (prefix == "") { prefix = 1 ; } ;
	if (limit == "") { limit = 3 ; } ;
	prefix += 0 ; limit += 0 ;
	deepest = prefix + limit - 1 ;
	mixinCount = 0 ;
	while ((getline specLine < specFile) > 0) {
		split(specLine, specField, "\t") ;
		if (specField[1] == "mixin") {
			mixinCount++ ; mixinFile[mixinCount] = specField[2] ; mixinName[mixinCount] = specField[3] ;
			filterCount[mixinCount, "include"] = 0 ; filterCount[mixinCount, "exclude"] = 0 ;
		} else if (specField[1] == "include" || specField[1] == "exclude") {
			filterCount[mixinCount, specField[1]]++ ;
			filterRegex[mixinCount, specField[1], filterCount[mixinCount, specField[1]]] = globRegex(specField[2]) ;
		} ;
	} ;
	close(specFile) ;

	for (m = 1 ; m <= mixinCount ; m++) {
		if (outCount > 0 && outLines[outCount] != "") { emit("") ; } ;
		emitHeading(prefix, mixinName[m]) ;
		emit("") ;
		including = (filterCount[m, "include"] > 0) ;
		## the open headings: their levels, captions, and whether each is written yet
		stackSize = 0 ; split("", stackLevel) ; split("", stackCaption) ; split("", stackWritten) ;
		dropDepth = 0 ; keepDepth = 0 ; inFence = 0 ; fenceMark = "" ; lineNo = 0 ; inFront = 0 ;
		file = mixinFile[m] ;
		while ((getline line < file) > 0) {
			lineNo++ ;
			sub(/\r$/, "", line) ;
			if (lineNo == 1 && line == "---") { inFront = 1 ; continue ; } ;
			if (inFront) { if (line == "---") { inFront = 0 ; } ; continue ; } ;
			## a code fence opens and closes on the same mark; nothing inside is a heading
			if (match(line, /^[ \t]*(```|~~~)/)) {
				mark = substr(line, RSTART + RLENGTH - 3, 3) ;
				if (!inFence) { inFence = 1 ; fenceMark = mark ; }
				else if (mark == fenceMark) { inFence = 0 ; } ;
			} else if (!inFence && match(line, /^#+[ \t]/) && RLENGTH <= 7) {
				level = RLENGTH - 1 ;
				caption = substr(line, RLENGTH + 1) ;
				sub(/^[ \t]+/, "", caption) ; sub(/[ \t]+#*[ \t]*$/, "", caption) ; sub(/[ \t]+$/, "", caption) ;
				while (stackSize > 0 && stackLevel[stackSize] >= level) { stackSize-- ; } ;
				stackSize++ ; stackLevel[stackSize] = level ; stackCaption[stackSize] = caption ; stackWritten[stackSize] = 0 ;
				depth = stackSize ;
				## a heading at or above the one a run of leaving out started at ends that run
				if (dropDepth > 0 && depth <= dropDepth) { dropDepth = 0 ; } ;
				if (keepDepth > 0 && depth <= keepDepth) { keepDepth = 0 ; } ;
				if (dropDepth > 0) { continue ; } ;
				if (matchesAny(caption, "exclude", m)) { dropDepth = depth ; continue ; } ;
				if (including && keepDepth == 0) {
					if (!matchesAny(caption, "include", m)) { continue ; } ;
					keepDepth = depth ;
					## the headings above an included one, without their own text
					for (a = 1 ; a < depth ; a++) {
						if (stackWritten[a]) { continue ; } ;
						if (prefix + a > deepest) { break ; } ;
						emitHeading(prefix + a, stackCaption[a]) ; emit("") ; stackWritten[a] = 1 ;
					} ;
				} ;
				if (prefix + depth > deepest) {
					emit("See \"" caption "\" in " file ", a section deeper than this merge shows.") ;
					dropDepth = depth ;
					continue ;
				} ;
				emitHeading(prefix + depth, caption) ;
				stackWritten[depth] = 1 ;
				continue ;
			} ;
			if (dropDepth > 0) { continue ; } ;
			if (including && keepDepth == 0) { continue ; } ;
			emit(line) ;
		} ;
		close(file) ;
	} ;

	if (doIndex) {
		print repeatText("#", prefix) " Contents" ;
		print "" ;
		for (i = 1 ; i <= indexCount ; i++) { print repeatText("  ", indexDepth[i]) "- " indexCaption[i] ; } ;
		print "" ;
	} ;
	## the last lines of the last file, as blank as they are, are not carried on
	while (outCount > 0 && outLines[outCount] == "") { outCount-- ; } ;
	for (i = 1 ; i <= outCount ; i++) { print outLines[i] ; } ;
} ;
