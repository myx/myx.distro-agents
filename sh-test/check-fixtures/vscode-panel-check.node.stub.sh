#!/usr/bin/env bash
## The stand-in `node` for AgentsVscodePanelCheck, for a machine that has no node: the
## JavaScript part of that check then runs on macOS's own JavaScriptCore shell, `jsc`.
## It is not node. A script gets `require`, `module`, `process.argv`, `process.stdout.write`
## (one line per call) and `setImmediate`, and of node's own modules only what the panel and
## its drivers call: `fs` (readFileSync, writeFileSync, existsSync, accessSync, statSync,
## utimesSync), `path` (join, dirname) and `crypto` (randomBytes). jsc cannot stat a file, so
## statSync's mtimeMs is what this stand-in itself last gave the file, by writeFileSync or
## utimesSync, and 0 before that: a change the running script makes is seen, one made by
## another process is not. `require` takes those three names, an absolute path, or a name
## under $NODE_PATH. `--version` says whether jsc is there; `--check <file>` is the syntax check.
set -u
rigJsc="/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc"
[ -x "$rigJsc" ] || { echo "⛔ ERROR: the stand-in node: no JavaScriptCore shell at $rigJsc" >&2 ; exit 127 ; }
case "${1:-}" in
	--version) echo "the jsc stand-in for node" ; exit 0 ;;
	--check) exec "$rigJsc" -e 'checkSyntax(arguments[0]);' -- "$2" ;;
esac
IFS= read -r -d '' rigLoader <<'EOF' || :
(function () {
  const loaderArgs = Array.from(arguments, (rawArg) => decodeURIComponent(escape(rawArg)));
  const nodePath = loaderArgs[0];
  const scriptPath = loaderArgs[1];
  const realSetTimeout = setTimeout;
  const fileStamps = {};
  let stampCount = 0;
  const noEntry = (filePath) => Object.assign(new Error(`ENOENT: no such file or directory, open '${filePath}'`), { code: 'ENOENT' });
  const normalize = (rawPath) => {
    const parts = [];
    for (const part of rawPath.split('/')) {
      if (part === '..' && parts.length && parts[parts.length - 1] !== '..' && parts[parts.length - 1] !== '') {
        parts.pop();
      } else if (part !== '.' && (part !== '' || !parts.length)) {
        parts.push(part);
      }
    }
    return parts.join('/') || '/';
  };
  const pathShim = {
    join: (...parts) => normalize(parts.filter((part) => part !== '').join('/')),
    dirname: (filePath) => filePath.replace(/\/+[^/]*\/*$/, '') || '/',
  };
  const fsShim = {
    constants: { R_OK: 4 },
    readFileSync: (filePath) => { try { return readFile(filePath); } catch (readError) { throw noEntry(filePath); } },
    writeFileSync: (filePath, fileText) => { writeFile(filePath, fileText); stampCount += 1; fileStamps[filePath] = stampCount; },
    existsSync: (filePath) => { try { readFile(filePath); return true; } catch (readError) { return false; } },
    accessSync: (filePath) => { fsShim.readFileSync(filePath); },
    statSync: (filePath) => { fsShim.readFileSync(filePath); return { mtimeMs: fileStamps[filePath] || 0 }; },
    utimesSync: (filePath, accessTime, changeTime) => { fsShim.readFileSync(filePath); fileStamps[filePath] = Number(changeTime); },
  };
  const cryptoShim = {
    randomBytes: (byteCount) => ({
      toString: () => btoa(Array.from({ length: byteCount }, () => String.fromCharCode(Math.floor(Math.random() * 256))).join('')),
    }),
  };
  const builtins = { fs: fsShim, path: pathShim, crypto: cryptoShim };
  const loaded = {};
  const requireFrom = (moduleId) => {
    if (builtins[moduleId]) {
      return builtins[moduleId];
    }
    const filePath = moduleId.startsWith('/') ? moduleId : `${nodePath}/${moduleId}/index.js`;
    if (!loaded[filePath]) {
      const loadedModule = { exports: {} };
      loaded[filePath] = loadedModule;
      new Function('exports', 'require', 'module', '__filename', '__dirname', readFile(filePath))(loadedModule.exports, requireFrom, loadedModule, filePath, pathShim.dirname(filePath));
    }
    return loaded[filePath].exports;
  };
  globalThis.global = globalThis;
  globalThis.setImmediate = (callback) => realSetTimeout(callback, 0);
  globalThis.clearTimeout = () => {};
  globalThis.process = {
    argv: ['node', scriptPath, ...loaderArgs.slice(2)],
    stdout: { write: (text) => { print(text); } },
    stderr: { write: (text) => { printErr(text); } },
  };
  requireFrom(scriptPath);
}).apply(null, arguments);
EOF
exec "$rigJsc" -e "$rigLoader" -- "${NODE_PATH:-}" "$@"
