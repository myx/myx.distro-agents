#!/usr/bin/env bash
## The Conclave panel, vscode/magic-team/: its manifest and its loader, extension.js, agree,
## the view its panel.js renders is locked down, a click on a task button starts that task,
## and the loader reads panel.js again from disk when that file changed. The always-on part
## needs no JavaScript runtime: package.json is read through the package's own JSON field
## reader, and the two scripts by grep. The JavaScript part, a syntax check, a headless render and
## the clicks through a stub `vscode` module, runs on `node` when node is on PATH, else
## on the stand-in beside this test, check-fixtures/vscode-panel-check.node.stub.sh:
## macOS's own JavaScriptCore shell, put first on PATH as `node`. With neither, the rig
## says so and passes on the rest. Which of the two ran is in the last line. A click
## takes the road VS Code gives it: the link's command, the view's own enableCommandUris,
## the registered command. It never runs VS Code itself. Temp tree only; no tooling op,
## no team data.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigPanel="$rigPackage/vscode/magic-team"
rigField="$rigPackage/sh-lib/AgentsHarnessJsonField.awk"
rigStandIn="$rigPackage/sh-test/check-fixtures/vscode-panel-check.node.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigPanel/package.json" "$rigPanel/extension.js" "$rigPanel/panel.js" "$rigPanel/instructions.md" "$rigField" "$rigStandIn" ; do
	[ -f "$rigFile" ] || rigRefuse "missing: $rigFile"
done
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsVscodePanelCheck )" || exit 1
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
rigCsp="$( LC_ALL=C grep -o -h 'Content-Security-Policy" content="[^"]*"' "$rigPanel/extension.js" "$rigPanel/panel.js" )"
rigAssert "one CSP in each script: the panel's, and the one of the loader's own one-line page" \
	"$( LC_ALL=C grep -c 'Content-Security-Policy" content="' "$rigPanel/extension.js" ) $( LC_ALL=C grep -c 'Content-Security-Policy" content="' "$rigPanel/panel.js" )" "1 1"
rigAssert "each CSP defaults to none" "$( printf '%s\n' "$rigCsp" | LC_ALL=C grep -c "default-src 'none'" )" 2
rigAssert "no CSP names a script source" "$( case "$rigCsp" in (*script-src*) printf present ;; (*) printf none ;; esac )" none
rigAssert "scripts are disabled in the webview options" "$( LC_ALL=C grep -c 'enableScripts: false' "$rigPanel/panel.js" ) $( cat "$rigPanel/extension.js" "$rigPanel/panel.js" | LC_ALL=C grep -c 'enableScripts: true' )" "1 0"
rigAssert "the one command a link in the view may run is the loader's click command" "$( LC_ALL=C grep -c 'enableCommandUris: \[host.clickCommand\]' "$rigPanel/panel.js" ) $( cat "$rigPanel/extension.js" "$rigPanel/panel.js" | LC_ALL=C grep -c 'enableCommandUris: true' )" "1 0"
rigAssert "and every link in the view is a click on it" \
	"$( LC_ALL=C grep -c 'command:${host.clickCommand}?' "$rigPanel/panel.js" ) $( LC_ALL=C grep -o 'href="' "$rigPanel/panel.js" | LC_ALL=C grep -c . ) $( LC_ALL=C grep -o 'href="${clickHref(host, ' "$rigPanel/panel.js" | LC_ALL=C grep -c . )" "1 2 2"
rigAssert "the loader is the loader only: no task, no text file, no link, no webview option of the panel's" \
	"$( LC_ALL=C grep -c -e 'fetchTasks' -e 'executeTask' -e 'instructions.md' -e 'href=' -e 'webview.options' "$rigPanel/extension.js" )" 0
rigAssert "and it reads the panel from the one file beside it" "$( LC_ALL=C grep -c "path.join(__dirname, 'panel.js')" "$rigPanel/extension.js" )" 1

## The JavaScript part: on node when node is on PATH, else on the stand-in, put first on
## PATH as `node` for the drivers below.
rigRuntime=""
if command -v node > /dev/null 2>&1 ; then
	rigRuntime="node"
else
	mkdir -p "$rigTmp/bin" && cp "$rigStandIn" "$rigTmp/bin/node" && chmod +x "$rigTmp/bin/node" || rigRefuse "the stand-in node could not be set up"
	if "$rigTmp/bin/node" --version > /dev/null 2>&1 ; then
		PATH="$rigTmp/bin:$PATH"
		rigRuntime="the jsc stand-in for node"
	fi
