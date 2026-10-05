# Formats

[Back to the README](../README.md)

## Operation names

`DistroAgentsTools.fn.sh` takes one operation as its first argument. The prefix tells you who the operation is for.

- `--install-*` — install steps, such as `--install-skillset-symlinks`.
- `--owner-*` — operations for the person who owns the installation: `--owner-setup-<domain>`, `--owner-workspace-*` and `--owner-credential-store-*`.
- `--member-*` — operations that act for or on one team member, such as `--member-config-option <member>` and `--member-help <member>`.
- `--console-*` — keep-alive console sessions.

## Argument order

Give options and their values first, then at most one sub-operation, last. A sub-operation is a major mode such as `--check` or `--apply`. Anything after it is an error.

## Values on stdin

`--values-from-stdin` reads `KEY=value` lines from standard input. Use it for a credential, so it never appears in the process table. `--upsert-from-stdin <key>` sets one value the same way.

## Member declaration

A project declares a member in its `project.inf`, with one `Declares` entry per member:

	Declares: \
		magic-team:team-member:skillset/<member-name>:<host-glob> \

[Extension](extension.md) shows how to add one. The [project.inf manual](https://github.com/myx/myx.distro-.local/blob/main/sh-lib/help/Man.Project.Inf.file.help.md) describes the file format.
