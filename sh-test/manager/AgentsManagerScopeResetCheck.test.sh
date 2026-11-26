#!/usr/bin/env bash
## Behavioural check on `--manager-scope-reset` and the screen binding that asks it (S7, the console floors of the
## refactorings epic, 14.7 `Settings` and `Scope Settings`: "can clear/reset/delete ... whole subsection"). Gap 6 of
## `inquiry-20261124T0530Z-console-floor-gaps`.
## Held: a scope whose keys all declare a default is reset by the one operation, so each reads that default again, and
## every other line of its file and the other scopes stay; a declaration is a `settings-rows.list` row of an installed
## package or a `settings` line of the agents console's digest, and never a line of the configuration; a scope holding
## any key that no declaration gives a default is refused whole, and no key is taken out; Clear and Delete still stand beside it; the screen binds `R` to the reset
## on a scope, as it binds `c` to Clear and `D` to Delete.
## Red before the change: `--manager-scope-reset` is not an operation of the tool, and no part declares the binding.
## Offline: only the rig's own tree is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigScopeParts="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-.local/sh-lib/manager/LocalManagerScreen.Scopes.py"
rigScopeImpl="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-.local/sh-lib/manager/LocalTools.ManagerScope.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigScopeParts" ] || rigRefuse "the Scope Settings part is not at the origin this workspace resolves: $rigScopeParts"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScopeResetCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
rigUser="$( id -un )" || rigRefuse "the name of the user who runs this check cannot be read"
mkdir -p "$rigWs/.local/home/$rigUser" "$rigWs/.local/.agents" "$rigHome" "$rigSkills"

## Two keys of the running user's own settings declare a default in `.local`'s `settings-rows.list` (`MDLT_MANAGER_STYLE`,
## `MDLT_MANAGER_MOUSE`), so a reset takes both back to it. The workspace's own settings hold one declared key and one no
## declaration carries, so a reset of that scope is refused whole.
rigOwn="$rigWs/.local/home/$rigUser/MDLT.settings.env"
rigShared="$rigWs/.local/MDLT.settings.env"
printf '# a note of the owner\nMDLT_MANAGER_STYLE=nu-system\nMDLT_MANAGER_MOUSE=disable\n' > "$rigOwn"
printf 'MDLT_MANAGER_SPACERS=disable\nWAIT_ROUND_SECONDS=5\n' > "$rigShared"

