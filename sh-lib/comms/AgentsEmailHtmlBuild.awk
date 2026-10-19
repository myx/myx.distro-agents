#!/usr/bin/env awk

# Agent-written text (stdin) -> an HTML fragment (stdout), for
# AgentsTools.MemberCommsEmail.include's --member-comms-email-send, which
# splices this output into the text/html part of a multipart/alternative
# message sent beside the unmodified plain-text part. Invoked with
# -v format=markdown|text, matching --member-comms-email-send's own
# --format flag.
#
# format=text: every line is HTML-escaped, and a bare "http://"/"https://"
#   URL becomes a real <a> link, while a bare "local@domain" address becomes
#   bold blue text instead, with no anchor -- same detection, same
#   trailing-punctuation/lone-bracket stripping, same
#   url-wins-over-address-on-"https://user@host/path" rule as
#   AgentsSlackBlocksBuild.awk's own bare-URL/bare-address branch (that
#   file's lines ~395-440 are the reference this mirrors). No code spans, no
#   fences, no emphasis, no "[text](url)" links -- plain text has none of
#   those constructs.
#
# format=markdown: the same bare-URL/bare-address rule, PLUS the cheap
#   CommonMark-ish subset AgentsSlackBlocksBuild.awk already honours:
#   "`text`" code spans (verbatim, never re-scanned), "[text](url)" links,
#   a "```" fenced block (verbatim, toggled on/off, flushed as one <pre>),
#   and "*x*"/"_x_" italic, "**x**"/"__x__" bold emphasis (CommonMark
#   delimiter runs and flanking rules, ported from that file's
#   parseInlineStyles()/processEmphasis()). No tables, no headers, no
#   lists -- deliberately not offered here. Unlike Slack's flat rich_text,
#   HTML nests naturally, so bold+italic together becomes a real nested
#   "<strong><em>...</em></strong>" rather than Slack's flattened combined
#   style set.
#
# A blank line ends the current paragraph/fence run, same "run" concept
# AgentsSlackBlocksBuild.awk uses; consecutive non-blank lines in one
# paragraph join with "<br>\n" inside one "<p>...</p>", and a fenced block
# becomes one "<pre>...escaped verbatim...</pre>".
#
# HTML-escaping covers exactly "&", "<", ">" and '"', in text and in href
# values alike -- Help.DistroAgentsTools.help.md's --member-comms-email-send
# section and MAGIC.md's own heading for this file state the full rule.

BEGIN {
	if (format == "") format = "markdown"
	ALNUM = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	inFence = 0
	fenceLineCount = 0
	paraLineCount = 0
	out = ""
	blockCount = 0
}

