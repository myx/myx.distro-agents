#!/usr/bin/env bash
## Check on the `undefined-call` class of AgentsSolidContracts.py beside this check: a call to a package function runs
## only where its defining file is loaded on the call's own path. A load in a branch covers the calls in that branch
## alone, never a call after its `fi`, never a call in its sibling branch.
## The class is held on a constructed package, so the result is about the detector and never about the live tree.
## Held:
##   1. control: the scan reads a constructed package of code files
##   2. a call after the `fi` of the block that loads the file is a row
##   3. a call in the `else` of the block that loads the file is a row
##   4. a call a file-scope load precedes is no row
##   5. a call its own `type <Fn> || . <file>` guard precedes is no row
##   6. an awk program's `if ( … ) { … }` is no branch: the call after it in the same function is no row
##   7. a call to a name no file defines is a row, whatever the branch state
## Red on the package before the fix: rows 2, 3 and 7 missing; the same fixture under the fixed scan gives all seven.
## Usage: AgentsSolidUndefinedCall.test.sh [<package root>]   (default: the package at $MDLT_ORIGIN). Offline: it writes
## nothing but its own rig.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
scanHere="$( cd "${BASH_SOURCE%/*}" && pwd )"
rigDetector="$scanHere/AgentsSolidContracts.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigDetector" ] || rigRefuse "the detector is not beside this check: $rigDetector"
. "$scanHere/../check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSolidUndefinedCallCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
[ -n "${RIG_KEEP:-}" ] || trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

## The constructed package: two callers whose load sits in a branch, one whose load is at file scope, one whose own
## guard loads, one whose `if` is an awk program's, and the file that defines every function they call.
rigPkg="$rigTmp/pkg"
mkdir -p "$rigPkg/sh-lib/fixture" "$rigPkg/sh-scripts" "$rigPkg/sh-test" || exit 1
cat > "$rigPkg/sh-lib/fixture/defs.include" <<'FIX'
AgentsFixtureLoadedWork(){ ## a function of another file, reached only through its own load
	echo "$1"
}
FIX
cat > "$rigPkg/sh-lib/fixture/branch-caller.include" <<'FIX'
AgentsFixtureBranchCaller(){ ## -- load in a block, call after its fi
	if [ -n "${1:-}" ] ; then
		type AgentsFixtureLoadedWork > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/fixture/defs.include"
		AgentsFixtureLoadedWork "$1"
	fi
	## The call below the block that loads its file, five lines under the guard.
	AgentsFixtureLoadedWork "after-the-fi"
}
FIX
cat > "$rigPkg/sh-lib/fixture/else-caller.include" <<'FIX'
AgentsFixtureElseCaller(){ ## -- load in a block, call in its else
	if [ -n "${1:-}" ] ; then
		type AgentsFixtureLoadedWork > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/fixture/defs.include"
		AgentsFixtureLoadedWork "$1"
	else
		## The else branch never ran the load above it.
		AgentsFixtureLoadedWork "in-the-else"
	fi
}
FIX
cat > "$rigPkg/sh-lib/fixture/covered-caller.include" <<'FIX'
type AgentsFixtureLoadedWork > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/fixture/defs.include"
AgentsFixtureCoveredCaller(){ ## -- a file-scope load before the call covers it
	AgentsFixtureLoadedWork "covered"
}
FIX
cat > "$rigPkg/sh-lib/fixture/guarded-caller.include" <<'FIX'
AgentsFixtureGuardedCaller(){ ## -- the call's own guard loads its file
	type AgentsFixtureLoadedWork > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/fixture/defs.include"
	AgentsFixtureLoadedWork "guarded"
}
FIX
cat > "$rigPkg/sh-lib/fixture/awk-caller.include" <<'FIX'
AgentsFixtureAwkCaller(){ ## -- an awk program's if is no branch of the shell
	if [ -n "${1:-}" ] ; then
		type AgentsFixtureLoadedWork > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/fixture/defs.include"
		LC_ALL=C awk 'BEGIN { if ( 1 ) { print "x" ; } else { print "y" ; } }'
		AgentsFixtureLoadedWork "$1"
	fi
	## Below the block. The awk program's if and else above it added no branch.
	AgentsFixtureLoadedWork "after-the-awk"
}
FIX
cat > "$rigPkg/sh-lib/fixture/nowhere-caller.include" <<'FIX'
AgentsFixtureNowhereCaller(){ ## -- a call to a name no file of the package defines
	AgentsFixtureDefinedNowhere "x"
}
FIX

rigRows="$( cd "$rigPkg" && python3 -I "$rigDetector" "$rigPkg" )" || rigRefuse "the detector failed on $rigPkg"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRowsAt(){ ## file:line -- the details of the undefined-call rows at that site, joined by `; `
	LC_ALL=C awk -F'\t' -v rowAt="$1" '$1 == "undefined-call" && $2 == rowAt { printf "%s%s", rowSep, $3 ; rowSep = "; " ; }' <<< "$rigRows"
}

echo "-- 1. control: the scan reads a constructed package --"
rigAssert "control: the constructed package holds a file the scan read" \
	"$( [ -s "$rigPkg/sh-lib/fixture/branch-caller.include" ] && echo read )" read

echo "-- 2. a call after the fi of the block that loads its file is a row --"
rigAssert "the call after the fi is reported, naming its defining file" \
	"[$( rigRowsAt sh-lib/fixture/branch-caller.include:7 )]" "[AgentsFixtureLoadedWork of sh-lib/fixture/defs.include is not loaded on this path]"

echo "-- 3. a call in the else of the block that loads its file is a row --"
rigAssert "the call in the else is reported, naming its defining file" \
	"[$( rigRowsAt sh-lib/fixture/else-caller.include:7 )]" "[AgentsFixtureLoadedWork of sh-lib/fixture/defs.include is not loaded on this path]"

echo "-- 4. a call a file-scope load precedes is no row --"
rigAssert "no row at the covered call" "[$( rigRowsAt sh-lib/fixture/covered-caller.include:3 )]" "[]"

echo "-- 5. a call its own guard precedes is no row --"
rigAssert "no row at the guarded call" "[$( rigRowsAt sh-lib/fixture/guarded-caller.include:3 )]" "[]"

echo "-- 6. an awk program's if is no branch --"
rigAssert "one row, at the call below the block, and none inside the block after the awk program" \
	"[$( rigRowsAt sh-lib/fixture/awk-caller.include:8 )][$( rigRowsAt sh-lib/fixture/awk-caller.include:5 )]" \
	"[AgentsFixtureLoadedWork of sh-lib/fixture/defs.include is not loaded on this path][]"

echo "-- 7. a call to a name no file defines is a row --"
rigAssert "the undefined name is reported" \
	"[$( rigRowsAt sh-lib/fixture/nowhere-caller.include:2 )]" "[AgentsFixtureDefinedNowhere is defined nowhere]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SOLID UNDEFINED-CALL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SOLID_UNDEFINED_CALL: OK (%d assertions, offline)\n' "$rigPassCount"
