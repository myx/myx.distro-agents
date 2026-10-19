#!/usr/bin/env awk

# Raw text on stdin -> JSON string body on stdout, without surrounding quotes.
# Caller must set LC_ALL=C for byte safety.

BEGIN {
	for (i = 1; i <= 31; i++) esc[sprintf("%c", i)] = sprintf("\\u%04x", i)
}
{
	if (NR > 1) printf "\\n"
	line = $0
	out = ""
	ln = length(line)
	for (i = 1; i <= ln; i++) {
		c = substr(line, i, 1)
		if (c == "\\") out = out "\\\\"
		else if (c == "\"") out = out "\\\""
		else if (c in esc) out = out esc[c]
		else out = out c
	}
	printf "%s", out
}