function htmlEscapeLine(s,   i, c, ln, r) {
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

function isSpaceCh(c) {
	return (c == " " || c == "\t")
}

## Same deliberate departure as AgentsSlackBlocksBuild.awk's own isPunctCh:
## ASCII punctuation minus backtick, apostrophe and double quote, so a
## delimiter beside one of those three does not gain a flanking boundary it
## would have under plain CommonMark.
function isPunctCh(c) {
	if (c == "" || c == "`" || c == "'" || c == "\"") return 0
	return (index("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~", c) > 0)
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

## HTML nests naturally, so bold+italic together is a real nested
## "<strong><em>" rather than Slack rich_text's flattened combined style.
function wrapStyle(text, b, i) {
	if (text == "") return ""
	if (b && i) return "<strong><em>" htmlEscapeLine(text) "</em></strong>"
	if (b) return "<strong>" htmlEscapeLine(text) "</strong>"
	if (i) return "<em>" htmlEscapeLine(text) "</em>"
	return htmlEscapeLine(text)
}

## Ported verbatim from AgentsSlackBlocksBuild.awk's own processEmphasis():
## the CommonMark "process emphasis" step over the delimiter list built by
## the tokenizer below -- same walk-to-closer/walk-back-to-opener matching,
## same multiple-of-three rule. Output-format-agnostic: it only touches
## tkType/tkLen/tkOpen/tkClose/tkOrigLen/tkB/tkI/tkChar/tkText.
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

function emitTokens(   t, res, curText, curB, curI) {
	res = "" ; curText = "" ; curB = 0 ; curI = 0
	for (t = 1; t <= nTok; t++) {
		if (tkType[t] == "used") continue
		if (tkType[t] == "text") {
			if (curText != "" && (tkB[t] != curB || tkI[t] != curI)) {
				res = res wrapStyle(curText, curB, curI) ; curText = ""
			}
			curB = tkB[t] ; curI = tkI[t] ; curText = curText tkText[t]
			continue
		}
		if (curText != "") { res = res wrapStyle(curText, curB, curI) ; curText = "" ; }
		if (tkType[t] == "code") res = res "<code>" htmlEscapeLine(tkText[t]) "</code>"
		else if (tkType[t] == "html") res = res tkText[t]
	}
	if (curText != "") res = res wrapStyle(curText, curB, curI)
	return res
}

## The bare-URL/"bare-address" rule, ported from AgentsSlackBlocksBuild.awk's
## parseInlineStyles() (its own lines ~395-440): scanned from position i to
## the next space/tab, trimmed of trailing ".,:!?'\"" and of a trailing
## closing bracket with no unmatched opener earlier in the span, then
## classified -- the URL check first, so "https://user@host/path" is
## claimed whole. An already-"mailto:"-prefixed span is left alone. Reports
## through the globals lfLen (characters consumed, 0 on no match) and
## returns the ready-to-splice HTML -- an <a> element for a URL, or a bold
## blue <b> element with no href for an address, text escaped either way --
## or "" on no match. Called only at a word boundary (i==1 or the previous
## character is not alphanumeric), same as the Slack branch.
function tryLinkify(line, n, i,   k, j, spanText, closeChar, openChar, nestDepth,
                                   atSign, domainPart, lastDot, domainEnd, domainEndOk) {
	k = i
	while (k <= n && !isSpaceCh(substr(line, k, 1))) k++
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
		return "<a href=\"" htmlEscapeLine(spanText) "\">" htmlEscapeLine(spanText) "</a>"
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
			return "<b style=\"color:#0000EE\">" htmlEscapeLine(spanText) "</b>"
		}
	}
	lfLen = 0
	return ""
}

## format=text: escape plus the bare-URL/bare-address rule only -- no code
## spans, no fences, no emphasis, no markdown links. Plain text has none of
## those constructs, so none are looked for.
function parseInlineText(line,   n, i, lhtml, res) {
	n = length(line)
	res = ""
	i = 1
	while (i <= n) {
		if (i == 1 || index(ALNUM, substr(line, i - 1, 1)) == 0) {
			lhtml = tryLinkify(line, n, i)
			if (lfLen > 0) { res = res lhtml ; i += lfLen ; continue ; }
		}
		res = res htmlEscapeLine(substr(line, i, 1))
		i++
	}
	return res
}