rigRc=0
rigRun(){ ## tool arguments...
	rigRc=0
	( cd "$rigWs" && printf '%s' "${rigIn:-}" | env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigKeys(){ ## file -- the names of the keys it holds, parted by a comma
	LC_ALL=C awk 'index( $0, "=" ) > 1 { name = substr( $0, 1, index( $0, "=" ) - 1 ) ; if ( name ~ /^[A-Za-z_][A-Za-z0-9_]*$/ ) printf "%s%s", ( seen++ ? "," : "" ), name ; }' "$1"
}

echo "== the operation is the tool's"
rigRun --help-syntax
rigAssert "the tool lists --manager-scope-reset" \
	"$( LC_ALL=C grep -c -F -- '--manager-scope-reset' "$rigTmp/err" )" "1"

echo "== a scope whose keys all declare a default is reset"
rigIn="" ; rigRun --manager-scope-reset "common:user-$rigUser"
rigAssert "the reset ends 0" "$rigRc" "0"
rigAssert "its row says reset, of both keys" "$( LC_ALL=C sed -n 's/^reset\t//p' "$rigTmp/out" | LC_ALL=C tr '\t' ' ' )" "common:user-$rigUser 2"
rigAssert "the two declared keys are gone from the file" "$( rigKeys "$rigOwn" )" ""
rigAssert "the comment of the file stays" "$( LC_ALL=C grep -c -F -- '# a note of the owner' "$rigOwn" )" "1"
rigAssert "the file itself stays" "$( [ -f "$rigOwn" ] && echo there || echo absent )" "there"
rigAssert "the other scope's file is not touched" "$( rigKeys "$rigShared" )" "MDLT_MANAGER_SPACERS,WAIT_ROUND_SECONDS"

echo "== a key a reset took out reads its declared default again"
rigIn="" ; rigRun --manager-config-digest --full interface
rigAssert "the style's value is the declared default, and where it comes from says default" \
	"$( LC_ALL=C awk -F'\t' '$1 == "line" && $4 == "MDLT_MANAGER_STYLE" { print $6 ":" $12 }' "$rigTmp/out" )" "tv-system:default"
rigAssert "the reset scope lists no key at all now" "$( LC_ALL=C awk -F'\t' '$1 == "key" { print $2 }' "$rigTmp/out" | LC_ALL=C grep -c -F -- 'MDLT_MANAGER_STYLE' )" "0"

echo "== a scope holding a key that no declaration gives a default is refused whole, and no key is taken out"
rigBefore="$( cksum < "$rigShared" )"
rigIn="" ; rigRun --manager-scope-reset common:workspace
rigAssert "the refusal ends non-zero" "$( [ "$rigRc" -ne 0 ] && echo refused || echo allowed )" "refused"
rigAssert "it names that key alone, and not the declared one beside it" \
	"$( LC_ALL=C sed -n 's/.*holds \([A-Za-z0-9_,]*\) and no declaration gives.*/\1/p' "$rigTmp/err" )" "WAIT_ROUND_SECONDS"
rigAssert "no key was taken out of that scope" "$( cksum < "$rigShared" )" "$rigBefore"

echo "== a scope holding a key only the agents console declares is reset too"
rigAgentScope="$rigWs/.local/.agents/probe.agent.env"
printf 'MDLT_CONSOLE_DETAIL=full\n' > "$rigAgentScope"
rigIn="" ; rigRun --manager-scope-reset agents:probe
rigAssert "the reset of an agents scope ends 0" "$rigRc" "0"
rigAssert "its row says reset, of that key" "$( LC_ALL=C sed -n 's/^reset\t//p' "$rigTmp/out" | LC_ALL=C tr '\t' ' ' )" "agents:probe 1"
rigAssert "the agents-declared key is gone from the file" "$( rigKeys "$rigAgentScope" )" ""

echo "== a scope holding a line of the configuration is refused whole, and no key is taken out"
## `MDAT_WORKSPACE_MODE` is a line of the configuration, deployed by the installer of the workspace: its own default is
## `just-agents`, and a reset that took it out would quietly turn a team rig into a workspace of just agents.
rigConfigScope="$rigWs/.local/.agents/mode.agent.env"
printf 'MDAT_WORKSPACE_MODE=team-rig\n' > "$rigConfigScope"
rigBefore="$( cksum < "$rigConfigScope" )"
rigIn="" ; rigRun --manager-scope-reset agents:mode
rigAssert "the refusal ends non-zero" "$( [ "$rigRc" -ne 0 ] && echo refused || echo allowed )" "refused"
rigAssert "it names that line of the configuration" \
	"$( LC_ALL=C sed -n 's/.*holds \([A-Za-z0-9_,]*\) and no declaration gives.*/\1/p' "$rigTmp/err" )" "MDAT_WORKSPACE_MODE"
rigAssert "no key was taken out of that scope" "$( cksum < "$rigConfigScope" )" "$rigBefore"

echo "== a row is read by the form its own file names, and a trailing empty field is a field"
## `settings-rows.list` names its form on a line beginning `## Form:`, which gives the fields and their order. A row is a
## declaration when it splits into exactly that many fields under awk, and the field the form calls `key` is not empty.
## A row whose `takes` field is empty ends in a pipe and still counts its seven fields. A row of another count declares
## nothing, and the reader names its file and line. The sixth field is the declared default and it may be empty.
rigDeclareOrigin="$rigTmp/declarations"
rigDeclareFile="$rigDeclareOrigin/myx/myx.distro-probe/sh-lib/config/settings-rows.list"
mkdir -p "${rigDeclareFile%/*}"
printf '%s\n' MDLT_MANAGER_STYLE MDLT_MANAGER_MOUSE > "$rigTmp/declarations.keys"
rigUndeclared(){ ## origin -- the probe's keys that no package declares, one a line
	MDSC_CMD=probe MDLT_ORIGIN="$1" bash -c '
		set +u
		inc="$1" ; keys="$2"
		set --
		. "$inc" > /dev/null 2>&1
		type -t LocalToolsManagerScopeUndeclaredKeys > /dev/null || { printf "NO-READER\n" ; exit 0 ; }
		LocalToolsManagerScopeUndeclaredKeys < "$keys"
	' _ "$rigScopeImpl" "$rigTmp/declarations.keys"
}

## the control: two rows of the seven fields its own form names, the second ending in its empty `takes`
printf '%s\n' \
	'## Form: subject|group|key|kind|places|default|takes.' \
	'interface|style|MDLT_MANAGER_STYLE|choice|user system|tv-system|nu-system=a' \
	'interface|mouse|MDLT_MANAGER_MOUSE|choice|user system||' \
	> "$rigDeclareFile"
rigAssert "both rows of the form's own count declare their key" \
	"$( rigUndeclared "$rigDeclareOrigin" 2> "$rigTmp/decl.warn" | LC_ALL=C tr '\n' ' ' )" ""
rigAssert "and nothing is warned about them" "$( LC_ALL=C grep -c -F -- 'WARNING:' "$rigTmp/decl.warn" )" "0"

## a row of seven fields whose sixth, the declared default, is empty: the empty default is a default
printf '%s\n' \
	'## Form: subject|group|key|kind|places|default|takes.' \
	'interface|mouse|MDLT_MANAGER_MOUSE|choice|user system||=Enabled,disable=Disabled' \
	> "$rigDeclareFile"
rigAssert "a row whose declared default is empty still declares its key" \
	"$( rigUndeclared "$rigDeclareOrigin" 2> "$rigTmp/decl.warn" | LC_ALL=C tr '\n' ' ' )" "MDLT_MANAGER_STYLE "

## the row written without its last two fields: five fields where the form names seven
printf '%s\n' \
	'## Form: subject|group|key|kind|places|default|takes.' \
	'interface|style|MDLT_MANAGER_STYLE|choice|user system|tv-system|nu-system=a' \
	'interface|mouse|MDLT_MANAGER_MOUSE|choice|user system' \
	> "$rigDeclareFile"
rigAssert "a row of five fields under a form of seven declares nothing, so its key is undeclared" \
	"$( rigUndeclared "$rigDeclareOrigin" 2> "$rigTmp/decl.warn" | LC_ALL=C tr '\n' ' ' )" "MDLT_MANAGER_MOUSE "
rigAssert "the warning names that row's file and line" \
	"$( LC_ALL=C sed -n 's/.*WARNING: \(.*\): the row has.*/\1/p' "$rigTmp/decl.warn" )" "$rigDeclareFile:3"
rigAssert "the warning gives both counts" \
	"$( LC_ALL=C sed -n 's/.*the row has \([0-9]*\) fields and the form names \([0-9]*\).*/\1 of \2/p' "$rigTmp/decl.warn" )" "5 of 7"

## the row written without its last field but with a default: six fields, no trailing pipe. That is the shape a writer
## makes when it leaves out `takes` rather than writing it empty, and the count is what tells the two apart.
printf '%s\n' \
	'## Form: subject|group|key|kind|places|default|takes.' \
	'interface|style|MDLT_MANAGER_STYLE|choice|user system|tv-system|nu-system=a' \
	'interface|mouse|MDLT_MANAGER_MOUSE|choice|user system|disable' \
	> "$rigDeclareFile"
rigAssert "a row of six fields with no trailing pipe declares nothing" \
	"$( rigUndeclared "$rigDeclareOrigin" 2> "$rigTmp/decl.warn" | LC_ALL=C tr '\n' ' ' )" "MDLT_MANAGER_MOUSE "
rigAssert "and the six it carries against seven is what the warning says" \
	"$( LC_ALL=C sed -n 's/.*the row has \([0-9]*\) fields and the form names \([0-9]*\).*/\1 of \2/p' "$rigTmp/decl.warn" )" "6 of 7"

## the same row, once the file's own form names six fields: the reader follows the file, and no code changes
printf '%s\n' \
	'## Form: subject|group|key|kind|places|default.' \
	'interface|style|MDLT_MANAGER_STYLE|choice|user system|tv-system' \
	'interface|mouse|MDLT_MANAGER_MOUSE|choice|user system|' \
	> "$rigDeclareFile"
rigAssert "a form of six fields makes a six-field row a declaration" \
	"$( rigUndeclared "$rigDeclareOrigin" 2> "$rigTmp/decl.warn" | LC_ALL=C tr '\n' ' ' )" ""

## the key is the field the form calls `key`, not the third field
printf '%s\n' \
	'## Form: subject|key|group|kind|places|default|takes.' \
	'interface|MDLT_MANAGER_STYLE|style|choice|user system|tv-system|nu-system=a' \
	'interface|MDLT_MANAGER_MOUSE|mouse|choice|user system||' \
	> "$rigDeclareFile"
rigAssert "the key is read from the field the form names, in its own order" \
	"$( rigUndeclared "$rigDeclareOrigin" 2> "$rigTmp/decl.warn" | LC_ALL=C tr '\n' ' ' )" ""

## a second comment line carrying `Form:` without the anchor must not replace the count
printf '%s\n' \
	'## Form: subject|group|key|kind|places|default|takes.' \
	'## A note: Form: subject|group|key.' \
	'interface|style|MDLT_MANAGER_STYLE|choice|user system|tv-system|nu-system=a' \
	> "$rigDeclareFile"
rigAssert "an unanchored form line later in the file changes nothing" \
	"$( rigUndeclared "$rigDeclareOrigin" 2> "$rigTmp/decl.warn" | LC_ALL=C tr '\n' ' ' )" "MDLT_MANAGER_MOUSE "

## a file that names no form at all declares nothing, and says so once for the file, not once for each of its rows
printf '%s\n' \
	'interface|style|MDLT_MANAGER_STYLE|choice|user system|tv-system|nu-system=a' \
	'interface|mouse|MDLT_MANAGER_MOUSE|choice|user system||' \
	'interface|spacer|MDLT_MANAGER_SPACERS|flag|||' \
	> "$rigDeclareFile"
rigAssert "a file with no form line declares nothing, and its keys are named" \
	"$( rigUndeclared "$rigDeclareOrigin" 2> "$rigTmp/decl.warn" | LC_ALL=C tr '\n' ' ' )" "MDLT_MANAGER_STYLE MDLT_MANAGER_MOUSE "
rigAssert "and one line says so for the file, though it holds three rows" \
	"$( LC_ALL=C grep -c -F -- 'the file names no form line' "$rigTmp/decl.warn" )" "1"
rigAssert "and that line names the file, and no row of it" \
	"$( LC_ALL=C sed -n 's/.*WARNING: \(.*\): the file names no form line.*/\1/p' "$rigTmp/decl.warn" )" "$rigDeclareFile"

echo "== both list files of the real package carry their form on the anchor"
## One rule covers both files only when each names its form the same way. The labels file's line moves to the anchor as
## part of this change, and no reader parses its form today, so the move costs nothing.
rigRowsList="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-.local/sh-lib/config/settings-rows.list"
rigLabelsList="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-.local/sh-lib/config/settings-labels.list"
rigAssert "the rows list names its form on the anchor, seven fields" \
	"$( LC_ALL=C sed -n 's/^## Form: \(.*\)\.$/\1/p' "$rigRowsList" )" "subject|group|key|kind|places|default|takes"
rigAssert "the labels list names its form on the anchor, six fields" \
	"$( LC_ALL=C sed -n 's/^## Form: \(.*\)\.$/\1/p' "$rigLabelsList" )" "subject|group|key|label|belongs|description"
rigAssert "only one line of each file carries the anchor" \
	"$( LC_ALL=C grep -c '^## Form:' "$rigRowsList" )$( LC_ALL=C grep -c '^## Form:' "$rigLabelsList" )" "11"

echo "== Clear and Delete stand beside it"
rigIn="" ; rigRun --manager-scope-clear "common:user-$rigUser"
rigAssert "clear still ends 0 on the scope it just reset" "$rigRc" "0"
rigAssert "clear's row says cleared, of no key left" "$( LC_ALL=C sed -n 's/^cleared\t//p' "$rigTmp/out" | LC_ALL=C tr '\t' ' ' )" "common:user-$rigUser 0"
rigIn="" ; rigRun --manager-scope-delete "common:user-$rigUser"
rigAssert "delete still refuses the user's own scope" "$( [ "$rigRc" -ne 0 ] && echo refused || echo allowed )" "refused"

echo "== the screen asks it on a scope, on R"
rigAssert "the part declares the reset call" "$( LC_ALL=C grep -c -F -- 'CALLS["scope-reset"]' "$rigScopeParts" )" "1"
rigAssert "a command carries the R key for it" "$( LC_ALL=C grep -c -F -- '"keys": ("R",)' "$rigScopeParts" )" "1"
rigAssert "the command it names is the reset" "$( LC_ALL=C grep -c -F -- '"calls": ("scope-reset",)' "$rigScopeParts" )" "1"
rigAssert "its answer is read as a change the operation printed" "$( LC_ALL=C grep -c -F -- '"reset", "deleted"' "$rigScopeParts" )" "1"

printf '\n%d passed, %d failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
