#!/usr/bin/env bash
## Behavioural check on `Installed Subsystems` of the console's configuration (F11.7 of the refactorings epic), run rather than read:
## --manager-subsystem-list and --manager-subsystem-run, which the agents' dispatcher offers from `.local`'s include, and the local
## tools' own --uninstall-distro-<name>, against a rig workspace built here. The install is never run for real: the local tools the
## operation calls are a stand-in that writes its call down; the uninstall is run for real, but in the rig's own tree.
## Held (F11.7: "`Installed Subsystems` displays the subsystem list with installed status, and indented commands to install or
## uninstall ... It does not allow uninstalling the current subsystem's console, or `.local`. Owned by `.local`"; the coordinator's
## ruling: "the epic is the order for .local here ... Add --uninstall-distro-<x> in .local with its help pair and tests", refusing
## .local and the console's own subsystem):
##   1. the list: the six subsystems in order, each installed where its installed copy stands in the workspace's .local/myx, with its
##      role (the base, the shared, the console that is asking) and whether install and uninstall are offered
##   2. a run: install of a missing toolset and uninstall of an installed one call the local tools with exactly that option, the
##      output and the exit status theirs; a command the row does not offer, .local, system, the console's own, a toolset that
##      is installed (install) or missing (uninstall), a name or a command that is none and a wrong count of words are refused with
##      nothing run
##   3. --uninstall-distro-<name> removes the installed copy of remote, deploy, source or agents and the console command the install
##      made, and nothing else of the workspace; several combine; .local and system are refused, a toolset that is not installed
##      is refused, and so is an option that is none; a refusal removes nothing
##   4. from inside a member's session both operations are refused; the help pair of each
## Offline; only the rig's own tree is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigLocal="$MDLT_ORIGIN/myx/myx.distro-.local"
rigLocalTool="$rigLocal/sh-scripts/DistroLocalTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] && [ -f "$rigLocalTool" ] || rigRefuse "the tool is not at the origin this workspace resolves"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSubsystemCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigHome" "$rigSkills" "$rigWs/remote/static" "$rigWs/source" "$rigWs/distro"
: > "$rigWs/.local/.agents/keeper-rig.agent.env" ; chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env
## the installed copies of the rig: .local, system, deploy, remote and agents; source is missing
for rigOne in .local system deploy remote agents ; do
	mkdir -p "$rigWs/.local/myx/myx.distro-$rigOne/sh-scripts"
	: > "$rigWs/.local/myx/myx.distro-$rigOne/sh-scripts/marker"
done
printf 'MDLT_CONSOLE_ORIGIN=.local\n' > "$rigWs/.local/MDLT.settings.env"
for rigOne in Local Deploy Remote Agents ; do printf '#!/bin/sh\n' > "$rigWs/Distro${rigOne}Console.sh" ; done
printf 'rig note\n' > "$rigWs/NOTES.txt"
## THE STAND-IN FOR THE LOCAL TOOLS: it writes its call down and prints one line; its exit status is the rig's to say
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/local.calls"\necho "rig-local-tools says: $*"\nexit "${RIG_LOCAL_RC:-0}"\n' "$rigTmp" > "$rigTmp/local-tools-stub.sh"
: > "$rigTmp/local.calls"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
: > "$rigTmp/all"
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace, the stand-in as the local tools; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_MANAGER_LOCAL_TOOLS="$rigTmp/local-tools-stub.sh" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}
rigLocalRun(){ ## local tools arguments... -- the real local tools, from the rig workspace
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigLocalTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}
rigTroubles(){ LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || : ; }
rigFlat(){ LC_ALL=C tr '\t' ' ' < "$1" | LC_ALL=C tr '\n' '/' ; }
rigCalls(){ LC_ALL=C tr '\n' '/' < "$rigTmp/local.calls" ; }

echo "-- 1. the list --"
rigRun --manager-subsystem-list
rigAssert "the call ends 0, with no error, and lists the six in order: .local the base and system the shared with no command, deploy and remote installed and offered the uninstall, source missing and offered the install, agents installed and the console that asks, so not offered the uninstall" "$rigRc $( rigTroubles ) $( rigFlat "$rigTmp/out" )" \
	"0 0 subsystem .local installed base no no/subsystem system installed shared no no/subsystem deploy installed - no yes/subsystem source missing - yes no/subsystem remote installed - no yes/subsystem agents installed console no no/"
rm -rf "$rigWs/.local/myx/myx.distro-system"
rigRun --manager-subsystem-list
rigAssert "a subsystem whose copy is not there reads missing, and system has no command whether it is there or not" "$( LC_ALL=C awk -F'\t' '$2 == "system" { print $3, $5, $6 }' "$rigTmp/out" )" "missing no no"
mkdir -p "$rigWs/.local/myx/myx.distro-system/sh-scripts"
rigRun --manager-subsystem-list extra
rigAssert "a word after it is refused" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 0"