fi
echo "-- syntax and a headless render (JavaScript part, on ${rigRuntime:-nothing}) --"
if [ -z "$rigRuntime" ] ; then
	echo "        not run: no node on PATH and no JavaScriptCore shell -- syntax check, headless render and clicks skipped"
else
	rigAssert "extension.js and panel.js pass node --check" "$( node --check "$rigPanel/extension.js" 2>&1 && node --check "$rigPanel/panel.js" 2>&1 && printf ok )" ok

	## A tree shaped as the extension expects: the panel two levels below the skillset.
	## The identity file is a fixture with known text; the instructions are the real
	## ones, and a second copy carries a planted heading and a planted <script>.
	rigTree(){ ## name -> a fresh tree holding a full panel
		local treeDir="$rigTmp/$1"
		mkdir -p "$treeDir/vscode/magic-team" "$treeDir/skillset/magic-team/magic-team/resources"
		cp "$rigPanel/extension.js" "$rigPanel/panel.js" "$rigPanel/instructions.md" "$treeDir/vscode/magic-team/"
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
    onDidStartTask: (listener) => { startListeners.push(listener); return { dispose() { startListeners = startListeners.filter((kept) => kept !== listener); } }; },
    onDidEndTask: (listener) => { endListeners.push(listener); return { dispose() { endListeners = endListeners.filter((kept) => kept !== listener); } }; },
  },
  rigProvider: () => provider,
  rigCommands: () => registeredCommands,
  rigExecutedTasks: () => executedTasks,
  rigTasks: RIG_TASKS,
  rigNext,
  rigExecutions: () => returnedExecutions,
  rigListeners: () => startListeners.length + endListeners.length,
  rigStart: (execution) => startListeners.slice().forEach((listener) => listener({ execution })),
  rigEnd: (execution) => endListeners.slice().forEach((listener) => listener({ execution })),
  rigView: (webview) => {
    const showListeners = [];
    return {
      webview,
      visible: true,
      onDidDispose: () => ({ dispose() {} }),
      onDidChangeVisibility: (listener) => { showListeners.push(listener); return { dispose() {} }; },
      rigShow: () => showListeners.forEach((listener) => listener()),
    };
  },
};
EOF
	cat > "$rigTmp/render.js" <<'EOF'
const vscode = require('vscode');
const extension = require(process.argv[2]);
extension.activate({ extensionPath: process.argv[3], subscriptions: [] });
const webview = { cspSource: 'rig-csp-source', asWebviewUri: (u) => ({ toString: () => 'rig-webview:' + u.fsPath }) };
(async () => {
  await vscode.rigProvider().p.resolveWebviewView(vscode.rigView(webview));
  process.stdout.write(webview.html);
})();
EOF
	## One scenario on the Update Local Tools button, and what was seen of it, one `key=value`
	## a line. A click goes as VS Code sends it: the link the view shows now, refused unless
	## the view's enableCommandUris lets its command run, then the registered command with the
	## link's own arguments. The timer the panel arms is held here and fires only when the
	## scenario says so. A scenario that changes the panel file writes it itself, with a later
	## change time, as the install does when it rewrites the copy: RIG-V2 in two of its texts,
	## or a file that does not parse.
	cat > "$rigTmp/click.js" <<'EOF'
