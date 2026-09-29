#!/usr/bin/env bash
## The Conclave panel, vscode/magic-team/: its manifest and its extension agree, and
## the view it renders is locked down. The always-on part needs no JavaScript runtime:
## package.json is read through the package's own JSON field reader, and extension.js
## by grep. The syntax check and a headless render through a stub `vscode` module run
## only when `node` is on PATH; without it the rig says so, and passes on the rest.
## It never runs VS Code itself. Temp tree only; no tooling op, no team data.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigPanel="$rigPackage/vscode/magic-team"
rigField="$rigPackage/sh-lib/AgentsHarnessJsonField.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigPanel/package.json" "$rigPanel/extension.js" "$rigPanel/instructions.md" "$rigField" ; do
	[ -f "$rigFile" ] || rigRefuse "missing: $rigFile"
done
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsVscodePanelCheck.XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
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
rigJson(){ ## key path -> the value in package.json, or <absent>/<unparsed>
	local jsonValue jsonRc=0
	jsonValue="$( LC_ALL=C awk -v path="$1" -v optional=1 -f "$rigField" < "$rigPanel/package.json" 2>/dev/null )" || jsonRc=$?
	case "$jsonRc" in
		0) printf '%s' "$jsonValue" ;;
		3) printf '<absent>' ;;
		*) printf '<unparsed>' ;;
	esac
}

echo "-- the manifest and the extension agree (always run) --"
rigAssert "package.json parses as one JSON object" "$( LC_ALL=C awk -v path=name -f "$rigField" < "$rigPanel/package.json" > /dev/null 2>&1 && printf yes || printf no )" yes
rigContainer="$( rigJson contributes.viewsContainers.activitybar.0.id )"
rigView="$( rigJson "contributes.views.$rigContainer.0.id" )"
rigAssert "one activity-bar container" "$( rigJson contributes.viewsContainers.activitybar.__count )" 1
rigAssert "its views are listed under that container's id" "$( rigJson "contributes.views.$rigContainer.__count" )" 1
rigAssert "the view is a webview" "$( rigJson "contributes.views.$rigContainer.0.type" )" webview
rigAssert "the view id is in the container's namespace" "$( case "$rigView" in ("$rigContainer".?*) printf yes ;; (*) printf "no: $rigView" ;; esac )" yes
rigExtensionView="$( LC_ALL=C sed -n "s/.*registerWebviewViewProvider('\([^']*\)'.*/\1/p" "$rigPanel/extension.js" )"
rigAssert "extension.js registers the manifest's view id" "$rigExtensionView" "$rigView"
rigAssert "the only activation is onView of that id" "$( rigJson activationEvents.__count ) $( rigJson activationEvents.0 )" "1 onView:$rigExtensionView"
rigAssert "main points at extension.js" "$( rigJson main )" ./extension.js
rigAssert "the icon is the organization codicon" "$( rigJson contributes.viewsContainers.activitybar.0.icon )" '$(organization)'

echo "-- the view is locked down (always run) --"
rigCsp="$( LC_ALL=C grep -o 'Content-Security-Policy" content="[^"]*"' "$rigPanel/extension.js" )"
rigAssert "one CSP in extension.js" "$( printf '%s\n' "$rigCsp" | LC_ALL=C grep -c . )" 1
rigAssert "the CSP defaults to none" "$( case "$rigCsp" in (*"default-src 'none'"*) printf yes ;; (*) printf no ;; esac )" yes
rigAssert "the CSP names no script source" "$( case "$rigCsp" in (*script-src*) printf present ;; (*) printf none ;; esac )" none
rigAssert "scripts are disabled in the webview options" "$( LC_ALL=C grep -c 'enableScripts: false' "$rigPanel/extension.js" ) $( LC_ALL=C grep -c 'enableScripts: true' "$rigPanel/extension.js" )" "1 0"

echo "-- syntax and a headless render (node only) --"
if ! command -v node > /dev/null 2>&1 ; then
	echo "        not run: no node on PATH -- syntax check and headless render skipped"
else
	rigAssert "extension.js passes node --check" "$( node --check "$rigPanel/extension.js" 2>&1 && printf ok )" ok

	## A tree shaped as the extension expects: the panel two levels below the skillset.
	## The identity file is a fixture with known text; the instructions are the real
	## ones, and a second copy carries a planted <script>.
	rigTree(){ ## name -> a fresh tree holding a full panel
		local treeDir="$rigTmp/$1"
		mkdir -p "$treeDir/vscode/magic-team" "$treeDir/skillset/magic-team/magic-team/resources"
		cp "$rigPanel/extension.js" "$rigPanel/instructions.md" "$treeDir/vscode/magic-team/"
		cp "$rigPackage/skillset/magic-team/magic-team/resources/the-conclave.mark.svg" "$treeDir/skillset/magic-team/magic-team/resources/"
		printf '# fixture\n\n## Public Information\n\n- **Description**: RIG-DESCRIPTION spread\n  over two lines.\n- **Name**: **RIG-NAME** is the name.\n\n## Other\n\n- **Name**: NOT-THIS\n' \
			> "$treeDir/skillset/magic-team/magic-team/magic-team.basic.md"
		printf '%s' "$treeDir/vscode/magic-team"
	}
	mkdir -p "$rigTmp/node_modules/vscode"
	cat > "$rigTmp/node_modules/vscode/index.js" <<'EOF'
let provider = null;
module.exports = {
  Uri: { file: (p) => ({ fsPath: p, toString: () => 'file://' + p }) },
  window: { registerWebviewViewProvider: (id, p) => { provider = { id, p }; return { dispose() {} }; } },
  rigProvider: () => provider,
};
EOF
	cat > "$rigTmp/render.js" <<'EOF'
