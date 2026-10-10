#!/usr/bin/env awk

# A Markdown document (stdin) -> an HTML fragment (stdout): the document mode
# beside AgentsEmailHtmlBuild.awk, which stays the email mode. Run as
#
#   LC_ALL=C awk -f AgentsMarkdownHtmlDocument.awk < document.md
#
# The output is body content only -- no <html>, <head>, <body> or <title>,
# which the step that publishes it adds -- its top-level blocks joined by
# one newline.
#
# Its own file rather than a mode inside AgentsEmailHtmlBuild.awk, so the
# email output cannot move: the inline rules below are copied from that
# file, not shared with it.
#
# Blocks, after CommonMark, with GFM tables:
#   "#" .. "######" + space   -> <h1> .. <h6>; a closing "#" run is dropped.
#   "```lang" or "~~~"        -> <pre><code class="language-lang">, content
#                                verbatim and escaped, closed by a fence of
#                                the same character at least as long, or by
#                                the end of its container.
#   "> text"                  -> <blockquote>, its content converted as a
#                                document; a lazy paragraph line continues it.
#   "---", "***", "___"       -> <hr>, spaces between allowed. A "---" under a
#                                paragraph is a rule too: no setext headings.
#   "-", "+", "*" + space     -> <ul><li>; "1." or "1)" -> <ol>, with start=
#                                when the first number is not 1. An item holds
#                                every line indented to its content column,
#                                so a deeper list nests; a marker line at
#                                least two columns past its parent marker
#                                nests too, short of that column. A changed
#                                bullet character or delimiter starts a new
#                                list. A blank line between items, or between
#                                blocks of one item, makes the list loose and
#                                keeps <p>; a tight list unwraps them.
#   "| a | b |" over "| :-- | --: |" -> <table>, <thead>, <tbody>, and a
#                                text-align style per aligned column. The
#                                delimiter row needs as many cells as the
#                                header; a body row is padded or cut to that.
#                                "\|" is a literal pipe inside a cell.
#   anything else             -> <p>. A line break inside stays a newline; one
#                                after two spaces or a backslash is <br>.
#
# Inline: everything the email mode (format=markdown) honours -- backslash
# escapes, code spans, "[text](url)" links, bare URLs as links, bare
# addresses as bold blue text with no mailto:, CommonMark emphasis -- plus
# "![alt](src "title")" -> <img>, with src kept as written (attribute
# escaping only) for the publish step to rewrite; an optional "title" on a
# link; "<https://...>" autolinks. A code span is a backtick run closed by a
# run of the same length, as CommonMark has it, and emphasis nests around
# code and links instead of being split by them.
#
# Escaping matches the email mode: "&", "<", ">" and '"' in text, href and
# src alike. No raw HTML passes through: a tag in the source is text.
#
# Not supported: setext headings, indented code blocks, raw HTML, reference
# links, footnotes, front matter, heading ids, and an image or emphasis
# inside a link label, which is taken verbatim as the email mode takes it.

BEGIN {
	ALNUM = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	PUNCT = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
	## A hard line break inside a paragraph, carried as one control byte from
	## the line join to the inline pass, which turns it into "<br>".
	HARDBREAK = "\001"
	docLineCount = 0
}

function htmlEscape(s,   i, c, ln, r) {
	r = ""
	ln = length(s)
	for (i = 1; i <= ln; i++) {
		c = substr(s, i, 1)
		if (c == "&") r = r "&amp;"
		else if (c == "<") r = r "&lt;"
		else if (c == ">") r = r "&gt;"
		else if (c == "\"") r = r "&quot;"
		else r = r c
	}
	return r
}

## A paragraph is inline-parsed whole, so its line breaks count as
## whitespace too, wherever the email mode counts a space or a tab.
function isWsCh(c) {
	return (c == " " || c == "\t" || c == "\n" || c == HARDBREAK)
}

## Same deliberate departure as AgentsSlackBlocksBuild.awk's own isPunctCh:
## ASCII punctuation minus backtick, apostrophe and double quote.
function isPunctCh(c) {
	if (c == "" || c == "`" || c == "'" || c == "\"") return 0
	return (index(PUNCT, c) > 0)
}

function dupCh(ch, cnt,   s, x) {
	s = ""
	for (x = 0; x < cnt; x++) s = s ch
	return s
}

function addTok(type, val, ch, len) {
	nTok++
	tkType[nTok] = type ; tkText[nTok] = val ; tkChar[nTok] = ch
	tkLen[nTok] = len ; tkOrigLen[nTok] = len
	tkOpen[nTok] = 0 ; tkClose[nTok] = 0 ; tkB[nTok] = 0 ; tkI[nTok] = 0
}

