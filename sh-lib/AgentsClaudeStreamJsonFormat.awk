#!/usr/bin/env awk

# Reformats one claude `--verbose --output-format stream-json` run into short,
# human-readable progress lines on real stderr (flushed per line), and copies
# the terminal `type:"result"` line's own `.result` text onto real stdout,
# exiting 0 or 1 per that line's `.is_error`. Run under `LC_ALL=C awk -f` for
# byte safety, fed by claude's own stdout -- see AgentsConsoleShellScript.template.sh.
#
# NOT STANDALONE. It calls progressLineSafe(), which lives in
# AgentsProgressLineSafe.awk, so every caller must load that file FIRST:
#   awk -f AgentsProgressLineSafe.awk -f AgentsClaudeStreamJsonFormat.awk
# Loading this one alone is a fatal exit 2 the first time a progress line is
# rendered -- at call time, undetectable by any syntax check -- see MAGIC.md.
#
# Bespoke regex extraction for this stream's own known line shapes -- not a
# general JSON parser. A record's own top-level `type` is not reliably its
# first key (the real terminal line carries it near the end), so classification
# checks for each envelope's own literal type VALUE instead of a key position --
# "system"/"assistant"/"user"/"result" never occur as a nested content block's
# own type (those are "text"/"thinking"/"tool_use"/"tool_result", a disjoint
# set), so an unanchored substring check is safe. The terminal line, the one
# case where misclassifying a tool-output line as it would print the wrong
# thing to real stdout, additionally requires "total_cost_usd" -- a
# claude-internal metrics field a tool's own output content will not
# coincidentally contain. An unrecognised line is skipped, never fatal --
# claude's next write must never die on a broken pipe from a formatter that
# quit early.

function jsonStringEnd(afterQuote,   byteIndex, byteCount, currentChar, isEscaped) {
	byteCount = length(afterQuote)
	for (byteIndex = 1; byteIndex <= byteCount; byteIndex++) {
		currentChar = substr(afterQuote, byteIndex, 1)
		if (isEscaped) {
			isEscaped = 0
			continue
		}
		if (currentChar == "\\") {
			isEscaped = 1
			continue
		}
		if (currentChar == "\"") return byteIndex - 1
	}
	return -1
}

function jsonUnescape(rawValue,   outValue, byteIndex, byteCount, currentChar) {
	outValue = ""
	byteCount = length(rawValue)
	for (byteIndex = 1; byteIndex <= byteCount; byteIndex++) {
		currentChar = substr(rawValue, byteIndex, 1)
		if (currentChar != "\\" || byteIndex == byteCount) {
			outValue = outValue currentChar
			continue
		}
		byteIndex++
		currentChar = substr(rawValue, byteIndex, 1)
		if (currentChar == "n") outValue = outValue "\n"
		else if (currentChar == "t") outValue = outValue "\t"
		else if (currentChar == "r") outValue = outValue "\r"
		else if (currentChar == "u") byteIndex += 4  # control-char escape outside \n\t\r -- dropped, never shown mid-progress
		else outValue = outValue currentChar          # ", \, / and anything else pass through literally
	}
	return outValue
}

function extractJsonField(sourceLine, fieldKey, searchFrom,   needlePattern, foundAt, afterNeedle, valueEnd) {
	needlePattern = "\"" fieldKey "\":\""
	foundAt = index(substr(sourceLine, searchFrom), needlePattern)
	if (foundAt == 0) return ""
	afterNeedle = substr(sourceLine, searchFrom + foundAt - 1 + length(needlePattern))
	valueEnd = jsonStringEnd(afterNeedle)
	if (valueEnd < 0) return ""
	return jsonUnescape(substr(afterNeedle, 1, valueEnd))
}

# Wrapped to the terminal and indented, so a long line reads as one block rather
# than as a wall the terminal reflowed against the left margin. Layout only: the
# text arrived through progressLineSafe(), so every control byte is already a
# space and nothing here can reintroduce one. COLUMNS via ENVIRON, never -v,
# which backslash-decodes what it is given.
function printProgress(progressText, leadText,   wrapWidth, wordCount, wordList, wordIndex, lineText, indentText) {
	wrapWidth = ENVIRON["COLUMNS"] + 0
	if (wrapWidth < 40) wrapWidth = 100
	## Passed in, never prefixed onto the text: default field splitting strips leading
	## blanks, so an indent carried inside progressText is silently eaten.
	if (leadText == "") leadText = "  "
	indentText = "       "
	wordCount = split(progressText, wordList, " ")
	lineText = leadText
	for (wordIndex = 1; wordIndex <= wordCount; wordIndex++) {
		if (lineText != leadText && lineText != indentText && length(lineText) + length(wordList[wordIndex]) + 1 > wrapWidth) {
			print lineText > "/dev/stderr"
			lineText = indentText
		}
		lineText = lineText (lineText == leadText || lineText == indentText ? "" : " ") wordList[wordIndex]
	}
	if (lineText != leadText && lineText != indentText) print lineText > "/dev/stderr"
	fflush("/dev/stderr")
}

