#!/usr/bin/env awk

# Upserts myx.distro-agents' workspace-level Claude Code restrictions into a
# TARGET WORKSPACE's own `.claude/settings.json`: `permissions.deny` entries
# plus `hooks.PreToolUse` entries. Merge-only, awk (no jq dependency).
# DistroAgentsTools.fn.sh --install-workspace-restrictions
# (AgentsTools.Install.include) is the only caller.
#
# Every entry already present that this script did not itself add is kept, in
# its original position. The removals are a hooks.PreToolUse entry running a
# retired hook script (MYX_WSRESTRICT_RETIRED_HOOKS), a permissions.deny entry
# equal to a retired one (MYX_WSRESTRICT_RETIRED_DENY), and the permissions.allow
# file grants earlier installs wrote (MYX_WSRESTRICT_RETIRED_ALLOW, and a Read on a
# workspace source/ or .agents root, by its shape): this script writes no
# permissions.allow entry at all, the PreToolUse hooks decide. Everything else only
# appends missing entries. Prints the new document on stdout; never opens the
# target itself.
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
#                                        descriptor per line: `<dedupe-key>\t<PreToolUse-array-element-json>`,
#                                        or `...\t<event>` to add the element under
#                                        that hooks event instead of PreToolUse.
#                                        <dedupe-key> is a plain substring (not
#                                        JSON) searched for within the CURRENT
#                                        hooks.PreToolUse array's raw text --
#                                        present means "already installed, skip";
#                                        absent means "append this element".
#   MYX_WSRESTRICT_RETIRED_ALLOW      -- the permissions.allow entries earlier
#                                        installs wrote, one per line, each the
#                                        exact entry text. An entry equal to one
#                                        is removed; nothing else is, so a rule
#                                        the user added stays. Beside these, a
#                                        `Read|Edit|Write(//<path>/source/**)` and
#                                        a `Read(//<path>/.agents/**)` go by their
#                                        shape, as a moved workspace's always
#                                        did. Optional -- unset removes only
#                                        those two shapes.
#   MYX_WSRESTRICT_RETIRED_HOOKS      -- retired hook script names, one per
#                                        line. A hooks.PreToolUse entry whose
#                                        raw text runs `.claude/hooks/<name>`
#                                        is removed, and the entries around it
#                                        keep their text. Optional -- unset
#                                        removes nothing.
#   MYX_WSRESTRICT_SETTINGS           -- top-level settings the restrictions set
#                                        fixes, one per line: `<key>\t<value>`,
#                                        the value a JSON scalar (true, false,
#                                        null, an integer or a plain string).
#                                        Each key is set to exactly that value,
#                                        added if absent; no other key is touched.
#                                        Optional -- unset sets nothing.
#   MYX_WSRESTRICT_RETIRED_DENY       -- retired permissions.deny entries, one
#                                        per line, each the exact entry text an
#                                        earlier install wrote. An entry equal
#                                        to one is removed; nothing else is.
#                                        Optional -- unset removes nothing.

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
	if (ok) { skipws(); ok = (p > n) ; }
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
		if (substr(s, p, 1) == ",") { p++; continue ; }
		if (substr(s, p, 1) == "]") { p++; return count ; }
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
	if (denyAddRaw == "" || hooksFile == "") fail("usage")
	if (!validJson(denyAddRaw, "[")) fail("deny-add-not-a-json-array")
	retiredCount = split(ENVIRON["MYX_WSRESTRICT_RETIRED_HOOKS"], retiredHook, "\n")
	retiredDenyCount = split(ENVIRON["MYX_WSRESTRICT_RETIRED_DENY"], retiredDeny, "\n")
	retiredAllowLines = split(ENVIRON["MYX_WSRESTRICT_RETIRED_ALLOW"], retiredAllowLine, "\n")
	for (i = 1; i <= retiredAllowLines; i++) if (retiredAllowLine[i] != "") retiredAllow[retiredAllowLine[i]] = 1
	settingsCount = 0
	settingsLines = split(ENVIRON["MYX_WSRESTRICT_SETTINGS"], settingsLine, "\n")
	for (i = 1; i <= settingsLines; i++) {
		if (settingsLine[i] == "") continue
		tabAt = index(settingsLine[i], "\t")
		if (tabAt < 2) fail("settings-descriptor-malformed")
		settingKey[settingsCount] = substr(settingsLine[i], 1, tabAt - 1)
		settingValue[settingsCount] = substr(settingsLine[i], tabAt + 1)
		if (settingKey[settingsCount] !~ /^[A-Za-z][A-Za-z0-9_]*$/) fail("settings-descriptor-malformed")
		if (settingValue[settingsCount] !~ /^(true|false|null|-?[0-9]+|"[^"\\]*")$/) fail("settings-descriptor-malformed")
		settingsCount++
	}

	s = denyAddRaw; n = length(s); p = 1; skipws()
	denyAddCount = stringArrayAt(p)
	for (i = 0; i < denyAddCount; i++) denyAdd[i] = ELEMS[i]

	hooksCount = 0
	while ((getline hooksLine < hooksFile) > 0) {
		if (hooksLine == "") continue
		tabAt = index(hooksLine, "\t")
		if (tabAt == 0) fail("hooks-descriptor-malformed")
		hookKey[hooksCount] = substr(hooksLine, 1, tabAt - 1)
		hookJson[hooksCount] = substr(hooksLine, tabAt + 1)
		## An optional third field names the hooks event; without it the entry is PreToolUse.
		hookEvent[hooksCount] = "PreToolUse"
		tabAt = index(hookJson[hooksCount], "\t")
		if (tabAt > 0) {
			hookEvent[hooksCount] = substr(hookJson[hooksCount], tabAt + 1)
			hookJson[hooksCount] = substr(hookJson[hooksCount], 1, tabAt - 1)
			if (hookEvent[hooksCount] !~ /^[A-Za-z]+$/) fail("hooks-descriptor-malformed")
		}
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
	## No file grant is written here: the PreToolUse hooks decide every call. The
	## ones earlier installs wrote go -- the retired entries on an exact match, and
	## a Read on a workspace source/ or .agents root by its shape, as a moved
	## workspace's always did -- and every other entry stays where it is. An array
	## with nothing to drop, or none at all, is left exactly as it stands.
	if (!findKeyInObjectAt(rootStart, "permissions")) fail("unparsable")
	if (FOUND && substr(s, VALUE_START, 1) == "{") {
		permStart = VALUE_START
		if (!findKeyInObjectAt(permStart, "allow")) fail("unparsable")
		if (FOUND) {
			if (substr(s, VALUE_START, 1) != "[") fail("allow-not-an-array")
			oldAllowCount = stringArrayAt(VALUE_START)
			for (i = 0; i < oldAllowCount; i++) oldAllow[i] = ELEMS[i]
			newAllowCount = 0
			for (i = 0; i < oldAllowCount; i++) {
				v = oldAllow[i]
				if (v ~ /^(Read|Edit|Write)\(\/\/.*\/source\/\*\*\)$/) continue
				if (v ~ /^Read\(\/\/.*\/\.agents\/\*\*\)$/) continue
				if (v in retiredAllow) continue
				newAllow[newAllowCount++] = v
			}
			if (newAllowCount < oldAllowCount) s = upsertKeyValue(permStart, "allow", arrayJson(newAllow, newAllowCount))
		}
	}

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
	## A retired entry goes on an exact match only, so a user's own rule stays.
	newDenyCount = 0
	for (i = 0; i < oldDenyCount; i++) {
		denyRetired = 0
		for (j = 1; j <= retiredDenyCount; j++) if (retiredDeny[j] != "" && oldDeny[i] == retiredDeny[j]) denyRetired = 1
		if (!denyRetired) newDeny[newDenyCount++] = oldDeny[i]
	}
	for (i = 0; i < denyAddCount; i++) {
		if (!inList(newDeny, newDenyCount, denyAdd[i])) newDeny[newDenyCount++] = denyAdd[i]
	}
	sortList(newDeny, newDenyCount)
	s = upsertKeyValue(permStart, "deny", arrayJson(newDeny, newDenyCount))

	## --- fixed top-level settings ---
	for (i = 0; i < settingsCount; i++) {
		n = length(s); p = 1; skipws(); rootStart = p
		s = upsertKeyValue(rootStart, settingKey[i], settingValue[i])
	}

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

	## Entries running a retired hook script go before anything is appended.
	## A kept entry carries the gap before it, comma included, except the
	## first kept one, which takes the gap after `[`.
	preToolUseStart = VALUE_START
	p = preToolUseStart + 1
	skipws()
	elemCount = 0
	while (substr(s, p, 1) != "]") {
		elemStart[elemCount] = p
		if (!skipValue()) fail("pretooluse-malformed")
		elemEnd[elemCount++] = p
		skipws()
		if (substr(s, p, 1) == ",") { p++; skipws() ; }
	}
	keptText = ""
	keptCount = 0
	for (i = 0; i < elemCount; i++) {
		elemText = substr(s, elemStart[i], elemEnd[i] - elemStart[i])
		elemRetired = 0
		for (j = 1; j <= retiredCount; j++) {
			if (retiredHook[j] == "") continue
			## The name ends where the JSON string does, or where an argument starts.
			if (index(elemText, ".claude/hooks/" retiredHook[j] "\"") > 0 || index(elemText, ".claude/hooks/" retiredHook[j] "\\\"") > 0 || index(elemText, ".claude/hooks/" retiredHook[j] " ") > 0) elemRetired = 1
		}
		if (elemRetired) continue
		if (keptCount > 0) keptText = keptText substr(s, elemEnd[i - 1], elemStart[i] - elemEnd[i - 1])
		keptText = keptText elemText
		keptCount++
	}
	if (keptCount == 0 && elemCount > 0) s = substr(s, 1, preToolUseStart) substr(s, p)
	else if (keptCount < elemCount) s = substr(s, 1, elemStart[0] - 1) keptText substr(s, elemEnd[elemCount - 1])

	for (i = 0; i < hooksCount; i++) {
		## re-locate fresh every iteration: an earlier append shifts every
		## later offset in the document.
		n = length(s); p = 1; skipws(); rootStart = p
		if (!findKeyInObjectAt(rootStart, "hooks")) fail("unparsable")
		hooksStart = VALUE_START
		s = ensureKey(hooksStart, hookEvent[i], "[]")
		n = length(s); p = 1; skipws(); rootStart = p
		if (!findKeyInObjectAt(rootStart, "hooks")) fail("unparsable")
		hooksStart = VALUE_START
		if (!findKeyInObjectAt(hooksStart, hookEvent[i]) || !FOUND) fail("unparsable")
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
