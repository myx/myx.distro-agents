#!/usr/bin/env awk

# The one formatter for a session transcript's tool line, shared by every writer:
# the harness model loop, the served (--intern-tool) path, the MCP execute arm and
# the stream-json formatter of a native spawn. The same line goes to the MCP daemon
# log. Run under LC_ALL=C: every cap here counts bytes.
#
# A LIBRARY FIRST. Every function is prefixed stl, so it loads beside another program
# (awk -f AgentsSessionTranscriptFormat.awk -f AgentsClaudeStreamJsonFormat.awk) without
# a name clash, and its own rules run only in standalone mode:
#   stlStandalone=tool  stdin is the call's raw argument JSON; ENVIRON gives
#                       STL_TS STL_TOOL STL_OUTCOME STL_FIRST STL_BYTES STL_LINES
#                       STL_DUR_MS STL_COMMENT. Prints the one tool line.
#   stlStandalone=body  stdin is a text; ENVIRON STL_CAP caps it in bytes (0: none).
#                       Prints it as `> ` lines.
#   stlStandalone=event stdin is `key<TAB>value` lines; ENVIRON STL_TS STL_KIND. Prints
#                       `<ts> <KIND> key=val ...`, an empty value dropping its key.
#   stlStandalone=field stdin is a JSON object; prints its STL_KEY string field.
# Values come through ENVIRON or stdin, never -v, which decodes backslashes.
#
# The line:  <ISO UTC> TOOL <name> key=val ... -> <ok|error|refused> ["first line"]
#            <bytes>B/<lines>L <duration> | "<comment>"
# A value holding anything but a plain token character is double-quoted, with \ and "
# escaped and every control byte folded to a space. No file content and no file list
# is ever put on it: only the key request arguments each tool names below. A token-like
# value in an argument, a command's first line, a result's first line, a comment or a
# body given to stlRedactedBody is replaced by [redacted] (stlRedact) before any cut.

function stlJsonStringEnd(afterQuote,   byteIndex, byteCount, currentChar, isEscaped) {
	byteCount = length(afterQuote)
	isEscaped = 0
	for (byteIndex = 1; byteIndex <= byteCount; byteIndex++) {
		currentChar = substr(afterQuote, byteIndex, 1)
		if (isEscaped) { isEscaped = 0 ; continue }
		if (currentChar == "\\") { isEscaped = 1 ; continue }
		if (currentChar == "\"") return byteIndex - 1
	}
	return -1
}

function stlJsonUnescape(rawValue,   outValue, byteIndex, byteCount, currentChar) {
	outValue = ""
	byteCount = length(rawValue)
	for (byteIndex = 1; byteIndex <= byteCount; byteIndex++) {
		currentChar = substr(rawValue, byteIndex, 1)
		if (currentChar != "\\" || byteIndex == byteCount) { outValue = outValue currentChar ; continue }
		byteIndex++
		currentChar = substr(rawValue, byteIndex, 1)
		if (currentChar == "n") outValue = outValue "\n"
		else if (currentChar == "t") outValue = outValue "\t"
		else if (currentChar == "r") outValue = outValue "\r"
		else if (currentChar == "u") { outValue = outValue "?" ; byteIndex += 4 }
		else outValue = outValue currentChar
	}
	return outValue
}

# The first string value of a key, unescaped; "" when absent or not a string.
function stlJsonStr(jsonText, keyName,   keyAt, restText, valueEnd) {
	if (!match(jsonText, "\"" keyName "\"[ \t\r\n]*:[ \t\r\n]*\"")) return ""
	restText = substr(jsonText, RSTART + RLENGTH)
	valueEnd = stlJsonStringEnd(restText)
	if (valueEnd < 0) return ""
	return stlJsonUnescape(substr(restText, 1, valueEnd))
}

# A number, boolean or string value of a key as written; "" when absent.
function stlJsonScalar(jsonText, keyName,   restText) {
	if (match(jsonText, "\"" keyName "\"[ \t\r\n]*:[ \t\r\n]*-?[0-9][0-9.eE+-]*")) {
		restText = substr(jsonText, RSTART, RLENGTH)
		sub(/^"[^"]*"[ \t\r\n]*:[ \t\r\n]*/, "", restText)
		return restText
	}
	if (match(jsonText, "\"" keyName "\"[ \t\r\n]*:[ \t\r\n]*(true|false)")) {
		restText = substr(jsonText, RSTART, RLENGTH)
		sub(/^"[^"]*"[ \t\r\n]*:[ \t\r\n]*/, "", restText)
		return restText
	}
	return stlJsonStr(jsonText, keyName)
}