# One obvious "the" argument per tool, shown as `name(value)` -- a tool whose
# arguments don't reduce to one clear candidate is left off this table and
# prints its bare name instead, never a guessed or misleading field.
BEGIN {
	argKeyForTool["Skill"] = "skill"
	argKeyForTool["Read"] = "file_path"
	argKeyForTool["Edit"] = "file_path"
	argKeyForTool["Write"] = "file_path"
	argKeyForTool["NotebookEdit"] = "notebook_path"
	argKeyForTool["Bash"] = "command"
	argKeyForTool["Grep"] = "pattern"
	argKeyForTool["Glob"] = "pattern"
	argKeyForTool["WebFetch"] = "url"
	argKeyForTool["WebSearch"] = "query"
	argKeyForTool["ToolSearch"] = "query"
	argKeyForTool["SendMessage"] = "to"
	argKeyForTool["Task"] = "description"
}

# A path's identity is at its end, so cutting from the right removes exactly the
# part a reader needs: three sibling files under one long directory all render as
# the same truncated prefix. Elides from the LEFT for a value holding a separator,
# keeping the tail; anything else keeps the existing right-hand cut, where the
# start is what identifies it. Sanitised first with no cut, so the control-byte
# guard still runs over the whole value before any of it is dropped.
function elideForDisplay(rawValue, capBytes,   safeValue, tailText) {
	safeValue = progressLineSafe(rawValue, 0)
	if (length(safeValue) <= capBytes) return safeValue
	if (substr(safeValue, 1, 1) == "/") {
		tailText = substr(safeValue, length(safeValue) - capBytes + 4)
		## This file is pinned LC_ALL=C, so that cut is by byte and lands mid-character
		## as readily as not. The head of the sequence went with the elision, so any
		## leading continuation byte is dropped rather than shown as a broken glyph.
		sub(/^[\200-\277]+/, "", tailText)
		return "..." tailText;
	}
	return progressLineSafe(safeValue, capBytes)
}

# Reasoning, with its own line structure intact. progressLineSafe() folds every C0
# byte to a space, newlines included, so passing a whole thinking block through it
# once returns a blob and no amount of wrapping restores the paragraphs and lists the
# model wrote. Split first, sanitise each line on its own, and label the first line
# only -- every line still goes through printProgress, so nothing the model emits
# reaches column zero and the guard's intent is untouched. No cut: a cap here
# discards reasoning and splices a literal "..." into the middle of a sentence.
function printThinking(rawText,   lineCount, lineList, lineIndex, prefixText) {
	lineCount = split(rawText, lineList, "\n")
	prefixText = "  thinking: "
	for (lineIndex = 1; lineIndex <= lineCount; lineIndex++) {
		if (lineList[lineIndex] == "") continue
		printProgress(progressLineSafe(lineList[lineIndex], 0), prefixText)
		prefixText = "            ";
	}
}

# `offset` and `limit` are JSON numbers, which extractJsonField cannot reach -- it
# matches a quoted value. Returns "" where the key is absent, which is what keeps an
# absent range absent instead of rendering it as 0.
function extractJsonNumber(sourceLine, fieldKey,   needlePattern, foundAt, afterNeedle, scanIndex, scanChar, numberText) {
	needlePattern = "\"" fieldKey "\":"
	foundAt = index(sourceLine, needlePattern)
	if (foundAt == 0) return ""
	afterNeedle = substr(sourceLine, foundAt + length(needlePattern))
	numberText = ""
	for (scanIndex = 1; scanIndex <= length(afterNeedle); scanIndex++) {
		scanChar = substr(afterNeedle, scanIndex, 1)
		if (scanChar == " " && numberText == "") continue
		if (index("0123456789", scanChar) == 0) break
		numberText = numberText scanChar;
	}
	return numberText;
}

