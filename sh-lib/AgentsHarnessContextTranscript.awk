#!/usr/bin/env awk

# The universal harness's persisted model context (context.jsonl, kept in the spawn
# sandbox by AgentsHarnessContext.include) read back: as transcript lines, as a check
# that it parses, or as its records for a resume. One reader, so the transcript, the
# event-track feed and a resume can never read the file differently.
#
# NOT STANDALONE, and order is load-bearing:
#   LC_ALL=C awk -f AgentsHarnessJsonField.awk -f AgentsSessionTranscriptFormat.awk \
#       -f AgentsHarnessContextTranscript.awk
# The JSON reader as a library (jfParseText, jfSliceText), the formatter for its stl*
# functions. LC_ALL=C is required: every cap counts bytes.
#
# The file: one JSON object per line.
#   {"type":"context",...header...}
#   {"type":"system","text":"<the system text, JSON-escaped, exactly as sent>"}
#   {"type":"tools","cksum":"<cksum of the tools array as sent>","bytes":<n>}
#   {"type":"message","n":<n>,"leg":<leg>,"kind":"task|user|assistant|tool","round":<r>,
#    "ts":"<ISO UTC>","ms":<epoch ms>[,meta],"record":<the message record, its own bytes>}
# The record is always last, so its bytes are everything after `,"record":` but the
# closing brace. A record holding a raw newline is kept as "record_text":"<escaped>".
#
# Modes (-v mode=):
#   render    (default) the transcript lines of every message with n >= from (-v from=,
#             default 1): a ROUND line per assistant record -- its tokens, then its visible
#             text cut at 1 KB -- and per tool record the formatter's TOOL line, with the
#             same message events (MSG-OUT, HANDBACK, WAIT-RESULT, DISMISSED, ASK, ANSWER,
#             SPAWN) and bodies the per-call hook writes. Thinking is never rendered. An
#             assistant record before `from` is still read, for the arguments of its calls.
#   validate  rc 0 and the message count when every line parses as one JSON object, the
#             header first, then the system and tools lines, then messages numbered from 1;
#             rc 1 and the reason otherwise.
#   extract   every message record written to <dir>/rec.<n>, its exact bytes (-v dir=),
#             and the message count printed.

BEGIN {
	jfLibrary = 1
	if (mode == "") mode = "render"
	from = from + 0
	if (from < 1) from = 1
	ctxBad = ""
	ctxLine = 0
	ctxMessages = 0
	ctxAssistRaw = ""
	ctxAssistParsed = 1
	ctxRoundText = ""
}

# The wrapper's own fields are read from the bytes before the record only.
function ctxHead(lineText,   recordAt) {
	recordAt = index(lineText, ",\"record\":")
	if (recordAt == 0) recordAt = index(lineText, ",\"record_text\":")
	if (recordAt == 0) return lineText
	return substr(lineText, 1, recordAt)
}

function ctxRecord(lineText,   recordAt) {
	recordAt = index(lineText, ",\"record\":")
	if (recordAt > 0) return substr(lineText, recordAt + 10, length(lineText) - recordAt - 10)
	if (jfParseText(lineText) != 0) return ""
	return jfLeaf["record_text"]
}

# The calls and the visible text of the latest assistant record, read once, when needed.
function ctxAssistParse(   rawText, blockCount, blockIndex, blockType, callCount, sliceAt) {
	if (ctxAssistParsed) return
	ctxAssistParsed = 1
	delete ctxArgs
	delete ctxSliceWant
	ctxRoundText = ""
	rawText = ctxAssistRaw
	if (jfParseText(rawText) != 0) return
	if (("content.__count") in jfLeaf) {
		## Anthropic Messages: content blocks; a tool_use input is sliced as its own bytes.
		blockCount = jfLeaf["content.__count"] + 0
		sliceAt = 0
		for (blockIndex = 0; blockIndex < blockCount; blockIndex++) {
			blockType = jfLeaf["content." blockIndex ".type"]
			if (blockType == "text") ctxRoundText = ctxRoundText jfLeaf["content." blockIndex ".text"]
			else if (blockType == "tool_use") ctxSliceWant[++sliceAt] = blockIndex SUBSEP jfLeaf["content." blockIndex ".id"]
		}
		for (blockIndex = 1; blockIndex <= sliceAt; blockIndex++) {
			split(ctxSliceWant[blockIndex], ctxSlicePart, SUBSEP)
			if (jfSliceText(rawText, "content." ctxSlicePart[1] ".input", "raw") == 0) ctxArgs[ctxSlicePart[2]] = jfSliceValue
			else ctxArgs[ctxSlicePart[2]] = "{}"
		}
	} else {
		## OpenAI chat: a content string, and tool_calls whose arguments are a JSON string.
		ctxRoundText = jfLeaf["content"]
		callCount = jfLeaf["tool_calls.__count"] + 0
		for (blockIndex = 0; blockIndex < callCount; blockIndex++)
			ctxArgs[jfLeaf["tool_calls." blockIndex ".id"]] = jfLeaf["tool_calls." blockIndex ".function.arguments"]
	}
}

