📘 syntax: DistroAgentsQuestions.fn.sh --read-escalation [--team-member <team-member>] <request-id>
📘 syntax: DistroAgentsQuestions.fn.sh --answer-escalation [--team-member <team-member>] <request-id> <verdict> [text]
📘 syntax: DistroAgentsQuestions.fn.sh --readback-escalation [--team-member <team-member>] <request-id> <option word> [text]
📘 syntax: DistroAgentsQuestions.fn.sh --forward-escalation [--team-member <team-member>] <request-id>
📘 syntax: DistroAgentsQuestions.fn.sh --read-pending-reply [--team-member <team-member>] [<pending-id>] [--all] [--any-owner] [--count]
📘 syntax: DistroAgentsQuestions.fn.sh --amend-pending-reply [--team-member <team-member>] <pending-id> --verdict <text> --reason <text>
📘 syntax: DistroAgentsQuestions.fn.sh --reconcile-answered-status [--team-member <team-member>] [--apply]
📘 syntax: DistroAgentsQuestions.fn.sh --record-decision [--team-member <team-member>] <item-filename> --kind <clarification|resolved|dismissed> --text <one line> (--with <party> [--wait]|--readback <pending-id>) [--source <ts-or-id>] [--clears-blocker]
📘 syntax: DistroAgentsQuestions.fn.sh --record-decision [--team-member <team-member>] <item-filename> --strike <exact line text> --reason <text> (--with <party> [--wait]|--readback <pending-id>)
📘 syntax: DistroAgentsQuestions.fn.sh --record-decision [--team-member <team-member>] <item-filename> --review --with <party> [--wait]

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

		--reconcile-answered-status [--apply]
			Lists the open items whose `status:` or `condition:` names a question already
			answered, by its id or the id's first eight characters, and whose status lacks that
			answer: one `STATUS-STALE <item> <state> <pending-id>` line each, or `STATUS-NONE`.
			It writes nothing. `--apply` appends `<pending-id> answered <verdict> by <who> at
			<time>` to each one's status, and prints `STATUS-ANSWERED` lines instead. Only
			magic-coordinator may apply it. A close with a verdict appends the same line by itself,
			to the ask's own item and to every open item that names it so.

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

		--record-decision <item-filename> --review --with <party> [--wait]
			Reads back every unconfirmed line of that item's own Decisions as one numbered list. An unconfirmed
			line is a clarification, resolved or dismissed line with no confirmed readback behind it, neither
			struck nor confirmed. Each line carries a proposed action: confirm where its source shows an answered
			or settled ask, re-ask where it shows a withdrawn one, and prune otherwise. `yes` applies the list,
			`edit: 3 confirm, 5 prune` changes the lines it names, and `no` changes nothing. Confirm marks the
			line confirmed, naming who and when. Prune strikes it. Re-ask strikes it and asks its text again of
			the party, through `--with`. An answer from one who is not the human-owner and holds no tier-admin
			or tier-owner over the item sends the list up to the human-owner. The item's owner or magic-coordinator
			starts it. With no unconfirmed line it prints `DECISION-REVIEW-NONE` and asks nothing.

##  Notes:

		Two operations moved, and each old name still forwards to its new place, saying so
		on stderr. `--request-permission-set` is AgentDispatcherTools.fn.sh's own, documented
		there. `--settle-pending-reply` is a session-channel operation, documented in
		DistroAgentsSession.fn.sh's manual with the rest of them.

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
