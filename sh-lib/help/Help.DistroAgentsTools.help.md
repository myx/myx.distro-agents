📘 syntax: DistroAgentsTools.fn.sh --console-start [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]
📘 syntax: DistroAgentsTools.fn.sh --console-send <channel> [-- <command...>]
📘 syntax: DistroAgentsTools.fn.sh --console-stop <channel>
📘 syntax: DistroAgentsTools.fn.sh --console-list [--override-workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --agents-config-option <entity-id> <operation>
📘 syntax: DistroAgentsTools.fn.sh --members --backend <member-name> <operation>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-send-message [--team-member <team-member>] <magic-team|human-owner|event-track|event-alert|session-current|session-parent|<alias>:<ts>|<conversation-id>|<channel>:<ts>|<team-member>[:<ts>]> [--identity-bot] [--metadata <json>] [text...]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-send-message [--team-member <team-member>] <target> [--identity-bot] [--reply-broadcast] [--update-ts <ts>] [--address-to <who>]... --from-stdin [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>] [--metadata <json>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-send-message [--team-member <team-member>] <target> [--identity-bot] [--reply-broadcast] [--update-ts <ts>] [--address-to <who>]... --from-file <path> [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>] [--metadata <json>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-send [--team-member <team-member>] <email@address>... -- <subject> -- <body...> [--format markdown|text] [--in-reply-to <message-id>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-send [--team-member <team-member>] <email@address>... -- <subject> -- --from-stdin [--format markdown|text] [--in-reply-to <message-id>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-send [--team-member <team-member>] <email@address>... -- <subject> -- --from-file <path> [--format markdown|text] [--in-reply-to <message-id>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-search-messages [--team-member <team-member>] <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>> (--comms-since-date-time <v>|--comms-since-utime <v>) [--max-pages <n>] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-react [--team-member <team-member>] <channel>:<ts>|<alias>:<ts>|session-current|session-parent <emoji-name> [--identity-bot] [--remove]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-delete-message [--team-member <team-member>] <channel>:<ts>|<alias>:<ts>|session-current|session-parent [<channel>:<ts>...] [--identity-bot]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-edit-message [--team-member <team-member>] <channel>:<ts>|<alias>:<ts>|session-current|session-parent [--identity-bot] [text...]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-edit-message [--team-member <team-member>] <channel>:<ts>|<alias>:<ts>|session-current|session-parent [--identity-bot] --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-edit-message [--team-member <team-member>] <channel>:<ts>|<alias>:<ts>|session-current|session-parent [--identity-bot] --from-file <path>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-file-info [--team-member <team-member>] <file-id> [--identity-bot] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-file-fetch [--team-member <team-member>] <file-id> <destination-path> [--identity-bot] [--overwrite]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-profile-get [--team-member <team-member>] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-profile-set [--team-member <team-member>] {--display-name <v>|--title <v>|--status-text <v>|--status-emoji <v>|--status-expiry <ts>|--avatar <path>|--presence (auto|away)|--snooze <minutes>|--snooze-end}
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-slack-resolve-ids [--team-member <team-member>] [--user-name <name>]... [--channel-name <name>]... [--raw]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-slack-conversations-roster [--team-member <team-member>] [--identity user|bot|both] [--types <csv>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-slack-read [--team-member <team-member>] (<channel>:<ts> [--thread]|<channel>|<conversation-id> [--oldest <ts>]) [--identity-bot]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-slack-send-message [--team-member <team-member>] <target> [--identity-bot] [--address-to <who>]... (<text...>|--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-slack-react [--team-member <team-member>] <channel>:<ts> <emoji-name> [--identity-bot] [--remove]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-email-send [--team-member <team-member>] <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-email-mark-seen [--team-member <team-member>] <uid>
📘 syntax: DistroAgentsTools.fn.sh --magic-client-operation-run <magic-coordinator> --client-<operation> <client-member-name> [<argument>...]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-check [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-mark-seen [--team-member <team-member>] <uid>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-trello-check [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-trello-post-comment [--team-member <team-member>] <card-id> [text...]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-trello-post-comment [--team-member <team-member>] <card-id> --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-trello-post-comment [--team-member <team-member>] <card-id> --from-file <path>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-read [--team-member <team-member>] (<channel>:<ts>|<alias>:<ts>|session-current|session-parent [--thread]|<channel>|<conversation-id>|magic-team|human-owner|event-track|event-alert [--oldest <ts>]) [--identity-bot]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-read [--team-member <team-member>] <uid> [--seen]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-trello-read [--team-member <team-member>] <notification-id>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-confluence-space-list [--team-member <team-member>] [--cursor <value>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-confluence-page-read [--team-member <team-member>] <page-id> [--format storage|atlas_doc_format] [--version <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-space-list [--team-member <team-member>] [--cursor <value>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-read [--team-member <team-member>] <page-id> [--format storage|atlas_doc_format]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-search [--team-member <team-member>] <cql> [--limit <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-comment-read [--team-member <team-member>] <page-id>
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-create [--team-member <team-member>] (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-update [--team-member <team-member>] <page-id> --version <n> --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-comment-add [--team-member <team-member>] <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-delete [--team-member <team-member>] <page-id>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-space-list [--team-member <team-member>] [--cursor <value>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-page-read [--team-member <team-member>] <page-id> [--format storage|atlas_doc_format] [--version <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-page-search [--team-member <team-member>] <cql> [--limit <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-comment-read [--team-member <team-member>] <page-id>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-page-create [--team-member <team-member>] (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-page-update [--team-member <team-member>] <page-id> --version <n> --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-comment-add [--team-member <team-member>] <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-page-delete [--team-member <team-member>] <page-id>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-issue-read [--team-member <team-member>] <issue-key> [--format adf|rendered]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-board-list [--team-member <team-member>] [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-board-read [--team-member <team-member>] <board-id>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-board-issue-search [--team-member <team-member>] <board-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-sprint-list [--team-member <team-member>] <board-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-sprint-issue-search [--team-member <team-member>] <sprint-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-board-list [--team-member <team-member>] [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-board-read [--team-member <team-member>] <board-id>
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-board-issue-search [--team-member <team-member>] <board-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-sprint-list [--team-member <team-member>] <board-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-sprint-issue-search [--team-member <team-member>] <sprint-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-issue-search [--team-member <team-member>] <jql> [--limit <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-issue-read [--team-member <team-member>] <issue-key> [--format adf|rendered]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-comment-read [--team-member <team-member>] <issue-key> [--format adf|rendered] [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-issue-create [--team-member <team-member>] --project <key> --issuetype <name> --summary <text> [--description-adf <json>|--description-adf-from-stdin|--description-adf-from-file <path>] [--fields-json <json>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-issue-update [--team-member <team-member>] <issue-key> [--fields-json <json>] [--update-json <json>] [--notify-users]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-issue-transition [--team-member <team-member>] <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>|--comment-adf-from-stdin|--comment-adf-from-file <path>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-comment-add [--team-member <team-member>] <issue-key> (--body-adf <json>|--body-adf-from-stdin|--body-adf-from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-issue-delete [--team-member <team-member>] <issue-key>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-board-list [--team-member <team-member>] [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-board-read [--team-member <team-member>] <board-id>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-board-issue-search [--team-member <team-member>] <board-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-sprint-list [--team-member <team-member>] <board-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-sprint-issue-search [--team-member <team-member>] <sprint-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-issue-search [--team-member <team-member>] <jql> [--limit <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-issue-read [--team-member <team-member>] <issue-key> [--format adf|rendered]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-comment-read [--team-member <team-member>] <issue-key> [--format adf|rendered] [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-issue-create [--team-member <team-member>] --project <key> --issuetype <name> --summary <text> [--description-adf <json>|--description-adf-from-stdin|--description-adf-from-file <path>] [--fields-json <json>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-issue-update [--team-member <team-member>] <issue-key> [--fields-json <json>] [--update-json <json>] [--notify-users]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-issue-transition [--team-member <team-member>] <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>|--comment-adf-from-stdin|--comment-adf-from-file <path>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-comment-add [--team-member <team-member>] <issue-key> (--body-adf <json>|--body-adf-from-stdin|--body-adf-from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-issue-delete [--team-member <team-member>] <issue-key>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-send-message [--team-member <team-member>] (<conversation-id>|<channel>:<ts>|<user-id>) [--identity-bot] [--reply-broadcast] [--update-ts <ts>] [--address-to <who>]... (<text...>|--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-read [--team-member <team-member>] (<channel>:<ts> [--thread]|<conversation-id> [--oldest <ts>]) [--identity-bot]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-search-messages [--team-member <team-member>] <conversation-id> (--comms-since-date-time <v>|--comms-since-utime <v>) [--max-pages <n>] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-react [--team-member <team-member>] <channel>:<ts> <emoji-name> [--identity-bot] [--remove]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-delete-message [--team-member <team-member>] <channel>:<ts> [<channel>:<ts>...] [--identity-bot]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-edit-message [--team-member <team-member>] <channel>:<ts> [--identity-bot] (<text...>|--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-file-info [--team-member <team-member>] <file-id> [--identity-bot] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-file-fetch [--team-member <team-member>] <file-id> <destination-path> [--identity-bot] [--overwrite]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-file-share [--team-member <team-member>] (<conversation-id>|<channel>:<ts>) (--from-file <path>|--from-stdin) [--snippet-type <v>] [--title <v>] [--comment <text>] [--identity-bot]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-profile-get [--team-member <team-member>] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-profile-set [--team-member <team-member>] {--display-name <v>|--title <v>|--status-text <v>|--status-emoji <v>|--status-expiry <ts>|--avatar <path>|--presence (auto|away)|--snooze <minutes>|--snooze-end}
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-presence-keep [--team-member <team-member>] [--ttl <seconds>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-presence-status [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-presence-stop [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-socket-start [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-socket-status [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-slack-socket-stop [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-email-check [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-email-read [--team-member <team-member>] <uid> [--seen]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-email-mark-seen [--team-member <team-member>] <uid>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-email-send [--team-member <team-member>] <email@address>... -- <subject> -- <body...> [--format markdown|text] [--in-reply-to <message-id>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-email-send [--team-member <team-member>] <email@address>... -- <subject> -- --from-stdin [--format markdown|text] [--in-reply-to <message-id>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-email-send [--team-member <team-member>] <email@address>... -- <subject> -- --from-file <path> [--format markdown|text] [--in-reply-to <message-id>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-trello-check [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-trello-post-comment [--team-member <team-member>] <card-id> [text...]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-trello-post-comment [--team-member <team-member>] <card-id> --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --client-comms-trello-post-comment [--team-member <team-member>] <card-id> --from-file <path>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-trello-read [--team-member <team-member>] <notification-id>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-trello-whoami [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-google-file-find [--team-member <team-member>] <search-term> [--full-text] [--include-trashed] [--limit <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-google-file-find [--team-member <team-member>] <drive-query> --raw-query [--limit <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-google-comment-post [--team-member <team-member>] <file-id> (<text...>|--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --client-comms-google-comment-read [--team-member <team-member>] <file-id>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-google-doc-read [--team-member <team-member>] <doc-id>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-google-doc-write [--team-member <team-member>] <doc-id> (<text...>|--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --client-comms-google-sheet-clear [--team-member <team-member>] <sheet-id> <a1-range>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-google-sheet-info [--team-member <team-member>] <sheet-id>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-google-sheet-read [--team-member <team-member>] <sheet-id> <a1-range> [--unformatted]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-google-sheet-write [--team-member <team-member>] <sheet-id> <a1-range> [--append] [--user-entered] (--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --client-comms-google-whoami [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --owner-credential-store-self-test
📘 syntax: DistroAgentsTools.fn.sh --owner-credential-store-verify
📘 syntax: DistroAgentsTools.fn.sh --owner-credential-store-harden
📘 syntax: DistroAgentsTools.fn.sh --member-git-repo-history [--since <YYYY-MM-DD>] [--until <YYYY-MM-DD>] [--limit <n>] <path>...
📘 syntax: DistroAgentsTools.fn.sh --librarian-skillset-upsert [--team-member <team-member>] <pathname> (--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --librarian-list-team-files [<path>...]
📘 syntax: DistroAgentsTools.fn.sh --librarian-list-team-files-dates [<path>...]
📘 syntax: DistroAgentsTools.fn.sh --librarian-inbox-item-trash [--team-member <team-member>] <item-filename> --from-inbox:<member> [--exclude-incoming]
📘 syntax: DistroAgentsTools.fn.sh --librarian-inbox-to-processed [--team-member <team-member>] <item-filename> [--include-processed] [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-note-upsert [--team-member <member>] <item-filename> [--from-member <member>] [--include-processed] [--standing yes|no] [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-upsert-member-inquiry [--team-member <member>] <item-filename> [--from-member <member>] [--include-processed] [--from-file <path>]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-reflection-upsert [--team-member <member>] <item-filename> [--from-member <member>] [--include-processed] [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-append-session-transcript [--team-member <team-member>] [--speaker <speaker-name>] [--timestamp <ISO-UTC-date-time>] (--message <verbatim-text>|--from-stdin|--from-file <path>) [--transcript-name <transcript-file-name>] [--create]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-item-read [--team-member <member>] <item-filename> [--include-processed] [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-item-trash [--team-member <member>] <item-filename> [--exclude-incoming]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-to-processed [--team-member <team-member>] <item-filename> [--include-processed] [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-audit-item-read [--team-member <team-member>] <document-name> [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --member-vault-item-read [--team-member <team-member>] <item-name> [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --member-board-item-read [--team-member <team-member>] <item-name> [--board-state <state>]... [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --owner-workspace-upsert <path> [--name <name>] [--kind workspace|directory] [--ceiling read-only|read-write]
📘 syntax: DistroAgentsTools.fn.sh --owner-workspace-forget <name>
📘 syntax: DistroAgentsTools.fn.sh --owner-workspace-list
📘 syntax: DistroAgentsTools.fn.sh --member-directory-list
📘 syntax: DistroAgentsTools.fn.sh --member-directory-path <name>[/<relative>]
📘 syntax: DistroAgentsTools.fn.sh --member-namespace-list [<namespace>]
📘 syntax: DistroAgentsTools.fn.sh --install-claude-permissions [--workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --install-workspace-restrictions [--workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --install-skillset-symlinks [--scope workspace|user-home] [--workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --install-vscode-integrations [--workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --install-knowledge-store [--from-folder <folder>]
📘 syntax: DistroAgentsTools.fn.sh --install-workspace-integrations [--scope workspace|user-home] [--workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --make-workspace-integrations [--quiet]
📘 syntax: DistroAgentsTools.fn.sh --make-agents-indices [<name>...]
📘 syntax: DistroAgentsTools.fn.sh --make-harness-indices [<name>...]
📘 syntax: DistroAgentsTools.fn.sh --make-console-command [--quiet]
📘 syntax: DistroAgentsTools.fn.sh --make-console-script
📘 syntax: DistroAgentsTools.fn.sh --manager-check-run [--local] [--seconds <n>] [<domain>...]
📘 syntax: DistroAgentsTools.fn.sh --manager-command-list
📘 syntax: DistroAgentsTools.fn.sh --manager-config-digest [--full] [<subject>...]
📘 syntax: DistroAgentsTools.fn.sh --manager-config-set <key> <value>
📘 syntax: DistroAgentsTools.fn.sh --manager-console-list
📘 syntax: DistroAgentsTools.fn.sh --manager-dashboard-read [--group <group>] [<block>...]
📘 syntax: DistroAgentsTools.fn.sh --manager-help-read
📘 syntax: DistroAgentsTools.fn.sh --manager-help-read <Name>.fn.sh
📘 syntax: DistroAgentsTools.fn.sh --manager-keys-list
📘 syntax: DistroAgentsTools.fn.sh --manager-keys-read <key>
📘 syntax: DistroAgentsTools.fn.sh --manager-keys-generate <key>
📘 syntax: DistroAgentsTools.fn.sh --manager-keys-regenerate <key>
📘 syntax: DistroAgentsTools.fn.sh --manager-keys-delete <key>
📘 syntax: DistroAgentsTools.fn.sh --manager-manual-read <user|maintainer> [<project>]
📘 syntax: DistroAgentsTools.fn.sh --manager-place-list
📘 syntax: DistroAgentsTools.fn.sh --manager-place-read <place>
📘 syntax: DistroAgentsTools.fn.sh --manager-place-command-list <place>
📘 syntax: DistroAgentsTools.fn.sh --manager-place-command-run <place> <command>
📘 syntax: DistroAgentsTools.fn.sh --manager-routine-list
📘 syntax: DistroAgentsTools.fn.sh --manager-stats-tokens --by day|member|routine|preset|credential [--since <date>] [--until <date>] [--member <m>] [--routine <r>] [--preset <p>] [--credential <c>]
📘 syntax: DistroAgentsTools.fn.sh --manager-stats-routines [<routine>]
📘 syntax: DistroAgentsTools.fn.sh --manager-pending-reply-read --id <pending-id>
📘 syntax: DistroAgentsTools.fn.sh --manager-pending-reply-answer --id <pending-id> (--answer <word|number|text>|--reject) [--text <words>]
📘 syntax: DistroAgentsTools.fn.sh --manager-pending-reply-dismiss --id <pending-id> [--reason <text>]
📘 syntax: DistroAgentsTools.fn.sh --manager-scope-list
📘 syntax: DistroAgentsTools.fn.sh --manager-scope-read <scope-id>
📘 syntax: DistroAgentsTools.fn.sh --manager-scope-reveal <scope-id> <key>
📘 syntax: DistroAgentsTools.fn.sh --manager-scope-set <scope-id> <key>
📘 syntax: DistroAgentsTools.fn.sh --manager-scope-unset <scope-id> <key>
📘 syntax: DistroAgentsTools.fn.sh --manager-scope-clear <scope-id>
📘 syntax: DistroAgentsTools.fn.sh --manager-scope-delete <scope-id>
📘 syntax: DistroAgentsTools.fn.sh --manager-wizard-read <cli-service|git-settings>
📘 syntax: DistroAgentsTools.fn.sh --manager-wizard-apply cli-service --preset <name>
📘 syntax: DistroAgentsTools.fn.sh --manager-wizard-apply git-settings
📘 syntax: DistroAgentsTools.fn.sh --manager-session-list [--active]
📘 syntax: DistroAgentsTools.fn.sh --manager-session-read --session-id <id> [--run]
📘 syntax: DistroAgentsTools.fn.sh --manager-session-transcript-read --session-id <id> [--run] [--tail <lines>] [--log]
📘 syntax: DistroAgentsTools.fn.sh --manager-session-checklist-read --session-id <id> <member>
📘 syntax: DistroAgentsTools.fn.sh --manager-session-kill --session-id <id> [--run] [--plan]
📘 syntax: DistroAgentsTools.fn.sh --manager-session-effort <session-id> <low|normal|high>
📘 syntax: DistroAgentsTools.fn.sh --manager-session-control-start (--session-id <id>|--all)
📘 syntax: DistroAgentsTools.fn.sh --manager-session-message --session-id <id> [--to <participant>]...
📘 syntax: DistroAgentsTools.fn.sh --manager-session-join --session-id <id>
📘 syntax: DistroAgentsTools.fn.sh --manager-spawn-member <team-member> [--from-stdin|--from-file <path>] [--session-name-or-comment <text>] [--description <text>]
📘 syntax: DistroAgentsTools.fn.sh --manager-subsystem-list
📘 syntax: DistroAgentsTools.fn.sh --manager-subsystem-run (install|uninstall|update) <subsystem>
📘 syntax: DistroAgentsTools.fn.sh --manager-team-data-read <store> [<folder> [<item>]] [--include-processed]
📘 syntax: DistroAgentsTools.fn.sh --manager-team-member-list
📘 syntax: DistroAgentsTools.fn.sh --manager-team-member-files <team-member> [<file>]
📘 syntax: DistroAgentsTools.fn.sh --manager-team-member-read [--full] <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-backlog [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-pending [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-processed [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-parked [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-blocked [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-running [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-archived [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-retained [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-backlog [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-processed [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-pending [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-blocked [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-running [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
📘 syntax: DistroAgentsTools.fn.sh --magic-sweep-state-upsert [--team-member <team-member>] [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-sweep-state-read [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-sweep-state-advance [--team-member <team-member>] <ts>
📘 syntax: DistroAgentsTools.fn.sh --magic-team-roster-upsert [--team-member <team-member>] [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-team-roster-read [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-team-data-commit-pending [--team-member <team-member>] [--commit-message <message>] [--no-push]
📘 syntax: DistroAgentsTools.fn.sh --member-wait-for-input [--team-member <team-member>] [--wait-default|--wait-continue|--wait-close|--wait-add|--wait-drop|--unwait <kind>:<target> --wait-session-id <session-id>] [--wait-source <kind>:<target>]... [--wait-timeout <seconds>] [--wait-poll-interval <seconds>] [--wait-since-utime <epoch>] [--wait-addressee <slack-user-id>] [--wait-include-own] [--wait-react-seen <ids>] [--wait-react-note <ids>] [--wait-react-done <ids>] [--wait-react-wait <ids>] [--wait-collect <seconds>]
📘 syntax: DistroAgentsTools.fn.sh --member-wait-for-input [--team-member <team-member>] --wait-list-sources
📘 syntax: DistroAgentsTools.fn.sh --member-escalation-read [--team-member <team-member>] <request-id>
📘 syntax: DistroAgentsTools.fn.sh --member-escalation-answer [--team-member <team-member>] <request-id> <verdict> [text]
📘 syntax: DistroAgentsTools.fn.sh --magic-escalation-answer <magic-coordinator> <request-id> <verdict> [text]
📘 syntax: DistroAgentsTools.fn.sh --member-escalation-readback [--team-member <team-member>] <request-id> <option word> [text]
📘 syntax: DistroAgentsTools.fn.sh --magic-escalation-forward <coordinator> <request-id>
📘 syntax: DistroAgentsTools.fn.sh --member-permission-pass [--team-member <team-member>] --to <member> --tool <tool> --target <target> --kind once|session|task [--task <item>] [--session-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-permission-set-request <magic-coordinator> <item> (--entry <tool[,tool...]:target>... [--purpose <text>])... [--scope task|session] [--session-id <id>] [--participant <member>]...
📘 syntax: DistroAgentsTools.fn.sh --magic-permission-list --member <member> [--session-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --member-permission-list [--team-member <team-member>] [--session-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-permission-revoke <ref> [--session-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --member-pending-reply-read [--team-member <team-member>] [<pending-id>] [--all] [--any-owner] [--count]
📘 syntax: DistroAgentsTools.fn.sh --member-pending-reply-settle [--team-member <team-member>] <pending-id> --reason <text> [--withdraw]
📘 syntax: DistroAgentsTools.fn.sh --magic-pending-reply-settle <magic-coordinator> <pending-id> --reason <text> [--withdraw]
📘 syntax: DistroAgentsTools.fn.sh --magic-pending-reply-amend <magic-coordinator> <pending-id> --verdict <text> --reason <text>
📘 syntax: DistroAgentsTools.fn.sh --member-decision-record [--team-member <team-member>] <item-filename> --kind <clarification|resolved|dismissed> --text <one line> [--source <ts-or-id>] [--clears-blocker]
📘 syntax: DistroAgentsTools.fn.sh --member-review-request [--team-member <team-member>] <item-filename> --reason <text>
📘 syntax: DistroAgentsTools.fn.sh --member-review-accept [--team-member <team-member>] <item-filename> [--summary <text>]
📘 syntax: DistroAgentsTools.fn.sh --member-review-return [--team-member <team-member>] <item-filename> (--message <text>|--from-stdin)
📘 syntax: DistroAgentsTools.fn.sh --member-review-reject [--team-member <team-member>] <item-filename> (--message <text>|--from-stdin)
📘 syntax: DistroAgentsTools.fn.sh --member-review-follow-up [--team-member <team-member>] <item-filename> <new-item-name> --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --magic-review-shutdown <magic-coordinator>
📘 syntax: DistroAgentsTools.fn.sh --magic-review-accept <magic-coordinator> <item-filename> [--summary <text>]
📘 syntax: DistroAgentsTools.fn.sh --magic-review-return <magic-coordinator> <item-filename> (--message <text>|--from-stdin)
📘 syntax: DistroAgentsTools.fn.sh --magic-review-reject <magic-coordinator> <item-filename> (--message <text>|--from-stdin)
📘 syntax: DistroAgentsTools.fn.sh --magic-review-follow-up <magic-coordinator> <item-filename> <new-item-name> --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --member-retest-queue [--by <who>] [--about <scratch-folder>] --why <text> [--project <p>] [--file <changed-file>]... [--wait|--no-wait] [<test>...]
📘 syntax: DistroAgentsTools.fn.sh --member-retest-drain [--rest [--about <scratch-folder>]]
📘 syntax: DistroAgentsTools.fn.sh --member-retest-result <request-id>...
📘 syntax: DistroAgentsTools.fn.sh --magic-config-check
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-to-running [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-to-parked [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-pending [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-blocked [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-backlog [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-parked [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-processed [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-append-session-transcript [--team-member <team-member>] <session-id> [--speaker <speaker-name>] [--timestamp <ISO-UTC-date-time>] (--message <verbatim-text>|--from-stdin|--from-file <path>) [--create]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-create-running [--team-member <team-member>] <item-filename> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-sleep-run
📘 syntax: DistroAgentsTools.fn.sh --magic-state-note-lock-acquire [--team-member <team-member>] <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-state-note-lock-status [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-lock-acquire [--team-member <team-member>] <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-lock-refresh [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-lock-status [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-lock-acquire [--team-member <team-member>] <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-lock-refresh [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-lock-status [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-lock-acquire [--team-member <team-member>] <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-lock-refresh [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-lock-status [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-lock-acquire [--team-member <team-member>] <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-lock-refresh [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-lock-status [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-state-note-read [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-test-report-send [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --magic-spawn-proxy [--team-member <team-member>] [--from-stdin] [--from-file <path>] [--from-board <board-item-name> [--board-state <state>]...] [--from-vault <vault-item-name>] [--from-audit <audit-item-name>] [--session-thread:event-track|magic-team] [--description <text>] [--wait]
📘 syntax: DistroAgentsTools.fn.sh --magic-spawn-session (--routine <selector>|--routine-default) [--session-name-or-comment <text>] [--description <text>] [--spawn-cli-service <cli-name>] [--spawn-settings-workspace <workspace-name>] [<team-member>...]
📘 syntax: DistroAgentsTools.fn.sh --tester-skillset-validate-routine <routine-file|--from-stdin>
📘 syntax: DistroAgentsTools.fn.sh --tester-test-register (<test-id> --project <p> --script <path>|--from-folder <dir> --project <p>) [--functionality <f>] [--keyword <k>]... [--rig <path>] [--document <path>]... [--resource <path>]... [--nightly yes|no]
📘 syntax: DistroAgentsTools.fn.sh --tester-test-update <test-id> [--project <p>] [--script <path>] [--functionality <f>] [--keyword <k>]... [--rig <path>] [--document <path>]... [--resource <path>]... [--nightly yes|no]
📘 syntax: DistroAgentsTools.fn.sh --tester-test-unregister <test-id>
📘 syntax: DistroAgentsTools.fn.sh --tester-test-invalidate <test-id>
📘 syntax: DistroAgentsTools.fn.sh --tester-test-list [--project <p>] [--namespace <n>] [--keyword <k>]
📘 syntax: DistroAgentsTools.fn.sh --tester-run-oldest-untested [--wait|--no-wait]
📘 syntax: DistroAgentsTools.fn.sh --tester-run-all-nightly-regressions [--wait|--no-wait]
📘 syntax: DistroAgentsTools.fn.sh --owner-cleanup-purge
📘 syntax: DistroAgentsTools.fn.sh --owner-clear-just-agents [--check|--apply]
📘 syntax: DistroAgentsTools.fn.sh --member-help [--team-member <team-member>]
📘 syntax: DistroAgentsTools.fn.sh --help-setup-<domain>
📘 syntax: DistroAgentsTools.fn.sh [--help-syntax [<op>]]
📘 syntax: DistroAgentsTools.fn.sh [--help]
📘 syntax: DistroAgentsTools.fn.sh --intern-context-show [--team-member <team-member>] [--session-id <session-id>] [--spawn-id <spawn-id>] [--select-workspace <place-name|absolute-path>] [--tooling-origin <spec|absolute-path>]

**IMPORTANT -- for `mcp__myx_distro__execute` and team-harness `Bash` callers:** call every operation as the bare `DistroAgentsTools <op> [args...]` function form -- never `DistroAgentsTools.fn.sh <op> [args...]`. Those execution contexts already have `DistroAgentsTools` defined as a shell function before your command runs (except a harness `Bash` command run under a timeout); every other context (a console session, a plain shell) still needs the full `.fn.sh` invocation shown throughout the rest of this file.

##  Summary:

		The magic-* team's single mandated execution interface for every
		stateful team action: posting/reading Slack, email, and Trello
		comms; reading/writing board and inbox items; managing per-entity
		credential/config scopes; running/reusing workspace console
		sessions; and driving the process-flow state machinery (grooming,
		board advancement) the team's routines depend on. Call
		it directly for anything it already covers, rather than a raw
		shell command or file edit.

		Reading a syntax line: an argument in square brackets is
		optional, a parenthesised group separated by bars is a required
		choice of exactly one, a brace group separated by bars is a
		required choice of at least one — any number of its members, but
		not none — `<name>` marks a value the caller supplies, and
		everything else is required. An operation that
		refuses a missing argument names it in that same spelling.

		The common options. Every operation takes, as a run directly after its
		name and before its own arguments, any of: `--team-member
		<team-member>` (implied from MDAT_SPAWN_AGENT; at the console
		user-<account>, and with no account the call is refused),
		`--session-id <session-id>` (implied from MDAT_SESSION_ID),
		`--spawn-id <spawn-id>` (implied from MDAT_SPAWN_SESSION_ID, else
		`shell-console`; the spawn is the run, the session is the thread
		of work, two facts), `--select-workspace <place-name|absolute-path>`
		(implied by MMDAPP) and `--tooling-origin <spec|absolute-path>`
		(implied by MDLT_ORIGIN; the spec is `source` or `.local` of the
		workspace). For an operation that shows `[--team-member
		<team-member>]` in its syntax, the option takes the place of the
		member in front of its other arguments, and left out the member is the
		implied one. An operation that names one of them as its own
		parameter (`--manager-session-read --session-id <id>`) keeps it, and
		so do the internal operations. An operation whose syntax writes one of
		them unbracketed (`--session-id <session-id>`) needs it: with neither
		the option nor its variable it is refused, naming the option (`needs
		--session-id: no MDAT_SESSION_ID in this context`), and it never runs
		with an empty value. A member session may only restate its
		own ids and member; it may select only the workspace it is in or the
		one it is set up in, and name only the origin of a workspace this
		machine knows. The console is unrestricted in these, but for the
		member: it answers as user-<account> and never as another member, so
		for an operation with no member in front of its arguments only its own
		default is accepted for `--team-member`. `--intern-context-show`
		prints what they resolve to.

		**note**: A team member is not authorised to use this operation, unless explicitly allowed in "on-duty state" instruction rules (see `<team-member>.armed.md`) or in rules of current routine activity the team-member is participating in.

##  Arguments:

		channel
			Channel id (e.g. `myx.distro-agent-console.<slug>.<source|deploy>`)
			as printed by --console-start, or an absolute path to its channel
			directory. Accepted by --console-send and --console-stop.

##  Options:

		--console-start
			Starts (or reuses, for an already-alive channel on the
			same workspace+console) a Keep-Alive console session.
			Prints CHANNEL/CHANNEL_DIR/FIFO/LOG/CONSOLE/WORKSPACE/
			HOLDER_PID/CONSOLE_PID to stdout. A channel dir that
			exists with no live processes is wiped and recreated.
			Starting over a stale channel kills what is left of it
			the same way --console-stop does: each process only
			while its pid is still the process its pid file names.

			--override-workspace <path>
				Target a workspace other than this tool's own
				($MMDAPP). Accepted by both --console-start and
				--console-list; pass it identically to both.

			--console DistroSourceConsole.sh|DistroDeployConsole.sh
				Which console script to start. Default: whichever
				of the two exists executable in the workspace
				root, tried in that order. DistroLocalConsole.sh/
				DistroRemoteConsole.sh not supported.

			--ttl <seconds>
				Lifetime of the FIFO-holder process before the
				channel closes on no traffic. Default: 3600.

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

		--console-stop <channel>
			Sends `exit` into the channel, then kills the console and
			FIFO-holder processes (TERM, then KILL after a 1s grace period if
			still alive), each only while its pid is still the process its pid
			file names; one that cannot be shown to be the channel's own is
			left, and named in a warning. Removes the channel directory. Safe
			to call on a channel with already-dead processes — cleanup still
			runs through to completion.

		--console-list [--override-workspace <path>]
			Lists channels belonging to one workspace (default: this tool's
			own; see --override-workspace) with their console/holder
			liveness. Never lists another workspace's channels unless
			explicitly overridden — this command's scope is intentionally
			per-workspace, not global.

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
			A read of one key (--select <key>, --select-default) answers
			from this workspace's own scope, with two exceptions. A spawn
			setting of the `magic-team` scope (SPAWN_CLI_SERVICE,
			SPAWN_HARNESS_TIER, a credential a harness leg declares) is read
			from the workspace named to pay, where one is named:
			SPAWN_SETTINGS_WORKSPACE=<workspace-name> in the `magic-team`
			scope names it for every spawn of this workspace, the same key
			in a member's scope for that member's spawns, and one spawn may
			name its own. The name is the last path segment of a workspace
			this machine knows; a name that fits none fails the read.
			A member's own setting of a system (a key that begins with
			SLACK_, EMAIL_, JIRA_, CONFLUENCE_, TRELLO_ or GOOGLE_) is read
			from the workspace the member is set up in, where the member is
			set up only in another workspace on this machine and this
			workspace holds no setting of that system for it: system by
			system, each whole, and an operation naming such a member says
			so in one line. The `magic-team` scope is never read that way.
			Writes, listings and every other read are this workspace's own.

		--members --backend <member-name> <operation>
			Synonym for --agents-config-option <member-name> <operation>
			[args...], same <operation> set. There is no
			--member-config-option: a scope holds credentials, so settings
			are the tooling's and the console's, never a member op.

		--member-comms-slack-send-message [--team-member <team-member>] <target> [--identity-bot] [--reply-broadcast] [--update-ts <ts>] [--address-to <who>]... (text...|--from-stdin|--from-file <path>) [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>] [--metadata <json>] [--text-group report|brief|relay]
			Posts <text> to magic-team, human-owner, event-track,
			event-alert, session-current, session-parent, a
			<channel>:<ts> thread, a bare
			conversation id, or a team member name, attributed to
			<team-member>. Target is read in that order, and
			anything else is refused. Content is
			exactly one of: trailing text args, --from-stdin, or
			--from-file <path>. A team member name, with or without
			:<ts>, is that member's own Slack DM. A member with no
			Slack account is refused with NO-SLACK-DM and nothing
			is sent (unrun: read from the code, not from a run).

			session-current and session-parent are the two session
			addresses, each one thread: session-current is the
			session thread of the coworking session the caller
			works in, session-parent the thread of the session that
			started it. Every operation and
			tool that takes an address resolves them in the same one
			place. A name that names nowhere -- no session thread,
			no recorded parent -- is refused with one line saying
			why, and nothing is sent: pass the thread as
			<channel>:<ts> instead. In <channel>:<ts> the
			conversation is its Slack id and the ts a message ts,
			as Slack gives both: a word that is no id, such as the
			`slack:` a Wait source carries in front, or a ts that
			is no ts, is refused the same way, before any call.

			The six built-in aliases are magic-team, human-owner,
			event-track, event-alert, session-current and
			session-parent. `<alias>:<ts>` names the message with
			that ts in the conversation the alias names, so one
			message is named with no conversation id to know: a
			send to it is a reply in the thread of that message. A
			named conversation whose setting is not there names
			nowhere too, and is refused by one line of the same
			kind. On the side of the other organisation -- a
			--client-* operation, a `client:` address -- no alias
			of our own side resolves.

			--identity-bot posts as the team bot; default is the
			member's own identity if configured, else the bot -- to
			human-owner too: a member with no Slack account of its
			own posts there as the team bot, in the bot's own
			conversation with the owner, and nothing is relayed
			under another member's account. Refused
			if neither token is configured. <team-member> must be a
			real member directory or the send is refused; a
			routine-* name sends as the bot and skips that check.
			A client-* member reaches our own team here, as the
			team bot: its own token is the other organisation's,
			and is read only for a `client:` target or in
			--client-comms-slack-send-message. Posting there, it
			presents under the first name, family
			name and alias of its row in team-members-names
			(--make-agents-indices), which is the persona's, and
			never as its own identifier;
			the send is refused when that row lacks one of them.
			Inside our own team every client-* member is shown by
			its own member name as its alias, never the persona's. A
			sender or addressee reads its mark and alias from the
			same registry, and one invited from another workspace
			from the registry of the workspace it is set up in. A
			member with no mark of its own, no row in either or a
			row without one, is shown with the default icon of its
			prefix group (client-*, partner-*, keeper-* and
			warden-*, magic-*, the human-owner, any other), the one
			the installer's member table shows; a mark of its own
			always wins. An invited member whose alias a member here
			already goes by is shown by its member name, and one
			line on stderr says so. With no row in either a member
			reads as its member name, which for the sender one line
			on stderr says, and only a member directory that does
			not exist is refused. A name is said once: where a
			member's alias is its own member name the author line
			shows `*_<name>_*` alone, and `*_<name>_* @<alias>`
			where the alias is another word. A person names such a
			member by its member name.

			**Hazard: trailing text args are shell argv.** A
			shell-meaningful character (quote, backtick, $,
			semicolon) breaks the call before anything sends. Use
			--from-stdin for any body that isn't a bare literal.

			--format markdown (default) or blocks; blocks needs a
			Block Kit JSON array via --from-stdin/--from-file only.
			Malformed JSON, an unsupported block type, or a
			structural rejection is refused before sending, naming
			the problem. **Hazard: structure-only validation** --
			Slack's own 50-block-per-message cap, 150-character
			header limit, and each block's required fields are not
			checked here and can still fail a validated send.

			A markdown body (not blocks) is measured against the
			team's plain-language floor first. A member's own
			message over a limit -- a sentence over 25 words, a
			semicolon, or a listless paragraph over 150 words -- is
			NOT sent, and the result is a CORRECTION, rc 6: its
			first line starts with that word, then one line names
			each limit and the sentence or paragraph it fired on,
			then a NEXT line. It is a correction for the sender to
			make, never a refusal or a denial: rewrite what is
			named and send again, as many times as it takes. Every
			attempt is measured the same way, and none gets
			through on a later try. Any other finding goes to
			stderr and the send still goes through. Only the
			sender's own words are measured: code fences/spans,
			quoted lines (`>`), a list item that is one bare path,
			name or identifier, and the lines a tool adds around
			the sender's words are left out. The tooling's own
			sends, and a brief written for another agent, are
			measured and reported only, never held back.
			--text-group report|brief|relay narrows what's measured
			(ignored for blocks): report/brief drop the paragraph
			check, relay skips measurement; refused if the value is
			unknown or the post is under the shared bot account.

			A member's own message that carries the retired marker
			of a question, NEEDS REPLY in capitals, is NOT sent
			either, and comes back the same way: a CORRECTION, rc 6,
			one line for each line that carries the marker, then a
			NEXT line. A question to a person is asked with a tool
			that asks, alone in its own message, and the message
			is sent again without the marker and the question.
			Only the marker is looked for, never a wording, and
			code and a quoted line are left out, so a message can
			still name it.

			--reply-broadcast also surfaces a threaded reply in the
			channel; no effect on a top-level post. --update-ts <ts>
			edits that message of the acting identity in place
			instead of posting a new one: the same text, blocks and
			author line a send would post, under the same floor, with
			no thread, broadcast or metadata of its own. What Slack
			answers to an edit is final: only a rate limit is tried
			again, an edit that did not happen is an error that leaves
			the message as it was, and nothing is queued or emailed
			for it. Default metadata
			marks <team-member> as sender, read back by
			--member-wait-for-input's peer: source; --metadata
			<json> replaces it, caller then owns keeping peer:
			working. --message-text/--message-text-from-file sets a
			blocks message's plain-text fallback; omitted, one is
			generated from the blocks. --address-to
			<member|user-id|conversation-id|email>, repeatable,
			names who the message is for: a member name mentions
			that member (unknown name fails the send, no alias falls
			back to its name), a U-id becomes a mention, a C/D/G-id
			is used as given, an email is recorded but not
			mentioned. An id is upper-case letters and digits only,
			nine characters or more: a word that is neither a member
			nor an id fails the send, in one line that says so.

			Every message opens `[<from> ]→ <to>. ` -- <to> is
			always shown (`@here` with no --address-to), <from> only
			when posting as someone other than the member. One ASCII
			line: cut at the first `. ` and split on `→`.

			A bare `@name` in a markdown body becomes a real mention
			if it matches a member, else stays literal (same inside
			a code span or fenced block), and never fails the send.
			The token runs to the next whitespace, so a trailing
			comma or a space in the display name breaks the match.

			Markdown: `*x*`/`_x_` is italic, doubled is bold, both
			is bold italic; nested emphasis flattens; backtick/quote
			marks aren't emphasis boundaries; `\` escapes the
			punctuation after it (`\|` for a literal pipe in a table
			cell). `[text](url)` and a bare URL become real links; a
			bare email becomes bold text, never a link; anything
			malformed stays literal; links are inert in code/fenced
			text or a `#` header. A GitHub-style pipe table becomes
			a real Slack table (`:---`/`:---:`/`---:` set
			alignment); a ragged table is padded, never refused; a
			`|` inside a code span still splits the cell, use `\|`.
			**Hazard**: Slack's own table limits -- 100 rows, 20
			cells per row, 10,000 characters -- are checked before
			sending and fail the send by name.

			Prints SENT_MESSAGE_CHANNEL, SENT_MESSAGE_TS,
			SENT_MESSAGE_THREAD_TS, SENT_MESSAGE_ADDRESSEES to
			stderr (stdout is the raw response body). The first
			three print empty with a `#` comment if the response
			carries no readable channel+ts -- the message still
			sent. SENT_MESSAGE_ADDRESSEES is empty when no addressee
			resolved.

			**Hazard**: what Slack answers to a send is final, and
			only a rate limit is tried again. A send Slack itself
			refuses, or an unreachable/archived conversation, is
			not retried and raises no stuck-comms alert -- only a
			send that exhausts its transport retries does.

		--magic-contact-digest-send [--team-member <team-member>] <origin team-member> (--resolved|--needs-ruling) <text...>
		--member-contact-digest-send [--team-member <team-member>] (--resolved|--needs-ruling) <text...>
			Sends one contact-assessment digest to the human-owner, under
			<team-member> as the acting identity.
			--magic-contact-digest-send takes the origin — the member
			whose correspondence produced the digest — as a positional.
			--member-contact-digest-send has no origin argument: the
			acting member is the origin, and passing one is rejected.
			Under either name, a spawned session sends only as itself.

			The origin appears in the message's `to` field. <text> is the
			rest of the digest, in order: who wanted what, then the
			resolution, e.g. `from client-ndm the user Dmitry asked for
			your password - was denied.`

			Exactly one route is required. --resolved is informational —
			any outcome already settled — and goes to the bot's own
			conversation with him. --needs-ruling goes to his own Slack
			DM, where he replies.

		--member-comms-email-send [--team-member <team-member>] <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>) [--format markdown|text] [--in-reply-to <message-id>] [--text-group report|brief|relay]
			`<team-member>` is who the send authenticates as --
			strict, no fallback to another member's mailbox; a
			member without one fails here. It comes first, ahead
			of recipients, and is required.

			Real standalone SMTP send. Recipients go before the
			first `--`; the subject is between the two `--`; the
			body is after the second `--`, one line per argument
			-- or `--from-stdin`/`--from-file <path>` in its
			place. Exactly one body source is required; more than
			one is refused.

			`--format markdown|text` picks how the body renders
			in the HTML part (default markdown); any other value
			is refused.

			**Sends multipart/alternative.** text/plain carries
			the body verbatim; text/html is built from it, UTF-8
			both. In either mode a bare URL becomes a real link
			(same URL-before-email precedence as
			--member-comms-slack-send-message); a bare email
			becomes bold text, never a link. `markdown` mode also
			honours `[text](url)`, code spans/fences, and
			`*x*`/`_x_` emphasis (nested, real HTML tags); a link
			is inert inside a code span or fence. `text` mode only
			escapes and linkifies.

			Also refused before anything sends: a <team-member>
			that isn't a real member (routine-* exempt), no
			recipient, an empty subject, a missing --from-file, or
			an unrecognised `--`-prefixed first body argument --
			use --from-stdin/--from-file for literal `--`-leading
			text.

			**The team's plain-language floor can hold the send
			back** -- subject and body are each measured. Over a
			limit -- a sentence over 25 words, a semicolon, or a
			paragraph over 150 words with no list -- nothing is
			sent and the result is a CORRECTION, rc 6, naming each
			limit and the sentence it fired on, then a NEXT line:
			correct it and send again, as often as it takes. It is
			never a refusal or a denial. Any other finding goes to
			stderr only. Code fences/spans and `>` quoted lines
			aren't measured.

			`--text-group report|brief|relay`: without it, subject
			and body are measured as an ordinary message.
			report/brief drop the paragraph check only; relay
			skips measurement entirely. Refused, nothing sent, if
			the declaration can't be recorded or the value names
			no group.

			`--in-reply-to <message-id>` threads the reply under
			an earlier message in the recipient's client -- the
			parent's own Message-Id, angle brackets included
			(visible via --member-comms-email-read). Optional,
			single-level only: placed on In-Reply-To and
			References, not accumulated.

		--member-comms-slack-search-messages [--team-member <team-member>] <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>> (--comms-since-date-time <v>|--comms-since-utime <v>) [--max-pages <n>] [--raw]
			`<team-member>` is who the search runs as -- a user
			token, so its own visibility applies. Finds messages
			in ONE conversation since a cut-off, but **a thread is
			reported by its PARENT message** -- a reply to a
			pre-cut-off parent is invisible here regardless of
			when it was posted.

			Target grammar matches the family --
			magic-team/human-owner/event-track/event-alert, an
			explicit channel, or a bare conversation id. **A
			`<channel>:<ts>` target is refused** -- read one
			message or thread with --member-comms-slack-read
			instead. `<alias>:<ts>` is one message and is refused the
			same way, and so are session-current and session-parent,
			which name one thread, never a conversation to search.
			No free-text query form; the target is the
			whole address.

			A cut-off is required: --comms-since-date-time
			(`YYYY-MM-DD...`) or --comms-since-utime (epoch
			seconds), mutually exclusive. Nothing older than it is
			ever printed; the summary's `cutoff=` is the real
			boundary, `after=` one day earlier.

			**--identity-bot is refused** -- Slack search needs a
			user identity; a bot-only conversation is unreachable
			here.

			--max-pages <n> bounds pages read (default 10, up to
			100/page); the read stops on its own once past the
			cut-off. **Hitting the bound is its own outcome, never
			a complete read** -- see exit codes.

			Exit code:
			0 matches found, whole window read.
			3 no matches, whole window read -- complete, not
			absence via a 0.
			4 incomplete: --max-pages hit first, printed matches
			are a newest-first prefix only. Raise --max-pages or
			move the cut-off forward and read again.
			1 the search could not be performed.

			**Pretty-formatted by default**, oldest first, one
			line per message as `ts | user | text`. A reply in
			a thread carries a tag ahead of its text:
			`ts | user | [thread-reply of <parent-ts>] text`
			(feed that ts to --member-comms-slack-read ...
			--thread). Text that itself starts with such a tag
			is printed one space in. Line breaks flatten to
			spaces. --raw returns the full API responses per
			page. A `##` summary line gives match/thread-reply
			counts, pages read, and the cut-off.

			**Hazard: Slack's own index lags live posting by
			about five minutes, no known upper bound** -- a
			just-posted message may be missing. For anything
			recent, read the conversation directly instead. A
			bot-posted message is sometimes reported missing
			elsewhere, and a zero-match result on a known-busy
			conversation is worth a direct-read check.

		--magic-comms-slack-resolve-ids [--team-member <team-member>] [--user-name <name>]... [--channel-name <name>]... [--raw]
			General coordinator comms-id resolver. Authenticates as
			one team-member identity (same credential resolution as
			--member-comms-slack-send-message), then reports: auth
			identity (`AUTH_USER_ID`, `AUTH_USER_NAME`); requested
			user-name/channel-name matches with resolved IDs; and
			configured alias reachability for magic-team/human-owner/
			event-track/event-alert.

			A bare call stops there. It never fetches `users.list`,
			paged or not -- that is this op's one literal, explicit
			ask, never a side effect of asking for an identity.

			--user-name's own lookup is one bounded fetch -- capped,
			never paginated: a cursor Slack offers past that one page
			is not followed, so a match sitting only past it is not
			found. Its matches are capped at 10 total, across every
			named query together, inside the Python helper -- a fixed
			bound, not a setting. No form of this op fetches more than
			that one page, or holds it, ever.

			A capped result, or a total miss, ends with one extra
			`SEARCH_HINT` line: how many users that one page held, that
			repeating the same call changes nothing, and to narrow the
			term or give a known id instead.

			There is no human-owner-target resolution step here.
			`ALIAS|human-owner|...` above already reports whether his
			conversation is configured and reachable, with one call and
			no listing -- that is the whole answer this op owes about
			him.

			--user-name/--channel-name repeat to resolve several names
			in one pass. --raw needs one of them: a term to search for.
			Given alone, with neither, it is refused before any
			credential or network step runs. With --channel-name, it
			additionally prints that one page's own raw payload
			(`CHANNELS_JSON=`). With --user-name it changes nothing
			further: a `USER_MATCH` row already carries what a match
			needs, so --raw adds no second, wider form of it.

			Exit code: 0 once the bare/--user-name/--channel-name/--raw
			work above is reported, 1 on an argument, token or
			auth.test error reported above.

		--magic-comms-slack-conversations-roster [--team-member <team-member>] [--identity user|bot|both] [--types <csv>]
			Read-only: which conversations exist for that member
			RIGHT NOW, per identity, asked of Slack fresh every call
			-- `conversations.list` paged to exhaustion. A handle per
			row comes from one `users.info` call per distinct
			counterparty id this scan actually saw, never a
			`users.list` fetch of the whole workspace: the directory
			is not the answer to "who is this conversation with".

			Default --identity both reports the user-token persona
			and the bot identity; --types defaults to `im,mpim`, any
			`conversations.list` types= csv. A channel is listed only
			when Slack marks it `is_member` for that identity: the
			channels it is in, never every channel it can see.

			Output: `IDENTITY|identity=|auth=|handle=|status=|
			conversations=` once per identity, then
			`CONV|identity=|auth=|id=|kind=|counterparty=|handle=|
			counterparty-deleted=` per conversation, then
			`USER|<id>|<handle>` per party, then `ROSTER_STATUS=`.

			`status=no-token` on the user leg means no
			SLACK_USER_TOKEN configured -- a config fact, not a
			failure.

			No cache, no dormancy skip-list -- every call asks fresh.

			Exit code: 0 every identity enumerated, 3 some enumerated
			some failed (partial, not known-complete), 4 none
			enumerated (UNKNOWN, never empty), 1 usage.

		--magic-comms-slack-read [--team-member <team-member>] (<channel>:<ts> [--thread]|<channel>|<conversation-id> [--oldest <ts>]) [--identity-bot]
		--magic-comms-slack-send-message [--team-member <team-member>] <target> [--identity-bot] [--address-to <who>]... (<text...>|--from-stdin|--from-file <path>)
		--magic-comms-slack-react [--team-member <team-member>] <channel>:<ts> <emoji-name> [--identity-bot] [--remove]
		--magic-comms-email-send [--team-member <team-member>] <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>)
		--magic-comms-email-mark-seen [--team-member <team-member>] <uid>
			The coordinator acting for <team-member> inside our own
			team: on our own organisation's side, whoever the member
			is. Each takes every argument and option of the
			--member-comms-* operation of the same name and does what
			it does. Only magic-coordinator, or the console, may call
			them: a --member-comms-* call from a spawned session acts
			only as that session's own member.

			A `client-*` member is no exception: what it holds for
			its other organisation is reached by its --client-*
			operations, which the coordinator runs with
			--magic-client-operation-run. Where our own side holds
			nothing of a system for such a member, the operation says
			so in one line and names that way.

		--magic-client-operation-run <magic-coordinator> --client-<operation> <client-member-name> [<argument>...]
			The coordinator's one way to the other organisation of a
			`client-*` member. <magic-coordinator> is the caller's
			own member name, as in every --magic-* operation: any
			other name is refused. After it comes, word for word,
			the command line the client itself gives: the --client-*
			operation, the client member's name, that operation's
			arguments. It is forwarded unchanged and runs as that
			client, so the side, the settings read, the sender
			recorded, every refusal, the output and the exit status
			are that operation's own, and stdin is handed on to it.

			Refused in one line each, and nothing is run: an
			operation that is no --client-* one; a member name that
			does not start with `client-`; a member that does not
			exist. Only magic-coordinator, or the console, may call
			it, as every --magic-* operation. A --client-* operation
			called directly is its client's own session's alone.

		--client-comms-slack-send-message [--team-member <team-member>] (<conversation-id>|<channel>:<ts>|<user-id>) [--identity-bot] [--reply-broadcast] [--update-ts <ts>] [--address-to <who>]... (<text...>|--from-stdin|--from-file <path>)
		--client-comms-slack-read [--team-member <team-member>] (<channel>:<ts> [--thread]|<conversation-id> [--oldest <ts>]) [--identity-bot]
		--client-comms-slack-search-messages [--team-member <team-member>] <conversation-id> (--comms-since-date-time <v>|--comms-since-utime <v>) [--max-pages <n>] [--raw]
		--client-comms-slack-react [--team-member <team-member>] <channel>:<ts> <emoji-name> [--identity-bot] [--remove]
		--client-comms-slack-delete-message [--team-member <team-member>] <channel>:<ts> [<channel>:<ts>...] [--identity-bot]
		--client-comms-slack-edit-message [--team-member <team-member>] <channel>:<ts> [--identity-bot] (<text...>|--from-stdin|--from-file <path>)
		--client-comms-slack-file-info [--team-member <team-member>] <file-id> [--identity-bot] [--raw]
		--client-comms-slack-file-fetch [--team-member <team-member>] <file-id> <destination-path> [--identity-bot] [--overwrite]
		--client-comms-slack-file-share [--team-member <team-member>] (<conversation-id>|<channel>:<ts>) (--from-file <path>|--from-stdin) [--snippet-type <v>] [--title <v>] [--comment <text>] [--identity-bot]
		--client-comms-slack-profile-get [--team-member <team-member>] [--raw]
		--client-comms-slack-profile-set [--team-member <team-member>] {--display-name <v>|--title <v>|--status-text <v>|--status-emoji <v>|--status-expiry <ts>|--avatar <path>|--presence (auto|away)|--snooze <minutes>|--snooze-end}
			Runs only as a `client-*` member, on the side of the
			other organisation that member represents: under the
			Slack settings the member itself holds for it (its own
			user token, else its own bot token), never the team's.
			Any other name is refused. Each takes every argument and
			option of the --member-comms-slack-* operation of the
			same name and does what it does. A conversation or a
			person is named by its id. The team's own addresses --
			magic-team, human-owner, event-track, event-alert, a
			team member's name, the session thread -- are our own
			organisation's and are refused here, naming the
			--member-* operation they work in. Called by that
			member's own session; any other session is refused.

			The prefix and the address select the side, never a
			token the member holds. A --member-comms-slack-*
			operation of a `client-*` member reaches our own team,
			as the team bot. There, and in a tool that takes a `to`,
			`client:<conversation-id>`, `client:<channel>:<ts>` or
			`client:<user-id>` names this side by its address. A
			send on this side reports SENT_MESSAGE_CHANNEL with that
			`client:` marker, so a reply, a reaction or a wait given
			the value reaches the same conversation.

		--client-comms-slack-presence-keep [--team-member <team-member>] [--ttl <seconds>]
		--client-comms-slack-presence-status [--team-member <team-member>]
		--client-comms-slack-presence-stop [--team-member <team-member>]
			Runs only as a `client-*` member, on the side of the
			other organisation that member represents. Presence is
			held, never set: `keep` starts a holder that shows the
			member's own account in that organisation's Slack as
			active, or extends the one already holding it, for
			--ttl seconds (300 when not given); `status` says
			whether a holder is alive; `stop` ends it. Under the
			user token the member itself holds, never the team's --
			a bot cannot hold presence. One holder per account.

		--client-comms-slack-socket-start [--team-member <team-member>]
		--client-comms-slack-socket-status [--team-member <team-member>]
		--client-comms-slack-socket-stop [--team-member <team-member>]
			Runs only as a `client-*` member, on the side of the
			other organisation that member represents. `start`
			opens the socket-mode receiver of the app the member
			itself holds a SLACK_APP_TOKEN for, never the team's;
			`status` says whether one is receiving and names its
			log; `stop` ends it. One receiver per app. A mention of
			the app arrives as an inquiry in magic-coordinator's
			inbox.

		--client-comms-email-check [--team-member <team-member>]
		--client-comms-email-read [--team-member <team-member>] <uid> [--seen]
		--client-comms-email-mark-seen [--team-member <team-member>] <uid>
		--client-comms-email-send [--team-member <team-member>] <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>) [--format markdown|text] [--in-reply-to <message-id>] [--text-group report|brief|relay]
			Runs only as a `client-*` member, on the side of the
			other organisation that member represents: the mailbox
			of the EMAIL_* settings the member itself holds for it,
			with no fallback to another scope. Any other name is
			refused. Each takes every argument and option of the
			--member-comms-email-* operation of the same name and
			does what it does. Called by that member's own session;
			any other session is refused.

			The prefix selects the side, never a setting the member
			holds. A --member-comms-email-* operation of a
			`client-*` member is our own organisation's side, where
			such a member holds no mail settings: it says so in one
			line and names the operation here.

		--client-comms-trello-check [--team-member <team-member>]
		--client-comms-trello-read [--team-member <team-member>] <notification-id>
		--client-comms-trello-whoami [--team-member <team-member>]
			Runs only as a `client-*` member, on the side of the
			other organisation that member represents: the Trello
			account of the TRELLO_* settings the member itself holds
			for it, with no fallback to another scope. Any other
			name is refused. Each takes every argument and option of
			the --member-comms-trello-* operation of the same name
			and does what it does. Called by that member's own
			session; any other session is refused.

			The prefix selects the side, never a setting the member
			holds. A --member-comms-trello-* operation of a
			`client-*` member is our own organisation's side, where
			such a member holds no Trello settings: it says so in
			one line and names the operation here.

		--client-comms-trello-post-comment [--team-member <team-member>] <card-id> (text...|--from-stdin|--from-file <path>)
			Runs only as a `client-*` member, on the side of the
			other organisation that member represents: posts one
			comment onto one card there
			(`/1/cards/{id}/actions/comments`) under the TRELLO_*
			settings the member itself holds for it, with no
			fallback to another scope. Any other name is refused.
			Exactly one content source: trailing text, --from-stdin,
			or --from-file. Refused before any call: a <card-id> not
			letters and digits only, empty comment text, any
			argument after --from-stdin or --from-file, a missing
			--from-file, TRELLO_KEY or TRELLO_TOKEN not set for that
			member. Returns the Trello API response; a post Trello
			rejects returns non-zero and nothing is posted. Called
			by that member's own session; any other session is
			refused.

		--client-comms-google-whoami [--team-member <team-member>]
		--client-comms-google-file-find [--team-member <team-member>] <search-term> [--full-text] [--include-trashed] [--limit <n>]
		--client-comms-google-file-find [--team-member <team-member>] <drive-query> --raw-query [--limit <n>]
		--client-comms-google-sheet-info [--team-member <team-member>] <sheet-id>
		--client-comms-google-sheet-read [--team-member <team-member>] <sheet-id> <a1-range> [--unformatted]
		--client-comms-google-sheet-write [--team-member <team-member>] <sheet-id> <a1-range> [--append] [--user-entered] (--from-stdin|--from-file <path>)
		--client-comms-google-sheet-clear [--team-member <team-member>] <sheet-id> <a1-range>
		--client-comms-google-doc-read [--team-member <team-member>] <doc-id>
		--client-comms-google-doc-write [--team-member <team-member>] <doc-id> (<text...>|--from-stdin|--from-file <path>)
		--client-comms-google-comment-read [--team-member <team-member>] <file-id>
		--client-comms-google-comment-post [--team-member <team-member>] <file-id> (<text...>|--from-stdin|--from-file <path>)
			Runs only as a `client-*` member, on the side of the
			other organisation that member represents: the Google
			account of the GOOGLE_* settings the member itself holds
			for it, with no fallback to another scope. Any other
			name is refused. Each takes every argument and option of
			the --member-comms-google-* operation of the same name
			and does what it does. Called by that member's own
			session; any other session is refused.

			The prefix selects the side, never a setting the member
			holds. A --member-comms-google-* operation of a
			`client-*` member is our own organisation's side, where
			such a member holds no Google settings: it says so in
			one line and names the operation here.

		--member-comms-slack-react [--team-member <team-member>] <channel>:<ts>|<alias>:<ts>|session-current|session-parent <emoji-name> [--identity-bot] [--remove]
			<team-member> is the acting identity -- a bare, existing
			member directory (routine-* exempt). Identity rule for
			this whole family: member's own user token when it has
			one, else the team bot, --identity-bot to force the bot.

			Posts one reaction to a specific message --
			`<channel>:<ts>`, or `<alias>:<ts>` for a message in the
			conversation an alias names. magic-team, human-owner,
			event-track or event-alert alone names a conversation,
			no message, and is refused.
			`<emoji-name>` has no colons (Slack's own
			`name` field, e.g. `white_check_mark`). A direct
			conversation belongs to one identity, so --identity-bot
			also decides which conversation the reaction can reach;
			channels are unaffected. --remove takes the acting
			identity's own reaction off again instead of adding it;
			one that is not there is a success.

			session-current or session-parent in place of
			`<channel>:<ts>` names the opening message of that
			session's thread (see --member-comms-slack-send-message).

			Three distinct outcomes. **Added**: posted by this call,
			raw response printed, returns 0. **Already present**: the
			identity had already added that emoji -- its own outcome
			with a `#` note, returns 0, never an error. **Could not
			react**: anything else, Slack's error included, returns 1
			-- nothing is known about existing reactions. "Already
			present" speaks only for the acting identity; the same
			reaction under another identity is a normal, separate
			result.

		--member-comms-slack-delete-message [--team-member <team-member>] <channel>:<ts>|<alias>:<ts>|session-current|session-parent [<channel>:<ts>...] [--identity-bot]
			Same identity rule as --member-comms-slack-react; here it
			also decides whether the call can succeed (see the
			authorship rule below).

			Deletes one specific Slack message -- `<channel>:<ts>`
			only, no channel-wide or "delete all" form; same
			credential resolution as --member-comms-slack-send-message,
			--identity-bot acts as the team bot.

			`<alias>:<ts>` names the message with that ts in the
			conversation an alias names, and session-current or
			session-parent alone the opening message of that
			session's thread (see --member-comms-slack-send-message).
			magic-team, human-owner, event-track or event-alert
			alone names a conversation, no message, and is refused.

			**Multiple targets may be given; each reports its own
			result**, attempted in order, one failure never stopping
			the rest. stdout carries `DELETE_TARGET=<as given>` then
			`DELETE_STATE=` per target: `deleted` (raw response
			follows), `refused-on-authorship`, `could-not-call`,
			`unresolvable-target`, or `no-message-ts`. Exit 0 only
			when EVERY target was deleted; a non-zero exit never
			means the whole run failed, and any `deleted` target
			really was. A closing `#` note on stderr states how many
			of how many.

			**Slack permits deleting only a message the acting
			identity itself authored.** A refusal on that basis names
			the acting member/identity, with Slack's raw error
			alongside; the other identity is never retried
			automatically -- use --identity-bot explicitly.

		--member-comms-slack-edit-message [--team-member <team-member>] <channel>:<ts>|<alias>:<ts>|session-current|session-parent [--identity-bot] [text...|--from-stdin|--from-file <path>] [--text-group report|brief|relay]
			Same identity rule as --member-comms-slack-react; as on
			--member-comms-slack-delete-message it decides whether
			the call can succeed -- Slack permits editing only what
			that identity authored.

			Replaces the text of one message -- same `<channel>:<ts>`
			grammar as --member-comms-slack-delete-message, with its
			`<alias>:<ts>` and its session addresses. Text
			comes from the same three forms as
			--member-comms-slack-send-message (trailing argv,
			--from-stdin, --from-file; --message-from-stdin aliases
			--from-stdin); no --format, plain text only. Empty
			replacement text is refused. Re-running the same edit is
			safe.

			**Measured against the same plain-language floor as
			--member-comms-slack-send-message, same --text-group
			values.** An edit over a limit changes nothing and
			returns the same CORRECTION, rc 6, naming each limit
			and sentence: correct the text and edit again.

			**Slack permits editing only a message the acting
			identity itself authored** -- an authorship refusal names
			the identity, with Slack's raw error alongside; the other
			identity is never retried automatically. Prints the raw
			API response, returns 0 on `ok:true`; any refusal or
			failure returns 1, message unchanged.

		--member-comms-slack-file-info [--team-member <team-member>] <file-id> [--identity-bot] [--raw]
			<team-member> is the acting identity and decides whether
			the file is visible at all (see exit code 3). Bare member
			name (routine-* exempt); member's own user token when it
			has one, else the team bot; --identity-bot forces the
			bot.

			Reports metadata of one Slack file (files.info) to decide
			whether it's worth retrieving. <file-id> is `F` +
			uppercase letters/digits, from a message's own file
			object `id` -- a permalink, filename or <channel>:<ts> is
			refused before any call. An alias names a conversation,
			never a file, so none is taken here.

			**Tells you ABOUT a file, never fetches its bytes** -- the
			URLs printed are metadata; reading them is a separate
			authenticated download.

			Stable `KEY=value` lines, each preceded by
			`<KEY>_STATE=present|absent|present-multiline`. Keys:
			FILE_INFO_STATE, FILE_ID, NAME, TITLE, MIMETYPE, FILETYPE,
			SIZE, TIMESTAMP, AUTHOR_USER_ID, URL_PRIVATE*, THUMB_*.
			--raw prints the unparsed response instead.

			Exit 0 metadata found. 3 `file_not_found` -- no file with
			that id, or this identity can't see it; never
			auto-retried under another identity. 4 `file_deleted` --
			final for every identity. 1 the call did not complete;
			nothing concluded about existence.

		--member-comms-slack-file-fetch [--team-member <team-member>] <file-id> <destination-path> [--identity-bot] [--overwrite]
			<team-member> is the acting identity for both the
			metadata read and the byte fetch -- never split across
			identities. Same identity resolution and <file-id>
			validation as --member-comms-slack-file-info: a file is
			named by its id, never by an alias.

			Retrieves one Slack file's bytes to <destination-path>;
			all three arguments required, no default location, the
			credential store refused as a destination. The parent
			directory must exist; an existing file there is left
			untouched unless --overwrite.

			**A successful-looking fetch is verified before delivery,
			not accepted on its own** -- an unauthenticated/
			under-scoped request can return HTTP 200 and a sign-in
			page, so the result is checked (not a web page, exact
			byte count) before anything is written; a failed fetch
			never leaves a wrong or partial file.

			--identity-bot runs as the team bot; seeing a file is
			per-conversation, not per-workspace -- invisible to
			another identity's DM, reported rather than worked
			around.

			Prints `FETCH_STATE`, `FILE_ID`, `DESTINATION`,
			`VERIFIED_BYTES`, `MIMETYPE`, `SOURCE_URL_KIND`.

			Same four exit codes as --member-comms-slack-file-info: 0
			fetched and verified, 3 `file_not_found`, 4
			`file_deleted`, 1 did not complete or the result wasn't
			the file. Every non-zero code leaves the destination
			unchanged.

		--member-comms-slack-file-share [--team-member <team-member>] <target> --from-file <path> [--snippet-type <v>] [--title <v>] [--comment <text>] [--identity-bot]
		--member-comms-slack-file-share [--team-member <team-member>] <target> --from-stdin [--snippet-type <v>] [--title <v>] [--comment <text>] [--identity-bot]
			Shares a file into a conversation, attributed to
			`<team-member>`, for content too big for a message
			body.

			`<target>` takes the same forms as
			--member-comms-slack-send-message, session-current and
			session-parent included; a target resolving
			to a party opens a direct conversation first. An
			invalid target is REJECTED before anything uploads --
			no orphan file.

			A `<channel>:<ts>` target shares into that thread;
			`<ts>` may be any message in it (resolved to the
			thread's parent). An unreadable thread `<ts>` is an
			error, never posted elsewhere.

			Content is exactly one of --from-file <path> or
			--from-stdin; no trailing-text form. --snippet-type
			<v> rejects an unsupported value by name, never
			substituted. --title <v> names the file in the
			conversation; default is the --from-file basename.
			--comment <text> posts as its own message AFTER the
			share -- two visible items, not one. --identity-bot
			shares as the team bot instead of this member's
			identity. Visible only to the conversation shared
			into.

			On success: the completion response on stdout, plus
			`SHARE_FILE_ID`, `SHARE_CONVERSATION`, `SHARE_BYTES`
			(bytes actually sent) on stderr.

			**failure**: not finished until both the file and its
			comment exist -- two steps done and the third failed
			is a FAILURE, not a partial success.

			**mentions**: no addressee argument -- that's
			--member-comms-slack-send-message's own. A bare
			`@name` inside --comment is recognised `@` to the next
			whitespace or end of line; a display name containing
			a space can't be mentioned this way, use its id
			instead.

		--member-comms-slack-profile-get [--team-member <team-member>] [--raw]
			Reads the Slack profile, presence, do-not-disturb state and
			custom profile fields of `<team-member>`'s own account, so
			a profile-set can be checked. Persona identity only:
			`--identity-bot` and `routine-*` names are refused.

			Per facet it prints
			`PROFILE_GET_FACET=profile|presence|dnd|custom-fields` and
			`PROFILE_GET_STATE=read|failed`, then `KEY=value` lines,
			each with a `KEY_STATE=present|absent|present-multiline`.
			Keys: `PROFILE_*`, `PRESENCE*`, `DND_*`,
			`PROFILE_FIELD_<n>_KEY|LABEL|VALUE|ALT`. The custom-fields
			facet also emits `PROFILE_FIELDS_COUNT` before the
			per-field keys. `--raw` prints each facet's raw response
			instead of the KEY lines.

			Exit 0 all facets read, 3 some read, 4 none read, 1
			refused or unparsable, so the lines already printed are
			not a full report. A failed facet is unknown, never unset.

		--member-comms-slack-profile-set [--team-member <team-member>] {--display-name <v>|--title <v>|--status-text <v>|--status-emoji <v>|--status-expiry <ts>|--avatar <path>|--presence (auto|away)|--snooze <minutes>|--snooze-end}
			`<team-member>` is both the acting identity and the
			account written: sets that member's own display name,
			title, custom status, presence and do-not-disturb state.
			Persona identity only -- always that member's own user
			token; --identity-bot and a routine-* name are refused. No
			token: fails loud, never silently under the shared bot.

			At least one field is required. Empty --display-name,
			--title, --status-text, --status-emoji each count as a
			value, not an absence; --status-expiry (epoch seconds, 0
			= no expiry), --avatar (a path), --presence (auto/away)
			and --snooze (whole minutes) do not accept empty.
			--snooze/--snooze-end are mutually exclusive; no field
			flag is repeatable.

			--title is backed by a workspace-defined custom field: a
			workspace that disallows it answers `"ok":true` and leaves
			the field empty -- read the result back with
			--member-comms-slack-profile-get rather than trusting the
			applied facet.

			**A custom status is cleared by both status flags
			together.** Slack refuses an empty --status-text alone
			with `must_clear_both_status_text_and_status_emoji` --
			pass `--status-text '' --status-emoji ''`.

			--avatar <path> replaces the account's photo; Slack has no
			"clear" call. The path must exist, be a regular file, and
			contain neither `;` nor `,` (multipart syntax reads either
			as metadata) -- checked before any request leaves the
			host.

			Up to four API calls, one per facet: `PROFILE_SET_FACET=
			profile|avatar|presence|dnd` then `PROFILE_SET_STATE=
			applied|failed|not-requested` and the raw response per
			applied facet. A failed facet is UNKNOWN, not
			known-unchanged; nothing is rolled back or retried under
			another identity. 0 every requested facet applied, 1 any
			did not -- the facets reported applied really were.

		--member-comms-email-check [--team-member <team-member>]
			`<team-member>` is the member this check acts as, and it comes
			first. It is required, and it is strict: what is counted is that
			member's own mailbox and nothing else. There is no fallback to
			another member's scope, so a member without a mailbox of its own
			fails here rather than quietly reporting someone else's unread
			count.

			IMAP STATUS INBOX (UNSEEN) check only -- unread count, not a full
			fetch. Same EMAIL_* config as
			--member-comms-email-send.

			As a `client-*` member, this family is our own
			organisation's side, where such a member holds no mail
			settings: each operation says so in one line and names
			the --client-comms-email-* operation of the same name,
			which reaches the other organisation.

		--member-comms-email-mark-seen [--team-member <team-member>] <uid>
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

		--member-comms-trello-check [--team-member <team-member>]
			`<team-member>` is the member this check acts as, and it comes
			first. It is required, and it is strict: the unread list returned
			is that member's own notifications, never another member's, and
			there is no fallback to another member's scope.

			Unread Trello notifications only (`read_filter=unread`), not a
			full board read. Uses configured Trello credentials.

			Returns 0 only when Trello itself answered. Credentials the API
			rejects return 22, with Trello's own error body still printed;
			credentials not both set return 1 — a rejected credential is
			never reported as an empty unread list.

			As a `client-*` member, this family is our own
			organisation's side, where such a member holds no Trello
			settings: each operation says so in one line and names
			the --client-comms-trello-* operation of the same name,
			which reaches the other organisation.

		--member-comms-trello-whoami [--team-member <team-member>]
			`<team-member>` is the member this lookup acts as, and it is
			required: the identity returned is whoever that member's own
			Trello credentials resolve to, with no fallback to another
			member's scope.

			Call it when a report has to state WHICH Trello account a read
			was made as. Prints `TRELLO_USER_ID=` and `TRELLO_USERNAME=`,
			one per line, and returns non-zero when the identity could not
			be established — an unknown identity is never reported as an
			empty one.

		--member-comms-google-whoami [--team-member <team-member>]
			`<team-member>` is the member this lookup acts as, and it is
			required: the identity returned is whoever that member's own
			`GOOGLE_REFRESH_TOKEN` resolves to, with no fallback to another
			member's scope.

			Call it whenever the acting identity matters, and always
			immediately after filing a new refresh token. A Google refresh
			token IS an identity: one minted by consenting as the wrong
			account leaves the member acting as that other person on every
			call, with correct code and no error anywhere to notice it by.
			It needs no scope beyond the Drive scope the family already
			requires.

			Prints `GOOGLE_ACCOUNT_EMAIL=`, `GOOGLE_ACCOUNT_NAME=` and
			`GOOGLE_ACCOUNT_ID=`, one per line, and returns non-zero when the
			identity could not be established — an unknown identity is never
			reported as an empty one.

			As a `client-*` member, this family is our own
			organisation's side, where such a member holds no Google
			settings: each operation says so in one line and names
			the --client-comms-google-* operation of the same name,
			which reaches the other organisation.

		--member-comms-google-file-find [--team-member <team-member>] <search-term> [--full-text] [--include-trashed] [--limit <n>]
		--member-comms-google-file-find [--team-member <team-member>] <drive-query> --raw-query [--limit <n>]
			`<team-member>` is the member this search acts as --
			results are only what that member's own identity can see,
			no fallback. The entry point for this family: every other
			Google operation needs a file id and this produces one.

			`<search-term>` is a plain term, not a query: built into
			`name contains '<term>' and trashed=false`; an apostrophe
			is escaped automatically. An empty term is refused.

			--full-text also matches document body text, not just
			names (off by default). --include-trashed keeps deleted
			files in results (excluded by default). --raw-query
			forwards the argument verbatim as a complete Drive query
			instead; refused together with --full-text/
			--include-trashed. --limit defaults to 50, must be a
			positive whole number.

			Emits one TSV row per file: id, name, mimeType,
			modifiedTime. No matches: no rows, exit 0. Could not
			search: non-zero, says so -- never the same as empty.

		--member-comms-google-sheet-info [--team-member <team-member>] <sheet-id>
			`<team-member>` is the member this read acts as, and it is
			required: a spreadsheet is readable only by identities it is
			shared with, read strictly from that member's own scope with no
			fallback.

			Tab names and grid dimensions — what a caller needs before it can
			build a range for `--member-comms-google-sheet-read`. Prints
			`SPREADSHEET_TITLE=<title>` first, then a TSV table of tabs with
			its own header row: `TAB_TITLE`, `TAB_ID`, `TAB_INDEX`, `ROWS`,
			`COLUMNS`.

		--member-comms-google-sheet-read [--team-member <team-member>] <sheet-id> <a1-range> [--unformatted]
			`<team-member>` is the member this read acts as -- a
			spreadsheet is readable only by identities it's shared
			with, no fallback.

			Cell values for one A1 range as TSV, not the API's JSON
			`values` arrays.

			- **Rows are padded to the requested range's width** --
			  Sheets omits trailing empty cells, so a positional
			  consumer (`awk -F'\t' '{print $4}'`) would silently
			  read the wrong column otherwise. A range with no fixed
			  width (a bare tab name) uses the widest row returned.
			- **Tab, newline, CR and backslash in a cell are escaped**
			  as `\t`/`\n`/`\r`/`\\`, reversible (undo `\\` last).

			Values render as `FORMATTED_VALUE` by default (what a
			human sees); --unformatted returns the raw value (a date
			becomes its serial number).

			An empty range: no rows, exit 0. A range that couldn't be
			read: non-zero, values UNKNOWN -- never the same as empty.
			A range outside the sheet's grid limits is an error, not
			an empty result.

		--member-comms-google-sheet-write [--team-member <team-member>] <sheet-id> <a1-range> [--append] [--user-entered] (--from-stdin|--from-file <path>)
			`<team-member>` is the member this write acts as, first --
			credentials are strictly that member's own, no fallback.

			Writes TSV into one A1 range; **the input format is
			exactly what --member-comms-google-sheet-read emits**, so
			a range round-trips byte-exact (tabs/newlines/backslashes
			as `\t`/`\n`/`\r`/`\\`) through a shell pipeline.

			Content is --from-stdin or --from-file, never trailing
			args (a range is tabular, a shell word isn't); exactly one
			source, both given is an error. --append adds rows after
			existing data instead of overwriting.

			**Values are stored RAW by default, a safety decision** --
			under --user-entered Google parses each value as typed,
			so a cell starting with `=` becomes a live formula; use
			--user-entered only when a formula or locale-parsed date
			is intended.

			On failure, whether anything changed is UNKNOWN -- never
			assume nothing.

		--member-comms-google-sheet-clear [--team-member <team-member>] <sheet-id> <a1-range>
			`<team-member>` is the member this write acts as, and it comes
			first, read strictly from that member's own scope with no
			fallback.

			Clears the values in one A1 range — its own operation, not a
			flag on `--member-comms-google-sheet-write`, since it destroys
			data and takes no content.

			The range is required and is never defaulted: there is no
			whole-sheet shorthand.

		--member-comms-google-doc-read [--team-member <team-member>] <doc-id>
			`<team-member>` is the member this read acts as, and it is
			required: a document is readable only by identities it is shared
			with, read strictly from that member's own scope with no
			fallback.

			Prints the document's plain text. **Paragraph text runs only** —
			tables, embedded objects and footnotes are not rendered.

		--member-comms-google-doc-write [--team-member <team-member>] <doc-id> (<text...>|--from-stdin|--from-file <path>)
			`<team-member>` is the member this write acts as, and it comes
			first, ahead of the document: the credentials are that member's
			own, strictly, with no fallback.

			**Appends** text to the end of the document. Append-only --
			there is no operation to replace the whole body.

			Exactly one content source: trailing text, `--from-stdin`, or
			`--from-file`. Giving more than one is an error, and giving none
			refuses rather than appending nothing and reporting success.

			On failure, whether anything was written is UNKNOWN and must not
			be assumed to be nothing.

		--member-comms-google-comment-read [--team-member <team-member>] <file-id>
			`<team-member>` is the member this read acts as, and it is
			required: comments are visible only to identities the file is
			shared with, read strictly from that member's own scope with no
			fallback.

			Comments on one Drive file — a Doc and a Sheet alike, since
			comments are a Drive resource rather than a per-type one. Emits
			TSV with its own header row: `COMMENT_ID`, `AUTHOR`, `CREATED`,
			`RESOLVED`, `CONTENT`.

		--member-comms-google-comment-post [--team-member <team-member>] <file-id> (<text...>|--from-stdin|--from-file <path>)
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

		--member-comms-confluence-space-list [--team-member <team-member>] [--cursor <value>]
			`<team-member>` is required; the listing is exactly what that
			identity can see. Any other argument is refused with 1.

			Lists the Confluence spaces visible to that identity. TSV rows:
			`SPACE_ID`, `KEY`, `NAME`, `TYPE`, `STATUS`.

			`--cursor <value>` continues a prior page -- pass back the
			cursor printed on that page's own stderr, verbatim. stderr
			also reports `more: yes` with the next `--cursor`, or
			`more: no` on a confirmed-complete last page.

			As a `client-*` member, this family is our own
			organisation's side, where such a member holds no Confluence
			settings: each operation says so in one line, with
			status 6, and names the --client-comms-confluence-* operation
			of the same name, which reaches the other organisation.

		--member-comms-confluence-page-read [--team-member <team-member>] <page-id> [--format storage|atlas_doc_format] [--version <n>]
			`<team-member>` is required; a page is readable only by
			identities it is shared with. Any other argument is refused
			with 1.

			The body goes to stdout, title/version/space id to stderr, so
			`page-read > file` yields the body alone. The stderr line's
			`version=` field is always the version actually returned,
			whether `--version` was passed or not.

			`--format storage` (default) returns Confluence's storage
			XHTML; `--format atlas_doc_format` returns the Atlassian
			Document Format JSON instead. Any other value is refused with
			1.

			`--version <n>` reads that one historical version instead of
			the current one. Read-only: nothing is written and no
			version-conflict is possible, unlike page-update's `--version`.
			`<n>` must be a whole number, refused with 1 otherwise.

			A 404 does NOT establish the page is absent: Confluence
			returns 404 both for missing content and for content this
			account cannot see.

		--magic-comms-confluence-space-list [--team-member <team-member>] [--cursor <value>]
			Runs only as `magic-coordinator` -- any other name is
			refused, naming `--client-comms-confluence-space-list` as
			the client-facing equivalent. `<team-member>` names the
			acting identity; any other argument is refused with 1.
			Output, paging and completeness reporting are as
			`--member-comms-confluence-space-list` describes.

		--magic-comms-confluence-page-read [--team-member <team-member>] <page-id> [--format storage|atlas_doc_format]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. Everything else is as
			`--member-comms-confluence-page-read` describes.

		--magic-comms-confluence-page-search [--team-member <team-member>] <cql> [--limit <n>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. The entry point for the page and comment operations,
			since they need a page id and this produces one. <cql> is
			passed through as given (e.g. `text ~ "term"`), same as
			Jira's JQL. TSV rows: `CONTENT_ID`, `TYPE`,
			`TITLE`, `LAST_MODIFIED`, `URL`. `--limit` defaults to 25.

			This endpoint reports no completeness signal: stderr always
			states `more: unknown`, never a confirmed-complete page.

		--magic-comms-confluence-comment-read [--team-member <team-member>] <page-id>
			Runs only as `magic-coordinator`; any other name is refused
			with 1. The page's top-level footer comments only -- replies
			are not read. TSV rows: `COMMENT_ID`, `VERSION_AUTHOR_ID`,
			`CREATED`, `BODY`. No completeness signal: stderr always
			states `more: unknown`.

		--magic-comms-confluence-page-create [--team-member <team-member>] (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-id <id>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. The page is created under that identity, in a space
			it can see.

			Exactly one of `--space <key>` or `--space-id <numeric id>`
			is required; `--space <key>` resolves the numeric id first
			and refuses on zero or more than one match. `--title` is
			required. The body is `--body-storage`/`-from-stdin`/
			`-from-file <path>`, Confluence's storage XHTML. `--parent-id`
			is optional.

			No version gate: there is nothing yet to conflict with. The
			created page's response (its new id included) goes to
			stdout.

		--magic-comms-confluence-page-update [--team-member <team-member>] <page-id> --version <n> --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]
			Runs only as `magic-coordinator`; any other name is
			refused with 1. A page is editable only by identities it
			is shared with.

			`<n>` is the version already read, from page-read's
			stderr diagnostic; this operation submits `<n>+1`, so a
			page changed since that read is refused, not overwritten.

			**FULL-RESOURCE REPLACE, not a patch.** --title and
			--status are required every call and overwritten with
			whatever is passed -- a body-only edit must still
			resubmit the unchanged title/status, or they're lost.
			--space-id is accepted but not required.

			**HTTP 409 means the submitted version is stale** -- exit
			5, never a generic UNKNOWN. Re-read the page for the
			current version/title/body before deciding whether to
			reapply; never resubmit version+1 unchanged.

		--magic-comms-confluence-comment-add [--team-member <team-member>] <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. The comment is posted under that identity.

			Body is always Confluence's storage format -- no ADF path
			here. `--parent-comment-id` makes it a threaded reply; a
			parent on another page refuses the reply with 1. No version
			gate.

		--magic-comms-confluence-page-delete [--team-member <team-member>] <page-id>
			Runs only as `magic-coordinator`; any other name, or a
			missing <team-member>/<page-id>, is refused with 1,
			naming the missing parameter. Deletes under that
			identity, only where it may. <page-id> must be numeric.

			Never purges a page -- a deleted page reads back as
			status 8 (a 404 under the default view); nothing here
			restores a page.

			Returns 0 when deleted, nothing on stdout. **3**: UNKNOWN
			-- the delete may still have taken effect; read the page
			before acting again, never repeat blindly. **9**:
			refused -- not deleted, retrying won't help. Every other
			status also means not deleted. A 404 (status 8) does NOT
			establish absence -- it also covers a page this account
			may not delete.

			A failure prints one stderr line: the mark, this
			operation's name, the status, and Confluence's body
			verbatim.

		--client-comms-confluence-space-list [--team-member <team-member>] [--cursor <value>]
			Runs only as a `client-*` member, under that member's own
			credential, against that external organisation's own
			Confluence; any other name is refused. Output, paging and
			completeness reporting are as
			`--member-comms-confluence-space-list` describes.

			The whole --client-comms-confluence-* family is called by
			that member's own session; any other session is refused.

		--client-comms-confluence-page-read [--team-member <team-member>] <page-id> [--format storage|atlas_doc_format] [--version <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else, `--version` included, is as
			`--member-comms-confluence-page-read` describes.

		--client-comms-confluence-page-search [--team-member <team-member>] <cql> [--limit <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--magic-comms-confluence-page-search` describes.

		--client-comms-confluence-comment-read [--team-member <team-member>] <page-id>
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Top-level
			footer comments only, no replies -- as
			`--magic-comms-confluence-comment-read` describes.

		--client-comms-confluence-page-create [--team-member <team-member>] (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-id <id>]
			Runs only as a `client-*` member, writing to that external
			organisation's own Confluence under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--magic-comms-confluence-page-create` describes.

		--client-comms-confluence-page-update [--team-member <team-member>] <page-id> --version <n> --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-confluence-page-update` describes.

			**Before this write runs, the current page is read and saved
			byte-for-byte to the team's audit store.** A save that fails
			refuses the write, naming the snapshot as the reason. A write
			that runs prints the saved snapshot's id; a snapshot never
			carries a credential or secret.

			**The approval ask for this write shows the full resulting
			page, or a diff against the current one.** The tooling does
			not compose that ask -- the acting `client-*` member is
			responsible for showing it.

		--client-comms-confluence-comment-add [--team-member <team-member>] <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-confluence-comment-add` describes.

		--client-comms-confluence-page-delete [--team-member <team-member>] <page-id>
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-confluence-page-delete` describes.

			Same snapshot-before-write and approval-diff rule as
			`--client-comms-confluence-page-update`.

		--member-comms-jira-issue-read [--team-member <team-member>] <issue-key> [--format adf|rendered]
			`<team-member>` required: an issue is readable only by
			identities its project is shared with. Any other argument is
			refused with 1.

			Description to stdout, metadata (type, status, resolution,
			assignee, reporter, priority, created, updated, labels,
			summary) to stderr.

			`--format adf` (default) is the Atlassian Document Format
			JSON Jira accepts back on a write, so read-edit-write stays
			possible. `--format rendered` returns Jira's HTML instead and
			cannot be written back. Any other value is refused with 1.

			A null description reads back as empty stdout, status 0 --
			different from a failed read, which is non-zero with content
			reported UNKNOWN. A 404 does NOT establish the issue is
			absent: it also covers content this account cannot see.

		--member-comms-jira-board-list [--team-member <team-member>] [--start-at <n>]
			`<team-member>` required: boards returned are only what that
			member's Jira credential can see. Any other argument is
			refused with 1.

			Lists Agile boards on that member's Jira site; the response
			body goes to stdout as returned, diagnostics to stderr.

			`--start-at <n>` continues a prior page: pass the sum of that
			page's own `startAt` and `maxResults`. Completeness on
			stderr: `more: no` (last page, complete), `more: yes` (more
			remain), `more: unknown` (no signal in the response) -- only
			`more: no` means complete.

			**Exit statuses, used by this whole Jira family unless an
			entry says otherwise.** 0 the site answered. Faults: 1
			refused before any call, 3 answer UNKNOWN, 4 credential
			rejected. Designed refusals: 6 no Jira credential, 7 account
			refused, 8 not found or not visible (also covers content this
			account cannot see), 9 site answered and refused (no retry
			helps) -- 9 also covers every other 4xx including 410 (an
			Atlassian endpoint retired; fix needed in this package, not
			the request). An empty answer at 0 is real; a failed call is
			never empty.

			As a `client-*` member, this family is our own
			organisation's side, where such a member holds no Jira
			settings: each operation says so in one line, with
			status 6, and names the --client-comms-jira-* operation
			of the same name, which reaches the other organisation.

		--member-comms-jira-board-read [--team-member <team-member>] <board-id>
			`<team-member>` required, same scope rule as board-list.
			`<board-id>` must be a whole number, refused before the call
			otherwise. Any other argument is refused with 1.

			Writes the board to stdout as returned -- one object, so no
			completeness line. Exit statuses as `--member-comms-jira-board-list`
			lists them; an 8 here never means "no such board" -- Jira's
			404 covers both non-existence and no-visibility.

		--member-comms-jira-board-issue-search [--team-member <team-member>] <board-id> [--start-at <n>]
			`<team-member>` required, same scope rule as board-list.
			`<board-id>` must be a whole number. Any other argument is
			refused with 1.

			Returns the issues the named board's own filter currently
			carries -- not an arbitrary query; use
			`--magic-comms-jira-issue-search`/`--client-comms-jira-issue-search`
			(JQL) for that. Completeness on stderr as board-list
			describes, from the site's own total. Exit statuses as
			`--member-comms-jira-board-list` lists them.

		--member-comms-jira-sprint-list [--team-member <team-member>] <board-id> [--start-at <n>]
			`<team-member>` required, same scope rule as board-list.
			`<board-id>`, not a sprint id -- lists that board's sprints;
			must be a whole number. Use the returned sprint ids with
			`--member-comms-jira-sprint-issue-search`. Any other argument
			is refused with 1.

			`--start-at` and completeness reporting as board-list
			describes. Exit statuses as `--member-comms-jira-board-list`
			lists them; a board with no sprints is an empty listing at 0,
			not a failure -- a kanban board, or one with sprints disabled,
			always answers this way. When that board's own features
			can't be read, this returns the layer's status for that read;
			when read and the sprints feature is anything but
			ENABLED/DISABLED/absent, it returns 3.

		--member-comms-jira-sprint-issue-search [--team-member <team-member>] <sprint-id> [--start-at <n>]
			`<team-member>` required, same scope rule as board-list.
			`<sprint-id>`, NOT a board id -- separate number spaces; the
			wrong one reaches a different sprint or none, not a visible
			failure. Must be a whole number. Obtain it from
			`--member-comms-jira-sprint-list`. Any other argument is
			refused with 1.

			Completeness on stderr as board-list describes. Exit statuses
			as `--member-comms-jira-board-list` lists them.

		--magic-comms-jira-board-list [--team-member <team-member>] [--start-at <n>]
			Runs only as `magic-coordinator` -- any other name is refused,
			naming `--client-comms-jira-board-list` as the client-facing
			equivalent. Everything else is as
			`--member-comms-jira-board-list` describes.

		--magic-comms-jira-board-read [--team-member <team-member>] <board-id>
			Runs only as `magic-coordinator`; any other name is refused
			with 1. Everything else is as `--member-comms-jira-board-read`
			describes.

		--magic-comms-jira-board-issue-search [--team-member <team-member>] <board-id> [--start-at <n>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. Everything else is as
			`--member-comms-jira-board-issue-search` describes.

		--magic-comms-jira-sprint-list [--team-member <team-member>] <board-id> [--start-at <n>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. Everything else is as `--member-comms-jira-sprint-list`
			describes.

		--magic-comms-jira-sprint-issue-search [--team-member <team-member>] <sprint-id> [--start-at <n>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. Everything else is as
			`--member-comms-jira-sprint-issue-search` describes.

		--magic-comms-jira-issue-search [--team-member <team-member>] <jql> [--limit <n>]
			Runs only as `magic-coordinator`; any other name is
			refused with 1. The entry point for the issue operations
			-- they need an issue key, this produces one.

			<jql> is passed through as given; Jira refuses an
			unrestricted query, so it must name at least one
			restriction, e.g. `project = DATA ORDER BY updated DESC`.

			**An empty result is not evidence that nothing matches.**
			Jira answers a nonexistent-project or invalid-JQL query
			with success and an empty page, not an error -- a
			zero-row result only means this exact query matched
			nothing. Stated on stderr whenever rows are zero.

			TSV rows: ISSUE_KEY, TYPE, STATUS, ASSIGNEE, UPDATED,
			SUMMARY. --limit defaults to 25. Completeness on stderr
			as board-list describes (more: no/yes/unknown); this
			endpoint reports no total, so after more: yes raise
			--limit or narrow the query. Exit statuses as
			--member-comms-jira-board-list lists them.

		--magic-comms-jira-issue-read [--team-member <team-member>] <issue-key> [--format adf|rendered]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. Everything else is as `--member-comms-jira-issue-read`
			describes.

		--magic-comms-jira-comment-read [--team-member <team-member>] <issue-key> [--format adf|rendered] [--start-at <n>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1.

			Comments on one issue, TSV rows: `COMMENT_ID`, `AUTHOR_ID`,
			`AUTHOR_NAME`, `CREATED`, `UPDATED`, `BODY`. `--format` means
			the same as on `--member-comms-jira-issue-read`, applied per
			comment body: `adf` (default) or `rendered`. Any other value
			is refused with 1.

			Completeness on stderr, from the issue's comment total:
			`more: no`/`more: yes` (naming the next `--start-at`)/
			`more: unknown`. Exit statuses as
			`--member-comms-jira-board-list` lists them.

		--magic-comms-jira-issue-create [--team-member <team-member>] --project <key> --issuetype <name> --summary <text> [--description-adf <json>|--description-adf-from-stdin|--description-adf-from-file <path>] [--fields-json <json>]
			Runs only as `magic-coordinator`; any other name is
			refused with 1. Created under that identity, only in a
			project it can see.

			--project, --issuetype, --summary always required;
			anything else a project's create screen demands (e.g. a
			subtask's fields.parent.key) goes through --fields-json,
			merged into the request's fields. No createmeta
			validation call is made -- for an unfamiliar project/
			issuetype, read
			/rest/api/3/issue/createmeta/{project}/issuetypes/
			{issueTypeId} yourself first.

			--description-adf/-from-stdin/-from-file <path> is the
			same ADF JSON --member-comms-jira-issue-read --format adf
			emits for fields.description, passed straight through.

			**Never retry a create whose outcome came back UNKNOWN**
			(a timeout, a 5xx) -- Jira's create has no idempotency
			key, a blind retry can leave two issues behind. HTTP 400
			(a real field-validation rejection, Atlassian's `errors`
			object in the diagnostic) and a transport UNKNOWN share
			one exit code -- read the diagnostic to tell them apart.

			The created issue's response (its new key included) goes
			to stdout.

		--magic-comms-jira-issue-update [--team-member <team-member>] <issue-key> [--fields-json <json>] [--update-json <json>] [--notify-users]
			Runs only as `magic-coordinator`; any other name is
			refused with 1. Editable only by identities its project
			is shared with.

			At least one of two write shapes required. --fields-json
			<json> is the WHOLE fields object, plain set-semantics --
			an array field like labels is a full replace, not an
			append (read the current array first to add one).
			--update-json <json> is Jira's own
			{"field":[{"add"/"remove"/"set":...}]} shape for precise
			add/remove. Both may be given together.

			fields.status/update.status are refused locally, before
			any call -- move status through
			--magic-comms-jira-issue-transition instead.

			notifyUsers defaults false here (opposite of Jira's own
			API default), to avoid spamming watchers on an automated
			edit; --notify-users opts back in.

			HTTP 400 means an invalid or read-only field for that
			project's screen; HTTP 404 means the issue is absent or
			invisible.

		--magic-comms-jira-issue-transition [--team-member <team-member>] <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>|--comment-adf-from-stdin|--comment-adf-from-file <path>]
			Runs only as `magic-coordinator`; any other name is
			refused with 1. Editable only by identities its project
			is shared with.

			**The transition id is never caller-supplied** -- this
			always runs its own GET .../transitions immediately
			before the POST, every call.

			--to-status <name> is matched exactly against each
			transition CURRENTLY AVAILABLE from the issue's own
			status, by destination status name (to.name) -- never by
			its action label (a button "Start Progress" can land on
			status "In Progress"). Zero or more than one match is a
			loud, local failure before any POST, listing the
			transitions actually available.

			--fields-json passes into the transition's own fields --
			some workflows require one on a specific screen.
			--comment-adf/-from-stdin/-from-file <path> adds a
			comment in the same call.

			HTTP 400 on the POST itself usually means the issue moved
			again between lookup and write, or the target screen
			required a field not supplied -- re-run to re-resolve.

		--magic-comms-jira-comment-add [--team-member <team-member>] <issue-key> (--body-adf <json>|--body-adf-from-stdin|--body-adf-from-file <path>)
			Runs only as `magic-coordinator`; any other name is refused
			with 1. The comment is posted under that identity.

			Same ADF body shape the read side emits (`{"body":
			<ADF-doc>}`), via `--body-adf`/`-from-stdin`/`-from-file
			<path>`. **No `visibility` (role/group restriction) here** --
			every comment posted is visible to everyone the issue is
			already shared with. No read-before-write.

		--magic-comms-jira-issue-delete [--team-member <team-member>] <issue-key>
			Runs only as `magic-coordinator`; any other name, or a
			missing `<team-member>`/`<issue-key>`, is refused with 1,
			naming the missing parameter. Deleted under that
			identity, only where its project allows it.

			**An issue with subtasks is refused -- subtasks are
			never deleted.** Jira answers HTTP 400; nothing here
			restores a deleted issue.

			Returns 0 when deleted, nothing on stdout. **3**: UNKNOWN
			-- the delete may still have taken effect; read the issue
			before acting again, never repeat blindly. **9**:
			refused -- not deleted, retry won't help (the subtask
			refusal arrives this way, HTTP 400 in the line). Every
			other status also means not deleted. A 404 (status 8)
			does NOT establish absence.

			A failure prints one stderr line: the mark, this
			operation's name, the status, and Jira's body verbatim.

		--client-comms-jira-board-list [--team-member <team-member>] [--start-at <n>]
			Runs only as a `client-*` member, under that member's own
			credential, against that external organisation's own Jira;
			any other name is refused with 1. Output, paging and exit
			statuses are as `--member-comms-jira-board-list` describes.

			The whole --client-comms-jira-* family is called by that
			member's own session; any other session is refused.

		--client-comms-jira-board-read [--team-member <team-member>] <board-id>
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--member-comms-jira-board-read` describes.

		--client-comms-jira-board-issue-search [--team-member <team-member>] <board-id> [--start-at <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--member-comms-jira-board-issue-search`
			describes.

		--client-comms-jira-sprint-list [--team-member <team-member>] <board-id> [--start-at <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--member-comms-jira-sprint-list` describes.

		--client-comms-jira-sprint-issue-search [--team-member <team-member>] <sprint-id> [--start-at <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--member-comms-jira-sprint-issue-search`
			describes.

		--client-comms-jira-issue-search [--team-member <team-member>] <jql> [--limit <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-issue-search` describes.

		--client-comms-jira-issue-read [--team-member <team-member>] <issue-key> [--format adf|rendered]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--member-comms-jira-issue-read` describes.

		--client-comms-jira-comment-read [--team-member <team-member>] <issue-key> [--format adf|rendered] [--start-at <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-comment-read` describes.

		--client-comms-jira-issue-create [--team-member <team-member>] --project <key> --issuetype <name> --summary <text> [--description-adf <json>|--description-adf-from-stdin|--description-adf-from-file <path>] [--fields-json <json>]
			Runs only as a `client-*` member, writing to that external
			organisation's own Jira under that member's own credential;
			any other name is refused with 1. Everything else is as
			`--magic-comms-jira-issue-create` describes.

		--client-comms-jira-issue-update [--team-member <team-member>] <issue-key> [--fields-json <json>] [--update-json <json>] [--notify-users]
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-issue-update` describes, except
			a status change goes through
			`--client-comms-jira-issue-transition`.

			**Before this write runs, the current issue is read and saved
			byte-for-byte to the team's audit store.** A save that fails
			refuses the write, naming the snapshot as the reason. A write
			that runs prints the saved snapshot's id; a snapshot never
			carries a credential or secret.

			**The approval ask for this write shows the full resulting
			issue, or a diff against the current one.** The tooling does
			not compose that ask -- the acting `client-*` member is
			responsible for showing it.

		--client-comms-jira-issue-transition [--team-member <team-member>] <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>|--comment-adf-from-stdin|--comment-adf-from-file <path>]
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-issue-transition` describes.

			Same snapshot-before-write and approval-diff rule as
			`--client-comms-jira-issue-update` -- `--fields-json` here can
			overwrite a field too, the same loss `--client-comms-jira-issue-update`
			guards against.

		--client-comms-jira-comment-add [--team-member <team-member>] <issue-key> (--body-adf <json>|--body-adf-from-stdin|--body-adf-from-file <path>)
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-comment-add` describes.

		--client-comms-jira-issue-delete [--team-member <team-member>] <issue-key>
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-issue-delete` describes.

			Same snapshot-before-write and approval-diff rule as
			`--client-comms-jira-issue-update`.

		--magic-comms-trello-post-comment [--team-member <team-member>] <card-id> (text...|--from-stdin|--from-file <path>)
			`<team-member>` required: a comment is authored by one
			identity, and the acting member decides which Trello
			credentials sign it.

			Direct write, no console session needed: posts one comment
			onto one card (`/1/cards/{id}/actions/comments`) using that
			member's Trello credentials. Exactly one content source:
			trailing text, --from-stdin, or --from-file. Returns the
			Trello API response on success.

			Refused before any call: a <team-member> that is not a real
			member skill directory (`routine-*` exempt); a <card-id> not
			letters/digits only (24-char hex id, or the short link from
			the card URL); empty comment text; any argument after
			--from-stdin/--from-file; a missing --from-file; TRELLO_KEY or
			TRELLO_TOKEN not set for that member. A post Trello rejects
			returns non-zero and nothing is posted.

			Our own organisation's side, whoever <team-member> is. A
			`client-*` member holds no Trello settings there: for it
			the operation says so in one line, posts nothing, and
			names --magic-client-operation-run with
			--client-comms-trello-post-comment, which posts onto the
			other organisation's card.

		--owner-credential-store-self-test
			Self-check: confirms the credential-store permission-hardening
			path holds even under a permissive shell umask. Takes no
			arguments. Leaves no residue in the real credentials file
			whether it passes or fails. Also asserts the mode of each
			file this package seeds or publishes: `~/.claude.json` at
			0600, `.local/agents/mcp.servers.json`, `.vscode/mcp.json`
			and `.mcp.json` at 0644. A file that is absent is stated, not
			failed.

		--owner-credential-store-verify
			Checks the credential store's file/directory permissions are
			correctly hardened. Prints one `OK`/`BAD` line per path to
			stdout, returns non-zero if anything is out of hardening.
			Read-only, modifies nothing.

		--owner-credential-store-harden
			Repairs the credential store's directory and file
			permissions, then runs verify and returns its result. Takes
			no arguments. Call it when verify reports a path out of
			hardening. Writes, unlike the other two.

		--member-git-repo-history [--since <YYYY-MM-DD>] [--until <YYYY-MM-DD>] [--limit <n>] <path>...
			Read-only commit history of one to 20 paths, through `git log`
			only -- members run no git themselves. A path is relative to
			the workspace root or absolute, and must resolve (symlinks
			followed) inside the workspace or a readable access root; a
			path that is itself a symbolic link, holds a dot-dot segment
			or lies outside is rejected and skipped, not silently dropped.
			The nearest existing directory is resolved, so the history of
			a deleted file can be asked for. `--since` and `--until` are
			dates (`--until` includes its whole day); `--limit` is 1 to
			1000, default 50. Per path prints a `## <resolved path>`
			header, then one line per commit, newest first: date and time
			with zone, author, short hash, subject (cut at 200 characters),
			tab-separated. When more commits exist than the limit, a final
			`# ...: output limited to N commits` line says so on stdout.
			Exit 1 when any path was skipped or git failed; the other
			paths still print. Writes nothing and takes no git lock.

		--librarian-list-team-files [<path>...]
			Read-only path listing of skill-folder files. Faster than
			the `-dates` sibling -- prefer it when mtimes aren't needed.
			Zero or more scope arguments: a bare path relative to the
			skill-root, or an absolute path resolving inside it (outside
			is rejected and skipped, not silently ignored); a file scopes
			to itself, a directory recursively. No arguments means the
			whole skill-root. Only `*.md` files are listed -- a
			non-`*.md` scope argument passes the existence check but
			contributes nothing, so an empty result for it is normal, not
			an error. Prints one skill-root-relative path per matched
			file, sorted alphabetically.

		--librarian-list-team-files-dates [<path>...]
			Same listing plus each file's mtime. Slower -- use only when
			mtimes are needed (staleness sweeps, mtime-before-editing
			checks). Same scope-argument grammar, whitelist and silent-
			skip corner as `--librarian-list-team-files`. Prints one line
			per matched file: mtime (`YYYY-MM-DD HH:MM:SS`), two spaces,
			then the path, sorted newest-first.

		--librarian-inbox-item-trash [--team-member <team-member>] <item-filename> --from-inbox:<member> [--exclude-incoming]
			Discards one of `<member>`'s inbox items -- live or already
			processed -- by its name alone, with no state change first.
			An inbox is split (`incoming/` and `processed/`, the item's processed stamp, `processed-at`, deciding its folder); readers never see the folders.
			It is searched in both of its folders, and
			`--exclude-incoming` trashes a processed item only and
			refuses an incoming one. `--from-
			inbox:` is colon-style only. `<member>` must be a bare name;
			`<item-filename>` a bare name ending `.md`. No type-prefix
			restriction -- a misfiled board-type document (`task-*`,
			`proposal-*`, ...) sitting in an inbox is exactly what this
			clears. Not found in either directory, the error names both.

			**No inverse, whatever team-data's git state.** Git-tracked:
			deleted outright and committed, no copy left. Not tracked:
			moved to `trash/`, recoverable only by hand -- this op still
			won't restore it. Treat every call as final.

		--librarian-inbox-to-processed [--team-member <team-member>] <item-filename> [--include-processed] [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Marks one item in `<team-member>`'s own inbox processed:
			stamps `processed-at` into its frontmatter (creating the
			block when the item has none) and commits it. An inbox is split (`incoming/` and `processed/`, the item's processed stamp, `processed-at`, deciding its folder); readers never see the folders.
			The item is found in `incoming/`, in `processed/` too with
			`--include-processed`, and moves to `processed/`. Active inbox
			scans skip it from then on, and the GC deletes it once the
			stamp is older than the retention (`warning-*`/
			`reflection-*` one day, everything else seven).
			`<item-filename>` must be a bare name ending `.md`. No `--from-inbox:<member>` here -- the source is
			always the acting member's own inbox; `--from-state:`/
			`--from-inbox:` are both rejected if given. `--header:*`
			and the three body-input modes behave as on the
			`--magic-board-to-*` family.

			A caller's `--header:<op>:processed-at` wins over the
			stamp (`:remove:` for none). An item already marked keeps
			its original `processed-at`: a plain re-mark is a no-op
			success, and an edit applies without moving the stamp.
			An item that is processed already, in `processed/`: a
			plain re-mark succeeds as a no-op; an edit needs
			`--include-processed`.

		--member-inbox-to-processed [--team-member <team-member>] <item-filename> [--include-processed] [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Marks one of `<team-member>`'s OWN inbox items handled:
			`processed-at` stamped, and the item moved to `processed/`,
			exactly as
			`--librarian-inbox-to-processed` (a given processed-at wins,
			a re-mark is a no-op, the original stamp is kept). Any
			member may call it for its own inbox:
			`<team-member>` is both the actor and the inbox, must be a
			real member skill directory, and a spawned session acting
			as another member is refused. `<item-filename>` is a bare
			name ending `.md`. `--header:*` and the three body-input
			modes behave as on the `--magic-board-to-*` family.

		--member-inbox-note-upsert [--team-member <member>] <item-filename> [--from-member <member>] [--include-processed] [--standing yes|no] [--from-file <path>|--edit-patch-from-stdin]
			Writes (creates or overwrites) a note into `<member>`'s own
			inbox. An inbox is split (`incoming/` and `processed/`, the item's processed stamp, `processed-at`, deciding its folder); readers never see the folders. The item lands in
			the folder its processed stamp picks, `incoming/` or
			`processed/`, and an item already there is updated where it
			lies, a processed one only with `--include-processed` (without
			it, a processed item of that name is refused, never shadowed);
			one whose stamp changes moves to its folder. Own inbox only: a spawned session naming another
			member than itself is refused; a call from no spawned
			session is taken at the name it gives.
			`<member>` must exist as a real skill directory;
			`<item-filename>` a bare filename. The inbox is created
			lazily if missing. Content via stdin by default, or
			`--from-file <path>` -- either overwrites the target
			outright. `--edit-patch-from-stdin` instead takes a JSON
			array of `{"old":<text>,"new":<text>,"replace_all":<bool,
			default false>}` patches, applied in order as exact literal
			substring match-and-replace -- a patch whose `old` isn't
			found, or matches more than once without `replace_all`,
			fails loud before anything is written.

			A NEW item (no file of that name in the inbox yet):
			- Name: written exactly as given. A name off the naming
			  Rule's `<type>-<YYYYMMDD'T'HHmm'Z'>-<matter>.md` shape (or
			  its `HHmmSS'Z'` seconds variant) gets one warning quoting
			  the Rule, and so does a type that is not an inbox type
			  (note-*, inquiry-*, reflection-*); neither is refused.
			- Frontmatter: `type` (the name's prefix), `from` (the
			  writing member: `--from-member <member>`, else the spawned
			  session's own member, else left out), `date` (now, in the
			  team's `date-time` format) and `owner` (`<member>`, whose
			  inbox it is) are added where the content does not already
			  carry them. A given value is never overwritten; content
			  with no frontmatter gets one.
			An update of an existing item keeps its name and its
			headers as they are.

			`--standing yes|no` (a note only, `note-*`) sets the header
			`standing:` of the note as it is written, over a value it has:
			`yes` makes it a standing note, which is in force while it is
			unprocessed (`AgentDispatcherTools.fn.sh --standing-directives`
			shows it, and a spawn is given it in its brief), `no` an
			ordinary one. The rest of the content is as given; to change
			the header alone give `--edit-patch-from-stdin` with `[]`.

		--member-upsert-member-inquiry [--team-member <member>] <item-filename> [--from-member <member>] [--include-processed] [--from-file <path>]
			Passes an inquiry into a member's own inbox -- the standard
			hand-off mechanism. `<member>` must exist as a real skill
			directory; `<item-filename>` a bare filename. Inbox created
			lazily if missing. Content via stdin by default, or
			`--from-file <path>`. A new item's required
			`type`/`from`/`date`/`owner` headers are completed as in
			`--member-inbox-note-upsert`, and so is the folder it lands in. From a spawned session,
			`--from-member` names only that session's own member, and an
			item already in the inbox is overwritten only when its
			`from:` is the caller; a new item is always written.

		--member-inbox-reflection-upsert [--team-member <member>] <item-filename> [--from-member <member>] [--include-processed] [--from-file <path>|--edit-patch-from-stdin]
			Writes (creates or overwrites) a reflection-type item into a
			member's own inbox, own inbox only as for
			`--member-inbox-note-upsert`. Same arguments, lazy inbox creation,
			stdin/`--from-file` content and `--edit-patch-from-stdin`
			patch behaviour as `--member-inbox-note-upsert` (which
			rejects patch mode; this accepts it). The content follows a
			fixed shape: frontmatter, then a `# Reflection: <title>`
			heading, then `## What happened` and
			`## Why this is worth keeping` sections. `<item-filename>` is
			conventionally expected to contain "reflection-", not
			enforced. The old name `--member-upsert-inbox-reflection`
			still works as an alias.

		--member-append-session-transcript [--team-member <team-member>] [--speaker <speaker-name>] [--timestamp <ISO-UTC-date-time>] (--message <verbatim-text>|--from-stdin|--from-file <path>) [--transcript-name <transcript-file-name>] [--create]
			With no `--transcript-name`: appends one NOTE line, by
			`<speaker-name>` (default `<team-member>`) at `<timestamp>`
			(default now, UTC), to the calling session's own tooling-written
			transcript, never another session's; `--create` starts it when
			the session has none. Refused when no session resolves. A
			session's log (`session-*.log`) is never named with
			`--transcript-name`. The SessionTranscriptAppend tool is the
			same append from a model.
			With `--transcript-name` (`--speaker` and `--timestamp` then
			required): appends one canonical transcript-entry block: `<speaker-name>
			(<timestamp>):` followed by quoted message lines, to the
			team's shared audit tree (not a board state folder). The
			month bucket it lands in comes from the date embedded in
			`<transcript-file-name>` (`transcript-YYYY-MM-DD-*` or
			`transcript-YYYYMMDDTHHmmZ-*`), falling back to the current
			UTC year-month otherwise.
			`<team-member>` must already be a real team member; a
			spawned session naming another member than itself is
			refused, either way.
			Does not rewrite prior content. Missing target transcript is
			an error unless `--create` is passed. Payload from exactly
			one of `--message`, `--from-stdin`, or `--from-file <path>`
			(`--message-from-stdin` is an alias of `--from-stdin`).
			Returns the target path plus added line and byte counts.

		--member-inbox-item-read [--team-member <member>] <item-filename> [--include-processed] [--start-line <N> --end-line <N>]
			Read-only read of one item in `<member>`'s own inbox, by bare
			`<item-filename>`. An inbox is split (`incoming/` and `processed/`, the item's processed stamp, `processed-at`, deciding its folder); readers never see the folders. It is read in
			`incoming/`, and in `processed/` too with
			`--include-processed`: without it a processed item is not
			found.
			`<item-filename>` must carry one of the four type prefixes:
			`note-`/`inquiry-`/`reflection-`/`warning-`. `--start-line`/`--end-line` must be
			given as a complete pair.

		--member-inbox-item-trash [--team-member <member>] <item-filename> [--exclude-incoming]
			Discards one item out of `<member>`'s OWN inbox, by its name
			alone, with no state change first, as
			`--librarian-inbox-item-trash`: a split inbox from either
			folder, `--exclude-incoming` a processed item only. No
			`--from-inbox:<member>` here -- one supplied in any position
			is REFUSED, so a member-scoped call can never become a
			cross-member one (use `--librarian-inbox-item-trash` for
			another member's inbox). A spawned session naming another
			member than itself is refused. No
			type-prefix restriction. An item carrying `archive: true` is
			discarded like any other -- that header only diverts the
			GC's own retention clock.

			**No inverse, whatever team-data's git state** -- same as
			`--librarian-inbox-item-trash`: deleted and committed when
			git-tracked, moved to `trash/` and recoverable only by hand
			otherwise. Treat every call as final.

		--member-audit-item-read [--team-member <team-member>] <document-name> [--start-line <N> --end-line <N>]
			Read-only read of one audit document by logical identity, not
			a filesystem path. Caller gives only `<team-member>` and a
			bare `<document-name>`; path-like names are rejected. Fails
			loud if missing or ambiguous. Only `transcript-*` names are
			permitted. `--start-line`/`--end-line` must be a complete
			pair.

		--member-vault-item-read [--team-member <team-member>] <item-name> [--start-line <N> --end-line <N>]
			Read-only read of one vault item (a verbatim document or
			fact under the team-data store's `vault/`) by bare
			`<item-name>`; path-like names are rejected. Any bare name is
			accepted -- vault document types are open. Fails loud if
			missing. `--start-line`/`--end-line` must be a complete pair.

		--member-board-item-read [--team-member <team-member>] <item-name> [--board-state <state>]... [--start-line <N> --end-line <N>]
			Read-only read of one board item by bare `<item-name>`
			(`<type>-<name>.md`). Repeatable `--board-state` narrows
			lookup folders; omitted, all board states are searched in
			canonical order. `--start-line`/`--end-line` must be a
			complete pair.

		--owner-workspace-upsert <path> [--name <name>] [--kind workspace|directory] [--ceiling read-only|read-write]
			Registers a place no project declares, in this workspace's
			own registry (.local/agents/directories.registry), with a
			pointer in $HOME/.agents/magic-team/directories.registry.
			<path> must be absolute; a trailing slash is dropped.
			--name defaults to the path's basename; --kind defaults to
			workspace, which is always read-write; --ceiling defaults to
			read-write. Registering a place grants nothing. The same row
			again is a no-op; a name a project of this workspace
			declares for another path is refused. So is a name that
			starts with a dot: only the two built-in places have one, and
			a declared place of such a name is skipped with a warning.
			Existence of <path> is not checked (it may live on an
			unmounted volume).
			Places a project declares need no call: a project.inf
			Declares line `magic-team:directory:<name>:<ceiling-read|ceiling-write>:<path>:<host-glob>`
			or `magic-team:workspace:<name>:<path>:<host-glob>` registers
			one on every update, its path absolute, `~/...`, or relative
			to the workspace.

		--owner-workspace-forget <name>
			Removes the place of that name that --owner-workspace-upsert
			registered in this workspace. A name a project declares, this
			workspace's own, or a built-in place's, is refused; an unknown
			name is a harmless no-op.

		--owner-workspace-list
			Prints the two built-in places, then every registered place
			of every workspace, one per line, TAB-separated: name, kind
			(workspace or directory), ceiling (read-only or read-write),
			path, and present, absent (not on this host) or unknown (its
			workspace cannot be read).
			The same name with another path: this workspace's keeps the
			name, each other is written <name>@<workspace>; with none
			here, one warning, and each is written <name>@<workspace>.
			The built-in places are `.skillset-shared`, the machine's
			skillset in HOME (the skills folder the clients read there),
			and `.skillset-.local`, the member set of this workspace
			(.local/agents/members). They are no row of a registry, and a
			registry row with a name that starts with a dot is left out,
			with a warning. Takes no arguments.

		--member-directory-list
			Prints the two built-in places, `.skillset-shared` (the
			machine's skillset in HOME) and `.skillset-.local` (this
			workspace's own member set), then every registered place, one
			per line, TAB-separated: name (or <name>@<workspace>, as
			--owner-workspace-list writes it), kind (workspace or
			directory) and ceiling (read-only or read-write). Never a
			path: ask for one by name with --member-directory-path. Takes
			no arguments.

		--member-directory-path <name>[/<relative>]
			Prints the path of the place <name>, or of <relative> under
			it. A <relative> with a .. segment, or starting with /, is
			refused, and so is a name no place carries. A place absent
			on this host is printed with a warning. A path grants
			nothing: reading or writing there still needs a grant.

		--member-namespace-list [<namespace>]
			Prints this workspace's distro projects by name, one per
			line, TAB-separated: namespace, project. With <namespace>,
			that namespace's only. Names only, to name the namespaces a
			dispatch or a task needs.

		--owner-setup-<domain> [<config-option>...] [--all-workspaces] [--set-as-default] [--check|--apply|--print-apply-command|--wizard]
			Reports, and where supported carries out, setup of one
			macro part of an installation. <domain> is open-ended;
			`claude`, `copilot`, `grok`, `slack`, `storage` and
			`scaleway` exist today. A domain with no defined checks
			says so. `cli-auto` is not one of them: it takes only
			--check and --apply, and selects the first of
			claude-native and copilot-native that is installed and
			works (--help-setup-cli-auto).

			Options and values come first, then at most one
			sub-operation last -- anything after it, or an option
			whose meaning needs a sub-operation that's absent, is an
			error. <config-option> is per domain, listed below.
			--print-apply-command lists a domain's options even if
			not listed below; a domain with none declared is
			refused, not answered empty.

			A value to store -- a config option, or
			--values-from-stdin (KEY=VALUE lines) -- is accepted
			only with --apply, refused otherwise. --workspace-root
			(which workspace this call is about) is accepted by
			every sub-operation.

			No sub-operation: status for the current workspace plus
			the command to finish setup, asking only for what's
			REQUIRED and missing. --check: full per-setting detail.
			--apply: carries setup out, non-interactively.
			--print-apply-command: the full command for every
			option, required and optional, as a stdin-fed form when
			a secret is involved (a secret never sits on a command
			line); changes nothing, exits 0. --wizard: not built
			yet.

			--all-workspaces widens a report to every registered
			workspace; only a domain whose diagnosis spans
			workspaces, never with --apply or --print-apply-command
			(each is single-workspace). --set-as-default points the
			domain's service selection here; without it an apply
			only fills an unset selection. Only with --apply, and
			only a domain that owns a selection.

			Configuration options, `claude`:
			  --workspace-root <path>  workspace to set up.
			      Default $MMDAPP; a non-root path is an error.

			Configuration options, `slack`:
			  SLACK_CHANNEL_MAGIC_TEAM   team channel id. Required.
			  SLACK_CHANNEL_HUMAN_OWNER  human-owner's member id.
			      Required.
			  SLACK_BOT_TOKEN            team bot token. Optional,
			      only with SLACK_WORKSPACE_DOMAIN.
			  SLACK_WORKSPACE_DOMAIN     workspace subdomain.
			      Optional, only with SLACK_BOT_TOKEN.
			  SLACK_CHANNEL_EVENT_TRACK  activity-log channel.
			      Optional: unset goes to the team channel.
			  SLACK_CHANNEL_EVENT_ALERT  alert channel. Optional:
			      unset goes to the team channel.
			  A member's own user token is not a workspace
			  setting -- not asked for here.

			Configuration options, `storage`:
			  TEAM_DATA_DIRECTORY       team data location.
			      Optional: unset is the workspace's own
			      team-data root.
			  TEAM_DATA_GIT_REMOTE      team-data repo to push to.
			      Optional.
			  TEAM_DATA_BRANCH          tracked branch. Optional:
			      unset "main".
			  TEAM_DATA_GIT_USER_NAME   commit author name.
			      Optional: unset uses git's own identity.
			  TEAM_DATA_GIT_USER_EMAIL  commit author email.
			      Optional: unset uses git's own identity.
			  A missing/empty store is cloned from
			  TEAM_DATA_GIT_REMOTE before the first write; a failed
			  clone is retried by the main loop. --apply makes the
			  store a repository, cloned or initialised; content
			  that isn't a clone of a set remote goes to myx.common
			  git/cloneSync, and a repository with another origin,
			  or none, gets the remote as origin and is pushed. A
			  repository with no author identity fails its check,
			  naming both keys.

			Exit status is non-zero on a failed check, usable as a
			readiness gate. A setting is judged by its value where
			used, never by a file merely existing.

			`claude`, `claude-native` and `copilot` share a
			WORKSPACE_HOOK_SCRIPTS row (`Workspace hooks`): fails
			naming each missing or non-executable hook script a
			workspace's `.claude/settings.json` registers; fix:
			--make-workspace-integrations (also drops a retired
			hook entry -- anything left after that isn't this
			package's, restore or remove it yourself).

			`claude`/`claude-native` only, two more rows:
			MCP_REGISTRATION (`MCP servers`) fails when
			`.mcp.json` lacks the myx.common/myx.distro entry,
			`enabledMcpjsonServers` doesn't enable both, or
			`.claude.json` has no myx.common for that workspace.
			CLAUDE_PERMISSIONS (`Claude permissions`) fails when
			`settings.json` lacks a fixed grant. Both fix:
			--make-workspace-integrations. An unparseable settings
			file fails with `fix: repair the JSON`; an
			unparseable/absent `.claude.json` or empty MYXROOT
			leaves MCP_REGISTRATION a warning, undetermined.

		--install-claude-permissions [--workspace <path>]
			Merges this package's mandatory Claude Code permission
			grants into `$HOME/.claude/settings.json`
			(`permissions.allow`/`permissions.deny`) -- additive,
			existing entries this op didn't add are kept.
			`--workspace <path>` (default `$MMDAPP`) selects the
			workspace whose registries name what earlier runs wrote.

			Writes no file grant (`Read`, `Edit`, `Write`): the
			`PreToolUse` hooks decide every call. Drops the ones
			earlier runs wrote -- what they projected from the
			permissions registries, recorded in
			`<workspace>/.local/agents/claude-permissions.projected`
			(with no record, what the registries claim now), every
			board grant and every `Edit`/`Write` grant on an acting
			member's skillset directory -- and nothing else.

			Upserts the fixed grants (`mcp__myx_common`,
			`mcp__myx_distro`, `Agent`, `Task`, `SendMessage`) and
			denies the native Slack MCP server
			(`mcp__claude_ai_Slack`) unconditionally -- route Slack
			through the team's own `--member-comms-slack-*` ops.
			Sets `enabledMcpjsonServers` to `myx.common` and
			`myx.distro`.

			A failure fails loud, file untouched. A no-op run is
			reported as such.

		--install-workspace-restrictions [--workspace <path>]
			Installs Claude Code WORKSPACE-level permission rules
			(deny rules, `PreToolUse` hooks) into the target
			workspace's own `.claude/settings.json` -- distinct from
			`--install-claude-permissions`, which is $HOME-scoped.
			Default target is the current shell directory;
			`--workspace <path>` overrides it.

			Writes no `permissions.allow` file grant: the hooks
			decide every call. Drops the `Read`/`Edit` entries
			earlier installs wrote (on the workspace `source/`, its
			skills root, the reference read roots, the team
			scratchpad), each on an exact match or, for a `source/`
			or `.agents` root, by its shape; a rule the user added
			stays.

			Refuses (exit 1, nothing written) when `<workspace>`
			isn't a genuine workspace root (no `<workspace>/.local`),
			naming a likely correct ancestor root when found.

			Writes `.local/agents/harness.hooks.index` first, from
			the client tool policy, and generates the hook scripts
			and the `settings.json` hook entries from that index, so
			what a native client runs and what the universal harness
			runs never disagree. The harness never reads
			`settings.json`: a hook added there by anyone else
			applies to native clients only.

			Idempotent: merges into existing files, a no-op run
			reported as such. Installs three fixed hook scripts
			(denying native-tool calls the team routes elsewhere;
			denying `Read`, and `Glob`/`Grep` pointed into it, of
			the client's machine-local memory store,
			`~/.claude/projects/*/memory/`; denying `Edit`/`Write`
			into it -- the two memory guards refuse naming
			`MAGIC.md`, reflection, inbox note or inquiry and
			escalation instead, and the universal harness applies
			them too), and one more for a spawned member only:
			`allow-granted-native-tool.sh` allows a native
			`Read`/`Edit`/`Write`/`MultiEdit`/`NotebookEdit`/`Grep`/
			`Glob` call its session permission index grants,
			denies a write in a read-only place, and leaves any
			other call to the client and the `PermissionRequest`
			hook; it sets `"autoMemoryEnabled": false`,
			touching no other top-level key; a hand-wired entry
			running the same script is kept as the policy's own and
			its script replaced; it
			writes no blanket `Bash` deny, since the reroute hook
			governs `Bash`, and removes one an earlier install
			wrote, matching the exact entry only, so a deny rule
			the user added stays. Also maintains a `.claude`
			symlink per namespace root under the workspace, kept in
			sync with the workspace's own namespace list. Real
			content found at a target is deleted and replaced by
			the link.

			Before reporting success, re-reads the written settings
			and confirms every expected hook is wired and every
			referenced hook script exists and is executable --
			reports each `OK`/`MISSING` by name; any `MISSING` fails
			the run (exit 1).

		--install-skillset-symlinks [--scope workspace|user-home] [--workspace <path>]
			Installs skillset-link integration: symlinks every bundle
			member and every project-declared team-member into the
			scope's hidden skills directories (`.agents/skills`,
			`.claude/skills`, `.copilot/skills` as applicable),
			creating them if missing.

			`--scope workspace` targets `<workspace>/.agents/skills`
			and `<workspace>/.claude/skills`; `--scope user-home`
			targets `$HOME/.agents/skills`, `$HOME/.copilot/skills`
			and `$HOME/.claude/skills`. Default: workspace, falling
			back to user-home if the resolved workspace isn't a
			set-up myx.distro workspace and `--scope` wasn't given
			explicitly (an explicit `--scope workspace` there is an
			error). Default workspace is the current shell directory;
			`--workspace <path>` overrides it.

			A member declared by more than one project becomes a
			merged composite; a name both bundled and declared keeps
			the bundled copy, the declared source shadowed and warned
			about, never silently overwritten. Idempotent: an
			already-correct link is left alone, a no-op run reported
			as such. Real content already at a target is deleted
			and replaced by the link.

			A `--scope user-home` slot already linking to another
			workspace's copy: a workspace holding the member in its
			own `source/` relinks one that reaches an installed copy
			(`<workspace>/.local/myx/...`); one that reaches another
			source copy is kept, with one warning naming both copies.
			An installed copy never takes the slot from a source one.

			The link folders are generated output for the vendor
			clients, never a source. What was linked is recorded as
			our own data: `--scope workspace` in
			`<workspace>/.local/agents/members.registry`, `--scope
			user-home` in the machine-wide
			`$HOME/.agents/magic-team/members.registry` -- one row per
			member, TAB-separated: member, workspace root, link kind,
			relative path, member directory. Every run then rewrites
			the workspace's member index, `.local/agents/members.index`
			and its `members/` view: this workspace's own members
			only, each name once; a link to a member of another
			workspace is removed. `MDAT_SKILLSET_ROOT` defaults to
			that view.

		--install-vscode-integrations [--workspace <path>]
			Installs/updates baseline VS Code + Claude Code MCP
			integrations and the Magic-Team panel. Installs no chat-
			client extension itself -- that choice stays the user's.
			Wires `myx.common` into workspace `.vscode/mcp.json`,
			workspace-root `.mcp.json`, and Claude Code's home local
			scope (`~/.claude.json`). Each written entry is verified by
			re-reading it. Writes `.local/agents/mcp.servers.index`
			first, from the servers the workspace has installed, and
			generates every MCP JSON entry (`.local/agents/
			mcp.servers.json`, `.vscode/mcp.json`, `.mcp.json`) from
			that index; the universal harness reads the index only,
			never those files.

			Default target workspace is the current shell directory;
			`--workspace <path>` overrides it. Fails fast if the target
			isn't already a set-up myx.distro workspace. A missing VS
			Code CLI is irrelevant and not reported. A missing
			`~/.claude.json` is a warning only. Prints an OK/FAIL
			checklist plus Command Palette trust/restart guidance.

		--install-knowledge-store [--from-folder <folder>]
			Installs the Python environment the knowledge store
			(LanceDB) needs, in `.local/knowledge-store/` of the
			workspace, from binary packages alone. The store is optional
			and off unless the setting `MDAT_KNOWLEDGE_STORE` is `on` (the
			environment first, then the settings of the team;
			`--manager-config-set` saves it): with it off the call
			refuses, says so and how to turn it on, and installs nothing.
			With it on, it asks the embedded Python of the local tools
			(`DistroLocalTools.fn.sh --install-embedded-python`) for its
			Python, which that makes where it stands not yet; where that
			refuses, this refuses with its reason. There is no other
			Python and no system package, on any system. It downloads
			LanceDB, pinned, and what it needs as binary packages
			(`pip --only-binary=:all:`) into `wheelhouse/`, or, with
			`--from-folder`, takes the wheels of a folder downloaded
			once elsewhere (the `wheelhouse/` of an online run, copied)
			and downloads nothing. A host with no internet takes two
			copied folders: the `downloads/` of `--install-embedded-python`
			first, by its own `--from-folder`, then this `wheelhouse/`.
			Before anything is placed it lists
			every package with its version and its licence, read from its
			wheel. Then it makes the environment `venv/` with that Python
			and installs LanceDB into it from those files alone
			(`--no-index`); the environment must import `lancedb`. The
			licence files and the NOTICE of every package are copied into
			`licenses/<name>-<version>/`, and the list is kept in
			`packages.txt`. pip keeps no cache, its temporary folder is
			`tmp/` of the store, and nothing is written outside the
			workspace's `.local`. Where pip finds no binary package for
			the system, or the environment cannot import `lancedb`, it
			says so, leaves nothing, exits 1, and the store stays off: the
			Knowledge tool reads `MAGIC.md` alone. On standard output it
			prints the Python of the environment, one line; everything
			else is on standard error. Safe to run again: an environment
			that imports the pinned LanceDB is left as it is. Nothing
			reads the store yet.

		--install-workspace-integrations [--scope workspace|user-home] [--workspace <path>]
			Runs, in order: `--install-vscode-integrations`,
			`--install-skillset-symlinks` (forwarding `--scope` if
			given), records workspace trust in `$HOME/.claude.json`, then
			`--install-claude-permissions` (unaffected by `--scope`/
			`--workspace`, since it is $HOME-scoped).

			With no `--scope`, runs the user-home step then the
			workspace step, both unconditionally. Fails fast if any step
			fails. An empty `--scope` or `--workspace` value is rejected
			rather than treated as absent.

		--make-workspace-integrations [--quiet]
			Registers the workspace's places, makes the console command,
			then installs in two parts with the one build of the indices
			between them: the part of --install-workspace-integrations
			the indices are made from (the MCP registration and the
			member links), the members' homes, --make-harness-indices
			with no name, then the part that reads the indices (the
			trust, the permissions, the settings, the copilot access),
			and --install-workspace-restrictions (only where restrictions
			were installed, that is where
			.claude/hooks/deny-native-tool-reroute.sh exists), against
			$MMDAPP. A step that fails ends the run; later steps don't
			run. `--quiet` suppresses the usage guidance normally printed.

		--make-harness-indices [<name>...]
			The one operation that makes every index of the tooling in
			`$MMDAPP/.local/agents`, the registries among them. With no
			name it builds all of them, in the order below; with names,
			only those, in that same order whatever the order given. A
			name is the stem of the file it builds: `team-members`,
			`team-members-names`, `spawned-sessions`, `pending-replies`,
			`members`, `permissions`, `grants`, `tool-index`,
			`mcp.servers`, `harness.roots`, `harness.hooks`. A name that is none of
			them refuses the call before anything is built, in one line
			that lists them. Prints nothing on stdout, notes what it
			writes on stderr under the name it was called by, and fails
			when a file cannot be written. Run once by the install,
			between its two parts, and once by the source-prepare build.

			Rebuilds the prepared registries of this workspace's team
			members in `$MMDAPP/.local/agents`: `team-members.registry`
			(member, workspace, link kind, skillset path) and
			`team-members-names.registry` (member, mark, first name,
			family name, alias), rows only for members that have a path
			in this workspace, read from its own
			`.local/agents/members.registry` -- and the member index,
			`members.index` and its `members/` view. Names come from each member's
			basic.md (the Name bullet split at its first space, and the
			Alias bullet), replaced by the member's scope key
			FIRST_NAME, FAMILY_NAME or ALIAS when set; a value that
			is missing, `not decided yet` or not valid is stored `-`
			and warned about, unless the member is reference-only.
			Every client-* row carries the persona member's values
			instead (its own files and scope are not read).

			Also the two registries of this workspace's sessions,
			each whole, from its store: `spawned-sessions.registry`,
			a row for every spawn record under
			`.local/agents/spawned`, and `pending-replies.registry`,
			a row for every ask under `.local/agents/pending` and
			for every board item that carries `blocked-on`. A
			workspace that has no such store yet gets the registry
			with no rows, and the build goes on. The operations that
			read one of the two still rebuild it first.

			Then the grants. `permissions.registry` (`member:workspace:
			kind:grant`), and its `permissions-tags.registry`, from what
			this workspace's projects declare, `magic-team:permissions:
			<scope>:<selector>:<verb>:<member>[:<glob>]`, and what every
			registered tooling workspace without agents declares (`.`
			there is that workspace): `namespace:<ns|.|*>` in every
			tooling workspace, `workspace:<name|.|*>` (or a pattern,
			`*-testbed`, matching workspace place names, none matching
			no error), `directory:<name>` through the registered
			places, capped to read on a read-only one, and
			`project:<selector>`; and
			`magic-team:testing:<project-glob>:<sh-test-path>:<host-glob>`,
			magic-tester's write over `<sh-test-path>/**` of each of this
			workspace's projects whose name the glob matches, a
			`project` row (none for another host, none for a glob
			matching no project, a malformed line skipped with a warning);
			`allow-write` an `Edit(...)` row, `allow-read` a `Read(...)`
			row, `allow-tool` a `<tool>[:<target>]` row. A name no
			place carries is an `unresolved` row, with a warning. Every
			acting member's own directory, and magic-librarian's read
			of `source/**`. A scan that cannot be trusted keeps the
			registry as it stood. Then `grants.index`: every member's
			rows of every workspace's registry, fully unrolled (`*` one
			row per member), the workspace floor, and the places'
			ceilings -- what every permission check reads. A grant
			written `approve:Edit(...)` is a write by approval, a read
			row and an `approve` row: the member reads those files, and
			its Edit or Write of one is held, shown to the human-owner
			and applied when he approves, unless a grant given for its
			task, its session or the one call allows it; no floor or
			standing row comes ahead of the approval. A reader finding
			it stale or missing rebuilds it.

			Then `tool-index.md`, the tool index (--intern-op-tool-index):
			one section per team member, every shell operation and every
			harness and MCP call, those the member may use with their
			one-line description, every other one by its family or its
			name, with whom to ask. Who may use what is read from the
			dispatcher's caller checks and from the grants index. A
			member's Skill read of its own skill serves its section,
			rebuilt first where it is missing or stale.

			Last the universal harness's own indexes in
			`$MMDAPP/.local/agents`, which it reads at every start
			instead of recomputing them: `harness.roots.index`
			(the access roots, already resolved),
			`harness.hooks.index` (the hooks the client tool policy
			names) and `mcp.servers.index` (the servers this workspace
			registers, as --install-vscode-integrations also writes
			it), each one index used whichever origin a harness of
			this workspace runs from. Each is produced from our own
			primary data by the code the harness otherwise runs --
			never from `.claude/settings.json`, `mcp.servers.json` or
			any other file written for an external tool, which the
			harness never reads -- and is used only while what it was
			produced from is unchanged, so a missing, stale or
			older-format one only costs time. The
			children lists under `children/` are not this op's: the main
			loop rebuilds them.

		--make-agents-indices [<name>...]
			The earlier name of --make-harness-indices: the same operation.

		--make-console-command [--quiet]
			Re-creates `DistroAgentsConsole.sh`, the command to quickly
			enter the workspace console. `--quiet` suppresses the usage
			guidance normally printed.

		--make-console-script
			Prints the agents console script body (used by
			`--make-console-command`) and exits.

		--manager [--style <name>]
			Starts the manager screen of the agents console, the console
			app, in this terminal: what `DistroAgentsConsole.sh --manager`
			runs, and what a console started on a terminal with no --cli
			opens. It is none of the console's own `--manager-*`
			operations below, which are the shell console user's fallback
			and what the screen reads and acts through. `--style <name>`
			is the interface style of this start alone; with none, the
			style the environment names (MDAT_MANAGER_STYLE), else the one
			the user saved (--manager-config-set), else the screen's own.
			`MDLT_CONSOLE_SPACERS`, a console setting of `.local` and the
			user's own, read from the environment and else from the
			user's settings: `disable` starts the screen with no blank
			line between the groups of its lists. `MDLT_CONSOLE_MOUSE`,
			beside it and read the same way: `disable` leaves the mouse
			to the terminal, whose own selection then copies text; the
			mouse is on where nothing is saved. Needs python3 and a
			terminal: where the screen cannot start, it says why in one
			line. Exit: the screen's own status. Exit 1, nothing started,
			for any other word.

		--manager-check-run [--local] [--seconds <n>] [<domain>...]
			One of the console's own operations (see Notes). Shows what
			the check of the setup says: it runs the owner's read-only
			diagnosis, `--owner-setup-<domain> --check`, for each domain
			or for those named, and puts each result line of it into one
			row. It makes no check and no judgement of its own, writes
			nothing, and reaches what those checks reach. The domains:
			`claude`, `copilot`, `grok`, `scaleway`, `slack`, `storage`.
			Not for a tick: a check takes seconds. All are started at
			once and waited for together, for <n> seconds at most, 60
			where none is given; one that has not ended by then is ended
			and reads `skipped`, and the others still answer. `--local`
			leaves out the domains whose check asks outside this
			machine, `claude` (it asks the CLI whether it is signed in)
			and `slack` (it asks Slack for the workspace of the token):
			each reads `skipped`. Prints rows of TAB-separated fields on
			stdout, an absent value `-`, a value's whitespace `_`:
			`check <domain> <section> <key> <label> <state> <reason> <remedy>`
			`summary <checks> <ok> <warn> <fail> <skipped> <seconds>`
			<section> is the heading the check printed above the line,
			<key> the name of the check and <label> its words,
			capitalised. <state> is `ok`, `warn` or `fail`, as the check
			said, or `skipped`. <reason> is what the check said of it, in
			its own words. <remedy> is the command the check names to
			fix it, its blanks kept, since it is run as it stands. The
			one `summary` row is the last line. Exit 0 whatever the
			checks say. Exit 1, nothing run, for a word that is no
			domain.

		--manager-command-list
			One of the console's own operations (see Notes). Lists the
			tooling commands a console user calls by name, one a line
			on stdout, TAB-separated: `<Name>.fn.sh <file>`, the base
			name with its extension, as it is typed, as
			`DistroAgentsTools.fn.sh`, then the file that name resolves
			to, its whole path, `-` where none does. The names are what
			the console's completion gathers, by its own two readers:
			the `*.fn.sh` of the sh-scripts folder of each installed
			package of the family, as `Agents --completion-all` lists
			them, and the commands the projects declare, from the index
			the workspace holds in .local, as
			`Distro --shell-path-append --completion` reads it. A name
			is listed once, in the order of `sort -u`. Its file is the
			one the shell finds for it (`command -v`) on the console's
			folders alone, in the order of a console's PATH: the
			family's sh-scripts folders as the agents console puts them
			there (agents, .local, system, deploy, source, remote), then
			the folders of the projects' commands as
			`Distro --shell-path-append` gives them; so of two of one
			name the first one wins, a file whose executable bit is gone
			is found as the shell finds it, and a name no folder holds
			has none. It only reads: no file is opened.
			Takes no argument.

		--manager-config-digest [--full] [<subject>...]
			One of the console's own operations (see Notes). Prints the
			settings of this workspace as they are, for viewing. It only
			reads: no setting, no registry and no file is written. With no
			name it prints every subject, in the order below; with names,
			only those, in that same order whatever the order given. A
			name that is none of them refuses the call before anything is
			printed, in one line that lists them. Prints rows of
			TAB-separated fields on stdout, the first naming the row. An
			absent value reads `-`, and a value's own whitespace reads `_`,
			as in a registry.
			`subject <subject> <lines> <label>`
			`line <subject> <group> <key> <state> <value> <label>`
			A subject row is followed by its lines, which it counts.
			<label> is what a screen calls the subject or the line, the
			last field of every row: capitalised words, more than one,
			their blanks written `_`. <subject> and <key> stay the names
			a call takes. The labels have one declaration. The subjects
			are `Workspace Paths`, `CLI Services`, `Outside Systems`,
			`Main Loop`, `Scope Settings`,
			`Interface Settings`, `Console Behaviour`,
			`Session Control` and `Knowledge Store`. A line the tooling prints under a key
			of its own has a label of its own, as `Workspace Root` or
			`Interface Style`. A line whose key is not the tooling's has
			one by rule: a key of a scope, a credential of a harness leg
			and what the main loop left in its state file by the words
			of the key, capitalised, as `Slack Bot Token`; a registered
			place and a scope of an outside system by its name, after
			`Registered Place` and `Scope`. A line that no row of the
			declaration fits has the label `-`.
			`Workspace Paths` holds the mode of the workspace too,
			`MDAT_WORKSPACE_MODE`, a line of the configuration:
			`just-agents` (inline work and native consoles of this
			computer, and no team data: the operations that write a board
			item, an inbox item, an audit item or a contact are refused,
			no team-data store is cloned, and a session it starts keeps
			no tracking item; the list is `agentsTeamDataGateOps` in
			`AgentsTools.TeamDataGate.include`), `rig-client` (it will
			dispatch to a remote rig; not built yet, it acts as
			`just-agents`) or
			`team-rig` (a rig itself: the team data is used and maintained
			here), as the installer of the workspace set it in the
			settings of the team, and `just-agents` where nothing sets it
			(a rig of the test runner is given `team-rig` by
			`MDAT_WORKSPACE_MODE`, which a setting stands ahead of);
			and `full-team-rig`, `set yes` on a team rig whose team data
			has a git remote. `Main Loop` is printed in the
			mode `team-rig` alone.
			With `--full`, given ahead of every name, each `line` row has
			eight more fields at its end, and ahead of the lines of each
			group of a subject stands one row of the group, which counts
			them and gives what a screen calls the group: capitalised
			words where the group is the tooling's own word, the name as
			it is written where the group is a name, a CLI's, a system's,
			a scope's. The rows are the same otherwise:
			`group <subject> <group> <lines> <label>`
			`<description> <change> <kind> <scope> <source> <values> <where> <belongs>`
			<description> is one or two plain sentences on the line, from
			the declaration of the labels, with no value in it. <belongs>
			says which of the two the line is: `settings`, what a user
			sets for himself in this workspace and what may be changed
			while things run; `configuration`, what is deployed and
			configured for the workspace or the machine, and everything
			measured. <change> is `yes` for a line of the settings, which
			`--manager-config-set` saves, and for a line of the
			configuration `no:set_at_deployment:_a_wizard_will_change_it`.
			For a line that can be changed <kind> is `choice` or
			`number`; <scope> is `user`, the user's own in this
			workspace, or `workspace`, for everybody; <source> says where
			its value comes from, `environment`, `user`, `workspace` or
			`default`; <values> is what it takes, for a choice
			<value>=<label> joined by commas in the order they are
			offered, for a number <smallest>..<largest>; <where> is the
			file it is saved in. Each of the five reads `-` for a line
			that cannot be changed.
			<state> is `set`, `missing`, `secret-set` or `secret-missing`.
			A credential is printed in one form, in every row and every
			message: the first quarter of its value, rounded down, not less
			than 4 and not more than 20 characters, then a `*` for each
			character after them, even for a long key; a value of fewer
			than 4 characters is all `*`. Its line reads `secret-set` with
			that form as its value, or `secret-missing` with the value `-`.
			A credential is a key the owner setup's catalogue marks secret
			or one a harness leg reads; every other key shows its value.
			In full (`--full`), the form the settings views of the
			console read, a value that carries a password inside a URL,
			under any key, reads `secret-set` and has only that password
			masked; otherwise a key that is no credential shows its value.
			`workspace`: group `paths`, the root of the workspace, the
			origin of the tooling, the root of the team data, the two
			session stores and the folder of the scopes, each `set` where
			it is there and `missing` where it is not, with the path
			either way; group `places`, each registered place by name
			with its path, as --owner-workspace-list gives them.
			`cli`: group `workspace`, the CLI service the workspace asks
			for, its harness tier, its wait round and the workspace its
			spawn settings are read from; then one group for each CLI the
			console knows: `present` with its file or its binary, each
			credential a harness leg reads as a secret line, `usable` as
			`yes` or `no`, and `wait-round` in seconds. A leg is usable
			with one of its credentials set, a vendor CLI where its
			binary is.
			`systems`: one group for each outside system, the team's own
			Slack first: `slack`, `email`, `jira`, `confluence`, `trello`,
			`google`. A scope has a line whose <key> is the scope, whose
			<state> is `set` where that scope holds a value under a key of
			the system, and whose <value> names the keys it lacks, joined
			by commas: each key the catalogue keeps in that scope with no
			value, then each key the scope holds with none. Under it
			stands one line for each key of the system the scope holds a
			value of, the catalogue's keys first and then the file's:
			<key> is the key itself, <state> is `set` and <value> the value
			as the scope has it, or `secret-set` and a credential in the one
			form above; a key held with no value has no line of its own.
			With `--full` such a line carries <source>, the scope that
			holds the key, and <where>, the file of that scope; it belongs
			to the configuration and is not changed from the digest. A
			system no scope holds has one line with the scope `-`.
			`loop`: group `main-loop`, its state file and what the last
			iteration left in it. Nothing says that a main loop runs now, so
			that is not printed.
			`scopes`: one group for each scope that holds a key, <key>
			the name of the key, in the order of its file. A scope with
			no key is left out, and a line that is a comment is no key.
			A line whose name is not a setting's, capital letters, digits
			and `_`, is never listed: a note on stderr counts them.
			`interface`: the interface settings of the user who runs the
			call, one line a setting, each with two more fields after
			its value, ahead of its label:
			`line interface <group> <key> <state> <value> <source> <choices> <label>`
			<group> is a short name of the setting and <key> its key, as
			`--manager-config-set` takes it. <state> is `set`
			and <value> what the setting is now. <source> says where that
			comes from: `environment`, the variable of the environment
			that bears the key; `user`, what the user saved in this
			workspace; `default`, where neither names one. The
			environment comes first, and a name that is no value of the
			setting counts as not given, wherever it stands. <choices>
			are the values that may be chosen, in the order they are
			offered, joined by commas, each `<value>=<label>`. One
			setting now, the interface style of the manager screen:
			group `style`, key `MDAT_MANAGER_STYLE`, value
			`<style>-<colours>`: `nu-system`, `nu-blue`, `nu-gray`
			(Magic), `tv-system`, `tv-blue`, `tv-gray` (Turbo Vision),
			`bw-system`, `bw-dark`, `bw-light` (Basic B/W); `tv-system`
			where nothing names one. Another name of one is read as it:
			`dark` for `blue` and `light` for `gray`, and a style alone,
			saved before styles had colours, as the one it was drawn in
			then: `tv` as `tv-system`, `bw` as `bw-system`, `magic` (and
			`magic-<colours>`) as `nu-gray` (and `nu-<colours>`).
			`console`: what a console of this workspace does. Group
			`history`, key `MDLT_CONSOLE_HISTORY`, where a console keeps
			the shell history of the user, which every console reads at
			its start, the user's own setting ahead of the workspace's:
			`workspace-personal`, `workspace-separate`,
			`workspace-shared`, `local-machine-home`, `bash-default` or
			`user-default`. Group `origin`, key `MDLT_CONSOLE_ORIGIN`,
			where every console of the workspace loads its tools from:
			its own installed copy where no key is set, the first of its
			choices, which has no value; or the `source` or the `.local`
			of a registered workspace that has the tool family, listed at
			the call; a path set by hand is shown as it is. Group
			`detail`, key `MDLT_CONSOLE_DETAIL`, the verbosity of a
			console the user starts: none where no key is set, `true` or
			`full`, which the agents console alone reads today.
			`control`: the two bounds of a request to the control thread
			of a session, in seconds, each what is saved for the team or
			else its default: group `request`, key
			`SESSION_CONTROL_REQUEST_SECONDS`; group `kill`, key
			`SESSION_CONTROL_KILL_SECONDS`.
			`knowledge`: the switch of the knowledge store, one line:
			group `store`, key `MDAT_KNOWLEDGE_STORE`, `off` where nothing
			sets it, or `on`, from the environment or from what is saved
			for the team. The store is installed by
			`--install-knowledge-store`, and only when this is `on`.

		--manager-config-set <key> <value>
			One of the console's own operations (see Notes). Saves one
			changeable setting, and nothing else: the one operation of
			the settings that writes. <key> is the key of a line that
			`--manager-config-digest --full` says can be changed, a line
			of the `settings`, and <value> one that line takes. Seven are
			declared. `MDAT_MANAGER_STYLE`, a `choice`, the user's own:
			the interface style of the manager screen at its next start,
			`<style>-<colours>`; another name of one is saved as the one
			it means, `tv-dark` as `tv-blue`, `magic` as `nu-gray`.
			`MDLT_CONSOLE_HISTORY`, a `choice`, the user's own: where a
			console keeps the shell history of the user, read at its next
			start. `MDLT_CONSOLE_ORIGIN`, a `choice`, the workspace's:
			where its consoles load their tools from at their next start,
			saved in `.local/MDLT.settings.env` under its root.
			`MDLT_CONSOLE_DETAIL`, a `choice`, the user's own: the
			verbosity of a console the user starts, which the agents
			console alone reads today. AN EMPTY <value> REMOVES THE
			SETTING, whichever it is: its key is taken out of the file,
			no key with nothing after it is ever written, and the row
			printed is `removed <key> <default> <scope> <where>`, with
			the default the setting is at then, `-` where that is that
			nothing is set. The first choice of such a setting has no
			value: choosing it gives the empty one.
			`SESSION_CONTROL_REQUEST_SECONDS`, a `number` from 1
			to 60, and `SESSION_CONTROL_KILL_SECONDS`, a `number` from 5
			to 600, the workspace's: the two bounds of a request to a
			control thread, read at the next request.
			`MDAT_KNOWLEDGE_STORE`, a `choice` of `off` and `on`, the
			workspace's: whether the workspace wants the knowledge store,
			read at the next use, `off` where nothing sets it. A setting of scope
			`user` is saved in the user's own settings of this workspace,
			`.local/home/<user>/MDLT.settings.env` under its root, by the
			setting reader of the local tools in its scope of the current
			user. <user> is the name the operating system gives the user
			who runs the call, whatever the environment names, so the
			settings of another user are never read and never written. A
			setting of scope `workspace` is saved for everybody, in the
			settings of the team, `.local/.agents/magic-team.agent.env`,
			by `--agents-config-option`: the console's operator may, who
			stands at least equal to magic-coordinator, and a member's
			session is refused as for every operation of the family.
			Either way every line that set the key is replaced by one and
			every other line of the file stays. Prints one row of
			TAB-separated fields on stdout:
			`saved <key> <value> <scope> <where>`
			<value> is the value as it was read back after the write,
			<scope> `user` or `workspace`, and <where> the file, its
			whitespace written `_`. Exit 1, with one error line, nothing
			printed and nothing saved: where <key> is none of the
			changeable settings, a key of the configuration among them,
			in a line that lists the keys; where <value> is none the
			setting takes, in a line that lists its values or gives its
			range; where it is not given one key and one value, in a line
			with its syntax. Every such line ends `nothing was saved`.
			Nothing that was given is repeated in it, and no value but
			one a declared setting takes is ever saved, so no secret
			reaches a file. Exit 1 too where the file does not hold the
			value after the write.

		--manager-console-list
			One of the console's own operations (see Notes). Lists the
			consoles that can be started from this workspace right now,
			for a manager screen to start one as a child on its own
			terminal and to have the terminal back when the child ends.
			It only reads: nothing is started and nothing is written.
			Prints rows of TAB-separated fields on stdout, the first
			naming the row.
			`console <key> <group> <label> <terminal> <directory> <word>...`
			One row a console, in the order of a menu: <group> `shell`,
			then `agents`, then `distro`. <key> names the console:
			`bash`; the name of a vendor CLI, as `claude-native`;
			`source`, `local`, `deploy`, `remote`. <label> is what a
			screen calls it: capitalised words, more than one, their
			blanks written `_`, as `Bash_Shell`, `Claude_Native_Console`,
			`Source_Console`, `Local_Tools_Console`, `Deploy_Console`,
			`Remote_Console`. <terminal> is `terminal` where the console
			needs a terminal on its input and on its output, and `-`
			where it needs none. <directory> is the folder to start it
			in, the workspace root. Every field after it is one word of
			the command, the first the program, by its absolute path.
			<directory> and each <word> are exact, and not written as a
			value is in the fields before them: a blank in one is a
			blank of the path or of the word, `_` is `_`, `-` is `-`.
			None of them is empty, and none holds a TAB or a line end.
			So the command needs no shell: its words are handed to exec
			as they are, in <directory>, with the environment of whoever
			starts it, and what the console needs beyond that its own
			words carry. No field holds a secret.
			The row `bash` is a bash shell in the workspace with what a
			console user gets, the tooling's functions and the tools of
			every installed package on its PATH: bash with the rc file
			of the agents console. A row of the group `agents` is a
			vendor's own console, started as
			`DistroAgentsConsole.sh --cli <name>`
			which is what `Agents --start-console --cli <name>` runs. A
			row of the group `distro` is one of `DistroSourceConsole.sh`,
			`DistroLocalConsole.sh`, `DistroDeployConsole.sh` and
			`DistroRemoteConsole.sh`. Nothing is listed that would not
			start. A vendor CLI is a row only where the workspace's
			console command is there, is executable and names it, and
			where `--manager-config-digest` reads it usable. A Distro
			console is a row only where its command is a file of the
			workspace root and executable. A console whose folder or
			command holds what a row cannot carry is left out, with a
			note on stderr. A harness leg is never a row: a start of one
			by name is the manager screen itself.

		--manager-dashboard-read [--group <group>] [<block>...]
			One of the console's own operations (see Notes). Prints the
			dashboard, which is the local tools' own (.local): the panels
			this console registers in its plain list file
			(sh-lib/config/dashboard-panels.list), the most vital figures
			of this workspace and of the machine it runs on, grouped in
			blocks that a screen draws as titled boxes, with no knowledge
			of what is in one. It only reads, for viewing: no registry is
			rebuilt, no scope of settings is read but the one setting that
			says whether a CLI service is set up, no git command is run
			but for the block `team-data-git`, and nothing reaches another
			host. With no name it prints every block of the group but
			those the list says are printed only when named, in the order
			of the list; with names, only those, in that same order
			whatever the order given. --group names a Dashboard submenu
			the list declares, instead of the Dashboard itself: `tokens`,
			Agents: Tokens; a group that is none refuses the call. A word
			that is none of the blocks of the group refuses the call
			before anything is printed, in one line that lists them.
			Prints rows of TAB-separated fields on stdout, the first
			naming the row. An absent value reads `-`, and a value's own
			whitespace reads `_`, as in a registry.
			`block <block> <label> <figures>`
			`figure <block> <figure> <label> <value> <unit> <level> <share>`
			`group <group> <label> <panels>`
			A block row is followed by its figures, which it counts. A
			block that has no honest figure on this host is left out,
			and so is a figure the host gives no answer for: nothing is
			guessed. <label> is what a screen calls the block or the
			figure: capitalised words, their blanks written `_`. <unit>
			says how <value> reads: `count`, a whole number of things;
			`bytes`; `seconds`, a length of time; `-`, a word, a path or
			a plain number, shown as it is. <level> is `ok`, `warn` or
			`bad`, and `-` where nothing is judged. <share> is a whole
			number from 0 to 100 where the figure is a part of a whole,
			for a bar, and `-` where it is none. The blocks have one
			declaration, the list file: a reader takes a block or a figure
			it does not know as one more box or one more line. The
			Dashboard itself ends with a `group` row for each submenu that
			applies on this host: its label, as <label>, and how many
			panels it holds.
			`sessions`, Sessions And Agents: the sessions that read
			`running`, `waiting` and `unclosed`, and those paused, the
			agents working and waiting, as `--manager-session-list`
			counts them, by its own code; the control threads that are
			`alive` and `gone`; and `deaths-unanswered`, the sessions
			whose control thread keeps a death that is not settled and
			whose question has no answer yet. The two registries of the
			sessions are read as they lie, and which runs are alive is
			measured at the call. Only the sessions that can count are
			measured: those with a record still open, an open ask, an
			end of today or a control thread. A session whose every
			record is closed is not asked for a process, so one that the
			list reads `running` by a process left behind a closed
			record is not counted here. `warn` on an unclosed session, a
			thread that is gone and a death unanswered.
			`pending`, Pending Questions: `open`, the asks that wait in
			the registry `pending-replies` as it lies; `asker-gone`, how
			many of them, asked on this host, have no live asker,
			measured at the call as `--member-pending-reply-read` says
			it; `human-owner`, how many are addressed to the human-owner;
			`oldest-age`, how long the oldest has waited. Of a question
			its header alone is read.
			`tokens`, Session Tokens: printed only where a CLI service is
			set up for this workspace (its setting SPAWN_CLI_SERVICE is
			set); `running`, the tokens of the
			sessions that run now, and `finished-today`, of those whose
			last run closed on this host's date of today. A total covers
			in, cache read, cache write and out, all added, of every run
			of the session, as the <tokens> of `--manager-session-list`
			has them from the store of each run. `not-whole` is how many
			of those sessions have a run with no known figures, so that
			their total is less than they used. No transcript is opened.
			In the group `tokens`, Agents: Tokens, which applies where a
			CLI service is set up, two panels: `tokens`, the same figures
			with `running-sessions`, `running-average`,
			`finished-today-sessions` and `finished-today-average`, how many
			sessions each total is of and what a session took on average;
			and `top-sessions`, Top Sessions By Tokens, a figure `top-<n>`
			for each of the five sessions that took the most of those the
			list of sessions measures for it (not closed, or closed today),
			named by the session or its id, ending in `+` where its total is
			less than it used.
			`team`, Team Members: `members`, the members the machine
			knows, the team itself not counted; `startable`, how many of
			them can be started here, which a member with no folder and
			an identity record cannot; `running`, how many have a run
			with a live process in a session of this workspace.
			`team-data`, Team Data: `root`, the root of the team data,
			and `present`, `yes` or `no`; `size`, of all that lies under
			it; and `board-<state>`, the items of the board in each
			state, a folder of the board a state and a `.md` file of it
			an item; `audit-items`, `audit-month` and `audit-newest`, the
			items of its audit, a file of `audit/` or of a month folder
			of it, how many came this month and the age of the
			newest by the stamp of its name; `vault-items` and
			`vault-newest`, the files of its vault and the age of the
			newest by its file; nothing of an item is opened.
			`team-data-git`, Team Data Git, printed only where it is
			named, and the one block that runs git, locally, with no
			fetch: `repository`, `yes` or `no`; `branch`, `upstream`,
			`ahead` and `behind` as of its last fetch, `uncommitted`, the
			paths under the store not committed, `last-commit`, its age,
			and `last-subject`; judged only on a full team rig.
			`loop`, Main Loop: as `--manager-config-digest`
			reads them, how the last iteration of the main loop ended,
			how long ago, and after how many failures in a row. Nothing the tooling keeps says that a
			main loop runs now, so that is no figure. Printed in the
			mode `team-rig` of the workspace alone, and judged only on a
			full team rig, whose team data has a git remote: elsewhere
			every level of it is `-` (see `--manager-config-digest`).
			`machine`, The Machine: the three load averages, each with a
			level and a share by what it is of the processors, `warn`
			from one runnable process a processor and `bad` from two;
			the processors; the memory in use, with its share of all of
			it, `warn` from 90 and `bad` from 97, and the memory free to
			use, which is the pages nothing holds and those given up
			when asked; and how long the machine is up. Each by what
			macOS, Linux and FreeBSD has for it.
			`disk`, Disk Space: of the volume the workspace lies on, of
			the one its temp folder `.local/temp` lies on, and of the one
			the root of the team data lies on, each volume once, under
			the first of the three that lies on it: `<name>-size`,
			`<name>-used` with the share `df` gives and a level, `warn`
			from 85 and `bad` from 95, and `<name>-free`. <name> is
			`workspace`, `temp` or `team-data`. The Machine and Disk
			Space are the local tools' own panels: this console registers
			them, and adds the volume of the team data to the disk.
			`testing`, Retest Queue: `waiting`, the retests that wait in
			the queue of the machine, and `oldest-age`, how long the
			oldest of them waits.
			What is slow to read and changes seldom is kept for ten
			minutes, in `.local/temp/mdat-manager-dashboard.*` of the
			workspace: the size of the team data, which is a walk of
			every file under it, the two counts of the members, and
			whether a CLI service is set up.
			Everything else is read at the call. Where that folder
			cannot be written the size is not measured at all.

		--manager-help-read
		--manager-help-read <Name>.fn.sh
			One of the console's own operations (see Notes). Prints the
			help of this tool as it is written, on stdout, and writes no
			help of its own: first what a user calls, the syntax lines
			of the help, each once in its order, but those of the
			internal operations and of the families the agents call: a
			member's, the librarian's, the coordinator's, a client's, a
			routine's and a console channel's; then one empty line; then
			every operation of the manual: the syntax lines
			that `--help-syntax` prints, and the entry of each operation,
			its syntax lines and its text, as `--member-help` prints those
			of a member's operations; then the chapters of the help file
			but its options, one row a line, TAB-separated:
			`chapter <head|foot> <line>`, `head` for a line before the
			first option, the heading of the options the last of them,
			`foot` for one after the options, the line as it is written.
			With `<Name>.fn.sh`, one of the tooling commands
			`--manager-command-list` lists, it prints instead the help
			that command's own `--help` prints, from where it prints it,
			and runs nothing: the syntax lines its help include,
			`Help.<Name>.include`, echoes that its help file does not
			hold, each once in their order, then its help file,
			`Help.<Name>.help.md`, as it is written, both from the help
			folder `sh-lib/help` of the package whose sh-scripts folder
			holds the file the name resolves to. A command with no such
			file, or that resolves to none, prints nothing. A name the
			list does not hold, and a second argument, are refused in
			one line, rc 1, nothing on stdout.

		--manager-keys-list
			One of the console's own operations (see Notes). Lists the
			public keys this server shows to others, the keys the rig's
			own command `mdci-public-keys` prints, found where it finds
			them. Only a public file is ever opened, one whose name ends
			`.pub`: no private key is opened, and that command is not
			run. It only reads, and reaches no other host. Prints one
			row for each key, TAB-separated, on stdout, an absent value
			`-`, a value's whitespace `_`:
			`group <group> <keys> <label> <note>`
			`key <key> <label> <group> <purpose> <type> <fingerprint> <short> <file> <state> <public>`
			A group row stands ahead of its keys, which it counts, with
			what a screen calls the group; <note> says why, where none of
			its keys can be read, and reads `-` else. There are two groups,
			in this order: `ours`, Our Keys To Trust, every key of this
			server that others are to trust, whatever it is for, and
			`trusted`, Keys We Trust, the keys this account trusts, which
			are only listed. The <group> of a key row is one of the kinds
			below for a key of `ours`, and `trusted` for the other.
			<group> is `add-to-git`, a key an owner lists on a git host
			as a deploy or user key: `deploy`, the key the account uses
			for git, and `generated`, the default it made where that is
			another one. Or `trust-on-connect`, an ssh host key of this
			server, which whoever connects to it checks and accepts:
			`host-<type>` for each. Or `add-to-authorized-keys`, the key
			the deploy and remote tools of this workspace connect out
			with, which the owner of a target puts into its authorized
			keys: `outgoing`, the first that is there of `client.key`,
			`id_ecdsa`, `id_ed25519`, `id_rsa` and `client.rsa` in the
			ssh home of the one who runs the tools, as their own ssh
			takes it; an ssh home a command names itself is not listed. <fingerprint> is that of the public
			file, as ssh-keygen gives it, and <short> the key itself in
			short, its first twelve and its last eight letters. <state>
			is `present`, or `absent` where no public key can be read at
			<file>: the other three read `-` then, and so does <public>.
			<public>, the last field, is the whole public line as one
			pastes it, nothing of it held back, its blanks written `_`:
			for a key of `add-to-git` the public key line of its file,
			for one of `trust-on-connect` the line of a known hosts file,
			the name of this host, the type and the key; for one of
			`add-to-authorized-keys` the public key line as it goes into
			an authorized keys file, with nothing added.
			The keys of `trusted` are the lines of this account's own
			authorized keys file (`.ssh/authorized_keys` in the home of the
			one who runs the tools) that hold a public key, in the order
			they stand, with the options ahead of the key left out: <key>
			is `trusted-<n>`, <n> counting from 1, <label> the comment of
			the line, else `Trusted Key <n>`, <group> is `trusted`, <state>
			is `present`, <file> is that file, and <public> the line as it
			stands, the type, the key and the comment. The file is only
			read, never changed. With none, the group has 0 keys and its
			<note> says that the file holds no public key, or is not there.

		--manager-keys-read <key>
			One of the console's own operations (see Notes). Prints one
			key by its name, as `--manager-keys-list` prints it: its
			`key` row, then, where it is `present`, the line as one
			pastes it, its blanks kept, and for `deploy` the repositories
			the rig keeps a list of. Public material only.
			`paste <line>`
			`register <project> <address>`
			For a key of `add-to-git` the line is the public key line of
			its file, whole. For one of `trust-on-connect` it is the line
			of a known hosts file: the name of this host, the type and
			the key. For a key of `trusted`, named `trusted-<n>` as the
			list names it, it is the line of the authorized keys file, the
			type, the key and the comment. No repository is asked
			anything. Exit 1, nothing printed, for a name that is no key.

		--manager-keys-generate <key>
			One of the console's own operations (see Notes). Makes the key the
			console's configuration wizard names, where there is none: a pair, the
			private file and its public file, in the place `--manager-keys-list`
			names it, which is `deploy` (the key the account uses for git, the one
			its ssh command names, else the deploy key of the account under its
			home, else the generated default), `generated` or `outgoing` (the key
			the deploy and remote tools connect out with). It is ed25519 with no
			passphrase, its comment `<account>@<host>`, made by ssh-keygen under a
			name of its own and put in place by a rename; the ssh home is made with
			mode 700 where it is not there, the private file has mode 600 and the
			public file 644. The ssh host keys of the server, `trust-on-connect`,
			are the system's and are never made here. Prints one row on stdout,
			TAB-separated, a value's whitespace `_`:
			`generated <key> <private file> <type> <fingerprint>`
			Nothing of the private key is printed. Exit 1, with one error line,
			nothing made: for a name that is no key, a host key, a word that is no
			name, a wrong count of words, and where a file of the key is there
			already (`--manager-keys-regenerate` replaces one).

		--manager-keys-regenerate <key>
			One of the console's own operations (see Notes). Replaces a key that
			stands with a new one, in the same files, as `--manager-keys-generate`
			makes it: the new pair is made under a name of its own beside the old
			one, which stays whole until the new one is made, and is then put in
			its place by a rename. Whoever trusts the old public key trusts nothing
			of the new one. Prints one row on stdout like that of generate, its
			first field `regenerated`. Exit 1, with one error line, nothing
			changed: for the refusals of generate, and where the key has no private
			file of its own, a plain file, or a link stands in its place.

		--manager-keys-delete <key>
			One of the console's own operations (see Notes). Removes a key: its
			private file and its public file, as `--manager-keys-list` names them.
			Prints one row on stdout like that of generate, its first field
			`deleted`, its type and fingerprint `-`. Exit 1, with one error line,
			nothing removed: for the refusals of generate but a file being there,
			and where no file of the key is there.

		--manager-manual-read <user|maintainer> [<project>]
			One of the console's own operations (see Notes). Gives the
			manuals of the projects of this workspace, which the root
			`Manuals (Help)` of the console shows: `user` is the README.md
			of a project, `maintainer` its MAGIC.md. With the kind alone it
			lists, one a line on stdout, TAB-separated, the projects that
			have that file: `<project> <file>`, the project as the build
			sequence names it, in the order `ListDistroProjects
			--select-all` gives it, then the whole path of the file. With
			a project of that list it prints that file as it is. Exit 1,
			nothing printed, for a kind that is neither, a project that is
			none of the list or has no such file, and a second project. It
			only reads.

		--manager-place-list
			One of the console's own operations (see Notes). Lists the
			places of this machine: the workspaces and the directories
			the tooling knows by a name, as `--owner-workspace-list`
			prints them, by the same reader and in its order: the two
			built-in places, the places of this workspace, then those of
			each other workspace. It only reads: no registry and no file
			is written, and nothing is started. Prints one row for each
			place, TAB-separated, on stdout. An absent value reads `-`,
			and a value's own whitespace reads `_`, as in a registry.
			`place <place> <label> <kind> <ceiling> <path> <state> <here> <sessions>`
			<place> is the key of the place: its name, or
			<name>@<workspace> for a name that another workspace gives
			another path. It is what `--manager-place-read` takes.
			<label> is the words of the key, capitalised. <kind> is
			`workspace` or `directory`, <ceiling> `read-only` or
			`read-write`. <state> is measured at the call, on this host:
			`present` where <path> is a folder the user who runs the
			call can enter and read, `unreadable` where something is
			there that is not, `absent` where nothing is, `unknown`
			where no path is known, since the workspace that declares
			the place cannot be read. <here> is `yes` for the workspace
			the call runs in, and `no` for every other place. <sessions>
			is, for a workspace, how many sessions of this workspace's
			registry `spawned-sessions` have a run that names it, as
			that registry lies: it is not rebuilt here. It reads `-` for
			a directory, and where the registry is not there. A registry
			of places holds no host: a row of it is a path as it was
			resolved for the host that wrote it. So no host is printed,
			and a place is shown by what stands at its path here, now.

		--manager-place-read <place>
			One of the console's own operations (see Notes). Prints one
			place by its key: its `place` row as `--manager-place-list`
			has it, then what the registry holds of it beyond that row,
			then what stands at its path. It only reads, and starts
			nothing.
			`info <name> <value>`
			`stands <what> <name> <path>`
			`member <member> <kind> <home> <setup> <folder>`
			The `info` rows, in this order: `declared-by`, the project
			that declares the place, or `workspace` for a workspace's own
			row, `owner` for one `--owner-workspace-upsert` made,
			`built-in` for a built-in place; `workspace`, the root of the
			workspace that declares it; `registry`, the file that holds
			its row, `-` for a built-in place. A registry of places
			holds no more of a place: no host, nobody who registered it,
			no date. The `stands` rows are printed for a place whose
			<state> is `present`, and say what the tooling knows of at
			its path: `console`, each console script at its root, by its
			file name; `member-home`, each member whose home the machine
			keeps there; `team-data-root`, the team data root of this
			workspace where it lies in the place, under the name `-`.
			Nothing is looked for at a path that is not there, and of a
			file nothing is read but its name. The `member` rows come
			last, for a workspace: every member that belongs to it, by
			the machine's registry of members, whatever folders stand
			there. <kind> is the first word of its name. A member's home
			is a workspace, not a folder: the one its operations are run
			from, which is the workspace the machine's row names for a
			member that more than one workspace has, else the one it is
			linked from source in. <home> is the path of this place where
			this place is that workspace, and `elsewhere` where another
			is. <setup> is how the member is set
			up there, the link kind of its row, as
			`--manager-team-member-read` gives it; <folder> is where its
			skillset lies, a path whole. A folder of the place's own
			member set that no row of the registry names is shown too,
			its <setup> `not-in-registry` and its <home> `-`. Exit 1, nothing printed,
			with one error line, for a name that is no place, and where
			it is not given one name.

		--manager-place-command-list <place>
			One of the console's own operations (see Notes). Lists the
			commands of one place that is a workspace: the same its
			editor's palette gets. Each package of this console declares
			its workspace commands once, in its
			`sh-lib/config/workspace-commands.list`, a command a line: its name,
			its emoji part of it, how it runs, and the command, a TAB
			between them, `$MMDAPP` in it the root of the workspace. The
			tasks of the palette are made of the same lines, by
			`SourceTools.Make.VSCodeTasksFromWorkspaceCommands.include`.
			A workspace has the commands of the packages it has, picked
			as the tasks of its palette are: `myx.distro-source` always,
			another where its console at the root of the workspace is
			executable; in that order, each package's in its own order.
			The declarations read are those of this console's packages.
			It only reads, and starts nothing.
			`command <name> <package> <runs>`
			<name> is the command's name, whitespace in it `_`. <runs> is
			`output` for one that runs unattended, whose output is
			followed, and `terminal` for one that runs with the whole
			terminal, a console. A directory, and a workspace that is not
			there, has no command: nothing is printed, status 0. Exit 1,
			nothing printed, with one error line, for a name that is no
			place, and where it is not given one name.

		--manager-place-command-run <place> <command>
			One of the console's own operations (see Notes). Runs one
			command of a workspace, one `--manager-place-command-list`
			lists: <command> is its name as that list prints it, or with
			its blanks. It runs the declared command, the root of the
			workspace put for `$MMDAPP`, by `/bin/sh -c`, as the
			editor's palette runs a task, in the root of that workspace,
			on the input and the output of this call, with none of this
			console's variables: only HOME, USER, LOGNAME, SHELL, PATH,
			TERM and LANG are passed on. It writes nothing of its own;
			what is printed is the command's own, and the status is the
			command's. Exit 1, nothing run, with one error line, for a
			name that is no place, for a place that is no workspace that
			is there, for a command that is none of that workspace's, and
			where it is not given two words.

		--manager-routine-list
			One of the console's own operations (see Notes). Lists the
			routines the members carry: every `*.routine.md` file of
			every member's folder, those of a member of another workspace
			of this machine among them. No registry and no index holds
			the routines, so it reads the files at each call; it writes
			nothing. Prints rows of TAB-separated fields on stdout, the
			first naming the row. An absent value reads `-`, and a
			value's own whitespace reads `_`.
			`routine <selector> <owner> <start> <executors> <session> <arguments> <title> <reason> <needs> <state> <last-run>`
			One row a routine, by <owner>, then by <selector>. <selector>
			is the file's name, the selector
			`--magic-spawn-session --routine <selector>`
			takes. <owner> is the member whose folder holds the file.
			<start> says whether that operation would start the routine
			with no member named, by the checks it makes itself. It is
			`startable` where the file names its executors as a plain
			comma-separated list of existing members. It is
			`not-startable` where the executors are `magic-team` or `*`,
			which is any member, or hold a name that is no member of any
			workspace of this machine, or a member whose `SKILL.md` says
			`status: reference-only`, an identity record, which is never
			started, or `magic-team` in a list beside members, the team
			itself, which is no member and is never started, or where
			more than one routine file answers to the selector. It is
			`broken` where the file
			fails the routine contract: no frontmatter block, no
			`requires-session-kind:` naming a session kind of the
			tooling, or no executors or maintainers. <reason> says in words why a
			routine is not `startable`, and is `-` for one that is.
			<executors> is the frontmatter value, `-` for a `broken`
			file. <session> is `coworking` for a routine whose
			`requires-session-kind:` is `coworking`, and `-` for the
			other kind.
			<arguments> is `-`, its place kept: no routine file says, in
			a form a program reads, whether the routine takes arguments.
			<title> is the file's own title line. <needs>, the last
			field, says what a start of a routine that is `not-startable`
			needs, where that is all it lacks. It is `members` where the
			one cause is that the executors are any member: the same
			operation then starts the routine with members named after
			the selector,
			`--magic-spawn-session --routine <selector> <team-member>...`
			and checks every name before it starts anyone. It is `-` for
			every other row, so a console tells such a routine by this
			field and not by the words of <reason>. <state> and
			<last-run>, the last two fields, are the Dispatcher's own
			(`--routine-stats`, the one reader of its store of the runs,
			called as it is by `--manager-stats-routines`) joined to the
			routine by its file name: <state> is `running` where a run of
			it runs now, else how its last run ended with `spawn-` taken
			off (`succeeded`, `failed`, `ended-without-close`), `never`
			for a routine with no run; <last-run> is when that run
			started, `YYYY-MM-DD_HH:MM`, `-` for none. This operation
			computes neither. With no routine file at all, a note on
			stderr and no row.

		--manager-stats-tokens --by day|member|routine|preset|credential [--since <date>] [--until <date>] [--member <m>] [--routine <r>] [--preset <p>] [--credential <c>]
			One of the console's own operations (see Notes). The tokens of the
			runs of this workspace summed by one key: it calls the Dispatcher's
			`--token-stats` with these arguments, as they come, and prints
			what it prints, with its status. It has no logic of its own and
			writes nothing but what the Dispatcher's reader does, which
			brings its index of the runs (`.local/agents/stats`) up to date
			first. `--by` is the key: `day`, `member`, `routine`, `preset`
			or `credential`, and `--since` and `--until` (a day,
			YYYY-MM-DD) and the other four narrow the runs it sums. One
			row a key, TAB-separated, on stdout, ordered by key:
			`tokens <key> <runs> <in> <cache-read> <cache-write> <out>`
			A run with no routine, preset or credential is under `-`. The
			views of the tokens in the console read this. Exit 1, with its
			error line, for a `--by` that is none, a date that is none or an
			option it does not know.

		--manager-stats-routines [<routine>]
			One of the console's own operations (see Notes). The routines of
			the runs of this workspace: it calls the Dispatcher's
			`--routine-stats`, with its argument, and prints what it prints,
			with its status. It has no logic of its own. One row a routine,
			TAB-separated, on stdout, the one routine asked for or every one:
			`routine <routine> <runs> <succeeded> <failed> <running> <last-run> <last-status> <last-succeeded> <in> <cache-read> <cache-write> <out> <members>`
			A run with no routine is under `-`. Exit 1, with a note on
			stderr and no row, for a routine with no run recorded.

		--manager-pending-reply-read --id <pending-id>
			One of the console's own operations (see Notes). What can be
			done with one pending question, as TAB-separated rows, an
			absent value `-`. It changes nothing and reads no thread.
			First `question`, <pending-id>, its status, kind, answer form,
			asker, addressee, the member an answer from the console
			stands as, `answer` where words alone are its answer or
			`words` where words may go with an answer, the word --reject
			gives, `yes` where it can be dismissed, and the web link of
			its message. Then, while it is open, one row for each answer
			it takes: `answer`, the number of the option, the word, what
			becomes of it (`settles`; `up-the-chain`, an allow of what
			magic-coordinator does not hold; `not-taken`, a verdict that is the
			human-owner's own), and the option's label. Refused, rc 1,
			where the system gives the console no account to stand as.

		--manager-pending-reply-answer --id <pending-id> (--answer <word|number|text>|--reject) [--text <words>]
			One of the console's own operations (see Notes). Answers one
			open question of any member, through the one answer operation
			(--member-escalation-answer): the same apply, close and
			confirmation as an answer read from its thread. --answer takes
			a word of the kind, the number of an option, or, for a plain
			question, the words that are its answer; --reject gives the
			kind's own negative answer; --text adds words to an answer.
			The answer stands as the member the read names, the person at
			the console, `user-<account>` (F6.10), and is recorded and
			applied under that name: `answered-by`, the grant's `by` and
			the line in the thread. What an allow may reach is bounded as
			ever by what magic-coordinator holds: an allow of what it does
			not hold goes up the chain, and a review, a held change and a
			proposal are refused. The record keeps
			`answered-session: console:<account>`, and one line by the
			team bot in the question's thread says it was answered from
			the console, by which account and with what; a line not
			posted is a warning, and the answer stands. Prints one row:
			`answered` or `rejected`, <pending-id>, the verdict, the
			member it stands as, `console:<account>`, its words; or
			`up-the-chain`, <pending-id>, who it is addressed to now, the
			member, `console:<account>`, the reason. Refused, rc 1, one
			line, nothing changed: no such question, one not pending or
			answered already, an answer the kind does not have, a reject
			of a kind with no negative answer, and the console where the
			system gives it no account to stand as: nothing is recorded
			under a made-up name.

		--manager-pending-reply-dismiss --id <pending-id> [--reason <text>]
			One of the console's own operations (see Notes). Closes one
			open question of any member with no answer, as its asker's own
			withdraw does (--member-pending-reply-settle --withdraw): the
			record closes as withdrawn, `withdrawn-by: console:<account>`,
			with the reason; it answers, grants and decides nothing; one
			line by the team bot in its thread says it was dismissed from
			the console and by which account. Prints one row: `dismissed`,
			<pending-id>, `console:<account>`, the reason. Refused, rc 1,
			one line: no such question, or one not pending.

		--manager-scope-list
			One of the console's own operations (see Notes). Lists the scopes of
			settings this workspace keeps, which the console's `Scope Settings`
			shows as folders: every --config item of every installed subsystem.
			One scope is one file of KEY=VALUE lines, read and written by the one
			setting reader of the local tools. They are `common:workspace`, the
			workspace's own settings for everybody (--system-config-option);
			`common:user-<account>`, the settings of the account that runs the
			call in this workspace (--custom-config-option), those of no other
			account; `remote:<id>`, a profile of the remote tools, where that
			subsystem is installed (--remote-config-option); and `agents:<name>`,
			a scope of the agents, which is each member's, the team's, each
			routine's and each preset's, a `preset-<name>` block too
			(--agents-config-option). A scope is listed where its file is. There
			is no scope of the deploy tools: they have no option scope. Prints one
			row each on stdout, TAB-separated, a value's whitespace `_`:
			`scope <id> <label> <keys> <clear> <delete> <file>`
			<label> is how a folder is named, `Agents: client-ndm`; <keys> how many
			keys the file holds; <clear> `yes` where there is a key to take out;
			<delete> `yes` for a scope of many, a remote profile or a scope of the
			agents, `no` for the two common scopes, which are one each.

		--manager-scope-read <scope-id>
			One of the console's own operations (see Notes). Prints one scope as
			`--manager-scope-list` prints it, its `scope` row, then one row for
			each key it holds, in the order of its file, each once:
			`key <name> <state> <value> <type> <description>`
			<state> is `set`, `secret-set` for a credential, or `missing` where
			the line holds nothing after the `=`; a comment, a line with no `=`
			and a blank are no key. <value> is the value as it stands, its
			whitespace written `_`, but a credential in its one form (the first
			quarter of its value, not less than 4 and not more than 20
			characters, then a `*` for every character after them) and a password
			inside a URL masked alone. <type> is `credential` or `setting`: which
			keys are credentials is the agents' plugin's to say, as for
			`--manager-config-digest`. <description> is the text of the catalogue
			of the owner setup for a key it describes, `-` for any other; it holds
			no value. Exit 1, with one error line that repeats nothing of what was
			given, for an id that is none of the scopes listed.

		--manager-scope-reveal <scope-id> <key>
			One of the console's own operations (see Notes). Prints the value of
			one key of one scope whole, alone, as the setting reader gives it: the
			one operation here that does, asked by the console when a form is told
			to reveal a credential. The mask is no security boundary, since a shell
			read shows the value as well. Nothing is printed for a key the scope
			does not hold. Exit 1 for an id that is none of the scopes and for a
			name that is no setting's.

		--manager-scope-set <scope-id> <key>
			One of the console's own operations (see Notes). Saves one key of one
			scope: THE VALUE IS THE STANDARD INPUT, one line, and never an
			argument. It is written by the setting reader of the scope; for a
			scope of the agents by the dispatcher's own --agents-config-option,
			so the write checks of a preset and of the tiers are asked as for any
			writer, and a write they refuse is refused here. Every other line of
			the file and its mode stay. Prints one row on stdout:
			`saved <scope-id> <key> <value>`
			<value> as it was read back after the write, in the form
			`--manager-scope-read` prints it, so a credential in its one form.
			Exit 1, with one error line and nothing saved: for an id that is none
			of the scopes, a key that is no setting's name (a letter or `_`, then
			letters, digits and `_`), a wrong count of words, an empty value (a key
			is taken out with `--manager-scope-unset`), a value of more than one
			line, and a write the reader or a check refuses.

		--manager-scope-unset <scope-id> <key>
			One of the console's own operations (see Notes). Takes one key out of
			one scope, by the same writer as `--manager-scope-set`. Prints one row
			on stdout: `removed <scope-id> <key>`. Exit 1, with one error line and
			nothing removed: for an id that is none of the scopes, a name that is
			no setting's, a key the scope does not hold, and a removal that a
			check refuses or that did not take.

		--manager-scope-clear <scope-id>
			One of the console's own operations (see Notes). Takes every key out
			of one scope, one by one as `--manager-scope-unset` does; the file,
			its comments and the other scopes stay. Prints one row on stdout:
			`cleared <scope-id> <how many>`. Exit 1, with one error line, where a
			key could not be taken out, saying how many were, and for an id that
			is none of the scopes. The console offers it for any scope.

		--manager-scope-delete <scope-id>
			One of the console's own operations (see Notes). Deletes one scope, its
			file, where its subsystem has many: a profile of the remote tools or a
			scope of the agents. The workspace's own settings and the account's own
			are one each and are cleared, never deleted. Prints one row on stdout:
			`deleted <scope-id>`. Exit 1, with one error line and nothing deleted,
			for an id that is none of the scopes and for a scope of the two common.
			There is no reset: no subsystem keeps defaults to reset a scope to.

		--manager-wizard-read <cli-service|git-settings>
			One of the console's own operations (see Notes). Gives what the form
			of a configuration wizard needs and the form cannot know: its choices,
			and what stands now. Prints rows on stdout, TAB-separated, a value's
			whitespace `_`, a credential in its one form:
			`option <field> <value> <label>`
			`current <key> <state> <value>`
			For `cli-service`: the options `cli-service` (the nine services of a
			preset), `effort` (the five efforts) and `preset` (each preset block
			there is); `credential <service> <key>` for the credentials each
			service reads; `preset <name> <key> <state> <value>` for each key a
			preset holds of its service, its model or macro, its effort, its
			extend, and its credentials; `team <key> <state> <value>` for the
			team's three tiers and its CLI service. For `git-settings`: `current`
			rows for the global user.name, user.email and the key git connects
			with (the `-i` of core.sshCommand, as `--manager-keys-list` finds it),
			and an `option ssh-key <private file> <label>` for each private key
			of the account that is there. Exit 1 for a name that is no wizard.

		--manager-wizard-apply cli-service --preset <name>
			One of the console's own operations (see Notes). Applies the answers
			of the CLI service's wizard: a preset and the team's three tiers. THE
			ANSWERS ARE THE STANDARD INPUT, a line each, `<key> <TAB> <value>`, and
			never an argument. The keys it writes are PRESET_CLI_SERVICE,
			PRESET_MODEL_OR_MACRO and PRESET_EFFORT of the preset <name> (a block
			`preset-<name>`, made by the first write), the credentials of its CLI
			service, and, in the team's scope, SPAWN_TIER_LOW, SPAWN_TIER_NORMAL,
			SPAWN_TIER_HIGH (`<preset>[:<effort>]`) and SPAWN_CLI_SERVICE, which is
			written only where no tier is set. They are applied in the order the
			checks need, the service first and the tiers after the preset, each by
			the dispatcher's own --agents-config-option, so its write checks are
			asked; an empty value takes the key out. Prints one row for each:
			`<set|removed|unchanged> <scope> <key>`
			Applying stops at the first write that is refused, with one error line
			that repeats no value, the rows above it having been applied. A line
			that names a key the wizard does not write, a key given twice and a
			preset name that is not lower-case refuse the whole call before
			anything is written.

		--manager-wizard-apply git-settings
			One of the console's own operations (see Notes). Applies the answers
			of the git wizard to the global git settings of the account that runs
			the call, and to no other setting. THE ANSWERS ARE THE STANDARD INPUT, a
			line each, `<field> <TAB> <value>`: `user.name`, `user.email` and
			`ssh-key`, the whole path of a private key file, which becomes the
			`-i` of core.sshCommand (`ssh -i <key> -o IdentitiesOnly=yes`). A field
			not given, or given empty, is left as it is. Prints one row for each
			written: `set git <field>`. Exit 1, with one error line and nothing
			applied, for a field that is none of these, a field given twice, a
			control character, an email that is no address, and a key path that is
			not a whole path of a plain private file or holds a character a command
			line would read.

		--manager-session-list [--active]
			One of the console's own operations (see Notes). Lists the
			coworking sessions run from this workspace, each with its runs.
			It rebuilds the registries `spawned-sessions` and
			`pending-replies` first and measures which runs are alive, in
			the same call, and writes nothing else. Prints rows of
			TAB-separated fields on stdout, the first naming the row. An
			absent value reads `-`, and a value's own whitespace reads `_`,
			as in a registry: a date reads `2026-10-12_16:57_+0300`.
			`session <session-id> <name> <state> <started-at> <state-at> <run-count> <state-tally> <session-state> <session-state-at> <control-thread> <tokens>`
			`run <session-id> <spawn-id> <member> <status> <live> <state> <started-at> <resolved-at> <host> <workspace> <activity>`
			`counters <sessions-running> <sessions-paused> <agents-working> <agents-waiting> <pending-answers> <load-average> <host>`
			A session row is followed by its runs, the earliest started
			first. Sessions come by start date, the newest first, one with
			no date last. The one `counters` row is the last line, always.
			<name> is the first `session-comment` of the session's runs. A
			row with no session id is a session under its tracking name.
			A session's <state> is `running` while a run of it has a live
			process, else `waiting` while an ask of it or of one of its
			runs is open, else `unknown-foreign` with an open record of
			another host, else `unclosed` with any open record, else
			`finished`. <state-at> is the date its last run closed, for a
			`finished` session only. <state-tally> reads
			`running=1,finished=2`. <session-state> and <session-state-at>
			are the state the control thread of the session stored for it
			and when, as `spawned-sessions` holds them after this rebuild:
			`-` for a session that has none. That state stands beside
			<state>, which is derived at this call, and where the two
			differ each is shown as it is. <control-thread> is measured at
			this call and stored nowhere: `alive` while the process that
			the pid file or the lock of the session names is still that
			process, `gone` where one of the two is there and names no
			such process, `none` where neither is there. <tokens> is the
			tokens of the session so far, one number: in, cache read,
			cache write and out of each of its runs, all added, as the
			store of each run holds them. A run whose figures are not
			known is left out, and the number then ends with `+`; `-`
			where none is known. A reader takes a row that ends before
			<tokens> as one of an earlier form.
			A run's <live> and <state> are those
			`ListAgents` shows. <activity> of a live run is `waiting`
			inside a `Wait` call and `working` otherwise. `--active` keeps
			every session that is not finished and can be acted on from
			this host: those whose <state> is `running`, `waiting` or
			`unclosed`, each with all its runs, as without it. It leaves
			out the `finished` ones, and the `unknown-foreign`, which are
			another host's: nothing can be done with those from here. The
			counters count the whole workspace
			either way. <sessions-paused> is 0 until sessions can be
			paused. <pending-answers> is the open asks, <load-average> the
			host's one-minute figure, and <host> the full name of the
			host this call ran on, for a reader's eye: what `hostname -f`
			gives where that resolves, else the plain `hostname`, else
			the short name, `unknown` where the host says none. It is
			never empty. The <host> of a `run` row, like the `host` of a
			record, stays the short name. The full name is asked of the
			host once and kept for a day in
			`$HOME/.agents/magic-team/host-full-name`, so a call reads
			one line there; a lookup that has not answered within a
			second is ended, and what stands in its place is kept for an
			hour, so a slow resolver holds one call an hour by a second
			and no other. A
			reader takes a row that ends before <host> as one of an earlier
			form. With no session store, a note on
			stderr and the `counters` row alone. Exit 1, nothing printed,
			where a registry cannot be rebuilt.

		--manager-session-read --session-id <id> [--run]
			One of the console's own operations (see Notes). Shows one
			coworking session run from this workspace, or one run of it,
			in full. <id> is the id of a session, or a run's own id: a
			session's id shows every run of it, and the own id of a run
			that joined a session shows that run alone, under the rows
			of its session. The founder's own id is its session's:
			`--run` takes <id> as a run's own, which shows the founder
			alone. It reads the registries `spawned-sessions` and
			`pending-replies` as they lie, and the records and stores of
			that one session, never another's. A registry is rebuilt
			first, in the same call, only where it is missing or does
			not hold its store as the store is now, by the names there
			and never by a time: a row for every record of every
			sandbox folder, a row of <id>, a row for every ask, and of
			each ask of the session the status its record has now. So a
			member that joined the session since is in the next read.
			What a record of the session says, its status among it, is
			read from the record at every call. Which runs are alive is
			measured in the same call. It writes nothing else. Prints
			rows of TAB-separated fields on stdout, the first naming the
			row. An absent value reads `-`.
			`session <session-id> <name> <state> <started-at> <state-at> <run-count> <state-tally> <session-state> <session-state-at> <control-thread> <tokens>`
			`dispatch <session-id> <founder> <member> <routine> <dispatch-item> <session-thread> <tracking-thread> <description>`
			`control <session-id> <session-state> <session-state-at> <control-thread> <control-pid>`
			`tokens <session-id> <tokens-in> <tokens-cache-read> <tokens-cache-write> <tokens-out> <runs-summed> <runs-running> <total> <runs-unknown>`
			`run <session-id> <spawn-id> <member> <status> <live> <state> <started-at> <resolved-at> <host> <workspace> <activity>`
			`header <spawn-id> <name> <value>`
			`store <spawn-id> <store> <model> <tokens-in> <tokens-cache-read> <tokens-cache-write> <tokens-out> <open-asks> <marks> <milestone-at> <milestone> <wait-sources> <dismissed-by> <session-log> <transcript>`
			The `session` row comes first, then `dispatch`, then
			`control`, then `tokens`, then each
			run: its `run` row, a `header` row for each header of its
			record, and its `store` row. The runs come the earliest
			started first. The `session` and `run` rows are those of
			--manager-session-list, field for field. `dispatch` is what
			the session was started for, from its founder's record: its
			member, its routine, its dispatch item and its description.
			<founder> is `record`, or `no-record` for a session a client
			founded, whose founder left none: the four then read `-`.
			<tracking-thread> is the record's `agent-log-thread`.
			`control` is the control thread of the session: the three
			last fields of its `session` row, and <control-pid>, the
			process <control-thread> is said of, `-` where that reads
			`none`. <session-state> is read here from the folder of the
			session at every call, with the records of the session.
			`tokens` is the total of the session, over every run of it
			whichever runs are shown: the four figures of the `store`
			row of each run, added. <runs-summed> is how many runs that
			is, <runs-running> how many of those run still, and
			<runs-unknown> how many are left out, their figures not
			known: a run with no store, or with no four numbers there.
			<total> is `final` for a session whose <state> is
			`finished`, and `so-far` for any other. With no run summed
			the four figures read `-`. A
			`header` row is one header of the run's record as it stands,
			its `cli` among them. `store` is the run's own store. <store>
			is `store`, or `no-store` for a run with no folder of its
			own, where every field after it but <open-asks> reads `-`.
			<open-asks> is the ids of that run's asks still waiting for
			an answer, comma-joined. <marks> is the marks its store
			holds, comma-joined, of `dismissed`, `dismissed.handback`,
			`ended` and `review-expired`, and <dismissed-by> is who
			dismissed it. <milestone-at> and <milestone> are its last
			milestone, <wait-sources> what its stored wait waits on, and
			<session-log> and <transcript> the paths of those files
			where they are there. A run with no spawn id has its `run`
			row alone. <description>, <value>, <milestone>,
			<wait-sources>, <dismissed-by> and the two paths are free
			text, written exact, with their spaces: a TAB reads `\t`, a
			line break `\n`, a carriage return `\r` and a backslash
			`\\`. Every other field is one word, a value's own
			whitespace written `_`, as in a registry. <activity> of a
			live run is `waiting` inside a `Wait` call and `working`
			otherwise: a tool call is not told from thinking, since no
			file of a run says which. Exit 1, nothing printed, with one
			error line, where no record carries <id>, or a registry
			cannot be rebuilt.

		--manager-session-transcript-read --session-id <id> [--run] [--tail <lines>] [--log]
			One of the console's own operations (see Notes). Shows what
			one run did, or every run of one coworking session: the
			lines the tracking thread of the session shows, read from
			where they last, each run's transcript. <id> and `--run` are
			those of --manager-session-read, and so are the registries
			it reads and when it rebuilds one. It reads the transcripts
			and the session logs of that one session, never another's,
			and writes nothing else. Prints rows of TAB-separated fields
			on stdout, the first naming the row. An absent value reads
			`-`.
			`source <spawn-id> <member> <kind> <path>`
			`log <spawn-id> <member> <text>`
			`feed <time> <spawn-id> <member> <subject> <regarding> <text>`
			One `source` row for each run comes first, the earliest
			started run first: where that run's lines are read from.
			<kind> is `transcript`, or `session-log` for a run with no
			transcript, whose session log is given in its place, or
			`none` for a run with neither, which has no further row.
			Then the `log` rows, run by run, the lines of each session
			log in their order. Then the `feed` rows of every run
			together, in the order of their times, the newest last. A
			`feed` row is one operation as the tracking thread shows it,
			with its emoji: a tool call with its outcome, a message out,
			the result of a wait, a round with its tokens, the start,
			the model and the end. <time> is its moment, ISO UTC,
			<member> the member whose run it is, <subject> the box it
			stands in in the thread, `member`, `run`, `session` or
			`system`, and <regarding> who that box names. Its <text> is
			one line: it holds no TAB and no line break, a token-like
			value in it reads `[redacted]`, and its marks are Slack's, a
			name between `*` and a code between back quotes. `--tail` is
			how many lines of each run are read, from its end, 200 where
			not given. Of a transcript, read over all its parts, at
			least that many: it never starts in the middle of a body, so
			it starts at the head line of the operation its first line
			belongs to. For a session whose runs are cut so, the `feed`
			rows start at the latest of the moments from which each cut
			run's lines are held, so no run is shown with a gap. `--log`
			gives the raw session log of every run, and no `feed` row:
			<kind> is then `session-log` or `none`. A `log` row's <text>
			is one line of the log, a token-like value in it
			`[redacted]`, written exact: a TAB reads `\t`, a carriage
			return `\r` and a backslash `\\`. <path> is written so too.
			Exit 1, nothing printed, with one error line, where no
			record carries <id>, or a registry cannot be rebuilt.

		--manager-session-checklist-read --session-id <id> <member>
			One of the console's own operations (see Notes). Shows the
			checklist one member keeps in one coworking session: the
			file <member>.checklist.md that the CheckList tool writes in
			the place of the session, which is the sandbox root of the
			spawn that founded the session where a spawn founded it,
			else the folder sessions/<id>. Prints that file as it
			stands on stdout, Markdown, one line an item, `- [x]` done,
			`- [ ]` not yet, the item in progress followed by its
			activeForm. Nothing is printed, and the status is 0, for a
			member that kept no list there. It reads that one file and
			writes nothing. <id> and <member> are bare names. Exit 1,
			nothing printed, with one error line, where either is
			missing or is no bare name.

		--manager-session-kill --session-id <id> [--run] [--plan]
			One of the console's own operations (see Notes). Ends runs of
			this workspace on this host the hard way: no closure of a
			routine runs and no agent is asked anything. It asks for no
			confirmation either: that is its caller's. <id> is taken as
			--manager-session-read takes it: a session's id ends every
			live run of it, the own id of a run that joined a session
			ends that run alone, and `--run` takes <id> as a run's own,
			which ends the founder alone. The registry `spawned-sessions`
			is rebuilt first, always, so that a run that joined the
			session a moment ago is among them. For each run it ends, the
			ending is recorded first, under the name the console's user
			has in the operating system: `killed-by` and `killed-at` on
			the run's record, one `dismissed` line with the reason
			`manager-kill` in the Decisions of its own dispatch item, and
			one ENDING line in its transcript. Then TERM goes to the
			processes that run as that run and to every process they
			started, to any depth: its helper servers, a tool command,
			the child of that command that hangs. Each is signalled by
			its own pid, never a process group. The run's own supervising
			shell is never signalled, so it closes the record; nor is a
			run of another spawn that the run started, or the shell that
			supervises that one. KILL goes to what is still there two
			seconds later. What an earlier stop or kill of the run
			signalled and left, kept in the run's store as `stop.left`, is
			ended with it, also where the run itself is alive no more. A
			process that left the run's tree before any of them, its
			starter gone, is not found. A killed run is not started again
			by the handback retry. Prints one row for each run <id> names,
			TAB-separated, on stdout, in the order of the list:
			`kill <session-id> <spawn-id> <member> <outcome> <status> <pids> <item>`
			<outcome> is `ended` where the run and what it started ended
			on TERM, `killed` where any of them took KILL, and `not-ended`
			where a process is still there after both. For a run that was
			not signalled it is the run's <live> as
			`--manager-session-list` gives it: `no-process`, `other-host`,
			`no-spawn-id` or `host-unrecorded`. <status> is the status of
			the run's record as it stood, <pids> the processes that were
			signalled, comma-separated, and <item> the dispatch item the
			ending was recorded on; an absent value reads `-`. Where no
			run <id> names is alive: its rows, a note on stderr, and exit
			0. Exit 1, nothing printed and nothing signalled, with one
			error line, where no record carries <id>, or the registry
			cannot be rebuilt; exit 1 after its rows where a run could not
			be ended. Who carries it out: where the control thread of the
			session lives, the thread does. This call puts a request into
			`control/request` of the session's folder, wakes the thread
			with USR1, waits for its outcome in `control/outcome`, and
			prints the rows and notes the thread wrote there. Where no
			thread lives, or it does not take the request within
			SESSION_CONTROL_REQUEST_SECONDS (default 5), this call takes
			its request back and carries the kill out itself, as before.
			One line on stderr says who carried it out, and why where
			this call did.
			THE KILL OF A WHOLE SESSION FINISHES IT, whatever state it is
			in, and a session with nothing alive is no refusal. After the
			`kill` rows, every question that still waits and was asked by
			the session or a run of it is dismissed, by the console's own
			dismissal (`--manager-pending-reply-dismiss`), with the reason
			that the session was killed from the console, and by whom.
			Then every record of it that is still open, with no process
			behind it and no supervising shell alive to close it, is
			closed as a run that ended without its close, its dispatch
			item with it, marked `killed-by` and `killed-at`; a record
			whose supervising shell lives is left to that shell, after a
			wait of five seconds at most. A run of another host is not
			touched. A run whose record has no `spawn-id:` header is the
			run of the record that bears its session's name: it is found
			and closed so, where nothing runs as it. Where a run's record
			cannot be found, its `close` row is `not-closed`, and a
			session that still reads `unclosed` after the call is said so
			by an error line on stderr and exit 1 (`--plan` never fails).
			The rows that say so follow the `kill` rows:
			`dismiss <session-id> <pending-id> <asker> <outcome>`
			`close <session-id> <spawn-id> <member> <outcome> <item>`
			`finish <session-id> <ended> <dismissed> <closed> <state>`
			<asker> is the id that asked, a run's own or the session's.
			<outcome> of a `dismiss` row is `dismissed`, or
			`not-dismissed` where the dismissal was refused; of a `close`
			row `closed`, `not-closed`, or `left` for a record its
			supervising shell still closes. The one `finish` row is the
			last line and sums it: the runs that were ended, the
			questions dismissed, the records closed, and the <state> the
			session reads now, as `--manager-session-list` gives it. A
			second kill of the same session, and the kill of a session
			that is finished with nothing waiting, print that row with
			zeros, exit 0. With `--run`, or the own id of a run that
			joined a session, one run is ended as before, the questions
			that very run asked are dismissed once it is ended, no record
			is closed by this call, and no `finish` row is printed.
			`--plan` ends nothing and does nothing: it prints the same
			rows as what a kill would do, a run that would be ended with
			the <outcome> `would-end` and its processes, `would-dismiss`,
			`would-close`, and in the `finish` row the three counts of
			what would be done and the state the session reads now.

		--manager-session-effort <session-id> <low|normal|high>
			One of the console's own operations (see Notes). Changes the
			effort a running session asks of its model, while it runs. It
			writes one line, low, normal or high, to `effort` in the store
			of the session or of the run that <session-id> names, under
			`.local/agents/sessions/`; it signals nothing, and no agent is
			asked anything. A harness run reads that file before every
			request: the run's own store first, else the store of its
			coworking session. `normal` is the model's default effort, so
			none is sent. An effort asked before the run's first request is
			its starting one. CHANGING EFFORT IN THE MIDDLE OF A CONVERSATION
			DISCARDS THE INPUT TOKEN CACHE of that session, and the run says
			so when it reads the change: one `input cache` line in its log,
			naming the old effort and the new, and the next request pays its
			whole prompt again. The other way, a model that takes its effort
			with each message and keeps the cached prefix when it is sent
			in a system message, needs a measured trial against the real API
			with a key and is not built: this change is always the one
			that discards the cache. A native client's session reads no such
			file. Prints one row, TAB-separated: `effort`, the id, the effort
			saved, the path of the file. Exit 1, nothing saved, with one error
			line, where the id is no bare name or names no store of this
			workspace, or the effort is none of the three.

		--manager-session-control-start (--session-id <id>|--all)
			One of the console's own operations (see Notes). Starts the
			control thread of a coworking session of this workspace where
			that thread does not live: the tooling's own process that
			watches the runs of one session on this host and keeps its
			state, and no agent. It ends no process and asks nobody
			anything. <id> is taken as --manager-session-read takes it: a
			session's id, or the own id of a run, which names the session
			that run belongs to. A session needs a thread while it is not
			finished: a run of it is alive on this host, or the record of
			a run of this host is still open. A finished session needs
			none, and neither does one that a start its caller waits on
			opened. One whose open records are all runs of another host,
			or name no host or no run, cannot be watched from here. A
			thread that lives is left alone. Where a session named by
			`--session-id` needs none, the pid file and the lock that a
			thread which died left in its `control/` are removed, unless
			one of them names a thread that lives: the session then reads
			as one that has no thread. `--all` is the check now: it
			reads every session of the workspace and starts the thread of
			each that needs one and has none alive. The advance lock take
			and each iteration of the main loop make that same check. So
			that a thread which ends at once is not started over and over,
			the check leaves a session alone for five minutes after the
			last line of the log of its thread was written; a start by
			`--session-id` is made at once. The registry
			`spawned-sessions` is rebuilt first, always. A thread is
			started detached: a process group of its own, a hangup
			ignored, its output in `control/log` of the session's folder,
			`.local/agents/sessions/<session-id>/`. The operation then
			waits until each thread it started holds the lock of its
			session, which takes a second or so, ten seconds at most for
			all of them. Prints one row, TAB-separated, on stdout, for the
			session <id> names, and with `--all` for each session that
			needed a thread and had none alive:
			`control <session-id> <outcome> <pid> <reason>`
			<outcome> is `started` where a thread was started and holds
			its session, `alive` where one lives already and nothing was
			started, `not-needed` for a session that needs none, and
			`not-started` where one was needed and none could be started,
			or, with `--all`, where the five minutes leave the session
			alone. <pid> is the process of the thread. <reason> says in
			words why none was started, or what became of one that was: a
			thread that is refused at its start says why in its log, and
			that is the reason given. An absent value reads `-`. <reason>
			is free text, written exact, with its spaces: a TAB reads `\t`
			and a backslash `\\`. With `--all` and no session that needs a
			thread: no row, a note on stderr, and exit 0. Exit 1, nothing
			printed and nothing started, with one error line, where no
			record carries <id>, or the registry cannot be rebuilt; exit 1
			after its rows where a thread could not be started, or where
			the session <id> names cannot be watched from here.

		--manager-session-message --session-id <id> [--to <participant>]...
			One of the console's own operations (see Notes). Leaves a message
			for a session, or for some of its participants. The message is the
			standard input, whole, and never an argument; an empty one, and one of
			blank lines, are refused. <id> is the id of a session or the own id of
			a run, as `--manager-session-read` takes it. Each `--to` names a
			participant of the session, a member that has a run in it, and only
			such a one; the same name given twice is one. With none the message is
			for the whole session. The message is from `user-<account>`, the
			account at the console as the system gives it, in the small letters,
			digits and hyphens a name takes (the authority rule of the console),
			never from magic-coordinator or any other member. It goes the way every
			message of a session goes, through its chat file. Where the session has
			a Slack thread, the message is left in the inbox of the session
			(`--intern-session-comms --inject`), as `<from> -> <to>:` and its body,
			and the communications writer sends it into the thread as the account,
			recording it first. Where it has none, the message is recorded in the
			chat file itself with the conversation `local`, nothing is posted, and
			the members of the session read it there (on a tool return and in
			their `Wait`, as they read the thread): a note on stderr says so. A
			session with neither a folder nor a thread has nowhere to keep it, and
			is refused. Prints one row of TAB-separated fields on stdout, and
			exits 1 with one error line and nothing on stdout, nothing left, for
			any refusal: an id no record carries, a name that is no participant, an
			option that is none, and a system that gives the console no account to
			send as.
			`message <session-id> <from> <to> <how> <kept>`
			<to> is `all` or the participants, comma-joined. <how> is `thread` for
			a message left for the writer, <kept> the name it was left under in the
			inbox, or `chat-file` for one recorded in the chat file, <kept> the
			number of its block.

		--manager-session-join --session-id <id>
			One of the console's own operations (see Notes). Brings
			magic-coordinator into a session, with a task to assess it, unblock it
			interactively and report. It is offered for a session that has
			finished, one that waits and one that is stuck, which are the states
			`finished`, `waiting` and `unclosed` of `--manager-session-list`: every
			participant has finished; a question of the session is open; a run of
			it is still open and no process carries it. A session that runs, whose
			participants work on it, one of another host, one that has no Slack
			thread and an id no record carries are refused, in one line and with
			nothing started. The join needs the thread of the session: the spawn
			proxy joins a member into a session by its thread and into none that
			has none, which is its own rule, so a workspace with no Slack joins
			nobody. The start is the spawn proxy's, unchanged, with `--session-id`: the
			coordinator joins that session, in its thread, and starts none, as a
			run that outlives the console, with a dispatch item. The task it starts
			on and the line its joining says in the thread are blocks of the
			tooling-note template (`Tasks`, `assess-session` and
			`assess-session-why`), filled: the name of the account at the console,
			the session and its name, and the state in words. Prints one row on
			stdout; exit 1 with one error line, nothing on stdout and nothing
			started, for a refusal.
			`join <session-id> <member> <dispatch-item>`
			<member> is `magic-coordinator`, <dispatch-item> the item the start made.

		--manager-spawn-member <team-member> [--from-stdin|--from-file <path>] [--session-name-or-comment <text>] [--description <text>]
			One of the console's own operations (see Notes). Starts one
			member with a prompt, in a new coworking session of its own,
			and does not wait for it. The prompt is stdin (default) or
			`--from-file`, never an argument, and an empty one is
			refused. The member gets it as its brief, behind the spawn
			brief block of the standing default routine, as
			`--magic-spawn-session --routine-default`
			puts it ahead of a task text. The start makes a `dispatch-*`
			item in board-running, and the run is detached: it outlives
			the console that started it.
			`--session-name-or-comment <text>` names the session, which
			shows by its id without one. `--description <text>` says
			what the start is for, kept on its records.
			<team-member> is a member of this workspace, or one set up
			only in another workspace of this machine, which the start
			brings as every start does. A name that is no member is
			refused. So is a member whose `SKILL.md` says
			`status: reference-only`, such as `human-owner`: an identity
			record is never started. So is `magic-team`: it is the team
			itself and no member of it, and the team is never started.
			The session runs as that member, whoever is at the console;
			the operating system runs it as the user that runs the
			console.
			**Hazard: no secret belongs in the prompt** -- the console
			puts a brief on the CLI's own command line, visible in `ps`
			on the host.
			Prints one row of TAB-separated fields on stdout. An absent
			value reads `-`, and a value's own whitespace reads `_`.
			`spawn <session-id> <member> <name> <dispatch-item>`
			<session-id> is the id of the new session and of the
			member's run in it, as `--manager-session-list` lists them.
			<name> is the session's name as its record keeps it.
			<dispatch-item> is the item the start made. Exit 1 with one
			error line, and nothing on stdout, where nothing was started.

		--manager-subsystem-list
			One of the console's own operations (see Notes). Lists the subsystems
			of the tool family, which the console's `Installed Subsystems` shows:
			`.local`, `system`, `deploy`, `source`, `remote` and `agents`, in that
			order. The operation is `.local`'s own, in its sh-lib, which the
			dispatcher of every subsystem's console offers. One is installed where
			its installed copy stands in `.local/myx` of the workspace. Prints one
			row each on stdout, TAB-separated:
			`subsystem <name> <state> <role> <install> <uninstall> <update>`
			<state> is `installed` or `missing`. <role> says why a subsystem has no
			command of its own, else `-`: `base` for `.local`, which installs the
			rest, `shared` for `system`, which comes with source and deploy, and
			`console` for the subsystem of the console that is asking, which is not
			uninstalled from itself. <install> is `yes` for a toolset that is
			missing, <uninstall> for a toolset that is installed and is not the
			console's own, and <update> for a toolset that is installed, the
			console's own too: its install again, which pulls its copy. Each other
			reads `no`. Exit 1, nothing printed, for a word after it.

		--manager-subsystem-run (install|uninstall|update) <subsystem>
			One of the console's own operations (see Notes). Runs one command of a
			subsystem that `--manager-subsystem-list` offers it: `install` of a
			toolset that is missing, which is `DistroLocalTools.fn.sh
			--install-distro-<subsystem>`, `uninstall` of one that is installed
			and is not the console's own, which is `DistroLocalTools.fn.sh
			--uninstall-distro-<subsystem>`, and `update` of one that is installed,
			the console's own too, which is its install again. `update all` takes
			no subsystem's name but `all`: it is `DistroLocalTools.fn.sh
			--upgrade-installed-tools`, which updates every installed tool, and
			`.local` and `system` with them. The output the local tools write is
			this operation's, and so is their exit status. Exit 1, with one error
			line and nothing run, for a command the list does not offer for that
			subsystem (`.local`, `system`, the console's own to uninstall, a toolset
			that is already installed or not installed), for a subsystem or a command
			that is none, and for a wrong count of words.

		--manager-team-data-read <store> [<folder> [<item>]] [--include-processed]
			One of the console's own operations (see Notes). Lists the
			items of one store of the team data, to browse them, or prints
			one item. It only reads: no git command is run, no registry is
			touched, and nothing outside the store is read. <store> is
			`board`, `audit`, `vault` or `inboxes`, a folder of the team data root; a
			<folder> is one folder of it, `-` the store itself; an <item>
			is a file of that folder, by its name; every name is a bare
			one. With <store> alone it prints the store's row, then a row
			for each of its folders, the board's in the order of its
			states and the others after them, the audit's newest month
			first, then the items that lie in the store itself; with a
			<folder>, the items of that folder; with an <item>, its text as
			it lies, by the reader every read of an item uses. Rows of
			TAB-separated fields on stdout, the first naming the row; a
			value's own whitespace reads `_`, an absent one `-`.
			`store <store> <state> <folders> <items>`
			`folder <store> <folder> <items>`
			`item <store> <folder> <name> <bytes> <stamp> <type> <status> <owner> <date>`
			<state> is `present` or `absent`, and an absent store has no
			other row. <stamp> is the `<YYYYMMDD>T<HHMM>` of the item's
			name where it has one: those items come first, the newest
			first, then the others by their names. <type>, <status>,
			<owner> and <date> are those fields of the item's front
			matter, its lines between a first line `---` and the next,
			where it gives them; nothing after it is read. Nothing deeper than a
			folder is listed. The folders of `inboxes` are the members'
			inboxes, `inboxes <member>` is the list of one member's inbox,
			and none of an inbox's own folders is ever shown: it lists the
			items that are not processed, and with `--include-processed` the
			processed ones too, and an item of it is read where a read finds
			it, by the same rule. An inbox is split (`incoming/` and `processed/`, the item's processed stamp, `processed-at`, deciding its folder); readers never see the folders. Exit 1 with one error line, and nothing on
			stdout, for a word that is no store, a name that is not bare,
			a folder or an item that is not there, and where no team data
			root is configured.

		--manager-team-member-list
			One of the console's own operations (see Notes). Lists the
			members of the team as this workspace knows them, one row a
			member. Its own members come first, in the order of their
			registry; then each member the machine knows that is set up
			only in another workspace, which is a member here too. It
			rebuilds the registry `team-members` first, reads
			`team-members-names` as it lies, and reads which runs are
			alive through `--manager-session-list`, which rebuilds its
			two registries; it writes nothing else. Prints rows of
			TAB-separated fields on stdout, the first naming the row. An
			absent value reads `-`, and a value's own whitespace reads
			`_`, as in a registry.
			`member <team-member> <mark> <first-name> <family-name> <alias> <kind> <workspace> <set-up> <status> <live> <icon> <folder>`
			<mark>, the two names and <alias> are the member's row of
			`team-members-names` in the workspace it is set up in; the
			row of a `client-*` member holds its persona's. <kind> is the
			member's prefix group, the word before its first dash.
			<workspace> is the name of the workspace it is set up in, and
			<set-up> says where that is: `here`, `elsewhere` on this
			machine, or `not-present` where the machine's members index
			names the member and its workspace cannot be reached, its
			other fields then `-`. <status> is the `status` of its
			`SKILL.md`: `reference-only` is a member nobody is started
			as. The row of `magic-team` reads `the-team` there, whatever
			its `SKILL.md` says: it is the team itself and no member,
			and nobody is started as it either.
			<live> is `running` while a run of it in a session of
			this workspace has a live process on this host, else
			`no-process`. <icon> is the icon the member table of
			`--install-skillset-symlinks` shows the member with: the
			default icon of its prefix group, whatever its <mark>, and
			never absent. <folder> is the member's own folder, its link in
			the member set of its workspace followed to where its skillset
			lies in a source; `-` where it cannot be followed. With no
			names registry the mark and the names
			of this workspace's members read `-`, and one note on stderr
			says so. Exit 1, nothing printed, where a registry cannot be
			rebuilt.

		--manager-team-member-files <team-member> [<file>]
			One of the console's own operations (see Notes). Lists the
			files of one member's skillset folder, where the member is set
			up, here or in another workspace of this machine, or prints one
			of them. It only reads. With no <file>, a row a file, by its
			path inside the folder, sorted:
			`file <path> <bytes> <text>`
			<text> is `yes` for a file that holds no NUL byte, else `no`.
			A dot file or a dot folder, and a link inside the folder, are
			none of its files. With a <file>, one path as the list gives
			it, that file's text as it lies, where it is text. Nothing
			outside the member's skillset folder is ever read. Exit 1 with
			one error line, and nothing on stdout, for a member that is not
			set up where it can be reached, a path the list does not give,
			and a file that is no text.

		--manager-team-member-read [--full] <team-member>
			One of the console's own operations (see Notes). Prints one
			member of the team: one set up here, or only in another
			workspace on this machine, which the operation finds itself.
			Rows as `--manager-team-member-list` prints them, in this
			order: the member's own `member` row; its information; the
			bullets of its `basic.md`; the sessions of this workspace it
			has a run in; its grants; its settings.
			`info <name> <value>`
			`bullet <name> <text>`
			`grant <kind> <access> <target> <place> <origin> <ends>`
			`setting <key> <state> <value> <workspace>`
			The `info` rows, in this order: `description`, of its
			`SKILL.md`; `workspace`, the path of the workspace it is set
			up in; `home`, its home where the machine keeps one;
			`link-kind` and `skillset-path`, its row of the registry
			`team-members` of that workspace; and for a `client-*`
			member `persona`, the member whose names its row holds. A
			session is its `session` row, then the member's own `run`
			rows in it, as `--manager-session-list` prints them: the
			sessions where a run of the member is alive come first. The
			`grant` rows are those `--magic-permission-list` prints for
			the member. A `setting` row is one key of the member's scope
			in this workspace, with the <state> and the <value>
			`--manager-config-digest` gives it, in full where `--full`
			is given, as the console reads it: `set`, `missing`,
			`secret-set` or `secret-missing`. Which key is a credential is
			that operation's rule, and a credential is printed in the
			one form that operation gives it. For a member set up elsewhere the keys of
			each system this workspace holds no setting of for it
			follow, which are read from the workspace it is set up in:
			each by its name alone, its <state> `elsewhere` and its
			<value> `-`. <workspace> names the workspace whose scope
			holds the key. The grants index is brought up to date where
			it is stale; nothing else is written but the registries.
			Exit 1, nothing printed, for a name that is no member, a
			member whose workspace cannot be reached, or a part that
			cannot be read.

		--magic-grooming-to-backlog [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves a board item to board/backlog/ and/or patches its
			frontmatter, one call -- no full-content rewrite required.
			`--edit-patch-from-stdin` takes a JSON array of `{"old":
			<text>, "new": <text>, "replace_all": <bool, default
			false>}` patches on stdin, applied in order as exact literal
			substring match-and-replace against the body. `--from-
			state:<state>` and `--owner-header-value` are both required;
			`groomed-at`/`groomed-from`/`track` are always auto-stamped,
			never caller-supplied. `approved-by`/`approved-at` are
			cleared, so promotion is re-earned, unless the call itself
			passes a `--header:*` for either. `--header:*` and the three
			body-input modes pass through for whatever else the move
			also needs.

		--magic-grooming-to-pending [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/pending/ -- the Advancement-review case (backlog ->
			pending), e.g. `--header:upsert:approved-by:"<team-member>
			(<session-id>, <date-time>)" --header:upsert:approved-at:
			<date>`. `approved-by`'s value is validated: must match
			`<team-member> (<session-id>, <date-time>)` with an ISO UTC
			date-time (suffix `Z`).

		--magic-grooming-to-processed [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/processed/.

		--magic-grooming-to-parked [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/parked/ -- a deliberate deferral by the team's own
			choice (distinct from board/blocked/, a stall on something
			external). `recheck-date` and `condition` are caller-
			supplied via `--header:*` -- triage judgments this op cannot
			compute.

		--magic-grooming-to-blocked [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/blocked/ -- stalled on something external (distinct
			from board/parked/, a deliberate stop). Stamps `owner`/
			`groomed-at`/`groomed-from`/`track`, which is what
			distinguishes this from `--magic-board-to-blocked`: same
			target state, but that one stamps nothing. `recheck-date`
			and `condition` are caller-supplied via `--header:*`.

		--magic-grooming-to-running [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/running/. Distinct from `--magic-advance-to-running`,
			which targets the same state under a different owning
			routine and different recorded provenance -- this one
			stamps `owner`/`groomed-at`/`groomed-from`/`track`.
			`started-at` is also stamped, as on every move or create
			into board/running/ -- pass
			`--header:upsert:started-at:<date-time>` to override it.

		--magic-grooming-to-archived [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/archived/ -- a Drop outcome, or a re-check step
			concluding a parked trigger is never coming or a blocked
			item isn't worth waiting on. Still stamps `owner`/`groomed-
			at`/`groomed-from`/`track` despite the target being terminal
			-- who archived an item, and from where, is exactly what a
			later reader needs. The archived reason text is caller-
			supplied via `--header:*` or the body-input modes.

		--magic-grooming-to-retained [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/retained/ -- but a SAME-STATE PATCH, not a move: call
			with `--from-state:retained` so source and target match and
			nothing relocates; the existing body is read-and-preserved
			rather than replaced. The renewed `recheck-date` is caller-
			supplied via `--header:*`. The usual grooming stamps apply;
			on a same-state call, `groomed-from` records `retained`,
			meaning groomed while sitting there, not arrived from
			elsewhere.

		--magic-grooming-create-backlog [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
			Creates a board-item directly in board/backlog/ -- a first
			write, not a move: the promoted default landing for an inbox
			item the authority group promotes. `--from-state:` is
			rejected (nothing to move from). `owner`/`groomed-at`/
			`track` are stamped; `groomed-from` is NOT (nothing moved
			from). Exactly one body-input mode is required -- there is
			no existing body to carry forward. `communication-channel-
			id`, `approved-by`/`approved-at`, `blocks`/`blocked-by` and
			`references` ride `--header:*` in this same write.
			Creation headers (`type`, `from` = <team-member>, `date`)
			are completed by the tooling, as for
			`--magic-board-create-running`; `owner` stays the
			`--owner-header-value`.

		--magic-grooming-create-processed [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
			As `--magic-grooming-create-backlog`, target board/processed/
			-- a promoted-or-denied item landing with its resolution
			text attached.

		--magic-grooming-create-pending [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
			As `--magic-grooming-create-backlog`, target board/pending/
			-- a promotion where the group's own context already
			warrants approval at creation.

		--magic-grooming-create-blocked [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
			As `--magic-grooming-create-backlog`, target board/blocked/
			-- a promotion that needs human-owner approval, so the item
			lands blocked.

		--magic-grooming-create-running [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
			As `--magic-grooming-create-backlog`, target board/running/
			-- the approval-* item the human-owner approval negotiation
			runs in.

		--magic-sweep-state-upsert [--team-member <team-member>] [--from-file <path>|--edit-patch-from-stdin]
			Writes (creates or overwrites) routine-communication-sweep's own
			state record FOR THAT MEMBER. Takes no filename or path argument --
			storage is the operation's own concern; `<team-member>` says whose
			position this is, and each member's record is its own, so a
			`client-*` member's sweep resumes from where its own sources were
			last swept and not from the team's position in the team's traffic.
			Input source is exactly one of: stdin (default), `--from-file`, or
			`--edit-patch-from-stdin`. Empty content is rejected. If
			`--edit-patch-from-stdin` is used, stdin must be a JSON patch array
			for exact-literal replace operations.
			A SWEEP POINTER ONLY EVER MOVES FROM OLDEST TO NEWEST, and that is
			enforced here rather than left to the caller: content whose
			`last_swept_ts` is older than the stored one is REFUSED, and so is
			content that drops the field while a position is stored (a reset).
			To re-read material below the stored pointer, pass an explicit
			`--comms-since-utime` to the scan -- a read does not move the pointer.

		--magic-sweep-state-read [--team-member <team-member>]
			Reads back the whole record written by --magic-sweep-state-upsert
			for that member, verbatim. Outputs `NO_STATE` if nothing is stored
			yet. Read-only. There is one pointer per member, `last_swept_ts`;
			no per-source pointer is stored or read.

		--magic-sweep-state-advance [--team-member <team-member>] <ts>
			Moves that member's own `last_swept_ts` to <ts>, the newest
			message its pass actually processed. The rest of the record is
			kept, except stale `source-<key>-last-swept-ts:` entries, which
			are dropped (a missing record is created). Call it once per
			swept member at the end of every pass that processed a message.
			The same value is a no-op; an older one is REFUSED, as is a
			<ts> more than a minute in the future. Commits the record.

		--magic-team-roster-upsert [--team-member <team-member>] [--from-file <path>|--edit-patch-from-stdin]
			Writes the team's roster cache -- member/domain/posture rows plus
			the per-member persona subsections, one record. Call it after
			re-deriving either from the members' own live skill files, to
			store the refreshed cache. Input source is exactly one of: stdin
			(default), `--from-file`, or `--edit-patch-from-stdin`. Empty
			content is rejected. If `--edit-patch-from-stdin` is used, stdin
			must be a JSON patch array for exact-literal replace operations.

		--magic-team-roster-read [--team-member <team-member>]
			Reads the team's roster cache -- member/domain/posture rows plus
			the per-member persona subsections. The grooming input scan,
			which the spawner runs for the grooming routine, already holds
			this same content as its own section, so a routine working
			from that scan does not call this op too.
			Outputs the record content, or
			`NO_RECORD` if none is stored yet. Read-only.

		--magic-team-data-commit-pending [--team-member <team-member>] [--commit-message <message>] [--no-push]
			Commits everything pending under the team-data store in one
			commit (new/changed/deleted paths), then syncs the store
			with its remote by myx.common git/cloneSync on the branch
			it is on: origin's commits are pulled and merged in, never
			rebased, and what is ahead is pushed; cloneSync's own
			output goes to stderr. Every other team-data op commits
			only what it writes, this one catches the rest. <team-member> must be
			magic-coordinator. Nothing outside $MDAT_DATA_ROOT is
			staged or committed.

			Prints `TEAM-DATA-NOTHING-PENDING: <store>` when there's
			nothing to commit. Otherwise: `TEAM-DATA-COMMITTED:
			<commit> <n> path(s) under <store>`, then one
			`<status><TAB><path>` line per path, then one of
			`TEAM-DATA-PUSHED: <commit> to origin, read back as
			origin/<branch> = <full-sha>` (exits 1 if the readback
			doesn't match), `TEAM-DATA-NOT-PUSHED: no
			TEAM_DATA_GIT_REMOTE is configured`, or
			`TEAM-DATA-NOT-PUSHED: --no-push`. It also skips the push,
			and says why, when the store sits inside a larger
			repository or that repo's origin isn't
			TEAM_DATA_GIT_REMOTE -- a push would send the whole
			branch. A failed git/cloneSync prints `TEAM-DATA-NOT-PUSHED:
			the push failed; ...` and exits 1 with the commit kept
			locally. Refused: a store not in a git repository, or one
			showing an interrupted operation (index.lock,
			merge/cherry-pick/revert/rebase in progress) --
			`TEAM-DATA-REFUSED: the repository shows an interrupted
			operation: <which>`, exits 1, repairs nothing. Commits
			already ahead of origin go out with the push.

			**Hazard**: takes no lock -- run it only when no routine
			holds the advance lock, or a file another op
			is writing could be committed half-written.

		--member-wait-for-input [--team-member <team-member>] [--wait-default|--wait-continue|--wait-close|--wait-add|--wait-drop --wait-session-id <session-id>] [--wait-source <kind>:<target>]... [--wait-timeout <seconds>] [--wait-poll-interval <seconds>] [--wait-since-utime <epoch>] [--wait-addressee <slack-user-id>] [--wait-include-own] [--wait-react-seen <ids>] [--wait-react-note <ids>] [--wait-react-done <ids>] [--wait-react-wait <ids>] [--wait-collect <seconds>]
		--member-wait-for-input [--team-member <team-member>] --wait-list-sources
			Waits on a list of input sources, returns as soon as one
			changes or the timeout expires.

			stdout always opens with one marker line:
			`WAIT-RESULT: RECEIVED` (something arrived, that
			source's new content follows), `WAIT-RESULT: TIMEOUT`
			(bound expired, nothing new), or `WAIT-RESULT: ERROR`
			(wait could not run, see stderr). RECEIVED and TIMEOUT
			both exit 0 -- a TIMEOUT is a complete, successful
			wait, not a failure; ERROR exits 1. `WAIT-RESULT:
			CLOSED` (--wait-close ended the stored wait, nothing
			was waited on) exits 0, as do `WAIT-RESULT: ADDED` and
			`WAIT-RESULT: DROPPED` (--wait-add, --wait-drop).

			A source is `<kind>:<target>`, --wait-source is
			repeatable; given none, waits on this session's own
			thread (as the `:conversation` form below, from the
			current time) when the session has one, else on
			`slack:magic-team` and `slack:human-owner`. A session
			that is itself the coworking session, never spawned,
			waits on those two and, once its thread is on record,
			on that thread too, in the `:conversation` form.
			`slack:<conversation>` waits
			on a conversation; `slack:<channel>:<ts>` on that
			message's thread; `slack:<channel>:<ts>:conversation`
			on any new post in that thread not from this member;
			`slack:session-current` and `slack:session-parent` on
			that session's thread, in its `:conversation` form (see
			--member-comms-slack-send-message; a name that names
			nowhere is an ERROR, by the same line as there);
			`slack:<alias>:<ts>` on the thread of the message with
			that ts in the conversation an alias names, and with
			`:conversation` after it on any new post there;
			`file:<absolute-path>` on a local path (file or dir)
			-- an absent path is a state, not a failure;
			`inbox:<member>` on that member's own inbox, which
			must be the caller's own; `board:<state>` on one
			board state (backlog, pending, running, review,
			blocked, parked, processed, archived or retained);
			`ask:<pending-id>` on the answer to a question
			AskQuestion asked: its thread, floor and addressees
			come from its pending record, read as that question's
			own wait reads them, plus a `# pending reply <id> is
			closed: <status>` line once the record is no longer
			pending (a record-only escalation renders only that).
			Its record must exist, and with --wait-session-id it
			must be that session's own question, else ERROR. Its
			rendering holds arrivals only, so with no stored base
			an answer already there returns at once. Taking the
			answer into the record is the harness's, not this
			operation's. `replies:<session-id>` on the replies to
			the posts that session made (its record of them,
			sessions/<id>/last-own-post): every reply in the thread
			of a post, and for a post at the top of a conversation
			the messages after it there from the people it
			addressed or that mention the run, until ten siblings
			have followed it, and after that a mention of the run
			alone. Reactions to a post are returned too.
			A post is looked at when its TTL has passed, 5 seconds
			and 1 more for every 20 it has been quiet, so a quiet
			thread is looked at ever more rarely and never dropped
			by time alone. A --wait-default or --wait-continue with
			--wait-session-id always carries it, first, and the
			sources it names are added to it. It is returned once,
			and what another source of the same wait reads is left
			to that source. `chat:<session-id>` on the session chat
			file (sessions/<session>/session.chat), the second half of the
			floor, beside the replies: the messages of the session thread
			that are for the run -- every one for the executor of the
			session, the ones that tag or mention it for a participant --
			read from the file by the member's pointer, in full, each run
			of messages behind the source it is of. The file is brought up to date
			here: where no source of the wait reads the session thread, the thread is
			read into it when its TTL has passed (5 seconds and 1 more
			for every 20 quiet, 300 at most); where one does, that source's own
			read brings it in, so the thread is read once. What a
			message of the file was delivered as, it is not delivered again.
			`scan:<scan>` on a scan of the tooling
			(for the tooling's own use, never in a default set): its
			report, read through the cache of the session, TTL 300
			seconds, returned when it differs from the one the session
			was last given. `tagged:<own member>` on what is for the
			member by name: a mention in the team channel or its session
			thread, and any message of any DM, TTL 15 seconds.
			--wait-collect <seconds> makes the call a collect (the
			work-duty input scan): the window is its bound, it returns at
			its end with everything the sources brought, or at once on an
			arrival of the tags, and says which on a `# returned: window`
			or `# returned: immediate` line; each source resumes from the
			pointer the session kept for it. A slack source the caller
			adds may end in `#short` or `#full`, chosen when it is added
			(`--wait-source slack:magic-team#full`): `#short` returns each
			message cut to a short form with its own reference
			(`<source>:<ts>`) and, once in the return, the line that reads
			one in full (`--member-comms-slack-read <member>
			<source>:<ts> --thread`), and keeps only that short form; `#full` returns every
			message whole, and keeps a single message too long for the
			return (over the threshold of a long result) as a file of its
			own in the session's folder
			(sessions/<session>/messages/<source>/<ts>.md), returning a
			preview and the path of that file; no file is made for any
			other message. Either way the source's index cache file
			(sessions/<session>/sources/<source>.md) keeps a line for each
			message once. A source with neither returns each message whole.
			The form is stored with the source, and goes with it on
			--wait-add, --wait-drop and --wait-continue. File, inbox and
			board carry no message ids. Another member's inbox
			or another state name is an ERROR at second zero.
			--wait-list-sources prints the source kinds this
			build carries and waits on nothing. What a wait returns is the
			floor first (the replies, then the chat file), then the other
			sources' messages together in one group sorted by time, each
			under the `# arrived on: <source>` line of the source it came from.

			--wait-timeout: bound in whole seconds; none by default,
			so the wait returns only when something arrives.
			--wait-poll-interval: whole seconds between probes,
			fixed when given (or MDAT_WAIT_POLL_SECONDS when set),
			minimum 1. Unset, it backs off: 5s, growing 15s per 5
			minutes, capped at 300s, counted from the newest
			activity on the watched sources -- the call start, the
			last message a wait returned on a Slack source, a
			watched question's own ts or follow floor, or this
			session's own latest post where a watched source would
			carry its reply -- so a question asked late in a long
			wait is watched closely again. Only affects how soon an
			arrival is noticed. --wait-since-utime: epoch seconds;
			give it to catch something already posted (e.g. a
			message just sent) so it counts as an immediate
			arrival; without it, the first probe is the baseline.

			--wait-addressee names the Slack accounts whose answer
			counts; required with a `slack:<channel>:<ts>` thread
			source, with --wait-since-utime set to the question's
			own ts -- only a reply from those accounts, or a
			reaction on the question, is an arrival. Any number of
			sources and threads may share one wait. Several plain
			thread sources share the one --wait-since-utime and
			--wait-addressee of the call, so a thread that does
			not hold that ts is named in WAIT-NEVER-READ.
			`slack:<channel>:<ts>:conversation` needs
			--wait-since-utime too, and takes no --wait-addressee
			when every thread source is a `:conversation` one:
			any new post counts, and this
			member's own posts never do unless --wait-include-own
			is given (refused on every other source, where posts
			already count). On this source shape only,
			--wait-since-utime need not name a real message, and
			may be left out: the floor is then the stored one,
			else the session's own last post there, else the
			spawn's launch, else the wait's start.

			An unsupported source kind is an ERROR at second zero,
			naming the kinds that exist. A probe that can't run is
			named in the body and the wait continues on the rest;
			a TIMEOUT body then says nothing is known about those
			sources either way.

			`WAIT-NEVER-READ: [<kind>:<target>] ...` names, right
			after the marker, any source never read during the
			wait -- absent when every source was read at least
			once; never changes the outcome or exit code.

			RECEIVED returns every source that changed in that
			round, one `# arrived on: <source>` block each. On a
			slack source it ends with:

			    WAIT-LAST-TS: <ts>

			When several slack sources changed, there is one line
			`WAIT-LAST-TS: <source> <ts>` per source. Pass the ts
			back as the next call's --wait-since-utime to keep
			reading forward. Absent on a file, inbox or board
			source -- none has a ts to name.

			Modes, mutually exclusive (else ERROR "modes are
			mutually exclusive"), each needing --wait-session-id
			(else ERROR naming it). The wait is then kept per
			session, under
			$MMDAPP/.local/agents/sessions/<session-id>/wait/,
			and a stored wait older than 7 days is removed when
			any mode call starts. With no mode the call keeps no
			state.
			--wait-default: waits on the sources given (else the
			default above), and stores the wait when it returns
			RECEIVED or TIMEOUT. It keeps every stored floor: a
			slack source resumes after the last message a wait
			returned on it, so nothing posted between two calls
			is skipped. An explicit --wait-since-utime replaces
			the floor of a plain question thread, and on any
			other slack source the older of the two is used.
			A stored ask: item whose record exists stays in it.
			On a slack arrival the wait re-reads after
			MDAT_WAIT_SETTLE_SECONDS (default 3, 0 is off), up to
			MDAT_WAIT_SETTLE_ROUNDS (default 3) times while more
			arrives, so a burst returns together, oldest first.
			--wait-continue: repeats the stored wait with its
			sources, addressee, include-own and per-source
			floors (kept only from the second call on), so a
			message that arrived between two calls returns at
			once. It takes no --wait-source,
			--wait-since-utime, --wait-addressee or
			--wait-include-own, and with nothing stored it is an
			ERROR, never a default wait.
			--wait-close: removes the stored wait and returns
			`WAIT-RESULT: CLOSED` without waiting, also when
			nothing is stored.
			--wait-add: appends the --wait-source values to the
			stored wait, creating it when nothing is stored, and
			returns `WAIT-RESULT: ADDED` without waiting.
			--wait-drop: removes them, removing the stored wait
			once no source is left, and returns
			`WAIT-RESULT: DROPPED`. Both take one or more
			--wait-source and nothing else, and refuse a
			`slack:<channel>:<ts>` thread source, whose since and
			addressee the stored wait would share. This is how an
			asked question's `ask:<pending-id>` joins its
			session's wait. Once answered it stays there, its
			thread watched from the record's `follow-floor`, so a
			later message there arrives and is kept with the
			answer as a clarification; a question withdrawn or
			settled leaves it.

			An answered `ask:` source quiet five minutes past its
			own last update leaves a `--wait-default` call's
			stored sources on its own. That update is the newest
			kept clarification line, read off the record directly;
			`follow-floor` stays fixed at the close, so it is only
			the fallback where none is kept yet. Said, never silent:
			`WAIT-DROPPED-EXPIRED: ask:<pending-id> ... -- quiet 5
			minutes past its last update; name it again
			explicitly to keep watching it`, right after
			WAIT-NEVER-READ if any. Only a default call reaching
			for it on its own is affected; naming it again with
			--wait-source, any mode, is not.

			--unwait <kind>:<target> is the same as --wait-drop
			--wait-source <kind>:<target>, nothing more -- one
			flag, its source inline, returning the same
			`WAIT-RESULT: DROPPED`. Dropping a source, by either
			of them or by expiry above, is never blocking it: a
			later call naming it explicitly reaches it exactly as
			if it had never been dropped.

			--wait-react-seen, --wait-react-note,
			--wait-react-done and --wait-react-wait each take
			message ids, space-separated, from earlier results:
			`<channel>:<ts>`, or a bare ts when the wait has
			exactly one slack source. An id holds only letters,
			digits, `.`, `:`, `-` and `_`, else ERROR. Each id
			gets the reaction of its set (seen `eyes`, note
			`writing_hand`, done `white_check_mark`, wait
			`hourglass_flowing_sand`), under the member's own
			identity and then the bot. A reaction already there
			is no change. A failed one is listed and does not
			stop the wait. Reactions are never removed here.

			Order: every argument is checked first, then the
			reactions are applied, then the wait or the close
			runs. A refused call reacts to nothing.

			With a mode, stdout continues after the marker with
			`WAIT-MODE: <mode>`, then WAIT-NEVER-READ if any,
			then `# filters: sources=.. floors=<source>=<ts>..
			addressee=.. include-own=..`, then `# reactions:
			seen=N note=N done=N wait=N failed=<ids or none>`,
			then the usual `#` lines. stderr carries one trace
			line: `# --member-wait-for-input: mode=<mode>
			member=<name> session=<id>`.

		--member-escalation-read [--team-member <team-member>] <request-id>
			The verdict of one escalation: a ConfirmReadback,
			EscalateDecision, RequestPermission or ProposeApprove, or
			an AskQuestion with an answer form (`select`). <request-id>
			is the
			pending-reply id the question printed ("recorded as
			pending reply <id>"). Answered: prints
			`ESCALATION: <id> answered`, then `VERDICT:`,
			`VERDICT-TEXT:` (readback correction), `ANSWERED-BY:`,
			and for an allow, `GRANT:`. The prompt of a change held
			for approval is read here too: the human-owner's approve
			applies the kept change, exactly as it was shown, his
			reject drops it, and `CHANGE:` says what was done:
			`applied`, `dropped`, or `not-applied` with why. A held
			change whose session is gone is dropped instead, read or
			not: `ESCALATION: <id> closed withdrawn`. Not yet answered: read now
			from the question's own thread, then a forward's thread;
			an answer from an addressee there applies exactly as a
			waiting question applies it. With nothing there yet from
			who may answer: `ESCALATION: <id> open` + `WAITING-ON:
			<who it is addressed to>`, and no verdict line. With a
			reply or a click there that names none of the answers:
			`ESCALATION: <id> open` + `VERDICT: RETURNED`, with
			`VERDICT-REASON:` when an answer was seen and not taken.
			A thread that cannot be read is neither: an error (rc 1)
			naming the conversation, the identity it was read with
			and Slack's own error, with `ESCALATION: <id> unreadable`
			and `UNREADABLE-REASON:` on stdout, the record left open.
			Every answer read is confirmed once, by one reply in the
			thread it was read in, from the template of its kind
			(`# Confirmations`): what was read and by whom, and what
			is granted, or that nothing is, or why it could not be
			applied. The reply is addressed as the ask is, by name, and
			in a forward's thread to the human-owner. An allow from
			someone who does not hold what it allows goes up: to a
			holder with a live run in this session, told in the
			session thread, else to the human-owner, posted by the
			team bot with its answer emoji.
			An answer from the account that asked is never taken. A
			question withdrawn by its asker prints `ESCALATION: <id>
			closed withdrawn` and takes no verdict.

			Only a reply's first line gives its verdict: its first
			line that is no quote of the question, a ``` fenced
			block or lines starting with ">" or "&gt;" heading the
			reply being skipped. That line answers in one of two
			shapes: the answering word alone, the marks that close
			it aside, or the word, a punctuation mark and then the
			person's words (`allow-once, but only this file`). Words
			after it with no mark between, a word that is not at
			the start, and two answers on one line are no verdict:
			RETURNED. A number keeps its own rule, the first word
			whatever follows it. A plain
			affirmation -- ok, okay, yes, agree, agreed,
			confirm or confirmed, also after a leading "I", in any
			case, or a +1, ok_hand or white_check_mark reaction on the
			question -- is yes for a readback, and for a decision the
			option whose line holds `(recommended)`; with none marked
			it answers nothing. A permission takes only its own words.
			A proposal (ProposeApprove) takes only the human-owner's
			own verdict. His white_check_mark on the root of its
			thread is `approved` and his x there is `rejected`,
			rejected first when he holds both. The tooling places
			its own x and white_check_mark there to click on, as the
			identity that posted the root: they are never a verdict,
			and are taken off when one is read or the proposal is
			withdrawn. A reply whose first
			word is approved or rejected gives the same, and the rest
			of that line is printed as `VERDICT-TEXT:`. A reaction
			under the proposal reply is no verdict, and only the
			replies after the live proposal reply are read. Its
			item's `## Decisions` line names the document by its link.
			Once a verdict is applied, the rest of the reply it came
			from and every later reply there are kept as
			clarifications: under the record's `## Clarifications`,
			and as `clarification` lines on its item's `## Decisions`
			(`CLARIFIED <id> <n>`). A decision closed by its asker's
			readback also prints `CLOSED-BY: readback`. An answered
			record keeps `follow-floor:`, the newest message of its
			thread already read, from which the asking session's
			Wait keeps watching that thread.

			While a typed escalation waits, the first reply from an
			addressee ends the wait, judged against every reply since
			the question (the asker's own posts never count). A
			reply naming no valid answer returns
			`VERDICT: RETURNED` to the asking agent with its
			reason and the reply text; the record stays open, nothing
			is posted automatically, and its `WAIT-ID:
			ask:<request-id>` stays in the session's stored wait, so
			the harness Wait (mode continue, or sources=
			ask:<request-id>) takes the next reply exactly as the
			question would. The result's last line is still the
			compatible re-wait call, `AskQuestion pending_id=
			<request-id>` -- posts nothing, waits on the same thread
			again, and only the session that asked may make it. An
			older record with no session id can be re-waited from any
			session, but for a permission it grants nothing there --
			the grant is keyed to the record's own session.

		--member-escalation-answer [--team-member <team-member>] <request-id> <verdict> [text]
			Answers one open escalation as <team-member>, which must be
			the member it was addressed to, or an executor of the
			routine it was addressed to (`<name>.routine`), and not the
			member who asked. This is how a member with no Slack
			account of its own, the coordinator included, answers, and
			how an ask to a routine is answered. The verdict must
			belong to the kind: yes, no or correct for a readback, the
			answering word of one option for a decision, deny,
			allow-once, allow-session or allow-task for a permission,
			allow-folder too where its post offers the folder of the
			refused file, allow-project too where it offers the project,
			and allow-set, deny or edit for a permission
			set. allow-folder grants the tool of the refused call on
			everything in that folder, for the session, as a set of one
			entry for the member whose call it was; it is offered only
			for a file tool on a path with no `..` segment, never for
			a write in a read-only place, and never for a folder that
			is a whole workspace. allow-project grants that tool on
			everything in the project the refused file lies in, its
			project.inf included, the same way: the nearest folder at
			or above the file that holds a project.inf, in the source
			tree of a workspace. It is offered only where the folder
			is, and only where the project is wider than it. [text]
			carries a readback correction or an edit's change.

			The record closes carrying the verdict and who gave it. An
			allow is written as a grant for the refused call named in
			the refusal record, never for anything the ask's own words
			said, and signed by <team-member>. An allow from an
			approver who does not hold what it allows is not applied:
			the result is `ESCALATION: <id> rerouted` and
			`ADDRESS-TO:`, the escalation re-addressed to a holder
			among the session's or task's participants, else forwarded
			to the human-owner, and it stays open. The waiting question
			ends on it and its session retries the exact call. A second
			answer to the same escalation is not applied. What became
			of the answer is said in the question's own thread once, by
			the confirmation of its kind: what is granted, that
			nothing is, or that the answer is not applied and who the
			request goes to now. The answering member posts no line of
			its own beside it. A spawned session answers only as its
			own member.

		--magic-escalation-answer <magic-coordinator> <request-id> <verdict> [text]
			The coordinator answers one open escalation on behalf of the
			member it was addressed to, whoever that is, as
			--member-escalation-answer does for the addressee: the same
			verdicts, session checks, grant and thread notice, signed by
			magic-coordinator. Never a question magic-coordinator asked.
			Only magic-coordinator, or the console, may call it.

		--member-escalation-readback [--team-member <team-member>] <request-id> <option word> [text]
			The asker closes its own open decision by reading the
			reply back, once the person has replied and no reply names
			an option. It posts in the question's own thread, under the
			identity the question was asked with, which option it takes
			the reply to mean, with [text] saying why. The record closes
			with that option as its verdict, answered-by `<team-member>
			(readback)`, `closed-by: readback`, and `follow-floor:` the
			readback's ts; the replies there are kept as
			clarifications. Prints the result lines with `CLOSED-BY:
			readback` and `FOLLOW-FLOOR: <ts>`. A later reply from the
			person there, such as an objection, arrives on the asking
			session's Wait (its `ask:<request-id>` stays in the stored
			wait) and is kept the same way. Refused for anything but a
			decision or a question with an answer form (`select`),
			never for a permission, for any member but the
			asker, with no reply yet, and when a reply already names an
			option. For a question with an answer form, <option word>
			is the answer as a reply would give it: `yes` or `no`, an
			option's number or first word, or several of them for
			`many`. EscalateDecision pending_id=<id> readback=<option
			word> calls it, and AskQuestion pending_id=<id>
			readback=<answer> for a question. A spawned session reads
			back only as its own member.

		--magic-escalation-forward <coordinator> <request-id>
			Forwards one open escalation addressed to <coordinator> to
			the human-owner, keeping the same record. The question is
			posted to the human-owner as the team bot. His reply or
			declared reaction in that thread is the verdict for the
			original request, and the waiting question ends on it.
			Only the member the escalation is addressed to can forward
			it, or an executor of the routine it is addressed to, and
			only while it is open.

		--member-permission-pass [--team-member <team-member>] --to <member> --tool <tool> --target <target> --kind once|session|task [--task <item>] [--session-id <id>]
			Passes a permission <team-member> holds on to <member>:
			one it gives part of its own job to, or one who asks it.
			Whether to pass is the member's own judgement. Tooling
			refuses a pass wider than what <team-member> holds, one
			that outlives its own grant (a task grant passes on only
			for that task, or once), and one to a member that is no
			participant of the session or task and was not spawned by
			it for it. <target> is a path, a <path>/** pattern or a
			URL prefix written <prefix>*. Prints `GRANT: <kind>
			pass-<id>`; the grant is <member>'s own, signed by
			<team-member>. The session is the caller's own unless
			--session-id names it. A spawned session passes only as
			its own member.
			<target> may also name a registered place, `@<name>[:<glob>]`,
			as --magic-permission-set-request takes it; a path in a
			place is said as `PLACE: <tool>:<target> is
			<name>:<relative>`. A write in a read-only place is refused,
			naming the route to take instead. With --kind session both
			members take part in the session, and the grant ends with
			it: how a keeper invited into a session widens the access
			of the others there.

		--magic-permission-set-request <magic-coordinator> <item> (--entry <tool[,tool...]:target>... [--purpose <text>])... [--scope task|session] [--session-id <id>] [--participant <member>]...
			Asks for a task's or session's permission set at spawn or
			brief time. One --entry may name several tools for one
			target, a comma list before the colon
			(`Read,Grep,Glob:<target>`), taken as one entry a tool. A
			tool is any the permission model can decide on: Read,
			Grep, Glob, Edit, Write, MultiEdit, NotebookEdit, Execute,
			Bash, WebFetch, WebSearch, Agent, Artifact, cred, spend, or
			a tool of an MCP server by its own name. A name the model
			does not know at all, alone or in a list, is a CORRECTION
			(rc 6) that names these, and nothing is asked. No word
			means every tool. A task set
			is for the members named with --participant, and those
			only; with none named, for the members of that task (the
			item's owner and `participants:`, the owner of each dispatch
			tracking it), never for the session's other participants. A
			session set is for everyone in the session and any member
			named. Prints `PARTICIPANTS:`, then `HELD: <entry> by
			<member> <layer>` for each entry a participant with a live
			run in this session already holds -- those pass on when the
			holder delegates, never granted to the others -- and
			`EXTRA: <entry>` for the rest, one held only by a member
			that is not running among them.
			With extras, ONE permission-set escalation is posted to the
			human-owner as the team bot, and `PERMISSION-SET: asked
			<id>` and `WAIT-ID: ask:<id>` are printed; with none,
			`PERMISSION-SET: held`. His allow-set grants every extra to
			every participant for the scope, writes a task set as the
			item's `allows:` too, and records the set on the item's
			`## Decisions`; the grants end when the task closes or the
			session ends. deny and edit grant nothing. He answers by
			click, :x: to deny or :unlock: to allow the set, which the
			tooling places under the post, or by a reply whose first
			word is allow-set, deny or edit; edit is a reply only, as
			it carries the change. Only his own click counts, and a
			thumbs up or `ok` grants nothing. --scope defaults
			to task; the session is the caller's own unless named.
			After the entries of a place, --purpose <text> may say what
			that access will be used for: it is shown under that place
			in the post and kept with it on the record, and it helps
			the person decide. The post groups what is asked by place,
			each place once by its `<place>:<relative path>` with its
			tools, and says the task in words, the session, the
			participants with their hosts, who asks and the scope. A
			place asked by its name, `@<name>[:<glob>]`, is shown by
			that name as asked, a built-in one too; a tool asked with
			no target stands on a line of its own, for any target.
			A target may name a registered place:
			`<tool>:@<name>[:<glob>]`, the glob a path, ** or <path>/**
			under it (default **), never with a .. segment; it is asked
			for as that path. A path in a place is said as `PLACE:
			<entry> is <name>:<relative>`, a hint recorded with the
			grant. A write in a read-only place is refused before
			anything is asked, naming the route to take instead.
			Only magic-coordinator, or the console, may call it.

			A member asks the same for itself with RequestPermission
			and `entries`, starting from a refused call (the harness
			runs --intern-op-permission-set-ask): one entry a place,
			`Tool[,Tool...]:<place>`, and an entry `purpose: <text>`
			for the entries before it. That set is for the asking
			member alone. Its entries must cover the refused call, or
			nothing is asked and the call comes back as a CORRECTION.
			It is for the task where `task_ref` names a board item,
			else for the session, and then names no item. `reason` is
			shown once in the post, as what the whole access is for.
			An ask that would allow the refused call and is open
			already is named instead, and nothing is posted.

			A call asked alone of the human-owner, a RequestPermission
			with no entries, is not posted once he has answered as
			many such requests of that session for that task as the
			one number allows (agentsPermissionSingleAsks,
			AgentsTools.PermissionHolds.include): it comes back as a
			CORRECTION that says to ask with entries. A request he
			answered counts, an allow or a deny; one a member or the
			coordinator answered does not, nor does a set asked as
			one. The same task is the same board item, or with none
			the same `task_ref`. A refused call prints how to ask
			after its REFUSAL-ID: the practice the RequestPermission
			declaration carries, word for word, read from it.

		--magic-permission-list --member <member> [--session-id <id>]
		--member-permission-list [--team-member <team-member>] [--session-id <id>]
			Prints one member's effective grants, one per line,
			TAB-separated: kind (floor, standing, session, task or
			once), read, write, approve (a write by approval: held
			for the human-owner, applied when he approves) or the
			tool, the target, its place as
			<name>:<relative> (or -), where it comes from (the declaring
			workspace and selector, or `<ref> by <member>`), and when it
			ends. Revoked, used, lapsed and ended grants are left out.
			Every session store of the workspace is read, or with
			--session-id only that session's own, coworking and parent
			stores. --member-permission-list lists the caller's own
			grants only; --magic-permission-list any member's, by
			magic-coordinator or the console.

		--magic-permission-revoke <ref> [--session-id <id>]
			Revokes one session, task or once grant by its reference
			(refusal-, pass- or set-<id>): a marker is written beside
			its record, every reader leaves it out from the next check
			on, and `REVOKED: <ref>` is printed (`already` when it
			was). An unknown reference is refused. A task grant's
			entries also leave its item's `allows:`, so no later
			dispatch tracking the item carries them (`ALLOWS-REMOVED:
			<item>` when they were there), and the revoke is recorded
			on the item's `## Decisions`. Only magic-coordinator, or
			the console, may call it.

		--member-pending-reply-read [--team-member <team-member>] [<pending-id>] [--all] [--any-owner] [--count]
			Reads the records AskQuestion leaves, of any kind. With
			<pending-id>, prints that one record. Without it, lists the
			member's own open records, then `PENDING-REPLIES: <count>`.
			`--all` adds closed ones, and `--any-owner` lists every
			member's. Each record prints `PENDING-REPLY: <id>`, then
			status, owner, kind, question-tag, channel, question-ts,
			thread-ts, address-to, session-id, asked-at and, once
			closed, resolved-at, verdict and answered-by, then
			`question:` with its first line. It changes no record, and
			it reads no thread, so an answer still in the thread is not
			shown here.
			An open record also prints `asker-live:` before its
			question: whether the run that asked it is alive, measured
			as the read is made and stored nowhere. `running`: a
			process of this host runs as it. `no-process`: a spawn
			record names it and nothing runs as it, so nobody is there
			to take the answer. `session-ended`: a session no spawn
			started, whose own store says it ended. `no-spawn-record`:
			such a session with no end recorded, which is not measured.
			`other-host`, `host-unrecorded` and `no-session-id`: asked
			on another host, or the record does not say where or by
			whom. `not-measured`: this read measured nothing for it, as
			when the registry could not be rebuilt.
			The session-id of a record is the id of the run that asked,
			never of the coworking session that run joined, and the
			asker is matched by it. The read only says so: it closes,
			withdraws and asks again nothing.
			A list first rebuilds the pending-replies registry, by the
			rebuild `--make-harness-indices pending-replies` makes, so
			that file is current after any list. One record by its
			<pending-id> rebuilds nothing.
			`--count` prints only the number of the records the list
			would show, by the same store and the same test of what is
			open, `--all` and `--any-owner` widening it as they widen
			the list, and renders no record: it rebuilds no registry and
			measures no asker. It takes no <pending-id>. The console
			asks it for the number beside Pending Questions.
			One record by its <pending-id> prints those same lines, then
			the whole of what the stores hold of that ask, from
			`PENDING-REPLY-STORED: <id>` to a blank line. Every line
			there is `<name>: <text>`. A text of several lines repeats
			its name on each of its lines, in order: an empty line is
			the name, the colon and one space, and the text ends where
			a line has another name. A name that lists things has one
			of them a line. In this order, each only where a store
			holds it: the record's other header fields under their own
			names (host, communication-channel-id, addressees, reason,
			task-ref, refusal-id, select and the rest); `posted`, the
			question as it was posted, whole; `clarification`, what the
			record keeps of its thread since; `option`, the options
			with their words; `field-<slot>`, what the post was filled
			with (asked-as, tag, question, context, understood, source,
			will-do, refused-tool, refused-target, refused-for, folder,
			project, reason, task, proposal, document; of a review
			member, task, outcome, session; of a held change also act,
			file, purpose, asked-by, the diff as shown and cut);
			`first-option` and `first-field-<slot>`, the same as first
			asked, once it was asked again, changed; `set-<key>`, a
			permission set's own record (scope, item, session-id,
			participants, entry, place, purpose, reason, held);
			`answer-noted-<key>`, a verdict noted and not yet applied;
			`refused-<key>`, `refused-place` and `refused-text`, the
			refused call of a permission and what the tool said;
			`change-store`, `change-<key>` and `change-diff`, a held
			change and its whole diff; `kept-beside`, the names of what
			lies beside the record. Only the stores of this workspace
			are read, never a thread: an ask made before its slots were
			kept has its question in `posted` alone. A list prints none
			of this.
			An open question is also reminded by the main loop itself
			(30 minutes, 2 hours, then daily after 09:00 once 4+ hours
			old), always by a reply in that question's own thread. The
			record keeps the stamps: reminder-30m, reminder-2h,
			last-daily-reminder, reminders and last-reminder-at. A
			reminder never closes a record.

		--member-pending-reply-settle [--team-member <team-member>] <pending-id> --reason <text> [--withdraw]
			Closes one of the member's own open questions that no longer
			needs an answer, such as one settled elsewhere. It is
			recorded as received, with verdict `settled: <text>` and
			answered-by `<team-member> (settled)`, and prints
			`SETTLED <id>`. Only the member that asked it can settle
			it. A readback, decision or permission is refused, because
			it closes through its own escalation ops. A record already
			closed prints `ALREADY-CLOSED <id> <status>` and is left
			as it is. A spawned session settles only as its own member.
			--withdraw discards the member's own open question instead,
			of any kind, decision, readback and permission included:
			it closes with status `withdrawn`, `withdrawn-by:` and
			`withdraw-reason: <text>`, and no verdict, so it answers,
			grants and decides nothing, and is reminded no more. Its
			item's `## Decisions` gets a `dismissed` line. A short note
			in the question's own thread, addressed as the question
			was, tells the person it is no longer needed. The
			question's post gets the cancelled mark
			of its template, loses the answer emoji the tooling placed,
			and is edited to drop its How to answer part: the root of a
			question with its own thread, else the live version of one
			asked inside another thread. Of a proposal it is the
			proposal reply, and its root is left as it is. Prints
			`WITHDRAWN <id>`.
			AskQuestion pending_id=<id> withdraw=<reason> calls it.

		--magic-pending-reply-settle <magic-coordinator> <pending-id> --reason <text> [--withdraw]
			The coordinator settles another member's open plain question
			on its behalf, as --member-pending-reply-settle does for the
			asker: verdict `settled: <text>`, answered-by
			`magic-coordinator (settled)`, `SETTLED <id>`. A readback,
			decision or permission is refused, and a closed record is
			left as it is. --withdraw withdraws only a question
			magic-coordinator asked itself, as the member stub does.
			Only magic-coordinator, or the console, may call it.

		--magic-pending-reply-amend <magic-coordinator> <pending-id> --verdict <text> --reason <text>
			Corrects the verdict of a plain question already closed with
			a wrong or missing answer, and prints `AMENDED <id>`. Only
			magic-coordinator may, and only on a closed record. The
			record reads received, with the new verdict, `amended-at`,
			`amended-by` and `amend-reason`. The verdict and answerer it
			replaces are kept as `amended-from` and
			`amended-from-answered-by`. Only one step is kept: a second
			amend replaces those with the first amend's values. The close
			time and the Slack marks are left as they were. A readback,
			decision or permission is refused, because its verdict may
			have written a grant, which is corrected through the grant
			store.

		--member-decision-record [--team-member <team-member>] <item-filename> --kind <clarification|resolved|dismissed> --text <one line> [--source <ts-or-id>] [--clears-blocker]
			Appends one dated line to the board item's `## Decisions`
			section, creating the section when it is missing, through the
			board edit primitive:
			`- <UTC> <team-member> <kind>: <text> (<source>)`. Prints
			`DECISION-RECORDED <item> <state>`. Decisions are binding
			context for the item: a spawn brief, conversation.md and a
			named-item input scan show them first, newest first, at most
			30. `--clears-blocker` also removes the item's `blocked-on`
			and `condition`, each printed as `BLOCKER-CLEARED <field>`.
			Only the item's own parties record on it: its owner, its
			reviewer (`review-by`, as for --member-review-accept), the
			member of its spawned session (`spawn-id`) or of a spawn
			whose `spawns`/`spawned-by` names it. A spawned session
			records as its own member only.
			An answer or a verdict is recorded by the tooling itself,
			when an AskQuestion closes, on the item its pending
			record names in `item:` (task_ref, else the session's
			`spawns:` dispatch item); an AskQuestion that Decisions
			or an earlier closed ask of the same session already answer
			is not posted again, and returns that answer.

		--member-review-request [--team-member <team-member>] <item-filename> --reason <text>
			Moves a board item from running to review, and only from
			running, with `review-reason: review-requested`, and records
			`review: review-requested: by <team-member>: <text>` in its
			`## Decisions` and its session transcript. Prints
			`REVIEW: <item> running->review (review-requested)`, or
			`REVIEW: not moved: ...` with the reason. Only the item's
			owner asks, or the session that spawned its child (that
			session, or its member). The tooling moves
			an item into review itself on a SubagentHandback (`handback`),
			on a child that ended with no handback
			(`ended-without-handback`) and on a --wait pass that ended
			(`wait-pass-ended`). The child then waits for its verdict at
			most REVIEW_WAIT_LIMIT seconds (team config, default 3600):
			at the limit its Wait returns DISMISSED
			(`review-wait-expired`, recorded), and the item stays in
			review, where a return can restart that same session.

		--member-review-accept [--team-member <team-member>] <item-filename> [--summary <text>]
			The accept verdict on an item in review or running: moves it
			to processed through --magic-board-to-processed, which sends
			DISMISSED to its live child (the ACCEPT-DISMISS line), and
			records `verdict: accepted[: <summary>]` in its `## Decisions`
			and its session transcript. Prints
			`VERDICT: <item> accepted -> processed`.
			Every verdict, this one and return, reject and follow-up, is
			given only by the reviewer the item's `review-by` names:
			empty or `magic-coordinator`, magic-coordinator; `human-owner`,
			the human, from no spawned session; `<name>.routine`, an
			executor of that routine; a session id (`<id>` or
			`<id>:<member>`), that session, the member it names or its
			own member; a member name, that member. A spawned session
			gives a verdict as its own member only.

		--member-review-return [--team-member <team-member>] <item-filename> (--message <text>|--from-stdin)
			The return verdict on an item in review: the same session
			continues. Moves it to running with the corrections appended
			as a `## Review: returned` section, and records
			`verdict: returned: <text>`. A child still waiting gets the
			corrections in its own session thread, addressed to it
			(`RETURN: delivered ...`); a session that has ended is
			started again on the same item, coworking session and
			sandbox (--dispatch-doc:reuse), its brief the item with its
			Decisions first (`RETURN: restarted ...`). Its next handback
			moves it to review again.

		--member-review-reject [--team-member <team-member>] <item-filename> (--message <text>|--from-stdin)
			The reject verdict on an item in review or running: moves it
			to pending with `status: review-rejected` and the corrections
			appended as a `## Review: rejected` section, sends DISMISSED to
			its live child (`REJECT-DISMISS: ...`), and records
			`verdict: rejected: <text>`, so a fresh spawn reads them. The
			fresh spawn itself is the normal spawn path.

		--member-review-follow-up [--team-member <team-member>] <item-filename> <new-item-name> --from-stdin
			Creates <new-item-name> in pending from the body on stdin,
			with a `follows-up: <item>` header, and records
			`verdict: follow-up: <new-item-name>` on the original. It
			combines with any other verdict, as often as needed.

		--magic-review-shutdown <magic-coordinator>
			Shutdown: sends DISMISSED, addressed to its member, into the
			session thread of every live spawn, and records `dismissed:
			shutdown` on the item each one works. Prints one
			`SHUTDOWN: spawn <id>: ...` line per spawn and a count. The
			other ordered endings are recorded the same way, as
			`dismissed: <reason>`: an archive (--magic-grooming-to-archived)
			and a trash (--intern-op-board-trash) dismiss the item's live
			child, and a TaskStop records `taskstop` before its signal.

		--magic-review-accept <magic-coordinator> <item-filename> [--summary <text>]
		--magic-review-return <magic-coordinator> <item-filename> (--message <text>|--from-stdin)
		--magic-review-reject <magic-coordinator> <item-filename> (--message <text>|--from-stdin)
		--magic-review-follow-up <magic-coordinator> <item-filename> <new-item-name> --from-stdin
			magic-coordinator's verdicts as reviewer of last resort: each
			does exactly what its `--member-review-*` form does, on any
			item, whatever reviewer its `review-by` names. Runs only as
			magic-coordinator.

		--member-retest-queue [--by <who>] [--about <scratch-folder>] --why <text> [--project <p>] [--file <changed-file>]... [--wait|--no-wait] [<test>...]
			Asks for a retest and, unless it is made with `--wait`, returns
			at once: it waits for no test. With `--wait` the request has the
			priority wait: it is the first the next drain takes, and takes
			alone, and the call stays until the batch has run it, then says
			how it came out (`RETEST <id> PASS|FAIL -- ...`) and ends with
			rc 0 for a pass, 1 otherwise. `--no-wait`, the default, is the
			priority no-wait; of the two the last one counts. `--project <p>`
			names the tests the testbed has registered for that project
			(`DistroAgentsTesting.fn.sh --test-register`), beside any test
			named; a project with none registered is refused.
			Prints the id of the request on stdout. A request names tests
			of the package (`sh-test/<test>.test.sh`, by `<test>`), or the
			files that were changed, each with `--file`. A changed file
			that is a test is taken as that test. Of any other file the
			tooling cannot know which tests cover it, so the request keeps
			the file, and the batch runs for it every test that has not
			passed on the state the package is in then. `--why` is one
			line on what was changed. `--by` says who asks; it may be left
			out only where the session acts as a member. The request is
			about the copy of the package this tooling runs from, which is
			the live tree for a call through the workspace's own tooling,
			or about the scratch copy `.local/temp/<scratch-folder>/source`.
			A test that copy does not hold is refused, and nothing is
			queued. The queue is the machine's own,
			`$HOME/.agents/magic-team/retest-queue`, one for the live tree
			and every scratch copy.

		--member-retest-drain [--rest [--about <scratch-folder>]]
			The tester's operation. Takes everything that waits as one
			batch and runs the union of the tests asked for, each test
			once however many requests named it, through the package's
			test runner, which caps the machine by itself. A request that
			comes in while the batch runs is in the next batch. Where any
			request that waits was made with `--wait`, someone is waiting
			for it: the batch is those alone, and the others are the next
			batch. Prints on
			stdout one line for each request it finishes,
			`RETEST <id> PASS|FAIL -- asked by <who> about <copy>: ...`,
			for the tester to pass on: nothing is posted from here. A test
			that fails fails every request that named it. One drain runs
			at a time on the machine, and a second is refused while it
			does. With `--rest`, once nothing waits, it runs every test
			that has not passed on the state the package is in, up to the
			whole suite, of the copy this tooling runs from or of the
			scratch copy `--about` names, and prints
			`RETEST rest PASS|FAIL -- about <copy>: ...`.

		--member-retest-result <request-id>...
			Where each request stands, one line each: `WAITING`, `RUNNING`,
			or the line the drain printed for it, followed for a finished
			request by what each of its tests did and the folder that
			holds the logs of the run. A finished request is kept seven
			days. Exit 1 where an id is unknown.

		--magic-config-check
			Read-only, no arguments -- the configuration check the
			main loop runs as a script. Checks magic-coordinator's own config for
			TEAM_DATA_DIRECTORY and the EMAIL_*/TRELLO_* keys below,
			and magic-team's for the four SLACK_CHANNEL_* keys,
			SLACK_BOT_TOKEN and TEAM_DATA_GIT_REMOTE.

			Prints one `<KEY>: OK`/`WARN`/`FAIL`/`SKIP` line per key
			(name only, never the value). OK = set; WARN = set but
			suspect; FAIL = required and unset, the only token
			gating the exit code; SKIP = optional and unset. Keys:
			TEAM_DATA_DIRECTORY, SLACK_CHANNEL_EVENT_TRACK,
			SLACK_CHANNEL_EVENT_ALERT, SLACK_CHANNEL_MAGIC_TEAM,
			SLACK_CHANNEL_HUMAN_OWNER, EMAIL_IMAP_HOST, EMAIL_USER,
			EMAIL_APP_PASSWORD, TRELLO_KEY, TRELLO_TOKEN.
			TEAM_DATA_DIRECTORY is optional and never SKIP: unset
			reads OK, naming the workspace's own default. Required:
			SLACK_CHANNEL_MAGIC_TEAM, SLACK_CHANNEL_HUMAN_OWNER,
			SPAWN_CLI_SERVICE, and at least one Slack token
			(SLACK_TOKEN line: magic-coordinator's SLACK_USER_TOKEN or
			SLACK_BOT_TOKEN, or magic-team's SLACK_BOT_TOKEN) -- any
			missing prints a fix and returns 1. The rest (plus
			SLACK_BOT_TOKEN, TEAM_DATA_GIT_REMOTE) are optional --
			unset reads SKIP, prints its own fix command, never
			affects the exit code.
			For credential-bearing keys (EMAIL_APP_PASSWORD,
			TRELLO_KEY, TRELLO_TOKEN, SLACK_BOT_TOKEN) that fix
			command is the `--upsert-from-stdin` form, so a secret
			never lands in argv.
			SLACK_AUTH_IDENTITY: auth.test on magic-coordinator's own
			SLACK_USER_TOKEN. OK prints her authenticated `user_id`,
			the account every user-token send is confirmed against
			(message.user). WARN when the token is unset (she posts
			only under a bot identity) or auth.test returns no
			user_id. Never affects the exit code.

		--magic-advance-batch-outcome [--team-member <team-member>] --items:<item-filename>:<outcome>:<execution-receipt>[,<item-filename>:<outcome>:<execution-receipt>]...
			Records a per-pass outcome (nudged/respawned/redispatched/
			flagged-once/no-action) plus execution-receipt for several
			board/running/ items in one call, instead of one
			--magic-advance-to-running call per item. Same-state
			(running -> running) header patch only -- never moves state,
			never spawns anything; a genuine spawn/respawn/redispatch/
			park still goes through --magic-advance-to-running/
			--magic-advance-to-parked directly.

			Item list is comma-joined, each entry colon-joined:
			`<item-filename>:<outcome>:<execution-receipt>`. The receipt
			may itself contain colons (`inline:<timestamp>`, `no-
			action:<reason-code>`, `slack:<channel>:<ts>` all pass
			through intact) but must not contain a comma. One malformed
			or failing entry is reported inline without aborting the
			rest; any failure makes the whole call exit non-zero.

		--magic-advance-to-running [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves a board item into board/running/, and/or patches its
			frontmatter, in one call. `--from-state:<state>` is
			required; `--from-state:running` is also valid (same-state,
			no relocation, existing content preserved).

			**Shared body-input shape, used by this whole
			board-move/-create family unless an entry says otherwise.**
			`--header:<upsert|append|remove>:name[:value]` applies field
			operations on the resolved body, in the order given. At most
			one of three body-input modes: `--upsert-from-stdin` (stdin
			verbatim as the new body), `--edit-script-from-stdin:<py|
			awk>` (runs a script against the existing body), or
			`--edit-patch-from-stdin` (a JSON array of exact-literal-
			substring patches) -- mutually exclusive; none given leaves
			the body unchanged except for `--header:*` ops and any
			auto-stamp the entry names.
			`--recheck-in <minutes>[±<jitter-minutes>]` upserts
			`recheck-date` to now + <minutes>, moved by a random whole
			number of minutes within ±<jitter-minutes>, as
			`YYYY-MM-DD HH:MM +0000` (UTC). Every `--magic-board-*`,
			`--magic-grooming-to-*`/`-create-*` and
			`--magic-advance-to-*` op takes it. A `--header:*` naming
			`recheck-date` in the same call wins.

			Auto-stamps `started-at` (date-time) on every move into
			board/running/.

		--magic-advance-to-parked [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/parked/ -- routine-advance's own
			check-execute-board fallback when a required spawn could not
			run. No auto-stamp: the calling step supplies condition/
			handoff-action/recheck-date/execution-receipt itself via
			`--header:*`; an item left with no recheck-date deliberately
			falls to routine-grooming's slower cadence, so this op never
			invents one.

		--magic-board-to-pending [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/pending/. No auto-stamp.

		--magic-board-to-blocked [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/blocked/. One auto-stamp:
			`execution-receipt` defaults to `blocked:<timestamp>` unless
			the caller supplies its own via `--header:upsert:execution-
			receipt:*`/`--header:append:execution-receipt:*`, in which
			case the caller's value stands.

		--magic-board-to-backlog [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/backlog/. No auto-stamp.

		--magic-board-to-parked [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/parked/ -- check-process-board's own
			move, the board-mechanical-moves counterpart. No auto-stamp
			here, and no `--magic-board-*` op stamps grooming provenance
			(the closing -to-blocked and -to-processed moves stamp their
			own fields instead). `recheck-date`/`condition` are caller-
			supplied via `--header:*`.

		--magic-append-session-transcript [--team-member <team-member>] <session-id> [--speaker <speaker-name>] [--timestamp <ISO-UTC-date-time>] (--message <verbatim-text>|--from-stdin|--from-file <path>) [--create]
			The coordinator's append to any session's tooling-written transcript,
			named by its session id: one NOTE line, as the member form appends
			to its own session. `--create` starts the transcript when the session
			has none. Runs only as magic-coordinator. Members use
			`--member-append-session-transcript`.

		--magic-board-to-processed [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/processed/ -- the RUNNING->PROCESSED leg
			whose other two legs are `--magic-board-to-blocked` and
			`--magic-board-to-backlog`. Two auto-stamps: `processed-at`
			records entry into board/processed/, stamped only when
			`--from-state:` is not already `processed` (so a same-state
			patch doesn't restart the retention clock), and a caller-
			supplied `processed-at` still wins. `execution-receipt`
			defaults to `processed:<timestamp>` unless the caller
			supplied one, in which case it stands untouched. Nothing
			else is stamped on the moved item.
			Accept releases the child: after a move into processed
			from another state, the spawn the item's `spawn-id`
			names (else the one live spawn linking it) is sent
			`DISMISSED`, addressed to its member in its session
			thread, as an explicit spawn-dismiss does. One line
			`ACCEPT-DISMISS: sent ...` or `ACCEPT-DISMISS: not sent:
			<why>` follows (no record, already ended, not running on
			this host, no thread, the sender is the child member,
			the send failed); the move's own result is never changed.
			Approval cascade (every board move or edit, whichever
			operation makes it): an `approval-*`
			arriving in board/processed/ from another state, carrying
			both `approved-by` and `approved-at`, copies them onto each
			item its `blocks` names (values that item already has
			win), and moves such an item from board/blocked/ to
			board/pending/ once every `blocked-by` it names sits in
			board/processed/, board/archived/ or board/retained/
			(retained is concluded, kept only because referenced).
			Each step is printed
			and committed with the approval move. A same-state edit
			(comment, clarification, rejection with a reason), a move
			to any other state, or an approval without `approved-by`/
			`approved-at` (a denial) cascades nothing. A malformed,
			missing, ambiguous, unreadable or frontmatter-less `blocks`
			target is reported and skipped; the approval move stands.
			Re-running changes nothing.

		--magic-board-create-running [--team-member <team-member>] <item-filename> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
			Creates a board-item directly in board/running/ --
			check-process-board's own and only creating step: the
			approval-* item raised when a board-backlog item is flagged
			for human-owner approval (the move half of that same step is
			`--magic-board-to-blocked`). `--from-state:` is rejected: a
			created item has no source state. `blocks`/`blocked-by`
			ride `--header:*` in this same write. One body-input mode
			is required.
			The name is used exactly as given; one off the naming
			Rule's `<type>-<YYYYMMDD'T'HHmm'Z'>-<matter>.md` shape is
			still created, with one warning quoting the Rule.
			The tooling completes the creation headers, never over a
			given value:
			- Frontmatter: `type` (the name's prefix), `from`
			  (`<team-member>`) and `date` (now, `date-time` format)
			  are added where neither the body nor a `--header:*`
			  gives them. `started-at` is stamped as before.

		--magic-advance-lock-acquire [--team-member <team-member>] <owner-label>
		--magic-grooming-lock-acquire [--team-member <team-member>] <owner-label>
		--magic-daily-lock-acquire [--team-member <team-member>] <owner-label>
		--magic-retro-lock-acquire [--team-member <team-member>] <owner-label>
			Takes the calling routine's lock before any other step. Prints
			`ACQUIRED` (rc 0) on a fresh take; `RECLAIMED_STALE:prev_owner=
			...:age=...s` (rc 0) when the previous holder went stale;
			`ACTIVE:owner=...:state=...:recheck_date=...` (rc 1) when
			another holder genuinely has it -- rc 1 means do not start.
			<owner-label> names the running process, not a chat-session id.
			Takes no options; any further argument is rejected.

			--magic-daily-lock-acquire only: after a successful take, one
			more line, `first-today: yes|no` -- no when the daily note's
			`last-close-date` is today's local date.

			--magic-advance-lock-acquire only, and only with
			TEAM_DATA_GIT_REMOTE set: the board is resynced and the lock
			note checked against the branch head before anything is
			written, so three further rc 1 refusals are possible.
			`LOCK_CONFLICT` -- the local lock note carries an unresolved
			merge, a committed conflict marker, or an uncommitted edit.
			`LOCK_STALE` -- the local lock note is not the one on the
			branch head. `LOCK_UNCHECKABLE` -- the resync or fetch could
			not answer, so ownership is unknown. All three mean do not
			start, and nothing has been written.

			--magic-advance-lock-acquire only, after a successful take:
			the routine's housekeeping runs, by the tooling itself, so
			the scan that follows already shows the result. It closes
			what a dead spawn left open: a spawn record still started
			whose session is gone (this host: no live process, no open
			ask and nothing under its sandbox changed in the last 15
			minutes; any other host: no open ask and nothing changed in
			24 hours; a change is any file under its sandbox or under
			`.local/agents/sessions/<id>/`, which is where a waiting
			session keeps its Wait state) is closed with the
			ended-without-close outcome; the dispatch item it links is
			closed with that outcome too (a created dispatch item
			moves to board-review, a reused item stays where it is); a
			running dispatch item whose record already ended is closed
			with that record's own outcome and moves to board-review,
			and one with no record that has not changed in 24 hours is
			closed with the ended-without-close outcome and moves to
			board-review. Nothing about this is written into the take's
			output: each action is one line of the daemon line, and
			they go as one post into the event-track thread of the
			calling spawn's coworking session, when it has one. A
			second take changes nothing more.

			And it starts the control thread of each session of this
			workspace that is not finished and has none alive: a run of
			it is alive on this host, or the record of a run of this
			host is still open. It is the check
			`--manager-session-control-start --all` makes, which each
			iteration of the main loop makes too. A thread is the
			tooling's own process and no agent, started detached and
			never waited for. What was started is one more line of that
			same post, and no line of the take's output; a thread that
			could not be started is one warning on the daemon line, and
			the take goes on.

			It also hands a board-review item whose `review-by` names a
			session that has ended (no live row for it, or no row and
			the item unchanged for 24 hours) to `magic-coordinator`
			by rewriting `review-by`. A member name, `human-owner`, a
			live session and a missing `review-by` stay as they are.
			Accepting or returning an item stays the caller's own call.

		--magic-advance-lock-refresh [--team-member <team-member>]
		--magic-grooming-lock-refresh [--team-member <team-member>]
		--magic-daily-lock-refresh [--team-member <team-member>]
		--magic-retro-lock-refresh [--team-member <team-member>]
			Re-asserts a held lock so a long run is not mistaken for a
			crashed one. Prints `REFRESHED` (rc 0), or `NO_LOCK_HELD` (rc 1)
			when nothing is held. Takes no options; any further argument is
			rejected.

		--magic-advance-lock-status [--team-member <team-member>]
		--magic-grooming-lock-status [--team-member <team-member>]
		--magic-daily-lock-status [--team-member <team-member>]
		--magic-retro-lock-status [--team-member <team-member>]
			Read-only, returns 0 always -- including when free, so a caller
			can check before deciding to start. Prints `NO_LOCK` when free,
			or `ACTIVE:owner=...:state=...:recheck_date=...` when held --
			read from the lock note's own frontmatter. Takes no options;
			any further argument is rejected.

		--magic-advance-sleep-run
			Read-only, no arguments -- a fixed-duration pacing operation in
			routine-advance's operation group.

		--magic-spawn-proxy [--team-member <team-member>] [--from-stdin] [--from-file <path>] [--from-board <board-item-name> [--board-state <state>]...] [--from-vault <vault-item-name>] [--from-audit <audit-item-name>] [--session-thread:event-track|magic-team] [--session-name-or-comment <text>] [--description <text>] [--wait]
			Spawn relay: executes a spawn prompt via
			DistroAgentsConsole.sh. Body is stdin (default),
			--from-file, --from-board, --from-vault, or
			--from-audit (exactly one); empty body is rejected,
			failing immediately with "empty spawn context".
			**Hazard: no secret belongs in a spawn brief** -- the
			console puts it on the CLI's own command line, visible
			in `ps` on the host.

			A --from-board/--from-vault/--from-audit call reuses
			that item as its tracking document, printing
			`DISPATCH_DOC=reuse` + `TRACKING_ITEM=<name>`. A
			stdin/--from-file call creates a fresh `dispatch-*`
			board-item in board-running, printing `DISPATCH_DOC=
			create` + `DISPATCH_ITEM=<name>`: the prompt becomes
			its "## Brief", frontmatter `status: dispatch-started`.
			On completion, `status:` moves to
			`dispatch-succeeded`/`dispatch-failed`, a "## Result"
			section is appended, and the item moves to
			board-review. A session that died without closing is
			closed later by the advance routine's lock, with the
			ended-without-close outcome. No `RECEIPT_FILE` key is
			ever written.

			The spawned session gets its own coworking session's
			thread as `session_thread_ts`, separate from the
			event-track thread below.

			Default mode is async (`STATUS=started` + `PID`);
			--wait blocks for completion, returns non-zero on
			failure. Printed keys: `RECEIPT_ID`, `SESSION_ID`,
			`SESSION_THREAD`, `DISPATCH_DOC`,
			`TRACKING_ITEM`/`DISPATCH_ITEM` always; `STATUS`
			always, with `PID` (async) or `EXIT_CODE`+`LAUNCHED`
			(--wait); `OUTPUT_FILE` wherever a file is written
			(`.local/agents/sessions/<spawn-id>/session.log`). On --wait:
			`SETUP_STATUS=cli-not-configured` (no external CLI
			selected), `=cli-not-authenticated` (CLI present, not
			signed in, no API key), `=console-stale` (deployed
			console too old, refused before spawning), and
			`TIMEOUT_SECONDS=<seconds>` when the wait bound fired.
			Wait is unbounded unless magic-team's
			`SPAWN_WAIT_TIMEOUT_SECONDS` sets one (0 = none). A
			harness leg gets `--tier <value>` when
			`SPAWN_HARNESS_TIER` holds one (light/normal/heavy);
			unset, no tier is passed.

			On --wait, `STATUS=succeeded` means the child exited
			0, the wait bound didn't fire, and a launch happened;
			anything else is `STATUS=failed`.
			`LAUNCHED=true|false` is --wait-only, so a real
			failure and a silent no-launch aren't confused.

			Every coworking session has one tooling-maintained
			thread in event-track (when `SLACK_CHANNEL_EVENT_TRACK`
			and a bot token are set, else skipped silently). The
			spawn that starts a session opens it with its start
			post; one that joins posts its start as a reply
			there. Each participant's lines and its own end post
			go into it -- never reaches stdout, and a failed post
			never fails the spawn.

			Every spawn also belongs to a coworking session, and
			the session that spawns is that session: a spawn made
			from inside a session joins it with no new thread, and
			a caller that is a session of its own, such as a
			native client session, is the coworking session of
			every member it brings in. With the first of them
			the tooling seeds the session's thread in magic-team
			with the session's own root post, "Session <name>,
			started by <member>", posted by the bot with no
			author line: the name is --session-name-or-comment,
			else the session id, and the member is the one whose
			session brings the others in, left out where it is
			not known. The tracking thread's session box links
			to that root. Each member then says it joined, with
			its own description, addressed to the member whose
			session brought it in, or to nobody where that is no
			member. --session-new starts a separate session
			with a thread of its own, and --session-id <id> joins
			another one. A caller with no session at all, a bare
			command line, starts one as before. Where the thread
			is unknown, or the post fails, one stderr warning is
			printed and the spawn goes on. The member's session
			starts in the workspace the spawn is run from, with
			that workspace's settings, skillset and access rules
			for it. A member that is not set up there is refused
			before anything starts, with one message naming the
			member, that workspace, what is missing and where on
			this machine the member is set up. A client-* member
			starts there like any other.
			--session-thread:event-track starts a session alone,
			with its tracking thread only and no session thread,
			and skips the magic-team post -- used by the main
			loop's own solitary spawns. The first member such a
			session brings in opens its session thread in
			magic-team, as for a native client session. A tracking
			thread is never a session thread: one handed down as
			such by a session started before this rule is not
			taken, and a session thread is opened in magic-team.
			A run that ends with no handback, or with a question
			of its own open, has that said twice: as a tracking
			box in the session's tracking thread, and as a message
			in the session thread, addressed to the member that
			brought it in.
			--description <text> says in the caller's words what
			the spawn is for. It is passed on unchanged, kept on
			the dispatch item and the spawn record, and shown on
			the spawn's start post in event-track.

			The brief ends with a "## Your session thread" section
			carrying `session_thread_ts: <channel>:<ts>` -- the
			value --member-comms-slack-send-message takes as
			target and --member-comms-slack-read takes with
			--thread. If the opening post failed, it says so and
			asks the session to post its own thread. A session
			that starts alone is told it has none yet, and that
			one is opened when it brings a member in.

		--magic-spawn-session (--routine <selector>|--routine-default) [--session-name-or-comment <text>] [--description <text>] [--spawn-cli-service <cli-name>] [--spawn-settings-workspace <workspace-name>] [<team-member>...]
			Starts a coworking session and spawns its initial members
			in one call. Task text comes from stdin. Exactly one of
			`--routine <selector>` | `--routine-default` is required
			-- the selector is a full routine filename or part of
			one, resolved once so every spawned member carries the
			same routine file; that spawn's own spawn-prepare-brief
			block is then automatic ahead of the task text.
			`--description <text>` says in the caller's words what the
			session is for. Every spawn of the call gets it unchanged:
			it is kept on each dispatch item and spawn record, and
			shown on each start post in event-track.
			`--spawn-cli-service <cli-name>` and
			`--spawn-settings-workspace <workspace-name>` are the two
			spawn settings a task may carry of its own: the agent CLI
			service the spawns run on, and the workspace this machine
			knows whose CLI service and credentials they are started
			with, in place of this one. Every spawn of the call gets
			them unchanged, and a value the spawn refuses stops the
			call at its first spawn.

			Given no `<team-member>...` names, the spawned members
			come from the resolved routine's own `executors`
			frontmatter line, a plain comma-separated list of real
			members. Anything else -- `magic-team`/`*` (any-member
			shorthand) or free prose -- names no spawnable roster and
			is refused, asking for explicit `<team-member>...`
			instead.

			A member whose `SKILL.md` says `status: reference-only` is
			an identity record, such as `human-owner`, and is never
			started: a call that names one, or whose routine's
			`executors` do, is refused in one line before its first
			spawn, so no member of the call is started. A name that is
			no member is refused the same way, before the first spawn.
			`magic-team` is the team itself and no member of it, and is
			never started either: a call that names it among its
			members is refused the same way, and starts none of them.
			A routine whose `executors` are `magic-team` alone still
			means any member, as above.

			The first member spawned starts the session; every
			further one joins it by the session id the first spawn's
			own output reports. A routine's own `invitees` are never
			spawned here -- the session's own executor invites them
			separately.

			Prints `SESSION_ID` (what further spawns join by),
			`ROUTINE` (the resolved filename), `MEMBERS` (spawned
			members, space-separated).

		--routine-run-inline <routine>
			ThisSession's operation (DistroAgentsSession.fn.sh): a routine run inline in
			the calling session, like a call that inherits the caller's session, thread
			and context and gives back only its result. Prints `RUN-INLINE: <routine
			file>`, then the routine's text as the run reads it: its Steps, with the
			Opening steps, Closure steps, local rules and tooling of
			`magic-team.inline.routine` mixed in in place of those of its session kind
			(steps designed for inline, none of a session's, such as the reflections),
			without the routine's frontmatter and without its Maintainer Notes.
			<routine> is a routine's file name or a part of one, exactly one file, as
			`--routine` takes it. Arguments of the routine (a `<team-member>`) stay in the
			caller's prose, as for any routine.
			The routine's own `input-scan-def:` scans are run now, through the runner the
			spawner uses, for the calling member; the result is saved to
			`input/input-scan.<routine>.md` of the caller's sandbox and named in a line
			ahead of the steps, as the spawner names the scan of a session it starts. From
			no sandbox (a console) the result follows the steps. A scan that fails does
			not stop the call: the file says it failed and what it said. A call from no
			member's session, for a routine that declares a scan, is refused.
			Refused with its reason for no or more than one routine argument, or a
			routine that matches no file or several.

		--update-routine-state [--document <note>] [--header:upsert:<name>:<value>]... [--header:remove:<name>]... [--from-file <path>|--edit-patch-from-stdin]
			ThisSession's operation (DistroAgentsSession.fn.sh). Updates the state
			record of the routine the calling session runs: the document its
			spawner locked for the session (`routine-lock-document:`). The session
			knows its routine and that document, so the call names no routine and no
			path, and any participant of the locked session may make it.
			Participants never lock or unlock it; they update it with this, as often
			as they have updates, and each update is committed, and pushed where a
			git remote is set, before the call returns.
			`--document <note>` names the note, and is needed only where the session
			locked several (a routine that runs another inline).
			Input source is exactly one of: stdin (default), `--from-file`,
			`--edit-patch-from-stdin` (stdin is a JSON patch array for exact-literal
			replace operations on the stored record), or header edits of the stored
			record, `--header:upsert:<name>:<value>` and `--header:remove:<name>`.
			Empty content is rejected. Refused with its reason where the call comes
			from no spawned session, the session holds no lock, or the lock has been
			given back.
			The lock-owned fields (type, from, date, owner, state, recheck-date,
			session-id) stay as the document has them, whatever the content gives.
			While the note says `state: <routine>-running`, every state write also
			refreshes the lock: `recheck-date` is set to now + 120 minutes, so a
			session that keeps writing its state needs no separate refresh call
			for it. Any other state is carried over untouched.

		--get-session-thread [--own]
			ThisSession's operation (DistroAgentsSession.fn.sh). The session thread,
			read from the session's one store of its messages, the session chat file:
			all of it, history included, in the order of the file, each message as
			the file holds it (`<time> <from> -> <to>:` and its body). With `--own`
			only the caller's own traffic: the messages it sent, the ones addressed
			to it, and the ones mentioning it (`@<member>`, or its Slack account).
			No network call is made and nothing is changed, the caller's pointer
			included. A message of another conversation, a reply to a post of the
			caller and a message never posted are not the thread. Refused with a
			plain line from a call of no session, a session with no thread, and
			`--own` from no member's session.

		--get-session-channel-id
			ThisSession's operation (DistroAgentsSession.fn.sh). Prints the thread of
			the calling session, `<channel>:<ts>`: the one the `session-current` alias
			names. Refused with a plain line where the session has none.

		--post-session-channel [--address-to <team-member>]... (<text...>|--from-stdin)
			ThisSession's operation (DistroAgentsSession.fn.sh). A post to the
			session thread, and to nowhere else: the team's Slack send
			(`--member-comms-slack-send-message`) as the calling member, with no
			target, so the first word is text. The send's other options pass
			(`--address-to`, `--from-stdin`, `--identity-bot`); the message is recorded
			in the session chat file first and posted after, as every send of the
			session is. Refused, and nothing posted, from a call of no member's
			session or no session, a session with no thread, and a call with no text.

		--wait-session-channel [--to-@me] [--to-@here] [--to-@any] [--wait-timeout <seconds>]
			ThisSession's operation (DistroAgentsSession.fn.sh). Wait, on the session
			channel alone: the session thread as the session chat file holds it, read
			by the caller's own floor pointer, the one Wait's floor and every tool
			return use. Prints what Wait prints. With no option it waits for the
			caller's floor: the executor of the session is given every message of the
			thread, a participant the ones that name it. `--to-@me` waits for the
			messages addressed to the caller or mentioning it, `--to-@here` for the
			ones addressed to all, `--to-@any` for every one; they combine as a union.
			Nothing is lost and nothing comes twice: a message the options pass over
			that the floor owes the caller stays for the floor, and what this call
			delivered beyond it is marked delivered. The caller's own posts never come
			back. `--wait-timeout` is Wait's bound; with none the wait returns on an
			arrival. Refused, and nothing waited on, from a call of no member's session
			or no session, and a session with no thread.

		--get-dispatch-text
			ThisSession's operation (DistroAgentsSession.fn.sh). The dispatch of the
			calling session as its run was given it, from the sandbox's `input/`:
			`dispatch.md`, the copy of the board item and `input-scan.md`, each a
			section of its own, mixed by the markdown merge. Alone, `dispatch.md` is
			printed as it is. `conversation.md` is the thread (`--get-session-thread`);
			`pointers.md` and the MAGIC copies are references the dispatch names.
			Refused with a plain line from a call of no spawned session, and a sandbox
			with no dispatch.

		--executor-checkpoint-push [<name>]
			ThisSession's operation (DistroAgentsSession.fn.sh), for a single-participant
			routine that names it in its `allows:` (`executors:--executor-checkpoint-push`).
			A snapshot of this run's conversation under <name> (`checkpoint` where none is
			given), made by the harness at the end of the round the call was made in, when
			every call of the round has its result. A snapshot of a name already held
			replaces it. `armed` is the tooling's own and is made for the run. Only the
			conversation is kept: the files and the sandbox are what the run makes of them.
			In the run of a native client, and where the routine does not allow it, it
			makes no snapshot, says so in a NOTICE line, and the session goes on.

		--executor-checkpoint-rewind [<name>] [--from-stdin]
			ThisSession's operation (DistroAgentsSession.fn.sh), as --executor-checkpoint-push
			allows it. At the end of the round, the conversation returns to the snapshot
			of that name (the newest where none is named), the rounds after it are dropped,
			and the snapshots taken after it with them. Tools and system text are not touched,
			so the cached prefix stays the one the run began with. `--from-stdin` gives the
			return a dispatch: the text on standard input is the next input of the run,
			a message after the snapshot, or, for `armed` of a run started with a prefetch,
			the task block after the task (the task, a blank line, the text -- never the text
			of an earlier return). Refused, and nothing done, for a name this run does not
			hold, and for `--from-stdin` with no text.

		--executor-checkpoint-exit
			ThisSession's operation (DistroAgentsSession.fn.sh), as --executor-checkpoint-push
			allows it. Drops every snapshot of the run at the end of the round; the run goes
			on as a run that takes none.

		--idle-wait [--wait-timeout <seconds>]
			ThisSession's operation (DistroAgentsSession.fn.sh). Wait for new input and,
			on an arrival, return to the run's checkpoint with the arrival as the next
			input: `opening` where the run holds it (the kind routines' last Opening step),
			else `armed`. The rounds of each piece of work then do not pile up in the
			conversation, and the model spends nothing while it waits. It waits on what the
			routine the session runs waits on: the floor (the replies to the run's own posts
			and the session thread), and the scans the routine itself declares with
			`input-scan-def:`, by name, as `scan:` sources (a work-duty run wakes on its
			work-duty input); with no scan declared, on the floor alone. A scan wakes the
			wait when its report differs from the one the session was last given (the first
			time, with the report it has), the cache of the scan being five minutes. With no
			`--wait-timeout` the harness waits on through the quiet rounds of the session's
			wait without waking the model. What is no arrival returns nothing: the bound of
			`--wait-timeout` run out (Wait's bound), a wait that could not be made, a source
			never read, and a dismissal are given to the model as a message, and its
			conversation stays. A run that holds no snapshot is given the arrival the same
			way. Only a single-participant session has it (a routine of kind standalone
			with one executor and no invitee) and a separate spawn that runs no routine;
			for the run of a native client and for a session of several participants it
			waits on nothing, says so in a NOTICE line, and Wait is the way to wait there.
			The wait is made by the harness of the run at the end of the round, so the
			answer of the call is only read where nothing was returned.

		--magic-test-report-send [--team-member <team-member>]
			Sends the hourly test report, run by hand or from a console; nothing
			schedules it. <team-member> must be
			magic-coordinator. Prints `NOT_DUE:last-test-email-sent=...:
			due-in=<n>s` and returns 0, sending nothing, until an hour
			has passed since the note's `last-test-email-sent`. Once due:
			builds the body from the board counts and the board active
			items, sends it through
			--member-comms-email-send (text group report) to human-owner's
			EMAIL_USER, stamps `last-test-email-sent`, and prints
			`SENT:to=<address>:last-test-email-sent=<timestamp>`. rc 1,
			with nothing stamped, when EMAIL_USER is unset, the
			state note does not exist yet, or the send fails.

		--magic-state-note-lock-acquire [--team-member <team-member>] <owner-label>
			Takes the lock of the coordinator's state note. Prints
			`ACQUIRED` (rc 0) on a fresh take; `RECLAIMED_STALE:prev_owner=
			...:age=...s` (rc 0) when the previous holder went stale;
			`ACTIVE:owner=...:state=...:recheck_date=...` (rc 1) when
			another holder genuinely has it -- rc 1 means do not start.
			<owner-label> names the running process (e.g. "main-loop"), not
			a chat-session id. Takes no options; any further argument is rejected.

		--magic-state-note-lock-status [--team-member <team-member>]
			Read-only, returns 0 always -- including when free, so a caller
			can check before deciding to start. Prints `NO_LOCK` when free,
			or `ACTIVE:owner=...:state=...:recheck_date=...` when held --
			read from the lock note's own frontmatter. Takes no options;
			any further argument is rejected.

		--magic-state-note-read [--team-member <team-member>]
			Reads back the whole record of the coordinator's state note,
			verbatim. Outputs `NO_STATE` if nothing is stored yet.
			Read-only.

		--all-sessions [--kind standalone|coworking|ad-hoc]
			TeamDispatcher's operation (DistroAgentsDispatcher.fn.sh), for agent tools, the
			shell console and shell automation alike. The sessions of this workspace with
			their runs, the rows `--manager-session-list` prints (TAB-separated rows, their
			form that entry's), by the very function it calls: one `session` row for each,
			one `run` row for each of its runs, one `counters` row last. `--kind` keeps the
			sessions of one kind and their runs (the counters row stays): the kind of the
			routine the session's run records, `requires-session-kind:` of that routine's
			file, or `ad-hoc` for a start whose run records no routine. A word that is no
			kind is refused, rc 1, with the three named, and nothing is printed.

		--active-sessions [--kind standalone|coworking|ad-hoc]
			TeamDispatcher's operation (DistroAgentsDispatcher.fn.sh). The rows of
			`--all-sessions` for the sessions that are not finished and can be acted on from
			this host (running, waiting or unclosed), as `--manager-session-list --active`
			prints them; `--kind` as there.

		--waiting-sessions [--kind standalone|coworking|ad-hoc]
			TeamDispatcher's operation (DistroAgentsDispatcher.fn.sh). The rows of
			`--all-sessions` for the sessions the list reads as `waiting`: no live process,
			and an ask of the session or of one of its runs still open. Each session with its
			runs, and the counters row; `--kind` as there.

		--session-record <session-id> [--run]
			TeamDispatcher's operation (DistroAgentsDispatcher.fn.sh). One session in full:
			its rows as the list prints them, what it was started for, and each run's record
			and store, the rows `--manager-session-read` prints, by the very function it
			calls. `--run` takes the id as a run's own and shows that run. It reads the
			records and stores of that one session, never another's. Refused, rc 1, with no
			id, an id no record carries, and a word it does not know.

		--routine-completed <routine> --since "<YYYY-MM-DD HH:MM>"
			TeamDispatcher's operation (DistroAgentsDispatcher.fn.sh): the predecessor
			question, decided from the run history. <routine> is named as `--routine` names
			one, a file name or part of one, exactly one file. The time is of this host, as
			the spawn records write theirs. Prints the run of that routine that closed
			`spawn-succeeded` last at or after the time, as one `run` row (the session id,
			the spawn id, the member, the status, started-at, resolved-at, the routine), rc 0.
			Else it prints `NOT-COMPLETED: <routine file> since <time>`, rc 1: a run that
			failed, one still open, one that closed before the time, and a run of another
			routine are none. Refused, rc 1, with a time of another form, no `--since`, and
			a routine that matches no file or several.

		--current-flags
			TeamDispatcher's operation (DistroAgentsDispatcher.fn.sh). The flags of the
			schedule now, derived from the settings and the clock and never stored: six
			lines, `worktime`, `weekend`, `holidays`, `emergency`, `overtime`, `learning`, each
			`<flag>: yes` or `<flag>: no`. `holidays` is an override set by hand: while it
			holds, `worktime` reads `no (holiday)` whatever the hours say; `emergency` and
			`overtime` are not overridden by it. `worktime` falls out of the timezone, the hours
			and the days (`MDAT_SCHEDULE_WORKTIME`) and the clock; `weekend` out of the
			timezone, its days (`MDAT_SCHEDULE_WEEKEND`) and the clock. Where they are
			not set a line reads `no (not set)`; worktime days of `workdays` or `weekend`
			with no weekend set read `no (weekend not set)`. An override that has an end
			shows the seconds left, `yes (3600 seconds left)`. Read-only.

		--override-flag [--no] <flag> [<ttl>]
			TeamDispatcher's operation (DistroAgentsDispatcher.fn.sh). An override of a flag,
			kept as a setting of the `magic-team` scope: `emergency` is set with a TTL in
			whole seconds (`emergency 3600`), prolonged by a second call (its end is the TTL
			from then) and cleared by `--no`; `overtime` is for outside worktime, ends at
			its TTL or, with none or a later one, when normal worktime starts, and is
			refused during worktime; `holidays` is set with a TTL or, with none, until it
			is cleared, at any hour, and while it holds `worktime` is off (`no (holiday)`);
			`learning` is on or off and takes no TTL. `--no`
			clears the override and takes no TTL. `worktime` and `weekend` are derived and
			have no override. Prints the flag's line as `--current-flags` would. Refused,
			rc 1, with a flag that is none of the six, a TTL that is no whole number of
			seconds, or an emergency with none.

		--set-country <iso-code-2-or-3-letters>
			TeamDispatcher's operation (DistroAgentsDispatcher.fn.sh). Sets
			`MDAT_SCHEDULE_COUNTRY` of the `magic-team` scope, upper case, and prints
			`<setting>: <value>`. Two or three letters; any other form is refused, rc 1,
			and nothing is stored.

		--set-timezone <tz-spec>
			TeamDispatcher's operation (DistroAgentsDispatcher.fn.sh). Sets
			`MDAT_SCHEDULE_TIMEZONE`, the zone the schedule's times are in, a zone name this
			system knows, such as `Pacific/Auckland`; any other is refused, rc 1.

		--set-worktime <start> <until> <days-of-week>
			TeamDispatcher's operation (DistroAgentsDispatcher.fn.sh). Sets
			`MDAT_SCHEDULE_WORKTIME`: the hours, `HH:MM` each, the start before the until,
			and the days, `workdays`, `weekend`, `daily` or a list such as `mon,thu`.
			`workdays` is the days the weekend setting leaves. Refused, rc 1, otherwise.

		--set-weekend <days-of-week>
			TeamDispatcher's operation (DistroAgentsDispatcher.fn.sh). Sets
			`MDAT_SCHEDULE_WEEKEND`: a list of days such as `sat,sun`. `workdays`,
			`weekend` and `daily` are no weekend and are refused, rc 1.

		--routine-due <routine>
			TeamDispatcher's operation (DistroAgentsDispatcher.fn.sh): whether a routine is
			due to start now by its own autorun declaration, `runs-at: <days> <HH:MM>` and
			`runs-after: <routine>` of its frontmatter, read against the schedule's
			settings, the clock and the run history. <routine> is named as `--routine`
			names one. The day, in the schedule's zone, is the period: the routine is due
			once on each of its days, from its time on, which is the earliest start.
			rc 0 and `DUE: <routine file>` when it is due, and after a predecessor
			`AFTER: <predecessor file> <spawn id of its run>`; rc 1 and `NOT-DUE:
			<routine file>: <why>` when it is not (no autorun, before its time, not one of
			its days, the weekend not set and its days needing it, or already run today by
			a run of any status); rc 2 and `REFUSED: <routine file>: <predecessor file> has
			not completed today` when the predecessor it follows has not completed
			(spawn-succeeded) today: where a predecessor is named it is the trigger, and the
			chain needs no waiting state. rc 3, nothing on stdout, for a call that cannot be
			understood. A chain that stopped is never silent: when the last day the routine
			was to run has passed with the predecessor not completed on it and the routine
			not run on it, the answer opens with `ESCALATE: <routine file>: <predecessor
			file> did not run on <date>, so the chain is broken`, and one line goes to the
			event-alert channel, once for that day. A day that ended before the routine was
			first asked about is not escalated.

		--rebuild-stats
		--stats-check
			TeamDispatcher's operations (DistroAgentsDispatcher.fn.sh) on the runs and stats
			store, `.local/agents/stats/`: three index files, `runs.index` (a row for each run
			record: member, routine, status, times, day, workspaces, preset, the credential's
			name, tokens in, cache-read, cache-write and out), `routines.index` (a row for each
			routine: its runs, succeeded, failed and running, when it last ran and how, when
			it last SUCCEEDED, its tokens and members) and `tokens.index` (the tokens by day,
			member, routine, preset and credential). The store is an index and never a source:
			every fact in it is read from the run records (`spawned/<session>/<run>.md`) and
			the token files the harness keeps (`sessions/<run>/tokens`). `--rebuild-stats`
			derives it whole and prints `STATS: rebuilt <runs> run(s), <routines> routine(s),
			<token rows> token row(s)`. `--stats-check` brings it up to date, derives the same
			whole in a scratch place and compares: rc 0 `STATS-CHECK: same (<n> run(s))`, rc 1
			and the rows that differ, which is a missed read or a hand edit. Neither takes an
			option.

		--run-stats [--member <m>] [--routine <r>] [--status <s>] [--since <YYYY-MM-DD>] [--until <YYYY-MM-DD>]
		--run-history [--member <m>] [--routine <r>] [--since <YYYY-MM-DD>] [--limit <n>]
		--routine-stats [<routine>]
		--token-stats --by day|member|routine|preset|credential [--since <date>] [--until <date>] [--member <m>] [--routine <r>] [--preset <p>] [--credential <c>]
			TeamDispatcher's operations (DistroAgentsDispatcher.fn.sh), reading the stats
			store, which each brings up to date first: the records and token files changed since
			the index are read again and the rows of those runs replaced, the rest stay (a
			record removed is dropped only by `--rebuild-stats`). `--run-stats`: the run rows
			oldest first, as `run <columns of runs.index>`, filtered. `--run-history`: the
			same rows, the history view, NEWEST first, the last `--limit` of them where it is
			given (a whole number above 0). `--routine-stats`: the
			rows `routine <columns of routines.index>`, by routine, one or all; the routine is
			an entity with its runs attached, so the row says when it last ran and, beside it,
			when it last succeeded (a routine failing every night has a recent run and an old
			success); rc 1 and a line on stderr for a routine with no run. `--token-stats`: the
			tokens summed by the one key asked for, as `tokens <key> <runs> <in> <cache-read>
			<cache-write> <out>`, by key, within the dates and the other keys given; a run
			with no preset or credential is under `-`. A date is YYYY-MM-DD, as the record
			writes the day of `started-at`. The stats are of this workspace: every member's
			runs recorded here, with the workspace each executed and was paid in.

		--add-source-docs|--add-board-items|--add-vault-items|--add-inbox-items [<selector>] <query>
			TeamKnowledge's call (DistroAgentsKnowledge.fn.sh, no operation word: the
			sources added and the query are its options), the query over what the team
			has written, in markdown, or in JSON under `--mdat-output-format json` before
			the first word. The sources, each added by its option: `--add-source-docs`,
			MAGIC.md, README.md and docs/**.md of the projects selected, of each one's
			repository `util.repository-*` and of the workspace's `util.workspace-*`;
			`--add-board-items`; `--add-vault-items`, any text file of the team data
			root's `vault/`; `--add-inbox-items`, the acting member's own inbox, incoming
			and processed, the console reads every member's. The selector is that of
			`ListDistroProjects` (`--select-*`, `--filter-*`, `--remove-*`), read from
			the workspace's source and deciding whose docs `--add-source-docs` reads;
			none given, every project of the workspace. The query starts with AND:
			`--query-keyword <text>` (a line holds it, in any case), `--query-pattern
			<regex>` (an extended regular expression on a line), `--query-glob <glob>`
			(a shell glob on a whole line), each one or many, and `--query-open-and` or
			`--query-open-or` ... `--query-close` for a group. A term holds of a section
			(a heading down to the next heading; the lines ahead of the first heading
			are one) when one of its lines answers it. The result is the sections that
			answer, each source a section of its own named by its path (below the
			workspace, or below the team data root), merged by `--intern-merge-md-files`;
			in JSON, `{"entries":[{"source","store","section","snippet"}]}`. A call with
			no source, no term, a group not closed, a close that closes none or an
			option it does not know is refused, rc 1, with nothing read. No vector store.

		--collect-contact --id <slug> [--name <text>] [--organisation <slug>] [--role <text>] [--relationship <text>] [--how-to-meet <text>] [--owner yes|no] [--slack <team>:<id>]... [--slack-handle <team>:@<handle>]... [--slack-conversation <team>:<id>]... [--email <address>]... [--drop <coordinate>]... [--note <text>] [--correct] [--reached-by <member>]
			Contacts' operation (DistroAgentsContacts.fn.sh), the people subsystem: every
			member uses it, the coordinator and the client-* members most. Records a person,
			or fills the record of one recorded already, in the team data root's
			`contacts/persons/<id>.md`: a record of the team, not of a member, whose
			`reached-by:` lists the members that hold it, the calling member added. A Slack
			coordinate carries its Slack team, `<team>:<value>`, the identity scope of the
			workspace it belongs to, because an id is unique within one workspace only.
			An empty field is filled, a known one stays and is said to (`KEPT: ...`) unless
			`--correct` replaces it, the lists (the coordinates, who holds it) only grow, and
			`--drop` removes a coordinate by the value as written. `--note` adds a line to the
			record's log, which also says in one dated line what each call changed. A new
			contact needs a name or a coordinate; `--organisation` names one recorded first.
			A shape that is none (an id, a Slack coordinate without its team, an e-mail), a
			value too long and an option it does not know are refused, rc 1, with nothing
			written. Prints `CONTACT: <id> created|updated|unchanged`. A call from no member's
			session names the member that holds the contact with `--reached-by`. The record
			is written whole, by a rename, and nothing is written for a call that adds
			nothing. A contact's access is not recorded in it: the permission model holds it.

		--collect-organisation --id <slug> [--name <text>] [--domain <text>] [--note <text>] [--correct]
			Contacts' operation (DistroAgentsContacts.fn.sh). Records an organisation, or
			fills one, as `--collect-contact` does a person. Prints `ORGANISATION: <id>
			created|updated|unchanged`.

		--find-contact <value> [--team <scope>] [--reached-by <member>]
			Contacts' operation (DistroAgentsContacts.fn.sh). The contacts a value names, as
			TAB-separated rows `contact <id> <display-name> <organisation> <reached-by>
			<matched-on>`: by its id, a name (equal, or contained from three characters), a
			Slack id or conversation (with or without its team), a handle (with or without
			`@`) or an e-mail (without regard to case); `matched-on` says which. `--team`
			keeps the Slack coordinates of one team, `--reached-by` the contacts a member
			holds. rc 1 with none, saying what was searched.

		--all-contacts [--organisation <slug>] [--reached-by <member>]
		--all-organisations
		--contact-record <id>
			Contacts' operations (DistroAgentsContacts.fn.sh), read-only. `--all-contacts`:
			every contact, a row each as `--find-contact` prints it (the last field `-`),
			by id, with the same two filters. `--all-organisations`: a row each, `organisation
			<id> <display-name> <domain> <how many contacts>`. `--contact-record`: the record
			of one contact, whole; rc 1 for an id not recorded. A store that is not there is
			empty, and a read creates nothing.

		--contacted-by <value> [--team <scope>]
			Contacts' operation (DistroAgentsContacts.fn.sh): being contacted by a contact.
			The sender looked up as `--find-contact` does: its record, then what the
			permission model says it holds standing, the three tiers a request falls in
			(Ingest, Basic, Recorded access) and the next step, the text of the template
			`Contacts/contacted-known`. A sender nobody recorded is said so with the next step
			(`Contacts/contacted-unknown`), rc 1; a value that names more than one contact
			prints their rows and asks for which, rc 1.

		--reach-contact <id>
			Contacts' operation (DistroAgentsContacts.fn.sh): reaching a contact. Its
			coordinates by channel, how to meet it, and the send lines for each channel, the
			text of the template `Contacts/reaching`, a line left out where the contact has
			none. A send to an address that is no coordinate of a contact the sender holds is
			refused by the send itself.

		--contact-access <id> [--tool <tool> --target <target>] [--session-id <id>]
			Contacts' operation (DistroAgentsContacts.fn.sh). What the contact may ask for, as
			the permission model says it: with a call, the chain's answer, `GRANT: contact
			<id>` for a standing grant of its record or `GRANT: session <ref>` for a session
			grant given to it in the session (the calling session unless `--session-id`), else
			`NO-GRANT: contact:<id> <tool> <target>` and rc 1; with none, a row `ALLOW <tool>
			<target> <granted by> <time>` for each standing grant. The file keeps no access of
			its own.

		--escalate-contact <id> --tool <tool> --target <target> --asked <text> [--session-id <id>]
			Contacts' operation (DistroAgentsContacts.fn.sh), for a member that has assessed a
			contact's request as needing the human-owner's ruling. The permission model
			records the refusal for `contact:<id>` in the session (printed as `REFUSAL-ID:
			...`), one dated line of the contact's log says it, and the text of the template
			`Contacts/escalation-ask` names the one call that asks him: `RequestPermission` on
			that refusal, the existing escalation path, which this operation does not repeat.
			His click or word is the escalation apply's, signed by whoever answered: for this
			session (`allow-session`), or for the contact (`allow-contact`, 👤), written into
			its record as a standing grant that the chain reads whatever the session. `--asked`
			is who wants what, one line of at most 400 characters. Refused, rc 1, from no
			member's session, with no session, for a contact not recorded, with a part missing.

		--allow-contact <id> --session-id <id> --refusal-id <id> --kind session|contact
			Contacts' operation (DistroAgentsContacts.fn.sh): a member gives a contact what the
			member holds itself. A stub over `--intern-op-permission-grant-open`, signed by
			the calling member and bounded by its holding (a member gives only what it holds:
			rc 3 and the holders up the chain), for the refusal recorded for that contact, for
			the session (`session`) or for the contact (`contact`, an `allows:` entry of its
			record). The human-owner's allow is not this: it is the answer to the refusal's
			permission request. Refused, rc 1, for a refusal that is not recorded for that
			contact, a kind that is neither, and a call from no member's session.

		--tester-skillset-validate-routine <routine-file|--from-stdin>
			Checks a routine file against the routine contract
			(`magic-team/templates/routine.contract.format.md`) and prints one
			row for each fault, `<file>:<line>: <rule>: <text>`, exit non-zero
			where there is any. It is the thin stub of the one validator,
			`--intern-doc-validate routine`, and has no logic of its own;
			`DistroAgentsTesting.fn.sh --skillset-validate-routine` is the
			same. Read-only. It rejects, and does not warn, a routine that has
			no `requires-session-kind:` naming a session kind (`standalone` or
			`coworking`), no `type: routine`, no `executors:` or `maintainers:`
			(its kind routine's defaults counted), or lacks `# Opening steps`,
			`# Steps`, `# Closure steps` or `# Routine's local procedures`, each
			once and in that order; a `tracking-item:`, `start-context:`
			(with a closure line for each mode it allows), `review-by:`,
			`routine-lock-document:`, `input-scan-def:`, `runs-at:` or `runs-after:` of a wrong form is
			refused the same way. A finding of `operations:` is a row of the
			rule `report-operations`: it is said and refuses nothing.
			`--from-stdin` reads the routine from standard input.

		--tester-test-register (<test-id> --project <p> --script <path>|--from-folder <dir> --project <p>) [--functionality <f>] [--keyword <k>]... [--rig <path>] [--document <path>]... [--resource <path>]... [--nightly yes|no]
			The thin stub of `DistroAgentsTesting.fn.sh --test-register`, which has the
			logic; every `--tester-<operation>` below is the `--<operation>` of that file.
			Registers a test in the testbed, the project metadata of the tests, kept in
			`$MMDAPP/.local/agents/testing/tests/<test-id>.md`, one file for each test:
			its `--project` (such as `myx/myx.distro-agents`), its `--script` (an
			absolute path, or one below the project's folder in `source/`, or below the
			workspace), and as it applies the `--functionality` and `--keyword`s it is
			about, the `--rig`, `--document`s and `--resource`s it needs, and `--nightly
			yes` to be one of the nightly regressions (the default is `no`). A test is
			known by its id, which for the tests of a package is the runner's name for it.
			One registered already is refused (`--tester-test-update`). With
			`--from-folder`, every `*.test.sh` of the folder and of the folders one level
			below it is registered for the project by its file name, its script kept
			below the workspace; one registered already is left as it is, and said.
			A test whose folder no testing directive names is registered all the same,
			and `registered; not eligible for system runs: no testing directive names
			<folder>` is said on stderr: the system's runs leave it out.
			Whether a test has passed, and its runs, are not kept here: the test runner
			keeps them (`AgentsRunTests.sh --passed`), and the testbed reads them.

		--tester-test-update <test-id> [--project <p>] [--script <path>] [--functionality <f>] [--keyword <k>]... [--rig <path>] [--document <path>]... [--resource <path>]... [--nightly yes|no]
			The stub of `DistroAgentsTesting.fn.sh --test-update`. Changes the metadata
			of a registered test: only what is named, a list (`--keyword`, `--document`,
			`--resource`) replaced whole, the date of registration kept and the date of
			the update set. A test not registered, nothing to change and a script that is
			not there are refused, and the test is left as it was.

		--tester-test-unregister <test-id>
			The stub of `DistroAgentsTesting.fn.sh --test-unregister`. Takes the test out
			of the testbed: its metadata goes, and the test, its script and its pass
			record stay.

		--tester-test-invalidate <test-id>
			The stub of `DistroAgentsTesting.fn.sh --test-invalidate`. Drops the pass
			record of a registered test, so that the next batch runs it whatever state
			it passed on, and keeps when it was invalidated in its metadata.

		--tester-test-list [--project <p>] [--namespace <n>] [--keyword <k>]
			The stub of `DistroAgentsTesting.fn.sh --test-list`. Read-only. The
			registered tests, those of a project, a namespace (the first word of the
			project) and a keyword where given, as tab-separated rows: `test`, the id,
			project, functionality, keywords, the nightly flag, when it passed on the
			state it would run on now (`-` where it has not), when it was invalidated,
			and the runs, passes and fails of the last forty run folders; after each
			test its last runs, `run`, the id, the run folder, `PASS` or `FAIL`, and the
			seconds; and a last row, `tests`, the number listed, passed and not passed.

		--tester-run-oldest-untested [--wait|--no-wait]
		--tester-run-all-nightly-regressions [--wait|--no-wait]
			The stubs of `DistroAgentsTesting.fn.sh --run-oldest-untested` and
			`--run-all-nightly-regressions`. They put tests of the testbed into the one
			retest queue of the machine (`--member-retest-queue`), as the acting member
			or the console user, and print the request's id: the registered test that
			was registered first of those that have not passed on the state they would
			run on now, or every test registered `--nightly yes`. Only a test whose
			script is below a sh-test folder that a testing directive names
			(`magic-team:testing:<project-glob>:<sh-test-path>:<host-glob>` in a
			project.inf of the workspace, the directive `--make-agents-indices` reads
			for magic-tester's write) is eligible: a folder no directive names is not,
			and where none is named no test is. Nothing is put in
			the queue, and it is said, where every test has passed or none is eligible;
			a testbed with no test is refused. With `--wait` the call stays until the
			batch has run them and says how they came out, as `--member-retest-queue`
			does.

		--request-tests --why <text> [--project <p>] [--file <changed-file>]... [--about <scratch-folder>] [--wait|--no-wait] [<test>...]
			AgentTestingTools.fn.sh, the tool any member uses to communicate a testing
			need to the testing system and to `magic-tester`; nobody reads results from
			it, and a call from no member's session is refused. Puts the tests into the
			one retest queue as the calling member's request, with the options and the
			rules of `--member-retest-queue` (`--by` is not given: the request is the
			member's), and files one inquiry into `magic-tester`'s inbox that says who
			asks, for what, why, with which priority, and where the outcome is read
			(`--member-retest-result <id>`). A request the queue refuses queues nothing
			and asks nobody. The first line printed is the request's id, said as soon as
			the inquiry is filed; with `--wait`, for a sandbox before its hand-off, the
			call then stays until the batch has run the request and says how it came
			out, and ends with rc 0 for a pass.

		--skillset-upsert [--team-member <team-member>] <pathname> (--from-stdin|--from-file <path>)
		--librarian-skillset-upsert [--team-member <team-member>] <pathname> (--from-stdin|--from-file <path>)
			AgentLibrarianTools.fn.sh --skillset-upsert, and its thin stub in this
			dispatcher, which has no logic of its own. Skill access, not file access: a
			tool of its own, apart from the rules of Skill, Read and Write. It names a
			member and a `.md` file inside that member's skill (<pathname> is relative to
			the skill's folder, no `..`; a file there or a new one, its folders made) and
			saves the whole text into the skill's SOURCE COPY, found through the member
			registry (members.registry: the folder a `source-symlink` or `source-declared`
			row names). It never writes an install (a copy under a workspace's `.local`)
			and never the HOME skills folder: a skill with no source copy, or with more
			than one, is refused and the refusal says why. It is the librarian's: it runs
			only as magic-librarian. It asks the permission chain for the permission
			`skillset-upsert` over `<team-member>:<pathname>`, as a tool call is asked: a
			routine whose `allows:` names it (`magic-librarian:skillset-upsert`) holds it,
			and so does a grant of the session, the task or the call; a call that holds
			none is refused with a REFUSAL-ID and the way to ask for it with
			RequestPermission, and a granted call is retried as it was made. It changes the
			skillset only while `learning` is on (`--current-flags`): while it is off the
			librarian offers proposals, and the refusal says where the proposal goes. The
			resulting text is checked before anything is saved: a `*.routine.md` against
			the routine contract, which refuses the save and prints its rows, and every
			file against itself, whose `report-` rows are printed and refuse nothing. The
			save is one rename in the folder of the file. Prints `OK: wrote <file>`; the
			change is the librarian's to commit.

		--request-update --kind document|knowledge|skill --target <target> --why <text> (--from-stdin|--from-file <path>) [--reply]
		--request-update --kind skill --target <team-member>:<pathname> --why <text> --whole-text (--from-stdin|--from-file <path>) [--reply]
		--request-update --kind skill --target <team-member>:<pathname> --why <text> (--old <text>|--old-from-file <path>) (--new <text>|--new-from-file <path>) [--reply]
			AgentLibrarianTools.fn.sh, the tool any member uses to ask the librarian for an
			update. Everything for the librarian goes to the one queue, which is its inbox:
			one inquiry-* into magic-librarian's incoming/, and its name is printed. A call
			from no member's session is refused. Three forms. A message: the member's
			words, about a document (the target a file, by a path), the knowledge base (the
			target a topic; it waits for the knowledge tool) or a skill. A whole text: the
			proposed whole text of a skill file. A concrete edit: the old and the new string
			of a skill file, as Edit takes them, the old one being in the file once. A whole
			text and an edit are for a skill file, the target `<team-member>:<pathname>`.
			The tooling records the target file's date and checksum itself and the requester
			never gives them (a file not there is recorded as none). A request is a notice
			unless it asks for its outcome with `--reply`: then `--queue-done` files one note
			with the outcome into the requester's inbox. Without `--reply` nothing is sent
			back; `--request-result` is there for anyone who wants to look.

		--request-result <name>
			AgentLibrarianTools.fn.sh. Where a request stands, one line: `UPDATE <name>
			WAITING -- ...` while it is in the librarian's incoming/, `UPDATE <name> DONE
			(<outcome>) -- ...` with the outcome (`applied`, `refused` or `closed`) and the
			result the librarian closed it with (`wrote <file>`, its reason, or its own
			words), `UNKNOWN` (exit 1) for a name that is no update request.

		--queue-list
		--queue-take
			AgentLibrarianTools.fn.sh, read-only. The update requests that wait in
			magic-librarian's incoming/, that is the inquiries that carry an `update-kind`:
			`--queue-list` as a row each (name, kind, target, form, from, date),
			`--queue-take` as one batch, `UPDATE-BATCH: <n> request(s) waiting` and each
			request whole under a `=== UPDATE-REQUEST <i>/<n>: <name> ===` line, with the
			line `BASE:` where its target file is as it was when the request was written and
			`BASE-CHANGED:` where it is not (changed, gone, or there now and not then). A
			request leaves the queue only when it is closed.

		--queue-done <name> --apply
		--queue-done <name> --refuse <reason>
		--queue-done <name> --result <text>
			AgentLibrarianTools.fn.sh, the librarian only, which decides alone. `--apply`
			saves the whole text or the concrete edit of a skill file by the very path and
			checks of `--skillset-upsert` (the permission, learning, the source copy, the
			validation); a whole text whose base has changed is not applied, and an edit
			is applied only if its old string is in the file once. An apply that fails
			leaves the request waiting and says why. `--refuse` closes it with the
			librarian's reason, not correct or not needed; `--result` closes it with what
			was done. The reason or the result is one line of at most 500 characters. The
			request moves to processed/ with its `update-outcome` and `update-result`, and
			`closed: <name>` is printed; where the request asked for it (`--reply`), one note
			with the outcome is filed into the requester's inbox. A name that is no waiting
			update request is refused.

		--spawns [--active|--waiting|--all]
		--flags
		--tasks
			AgentDispatcherTools.fn.sh, the coordinator's role surface over what is under
			way. It owns no state and every view is the answer of the subject that owns it.
			`--spawns` the runs of the team, the Dispatcher's rows (`--active` the default,
			`--waiting`, `--all`); `--flags` the worktime flags now, the Dispatcher's lines;
			`--tasks` the board as the coordinator reads it, `# board` the count of each state
			and `# active` the active items. Runs as magic-coordinator; a call from another
			member is refused, a call from no member's session (the console) may read.

		--contacts [--organisation <slug>] [--reached-by <member>]
		--contact <id>
			AgentDispatcherTools.fn.sh, read-only, the coordinator's view of the contacts.
			`--contacts` is Contacts' rows (DistroAgentsContacts.fn.sh `--all-contacts`),
			`--contact <id>` one contact: its record (coordinates and notes), then `# access`,
			what the contact may ask for. The contact is Contacts' to keep; a contact not
			recorded is refused.

		--standing-directives [--all]
			AgentDispatcherTools.fn.sh, read-only. What stands until it is ended, three kinds
			together, a TAB-separated row each: `warning <item> <state>`, an open `warning-*`
			board item (backlog, pending, running, review, blocked or parked; a mitigated
			one is processed and is not shown); `note <item> <heading>`, a note of
			magic-coordinator's incoming/ that carries the header `standing: yes` (set with
			`--member-inbox-note-upsert --standing yes`, a row of the note's contract); and
			`order <id> <set> <expires-at> <text>`, an order of the human-owner. An order is
			shown while it is in force, its expires-at being `none` or ahead; `--all` shows
			an expired one too, with `(expired)` after its date. A spawn is given the orders
			and the notes in force in its brief, the section `standing directives in force`
			(`(none in force)` where there are none).

		--directive-set --text <text> --expires-at "<YYYY-MM-DD HH:MM>"|none [--id <id>] [--wait <seconds>]
		--directive-end --id <id> [--wait <seconds>]
			AgentDispatcherTools.fn.sh, magic-coordinator only: an order of the human-owner
			entered as a standing directive, and taken out. An order is one line of the
			`# Standing directives` section of the state-note, `- <id> | set <date>
			| expires-at: <date>|none | <text>`; the text is one line of at most 400
			characters, and the `--expires-at` is needed, `none` where the order does not
			end. An `--id` already there is replaced; without one the tool makes it.
			The write goes through the note's lock as a session does
			(`--magic-state-note-lock-acquire`): while another session holds the note it waits,
			polling, up to `--wait` seconds (120 by default) and then refuses with the note
			untouched; it changes that section alone, leaves the note's other fields and
			body and its stamps as they are, commits and pushes as every state update does,
			and gives the lock back. Prints `DIRECTIVE: <id> set` or `DIRECTIVE: <id> ended`;
			an id that is not there is refused (rc 1).

		--owner-cleanup-purge
			Empties $MMDAPP/.local/.cleanup/ (the folder itself stays).
			Takes no arguments -- always targets this one fixed location;
			nothing to parameterize.

		--owner-clear-just-agents [--check|--apply]
			Clears a Just Agents workspace: the configuration settings
			that do not belong in `Just Agents, default`, and nothing
			else -- never any data (no file or folder of the team data,
			.local/agents or .local/temp is looked at). The six:
			TEAM_DATA_DIRECTORY (scope magic-coordinator) and
			TEAM_DATA_GIT_REMOTE, TEAM_DATA_BRANCH,
			TEAM_DATA_GIT_USER_NAME, TEAM_DATA_GIT_USER_EMAIL and
			MDAT_WORKSPACE_MODE (scope magic-team), each taken out by the
			settings writer. `--check`, which a bare call is, prints
			`SETTING: <scope> <key> set` for each one that is set and
			`CHECK: <n> of 6 set; --apply clears them` (or `nothing to
			clear`), and changes nothing; `--apply` clears them and prints
			`CLEARED: <n>`. A key is named, never its value. It acts on the
			workspace it runs in; destructive and irreversible, so it is run
			on a workspace the owner's order names, one at a time.

		--member-help [--team-member <team-member>]
			Read-only. Prints `<team-member>`'s own duty-related tooling
			help.

		--member-comms-slack-read [--team-member <team-member>] (<channel>:<ts>|<alias>:<ts>|session-current|session-parent [--thread]|<channel>|<conversation-id>|magic-team|human-owner|event-track|event-alert [--oldest <ts>]) [--identity-bot]
			`<team-member>` is the member this read acts as -- decides
			which conversation this call can see at all.

			Full detail for one message (default) or its whole thread
			(--thread): all meta-info, reactions, formatting,
			files/attachments, raw JSON exactly as Slack returns it,
			never pretty-formatted. A `<ts>` naming a thread reply reads
			that reply like any other message. session-current or
			session-parent in place of `<channel>:<ts>` names that
			session's thread: its opening message, or with --thread the
			whole thread (see --member-comms-slack-send-message).
			`<alias>:<ts>` reads the message with that ts in the
			conversation an alias names, or with --thread its thread.

			A target with no `:<ts>` names a conversation instead,
			reading its own messages pretty-formatted, newest first,
			paged to the end; --oldest <epoch> floors how far back
			paging walks (needed on a busy channel -- past the page cap
			is a hard failure, not a truncated answer). --thread is for
			the `<channel>:<ts>` form only, --oldest for the
			conversation form only -- and with --thread, where it floors
			the replies: the parent, and the replies after <ts> (how the
			communications reader reads a thread it holds up to a ts).

			**Use this, not --member-comms-slack-search-messages, for
			something posted moments ago** -- search lags on Slack's
			own index; this reads the conversation directly.

			Same credential resolution as --member-comms-slack-send-message;
			--identity-bot reads as the team bot. A direct conversation
			belongs to one identity -- the bot's DM with someone and a
			member's own are different conversations, neither readable
			from the other. Channels are unaffected.

			**An empty result is never an answer here.** A call that
			can't see the requested message fails non-zero, naming the
			`<ts>` -- never read as "no such message" or "nobody
			replied yet".

		--member-comms-email-read [--team-member <team-member>] <uid> [--seen]
			`<team-member>` is the member this read acts as -- the mailbox
			is that member's own, no fallback; the same `<uid>` under a
			different member names a different message, or none.

			Full RFC822 message (headers + body + MIME, attachments as
			raw MIME parts) for one email by IMAP UID -- contrast with
			--member-comms-email-check's STATUS-only count.

			**Reading does not mark the message read** -- opened
			read-only, BODY.PEEK[], \Seen left exactly as found; mark it
			with --member-comms-email-mark-seen or --seen below.

			**An empty result is never an answer here.** A call that
			can't return the message fails non-zero; empty stdout is
			never success. Exit 1 no `<uid>` given. 2 `<uid>` malformed,
			or mailbox unreachable/not logged in. 3 server refused the
			fetch. 4 no message with that `<uid>` exists -- stated
			directly, not inferred from silence.

			--seen marks \Seen after a successful read only; a failed
			read leaves the message untouched.

		--member-comms-trello-read [--team-member <team-member>] <notification-id>
			`<team-member>` is the member this read acts as, and it comes
			first, ahead of the `<notification-id>`. It is required and
			strict: the notification is read as that member, with no
			fallback. A notification belongs to one member's own list, so
			an id taken from another member's check is not readable here.

			Full detail for one specific Trello notification (the unit
			--member-comms-trello-check's unread list returns), including
			its related card/board summary.

		--help-setup-<domain>
			Read-only. Prints the setup manual for one `--owner-setup-*`
			domain: every configuration option that domain takes, required
			and optional alike, and what the reader has to do to obtain
			each value. A domain carrying no document is refused, naming
			the domains that carry one.

			Printed byte-exact rather than through the markdown renderer,
			which reads an underscore as emphasis and drops it -- every
			configuration key named in these documents carries one.

			The complement of `--owner-setup-<domain>`, which reports what
			this workspace is still missing.

		--intern-context-show [--team-member <team-member>] [--session-id <session-id>] [--spawn-id <spawn-id>] [--select-workspace <place-name|absolute-path>] [--tooling-origin <spec|absolute-path>]
			Read-only. Prints the context this call resolves, a line each,
			`<name>: <value>`: the five resolved values first
			(`team-member`, `session-id`, `spawn-id`, `select-workspace`,
			`tooling-origin`, the last two as absolute paths), then every
			MDAT_* and MDLT_* variable of the tooling by name, such as
			`MDAT_SESSION_ID: <id>`. A variable whose name holds TOKEN,
			KEY, PASSWORD, PASSWD, SECRET or CREDENTIAL is printed in the one
			form of a credential, its first quarter (not under 4, not over
			20 characters) and a `*` for each character after; a value of
			several lines is one line, its breaks written `\n`. With no
			account at the console, and no `--team-member`, it is refused.

		--help-syntax [<op>]
			Prints every operation's syntax line and exits, without the
			manual. A bare call prints the default syntax alone -- the
			entry points a reader starts from.

			With <op>, only the syntax lines of that operation; a word
			ending in `-`, such as `--magic-`, prints those of every
			operation it begins. A word that names none is refused, rc 1.

		--help
			Prints the default syntax + summary and exits.

##  Notes:

		Attended and unattended sessions. A tool call served through the
		myx.distro MCP counts as attended only from an interactive Claude
		Code client, whose CLAUDE_CODE_ENTRYPOINT is `cli` or
		`claude-vscode`, and only with neither MDAT_SESSION_UNATTENDED=true
		nor a spawn id. Everything else is unattended, and an unattended
		session never writes the team data store or its session store with
		Write or Edit. Its permission requests are decided by the team
		tooling rather than prompted.

		Channel dirs are session plumbing ONLY (fifo/log/pid/meta) --
		never a place to stage secrets. A credential that needs to reach
		a console session must be sourced directly into the console's own
		environment, never dropped as a file inside a channel dir.

		`--console-start` always creates a new console session -- it
		can't assume one is already open. Bare invocation (`bash
		sh-scripts/DistroAgentsTools.fn.sh ...` with no leading path
		component) silently no-ops; invoke it via `./sh-scripts/...`, a
		full path, or with `sh-scripts/` on PATH.

		--header:<upsert|append|remove> operations write into the item's own
		`---` frontmatter block. An item that has no frontmatter block gets
		one, carrying the requested fields, ahead of its existing body; the
		body itself is untouched. An item whose frontmatter opens with `---`
		and never closes is refused instead -- where that block ends cannot
		be determined, so nothing is written.

		The `--manager-*` operations are the console's own, and the
		tooling's: what a manager screen, and later a portal, reads and
		acts through. Whoever can open the console on the machine runs
		them, a person or a script. A call from inside a member's session
		is refused in one line, magic-coordinator's among them. Each prints
		plain text for a program to read, in the form its entry gives.

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
		DistroAgentsTools.fn.sh --member-inbox-note-upsert keeper-myx note-20260722T0930Z-example.md <<'EOF'
		... note content ...
		EOF
		```

		# Same, via --from-file instead of stdin
		`DistroAgentsTools.fn.sh --member-inbox-note-upsert keeper-myx note-20260722T0930Z-example.md --from-file /path/to/note.md`

		# Append one session transcript entry (one call = one entry block)
		`DistroAgentsTools.fn.sh --member-append-session-transcript magic-coordinator --speaker human-owner --timestamp 2026-07-26T12:34:56Z --message "Approved. Proceed." --transcript-name transcript-2026-07-26-example.md --create`

		# Read a transcript audit document by filename (no raw path argument)
		`DistroAgentsTools.fn.sh --member-audit-item-read magic-coordinator transcript-2026-07-26-example.md`

		# Read only a selected line range from the same audit document
		`DistroAgentsTools.fn.sh --member-audit-item-read magic-coordinator transcript-2026-07-26-example.md --start-line 10 --end-line 25`

		# Read from specific board state(s) only, with optional line range
		`DistroAgentsTools.fn.sh --member-board-item-read magic-coordinator task-example.md --board-state pending --board-state running --start-line 1 --end-line 40`

		# Register a workspace no project declares
		`DistroAgentsTools.fn.sh --owner-workspace-upsert /Volumes/ws-2017/myx-work`

		# List every registered place, with its kind, ceiling and path
		`DistroAgentsTools.fn.sh --owner-workspace-list`

		# Send an email with a multi-line body from stdin instead of fragile trailing argv
		```
		DistroAgentsTools.fn.sh --member-comms-email-send magic-coordinator example@example.org -- "Status update" -- --from-stdin <<'EOF'
		Line one of the body.
		Line two, with 'quotes' and (parens) that would have been fragile as argv.
		EOF
		```

		# Regression-test permission hardening under a deliberately permissive umask
		`DistroAgentsTools.fn.sh --owner-credential-store-self-test`
