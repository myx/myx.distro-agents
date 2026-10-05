# Installation

[Back to the README](../README.md)

## Getting started

Install the toolset into a workspace, then wire the team into every editor and
agent client on this machine:

	bash .local/myx/myx.distro-.local/sh-scripts/DistroLocalTools.fn.sh --install-distro-agents
	DistroAgentsTools.fn.sh --install-workspace-integrations

`--install-workspace-integrations` does both setup steps: it links the team's
members into the skill directories agent clients read, workspace-local and
user-home, then installs the VS Code integrations. Run the steps on their own
when you need to:

	DistroAgentsTools.fn.sh --install-skillset-symlinks --scope workspace
	DistroAgentsTools.fn.sh --install-skillset-symlinks --scope user-home
	DistroAgentsTools.fn.sh --install-vscode-integrations

Re-run `--install-skillset-symlinks` after adding or removing a member: it
reconciles this workspace's registered set rather than only adding to it. Remove
everything this workspace registered with `--install-skillset-symlinks --remove`.

## Choosing the agent CLI

Each CLI this workspace can start has its own setup domain. A bare call reports
what is still missing and names the command that closes it:

	DistroAgentsTools.fn.sh --owner-setup-claude-native
	DistroAgentsTools.fn.sh --owner-setup-claude-native --apply

- `--check` writes the per-setting detail, read-only.
- `--apply` carries the setup out.
- `--print-apply-command` writes the command an `--apply` would run, and changes
  nothing — use it when a credential has to be supplied.

The CLI domains are `claude`, `claude-native`, `copilot`, `grok` and `scaleway`:

- `claude-native` runs the vendor `claude` already installed and signed in on
  this machine. It stores no credential here — sign in once with
  `claude auth login`, and every workspace on the machine uses that sign-in.
- `claude`, `copilot`, `grok` and `scaleway` each store their own credential in this
  workspace, so a workspace can run under an account of its own.


## Setup manuals

Each CLI domain has its own manual. It lists every option the domain takes, and what you must do yourself to obtain each value.

- `DistroAgentsTools.fn.sh --help-setup-<domain>` prints one domain's manual.
- [claude](../sh-lib/help/Help.DistroAgentsTools-setup-claude.help.md), [grok](../sh-lib/help/Help.DistroAgentsTools-setup-grok.help.md) and [scaleway](../sh-lib/help/Help.DistroAgentsTools-setup-scaleway.help.md) have manuals.

For `claude`, `--apply` first records the workspace as trusted in the vendor's own state file. Claude discards the permission entries of a workspace it does not trust, so the later steps would do nothing without it.
