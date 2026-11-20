#!/usr/bin/env awk

# Flags a `}` sharing its line with code that does not end in `;` or `{` right before it.
# Every such brace is checked, not only the last: `{ if (a) { b = 1 } ; }` and `; } }` are faults,
# and the only forms are `; }` on the line or the `}` on a line of its own. Some non-gawk awks reject
# the fault as a hard parse error while one-true-awk on a dev box accepts it, so a clean run here
# proves nothing about the fleet -- which is why this is a check and not a convention anyone remembers.
# Prints one `<file>:<line>: <text>` per hit and exits 1; silent and 0 when clean.
#
# A brace inside a string, a regex literal, a comment or a shell `${...}` is not code, and is blanked
# in place before the scan. A line that is a quoted payload the file only transports is passed over.
#
# A PROGRAM IS ALSO QUOTED INSIDE A SHELL FILE. With AWK_AXIOM_SHELL set the input is a shell file,
# lexed by shellScan, and only the text of its awk programs is checked: a program opened and closed
# on one line, as in `awk '{ print $1 ; }'`, and every line of a program that spans lines.

## Lexes one shell line, carrying quote, `$( )` and command state over from the line before, and returns how many
## spans of the line are awk program text: spanFrom[n] to spanTo[n], columns of the line. A program is the text of a
## single quote whose own command names awk. The command is read outside quotes, restarts at | ; & and at a line not
## continued, and leaves out a ( ... ) closed before the quote. `'\''` is an apostrophe inside a quote, a `$'...'`
## is an ANSI-C string, and a word that starts with `#` outside any quote ends the line.
function shellScan(text,   scanAt, scanChar, scanCount, scanFrom) {
	scanCount = 0
	scanFrom = (shellQuote && inProgram) ? 1 : 0
	if (!shellQuote && !shellContinued && !shellDouble[shellDepth]) shellCommand[shellDepth] = ""
	for (scanAt = 1 ; scanAt <= length(text) ; scanAt++) {
		scanChar = substr(text, scanAt, 1)
		if (shellQuote) {
			if (scanChar != "'") continue
			if (substr(text, scanAt, 4) == "'\\''") { scanAt += 3 ; continue ; }
			if (inProgram) { spanFrom[++scanCount] = scanFrom ; spanTo[scanCount] = scanAt - 1 ; }
			shellQuote = 0
			inProgram = 0
			continue
		}
		if (scanChar == "\\") { scanAt++ ; continue ; }
		if (scanChar == "\"") { shellDouble[shellDepth] = !shellDouble[shellDepth] ; continue ; }
		if (scanChar == "$" && substr(text, scanAt + 1, 1) == "(") { scanAt++ ; shellDouble[++shellDepth] = 0 ; shellCommand[shellDepth] = "" ; continue ; }
		if (shellDouble[shellDepth]) continue
		if (scanChar == "(") { shellDouble[++shellDepth] = 0 ; shellCommand[shellDepth] = "" ; continue ; }
		if (scanChar == ")") { if (shellDepth > 0) shellDepth-- ; continue ; }
		if (scanChar == "#" && (scanAt == 1 || substr(text, scanAt - 1, 1) ~ /[ \t;|&]/)) break
		if (scanChar == "|" || scanChar == ";" || scanChar == "&") { shellCommand[shellDepth] = "" ; continue ; }
		if (scanChar == "'") {
			if (scanAt > 1 && substr(text, scanAt - 1, 1) == "$") {
				for (scanAt++ ; scanAt <= length(text) && substr(text, scanAt, 1) != "'" ; scanAt++) if (substr(text, scanAt, 1) == "\\") scanAt++
				continue
			}
			shellQuote = 1
			inProgram = (tolower(shellCommand[shellDepth]) ~ /awk/) ? 1 : 0
			scanFrom = scanAt + 1
			continue
		}
		shellCommand[shellDepth] = shellCommand[shellDepth] scanChar
	}
	if (shellQuote && inProgram && scanFrom <= length(text)) { spanFrom[++scanCount] = scanFrom ; spanTo[scanCount] = length(text) ; }
	shellContinued = (text ~ /\\$/)
	return scanCount
}

