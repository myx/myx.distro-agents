#!/usr/bin/env awk

# Reads the harness tool declarations -- the `harnessToolsJson` array, stdin --
# in ONE pass and prints them as one MCP tools/list array,
# [{"name":..,"description":..,"inputSchema":..},...], from each declaration's
# function.name, function.description and function.parameters. Every value is
# the RAW SOURCE TEXT the array carried: nothing is decoded or re-escaped,
# because a value already escaped for the wire is already escaped for MCP.
#
# `-v exclude="A B"` leaves out each declaration whose bare name is listed.
# The array is printed only once everything has parsed, so a failure leaves
# stdout empty.
#
# rc 0 printed -- rc 1 not one parseable JSON array, a declaration missing
# function.name, .description or .parameters, or nothing left to print.
#
# LC_ALL=C IS REQUIRED -- the walk indexes a byte array from split(s, sc, "")
# and slices with substr(), and the two must count the same bytes.

BEGIN {
	split(exclude, excludeNames, " ")
	for (excludeIndex in excludeNames) isExcluded["\"" excludeNames[excludeIndex] "\""] = 1
	inputText = ""
	inputSeen = 0
	toolCount = 0
	structErr = 0
}

function skipws(   curChar) {
	while (scanPos <= scanLen) {
		curChar = scanChars[scanPos]
		if (curChar == " " || curChar == "\t" || curChar == "\n" || curChar == "\r") scanPos++
		else break
	}
}

## Advances past one string and returns its source text without the quotes.
function scanString(   startPos, curChar, isClosed) {
	startPos = scanPos
	scanPos++
	isClosed = 0
	while (scanPos <= scanLen) {
		curChar = scanChars[scanPos]
		if (curChar == "\\") { scanPos = scanPos + 2 ; continue ; }
		scanPos++
		if (curChar == "\"") { isClosed = 1 ; break ; }
	}
	if (!isClosed) structErr = 1
	return substr(inputText, startPos + 1, scanPos - startPos - 2)
}

## nodeRole is where this value sits: "top", "tool", "function", or the field
## name it is kept as -- "name", "description", "parameters" -- else "".
function scanValue(nodeRole,   startPos, curChar) {
	skipws()
	startPos = scanPos
	curChar = scanChars[scanPos]
	if (curChar == "\"") scanString()
	else if (curChar == "{") scanObject(nodeRole)
	else if (curChar == "[") scanArray(nodeRole)
	else {
		while (scanPos <= scanLen) {
			curChar = scanChars[scanPos]
			if (curChar == "," || curChar == "}" || curChar == "]" || curChar == " " || curChar == "\t" || curChar == "\n" || curChar == "\r") break
			scanPos++
		}
		## A zero-length run cannot begin a value, so `{"a":}` is refused.
		if (scanPos == startPos) { structErr = 1 ; return ; }
	}
	if ((nodeRole == "name" || nodeRole == "description" || nodeRole == "parameters") && !((toolCount, nodeRole) in toolField)) {
		toolField[toolCount, nodeRole] = substr(inputText, startPos, scanPos - startPos)
	}
}

function scanObject(nodeRole,   keyName, childRole, curChar) {
	scanPos++
	skipws()
	if (scanChars[scanPos] == "}") { scanPos++ ; return ; }
	while (!structErr) {
		skipws()
		## A key is a string and the separator is required: consuming either blindly
		## reads `{"a" 1}` as a well-formed object.
		if (scanChars[scanPos] != "\"") { structErr = 1 ; return ; }
		keyName = scanString()
		skipws()
		if (scanChars[scanPos] != ":") { structErr = 1 ; return ; }
		scanPos++
		childRole = ""
		if (nodeRole == "tool" && keyName == "function") childRole = "function"
		else if (nodeRole == "function" && (keyName == "name" || keyName == "description" || keyName == "parameters")) childRole = keyName
		scanValue(childRole)
		skipws()
		curChar = scanChars[scanPos]
		if (curChar == ",") { scanPos++ ; continue ; }
		else if (curChar == "}") { scanPos++ ; break ; }
		else { structErr = 1 ; break ; }
	}
}

