#!/usr/bin/env awk

# Verifies the "myx.common" MCP server registration in one config file, as
# written by AgentsMcpServerJsonUpsert.py. Input: whole file as one record
# (caller sets RS to slurp-all, under LC_ALL=C). Prints "OK" and exits 0, or
# prints a one-word reason and exits 1.
#
# Params, via ENVIRON rather than -v: awk's -v assignment performs its own
# backslash-escape decoding, which corrupts values containing '\' or '"'.
#   MYX_MCPVERIFY_TOPKEY  - "servers" or "mcpServers".
#   MYX_MCPVERIFY_COMMAND - the server script the entry must launch.
#
# Asserts: the entry exists, launches exactly MYX_MCPVERIFY_COMMAND with args
# ["--run"], and that no OTHER key in the same object launches a command from
# inside this product's tree -- a duplicate the host would launch twice.

function skipws(   c) {
	while (p <= n) {
		c = substr(s, p, 1)
		if (c == " " || c == "\t" || c == "\n" || c == "\r") p++
		else return
	}
}

function skipString(   c) {
	if (substr(s, p, 1) != "\"") return 0
	p++
	while (p <= n) {
		c = substr(s, p, 1)
		if (c == "\\") { p += 2; continue }
		p++
		if (c == "\"") return 1
	}
	return 0
}

function skipValue(   c) {
	skipws()
	c = substr(s, p, 1)
	if (c == "\"") return skipString()
	if (c == "{") return skipObject()
	if (c == "[") return skipArray()
	while (p <= n) {
		c = substr(s, p, 1)
		if (c == "," || c == "}" || c == "]" || c == " " || c == "\t" || c == "\n" || c == "\r") break
		p++
	}
	return 1
}

function skipObject(   c) {
	p++ # {
	skipws()
	if (substr(s, p, 1) == "}") { p++; return 1 }
	while (1) {
		skipws()
		if (!skipString()) return 0
		skipws()
		if (substr(s, p, 1) != ":") return 0
		p++
		if (!skipValue()) return 0
		skipws()
		c = substr(s, p, 1)
		if (c == ",") { p++; continue }
		if (c == "}") { p++; return 1 }
		return 0
	}
}

function skipArray(   c) {
	p++ # [
	skipws()
	if (substr(s, p, 1) == "]") { p++; return 1 }
	while (1) {
		if (!skipValue()) return 0
		skipws()
		c = substr(s, p, 1)
		if (c == ",") { p++; continue }
		if (c == "]") { p++; return 1 }
		return 0
	}
}

# Finds targetKey among the direct pairs of the object whose "{" is at
# objStart. Sets FOUND, VALUE_START, VALUE_END.
function findKeyInObjectAt(objStart, targetKey,   keyStart, key, valStart) {
	p = objStart
	FOUND = 0
	p++ # {
	skipws()
	if (substr(s, p, 1) == "}") { p++; return 1 }
	while (1) {
		skipws()
		keyStart = p
		if (!skipString()) return 0
		key = substr(s, keyStart + 1, p - keyStart - 2)
		skipws()
		if (substr(s, p, 1) != ":") return 0
		p++
		skipws()
		valStart = p
		if (!skipValue()) return 0
		if (key == targetKey) { FOUND = 1; VALUE_START = valStart; VALUE_END = p }
		skipws()
		if (substr(s, p, 1) == ",") { p++; continue }
		if (substr(s, p, 1) == "}") { p++; return 1 }
		return 0
	}
}

# Reads the "command" of the entry object at objStart, as its raw JSON token.
# Saves/restores p so the caller's own walk is unaffected.
function commandTokenAt(objStart,   savedP, ret) {
	savedP = p
	ret = ""
	if (substr(s, objStart, 1) == "{" && findKeyInObjectAt(objStart, "command") && FOUND)
		ret = substr(s, VALUE_START, VALUE_END - VALUE_START)
	p = savedP
	return ret
}

# True when the command lives inside this product's tree, i.e. "myx.common" is
# one of its path components. An exact component, never a substring: a
# directory merely named "not-myx.common-really" is a stranger's.
function isOurCommand(tok,   v) {
	if (tok == "" || substr(tok, 1, 1) != "\"") return 0
	v = substr(tok, 2, length(tok) - 2)
	gsub(/\\\//, "/", v)
	return v ~ /(^|\/)myx\.common(\/|$)/
}

# Counts direct pairs, other than "myx.common", launching a command from
# inside this product's tree. Sets DUPES.
function countDupeEntriesAt(objStart,   keyStart, key, valStart) {
	p = objStart
	DUPES = 0
	p++ # {
	skipws()
	if (substr(s, p, 1) == "}") { p++; return 1 }
	while (1) {
		skipws()
		keyStart = p
		if (!skipString()) return 0
		key = substr(s, keyStart + 1, p - keyStart - 2)
		skipws()
		if (substr(s, p, 1) != ":") return 0
		p++
		skipws()
		valStart = p
		if (!skipValue()) return 0
		if (key != "myx.common" && isOurCommand(commandTokenAt(valStart))) DUPES++
		skipws()
		if (substr(s, p, 1) == ",") { p++; continue }
		if (substr(s, p, 1) == "}") { p++; return 1 }
		return 0
	}
}

# The only escapes a filesystem path can force. Mirrors what json.dump wrote.
function jsonEscape(v) {
	gsub(/\\/, "\\\\", v)
	gsub(/"/, "\\\"", v)
	return v
}

# Whitespace outside string literals; the values compared here hold none.
function squeeze(v) {
	gsub(/[ \t\r\n]/, "", v)
	return v
}

BEGIN {
	topKey = ENVIRON["MYX_MCPVERIFY_TOPKEY"]
	wantCommand = ENVIRON["MYX_MCPVERIFY_COMMAND"]
	if (topKey == "" || wantCommand == "") { print "usage"; exit 1 }
}

{
	s = $0
	n = length(s)
	p = 1

	skipws()
	if (substr(s, p, 1) != "{") { print "not-a-json-object"; exit 1 }
	if (!findKeyInObjectAt(p, topKey)) { print "unparsable"; exit 1 }
	if (!FOUND) { print "no-" topKey "-key"; exit 1 }
	serversStart = VALUE_START
	if (substr(s, serversStart, 1) != "{") { print topKey "-not-an-object"; exit 1 }

	if (!findKeyInObjectAt(serversStart, "myx.common")) { print "unparsable"; exit 1 }
	if (!FOUND) { print "no-myx.common-entry"; exit 1 }
	entryStart = VALUE_START
	if (substr(s, entryStart, 1) != "{") { print "entry-not-an-object"; exit 1 }

	if (!findKeyInObjectAt(entryStart, "command")) { print "unparsable"; exit 1 }
	if (!FOUND) { print "entry-has-no-command"; exit 1 }
	if (substr(s, VALUE_START, VALUE_END - VALUE_START) != "\"" jsonEscape(wantCommand) "\"") { print "wrong-command"; exit 1 }

	if (!findKeyInObjectAt(entryStart, "args")) { print "unparsable"; exit 1 }
	if (!FOUND) { print "entry-has-no-args"; exit 1 }
	if (squeeze(substr(s, VALUE_START, VALUE_END - VALUE_START)) != "[\"--run\"]") { print "wrong-args"; exit 1 }

	if (!countDupeEntriesAt(serversStart)) { print "unparsable"; exit 1 }
	if (DUPES > 0) { print "duplicate-entry-for-this-server"; exit 1 }

	print "OK"
}
