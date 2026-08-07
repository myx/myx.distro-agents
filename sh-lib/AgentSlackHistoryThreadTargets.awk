#!/usr/bin/env awk

# Reads one raw Slack conversations.history JSON response on stdin and
# prints one <channel>:<parent-ts> target per parent message whose thread
# activity is worth a follow-up conversations.replies read.
#
# Selection rule:
# - reply_count > 0
# - if -v oldest=<ts> is provided, latest_reply must be newer than oldest
#
# This is intentionally a best-effort widening of the watched-channel sweep,
# not a global mention search: it only sees parent messages present in the
# current conversations.history page. Older untracked thread parents outside
# that page remain undiscoverable without a separate search-capable token/mech.

BEGIN {
	msgCount = 0
	apiOk = "true"
	apiOkSeen = 0
}

function skipws(   c) {
	while (p <= n) {
		c = substr(s, p, 1)
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
	p++
	out = ""
	while (p <= n) {
		c = substr(s, p, 1)
		if (c == "\"") { p++; break; }
		if (c == "\\") {
			p++
			c = substr(s, p, 1)
			if (c == "\"") out = out "\""
			else if (c == "\\") out = out "\\"
			else if (c == "/") out = out "/"
			else if (c == "b") out = out "\b"
			else if (c == "f") out = out "\f"
			else if (c == "n") out = out "\n"
			else if (c == "r") out = out "\r"
			else if (c == "t") out = out "\t"
			else if (c == "u") {
				hex = substr(s, p + 1, 4)
				code = hex2dec(hex)
				p += 4
				if (code >= 55296 && code <= 56319 && substr(s, p + 1, 2) == "\\u") {
					hex2 = substr(s, p + 3, 4)
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

function emitLeaf(path, raw, val,   idx, rest) {
	if (path == "ok") { apiOk = val; apiOkSeen = 1; return }
	if (path == "error") { apiError = val; return }
	if (index(path, "messages.") != 1) return
	rest = substr(path, length("messages.") + 1)
	idx = rest
	sub(/\..*/, "", idx)
	if (idx !~ /^[0-9]+$/) return
	if (idx + 1 > msgCount) msgCount = idx + 1

	if (rest == idx ".ts") { tsOf[idx] = val; return }
	if (rest == idx ".reply_count") { replyCountOf[idx] = val; return }
	if (rest == idx ".latest_reply") { latestReplyOf[idx] = val; return }
}

function parseValue(path,   c, startp, val, raw) {
	skipws()
	c = substr(s, p, 1)
	if (c == "\"") {
		startp = p
		val = parseString()
		raw = substr(s, startp, p - startp)
		emitLeaf(path, raw, val)
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
			c = substr(s, p, 1)
			if (c == "-" || c == "+" || c == "." || c == "e" || c == "E" || (c >= "0" && c <= "9")) p++
			else break
		}
		raw = substr(s, startp, p - startp)
		emitLeaf(path, raw, raw)
	}
}

function parseObject(path,   key, keypath, c) {
	p++
	skipws()
	if (substr(s, p, 1) == "}") { p++; return }
	while (1) {
		skipws()
		key = parseString()
		skipws()
		p++
		keypath = (path == "") ? key : path "." key
		parseValue(keypath)
		skipws()
		c = substr(s, p, 1)
		if (c == ",") { p++; continue }
		else if (c == "}") { p++; break }
		else break
	}
}

function parseArray(path,   idx, c) {
	p++
	skipws()
	idx = 0
	if (substr(s, p, 1) == "]") { p++; return }
	while (1) {
		parseValue(path "." idx)
		idx++
		skipws()
		c = substr(s, p, 1)
		if (c == ",") { p++; continue }
		else if (c == "]") { p++; break }
		else break
	}
}

{ s = $0; n = length(s); p = 1; parseValue("") }

END {
	if (apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: Slack API call failed: ok:false%s\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 1
	}
	for (i = 0; i < msgCount; i++) {
		ts = tsOf[i]
		replyCount = ((i in replyCountOf) ? replyCountOf[i] + 0 : 0)
		latestReply = ((i in latestReplyOf) ? latestReplyOf[i] + 0 : 0)
		if (ts == "" || replyCount <= 0) continue
		if (oldest != "" && latestReply <= (oldest + 0)) continue
		print channel ":" ts
	}
}