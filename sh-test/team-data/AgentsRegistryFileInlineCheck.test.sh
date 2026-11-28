#!/usr/bin/env bash
## Static and behavioural check of the load guards. A guard `type F || . X` stops reloading X only where X defines F, itself or through
## a file X loads at its top level. A guard naming a function that X does not define reloads X on every pass, and the call after it
## finds nothing. Held:
##   1. every guard in sh-lib and sh-scripts names a function its file defines, itself or through its top-level loads
##   2. no file names AgentsToolsRegistryFile: a registry's path is written where it is used
##   3. --intern-context-show answers: the function its guard names is defined
## Red before the change: the context show's file defined no function, and the registry path had a helper.
## Offline: reads the package tree, and runs one read-only operation.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}

echo "-- 1. every guard names a function its file defines --"
rigUndefined="$( cd "$rigPkg" && find sh-lib sh-scripts -type f \( -name '*.include' -o -name '*.sh' \) -print | LC_ALL=C sort | LC_ALL=C xargs awk '
	FNR == 1 { file = FILENAME ; files[ file ] = 1 ; }
	match( $0, /^[ \t]*[A-Za-z_][A-Za-z0-9_]*\(\)/ ) { name = substr( $0, RSTART, RLENGTH ) ; sub( /^[ \t]*/, "", name ) ; sub( /\(\)$/, "", name ) ; defines[ file SUBSEP name ] = 1 ; }
	/^(type [A-Za-z_][A-Za-z0-9_]* > \/dev\/null 2>&1 \|\| )?\. "\$MDLT_ORIGIN\/myx\/myx\.distro-agents\/sh-lib\// {
		target = $0 ; sub( /^.*\/myx\.distro-agents\//, "", target ) ; sub( /".*$/, "", target ) ; loads[ file, ++loadCount[ file ] ] = target ;
	}
	match( $0, /type [A-Za-z_][A-Za-z0-9_]* > \/dev\/null 2>&1 \|\| \. "\$MDLT_ORIGIN\/myx\/myx\.distro-agents\/sh-lib\/[^"]+"/ ) {
		guard = substr( $0, RSTART, RLENGTH ) ; name = guard ; sub( /^type /, "", name ) ; sub( / .*$/, "", name ) ;
		target = guard ; sub( /^.*\/myx\.distro-agents\//, "", target ) ; sub( /"$/, "", target ) ;
		guards[ ++guardCount ] = file " " name " " target ;
	}
	function reaches( start, name,    stack, depth, seen, at, step ) {
		depth = 1 ; stack[ 1 ] = start ;
		while ( depth > 0 ) {
			at = stack[ depth-- ] ;
			if ( at in seen ) continue ;
			seen[ at ] = 1 ;
			if ( ( at SUBSEP name ) in defines ) return 1 ;
			for ( step = 1 ; step <= loadCount[ at ] ; step++ ) stack[ ++depth ] = loads[ at, step ] ;
		}
		return 0 ;
	}
	END {
		for ( at = 1 ; at <= guardCount ; at++ ) {
			split( guards[ at ], part, " " ) ;
			if ( !( part[ 3 ] in files ) ) { print part[ 1 ] ": " part[ 2 ] " -> " part[ 3 ] " (no such file)" ; continue ; }
			if ( !reaches( part[ 3 ], part[ 2 ] ) ) print part[ 1 ] ": " part[ 2 ] " -> " part[ 3 ] ;
		}
	}
' | LC_ALL=C sort -u | tr '\n' ';' )"
rigAssert "guards whose file defines no such function" "$rigUndefined" ""

echo "-- 2. a registry's path is written where it is used --"
rigAssert "files naming AgentsToolsRegistryFile" \
	"$( LC_ALL=C grep -rlF 'AgentsToolsRegistryFile' "$rigPkg/sh-lib" "$rigPkg/sh-scripts" | sed "s|^$rigPkg/||" | tr '\n' ' ' )" ""

echo "-- 3. the context show answers --"
rigShow="$( "$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-context-show < /dev/null 2> /dev/null )" ; rigShowRc=$?
rigAssert "rc and first line" "$rigShowRc ${rigShow%%:*}" "0 team-member"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ REGISTRY FILE INLINE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'REGISTRY_FILE_INLINE: OK (%d assertions, offline)\n' "$rigPass"
