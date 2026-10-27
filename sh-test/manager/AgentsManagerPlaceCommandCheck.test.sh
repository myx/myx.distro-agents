#!/usr/bin/env bash
## Behavioural check on the workspace commands, declared once by each package in its workspace-commands.list (in sh-lib/config/ of
## myx.distro-agents, whose sh-lib is in folders, and in the sh-lib/ of the others)
## (a command a line: its name, its emoji part of it; how it runs, `output` or `terminal`; the command, `$MMDAPP` the
## root of the workspace; a TAB between them), and on their two products, neither made from the other: the tasks
## the editor's palette gets (each package's *Tools.Make.VSCodeTasksFragment.include, by the one emitter of
## myx.distro-source) and the console's commands of a workspace (--manager-place-command-list and
## --manager-place-command-run). The owner: "All same as added to palette". Held: the tasks are those of before,
## byte for byte, but for the blanks that ended some of their lines (GOLDEN, taken from the fragments as they were
## written by hand); a name and a command are set out as JSON strings; the list of a workspace has the commands of
## the packages it has, picked as the tasks are (myx.distro-source always, another where its console at the root
## is executable), and a directory, or a workspace that is not there, has none; the run runs the declared command
## in that workspace's root, with none of the console's variables, and ends with its status; a name that is not
## one of that workspace's commands runs nothing. NOTHING REAL IS RUN: the commands run here are the rig's own
## stand-ins, from an origin that is the real one but for the four declarations; no console of the rig is started.
## Offline; only the rig's own tree is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigListOp="--manager-place-command-list"
rigRunOp="--manager-place-command-run"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigPackage"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerPlaceCommandCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws-here" ; rigFar="$rigTmp/ws-far" ; rigHome="$rigTmp/home" ; rigOrigin="$rigTmp/origin"
rigShared="$rigHome/.agents/magic-team"
mkdir -p "$rigWs/.local/agents" "$rigFar/.local/agents" "$rigShared" "$rigTmp/docs"
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
rigSourced(){ ## include -- sourced in a function, as the assembler sources a fragment
	. "$1"
}
rigFragment(){ ## origin, package, prefix -- the fragment of that package, in its sh-lib/config/ where it has that folder, else in its sh-lib/
	local rigName="$1/myx/myx.distro-$2/sh-lib"
	[ -f "$rigName/config/$3.Make.VSCodeTasksFragment.include" ] && printf '%s\n' "$rigName/config/$3.Make.VSCodeTasksFragment.include" || printf '%s\n' "$rigName/$3.Make.VSCodeTasksFragment.include"
}
rigTasks(){ ## origin, package, prefix -- what that package's fragment gives the tasks array for the root /rig/ws-golden, as the assembler takes it: from inside a $( ), its last newlines gone
	( MMDAPP=/rig/ws-golden ; MDLT_ORIGIN="$1" ; printf '%s\n' "$( rigSourced "$( rigFragment "$1" "$2" "$3" )" )" )
}
## THE REAL LISTS ARE NEVER WRITTEN: what the four packages hold, summed now and again at the end
rigListPath(){ ## package, origin -- where that package declares its workspace commands
	case "$1" in
		agents) printf '%s\n' "$2/myx/myx.distro-agents/sh-lib/config/workspace-commands.list" ;;
		*) printf '%s\n' "$2/myx/myx.distro-$1/sh-lib/workspace-commands.list" ;;
	esac
}
rigRealSum(){ ## -- the sums of the lists of the four packages
	for rigPkg in source deploy remote agents ; do cksum "$( rigListPath "$rigPkg" "$MDLT_ORIGIN" )" 2> /dev/null ; done
}
rigRealBefore="$( rigRealSum )"

