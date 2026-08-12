#!/usr/bin/env awk

# Reads one single-line Slack conversations.info JSON response (fed on
# stdin, run under LC_ALL=C for byte safety) and prints the conversation's
# OWN counterparty -- the `channel.user` field of a DM -- and nothing else.
# Exactly one line of output for a DM, zero lines for anything that has no
# single counterparty (a public/private channel, an mpim).
#
# WHY THIS FILE EXISTS AT ALL, i.e. why the counterparty is parsed and not
# pattern-matched. The control in AgentsTools.InternOpSlackCall.include used
# to read the counterparty with
#     sed -n 's/.*"user":"\([UW][^"]*\)".*/\1/p' | head -1
# and that is wrong by construction: BRE `.*` is greedy, so the leading
# `.*` eats as much as it can and the capture lands on the LAST
# `"user":"..."` in the payload, not the channel's own one. A real
# conversations.info body for a DM carries several of them --
#     {"ok":true,"channel":{"id":"D...","user":"<the counterparty>",
#       "latest":{"user":"<whoever spoke last>",
#         "bot_profile":{"user_id":"<the app's own user>"}}}}
# -- so the control was reporting the most recent speaker, or a bot profile,
# instead of the party the conversation is with.
#
# It passed its own verification anyway, by coincidence: at the time it was
# first checked, the newest message in that DM happened to be from the very
# party the control expected, so the last `"user"` incidentally equalled the
# expected one. The check was real; the mechanism underneath it had never
# once read the counterparty. Every green that control produced before the
# fix is unproven, not evidence.
#
# There is deliberately NO cleverer regex here. `sed` has no non-greedy
# quantifier in BRE, and the GNU-only constructs that could fake one (`\|`
# alternation, PCRE `.*?`) are exactly what this family forbids for
# Darwin/FreeBSD/Linux parity -- a greedy/non-greedy fight in a BRE is how
# this bug happened in the first place. The payload is therefore parsed
# structurally, by full key path, so `channel.user` is the only thing that
# can ever match: `channel.latest.user` and
# `channel.latest.bot_profile.user_id` are different paths and are ignored
# by construction, not by anchoring luck. Do not "simplify" this back into a
# one-liner.
#
# Parsing engine (skipws/hex2dec/utf8enc/parseString/parseValue/
# parseObject/parseArray) is copied verbatim from AgentsSlackMessagesFormat.awk
# in this same directory (which in turn copied it from myx.common's
# agentMcpJsonParseRequest.awk) -- same recursive-descent JSON parser, only
# the leaf-emission logic differs.

BEGIN {
	apiOk = "true"
	apiOkSeen = 0
	channelSeen = 0
	isIm = ""
	counterparty = ""
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

## Full-path equality only -- never a substring/prefix test. `channel.user`
## is the channel object's own field; `channel.latest.user` and
## `channel.latest.bot_profile.user_id` are other paths entirely and fall
## through untouched, which is the whole point of parsing rather than
## matching. Fields are recorded here and judged in END: Slack's own field
## order is not something to depend on, so `is_im` may well arrive after
## `user`.
function emitLeaf(path, raw, val) {
	if (path == "ok") { apiOk = val; apiOkSeen = 1; return; }
	if (path == "error") { apiError = val; return; }
	if (path == "channel.id") { channelSeen = 1; return; }
	if (path == "channel.is_im") { isIm = val; return; }
	if (path == "channel.user") { counterparty = val; return; }
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
	if (substr(s, p, 1) == "}") { p++; return; }
	while (1) {
		skipws()
		key = parseString()
		skipws()
		p++
		keypath = (path == "") ? key : path "." key
		parseValue(keypath)
		skipws()
		c = substr(s, p, 1)
		if (c == ",") { p++; continue; }
		else if (c == "}") { p++; break; }
		else break
	}
}

function parseArray(path,   idx, c) {
	p++
	skipws()
	idx = 0
	if (substr(s, p, 1) == "]") { p++; return; }
	while (1) {
		parseValue(path "." idx)
		idx++
		skipws()
		c = substr(s, p, 1)
		if (c == ",") { p++; continue; }
		else if (c == "]") { p++; break; }
		else break
	}
}

{ s = $0; n = length(s); p = 1; parseValue(""); }

END {
	if (apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: Slack API call failed: ok:false%s\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 1
	}
	# COULD-NOT-PARSE, distinct from "parsed fine, no counterparty to
	# report". Every real conversations.info response carries an `ok` key
	# and a channel object, so reaching END with neither means the input
	# was not the JSON this script parses -- a truncated body, an HTML
	# error page, an empty read. Without this, all three would print
	# nothing and be indistinguishable from a channel that legitimately
	# has no single counterparty.
	if (!apiOkSeen && !channelSeen) {
		printf("⛔ ERROR: could not parse Slack conversations.info response: no `ok` key and no channel object -- input was not a parseable API response (truncated body, error page, or empty read), not a conversation without a counterparty\n") > "/dev/stderr"
		exit 1
	}

	# Positive tests on presence, both of them: a DM says so with
	# is_im:true AND carries the party in channel.user. A conversation
	# missing either one prints nothing at all, which is what the caller
	# renders as "no single counterparty" -- never a guess drawn from
	# somewhere else in the payload.
	if (isIm == "true" && counterparty != "") print counterparty
}
