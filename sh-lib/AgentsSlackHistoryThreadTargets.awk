#!/usr/bin/env awk

# Reads one raw Slack conversations.history JSON response on stdin and
# prints one <channel>:<parent-ts> target per parent message whose thread
# activity is worth a follow-up conversations.replies read.
#
# Selection rule (a parent message with reply_count > 0 is emitted when
# ANY of the following hold):
# - "fresh": if -v oldest=<ts> is provided, latest_reply is newer than oldest
#   (if oldest is empty, every thread-having parent counts as fresh)
# - "vane hit": -v vaneId=<user-or-bot-id> is provided (Vane's own resolved
#   Slack id) AND the parent message was posted by vaneId, OR vaneId appears
#   in the parent's own reply_users array (Vane already replied in this
#   thread), OR the parent's own text contains a literal "<@vaneId>" mention
#   (Vane was tagged in this thread's parent). A vane-hit bypasses the
#   freshness gate -- it exists to keep surfacing a thread Vane already
#   participated in / was tagged in even when its latest reply happens to
#   predate --oldest.
#
# This is intentionally a best-effort widening of the watched-channel sweep,
# not a global mention search: it only sees parent messages present in the
# current conversations.history page. Older untracked thread parents outside
# that page remain undiscoverable without a separate search-capable token/mech
# -- true workspace-wide "tagged anywhere" coverage needs a user token with
# search:read (not currently confirmed available) and is out of this file's
# reach regardless of the vaneId widening above.
#
# MULTI-DOCUMENT INPUT: a human-owner fan-out read (--intern-op-slack-check's
# own two-DM merge, --raw mode) concatenates TWO separate conversations.history
# responses on stdin, each preceded by its own "## dm=<id> identity=<name> ..."
# marker line -- one already present in that data, not added by this script.
# Every per-message array below is scoped to the CURRENT document and reset at
# each such marker (flushDoc/resetDoc) so a second document's message index 0
# can never silently overwrite the first's. A single-document input (every
# caller besides the human-owner fan-out) carries no marker at all, so the
# whole input stays one implicit document and behaves exactly as before.

BEGIN {
	msgCount = 0
	apiOk = "true"
	apiOkSeen = 0
	docChannel = channel
	linesSeen = 0
}

function resetDoc() {
	delete tsOf
	delete replyCountOf
	delete latestReplyOf
	delete userOf
	delete botIdOf
	delete textOf
	delete replyUsersOf
	msgCount = 0
	apiOk = "true"
	apiOkSeen = 0
	linesSeen = 0
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
	if (rest == idx ".user") { userOf[idx] = val; return }
	if (rest == idx ".bot_id") { botIdOf[idx] = val; return }
	if (rest == idx ".text") { textOf[idx] = val; return }
	if (index(rest, idx ".reply_users.") == 1) {
		replyUsersOf[idx] = (idx in replyUsersOf) ? replyUsersOf[idx] " " val : val
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

# DOCUMENT-BOUNDARY MARKER. Matched BEFORE the catch-all parse rule below --
# same ordering convention InternOpSessionContextScan.include's own
# commsCutoffTrimAwkProgram uses for its heading rule ("must precede the
# buffering rule, so a heading closes the PREVIOUS block and then lands in
# the new one"): a marker here closes the PREVIOUS document (flushDoc, which
# is a safe no-op if nothing has been accumulated yet -- see linesSeen below)
# and opens the new one.
#
# MATCHES MORE THAN THE ONE MARKER PER DOCUMENT, ON PURPOSE, NOT BY ACCIDENT:
# --intern-op-slack-check's own --raw fan-out output actually carries FOUR
# "## dm=" lines for a two-leg read, not two -- a provenance summary line
# per leg ("## dm=<id> ... status=ok"), printed before ANY blob content,
# followed by the inline marker immediately before each leg's own raw JSON
# ("## dm=<id> ... (this DM's own raw API response follows)"). Verified
# against the real emission order in AgentsTools.InternOpSlackCheck.include.
# Both shapes share the "## dm=<id>" prefix this rule matches, and the extra,
# earlier (provenance) matches are harmless: flushDoc()'s own linesSeen guard
# makes closing an empty/not-yet-started document a no-op, so the two
# provenance-line hits before any real content simply update docChannel and
# do nothing else, and the real flush only fires once actual message content
# has been parsed under that channel.
/^## dm=/ {
	flushDoc()
	resetDoc()
	docChannel = $0
	sub(/^## dm=/, "", docChannel)
	sub(/ .*/, "", docChannel)
	next
}

{ linesSeen++; s = $0; n = length(s); p = 1; parseValue("") }

# One call per document: from END for the only/last document, and from the
# marker rule above for every document before the last. `channel`, the
# externally-passed -v value, is untouched here -- it is BEGIN's own initial
# value for docChannel and stays authoritative for the entire input on any
# single-document (no marker) call, exactly reproducing prior behaviour.
function flushDoc(   i, ts, replyCount, latestReply, vaneHit) {
	# Nothing accumulated since the last reset (or since start) -- a
	# boundary marker with no real content behind it, never a document to
	# validate or report on. See the marker rule's own comment for why this
	# fires harmlessly on the provenance-line matches.
	if (linesSeen == 0) return

	if (apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: Slack API call failed: ok:false%s\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 1
	}
	# COULD-NOT-PARSE, distinct from "parsed fine, nothing to report".
	# Every real conversations.history response carries an `ok` key, so
	# reaching this point having seen no `ok` at all for THIS document means
	# the input was not the JSON this script parses -- a truncated body, an
	# HTML error page, an empty read. Without this, all three returned rc 0
	# with no output and were indistinguishable from a channel that simply
	# has no threads, which then propagated as a confident "no open
	# threads" upstream.
	#
	# `msgCount == 0` is required alongside it, not optional: the recogniser
	# must not fire on input that clearly DID parse. A response whose
	# messages array came through is parsed input by definition, so a
	# missing `ok` there is a Slack-side shape change to notice separately,
	# not a parse failure to abort on -- and aborting would throw away
	# messages already extracted.
	if (!apiOkSeen && msgCount == 0) {
		printf("⛔ ERROR: could not parse Slack conversations.history response: no `ok` key and no messages -- input was not a parseable API response (truncated body, error page, or empty read), not a channel with no threads\n") > "/dev/stderr"
		exit 1
	}
	for (i = 0; i < msgCount; i++) {
		ts = tsOf[i]
		replyCount = ((i in replyCountOf) ? replyCountOf[i] + 0 : 0)
		latestReply = ((i in latestReplyOf) ? latestReplyOf[i] + 0 : 0)
		if (ts == "" || replyCount <= 0) continue

		fresh = (oldest == "" || latestReply > (oldest + 0))

		vaneHit = 0
		if (vaneId != "") {
			if ((i in userOf) && userOf[i] == vaneId) vaneHit = 1
			if ((i in botIdOf) && botIdOf[i] == vaneId) vaneHit = 1
			if ((i in replyUsersOf) && index(" " replyUsersOf[i] " ", " " vaneId " ") > 0) vaneHit = 1
			if ((i in textOf) && index(textOf[i], "<@" vaneId ">") > 0) vaneHit = 1
		}

		if (!fresh && !vaneHit) continue
		print docChannel ":" ts
	}
}

END {
	flushDoc()
}