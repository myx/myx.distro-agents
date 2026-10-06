#!/usr/bin/env awk

# Run AFTER the field reader, as its driver -- never alone:
#   LC_ALL=C awk -f AgentsHarnessJsonField.awk -f AgentsHarnessArgTable.awk
# Reads one JSON object (stdin) -- a tool call's own `arguments` -- and prints every
# scalar leaf in it as one table, so the harness parses a call's arguments ONCE and
# answers each per-field lookup from builtins. There is no second JSON engine here:
# the walk is AgentsHarnessJsonField.awk's own, in its library mode (jfParseText fills
# jfLeaf/jfLeafSeen with the first value of every leaf), so each value is by
# construction what that reader prints for the same path.
# AgentsHarnessArgTableCheck.test.sh holds the two to the same answer anyway.
#
# Output, only when the whole input parses as one JSON object (rc 0):
#   !ok
#   <kind> TAB <path> TAB <value>      one line per distinct path
# <kind> is `v` for a top-level key spelled from [A-Za-z0-9_] alone, `d` for one that is
# `-` followed by those, and `p` for every other path -- the first two are the ones the
# shell may also hold as a variable named after the key. <path> and <value> are encoded
# for the shell's own `printf '%b'`: every backslash doubled, a newline as \n, a TAB as
# \t -- so no record spans lines and the first TAB always ends the path.
#
# rc 1 -- not a parseable JSON object; nothing is printed, which reads as every path
# absent, exactly as every AgentsHarnessJsonField.awk lookup on that input would.
#
# `-v lineId=<id>` is the per-line mode the MCP client reads a server's stdout with:
# every non-empty input line is its own document, and the LAST line whose top-level
# `id` -- trailing newlines dropped, as `$( ... )` drops them -- equals <id> is printed,
# encoded as above, on one line. Nothing printed is no such line. Always rc 0.
#
# LC_ALL=C IS REQUIRED -- every offset in the reader is a byte offset.

BEGIN {
	jfLibrary = 1
	atInput = ""
	atInputSeen = 0
	atLineFound = ""
}

## Linear, and the same on every awk: `&&` doubles a backslash without the replacement
## string's own backslash rules, which differ between awks, ever being involved; a
## split() on a backslash is a regex on one awk and a literal on another, so none here.
function atEncode(encText) {
	gsub(/\\/, "&&", encText)
	gsub(/\n/, "\\n", encText)
	gsub(/\t/, "\\t", encText)
	return encText
}

lineId != "" {
	if ($0 == "") next
	if (jfParseText($0) != 0) next
	if (!("id" in jfLeafSeen)) next
	atValue = jfLeaf["id"]
	while (substr(atValue, length(atValue), 1) == "\n") atValue = substr(atValue, 1, length(atValue) - 1)
	if (atValue == lineId) atLineFound = $0
	next
}

{
	if (atInputSeen) atInput = atInput "\n" $0
	else atInput = $0
	atInputSeen = 1
}

END {
	if (lineId != "") {
		if (atLineFound != "") print atEncode(atLineFound)
		exit 0
	}
	if (jfParseText(atInput) != 0) exit 1
	print "!ok"
	for (atPath in jfLeafSeen) {
		atKind = "p"
		if (atPath ~ /^[A-Za-z0-9_]+$/) atKind = "v"
		else if (atPath ~ /^-[A-Za-z0-9_]+$/) atKind = "d"
		printf "%s\t%s\t%s\n", atKind, atEncode(atPath), atEncode(jfLeaf[atPath])
	}
	exit 0
}
