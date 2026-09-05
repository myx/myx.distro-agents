#!/usr/bin/env awk

# Markdown-ish plain text (stdin) -> Slack Block Kit JSON array (stdout), for
# DistroAgentsTools.fn.sh's --member-comms-slack-send-message --format markdown
# path (myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh /
# sh-lib/AgentsTools.Member.include). Deliberately a small, restricted
# markdown-ish syntax, not a general markdown parser -- see
# Help.DistroAgentsTools.help.md's --member-comms-slack-send-message section for
# the exact rules and a worked example.
#
# Recognized per line:
#   "# text"      -> a `header` block (plain_text)
#   "## text"     -> a bold paragraph line (Slack's `header` block has no H2/
#                    H3 distinction, so a deeper heading level renders bold
#                    instead of a raw, unconverted "##" prefix); "###", etc.
#                    all collapse to the same bold treatment as "##"
#   "- text"      -> a top-level (indent 0) bullet list item
#   "  - text"    -> an indent-1 nested bullet item (exactly 2 leading spaces)
#   "    - text"  -> an indent-2 nested bullet item (exactly 4 leading spaces)
#   "```"         -> toggles a fenced code block on/off (GitHub-style triple-
#                    backtick fence). The opening fence may carry a language
#                    tag right after the backticks (e.g. "```bash") -- it's
#                    discarded, since Slack's `rich_text_preformatted` has no
#                    language concept. Every line between an opening and
#                    closing fence is captured VERBATIM (no inline-style
#                    parsing -- same "content taken verbatim, not re-scanned
#                    for bold/italic" treatment the inline "`text`" code span
#                    already gets below) and flushed as one real Slack
#                    `rich_text_preformatted` block on close.
#   "| a | b |"   -> a pipe-table row, but only once a "|---|---|" delimiter
#                    line arrives under it; without one the pipe lines stay
#                    plain paragraph text. Emits one Slack `table` block --
#                    see Help.DistroAgentsTools.help.md for the cell grammar
#                    and MAGIC.md for why the delimiter row is the recogniser.
#   ""            -> ends the current paragraph/list run
#   anything else -> a plain-paragraph line
# Deeper indents (6+ leading spaces) aren't a supported bullet shape -- they
# fall through and are treated as plain paragraph text, same as any other
# non-blank, non-bullet, non-header line.
#
# Recognized inline, within a paragraph or bullet-item line's own text (never
# inside a "# " header line -- Slack's `header` block is `plain_text`, which
# has no rich-text/style support at all):
#   "\*"                   -> a literal "*": CommonMark's backslash escape,
#                            over the full ASCII punctuation set, taken
#                            AHEAD of every branch below -- so "\`" opens no
#                            code span and "\*" opens no delimiter run.
#   "`text`"               -> code, first branch after the escape; content is
#                            taken verbatim, never re-scanned for emphasis.
#   "@name"                -> a real rich_text mention where the name resolves.
#   "[text](url)"          -> a real rich_text `link` element, the label in
#                            "text" and the target in "url". Both consumed in
#                            ONE step, so the url's own "_" and "*" never
#                            open a delimiter run and the label is verbatim.
#   "*x*" / "_x_"          -> italic; "**x**" / "__x__" -> bold. CommonMark
#                            emphasis, not an invented subset: delimiter
#                            runs and the left/right-flanking predicates, in
#                            processEmphasis() below. ONE delimiter is
#                            italic, TWO is bold, and BOTH "*" and "_" carry
#                            both meanings. "_" takes the spec's stricter
#                            open/close predicates, which is why an
#                            intra-word run ("some_var_name") stays literal
#                            by the spec rather than by a guard of ours.
# An unmatched delimiter, or a pair with nothing between (e.g. "****"), is
# never consumed as a span and passes through as literal text. Slack's
# rich_text cannot nest emphasis, so nested emphasis flattens into one
# combined style set rather than nesting. Full grammar (the one ruled
# flanking departure, the malformed-link rules): see
# Help.DistroAgentsTools.help.md's --member-comms-slack-send-message section;
# for why each is shaped that way, MAGIC.md's own headings for this file.
#
# Consecutive lines of the same kind merge into ONE run, same "paragraph/
# list run" concept the help text uses: consecutive plain lines join
# (JSON-escaped, "\n"-joined -- same convention as agentMcpJsonEscape.awk's
# own multi-line handling) into a single rich_text_section inside one
# `rich_text` block; consecutive bullet lines merge into `rich_text_list`
# element(s) inside one `rich_text` block -- one rich_text_list per
# contiguous same-indent stretch (multiple rich_text_section items each),
# never one block per bullet. A level change mid-list starts a new sibling
# rich_text_list element at the new indent within the same block (that's how
# Slack's own rich_text schema represents nesting -- a list is not nested
# inside a single item, it's a sequence of indent-tagged list elements). A
# run ends on a blank line, a header line, a fence toggle, or a line-kind
# change (paragraph<->list); a header line always closes whatever run is
# open and emits its own standalone `header` block, and a fence opening does
# the same before it starts accumulating verbatim code lines.
#
# JSON string escaping mirrors myx.common's agentMcpJsonEscape.awk exactly
# (same control-char table, same backslash/quote handling; see
# DistroAgentsTools.fn.sh:75-76's own comment on reusing that escaper) --
# this script follows the same convention rather than inventing a second
# escaper, applied per-segment (each plain/bold/italic span gets its own
# pass) since bullet/header text, inline-style spans, and paragraph-line-
# joining all need it independently rather than once over the whole input.

