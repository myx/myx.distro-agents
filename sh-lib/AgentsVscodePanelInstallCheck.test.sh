#!/usr/bin/env bash
## Behavioural check on the Magic-Team VS Code panel's delivery, and on the workspace
## generator it follows:
## - the generated .code-workspace never lists the workspace root (the tooling folders are
##   listed: the control), and its start.sh launches once with the workspace's own store,
##   user data and workspace file, from any directory;
## - --install-vscode-magic-team-panel writes one authoritative unpacked copy to the
##   workspace's .local/agents/vscode-magic-team-panel/ with no VS Code anywhere (a fake
##   `code` first on PATH), and links it into every listed folder as
##   <folder>/.vscode/extensions/magic-team-panel, each link resolving to that copy;
## - a re-run changes nothing; a changed team text rewrites the copy, same version, and the
##   links still resolve; real content in a slot is reported and left alone;
## - --install-vscode-integrations reaches it (one step below --make-workspace-integrations,
##   whose console step needs a live origin), regenerates a --workspace X through X's own
##   console, and links X's root .agents/skills, .claude/skills and .vscode/mcp.json, with the
##   panel, into every folder X lists, by the one link helper.
## What this cannot show: VS Code offering the panel. Only a real open shows that.
## Offline: the whole tree, TMPDIR included, under the workspace's own .local/temp, and a
## temp origin copy.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigHere="$rigOrigin/myx/myx.distro-agents/sh-lib"
rigGenerator="$rigOrigin/myx/myx.distro-source/sh-lib/SourceTools.Make.BuildCodeWorkspaceData.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigGenerator" ] || rigRefuse "the workspace generator is not at the origin: $rigGenerator"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsVscodePanelInstallCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## A private origin: this package copied, so its team text can change; the rest linked.
mkdir -p "$rigTmp/origin/myx"
for rigDir in "$rigOrigin"/myx/* ; do
	case "${rigDir##*/}" in
		myx.distro-agents) cp -R "$rigDir" "$rigTmp/origin/myx/" ;;
		*) ln -s "$rigDir" "$rigTmp/origin/myx/${rigDir##*/}" ;;
	esac
done
for rigDir in "$rigOrigin"/* ; do
	[ "${rigDir##*/}" = "myx" ] || ln -s "$rigDir" "$rigTmp/origin/${rigDir##*/}"
done
rigTool="$rigTmp/origin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigBasic="$rigTmp/origin/myx/myx.distro-agents/skillset/magic-team/magic-team/magic-team.basic.md"

mkdir -p "$rigTmp/bin" "$rigTmp/scenario" "$rigTmp/home" "$rigTmp/tmp"
cp "$rigHere/check-fixtures/vscode-panel-check.code.test.sh" "$rigTmp/bin/code" \
	|| rigRefuse "the fake code fixture is missing: $rigHere/check-fixtures/vscode-panel-check.code.test.sh"
chmod +x "$rigTmp/bin/code"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v code )" = "$rigTmp/bin/code" ] || rigRefuse "the fake code is not first on PATH"
export RIG_SCENARIO="$rigTmp/scenario"
: > "$rigTmp/scenario/code.log"

echo "-- the workspace generator --"
## The generator runs as the sourced body of a function; its namespace list comes from the
## workspace's source console, stubbed here to list one namespace.
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/source/rigns" "$rigWs/.local"
printf '#!/usr/bin/env bash\ncat > /dev/null\necho rigns\n' > "$rigWs/DistroSourceConsole.sh"
chmod +x "$rigWs/DistroSourceConsole.sh"
( MMDAPP="$rigWs" MDLT_ORIGIN="$rigTmp/origin" MDSC_CMD=rig TMPDIR="$rigTmp/tmp" ; rigGenerate(){ . "$rigGenerator" --quiet ; } ; rigGenerate ) > /dev/null 2> "$rigTmp/gen.err" || :
rigWsFile="$rigWs/${rigWs##*/}.code-workspace"
[ -f "$rigWsFile" ] || rigRefuse "the generator wrote no workspace file: $( head -3 "$rigTmp/gen.err" )"
rigFolders="$( LC_ALL=C awk -F '"' '$2 == "path" { sub( /\/$/, "", $4 ) ; print $4 ; }' "$rigWsFile" )"
rigAssert "the workspace root is never a listed folder"   "$( printf '%s\n' "$rigFolders" | LC_ALL=C grep -c -x -F "$rigWs" )" 0
rigAssert "control: the namespace and the two tooling folders are listed" \
	"$( printf '%s\n' "$rigFolders" | LC_ALL=C grep -c -x -F -e "$rigWs/source/rigns" -e "$rigWs/.local/.vscode/browse" -e "$rigWs/.local/.vscode/status" )" 3
