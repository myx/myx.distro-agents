#!/usr/bin/env awk

# Parses ONE `search.messages` JSON response (fed on stdin, run under
# LC_ALL=C for byte safety) and reports that page's matches -- the reader
# --member-comms-slack-search-messages uses, and the only thing in this package that
# understands search's own `messages.matches[]` envelope.
#
# WHY A SEPARATE READER, and not one of the two that already exist. Neither
# fits, and neither was bent to fit:
#   - sh-lib/AgentsSlackMessagesFormat.awk is anchored on `messages.<idx>.`,
#     the flat array conversations.history/conversations.replies return.
#     search.messages nests its own array one level deeper, at
#     `messages.matches.<idx>.`, so that formatter reads nothing at all here.
#     Re-anchoring it would have made one file serve two response shapes that
#     Slack does not promise to keep alike.
#   - sh-lib/AgentsSlackJsonField.awk reads ONE fully-qualified scalar path by
#     equality and cannot enumerate an array of unknown length. Driving it from
#     a shell loop would mean one process, and one full re-parse of a
#     hundred-match payload, per field per match.
# Same reasoning that put AgentsSlackConversationCounterparty.awk beside them:
# a new response shape gets its own reader on the shared engine, never a
# pattern match over raw JSON.
#
# THE PARENT THREAD TS IS NOT A TOP-LEVEL FIELD ON A MATCH, and that is the one
# fact this reader exists to recover. A `search.messages` match object carries
# no `thread_ts` of its own -- verified against real responses from this
# workspace. The only place the parent's ts appears is inside the match's own
# `permalink`, as a query parameter:
#     https://<team>.slack.com/archives/C.../p1786394209731199?thread_ts=1786394109.813549&cid=C...
# So the permalink is parsed here, and it is parsed as a URL: the JSON is walked
# structurally by the engine below, the permalink arrives as a decoded scalar
# string, and only then is its query string split on the literal `?`/`&`/`=`
# delimiters that define it. Nothing anywhere reaches into the raw JSON body
# with a pattern -- a greedy BRE reading the "last thread_ts in the payload" is
# precisely the class of bug AgentsSlackJsonField.awk's own header documents,
# and it would be an especially easy one to reintroduce here, where every one of
# a hundred matches carries a thread_ts-bearing permalink.
#
# A match whose parent ts EQUALS its own ts is the thread's parent, not a reply
# -- Slack writes the parent's permalink with `thread_ts` set to the parent
# itself. Told apart by that positive comparison, never by assuming a
# thread_ts-bearing permalink means "reply".
#
# Parsing engine (skipws/hex2dec/utf8enc/parseString/parseValue/parseObject/
# parseArray) is copied verbatim from sh-lib/AgentsSlackMessagesFormat.awk,
# which copied it in turn from myx.common's agentMcpJsonParseRequest.awk --
# same recursive-descent JSON parser, only the leaf-emission logic differs.
#
# Options:
#   -v cutoff=<epoch>  REQUIRED. Matches with `ts` STRICTLY OLDER than this are
#                      dropped. The caller over-fetches on purpose -- Slack's
#                      own `after:` operator is day-granular and exclusive, so
#                      the query asks for a wider window than the caller wants
#                      and this is where the real, sub-second boundary is
#                      applied. See the op's own arm for that reasoning.
#   -v mode=lines      Default. One line per in-range match, oldest first.
#   -v mode=meta       That page's own counters instead, as `KEY=value` lines.
#
# `mode=lines` output, one line per match:
#     <ts> | <user> | <text>
# plus, only for a match that is a reply inside a thread:
#     <ts> | <user> | <text> [thread-reply of <parent-ts>]
# The three-column shape and the trailing bracket annotation are
# AgentsSlackMessagesFormat.awk's own established output shape, not a new one
# invented here -- that file appends `[reactions: ...]` and `[thread: ...]` the
# same way, so a downstream reader splitting on " | " keeps working unchanged.
#
# A match's text may legitimately contain newlines, and a format whose whole
# promise is one line per match cannot carry them. INTERIOR newlines are
# flattened to single spaces, so a multi-line message stays one output record.
# The full, unflattened text is what `--raw` is for.
#
# `mode=meta` output, always all of these keys, always in this order:
#   SEARCH_TOTAL=        matches Slack reports for the whole query, all pages
#   SEARCH_PAGE=         which page this response is
#   SEARCH_PAGES=        how many pages the query has in total
#   PAGE_MATCH_COUNT=    matches carried by THIS response
#   PAGE_EXPECTED_COUNT= how many Slack itself says a full page holds, i.e. the
#                        per-page size the query asked for. On any page but the
#                        last, a PAGE_MATCH_COUNT below this is a SHORT BODY --
#                        a truncated read, not a small page -- and the caller
#                        fails loud on it rather than reporting the missing
#                        matches as absent.
#   PAGE_IN_RANGE_COUNT= how many of them survived the cutoff
#   PAGE_THREAD_REPLIES= how many of those are replies inside a thread
#   PAGE_OLDEST_TS=      the oldest ts on this page, cutoff NOT applied
#                        (empty when the page carried no match). The caller
#                        compares it against the cutoff to decide whether the
#                        next page can still hold anything in range.
#
# Exit status -- the answer to the caller's question, never Slack's own ok flag
# restated (see AgentsTools.MemberCommsSlack.include's own header rule):
#   rc 0  parsed, and at least one match survived the cutoff.
#   rc 3  parsed fine, and NO match survived the cutoff. A real, positive
#         answer -- this page holds nothing in range -- and deliberately not
#         rc 0, so a caller cannot read absence as presence by ignoring status.
#         `mode=meta` returns it identically, so both modes agree.
#   rc 1  the input is not a parseable search.messages response, or Slack
#         answered ok:false. Nothing is known about presence or absence.

