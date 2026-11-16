#!/usr/bin/env bash
## Check that every load of a package file finds its file, and that every call reaches a loaded file: the load-missing
## and unreached classes of AgentsSolidContracts.py beside this file, held by the suite. A move that leaves a call site
## naming where a file used to be fails here, by the path no file answers or by the helper no load reaches.
## Held:
##   1. no load by a literal path names a file that does not exist (load-missing)
##   2. no call to a package function runs on a path where its file is not loaded (unreached)
## Red on a copy with one load moved to sh-lib/magic/ and the guarded load of an inbox op deleted: one row each.
## Usage: AgentsSolidLoadCheck.test.sh [<package root>]   (default: the package at $MDLT_ORIGIN). Offline: it writes nothing.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRoot="${1:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigRoot/sh-lib" ] && [ -d "$rigRoot/sh-scripts" ] || rigRefuse "no package at $rigRoot"
rigRows="$( python3 -I "${BASH_SOURCE%/*}/AgentsSolidContracts.py" "$rigRoot" )" || rigRefuse "AgentsSolidContracts.py failed on $rigRoot"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRowsOf(){ ## class -- the rows of that class, `<file>:<line> <detail>`, joined by `; `
	LC_ALL=C awk -F'\t' -v rowClass="$1" '$1 == rowClass { printf "%s%s %s", rowSep, $2, $3 ; rowSep = "; " ; }' <<< "$rigRows"
}

echo "-- control: the scan reads a package of code files --"
rigAssert "control: sh-lib and sh-scripts hold more than a hundred .include and .sh files" \
	"$( find "$rigRoot/sh-lib" "$rigRoot/sh-scripts" -type f \( -name '*.include' -o -name '*.sh' \) | LC_ALL=C awk 'END { print ( NR > 100 ) ? "many" : NR ; }' )" many

echo "-- 1. every load by a literal path finds its file --"
rigAssert "no load-missing row" "[$( rigRowsOf load-missing )]" "[]"

echo "-- 2. every call reaches a loaded file --"
rigAssert "no unreached row" "[$( rigRowsOf unreached )]" "[]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SOLID LOAD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SOLID_LOAD: OK (%d assertions, offline)\n' "$rigPassCount"
