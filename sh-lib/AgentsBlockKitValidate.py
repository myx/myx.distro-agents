#!/usr/bin/env python3

# Block Kit validator for DistroAgentsTools.fn.sh's --member-comms-slack-send-message
# (myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh). Reads the final blocks
# array on stdin -- already confirmed syntactically valid JSON and array-shaped
# by the caller -- and prints one line per problem, each naming the path it sits
# at. Prints nothing and exits 0 when the payload is clean. Exits non-zero when
# the walk itself could not complete, so a crash cannot read as a pass; the
# caller treats a non-zero exit and any stdout content alike as a rejection.
#
# It walks the whole payload rather than the top level alone: Slack rejects an
# empty text string and a childless elements array wherever they sit, and a
# top-level check reports clean on exactly the payloads that come back
# invalid_blocks.
#
# What this does NOT promise: that a Slack rejection is impossible. The
# empty-node rule is in none of Slack's published Block Kit pages -- it was
# learned from a live rejection -- so the rule set is open by construction.
# Every rejection class measured so far is caught here; a class nobody has met
# yet is not. Known-uncaught, all documented by Slack and none of them a
# per-node property this walk can see: the 50-block cap per message, the
# 150-character header maximum, the per-type required fields of the blocks a
# caller supplies verbatim, and any value Slack resolves rather than shapes.

import json, sys

TOPLEVELTYPES = {"section","divider","header","context","image","actions","input","video","rich_text","file","table"}

# A table's own three documented maxima. Unlike the 50-block cap they ARE
# visible here -- a row count and a cell count are properties of the node, and
# the character budget is a sum over the array this walk already holds.
TABLEROWMAX = 100
TABLECELLMAX = 20
TABLECHARMAX = 10000

problemList = []
tableCharTotal = 0


def cellTextLength(nodeValue):
	if isinstance(nodeValue, dict):
		return sum(len(itemValue) if keyName == "text" and isinstance(itemValue, str) else cellTextLength(itemValue) for keyName, itemValue in nodeValue.items())
	if isinstance(nodeValue, list):
		return sum(cellTextLength(itemValue) for itemValue in nodeValue)
	return 0


def walkNode(nodeValue, nodePath):
	if isinstance(nodeValue, dict):
		nodeText = nodeValue.get("text")
		if isinstance(nodeText, str) and nodeText == "":
			problemList.append('%s: "text" is empty -- Slack rejects an empty text node' % nodePath)
		if "elements" in nodeValue:
			childList = nodeValue.get("elements")
			if not isinstance(childList, list) or not childList:
				problemList.append('%s: "elements" carries no child -- Slack rejects an element with nothing in it' % nodePath)
		for keyName, keyValue in nodeValue.items():
			walkNode(keyValue, "%s.%s" % (nodePath, keyName))
	elif isinstance(nodeValue, list):
		for itemIndex, itemValue in enumerate(nodeValue):
			walkNode(itemValue, "%s[%d]" % (nodePath, itemIndex))


try:
	blockList = json.load(sys.stdin)
	if not isinstance(blockList, list):
		print("blocks: not a Block Kit array, which the caller had already confirmed -- the two checks disagree")
		sys.exit(1)
	if not blockList:
		problemList.append("blocks: the body produced no blocks at all -- there is nothing to post")
	for blockIndex, blockValue in enumerate(blockList):
		blockPath = "blocks[%d]" % blockIndex
		if not isinstance(blockValue, dict) or blockValue.get("type") not in TOPLEVELTYPES:
			problemList.append('%s: invalid or missing top-level "type" -- mrkdwn/plain_text and the rest are TEXT-OBJECT types, valid only nested inside a block\'s own "text" field, never as a block\'s own "type" (valid top-level types: %s)' % (blockPath, ", ".join(sorted(TOPLEVELTYPES))))
			continue
		if blockValue.get("type") == "table":
			rowList = blockValue.get("rows")
			if not isinstance(rowList, list) or not rowList:
				problemList.append('%s: a table carries no row -- Slack rejects a table with nothing in it' % blockPath)
			else:
				if len(rowList) > TABLEROWMAX:
					problemList.append("%s: %d rows -- Slack accepts at most %d in one table" % (blockPath, len(rowList), TABLEROWMAX))
				for rowIndex, rowValue in enumerate(rowList):
					if isinstance(rowValue, list) and len(rowValue) > TABLECELLMAX:
						problemList.append("%s.rows[%d]: %d cells -- Slack accepts at most %d in one row" % (blockPath, rowIndex, len(rowValue), TABLECELLMAX))
			tableCharTotal += cellTextLength(rowList)
		walkNode(blockValue, blockPath)
except Exception as walkFailure:
	print("blocks: the validator could not finish its own walk, so the payload is unchecked: %s" % walkFailure)
	sys.exit(1)

if tableCharTotal > TABLECHARMAX:
	problemList.append("blocks: %d characters across this message's table cells -- Slack accepts at most %d per message, so the content has to be split across messages" % (tableCharTotal, TABLECHARMAX))

for problemLine in problemList:
	print(problemLine)
