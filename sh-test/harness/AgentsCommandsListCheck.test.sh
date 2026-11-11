#!/usr/bin/env bash
## AgentsCommandsListCheck -- the tooling commands of a workspace, listed with the path the shell runs each by
## (DistroAgentsTools.fn.sh --commands-list, AgentsTools.CommandsList.include; epic S12.26).
## Guards: the list names the family's own commands with their paths; a project command the prepared index names is in it,
## with the folder the index gives; a name met in two folders keeps its first, in the command path's order; `--names` prints
## the names alone, sorted; another word is refused; the list is read through the tooling command itself.
## Red: a list that misses the index's folders fails `the project command of the index is listed`.
## Offline: a temp workspace of this check alone, removed at its end; the family's own folders are read as they are.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigTmp="$( mktemp -d "${MMDAPP:-${TMPDIR:-/tmp}}/.local/agents/scratch/sh-test/AgentsCommandsListCheck.XXXXXXXX" 2> /dev/null || mktemp -d "${TMPDIR:-/tmp}/AgentsCommandsListCheck.XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local" "$rigWs/source/rig/one/sh-scripts" "$rigWs/source/rig/two/sh-scripts" || exit 1
printf '#!/usr/bin/env bash\necho ONE\n' > "$rigWs/source/rig/one/sh-scripts/RigCustom.fn.sh"
printf '#!/usr/bin/env bash\necho TWO\n' > "$rigWs/source/rig/two/sh-scripts/RigCustom.fn.sh"
printf '#!/usr/bin/env bash\necho SHADOW\n' > "$rigWs/source/rig/two/sh-scripts/DistroAgentsTools.fn.sh"
chmod 755 "$rigWs"/source/rig/*/sh-scripts/*.fn.sh
printf 'rig/one RigCustom %s\nrig/two RigCustom %s\nrig/two DistroAgentsTools %s\n' "$rigWs/source/rig/one/sh-scripts" "$rigWs/source/rig/two/sh-scripts" "$rigWs/source/rig/two/sh-scripts" > "$rigWs/.local/distro-commands.txt"
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigList(){ ## words...
	( MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" ; export MMDAPP MDLT_ORIGIN ; . "$rigLib/common/AgentsTools.CommandsList.include" ; AgentsToolsCommandsList "$@" ) 2> "$rigTmp/err"
}

echo "-- 1. the family's commands, with their paths --"
rigList > "$rigTmp/list"
rigAssert "DistroAgentsTools is listed with the family's own path, not the index's shadow" "$( LC_ALL=C awk -F'\t' '$1 == "DistroAgentsTools" { print $2 }' "$rigTmp/list" )" "$rigTool"
rigAssert "the agents' and the deploy's commands are in it" "$( LC_ALL=C grep -c -e '^DistroAgentsItems	' -e '^DeployProjectSsh	' "$rigTmp/list" )" 2
rigAssert "each name once"                                  "$( LC_ALL=C cut -f 1 "$rigTmp/list" | LC_ALL=C sort | LC_ALL=C uniq -d | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0

echo "-- 2. the prepared index's commands --"
rigAssert "the project command of the index is listed"      "$( LC_ALL=C awk -F'\t' '$1 == "RigCustom" { print $2 }' "$rigTmp/list" )" "$rigWs/source/rig/one/sh-scripts/RigCustom.fn.sh"
rigAssert "the list is sorted by name"                      "$( LC_ALL=C cut -f 1 "$rigTmp/list" | LC_ALL=C sort -c 2>&1 | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0

echo "-- 3. the names alone, and a refused word --"
rigAssert "--names prints names alone"                      "$( rigList --names | LC_ALL=C grep -c '	' )" 0
rigAssert "and the same count"                              "$( rigList --names | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "$( LC_ALL=C wc -l < "$rigTmp/list" | LC_ALL=C tr -d ' ' )"
rigAssert "another word is refused"                         "$( rigList --paths | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( LC_ALL=C grep -c 'takes --names or nothing' "$rigTmp/err" )" "0:1"

echo "-- 4. through the tooling command itself --"
rigAssert "the command answers the same first row"          "$( cd "$rigWs" && MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigTool" --commands-list 2> /dev/null | LC_ALL=C head -n 1 )" "$( LC_ALL=C head -n 1 "$rigTmp/list" )"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ COMMANDS LIST CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: a member learns the tooling commands by reading code, and takes a .fn.sh command for a function" >&2
	echo "  fix:  AgentsToolsCommandsList in sh-lib/common/AgentsTools.CommandsList.include" >&2
	exit 1
fi
echo "COMMANDS_LIST: OK ($rigPass assertions, offline)"
