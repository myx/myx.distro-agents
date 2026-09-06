#!/usr/bin/env awk

# Verifies the Claude Code settings this package installs are present in one
# settings.json, as written by AgentsClaudeSettingsPermissionsUpsert.awk
# (~/.claude/settings.json) and AgentsClaudeWorkspaceRestrictionsUpsert.awk
# (<workspace>/.claude/settings.json). Reads the whole file itself, under the
# default RS and LC_ALL=C.
#
# Every requested setting gets its own `<where> <entry>: OK|MISSING` line, so a
# caller learns which particular setting is absent rather than that the file
# differs. Exits 1 when any is MISSING, or on a structural failure (one-word
# reason on stderr). An absent key is every one of its entries MISSING, never a
# file-level verdict: this asserts settings, never file existence.
#
# Same structural JSON-walker core as AgentsClaudeSettingsPermissionsUpsert.awk
# / AgentsMcpServerJsonUpsert.awk, duplicated rather than shared, per this
# codebase's own established convention for these walkers.
#
# Params via ENVIRON, each optional -- an empty one asserts nothing:
#   MYX_CLAUDEVERIFY_ALLOW_JSON       -- JSON string array, each element
#                                        required in `permissions.allow`
#   MYX_CLAUDEVERIFY_DENY_JSON        -- same, against `permissions.deny`
#   MYX_CLAUDEVERIFY_MCP_SERVERS_JSON -- same, against root
#                                        `enabledMcpjsonServers`
#   MYX_CLAUDEVERIFY_HOOK_KEYS        -- newline-separated plain substrings,
#                                        each required within the raw text of
#                                        `hooks.PreToolUse`. Same dedupe-key
#                                        mechanism the restrictions writer uses
#                                        to decide a hook is already installed.

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

# Parses a JSON array of plain strings at arrStart into ELEMS (0-based),
# returns the element count.
function stringArrayAt(arrStart,   count, elemStart) {
	p = arrStart + 1
	skipws()
	count = 0
	delete ELEMS
	if (substr(s, p, 1) == "]") return count
	while (1) {
		skipws()
		elemStart = p
		if (substr(s, p, 1) != "\"") fail("array-element-not-a-string")
		skipString()
		ELEMS[count++] = substr(s, elemStart + 1, p - elemStart - 2)
		skipws()
		if (substr(s, p, 1) == ",") { p++; continue ; }
		if (substr(s, p, 1) == "]") { p++; return count ; }
		fail("array-malformed")
	}
}