echo "-- 1. the tasks of the palette: those of before, made from the declarations --"
cat > "$rigTmp/golden.source" <<'RIGEOF'
			{
				"label": "🖥️ Start Source Console...",
				"type": "shell",
				"command": "bash '/rig/ws-golden/DistroSourceConsole.sh'",
				"group": {
					"kind": "build",
					"isDefault": true
				}
			},
			{
				"label": "⬇️ Pull/Sync All Known Sources...",
				"type": "shell",
				"command": "bash -c 'echo \"Distro DistroImageSync --all-tasks --execute-source-prepare-pull\" | /rig/ws-golden/DistroSourceConsole.sh --non-interactive'",
				"group": {
					"kind": "build",
					"isDefault": true
				}
			},
			{
				"label": "📥 Re-Build Source Index Snapshot (cached from source)...",
				"type": "shell",
				"command": "bash -c 'echo \"BuildCachedFromSource.fn.sh\" | /rig/ws-golden/DistroSourceConsole.sh --non-interactive'",
				"group": {
					"kind": "build",
					"isDefault": true
				}
			},
			{
				"label": "🛫 Ingest Source Changes...",
				"type": "shell",
				"command": "bash -c 'echo \"Distro DistroSourcePrepare --ingest-distro-index-from-source\" | /rig/ws-golden/DistroSourceConsole.sh --non-interactive'",
				"group": {
					"kind": "build",
					"isDefault": true
				}
			},
			{
				"label": "🛠️ Update Local Tools...",
				"type": "shell",
				"command": "bash '/rig/ws-golden/.local/myx/myx.distro-.local/sh-scripts/DistroLocalTools.fn.sh' --upgrade-installed-tools",
				"group": {
					"kind": "build",
					"isDefault": true
				}
			},
RIGEOF
cat > "$rigTmp/golden.deploy" <<'RIGEOF'
			{
				"label": "🖥️ Start Deploy Console...",
				"type": "shell",
				"command": "bash '/rig/ws-golden/DistroDeployConsole.sh'",
				"group": {
					"kind": "build",
					"isDefault": true
				}
			},
			{
				"label": "🏋️ Re-Build Deploy Data from Source (distro from source)...",
				"type": "shell",
				"command": "bash -c 'echo \"BuildDistroFromSource.fn.sh\" | /rig/ws-golden/DistroSourceConsole.sh --non-interactive'",
				"group": {
					"kind": "build",
					"isDefault": true
				}
			},
RIGEOF
cat > "$rigTmp/golden.remote" <<'RIGEOF'
			{
				"label": "🖥️ Start Remote Console...",
				"type": "shell",
				"command": "bash '/rig/ws-golden/DistroRemoteConsole.sh'",
				"group": {
					"kind": "build",
					"isDefault": true
				}
			},
RIGEOF
cat > "$rigTmp/golden.agents" <<'RIGEOF'
			{
				"label": "🤖 Start Agents Console...",
				"type": "shell",
				"command": "bash '/rig/ws-golden/DistroAgentsConsole.sh'",
				"group": {
					"kind": "build",
					"isDefault": true
				}
			},
RIGEOF
for rigPair in source:SourceTools deploy:DeployTools remote:RemoteTools agents:AgentsTools ; do
	rigTasks "$MDLT_ORIGIN" "${rigPair%%:*}" "${rigPair#*:}" > "$rigTmp/tasks.${rigPair%%:*}" 2> "$rigTmp/tasks.err"
	rigAssert "the tasks of myx.distro-${rigPair%%:*} are those of before, byte for byte, but for the blanks that ended lines, and nothing is said on stderr" \
		"$( cmp -s "$rigTmp/golden.${rigPair%%:*}" "$rigTmp/tasks.${rigPair%%:*}" && echo same || echo differs ) $( wc -c < "$rigTmp/tasks.err" | LC_ALL=C tr -d ' ' )" "same 0"
done
rigAssert "each package declares its commands once, in its own list: how many, and those that run with the whole terminal, the consoles" \
	"$( for rigPkg in source deploy remote agents ; do LC_ALL=C awk -F'\t' -v pkg="$rigPkg" '/^#/ || !NF { next } { all++ ; if ( NF != 3 || ( $2 != "output" && $2 != "terminal" ) ) bad++ ; if ( $2 == "terminal" ) term = term "," $1 } END { printf "%s=%d/%d%s ", pkg, all, bad + 0, term }' "$( rigListPath "$rigPkg" "$MDLT_ORIGIN" )" 2> /dev/null || printf '%s=none ' "$rigPkg" ; done )" \
	"source=5/0,🖥️ Start Source Console deploy=2/0,🖥️ Start Deploy Console remote=1/0,🖥️ Start Remote Console agents=1/0,🤖 Start Agents Console "
rigAssert "no fragment writes a task of its own: each is made from its package's list by the one emitter" \
	"$( for rigPair in source:SourceTools deploy:DeployTools remote:RemoteTools agents:AgentsTools ; do rigFile="$( rigFragment "$MDLT_ORIGIN" "${rigPair%%:*}" "${rigPair#*:}" )" ; printf '%s:%s ' "$( LC_ALL=C grep -c -e '"label"' -e '"command"' "$rigFile" || : )" "$( LC_ALL=C grep -c -F -e 'SourceTools.Make.VSCodeTasksFromWorkspaceCommands.include' "$rigFile" || : )" ; done )" "0:1 0:1 0:1 0:1 "

