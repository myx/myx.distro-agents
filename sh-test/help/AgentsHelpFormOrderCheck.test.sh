#!/usr/bin/env bash
## Behavioural check on the ORDER OF THE FORMS of the help of the family (board task 2026-11-09T1425Z): an operation's help lists
## its most preferred and most frequent form first, and its least preferred last. A help page is `sh-lib/help/Help.<Tool>.help.md`,
## the authority, and a `Help*.include` beside it prints the syntax lines `--help-syntax` gives. Where an operation takes a body, the
## patch form `--edit-patch-from-stdin` comes before the whole-body forms. Read rather than run, over the help of all six
## myx.distro-* packages: .local, agents, deploy, remote, source and system. Held:
##   1. THE HELP WAS READ WHOLE: every `*.help.md` and every `Help*.include` of every one of the six packages, the counts said, and
##      each package carrying both kinds. A scan of none, or of too few, is a refusal, not a pass. The reader saw the form it judges,
##      on lines of the help, so a scan that never looked fails here rather than reporting clean.
##   2. NO LINE PUTS ANOTHER FORM BEFORE THE PATCH FORM. A form group is a bracketed or parenthesised alternative list, read whole,
##      an inner bracket included. A group holding `--edit-patch-from-stdin` that begins with another form is a row, written
##      `<package>/sh-lib/help/<file>:<line>: form-order: <group>`. A group beginning with the patch form gives none.
##   3. THE READER CAN FAIL: a seeded page and a seeded include, each with a group that puts the whole body first, give exactly their
##      rows, and the pair written right gives none.
## Offline: the help of the six packages at the origin, and a rig tree of the check's own. No network, no session, no other workspace.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help" ] || rigRefuse "the help of the family is not at the origin this workspace resolves: $MDLT_ORIGIN/myx"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHelpFormOrderCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
	return 0
}
## The rows of one help folder: every form group of a line, in the order the line writes them, and one row for a group that holds the
## patch form and puts another form first. A group is read to its own closing bracket, an inner bracket included, so the nested
## `<py|awk>` of `--edit-script-from-stdin:<py|awk>` never cuts the group short.
rigRows(){ ## help folder, the name its files are written under
	LC_ALL=C awk '
		function firstForm( group,   first ) {
			first = group
			sub( /^[\[(]/, "", first ) ; sub( /\|.*/, "", first )
			return first
		}
		function shortName( path,   name ) {
			name = path ; sub( /^.*\//, "", name )
			return name
		}
		{
			text = $0 ; size = length( text ) ; at = 1
			while ( at <= size ) {
				lead = substr( text, at, 1 )
				if ( lead != "[" && lead != "(" ) { at++ ; continue ; }
				depth = 0 ; end = at
				while ( end <= size ) {
					char = substr( text, end, 1 )
					if ( char == "[" || char == "(" ) depth++
					else if ( char == "]" || char == ")" ) { depth-- ; if ( depth == 0 ) break ; }
					end++
				}
				if ( depth != 0 ) break
				group = substr( text, at, end - at + 1 ) ; at = end + 1
				if ( index( group, "--edit-patch-from-stdin" ) == 0 ) continue
				if ( firstForm( group ) == "--edit-patch-from-stdin" ) continue
				printf "%s/sh-lib/help/%s:%d: form-order: %s\n", where, shortName( FILENAME ), FNR, group
			}
		}' where="$2" "$1"/*.help.md "$1"/Help*.include
}

rigBegin=$( date +%s )
rigPages=0 rigIncludes=0 rigPackages=0
: > "$rigTmp/rows"
for rigHelpDir in "$MDLT_ORIGIN"/myx/*/sh-lib/help ; do
	[ -d "$rigHelpDir" ] || continue
	rigPackage="${rigHelpDir%/sh-lib/help}" ; rigPackage="${rigPackage##*/}"
	rigPageCount=0 rigIncludeCount=0
	for rigPageFile in "$rigHelpDir"/*.help.md ; do [ -f "$rigPageFile" ] && rigPageCount=$(( rigPageCount + 1 )) ; done
	for rigIncludeFile in "$rigHelpDir"/Help*.include ; do [ -f "$rigIncludeFile" ] && rigIncludeCount=$(( rigIncludeCount + 1 )) ; done
	[ "$rigPageCount" -gt 0 ] && [ "$rigIncludeCount" -gt 0 ] && rigPackages=$(( rigPackages + 1 ))
	rigPages=$(( rigPages + rigPageCount )) ; rigIncludes=$(( rigIncludes + rigIncludeCount ))
	rigRows "$rigHelpDir" "myx/$rigPackage" >> "$rigTmp/rows" 2> "$rigTmp/rows.err" \
		|| rigRefuse "the scan of $rigPackage ended with an error: $( LC_ALL=C sed -n 1p "$rigTmp/rows.err" )"
done

echo "-- 1. the help of the family --"
rigAssert "each package of the family carries a page and an include: $rigPackages packages, $rigPages pages, $rigIncludes includes" \
	"$( [ "$rigPackages" -ge 6 ] && printf enough || printf "read $rigPackages packages" )" enough
rigSeen="$( LC_ALL=C cat "$MDLT_ORIGIN"/myx/*/sh-lib/help/*.help.md "$MDLT_ORIGIN"/myx/*/sh-lib/help/Help*.include | LC_ALL=C grep -c -F -- '--edit-patch-from-stdin' || : )"
rigAssert "the reader saw the patch form it judges: $rigSeen lines of the help name it, not none" \
	"$( [ "$rigSeen" -gt 0 ] && printf seen || printf "seen $rigSeen" )" seen
rigAssert "no line of the help puts another form before the patch form" "$( LC_ALL=C grep -c . "$rigTmp/rows" )" 0
LC_ALL=C sed 's/^/        /' "$rigTmp/rows" | LC_ALL=C head -40

echo "-- 2. the reader can fail --"
rigSeed="$rigTmp/seed/myx/myx.distro-seed/sh-lib/help"
mkdir -p "$rigSeed" || exit 1
printf '%s\n' '📘 syntax: Seed.fn.sh --seed-write [--edit-patch-from-stdin|--from-file <path>]' > "$rigSeed/Help.Good.help.md"
printf '%s\n' 'echo "📘 syntax: Seed.fn.sh --seed-write [--edit-patch-from-stdin|--from-file <path>]" >&2' > "$rigSeed/Help.Good.include"
printf '%s\n' '📘 syntax: Seed.fn.sh --seed-write [--from-file <path>|--edit-patch-from-stdin]' '' \
	'		--seed-write [--from-file <path>|--edit-patch-from-stdin]' > "$rigSeed/Help.Bad.help.md"
printf '%s\n' 'echo "📘 syntax: Seed.fn.sh --seed-write (--upsert-from-stdin|--edit-patch-from-stdin)" >&2' > "$rigSeed/Help.Bad.include"
rigRows "$rigSeed" "myx/myx.distro-seed" > "$rigTmp/seed.rows" 2> "$rigTmp/seed.err" \
	|| rigRefuse "the scan of the seeded tree ended with an error: $( LC_ALL=C sed -n 1p "$rigTmp/seed.err" )"
rigAssert "the pair written right gives no row" "[$( LC_ALL=C grep -F 'Help.Good' "$rigTmp/seed.rows" | LC_ALL=C cut -c1-60 )]" "[]"
rigAssert "the page whose group puts the whole body first gives its rows, on its own lines (1 and 3)" \
	"$( LC_ALL=C grep -F 'Help.Bad.help.md:' "$rigTmp/seed.rows" | LC_ALL=C sed 's|^.*Help\.Bad\.help\.md:\([0-9]*\):.*|\1|' | LC_ALL=C tr '\n' ',' )" "1,3,"
rigAssert "and so does its include, on its own line (1)" \
	"$( LC_ALL=C grep -F 'Help.Bad.include:' "$rigTmp/seed.rows" | LC_ALL=C sed 's|^.*Help\.Bad\.include:\([0-9]*\):.*|\1|' )" 1
rigAssert "the seeded tree gives exactly those three rows, and no more" "$( LC_ALL=C grep -c . "$rigTmp/seed.rows" )" 3

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HELP FORM ORDER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HELP_FORM_ORDER: OK (%d assertions, %d pages and %d includes of %d packages, offline, rig tree only, %d seconds)\n' \
	"$rigPassCount" "$rigPages" "$rigIncludes" "$rigPackages" "$(( $( date +%s ) - rigBegin ))"
