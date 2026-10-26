📘 syntax: AgentDispatcherTools.fn.sh --advance-sleep-run
📘 syntax: AgentDispatcherTools.fn.sh --client-operation-run <magic-coordinator> --client-<operation> <client-member-name> [<argument>...]
📘 syntax: AgentDispatcherTools.fn.sh --daily-lock-refresh [--team-member <team-member>]
📘 syntax: AgentDispatcherTools.fn.sh --grooming-lock-refresh [--team-member <team-member>]
📘 syntax: AgentDispatcherTools.fn.sh --config-check
📘 syntax: AgentDispatcherTools.fn.sh --state-note-lock-acquire [--team-member <team-member>] <owner-label>
📘 syntax: AgentDispatcherTools.fn.sh --state-note-read [--team-member <team-member>]
📘 syntax: AgentDispatcherTools.fn.sh --retro-lock-refresh [--team-member <team-member>]
📘 syntax: AgentDispatcherTools.fn.sh --sweep-state-advance [--team-member <team-member>] <ts>
📘 syntax: AgentDispatcherTools.fn.sh --sweep-state-read [--team-member <team-member>]
📘 syntax: AgentDispatcherTools.fn.sh --sweep-state-upsert [--team-member <team-member>] [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: AgentDispatcherTools.fn.sh --roster-upsert [--team-member <team-member>] [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: AgentDispatcherTools.fn.sh --spawns [--team-member <team-member>] [--active|--waiting|--all]
📘 syntax: AgentDispatcherTools.fn.sh --flags [--team-member <team-member>]
📘 syntax: AgentDispatcherTools.fn.sh --tasks [--team-member <team-member>]
📘 syntax: AgentDispatcherTools.fn.sh --contacts [--team-member <team-member>] [--organisation <slug>] [--reached-by <member>]
📘 syntax: AgentDispatcherTools.fn.sh --contact [--team-member <team-member>] <id>
📘 syntax: AgentDispatcherTools.fn.sh --standing-directives [--team-member <team-member>] [--all]
📘 syntax: AgentDispatcherTools.fn.sh --directive-set [--team-member <team-member>] --text <text> --expires-at \"<YYYY-MM-DD HH:MM>\"|none [--id <id>] [--wait <seconds>]
📘 syntax: AgentDispatcherTools.fn.sh --directive-end [--team-member <team-member>] --id <id> [--wait <seconds>]
📘 syntax: AgentDispatcherTools.fn.sh --epic-update [--team-member <team-member>] <epic-file> (--set-status <feature-id> <status>|--add-settled <feature-id> [--date <YYYY-MM-DD>] [--owner <name>] <text...>)
📘 syntax: AgentDispatcherTools.fn.sh [--help-syntax [<op>]]
📘 syntax: AgentDispatcherTools.fn.sh [--help]

##  Summary:

		The duties of the coordinator: the standing locks of the routines and
		their state note, the roster, the sweep's state, the client operations of
		the other organisation, and the coordinator's own read of the team. Every
		operation here is magic-coordinator's, asked of the caller in the tool
		file before the operation runs.

##  Options:

		--advance-sleep-run
			The advance routine's sleep: five one-second loops, the count printed
			downwards, then the pass continues. Takes no argument.

		--client-operation-run <magic-coordinator> --client-<operation> <client-member-name> [<argument>...]
			The coordinator's one way to the other organisation. It gives its own
			member name first, then word for word the command line the client itself
			gives; the rest is forwarded unchanged and runs as that client.

		--config-check
			Every setting the coordinator and the team consume, each checked where it
			is consumed, a line each. Ends non-zero where a required one is missing or
			of the wrong shape.

		--state-note-lock-acquire <owner-label>
		--state-note-read
			The coordinator's state note: its lock taken for an owner label, and the
			note read as it stands.

		--daily-lock-refresh
		--grooming-lock-refresh
		--retro-lock-refresh
			The standing lock of one routine refreshed, so it does not go stale while
			the routine runs.

		--roster-upsert [--from-file <path>|--edit-patch-from-stdin]
			The team roster written whole, or patched by an edit patch.

		--sweep-state-advance <ts>
		--sweep-state-read
		--sweep-state-upsert [--from-file <path>|--edit-patch-from-stdin]
			The communication sweep's state note: its stored last_swept_ts read,
			advanced to a time, or written whole.

		--spawns [--active|--waiting|--all]
		--flags
		--tasks
			The coordinator's read of the team: the runs (active, waiting, or all),
			the worktime flags now, and the board's counts with the active items.

		--contacts [--organisation <slug>] [--reached-by <member>]
		--contact <id>
			The contacts as the coordinator reads them, a row each; `--contact` one,
			its record and its access.

		--standing-directives [--all]
			The standing directives in force: open warnings, coordinator notes, the
			human-owner's orders. `--all` includes the ones not in force.

		--directive-set --text <text> --expires-at "<YYYY-MM-DD HH:MM>"|none [--id <id>] [--wait <seconds>]
			An order entered, through the state note's lock.

		--directive-end --id <id> [--wait <seconds>]
			An order taken out.

		--epic-update <epic-file> (--set-status <feature-id> <status>|--add-settled <feature-id> [--date <YYYY-MM-DD>] [--owner <name>] <text...>)
			The epic file's own edit, so no routine edits an epic by hand: one
			feature's status set, or one settlement added.

##  Examples:

		# The runs that wait, and the board as the coordinator reads it
		`AgentDispatcherTools.fn.sh --spawns --waiting`
		`AgentDispatcherTools.fn.sh --tasks`
		# The settings every operation consumes, checked
		`AgentDispatcherTools.fn.sh --config-check`
		# An order in force for a day, then taken out
		`AgentDispatcherTools.fn.sh --directive-set --text "No deploys before the review." --expires-at "2026-10-27 09:00"`
		`AgentDispatcherTools.fn.sh --directive-end --id own-3`
		# The other organisation's own operation, run as that client
		`AgentDispatcherTools.fn.sh --client-operation-run magic-coordinator --client-comms-slack-send-message client-ndm magic-team Done.`
