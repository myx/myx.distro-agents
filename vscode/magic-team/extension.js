const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const vscode = require('vscode');

function escapeHtml(rawText) {
  return rawText.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function renderMissing(filePath, readError) {
  return `<p class="missing">${escapeHtml(filePath)} could not be read: ${escapeHtml(String(readError.code || readError.message))}</p>`;
}

const RUN_TASK_COMMAND = 'magic-team.runPaletteTask';
const START_REPORT_WAIT_MS = 10000;

function renderTask(taskName, isStarting) {
  return isStarting
    ? `<li><span class="task starting">Starting: ${escapeHtml(taskName)}</span></li>`
    : `<li><a class="task" href="command:${RUN_TASK_COMMAND}?${encodeURIComponent(JSON.stringify([taskName]))}">${escapeHtml(taskName)}</a></li>`;
}

function activate(context) {
  const skillsetDir = path.join(context.extensionPath, '..', '..', 'skillset', 'magic-team', 'magic-team');
  const startingTasks = new Set();
  const startedExecutions = new Set(vscode.tasks.taskExecutions);
  const startWaits = new Map();
  let taskProblem = '';
  let renderView = () => {};
  const settleStart = (taskExecution) => {
    const startWait = startWaits.get(taskExecution);
    if (startWait) {
      startWaits.delete(taskExecution);
      clearTimeout(startWait.timer);
      startWait.resolve();
    }
  };
  context.subscriptions.push(vscode.tasks.onDidStartTask((taskEvent) => {
    startedExecutions.add(taskEvent.execution);
    settleStart(taskEvent.execution);
  }));
  context.subscriptions.push(vscode.tasks.onDidEndTask((taskEvent) => {
    startedExecutions.delete(taskEvent.execution);
    settleStart(taskEvent.execution);
  }));
  context.subscriptions.push(vscode.commands.registerCommand(RUN_TASK_COMMAND, async (taskName) => {
    if (startingTasks.has(taskName)) {
      return;
    }
    startingTasks.add(taskName);
    taskProblem = '';
    renderView();
    try {
      const paletteTasks = await vscode.tasks.fetchTasks();
      const paletteTask = paletteTasks.find((candidateTask) => candidateTask.source === 'Workspace' && candidateTask.name === taskName);
      if (!paletteTask) {
        throw new Error('the workspace has no such task now');
      }
      const taskExecution = await vscode.tasks.executeTask(paletteTask);
      if (!startedExecutions.has(taskExecution)) {
        await new Promise((resolve) => {
          startWaits.set(taskExecution, { resolve, timer: setTimeout(() => settleStart(taskExecution), START_REPORT_WAIT_MS) });
        });
      }
    } catch (startError) {
      taskProblem = `${taskName} did not start: ${String(startError.message || startError)}`;
    }
    startingTasks.delete(taskName);
    renderView();
  }));
  context.subscriptions.push(vscode.window.registerWebviewViewProvider('magic-team.conclave', {
    async resolveWebviewView(webviewView) {
      const webview = webviewView.webview;
      const installedLayout = fs.existsSync(path.join(context.extensionPath, 'magic-team.basic.md'));
      const markPath = installedLayout ? path.join(context.extensionPath, 'the-conclave.mark.svg') : path.join(skillsetDir, 'resources', 'the-conclave.mark.svg');
      const basicPath = path.join(installedLayout ? context.extensionPath : skillsetDir, 'magic-team.basic.md');
      const instructionsPath = path.join(context.extensionPath, 'instructions.md');
      webview.options = { enableScripts: false, enableCommandUris: [RUN_TASK_COMMAND], localResourceRoots: [vscode.Uri.file(path.dirname(markPath))] };

      let markHtml;
      try {
        fs.accessSync(markPath, fs.constants.R_OK);
        markHtml = `<img class="mark" src="${escapeHtml(webview.asWebviewUri(vscode.Uri.file(markPath)).toString())}" alt="">`;
      } catch (readError) {
        markHtml = renderMissing(markPath, readError);
      }

      let identityHtml;
      try {
        const publicSection = (fs.readFileSync(basicPath, 'utf8').split(/^## Public Information[ \t]*\r?$/m)[1] || '').split(/^## /m)[0];
        const nameMatch = publicSection.match(/^- \*\*Name\*\*:[ \t]*(?:\*\*([^*\n]+)\*\*|(.*))/m);
        const descriptionMatch = publicSection.match(/^- \*\*Description\*\*:[ \t]*(.*(?:\n[ \t]+\S.*)*)/m);
        identityHtml = nameMatch && descriptionMatch
          ? `<h1>${escapeHtml((nameMatch[1] || nameMatch[2]).trim())}</h1>\n<p>${escapeHtml(descriptionMatch[1].replace(/\s+/g, ' ').trim()).replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>').replace(/`([^`]+)`/g, '<code>$1</code>')}</p>`
          : `<p class="missing">${escapeHtml(basicPath)} has no Name or Description in its Public Information section</p>`;
      } catch (readError) {
        identityHtml = renderMissing(basicPath, readError);
      }

      let instructionsHtml = '';
      try {
        let openTag = '';
        for (const sourceLine of fs.readFileSync(instructionsPath, 'utf8').split(/\r?\n/)) {
          const headingMatch = sourceLine.match(/^#+[ \t]+(.*)/);
          const itemMatch = sourceLine.match(/^-[ \t]+(.*)/);
          const lineHtml = escapeHtml((headingMatch || itemMatch || [sourceLine, sourceLine])[1].trim()).replace(/`([^`]+)`/g, '<code>$1</code>');
          if (openTag && headingMatch) {
            instructionsHtml += `</${openTag}>\n`;
            openTag = '';
          }
          if (openTag && !lineHtml) {
            instructionsHtml += `</${openTag}>\n`;
            openTag = '';
          }
          if ((openTag === 'p' && itemMatch) || (openTag === 'ul' && !itemMatch && !/^[ \t]/.test(sourceLine))) {
            instructionsHtml += `</${openTag}>\n`;
            openTag = '';
          }
          if (headingMatch) {
            instructionsHtml += `<h2>${lineHtml}</h2>\n`;
          } else if (itemMatch) {
            instructionsHtml += `${openTag ? '' : '<ul>'}<li>${lineHtml}</li>\n`;
            openTag = 'ul';
          } else if (lineHtml && openTag === 'ul') {
            instructionsHtml = instructionsHtml.replace(/<\/li>\n$/, ` ${lineHtml}</li>\n`);
          } else if (lineHtml) {
            instructionsHtml += openTag ? ` ${lineHtml}` : `<p>${lineHtml}`;
            openTag = 'p';
          }
        }
        if (openTag) {
          instructionsHtml += `</${openTag}>\n`;
        }
      } catch (readError) {
        instructionsHtml = renderMissing(instructionsPath, readError);
      }

      let paletteTasks = [];
      let tasksMissingHtml = '';
      try {
        paletteTasks = (await vscode.tasks.fetchTasks()).filter((candidateTask) => candidateTask.source === 'Workspace');
      } catch (readError) {
        tasksMissingHtml = `<p class="missing">workspace tasks could not be read: ${escapeHtml(String(readError.message))}</p>`;
      }

      renderView = () => {
        const tasksHtml = paletteTasks.length
          ? `<p class="tasks-label">Run a task:</p>\n<ul class="tasks">\n${paletteTasks.map((paletteTask) => renderTask(paletteTask.name, startingTasks.has(paletteTask.name))).join('\n')}\n</ul>\n${taskProblem ? `<p class="missing">${escapeHtml(taskProblem)}</p>\n` : ''}`
          : tasksMissingHtml;
        const styleNonce = crypto.randomBytes(16).toString('base64');
        webview.html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${webview.cspSource}; style-src 'nonce-${styleNonce}'; base-uri 'none'; form-action 'none';">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style nonce="${styleNonce}">
body { font-family: var(--vscode-font-family); font-size: var(--vscode-font-size); color: var(--vscode-foreground); line-height: 1.5; padding: 0 12px 16px; }
.mark { display: block; width: 96px; height: 96px; margin: 16px auto 8px; border-radius: 16px; }
h1 { font-size: 1.4em; text-align: center; margin: 0 0 8px; }
h2 { font-size: 1.05em; margin: 20px 0 6px; }
p { margin: 0 0 8px; }
ul { margin: 0 0 8px; padding-left: 20px; }
code { font-family: var(--vscode-editor-font-family); background: var(--vscode-textCodeBlock-background); padding: 0 3px; border-radius: 3px; }
.missing { color: var(--vscode-errorForeground); }
.tasks-label { margin: 16px 0 4px; font-weight: 600; }
.tasks { margin: 0 0 8px; padding: 0; list-style: none; }
.task { display: block; margin: 4px 0; padding: 6px 10px; border-radius: 4px; background: var(--vscode-button-background); color: var(--vscode-button-foreground); text-decoration: none; text-align: center; }
.task:hover { background: var(--vscode-button-hoverBackground); }
.starting { opacity: 0.6; pointer-events: none; }
</style>
</head>
<body>
${markHtml}
${identityHtml}
${instructionsHtml}${tasksHtml}</body>
</html>`;
      };
      webviewView.onDidDispose(() => {
        renderView = () => {};
      });
      renderView();
    },
  }));
}

function deactivate() {}

module.exports = { activate, deactivate };
