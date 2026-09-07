#!/usr/bin/env awk

# Sets one boolean member to literal `true` on one entry of ~/.claude.json's
# root `projects` object -- claude's own machine-global state file, holding
# every project it knows about. Reads the whole file itself, rejoining records
# under the default RS (caller sets only LC_ALL=C), prints the new document on
# stdout, and never opens the target: the caller installs the output.
#
# The counterpart of AgentsClaudeSettingsVerify.awk's own
# MYX_CLAUDEVERIFY_PROJECT_PATH/MYX_CLAUDEVERIFY_PROJECT_TRUE pair, which
# reports whether that same member reads `true`.
#
# Splices rather than re-serialising, so every key it was not asked to write
# survives byte for byte and the file keeps the layout it already had. Creates
# `projects`, and the entry inside it, only when they are absent; an entry that
# exists keeps every member it already carries. Fails closed: any error exits 1
# with a one-word reason on stderr and zero bytes on stdout, and an empty or
# unparsable document is such an error rather than a file to replace.
#
# Same structural JSON-walker core as AgentsClaudeSettingsVerify.awk /
# AgentsMcpServerJsonUpsert.awk, duplicated rather than shared, per this
# codebase's own established convention for these walkers.
#
# Params via ENVIRON, never `-v`: `-v` backslash-decodes its value, which
# corrupts a path, and a project key IS a path.
#   MYX_CLAUDETRUST_PROJECT_PATH -- one key of the root `projects` object,
#                                   i.e. a workspace root
#   MYX_CLAUDETRUST_PROJECT_TRUE -- the member name on that entry to set to
#                                   literal `true`

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
		if (c == "\\") { p += 2; continue ; }
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
	if (substr(s, p, 1) == "}") { p++; return 1 ; }
	while (1) {
		skipws()
		if (!skipString()) return 0
		skipws()
		if (substr(s, p, 1) != ":") return 0
		p++
		if (!skipValue()) return 0
		skipws()
		c = substr(s, p, 1)
		if (c == ",") { p++; continue ; }
		if (c == "}") { p++; return 1 ; }
		return 0
	}
}

function skipArray(   c) {
	p++
	skipws()
	if (substr(s, p, 1) == "]") { p++; return 1 ; }
	while (1) {
		if (!skipValue()) return 0
		skipws()
		c = substr(s, p, 1)
		if (c == ",") { p++; continue ; }
		if (c == "]") { p++; return 1 ; }
		return 0
	}
}

# Sets FOUND, VALUE_START, VALUE_END.
function findKeyInObjectAt(objStart, targetKey,   keyStart, key, valStart) {
	p = objStart
	FOUND = 0
	p++
	skipws()
	if (substr(s, p, 1) == "}") { p++; return 1 ; }
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
		if (key == targetKey) { FOUND = 1; VALUE_START = valStart; VALUE_END = p ; }
		skipws()
		if (substr(s, p, 1) == ",") { p++; continue ; }
		if (substr(s, p, 1) == "}") { p++; return 1 ; }
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
	if (ok) { skipws(); ok = (p > n) ; }
	s = savedS; n = savedN; p = savedP
	return ok
}

function fail(reason) {
	print reason > "/dev/stderr"
	FAILED = 1
	exit 1
}

function emit(result) {
	if (!validJson(result, "{")) fail("generated-config-would-not-parse")
	printf "%s", result
	exit 0
}

# Replaces memberKey's value inside the object at objStart with memberValueJson,
# creating the member as the object's first entry when it is absent.
function upsertMember(objStart, memberKey, memberValueJson,   head, tail, sep) {
	if (!findKeyInObjectAt(objStart, memberKey)) fail("unparsable")
	if (!FOUND) {
		objectShapeAt(objStart)
		sep = OBJ_EMPTY ? "" : ", "
		head = substr(s, 1, OBJ_FIRST - 1)
		tail = substr(s, OBJ_FIRST)
		return head "\"" jsonEscape(memberKey) "\": " memberValueJson sep tail
	}
	head = substr(s, 1, VALUE_START - 1)
	tail = substr(s, VALUE_END)
	return head memberValueJson tail
}

BEGIN {
	projectPath = ENVIRON["MYX_CLAUDETRUST_PROJECT_PATH"]
	trueMember = ENVIRON["MYX_CLAUDETRUST_PROJECT_TRUE"]
	if (projectPath == "" || trueMember == "") fail("usage")
}

# Rejoin the records under the default RS: a NUL RS is the empty string, which
# selects paragraph mode and would split the document on any blank line.
{ doc = (NR == 1) ? $0 : doc "\n" $0; }

END {
	if (FAILED) exit 1
	## An absent or empty state file is claude's to create, never this
	## writer's: a replacement written here would stand where claude expects
	## its own record.
	if (doc ~ /^[ \t\r\n]*$/) fail("empty-document")
	s = doc; n = length(s); p = 1
	skipws()
	if (substr(s, p, 1) != "{") fail("not-a-json-object")
	rootStart = p

	if (!findKeyInObjectAt(rootStart, "projects")) fail("unparsable")
	if (!FOUND) emit(upsertMember(rootStart, "projects", "{\"" jsonEscape(projectPath) "\": {\"" jsonEscape(trueMember) "\": true}}"))

	projectsStart = VALUE_START
	if (substr(s, projectsStart, 1) != "{") fail("projects-not-an-object")

	if (!findKeyInObjectAt(projectsStart, projectPath)) fail("unparsable")
	if (!FOUND) emit(upsertMember(projectsStart, projectPath, "{\"" jsonEscape(trueMember) "\": true}"))

	projectStart = VALUE_START
	if (substr(s, projectStart, 1) != "{") fail("project-entry-not-an-object")

	emit(upsertMember(projectStart, trueMember, "true"))
}
