---
maintainers: magic-coordinator, magic-librarian, keeper-myx, human-owner
---
# Calling the workspace tooling: the forms that work

The operator's form is one shape everywhere: **`<Tool>.fn.sh --<operation> <arguments>`, run inside a workspace console.** The internal form `Require F ; Distro F …` belongs to tooling code that calls tooling, never to an operator at a console (code-craft.md, "Each call runs only its own path").

Before typing an operation, take its syntax from its own help, never from memory:

```
<Tool>.fn.sh --help-syntax --<operation>
```

Measured 2026-11-26 in the six `util.repository-*` workspaces and in ws-2017.

## Getting a console

A workspace console sets `MMDAPP`, `MDLT_ORIGIN` and the tool paths. Feed it commands on stdin and tell it to exit:

```
printf '<Tool>.fn.sh --<operation> <arguments>\nexit\n' | ./DistroSourceConsole.sh
printf '<Tool>.fn.sh --<operation> <arguments>\nexit\n' | ./DistroDeployConsole.sh
```

Source-side operations live in the source console, deploy-side in the deploy console. A deploy tool typed into the source console reports `command not found`, which is a wrong-console symptom, not a missing tool.

## The operations this session relied on

| Purpose | Call | Console |
|---|---|---|
| Build check | `CleanAllOutputs.fn.sh ; BuildCachedFromSource.fn.sh` | source |
| List hosts with ssh targets | `ListSshTargets.fn.sh --all-targets` | deploy |
| Run a command on a host | `ShellTo.fn.sh <unique-name-part> --execute-command <command>` | deploy |
| List namespace roots | `DistroSourceTools.fn.sh --list-namespace-roots` | source |
| Register a namespace root | `DistroSourceTools.fn.sh --register-namespace-root <ns> <repository-href>` | source |
| Unregister a namespace root | `DistroSourceTools.fn.sh --unregister-namespace-root <ns>` | source |
| Pull what the list names | `DistroImageSync.fn.sh --all-tasks --execute-source-prepare-pull` | source |
| Build deploy data from source | `BuildDistroFromSource.fn.sh` | deploy |

`--register-namespace-root` without its href fails with `repository root href expected`; the href is the umbrella project's own remote (for example `git@github.com:myx/util.repository-myx.git`).

## How a build check reads

`All Builders passed.` is the pass line. `⛔ ERROR` lines are failures. `⛔ MISSING:no '<provider>' provider, required from '<project>'` is an unresolved dependency: the provider's project is not in source, or its namespace root is not registered, or the project carries no `project.inf`. A project present on disk without `project.inf` provides nothing.

## What a clean removes

`CleanAllOutputs.fn.sh` deletes the workspace's `output/` tree outright, by design. Nothing that must survive the next build check is kept under `output/`; records go to the board or the inbox through the items tooling.

## Two wrong turns this file exists to prevent

- Inventing a dispatcher form such as `Distro ListSshTargets`. No such form exists at a console: the tool's own name with its own options is the only form.
- Passing an operation name the tool's help does not list, then reading the refusal as a broken tool. The help is the definition: `--help-syntax --<operation>` first, then the call.
