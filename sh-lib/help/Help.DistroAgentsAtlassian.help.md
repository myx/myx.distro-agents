📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-comment-add [--team-member <team-member>] <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-comment-read [--team-member <team-member>] <page-id>
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-create [--team-member <team-member>] (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-id <id>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-delete [--team-member <team-member>] <page-id>
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-search [--team-member <team-member>] <cql> [--limit <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-update [--team-member <team-member>] <page-id> --version <n> --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-space-list [--team-member <team-member>] [--cursor <value>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-board-issue-search [--team-member <team-member>] <board-id> [--start-at <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-board-list [--team-member <team-member>] [--start-at <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-board-read [--team-member <team-member>] <board-id>
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-comment-add [--team-member <team-member>] <issue-key> (--body-adf <json>|--body-adf-from-stdin|--body-adf-from-file <path>)
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-comment-read [--team-member <team-member>] <issue-key> [--format adf|rendered] [--start-at <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-create [--team-member <team-member>] --project <key> --issuetype <name> --summary <text> [--description-adf <json>|--description-adf-from-stdin|--description-adf-from-file <path>] [--fields-json <json>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-delete [--team-member <team-member>] <issue-key>
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-read [--team-member <team-member>] <issue-key> [--format adf|rendered]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-search [--team-member <team-member>] <jql> [--limit <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-transition [--team-member <team-member>] <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>|--comment-adf-from-stdin|--comment-adf-from-file <path>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-update [--team-member <team-member>] <issue-key> [--fields-json <json>] [--update-json <json>] [--notify-users]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-sprint-issue-search [--team-member <team-member>] <sprint-id> [--start-at <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-sprint-list [--team-member <team-member>] <board-id> [--start-at <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-read [--team-member <team-member>] <page-id> [--format storage|atlas_doc_format] [--version <n>]

##  Summary:

		the team's Jira and Confluence operations. A bare call lists the operations of the file, --help-syntax
		prints the syntax line of every operation (or of one operation, or of those
		that a prefix ending in "-" begins), and --help prints this manual.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
