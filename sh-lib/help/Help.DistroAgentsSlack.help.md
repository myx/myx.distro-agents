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

		the team's Slack operations. A bare call lists the operations of the file, --help-syntax
		prints the syntax line of every operation (or of one operation, or of those
		that a prefix ending in "-" begins), and --help prints this manual.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