# Raw text of the array literal at arrStart, `[` through matching `]`
# inclusive -- used only for a plain substring test, never reparsed.
function arraySliceAt(arrStart,   closeAt) {
	p = arrStart
	if (!skipArray()) fail("array-malformed")
	closeAt = p - 1
	return substr(s, arrStart, closeAt - arrStart + 1)
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

# Switches the scan onto one wanted-entry literal, parses it, and copies the
# elements into wantList. Returns the element count.
function loadWanted(rawJson, wantList,   savedS, savedN, savedP, wantCount, i) {
	if (rawJson == "") return 0
	if (!validJson(rawJson, "[")) fail("wanted-not-a-json-array")
	savedS = s; savedN = n; savedP = p
	s = rawJson; n = length(s); p = 1
	skipws()
	wantCount = stringArrayAt(p)
	for (i = 0; i < wantCount; i++) wantList[i] = ELEMS[i]
	s = savedS; n = savedN; p = savedP
	return wantCount
}

# Reports every wanted entry against the string array at arrStart, one line
# each. arrFound 0 means the key is absent, which is every entry MISSING.
# Returns how many were missing.
function checkGroup(whereLabel, wantList, wantCount, arrStart, arrFound,   haveCount, i, j, seen, missingCount) {
	haveCount = 0
	if (arrFound) {
		if (substr(s, arrStart, 1) != "[") fail(whereLabel "-not-an-array")
		haveCount = stringArrayAt(arrStart)
	}
	missingCount = 0
	for (i = 0; i < wantCount; i++) {
		seen = 0
		for (j = 0; j < haveCount; j++) if (ELEMS[j] == wantList[i]) seen = 1
		printf "%s %s: %s\n", whereLabel, wantList[i], (seen ? "OK" : "MISSING")
		if (!seen) missingCount++
	}
	return missingCount
}

BEGIN {
	wantAllowCount = loadWanted(ENVIRON["MYX_CLAUDEVERIFY_ALLOW_JSON"], wantAllow)
	wantDenyCount = loadWanted(ENVIRON["MYX_CLAUDEVERIFY_DENY_JSON"], wantDeny)
	wantMcpCount = loadWanted(ENVIRON["MYX_CLAUDEVERIFY_MCP_SERVERS_JSON"], wantMcp)
	wantHookCount = split(ENVIRON["MYX_CLAUDEVERIFY_HOOK_KEYS"], wantHook, "\n")
}

# Rejoin the records under the default RS: a NUL RS is the empty string, which
# selects paragraph mode and would split the document on any blank line.
{ doc = (NR == 1) ? $0 : doc "\n" $0; }

END {
	if (FAILED) exit 1
	## No document at all is no settings at all -- every requested entry is
	## reported MISSING, which is the answer, not a parse failure.
	s = (doc == "") ? "{}" : doc
	n = length(s); p = 1
	skipws()
	if (substr(s, p, 1) != "{") fail("not-a-json-object")
	rootStart = p

	missingTotal = 0

	if (wantAllowCount > 0 || wantDenyCount > 0) {
		if (!findKeyInObjectAt(rootStart, "permissions")) fail("unparsable")
		permFound = FOUND
		permStart = VALUE_START
		if (permFound && substr(s, permStart, 1) != "{") fail("permissions-not-an-object")

		allowFound = 0
		if (permFound) {
			if (!findKeyInObjectAt(permStart, "allow")) fail("unparsable")
			allowFound = FOUND
			allowStart = VALUE_START
		}
		missingTotal += checkGroup("permissions.allow", wantAllow, wantAllowCount, allowStart, allowFound)

		denyFound = 0
		if (permFound) {
			if (!findKeyInObjectAt(permStart, "deny")) fail("unparsable")
			denyFound = FOUND
			denyStart = VALUE_START
		}
		missingTotal += checkGroup("permissions.deny", wantDeny, wantDenyCount, denyStart, denyFound)
	}

	if (wantMcpCount > 0) {
		if (!findKeyInObjectAt(rootStart, "enabledMcpjsonServers")) fail("unparsable")
		missingTotal += checkGroup("enabledMcpjsonServers", wantMcp, wantMcpCount, VALUE_START, FOUND)
	}

	## split() on an empty string yields 0 fields, so an unset hook-keys param
	## asserts nothing rather than testing one empty key.
	if (wantHookCount > 0) {
		hooksSlice = ""
		if (!findKeyInObjectAt(rootStart, "hooks")) fail("unparsable")
		if (FOUND) {
			hooksStart = VALUE_START
			if (substr(s, hooksStart, 1) != "{") fail("hooks-not-an-object")
			if (!findKeyInObjectAt(hooksStart, "PreToolUse")) fail("unparsable")
			if (FOUND) {
				if (substr(s, VALUE_START, 1) != "[") fail("PreToolUse-not-an-array")
				hooksSlice = arraySliceAt(VALUE_START)
			}
		}
		for (i = 1; i <= wantHookCount; i++) {
			seenHook = (hooksSlice != "" && index(hooksSlice, wantHook[i]) > 0)
			printf "%s %s: %s\n", "hooks.PreToolUse", wantHook[i], (seenHook ? "OK" : "MISSING")
			if (!seenHook) missingTotal++
		}
	}

	if (missingTotal > 0) exit 1
}
