#!/usr/bin/env bash
## Static check that no function only renames another. A function whose whole body passes its arguments to one other function costs
## a call on every use and says nothing the callee's name does not: the callee carries the name its callers use. Held:
##   1. no sh-lib or sh-scripts function has a body of one call that passes "$@" on, in its multi-line or its one-line form
##   2. the session chat's pointer and stamp writes are defined once, under the names their callers use
## Red before the change: the chat's stamp, pointer set and pointer unset each passed "$@" to a twin named Direct.
## Offline: reads the package tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}

echo "-- 1. no function only renames another --"
rigRenames="$( cd "$rigPkg" && find sh-lib sh-scripts -type f \( -name '*.include' -o -name '*.sh' \) -print | LC_ALL=C sort | LC_ALL=C xargs awk '
	FNR == 1 { held = "" ; }
	/^[ \t]*[A-Za-z_][A-Za-z0-9_]*\(\)[ \t]*\{[ \t]*[A-Za-z_][A-Za-z0-9_]* "\$@"[ \t]*;?[ \t]*\}[ \t]*$/ { name = $0 ; sub( /^[ \t]*/, "", name ) ; sub( /\(\).*/, "", name ) ; print FILENAME ": " name ; next ; }
	/^[ \t]*[A-Za-z_][A-Za-z0-9_]*\(\)[ \t]*\{[ \t]*(#.*)?$/ { held = $0 ; sub( /^[ \t]*/, "", held ) ; sub( /\(\).*/, "", held ) ; body = 0 ; only = 0 ; next ; }
	held != "" && /^[ \t]*\}[ \t]*$/ { if ( body == 1 && only ) print FILENAME ": " held ; held = "" ; next ; }
	held != "" { line = $0 ; sub( /^[ \t]+/, "", line ) ; sub( /[ \t]+$/, "", line ) ; if ( line == "" || line ~ /^#/ ) next ; body++ ; only = ( body == 1 && line ~ /^[A-Za-z_][A-Za-z0-9_]* "\$@"$/ ) ; }
' | tr '\n' ';' )"
rigAssert "functions whose body only passes \"\$@\" on" "$rigRenames" ""

echo "-- 2. the chat writes are defined once --"
rigChat="$rigPkg/sh-lib/session/AgentsTools.SessionChat.include"
rigAssert "definitions of the stamp, pointer set and pointer unset, and of a Direct twin" \
	"$( for rigName in AgentsToolsSessionChatStamp AgentsToolsSessionChatPointerSet AgentsToolsSessionChatPointerUnset ; do printf '%s:%s ' "$( LC_ALL=C grep -cE "^${rigName}\\(\\)" "$rigChat" )" "$( LC_ALL=C grep -rlE "${rigName}Direct" "$rigPkg/sh-lib" "$rigPkg/sh-scripts" | wc -l | tr -d ' ' )" ; done )" "1:0 1:0 1:0 "

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ RENAME WRAPPER CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'RENAME_WRAPPER: OK (%d assertions, offline)\n' "$rigPass"
