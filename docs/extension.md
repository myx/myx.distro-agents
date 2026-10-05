# Extension

[Back to the README](../README.md)

## Adding your own team members

A workspace contributes members by declaring them in a project's `project.inf`:

	Declares: \
		magic-team:team-member:skillset/<member-name>:<host-glob> \

Put the member's own skill directory at that path, then re-run
`--install-skillset-symlinks` to register it.
