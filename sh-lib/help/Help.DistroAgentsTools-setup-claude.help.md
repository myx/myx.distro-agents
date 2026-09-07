📘 syntax: DistroAgentsTools.fn.sh --owner-setup-claude [<config-option>...] [--all-workspaces] [--set-as-default] [--check|--apply|--print-apply-command|--wizard]
📘 syntax: DistroAgentsTools.fn.sh --help-setup-claude

##  Summary:

		The claude domain makes this workspace able to run Anthropic's
		claude CLI as its spawned agent: the CLI installed, this workspace
		trusted by it, the generated agents console current, and the
		directories a spawned agent may reach granted to it.

		`--owner-setup-claude` reports what this workspace is still
		missing and names the one command that supplies it. This document
		is the other half: every option the domain takes, optional ones
		included, and what you have to do yourself to obtain each value.

		`--owner-setup-claude --apply` carries out everything that can be
		carried out from here. Creating a credential, or signing the CLI
		in, is the part it cannot do for you.

##  What you do yourself, before --apply:

		Installing the CLI is not one of these. `--apply` runs
		`myx.common install/claude` wherever `command -v claude` finds
		nothing.

		1. Start claude once, interactively, on this machine. It writes
		   $HOME/.claude.json on its first run, and `--apply` records this
		   workspace's trust INTO that file rather than standing a
		   replacement in its place -- so an absent file stops the run
		   with a message saying exactly this.

		2. Give claude a way to authenticate. Either of these is enough,
		   and this is the one step no `--apply` can perform for you:

		   - Sign the CLI in with `claude auth login`, on a machine that
		     has a browser. Nothing is stored in this workspace, and
		     neither credential option below is then needed at all.

		   - Or store a credential here, with --anthropic-api-key or
		     --claude-code-oauth-token below. Set one, never both.

##  Options:

		--workspace-root <path>
			Which workspace this call is about. Defaults to the workspace
			the tool is run from, and a path that is not a workspace root
			is an error rather than a fallback. Every sub-operation takes
			it. It names a target; it stores no value.

		--access-root <path>
			One extra directory a spawned agent may read and write, beyond
			the member and source roots the installer already grants.
			Repeatable. Each path must be given absolute and must already
			exist. Optional -- nothing is blocked by leaving it out.

			Stored colon-joined as CLIENT_ACCESS_ROOTS_EXTRA in this
			workspace's magic-team config scope. A path carrying ':'
			cannot be expressed in that value and is refused rather than
			split. Takes effect only together with --apply.

		--client-access-roots-extra <abs-path>[:<abs-path>...]
			The same setting written as one colon-joined value instead of
			one --access-root per directory. Optional.

		--spawn-cli-service <cli-name>
			Which agent CLI this workspace starts. You are never asked for
			it: an --apply on this domain writes `claude` into it, and
			--set-as-default is what repoints an already-made selection.
			It appears in --print-apply-command because that sub-operation
			names every option the domain declares.

		--anthropic-api-key <sk-ant-...>
			An Anthropic API key, billed per use. Optional, and the
			alternative to --claude-code-oauth-token -- set one, not both.
			Not needed at all where the CLI is already signed in.

			Where it comes from: console.anthropic.com, API keys, Create
			key. The key is shown once, at creation; store it then.

			Stored as ANTHROPIC_API_KEY -- the name claude reads out of its
			own environment, so what is stored and what the console exports
			are one string -- in this workspace's magic-team config scope.
			A secret: it never travels on a command line, so supply it
			through the stdin-fed form --print-apply-command writes.

		--claude-code-oauth-token <oauth-token>
			A token billing a Claude subscription rather than API use.
			Optional, and the alternative to --anthropic-api-key -- set
			one, not both. Not needed at all where the CLI is already
			signed in.

			Where it comes from: run `claude setup-token` once on a machine
			that has a browser, and store what it prints.

			Stored as CLAUDE_CODE_OAUTH_TOKEN -- claude's own environment
			variable name -- in this workspace's magic-team config scope.
			A secret, supplied the same stdin-fed way.

##  Sub-operations:

		--check
			Writes the per-setting detail behind the status a bare call
			reports. Read-only. Its exit status is non-zero while the
			domain is not set up, so it is usable as a readiness gate.

		--apply
			Carries the setup out non-interactively, in dependency order:
			this workspace's trust in claude, the CLI install, the
			settings, the workspace integrations, then the diagnosis again
			as its own verdict.

		--print-apply-command
			Writes the full command an --apply would carry out, naming
			every option this domain declares, required and optional, set
			or not, with a placeholder per value and a line per option
			saying where that value comes from. Changes nothing, exits 0.

		--set-as-default
			Points the CLI selection at claude even where another CLI is
			already selected. Without it, an --apply takes the selection
			only when nothing is selected at all, so an existing choice is
			never overwritten by accident. Only together with --apply.

		--all-workspaces
			Widens the report from this workspace to every workspace the
			skillset installer has registered. Reporting only: it does not
			combine with --apply, which changes exactly one workspace, nor
			with --print-apply-command, which writes the command for one.

		--wizard
			The interactive form. Not built.

##  Notes:

		Workspace trust is neither an option above nor a value in a config
		scope of ours: it is a flag on this workspace's own entry in
		claude's machine-global $HOME/.claude.json. It matters because
		claude discards every permission grant belonging to an untrusted
		workspace, which leaves everything else an --apply writes inert
		until trust is recorded.

		A setting is judged by its value where that value is used. A config
		file existing is never the check, and an unset or empty value is a
		failure rather than a default.

##  Examples:

		# What this workspace is still missing, and what closes it
		`DistroAgentsTools.fn.sh --owner-setup-claude`

		# Everything that can be carried out from here
		`DistroAgentsTools.fn.sh --owner-setup-claude --apply`

		# Store a subscription token and apply, with no secret in argv
		```
		printf '%s\n' \
		  CLAUDE_CODE_OAUTH_TOKEN='<oauth-token>' \
		  | DistroAgentsTools.fn.sh --owner-setup-claude --values-from-stdin --apply
		```

		# Grant a spawned agent one more directory
		`DistroAgentsTools.fn.sh --owner-setup-claude --access-root /Volumes/data/shared --apply`

		# Point the CLI selection at claude, over an existing selection
		`DistroAgentsTools.fn.sh --owner-setup-claude --set-as-default --apply`
