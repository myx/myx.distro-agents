#!/usr/bin/awk -f
##
## AgentsKnowledgeScan.awk -- the sections of markdown files that answer a query (TeamKnowledge, F7.3: DistroAgentsKnowledge.fn.sh, whose
## include AgentsTools.Knowledge.include runs it). stdin: the files to read, one path a line.
##
## THE QUERY is in the environment, KNOWLEDGE_QUERY, one token a line, in the order the options came:
##   `kw <text>`   a line holds the text, upper or lower case alike       `re <text>`   a line matches the extended regular expression
##   `gl <text>`   a whole line matches the shell glob (`*`, `?`, `[...]`)
##   `open and` / `open or` ... `close`   a group, all of its terms hold / any of them holds; the query as a whole is a group of `and`
## THE UNIT is the section: the lines of a heading down to the next heading of any depth, the heading line included; the lines ahead of a file's first
## heading are a section of their own, with no caption (a file with no heading is one). A term holds of a section when a line of that section answers
## it. A file's leading front matter, `---` down to the next, is not read; a `#` inside a code fence is no heading.
##
## OUTPUT, by -v format=:
##   list   a line for each section that answers: `<path><TAB><source><TAB><store><TAB><caption>` (an empty caption: the lines ahead of the first heading)
##   json   {"entries":[{"source":..,"store":..,"section":..,"snippet":..}]}, the snippet the section's own text (cut at 4000 bytes, "truncated":true then)
## -v wsRoot=<workspace>/ and -v dataRoot=<team data root>/ turn a path into its source, relative to the one it lies under; the store is `board`,
## `vault`, `inbox` where the path lies under the team data root's board/, vault/ or inboxes/, and `docs` for any other.
##
## Every closing `}` below is preceded by a `;` (magic-developer's reference/shell.md axiom).
##

## A glob as an anchored regular expression, as LocalMergeMdFiles.awk reads one.
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

## A text as the inside of a JSON string.
function jsonText(text,    out, at, ch) {
	gsub(/\\/, "\\\\", text) ; gsub(/"/, "\\\"", text) ; gsub(/\t/, "\\t", text) ; gsub(/\r/, "\\r", text) ; gsub(/\n/, "\\n", text) ;
	if (text !~ /[\001-\010\013\014\016-\037]/) { return text ; } ;
	out = "" ;
	for (at = 1 ; at <= length(text) ; at++) {
		ch = substr(text, at, 1) ;
		if (ch < " ") { out = out sprintf("\\u%04x", index(controlChars, ch)) ; } else { out = out ch ; } ;
	} ;
	return out ;
} ;

## Whether a line answers a term.
function lineAnswers(term, line) {
	if (kind[term] == "kw") { return index(tolower(line), needle[term]) > 0 ; } ;
	if (kind[term] == "re") { return line ~ arg[term] ; } ;
	return line ~ globRx[term] ;
} ;

## Whether the section read answers the query: the groups walked in order, a stack of them.
function sectionAnswers(    term, line, depth, token, value) {
	for (term = 1 ; term <= tokenCount ; term++) {
		hit[term] = 0 ;
		if (kind[term] == "open" || kind[term] == "close") { continue ; } ;
		for (line = 1 ; line <= sectionLines ; line++) { if (lineAnswers(term, sectionText[line])) { hit[term] = 1 ; break ; } ; } ;
	} ;
	depth = 1 ; groupOp[1] = "and" ; groupValue[1] = 1 ;
	for (token = 1 ; token <= tokenCount ; token++) {
		if (kind[token] == "open") { depth++ ; groupOp[depth] = arg[token] ; groupValue[depth] = ( arg[token] == "and" ) ? 1 : 0 ; continue ; } ;
		if (kind[token] == "close") { value = groupValue[depth] ; depth-- ; } else { value = hit[token] ; } ;
		if (groupOp[depth] == "and") { groupValue[depth] = groupValue[depth] && value ; } else { groupValue[depth] = groupValue[depth] || value ; } ;
	} ;
	return groupValue[1] ;
} ;

