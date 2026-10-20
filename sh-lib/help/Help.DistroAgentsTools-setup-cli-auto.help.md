📘 syntax: DistroAgentsTools.fn.sh --owner-setup-cli-auto [--check|--apply]
📘 syntax: DistroAgentsTools.fn.sh --help-setup-cli-auto

##  Summary:

		The cli-auto domain selects the vendor CLI this workspace starts, of
		the two this package reaches as they are installed on the machine,
		`claude-native` and `copilot-native`: the first, in that order,
		that is installed and works.

		It stores nothing of its own. `--apply` carries out
		`--owner-setup-<that CLI> --set-as-default --apply`, so the setup
		of that CLI writes SPAWN_CLI_SERVICE and everything else that
		setup takes with it, as it would if you had named the CLI yourself.

		The detection is here and in the console's Configuration, never
		at a spawn: a spawn resolves SPAWN_CLI_SERVICE and scans no PATH.

##  What works, for each CLI:

		claude-native
			`claude` is in PATH and `claude auth status --json` says
			somebody is signed in. The test the setup of claude-native
			makes of its own sign-in (SPAWN_CLI_AUTHENTICATED).

		copilot-native
			`copilot` is in PATH and `copilot --version` ends well.
			copilot carries no sign-in to ask of, so this is all there
			is to ask.

##  Sub-operations:

		--check
			(the same as none) Asks each CLI whether it works, says why
			for each, and names the pick and the command that applies
			it, and what SPAWN_CLI_SERVICE is now. Read-only. Its exit
			status is non-zero while neither works.

		--apply
			Carries out the setup of the pick, over an existing
			selection. Changes nothing, and exits non-zero, while
			neither CLI works.

##  Examples:

		# Which would be selected, and why
		`DistroAgentsTools.fn.sh --owner-setup-cli-auto --check`

		# Select it
		`DistroAgentsTools.fn.sh --owner-setup-cli-auto --apply`
