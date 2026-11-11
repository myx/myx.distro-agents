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
📘 syntax: AgentDispatcherTools.fn.sh --sweep-state-upsert [--team-member <team-member>] [--edit-patch-from-stdin|--from-file <path>]
📘 syntax: AgentDispatcherTools.fn.sh --roster-upsert [--team-member <team-member>] [--edit-patch-from-stdin|--from-file <path>]
📘 syntax: AgentDispatcherTools.fn.sh --spawns [--team-member <team-member>] [--active|--waiting|--all]
📘 syntax: AgentDispatcherTools.fn.sh --flags [--team-member <team-member>]
📘 syntax: AgentDispatcherTools.fn.sh --tasks [--team-member <team-member>]
📘 syntax: AgentDispatcherTools.fn.sh --contacts [--team-member <team-member>] [--organisation <slug>] [--reached-by <member>]
📘 syntax: AgentDispatcherTools.fn.sh --contact [--team-member <team-member>] <id>
📘 syntax: AgentDispatcherTools.fn.sh --standing-directives [--team-member <team-member>] [--all]
📘 syntax: AgentDispatcherTools.fn.sh --directive-set [--team-member <team-member>] --text <text> --expires-at \"<YYYY-MM-DD HH:MM>\"|none [--id <id>] [--wait <seconds>]
📘 syntax: AgentDispatcherTools.fn.sh --directive-end [--team-member <team-member>] --id <id> [--wait <seconds>]
📘 syntax: AgentDispatcherTools.fn.sh --epic-update [--team-member <team-member>] <epic-file|epic-item> (--set-status <feature-id> <status>|--add-settled <feature-id> <text...>)
📘 syntax: AgentDispatcherTools.fn.sh --epic-read <epic-file|epic-item> [--feature <feature-id>]
📘 syntax: AgentDispatcherTools.fn.sh --epic-list [<folder>]
📘 syntax: AgentDispatcherTools.fn.sh --request-permission-set [--team-member <team-member>] <item> (--entry <tool[,tool...]:target>... [--purpose <text>])... [--scope task|session] [--session-id <id>] [--participant <member>]...
📘 syntax: AgentDispatcherTools.fn.sh --spawn-run [--select-workspace <place-name>] (--routine <selector>|--routine-default) [<DistroAgentsDispatcher.fn.sh --spawn-session options>]
📘 syntax: AgentDispatcherTools.fn.sh --supervise-scan [--workspace <path>]... [--since <epoch>]
📘 syntax: AgentDispatcherTools.fn.sh --supervise-resume [--workspace <path>]...
📘 syntax: AgentDispatcherTools.fn.sh --supervise-read <run-id> [--tail <lines>] [--thread-lines <lines>] [--no-thread] [--no-checklist] [--log] [--workspace <path>]
📘 syntax: AgentDispatcherTools.fn.sh --supervise-guide <run-id> [--text <text>|--from-file <path>] [--workspace <path>]
📘 syntax: AgentDispatcherTools.fn.sh --supervise-checklist-add <run-id> (--item <text>)... [--workspace <path>]
📘 syntax: AgentDispatcherTools.fn.sh --supervise-fault <run-id> --owner <member> --title <one line> [--from-file <path>] [--workspace <path>]
📘 syntax: AgentDispatcherTools.fn.sh --supervise-close-orphans [--execute] [--workspace <path>]...
📘 syntax: AgentDispatcherTools.fn.sh --supervise-copy <from-run-id> <source-path> <to-run-id> <destination-path>
📘 syntax: AgentDispatcherTools.fn.sh --supervise-commit-transcripts [--dry-run]
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

		--roster-upsert [--edit-patch-from-stdin|--from-file <path>]
			The team roster written whole, or patched by an edit patch.

		--sweep-state-advance <ts>
		--sweep-state-read
		--sweep-state-upsert [--edit-patch-from-stdin|--from-file <path>]
			The communication sweep's state note: its stored last_swept_ts read,
			advanced to a time, or written whole.

		--spawns [--active|--waiting|--all]
		--flags
		--tasks
			The coordinator's read of the team: the runs (active, waiting, or all),
			the worktime flags now, and the board's counts with the active items.

		--request-permission-set <item> (--entry <tool[,tool...]:target>... [--purpose <text>])...
			Asks the human-owner for one permission set covering a whole task or session: one
			post for every place and tool it needs, answered once.

		--spawn-run [--select-workspace <place-name>] (--routine <selector>|--routine-default) [<--spawn-session options>]
			One session spawned, handed whole to DistroAgentsDispatcher.fn.sh
			--spawn-session. A root-harness session (the one RootSession minted) spawns
			only, and each call names its place: a name the places API resolves,
			listed by --manager-place-list, never a path; a spawn without one, or naming
			one that does not resolve, is refused. The coordinator's own spawn takes
			--select-workspace as an option (the workspace it is in is implied).

		--contacts [--organisation <slug>] [--reached-by <member>]
		--contact <id>
			The contacts as the coordinator reads them, a row each; `--contact` one,
			its record and its access.

		--standing-directives [--all]
		--directive-set --text <text> --expires-at "<YYYY-MM-DD HH:MM>"|none [--id <id>] [--wait <seconds>]
		--directive-end --id <id> [--wait <seconds>]
			Stubs of the same operations of DistroAgentsSession.fn.sh, the
			ThisSession tool, which owns the standing directives.

		--epic-update <epic-file|epic-item> (--set-status <feature-id> <status>|--add-settled <feature-id> <text...>)
			The epic's own edit, so no routine edits an epic by hand: one
			feature's status set, or one settlement added. A settlement stands
			after the feature's `Status:` line, or before its next heading where
			the feature has no `Status:` line, as the rule alone: no date and no
			owner. A status of `done` closes the feature: its own lines leave, and
			one line joins `## Done`, its id and what holds now. A vault epic blueprint item
			(`epic-blueprint-<date>-<matter>.md`) is written through `--upsert-vault-epic-blueprint`, so
			its contract check and its commit both happen there.

		--epic-read <epic-file|epic-item> [--feature <feature-id>]
		--epic-list [<folder>]
			The epic read through the tooling, for any member: the epic whole, or
			one feature's section down to the next heading; and the epics, the
			vault's own items or the `*.epic.md` files of a folder, a line each
			with its section count. A path must lie under a `todo-sketchpad`
			folder and have no `..` part; one outside is an error, never an empty
			result.

		--supervise-scan [--workspace <path>]... [--since <epoch>]
			The supervisor's read of the rigs, one line a finding, for each
			workspace named, else this one. With no finding it prints one
			line, `none - - no finding: nothing needs a coordinator's hand`. Its kinds:
			`rig-orphan` (a control thread inside a run's output folder, a test rig,
			alive after that run's record closed), `ask`, `unposted`,
			`orphan-ask`, `parent-ask` (an open question to the owner whose asking
			run's parent is a live coordinator's, so the parent can settle it),
			`msg`, `track`, `dead`, `run` (where each live run stands, with its
			verdict active, waiting or stuck), `stall` (a run silent past the
			bound with items still pending on its own CheckList), `idle-done`,
			`no-plan`, `stale-plan` and `control-stuck`. A run's age is its own
			activity mark, else its transcript's last tool line, never a file's
			date. The bound is `MDAT_SUPERVISE_STALL_SECONDS`, 600 by default.

		--supervise-resume [--workspace <path>]...
			The runs that ended with no handback, resumed once the fixed sleep
			has passed, one line a run: `resumed` with its item and how it was
			started, or `held` with why. It leaves alone a run still open, one the
			owner dismissed, one that ended inside the sleep, a work-duty run (the
			scheduler's own case) and an item waiting for its reviewer. The sleep
			is `SUPERVISE_RESUME_SECONDS`, else `DUTY_RESTART_SECONDS`, else 300.

		--supervise-read <run-id> [--tail <lines>] [--thread-lines <lines>] [--no-thread] [--no-checklist] [--log] [--workspace <path>]
			A run of another workspace is read with `--workspace <path>`, as the scan reads
			the workspaces it is given. The same option stands on --supervise-guide,
			--supervise-checklist-add and --supervise-fault. A workspace this machine does
			not know is refused, and nothing is done.
			One run read by its id, as its supervisor reads it, one section a row:
			`run` the record's member, session, status and liveness; `transcript`
			and its last `--tail` lines (40); `thread` and its last
			`--thread-lines` messages (30); `checklist` and its items; and with
			`--log` the session log. A `-` column says the run keeps none of it.
			`--no-thread` and `--no-checklist` leave a section out, for a run whose
			sections are not wanted. The console's own --manager-session-* reads
			are refused to a member's session, and a supervisor is one.

		--supervise-guide <run-id> [--text <text>|--from-file <path>] [--workspace <path>]
			Guidance posted into that run's session thread, as magic-coordinator,
			addressed to its member. A run with no thread takes the message in its
			session chat file. The text is the standard input where neither
			option gives it; an empty one is refused.

		--supervise-checklist-add <run-id> (--item <text>)... [--workspace <path>]
			Pending items added at the end of that run's own CheckList, under the
			list's own lock, and noted in `<member>.checklist.md.added` so the
			member's next whole-list write keeps them. `CheckList append` does the
			same for a session the caller started; a supervisor founds none.

		--supervise-fault <run-id> --owner <member> --title <one line> [--from-file <path>] [--workspace <path>]
			A tooling fault filed as an inquiry in that member's inbox, with the
			run, its member, its session and its dispatch item above the evidence,
			and one line in that item's `## Decisions` linking the two. The
			evidence is the standard input where `--from-file` gives none.

		--supervise-close-orphans [--execute] [--workspace <path>]...
			The test rigs the scan reports as `rig-orphan`: a control thread alive
			inside a run's own output folder after that run's record closed. One
			line each, ending in a verdict. Without `--execute` it is a readout:
			`would-close`, `kept-unverified` where the pid file holds no began
			moment, `kept-mismatch` where the pid now belongs to another process.
			With `--execute` a `would-close` one is sent TERM and reads `closed`,
			or `still-alive` after two seconds; nothing is killed harder. The pid
			is checked against the process before any signal.

		--supervise-copy <from-run-id> <source-path> <to-run-id> <destination-path>
			One file copied from one run's sandbox to another's, always a real copy
			and never a link: the copy is proven a regular file with an inode of its
			own and the source's bytes before it is put in place. Each path is
			relative to its run's sandbox root, with no `..` and no absolute path.
			A read-only `input/` folder is reached, its write bit lifted for the
			call and put back, and the copy is left without one. One `copy` row
			each: the two runs, the two paths, `new` or `replaced`, and the bytes.

		--supervise-commit-transcripts [--workspace <path>] [--dry-run]
			The transcripts under `audit/` that the store holds changed reach one
			commit, and the push the store owes is paid, one `commit <path>` row
			each then `pushed <state>`. `--dry-run` commits nothing and prints the
			paths that would go. A path still uncommitted after the commit exits 1.
			This is the sweep for the lines written after a run ended, which no
			milestone of that run will ever carry.

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