echo "-- 2. a run --"
: > "$rigTmp/local.calls"
rigRun --manager-subsystem-run install source
rigAssert "install of a missing toolset calls the local tools with --install-distro-<name> and nothing else, and what they wrote comes back" "$rigRc $( rigCalls ) $( cat "$rigTmp/out" )" "0 --install-distro-source/ rig-local-tools says: --install-distro-source"
: > "$rigTmp/local.calls"
rigPre=(RIG_LOCAL_RC=3)
rigRun --manager-subsystem-run uninstall remote
rigPre=()
rigAssert "uninstall of an installed one calls it with --uninstall-distro-<name>, and their exit status is the operation's" "$rigRc $( rigCalls )" "3 --uninstall-distro-remote/"
: > "$rigTmp/local.calls"
rigBad=""
for rigOne in "install deploy" "uninstall source" "uninstall agents" "install agents" "install .local" "uninstall .local" "install system" "uninstall system" "install no-such-thing" "remove deploy" "install" "install source extra" ; do
	rigRun --manager-subsystem-run $rigOne
	[ "$rigRc" = 1 ] && [ "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" = 0 ] || rigBad="$rigBad [$rigOne]"
done
rigAssert "install of an installed toolset, uninstall of a missing one, the console's own either way, .local, system, a name and a command that are none and a wrong count of words are each refused, with nothing on stdout" "${rigBad:- all refused}" " all refused"
rigAssert "and nothing of them was run" "$( rigCalls )" ""
rigRun --manager-subsystem-run uninstall agents
rigAssert "the refusal of the console's own says it is the console that asks, and repeats nothing of what was given but the subsystem's name" "$( LC_ALL=C grep -c -F -- 'is the console that asks' "$rigTmp/err" )" "1"

echo "-- 3. the uninstall of the local tools --"
rigLocalRun --uninstall-distro-remote
rigAssert "the installed copy of a toolset and the console command the install made for it are removed, and said" "$rigRc $( [ -e "$rigWs/.local/myx/myx.distro-remote" ] && echo copy || echo gone ) $( [ -e "$rigWs/DistroRemoteConsole.sh" ] && echo launcher || echo gone ) $( LC_ALL=C grep -c -F -- 'removed' "$rigTmp/err" )" "0 gone gone 1"
rigAssert "the data of the workspace, its settings, the other toolsets and their console commands stand" "$( [ -d "$rigWs/remote/static" ] && echo remote-data ) $( [ -f "$rigWs/.local/MDLT.settings.env" ] && echo settings ) $( [ -d "$rigWs/.local/myx/myx.distro-deploy" ] && echo deploy ) $( [ -f "$rigWs/DistroDeployConsole.sh" ] && echo launcher ) $( [ -f "$rigWs/NOTES.txt" ] && echo notes )" "remote-data settings deploy launcher notes"
rigLocalRun --uninstall-distro-deploy --uninstall-distro-agents
rigAssert "several combine in one run" "$rigRc $( [ -e "$rigWs/.local/myx/myx.distro-deploy" ] || [ -e "$rigWs/.local/myx/myx.distro-agents" ] && echo left || echo gone ) $( [ -e "$rigWs/DistroDeployConsole.sh" ] || [ -e "$rigWs/DistroAgentsConsole.sh" ] && echo left || echo gone )" "0 gone gone"
rigBad=""
for rigOne in --uninstall-distro-.local --uninstall-distro-system --uninstall-distro-source --uninstall-distro-remote --uninstall-distro-no-such ; do
	rigLocalRun $rigOne
	[ "$rigRc" = 1 ] && [ -d "$rigWs/.local/myx/myx.distro-.local" ] && [ -d "$rigWs/.local/myx/myx.distro-system" ] && [ -f "$rigWs/DistroLocalConsole.sh" ] || rigBad="$rigBad [$rigOne]"
done
rigAssert ".local, system, a toolset that is not installed (source, and remote, which was removed) and an option that is none are each refused, and .local and system stand" "${rigBad:- all refused}" " all refused"
rigAssert "an option that is none is named in the one line of its refusal, as every invalid option of the local tools is" "$( LC_ALL=C grep -c -F -- 'invalid option: --uninstall-distro-no-such' "$rigTmp/err" || : )" "1"

echo "-- 4. from a member's session, and the help pair --"
rigPre=(MDAT_SPAWN_AGENT=magic-coordinator)
rigBad=""
rigRun --manager-subsystem-list ; [ "$rigRc" = 1 ] && [ "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" = 0 ] || rigBad="$rigBad [list]"
rigRun --manager-subsystem-run install source ; [ "$rigRc" = 1 ] && [ ! -s "$rigTmp/local.calls" ] || rigBad="$rigBad [run]"
rigPre=()
rigAssert "a member's session is refused both, magic-coordinator's too" "${rigBad:- all refused}" " all refused"
rigBad=""
for rigOne in "--manager-subsystem-list" "--manager-subsystem-run (install|uninstall) <subsystem>" ; do
	LC_ALL=C grep -q -F -- "DistroAgentsTools.fn.sh $rigOne" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.include" || rigBad="$rigBad [include $rigOne]"
	LC_ALL=C grep -q -x -F -- "		$rigOne" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md" || rigBad="$rigBad [help.md $rigOne]"
done
LC_ALL=C grep -q -E -- '^[[:space:]]+--uninstall-distro-(remote|deploy|source|agents)' "$rigLocal/sh-lib/help/Help.DistroLocalTools.help.md" || rigBad="$rigBad [local help.md]"
rigAssert "each operation has its syntax line and its help entry, and the local tools' help names --uninstall-distro-<name>" "${rigBad:- all paired}" " all paired"

printf '\nTOTAL: %d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
