📘 syntax: DistroAgentsSession.fn.sh --append-transcript [--team-member <team-member>] [--of-session <session-id>] [--speaker <speaker-name>] [--timestamp <ISO-UTC-date-time>] (--message <verbatim-text>|--from-stdin|--from-file <path>) [--transcript-name <transcript-file-name>] [--create]
📘 syntax: DistroAgentsSession.fn.sh --wait-for-input [--team-member <team-member>] [--wait-default|--wait-continue|--wait-close|--wait-add|--wait-drop|--unwait <kind>:<target> --wait-session-id <session-id>] [--wait-source <kind>:<target>]... [--wait-timeout <seconds>] [--wait-poll-interval <seconds>] [--wait-since-utime <epoch>] [--wait-addressee <slack-user-id>] [--wait-include-own] [--wait-react-seen <ids>] [--wait-react-note <ids>] [--wait-react-done <ids>] [--wait-react-wait <ids>] [--wait-collect <seconds>]
📘 syntax: DistroAgentsSession.fn.sh --wait-for-input [--team-member <team-member>] --wait-list-sources
📘 syntax: DistroAgentsSession.fn.sh --get-routine-text [--team-member <team-member>] <routine-selector>
📘 syntax: DistroAgentsSession.fn.sh --routine-run-inline [--team-member <team-member>] <routine-selector>
📘 syntax: DistroAgentsSession.fn.sh --get-session-channel-id [--team-member <team-member>]
📘 syntax: DistroAgentsSession.fn.sh --post-session-channel [--team-member <team-member>] [--address-to <team-member>]... [--identity-bot] (<text...>|--from-stdin)
📘 syntax: DistroAgentsSession.fn.sh --get-session-thread [--team-member <team-member>] [--own]
📘 syntax: DistroAgentsSession.fn.sh --wait-session-channel [--team-member <team-member>] [--to-@me] [--to-@here] [--to-@any] [--wait-timeout <seconds>]
📘 syntax: DistroAgentsSession.fn.sh --get-dispatch-text [--team-member <team-member>]
📘 syntax: DistroAgentsSession.fn.sh --update-routine-state [--team-member <team-member>] [--document <note>] [--header:upsert:<name>:<value>]... [--header:remove:<name>]... [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsSession.fn.sh --executor-checkpoint-push [--team-member <team-member>] [<name>]
📘 syntax: DistroAgentsSession.fn.sh --executor-checkpoint-rewind [--team-member <team-member>] [<name>] [--from-stdin]
📘 syntax: DistroAgentsSession.fn.sh --executor-checkpoint-exit [--team-member <team-member>]
📘 syntax: DistroAgentsSession.fn.sh --idle-wait [--team-member <team-member>] [--wait-timeout <seconds>]
📘 syntax: DistroAgentsSession.fn.sh --session-floor-remove [--team-member <team-member>] <seconds>
📘 syntax: DistroAgentsSession.fn.sh --set-session-topic [--team-member <team-member>] <text...>
📘 syntax: DistroAgentsSession.fn.sh --set-session-chapter [--team-member <team-member>] <text...>
📘 syntax: DistroAgentsSession.fn.sh [--help-syntax [<op>]]
📘 syntax: DistroAgentsSession.fn.sh [--help]

##  Summary:

		Your own session as its run has it: this session's thread and the input
		the run was given, the wait on its channel alone, the routine it runs
		and the checkpoint it returns to, and the two lines that say what it is
		about. Every call is answered about the session the call is made in,
		and names no session of its own.

##  Options:

		--append-transcript [--of-session <session-id>] [--speaker <speaker-name>] [--timestamp <ISO-UTC-date-time>] (--message <verbatim-text>|--from-stdin|--from-file <path>) [--transcript-name <transcript-file-name>] [--create]
			One message added to a session's transcript: the caller's own session
			with no `--of-session`, or another session's as magic-coordinator.
			The speaker and the timestamp are the message's own; `--create` makes a
			transcript that is not there yet.

		--wait-for-input [--wait-default|--wait-continue|--wait-close|--wait-add|--wait-drop|--unwait <kind>:<target> --wait-session-id <session-id>] [--wait-source <kind>:<target>]... [--wait-timeout <seconds>]
			Waits for new input and brings it, whole: the floor's own forms, the
			sources, the filters, the reactions and the bound. `--wait-list-sources`
			prints the sources the call would wait on and exits.

		--get-routine-text <routine-selector>
			The text of a routine as its run reads it: the routine's file with the
			routine of its kind mixed in, Opening steps, Steps and Closure steps in
			the order the kind sets. The selector is a routine's file name or part
			of one, exactly one file.

		--routine-run-inline <routine-selector>
			Runs one routine inline in this session, like a call: the routine's
			steps without its front matter and Maintainer Notes, the Opening and
			Closure steps of `magic-team.inline.routine`, and the result of its own
			input scan run now.

		--get-session-channel-id
			The thread of the session, `<channel>:<ts>`, the one the session-current
			alias names. Takes no argument.

		--post-session-channel [--address-to <team-member>]... [--identity-bot] (<text...>|--from-stdin)
			A post to the session's thread and to nowhere else: the team's Slack
			send as the calling member, with no target, so the first word is text.

		--get-session-thread [--own]
			The session thread read from the session chat file, all of it, or with
			`--own` the caller's own traffic. No network call.

		--wait-session-channel [--to-@me] [--to-@here] [--to-@any] [--wait-timeout <seconds>]
			Waits on the session channel alone, read by the caller's own floor
			pointer. The three `--to-` forms combine as a union; the timeout is the
			bound, and with none the call returns on an arrival.

		--get-dispatch-text
			The dispatch of the session as the run was given it: `dispatch.md`, the
			board item's copy and `input-scan.md`, each a section, mixed in that
			order.

		--update-routine-state [--document <note>] [--header:upsert:<name>:<value>]... [--header:remove:<name>]... [--from-file <path>|--edit-patch-from-stdin]
			The update of the locked document of the session's routine. The session
			knows the routine and the document the spawner locked, so the call names
			neither and any participant of a locked session may make it. The
			lock-owned fields stay as the spawner set them, and the update is
			committed before it returns.

		--executor-checkpoint-push [<name>]
		--executor-checkpoint-rewind [<name>] [--from-stdin]
		--executor-checkpoint-exit
			The executor's checkpoints: a snapshot of the run's conversation, a
			return to one, and the end of both. They write a request the harness of
			the run reads at the end of the round; a native client's run, or a
			routine that does not allow them, takes no checkpoint and says so.

		--idle-wait [--wait-timeout <seconds>]
			Waits for new input and, on an arrival, returns to the run's checkpoint
			with it as the next input. A native client's run, or a session with
			several participants, waits on nothing: a notice says so and Wait is the
			way to wait there.

		--session-floor-remove <seconds>
			The explicit timed removal of the run's delivery floor: after the given
			seconds the session channel is read from the start again.

		--set-session-topic <text...>
			The title of the session, what it is about: the title in lists and
			statuses, and the thread's root post edited to match. The authority
			rule's own options decide what a participant's change does.

		--set-session-chapter <text...>
			What the session does now, kept in its own store and announced in the
			session thread, under the same authority as the topic.

##  Examples:

		# Say what this session is about, then what it does now
		`DistroAgentsSession.fn.sh --set-session-topic Fixing the release build`
		`DistroAgentsSession.fn.sh --set-session-chapter Writing the dispatch`
		# Post into the session thread alone
		`DistroAgentsSession.fn.sh --post-session-channel The build is green again.`
		# Read the thread's own traffic, then wait on the channel alone
		`DistroAgentsSession.fn.sh --get-session-thread --own`
		`DistroAgentsSession.fn.sh --wait-session-channel --to-@me --wait-timeout 300`
		# One routine's text, and the same routine run here
		`DistroAgentsSession.fn.sh --get-routine-text advance`
		`DistroAgentsSession.fn.sh --routine-run-inline advance`
