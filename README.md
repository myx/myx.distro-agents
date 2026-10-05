# myx.distro-agents

The `magic-team` AI agent team, the tooling it runs on, and the installation that
wires both into a workspace.

- **The team** — `skillset/magic-team/` holds the members themselves.
	- `magic-coordinator` — dispatch and prioritisation across the team.
	- `magic-architect` — system design and architecture review.
	- `magic-developer` — language mechanics, idiom and portability.
	- `magic-devops` — builds, deploys and fleet operations.
	- `magic-frontender` — browser-facing UI work.
	- `magic-librarian` — documentation, references, protocols and conventions.
	- `magic-tester` — test design, coverage and verification.
	- `magic-team` — the team avatar, plus team-level shared artifacts.
	- Any workspace can add its own members on top. See [Extension](docs/extension.md).
- **The tooling** — `DistroAgentsTools.fn.sh`, the single interface the team uses
  for every stateful action: Slack, email and Trello messaging; board and inbox
  items; per-member credentials; keep-alive console sessions; and the state
  machinery the team's routines run on.
- **The console** — `DistroAgentsConsole.sh`, which starts an agent CLI session
  against the workspace instead of a bash shell.

## Documentation

- [Installation](docs/installation.md) — requirements, install, upgrade and uninstall.
- [Configuration](docs/configuration.md) — settings, profile options and configuration commands.
- [Use](docs/use.md) — getting started, common tasks and selecting what to act on.
- [Commands](docs/commands.md) — the command reference.
- [Formats](docs/formats.md) — file formats, directives, stages and folder layout.
- [Extension](docs/extension.md) — adding your own members, builders, directives and commands.
- [Examples](docs/examples.md) — worked examples from start to finish.
- [Troubleshooting](docs/troubleshooting.md) — symptoms, causes and actions.

## Getting help

- `DistroAgentsTools.fn.sh --help` — every operation, with full syntax.
- `DistroAgentsTools.fn.sh --member-help <member>` — only what that member may run.
- `Agents --help` — agents-context dispatcher syntax, from inside the console.
- Press TAB after a command name and a space for shell completion.

## Related packages

- [myx.distro](https://github.com/myx/myx.distro) — the distro system overview.
- [myx.distro-.local](https://github.com/myx/myx.distro-.local) — install and launch the toolsets.
- [myx.distro-system](https://github.com/myx/myx.distro-system) — shared indexing and query tools.
- [myx.distro-source](https://github.com/myx/myx.distro-source) — build source into a distro image.
- [myx.distro-deploy](https://github.com/myx/myx.distro-deploy) — deploy a distro image to hosts.
- [myx.distro-remote](https://github.com/myx/myx.distro-remote) — drive a workspace on another machine.
