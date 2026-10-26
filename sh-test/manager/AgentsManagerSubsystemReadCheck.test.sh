#!/usr/bin/env bash
## Behavioural check on --manager-subsystem-read <subsystem> (C1 of the refactorings epic): one subsystem's repository
## and its user manual, the README.md of its package, which the content-pane of `Installed Subsystems` shows for the
## subsystem selected. Run rather than read, against a rig workspace built here. The install is never run for real, and
## nothing of the machine's own tree is read.
## Held: with a subsystem, one `repository` row holding the address its project.inf declares under
## `distro-image-sync:source-prepare-pull:repo:`, a `readme` row holding the whole path of the README.md it read, then
## that README as it is; a package that declares no repository has `-`; one with no README prints the two rows and
## nothing after them, and ends 0. The README is read from the installed copy where that stands (its project.inf), else
## from the source tree of the origin. A word that is none of the six, no word, a second word, and a path in place of a
## subsystem are refused, rc 1, nothing on stdout, in one line. It only reads: every file of the rig is as it was.
## From inside a member's session it is refused. And the help pair. Offline; nothing reaches another host.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-subsystem-read"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSubsystemReadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigHome" "$rigSkills" "$rigWs/remote/static" "$rigWs/source" "$rigWs/distro"
: > "$rigWs/.local/.agents/keeper-rig.agent.env" ; chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env
printf 'MDLT_CONSOLE_ORIGIN=.local\n' > "$rigWs/.local/MDLT.settings.env"
## the installed copies the read is made from: deploy and agents with a repository and a README, remote with neither
for rigOne in .local system deploy remote agents ; do
	mkdir -p "$rigWs/.local/myx/myx.distro-$rigOne/sh-scripts"
	: > "$rigWs/.local/myx/myx.distro-$rigOne/sh-scripts/marker"
done
rigRepoLine(){ printf 'distro-image-sync:source-prepare-pull:repo:%s\n' "$1" ; }
rigRepoLine "myx/myx.distro-deploy:main:git@github.com:myx/myx.distro-deploy.git" > "$rigWs/.local/myx/myx.distro-deploy/project.inf"
printf '# deploy readme\n\nThe deploy side.\n' > "$rigWs/.local/myx/myx.distro-deploy/README.md"
rigRepoLine "myx/myx.distro-agents:main:git@github.com:myx/myx.distro-agents.git" > "$rigWs/.local/myx/myx.distro-agents/project.inf"
printf '# agents readme\n\nThe agents.\n' > "$rigWs/.local/myx/myx.distro-agents/README.md"
## remote has an installed project.inf that declares no repository, and no README, so the read stays on the installed copy
: > "$rigWs/.local/myx/myx.distro-remote/project.inf"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
: > "$rigTmp/all"
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}
rigRefused(){ ## -- rc, what stdout held in bytes, and whether stderr names an error
	printf '%s %s %s' "$rigRc" "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "$( LC_ALL=C grep -c -F -- '⛔ ERROR: DistroAgentsTools --manager-subsystem-read:' "$rigTmp/err" || : )"
}
rigTree(){ ## -- every file of the rig, each with the sum of its bytes, as one sum
	( cd "$rigTmp" && find ws home skills -type f 2> /dev/null | LC_ALL=C sort | while IFS= read -r treeFile ; do printf '%s %s\n' "$treeFile" "$( cksum < "$treeFile" )" ; done ) | cksum
}
rigTreeBefore="$( rigTree )"

echo "-- 1. the read of an installed toolset: its repository and its README --"
rigRun "$rigOp" deploy
rigAssert "the call ends 0, with no error, and prints the repository row, the readme row, then the README as it is" "$rigRc $( cat "$rigTmp/out" )" "0 repository	git@github.com:myx/myx.distro-deploy.git
readme	$rigWs/.local/myx/myx.distro-deploy/README.md
# deploy readme

The deploy side."
rigRun "$rigOp" agents
rigAssert "another toolset, the console's own, reads the same way from its installed copy" "$rigRc $( LC_ALL=C sed -n '1,2p' "$rigTmp/out" | LC_ALL=C tr '\t' '|' | LC_ALL=C tr '\n' '/' )" "0 repository|git@github.com:myx/myx.distro-agents.git/readme|$rigWs/.local/myx/myx.distro-agents/README.md/"

echo "-- 2. a package that declares no repository, and one with no README --"
rigRun "$rigOp" remote
rigAssert "a package whose project.inf declares no repository reads -, and one with no README prints the two rows and nothing after them, rc 0" "$rigRc $( LC_ALL=C tr '\t' '|' < "$rigTmp/out" | LC_ALL=C tr '\n' '/' )" "0 repository|-/readme|$rigWs/.local/myx/myx.distro-remote/README.md/"

echo "-- 3. a missing toolset is read from the source tree of the origin --"
rigRun "$rigOp" source
rigAssert "the toolset that is not installed reads the project.inf and README of the origin's source tree, its repository as the real one declares it" "$rigRc $( LC_ALL=C sed -n '1,2p' "$rigTmp/out" | LC_ALL=C tr '\t' '|' | LC_ALL=C tr '\n' '/' )" "0 repository|git@github.com:myx/myx.distro-source.git/readme|$MDLT_ORIGIN/myx/myx.distro-source/README.md/"

echo "-- 4. what it refuses --"
rigRun "$rigOp" no-such-thing
rigAssert "a word that is none of the six is refused, rc 1, nothing printed, and names the six" "$( rigRefused ) $( LC_ALL=C grep -c -F -- '.local, system, deploy, source, remote, agents' "$rigTmp/err" || : )" "1 0 1 1"
rigRun "$rigOp"
rigAssert "no word is refused with its syntax" "$( rigRefused )" "1 0 1"
rigRun "$rigOp" deploy extra
rigAssert "a second word is refused" "$( rigRefused )" "1 0 1"
rigRun "$rigOp" ../deploy
rigAssert "a path in place of a subsystem is refused and not repeated" "$( rigRefused ) $( LC_ALL=C grep -c -F -- '../deploy' "$rigTmp/err" || : )" "1 0 1 0"
rigAssert "it only reads: no file of the rig was written, made or removed" "$( rigTree )" "$rigTreeBefore"

echo "-- 5. from inside a member's session, and the help pair --"
rigPre=( "MDAT_SPAWN_AGENT=magic-coordinator" )
rigRun "$rigOp" deploy
rigPre=()
rigAssert "a member's session is refused, magic-coordinator's too, rc 1, nothing printed" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 0"
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each" "$( LC_ALL=C grep -c -x -F -- "echo \"📘 syntax: DistroAgentsTools.fn.sh $rigOp <subsystem>\" >&2" "$rigHere/help/Help.DistroAgentsTools.include" || : ) $( LC_ALL=C grep -c -x -F -- "📘 syntax: DistroAgentsTools.fn.sh $rigOp <subsystem>" "$rigHere/help/Help.DistroAgentsTools.help.md" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s <subsystem>' "$rigOp" )" "$rigHere/help/Help.DistroAgentsTools.help.md" || : )" "1 1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER SUBSYSTEM READ CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SUBSYSTEM_READ: OK (%d assertions, offline, workspace rig)\n' "$rigPasses"
