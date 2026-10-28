📘 syntax: DistroAgentsGrants.fn.sh --pass-permission [--team-member <team-member>] --to <member> --tool <tool> --target <target> --kind once|session|task [--task <item>] [--session-id <id>]
📘 syntax: DistroAgentsGrants.fn.sh --list-permissions [--team-member <team-member>] [--member <member>] [--session-id <id>]
📘 syntax: DistroAgentsGrants.fn.sh --revoke-permission <ref> [--session-id <id>]

##  Summary:

		the permission registry, its management and its bookkeeping. A bare call prints the
		syntax line of each of the file's operations, --help-syntax prints every form of
		every operation (or of one operation, or of those that a prefix ending in "-"
		begins), and --help prints this manual.

##  Options:

		--list-permissions [--member <member>] [--session-id <id>]
			The permissions a member holds, one a row, as the grants index unrolled them for
			it. Another member's are magic-coordinator's to list, or the console's.

		--pass-permission --to <member> --tool <tool> --target <target> --kind once|session|task
			Grants one permission to another member and prints its reference. `once` is spent
			by the call it allows, `session` lasts that session, `task` while its board item
			is open.

		--revoke-permission <ref> [--session-id <id>]
			Withdraws a grant, by the reference `--pass-permission` printed.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