## format=markdown: same precedence order as AgentsSlackBlocksBuild.awk's
## parseInlineStyles() (minus the Slack-only "@mention" branch, which has no
## counterpart in an email) -- backslash escape, code span, "[text](url)"
## link, bare URL/address, then emphasis delimiters.
function parseInlineMarkdown(line,   n, i, j, k, c, closeIdx, spanText, runLen, lhtml,
                                     prevCh, nextCh, beforeSp, beforePu, afterSp, afterPu, lf, rf,
                                     labelEnd, urlEnd, parenDepth, linkLabel, linkTarget) {
	n = length(line)
	nTok = 0
	split("", tkType) ; split("", tkText) ; split("", tkChar)
	split("", tkLen) ; split("", tkOrigLen) ; split("", tkOpen)
	split("", tkClose) ; split("", tkB) ; split("", tkI)
	i = 1
	while (i <= n) {
		c = substr(line, i, 1)
		if (c == "\\" && i < n && index("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~", substr(line, i + 1, 1)) > 0) {
			addTok("text", substr(line, i + 1, 1), "", 0) ; i += 2
			continue
		}
		if (c == "`") {
			closeIdx = 0
			k = i + 1
			while (k <= n) { if (substr(line, k, 1) == "`") { closeIdx = k ; break } ; k++ ; }
			spanText = (closeIdx > 0) ? substr(line, i + 1, closeIdx - i - 1) : ""
			if (spanText != "") { addTok("code", spanText, "", 0) ; i = closeIdx + 1 ; continue ; }
			addTok("text", c, "", 0) ; i++
			continue
		}
		if (c == "[") {
			labelEnd = 0
			k = i + 1
			while (k <= n) { if (substr(line, k, 1) == "]") { labelEnd = k ; break ; } ; k++ ; }
			urlEnd = 0
			if (labelEnd > 0 && substr(line, labelEnd + 1, 1) == "(") {
				parenDepth = 1
				k = labelEnd + 2
				while (k <= n) {
					if (substr(line, k, 1) == "(") parenDepth++
					else if (substr(line, k, 1) == ")") { parenDepth-- ; if (parenDepth == 0) { urlEnd = k ; break ; } ; }
					k++
				}
			}
			linkLabel = (urlEnd > 0) ? substr(line, i + 1, labelEnd - i - 1) : ""
			linkTarget = (urlEnd > 0) ? substr(line, labelEnd + 2, urlEnd - labelEnd - 2) : ""
			if (linkLabel != "" && linkTarget != "" && linkTarget !~ /[ \t]/) {
				addTok("html", "<a href=\"" htmlEscapeLine(linkTarget) "\">" htmlEscapeLine(linkLabel) "</a>", "", 0)
				i = urlEnd + 1
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
			beforeSp = (prevCh == "" || isSpaceCh(prevCh))
			afterSp  = (nextCh == "" || isSpaceCh(nextCh))
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

function appendBlock(html) {
	if (blockCount > 0) out = out "\n"
	out = out html
	blockCount++
}

function flushPara(    i, html) {
	if (paraLineCount == 0) return
	html = ""
	for (i = 1; i <= paraLineCount; i++) {
		if (i > 1) html = html "<br>\n"
		html = html ( (format == "markdown") ? parseInlineMarkdown(paraLines[i]) : parseInlineText(paraLines[i]) )
		delete paraLines[i]
	}
	paraLineCount = 0
	appendBlock("<p>" html "</p>")
}

## Verbatim (HTML-escaped only, never re-parsed) -- same "content taken as
## written" treatment the inline "`code`" span gets, and the same one
## AgentsSlackBlocksBuild.awk's own rich_text_preformatted block gets.
function flushFence(    i, html) {
	if (fenceLineCount == 0) return
	html = ""
	for (i = 1; i <= fenceLineCount; i++) {
		if (i > 1) html = html "\n"
		html = html htmlEscapeLine(fenceLines[i])
		delete fenceLines[i]
	}
	fenceLineCount = 0
	appendBlock("<pre>" html "</pre>")
}

{
	line = $0

	## Fence toggling is a markdown-only construct -- in format=text a
	## "```" line is three ordinary backtick characters.
	if (format == "markdown" && substr(line, 1, 3) == "```") {
		if (inFence) { flushFence(); inFence = 0; }
		else { flushPara(); inFence = 1; fenceLineCount = 0; }
		next
	}

	if (inFence) {
		fenceLines[++fenceLineCount] = line
		next
	}

	if (line == "") {
		flushPara()
		next
	}

	paraLines[++paraLineCount] = line
}

END {
	if (inFence) { flushFence(); inFence = 0; }
	flushPara()
	print out
}
