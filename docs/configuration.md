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

	DistroAgentsTools.fn.sh --member-config-option <member> --select-all
	DistroAgentsTools.fn.sh --member-config-option <member> --upsert-from-stdin <key>

Check that the credential store stays locked down:

	DistroAgentsTools.fn.sh --owner-credential-store-verify
	DistroAgentsTools.fn.sh --owner-credential-store-self-test
	DistroAgentsTools.fn.sh --owner-credential-store-harden
