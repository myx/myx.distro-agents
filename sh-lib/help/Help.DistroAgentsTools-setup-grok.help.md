📘 syntax: DistroAgentsTools.fn.sh --owner-setup-grok [<config-option>...] [--set-as-default] [--check|--apply|--print-apply-command|--wizard]
📘 syntax: DistroAgentsTools.fn.sh --help-setup-grok

##  Summary:

		The grok domain makes this workspace able to run
		AgentsGrokHarness.sh -- this package's own tool-calling harness
		against xAI's Chat Completions API -- as its spawned agent: the
		harness present in this release, and its credential configured.

		This domain's subject is that harness, not the vendor grok CLI,
		which the console reaches as `grok-native` and which this domain
		neither installs nor configures.

		`--owner-setup-grok --apply` carries out everything that can be
		carried out from here. Obtaining a key is the part it cannot do
		for you.

##  What you do yourself, before --apply:

		Create an xAI API key: console.x.ai, API Keys, Create API Key.
		Store it with --xai-api-key below.

##  Options:

		--workspace-root <path>
			Which workspace this call is about. Defaults to the workspace
			the tool is run from, and a path that is not a workspace root
			is an error rather than a fallback. Every sub-operation takes
			it. It names a target; it stores no value.

		--spawn-cli-service <cli-name>
			Which agent CLI this workspace starts. You are never asked for
			it: an --apply on this domain writes `grok` into it, and
			--set-as-default is what repoints an already-made selection.

		--xai-api-key <key>
			An xAI API key, used for every tier. Required.

			Stored as XAI_API_KEY -- the name AgentsGrokHarness.sh reads
			out of its own environment, and xAI's own documented name -- in
			this workspace's magic-team config scope. A secret: it never
			travels on a command line, so supply it through the stdin-fed
			form --print-apply-command writes.

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
			Points the CLI selection at grok even where another CLI is
			already selected. Without it, an --apply takes the selection
			only when nothing is selected at all, so an existing choice is
			never overwritten by accident. Only together with --apply.

		--wizard
			The interactive form. Not built.

##  Notes:

		`grok` is a harness leg, so it has no interactive shape: the
		console runs it only with --non-interactive, as it does every leg.

		The harness enforces its own access-root allow-list and refuses
		any file read, write, list, grep or command whose path or working
		directory falls outside it.

		A setting is judged by its value where that value is used. A config
		file existing is never the check, and an unset or empty value is a
		failure rather than a default.

##  Examples:

		# What this workspace is still missing, and what closes it
		`DistroAgentsTools.fn.sh --owner-setup-grok`

		# Store the key and apply, with no secret in argv
		```
		printf '%s\n' \
		  XAI_API_KEY='<key>' \
		  | DistroAgentsTools.fn.sh --owner-setup-grok --values-from-stdin --apply
		```

		# Point the CLI selection at grok, over an existing selection
		`DistroAgentsTools.fn.sh --owner-setup-grok --set-as-default --apply`