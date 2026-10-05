#!/usr/bin/env awk

# Flags a statement sharing a line with its closing brace and no `;` before it.
# Some non-gawk awks reject that as a hard parse error while one-true-awk on a
# dev box accepts it, so a clean run here proves nothing about the fleet --
# which is why this is a check and not a convention anyone remembers.
# Prints one `<file>:<line>: <text>` per hit and exits 1; silent and 0 when clean.
#
# Own-line braces are the documented false positive and are skipped, as is a
# brace inside a quoted payload the file only transports.

## True when the line's last `}` closes an opener written as `${`. Openers are paired
## by nesting depth from the left; an unmatched close leaves the answer false.
function closesShellExpansion(text,   i, c, depth, openAt) {
	depth = 0
	for (i = 1 ; i <= length(text) ; i++) {
		c = substr(text, i, 1)
		if (c == "{") { depth++ ; openAt[depth] = i ; }
		else if (c == "}") {
			if (depth == 0) return 0
			if (i == length(text)) return (openAt[depth] > 1 && substr(text, openAt[depth] - 1, 1) == "$")
			depth--
		}
	}
	return 0
}

{
	lineText = $0
	sub(/^[ \t]+/, "", lineText)
	sub(/[ \t]+$/, "", lineText)
	## A comment is prose, and prose ends in a brace often enough to matter.
	if (lineText ~ /^#/) next
	if (lineText !~ /\}$/ || lineText == "}") next
	beforeBrace = substr(lineText, 1, length(lineText) - 1)
	sub(/[ \t]+$/, "", beforeBrace)
	if (beforeBrace == "" || beforeBrace ~ /;$/ || beforeBrace ~ /\{$/) next
	## A transported payload, not a program: quoted, or a JSON object literal.
	if (lineText ~ /^["\x27]/ || lineText ~ /"[ \t]*:[ \t]*["{[]/) next
	## A shell expansion, not a block: the brace the line ends on closes a `${`,
	## which awk has no syntax for, so the line is shell.
	if (closesShellExpansion(lineText)) next
	printf "%s:%d: %s\n", FILENAME, FNR, $0
	hitCount = hitCount + 1
}

END { exit (hitCount > 0 ? 1 : 0) ; }
