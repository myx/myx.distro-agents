#!/usr/bin/env awk

# Flags a statement sharing a line with its closing brace and no `;` before it.
# Some non-gawk awks reject that as a hard parse error while one-true-awk on a
# dev box accepts it, so a clean run here proves nothing about the fleet --
# which is why this is a check and not a convention anyone remembers.
# Prints one `<file>:<line>: <text>` per hit and exits 1; silent and 0 when clean.
#
# Own-line braces are the documented false positive and are skipped, as is a
# brace inside a quoted payload the file only transports.
#
# A PROGRAM IS ALSO QUOTED INSIDE A SHELL FILE, and that was where the axiom went
# unenforced: the checker read awk sources only, so an awk program held in a `sh`
# file's single quotes was never looked at. With -v awkShell=1 the input is a shell
# file, and only the lines inside a single-quoted region opened on a line naming awk
# are checked. Every other line of that file is shell and is passed over.

## True while the line is inside such a region, and the region's own opening line
## is the one that names awk. The name is read whatever its case, since a shell
## variable holding a program is written `rigSpinAwk=`. `'\''` is the shell's
## apostrophe, so it closes and reopens one literal: those characters are taken
## together and the region goes on.
function shellRegion(text,   i, c) {
	for (i = 1 ; i <= length(text) ; i++) {
		c = substr(text, i, 1)
		if (c != "'") continue
		if (substr(text, i, 3) == "'\\''") { i = i + 2 ; continue }
		if (inProgram) { inProgram = 0 ; continue }
		inProgram = (tolower(substr(text, 1, i - 1)) ~ /awk/) ? 1 : 0
	}
	return inProgram
}

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

BEGIN { inProgram = 0 }
{
	if (ENVIRON["AWK_AXIOM_SHELL"] != "") { if (!shellRegion($0)) next }
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
