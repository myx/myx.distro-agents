📘 syntax: AgentTestingTools.fn.sh --request-tests --why <text> [--project <p>] [--file <changed-file>]... [--about <scratch-folder>] [--wait|--no-wait] [<test>...]
📘 syntax: AgentTestingTools.fn.sh [--help-syntax]
📘 syntax: AgentTestingTools.fn.sh [--help]

##  Summary:

		Any member's personal tool for a testing need: the way a member
		communicates a testing task to the testing system and to
		magic-tester. A tool that takes work in; nobody reads results
		from it.

##  Options:

		--request-tests --why <text> [--project <p>] [--file <changed-file>]... [--about <scratch-folder>] [--wait|--no-wait] [<test>...]
			Puts the tests into the one retest queue as the calling
			member's request, with the options and the rules of
			--retest-queue (`--by` is not given: the request is the
			member's), and files one inquiry into magic-tester's inbox
			that says who asks, for what, why, with which priority, and
			where the outcome is read (`--retest-result <id>`). A
			request the queue refuses queues nothing and asks nobody.
			The first line printed is the request's id, said as soon as
			the inquiry is filed; with `--wait` the call stays until
			the batch has run the request and says how it came out, and
			ends with rc 0 for a pass.