BEGIN {
	for (i = 1; i <= 31; i++) esc[sprintf("%c", i)] = sprintf("\\u%04x", i)
	blockCount = 0
	out = "["
	runKind = ""    # "" | "para" | "list"
	paraLineCount = 0
	listIndent = -1
	listItems = ""  # rich_text_section elements accumulated for the current indent run
	listRun = ""    # rich_text_list elements accumulated for the whole current list run
	inFence = 0     # 0 | 1 -- inside a ``` ... ``` fenced code block
	fenceLineCount = 0
	tableRowCount = 0
	tableSepLine = ""
	## In-body mention map, supplied by the send path as "name=Uxxx;name2=Uyyy"
	## via -v mentionMap=. A name absent from it renders as a literal "@name"
	## and NEVER fails the send -- same failover family as a missing icon
	## falling back to the emoji. An empty/unset map means every "@name" in the
	## body stays literal, which is exactly today's behavior.
	if (mentionMap != "") {
		mentionPairCount = split(mentionMap, mentionPairs, ";")
		for (i = 1; i <= mentionPairCount; i++) {
			eqAt = index(mentionPairs[i], "=")
			if (eqAt > 1) mention[substr(mentionPairs[i], 1, eqAt - 1)] = substr(mentionPairs[i], eqAt + 1)
		}
	}
}

function jsonEscapeLine(line,   i, c, ln, res) {
	res = ""
	ln = length(line)
	for (i = 1; i <= ln; i++) {
		c = substr(line, i, 1)
		if (c == "\\") res = res "\\\\"
		else if (c == "\"") res = res "\\\""
		else if (c in esc) res = res esc[c]
		else res = res c
	}
	return res
}

function plainElem(text) {
	return "{\"type\":\"text\",\"text\":\"" jsonEscapeLine(text) "\"}"
}

function styledElem(text, style) {
	return "{\"type\":\"text\",\"text\":\"" jsonEscapeLine(text) "\",\"style\":{\"" style "\":true}}"
}

## A real Slack mention: the structured "user" element. Deliberately NOT a text
## element carrying an escape form -- an escape form inside rich_text stays
## inert plain text, which is measured, and is the whole reason the text
## version cannot be derived from this one.
function mentionElem(userId) {
	return "{\"type\":\"user\",\"user_id\":\"" jsonEscapeLine(userId) "\"}"
}

