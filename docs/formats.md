# Formats

[Back to the README](../README.md)

## Operation names

`DistroAgentsTools.fn.sh` takes one operation as its first argument. The prefix tells you who the operation is for.

- `--install-*` — install steps, such as `--install-skillset-symlinks`.
- `--owner-*` — operations for the person who owns the installation: `--owner-setup-<domain>`, `--owner-workspace-*` and `--owner-credential-store-*`.
- `--member-*` — operations that act for or on one team member, such as `--member-help <member>`.
- `--console-*` — keep-alive console sessions.
- `--manager-*` — the reads and actions of the console's manager screen, such as `--manager-session-list`.

## Argument order

Give options and their values first, then at most one sub-operation, last. A sub-operation is a major mode such as `--check` or `--apply`. Anything after it is an error.

## Values on stdin

`--values-from-stdin` reads `KEY=value` lines from standard input. Use it for a credential, so it never appears in the process table. `--upsert-from-stdin <key>` sets one value the same way.

## Member declaration

A project declares a member in its `project.inf`, with one `Declares` entry per member:

	Declares: \
		magic-team:team-member:skillset/<member-name>:<host-glob> \

[Extension](extension.md) shows how to add one. The [project.inf manual](https://github.com/myx/myx.distro-.local/blob/main/sh-lib/help/Man.Project.Inf.file.help.md) describes the file format.

## Channel declaration

A project registers a communication channel in its `project.inf`, with one `Declares` entry per
channel. The entry names the channel, the driver that reaches it (`slack`, `email`, `telegram` or
`printback`), and that driver's address:

	Declares: \
		magic-team:comms-channel:<channel-name>:<service>:<channel-address> \

The whole workspace can then address the channel by `<channel-name>`, resolved through the
communication-channel-id abstraction (`sh-lib/comms/AgentsTools.CommsChannel.include`). Several
drivers are plugged at once and their order is the preference; a name declared on more than one
service resolves to the first driver in that order. The built-in Slack aliases (`magic-team`,
`human-owner`, `event-track`, `event-alert`) keep their `SLACK_CHANNEL_*` settings; a declared
channel only adds names beside them. `printback` is the root-native kind: its address is a session
id, its message is printed to the tool's output and recorded in that session's one chat file, and
it opens no network call.
