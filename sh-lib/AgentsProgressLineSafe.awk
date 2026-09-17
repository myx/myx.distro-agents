#!/usr/bin/env awk

# The one renderer for an untrusted value shown as a terminal progress line,
# shared by every spawn service. Two ways in:
#   awk -v progressLineCap=<bytes> -f AgentsProgressLineSafe.awk -- value on
#     stdin, rendered once on stdout with no trailing newline.
#   awk -f AgentsProgressLineSafe.awk -f <rules>.awk -- loaded ahead of a
#     formatter that calls progressLineSafe() itself.
# MUST run under LC_ALL=C: the byte table and the [[:cntrl:]] gate depend on it.
# See MAGIC.md for why the primitive lives here and what a caller that forgets
# to load it costs.

BEGIN {
	for (byteVal = 0; byteVal < 256; byteVal++) ordTable[sprintf("%c", byteVal)] = byteVal
}

# Cuts to at most capBytes on a real UTF-8 boundary (`...` appended), then folds
# every C0 byte and DEL to a space. capBytes below 1 folds without cutting.
function progressLineSafe(rawText, capBytes,   outText, byteCount, byteIndex, byteVal, cutAt, leadPos, seqLen, wasCut) {
	outText = rawText
	byteCount = length(outText)
	if (capBytes >= 1 && byteCount > capBytes) {
		cutAt = capBytes
		byteVal = ordTable[substr(outText, cutAt, 1)]
		if (byteVal >= 128) {
			leadPos = cutAt
			while (leadPos > 0) {
				byteVal = ordTable[substr(outText, leadPos, 1)]
				if (byteVal >= 192 || byteVal < 128) break
				leadPos--
			}
			if (leadPos > 0 && byteVal >= 192) {
				seqLen = (byteVal >= 240) ? 4 : (byteVal >= 224) ? 3 : 2
				if (leadPos + seqLen - 1 > cutAt) cutAt = leadPos - 1
			} else {
				## Ran off the start, or backed into stray continuation bytes.
				cutAt = leadPos
			}
		}
		outText = substr(outText, 1, cutAt)
		byteCount = cutAt
		wasCut = 1
	}
	## Byte-local and length-preserving, so it runs after the cut. The named
	## class only gates the scan: it can over-match, never under-match.
	if (outText ~ /[[:cntrl:]]/) {
		for (byteIndex = 1; byteIndex <= byteCount; byteIndex++) {
			byteVal = ordTable[substr(outText, byteIndex, 1)]
			if (byteVal < 32 || byteVal == 127) outText = substr(outText, 1, byteIndex - 1) " " substr(outText, byteIndex + 1)
		}
	}
	return wasCut ? outText "..." : outText
}

## Standalone mode: the whole of stdin is one untrusted value.
progressLineCap > 0 {
	progressLineText = progressLineText (NR > 1 ? " " : "") $0
	next
}
END {
	if (progressLineCap > 0) printf "%s", progressLineSafe(progressLineText, progressLineCap)
}
