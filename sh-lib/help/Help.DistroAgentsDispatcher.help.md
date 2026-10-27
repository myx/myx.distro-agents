📘 syntax: DistroAgentsDispatcher.fn.sh --spawn-prompt [--team-member <team-member>] [--from-stdin] [--from-file <path>] [--from-board <board-item-name> [--board-state <state>]...] [--from-vault <vault-item-name>] [--from-audit <audit-item-name>] [--session-thread:event-track|magic-team] [--session-name-or-comment <text>] [--description <text>] [--wait]
📘 syntax: DistroAgentsDispatcher.fn.sh --spawn-session (--routine <selector>|--routine-default) [--session-name-or-comment <text>] [--description <text>] [--spawn-cli-service <cli-name>] [--spawn-settings-workspace <workspace-name>] [--join-session <session-id>] [--participants <entry>[,<entry>...]|none] [--likely-permission <tool>:<target>]... [--likely-tool <tool>]... [<team-member>...]
📘 syntax: DistroAgentsDispatcher.fn.sh --shutdown-runs [--team-member <team-member>]
📘 syntax: DistroAgentsDispatcher.fn.sh --all-sessions [--team-member <team-member>] [--kind standalone|coworking|ad-hoc] [--scope this-session|own|member <team-member>|all]
📘 syntax: DistroAgentsDispatcher.fn.sh --active-sessions [--team-member <team-member>] [--kind standalone|coworking|ad-hoc] [--scope this-session|own|member <team-member>|all]
📘 syntax: DistroAgentsDispatcher.fn.sh --waiting-sessions [--team-member <team-member>] [--kind standalone|coworking|ad-hoc] [--scope this-session|own|member <team-member>|all]
📘 syntax: DistroAgentsDispatcher.fn.sh --list-session-runs [--team-member <team-member>]
📘 syntax: DistroAgentsDispatcher.fn.sh --camunda-diagram-sync-stale [--team-member <team-member>] <definitions-dir> <diagrams-dir>
📘 syntax: DistroAgentsDispatcher.fn.sh --session-record [--team-member <team-member>] <session-id> [--run]
📘 syntax: DistroAgentsDispatcher.fn.sh --routine-completed [--team-member <team-member>] <routine> --since \"<YYYY-MM-DD HH:MM>\"
📘 syntax: DistroAgentsDispatcher.fn.sh --current-flags [--team-member <team-member>]
📘 syntax: DistroAgentsDispatcher.fn.sh --override-flag [--team-member <team-member>] [--no] <flag> [<ttl>]
📘 syntax: DistroAgentsDispatcher.fn.sh --set-country [--team-member <team-member>] <iso-code-2-or-3-letters>
📘 syntax: DistroAgentsDispatcher.fn.sh --set-timezone [--team-member <team-member>] <tz-spec>
📘 syntax: DistroAgentsDispatcher.fn.sh --set-worktime [--team-member <team-member>] <start HH:MM> <until HH:MM> <days-of-week>
📘 syntax: DistroAgentsDispatcher.fn.sh --set-weekend [--team-member <team-member>] <days-of-week>
📘 syntax: DistroAgentsDispatcher.fn.sh --routine-due [--team-member <team-member>] [--read-only] <routine>
📘 syntax: DistroAgentsDispatcher.fn.sh --rebuild-stats [--team-member <team-member>]
📘 syntax: DistroAgentsDispatcher.fn.sh --stats-check [--team-member <team-member>]
📘 syntax: DistroAgentsDispatcher.fn.sh --run-stats [--team-member <team-member>] [--member <m>] [--routine <r>] [--status <s>] [--since <YYYY-MM-DD>] [--until <YYYY-MM-DD>]
📘 syntax: DistroAgentsDispatcher.fn.sh --run-history [--team-member <team-member>] [--member <m>] [--routine <r>] [--since <YYYY-MM-DD>] [--limit <n>]
📘 syntax: DistroAgentsDispatcher.fn.sh --routine-stats [--team-member <team-member>] [<routine>]
📘 syntax: DistroAgentsDispatcher.fn.sh --token-stats [--team-member <team-member>] --by day|weekday|hour|member|routine|preset|credential|session [--since <date>] [--until <date>] [--member <m>] [--routine <r>] [--preset <p>] [--credential <c>] [--average] [--share] [--cache]
📘 syntax: DistroAgentsDispatcher.fn.sh [--help-syntax [<op>]]
📘 syntax: DistroAgentsDispatcher.fn.sh [--help]

##  Summary:

		The runs of the team and everything about them: the sessions of this
		workspace and their runs, one session in full, the flags and the
		settings of the schedule, and the stats store derived from the run
		records. The spawn operations start a run; nothing here reads a
		transcript.