function stlFirstLine(textValue,   lineEnd) {
	lineEnd = index(textValue, "\n")
	if (lineEnd > 0) return substr(textValue, 1, lineEnd - 1)
	return textValue
}

# The first line holding anything but blanks; "" for none.
function stlFirstText(textValue,   lineCount, lineList, lineIndex) {
	lineCount = split(textValue, lineList, "\n")
	for (lineIndex = 1; lineIndex <= lineCount; lineIndex++) if (lineList[lineIndex] ~ /[^ \t\r]/) return lineList[lineIndex]
	return ""
}

# A command as a reader wants it, for the event-track post and the console: the shared
# boilerplate that opens most workspace commands left out -- each leading DistroSystemContext,
# DistroAgentsContext or Require step ended by ; or &&, then the Distro dispatcher's own word
# before a tool name. The command as given when nothing else would be left. The transcript
# keeps the command whole.
function stlCompactCmd(cmdText,   restText) {
	restText = cmdText
	while (1) {
		sub(/^[ \t]+/, "", restText)
		if (!match(restText, /^(DistroSystemContext|DistroAgentsContext|Require)([ \t][^;&|]*)?[ \t]*(;|&&)/)) break
		restText = substr(restText, RLENGTH + 1)
	}
	sub(/^[ \t]+/, "", restText)
	if (restText ~ /^Distro[ \t]+[A-Z]/) sub(/^Distro[ \t]+/, "", restText)
	if (restText == "") return cmdText
	return restText
}

# Every match of findPattern, the head keepPattern matches at its start left in place and
# the rest replaced by [redacted] when it is at least minBytes long.
function stlRedactEach(textValue, findPattern, keepPattern, minBytes,   outText, foundText, keepText, secretText) {
	outText = ""
	while (match(textValue, findPattern)) {
		foundText = substr(textValue, RSTART, RLENGTH)
		outText = outText substr(textValue, 1, RSTART - 1)
		textValue = substr(textValue, RSTART + RLENGTH)
		keepText = ""
		if (keepPattern != "" && match(foundText, keepPattern)) keepText = substr(foundText, 1, RLENGTH)
		secretText = substr(foundText, length(keepText) + 1)
		if (length(secretText) >= minBytes && secretText != "[redacted]") outText = outText keepText "[redacted]"
		else outText = outText foundText
	}
	return outText textValue
}

# Token-like values, each replaced by [redacted]: Slack xox[abpr]- and xapp- tokens, a
# Bearer credential, sk- keys, GitHub ghp_, gho_ and github_pat_ tokens, AWS AKIA key ids,
# and the value of a *_TOKEN=, *_KEY=, *_SECRET= or PASSWORD= assignment. The scheme or
# the name before the value stays. A token must start a word, so task- or desk- is no sk-.
function stlRedact(textValue) {
	if (textValue == "") return textValue
	textValue = stlRedactEach(textValue, "(^|[^A-Za-z0-9_])xox[abpr]-[A-Za-z0-9-]+", "^[^A-Za-z0-9_]", 6)
	textValue = stlRedactEach(textValue, "(^|[^A-Za-z0-9_])xapp-[A-Za-z0-9-]+", "^[^A-Za-z0-9_]", 6)
	textValue = stlRedactEach(textValue, "(^|[^A-Za-z0-9_])[Bb]earer[ \t]+[^ \t\"',;)]+", "^[^A-Za-z0-9_]?[Bb]earer[ \t]+", 1)
	textValue = stlRedactEach(textValue, "(^|[^A-Za-z0-9_])sk-[A-Za-z0-9_-]+", "^[^A-Za-z0-9_]", 20)
	textValue = stlRedactEach(textValue, "(^|[^A-Za-z0-9_])gh[po]_[A-Za-z0-9]+", "^[^A-Za-z0-9_]", 20)
	textValue = stlRedactEach(textValue, "(^|[^A-Za-z0-9_])github_pat_[A-Za-z0-9_]+", "^[^A-Za-z0-9_]", 20)
	textValue = stlRedactEach(textValue, "(^|[^A-Za-z0-9_])AKIA[0-9A-Z]+", "^[^A-Za-z0-9_]", 20)
	textValue = stlRedactEach(textValue, "[A-Za-z0-9_]*_(TOKEN|KEY|SECRET)=(\"[^\"]*\"|'[^']*'|[^ \t\"';&|)]+)", "^[A-Za-z0-9_]*=", 1)
	textValue = stlRedactEach(textValue, "[A-Za-z0-9_]*PASSWORD=(\"[^\"]*\"|'[^']*'|[^ \t\"';&|)]+)", "^[A-Za-z0-9_]*=", 1)
	return textValue
}

