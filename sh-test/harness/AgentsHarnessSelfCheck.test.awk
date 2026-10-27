#!/usr/bin/env awk

# Offline coherence check for a tool-calling harness: every tool must appear in
# all four of its structural sites, and nothing may appear in fewer. Prints one
# `<entry>: OK|FAIL` line plus an indented detail line per discrepancy, and
# exits 1 if any assertion failed. Issues no request and touches no host.
#
# THE FOUR SITES SPAN TWO FILES: the tools JSON literal is in the wire adapter,
# AgentsOpenAiChatWire.sh; the announce arm, the dispatch arm and the tool
# function are in AgentsUniversalHarness.sh. PASS BOTH -- passing one names the
# other in its failure. Function names derive from the declared name
# (Read -> AgentsHarnessToolRead), and every defined AgentsHarnessTool*
# is matched back to a live tool so an orphan is a FAIL.
#
# It proves coherence and nothing about behaviour. MAGIC.md's own "The harness
# instruments, and what each one proves" states what each of the four does not cover.

function pascal(snakeName,   nameParts, partCount, partIndex, outName) {
	partCount = split(snakeName, nameParts, "_")
	outName = ""
	for (partIndex = 1; partIndex <= partCount; partIndex++)
		outName = outName toupper(substr(nameParts[partIndex], 1, 1)) substr(nameParts[partIndex], 2)
	return outName
}

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

## Dispatch site: the case arms assigning harnessResult from a tool call.
/^[ \t]+[A-Za-z_]+\)[ \t]+harnessResult="\$\( AgentsHarnessTool/ {
	armName = $0 ; sub(/^[ \t]+/, "", armName) ; sub(/\).*$/, "", armName)
	siteSeen["dispatch", armName] = 1 ; toolNames[armName] = 1
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
		wantName = pascal(toolName)
		expectFn = "AgentsHarnessTool" wantName
		expectedFns[expectFn] = toolName
		if (!((("declared" SUBSEP toolName) in siteSeen)))  { failedAny = 1 ; missingDetail = missingDetail sprintf("\n    %s: declared site missing", toolName) ; }
		if (!((("announce" SUBSEP toolName) in siteSeen)))  { failedAny = 1 ; missingDetail = missingDetail sprintf("\n    %s: announce arm missing", toolName) ; }
		if (!((("dispatch" SUBSEP toolName) in siteSeen)))  { failedAny = 1 ; missingDetail = missingDetail sprintf("\n    %s: dispatch arm missing", toolName) ; }
		if (!(expectFn in fnDefined))                       { failedAny = 1 ; missingDetail = missingDetail sprintf("\n    %s: function %s missing", toolName, expectFn) ; }
	}

	## Read from the function side: the loop above fills toolNames from the other
	## three sites only, so a surviving orphan function is invisible to it.
	for (fnName in fnDefined) {
		if (!(fnName in expectedFns)) {
			failedAny = 1
			missingDetail = missingDetail sprintf("\n    %s: defined, but no tool declares, announces or dispatches it", fnName)
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
