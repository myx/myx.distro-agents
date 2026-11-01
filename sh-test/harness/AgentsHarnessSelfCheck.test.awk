#!/usr/bin/env awk

# Offline coherence check for a tool-calling harness: every tool must appear in
# all four of its structural sites, and nothing may appear in fewer. Prints one
# `<entry>: OK|FAIL` line plus an indented detail line per discrepancy, and
# exits 1 if any assertion failed. Issues no request and touches no host.
#
# THE FOUR SITES SPAN TWO FILES: the tools JSON literal is in the wire adapter,
# AgentsOpenAiChatWire.sh; the announce arm, the dispatch arm and the tool
# function are in AgentsUniversalHarness.sh and the includes it sources. PASS BOTH -- passing one names the
# other in its failure. Functions are read off the core and are matched back to the
# arm that calls them, so a family of tools served by one shared handler is held to
# the same rule as a tool with a handler of its own, and an orphan handler is a FAIL.
#
# It proves coherence and nothing about behaviour. MAGIC.md's own "The harness
# instruments, and what each one proves" states what each of the four does not cover.

BEGIN { inAnnounce = 0 ; }

## Declaration site: matched on the literal envelope, since `name` also occurs
## inside parameter descriptions.
/\{"type":"function","function":\{"name":"/ {
	declLine = $0
	while (match(declLine, /\{"type":"function","function":\{"name":"[A-Za-z_]+"/)) {
		declFrag = substr(declLine, RSTART, RLENGTH)
		sub(/.*"name":"/, "", declFrag)
		sub(/"$/, "", declFrag)
		siteSeen["declared", declFrag] = 1 ; toolNames[declFrag] = 1
		declLine = substr(declLine, RSTART + RLENGTH)
	}
}

## Announce site: case arms inside AgentsHarnessAnnounceTool.
/^AgentsHarnessAnnounceTool\(\)/ { inAnnounce = 1 ; next ; }
inAnnounce && /^\}/ { inAnnounce = 0 ; next ; }
inAnnounce && /^[ \t]+[A-Za-z_]+\)[ \t]*$/ {
	armName = $0 ; sub(/^[ \t]+/, "", armName) ; sub(/\).*$/, "", armName)
	siteSeen["announce", armName] = 1 ; toolNames[armName] = 1
}

## Dispatch site: the case arms assigning harnessResult from a tool call. The handler a given arm calls
## is recorded too, so a tool served by a shared handler is held to the same thing as one with a
## handler of its own: the function its arm names must exist.
/^[ \t]+[A-Za-z_]+\)[ \t]+harnessResult="\$\( AgentsHarnessTool/ {
	armName = $0 ; sub(/^[ \t]+/, "", armName) ; sub(/\).*$/, "", armName)
	calledName = $0 ; sub(/.*harnessResult="\$\( /, "", calledName) ; sub(/[ \t].*$/, "", calledName)
	siteSeen["dispatch", armName] = 1 ; toolNames[armName] = 1
	dispatchCalls[armName] = calledName ; calledFns[calledName] = 1
}

## Function site.
/^AgentsHarnessTool[A-Za-z]+\(\)/ {
	fnName = $0 ; sub(/\(\).*$/, "", fnName)
	fnDefined[fnName] = 1
}

END {
	failedAny = 0
	missingDetail = ""
	for (toolName in toolNames) {
		if (!((("declared" SUBSEP toolName) in siteSeen)))  { failedAny = 1 ; missingDetail = missingDetail sprintf("\n    %s: declared site missing", toolName) ; }
		if (!((("announce" SUBSEP toolName) in siteSeen)))  { failedAny = 1 ; missingDetail = missingDetail sprintf("\n    %s: announce arm missing", toolName) ; }
		if (!((("dispatch" SUBSEP toolName) in siteSeen)))  { failedAny = 1 ; missingDetail = missingDetail sprintf("\n    %s: dispatch arm missing", toolName) ; }
		else if (!((dispatchCalls[toolName]) in fnDefined)) { failedAny = 1 ; missingDetail = missingDetail sprintf("\n    %s: its dispatch arm calls %s, which no function defines", toolName, dispatchCalls[toolName]) ; }
	}

	## Read from the function side: the loop above fills toolNames from the other three sites only, so a
	## handler no arm of any tool calls is invisible to it.
	for (fnName in fnDefined) {
		if (!(fnName in calledFns)) {
			failedAny = 1
			missingDetail = missingDetail sprintf("\n    %s: defined, but no dispatch arm calls it", fnName)
		}
	}

	toolTotal = 0
	for (toolName in toolNames) toolTotal++
	if (toolTotal == 0) {
		## An empty population cannot fail, so it is a FAIL rather than a pass.
		print "HARNESS_TOOL_SITES: FAIL"
		print "  warn: no tool declarations found -- the extraction did not match this file"
		print "  fix:  check that the harness still declares tools as {\"type\":\"function\",...}"
		exit 1
	}

	if (failedAny) {
		print "HARNESS_TOOL_SITES: FAIL"
		printf "  warn: %d tool(s) examined, and one or more is absent from a site it must occupy:%s\n", toolTotal, missingDetail
		print "  fix:  add the missing site, or remove the tool from the sites it still occupies"
		exit 1
	}

	printf "HARNESS_TOOL_SITES: OK (%d tools, four sites each)\n", toolTotal
	exit 0
}
