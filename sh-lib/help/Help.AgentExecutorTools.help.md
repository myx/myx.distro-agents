📘 syntax: AgentExecutorTools.fn.sh --set-session-topic <text> [--escalate-wait [--timeout <s>]|--escalate-enqueue]
📘 syntax: AgentExecutorTools.fn.sh --set-session-chapter <text> [--escalate-wait [--timeout <s>]|--escalate-enqueue]
📘 syntax: AgentExecutorTools.fn.sh --get-uninvited-participants
📘 syntax: AgentExecutorTools.fn.sh --list-session-runs
📘 syntax: AgentExecutorTools.fn.sh --executor-queue [--session-id <id>] [--member <name>]
📘 syntax: AgentExecutorTools.fn.sh --executor-checklist-append (--item <text>)... [--session-id <id>] [--member <name>]
📘 syntax: AgentExecutorTools.fn.sh --executor-resume [--session-id <id>] [--reason <text>]
📘 syntax: AgentExecutorTools.fn.sh [--help-syntax [<op>]]
📘 syntax: AgentExecutorTools.fn.sh [--help]

##  Summary:

		The chair of a session: what acts on a session as its executor, whoever that member is.
		The four names that came here from `DistroAgentsSession.fn.sh` and
		`DistroAgentsDispatcher.fn.sh` keep working under their old names there, as stubs that say
		where the name went. The three `--executor-*` operations are the chair's own: they read its
		session's queue and put work into it, and they resume the session's control thread where it
		stopped. It owns no store: the queue is the CheckList tool's, and every path here comes through
		that tool's own locator.

		The chair of a session is the member of the run that founded it, its record's `owner` beside
		`start-context: spawned`. Every operation that acts on the session as its chair refuses a call
		made as another member, a session this workspace does not hold, and a call from no member's seat.

##  Options:

  --set-session-topic <text> [--escalate-wait [--timeout <seconds>]|--escalate-enqueue]
			The title of the session, what it is about: the title in lists and statuses (the
			`session-comment` header of its records), and the thread's root post edited to match.
			The executor sets it itself; a participant's change escalates to the executor and up its
			chain, and the person at the console sets it under the authority rule.

  --set-session-chapter <text> [--escalate-wait [--timeout <seconds>]|--escalate-enqueue]
			What the session does now: kept as one line in the session's own store, and announced in
			its thread. The same authority as the topic.

  --get-uninvited-participants
			The participants the session's record names that have no run in it yet, one a line: the
			default list the executor invites from. A record that names no participants prints nothing
			and says so on stderr.

  --list-session-runs
			The runs this session may see, as the manager list prints them: its own runs and its
			sub-sessions, the public coworking sessions of the team, and the caller's own. Another
			member's private session is never listed, unless the caller is in it.

  --executor-queue [--session-id <id>] [--member <name>]
			The chair's read of its session's queue: one block per participant, with the items open and
			in progress, and whether that member has a run in the session. `--member` keeps one
			participant's block. `--session-id` reads another session the caller chairs; it defaults to
			the caller's own. It reads only. Refused from a call with no member's seat, for a session
			this workspace does not hold, for a caller that is not its executor, and for a member that
			is neither its executor nor its participant.

  --executor-checklist-append (--item <text>)... [--session-id <id>] [--member <name>]
			The chair puts work into a session's queue: each `--item` goes to the end of that
			participant's list as a pending item, marked as the chair's own, in the place the CheckList
			tool keeps it. `--member` names the participant, the chair itself where none is given. An
			item carrying a ` (due: <date-time>)` mark that no date reader can read is refused, and so
			is a list whose lock is not taken in five seconds. Where the named member has no run in the
			session, the append resumes the session's executor (see `--executor-resume`).

  --executor-resume [--session-id <id>] [--reason <text>]
			Adding work to a stopped session's queue resumes its executor: the session's control thread
			is started where none lives, and what became of the start is printed. Refused from a call
			with no member's seat, for a session this workspace does not hold, for a caller that is not
			its executor, where the executor's run is live, for a session carrying the owner's
			dismissal mark (a dismissal is never undone by a rule), and for a session with no place for
			a control thread.

##  Notes:

		The front is reached by command and by the harness's execute, as `AgentLibrarianTools.fn.sh` is;
		it is no MCP tool of its own. The coordinator's `--supervise-checklist-add` stays its own
		operation in `AgentDispatcherTools.fn.sh`.
