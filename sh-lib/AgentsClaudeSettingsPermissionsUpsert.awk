#!/usr/bin/env awk

# Upserts myx.distro-agents' own mandatory Claude Code permission grants into
# ~/.claude/settings.json's `permissions.allow`/`permissions.deny`, merge-only
# -- awk fallback for a host without jq. DistroAgentsTools.fn.sh
# --install-claude-permissions (AgentsTools.Install.include) picks
# AgentsClaudeSettingsPermissionsUpsert.jq when `jq` is on PATH and this file
# otherwise; neither is a hard dependency of the op itself.
#
# Every entry already present that this script did not itself add is kept, in
# its original position -- this only ever appends missing entries (and, for
# the board grant specifically, first drops any stale prior grant so a moved
# board path does not accumulate old entries alongside the new one). Prints
# the new document on stdout; never opens the target itself.
#
# Same structural JSON-walker core as AgentsMcpServerJsonUpsert.awk
# (skipString/skipValue/skipObject/skipArray/findKeyInObjectAt/
# objectShapeAt/jsonEscape/validJson) -- duplicated rather than shared, since
# that file's own BEGIN/END are specific to its single-entry upsert and are
# not reusable as a library without a refactor out of this task's scope.
#
# Params via ENVIRON:
#   MYX_CLAUDEPERMS_BOARD_ROOT        -- resolved $MDAT_DATA_ROOT/board path
#   MYX_CLAUDEPERMS_STATIC_ALLOW_JSON -- fixed allow-grant JSON string array (literal)
#   MYX_CLAUDEPERMS_DENY_ADD_JSON     -- fixed deny-grant JSON string array (literal)
#   MYX_CLAUDEPERMS_MEMBERS_FILE      -- path to a plain text file, one acting
#                                        member's real skillset directory per line

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

function fail(reason) {
	print reason > "/dev/stderr"
	FAILED = 1
	exit 1
}

# Parses a JSON array of plain strings starting at arrStart into global ELEMS
# (0-based), returns the element count. Only ever called on permissions.allow
# / permissions.deny, which this whole document's own writer (this script,
# going forward) never puts anything but plain strings into.
function stringArrayAt(arrStart,   count, elemStart) {
	p = arrStart + 1
	skipws()
	count = 0
	delete ELEMS
	if (substr(s, p, 1) == "]") return count
	while (1) {
		skipws()
		elemStart = p
		if (substr(s, p, 1) != "\"") fail("permissions-array-element-not-a-string")
		skipString()
		ELEMS[count++] = substr(s, elemStart + 1, p - elemStart - 2)
		skipws()
		if (substr(s, p, 1) == ",") { p++; continue }
		if (substr(s, p, 1) == "]") { p++; return count }
		fail("permissions-array-malformed")
	}
}

function arrayJson(list, count,   i, out) {
	out = "["
	for (i = 0; i < count; i++) out = out (i ? ", " : "") "\"" jsonEscape(list[i]) "\""
	return out "]"
}

function inList(list, count, value,   i) {
	for (i = 0; i < count; i++) if (list[i] == value) return 1
	return 0
}

function basenameOf(path,   i, slash) {
	slash = 0
	for (i = length(path); i >= 1; i--) {
		if (substr(path, i, 1) == "/") { slash = i; break }
	}
	if (slash == 0) return path
	return substr(path, slash + 1)
}

# Reads membersFile once into MEMBERPATH[0..MEMBERPATHCOUNT-1] and populates
# memberNameSet[basename] = 1 for each -- basename is this whole codebase's
# own member-identity convention (every enumeration elsewhere, e.g.
# --install-skillset-symlinks, keys a member by `basename` of its skillset
# directory too), which is what lets a moved member be recognized as the
# "same" member at a new path rather than an unrelated new grant.
function loadMembers(   memberLine) {
	MEMBERPATHCOUNT = 0
	while ((getline memberLine < membersFile) > 0) {
		if (memberLine == "") continue
		MEMBERPATH[MEMBERPATHCOUNT++] = memberLine
		memberNameSet[basenameOf(memberLine)] = 1
	}
	close(membersFile)
}

# If v is exactly `Edit(<path>/**)` or `Write(<path>/**)`, returns basename(path);
# otherwise "" (not one of this op's own grant shapes at all -- a caller-added
# grant for something else entirely, always left alone).
function grantBasename(v,   prefixLen, path) {
	if (substr(v, 1, 5) == "Edit(") prefixLen = 5
	else if (substr(v, 1, 6) == "Write(") prefixLen = 6
	else return ""
	if (substr(v, length(v) - 3, 4) != "/**)") return ""
	path = substr(v, prefixLen + 1, length(v) - prefixLen - 4)
	return basenameOf(path)
}

