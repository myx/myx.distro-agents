#!/usr/bin/env awk

# The OpenAI chat-completions SSE stream, consumed by ONE process for the whole
# round. AgentsOpenAiChatWire.sh's AgentsWireStreamConsume runs it as
#   agentsWireStreamScratch=<dir> LC_ALL=C awk -f AgentsProgressLineSafe.awk \
#     -f AgentsHarnessJsonField.awk -f AgentsHarnessJsonSlice.awk -f <this file>
# and it writes the round's stream.* accumulators exactly as the shell loop it
# replaces did, file by file and byte for byte: each field is what that loop's own
# `$( awk -f AgentsHarnessJsonField.awk ... )` gave -- a plain read with its
# trailing newlines dropped, a sentinel read exact. Before, every `data:` event
# forked that reader four times, and every tool-call delta four times more.
#
# What must be SHOWN stays the shell's: this prints, for each event, the records
# the shell turns into the live display, in the order that loop showed them, and
# flushes after every input line so nothing waits behind a buffer. A record is a
# tag line, then each of its fields as `<n>` -- the count of newlines in it -- and
# the field itself on the next n+1 lines.
#   K               [DONE]: close an open thinking line
#   U prompt cached the prompt-cache line
#   O               a reasoning delta begins: open the thinking line if not open
#   S safe          one sanitised reasoning segment, to buffer and wrap
#   B               a newline inside the reasoning: break the thinking line
#   C content       a content delta: close thinking, echo it
#   X count index   bash's arithmetic stops here: the shell repeats that step
#
# The tool-call count is decided as bash decided it, by `[ index -ge seen ]` and
# `$(( index + 1 ))`. A plain decimal index is decided here; any other spelling is
# handed to one `bash -c` running that same test and arithmetic, and where bash's
# arithmetic would have stopped the shell loop dead -- `08`, `1.5`, an unset name
# under `set -u` -- this stops dead at the same point, writing nothing further.
#
# LC_ALL=C IS REQUIRED, as it is for the readers this loads.

BEGIN {
	jfLibrary = 1
	jsLibrary = 1
	wireScratch = ENVIRON["agentsWireStreamScratch"]
	## stream.tool.count as the shell found it on entry, and the shell's own flags.
	wireSeen = ENVIRON["agentsWireStreamSeen"]
	wireShellFlags = ENVIRON["agentsWireStreamFlags"]
	## What bash's own `[ n -lt m ]` accepts as an integer: strtoimax's leading
	## blanks, a sign, digits, and only spaces or tabs after.
	wireIntegerRe = "^[ \t\n\r\013\014]*[-+]?[0-9]+[ \t]*$"
}

function wireField(fieldText,   fieldCopy) {
	fieldCopy = fieldText
	printf("%d\n%s\n", gsub(/\n/, "", fieldCopy), fieldText)
}

## Overwrite, as `printf '%s' ... > file` did; closed so the next one truncates.
function wireWrite(fileName, fileText) {
	printf("%s", fileText) > (wireScratch "/" fileName)
	close(wireScratch "/" fileName)
}

## Append, as `printf '%s' ... >> file` did -- the file exists afterwards either way.
function wireAppend(fileName, fileText) {
	printf("%s", fileText) >> (wireScratch "/" fileName)
	close(wireScratch "/" fileName)
}

## What `$( reader )` held: the value, every trailing newline gone.
function wireTrim(trimText) {
	while (substr(trimText, length(trimText), 1) == "\n") trimText = substr(trimText, 1, length(trimText) - 1)
	return trimText
}

## Significant digits, past which strtoimax overflows and bash's test refuses the number.
function wireDigits(numText) {
	gsub(/[^0-9]/, "", numText)
	sub(/^0+/, "", numText)
	return length(numText)
}

## A whole number this awk adds exactly and spells as bash does: no sign, no
## leading zero, few enough digits to stay exact in a double.
function wireCanonical(numText) {
	return numText ~ /^(0|[1-9][0-9]*)$/ && length(numText) <= 15
}

