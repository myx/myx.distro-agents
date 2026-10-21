#!/usr/bin/env awk
# ^^^ for syntax checking in the editor only

##
## AgentsDocSelfCheck.awk -- the text half of the rule set `document` of the one validator (F5.7), read in ONE pass over
## ONE document. A document is checked against itself: what it cites, what it counts, what it adds up, what it says twice.
## Needs no store, no model and no decision. Run by AgentsToolsDocValidateSelfCheck (AgentsTools.InternDocValidate.include),
## which answers the records that ask the filesystem, the board or the places; this file reads text only.
##
## Prints tab-separated records, one a line:
##   ROW   <line> <rule> <text>        a fault the text alone shows (the rules count, arithmetic, heading, order, replaced)
##   FILE  <line> <token>              a file cited in backticks: is it there
##   BOARD <line> <item name>          a board item cited in backticks: is it on the board
##   PLACE <line> <name>               a workspace or a place cited: is it registered
##   RULE  <line> <name> <file token>  a rule cited as **name** (`file:line`): is the NAME in that file (the line is a hint only)
## A file token of a RULE that is `:N` alone keeps the file of the RULE before it on the line.
##
## What is read: the lines after the frontmatter and outside a code fence. A sentence ends at its full stop, its question or
## exclamation mark (with the closers *, ), " and ' after it); at the end of a bold run that is the whole sentence so far; and
## at the end of a line that ends a bold run. A list item, a table row and a heading are blocks of their own, so a line
## without a full stop ends there.
##

function trimText(textIn,   textOut) {
	textOut = textIn ; sub(/^[ \t]+/, "", textOut) ; sub(/[ \t]+$/, "", textOut) ;
	return textOut ;
}