## A real Slack link: the structured "link" element, target in "url" and
## visible label in "text". Both are optional to Slack and neither is optional
## here -- an element with no label renders as the bare url, which is what
## Slack's own auto-linkification already produces from plain text.
function linkElem(labelText, targetUrl) {
	return "{\"type\":\"link\",\"url\":\"" jsonEscapeLine(targetUrl) "\",\"text\":\"" jsonEscapeLine(labelText) "\"}"
}

function appendElem(list, elem) {
	return (list == "") ? elem : list "," elem
}

function isSpaceCh(c) {
	return (c == " " || c == "\t")
}

## Punctuation, for the flanking rules below. ASCII punctuation MINUS three
## characters: backtick, apostrophe and double quote.
##
## Excluding them makes each behave as an ordinary character, so a delimiter
## sitting beside one does NOT gain a boundary it would have under CommonMark.
## `"_it_"` therefore stays literal here where the spec would emphasise it.
## That is a DELIBERATE, RULED DEPARTURE from the spec -- recorded here so it
## is never "fixed" back as an oversight. Everything else follows the spec.
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

function styleElem(text, b, i) {
	if (b && i) return "{\"type\":\"text\",\"text\":\"" jsonEscapeLine(text) "\",\"style\":{\"bold\":true,\"italic\":true}}"
	if (b) return styledElem(text, "bold")
	if (i) return styledElem(text, "italic")
	return plainElem(text)
}

