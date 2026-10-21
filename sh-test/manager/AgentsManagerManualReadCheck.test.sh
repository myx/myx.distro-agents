#!/usr/bin/env bash
## Behavioural check on --manager-manual-read <user|maintainer> [<project>] (F11.9 of the refactorings epic), the operation
## of the console's own family --manager-* that gives the manuals of the projects of a workspace, which the root
## `Manuals (Help)` of the manager screen shows. Run rather than read, against a distro workspace built here
## (check-fixtures/rig-distro-workspace.include.sh): one repository, three projects, of which one has a README.md and a
## MAGIC.md, one a README.md alone, and one neither.
## Held: with a kind alone, one line a project that has the file of that kind, `<project> <TAB> <whole path of the file>`,
## `user` the README.md, `maintainer` the MAGIC.md, in the order ListDistroProjects --select-all gives the projects (the
## build sequence), a project without the file left out; with a project of that list, that file as it is; a kind that is
## neither, no kind, a project that is none of the list, one that has no file of the kind, a path in place of a project
## and a second project are refused, rc 1, nothing on stdout, in one line; it only reads: every file of the rig is as it
## was; and the help pair: its syntax echo, its syntax line and its entry, once each. Offline.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigOp="--manager-manual-read"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "the tool is not at the origin this workspace resolves"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-distro-workspace.include.sh" || exit 1
rigTmp="$( rigDistroTmp AgentsManagerManualReadCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home"
mkdir -p "$rigHome"
rigDistroWorkspace "$rigWs" rigrepo || rigRefuse "the rig workspace could not be made"
rigDistroProject "$rigWs" rigrepo zz-base ""
rigDistroProject "$rigWs" rigrepo aa-app ""
rigDistroProject "$rigWs" rigrepo mm-none ""
printf '# zz readme\n\nThe base.\n' > "$rigWs/source/rigrepo/zz-base/README.md"
printf '# aa readme\n\nThe app.\n' > "$rigWs/source/rigrepo/aa-app/README.md"
printf '# aa magic\n\nMaintainer notes of the app.\n' > "$rigWs/source/rigrepo/aa-app/MAGIC.md"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigRun(){ ## words... -- the call from the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	rigDistroRun "$rigWs" "$rigHome" "$@" > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigRefused(){ ## -- rc, what stdout held in bytes, and whether stderr names an error
	printf '%s %s %s' "$rigRc" "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "$( LC_ALL=C grep -c -F -- '⛔ ERROR: DistroAgentsTools --manager-manual-read:' "$rigTmp/err" || : )"
}
rigTree(){ ## -- every file of the rig, each with the sum of its bytes, as one sum
	( cd "$rigTmp" && find ws home -type f 2> /dev/null | LC_ALL=C sort | while IFS= read -r treeFile ; do printf '%s %s\n' "$treeFile" "$( cksum < "$treeFile" )" ; done ) | cksum
}
rigTreeBefore="$( rigTree )"
rigTab="$( printf '\t' )"

echo "-- the build sequence, as the listing gives it --"
rigRun --list-namespaces rigrepo
rigAssert "control: the listing of the rig names the three projects, in its own order" "$( LC_ALL=C awk -F'\t' '{ printf "%s ", $2 }' "$rigTmp/out" )" "rigrepo/aa-app rigrepo/mm-none rigrepo/zz-base "

echo "-- the user manuals: the README.md of each project that has one --"
rigRun $rigOp user
rigAssert "one line a project, the project and the whole path of its README.md, in the order of the listing, and none for the project without one" "$rigRc $( cat "$rigTmp/out" )" "0 rigrepo/aa-app${rigTab}$rigWs/source/rigrepo/aa-app/README.md
rigrepo/zz-base${rigTab}$rigWs/source/rigrepo/zz-base/README.md"
rigRun $rigOp user rigrepo/zz-base
rigAssert "with a project, that README.md as it is" "$rigRc $( cat "$rigTmp/out" )" "0 # zz readme

The base."

echo "-- the maintainer manuals: the MAGIC.md of each --"
rigRun $rigOp maintainer
rigAssert "only the project that has a MAGIC.md is listed, with the whole path of the file" "$rigRc $( cat "$rigTmp/out" )" "0 rigrepo/aa-app${rigTab}$rigWs/source/rigrepo/aa-app/MAGIC.md"
rigRun $rigOp maintainer rigrepo/aa-app
rigAssert "with that project, its MAGIC.md as it is, and not its README.md" "$rigRc $( cat "$rigTmp/out" )" "0 # aa magic

Maintainer notes of the app."

echo "-- what it refuses --"
rigRun $rigOp
rigAssert "no kind" "$( rigRefused )" "1 0 1"
rigRun $rigOp both
rigAssert "a kind that is neither" "$( rigRefused )" "1 0 1"
rigRun $rigOp user rigrepo/none-such
rigAssert "a project that is none of the list" "$( rigRefused )" "1 0 1"
rigRun $rigOp maintainer rigrepo/zz-base
rigAssert "a project that has no file of that kind" "$( rigRefused )" "1 0 1"
rigRun $rigOp user rigrepo/mm-none
rigAssert "a project that has neither" "$( rigRefused )" "1 0 1"
rigRun $rigOp user ../../home/x
rigAssert "a path in place of a project" "$( rigRefused )" "1 0 1"
rigRun $rigOp user rigrepo/aa-app rigrepo/zz-base
rigAssert "a second project" "$( rigRefused )" "1 0 1"
rigAssert "it only reads: no file of the rig was written, made or removed" "$( rigTree )" "$rigTreeBefore"

echo "-- the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigOp <user|maintainer> [<project>]"
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s <user|maintainer> [<project>]' "$rigOp" )" "$rigHelpMd" || : )" "1 1 1"
rigAssert "the family's include has one arm for the manuals, which sources their include" "$( LC_ALL=C grep -c -x -e '	--manager-manual-\*)' "$rigHere/manager/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerManual.include"' "$rigHere/manager/AgentsTools.Manager.include" || : )" "1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER MANUAL READ CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_MANUAL_READ: OK (%d assertions, offline, distro workspace rig)\n' "$rigPasses"
