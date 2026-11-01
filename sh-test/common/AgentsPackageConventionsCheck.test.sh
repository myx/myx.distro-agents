#!/usr/bin/env bash
## Behavioural check on the package's own conventions, run rather than read: what the rework pass (S16 of the refactorings
## epic) brings every changed file into line with, kept as one pass that runs again.
##   1. EVERY TEXT FILE ENDS WITH A NEWLINE ("A text file ends with a newline").
##   2. NO BASH-4 CONSTRUCT: a bash file here is written to bash 3.2, so mapfile, readarray, an associative array and the
##      case-conversion expansions have no place in it.
##   3. NO UNGUARDED GNU-ONLY FLAG: sed -i, readlink -f, ls --color, grep -P and xargs -r are absent where the code runs, and
##      named only in a comment where the code says why it does not use them.
## Offline: the package at this origin, and nothing run but the readers themselves.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
[ -d "$rigPackage/sh-lib" ] || { echo "⛔ ERROR: not found at the origin this workspace resolves: $rigPackage/sh-lib -- refusing to report a result" >&2 ; exit 1 ; }
command -v python3 > /dev/null 2>&1 || { echo "⛔ ERROR: python3 is not on PATH, so the last byte of a file cannot be read -- refusing to report a result" >&2 ; exit 1 ; }

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigCount(){ ## text -- how many lines it holds
	printf '%s\n' "$1" | LC_ALL=C grep -c . || :
}

echo "-- 1. every text file ends with a newline --"
rigNoNewline="$( python3 -I -B - "$rigPackage" <<'PY'
import os, sys
pkg = sys.argv[1]
bad = []
for root, dirs, files in os.walk(pkg):
    dirs[:] = [ d for d in dirs if d != '.git' ]
    for name in files:
        if not name.endswith(('.sh', '.include', '.md', '.awk', '.py', '.txt')):
            continue
        path = os.path.join(root, name)
        try:
            size = os.path.getsize(path)
            if size == 0:
                continue
            with open(path, 'rb') as handle:
                handle.seek(-1, os.SEEK_END)
                if handle.read(1) != b'\n':
                    bad.append(os.path.relpath(path, pkg))
        except OSError:
            pass
print('\n'.join(bad))
PY
)"
rigAssert "no text file of the package stops short of a newline"      "$( rigCount "$rigNoNewline" )" 0
[ ! -n "$rigNoNewline" ] || printf '        files: %s\n' "$( printf '%s\n' "$rigNoNewline" | LC_ALL=C tr '\n' ' ' )"

echo "-- 2. no bash-4 construct in the tooling --"
rigBash4="$( LC_ALL=C grep -rn -E 'mapfile|readarray|declare -A|local -A|\$\{[A-Za-z_][A-Za-z0-9_]*\^\^|\$\{[A-Za-z_][A-Za-z0-9_]*,,' \
	--include=*.sh --include=*.include "$rigPackage/sh-lib" "$rigPackage/sh-scripts" 2> /dev/null | LC_ALL=C grep -v -E ':[[:space:]]*#' || : )"
rigAssert "no bash-4 construct stands in a bash 3.2 file"            "$( rigCount "$rigBash4" )" 0

echo "-- 3. no unguarded GNU-only flag --"
rigGnu="$( LC_ALL=C grep -rn -E 'sed -i|readlink -f|ls --color|grep -P|xargs -r' \
	--include=*.sh --include=*.include "$rigPackage/sh-lib" "$rigPackage/sh-scripts" 2> /dev/null | LC_ALL=C grep -v -E ':[[:space:]]*#' || : )"
rigAssert "a GNU-only flag is used, or named only in a comment"       "$( rigCount "$rigGnu" )" 0

if [ "$rigFailCount" != 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount"
	exit 1
fi
printf 'RESULT: PASS (%s assertions)\n' "$rigPassCount"
exit 0
