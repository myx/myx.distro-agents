📘 syntax: DistroAgentsContacts.fn.sh --send-contact-digest [--team-member <team-member>] [<origin team-member>] (--resolved|--needs-ruling) <text...>
📘 syntax: DistroAgentsContacts.fn.sh --collect-contact [--team-member <team-member>] --id <slug> [--name <text>] [--organisation <slug>] [--role <text>] [--relationship <text>] [--how-to-meet <text>] [--language <word>] [--owner yes|no] [--tier tier-moot|tier-contact|tier-client|tier-admin|tier-owner] [--scope-tier <scope>=<tier>]... [--slack <team>:<id>]... [--slack-handle <team>:@<handle>]... [--slack-conversation <team>:<id>]... [--email <address>]... [--drop <coordinate>]... [--note <text>] [--correct]
📘 syntax: DistroAgentsContacts.fn.sh --collect-organisation [--team-member <team-member>] --id <slug> [--name <text>] [--domain <text>] [--note <text>] [--correct]
📘 syntax: DistroAgentsContacts.fn.sh --find-contact [--team-member <team-member>] <value> [--team <scope>] [--reached-by <member>] [--scope <scope>[=<tier>]]
📘 syntax: DistroAgentsContacts.fn.sh --all-contacts [--team-member <team-member>] [--organisation <slug>] [--reached-by <member>] [--scope <scope>[=<tier>]]
📘 syntax: DistroAgentsContacts.fn.sh --all-organisations [--team-member <team-member>]
📘 syntax: DistroAgentsContacts.fn.sh --contact-record [--team-member <team-member>] <id>
📘 syntax: DistroAgentsContacts.fn.sh --contacted-by [--team-member <team-member>] <value> [--team <scope>] [--slack-team <team>]
📘 syntax: DistroAgentsContacts.fn.sh --reach-contact [--team-member <team-member>] <id>
📘 syntax: DistroAgentsContacts.fn.sh --contact-access [--team-member <team-member>] <id> [--tool <tool> --target <target>] [--session-id <id>]
📘 syntax: DistroAgentsContacts.fn.sh --escalate-contact [--team-member <team-member>] <id> --tool <tool> --target <target> --asked <text> [--session-id <id>]
📘 syntax: DistroAgentsContacts.fn.sh --allow-contact [--team-member <team-member>] <id> --session-id <id> --refusal-id <id> --kind session|contact
📘 syntax: DistroAgentsContacts.fn.sh [--help-syntax [<op>]]
📘 syntax: DistroAgentsContacts.fn.sh [--help]

##  Summary:

		The people subsystem: the contacts and the organisations of the team,
		recorded once and filled as they are met, and what a contact asks for and
		holds. A contact is a person or a role outside the team whose record
		says how to reach it and what it may ask for; the access operations
		answer with the permission model's own words.

##  Options:

		--send-contact-digest [<origin team-member>] (--resolved|--needs-ruling) <text...>
			One digest of the contacts' open questions into the contacts' channel,
			said as resolved or as needing the human-owner's ruling.

		--collect-contact --id <slug> [--name <text>] [--organisation <slug>] [--role <text>] [--relationship <text>] [--how-to-meet <text>] [--language <word>] [--owner yes|no] [--tier tier-moot|tier-contact|tier-client|tier-admin|tier-owner] [--scope-tier <scope>=<tier>]... [--slack <team>:<id>]... [--slack-handle <team>:@<handle>]... [--slack-conversation <team>:<id>]... [--email <address>]... [--drop <coordinate>]... [--note <text>] [--correct]
			A contact recorded, or filled where it is recorded already. The calling
			member is added to who holds it. A coordinate is dropped with
			`--drop`, and `--correct` says the record was wrong rather than merely
			incomplete. `--tier` is the human-owner's alone: `tier-moot`,
			`tier-contact`, `tier-client`, `tier-admin` or `tier-owner`, lowest first,
			each including the tiers below it. The old words `ingest`, `basic`,
			`partner` and `recorded` are read as `tier-moot`, `tier-contact`,
			`tier-client` and `tier-admin`. A value that is none of them is refused. A member's `--tier` call writes nothing:
			it asks him once, in his own conversation, naming the contact and the
			tier it proposes, and prints `ASKED <contact> <tier> <ask>`. His word is
			what the record takes, and the action his answer runs is that same call.
			`--scope-tier <scope>=<tier>` gives the contact a tier for one project,
			product or team scope, as `rmm2=tier-client`, and is repeated for more
			scopes. It is the human-owner's to set, as `--tier` is: a member's call
			(one scope a call) writes nothing, asks him once for that scope and prints
			`ASKED <contact> <scope>=<tier> <ask>`; his word, used once, is the scope's
			tier. A contact of an
			organisation, given no tier, holds `tier-contact` at once, without an ask.
			`--contacted-by <value> --team <scope>` reads the tier of that scope.

		--collect-organisation --id <slug> [--name <text>] [--domain <text>] [--note <text>] [--correct]
			An organisation recorded, or filled where it is recorded already.

		--find-contact <value> [--team <scope>] [--reached-by <member>] [--scope <scope>[=<tier>]]
			The contacts a value names, a row each, the last field the contact's scope tiers; rc 1 with none. --scope keeps the contacts holding that scope tier.

		--all-contacts [--organisation <slug>] [--reached-by <member>] [--scope <scope>[=<tier>]]
		--all-organisations
			Every contact, or every organisation, a row each; the contacts narrow to
			one organisation or to those a member reaches.

		--contact-record <id>
			One contact's record, whole.

		--contacted-by <value> [--team <scope>] [--slack-team <team>]
			Being contacted: the sender looked up, its record, what it holds, the
			tier's whole rules and the next step. The rules are the tier the
			record holds for `--team`'s scope, else the record's own `tier:`, and
			every tier below it, and the five tiers as they stand where the record
			sets none. `--slack-team` narrows the lookup to one Slack workspace, as
			`--find-contact` does.

		--reach-contact <id>
			Reaching one contact: its coordinates by channel, how to meet it, and the
			send lines.

		--contact-access <id> [--tool <tool> --target <target>] [--session-id <id>]
			The permission model's answer for a call a contact makes, or, with no
			tool, what the contact holds standing.

		--escalate-contact <id> --tool <tool> --target <target> --asked <text> [--session-id <id>]
			What the contact asks for and holds no access to: the refusal is recorded
			for the contact, and the call that asks the human-owner is printed.

		--allow-contact <id> --session-id <id> --refusal-id <id> --kind session|contact
			A member gives the contact what the member holds: a stub over grant-open,
			signed by the member, for one session or for the contact.

##  Examples:

		# Record a contact once, then find it by an address it answered from
		`DistroAgentsContacts.fn.sh --collect-contact --id ada --name "Ada Lovelace" --email ada@example.com`
		`DistroAgentsContacts.fn.sh --find-contact ada@example.com`
		# One record, and how to reach it
		`DistroAgentsContacts.fn.sh --contact-record ada`
		`DistroAgentsContacts.fn.sh --reach-contact ada`
		# What it holds standing, then what it asks for and does not hold
		`DistroAgentsContacts.fn.sh --contact-access ada`
		`DistroAgentsContacts.fn.sh --escalate-contact ada --tool Slack --target magic-team --asked "Please post the summary."`
