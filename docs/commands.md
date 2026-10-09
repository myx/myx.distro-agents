# Commands

[Back to the README](../README.md)

- `DistroAgentsTools.fn.sh` — the team's operations interface: install, configure, message,
  read and write board items, run console sessions, drive the routine state machinery.
- `DistroAgentsConsole.sh` — start an agent CLI session against this workspace.


## Setup operations

`--owner-setup-<domain>` sets up one domain of the installation. A bare call writes the status and names the one command that closes the gap.

- `--check` — write the per-setting detail. Read-only.
- `--apply` — carry out the setup without prompts.
- `--print-apply-command` — write the full command template, with a placeholder per value. It changes nothing.
- `--wizard` — an interactive form. It is not built yet.

Rules for the arguments:

- Give options and their values first, then at most one sub-operation last.
- Anything after a sub-operation is an error.
- A domain accepts only the options it declares.
- A bare call names the required options that are still unset. An optional option is never shown there.
- `--print-apply-command` shows every option the domain declares. It exits 0, so it is not a readiness check. Use `--check` for that.
- `--apply` takes a value to store, such as `--set-as-default`. `--print-apply-command` refuses one.
- A diagnosis answers about the current workspace. `--all-workspaces` reports every registered workspace, where a domain offers it.

A secret goes through `--values-from-stdin --apply`, so it never reaches a command line. `--print-apply-command` writes that stdin form when the domain carries a secret.

## Help levels

- A bare call to `DistroAgentsTools.fn.sh` prints the default syntax: the help entry points, the two root install methods, `--owner-setup-<domain>` and the general agents-config line.
- `--help-syntax` adds the syntax line of every other operation.
- `--help` adds the manual. It opens with the same full list.
- `--help-setup-<domain>` prints one domain's setup manual.
- `--member-help <member>` prints only what that member may run.

The two root install methods are `--install-workspace-integrations` and `--install-workspace-restrictions`. `--install-workspace-integrations` calls the VS Code, skillset-link, Claude trust, Claude permission and Copilot access steps. `--help-syntax` lists those steps.

`--install-workspace-restrictions` is optional, and you run it yourself. Once it is installed, `--make-workspace-integrations` keeps it current. See [Workspace restrictions](installation.md#workspace-restrictions-optional).

The first command to run in a new workspace is `--owner-setup-claude`. See [Getting started](installation.md#getting-started).


## Manuals

Each tool has a manual with its full syntax, options and examples.

- [DistroAgentsTools-setup-claude](../sh-lib/help/Help.DistroAgentsTools-setup-claude.help.md)
- [DistroAgentsTools-setup-grok](../sh-lib/help/Help.DistroAgentsTools-setup-grok.help.md)
- [DistroAgentsTools-setup-scaleway](../sh-lib/help/Help.DistroAgentsTools-setup-scaleway.help.md)
- [DistroAgentsTools](../sh-lib/help/Help.DistroAgentsTools.help.md)
