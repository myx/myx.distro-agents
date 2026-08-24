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
#   "- text"      -> a top-level (indent 0) bullet list item
#   "  - text"    -> an indent-1 nested bullet item (exactly 2 leading spaces)
#   "    - text"  -> an indent-2 nested bullet item (exactly 4 leading spaces)
#   ""            -> ends the current paragraph/list run
#   anything else -> a plain-paragraph line
# Deeper indents (6+ leading spaces) aren't a supported bullet shape -- they
# fall through and are treated as plain paragraph text, same as any other
# non-blank, non-bullet, non-header line.
#
# Recognized inline, within a paragraph or bullet-item line's own text (never
# inside a "# " header line -- Slack's `header` block is `plain_text`, which
# has no rich-text/style support at all):
#   "**text**" / "*text*" -> bold (any run of one-or-more "*" on both sides;
#                            "**" and "*" are interchangeable, not two
#                            separate levels)
#   "_text_"               -> italic (single "_" only, and only where it
#                            sits at a word boundary -- an "_" with a
#                            letter/digit immediately on its outward side,
#                            e.g. "some_var_name", never opens or closes a
#                            span, so identifier-shaped text stays literal)
#   "`text`"               -> code (single "`" only, no word-boundary rule --
#                            unlike "_", a bare "`" isn't part of ordinary
#                            word-shaped text, so it's always delimiter-
#                            significant; its content is taken verbatim, not
#                            re-scanned for bold/italic, same as any other
#                            span's content below)
#   "**_text_**"            -> bold+italic combined (one specific pattern,
#                            not general nesting): EXACTLY a "**" run (not 1,
#                            not 3+) immediately wrapping a word-boundary-
#                            respecting "_..._" span, closed by EXACTLY "**"
#                            right after the closing "_". A single "*"
#                            wrapping "_text_" (e.g. "*_text_*") does NOT
#                            combine -- it stays today's plain-bold-with-
#                            literal-underscores behavior, since only the
#                            exact double-asterisk shape is recognized here.
#                            Because the "_" always sits immediately against
#                            an asterisk on its outward side in this shape,
#                            italic's own word-boundary rule is trivially
#                            satisfied by construction and never rejects it.
# An unmatched delimiter, or a delimiter pair with nothing between (e.g.
# "****"), is never consumed as a span -- it passes through as literal text.
# No nesting beyond the one "**_text_**" combined case above (bold-inside-
# italic any other way, code-inside-either, or vice versa) and no escaping
# ("\*") -- same "restricted, not general" floor as the per-line syntax
# above.
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
# run ends on a blank line, a header line, or a line-kind change
# (paragraph<->list); a header line always closes whatever run is open and
# emits its own standalone `header` block.
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

function isAlnum(c) {
	return (c ~ /^[A-Za-z0-9]$/)
}

function plainElem(text) {
	return "{\"type\":\"text\",\"text\":\"" jsonEscapeLine(text) "\"}"
}

function styledElem(text, style) {
	return "{\"type\":\"text\",\"text\":\"" jsonEscapeLine(text) "\",\"style\":{\"" style "\":true}}"
}

function styledElemBoldItalic(text) {
	return "{\"type\":\"text\",\"text\":\"" jsonEscapeLine(text) "\",\"style\":{\"bold\":true,\"italic\":true}}"
}

function appendElem(list, elem) {
	return (list == "") ? elem : list "," elem
}