## Copied verbatim from AgentsEmailHtmlBuild.awk, which ported it from
## AgentsSlackBlocksBuild.awk: the CommonMark "process emphasis" step.
function processEmphasis(   closer, opener, ok, useLen, t) {
	closer = 1
	while (closer <= nTok) {
		if (tkType[closer] != "delim" || !tkClose[closer] || tkLen[closer] == 0) { closer++ ; continue ; }
		opener = closer - 1
		ok = 0
		while (opener >= 1) {
			if (tkType[opener] == "delim" && tkLen[opener] > 0 && tkOpen[opener] && tkChar[opener] == tkChar[closer]) {
				if ((tkClose[opener] || tkOpen[closer]) \
				    && ((tkOrigLen[opener] + tkOrigLen[closer]) % 3 == 0) \
				    && !(tkOrigLen[opener] % 3 == 0 && tkOrigLen[closer] % 3 == 0)) {
					opener--
					continue
				}
				ok = 1
				break
			}
			opener--
		}
		if (!ok) {
			if (!tkOpen[closer]) {
				tkType[closer] = "text" ; tkText[closer] = dupCh(tkChar[closer], tkLen[closer]) ; tkLen[closer] = 0
			}
			closer++
			continue
		}
		useLen = (tkLen[opener] >= 2 && tkLen[closer] >= 2) ? 2 : 1
		for (t = opener + 1; t < closer; t++) {
			if (useLen == 2) tkB[t] = 1 ; else tkI[t] = 1
		}
		tkLen[opener] -= useLen ; tkLen[closer] -= useLen
		for (t = opener + 1; t < closer; t++) {
			if (tkType[t] == "delim") { tkType[t] = "text" ; tkText[t] = dupCh(tkChar[t], tkLen[t]) ; tkLen[t] = 0 ; }
		}
		if (tkLen[opener] == 0) tkType[opener] = "used"
		if (tkLen[closer] == 0) { tkType[closer] = "used" ; closer++ ; }
	}
	for (t = 1; t <= nTok; t++) {
		if (tkType[t] == "delim") {
			if (tkLen[t] > 0) { tkType[t] = "text" ; tkText[t] = dupCh(tkChar[t], tkLen[t]) ; }
			else tkType[t] = "used"
		}
	}
}

## Opens and closes tags as the style changes from token to token, strong
## always outside em, so a code span or a link inside bold stays inside one
## <strong>. For plain runs of styled text the output is the email mode one.
function emitTokens(   t, res, curB, curI) {
	res = "" ; curB = 0 ; curI = 0
	for (t = 1; t <= nTok; t++) {
		if (tkType[t] == "used") continue
		if (tkB[t] == curB) {
			if (curI && !tkI[t]) res = res "</em>"
			else if (!curI && tkI[t]) res = res "<em>"
		} else {
			res = res (curI ? "</em>" : "") (curB ? "</strong>" : "") (tkB[t] ? "<strong>" : "") (tkI[t] ? "<em>" : "")
		}
		curB = tkB[t] ; curI = tkI[t]
		if (tkType[t] == "text") res = res htmlEscape(tkText[t])
		else if (tkType[t] == "code") res = res "<code>" htmlEscape(tkText[t]) "</code>"
		else res = res tkText[t]
	}
	return res (curI ? "</em>" : "") (curB ? "</strong>" : "")
}

