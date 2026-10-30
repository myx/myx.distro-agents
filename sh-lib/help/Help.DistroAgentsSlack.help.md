📘 syntax: DistroAgentsSlack.fn.sh --slack-conversations-roster [--team-member <team-member>] [--identity user|bot|both] [--types <csv>]
📘 syntax: DistroAgentsSlack.fn.sh --slack-send-message [--team-member <team-member>] <magic-team|human-owner|event-track|event-alert|session-current|session-parent|<alias>:<ts>|<conversation-id>|<channel>:<ts>|<team-member>[:<ts>]> [--identity-bot] [--reply-broadcast] [--update-ts <ts>] [--address-to <who>]... [<text...>|--from-stdin|--from-file <path>] [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>] [--metadata <json>] [--text-group report|brief|relay]
📘 syntax: DistroAgentsSlack.fn.sh --slack-resolve-ids [--team-member <team-member>] [--user-name <name>]... [--channel-name <name>]... [--raw]
📘 syntax: DistroAgentsSlack.fn.sh --slack-delete-message [--team-member <team-member>] <channel>:<ts>|<alias>:<ts>|session-current|session-parent [<channel>:<ts>...] [--identity-bot]
📘 syntax: DistroAgentsSlack.fn.sh --slack-edit-message [--team-member <team-member>] <channel>:<ts>|<alias>:<ts>|session-current|session-parent [--identity-bot] [<text...>|--from-stdin|--from-file <path>] [--text-group report|brief|relay]
📘 syntax: DistroAgentsSlack.fn.sh --slack-file-fetch [--team-member <team-member>] <file-id> <destination-path> [--identity-bot] [--overwrite]
📘 syntax: DistroAgentsSlack.fn.sh --slack-file-info [--team-member <team-member>] <file-id> [--identity-bot] [--raw]
📘 syntax: DistroAgentsSlack.fn.sh --slack-file-share [--team-member <team-member>] <target> (--from-file <path>|--from-stdin) [--snippet-type <v>] [--title <v>] [--comment <text>] [--identity-bot]
📘 syntax: DistroAgentsSlack.fn.sh --slack-profile-get [--team-member <team-member>] [--raw]
📘 syntax: DistroAgentsSlack.fn.sh --slack-profile-set [--team-member <team-member>] {--display-name <v>|--title <v>|--status-text <v>|--status-emoji <v>|--status-expiry <ts>|--avatar <path>|--presence (auto|away)|--snooze <minutes>|--snooze-end}
📘 syntax: DistroAgentsSlack.fn.sh --slack-presence-keep [--team-member <team-member>] [--ttl <seconds>]
📘 syntax: DistroAgentsSlack.fn.sh --slack-presence-status [--team-member <team-member>] [--ttl <seconds>]
📘 syntax: DistroAgentsSlack.fn.sh --slack-presence-stop [--team-member <team-member>] [--ttl <seconds>]
📘 syntax: DistroAgentsSlack.fn.sh --slack-socket-start [--team-member <team-member>]
📘 syntax: DistroAgentsSlack.fn.sh --slack-socket-status [--team-member <team-member>]
📘 syntax: DistroAgentsSlack.fn.sh --slack-socket-stop [--team-member <team-member>]
📘 syntax: DistroAgentsSlack.fn.sh --slack-react [--team-member <team-member>] <channel>:<ts>|<alias>:<ts>|session-current|session-parent <emoji-name> [--identity-bot] [--remove]
📘 syntax: DistroAgentsSlack.fn.sh --slack-read [--team-member <team-member>] (<channel>:<ts>|<alias>:<ts>|session-current|session-parent [--thread]|<channel>|<conversation-id>|magic-team|human-owner|event-track|event-alert [--oldest <ts>]) [--identity-bot]
📘 syntax: DistroAgentsSlack.fn.sh --slack-search-messages [--team-member <team-member>] <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>> (--comms-since-date-time <v>|--comms-since-utime <v>) [--max-pages <n>] [--raw]

##  Summary:

		the team's Slack operations. A bare call prints the syntax line of each of the file's
		operations, --help-syntax prints every form of every operation (or of one
		operation, or of those that a prefix ending in "-" begins), and --help prints this
		manual.

##  Options:

		--slack-conversations-roster [--identity user|bot|both] [--types <csv>]
			Lists the conversations the member's own side may see, every page of them, so a
			correspondent is never missing for want of a page.

		--slack-send-message <target> [<text...>|--from-stdin|--from-file <path>]
			Posts one message to that place, or to that member's direct message, as the
			member, or as the team bot with `--identity-bot`. `--address-to` names who it is
			for, and the header of the post says so.

		--slack-resolve-ids [--user-name <name>]... [--channel-name <name>]... [--raw]
			Turns a person's name or a conversation's name into the ids the other
			operations take.

		--slack-delete-message <channel>:<ts>... [--identity-bot]
			Deletes those messages.

		--slack-edit-message <channel>:<ts> [<text...>|--from-stdin|--from-file <path>]
			Replaces the text of one message the member wrote, and leaves the thread it
			sits in as it was.

		--slack-file-fetch <file-id> <destination-path> [--overwrite]
			Saves the content of one shared file at that path.

		--slack-file-info <file-id> [--raw]
			Prints what Slack holds about one file: its name, its type and its size.

		--slack-file-share <target> (--from-file <path>|--from-stdin)
			Shares the text given into that conversation, as a snippet where a type or a
			title is named, with a comment where one is given.

		--slack-profile-get [--raw]
			Prints the member's own Slack profile.

		--slack-profile-set {--display-name <v>|--title <v>|--status-text <v>|--status-emoji <v>|--status-expiry <ts>|--avatar <path>|--presence (auto|away)|--snooze <minutes>|--snooze-end}
			Sets only the fields of that profile that are named.

		--slack-presence-keep [--ttl <seconds>]
			Holds the member's own Slack presence, `--ttl` seconds at a time.

		--slack-presence-status [--ttl <seconds>]
			Reads that presence, as it stands now.

		--slack-presence-stop [--ttl <seconds>]
			Ends the hold, and the presence is the member's own again.

		--slack-socket-start
			Starts the member's own socket listener, which is how a message reaches it without
			a poll.

		--slack-socket-status
			Whether that listener runs now.

		--slack-socket-stop
			Stops it.

		--slack-react <channel>:<ts>|<alias>:<ts>|session-current|session-parent <emoji-name> [--remove]
			Puts that emoji on one message as a reaction, and `--remove` takes it off.
			A conversation the acting user identity cannot reach is reacted to once
			under the team bot, and a note says so. `--identity-bot` forces the bot.

		--slack-read (<channel>:<ts> [--thread]|<channel>|<conversation-id>|<alias> [--oldest <ts>])
			Prints a conversation, the thread of one message with `--thread`, or the messages
			after `--oldest`.

		--slack-search-messages <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>> (--comms-since-date-time <v>|--comms-since-utime <v>) [--max-pages <n>]
			Prints the messages of that conversation since that moment, as far back as
			`--max-pages` allows.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