[ -f "$rigWs/start.sh" ] || rigRefuse "the generator wrote no start.sh"
rigAssert "start.sh parses"                               "$( bash -n "$rigWs/start.sh" && echo parses || echo broken )" parses
rigLaunchCalls(){
	LC_ALL=C grep -c -F -- "--extensions-dir $rigWs/.vscode/extensions --user-data-dir $rigWs/.vscode/user-data $rigWs/${rigWs##*/}.code-workspace" "$rigTmp/scenario/code.log"
}
: > "$rigTmp/scenario/code.log"
( cd "$rigTmp" && TMPDIR="$rigTmp/tmp" bash "$rigWs/start.sh" ) > /dev/null 2>&1 || :
rigAssert "start.sh, run from elsewhere, launches once with the workspace's own store, data and file" "$( rigLaunchCalls )" 1
rigAssert "and makes no other code call"                  "$( LC_ALL=C awk 'END { print NR ; }' "$rigTmp/scenario/code.log" )" 1

rigHome="$rigWs/.local/agents/vscode-magic-team-panel"
rigRun(){
	rigRc=0
	: > "$rigTmp/scenario/code.log"
	env -u MDAT_DATA_ROOT HOME="$rigTmp/home" TMPDIR="$rigTmp/tmp" MMDAPP="$rigWs" MDLT_ORIGIN="$rigTmp/origin" \
		bash "$rigTool" --install-vscode-magic-team-panel "$rigWs" > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
## How many listed folders hold a link that resolves to the authoritative copy.
rigResolving(){
	local rigFolder rigCount=0
	while IFS= read -r rigFolder ; do
		[ -L "$rigFolder/.vscode/extensions/magic-team-panel" ] \
			&& [ "$( cd "$rigFolder/.vscode/extensions/magic-team-panel" && pwd -P )" = "$( cd "$rigHome" && pwd -P )" ] \
			&& rigCount=$(( rigCount + 1 ))
	done <<< "$rigFolders"
	echo "$rigCount"
}

echo "-- the panel: one authoritative copy, linked into every listed folder --"
rigRun
[ -d "$rigHome" ] || rigRefuse "no authoritative copy was written: $( grep -v SetInputSpec "$rigTmp/err" | grep -m1 ERROR )"
rigAssert "it runs, rc 0"                                 "$rigRc" 0
rigAssert "no code call was made"                         "$( LC_ALL=C awk 'END { print NR ; }' "$rigTmp/scenario/code.log" )" 0
rigAssert "the copy holds its payload"                    "$( ls -A "$rigHome" | LC_ALL=C sort | tr '\n' ' ' )" \
	".payload-sum extension.js instructions.md magic-team.basic.md package.json the-conclave.mark.svg "
rigAssert "the team text copy matches its source"         "$( cmp -s "$rigHome/magic-team.basic.md" "$rigBasic" && echo same || echo differs )" same
rigAssert "every listed folder links to it"               "$( rigResolving )" 3
rigAssert "no build sibling is left"                      "$( ls -A "$rigWs/.local/agents" | tr '\n' ' ' )" "vscode-magic-team-panel "

echo "-- a re-run changes nothing --"
: > "$rigHome/.rig-touch"
rigRun
rigAssert "it says unchanged"                             "$( LC_ALL=C grep -c 'panel unchanged' "$rigTmp/err" )" 1
rigAssert "the copy is the same one"                      "$( [ -f "$rigHome/.rig-touch" ] && echo kept || echo rewritten )" kept
rigAssert "no link is newly made"                         "$( LC_ALL=C grep -c '0 folder(s) newly linked, 3 already linked' "$rigTmp/err" )" 1
rm -f "$rigHome/.rig-touch"

echo "-- control: a changed team text rewrites the copy, same version --"
printf '\nrig change\n' >> "$rigBasic"
rigRun
rigAssert "it is rewritten"                               "$( LC_ALL=C grep -c 'panel written' "$rigTmp/err" )" 1
rigAssert "carrying the changed text"                     "$( LC_ALL=C grep -c 'rig change' "$rigHome/magic-team.basic.md" )" 1
rigAssert "and every link still resolves to it"           "$( rigResolving )" 3

echo "-- real content in a slot --"
rm -f "$rigWs/.local/.vscode/status/.vscode/extensions/magic-team-panel"
mkdir -p "$rigWs/.local/.vscode/status/.vscode/extensions/magic-team-panel"
: > "$rigWs/.local/.vscode/status/.vscode/extensions/magic-team-panel/rig-own.txt"
rigRun
rigAssert "it is warned about"                            "$( LC_ALL=C grep -c 'WARNING: .*real content at .*/status/.vscode/extensions/magic-team-panel, will not overwrite' "$rigTmp/err" )" 1
rigAssert "and the op still succeeds, rc 0"               "$rigRc" 0
rigAssert "the content is left alone"                     "$( [ -f "$rigWs/.local/.vscode/status/.vscode/extensions/magic-team-panel/rig-own.txt" ] && [ ! -L "$rigWs/.local/.vscode/status/.vscode/extensions/magic-team-panel" ] && echo alone || echo touched )" alone
rigAssert "the other folders keep their links"            "$( rigResolving )" 2

echo "-- --install-vscode-integrations reaches it --"
rigWs2="$rigTmp/ws2"
mkdir -p "$rigWs2/.local/myx/myx.distro-.local/sh-lib"
: > "$rigWs2/.local/myx/myx.distro-.local/sh-lib/LocalContext.include"
printf '{}\n' > "$rigTmp/home/.claude.json"
env -u MDAT_DATA_ROOT HOME="$rigTmp/home" TMPDIR="$rigTmp/tmp" MMDAPP="$rigWs2" MDLT_ORIGIN="$rigTmp/origin" \
	MYXROOT="$rigTmp/origin/myx/myx.common/os-myx.common/host/tarball/share/myx.common" \
	bash "$rigTool" --install-vscode-integrations --workspace "$rigWs2" > /dev/null 2>&1 || :
rigAssert "the integrations install wrote the authoritative copy" "$( [ -f "$rigWs2/.local/agents/vscode-magic-team-panel/package.json" ] && echo written || echo missing )" written

echo "-- --workspace X, not MMDAPP --"
## X's own console is the stub: asked to regenerate, it records the command and writes X's
## workspace file listing one tooling folder. MMDAPP holds a file that must stay untouched.
rigWsM="$rigTmp/wsM" rigWsX="$rigTmp/wsX"
mkdir -p "$rigWsM/.local" "$rigWsX/.local/myx/myx.distro-.local/sh-lib" "$rigWsX/.local/.vscode/browse"
: > "$rigWsX/.local/myx/myx.distro-.local/sh-lib/LocalContext.include"
printf 'rig-mmdapp-file\n' > "$rigWsM/${rigWsM##*/}.code-workspace"
cat > "$rigWsX/DistroSourceConsole.sh" <<'RIG_CONSOLE'
#!/usr/bin/env bash
rigHere="$( cd "$( dirname "$0" )" && pwd )"
rigCommand="$( cat )"
printf '%s\n' "$rigCommand" >> "$rigHere/console.log"
case "$rigCommand" in
	*--make-code-workspace*)
		printf '{ "folders": [ { "path": "%s/.local/.vscode/browse", "name": "rig" } ], "settings": { "chat.agentSkillsLocations": {} } }\n' "$rigHere" > "$rigHere/${rigHere##*/}.code-workspace"
	;;
