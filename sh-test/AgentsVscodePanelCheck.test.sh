#!/usr/bin/env bash
## The Conclave panel, vscode/magic-team/: its manifest and its extension agree, the
## view it renders is locked down, and a click on a task button starts that task. The
## always-on part needs no JavaScript runtime: package.json is read through the package's
## own JSON field reader, and extension.js by grep. The syntax check, a headless render
## and the clicks, through a stub `vscode` module, run only when `node` is on PATH;
## without it the rig says so, and passes on the rest. A click takes the road VS Code
## gives it: the button's command link, the view's own enableCommandUris, the registered
## command. It never runs VS Code itself. Temp tree only; no tooling op, no team data.
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
rigAssert "the one command a link in the view may run is the task runner" "$( LC_ALL=C grep -c 'enableCommandUris: \[RUN_TASK_COMMAND\]' "$rigPanel/extension.js" ) $( LC_ALL=C grep -c 'enableCommandUris: true' "$rigPanel/extension.js" )" "1 0"
rigAssert "and it is the command every button links to" "$( LC_ALL=C grep -c 'href="command:${RUN_TASK_COMMAND}?' "$rigPanel/extension.js" ) $( LC_ALL=C grep -c 'href="command:' "$rigPanel/extension.js" )" "1 1"

echo "-- syntax and a headless render (node only) --"
if ! command -v node > /dev/null 2>&1 ; then
	echo "        not run: no node on PATH -- syntax check, headless render and clicks skipped"
else
	rigAssert "extension.js passes node --check" "$( node --check "$rigPanel/extension.js" 2>&1 && printf ok )" ok

	## A tree shaped as the extension expects: the panel two levels below the skillset.
	## The identity file is a fixture with known text; the instructions are the real
	## ones, and a second copy carries a planted heading and a planted <script>.
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
let registeredCommands = {};
let executedTasks = [];
let returnedExecutions = [];
let startListeners = [];
let endListeners = [];
const RIG_TASKS = [
  { name: '🤖 Start Agents Console...', source: 'Workspace' },
  { name: '📦 Update Local Tools', source: 'Workspace' },
  { name: 'rig-other-provider-task', source: 'npm' },
];
const rigNext = { tasks: RIG_TASKS, fetchFailure: '', refusal: '', execution: null };
module.exports = {
  Uri: { file: (p) => ({ fsPath: p, toString: () => 'file://' + p }) },
  window: { registerWebviewViewProvider: (id, p) => { provider = { id, p }; return { dispose() {} }; } },
  commands: { registerCommand: (id, fn) => { registeredCommands[id] = fn; return { dispose() {} }; } },
  tasks: {
    taskExecutions: [],
    fetchTasks: async () => {
      if (rigNext.fetchFailure) {
        throw new Error(rigNext.fetchFailure);
      }
      return rigNext.tasks;
    },
    executeTask: async (task) => {
      executedTasks.push(task);
      if (rigNext.refusal) {
        throw new Error(rigNext.refusal);
      }
      returnedExecutions.push(rigNext.execution || { task });
      return returnedExecutions[returnedExecutions.length - 1];
    },
    onDidStartTask: (listener) => { startListeners.push(listener); return { dispose() {} }; },
    onDidEndTask: (listener) => { endListeners.push(listener); return { dispose() {} }; },
  },
  rigProvider: () => provider,
  rigCommands: () => registeredCommands,
  rigExecutedTasks: () => executedTasks,
  rigTasks: RIG_TASKS,
  rigNext,
  rigExecutions: () => returnedExecutions,
  rigStart: (execution) => startListeners.forEach((listener) => listener({ execution })),
  rigEnd: (execution) => endListeners.forEach((listener) => listener({ execution })),
};
EOF
	cat > "$rigTmp/render.js" <<'EOF'
const vscode = require('vscode');
const extension = require(process.argv[2]);
extension.activate({ extensionPath: process.argv[3], subscriptions: [] });
const webview = { cspSource: 'rig-csp-source', asWebviewUri: (u) => ({ toString: () => 'rig-webview:' + u.fsPath }) };
(async () => {
  await vscode.rigProvider().p.resolveWebviewView({ webview, onDidDispose: () => ({ dispose() {} }) });
  process.stdout.write(webview.html);
})();
EOF
	## One click on the Update Local Tools button, in the scenario named, and what was seen
	## of it, one `key=value` a line. The click goes as VS Code sends it: the link the view
	## shows for that task now, refused unless the view's enableCommandUris lets its command
	## run, then the registered command with the link's own arguments. The timer the
	## extension arms is held here, and fires only when the scenario says so.
	cat > "$rigTmp/click.js" <<'EOF'
