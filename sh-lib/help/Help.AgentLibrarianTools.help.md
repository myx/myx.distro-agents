📘 syntax: AgentLibrarianTools.fn.sh --request-update --kind document|knowledge|skill --target <target> --why <text> (--from-stdin|--from-file <path>) [--reply]
📘 syntax: AgentLibrarianTools.fn.sh --request-update --kind skill --target <team-member>:<pathname> --why <text> --whole-text (--from-stdin|--from-file <path>) [--reply]
📘 syntax: AgentLibrarianTools.fn.sh --request-update --kind skill --target <team-member>:<pathname> --why <text> (--old <text>|--old-from-file <path>) (--new <text>|--new-from-file <path>) [--reply]
📘 syntax: AgentLibrarianTools.fn.sh --skillset-upsert [--team-member <team-member>] <pathname> (--from-stdin|--from-file <path>)
📘 syntax: AgentLibrarianTools.fn.sh --queue-list
📘 syntax: AgentLibrarianTools.fn.sh --queue-take
📘 syntax: AgentLibrarianTools.fn.sh --queue-done <name> (--apply|--refuse <reason>|--result <text>)
📘 syntax: AgentLibrarianTools.fn.sh --request-result <name>
📘 syntax: AgentLibrarianTools.fn.sh --doc-drift [<path>...] [--queue]
📘 syntax: AgentLibrarianTools.fn.sh --skillset-size [<team-member>...]
📘 syntax: AgentLibrarianTools.fn.sh --queue-ask <name>
📘 syntax: AgentLibrarianTools.fn.sh [--help-syntax]
📘 syntax: AgentLibrarianTools.fn.sh [--help]

##  Summary:

		The librarian's personal tool, and the queue of update requests
		any member files to ask the librarian for an update of a
		document, the knowledge base or a skill file. A tool that takes
		work in: nobody reads results from it but the one who asked.

##  Options:

		--request-update --kind document|knowledge|skill --target <target> --why <text> (--from-stdin|--from-file <path>) [--reply]
		--request-update --kind skill --target <team-member>:<pathname> --why <text> --whole-text (--from-stdin|--from-file <path>) [--reply]
		--request-update --kind skill --target <team-member>:<pathname> --why <text> (--old <text>|--old-from-file <path>) (--new <text>|--new-from-file <path>) [--reply]
			Any member's request for an update, filed as one inquiry into
			magic-librarian's inbox; its name is printed. Three forms. A
			message: the member's words, about a document (the target a
			file, by a path), the knowledge base (the target a topic) or a
			skill. A whole text: the proposed whole text of a skill file.
			A concrete edit: the old and the new string of a skill file,
			as Edit takes them, the old one being in the file once. A
			whole text and an edit are for a skill file, the target
			`<team-member>:<pathname>`. The tooling records the target
			file's date and checksum itself, and the requester never gives
			them. A request is a notice unless it asks for its outcome
			with `--reply`: then `--queue-done` files one note with the
			outcome into the requester's inbox.

		--skillset-upsert [--team-member <team-member>] <pathname> (--from-stdin|--from-file <path>)
			The librarian's save of a `.md` file of a member's skill, the
			whole text, into the skill's source copy. Skill access, not
			file access: a tool of its own, apart from the rules of Skill,
			Read and Write. `<pathname>` is relative to the skill's
			folder, no `..`. It never writes an install and never the HOME
			skills folder. The librarian's alone; it asks the permission
			`skillset-upsert` over `<team-member>:<pathname>`, and changes
			the skillset only while `learning` is on. The resulting text
			is checked before it is saved. Prints `OK: wrote <file>`.

		--queue-list
		--queue-take
			The update requests that wait in magic-librarian's incoming/,
			read-only: `--queue-list` as a row each (name, kind, target,
			form, from, date), `--queue-take` as one batch, each request
			whole, with the line `BASE:` where its target file is as it
			was when the request was written and `BASE-CHANGED:` where it
			is not. A request leaves the queue only when it is closed.

		--queue-done <name> --apply
		--queue-done <name> --refuse <reason>
		--queue-done <name> --result <text>
			The librarian's decision on one waiting request, alone.
			`--apply` saves the whole text or the concrete edit of a skill
			file by the very path and checks of `--skillset-upsert`;
			`--refuse` closes it with the librarian's reason, not correct
			or not needed; `--result` closes it with what was done. Where
			the request asked for it (`--reply`), one note with the
			outcome is filed into the requester's inbox. Prints
			`closed: <name>`.

		--request-result <name>
			Where a request stands, one line: `UPDATE <name> WAITING --`
			while it is in the librarian's incoming/, `UPDATE <name> DONE
			(<outcome>) --` once closed, or `UNKNOWN` (exit 1) for a name
			that is no update request.

		--skillset-size [<team-member>...]
			The size of the skillset, so that "the skillset shrinks" can be
			measured. Reads the skill folders of the registered members (this
			workspace's, then those of the other workspaces of this machine)
			and writes nothing. Prints rows of TAB-separated fields on stdout:
			`file <member> <file> <lines> <bytes>`
			One row for each file below a member's folder, <file> its path
			below that folder. <lines> is `-` for a file that holds a NUL byte,
			which is no text; its bytes still count. A file or folder whose
			name starts with a dot is no part of the skillset.
			`member <member> - <lines> <bytes>`
			One row for each member, its text lines and its bytes summed.
			`total - - <lines> <bytes>`
			One row, over the members printed. Members are in the C order of
			their names, the files of a member in the C order of their paths.
			With members named, only those are printed and the total is theirs
			alone. Exit 1 with one error line, and nothing printed, for a name
			that is no registered team member.

		--doc-drift [<path>...] [--queue]
			Detects, by dates and checksums, a package whose code changed
			after its MAGIC.md, README or help files. Read-only without
			`--queue`: one `STALE <path>` line per stale doc. With
			`--queue` (the librarian only), each stale doc is filed as an
			update request into magic-librarian's inbox, and each
			request's name is printed.

		--queue-ask <name>
			The librarian only. Poses a waiting concrete edit to a person
			in Pending Questions, as well as deciding it itself: one
			pending question whose `allow` applies the edit and whose
			`deny` refuses it. Whichever decides first wins. Prints
			`ASKED <id> <who>`.
