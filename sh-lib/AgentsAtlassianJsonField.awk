#!/usr/bin/env awk

# Reads one Atlassian Cloud JSON response (fed on stdin, run under LC_ALL=C for
# byte safety) and prints the scalar value sitting at ONE exact, fully
# qualified key path -- given as `-v path=isLast` -- and nothing else. The
# Atlassian sibling of AgentsSlackJsonField.awk, one per product segment.
#
# WHY A SIBLING RATHER THAN THE SLACK READER. That file requires a top-level
# `ok` key and refuses any body without one, which is correct for Slack and
# rejects every Atlassian response. Generalising it would mean editing a proven
# file to serve a new feature, so it is left exactly as it stands.
#
# WHAT THIS FILE CANNOT DO THAT ITS SLACK SIBLING CAN, stated because the
# difference is a real weakening and must not be discovered later. Slack's `ok`
# separates "not an API response at all" from "the field is absent". Atlassian
# has no universal top-level key, so that discriminator does not exist here:
# validation stops at "this parsed as one complete JSON object". rc 1 therefore
# means unparseable, not un-Atlassian, and rc 3 means absent from a body that
# parsed rather than absent from a body confirmed to be a response. A caller
# that needs more reads the HTTP status, which the transport already classifies.
#
# Exit: 0 found and printed, 1 input is not one complete JSON object,
#       2 no key path given, 3 the path is absent.
#
#   -v path=...      Full path, dot-separated. Array elements are addressed by
#                    index, e.g. `values.0.name`. Only scalar leaves are
#                    addressable: naming an object or an array yields rc 3.
#   -v optional=1    Declares that absence is an expected state at this call
#                    site, and suppresses the rc-3 stderr note. Purely about
#                    the note; rc 3 is returned either way.
#   -v raw=1         The value at `path` is itself a JSON object/array (an ADF
#                    document body, e.g.) rather than a scalar. Captured as its
#                    exact source bytes, verbatim, instead of the rc-3 this
#                    file otherwise gives an object/array leaf -- a caller
#                    that needs it structured parses that text itself.
#   -v sentinel=1    Emits `<value>X` with no record separator, so the value's
#                    own trailing newlines survive the caller's `$( ... )`.
#                    The caller strips the one trailing `X`.
#
# The whole input is slurped and parsed once, NOT line by line, so a
# pretty-printed body parses exactly like a single-line one. Nothing here may
# be replaced by a line-oriented shortcut such as `head -1`: picking the first
# line, or the first match on a line, is the same class of accident as picking
# the last match -- correct only while the body happens to be formatted the way
# it is formatted this week.
#
# Parsing engine (skipws/hex2dec/utf8enc/parseString/parseValue/parseObject/
# parseArray) is copied verbatim from AgentsSlackJsonField.awk in this same
# directory, which took it from AgentsSlackConversationCounterparty.awk, which
# took it from AgentsSlackMessagesFormat.awk, which took it from myx.common's
# agentMcpJsonParseRequest.awk -- same recursive-descent JSON parser, only the
# leaf-emission and the validation gate differ.
#
# LC_ALL=C IS REQUIRED, not advisory. The walk below indexes a byte array built
# by `split(s, sc, "")`, and `split`/`length`/`substr` count CHARACTERS rather
# than bytes under a UTF-8 locale. Every call site already sets it. Dropping it
# does not fail -- it parses emoji and accented text subtly wrong.

BEGIN {
	## `-v path=...` is the caller-facing spelling, but `path` is also the
	## parameter name every parse function uses, and an awk parameter shadows
	## the global of the same name inside that function -- emitLeaf could never
	## see it. Copied once here, in BEGIN, which is not a function and therefore
	## does see the global. Compare against `wantPath` everywhere below.
	wantPath = path
	wantRaw = (raw == "1")

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

## An unclosed string (input ran out before the closing quote) sets structErr,
## so a body truncated mid-value is reported as unparseable instead of silently
## yielding whatever prefix survived.
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

## Full-path EQUALITY only -- never a prefix or substring test. `values.0.id` is
## the first value's own `id`; `id` and `values.1.id` are different paths and
## fall through untouched, which is the entire point of parsing rather than
## matching.
function emitLeaf(path, raw, val) {
	if (path != wantPath) return
	## First occurrence wins, and a second one is reported rather than quietly
	## preferred either way: two leaves at one identical full path means the
	## object carried a duplicate key, which is malformed JSON and worth seeing
	## in the log rather than resolving by a coin toss.
	if (foundCount == 0) foundValue = val
	foundCount++
}

## Advances p past one balanced {...} or [...], skipping over string content
## (via parseString, so a brace inside a string never miscounts) rather than
## walking it into named leaves -- raw mode wants these bytes verbatim.
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

function parseValue(path,   c, startp, val, raw, rawPos) {
	skipws()
	c = sc[p]
	if (path == wantPath && wantRaw && (c == "{" || c == "[")) {
		startp = p
		skipBalanced()
		raw = ""
		for (rawPos = startp; rawPos < p; rawPos++) raw = raw sc[rawPos]
		emitLeaf(path, raw, raw)
		return
	}
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

## Slurp, never parse per line -- see the pretty-printing note in the header.
{
	if (inputSeen) input = input "\n" $0
	else input = $0
	inputSeen = 1
}

END {
	if (wantPath == "") {
		printf("⛔ ERROR: AgentsAtlassianJsonField.awk: no key path given -- pass one as `-v path=isLast`\n") > "/dev/stderr"
		exit 2
	}

	s = input
	## One split, then sc[p] per byte: substr(s, p, 1) costs a strlen of the
	## whole payload per call in one-true-awk, which makes the walk quadratic.
	n = split(s, sc, "")
	p = 1

	## rc 1, the not-a-response state, decided BEFORE anything is parsed: an
	## empty read and an HTML error page both fail here, and neither may be
	## allowed to look like "the field is absent".
	skipws()
	if (p > n || sc[p] != "{") {
		printf("⛔ ERROR: AgentsAtlassianJsonField.awk: input is not a JSON object -- an empty read, an HTML error page, or a transport diagnostic captured in place of a response body (wanted path `%s`)\n", wantPath) > "/dev/stderr"
		exit 1
	}

	parseValue("")
	skipws()

	## Truncated mid-body, or a second document glued after the first. Either
	## way the thing parsed is not the response it claims to be.
	if (structErr || p <= n) {
		printf("⛔ ERROR: AgentsAtlassianJsonField.awk: input did not parse as one complete JSON object -- truncated body or trailing garbage (wanted path `%s`)\n", wantPath) > "/dev/stderr"
		exit 1
	}

	if (foundCount > 1) {
		printf("# AgentsAtlassianJsonField.awk: path `%s` occurred %d times at that exact full path (duplicate key in one object, malformed JSON) -- reporting the first\n", wantPath, foundCount) > "/dev/stderr"
	}

	if (foundCount == 0) {
		if (optional != "1") {
			printf("# AgentsAtlassianJsonField.awk: path `%s` is absent from this response (rc 3) -- not an empty value, not present\n", wantPath) > "/dev/stderr"
		}
		exit 3
	}

	## `printf`, never `print`, in sentinel mode: `print` would append OFS/ORS
	## and reintroduce the very separator this mode exists to remove.
	if (sentinel == "1") {
		printf("%sX", foundValue)
	} else {
		print foundValue
	}
	exit 0
}
