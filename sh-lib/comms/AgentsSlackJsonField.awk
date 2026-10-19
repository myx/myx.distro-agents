#!/usr/bin/env awk

# Reads one Slack Web API JSON response (fed on stdin, run under LC_ALL=C for
# byte safety) and prints the scalar value sitting at ONE exact, fully
# qualified key path -- given as `-v path=channel.id` -- and nothing else.
# Generic by design: it is the single field reader every Slack response site
# in this package uses, instead of one bespoke `sed` expression per field.
#
# WHY THIS FILE EXISTS AT ALL, i.e. why a Slack field is parsed and not
# pattern-matched. Every site this file replaced was written as
#     sed -n 's/.*"user_id":"\([^"]*\)".*/\1/p'
# and every one of them is wrong by construction rather than by accident: BRE
# `.*` is greedy, so the leading `.*` eats as far as it can and the capture
# lands on the LAST occurrence of that key anywhere in the payload -- at any
# depth, inside any nested object, in any array element. Each of those
# expressions was written as if the key occurred exactly once. They were
# correct only while the payload happened to contain a single instance of it:
# a property of the response shape Slack returns today, never documented,
# never enforced, and never checked by the code relying on it.
#
# That is not a hypothetical. A `chat.postMessage` response carries
# `message.user`, `message.bot_profile.user_id` and more; a
# `conversations.info` body carries the channel's own `name` plus a `name` on
# every nested profile-ish object it feels like including. The counterparty
# control that started this cleanup read the last `"user"` in a
# conversations.info body for months and passed verification three times by
# coincidence, because the newest message in that DM happened to be from the
# very party it expected. The check was real; the mechanism underneath it had
# never once read the field it claimed to read.
#
# There is deliberately NO cleverer regex here, and the fix is not a better
# pattern -- it is not a pattern at all. `sed` has no non-greedy quantifier in
# BRE, and the GNU-only constructs that could fake one are exactly what this
# family forbids for Darwin/FreeBSD/Linux parity: `\|` alternation is a GNU
# basic-regex extension BSD sed does not honour, so on Darwin an expression
# leaning on it matches nothing, yields the empty string, and reports a
# perfectly good response as a refusal -- caught live in this package against
# a real `ok:true,no_op:true` reply. A greedy/non-greedy fight in a BRE is how
# the counterparty bug happened, and a portability fight in a BRE is how the
# ok-test bug happened. Structural parsing has neither failure mode: the
# payload is walked, and `channel.id` matches the channel object's own `id`
# because that is its path, not because a pattern anchored luckily.
#
# CONTRACT -- three states, told apart by exit status, never by inspecting the
# printed string. An empty stdout is NOT a synonym for "not there": a JSON
# `null`, and a key genuinely holding `""`, are both PRESENT and both print
# nothing.
#   rc 0  -- found. The value is on stdout, one line, unquoted and unescaped.
#   rc 3  -- parsed fine, that path is not in this payload. Nothing on stdout.
#            The normal, expected state for an optional field (`error` on a
#            successful call). A caller must test rc, positively, and must
#            never pass the empty string onward as if it were a value: an
#            absent id flowing into a channel argument is exactly how the
#            outage behind this cleanup happened.
#   rc 1  -- the input is not a parseable Slack API response at all: empty
#            read, truncated body, an HTML error page, curl's own diagnostics
#            captured in place of a body. Says so on stderr.
#   rc 2  -- usage error (no `path` given). Says so on stderr.
#
# A VALUE'S OWN TRAILING NEWLINE, and the mode that preserves it. In the default
# output shape it does not survive the usual call site: `print` terminates the
# value with a record separator of its own, and `$( ... )` strips every trailing
# newline it finds without being able to tell the value's from the separator's.
# So a value of "abc" and a value of "abc\n" both come back as `abc` -- read as
# the same string, with the second handed on one byte short, and (at a caller
# that classifies by looking for a newline) reported as single-line when it is
# not. INTERIOR newlines were never affected and arrive intact in both modes.
#
# This was previously documented here as unfixable-in-this-file, on the grounds
# that the loss happens in the CALLER's command substitution. That reasoning was
# half right: the loss does happen there, but the cause is the separator THIS
# script adds, which makes the value's own last byte indistinguishable from it.
# Removing that ambiguity is this file's job after all.
#
#   -v sentinel=1  emits `<value>X` -- the value, then one literal `X`, and NO
#                  record separator at all. `$( ... )` then has no trailing
#                  newline of ours to strip and no reason to strip the value's,
#                  because `X` is the last byte. The caller removes exactly that
#                  one byte:
#                      value="$( awk -v sentinel=1 ... )" ; value="${value%X}"
#                  and what remains is the value byte-for-byte, trailing
#                  newlines included.
#
# It is OPT-IN rather than the new default purely for blast radius: every
# existing call site reads a field that cannot end in a newline (ids,
# timestamps, mimetypes, URLs) and is correct as written, and a mode switch that
# silently appended a byte to all of them would be the kind of change this
# package spends its sessions removing. A call site reading FREE TEXT -- a
# filename, a title, a message body -- passes `sentinel=1`; one that reads an id
# does not need to.
#
# `X` specifically, and not a NUL or a control byte: a shell variable cannot
# hold a NUL at all, and `${value%X}` is a POSIX suffix removal that needs no
# subprocess. That the value itself may also end in `X` is harmless -- exactly
# one byte is removed, and it is the one this script appended.
#
# Options:
#   -v path=<a.b.c>  REQUIRED. The full key path, dot-separated, matched by
#                    EQUALITY and never as a prefix or a substring. Array
#                    elements are addressed by index, e.g. `messages.0.text`.
#                    Only scalar leaves are addressable: naming an object or
#                    an array (`-v path=channel`) yields rc 3, since there is
#                    no scalar there to print.
#   -v optional=1    Declares that absence is an expected state at this call
#                    site, and suppresses the rc-3 stderr note. Purely about
#                    the note; rc 3 is returned either way. Set it where the
#                    field is genuinely optional (`error`), leave it unset
#                    where absence is a fault the log should show.
#   -v sentinel=1    Emits `<value>X` with no record separator, so the value's
#                    own trailing newlines survive the caller's `$( ... )`.
#                    The caller strips the one trailing `X`. See the
#                    trailing-newline section above. Affects the found (rc 0)
#                    output only -- rc 1/2/3 print nothing on stdout either way.
#
# The whole input is slurped and parsed once, NOT line by line, so a
# pretty-printed body parses exactly like the single-line one Slack sends
# today. Nothing in this file may be replaced by a line-oriented shortcut such
# as `head -1`: picking the first line, or the first match on a line, is the
# same class of accident as picking the last match -- correct only while the
# body happens to be formatted the way it is formatted this week.
#
# `ok` is required at the top level. Every Slack Web API response carries it,
# so its absence means the input was not one -- that check is what separates
# rc 1 from rc 3, and without it a garbage body would be indistinguishable
# from a payload that simply lacks the wanted field. Note that `ok:false` is
# NOT an error here: reading `error` out of a failed response is one of this
# reader's jobs. Callers test `ok` themselves, as they already do.
#
# Parsing engine (skipws/hex2dec/utf8enc/parseString/parseValue/parseObject/
# parseArray) is copied verbatim from AgentsSlackConversationCounterparty.awk
# in this same directory (which took it from AgentsSlackMessagesFormat.awk,
# which took it from myx.common's agentMcpJsonParseRequest.awk) -- same
# recursive-descent JSON parser, only the leaf-emission logic differs.
#
# LC_ALL=C IS REQUIRED, not advisory. The walk below indexes a byte array
# built by `split(s, sc, "")`, and `split`/`length`/`substr` count CHARACTERS
# rather than bytes under a UTF-8 locale. Every call site already sets it.
# Dropping it does not fail -- it parses emoji and accented text subtly wrong.

