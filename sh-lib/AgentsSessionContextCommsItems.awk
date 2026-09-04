#!/usr/bin/env awk

# Turns one comms API response (stdin, one line, LC_ALL=C) into the
# session-context document's own per-item block shape, defined by
# magic-team/templates/session-context.document.format.md.
#
# `-v kind=slack|trello`; Slack additionally takes `-v source=<watched-target-name>`
# and `-v channel=<channel-id>`.
#
# EMPTY IS NOT THE SAME AS FAILED: a Slack `"ok":false` inside a 200 body, or a
# Trello plain-text error line with curl still exiting 0, goes to stderr and exits 1.
#
# LC_ALL=C IS REQUIRED, not advisory: `split(s, sc, "")` counts CHARACTERS rather
# than bytes under a UTF-8 locale, and dropping it parses emoji subtly wrong.

BEGIN {
	itemCount = 0
	apiOk = "true"
	apiOkSeen = 0
	sawJsonRoot = 0
	legChannel = channel
	legIdentity = ""
	if (kind != "slack" && kind != "trello") {
		printf("⛔ ERROR: AgentsSessionContextCommsItems.awk: -v kind= must be slack or trello, got: %s\n", kind) > "/dev/stderr"
		## `exit` in BEGIN still runs END, which would otherwise add a second error.
		kindBad = 1
		exit 1
	}
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

## One `key: value` per line: an embedded newline in a value would forge a key line.
function oneLine(v) {
	gsub(/[\n\r\t]/, " ", v)
	return v
}

## A raw `U…` beside the handle it belongs to, when the caller supplied a map.
## The id STAYS and the handle is ADDED, never substituted: a reader needs the
## name, and every follow-up call in this family is addressed by the id, so
## dropping either one costs the other. An id the map does not carry is printed
## exactly as before -- unnamed, never blank.
##
## The map travels in the ENVIRONMENT, not through `-v`: one-true-awk rejects a
## newline inside a `-v` assigned value outright ("awk: newline in string ... at
## source line 1", measured in this package), and this map is one entry per
## line. `-v` would separately backslash-decode what it carried.
function whoIs(id,   raw, nl, i, f) {
	if (!handlesLoaded) {
		handlesLoaded = 1
		raw = ENVIRON["COMMS_USER_HANDLES"]
		nl = split(raw, hl, "\n")
		for (i = 1; i <= nl; i++) {
			if (hl[i] == "") continue
			split(hl[i], f, "\t")
			if (f[1] != "" && f[2] != "") handleOf[f[1]] = f[2]
		}
	}
	if (id == "") return "?"
	if (id in handleOf) return id " (" handleOf[id] ")"
	return id
}

## Prints the CURRENT leg under its own legChannel; resetLeg() is the separate reset.
function flushLeg(   i) {
	if (itemCount == 0) return
	for (i = 0; i < itemCount; i++) {
		printf("## slack-message %s:%s\n", legChannel, tsOf[i])
		printf("source: %s\n", source)
		printf("channel: %s\n", legChannel)
		if (legIdentity != "") printf("identity: %s\n", legIdentity)
		printf("ts: %s\n", tsOf[i])
		printf("user: %s\n", (i in userOf) ? whoIs(userOf[i]) : "?")
		if (i in threadTsOf) printf("thread-ts: %s\n", threadTsOf[i])
		if ((i in replyCountOf) && replyCountOf[i] + 0 > 0) printf("reply-count: %s\n", replyCountOf[i])
		printf("text: %s\n", oneLine(textOf[i]))
		printf("\n")
	}
}

function resetLeg() {
	delete tsOf
	delete userOf
	delete textOf
	delete threadTsOf
	delete replyCountOf
	itemCount = 0
}

function emitLeaf(path, raw, val,   rest, idx, after) {
	if (kind == "slack") {
		if (path == "ok") { apiOk = val; apiOkSeen = 1; return; }
		if (path == "error") { apiError = val; return; }
		if (index(path, "messages.") != 1) return
		rest = substr(path, length("messages.") + 1)
	} else {
		## Trello returns a bare top-level array, so every path arrives as `.<idx>.<field>`.
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

function parseValue(path,   c, startp, val, raw, rawPos) {
	skipws()
	c = sc[p]
	if (c == "\"") {
		val = parseString()
		emitLeaf(path, "", val)
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

## LEG-BOUNDARY MARKER (Slack only), matched BEFORE the catch-all parse rule below:
## flushes the previous leg under ITS OWN channel id, resets, opens the new leg.
## More than one marker per leg is expected; flushLeg()'s itemCount guard makes the
## extra hits update legChannel and nothing else.
kind == "slack" && /^## dm=/ {
	flushLeg()
	resetLeg()
	legChannel = $0
	sub(/^## dm=/, "", legChannel)
	sub(/ .*/, "", legChannel)
	## `identity=<user|bot>` on the marker line is optional; absent leaves this "".
	legIdentity = $0
	if (legIdentity ~ /identity=/) {
		sub(/^.*identity=/, "", legIdentity)
		sub(/ .*/, "", legIdentity)
	} else {
		legIdentity = ""
	}
	next
}

## One split, then sc[p] per byte: substr() per call makes the walk quadratic.
{ s = $0; n = split(s, sc, ""); p = 1; parseValue(""); }

END {
	if (kindBad) exit 1
	if (!sawJsonRoot) {
		## Trello's own failure shape: a plain-text body with curl exiting 0.
		printf("⛔ ERROR: AgentsSessionContextCommsItems.awk: %s response was not JSON -- treat as NOT SCANNED, never as empty\n", kind) > "/dev/stderr"
		exit 1
	}
	if (kind == "slack" && apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: AgentsSessionContextCommsItems.awk: Slack API call failed: ok:false%s -- treat as NOT SCANNED, never as empty\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 1
	}

	if (kind == "slack") {
		flushLeg()
	} else {
		## OLDEST FIRST. Trello's notifications endpoint returns newest-first, so
		## the array is walked BACKWARDS here -- every list an input-scan returns is
		## ordered oldest to newest, and a source's own ordering is not the
		## document's. The Slack path above reaches the same order by sorting on
		## `ts`; Trello carries no comparable key on every notification, so its own
		## documented ordering is reversed rather than a key invented for it.
		for (i = itemCount - 1; i >= 0; i--) {
			printf("## trello-notification %s\n", idOf[i])
			printf("type: %s\n", (i in typeOf) ? typeOf[i] : "?")
			printf("date: %s\n", (i in dateOf) ? dateOf[i] : "?")
			printf("unread: %s\n", (i in unreadOf) ? unreadOf[i] : "?")
			printf("from: %s\n", (i in fromOf) ? fromOf[i] : "?")
			if (i in boardOf) printf("board: %s\n", oneLine(boardOf[i]))
			if (i in cardOf) printf("card: %s\n", oneLine(cardOf[i]))
			if (i in textOf) printf("text: %s\n", oneLine(textOf[i]))
			printf("\n")
		}
	}
}
