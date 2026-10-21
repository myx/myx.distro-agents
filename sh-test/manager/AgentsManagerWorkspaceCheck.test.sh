#!/usr/bin/env bash
## Behavioural check on `--manager-workspace-read`, the rows `Workspace (System)` of the console shows (F11.10 of the refactorings epic), run rather than read: the operation is `.local`'s own
## (myx.distro-.local, sh-lib/manager/LocalTools.ManagerWorkspace.include), which the agents' dispatcher offers, and the blocks this console adds are registered in
## sh-lib/config/workspace-blocks.list and written by sh-lib/manager/AgentsTools.ManagerWorkspace.include. Against a rig workspace built here. Held (the owner's ruling: "Workspace content is as
## you list it, with one addition to the agents block: the workspace's agents mode ... and whether it keeps team data, read through the one mode reader. Nothing else."):
##   1. the rows, byte for byte: the workspace's own facts (name, path, where its tooling comes from, that tooling's path, the account the console runs as), the subsystems installed in it (the
##      rows of --manager-subsystem-list that read installed), the agents block (its mode and whether it keeps team data) and the members that belong to the workspace, each with its kind, how
##      it is set up and its folder, by the registry of members: a folder of the workspace's own member set that no row names is shown, marked so
##   2. the tooling reads `source` where the origin is the workspace's source tree, `.local` where it is its .local, and `elsewhere` for any other
##   3. the mode: a team rig keeps team data; Just Agents and a rig client keep none; the facts are those the one mode reader says
##   4. a block that wrote nothing is left out; a workspace with no member prints no `team` block
##   5. it writes nothing (the tree of the rig is as it was); a word after it, and a member's session, are refused with nothing printed; its syntax line and its help entry are there
## Offline; only the rig's own tree is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerWorkspaceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws-here" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigShared="$rigHome/.agents/magic-team"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/members/keeper-two" "$rigWs/.local/agents/members/odd-one" "$rigShared" "$rigSkills"
## the installed copies of the rig: .local, system, remote and agents; deploy and source are missing
for rigOne in .local system remote agents ; do
	mkdir -p "$rigWs/.local/myx/myx.distro-$rigOne/sh-scripts"
	: > "$rigWs/.local/myx/myx.distro-$rigOne/sh-scripts/marker"
done
: > "$rigWs/.local/.agents/keeper-rig.agent.env" ; chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env
## THE MEMBERS, as the machine's registry of members has them: two belong to this workspace, one belongs to another; and in this workspace's own member set stands a folder no row names.
{
	printf 'keeper-rig\t%s\tsource-symlink\trig/skills/keeper-rig\t%s\n' "$rigWs" "$rigTmp/skill-source/keeper-rig"
	printf 'keeper-two\t%s\tlocal-copy\t-\t%s\n' "$rigWs" "$rigWs/.local/agents/members/keeper-two"
	printf 'keeper-far\t%s\tsource-declared\trig/skills/keeper-far\t%s\n' "$rigTmp/ws-far" "$rigTmp/skill-source/keeper-far"
} > "$rigShared/members.registry"
## the workspace is a place of the machine, as the read of a place needs it: its own registry of places and the pointer of the machine
printf 'ws-here\tworkspace\tread-write\t%s\tworkspace\n' "$rigWs" > "$rigWs/.local/agents/directories.registry"
printf 'ws-here\t%s\n' "$rigWs" > "$rigShared/directories.registry"
rigAccount="$( id -un )"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigPre=() rigMode="team-rig" rigRoot="$rigWs" rigOrigin="$MDLT_ORIGIN"
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigRoot" && env -i MDAT_WORKSPACE_MODE="$rigMode" HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigRoot" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigTroubles(){ LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || : ; }
rigFlat(){ LC_ALL=C tr '\t' ' ' < "$1" | LC_ALL=C tr '\n' '/' ; }
rigTree(){ ( cd "$rigTmp" && { find ws-here home skills -type f 2> /dev/null | LC_ALL=C sort | while IFS= read -r treeFile ; do printf '%s %s\n' "$treeFile" "$( cksum < "$treeFile" )" ; done ; find ws-here home skills -type d 2> /dev/null | LC_ALL=C sort ; } ) | cksum ; }
rigTreeBefore="$( rigTree )"

echo "-- 1. the rows --"
rigRun --manager-workspace-read
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the workspace's own facts, the installed subsystems, the agents block and the members that belong to the workspace, byte for byte" "$( rigFlat "$rigTmp/out" )" \
	"fact - name ws-here/fact - path $rigWs/fact - tooling elsewhere/fact - tooling-path $MDLT_ORIGIN/fact - account $rigAccount/block packages Installed_Subsystems 4/item packages .local subsystem installed -/item packages system subsystem installed -/item packages remote subsystem installed -/item packages agents subsystem installed -/block agents Agents 0/fact agents mode team-rig/fact agents team-data yes/block team Team_Members 3/item team keeper-rig keeper source-symlink $rigTmp/skill-source/keeper-rig/item team keeper-two keeper local-copy $rigWs/.local/agents/members/keeper-two/item team odd-one odd not-in-registry $rigWs/.local/agents/members/odd-one/"
