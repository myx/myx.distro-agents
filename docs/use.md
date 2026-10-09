# Use

[Back to the README](../README.md)

## Common tasks

Open and reuse a keep-alive workspace console session:

	DistroAgentsTools.fn.sh --console-start
	DistroAgentsTools.fn.sh --console-list
	DistroAgentsTools.fn.sh --console-send <channel> -- <command...>
	DistroAgentsTools.fn.sh --console-stop <channel>

When you send commands into a console channel:

- Send one command per line. A `;`-joined line drops its first command without any error.
- A command that exits non-zero stops the rest of the batch. Send anything that may fail on its own.
- Two sessions on one channel write into one log. Read by line offset to tell them apart.
- A channel belongs to the workspace and the console, not to the caller. Two callers on the same
  workspace and console share one channel, and one can stop the other's session. A
  `channel_not_found`, or a console that dies while another session is active, is this case.

See exactly which operations one member is allowed to run:

	DistroAgentsTools.fn.sh --member-help <member>

## Running the agents console

The console starts an agent CLI, not a shell. A line you pipe into it is a prompt: a model reads it
and decides what to run. So even a read-only tooling call through the console costs a full model
round trip. For a read, run the tool directly instead:

	bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" <operation> ...

Keep the console for work that needs an agent session.

	DistroAgentsConsole.sh [--cli copilot|copilot-native|claude|claude-native|grok|grok-native|scaleway] [--cli-auto] [--non-interactive] [args...]

	./DistroAgentsConsole.sh
	./DistroAgentsConsole.sh --cli claude
	./DistroAgentsConsole.sh --cli-auto
	./DistroAgentsConsole.sh --non-interactive "list the projects that changed today"
	echo "list the projects that changed today" | ./DistroAgentsConsole.sh --non-interactive

- Known CLIs, in preference order: `copilot`, `copilot-native`, `claude`, `claude-native`, `grok`,
  `grok-native`, `scaleway`. That order is the fallback, used when no CLI is configured.
- A name ending in `-native` runs the vendor's own CLI. `claude`, `copilot`, `grok` and `scaleway`
  run this package's own harness against that service's API.
- `claude-native` runs the `claude` CLI already installed and signed in on this machine, using that
  existing login rather than any credential configured here.
- `grok` runs this package's own harness against xAI's API, and the vendor `grok` CLI is reached as
  `grok-native`. Configure it once with `DistroAgentsTools.fn.sh --owner-setup-grok`. It is one-shot
  only, like `scaleway` below.
- `scaleway` needs no vendor CLI installed at all — it works against Scaleway's own API, so it runs
  on a machine where nothing else is set up. Configure it once with
  `DistroAgentsTools.fn.sh --owner-setup-scaleway`. It is one-shot only: always pass
  `--non-interactive`, and it will tell you so if you forget.
- `--cli-auto` — take the configured CLI (`SPAWN_CLI_SERVICE`), or the first installed one from the
  order above when none is configured.
- `--cli <name>` — start that CLI. A CLI missing from `PATH` is an error; there is no fallback.
- No `--cli` given — the same as `--cli-auto`: the configured CLI, else the first installed one from
  the order above, else an interactive bash session. A configured CLI missing from `PATH` is an
  error, the same as naming it with `--cli`.
- `--non-interactive` — one-shot, no attached terminal.
	- Supported for `copilot`, `copilot-native`, `claude`, `claude-native`, `grok` and `scaleway`.
	  Not for `grok-native`.
	- Remaining arguments are joined into one prompt.
	- With no arguments, the prompt is read from stdin.
	- Exits with an error rather than falling back to bash when no CLI is available.


## Working with the team

[Working with The Conclave](../vscode/magic-team/instructions.md) explains how to ask the team for work: whom to address, and what to expect back.