# In-place insertion sort (byte/ASCII order, consistent under the caller's
# LC_ALL=C) -- both permissions arrays are written sorted, not merge-order,
# so the generated config stays reviewable/diffable across runs.
function sortList(list, count,   i, j, tmp) {
	for (i = 1; i < count; i++) {
		tmp = list[i]
		j = i - 1
		while (j >= 0 && list[j] > tmp) {
			list[j + 1] = list[j]
			j--
		}
		list[j + 1] = tmp
	}
}

# Locates targetKey inside the object at objStart within the CURRENT `s`,
# replacing its value with newValueJson (creating the key, as the first
# member, if absent) -- returns the whole new document. Mirrors
# AgentsMcpServerJsonUpsert.awk's own upsert()'s insert-vs-replace split,
# generalized to an arbitrary caller-supplied replacement value.
function upsertKeyValue(objStart, targetKey, newValueJson,   head, tail, sep) {
	if (!findKeyInObjectAt(objStart, targetKey)) fail("unparsable")
	if (!FOUND) {
		objectShapeAt(objStart)
		sep = OBJ_EMPTY ? "" : ", "
		head = substr(s, 1, OBJ_FIRST - 1)
		tail = substr(s, OBJ_FIRST)
		return head "\"" jsonEscape(targetKey) "\": " newValueJson sep tail
	}
	head = substr(s, 1, VALUE_START - 1)
	tail = substr(s, VALUE_END)
	return head newValueJson tail
}

# Every string this op always wants present in permissions.allow: the board
# grant pair (against the resolved $MDAT_DATA_ROOT/board path), the fixed
# static tool grants, then one Edit/Write pair per acting member path (from
# MEMBERPATH[], loaded once by loadMembers() before this runs).
function buildDesiredAllow(   dCount, k) {
	## `//` (not a single `/`) is required for an absolute filesystem path --
	## a single leading slash anchors at the settings source ($HOME, for this
	## user-scope file), not the filesystem root (Claude Code's own
	## permissions docs, "Read and Edit" pattern table; same rule
	## AgentsClaudeWorkspaceRestrictionsUpsert.awk's own allow-grant comment
	## documents and applies). boardRoot/MEMBERPATH[] are already absolute
	## (each carries its own leading "/"), so exactly ONE more "/" here
	## yields the required "//" -- prepending "//" would double it.
	dCount = 0
	## A board is not configured in most installations. Add the board grant
	## pair only when a board path was actually supplied; an empty boardRoot
	## contributes no grant (and any stale board grant is still dropped below).
	if (boardRoot != "") {
		DESIRED[dCount++] = "Edit(/" boardRoot "/**)"
		DESIRED[dCount++] = "Write(/" boardRoot "/**)"
	}
	for (i = 0; i < staticAllowCount; i++) DESIRED[dCount++] = staticAllow[i]
	for (k = 0; k < MEMBERPATHCOUNT; k++) {
		DESIRED[dCount++] = "Edit(/" MEMBERPATH[k] "/**)"
		DESIRED[dCount++] = "Write(/" MEMBERPATH[k] "/**)"
	}
	return dCount
}

BEGIN {
	boardRoot = ENVIRON["MYX_CLAUDEPERMS_BOARD_ROOT"]
	membersFile = ENVIRON["MYX_CLAUDEPERMS_MEMBERS_FILE"]
	staticAllowRaw = ENVIRON["MYX_CLAUDEPERMS_STATIC_ALLOW_JSON"]
	denyAddRaw = ENVIRON["MYX_CLAUDEPERMS_DENY_ADD_JSON"]
	## boardRoot is optional (no board in most installations); the other three are required.
	if (membersFile == "" || staticAllowRaw == "" || denyAddRaw == "") fail("usage")
	if (!validJson(staticAllowRaw, "[")) fail("static-allow-not-a-json-array")
	if (!validJson(denyAddRaw, "[")) fail("deny-add-not-a-json-array")

	## stringArrayAt expects arrStart to point at the '[' itself, and reads/
	## writes the scan globals (s/n/p) -- switch the scan onto each literal
	## as its own statements first (awk has no comma-expression sequencing
	## to do this inline inside the call).
	s = staticAllowRaw; n = length(s); p = 1; skipws()
	staticAllowCount = stringArrayAt(p)
	for (i = 0; i < staticAllowCount; i++) staticAllow[i] = ELEMS[i]

	s = denyAddRaw; n = length(s); p = 1; skipws()
	denyAddCount = stringArrayAt(p)
	for (i = 0; i < denyAddCount; i++) denyAdd[i] = ELEMS[i]
}

