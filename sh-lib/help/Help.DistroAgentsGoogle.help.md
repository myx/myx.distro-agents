📘 syntax: DistroAgentsGoogle.fn.sh --google-file-find [--team-member <team-member>] (<search-term> [--full-text] [--include-trashed]|<drive-query> --raw-query) [--limit <n>]
📘 syntax: DistroAgentsGoogle.fn.sh --google-comment-post [--team-member <team-member>] <file-id> (<text...>|--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsGoogle.fn.sh --google-comment-read [--team-member <team-member>] <file-id>
📘 syntax: DistroAgentsGoogle.fn.sh --google-doc-read [--team-member <team-member>] <doc-id>
📘 syntax: DistroAgentsGoogle.fn.sh --google-doc-write [--team-member <team-member>] <doc-id> (<text...>|--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsGoogle.fn.sh --google-sheet-clear [--team-member <team-member>] <sheet-id> <a1-range>
📘 syntax: DistroAgentsGoogle.fn.sh --google-sheet-info [--team-member <team-member>] <sheet-id>
📘 syntax: DistroAgentsGoogle.fn.sh --google-sheet-read [--team-member <team-member>] <sheet-id> <a1-range> [--unformatted]
📘 syntax: DistroAgentsGoogle.fn.sh --google-sheet-write [--team-member <team-member>] <sheet-id> <a1-range> [--append] [--user-entered] (--from-stdin|--from-file <path>)
📘 syntax: DistroAgentsGoogle.fn.sh --google-whoami [--team-member <team-member>]

##  Summary:

		the team's Google operations. A bare call lists the operations of the file, --help-syntax
		prints the syntax line of every operation (or of one operation, or of those
		that a prefix ending in "-" begins), and --help prints this manual.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