esac
RIG_CONSOLE
chmod +x "$rigWsX/DistroSourceConsole.sh"
## MMDAPP carries the same console, so a regeneration sent to MMDAPP by mistake would
## write MMDAPP's file and show here, rather than failing silently for want of a console.
cp "$rigWsX/DistroSourceConsole.sh" "$rigWsM/DistroSourceConsole.sh"
## X's own authoritative root artefacts, which VS Code reads per folder.
mkdir -p "$rigWsX/.agents/skills" "$rigWsX/.claude/skills"
rigRunX(){
	env -u MDAT_DATA_ROOT HOME="$rigTmp/home" TMPDIR="$rigTmp/tmp" MMDAPP="$rigWsM" MDLT_ORIGIN="$rigTmp/origin" \
		MYXROOT="$rigTmp/origin/myx/myx.common/os-myx.common/host/tarball/share/myx.common" \
		bash "$rigTool" --install-vscode-integrations --workspace "$rigWsX" > /dev/null 2> "$rigTmp/x.err" || :
}
rigRunX
rigAssert "X's own console was asked to regenerate"       "$( LC_ALL=C grep -c -x -F 'DistroSourceTools --make-code-workspace --quiet' "$rigWsX/console.log" 2>/dev/null )" 1
rigAssert "X's workspace file is written"                 "$( [ -f "$rigWsX/${rigWsX##*/}.code-workspace" ] && echo written || echo missing )" written
rigAssert "MMDAPP's workspace file is untouched"          "$( cat "$rigWsM/${rigWsM##*/}.code-workspace" )" rig-mmdapp-file
rigAssert "and MMDAPP's console was never asked"          "$( [ -f "$rigWsM/console.log" ] && echo asked || echo never )" never
rigAssert "X's listed folder is linked"                   "$( [ -L "$rigWsX/.local/.vscode/browse/.vscode/extensions/magic-team-panel" ] && echo linked || echo missing )" linked
rigAssert "and MMDAPP got no panel"                       "$( [ -e "$rigWsM/.local/agents/vscode-magic-team-panel" ] && echo present || echo none )" none

echo "-- every root artefact VS Code reads per folder reaches X's listed folder --"
rigXFolder="$rigWsX/.local/.vscode/browse"
rigLinksTo(){ ## slot, authoritative path -> resolves|other
	[ -L "$rigXFolder/$1" ] && [ "$( cd "$( dirname "$rigXFolder/$1" )" && cd "$( dirname "$( readlink "$rigXFolder/$1" )" )" 2>/dev/null && pwd -P )/$( basename "$( readlink "$rigXFolder/$1" )" )" = "$( cd "$( dirname "$2" )" && pwd -P )/$( basename "$2" )" ] && echo resolves || echo other
}
rigAssert ".agents/skills links to X's root copy"          "$( rigLinksTo .agents/skills "$rigWsX/.agents/skills" )" resolves
rigAssert ".claude/skills links to X's root copy"          "$( rigLinksTo .claude/skills "$rigWsX/.claude/skills" )" resolves
rigAssert ".vscode/mcp.json links to X's root copy"        "$( rigLinksTo .vscode/mcp.json "$rigWsX/.vscode/mcp.json" )" resolves
rigAssert "the panel links to X's authoritative copy"      "$( rigLinksTo .vscode/extensions/magic-team-panel "$rigWsX/.local/agents/vscode-magic-team-panel" )" resolves
rigRunX
rigAssert "a re-run links nothing new"                     "$( LC_ALL=C grep -c 'newly linked' "$rigTmp/x.err" ) $( LC_ALL=C grep -c ': 0 folder(s) newly linked, 1 already linked' "$rigTmp/x.err" )" "4 4"
rm -f "$rigXFolder/.claude/skills" ; mkdir -p "$rigXFolder/.claude/skills" ; : > "$rigXFolder/.claude/skills/rig-own"
rigRunX
rigAssert "control: real content in a slot is reported"    "$( LC_ALL=C grep -c 'real content at .*/browse/.claude/skills, will not overwrite' "$rigTmp/x.err" )" 1
rigAssert "and left alone"                                 "$( [ -f "$rigXFolder/.claude/skills/rig-own" ] && [ ! -L "$rigXFolder/.claude/skills" ] && echo alone || echo touched )" alone

echo "-- a slot already reaching X's root copy is kept --"
rm -rf "$rigXFolder/.claude" "$rigXFolder/.vscode"
ln -s ../../../.claude "$rigXFolder/.claude" ; ln -s ../../../.vscode "$rigXFolder/.vscode"
rigRunX
rigAssert "a dir and a file slot through a parent link: no refusal" "$( LC_ALL=C grep -e 'ERROR' -e 'WARNING' "$rigTmp/x.err" | LC_ALL=C grep -c -e 'browse/.claude/skills' -e 'browse/.vscode/mcp.json' )" 0
rigAssert "both count as already linked"                   "$( LC_ALL=C grep -c -e '.claude/skills: 0 folder(s) newly linked, 1 already linked' -e '.vscode/mcp.json: 0 folder(s) newly linked, 1 already linked' "$rigTmp/x.err" )" 2
rigAssert "the parent links are left as they were"         "$( readlink "$rigXFolder/.claude" ) $( readlink "$rigXFolder/.vscode" )" "../../../.claude ../../../.vscode"
rm -f "$rigXFolder/.claude" ; mkdir -p "$rigXFolder/.claude" ; ln -s ../../../../.claude/skills "$rigXFolder/.claude/skills"
rigRunX
rigAssert "a differently spelled link to it: no refusal"   "$( LC_ALL=C grep -e 'ERROR' -e 'WARNING' "$rigTmp/x.err" | LC_ALL=C grep -c 'browse/.claude/skills' )" 0
rigAssert "and it is kept as spelled"                      "$( readlink "$rigXFolder/.claude/skills" )" ../../../../.claude/skills

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ VSCODE PANEL INSTALL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'VSCODE_PANEL_INSTALL: OK (%d assertions, offline; VS Code offering the panel is shown only by a real open)\n' "$rigPassCount"