##  Options:

		--spawn-prompt [--from-stdin] [--from-file <path>] [--from-board <board-item-name> [--board-state <state>]...] [--from-vault <vault-item-name>] [--from-audit <audit-item-name>] [--session-thread:event-track|magic-team] [--session-name-or-comment <text>] [--description <text>] [--wait]
			One prompt run against an agent CLI, the text read from the call or from
			an item of the board, the inbox or the vault. `--wait` stays until the
			run ends and brings its notice.

		--spawn-session (--routine <selector>|--routine-default) [--session-name-or-comment <text>] [--description <text>] [--spawn-cli-service <cli-name>] [--spawn-settings-workspace <workspace-name>] [--join-session <session-id>] [--participants <entry>[,<entry>...]|none] [--likely-permission <tool>:<target>]... [--likely-tool <tool>]... [<team-member>...]
			A session of one routine's run, started for each team member named, or
			for the caller where none is: the work-session dispatch every routine
			runs under. The participants the executor is to invite, and what the
			work likely needs, are checked and recorded, never started here.

		--shutdown-runs [--team-member <team-member>]
			Ends the runs that are to end now, a line each for what was ended, and
			what was left standing with why.

		--all-sessions [--kind standalone|coworking|ad-hoc] [--scope this-session|own|member <team-member>|all]
		--active-sessions [--kind standalone|coworking|ad-hoc] [--scope this-session|own|member <team-member>|all]
		--waiting-sessions [--kind standalone|coworking|ad-hoc] [--scope this-session|own|member <team-member>|all]
			The sessions of this workspace with their runs: the rows the manager's
			session list prints, with `--active-sessions` those not finished and
			with `--waiting-sessions` those that wait. The kind keeps one kind of
			session, read from the routine its run records; the scope narrows whose.

		--list-session-runs
			The runs this session may see, bound to the session of the call: its
			own runs and its sub-sessions, the public coworking sessions and the
			caller's own. Never another member's private session, unless the call is
			made in it. Takes no argument.

		--camunda-diagram-sync-stale <definitions-dir> <diagrams-dir>
			The BPMN and DMN diagrams older than the newest definition file, a row
			each. Read-only.

		--session-record <session-id> [--run]
			One session in full, or with `--run` one run of it: the rows the
			manager's session read prints.

		--routine-completed <routine> --since "<YYYY-MM-DD HH:MM>"
			The predecessor question: whether a run of a routine closed
			spawn-succeeded at or after a time. Prints the run and ends 0, else a
			NOT-COMPLETED line and ends 1.

		--current-flags
			The flags of the schedule now, derived from the settings and the clock:
			worktime, weekend, holidays, emergency, overtime and learning, a line
			each, `<flag>: yes|no`. Read-only.

		--override-flag [--no] <flag> [<ttl>]
			An override of a flag: emergency, with a TTL; overtime; holidays, with a
			TTL or until cleared; or learning. `--no` clears the override.

		--set-country <iso-code-2-or-3-letters>
		--set-timezone <tz-spec>
		--set-worktime <start HH:MM> <until HH:MM> <days-of-week>
		--set-weekend <days-of-week>
			The settings of the schedule, a person's configuration. Each prints the
			setting back as `<setting>: <value>`; a value of another form is refused
			and nothing is stored.

		--routine-due [--read-only] <routine>
			Whether a routine is due to start now by its own autorun declaration.
			Ends 0 due, 1 not due, 2 refused naming the predecessor that has not
			completed, 3 a call that could not be understood.

		--rebuild-stats
		--stats-check
		--run-stats [--member <m>] [--routine <r>] [--status <s>] [--since <YYYY-MM-DD>] [--until <YYYY-MM-DD>]
		--run-history [--member <m>] [--routine <r>] [--since <YYYY-MM-DD>] [--limit <n>]
		--routine-stats [<routine>]
		--token-stats --by day|weekday|hour|member|routine|preset|credential|session [--since <date>] [--until <date>] [--member <m>] [--routine <r>] [--preset <p>] [--credential <c>] [--average] [--share] [--cache]
			The runs and stats store of `.local/agents`, an index derived from the
			run records and never a source. `--rebuild-stats` derives it whole,
			`--stats-check` compares it with a rebuild, and the four readers bring it
			up to date before they print. `--token-stats --average` prints the four
			token fields as the average of a run (whole tokens, 0 for a key with no run);
			`--share` adds two fields, the share of the `in` tokens of a key in the total
			of all keys and in the largest key, each in whole percent (of the averages
			with `--average`).
			`--cache` adds the cache-hit of a key before the shares: the cache-read
			tokens over all input tokens, in whole percent, 0 for no input. `--by session`
			gives a row for each session, so the hit is read per session.

##  Examples:

		# The sessions that wait, and one session in full
		`DistroAgentsDispatcher.fn.sh --waiting-sessions`
		`DistroAgentsDispatcher.fn.sh --session-record <session-id> --run`
		# Whether a routine is due, and whether its predecessor completed
		`DistroAgentsDispatcher.fn.sh --routine-due advance`
		`DistroAgentsDispatcher.fn.sh --routine-completed daily --since "2026-10-26 09:00"`
		# The flags now, then one of them overridden for an hour
		`DistroAgentsDispatcher.fn.sh --current-flags`
		`DistroAgentsDispatcher.fn.sh --override-flag emergency 3600`
		# The runs' own stats, and one token report by member
		`DistroAgentsDispatcher.fn.sh --run-stats --since 2026-10-01`
		`DistroAgentsDispatcher.fn.sh --token-stats --by member`
