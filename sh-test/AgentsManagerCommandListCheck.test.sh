#!/usr/bin/env bash
## Behavioural check on --manager-command-list, the operation of the console's own family --manager-* that lists the
## tooling commands a console user calls by name, run rather than read, against a rig workspace built here. Held:
## each line is one base name with its extension, `<Name>.fn.sh`, as a user types it, a TAB, and the file that
## name resolves to on the console's PATH (the owner: "show them in left pane in table with source paths"): the
## family's own in the folder of their package, a project's in the folder the index names, of a name two projects
## declare the one of the first folder, the file the shell finds for it also where its executable bit is gone, and
## `-` for a name no folder holds; the names are
## what the console's completion gathers by its own two readers and nothing else: the `*.fn.sh` of the sh-scripts
## folders of the family's packages (`Agents --completion-all`), and the project-declared commands of the index the
## workspace holds at .local/distro-commands.txt (`Distro --shell-path-append --completion`), a project's command
## that no family filter of `Distro <TAB>` keeps among them; a name two projects declare is listed once; with no
## index the family's alone; the call reads only. The caller rule of the family holds for it, its place in the
## family is one arm and one include, which finds nothing a second way, and its help pair is there.
## Offline; only the rig's own tree is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-command-list"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerCommandListCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local" "$rigHome"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}

## THE RIG WORKSPACE: two projects that declare commands, as the source-prepare stage indexes them, one line a
## command, `<project> <name> <scripts folder>`, only an executable one: both declare ScreenTo, one also JumpRig.
printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigWs/.local/MDLT.settings.env"
for rigProject in rig/farm-a rig/farm-b ; do
	mkdir -p "$rigWs/source/$rigProject/sh-scripts"
	for rigName in ScreenTo TwinRig ; do
		printf '#!/bin/sh\necho rig\n' > "$rigWs/source/$rigProject/sh-scripts/$rigName.fn.sh"
		chmod +x "$rigWs/source/$rigProject/sh-scripts/$rigName.fn.sh"
	done
done
printf '#!/bin/sh\necho rig\n' > "$rigWs/source/rig/farm-b/sh-scripts/JumpRig.fn.sh"
chmod +x "$rigWs/source/rig/farm-b/sh-scripts/JumpRig.fn.sh"
## one whose file has lost its executable bit since the index was built, and one whose file is gone
printf '#!/bin/sh\necho rig\n' > "$rigWs/source/rig/farm-b/sh-scripts/BareRig.fn.sh"
{
	printf '%s %s %s\n' rig/farm-a ScreenTo "$rigWs/source/rig/farm-a/sh-scripts"
	printf '%s %s %s\n' rig/farm-b ScreenTo "$rigWs/source/rig/farm-b/sh-scripts"
	printf '%s %s %s\n' rig/farm-a TwinRig "$rigWs/source/rig/farm-a/sh-scripts"
	printf '%s %s %s\n' rig/farm-b TwinRig "$rigWs/source/rig/farm-b/sh-scripts"
	printf '%s %s %s\n' rig/farm-b JumpRig "$rigWs/source/rig/farm-b/sh-scripts"
	printf '%s %s %s\n' rig/farm-b BareRig "$rigWs/source/rig/farm-b/sh-scripts"
	printf '%s %s %s\n' rig/farm-b GoneRig "$rigWs/source/rig/farm-b/sh-scripts"
} > "$rigWs/.local/distro-commands.txt"
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace, as a console makes it; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
## What the family's packages hold, the oracle of this check: the `*.fn.sh` of each sh-scripts folder of the family.
rigFamily(){
	for rigItem in agents .local system deploy source remote ; do
		[ -d "$MDLT_ORIGIN/myx/myx.distro-$rigItem/sh-scripts" ] || continue
		find "$MDLT_ORIGIN/myx/myx.distro-$rigItem/sh-scripts" -type f -name '*.fn.sh'
	done | LC_ALL=C sed 's:^.*/::'
}
rigTree(){
	( cd "$rigWs" && find . -print | LC_ALL=C sort | while IFS= read -r rigFile ; do [ -f "$rigFile" ] && cksum < "$rigFile" ; printf '%s\n' "$rigFile" ; done )
}
rigNames(){ ## file -- its names, the first field of each line
	LC_ALL=C cut -f1 "$1"
}
rigPathOf(){ ## name -- the path the last list gives that name
	LC_ALL=C awk -F'\t' -v name="$1" '$1 == name { print $2 }' "$rigTmp/out"
}

echo "-- 1. the commands the completion gathers, by their base names --"
rigBefore="$( rigTree )"
rigRun "$rigOp"
rigAssert "it ends rc 0, and writes nothing to stderr but the tooling's own lines" "$rigRc $( LC_ALL=C grep -v -e '^AgentsContext' -e '^SystemContext' -e 'Working in:' "$rigTmp/err" | LC_ALL=C grep -c . || : )" "0 0"
rigAssert "every line is one base name with its extension, as a user types it, a TAB, and a path or a dash: no blank" \
	"$( LC_ALL=C awk -F'\t' '{ lines++ ; if ( NF != 2 || $1 !~ /^[^\/ \t]+\.fn\.sh$/ || ( $2 != "-" && $2 !~ /^\// ) ) bad++ ; } END { printf "%s:%s", ( lines > 3 ? "lines" : "few" ), bad + 0 }' "$rigTmp/out" )" "lines:0"
