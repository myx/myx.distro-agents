#!/usr/bin/env bash
## Static check: no awk `-v name=value` of the package is fed a value that holds a newline. BSD awk refuses such a value with
## "newline in string" and exit 2, and a caller that sends awk's stderr to /dev/null then reads nothing, as --supervise-scan read no
## tracked dispatch on Darwin. A value with newlines goes to awk on stdin or through ENVIRON. Two shapes are found, both by reading:
##   1. the value written as a $'...' literal that holds \n
##   2. the value a variable that the same file assigns, or appends to, with a $'\n', unless that value is cut at a newline
## Not found, since no reading can settle it: a value a parameter or another file carries. Held on every shell file of sh-lib,
## sh-scripts and sh-test, in one awk process; red on a planted case of each shape, green on the tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -d "$rigPkg/sh-lib" ] || rigRefuse "the package is not at the origin: $rigPkg"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsAwkValueNewlineCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
## The sites found in the files given, one `<file>:<line> <name> <shape>` a line. The $'\n' token is built in BEGIN, since a quote
## cannot stand in the program's own text.
rigScan(){ ## files...
	LC_ALL=C awk '
		BEGIN { q = sprintf( "%c", 39 ) ; nlToken = "$" q "\\n" q ; }
		## The word an assignment gives: up to the first blank or ; outside quotes and $( ), as the shell ends it.
		function wordOf( text,   at, ch, inDouble, inSingle, depth ) {
			inDouble = 0 ; inSingle = 0 ; depth = 0
			for ( at = 1 ; at <= length( text ) ; at++ ) {
				ch = substr( text, at, 1 )
				if ( inSingle ) { if ( ch == q ) inSingle = 0 ; continue ; }
				if ( ch == "\\" ) { at++ ; continue ; }
				if ( ch == "\"" ) { inDouble = ! inDouble ; continue ; }
				if ( ch == "$" && substr( text, at + 1, 1 ) == "(" ) { depth++ ; at++ ; continue ; }
				if ( ch == ")" && depth > 0 ) { depth-- ; continue ; }
				if ( ch == q && ! inDouble ) { inSingle = 1 ; continue ; }
				if ( ! inDouble && depth == 0 && ( ch == " " || ch == "\t" || ch == ";" || ch == ")" ) ) return substr( text, 1, at - 1 )
			}
			return text
		}
		function settle(   siteAt ) {
			for ( siteAt = 1 ; siteAt <= siteCount ; siteAt++ ) if ( siteVar[ siteAt ] in newlineVar ) print siteWhere[ siteAt ] " " siteName[ siteAt ] " variable:" siteVar[ siteAt ]
			siteCount = 0 ; split( "", newlineVar )
		}
		FNR == 1 { settle() ; }
		{
			line = $0
			## A variable given a newline: `name=` or `name+=`, its value holding the token and no cut at a newline.
			rest = line
			while ( match( rest, /[A-Za-z_][A-Za-z0-9_]*\+?=/ ) ) {
				name = substr( rest, RSTART, RLENGTH ) ; sub( /\+?=$/, "", name )
				before = substr( rest, RSTART - 1, 1 )
				value = substr( rest, RSTART + RLENGTH )
				rest = value
				if ( RSTART > 1 && before ~ /[A-Za-z0-9_]/ ) continue
				## The name of a -v site is no assignment of the shell.
				if ( RSTART > 3 && substr( line, length( line ) - length( rest ) - RLENGTH - 2, 3 ) ~ /^-v[ \t]$/ ) continue
				value = wordOf( value )
				if ( index( value, nlToken ) && ! index( value, "%" nlToken ) && ! index( value, "#*" nlToken ) && ! index( value, "%%" nlToken ) ) newlineVar[ name ] = 1
			}
			## The -v sites of the line.
			rest = line
			while ( match( rest, /-v[ \t]+[A-Za-z_][A-Za-z0-9_]*=/ ) ) {
				name = substr( rest, RSTART, RLENGTH ) ; sub( /^-v[ \t]+/, "", name ) ; sub( /=$/, "", name )
				value = substr( rest, RSTART + RLENGTH )
				rest = value
				if ( substr( value, 1, 2 ) == "$" q ) {
					literal = substr( value, 3 ) ; literalEnd = index( literal, q )
					if ( literalEnd && index( substr( literal, 1, literalEnd - 1 ), "\\n" ) ) print FILENAME ":" FNR " " name " literal"
					continue
				}
				if ( substr( value, 1, 1 ) == "\"" ) value = substr( value, 2 )
				if ( substr( value, 1, 1 ) != "$" ) continue
				value = substr( value, 2 ) ; braced = ( substr( value, 1, 1 ) == "{" ) ; if ( braced ) value = substr( value, 2 )
				if ( ! match( value, /^[A-Za-z_][A-Za-z0-9_]*/ ) ) continue
				var = substr( value, 1, RLENGTH )
				if ( braced && index( substr( value, 1, index( value, "}" ) ), nlToken ) ) continue
				siteCount++ ; siteWhere[ siteCount ] = FILENAME ":" FNR ; siteName[ siteCount ] = name ; siteVar[ siteCount ] = var
			}
		}
		END { settle() ; }
	' "$@"
}
## Red: a planted file of each shape, beside one that cuts its value at a newline and one fed a single line.
rigQ="'"
{
	printf '%s\n' "rigLive=\"\$( printf x )\""
	printf '%s\n' "rigTracked=\"\$( LC_ALL=C awk -v live=\$${rigQ}\\n${rigQ}\"\$rigLive\"\$${rigQ}\\n${rigQ} '{ print ; }' x )\""
	printf '%s\n' "rigList=\"one\"\$${rigQ}\\n${rigQ}\"two\""
	printf '%s\n' "LC_ALL=C awk -v names=\"\$rigList\" '{ print ; }' x"
	printf '%s\n' "rigCut=\"\${rigList%%\$${rigQ}\\n${rigQ}*}\""
	printf '%s\n' "LC_ALL=C awk -v first=\"\$rigCut\" '{ print ; }' x"
	printf '%s\n' "LC_ALL=C awk -v one=\"\$rigLive\" '{ print ; }' x"
} > "$rigTmp/Planted.include"
rigPlanted="$( rigScan "$rigTmp/Planted.include" | LC_ALL=C sed "s|$rigTmp/||" )"
rigAssert "red: the old SuperviseBoard form, a \$'\\n' literal in the value, is found" "$( printf '%s\n' "$rigPlanted" | LC_ALL=C grep -c -x -F 'Planted.include:2 live literal' )" "1"
rigAssert "red: a variable assigned with a newline, fed to -v, is found" "$( printf '%s\n' "$rigPlanted" | LC_ALL=C grep -c -x -F 'Planted.include:4 names variable:rigList' )" "1"
rigAssert "control: a value cut at a newline, and one of a single line, are not" "$( printf '%s\n' "$rigPlanted" | LC_ALL=C grep -c -E ' (first|one) ' )" "0"
## Green: the whole tree, every shell file of the three folders, in one awk process.
rigFiles=()
while IFS= read -r rigFile ; do rigFiles+=( "$rigFile" ) ; done < <( cd "$rigPkg" && find sh-lib sh-scripts sh-test -type f \( -name '*.sh' -o -name '*.include' \) | LC_ALL=C sort )
[ "${#rigFiles[@]}" -gt 100 ] || rigRefuse "the package's shell files were not listed: ${#rigFiles[@]} found"
rigFound="$( cd "$rigPkg" && rigScan "${rigFiles[@]}" )"
rigAssert "no -v of the package's ${#rigFiles[@]} shell files is fed a value that holds a newline" "${rigFound:-none}" "none"
[ "$rigFail" = 0 ] || { printf 'AWK_VALUE_NEWLINE: FAIL (%d of %d assertions)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1 ; }
printf 'AWK_VALUE_NEWLINE: OK (%d assertions, offline)\n' "$rigPass"