# One line, every control byte a space, token-like values redacted, cut to cap bytes
# (0: no cut) with a `...`.
function stlOneLine(textValue, capBytes) {
	gsub(/[\001-\037\177]/, " ", textValue)
	textValue = stlRedact(textValue)
	if (capBytes > 0 && length(textValue) > capBytes) {
		textValue = substr(textValue, 1, capBytes - 3)
		sub(/[\300-\377][\200-\277]*$/, "", textValue)
		textValue = textValue "..."
	}
	return textValue
}

function stlQuote(textValue, capBytes) {
	textValue = stlOneLine(textValue, capBytes)
	gsub(/\\/, "\\\\", textValue)
	gsub(/"/, "\\\"", textValue)
	return "\"" textValue "\""
}

# ` key=value`, quoted unless every byte is a plain token character; "" for no value.
function stlKv(keyName, textValue, capBytes) {
	if (textValue == "") return ""
	textValue = stlRedact(textValue)
	if (capBytes <= 0) capBytes = 200
	if (textValue ~ /^[A-Za-z0-9._\/:@+,=%~-]+$/ && length(textValue) <= capBytes) return " " keyName "=" textValue
	return " " keyName "=" stlQuote(textValue, capBytes)
}

# The tool a name means, without an MCP server prefix: mcp__myx_distro__Read is Read.
function stlBaseTool(toolName,   restName, cutAt) {
	if (substr(toolName, 1, 5) != "mcp__") return toolName
	restName = substr(toolName, 6)
	cutAt = index(restName, "__")
	if (cutAt == 0) return toolName
	return substr(restName, cutAt + 2)
}

function stlPathArg(jsonText,   pathValue) {
	pathValue = stlJsonStr(jsonText, "file_path")
	if (pathValue == "") pathValue = stlJsonStr(jsonText, "notebook_path")
	if (pathValue == "") pathValue = stlJsonStr(jsonText, "path")
	return pathValue
}

