#!/usr/bin/env awk

# Reads one Atlassian Cloud JSON response (fed on stdin, run under LC_ALL=C for
# byte safety) and prints one TAB-separated record per element of ONE named
# array, e.g. `-v array=issues -v want=key,fields.status.name,fields.summary`.
# The Atlassian sibling of AgentsSlackListRecords.awk: same recursive-descent
# engine, but this product has no top-level `ok` to gate on (see
# AgentsAtlassianJsonField.awk's own note on that difference) and its TSV cells
# escape rather than blank a control character, so a body or a summary
# carrying a real tab or newline still round-trips.
#
# Fields come out in the order `want` names them, empty for a field this
# element does not carry. A field naming a nested path (fields.status.name) is
# matched by its full key path, never by its last segment -- an issue carries
# `id` on itself AND inside `fields.assignee`, `fields.reporter`, and a
# suffix-only match would silently read the wrong one.
#
#   -v raw=<csv>   Entries copied verbatim from `want` (the full dotted path as
#                  it appears there, e.g. `body` or `fields.description`)
#                  whose value is a JSON object/array rather than a scalar --
#                  an ADF comment body is the working example. Captured as the
#                  exact source bytes of that value, verbatim, rather than
#                  walked into: the cell holds a JSON document, same as
#                  `json.dumps()` produced before this file existed, and a
#                  caller that needs it structured parses that cell itself.
#
# Exit: 0 parsed (zero or more records on stdout), 1 input is not one complete
#       JSON object, 2 usage error (no `array` or no `want` given), 3 the
#       named array itself is absent (never for a real, empty `[]`).
#
# LC_ALL=C IS REQUIRED, not advisory: `split(s, sc, "")` counts CHARACTERS
# rather than bytes under a UTF-8 locale, corrupting emoji and accented text.
# Every call site already sets it.
#
# Parsing engine (skipws/hex2dec/utf8enc/parseString/parseValue/parseObject/
# parseArray) is copied verbatim from AgentsAtlassianJsonField.awk in this same
# directory; only emitLeaf, parseValue's raw-capture arm and the TSV escaping
# differ.

BEGIN {
	if (array == "" || want == "") {
		printf("⛔ ERROR: AgentsAtlassianListRecords.awk: -v array=<name> and -v want=<csv> are both required\n") > "/dev/stderr"
		usageBad = 1
		exit 2
	}
	wantCount = split(want, wantName, ",")
	for (w = 1; w <= wantCount; w++) { wantAt[wantName[w]] = w ; }
	if (raw != "") {
		rawCount = split(raw, rawName, ",")
		for (w = 1; w <= rawCount; w++) { rawAt[rawName[w]] = 1 ; }
	}
	prefix = array "."
	prefixLen = length(prefix)
	maxIdx = -1
	arraySeen = 0
	input = ""
	inputSeen = 0
	structErr = 0
}

function skipws(   c) {
	while (p <= n) {
		c = sc[p]
		if (c == " " || c == "\t" || c == "\n" || c == "\r") p++
		else break
	}
}

function hex2dec(h,   i, c, v, r) {
	r = 0
	for (i = 1; i <= length(h); i++) {
		c = tolower(substr(h, i, 1))
		v = index("0123456789abcdef", c) - 1
		r = r * 16 + v
	}
	return r
}

function utf8enc(cp,   c1, c2, c3, c4) {
	if (cp < 128) {
		return sprintf("%c", cp)
	} else if (cp < 2048) {
		c1 = 192 + int(cp / 64)
		c2 = 128 + (cp % 64)
		return sprintf("%c%c", c1, c2)
	} else if (cp < 65536) {
		c1 = 224 + int(cp / 4096)
		c2 = 128 + int(cp / 64) % 64
		c3 = 128 + (cp % 64)
		return sprintf("%c%c%c", c1, c2, c3)
	} else {
		c1 = 240 + int(cp / 262144)
		c2 = 128 + int(cp / 4096) % 64
		c3 = 128 + int(cp / 64) % 64
		c4 = 128 + (cp % 64)
		return sprintf("%c%c%c%c", c1, c2, c3, c4)
	}
}

function parseString(   c, out, hex, code, hex2, code2, cp, closed) {
	p++
	out = ""
	closed = 0
	while (p <= n) {
		c = sc[p]
		if (c == "\"") { p++; closed = 1; break; }
		if (c == "\\") {
			p++
			c = sc[p]
			if (c == "\"") out = out "\""
			else if (c == "\\") out = out "\\"
			else if (c == "/") out = out "/"
			else if (c == "b") out = out "\b"
			else if (c == "f") out = out "\f"
			else if (c == "n") out = out "\n"
			else if (c == "r") out = out "\r"
			else if (c == "t") out = out "\t"
			else if (c == "u") {
				hex = sc[p+1] sc[p+2] sc[p+3] sc[p+4]
				code = hex2dec(hex)
				p += 4
				if (code >= 55296 && code <= 56319 && (sc[p+1] sc[p+2]) == "\\u") {
					hex2 = sc[p+3] sc[p+4] sc[p+5] sc[p+6]
					code2 = hex2dec(hex2)
					if (code2 >= 56320 && code2 <= 57343) {
						cp = 65536 + (code - 55296) * 1024 + (code2 - 56320)
						out = out utf8enc(cp)
						p += 6
					} else {
						out = out utf8enc(code)
					}
				} else {
					out = out utf8enc(code)
				}
			}
			else out = out c
			p++
		} else {
			out = out c
			p++
		}
	}
	if (!closed) structErr = 1
	return out
}