rigNames "$rigTmp/out" > "$rigTmp/names"
rigAssert "the project-declared commands of the index are there, one that no filter of Distro's own completion keeps among them, and a name two projects declare stands once" \
	"$( rigWhole "$rigTmp/names" ScreenTo.fn.sh ) $( rigWhole "$rigTmp/names" JumpRig.fn.sh )" "1 1"
rigAssert "the family's own are there, this package's dispatcher among them" "$( rigWhole "$rigTmp/names" DistroAgentsTools.fn.sh )" "1"
rigAssert "and nothing else: the list is the family's commands and the index's, each once" \
	"$( LC_ALL=C sort "$rigTmp/names" | LC_ALL=C tr '\n' ' ' )" "$( { rigFamily ; printf '%s\n' ScreenTo.fn.sh TwinRig.fn.sh JumpRig.fn.sh BareRig.fn.sh GoneRig.fn.sh ; } | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )"
rigAssert "a command of the family stands with the file of its package, as the console's PATH resolves it" \
	"$( rigPathOf DistroAgentsTools.fn.sh )" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigAssert "a project's command with the file in the folder the index names; of a name two projects declare, the first folder's" \
	"$( rigPathOf JumpRig.fn.sh ) $( rigPathOf TwinRig.fn.sh )" "$rigWs/source/rig/farm-b/sh-scripts/JumpRig.fn.sh $rigWs/source/rig/farm-a/sh-scripts/TwinRig.fn.sh"
rigAssert "a name a project declares and the family holds too resolves to the family's file, whose folder stands first on the PATH" \
	"$( rigPathOf ScreenTo.fn.sh )" "$( [ -f "$MDLT_ORIGIN/myx/myx.distro-deploy/sh-scripts/ScreenTo.fn.sh" ] && echo "$MDLT_ORIGIN/myx/myx.distro-deploy/sh-scripts/ScreenTo.fn.sh" || echo "$rigWs/source/rig/farm-a/sh-scripts/ScreenTo.fn.sh" )"
rigAssert "a file without its executable bit is the one the shell finds for its name; a name no folder holds is listed with a dash" "$( rigPathOf BareRig.fn.sh ) $( rigPathOf GoneRig.fn.sh )" "$rigWs/source/rig/farm-b/sh-scripts/BareRig.fn.sh -"
rigAssert "every path the list gives is a file of that name" \
	"$( LC_ALL=C awk -F'\t' '$2 != "-"' "$rigTmp/out" | while IFS=$'\t' read -r rigName rigPath ; do [ -f "$rigPath" ] && [ "${rigPath##*/}" = "$rigName" ] || echo bad ; done | LC_ALL=C grep -c . || : )" "0"
rigAssert "the call reads only: no file of the rig changes" "$( [ "$( rigTree )" = "$rigBefore" ] && echo same || echo changed )" "same"

echo "-- 2. with no index, the family's alone --"
mv "$rigWs/.local/distro-commands.txt" "$rigTmp/distro-commands.kept"
rigRun "$rigOp"
rigAssert "rc 0, and the list is the family's commands alone" "$rigRc $( rigNames "$rigTmp/out" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "0 $( rigFamily | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )"
mv "$rigTmp/distro-commands.kept" "$rigWs/.local/distro-commands.txt"

echo "-- 3. the caller rule, and the place in the family --"
rigPre=( "MDAT_SPAWN_AGENT=magic-coordinator" )
rigRun "$rigOp"
rigPre=()
rigAssert "from inside a member's session it is refused, rc 1, nothing on stdout" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 0"
rigRun "$rigOp" --all
rigAssert "an argument is refused, rc 1, nothing on stdout, in one line with its syntax: the list takes none" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is no argument, got: --all" )" "1 0 1"
rigAssert "the family has one arm for the commands, which sources their include" \
	"$( LC_ALL=C grep -c -x -e '	--manager-command-\*)' "$rigHere/manager/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerCommand.include"' "$rigHere/manager/AgentsTools.Manager.include" || : )" "1 1"
rigAssert "the include gathers by the completion's two readers, resolves on a PATH by the shell's own lookup, the index's folders by its one reader, and scans nothing of its own" \
	"$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerCommand.include" | LC_ALL=C grep -c -F -e 'Agents --completion-all' -e 'Distro --shell-path-append --completion' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerCommand.include" | LC_ALL=C grep -c -F -e 'command -v' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerCommand.include" | LC_ALL=C grep -c -E 'Distro --shell-path-append \)' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerCommand.include" | LC_ALL=C grep -c -e 'find ' -e 'ls ' -e 'distro-commands' || : )" "2 1 1 0"

echo "-- 4. the help pair --"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigOp"
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each" \
	"$( rigWhole "$rigHere/help/Help.DistroAgentsTools.include" "echo \"$rigSyntax\" >&2" ) $( rigWhole "$rigHere/help/Help.DistroAgentsTools.help.md" "$rigSyntax" ) $( rigWhole "$rigHere/help/Help.DistroAgentsTools.help.md" "$( printf '\t\t%s' "$rigOp" )" )" "1 1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER COMMAND LIST CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_COMMAND_LIST: OK (%d assertions, offline)\n' "$rigPasses"
