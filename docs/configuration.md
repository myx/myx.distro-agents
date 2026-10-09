# Configuration

[Back to the README](../README.md)

## Workspaces, members and credentials

Tell the tooling which workspaces it may act on:

	DistroAgentsTools.fn.sh --owner-workspace-list
	DistroAgentsTools.fn.sh --owner-workspace-current
	DistroAgentsTools.fn.sh --owner-workspace-upsert /path/to/workspace
	DistroAgentsTools.fn.sh --owner-workspace-forget /path/to/workspace

Read and set a member's own configuration and credentials. Always pipe a secret
through `--upsert-from-stdin`, so it never appears in the process table:

	DistroAgentsTools.fn.sh --agents-config-option <member> --select-all
	DistroAgentsTools.fn.sh --agents-config-option <member> --upsert-from-stdin <key>

Check that the credential store stays locked down:

	DistroAgentsTools.fn.sh --owner-credential-store-verify
	DistroAgentsTools.fn.sh --owner-credential-store-self-test
	DistroAgentsTools.fn.sh --owner-credential-store-harden


## How settings behave

- A setting is read when a call needs it. A changed value is in force on the next spawn. Nothing is regenerated and nothing needs a reinstall.
- A read never creates a member's configuration. A write does.
- A mistyped or missing sub-command can create an empty configuration before it reports the error. That empty entry then looks like a configured member.
- Read with `DistroAgentsTools.fn.sh --agents-config-option <member> --select-all`. Look for the key you need, not only for the member.
- Check that the member exists before the first configuration call.

## Remove a setting

Two forms remove a setting, and they mean the same request:

- `KEY=` in a `--values-from-stdin` set.
- `--<option> ""` on the command line.

The tool answers "removed" or "is not set". It refuses to remove a key that the domain requires.

## Where team data lives

When `TEAM_DATA_DIRECTORY` is unset, the workspace uses its own hidden team data store. Set the key only to share team data between workspaces. Every check reports the unset key as fine, and shows the store it resolved.

## Register the MCP servers

`--install-vscode-integrations` registers this workspace's tooling in this workspace's own configuration. It never writes into another workspace's configuration. To register elsewhere, run the tool from there.

- VS Code and Copilot Chat read `.vscode/mcp.json`, under `servers`.
- Claude Code and the Copilot CLI read `.mcp.json`, under `mcpServers`. Claude Code does not read `.vscode/mcp.json`.
- The user-level `projects["<directory>"].mcpServers` entry is keyed by the exact directory. A session opened at a different depth sees no server.
- The `myx.common` entry points at the workspace's own installed copy. A workspace without that copy gets no entry, and the install reports an error.
