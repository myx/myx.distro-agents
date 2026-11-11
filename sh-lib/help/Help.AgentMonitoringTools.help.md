📘 syntax: AgentMonitoringTools.fn.sh --health [--workspace <path>]
📘 syntax: AgentMonitoringTools.fn.sh [--help-syntax]
📘 syntax: AgentMonitoringTools.fn.sh [--help]

##  Summary:

		Any member's personal tool for monitoring (epic S14): the health reading of
		the workspace the member works in, the same reading DistroAgentsMonitoring.fn.sh
		gives an operator or a supervisor. Read only: nothing here changes a flag or
		starts anyone.

##  Options:

  --health [--workspace <path>]
			One reading of the workspace, this one where none is named. Tab-separated
			lines: `health <workspace> <asset> <state> <detail>`, one an asset; an `alarm`
			line after a dead daemon or a comms outbox backlog; `muted` in place of an
			alarm while the planned-maintenance flag holds, with the seconds left.