## THE ORIGIN OF THIS CHECK: the real one, linked, but for the list of each of the four packages, which is the rig's.
mkdir -p "$rigOrigin/myx"
for rigEntry in "$MDLT_ORIGIN"/* ; do [ "${rigEntry##*/}" = myx ] || ln -s "$rigEntry" "$rigOrigin/${rigEntry##*/}" ; done
for rigEntry in "$MDLT_ORIGIN"/myx/* ; do
	case "${rigEntry##*/}" in
		myx.distro-source|myx.distro-deploy|myx.distro-remote|myx.distro-agents) ;;
		*) ln -s "$rigEntry" "$rigOrigin/myx/${rigEntry##*/}" ; continue ;;
	esac
	## sh-lib and sh-lib/config are folders of the rig's own, with the files of the real ones linked in but for the list: a write to the list
	## must never go through a linked folder into the package
	mkdir -p "$rigOrigin/myx/${rigEntry##*/}/sh-lib"
	for rigOne in "$rigEntry"/* ; do [ "${rigOne##*/}" = sh-lib ] || ln -s "$rigOne" "$rigOrigin/myx/${rigEntry##*/}/${rigOne##*/}" ; done
	for rigOne in "$rigEntry"/sh-lib/* ; do case "${rigOne##*/}" in config|workspace-commands.list) ;; *) ln -s "$rigOne" "$rigOrigin/myx/${rigEntry##*/}/sh-lib/${rigOne##*/}" ;; esac ; done
	if [ -d "$rigEntry/sh-lib/config" ] ; then
		mkdir -p "$rigOrigin/myx/${rigEntry##*/}/sh-lib/config"
		for rigOne in "$rigEntry"/sh-lib/config/* ; do [ "${rigOne##*/}" = workspace-commands.list ] || ln -s "$rigOne" "$rigOrigin/myx/${rigEntry##*/}/sh-lib/config/${rigOne##*/}" ; done
	fi
	[ ! -L "$rigOrigin/myx/${rigEntry##*/}/sh-lib/config" ] || rigRefuse "the rig's sh-lib/config of ${rigEntry##*/} is a link into the package: the lists would be written there"
done
{
	printf '## the rig'"'"'s own commands of myx.distro-source\n\n'
	printf '🧪 Rig Output\toutput\tsh "$MMDAPP/rig-command.sh" output "two words"\n'
	printf '🧪 Rig "Quoted" \\ Back\toutput\tsh '"'"'${MMDAPP}/rig-command.sh'"'"' "a \\"b\\""\n'
} > "$( rigListPath source "$rigOrigin" )"
printf '🧪 Rig Deploy\toutput\tsh "$MMDAPP/rig-command.sh" deploy\n' > "$( rigListPath deploy "$rigOrigin" )"
printf '🧪 Rig Remote\toutput\tsh "$MMDAPP/rig-command.sh" remote\n' > "$( rigListPath remote "$rigOrigin" )"
printf '🧪 Rig Terminal\tterminal\tsh "$MMDAPP/rig-command.sh" terminal\n' > "$( rigListPath agents "$rigOrigin" )"
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigTasks "$rigOrigin" source SourceTools > "$rigTmp/tasks.rig" 2> /dev/null
rigAssert "a name and a command are set out as JSON strings: a quote and a backslash escaped, the root put for \$MMDAPP and \${MMDAPP}, a comment line and an empty one none" \
	"$( LC_ALL=C grep -c -e '^			{$' "$rigTmp/tasks.rig" || : ) $( rigWhole "$rigTmp/tasks.rig" '				"label": "🧪 Rig \"Quoted\" \\ Back...",' ) $( rigWhole "$rigTmp/tasks.rig" '				"command": "sh '"'"'/rig/ws-golden/rig-command.sh'"'"' \"a \\\"b\\\"\"",' ) $( rigWhole "$rigTmp/tasks.rig" '				"command": "sh \"/rig/ws-golden/rig-command.sh\" output \"two words\"",' )" "2 1 1 1"

## THE RIG: this workspace, with the consoles of deploy and agents executable at its root and that of remote not;
## a second workspace with none; a directory; and a workspace that is not there. Each workspace has the stand-in
## its commands run, which says what it was given, where, and with which of the console's variables.
{
	printf 'ws-here\tworkspace\tread-write\t%s\tworkspace\n' "$rigWs"
	printf 'docs\tdirectory\tread-only\t%s\towner\n' "$rigTmp/docs"
	printf 'ws-gone\tworkspace\tread-write\t%s\towner\n' "$rigTmp/ws-gone"
} > "$rigWs/.local/agents/directories.registry"
printf 'ws-far\tworkspace\tread-write\t%s\tworkspace\n' "$rigFar" > "$rigFar/.local/agents/directories.registry"
{
	for rigOne in ws-here docs ws-gone ; do printf '%s\t%s\n' "$rigOne" "$rigWs" ; done
	printf 'ws-far\t%s\n' "$rigFar"
} > "$rigShared/directories.registry"
: > "$rigWs/DistroSourceConsole.sh" ; : > "$rigWs/DistroDeployConsole.sh" ; : > "$rigWs/DistroRemoteConsole.sh" ; : > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroSourceConsole.sh" "$rigWs/DistroDeployConsole.sh" "$rigWs/DistroAgentsConsole.sh"
for rigOne in "$rigWs" "$rigFar" ; do
	printf '%s\n' '#!/bin/sh' \
		'{ printf "args:" ; for rigArg in "$@" ; do printf " [%s]" "$rigArg" ; done ; printf "\n" ; printf "cwd: %s\n" "$( pwd -P )" ; printf "origin: %s mmdapp: %s\n" "${MDLT_ORIGIN:-none}" "${MMDAPP:-none}" ; } >> "$( dirname "$0" )/rig-ran.txt"' \
		'echo "the rig command ran"' 'exit 3' > "$rigOne/rig-command.sh"
done
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace, as a console makes it; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigSaid(){ ## -- how many lines of the last stderr are of the call itself, but for those every rig of this package gets
	LC_ALL=C grep -v -F -e 'SystemContext' "$rigTmp/err" | LC_ALL=C grep -c . || :
}
rigRan(){ ## workspace root -- what its stand-in wrote, on one line, and it is cleared
	[ -f "$1/rig-ran.txt" ] || { printf 'nothing ran' ; return 0 ; }
	LC_ALL=C tr '\n' '|' < "$1/rig-ran.txt" ; rm -f "$1/rig-ran.txt"
}

echo "-- 2. the commands of a workspace --"
rigRun "$rigListOp" ws-here
rigAssert "this workspace: the commands of myx.distro-source, then of each package whose console at its root is executable, in the palette's order, a row each, whitespace of a name as _" \
	"$rigRc $( LC_ALL=C grep '^command' "$rigTmp/out" | LC_ALL=C tr '\t\n' ' |' )" \
	"0 command 🧪_Rig_Output myx.distro-source output|command 🧪_Rig_\"Quoted\"_\\_Back myx.distro-source output|command 🧪_Rig_Deploy myx.distro-deploy output|command 🧪_Rig_Terminal myx.distro-agents terminal|"
rigAssert "it begins with whether it is the workspace the call runs in, and how many sessions name it" "$( LC_ALL=C awk -F'\t' '$1 == "here" || $1 == "sessions" { printf "%s=%s ", $1, $2 }' "$rigTmp/out" )" "here=yes sessions=- "
rigRun "$rigListOp" ws-far
rigAssert "a workspace other than the one the call runs in says so" "$( LC_ALL=C awk -F'\t' '$1 == "here" { printf "%s=%s ", $1, $2 }' "$rigTmp/out" )" "here=no "
rigAssert "a workspace with no console at its root has the commands of myx.distro-source alone" "$rigRc $( LC_ALL=C grep '^command' "$rigTmp/out" | LC_ALL=C cut -f2 | LC_ALL=C tr '\n' ' ' )" "0 🧪_Rig_Output 🧪_Rig_\"Quoted\"_\\_Back "
rigRun "$rigListOp" docs
rigAssert "a directory has none, and that is no error" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigSaid )" "0 0 0"
rigRun "$rigListOp" ws-gone
rigAssert "nor has a workspace that is not there" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "0 0"
rigRun "$rigListOp" no-such
rigAssert "a name that is no place is refused in one line, nothing printed" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigSaid ) $( LC_ALL=C grep -c -F -e "⛔ ERROR: DistroAgentsTools $rigListOp: no place is named 'no-such'" "$rigTmp/err" || : )" "1 0 1 1"
rigRun "$rigListOp"
rigAssert "and so is a call with no place" "$rigRc $( LC_ALL=C grep -c -F -e "syntax is $rigListOp <place>" "$rigTmp/err" || : )" "1 1"

