📘 syntax: DistroAgentsMail.fn.sh --email-send [--team-member <team-member>] <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>) [--format markdown|text] [--in-reply-to <message-id>] [--text-group report|brief|relay]
📘 syntax: DistroAgentsMail.fn.sh --email-mark-seen [--team-member <team-member>] <uid>
📘 syntax: DistroAgentsMail.fn.sh --email-check [--team-member <team-member>]
📘 syntax: DistroAgentsMail.fn.sh --email-read [--team-member <team-member>] <uid> [--seen]

##  Summary:

		the team's mail operations. A bare call lists the operations of the file, --help-syntax
		prints the syntax line of every operation (or of one operation, or of those
		that a prefix ending in "-" begins), and --help prints this manual.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