## Same escape as the Python workers this file replaces: backslash first so
## the escape character itself round-trips, then tab/CR/LF -- never a blanking
## `gsub`, since a summary or a comment body legitimately carries them.
function tsvEscape(v) {
	gsub(/\\/, "\\\\", v)
	gsub(/\t/, "\\t", v)
	gsub(/\r/, "\\r", v)
	gsub(/\n/, "\\n", v)
	return v
}

## The field name a path resolves to under the wanted array, or "" if this
## path is not a direct element of it (wrong prefix, or not `array.<idx>.*`).
function fieldNameAt(path,   rest, idx) {
	if (index(path, prefix) != 1) return ""
	rest = substr(path, prefixLen + 1)
	idx = rest
	sub(/\..*/, "", idx)
	if (idx !~ /^[0-9]+$/) return ""
	if (index(rest, idx ".") != 1) return ""
	return substr(rest, length(idx) + 2)
}

function emitLeaf(path, val,   rest, idx, after) {
	if (index(path, prefix) != 1) return
	rest = substr(path, prefixLen + 1)

	idx = rest
	sub(/\..*/, "", idx)
	if (idx !~ /^[0-9]+$/) return
	if (index(rest, idx ".") != 1) return
	after = fieldNameAt(path)
	if (!(after in wantAt)) return

	if (idx > maxIdx) maxIdx = idx
	seenIdx[idx] = 1
	cell[idx SUBSEP wantAt[after]] = tsvEscape(val)
}

## Advances p past one balanced {...} or [...], skipping over string content
## (via parseString, so a brace inside a string never miscounts) rather than
## walking it into named leaves -- the caller wants these bytes verbatim.
function skipBalanced(   depth, c) {
	depth = 0
	while (p <= n) {
		c = sc[p]
		if (c == "\"") { parseString(); continue; }
		if (c == "{" || c == "[") { depth++; p++; continue; }
		if (c == "}" || c == "]") { depth--; p++; if (depth <= 0) return; continue; }
		p++
	}
	structErr = 1
}

function parseValue(path,   c, startp, val, raw, rawPos, rawField) {
	skipws()
	c = sc[p]
	if (path == array && c == "[") arraySeen = 1
	rawField = fieldNameAt(path)
	if (rawField != "" && (rawField in rawAt) && (c == "{" || c == "[")) {
		startp = p
		skipBalanced()
		raw = ""
		for (rawPos = startp; rawPos < p; rawPos++) raw = raw sc[rawPos]
		emitLeaf(path, raw)
		return
	}
	if (c == "\"") {
		val = parseString()
		emitLeaf(path, val)
	} else if (c == "{") {
		parseObject(path)
	} else if (c == "[") {
		parseArray(path)
	} else if (c == "t") {
		p += 4
		emitLeaf(path, "true")
	} else if (c == "f") {
		p += 5
		emitLeaf(path, "false")
	} else if (c == "n") {
		p += 4
		emitLeaf(path, "")
	} else {
		startp = p
		while (p <= n) {
			c = sc[p]
			if (c == "-" || c == "+" || c == "." || c == "e" || c == "E" || (c >= "0" && c <= "9")) p++
			else break
		}
		raw = ""
		for (rawPos = startp; rawPos < p; rawPos++) raw = raw sc[rawPos]
		emitLeaf(path, raw)
	}
}

## structErr on the fall-through arm: a container that ended on neither `,` nor
## its own closing bracket did not end, it ran out of input.
function parseObject(path,   key, keypath, c) {
	p++
	skipws()
	if (sc[p] == "}") { p++; return; }
	while (1) {
		skipws()
		key = parseString()
		skipws()
		p++
		keypath = (path == "") ? key : path "." key
		parseValue(keypath)
		skipws()
		c = sc[p]
		if (c == ",") { p++; continue; }
		else if (c == "}") { p++; break; }
		else { structErr = 1; break; }
	}
}

function parseArray(path,   idx, c) {
	p++
	skipws()
	idx = 0
	if (sc[p] == "]") { p++; return; }
	while (1) {
		parseValue(path "." idx)
		idx++
		skipws()
		c = sc[p]
		if (c == ",") { p++; continue; }
		else if (c == "]") { p++; break; }
		else { structErr = 1; break; }
	}
}

## Slurp, never parse per line: a pretty-printed body must parse exactly like
## a single-line one.
{
	if (inputSeen) input = input "\n" $0
	else input = $0
	inputSeen = 1
}

END {
	if (usageBad) exit 2

	s = input
	n = split(s, sc, "")
	p = 1

	skipws()
	if (p > n || sc[p] != "{") {
		printf("⛔ ERROR: AgentsAtlassianListRecords.awk: input is not a JSON object -- an empty read, an HTML error page, or a transport diagnostic captured in place of a response body (wanted array `%s`)\n", array) > "/dev/stderr"
		exit 1
	}

	parseValue("")
	skipws()

	if (structErr || p <= n) {
		printf("⛔ ERROR: AgentsAtlassianListRecords.awk: input did not parse as one complete JSON object -- truncated body or trailing garbage (wanted array `%s`)\n", array) > "/dev/stderr"
		exit 1
	}

	if (!arraySeen) {
		printf("⛔ ERROR: AgentsAtlassianListRecords.awk: no `%s` array in this response -- the result set is UNKNOWN, not empty. A real, empty `[]` sets this flag; only a missing or wrongly-typed field does not\n", array) > "/dev/stderr"
		exit 3
	}

	for (i = 0; i <= maxIdx; i++) {
		if (!(i in seenIdx)) continue
		line = ""
		for (w = 1; w <= wantCount; w++) {
			line = line (w == 1 ? "" : "\t") ((i SUBSEP w) in cell ? cell[i SUBSEP w] : "")
		}
		printf("%s\n", line)
	}
}
