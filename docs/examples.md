# Examples

[Back to the README](../README.md)

## Set up the vendor claude CLI

A bare call reports what is missing and names the command that closes it:

	DistroAgentsTools.fn.sh --owner-setup-claude-native

Carry the setup out:

	DistroAgentsTools.fn.sh --owner-setup-claude-native --apply

Sign in once with `claude auth login`. Every workspace on the machine then uses that sign-in.

## Store a secret without exposing it

	DistroAgentsTools.fn.sh --member-config-option <member> --upsert-from-stdin <key>

## Run one prompt without a session

	./DistroAgentsConsole.sh --non-interactive "list the projects that changed today"
	echo "list the projects that changed today" | ./DistroAgentsConsole.sh --non-interactive

## Open and use a keep-alive console session

	DistroAgentsTools.fn.sh --console-start
	DistroAgentsTools.fn.sh --console-list
	DistroAgentsTools.fn.sh --console-send <channel> -- <command...>
	DistroAgentsTools.fn.sh --console-stop <channel>
