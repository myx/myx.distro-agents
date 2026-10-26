📘 syntax: DistroAgentsKnowledge.fn.sh --member-help [--team-member <team-member>]
📘 syntax: DistroAgentsKnowledge.fn.sh --get-path-history [--since <YYYY-MM-DD>] [--until <YYYY-MM-DD>] [--limit <n>] <path>...
📘 syntax: DistroAgentsKnowledge.fn.sh --get-roster [--team-member <team-member>]
📘 syntax: DistroAgentsKnowledge.fn.sh --list-places
📘 syntax: DistroAgentsKnowledge.fn.sh --get-place-path <name>[/<relative>]
📘 syntax: DistroAgentsKnowledge.fn.sh --list-namespaces [<namespace>]
📘 syntax: DistroAgentsKnowledge.fn.sh [--mdat-output-format json] [<project selector: --select-*|--filter-*|--remove-*>] (--add-source-docs|--add-board-items|--add-vault-items|--add-inbox-items)... (--query-keyword <text>|--query-pattern <regex>|--query-glob <glob>|--query-open-and|--query-open-or|--query-close)...
📘 syntax: DistroAgentsKnowledge.fn.sh [--help-syntax [<op>]]
📘 syntax: DistroAgentsKnowledge.fn.sh [--help]

##  Summary:

		What the team has written, searched, and the registries read. A bare call
		is a query: the sources added, the projects whose docs it reads, and the
		terms it answers by, its result the sections that answer, each with its
		source. The registry operations read the projects, the places, the
		namespaces and the members, and one member's own help.

##  Options:

		[--mdat-output-format json] [<project selector: --select-*|--filter-*|--remove-*>] (--add-source-docs|--add-board-items|--add-vault-items|--add-inbox-items)... (--query-keyword <text>|--query-pattern <regex>|--query-glob <glob>|--query-open-and|--query-open-or|--query-close)...
			The query. Each `--add-` option adds a store to read, and only what is
			added is read: the docs of the selected projects with their LanceDB store,
			the board items, the vault, the acting member's own inbox. The selector is
			the one ListDistroProjects takes, and none given is every project of the
			workspace. The terms are answered by section: keyword, pattern and glob
			lines, and groups opened with `--query-open-and` or `--query-open-or` and
			closed with `--query-close`. Markdown by default, or JSON under
			`--mdat-output-format json` before the first word.

		--get-path-history [--since <YYYY-MM-DD>] [--until <YYYY-MM-DD>] [--limit <n>] <path>...
			The commits that touched the paths named, a row each.

		--get-place-path <name>[/<relative>]
			Where a registered place stands on this machine.

		--list-namespaces [<namespace>]
		--list-places
			The registries read: the namespaces, one or all, and every place with its
			path.

		--get-roster [--team-member <team-member>]
			The team's roster, a row each, as the tooling holds it.

		--member-help [--team-member <team-member>]
			One member's own operation group, as its duty instructions declare it,
			and the operations the floor under every member gives it.

##  Examples:

		# Ask the team's own docs what they say about one operation
		`DistroAgentsKnowledge.fn.sh --add-source-docs --select-all --query-keyword help-syntax`
		# The same, over the board and the vault, as JSON
		`DistroAgentsKnowledge.fn.sh --mdat-output-format json --add-board-items --add-vault-items --query-pattern 'permission|grant'`
		# A group: one term or the other, then a second term that must hold too
		`DistroAgentsKnowledge.fn.sh --add-source-docs --query-open-or --query-keyword "spawn" --query-keyword "dispatch" --query-close --query-keyword "routine"`
		# The registries, and one member's own help
		`DistroAgentsKnowledge.fn.sh --list-places`
		`DistroAgentsKnowledge.fn.sh --get-place-path myx.distro-agents`
		`DistroAgentsKnowledge.fn.sh --member-help keeper-myx`
