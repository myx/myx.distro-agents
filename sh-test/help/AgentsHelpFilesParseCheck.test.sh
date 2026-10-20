#!/usr/bin/env bash
## Behavioural check on the help files of the family (F7.6 of the refactorings epic: ".help.md files parse correctly for the completion utilities,
## help renderers and mixers. .help.include files too"), run rather than read, over EVERY help file of all six myx.distro-* packages: .local,
## agents, deploy, remote, source and system. A help file here is a `*.help.md` (the manual a `--help` renders) and a `Help*.include` (the code a
## `--help` runs, which prints the `syntax:` lines of the command and renders its manual). They are parsed by the code that reads them:
##   - a manual by the renderer of the family, `myx.common lib/catMarkdown`, of the origin under test, in the text form (--strip-all) and in the form
##     the manager screen draws from (--spans), whose rows are checked against their own spans;
##   - an include by running it the way the completion utility and the command do: `<command> --help`, with the include sourced under `--help`,
##     where `myx.common lib/catMarkdown` and `CatMarkdown` are the renderer of the origin and nothing else is on the path.
## Every failure is a row `<file>:<line>: <rule>: <text>`, the file below myx/. The rules: render-text, render-spans, front-matter, code-fence,
## control-char, syntax-line (a manual and an include), bash-n, run-help, md-reference and no-help.
## Held:
##   1. All of the six packages: every manual and every include parses, and not one row is found. The numbers of files found are said, and each
##      package must have both kinds (a package that lost its help files is a failure, not an empty pass).
##   2. The check is able to fail, each time naming the file and the line: a tree of seeded defects (a stray `fi`, a command that is not there, a
##      syntax line that names no command, a manual that is not there, an unclosed code fence, a front matter never closed, a carriage return, an
##      empty manual, an include that prints nothing) gives exactly the row of each, and the pair that is well made gives none.
## Offline, rig tree only: nothing but the renderer of the origin is run.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigMyxRoot="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
rigCatMarkdown="$rigMyxRoot/bin/lib/catMarkdown.Common"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigCatMarkdown" ] || rigRefuse "the renderer is not at the origin this workspace resolves: $rigCatMarkdown"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHelpFilesParseCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
mkdir -p "$rigTmp/bin" "$rigTmp/ws"
## The renderer of the origin under test is the only one there is: `myx.common lib/catMarkdown`, as the includes call it, and nothing else.
cat > "$rigTmp/bin/myx.common" <<'RIGSHIM'
#!/bin/sh
[ "$1" = lib/catMarkdown ] || { echo "myx.common shim: only lib/catMarkdown is run here, not: $1" >&2 ; exit 99 ; }
shift
MYXROOT="$RIG_MYXROOT" exec bash "$RIG_MYXROOT/bin/lib/catMarkdown.Common" "$@"
RIGSHIM
chmod +x "$rigTmp/bin/myx.common"
export TZ=UTC
unset NO_COLOR

