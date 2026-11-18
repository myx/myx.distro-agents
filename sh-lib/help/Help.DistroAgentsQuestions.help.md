📘 syntax: DistroAgentsQuestions.fn.sh --read-escalation [--team-member <team-member>] <request-id>
📘 syntax: DistroAgentsQuestions.fn.sh --answer-escalation [--team-member <team-member>] <request-id> <verdict> [text]
📘 syntax: DistroAgentsQuestions.fn.sh --readback-escalation [--team-member <team-member>] <request-id> <option word> [text]
📘 syntax: DistroAgentsQuestions.fn.sh --forward-escalation [--team-member <team-member>] <request-id>
📘 syntax: DistroAgentsQuestions.fn.sh --read-pending-reply [--team-member <team-member>] [<pending-id>] [--all] [--any-owner] [--count]
📘 syntax: DistroAgentsQuestions.fn.sh --amend-pending-reply [--team-member <team-member>] <pending-id> --verdict <text> --reason <text>
📘 syntax: DistroAgentsQuestions.fn.sh --record-decision [--team-member <team-member>] <item-filename> --kind <clarification|resolved|dismissed> --text <one line> (--with <party> [--wait]|--readback <pending-id>) [--source <ts-or-id>] [--clears-blocker]
📘 syntax: DistroAgentsQuestions.fn.sh --record-decision [--team-member <team-member>] <item-filename> --strike <exact line text> --reason <text> (--with <party> [--wait]|--readback <pending-id>)

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

		--record-decision <item-filename> --kind <clarification|resolved|dismissed> --text <one line> (--with <party> [--wait]|--readback <pending-id>)
			One line onto that item's own Decisions, where a ruling on the work belongs.
			It lands only through its confirmed readback, on the same item: `yes` lands the text it confirmed, word for word,
			and `edit` lands the words of the edit. A `no` lands nothing. The line names who confirmed it and when. A readback lands once.
			`--with <party>` asks that readback: the text goes to the party it was made with, and their answer lands it by itself,
			whoever reads the answer and whether or not the asking run still lives. It returns at once with `DECISION-ASKED`, the
			readback joins your waits, and its answer reaches your session floor. `--wait` waits for the answer instead and ends
			with `DECISION-RECORDED` or `DECISION-NOT-RECORDED`.
			`--readback <pending-id>` records through a readback already confirmed.
			A line that tells a decision by the human-owner lands only with the message or the ask's verdict it came from,
			named in `--source`, or from a readback he confirmed.
			`--clears-blocker` clears what the line settles, with `--readback` only.

		--record-decision <item-filename> --strike <exact line text> --reason <text> (--with <party> [--wait]|--readback <pending-id>)
			Marks one of that item's recorded lines struck, with the reason and who struck it, and deletes nothing.
			Its writer, the item's owner, or magic-coordinator above them may strike it, through the readback
			that confirmed the reason. That readback is answered by the account that confirmed the line, or by
			the human-owner: a line with no confirmation behind it is struck on his confirmation alone. The
			dismissed line names that readback, so it strikes once. `--with <party>` asks it, and its yes or edit
			strikes the line by itself; a no keeps it. A strike takes no `--kind` and no `--text`.

##  Notes:

		Two operations moved, and each old name still forwards to its new place, saying so
		on stderr. `--request-permission-set` is AgentDispatcherTools.fn.sh's own, documented
		there. `--settle-pending-reply` is a session-channel operation, documented in
		DistroAgentsSession.fn.sh's manual with the rest of them.

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
