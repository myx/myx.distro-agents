#!/usr/bin/env awk

# The one renderer for an untrusted value shown as a terminal progress line,
# shared by every spawn service rather than owned by any of them. Two ways in:
#
#   awk -v progressLineCap=<bytes> -f AgentsProgressLineSafe.awk    -- value on
#       stdin, rendered once on stdout with no trailing newline. This is the
#       whole tool; AgentsScalewayHarness.sh uses it this way.
#   awk -f AgentsProgressLineSafe.awk -f <rules>.awk                -- loaded
#       ahead of a formatter that calls progressLineSafe() itself. With
#       progressLineCap unset the stdin rule below never fires and the loaded
#       rules see every line. AgentsConsoleShellScript.template.sh's claude
#       path uses it this way.
#
# Must run under `LC_ALL=C`: the byte table and the [[:cntrl:]] gate below both
# depend on it. Unpinned, a UTF-8 locale makes gawk match 65 characters for that
# class rather than 32, and makes one-true-awk abort outright on an invalid
# UTF-8 byte -- so the locale, not the awk implementation, is what has to be
# fixed at the call site. Measured across one-true-awk, mawk and gawk.
#
# Splitting this out of a caller is safe only while every caller loads it: a
# call to an undefined awk function is a fatal exit 2 in gawk and one-true-awk
# alike, and it fires at CALL time, so no syntax check or dry run detects a
# caller that forgot -- see MAGIC.md.

BEGIN {
	for (byteVal = 0; byteVal < 256; byteVal++) ordTable[sprintf("%c", byteVal)] = byteVal
}

# Renders one untrusted value as a one-line terminal progress fragment: cut to
# at most `capBytes` bytes on a real UTF-8 character boundary (`...` appended),
# then every C0 byte and DEL folded to a space so nothing can move the cursor.
# `capBytes` below 1 folds without cutting. `ordTable` is built once in BEGIN.
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
				## else: the character ending at cutAt is complete -- keep cutAt as-is.
			} else {
				## Ran off the start (leadPos == 0) or hit a plain ASCII byte while
				## backing up through stray continuation bytes with no lead byte of
				## their own -- nothing valid to keep from this run.
				cutAt = leadPos
			}
		}
		outText = substr(outText, 1, cutAt)
		byteCount = cutAt
		wasCut = 1
	}
	## Folding is byte-local and length-preserving, and no C0/DEL byte can be part
	## of a UTF-8 sequence, so it runs after the cut, over the kept bytes only. The
	## named class gates the scan and never replaces it: a class can only over-match
	## across locales, so a gate built on it costs a wasted pass, never a missed byte.
	if (outText ~ /[[:cntrl:]]/) {
		for (byteIndex = 1; byteIndex <= byteCount; byteIndex++) {
			byteVal = ordTable[substr(outText, byteIndex, 1)]
			if (byteVal < 32 || byteVal == 127) outText = substr(outText, 1, byteIndex - 1) " " substr(outText, byteIndex + 1)
		}
	}
	return wasCut ? outText "..." : outText
}

## Standalone mode: whole stdin is one untrusted value. `next` keeps the line
## from reaching any rules file loaded after this one; with progressLineCap
## unset this rule never fires at all.
progressLineCap > 0 {
	progressLineText = progressLineText (NR > 1 ? " " : "") $0
	next
}
END {
	if (progressLineCap > 0) printf "%s", progressLineSafe(progressLineText, progressLineCap)
}
