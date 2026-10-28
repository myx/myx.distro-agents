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

		the team's Google operations. A bare call prints the syntax line of each of the
		file's operations, --help-syntax prints every form of every operation (or of one
		operation, or of those that a prefix ending in "-" begins), and --help prints this
		manual.

##  Options:

		--google-file-find (<search-term> [--full-text] [--include-trashed]|<drive-query> --raw-query)
			Finds the files of the member's own Drive by a search term, or by a Drive query
			said to be raw.

		--google-whoami
			Prints the Google account the member's credentials belong to.

		--google-doc-read <doc-id>
			Prints one document of that account, as its text.

		--google-doc-write <doc-id> (<text...>|--from-stdin|--from-file <path>)
			Writes the text given into that document.

		--google-comment-read <file-id>
			Prints the comments on that file.

		--google-comment-post <file-id> (<text...>|--from-stdin|--from-file <path>)
			Posts one comment on that file, in the member's own voice.

		--google-sheet-info <sheet-id>
			Prints what the spreadsheet is made of: its sheets and the extent of each.

		--google-sheet-read <sheet-id> <a1-range> [--unformatted]
			Prints the values of that A1 range. `--unformatted` takes them as stored, not as
			the sheet shows them.

		--google-sheet-write <sheet-id> <a1-range> (--from-stdin|--from-file <path>)
			Writes the values given into that A1 range, and with `--append` after its last
			row instead of over it.

		--google-sheet-clear <sheet-id> <a1-range>
			Empties the values of that A1 range, the sheet's own formatting left alone.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
