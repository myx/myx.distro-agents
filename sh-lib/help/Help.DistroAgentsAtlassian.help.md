📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-comment-add [--team-member <team-member>] <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-comment-read [--team-member <team-member>] <page-id> [--inline] [--since <iso-utc-date>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-comment-resolve [--team-member <team-member>] <page-id> <comment-id>
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-check [--team-member <team-member>] [<page-id>...]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-create [--team-member <team-member>] (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-id <id>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-delete [--team-member <team-member>] <page-id>
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-move [--team-member <team-member>] <page-id> --parent-id <parent-page-id>
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-search [--team-member <team-member>] <cql> [--limit <n>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-update [--team-member <team-member>] <page-id> (--version <n>|--if-version <n>) --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--space-id <numeric-id>]
📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-page-render [--team-member <team-member>] --source <spec> [--page-id <page-id>]
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

		--confluence-page-read <page-id> [--format storage|atlas_doc_format] [--version <n>]			Prints one page, or the version of it named.

		--confluence-page-search <cql> [--limit <n>]
			Prints the pages a CQL query finds, up to the limit given.

		--confluence-page-check [<page-id>...]
			Checks each page against the documentation convention's mechanical rules, and
			prints one row per failing page and rule: the page's id, the rule's own id and
			what failed. Read-only. Exit 1 where it printed a row, and 0 where every page
			passes.

			With no page id it checks the ids the workspace setting
			`CONFLUENCE_PAGE_CHECK_PAGES` names, comma-separated, and refuses with 6 where
			that setting holds none: a page set belongs to the workspace, never to this
			package.

			The rules are R1, R2, R3, R4, R5, R8's title uniqueness, R9, R10, R11's
			credential half and R13, of the `confluence-page` contract proposed to
			`magic-librarian`. R6, R7, R12 and R14 need the page inventory or a live read,
			and R15 is decided only once this check is wired to the render.

			A page it cannot read is a failing row, never a skip: a 404 is a missing page
			and a page this identity may not see, and the row says both. A link whose target
			the checked set's spaces do not hold is reported on stderr as uncompared.

		--confluence-page-create (--space <key>|--space-id <numeric-id>) --title <text> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>)
			Creates one page in that space, the body in Confluence's storage format, under a
			parent page where `--parent-id` names one.

			A 🙋 WARNING on stderr before the request says the page cannot be removed
			afterwards unless this identity holds delete there, so a page made for a
			measurement stays in its space. The page is still created.

		--confluence-page-update <page-id> (--version <n>|--if-version <n>) --title <text> --status <value> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>)
			Replaces one page's title and body. `--version <n>` is the version the page was
			read at (`version.number` of --confluence-page-read): the operation writes
			version n+1 itself, and the service refuses with 409 where the page has moved
			past n, so a page changed since it was read is not overwritten unseen.

			`--if-version <n>` is the same number, read again here before anything is sent. A
			page that stands at another version is a CONFLICT printed on stderr, exit 10, and
			nothing written. This is the form a regeneration uses: its body was rendered
			against that version, and writing it over a newer body would drop the other
			writer's words with no error at all.

		--confluence-page-delete <page-id>
			Deletes one page.

			A 404 is read back once, so the answer separates a page this identity may not
			delete from a page that is not there. Both stay exit 8, and whether another
			identity still holds a page the read-back cannot see is UNKNOWN.

		--confluence-page-move <page-id> --parent-id <parent-page-id>
			Puts one page under that parent, which makes it that page's
			child. Only the parent changes: the title, the body and the
			version stay as they were.

			Confluence's v2 page update carries no parent field, so the
			move is the v1 `PUT /wiki/rest/api/content/<id>/move/append/<parent>`.
			The page is then read back through v2, and the read-back is
			what is printed: `PAGE_ID`, `TITLE`, `PARENT_ID`.

			Returns 0 when the page reads back under that parent. **3**:
			UNKNOWN -- the move was sent, and the read-back failed or
			showed another parent. Both pages are then read before
			anything is sent again. **8**: the page or the parent is
			missing, or this identity may not see it. **9**: refused,
			so nothing moved and a retry of the same call changes
			nothing. Every other status means the move was not sent.

		--confluence-comment-read <page-id> [--inline] [--since <iso-utc-date>]
			Prints the comments of one page, as TSV rows: `COMMENT_ID`,
			`VERSION_AUTHOR_ID`, `CREATED`, `BODY`, `PAGE_ID`, `STATUS`,
			`RESOLUTION_STATUS`, `PARENT_COMMENT_ID`.

			Without `--inline`, the page's footer comments.
			`--inline` adds its inline comments, which are the ones attached
			to a span of the body. A reply to either kind is read under its
			parent, so a reply is a row carrying its parent's id: a caller
			that wants only comments to act on skips the rows whose
			`PARENT_COMMENT_ID` is not empty.

			`--since` bounds the read by the comment's own
			`version.createdAt`, so a scan of a page files nothing twice. It
			takes `2026-11-20` or `2026-11-20T09:00:00.000Z`, both read as
			UTC, and any other form is refused before anything is sent.

			No completeness signal: stderr always states `more: unknown`.

		--confluence-comment-add <page-id> (--body-storage <html>|--body-storage-from-stdin|--body-storage-from-file <path>) [--parent-comment-id <id>]
			Adds one comment to that page, as an answer where a parent comment is named.
			A reply takes its parent's own leg: a footer comment is answered at
			`/wiki/api/v2/footer-comments`, and an inline comment at
			`/wiki/api/v2/inline-comments` with its parent named. The parent is read
			on the footer leg first and the inline leg second, so an id on neither
			is refused and nothing is posted.

		--confluence-comment-resolve <page-id> <comment-id>
			Runs only as `magic-coordinator` or `magic-librarian`; any
			other name is refused with 1. Resolves one inline comment on
			that page, and prints the state it is left in: `COMMENT_ID`,
			`PAGE_ID`, `RESOLUTION_STATUS`, `WROTE`.

			The comment is read first, so the write carries its text as
			the site holds it and the next version number. A comment the
			site answers `resolved` already is answered with success and
			`WROTE` `no`, so a second pass is safe. A comment reading
			`dangling` is refused with 9, because the site will not
			update one.

			An id the site does not hold, or one this identity may not
			see, is refused with 8 and nothing is written. A comment on
			another page is refused with 1, naming both pages. A write the
			read-back does not show is UNKNOWN with 3, never success.

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