BEGIN {
	matchCount = 0
	apiOk = "true"
	apiOkSeen = 0
	apiError = ""
	docSeen = 0
	searchTotal = ""
	searchPage = ""
	searchPages = ""
	searchPerPage = ""
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

## Pulls `thread_ts` out of ONE permalink, treating it as the URL it is: split
## off the query string at the first `?`, then walk the `&`-separated pairs and
## compare each pair's NAME by equality against `thread_ts`. Equality on the
## split name, not a search for the substring "thread_ts=" anywhere in the URL,
## so a future parameter named e.g. `parent_thread_ts` can never be mistaken for
## this one. Returns "" when the permalink carries no such parameter, which is
## the normal shape for a message that is not in a thread at all.
function permalinkThreadTs(link,   qs, qmark, count, pairs, i, eq, name) {
	qmark = index(link, "?")
	if (qmark == 0) return ""
	qs = substr(link, qmark + 1)
	count = split(qs, pairs, "&")
	for (i = 1; i <= count; i++) {
		eq = index(pairs[i], "=")
		if (eq == 0) continue
		name = substr(pairs[i], 1, eq - 1)
		if (name == "thread_ts") return substr(pairs[i], eq + 1)
	}
	return ""
}

## Only the four leaves this reader actually reports, plus the envelope's own
## ok/error and paging counters. Everything else in a match object -- score,
## iid, blocks, team -- is deliberately not collected.
function emitLeaf(path, raw, val,   idx, rest, afterIdx) {
	if (path == "ok") { apiOk = val; apiOkSeen = 1; return; }
	if (path == "error") { apiError = val; return; }
	if (path == "messages.total") { searchTotal = val; return; }
	if (path == "messages.paging.page") { searchPage = val; return; }
	if (path == "messages.paging.pages") { searchPages = val; return; }
	if (path == "messages.paging.count") { searchPerPage = val; return; }

	if (index(path, "messages.matches.") != 1) return
	rest = substr(path, length("messages.matches.") + 1)
	idx = rest
	sub(/\..*/, "", idx)
	if (idx !~ /^[0-9]+$/) return
	if (idx + 1 > matchCount) matchCount = idx + 1

	if (index(rest, idx ".") != 1) return
	afterIdx = substr(rest, length(idx) + 2)

	if (afterIdx == "ts") { tsOf[idx] = val; return; }
	if (afterIdx == "text") { textOf[idx] = val; return; }
	if (afterIdx == "permalink") { linkOf[idx] = val; return; }
	## `user` is a real user id; `username` is the display name search returns
	## beside it. A bot-posted match may carry only the latter, so it is the
	## fallback -- and only ever a fallback, never an overwrite of a real id.
	if (afterIdx == "user") { userOf[idx] = val; return; }
	if (afterIdx == "username" && !(idx in userOf)) { userOf[idx] = val; return; }
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

## The WHOLE input is accumulated and parsed once, never line by line: a
## pretty-printed body must parse exactly like the single-line one Slack sends
## today, and picking a line is the same class of accident as picking a match.
{ doc = doc $0 "\n"; docSeen = 1 }

END {
	if (cutoff == "") {
		print "⛔ ERROR: AgentsSlackSearchMatches.awk: -v cutoff=<epoch> is required -- without it there is no boundary to apply and every match would be reported as in range." > "/dev/stderr"
		exit 1
	}
	if (mode == "") mode = "lines"
	if (mode != "lines" && mode != "meta") {
		printf("⛔ ERROR: AgentsSlackSearchMatches.awk: -v mode must be 'lines' or 'meta', got: %s\n", mode) > "/dev/stderr"
		exit 1
	}
	if (!docSeen) {
		print "⛔ ERROR: AgentsSlackSearchMatches.awk: empty input -- no search.messages response was read, so nothing is known about presence or absence of matches." > "/dev/stderr"
		exit 1
	}

	s = doc
	n = length(s)
	p = 1
	parseValue("")

	if (apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: AgentsSlackSearchMatches.awk: Slack API call failed: ok:false%s\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 1
	}
	## A body that carried no `ok` at all is not a search.messages response --
	## an HTML error page or a truncated read reaches here otherwise and would
	## be reported as a clean "no matches".
	if (!apiOkSeen) {
		print "⛔ ERROR: AgentsSlackSearchMatches.awk: the input carried no `ok` field, so it is not a Slack API response body. It has NOT been read as an empty result." > "/dev/stderr"
		exit 1
	}

	inRange = 0
	threadReplies = 0
	oldestTs = ""
	for (i = 0; i < matchCount; i++) {
		if (!(i in tsOf)) continue
		if (oldestTs == "" || tsOf[i] + 0 < oldestTs + 0) oldestTs = tsOf[i]
		if (tsOf[i] + 0 < cutoff + 0) continue
		keep[inRange] = i
		inRange++
		parentTs = (i in linkOf) ? permalinkThreadTs(linkOf[i]) : ""
		parentOf[i] = parentTs
		if (parentTs != "" && parentTs != tsOf[i]) threadReplies++
	}

	if (mode == "meta") {
		printf("SEARCH_TOTAL=%s\n", searchTotal)
		printf("SEARCH_PAGE=%s\n", searchPage)
		printf("SEARCH_PAGES=%s\n", searchPages)
		printf("PAGE_MATCH_COUNT=%d\n", matchCount)
		printf("PAGE_EXPECTED_COUNT=%s\n", searchPerPage)
		printf("PAGE_IN_RANGE_COUNT=%d\n", inRange)
		printf("PAGE_THREAD_REPLIES=%d\n", threadReplies)
		printf("PAGE_OLDEST_TS=%s\n", oldestTs)
		exit (inRange > 0 ? 0 : 3)
	}

	## Slack returns search matches newest-first under sort_dir=desc; print
	## oldest-first, the same chronological direction
	## AgentsSlackMessagesFormat.awk prints in, so the two ops read alike.
	for (k = inRange - 1; k >= 0; k--) {
		i = keep[k]
		text = (i in textOf) ? textOf[i] : ""
		gsub(/\n/, " ", text)
		gsub(/\r/, " ", text)
		line = sprintf("%s | %s | %s", tsOf[i], (i in userOf ? userOf[i] : "?"), text)
		if (parentOf[i] != "" && parentOf[i] != tsOf[i]) {
			line = line sprintf(" [thread-reply of %s]", parentOf[i])
		}
		print line
	}
	exit (inRange > 0 ? 0 : 3)
}
