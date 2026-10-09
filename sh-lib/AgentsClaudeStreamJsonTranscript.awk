#!/usr/bin/env awk

# The session transcript of a native claude spawn, written from the same
# `--verbose --output-format stream-json` lines AgentsClaudeStreamJsonFormat.awk turns
# into progress: every tool call with its key arguments, outcome, result size, duration
# and the model's text before it; each round's tokens, then its visible text (about 1 KB),
# on its ROUND line; the model; a provider error the CLI reports as a message, and
# whatever the CLI prints on its stdout outside the stream, each an ERROR line kept in
# full (16 KB); the final result with its usage. Every text goes through the formatter's
# redaction (stlRedactedBody). Thinking is not kept. The
# session's running token sum goes to $MMDAPP/.local/agents/sessions/<sid>/tokens.
#
# NOT STANDALONE, and order is load-bearing:
#   awk -f AgentsProgressLineSafe.awk -f AgentsSessionTranscriptFormat.awk \
#       -f AgentsClaudeStreamJsonTranscript.awk -f AgentsClaudeStreamJsonFormat.awk
# The formatter first, for its stl* functions; this file before the progress formatter,
# because that one exits on the terminal result line and this rule must see it first.
# Silent and inert where the session has no transcript (no MDAT_SPAWN_SESSION_ID, or no
# sessions/<sid>/transcript): every function then returns at once, and the progress
# output is unchanged either way. Never prints to stdout or stderr.

BEGIN {
	stjOn = 0
	stjSid = ENVIRON["MDAT_SPAWN_SESSION_ID"]
	stjApp = ENVIRON["MMDAPP"]
	stjLib = ENVIRON["MDLT_ORIGIN"] "/myx/myx.distro-agents/sh-lib"
	if (stjSid != "" && stjApp != "" && stjSid !~ /[\/ ]/ && ENVIRON["MDLT_ORIGIN"] != "") {
		stjDir = stjApp "/.local/agents/sessions/" stjSid
		stjResolve()
		if (stjPath != "") {
			stjOn = 1
			## The served path of this session leaves its tool lines to this file.
			printf "" > (stjDir "/transcript.stream")
			close(stjDir "/transcript.stream")
			stjTokensRead()
		}
	}
	stjRound = 0
	stjMsgId = ""
	stjMsgText = ""
	stjCliError = ""
}

