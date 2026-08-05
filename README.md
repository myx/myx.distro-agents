# myx.distro-agents

Starts an AI-agent CLI console (`claude` or `copilot`) against a myx.distro workspace,
instead of a bash session. Provides `DistroAgentsConsole.sh` (workspace root) and its
own workspace integration (Command Palette entry), installed/updated the same way as
`DistroLocalConsole.sh` / `DistroSourceConsole.sh` / `DistroDeployConsole.sh` /
`DistroRemoteConsole.sh` are.

Not to be confused with `DistroAgentsTools.fn.sh` (owned by `myx.distro-agents`) --
that is the unrelated magic-* team automation tool (Slack/email/board/console-session
ops). This package owns only the console launcher script and its own install/Command
Palette wiring.

---

## Console command:

	DistroAgentsConsole.sh [--cli claude|copilot] [--non-interactive] [args...]

- Default (no flags): harness-interactive mode -- starts a real interactive
  `claude`/`copilot` CLI session when the default CLI is available; otherwise,
  falls back to an interactive bash console where the CLI can be started
  manually.
- `--non-interactive`: headless-terminal mode -- one-shot, no attached TTY. Remaining
  arguments are joined into a single prompt string; with none given, the CLI reads its
  prompt from stdin (same "pipe stdin through" shape the sibling consoles use for their
  own `--non-interactive`).
- `--cli claude|copilot`: which CLI to start. Default: `claude`.
- `--cli` given explicitly: starts that CLI or exits with an error if it is not on
  `PATH`.
- `--cli` not given: defaults to `claude`; if it is not on `PATH`, the console falls
  back to an interactive bash session. `--non-interactive` still exits with an error
  in that case.

---

## Variables (context environment):

	MMDAPP - workspace root (something like: "/Volumes/ws-2017/myx-work")
	MDLT_ORIGIN - source of system console commands (something like: "/Volumes/ws-2017/myx-work/.local/")
	MDSC_DETAIL - debug settings, values: <empty>, "true", "full"

---

## Distro components:

See: [distro](https://github.com/myx/myx.distro?tab=readme-ov-file#myxdistro)
See: [distro-.local](https://github.com/myx/myx.distro-.local?tab=readme-ov-file#myxdistro-.local)
See: [distro-system](https://github.com/myx/myx.distro-system?tab=readme-ov-file#myxdistro-system)
See: [distro-deploy](https://github.com/myx/myx.distro-deploy?tab=readme-ov-file#myxdistro-deploy)
See: [distro-source](https://github.com/myx/myx.distro-source?tab=readme-ov-file#myxdistro-source)
See: [distro-remote](https://github.com/myx/myx.distro-remote?tab=readme-ov-file#myxdistro-remote)
See: [distro-agents](https://github.com/myx/myx.distro-agents?tab=readme-ov-file#myxdistro-agents)# myx.distro-agents
