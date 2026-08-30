#!/usr/bin/env awk

# Upserts myx.distro-agents' workspace-level Claude Code restrictions into a
# TARGET WORKSPACE's own `.claude/settings.json`: `permissions.deny` entries
# plus `hooks.PreToolUse` entries. Merge-only, awk (no jq dependency).
# DistroAgentsTools.fn.sh --install-workspace-restrictions
# (AgentsTools.Install.include) is the only caller.
#
# Every entry already present that this script did not itself add is kept, in
# its original position -- this only ever appends missing entries. Prints the
# new document on stdout; never opens the target itself.
#
# Same structural JSON-walker core as AgentsClaudeSettingsPermissionsUpsert.awk
# / AgentsMcpServerJsonUpsert.awk (skipString/skipValue/skipObject/skipArray/
# findKeyInObjectAt/objectShapeAt/jsonEscape/validJson/upsertKeyValue) --
# duplicated rather than shared, per this codebase's own established
# convention for these walkers (see AgentsClaudeSettingsPermissionsUpsert.awk's
# own header comment).
#
# Params via ENVIRON:
#   MYX_WSRESTRICT_DENY_ADD_JSON      -- fixed permissions.deny addition, JSON
#                                        string array (literal)
#   MYX_WSRESTRICT_HOOKS_FILE         -- path to a plain text file, one hook
#                                        descriptor per line: `<dedupe-key>\t<PreToolUse-array-element-json>`.
#                                        <dedupe-key> is a plain substring (not
#                                        JSON) searched for within the CURRENT
#                                        hooks.PreToolUse array's raw text --
#                                        present means "already installed, skip";
#                                        absent means "append this element".
#   MYX_WSRESTRICT_ALLOW_SOURCE_ROOT  -- resolved `<workspace>/source` absolute
#                                        path (raw, not JSON-escaped -- escaped
#                                        here via jsonEscape() same as every
#                                        other value this script writes).
#                                        Upserted into permissions.allow as
#                                        `Read(//<this>/**)`. A prior grant for
#                                        a DIFFERENT source root (e.g. after a
#                                        workspace move) is replaced, not
#                                        accumulated alongside the new one --
#                                        same pattern
#                                        AgentsClaudeSettingsPermissionsUpsert.awk's
#                                        own board-grant replace uses.
#   MYX_WSRESTRICT_ALLOW_EXTRA_ROOTS_JSON -- fixed extra permissions.allow Read
#                                        roots, JSON string array (literal,
#                                        same shape as MYX_WSRESTRICT_DENY_ADD_JSON).
#                                        Each element is a raw absolute path,
#                                        upserted into permissions.allow as its
#                                        own `Read(//<element>/**)`. Unlike
#                                        MYX_WSRESTRICT_ALLOW_SOURCE_ROOT, these
#                                        are FIXED external reference roots --
#                                        not derived from the target workspace,
#                                        so there is no "workspace moved" stale
#                                        entry to replace: simple add-if-missing,
#                                        same as MYX_WSRESTRICT_DENY_ADD_JSON's
#                                        own merge (nothing removed if an
#                                        element is later dropped from the
#                                        caller's list).

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