function wireQuote(quoteText,   quoteParts, quoteCount, quoteIndex, quoteOut) {
	quoteCount = split(quoteText, quoteParts, "'")
	quoteOut = "'" quoteParts[1]
	for (quoteIndex = 2; quoteIndex <= quoteCount; quoteIndex++) quoteOut = quoteOut "'\\''" quoteParts[quoteIndex]
	return quoteOut "'"
}

## Runs a few lines of bash over the given values with the calling shell's own
## `set -u`, and returns what they print -- "" where bash stopped on an error.
## Reached only for a value spelled other than a plain whole number. Its own error
## text is dropped: the shell repeats the failing step itself (record `X`), so the
## message, and the stop, come from where they always came from.
function wireBashProbe(probeScript, probeOne, probeTwo,   probeCmd, probeOut) {
	probeCmd = "bash " (index(wireShellFlags, "u") ? "-u " : "") "-c " wireQuote(probeScript) " AgentsWireStream " wireQuote(probeOne) " " wireQuote(probeTwo) " 2>/dev/null"
	probeOut = ""
	if ((probeCmd | getline probeOut) <= 0) probeOut = ""
	close(probeCmd)
	return probeOut
}

## The shell's own count step for one tool-call delta: 0 where its arithmetic
## would have ended the loop, so the caller stops here.
function wireToolSeen(indexField,   seenNow, probeOut) {
	seenNow = wireSeen
	if (seenNow == "") seenNow = 0
	if (wireCanonical(indexField) && wireCanonical(seenNow)) {
		if (indexField + 0 >= seenNow + 0) {
			wireSeen = indexField + 1
			wireWrite("stream.tool.count", wireSeen)
		}
		return 1
	}
	probeOut = wireBashProbe("v=$1 s=$2 ; [ -n \"$s\" ] || s=0 ; if [ \"$v\" -ge \"$s\" ] 2>/dev/null ; then n=\"$(( v + 1 ))\" ; printf \"ok:%s\" \"$n\" ; else printf \"ok=\" ; fi", indexField, seenNow)
	if (probeOut == "ok=") return 1
	if (substr(probeOut, 1, 3) != "ok:") return 0
	wireSeen = substr(probeOut, 4)
	wireWrite("stream.tool.count", wireSeen)
	return 1
}

## One leaf of this event, "" where the reader would have printed nothing.
function wireLeaf(leafPath) {
	if (wireDocRc != 0 || !(leafPath in jfLeafSeen)) return ""
	return jfLeaf[leafPath]
}

function wireHas(leafPath) {
	return wireDocRc == 0 && (leafPath in jfLeafSeen)
}

## AgentsHarnessJsonSlice.awk -v mode=raw, driven in place: 0 found (value in
## wireSliceValue), 1 not one JSON object, 3 absent.
function wireSliceRaw(sliceText, slicePath) {
	wantPath = slicePath
	sliceMode = "raw"
	foundCount = 0
	foundValue = ""
	structErr = 0
	delete scanChars
	scanLen = split(sliceText, scanChars, "")
	scanPos = 1
	skipws()
	if (scanPos > scanLen || scanChars[scanPos] != "{") return 1
	scanValue("")
	skipws()
	if (structErr || scanPos <= scanLen) return 1
	if (foundCount == 0) return 3
	wireSliceValue = foundValue
	return 0
}