## The email mode bare-URL/bare-address rule, unchanged but for what ends a
## span: any whitespace, line breaks included. Reports the characters
## consumed through lfLen, 0 on no match.
function tryLinkify(line, n, i,   k, j, spanText, closeChar, openChar, nestDepth,
                                   atSign, domainPart, lastDot, domainEnd, domainEndOk) {
	k = i
	while (k <= n && !isWsCh(substr(line, k, 1))) k++
	spanText = substr(line, i, k - i)
	while (length(spanText) > 0 && index(".,:!?'\"", substr(spanText, length(spanText), 1)) > 0) spanText = substr(spanText, 1, length(spanText) - 1)
	closeChar = (length(spanText) > 0) ? substr(spanText, length(spanText), 1) : ""
	if (closeChar == ")" || closeChar == "]") {
		openChar = (closeChar == ")") ? "(" : "["
		nestDepth = 0
		for (j = 1; j < length(spanText); j++) {
			if (substr(spanText, j, 1) == openChar) nestDepth++
			else if (substr(spanText, j, 1) == closeChar) nestDepth--
		}
		if (nestDepth <= 0) spanText = substr(spanText, 1, length(spanText) - 1)
	}
	if (substr(spanText, 1, 7) == "http://" || substr(spanText, 1, 8) == "https://") {
		lfLen = length(spanText)
		return "<a href=\"" htmlEscape(spanText) "\">" htmlEscape(spanText) "</a>"
	}
	atSign = index(spanText, "@")
	if (atSign > 1 && atSign < length(spanText) && substr(spanText, 1, 7) != "mailto:") {
		domainPart = substr(spanText, atSign + 1)
		lastDot = 0
		for (j = length(domainPart); j >= 1; j--) {
			if (substr(domainPart, j, 1) == ".") { lastDot = j ; break ; }
		}
		domainEnd = (lastDot > 0) ? substr(domainPart, lastDot + 1) : ""
		domainEndOk = (domainEnd != "")
		for (j = 1; domainEndOk && j <= length(domainEnd); j++) {
			if (index("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", substr(domainEnd, j, 1)) == 0) domainEndOk = 0
		}
		if (lastDot > 0 && domainEndOk) {
			lfLen = length(spanText)
			return "<b style=\"color:#0000EE\">" htmlEscape(spanText) "</b>"
		}
	}
	lfLen = 0
	return ""
}

## The "(destination "title")" part of a link or an image, from the "(" at
## p: a destination written as <...> or as a run with balanced parentheses
## and no whitespace, then after whitespace an optional title in double
## quotes, single quotes or parentheses, then ")". Reports through ldDest,
## ldTitle and ldEnd (the closing ")"); returns 1 on a match.
function parseLinkDest(s, n, p,   k, start, depth, ch, closeCh, t, sawWs) {
	ldDest = "" ; ldTitle = "" ; ldEnd = 0
	k = p + 1
	while (k <= n && isWsCh(substr(s, k, 1))) k++
	if (substr(s, k, 1) == "<") {
		t = index(substr(s, k + 1), ">")
		if (t == 0) return 0
		ldDest = substr(s, k + 1, t - 1)
		if (index(ldDest, "<") > 0 || index(ldDest, "\n") > 0 || index(ldDest, HARDBREAK) > 0) return 0
		k = k + t + 1
	} else {
		start = k
		depth = 0
		while (k <= n) {
			ch = substr(s, k, 1)
			if (isWsCh(ch)) break
			if (ch == "(") depth++
			else if (ch == ")") { if (depth == 0) break ; depth-- ; }
			k++
		}
		ldDest = substr(s, start, k - start)
	}
	sawWs = 0
	while (k <= n && isWsCh(substr(s, k, 1))) { k++ ; sawWs = 1 ; }
	ch = substr(s, k, 1)
	if (sawWs && (ch == "\"" || ch == "'" || ch == "(")) {
		closeCh = (ch == "(") ? ")" : ch
		t = index(substr(s, k + 1), closeCh)
		if (t == 0) return 0
		ldTitle = substr(s, k + 1, t - 1)
		k = k + t + 1
		while (k <= n && isWsCh(substr(s, k, 1))) k++
	}
	if (substr(s, k, 1) != ")") return 0
	ldEnd = k
	return 1
}