## Splits one raw (not yet JSON-escaped) line of text into a comma-joined
## list of rich_text "text" element objects -- one per plain/bold/italic
## span, in left-to-right order -- ready to be spliced directly into a
## rich_text_section's own "elements" array. Single left-to-right scan, no
## nesting, no recursion: see this file's own header comment for the exact
## bold/italic rules this implements.
function parseInlineStyles(line,    n, i, j, k, c, closeIdx, closeEnd, spanText, plain, out, leftOk, rightOk, found) {
	n = length(line)
	out = ""
	plain = ""
	i = 1
	while (i <= n) {
		c = substr(line, i, 1)
		if (c == "*") {
			j = i
			while (j <= n && substr(line, j, 1) == "*") j++
			## Combined bold+italic case -- see this file's own header
			## comment for the exact "**_text_**" shape. Only ever
			## preempts the generic bold scan below when the run is
			## EXACTLY 2 asterisks and a "_" sits immediately after it;
			## anything else (single "*", a 3+ run, no "_" right there,
			## or no matching close) falls straight through unchanged.
			if (j - i == 2 && substr(line, j, 1) == "_") {
				k = j + 1
				found = 0
				while (k <= n) {
					if (substr(line, k, 1) == "_" && substr(line, k + 1, 2) == "**" && substr(line, k + 3, 1) != "*") {
						found = 1
						break
					}
					k++
				}
				if (found && k > j + 1) {
					spanText = substr(line, j + 1, k - j - 1)
					if (plain != "") { out = appendElem(out, plainElem(plain)); plain = "" }
					out = appendElem(out, styledElemBoldItalic(spanText))
					i = k + 3
					continue
				}
			}
			closeIdx = 0
			k = j
			while (k <= n) {
				if (substr(line, k, 1) == "*") { closeIdx = k; break }
				k++
			}
			spanText = (closeIdx > 0) ? substr(line, j, closeIdx - j) : ""
			if (spanText != "") {
				if (plain != "") { out = appendElem(out, plainElem(plain)); plain = "" }
				out = appendElem(out, styledElem(spanText, "bold"))
				closeEnd = closeIdx
				while (closeEnd <= n && substr(line, closeEnd, 1) == "*") closeEnd++
				i = closeEnd
			} else {
				plain = plain substr(line, i, j - i)
				i = j
			}
			continue
		}
		if (c == "_") {
			leftOk = (i == 1) || !isAlnum(substr(line, i - 1, 1))
			found = 0
			if (leftOk) {
				k = i + 1
				while (k <= n) {
					if (substr(line, k, 1) == "_") {
						rightOk = (k == n) || !isAlnum(substr(line, k + 1, 1))
						if (rightOk) { found = 1; break }
					}
					k++
				}
			}
			spanText = found ? substr(line, i + 1, k - i - 1) : ""
			if (spanText != "") {
				if (plain != "") { out = appendElem(out, plainElem(plain)); plain = "" }
				out = appendElem(out, styledElem(spanText, "italic"))
				i = k + 1
				continue
			}
			plain = plain c
			i++
			continue
		}
		if (c == "`") {
			closeIdx = 0
			k = i + 1
			while (k <= n) {
				if (substr(line, k, 1) == "`") { closeIdx = k; break }
				k++
			}
			spanText = (closeIdx > 0) ? substr(line, i + 1, closeIdx - i - 1) : ""
			if (spanText != "") {
				if (plain != "") { out = appendElem(out, plainElem(plain)); plain = "" }
				out = appendElem(out, styledElem(spanText, "code"))
				i = closeIdx + 1
			} else {
				plain = plain c
				i++
			}
			continue
		}
		plain = plain c
		i++
	}
	if (plain != "") out = appendElem(out, plainElem(plain))
	return out
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

function flushRun() {
	if (runKind == "para") flushPara()
	else if (runKind == "list") flushList()
	runKind = ""
}

function emitHeader(text) {
	emitBlock("{\"type\":\"header\",\"text\":{\"type\":\"plain_text\",\"text\":\"" jsonEscapeLine(text) "\",\"emoji\":true}}")
}

{
	line = $0

	if (line == "") {
		flushRun()
		next
	}

	if (substr(line, 1, 2) == "# ") {
		flushRun()
		emitHeader(substr(line, 3))
		next
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
		if (listItems != "") listItems = listItems ","
		listItems = listItems "{\"type\":\"rich_text_section\",\"elements\":[" parseInlineStyles(text) "]}"
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
	flushRun()
	out = out "]"
	print out
}
