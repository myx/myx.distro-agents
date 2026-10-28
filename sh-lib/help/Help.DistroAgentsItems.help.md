📘 syntax: DistroAgentsItems.fn.sh --advance-batch-outcome [--team-member <team-member>] --items:<item-filename>:<outcome>:<execution-receipt>[,<item-filename>:<outcome>:<execution-receipt>]...
📘 syntax: DistroAgentsItems.fn.sh --advance-to-parked [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --advance-to-running [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --create-running [--team-member <team-member>] <item-filename> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
📘 syntax: DistroAgentsItems.fn.sh --move-to-backlog [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --move-to-blocked [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --move-to-parked [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --move-to-pending [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --move-to-processed [--team-member <team-member>] <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --grooming-create-backlog [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
📘 syntax: DistroAgentsItems.fn.sh --grooming-create-blocked [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
📘 syntax: DistroAgentsItems.fn.sh --grooming-create-pending [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
📘 syntax: DistroAgentsItems.fn.sh --grooming-create-processed [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
📘 syntax: DistroAgentsItems.fn.sh --grooming-create-running [--team-member <team-member>] <item-filename> --owner-header-value <value> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin) [--header:<upsert|append|remove>:name[:value]]...
📘 syntax: DistroAgentsItems.fn.sh --grooming-to-archived [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --grooming-to-backlog [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --grooming-to-blocked [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --grooming-to-parked [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --grooming-to-pending [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --grooming-to-processed [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --grooming-to-retained [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --grooming-to-running [--team-member <team-member>] <item-filename> --from-state:<state> --owner-header-value <value> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --commit-pending [--team-member <team-member>] [--commit-message <message>] [--no-push]
📘 syntax: DistroAgentsItems.fn.sh --repair-team-data-checkout [--team-member <team-member>] [--keep-merged|--take-remote]
📘 syntax: DistroAgentsItems.fn.sh --get-inbox-item [--team-member <member>] <item-filename> [--include-processed] [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsItems.fn.sh --trash-inbox-item [--team-member <member>] <item-filename> [--exclude-incoming]
📘 syntax: DistroAgentsItems.fn.sh --mark-inbox-processed [--team-member <team-member>] <item-filename> [--include-processed] [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
📘 syntax: DistroAgentsItems.fn.sh --upsert-inbox-note [--team-member <member>] <item-filename> [--from-member <member>] [--include-processed] [--from-file <path>|--edit-patch-from-stdin|--upsert-from-slots]
📘 syntax: DistroAgentsItems.fn.sh --upsert-inbox-reflection [--team-member <member>] <item-filename> [--from-member <member>] [--include-processed] [--from-file <path>|--edit-patch-from-stdin|--upsert-from-slots]
📘 syntax: DistroAgentsItems.fn.sh --get-audit-item [--team-member <team-member>] <document-name> [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsItems.fn.sh --get-vault-item [--team-member <team-member>] <item-name> [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsItems.fn.sh --get-board-item [--team-member <team-member>] <item-name> [--board-state <state>]... [--start-line <N> --end-line <N>]
📘 syntax: DistroAgentsItems.fn.sh --upsert-inbox-inquiry [--team-member <member>] <item-filename> [--from-member <member>] [--include-processed] [--from-reflection <reflection-file>] [--reply] [--from-file <path>|--upsert-from-slots]
📘 syntax: DistroAgentsItems.fn.sh --request-review [--team-member <team-member>] <item-filename> --reason <text>
📘 syntax: DistroAgentsItems.fn.sh --accept-review [--team-member <team-member>] <item-filename> [--summary <text>]
📘 syntax: DistroAgentsItems.fn.sh --return-review [--team-member <team-member>] <item-filename> (--message <text>|--from-stdin)
📘 syntax: DistroAgentsItems.fn.sh --reject-review [--team-member <team-member>] <item-filename> (--message <text>|--from-stdin)
📘 syntax: DistroAgentsItems.fn.sh --follow-up-review [--team-member <team-member>] <item-filename> <new-item-name> --from-stdin

##  Summary:

		the items of the team's stores: board, inbox, audit and vault. A bare call prints
		the syntax line of each of the file's operations, --help-syntax prints every form
		of every operation (or of one operation, or of those that a prefix ending in "-"
		begins), and --help prints this manual.

##  Options:

		--move-to-backlog <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]...
		--move-to-blocked <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]...
		--move-to-parked <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]...
		--move-to-pending <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]...
			Moves one board item out of the state `--from-state` names and into that one,
			writing the header edits given, and refuses where the item is not there now.

		--move-to-processed <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]...
			The same move into processed, with its receipt and `processed-at` stamps, and it
			releases the item's spawned child as it goes.

		--create-running <item-filename> (--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin)
			Writes a new board item straight into running/, its body from stdin by one of the
			three edit forms.

		--advance-to-running <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]...
		--advance-to-parked <item-filename> --from-state:<state> [--header:<upsert|append|remove>:name[:value]]...
			The advance routine's own moves into running and into parked: the same guarded
			move, taken where the round has finished with the item.

		--advance-batch-outcome --items:<item-filename>:<outcome>:<execution-receipt>[,...]
			Records one outcome and one execution receipt for each item named, and moves
			each on, in a single call.

		--commit-pending [--commit-message <message>] [--no-push]
			Commits the team-data checkout's pending work, and pushes it unless `--no-push`
			says not to.

		--repair-team-data-checkout [--keep-merged|--take-remote]
			Repairs the team-data checkout that diverged from origin: trial-merges, applies
			the mode, moves the flat inbox items by their processed stamp, and pushes.

		--grooming-create-backlog <item-filename> --owner-header-value <value> (...edit...)
		--grooming-create-blocked <item-filename> --owner-header-value <value> (...edit...)
		--grooming-create-pending <item-filename> --owner-header-value <value> (...edit...)
		--grooming-create-processed <item-filename> --owner-header-value <value> (...edit...)
		--grooming-create-running <item-filename> --owner-header-value <value> (...edit...)
			Creates a board item in that state, carrying the owner header the grooming
			routine must give it.

		--grooming-to-archived <item-filename> --from-state:<state> --owner-header-value <value> (...)
		--grooming-to-backlog <item-filename> --from-state:<state> --owner-header-value <value> (...)
		--grooming-to-blocked <item-filename> --from-state:<state> --owner-header-value <value> (...)
		--grooming-to-parked <item-filename> --from-state:<state> --owner-header-value <value> (...)
		--grooming-to-pending <item-filename> --from-state:<state> --owner-header-value <value> (...)
		--grooming-to-processed <item-filename> --from-state:<state> --owner-header-value <value> (...)
		--grooming-to-retained <item-filename> --from-state:<state> --owner-header-value <value> (...)
		--grooming-to-running <item-filename> --from-state:<state> --owner-header-value <value> (...)
			Moves one board item into that state from the one it must be in, with the owner
			header the grooming routine must give it.

		--get-board-item <item-name> [--board-state <state>]... [--start-line <N> --end-line <N>]
			Finds one board item by its name, in the states named or in every state, and
			prints it, or the lines of it named.

		--get-inbox-item <item-filename> [--include-processed] [--start-line <N> --end-line <N>]
			Prints one inbox item, an item still wanted, or with `--include-processed` a
			processed one too, or the lines of it named.

		--get-audit-item <document-name> [--start-line <N> --end-line <N>]
			Prints one audit document, or the lines of it named.

		--get-vault-item <item-name> [--start-line <N> --end-line <N>]
			Prints one vault item, or the lines of it named.

		--upsert-inbox-note <item-filename> [--from-member <member>] [--from-file <path>|--edit-patch-from-stdin|--upsert-from-slots]
			Writes a note into a member's own inbox, creating it or overwriting it.

		--upsert-inbox-reflection <item-filename> [--from-member <member>] [--from-file <path>|--edit-patch-from-stdin|--upsert-from-slots]
			The same for a reflection: what was learned, and why it is worth keeping.

		--upsert-inbox-inquiry <item-filename> [--from-member <member>] [--from-file <path>|--upsert-from-slots] [--reply]
			Files an inquiry into another member's inbox: a question that needs an answer, or
			a piece of work handed over. `--reply` asks for a note with the outcome.

		--mark-inbox-processed <item-filename> [--include-processed] [--header:<upsert|append|remove>:name[:value]]...
			Handles one inbox item: stamps `processed-at`, moves it from `incoming/` into
			`processed/`, and writes the header edits given.

		--trash-inbox-item <item-filename> [--exclude-incoming]
			Discards one inbox item out of the queue, and, unless `--exclude-incoming` says
			otherwise, out of `incoming/` too.

		--request-review <item-filename> --reason <text>
			Asks the item's reviewer to settle the handback, saying why the work is ready.

		--accept-review <item-filename> [--summary <text>]
			Accepts the handback: the work is taken and the item closes, with the summary
			kept where one is given.

		--return-review <item-filename> (--message <text>|--from-stdin)
			Returns the work to the member that made it, with the reason given, and the
			session goes on from there.

		--reject-review <item-filename> (--message <text>|--from-stdin)
			Rejects the work: it is not taken, and the item closes as rejected.

		--follow-up-review <item-filename> <new-item-name> --from-stdin
			Accepts the work and files a follow-up item under that name, its text from stdin.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