## Same precedence order as the email mode: backslash escape, code span,
## then the constructs it has no counterpart for (autolink, image), the
## "[text](url)" link, bare URL/address, emphasis delimiters.
function parseInline(line,   n, i, j, k, m, c, runLen, closeIdx, spanText, lhtml, tagText,
                             prevCh, nextCh, beforeSp, beforePu, afterSp, afterPu, lf, rf) {
	n = length(line)
	nTok = 0
	split("", tkType) ; split("", tkText) ; split("", tkChar)
	split("", tkLen) ; split("", tkOrigLen) ; split("", tkOpen)
	split("", tkClose) ; split("", tkB) ; split("", tkI)
	i = 1
	while (i <= n) {
		c = substr(line, i, 1)
		if (c == HARDBREAK) {
			addTok("html", "<br>\n", "", 0) ; i++
			continue
		}
		if (c == "\\" && i < n && index(PUNCT, substr(line, i + 1, 1)) > 0) {
			addTok("text", substr(line, i + 1, 1), "", 0) ; i += 2
			continue
		}
		## Content verbatim, a line break in it a space, and one space taken
		## off each end when both ends have one and it is not all spaces.
		if (c == "`") {
			j = i
			while (j <= n && substr(line, j, 1) == "`") j++
			runLen = j - i
			closeIdx = 0
			k = j
			while (k <= n) {
				if (substr(line, k, 1) != "`") { k++ ; continue ; }
				m = k
				while (m <= n && substr(line, m, 1) == "`") m++
				if (m - k == runLen) { closeIdx = k ; break ; }
				k = m
			}
			if (closeIdx == 0) {
				addTok("text", substr(line, i, runLen), "", 0) ; i = j
				continue
			}
			spanText = substr(line, j, closeIdx - j)
			gsub(/\n/, " ", spanText)
			while ((m = index(spanText, HARDBREAK)) > 0) spanText = substr(spanText, 1, m - 1) " " substr(spanText, m + 1)
			if (spanText ~ /^ / && spanText ~ / $/ && spanText !~ /^ *$/) spanText = substr(spanText, 2, length(spanText) - 2)
			addTok("code", spanText, "", 0) ; i = closeIdx + runLen
			continue
		}
		if (c == "<") {
			k = index(substr(line, i + 1), ">")
			spanText = (k > 0) ? substr(line, i + 1, k - 1) : ""
			if ((substr(spanText, 1, 7) == "http://" || substr(spanText, 1, 8) == "https://") \
			    && spanText !~ /[ \t\n<]/ && index(spanText, HARDBREAK) == 0) {
				addTok("html", "<a href=\"" htmlEscape(spanText) "\">" htmlEscape(spanText) "</a>", "", 0) ; i += k + 1
				continue
			}
			addTok("text", c, "", 0) ; i++
			continue
		}
		if (c == "!" && substr(line, i + 1, 1) == "[") {
			k = index(substr(line, i + 2), "]")
			if (k > 0 && substr(line, i + 2 + k, 1) == "(" && parseLinkDest(line, n, i + 2 + k) && ldDest != "") {
				tagText = "<img src=\"" htmlEscape(ldDest) "\" alt=\"" htmlEscape(substr(line, i + 2, k - 1)) "\""
				if (ldTitle != "") tagText = tagText " title=\"" htmlEscape(ldTitle) "\""
				addTok("html", tagText ">", "", 0) ; i = ldEnd + 1
				continue
			}
			addTok("text", c, "", 0) ; i++
			continue
		}
		if (c == "[") {
			k = index(substr(line, i + 1), "]")
			if (k > 1 && substr(line, i + 1 + k, 1) == "(" && parseLinkDest(line, n, i + 1 + k) && ldDest != "") {
				tagText = "<a href=\"" htmlEscape(ldDest) "\""
				if (ldTitle != "") tagText = tagText " title=\"" htmlEscape(ldTitle) "\""
				addTok("html", tagText ">" htmlEscape(substr(line, i + 1, k - 1)) "</a>", "", 0) ; i = ldEnd + 1
				continue
			}
			addTok("text", c, "", 0) ; i++
			continue
		}
		if (i == 1 || index(ALNUM, substr(line, i - 1, 1)) == 0) {
			lhtml = tryLinkify(line, n, i)
			if (lfLen > 0) { addTok("html", lhtml, "", 0) ; i += lfLen ; continue ; }
		}
		if (c == "*" || c == "_") {
			j = i
			while (j <= n && substr(line, j, 1) == c) j++
			runLen = j - i
			prevCh = (i == 1) ? "" : substr(line, i - 1, 1)
			nextCh = (j > n) ? "" : substr(line, j, 1)
			beforeSp = (prevCh == "" || isWsCh(prevCh))
			afterSp  = (nextCh == "" || isWsCh(nextCh))
			beforePu = isPunctCh(prevCh)
			afterPu  = isPunctCh(nextCh)
			lf = (!afterSp && (!afterPu || (beforeSp || beforePu)))
			rf = (!beforeSp && (!beforePu || (afterSp || afterPu)))
			addTok("delim", "", c, runLen)
			if (c == "*") {
				tkOpen[nTok] = lf ; tkClose[nTok] = rf
			} else {
				tkOpen[nTok]  = (lf && (!rf || beforePu))
				tkClose[nTok] = (rf && (!lf || afterPu))
			}
			i = j
			continue
		}
		addTok("text", c, "", 0)
		i++
	}
	processEmphasis()
	return emitTokens()
}

function isBlank(s) {
	return (s ~ /^[ \t]*$/)
}