function ctxLines(textValue,   lineCount, byteCount) {
	if (textValue == "") return 0
	lineCount = gsub(/\n/, "\n", textValue)
	byteCount = length(textValue)
	if (substr(textValue, byteCount, 1) != "\n") lineCount++
	return lineCount
}

# One event as AgentsTranscriptEvent writes it: values one line each, a body when given.
function ctxEvent(tsText, kindText, bodyText, capBytes, keyList, valueList,   keyName, keyCount, keyAt, valueText, outText) {
	outText = tsText " " kindText
	keyCount = split(keyList, ctxKeyPart, " ")
	for (keyAt = 1; keyAt <= keyCount; keyAt++) {
		valueText = valueList[keyAt]
		gsub(/[\n\t\r]/, " ", valueText)
		outText = outText stlKv(ctxKeyPart[keyAt], valueText, 300)
	}
	if (bodyText != "") outText = outText "\n" stlBody(bodyText, capBytes)
	print outText
}

function ctxRenderRound(headText, tsText,   roundText, valueList) {
	valueList[1] = stlJsonScalar(headText, "round")
	valueList[2] = stlJsonScalar(headText, "in") + 0
	valueList[3] = stlJsonScalar(headText, "cache_read") + 0
	valueList[4] = stlJsonScalar(headText, "cache_write") + 0
	valueList[5] = stlJsonScalar(headText, "out") + 0
	ctxEvent(tsText, "ROUND", ctxRoundText, 1024, "n in cache-read cache-write out", valueList)
}

function ctxRenderTool(headText, tsText, recordText,   toolName, callId, durMs, outcomeText, resultText, argsText, baseName, firstText, commentText, capBytes, bodyText, valueList) {
	toolName = stlJsonStr(headText, "tool")
	callId = stlJsonStr(headText, "id")
	durMs = stlJsonScalar(headText, "dur_ms")
	outcomeText = stlJsonStr(headText, "outcome")
	if (outcomeText == "") outcomeText = "ok"
	resultText = ""
	if (jfParseText(recordText) == 0) {
		if (("content.__count") in jfLeaf) resultText = jfLeaf["content.0.content"]
		else resultText = jfLeaf["content"]
	}
	argsText = (callId in ctxArgs) ? ctxArgs[callId] : "{}"
	if (argsText == "") argsText = "{}"
	baseName = stlBaseTool(toolName)
	firstText = substr(stlFirstLine(resultText), 1, 400)
	commentText = ctxRoundText
	gsub(/[\n\t\r]/, " ", commentText)
	commentText = substr(commentText, 1, 400)
	print stlToolLine(tsText, toolName, argsText, outcomeText, firstText, length(resultText), ctxLines(resultText), stlDurMs(durMs), commentText)
	## Errors and refusals in full; a failed command's own output is held to 16 KB.
	capBytes = (baseName == "execute") ? 16384 : 0
	if (outcomeText != "ok" && resultText != "") print stlBody(resultText, capBytes)
	if (baseName == "SendMessage") {
		if (outcomeText != "ok") return
		valueList[1] = stlJsonStr(argsText, "to")
		ctxEvent(tsText, "MSG-OUT", stlJsonStr(argsText, "message"), 4096, "to", valueList)
	} else if (baseName == "SubagentHandback") {
		if (outcomeText != "ok") return
		bodyText = "task: " stlJsonStr(argsText, "task") "\noutcome: " stlJsonStr(argsText, "outcome") "\nfindings: " stlJsonStr(argsText, "findings") "\nunfinished: " stlJsonStr(argsText, "unfinished")
		valueList[1] = stlJsonStr(argsText, "to")
		ctxEvent(tsText, "HANDBACK", bodyText, 4096, "to", valueList)
	} else if (baseName == "ReportFindings" || baseName == "PushNotification" || baseName == "Artifact") {
		if (outcomeText != "ok") return
		valueList[1] = baseName
		valueList[2] = stlJsonStr(argsText, "to")
		ctxEvent(tsText, "MSG-OUT", argsText, 4096, "tool to", valueList)
	} else if (baseName == "Wait") {
		if (index(firstText, "WAIT-RESULT: DISMISSED") == 1) ctxEvent(tsText, "DISMISSED", resultText, 4096, "", valueList)
		else ctxEvent(tsText, "WAIT-RESULT", resultText, 4096, "", valueList)
	} else if (baseName == "AskUserQuestion") {
		valueList[1] = stlJsonStr(argsText, "to")
		valueList[2] = stlJsonStr(argsText, "kind")
		ctxEvent(tsText, "ASK", stlJsonStr(argsText, "question"), 4096, "to kind", valueList)
		ctxEvent(tsText, "ANSWER", resultText, 4096, "", valueList)
	} else if (baseName == "Agent") {
		valueList[1] = stlJsonStr(argsText, "agent")
		ctxEvent(tsText, "SPAWN", resultText, 1024, "agent", valueList)
	}
}

