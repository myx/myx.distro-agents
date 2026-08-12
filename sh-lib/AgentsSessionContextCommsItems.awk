#!/usr/bin/env awk

# Turns one comms API response (fed on stdin as a single line, run under
# LC_ALL=C for byte safety) into the session-context document's own per-item
# block shape:
#
#	## <type-name> <id>
#	<key>: <value>
#	...
#	<blank line>
#
# defined by magic-team/templates/session-context.document.format.md ("Every
# item block states its type name and id on its heading line").
#
# Selected by `-v kind=slack` or `-v kind=trello`; Slack additionally takes
# `-v source=<watched-target-name>` and `-v channel=<channel-id>` so each block
# can name where it came from. Email needs nothing here -- IMAP's UID SEARCH
# reply is a plain text line, not JSON, and is handled at its own call site.
#
# NOT the same job as AgentsSlackMessagesFormat.awk, which prints the human
# "ts | user | text" scan lines --intern-op-slack-check/--magic-sweep-input-scan
# emit. Both exist because the two consumers want genuinely different shapes:
# that one is read by a person scanning, this one is parsed as a document.
#
# EMPTY IS NOT THE SAME AS FAILED, and this file is where that distinction is
# actually enforced for these two services:
#   - Slack answers a failure with `"ok":false` inside a 200 body.
#   - Trello answers a failure with a plain-text line ("invalid key") and curl
#     still exits 0.
# Either would otherwise render exactly like "nothing new", which is the one
# confusion the whole session-context document exists to prevent. Both are
# reported on stderr and exit 1, so the caller reports "no scan was made"
# rather than a truthful-looking zero.
#
# Sorting: newest first, which is the order both APIs already return
# (conversations.history/replies and /members/me/notifications are both
# newest-first), so the emission order below is the natural index order and no
# sort step is needed.
#
# Parsing engine (skipws/hex2dec/utf8enc/parseString/parseValue/parseObject/
# parseArray) is copied verbatim from AgentsSlackMessagesFormat.awk in this same
# folder, which took it verbatim from myx.common's agentMcpJsonParseRequest.awk
# -- same recursive-descent JSON parser, only the leaf-emission logic differs.

BEGIN {
	itemCount = 0
	apiOk = "true"
	apiOkSeen = 0
	sawJsonRoot = 0
	if (kind != "slack" && kind != "trello") {
		printf("⛔ ERROR: AgentsSessionContextCommsItems.awk: -v kind= must be slack or trello, got: %s\n", kind) > "/dev/stderr"
		## `exit` in BEGIN still runs END, so END would otherwise add a second,
		## misleading "not JSON" error on top of this one.
		kindBad = 1
		exit 1
	}
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

## A document is one block per item and one `key: value` per line, so any
## embedded newline in a value would forge a new key line. Flattened to spaces
## at the single point every value passes through, never per-field.
function oneLine(v) {
	gsub(/[\n\r\t]/, " ", v)
	return v
}

function emitLeaf(path, raw, val,   rest, idx, after) {
	if (kind == "slack") {
		if (path == "ok") { apiOk = val; apiOkSeen = 1; return; }
		if (path == "error") { apiError = val; return; }
		if (index(path, "messages.") != 1) return
		rest = substr(path, length("messages.") + 1)
	} else {
		## Trello's notifications endpoint returns a bare top-level array, so
		## every path arrives as `.<idx>.<field>` -- strip that leading dot.
		rest = path
		sub(/^\./, "", rest)
	}

	idx = rest
	sub(/\..*/, "", idx)
	if (idx !~ /^[0-9]+$/) return
	if (idx + 1 > itemCount) itemCount = idx + 1
	if (index(rest, idx ".") != 1) return
	after = substr(rest, length(idx) + 2)

	if (kind == "slack") {
		if (after == "ts") { tsOf[idx] = val; return; }
		if (after == "user") { userOf[idx] = val; return; }
		if (after == "bot_id" && !(idx in userOf)) { userOf[idx] = val; return; }
		if (after == "text") { textOf[idx] = val; return; }
		if (after == "thread_ts") { threadTsOf[idx] = val; return; }
		if (after == "reply_count") { replyCountOf[idx] = val; return; }
		return
	}

	if (after == "id") { idOf[idx] = val; return; }
	if (after == "type") { typeOf[idx] = val; return; }
	if (after == "date") { dateOf[idx] = val; return; }
	if (after == "unread") { unreadOf[idx] = val; return; }
	if (after == "memberCreator.username") { fromOf[idx] = val; return; }
	if (after == "data.text") { textOf[idx] = val; return; }
	if (after == "data.card.name") { cardOf[idx] = val; return; }
	if (after == "data.board.name") { boardOf[idx] = val; return; }
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
		if (path == "") sawJsonRoot = 1
		parseObject(path)
	} else if (c == "[") {
		if (path == "") sawJsonRoot = 1
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

END {
	if (kindBad) exit 1
	if (!sawJsonRoot) {
		## Trello's own failure shape: a plain-text body ("invalid key",
		## "unauthorized permission requested") returned with curl exiting 0.
		printf("⛔ ERROR: AgentsSessionContextCommsItems.awk: %s response was not JSON -- treat as NOT SCANNED, never as empty\n", kind) > "/dev/stderr"
		exit 1
	}
	if (kind == "slack" && apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: AgentsSessionContextCommsItems.awk: Slack API call failed: ok:false%s -- treat as NOT SCANNED, never as empty\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 1
	}

	for (i = 0; i < itemCount; i++) {
		if (kind == "slack") {
			printf("## slack-message %s:%s\n", channel, tsOf[i])
			printf("source: %s\n", source)
			printf("channel: %s\n", channel)
			printf("ts: %s\n", tsOf[i])
			printf("user: %s\n", (i in userOf) ? userOf[i] : "?")
			if (i in threadTsOf) printf("thread-ts: %s\n", threadTsOf[i])
			if ((i in replyCountOf) && replyCountOf[i] + 0 > 0) printf("reply-count: %s\n", replyCountOf[i])
			printf("text: %s\n", oneLine(textOf[i]))
		} else {
			printf("## trello-notification %s\n", idOf[i])
			printf("type: %s\n", (i in typeOf) ? typeOf[i] : "?")
			printf("date: %s\n", (i in dateOf) ? dateOf[i] : "?")
			printf("unread: %s\n", (i in unreadOf) ? unreadOf[i] : "?")
			printf("from: %s\n", (i in fromOf) ? fromOf[i] : "?")
			if (i in boardOf) printf("board: %s\n", oneLine(boardOf[i]))
			if (i in cardOf) printf("card: %s\n", oneLine(cardOf[i]))
			if (i in textOf) printf("text: %s\n", oneLine(textOf[i]))
		}
		printf("\n")
	}
}