# Sets ARR_FIRST, ARR_EMPTY. Restores p.
function arrayShapeAt(arrStart,   savedP) {
	savedP = p
	p = arrStart + 1
	skipws()
	ARR_FIRST = p
	ARR_EMPTY = (substr(s, p, 1) == "]") ? 1 : 0
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
# (0-based), returns the element count. Only ever called on permissions.deny,
# which this whole document's own writer (this script, going forward) never
# puts anything but plain strings into.
function stringArrayAt(arrStart,   count, elemStart) {
	p = arrStart + 1
	skipws()
	count = 0
	delete ELEMS
	if (substr(s, p, 1) == "]") return count
	while (1) {
		skipws()
		elemStart = p
		if (substr(s, p, 1) != "\"") fail("permissions-deny-element-not-a-string")
		skipString()
		ELEMS[count++] = substr(s, elemStart + 1, p - elemStart - 2)
		skipws()
		if (substr(s, p, 1) == ",") { p++; continue }
		if (substr(s, p, 1) == "]") { p++; return count }
		fail("permissions-deny-malformed")
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

# In-place insertion sort (byte/ASCII order, consistent under the caller's
# LC_ALL=C) -- permissions.deny is written sorted, not merge-order, so the
# generated config stays reviewable/diffable across runs. Same convention as
# AgentsClaudeSettingsPermissionsUpsert.awk.
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
# member, if absent) -- returns the whole new document.
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

# Ensures targetKey exists inside the object at objStart, creating it with
# emptyValueJson ("{}" or "[]") as the first member if absent. Returns the
# whole new document unchanged (a no-op copy) if the key was already present.
function ensureKey(objStart, targetKey, emptyValueJson,   sep, head, tail) {
	if (!findKeyInObjectAt(objStart, targetKey)) fail("unparsable")
	if (FOUND) return s
	objectShapeAt(objStart)
	sep = OBJ_EMPTY ? "" : ", "
	head = substr(s, 1, OBJ_FIRST - 1)
	tail = substr(s, OBJ_FIRST)
	return head "\"" jsonEscape(targetKey) "\": " emptyValueJson sep tail
}

# Appends elementJson as the new last element of the array at arrStart.
# Returns the whole new document.
function appendArrayElement(arrStart, elementJson,   savedP, closeAt, head, tail, sep) {
	savedP = p
	p = arrStart
	if (!skipArray()) fail("array-malformed")
	closeAt = p - 1
	arrayShapeAt(arrStart)
	sep = ARR_EMPTY ? "" : ", "
	head = substr(s, 1, closeAt - 1)
	tail = substr(s, closeAt)
	p = savedP
	return head sep elementJson tail
}

# Raw text of the array literal at arrStart, `[` through matching `]`
# inclusive -- used only for a plain substring dedupe check, never reparsed.
function arraySliceAt(arrStart,   savedP, closeAt, slice) {
	savedP = p
	p = arrStart
	if (!skipArray()) fail("array-malformed")
	closeAt = p - 1
	slice = substr(s, arrStart, closeAt - arrStart + 1)
	p = savedP
	return slice
}

BEGIN {
	denyAddRaw = ENVIRON["MYX_WSRESTRICT_DENY_ADD_JSON"]
	hooksFile = ENVIRON["MYX_WSRESTRICT_HOOKS_FILE"]
	allowSourceRoot = ENVIRON["MYX_WSRESTRICT_ALLOW_SOURCE_ROOT"]
	allowExtraRootsRaw = ENVIRON["MYX_WSRESTRICT_ALLOW_EXTRA_ROOTS_JSON"]
	if (denyAddRaw == "" || hooksFile == "" || allowSourceRoot == "" || allowExtraRootsRaw == "") fail("usage")
	if (!validJson(denyAddRaw, "[")) fail("deny-add-not-a-json-array")
	if (!validJson(allowExtraRootsRaw, "[")) fail("allow-extra-roots-not-a-json-array")

	s = denyAddRaw; n = length(s); p = 1; skipws()
	denyAddCount = stringArrayAt(p)
	for (i = 0; i < denyAddCount; i++) denyAdd[i] = ELEMS[i]

	s = allowExtraRootsRaw; n = length(s); p = 1; skipws()
	allowExtraRootsCount = stringArrayAt(p)
	for (i = 0; i < allowExtraRootsCount; i++) allowExtraRoots[i] = ELEMS[i]

	hooksCount = 0
	while ((getline hooksLine < hooksFile) > 0) {
		if (hooksLine == "") continue
		tabAt = index(hooksLine, "\t")
		if (tabAt == 0) fail("hooks-descriptor-malformed")
		hookKey[hooksCount] = substr(hooksLine, 1, tabAt - 1)
		hookJson[hooksCount] = substr(hooksLine, tabAt + 1)
		hooksCount++
	}
	close(hooksFile)
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
	## Standing Read grant on the target workspace's own source/ tree, so a
	## plain skillset/MAGIC.md read inside it never triggers an interactive
	## permission prompt -- covers every source-symlinked skillset file for
	## this workspace already (see AgentsTools.Install.include's
	## --install-skillset-symlinks: a member's skills-dir slot is a symlink
	## into this same source/ tree). Merge-only, same replace-not-accumulate
	## shape the deny section below and the sibling
	## AgentsClaudeSettingsPermissionsUpsert.awk's own board grant both use.
	s = ensureKey(rootStart, "permissions", "{}")
	n = length(s); p = 1; skipws(); rootStart = p
	if (!findKeyInObjectAt(rootStart, "permissions")) fail("unparsable")
	permStart = VALUE_START
	if (substr(s, permStart, 1) != "{") fail("permissions-not-an-object")

	s = ensureKey(permStart, "allow", "[]")
	n = length(s); p = 1; skipws(); rootStart = p
	if (!findKeyInObjectAt(rootStart, "permissions")) fail("unparsable")
	permStart = VALUE_START
	if (!findKeyInObjectAt(permStart, "allow") || !FOUND) fail("unparsable")
	if (substr(s, VALUE_START, 1) != "[") fail("allow-not-an-array")

	oldAllowCount = stringArrayAt(VALUE_START)
	for (i = 0; i < oldAllowCount; i++) oldAllow[i] = ELEMS[i]

	## `//` (not a single `/`) is required for an absolute filesystem path --
	## a single leading slash anchors at the settings source (e.g. $HOME for
	## a user-scope file), not the filesystem root (Claude Code's own
	## permissions docs, "Read and Edit" pattern table). allowSourceRoot is
	## already absolute (carries its own leading "/"), so exactly ONE more
	## "/" here yields the required "//" -- prepending "//" would double it.
	desiredAllowEntry = "Read(/" allowSourceRoot "/**)"
	newAllowCount = 0
	for (i = 0; i < oldAllowCount; i++) {
		v = oldAllow[i]
		if ((v ~ /^Read\(\/\/.*\/source\/\*\*\)$/) && v != desiredAllowEntry) continue
		newAllow[newAllowCount++] = v
	}
	if (!inList(newAllow, newAllowCount, desiredAllowEntry)) newAllow[newAllowCount++] = desiredAllowEntry

	## Fixed extra reference roots (MYX_WSRESTRICT_ALLOW_EXTRA_ROOTS_JSON) --
	## unlike allowSourceRoot above, these are NOT derived from the target
	## workspace, so there is no stale "workspace moved" entry to replace:
	## add-if-missing only, same shape MYX_WSRESTRICT_DENY_ADD_JSON's own merge
	## below uses.
	for (i = 0; i < allowExtraRootsCount; i++) {
		desiredExtraAllowEntry = "Read(/" allowExtraRoots[i] "/**)"
		if (!inList(newAllow, newAllowCount, desiredExtraAllowEntry)) newAllow[newAllowCount++] = desiredExtraAllowEntry
	}

	sortList(newAllow, newAllowCount)
	s = upsertKeyValue(permStart, "allow", arrayJson(newAllow, newAllowCount))

	## --- permissions.deny ---
	n = length(s); p = 1; skipws(); rootStart = p
	s = ensureKey(rootStart, "permissions", "{}")
	n = length(s); p = 1; skipws(); rootStart = p
	if (!findKeyInObjectAt(rootStart, "permissions")) fail("unparsable")
	permStart = VALUE_START
	if (substr(s, permStart, 1) != "{") fail("permissions-not-an-object")

	s = ensureKey(permStart, "deny", "[]")
	n = length(s); p = 1; skipws(); rootStart = p
	if (!findKeyInObjectAt(rootStart, "permissions")) fail("unparsable")
	permStart = VALUE_START
	if (!findKeyInObjectAt(permStart, "deny") || !FOUND) fail("unparsable")
	if (substr(s, VALUE_START, 1) != "[") fail("deny-not-an-array")

	oldDenyCount = stringArrayAt(VALUE_START)
	for (i = 0; i < oldDenyCount; i++) oldDeny[i] = ELEMS[i]
	newDenyCount = oldDenyCount
	for (i = 0; i < oldDenyCount; i++) newDeny[i] = oldDeny[i]
	for (i = 0; i < denyAddCount; i++) {
		if (!inList(newDeny, newDenyCount, denyAdd[i])) newDeny[newDenyCount++] = denyAdd[i]
	}
	sortList(newDeny, newDenyCount)
	s = upsertKeyValue(permStart, "deny", arrayJson(newDeny, newDenyCount))

	## --- hooks.PreToolUse ---
	n = length(s); p = 1; skipws(); rootStart = p
	s = ensureKey(rootStart, "hooks", "{}")
	n = length(s); p = 1; skipws(); rootStart = p
	if (!findKeyInObjectAt(rootStart, "hooks")) fail("unparsable")
	hooksStart = VALUE_START
	if (substr(s, hooksStart, 1) != "{") fail("hooks-not-an-object")

	s = ensureKey(hooksStart, "PreToolUse", "[]")
	n = length(s); p = 1; skipws(); rootStart = p
	if (!findKeyInObjectAt(rootStart, "hooks")) fail("unparsable")
	hooksStart = VALUE_START
	if (!findKeyInObjectAt(hooksStart, "PreToolUse") || !FOUND) fail("unparsable")
	if (substr(s, VALUE_START, 1) != "[") fail("pretooluse-not-an-array")

	for (i = 0; i < hooksCount; i++) {
		## re-locate fresh every iteration: an earlier append shifts every
		## later offset in the document.
		n = length(s); p = 1; skipws(); rootStart = p
		if (!findKeyInObjectAt(rootStart, "hooks")) fail("unparsable")
		hooksStart = VALUE_START
		if (!findKeyInObjectAt(hooksStart, "PreToolUse") || !FOUND) fail("unparsable")
		preToolUseStart = VALUE_START
		if (substr(s, preToolUseStart, 1) != "[") fail("pretooluse-not-an-array")

		slice = arraySliceAt(preToolUseStart)
		if (index(slice, hookKey[i]) > 0) continue
		s = appendArrayElement(preToolUseStart, hookJson[i])
	}

	if (!validJson(s, "{")) fail("generated-config-would-not-parse")
	## the doc/record join above drops the source file's own trailing
	## newline (awk's per-line read strips each record's terminator, and a
	## file ending in "\n" produces no further empty record to rejoin) --
	## restored once here rather than left off the whole document.
	printf "%s\n", s
}
