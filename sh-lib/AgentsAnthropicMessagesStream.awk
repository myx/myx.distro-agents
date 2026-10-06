#!/usr/bin/env awk

# The Anthropic Messages SSE stream, consumed by ONE process for the whole round.
# AgentsAnthropicMessagesWire.sh's AgentsWireStreamConsume runs it as
#   agentsWireStreamScratch=<dir> LC_ALL=C awk -f AgentsHarnessJsonField.awk \
#     -f AgentsHarnessJsonSlice.awk -f <this file>
# and it writes the round's stream.* files -- each block's own, keyed by the index
# the stream gives it -- exactly as the shell loop it replaces did, byte for byte.
# Every field is what that loop's AgentsWireEventField gave: appended straight to a
# file it is exact, and held in a variable first -- `x="$( AgentsWireEventField ...)"`
# -- it lost its trailing newlines, which wireTrim() repeats. Before, every `data:`
# event forked that reader two to four times, and a content_block_start forked the
# slice reader once more.
#
# What must be SHOWN stays the shell's: this prints a record per such event, flushed
# after every input line. A record is a tag line, then each of its fields as `<n>` --
# the count of newlines in it -- and the field itself on the next n+1 lines.
#   H                             a thinking block starts: show its header
#   C text                        a text delta to echo
#   M prompt read write           message_stop: the prompt-cache line
#   X count index                 bash's arithmetic stops here: the shell repeats
#   X usage input write read out  that step, and stops where it always stopped
#
# The block count and the usage sums are decided as bash decided them, by its own
# `[ -lt ]` and `$(( ))`. Plain whole numbers are decided here; any other spelling is
# handed to one `bash -c` running that same test and arithmetic, and where bash's
# arithmetic would have stopped the shell loop dead -- `1.5`, `08`, an unset name
# under `set -u` -- this stops dead at the same point, writing nothing further.
#
# LC_ALL=C IS REQUIRED, as it is for the readers this loads.

