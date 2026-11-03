#!/usr/bin/env awk

# Reads one raw Slack conversations.replies (or conversations.history) JSON
# response on stdin and prints back the SAME response narrowed to exactly one
# message: the element whose own `ts` equals -v wantTs=<ts>, byte-verbatim,
# re-wrapped as {"ok":true,"messages":[<that message object>]}.
#
# WHY THIS EXISTS. `conversations.history` does not return thread replies at
# all: asked for a reply's own ts it answers {"ok":true,"messages":[],...} --
# success, empty array -- and a caller reads that as "no reply yet" rather than
# "wrong endpoint for this question." `conversations.replies` answers for a
# parent ts, a reply ts AND a plain non-threaded ts alike (measured, all three
# against a real DM), so it is the endpoint that can actually see everything it
# was asked to see. The cost of that is that it returns the surrounding thread,
# not one message -- so a single-message read has to pick its own message back
# out of the thread, which is this file's whole job. Without it, moving the
# read onto the right endpoint would silently change the op's contract from
# "one message" to "a thread."
#
# THREE OUTCOMES, all distinguishable by exit status, never by an empty stdout:
#
#   rc 0 -- read-and-found. The requested ts is present in the response;
#           its message object is printed on stdout.
#   rc 1 -- read-but-absent. The response parsed, but no element carries the
#           requested ts. This is a COULD-NOT-READ, never "no messages": a
#           caller must not be able to conclude "nothing there" from a call
#           that could not have seen the thing it asked about.
#   rc 2 -- could-not-parse / ok:false. The input was not a usable API
#           response (truncated body, error page, empty read) or Slack itself
#           refused. Kept distinct from rc 1 so "the read worked and the
#           message is not there" never reads the same as "the read did not
#           work."
#
# Selection is an EXACT ts match, tested positively on presence of a matching
# element -- never a negation against an empty array. Both sides are forced to
# string comparison (the `x ""` concatenations below), because a ts like
# 1786361564.517149 is a strnum to awk and a numeric comparison would happily
# equate two distinct ts values that differ only past the float's precision.
#
# WHAT THE OUTPUT ENVELOPE IS, AND IS NOT. The message object is reproduced
# exactly as Slack sent it -- every field, reaction, block and attachment
# untouched, since it is a raw substring of the response, not a re-serialised
# copy. The envelope around it is synthesised, and deliberately carries only
# `ok` and `messages`: the response's own `has_more`/`response_metadata`
# describe the THREAD's pagination, and carrying them beside a single selected
# message would describe something the output no longer contains.
#
# Parsing engine (skipws/hex2dec/utf8enc/parseString/parseValue/parseObject/
# parseArray) is the same recursive-descent parser the sibling
# AgentsSlackMessagesFormat.awk / AgentsSlackHistoryThreadTargets.awk carry,
# itself copied from myx.common's agentMcpJsonParseRequest.awk -- only the
# emission logic differs (a raw object slice instead of formatted leaf fields).
# Reusing the family's own proven parser is the point: a "pick one JSON element"
# one-liner in sed/grep is exactly the fragile, dialect-dependent shape this
# file family has already been bitten by.
#
# Same single-line-response assumption every sibling in this family makes:
# Slack's API answers one JSON document on one line, and state accumulates
# across input lines rather than resetting per line.

