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

		the items of the team's stores: board, inbox, audit and vault. A bare call lists the operations of the file, --help-syntax
		prints the syntax line of every operation (or of one operation, or of those
		that a prefix ending in "-" begins), and --help prints this manual.

##  Notes:

		The syntax lines above are this command's own; a word given to
		--help-syntax after it prints that operation's line alone.