## ---- the scan ----
rigRows="$rigTmp/rows" rigManuals=0 rigIncludes=0
rigRow(){ ## file below myx/, line, rule, text
	printf '%s:%s: %s: %s\n' "$1" "$2" "$3" "$4" >> "$rigRows"
}
rigLineOf(){ ## file, fixed text -- the first line of the file holding the text, else 1
	local lineOf
	lineOf="$( LC_ALL=C grep -n -F -m 1 -- "$2" "$1" 2> /dev/null | LC_ALL=C sed -n '1s/:.*//p' )"
	printf '%s\n' "${lineOf:-1}"
}
## The rows of one manual: the renderer in both forms, then what the lines themselves must be.
rigScanManual(){ ## root, file below myx/
	local scanFile="$1/myx/$2" scanOut="$rigTmp/render.out" scanRc scanRow scanReason scanText
	rigManuals=$(( rigManuals + 1 ))
	MYXROOT="$rigMyxRoot" bash "$rigCatMarkdown" --strip-all "$scanFile" > "$scanOut" 2> "$rigTmp/render.err" ; scanRc=$?
	if [ "$scanRc" != 0 ] ; then rigRow "$2" 1 render-text "the renderer ends with status $scanRc: $( LC_ALL=C sed -n 1p "$rigTmp/render.err" | LC_ALL=C cut -c1-120 )"
	elif [ ! -s "$scanOut" ] ; then rigRow "$2" 1 render-text "the renderer prints nothing" ; fi
	MYXROOT="$rigMyxRoot" bash "$rigCatMarkdown" --spans "$scanFile" > "$scanOut" 2> "$rigTmp/render.err" ; scanRc=$?
	if [ "$scanRc" != 0 ] ; then
		rigRow "$2" 1 render-spans "the renderer ends with status $scanRc: $( LC_ALL=C sed -n 1p "$rigTmp/render.err" | LC_ALL=C cut -c1-120 )"
	else
		## each row is its text, a TAB and its spans, `<byte offset>+<bytes>+<look>` separated by commas, each inside the text and of a look the renderer has
		LC_ALL=C awk '
			{
				cut = 0 ;
				for ( i = length( $0 ); i > 0; i-- ) if ( substr( $0, i, 1 ) == "\t" ) { cut = i ; break ; }
				if ( cut == 0 ) { print "no TAB between the text and its spans\t" $0 ; next ; }
				text = substr( $0, 1, cut - 1 ) ; spans = substr( $0, cut + 1 ) ;
				if ( spans == "" ) next ;
				n = split( spans, entry, "," ) ;
				for ( k = 1; k <= n; k++ ) {
					if ( entry[k] !~ /^[0-9]+[+][0-9]+[+][a-z0-9]+$/ ) { print "span " entry[k] " is not offset+bytes+look\t" text ; break ; }
					split( entry[k], part, "+" ) ;
					if ( index( " h1 h2 h3 strong em code quote rule meta item head link ", " " part[3] " " ) == 0 ) { print "span " entry[k] " has a look the renderer does not have\t" text ; break ; }
					if ( part[1] + part[2] > length( text ) ) { print "span " entry[k] " is beyond its " length( text ) " bytes\t" text ; break ; }
				}
			}' "$scanOut" > "$rigTmp/spans.bad"
		while IFS= read -r scanRow ; do
			[ -n "$scanRow" ] || continue
			scanReason="${scanRow%%$'\t'*}" ; scanText="${scanRow#*$'\t'}" ; scanText="$( printf '%s' "$scanText" | LC_ALL=C sed -e 's/^ *//' -e 's/ *$//' )"
			rigRow "$2" "$( rigLineOf "$scanFile" "$scanText" )" render-spans "$scanReason"
		done < "$rigTmp/spans.bad"
	fi
	## the lines: a front matter that closes, code fences that close, no control character but TAB, a syntax line that names its command
	LC_ALL=C awk -v file="$2" '
		NR == 1 && $0 == "---" { fm = 1 ; next ; }
		fm == 1 && $0 == "---" { fm = 2 ; next ; }
		$0 ~ /^```/ { if ( fence ) fence = 0 ; else fence = NR ; }
		$0 ~ /[\001-\010\013-\037\177]/ { printf "%s:%d: control-char: a control character (such as a carriage return) is in the line\n", file, NR ; }
		$0 ~ /^📘 syntax:/ && $0 !~ /^📘 syntax: [A-Za-z][A-Za-z0-9_.-]*( |$)/ { printf "%s:%d: syntax-line: the syntax line names no command: %s\n", file, NR, substr( $0, 1, 80 ) ; }
		END {
			if ( fm == 1 ) printf "%s:1: front-matter: the front matter opened on line 1 is never closed\n", file ;
			if ( fence ) printf "%s:%d: code-fence: the code fence opened here is never closed\n", file, fence ;
		}' "$scanFile" >> "$rigRows"
}
## The rows of one include: it parses; run as `--help` runs it, it says no error of bash, prints its syntax lines in the right shape and renders only
## a manual that is there.
rigScanInclude(){ ## root, file below myx/
	local scanFile="$1/myx/$2" scanOut="$rigTmp/run.out" scanRc scanMsg scanLine scanSyntax scanRef scanPath scanReal
	rigIncludes=$(( rigIncludes + 1 ))
	if ! bash -n "$scanFile" > "$rigTmp/bashn.out" 2>&1 ; then
		scanLine="$( LC_ALL=C sed -n 's/^.*: line \([0-9][0-9]*\): .*$/\1/p' "$rigTmp/bashn.out" | LC_ALL=C sed -n 1p )"
		rigRow "$2" "${scanLine:-1}" bash-n "$( LC_ALL=C sed -n 1p "$rigTmp/bashn.out" | LC_ALL=C sed 's/^.*: line [0-9]*: //' | LC_ALL=C cut -c1-120 )"
		return 0
	fi
	## the references to a manual: the path handed to the renderer must be a file
	LC_ALL=C grep -n -E '[cC]atMarkdown[^"]*"[^"]*"' "$scanFile" | LC_ALL=C grep -v -E '^[0-9]+:[[:space:]]*#' > "$rigTmp/refs" || :
	while IFS= read -r scanRef ; do
		[ -n "$scanRef" ] || continue
		scanLine="${scanRef%%:*}" ; scanPath="$( printf '%s' "$scanRef" | LC_ALL=C sed -n 's/^[^"]*[cC]atMarkdown[^"]*"\([^"]*\)".*$/\1/p' )"
		[ -n "$scanPath" ] || continue
		scanReal="$( printf '%s' "$scanPath" | LC_ALL=C sed -e "s|\${MDLT_ORIGIN}|$1|g" -e "s|\$MDLT_ORIGIN|$1|g" )"
		case "$scanReal" in *'$'*) continue ;; esac
		[ -f "$scanReal" ] || rigRow "$2" "$scanLine" md-reference "the manual it renders is not there: $scanPath"
	done < "$rigTmp/refs"
	( cd "$rigTmp/ws" && env -i HOME=/nonexistent PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$1" MYXROOT="$rigMyxRoot" RIG_MYXROOT="$rigMyxRoot" \
		bash -c '. "$MYXROOT/bin/lib/catMarkdown.Common"; inc="$1"; shift; . "$inc"' _ "$scanFile" --help ) > "$scanOut" 2>&1 < /dev/null ; scanRc=$?
	LC_ALL=C grep -E "^$scanFile: line [0-9]+: " "$scanOut" > "$rigTmp/run.errors" || :
	while IFS= read -r scanMsg ; do
		[ -n "$scanMsg" ] || continue
		scanLine="$( printf '%s' "$scanMsg" | LC_ALL=C sed -n 's/^.*: line \([0-9][0-9]*\): .*$/\1/p' )"
		rigRow "$2" "$scanLine" run-help "$( printf '%s' "$scanMsg" | LC_ALL=C sed 's/^.*: line [0-9]*: //' | LC_ALL=C cut -c1-120 )"
	done < "$rigTmp/run.errors"
	if [ ! -s "$rigTmp/run.errors" ] && [ "$scanRc" -gt 1 ] ; then rigRow "$2" 1 run-help "ends with status $scanRc under --help" ; fi
	[ -s "$scanOut" ] || rigRow "$2" 1 no-help "prints nothing under --help"
	LC_ALL=C grep '^📘 syntax:' "$scanOut" | LC_ALL=C grep -v -E '^📘 syntax: [A-Za-z][A-Za-z0-9_.-]*( |$)' > "$rigTmp/run.syntax" || :
	while IFS= read -r scanSyntax ; do
		[ -n "$scanSyntax" ] || continue
		rigRow "$2" "$( rigLineOf "$scanFile" "${scanSyntax#📘 syntax: }" )" syntax-line "the syntax line names no command: $( printf '%s' "$scanSyntax" | LC_ALL=C cut -c1-80 )"
	done < "$rigTmp/run.syntax"
}
rigScan(){ ## root, package... -- rows for every help file of those packages
	local scanRoot="$1" scanPkg scanFile ; shift
	for scanPkg in "$@" ; do
		[ -d "$scanRoot/myx/$scanPkg/sh-lib" ] || { rigRow "$scanPkg" 1 missing "the package has no sh-lib at $scanRoot" ; continue ; }
		find "$scanRoot/myx/$scanPkg/sh-lib" -type f -name '*.help.md' | LC_ALL=C sort > "$rigTmp/found.md"
		find "$scanRoot/myx/$scanPkg/sh-lib" -type f -name 'Help*.include' | LC_ALL=C sort > "$rigTmp/found.inc"
		[ -s "$rigTmp/found.md" ] || rigRow "$scanPkg" 1 missing "the package has no manual (*.help.md)"
		[ -s "$rigTmp/found.inc" ] || rigRow "$scanPkg" 1 missing "the package has no help include (Help*.include)"
		while IFS= read -r scanFile ; do [ -n "$scanFile" ] && rigScanManual "$scanRoot" "${scanFile#"$scanRoot"/myx/}" ; done < "$rigTmp/found.md"
		while IFS= read -r scanFile ; do [ -n "$scanFile" ] && rigScanInclude "$scanRoot" "${scanFile#"$scanRoot"/myx/}" ; done < "$rigTmp/found.inc"
	done
}
rigBegin=$( date +%s )

echo "-- 1. all six packages --"
: > "$rigRows"
rigScan "$MDLT_ORIGIN" myx.distro-.local myx.distro-agents myx.distro-deploy myx.distro-remote myx.distro-source myx.distro-system
rigAssert "every manual and every include of the six packages parses by the code that reads it: no row ($rigManuals manuals, $rigIncludes includes)" "$( LC_ALL=C grep -c . "$rigRows" ) rows" "0 rows"
LC_ALL=C sed 's/^/        /' "$rigRows" | LC_ALL=C head -40
rigAssert "the manuals and includes were found, not nothing: at least a dozen of each" "$( [ "$rigManuals" -ge 12 ] && [ "$rigIncludes" -ge 12 ] && printf enough )" "enough"

echo "-- 2. the seeded defects --"
rigSeed="$rigTmp/seed" rigSeedHelp="$rigTmp/seed/myx/myx.distro-seed/sh-lib/help"
mkdir -p "$rigSeedHelp"
## a pair that is well made
printf '%s\n' 'echo "📘 syntax: Seed.fn.sh [--help]" >&2' 'if [ "$1" = "--help" ]; then' '	myx.common lib/catMarkdown "@ORIGIN@/myx/myx.distro-seed/sh-lib/help/Help.Good.help.md" >&2' 'fi' | LC_ALL=C sed 's|@ORIGIN@|$MDLT_ORIGIN|' > "$rigSeedHelp/Help.Good.include"
printf '%s\n' '📘 syntax: Seed.fn.sh [--help]' '' '##  Summary:' '' '		Prints a seed.' '' '##  Examples:' '' '		# Show it' '		`Seed.fn.sh`' > "$rigSeedHelp/Help.Good.help.md"
## includes with a defect each
printf '%s\n' 'echo "📘 syntax: Seed.fn.sh [--help]" >&2' 'echo ok' 'fi' > "$rigSeedHelp/Help.StrayFi.include"
printf '%s\n' 'echo "📘 syntax: Seed.fn.sh [--help]" >&2' 'a_command_that_is_not_there_for_the_help_check' > "$rigSeedHelp/Help.NoCommand.include"
printf '%s\n' 'echo "📘 syntax: --oops" >&2' 'echo "	Options:" >&2' > "$rigSeedHelp/Help.NoName.include"
printf '%s\n' 'echo "📘 syntax: Seed.fn.sh [--help]" >&2' 'if [ "$1" = "--help" ]; then' '	myx.common lib/catMarkdown "@ORIGIN@/myx/myx.distro-seed/sh-lib/help/Help.Nowhere.help.md" >&2' 'fi' | LC_ALL=C sed 's|@ORIGIN@|$MDLT_ORIGIN|' > "$rigSeedHelp/Help.NoManual.include"
printf '%s\n' ':' > "$rigSeedHelp/Help.Silent.include"
## manuals with a defect each
printf '%s\n' '📘 syntax: Seed.fn.sh [--help]' '' '##  Examples:' '```' 'Seed.fn.sh' '' 'and the rest of the text' > "$rigSeedHelp/Help.Fence.help.md"
printf '%s\n' '---' 'title: a front matter' '' '##  Summary:' > "$rigSeedHelp/Help.FrontMatter.help.md"
printf '%s\n' '📘 syntax: Seed.fn.sh [--help]' '' 'a line with a carriage return' > "$rigSeedHelp/Help.Carriage.help.md"
printf 'a line with a carriage return\r\n' >> "$rigSeedHelp/Help.Carriage.help.md"
printf '%s\n' '📘 syntax: Seed.fn.sh [--help]' '📘 syntax: <project>' '' '##  Summary:' > "$rigSeedHelp/Help.SyntaxLine.help.md"
: > "$rigSeedHelp/Help.Empty.help.md"
: > "$rigRows"
rigManuals=0 rigIncludes=0
rigScan "$rigSeed" myx.distro-seed
LC_ALL=C sort "$rigRows" | LC_ALL=C sed -e 's/: [^:]*$//' > "$rigTmp/rows.keys"
rigRowsOf(){ ## file name -- the "line: rule" of every row of that file, one line
	LC_ALL=C sed -n "s|^myx\.distro-seed/sh-lib/help/$1:\([0-9]*\): \([a-z-]*\): .*|\1 \2|p" "$rigRows" | LC_ALL=C sort | LC_ALL=C tr '\n' ',' | LC_ALL=C sed 's/,$//'
}
rigAssert "the pair that is well made: no row" "[$( rigRowsOf Help.Good.include )][$( rigRowsOf Help.Good.help.md )]" "[][]"
rigAssert "a stray fi: bash-n, on its line (3)" "$( rigRowsOf Help.StrayFi.include )" "3 bash-n"
rigAssert "a command that is not there: run-help, on its line (2)" "$( rigRowsOf Help.NoCommand.include )" "2 run-help"
rigAssert "a syntax line that names no command: syntax-line, on the line of its echo (1)" "$( rigRowsOf Help.NoName.include )" "1 syntax-line"
rigAssert "a manual that is not there: md-reference, on the line that renders it (3)" "$( rigRowsOf Help.NoManual.include )" "3 md-reference"
rigAssert "an include that prints nothing: no-help" "$( rigRowsOf Help.Silent.include )" "1 no-help"
rigAssert "an unclosed code fence: code-fence, on the line that opens it (4)" "$( rigRowsOf Help.Fence.help.md )" "4 code-fence"
rigAssert "a front matter never closed: front-matter, on line 1" "$( rigRowsOf Help.FrontMatter.help.md )" "1 front-matter"
rigAssert "a carriage return: control-char, on its line (4)" "$( rigRowsOf Help.Carriage.help.md )" "4 control-char"
rigAssert "a syntax line that names no command in a manual: syntax-line, on its line (2)" "$( rigRowsOf Help.SyntaxLine.help.md )" "2 syntax-line"
rigAssert "an empty manual: render-text, on line 1" "$( rigRowsOf Help.Empty.help.md )" "1 render-text"
rigAssert "nothing else was found in the seeded tree: ten rows for ten defects" "$( LC_ALL=C grep -c . "$rigRows" )" "10"
rigAssert "the seeded tree was scanned whole: 6 manuals and 6 includes" "$rigManuals manuals $rigIncludes includes" "6 manuals 6 includes"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ HELP FILES PARSE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'HELP_FILES_PARSE: OK (%d assertions, offline, rig tree only, %d seconds)\n' "$rigPasses" "$(( $( date +%s ) - rigBegin ))"