# The key request arguments of one call, per tool. Never content, never a file list.
function stlToolArgs(toolName, jsonText,   baseName, outText) {
	baseName = stlBaseTool(toolName)
	outText = ""
	if (baseName == "Read") {
		outText = stlKv("path", stlPathArg(jsonText), 300) stlKv("offset", stlJsonScalar(jsonText, "offset")) stlKv("limit", stlJsonScalar(jsonText, "limit")) stlKv("pages", stlJsonStr(jsonText, "pages"))
	} else if (baseName == "Write" || baseName == "NotebookEdit") {
		outText = stlKv("path", stlPathArg(jsonText), 300)
	} else if (baseName == "Edit") {
		outText = stlKv("path", stlPathArg(jsonText), 300) stlKv("replace_all", stlJsonScalar(jsonText, "replace_all"))
	} else if (baseName == "Grep") {
		outText = stlKv("pattern", stlJsonStr(jsonText, "pattern"), 200) stlKv("path", stlJsonStr(jsonText, "path"), 300) stlKv("glob", stlJsonStr(jsonText, "glob")) stlKv("type", stlJsonStr(jsonText, "type")) stlKv("mode", stlJsonStr(jsonText, "output_mode")) stlKv("head_limit", stlJsonScalar(jsonText, "head_limit"))
	} else if (baseName == "Glob") {
		outText = stlKv("pattern", stlJsonStr(jsonText, "pattern"), 200) stlKv("path", stlJsonStr(jsonText, "path"), 300)
	} else if (baseName == "Bash" || baseName == "execute" || baseName == "Monitor") {
		outText = stlKv("cmd", stlOneLine(stlFirstLine(stlJsonStr(jsonText, "command")), 200), 220) stlKv("cwd", stlJsonStr(jsonText, "cwd"), 300) stlKv("workspace", stlJsonStr(jsonText, "workspace"), 300) stlKv("background", stlJsonScalar(jsonText, "background")) stlKv("timeout", stlJsonScalar(jsonText, "timeout")) stlKv("job", stlJsonScalar(jsonText, "job")) stlKv("handle", stlJsonStr(jsonText, "handle")) stlKv("action", stlJsonStr(jsonText, "action"))
	} else if (baseName == "SendMessage") {
		## The message's first line, so a send that failed, and so wrote no MSG-OUT, still says what it was.
		outText = stlKv("to", stlJsonStr(jsonText, "to"), 120) stlKv("as_bot", stlJsonScalar(jsonText, "as_bot")) stlKv("message", stlOneLine(stlFirstText(stlJsonStr(jsonText, "message")), 120), 140)
	} else if (baseName == "SubagentHandback") {
		outText = stlKv("to", stlJsonStr(jsonText, "to"), 120) stlKv("as_bot", stlJsonScalar(jsonText, "as_bot"))
	} else if (baseName == "ReportFindings") {
		outText = stlKv("to", stlJsonStr(jsonText, "to"), 120) stlKv("subject", stlJsonStr(jsonText, "subject"), 120)
	} else if (baseName == "PushNotification") {
		outText = stlKv("to", stlJsonStr(jsonText, "to"), 120) stlKv("severity", stlJsonStr(jsonText, "severity")) stlKv("headline", stlJsonStr(jsonText, "headline"), 120)
	} else if (baseName == "Artifact") {
		outText = stlKv("to", stlJsonStr(jsonText, "to"), 120) stlKv("url", stlJsonStr(jsonText, "url"), 300)
	} else if (baseName == "Wait") {
		outText = stlKv("sources", stlJsonStr(jsonText, "sources"), 200) stlKv("mode", stlJsonStr(jsonText, "mode")) stlKv("timeout", stlJsonScalar(jsonText, "timeout")) stlKv("since", stlJsonScalar(jsonText, "since_utime")) stlKv("addressee", stlJsonStr(jsonText, "addressee"), 120)
	} else if (baseName == "AskUserQuestion") {
		outText = stlKv("to", stlJsonStr(jsonText, "to"), 120) stlKv("kind", stlJsonStr(jsonText, "kind")) stlKv("address_to", stlJsonStr(jsonText, "address_to"), 120) stlKv("wait", stlJsonScalar(jsonText, "wait")) stlKv("pending_id", stlJsonStr(jsonText, "pending_id"))
	} else if (baseName == "Agent" || baseName == "Task") {
		outText = stlKv("agent", stlJsonStr(jsonText, "agent"), 120) stlKv("subagent_type", stlJsonStr(jsonText, "subagent_type"), 120) stlKv("session_id", stlJsonStr(jsonText, "session_id")) stlKv("cli_service", stlJsonStr(jsonText, "cli_service"))
	} else if (baseName == "Skill") {
		outText = stlKv("name", stlJsonStr(jsonText, "name"), 120) stlKv("skill", stlJsonStr(jsonText, "skill"), 120) stlKv("file", stlJsonStr(jsonText, "file"), 200) stlKv("section", stlJsonStr(jsonText, "section"), 120) stlKv("offset", stlJsonScalar(jsonText, "offset")) stlKv("limit", stlJsonScalar(jsonText, "limit"))
	} else if (baseName == "WebFetch") {
		outText = stlKv("url", stlJsonStr(jsonText, "url"), 300)
	} else if (baseName == "WebSearch" || baseName == "ToolSearch") {
		outText = stlKv("query", stlJsonStr(jsonText, "query"), 200)
	} else if (baseName == "TaskOutput" || baseName == "TaskStop") {
		outText = stlKv("handle", stlJsonStr(jsonText, "handle")) stlKv("task_id", stlJsonStr(jsonText, "task_id")) stlKv("shell_id", stlJsonStr(jsonText, "shell_id")) stlKv("offset", stlJsonScalar(jsonText, "offset"))
	} else if (baseName == "ListAgents") {
		outText = stlKv("view", stlJsonStr(jsonText, "view")) stlKv("state", stlJsonStr(jsonText, "state")) stlKv("session_id", stlJsonStr(jsonText, "session_id"))
	} else if (baseName == "ListMcpResourcesTool" || baseName == "ReadMcpResourceTool" || baseName == "ReadMcpResourceDirTool") {
		outText = stlKv("server", stlJsonStr(jsonText, "server"), 120) stlKv("uri", stlJsonStr(jsonText, "uri"), 300) stlKv("uri_prefix", stlJsonStr(jsonText, "uri_prefix"), 300)
	} else if (baseName == "SessionTranscriptAppend") {
		outText = ""
	} else {
		## Only the server knows a foreign tool's shape: its size, never its content.
		if (jsonText != "" && jsonText != "{}") outText = " args=" length(jsonText) "B"
	}
	return outText
}

