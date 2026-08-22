# myx.distro-agents

The `magic-team` AI agent team, the tooling it runs on, and the installation that
wires both into a workspace.

Three parts:

- **The team** — `skillset/magic-team/` holds the team members themselves:
  `magic-coordinator`, `magic-architect`, `magic-developer`, `magic-devops`,
  `magic-frontender`, `magic-librarian`, `magic-tester` and the shared
  `magic-team` avatar. Any workspace can add its own members on top.
- **The tooling** — `DistroAgentsTools.fn.sh`, the single interface the team uses
  for every stateful action: Slack, email and Trello messaging; board and inbox
  items; per-member credentials; keep-alive console sessions; and the routine
  state machinery the team's daily rhythm runs on.
- **The console** — `DistroAgentsConsole.sh`, which starts an agent CLI session
  against the workspace instead of a bash shell.

## Getting started

Install the toolset into a workspace, then wire the team into every editor and
agent client on this machine:

	bash .local/myx/myx.distro-.local/sh-scripts/DistroLocalTools.fn.sh --install-distro-agents
	DistroAgentsTools.fn.sh --install-workspace-integrations

That one command does both setup steps: it links the team's members into the
skill directories agent clients read (workspace-local and user-home), then
installs the VS Code integrations. Run the steps on their own when you need to:

	DistroAgentsTools.fn.sh --install-skillset-symlinks --scope workspace
	DistroAgentsTools.fn.sh --install-skillset-symlinks --scope user-home
	DistroAgentsTools.fn.sh --install-vscode-integrations

Re-run `--install-skillset-symlinks` after adding or removing a member: it
reconciles this workspace's registered set rather than only adding to it. Remove
everything this workspace registered with `--install-skillset-symlinks --remove`.

## Adding your own team members

A workspace contributes members by declaring them in a project's `project.inf`:

	Declares: \
		magic-team:team-member:skillset/<member-name>:<host-glob> \

Put the member's own skill directory at that path, then re-run
`--install-skillset-symlinks` to register it.

## Common tasks

Tell the tooling which workspaces it may act on:

	DistroAgentsTools.fn.sh --owner-workspace-list
	DistroAgentsTools.fn.sh --owner-workspace-current
	DistroAgentsTools.fn.sh --owner-workspace-upsert /path/to/workspace
	DistroAgentsTools.fn.sh --owner-workspace-forget /path/to/workspace

Read and set a member's own configuration and credentials. Always pipe a secret
through `--upsert-from-stdin`, so it never appears in the process table:

	DistroAgentsTools.fn.sh --member-config-option <member> --select-all
	DistroAgentsTools.fn.sh --member-config-option <member> --upsert-from-stdin <key>

Check that the credential store stays locked down:

	DistroAgentsTools.fn.sh --verify-permissions
	DistroAgentsTools.fn.sh --self-test

Open and reuse a keep-alive workspace console session:

	DistroAgentsTools.fn.sh --console-start
	DistroAgentsTools.fn.sh --console-list
	DistroAgentsTools.fn.sh --console-send <channel> -- <command...>
	DistroAgentsTools.fn.sh --console-stop <channel>

See exactly which operations one member is allowed to run:

	DistroAgentsTools.fn.sh --member-help <member>

## Running the agents console

	DistroAgentsConsole.sh [--cli copilot|claude|grok] [--cli-auto] [--non-interactive] [args...]

	./DistroAgentsConsole.sh
	./DistroAgentsConsole.sh --cli claude
	./DistroAgentsConsole.sh --cli-auto
	./DistroAgentsConsole.sh --non-interactive "list the projects that changed today"
	echo "list the projects that changed today" | ./DistroAgentsConsole.sh --non-interactive

- Known CLIs, in preference order: `copilot`, `claude`, `grok`. The default is `copilot`.
- `--cli-auto` picks the first one that is actually installed.
- `--non-interactive` supports `copilot` and `claude` only. Remaining arguments are joined
  into one prompt; with none given, the prompt is read from stdin.
- With `--cli` given explicitly, a CLI missing from `PATH` is an error — no fallback.
- With no `--cli`, the console tries the default, then the rest of the known list, then falls
  back to an interactive bash session. `--non-interactive` still exits with an error there.

## Commands

- `DistroAgentsTools.fn.sh` — the team's operations interface: install, configure, message,
  read and write board items, run console sessions, drive the routine state machinery.
- `DistroAgentsConsole.sh` — start an agent CLI session against this workspace.

## Getting help

- `DistroAgentsTools.fn.sh --help` prints every operation with its full syntax.
- `DistroAgentsTools.fn.sh --member-help <member>` prints only what that member may run.
- `Agents --help` prints the agents-context dispatcher syntax.
- Press TAB after a command name and a space for shell completion.

## Related packages

- [myx.distro](https://github.com/myx/myx.distro) — the distro system overview.
- [myx.distro-.local](https://github.com/myx/myx.distro-.local) — install and launch the toolsets.
- [myx.distro-system](https://github.com/myx/myx.distro-system) — shared indexing and query tools.
- [myx.distro-source](https://github.com/myx/myx.distro-source) — build source into a distro image.
- [myx.distro-deploy](https://github.com/myx/myx.distro-deploy) — deploy a distro image to hosts.
- [myx.distro-remote](https://github.com/myx/myx.distro-remote) — drive a workspace on another machine.