# The encoded length of a JSON string value, measured without unescaping it: a tool
# result runs to hundreds of kilobytes, and building a second copy of one to size it
# costs the whole stream. Returns -1 where that key carries no string at all, so a
# size nothing could measure is never reported as a 0.
function jsonStringLength(sourceLine, fieldKey,   needlePattern, foundAt) {
	needlePattern = "\"" fieldKey "\":\""
	foundAt = index(sourceLine, needlePattern)
	if (foundAt == 0) return -1
	return jsonStringEnd(substr(sourceLine, foundAt + length(needlePattern)));
}

function reportToolCalls(sourceLine,   cursorPos, blockEnd, blockText, toolName, argKey, argVal, rangeText, readOffset, readLimit) {
	cursorPos = 1
	while (match(substr(sourceLine, cursorPos), /"type":"tool_use"/)) {
		cursorPos = cursorPos + RSTART + RLENGTH - 1
		## Bounded to this one tool_use block -- up to the next one, if any, so a
		## later block's own same-named field (a second Read's file_path) is never
		## picked up as this block's argument.
		blockEnd = length(sourceLine)
		if (match(substr(sourceLine, cursorPos), /"type":"tool_use"/)) blockEnd = cursorPos + RSTART - 2
		blockText = substr(sourceLine, cursorPos, blockEnd - cursorPos + 1)
		toolName = extractJsonField(blockText, "name", 1)
		if (toolName == "") continue
		argKey = argKeyForTool[toolName]
		argVal = (argKey == "") ? "" : extractJsonField(blockText, argKey, 1)
		## The range a read asked for, beside that one argument rather than inside the
		## table above: it qualifies the path instead of competing to be it, and each
		## half appears only where the call carried it.
		rangeText = ""
		if (toolName == "Read") {
			readOffset = extractJsonNumber(blockText, "offset")
			readLimit = extractJsonNumber(blockText, "limit")
			if (readOffset != "") rangeText = rangeText " offset " readOffset
			if (readLimit != "") rangeText = rangeText " limit " readLimit;
		}
		## A name is model output too, and an MCP server names its own tools.
		toolName = progressLineSafe(toolName, 0)
		if (argVal == "") {
			printProgress("-> tool: " toolName rangeText)
		} else {
			printProgress("-> tool: " toolName "(" elideForDisplay(argVal, 110) ")" rangeText)
		}
	}
}

{
	if ($0 ~ /"type":"result"/ && index($0, "\"total_cost_usd\"") > 0) {
		print extractJsonField($0, "result", 1)
		fflush("/dev/stdout")
		if ($0 ~ /"is_error":true/) exit 1
		exit 0
	} else if ($0 ~ /"type":"assistant"/) {
		## A turn's content array can carry a thinking block alongside tool_use
		## blocks on the same line -- checked independently of the tool_use/text
		## branch below so it is never silently dropped just because the same
		## line also has a tool call.
		if ($0 ~ /"type":"thinking"/) {
			previewText = extractJsonField($0, "thinking", 1)
			if (previewText == "") printProgress("thinking...")
			else printThinking(previewText);
		}
		if ($0 ~ /"type":"tool_use"/) {
			reportToolCalls($0)
		} else if ($0 ~ /"type":"text"/) {
			previewText = extractJsonField($0, "text", 1)
			printProgress(previewText == "" ? "answering..." : "answering: " progressLineSafe(previewText, 260))
		}
	} else if ($0 ~ /"type":"user"/) {
		## What the call actually returned, which is the half a PreToolUse hook cannot
		## see. Encoded length of the tool_result string where the record carries one,
		## the record's own length otherwise -- two units, named apart on the line so
		## neither is ever read as the other.
		resultBytes = jsonStringLength($0, "content")
		resultText = ($0 ~ /"is_error":true/) ? "<- tool result (error)" : "<- tool result"
		if (resultBytes < 0) resultText = resultText " record " length($0) " bytes"
		else resultText = resultText " " resultBytes " encoded bytes"
		printProgress(resultText)
	} else if ($0 ~ /"type":"system"/) {
		## Claude's stream carries several "system" subtypes (a one-time "init",
		## and others like a periodic "thinking_tokens" token-count ping) -- only
		## "init" is a real, one-time milestone; the rest are noise this formatter
		## drops rather than re-printing "session started" on every occurrence.
		if ($0 ~ /"subtype":"init"/) printProgress("session started")
	}
}