## The section read, if it answers.
function flushSection(    line, text, cut) {
	if (sectionLines == 0) { return ; } ;
	text = "" ;
	for (line = 1 ; line <= sectionLines ; line++) { text = text sectionText[line] "\n" ; } ;
	if (text ~ /^[ \t\n]*$/) { sectionLines = 0 ; return ; } ;
	if (sectionAnswers()) {
		if (format == "json") {
			sub(/\n+$/, "", text) ; cut = 0 ;
			if (length(text) > 4000) { text = substr(text, 1, 4000) ; cut = 1 ; } ;
			printf "%s{\"source\":\"%s\",\"store\":\"%s\",\"section\":\"%s\",\"snippet\":\"%s\"%s}", ( entryCount++ ? ",\n" : "" ), jsonText(fileRef), jsonText(fileStore), jsonText(sectionCaption), jsonText(text), ( cut ? ",\"truncated\":true" : "" ) ;
		} else {
			printf "%s\t%s\t%s\t%s\n", filePath, fileRef, fileStore, sectionCaption ;
		} ;
	} ;
	sectionLines = 0 ;
} ;

## A file read section by section. A path named in KNOWLEDGE_STORE_MAP (a store dumped to a scratch file) keeps the
## MAGIC.md reference it was dumped from as its source, not the scratch path it was read through.
function scanFile(path,    rel, line, inFront, lineNo, inFence, fenceMark, mark, caption, at) {
	filePath = path ; fileStore = "docs" ; rel = path ;
	if (dataRoot != "" && index(path, dataRoot) == 1) {
		rel = substr(path, length(dataRoot) + 1) ;
		fileStore = ( rel ~ /^board\// ) ? "board" : ( rel ~ /^vault\// ) ? "vault" : ( rel ~ /^inboxes\// ) ? "inbox" : "team" ;
	} else if (wsRoot != "" && index(path, wsRoot) == 1) { rel = substr(path, length(wsRoot) + 1) ; } ;
	fileRef = rel ;
	for (at = 1 ; at <= storeMapCount ; at++) { if (path == storeMapPath[at]) { fileRef = storeMapRef[at] ; break ; } ; } ;
	sectionLines = 0 ; sectionCaption = "" ; inFront = 0 ; lineNo = 0 ; inFence = 0 ; fenceMark = "" ;
	while ((getline line < path) > 0) {
		lineNo++ ;
		sub(/\r$/, "", line) ;
		if (lineNo == 1 && line == "---") { inFront = 1 ; continue ; } ;
		if (inFront) { if (line == "---") { inFront = 0 ; } ; continue ; } ;
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
	close(path) ;
	flushSection() ;
} ;

BEGIN {
	for (code = 1 ; code < 32 ; code++) { controlChars = controlChars sprintf("%c", code) ; } ;
	queryCount = split(ENVIRON["KNOWLEDGE_QUERY"], queryLine, "\n") ;
	for (at = 1 ; at <= queryCount ; at++) {
		if (queryLine[at] == "") { continue ; } ;
		tokenCount++ ;
		gap = index(queryLine[at], " ") ;
		if (gap == 0) { kind[tokenCount] = queryLine[at] ; arg[tokenCount] = "" ; } else { kind[tokenCount] = substr(queryLine[at], 1, gap - 1) ; arg[tokenCount] = substr(queryLine[at], gap + 1) ; } ;
		if (kind[tokenCount] == "kw") { needle[tokenCount] = tolower(arg[tokenCount]) ; } ;
		if (kind[tokenCount] == "gl") { globRx[tokenCount] = globRegex(arg[tokenCount]) ; } ;
	} ;
	storeMapCount = 0 ;
	if ("KNOWLEDGE_STORE_MAP" in ENVIRON) {
		mapCount = split(ENVIRON["KNOWLEDGE_STORE_MAP"], mapLine, "\n") ;
		for (at = 1 ; at <= mapCount ; at++) {
			if (mapLine[at] == "") { continue ; } ;
			gap = index(mapLine[at], "\t") ;
			if (gap > 0) { storeMapCount++ ; storeMapPath[storeMapCount] = substr(mapLine[at], 1, gap - 1) ; storeMapRef[storeMapCount] = substr(mapLine[at], gap + 1) ; } ;
		} ;
	} ;
	if (format == "json") { print "{\"entries\":[" ; } ;
} ;

NF { scanFile($0) ; } ;

END {
	if (format == "json") { print "" ; print "]}" ; } ;
} ;
