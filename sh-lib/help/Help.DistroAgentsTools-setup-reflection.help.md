📘 syntax: DistroAgentsTools.fn.sh --owner-setup-reflection [<config-option>...] [--check|--apply|--print-apply-command|--render-missing]
📘 syntax: DistroAgentsTools.fn.sh --help-setup-reflection

##  Summary:

		The reflection domain makes this workspace able to mirror
		its work to the team's own board and document places: which
		pair of mechanisms it mirrors to, and the place each half
		writes into.

		This domain configures the choice. It builds no mirror: the
		mirrors are the epic's own later item, and a workspace that
		names a mechanism here starts mirroring nothing until they
		are built.

		The value is one compound setting, REFLECT_MODELS. A half it
		names and this workspace cannot use is a fault, reported by
		`--config-check`, by the console's row and by the mirror. A
		token with no half is no fault: a member's own read uses it
		too.

##  What you do yourself, before --apply:

		Obtain the credentials of each half you name: a Jira and
		Confluence API token pair, a Trello key and token, or a Google
		OAuth client. This domain does not ask for them: they stand
		where the mechanism that reads them keeps them, and the
		`--owner-setup-*` domain of that same subject places them.

##  Options:

		--workspace-root <path>
			Which workspace this call is about. Defaults to the workspace
			the tool is run from, and a path that is not a workspace root
			is an error rather than a fallback. Every sub-operation takes
			it. It names a target; it stores no value.

		--reflect-models <board>+<documents>
			The pair of mechanisms this workspace reflects to. The board
			half is `none`, `jira` or `trello`; the documents half is
			`none`, `confluence` or `google-docs`. The word `none` alone
			is `none+none`, and nothing stored means the same.

			Stored as REFLECT_MODELS in the team scope. A value outside
			the two closed lists is refused at write and reported at
			read, so a typo cannot make a silent third model.

		--reflect-jira-project <project-key>
			The Jira project the board half mirrors into. Read only while
			the model names the `jira` half.

		--reflect-trello-board <board-id>
			The Trello board the board half mirrors into. Read only while
			the model names the `trello` half.

		--confluence-space <space-key>
			The Confluence space the documents half mirrors into. Read
			only while the model names the `confluence` half. It is the
			team's own place key, shared with the other domains that
			publish there.

##  Sub-operations:

		--render-missing
			Step 2 of the wizard, read-only: the keys each chosen half
			needs and this workspace lacks, one line a key. It ends
			non-zero while a key is missing, so it is usable as the gate
			the write waits behind.

		--check
			Writes the per-setting detail behind the status a bare call
			reports. Read-only. Its exit status is non-zero while a half
			the model names cannot be used here.

		--apply
			Carries the four steps out in order: the place keys are
			stored, then each chosen half answers one live read, and only
			then is the model written. A half that does not answer leaves
			the model unchanged, so the workspace never names a half it
			cannot use.

			Every value here is a place or a model, and none is a secret:
			each travels as a flag or on stdin, and nothing of it is
			printed the way a credential is.

		--print-apply-command
			Writes the command an --apply would carry out, with its
			placeholders, and changes nothing.

##  What it does not do:

		It does not write the token sets. Those are member-scope keys
		today, and the plan that moves them to the team scope is the
		epic's own S20 item 3. Until it lands, each half reads its
		tokens from the scope its own mechanism keeps them in, and
		`--render-missing` reports a missing one rather than storing it.

		It does not back-fill the items: the count that falls to zero is
		the mirror's own later stage.
