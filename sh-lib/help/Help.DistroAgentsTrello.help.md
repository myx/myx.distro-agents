📘 syntax: DistroAgentsTrello.fn.sh --trello-post-comment [--team-member <team-member>] <card-id> [<text...>|--from-stdin|--from-file <path>]
📘 syntax: DistroAgentsTrello.fn.sh --trello-check [--team-member <team-member>]
📘 syntax: DistroAgentsTrello.fn.sh --trello-read [--team-member <team-member>] <notification-id>
📘 syntax: DistroAgentsTrello.fn.sh --trello-whoami [--team-member <team-member>]

##  Summary:

		the team's Trello operations. A bare call prints the syntax line of each of the
		file's operations, --help-syntax prints every form of every operation (or of one
		operation, or of those that a prefix ending in "-" begins), and --help prints this
		manual.

##  Options:

		--trello-check
			Checks that the member's own Trello credentials answer: reads the unread
			notifications of its own account, and fails loudly where they do not, so an
			empty answer is never taken for none.

		--trello-read <notification-id>
			Prints one notification of that account, as Trello wrote it.

		--trello-whoami
			Prints the Trello account the member's credentials belong to.

		--trello-post-comment <card-id> [<text...>|--from-stdin|--from-file <path>]
			Posts one comment on that card, under the member's own Trello identity.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
