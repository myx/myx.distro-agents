# Troubleshooting

[Back to the README](../README.md)

## A read-only call through the console is slow and costs credits

`DistroAgentsConsole.sh` starts an agent CLI. A line piped into it arrives as a prompt, so a model reads it and decides whether to run it. Every call through it costs a full model round trip, even a plain read. See [Running the agents console](use.md#running-the-agents-console).

For anything read-only, run the script directly:

	bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" <operation> ...

Keep the console for work that needs an agent session. Whether a write operation is just as safe by this path is not established.

## Underscores are missing from --help output

The help renderer drops an underscore wherever it appears. `ANTHROPIC_API_KEY` prints as `ANTHROPICAPIKEY`.

Read the manual file itself, or use `--help-setup-<domain>`, which prints the setup manual as it is.

## A setup call asks for something I did not expect

A bare `--owner-setup-<domain>` call names only the required options that are still unset. It prints one command, `--apply`, and adds `--set-as-default` where a selection must be repointed. Use `--print-apply-command` to see every option.

## A setting will not clear

Pass it with an empty value. See [Configuration](configuration.md) for the two forms. The tool refuses to remove a key that the domain requires.

## A member is configured that I never set up

A mistyped or missing sub-command can create an empty configuration before it reports the error. [Configuration](configuration.md) explains how to tell it from a real one.

## The agent host does not see a registered MCP server

- A registration change takes effect only when the host restarts.
- A `.mcp.json` entry also waits for your own trust prompt.
- A host starts its server once per session. Workspace variables arrive unset, and the working directory is the host's project directory, not the workspace root.
- A session opened at a different directory depth sees no server. The user-level entry is keyed by the exact directory.

## A member link points at a second copy

`--install-skillset-symlinks` keeps an existing link as it is, whatever it points at. Re-running it never moves one. Correct the link yourself.

## A claude-native spawn reports cli-not-authenticated

The machine is signed out of `claude`, and no key is configured. Sign in with `claude auth login`, or store `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` in the magic-team scope.

- A signed-in machine never uses a configured key. Claude Code prefers a key over a sign-in, and that would move spawns onto API billing.
- A signed-out machine uses the first configured key, for `--non-interactive` runs only, and says which one.
- An interactive console is only warned. Sign in there with `/login`.

## The hooks or permission rules I expected are not there

Workspace restrictions are optional, and nothing installs them for you. Run `--install-workspace-restrictions` once. See [Workspace restrictions](installation.md#workspace-restrictions-optional).

## An agent CLI is missing

A CLI missing from `PATH` is an error, whether you name it with `--cli` or configure it. There is no fallback. `scaleway` and `grok` are one-shot: pass `--non-interactive`.
