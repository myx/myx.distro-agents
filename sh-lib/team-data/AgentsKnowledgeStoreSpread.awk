#!/usr/bin/awk -f
##
## AgentsKnowledgeStoreSpread.awk -- the sections of one MAGIC.md, split for the spread operation (F8.3,
## sh-lib/team-data/AgentsTools.KnowledgeStore.include). The same section unit as AgentsKnowledgeScan.awk: a heading
## down to the next heading of any depth, the heading line included; the lines ahead of the first heading and the front
## matter are kept as they stand. A section whose caption matches a glob of SPREAD_KEEP (one glob a line) stays; every
## other section moves to the store.
##
## Read: -v file=<path>, the one MAGIC.md.
## Written, through the variables (nothing on stdout):
##   SPREAD_KEPT     the file as it stays: front matter, the preamble, and every kept section, verbatim
##   SPREAD_MANIFEST one line a moved section: `<caption><TAB><body-file>`, the body the section's lines without its heading
##   the body files  SPREAD_DIR/<n>.body, one a moved section
## Every closing `}` below is preceded by a `;` (magic-developer's reference/shell.md axiom).
##

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

function keptSection(    at) {
	for (at = 1 ; at <= keepCount ; at++) { if (sectionCaption ~ keepRx[at]) { return 1 ; } ; } ;
	return 0 ;
} ;

function flushSection(    at) {
	if (sectionLines == 0) { return ; } ;
	if (sectionCaption == "") { for (at = 1 ; at <= sectionLines ; at++) { print sectionText[at] > keptPath ; } ; sectionLines = 0 ; return ; } ;
	if (keptSection()) {
		for (at = 1 ; at <= sectionLines ; at++) { print sectionText[at] > keptPath ; } ;
	} else {
		bodyFile = sprintf("%s/%d.body", spreadDir, ++movedCount) ;
		for (at = 2 ; at <= sectionLines ; at++) { print sectionText[at] > bodyFile ; } ;
		close(bodyFile) ;
		print sectionCaption "\t" bodyFile > manifestPath ;
	} ;
	sectionLines = 0 ;
} ;

BEGIN {
	n = split(ENVIRON["SPREAD_KEEP"], keepGlob, "\n") ;
	keepCount = 0 ;
	for (at = 1 ; at <= n ; at++) { if (keepGlob[at] != "") { keepRx[++keepCount] = globRegex(keepGlob[at]) ; } ; } ;
	keptPath = ENVIRON["SPREAD_KEPT"] ;
	manifestPath = ENVIRON["SPREAD_MANIFEST"] ;
	spreadDir = ENVIRON["SPREAD_DIR"] ;
	movedCount = 0 ;
	sectionLines = 0 ; sectionCaption = "" ; inFront = 0 ; lineNo = 0 ; inFence = 0 ; fenceMark = "" ;
	while ((getline line < file) > 0) {
		lineNo++ ;
		sub(/\r$/, "", line) ;
		if (lineNo == 1 && line == "---") { inFront = 1 ; print line > keptPath ; continue ; } ;
		if (inFront) { print line > keptPath ; if (line == "---") { inFront = 0 ; } ; continue ; } ;
		if (match(line, /^[ \t]*(```|~~~)/)) {
			mark = substr(line, RSTART + RLENGTH - 3, 3) ;
			if (!inFence) { inFence = 1 ; fenceMark = mark ; } else if (mark == fenceMark) { inFence = 0 ; } ;
		} else if (!inFence && match(line, /^#+[ \t]/) && RLENGTH <= 7) {
			flushSection() ;
			caption = substr(line, RLENGTH + 1) ;
			sub(/^[ \t]+/, "", caption) ; sub(/[ \t]+#*[ \t]*$/, "", caption) ; sub(/[ \t]+$/, "", caption) ; gsub(/\t/, " ", caption) ;
			sectionCaption = caption ;
		} ;
		sectionLines++ ; sectionText[sectionLines] = line ;
	} ;
	close(file) ;
	flushSection() ;
	close(keptPath) ; close(manifestPath) ;
} ;
