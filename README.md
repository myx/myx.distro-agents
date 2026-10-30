# myx.distro-agents

The `magic-team` AI agent team, the tooling it runs on, and the installation that
wires both into a workspace.

- **The team** — `skillset/magic-team/` holds the members themselves, and the owner's own identity record beside them.
	- `magic-coordinator` — dispatch and prioritisation across the team.
	- `magic-architect` — system design and architecture review.
	- `magic-developer` — language mechanics, idiom and portability.
	- `magic-devops` — builds, deploys and fleet operations.
	- `magic-frontender` — browser-facing UI work.
	- `magic-librarian` — documentation, references, protocols and conventions.
	- `magic-tester` — test design, coverage and verification.
	- `magic-team` — the team avatar, plus team-level shared artifacts.
	- Any workspace can add its own members on top. See [Extension](docs/extension.md).
- **The tooling** — the `DistroAgents*.fn.sh` family, one file a subject: `DistroAgentsTools` for
  setup, settings and console sessions, `DistroAgentsSlack`, `DistroAgentsMail`, `DistroAgentsTrello`,
  `DistroAgentsGoogle` and `DistroAgentsAtlassian` for comms, `DistroAgentsItems` for board, inbox,
  audit and vault items, `DistroAgentsQuestions` for asks, `DistroAgentsSession` for the session's own
  thread and transcript, `DistroAgentsGrants` for permissions, `DistroAgentsTesting` for tests and the
  retest queue, `DistroAgentsDispatcher` for the team's runs, and `DistroAgentsKnowledge` for places,
  the roster and knowledge. `AgentDispatcherTools`, `AgentLibrarianTools` and `AgentTestingTools` are
  the member-facing ones. Together they are the interface the team uses for every stateful action.
- **The console** — `DistroAgentsConsole.sh`. On a terminal it opens the manager
  screen: sessions, questions, members and settings. With `--non-interactive` it
  runs one prompt through an agent CLI, so every line goes through a model; run
  `DistroAgentsTools.fn.sh` directly for read-only calls.
  See [Use](docs/use.md#running-the-agents-console).

## Getting started

After installing the toolset, run `DistroAgentsTools.fn.sh --owner-setup-claude`,
then the `--apply` command it prints. Workspace restrictions are an optional
extra step. See [Installation](docs/installation.md#getting-started).

## Documentation

- [Installation](docs/installation.md) — requirements, install, upgrade and uninstall.
- [Configuration](docs/configuration.md) — settings, profile options and configuration commands.
- [Use](docs/use.md) — getting started, common tasks and selecting what to act on.
- [Commands](docs/commands.md) — the command reference.
- [Formats](docs/formats.md) — file formats, directives, stages and folder layout.
- [Extension](docs/extension.md) — adding your own members, builders, directives and commands.
- [Examples](docs/examples.md) — worked examples from start to finish.
- [Troubleshooting](docs/troubleshooting.md) — symptoms, causes and actions.

Maintainers: see [MAGIC.md](MAGIC.md) for the decisions, conventions and gotchas behind the code.

## Getting help

- `DistroAgentsTools.fn.sh --help` — every operation, with full syntax.
- `DistroAgentsKnowledge.fn.sh --member-help <member>` — only what that member may run.
- `Agents --help` — agents-context dispatcher syntax, from inside the console.
- Press TAB after a command name and a space for shell completion.

## Related packages

- [myx.distro](https://github.com/myx/myx.distro) — the distro system overview.
- [myx.distro-.local](https://github.com/myx/myx.distro-.local) — install and launch the toolsets.
- [myx.distro-system](https://github.com/myx/myx.distro-system) — shared indexing and query tools.
- [myx.distro-source](https://github.com/myx/myx.distro-source) — build source into a distro image.
- [myx.distro-deploy](https://github.com/myx/myx.distro-deploy) — deploy a distro image to hosts.
- [myx.distro-remote](https://github.com/myx/myx.distro-remote) — drive a workspace on another machine.
