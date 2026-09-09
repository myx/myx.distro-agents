📘 syntax: DistroAgentsTools.fn.sh --owner-setup-scaleway [<config-option>...] [--set-as-default] [--check|--apply|--print-apply-command|--wizard]
📘 syntax: DistroAgentsTools.fn.sh --help-setup-scaleway

##  Summary:

		The scaleway domain makes this workspace able to run
		AgentsScalewayHarness.sh -- this package's own bespoke tool-calling
		harness against Scaleway's Serverless Generative APIs -- as its
		spawned agent: the harness present in this release, and at least
		one of its two credentials configured.

		There is no `scaleway` binary. Where `claude`/`copilot` install and
		authenticate a real CLI, this domain's whole subject is a script
		this package ships and a secret key you provide -- see MAGIC.md for
		why the harness exists and how it differs from the other domains.

		`--owner-setup-scaleway --apply` carries out everything that can be
		carried out from here. Obtaining a key is the part it cannot do
		for you.

##  What you do yourself, before --apply:

		Create a Scaleway API secret key: console.scaleway.com, IAM, API
		Keys, a Project-scoped key carrying the GenerativeApisFullAccess
		policy. Store it with --scaleway-deepseek or --scaleway-gemma
		below -- either name reaches every model Scaleway serves under
		that Project (confirmed live: a key is scoped by Project+policy,
		not by model), so one is enough. The two names exist because the
		harness's light tier prefers one and its normal/heavy tiers prefer
		the other, falling back to whichever is set when its own preferred
		name is not -- not because they are exclusive.

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
			workspace's magic-team config scope -- the same setting
			`--owner-setup-claude`/`--owner-setup-copilot` write, and the
			one the harness itself reads out of the generated
			`.claude/copilot-add-dir.fragment` at spawn time. Takes effect
			only together with --apply.

		--client-access-roots-extra <abs-path>[:<abs-path>...]
			The same setting written as one colon-joined value instead of
			one --access-root per directory. Optional.

		--spawn-cli-service <cli-name>
			Which agent CLI this workspace starts. You are never asked for
			it: an --apply on this domain writes `scaleway` into it, and
			--set-as-default is what repoints an already-made selection.
			Setting it to `scaleway` here does not by itself make a spawn
			run non-interactively -- see the Notes below.

		--scaleway-deepseek <key>
			A Scaleway API secret key, preferred for the normal/heavy
			tiers (deepseek-v4-flash-0731). Optional, and either this or
			--scaleway-gemma is enough -- at least one is required.

			Stored as SCALEWAY_DEEPSEEK -- the name AgentsScalewayHarness.sh
			reads out of its own environment -- in this workspace's
			magic-team config scope. A secret: it never travels on a
			command line, so supply it through the stdin-fed form
			--print-apply-command writes.

		--scaleway-gemma <key>
			A Scaleway API secret key, preferred for the light tier
			(gemma-4-26b-a4b-it). Optional, and either this or
			--scaleway-deepseek is enough -- at least one is required.

			Stored as SCALEWAY_GEMMA, the same way, also a secret.

##  Sub-operations:

		--check
			Writes the per-setting detail behind the status a bare call
			reports. Read-only. Its exit status is non-zero while the
			domain is not set up, so it is usable as a readiness gate.

		--apply
			Carries the setup out non-interactively: the settings, the
			workspace integrations, then the diagnosis again as its own
			verdict. There is no CLI to install and no sign-in to record.

		--print-apply-command
			Writes the full command an --apply would carry out, naming
			every option this domain declares, required and optional, set
			or not, with a placeholder per value and a line per option
			saying where that value comes from. Changes nothing, exits 0.

		--set-as-default
			Points the CLI selection at scaleway even where another CLI is
			already selected. Without it, an --apply takes the selection
			only when nothing is selected at all, so an existing choice is
			never overwritten by accident. Only together with --apply.

		--wizard
			The interactive form. Not built.

##  Notes:

		A domain being set up here is a different question from whether a
		spawn can actually run non-interactively through it, but for
		`scaleway` both are now true: AgentsConsoleShellScript.template.sh's
		own DAGC_NONINTERACTIVE_CLIS list includes `scaleway`, added after a
		live round-trip through the console itself (`--cli scaleway
		--non-interactive`, prompt on argv and on stdin) was confirmed
		working end to end. `scaleway` has no interactive shape at all --
		`--cli scaleway` without `--non-interactive` is refused with a
		stated reason -- unlike `grok`, which is the opposite case (a real
		interactive binary, not yet proven non-interactive). Setting
		SPAWN_CLI_SERVICE to `scaleway` here configures the domain and, via
		DAGC_NONINTERACTIVE_CLIS, is enough for a spawn proxy to use it. See
		MAGIC.md.

		The harness enforces its own access-root allow-list -- there is no
		real binary for `--add-dir` to reach into, so
		AgentsScalewayHarness.sh reads the same access fragment this
		domain's own CLIENT_ACCESS_ROOTS_EXTRA feeds, and refuses any file
		read, write, list, grep or command whose path or working directory
		falls outside it.

		A setting is judged by its value where that value is used. A config
		file existing is never the check, and an unset or empty value is a
		failure rather than a default.

##  Examples:

		# What this workspace is still missing, and what closes it
		`DistroAgentsTools.fn.sh --owner-setup-scaleway`

		# Store one key and apply, with no secret in argv
		```
		printf '%s\n' \
		  SCALEWAY_DEEPSEEK='<key>' \
		  | DistroAgentsTools.fn.sh --owner-setup-scaleway --values-from-stdin --apply
		```

		# Grant a spawned agent one more directory
		`DistroAgentsTools.fn.sh --owner-setup-scaleway --access-root /Volumes/data/shared --apply`

		# Point the CLI selection at scaleway, over an existing selection
		`DistroAgentsTools.fn.sh --owner-setup-scaleway --set-as-default --apply`
