📘 syntax: DistroAgentsMail.fn.sh --email-send [--team-member <team-member>] <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>) [--format markdown|text] [--in-reply-to <message-id>] [--text-group report|brief|relay]
📘 syntax: DistroAgentsMail.fn.sh --email-mark-seen [--team-member <team-member>] <uid>
📘 syntax: DistroAgentsMail.fn.sh --email-check [--team-member <team-member>]
📘 syntax: DistroAgentsMail.fn.sh --email-read [--team-member <team-member>] <uid> [--seen]

##  Summary:

		the team's mail operations. A bare call prints the syntax line of each of the
		file's operations, --help-syntax prints every form of every operation (or of one
		operation, or of those that a prefix ending in "-" begins), and --help prints this
		manual.

##  Options:

		--email-send <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>)
			Sends one mail from the member's own account to each address, the subject and
			the body each behind its own `--`. `--format` chooses markdown or plain text,
			`--in-reply-to` answers a message, and `--text-group` says a report, a brief or
			a relay.

		--email-check
			Whether the member's own mailbox answers: counts that member's unread, from
			its own scope and no other, so a broken account is seen before mail is sent
			through it.

		--email-read <uid> [--seen]
			Prints one message of the INBOX, by its IMAP UID, and with `--seen` marks it
			read as it does.

		--email-mark-seen <uid>
			Marks one INBOX message read, by its IMAP UID, and says so.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
