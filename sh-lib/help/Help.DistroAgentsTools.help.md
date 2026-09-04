📘 syntax: DistroAgentsTools.fn.sh --console-start [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]
📘 syntax: DistroAgentsTools.fn.sh --console-send <channel> [-- <command...>]
📘 syntax: DistroAgentsTools.fn.sh --console-stop <channel>
📘 syntax: DistroAgentsTools.fn.sh --console-list [--override-workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --agents-config-option <entity-id> <operation>
📘 syntax: DistroAgentsTools.fn.sh --member-config-option <member-name> <operation>
📘 syntax: DistroAgentsTools.fn.sh --members --backend <member-name> <operation>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>:<ts>> [--identity-bot] [text...]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <target> [--identity-bot] [--address-to <who>]... --from-stdin [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <target> [--identity-bot] [--address-to <who>]... --from-file <path> [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-send <team-member> <email@address>... -- <subject> -- <body...> [--in-reply-to <message-id>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-send <team-member> <email@address>... -- <subject> -- --from-stdin [--in-reply-to <message-id>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-send <team-member> <email@address>... -- <subject> -- --from-file <path> [--in-reply-to <message-id>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-search-messages <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>> (--comms-since-date-time <v>|--comms-since-utime <v>) [--max-pages <n>] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-react <team-member> <channel>:<ts> <emoji-name> [--identity-bot]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-delete-message <team-member> <channel>:<ts> [<channel>:<ts>...] [--identity-bot]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-edit-message <team-member> <channel>:<ts> [--identity-bot] [text...]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-edit-message <team-member> <channel>:<ts> [--identity-bot] --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-edit-message <team-member> <channel>:<ts> [--identity-bot] --from-file <path>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-file-info <team-member> <file-id> [--identity-bot] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-file-fetch <team-member> <file-id> <destination-path> [--identity-bot] [--overwrite]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-profile-get <team-member>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-profile-set <team-member> [--display-name <v>] [--status-text <v>] [--status-emoji <v>] [--status-expiry <ts>] [--avatar <path>] [--presence auto|away] [--snooze <minutes>|--snooze-end]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-slack-resolve-ids <team-member> [--user-name <name>]... [--channel-name <name>]... [--human-owner-hint <name>] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-check <team-member>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-mark-seen <team-member> <uid>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-trello-check <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-trello-post-comment <team-member> <card-id> [text...]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-trello-post-comment <team-member> <card-id> --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-trello-post-comment <team-member> <card-id> --from-file <path>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-read <team-member> <channel>:<ts> [--thread] [--identity-bot]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-read <team-member> <uid> [--seen]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-trello-read <team-member> <notification-id>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-whoami <team-member>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-issue-search <team-member> <jql> [--limit <n>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-issue-read <team-member> <issue-key> [--format adf|rendered]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-comment-read <team-member> <issue-key> [--format adf|rendered]
📘 syntax: DistroAgentsTools.fn.sh --self-test
📘 syntax: DistroAgentsTools.fn.sh --verify-permissions
📘 syntax: DistroAgentsTools.fn.sh --librarian-list-team-files [<path>...]
📘 syntax: DistroAgentsTools.fn.sh --librarian-list-team-files-dates [<path>...]
📘 syntax: DistroAgentsTools.fn.sh --librarian-inbox-item-trash <team-member> <item-filename> --from-inbox:<member>
📘 syntax: DistroAgentsTools.fn.sh --librarian-inbox-to-processed <team-member> <item-filename> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-note-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-upsert-member-inquiry <member> <item-filename> [--from-file <path>]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-reflection-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-append-session-transcript <team-member> --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <verbatim-text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> --workspace-root <path> [--create]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-item-read <member> <item-filename> [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --member-read-audit-item <team-member> <document-name> [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --member-read-board-item <team-member> <item-name> [--board-state <state>]... [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --owner-workspace-upsert <path>
📘 syntax: DistroAgentsTools.fn.sh --owner-workspace-forget <path>
📘 syntax: DistroAgentsTools.fn.sh --owner-workspace-list
📘 syntax: DistroAgentsTools.fn.sh --owner-workspace-current
📘 syntax: DistroAgentsTools.fn.sh --install-claude-permissions
📘 syntax: DistroAgentsTools.fn.sh --install-workspace-restrictions [--workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --install-skillset-symlinks [--scope workspace|user-home] [--workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --install-vscode-integrations [--workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --install-workspace-integrations [--scope workspace|user-home] [--workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --make-workspace-integrations [--quiet]
📘 syntax: DistroAgentsTools.fn.sh --make-console-command [--quiet]
📘 syntax: DistroAgentsTools.fn.sh --make-console-script
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-backlog <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-pending <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-processed <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-parked <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-blocked <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-running <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-archived <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-retained <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-backlog <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-processed <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-pending <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-blocked <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-running <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-sweep-input-scan <team-member> [--comms-since-utime <v>|--comms-since-date-time <v>]
📘 syntax: DistroAgentsTools.fn.sh --magic-sweep-state-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-sweep-state-read <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-team-roster-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-team-roster-read <team-member>
📘 syntax: DistroAgentsTools.fn.sh --member-work-session-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --routine-coworking-session-input-scan <team-member> <tracking-document>...
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-config-check
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-to-running <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-to-parked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-pending <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-blocked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-backlog <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-parked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-processed <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-create-running <team-member> <item-filename> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-sleep-run
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-lock-acquire <team-member> <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-lock-refresh <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-close-state-and-unlock <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-lock-status <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-lock-acquire <team-member> <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-lock-refresh <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-close-state-and-unlock <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-lock-status <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-lock-acquire <team-member> <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-lock-refresh <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-close-state-and-unlock <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-lock-status <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-lock-acquire <team-member> <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-lock-refresh <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-close-state-and-unlock <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-lock-status <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-lock-acquire <team-member> <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-lock-refresh <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-close-state-and-unlock <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-lock-status <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-state-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-state-read <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-board-item-trash <team-member> <board-state> <item-name>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-spawn-proxy <team-member> [--from-stdin] [--from-file <path>] [--from-board <board-item-name> [--board-state <state>]...] [--from-vault <vault-item-name>] [--from-audit <audit-item-name>] [--wait]
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-sleep-run
📘 syntax: DistroAgentsTools.fn.sh --purge-cleanup
📘 syntax: DistroAgentsTools.fn.sh --member-help <team-member>
📘 syntax: DistroAgentsTools.fn.sh [--help]

**IMPORTANT -- for `mcp__myx_distro__execute` callers specifically:** call every operation as the bare `DistroAgentsTools <op> [args...]` function form -- never `DistroAgentsTools.fn.sh <op> [args...]`. That one execution context already has `DistroAgentsTools` defined as an in-process shell function before your command runs, uniquely among the ways this tool is invoked; every other context (a console session, a plain shell) still needs the full `.fn.sh` invocation shown throughout the rest of this file.

##  Summary:

		The magic-* team's single mandated execution interface for every
		stateful team action: posting/reading Slack, email, and Trello
		comms; reading/writing board and inbox items; managing per-entity
		credential/config scopes; running/reusing workspace console
		sessions; and driving the process-flow state machinery (grooming,
		heartbeat, board advancement) the team's routines depend on. Call
		it directly for anything it already covers, rather than a raw
		shell command or file edit.

		**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

##  Arguments:

		channel
			Channel id (e.g. `myx.distro-agent-console.<slug>.<source|deploy>`)
			as printed by --console-start, or an absolute path to its channel
			directory. Accepted by --console-send and --console-stop.

##  Options:

		--console-start
			Starts (or, for an already-alive channel on the same workspace +
			console, reuses) a Keep-Alive console session. Prints
			CHANNEL/CHANNEL_DIR/FIFO/LOG/CONSOLE/WORKSPACE/HOLDER_PID/CONSOLE_PID
			to stdout. A channel dir that exists but has no live processes is
			wiped and recreated rather than reused.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--override-workspace <path>
			Target a workspace other than this tool's own ($MMDAPP). Accepted
			by both --console-start and --console-list; the two must agree on
			what "own workspace" means, so pass it identically to both.

		--console DistroSourceConsole.sh|DistroDeployConsole.sh
			Pick which console script to start. Default: whichever of
			DistroSourceConsole.sh / DistroDeployConsole.sh exists (executable)
			in the workspace root, tried in that order. DistroLocalConsole.sh
			and DistroRemoteConsole.sh are not supported.

		--ttl <seconds>
			Lifetime of the FIFO-holder process, i.e. how long the channel
			stays open with no traffic before its holder exits and the console
			sees EOF. Default: 3600.

		--console-send <channel> [-- <command...>]
			Sends one command line into an open channel's FIFO. With a
			trailing `-- <command...>`, that argument list (joined with
			spaces) is sent. With no command given, stdin is read and piped
			through as-is (so multi-line input/heredocs work).

			**Command-only, not a data-transport.** The joined command is
			written raw and unquoted, exactly like typing at an interactive
			shell prompt -- caller is responsible for their own quoting. Do
			NOT pass arbitrary free text (a message body, anything with
			shell metacharacters like parentheses/quotes/semicolons) as the
			trailing argument -- that has crashed a live console process for
			real. For free text, call
			--member-comms-slack-send-message/--member-comms-email-send
			as bare direct invocations instead; neither goes through
			--console-send.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--console-stop <channel>
			Sends `exit` into the channel, then kills the console and
			FIFO-holder processes (TERM, then KILL after a 1s grace period if
			still alive), and removes the channel directory. Safe to call on a
			channel with already-dead processes — cleanup still runs through
			to completion.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--console-list [--override-workspace <path>]
			Lists channels belonging to one workspace (default: this tool's
			own; see --override-workspace) with their console/holder
			liveness. Never lists another workspace's channels unless
			explicitly overridden — this command's scope is intentionally
			per-workspace, not global.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--agents-config-option <entity-id> <operation>
			Reads/writes one settings scope per named entity. <entity-id> is
			a required first argument (this tool's own team-wide settings
			live under entity-id `magic-coordinator`).
			<operation> is one of: --select-all, --select <key>|--all,
			--select-default <key> <default>, --upsert <key> <val>,
			--upsert-from-stdin <key>, --upsert-if <key> <val> <ifval>,
			--delete <key>, --delete-if <key> <ifval> — the underlying
			config backend defines the authoritative behavior of each.
			--upsert-from-stdin reads the value from stdin instead of argv,
			so a credential is never visible in the process table; trailing
			newlines are stripped, and empty or multi-line input is an
			error. Use it for every secret.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-config-option <member-name> <operation>
			Friendly synonym for --agents-config-option <member-name>
			<operation> — self-recurses into it directly, same <operation>
			set. Exists so a caller thinking in terms of "this member's own
			settings" doesn't need to know the underlying scope's name.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--members --backend <member-name> <operation>
			Second synonym, one hop further — mirrors myx.distro-remote's
			RemoteConsole.fn.sh `--remotes --backend <remote-name>` calling
			shape exactly, remote→member renamed mechanically. Self-recurses
			into --member-config-option <member-name> <operation> [args...].
			Only --backend is mirrored from Remote's own --remotes op group
			— RemoteConsole.fn.sh's friendlier --upsert/--upsert-if/--select/
			--delete wrappers are not mirrored here; call --members
			--backend (or --member-config-option, or --agents-config-option
			directly) for every operation.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-slack-send-message <team-member> <target> [--identity-bot] [--address-to <who>]... [text...]
		--member-comms-slack-send-message <team-member> <target> [--identity-bot] [--address-to <who>]... --from-stdin [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>]
		--member-comms-slack-send-message <team-member> <target> [--identity-bot] [--address-to <who>]... --from-file <path> [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>]
			Posts a message, attributed to <team-member>, to one of:
			magic-team, human-owner, event-track, event-alert, a bare
			<conversation-id> (posted as a NEW TOP-LEVEL message in that
			conversation), or a literal <channel>:<ts> (posted as a
			THREADED REPLY under that one message). The forms are told
			apart in that order: a target containing `:` is
			<channel>:<ts>; one of the four alias words resolves to its
			configured conversation; otherwise a token of uppercase
			letters and digits, starting with a letter and at least 9
			characters long, is taken as a literal conversation id. A
			target matching none of these forms is REJECTED with an error
			and nothing is sent anywhere. Content comes from
			trailing text args, --from-stdin, or --from-file <path> —
			exactly one. --identity-bot posts as the team bot instead of
			this member's own identity.

			**Two versions are generated, never derived from each other.**
			Every message goes out as a blocks version and a text version,
			each built independently from the one input you give. Neither is
			produced from the other, and nothing converts between them: a
			mention written as an escape form inside `rich_text` stays inert
			plain text, while the same form in the `text` field survives
			byte-identically, so the same field has to be a text sequence on
			one side and a structural element on the other.

			`--format` selects how the body is read. **Accepted values are
			`markdown` (the default) and `blocks`.** An unrecognised value is
			rejected with an error naming the accepted set, and nothing is
			sent. Earlier revisions of this manual documented a `text` value
			that the code never implemented, and did not name the value it
			actually defaulted to; `text` is no longer an input format, and
			passing it now fails loudly instead of silently posting an
			unformatted message.

			`--format blocks` sends a caller-supplied Block Kit JSON array
			(with --from-stdin/--from-file only — a JSON array pasted as a
			trailing text argument is rejected, not posted as the message
			body). Malformed JSON or an unsupported block type is rejected
			before anything is sent, with a specific error naming the
			problem.

			**Both formats are checked against Slack's own acceptance before
			the send, and a payload that fails is never posted in a reduced
			form.** The whole array is walked, not its top level: an empty
			text string or a childless `elements` array anywhere in it is
			reported by the path it sits at, and the operation fails with
			nothing sent. This does not promise that a Slack rejection is
			impossible — the empty-node rule appears in none of Slack's own
			published Block Kit pages and was learned from a live rejection,
			so the rule set is open. What it promises is that every rejection
			class already measured is caught here rather than at Slack.
			Known-uncaught, each documented by Slack and none of them a
			property of a single node: the 50-block cap per message, the
			150-character header maximum, and the per-type required fields
			of the blocks a caller supplies verbatim.

			**A send that does not land fails, and says so.** `invalid_blocks`
			is a verdict Slack reached, not a transport fault, so it is not
			retried and no stuck-comms email is sent for it; the same holds
			for an unreachable or archived conversation. Only a send that
			genuinely exhausted its retries notifies by email, and even then
			the operation returns failure — the email is a notification, never
			a delivery, and the exit status always reports whether the message
			reached Slack.

			`--message-text <text>` and
			`--message-text-from-file <path>` supply the text version of a
			blocks message and are **optional**: when neither is given, a text
			version is generated from the blocks. When one is given, that text
			is used verbatim and nothing is generated over it. Give what the
			message *says*, in plain text — not a transcription of your blocks.

			The generated text version is **simplified but not lossy**. Every
			structured element is emitted in its own text form: a mention
			becomes `<@Uxxx>`, a broadcast `<!here>`, a channel `<#Cxxx>`, an
			emoji its character, a link its visible text. An element with no
			known text form is rendered as a visible placeholder and reported
			on stderr, never silently dropped. That last point is the whole
			difference from the renderer this replaces, which collected each
			node's own `text` key and so turned `ping <@U75H0DK43>` into
			`ping`.

			**`--address-to <member|user-id|conversation-id>`**, repeatable,
			names who the message is *for*. Deliberately not the same thing as
			the operation's own target, which is the conversation the message
			goes *to* — a message in the team channel addressed to one member
			is the ordinary case. The argument form is resolved by the
			operation, never chosen by the caller: recognition is lexical, on
			the argument's own first character. A team member name brings that
			member's own identity marks — alias and emoji or Slack shortcode,
			read from their `<name>.basic.md` — into both versions, each in
			that version's own form. A `U…` id becomes the structured user
			element in blocks and `<@U…>` in text. A `C…`/`D…`/`G…` id
			resolves as given. An email addressee is a recorded direction that
			is not built, and says so rather than being guessed at. A name
			that is not a member fails loudly; a member whose alias is absent
			or malformed falls back to the member name and never fails the
			send.

			**Every message carries a labelled `To:` line, and a bot message
			carries a `From:` line above it.** Both name their member the same
			way — `<icon> <team-member> @<alias>` — and several addressees are
			separated by `; `. `To:` is always present: with no `--address-to`
			it reads `To: @here`, which is plain text and pings nobody. `From:`
			appears only where the Slack account shown is not the member's own
			— a bot post, or one relayed for a token-less member — since a
			message sent under the member's own user token already shows who
			sent it. Both lines land in the blocks version and in the text
			version, and both are found by their label: Slack rewrites the text
			version of a blocks message and flattens its line breaks, so a
			reader must never depend on which line either one sits on.

			**In-body mentions.** Write a bare `@name` anywhere in a
			`markdown` body. The blocks version renders it as a real mention
			where the name resolves; the text version keeps it exactly as
			written, byte for byte. A name that resolves to nobody stays a
			literal `@name` in both versions and never fails the send. Two
			boundaries are ours, not Slack's: the token runs from the `@` to
			whitespace or end of line, so `@name,` takes the trailing comma
			with it and will not resolve, and a display name containing a
			space breaks at the space. A `@name` inside a code span or a
			fenced block is left exactly as written.

			**Emphasis is CommonMark.** Not a restricted subset invented
			here: delimiter runs, the left/right-flanking predicates and the
			matching rules follow the CommonMark specification's "Emphasis and
			strong emphasis" section. **One delimiter is emphasis (italic),
			two is strong (bold), and both `*` and `_` carry both meanings.**
			So `*x*` and `_x_` are italic; `**x**` and `__x__` are bold;
			`***x***`, `*__x__*` and `**_x_**` are bold italic.

			`_` takes the spec's stricter open/close predicates, which is
			exactly why an intra-word run never opens emphasis: an identifier
			such as `mcp__myx_distro__execute` or `snake_case_name` renders as
			one unbroken literal token. That protection is the specification's
			own, not a guard bolted on beside it.

			Slack's `rich_text` cannot nest emphasis, so nested emphasis
			flattens into a combined style set — `*__b__*` becomes one
			bold+italic span. The input grammar is CommonMark and the output
			is Block Kit; they are different things and neither constrains the
			other.

			**One ruled departure**: backtick, apostrophe and double quote do
			NOT act as flanking boundaries here, so `"_it_"` stays literal
			where CommonMark would emphasise it. Deliberate and recorded, not
			an oversight. Backtick-quoting an identifier remains the reliable
			way to protect one: a code span's content is taken verbatim and
			never rescanned.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-email-send <team-member> <email@address>... -- <subject> -- <body...> [--in-reply-to <message-id>]
		--member-comms-email-send <team-member> <email@address>... -- <subject> -- --from-stdin [--in-reply-to <message-id>]
		--member-comms-email-send <team-member> <email@address>... -- <subject> -- --from-file <path> [--in-reply-to <message-id>]
			`<team-member>` is the member this send acts as, and it comes
			first, ahead of the recipients. It is required, and it is strict:
			the credentials the send authenticates with are that member's own,
			with no fallback to another member's scope, so a member without a
			mailbox of its own fails here rather than quietly sending from
			someone else's address.

			Real, standalone SMTP send. Uses that member's configured email
			credentials, not just an internal fallback -- a --member-comms-slack-send-message
			call that exhausts its retries notifies through this same operation. That
			notification does not stand in for the message: the Slack send still reports
			failure, and its exit status says so. Multiple recipients
			accepted before the first `--`; subject is everything between the
			two `--` separators; everything after the second `--` becomes the
			body, one line per remaining argument -- OR
			`--from-stdin` in place of trailing body argv reads the whole body
			from stdin instead (call with the tool's absolute path leading and
			a heredoc, per the team-wide convention above), avoiding
			multi-line/shell-metacharacter argv fragility. `--from-file <path>`
			reads the body from a file instead — same motivation
			as --member-comms-slack-send-message's own --from-file (write the body with a plain Write
			tool call first, then invoke this op as one single-line command).
			Giving more than one of `--from-stdin`/`--from-file`/trailing body argv
			together is an error (`⛔ ERROR: ... given alongside ... -- use one
			or the other, not both`), not silently resolved one way or the
			other -- exactly one body source is required.

			`--in-reply-to <message-id>`: use this when the send is a reply to
			an earlier message, so the recipient's own mail client threads it
			under that message instead of showing it as unrelated. Pass exactly
			the parent message's own `Message-Id` header value, angle brackets
			included -- the same value visible on a message fetched via
			`--member-comms-email-read`. Optional; a send with no
			`--in-reply-to` is unchanged from before this flag existed. Single-level
			threading only: the value is placed on both `In-Reply-To` and
			`References`, not accumulated into a multi-message chain.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-slack-search-messages <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>> (--comms-since-date-time <v>|--comms-since-utime <v>) [--max-pages <n>] [--raw]
			`<team-member>` is the member this search acts as, and it comes
			first, ahead of the target. It matters more here than on the
			sibling read ops, not less: this operation always acts under a
			user token, so the member is the only thing deciding whose
			account performs the search and therefore what it can see.
			Finds messages in ONE conversation since a cut-off, including
			**thread replies whose parent message is older than that
			cut-off**. That last part is the whole reason to reach for this
			op instead of a single-target conversation read: a bounded
			single-target read reports a thread by its PARENT, so a
			long-running thread whose parent predates the cut-off is
			invisible in that read no matter how recently it was replied to.
			Measured on this workspace: three threads in `magic-team` whose
			parents predated a cut-off carried 41, 18 and 6 replies after it,
			and none of the three appeared in the bounded read. This op
			answers "what has been said anywhere in this conversation,
			threads included" -- a different question from "what is new at
			the top level of this conversation", and neither replaces the
			other.

			Target grammar is the same vocabulary the rest of the
			family takes -- `magic-team`/`human-owner`/`event-track`/
			`event-alert`, an explicit channel, or a bare
			`<conversation-id>`, which searches THAT conversation exactly as
			a bare alias does; it is the form to reach a conversation no
			alias is configured for. **A `<channel>:<ts>`
			target is refused**, not silently accepted with the `<ts>`
			dropped: a `<ts>` names one exact message and this op searches a
			whole conversation over a time window. Read one message or one
			thread with --member-comms-slack-read instead. There is deliberately no
			free-text query form; the query is built from the target, so
			every op in this family is addressed the same way.

			A cut-off is **required** -- `--comms-since-date-time
			<YYYY-MM-DD...>` or `--comms-since-utime <epoch-seconds>`,
			mutually exclusive, neither repeatable, the same pair
			--magic-sweep-input-scan takes. Without one, the search would
			walk the conversation's entire history a page at a time.
			The cut-off is applied to each message's own timestamp at full
			precision. The window actually requested of Slack starts one day
			earlier than the cut-off on purpose -- Slack's own date filtering
			is whole-day and exclusive -- so results are asked for widely and
			then narrowed here. The `after=` value in the summary line
			reports that widened start date; the `cutoff=` value is the real
			boundary, and nothing older than it is ever printed.

			**`--identity-bot` is REFUSED by this operation**, and this is
			the one op in the family where that flag cannot work. Slack's
			message search is available to a user identity only -- no
			permission grant changes that -- so the flag is rejected with a
			reason rather than accepted and quietly ignored, which would mean
			acting under an identity the caller did not ask for. Every other
			--member-comms-slack-* op does accept it. One consequence worth knowing
			before choosing this op: a conversation only the team bot can see
			is not reachable here at all.

			`--max-pages <n>` bounds how many result pages are read
			(default 10; each page holds up to 100 messages). The read stops
			on its own as soon as it has reached back past the cut-off, so
			the bound only matters for a genuinely large window. **Hitting
			the bound is reported as its own outcome and never returned as
			if the read were complete** -- see the exit codes below.

			Exit code:
			0 matches found, and the whole window was read.
			3 no matches in the window, and the whole window was read -- a
			real, complete answer that this conversation holds nothing
			there. Deliberately not 0, so absence cannot be read as
			presence by a caller that ignores status.
			4 incomplete -- the `--max-pages` bound was reached before the
			cut-off was, so what was printed is the newest matches only, a
			prefix of the answer. Nothing in it supports concluding any
			message is absent. Raise `--max-pages` or move the cut-off
			forward and read again.
			1 the search could not be performed at all; nothing is known
			about presence or absence.

			**Output is pretty-formatted by default**, oldest first, one
			line per message in the same `ts | user | text` shape
			a single-target conversation read prints, with ` [thread-reply of <parent-ts>]`
			appended to a message that sits inside a thread -- that parent ts
			is what a follow-up `--member-comms-slack-read <team-member> <channel>:<ts> --thread`
			needs. A message's own line breaks are flattened to spaces to
			keep one line per message; `--raw` returns the full API responses
			instead, each labelled with its own page and never glued into one
			body. A `##` summary line reports the match and thread-reply
			counts, how many pages were read, and the cut-off actually
			applied.

			**Known limits, stated rather than implied away.** Search results
			come from an index, not from the live conversation, so a very
			recent message may not be findable yet -- a lag of about five
			minutes has been observed here, and the upper bound is not known.
			For anything just posted, a direct single-target conversation
			read sees it and this op does not. Two further
			behaviours are unverified in this workspace and may affect
			completeness: messages posted by bots are reported elsewhere as
			sometimes missing from search results, and search may honour
			search-preference settings configured in the Slack UI for the
			acting identity. Neither has been confirmed or ruled out here, so
			a zero-match result on a conversation known to be busy is worth
			cross-checking with a direct single-target conversation read.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-comms-slack-resolve-ids <team-member> [--user-name <name>]... [--channel-name <name>]... [--human-owner-hint <name>] [--raw]
			General coordinator comms-id resolver. Authenticates as one
			specific team-member identity (uses the same credential
			resolution as --member-comms-slack-send-message), then reports:
			(1) auth identity (`AUTH_USER_ID`, `AUTH_USER_NAME`),
			(2) requested user-name and channel-name matches with resolved IDs,
			(3) configured alias reachability for `magic-team`, `human-owner`,
			`event-track`, `event-alert`, and
			(4) best-known reachable human-owner target for this identity.

			Human-owner target resolution order is explicit and fail-loud:
			first the configured `human-owner` alias id, then (if not reachable)
			a DM open attempt using `--human-owner-hint`
			(default `myx`) matched against the workspace's user list.

			Use `--user-name`/`--channel-name` repeatedly to resolve concrete
			names to ids in one pass. `--raw` includes the full underlying
			API payloads for diagnostics.

			Exit code:
			0 when a reachable human-owner target is confirmed,
			1 when unresolved/unreachable.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-slack-react <team-member> <channel>:<ts> <emoji-name> [--identity-bot]
			<team-member> is the acting identity: the reaction is posted BY
			that member, and it must be a bare team-member name whose skill
			directory already exists (a `routine-*` caller is exempt from the
			directory check, as on every other op taking a member). The
			identity rule is the one this whole family follows -- the
			member's own user token when it has one, the team bot when it
			does not, and `--identity-bot` to skip the user token and act as
			the bot.

			Posts one Slack reaction to a specific message --
			<channel>:<ts> only, same target grammar as --member-comms-slack-read (no
			magic-team/human-owner shortcut, since a reaction always targets one
			exact message, not a channel). <emoji-name> has no colons (matches
			Slack's own `name` field, e.g. `white_check_mark`, not
			`:white_check_mark:`). The per-message Slack-reaction-tracking
			design (`routine-communication-sweep`,
			`routine-board-actualisation`'s pending-reaction lookup) calls
			this op to actually post. Uses the same credential resolution as
			--member-comms-slack-send-message; `--identity-bot` reacts as the team
			bot instead of this member's own identity. Reply and react take
			the same identity surface on purpose: you reply as yourself, you
			react as yourself; you reply as the bot, you react as the bot. A
			direct conversation belongs to one identity, so this also decides
			which conversation the reaction can reach at all. Channels are
			unaffected by it.

			Three outcomes, kept distinct. **Added**: the reaction was posted
			by this call -- raw API response printed, returns 0.
			**Already present**: the acting identity had already added that
			emoji to that message, so the end state asked for holds and this
			call posted nothing -- reported as its own outcome with a `#`
			note, returns 0, never folded into "added" and never an error.
			**Could not react**: anything else, Slack's own error code
			included -- returns 1 and nothing about the message's existing
			reactions is known from it. Reactions are per identity, so
			"already present" speaks only for the identity this call acted
			as; the same reaction under another identity is a normal result,
			not a duplicate.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-slack-delete-message <team-member> <channel>:<ts> [<channel>:<ts>...] [--identity-bot]
			<team-member> is the acting identity, and on this operation it
			decides whether the call can succeed at all -- see the authorship
			rule below. It must be a bare team-member name whose skill
			directory already exists (`routine-*` callers exempt). The
			identity rule is the family's own: the member's own user token
			when it has one, the team bot when it does not, and
			`--identity-bot` to skip the user token and act as the bot.

			Deletes one specific Slack message -- <channel>:<ts> only, same
			target grammar as --member-comms-slack-react (no
			magic-team/human-owner shortcut, since a deletion always targets
			one exact message, not a channel). There is no channel-wide or
			"delete all" form: every target is named explicitly, every time.
			Uses the same credential resolution as
			--member-comms-slack-send-message; `--identity-bot` acts as the team
			bot instead of this member's own identity.

			**More than one target may be given, and each one reports its
			own result.** Targets are attempted in order, a failure on one
			never stops the rest, and stdout carries a
			`DELETE_TARGET=<as given>` line followed by a `DELETE_STATE=` line
			for every single target: `deleted` (the raw API response follows
			it), `refused-on-authorship`, `could-not-call`,
			`unresolvable-target`, or `no-message-ts`. A partial failure is
			therefore visible per target rather than collapsed into one
			verdict. The exit status is 0 only when EVERY target was deleted;
			a non-zero exit never means the whole run failed, and the targets
			reporting `DELETE_STATE=deleted` really were deleted. A closing
			`#` note on stderr states how many of how many were deleted.

			**Slack permits deleting only a message the acting identity
			itself authored**, so this call succeeds or fails on who is
			asking. A refusal on that basis is reported as an authorship
			refusal naming the acting member and identity, distinct from a
			call that could not complete at all, and the raw Slack error is
			printed alongside it. The other identity is never retried
			automatically -- ask for it explicitly with `--identity-bot`
			instead.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-slack-edit-message <team-member> <channel>:<ts> [--identity-bot] [text...|--from-stdin|--from-file <path>]
			<team-member> is the acting identity, and as on
			--member-comms-slack-delete-message it decides whether the call can
			succeed at all -- Slack permits editing only what that identity
			itself authored. Bare team-member name, skill directory must
			exist (`routine-*` callers exempt). The member's own user token
			when it has one, the team bot when it does not, and
			`--identity-bot` to skip the user token and act as the bot.

			Replaces the text of one specific Slack message -- same
			<channel>:<ts> target grammar as --member-comms-slack-delete-message. The
			replacement text comes from the same three input forms
			--member-comms-slack-send-message accepts: trailing argv,
			`--from-stdin`, or
			`--from-file <path>`. `--format` is not offered here: this op
			edits plain text only. Empty replacement text is refused rather
			than applied, since that would blank the message. Re-running the
			same edit is safe -- it leaves the message as the first run left
			it.

			**Slack permits editing only a message the acting identity
			itself authored**, exactly as for --member-comms-slack-delete-message above:
			an authorship refusal is reported as such, naming the acting
			identity, with the raw Slack error alongside it, and the other
			identity is never retried automatically. Prints the raw API
			response and returns 0 on `ok:true`; any refusal or failure
			returns 1 and leaves the message unchanged.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-slack-file-info <team-member> <file-id> [--identity-bot] [--raw]
			<team-member> is the acting identity, and it is load-bearing
			here: a file lives in a conversation, so which identity asks
			decides whether the file is visible at all -- that is exactly
			what the exit code 3 below reports. Bare team-member name, skill
			directory must exist (`routine-*` callers exempt). The member's
			own user token when it has one, the team bot when it does not,
			and `--identity-bot` to skip the user token and act as the bot.

			Reports the metadata of one Slack file (`files.info`) so a caller
			can decide whether that file is worth retrieving at all.
			<file-id> is a Slack file id -- `F` followed by uppercase
			letters and digits, taken from a message payload's own file
			object `id` field; a permalink, a filename or a <channel>:<ts>
			pair is refused before any call is made. Uses the same
			credential resolution as --member-comms-slack-send-message;
			`--identity-bot` acts as the team bot instead of this member's
			own identity.

			**This operation tells you ABOUT a file and never fetches its
			bytes.** The URLs it prints (`URL_PRIVATE`,
			`URL_PRIVATE_DOWNLOAD`, the thumbnails) are metadata like every
			other field: reading what is behind them is an authenticated
			download, which is a different call, not a flag on this one.

			Output is stable `KEY=value` lines on stdout, one field per
			line, in this fixed order: `FILE_INFO_STATE`, `FILE_ID`,
			`NAME`, `TITLE`, `MIMETYPE`, `FILETYPE`, `SIZE`, `TIMESTAMP`,
			`AUTHOR_USER_ID`, `URL_PRIVATE`, `URL_PRIVATE_DOWNLOAD`,
			`THUMB_64`, `THUMB_80`, `THUMB_160`, `THUMB_360`, `THUMB_480`,
			`THUMB_720`, `THUMB_800`, `THUMB_960`, `THUMB_1024`. Each field
			is preceded by its own `<KEY>_STATE=present|absent|present-multiline`
			line, so a file with no title or no thumbnails says so
			positively instead of leaving a blank to guess at; `<KEY>=` is
			printed only for `present`. `--raw` prints the unparsed
			files.info response instead, for a field this op does not
			declare.

			Four exit codes, kept distinct. **0**: metadata found and
			emitted. **3**: Slack answered `file_not_found` -- one code for
			two situations it does not separate, either no file has that id
			or this identity cannot see it, so the message names the acting
			identity and the other identity is never retried automatically.
			**4**: Slack answered `file_deleted` -- the file existed and is
			gone, final for every identity. **1**: the call did not
			complete, from which nothing may be concluded about whether the
			file exists.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-slack-file-fetch <team-member> <file-id> <destination-path> [--identity-bot] [--overwrite]
			<team-member> is the acting identity, used for BOTH steps this
			op takes -- the metadata read and the authenticated byte fetch --
			so the two can never run as different identities. Bare
			team-member name, skill directory must exist (`routine-*` callers
			exempt). The member's own user token when it has one, the team
			bot when it does not, and `--identity-bot` to skip the user token
			and act as the bot.

			Retrieves one Slack file's actual bytes and writes them to
			<destination-path>. The counterpart to --member-comms-slack-file-info
			above: info tells you about a file so you can decide whether it
			is worth retrieving, this gets it -- so a member can open an
			attached screenshot rather than only read its description.
			<file-id> is a Slack file id, validated in the same way and
			refused the same way as by --member-comms-slack-file-info.

			**All three arguments are required and the destination is always
			yours.** There is no default location, no downloads directory,
			and the credential store is refused as a destination. The
			parent directory must already exist -- this operation writes a
			file, it does not create the tree above it. An existing file at
			the destination is left untouched unless `--overwrite` is
			given.

			**A successful-looking fetch is not accepted on its own.**
			An unauthenticated or under-scoped request for Slack file
			content is answered with HTTP 200 and a sign-in page, which
			without checking is indistinguishable from the file. So the
			result is verified before it is delivered: it must not be a web
			page, and its byte count must match exactly the size reported
			for that file. Bytes are written to <destination-path> only
			after every check passes -- a failed fetch never leaves a
			plausible-looking wrong file there, and never leaves a partial
			one.

			`--identity-bot` runs the call as the team's bot rather than
			the acting member's own identity. Note that being able to see a
			file is per-conversation, not per-workspace: a file in one
			identity's DM is genuinely invisible to the other, and that is
			reported rather than worked around by silently switching.

			On success, stable `KEY=value` lines on stdout, in this fixed
			order: `FETCH_STATE`, `FILE_ID`, `DESTINATION`,
			`VERIFIED_BYTES`, `MIMETYPE`, `SOURCE_URL_KIND`.
			`VERIFIED_BYTES` is the count that was actually checked.

			Four exit codes, the same four --member-comms-slack-file-info uses.
			**0**: fetched and verified; the file is at the destination.
			**3**: `file_not_found` -- either no file has that id or this
			identity cannot see it, the two situations Slack does not
			separate. **4**: `file_deleted` -- final for every identity.
			**1**: the fetch did not complete, or it completed and the
			result was not the file. For every non-zero code the
			destination is left exactly as it was.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-slack-file-share <team-member> <target> --from-file <path> [--snippet-type <v>] [--title <v>] [--comment <text>] [--identity-bot]
		--member-comms-slack-file-share <team-member> <target> --from-stdin [--snippet-type <v>] [--title <v>] [--comment <text>] [--identity-bot]
			Shares a file into a conversation, attributed to
			`<team-member>`. Use this for content that does not belong in a
			message body -- anything long, anything a reader needs to
			scroll, anything awaiting approval. A message body carries the
			ask; the file carries the material.

			`<target>` takes the same forms as
			--member-comms-slack-send-message and is classified the same
			way: `magic-team`, `human-owner`, `event-track`, `event-alert`,
			a bare `<conversation-id>`, or a literal `<channel>:<ts>`. A
			target resolving to a party rather than a conversation is
			opened as a direct conversation first, under the acting
			identity, because a share needs a conversation id and a party
			id is not one. A target matching no form is REJECTED before
			anything is uploaded, so a failed target never leaves a file
			behind.

			A `<channel>:<ts>` target shares into that thread. The `<ts>`
			may be any message in it: a reply's own `<ts>` is resolved to
			the thread's parent, because a share is anchored to the parent
			and a reply's ts is the value a caller most easily holds. That
			resolution is silent -- it gives nothing up, so there is
			nothing to report. A `<ts>` whose thread cannot be read is an
			error, never a share posted somewhere else.

			Content comes from `--from-file <path>` or `--from-stdin`,
			exactly one; naming both is an error, as it is on
			--member-comms-slack-send-message. There is no trailing-text
			form: the point of this operation is that the content is too
			big to be an argument. `--from-stdin` is buffered to a
			temporary file before the share begins, because the size in
			BYTES has to be known up front -- a character count is not a
			byte count, and content carrying em dashes or emoji differs in
			the two.

			`--snippet-type <v>` selects how the shared content is
			rendered. Which values are accepted is a property of the
			platform and of what this operation supports at the time you
			call it: ask for the value you want, and a value that is not
			supported is REJECTED, naming what was passed. It is never
			quietly replaced with a different one.

			`--title <v>` names the file as it appears in the
			conversation. Without it the name is the `--from-file`
			basename.

			`--comment <text>` is the message posted alongside the file,
			and is where the ask belongs. It is posted as its own message
			AFTER the share, through the ordinary message path -- not as a
			comment carried by the upload, which cannot render both
			versions of a message. Two visible items appear in the thread
			rather than one: that is the accepted cost of the message
			being a real message. Share first, message second, because a
			message posted first announces a file that is not there yet.

			`--identity-bot` shares as the team bot instead of this
			member's own identity.

			A share is visible to the conversation it was shared into, and
			not beyond it. It is not public, and it is not hidden from the
			people in that conversation.

			On success, the completion response on stdout, plus
			`SHARE_FILE_ID`, `SHARE_CONVERSATION` and `SHARE_BYTES` as
			`KEY=value` lines on stderr. `SHARE_BYTES` is the byte count
			that was actually sent.

			**failure**: this is one operation to the caller, and it is
			not finished until both the file and its accompanying message
			are there. A failure names the step that failed, of three. Two
			steps done and the third failed is a FAILURE, not a partial
			success -- and a file shared with no accompanying message is a
			failed operation however much of it you can see in the
			conversation. An upload begun and not completed is abandoned
			by the platform; there is nothing left for you to clean up.

			**mentions**: two separate things, and they behave
			differently. This operation takes no addressee argument --
			addressing a message is --member-comms-slack-send-message's
			own, and a share needing an addressee gets it from the message
			beside it. A bare `@name` written inside `--comment` is yours,
			and is recognised on its own terms: the token runs from the
			`@` to the next whitespace or the end of the line. That
			boundary is this tool's own rule, not a limit of the platform,
			so a display name containing a space cannot be written this
			way -- the platform renders such a name correctly when it is
			addressed by id.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-slack-profile-get <team-member> [--raw]
			`<team-member>` is both the acting identity and the account
			read: a profile, a presence and a do-not-disturb state each
			belong to one Slack account, so the member is the subject here,
			not a credential selector. The read-only counterpart to
			--member-comms-slack-profile-set, so a set can be verified
			rather than assumed.

			Persona identity only, on the same terms as
			--member-comms-slack-profile-set: `--identity-bot` is REFUSED
			rather than accepted-and-ignored, and a `routine-*` name is
			refused with its own message. A bot would answer for the app
			rather than for the member, which is a different account's
			answer wearing this member's name.

			Four facets, one API call each: the account's own profile
			fields, its presence, its do-not-disturb state, and the
			workspace's custom profile fields. Each
			reports `PROFILE_GET_FACET=profile|presence|dnd|custom-fields` then
			`PROFILE_GET_STATE=read|failed`, and every read facet's fields
			follow as line-anchored `KEY=value` with a `KEY_STATE=`
			companion -- `present`, `absent`, or `present-multiline` for a
			value carrying a newline, which is reported rather than printed
			so the `KEY=value` read-back contract still holds.

			The profile facet's standard-field set is emitted in this
			order: `PROFILE_DISPLAY_NAME`, `PROFILE_REAL_NAME`,
			`PROFILE_TITLE`, `PROFILE_STATUS_TEXT`, `PROFILE_STATUS_EMOJI`,
			`PROFILE_STATUS_EXPIRATION`, `PROFILE_AVATAR_URL`,
			`PROFILE_AVATAR_ORIGINAL_URL`, `PROFILE_AVATAR_HASH`,
			`PROFILE_AVATAR_IS_CUSTOM`, `PROFILE_EMAIL`,
			`PROFILE_FIRST_NAME`, `PROFILE_LAST_NAME`, `PROFILE_PHONE`.
			The presence facet emits `PRESENCE`, `PRESENCE_AUTO_AWAY`,
			`PRESENCE_MANUAL_AWAY` and `PRESENCE_CONNECTION_COUNT`; the
			do-not-disturb facet `DND_ENABLED`, `DND_NEXT_START_TS`,
			`DND_NEXT_END_TS`, `DND_SNOOZE_ENABLED` and
			`DND_SNOOZE_ENDTIME`. A facet's own emitted lines are the
			authority on what it carried: this names the standard set, not a
			promise that a facet carries nothing besides it.

			The custom-fields facet emits `PROFILE_FIELDS_COUNT` then one
			ordinal group per field: `PROFILE_FIELD_<n>_KEY`, `_LABEL`,
			`_VALUE` and `_ALT`. It joins the workspace's own field
			DEFINITIONS with this account's VALUES in them, because a field
			id is workspace-defined -- the same "Title" label is a different
			id in each workspace -- so neither body alone answers which
			fields exist and what this account holds in them. Ids from both
			sides are unioned: a definition with no value is a field left
			empty, a value with no definition is one defined after the
			definitions were read or one this identity cannot see, and both
			are real states. A count of zero is a real answer, never an
			error -- an account may have filled none, and a workspace may
			define none.

			`--raw` REPLACES the parsed field lines with each facet's own
			API response body, and keeps the `PROFILE_GET_FACET=` and
			`PROFILE_GET_STATE=` markers -- unlike the single-body raw modes
			on --member-comms-slack-file-info and
			--member-comms-slack-search-messages, this operation makes three
			calls, so three unlabelled bodies could not be told apart and a
			failed facet would contribute nothing rather than saying so.
			Use it to audit the operation against its own source data: the
			field set above is the standard set, and the body carries more
			besides -- measured, twenty-eight top-level profile keys against
			the fourteen named here. A field this operation does not surface
			is a field a set cannot be verified against, which is not
			knowable from the parsed output alone.

			Exit codes. **0**: every facet read. **3**: some read,
			the rest named with their own reason. **4**: none read, though
			the operation itself ran. **1**: the call was refused before any
			facet was reached, or a facet's response could not be parsed --
			that facet's field set is then incomplete and the facets after
			it were not attempted, so the lines already printed are not a
			full report. A failed facet is UNKNOWN, never a report that the
			field is unset.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-slack-profile-set <team-member> [--display-name <v>] [--status-text <v>] [--status-emoji <v>] [--status-expiry <ts>] [--avatar <path>] [--presence auto|away] [--snooze <minutes>|--snooze-end]
			`<team-member>` is both the acting identity and the account
			written: this sets that member's own Slack display name, custom
			status, presence and do-not-disturb state.

			Persona identity only. It acts under the member's own user token
			always; `--identity-bot` is REFUSED rather than
			accepted-and-ignored, and a `routine-*` name is refused with its
			own message. A bot and a routine own no persona, so there is
			nothing for either to set, and a member with no user token fails
			loud rather than silently writing under the shared bot.

			At least one field is required. An empty string is a value here,
			not an absence: empty `--display-name`, `--status-text` and
			`--status-emoji` each count as a field. Those three therefore
			accept an empty value; `--status-expiry` (epoch seconds, 0 for
			no expiry), `--avatar` (a path), `--presence` (`auto` or `away`,
			the only two values Slack has) and `--snooze` (a positive whole
			number of minutes) do not. `--snooze` and `--snooze-end` are
			mutually exclusive, and no field flag is repeatable.

			**A custom status is cleared by both status flags together.**
			Slack refuses an empty `--status-text` on its own with
			`must_clear_both_status_text_and_status_emoji`: the empty text
			and the empty emoji are one clear, not two independent fields.
			Pass `--status-text '' --status-emoji ''`. This is Slack's own
			rule about that pair, not a restriction added here.

			`--avatar <path>` replaces the account's photo. Slack has no
			"clear the photo" call, so a photo is replaced and never unset.
			The path is checked at parse time: it must exist and be a
			regular file, and it must contain neither `;` nor `,`, which
			multipart value syntax reads as part metadata and as a
			multi-file separator rather than as part of a filename. Both
			checks run before any request leaves the host, because a path
			fault found later would surface only after the profile fields
			had already been written. The filename itself goes on the wire.

			Up to four API calls, one per facet, reported as
			`PROFILE_SET_FACET=profile|avatar|presence|dnd` followed by
			`PROFILE_SET_STATE=applied|failed|not-requested` and the raw
			response for each applied facet. The photo is always its own
			call, never folded into the profile write. A failed facet is
			UNKNOWN, not known-unchanged. Nothing is rolled back and nothing
			is retried under another identity. **0** when every requested
			facet applied, **1** when any did not -- and a non-zero exit
			here never means the whole call failed: the facets reported
			applied really were applied.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-email-check <team-member>
			`<team-member>` is the member this check acts as, and it comes
			first. It is required, and it is strict: what is counted is that
			member's own mailbox and nothing else. There is no fallback to
			another member's scope, so a member without a mailbox of its own
			fails here rather than quietly reporting someone else's unread
			count.

			IMAP STATUS INBOX (UNSEEN) check only -- unread count, not a full
			fetch. Same EMAIL_* config as
			--member-comms-email-send.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-email-mark-seen <team-member> <uid>
			`<team-member>` is the member this mark acts as, and it comes
			first, ahead of the `<uid>`. It is required, and it is strict:
			the mailbox written to is that member's own, with no fallback to
			another member's. A UID only means anything inside one mailbox,
			so the same `<uid>` under a different member names a different
			message, or none at all.

			Marks one specific email (by IMAP UID, same identifier
			--member-comms-email-read takes) as \Seen -- otherwise every
			comms-sweep pass keeps re-seeing the same UIDs as unseen.
			Same EMAIL_* config as --member-comms-email-check/
			--member-comms-email-send.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-trello-check <team-member>
			`<team-member>` is the member this check acts as, and it comes
			first. It is required, and it is strict: the unread list returned
			is that member's own notifications, never another member's, and
			there is no fallback to another member's scope.

			Unread Trello notifications only (`read_filter=unread`), not a
			full board read. Uses configured Trello credentials.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-trello-whoami <team-member>
			`<team-member>` is the member this lookup acts as, and it is
			required: the identity returned is whoever that member's own
			Trello credentials resolve to, with no fallback to another
			member's scope.

			Call it when a report has to state WHICH Trello account a read
			was made as. Prints `TRELLO_USER_ID=` and `TRELLO_USERNAME=`,
			one per line, and returns non-zero when the identity could not
			be established — an unknown identity is never reported as an
			empty one.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-google-whoami <team-member>
			`<team-member>` is the member this lookup acts as, and it is
			required: the identity returned is whoever that member's own
			`GOOGLE_REFRESH_TOKEN` resolves to, with no fallback to another
			member's scope.

			Call it whenever the acting identity matters, and always
			immediately after filing a new refresh token. A Google refresh
			token IS an identity: one minted by consenting as the wrong
			account leaves the member acting as that other person on every
			call, with correct code and no error anywhere to notice it by.
			This operation is what turns that from undetectable into one
			command. It needs no scope beyond the Drive scope the family
			already requires.

			Prints `GOOGLE_ACCOUNT_EMAIL=`, `GOOGLE_ACCOUNT_NAME=` and
			`GOOGLE_ACCOUNT_ID=`, one per line, and returns non-zero when the
			identity could not be established — an unknown identity is never
			reported as an empty one.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-google-file-find <team-member> <search-term> [--full-text] [--include-trashed] [--limit <n>]
		--member-comms-google-file-find <team-member> <drive-query> --raw-query [--limit <n>]
			`<team-member>` is the member this search acts as, and it comes
			first. It is required and strict: the results are what that
			member's own identity can see in Drive, never another member's,
			and there is no fallback to another member's scope.

			The entry point for this family, since every other Google
			operation needs a file id and this is what produces one.

			**`<search-term>` is a plain term, not a query.** Drive's own `q`
			parameter is a structured query language rather than a search
			box — a bare word such as `ADR` is a syntax error there, not a
			match-anything — so this operation builds the query around the
			term for you: `name contains '<term>' and trashed=false`. An
			apostrophe in the term (`Bob's notes` is an ordinary filename) is
			escaped before it reaches the API rather than breaking the query.
			An empty term is refused rather than silently listing the whole
			Drive.

			`--full-text` also matches text inside document bodies, not just
			names. Off by default: it is markedly slower and returns hits
			from inside unrelated files, which is not what a search by name
			expects.

			`--include-trashed` keeps deleted files in the results. By
			default they are excluded, because a trashed file is otherwise
			indistinguishable from a live one and a caller may act on
			something already in the bin.

			`--raw-query` forwards the argument verbatim as a complete Drive
			query instead, for structured searches such as
			`mimeType='application/vnd.google-apps.spreadsheet' and trashed=false`.
			It cannot be combined with `--full-text` or `--include-trashed`:
			with `--raw-query` the argument is the whole query and those
			flags would have nothing to shape, so the combination is refused
			rather than silently ignored.

			`--limit` defaults to 50 and must be a positive whole number.

			Emits one TSV row per file: id, name, mimeType, modifiedTime.
			A search that completed and matched nothing prints no rows and
			returns zero; a search that could not be performed returns
			non-zero and says so — those are different outcomes and are never
			rendered the same way.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-google-sheet-info <team-member> <sheet-id>
			`<team-member>` is the member this read acts as, and it is
			required: a spreadsheet is readable only by identities it is
			shared with, read strictly from that member's own scope with no
			fallback.

			Tab names and grid dimensions — what a caller needs before it can
			build a range for `--member-comms-google-sheet-read`. Prints
			`SPREADSHEET_TITLE=<title>` first, then a TSV table of tabs with
			its own header row: `TAB_TITLE`, `TAB_ID`, `TAB_INDEX`, `ROWS`,
			`COLUMNS`.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-google-sheet-read <team-member> <sheet-id> <a1-range> [--unformatted]
			`<team-member>` is the member this read acts as, and it is
			required: a spreadsheet is readable only by identities it is
			shared with, read strictly from that member's own scope with no
			fallback.

			Cell values for one A1 range, emitted as TSV rather than the
			API's own JSON `values` arrays — a range is tabular, and every
			other operation in this tool is shell-consumable.

			Two conversion rules the caller can rely on:

			- **Rows are padded to the width of the requested range.** Sheets
			  omits trailing empty cells, so `A1:D10` would otherwise return
			  two fields for a row whose last two are blank, and every
			  positional consumer (`awk -F'\t' '{print $4}'`) would read the
			  wrong column with no error at all. Where the range does not fix
			  a width (a bare tab name), the widest row returned is used.
			- **Tab, newline, carriage return and backslash inside a cell are
			  escaped** as `\t`, `\n`, `\r` and `\\`. A cell may legitimately
			  contain any of them, and emitted raw a tab becomes a new column
			  and a newline a new row. The escape is reversible — undo `\\`
			  last.

			Values render as `FORMATTED_VALUE` by default: what a human
			reading the sheet sees. `--unformatted` returns the underlying
			value instead, so a date becomes its serial number.

			A range that is genuinely empty prints no rows and returns zero.
			A range that could not be read returns non-zero and says the
			values are UNKNOWN — never the same rendering as empty. A range
			outside the sheet's grid limits is an error, not an empty result.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-google-sheet-write <team-member> <sheet-id> <a1-range> [--append] [--user-entered] (--from-stdin|--from-file <path>)
			`<team-member>` is the member this write acts as, and it comes
			first: the credentials the write authenticates with are that
			member's own, strictly, with no fallback to another member's
			scope.

			Writes TSV into one A1 range. **The input format is exactly what
			`--member-comms-google-sheet-read` emits**, so a range can be
			read, edited in a shell pipeline, and written straight back — the
			round trip is byte-exact, including cells that contain tabs,
			newlines or backslashes (written as `\t`, `\n`, `\r`, `\\`).

			Content comes from `--from-stdin` or `--from-file` and never from
			trailing text arguments, because a range is tabular and a shell
			word is not. Exactly one source is required; giving both is an
			error rather than a silent precedence.

			`--append` adds rows after the existing data instead of
			overwriting the range.

			**Values are stored RAW by default, and that is a safety
			decision.** Under `--user-entered` Google parses each value as
			though a person had typed it, so any caller-supplied cell
			beginning with `=` becomes a live formula in a document real
			people will open. RAW stores exactly what was given. Use
			`--user-entered` only where a formula or a locale-parsed date is
			genuinely intended.

			On failure, whether anything was changed is UNKNOWN and must not
			be assumed to be nothing.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-google-sheet-clear <team-member> <sheet-id> <a1-range>
			`<team-member>` is the member this write acts as, and it comes
			first, read strictly from that member's own scope with no
			fallback.

			Clears the values in one A1 range. **Its own operation rather
			than a flag on `--member-comms-google-sheet-write`**, because it
			destroys data and takes no content — the same reason
			`--member-comms-slack-delete-message` and `--intern-op-board-trash`
			carry their own names. A destructive mode hidden behind a flag on
			a constructive verb reads as safer at the call site than it is.

			The range is required and is never defaulted: there is no
			whole-sheet shorthand, because a mistyped default would erase a
			spreadsheet.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-google-doc-read <team-member> <doc-id>
			`<team-member>` is the member this read acts as, and it is
			required: a document is readable only by identities it is shared
			with, read strictly from that member's own scope with no
			fallback.

			Prints the document's plain text. **Paragraph text runs only** —
			tables, embedded objects and footnotes are not rendered. Stated
			here rather than left to be inferred, because output that
			silently omits a table looks complete.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-google-doc-write <team-member> <doc-id> (<text...>|--from-stdin|--from-file <path>)
			`<team-member>` is the member this write acts as, and it comes
			first, ahead of the document: the credentials are that member's
			own, strictly, with no fallback.

			**Appends** text to the end of the document. Append-only,
			deliberately: replacing a document's whole body means computing
			and deleting its existing content range first, which is
			destructive and structural, and if it is ever wanted it belongs
			in its own operation — the same reasoning that gave
			`--member-comms-google-sheet-clear` its own name instead of a
			flag.

			Exactly one content source: trailing text, `--from-stdin`, or
			`--from-file`. Giving more than one is an error, and giving none
			refuses rather than appending nothing and reporting success.

			On failure, whether anything was written is UNKNOWN and must not
			be assumed to be nothing.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-google-comment-read <team-member> <file-id>
			`<team-member>` is the member this read acts as, and it is
			required: comments are visible only to identities the file is
			shared with, read strictly from that member's own scope with no
			fallback.

			Comments on one Drive file — a Doc and a Sheet alike, since
			comments are a Drive resource rather than a per-type one. Emits
			TSV with its own header row: `COMMENT_ID`, `AUTHOR`, `CREATED`,
			`RESOLVED`, `CONTENT`.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-google-comment-post <team-member> <file-id> (<text...>|--from-stdin|--from-file <path>)
			`<team-member>` is the member this write acts as, and it comes
			first, ahead of the file: a comment is authored by one identity,
			so the acting member decides which account signs it, read
			strictly from that member's own scope with no fallback.

			Posts one comment onto one Drive file. Exactly one content
			source: trailing text, `--from-stdin`, or `--from-file`.

			Prints `COMMENT_ID=` and `COMMENT_CREATED=` on success. A
			response carrying no id is reported as UNKNOWN rather than
			success — a positive test on what is present, not an assumption
			drawn from a 2xx status.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-jira-whoami <team-member>
			`<team-member>` is the member this lookup acts as, and it is
			required: the identity returned is whoever that member's own
			`JIRA_USER`/`JIRA_API_TOKEN` resolve to, with no fallback to
			another member's scope.

			Jira keeps its own key set — `JIRA_SITE`, `JIRA_USER`,
			`JIRA_API_TOKEN` — even where one Atlassian token also serves
			Confluence on the same site. A `CONFLUENCE_*` value is never read
			here, so either service's credential can be rotated, revoked or
			pointed at another account without disturbing the other.

			Call it first after a token is filed, and whenever a report has to
			state WHICH Jira account a read was made as. Prints
			`JIRA_ACCOUNT_ID=`, `JIRA_ACCOUNT_EMAIL=` and
			`JIRA_ACCOUNT_NAME=`, one per line, and returns non-zero when the
			identity could not be established — an unknown identity is never
			reported as an empty one.

			It is also the only operation here that reports a bad credential
			as one: Jira treats a request carrying a rejected token as
			anonymous, and a private issue is invisible to anonymous, so an
			issue read answers "not found" rather than "not authorised".
			Diagnose a credential with this operation, never with a read that
			failed.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-jira-issue-search <team-member> <jql> [--limit <n>]
			`<team-member>` is the member this search acts as, and it comes
			first. It is required and strict: the results are what that
			member's own identity can see in Jira, never another member's,
			and there is no fallback to another member's scope.

			The entry point for this family, since the issue operations need
			an issue key and this is what produces one.

			The JQL is passed through as given, the way the Confluence
			family passes CQL: it is the documented query surface a caller is
			expected to write, and it has no single safe general wrapping.
			Jira refuses an unrestricted query outright, so the JQL names at
			least one restriction — `project = DATA ORDER BY updated DESC`,
			`assignee = currentUser() AND statusCategory != Done`.

			**An empty result is not evidence that nothing matches.** Jira
			answers a query naming a project that does not exist, and one
			that is not JQL at all, with a success and an empty page rather
			than an error, so a zero-row result means only that this exact
			query matched nothing — re-check the query itself. The operation
			says so on stderr whenever it returns no rows.

			Emits one TSV row per issue with its own header row:
			`ISSUE_KEY`, `TYPE`, `STATUS`, `ASSIGNEE`, `UPDATED`, `SUMMARY`.
			`--limit` defaults to 25 and must be a positive whole number.
			The endpoint pages by token and reports no total, so when more
			issues match than the page carries, the operation says that on
			stderr and how many more is unknown; raise `--limit` or narrow
			the query.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-jira-issue-read <team-member> <issue-key> [--format adf|rendered]
			`<team-member>` is the member this read acts as, and it is
			required: an issue is readable only by identities its project is
			shared with, read strictly from that member's own scope with no
			fallback.

			The description goes to stdout and the identifying metadata to
			stderr, so `issue-read > file` yields the description and nothing
			else. Type, status, resolution, assignee, reporter, priority,
			created, updated, labels and summary are the stderr diagnostics.

			`--format adf` is the default: the Atlassian Document Format JSON
			Jira accepts back on a write, so read-edit-write stays possible
			once the write side exists. `--format rendered` returns Jira's
			own HTML instead — what a human reads, and it cannot be written
			back.

			An issue whose description field came back null really has no
			description: stdout stays empty, stderr says so, and the
			operation returns zero. That is a different outcome from a read
			that failed, which returns non-zero and reports the content as
			UNKNOWN. A 404 from Jira does NOT establish that the issue is
			absent — Jira returns 404 both for a missing issue and for one
			this account cannot see, and says so itself.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-jira-comment-read <team-member> <issue-key> [--format adf|rendered]
			`<team-member>` is the member this read acts as, and it is
			required: comments are visible only to identities the issue is
			shared with, read strictly from that member's own scope with no
			fallback.

			Comments on one issue, as TSV with its own header row:
			`COMMENT_ID`, `AUTHOR_ID`, `AUTHOR_NAME`, `CREATED`, `UPDATED`,
			`BODY`. `--format` carries the same meaning as it does for
			`--member-comms-jira-issue-read`, applied to each comment body:
			`adf` (default) emits the Atlassian Document Format JSON on one
			line, `rendered` emits Jira's own HTML.

			An issue carrying more comments than one page holds is reported
			on stderr, naming how many exist and how many were read.

			**This family is read-only.** There is no operation here that
			creates or edits an issue, a comment or a field, and that is a
			sequencing decision rather than an omission — the write side is
			its own separate piece of work.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-comms-trello-post-comment <team-member> <card-id> [text...]
		--magic-comms-trello-post-comment <team-member> <card-id> --from-stdin
		--magic-comms-trello-post-comment <team-member> <card-id> --from-file <path>
			`<team-member>` is the member this write acts as, and it comes
			first, ahead of the card. It is required: a comment is authored by
			one identity, so the acting member decides which Trello
			credentials sign it, read strictly from that member's own scope
			with no fallback.

			Direct Trello write operation for process-flow use (no
			console-session mechanism required): posts one comment onto one
			card (`/1/cards/{id}/actions/comments`) using
			that member's configured Trello credentials. Exactly one
			content source: trailing text args, --from-stdin, or --from-file.
			Returns Trello API response JSON on success.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--self-test
			Self-check: confirms the credential-store permission-hardening
			path holds even under a permissive shell umask. Takes no
			arguments. Leaves no residue in the real credentials file
			whether it passes or fails.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--verify-permissions
			Checks the credential store's file/directory permissions are
			correctly hardened. Prints one `OK`/`BAD` line per path to
			stdout, returns non-zero if anything is out of hardening.
			Read-only, modifies nothing.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--librarian-list-team-files [<path>...]
			Read-only path listing of skill-folder files. The faster of
			the two listing ops — prefer this one when mtimes aren't
			needed. Zero or more optional scope
			arguments, each either a bare path relative to the skill-root
			(`$HOME/.claude/skills/`) or an absolute path that must resolve
			inside it (anything outside is rejected and skipped, not
			silently ignored); a bare file scopes to just that file, a directory
			scopes recursively. No arguments means the whole skill-root.
			Only `*.md` files are listed — a deliberate whitelist, so any
			non-markdown file in the skill-root (`.DS_Store` and anything
			like it) never appears. Note the corner this creates: a bare
			non-`*.md` path given as a scope argument passes the
			existence check and then contributes nothing to the output —
			it is filtered out silently, so an empty result for such an
			argument is expected behaviour, not an error.
			Prints one skill-root-relative path per matched file (never
			absolute), sorted alphabetically.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--librarian-list-team-files-dates [<path>...]
			Same listing, plus each file's mtime. Slower than the plain
			listing — use only when mtimes are actually needed (staleness
			sweeps, mtime-before-editing checks). Same scope-argument
			grammar and error handling as --librarian-list-team-files,
			including the same `*.md`-only whitelist and the same
			silently-filtered non-`*.md`-scope-argument corner.
			Prints one
			line per matched file: mtime (`YYYY-MM-DD HH:MM:SS`) then two
			spaces then the path relative to the skill-root (never
			absolute), sorted newest-first.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--librarian-inbox-item-trash <team-member> <item-filename> --from-inbox:<member>
			Discards one already-processed inbox item:
			`inboxes/<member>/processed/<item-filename>`.
			`--from-inbox:` is colon-style, never a spaced pair — a spaced
			pair would silently swallow a neighbouring option. `<member>`
			must be a bare name; `<item-filename>` must be a bare filename
			ending in `.md`.

			**The operation itself has no inverse, whatever team-data's git
			state.** When team-data is git-tracked, the item is deleted
			outright and the deletion committed — no copy is left anywhere.
			When it is not, the item is moved to trash/ instead, recoverable
			only by hand — this op still won't restore it.

			Calibrate a batch accordingly: git-tracked team-data offers no
			recovery at all.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--librarian-inbox-to-processed <team-member> <item-filename> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves one item OUT of `<team-member>`'s own live inbox ROOT into
			that same inbox's `processed/` — reads
			`inboxes/<team-member>/<item-filename>`, writes
			`inboxes/<team-member>/processed/<item-filename>`, and deletes
			the original. `<item-filename>` must be a bare
			filename ending in `.md`. Unlike its sibling above, there
			is no `--from-inbox:<member>` here — the source and the acting
			member are the same one positional, since the source is that
			member's own inbox root, not a cross-member processed/ item.
			`--from-state:`/`--from-inbox:` are both rejected outright if
			given. `--header:*` and the three body-input modes behave
			exactly as they do on the `--magic-board-to-*` family. Refuses
			rather than overwrites if
			`processed/` already holds that basename, leaving
			the source in place, so a refused call is safe to fix and
			re-run.

			**ONE-WAY**: there is no inverse, and the original root file is
			deleted once the processed/ copy is written. Treat every call as
			final.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-inbox-note-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]
			Writes (creates or overwrites) a note into your own personal
			inbox. <member> must already exist as a real
			skill directory; <item-filename> must be a bare filename. The
			inbox/ directory is created lazily if it doesn't exist yet (a
			missing inbox/ is not an error, unlike a missing board-state
			directory, since board states are a fixed known set and a
			member's inbox may simply not have been created yet). Content
			via stdin by default, or via --from-file <path> -- either
			overwrites the target outright. --edit-patch-from-stdin instead
			takes a JSON array of {"old": <text>, "new": <text>,
			"replace_all": <bool, default false>} patch objects on stdin
			and applies each, in order, as an exact literal (non-regex)
			substring match-and-replace against the existing note -- a
			patch whose old text isn't found, or matches more than once
			without replace_all, fails loud before anything is written.
			Renamed from --member-upsert-inbox-note (itself earlier renamed
			from --write-inbox-note) — both old names still work, unchanged,
			as thin backward-compatible shims calling this op, but neither
			is documented separately here.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-upsert-member-inquiry <member> <item-filename> [--from-file <path>]
			Passes an inquiry into a specific member's own personal inbox,
			the standard mechanism for handing something off to another
			team member. <member> must already exist as a real skill
			directory; <item-filename> must be a bare filename. The
			inbox/ directory is created lazily if it doesn't exist yet.
			Content via stdin by default, or via --from-file <path>.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-inbox-reflection-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]
			Writes (creates or overwrites) a reflection-type item into a
			member's own personal inbox. <member> must already exist as a
			real skill directory; <item-filename> must be a bare filename.
			The inbox directory is created lazily if it doesn't exist yet.
			Content via stdin by default, or via --from-file <path> -- either
			overwrites the target outright. --edit-patch-from-stdin IS
			accepted here (unlike --member-upsert-member-inquiry, which
			rejects it) and behaves exactly as on
			--member-inbox-note-upsert: a JSON array of {"old": <text>,
			"new": <text>, "replace_all": <bool, default false>} patch
			objects on stdin, each applied in order as an exact literal
			(non-regex) substring match-and-replace against the existing
			item, failing loud before any write if a patch's old text isn't
			found or matches more than once without replace_all.

			Mechanically identical to --member-inbox-note-upsert (both are
			thin wrappers over the same shared write primitive; neither calls
			the other) -- kept as its own distinctly-named op because
			reflection notes are an established content family in this team's
			inboxes: a frontmatter block followed by a "# Reflection: <title>"
			heading and "## What happened"/"## Why this is worth keeping"
			sections, as distinct from a plain free-form note or a passed
			inquiry. <item-filename> is conventionally expected to contain
			"reflection-" in its slug, matching every existing example, but
			that is a naming convention to follow, not something enforced by
			this operation. Renamed from --member-upsert-inbox-reflection —
			the old name still works, unchanged, as a thin backward-compatible
			shim calling this op, but is no longer documented separately here.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-append-session-transcript <team-member> --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <verbatim-text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> --workspace-root <path> [--create]
			Appends exactly one canonical transcript-entry block:
			<speaker-name> (<timestamp>): followed by quoted message lines.
			Transcripts save under the team's shared audit tree -- not a
			board/<state>/ folder (the real board state names are
			backlog/pending/running/blocked/parked/processed/archived/
			retained). <YYYY-MM> is derived from the date
			embedded in <transcript-file-name> (transcript-YYYY-MM-DD-*),
			falling back to the current UTC year-month otherwise.
			<team-member> is an enforced first positional argument, not a
			--member flag. It must already be a real team member (sanity check);
			the target month's own bucket is
			created on demand if missing (same laziness as
			--member-inbox-note-upsert's inbox handling). --workspace-root is
			still required and validated (absolute, existing directory) but
			does not determine the target path. Does not rewrite prior content.
			Missing target transcript is an error unless --create is passed.
			Payload must be provided by exactly one source: --message,
			--from-stdin, or --from-file <path>.
			Returns append audit details: target path plus added line and byte
			counts.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-inbox-item-read <member> <item-filename> [--start-line <N> --end-line <N>]
			Read-only accessor for one item in a member's own personal inbox,
			by bare <item-filename> filename. <member> is both the
			sanity-checked caller identity and the actual inbox searched --
			same convention --member-inbox-note-upsert already uses for
			whose inbox a write targets. Searches the live inbox root first,
			then its own processed/ subfolder, first match wins.
			<item-filename> must carry one of the four legitimate
			personal-inbox type prefixes -- note-/inquiry-/reflection-/
			warning- -- enforcing the type policy directly from the
			filename, the same way --member-read-audit-item restricts to
			transcript-* names. Optional line range is supported via
			--start-line/--end-line and must be provided as a complete pair.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-read-audit-item <team-member> <document-name> [--start-line <N> --end-line <N>]
			Read-only accessor for one audit document by logical identity,
			not by caller-provided filesystem path. The caller provides only
			<team-member> and a bare <document-name> filename. The operation
			validates member existence, rejects path-like names, and resolves
			the document's actual location itself -- lookup order is the
			operation's own concern, not caller-supplied. Fails loud if missing or
			ambiguous. It currently permits only transcript-* file names,
			enforcing the type policy directly from the filename.
			Optional line range is supported via --start-line/--end-line and
			must be provided as a complete pair.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-read-board-item <team-member> <item-name> [--board-state <state>]... [--start-line <N> --end-line <N>]
			Read-only accessor for one board item by bare <item-name> filename.
			<item-name> must match <type>-<name>.md. Optional repeatable
			--board-state narrows lookup folders; when omitted, all board
			states are searched in canonical order. Resolution and read
			validation are the operation's own concern, not caller-supplied.
			Optional line range is
			supported via --start-line/--end-line and must be provided as a
			pair.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--owner-workspace-upsert <path>
			Adds one filesystem path to the human-owner's tracked workspace
			list at $HOME/.claude/skills/human-owner/human-owner.workspaces.md
			-- a bare, one-absolute-path-per-line file that is the ONLY
			authoritative source of truth for the workspace paths the
			magic-* team tracks (see magic-team.armed.md's "Workspace" term
			entry for the model this backs -- that file never states a
			literal path itself). <path> must be absolute (starts with `/`);
			a single trailing slash is stripped before comparing/storing, so
			`/foo/bar` and `/foo/bar/` collapse to the same entry. Idempotent
			-- upserting an already-tracked path is a harmless no-op, not an
			error. Existence of <path> on disk is not checked (a tracked
			workspace may live on a currently-unmounted volume). The
			human-owner skill directory itself must already exist (it does,
			as a standing skill folder) -- this op does not create that
			directory, only the workspaces.md file inside it on first use.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--owner-workspace-forget <path>
			Removes one filesystem path from the same tracked workspace list.
			Same trailing-slash normalization as --owner-workspace-upsert.
			Forgetting a path that isn't tracked, or when the file doesn't
			exist yet at all, is a harmless no-op, not an error.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--owner-workspace-list
			Prints every currently-tracked workspace path, one per line, in
			file order -- reads only lines that look like an absolute path
			(start with `/`), so any stray non-data content in
			human-owner.workspaces.md is never treated as data. Takes no
			arguments. Prints nothing (and does not error) if the file
			doesn't exist yet or has no tracked paths.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--owner-workspace-current
			Registers this tool's own workspace root ($MMDAPP) into the
			tracked workspace list (delegates to --owner-workspace-upsert
			internally, so the same idempotent/no-error-on-already-tracked
			behavior applies), then prints that path to stdout. Takes no
			arguments. Convenience op for a caller that wants "track my
			current workspace and tell me its path" in one call instead of
			spelling out $MMDAPP itself for --owner-workspace-upsert.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--install-claude-permissions
			Merges myx.distro-agents' own mandatory Claude Code permission
			grants into `$HOME/.claude/settings.json`'s `permissions.allow`/
			`permissions.deny` -- a JSON-safe merge (awk, the same
			structural walker `AgentsMcpServerJsonUpsert.awk` uses; no jq
			dependency), never a blind overwrite: every entry already
			present that this op did not itself add is kept. Takes no
			arguments.
			Resolves `$MDAT_DATA_ROOT/board` (already resolved by
			`DistroAgentsTools()` at entry from the `TEAM_DATA_DIRECTORY`
			config key, never re-derived here) and upserts
			`Edit(<board>/**)`/`Write(<board>/**)` into `allow` -- any
			prior board grant (any root) is dropped first, so a moved
			board path replaces rather than accumulates alongside the new
			one. Also upserts the fixed static grants
			`mcp__myx_distro__execute`, `Agent`, `Task`, plus one
			`Edit(<path>/**)`/`Write(<path>/**)` pair per acting team
			member's real skillset directory -- enumerated fresh every run
			from `$HOME/.claude/skills` (symlink or real directory, real
			path resolved via `cd` + `pwd -P`), skipping `trash` and
			skipping any member whose `SKILL.md` marks it
			`status: reference-only` (the human-owner's own non-acting
			record), so a member added or removed there is picked up
			automatically, never hand-maintained. Upserts the native Slack
			MCP server (`mcp__claude_ai_Slack`) into `deny`, unconditionally
			-- a different, separate path from the team's own sanctioned
			`--member-comms-slack-*` Bash ops, which this cannot reach.
			Both generated arrays are written fully sorted (not
			merge-order) for reviewability.
			Deliberately `$HOME`-scoped, not workspace-scoped: the Slack
			deny must hold in every workspace/session, which only the
			user-global settings file provides.
			Fails loud and leaves the target file untouched if
			`$MDAT_DATA_ROOT` cannot be resolved (`TEAM_DATA_DIRECTORY` not
			configured) or the merge itself fails. A run that changes
			nothing (already current) is reported as such, not silently
			treated the same as a write.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--install-workspace-restrictions [--workspace <path>]
			Installs Claude Code WORKSPACE-level permission rules -- a
			standing Read allow-grant, deny rules, plus `PreToolUse` hooks
			-- into a target workspace's own `.claude/settings.json`, so a
			future session in that workspace cannot bypass the deny rules
			just by not remembering a CLAUDE.md instruction, and does not
			hit an interactive prompt for a plain read under the
			workspace's own source tree either. Distinct from
			`--install-claude-permissions` above: that op is `$HOME`-scoped
			and merges the team's own mandatory grants; this one is
			workspace-scoped and merges this fixed set of rules -- the two
			touch different files and neither substitutes for the other.
			Upserts `Read(//<workspace>/source/**)` into
			`permissions.allow` -- resolved per target `<workspace>`, never
			hardcoded. Covers every source-symlinked skillset file for this
			workspace (`--install-skillset-symlinks` links a member's
			skills-dir slot into this same `source/` tree) plus every other
			file under it, so a plain skillset/MAGIC.md/source read here
			never triggers an interactive permission prompt. A prior grant
			for a DIFFERENT source root (e.g. after a workspace move) is
			replaced, not accumulated alongside the new one -- same
			replace-not-accumulate shape `--install-claude-permissions`'s
			own board grant uses. Note the required double-slash: a single
			leading slash in a permission-rule path anchors at the
			settings source (e.g. `$HOME` for a user-scope file), not the
			filesystem root -- `//` is what selects an absolute filesystem
			path (Claude Code's own permissions documentation).
			A workspace whose own skillset members live in a DIFFERENT
			workspace's `source/` tree (a `keeper-*`/`partner-*` member
			declared by a project outside this one) is not reached by this
			grant -- configure that other workspace directly via its own
			`--workspace <path>`, never by reaching across workspaces from
			here.
			Also upserts a fixed set of extra `Read` allow-grants, the SAME
			for every target workspace (unlike the source-tree grant above,
			never derived from `<workspace>`): real, external filesystem
			locations outside any workspace's own `source/` tree that this
			ecosystem's agents routinely need plain read access to. Currently
			one entry, `Read(//Volumes/workspace/myx/**)` -- the canonical,
			editable AE3 legacy Eclipse-project checkout. Kept short and
			evidenced, grown only when live use actually hits the
			interactive prompt for a real path, never speculatively. Each
			entry is added if missing and left alone if already present --
			unlike the source-tree grant's replace-not-accumulate handling,
			there is no "moved" case for a fixed external root, so nothing
			is ever removed here even if a future entry is dropped from the
			op's own fixed list.
			Default target workspace is the current shell directory;
			optional `--workspace <path>` overrides it. Refuses (exit 1,
			nothing written) when `<workspace>` is not a genuine workspace
			root: checks `<workspace>/.local` exists as a directory, the
			same test every generated console script (DistroSourceConsole.sh
			etc.) performs on itself at its own startup -- not a new check
			invented for this op. Confirmed error shape (a nested
			sub-project/repo given by mistake, e.g. a leaf repo under a real
			workspace's own `source/`):
			```
			⛔ ERROR: DistroAgentsTools --install-workspace-restrictions: not a workspace root: <workspace> -- expected '<workspace>/.local' to exist (the same check every DistroSourceConsole.sh/DistroDeployConsole.sh/etc. performs on itself at startup), but it is missing. This looks like a sub-project/repo living inside a real workspace, not the workspace root itself.
			   likely correct root: <ancestor> (found '<ancestor>/.local')
			```
			The `likely correct root:` hint line is printed only when an
			ancestor directory with its own `.local` is actually found by
			walking up from `<workspace>` to `/`; omitted entirely when none
			is found (e.g. `<workspace>` is not under a real workspace at
			all), never a guessed/fabricated suggestion.
			Once past this guard, creates
			`<workspace>/.claude/` and `<workspace>/.claude/hooks/` if
			missing, and creates `<workspace>/.claude/settings.json` as `{}`
			if it does not already exist -- never overwrites an existing
			one, only merges into it (awk, the same structural walker
			`AgentsClaudeSettingsPermissionsUpsert.awk`/
			`AgentsMcpServerJsonUpsert.awk` use; no jq dependency): every
			entry already present that this op did not itself add is kept,
			at both the JSON level and the file level.
			Writes two hook scripts into `<workspace>/.claude/hooks/`
			(mode 0755, regenerated idempotently every run --
			tmp+`cmp`+`mv`, a no-op run touches nothing):
			`deny-memory-md-read.sh` (denies `Read` on the memory-system's
			`MEMORY.md` index file, any workspace/project, with reason
			"read workspace, repository and project MAGIC.md") and
			`deny-bash-tool.sh` (denies every `Bash` tool call outright,
			with reason "always use MCP TOOLING to properly execute shell
			commands" -- this also fully covers `python3`/`rm`/`mv`/
			anything else run through Bash, since nothing reaches a shell
			any other way). Neither writes nor touches
			`protect-memory-md.sh` (the already-verified `Edit`/`Write`
			MEMORY.md guard) -- that hook, and its own `hooks.PreToolUse`
			entry, are left exactly as found.
			Wires both new scripts into `hooks.PreToolUse` (matcher `Read`
			and matcher `Bash` respectively) and adds
			`"Bash"`, `"Bash(mv *)"`, `"Bash(python3*)"`, `"Bash(rm *)"` to
			`permissions.deny`. The bare `"Bash"` entry (same shape as
			`--install-claude-permissions`' own bare `"mcp__claude_ai_Slack"`
			entry) already denies the whole tool on its own, so the three
			scoped patterns are defense-in-depth, not load-bearing today --
			they keep `python3`/`rm`/`mv` denied on their own if the
			wholesale `"Bash"` entry or the hook above is ever loosened
			later. `MEMORY.md` `Edit`/`Write`/`Read` denial relies on the
			hooks alone (for the custom reason each needs); no
			`permissions.deny` entry is added for either, since a hook's
			`permissionDecision: deny` already blocks the call without one.
			A run that changes nothing (already current) is reported as
			such, not silently treated the same as a write.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--install-skillset-symlinks [--scope workspace|user-home] [--workspace <path>]
			Installs skillset-link integration. `$MDLT_ORIGIN/myx/
			myx.distro-agents/skillset/magic-team` is the operation's source
			skillset directory used for link targets.
			Target roots are the hidden skills directories below, all
			created if missing:
			`<workspace>/.agents/skills` and `<workspace>/.claude/skills`
			for `--scope workspace`, at the
			WORKSPACE ROOT; `$HOME/.agents/skills`, `$HOME/.copilot/skills` and
			`$HOME/.claude/skills` for `--scope user-home`. Every root gets the
			same members and its own registry file.
			Two distinct mechanisms populate `target/`, not one:
			(1) **Bundle members**: for each member directory under the
			bundle root (`myx.distro-agents/skillset/magic-team`, skipping
			`trash`), ensures target/member is a symlink to bundle/member.
			A name present in a target root but not in the bundle is not
			this mechanism's concern: mechanism (2) below covers a member
			this workspace declares, and a member another workspace
			installed into the same root is left as it stands.
			(2) **Declared team-members**: separately, every workspace
			project that declares `magic-team:team-member:skillset/<name>:
			<host-glob>` in its own `project.inf` (matched against this
			host's `hostname -s`/`hostname`) gets `<name>` symlinked at
			`target/<name>`, pointing at that project's own
			`skillset/<name>` directory — real, live code path
			(`AgentsTools.Install.include`'s declared-team-member loop),
			not dead/reserved. This is the actual mechanism behind
			`keeper-ndm`, `keeper-ae3`, `keeper-mel`, `partner-ndm-camunda`,
			and any other `keeper-*`/`warden-*`/`partner-*`/`client-*`/
			`oncall-*`/`expert-*` member whose owning project declares it —
			each lives in its own separate owning repo, outside the single
			shared bundle, and reaches `target/` through this second path
			instead. A member declared by more than one project becomes a
			composite (`rsync`'d union into `$workspace/.local/agents/
			magic-team-composite/<name>`, later collisions logged, last
			source wins per colliding path); a name declared by a project
			AND present in the bundle is a collision — the bundled copy
			keeps the slot, the declared source(s) are shadowed with a
			warning, neither silently overwritten.
			In both mechanisms: an already-correct symlink is kept; a
			symlink pointing at a different target is also kept as-is and
			registered at the target it actually points to, not the one it
			would have been given; a dangling symlink is reclaimed and
			relinked. Only real (non-symlink) content at the target, or a
			link-creation failure, is an error — nothing is ever
			overwritten.
			With no `--scope`, default is workspace; if the resolved workspace
			is not a set-up myx.distro workspace and scope was not explicitly
			provided, falls back to user-home. If `--scope workspace` was
			explicitly requested for a non-set-up workspace, this is an error.
			Default workspace is current shell directory; `--workspace <path>`
			overrides it.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--install-vscode-integrations [--workspace <path>]
			Installs/updates baseline VS Code + Claude Code integrations.
			Installs NO extensions and never invokes the `code` CLI --
			which chat client is installed is the user's own choice; this
			op only configures the workspace so that whichever client is
			present can use it. Upserts MCP wiring for every client, in
			three places:
			workspace `.vscode/mcp.json` with a `servers."myx.common"` stdio entry
			(VS Code/Copilot-Chat's own schema); workspace-root `.mcp.json`
			with a `mcpServers."myx.common"` stdio entry (Claude Code's own
			project-scope schema -- Claude Code does not read
			`.vscode/mcp.json` -- and also what Copilot CLI reads since it
			dropped `.vscode/mcp.json` support); and Claude Code's home
			local scope, `~/.claude.json`'s
			`projects["<workspace>"].mcpServers."myx.common"`, delegated to
			myx.common's own `setup/agentMcp` so that file keeps being edited
			by its one owner. All three register the same resolved myx.common
			`bin/lib/agentMcpServer.Common`, launched with `--run` (without
			`--run` that script prints usage and exits instead of serving, so
			the `args` are what make the entry actually work). Each written
			file is verified by re-reading the `myx.common` entry and asserting
			both its `command` and its `args`, that no other entry in the same
			object launches a command from inside the myx.common tree, and is
			left at mode 0644 regardless of the caller's umask.
			Default target workspace is the current shell directory; optional
			`--workspace <path>` overrides it. Fails fast if the target isn't
			already a set-up myx.distro workspace (checks for
			`.local/myx/myx.distro-.local/sh-lib/LocalContext.include`).
			A missing VS Code CLI (`code`) is irrelevant to this op and is
			neither checked nor reported. A missing `~/.claude.json` (Claude Code never
			run on this machine yet) is a warning only -- the workspace
			`.mcp.json` covers Claude Code here on its own. Prints a compact
			OK/FAIL checklist, plus Command Palette trust/restart guidance
			for MCP visibility.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--install-workspace-integrations [--scope workspace|user-home] [--workspace <path>]
			Composed integration op: runs
			`--install-vscode-integrations` first, then
			`--install-skillset-symlinks` against the same workspace, then
			`--install-claude-permissions` (this last step takes no
			arguments and is unaffected by `--scope`/`--workspace`, since
			it merges into the user-global `$HOME/.claude/settings.json`,
			not a workspace-local file).
			If `--scope` is provided, forwards it directly to
			`--install-skillset-symlinks`.
			With no `--scope`, runs the user-home step and then the workspace
			step -- both unconditionally, since `$HOME/.claude/skills` is
			where every VS Code panel-facing client reads the team skillset
			from and on a machine set up from scratch it does not exist yet.
			The MCP/integration step runs before them, so a workspace is
			registered even when the skillset step cannot complete. Fails
			fast if any executed step fails. An empty value for `--scope` or `--workspace` is rejected
			rather than silently treated as absent.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--make-workspace-integrations [--quiet]
			Runs all relevant `--make-*` commands (--make-console-command),
			then --install-workspace-integrations against the same workspace,
			thus (re-)creating all agents workspace integration files and exits.

			Won't output helpful information on files created and how to use
			those files, when `--quiet` option specified.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--make-console-command [--quiet]
			Re-Creates DistroAgentsConsole.sh script to be used as a command to
			quickly enter workspace console and exits.

			Won't output helpful information on files created and how to use
			those files, when `--quiet` option specified.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--make-console-script
			Prints agents console script body (used by --make-console-command)
			and exits.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-to-backlog <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves a board item to board/backlog/ and/or patches its
			frontmatter, one call -- no full-content rewrite required
			(--upsert-from-stdin/--edit-script-from-stdin/
			--edit-patch-from-stdin remain available for one).
			--edit-patch-from-stdin takes a JSON array of
			`{"old": <text>, "new": <text>, "replace_all": <bool, default
			false>}` patch objects on stdin and applies each, in order, as an
			exact literal (non-regex) substring match-and-replace against the
			body -- a small localized body edit without supplying the whole
			new body verbatim or writing a full script. --from-state:<state>
			and --owner-header-value are both required; groomed-at/groomed-from/track are
			always auto-stamped, never caller-supplied. --header:*/
			--upsert-from-stdin/--edit-script-from-stdin/
			--edit-patch-from-stdin pass straight through for whatever else
			the move also needs. Own dedicated case arm, not shared with
			--magic-grooming-to-pending/-processed (room for its own future
			backlog-specific validation).

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-to-pending <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as --magic-grooming-to-backlog, target fixed to
			board/pending/ -- the Advancement-review case (backlog->pending,
			e.g. --header:upsert:approved-by:"<team-member> (<session-id>,
			<date-time>)" --header:upsert:approved-at:<date>). approved-by's
			value is validated: must match <team-member> (<session-id>,
			<date-time>) with an ISO UTC date-time (suffix Z). Own dedicated
			case arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-to-processed <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as --magic-grooming-to-backlog, target fixed to
			board/processed/. Own dedicated case arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-to-parked <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as --magic-grooming-to-backlog, target fixed to
			board/parked/ -- routine-grooming's own Defer outcome, a
			deliberate deferral by the team's own choice (distinct from
			board/blocked/, which is a stall on something external).
			owner/groomed-at/groomed-from/track are stamped exactly as the
			other grooming ops stamp them. recheck-date and condition, the
			fields a parked item actually needs, are caller-supplied via
			--header:* -- they are triage judgments this op cannot compute.
			Own dedicated case arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-to-blocked <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as --magic-grooming-to-backlog, target fixed to
			board/blocked/ -- routine-grooming's own stalled-on-something-
			external outcome, as distinct from board/parked/, where the team
			deliberately chooses to stop pushing. Replaces the two-call
			write-then-remove recipe routine-grooming previously used for
			this move. owner/groomed-at/groomed-from/track are stamped exactly
			as the other grooming ops stamp them -- that stamping is what
			distinguishes this op from --magic-board-to-blocked, which targets
			the same state but stamps nothing and belongs to
			check-process-board rather than routine-grooming. recheck-date and
			condition are caller-supplied via --header:*. Own dedicated case
			arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-to-running <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as --magic-grooming-to-backlog, target fixed to
			board/running/ -- routine-grooming's own check-backlog-promote
			dispatch, "once the thread is genuinely active, move the item to
			board-running", which that step previously did as a two-call
			write-then-remove move. Distinct from --magic-advance-to-running,
			which targets the same state: that one is routine-advance's own
			dispatch and auto-stamps started-at, while this one is
			routine-grooming's and stamps owner/groomed-at/groomed-from/track
			instead. Same target state, different owning routine, different
			recorded provenance. Anything this op does not own -- started-at
			included -- is caller-supplied via --header:*. Own dedicated case
			arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-to-archived <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as --magic-grooming-to-backlog, target fixed to
			board/archived/ -- routine-grooming's own Drop outcome (dropped
			with no future intent), plus the two archived exits from its
			re-check steps: a board-parked item whose trigger the group
			concludes is never coming, and a board-blocked item the group
			decides is not worth even waiting on. Replaces the two-call
			write-then-remove recipe that routine-grooming previously
			prescribed for this move. board-archived being terminal is not a
			reason to withhold the grooming stamps --
			--magic-grooming-to-processed already stamps the same set onto a
			terminal state, and who archived an item, and out of which state,
			is exactly what a later reader of an archived item needs. The
			archived item's own reason text stays caller-supplied via
			--header:* or the body-input modes. Own dedicated case arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-to-retained <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as --magic-grooming-to-backlog, target fixed to
			board/retained/ -- but for a SAME-STATE PATCH, not a move.
			routine-grooming does not move items into board-retained, and this
			op is not evidence that it does: putting an item into
			board-retained is routine-heartbeat's own GC diversion. This op
			serves one case from routine-grooming's board-retained
			recheck-and-exit step -- "still referenced, stays, recheck-date
			renewed" -- which was previously a single raw write in the
			same state. Called with --from-state:retained, so source and
			target match and nothing relocates: the intern-op
			reads-and-preserves the existing body whenever --from-state equals
			the target state, the same same-state mechanism
			--magic-advance-to-running uses with --from-state:running. The
			renewed recheck-date is caller-supplied via --header:*. Grooming's
			owner/groomed-at/groomed-from/track stamps apply as with every
			sibling; on a same-state call groomed-from records retained, which
			says the item was groomed while sitting in retained, not that it
			arrived from elsewhere. Own dedicated case arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-create-backlog <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
			Creates a board-item directly in board/backlog/ -- routine-grooming's
			own first write of that item, not a move. The Promoted default landing for an inbox item the authority group promotes.
			--from-state: is rejected here: a created item has no source
			state. owner/groomed-at/track are stamped as elsewhere in this
			family; groomed-from deliberately is NOT -- it records the state
			an item moved from, and a created item moved from nowhere. One
			body-input mode is required: there is no existing body to carry
			forward. communication-channel-id, approved-by/approved-at,
			blocks/blocked-by and references ride --header:* in
			this same single write. Own dedicated case arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-create-processed <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
			Creates a board-item directly in board/processed/ -- routine-grooming's
			own first write of that item, not a move. A promoted-or-denied item landing with its resolution text attached.
			--from-state: is rejected here: a created item has no source
			state. owner/groomed-at/track are stamped as elsewhere in this
			family; groomed-from deliberately is NOT -- it records the state
			an item moved from, and a created item moved from nowhere. One
			body-input mode is required: there is no existing body to carry
			forward. communication-channel-id, approved-by/approved-at,
			blocks/blocked-by and references ride --header:* in
			this same single write. Own dedicated case arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-create-pending <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
			Creates a board-item directly in board/pending/ -- routine-grooming's
			own first write of that item, not a move. Promotion where the group's own context already warrants approval at creation.
			--from-state: is rejected here: a created item has no source
			state. owner/groomed-at/track are stamped as elsewhere in this
			family; groomed-from deliberately is NOT -- it records the state
			an item moved from, and a created item moved from nowhere. One
			body-input mode is required: there is no existing body to carry
			forward. communication-channel-id, approved-by/approved-at,
			blocks/blocked-by and references ride --header:* in
			this same single write. Own dedicated case arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-create-blocked <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
			Creates a board-item directly in board/blocked/ -- routine-grooming's
			own first write of that item, not a move. Promotion that needs human-owner approval, so the item lands blocked.
			--from-state: is rejected here: a created item has no source
			state. owner/groomed-at/track are stamped as elsewhere in this
			family; groomed-from deliberately is NOT -- it records the state
			an item moved from, and a created item moved from nowhere. One
			body-input mode is required: there is no existing body to carry
			forward. communication-channel-id, approved-by/approved-at,
			blocks/blocked-by and references ride --header:* in
			this same single write. Own dedicated case arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-create-running <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
			Creates a board-item directly in board/running/ -- routine-grooming's
			own first write of that item, not a move. The approval-* item the human-owner approval negotiation runs in.
			--from-state: is rejected here: a created item has no source
			state. owner/groomed-at/track are stamped as elsewhere in this
			family; groomed-from deliberately is NOT -- it records the state
			an item moved from, and a created item moved from nowhere. One
			body-input mode is required: there is no existing body to carry
			forward. communication-channel-id, approved-by/approved-at,
			blocks/blocked-by and references ride --header:* in
			this same single write. Own dedicated case arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-grooming-input-scan <team-member>
			Read-only: lists board items as <state>/<item-filename>, one per
			line, with every frontmatter field. Always scans backlog/
			pending/running/blocked/parked, --all-types. Use this to find an
			item's actual current state before calling --magic-grooming-to-*.
			Also returns routine-grooming's own state-and-lock note content
			ahead of the board rows, so a pass can continue from what the
			previous one recorded; a note that does not exist yet reports as
			having nothing to report and is not an error. Returns content
			only -- it never evaluates the lock. The team roster cache
			follows it as its own section, since this routine's own
			roster/tooling recheck works from it -- also content only, and
			also not an error when nothing is stored yet; there is no need to
			call --magic-team-roster-read separately after this scan.
			<team-member> is the only argument -- no --state/--header
			override.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-sweep-input-scan <team-member> [--comms-since-utime <v>|--comms-since-date-time <v>]
			Read-only: routine-communication-sweep's own combined check
			pass. Scans backlog/pending/running/blocked -- not parked.
			Returns only the items whose communication-channel-id is the
			three-field `slack:<channel>:<ts>` form, i.e. those tracking a
			live, reply-pending Slack thread -- a bare `slack:<channel>`
			names no thread, and a non-slack service is not one at all.
			Every board-item type, every frontmatter field --
			and reads every watched source in the same pass.
			An empty result (no live-tracked thread) is a normal, clean
			outcome, not an error. No --state/--header override.

			**One pass, several accounts.** After the calling member's own
			document it sweeps EVERY client-* member that exists, each
			under that member's own credentials and its own configured
			sources, and returns the whole set as one document. A client
			member's part is the same document --client-sweep-input-scan
			returns on its own, opening with its own
			`# Incoming Communications Sweep -- <member>` heading and
			`member:`/`member-kind:` lines, so a reader can tell whose
			traffic is whose. The member set is read from the members that
			exist at the moment of the call, never from a cached roster.

			A client member whose own sweep recorded no coverage still
			gets a block, in its own place, saying `no scan was made` --
			nothing it may have emitted is shown, so a member that failed
			never reads as a member with nothing new, and a member is
			never silently missing from the report.

			An optional cut-off narrows the read: --comms-since-utime takes
			epoch seconds, with or without a fractional part; --comms-since-date-time
			takes a YYYY-MM-DD-leading value. Mutually exclusive, neither
			repeatable -- one cut-off, one spelling. It is passed on to
			every client member's own sweep unchanged, so the whole
			document shares one cut-off.

			**Not a workspace-wide mention search.** A conversation outside
			the already-watched sources, or an identity mention that falls
			outside them, stays undiscoverable here -- true "tagged anywhere"
			coverage is a separate, not-yet-built capability.

			Exit code, reporting how much of the watched set was actually
			read (the body reports the same fact in its own
			`sources-scanned: N of M` lines and `NOT SCANNED`/partial
			markers; this makes it readable by status alone). It is the
			combined verdict over the calling member and every client
			member swept, since they are one document:
			0 when every one of them scanned every source it has,
			3 when some sources were read and some could not be -- whether
			that split falls inside one member or between two, the result
			is a partial sweep and must not be read as a complete one,
			4 when none of them read anything,
			1 when the operation failed before producing a document.
			A client member's own failure is coverage it did not get, so
			it lands in this status as 4 would and never as 1: once a
			document exists, 1 is not reachable.
			Same three-way shape and meanings as --member-comms-slack-read's
			human-owner fan-out.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-sweep-state-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]
			Writes (creates or overwrites) routine-communication-sweep's own
			state record. Takes no filename or path argument -- storage is
			the operation's own concern.
			Input source is exactly one of: stdin (default), `--from-file`, or
			`--edit-patch-from-stdin`. Empty content is rejected. If
			`--edit-patch-from-stdin` is used, stdin must be a JSON patch array
			for exact-literal replace operations.

		--magic-sweep-state-read <team-member>
			Reads back the whole record written by --magic-sweep-state-upsert,
			verbatim. Outputs `NO_STATE` if nothing is stored yet.
			Read-only.

		--magic-team-roster-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]
			Writes the team's roster cache -- member/domain/posture rows plus
			the per-member persona subsections, one record. Call it after
			re-deriving either from the members' own live skill files, to
			store the refreshed cache. Input source is exactly one of: stdin
			(default), `--from-file`, or `--edit-patch-from-stdin`. Empty
			content is rejected. If `--edit-patch-from-stdin` is used, stdin
			must be a JSON patch array for exact-literal replace operations.

		--magic-team-roster-read <team-member>
			Reads the team's roster cache -- member/domain/posture rows plus
			the per-member persona subsections. Call it when a roster or
			persona fact is needed, or to diff the cache before refreshing
			it. `--magic-grooming-input-scan` already returns this same
			content as its own section, so a routine working from that scan
			does not call this op as well. Outputs the record content, or
			`NO_RECORD` if none is stored yet. Read-only.

		--client-sweep-input-scan <client-* member> [--comms-since-utime <v>|--comms-since-date-time <v>]
			Read-only: one client-* member's own incoming
			external communications -- Slack, email and Trello -- read as
			that member, under that member's own credentials, from that
			member's own configured sources. Use it to sweep one external
			relationship's traffic; use --magic-sweep-input-scan for the
			team's own.

			The member name is the only required argument, and it must be
			a client-* one -- a partner-* member is not accepted: the
			document names that member as
			its entire scope, and no other member's is what it reports.
			Each section states our own side of that source
			(`identity: slack <id> (config: <member>)`, and the same for
			email and Trello), and board items are limited to the ones
			that member owns.

			A source that could not be read is reported as not scanned, in
			that section's `sources-scanned: N of M` line and its
			`**NOTE:** partial` marker, and counts against the exit status.
			It is never read under any other member's or the team's
			credentials.

			An OPTIONAL source this member holds no credentials of its own
			for -- email, Trello -- is a separate case: it was never
			contacted, so it carries no `sources-scanned:` line, enters no
			source total, and does not make the scan partial. Its section
			says so in its own `**NOTE:** no scan was made` line, naming
			the keys that are unset. Only that way is an unconfigured
			source distinguishable from an unreachable one.

			Slack sources come from this member's own `SLACK_CONVERSATIONS`
			config value -- conversation ids or `<channel>:<ts>` targets,
			whitespace- or comma-separated. With none configured, the
			Slack section reports that nothing was scanned rather than
			falling back to any team-scoped conversation.

			A cut-off narrows the read: --comms-since-utime takes
			epoch seconds, with or without a fractional part;
			--comms-since-date-time takes a YYYY-MM-DD-leading value.
			Mutually exclusive, neither repeatable -- one cut-off, one
			spelling. Optional to pass, never absent from the call: with
			neither given this operation supplies
			`--comms-since-utime 0` itself, so a member swept for the first
			time is not reported empty by a defaulted recent window. The
			cut-off actually used is stated in each section's own
			`instrument:` line.

			Exit code, same three-way shape and meanings as
			--magic-sweep-input-scan's: 0 when every source was scanned,
			3 when some were and some could not be, 4 when none could be,
			1 when the operation failed before producing a document.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-work-session-input-scan <team-member>
			Read-only: one member's own current work-session input --
			personal, not routine-dictated (every armed member runs this
			against its own name as it becomes armed, regardless of which
			routine triggered the arming). Scans backlog/pending/running/
			blocked/parked, restricted to the items owned by <team-member>,
			every board-item type, every frontmatter field. <team-member>
			is the only argument -- no --state/--header override. Appends
			that same member's own
			inbox/ contents as a second, identically shaped section
			(`## inbox/<item-filename>` + frontmatter) -- a not-yet-created
			inbox/ prints an empty section, not an error.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--routine-coworking-session-input-scan <team-member> <tracking-document>...
			Read-only: routine-coworking's own step-1 board scan once the
			session's shared goal names its own tracking document(s). Each
			<tracking-document> is one tracking document for this particular
			session -- a dispatch, an interview, a task or an attachment that
			is this session's own work -- given as a bare name, without the
			.md suffix. At least one is required -- no --state/--header
			override alongside them. Searches every real board state (a named
			document may
			live in any of them) and never filters by owner (contrast
			--member-work-session-input-scan: this is about specific named
			documents regardless of who owns them). Returns the named
			documents
			plus every item reached through their own references/blocks/
			blocked-by fields, every board-item type, every frontmatter
			field.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-heartbeat-input-scan <team-member>
			Read-only: routine-heartbeat's own prepared input, narrowed to
			what that routine's own steps consume. Returns
			routine-heartbeat's own state-and-lock note content first, so a
			pass can continue from what the previous one recorded; a note
			that does not exist yet reports as having nothing to report and
			is not an error. That is the lock note, not the heartbeat state
			record read by --magic-heartbeat-state-read. Returns content
			only -- it never evaluates the lock. Then an index of running/
			blocked only, every board-item type, carrying the `status`
			field alone -- the Test-email-report sub-step's own
			active-processes list, not a whole-board digest. <team-member>
			is the only argument -- no --state/--header override.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-heartbeat-config-check
			Read-only, no arguments -- routine-heartbeat's step-0 upfront
			config gate. Checks two scopes: magic-coordinator's own config
			for the keys below, and magic-team's for SLACK_BOT_TOKEN and
			TEAM_DATA_GIT_REMOTE, which are the team's own credential/config
			rather than any one member's.
			Prints one `<KEY>: OK`/`<KEY>: WARN`/`<KEY>: FAIL`/`<KEY>: SKIP`
			line per key checked (name
			only, never the value). OK is set; WARN is set but suspect;
			FAIL is required and unset, and is the only token that gates
			the exit code; SKIP is optional and unset. Keys checked: TEAM_DATA_DIRECTORY,
			SLACK_CHANNEL_EVENT_TRACK, SLACK_CHANNEL_EVENT_ALERT,
			SLACK_CHANNEL_MAGIC_TEAM, SLACK_CHANNEL_HUMAN_OWNER,
			EMAIL_IMAP_HOST, EMAIL_USER, EMAIL_APP_PASSWORD, TRELLO_KEY,
			TRELLO_TOKEN. Five are required:
			TEAM_DATA_DIRECTORY and the four SLACK_CHANNEL_* keys -- any of
			them missing also prints a
			`⛔ ERROR ... set it first: DistroAgentsTools.fn.sh
			--agents-config-option magic-coordinator --upsert <KEY> <value>`
			line and returns 1. The other five, and SLACK_BOT_TOKEN and
			TEAM_DATA_GIT_REMOTE (checked under magic-team, fix command
			`DistroAgentsTools.fn.sh --agents-config-option magic-team
			--upsert <KEY> <value>`), are optional/informational -- unset
			they read SKIP, print their own fix command too, and never
			affect the exit code.
			For the credential-bearing keys (EMAIL_APP_PASSWORD, TRELLO_KEY,
			TRELLO_TOKEN, SLACK_BOT_TOKEN) that fix command is the
			--upsert-from-stdin form, so following the hint never puts a
			secret in argv.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-advance-batch-outcome <team-member> --items:<item-filename>:<outcome>:<execution-receipt>[,<item-filename>:<outcome>:<execution-receipt>]...
			Records a per-pass outcome (nudged/respawned/redispatched/
			flagged-once/no-action) plus
			execution-receipt for several board/running/ items in one call,
			instead of one --magic-advance-to-running call per item.
			Same-state (running -> running) header patch only, existing
			content preserved -- never moves state, never spawns anything;
			a genuine spawn/respawn/redispatch/park still goes through
			--magic-advance-to-running/--magic-advance-to-parked directly.
			Item list is comma-joined, each entry colon-joined:
			<item-filename>:<outcome>:<execution-receipt>. The receipt
			portion may itself contain colons (inline:<timestamp>,
			no-action:<reason-code>, slack:<channel>:<ts> all pass through
			intact) but must not contain a comma. One malformed or failing entry is
			reported inline and does not abort the rest of the batch; any
			failures make the whole call exit non-zero.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-advance-input-scan <team-member>
			Read-only: routine-advance's own board scan, and the same scan
			routine-update-board reads to recompute what blocks what. Scans
			backlog/pending/running/blocked/parked, every board-item type,
			every frontmatter field. A caller needing a narrower view
			(routine-update-board uses only running/blocked) selects from
			the returned rows itself -- each one is labelled
			<state>/<item-filename>. Also returns routine-advance's own
			state-and-lock note content ahead of the board rows, so a pass
			can continue from what the previous one recorded; a note that
			does not exist yet reports as having nothing to report and is
			not an error. Returns content only -- it never evaluates the
			lock. <team-member> is the only argument -- no --state/--header
			override.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-advance-to-running <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves a board item into board/running/, in one call, and/or
			patches its frontmatter. Auto-stamps started-at (date-time) on
			every move. --from-state:running is also valid (same-state, no
			relocation) -- patches frontmatter on an item already in
			board/running/, existing content preserved. --from-state:<state>
			is required. --header:*
			applies upsert/append/remove field operations on top of the
			resolved body, in the order given. --upsert-from-stdin takes
			stdin verbatim as the new body; --edit-script-from-stdin runs a
			given py/awk script against the existing body; --edit-patch-from-stdin
			applies a JSON array of exact-literal-substring patches. The
			three body-input modes are mutually exclusive; none given means
			the body carries over unchanged except for the started-at stamp
			and any --header:* ops.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-advance-to-parked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves a board item into board/parked/, in one call, and/or
			patches its frontmatter -- routine-advance's own
			check-execute-board fallback, for a pass where a required spawn
			could not be executed. No auto-stamp, unlike
			--magic-advance-to-running's started-at: the calling step supplies
			condition/handoff-action/recheck-date/execution-receipt itself via
			--header:*, and recheck-date in particular is a caller-computed
			offset -- an item left without one deliberately falls to
			routine-grooming's slower cadence, so this op never invents it.
			--from-state:<state> is required. --header:* applies
			upsert/append/remove field operations on top of the resolved body,
			in the order given. --upsert-from-stdin takes stdin verbatim as
			the new body; --edit-script-from-stdin runs a given py/awk script
			against the existing body; --edit-patch-from-stdin applies a JSON
			array of exact-literal-substring patches. The three body-input
			modes are mutually exclusive; none given means the body carries
			over unchanged except for any --header:* ops.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-board-to-pending <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves a board item into board/pending/, in one call, and/or
			patches its frontmatter. No auto-stamp. --from-state:<state> is
			required. --header:* applies upsert/append/remove field
			operations on top of the resolved body, in the order given.
			--upsert-from-stdin takes stdin verbatim as the new body;
			--edit-script-from-stdin runs a given py/awk script against the
			existing body; --edit-patch-from-stdin applies a JSON array of
			exact-literal-substring patches. The three body-input modes are
			mutually exclusive; none given means the body carries over
			unchanged except for any --header:* ops.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-board-to-blocked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves a board item into board/blocked/, in one call, and/or
			patches its frontmatter. No auto-stamp. --from-state:<state> is
			required. --header:* applies upsert/append/remove field
			operations on top of the resolved body, in the order given.
			--upsert-from-stdin takes stdin verbatim as the new body;
			--edit-script-from-stdin runs a given py/awk script against the
			existing body; --edit-patch-from-stdin applies a JSON array of
			exact-literal-substring patches. The three body-input modes are
			mutually exclusive; none given means the body carries over
			unchanged except for any --header:* ops.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-board-to-backlog <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves a board item into board/backlog/, in one call, and/or
			patches its frontmatter. No auto-stamp. --from-state:<state> is
			required. --header:* applies upsert/append/remove field
			operations on top of the resolved body, in the order given.
			--upsert-from-stdin takes stdin verbatim as the new body;
			--edit-script-from-stdin runs a given py/awk script against the
			existing body; --edit-patch-from-stdin applies a JSON array of
			exact-literal-substring patches. The three body-input modes are
			mutually exclusive; none given means the body carries over
			unchanged except for any --header:* ops.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-board-to-parked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves a board item into board/parked/, in one call, and/or
			patches its frontmatter -- check-process-board's own move into
			board/parked/, the board-mechanical-moves counterpart of the
			three ops above. No auto-stamp here -- and no --magic-board-* op
			stamps grooming provenance, because check-process-board records
			none of its own the way routine-grooming does; the closing
			-to-blocked and -to-processed moves stamp their own fields
			instead. The recheck-date/condition pair a parked item carries is
			a caller judgment, passed as --header:* like any other field this
			op does not own. --from-state:<state> is
			required. --header:* applies upsert/append/remove field
			operations on top of the resolved body, in the order given.
			--upsert-from-stdin takes stdin verbatim as the new body;
			--edit-script-from-stdin runs a given py/awk script against the
			existing body; --edit-patch-from-stdin applies a JSON array of
			exact-literal-substring patches. The three body-input modes are
			mutually exclusive; none given means the body carries over
			unchanged except for any --header:* ops.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-board-to-processed <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves a board item into board/processed/, in one call, and/or
			patches its frontmatter -- the RUNNING->PROCESSED leg whose other
			two legs are --magic-board-to-blocked and --magic-board-to-backlog.
			Two auto-stamps, where --magic-board-to-blocked above stamps one
			and the other siblings none. processed-at records when the item
			entered board/processed/, the one fact age-based cleanup needs; it
			is stamped only when --from-state: is not processed already, since
			re-stamping on a same-state patch would restart that clock, and a
			caller passing its own processed-at still wins. execution-receipt
			defaults to processed:<timestamp> unless the caller supplied an
			execution-receipt upsert or append, in which case the caller's
			value stands untouched. Nothing else is
			stamped. --from-state:<state> is required. --header:* applies
			upsert/append/remove field operations on top of the resolved body,
			in the order given. --upsert-from-stdin takes stdin verbatim as the
			new body; --edit-script-from-stdin runs a given py/awk script
			against the existing body; --edit-patch-from-stdin applies a JSON
			array of exact-literal-substring patches. The three body-input
			modes are mutually exclusive; none given means the body carries
			over unchanged except for any --header:* ops.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-board-create-running <team-member> <item-filename> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
			Creates a board-item directly in board/running/ --
			check-process-board's own and only creating step: the approval-*
			item raised when a board-backlog item is flagged for human-owner
			approval. The move half of that same step is
			--magic-board-to-blocked. --from-state: is rejected: a created
			item has no source state. No auto-stamp, matching every sibling
			in this family. blocks/blocked-by ride --header:* in this same
			single write. One body-input mode is required. Own dedicated
			case arm.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-advance-lock-acquire <team-member> <owner-label>
		--magic-grooming-lock-acquire <team-member> <owner-label>
		--magic-daily-lock-acquire <team-member> <owner-label>
		--magic-retro-lock-acquire <team-member> <owner-label>
			Takes the calling routine's lock before any other step. Prints
			`ACQUIRED` (rc 0) on a fresh take; `RECLAIMED_STALE:prev_owner=
			...:age=...s` (rc 0) when the previous holder went stale;
			`ACTIVE:owner=...:state=...:recheck_date=...` (rc 1) when
			another holder genuinely has it -- rc 1 means do not start.
			<owner-label> names the running process, not a chat-session id.
			Takes no options; any further argument is rejected.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-advance-lock-refresh <team-member>
		--magic-grooming-lock-refresh <team-member>
		--magic-daily-lock-refresh <team-member>
		--magic-retro-lock-refresh <team-member>
			Re-asserts a held lock so a long run is not mistaken for a
			crashed one. Prints `REFRESHED` (rc 0), or `NO_LOCK_HELD` (rc 1)
			when nothing is held. Takes no options; any further argument is
			rejected.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-advance-close-state-and-unlock <team-member> [--from-file <path>|--edit-patch-from-stdin]
		--magic-grooming-close-state-and-unlock <team-member> [--from-file <path>|--edit-patch-from-stdin]
		--magic-daily-close-state-and-unlock <team-member> [--from-file <path>|--edit-patch-from-stdin]
		--magic-retro-close-state-and-unlock <team-member> [--from-file <path>|--edit-patch-from-stdin]
			Releases the lock in routine closure, setting the note's own
			`state: advance-finished`, `state: grooming-finished`,
			`state: daily-finished` or `state: retro-finished`
			respectively. Prints `RELEASED` and returns 0 always.

			Closing content is optional. Given, it is written into the SAME
			upsert call that sets the finished state and releases the lock
			-- one call closes a pass, not two: a caller no longer writes
			closing content via `--magic-*-state-and-lock-upsert` first and
			then calls this op second. Omitted, the note's existing body is
			preserved unchanged, only headers/lock change. A narrower subset
			of the sibling `--magic-*-state-and-lock-upsert` ops' three body
			sources -- no `--upsert-from-stdin` here, closing content is
			expected prepared rather than typed inline.

			--from-file <path>
				Replace the note body with this file's contents.

			--edit-patch-from-stdin
				Apply a JSON array of {"old","new","replace_all"} patches to
				the existing body. Mutually exclusive with --from-file.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-advance-lock-status <team-member>
		--magic-grooming-lock-status <team-member>
		--magic-daily-lock-status <team-member>
		--magic-retro-lock-status <team-member>
			Read-only, returns 0 always -- including when free, so a caller
			can check before deciding to start. Prints `NO_LOCK` when free,
			or `ACTIVE:owner=...:state=...:recheck_date=...` when held --
			read from the lock note's own frontmatter. Takes no options;
			any further argument is rejected.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-advance-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]
		--magic-grooming-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]
		--magic-daily-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]
		--magic-retro-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]
			Writes the calling routine's own fixed state-and-lock note --
			its session tracking document between iterations, not a
			transcript. Prefer referencing TEAM-DATA over copying it.
			`state` and `recheck-date` are stamped by the operation itself
			(+10 minutes for advance, +30 for grooming, daily and retro);
			pass `--header:upsert:state:<routine>-finished` to close.

			--header:<upsert|append|remove>:name[:value]
				Frontmatter field operations, applied in order. A repeated
				upsert on one field takes the last value. `recheck-date` is
				always re-stamped by the operation and cannot be overridden.

			--from-file <path>
				Replace the note body with this file's contents.

			--edit-patch-from-stdin
				Apply a JSON array of {"old","new","replace_all"} patches to
				the existing body. Mutually exclusive with --from-file.
				Given neither, the existing body is preserved.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-advance-sleep-run
			Read-only, no arguments -- a fixed-duration pacing operation in
			routine-advance's operation group.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-heartbeat-board-item-trash <team-member> <board-state> <item-name>
			Relocates one terminal board-item out of the board entirely, for
			routine-heartbeat's own GC step. <team-member> is the calling
			member's own identity — recorded in the git-commit message once
			team-data is git-tracked, otherwise unused;
			<board-state> is the item's current real board state
			(backlog/pending/running/blocked/parked/processed/archived/
			retained); <item-name> is a bare filename. Thin wrapper, always
			trashes, never restores -- restoring is a separate, internal-only
			capability, not exposed through this op.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-heartbeat-spawn-proxy <team-member> [--from-file <path>] [--from-board <board-item-name> [--board-state <state>]...] [--from-vault <vault-item-name>] [--from-audit <audit-item-name>] [--wait]
			Heartbeat/advance spawn relay: executes a spawn prompt through
			DistroAgentsConsole.sh. Prompt body source is stdin (default),
			--from-file, --from-board, --from-vault, or --from-audit
			(exactly one source selector when used); empty body is
			rejected. On the stdin default the body has to be redirected
			in for real — a pipe, a heredoc, or a file redirect. A bare
			call with nothing attached does NOT wait for input: stdin is
			already at EOF in a non-interactive caller, so the read
			returns 0 bytes and the call fails with "empty spawn context"
			straight away. Use --from-file <path> where redirecting is
			awkward. The prompt body is passed to the spawned session as
			its whole stdin and is not parsed here -- no field inside it
			selects a mode, `--wait` included.

			Two tracking outcomes. The two input-path groups differ by
			design, not by oversight, and neither writes a private receipt
			file. A --from-board/--from-vault/--from-audit call already
			names an existing tracking document, so NO new item is
			written and the call prints `TRACKING_ITEM=<name>` instead. A
			stdin/--from-file call is ad-hoc, with no document behind it
			yet, so it DOES create one: a `dispatch-*` board-item in
			board-running up front (verbatim prompt as its own "## Brief",
			under a frontmatter block carrying `owner`, `status` and
			`session-id`), and the same item is updated in place on
			completion — a `status:` header moving from `dispatch-started`
			to `dispatch-succeeded`/`dispatch-failed`, `resolved-at`
			stamped, and a real "## Result" section appended — printed as
			`DISPATCH_ITEM=<name>`. Async spawns close their own dispatch
			item from a background subshell once the child exits, so
			closure happens even though the call itself already returned.

			Default mode is async (returns STATUS=started + PID); --wait
			blocks for completion and returns non-zero on failure. Printed
			keys in full: RECEIPT_ID (a correlation id) always; exactly
			one of TRACKING_ITEM/DISPATCH_ITEM, per the two outcomes
			above; STATUS always, accompanied by PID on the async path and
			by EXIT_CODE on the --wait path; and OUTPUT_FILE always — the
			spawned process's own raw stdout/stderr, written under
			`$MDAT_DATA_ROOT/audit/<YYYY-MM>/`. No RECEIPT_FILE key is
			written or printed on any path.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-heartbeat-state-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]
			Writes (creates or overwrites) routine-heartbeat's own state
			record. Takes no filename or path argument -- storage is
			the operation's own concern.
			Input source is exactly one of: stdin (default), `--from-file`, or
			`--edit-patch-from-stdin`. Empty content is rejected. If
			`--edit-patch-from-stdin` is used, stdin must be a JSON patch array
			for exact-literal replace operations.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-heartbeat-lock-acquire <team-member> <owner-label>
			Takes routine-heartbeat's lock before any other step. Prints
			`ACQUIRED` (rc 0) on a fresh take; `RECLAIMED_STALE:prev_owner=
			...:age=...s` (rc 0) when the previous holder went stale;
			`ACTIVE:owner=...:state=...:recheck_date=...` (rc 1) when
			another holder genuinely has it -- rc 1 means do not start.
			<owner-label> names the running process (e.g. "main-loop"), not
			a chat-session id. Takes no options; any further argument is rejected.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-heartbeat-lock-refresh <team-member>
			Re-asserts a held lock so a long run is not mistaken for a
			crashed one. Prints `REFRESHED` (rc 0), or `NO_LOCK_HELD` (rc 1)
			when nothing is held. Takes no options; any further argument is rejected.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-heartbeat-close-state-and-unlock <team-member>
			Releases the lock in routine closure, setting the note's
			`state: heartbeat-finished`. Prints `RELEASED` and returns 0
			always. Takes no options; any further argument is rejected.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-heartbeat-lock-status <team-member>
			Read-only, returns 0 always -- including when free, so a caller
			can check before deciding to start. Prints `NO_LOCK` when free,
			or `ACTIVE:owner=...:state=...:recheck_date=...` when held --
			read from the lock note's own frontmatter. Takes no options;
			any further argument is rejected.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-heartbeat-state-read <team-member>
			Reads back the whole record written by --magic-heartbeat-state-upsert,
			verbatim. Outputs `NO_STATE` if nothing is stored yet.
			Read-only.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--magic-heartbeat-sleep-run
			Read-only, no arguments -- a fixed-duration pacing operation in
			routine-heartbeat's operation group.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--purge-cleanup
			Empties $MMDAPP/.local/.cleanup/ (the folder itself stays).
			Takes no arguments -- always targets this one fixed location;
			nothing to parameterize.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-help <team-member>
			Read-only. Prints `<team-member>`'s own duty-related tooling
			help.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-slack-read <team-member> <channel>:<ts> [--thread] [--identity-bot]
			`<team-member>` is the member this read acts as, and it comes
			first, ahead of the target. It is required, for the reason the
			identity paragraph below already gives: the acting member decides
			which conversation this call can see at all.

			Full detail for one specific message (default) or its whole
			thread (--thread) -- all meta-info, reactions, formatting,
			files/attachments, exactly as Slack's own API returns them. This
			is the deep read for actually processing one specific item, not a
			lightweight scan. Always returns full raw JSON, never
			pretty-formatted -- "full" is the entire point.

			Thread replies are covered: a `<ts>` naming a reply inside a
			thread reads back that reply, exactly as a thread parent or a
			plain non-threaded message does.

			Uses the same credential resolution as
			--member-comms-slack-send-message; `--identity-bot` reads as the team
			bot instead of this member's own identity. A direct
			conversation belongs to one identity, so the identity this call
			acts as decides WHICH conversation it can see: the bot's direct
			conversation with a person and a member's own are two different
			conversations, and neither can read the other. Channels are
			unaffected by it.

			**An empty result is never an answer from this operation.** A
			call that could not see the message it was asked for fails with
			a non-zero status and names the requested `<ts>`. Nothing this
			operation returns ever supports concluding "there is no such
			message" or "nobody replied yet" -- that conclusion needs a
			successful read, not an empty one.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-email-read <team-member> <uid> [--seen]
			`<team-member>` is the member this read acts as, and it comes
			first, ahead of the `<uid>`. It is required, and it is strict:
			the mailbox read is that member's own, with no fallback to
			another member's. A UID only means anything inside one mailbox,
			so the same `<uid>` under a different member names a different
			message, or none at all -- and the not-found code below is about
			this member's mailbox, never about email in general.

			Full RFC822 message (headers + body + MIME multipart,
			attachments included as their raw MIME parts) for one specific
			email by IMAP UID -- contrast with --member-comms-email-check's
			STATUS-only unread count.

			**Reading does not mark the message read.** The mailbox is
			opened read-only for the fetch, so the server cannot set \Seen
			on it at all; the fetch also asks for BODY.PEEK[]. \Seen is
			left exactly as it was found. Reading is not a decision about
			the message; marking it read is, and that decision is made
			separately -- either by --member-comms-email-mark-seen, or inline with
			--seen below.

			**An empty result is never an answer from this operation.** A
			call that could not return the message it was asked for fails
			with a non-zero status; empty stdout is never a successful
			answer. Four non-zero codes. **1**: no `<uid>` argument was
			given. **2**: `<uid>` is malformed, or the mailbox could not be
			reached or logged into. **3**: the server refused the fetch.
			**4**: no message with that `<uid>` exists in the mailbox --
			the not-found case, distinct from every failure above, so
			"there is no such message" is a conclusion this operation
			states itself rather than one a caller infers from silence.

			--seen marks the message \Seen after a successful read, for the
			case where a caller reads and immediately concludes. It runs only
			once the read has succeeded -- a failed read leaves the message
			untouched.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--member-comms-trello-read <team-member> <notification-id>
			`<team-member>` is the member this read acts as, and it comes
			first, ahead of the `<notification-id>`. It is required, and it
			is strict: the notification is read as that member, with no
			fallback to another member's scope. A notification belongs to
			one member's own list, so an id taken from another member's
			check is not readable here.

			Full detail for one specific Trello notification (the unit
			--member-comms-trello-check's unread list returns), including its related
			card/board summary. Contrast with --member-comms-trello-check's unread-list
			scan.

			**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

		--help
			Prints this syntax + summary and exits.

##  Notes:

		Channel dirs are session plumbing ONLY (fifo/log/pid/meta) — never a
		place to stage secrets material; if a credential ever needs to reach a
		console session, it must be sourced directly into the console's own
		environment, never dropped as a file inside a channel dir, so
		--console-stop's `rm -rf` (scoped to one deterministic channel dir,
		never a fixed/shared path) can never take it down with it.

		Must be run from inside or outside any console — --console-start's
		whole job is to create a new console session, so it can't assume one
		is already open. Bare invocation (`bash sh-scripts/DistroAgentsTools.fn.sh ...`
		with no leading path component) does not match this script's own
		`case "$0"` dispatcher and silently no-ops; invoke it via `./sh-scripts/...`,
		a full path, or with `sh-scripts/` on PATH.

		--header:<upsert|append|remove> operations write into the item's own
		`---` frontmatter block. An item that has no frontmatter block gets
		one, carrying the requested fields, ahead of its existing body; the
		body itself is untouched. An item whose frontmatter opens with `---`
		and never closes is refused instead -- where that block ends cannot
		be determined, so nothing is written.

##  Examples:

		# Start a console session against this tool's own workspace (source console)
		`DistroAgentsTools.fn.sh --console-start`

		# Start (or reuse) a deploy console against a different workspace
		`DistroAgentsTools.fn.sh --console-start --override-workspace /path/to/other/workspace --console DistroDeployConsole.sh`

		# Send one command into an open channel
		`DistroAgentsTools.fn.sh --console-send myx.distro-agent-console.<slug>.source -- echo hello`

		# Send multiple lines via stdin -- absolute path leading, heredoc for content,
		# never a separate piping command in front (that breaks the permission
		# allowlist match; see magic-team/CONSOLE-SESSIONS.md's "Heredoc for stdin"
		# section)
		```
		DistroAgentsTools.fn.sh --console-send myx.distro-agent-console.<slug>.source <<'EOF'
		echo one
		echo two
		EOF
		```

		# List this workspace's channels
		`DistroAgentsTools.fn.sh --console-list`

		# Stop a channel and clean up its processes/directory
		`DistroAgentsTools.fn.sh --console-stop myx.distro-agent-console.<slug>.source`

		# Set/read a credential-bearing setting
		`printf '%s' "$TOKEN" | DistroAgentsTools.fn.sh --agents-config-option magic-team --upsert-from-stdin SLACK_BOT_TOKEN`
		`DistroAgentsTools.fn.sh --agents-config-option magic-team --select SLACK_BOT_TOKEN`

		# Send a plain-text message to a fixed target
		`DistroAgentsTools.fn.sh --member-comms-slack-send-message keeper-myx magic-team Build finished OK.`

		# Send a threaded reply with rich Block Kit formatting from stdin -- heredoc,
		# not a piping command in front
		```
		DistroAgentsTools.fn.sh --member-comms-slack-send-message keeper-myx C0123ABCD:1700000000.000100 --from-stdin --format blocks <<'EOF'
		[{"type":"section","text":{"type":"mrkdwn","text":"*done*"}}]
		EOF
		```

		# Send the same via --from-file instead -- write content with a plain Write tool
		# call first, then this stays a single-line command
		`DistroAgentsTools.fn.sh --member-comms-slack-send-message keeper-myx magic-team --from-file /path/to/message.txt`

		# Mark an email UID as read after processing it
		`DistroAgentsTools.fn.sh --member-comms-email-mark-seen magic-coordinator 48`

		# Create a board Item -- one call, see --magic-grooming-create-backlog above
		```
		DistroAgentsTools.fn.sh --magic-grooming-create-backlog magic-coordinator task-example.md --owner-header-value magic-coordinator --upsert-from-stdin <<'EOF'
		... board item content ...
		EOF
		```

		# Move an existing board Item between states -- one call, old file relocated to trash/
		`DistroAgentsTools.fn.sh --magic-board-to-pending magic-coordinator task-example.md --from-state:backlog`

		# Post a note into another member's own personal inbox
		```
		DistroAgentsTools.fn.sh --member-inbox-note-upsert keeper-myx 2026-07-22-note-example.md <<'EOF'
		... note content ...
		EOF
		```

		# Same, via --from-file instead -- write content with a plain Write tool call
		# first, then this stays a single-line command
		`DistroAgentsTools.fn.sh --member-inbox-note-upsert keeper-myx 2026-07-22-note-example.md --from-file /path/to/note.md`

		# Pass an inquiry along to another member's own inbox
		```
		DistroAgentsTools.fn.sh --member-upsert-member-inquiry keeper-ae3 2026-07-24-inquiry-example.md <<'EOF'
		... inquiry content ...
		EOF
		```

		# Append one session transcript entry (one call = one entry block)
		`DistroAgentsTools.fn.sh --member-append-session-transcript magic-coordinator --speaker human-owner --timestamp 2026-07-26T12:34:56Z --message "Approved. Proceed." --transcript-name transcript-2026-07-26-example.md --workspace-root /Users/myx/.claude/skills/magic-team --create`

		# Read a transcript audit document by filename (no raw path argument)
		`DistroAgentsTools.fn.sh --member-read-audit-item magic-coordinator transcript-2026-07-26-example.md`

		# Read only a selected line range from the same audit document
		`DistroAgentsTools.fn.sh --member-read-audit-item magic-coordinator transcript-2026-07-26-example.md --start-line 10 --end-line 25`

		# Read a board item by filename (search all board states)
		`DistroAgentsTools.fn.sh --member-read-board-item magic-coordinator task-example.md`

		# Read from specific state(s) only, with optional line range
		`DistroAgentsTools.fn.sh --member-read-board-item magic-coordinator task-example.md --board-state pending --board-state running --start-line 1 --end-line 40`

		# Track a workspace path for the human-owner
		`DistroAgentsTools.fn.sh --owner-workspace-upsert /Volumes/ws-2017/myx-work`

		# Stop tracking it
		`DistroAgentsTools.fn.sh --owner-workspace-forget /Volumes/ws-2017/myx-work`

		# List every currently-tracked workspace path
		`DistroAgentsTools.fn.sh --owner-workspace-list`

		# Track this tool's own workspace root and print its path
		`DistroAgentsTools.fn.sh --owner-workspace-current`

		# Send an email with a multi-line body from stdin instead of fragile trailing argv
		```
		DistroAgentsTools.fn.sh --member-comms-email-send magic-coordinator example@example.org -- "Status update" -- --from-stdin <<'EOF'
		Line one of the body.
		Line two, with 'quotes' and (parens) that would have been fragile as argv.
		EOF
		```

		# Sweep all watched targets (magic-team, human-owner, email, Trello) for new activity --
		# board-tracked threads and every watched source in one pass, not a single-target reader
		`DistroAgentsTools.fn.sh --magic-sweep-input-scan magic-coordinator`

		# Sweep all watched targets, incrementally since a prior check marker
		`DistroAgentsTools.fn.sh --magic-sweep-input-scan magic-coordinator --comms-since-utime 1786140114.450349`

		# Regression-test permission hardening under a deliberately permissive umask
		`DistroAgentsTools.fn.sh --self-test`

		# Audit .local/.agents for anything not chmod 700/600
		`DistroAgentsTools.fn.sh --verify-permissions`
