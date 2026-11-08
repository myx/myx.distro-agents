#!/usr/bin/env bash
## Behavioural check on the `Configuration` and `Settings` roots of a sibling console (S7.24; LocalManagerScreen.SiblingRoots.py of
## myx.distro-.local), run rather than read: the screen is started as the `local` app through the driver (check-fixtures/manager-screen.driver.py),
## with the stand-in dispatcher (check-fixtures/manager-screen.tools.stub.sh). Held:
##   1. In the local app, Configuration is a root and holds Installed Subsystems, a plugin of .local mounted under it.
##   2. In the local app, Settings is a root and holds Scope Settings, mounted under it the same way.
##   3. Neither root carries the agents' own screens there: no checker, no keys, no CLI presets under Configuration.
##   4. The control: in the agents app Configuration still holds the checker and the keys ahead of Installed Subsystems, as before.
## Red before S7.24: the two roots were the agents package's plugins, kept for the agents app alone, so a sibling had no `@configuration`
## and no `@settings` to stand on: rows 1 and 2 fail.
## Offline: no operation of the real tooling is called.
set -u
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/manager/LocalManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigTools="$rigFixtures/manager-screen.tools.stub.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenSiblingRootsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export TZ=UTC

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCase(){ ## name -- a fresh rig: no call noted, every start answered with no row
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	: > "$MANAGER_SCREEN_RIG/calls"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
	: > "$MANAGER_SCREEN_RIG/rows"
}
rigScript(){ ## the app, then the commands of the driver on standard input; what it printed is kept in rigOut
	local app="$1" ; shift
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\nwall 2026-10-13 02:30 +0000\nsize 120 40\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script --app "$app" 2>&1 )" || rigOut="$rigOut"$'\n'"DRIVER-FAILED rc=$?"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigIds(){ ## name, the ids to look for -- those of the named rowids that are among the ids given, in the order they stand
	rigVal "$1" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -x -F -f <( printf '%s\n' "${@:2}" ) | LC_ALL=C tr '\n' ' '
}

echo "-- 1. the local app: Configuration holds Installed Subsystems --"
rigCase local-configuration
rigScript local <<'RIGSCRIPT'
at @configuration
rowids ids
RIGSCRIPT
rigAssert "Configuration is a root of the local app, and Installed Subsystems stands under it" "$( rigIds ids .. subsystems )" ".. subsystems "
rigAssert "none of the agents' own screens stands there" "$( rigIds ids checker keys clipresets git harness diagnostics )" ""
rigAssert "the driver reports no failure" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'DRIVER-FAILED\|Traceback\|PluginError' )" "0"

echo "-- 2. the local app: Settings holds Scope Settings --"
rigCase local-settings
rigScript local <<'RIGSCRIPT'
at @settings
rowids ids
RIGSCRIPT
rigAssert "Settings is a root of the local app, and Scope Settings stands under it" "$( rigIds ids .. scopes )" ".. scopes "

echo "-- 3. the deploy app the same way --"
rigCase deploy
rigScript deploy <<'RIGSCRIPT'
at @configuration
rowids ids
RIGSCRIPT
rigAssert "the deploy app has the root and the folder too" "$( rigIds ids .. subsystems )" ".. subsystems "

echo "-- 4. the control: the agents app is as it was --"
rigCase agents
rigScript agents <<'RIGSCRIPT'
at @configuration
rowids ids
RIGSCRIPT
rigAssert "Configuration of the agents app holds the checker and the keys ahead of Installed Subsystems" "$( rigIds ids .. checker keys subsystems )" ".. checker keys subsystems "

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN SIBLING ROOTS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
echo "MANAGER_SCREEN_SIBLING_ROOTS: OK ($rigPassCount assertions, offline)"