echo "-- 3. a command run --"
rigRun "$rigRunOp" ws-far "🧪_Rig_Output"
rigAssert "the run runs the declared command in that workspace's root, by the name the list gives, with none of the console's variables, and ends with its status, its output its own" \
	"$rigRc $( rigRan "$rigFar" ) $( cat "$rigTmp/out" )" "3 args: [output] [two words]|cwd: $rigFar|origin: none mmdapp: none| the rig command ran"
rigRun "$rigRunOp" ws-here "🧪 Rig \"Quoted\" \\ Back"
rigAssert "a name is taken with its blanks too, and a command with quotes in it runs as it is written" "$rigRc $( rigRan "$rigWs" )" "3 args: [a \"b\"]|cwd: $rigWs|origin: none mmdapp: none|"
rigRun "$rigRunOp" ws-here "🧪_Rig_Terminal"
rigAssert "one that runs with the whole terminal is run the same way: the console gives it the terminal" "$rigRc $( rigRan "$rigWs" )" "3 args: [terminal]|cwd: $rigWs|origin: none mmdapp: none|"
rigRun "$rigRunOp" ws-far "🧪_Rig_Deploy"
rigAssert "a name that is not one of that workspace's commands is refused in one line, and nothing runs" "$rigRc $( rigSaid ) $( LC_ALL=C grep -c -F -e "⛔ ERROR: DistroAgentsTools $rigRunOp: '🧪_Rig_Deploy' is none of the commands of 'ws-far'" "$rigTmp/err" || : ) $( rigRan "$rigFar" )" "1 1 1 nothing ran"
rigRun "$rigRunOp" docs "🧪_Rig_Output"
rigAssert "a directory runs nothing" "$rigRc $( rigRan "$rigWs" ) $( rigRan "$rigFar" )" "1 nothing ran nothing ran"
rigRun "$rigRunOp" ws-here
rigAssert "a call without a command is refused by its syntax" "$rigRc $( LC_ALL=C grep -c -F -e "syntax is $rigRunOp <place> <command>" "$rigTmp/err" || : )" "1 1"

