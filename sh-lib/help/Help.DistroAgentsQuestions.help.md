📘 syntax: DistroAgentsQuestions.fn.sh --read-escalation [--team-member <team-member>] <request-id>
📘 syntax: DistroAgentsQuestions.fn.sh --answer-escalation [--team-member <team-member>] <request-id> <verdict> [text]
📘 syntax: DistroAgentsQuestions.fn.sh --readback-escalation [--team-member <team-member>] <request-id> <option word> [text]
📘 syntax: DistroAgentsQuestions.fn.sh --forward-escalation [--team-member <team-member>] <request-id>
📘 syntax: DistroAgentsQuestions.fn.sh --read-pending-reply [--team-member <team-member>] [<pending-id>] [--all] [--any-owner] [--count]
📘 syntax: DistroAgentsQuestions.fn.sh --amend-pending-reply [--team-member <team-member>] <pending-id> --verdict <text> --reason <text>
📘 syntax: DistroAgentsQuestions.fn.sh --record-decision [--team-member <team-member>] <item-filename> --kind <clarification|resolved|dismissed> --text <one line> [--source <ts-or-id>] [--clears-blocker]

##  Summary:

		every ask of the team. A bare call prints the syntax line of each of the file's
		operations, --help-syntax prints every form of every operation (or of one
		operation, or of those that a prefix ending in "-" begins), and --help prints
		this manual.

##  Options:

		--read-escalation <request-id>
			Prints one question as it waits: its kind, what it asks, its options and the
			accounts that may answer it.

		--answer-escalation <request-id> <verdict> [text]
			Gives that question its verdict, with the answerer's own words where there are
			some, and closes it as answered.

		--readback-escalation <request-id> <option word> [text]
			Closes a question whose reply named none of its options, with the asker's readback
			of what that reply meant.

		--forward-escalation <request-id>
			Passes a waiting question up the ladder, to whoever its asker's chain names next.

		--read-pending-reply [<pending-id>] [--all] [--any-owner] [--count]
			One question as it waits, by its id. With no id, the caller's own open ones, then
			their number: `--all` adds the closed ones, `--any-owner` every member's, and
			`--count` prints the number alone.

		--amend-pending-reply <pending-id> --verdict <text> --reason <text>
			Amends the verdict a question already closed with, and keeps the reason beside it.

		--record-decision <item-filename> --kind <clarification|resolved|dismissed> --text <one line>
			One line onto that item's own Decisions, where a ruling on the work belongs.
			`--clears-blocker` clears what the line settles.

##  Notes:

		Two operations moved, and each old name still forwards to its new place, saying so
		on stderr. `--request-permission-set` is AgentDispatcherTools.fn.sh's own, documented
		there. `--settle-pending-reply` is a session-channel operation, documented in
		DistroAgentsSession.fn.sh's manual with the rest of them.

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
