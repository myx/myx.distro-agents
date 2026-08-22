#!/usr/bin/env awk

# Upserts one MCP server entry into a JSON config, by entry key. Prints the new
# document on stdout; never opens the target. Params via ENVIRON:
# MYX_MCPUPSERT_{TOPKEY,ENTRYKEY,COMMAND,ARGS,ENV}. See MAGIC.md.

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
	if (p > n) return 0
	while (p <= n) {
		c = substr(s, p, 1)
		if (c == "," || c == "}" || c == "]" || c == " " || c == "\t" || c == "\n" || c == "\r") break
		p++
	}
	return 1
}

function skipObject(   c) {
	p++
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
	p++
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

# Sets FOUND, VALUE_START, VALUE_END.
function findKeyInObjectAt(objStart, targetKey,   keyStart, key, valStart) {
	p = objStart
	FOUND = 0
	p++
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

# Sets OBJ_FIRST, OBJ_EMPTY. Restores p.
function objectShapeAt(objStart,   savedP) {
	savedP = p
	p = objStart + 1
	skipws()
	OBJ_FIRST = p
	OBJ_EMPTY = (substr(s, p, 1) == "}") ? 1 : 0
	p = savedP
}

function jsonEscape(v) {
	gsub(/\\/, "\\\\", v)
	gsub(/"/, "\\\"", v)
	return v
}

# Parses txt on its own, restoring the document scan.
function validJson(txt, want,   savedS, savedN, savedP, ok) {
	savedS = s; savedN = n; savedP = p
	s = txt; n = length(s); p = 1
	skipws()
	ok = (substr(s, p, 1) == want) && skipValue()
	if (ok) { skipws(); ok = (p > n) }
	s = savedS; n = savedN; p = savedP
	return ok
}

function entryJson(   t) {
	t = "{\"type\": \"stdio\", \"command\": \"" jsonEscape(command) "\""
	if (argsJson != "") t = t ", \"args\": " argsJson
	if (envJson != "") t = t ", \"env\": " envJson
	return t "}"
}

function fail(reason) {
	print reason > "/dev/stderr"
	FAILED = 1
	exit 1
}

function emit(result) {
	if (!validJson(result, "{")) fail("generated-config-would-not-parse")
	printf "%s", result
	DONE = 1
}

function upsert(   entry, rootStart, topStart, head, tail, sep) {
	entry = entryJson()

	if (s ~ /^[ \t\r\n]*$/) {
		emit("{\n  \"" jsonEscape(topKey) "\": {\n    \"" jsonEscape(entryKey) "\": " entry "\n  }\n}\n")
		return
	}

	n = length(s)
	p = 1
	skipws()
	if (substr(s, p, 1) != "{") fail("not-a-json-object")
	rootStart = p

	if (!findKeyInObjectAt(rootStart, topKey)) fail("unparsable")
	if (!FOUND) {
		objectShapeAt(rootStart)
		sep = OBJ_EMPTY ? "" : ", "
		head = substr(s, 1, OBJ_FIRST - 1)
		tail = substr(s, OBJ_FIRST)
		emit(head "\"" jsonEscape(topKey) "\": {\"" jsonEscape(entryKey) "\": " entry "}" sep tail)
		return
	}

	topStart = VALUE_START
	if (substr(s, topStart, 1) != "{") fail(topKey "-not-an-object")

	if (!findKeyInObjectAt(topStart, entryKey)) fail("unparsable")
	if (!FOUND) {
		objectShapeAt(topStart)
		sep = OBJ_EMPTY ? "" : ", "
		head = substr(s, 1, OBJ_FIRST - 1)
		tail = substr(s, OBJ_FIRST)
		emit(head "\"" jsonEscape(entryKey) "\": " entry sep tail)
		return
	}

	head = substr(s, 1, VALUE_START - 1)
	tail = substr(s, VALUE_END)
	emit(head entry tail)
}

BEGIN {
	topKey = ENVIRON["MYX_MCPUPSERT_TOPKEY"]
	entryKey = ENVIRON["MYX_MCPUPSERT_ENTRYKEY"]
	command = ENVIRON["MYX_MCPUPSERT_COMMAND"]
	argsJson = ENVIRON["MYX_MCPUPSERT_ARGS"]
	envJson = ENVIRON["MYX_MCPUPSERT_ENV"]
	if (topKey == "" || entryKey == "" || command == "") fail("usage")
	if (argsJson != "" && !validJson(argsJson, "[")) fail("args-not-a-json-array")
	if (envJson != "" && !validJson(envJson, "{")) fail("env-not-a-json-object")
}

# An empty target yields no record; END covers the fresh-document case.
{
	if (DONE) next
	s = $0
	upsert()
}

END {
	if (FAILED) exit 1
	if (DONE) exit 0
	s = ""
	upsert()
}