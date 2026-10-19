#!/usr/bin/env bash
## Check on the console app's own subfolder (F11.1 of the refactorings epic): the console app moves into a subfolder of
## sh-lib, `sh-lib/manager/`, the folder of F1.3's scheme for the manager (open-names 52; constraint 1: F1.3 defines the
## scheme, F11.1 uses it). The subfolder comes before any move into it, and the screen start is updated in the same
## change.
## Held:
##   1. sh-lib/manager/ holds the console app's python: the screen's entry file is there
##   2. no python file of the console app (AgentsManagerScreen*.py) stays at the top of sh-lib
##   3. run: the start of the console app (--manager, or --intern-manager before F2.5) starts python on a file in
##      sh-lib/manager/, handing it the workspace and the tools
## Red before F11.1: the screen is sh-lib/AgentsManagerScreen.py, and the start names it there (every case fails).
## Builder note: every screen check hands the driver sh-lib/AgentsManagerScreen.py (check-fixtures/
## manager-screen.driver.py and each `rigScreen=`), and manager/AgentsManagerBareOpCheck compares the start against it;
## they are brought in line in the same change.
## Offline: a rig python3 that writes down how it was started and runs nothing.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigLib="$rigOrigin/myx/myx.distro-agents/sh-lib"
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsManagerScreenFolderCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/skills"
printf '#!/bin/sh\n{ printf "start" ; for rigArg in "$@" ; do printf "\\t%%s" "$rigArg" ; done ; printf "\\n" ; } >> "%s/starts"\nexit 0\n' "$rigTmp" > "$rigTmp/bin/python3"
chmod +x "$rigTmp/bin/python3"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigStart(){ ## operation -- one start from the rig workspace, as the console user
	: > "$rigTmp/starts"
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" bash "$rigTool" "$1" ) > "$rigTmp/out" 2>&1 < /dev/null
}

echo "-- 1. sh-lib/manager/ holds the console app's python --"
rigAssert "the folder stands, with python files in it"        "$( [ -d "$rigLib/manager" ] && echo folder || echo none ) $( find "$rigLib/manager" -maxdepth 1 -name '*.py' -type f 2> /dev/null | LC_ALL=C grep -c . | LC_ALL=C sed -e 's/^[1-9][0-9]*$/python/' )" "folder python"

echo "-- 2. none of it stays at the top of sh-lib --"
rigAssert "the console app's python files at the top of sh-lib" "[$( find "$rigLib" -maxdepth 1 -name 'AgentsManagerScreen*.py' -type f -exec basename {} \; | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed -e 's/ $//' )]" "[]"

echo "-- 3. the start starts the screen from sh-lib/manager/ --"
rigStart --manager
LC_ALL=C grep -q -F 'invalid option: --manager' "$rigTmp/out" && rigStart --intern-manager
rigAssert "python is started on a file in sh-lib/manager/, with the workspace and the tools" \
	"$( LC_ALL=C awk -F'\t' -v wantLib="$rigLib/manager/" -v wantWs="$rigWs" -v wantTool="$rigTool" '$1 == "start" { for ( f = 2 ; f <= NF ; f++ ) if ( $f ~ /\.py$/ ) script = $f ; ws = 0 ; tools = 0 ; for ( f = 2 ; f < NF ; f++ ) { if ( $f == "--workspace" && $(f+1) == wantWs ) ws = 1 ; if ( $f == "--tools" && $(f+1) == wantTool ) tools = 1 } ; print ( index( script, wantLib ) == 1 ? "manager-folder" : "elsewhere:" script ) ( ws ? " workspace" : "" ) ( tools ? " tools" : "" ) ; exit }' "$rigTmp/starts" )" "manager-folder workspace tools"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN FOLDER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_FOLDER: OK (%d assertions, offline)\n' "$rigPassCount"
