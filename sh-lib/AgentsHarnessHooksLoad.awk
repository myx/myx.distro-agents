#!/usr/bin/env awk

# The PreToolUse hook list of one .claude/settings.json (the input), in ONE parse.
# Loaded after the field reader as a library:
#   LC_ALL=C awk -f AgentsHarnessJsonField.awk -f AgentsHarnessHooksLoad.awk settings.json
# It concludes exactly what the per-field walk it replaces concluded, one field read at a
# time: every value taken as `$( reader )` held it (trailing newlines dropped), an absent
# matcher as "", an entry's checks in the walk's order, the first fault ending the walk.
# ENVIRON["AGENTS_HOOKS_REROUTE_KEYS"] is the deny-reroute key list, one per line; a
# command holding any key as a plain substring is skipped and counted, never listed.
#
# stdout, always rc 0: one head line `<fault> TAB <entry> TAB <inner> TAB <skipped>`,
# fault one of none | parse | hooks | command | tab (the shell words it), then the list,
# `matcher TAB command` per line, as far as the walk got.
#
# LC_ALL=C IS REQUIRED, as it is for the reader this loads.

BEGIN {
	jfLibrary = 1
}

{
	hooksDoc = (NR > 1) ? hooksDoc "\n" $0 : $0
}

function hooksValue(valuePath,   valueText) {
	if (!(valuePath in jfLeafSeen)) return ""
	valueText = jfLeaf[valuePath]
	while (substr(valueText, length(valueText), 1) == "\n") valueText = substr(valueText, 1, length(valueText) - 1)
	return valueText
}

## A count as `[ "$n" -lt "$count" ] 2>/dev/null` read it: an integer, or no loop at all.
function hooksCount(countPath,   countText) {
	countText = hooksValue(countPath)
	if (countText !~ /^[ \t\n]*[-+]?[0-9]+[ \t\n]*$/) return 0
	return countText + 0
}

END {
	hooksKeyCount = 0
	hooksKeyLines = split(ENVIRON["AGENTS_HOOKS_REROUTE_KEYS"], hooksKeyLine, "\n")
	for (hooksKeyAt = 1 ; hooksKeyAt <= hooksKeyLines ; hooksKeyAt++) {
		if (hooksKeyLine[hooksKeyAt] != "") hooksKey[++hooksKeyCount] = hooksKeyLine[hooksKeyAt]
	}
	hooksFault = "none" ; hooksAtEntry = "" ; hooksAtInner = "" ; hooksSkipped = 0 ; hooksList = ""
	if (jfParseText(hooksDoc) != 0) {
		hooksFault = "parse"
	} else if ("hooks.PreToolUse.__count" in jfLeafSeen) {
		hooksEntryCount = hooksCount("hooks.PreToolUse.__count")
		for (hooksEntry = 0 ; hooksEntry < hooksEntryCount && hooksFault == "none" ; hooksEntry++) {
			hooksMatcher = hooksValue("hooks.PreToolUse." hooksEntry ".matcher")
			if (!(("hooks.PreToolUse." hooksEntry ".hooks.__count") in jfLeafSeen)) {
				hooksFault = "hooks" ; hooksAtEntry = hooksEntry
				break
			}
			hooksInnerCount = hooksCount("hooks.PreToolUse." hooksEntry ".hooks.__count")
			for (hooksInner = 0 ; hooksInner < hooksInnerCount ; hooksInner++) {
				hooksType = hooksValue("hooks.PreToolUse." hooksEntry ".hooks." hooksInner ".type")
				hooksCommand = hooksValue("hooks.PreToolUse." hooksEntry ".hooks." hooksInner ".command")
				if (hooksType != "command" || hooksCommand == "") {
					hooksFault = "command" ; hooksAtEntry = hooksEntry ; hooksAtInner = hooksInner
					break
				}
				hooksReroute = 0
				for (hooksKeyAt = 1 ; hooksKeyAt <= hooksKeyCount ; hooksKeyAt++) {
					if (index(hooksCommand, hooksKey[hooksKeyAt])) { hooksReroute = 1 ; break ; }
				}
				if (hooksReroute) { hooksSkipped++ ; continue ; }
				if (index(hooksMatcher hooksCommand, "\t") || index(hooksMatcher hooksCommand, "\n")) {
					hooksFault = "tab" ; hooksAtEntry = hooksEntry
					break
				}
				hooksList = hooksList hooksMatcher "\t" hooksCommand "\n"
			}
		}
	}
	printf("%s\t%s\t%s\t%d\n%s", hooksFault, hooksAtEntry, hooksAtInner, hooksSkipped, hooksList)
	exit 0
}