BEGIN {
	jfLibrary = 1
	jsLibrary = 1
	wireScratch = ENVIRON["agentsWireStreamScratch"]
	## stream.block.count as the shell found it on entry, and the shell's own flags.
	wireSeen = ENVIRON["agentsWireStreamSeen"]
	wireShellFlags = ENVIRON["agentsWireStreamFlags"]
	wireUsageInput = ""
	wireUsageWrite = ""
	wireUsageRead = ""
	wireUsageOutput = ""
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

## Append, as `... >> file` did -- the file exists afterwards either way.
function wireAppend(fileName, fileText) {
	printf("%s", fileText) >> (wireScratch "/" fileName)
	close(wireScratch "/" fileName)
}

## What `$( reader )` held: the value, every trailing newline gone.
function wireTrim(trimText) {
	while (substr(trimText, length(trimText), 1) == "\n") trimText = substr(trimText, 1, length(trimText) - 1)
	return trimText
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
function wireBashProbe(probeScript, probeOne, probeTwo, probeThree, probeFour,   probeCmd, probeOut) {
	probeCmd = "bash " (index(wireShellFlags, "u") ? "-u " : "") "-c " wireQuote(probeScript) " AgentsWireStream " wireQuote(probeOne) " " wireQuote(probeTwo) " " wireQuote(probeThree) " " wireQuote(probeFour) " 2>/dev/null"
	probeOut = ""
	if ((probeCmd | getline probeOut) <= 0) probeOut = ""
	close(probeCmd)
	return probeOut
}

## The shell's own count step for one content_block_start: 0 where its arithmetic
## would have ended the loop, so the caller stops here.
function wireBlockSeen(blockIndex,   seenNow, probeOut) {
	seenNow = wireSeen
	if (wireCanonical(blockIndex) && (seenNow == "" || wireCanonical(seenNow))) {
		if (!(blockIndex + 0 < seenNow + 0)) {
			wireSeen = blockIndex + 1
			wireWrite("stream.block.count", wireSeen)
		}
		return 1
	}
	probeOut = wireBashProbe("v=$1 s=$2 ; if [ \"$v\" -lt \"${s:-0}\" ] 2>/dev/null ; then printf \"ok=\" ; else n=\"$(( v + 1 ))\" ; printf \"ok:%s\" \"$n\" ; fi", blockIndex, seenNow, "", "")
	if (probeOut == "ok=") return 1
	if (substr(probeOut, 1, 3) != "ok:") return 0
	wireSeen = substr(probeOut, 4)
	wireWrite("stream.block.count", wireSeen)
	return 1
}

## message_stop: the usage line and stream.done, then the cache line to show. 0
## where the shell's sum would have ended the loop instead.
function wireMessageStop(   usagePrompt, usageOutput, usageTotal, probeOut, probeParts) {
	usageOutput = (wireUsageOutput == "") ? 0 : wireUsageOutput
	if ((wireUsageInput == "" || wireCanonical(wireUsageInput)) && (wireUsageWrite == "" || wireCanonical(wireUsageWrite)) && (wireUsageRead == "" || wireCanonical(wireUsageRead)) && wireCanonical(usageOutput)) {
		usagePrompt = wireUsageInput + wireUsageWrite + wireUsageRead
		usageTotal = usagePrompt + usageOutput
	} else {
		probeOut = wireBashProbe("p=$(( ${1:-0} + ${2:-0} + ${3:-0} )) ; t=\"$(( p + ${4:-0} ))\" ; printf \"ok:%s:%s\" \"$p\" \"$t\"", wireUsageInput, wireUsageWrite, wireUsageRead, wireUsageOutput)
		if (substr(probeOut, 1, 3) != "ok:" || split(substr(probeOut, 4), probeParts, ":") != 2) return 0
		usagePrompt = probeParts[1]
		usageTotal = probeParts[2]
	}
	wireWrite("stream.usage", usagePrompt " " usageOutput " " usageTotal "\n")
	print "M"
	wireField(usagePrompt)
	wireField(wireUsageRead)
	wireField(wireUsageWrite)
	wireWrite("stream.done", "")
	return 1
}

## One field of this event, trailing newlines kept; "" where the reader printed nothing.
function wireLeaf(leafPath) {
	if (wireDocRc != 0 || !(leafPath in jfLeafSeen)) return ""
	return jfLeaf[leafPath]
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

function wireData(payload,   eventType, blockIndex, blockType, deltaType, deltaText, stopReason) {
	if (substr(payload, 1, 1) == " ") payload = substr(payload, 2)
	wireDocRc = jfParseText(payload)
	## The `data:` line carries its own type, so the event name adds nothing.
	eventType = wireTrim(wireLeaf("type"))
	if (eventType == "message_start") {
		wireUsageInput = wireTrim(wireLeaf("message.usage.input_tokens"))
		wireUsageWrite = wireTrim(wireLeaf("message.usage.cache_creation_input_tokens"))
		wireUsageRead = wireTrim(wireLeaf("message.usage.cache_read_input_tokens"))
	} else if (eventType == "content_block_start") {
		blockIndex = wireTrim(wireLeaf("index"))
		## The block's raw source as the slice reader prints it, its newline included;
		## the file is there, empty, when that reader found nothing.
		wireWrite("stream.block." blockIndex ".raw", (wireSliceRaw(payload, "content_block") == 0) ? wireSliceValue "\n" : "")
		blockType = wireTrim(wireLeaf("content_block.type"))
		wireWrite("stream.block." blockIndex ".type", blockType)
		if (!wireBlockSeen(blockIndex)) {
			print "X"
			wireField("count")
			wireField(blockIndex)
			exit
		}
		if (blockType == "thinking" || blockType == "redacted_thinking") print "H"
	} else if (eventType == "content_block_delta") {
		blockIndex = wireTrim(wireLeaf("index"))
		deltaType = wireTrim(wireLeaf("delta.type"))
		if (deltaType == "text_delta") {
			deltaText = wireTrim(wireLeaf("delta.text"))
			wireAppend("stream.block." blockIndex ".text", deltaText)
			wireAppend("stream.content", deltaText)
			if (deltaText != "") {
				print "C"
				wireField(deltaText)
			}
		} else if (deltaType == "thinking_delta") {
			wireAppend("stream.block." blockIndex ".thinking", wireLeaf("delta.thinking"))
		} else if (deltaType == "signature_delta") {
			wireAppend("stream.block." blockIndex ".signature", wireLeaf("delta.signature"))
		} else if (deltaType == "input_json_delta") {
			wireAppend("stream.block." blockIndex ".json", wireLeaf("delta.partial_json"))
		}
	} else if (eventType == "message_delta") {
		stopReason = wireTrim(wireLeaf("delta.stop_reason"))
		if (stopReason != "") wireWrite("stream.finish_reason", stopReason)
		wireUsageOutput = wireTrim(wireLeaf("usage.output_tokens"))
	} else if (eventType == "message_stop") {
		if (!wireMessageStop()) {
			print "X"
			wireField("usage")
			wireField(wireUsageInput)
			wireField(wireUsageWrite)
			wireField(wireUsageRead)
			wireField(wireUsageOutput)
			exit
		}
	} else if (eventType == "error") {
		## An error event mid-stream is the whole answer for this round.
		wireAppend("stream.rawother", payload "\n")
	}
}

{
	## A refusal body ends without a newline; awk still reads that last line.
	wireLine = $0
	if (substr(wireLine, length(wireLine), 1) == "\r") wireLine = substr(wireLine, 1, length(wireLine) - 1)
	if (wireLine == "" || substr(wireLine, 1, 1) == ":" || substr(wireLine, 1, 6) == "event:" || substr(wireLine, 1, 3) == "id:" || substr(wireLine, 1, 6) == "retry:") {
		## the `data:` line carries its own type, so the event name adds nothing
	} else if (substr(wireLine, 1, 5) == "data:") {
		wireData(substr(wireLine, 6))
	} else {
		## Not an SSE line at all: a plain non-streaming error body, kept verbatim.
		wireAppend("stream.rawother", wireLine "\n")
	}
	fflush()
}