function scanArray(nodeRole,   curChar) {
	scanPos++
	skipws()
	if (scanChars[scanPos] == "]") { scanPos++ ; return ; }
	while (!structErr) {
		if (nodeRole == "top") {
			toolCount++
			scanValue("tool")
		}
		else scanValue("")
		skipws()
		curChar = scanChars[scanPos]
		if (curChar == ",") { scanPos++ ; continue ; }
		else if (curChar == "]") { scanPos++ ; break ; }
		else { structErr = 1 ; break ; }
	}
}

{
	if (inputSeen) inputText = inputText "\n" $0
	else inputText = $0
	inputSeen = 1
}

END {
	scanLen = split(inputText, scanChars, "")
	scanPos = 1

	skipws()
	if (scanPos > scanLen || scanChars[scanPos] != "[") {
		printf("⛔ ERROR: AgentsHarnessMcpMirror.awk: input is not a JSON array -- an empty read, or a literal that no longer opens with [\n") > "/dev/stderr"
		exit 1
	}

	scanValue("top")
	skipws()

	if (structErr || scanPos <= scanLen) {
		printf("⛔ ERROR: AgentsHarnessMcpMirror.awk: the tool declarations are NOT VALID JSON -- the parser refused them at byte %d, in or right after declaration %d\n", scanPos, toolCount - 1) > "/dev/stderr"
		printf("  fix:  repair the JSON -- most often a missing comma between two declarations\n") > "/dev/stderr"
		exit 1
	}

	if (toolCount == 0) {
		## An empty population cannot fail, so it is a FAIL rather than a pass.
		printf("⛔ ERROR: AgentsHarnessMcpMirror.awk: the array parsed but declares no tools at all, so the mirror would advertise an empty floor\n") > "/dev/stderr"
		printf("  fix:  check that the array still holds one object per tool\n") > "/dev/stderr"
		exit 1
	}

	mirrorOut = ""
	for (toolIndex = 1; toolIndex <= toolCount; toolIndex++) {
		## A mirrored tool the caller cannot name, read or call is worse than an absent
		## one: it reaches a native console as a tool that exists and refuses.
		if (!((toolIndex, "name") in toolField)) {
			printf("⛔ ERROR: AgentsHarnessMcpMirror.awk: declaration %d parses but carries no function.name, so no refusal could name the method a caller should use instead\n", toolIndex - 1) > "/dev/stderr"
			printf("  fix:  give that declaration its own \"name\"\n") > "/dev/stderr"
			exit 1
		}
		if (!((toolIndex, "description") in toolField)) {
			printf("⛔ ERROR: AgentsHarnessMcpMirror.awk: declaration %d (%s) carries no function.description, so a caller is offered a tool with nothing saying what it does\n", toolIndex - 1, toolField[toolIndex, "name"]) > "/dev/stderr"
			printf("  fix:  give that declaration its own \"description\"\n") > "/dev/stderr"
			exit 1
		}
		if (!((toolIndex, "parameters") in toolField)) {
			printf("⛔ ERROR: AgentsHarnessMcpMirror.awk: declaration %d (%s) carries no function.parameters, and MCP has no default for a missing inputSchema\n", toolIndex - 1, toolField[toolIndex, "name"]) > "/dev/stderr"
			printf("  fix:  give that declaration its own \"parameters\" object\n") > "/dev/stderr"
			exit 1
		}
		if (toolField[toolIndex, "name"] in isExcluded) continue
		if (mirrorOut != "") mirrorOut = mirrorOut ","
		mirrorOut = mirrorOut "{\"name\":" toolField[toolIndex, "name"] ",\"description\":" toolField[toolIndex, "description"] ",\"inputSchema\":" toolField[toolIndex, "parameters"] "}"
	}

	if (mirrorOut == "") {
		printf("⛔ ERROR: AgentsHarnessMcpMirror.awk: every declaration is excluded (exclude=\"%s\"), so the mirror would advertise an empty floor\n", exclude) > "/dev/stderr"
		exit 1
	}

	printf("[%s]\n", mirrorOut)
	exit 0
}