#!/usr/bin/env awk

# Reads Slack "list" responses -- conversations.list, users.list -- fed on
# stdin, ONE JSON body per line (so a paged read concatenates its pages and
# this file handles them all in one pass), run under LC_ALL=C for byte safety.
# Emits one TAB-separated record per array element:
#
#   -v array=channels -v want=id,is_im,is_mpim,user
#   -v array=members  -v want=id,name,deleted,is_bot
#
# Fields come out in the order `want` names them, empty for a field this
# element does not carry. A field naming a nested path (`profile.real_name`)
# is matched by its full key path, never by its last segment.
#
# WHY A PARSER AND NOT A PATTERN. Same reason as its siblings in this
# directory, stated in full in AgentsSlackJsonField.awk: a conversations.list
# element carries `id` on the channel AND `id` inside `purpose`/`topic`
# creator blocks, `user` on a DM AND `user` on nested profile objects, and a
# BRE `.*` is greedy so every one of those reads the LAST occurrence. The
# payload is walked structurally and `channels.<idx>.user` matches because
# that is its path -- not because an anchor was lucky.
#
# EMPTY IS NOT THE SAME AS FAILED. A Slack `"ok":false` inside a 200 body, or
# a body that is not JSON at all, goes to stderr and exits 1 -- a caller must
# never read either as "this identity has no conversations".
#   rc 0 -- parsed; zero or more records on stdout.
#   rc 1 -- not a parseable Slack list response, or ok:false. Nothing usable.
#   rc 2 -- usage error (no `array` or no `want` given).
#
# LC_ALL=C IS REQUIRED, not advisory: `split(s, sc, "")` counts CHARACTERS
# rather than bytes under a UTF-8 locale, and dropping it parses emoji subtly
# wrong -- the same trap AgentsSessionContextCommsItems.awk documents, whose
# recursive-descent engine (skipws/hex2dec/utf8enc/parseString/parseValue/
# parseObject/parseArray) is copied here verbatim; only emitLeaf differs.

BEGIN {
	apiOk = "true"
	apiOkSeen = 0
	sawJsonRoot = 0
	maxIdx = -1
	if (array == "" || want == "") {
		printf("⛔ ERROR: AgentsSlackListRecords.awk: -v array=<name> and -v want=<csv> are both required\n") > "/dev/stderr"
		usageBad = 1
		exit 2
	}
	wantCount = split(want, wantName, ",")
	for (w = 1; w <= wantCount; w++) { wantAt[wantName[w]] = w ; }
	prefix = array "."
	prefixLen = length(prefix)
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

function parseString(   c, out, hex, code, hex2, code2, cp) {
	p++ # skip opening quote
	out = ""
	while (p <= n) {
		c = sc[p]
		if (c == "\"") { p++; break; }
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
	return out
}

## One record per line: an embedded tab or newline in a value would forge a field.
function oneField(v) {
	gsub(/[\n\r\t]/, " ", v)
	return v
}

function emitLeaf(path, val,   rest, idx, after) {
	if (path == "ok") { apiOk = val; apiOkSeen = 1; return; }
	if (path == "error") { apiError = val; return; }
	if (index(path, prefix) != 1) return
	rest = substr(path, prefixLen + 1)

	idx = rest
	sub(/\..*/, "", idx)
	if (idx !~ /^[0-9]+$/) return
	if (index(rest, idx ".") != 1) return
	after = substr(rest, length(idx) + 2)
	if (!(after in wantAt)) return

	## Element indices restart at 0 on every page, so a second page's element 0
	## must not overwrite a first page's. `pageBase` shifts each page's block
	## past the previous one; it is advanced per input line, below.
	idx = pageBase + idx
	if (idx > maxIdx) maxIdx = idx
	seenIdx[idx] = 1
	cell[idx SUBSEP wantAt[after]] = oneField(val)
}

function parseValue(path,   c, startp, val, raw, rawPos) {
	skipws()
	c = sc[p]
	if (c == "\"") {
		val = parseString()
		emitLeaf(path, val)
	} else if (c == "{") {
		if (path == "") sawJsonRoot = 1
		parseObject(path)
	} else if (c == "[") {
		if (path == "") sawJsonRoot = 1
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

function parseObject(path,   key, keypath, c) {
	p++ # skip {
	skipws()
	if (sc[p] == "}") { p++; return; }
	while (1) {
		skipws()
		key = parseString()
		skipws()
		p++ # skip :
		keypath = (path == "") ? key : path "." key
		parseValue(keypath)
		skipws()
		c = sc[p]
		if (c == ",") { p++; continue; }
		else if (c == "}") { p++; break; }
		else break
	}
}

function parseArray(path,   idx, c) {
	p++ # skip [
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
		else break
	}
}

## A page marker written by a paged caller. Not JSON, so it must not reach the
## parser; it carries no data this file needs either.
/^## / { next ; }

## One split, then sc[p] per byte: substr() per call makes the walk quadratic.
{
	pageBase = maxIdx + 1
	s = $0; n = split(s, sc, ""); p = 1; parseValue("");
}

END {
	if (usageBad) exit 2
	if (!sawJsonRoot) {
		printf("⛔ ERROR: AgentsSlackListRecords.awk: the %s response was not JSON -- treat as NOT ENUMERATED, never as empty\n", array) > "/dev/stderr"
		exit 1
	}
	if (apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: AgentsSlackListRecords.awk: Slack API call failed: ok:false%s -- treat as NOT ENUMERATED, never as empty\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 1
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
