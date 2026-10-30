#!/usr/bin/env awk

# Raw text on stdin -> JSON string body on stdout, without surrounding quotes.
# Caller must set LC_ALL=C for byte safety.

## The four controls JSON has a two-byte escape for use it: the backslash-u-0009 form
## costs six bytes for a tab, and every line of a Read result carries one, so a
## 2000-line read paid 8 KB for nothing.
## A byte that cannot start or continue a valid UTF-8 character is replaced by U+FFFD (S21.20):
## a provider's own JSON parser refuses a request body carrying one unconverted, as "invalid
## unicode code point". A valid multi-byte sequence passes through unchanged, lead and every
## continuation byte checked; nothing here re-encodes what was already good UTF-8.
BEGIN {
	for (i = 1; i <= 31; i++) esc[sprintf("%c", i)] = sprintf("\\u%04x", i)
	esc["\t"] = "\\t" ; esc["\r"] = "\\r" ; esc["\b"] = "\\b" ; esc["\f"] = "\\f"
	for (i = 128; i <= 255; i++) ord[sprintf("%c", i)] = i
	replacement = "\357\277\275"
}
function isCont(ch) {
	return (ch in ord) && ord[ch] <= 191
}
{
	if (NR > 1) printf "\\n"
	line = $0
	out = ""
	ln = length(line)
	i = 1
	while (i <= ln) {
		c = substr(line, i, 1)
		if (!(c in ord)) {
			if (c == "\\") out = out "\\\\"
			else if (c == "\"") out = out "\\\""
			else if (c in esc) out = out esc[c]
			else out = out c
			i++
			continue
		}
		b1 = ord[c]
		seqLen = 0
		if (b1 >= 194 && b1 <= 223) seqLen = 2
		else if (b1 >= 224 && b1 <= 239) seqLen = 3
		else if (b1 >= 240 && b1 <= 244) seqLen = 4
		valid = (seqLen > 0) && (i + seqLen - 1 <= ln)
		if (valid) {
			for (k = 1; k < seqLen; k++) if (!isCont(substr(line, i + k, 1))) { valid = 0 ; break }
		}
		if (valid && seqLen == 3) {
			b2 = ord[substr(line, i + 1, 1)]
			if (b1 == 224 && b2 < 160) valid = 0
			else if (b1 == 237 && b2 > 159) valid = 0
		}
		if (valid && seqLen == 4) {
			b2 = ord[substr(line, i + 1, 1)]
			if (b1 == 240 && b2 < 144) valid = 0
			else if (b1 == 244 && b2 > 143) valid = 0
		}
		if (valid) {
			out = out substr(line, i, seqLen)
			i += seqLen
		} else {
			out = out replacement
			i++
		}
	}
	printf "%s", out
}