function plainText(textIn,   textOut) {
	textOut = textIn ; gsub(/[*`_]/, "", textOut) ;
	return trimText(textOut) ;
}

## The value of a number word two to twenty; 0 where the word is none.
function wordValue(wordIn,   wordLow) {
	wordLow = tolower(wordIn) ;
	if (wordLow in numWord) return numWord[wordLow] ;
	return 0 ;
}

## One character at a place of a text, empty past either end.
function charAt(textIn, atPlace) {
	if (atPlace < 1) return "" ;
	return substr(textIn, atPlace, 1) ;
}

## The line of an offset into the block being read.
function blockLineOf(atOffset,   idx, found) {
	found = blkLn[1] ;
	for (idx = 1 ; idx <= blkN ; idx++) {
		if (blkOff[idx] <= atOffset) found = blkLn[idx] ;
	}
	return found ;
}

## ---- sentences ----

## The sentences of a text, into sentText[1..sentN] and sentAt[1..sentN] (the offset each starts at).
function splitSentences(textIn,   textLen, pos, ch, closeAt, start, inCode, inBold, boldFrom, boldWhole, beforeBold, afterAt, afterCh, endAt) {
	sentN = 0 ; textLen = length(textIn) ; start = 1 ; inCode = 0 ; inBold = 0 ; boldFrom = 0 ;
	for (pos = 1 ; pos <= textLen ; pos++) {
		ch = substr(textIn, pos, 1) ;
		if (ch == "`") { inCode = !inCode ; continue ; }
		if (inCode) continue ;
		if (ch == "\001") {
			## A hard boundary: the line before it ended a bold run.
			if (pos > start) addSentence(textIn, start, pos - 1) ;
			start = pos + 1 ; inBold = 0 ;
			continue ;
		}
		if (ch == "*" && substr(textIn, pos, 2) == "**") {
			if (!inBold) { inBold = 1 ; boldFrom = pos ; pos++ ; continue ; }
			inBold = 0 ; pos++ ;
			## The run closes here. When it is the whole sentence so far and what follows begins a new one, it ends it.
			beforeBold = substr(textIn, start, boldFrom - start) ;
			afterAt = pos + 1 ;
			while (charAt(textIn, afterAt) == " ") afterAt++ ;
			afterCh = charAt(textIn, afterAt) ;
			if (beforeBold ~ /^[ ]*$/ && afterAt > pos + 1 && afterCh != "" && afterCh ~ /[A-Z0-9`*]/) {
				addSentence(textIn, start, pos) ;
				start = afterAt ; pos = afterAt - 1 ; inBold = 0 ;
			}
			continue ;
		}
		if (ch == "." || ch == "!" || ch == "?") {
			if (ch == "." && (substr(textIn, pos - 3, 4) == "e.g." || substr(textIn, pos - 3, 4) == "i.e." || substr(textIn, pos - 2, 3) == "vs.")) continue ;
			closeAt = pos + 1 ;
			while (charAt(textIn, closeAt) ~ /[]*)"'_]/) closeAt++ ;
			if (closeAt > textLen || charAt(textIn, closeAt) == " " || charAt(textIn, closeAt) == "\001") {
				addSentence(textIn, start, closeAt - 1) ;
				start = closeAt ;
				while (charAt(textIn, start) == " ") start++ ;
				pos = start - 1 ; inBold = 0 ;
			}
		}
	}
	if (start <= textLen) addSentence(textIn, start, textLen) ;
}

function addSentence(textIn, fromAt, toAt,   one) {
	one = substr(textIn, fromAt, toAt - fromAt + 1) ;
	if (trimText(one) == "") return ;
	sentN++ ; sentText[sentN] = one ; sentAt[sentN] = fromAt ;
}

## ---- counts ----

## The first count a sentence states that can be read as the count of the things it names: sets cntValue, cntWord and cntNoun.
## Returns 1 for one. It stands among the first five words and is followed by a plural noun, one word between allowed. A count
## followed by `of` counts a part, one after every/each/per/than/within/about/around is a rate or a bound, one with a
## preposition among the four words before it (over the 24 routines, in fifteen files) is the size of a population, one
## followed by a time or size is a measure, and a number joined to letters, dots, dashes or colons is an id, a date or a
## version: none of them states a count of the items that follow.
function firstCount(sentIn,   rest, shift, tokAt, tokLen, tok, tokIdx, prevCh, nextCh, valueOf, beforeTxt, afterTxt, prevTok, nounTok, nounNext, prevWords, prevN, prevIdx, prevHit) {
	rest = sentIn ; shift = 0 ; tokIdx = 0 ;
	while (match(rest, /[A-Za-z0-9]+/)) {
		tokAt = shift + RSTART ; tokLen = RLENGTH ; tok = substr(rest, RSTART, RLENGTH) ; tokIdx++ ;
		rest = substr(rest, RSTART + RLENGTH) ; shift = tokAt + tokLen - 1 ;
		if (tokIdx > 5) return 0 ;
		if (tok ~ /^[0-9]+$/) valueOf = tok + 0 ; else valueOf = wordValue(tok) ;
		if (valueOf < 2 || valueOf > 1000) continue ;
		prevCh = charAt(sentIn, tokAt - 1) ; nextCh = charAt(sentIn, tokAt + tokLen) ;
		if (prevCh != "" && prevCh ~ /[A-Za-z0-9_.\/#:@$-]/) continue ;
		if (nextCh != "" && nextCh ~ /[A-Za-z0-9_\/%@$-]/) continue ;
		if ((nextCh == "." || nextCh == ":") && charAt(sentIn, tokAt + tokLen + 1) ~ /[0-9]/) continue ;
		beforeTxt = tolower(substr(sentIn, 1, tokAt - 1)) ; gsub(/[^a-z]+/, " ", beforeTxt) ;
		prevN = split(beforeTxt, prevWords, " ") ; prevHit = 0 ;
		for (prevIdx = (prevN > 4 ? prevN - 3 : 1) ; prevIdx <= prevN ; prevIdx++) { if (prevWords[prevIdx] in rateWord) prevHit = 1 ; }
		if (prevHit) continue ;
		afterTxt = substr(sentIn, tokAt + tokLen) ; nounTok = "" ; nounNext = "" ;
		if (match(afterTxt, /^[^A-Za-z0-9]*[A-Za-z]+/)) {
			nounTok = substr(afterTxt, RSTART, RLENGTH) ; sub(/^[^A-Za-z]+/, "", nounTok) ;
			afterTxt = substr(afterTxt, RSTART + RLENGTH) ;
			if (match(afterTxt, /^[ ]+[A-Za-z]+/)) { nounNext = substr(afterTxt, RSTART, RLENGTH) ; sub(/^[ ]+/, "", nounNext) ; }
		}
		nounTok = tolower(nounTok) ; nounNext = tolower(nounNext) ;
		if (nounTok == "of" || nounTok in unitWord) return 0 ;
		if (!isPlural(nounTok)) { if (isPlural(nounNext)) nounTok = nounNext ; else return 0 ; }
		cntValue = valueOf ; cntWord = tolower(tok) ; cntNoun = nounTok ;
		return 1 ;
	}
	return 0 ;
}

## Whether a word reads as a plural noun: four letters or more, ending in s, and not in ss, us or is.
function isPlural(wordIn) {
	return (length(wordIn) >= 4 && wordIn ~ /s$/ && wordIn !~ /(ss|us|is)$/) ;
}

## ---- statements that are replaced ----

## The statement a sentence makes, with its numbers taken out: sets normText (the words, a number read as #) and normNums
## (the numbers in order, comma-separated). Returns the number of words.
function normalise(sentIn,   textLow, words, wordN, idx, tok, outText, numText, valueOf) {
	textLow = tolower(sentIn) ; gsub(/[^a-z0-9]+/, " ", textLow) ;
	wordN = split(textLow, words, " ") ; outText = "" ; numText = "" ;
	for (idx = 1 ; idx <= wordN ; idx++) {
		tok = words[idx] ;
		if (tok == "") continue ;
		if (tok ~ /^[0-9]+$/) { valueOf = tok + 0 ; tok = "#" ; numText = numText (numText == "" ? "" : ",") valueOf ; }
		else if (tok in numWord) { valueOf = numWord[tok] ; tok = "#" ; numText = numText (numText == "" ? "" : ",") valueOf ; }
		outText = outText (outText == "" ? "" : " ") tok ;
	}
	normText = outText ; normNums = numText ;
	return wordN ;
}

## ---- blocks ----

function blockOpen(kindIn, lineNo, textIn) {
	blkOpen = 1 ; blkKind = kindIn ; blkText = textIn ; blkN = 1 ; blkOff[1] = 1 ; blkLn[1] = lineNo ;
}

function blockAppend(lineNo, textIn,   joiner) {
	joiner = " " ;
	if (blkText ~ /[*][*]$/ && boldClosed(blkText)) joiner = "\001" ;
	blkN++ ; blkOff[blkN] = length(blkText) + 2 ; blkLn[blkN] = lineNo ;
	blkText = blkText joiner textIn ;
}

## Whether the last ** of a text closes a bold run: an even number of ** in all of it.
function boldClosed(textIn,   copyOf, marks) {
	copyOf = textIn ; marks = gsub(/[*][*]/, "", copyOf) ;
	return (marks % 2 == 0) ;
}

## A block is complete: read its sentences.
function blockFlush(   idx, lineNo, lastIdx, wordN) {
	if (!blkOpen) return ;
	blkOpen = 0 ;
	splitSentences(blkText) ;
	for (idx = 1 ; idx <= sentN ; idx++) {
		lineNo = blockLineOf(sentAt[idx]) ;
		readSentence(sentText[idx], lineNo) ;
	}
	introVal = 0 ;
	if (blkKind == "para" && sentN > 0) {
		lastIdx = sentN ;
		if (introduces(sentText[lastIdx], sentN) && firstCount(sentText[lastIdx])) {
			introVal = cntValue ; introWord = cntWord ; introNoun = cntNoun ; introLn = blockLineOf(sentAt[lastIdx]) ;
		}
	}
	blkText = "" ; blkN = 0 ;
}

## Whether a sentence introduces what follows it: it ends in a colon, or it is the one short sentence of its block.
function introduces(sentIn, sentCount,   shown) {
	shown = trimText(sentIn) ; sub(/[*_)]+$/, "", shown) ;
	if (shown ~ /:$/) return 1 ;
	return (sentCount == 1 && split(shown, introWords, " ") <= 10) ;
}

## A sentence of a paragraph or a list item: the statements it makes.
function readSentence(sentIn, lineNo,   plain, wordN, famWord, famLow) {
	plain = sentIn ;
	## "all <count> stages" / "all <count> features": a tally against the headings present.
	if (match(plain, /[Aa]ll [A-Za-z0-9]+ (stages|features)/)) {
		famWord = substr(plain, RSTART, RLENGTH) ;
		split(famWord, famParts, " ") ;
		famLow = tolower(famParts[2]) ;
		if (famLow ~ /^[0-9]+$/) tallyValue = famLow + 0 ; else tallyValue = wordValue(famLow) ;
		if (tallyValue >= 2) { tallyN++ ; tallyLine[tallyN] = lineNo ; tallyVal[tallyN] = tallyValue ; tallyWord[tallyN] = famLow ; tallyFam[tallyN] = famParts[3] ; }
	}
	wordN = normalise(plain) ;
	if (wordN >= 6 && normNums != "") {
		stmtN++ ; stmtNorm[stmtN] = headN SUBSEP normText ; stmtNums[stmtN] = normNums ; stmtLine[stmtN] = lineNo ;
	}
}

## ---- lists and tables ----

function listStart(indentIn, lineNo) {
	listActive = 1 ; listBase = indentIn ; listTop = 0 ; listLn = lineNo ;
	listIntroVal = 0 ;
	if (introVal > 0 && blankRun <= 1) { listIntroVal = introVal ; listIntroWord = introWord ; listIntroNoun = introNoun ; listIntroLn = introLn ; }
	introVal = 0 ;
	delete numLast ; delete itemKind ;
}

function listEnd() {
	if (!listActive) return ;
	if (listIntroVal > 0 && listTop != listIntroVal) {
		emitRow(listIntroLn, "report-count", "states " listIntroWord " " listIntroNoun ", and the list that follows has " listTop " items") ;
	}
	listActive = 0 ; listIntroVal = 0 ; delete numLast ; delete itemKind ;
}

function tableStart(lineNo) {
	tblActive = 1 ; tblN = 0 ; tblSep = 0 ; tblBody = 0 ; tblLn = lineNo ;
	tblIntroVal = 0 ;
	if (introVal > 0 && blankRun <= 1) { tblIntroVal = introVal ; tblIntroWord = introWord ; tblIntroNoun = introNoun ; tblIntroLn = introLn ; }
	introVal = 0 ;
	delete tblCell ; delete tblRowLn ;
}

function tableRow(lineNo, lineText,   cells, cellN, idx, cellText, isSep) {
	cellText = trimText(lineText) ;
	sub(/^[|]/, "", cellText) ; sub(/[|]$/, "", cellText) ;
	cellN = split(cellText, cells, "|") ;
	isSep = 1 ;
	for (idx = 1 ; idx <= cellN ; idx++) { if (trimText(cells[idx]) !~ /^:?-+:?$/) isSep = 0 ; }
	if (isSep && !tblSep && tblN == 1) { tblSep = 1 ; return ; }
	tblN++ ; tblRowLn[tblN] = lineNo ; tblCols[tblN] = cellN ;
	for (idx = 1 ; idx <= cellN ; idx++) tblCell[tblN, idx] = trimText(cells[idx]) ;
	if (tblSep) tblBody++ ;
}

function tableEnd(   rowIdx, colIdx, totalRow, labelText, sumOf, okCol, cellText, totalText, bodyRows) {
	if (!tblActive) return ;
	tblActive = 0 ;
	if (tblIntroVal > 0 && tblSep && tblBody != tblIntroVal) {
		emitRow(tblIntroLn, "report-count", "states " tblIntroWord " " tblIntroNoun ", and the table that follows has " tblBody " rows") ;
	}
	if (!tblSep) return ;
	totalRow = 0 ;
	for (rowIdx = 2 ; rowIdx <= tblN ; rowIdx++) {
		labelText = tolower(plainText(tblCell[rowIdx, 1])) ;
		if (labelText == "total" || labelText == "totals" || labelText == "sum") { totalRow = rowIdx ; break ; }
	}
	if (totalRow < 3) return ;
	for (colIdx = 2 ; colIdx <= tblCols[totalRow] ; colIdx++) {
		totalText = plainText(tblCell[totalRow, colIdx]) ; gsub(/,/, "", totalText) ;
		if (totalText !~ /^-?[0-9]+$/) continue ;
		sumOf = 0 ; okCol = 1 ;
		for (rowIdx = 2 ; rowIdx < totalRow ; rowIdx++) {
			cellText = plainText(tblCell[rowIdx, colIdx]) ; gsub(/,/, "", cellText) ;
			if (cellText !~ /^-?[0-9]+$/) { okCol = 0 ; break ; }
			sumOf += cellText ;
		}
		if (okCol && sumOf != totalText + 0) {
			emitRow(tblRowLn[totalRow], "report-arithmetic", "the Total row says " totalText " in column " colIdx ", and the rows above add to " sumOf) ;
		}
	}
}

## ---- records ----

function emitRow(lineNo, ruleName, rowText) {
	printf "ROW\t%d\t%s\t%s\n", lineNo, ruleName, rowText ;
}

function emitCite(kindName, lineNo, tokenText,   citeKey) {
	citeKey = kindName SUBSEP lineNo SUBSEP tokenText ;
	if (citeKey in citeSeen) return ;
	citeSeen[citeKey] = 1 ;
	printf "%s\t%d\t%s\n", kindName, lineNo, tokenText ;
}

## The citations of one prose line: files, board items, places (in backticks), and rules (**name** (`file:line`)).
function readCitations(lineText, lineNo,   rest, spanEnd, spanText, lastFile, ruleAt, ruleText, nameText, fileText) {
	rest = lineText ;
	while (index(rest, "`") > 0) {
		rest = substr(rest, index(rest, "`") + 1) ;
		spanEnd = index(rest, "`") ;
		if (spanEnd == 0) break ;
		spanText = substr(rest, 1, spanEnd - 1) ;
		rest = substr(rest, spanEnd + 1) ;
		readSpan(trimText(spanText), lineNo) ;
	}
	rest = lineText ; lastFile = "" ;
	while (match(rest, /[*][*][^*]+[*][*] [(]`[^`]+`[)]/)) {
		ruleText = substr(rest, RSTART, RLENGTH) ;
		rest = substr(rest, RSTART + RLENGTH) ;
		nameText = ruleText ; sub(/^[*][*]/, "", nameText) ; sub(/[*][*] [(]`.*$/, "", nameText) ;
		gsub(/`/, "", nameText) ; nameText = trimText(nameText) ; sub(/[.:,;]+$/, "", nameText) ;
		fileText = ruleText ; sub(/^.*[(]`/, "", fileText) ; sub(/`[)]$/, "", fileText) ;
		if (fileText ~ /^:[0-9]/) fileText = lastFile ;
		else { sub(/#.*$/, "", fileText) ; sub(/:[0-9]+(-[0-9]+)?$/, "", fileText) ; lastFile = fileText ; }
		if (length(nameText) >= 3 && fileText != "") printf "RULE\t%d\t%s\t%s\n", lineNo, nameText, fileText ;
	}
}

## One code span: a file, a board item, a place, or nothing that is cited.
function readSpan(spanIn, lineNo,   pathText, placeText) {
	if (spanIn == "") return ;
	if (spanIn ~ /^--get-place-path [A-Za-z0-9][A-Za-z0-9._@-]*/) {
		placeText = spanIn ; sub(/^--get-place-path /, "", placeText) ; sub(/[\/ ].*$/, "", placeText) ;
		if (placeText != "") emitCite("PLACE", lineNo, placeText) ;
		return ;
	}
	pathText = spanIn ; sub(/#[A-Za-z0-9._-]*$/, "", pathText) ; sub(/:[0-9]+(-[0-9]+)?$/, "", pathText) ;
	if (pathText ~ /^(ws-|util[.]workspace-)[A-Za-z0-9._-]+$/) { emitCite("PLACE", lineNo, pathText) ; return ; }
	placeText = pathText ; sub(/[.]md$/, "", placeText) ;
	if (placeText ~ /^(project|task|change|idea|proposal|interview|approval|dispatch|warning)-[0-9]+T[0-9]+Z-[A-Za-z0-9._-]+$/) { emitCite("BOARD", lineNo, placeText) ; return ; }
	if (pathText !~ /^[\/A-Za-z0-9_.@+-][A-Za-z0-9_.\/@+-]*[\/][A-Za-z0-9_.@+-]+[.](md|sh|include|awk|py|json|inf|txt|html|css|js|yaml|yml|xml|xsl|tpl|png|svg|env|conf)$/) return ;
	if (pathText ~ /[.][.][.]/) return ;
	if (pathText ~ /^(input|output|[.]local)[\/]/) return ;
	emitCite("FILE", lineNo, pathText) ;
}

## ---- equations ----

## An equation on a line, `a + b = c` or `c = a + b`, in digits: does it close.
function readEquations(lineText, lineNo,   work, eqText, parts, partN, idx, sumOf, wantOf) {
	work = lineText ;
	while (match(work, /`[^`]*`/)) work = substr(work, 1, RSTART - 1) " " substr(work, RSTART + RLENGTH) ;
	while (match(work, /[0-9]+( ?[+] ?[0-9]+)+ ?= ?[0-9]+/)) {
		eqText = substr(work, RSTART, RLENGTH) ;
		work = substr(work, 1, RSTART - 1) " " substr(work, RSTART + RLENGTH) ;
		partN = split(eqText, parts, /[+=]/) ; sumOf = 0 ;
		for (idx = 1 ; idx < partN ; idx++) sumOf += parts[idx] ;
		wantOf = trimText(parts[partN]) + 0 ;
		if (sumOf != wantOf) emitRow(lineNo, "report-arithmetic", eqText " does not close: the terms add to " sumOf) ;
	}
	while (match(work, /[0-9]+ ?= ?[0-9]+( ?[+] ?[0-9]+)+/)) {
		eqText = substr(work, RSTART, RLENGTH) ;
		work = substr(work, 1, RSTART - 1) " " substr(work, RSTART + RLENGTH) ;
		partN = split(eqText, parts, /[+=]/) ; sumOf = 0 ;
		for (idx = 2 ; idx <= partN ; idx++) sumOf += parts[idx] ;
		wantOf = trimText(parts[1]) + 0 ;
		if (sumOf != wantOf) emitRow(lineNo, "report-arithmetic", eqText " does not close: the terms add to " sumOf) ;
	}
}

## ---- headings ----

function readHeading(levelIn, textIn, lineNo,   parentKey, level, idText, idFull, prefix, majorOf, minorOf, valueOf, afterCh, orderKey) {
	parentKey = "" ;
	for (level = 1 ; level < levelIn ; level++) parentKey = parentKey "/" chain[level] ;
	chain[levelIn] = textIn ;
	for (level = levelIn + 1 ; level <= 6 ; level++) chain[level] = "" ;
	headN++ ; headLevel[headN] = levelIn ; headText[headN] = textIn ; headLn[headN] = lineNo ; headParent[headN] = parentKey ;
	if (((parentKey SUBSEP levelIn SUBSEP textIn) in headFirst) == 0) headFirst[parentKey SUBSEP levelIn SUBSEP textIn] = headN ;
	else { headDup++ ; headDupIdx[headDup] = headN ; headDupOf[headDup] = headFirst[parentKey SUBSEP levelIn SUBSEP textIn] ; }
	## An id at the start of the heading (S5, F5.1): ids of one kind ascend among the headings of one place.
	if (match(textIn, /^[A-Z]+[0-9]+([.][0-9]+)?/)) {
		idFull = substr(textIn, RSTART, RLENGTH) ; idText = idFull ; afterCh = charAt(textIn, RLENGTH + 1) ;
		if (afterCh == "" || afterCh !~ /[A-Za-z0-9]/) {
			match(idText, /^[A-Z]+/) ; prefix = substr(idText, 1, RLENGTH) ;
			sub(/^[A-Z]+/, "", idText) ;
			majorOf = idText ; minorOf = 0 ;
			if (index(idText, ".") > 0) { majorOf = substr(idText, 1, index(idText, ".") - 1) ; minorOf = substr(idText, index(idText, ".") + 1) ; }
			valueOf = (majorOf + 0) * 100000 + (minorOf + 0) ;
			orderKey = prefix SUBSEP levelIn SUBSEP parentKey ;
			if ((orderKey in idLast) && valueOf < idLast[orderKey]) {
				emitRow(lineNo, "report-order", "the heading " idFull " stands after " idLastText[orderKey] ": ids ascend among the headings of one place") ;
			}
			idLast[orderKey] = valueOf ; idLastText[orderKey] = idFull ;
		}
	}
}

## The text of the lines under a heading, up to the next heading of its level or above.
function headingContent(idx,   toLn, nextIdx, lineNo, outText) {
	toLn = lastLine + 1 ;
	for (nextIdx = idx + 1 ; nextIdx <= headN ; nextIdx++) {
		if (headLevel[nextIdx] <= headLevel[idx]) { toLn = headLn[nextIdx] ; break ; }
	}
	outText = "" ;
	for (lineNo = headLn[idx] + 1 ; lineNo < toLn ; lineNo++) outText = outText "\n" allLines[lineNo] ;
	return outText ;
}

## ---- the main pass ----

BEGIN {
	numWord["two"] = 2 ; numWord["three"] = 3 ; numWord["four"] = 4 ; numWord["five"] = 5 ; numWord["six"] = 6 ;
	numWord["seven"] = 7 ; numWord["eight"] = 8 ; numWord["nine"] = 9 ; numWord["ten"] = 10 ; numWord["eleven"] = 11 ;
	numWord["twelve"] = 12 ; numWord["thirteen"] = 13 ; numWord["fourteen"] = 14 ; numWord["fifteen"] = 15 ;
	numWord["sixteen"] = 16 ; numWord["seventeen"] = 17 ; numWord["eighteen"] = 18 ; numWord["nineteen"] = 19 ; numWord["twenty"] = 20 ;
	unitWord["minutes"] = 1 ; unitWord["seconds"] = 1 ; unitWord["hours"] = 1 ; unitWord["days"] = 1 ; unitWord["weeks"] = 1 ;
	unitWord["months"] = 1 ; unitWord["years"] = 1 ; unitWord["bytes"] = 1 ; unitWord["kb"] = 1 ; unitWord["mb"] = 1 ;
	unitWord["percent"] = 1 ; unitWord["times"] = 1 ; unitWord["characters"] = 1 ; unitWord["chars"] = 1 ;
	rateWord["every"] = 1 ; rateWord["each"] = 1 ; rateWord["per"] = 1 ; rateWord["than"] = 1 ; rateWord["within"] = 1 ;
	rateWord["about"] = 1 ; rateWord["around"] = 1 ;
	rateWord["over"] = 1 ; rateWord["across"] = 1 ; rateWord["from"] = 1 ; rateWord["by"] = 1 ; rateWord["among"] = 1 ;
	rateWord["between"] = 1 ; rateWord["of"] = 1 ; rateWord["in"] = 1 ; rateWord["on"] = 1 ; rateWord["at"] = 1 ;
	rateWord["with"] = 1 ; rateWord["to"] = 1 ;
	inFront = 0 ; inFence = 0 ; blkOpen = 0 ; blkN = 0 ; blankRun = 0 ; introVal = 0 ;
	listActive = 0 ; tblActive = 0 ; headN = 0 ; headDup = 0 ; stmtN = 0 ; tallyN = 0 ; lastLine = 0 ;
}

{
	lineText = $0 ; lastLine = NR ; allLines[NR] = lineText ;
	if (NR == 1 && lineText == "---") { inFront = 1 ; next ; }
	if (inFront) { if (lineText == "---") inFront = 0 ; next ; }
	if (lineText ~ /^[ \t]*(```|~~~)/) { inFence = !inFence ; blockFlush() ; blankRun = 0 ; next ; }
	if (inFence) next ;
	gsub(/\t/, "    ", lineText) ;
	if (lineText ~ /^[ ]*$/) {
		blockFlush() ; tableEnd() ; blankRun++ ; next ;
	}
	readCitations(lineText, NR) ;
	if (lineText !~ /^[ ]*[|]/) readEquations(lineText, NR) ;
	if (lineText ~ /^[ ]*(---+|[*][*][*]+|___+)[ ]*$/) { blockFlush() ; listEnd() ; tableEnd() ; introVal = 0 ; blankRun = 0 ; next ; }
	## A table row.
	if (lineText ~ /^[ ]*[|]/) {
		blockFlush() ; listEnd() ;
		if (!tblActive) tableStart(NR) ;
		tableRow(NR, lineText) ;
		blankRun = 0 ; next ;
	}
	tableEnd() ;
	## A heading.
	if (lineText ~ /^#+ /) {
		blockFlush() ; listEnd() ;
		headMarks = lineText ; sub(/ .*$/, "", headMarks) ;
		headBody = lineText ; sub(/^#+ +/, "", headBody) ; sub(/ +#+ *$/, "", headBody) ; headBody = trimText(headBody) ;
		if (length(headMarks) <= 6) {
			readHeading(length(headMarks), headBody, NR) ;
			introVal = 0 ;
			if (introduces(plainText(headBody), 1) && firstCount(plainText(headBody))) { introVal = cntValue ; introWord = cntWord ; introNoun = cntNoun ; introLn = NR ; }
		}
		blankRun = 0 ; next ;
	}
	## A list item.
	if (match(lineText, /^[ ]*([-*+]|[0-9]+[.)])( +|$)/)) {
		itemMark = substr(lineText, RSTART, RLENGTH) ;
		itemIndent = 0 ; while (substr(itemMark, itemIndent + 1, 1) == " ") itemIndent++ ;
		itemBody = substr(lineText, RSTART + RLENGTH) ;
		itemWord = substr(itemMark, itemIndent + 1) ; sub(/ +$/, "", itemWord) ;
		blockFlush() ;
		if (listActive && itemIndent < listBase) listEnd() ;
		if (!listActive) listStart(itemIndent, NR) ;
		if (itemIndent == listBase) listTop++ ;
		## A numbered item declares its place: a number below the one before it, in one list at one depth, is out of order.
		for (depthKey = itemIndent + 1 ; depthKey <= 40 ; depthKey++) { delete numLast[depthKey] ; delete itemKind[depthKey] ; }
		itemKindNow = (itemWord ~ /^[0-9]/) ? "n" : "b" ;
		if ((itemIndent in itemKind) && itemKind[itemIndent] != itemKindNow) delete numLast[itemIndent] ;
		itemKind[itemIndent] = itemKindNow ;
		if (itemKindNow == "n") {
			itemNum = itemWord ; sub(/[.)]$/, "", itemNum) ; itemNum = itemNum + 0 ;
			if ((itemIndent in numLast) && itemNum < numLast[itemIndent]) {
				emitRow(NR, "report-order", "item " itemNum " follows item " numLast[itemIndent] ": a numbered list ascends") ;
			}
			numLast[itemIndent] = itemNum ;
		}
		blockOpen("item", NR, itemBody) ;
		blankRun = 0 ; next ;
	}
	## Text that is no item: a continuation of the item above, or a paragraph.
	lineIndent = 0 ; while (substr(lineText, lineIndent + 1, 1) == " ") lineIndent++ ;
	plainLine = substr(lineText, lineIndent + 1) ;
	if (listActive && (lineIndent > listBase || blankRun == 0)) {
		if (blkOpen) blockAppend(NR, plainLine) ; else blockOpen("cont", NR, plainLine) ;
		blankRun = 0 ; next ;
	}
	if (listActive) { blockFlush() ; listEnd() ; }
	if (blkOpen) blockAppend(NR, plainLine) ;
	else { introVal = 0 ; blockOpen("para", NR, plainLine) ; }
	blankRun = 0 ;
}

END {
	blockFlush() ; listEnd() ; tableEnd() ;
	## A heading twice in one place, with different content.
	for (dupIdx = 1 ; dupIdx <= headDup ; dupIdx++) {
		if (headingContent(headDupIdx[dupIdx]) != headingContent(headDupOf[dupIdx])) {
			emitRow(headLn[headDupIdx[dupIdx]], "report-heading", "the heading " headText[headDupIdx[dupIdx]] " stands twice in one place with different content: first at line " headLn[headDupOf[dupIdx]]) ;
		}
	}
	## "all <count> stages" and "all <count> features" against the headings present.
	for (idx = 1 ; idx <= headN ; idx++) {
		if (headText[idx] ~ /^S[0-9]+([^A-Za-z0-9.]|$)/) stageHeads++ ;
		if (headText[idx] ~ /^F[0-9]+[.][0-9]+([^A-Za-z0-9]|$)/) featureHeads++ ;
	}
	for (idx = 1 ; idx <= tallyN ; idx++) {
		if (tallyFam[idx] == "stages" && stageHeads + 0 > 0 && tallyVal[idx] != stageHeads) emitRow(tallyLine[idx], "report-count", "states " tallyWord[idx] " stages, and the headings present are " stageHeads) ;
		if (tallyFam[idx] == "features" && featureHeads + 0 > 0 && tallyVal[idx] != featureHeads) emitRow(tallyLine[idx], "report-count", "states " tallyWord[idx] " features, and the headings present are " featureHeads) ;
	}
	## A statement a later statement replaces: the same words, other numbers.
	for (idx = 1 ; idx <= stmtN ; idx++) {
		if ((stmtNorm[idx] in stmtLast) && stmtNums[stmtLast[stmtNorm[idx]]] != stmtNums[idx]) {
			emitRow(stmtLine[stmtLast[stmtNorm[idx]]], "report-replaced", "the same statement is made again at line " stmtLine[idx] " with other numbers (" stmtNums[stmtLast[stmtNorm[idx]]] " and " stmtNums[idx] ")") ;
		}
		stmtLast[stmtNorm[idx]] = idx ;
	}
}