# The call's own comment, where its arguments carry one: a task tool's subject, a
# description (any tool's: every harness and served tool declares one as the call's
# intent, and native Bash and Agent have their own), an action_summary or a comment; a
# TodoWrite's item in progress, its activeForm else its content.
function stlArgComment(jsonText, toolName,   commentText, baseName, objectText, objectStart, closeAt) {
	commentText = ""
	baseName = stlBaseTool(toolName)
	if (baseName ~ /^Task(Create|Update)$/) commentText = stlJsonStr(jsonText, "subject")
	if (commentText == "") commentText = stlJsonStr(jsonText, "description")
	if (commentText == "") commentText = stlJsonStr(jsonText, "action_summary")
	if (commentText == "") commentText = stlJsonStr(jsonText, "comment")
	if (commentText == "" && baseName == "TodoWrite" && match(jsonText, /"status"[ \t\r\n]*:[ \t\r\n]*"in_progress"/)) {
		## The object holding that status: from the last { before it to the first } after it.
		objectText = substr(jsonText, 1, RSTART)
		objectStart = 0
		while (match(substr(objectText, objectStart + 1), /[{]/)) objectStart += RSTART
		objectText = substr(jsonText, objectStart)
		closeAt = index(objectText, "}")
		if (closeAt > 0) objectText = substr(objectText, 1, closeAt)
		commentText = stlJsonStr(objectText, "activeForm")
		if (commentText == "") commentText = stlJsonStr(objectText, "content")
	}
	return commentText
}

function stlDurMs(durMs) {
	if (durMs == "") return ""
	durMs = durMs + 0
	if (durMs < 1000) return durMs "ms"
	if (durMs < 60000) return sprintf("%.1fs", durMs / 1000)
	return sprintf("%dm%02ds", int(durMs / 60000), int((durMs % 60000) / 1000))
}

# The comment is the call's own (its description, an action_summary) where it
# carries one, else the one passed: the model's visible text just before the call.
function stlToolLine(tsText, toolName, jsonText, outcomeText, firstText, sizeBytes, sizeLines, durText, commentText,   lineText, argComment) {
	argComment = stlArgComment(jsonText, toolName)
	if (argComment != "") commentText = argComment
	lineText = tsText " TOOL " stlOneLine(toolName, 120) stlToolArgs(toolName, jsonText) " -> " outcomeText
	if (outcomeText != "ok" && firstText != "") lineText = lineText " " stlQuote(firstText, 240)
	if (sizeBytes != "") lineText = lineText " " sizeBytes "B" (sizeLines != "" ? "/" sizeLines "L" : "")
	if (durText != "") lineText = lineText " " durText
	if (commentText != "") lineText = lineText " | " stlQuote(commentText, 120)
	return lineText
}

# A text as `> ` lines, cut at capBytes (0: whole) with a marker naming the full size.
function stlBody(textValue, capBytes,   fullBytes, lineCount, lineList, lineIndex, outText, lineText) {
	fullBytes = length(textValue)
	if (capBytes > 0 && fullBytes > capBytes) {
		textValue = substr(textValue, 1, capBytes)
		sub(/[\300-\377][\200-\277]*$/, "", textValue)
	}
	sub(/\n+$/, "", textValue)
	lineCount = split(textValue, lineList, "\n")
	outText = ""
	if (lineCount == 0) outText = ">"
	for (lineIndex = 1; lineIndex <= lineCount; lineIndex++) {
		lineText = lineList[lineIndex]
		gsub(/[\001-\010\013-\037\177]/, " ", lineText)
		outText = outText (lineIndex > 1 ? "\n" : "") "> " lineText
	}
	if (capBytes > 0 && fullBytes > capBytes) outText = outText "\n> [... cut at " capBytes " of " fullBytes " bytes]"
	return outText
}

# A model's or a provider's own text as stlBody shows it, each line redacted (stlRedact)
# before the cut.
function stlRedactedBody(textValue, capBytes,   lineCount, lineList, lineIndex, outText) {
	outText = ""
	lineCount = split(textValue, lineList, "\n")
	for (lineIndex = 1; lineIndex <= lineCount; lineIndex++) outText = outText (lineIndex > 1 ? "\n" : "") stlRedact(lineList[lineIndex])
	return stlBody(outText, capBytes)
}

# Epoch seconds as ISO UTC, by the civil-from-days rule: no strftime in this awk.
function stlIsoUtc(epochSeconds,   dayCount, secOfDay, eraValue, dayOfEra, yearOfEra, dayOfYear, monthPrime, yearValue, monthValue, dayValue) {
	epochSeconds = int(epochSeconds)
	dayCount = int(epochSeconds / 86400)
	secOfDay = epochSeconds - dayCount * 86400
	dayCount += 719468
	eraValue = int(dayCount / 146097)
	dayOfEra = dayCount - eraValue * 146097
	yearOfEra = int((dayOfEra - int(dayOfEra / 1460) + int(dayOfEra / 36524) - int(dayOfEra / 146096)) / 365)
	yearValue = yearOfEra + eraValue * 400
	dayOfYear = dayOfEra - (365 * yearOfEra + int(yearOfEra / 4) - int(yearOfEra / 100))
	monthPrime = int((5 * dayOfYear + 2) / 153)
	dayValue = dayOfYear - int((153 * monthPrime + 2) / 5) + 1
	monthValue = monthPrime < 10 ? monthPrime + 3 : monthPrime - 9
	if (monthValue <= 2) yearValue++
	return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", yearValue, monthValue, dayValue, int(secOfDay / 3600), int((secOfDay % 3600) / 60), secOfDay % 60)
}

# Now, in epoch seconds: srand() returns the seed it replaces, and srand() with no
# argument seeds from the clock.
function stlNow(   seedWas) {
	srand()
	seedWas = srand()
	return seedWas
}

stlStandalone != "" { stlInput = stlInput $0 "\n" ; next }

END {
	if (stlStandalone == "tool") {
		sub(/\n$/, "", stlInput)
		print stlToolLine(ENVIRON["STL_TS"], ENVIRON["STL_TOOL"], stlInput, ENVIRON["STL_OUTCOME"], ENVIRON["STL_FIRST"], ENVIRON["STL_BYTES"], ENVIRON["STL_LINES"], stlDurMs(ENVIRON["STL_DUR_MS"]), ENVIRON["STL_COMMENT"])
	} else if (stlStandalone == "body") {
		sub(/\n$/, "", stlInput)
		print stlBody(stlInput, ENVIRON["STL_CAP"] + 0)
	} else if (stlStandalone == "event") {
		## stdin: one `key<TAB>value` per line; an empty value drops its key.
		stlEventCount = split(stlInput, stlEventRows, "\n")
		stlEventText = ENVIRON["STL_TS"] " " ENVIRON["STL_KIND"]
		for (stlEventIndex = 1; stlEventIndex <= stlEventCount; stlEventIndex++) {
			stlEventTab = index(stlEventRows[stlEventIndex], "\t")
			if (stlEventTab == 0) continue
			stlEventText = stlEventText stlKv(substr(stlEventRows[stlEventIndex], 1, stlEventTab - 1), substr(stlEventRows[stlEventIndex], stlEventTab + 1), 300)
		}
		print stlEventText
	} else if (stlStandalone == "field") {
		## One string field of a JSON object on stdin, as text.
		sub(/\n$/, "", stlInput)
		printf "%s", stlJsonStr(stlInput, ENVIRON["STL_KEY"])
	}
}
