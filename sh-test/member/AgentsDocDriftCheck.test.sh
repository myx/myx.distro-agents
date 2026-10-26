#!/usr/bin/env bash
## Check on --doc-drift (K2): a package whose code changed after its documents is detected by mtime. The function is
## sourced and called directly, offline, in a scratch tree of files at controlled mtimes.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPackage/sh-lib/member/AgentsTools.LibrarianWork.include"
rigFails=0 rigPasses=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi ; }
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsDocDriftCheck.XXXXXX" )" || exit 1 ; trap 'rm -rf -- "$rigTmp"' EXIT
rigPkgA="$rigTmp/pkg-a" rigPkgB="$rigTmp/pkg-b" ; mkdir -p "$rigPkgA/sh-lib/help" "$rigPkgB"
printf -- '---\nname: pkg-a\n---\n' > "$rigPkgA/project.inf" ; printf -- '---\nname: pkg-b\n---\n' > "$rigPkgB/project.inf"
## pkg-a: code newer than its docs -> drifts. pkg-b: docs newer -> no drift.
printf '# MAGIC\n' > "$rigPkgA/MAGIC.md" ; printf '# code\n' > "$rigPkgA/code.fn.sh"
printf '# MAGIC\n' > "$rigPkgB/MAGIC.md" ; printf '# code\n' > "$rigPkgB/code.fn.sh"
touch -t 202601010000 "$rigPkgA/MAGIC.md" ; touch -t 202701010000 "$rigPkgA/code.fn.sh"
touch -t 202701010000 "$rigPkgB/MAGIC.md" ; touch -t 202601010000 "$rigPkgB/code.fn.sh"
rigOut="$( MDSC_CMD=AgentLibrarianTools AgentsToolsLibrarianDocDrift --doc-drift "$rigPkgA" "$rigPkgB" )" ; rigRc=$?
rigAssert "the package whose code is newer than its docs drifts, the other does not" "$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c "$rigPkgA" ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c "$rigPkgB" || : )" "0 1 0"
if [ "$rigFails" -ne 0 ] ; then echo "⛔ DOC_DRIFT FAILED: $rigFails of $(( rigPasses + rigFails ))" >&2 ; exit 1 ; fi
printf 'DOC_DRIFT: OK (%d assertions)\n' "$rigPasses"