# Rejoin the records under the default RS: a NUL RS is the empty string, which
# selects paragraph mode and would split the document on any blank line.
{ doc = (NR == 1) ? $0 : doc "\n" $0; }

END {
	if (FAILED) exit 1
	s = doc; n = length(s); p = 1
	skipws()
	if (substr(s, p, 1) != "{") fail("not-a-json-object")
	rootStart = p

	## --- permissions.allow ---
	if (!findKeyInObjectAt(rootStart, "permissions")) fail("unparsable")
	if (!FOUND) {
		objectShapeAt(rootStart)
		sep = OBJ_EMPTY ? "" : ", "
		head = substr(s, 1, OBJ_FIRST - 1)
		tail = substr(s, OBJ_FIRST)
		s = head "\"permissions\": {}" sep tail
	}
	n = length(s); p = 1; skipws()
	rootStart = p
	if (!findKeyInObjectAt(rootStart, "permissions")) fail("unparsable")
	permStart = VALUE_START
	if (substr(s, permStart, 1) != "{") fail("permissions-not-an-object")

	loadMembers()

	oldAllowCount = 0
	if (findKeyInObjectAt(permStart, "allow") && FOUND) {
		if (substr(s, VALUE_START, 1) != "[") fail("allow-not-an-array")
		oldAllowCount = stringArrayAt(VALUE_START)
	}
	for (i = 0; i < oldAllowCount; i++) oldAllow[i] = ELEMS[i]

	keptAllowCount = 0
	for (i = 0; i < oldAllowCount; i++) {
		v = oldAllow[i]
		if ((v ~ /^Edit\(.*\/board\/\*\*\)$/) || (v ~ /^Write\(.*\/board\/\*\*\)$/)) continue
		## a prior Edit/Write grant for a member still acting today, at
		## whatever path it used to resolve to -- drop it here, the fresh
		## grant at its CURRENT path gets appended below via DESIRED. Same
		## replace-not-accumulate rule as the board grant, keyed by member
		## name (this codebase's own identity convention) instead of a
		## fixed suffix, so a member converted from a real directory to a
		## symlink (or moved to a different repo) doesn't end up granted
		## at both its old and new location at once.
		bn = grantBasename(v)
		if (bn != "" && (bn in memberNameSet)) continue
		keptAllow[keptAllowCount++] = v
	}
	desiredCount = buildDesiredAllow()
	newAllowCount = keptAllowCount
	for (i = 0; i < keptAllowCount; i++) newAllow[i] = keptAllow[i]
	for (i = 0; i < desiredCount; i++) {
		if (!inList(newAllow, newAllowCount, DESIRED[i])) newAllow[newAllowCount++] = DESIRED[i]
	}

	sortList(newAllow, newAllowCount)

	## re-locate "permissions" fresh (splicing "allow" in shifts every later
	## offset) before touching "deny" in the same object
	s = upsertKeyValue(permStart, "allow", arrayJson(newAllow, newAllowCount))
	n = length(s); p = 1; skipws(); rootStart = p
	if (!findKeyInObjectAt(rootStart, "permissions")) fail("unparsable")
	permStart = VALUE_START

	## --- permissions.deny ---
	oldDenyCount = 0
	if (findKeyInObjectAt(permStart, "deny") && FOUND) {
		if (substr(s, VALUE_START, 1) != "[") fail("deny-not-an-array")
		oldDenyCount = stringArrayAt(VALUE_START)
	}
	for (i = 0; i < oldDenyCount; i++) oldDeny[i] = ELEMS[i]
	newDenyCount = oldDenyCount
	for (i = 0; i < oldDenyCount; i++) newDeny[i] = oldDeny[i]
	for (i = 0; i < denyAddCount; i++) {
		if (!inList(newDeny, newDenyCount, denyAdd[i])) newDeny[newDenyCount++] = denyAdd[i]
	}
	sortList(newDeny, newDenyCount)
	s = upsertKeyValue(permStart, "deny", arrayJson(newDeny, newDenyCount))

	if (!validJson(s, "{")) fail("generated-config-would-not-parse")
	## the doc/record join above drops the source file's own trailing
	## newline (awk's per-line read strips each record's terminator, and a
	## file ending in "\n" produces no further empty record to rejoin) --
	## restored once here rather than left off the whole document.
	printf "%s\n", s
}