function stjShellQuote(textValue) {
	gsub(/'/, "'\\''", textValue)
	return "'" textValue "'"
}

# The part to append to, by the shell's own rule (rolls at 8 MB); re-read every 200 writes.
function stjResolve(   resolveCmd, resolveLine) {
	stjPath = ""
	resolveCmd = "/bin/bash -c '. \"$0/AgentsTools.SessionTranscript.include\" && AgentsTranscriptPath \"$1\"' " stjShellQuote(stjLib) " " stjShellQuote(stjSid) " 2>/dev/null"
	if ((resolveCmd | getline resolveLine) > 0) stjPath = resolveLine
	close(resolveCmd)
	stjWrites = 0
}

function stjAppend(blockText) {
	if (!stjOn) return
	if (++stjWrites >= 200) {
		close(stjPath)
		stjResolve()
		if (stjPath == "") { stjOn = 0 ; return }
	}
	print blockText >> stjPath
	fflush(stjPath)
	## The event-track feed (AgentsTools.EventTrackFeed.include): the same lines, while its thread is open.
	if (stjFeedChecked == 0) {
		stjFeedChecked = 1
		stjFeed = ""
		if ((getline stjFeedThread < (stjDir "/event-track")) > 0 && stjFeedThread != "") stjFeed = stjDir "/feed"
		close(stjDir "/event-track")
	}
	## Opened for each write: the poster takes the feed whole by renaming it, and a write
	## through a handle kept open would land in the feed it took.
	if (stjFeed != "") { print blockText >> stjFeed ; close(stjFeed) }
}

function stjStamp() {
	return stlIsoUtc(stlNow())
}

function stjTokensRead(   tokensLine, tokensParts) {
	stjBaseIn = 0 ; stjBaseCr = 0 ; stjBaseCw = 0 ; stjBaseOut = 0
	if ((getline tokensLine < (stjDir "/tokens")) > 0) {
		split(tokensLine, tokensParts, " ")
		stjBaseIn = tokensParts[1] + 0 ; stjBaseCr = tokensParts[2] + 0 ; stjBaseCw = tokensParts[3] + 0 ; stjBaseOut = tokensParts[4] + 0
	}
	close(stjDir "/tokens")
	stjRunIn = 0 ; stjRunCr = 0 ; stjRunCw = 0 ; stjRunOut = 0
}

function stjTokensWrite(   tokensFile) {
	tokensFile = stjDir "/tokens"
	printf "%d %d %d %d\n", stjBaseIn + stjRunIn, stjBaseCr + stjRunCr, stjBaseCw + stjRunCw, stjBaseOut + stjRunOut > tokensFile
	close(tokensFile)
}

# The numbers of one usage object, from the text that follows its `"usage":{`.
function stjUsage(lineText, prefixName,   usageAt, usageText) {
	usageAt = index(lineText, "\"usage\":{")
	if (usageAt == 0) return 0
	usageText = substr(lineText, usageAt + 9)
	usageText = substr(usageText, 1, index(usageText, "}"))
	stjUsageIn = stlJsonScalar(usageText, "input_tokens") + 0
	stjUsageCw = stlJsonScalar(usageText, "cache_creation_input_tokens") + 0
	stjUsageCr = stlJsonScalar(usageText, "cache_read_input_tokens") + 0
	stjUsageOut = stlJsonScalar(usageText, "output_tokens") + 0
	return 1
}

# The round just ended: its tokens into the running sum and one ROUND line, its visible
# text after it, about 1 KB, as the harness writes its own rounds.
function stjRoundFlush() {
	if (stjMsgId == "") return
	stjRunIn += stjMsgIn ; stjRunCr += stjMsgCr ; stjRunCw += stjMsgCw ; stjRunOut += stjMsgOut
	stjAppend(stjStamp() " ROUND n=" stjRound " in=" stjMsgIn " cache-read=" stjMsgCr " cache-write=" stjMsgCw " out=" stjMsgOut \
		(stjMsgText != "" ? "\n" stlRedactedBody(stjMsgText, 1024) : ""))
	stjTokensWrite()
	stjMsgId = ""
	stjMsgText = ""
}

# What the CLI printed on its stdout outside the stream, as one ERROR line kept in full.
function stjCliErrorFlush() {
	if (stjCliError == "") return
	stjAppend(stjStamp() " ERROR source=cli\n" stlRedactedBody(stjCliError, 16384))
	stjCliError = ""
}

# The line without its `"message":{...}` object: the fields the CLI itself adds.
function stjTopLevel(lineText,   messageAt, messageEnd) {
	messageAt = index(lineText, "\"message\":")
	if (messageAt == 0) return lineText
	messageAt += 10
	while (substr(lineText, messageAt, 1) == " ") messageAt++
	messageEnd = stjValueEnd(lineText, messageAt)
	if (messageEnd == 0) return substr(lineText, 1, messageAt - 1)
	return substr(lineText, 1, messageAt - 1) substr(lineText, messageEnd + 1)
}

# The strings of a result's own `"errors":[...]`, one per line; "" when it has none.
function stjErrorsText(lineText,   bracketAt, arrayEnd, arrayText, outText, valueEnd) {
	bracketAt = index(lineText, "\"errors\":[")
	if (bracketAt == 0) return ""
	bracketAt += 9
	arrayEnd = stjValueEnd(lineText, bracketAt)
	if (arrayEnd == 0) return ""
	arrayText = substr(lineText, bracketAt + 1, arrayEnd - bracketAt - 1)
	outText = ""
	while (match(arrayText, /"/)) {
		arrayText = substr(arrayText, RSTART + 1)
		valueEnd = stlJsonStringEnd(arrayText)
		if (valueEnd < 0) break
		outText = outText (outText != "" ? "\n" : "") stlJsonUnescape(substr(arrayText, 1, valueEnd))
		arrayText = substr(arrayText, valueEnd + 2)
	}
	return outText
}

# The matching close of the JSON value opening at fromAt, strings respected; 0 when none.
function stjValueEnd(lineText, fromAt,   scanAt, scanChar, depthCount, inString, isEscaped, lineLength) {
	depthCount = 0 ; inString = 0 ; isEscaped = 0
	lineLength = length(lineText)
	for (scanAt = fromAt; scanAt <= lineLength; scanAt++) {
		scanChar = substr(lineText, scanAt, 1)
		if (inString) {
			if (isEscaped) isEscaped = 0
			else if (scanChar == "\\") isEscaped = 1
			else if (scanChar == "\"") inString = 0
			continue
		}
		if (scanChar == "\"") inString = 1
		else if (scanChar == "{" || scanChar == "[") depthCount++
		else if (scanChar == "}" || scanChar == "]") { depthCount-- ; if (depthCount == 0) return scanAt }
	}
	return 0
}

function stjAssistant(lineText,   headText, contentAt, messageId, messageError, cursorAt, restText, blockAt, blockType, nextAt, blockText, textValue, toolId, toolName, inputAt, inputEnd, inputJson) {
	contentAt = index(lineText, "\"content\":[")
	headText = (contentAt > 0) ? substr(lineText, 1, contentAt) : lineText
	messageId = stlJsonStr(headText, "id")
	## A provider error the CLI reports as a message of its own carries the CLI's `error` beside it.
	messageError = ""
	if (index(lineText, "\"error\":\"") > 0) messageError = stlJsonStr(stjTopLevel(lineText), "error")
	if (messageId != stjMsgId) {
		stjRoundFlush()
		stjMsgId = messageId
		stjRound++
		stjMsgText = ""
		## A call's comment is the text just before it in its own turn, never an earlier turn's.
		stjLastText = ""
		stjMsgIn = 0 ; stjMsgCr = 0 ; stjMsgCw = 0 ; stjMsgOut = 0
	}
	## The latest usage snapshot of this message stands: output grows as it streams.
	if (stjUsage(lineText)) { stjMsgIn = stjUsageIn ; stjMsgCr = stjUsageCr ; stjMsgCw = stjUsageCw ; stjMsgOut = stjUsageOut }
	cursorAt = 1
	while (1) {
		restText = substr(lineText, cursorAt)
		if (!match(restText, /"type":"(text|tool_use|thinking|redacted_thinking)"/)) break
		blockAt = cursorAt + RSTART - 1
		blockType = substr(restText, RSTART + 8, RLENGTH - 9)
		nextAt = blockAt + RLENGTH
		restText = substr(lineText, nextAt)
		if (match(restText, /"type":"(text|tool_use|thinking|redacted_thinking)"/)) blockText = substr(lineText, blockAt, nextAt - blockAt + RSTART - 1)
		else blockText = substr(lineText, blockAt)
		cursorAt = nextAt
		if (blockType == "text") {
			textValue = stlJsonStr(blockText, "text")
			if (textValue == "") continue
			stjLastText = stlOneLine(textValue, 400)
			## The error's own text, in full, never as the round's text.
			if (messageError != "") {
				stjAppend(stjStamp() " ERROR source=provider" stlKv("kind", messageError) "\n" stlRedactedBody(textValue, 16384))
				continue
			}
			stjMsgText = stjMsgText (stjMsgText != "" ? "\n" : "") textValue
		} else if (blockType == "tool_use") {
			toolId = stlJsonStr(blockText, "id")
			toolName = stlJsonStr(blockText, "name")
			inputJson = "{}"
			inputAt = index(blockText, "\"input\":")
			if (inputAt > 0) {
				inputAt += 8
				while (substr(blockText, inputAt, 1) == " ") inputAt++
				inputEnd = stjValueEnd(blockText, inputAt)
				if (inputEnd > 0) inputJson = substr(blockText, inputAt, inputEnd - inputAt + 1)
			}
			if (toolId == "") toolId = "anon" (++stjAnonCount)
			stjToolName[toolId] = toolName
			stjToolInput[toolId] = inputJson
			stjToolStart[toolId] = stlNow()
			stjToolComment[toolId] = stjLastText
		}
	}
}

function stjToolResults(lineText,   cursorAt, restText, blockAt, nextAt, blockText, toolId, rawText, rawEnd, contentAt, isError, outcomeText, firstText, escapeCount, rawCopy, sizeBytes, sizeLines, durSeconds, durText, lineOut, firstEnd) {
	cursorAt = 1
	while (1) {
		restText = substr(lineText, cursorAt)
		if (!match(restText, /"tool_use_id":"/)) break
		blockAt = cursorAt + RSTART - 1
		nextAt = blockAt + RLENGTH
		restText = substr(lineText, nextAt)
		if (match(restText, /"tool_use_id":"/)) blockText = substr(lineText, blockAt, nextAt - blockAt + RSTART - 1)
		else blockText = substr(lineText, blockAt)
		cursorAt = nextAt
		toolId = stlJsonStr(blockText, "tool_use_id")
		if (!(toolId in stjToolName)) continue
		## The result text, raw: a string content, else the first text part of an array.
		rawText = ""
		contentAt = index(blockText, "\"content\":\"")
		if (contentAt > 0) {
			rawText = substr(blockText, contentAt + 11)
		} else if (match(blockText, /"text":"/)) {
			rawText = substr(blockText, RSTART + RLENGTH)
		}
		rawEnd = stlJsonStringEnd(rawText)
		rawText = (rawEnd >= 0) ? substr(rawText, 1, rawEnd) : ""
		isError = (blockText ~ /"is_error":true/)
		rawCopy = rawText
		escapeCount = gsub(/\\./, "", rawCopy)
		sizeBytes = length(rawText) - escapeCount
		rawCopy = rawText
		sizeLines = (rawText == "") ? 0 : gsub(/\\n/, "", rawCopy) + 1
		firstEnd = index(rawText, "\\n")
		firstText = stlJsonUnescape(substr(rawText, 1, (firstEnd > 0 && firstEnd < 600) ? firstEnd - 1 : 600))
		outcomeText = "ok"
		if (isError) {
			outcomeText = "error"
			if (firstText ~ /[Hh]ook|denied|[Pp]ermission|REFUSAL-ID|read your duty file first|refused/) outcomeText = "refused"
		}
		durSeconds = stlNow() - stjToolStart[toolId]
		durText = (durSeconds < 1) ? "<1s" : durSeconds "s"
		lineOut = stlToolLine(stjStamp(), stjToolName[toolId], stjToolInput[toolId], outcomeText, firstText, sizeBytes, sizeLines, durText, stjToolComment[toolId])
		## Errors and refusals in full, held to 16 KB.
		if (outcomeText != "ok" && rawText != "") lineOut = lineOut "\n" stlBody(stlJsonUnescape(substr(rawText, 1, 20000)), 16384)
		stjAppend(lineOut)
		delete stjToolName[toolId] ; delete stjToolInput[toolId] ; delete stjToolStart[toolId] ; delete stjToolComment[toolId]
	}
}

function stjResult(lineText,   resultText, turnsText, isError) {
	stjCliErrorFlush()
	stjRoundFlush()
	isError = (lineText ~ /"is_error":true/)
	turnsText = stlJsonScalar(lineText, "num_turns")
	## The run's own totals are authoritative over the per-round sum.
	if (stjUsage(lineText)) { stjRunIn = stjUsageIn ; stjRunCr = stjUsageCr ; stjRunCw = stjUsageCw ; stjRunOut = stjUsageOut }
	stjTokensWrite()
	resultText = stlJsonStr(lineText, "result")
	## An error the CLI ended on is its result, or its own `errors`, kept in full (16 KB).
	if (isError && resultText == "") resultText = stjErrorsText(lineText)
	stjAppend(stjStamp() " RESULT outcome=" (isError ? "error" : "ok") (turnsText != "" ? " turns=" turnsText : "") \
		" in=" stjRunIn " cache-read=" stjRunCr " cache-write=" stjRunCw " out=" stjRunOut \
		(resultText != "" ? "\n" stlRedactedBody(resultText, isError ? 16384 : 4096) : ""))
	stjOn = 0
}

stjOn {
	## Not a stream event: what the CLI printed on its stdout outside the stream, collected
	## until the next event, which writes it first.
	if ($0 !~ /^[ \t]*[{]/) {
		if ($0 !~ /^[ \t\r]*$/) stjCliError = stjCliError (stjCliError != "" ? "\n" : "") $0
	} else if (stjCliError != "") {
		stjCliErrorFlush()
	}
	if ($0 ~ /"type":"result"/ && index($0, "\"total_cost_usd\"") > 0) {
		stjResult($0)
	} else if ($0 ~ /"type":"assistant"/) {
		stjAssistant($0)
	} else if ($0 ~ /"type":"user"/ && index($0, "\"tool_use_id\":\"") > 0) {
		stjToolResults($0)
	} else if ($0 ~ /"type":"system"/ && $0 ~ /"subtype":"init"/) {
		stjModel = stlJsonStr($0, "model")
		if (stjModel != "") {
			printf "%s\n", stjModel > (stjDir "/model")
			close(stjDir "/model")
		}
		stjAppend(stjStamp() " MODEL" stlKv("model", stjModel) " service=claude-native" stlKv("cli_session", stlJsonStr($0, "session_id")))
	}
}

## A stream that ends with no result line: its last round, and what the CLI printed after it.
END {
	if (stjOn) {
		stjRoundFlush()
		stjCliErrorFlush()
	}
}