## Columns of leading whitespace, a tab advancing to the next multiple of 4.
function indentOf(s,   i, c, col) {
	col = 0
	for (i = 1; i <= length(s); i++) {
		c = substr(s, i, 1)
		if (c == " ") col++
		else if (c == "\t") col = col + 4 - (col % 4)
		else break
	}
	return col
}

## s without its first k columns of leading whitespace; a tab only partly
## taken leaves its remaining columns behind as spaces.
function dropCols(s, k,   i, c, col, w) {
	col = 0
	for (i = 1; i <= length(s) && col < k; i++) {
		c = substr(s, i, 1)
		if (c == " ") col++
		else if (c == "\t") {
			w = 4 - (col % 4)
			if (col + w > k) return substr("    ", 1, col + w - k) substr(s, i + 1)
			col += w
		}
		else break
	}
	return substr(s, i)
}

## An ATX heading on rest (de-indented): its level 1-6, or 0. The text goes
## to atxText, trimmed, with an optional closing "#" run dropped.
function atxLevel(rest,   lvl, t) {
	if (!match(rest, /^#+/)) return 0
	lvl = RLENGTH
	if (lvl > 6) return 0
	t = substr(rest, lvl + 1)
	if (t != "" && substr(t, 1, 1) != " " && substr(t, 1, 1) != "\t") return 0
	sub(/^[ \t]+/, "", t)
	sub(/[ \t]+$/, "", t)
	if (t ~ /^#+$/) t = ""
	else if (match(t, /[ \t]+#+$/)) t = substr(t, 1, RSTART - 1)
	atxText = t
	return lvl
}

function isThematicBreak(rest,   t) {
	t = rest
	gsub(/[ \t]/, "", t)
	return (length(t) >= 3 && (t ~ /^-+$/ || t ~ /^\*+$/ || t ~ /^_+$/))
}

## An opening fence on rest: three or more backticks or tildes, then an
## optional info string, which may not hold a backtick after a backtick
## fence. Sets foChar, foLen and foLang (the info string first word).
function fenceOpen(rest,   info) {
	foChar = substr(rest, 1, 1)
	if (foChar != "`" && foChar != "~") return 0
	if (foChar == "`") match(rest, /^`+/) ; else match(rest, /^~+/)
	foLen = RLENGTH
	if (foLen < 3) return 0
	info = substr(rest, foLen + 1)
	if (foChar == "`" && index(info, "`") > 0) return 0
	sub(/^[ \t]+/, "", info)
	sub(/[ \t].*$/, "", info)
	foLang = info
	return 1
}

function isFenceClose(rest, ch, len) {
	if (substr(rest, 1, 1) != ch) return 0
	if (ch == "`") match(rest, /^`+/) ; else match(rest, /^~+/)
	return (RLENGTH >= len && substr(rest, RLENGTH + 1) ~ /^[ \t]*$/)
}

## A list item marker opening rest: "-", "+" or "*", or up to nine digits
## and "." or ")", then whitespace or the end of the line. Sets lmKind (the
## bullet character, or "o" and the delimiter), lmLen and lmNum.
function listMarker(rest,   c) {
	c = substr(rest, 1, 1)
	if (c == "-" || c == "+" || c == "*") {
		lmKind = c ; lmLen = 1 ; lmNum = 0
	} else if (match(rest, /^[0-9]+[.)]/) && RLENGTH <= 10) {
		lmKind = "o" substr(rest, RLENGTH, 1) ; lmLen = RLENGTH ; lmNum = substr(rest, 1, RLENGTH - 1) + 0
	} else {
		return 0
	}
	c = substr(rest, lmLen + 1, 1)
	return (c == "" || c == " " || c == "\t")
}

## Whether line starts a block that ends a paragraph or a table: a heading,
## a fence, a block quote, a thematic break, or a list item with content
## (an ordered one only when it starts at 1).
function startsBlock(line,   ind, rest) {
	ind = indentOf(line)
	if (ind > 3) return 0
	rest = dropCols(line, ind)
	if (atxLevel(rest) || fenceOpen(rest) || substr(rest, 1, 1) == ">" || isThematicBreak(rest)) return 1
	return (listMarker(rest) && substr(rest, lmLen + 1) !~ /^[ \t]*$/ && (lmKind !~ /^o/ || lmNum == 1))
}

function interruptsPara(lines, n, j) {
	return (startsBlock(lines[j]) || isTableStart(lines, n, j))
}

## Splits one table row into rowCell[1..rowCellCount], ported from
## AgentsSlackBlocksBuild.awk: outer pipes dropped, cells trimmed, and "\|"
## taken here as a literal pipe, every other escape left for parseInline.
function splitRowCells(rowText,   charPos, rowLen, curChar, cellText, cellIndex) {
	rowCellCount = 0
	split("", rowCell)
	sub(/^[ \t]+/, "", rowText)
	sub(/[ \t]+$/, "", rowText)
	if (substr(rowText, 1, 1) == "|") rowText = substr(rowText, 2)
	cellText = ""
	rowLen = length(rowText)
	for (charPos = 1; charPos <= rowLen; charPos++) {
		curChar = substr(rowText, charPos, 1)
		if (curChar == "\\" && charPos < rowLen) {
			cellText = cellText ((substr(rowText, charPos + 1, 1) == "|") ? "|" : curChar substr(rowText, charPos + 1, 1))
			charPos++
			continue
		}
		if (curChar == "|") { rowCell[++rowCellCount] = cellText ; cellText = "" ; continue ; }
		cellText = cellText curChar
	}
	rowCell[++rowCellCount] = cellText
	if (rowCellCount > 1 && rowCell[rowCellCount] == "") rowCellCount--
	for (cellIndex = 1; cellIndex <= rowCellCount; cellIndex++) {
		sub(/^[ \t]+/, "", rowCell[cellIndex])
		sub(/[ \t]+$/, "", rowCell[cellIndex])
	}
}

## GFM: a row holding a "|", over a delimiter row holding one too, whose
## every cell is dashes with an optional ":" at either end, and whose cell
## count is the header row count.
function isTableStart(lines, n, j,   headCount, c) {
	if (j >= n || index(lines[j], "|") == 0 || index(lines[j + 1], "|") == 0) return 0
	if (indentOf(lines[j]) > 3 || indentOf(lines[j + 1]) > 3) return 0
	splitRowCells(lines[j])
	headCount = rowCellCount
	splitRowCells(lines[j + 1])
	if (rowCellCount != headCount) return 0
	for (c = 1; c <= rowCellCount; c++) {
		if (rowCell[c] !~ /^:?-+:?$/) return 0
	}
	return 1
}

function tableRow(rowText, tag, colCount, align,   c, html) {
	splitRowCells(rowText)
	html = "<tr>"
	for (c = 1; c <= colCount; c++) html = html "<" tag align[c] ">" ((c <= rowCellCount) ? parseInline(rowCell[c]) : "") "</" tag ">"
	return html "</tr>"
}

## The table at lines[start]; sets rtEnd to the first line after it.
function renderTable(lines, n, start,   align, colCount, c, j, html) {
	split("", align)
	splitRowCells(lines[start + 1])
	colCount = rowCellCount
	for (c = 1; c <= colCount; c++) {
		if (rowCell[c] ~ /^:-+:$/) align[c] = " style=\"text-align:center\""
		else if (rowCell[c] ~ /^:/) align[c] = " style=\"text-align:left\""
		else if (rowCell[c] ~ /:$/) align[c] = " style=\"text-align:right\""
		else align[c] = ""
	}
	html = "<table>\n<thead>\n" tableRow(lines[start], "th", colCount, align) "\n</thead>"
	j = start + 2
	if (j <= n && !isBlank(lines[j]) && !startsBlock(lines[j])) {
		html = html "\n<tbody>"
		while (j <= n && !isBlank(lines[j]) && !startsBlock(lines[j])) {
			html = html "\n" tableRow(lines[j], "td", colCount, align)
			j++
		}
		html = html "\n</tbody>"
	}
	rtEnd = j
	return html "\n</table>"
}

## The fenced block at lines[start]; sets rfEnd to the first line after it.
## Content lines lose up to the opening fence indentation, nothing more.
function renderFence(lines, n, start,   ind, ch, len, lang, j, body, cnt, line, lind) {
	ind = indentOf(lines[start])
	fenceOpen(dropCols(lines[start], ind))
	ch = foChar ; len = foLen ; lang = foLang
	body = "" ; cnt = 0
	for (j = start + 1; j <= n; j++) {
		line = lines[j]
		lind = indentOf(line)
		if (lind <= 3 && isFenceClose(dropCols(line, lind), ch, len)) { j++ ; break ; }
		body = body (cnt ? "\n" : "") htmlEscape(dropCols(line, (lind < ind) ? lind : ind))
		cnt++
	}
	rfEnd = j
	return "<pre><code" ((lang != "") ? " class=\"language-" htmlEscape(lang) "\"" : "") ">" body "</code></pre>"
}

## The block quote at lines[start]: its lines with the ">" and one space
## taken off, plus lazy paragraph lines, converted as a document of their
## own. Sets rqEnd to the first line after it.
function renderQuote(lines, n, start,   inner, innerCount, lastContent, j, line, ind, rest, blk, kinds, cnt) {
	split("", inner)
	innerCount = 0
	lastContent = 0
	for (j = start; j <= n; j++) {
		line = lines[j]
		ind = indentOf(line)
		rest = dropCols(line, ind)
		if (ind <= 3 && substr(rest, 1, 1) == ">") {
			rest = substr(rest, 2)
			if (substr(rest, 1, 1) == " ") rest = substr(rest, 2)
			else if (substr(rest, 1, 1) == "\t") rest = dropCols(rest, 1)
			inner[++innerCount] = rest
			lastContent = !isBlank(rest)
			continue
		}
		if (lastContent && !isBlank(line) && !interruptsPara(lines, n, j)) {
			inner[++innerCount] = line
			continue
		}
		break
	}
	split("", blk) ; split("", kinds)
	cnt = renderBlocks(inner, innerCount, blk, kinds)
	## Set after the recursive call, which overwrites it.
	rqEnd = j
	return "<blockquote>\n" ((cnt > 0) ? joinBlocks(blk, cnt) "\n" : "") "</blockquote>"
}

## The list at lines[start]: items while the marker kind holds, each item
## gathered de-indented and converted as a document of its own. Sets rlEnd
## to the line after its last non-blank line, so a blank line that follows
## the list is still seen by the container, as CommonMark looseness needs.
function renderList(lines, n, start,   listKind, startNum, buf, bufCount, itemFirst, itemLast, itemCount,
                                        markerInd, contentCol, lastLine, line, ind, rest, after, pad, sawBlank,
                                        loose, tight, j, k, b, part, partCount, blk, kinds, cnt, ib, ik, ibCount, html) {
	split("", buf) ; split("", itemFirst) ; split("", itemLast)
	split("", ib) ; split("", ik) ; split("", ibCount)
	bufCount = 0 ; itemCount = 0 ; loose = 0
	j = start
	while (j <= n) {
		line = lines[j]
		markerInd = indentOf(line)
		rest = dropCols(line, markerInd)
		listMarker(rest)
		if (itemCount == 0) { listKind = lmKind ; startNum = lmNum ; }
		itemCount++
		itemFirst[itemCount] = bufCount + 1
		after = substr(rest, lmLen + 1)
		if (after ~ /^[ \t]*$/) {
			contentCol = markerInd + lmLen + 1
		} else {
			pad = indentOf(after)
			if (pad > 4) pad = 1
			contentCol = markerInd + lmLen + pad
			buf[++bufCount] = dropCols(after, pad)
		}
		lastLine = j
		j++
		sawBlank = 0
		while (j <= n) {
			line = lines[j]
			if (isBlank(line)) {
				buf[++bufCount] = "" ; sawBlank = 1 ; j++
				continue
			}
			ind = indentOf(line)
			rest = dropCols(line, ind)
			if (ind >= contentCol) {
				buf[++bufCount] = dropCols(line, contentCol) ; sawBlank = 0 ; lastLine = j ; j++
				continue
			}
			## Nested by indentation alone: a marker two or more columns past
			## this item marker belongs to the item, short of its content column.
			if (ind >= markerInd + 2 && listMarker(rest) && !isThematicBreak(rest)) {
				buf[++bufCount] = rest ; sawBlank = 0 ; lastLine = j ; j++
				continue
			}
			## A lazy paragraph line, straight after item content.
			if (!sawBlank && bufCount >= itemFirst[itemCount] && !interruptsPara(lines, n, j) && !(ind <= 3 && listMarker(rest))) {
				buf[++bufCount] = rest ; lastLine = j ; j++
				continue
			}
			break
		}
		while (bufCount >= itemFirst[itemCount] && isBlank(buf[bufCount])) bufCount--
		itemLast[itemCount] = bufCount
		if (j > n) break
		line = lines[j]
		ind = indentOf(line)
		rest = dropCols(line, ind)
		if (ind > 3 || isThematicBreak(rest) || !listMarker(rest) || lmKind != listKind) break
		if (sawBlank) loose = 1
	}
	for (k = 1; k <= itemCount; k++) {
		split("", part)
		partCount = 0
		for (b = itemFirst[k]; b <= itemLast[k]; b++) part[++partCount] = buf[b]
		split("", blk) ; split("", kinds)
		cnt = renderBlocks(part, partCount, blk, kinds)
		if (rbLoose) loose = 1
		ibCount[k] = cnt
		for (b = 1; b <= cnt; b++) { ib[k, b] = blk[b] ; ik[k, b] = kinds[b] ; }
	}
	tight = !loose
	if (listKind ~ /^o/) html = "<ol" ((startNum != 1) ? " start=\"" startNum "\"" : "") ">"
	else html = "<ul>"
	for (k = 1; k <= itemCount; k++) {
		html = html "\n<li>"
		for (b = 1; b <= ibCount[k]; b++) {
			if (tight && ik[k, b] == "p") html = html ((b > 1) ? "\n" : "") substr(ib[k, b], 4, length(ib[k, b]) - 7)
			else html = html "\n" ib[k, b]
		}
		if (ibCount[k] > 0 && !(tight && ik[k, ibCount[k]] == "p")) html = html "\n"
		html = html "</li>"
	}
	## Set last: the recursive renderBlocks calls above overwrite it.
	rlEnd = lastLine + 1
	return html "\n" ((listKind ~ /^o/) ? "</ol>" : "</ul>")
}

## A paragraph: its lines joined by a newline, or by a hard break where a
## line ends in two or more spaces or in a backslash, then parsed inline.
function renderParaText(para, count,   k, text, line) {
	text = ""
	for (k = 1; k <= count; k++) {
		line = para[k]
		if (k < count && line ~ /  +$/) {
			sub(/[ \t]+$/, "", line)
			text = text line HARDBREAK
			continue
		}
		if (k < count && line ~ /\\$/) {
			text = text substr(line, 1, length(line) - 1) HARDBREAK
			continue
		}
		sub(/[ \t]+$/, "", line)
		text = text line ((k < count) ? "\n" : "")
	}
	return parseInline(text)
}

function joinBlocks(blk, cnt,   b, html) {
	html = ""
	for (b = 1; b <= cnt; b++) html = html ((b > 1) ? "\n" : "") blk[b]
	return html
}

## Converts lines[1..n] into blocks blk[1..count], kinds[b] "p" for a
## paragraph (which a tight list item unwraps) and "b" for anything else.
## Returns the count, and sets rbLoose when a blank line sat between two of
## these blocks, which is what makes a list item loose.
function renderBlocks(lines, n, blk, kinds,   cnt, gap, loose, i, line, ind, rest, lvl, para, paraCount) {
	cnt = 0 ; gap = 0 ; loose = 0
	i = 1
	while (i <= n) {
		line = lines[i]
		if (isBlank(line)) {
			if (cnt > 0) gap = 1
			i++
			continue
		}
		if (gap) { loose = 1 ; gap = 0 ; }
		ind = indentOf(line)
		rest = dropCols(line, ind)
		if (ind <= 3) {
			if (fenceOpen(rest)) {
				blk[++cnt] = renderFence(lines, n, i) ; kinds[cnt] = "b" ; i = rfEnd
				continue
			}
			lvl = atxLevel(rest)
			if (lvl > 0) {
				blk[++cnt] = "<h" lvl ">" parseInline(atxText) "</h" lvl ">" ; kinds[cnt] = "b" ; i++
				continue
			}
			if (isThematicBreak(rest)) {
				blk[++cnt] = "<hr>" ; kinds[cnt] = "b" ; i++
				continue
			}
			if (substr(rest, 1, 1) == ">") {
				blk[++cnt] = renderQuote(lines, n, i) ; kinds[cnt] = "b" ; i = rqEnd
				continue
			}
			if (listMarker(rest)) {
				blk[++cnt] = renderList(lines, n, i) ; kinds[cnt] = "b" ; i = rlEnd
				continue
			}
			if (isTableStart(lines, n, i)) {
				blk[++cnt] = renderTable(lines, n, i) ; kinds[cnt] = "b" ; i = rtEnd
				continue
			}
		}
		split("", para)
		paraCount = 0
		para[++paraCount] = rest
		for (i++; i <= n && !isBlank(lines[i]) && !interruptsPara(lines, n, i); i++) para[++paraCount] = dropCols(lines[i], indentOf(lines[i]))
		blk[++cnt] = "<p>" renderParaText(para, paraCount) "</p>" ; kinds[cnt] = "p"
	}
	rbLoose = loose
	return cnt
}

{
	docLines[++docLineCount] = $0
}

END {
	split("", topBlk) ; split("", topKinds)
	topCount = renderBlocks(docLines, docLineCount, topBlk, topKinds)
	print joinBlocks(topBlk, topCount)
}
