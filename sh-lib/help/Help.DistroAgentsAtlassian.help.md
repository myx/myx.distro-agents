📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-comment-add [--team-member <team-member>] <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-comment-read [--team-member <team-member>] <page-id>
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-create [--team-member <team-member>] (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-id <id>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-delete [--team-member <team-member>] <page-id>
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-search [--team-member <team-member>] <cql> [--limit <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-update [--team-member <team-member>] <page-id> --version <n> --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-space-create [--team-member <team-member>] --key <space-key> --name <text> [--description <text>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-space-list [--team-member <team-member>] [--cursor <value>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-board-issue-search [--team-member <team-member>] <board-id> [--start-at <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-board-list [--team-member <team-member>] [--start-at <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-board-read [--team-member <team-member>] <board-id>
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-comment-add [--team-member <team-member>] <issue-key> (--body-adf <json>|--body-adf-from-stdin|--body-adf-from-file <path>)
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-comment-read [--team-member <team-member>] <issue-key> [--format adf|rendered] [--start-at <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-create [--team-member <team-member>] --project <key> --issuetype <name> --summary <text> [--description-adf <json>|--description-adf-from-stdin|--description-adf-from-file <path>] [--fields-json <json>] [--assignee <contact>|me]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-delete [--team-member <team-member>] <issue-key>
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-project-delete [--team-member <team-member>] <project-key>
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-link-list [--team-member <team-member>] <issue-key>
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-link-page [--team-member <team-member>] <issue-key> --url <page-url> --title <text>
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-read [--team-member <team-member>] <issue-key> [--format adf|rendered]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-search [--team-member <team-member>] <jql> [--limit <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-transition [--team-member <team-member>] <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>|--comment-adf-from-stdin|--comment-adf-from-file <path>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-issue-update [--team-member <team-member>] <issue-key> [--fields-json <json>] [--update-json <json>] [--notify-users] [--assignee <contact>|me --project <key>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-sprint-issue-search [--team-member <team-member>] <sprint-id> [--start-at <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --jira-sprint-list [--team-member <team-member>] <board-id> [--start-at <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-read [--team-member <team-member>] <page-id> [--format storage|atlas_doc_format] [--version <n>]

##  Summary:

		the team's Jira and Confluence operations. A bare call prints the syntax line of
		each of the file's operations, --help-syntax prints every form of every operation
		(or of one operation, or of those that a prefix ending in "-" begins), and --help
		prints this manual.

##  Options:

		--jira-issue-read <issue-key> [--format adf|rendered]
			Prints one issue. `adf` is Atlassian's own document format, `rendered` the text a
			reader sees.

		--jira-issue-search <jql> [--limit <n>]
			Prints the issues a JQL query finds, up to the limit given.

		--jira-issue-create --project <key> --issuetype <name> --summary <text> [--description-adf <json>] [--assignee <contact>|me]
			Creates one issue there, and `--fields-json` sets any other field it needs.
			Every issue takes an assignee: `--assignee` names a contact, or `me`,
			and the acting identity is the default.

		--jira-issue-update <issue-key> [--fields-json <json>] [--update-json <json>] [--notify-users] [--assignee <contact>|me --project <key>]
			Changes the fields of one issue. `--assignee` sets its assignee, and
			needs `--project`, where the contact must be assignable.

		--jira-issue-transition <issue-key> --to-status <name> [--fields-json <json>] [--comment-adf <json>]
			Moves one issue to that status, with a comment where one is given.

		--jira-issue-delete <issue-key>
			Deletes one issue.

		--jira-project-delete <project-key>
			Deletes one project, after printing its own key and name. The
			printed row is the confirmation. Runs only as `magic-coordinator`,
			and Jira's undo window is off, so nothing restores the project.

		--jira-comment-read <issue-key> [--format adf|rendered] [--start-at <n>]
			Prints the comments of one issue, from the place named on.

		--jira-comment-add <issue-key> (--body-adf <json>|--body-adf-from-stdin|--body-adf-from-file <path>)
			Adds one comment to that issue.

		--jira-issue-link-list <issue-key>
			Prints the remote links stored on that issue, one a line: its id, its
			address and its title. Every member may read them, since they are
			readable by any identity that can see the issue.

			Completeness on stderr: `more: unknown` always, because this
			endpoint's answer carries no total and no paging field, so it
			can never say it holds every link. An answer that is not the
			array of links is reported UNKNOWN with 3, never as an issue
			holding none. Exit statuses as `--jira-board-list` lists them.

		--jira-issue-link-page <issue-key> --url <page-url> --title <text>
			Links a page, such as a Confluence page, to that issue. Runs only as
			`magic-coordinator`. The address identifies the link, so a retry leaves one.

		--jira-board-list [--start-at <n>] / --jira-board-read <board-id> / --jira-board-issue-search <board-id> [--start-at <n>]
			The boards the member may see; one board; and the issues of one board, from the
			place named on.

		--jira-sprint-list <board-id> [--start-at <n>] / --jira-sprint-issue-search <sprint-id> [--start-at <n>]
			The sprints of one board; the issues of one sprint, from the place named on.

		--confluence-page-read <page-id> [--format storage|atlas_doc_format] [--version <n>]
			Prints one page, or the version of it named.

		--confluence-page-search <cql> [--limit <n>]
			Prints the pages a CQL query finds, up to the limit given.

		--confluence-page-create (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>)
			Creates one page in that space, the body in Confluence's storage format, under a
			parent page where `--parent-id` names one.

		--confluence-page-update <page-id> --version <n> --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>)
			Replaces one page's title and body. `--version <n>` is the version the page was
			read at (`version.number` of --confluence-page-read): the operation writes
			version n+1 itself, and the service refuses with 409 where the page has moved
			past n, so a page changed since it was read is not overwritten unseen.

		--confluence-page-delete <page-id>
			Deletes one page.

		--confluence-comment-read <page-id>
			Prints the comments of one page.

		--confluence-comment-add <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
			Adds one comment to that page, as an answer where a parent comment is named.

		--confluence-space-create --key <space-key> --name <text> [--description <text>]
			Creates one space on this organisation's own site, and prints its row:
			`SPACE_ID`, `KEY`, `NAME`, `URL`. `--key` is how every page of the space is
			addressed afterwards, so a key outside letters, digits, `-` and `_` is refused
			before anything is sent. `--description` goes in the one form a create takes,
			plain text.

			A space is the site's top-level container, so this runs only as
			`magic-coordinator`, and no client-side twin of it exists. The account
			needs Confluence's permission to create spaces: the site answers 404
			without it, which is reported as that refusal and not as a missing space.

			An answer carrying no space id is reported UNKNOWN with 3, never as success,
			because nothing is created twice on an unknown outcome.

		--confluence-space-list [--cursor <value>]
			The spaces the member may see, one page of them, the next page by the cursor
			shown.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
