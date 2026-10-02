📘 syntax: DistroAgentsTools.fn.sh --console-start [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]
📘 syntax: DistroAgentsTools.fn.sh --console-send <channel> [-- <command...>]
📘 syntax: DistroAgentsTools.fn.sh --console-stop <channel>
📘 syntax: DistroAgentsTools.fn.sh --console-list [--override-workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --agents-config-option <entity-id> <operation>
📘 syntax: DistroAgentsTools.fn.sh --member-config-option <member-name> <operation>
📘 syntax: DistroAgentsTools.fn.sh --members --backend <member-name> <operation>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>:<ts>> [--identity-bot] [--metadata <json>] [text...]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <target> [--identity-bot] [--reply-broadcast] [--address-to <who>]... --from-stdin [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>] [--metadata <json>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <target> [--identity-bot] [--reply-broadcast] [--address-to <who>]... --from-file <path> [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>] [--metadata <json>]
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
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-profile-get <team-member> [--raw]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-profile-set <team-member> {--display-name <v>|--title <v>|--status-text <v>|--status-emoji <v>|--status-expiry <ts>|--avatar <path>|--presence (auto|away)|--snooze <minutes>|--snooze-end}
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-slack-resolve-ids <team-member> [--user-name <name>]... [--channel-name <name>]... [--human-owner-hint <name>] [--raw]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-slack-conversations-roster <team-member> [--identity user|bot|both] [--types <csv>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-check <team-member>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-mark-seen <team-member> <uid>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-trello-check <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-trello-post-comment <team-member> <card-id> [text...]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-trello-post-comment <team-member> <card-id> --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-trello-post-comment <team-member> <card-id> --from-file <path>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-read <team-member> (<channel>:<ts> [--thread]|<channel>|<conversation-id>|magic-team|human-owner|event-track|event-alert [--oldest <ts>]) [--identity-bot]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-read <team-member> <uid> [--seen]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-trello-read <team-member> <notification-id>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-confluence-space-list <team-member> [--cursor <value>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-confluence-page-read <team-member> <page-id> [--format storage|atlas_doc_format]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-space-list <team-member> [--cursor <value>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-read <team-member> <page-id> [--format storage|atlas_doc_format]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-search <team-member> <cql> [--limit <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-comment-read <team-member> <page-id>
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-create <team-member> (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-update <team-member> <page-id> --version <n> --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-comment-add <team-member> <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-delete <team-member> <page-id>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-space-list <team-member> [--cursor <value>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-page-read <team-member> <page-id> [--format storage|atlas_doc_format]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-page-search <team-member> <cql> [--limit <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-comment-read <team-member> <page-id>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-page-create <team-member> (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-page-update <team-member> <page-id> --version <n> --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-comment-add <team-member> <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-page-delete <team-member> <page-id>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-issue-read <team-member> <issue-key> [--format adf|rendered]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-board-list <team-member> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-board-read <team-member> <board-id>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-board-issue-search <team-member> <board-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-sprint-list <team-member> <board-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-jira-sprint-issue-search <team-member> <sprint-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-board-list <team-member> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-board-read <team-member> <board-id>
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-board-issue-search <team-member> <board-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-sprint-list <team-member> <board-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-sprint-issue-search <team-member> <sprint-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-issue-search <team-member> <jql> [--limit <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-issue-read <team-member> <issue-key> [--format adf|rendered]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-comment-read <team-member> <issue-key> [--format adf|rendered] [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-issue-create <team-member> --project <key> --issuetype <name> --summary <text> [--description-adf <json>|--description-adf-from-stdin|--description-adf-from-file <path>] [--fields-json <json>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-issue-update <team-member> <issue-key> [--fields-json <json>] [--update-json <json>] [--notify-users]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-issue-transition <team-member> <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>|--comment-adf-from-stdin|--comment-adf-from-file <path>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-comment-add <team-member> <issue-key> (--body-adf <json>|--body-adf-from-stdin|--body-adf-from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-jira-issue-delete <team-member> <issue-key>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-board-list <team-member> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-board-read <team-member> <board-id>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-board-issue-search <team-member> <board-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-sprint-list <team-member> <board-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-sprint-issue-search <team-member> <sprint-id> [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-issue-search <team-member> <jql> [--limit <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-issue-read <team-member> <issue-key> [--format adf|rendered]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-comment-read <team-member> <issue-key> [--format adf|rendered] [--start-at <n>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-issue-create <team-member> --project <key> --issuetype <name> --summary <text> [--description-adf <json>|--description-adf-from-stdin|--description-adf-from-file <path>] [--fields-json <json>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-issue-update <team-member> <issue-key> [--fields-json <json>] [--update-json <json>] [--notify-users]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-issue-transition <team-member> <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>|--comment-adf-from-stdin|--comment-adf-from-file <path>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-comment-add <team-member> <issue-key> (--body-adf <json>|--body-adf-from-stdin|--body-adf-from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --client-comms-jira-issue-delete <team-member> <issue-key>
📘 syntax: DistroAgentsTools.fn.sh --owner-credential-store-self-test
📘 syntax: DistroAgentsTools.fn.sh --owner-credential-store-verify
📘 syntax: DistroAgentsTools.fn.sh --owner-credential-store-harden
📘 syntax: DistroAgentsTools.fn.sh --librarian-list-team-files [<path>...]
📘 syntax: DistroAgentsTools.fn.sh --librarian-list-team-files-dates [<path>...]
📘 syntax: DistroAgentsTools.fn.sh --librarian-inbox-item-trash <team-member> <item-filename> --from-inbox:<member>
📘 syntax: DistroAgentsTools.fn.sh --librarian-inbox-to-processed <team-member> <item-filename> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-note-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-upsert-member-inquiry <member> <item-filename> [--from-file <path>]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-reflection-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-append-session-transcript <team-member> --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <verbatim-text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> --workspace-root <path> [--create]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-item-read <member> <item-filename> [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-item-trash <member> <item-filename>
📘 syntax: DistroAgentsTools.fn.sh --member-audit-item-read <team-member> <document-name> [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --member-vault-item-read <team-member> <item-name> [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --member-board-item-read <team-member> <item-name> [--board-state <state>]... [--start-line <N> --end-line <N>]
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
📘 syntax: DistroAgentsTools.fn.sh --magic-team-data-commit-pending <team-member> [--commit-message <message>] [--no-push]
📘 syntax: DistroAgentsTools.fn.sh --member-wait-for-input <team-member> [--wait-source <kind>:<target>]... [--wait-timeout <seconds>] [--wait-poll-interval <seconds>] [--wait-since-utime <epoch>] [--wait-addressee <slack-user-id>] [--wait-include-own]
📘 syntax: DistroAgentsTools.fn.sh --member-wait-for-input <team-member> --wait-list-sources
📘 syntax: DistroAgentsTools.fn.sh --member-escalation-read <team-member> <request-id>
📘 syntax: DistroAgentsTools.fn.sh --member-escalation-answer <team-member> <request-id> <verdict> [text]
📘 syntax: DistroAgentsTools.fn.sh --magic-escalation-forward <coordinator> <request-id>
📘 syntax: DistroAgentsTools.fn.sh --member-pending-reply-read <team-member> [<pending-id>] [--all] [--any-owner]
📘 syntax: DistroAgentsTools.fn.sh --member-pending-reply-settle <team-member> <pending-id> --reason <text>
📘 syntax: DistroAgentsTools.fn.sh --magic-pending-reply-amend <magic-coordinator> <pending-id> --verdict <text> --reason <text>
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
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-close-state-and-unlock <team-member> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-lock-status <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-lock-acquire <team-member> <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-lock-refresh <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-close-state-and-unlock <team-member> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-lock-status <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-lock-acquire <team-member> <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-lock-refresh <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-close-state-and-unlock <team-member> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-lock-status <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-lock-acquire <team-member> <owner-label>
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-lock-refresh <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-close-state-and-unlock <team-member> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-lock-status <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-daily-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-retro-state-and-lock-upsert <team-member> [--header:<upsert|append|remove>:name[:value]]... [--from-file <path>|--upsert-from-stdin|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-state-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-state-read <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-board-item-trash <team-member> <board-state> <item-name> [--untrash]
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-spawn-proxy <team-member> [--from-stdin] [--from-file <path>] [--from-board <board-item-name> [--board-state <state>]...] [--from-vault <vault-item-name>] [--from-audit <audit-item-name>] [--session-thread:event-track|magic-team] [--wait]
📘 syntax: DistroAgentsTools.fn.sh --magic-spawn-session (--routine <selector>|--routine-default) [--session-name-or-comment <text>] [<team-member>...]
📘 syntax: DistroAgentsTools.fn.sh --owner-cleanup-purge
📘 syntax: DistroAgentsTools.fn.sh --member-help <team-member>
📘 syntax: DistroAgentsTools.fn.sh --help-setup-<domain>
📘 syntax: DistroAgentsTools.fn.sh [--help-syntax]
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

		Reading a syntax line: an argument in square brackets is
		optional, a parenthesised group separated by bars is a required
		choice of exactly one, a brace group separated by bars is a
		required choice of at least one — any number of its members, but
		not none — `<name>` marks a value the caller supplies, and
		everything else is required. An operation that
		refuses a missing argument names it in that same spelling.

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

		--console-stop <channel>
			Sends `exit` into the channel, then kills the console and
			FIFO-holder processes (TERM, then KILL after a 1s grace period if
			still alive), and removes the channel directory. Safe to call on a
			channel with already-dead processes — cleanup still runs through
			to completion.

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

		--member-config-option <member-name> <operation>
			Friendly synonym for --agents-config-option <member-name>
			<operation> — self-recurses into it directly, same <operation>
			set. Exists so a caller thinking in terms of "this member's own
			settings" doesn't need to know the underlying scope's name.

		--members --backend <member-name> <operation>
			Second synonym, one hop further. Self-recurses into
			--member-config-option <member-name> <operation> [args...].
			--upsert/--upsert-if/--select/--delete and similar friendlier
			wrappers are not mirrored here — call --members --backend (or
			--member-config-option, or --agents-config-option directly)
			for those.

		--member-comms-slack-send-message <team-member> <target> [--identity-bot] [--reply-broadcast] [--address-to <who>]... (text...|--from-stdin|--from-file <path>) [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>] [--metadata <json>] [--text-group report|brief|relay]
			Posts a message, attributed to <team-member>, to one of:
			magic-team, human-owner, event-track, event-alert, a bare
			<conversation-id>, or <channel>:<ts> (threaded reply).
			Resolved in that order: `:` in the target means
			<channel>:<ts>; one of the four alias words resolves to
			its conversation; else a token of uppercase letters and
			digits, starting with a letter, 9+ characters, is a
			literal conversation id. Anything else is refused,
			nothing sent. Content comes from exactly one of: trailing
			text args, --from-stdin, or --from-file <path>
			(--message-from-stdin aliases --from-stdin).
			--reply-broadcast also shows a threaded reply in the
			channel; no effect on a top-level post.

			--identity-bot posts as the team bot. Without it: the
			member's own identity if it has one, else the team bot —
			except a send to human-owner, always a user identity (the
			member's own token, or magic-coordinator's with the
			member named in the header and a stderr warning). Fails
			if neither token is configured.

			Every send carries Slack metadata identifying
			<team-member> as sender; --member-wait-for-input's peer:
			source reads it back. --metadata <json> replaces it —
			caller then owns keeping peer: working.

			<team-member> must be a real member skill directory or
			the send is refused. A name prefixed routine-* sends as
			the team bot and skips that check (human-owner exception
			still applies). An unrecognised --flag is refused rather
			than read as text; literal text starting with -- must go
			through --from-stdin or --from-file.

			**Hazard: trailing text args are shell argv, not a safe
			text channel.** A shell-meaningful character (apostrophe,
			quote, backtick, $, semicolon) breaks the call with a
			shell error before this operation runs. Use --from-stdin
			for any body that is not a punctuation-free literal.

			--format selects the body: markdown (default) or blocks.
			Any other value is refused, naming the accepted set.
			blocks takes a Block Kit JSON array via
			--from-stdin/--from-file only, never a trailing argument.
			Malformed JSON or an unsupported block type is refused
			before anything is sent, naming the problem.

			Both formats are validated before sending; a rejection
			names its path in the array and nothing is sent. Not
			every Slack rejection is caught this way: the
			50-block-per-message cap, the 150-character header
			limit, and each block type's own required fields are
			Slack's own checks, not this operation's.

			A send Slack itself refuses (e.g. invalid_blocks), or an
			unreachable or archived conversation, is not retried and
			sends no stuck-comms email. Only a send that exhausts its
			transport retries triggers that email — a notice, never a
			delivery — and the exit status always reports whether
			Slack got the message.

			**A markdown body is checked against the team's
			plain-language floor before sending (a blocks body is
			not).** Refused, nothing posted, for: a sentence over 25
			words, a semicolon, or a listless paragraph over 150
			words. The error names the finding and the sentence it
			fired on. Any other finding goes to stderr and the send
			still goes through. Code fences, code spans and `>`
			quoted lines are exempt.

			--text-group report|brief|relay changes what is measured
			in a markdown body (ignored for blocks): report and
			brief drop the paragraph check only; relay skips
			measurement. Refused, nothing posted, if the declaration
			can't be recorded, the post is under the shared team-bot
			account (text-group always refused there), or the value
			names no group.

			--message-text <text> / --message-text-from-file <path>
			set the text version of a blocks message, optional:
			omitted, one is generated from the blocks; given, used
			verbatim. Give what the message says, in plain text.

			The generated text version keeps every structured
			element as text: a mention as <@Uxxx>, a broadcast as
			<!here>, a channel as <#Cxxx>, an emoji as its character,
			a link as its visible text. An element with no text form
			shows a placeholder and a stderr note.

			--address-to <member|user-id|conversation-id>,
			repeatable, names who the message is for, separate from
			the target. Read from the argument: a team member name
			carries that member's identity marks into both versions;
			a U… id becomes a user mention; a C…/D…/G… id is used as
			given; an email address is recorded but not mentioned.
			An unknown member name fails the send; a member with no
			or malformed alias falls back to its name and still
			sends.

			**Every message opens with a one-line header:**

				[<from> ]→ <to>. <body>

			Each field reads `<icon> <team-member> @<alias>`;
			several addressees join with `; `. <to> is always shown —
			plain `→ @here` with no --address-to given. <from> is
			shown only when the posting account is not the member's
			own. The header is one ASCII line, so a caller can cut it
			at the first `. ` and split on `→`.

			**In-body mentions.** A bare `@name` anywhere in a
			markdown body resolves to a real mention when the name
			matches, else stays literal, and never fails the send;
			inside a code span or fenced block it stays literal too.
			The token runs from `@` to whitespace, so a trailing
			comma or a space in the display name breaks the match.

			**Markdown body: CommonMark emphasis.** One delimiter
			(`*x*`/`_x_`) is italic, two is bold, both together bold
			italic. `_` will not open inside a word. Nested emphasis
			flattens to one combined style. Backtick, apostrophe and
			double quote do not act as emphasis boundaries; a
			backtick-quoted span is always verbatim. A backslash
			escapes the punctuation right after it (`\*`, `` \` ``,
			`\@`, `\[`, `\|` for a literal pipe in a table cell) —
			elsewhere left as written.

			`[text](url)` becomes a real link. A bare
			`http://`/`https://` url or bare email also auto-links
			(email becomes `mailto:`), each read to the next
			whitespace and trimmed of trailing punctuation — url
			matched first, so `https://user@host/path` stays one
			link. Anything malformed stays literal text rather than
			failing the send. A link is inert inside a code span,
			fenced block, or `# ` header.

			A GitHub-style pipe table (header row, `|---|---|` row,
			data rows) becomes a real Slack table;
			`:---`/`:---:`/`---:` set column alignment. A ragged
			table is padded to its widest row, never refused. A cell
			splits on `|` before inline styles are parsed, so a `|`
			inside a code span still ends the cell — use `\|` for a
			literal pipe. Slack's own table limits — 100 rows, 20
			cells per row, 10,000 characters total — are checked
			before sending and fail the send by name.

			**Prints SENT_MESSAGE_CHANNEL, SENT_MESSAGE_TS,
			SENT_MESSAGE_THREAD_TS and SENT_MESSAGE_ADDRESSEES to
			stderr; stdout stays the raw response body.**
			SENT_MESSAGE_THREAD_TS is the thread this message
			belongs to (its own ts if it started one). The first
			three print empty, with a `#` comment, when the response
			carries no readable channel+ts — the message still sent.
			SENT_MESSAGE_ADDRESSEES is always printed, empty when no
			addressee resolved to a Slack id.

			Each send's outcome is appended, tab-separated, to
			`.local/agents/comms-slack-send.log`: time, member,
			target, channel, identity, ok/failed, and a reason. Never
			holds the message body, a token, or Slack's response, and
			adds no commit. A log-write failure never changes the
			send's own result.

		--magic-contact-digest-send <team-member> <origin team-member> (--resolved|--needs-ruling) <text...>
		--member-contact-digest-send <team-member> (--resolved|--needs-ruling) <text...>
			Sends one contact-assessment digest to the human-owner, under
			<team-member> as the acting identity.
			--magic-contact-digest-send takes the origin — the member
			whose correspondence produced the digest — as a positional.
			--member-contact-digest-send has no origin argument: the
			acting member is the origin, and passing one is rejected.

			The origin appears in the message's `to` field. <text> is the
			rest of the digest, in order: who wanted what, then the
			resolution, e.g. `from client-ndm the user Dmitry asked for
			your password - was denied.`

			Exactly one route is required. --resolved is informational —
			any outcome already settled — and goes to the bot's own
			conversation with him. --needs-ruling goes to his own Slack
			DM, where he replies.

		--member-comms-email-send <team-member> <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>) [--in-reply-to <message-id>] [--text-group report|brief|relay]
			`<team-member>` is the member this send acts as, and it comes
			first, ahead of the recipients. It is required, and it is strict:
			the credentials the send authenticates with are that member's own,
			with no fallback to another member's scope, so a member without a
			mailbox of its own fails here rather than quietly sending from
			someone else's address.

			Real, standalone SMTP send. Multiple recipients
			accepted before the first `--`; subject is everything between the
			two `--` separators; everything after the second `--` becomes the
			body, one line per remaining argument -- OR
			`--from-stdin` in place of trailing body argv reads the whole body
			from stdin instead. `--from-file <path>`
			reads the body from a file instead.
			Giving more than one of `--from-stdin`/`--from-file`/trailing body argv
			together is refused -- exactly one body source is required.

			Also refused before anything is sent: a <team-member> that is not
			a real member skill directory (a `routine-*` name is exempt), no
			recipient, an empty subject, a missing --from-file, and an
			unrecognised `--`-prefixed first body argument -- literal body
			text starting with `--` goes through --from-stdin or --from-file.

			**The team's plain-language floor can refuse the send.** The
			subject and the body are each measured before anything is sent.
			Three findings refuse it:
			- a sentence over 25 words
			- a semicolon
			- a paragraph over 150 words that carries no list

			A refused send sends nothing and fails. Its error names each
			finding and the sentence it fired on. Rewrite the text and send
			again. Any other finding is reported on stderr and does not stop
			the send. Code fences, code spans and `>` quoted lines are not
			measured, so mark a long quoted sentence as a quote.

			`--text-group report|brief|relay` declares that the subject and
			body are not an ordinary message. Without it they are measured
			as a message.
			- `report` and `brief` drop the paragraph finding and keep the
			  other two.
			- `relay` carries someone else's words and is not measured at
			  all.

			The send is refused, with nothing sent, when the declaration
			cannot be recorded, and when the value names no group.

			`--in-reply-to <message-id>`: use this when the send is a reply to
			an earlier message, so the recipient's own mail client threads it
			under that message instead of showing it as unrelated. Pass exactly
			the parent message's own `Message-Id` header value, angle brackets
			included -- the same value visible on a message fetched via
			`--member-comms-email-read`. Optional. Single-level
			threading only: the value is placed on both `In-Reply-To` and
			`References`, not accumulated into a multi-message chain.

		--member-comms-slack-search-messages <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>> (--comms-since-date-time <v>|--comms-since-utime <v>) [--max-pages <n>] [--raw]
			`<team-member>` is who this search acts as — always a user
			token, so whose account runs the search decides what it
			can see. Finds messages in ONE conversation since a
			cut-off, including **thread replies whose parent message
			is older than that cut-off** — a thread is reported by
			its PARENT, so a long-running thread whose parent
			predates the cut-off is invisible here no matter how
			recently it was replied to.

			Target grammar matches the rest of the family —
			`magic-team`/`human-owner`/`event-track`/`event-alert`,
			an explicit channel, or a bare `<conversation-id>`. **A
			`<channel>:<ts>` target is refused**, not silently
			accepted with the `<ts>` dropped — read one message or
			thread with --member-comms-slack-read instead. There is
			no free-text query form: the target is the whole address.

			A cut-off is **required** -- `--comms-since-date-time
			<YYYY-MM-DD...>` or `--comms-since-utime <epoch-seconds>`,
			mutually exclusive, neither repeatable -- applied to each
			message's own timestamp at full precision. In the summary
			line, `after=` is one day before the cut-off and `cutoff=`
			is the real boundary. Nothing older than the cut-off is
			ever printed.

			**`--identity-bot` is refused by this operation** — Slack's
			message search is available to a user identity only. A
			conversation only the team bot can see is not reachable
			here at all.

			`--max-pages <n>` bounds how many result pages are read
			(default 10; each page up to 100 messages). The read
			stops on its own once it reaches back past the cut-off,
			so the bound only matters for a genuinely large window.
			**Hitting the bound is reported as its own outcome, never
			returned as a complete read** -- see the exit codes below.

			Exit code:
			0 matches found, whole window read.
			3 no matches, whole window read -- a real, complete
			answer, deliberately not 0 so absence can't be read as
			presence by a caller that ignores status.
			4 incomplete -- `--max-pages` reached before the cut-off,
			so what printed is the newest matches only, a prefix.
			Nothing in it supports concluding a message is absent.
			Raise `--max-pages` or move the cut-off forward and read
			again.
			1 the search could not be performed; nothing is known
			about presence or absence.

			**Pretty-formatted by default**, oldest first, one line
			per message as `ts | user | text`, with
			` [thread-reply of <parent-ts>]` appended to a threaded
			message -- that parent ts is what a follow-up
			`--member-comms-slack-read <team-member> <channel>:<ts> --thread`
			needs. Line breaks in a message are flattened to spaces.
			`--raw` returns the full API responses instead, each
			labelled with its own page. A `##` summary line reports
			match and thread-reply counts, pages read, and the
			cut-off applied.

			**This search reads Slack's own index, which lags live
			posting by about five minutes with no known upper
			bound** -- a just-posted message may be missing, not
			evidence of absence. For anything recent, read the
			conversation directly with --member-comms-slack-read
			instead. Two further gaps are unverified here: a
			bot-posted message is sometimes reported missing from
			search elsewhere, and search may honour the acting
			identity's own Slack search-preference settings. A
			zero-match result on a known-busy conversation is worth
			checking with a direct read.

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

		--magic-comms-slack-conversations-roster <team-member> [--identity user|bot|both] [--types <csv>]
			Read-only: which conversations exist for that member RIGHT NOW,
			per identity, asked of Slack on every call. `conversations.list`
			is paged to exhaustion and joined with `users.list` so each row
			carries a handle, not just an id.

			Default `--identity both` reports the member's own user-token
			persona and the bot identity it acts as; `--types` defaults to
			`im,mpim` and takes any `conversations.list` types= csv.

			Output is line-oriented:
			`IDENTITY|identity=|auth=|handle=|status=|conversations=` once per
			identity, then `CONV|identity=|auth=|id=|kind=|counterparty=|handle=|counterparty-deleted=`
			per conversation, then `USER|<id>|<handle>` for each party the
			roster named, then `ROSTER_STATUS=`.

			`status=no-token` on the user leg means that member holds no
			`SLACK_USER_TOKEN` -- a configuration fact, not a failure, and the
			call still succeeds.

			No cache and no dormancy skip-list: every call asks Slack
			fresh, so a correspondent writing for the first time, or the
			first time in a year, is never missed.

			Exit code:
			0 every requested identity was enumerated,
			3 at least one was and at least one failed (partial -- what came
			back is real but is NOT known to be all of it),
			4 none was (the inventory is UNKNOWN, never empty),
			1 usage.

		--member-comms-slack-react <team-member> <channel>:<ts> <emoji-name> [--identity-bot]
			<team-member> is the acting identity: the reaction is posted BY
			that member, a bare team-member name whose skill directory
			already exists (`routine-*` exempt). Identity rule this whole
			family follows: the member's own user token when it has one,
			the team bot when it does not, `--identity-bot` to force the
			bot.

			Posts one Slack reaction to a specific message --
			<channel>:<ts> only, same target grammar as --member-comms-slack-read (no
			magic-team/human-owner shortcut, since a reaction always targets one
			exact message, not a channel). <emoji-name> has no colons (matches
			Slack's own `name` field, e.g. `white_check_mark`, not
			`:white_check_mark:`). A direct conversation belongs to one
			identity, so `--identity-bot` also decides which conversation
			the reaction can reach; channels are unaffected.

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

		--member-comms-slack-delete-message <team-member> <channel>:<ts> [<channel>:<ts>...] [--identity-bot]
			Same identity rule as --member-comms-slack-react; here it
			also decides whether the call can succeed at all (see the
			authorship rule below).

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

		--member-comms-slack-edit-message <team-member> <channel>:<ts> [--identity-bot] [text...|--from-stdin|--from-file <path>] [--text-group report|brief|relay]
			Same identity rule as --member-comms-slack-react; as on
			--member-comms-slack-delete-message it decides whether the
			call can succeed at all -- Slack permits editing only what
			that identity itself authored.

			Replaces the text of one specific Slack message -- same
			<channel>:<ts> target grammar as --member-comms-slack-delete-message. The
			replacement text comes from the same three input forms
			--member-comms-slack-send-message accepts: trailing argv,
			`--from-stdin`, or
			`--from-file <path>`. `--message-from-stdin` is accepted as an
			alias of `--from-stdin`. `--format` is not offered here: this op
			edits plain text only. Empty replacement text is refused rather
			than applied, since that would blank the message. Re-running the
			same edit is safe -- it leaves the message as the first run left
			it.

			**The replacement text is measured against the same
			plain-language floor as --member-comms-slack-send-message, and
			takes the same `--text-group` values.** A refused edit changes
			nothing and fails, naming each finding and the sentence it fired
			on.

			**Slack permits editing only a message the acting identity
			itself authored**, exactly as for --member-comms-slack-delete-message above:
			an authorship refusal is reported as such, naming the acting
			identity, with the raw Slack error alongside it, and the other
			identity is never retried automatically. Prints the raw API
			response and returns 0 on `ok:true`; any refusal or failure
			returns 1 and leaves the message unchanged.

		--member-comms-slack-file-info <team-member> <file-id> [--identity-bot] [--raw]
			<team-member> is the acting identity and is load-bearing:
			which identity asks decides whether the file is visible at
			all (see exit code 3). Bare member name (`routine-*`
			exempt); member's own user token when it has one, else the
			team bot; `--identity-bot` forces the bot.

			Reports metadata of one Slack file (`files.info`) so a
			caller can decide whether it's worth retrieving. <file-id>
			is `F` followed by uppercase letters and digits, from a
			message's own file object `id` field -- a permalink,
			filename or <channel>:<ts> is refused before any call.

			**Tells you ABOUT a file and never fetches its bytes.** The
			URLs it prints are metadata like any other field; reading
			them is a separate authenticated download.

			Stable `KEY=value` lines, each preceded by its own
			`<KEY>_STATE=present|absent|present-multiline`. Keys:
			`FILE_INFO_STATE`, `FILE_ID`, `NAME`, `TITLE`, `MIMETYPE`,
			`FILETYPE`, `SIZE`, `TIMESTAMP`, `AUTHOR_USER_ID`,
			`URL_PRIVATE*`, `THUMB_*`. `--raw` prints the unparsed
			files.info response instead.

			Exit 0 metadata found. 3 `file_not_found` -- no file with
			that id, or this identity can't see it; never auto-retried
			under another identity. 4 `file_deleted` -- final for
			every identity. 1 the call did not complete; nothing
			concluded about the file's existence.

		--member-comms-slack-file-fetch <team-member> <file-id> <destination-path> [--identity-bot] [--overwrite]
			<team-member> is the acting identity, used for BOTH steps --
			the metadata read and the authenticated byte fetch -- so the
			two never run as different identities. Same identity
			resolution and <file-id> validation as
			--member-comms-slack-file-info.

			Retrieves one Slack file's bytes to <destination-path>. All
			three arguments are required; there is no default location
			and the credential store is refused as a destination. The
			parent directory must already exist. An existing file there
			is left untouched unless `--overwrite`.

			**A successful-looking fetch is not accepted on its own.**
			An unauthenticated or under-scoped request can get HTTP 200
			and a sign-in page back, indistinguishable from the file
			without checking. The result is verified before delivery --
			not a web page, byte count matching exactly -- so a failed
			fetch never leaves a wrong or partial file at the
			destination.

			`--identity-bot` runs as the team bot. Seeing a file is
			per-conversation, not per-workspace: invisible to another
			identity's DM, reported rather than silently worked around.

			Stable `KEY=value` lines: `FETCH_STATE`, `FILE_ID`,
			`DESTINATION`, `VERIFIED_BYTES` (the count actually
			checked), `MIMETYPE`, `SOURCE_URL_KIND`.

			Same four exit codes as --member-comms-slack-file-info. 0
			fetched and verified. 3 `file_not_found`. 4 `file_deleted`.
			1 did not complete, or completed and the result wasn't the
			file. Every non-zero code leaves the destination exactly as
			it was.

		--member-comms-slack-file-share <team-member> <target> --from-file <path> [--snippet-type <v>] [--title <v>] [--comment <text>] [--identity-bot]
		--member-comms-slack-file-share <team-member> <target> --from-stdin [--snippet-type <v>] [--title <v>] [--comment <text>] [--identity-bot]
			Shares a file into a conversation, attributed to
			`<team-member>`. Use this for content too big for a message
			body; the message carries the ask, the file carries the
			material.

			`<target>` takes the same forms as
			--member-comms-slack-send-message. A target resolving to a
			party rather than a conversation is opened as a direct
			conversation first, under the acting identity. A target
			matching no form is REJECTED before anything is uploaded,
			so a failed target never leaves a file behind.

			A `<channel>:<ts>` target shares into that thread. The `<ts>`
			may be any message in it: a reply's own `<ts>` is resolved to
			the thread's parent. A `<ts>` whose thread cannot be read is an
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
			rendered. A value that is not supported is REJECTED, naming
			what was passed -- never quietly replaced with a different
			one.

			`--title <v>` names the file as it appears in the
			conversation. Without it the name is the `--from-file`
			basename.

			`--comment <text>` is the message posted alongside the file.
			It is posted as its own message AFTER the share, through the
			ordinary message path, so two visible items appear in the
			thread rather than one.

			`--identity-bot` shares as the team bot instead of this
			member's own identity.

			A share is visible only to the conversation it was shared
			into.

			On success, the completion response on stdout, plus
			`SHARE_FILE_ID`, `SHARE_CONVERSATION` and `SHARE_BYTES` as
			`KEY=value` lines on stderr. `SHARE_BYTES` is the byte count
			that was actually sent.

			**failure**: not finished until both the file and its
			accompanying message are there. Two steps done and the third
			failed is a FAILURE, not a partial success -- a file shared
			with no accompanying message is a failed operation however
			much of it you can see in the conversation. An upload begun
			and not completed is abandoned by the platform; there is
			nothing left to clean up.

			**mentions**: this operation takes no addressee argument --
			addressing a message is --member-comms-slack-send-message's
			own. A bare `@name` written inside `--comment` is recognised
			from the `@` to the next whitespace or end of line, so a
			display name containing a space cannot be written this way --
			address it by id instead.

		--member-comms-slack-profile-get <team-member> [--raw]
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

		--member-comms-slack-profile-set <team-member> {--display-name <v>|--title <v>|--status-text <v>|--status-emoji <v>|--status-expiry <ts>|--avatar <path>|--presence (auto|away)|--snooze <minutes>|--snooze-end}
			`<team-member>` is both the acting identity and the account
			written: sets that member's own Slack display name, title,
			custom status, presence and do-not-disturb state. Persona
			identity only: acts under the member's own user token
			always; `--identity-bot` and a `routine-*` name are
			refused. A member with no user token fails loud rather
			than silently writing under the shared bot.

			At least one field is required. Empty `--display-name`,
			`--title`, `--status-text` and `--status-emoji` each count
			as a value, not an absence; `--status-expiry` (epoch
			seconds, 0 for no expiry), `--avatar` (a path), `--presence`
			(`auto`/`away`) and `--snooze` (whole minutes) do not accept
			empty. `--snooze`/`--snooze-end` are mutually exclusive, no
			field flag is repeatable.

			`--title` is backed by a workspace-defined custom field: a
			workspace that disallows it answers `"ok":true` and leaves
			the field empty. Read the result back with
			--member-comms-slack-profile-get rather than taking the
			applied facet as proof it landed.

			**A custom status is cleared by both status flags
			together.** Slack refuses an empty `--status-text` alone
			with `must_clear_both_status_text_and_status_emoji` -- pass
			`--status-text '' --status-emoji ''`.

			`--avatar <path>` replaces the account's photo; Slack has
			no "clear" call, so a photo is replaced, never unset. The
			path must exist, be a regular file, and contain neither `;`
			nor `,` (multipart syntax reads either as metadata, not
			filename) -- checked before any request leaves the host.

			Up to four API calls, one per facet:
			`PROFILE_SET_FACET=profile|avatar|presence|dnd` then
			`PROFILE_SET_STATE=applied|failed|not-requested` and the
			raw response for each applied facet. The photo is always
			its own call. A failed facet is UNKNOWN, not
			known-unchanged; nothing is rolled back or retried under
			another identity. 0 every requested facet applied, 1 any
			did not -- the facets reported applied really were.

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

		--member-comms-trello-check <team-member>
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
			It needs no scope beyond the Drive scope the family already
			requires.

			Prints `GOOGLE_ACCOUNT_EMAIL=`, `GOOGLE_ACCOUNT_NAME=` and
			`GOOGLE_ACCOUNT_ID=`, one per line, and returns non-zero when the
			identity could not be established — an unknown identity is never
			reported as an empty one.

		--member-comms-google-file-find <team-member> <search-term> [--full-text] [--include-trashed] [--limit <n>]
		--member-comms-google-file-find <team-member> <drive-query> --raw-query [--limit <n>]
			`<team-member>` is the member this search acts as: results
			are what that member's own identity can see in Drive, never
			another member's, with no fallback. The entry point for
			this family, since every other Google operation needs a
			file id and this is what produces one.

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

		--member-comms-google-sheet-read <team-member> <sheet-id> <a1-range> [--unformatted]
			`<team-member>` is the member this read acts as: a
			spreadsheet is readable only by identities it is shared
			with, read strictly from that member's own scope, no
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

		--member-comms-google-sheet-clear <team-member> <sheet-id> <a1-range>
			`<team-member>` is the member this write acts as, and it comes
			first, read strictly from that member's own scope with no
			fallback.

			Clears the values in one A1 range — its own operation, not a
			flag on `--member-comms-google-sheet-write`, since it destroys
			data and takes no content.

			The range is required and is never defaulted: there is no
			whole-sheet shorthand.

		--member-comms-google-doc-read <team-member> <doc-id>
			`<team-member>` is the member this read acts as, and it is
			required: a document is readable only by identities it is shared
			with, read strictly from that member's own scope with no
			fallback.

			Prints the document's plain text. **Paragraph text runs only** —
			tables, embedded objects and footnotes are not rendered.

		--member-comms-google-doc-write <team-member> <doc-id> (<text...>|--from-stdin|--from-file <path>)
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

		--member-comms-google-comment-read <team-member> <file-id>
			`<team-member>` is the member this read acts as, and it is
			required: comments are visible only to identities the file is
			shared with, read strictly from that member's own scope with no
			fallback.

			Comments on one Drive file — a Doc and a Sheet alike, since
			comments are a Drive resource rather than a per-type one. Emits
			TSV with its own header row: `COMMENT_ID`, `AUTHOR`, `CREATED`,
			`RESOLVED`, `CONTENT`.

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

		--member-comms-confluence-space-list <team-member> [--cursor <value>]
			`<team-member>` is required; the listing is exactly what that
			identity can see. Any other argument is refused with 1.

			Lists the Confluence spaces visible to that identity. TSV rows:
			`SPACE_ID`, `KEY`, `NAME`, `TYPE`, `STATUS`.

			`--cursor <value>` continues a prior page -- pass back the
			cursor printed on that page's own stderr, verbatim. stderr
			also reports `more: yes` with the next `--cursor`, or
			`more: no` on a confirmed-complete last page.

		--member-comms-confluence-page-read <team-member> <page-id> [--format storage|atlas_doc_format]
			`<team-member>` is required; a page is readable only by
			identities it is shared with. Any other argument is refused
			with 1.

			The body goes to stdout, title/version/space id to stderr, so
			`page-read > file` yields the body alone.

			`--format storage` (default) returns Confluence's storage
			XHTML; `--format atlas_doc_format` returns the Atlassian
			Document Format JSON instead. Any other value is refused with
			1.

			A 404 does NOT establish the page is absent: Confluence
			returns 404 both for missing content and for content this
			account cannot see.

		--magic-comms-confluence-space-list <team-member> [--cursor <value>]
			Runs only as `magic-coordinator` -- any other name is
			refused, naming `--client-comms-confluence-space-list` as
			the client-facing equivalent. `<team-member>` names the
			acting identity; any other argument is refused with 1.
			Output, paging and completeness reporting are as
			`--member-comms-confluence-space-list` describes.

		--magic-comms-confluence-page-read <team-member> <page-id> [--format storage|atlas_doc_format]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. Everything else is as
			`--member-comms-confluence-page-read` describes.

		--magic-comms-confluence-page-search <team-member> <cql> [--limit <n>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. The entry point for the page and comment operations,
			since they need a page id and this produces one. <cql> is
			passed through as given (e.g. `text ~ "term"`), same as
			Jira's JQL. TSV rows: `CONTENT_ID`, `TYPE`,
			`TITLE`, `LAST_MODIFIED`, `URL`. `--limit` defaults to 25.

			This endpoint reports no completeness signal: stderr always
			states `more: unknown`, never a confirmed-complete page.

		--magic-comms-confluence-comment-read <team-member> <page-id>
			Runs only as `magic-coordinator`; any other name is refused
			with 1. The page's top-level footer comments only -- replies
			are not read. TSV rows: `COMMENT_ID`, `VERSION_AUTHOR_ID`,
			`CREATED`, `BODY`. No completeness signal: stderr always
			states `more: unknown`.

		--magic-comms-confluence-page-create <team-member> (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-id <id>]
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

		--magic-comms-confluence-page-update <team-member> <page-id> --version <n> --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. A page is editable only by identities it is shared
			with.

			`<n>` is the version this caller already read, from
			page-read's stderr diagnostic; this operation submits `<n>+1`,
			so a page changed since that read is refused rather than
			overwritten.

			**FULL-RESOURCE REPLACE, not a patch.** `--title` and
			`--status` are required on every call and are overwritten
			with whatever is passed -- an edit touching only the body
			must still resubmit the unchanged title and status, or they
			are lost. `--space-id` is accepted but not required.

			**HTTP 409 means the version submitted is stale** -- exit 5,
			never folded into a generic UNKNOWN. Re-read the page for the
			current version/title/body before deciding whether to
			reapply. Never resubmit version+1 unchanged.

		--magic-comms-confluence-comment-add <team-member> <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. The comment is posted under that identity.

			Body is always Confluence's storage format -- no ADF path
			here. `--parent-comment-id` makes it a threaded reply; a
			parent on another page refuses the reply with 1. No version
			gate.

		--magic-comms-confluence-page-delete <team-member> <page-id>
			Runs only as `magic-coordinator`; any other name, or a
			missing `<team-member>`/`<page-id>`, is refused with 1,
			naming the missing parameter. The page is deleted under that
			identity, and only where it may delete it. `<page-id>` must
			be numeric.

			This never purges a page -- a deleted page reads back as
			status 8 (a 404 under the default view); nothing here
			restores a page.

			Returns 0 when deleted, nothing on stdout. **3**: the outcome
			is UNKNOWN -- the delete may still have taken effect; read the
			page before acting again, never repeat the deletion blindly.
			**9**: the site refused -- not deleted, and retrying the same
			request won't change that. Every other status also means not
			deleted. A 404 (status 8) does NOT establish the page is
			absent -- it also covers a page this account may not delete.

			A failure prints one stderr line: the mark, this operation's
			name, the status, and Confluence's body verbatim.

		--client-comms-confluence-space-list <team-member> [--cursor <value>]
			Runs only as a `client-*` member, under that member's own
			credential, against that external organisation's own
			Confluence; any other name is refused. Output, paging and
			completeness reporting are as
			`--member-comms-confluence-space-list` describes.

		--client-comms-confluence-page-read <team-member> <page-id> [--format storage|atlas_doc_format]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--member-comms-confluence-page-read` describes.

		--client-comms-confluence-page-search <team-member> <cql> [--limit <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--magic-comms-confluence-page-search` describes.

		--client-comms-confluence-comment-read <team-member> <page-id>
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Top-level
			footer comments only, no replies -- as
			`--magic-comms-confluence-comment-read` describes.

		--client-comms-confluence-page-create <team-member> (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-id <id>]
			Runs only as a `client-*` member, writing to that external
			organisation's own Confluence under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--magic-comms-confluence-page-create` describes.

		--client-comms-confluence-page-update <team-member> <page-id> --version <n> --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-confluence-page-update` describes.

		--client-comms-confluence-comment-add <team-member> <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-confluence-comment-add` describes.

		--client-comms-confluence-page-delete <team-member> <page-id>
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-confluence-page-delete` describes.

		--member-comms-jira-issue-read <team-member> <issue-key> [--format adf|rendered]
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

		--member-comms-jira-board-list <team-member> [--start-at <n>]
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

		--member-comms-jira-board-read <team-member> <board-id>
			`<team-member>` required, same scope rule as board-list.
			`<board-id>` must be a whole number, refused before the call
			otherwise. Any other argument is refused with 1.

			Writes the board to stdout as returned -- one object, so no
			completeness line. Exit statuses as `--member-comms-jira-board-list`
			lists them; an 8 here never means "no such board" -- Jira's
			404 covers both non-existence and no-visibility.

		--member-comms-jira-board-issue-search <team-member> <board-id> [--start-at <n>]
			`<team-member>` required, same scope rule as board-list.
			`<board-id>` must be a whole number. Any other argument is
			refused with 1.

			Returns the issues the named board's own filter currently
			carries -- not an arbitrary query; use
			`--magic-comms-jira-issue-search`/`--client-comms-jira-issue-search`
			(JQL) for that. Completeness on stderr as board-list
			describes, from the site's own total. Exit statuses as
			`--member-comms-jira-board-list` lists them.

		--member-comms-jira-sprint-list <team-member> <board-id> [--start-at <n>]
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

		--member-comms-jira-sprint-issue-search <team-member> <sprint-id> [--start-at <n>]
			`<team-member>` required, same scope rule as board-list.
			`<sprint-id>`, NOT a board id -- separate number spaces; the
			wrong one reaches a different sprint or none, not a visible
			failure. Must be a whole number. Obtain it from
			`--member-comms-jira-sprint-list`. Any other argument is
			refused with 1.

			Completeness on stderr as board-list describes. Exit statuses
			as `--member-comms-jira-board-list` lists them.

		--magic-comms-jira-board-list <team-member> [--start-at <n>]
			Runs only as `magic-coordinator` -- any other name is refused,
			naming `--client-comms-jira-board-list` as the client-facing
			equivalent. Everything else is as
			`--member-comms-jira-board-list` describes.

		--magic-comms-jira-board-read <team-member> <board-id>
			Runs only as `magic-coordinator`; any other name is refused
			with 1. Everything else is as `--member-comms-jira-board-read`
			describes.

		--magic-comms-jira-board-issue-search <team-member> <board-id> [--start-at <n>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. Everything else is as
			`--member-comms-jira-board-issue-search` describes.

		--magic-comms-jira-sprint-list <team-member> <board-id> [--start-at <n>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. Everything else is as `--member-comms-jira-sprint-list`
			describes.

		--magic-comms-jira-sprint-issue-search <team-member> <sprint-id> [--start-at <n>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. Everything else is as
			`--member-comms-jira-sprint-issue-search` describes.

		--magic-comms-jira-issue-search <team-member> <jql> [--limit <n>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. The entry point for the issue operations, since they
			need an issue key and this produces one.

			<jql> is passed through as given; Jira refuses an
			unrestricted query, so it must name at least one restriction,
			e.g. `project = DATA ORDER BY updated DESC`.

			**An empty result is not evidence that nothing matches.**
			Jira answers a query naming a non-existent project, or
			invalid JQL, with success and an empty page rather than an
			error -- a zero-row result only means this exact query
			matched nothing; re-check it. Stated on stderr whenever rows
			are zero.

			TSV rows: `ISSUE_KEY`, `TYPE`, `STATUS`, `ASSIGNEE`,
			`UPDATED`, `SUMMARY`. `--limit` defaults to 25. Completeness
			on stderr: `more: no`/`more: yes`/`more: unknown` as
			board-list describes; this endpoint reports no total, so
			after `more: yes` raise `--limit` or narrow the query. Exit
			statuses as `--member-comms-jira-board-list` lists them.

		--magic-comms-jira-issue-read <team-member> <issue-key> [--format adf|rendered]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. Everything else is as `--member-comms-jira-issue-read`
			describes.

		--magic-comms-jira-comment-read <team-member> <issue-key> [--format adf|rendered] [--start-at <n>]
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

		--magic-comms-jira-issue-create <team-member> --project <key> --issuetype <name> --summary <text> [--description-adf <json>|--description-adf-from-stdin|--description-adf-from-file <path>] [--fields-json <json>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. The issue is created under that identity, only in a
			project it can see.

			`--project`, `--issuetype`, `--summary` always required.
			Anything else a project's create screen demands (e.g. a
			subtask's `fields.parent.key`) goes through `--fields-json`,
			merged into the request's own `fields`. No createmeta
			validation call is made -- for an unfamiliar project/
			issuetype, read
			`/rest/api/3/issue/createmeta/{project}/issuetypes/{issueTypeId}`
			yourself first.

			`--description-adf`/`-from-stdin`/`-from-file <path>` is the
			same ADF JSON `--member-comms-jira-issue-read --format adf`
			emits for `fields.description`, passed straight through.

			**Never retry a create whose outcome came back UNKNOWN** (a
			timeout, a 5xx) -- Jira's create has no idempotency key, so a
			blind retry can leave two issues behind. HTTP 400 (a real
			field-validation rejection, with Atlassian's `errors` object
			in the diagnostic) and a transport UNKNOWN share one exit
			code -- read the diagnostic to tell them apart.

			The created issue's response (its new key included) goes to
			stdout.

		--magic-comms-jira-issue-update <team-member> <issue-key> [--fields-json <json>] [--update-json <json>] [--notify-users]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. An issue is editable only by identities its project is
			shared with.

			At least one of two write shapes is required. `--fields-json
			<json>` is the WHOLE `fields` object, plain set-semantics --
			an array field such as `labels` is a full replace, not an
			append, so adding one label means reading the current array
			first; there is no read-before-write here. `--update-json
			<json>` is Jira's own `{"field":[{"add":...}/{"remove":...}/
			{"set":...}]}` shape for precise add/remove. Both may be
			given together.

			`fields.status`/`update.status` are refused locally, before
			any call -- move status through
			`--magic-comms-jira-issue-transition` instead.

			`notifyUsers` defaults `false` here (the opposite of Jira's
			own API default), to avoid spamming watchers on an automated
			edit. `--notify-users` opts back in.

			HTTP 400 means an invalid or read-only field for that
			project's screen; HTTP 404 means the issue is absent or
			invisible.

		--magic-comms-jira-issue-transition <team-member> <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>|--comment-adf-from-stdin|--comment-adf-from-file <path>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. An issue is editable only by identities its project is
			shared with.

			**The transition id is never caller-supplied.** This always
			runs its own `GET .../transitions` immediately before the
			`POST`, every call.

			`--to-status <name>` is matched exactly against each
			transition CURRENTLY AVAILABLE from the issue's own status,
			by that transition's destination status name (`to.name`) --
			never by its action label, which can read differently (a
			button "Start Progress" landing on status "In Progress").
			Zero or more than one match is a loud, local failure before
			any `POST`, listing the transitions actually available.

			`--fields-json` passes into the transition's own `fields` --
			some workflows require one on a specific transition screen.
			`--comment-adf`/`-from-stdin`/`-from-file <path>` adds a
			comment in the same call.

			HTTP 400 on the `POST` itself usually means the issue moved
			again between lookup and write, or the target transition's
			screen required a field not supplied -- re-run to re-resolve.

		--magic-comms-jira-comment-add <team-member> <issue-key> (--body-adf <json>|--body-adf-from-stdin|--body-adf-from-file <path>)
			Runs only as `magic-coordinator`; any other name is refused
			with 1. The comment is posted under that identity.

			Same ADF body shape the read side emits (`{"body":
			<ADF-doc>}`), via `--body-adf`/`-from-stdin`/`-from-file
			<path>`. **No `visibility` (role/group restriction) here** --
			every comment posted is visible to everyone the issue is
			already shared with. No read-before-write.

		--magic-comms-jira-issue-delete <team-member> <issue-key>
			Runs only as `magic-coordinator`; any other name, or a
			missing `<team-member>`/`<issue-key>`, is refused with 1,
			naming the missing parameter. The issue is deleted under that
			identity, only where its project allows it.

			**An issue with subtasks is refused -- subtasks are never
			deleted.** Jira answers HTTP 400; no operation here restores
			a deleted issue.

			Returns 0 when deleted, nothing on stdout. **3**: outcome
			UNKNOWN -- the delete may still have taken effect; read the
			issue before acting again, never repeat blindly. **9**: site
			refused -- not deleted, retry won't change that (the subtask
			refusal arrives this way, HTTP 400 in the line). Every other
			status also means not deleted. A 404 (status 8) does NOT
			establish the issue is absent.

			A failure prints one stderr line: the mark, this operation's
			name, the status, and Jira's body verbatim.

		--client-comms-jira-board-list <team-member> [--start-at <n>]
			Runs only as a `client-*` member, under that member's own
			credential, against that external organisation's own Jira;
			any other name is refused with 1. Output, paging and exit
			statuses are as `--member-comms-jira-board-list` describes.

		--client-comms-jira-board-read <team-member> <board-id>
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--member-comms-jira-board-read` describes.

		--client-comms-jira-board-issue-search <team-member> <board-id> [--start-at <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--member-comms-jira-board-issue-search`
			describes.

		--client-comms-jira-sprint-list <team-member> <board-id> [--start-at <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--member-comms-jira-sprint-list` describes.

		--client-comms-jira-sprint-issue-search <team-member> <sprint-id> [--start-at <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--member-comms-jira-sprint-issue-search`
			describes.

		--client-comms-jira-issue-search <team-member> <jql> [--limit <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-issue-search` describes.

		--client-comms-jira-issue-read <team-member> <issue-key> [--format adf|rendered]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--member-comms-jira-issue-read` describes.

		--client-comms-jira-comment-read <team-member> <issue-key> [--format adf|rendered] [--start-at <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-comment-read` describes.

		--client-comms-jira-issue-create <team-member> --project <key> --issuetype <name> --summary <text> [--description-adf <json>|--description-adf-from-stdin|--description-adf-from-file <path>] [--fields-json <json>]
			Runs only as a `client-*` member, writing to that external
			organisation's own Jira under that member's own credential;
			any other name is refused with 1. Everything else is as
			`--magic-comms-jira-issue-create` describes.

		--client-comms-jira-issue-update <team-member> <issue-key> [--fields-json <json>] [--update-json <json>] [--notify-users]
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-issue-update` describes, except
			a status change goes through
			`--client-comms-jira-issue-transition`.

		--client-comms-jira-issue-transition <team-member> <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>|--comment-adf-from-stdin|--comment-adf-from-file <path>]
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-issue-transition` describes.

		--client-comms-jira-comment-add <team-member> <issue-key> (--body-adf <json>|--body-adf-from-stdin|--body-adf-from-file <path>)
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-comment-add` describes.

		--client-comms-jira-issue-delete <team-member> <issue-key>
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-issue-delete` describes.

		--magic-comms-trello-post-comment <team-member> <card-id> (text...|--from-stdin|--from-file <path>)
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

		--librarian-inbox-item-trash <team-member> <item-filename> --from-inbox:<member>
			Discards one of `<member>`'s inbox items -- live or already
			processed. Searched in order: the live inbox root, then its
			`processed/`; first match wins, so a basename in both leaves
			the processed copy untouched -- root-first, so the copy
			discarded is always one the caller could have read. `--from-
			inbox:` is colon-style only. `<member>` must be a bare name;
			`<item-filename>` a bare name ending `.md`. No type-prefix
			restriction -- a misfiled board-type document (`task-*`,
			`proposal-*`, ...) sitting in an inbox is exactly what this
			clears. Not found in either directory, the error names both.

			**No inverse, whatever team-data's git state.** Git-tracked:
			deleted outright and committed, no copy left. Not tracked:
			moved to `trash/`, recoverable only by hand -- this op still
			won't restore it. Treat every call as final.

		--librarian-inbox-to-processed <team-member> <item-filename> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves one item out of `<team-member>`'s own live inbox root
			into that inbox's `processed/`, deleting the original.
			`<item-filename>` must be a bare name ending `.md`. No
			`--from-inbox:<member>` here -- the source is always the
			acting member's own inbox; `--from-state:`/`--from-inbox:`
			are both rejected if given. `--header:*` and the three body-
			input modes behave as on the `--magic-board-to-*` family.

			Auto-stamps `processed-at` on the drained item unless: the
			caller gives `--header:<op>:processed-at` (including
			`:remove:` for no stamp); the body already carries
			`processed-at` in its own frontmatter; or the body has no
			complete frontmatter block to stamp into.

			Refuses rather than overwrites if `processed/` already holds
			that basename, leaving the source in place -- a refused call
			is safe to fix and re-run.

			**ONE-WAY** -- the original is deleted once the processed/
			copy is written. Treat every call as final.

		--member-inbox-note-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]
			Writes (creates or overwrites) a note into `<member>`'s own
			inbox. Checks nothing about who is writing -- whose inbox a
			member may write into is a team rule, not enforced here.
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

		--member-upsert-member-inquiry <member> <item-filename> [--from-file <path>]
			Passes an inquiry into a member's own inbox -- the standard
			hand-off mechanism. `<member>` must exist as a real skill
			directory; `<item-filename>` a bare filename. Inbox created
			lazily if missing. Content via stdin by default, or
			`--from-file <path>`.

		--member-inbox-reflection-upsert <member> <item-filename> [--from-file <path>|--edit-patch-from-stdin]
			Writes (creates or overwrites) a reflection-type item into a
			member's own inbox. Same arguments, lazy inbox creation,
			stdin/`--from-file` content and `--edit-patch-from-stdin`
			patch behaviour as `--member-inbox-note-upsert` (which
			rejects patch mode; this accepts it). The content follows a
			fixed shape: frontmatter, then a `# Reflection: <title>`
			heading, then `## What happened` and
			`## Why this is worth keeping` sections. `<item-filename>` is
			conventionally expected to contain "reflection-", not
			enforced. The old name `--member-upsert-inbox-reflection`
			still works as an alias.

		--member-append-session-transcript <team-member> --speaker <speaker-name> --timestamp <ISO-UTC-date-time> (--message <verbatim-text>|--from-stdin|--from-file <path>) --transcript-name <transcript-file-name> --workspace-root <path> [--create]
			Appends one canonical transcript-entry block: `<speaker-name>
			(<timestamp>):` followed by quoted message lines, to the
			team's shared audit tree (not a board state folder). The
			month bucket it lands in comes from the date embedded in
			`<transcript-file-name>` (`transcript-YYYY-MM-DD-*`), falling
			back to the current UTC year-month otherwise.
			`<team-member>` must already be a real team member.
			`--workspace-root` must be an absolute, existing directory.
			Does not rewrite prior content. Missing target transcript is
			an error unless `--create` is passed. Payload from exactly
			one of `--message`, `--from-stdin`, or `--from-file <path>`
			(`--message-from-stdin` is an alias of `--from-stdin`).
			Returns the target path plus added line and byte counts.

		--member-inbox-item-read <member> <item-filename> [--start-line <N> --end-line <N>]
			Read-only read of one item in `<member>`'s own inbox, by bare
			`<item-filename>`. Searches the live inbox root first, then
			its `processed/`, first match wins. `<item-filename>` must
			carry one of the four type prefixes: `note-`/`inquiry-`/
			`reflection-`/`warning-`. `--start-line`/`--end-line` must be
			given as a complete pair.

		--member-inbox-item-trash <member> <item-filename>
			Discards one item out of `<member>`'s OWN inbox. No
			`--from-inbox:<member>` here -- one supplied in any position
			is REFUSED, so a member-scoped call can never become a
			cross-member one (use `--librarian-inbox-item-trash` for
			another member's inbox). Resolution as
			`--member-inbox-item-read`: live root then `processed/`,
			first match wins, not found in either names both. No
			type-prefix restriction. An item carrying `archive: true` is
			discarded like any other -- that header only diverts the
			heartbeat GC's own retention clock.

			**No inverse, whatever team-data's git state** -- same as
			`--librarian-inbox-item-trash`: deleted and committed when
			git-tracked, moved to `trash/` and recoverable only by hand
			otherwise. Treat every call as final.

		--member-audit-item-read <team-member> <document-name> [--start-line <N> --end-line <N>]
			Read-only read of one audit document by logical identity, not
			a filesystem path. Caller gives only `<team-member>` and a
			bare `<document-name>`; path-like names are rejected. Fails
			loud if missing or ambiguous. Only `transcript-*` names are
			permitted. `--start-line`/`--end-line` must be a complete
			pair.

		--member-vault-item-read <team-member> <item-name> [--start-line <N> --end-line <N>]
			Read-only read of one vault item (a verbatim document or
			fact under the team-data store's `vault/`) by bare
			`<item-name>`; path-like names are rejected. Any bare name is
			accepted -- vault document types are open. Fails loud if
			missing. `--start-line`/`--end-line` must be a complete pair.

		--member-board-item-read <team-member> <item-name> [--board-state <state>]... [--start-line <N> --end-line <N>]
			Read-only read of one board item by bare `<item-name>`
			(`<type>-<name>.md`). Repeatable `--board-state` narrows
			lookup folders; omitted, all board states are searched in
			canonical order. `--start-line`/`--end-line` must be a
			complete pair.

		--owner-workspace-upsert <path>
			Adds one filesystem path to the human-owner's tracked workspace
			list at $HOME/.claude/skills/.human-owner.workspaces.md -- a
			bare, one-absolute-path-per-line file, the ONLY authoritative
			source for the workspace paths the magic-* team tracks.
			<path> must be absolute (starts with `/`); a trailing slash
			is stripped before comparing/storing, so `/foo/bar` and
			`/foo/bar/` collapse to the same entry. Idempotent -- an
			already-tracked path is a harmless no-op. Existence of <path>
			on disk is not checked (a tracked workspace may live on a
			currently-unmounted volume). The directory and file are
			created on first use.

		--owner-workspace-forget <path>
			Removes one filesystem path from the same tracked workspace
			list. Same trailing-slash normalization as
			--owner-workspace-upsert. Forgetting an untracked path, or
			when the file doesn't exist yet, is a harmless no-op.

		--owner-workspace-list
			Prints every tracked workspace path, one per line, in file
			order -- reads only lines that look like an absolute path, so
			stray non-data content in the file is read as commentary, not
			a tracked path. Takes no arguments. Prints nothing (no error)
			if the file doesn't exist yet or has no tracked paths.

		--owner-workspace-current
			Registers this tool's own workspace root ($MMDAPP) into the
			tracked workspace list, exactly as --owner-workspace-upsert
			does, then prints that path to stdout. Takes no arguments --
			a convenience for "track my current workspace and tell me its
			path" in one call.

		--owner-setup-<domain> [<config-option>...] [--all-workspaces] [--set-as-default] [--check|--apply|--print-apply-command|--wizard]
			Reports, and where supported carries out, the setup of one
			macro part of a working installation. `<domain>` is open and
			grows; `claude`, `copilot`, `grok`, `slack`, `storage` and
			`scaleway` exist today; a domain with no defined check set
			says so rather than inventing one.

			Options and their values come first, then at most one sub-operation
			LAST -- anything after a sub-operation is an error, and so is an
			option whose meaning depends on a sub-operation that is absent.

			`<config-option>` stands for this domain's own configuration
			options, which differ per domain and so are listed per domain
			below rather than on the family line. The flags after it are
			family-wide and mean the same thing for every domain.
			--print-apply-command writes the list for any domain that declares
			options, so one not listed below is still readable at runtime. A
			domain that declares none is refused, not answered with an empty
			list.

			A value the setup would store -- one of this domain's own
			configuration options, --access-root, or --values-from-stdin, which
			reads a set of them as KEY=VALUE lines -- is accepted only together
			with --apply, and refused rather than taken and dropped anywhere
			else. --workspace-root is not one of these: it names which
			workspace a call is about rather than a value to store, so every
			sub-operation takes it.

			With no sub-operation, writes a readable status for the current
			workspace and names the command that sets the domain up. What
			it asks for is only what the domain REQUIRES and does not yet
			have; an optional setting is left to --print-apply-command,
			named once nothing required is left waiting. --check
			writes the per-setting detail instead. --apply carries the setup
			out, non-interactively, for a domain that implements it.
			--print-apply-command writes the command that would carry it out,
			naming every option this domain declares, required and optional,
			set or not, with a placeholder per value and a short line per
			option saying where that value comes from. A domain whose options
			are all plain gets one command line; a domain carrying a secret
			gets a stdin-fed form instead -- its secrets as KEY=<placeholder>
			lines piped into --values-from-stdin --apply -- so no secret is
			written on a command line. It changes nothing and exits 0; --check
			is the sub-operation that reports whether the domain is set up.
			--wizard is the interactive form and is not built yet.

			--all-workspaces widens a report from the current workspace to every
			workspace the skillset installer has registered. Accepted only by a
			domain whose diagnosis spans workspaces, and never combined with
			--apply, which changes exactly one workspace, or with
			--print-apply-command, which writes the command for exactly one.

			--set-as-default points the domain's service selection at this
			domain. Without it, an apply takes the selection only when nothing
			is selected at all, so an existing selection is never overwritten by
			accident. Accepted only by a domain that owns a selection, and only
			together with --apply.

			Configuration options, `claude`:
			  --workspace-root <path>   the workspace to set up. Its own
			      basic setting: it defaults to $MMDAPP, and a path that is
			      not a workspace root is an error rather than a fallback.
			  --access-root <path>      an extra directory a spawned agent
			      may read and write, beyond the member and source roots the
			      installer already grants. Repeatable. Optional.

			Configuration options, `slack`:
			  SLACK_CHANNEL_MAGIC_TEAM   the team channel id. Required.
			  SLACK_CHANNEL_HUMAN_OWNER  the human-owner's own member id.
			      Required.
			  SLACK_BOT_TOKEN            the team bot's token. Optional, but
			      given only together with SLACK_WORKSPACE_DOMAIN.
			  SLACK_WORKSPACE_DOMAIN     the workspace subdomain. Optional,
			      given only together with SLACK_BOT_TOKEN.
			  SLACK_CHANNEL_EVENT_TRACK  the activity-log channel id.
			      Optional: unset, that traffic goes to the team channel.
			  SLACK_CHANNEL_EVENT_ALERT  the alert channel id. Optional:
			      unset, that traffic goes to the team channel.
			  A member's own user token is not a workspace setting, so this
			  domain does not ask for it.

			Configuration options, `storage`:
			  TEAM_DATA_DIRECTORY   where the team data lives. Optional:
			      unset, it is the workspace's own team-data root.
			  TEAM_DATA_GIT_REMOTE  the team-data repository to push to.
			      Optional.
			  TEAM_DATA_BRANCH      the branch that repository tracks.
			      Optional: unset, "main".
			  TEAM_DATA_GIT_USER_NAME   the author name on the team-data
			      commits the tooling makes. Optional: unset, git's own
			      identity stands.
			  TEAM_DATA_GIT_USER_EMAIL  the author email on those commits.
			      Optional: unset, git's own identity stands.
			  A missing or empty store is cloned from TEAM_DATA_GIT_REMOTE
			  before anything writes into it, at most once per operation;
			  after a failed clone the main loop's own sync retries it.
			  `--apply` also makes the
			  store a repository: cloned when a remote is set, initialised
			  when none is. A store holding content that is not a clone of
			  a set remote is left alone, with a warning. The two identity
			  keys, when set, are written into the store repository's own
			  config; a repository with no author identity is a failed
			  check, naming both keys.

			Exit status is non-zero when a check fails, so it is usable as a
			readiness gate. A setting is judged by its value where that value is
			used, never by a config file existing.

			`claude`, `claude-native` and `copilot` each diagnose a workspace
			with the same per-workspace rows, and `WORKSPACE_HOOK_SCRIPTS`
			(readable row `Workspace hooks`) is one of them. It fails when a
			command hook that workspace's `.claude/settings.json` registers
			runs a `"$CLAUDE_PROJECT_DIR"/.claude/hooks/<script>` that is
			missing or not executable, naming each such entry. Its `fix:` is
			`--make-workspace-integrations`, which removes an entry for a hook
			this package retired. An entry left after that is not this
			package's hook: restore its script or remove the entry.

			`claude` and `claude-native` also carry two rows `copilot` does
			not. `MCP_REGISTRATION` (readable row `MCP servers`) fails when the
			workspace's `.mcp.json` lacks the myx.common or myx.distro entry,
			when `$HOME/.claude/settings.json` does not enable both in
			`enabledMcpjsonServers`, or when `$HOME/.claude.json` has no
			myx.common in that workspace's project `mcpServers`.
			`CLAUDE_PERMISSIONS` (readable row `Claude permissions`) fails when
			`$HOME/.claude/settings.json` lacks any of the fixed grants in
			`permissions.allow` or `permissions.deny`. Both name
			`--make-workspace-integrations` as their `fix:`. A settings file
			that does not parse fails its row with `fix: repair the JSON`; an
			unparseable or absent `$HOME/.claude.json`, or an empty MYXROOT,
			leaves `MCP_REGISTRATION` undetermined, a warning.

		--install-claude-permissions
			Merges this package's mandatory Claude Code permission grants
			into `$HOME/.claude/settings.json` (`permissions.allow`/
			`permissions.deny`) -- additive, never a blind overwrite:
			existing entries this op did not add are kept. `--workspace
			<path>` (default `$MMDAPP`) selects which workspace's rows
			are reconciled.

			Upserts the fixed grants (`mcp__myx_common`, `mcp__myx_distro`,
			`Agent`, `Task`, `SendMessage`, and one `Edit(<path>/**)` per
			acting team member's skillset directory) and denies `Bash`
			and the native Slack MCP server (`mcp__claude_ai_Slack`)
			unconditionally -- route shell commands through
			`mcp__myx_distro__execute`/`Monitor`, and Slack through the
			team's own `--member-comms-slack-*` ops instead. Sets
			`enabledMcpjsonServers` to `myx.common` and `myx.distro`.

			A scan failure or an empty workspace suppresses revocation
			rather than reading as "every grant disappeared" -- existing
			grants are left in place and the reason is reported. Fails
			loud and leaves the file untouched on any other failure. A
			run that changes nothing is reported as such.

		--install-workspace-restrictions [--workspace <path>]
			Installs Claude Code WORKSPACE-level permission rules (a
			standing Read allow-grant, deny rules, and `PreToolUse`
			hooks) into the target workspace's own `.claude/settings.json`
			-- distinct from `--install-claude-permissions`, which is
			$HOME-scoped. Default target is the current shell directory;
			`--workspace <path>` overrides it.

			Refuses (exit 1, nothing written) when `<workspace>` is not a
			genuine workspace root (no `<workspace>/.local`), naming a
			likely correct ancestor root when one is found.

			Idempotent: merges into existing files rather than
			overwriting, and a run that changes nothing is reported as
			such. Installs two fixed hook scripts (denying native-tool
			calls the team routes elsewhere, and denying `Read` on the
			memory system's `MEMORY.md`) and denies `Bash` outright. Also
			maintains a `.claude` symlink per namespace root under the
			workspace, kept in sync with the workspace's own namespace
			list.

			Before reporting success, re-reads the written settings file
			and confirms every expected hook is wired and every hook
			script referenced by any command hook actually exists and is
			executable -- reports each `OK`/`MISSING` by name, and any
			`MISSING` fails the run (exit 1).

		--install-skillset-symlinks [--scope workspace|user-home] [--workspace <path>]
			Installs skillset-link integration: symlinks every bundle
			member and every project-declared team-member into the
			scope's hidden skills directories (`.agents/skills`,
			`.claude/skills`, `.copilot/skills` as applicable), creating
			them if missing.

			`--scope workspace` targets `<workspace>/.agents/skills` and
			`<workspace>/.claude/skills`; `--scope user-home` targets
			`$HOME/.agents/skills`, `$HOME/.copilot/skills` and
			`$HOME/.claude/skills`. Default: workspace, falling back to
			user-home if the resolved workspace isn't a set-up myx.distro
			workspace and `--scope` wasn't given explicitly -- an
			explicit `--scope workspace` on such a workspace is an
			error. Default workspace is the current shell directory;
			`--workspace <path>` overrides it.

			A member declared by more than one project becomes a merged
			composite; a name both bundled and declared keeps the
			bundled copy, with the declared source shadowed and warned
			about, never silently overwritten. Idempotent: an already-
			correct link is left alone, and a run that changes nothing
			is reported as such.

		--install-vscode-integrations [--workspace <path>]
			Installs/updates baseline VS Code + Claude Code MCP
			integrations and the Magic-Team panel. Installs no chat-
			client extension itself -- that choice stays the user's.
			Wires `myx.common` into workspace `.vscode/mcp.json`,
			workspace-root `.mcp.json`, and Claude Code's home local
			scope (`~/.claude.json`). Each written entry is verified by
			re-reading it.

			Default target workspace is the current shell directory;
			`--workspace <path>` overrides it. Fails fast if the target
			isn't already a set-up myx.distro workspace. A missing VS
			Code CLI is irrelevant and not reported. A missing
			`~/.claude.json` is a warning only. Prints an OK/FAIL
			checklist plus Command Palette trust/restart guidance.

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
			Runs all `--make-*` commands, then
			--install-workspace-integrations, then
			--install-workspace-restrictions, against $MMDAPP. A step
			that fails ends the run; later steps don't run. `--quiet`
			suppresses the usage guidance normally printed.

		--make-console-command [--quiet]
			Re-creates `DistroAgentsConsole.sh`, the command to quickly
			enter the workspace console. `--quiet` suppresses the usage
			guidance normally printed.

		--make-console-script
			Prints the agents console script body (used by
			`--make-console-command`) and exits.

		--magic-grooming-to-backlog <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Moves a board item to board/backlog/ and/or patches its
			frontmatter, one call -- no full-content rewrite required.
			`--edit-patch-from-stdin` takes a JSON array of `{"old":
			<text>, "new": <text>, "replace_all": <bool, default
			false>}` patches on stdin, applied in order as exact literal
			substring match-and-replace against the body. `--from-
			state:<state>` and `--owner-header-value` are both required;
			`groomed-at`/`groomed-from`/`track` are always auto-stamped,
			never caller-supplied. `--header:*` and the three body-input
			modes pass through for whatever else the move also needs.

		--magic-grooming-to-pending <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/pending/ -- the Advancement-review case (backlog ->
			pending), e.g. `--header:upsert:approved-by:"<team-member>
			(<session-id>, <date-time>)" --header:upsert:approved-at:
			<date>`. `approved-by`'s value is validated: must match
			`<team-member> (<session-id>, <date-time>)` with an ISO UTC
			date-time (suffix `Z`).

		--magic-grooming-to-processed <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/processed/.

		--magic-grooming-to-parked <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/parked/ -- a deliberate deferral by the team's own
			choice (distinct from board/blocked/, a stall on something
			external). `recheck-date` and `condition` are caller-
			supplied via `--header:*` -- triage judgments this op cannot
			compute.

		--magic-grooming-to-blocked <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/blocked/ -- stalled on something external (distinct
			from board/parked/, a deliberate stop). Stamps `owner`/
			`groomed-at`/`groomed-from`/`track`, which is what
			distinguishes this from `--magic-board-to-blocked`: same
			target state, but that one stamps nothing. `recheck-date`
			and `condition` are caller-supplied via `--header:*`.

		--magic-grooming-to-running <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/running/. Distinct from `--magic-advance-to-running`,
			which targets the same state under a different owning
			routine and different recorded provenance -- this one
			stamps `owner`/`groomed-at`/`groomed-from`/`track`.
			`started-at` is also stamped, as on every move or create
			into board/running/ -- pass
			`--header:upsert:started-at:<date-time>` to override it.

		--magic-grooming-to-archived <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/archived/ -- a Drop outcome, or a re-check step
			concluding a parked trigger is never coming or a blocked
			item isn't worth waiting on. Still stamps `owner`/`groomed-
			at`/`groomed-from`/`track` despite the target being terminal
			-- who archived an item, and from where, is exactly what a
			later reader needs. The archived reason text is caller-
			supplied via `--header:*` or the body-input modes.

		--magic-grooming-to-retained <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/retained/ -- but a SAME-STATE PATCH, not a move: call
			with `--from-state:retained` so source and target match and
			nothing relocates; the existing body is read-and-preserved
			rather than replaced. The renewed `recheck-date` is caller-
			supplied via `--header:*`. The usual grooming stamps apply;
			on a same-state call, `groomed-from` records `retained`,
			meaning groomed while sitting there, not arrived from
			elsewhere.

		--magic-grooming-create-backlog <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
			Creates a board-item directly in board/backlog/ -- a first
			write, not a move: the promoted default landing for an inbox
			item the authority group promotes. `--from-state:` is
			rejected (nothing to move from). `owner`/`groomed-at`/
			`track` are stamped; `groomed-from` is NOT (nothing moved
			from). Exactly one body-input mode is required -- there is
			no existing body to carry forward. `communication-channel-
			id`, `approved-by`/`approved-at`, `blocks`/`blocked-by` and
			`references` ride `--header:*` in this same write.

		--magic-grooming-create-processed <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
			As `--magic-grooming-create-backlog`, target board/processed/
			-- a promoted-or-denied item landing with its resolution
			text attached.

		--magic-grooming-create-pending <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
			As `--magic-grooming-create-backlog`, target board/pending/
			-- a promotion where the group's own context already
			warrants approval at creation.

		--magic-grooming-create-blocked <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
			As `--magic-grooming-create-backlog`, target board/blocked/
			-- a promotion that needs human-owner approval, so the item
			lands blocked.

		--magic-grooming-create-running <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
			As `--magic-grooming-create-backlog`, target board/running/
			-- the approval-* item the human-owner approval negotiation
			runs in.

		--magic-grooming-input-scan <team-member>
			Read-only: lists board items as `<state>/<item-filename>`,
			one per line, with every frontmatter field. Always scans
			backlog/pending/running/blocked/parked. Use this to find an
			item's actual current state before calling
			`--magic-grooming-to-*`. Also returns routine-grooming's own
			state-and-lock note content ahead of the board rows (content
			only, never evaluates the lock; absent is reported as
			nothing to report, not an error), and the team roster cache
			as its own section (same content-only, not-an-error-if-
			absent terms) -- no need to call `--magic-team-roster-read`
			separately after this. `<team-member>` is the only
			argument.

			Inbox scope is `<team-member>`'s own inbox PLUS every
			`client-*` member that exists as a skill directory, each in
			its own "Additional Inbox -- <member>" group. Widening the
			read is all it does: the acting identity stays
			`<team-member>`, no client credential or comms source is
			read, and nothing
			is written into a client inbox.

		--magic-sweep-input-scan <team-member> [--comms-since-utime <v>|--comms-since-date-time <v>]
			Read-only combined check pass: backlog/pending/running/blocked
			board items (not parked), the calling member's own watched
			sources, and every client-* member's own sources, each under
			that member's own credentials. Returns only items whose
			communication-channel-id is the three-field
			`slack:<channel>:<ts>` form -- a live, reply-pending Slack
			thread; a bare `slack:<channel>` or a non-slack service is
			not one. An empty result is a normal, clean outcome, not an
			error. No --state/--header override.

			One document covers everyone swept. A client member's own
			part matches what --client-sweep-input-scan returns on its
			own, with its own `# Incoming Communications Sweep --
			<member>` heading and `member:`/`member-kind:` lines. A
			client member whose own sweep recorded no coverage still
			gets a block saying `no scan was made`, so it never reads as
			a member with nothing new, and is never silently missing.

			An optional cut-off narrows the read: --comms-since-utime
			(epoch seconds, fractional part optional) or
			--comms-since-date-time (YYYY-MM-DD-leading), mutually
			exclusive, neither repeatable -- passed unchanged to every
			client member's own sweep.

			**Not a workspace-wide mention search:** a conversation or
			mention outside the already-watched sources stays
			undiscoverable here.

			Exit code, the combined verdict over the calling member and
			every client member swept, as one document -- the body
			reports the same coverage in `sources-scanned: N of M` and
			`NOT SCANNED`/partial markers, matching the exit code:
			0 every one of them scanned every source.
			3 some sources read, some not -- partial, never complete.
			4 none of them read anything.
			1 failed before producing a document.
			A client member's own failure counts as 4, never 1, once a
			document exists.

		--magic-sweep-state-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]
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

		--magic-sweep-state-read <team-member>
			Reads back the whole record written by --magic-sweep-state-upsert
			for that member, verbatim. Outputs `NO_STATE` if nothing is stored
			yet. Read-only.

			With a <source-key> it prints THAT source's own pointer instead --
			the `source-<key>-last-swept-ts:` entry -- under exactly the same
			three-outcome contract, where rc 3 means this member has never
			swept that source. A caller getting rc 3 falls back to the global
			pointer as that source's floor: never to 0, and never to "nothing
			to read".

			The key is `<auth-user-id>-<conversation-id>`: persona AND
			conversation, never the conversation alone. The same DM is
			reachable under two identities, so a key naming only the
			conversation would let whichever persona swept first move the
			pointer for the other, and the second persona's unread messages
			would then sit below a pointer it never set.

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
			the per-member persona subsections. `--magic-grooming-input-scan`
			already returns this same content as its own section, so a
			routine working from that scan does not call this op too.
			Outputs the record content, or
			`NO_RECORD` if none is stored yet. Read-only.

		--magic-team-data-commit-pending <team-member> [--commit-message <message>] [--no-push]
			Commits everything pending under the team-data store in one
			commit -- new, changed and deleted paths -- and pushes it the
			way --intern-op-item-upsert does, with one retry on a network
			failure. Every other team-data op commits only the paths it
			writes itself; this one is for work left uncommitted.
			<team-member> must be magic-coordinator. Nothing outside
			$MDAT_DATA_ROOT is staged or committed, even when the store
			sits inside a larger repository.

			Prints `TEAM-DATA-NOTHING-PENDING: <store>` when there is
			nothing to commit. Otherwise it prints
			`TEAM-DATA-COMMITTED: <commit> <n> path(s) under <store>`,
			then one `<status><TAB><path>` line per path (A, M, D, R...),
			then one of `TEAM-DATA-PUSHED: <commit> to origin, read back as
			origin/<branch> = <full-sha>` (the remote branch is read back
			after the push and must name this commit, or the op exits 1),
			`TEAM-DATA-NOT-PUSHED: no TEAM_DATA_GIT_REMOTE is configured`
			or `TEAM-DATA-NOT-PUSHED: --no-push`. It also does not push,
			and says why, when the store is inside a larger repository
			rather than its own root, or when that repository's origin is
			not TEAM_DATA_GIT_REMOTE: a push sends the whole branch. A
			failed push prints `TEAM-DATA-NOT-PUSHED: the push failed;
			...`, and the op exits 1 with the commit kept locally. A store
			that is not in a git repository is refused. So is one showing
			an interrupted operation -- an index.lock, or a merge,
			cherry-pick, revert or rebase in progress: it prints
			`TEAM-DATA-REFUSED: the repository shows an interrupted
			operation: <which>`, exits 1 and repairs nothing. Commits
			already ahead of origin go out with the push.

			Run it when no routine holds the advance or heartbeat lock: it
			takes no lock, so a file another op is writing at that moment
			could be committed half-written.

		--client-sweep-input-scan <team-member> [--comms-since-utime <v>|--comms-since-date-time <v>]
			Read-only: one client-* member's own incoming
			external communications -- Slack, email and Trello -- read as
			that member, under that member's own credentials, from that
			member's own configured sources. Use it to sweep one external
			relationship's traffic; use --magic-sweep-input-scan for the
			team's own.

			The member name is the only required argument, and it must be
			a client-* one -- a partner-* member is not accepted. The
			document's entire scope is that one member; no other
			member's traffic is in it. Each section states our own side
			of that source
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

			Exit code: 0 when every source was scanned, 3 when some were
			and some could not be, 4 when none could be, 1 when the
			operation failed before producing a document.

		--member-wait-for-input <team-member> [--wait-source <kind>:<target>]... [--wait-timeout <seconds>] [--wait-poll-interval <seconds>] [--wait-since-utime <epoch>] [--wait-addressee <slack-user-id>] [--wait-include-own]
		--member-wait-for-input <team-member> --wait-list-sources
			Waits on a list of input sources and returns as soon as
			any of them changes, or when the timeout expires.

			stdout ALWAYS opens with exactly one marker line:
			`WAIT-RESULT: RECEIVED` -- something arrived, and what
			that source holds now follows; `WAIT-RESULT: TIMEOUT` --
			the bound expired with nothing new; `WAIT-RESULT: ERROR`
			-- the wait could not be performed, see stderr. RECEIVED
			and TIMEOUT both exit 0, because both are answers; ERROR
			exits 1. A TIMEOUT is a COMPLETE, SUCCESSFUL wait, not a
			failure and not an error: those sources were read and held
			nothing new. What to do after a quiet wait -- wait again,
			look elsewhere, or escalate -- is the caller's own
			escalation rules, never this operation's.

			A source is `<kind>:<target>` and --wait-source is
			repeatable. Given none, the sources are `slack:magic-team`
			and `slack:human-owner`. `slack:<conversation>` waits on a
			conversation, `slack:<channel>:<ts>` on that one message's
			thread, `slack:<channel>:<ts>:conversation` on any new post
			in that thread that is not this member's own, and
			`file:<absolute-path>` on a local drop path,
			file or directory alike -- an absent path is a state, not
			a failure, and a drop appearing later is exactly the
			arrival being waited for. --wait-list-sources prints the
			source kinds this build carries and waits on nothing.

			--wait-timeout is the bound in whole seconds, default 300.
			--wait-poll-interval is whole seconds between probes,
			default 15, minimum 1 -- it never changes the outcome,
			only how soon within the bound an arrival is noticed.
			--wait-since-utime takes epoch seconds: give it when
			waiting for something at or after a moment already known,
			such as a message just posted, so a reply already sitting
			there returns immediately rather than reading as part of
			the scenery. Without it the first probe is the baseline
			and only a later change counts.

			--wait-addressee names the Slack accounts whose answer
			counts, and is required with a `slack:<channel>:<ts>` thread
			source, which must then be the only source and needs
			--wait-since-utime set to the question's own ts. Only a
			reply from one of those accounts, or its reaction on the
			question, is an arrival; no message text decides it.
			`slack:<channel>:<ts>:conversation` is a thread source too --
			same only-source and --wait-since-utime requirement -- but
			takes no --wait-addressee: any new post counts, not just one
			party's reply, and this member's own posts never count as
			an arrival, matched against the sender its own sends already
			carry (see --member-comms-slack-send-message's `--metadata`),
			unless --wait-include-own is given. That flag only changes
			anything on this one source shape, where it lifts the default
			skip of this member's own posts; on every other source they
			already count, so the flag is refused there rather than
			silently doing nothing.
			The --wait-since-utime value need not name a real message
			here, unlike an ordinary thread source -- a bare call defaults
			it to the current time, as a synthetic floor.

			A source kind this build does not carry is an ERROR at
			second zero, naming the kinds that exist -- never a source
			that silently never fires for the length of the bound. A
			probe that cannot run is named in the body and the wait
			carries on over the remaining sources; a TIMEOUT body then
			states that nothing is known about those sources either
			way, so their silence must not be read as quiet.

			A source that was never read once during the wait is also
			named on a second line, right after the marker:
			`WAIT-NEVER-READ: [<kind>:<target>] ...`. The line is
			absent when every source was read at least once. It never
			changes the outcome or the exit code. The TIMEOUT text
			claims a read only for the sources that were read: none
			read says that nothing is known at all, and a mix names
			which sources were read and which never were.

			On a thread source (`slack:<channel>:<ts>`, or its
			`:conversation` form), RECEIVED also ends with a line naming
			the newest message it just showed:

			    WAIT-LAST-TS: <ts>

			Pass that ts back as the next call's --wait-since-utime to
			keep reading forward without re-parsing the body for it.
			Absent on a bare conversation or file source: neither prints
			one message per line, so neither has a single ts this line
			could name.

		--member-escalation-read <team-member> <request-id>
			The verdict of one escalation: an AskUserQuestion of kind
			readback, decision or permission. <request-id> is the
			pending-reply id the question printed ("recorded as pending
			reply <id>"). An answered one prints
			`ESCALATION: <id> answered`, then `VERDICT:`,
			`VERDICT-TEXT:` for a readback correction, `ANSWERED-BY:`
			and, for an allow, `GRANT:`. One not answered yet is read
			now: the question's own thread, then a forward's thread.
			An answer from an addressee there is applied exactly as a
			waiting question applies it. With none it prints
			`ESCALATION: <id> open` and `VERDICT: UNCLASSIFIED`, with
			`VERDICT-REASON:` when an answer was seen and not taken.
			An answer from the account that asked is never taken.

			While a typed escalation waits, the first reply from an
			addressee ends the wait. It is judged against every reply
			since the question, and the asker's own posts never count.
			A reply that names no valid answer returns to the asking
			agent as `VERDICT: UNCLASSIFIED`, with its reason and the
			reply text, and the record stays open. Nothing is posted
			for it automatically. The result's last line is the exact
			re-wait call, `AskUserQuestion pending_id=<request-id>`. It
			posts nothing and waits on the same thread again, and only
			the session that asked may make it. An older record with no
			session id can be re-waited on from any session, but for a
			permission it grants nothing there, because the grant is
			keyed to the record's own session.

		--member-escalation-answer <team-member> <request-id> <verdict> [text]
			Answers one open escalation as <team-member>, which must be
			the member it was addressed to and not the member who
			asked. This is how a member with no Slack account of its
			own, the coordinator included, answers. The verdict must
			belong to the kind: yes, no or correct for a readback, the
			answering word of one option for a decision, and deny,
			allow-once or allow-session for a permission. [text]
			carries a readback correction.

			The record closes carrying the verdict and who gave it. An
			allow is written as a grant for the refused call named in
			the refusal record, never for anything the ask's own words
			said, and signed by <team-member>. The waiting question
			ends on it and its session retries the exact call. A second
			answer to the same escalation is not applied. The answer is
			also said in the question's own thread.

		--magic-escalation-forward <coordinator> <request-id>
			Forwards one open escalation addressed to <coordinator> to
			the human-owner, keeping the same record. The question is
			posted to the human-owner as the team bot. His reply or
			declared reaction in that thread is the verdict for the
			original request, and the waiting question ends on it.
			Only the member the escalation is addressed to can forward
			it, and only while it is open.

		--member-pending-reply-read <team-member> [<pending-id>] [--all] [--any-owner]
			Reads the records AskUserQuestion leaves, of any kind. With
			<pending-id>, prints that one record. Without it, lists the
			member's own open records, then `PENDING-REPLIES: <count>`.
			`--all` adds closed ones, and `--any-owner` lists every
			member's. Each record prints `PENDING-REPLY: <id>`, then
			status, owner, kind, question-tag, channel, question-ts,
			thread-ts, address-to, session-id, asked-at and, once
			closed, resolved-at, verdict and answered-by, then
			`question:` with its first line. It changes nothing, and it
			reads no thread, so an answer still in the thread is not
			shown here.

		--member-pending-reply-settle <team-member> <pending-id> --reason <text>
			Closes one of the member's own open questions that no longer
			needs an answer, such as one settled elsewhere. It is
			recorded as received, with verdict `settled: <text>` and
			answered-by `<team-member> (settled)`, and prints
			`SETTLED <id>`. Only the member that asked it can settle
			it. A readback, decision or permission is refused, because
			it closes through its own escalation ops. A record already
			closed prints `ALREADY-CLOSED <id> <status>` and is left
			as it is.

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

		--member-work-session-input-scan <team-member>
			Read-only: one member's own current work-session input --
			personal, not routine-dictated (every armed member runs this
			against its own name as it becomes armed, regardless of which
			routine triggered the arming). Returns that same member's own
			inbox first, as two sections: its reflections, then its notes
			(`## inbox/<item-filename>`, frontmatter and body; top-level
			items only, processed/ excluded, at most 64 each). A section with
			nothing in it, a not-yet-created inbox/ included, prints a note
			saying so, not an error. Inquiries and
			other inbox items are not returned. Then its board items:
			pending/running/blocked, restricted to the items owned by
			<team-member>, every board-item type, every frontmatter field,
			no body; where it owns none, this part prints nothing.
			<team-member> must be a real member skill directory,
			and is the only argument -- no --state/--header override.

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

		--magic-heartbeat-input-scan <team-member>
			Read-only: routine-heartbeat's own prepared input, narrowed to
			what that routine's own steps consume. Returns routine-
			heartbeat's own state-and-lock note content first (the same
			document --magic-heartbeat-state-read prints; a note that
			doesn't exist yet reports as nothing to report, not an
			error; content only, never evaluates the lock). Then, under
			a `## board digest` heading, `<team-member>`'s own inbox
			reflections: top-level items only, processed/ excluded, at
			most 64, each with frontmatter and body. No board items.
			Before the digest, a `## questions (pending replies)`
			section shows the main loop's last collect of unanswered
			questions, then every question still open, from any member,
			with its session, asker and age. Then a `## spawned
			sessions` section: each spawn's recorded close status and
			exit code, and whether its process is alive now.
			`<team-member>` is the only argument -- no --state/--header
			override.

		--magic-heartbeat-config-check
			Read-only, no arguments -- routine-heartbeat's step-0
			upfront config gate. Checks magic-coordinator's own config
			for TEAM_DATA_DIRECTORY and the EMAIL_*/TRELLO_* keys below,
			and magic-team's for the four SLACK_CHANNEL_* keys,
			SLACK_BOT_TOKEN and TEAM_DATA_GIT_REMOTE.

			Prints one `<KEY>: OK`/`WARN`/`FAIL`/`SKIP` line per key
			(name only, never the value). OK is set; WARN is set but
			suspect; FAIL is required and unset, and is the only token
			that gates the exit code; SKIP is optional and unset. Keys
			checked: TEAM_DATA_DIRECTORY, SLACK_CHANNEL_EVENT_TRACK,
			SLACK_CHANNEL_EVENT_ALERT, SLACK_CHANNEL_MAGIC_TEAM,
			SLACK_CHANNEL_HUMAN_OWNER, EMAIL_IMAP_HOST, EMAIL_USER,
			EMAIL_APP_PASSWORD, TRELLO_KEY, TRELLO_TOKEN.
			TEAM_DATA_DIRECTORY is optional and never SKIP: unset, it
			reads OK and names the workspace's own default. Required:
			the four SLACK_CHANNEL_* keys -- any missing also prints a
			fix command and returns 1. The other five, plus
			SLACK_BOT_TOKEN and TEAM_DATA_GIT_REMOTE, are optional --
			unset they read SKIP, print their own fix command, and never
			affect the exit code. For the credential-bearing keys
			(EMAIL_APP_PASSWORD, TRELLO_KEY, TRELLO_TOKEN,
			SLACK_BOT_TOKEN) that fix command is the
			`--upsert-from-stdin` form, so following it never puts a
			secret in argv.

		--magic-advance-batch-outcome <team-member> --items:<item-filename>:<outcome>:<execution-receipt>[,<item-filename>:<outcome>:<execution-receipt>]...
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

		--magic-advance-input-scan <team-member>
			Read-only: routine-advance's own board scan (the same scan
			routine-update-board and routine-heartbeat read). Scans
			pending/running/blocked/parked, every board-item type, every
			frontmatter field -- not backlog, which is
			--magic-grooming-input-scan's. Each row is labelled
			`<state>/<item-filename>`; a caller needing a narrower view
			selects from the rows itself. Also returns routine-advance's
			own state-and-lock note content ahead of the board rows
			(content only, never evaluates the lock; absent reports as
			nothing to report, not an error). `<team-member>` is the
			only argument -- no --state/--header override. After the
			board digest come three sections: `## team members`, `##
			spawned sessions` and `## pending replies`.

			Inbox scope is `<team-member>`'s own inbox, notes only: the
			pending-slack-reaction and pending-trello-update records the
			routine's comms step acts on. No inquiries, no reflections,
			no client-* inbox -- those are --magic-grooming-input-scan's.

		--magic-advance-to-running <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
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

			Auto-stamps `started-at` (date-time) on every move into
			board/running/.

		--magic-advance-to-parked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/parked/ -- routine-advance's own
			check-execute-board fallback when a required spawn could not
			run. No auto-stamp: the calling step supplies condition/
			handoff-action/recheck-date/execution-receipt itself via
			`--header:*`; an item left with no recheck-date deliberately
			falls to routine-grooming's slower cadence, so this op never
			invents one.

		--magic-board-to-pending <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/pending/. No auto-stamp.

		--magic-board-to-blocked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/blocked/. One auto-stamp:
			`execution-receipt` defaults to `blocked:<timestamp>` unless
			the caller supplies its own via `--header:upsert:execution-
			receipt:*`/`--header:append:execution-receipt:*`, in which
			case the caller's value stands.

		--magic-board-to-backlog <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/backlog/. No auto-stamp.

		--magic-board-to-parked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/parked/ -- check-process-board's own
			move, the board-mechanical-moves counterpart. No auto-stamp
			here, and no `--magic-board-*` op stamps grooming provenance
			(the closing -to-blocked and -to-processed moves stamp their
			own fields instead). `recheck-date`/`condition` are caller-
			supplied via `--header:*`.

		--magic-board-to-processed <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
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
			else is stamped.

		--magic-board-create-running <team-member> <item-filename> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
			Creates a board-item directly in board/running/ --
			check-process-board's own and only creating step: the
			approval-* item raised when a board-backlog item is flagged
			for human-owner approval (the move half of that same step is
			`--magic-board-to-blocked`). `--from-state:` is rejected: a
			created item has no source state. No auto-stamp.
			`blocks`/`blocked-by` ride `--header:*` in this same write.
			One body-input mode is required.

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

		--magic-advance-lock-refresh <team-member>
		--magic-grooming-lock-refresh <team-member>
		--magic-daily-lock-refresh <team-member>
		--magic-retro-lock-refresh <team-member>
			Re-asserts a held lock so a long run is not mistaken for a
			crashed one. Prints `REFRESHED` (rc 0), or `NO_LOCK_HELD` (rc 1)
			when nothing is held. Takes no options; any further argument is
			rejected.

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
				Replace the whole note, frontmatter included, with this
				file's contents -- a field the file does not carry is gone
				from the note. `session-id` is the exception: it is carried
				forward, so a body-replacing write cannot orphan the lock.

			--edit-patch-from-stdin
				Apply a JSON array of {"old","new","replace_all"} patches to
				the existing body. Mutually exclusive with --from-file.

			--magic-advance-close-state-and-unlock only, and only with
			TEAM_DATA_GIT_REMOTE set: after the unlock commit it pushes,
			then resyncs the board. A failure of either warns on stderr
			and still returns 0 -- the lock is released either way.

		--magic-advance-lock-status <team-member>
		--magic-grooming-lock-status <team-member>
		--magic-daily-lock-status <team-member>
		--magic-retro-lock-status <team-member>
			Read-only, returns 0 always -- including when free, so a caller
			can check before deciding to start. Prints `NO_LOCK` when free,
			or `ACTIVE:owner=...:state=...:recheck_date=...` when held --
			read from the lock note's own frontmatter. Takes no options;
			any further argument is rejected.

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
				Replace the whole note, frontmatter included, with this
				file's contents -- a field the file does not carry is gone
				from the note. `session-id` is the exception: it is carried
				forward, so a body-replacing write cannot orphan the lock.

			--edit-patch-from-stdin
				Apply a JSON array of {"old","new","replace_all"} patches to
				the existing body. Mutually exclusive with --from-file.
				Given neither, the existing body is preserved.

		--magic-advance-sleep-run
			Read-only, no arguments -- a fixed-duration pacing operation in
			routine-advance's operation group.

		--magic-heartbeat-board-item-trash <team-member> <board-state> <item-name> [--untrash]
			Relocates one terminal board-item out of the board entirely, for
			routine-heartbeat's own GC step. <team-member> is the calling
			member's own identity — recorded in the git-commit message once
			team-data is git-tracked, otherwise unused;
			<board-state> is the item's current real board state
			(backlog/pending/running/blocked/parked/processed/archived/
			retained); <item-name> is a bare filename. Thin wrapper.

			--untrash restores instead: on a store with no git, it moves
			trash/<item-name> back into board/<board-state>/, and refuses
			if the board already holds that name. On a git store a
			trashed item was deleted and committed, so --untrash fails
			(non-zero), changes nothing, and says so: a git store keeps
			trashed items only in its history, no tooling op restores
			from it, and the coordinator is the one to ask.

		--magic-heartbeat-spawn-proxy <team-member> [--from-stdin] [--from-file <path>] [--from-board <board-item-name> [--board-state <state>]...] [--from-vault <vault-item-name>] [--from-audit <audit-item-name>] [--session-thread:event-track|magic-team] [--session-name-or-comment <text>] [--wait]
			Heartbeat/advance spawn relay: executes a spawn prompt
			through DistroAgentsConsole.sh. Body source is stdin
			(default), --from-file, --from-board, --from-vault, or
			--from-audit (exactly one when used); empty body is
			rejected. A bare call with nothing piped in fails
			immediately with "empty spawn context" -- stdin is already
			at EOF for a non-interactive caller. Use --from-file where
			redirecting is awkward. Keep no secret in a spawn brief: the
			console puts it on the CLI's own command line, visible in
			`ps` on the host.

			A --from-board/--from-vault/--from-audit call reuses that
			item as its tracking document and prints `DISPATCH_DOC=
			reuse` with `TRACKING_ITEM=<name>`. A stdin/--from-file call
			creates a fresh `dispatch-*` board-item in board-running and
			prints `DISPATCH_DOC=create` with `DISPATCH_ITEM=<name>`: the
			verbatim prompt as its own "## Brief", `status:
			dispatch-started` in its frontmatter. On completion `status:`
			moves to `dispatch-succeeded`/`dispatch-failed`, a "## Result"
			section is appended, and the item moves to board-pending. No
			`RECEIPT_FILE` key is ever written on any path.

			The spawned session is handed its own coworking session's
			thread as `session_thread_ts`, separate from the event-track
			thread below.

			Default mode is async (`STATUS=started` + `PID`); `--wait`
			blocks for completion and returns non-zero on failure.
			Printed keys: `RECEIPT_ID`, `SESSION_ID`, `SESSION_THREAD`,
			`DISPATCH_DOC` and `TRACKING_ITEM`/`DISPATCH_ITEM` always;
			`STATUS` always, with `PID` (async) or `EXIT_CODE`+`LAUNCHED`
			(`--wait`); `OUTPUT_FILE` wherever a file is written (under
			`$MDAT_DATA_ROOT/audit/<YYYY-MM>/`). On `--wait`:
			`SETUP_STATUS=cli-not-configured` when this workspace selects
			no external CLI, `SETUP_STATUS=cli-not-authenticated` when
			the selected CLI is present but not signed in and no API key
			is configured, `SETUP_STATUS=console-stale` when the deployed
			console is too old to start or signal a spawn (refused before
			anything is spawned), and `TIMEOUT_SECONDS=<seconds>` when the
			wait bound fired. The wait is unbounded unless magic-team's
			`SPAWN_WAIT_TIMEOUT_SECONDS` sets one (0 = none). A harness
			leg is started with `--tier <value>` when magic-team's
			`SPAWN_HARNESS_TIER` holds one (`light`, `normal` or `heavy`);
			unset, no tier is passed.

			On `--wait`, `STATUS=succeeded` means the child exited 0,
			the wait bound did not fire, and a launch actually
			happened; anything else is `STATUS=failed`.
			`LAUNCHED=true|false` prints separately and is a `--wait`-
			only key, so a real failure and a silent no-launch are never
			confused.

			Every spawn also opens a tooling-maintained thread in
			event-track (when `SLACK_CHANNEL_EVENT_TRACK` and a bot
			token are set; otherwise skipped silently), closed with the
			result when the child exits. Nothing of this reaches
			stdout; a failed post never fails the spawn.

			Separately, every spawn belongs to a coworking session.
			Inheriting a session id from its parent joins that session
			with no new thread opened; otherwise one opens in
			magic-team, titled by `--session-name-or-comment` or the
			session id. `--session-thread:event-track` pins it to the
			agent-log thread instead and skips the magic-team post --
			used by the main loop's own solitary spawns.

			The brief ends with a "## Your session thread" section
			carrying `session_thread_ts: <channel>:<ts>` -- the value
			`--member-comms-slack-send-message` takes as its target and
			`--member-comms-slack-read` takes with `--thread`. If the
			opening post failed, it instead says so and asks the session
			to post its own thread.

		--magic-spawn-session (--routine <selector>|--routine-default) [--session-name-or-comment <text>] [<team-member>...]
			Starts a coworking session and spawns its initial members in
			one call. Task text comes from stdin. Exactly one of
			`--routine <selector>` | `--routine-default` is required --
			the selector is a full routine filename or part of one,
			resolved once so every member spawned here carries the same
			routine file; that spawn's own spawn-prepare-brief block is
			then automatic ahead of the task text.

			Given no `<team-member>...` positional names, the members
			spawned are read from the resolved routine's own `executors`
			frontmatter line, which must be a plain comma-separated list
			of real members. A value that is not one -- `magic-team`/`*`
			(any-member shorthand) or free prose -- names no spawnable
			roster and is refused, asking for explicit
			`<team-member>...` instead of guessing one.

			The first member spawned starts the session; every further
			one joins it by the session id the first spawn's own output
			reports. A routine's own `invitees` are never spawned here --
			the session's own executor invites them separately.

			Prints `SESSION_ID` (the id every further spawn into this
			session joins by), `ROUTINE` (the resolved routine's own
			filename) and `MEMBERS` (the spawned members, space-
			separated).

		--magic-heartbeat-state-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]
			Writes (creates or overwrites) routine-heartbeat's own state
			record. Takes no filename or path argument -- storage is
			the operation's own concern.
			Input source is exactly one of: stdin (default), `--from-file`, or
			`--edit-patch-from-stdin`. Empty content is rejected. If
			`--edit-patch-from-stdin` is used, stdin must be a JSON patch array
			for exact-literal replace operations.

		--magic-heartbeat-lock-acquire <team-member> <owner-label>
			Takes routine-heartbeat's lock before any other step. Prints
			`ACQUIRED` (rc 0) on a fresh take; `RECLAIMED_STALE:prev_owner=
			...:age=...s` (rc 0) when the previous holder went stale;
			`ACTIVE:owner=...:state=...:recheck_date=...` (rc 1) when
			another holder genuinely has it -- rc 1 means do not start.
			<owner-label> names the running process (e.g. "main-loop"), not
			a chat-session id. Takes no options; any further argument is rejected.

		--magic-heartbeat-lock-refresh <team-member>
			Re-asserts a held lock so a long run is not mistaken for a
			crashed one. Prints `REFRESHED` (rc 0), or `NO_LOCK_HELD` (rc 1)
			when nothing is held. Takes no options; any further argument is rejected.

		--magic-heartbeat-close-state-and-unlock <team-member>
			Releases the lock in routine closure, setting the note's
			`state: heartbeat-finished`. Prints `RELEASED` and returns 0
			always. Takes no options; any further argument is rejected.

		--magic-heartbeat-lock-status <team-member>
			Read-only, returns 0 always -- including when free, so a caller
			can check before deciding to start. Prints `NO_LOCK` when free,
			or `ACTIVE:owner=...:state=...:recheck_date=...` when held --
			read from the lock note's own frontmatter. Takes no options;
			any further argument is rejected.

		--magic-heartbeat-state-read <team-member>
			Reads back the whole record written by --magic-heartbeat-state-upsert,
			verbatim. Outputs `NO_STATE` if nothing is stored yet.
			Read-only.

		--owner-cleanup-purge
			Empties $MMDAPP/.local/.cleanup/ (the folder itself stays).
			Takes no arguments -- always targets this one fixed location;
			nothing to parameterize.

		--member-help <team-member>
			Read-only. Prints `<team-member>`'s own duty-related tooling
			help.

		--member-comms-slack-read <team-member> (<channel>:<ts> [--thread]|<channel>|<conversation-id>|magic-team|human-owner|event-track|event-alert [--oldest <ts>]) [--identity-bot]
			`<team-member>` is the member this read acts as: the acting
			member decides which conversation this call can see at all.

			Full detail for one specific message (default) or its whole
			thread (--thread) -- all meta-info, reactions, formatting,
			files/attachments, exactly as Slack's own API returns them.
			Always returns full raw JSON, never pretty-formatted. A `<ts>`
			naming a thread reply reads back that reply, same as a thread
			parent or a plain message.

			**A target with no `:<ts>` names a conversation, and reads that
			conversation's own messages** -- pretty-formatted, newest first,
			paged to the end. Use this form when the `<ts>` is itself the
			thing being looked for. `--oldest <epoch>[.<micros>]` puts a
			floor under how far back the paging walks; a busy channel needs
			one, since a conversation longer than the page cap is a hard
			failure rather than a truncated answer. `--thread` belongs to
			the `<channel>:<ts>` form only, and `--oldest` to the
			conversation form only.

			**This, not --member-comms-slack-search-messages, is what finds
			something posted moments ago** -- search reads Slack's own
			index, which lags posting; this read goes to the conversation
			itself and sees a message as soon as it is there.

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

		--member-comms-email-read <team-member> <uid> [--seen]
			`<team-member>` is the member this read acts as: the mailbox
			read is that member's own, with no fallback. A UID only
			means anything inside one mailbox, so the same `<uid>`
			under a different member names a different message, or none
			at all.

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

			--seen marks the message \Seen after a successful read, for
			the case where a caller reads and immediately concludes. It
			runs only once the read has succeeded -- a failed read
			leaves the message untouched.

		--member-comms-trello-read <team-member> <notification-id>
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

		--help-syntax
			Prints every operation's syntax line and exits, without the
			manual. A bare call prints the default syntax alone -- the
			entry points a reader starts from.

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
		DistroAgentsTools.fn.sh --member-inbox-note-upsert keeper-myx 2026-07-22-note-example.md <<'EOF'
		... note content ...
		EOF
		```

		# Same, via --from-file instead of stdin
		`DistroAgentsTools.fn.sh --member-inbox-note-upsert keeper-myx 2026-07-22-note-example.md --from-file /path/to/note.md`

		# Append one session transcript entry (one call = one entry block)
		`DistroAgentsTools.fn.sh --member-append-session-transcript magic-coordinator --speaker human-owner --timestamp 2026-07-26T12:34:56Z --message "Approved. Proceed." --transcript-name transcript-2026-07-26-example.md --workspace-root /path/to/workspace --create`

		# Read a transcript audit document by filename (no raw path argument)
		`DistroAgentsTools.fn.sh --member-audit-item-read magic-coordinator transcript-2026-07-26-example.md`

		# Read only a selected line range from the same audit document
		`DistroAgentsTools.fn.sh --member-audit-item-read magic-coordinator transcript-2026-07-26-example.md --start-line 10 --end-line 25`

		# Read from specific board state(s) only, with optional line range
		`DistroAgentsTools.fn.sh --member-board-item-read magic-coordinator task-example.md --board-state pending --board-state running --start-line 1 --end-line 40`

		# Track a workspace path for the human-owner
		`DistroAgentsTools.fn.sh --owner-workspace-upsert /Volumes/ws-2017/myx-work`

		# List every currently-tracked workspace path
		`DistroAgentsTools.fn.sh --owner-workspace-list`

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
		`DistroAgentsTools.fn.sh --owner-credential-store-self-test`