## The spec's own "process emphasis" step, run over the delimiter list built by
## parseInlineStyles: walk forward to each closer, walk back to the nearest
## compatible opener, and consume two delimiters for strong or one for
## emphasis. Includes the multiple-of-three rule, which is what stops a run
## that can both open and close from pairing with itself incorrectly.
function processEmphasis(   closer, opener, ok, useLen, t) {
	closer = 1
	while (closer <= nTok) {
		if (tkType[closer] != "delim" || !tkClose[closer] || tkLen[closer] == 0) { closer++ ; continue }
		opener = closer - 1
		ok = 0
		while (opener >= 1) {
			if (tkType[opener] == "delim" && tkLen[opener] > 0 && tkOpen[opener] && tkChar[opener] == tkChar[closer]) {
				## Rule of 3: if either delimiter can both open and close, the
				## summed ORIGINAL run lengths must not be a multiple of 3
				## unless both lengths are themselves multiples of 3.
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
			## A closer with no opener is literal text -- unless it can also
			## open, in which case it stays available for a later closer.
			if (!tkOpen[closer]) {
				tkType[closer] = "text" ; tkText[closer] = dupCh(tkChar[closer], tkLen[closer]) ; tkLen[closer] = 0
			}
			closer++
			continue
		}
		## Two delimiters available on both sides means strong; otherwise
		## emphasis. Slack rich_text cannot nest, so nested emphasis FLATTENS
		## into a combined style set on the innermost text.
		useLen = (tkLen[opener] >= 2 && tkLen[closer] >= 2) ? 2 : 1
		for (t = opener + 1; t < closer; t++) {
			if (useLen == 2) tkB[t] = 1 ; else tkI[t] = 1
		}
		tkLen[opener] -= useLen ; tkLen[closer] -= useLen
		for (t = opener + 1; t < closer; t++) {
			if (tkType[t] == "delim") { tkType[t] = "text" ; tkText[t] = dupCh(tkChar[t], tkLen[t]) ; tkLen[t] = 0 }
		}
		if (tkLen[opener] == 0) tkType[opener] = "used"
		if (tkLen[closer] == 0) { tkType[closer] = "used" ; closer++ }
	}
	for (t = 1; t <= nTok; t++) {
		if (tkType[t] == "delim") {
			if (tkLen[t] > 0) { tkType[t] = "text" ; tkText[t] = dupCh(tkChar[t], tkLen[t]) }
			else tkType[t] = "used"
		}
	}
}

function emitTokens(   t, out, curText, curB, curI) {
	out = "" ; curText = "" ; curB = 0 ; curI = 0
	for (t = 1; t <= nTok; t++) {
		if (tkType[t] == "used") continue
		if (tkType[t] == "text") {
			if (curText != "" && (tkB[t] != curB || tkI[t] != curI)) {
				out = appendElem(out, styleElem(curText, curB, curI)) ; curText = ""
			}
			curB = tkB[t] ; curI = tkI[t] ; curText = curText tkText[t]
			continue
		}
		if (curText != "") { out = appendElem(out, styleElem(curText, curB, curI)) ; curText = "" }
		if (tkType[t] == "code") out = appendElem(out, styledElem(tkText[t], "code"))
		else if (tkType[t] == "mention") out = appendElem(out, mentionElem(tkText[t]))
		else if (tkType[t] == "link") out = appendElem(out, linkElem(tkText[t], tkUrl[t]))
	}
	if (curText != "") out = appendElem(out, styleElem(curText, curB, curI))
	return out
}

## Splits one raw (not yet JSON-escaped) line of text into a comma-joined list
## of rich_text element objects, ready to splice into a rich_text_section's
## own "elements" array.
##
## EMPHASIS IS COMMONMARK, NOT AN INVENTED SUBSET. Delimiter runs, the
## left/right-flanking predicates and the matching in processEmphasis() above
## follow the CommonMark spec's "Emphasis and strong emphasis" section. ONE
## delimiter is emphasis (italic), TWO is strong (bold), and BOTH "*" and "_"
## carry both meanings. "_" takes the spec's stricter open/close predicates,
## which is exactly why an intra-word run such as "mcp__myx_distro__execute"
## never opens strong -- that identifier survives BY THE SPEC, not by a guard
## of ours bolted on beside it.
##
## READ THIS BEFORE "CORRECTING" ANY EXAMPLE IN THIS TREE:
## CommonMark makes "*x*" ITALIC and "__x__" BOLD. The human-owner's own
## illustrations said the reverse ("*bold*", "__ITALLIC__"), and he ruled
## against his own illustrations in the same breath -- "IT IS NOT ME SETTING
## THE FORMAT CORRECTNESS", "whatever is EXACTLY SUPPORTED BY NORMAL PROPER
## MARKDOWN - WINS". So the SPEC wins over the examples, by his own ruling.
## Verified differentially against pandoc's CommonMark reader.
##
## The input grammar is CommonMark; the output is Slack Block Kit. They are
## different things and neither constrains the other -- nested emphasis has no
## Block Kit representation, so it flattens into a combined style set.
function parseInlineStyles(line,   n, i, j, k, c, closeIdx, spanText, mname, runLen,
                                   prevCh, nextCh, beforeSp, beforePu, afterSp, afterPu, lf, rf,
                                   labelEnd, urlEnd, parenDepth, linkLabel, linkTarget) {
	n = length(line)
	nTok = 0
	split("", tkType) ; split("", tkText) ; split("", tkChar)
	split("", tkLen) ; split("", tkOrigLen) ; split("", tkOpen)
	split("", tkClose) ; split("", tkB) ; split("", tkI) ; split("", tkUrl)
	i = 1
	while (i <= n) {
		c = substr(line, i, 1)
		## CommonMark backslash escape, ahead of everything: a backslash before
		## ASCII punctuation makes that character ordinary text, so "\*" is a
		## literal asterisk that opens no delimiter run and "\`" starts no code
		## span. Before any other branch precisely because of that second case.
		## The punctuation set is spelled out here rather than taken from
		## isPunctCh(), which deliberately drops three characters for the
		## flanking rules and would leave "\`" unescaped.
		if (c == "\\" && i < n && index("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~", substr(line, i + 1, 1)) > 0) {
			addTok("text", substr(line, i + 1, 1), "", 0) ; i += 2
			continue
		}
		## Code span FIRST: its content is taken verbatim and never rescanned.
		if (c == "`") {
			closeIdx = 0
			k = i + 1
			while (k <= n) { if (substr(line, k, 1) == "`") { closeIdx = k ; break } ; k++ }
			spanText = (closeIdx > 0) ? substr(line, i + 1, closeIdx - i - 1) : ""
			if (spanText != "") { addTok("code", spanText, "", 0) ; i = closeIdx + 1 ; continue }
			addTok("text", c, "", 0) ; i++
			continue
		}
		## Mention AFTER the code-span branch, so it INHERITS that exclusion by
		## ordering rather than reimplementing it. Fenced blocks never reach
		## inline parsing at all. Boundary: "@" to whitespace or end of line.
		if (c == "@") {
			k = i + 1
			while (k <= n && substr(line, k, 1) != " " && substr(line, k, 1) != "\t") k++
			mname = substr(line, i + 1, k - i - 1)
			if (mname != "" && (mname in mention)) { addTok("mention", mention[mname], "", 0) ; i = k ; continue }
			addTok("text", c, "", 0) ; i++
			continue
		}
		## Link AFTER the code-span branch too, and inheriting its exclusion the
		## same way the mention branch does: a "[a](b)" inside a code span never
		## reaches here, because the backtick arrives first and takes the span
		## verbatim. Ahead of the emphasis branch is where the url's own "_" and
		## "*" are settled -- the whole construct is consumed in ONE step, so
		## they never become delimiter runs at all and "http://x/a_b_c" cannot
		## italicise. Parens nest, so a url ending in "(bar)" closes correctly.
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
					else if (substr(line, k, 1) == ")") { parenDepth-- ; if (parenDepth == 0) { urlEnd = k ; break ; } }
					k++
				}
			}
			linkLabel = (urlEnd > 0) ? substr(line, i + 1, labelEnd - i - 1) : ""
			linkTarget = (urlEnd > 0) ? substr(line, labelEnd + 2, urlEnd - labelEnd - 2) : ""
			## Anything malformed stays literal text and never fails the send --
			## same posture as an unresolvable mention. That covers a missing
			## "]", a "]" with no "(" right behind it, a missing ")", an empty
			## label and an empty url. Whitespace in the url is CommonMark's own
			## rule for a bare destination, and it is what keeps ordinary prose
			## such as "the array [1](see below)" out of a link to "see below".
			if (linkLabel != "" && linkTarget != "" && linkTarget !~ /[ \t]/) {
				addTok("link", linkLabel, "", 0)
				tkUrl[nTok] = linkTarget
				i = urlEnd + 1
				continue
			}
			addTok("text", c, "", 0) ; i++
			continue
		}
		if (c == "*" || c == "_") {
			j = i
			while (j <= n && substr(line, j, 1) == c) j++
			runLen = j - i
			prevCh = (i == 1) ? "" : substr(line, i - 1, 1)
			nextCh = (j > n) ? "" : substr(line, j, 1)
			## The beginning and the end of the line count as whitespace.
			beforeSp = (prevCh == "" || isSpaceCh(prevCh))
			afterSp  = (nextCh == "" || isSpaceCh(nextCh))
			beforePu = isPunctCh(prevCh)
			afterPu  = isPunctCh(nextCh)
			## left-flanking  = (1) not followed by whitespace, AND
			##                  ((2a) not followed by punctuation, OR
			##                   (2b) followed by punctuation and preceded by
			##                        whitespace or punctuation)
			lf = (!afterSp && (!afterPu || (beforeSp || beforePu)))
			## right-flanking = the mirror image of the above.
			rf = (!beforeSp && (!beforePu || (afterSp || afterPu)))
			addTok("delim", "", c, runLen)
			if (c == "*") {
				tkOpen[nTok] = lf ; tkClose[nTok] = rf
			} else {
				## "_" is deliberately stricter than "*" in the spec, so that
				## intra-word underscores in identifiers never emphasise.
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

function emitBlock(json) {
	if (blockCount > 0) out = out ","
	out = out json
	blockCount++
}

## Closes off the currently-accumulating same-indent bullet run (if any) into
## one rich_text_list element and appends it to listRun -- called both on an
## indent-level change (mid list-run) and when the whole list-run itself ends.
function closeListIndentRun() {
	if (listItems == "") return
	if (listRun != "") listRun = listRun ","
	listRun = listRun "{\"type\":\"rich_text_list\",\"style\":\"bullet\",\"indent\":" listIndent ",\"elements\":[" listItems "]}"
	listItems = ""
}

function flushList() {
	closeListIndentRun()
	if (listRun == "") return
	emitBlock("{\"type\":\"rich_text\",\"elements\":[" listRun "]}")
	listRun = ""
	listIndent = -1
}

## Emits the current paragraph run as one rich_text_section -- one or more
## raw lines, each independently inline-style-parsed via parseInlineStyles(),
## joined by a literal "\n" text element between lines (same join convention
## the pre-inline-styles version used, now as its own element instead of a
## character glued inside one big string).
function flushPara(    i, elems) {
	if (paraLineCount == 0) return
	elems = ""
	for (i = 1; i <= paraLineCount; i++) {
		if (i > 1) elems = elems ",{\"type\":\"text\",\"text\":\"\\n\"}"
		elems = appendElem(elems, parseInlineStyles(paraLines[i]))
		delete paraLines[i]
	}
	emitBlock("{\"type\":\"rich_text\",\"elements\":[{\"type\":\"rich_text_section\",\"elements\":[" elems "]}]}")
	paraLineCount = 0
}

## Closes off the currently-accumulating fenced-code-block run into one
## rich_text_preformatted block. Lines are taken verbatim (jsonEscapeLine
## only, no parseInlineStyles) -- same "content taken verbatim, not
## re-scanned for bold/italic" treatment the existing inline "`code`" span
## already gets. Multi-line join mirrors flushPara(): one plainElem() per
## line, joined by a literal {"type":"text","text":"\n"} separator element
## between lines, never an embedded "\n" inside one JSON string. An empty
## fence (opened and immediately closed) emits nothing -- same empty-run
## guard flushPara()/flushList() already have.
function flushFence(    i, elems) {
	if (fenceLineCount == 0) return
	elems = ""
	for (i = 1; i <= fenceLineCount; i++) {
		if (i > 1) elems = appendElem(elems, "{\"type\":\"text\",\"text\":\"\\n\"}")
		if (fenceLines[i] != "") elems = appendElem(elems, plainElem(fenceLines[i]))
		delete fenceLines[i]
	}
	fenceLineCount = 0
	if (elems == "") return
	emitBlock("{\"type\":\"rich_text\",\"elements\":[{\"type\":\"rich_text_preformatted\",\"elements\":[" elems "]}]}")
}

## Splits one raw table row into rowCell[1..rowCellCount] on unescaped "|",
## dropping the outer pipes and trimming each cell. This splitter knows nothing
## about code spans on purpose: GFM's own table extension splits on a pipe even
## inside one, and gives "\|" as the single way to write a literal pipe in a
## cell -- so "\|" is consumed HERE, which is what makes it work inside a code
## span too, where parseInlineStyles takes content verbatim and would leave the
## backslash showing. Every other escape passes through untouched for
## parseInlineStyles to resolve. Verified against pandoc's GFM reader.
function splitRowCells(rowText,   charPos, rowLen, curChar, cellText, cellIndex) {
	rowCellCount = 0
	split("", rowCell)
	if (substr(rowText, 1, 1) == "|") rowText = substr(rowText, 2)
	cellText = ""
	rowLen = length(rowText)
	for (charPos = 1; charPos <= rowLen; charPos++) {
		curChar = substr(rowText, charPos, 1)
		if (curChar == "\\" && charPos < rowLen) {
			cellText = cellText ((substr(rowText, charPos + 1, 1) == "|") ? "|" : curChar substr(rowText, charPos + 1, 1))
			charPos++
			continue ;
		}
		if (curChar == "|") { rowCell[++rowCellCount] = cellText ; cellText = "" ; continue ; }
		cellText = cellText curChar
	}
	rowCell[++rowCellCount] = cellText
	## A trailing "|" leaves one empty field behind it -- punctuation, not a cell.
	if (rowCellCount > 1 && rowCell[rowCellCount] == "") rowCellCount--
	for (cellIndex = 1; cellIndex <= rowCellCount; cellIndex++) {
		sub(/^[ \t]+/, "", rowCell[cellIndex])
		sub(/[ \t]+$/, "", rowCell[cellIndex])
	}
}

## The "|---|:--:|" line under a header row: every field a run of dashes, with
## an optional ":" on either side selecting that column's alignment.
function isSeparatorRow(rowText,   cellIndex) {
	if (substr(rowText, 1, 1) != "|") return 0
	splitRowCells(rowText)
	if (rowCellCount < 1) return 0
	for (cellIndex = 1; cellIndex <= rowCellCount; cellIndex++) {
		if (rowCell[cellIndex] !~ /^:?-+:?$/) return 0
	}
	return 1
}

## Emits the accumulated table run as one Slack `table` block. Cells are
## rich_text, not raw_text, so bold, a "`code`" span, an emoji and a mention
## keep working inside a cell -- raw_text would render every one of them as
## literal characters. Rows are PADDED to the widest row's own cell count:
## real tables arrive ragged, and padding is the only reshaping that neither
## drops a column of data nor refuses the whole message over it.
function flushTable(    rowIndex, cellIndex, colCount, rowsJson, cellsJson, cellElems, alignJson, alignName) {
	if (tableRowCount == 0) return
	colCount = 0
	for (rowIndex = 1; rowIndex <= tableRowCount; rowIndex++) {
		splitRowCells(tableRows[rowIndex])
		if (rowCellCount > colCount) colCount = rowCellCount
	}
	if (colCount < 1) colCount = 1
	splitRowCells(tableSepLine)
	alignJson = ""
	for (cellIndex = 1; cellIndex <= colCount; cellIndex++) {
		alignName = "left"
		if (cellIndex <= rowCellCount && rowCell[cellIndex] ~ /^:-+:$/) alignName = "center"
		else if (cellIndex <= rowCellCount && rowCell[cellIndex] ~ /^-+:$/) alignName = "right"
		alignJson = appendElem(alignJson, "{\"align\":\"" alignName "\",\"is_wrapped\":true}")
	}
	rowsJson = ""
	for (rowIndex = 1; rowIndex <= tableRowCount; rowIndex++) {
		splitRowCells(tableRows[rowIndex])
		cellsJson = ""
		for (cellIndex = 1; cellIndex <= colCount; cellIndex++) {
			cellElems = (cellIndex <= rowCellCount) ? parseInlineStyles(rowCell[cellIndex]) : ""
			## A padded or empty cell still carries one element: Slack rejects a
			## childless "elements" array wherever it sits.
			if (cellElems == "") cellElems = "{\"type\":\"text\",\"text\":\" \"}"
			cellsJson = appendElem(cellsJson, "{\"type\":\"rich_text\",\"elements\":[{\"type\":\"rich_text_section\",\"elements\":[" cellElems "]}]}")
		}
		rowsJson = appendElem(rowsJson, "[" cellsJson "]")
	}
	tableRowCount = 0
	emitBlock("{\"type\":\"table\",\"column_settings\":[" alignJson "],\"rows\":[" rowsJson "]}")
}

function flushRun() {
	if (runKind == "para") flushPara()
	else if (runKind == "list") flushList()
	else if (runKind == "table") flushTable()
	runKind = ""
}

function emitHeader(text) {
	if (text == "") return
	emitBlock("{\"type\":\"header\",\"text\":{\"type\":\"plain_text\",\"text\":\"" jsonEscapeLine(text) "\",\"emoji\":true}}")
}

{
	line = $0

	## Fenced code block: any line starting with three backticks toggles
	## fence state. Opening: flush whatever run was open, same as a header
	## line does, then start capturing verbatim lines. Closing: flush the
	## accumulated lines as one rich_text_preformatted block. This check
	## sits before the blank-line check below on purpose -- a blank line
	## inside a fence is code content to preserve, not a run-ending blank.
	if (substr(line, 1, 3) == "```") {
		if (inFence) { flushFence(); inFence = 0; }
		else { flushRun(); inFence = 1; fenceLineCount = 0; }
		next
	}

	if (inFence) {
		fenceLines[++fenceLineCount] = line
		next
	}

	if (line == "") {
		flushRun()
		next
	}

	if (runKind == "table" && substr(line, 1, 1) == "|") {
		tableRows[++tableRowCount] = line
		next
	}

	## A table is recognised by its "|---|---|" line, looking BACK at the row
	## already sitting in the open paragraph run -- which is what lets a pipe
	## line that never gets one stay ordinary paragraph text, with no
	## lookahead and no run to roll back. The header row leaves the paragraph
	## and any prose above it flushes as its own block.
	if (runKind == "para" && paraLineCount > 0 && substr(paraLines[paraLineCount], 1, 1) == "|" && isSeparatorRow(line)) {
		tableRowCount = 0
		tableRows[++tableRowCount] = paraLines[paraLineCount--]
		flushPara()
		runKind = "table"
		tableSepLine = line
		next
	}

	if (substr(line, 1, 2) == "# ") {
		flushRun()
		emitHeader(substr(line, 3))
		next
	}

	## "## text" / "### text" (two or more "#"s) -- Slack's Block Kit
	## `header` block has exactly one flat style, no H2/H3 distinction, so a
	## deeper heading level has no native block to become; render it as a
	## bold paragraph line instead of falling through unconverted (the raw
	## "##" prefix would otherwise show up literally in Slack). Reuses the
	## existing "**text**" -> bold path below rather than adding a second
	## bold mechanism.
	if (match(line, /^##+ /)) {
		line = "**" substr(line, RSTART + RLENGTH) "**"
	}

	## Bullet detection: exact leading-space counts only (0/2/4 -- the
	## restricted syntax this converter deliberately supports), not a
	## generic arbitrary-indent-width parser. Longer prefixes have distinct
	## required characters at every position (space vs. "- "), so checking
	## them in any order is unambiguous.
	indent = -1
	text = ""
	if (substr(line, 1, 2) == "- ") { indent = 0; text = substr(line, 3) }
	else if (substr(line, 1, 4) == "  - ") { indent = 1; text = substr(line, 5) }
	else if (substr(line, 1, 6) == "    - ") { indent = 2; text = substr(line, 7) }

	if (indent >= 0) {
		if (runKind != "list") { flushRun(); runKind = "list" }
		if (indent != listIndent) {
			closeListIndentRun()
			listIndent = indent
		}
		bulletElems = parseInlineStyles(text)
		if (bulletElems != "") listItems = appendElem(listItems, "{\"type\":\"rich_text_section\",\"elements\":[" bulletElems "]}")
		next
	}

	## Plain paragraph line -- accumulated raw (not yet JSON-escaped) so
	## parseInlineStyles() can scan the real characters; flushPara() joins
	## the accumulated lines' own parsed elements with a literal "\n" text
	## element between them.
	if (runKind != "para") { flushRun(); runKind = "para" }
	paraLines[++paraLineCount] = line
}

END {
	## Unterminated fence at EOF -- don't silently lose the accumulated
	## verbatim lines just because the closing ``` never arrived.
	if (inFence) { flushFence(); inFence = 0; }
	flushRun()
	out = out "]"
	print out
}
