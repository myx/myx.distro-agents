📘 syntax: DistroAgentsQuestions.fn.sh --read-escalation [--team-member <team-member>] <request-id>
📘 syntax: DistroAgentsQuestions.fn.sh --answer-escalation [--team-member <team-member>] <request-id> <verdict> [text]
📘 syntax: DistroAgentsQuestions.fn.sh --readback-escalation [--team-member <team-member>] <request-id> <option word> [text]
📘 syntax: DistroAgentsQuestions.fn.sh --forward-escalation [--team-member <team-member>] <request-id>
📘 syntax: DistroAgentsQuestions.fn.sh --request-permission-set [--team-member <team-member>] <item> (--entry <tool[,tool...]:target>... [--purpose <text>])... [--scope task|session] [--session-id <id>] [--participant <member>]...
📘 syntax: DistroAgentsQuestions.fn.sh --read-pending-reply [--team-member <team-member>] [<pending-id>] [--all] [--any-owner] [--count]
📘 syntax: DistroAgentsQuestions.fn.sh --settle-pending-reply [--team-member <team-member>] <pending-id> --reason <text> [--withdraw]
📘 syntax: DistroAgentsQuestions.fn.sh --amend-pending-reply [--team-member <team-member>] <pending-id> --verdict <text> --reason <text>
📘 syntax: DistroAgentsQuestions.fn.sh --record-decision [--team-member <team-member>] <item-filename> --kind <clarification|resolved|dismissed> --text <one line> [--source <ts-or-id>] [--clears-blocker]

##  Summary:

		every ask of the team. A bare call lists the operations of the file, --help-syntax
		prints the syntax line of every operation (or of one operation, or of those
		that a prefix ending in "-" begins), and --help prints this manual.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
