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
# escaper, just applied per-line here since bullet/header text and
# paragraph-line-joining all need it independently rather than once over the
# whole input.

BEGIN {
	for (i = 1; i <= 31; i++) esc[sprintf("%c", i)] = sprintf("\\u%04x", i)
	blockCount = 0
	out = "["
	runKind = ""    # "" | "para" | "list"
	paraText = ""
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

function flushPara() {
	if (paraText == "") return
	emitBlock("{\"type\":\"rich_text\",\"elements\":[{\"type\":\"rich_text_section\",\"elements\":[{\"type\":\"text\",\"text\":\"" paraText "\"}]}]}")
	paraText = ""
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
		listItems = listItems "{\"type\":\"rich_text_section\",\"elements\":[{\"type\":\"text\",\"text\":\"" jsonEscapeLine(text) "\"}]}"
		next
	}

	## Plain paragraph line -- joins onto any already-accumulating paragraph
	## run with a literal "\n" (two-char JSON escape, matching
	## agentMcpJsonEscape.awk's own between-line join), not a real newline.
	if (runKind != "para") { flushRun(); runKind = "para" }
	if (paraText != "") paraText = paraText "\\n"
	paraText = paraText jsonEscapeLine(line)
}

END {
	flushRun()
	out = out "]"
	print out
}