const fs = require('fs');
const vscode = require('vscode');
const rigPanelFile = `${process.argv[3]}/panel.js`;
const rigScenario = process.argv[4];
const rigName = '📦 Update Local Tools';
const rigTimers = [];
globalThis.setTimeout = (callback) => rigTimers.push(callback);
globalThis.clearTimeout = () => {};
if (rigScenario === 'running') {
  vscode.rigNext.execution = { task: vscode.rigTasks[1] };
  vscode.tasks.taskExecutions.push(vscode.rigNext.execution);
}
const rigSource = fs.readFileSync(rigPanelFile, 'utf8');
const rigChanged = rigSource.split('Run a task:').join('RIG-V2 run:').split('Starting: ').join('RIG-V2 starting: ');
const rigBroken = `${rigSource}\n}{\n`;
let rigWrites = 0;
const rigWrite = (panelSource) => {
  rigWrites += 1;
  fs.writeFileSync(rigPanelFile, panelSource);
  fs.utimesSync(rigPanelFile, new Date(2000000000000 + rigWrites * 1000), new Date(2000000000000 + rigWrites * 1000));
};
const extension = require(process.argv[2]);
extension.activate({ extensionPath: process.argv[3], subscriptions: [] });
const webview = { cspSource: 'rig-csp-source', asWebviewUri: (u) => ({ toString: () => 'rig-webview:' + u.fsPath }) };
const rigView = vscode.rigView(webview);
const rigItem = (taskName) => webview.html.split('\n').find((htmlLine) => htmlLine.startsWith('<li><') && htmlLine.includes(`${taskName}</`)) || '';
const rigState = (taskName) => (webview.html.includes(`RIG-V2 starting: ${taskName}<`) ? 'starting-changed' : rigItem(taskName).startsWith('<li><a class="task" href="command:') ? 'link' : rigItem(taskName).startsWith('<li><span class="task starting">') ? 'starting' : 'none');
const rigProblem = () => (webview.html.match(/<\/ul>\n<p class="missing">(.*)<\/p>/) || ['', 'none'])[1];
const rigVersion = () => (webview.html.includes('RIG-V2 run:') ? 'changed' : webview.html.includes('Run a task:') ? 'first' : 'none');
const rigLoadLine = () => {
  const lineMatch = webview.html.match(/<body>\n<p( class="missing")?>(.*)<\/p>/);
  if (!lineMatch) {
    return 'none';
  }
  if (lineMatch[1] && / could not be loaded: .+\. The last version that loaded is in use\.$/.test(lineMatch[2])) {
    return 'kept';
  }
  return !lineMatch[1] && / could not be loaded: .+\. Switch to another view and back to retry\.$/.test(lineMatch[2]) && !lineMatch[2].includes('last version') ? 'alone' : lineMatch[2];
};
const rigSettle = () => new Promise((resolve) => setImmediate(resolve));
const rigReleased = (clickRun) => Promise.race([Promise.resolve(clickRun).then(() => 'yes'), rigSettle().then(rigSettle).then(() => 'no')]);
const rigRan = () => JSON.stringify(vscode.rigExecutedTasks().map((executedTask) => executedTask.name));
let rigCommand = null;
const rigClick = (linkText) => {
  const linkMatch = (webview.html.split('\n').find((htmlLine) => htmlLine.includes(`>${linkText}</a>`)) || '').match(/<a (?:class="task" )?href="command:([^?"]*)\?([^"]*)">/);
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
const rigShow = async () => {
  rigView.rigShow();
  await rigSettle();
};
const rigHolds = async (rigSeen) => {
  vscode.rigNext.tasks = rigScenario === 'gone' ? [] : vscode.rigTasks;
  vscode.rigNext.fetchFailure = rigScenario === 'unreadable' ? 'rig-fetch-failure' : '';
  vscode.rigNext.refusal = rigScenario === 'refused' ? 'rig-refusal' : '';
  const rigRun = rigClick(rigName);
  await rigSettle();
  rigSeen.push(`click=${typeof rigRun === 'string' ? rigRun : rigState(rigName)}`);
  rigSeen.push(`other=${rigState('🤖 Start Agents Console...')}`);
  rigSeen.push(`ran=${rigRan()}`);
  rigSeen.push(`ran-fetched=${vscode.rigExecutedTasks()[0] === vscode.rigTasks[1] ? 'yes' : 'no'}`);
  rigSeen.push(`timers=${rigTimers.length}`);
  if (rigScenario === 'start' || rigScenario === 'held') {
    if (rigScenario === 'held') {
      rigWrite(rigChanged);
      await rigShow();
      rigSeen.push(`held=${rigState(rigName)}`);
    }
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
  rigSeen.push(`released=${await rigReleased(rigRun)}`);
  rigSeen.push(`after=${rigState(rigName)}`);
  rigSeen.push(`version=${rigVersion()}`);
  rigSeen.push(`problem=${rigProblem()}`);
  rigSeen.push(`listeners=${vscode.rigListeners()}`);
  if (rigScenario === 'refused') {
    vscode.rigNext.refusal = '';
    rigClick(rigName);
    await rigSettle();
    rigSeen.push(`next=${rigState(rigName)}`);
    rigSeen.push(`next-problem=${rigProblem()}`);
  }
};
const rigReloads = async (rigSeen) => {
  rigSeen.push(`first=${rigVersion()}`);
  rigSeen.push(`first-line=${rigLoadLine()}`);
  if (rigScenario === 'shown') {
    rigWrite(rigChanged);
    await rigShow();
    rigSeen.push(`shown=${rigVersion()}`);
    rigWrite(rigSource);
    const rigReload = rigClick('Reload');
    await rigSettle();
    rigSeen.push(`reload-click=${typeof rigReload === 'string' ? rigReload : 'taken'}`);
    rigSeen.push(`reloaded=${rigVersion()}`);
  }
  if (rigScenario === 'clicked') {
    rigWrite(rigChanged);
    rigClick(rigName);
    await rigSettle();
    rigSeen.push(`click=${rigState(rigName)}`);
    rigSeen.push(`ran=${rigRan()}`);
  }
  if (rigScenario === 'broken') {
    rigWrite(rigBroken);
    await rigShow();
    rigSeen.push(`shown=${rigVersion()}`);
    rigSeen.push(`line=${rigLoadLine()}`);
    const rigRun = rigClick(rigName);
    await rigSettle();
    rigSeen.push(`click=${rigState(rigName)}`);
    rigSeen.push(`ran=${rigRan()}`);
    vscode.rigStart(vscode.rigExecutions()[0]);
    rigSeen.push(`released=${await rigReleased(rigRun)}`);
    rigSeen.push(`line-after-click=${rigLoadLine()}`);
  }
  if (rigScenario === 'hollow') {
    rigWrite(`${rigSource}\nmodule.exports.createPanel = () => ({});\n`);
    await rigShow();
    rigSeen.push(`shown=${rigVersion()}`);
    rigSeen.push(`line=${rigLoadLine()}`);
  }
  if (rigScenario === 'broken' || rigScenario === 'unloadable') {
    rigWrite(rigScenario === 'broken' ? rigChanged : rigSource);
    await rigShow();
    rigSeen.push(`mended=${rigVersion()}`);
    rigSeen.push(`mended-line=${rigLoadLine()}`);
  }
};
(async () => {
  const rigSeen = [];
  if (rigScenario === 'unloadable') {
    rigWrite(rigBroken);
  }
  await vscode.rigProvider().p.resolveWebviewView(rigView);
  await (['shown', 'clicked', 'broken', 'hollow', 'unloadable'].includes(rigScenario) ? rigReloads : rigHolds)(rigSeen);
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

	echo "-- buttons: one per workspace-sourced palette task, not a second list (JavaScript part) --"
	rigAssert "each workspace-sourced task becomes a command-link button" \
		"$( LC_ALL=C grep -c '<a class="task" href="command:magic-team.conclave.click?' "$rigTmp/full.html" )" 2
	rigAssert "a button names the Agents Console task" \
		"$( LC_ALL=C grep -c '<a class="task" href="command:magic-team.conclave.click?[^"]*">🤖 Start Agents Console...</a>' "$rigTmp/full.html" )" 1
	rigAssert "a button names the Update Local Tools task" \
		"$( LC_ALL=C grep -c '<a class="task" href="command:magic-team.conclave.click?[^"]*">📦 Update Local Tools</a>' "$rigTmp/full.html" )" 1
	rigAssert "a task from another source (not the workspace's own tasks array) is not a button" \
		"$( LC_ALL=C grep -c 'rig-other-provider-task' "$rigTmp/full.html" )" 0

	echo "-- a click: through the view's command gate to the task, its button held while it starts (JavaScript part) --"
	for rigScenario in start running silent ended gone unreadable refused shown clicked broken hollow held unloadable ; do
		rigClick "$( rigTree "click-$rigScenario" )" "$rigScenario" || rigRefuse "the click failed in scenario $rigScenario: $( head -3 "$rigTmp/click-$rigScenario.out.err" )"
	done
	rigAssert "a click runs the fetched task of the button's name, and the button says it is starting" \
		"$( rigSeen start click ran ran-fetched )" 'starting ["📦 Update Local Tools"] yes'
	rigAssert "the other button stays a link" "$( rigSeen start other )" link
	rigAssert "a second click meanwhile finds no link, and the first one repeated runs nothing more" "$( rigSeen start again ran-after-again )" "no-link 1"
	rigAssert "at VS Code's start report the button is a link again: no problem shown, no listener left" "$( rigSeen start released after problem listeners )" "yes link none 0"
	rigAssert "a task already running is handed to VS Code once, and its button is not held" \
		"$( rigSeen running click ran timers problem )" 'link ["📦 Update Local Tools"] 0 none'
	rigAssert "with no report from VS Code the button is held on one timer" "$( rigSeen silent click timers )" "starting 1"
	rigAssert "and the timer gives it back: no problem shown, no listener left" "$( rigSeen silent released after problem listeners )" "yes link none 0"
	rigAssert "an end reported with no start gives it back as well, and is not called a failure" "$( rigSeen ended click released after problem listeners )" "starting yes link none 0"

	echo "-- a click that cannot start its task says why, in one line, and gives the button back (JavaScript part) --"
	rigAssert "a task the workspace no longer has" "$( rigSeen gone ran after problem )" "[] link 📦 Update Local Tools did not start: the workspace has no such task now"
	rigAssert "tasks that cannot be read" "$( rigSeen unreadable ran after problem )" "[] link 📦 Update Local Tools did not start: rig-fetch-failure"
	rigAssert "a task VS Code refuses" "$( rigSeen refused ran after problem )" '["📦 Update Local Tools"] link 📦 Update Local Tools did not start: rig-refusal'
	rigAssert "and the next click takes the line away" "$( rigSeen refused next next-problem )" "starting none"

	echo "-- the panel file is read again from disk when it has changed, with nothing restarted (JavaScript part) --"
	rigAssert "a changed file is drawn when the view is next shown, and at a click on Reload" "$( rigSeen shown first shown reload-click reloaded )" "first changed taken first"
	rigAssert "a changed file handles the very next click" "$( rigSeen clicked first click ran )" 'first starting-changed ["📦 Update Local Tools"]'
	rigAssert "a file that cannot be loaded leaves the last good one drawn, with one line saying so" "$( rigSeen broken first-line shown line )" "none first kept"
	rigAssert "and working: a click still starts its task, and the line stays" "$( rigSeen broken click ran released line-after-click )" 'starting ["📦 Update Local Tools"] yes kept'
	rigAssert "a mended file is loaded, and the line goes" "$( rigSeen broken mended mended-line )" "changed none"
	rigAssert "a file whose panel gives no draw and click is refused the same way" "$( rigSeen hollow shown line )" "first kept"
	rigAssert "a button held when the file changes stays held, drawn by the new file, and a second click runs nothing more" \
		"$( rigSeen held click held again ran-after-again )" "starting starting-changed no-link 1"
	rigAssert "and the start report gives it back, in the new file's view, with no listener left" "$( rigSeen held released after version problem listeners )" "yes link changed none 0"
	rigAssert "a file that cannot be loaded the first time leaves the loader's own one line, with how to retry, and a mended one the panel" \
		"$( rigSeen unloadable first first-line mended mended-line )" "none alone first none"

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

	## The installed layout: the six files flat in one folder, with no skillset above it.
	rigFlat="$rigTmp/flat/installed/magic-team-panel"
	mkdir -p "$rigFlat"
	cp "$rigPanel/package.json" "$rigPanel/extension.js" "$rigPanel/panel.js" "$rigPanel/instructions.md" \
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

	## A copy made by an install that knows no panel.js: the old five files, under the new
	## loader. The loader says so in its own one line, and does not fail.
	rm -f "$rigFlat/panel.js"
	rigRender "$rigFlat" "$rigTmp/flat-nopanel.html" || rigRefuse "the render of a copy without panel.js failed: $( head -3 "$rigTmp/flat-nopanel.html.err" )"
	rigAssert "a copy installed without panel.js: the loader's own one line, and nothing of the panel" \
		"$( LC_ALL=C grep -c "^<p>$rigFlat/panel.js could not be loaded: ENOENT. Switch to another view and back to retry.</p>\$" "$rigTmp/flat-nopanel.html" ) $( LC_ALL=C grep -c -e '<img' -e '<a ' -e '<ul' "$rigTmp/flat-nopanel.html" )" "1 0"
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ VSCODE PANEL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'VSCODE_PANEL: OK (%d assertions, JavaScript part %s)\n' "$rigPassCount" "$( [ -n "$rigRuntime" ] && printf 'on %s' "$rigRuntime" || printf 'not run' )"