## The line with every string, regex literal, comment and `${...}` blanked in place, column for column.
## A `/` opens a regex where the code before it ends in nothing or an operator, so a division is left alone.
function codeOnly(text,   codeOut, codeAt, codeChar, codeState, codePrev, codeClass, codeDepth) {
	codeOut = "" ; codeState = "" ; codePrev = "" ; codeClass = 0 ; codeDepth = 0
	for (codeAt = 1 ; codeAt <= length(text) ; codeAt++) {
		codeChar = substr(text, codeAt, 1)
		if (codeState == "#") { codeOut = codeOut " " ; continue ; }
		if (codeState == "$") {
			if (codeChar == "{") codeDepth++
			else if (codeChar == "}" && --codeDepth == 0) codeState = ""
			codeOut = codeOut "x"
			continue
		}
		if (codeState == "\"" || codeState == "/") {
			if (codeChar == "\\") { codeOut = codeOut "xx" ; codeAt++ ; continue ; }
			if (codeState == "/" && !codeClass && codeChar == "[") codeClass = 1
			else if (codeClass && codeChar == "]") codeClass = 0
			else if (!codeClass && codeChar == codeState) { codeOut = codeOut codeChar ; codeState = "" ; codePrev = codeChar ; continue ; }
			codeOut = codeOut "x"
			continue
		}
		if (codeChar == "#") { codeState = "#" ; codeOut = codeOut " " ; continue ; }
		if (codeChar == "$" && substr(text, codeAt + 1, 1) == "{") { codeState = "$" ; codeOut = codeOut "x" ; continue ; }
		if (codeChar == "\"" || (codeChar == "/" && (codePrev == "" || index("(,~!{};&|=?:", codePrev)))) { codeState = codeChar ; codeClass = 0 ; codeOut = codeOut codeChar ; continue ; }
		codeOut = codeOut codeChar
		if (codeChar != " " && codeChar != "\t") codePrev = codeChar
	}
	return codeOut
}

## Whether a `}` in the text shares its line with code that does not end in `;` or `{` right before it.
function braceFault(text,   faultCode, faultAt, faultBefore) {
	faultCode = codeOnly(text)
	for (faultAt = 1 ; faultAt <= length(faultCode) ; faultAt++) {
		if (substr(faultCode, faultAt, 1) != "}") continue
		faultBefore = substr(faultCode, 1, faultAt - 1)
		sub(/[ \t]+$/, "", faultBefore)
		if (faultBefore != "" && faultBefore !~ /[;{]$/) return 1
	}
	return 0
}

FNR == 1 { shellQuote = 0 ; inProgram = 0 ; shellDepth = 0 ; shellContinued = 0 ; split("", shellDouble) ; split("", shellCommand) ; }
{
	lineHit = 0
	if (ENVIRON["AWK_AXIOM_SHELL"] != "") {
		for (spanAt = shellScan($0) ; spanAt >= 1 ; spanAt--) if (braceFault(substr($0, spanFrom[spanAt], spanTo[spanAt] - spanFrom[spanAt] + 1))) lineHit = 1
	}
	else {
		lineText = $0
		sub(/^[ \t]+/, "", lineText)
		## A comment is prose, and prose ends in a brace often enough to matter. A line opening with a quote, or a JSON
		## object literal, is a payload the file only transports.
		lineHit = lineText !~ /^#/ && lineText !~ /^["\x27]/ && lineText !~ /"[ \t]*:[ \t]*["{[]/ && braceFault($0)
	}
	if (!lineHit) next
	printf "%s:%d: %s\n", FILENAME, FNR, $0
	hitCount = hitCount + 1
}

END { exit (hitCount > 0 ? 1 : 0) ; }
