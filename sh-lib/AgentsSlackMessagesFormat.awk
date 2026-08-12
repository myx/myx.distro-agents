#!/usr/bin/env awk

# Parses one single-line Slack conversations.history/conversations.replies
# JSON response (stdin, LC_ALL=C for byte safety) and prints one clean
# "ts | user | text" line per message to stdout.
#
# A message's `reactions` array and its `reply_count`/`latest_reply` fields
# sit directly on the message object in both APIs. When present they go on
# that message's HEAD line, BEFORE the text, as "[reactions: NAME xCOUNT
# (USERS)]" (one bracket per distinct reaction) and "[thread: N replies,
# latest at TS]". Before and not after because message text can carry an
# embedded newline: appended, the annotation stranded itself on a trailing
# physical line, where the fan-out tagger read it as a continuation. The
# thread annotation names no author -- conversations.history has no field
# naming the latest reply's author, and `reply_users` is not parsed at all.
#
# Lives here (myx.distro-agents/sh-lib, not myx.common) because it's
# Slack/DistroAgentsTools-specific: the only consumers are the two
# `--intern-op-slack-check` call sites in
# sh-lib/AgentsTools.InternOpSlackCheck.include (per-DM fan-out leg,
# single-conversation path). NOT --magic-sweep-input-scan, which never
# invokes this file -- that op feeds AgentsSessionContextCommsItems.awk.
#
# Parsing engine (skipws/hex2dec/utf8enc/parseString/parseValue/
# parseObject/parseArray) is copied verbatim from myx.common's
# agentMcpJsonParseRequest.awk; only the leaf-emission logic differs. Not a
# general-purpose formatter: only understands the flat messages[] array
# shape Slack's own API actually returns.

BEGIN { msgCount = 0; apiOk = "true"; apiOkSeen = 0; }

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
	p++ # skip opening quote
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

## Slack-specific: track ts/user/bot_id/text plus each message's own
## reactions[] array and reply_count/latest_reply fields, per
## message index; print in END once every field has been seen -- field
## order in Slack's real API responses isn't something to depend on.
function emitLeaf(path, raw, val,   idx, rest, afterIdx, afterReactions, j, afterJ, jNum) {
	if (path == "ok") { apiOk = val; apiOkSeen = 1; return; }
	if (path == "error") { apiError = val; return; }
	if (index(path, "messages.") != 1) return
	rest = substr(path, length("messages.") + 1)
	idx = rest
	sub(/\..*/, "", idx)
	if (idx !~ /^[0-9]+$/) return
	if (idx + 1 > msgCount) msgCount = idx + 1

	if (rest == idx ".ts") { tsOf[idx] = val; return; }
	if (rest == idx ".user") { userOf[idx] = val; return; }
	if (rest == idx ".bot_id" && !(idx in userOf)) { userOf[idx] = val; return; }
	if (rest == idx ".text") { textOf[idx] = val; return; }

	## Everything below is nested under messages.<idx>. -- pull off that
	## prefix once, then match the remaining sub-path.
	if (index(rest, idx ".") != 1) return
	afterIdx = substr(rest, length(idx) + 2)

	if (afterIdx == "reply_count") { replyCountOf[idx] = val; return; }
	if (afterIdx == "latest_reply") { latestReplyOf[idx] = val; return; }
	if (index(afterIdx, "reactions.") == 1) {
		afterReactions = substr(afterIdx, length("reactions.") + 1)
		j = afterReactions
		sub(/\..*/, "", j)
		if (j !~ /^[0-9]+$/) return
		jNum = j + 0
		if (!(idx in reactionCountPerMsg) || jNum + 1 > reactionCountPerMsg[idx]) reactionCountPerMsg[idx] = jNum + 1
		afterJ = substr(afterReactions, length(j) + 2)
		if (afterJ == "name") reactionNameOf[idx, j] = val
		else if (afterJ == "count") reactionCountOf[idx, j] = val
		else if (index(afterJ, "users.") == 1) {
			if ((idx, j) in reactionUsersOf) reactionUsersOf[idx, j] = reactionUsersOf[idx, j] "," val
			else reactionUsersOf[idx, j] = val
		}
		return
	}
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
	p++ # skip {
	skipws()
	if (substr(s, p, 1) == "}") { p++; return; }
	while (1) {
		skipws()
		key = parseString()
		skipws()
		p++ # skip :
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
	p++ # skip [
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

## Slack returns messages newest-first; print oldest-first (chronological)
## since that's what's actually useful to read. Reaction/thread
## annotations are appended to the same line, never a separate output line,
## so a "ts | user | text" parser downstream keeps working unchanged.
END {
	if (apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: Slack API call failed: ok:false%s\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 1
	}

	for (i = msgCount - 1; i >= 0; i--) {
		annotations = ""

		if (i in reactionCountPerMsg) {
			for (j = 0; j < reactionCountPerMsg[i]; j++) {
				rName = ((i, j) in reactionNameOf) ? reactionNameOf[i, j] : "?"
				rCount = ((i, j) in reactionCountOf) ? reactionCountOf[i, j] : "?"
				rUsers = ((i, j) in reactionUsersOf) ? reactionUsersOf[i, j] : "?"
				annotations = annotations sprintf(" [reactions: %s x%s (%s)]", rName, rCount, rUsers)
			}
		}

		if ((i in replyCountOf) && replyCountOf[i] + 0 > 0) {
			annotations = annotations sprintf(" [thread: %s replies, latest at %s]", \
				replyCountOf[i], (i in latestReplyOf ? latestReplyOf[i] : "?"))
		}

		print sprintf("%s | %s |%s %s", tsOf[i], (i in userOf ? userOf[i] : "?"), annotations, textOf[i])
	}
}
