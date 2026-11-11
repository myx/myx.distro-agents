#!/usr/bin/env bash
## AgentsCommandPathCheck -- a tooling command resolves by its name in every shell the team uses (epic S12.25): the one path
## include (`myx.distro-.local/sh-lib/console-.local-path.include`) is read by the console, by `execute`
## (`--intern-mcp-execute`) and by the harness `Bash` tool (AgentsHarnessToolsBash.include).
## Guards: a clean PATH does not resolve `DistroAgentsTools.fn.sh`; with the include it resolves to the agents package's
## sh-scripts, the `.local` package's scripts standing before the agents' on the path; a project command the prepared index
## (`.local/distro-commands.txt`) names resolves too, and a second sourcing appends nothing; `execute` resolves the tooling
## command and the project command by name from a clean PATH; the served Bash tool resolves both too. The include starts no
## process.
## Red: a Bash tool that keeps only the PATH it was handed fails `the Bash tool resolves a command by name`.
## Offline: a temp workspace of this check alone, removed at its end; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigInclude="$rigOrigin/myx/myx.distro-.local/sh-lib/console-.local-path.include"
rigMember="rig-a"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
[ -f "$rigInclude" ] || rigRefuse "the path include is not at the origin this workspace resolves: $rigInclude"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommandPathCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/skills/$rigMember" "$rigTmp/home" "$rigTmp/inside" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"
rigWant="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
## A project command of the rig's own, named by its prepared index.
mkdir -p "$rigTmp/ws/source/rig/rig.project/sh-scripts" "$rigTmp/ws/.local" || exit 1
printf '#!/usr/bin/env bash\necho RIG-CUSTOM-RAN\n' > "$rigTmp/ws/source/rig/rig.project/sh-scripts/RigCustom.fn.sh"
chmod 755 "$rigTmp/ws/source/rig/rig.project/sh-scripts/RigCustom.fn.sh"
printf 'rig/rig.project RigCustom %s\n' "$rigTmp/ws/source/rig/rig.project/sh-scripts" > "$rigTmp/ws/.local/distro-commands.txt"
rigCustom="$rigTmp/ws/source/rig/rig.project/sh-scripts/RigCustom.fn.sh"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## A clean shell, the include sourced or not, printing what the name resolves to (`none` for nothing).
rigResolve(){ ## with|without|twice, the command name
	env -i PATH="$rigPath" MDLT_ORIGIN="$rigOrigin" MMDAPP="$rigTmp/ws" bash -c '
		[ "$1" = without ] || . "$3"
		[ "$1" != twice ] || . "$3"
		command -v "$2" 2> /dev/null || printf none' _ "$1" "$2" "$rigInclude" 2> /dev/null
}

echo "-- 1. the include puts the family's scripts on the path --"
rigAssert "a clean PATH does not resolve the name"   "$( rigResolve without DistroAgentsTools.fn.sh )" none
rigAssert "with the include, the name resolves"      "$( rigResolve with DistroAgentsTools.fn.sh )" "$rigWant"
rigAssert "the .local scripts stand before the agents'" "$( env -i PATH="$rigPath" MDLT_ORIGIN="$rigOrigin" MMDAPP="$rigTmp/ws" bash -c '. "$1" ; printf "%s" "$PATH"' _ "$rigInclude" 2> /dev/null \
	| LC_ALL=C awk -F: -v l="$rigOrigin/myx/myx.distro-.local/sh-scripts" -v a="$rigOrigin/myx/myx.distro-agents/sh-scripts" '{ for (i = 1 ; i <= NF ; i++) { if ($i == l && !pl) pl = i ; if ($i == a && !pa) pa = i } } END { print ( pl && pa && pl < pa ) ? "yes" : "no" }' )" yes
rigAssert "a project command of the prepared index resolves" "$( rigResolve with RigCustom.fn.sh )" "$rigCustom"
rigAssert "a second sourcing appends nothing"       "$( env -i PATH="$rigPath" MDLT_ORIGIN="$rigOrigin" MMDAPP="$rigTmp/ws" bash -c '. "$1" ; one="$PATH" ; . "$1" ; [ "$one" = "$PATH" ] && printf same || printf grew' _ "$rigInclude" 2> /dev/null )" same
## Read, not timed (the hot-path rule): a line of the include that substitutes a command, pipes, or tests a folder is a cost per call.
## A pipe between spaces is a pipeline; the bar of a case alternative (`a|b)`) is not one.
rigAssert "the include starts no process and tests no folder or file" "$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigInclude" | LC_ALL=C grep -c -e '\$(' -e '`' -e ' | ' -e '\[ -' -e '\[ ! -' -e '\[\[ ' )" 0
rigAssert "with no index, the include is quiet and the family resolves" "$( env -i PATH="$rigPath" MDLT_ORIGIN="$rigOrigin" MMDAPP="$rigTmp/no-such-ws" bash -c '. "$1" 2>&1 ; command -v DistroAgentsTools.fn.sh' _ "$rigInclude" )" "$rigWant"

echo "-- 2. execute resolves a command by name from a clean PATH --"
rigAssert "execute resolves the name"                "$( cd "$rigTmp/ws" && printf 'command -v DistroAgentsTools.fn.sh\n' | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" MDAT_WORKSPACE_MODE=just-agents \
	bash "$rigWant" --intern-mcp-execute 2> /dev/null | LC_ALL=C grep -F "/sh-scripts/DistroAgentsTools.fn.sh" | head -n 1 )" "$rigWant"
rigAssert "execute runs the project command by name" "$( cd "$rigTmp/ws" && printf 'RigCustom.fn.sh\n' | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" MDAT_WORKSPACE_MODE=just-agents \
	bash "$rigWant" --intern-mcp-execute 2> /dev/null | LC_ALL=C grep -c RIG-CUSTOM-RAN )" 1

echo "-- 3. the served Bash tool resolves a command by name --"
rigCall(){ ## argument object, call name
	( cd "$rigTmp/ws" && printf '%s' "$1" | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="rig-session" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 30 -- bash "$rigHarness" --intern-tool Bash --access-read-root "$rigTmp/inside" --access-write-root "$rigTmp/inside" ) \
		> "$rigTmp/$2.out" 2> "$rigTmp/$2.err" || :
}
rigCall "{\"command\":\"command -v DistroAgentsTools.fn.sh\",\"cwd\":\"$rigTmp/inside\",\"background\":false}" bash
rigAssert "the Bash tool resolves a command by name"  "$( LC_ALL=C grep -F "/sh-scripts/DistroAgentsTools.fn.sh" "$rigTmp/bash.out" | LC_ALL=C grep -c "DistroAgentsTools.fn.sh" )" 1
rigCall "{\"command\":\"RigCustom.fn.sh\",\"cwd\":\"$rigTmp/inside\",\"background\":false}" custom
rigAssert "the Bash tool runs the project command by name" "$( LC_ALL=C grep -c RIG-CUSTOM-RAN "$rigTmp/custom.out" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COMMAND PATH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a member's command call fails by name in one shell and works in another, so paths get rebuilt by hand" >&2
	echo "  fix:  the path include myx.distro-.local/sh-lib/console-.local-path.include and its readers: --intern-mcp-execute in sh-scripts/DistroAgentsTools.fn.sh, AgentsHarnessToolBashRun in sh-lib/harness/AgentsHarnessToolsBash.include" >&2
	exit 1
fi
echo "COMMAND_PATH: OK ($rigPassCount assertions, offline)"
