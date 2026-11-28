#!/usr/bin/env bash
## Behavioural check of where the guard folders are made. The git, ln and grep guards are written into <workspace>/.local/agents/
## guard-bin for whatever workspace a run names; a workspace named wrong -- a relative one, or a folder of a source tree -- made a
## whole .local/agents tree there, and its files then stood in the source tree. Held:
##   1. given a folder whose .local/agents does not exist, no maker makes anything there
##   2. given a relative workspace, the guard path makes nothing under the folder the process stands in
##   3. given a workspace with its .local/agents, the three guards are made in its guard-bin
## Red before the change: each maker made every missing parent with mkdir -p.
## Offline: folders of this check alone, under its own temp folder; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsGuardFolderNoTreeCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
mkdir -p "$rigTmp/tree/sh-test" "$rigTmp/ws/.local/agents" || exit 1
rigMake(){ ## workspace, folder the process stands in
	( cd "$2" && env -u BASH_ENV -u MDAT_GIT_GUARD_FOLDER -u MDAT_GIT_GUARD_CHAIN bash -c '
		. "$1/sh-lib/common/AgentsTools.GitWrite.include" && . "$1/sh-lib/spawn/AgentsTools.SandboxLinks.include" || exit 9
		AgentsToolsGitGuardPath "$2"
		AgentsToolsGitGuardMake "$2/.local/agents/guard-bin" ; AgentsToolsLnGuardMake "$2/.local/agents/guard-bin" ; AgentsToolsGrepGuardMake "$2/.local/agents/guard-bin"
		exit 0' rig "$rigPkg" "$1" ) > /dev/null 2>&1
}

echo "-- 1. a folder that is no workspace keeps no tree --"
rigMake "$rigTmp/tree/sh-test" "$rigTmp"
rigAssert "files made under the folder" "$( find "$rigTmp/tree" -type f | wc -l | tr -d ' ' )" 0

echo "-- 2. a relative workspace makes nothing where the process stands --"
rigMake "." "$rigTmp/tree"
rigAssert "files made under the folder the process stands in" "$( find "$rigTmp/tree" -type f | wc -l | tr -d ' ' )" 0

echo "-- 3. a workspace gets its three guards --"
rigMake "$rigTmp/ws" "$rigTmp"
rigAssert "guards in its guard-bin" "$( for g in git ln grep ; do [ -x "$rigTmp/ws/.local/agents/guard-bin/$g" ] && printf '%s ' "$g" ; done )" "git ln grep "

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ GUARD FOLDER NO TREE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'GUARD_FOLDER_NO_TREE: OK (%d assertions, offline)\n' "$rigPass"