{
	ctxLine++
	if (mode == "validate") {
		if (ctxBad != "") next
		if (jfParseText($0) != 0) { ctxBad = "line " ctxLine " is not one JSON object" ; next }
		if (ctxLine == 1 && jfLeaf["type"] != "context") { ctxBad = "line 1 is not the context header" ; next }
		if (ctxLine == 2 && jfLeaf["type"] != "system") { ctxBad = "line 2 is not the system text" ; next }
		if (ctxLine == 3 && jfLeaf["type"] != "tools") { ctxBad = "line 3 is not the tools reference" ; next }
		if (ctxLine <= 3) next
		if (jfLeaf["type"] != "message") { ctxBad = "line " ctxLine " is not a message" ; next }
		if (jfLeaf["n"] + 0 != ctxMessages + 1) { ctxBad = "line " ctxLine " is message " jfLeaf["n"] ", expected " (ctxMessages + 1) ; next }
		if (!(("record") in jfLeafSeen) && !(("record_text") in jfLeafSeen) && index($0, ",\"record\":") == 0) { ctxBad = "line " ctxLine " carries no record" ; next }
		ctxMessages++
		next
	}
	if (index($0, "{\"type\":\"message\",") != 1) next
	ctxHeadText = ctxHead($0)
	ctxN = stlJsonScalar(ctxHeadText, "n") + 0
	ctxKind = stlJsonStr(ctxHeadText, "kind")
	ctxMessages++
	if (mode == "extract") {
		ctxOut = dir "/rec." ctxN
		printf "%s", ctxRecord($0) > ctxOut
		close(ctxOut)
		next
	}
	if (ctxKind == "assistant") {
		ctxAssistRaw = ctxRecord($0)
		ctxAssistParsed = 0
		if (ctxN < from) next
		ctxAssistParse()
		ctxRenderRound(ctxHeadText, stlJsonStr(ctxHeadText, "ts"))
		next
	}
	if (ctxKind == "tool" && ctxN >= from) {
		ctxAssistParse()
		ctxRenderTool(ctxHeadText, stlJsonStr(ctxHeadText, "ts"), ctxRecord($0))
	}
}

END {
	if (mode == "validate") {
		if (ctxBad == "" && ctxLine < 3) ctxBad = "the file holds " ctxLine " of its 3 head lines"
		if (ctxBad != "") { print ctxBad ; exit 1 }
		print ctxMessages
		exit 0
	}
	if (mode == "extract") print ctxMessages
}
