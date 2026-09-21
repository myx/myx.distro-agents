#!/usr/bin/env awk

# Flags a statement sharing a line with its closing brace and no `;` before it.
# Some non-gawk awks reject that as a hard parse error while one-true-awk on a
# dev box accepts it, so a clean run here proves nothing about the fleet --
# which is why this is a check and not a convention anyone remembers.
# Prints one `<file>:<line>: <text>` per hit and exits 1; silent and 0 when clean.
#
# Own-line braces are the documented false positive and are skipped, as is a
# brace inside a quoted payload the file only transports.

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
	printf "%s:%d: %s\n", FILENAME, FNR, $0
	hitCount = hitCount + 1
}

END { exit (hitCount > 0 ? 1 : 0) ; }