rigAssert "the installed subsystems are those --manager-subsystem-list reads installed: one list" "$( LC_ALL=C awk -F'\t' '$1 == "item" && $2 == "packages" { printf "%s ", $3 }' "$rigTmp/out" )" "$( rigRun --manager-subsystem-list ; LC_ALL=C awk -F'\t' '$3 == "installed" { printf "%s ", $2 }' "$rigTmp/out" )"
rigAssert "the members are those the read of a place prints for this workspace: one function" "$( rigRun --manager-workspace-read ; LC_ALL=C awk -F'\t' '$1 == "item" && $2 == "team" { printf "%s/%s/%s/%s ", $3, $4, $5, $6 }' "$rigTmp/out" )" "$( rigRun --manager-place-read ws-here ; LC_ALL=C awk -F'\t' '$1 == "member" { printf "%s/%s/%s/%s ", $2, $3, $5, $6 }' "$rigTmp/out" )"

echo "-- 2. where the tooling comes from --"
mkdir -p "$rigTmp/ws-src" "$rigTmp/ws-dot"
ln -s "$MDLT_ORIGIN" "$rigTmp/ws-src/source" ; ln -s "$MDLT_ORIGIN" "$rigTmp/ws-dot/.local"
rigRoot="$rigTmp/ws-src" rigOrigin="$rigTmp/ws-src/source"
rigRun --manager-workspace-read
rigAssert "an origin that is the workspace's source tree reads source" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "fact" && $2 == "-" && ( $3 == "tooling" || $3 == "tooling-path" ) { printf "%s=%s ", $3, $4 }' "$rigTmp/out" )" "0 tooling=source tooling-path=$rigTmp/ws-src/source "
rigRoot="$rigTmp/ws-dot" rigOrigin="$rigTmp/ws-dot/.local"
rigRun --manager-workspace-read
rigAssert "an origin that is the workspace's .local reads .local" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "fact" && $2 == "-" && ( $3 == "tooling" || $3 == "tooling-path" ) { printf "%s=%s ", $3, $4 }' "$rigTmp/out" )" "0 tooling=.local tooling-path=$rigTmp/ws-dot/.local "
rigRoot="$rigWs" rigOrigin="$MDLT_ORIGIN"

echo "-- 3. the mode --"
rigBad=""
for rigOne in "team-rig yes" "just-agents no" "rig-client no" "none-of-them no" ; do
	rigMode="${rigOne% *}" ; [ "$rigMode" != "none-of-them" ] || rigMode="junk"
	rigRun --manager-workspace-read
	rigWant="${rigOne% *}" ; [ "$rigWant" != "none-of-them" ] || rigWant="just-agents"
	[ "$( LC_ALL=C awk -F'\t' '$1 == "fact" && $2 == "agents" { printf "%s=%s ", $3, $4 }' "$rigTmp/out" )" = "mode=$rigWant team-data=${rigOne#* } " ] || rigBad="$rigBad [$rigOne]"
done
rigMode="team-rig"
rigAssert "a team rig keeps team data; Just Agents, a rig client and a value that is none of the three (which reads Just Agents) keep none" "${rigBad:- all as the mode reader says}" " all as the mode reader says"

rigAssert "every read so far wrote nothing: the tree of the rig is as it was before the first" "$( rigTree )" "$rigTreeBefore"

echo "-- 4. a block that wrote nothing --"
rm -rf "$rigWs/.local/agents/members" ; : > "$rigShared/members.registry"
rigRun --manager-workspace-read
rigAssert "a workspace no member belongs to prints no team block; the agents block stays" "$( LC_ALL=C grep -c -F -e 'block	team	' "$rigTmp/out" || : ) $( LC_ALL=C grep -c -F -e 'block	agents	' "$rigTmp/out" || : )" "0 1"

echo "-- 5. it refuses, and has its help --"
rigRun --manager-workspace-read extra
rigAssert "a word after it is refused with one error line and nothing printed" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -- 'syntax is --manager-workspace-read, got 1 argument(s)' "$rigTmp/err" || : )" "1 0 1"
rigPre=(MDAT_SPAWN_AGENT=magic-coordinator)
rigRun --manager-workspace-read
rigPre=()
rigAssert "a member's session is refused, magic-coordinator's too, with nothing printed" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 0"
rigBad=""
LC_ALL=C grep -q -F -- "DistroAgentsTools.fn.sh --manager-workspace-read" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.include" || rigBad="$rigBad [include]"
LC_ALL=C grep -q -x -F -- "		--manager-workspace-read" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md" || rigBad="$rigBad [help.md]"
rigAssert "the operation has its syntax line and its help entry" "${rigBad:- paired}" " paired"

printf '\nTOTAL: %d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
