const fs = require('fs');
const path = require('path');
const vscode = require('vscode');

function escapeHtml(rawText) {
  return rawText.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

const CLICK_COMMAND = 'magic-team.conclave.click';

// The loader, and nothing else. The extension host that started it holds it in memory, so a
// change to it reaches a window only when that window gets a new extension host: keep it
// this small, and put nothing here that will change. All that does is panel.js beside it,
// which it reads again from disk, before each draw and each click, whenever that file's
// change time is not the one it last saw. A panel.js that cannot be loaded leaves the last
// one that did in use, with one line saying so; with none, the loader shows the line itself.
function activate(context) {
  const panelPath = path.join(__dirname, 'panel.js');
  const host = { context, clickCommand: CLICK_COMMAND, state: {}, view: undefined, problem: '', panelTime: 0 };
  let panel;
  let seenStamp;
  const currentPanel = () => {
    let fileStamp;
    try {
      fileStamp = fs.statSync(panelPath).mtimeMs;
    } catch (statError) {
      fileStamp = String(statError.code || statError.message);
    }
    if (fileStamp !== seenStamp) {
      seenStamp = fileStamp;
      try {
        const loaded = { exports: {} };
        new Function('exports', 'require', 'module', '__filename', '__dirname', fs.readFileSync(panelPath, 'utf8'))(loaded.exports, require, loaded, panelPath, __dirname);
        const loadedPanel = loaded.exports.createPanel(host);
        if (typeof loadedPanel.draw !== 'function' || typeof loadedPanel.click !== 'function') {
          throw new Error('its createPanel gives no draw and click');
        }
        panel = loadedPanel;
        host.panelTime = fileStamp;
        host.problem = '';
      } catch (loadError) {
        host.problem = `${panelPath} could not be loaded: ${String(loadError.code || loadError.message || loadError)}.${panel ? ' The last version that loaded is in use.' : ''}`;
      }
    }
    return panel;
  };
  const showProblem = (problemLine) => {
    if (host.view) {
      host.view.webview.html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none';">
</head>
<body>
<p>${escapeHtml(problemLine)} Switch to another view and back to retry.</p>
</body>
</html>`;
    }
  };
  host.redraw = async (fresh) => {
    if (!host.view) {
      return;
    }
    const shownPanel = currentPanel();
    if (!shownPanel) {
      showProblem(host.problem);
      return;
    }
    try {
      await shownPanel.draw(fresh);
    } catch (drawError) {
      showProblem(`The panel could not be drawn: ${String(drawError.message || drawError)}.`);
    }
  };
  context.subscriptions.push(vscode.commands.registerCommand(CLICK_COMMAND, async (...clickArgs) => {
    try {
      await currentPanel().click(...clickArgs);
    } catch (clickError) {
      showProblem(`The panel failed on a click: ${String(clickError.message || clickError)}.`);
    }
  }));
  context.subscriptions.push(vscode.window.registerWebviewViewProvider('magic-team.conclave', {
    resolveWebviewView(webviewView) {
      host.view = webviewView;
      webviewView.onDidDispose(() => {
        host.view = undefined;
      });
      webviewView.onDidChangeVisibility(() => {
        if (webviewView.visible) {
          host.redraw(true);
        }
      });
      return host.redraw(true);
    },
  }));
}

function deactivate() {}

module.exports = { activate, deactivate };
