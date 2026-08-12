#!/usr/bin/env python3

# Block Kit -> plain-text fallback renderer for DistroAgentsTools.fn.sh's
# --member-comms-slack-send-message blocks path (myx.distro-agents/sh-scripts/
# DistroAgentsTools.fn.sh / sh-lib/AgentsTools.Member.include). Reads a JSON
# array on stdin -- already confirmed syntactically valid JSON, array-shaped,
# and carrying only real top-level block types by the caller -- and prints a
# plain-text rendering of the blocks' own human-readable leaf text to stdout,
# for chat.postMessage's own top-level "text" field: the summary/notification
# line Slack shows wherever the blocks themselves can't be rendered, and the
# only field this package's own AgentsSlackMessagesFormat.awk reads back.
# Prints nothing when the array carries no readable text at all, and nothing on
# any parse failure. Always exits 0; the caller inspects stdout content, not
# the exit code, and substitutes its own static fallback for empty output.

import json, sys

# Slack documents 40000 characters for chat.postMessage's own top-level "text"
# field. This cap is deliberately ~7% of that: this text is a summary line, not
# the message (the blocks carry that), the caller may still prefix a bot
# identity line onto it, and a multi-page wall of text serves neither Slack's
# own notification nor a sweep readback better than a few readable lines do.
MAX_CHARS = 2800
TRUNCATED_MARKER = " […truncated]"

# Generic recursive collector: picks up a "text" value wherever it is a plain
# string (Slack's text objects, rich_text "text" elements, a link's own label),
# and descends through the two container keys that carry further text-bearing
# nodes. Deliberately NOT a walk over every key -- "type", "url", "action_id",
# "block_id", "style" and friends are structure, not content, and emitting them
# would be junk in a summary line.
def collectText(node, out):
	if isinstance(node, list):
		for item in node:
			collectText(item, out)
		return
	if not isinstance(node, dict):
		return
	value = node.get("text")
	if isinstance(value, str):
		if value != "":
			out.append(value)
	elif isinstance(value, (dict, list)):
		collectText(value, out)
	for key in ("fields", "elements"):
		child = node.get(key)
		if isinstance(child, (dict, list)):
			collectText(child, out)

# One inline run -> one string. Slack renders a run's own elements with no
# separator between them (a link sits inside its sentence), so they join the
# same way here.
def inlineText(node):
	pieces = []
	collectText(node, pieces)
	return "".join(pieces).strip()

def renderRichTextElement(element):
	lines = []
	if not isinstance(element, dict):
		return lines
	if element.get("type") == "rich_text_list":
		indent = element.get("indent")
		if not isinstance(indent, int) or isinstance(indent, bool) or indent < 0:
			indent = 0
		# 2 spaces per level -- the same per-level indent width
		# AgentsSlackBlocksBuild.awk accepts on the way in.
		prefix = ("  " * indent) + "- "
		items = element.get("elements")
		if isinstance(items, list):
			for item in items:
				itemText = inlineText(item)
				if itemText != "":
					lines.append(prefix + itemText)
		return lines
	# rich_text_section, rich_text_quote, rich_text_preformatted: one line
	# (which may itself carry embedded newlines) for the whole run.
	text = inlineText(element)
	if text != "":
		lines.append(text)
	return lines

def renderBlock(block):
	lines = []
	if not isinstance(block, dict):
		return lines
	blockType = block.get("type")
	if blockType == "divider":
		return lines  # a rule, carries no content of its own
	if blockType == "rich_text":
		elements = block.get("elements")
		if isinstance(elements, list):
			for element in elements:
				lines.extend(renderRichTextElement(element))
		return lines
	if blockType == "section":
		text = inlineText(block.get("text"))
		if text != "":
			lines.append(text)
		fields = block.get("fields")
		if isinstance(fields, list):
			for field in fields:
				fieldText = inlineText(field)
				if fieldText != "":
					lines.append(fieldText)
		return lines
	if blockType == "context":
		# Context elements are short inline fragments, and its image elements
		# carry no text at all -- one line for the whole strip reads better
		# than one line per element.
		text = inlineText(block.get("elements"))
		if text != "":
			lines.append(text)
		return lines
	# header, and anything else carrying text (an image title, actions, input,
	# video, file): one line per collected leaf, in document order.
	pieces = []
	collectText(block, pieces)
	for piece in pieces:
		piece = piece.strip()
		if piece != "":
			lines.append(piece)
	return lines

# Cut at a line boundary where one is close enough, else at a word boundary,
# else hard at the budget. A hard cut can never split a UTF-8 entity (Python 3
# str indices are code points), and never lands mid-word in practice because
# the word-boundary branch catches that case first.
def truncate(text):
	if len(text) <= MAX_CHARS:
		return text
	budget = MAX_CHARS - len(TRUNCATED_MARKER)
	head = text[:budget]
	for boundary in (head.rfind("\n"), head.rfind(" ")):
		if boundary >= budget // 2:
			return head[:boundary].rstrip() + TRUNCATED_MARKER
	return head.rstrip() + TRUNCATED_MARKER

try:
	blocks = json.load(sys.stdin)
except Exception:
	sys.exit(0)  # syntax already confirmed valid above; nothing to add here
if not isinstance(blocks, list):
	sys.exit(0)  # array shape already confirmed above

chunks = []
for block in blocks:
	blockLines = renderBlock(block)
	if blockLines:
		chunks.append("\n".join(blockLines))
rendered = "\n\n".join(chunks).strip()
if rendered != "":
	print(truncate(rendered))
