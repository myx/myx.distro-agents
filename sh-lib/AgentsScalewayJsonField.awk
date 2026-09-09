#!/usr/bin/env awk

# Reads one Scaleway chat/completions JSON response (stdin, LC_ALL=C) and
# prints the scalar value at one exact dot-separated key path (`-v path=...`),
# same contract as AgentsSlackJsonField.awk in this same directory, whose
# parsing engine this is copied from verbatim (itself copied from
# AgentsSlackConversationCounterparty.awk, from AgentsSlackMessagesFormat.awk,
# from myx.common's agentMcpJsonParseRequest.awk -- the family's own
# propagation path for this engine). The one real difference: Scaleway's
# response carries no top-level `ok`, so there is no such gate here -- any
# complete, well-formed JSON object is a valid input.
#
# rc 0 found (value on stdout) -- rc 3 parsed fine, path absent -- rc 1 not a
# parseable JSON object at all -- rc 2 usage error (no path given).
#
# `-v optional=1` suppresses the rc-3 stderr note. `-v sentinel=1` emits
# `<value>X` with no record separator, for a free-text leaf (e.g. the final
# assistant message) whose own trailing newlines must survive `$( ... )`; the
# caller strips the one trailing `X`. See AgentsSlackJsonField.awk's own
# header for the full rationale on both.
#
# An array gets one extra synthetic leaf a plain field reader would not have:
# `<path>.__count`, the number of elements, emitted whether the array is
# empty or not (borrowed from AgentsMcpJsonParseRequest.awk's own parseArray
# in this same directory) -- this reader's own caller does not know in
# advance how many tool_calls a response carries, and needs to.
#
# LC_ALL=C IS REQUIRED -- the walk indexes a byte array from split(s, sc, ""),
# and split/length/substr count characters, not bytes, under a UTF-8 locale.

BEGIN {
	wantPath = path
	input = ""
	inputSeen = 0
	foundCount = 0
	foundValue = ""
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

function emitLeaf(path, raw, val) {
	if (path != wantPath) return
	if (foundCount == 0) foundValue = val
	foundCount++
}

function parseValue(path,   c, startp, val, raw, rawPos) {
	skipws()
	c = sc[p]
	if (c == "\"") {
		val = parseString()
		emitLeaf(path, "", val)
	} else if (c == "{") {
		parseObject(path)
	} else if (c == "[") {
		parseArray(path)
	} else if (c == "t") {
		p += 4
		emitLeaf(path, "true", "true")
	} else if (c == "f") {
		p += 5
		emitLeaf(path, "false", "false")
	} else if (c == "n") {
		p += 4
		emitLeaf(path, "null", "")
	} else {
		startp = p
		while (p <= n) {
			c = sc[p]
			if (c == "-" || c == "+" || c == "." || c == "e" || c == "E" || (c >= "0" && c <= "9")) p++
			else break
		}
		raw = ""
		for (rawPos = startp; rawPos < p; rawPos++) raw = raw sc[rawPos]
		emitLeaf(path, raw, raw)
	}
}

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
	if (sc[p] == "]") { p++; emitLeaf(path ".__count", idx, idx); return; }
	while (1) {
		parseValue(path "." idx)
		idx++
		skipws()
		c = sc[p]
		if (c == ",") { p++; continue; }
		else if (c == "]") { p++; break; }
		else { structErr = 1; break; }
	}
	emitLeaf(path ".__count", idx, idx)
}

{
	if (inputSeen) input = input "\n" $0
	else input = $0
	inputSeen = 1
}

END {
	if (wantPath == "") {
		printf("⛔ ERROR: AgentsScalewayJsonField.awk: no key path given -- pass one as `-v path=choices.0.message.content`\n") > "/dev/stderr"
		exit 2
	}

	s = input
	n = split(s, sc, "")
	p = 1

	skipws()
	if (p > n || sc[p] != "{") {
		printf("⛔ ERROR: AgentsScalewayJsonField.awk: input is not a JSON object -- an empty read, an HTML error page, or a transport diagnostic captured in place of a response body (wanted path `%s`)\n", wantPath) > "/dev/stderr"
		exit 1
	}

	parseValue("")
	skipws()

	if (structErr || p <= n) {
		printf("⛔ ERROR: AgentsScalewayJsonField.awk: input did not parse as one complete JSON object -- truncated body or trailing garbage (wanted path `%s`)\n", wantPath) > "/dev/stderr"
		exit 1
	}

	if (foundCount > 1) {
		printf("# AgentsScalewayJsonField.awk: path `%s` occurred %d times at that exact full path (duplicate key in one object, malformed JSON) -- reporting the first\n", wantPath, foundCount) > "/dev/stderr"
	}

	if (foundCount == 0) {
		if (optional != "1") {
			printf("# AgentsScalewayJsonField.awk: path `%s` is absent from this response (rc 3) -- not an empty value, not present\n", wantPath) > "/dev/stderr"
		}
		exit 3
	}

	if (sentinel == "1") {
		printf("%sX", foundValue)
	} else {
		print foundValue
	}
	exit 0
}
