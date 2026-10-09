📘 syntax: DistroAgentsTools.fn.sh --console-start [--override-workspace <path>] [--console DistroSourceConsole.sh|DistroDeployConsole.sh] [--ttl <seconds>]
📘 syntax: DistroAgentsTools.fn.sh --console-send <channel> [-- <command...>]
📘 syntax: DistroAgentsTools.fn.sh --console-stop <channel>
📘 syntax: DistroAgentsTools.fn.sh --console-list [--override-workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --agents-config-option <entity-id> <operation>
📘 syntax: DistroAgentsTools.fn.sh --members --backend <member-name> <operation>
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>:<ts>|<team-member>[:<ts>]> [--identity-bot] [--metadata <json>] [text...]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <target> [--identity-bot] [--reply-broadcast] [--address-to <who>]... --from-stdin [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>] [--metadata <json>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-send-message <team-member> <target> [--identity-bot] [--reply-broadcast] [--address-to <who>]... --from-file <path> [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>] [--metadata <json>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-send <team-member> <email@address>... -- <subject> -- <body...> [--format markdown|text] [--in-reply-to <message-id>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-send <team-member> <email@address>... -- <subject> -- --from-stdin [--format markdown|text] [--in-reply-to <message-id>]
📘 syntax: DistroAgentsTools.fn.sh --member-comms-email-send <team-member> <email@address>... -- <subject> -- --from-file <path> [--format markdown|text] [--in-reply-to <message-id>]
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
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-slack-read <team-member> (<channel>:<ts> [--thread]|<channel>|<conversation-id> [--oldest <ts>]) [--identity-bot]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-slack-send-message <team-member> <target> [--identity-bot] [--address-to <who>]... (<text...>|--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-slack-react <team-member> <channel>:<ts> <emoji-name> [--identity-bot]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-email-send <team-member> <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-email-mark-seen <team-member> <uid>
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
📘 syntax: DistroAgentsTools.fn.sh --member-comms-confluence-page-read <team-member> <page-id> [--format storage|atlas_doc_format] [--version <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-space-list <team-member> [--cursor <value>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-read <team-member> <page-id> [--format storage|atlas_doc_format]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-search <team-member> <cql> [--limit <n>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-comment-read <team-member> <page-id>
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-create <team-member> (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-update <team-member> <page-id> --version <n> --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-comment-add <team-member> <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-comms-confluence-page-delete <team-member> <page-id>
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-space-list <team-member> [--cursor <value>]
📘 syntax: DistroAgentsTools.fn.sh --client-comms-confluence-page-read <team-member> <page-id> [--format storage|atlas_doc_format] [--version <n>]
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
📘 syntax: DistroAgentsTools.fn.sh --member-git-repo-history [--since <YYYY-MM-DD>] [--until <YYYY-MM-DD>] [--limit <n>] <path>...
📘 syntax: DistroAgentsTools.fn.sh --librarian-list-team-files [<path>...]
📘 syntax: DistroAgentsTools.fn.sh --librarian-list-team-files-dates [<path>...]
📘 syntax: DistroAgentsTools.fn.sh --librarian-inbox-item-trash <team-member> <item-filename> --from-inbox:<member>
📘 syntax: DistroAgentsTools.fn.sh --librarian-inbox-to-processed <team-member> <item-filename> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-note-upsert <member> <item-filename> [--from-member <member>] [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-upsert-member-inquiry <member> <item-filename> [--from-member <member>] [--from-file <path>]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-reflection-upsert <member> <item-filename> [--from-member <member>] [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-append-session-transcript <team-member> [--speaker <speaker-name>] [--timestamp <ISO-UTC-date-time>] (--message <verbatim-text>|--from-stdin|--from-file <path>) [--transcript-name <transcript-file-name>] [--create]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-item-read <member> <item-filename> [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-item-trash <member> <item-filename>
📘 syntax: DistroAgentsTools.fn.sh --member-inbox-to-processed <team-member> <item-filename> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --member-audit-item-read <team-member> <document-name> [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --member-vault-item-read <team-member> <item-name> [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsTools.fn.sh --member-board-item-read <team-member> <item-name> [--board-state <state>]... [--start-line <N> --end-line <N>]
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
📘 syntax: DistroAgentsTools.fn.sh --install-workspace-integrations [--scope workspace|user-home] [--workspace <path>]
📘 syntax: DistroAgentsTools.fn.sh --make-workspace-integrations [--quiet]
📘 syntax: DistroAgentsTools.fn.sh --make-agents-indices
📘 syntax: DistroAgentsTools.fn.sh --make-harness-indices
📘 syntax: DistroAgentsTools.fn.sh --make-console-command [--quiet]
📘 syntax: DistroAgentsTools.fn.sh --make-console-script
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-backlog <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-pending <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-processed <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-parked <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-blocked <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-running <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-archived <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-to-retained <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-backlog <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-processed <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-pending <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-blocked <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-create-running <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
📘 syntax: DistroAgentsTools.fn.sh --magic-grooming-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-sweep-input-scan <team-member> [--comms-since-utime <v>|--comms-since-date-time <v>]
📘 syntax: DistroAgentsTools.fn.sh --magic-sweep-state-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-sweep-state-read <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-sweep-state-advance <team-member> <ts>
📘 syntax: DistroAgentsTools.fn.sh --magic-team-roster-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-team-roster-read <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-team-data-commit-pending <team-member> [--commit-message <message>] [--no-push]
📘 syntax: DistroAgentsTools.fn.sh --member-wait-for-input <team-member> [--wait-default|--wait-continue|--wait-close|--wait-add|--wait-drop --wait-session-id <session-id>] [--wait-source <kind>:<target>]... [--wait-timeout <seconds>] [--wait-poll-interval <seconds>] [--wait-since-utime <epoch>] [--wait-addressee <slack-user-id>] [--wait-include-own] [--wait-react-seen <ids>] [--wait-react-note <ids>] [--wait-react-done <ids>] [--wait-react-wait <ids>]
📘 syntax: DistroAgentsTools.fn.sh --member-wait-for-input <team-member> --wait-list-sources
📘 syntax: DistroAgentsTools.fn.sh --member-escalation-read <team-member> <request-id>
📘 syntax: DistroAgentsTools.fn.sh --member-escalation-answer <team-member> <request-id> <verdict> [text]
📘 syntax: DistroAgentsTools.fn.sh --magic-escalation-answer <magic-coordinator> <request-id> <verdict> [text]
📘 syntax: DistroAgentsTools.fn.sh --member-escalation-readback <team-member> <request-id> <option word> [text]
📘 syntax: DistroAgentsTools.fn.sh --magic-escalation-forward <coordinator> <request-id>
📘 syntax: DistroAgentsTools.fn.sh --member-permission-pass <team-member> --to <member> --tool <tool> --target <target> --kind once|session|task [--task <item>] [--session-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-permission-set-request <magic-coordinator> <item> --entry <tool:target>... [--scope task|session] [--session-id <id>] [--participant <member>]...
📘 syntax: DistroAgentsTools.fn.sh --magic-permission-list --member <member> [--session-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --member-permission-list <team-member> [--session-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-permission-revoke <ref> [--session-id <id>]
📘 syntax: DistroAgentsTools.fn.sh --magic-permission-escalation-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --member-pending-reply-read <team-member> [<pending-id>] [--all] [--any-owner]
📘 syntax: DistroAgentsTools.fn.sh --member-pending-reply-settle <team-member> <pending-id> --reason <text> [--withdraw]
📘 syntax: DistroAgentsTools.fn.sh --magic-pending-reply-settle <magic-coordinator> <pending-id> --reason <text> [--withdraw]
📘 syntax: DistroAgentsTools.fn.sh --magic-pending-reply-amend <magic-coordinator> <pending-id> --verdict <text> --reason <text>
📘 syntax: DistroAgentsTools.fn.sh --member-decision-record <team-member> <item-filename> --kind <clarification|resolved|dismissed> --text <one line> [--source <ts-or-id>] [--clears-blocker]
📘 syntax: DistroAgentsTools.fn.sh --member-review-request <team-member> <item-filename> --reason <text>
📘 syntax: DistroAgentsTools.fn.sh --member-review-accept <team-member> <item-filename> [--summary <text>]
📘 syntax: DistroAgentsTools.fn.sh --member-review-return <team-member> <item-filename> (--message <text>|--from-stdin)
📘 syntax: DistroAgentsTools.fn.sh --member-review-reject <team-member> <item-filename> (--message <text>|--from-stdin)
📘 syntax: DistroAgentsTools.fn.sh --member-review-follow-up <team-member> <item-filename> <new-item-name> --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --magic-review-shutdown <magic-coordinator>
📘 syntax: DistroAgentsTools.fn.sh --magic-review-accept <magic-coordinator> <item-filename> [--summary <text>]
📘 syntax: DistroAgentsTools.fn.sh --magic-review-return <magic-coordinator> <item-filename> (--message <text>|--from-stdin)
📘 syntax: DistroAgentsTools.fn.sh --magic-review-reject <magic-coordinator> <item-filename> (--message <text>|--from-stdin)
📘 syntax: DistroAgentsTools.fn.sh --magic-review-follow-up <magic-coordinator> <item-filename> <new-item-name> --from-stdin
📘 syntax: DistroAgentsTools.fn.sh --member-work-session-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --routine-coworking-session-input-scan <team-member> <tracking-document>...
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-config-check
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-morning-review-input-scan <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-morning-review-state-advance <team-member> <ts>
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-to-running <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-advance-to-parked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-pending <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-blocked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-backlog <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-parked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-to-processed <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsTools.fn.sh --magic-append-session-transcript <team-member> <session-id> [--speaker <speaker-name>] [--timestamp <ISO-UTC-date-time>] (--message <verbatim-text>|--from-stdin|--from-file <path>) [--create]
📘 syntax: DistroAgentsTools.fn.sh --magic-board-create-running <team-member> <item-filename> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
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
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-test-report-send <team-member>
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-board-item-trash <team-member> <board-state> <item-name> [--untrash]
📘 syntax: DistroAgentsTools.fn.sh --magic-heartbeat-spawn-proxy <team-member> [--from-stdin] [--from-file <path>] [--from-board <board-item-name> [--board-state <state>]...] [--from-vault <vault-item-name>] [--from-audit <audit-item-name>] [--session-thread:event-track|magic-team] [--wait]
📘 syntax: DistroAgentsTools.fn.sh --magic-spawn-session (--routine <selector>|--routine-default) [--session-name-or-comment <text>] [<team-member>...]
📘 syntax: DistroAgentsTools.fn.sh --owner-cleanup-purge
📘 syntax: DistroAgentsTools.fn.sh --member-help <team-member>
📘 syntax: DistroAgentsTools.fn.sh --help-setup-<domain>
📘 syntax: DistroAgentsTools.fn.sh [--help-syntax]
📘 syntax: DistroAgentsTools.fn.sh [--help]

**IMPORTANT -- for `mcp__myx_distro__execute` and team-harness `Bash` callers:** call every operation as the bare `DistroAgentsTools <op> [args...]` function form -- never `DistroAgentsTools.fn.sh <op> [args...]`. Those execution contexts already have `DistroAgentsTools` defined as a shell function before your command runs (except a harness `Bash` command run under a timeout); every other context (a console session, a plain shell) still needs the full `.fn.sh` invocation shown throughout the rest of this file.

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
			Starts (or reuses, for an already-alive channel on the
			same workspace+console) a Keep-Alive console session.
			Prints CHANNEL/CHANNEL_DIR/FIFO/LOG/CONSOLE/WORKSPACE/
			HOLDER_PID/CONSOLE_PID to stdout. A channel dir that
			exists with no live processes is wiped and recreated.

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

		--members --backend <member-name> <operation>
			Synonym for --agents-config-option <member-name> <operation>
			[args...], same <operation> set. There is no
			--member-config-option: a scope holds credentials, so settings
			are the tooling's and the console's, never a member op.

		--member-comms-slack-send-message <team-member> <target> [--identity-bot] [--reply-broadcast] [--address-to <who>]... (text...|--from-stdin|--from-file <path>) [--format markdown|blocks] [--message-text <text>|--message-text-from-file <path>] [--metadata <json>] [--text-group report|brief|relay]
			Posts <text> to magic-team, human-owner, event-track,
			event-alert, a <channel>:<ts> thread, a bare
			conversation id, or a team member name, attributed to
			<team-member>. Target is read in that order, and
			anything else is refused. Content is
			exactly one of: trailing text args, --from-stdin, or
			--from-file <path>. A team member name, with or without
			:<ts>, is that member's own Slack DM. A member with no
			Slack account is refused with NO-SLACK-DM and nothing
			is sent (unrun: read from the code, not from a run).

			--identity-bot posts as the team bot; default is the
			member's own identity if configured, else the bot -- a
			send to human-owner always uses a user identity. Refused
			if neither token is configured. <team-member> must be a
			real member directory or the send is refused; a
			routine-* name sends as the bot and skips that check.
			A client-* member posting from its own token into its
			own workspace presents under the first name, family
			name and alias of its row in team-members-names
			(--make-agents-indices), which is the persona's, and
			never as its own identifier;
			the send is refused when that row lacks one of them. A
			sender or addressee reads its mark and alias from the
			same registry. An addressee with no row reads as its plain
			name, and only a member directory that does not exist is
			refused.

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

			A markdown body (not blocks) is checked against the
			team's plain-language floor first: refused, nothing
			sent, for a sentence over 25 words, a semicolon, or a
			listless paragraph over 150 words -- the error names the
			finding and the sentence. Any other finding goes to
			stderr and the send still goes through. Code
			fences/spans and `>` quoted lines are exempt.
			--text-group report|brief|relay narrows what's measured
			(ignored for blocks): report/brief drop the paragraph
			check, relay skips measurement; refused if the value is
			unknown or the post is under the shared bot account.

			--reply-broadcast also surfaces a threaded reply in the
			channel; no effect on a top-level post. Default metadata
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
			mentioned.

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

			**Hazard**: a send Slack itself refuses, or an
			unreachable/archived conversation, is not retried and
			raises no stuck-comms alert -- only a send that exhausts
			its transport retries does.

		--magic-contact-digest-send <team-member> <origin team-member> (--resolved|--needs-ruling) <text...>
		--member-contact-digest-send <team-member> (--resolved|--needs-ruling) <text...>
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

		--member-comms-email-send <team-member> <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>) [--format markdown|text] [--in-reply-to <message-id>] [--text-group report|brief|relay]
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

			**The team's plain-language floor can refuse the
			send** -- subject and body are each measured; refused,
			nothing sent, for a sentence over 25 words, a
			semicolon, or a paragraph over 150 words with no list.
			The error names the finding and the sentence. Any
			other finding goes to stderr only. Code fences/spans
			and `>` quoted lines aren't measured.

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

		--member-comms-slack-search-messages <team-member> <magic-team|human-owner|event-track|event-alert|<conversation-id>|<channel>> (--comms-since-date-time <v>|--comms-since-utime <v>) [--max-pages <n>] [--raw]
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
			instead. No free-text query form; the target is the
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
			line per message as `ts | user | text`, threaded
			messages tagged ` [thread-reply of <parent-ts>]`
			(feed that ts to --member-comms-slack-read ...
			--thread). Line breaks flatten to spaces. --raw
			returns the full API responses per page. A `##`
			summary line gives match/thread-reply counts, pages
			read, and the cut-off.

			**Hazard: Slack's own index lags live posting by
			about five minutes, no known upper bound** -- a
			just-posted message may be missing. For anything
			recent, read the conversation directly instead. A
			bot-posted message is sometimes reported missing
			elsewhere, and a zero-match result on a known-busy
			conversation is worth a direct-read check.

		--magic-comms-slack-resolve-ids <team-member> [--user-name <name>]... [--channel-name <name>]... [--human-owner-hint <name>] [--raw]
			General coordinator comms-id resolver. Authenticates as
			one team-member identity (same credential resolution as
			--member-comms-slack-send-message), then reports: auth
			identity (`AUTH_USER_ID`, `AUTH_USER_NAME`); requested
			user-name/channel-name matches with resolved IDs;
			configured alias reachability for magic-team/human-owner/
			event-track/event-alert; and the best-known reachable
			human-owner target.

			Human-owner resolution order: the configured `human-owner`
			alias id first, then (if unreachable) a DM-open attempt
			using --human-owner-hint (default `myx`) against the
			workspace's user list.

			--user-name/--channel-name repeat to resolve several names
			in one pass. --raw includes the full API payloads.

			Exit code: 0 a reachable human-owner target is confirmed,
			1 unresolved/unreachable.

		--magic-comms-slack-conversations-roster <team-member> [--identity user|bot|both] [--types <csv>]
			Read-only: which conversations exist for that member
			RIGHT NOW, per identity, asked of Slack fresh every call
			-- `conversations.list` paged to exhaustion, joined with
			`users.list` for a handle per row.

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

		--magic-comms-slack-read <team-member> (<channel>:<ts> [--thread]|<channel>|<conversation-id> [--oldest <ts>]) [--identity-bot]
		--magic-comms-slack-send-message <team-member> <target> [--identity-bot] [--address-to <who>]... (<text...>|--from-stdin|--from-file <path>)
		--magic-comms-slack-react <team-member> <channel>:<ts> <emoji-name> [--identity-bot]
		--magic-comms-email-send <team-member> <email@address>... -- <subject> -- (<body...>|--from-stdin|--from-file <path>)
		--magic-comms-email-mark-seen <team-member> <uid>
			The coordinator acting as <team-member>, under that member's
			own credentials: a client-* member's own sources, handled as
			that member in the communication sweep. Each takes every
			argument and option of the --member-comms-* operation of the
			same name and does what it does. Only magic-coordinator, or
			the console, may call them: a --member-comms-* call from a
			spawned session acts only as that session's own member.

		--member-comms-slack-react <team-member> <channel>:<ts> <emoji-name> [--identity-bot]
			<team-member> is the acting identity -- a bare, existing
			member directory (routine-* exempt). Identity rule for
			this whole family: member's own user token when it has
			one, else the team bot, --identity-bot to force the bot.

			Posts one reaction to a specific message --
			`<channel>:<ts>` only, no magic-team/human-owner
			shortcut. `<emoji-name>` has no colons (Slack's own
			`name` field, e.g. `white_check_mark`). A direct
			conversation belongs to one identity, so --identity-bot
			also decides which conversation the reaction can reach;
			channels are unaffected.

			Three distinct outcomes. **Added**: posted by this call,
			raw response printed, returns 0. **Already present**: the
			identity had already added that emoji -- its own outcome
			with a `#` note, returns 0, never an error. **Could not
			react**: anything else, Slack's error included, returns 1
			-- nothing is known about existing reactions. "Already
			present" speaks only for the acting identity; the same
			reaction under another identity is a normal, separate
			result.

		--member-comms-slack-delete-message <team-member> <channel>:<ts> [<channel>:<ts>...] [--identity-bot]
			Same identity rule as --member-comms-slack-react; here it
			also decides whether the call can succeed (see the
			authorship rule below).

			Deletes one specific Slack message -- `<channel>:<ts>`
			only, no channel-wide or "delete all" form; same
			credential resolution as --member-comms-slack-send-message,
			--identity-bot acts as the team bot.

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

		--member-comms-slack-edit-message <team-member> <channel>:<ts> [--identity-bot] [text...|--from-stdin|--from-file <path>] [--text-group report|brief|relay]
			Same identity rule as --member-comms-slack-react; as on
			--member-comms-slack-delete-message it decides whether
			the call can succeed -- Slack permits editing only what
			that identity authored.

			Replaces the text of one message -- same `<channel>:<ts>`
			grammar as --member-comms-slack-delete-message. Text
			comes from the same three forms as
			--member-comms-slack-send-message (trailing argv,
			--from-stdin, --from-file; --message-from-stdin aliases
			--from-stdin); no --format, plain text only. Empty
			replacement text is refused. Re-running the same edit is
			safe.

			**Measured against the same plain-language floor as
			--member-comms-slack-send-message, same --text-group
			values.** A refused edit changes nothing, naming each
			finding and sentence.

			**Slack permits editing only a message the acting
			identity itself authored** -- an authorship refusal names
			the identity, with Slack's raw error alongside; the other
			identity is never retried automatically. Prints the raw
			API response, returns 0 on `ok:true`; any refusal or
			failure returns 1, message unchanged.

		--member-comms-slack-file-info <team-member> <file-id> [--identity-bot] [--raw]
			<team-member> is the acting identity and decides whether
			the file is visible at all (see exit code 3). Bare member
			name (routine-* exempt); member's own user token when it
			has one, else the team bot; --identity-bot forces the
			bot.

			Reports metadata of one Slack file (files.info) to decide
			whether it's worth retrieving. <file-id> is `F` +
			uppercase letters/digits, from a message's own file
			object `id` -- a permalink, filename or <channel>:<ts> is
			refused before any call.

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

		--member-comms-slack-file-fetch <team-member> <file-id> <destination-path> [--identity-bot] [--overwrite]
			<team-member> is the acting identity for both the
			metadata read and the byte fetch -- never split across
			identities. Same identity resolution and <file-id>
			validation as --member-comms-slack-file-info.

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

		--member-comms-slack-file-share <team-member> <target> --from-file <path> [--snippet-type <v>] [--title <v>] [--comment <text>] [--identity-bot]
		--member-comms-slack-file-share <team-member> <target> --from-stdin [--snippet-type <v>] [--title <v>] [--comment <text>] [--identity-bot]
			Shares a file into a conversation, attributed to
			`<team-member>`, for content too big for a message
			body.

			`<target>` takes the same forms as
			--member-comms-slack-send-message; a target resolving
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

		--member-comms-google-sheet-write <team-member> <sheet-id> <a1-range> [--append] [--user-entered] (--from-stdin|--from-file <path>)
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

		--member-comms-confluence-page-read <team-member> <page-id> [--format storage|atlas_doc_format] [--version <n>]
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

		--magic-comms-confluence-comment-add <team-member> <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
			Runs only as `magic-coordinator`; any other name is refused
			with 1. The comment is posted under that identity.

			Body is always Confluence's storage format -- no ADF path
			here. `--parent-comment-id` makes it a threaded reply; a
			parent on another page refuses the reply with 1. No version
			gate.

		--magic-comms-confluence-page-delete <team-member> <page-id>
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

		--client-comms-confluence-space-list <team-member> [--cursor <value>]
			Runs only as a `client-*` member, under that member's own
			credential, against that external organisation's own
			Confluence; any other name is refused. Output, paging and
			completeness reporting are as
			`--member-comms-confluence-space-list` describes.

		--client-comms-confluence-page-read <team-member> <page-id> [--format storage|atlas_doc_format] [--version <n>]
			Runs only as a `client-*` member, under that member's own
			credential; any other name is refused with 1. Everything
			else, `--version` included, is as
			`--member-comms-confluence-page-read` describes.

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

			**Before this write runs, the current page is read and saved
			byte-for-byte to the team's audit store.** A save that fails
			refuses the write, naming the snapshot as the reason. A write
			that runs prints the saved snapshot's id; a snapshot never
			carries a credential or secret.

			**The approval ask for this write shows the full resulting
			page, or a diff against the current one.** The tooling does
			not compose that ask -- the acting `client-*` member is
			responsible for showing it.

		--client-comms-confluence-comment-add <team-member> <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-confluence-comment-add` describes.

		--client-comms-confluence-page-delete <team-member> <page-id>
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-confluence-page-delete` describes.

			Same snapshot-before-write and approval-diff rule as
			`--client-comms-confluence-page-update`.

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

		--magic-comms-jira-issue-update <team-member> <issue-key> [--fields-json <json>] [--update-json <json>] [--notify-users]
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

		--magic-comms-jira-issue-transition <team-member> <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>|--comment-adf-from-stdin|--comment-adf-from-file <path>]
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

			**Before this write runs, the current issue is read and saved
			byte-for-byte to the team's audit store.** A save that fails
			refuses the write, naming the snapshot as the reason. A write
			that runs prints the saved snapshot's id; a snapshot never
			carries a credential or secret.

			**The approval ask for this write shows the full resulting
			issue, or a diff against the current one.** The tooling does
			not compose that ask -- the acting `client-*` member is
			responsible for showing it.

		--client-comms-jira-issue-transition <team-member> <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>|--comment-adf-from-stdin|--comment-adf-from-file <path>]
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-issue-transition` describes.

			Same snapshot-before-write and approval-diff rule as
			`--client-comms-jira-issue-update` -- `--fields-json` here can
			overwrite a field too, the same loss `--client-comms-jira-issue-update`
			guards against.

		--client-comms-jira-comment-add <team-member> <issue-key> (--body-adf <json>|--body-adf-from-stdin|--body-adf-from-file <path>)
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-comment-add` describes.

		--client-comms-jira-issue-delete <team-member> <issue-key>
			Runs only as a `client-*` member, writing under that member's
			own credential; any other name is refused with 1. Everything
			else is as `--magic-comms-jira-issue-delete` describes.

			Same snapshot-before-write and approval-diff rule as
			`--client-comms-jira-issue-update`.

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

		--librarian-inbox-item-trash <team-member> <item-filename> --from-inbox:<member>
			Discards one of `<member>`'s inbox items -- live or already
			processed. Searched in order: the inbox root, then its legacy
			`processed/` (items drained before the in-place marker, until
			the GC empties it); first match wins, so a basename in both
			leaves the legacy copy untouched -- root-first, so the copy
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
			Marks one item in `<team-member>`'s own inbox root
			processed, IN PLACE: stamps `processed-at` into its
			frontmatter (creating the block when the item has none)
			and commits it. The item stays where it is; active inbox
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
			An item in the legacy `processed/` folder is already
			processed: a plain re-mark succeeds as a no-op, an edit is
			refused (that folder is read-only).

		--member-inbox-to-processed <team-member> <item-filename> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Marks one of `<team-member>`'s OWN inbox items handled:
			`processed-at` stamped in place, exactly as
			`--librarian-inbox-to-processed` (a given processed-at wins,
			a re-mark is a no-op, the original stamp is kept). Any
			member may call it for its own inbox:
			`<team-member>` is both the actor and the inbox, must be a
			real member skill directory, and a spawned session acting
			as another member is refused. `<item-filename>` is a bare
			name ending `.md`. `--header:*` and the three body-input
			modes behave as on the `--magic-board-to-*` family.

		--member-inbox-note-upsert <member> <item-filename> [--from-member <member>] [--from-file <path>|--edit-patch-from-stdin]
			Writes (creates or overwrites) a note into `<member>`'s own
			inbox. Own inbox only: a spawned session naming another
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

		--member-upsert-member-inquiry <member> <item-filename> [--from-member <member>] [--from-file <path>]
			Passes an inquiry into a member's own inbox -- the standard
			hand-off mechanism. `<member>` must exist as a real skill
			directory; `<item-filename>` a bare filename. Inbox created
			lazily if missing. Content via stdin by default, or
			`--from-file <path>`. A new item's required
			`type`/`from`/`date`/`owner` headers are completed as in
			`--member-inbox-note-upsert`. From a spawned session,
			`--from-member` names only that session's own member, and an
			item already in the inbox is overwritten only when its
			`from:` is the caller; a new item is always written.

		--member-inbox-reflection-upsert <member> <item-filename> [--from-member <member>] [--from-file <path>|--edit-patch-from-stdin]
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

		--member-append-session-transcript <team-member> [--speaker <speaker-name>] [--timestamp <ISO-UTC-date-time>] (--message <verbatim-text>|--from-stdin|--from-file <path>) [--transcript-name <transcript-file-name>] [--create]
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

		--member-inbox-item-read <member> <item-filename> [--start-line <N> --end-line <N>]
			Read-only read of one item in `<member>`'s own inbox, by bare
			`<item-filename>`. Searches the inbox root first (marked or
			not), then its legacy `processed/`, first match wins.
			`<item-filename>` must carry one of the four type prefixes:
			`note-`/`inquiry-`/`reflection-`/`warning-`. `--start-line`/`--end-line` must be
			given as a complete pair.

		--member-inbox-item-trash <member> <item-filename>
			Discards one item out of `<member>`'s OWN inbox. No
			`--from-inbox:<member>` here -- one supplied in any position
			is REFUSED, so a member-scoped call can never become a
			cross-member one (use `--librarian-inbox-item-trash` for
			another member's inbox). A spawned session naming another
			member than itself is refused. Resolution as
			`--member-inbox-item-read`: root then legacy `processed/`,
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

		--owner-workspace-upsert <path> [--name <name>] [--kind workspace|directory] [--ceiling read-only|read-write]
			Registers a place no project declares, in this workspace's
			own registry (.local/agents/directories.registry), with a
			pointer in $HOME/.agents/magic-team/directories.registry.
			<path> must be absolute; a trailing slash is dropped.
			--name defaults to the path's basename; --kind defaults to
			workspace, which is always read-write; --ceiling defaults to
			read-write. Registering a place grants nothing. The same row
			again is a no-op; a name a project of this workspace
			declares for another path is refused. Existence of <path> is
			not checked (it may live on an unmounted volume).
			Places a project declares need no call: a project.inf
			Declares line `magic-team:directory:<name>:<ceiling-read|ceiling-write>:<path>:<host-glob>`
			or `magic-team:workspace:<name>:<path>:<host-glob>` registers
			one on every update, its path absolute, `~/...`, or relative
			to the workspace.

		--owner-workspace-forget <name>
			Removes the place of that name that --owner-workspace-upsert
			registered in this workspace. A name a project declares, or
			this workspace's own, is refused; an unknown name is a
			harmless no-op.

		--owner-workspace-list
			Prints every registered place of every workspace, one per
			line, TAB-separated: name, kind (workspace or directory),
			ceiling (read-only or read-write), path, and present, absent
			(not on this host) or unknown (its workspace cannot be read).
			The same name with another path: this workspace's keeps the
			name, each other is written <name>@<workspace>; with none
			here, one warning, and each is written <name>@<workspace>.
			Takes no arguments; prints nothing when no place is
			registered yet.

		--member-directory-list
			Prints every registered place, one per line, TAB-separated:
			name (or <name>@<workspace>, as --owner-workspace-list
			writes it), kind (workspace or directory) and ceiling
			(read-only or read-write). Never a path: ask for one by name
			with --member-directory-path. Takes no arguments.

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
			says so.

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
			  that isn't a clone of a set remote is left alone,
			  with a warning. A repository with no author identity
			  fails its check, naming both keys.

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
			--install-workspace-restrictions (only where restrictions
			were installed, that is where
			.claude/hooks/deny-native-tool-reroute.sh exists), then
			--make-harness-indices, against $MMDAPP. A step
			that fails ends the run; later steps don't run. `--quiet`
			suppresses the usage guidance normally printed.

		--make-harness-indices
			Writes the universal harness's own indexes in
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
			loop rebuilds them. Takes no arguments.

		--make-agents-indices
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
			`project:<selector>`;
			`allow-write` an `Edit(...)` row, `allow-read` a `Read(...)`
			row, `allow-tool` a `<tool>[:<target>]` row. A name no
			place carries is an `unresolved` row, with a warning. Every
			acting member's own directory, and magic-librarian's read
			of `source/**`. A scan that cannot be trusted keeps the
			registry as it stood. Then `grants.index`: every member's
			rows of every workspace's registry, fully unrolled (`*` one
			row per member), the workspace floor, and the places'
			ceilings -- what every permission check reads. A reader
			finding it stale or missing rebuilds it.

			Takes no arguments, prints nothing on stdout, notes each
			file on stderr, and fails only when a file cannot be
			written. Run by the install and by the source-prepare build.

		--make-console-command [--quiet]
			Re-creates `DistroAgentsConsole.sh`, the command to quickly
			enter the workspace console. `--quiet` suppresses the usage
			guidance normally printed.

		--make-console-script
			Prints the agents console script body (used by
			`--make-console-command`) and exits.

		--magic-grooming-to-backlog <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
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

		--magic-grooming-to-pending <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/pending/ -- the Advancement-review case (backlog ->
			pending), e.g. `--header:upsert:approved-by:"<team-member>
			(<session-id>, <date-time>)" --header:upsert:approved-at:
			<date>`. `approved-by`'s value is validated: must match
			`<team-member> (<session-id>, <date-time>)` with an ISO UTC
			date-time (suffix `Z`).

		--magic-grooming-to-processed <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/processed/.

		--magic-grooming-to-parked <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/parked/ -- a deliberate deferral by the team's own
			choice (distinct from board/blocked/, a stall on something
			external). `recheck-date` and `condition` are caller-
			supplied via `--header:*` -- triage judgments this op cannot
			compute.

		--magic-grooming-to-blocked <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/blocked/ -- stalled on something external (distinct
			from board/parked/, a deliberate stop). Stamps `owner`/
			`groomed-at`/`groomed-from`/`track`, which is what
			distinguishes this from `--magic-board-to-blocked`: same
			target state, but that one stamps nothing. `recheck-date`
			and `condition` are caller-supplied via `--header:*`.

		--magic-grooming-to-running <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/running/. Distinct from `--magic-advance-to-running`,
			which targets the same state under a different owning
			routine and different recorded provenance -- this one
			stamps `owner`/`groomed-at`/`groomed-from`/`track`.
			`started-at` is also stamped, as on every move or create
			into board/running/ -- pass
			`--header:upsert:started-at:<date-time>` to override it.

		--magic-grooming-to-archived <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/archived/ -- a Drop outcome, or a re-check step
			concluding a parked trigger is never coming or a blocked
			item isn't worth waiting on. Still stamps `owner`/`groomed-
			at`/`groomed-from`/`track` despite the target being terminal
			-- who archived an item, and from where, is exactly what a
			later reader needs. The archived reason text is caller-
			supplied via `--header:*` or the body-input modes.

		--magic-grooming-to-retained <team-member> <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			Same shape as `--magic-grooming-to-backlog`, target fixed to
			board/retained/ -- but a SAME-STATE PATCH, not a move: call
			with `--from-state:retained` so source and target match and
			nothing relocates; the existing body is read-and-preserved
			rather than replaced. The renewed `recheck-date` is caller-
			supplied via `--header:*`. The usual grooming stamps apply;
			on a same-state call, `groomed-from` records `retained`,
			meaning groomed while sitting there, not arrived from
			elsewhere.

		--magic-grooming-create-backlog <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
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

		--magic-grooming-create-processed <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
			As `--magic-grooming-create-backlog`, target board/processed/
			-- a promoted-or-denied item landing with its resolution
			text attached.

		--magic-grooming-create-pending <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
			As `--magic-grooming-create-backlog`, target board/pending/
			-- a promotion where the group's own context already
			warrants approval at creation.

		--magic-grooming-create-blocked <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
			As `--magic-grooming-create-backlog`, target board/blocked/
			-- a promotion that needs human-owner approval, so the item
			lands blocked.

		--magic-grooming-create-running <team-member> <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
			As `--magic-grooming-create-backlog`, target board/running/
			-- the approval-* item the human-owner approval negotiation
			runs in.

		--magic-grooming-input-scan <team-member>
			Read-only: lists board items as `<state>/<item-filename>`,
			one per line, with every frontmatter field. Always scans
			backlog/pending/running/review/blocked/parked. Use this to find
			an item's actual current state before calling
			`--magic-grooming-to-*`. Also returns routine-grooming's
			own state-and-lock note content ahead of the board rows
			(content only, absent reported as nothing to report, not
			an error), and the team roster cache as its own section
			(same terms) -- no need to call `--magic-team-roster-read`
			separately. `<team-member>` is the only argument.

			Inbox scope is `<team-member>`'s own inbox plus every
			`client-*` member, each in its own "Additional Inbox --
			<member>" group. Widening the read is all it does: the
			acting identity stays `<team-member>`, no client
			credential or comms source is read, nothing is written
			into a client inbox.

		--magic-sweep-input-scan <team-member> [--comms-since-utime <v>|--comms-since-date-time <v>]
			Read-only combined check: backlog/pending/running/review/
			blocked board items (not parked), the calling member's own
			watched sources, and every client-* member's own
			sources, each under that member's own credentials.
			Returns only items whose channel id is the
			three-field `slack:<channel>:<ts>` form -- a live,
			reply-pending thread; a bare `slack:<channel>` or
			non-slack service is not one. An empty result is
			normal, not an error. No --state/--header override.

			One document covers everyone swept. Each client
			member's own block matches
			--client-sweep-input-scan's own output (its `#
			Incoming Communications Sweep -- <member>` heading,
			`member:`/`member-kind:` lines); a client with no
			coverage still gets a `no scan was made` block --
			never silently missing.

			Every member resumes from its OWN cut-off. With none
			stated, the team part resumes from the calling
			member's own stored `last_swept_ts`
			(--magic-sweep-state-read), and each client member's
			part from that client's own; the scan's default window
			applies only to a member with no position stored. A
			stated --comms-since-utime or --comms-since-date-time
			(mutually exclusive) applies to the team part only and
			is never forwarded to a client.

			Every `## slack-message` item block carries `author:` and
			`addressees:` right after `user:`, so no reader parses a
			message itself. Where the text opens with the team's own
			send header (`*_<from>_* @<alias> → <addressee>; ....`),
			`author:` is the member named there and `addressees:`
			the members, accounts or conversations it names, or
			`@here (unaddressed)`. Without that header, `author:` is
			the platform sender (as `user:`) and `addressees:` the
			accounts the text mentions, `@here (unaddressed)` for a
			channel-wide mention, or `(none stated)`.

			**Hazard: not a workspace-wide mention search** -- a
			conversation or mention outside the already-watched
			sources stays undiscoverable here.

			Exit code, the combined verdict over everyone swept --
			matched in the body by `sources-scanned: N of M` and
			`NOT SCANNED`/partial markers:
			0 every source scanned.
			3 some scanned, some not.
			4 none scanned.
			1 failed before producing a document.
			A client member's own failure counts as 4, never 1,
			once a document exists.

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
			yet. Read-only. There is one pointer per member, `last_swept_ts`;
			no per-source pointer is stored or read.

		--magic-sweep-state-advance <team-member> <ts>
			Moves that member's own `last_swept_ts` to <ts>, the newest
			message its pass actually processed. The rest of the record is
			kept, except stale `source-<key>-last-swept-ts:` entries, which
			are dropped (a missing record is created). Call it once per
			swept member at the end of every pass that processed a message.
			The same value is a no-op; an older one is REFUSED, as is a
			<ts> more than a minute in the future. Commits the record.

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
			commit (new/changed/deleted paths) and pushes it the way
			--intern-op-item-upsert does, with one retry on a network
			failure; every other team-data op commits only what it
			writes, this one catches the rest. <team-member> must be
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
			branch. A failed push prints `TEAM-DATA-NOT-PUSHED: the
			push failed; ...` and exits 1 with the commit kept
			locally. Refused: a store not in a git repository, or one
			showing an interrupted operation (index.lock,
			merge/cherry-pick/revert/rebase in progress) --
			`TEAM-DATA-REFUSED: the repository shows an interrupted
			operation: <which>`, exits 1, repairs nothing. Commits
			already ahead of origin go out with the push.

			**Hazard**: takes no lock -- run it only when no routine
			holds the advance or heartbeat lock, or a file another op
			is writing could be committed half-written.

		--client-sweep-input-scan <team-member> [--comms-since-utime <v>|--comms-since-date-time <v>]
			Read-only: one client-* member's own incoming external
			comms -- Slack, email, Trello -- read as that member,
			under its own credentials and configured sources. Use
			for one external relationship; use
			--magic-sweep-input-scan for the team's own.

			The member name is required and must be client-* (a
			partner-* is not accepted); the whole document is that
			one member's scope, each section stating our own side
			(`identity: slack <id> (config: <member>)`, same for
			email/Trello), board items limited to ones it owns.

			A source that couldn't be read is `sources-scanned: N
			of M` + `**NOTE:** partial`, and counts against the
			exit status -- never read under another member's or
			the team's credentials. An OPTIONAL source this member
			holds no credentials for (email, Trello) is different:
			never contacted, no `sources-scanned:` line, not
			counted, not partial -- its own `**NOTE:** no scan
			was made` names the unset keys. This is the only way
			an unconfigured source is told apart from an
			unreachable one.

			Slack sources come from this member's own
			`SLACK_CONVERSATIONS` config (ids or `<channel>:<ts>`,
			whitespace/comma-separated); none configured reports
			nothing scanned, no team-scoped fallback.

			A cut-off (--comms-since-utime or
			--comms-since-date-time, mutually exclusive) is
			optional. Given neither, the scan resumes from this
			member's OWN stored `last_swept_ts`
			(--magic-sweep-state-read <this member>), never the
			caller's; with none stored, the scan's default window
			applies. `resumed-from:` says which, and the cut-off
			actually used is in each section's own `instrument:`
			line.

			Exit code: 0 every source scanned, 3 some scanned and
			some not, 4 none scanned, 1 failed before producing a
			document.

		--member-wait-for-input <team-member> [--wait-default|--wait-continue|--wait-close|--wait-add|--wait-drop --wait-session-id <session-id>] [--wait-source <kind>:<target>]... [--wait-timeout <seconds>] [--wait-poll-interval <seconds>] [--wait-since-utime <epoch>] [--wait-addressee <slack-user-id>] [--wait-include-own] [--wait-react-seen <ids>] [--wait-react-note <ids>] [--wait-react-done <ids>] [--wait-react-wait <ids>]
		--member-wait-for-input <team-member> --wait-list-sources
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
			`slack:magic-team` and `slack:human-owner`.
			`slack:<conversation>` waits
			on a conversation; `slack:<channel>:<ts>` on that
			message's thread; `slack:<channel>:<ts>:conversation`
			on any new post in that thread not from this member;
			`file:<absolute-path>` on a local path (file or dir)
			-- an absent path is a state, not a failure;
			`inbox:<member>` on that member's own inbox, which
			must be the caller's own; `board:<state>` on one
			board state (backlog, pending, running, review,
			blocked, parked, processed, archived or retained);
			`ask:<pending-id>` on the answer to a question
			AskUserQuestion asked: its thread, floor and addressees
			come from its pending record, read as that question's
			own wait reads them, plus a `# pending reply <id> is
			closed: <status>` line once the record is no longer
			pending (a record-only escalation renders only that).
			Its record must exist, and with --wait-session-id it
			must be that session's own question, else ERROR. Its
			rendering holds arrivals only, so with no stored base
			an answer already there returns at once. Taking the
			answer into the record is the harness's, not this
			operation's. File, inbox and board carry no message ids. Another member's inbox
			or another state name is an ERROR at second zero.
			--wait-list-sources prints the source kinds this
			build carries and waits on nothing.

			--wait-timeout: bound in whole seconds; none by default,
			so the wait returns only when something arrives.
			--wait-poll-interval: whole seconds between probes,
			fixed when given (or MDAT_WAIT_POLL_SECONDS when set),
			minimum 1. Unset, it backs off: 5s, growing 15s per 5
			minutes waited, capped at 300s. Only affects how soon an
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
			session's wait and leaves it once answered.

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

		--member-escalation-read <team-member> <request-id>
			The verdict of one escalation: an AskUserQuestion of kind
			readback, decision or permission. <request-id> is the
			pending-reply id the question printed ("recorded as
			pending reply <id>"). Answered: prints
			`ESCALATION: <id> answered`, then `VERDICT:`,
			`VERDICT-TEXT:` (readback correction), `ANSWERED-BY:`,
			and for an allow, `GRANT:`. Not yet answered: read now
			from the question's own thread, then a forward's thread;
			an answer from an addressee there applies exactly as a
			waiting question applies it. With none:
			`ESCALATION: <id> open` + `VERDICT: UNCLASSIFIED`, with
			`VERDICT-REASON:` when an answer was seen and not taken.
			An answer from the account that asked is never taken. A
			question withdrawn by its asker prints `ESCALATION: <id>
			closed withdrawn` and takes no verdict.

			Only a reply's first line gives its verdict. A plain
			affirmation -- a first word ok, okay, yes, agree, agreed,
			confirm or confirmed, also after a leading "I", in any
			case, or a +1, ok_hand or white_check_mark reaction on the
			question -- is yes for a readback, and for a decision the
			option whose line holds `(recommended)`; with none marked
			it answers nothing. A permission takes only its own words.
			Once a verdict is applied, the rest of the reply it came
			from and every later reply there are kept as
			clarifications: under the record's `## Clarifications`,
			and as `clarification` lines on its item's `## Decisions`
			(`CLARIFIED <id> <n>`). A decision closed by its asker's
			readback also prints `CLOSED-BY: readback`.

			While a typed escalation waits, the first reply from an
			addressee ends the wait, judged against every reply since
			the question (the asker's own posts never count). A
			reply naming no valid answer returns
			`VERDICT: UNCLASSIFIED` to the asking agent with its
			reason and the reply text; the record stays open, nothing
			is posted automatically, and its `WAIT-ID:
			ask:<request-id>` stays in the session's stored wait, so
			the harness Wait (mode continue, or sources=
			ask:<request-id>) takes the next reply exactly as the
			question would. The result's last line is still the
			compatible re-wait call, `AskUserQuestion pending_id=
			<request-id>` -- posts nothing, waits on the same thread
			again, and only the session that asked may make it. An
			older record with no session id can be re-waited from any
			session, but for a permission it grants nothing there --
			the grant is keyed to the record's own session.

		--member-escalation-answer <team-member> <request-id> <verdict> [text]
			Answers one open escalation as <team-member>, which must be
			the member it was addressed to, or an executor of the
			routine it was addressed to (`<name>.routine`), and not the
			member who asked. This is how a member with no Slack
			account of its own, the coordinator included, answers, and
			how an ask to a routine is answered. The verdict must
			belong to the kind: yes, no or correct for a readback, the
			answering word of one option for a decision, deny,
			allow-once, allow-session or allow-task for a permission,
			and allow-set, deny or edit for a permission set. [text]
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
			answer to the same escalation is not applied. The answer is
			also said in the question's own thread. A spawned session
			answers only as its own member.

		--magic-escalation-answer <magic-coordinator> <request-id> <verdict> [text]
			The coordinator answers one open escalation on behalf of the
			member it was addressed to, whoever that is, as
			--member-escalation-answer does for the addressee: the same
			verdicts, session checks, grant and thread notice, signed by
			magic-coordinator. Never a question magic-coordinator asked.
			Only magic-coordinator, or the console, may call it.

		--member-escalation-readback <team-member> <request-id> <option word> [text]
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
			decision, never for a permission, for any member but the
			asker, with no reply yet, and when a reply already names an
			option. AskUserQuestion pending_id=<id> readback=<option
			word> calls it. A spawned session reads back only as its
			own member.

		--magic-escalation-forward <coordinator> <request-id>
			Forwards one open escalation addressed to <coordinator> to
			the human-owner, keeping the same record. The question is
			posted to the human-owner as the team bot. His reply or
			declared reaction in that thread is the verdict for the
			original request, and the waiting question ends on it.
			Only the member the escalation is addressed to can forward
			it, or an executor of the routine it is addressed to, and
			only while it is open.

		--member-permission-pass <team-member> --to <member> --tool <tool> --target <target> --kind once|session|task [--task <item>] [--session-id <id>]
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

		--magic-permission-set-request <magic-coordinator> <item> --entry <tool:target>... [--scope task|session] [--session-id <id>] [--participant <member>]...
			Asks for a task's or session's permission set at spawn or
			brief time. Prints `PARTICIPANTS:`, then `HELD: <entry> by
			<member> <layer>` for each entry a participant already
			holds -- those pass on when the holder delegates, never
			granted to the others -- and `EXTRA: <entry>` for the rest.
			With extras, ONE permission-set escalation is posted to the
			human-owner as the team bot, and `PERMISSION-SET: asked
			<id>` and `WAIT-ID: ask:<id>` are printed; with none,
			`PERMISSION-SET: held`. His allow-set grants every extra to
			every participant for the scope, writes a task set as the
			item's `allows:` too, and records the set on the item's
			`## Decisions`; the grants end when the task closes or the
			session ends. deny and edit grant nothing. --scope defaults
			to task; the session is the caller's own unless named.
			A target may name a registered place:
			`<tool>:@<name>[:<glob>]`, the glob a path, ** or <path>/**
			under it (default **), never with a .. segment; it is asked
			for as that path. A path in a place is said as `PLACE:
			<entry> is <name>:<relative>`, a hint recorded with the
			grant. A write in a read-only place is refused before
			anything is asked, naming the route to take instead.
			Only magic-coordinator, or the console, may call it.

		--magic-permission-list --member <member> [--session-id <id>]
		--member-permission-list <team-member> [--session-id <id>]
			Prints one member's effective grants, one per line,
			TAB-separated: kind (floor, standing, session, task or
			once), read, write or the tool, the target, its place as
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

		--magic-permission-escalation-input-scan <team-member>
			The input scan of
			magic-coordinator.permission-escalation.routine: the
			oldest 20 open permission asks addressed to
			`permission-escalation.routine`, in every workspace this
			machine knows. Opens with `shown: <n> of <total>, oldest
			first`, or `(none)`. Each ask is a `## permission ask
			<id>` block of `<field>: <value>` lines: workspace,
			asked-at, member (who asked), session, refusal, tool,
			target, place (the target as <name>:<relative>, or -),
			reason, task-ref, item, holders (<member> <layer>,
			<team-member> first when it holds it, the human-owner
			last) and set-requests (the open permission-set asks of
			the same item or session). It changes nothing. Only
			magic-coordinator, or the console, may call it.

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
			An open question is also reminded by the main loop itself
			(30 minutes, 2 hours, then daily after 09:00 once 4+ hours
			old), always by a reply in that question's own thread. The
			record keeps the stamps: reminder-30m, reminder-2h,
			last-daily-reminder, reminders and last-reminder-at. A
			reminder never closes a record.

		--member-pending-reply-settle <team-member> <pending-id> --reason <text> [--withdraw]
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
			in the question's own thread tells the person it is no
			longer needed. Prints `WITHDRAWN <id>`. AskUserQuestion
			pending_id=<id> withdraw=<reason> calls it.

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

		--member-decision-record <team-member> <item-filename> --kind <clarification|resolved|dismissed> --text <one line> [--source <ts-or-id>] [--clears-blocker]
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
			when an AskUserQuestion closes, on the item its pending
			record names in `item:` (task_ref, else the session's
			`spawns:` dispatch item); an AskUserQuestion that Decisions
			or an earlier closed ask of the same session already answer
			is not posted again, and returns that answer.

		--member-review-request <team-member> <item-filename> --reason <text>
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

		--member-review-accept <team-member> <item-filename> [--summary <text>]
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

		--member-review-return <team-member> <item-filename> (--message <text>|--from-stdin)
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

		--member-review-reject <team-member> <item-filename> (--message <text>|--from-stdin)
			The reject verdict on an item in review or running: moves it
			to pending with `status: review-rejected` and the corrections
			appended as a `## Review: rejected` section, sends DISMISSED to
			its live child (`REJECT-DISMISS: ...`), and records
			`verdict: rejected: <text>`, so a fresh spawn reads them. The
			fresh spawn itself is the normal spawn path.

		--member-review-follow-up <team-member> <item-filename> <new-item-name> --from-stdin
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

		--member-work-session-input-scan <team-member>
			Read-only: one member's own current work-session input --
			personal, not routine-dictated (every armed member runs this
			against its own name as it becomes armed, regardless of which
			routine triggered the arming). Returns that same member's own
			inbox first, as two sections: its reflections, then its notes
			(`## inbox/<item-filename>`, frontmatter and body; top-level
			items only, items marked `processed-at` excluded, at most 64
			each). A section with nothing in it, a not-yet-created inbox/
			included, prints a note saying so, not an error. Inquiries and
			other inbox items are not returned. Then its board items:
			pending/running/review/blocked, restricted to the items owned by
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
			what that routine's own steps consume. Opens with a
			`## day-rhythm (routine-heartbeat)` section of three lines:
			`branch: first-today|later-today|weekend` (weekend on a
			local Saturday or Sunday; otherwise first-today unless the
			note's `last-iteration-date` is today's local date),
			`today-stage: <value>` (the note's own, or `not-started`
			when its date is not today or it has none), and
			`grooming-today: finished|running|none` (finished: the
			grooming note says `grooming-finished` with today's
			`last-close-date`; running: its lock is held; none
			otherwise). Then routine-heartbeat's own state-and-lock note
			content (the same document --magic-heartbeat-state-read
			prints; a note that doesn't exist yet reports as nothing to
			report, not an error; content only, never evaluates the
			lock). No board item content and no inbox reflections.
			Then a `## questions (pending replies)`
			section shows the main loop's last collect of unanswered
			questions, then every question still open, from any member,
			with its session, asker and age. Then a `## spawned
			sessions` section: each spawn's recorded close status and
			exit code, and whether its process is alive now. Then a
			`## board counts` section: one `<state>: <n>` line per board
			state (backlog, pending, running, review, blocked, parked,
			processed, archived, retained), counted live at scan time
			from the `*.md` files directly in that state's folder --
			the counts a report needs, with no count of its own. Last,
			a `## board active items` section: one `<state>/<item-filename>`
			line per item in running, review, pending and blocked, at
			most 40, then `(+<n> more)`; `(none)` when empty.
			`<team-member>` is the only argument -- no --state/--header
			override.

		--magic-heartbeat-config-check
			Read-only, no arguments -- routine-heartbeat's step-0
			config gate. Checks magic-coordinator's own config for
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

		--magic-morning-review-input-scan <team-member>
			Read-only, magic-coordinator's only:
			magic-librarian.morning-review.routine's own input.
			<team-member> is one of its executors (magic-coordinator,
			magic-librarian). `## cutoff`: `since:` this caller's own
			cut-off (default 7 days back when none is stored) and
			`next:`, the value to pass to
			--magic-morning-review-state-advance at close. `## state
			shape`: one `counts:` line over every board state, then
			one `<rule>: <n>` line per rule with at most 3 items, each
			`<state>/<item-filename>` plus its state headers only,
			never a body: blocked-no-blocker, parked-no-recheck-date,
			running-session-ended (by the spawned-sessions registry),
			review-no-review-by, processed-no-processed-at. `## skillset
			files changed since cutoff`: names only, newest first, at
			most 20. A cap reached says `(capped, <n> shown)`. Exit 0
			every source read, 2 some (each gap is a `**NOTE:**
			partial` line), 1 none.

		--magic-morning-review-state-advance <team-member> <ts>
			Moves this caller's own morning-review cut-off to <ts>,
			the scan's `next:` value, and commits it. Equal is a
			no-op; backwards or future is refused.

		--magic-advance-input-scan <team-member>
			Routine-advance's own board scan (the same scan
			routine-update-board and routine-heartbeat read). Scans
			pending/running/review/blocked/parked, every board-item type, every
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

			Not read-only. Before anything is read it closes what a dead
			spawn left open, so the output already shows the result:
			a spawn record still started whose session is gone (this
			host: no live process, no open ask and nothing under its
			sandbox changed in the last 15 minutes; any other host: no
			open ask and nothing changed in 24 hours; a change is any
			file under its sandbox or under
			`.local/agents/sessions/<id>/`, which is where a waiting
			session keeps its Wait state) is closed with the
			ended-without-close outcome; the dispatch item it links is
			closed with that outcome too (a created dispatch item
			moves to board-review, a reused item stays where it is); a
			running dispatch item whose record already ended is closed
			with that record's own outcome and moves to board-review,
			and one with no record that has not changed in 24 hours is
			closed with the ended-without-close outcome and moves to
			board-review. Nothing about this is written
			into the scan's output: the actions go as one post into the
			calling spawn's own event-track thread, when it has one. A
			second scan changes nothing more.

			It also hands a board-review item whose `review-by` names a
			session that has ended (no live row for it, or no row and
			the item unchanged for 24 hours) to `magic-coordinator`
			by rewriting `review-by`. A member name, `human-owner`, a
			live session and a missing `review-by` stay as they are.
			Accepting or returning an item stays the caller's own call.

			Inbox scope is `<team-member>`'s own inbox, notes only: the
			pending-slack-reaction and pending-trello-update records the
			routine's comms step acts on. No inquiries, no reflections,
			no client-* inbox -- those are --magic-grooming-input-scan's.

		--magic-advance-to-running <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
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

		--magic-advance-to-parked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/parked/ -- routine-advance's own
			check-execute-board fallback when a required spawn could not
			run. No auto-stamp: the calling step supplies condition/
			handoff-action/recheck-date/execution-receipt itself via
			`--header:*`; an item left with no recheck-date deliberately
			falls to routine-grooming's slower cadence, so this op never
			invents one.

		--magic-board-to-pending <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/pending/. No auto-stamp.

		--magic-board-to-blocked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/blocked/. One auto-stamp:
			`execution-receipt` defaults to `blocked:<timestamp>` unless
			the caller supplies its own via `--header:upsert:execution-
			receipt:*`/`--header:append:execution-receipt:*`, in which
			case the caller's value stands.

		--magic-board-to-backlog <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/backlog/. No auto-stamp.

		--magic-board-to-parked <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
			As `--magic-advance-to-running` for arguments and body-input
			shape, target board/parked/ -- check-process-board's own
			move, the board-mechanical-moves counterpart. No auto-stamp
			here, and no `--magic-board-*` op stamps grooming provenance
			(the closing -to-blocked and -to-processed moves stamp their
			own fields instead). `recheck-date`/`condition` are caller-
			supplied via `--header:*`.

		--magic-append-session-transcript <team-member> <session-id> [--speaker <speaker-name>] [--timestamp <ISO-UTC-date-time>] (--message <verbatim-text>|--from-stdin|--from-file <path>) [--create]
			The coordinator's append to any session's tooling-written transcript,
			named by its session id: one NOTE line, as the member form appends
			to its own session. `--create` starts the transcript when the session
			has none. Runs only as magic-coordinator. Members use
			`--member-append-session-transcript`.

		--magic-board-to-processed <team-member> <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]] [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
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
			Approval cascade (every op moving through
			`--intern-op-board-upsert-move-edit`): an `approval-*`
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

		--magic-board-create-running <team-member> <item-filename> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]... [--recheck-in <minutes>[±<jitter-minutes>]]
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
			Releases the lock in routine closure, setting
			`state: advance-finished`/`grooming-finished`/
			`daily-finished`/`retro-finished`. Prints `RELEASED` (rc 0)
			only once the close is read back from the note on disk and
			committed/pushed as configured; otherwise prints
			`CLOSE_NOT_RECORDED` naming what failed, keeps the lock (the
			note is not left finished) and returns 1. The grooming and daily closes also stamp
			`last-close-date` (today, local), which
			--magic-heartbeat-input-scan's `grooming-today:` and
			--magic-daily-lock-acquire's `first-today:` read.

			Closing content is optional, written in the SAME upsert
			call that sets the finished state and releases the lock --
			one call closes a pass, not two. Omitted, the note's body
			is preserved, only headers/lock change. Narrower than the
			sibling --magic-*-state-and-lock-upsert ops: no
			--upsert-from-stdin, closing content is expected prepared.

			--from-file <path>
				Replaces the whole note, frontmatter included -- a
				field the file omits is gone from the note.
				`session-id` is carried forward regardless, so the
				lock is never orphaned.

			--edit-patch-from-stdin
				Applies a JSON array of {"old","new","replace_all"}
				patches to the existing body. Mutually exclusive
				with --from-file.

			--magic-advance-close-state-and-unlock only, with
			TEAM_DATA_GIT_REMOTE set: pushes after the unlock commit,
			then resyncs the board. A failure of either warns on
			stderr and still returns 0 -- the lock releases either way.

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
			Writes the calling routine's own fixed state-and-lock
			note -- its session tracking document between
			iterations, not a transcript. Prefer referencing
			TEAM-DATA over copying it. `state` and `recheck-date` are
			stamped by the operation itself (+10 minutes for advance,
			+30 for grooming, daily and retro); pass
			`--header:upsert:state:<routine>-finished` to close.

			--header:<upsert|append|remove>:name[:value]
				Frontmatter field operations, applied in order. A
				repeated upsert on one field takes the last value.
				`recheck-date` is always re-stamped, cannot be
				overridden.

			--from-file <path>
				Replaces the whole note, frontmatter included -- an
				omitted field is gone. `session-id` is the
				exception, carried forward so the lock can't be
				orphaned.

			--edit-patch-from-stdin
				Applies a JSON array of {"old","new","replace_all"}
				patches to the existing body. Mutually exclusive
				with --from-file. Given neither, the body is
				preserved.

		--magic-advance-sleep-run
			Read-only, no arguments -- a fixed-duration pacing operation in
			routine-advance's operation group.

		--magic-heartbeat-board-item-trash <team-member> <board-state> <item-name> [--untrash]
			Relocates one terminal board-item out of the board entirely, for
			routine-heartbeat's own GC step. <team-member> is the calling
			member's own identity — recorded in the git-commit message once
			team-data is git-tracked, otherwise unused;
			<board-state> is the item's current real board state
			(backlog/pending/running/review/blocked/parked/processed/
			archived/retained); <item-name> is a bare filename. Thin wrapper.

			--untrash restores instead: on a store with no git, it moves
			trash/<item-name> back into board/<board-state>/, and refuses
			if the board already holds that name. On a git store a
			trashed item was deleted and committed, so --untrash fails
			(non-zero), changes nothing, and says so: a git store keeps
			trashed items only in its history, no tooling op restores
			from it, and the coordinator is the one to ask.

		--magic-heartbeat-spawn-proxy <team-member> [--from-stdin] [--from-file <path>] [--from-board <board-item-name> [--board-state <state>]...] [--from-vault <vault-item-name>] [--from-audit <audit-item-name>] [--session-thread:event-track|magic-team] [--session-name-or-comment <text>] [--wait]
			Heartbeat/advance spawn relay: executes a spawn prompt via
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
			closed later by --magic-advance-input-scan, with the
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

			Every spawn opens a tooling-maintained thread in
			event-track (when `SLACK_CHANNEL_EVENT_TRACK` and a
			bot token are set, else skipped silently), closed with
			the result on exit -- never reaches stdout, and a
			failed post never fails the spawn.

			Every spawn also belongs to a coworking session:
			inheriting one from its parent joins it with no new
			thread. Where that thread is unknown, or the post
			fails, one stderr warning is printed and the spawn
			goes on. Otherwise one opens in magic-team, titled by
			--session-name-or-comment or the session id.
			--session-thread:event-track pins it to the agent-log
			thread instead and skips the magic-team post -- used
			by the main loop's own solitary spawns.

			The brief ends with a "## Your session thread" section
			carrying `session_thread_ts: <channel>:<ts>` -- the
			value --member-comms-slack-send-message takes as
			target and --member-comms-slack-read takes with
			--thread. If the opening post failed, it says so and
			asks the session to post its own thread.

		--magic-spawn-session (--routine <selector>|--routine-default) [--session-name-or-comment <text>] [<team-member>...]
			Starts a coworking session and spawns its initial members
			in one call. Task text comes from stdin. Exactly one of
			`--routine <selector>` | `--routine-default` is required
			-- the selector is a full routine filename or part of
			one, resolved once so every spawned member carries the
			same routine file; that spawn's own spawn-prepare-brief
			block is then automatic ahead of the task text.

			Given no `<team-member>...` names, the spawned members
			come from the resolved routine's own `executors`
			frontmatter line, a plain comma-separated list of real
			members. Anything else -- `magic-team`/`*` (any-member
			shorthand) or free prose -- names no spawnable roster and
			is refused, asking for explicit `<team-member>...`
			instead.

			The first member spawned starts the session; every
			further one joins it by the session id the first spawn's
			own output reports. A routine's own `invitees` are never
			spawned here -- the session's own executor invites them
			separately.

			Prints `SESSION_ID` (what further spawns join by),
			`ROUTINE` (the resolved filename), `MEMBERS` (spawned
			members, space-separated).

		--magic-heartbeat-state-upsert <team-member> [--from-file <path>|--edit-patch-from-stdin]
			Writes (creates or overwrites) routine-heartbeat's own state
			record. Takes no filename or path argument -- storage is
			the operation's own concern.
			Input source is exactly one of: stdin (default), `--from-file`, or
			`--edit-patch-from-stdin`. Empty content is rejected. If
			`--edit-patch-from-stdin` is used, stdin must be a JSON patch array
			for exact-literal replace operations.
			While the note says `state: heartbeat-running`, every state
			write also refreshes the lock: `recheck-date` is set to now
			+ 15 minutes, the same value `--magic-heartbeat-lock-refresh`
			writes, so a pass that keeps writing its state needs no
			separate refresh call for it. Any other state is carried
			over untouched.
			Stamps `last-iteration-date` (today, local) and
			`last-iteration-timestamp` (now, UTC `YYYY-MM-DDTHH:MM:SSZ`)
			itself; a value the caller gives wins. A stored
			`last-test-email-sent` the caller leaves out is kept.

		--magic-heartbeat-test-report-send <team-member>
			Sends the hourly test report. <team-member> must be
			magic-coordinator. Prints `NOT_DUE:last-test-email-sent=...:
			due-in=<n>s` and returns 0, sending nothing, until an hour
			has passed since the note's `last-test-email-sent`. Once due:
			builds the body from the heartbeat scan's own day-rhythm
			lines, board counts and board active items, sends it through
			--member-comms-email-send (text group report) to human-owner's
			EMAIL_USER, stamps `last-test-email-sent`, and prints
			`SENT:to=<address>:last-test-email-sent=<timestamp>`. rc 1,
			with nothing stamped, when EMAIL_USER is unset, the
			heartbeat note does not exist yet, or the send fails.

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
			`state: heartbeat-finished`. Prints `RELEASED` (rc 0) only once
			the close is read back on disk and committed/pushed as
			configured; otherwise `CLOSE_NOT_RECORDED`, lock kept, rc 1.
			Takes no options; any further argument is rejected.

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
			`<team-member>` is the member this read acts as -- decides
			which conversation this call can see at all.

			Full detail for one message (default) or its whole thread
			(--thread): all meta-info, reactions, formatting,
			files/attachments, raw JSON exactly as Slack returns it,
			never pretty-formatted. A `<ts>` naming a thread reply reads
			that reply like any other message.

			A target with no `:<ts>` names a conversation instead,
			reading its own messages pretty-formatted, newest first,
			paged to the end; --oldest <epoch> floors how far back
			paging walks (needed on a busy channel -- past the page cap
			is a hard failure, not a truncated answer). --thread is for
			the `<channel>:<ts>` form only, --oldest for the
			conversation form only.

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

		--member-comms-email-read <team-member> <uid> [--seen]
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

		# Sweep all watched targets (magic-team, human-owner, email, Trello) for new activity --
		# board-tracked threads and every watched source in one pass, not a single-target reader
		`DistroAgentsTools.fn.sh --magic-sweep-input-scan magic-coordinator`

		# Sweep all watched targets, incrementally since a prior check marker
		`DistroAgentsTools.fn.sh --magic-sweep-input-scan magic-coordinator --comms-since-utime 1786140114.450349`

		# Regression-test permission hardening under a deliberately permissive umask
		`DistroAgentsTools.fn.sh --owner-credential-store-self-test`
