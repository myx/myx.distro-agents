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

function printProgress(progressText) {
	print "  " progressText > "/dev/stderr"
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

function reportToolCalls(sourceLine,   cursorPos, blockEnd, blockText, toolName, argKey, argVal) {
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
		## A name is model output too, and an MCP server names its own tools.
		toolName = progressLineSafe(toolName, 0)
		if (argVal == "") {
			printProgress("-> tool: " toolName)
		} else {
			printProgress("-> tool: " toolName "(" progressLineSafe(argVal, 110) ")")
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
			printProgress(previewText == "" ? "thinking..." : "thinking: " progressLineSafe(previewText, 260))
		}
		if ($0 ~ /"type":"tool_use"/) {
			reportToolCalls($0)
		} else if ($0 ~ /"type":"text"/) {
			previewText = extractJsonField($0, "text", 1)
			printProgress(previewText == "" ? "answering..." : "answering: " progressLineSafe(previewText, 260))
		}
	} else if ($0 ~ /"type":"user"/) {
		printProgress(($0 ~ /"is_error":true/) ? "<- tool result (error)" : "<- tool result")
	} else if ($0 ~ /"type":"system"/) {
		## Claude's stream carries several "system" subtypes (a one-time "init",
		## and others like a periodic "thinking_tokens" token-count ping) -- only
		## "init" is a real, one-time milestone; the rest are noise this formatter
		## drops rather than re-printing "session started" on every occurrence.
		if ($0 ~ /"subtype":"init"/) printProgress("session started")
	}
}