const vscode = require('vscode');
const extension = require(process.argv[2]);
const rigScenario = process.argv[4];
const rigName = '📦 Update Local Tools';
const rigTimers = [];
globalThis.setTimeout = (callback) => rigTimers.push(callback);
globalThis.clearTimeout = () => {};
if (rigScenario === 'running') {
  vscode.rigNext.execution = { task: vscode.rigTasks[1] };
  vscode.tasks.taskExecutions.push(vscode.rigNext.execution);
}
extension.activate({ extensionPath: process.argv[3], subscriptions: [] });
const webview = { cspSource: 'rig-csp-source', asWebviewUri: (u) => ({ toString: () => 'rig-webview:' + u.fsPath }) };
const rigItem = (taskName) => webview.html.split('\n').find((htmlLine) => htmlLine.startsWith('<li><') && htmlLine.includes(`${taskName}</`)) || '';
const rigState = (taskName) => (rigItem(taskName).startsWith('<li><a class="task" href="command:') ? 'link' : rigItem(taskName).startsWith('<li><span class="task starting">') ? 'starting' : 'none');
const rigProblem = () => (webview.html.match(/<\/ul>\n<p class="missing">(.*)<\/p>/) || ['', 'none'])[1];
const rigSettle = () => new Promise((resolve) => setImmediate(resolve));
let rigCommand = null;
const rigClick = (taskName) => {
  const linkMatch = rigItem(taskName).match(/^<li><a class="task" href="command:([^?"]*)\?([^"]*)">/);
  if (!linkMatch) {
    return 'no-link';
  }
  const allowedCommands = webview.options.enableCommandUris;
  if (allowedCommands !== true && !(Array.isArray(allowedCommands) && allowedCommands.includes(linkMatch[1]))) {
    return 'dropped';
  }
  rigCommand = () => vscode.rigCommands()[linkMatch[1]](...JSON.parse(decodeURIComponent(linkMatch[2])));
  return rigCommand();
};
(async () => {
  await vscode.rigProvider().p.resolveWebviewView({ webview, onDidDispose: () => ({ dispose() {} }) });
  vscode.rigNext.tasks = rigScenario === 'gone' ? [] : vscode.rigTasks;
  vscode.rigNext.fetchFailure = rigScenario === 'unreadable' ? 'rig-fetch-failure' : '';
  vscode.rigNext.refusal = rigScenario === 'refused' ? 'rig-refusal' : '';
  const rigSeen = [];
  const rigRun = rigClick(rigName);
  await rigSettle();
  rigSeen.push(`click=${typeof rigRun === 'string' ? rigRun : rigState(rigName)}`);
  rigSeen.push(`other=${rigState('🤖 Start Agents Console...')}`);
  rigSeen.push(`ran=${JSON.stringify(vscode.rigExecutedTasks().map((executedTask) => executedTask.name))}`);
  rigSeen.push(`ran-fetched=${vscode.rigExecutedTasks()[0] === vscode.rigTasks[1] ? 'yes' : 'no'}`);
  rigSeen.push(`timers=${rigTimers.length}`);
  if (rigScenario === 'start') {
    const rigAgain = rigClick(rigName);
    if (rigCommand) {
      rigCommand();
    }
    await rigSettle();
    rigSeen.push(`again=${typeof rigAgain === 'string' ? rigAgain : 'taken'}`);
    rigSeen.push(`ran-after-again=${vscode.rigExecutedTasks().length}`);
    vscode.rigStart(vscode.rigExecutions()[0]);
  }
  if (rigScenario === 'ended') {
    vscode.rigEnd(vscode.rigExecutions()[0]);
  }
  if (rigScenario === 'silent') {
    rigTimers.forEach((callback) => callback());
  }
  rigSeen.push(`released=${await Promise.race([Promise.resolve(rigRun).then(() => 'yes'), rigSettle().then(rigSettle).then(() => 'no')])}`);
  rigSeen.push(`after=${rigState(rigName)}`);
  rigSeen.push(`problem=${rigProblem()}`);
  if (rigScenario === 'refused') {
    vscode.rigNext.refusal = '';
    rigClick(rigName);
    await rigSettle();
    rigSeen.push(`next=${rigState(rigName)}`);
    rigSeen.push(`next-problem=${rigProblem()}`);
  }
  process.stdout.write(`${rigSeen.join('\n')}\n`);
})();
EOF
	rigRender(){ ## panel dir, output file
		env -i PATH="$PATH" NODE_PATH="$rigTmp/node_modules" HOME="$rigTmp" node "$rigTmp/render.js" "$1/extension.js" "$1" > "$2" 2> "$2.err"
	}
	rigClick(){ ## panel dir, scenario
		env -i PATH="$PATH" NODE_PATH="$rigTmp/node_modules" HOME="$rigTmp" node "$rigTmp/click.js" "$1/extension.js" "$1" "$2" > "$rigTmp/click-$2.out" 2> "$rigTmp/click-$2.out.err"
	}
	rigSeen(){ ## scenario, key... -> what its click saw under each key, on one line
		local seenScenario="$1" seenKey seenLine=""
		shift
		for seenKey in "$@" ; do
			seenLine="$seenLine${seenLine:+ }$( LC_ALL=C sed -n "s/^$seenKey=//p" "$rigTmp/click-$seenScenario.out" )"
		done
		printf '%s' "$seenLine"
	}
	rigFull="$( rigTree full )"
	rigRender "$rigFull" "$rigTmp/full.html" || rigRefuse "the render failed: $( head -3 "$rigTmp/full.html.err" )"
	rigAssert "the name is the Public Information one" "$( LC_ALL=C grep -c '<h1>RIG-NAME</h1>' "$rigTmp/full.html" )" 1
	rigAssert "the description is joined into one paragraph" "$( LC_ALL=C grep -c '<p>RIG-DESCRIPTION spread over two lines.</p>' "$rigTmp/full.html" )" 1
	rigAssert "the mark is an image through the webview URI" "$( LC_ALL=C grep -c 'src="rig-webview:.*the-conclave.mark.svg"' "$rigTmp/full.html" )" 1
	rigItems="$( LC_ALL=C grep -c '^- ' "$rigPanel/instructions.md" )"
	rigAssert "instructions.md is a list, with no heading" "$( [ "$rigItems" -gt 0 ] && printf items || printf none ) $( LC_ALL=C grep -c '^#' "$rigPanel/instructions.md" )" "items 0"
	rigAssert "each of its items is an item of one list in the view" \
		"$( LC_ALL=C sed -n '/^<ul><li>/,/^<\/ul>/p' "$rigTmp/full.html" | LC_ALL=C grep -c '<li>' ) $( LC_ALL=C grep -c '^<ul><li>' "$rigTmp/full.html" )" "$rigItems 1"
	rigAssert "the rendered view holds no script" "$( LC_ALL=C grep -c -i '<script' "$rigTmp/full.html" )" 0

	echo "-- buttons: one per workspace-sourced palette task, not a second list (node only) --"
	rigAssert "each workspace-sourced task becomes a command-link button" \
		"$( LC_ALL=C grep -c 'href="command:magic-team.runPaletteTask?' "$rigTmp/full.html" )" 2
	rigAssert "a button names the Agents Console task" \
		"$( LC_ALL=C grep -c '<a class="task" href="command:magic-team.runPaletteTask?[^"]*">🤖 Start Agents Console...</a>' "$rigTmp/full.html" )" 1
	rigAssert "a button names the Update Local Tools task" \
		"$( LC_ALL=C grep -c '<a class="task" href="command:magic-team.runPaletteTask?[^"]*">📦 Update Local Tools</a>' "$rigTmp/full.html" )" 1
	rigAssert "a task from another source (not the workspace's own tasks array) is not a button" \
		"$( LC_ALL=C grep -c 'rig-other-provider-task' "$rigTmp/full.html" )" 0

	echo "-- a click: through the view's command gate to the task, its button held while it starts (node only) --"
	for rigScenario in start running silent ended gone unreadable refused ; do
		rigClick "$rigFull" "$rigScenario" || rigRefuse "the click failed in scenario $rigScenario: $( head -3 "$rigTmp/click-$rigScenario.out.err" )"
	done
	rigAssert "a click runs the fetched task of the button's name, and the button says it is starting" \
		"$( rigSeen start click ran ran-fetched )" 'starting ["📦 Update Local Tools"] yes'
	rigAssert "the other button stays a link" "$( rigSeen start other )" link
	rigAssert "a second click meanwhile finds no link, and the first one repeated runs nothing more" "$( rigSeen start again ran-after-again )" "no-link 1"
	rigAssert "at VS Code's start report the button is a link again, and no problem is shown" "$( rigSeen start released after problem )" "yes link none"
	rigAssert "a task already running is handed to VS Code once, and its button is not held" \
		"$( rigSeen running click ran timers problem )" 'link ["📦 Update Local Tools"] 0 none'
	rigAssert "with no report from VS Code the button is held on one timer" "$( rigSeen silent click timers )" "starting 1"
	rigAssert "and the timer gives it back, with no problem shown" "$( rigSeen silent released after problem )" "yes link none"
	rigAssert "an end reported with no start gives it back as well, and is not called a failure" "$( rigSeen ended click released after problem )" "starting yes link none"

	echo "-- a click that cannot start its task says why, in one line, and gives the button back (node only) --"
	rigAssert "a task the workspace no longer has" "$( rigSeen gone ran after problem )" "[] link 📦 Update Local Tools did not start: the workspace has no such task now"
	rigAssert "tasks that cannot be read" "$( rigSeen unreadable ran after problem )" "[] link 📦 Update Local Tools did not start: rig-fetch-failure"
	rigAssert "a task VS Code refuses" "$( rigSeen refused ran after problem )" '["📦 Update Local Tools"] link 📦 Update Local Tools did not start: rig-refusal'
	rigAssert "and the next click takes the line away" "$( rigSeen refused next next-problem )" "starting none"

	rigPlanted="$( rigTree planted )"
	printf -- '# RIG-HEADING\n\n- RIG-PLANT <script>alert(1)</script>\n' >> "$rigPlanted/instructions.md"
	rigRender "$rigPlanted" "$rigTmp/planted.html" || rigRefuse "the planted render failed: $( head -3 "$rigTmp/planted.html.err" )"
	rigAssert "a heading in the instructions is a heading in the view" "$( LC_ALL=C grep -c '^<h2>RIG-HEADING</h2>$' "$rigTmp/planted.html" )" 1
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