BEGIN {
	## `-v path=...` is the caller-facing spelling, but `path` is also the
	## parameter name every parse function uses, and an awk parameter shadows
	## the global of the same name inside that function -- emitLeaf could
	## never see it. Copied once here, in BEGIN, which is not a function and
	## therefore does see the global. Compare against `wantPath` everywhere
	## below; never against `path`.
	wantPath = path

	input = ""
	inputSeen = 0
	okSeen = 0
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

## Identical to the engine's own parseString, with ONE addition: an unclosed
## string (input ran out before the closing quote) sets structErr, so a body
## truncated mid-value is reported as unparseable instead of silently
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

## Full-path EQUALITY only -- never a prefix or substring test. `channel.id`
## is the channel object's own `id`; `channel.purpose.id`, `channels.0.id` and
## `bot_profile.id` are different paths and fall through untouched, which is
## the entire point of parsing rather than matching. `ok` is recorded
## separately, as the marker that this input really is a Slack API response;
## it is recorded even when it is also the wanted path.
function emitLeaf(path, raw, val) {
	if (path == "ok") okSeen = 1
	if (path != wantPath) return
	## First occurrence wins, and a second one is reported rather than
	## quietly preferred either way: two leaves at one identical full path
	## means the object carried a duplicate key, which is malformed JSON and
	## worth seeing in the log rather than resolving by a coin toss.
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

## As the engine's own, plus structErr on the fall-through arm: a container
## that ended on neither `,` nor its own closing bracket did not end, it ran
## out of input.
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
		printf("⛔ ERROR: AgentsSlackJsonField.awk: no key path given -- pass one as `-v path=channel.id`\n") > "/dev/stderr"
		exit 2
	}

	s = input
	## One split, then sc[p] per byte: substr(s, p, 1) costs a strlen of the
	## whole payload per call in one-true-awk, which makes the walk quadratic.
	n = split(s, sc, "")
	p = 1

	## rc 1, the not-a-response state, decided BEFORE anything is parsed:
	## an empty read and an HTML error page both fail here, and neither may
	## be allowed to look like "the field is absent".
	skipws()
	if (p > n || sc[p] != "{") {
		printf("⛔ ERROR: AgentsSlackJsonField.awk: input is not a JSON object -- an empty read, an HTML error page, or a transport diagnostic captured in place of a response body (wanted path `%s`)\n", wantPath) > "/dev/stderr"
		exit 1
	}

	parseValue("")
	skipws()

	## Truncated mid-body, or a second document glued after the first.
	## Either way the thing parsed is not the response it claims to be.
	if (structErr || p <= n) {
		printf("⛔ ERROR: AgentsSlackJsonField.awk: input did not parse as one complete JSON object -- truncated body or trailing garbage (wanted path `%s`)\n", wantPath) > "/dev/stderr"
		exit 1
	}

	## Every Slack Web API response carries a top-level `ok`. Without it,
	## this is some other JSON, and reporting its missing field as a plain
	## absence would be a guess dressed as a finding.
	if (!okSeen) {
		printf("⛔ ERROR: AgentsSlackJsonField.awk: parsed JSON carries no top-level `ok` key -- not a Slack API response (wanted path `%s`)\n", wantPath) > "/dev/stderr"
		exit 1
	}

	if (foundCount > 1) {
		printf("# AgentsSlackJsonField.awk: path `%s` occurred %d times at that exact full path (duplicate key in one object, malformed JSON) -- reporting the first\n", wantPath, foundCount) > "/dev/stderr"
	}

	if (foundCount == 0) {
		if (optional != "1") {
			printf("# AgentsSlackJsonField.awk: path `%s` is absent from this response (rc 3) -- not an empty value, not present\n", wantPath) > "/dev/stderr"
		}
		exit 3
	}

	## `printf`, never `print`, in sentinel mode: `print` would append OFS/ORS
	## and reintroduce the very separator this mode exists to remove. The
	## default mode keeps `print` exactly as it was -- this adds a shape, it
	## does not change the existing one.
	if (sentinel == "1") {
		printf("%sX", foundValue)
	} else {
		print foundValue
	}
	exit 0
}