const vscode = require('vscode');
const extension = require(process.argv[2]);
extension.activate({ extensionPath: process.argv[3], subscriptions: [] });
const webview = { cspSource: 'rig-csp-source', asWebviewUri: (u) => ({ toString: () => 'rig-webview:' + u.fsPath }) };
vscode.rigProvider().p.resolveWebviewView({ webview });
process.stdout.write(webview.html);
EOF
	rigRender(){ ## panel dir, output file
		env -i PATH="$PATH" NODE_PATH="$rigTmp/node_modules" HOME="$rigTmp" node "$rigTmp/render.js" "$1/extension.js" "$1" > "$2" 2> "$2.err"
	}
	rigFull="$( rigTree full )"
	rigRender "$rigFull" "$rigTmp/full.html" || rigRefuse "the render failed: $( head -3 "$rigTmp/full.html.err" )"
	rigAssert "the name is the Public Information one" "$( LC_ALL=C grep -c '<h1>RIG-NAME</h1>' "$rigTmp/full.html" )" 1
	rigAssert "the description is joined into one paragraph" "$( LC_ALL=C grep -c '<p>RIG-DESCRIPTION spread over two lines.</p>' "$rigTmp/full.html" )" 1
	rigAssert "the mark is an image through the webview URI" "$( LC_ALL=C grep -c 'src="rig-webview:.*the-conclave.mark.svg"' "$rigTmp/full.html" )" 1
	rigSections="$( LC_ALL=C grep -c '^#' "$rigPanel/instructions.md" )"
	rigAssert "instructions.md has five sections" "$rigSections" 5
	rigAssert "each of them is a heading in the view" "$( LC_ALL=C grep -c '^<h2>' "$rigTmp/full.html" )" "$rigSections"
	rigAssert "the rendered view holds no script" "$( LC_ALL=C grep -c -i '<script' "$rigTmp/full.html" )" 0

	rigPlanted="$( rigTree planted )"
	printf -- '- RIG-PLANT <script>alert(1)</script>\n' >> "$rigPlanted/instructions.md"
	rigRender "$rigPlanted" "$rigTmp/planted.html" || rigRefuse "the planted render failed: $( head -3 "$rigTmp/planted.html.err" )"
	rigAssert "a <script> in the instructions is shown escaped" "$( LC_ALL=C grep -c 'RIG-PLANT &lt;script&gt;alert(1)&lt;/script&gt;' "$rigTmp/planted.html" )" 1
	rigAssert "and is not a script" "$( LC_ALL=C grep -c -i '<script' "$rigTmp/planted.html" )" 0

	for rigMissing in skillset/magic-team/magic-team/resources/the-conclave.mark.svg skillset/magic-team/magic-team/magic-team.basic.md vscode/magic-team/instructions.md ; do
		rigCase="$( rigTree "missing-${rigMissing##*/}" )"
		rm -f "${rigCase%/vscode/magic-team}/$rigMissing"
		rigRender "$rigCase" "$rigTmp/case.html" || rigRefuse "the render without ${rigMissing##*/} failed: $( head -3 "$rigTmp/case.html.err" )"
		rigAssert "a missing ${rigMissing##*/} gives its could-not-be-read line" \
			"$( LC_ALL=C grep -c "<p class=\"missing\">.*/${rigMissing##*/} could not be read: ENOENT</p>" "$rigTmp/case.html" )" 1
	done

	## The installed layout: the five files flat in one folder, with no skillset above it.
	rigFlat="$rigTmp/flat/installed/magic-team-panel"
	mkdir -p "$rigFlat"
	cp "$rigPanel/package.json" "$rigPanel/extension.js" "$rigPanel/instructions.md" \
		"${rigFull%/vscode/magic-team}/skillset/magic-team/magic-team/magic-team.basic.md" \
		"${rigFull%/vscode/magic-team}/skillset/magic-team/magic-team/resources/the-conclave.mark.svg" "$rigFlat/" \
		|| rigRefuse "the flat copy could not be made"
	[ ! -e "$rigTmp/flat/skillset" ] || rigRefuse "the flat copy has a skillset above it, so it would not test the installed layout"
	rigRender "$rigFlat" "$rigTmp/flat.html" || rigRefuse "the flat render failed: $( head -3 "$rigTmp/flat.html.err" )"
	rigAssert "installed layout: the name is read from beside extension.js" "$( LC_ALL=C grep -c '<h1>RIG-NAME</h1>' "$rigTmp/flat.html" )" 1
	rigAssert "installed layout: the mark is the flat copy" "$( LC_ALL=C grep -c "src=\"rig-webview:$rigFlat/the-conclave.mark.svg\"" "$rigTmp/flat.html" )" 1
	rm -f "$rigFlat/the-conclave.mark.svg"
	rigRender "$rigFlat" "$rigTmp/flat-nomark.html" || rigRefuse "the flat render without its mark failed: $( head -3 "$rigTmp/flat-nomark.html.err" )"
	rigAssert "installed layout: a missing mark names the flat path" \
		"$( LC_ALL=C grep -c "<p class=\"missing\">$rigFlat/the-conclave.mark.svg could not be read: ENOENT</p>" "$rigTmp/flat-nomark.html" )" 1
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ VSCODE PANEL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'VSCODE_PANEL: OK (%d assertions%s)\n' "$rigPassCount" "$( command -v node > /dev/null 2>&1 || printf ', node part not run' )"
