📘 syntax: DistroAgentsTesting.fn.sh --send-report [--team-member <team-member>]
📘 syntax: DistroAgentsTesting.fn.sh --retest-queue [--by <who>] [--about <scratch-folder>] --why <text> [--project <p>] [--file <changed-file>]... [--wait|--no-wait] [<test>...]
📘 syntax: DistroAgentsTesting.fn.sh --retest-drain [--rest [--about <scratch-folder>]]
📘 syntax: DistroAgentsTesting.fn.sh --retest-result <request-id>...
📘 syntax: DistroAgentsTesting.fn.sh --apply-tool <mark|level|plan|apply> [--repository <repository-path>] [--scratch <scratch-path>] [mark: <package>/<relative-path>...]
📘 syntax: DistroAgentsTesting.fn.sh --test-register [--team-member <team-member>] <test-id> --project <p> --script <path> [--functionality <f>] [--keyword <k>]... [--rig <path>] [--document <path>]... [--resource <path>]... [--nightly yes|no]
📘 syntax: DistroAgentsTesting.fn.sh --test-register [--team-member <team-member>] --from-folder <dir> --project <p> [--functionality <f>] [--keyword <k>]... [--rig <path>] [--document <path>]... [--resource <path>]... [--nightly yes|no]
📘 syntax: DistroAgentsTesting.fn.sh --test-update [--team-member <team-member>] <test-id> [--project <p>] [--script <path>] [--functionality <f>] [--keyword <k>]... [--rig <path>] [--document <path>]... [--resource <path>]... [--nightly yes|no]
📘 syntax: DistroAgentsTesting.fn.sh --test-unregister [--team-member <team-member>] <test-id>
📘 syntax: DistroAgentsTesting.fn.sh --test-invalidate [--team-member <team-member>] <test-id>
📘 syntax: DistroAgentsTesting.fn.sh --test-list [--team-member <team-member>] [--project <p>] [--namespace <n>] [--keyword <k>]
📘 syntax: DistroAgentsTesting.fn.sh --run-oldest-untested [--team-member <team-member>] [--wait|--no-wait]
📘 syntax: DistroAgentsTesting.fn.sh --run-all-nightly-regressions [--team-member <team-member>] [--wait|--no-wait]
📘 syntax: DistroAgentsTesting.fn.sh --skillset-validate-routine [--team-member <team-member>] <routine-file|--from-stdin>
📘 syntax: DistroAgentsTesting.fn.sh [--help-syntax [<op>]]
📘 syntax: DistroAgentsTesting.fn.sh [--help]

##  Summary:

		The testing system: the testbed, which knows every registered test and
		its pass record; the one retest queue and the batch that runs it; the
		report the coordinator reads; and the apply tool. A test is registered
		once, run by the batch, and asked about by its request id.

##  Options:

		--retest-queue [--by <who>] [--about <scratch-folder>] --why <text> [--project <p>] [--file <changed-file>]... [--wait|--no-wait] [<test>...]
			Puts the tests into the one retest queue as one request, with why and
			with the files that changed. The first line printed is the request's id;
			`--wait` stays until the batch has run it and says how it came out.

		--retest-drain [--rest [--about <scratch-folder>]]
			Runs the batch, one test after another, and ends when the queue is
			empty. `--rest` first, so a machine that has just worked does not run.

		--retest-result <request-id>...
			Where each request stands, a line each, and what a finished request's
			tests came to.

		--send-report [--team-member <team-member>]
			The testing report, as the coordinator reads it, posted where the report
			belongs.

		--test-register <test-id> --project <p> --script <path> [--functionality <f>] [--keyword <k>]... [--rig <path>] [--document <path>]... [--resource <path>]... [--nightly yes|no]
		--test-register --from-folder <dir> --project <p> [--functionality <f>] [--keyword <k>]... [--rig <path>] [--document <path>]... [--resource <path>]... [--nightly yes|no]
			The metadata of one test, or of every `*.test.sh` of a folder in one
			call.

		--test-update <test-id> [--project <p>] [--script <path>] [--functionality <f>] [--keyword <k>]... [--rig <path>] [--document <path>]... [--resource <path>]... [--nightly yes|no]
			Changes the metadata of a registered test: the options of
			`--test-register`, a list replaced whole.

		--test-unregister <test-id>
			Takes a test out of the testbed. The test, its script and its pass
			record stay where they are.

		--test-invalidate <test-id>
			Drops the pass record of a registered test, so that the next batch runs
			it again.

		--test-list [--project <p>] [--namespace <n>] [--keyword <k>]
			The registered tests, with their stats and a short run history.

		--run-oldest-untested [--wait|--no-wait]
		--run-all-nightly-regressions [--wait|--no-wait]
			The oldest untested registered test, or every test eligible for the
			nightly, put into the retest queue.

		--skillset-validate-routine <routine-file|--from-stdin>
			Checks a routine file's front matter and required headers and reports
			what is missing or wrong, a row each; exit non-zero where any.
			Read-only.

		--apply-tool <mark|level|plan|apply> [--repository <repository-path>] [--scratch <scratch-path>] [mark: <package>/<relative-path>...]
			The four beats of applying a lane's work to a repository, all of it under
			`.local/temp/live-apply.lock`: mark records a file's base, level brings
			the scratch packages level with live, plan is the dry run, and apply
			writes the work back.
			A file is removed when the scratch lists it in `removals.txt`, a path a
			line, and renamed when it lists `<old><TAB><new>` in `renames.txt`. The
			old path and a removed one are marked, with their base, and deleted from
			the scratch; the new path is marked with no base. Apply writes every file
			first and removes last. A removal or a rename source is taken only at
			its base: where live changed it, it is refused, and never merged. That
			is deliberate.
			A marked file that live no longer holds reads GONE on live, in level,
			plan and apply. A path outside packages.txt, with a `.` or `..` part, a
			blank or a symlink on live, and a case-only rename on macOS, are refused.
			Each step is added to `applied-steps.txt` in the scratch before it is
			made, tagged with a checksum of this work's order and lists. An apply
			that stopped is run again and skips a step of the same work that is
			recorded and already true on live. The lock holds an `owner` file, and
			every exit gives it back. plan and apply need `packages.txt`.
			Exit status of apply: 0 done; 1 a fault of the call or the scratch;
			2 the apply order is not the changed list; 3 the lock stays taken;
			4 refused, nothing done; 5 stopped part way; 6 a removed file is still
			on live; 129, 130 or 143 ended by a hangup, an interrupt or TERM.

##  Examples:

		# Ask for a retest of the tests a change touched, and bring the outcome
		`DistroAgentsTesting.fn.sh --retest-queue --why "the queue fix" --project myx.distro-agents --file sh-scripts/DistroAgentsTesting.fn.sh --wait`
		# One test's metadata, then the list that shows it
		`DistroAgentsTesting.fn.sh --test-register AgentsHelpFormsCheck --project myx.distro-agents --script sh-test/help/AgentsHelpFormsCheck.test.sh`
		`DistroAgentsTesting.fn.sh --test-list --project myx.distro-agents`
		# Drop a pass record so the next batch runs it, then run the batch
		`DistroAgentsTesting.fn.sh --test-invalidate AgentsHelpFormsCheck`
		`DistroAgentsTesting.fn.sh --retest-drain`