echo "-- 3b. the commands of the workspace the call runs in --"
rigRun --manager-workspace-command-run "🧪_Rig_Terminal"
rigAssert "the workspace's own command runs as a command of its location does, in its root" "$rigRc $( rigRan "$rigWs" )" "3 args: [terminal]|cwd: $rigWs|origin: none mmdapp: none|"
rigRun --manager-workspace-command-run "🧪 Rig \"Quoted\" \\ Back"
rigAssert "a name is taken with its blanks too" "$rigRc $( rigRan "$rigWs" )" "3 args: [a \"b\"]|cwd: $rigWs|origin: none mmdapp: none|"
rigRun --manager-workspace-command-list
rigAssert "its list is the one of the location, without the rows of the location" "$rigRc $( LC_ALL=C tr '\t\n' ' |' < "$rigTmp/out" )" "0 command 🧪_Rig_Output myx.distro-source output|command 🧪_Rig_\"Quoted\"_\\_Back myx.distro-source output|command 🧪_Rig_Deploy myx.distro-deploy output|command 🧪_Rig_Terminal myx.distro-agents terminal|"

rigAssert "nothing of the rig was written into the package: the four lists are as they were" "$( rigRealSum | cksum )" "$( printf '%s\n' "$rigRealBefore" | cksum )"

echo "-- 4. the help pair --"
for rigSyntax in "$rigListOp <place>" "$rigRunOp <place> <command>" ; do
	rigAssert "$rigSyntax has its syntax echo, its syntax line and its entry, once each" \
		"$( rigWhole "$rigHere/help/Help.DistroAgentsTools.include" "echo \"📘 syntax: DistroAgentsTools.fn.sh $rigSyntax\" >&2" ) $( rigWhole "$rigHere/help/Help.DistroAgentsTools.help.md" "📘 syntax: DistroAgentsTools.fn.sh $rigSyntax" ) $( rigWhole "$rigHere/help/Help.DistroAgentsTools.help.md" "$( printf '\t\t%s' "$rigSyntax" )" )" "1 1 1"
done

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER PLACE COMMAND CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_PLACE_COMMAND: OK (%d assertions, offline)\n' "$rigPasses"