BEGIN {
	msgCount = 0
	apiOk = "true"
	apiOkSeen = 0
	fatal = 0
	# The wanted ts is the whole question this script answers; without it there
	# is nothing to select, and selecting "the first one" would be a guess.
	if ((wantTs "") == "") {
		printf("⛔ ERROR: AgentsSlackMessageSelect.awk: -v wantTs=<ts> is required -- this script selects one message by its own exact ts and has nothing to select without one\n") > "/dev/stderr"
		fatal = 2
		exit 2
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

## Only three leaves matter here: the response's own `ok`/`error`, and each
## message's own `ts` -- everything else about a message travels in the raw
## slice captured by parseValue below, so there is nothing to accumulate for it.
function emitLeaf(path, raw, val,   idx, rest) {
	if (path == "ok") { apiOk = val; apiOkSeen = 1; return; }
	if (path == "error") { apiError = val; return; }
	if (index(path, "messages.") != 1) return
	rest = substr(path, length("messages.") + 1)
	idx = rest
	sub(/\..*/, "", idx)
	if (idx !~ /^[0-9]+$/) return
	if (idx + 1 > msgCount) msgCount = idx + 1
	if (rest == idx ".ts") { tsOf[idx] = val; return; }
}

## "" for anything that is not a direct element of the top-level messages
## array -- a nested object inside a message (a block, an attachment, a file)
## has a longer path and must NOT be captured as a message of its own.
function messageIndexOfPath(path,   rest) {
	if (index(path, "messages.") != 1) return ""
	rest = substr(path, length("messages.") + 1)
	if (rest !~ /^[0-9]+$/) return ""
	return rest
}

function parseValue(path,   c, startp, val, raw, msgIdx) {
	skipws()
	c = substr(s, p, 1)
	if (c == "\"") {
		startp = p
		val = parseString()
		raw = substr(s, startp, p - startp)
		emitLeaf(path, raw, val)
	} else if (c == "{") {
		## The raw slice is taken around the recursive parse, not reconstructed
		## after it: p is the parser's own cursor, so the object's exact byte
		## extent is [startp, p) once parseObject returns. That is what keeps the
		## selected message byte-identical to what Slack sent, rather than a
		## lossy re-serialisation of the fields this script happens to know.
		msgIdx = messageIndexOfPath(path)
		if (msgIdx != "") {
			startp = p
			parseObject(path)
			rawOf[msgIdx] = substr(s, startp, p - startp)
			if (msgIdx + 1 > msgCount) msgCount = msgIdx + 1
		} else {
			parseObject(path)
		}
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

END {
	## A BEGIN-time refusal must not be re-decided here by the outcome tests
	## below, which would all read "nothing parsed" and report the wrong reason.
	if (fatal != 0) exit fatal

	## Outcome rc 2, first half: Slack itself refused. The calling op already
	## turns ok:false into a failure of its own, so this is the second line of
	## defence rather than the only one -- but a script that printed a clean
	## "message not found" for an ok:false response would be reporting the wrong
	## fact, so it is tested here too.
	if (apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: AgentsSlackMessageSelect.awk: Slack API call failed: ok:false%s\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 2
	}

	## Outcome rc 2, second half: COULD-NOT-PARSE, distinct from "parsed fine,
	## the message is not in there." Every real API response carries an `ok`
	## key, so reaching here having seen no `ok` AND no messages means the input
	## was not the JSON this script parses. Both conditions are required: a
	## response whose messages array came through did parse by definition, and a
	## missing `ok` there is a Slack-side shape change to notice separately.
	if (!apiOkSeen && msgCount == 0) {
		printf("⛔ ERROR: AgentsSlackMessageSelect.awk: could not parse the Slack response: no `ok` key and no messages -- the input was not a parseable API response (truncated body, error page, or empty read), NOT a conversation with nothing in it\n") > "/dev/stderr"
		exit 2
	}

	## Outcome rc 0: read-and-found. A positive test for an element carrying the
	## requested ts -- the loop concludes only by finding one, never by finding
	## the array empty.
	for (i = 0; i < msgCount; i++) {
		if (!(i in rawOf)) continue
		if ((tsOf[i] "") != (wantTs "")) continue
		printf("{\"ok\":true,\"messages\":[%s]}\n", rawOf[i])
		exit 0
	}

	## Outcome rc 1: read-but-absent. Named with the ts that was actually asked
	## for, and with how many messages were seen instead, so the report can be
	## acted on without a second investigation.
	printf("⛔ ERROR: AgentsSlackMessageSelect.awk: COULD NOT READ message ts=%s -- the call succeeded and returned %d message(s), none of them carrying that ts. This is a failed read, NOT an empty conversation: nothing here supports concluding that the message does not exist.\n", wantTs, msgCount) > "/dev/stderr"
	exit 1
}