function wireData(payload,   errorText, usagePrompt, usageCompletion, usageTotal, usageCached, reasoningText, partCount, partIndex, reasoningParts, contentText, finishReason, toolCount, toolIndex, toolBase, toolIndexField, toolId, toolName, toolArgs) {
	## The space after the colon is optional in the SSE grammar, so exactly one is stripped.
	if (substr(payload, 1, 1) == " ") payload = substr(payload, 2)
	if (payload == "[DONE]") {
		wireWrite("stream.done", "")
		print "K"
		return
	}

	## An error object on a data line is the round's whole answer.
	if (index(payload, "\"error\":")) {
		errorText = (wireSliceRaw(payload, "error") == 0) ? wireTrim(wireSliceValue) : ""
		if (errorText != "" && errorText != "null") {
			wireAppend("stream.rawother", payload "\n")
			return
		}
	}

	wireDocRc = jfParseText(payload)

	## Gated on the object, not the key: every delta chunk carries a null usage.
	if (index(payload, "\"usage\":{") || index(payload, "\"usage\": {")) {
		usagePrompt = wireTrim(wireLeaf("usage.prompt_tokens"))
		usageCompletion = wireTrim(wireLeaf("usage.completion_tokens"))
		usageTotal = wireTrim(wireLeaf("usage.total_tokens"))
		if (usageTotal != "") {
			wireWrite("stream.usage", usagePrompt " " usageCompletion " " usageTotal "\n")
			usageCached = wireHas("usage.prompt_tokens_details.cached_tokens") ? wireTrim(wireLeaf("usage.prompt_tokens_details.cached_tokens")) : "absent"
			print "U"
			wireField(usagePrompt)
			wireField(usageCached)
		}
	}

	reasoningText = wireLeaf("choices.0.delta.reasoning")
	if (reasoningText != "") {
		print "O"
		## Split on real newlines, each segment sanitised on its own, exactly as the
		## shell's feed loop split and sanitised them.
		partCount = split(reasoningText, reasoningParts, "\n")
		for (partIndex = 1; partIndex <= partCount; partIndex++) {
			if (reasoningParts[partIndex] != "") {
				print "S"
				wireField(progressLineSafe(reasoningParts[partIndex], 1000000))
			}
			if (partIndex < partCount) print "B"
		}
	}

	contentText = wireLeaf("choices.0.delta.content")
	if (contentText != "") {
		wireAppend("stream.content", contentText)
		print "C"
		wireField(contentText)
	}

	finishReason = wireTrim(wireLeaf("choices.0.finish_reason"))
	if (finishReason != "") wireWrite("stream.finish_reason", finishReason)

	toolCount = wireTrim(wireLeaf("choices.0.delta.tool_calls.__count"))
	if (toolCount == "") toolCount = 0
	## A count bash's test would refuse ran no iteration at all.
	if (toolCount !~ wireIntegerRe || wireDigits(toolCount) > 18) toolCount = 0
	toolCount = toolCount + 0
	## `function.arguments` arrives as fragments keyed by the call's own index.
	for (toolIndex = 0; toolIndex < toolCount; toolIndex++) {
		toolBase = "choices.0.delta.tool_calls." toolIndex
		toolIndexField = wireTrim(wireLeaf(toolBase ".index"))
		if (toolIndexField == "") toolIndexField = toolIndex
		toolId = wireTrim(wireLeaf(toolBase ".id"))
		toolName = wireTrim(wireLeaf(toolBase ".function.name"))
		toolArgs = wireLeaf(toolBase ".function.arguments")
		if (toolId != "") wireWrite("stream.tool." toolIndexField ".id", toolId)
		if (toolName != "") wireWrite("stream.tool." toolIndexField ".name", toolName)
		if (toolArgs != "") wireAppend("stream.tool." toolIndexField ".args", toolArgs)
		if (!wireToolSeen(toolIndexField)) {
			print "X"
			wireField("count")
			wireField(toolIndexField)
			exit
		}
	}
}

{
	## A refusal body ends without a newline; awk still reads that last line.
	wireLine = $0
	if (substr(wireLine, length(wireLine), 1) == "\r") wireLine = substr(wireLine, 1, length(wireLine) - 1)
	if (wireLine == "") {
		## SSE event separator
	} else if (substr(wireLine, 1, 1) == ":" || substr(wireLine, 1, 6) == "event:" || substr(wireLine, 1, 3) == "id:" || substr(wireLine, 1, 6) == "retry:") {
		## SSE comment/heartbeat, or a named field this API does not use
	} else if (substr(wireLine, 1, 5) == "data:") {
		wireData(substr(wireLine, 6))
	} else {
		## Not an SSE line shape at all: most likely a plain non-streaming error body.
		wireAppend("stream.rawother", wireLine "\n")
	}
	fflush()
}
